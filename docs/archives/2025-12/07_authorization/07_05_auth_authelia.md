Tags: #os, #configuration, #network, #virtualization, #container, #security, #authentication, #authorization, #sso 

## Authelia

Authelia is one of the open source authentication and authorization server which can management IAM(Identity and Access Management). It supports SSO and even OpenID Connect 1.0 Provider (idP) on OAuth 2.0. Authelia uses its backend database as the file or LDAP server. LLDAP server is this backend database for authelia in this homelab.

### Secret management

File: 
	- ~/data/config/secrets/.secret.yaml

- Edit `.secret.yaml` with `edit_secret.sh`

```yaml
# ~/data/config/secrets/.secret.yaml
# Authelia:
AUTHELIA_JWT_SECRET: "$(LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32)"

AUTHELIA_SESSION_SECRET: "$(LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32)"

AUTHELIA_STORAGE_SECRET: "$(LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32)"

AUTHELIA_HMAC_SECRET: "$(openssl rand -base64 32)"

AUTHELIA_JWKS_RS256: |
"$(podman run --rm \
 -v ~/data/containers/authelia/certs:/output:rw \
 authelia/authelia:4.39.13 \
 authelia crypto pair ecdsa \
 generate --directory /output/ecdsa)"

AUTHELIA_JWKS_ES256: |
"$(podman run --rm \
 -v ~/data/containers/authelia/certs:/output:rw \
 authelia/authelia:4.39.13 \
 authelia crypto pair rsa \
 generate --directory /output/rsa)"

# content of private.pem and rm private.pem/ leave public.pem

# This is set on LLDAP server
AUTHELIA_LDAP_PASSWORD: "$(openssl rand -base64 32)"

POSTGRES_AUTHELIA_PASSWORD: "$(openssl rand -base64 32)"
```

```bash
# Podman secret

extract_secret.sh .secret.yaml -f AUTHELIA_JWT_SECRET | podman secret create AUTHELIA_JWT_SECRET -

extract_secret.sh .secret.yaml -f AUTHELIA_SESSION_SECRET | podman secret create AUTHELIA_SESSION_SECRET -

extract_secret.sh .secret.yaml -f AUTHELIA_STORAGE_SECRET | podman secret create AUTHELIA_STORAGE_SECRET -

extract_secret.sh .secret.yaml -f AUTHELIA_HMAC_SECRET | podman secret create AUTHELIA_HMAC_SECRET -

extract_secret.sh .secret.yaml -f AUTHELIA_LDAP_PASSWORD | podman secret create AUTHELIA_LDAP_PASSWORD -

extract_secret.sh .secret.yaml -f POSTGRES_AUTHELIA_PASSWORD | podman secret create POSTGRES_AUTHELIA_PASSWORD -

extract_secret.sh .secret.yaml -f AUTHELIA_JWKS_RS256 | podman secret create AUTHELIA_JWKS_RS256 -

extract_secret.sh .secret.yaml -f AUTHELIA_JWKS_ES256 | podman secret create AUTHELIA_JWKS_ES256 -
```

### Preparation

#### iptables and firewall rules

- Set iptables first, following [here](../03_common/03_02_iptables.md).
	- 636:6360: localhost nat
	- LDAPS will be only used localhost (Authelia), so PREROUTING doesn't require in nat table. nly OUTPUT requires in it.
- Set firewall rules first, following [here](Latest/05_firewall/05_04_opnsense_rules.md).

#### Create directory for container

```bash
mkdir -p ~/data/containers/authelia/{certs,config}
chmod -R 700 ~/data/containers/authelia
```

> authelia container executes as 0:0(root:root) permission in container. It is mapped host's UID. Therefore, directories don't have to have ACL via `setfacl`

#### Add new domain in BIND

Following [here](../06_network/06_03_net_bind.md).

- net server
- file: ~/data/containers/bind/lib/db.ilnmors.internal
  
```ini
# ...
authelia     IN     CNAME     auth.ilnmors.internal.
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
> CREATE USER authelia WITH PASSWORD '$POSTGRES_AUTHELIA_PASSWORD';
> CREATE DATABASE authelia_db;
> ALTER DATABASE authelia_db OWNER TO authelia;
> \du
> \l
```

#### Add information in caddy-auth

- Following [here](./07_03_auth_main_caddy.md).
- auth server
- File: ~/data/containers/caddy-auth/etc/Caddyfile
```ini
authelia.ilnmors.com {
		import crowdsec_log
		route {
			crowdsec
			reverse_proxy host.containers.internal:9091
		}
}

authelia.ilnmors.internal {
        import internal_tls
        import crowdsec_log
        route {
			crowdsec
			reverse_proxy host.containers.internal:9091
		}
}
```

```bash
# fix inconsistencies
podman exec caddy-auth caddy fmt --overwrite /etc/caddy/Caddyfile
# After Caddyfile setting is changed use this command.
podman exec caddy-auth caddy reload --config /etc/caddy/Caddyfile
```

### Podman Image

```bash
podman pull authelia/authelia:4.39.13 # Do not use latest version to management
```

### Configuration file

- file:
    - ~/data/containers/authelia/certs/root_ca.crt
    - ~/data/containers/authelia/config/configuration.yml

#### configuration.yml

```yaml
# authelia configuration.yml
---
# certificates setting
certificates_directory: '/etc/ssl/authelia/'

# them setting - light, dark, grey, auto.
theme: 'auto'

# Server configuration
server:
  # TLS will be applied on caddy
  address: 'tcp://:9091/'

# Log configuration
log:
  level: 'debug'
  #file_path: 'path/of/log/file' - without this option, using stdout

# TOTP configuration
totp:
  # issure option is for 2FA app. It works as identifier. "My homelab' or 'ilnmors.internal', 'Authelia - ilnmors'
  issuer: 'ilnmors.internal'

# Identity validation confituration
identity_validation:
  reset_password:
    jwt_secret: '' # $AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE

# Authentication backend provider configuration
authentication_backend:
  ldap:
    # ldaps uses 636 -> NAT automatically change port 636 in output packet -> 6360 which lldap server uses.
    address: 'ldaps://ldap.ilnmors.internal'
    implementation: 'lldap'
    # tls configruation, it uses certificates_directory's /etc/ssl/authelia/root_ca.crt
    tls:
      server_name: 'ldap.ilnmors.internal'
      skip_verify: false
    # LLDAP base DN
    base_dn: 'dc=ilnmors,dc=internal'
    additional_users_dn: 'ou=people'
    additional_groups_dn: 'ou=groups'
    # LLDAP filters
    users_filter: '(&(|({username_attribute}={input})({mail_attribute}={input}))(objectClass=person))'
    groups_filter: '(&(member={dn})(objectClass=groupOfNames))'
    # LLDAP bind account configuration
    user: 'uid=authelia,ou=people,dc=ilnmors,dc=internal'
    password: '' # $AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE
    # LLDAP schema mapping
    attributes:
      username: 'uid'
      display_name: 'displayName'
      mail: 'mail'
      group_name: 'cn'

# Access control configuration
access_control:
  default_policy: 'deny'
  rules:
    # authelia portal
    - domain: 'authelia.ilnmors.internal'
      policy: 'bypass'
    - domain: 'authelia.ilnmors.com'
      policy: 'bypass'

# Session provider configuration
session:
  secret: '' # $AUTHELIA_SESSION_SECRET_FILE
  expiration: '24 hours' # Session maintains for 24 hours
  inactivity: '2 hours' # Session maintains for 2 hours without actions
  cookies:
    - name: 'authelia_private_session'
      domain: 'ilnmors.internal'
      authelia_url: 'https://authelia.ilnmors.internal'
      same_site: 'lax'
    - name: 'authelia_public_session'
      domain: 'ilnmors.com'
      authelia_url: 'https://authelia.ilnmors.com'
      same_site: 'lax'

# This authelia doesn't use Redis.

# Storage provider configuration
storage:
  encryption_key: '' # $AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE
  postgres:
    address: 'tcp://postgresql.ilnmors.internal:5432'
    database: 'authelia_db'
    username: 'authelia'
    password: '' # $AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE
    tls:
      server_name: 'postgresql.ilnmors.internal'
      skip_verify: false

# Notification provider
notifier:
  filesystem:
    filename: '/config/notification.txt'
# Following goal, After `Postfix` and `Dovecot` setting.
#smtp:
  #address: 'smtp.ilnmors.internal'

# OIDC preperation
# Identity provisioner configuration
#identity_providers:
#  oidc:
#    hmac_secret: '' # $AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE
#    jwks:
#      - algorithm: 'RS256'
#        use: 'sig'
#        key: {{/* {{ secret "/run/secrets/AUTHELIA_JWKS_RS256" | mindent 10 "|" | msquote }} /*}}
#      - algorithm: 'ES256'
#        use: 'sig'
#        key: {{/* {{ secret "/run/secrets/AUTHELIA_JWKS_ES256" | mindent 10 "|" | msquote }} /*}}
#    clients:
...
```

### Quadlet

- File: 
	- ~/data/config/containers/authelia/authelia.container

```ini
# ~/data/config/containers/authelia/authelia.container
[Quadlet]
DefaultDependencies=false

[Unit]
Description=Authelia

After=caddy.service
Wants=caddy.service
After=ldap.service
Requires=ldap.service

[Service]
ExecStartPre=%h/data/config/scripts/wait-for-it.sh -h localhost -p 6360 -t 0
ExecStartPre=sleep 5

[Container]

Image=authelia/authelia:4.39.13

ContainerName=authelia

AddHost=ldap.ilnmors.internal:host-gateway

# Web UI
PublishPort=9091:9091/tcp


Volume=%h/data/containers/authelia/config:/config:rw
Volume=%h/data/containers/ldap/certs:/etc/ssl/authelia:ro

# Default
Environment="TZ=Asia/Seoul"
# Enable Go template engine
# !CAUTION!
# If this environment were enabled, you would have to use {{/* ... /*}} for {{ go_filter }} options. Go engine always processes its own grammar first.
Environment="X_AUTHELIA_CONFIG_FILTERS=template"

# Encryption

## JWT
Environment="AUTHELIA_IDENTITY_VALIDATION_RESET_PASSWORD_JWT_SECRET_FILE=/run/secrets/AUTHELIA_JWT_SECRET"

Secret=AUTHELIA_JWT_SECRET,target=/run/secrets/AUTHELIA_JWT_SECRET

## Session
Environment="AUTHELIA_SESSION_SECRET_FILE=/run/secrets/AUTHELIA_SESSION_SECRET"

Secret=AUTHELIA_SESSION_SECRET,target=/run/secrets/AUTHELIA_SESSION_SECRET

## Storage
Environment="AUTHELIA_STORAGE_ENCRYPTION_KEY_FILE=/run/secrets/AUTHELIA_STORAGE_SECRET"

Secret=AUTHELIA_STORAGE_SECRET,target=/run/secrets/AUTHELIA_STORAGE_SECRET

# OIDC (HMAC, JWKS)

# Environment="AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE=/run/secrets/AUTHELIA_HMAC_SECRET"

# Secret=AUTHELIA_HMAC_SECRET,target=/run/secrets/AUTHELIA_HMAC_SECRET

# Secret=AUTHELIA_JWKS_RS256,target=/run/secrets/AUTHELIA_JWKS_RS256

# Secret=AUTHELIA_JWKS_ES256,target=/run/secrets/AUTHELIA_JWKS_ES256

# LDAP
Environment="AUTHELIA_AUTHENTICATION_BACKEND_LDAP_PASSWORD_FILE=/run/secrets/AUTHELIA_LDAP_PASSWORD"

Secret=AUTHELIA_LDAP_PASSWORD,target=/run/secrets/AUTHELIA_LDAP_PASSWORD

# Database
Environment="AUTHELIA_STORAGE_POSTGRES_PASSWORD_FILE=/run/secrets/POSTGRES_AUTHELIA_PASSWORD"

Secret=POSTGRES_AUTHELIA_PASSWORD,target=/run/secrets/POSTGRES_AUTHELIA_PASSWORD

Label=diun.enable=true
Label=diun.watch_repo=true

[Install]
WantedBy=default.target
```

#### Create systemd `.service` file

```bash
# linger has to be activated
ln -s ~/data/config/containers/authelia/authelia.container ~/.config/containers/systemd/authelia.container

systemctl --user daemon-reload
```

#### Enable and start service

```bash
systemctl --user start authelia.service
```

### DB backup

- Following [here](../08_development/08_02_dev_postgresql.md).
- dev server

```bash
systemctl --user enable --now postgresql-data-backup@authelia.timer
```

### Verification

- Web UI: 
	- https://authelia.ilnmors.internal
	- https://authelia.ilnmors.com

- Login with LLDAP's User
	- Login: LLDAP User
	- Password: LLDAP Password

- Check the session

### Apply Forward_Auth

Basically, OIDC will be used in this homelab for the application which supports OIDC natively. However, some applications don't support OIDC or even login system. Therfore, Forward_Auth function in Caddy is used for authentication of those services.

#### Configuration files

- File:
	- ~/data/containers/caddy-auth/etc/Caddyfile
	- ~/data/containers/authelia/config/configuration.yml

#### Caddy

```ini
# Caddyfile

# ...

# Foward auth test in local
test-admin.ilnmors.com {
	import crowdsec_log
	route {
		crowdsec
		forward_auth host.containers.internal:9091 {
			# Authelia Forward Auth endpoint URI
			uri /api/authz/forward-auth
			copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
		}
		# back end service
		root * /usr/share/caddy
		file_server
	}
}

# Forward auth test in local
test-default.ilnmors.com {
	import crowdsec_log
	route {
		crowdsec
		forward_auth host.containers.internal:9091 {
			# Authelia Forward Auth endpoint URI
			uri /api/authz/forward-auth
			copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
		}
		# back end service
		root * /usr/share/caddy
		file_server
	}
}

# ...
```

#### Authelia

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
    - domain: 'test-admin.ilnmors.com'
      policy: 'one_factor'
	  # Access control for Forward_Auth
	  subject:
	    - 'group:admins'
	- domain: 'test-default.ilnmors.com'
      policy: 'one_factor'
	  # Access control for Forward_Auth
	  subject:
	    - 'group:admins'
	    - 'group:users'

session:
	secret: '' # $AUTHELIA_SESSION_SECRET_FILE
	cookies:
		- name: 'authelia_internal_session'
		  domain: 'ilnmors.internal'
		  authelia_url: 'https://authelia.ilnmors.internal'
		  # When login succeed, redirect
		  # default_redirection_url: 'https://authelia.ilnmors.internal'
		  same_site: 'lax'
		- name: 'authelia_com_session'
		  domain: 'ilnmors.com'
		  authelia_url: 'https://authelia.ilnmors.com' 
		  # default_redirection_url: 'https://authelia.ilnmors.com'
		  same_site: 'lax'
# ...
```

#### Verification

- https://test-admin.ilnmors.com
	- user_test (gruop: users): 403 Forbidden
	- admin_test (group: admins): File server
- https://test-default.ilnmors.com
	- admin_test (Just move): File server
	- user_test (Session initiating): File server

---

### OIDC

```bash
openssl rand -base64 32
# Add this value to .secret.yaml
# APP_OIDC_KEY: secret value
# Make the hash value of this secret
# It is needed or not depends on app

extract_secret.sh .secret.yaml -f APP_OIDC_KEY | podman secret create APP_OIDC_KEY -

# Copy this value and paste next to client_secret: in configuration.yml

# Hash value generate
extract_secret.sh .secret.yaml -f CADDY_OIDC_KEY
> secret value

podman run --rm \
authelia/authelia:4.39.13 authelia
 rypto hash generate --password secret_value --no-confirm
 
# Hash value validate
podman run --rm authelia/authelia:4.39.13 authelia crypto hash validate --password secret_value -- 'HASH_VALUE'
> The password matches the digest.
```

##### Authelia

- Remove annotation of OIDC in container file

```ini
# ~/data/config/containers/authelia/authelia.container
# ...
# OIDC (HMAC, JWKS)

Environment=AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE=/run/secrets/AUTHELIA_HMAC_SECRET"

Secret=AUTHELIA_HMAC_SECRET,target=/run/secrets/AUTHELIA_HMAC_SECRET

Secret=AUTHELIA_JWKS_RS256,target=/run/secrets/AUTHELIA_JWKS_RS256

Secret=AUTHELIA_JWKS_ES256,target=/run/secrets/AUTHELIA_JWKS_ES256
# Remove annotation

# ...
```

- Fix the configuration.yml

```yaml
---
# certificates setting

# ...

# Identity provisioner configuration
identity_providers:
  oidc:
    hmac_secret: '' # $AUTHELIA_IDENTITY_PROVIDERS_OIDC_HMAC_SECRET_FILE
    jwks:
      - algorithm: 'RS256'
        use: 'sig'
        key: {{ secret "/run/secrets/AUTHELIA_JWKS_RS256" | mindent 10 "|" | msquote }}
      - algorithm: 'ES256'
        use: 'sig'
        key: {{ secret "/run/secrets/AUTHELIA_JWKS_ES256" | mindent 10 "|" | msquote }}
    clients:
      - client_id: 'app'
        client_name: 'app'
        # It depends on application
        client_secret: 'HASH_VALUE'
        # If there were not client secret, public should be `true`
        public: \[ true | false \]
        response_types:
          - 'code'
        scopes:
          - 'openid'
          - 'profile'
          - 'email'
          - 'groups'
        redirect_uris:
          - 'https://app.ilnmors.com/oauth2/callback
          - 'https://app.ilnmors.com/'
        token_endpoint_auth_method: 'client_secret_post | client_secret_basic'
        authorization_policy: 'one_factor'
...
```

```bash
# restart the service
systemctl --user daemon-reload
systemctl --user restart authelia
```

#### Caddy

- Add the reverse proxy.

```ini
# Caddyfile
# ~/data/containers/caddy-auth/etc/Caddyfile

# ...
app.ilnmors.com {
	import crowdsec_log
	route {
		crowdsec
		# X-Forward-Host Domain doesn't need to appy on DNS
		header_up X-Forwarded-Host app.app.ilnmors.internal
		reverse_porxy app.ilnmors.internal
	}
}
# ...
```

```ini
# app server's sidecar caddy

app.ilnmors.internal
{
     import internal_tls
     @notes header X-Forwarded-Host app.app.ilnmors.internal
     reverse_proxy @notes host.containers.internal:3000
}
```

- Fix Caddyfile format and restart service

```bash
# fix inconsistencies
podman exec caddy-auth caddy fmt --overwrite /etc/caddy/Caddyfile
# After Caddyfile setting is changed use this command.
systemctl --user daemon-reload
systemctl --user restart caddy-auth
```

#### Verification

- Following.