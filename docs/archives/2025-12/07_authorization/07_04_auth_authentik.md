Tags: #os, #configuration, #network, #virtualization, #container, #security, #authentication, #authorization, #sso

## Authentik

Authentik is one of famous and strong open source idP solutions which support SSO, 2FA, LDAP, RADIUS, etc. It will be combining with Caddy-security module to apply SSO.

### Secret management

File: 
	- ~/data/config/secrets/.secret.yaml

- Edit `.secret.yaml` with `edit_secret.sh`

```yaml
# ~/data/config/secrets/.secret.yaml
# Authentik:
AUTHENTIK_SECRET_KEY: openssl rand -base64 32 value
AUTHENTIK_POSTGRESQL__PASSWORD: openssl rand -base64 32 value
```

```bash
# Podman secret
extract_secret.sh .secret.yaml -f AUTHENTIK_SECRET_KEY | podman secret create AUTHENTIK_SECRET_KEY -

extract_secret.sh .secret.yaml -f AUTHENTIK_POSTGRESQL__PASSWORD | podman secret create AUTHENTIK_POSTGRESQL__PASSWORD -
```

### Preparation

#### iptables and firewall rules

- Set iptables first, following [here](../03_common/03_02_iptables.md).
- Set firewall rules first, following [here](Latest/05_firewall/05_04_opnsense_rules.md).
#### Create directory for container

```bash
mkdir -p ~/data/containers/authentik
chmod 700 ~/data/containers/authentik
setfacl -m d:g::0 ~/data/containers/authentik
setfacl -m d:o::0 ~/data/containers/authentik
setfacl -m u:auth:rwx ~/data/containers/authentik
setfacl -m u:100999:rwx ~/data/containers/authentik
setfacl -d -m u:auth:rwx ~/data/containers/authentik
setfacl -d -m u:100999:rwx ~/data/containers/authentik
mkdir -p ~/data/containers/authentik/{backups,certs,media,templates}
# After generating
sudo find ~/data/containers/authentik -type f -exec setfacl -m m::rw {} \;
sudo find ~/data/containers/authentik -type d -exec setfacl -m m::rwx {} \;
```

> Authentik container executes as 1000:1000(authentik:authentik) permission in container. It is mapped host's 100999. Therefore, directories have to have ACL via `setfacl`

#### Add new domain in BIND

Following [here](../06_network/06_03_net_bind.md).

- net server
- file: ~/data/containers/bind/lib/db.ilnmors.internal
  
```ini
# ...
authentik     IN     CNAME     auth.ilnmors.internal.
# ...
```

```bash
# Adguard container has Requires=bind.service. When it restarted, then Adguard also restarted.
systemctl --user restart bind
```

#### Add new database and user

- Following [here](../08_development/08_02_dev_postgresql.md). Authentik uses postgresql.
- dev server

```bash
podman exec -it -u postgres postgresql psql -U postgres
> # Create user and database
> CREATE USER authentik WITH PASSWORD '$AUTHENTIK_POSTGRESQL__PASSWORD_value';
> CREATE DATABASE authentik_db;
> ALTER DATABASE authentik_db OWNER TO authentik;
> \du
> \l
```

#### Add information in caddy-auth

- Following [here](./07_03_auth_main_caddy.md).
- auth server
- File: ~/data/containers/caddy-auth/etc/Caddyfile
```ini
authentik.ilnmors.internal {
        import internal_tls
        import crowdsec_log
        reverse_proxy authentik.ilnmors.internal:9080
}
```

```bash
# After Caddyfile setting is changed use this command.
podman exec caddy-auth caddy reload --config /etc/caddy/Caddyfile
# fix inconsistencies
podman exec caddy-auth caddy fmt --overwrite /etc/caddy/Caddyfile
```
### Podman Image

```bash
podman pull ghcr.io/goauthentik/server:2025.10.0 # Do not use latest version to management
```

### Configuration file

- file:
    - ~/data/containers/authentik/certs/root_ca.crt

### Quadlet

- File: 
	- ~/data/config/containers/authentik/authentik-pod.pod
	- ~/data/config/containers/authentik/authentik.container
	- ~/data/config/containers/authentik/authentik-worker.container

```ini
# ~/data/config/containers/authentik.pod
[Quadlet]
DefaultDependencies=false

[Pod]
PodName=authentik

# web port
PublishPort=9080:9000/tcp
# LDAP port
#PublishPort=[set_port]:3389
# Prometheus Port
#PublishPort=[set_port]:9300
```

```ini
# ~/data/config/containers/authentik/authentik.container
[Quadlet]
DefaultDependencies=false

[Unit]
Description=Authentik - Server

After=caddy.service
Wants=caddy.service

[Service]
ExecStartPre=%h/data/config/scripts/wait-for-it.sh -h postgresql.ilnmors.internal -p 5432 -t 0
ExecStartPre=sleep 5

[Container]
Pod=authentik.pod

Image=ghcr.io/goauthentik/server:2025.10.0

ContainerName=authentik-server

# Change default http port from 9000 to 9080 - in pod


Volume=%h/data/containers/authentik/media:/media:rw
Volume=%h/data/containers/authentik/certs:/certs:ro
Volume=%h/data/containers/authentik/templates:/templates:rw
Volume=%h/data/containers/authentik/backups:/backups:rw

# Default
Environment="TZ=Asia/Seoul"
# Listen
#AUTHENTIK_LISTEN__HTTP=0.0.0.0:9000
# LDAP > 0.0.0.0:3389
# METRICS > 0.0.0.0:9300
# AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS > `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `fe80::/10`, `::1/128`

# DB connection - This can be changed as hot-reloading, however adding or removing needs restart.
Environment="AUTHENTIK_POSTGRESQL__HOST=postgresql.ilnmors.internal"
Environment="AUTHENTIK_POSTGRESQL__PORT=5432"
# Password will be injected as secret
Environment="AUTHENTIK_POSTGRESQL__USER=authentik"
Environment="AUTHENTIK_POSTGRESQL__NAME=authentik_db"

# SSL DB configuration
Environment="AUTHENTIK_POSTGRESQL__SSLMODE=verify-full"
Environment="AUTHENTIK_POSTGRESQL__SSLROOTCERT=/certs/root_ca.crt"
# This homelab doesn't use mTLS, therefore do not set `AUTHENTIK_POSTGRESQL__SSLCERT` and `AUTHENTIK_POSTGRESQL__SSLKEY`

# Media configuration - 'file' or 's3'
Environment="AUTHENTIK_STORAGE__MEDIA_BACKEND=file"

# Email configuration - after generate local Email services
# AUTHENTIK_EMAIL__HOST=ilnmors.internal
# AUTHENTIK_EMAIL__PORT=25
# AUTHENTIK_EMAIL__USERNAME=authentik
# AUTHENTIK_EMAIL__USE_TLS=true
# AUTHENTIK_EMAIL__FROM=authentik@ilnmors.internal


Secret=AUTHENTIK_SECRET_KEY,type=env
Secret=AUTHENTIK_POSTGRESQL__PASSWORD,type=env

# Start server
Exec=server

Label=diun.enable=true
Label=diun.watch_repo=true

[Install]
WantedBy=default.target
```

```ini
# ~/data/config/containers/authentik/authentik-worker.container
[Quadlet]
DefaultDependencies=false

[Unit]
Description=Authentik - worker

After=authentik-server.service
Requires=authentik-server.service

[Container]
Pod=authentik.pod

Image=ghcr.io/goauthentik/server:2025.10.0

ContainerName=authentik-worker

# Change default http port from 9000 to 9080 - in pod


Volume=%h/data/containers/authentik/media:/media:rw
Volume=%h/data/containers/authentik/certs:/certs:ro
Volume=%h/data/containers/authentik/templates:/templates:rw
Volume=%h/data/containers/authentik/backups:/backups:rw

# Default
Environment="TZ=Asia/Seoul"
# Listen
#AUTHENTIK_LISTEN__HTTP=0.0.0.0:9000
# LDAP > 0.0.0.0:3389
# METRICS > 0.0.0.0:9300
# AUTHENTIK_LISTEN__TRUSTED_PROXY_CIDRS > `127.0.0.0/8`, `10.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16`, `fe80::/10`, `::1/128`

# DB connection - This can be changed as hot-reloading, however adding or removing needs restart.
Environment="AUTHENTIK_POSTGRESQL__HOST=postgresql.ilnmors.internal"
Environment="AUTHENTIK_POSTGRESQL__PORT=5432"
# Password will be injected as secret
Environment="AUTHENTIK_POSTGRESQL__USER=authentik"
Environment="AUTHENTIK_POSTGRESQL__NAME=authentik_db"

# SSL DB configuration
Environment="AUTHENTIK_POSTGRESQL__SSLMODE=verify-full"
Environment="AUTHENTIK_POSTGRESQL__SSLROOTCERT=/certs/root_ca.crt"
# This homelab doesn't use mTLS, therefore do not set `AUTHENTIK_POSTGRESQL__SSLCERT` and `AUTHENTIK_POSTGRESQL__SSLKEY`

# Media configuration - 'file' or 's3'
Environment="AUTHENTIK_STORAGE__MEDIA_BACKEND=file"

# Email configuration - after generate local Email services
# AUTHENTIK_EMAIL__HOST=ilnmors.internal
# AUTHENTIK_EMAIL__PORT=25
# AUTHENTIK_EMAIL__USERNAME=authentik
# AUTHENTIK_EMAIL__USE_TLS=true
# AUTHENTIK_EMAIL__FROM=authentik@ilnmors.internal


Secret=AUTHENTIK_SECRET_KEY,type=env
Secret=AUTHENTIK_POSTGRESQL__PASSWORD,type=env

# Start worker
Exec=worker

[Install]
WantedBy=default.target
```

> All configurations, except DB connection information will be saved in postgresql. Do not set Environment Variables. It has the first priority, it will override all configuration from web UI.
#### Create systemd `.service` file

```bash
# linger has to be activated
ln -s ~/data/config/containers/authentik/authentik-pod.pod ~/.config/containers/systemd/authentik-pod.pod

ln -s ~/data/config/containers/authentik/authentik-server.container ~/.config/containers/systemd/authentik.container

ln -s ~/data/config/containers/authentik/authentik-worker.container ~/.config/containers/systemd/authentik-worker.container

systemctl --user daemon-reload
```

#### Enable and start service

```bash
systemctl --user start authentik.service
```

### Web UI configuration

#### Access web UI and initial setting

- URL: https://authentik.ilnmors.internal/if/flow/initial-setup/

> If you can't initialize the authentik at the first time, `DROP DATABASE authentik_db;` and recreate database after authentik container stop.

#### Initial setting wizard

- Email: Admin-email
	- user@example.com
- Password: password



