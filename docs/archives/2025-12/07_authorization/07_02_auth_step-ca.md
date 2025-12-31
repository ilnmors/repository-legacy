Tags: #os, #configuration, #network, #virtualization, #container, #security

## Step-CA

Step-CA is the modern CA server which can operate in private network environment. It can issue CA and certificates, apply the policy with provisioner. It supports ACME, JWK, etc.

### Secret management

- File: 
	- ~/data/config/secrets/.secret.yaml

- Edit `.secret.yaml` with `edit_secret.sh`


```yaml
# ~/data/config/secrets/.secret.yaml
# STEP_CA
STEP_CA_PASSWORD: generated_value
```


### Preparation

#### iptables and firewall rules

- Set iptables first, following [here](../03_common/03_02_iptables.md).
- Set firewall rules first, following [here](Latest/05_firewall/05_04_opnsense_rules.md).
#### Create directory for container

```bash
mkdir -p ~/data/containers/step-ca
chmod 700 ~/data/containers/step-ca
setfacl -m d:g::0 ~/data/containers/step-ca
setfacl -m d:o::0 ~/data/containers/step-ca
setfacl -m u:auth:rwx ~/data/containers/step-ca
setfacl -m u:100999:rwx ~/data/containers/step-ca
setfacl -d -m u:auth:rwx ~/data/containers/step-ca
setfacl -d -m u:100999:rwx ~/data/containers/step-ca
# After generating
sudo find ~/data/containers/step-ca -type f -exec setfacl -m m::rw {} \;
sudo find ~/data/containers/step-ca -type d -exec setfacl -m m::rwx {} \;
```

> Step-CA container executes as 1000:1000(step:step) permission in container. It is mapped host's 100999. Therefore, directories have to have ACL via `setfacl`

#### Add new domain in BIND

Following [here](../06_network/06_03_net_bind.md).

- net server
- file: /home/net/data/containers/bind/lib/db.ilnmors.internal
  
```ini
# ...
step-ca     IN     CNAME     auth.ilnmors.internal.
# ...
```

```bash
# Adguard container has Requires=bind.service. When it restarted, then Adguard also restarted.
systemctl --user restart bind
```

### Podman Image

```bash
podman pull smallstep/step-ca:0.28.4 # Do not use latest version to management
```

#### CA generation

```bash
podman run --rm -it \
-v /home/auth/data/containers/step-ca:/home/step:rw \
smallstep/step-ca:0.28.4 step ca init \
--deployment-type standalone \
--name ilnmors.internal \
--dns step-ca.ilnmors.internal \
--address :9000 \
--provisioner step-admin@ilnmors.internal
# Private mode: standalone

# Intermediate CA setting options
# --ra stepCAS \
# --issuer https://step-ca.ilnmors.internal:9000 \
# --issuer-fingerprint ~~~~ \
# --issuer-provisioner jwk-ca@dev.ilnmors.internal
# --confidential-file ~~~

> [leave empty and we\'ll generate one]: [blank]
# Print
---
✔ Password: Generated_value # Copy this value and paste in .secret.yaml file as STEP_CA_PASSWORD=
✔ Root fingerprint: fingerprint
---
```

> Password value encrypts root CA's private key

```bash
# Podman secret
extract_secret.sh ~/data/config/secrets/.secret.yaml -f "STEP_CA_PASSWORD" | podman secret create "STEP_CA_PASSWORD" -
```

### Configuration files

- File: ~/data/containers/step-ca/config/ca.json

#### Provisioner

Provisioner is basically the object of issuing certificates as a RA. They verify CSR from client and when it is valid with its policy they will sign the certificates with CA's private key. Step-CA supports various type of provisioner. In this homelab, only ACME will be used. Because it is easy to manage when you use OPNsense ACME client. Step-CA supports one root CA and one intermediate CA in one container, only one intermediate CA will be operated in this project. However, the way to set multi intermediate CA will be explained, and jwk way in this document.

##### jwk-ca@ilnmors.internal

This provisioner is to issue intermediate CA. It wouldn't be used in this project. The option for CA in X.509 format is optional and defined in as extension option. To define these option in step-ca, the template file is needed.

- file: ~/data/containers/step-ca/templates/ca.tpl

```json
{
	"subject": {{ toJson .Subject }},
	"keyUsage": ["certSign", "crlSign"],
	"basicConstraints": {
		"isCA": true,
		"maxPathLen": 0
	}
}
```

>  keyUsage: Designate to manage certificates and CRL
>  isCA:  Designate the certificate to use CA
>  maxPathLen: Designate allowed below CA's number


- Define provisioner

```bash
podman exec -it step-ca \
step ca provisioner add jwk-ca@ilnmors.internal \
--create \ # Generate key pair automatically
--type JWK \
--ca-config /home/step/config/ca.json \ # Sign on certificate with root CA's private key
--x509-template /home/step/template/ca.tpl \ # Use x509 template
--x509-max-dur 87600h \ #
--x509-default-dur 87600h
```

##### jwk@ilnmors.internal

This provisioner is to issue the certificates like DB communication based on its identity (Using JWK and JWT pre-shared). The certificate is issued based on enrolled key in provisioner. However, in this project all crt will be used central ACME client `Opnsens ACME client` and `Caddy`.

- Define provisioner

```bash
podman exec -it step-ca \
step ca provisioner add jwk-crt@ilnmors.internal \
--create \ # Generate key pair automatically
--type JWK \
--x509-default-dur 2160h # To set default expire date as 90 days.
```

##### acme@ilnmors.internal

This provisioner is to issue the certificates for https communication. The certificate is issued based on challenge; the ownership of domain.

- Define provisioner
```bash
podman exec -it step-ca \
step ca provisioner add acme@ilnmors.internal \
--type ACME \
--x509-default-dur 2160h # To set default expire date as 90 days.
```

#### Subject

Step-CA uses subject as a account. It is used to manage Step-CA remotely. To use this, it is necessary to use `--remote-management` option when the step-CA is initially set or fix `ca.json` authority.enableAdmin:true. When subject is enabled, provisioners aren't defined in ca.json but its own DB.

#### Policy

Self-hosted Step-CA server doesn't support to give x509 policy for each provisioner. It only allows public policy. Only `ilnmors.internal` and `*.ilnmors.internal` certificates are required, so designate the policy in `ca.json`

> Policies can be administered using the step CLI application. The commands are part of the step ca policy namespace. In a self-hosted step-ca, policies can be configured on the authority level. Source: [here](https://smallstep.com/docs/step-ca/policies/)

- file: ~/data/containers/step-ca/config/ca.json

```json
...
"authority": {
	"policy": {
		"x509": {
			"allow": {
				"dns": [
					"ilnmors.internal",
					"*.ilnmors.internal"
				]
			},
			"allowWildcardNames": true
		}
	},
	"provisioners": [ ... ]
	....
}
...
```
### Quadlet

- File: 
	- ~/data/config/containers/step-ca/step-ca.container

```ini
# ~/data/config/containers/step-ca/step-ca.container
[Quadlet]
DefaultDependencies=false

[Unit]
Description=Step-CA

After=network-online.target
Wants=network-online.target

[Container]
Image=docker.io/smallstep/step-ca:0.28.4

ContainerName=step-ca

PublishPort=9000:9000/tcp

Volume=%h/data/containers/step-ca:/home/step:rw

Environment="TZ=Asia/Seoul"
Environment="PWDPATH=/run/secrets/STEP_CA_PASSWORD"

Secret=STEP_CA_PASSWORD,target=/run/secrets/STEP_CA_PASSWORD

Label=diun.enable=true
Label=diun.watch_repo=true

[Install]
WantedBy=default.target
```

#### Create systemd `.service` file

```bash
mkdir -p ~/.config/containers/systemd

ln -s ~/data/config/containers/step-ca/step-ca.container ~/.config/containers/systemd/step-ca.container

systemctl --user daemon-reload
```

#### Enable and start service

```bash
systemctl --user start step-ca.service
```

### Verify server

#### Server health check

```bash
curl -k https://step-ca.ilnmors.internal:9000/health
> {"status":"ok"}
```

#### Server policy check

```bash
podman exec -it step-ca step ca certificate test.com test.crt test_key --provisioner acme@ilnmors.internal
> error creating new ACME order: The server will not issue certificates for the identifier
```

---
### Set trust Root CRT

#### Linux

##### Debian/ubuntu

- File: /usr/local/share/ca-certificates/{ca.crt, ca.pem}
- `update-ca-certificates`

##### Cent/RHEL/Fedora

- File: /etc/pki/ca-trust/source/anchors/{ca.crt, ca.pem}
- `update-ca-trust`

#### Windows

- `Windows + R` + `certlm.msc`
- `All Task` - `Import`

#### Firefox

- Setting - Security - certificates - CA - add

---
### intermediate CA setting

It won't be used in this project, however here is the way to set.

#### Example of dev.ilnmors.internal intermediate CA

- init CA
```bash
podman run --rm -it \
-v /home/dev/data/containers/step-ca:/home/step:rw \
smallstep/step-ca:0.28.4 step ca init \
--deployment-type standalone \
--name dev.ilnmors.internal \
--dns step-ca.dev.ilnmors.internal \
--address :9000 \
--provisioner admin@dev.ilnmors.internal \
--ra stepCAS \
--issuer https://step-ca.ilnmors.internal:9000 \
--issuer-fingerprint ~~~~ \ # root CA's fingerprint
--issuer-provisioner jwk-ca@dev.ilnmors.internal
--confidential-file ~~~ # jwk-ca's password file
```