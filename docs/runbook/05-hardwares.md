# Hardware

All hardware configuration is set after fw vm. The MAC address of hardware is reservated on kea-dhcp.

## Vlan switch

### Access VLAN switch

- http://switch.ilnmors.internal (192.168.1.2, KEA-DHCP, Only IPv4 support)
    - before set ipv6, use ip4 address instead of FQDN
    - id: admin, password: admin
    - new password: switch.password

### Set VLAN
- VLAN:802.1Q VLAN
    - `[x]` Enable - Apply
    - VLAN client
        - id 1
        - name default > client
        - member (Untagged)
            - Port 1 (Trunk, untagged): Linux bridge is already process untagged packet as id 1
            - Port 3
            - Port 4
            - Port 5
            - Port 6
            - Port 7
            - Port 8
    - VLAN server
        - id 10
        - name server
        - member
            - Port 1 (Trunk, tagged)
    - VLAN user
        - id 20
        - name user
        - member
            - Port 1 (Trunk, tagged)
            - Port 2 (Not a member of client vlan, untagged)

- VLAN:802.1Q VLAN PVID setting
    - Port 2
        - PVID 20

### Verify VLAN configuration

- Manually set consol ip as user
- Connect console to Port 2
- Check internet connection


## DSM (DS124)

- https://finds.synology.com/# (192.168.1.11, KEA-DHCP)
    - Install DSM

### Initial configuration
- Device name: ilnmorsNAS
- Administrator account: il
- Password: dsm.il.password

- automatical update
- synology account - skip, skip anyway
- opt disagree

### Storage

- Storage Manager:Storage:Create:btrfs - Create

### IP address

Kea in fw already reserved DSM's IP. However it is necessary to set IP address statically for stable operation.

- Control Panel:Network:Network Interface:LAN
    - Edit:IPv4:Use manual configuration
    - Edit:IPv6:Use manual configuration

### Certificates

- Control Panel:Security:Certificate
    - Replace an existing certificate:synology
        - Description: ilnmors.internal
        - Private Key
        - Certificate
        - Intermediate certificate
    - Edit: For: Set as default certificate
    - Setting (!CAUTION!)
        - Even though you set the certificate as default, you have to set certificate for each services.
        - configure: service: certificate: nas.ilnmors.internal

## Authelia OIDC

- **!CAUTION!** It can be set after authelia is implemented
- Following [here](../../config/services/containers/auth/authelia/config/authelia.yaml.j2) for Authelia configuration
- Control Panel:Domain/LDAP:SSO Client
    - Login Settings: `[x]` Select SSO by default on the login page
    - Services
        - `[x]` Enable OpenID Connect SSO service
        - OpenID Connect SSO Settings
            - Profile: OIDC
            - Account type: Domain/LDAP/local
            - Name: Authelia
            - Well-Known URL: https://authelia.ilnmors.com/.well-known/openid-configuration
            - Application ID: dsm (what you designated)
            - Application Secret: secret value
            - Redirect URI: https://nas.ilnmors.internal:5001
            - Authorization scope: openid profile groups email
            - Username claim: preferred_username
- Match the user name (ID) in DSM and lldap id.

### Kopia in DSM

#### Upload Kopia repository to DSM

- Directory
    - Control Panel:shared folder: docker
    - Create: docker/kopia - permission: everyone rwx - inheretence to sub directories

- Container manager
    - Package Center:Conatiner manager:install

- Upload repository directory from console to DSM
    - docker/kopia/repository

- Add certificate - DSM reverse proxy cannot deal with gRPC
    - /docker/kopia/config/ssl/nas.key
    - /docker/kopia/config/ssl/nas.crt (including intermediate crt)

- container manager:images:import
    - kopia/kopia
    - tags: {{ version['packages']['kopia'] }}
- run
    - image: kopia/kopia
    - containername: kopia-server
    - `[x]` Enable auto restart
    - port: 51515:51515
    - volume: /docker/kopia/config:/app/config:rw
    - volume: /docker/kopia/cache:/app/cache:rw
    - volume: /docker/kopia/logs:/app/logs:rw
    - volume: /docker/kopia/repository:/repository:rw
    - environment: KOPIA_PASSWORD=$KOPIA.REPOSITORY
    - command: server start --no-ui --tls-cert-file=/app/config/ssl/nas.crt --tls-key-file=/app/config/ssl/nas.key --address=0.0.0.0:51515 --log-level=info 
- action:Terminal:Create
```bash
kopia repository connect filesystem \
--path=/repository \
--override-username="il" \
--override-hostname="nas.ilnmors.internal"
```
- action:restart

- Set firewall nftables
- Remove kopia_tmp dir from console

### Connection from client

#### Structure

Repository directory - encrypted by server KOPIA_PASSWORD as master key of repository

Server manage ACL with user password, user's KOPIA_PASSWORD. When server verify user with their password, server works with its repository password.

Repository - (Repository key; master key) -  Server - (User key; access key) - Client

- Client knows its access password as KOPIA_PASSWORD to access server. It doesn't know master key, server's KOPIA_PASSWORD. server will control repository by its KOPIA_PASSWORD. their name is the same but it is different.

#### Access

```bash
# Console
# you have to use `'` not `"`
KOPIA_PASSWORD='$kopia.user.user_name' \ 
/usr/bin/kopia repository connect server \
--url=https://nas.ilnmors.internal:51515 \
--override-username=console \
--override-hostname=console.ilnmors.internal
# This makes repository.config on ~/.config/kopia
# verify with kopia server acl list command

# infra or app
## /etc/secrets/$KOPIA_UID/kopia.env
KOPIA_PASSWORD={{ hostvars['console']['kopia']['user'][node['name']] }}
KOPIA_CONFIG_PATH=/etc/kopia/repository.config
KOPIA_CACHE_DIRECTORY=/var/cache/kopia
KOPIA_LOG_DIR=/var/cache/kopia/logs
KOPIA_CHECK_FOR_UPDATES=false
## .service file
BindReadOnlyPaths=/path/to/backup
# In root namescope, %u always bring 0
BindPaths=/etc/kopia
BindPaths=/etc/secrets/{{ kopia_uid }}
BindPaths=/var/cache/kopia
EnvironmentFile=/etc/secrets/{{ kopia_uid }}/kopia.env

ExecStartPre=/usr/bin/kopia repository connect server \
    --url=https://{{ services['kopia']['domain'] }}.{{ domain['internal'] }}:{{ services['kopia']['ports']['https'] }} \
    --override-username={{ node['name'] }} \
    --override-hostname={{ node['name'] }}.{{ domain['internal'] }}

ExecStart=/usr/bin/kopia snapshot create \
    /path/to/backup
```

### Check kopia snapshot

```bash
# snapshot id check
kopia snapshot list [--all]
# Snapshot ID check
kopia ls -l [-r: for recursive] $SNAPSHOT_ID
kopia show -l $SNAPSHOT_ID/file/path
# or
kopia show -l $FILE_ID
```

### Restore

```bash
mkdir -p /mnt/kopia
kopia mount [$SNAPSHOT_ID|all] kopia &
```
