Tags: #os, #configuration, #network, #virtualization, #container, #security

## Caddy - dev

Caddy is an open source reverse proxy (web server) which supports automatically to apply TLS certificates via ACME protocol from CA. This caddy will work as sidecar caddy, so it only uses private TLS. It can only communication with auth's main caddy. This means it doesn't need any module except RFC2136 module. Because main caddy will conduct WAF function at all.

### Secret management

- File: 
	- ~/data/config/secrets/.secret.yaml

- Edit `.secret.yaml` with `edit_secret.sh`

```yaml
# ~/data/config/secrets/.secret.yaml
# CADDY:
CADDY_ACME_KEY: acme-key_key_value (Only secret value)
```

```bash
# Podman secret
extract_secret.sh .secret.yaml -f CADDY_ACME_KEY | podman secret create CADDY_ACME_KEY -
```

### Preparation

#### iptables and firewall rules

- Set iptables first, following [here](../03_common/03_02_iptables.md).
	- Limit access client as Caddy - auth ( -s 192.168.10.12/32 )
	- 443 > 2443 (iptables setting)
- Set firewall rules first, following [here](Latest/05_firewall/05_04_opnsense_rules.md).
#### Create directory for container

```bash
mkdir -p ~/data/containers/caddy-dev/{etc,data}
chmod -R 700 ~/data/containers/caddy-dev
```

> Caddy container executes as 0:0(root:root) permission in container. It is mapped host's UID. Therefore, directories don't have to have ACL via `setfacl`

#### Add new domain in BIND

Following [here](../06_network/06_03_net_bind.md).

- net server
- file: ~/data/containers/bind/lib/db.ilnmors.internal
  
```ini
# ...
dev     IN     A     192.168.10.13
# ...
```

```bash
# Adguard container has Requires=bind.service. When it restarted, then Adguard also restarted.
systemctl --user restart bind
```

### Podman Image

#### Podman containerfile

Caddy supports various module for it. rfc2136(nsupdate) module, Sidecar caddy only recieves the request from the main caddy. Therefore it doesn't need anymore.

- file: 
	- ~/data/config/containers/caddy-dev/containerfile-caddy-2.10.2-dev
	- ~/data/config/containers/caddy-dev/root_ca.crt

```containerfile
FROM caddy:2.10.2-builder-alpine AS builder

RUN xcaddy build \
--with github.com/caddy-dns/rfc2136

FROM caddy:2.10.2

COPY --from=builder /usr/bin/caddy /usr/bin/caddy

COPY ./root_ca.crt /usr/local/share/ca-certificates/root_ca.crt

RUN update-ca-certificates
```

#### Podman image build

```bash
podman build -t caddy:2.10.2-dev -f ~/data/config/containers/caddy-dev/containerfile-caddy-2.10.2-dev . && podman image prune -f
# Delete pure caddy and caddy-builder-alpine images after command above manually.
```

### Configuration files

Caddyfile will be updated after Authelia setting

```bash
# fix inconsistencies
podman exec caddy-dev caddy fmt --overwrite /etc/caddy/Caddyfile
# After Caddyfile setting is changed use this command.
podman exec caddy-dev caddy reload --config /etc/caddy/Caddyfile
```

- file:
    - ~/data/containers/caddy-auth/etc/Caddyfile
    - ~/data/containers/authelia/config/configuration.yml
    - ~/data/containers/caddy-dev/etc/Caddyfile

```ini
# Caddyfile
# ~/data/containers/caddy-auth/etc/Caddyfile

# Forward Auth for other vms
(apply_forward_auth) {
        forward_auth host.containers.internal:9091 {
                uri /api/authz/forward-auth
                copy_headers Remote-User Remote-Groups Remote-Email R>
        }
        reverse_proxy {args[0]} {
                header_up Host {http.reverse_proxy.upstream.host}
			# X-Forwarded-Host header contains original Host value
        }
}


# ...
dev-test.ilnmors.com {
        import crowdsec_log
        route {
            crowdsec
            import apply_forward_auth https://dev.ilnmors.internal
        }
}
# ...
```

```ini
# Caddyfile
# ~/data/containers/caddy-dev/etc/Caddyfile
{
        server {
                trusted_proxies static 192.168.10.12/32
                trusted_proxies_strict
                # To find the real client's IP.
                # default = false : left to right, when the Caddy met the untrusted IP first, then it would treat as client IP
                # true : right to left > It is easy to find currupted client IP
        }
}

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

dev.ilnmors.internal {
        import private_tls
        @test header X-Forwarded-Host dev-test.ilnmors.com
        route @test {
                root * /usr/share/caddy
                file_server
        }
}
```

```yaml
# configuration.yml

# ...
# Access control configuration
access_control:
  default_policy: 'deny'
  rules:
    # authelia portal
    - domain: 'authelia.ilnmors.internal'
      policy: 'bypass'
    - domain: 'authelia.ilnmors.com'
      policy: 'bypass'
    - domain: 'dev-test.ilnmors.com'
      policy: 'one_factor'
	  # Access control for Forward_Auth
	  subject:
	    - 'group:admins'

# ...
```

### Quadlet

- File: 
	- ~/data/config/containers/caddy-auth/caddy-dev.container

```ini
# ~/data/config/containers/caddy-dev/caddy-dev.container
# ~/data/config/containers/caddy-dev/caddy-dev.container
[Quadlet]
DefaultDependencies=false

[Unit]
Description=Caddy - dev

After=network-online.target
Wants=network-online.target

[Service]
# Main Caddy and Step-CA
ExecStartPre=%h/data/config/scripts/wait-for-it.sh -h 192.168.10.12 -p 443 -t 0
ExecStartPre=%h/data/config/scripts/wait-for-it.sh -h 192.168.10.12 -p 9000 -t 0
ExecStartPre=sleep 5

[Container]
Image=localhost/caddy:2.10.2-dev

ContainerName=caddy-dev

PublishPort=2080:80/tcp
PublishPort=2443:443/tcp

Volume=%h/data/containers/caddy-dev/etc:/etc/caddy:rw
Volume=%h/data/containers/caddy-dev/data:/data:rw

Environment="TZ=Asia/Seoul"

Secret=CADDY_ACME_KEY,target=/run/secrets/CADDY_ACME_KEY

Label=diun.enable=true
Label=diun.watch_repo=true

[Install]
WantedBy=default.target
```

#### Create systemd `.service` file

```bash
# linger has to be activated
ln -s ~/data/config/containers/caddy-dev/caddy-dev.container ~/.config/containers/systemd/caddy-dev.container

systemctl --user daemon-reload
```

#### Enable and start service

```bash
systemctl --user start caddy-dev.service
```

#### Verification

- https://dev-test.ilnmors.com
	- user_test (gruop: users): 403 Forbidden
	- admin_test (group: admins): File server