# wiki.js

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.wikijs`
  - Access infra server to create wikijs_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER wikijs WITH PASSWORD '<redacted>';
CREATE DATABASE wikijs_db;
ALTER DATABASE wikijs_db OWNER TO wikijs;
```

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'wikijs.oidc.secret'`
- Save this value in secrets.yaml in `wikijs.oidc.secret` and `wikijs.oidc.hash`
- !CAUTION! Don't update authelia with ansible-playbook before configuration

### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    connected_services:
      - ...
      - "wikijs"
```

## Configuration

### Access

- https://wiki.ilnmors.com
    - Administrator Email: admin@wiki.ilnmors.internal
    - Password: wikijs.il.password
    - Site URL: https://wiki.ilnmors.com
    - INSTALL

### Group configuration

- Administration: Groups: Guests: PERMISSIONS
    - Remove all permissions
- Administration: Groups: NEW GROUP
    - Users
- Administration: Groups: Users: PERMISSIONS
    - Grant all permission in CONTENT

- Administration: Groups: Users: PAGE RULES
    - Allow / Deny: Allow
    - Match: Path starts with
    - Path: empty value
    - Locale: Any / All
    - Permissions:
        - Grant all permission
    - Update Group

### OIDC configuration

- Administration: Modules: Authentication
    - Add Strategy: Generic OpenID Connect / OAuth2
        - Display Name: Authelia
        - client id: wikijs
        - client secret: wikijs.oidc.secret
        - Authorization Endpoint URL: https://authelia.ilnmors.com/api/oidc/authorization
        - Token Endpoint URL: https://authelia.ilnmors.com/api/oidc/token
        - User info Endpoint URL: https://authelia.ilnmors.com/api/oidc/userinfo
        - Skip User Profile: untoggled
        - Issure: https://authelia.ilnmors.com
        - Email Claim: email
        - Display Name Claim: displayName
        - Picture Claim: picture
        - Map Groups: untoggled
        - Groups Claim: groups
        - Registration: Allow self-registration: toggled
        - Assign to group: Users
    - Check: Callback URL / Redirect URI
    - Apply

- add Callback URL / Redirect URI to [authelia config](../../../config/services/containers/auth/authelia/config/authelia.yaml.j2)
    - update authelia

- logout from administrator

- login: Select Authentication Provider: Authelia

### Storage

- Administration: Modules: Stroage
    - Local File System
    - Path: /wiki/export
    - Apply

### Locale

- Administration: Site: Locale
    - Download what you needs.
    - Korean, Arabic, French ...
