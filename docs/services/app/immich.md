# immich

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.immich`
  - Access infra server to create immich_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER immich WITH PASSWORD '<redacted>';
CREATE DATABASE immich_db;
ALTER DATABASE immich_db OWNER TO immich;
\connect immich_db
CREATE EXTENSION IF NOT EXISTS vchord CASCADE;
CREATE EXTENSION IF NOT EXISTS cube CASCADE;
CREATE EXTENSION IF NOT EXISTS earthdistance CASCADE;
\dx
-- Check the extension is activated with `\dx`
-- postgresql image is built with `pgvector` and `vectorchord` already
```

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'immich.oidc.secret'`
- Save this value in secrets.yaml in `immich.oidc.secret` and `immich.oidc.hash`

### Create admin password

- Create the secret with `openssl rand -base64 32`
- Save this value in secrets.yaml in `immich.il.password`

### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    connected_services:
      - ...
      - "immich"
```

## Configuration

### Access to immich

- https://immich.ilnmors.com
  - Getting started
  - admin E-mail
  - admin password
  - admin name
- Theme
- language
- Server privacy
  - map
  - version check
- User privacy
  - google cast \(disable\)
- Storage template
  - `{{y}}/{{MM}}/{{y}}{{MM}}{{dd}}_{{hh}}{{mm}}{{ss}}`
- Backups
- Mobile App
- Done

### Oauth configuration

- Administartion: Authentication Settings: OAuth: Enable
    - Issuer URL: https://auth.example.com/.well-known/openid-configuration
    - Client ID: immich
    - Client Secret: immich.oidc.secret
    - Scope: openid profile email
    - Button Text: Login with Authelia
    - Auto Register: Enable if desired

### Machine learning configuration

- Administration: Machine Learning Settings: Enable
  - URL: http://host.containers.internal:3003
- **!CAUTION!**
  - immich-ml should contain `-openvino` to use GPU for machine learning.
