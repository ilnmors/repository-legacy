# affine

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.affine`
  - Access infra server to create affine_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER affine WITH PASSWORD '<redacted>';
CREATE DATABASE affine_db;
ALTER DATABASE affine_db OWNER TO affine;
\connect affine_db
CREATE EXTENSION IF NOT EXISTS vector;
\dx
-- Check the extension is activated with `\dx`
-- postgresql image is built with `pgvector` and `vectorchord` already
```

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'affine.oidc.secret'`
- Save this value in secrets.yaml in `affine.oidc.secret` and `affine.oidc.hash`

### Create secret key value

- Create the secret with `openssl genpkey -algorithm ed25519 -outform PEM`
  - Save this value in secrets.yaml in `affine.secret_key`

### Create admin password

- Create the secret with `openssl rand -base64 32`
- Save this value in secrets.yaml in `affine.il.password`

### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    connected_services:
      - ...
      - "affine"
```

## Configuration

### About community edition limitation

- Workspace seats
  - The number of members itself (account) are unlimited.
  - However the number of members who work on the same workspace simultaneously (seats) are designated as 10 members.
- Workspace storage quota
  - Originally, self-hosted version has no limitation in storage quota and uploading file size.
  - Now, there is some limitation even in the self-hosted version.
  - It will be changed when the application is updating

### Following feature which will be applied in this system

- Linking local caldav vaikal or radicale ...
- Apply AI function with API

### Access to affine

- https://affine.ilnmors.com
  - Getting started
  - admin name
  - admin E-mail
  - admin password
    - Initial setting allows only 32 digit password, now just set temporary password

### Server configuration
- https://affine.ilnmors.com/admin

#### Server

- A recognizable name for the server. Will be shown when connected with AFFiNE Desktop.
  - Ilnmors

#### Auth

- `[ ]` Whether allow new registrations
- `[x]` Whether allow new registration via configured oauth
- Minimum length requirement of password: 8
- Maximum length requirement of password: 50
- save

#### Oauth configuration

```ini
# These options are required
## OIDC callback URIs
Environment="AFFINE_SERVER_HOST={{ services['affine']['domain']['public'] }}.{{ domain['public'] }}"
Environment="AFFINE_SERVER_EXTERNAL_URL=https://{{ services['affine']['domain']['public'] }}.{{ domain['public'] }}"
Environment="AFFINE_SERVER_HTTPS=true"
```
- OIDC Oauth provider config

```json
{
  "clientId":"affine",
  "clientSecret":"affine.oidc.secret",
  "issuer":"https://authelia.ilnmors.com",
  "args":{
    "scope": "openid profile email"
  }
}
```

- save

#### Flags

- `[x]` Whether allow guest users to create demo workspaces
- save
