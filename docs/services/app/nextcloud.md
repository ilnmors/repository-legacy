# Nextcloud

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.nextcloud`
  - Access infra server to create nextcloud_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER nextcloud WITH PASSWORD '<redacted>';
CREATE DATABASE nextcloud_db;
ALTER DATABASE nextcloud_db OWNER TO nextcloud;
```

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'nextcloud.oidc.secret'`
- Save this value in secrets.yaml in `nextcloud.oidc.secret` and `nextcloud.oidc.hash`

### Create admin password

- Create the secret with `openssl rand -base64 32`
- Save this value in secrets.yaml in `nextcloud.admin-local.password`

### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    connected_services:
      - ...
      - "nextcloud"
```

## Configuration

### Access

- https://nextcloud.ilnmors.com
  - login with admin-local

### Disable and enable apps

- Profile: Apps: Your apps: Disable
  - Photo
  - dashboard

- Profile: Apps: Search
  - OpenID Connect user backend
  - Calendar
  - Contacts
  - Deck
  - Tasks
  - Mail
  - Nextcloud Office

### OIDC and DB Configuration

```bash
podman exec -u www-data nextcloud php occ user_oidc:provider Authelia \
  --clientid="nextcloud" \
  --clientsecret="nextcloud.oidc.secret" \
  --discoveryuri="https://authelia.ilnmors.com/.well-known/openid-configuration" \
  --scope="openid profile email groups" \
  --unique-uid=0 \
  --mapping-uid="preferred_username" \
  --mapping-display-name="name" \
  --mapping-email="email" \
  --mapping-groups="groups" \
  --group-whitelist-regex="/^users$/" \
  --group-provisioning=1

podman exec -u www-data nextcloud php occ db:add-missing-indices
podman exec -u www-data nextcloud php occ db:add-missing-columns
podman exec -u www-data nextcloud php occ db:add-missing-primary-keys
```

### Account configuration

- Profile: Accounts:
  - allocate admin group for admin users

#### Disable System addressbook expose

- Profile: Administration Settings: Groupware: System Address Book
  - Disable `Enable system address book` option

## Security warning in Nextcloud (ignored)

### trusted_proxies option
- Nextcloud wants admin to set `trusted_proxies` via forwarded ip header.
  - In current system, app vm explicitly prevents access the nextcloud container outside of vm.
  - trusted_proxy ip address will be definitely 169.254.1.2 (caddy's APIPA address which is used in PASTA network), so it is not distinguished from other containers.
  - Therefore, it doesn't need to be set.

### HSTS option
- This system is already main - sidecar reverse proxy system, and main proxy automatically changes http requests to https request (Caddyfile listens https).
  - main - sidecar communication is also on https via internal certificate.
  - Therefore, it doesn't need to be set.
