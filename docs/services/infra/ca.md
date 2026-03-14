## Operation
Refer to Ansible playbook

## Configuration files

- ca.json
- defaults.json

### Provisioner

Provisioner is basically the object of issuing certificates as a RA. They verify CSR from client and when it is valid with its policy they will sign the certificates with CA's private key. Step-CA supports various type of provisioner. In this homelab, only ACME will be used. Because infrastructure's certificates is issued manually. Step-CA supports one root CA and one intermediate CA in one container, only one intermediate CA will be operated in this project.

#### jwk-ca@ilnmors.internal

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

#### jwk@ilnmors.internal

This provisioner is to issue the certificates like DB communication based on its identity (Using JWK and JWT pre-shared). The certificate is issued based on enrolled key in provisioner. However, in this project all crt will be used central ACME client `Caddy`.

- Define provisioner

```bash
podman exec -it step-ca \
step ca provisioner add jwk@ilnmors.internal \
--create \ # Generate key pair automatically
--type JWK \
--x509-default-dur 2160h # To set default expire date as 90 days.
```

#### acme@ilnmors.internal

This provisioner is to issue the certificates for https communication. The certificate is issued based on challenge; the ownership of domain.

- Define provisioner
```bash
podman exec -it step-ca \
step ca provisioner add acme@ilnmors.internal \
--type ACME \
--x509-default-dur 2160h # To set default expire date as 90 days.
```

### Subject

Step-CA uses subject as a account. It is used to manage Step-CA remotely. To use this, it is necessary to use `--remote-management` option when the step-CA is initially set or fix `ca.json` authority.enableAdmin:true. When subject is enabled, provisioners aren't defined in ca.json but its own DB.

### Policy

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

## Verify server

### Server health check

```bash
curl -k https://ca.ilnmors.internal:9000/health
> {"status":"ok"}
```

### Server policy check

```bash
podman exec -it ca step ca certificate test.com test.crt test_key --provisioner acme@ilnmors.internal
> error creating new ACME order: The server will not issue certificates for the identifier
```

---
## Set trust Root CRT

### Linux

#### Debian/ubuntu

- File: /usr/local/share/ca-certificates/{ca.crt, ca.pem}
- `update-ca-certificates`

#### Cent/RHEL/Fedora

- File: /etc/pki/ca-trust/source/anchors/{ca.crt, ca.pem}
- `update-ca-trust`

### Windows

- `Windows + R` + `certlm.msc`
- `All Task` - `Import`

### Firefox

- Setting - Security - view certificates - Authority - add
    - \[x\] trust this ca to identify website
    - \[x\] trust this ca to identify email users
