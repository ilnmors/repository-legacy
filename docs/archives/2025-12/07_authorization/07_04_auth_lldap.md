Tags: #os, #configuration, #network, #virtualization, #container, #security, #authentication, #authorization, #sso 

## LLDAP (Light LDAP)

LLDAP provides LDAP protocol as very light and modern way.  It supports not only main function of LDAP protocol such as Group, or User management but also web UI and RESTFul API. Additionally, it is very simple to set and manage and takes a small amount of resources. Following [here](../02_theory/02_05_sso.md) about the structure of LDAP.

### Secret management

File: 
	- ~/data/config/secrets/.secret.yaml

- Edit `.secret.yaml` with `edit_secret.sh`

```yaml
# ~/data/config/secrets/.secret.yaml
# LLDAP:
LLDAP_DATABASE_URL: postgres://ldap:$PASSWORD@postgresql.ilnmors.internal/ldap_db?sslmode=verify-full&sslrootcert=/etc/ssl/ldap/root_ca.crt # $PASSWORD=openssl rand -base64 32 value and it should be encoded as URL

LLDAP_LDAP_USER_PASSWORD: $PASSWORD

LLDAP_KEY_SEED: "$(LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32)"

LLDAP_JWT_SECRET: "$(LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32)"
```

```bash
# Podman secret

extract_secret.sh .secret.yaml -f LLDAP_DATABASE_URL | podman secret create LLDAP_DATABASE_URL -

extract_secret.sh .secret.yaml -f LLDAP_LDAP_USER_PASSWORD | podman secret create LLDAP_LDAP_USER_PASSWORD -

extract_secret.sh .secret.yaml -f LLDAP_JWT_SECRET | podman secret create LLDAP_JWT_SECRET -

extract_secret.sh .secret.yaml -f LLDAP_KEY_SEED | podman secret create LLDAP_KEY_SEED -
```

### Preparation

#### iptables and firewall rules

- Set iptables first, following [here](../03_common/03_02_iptables.md).
	- 636:6360: localhost nat
	- LDAPS will be only used localhost (Authelia), so PREROUTING doesn't require in nat table. nly OUTPUT requires in it.
- Set firewall rules first, following [here](Latest/05_firewall/05_04_opnsense_rules.md).

#### Create directory for container

```bash
mkdir -p ~/data/containers/ldap
chmod 700 ~/data/containers/ldap
setfacl -m d:g::0 ~/data/containers/ldap
setfacl -m d:o::0 ~/data/containers/ldap
setfacl -m u:auth:rwx ~/data/containers/ldap
setfacl -m u:100999:rwx ~/data/containers/ldap
setfacl -d -m u:auth:rwx ~/data/containers/ldap
setfacl -d -m u:100999:rwx ~/data/containers/ldap
mkdir ~/data/containers/ldap/{certs,data}

# After generating
sudo find ~/data/containers/ldap -type f -exec setfacl -m m::rw {} \;
sudo find ~/data/containers/ldap -type d -exec setfacl -m m::rwx {} \;
```

> lldap container executes as 1000:1000(lldap:lldap) permission in container. It is mapped host's 100999. Therefore, directories have to have ACL via `setfacl`

#### Add new domain in BIND

Following [here](../06_network/06_03_net_bind.md).

- net server
- file: ~/data/containers/bind/lib/db.ilnmors.internal
  
```ini
# ...
ldap     IN     CNAME     auth.ilnmors.internal.
# ...
```

```bash
# Adguard container has Requires=bind.service. When it restarted, then Adguard also restarted.
systemctl --user restart bind
```

#### Add new database and user

- Following [here](../08_development/08_02_dev_postgresql.md). LLDAP can use postgresql (Basic is SQLite).
- dev server

```bash
podman exec -it -u postgres postgresql psql -U postgres
> # Create user and database
> CREATE USER ldap WITH PASSWORD '$POSTGRES_LDAP_PASSWORD';
> CREATE DATABASE ldap_db;
> ALTER DATABASE ldap_db OWNER TO ldap;
> \du
> \l
```

#### Add information in caddy-auth

- Following [here](./07_03_auth_main_caddy.md).
- auth server
- File: ~/data/containers/caddy-auth/etc/Caddyfile

```ini
ldap.ilnmors.internal {
        import internal_tls
        import crowdsec_log
        reverse_proxy host.containers.internal:17170
}
```

```bash
# fix inconsistencies
podman exec caddy-auth caddy fmt --overwrite /etc/caddy/Caddyfile
# After Caddyfile setting is changed use this command.
podman exec caddy-auth caddy reload --config /etc/caddy/Caddyfile
```

#### Certificates configuration

- File: ~/data/containers/certs/root_ca.crt

- ACME setting (OPNsense)
    - Services:ACME Client:Certificates - Certificates - \[+\]
    - Common Name: ldap.ilnmors.internal
    - Description: ldap
    - ACME Account: ldap.ilnmors.internal
        > Even though provisioner's name includes `@`, it has to use as `.`.
        > 
        > i.e. `acme@ilnmors.internal` > `acme.ilnmors.internal`
    - Challenge Type: ilnmors.internal-dns-01-challenge
    - \[\*\] Auto Renewal
    - Automations: ldap-auto-acme, ldap-auto-restart

- Automations (OPNsense)
    - Services:ACME Client:Automations - Automation - \[+\]
    - Name: ldap-auto-acme / ldap-auto-reload
    - Description: ldap acme crt issue / reload ldap after crt is issued
    - Run Command: Upload certificate via SFTP / Remote command via SSH
    - SFTP Host: ldap.ilnmors.internal
    - Username: auth
    - Identity Type: ed25519
    - Remote Path(SFTP): /home/auth/data/containers/ldap/certs
    - Command(SSH): setfacl -m m::r /home/auth/data/containers/ldap/certs/ldap.ilnmors.internal/*  &&  systemctl --user restart ldap.service
    - `Show Identity`
        > Copy Required parameters `ssh-ed25519 ~~~ root@opnsense.ilnmors.internal`
        > 
        > Add parameters in net server's ~/.ssh/authorized_keys
    - `Test Connect` and `Save`

- SSH command will be applied after postgresql start.

### Podman Image

```bash
podman pull lldap/lldap:v0.6.2 # Do not use latest version to management
```

### Configuration file

- file:
    - ~/data/containers/ldap/certs/root_ca.crt
    - ~/data/containers/ldap/data/lldap_config.toml

### Initiating

```bash
podman run --rm \
--secret LLDAP_DATABASE_URL,type=env \
--secret LLDAP_KEY_SEED,type=env \
--secret LLDAP_JWT_SECRET,type=env \
--secret LLDAP_LDAP_USER_PASSWORD,type=env \
-e TZ="Asia/Seoul" \
-e LLDAP_LDAP_BASE_DN="dc=ilnmors,dc=internal" \
-v "$HOME"/data/containers/ldap/data:/data:rw \
-v "$HOME"/data/containers/ldap/certs:/etc/ssl/ldap:ro \
lldap/lldap:v0.6.2
# `Ctrl + C` exit

podman secret rm LLDAP_LDAP_USER_PASSWORD
```

### Quadlet

- File: 
	- ~/data/config/containers/ldap/ldap.container

```ini
# ~/data/config/containers/ldap/ldap.container
[Quadlet]
DefaultDependencies=false

[Unit]
Description=LDAP

After=caddy.service
Wants=caddy.service

[Service]
ExecStartPre=%h/data/config/scripts/wait-for-it.sh -h postgresql.ilnmors.internal -p 5432 -t 0
ExecStartPre=sleep 5

[Container]

Image=lldap/lldap:v0.6.2

ContainerName=ldap

# For LDAPS - 636 > 6360 iptables
PublishPort=6360:6360/tcp
# Web UI
PublishPort=17170:17170/tcp


Volume=%h/data/containers/ldap/data:/data:rw
Volume=%h/data/containers/ldap/certs:/etc/ssl/ldap:ro

# Default
Environment="TZ=Asia/Seoul"

# Domain
Environment="LLDAP_LDAP_BASE_DN=dc=ilnmors,dc=internal"

# LDAPS
Environment="LLDAP_LDAPS_OPTIONS__ENABLED=true"
Environment="LLDAP_LDAPS_OPTIONS__CERT_FILE=/etc/ssl/ldap/ldap.ilnmors.internal/fullchain.pem"
Environment="LLDAP_LDAPS_OPTIONS__KEY_FILE=/etc/ssl/ldap/ldap.ilnmors.internal/key.pem"

# SMTP options > you can set all of these at the /data/config.toml instead of Environment
# Only `LLDAP_SMTP_OPTIONS__PASSWORD` will be injected by secret
# LLDAP_SMTP_OPTIONS__ENABLE_PASSWORD_RESET=true
# LLDAP_SMTP_OPTIONS__SERVER=smtp.example.com
# LLDAP_SMTP_OPTIONS__PORT=465
# LLDAP_SMTP_OPTIONS__SMTP_ENCRYPTION=TLS
# LLDAP_SMTP_OPTIONS__USER=no-reply@example.com
# LLDAP_SMTP_OPTIONS__PASSWORD=PasswordGoesHere
# LLDAP_SMTP_OPTIONS__FROM=no-reply <no-reply@example.com>
# LLDAP_SMTP_OPTIONS__TO=admin <admin@example.com>

# Database
Secret=LLDAP_DATABASE_URL,type=env

# Secrets
Secret=LLDAP_KEY_SEED,type=env
Secret=LLDAP_JWT_SECRET,type=env

Label=diun.enable=true
Label=diun.watch_repo=true

[Install]
WantedBy=default.target
```

#### Create systemd `.service` file

```bash
# linger has to be activated
ln -s ~/data/config/containers/ldap/ldap.container ~/.config/containers/systemd/ldap.container

systemctl --user daemon-reload
```

#### Enable and start service

```bash
systemctl --user start ldap.service
```

### DB backup

- Following [here](../08_development/08_02_dev_postgresql.md).
- dev server

```bash
systemctl --user enable --now postgresql-data-backup@ldap.timer
```

> The data saved in postgresql are all LDAP data including all users, groups and hashed passwords. However, LLDAP_KEY_SEED and LLDAP_JWT_SECRET are not saved in postgresql. It is for container itself and it is used as Environment value in the container.

### Configuration

#### Access web UI and Login

- URL: https://ldap.ilnmors.internal
- ID: admin
- PW: $LLDAP_LDAP_USER_PASSWORD

#### Create the groups

- Groups - \[\+\] Create a group
	- Group: admins
	- Group: users
#### Create the authelia user

- Users: \[\+\] Create a user
	- Username (cn; uid): authelia
	- Display name: Authelia
	- First Name: Authelia
	- Last Name (sn): Service
	- Email (mail): authelia@ilnmors.internal
	- Password: "$(openssl rand -base64 32)"
- lldap_strict_readonly \[Add to group\]
	- This group allow search authority.
> Save the password in .secret.yaml

#### Create the normal user

- Users: \[\+\] Create a user
	-  Username (cn; uid): user
	- First Name: John
	- Last Name (sn): Doe
	- Email (mail): john_doe@ilnmors.internal
	- Password: "$PASSWORD"
- (admins|users) \[Add to group\]

> Custom schema in `User schema`, `Gropu schema` doesn't need to be added. This is for advanced function to add additional value such as `identity number` or `phone number`. Hardcoded schema, which means basic schema the lldap provides is enough to use Authelia.

> After all these steps, now you can integrate the Authelia for SSO.

### Usage of LDAP

#### Service Bind

LDAP call `login` as Bind. When the authelia Bind to the LDAP server, it can get the authority to search in `lldap_strict_readonly` group.

#### Search

authelia account has the authority to search, it can search to send the query. 

##### Flow of search

- Client (authelia) sends the query
	- `uid=user in dc=ilnmors,dc=ilnmors`
- LDAP server searches the DN of entry
	- `uid=user,ou=people,dc=ilnmors,dc=ilnmors`
- LDAP sends the DN to Client (authelia)

### Authelia's work flow

#### First login

##### User login query

User try to login on login page of Authelia.

- id: user
- password: 1234

##### Service Bind (Bind and search)

authelia binds to LLDAP server based on the information in configuration.yml.

- dn: authelia
- password: authelia's password

##### Search

authelia sends the query to LLDAP after bind. 
- `uid=user in dc=ilnmors,dc=internal`

##### Request

LLDAP server searches the entry and send the DN information query to authelia.

- `uid=user,ou=people,dc=ilnmors,dc=internal`

#### Verify the user login (Second login)

##### User Bind (Bind only)

authelia tries to bind LLDAP server based on the information that user input.

- dn: requested uid
- password: 1234

##### Verification from LLDAP

LLDAP verify the password from authelia with its hash value saved in LLDAP's database.

##### Request

LLDAP server sends the result as `Success` or `Fail`.

> Search authority is basic authority of user who binds to LDAP server. It is just the way to check success or fail bind is the charge of Authelia.