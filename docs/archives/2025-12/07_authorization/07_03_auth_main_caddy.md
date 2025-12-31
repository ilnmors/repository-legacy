Tags: #os, #configuration, #network, #virtualization, #container, #security, #authentication, #authorization, #sso

## Caddy - auth

Caddy is an open source reverse proxy (web server) which supports automatically to apply TLS certificates via ACME protocol from CA. It supports various module including dns module. However, the most important and fundamental services such as OPNsense, AdGuard Home, Step-CA, Authelia would not use caddy for independency.

### Secret management

- File: 
	- ~/data/config/secrets/.secret.yaml

- Edit `.secret.yaml` with `edit_secret.sh`

```yaml
# ~/data/config/secrets/.secret.yaml
# CADDY:
CADDY_ACME_KEY: acme-key_key_value (Only secret value)
CADDY_CROWDSEC_KEY: CADDY_LAPI_KEY
```

```bash
# Podman secret
extract_secret.sh .secret.yaml -f CADDY_ACME_KEY | podman secret create CADDY_ACME_KEY -

extract_secret.sh .secret.yaml -f CADDY_CROWDSEC_KEY | podman secret create CADDY_CROWDSEC_KEY -
```

### Preparation

#### iptables and firewall rules

- Set iptables first, following [here](../03_common/03_02_iptables.md).
- Set firewall rules first, following [here](Latest/05_firewall/05_04_opnsense_rules.md).
#### Create directory for container

```bash
mkdir -p ~/data/containers/caddy-auth/{etc,data}
chmod -R 700 ~/data/containers/caddy-auth
```

> Caddy container executes as 0:0(root:root) permission in container. It is mapped host's UID. Therefore, directories don't have to have ACL via `setfacl`

#### Add new domain in BIND

Following [here](../06_network/06_03_net_bind.md).

- net server
- file: ~/data/containers/bind/lib/db.ilnmors.internal
  
```ini
# ...
login     IN     CNAME     auth.ilnmors.internal.
# ...
```

```bash
# Adguard container has Requires=bind.service. When it restarted, then Adguard also restarted.
systemctl --user restart bind
```

### Podman Image

#### Podman containerfile

Caddy supports various module for it. rfc2136(nsupdate) module, crowdsec will be used in this homelab project.

- file: 
	- ~/data/config/containers/caddy-auth/containerfile-caddy-2.10.2-auth
	- ~/data/config/containers/caddy-auth/root_ca.crt

```containerfile
FROM caddy:2.10.2-builder-alpine AS builder

RUN xcaddy build \
--with github.com/caddy-dns/rfc2136 \
--with github.com/hslatman/caddy-crowdsec-bouncer/crowdsec \
--with github.com/hslatman/caddy-crowdsec-bouncer/http

FROM caddy:2.10.2

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

COPY ./root_ca.crt /usr/local/share/ca-certificates/root_ca.crt

RUN update-ca-certificates
```


#### Podman image build

```bash
podman build -t caddy:2.10.2-auth -f ~/data/config/containers/caddy-auth/containerfile-caddy-2.10.2-auth . && podman image prune -f
# Delete pure caddy and caddy-builder-alpine images after command above manually.
```

### Configuration files

Caddyfile will be updated after Authelia setting

```bash
# fix inconsistencies
podman exec caddy-auth caddy fmt --overwrite /etc/caddy/Caddyfile
# After Caddyfile setting is changed use this command.
podman exec caddy-auth caddy reload --config /etc/caddy/Caddyfile
```

- file:
    - ~/data/containers/caddy-auth/etc/Caddyfile
    - ~/data/containers/caddy-auth/certs/root_ca.crt

```ini
# Caddyfile
# ~/data/containers/caddy-auth/etc/Caddyfile

# Global option
{
        # CrowdSec LAPI connection
        crowdsec {
                api_url https://crowdsec.ilnmors.internal:8080
                api_key "{file./run/secrets/CADDY_CROWDSEC_KEY}"
        }
}

# Snippets
# CrowdSec log for parser
(crowdsec_log) {
        log {
                output file /data/access.log {
                        mode 0640
                        roll_size 100MiB
                        roll_keep 1
                }
        }
}
# Private TLS ACME with DNS-01-challenge
(private_tls) {
        tls {
                issuer acme {
                        dir https://step-ca.ilnmors.internal:9000/acme/acme@ilnmors.internal/directory
                        dns rfc2136 {
                                server bind.ilnmors.internal:2253
                                key_name acme-key
                                key_alg hmac-sha256
                                key "{file./run/secrets/CADDY_ACME_KEY}"
                        }
                }
        }
}

test.ilnmors.com {
        import crowdsec_log
        route {
                crowdsec
                root * /usr/share/caddy
                file_server
        }
}

caddy.ilnmors.internal {
        import private_tls
        import crowdsec_log
        route {
                crowdsec
                root * /usr/share/caddy
                file_server
        }
}
```

### Quadlet

- File: 
	- ~/data/config/containers/caddy-auth/caddy-auth.container

```ini
# ~/data/config/containers/caddy-auth/caddy-auth.container
[Quadlet]
DefaultDependencies=false

[Unit]
Description=Caddy - auth

After=step-ca.service
Requires=step-ca.service

[Container]
Image=localhost/caddy:2.10.2-auth

ContainerName=caddy-auth

# To issue certificate from step-ca
AddHost=step-ca.ilnmors.internal:host-gateway

PublishPort=2080:80/tcp
PublishPort=2443:443/tcp

Volume=%h/data/containers/caddy-auth/etc:/etc/caddy:rw
Volume=%h/data/containers/caddy-auth/data:/data:rw

Environment="TZ=Asia/Seoul"

Secret=CADDY_ACME_KEY,target=/run/secrets/CADDY_ACME_KEY
Secret=CADDY_CROWDSEC_KEY,target=/run/secrets/CADDY_CROWDSEC_KEY

Label=diun.enable=true
Label=diun.watch_repo=true
# This label need configuration on `diun.yml`
Label=diun.regopt=caddy-auth-source

[Install]
WantedBy=default.target
```

#### Create systemd `.service` file

```bash
# linger has to be activated
ln -s ~/data/config/containers/caddy-auth/caddy-auth.container ~/.config/containers/systemd/caddy-auth.container

systemctl --user daemon-reload
```

#### Enable and start service

```bash
systemctl --user start caddy-auth.service
```

### Crowdsec bouncer and agent

- Following [here](../03_common/03_04_crowdsec.md).