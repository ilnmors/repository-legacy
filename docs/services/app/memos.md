# Memos

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.memos`
  - Access infra server to create memos_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER memos WITH PASSWORD '<redacted>';
CREATE DATABASE memos_db;
ALTER DATABASE memos_db OWNER TO memos;
```

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'memos.oidc.secret'`
- Save this value in secrets.yaml in `memos.oidc.secret` and `memos.oidc.hash`

### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    connected_services:
      - ...
      - "memos"
```

## Configuration

### Access to memos

- https://memos.ilnmors.com
  - Create local-admin account

### Set OIDC

- Profile: Settings: Admin: SSO: Create
  - Type: OAUTH2
  - Template: Custom
  - Provider ID: authelia
  - Name: Authelia
  - Client ID: memos
  - Client secret: memos.oidc.secret
  - Authorization endpoint: https://authelia.ilnmors.com/api/oidc/authorization
  - Token endpoint: https://authelia.ilnmors.com/api/oidc/token
  - User endpoint: https://authelia.ilnmors.com/api/oidc/userinfo
  - Scopes: openid profile email
  - Identifier: preferred_username
  - Display Name: given_name
  - Email: email
- Create

- Profile: Settings: Basic: My Account: SSO Accounts: Link
  - Login with Authelia
  - Accept

### Disallow local login and signup

- Profile: Settings: Admin: System
  - Disallow password auth: toggle
- Save

### Change user name

- Profile: Settings: Basic: My Account: Edit
