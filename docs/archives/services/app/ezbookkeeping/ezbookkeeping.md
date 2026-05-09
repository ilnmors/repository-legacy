# ezBookkeeping

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.ezbookkeeping`
  - Access infra server to create paperless_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER ezbookkeeping WITH PASSWORD '<redacted>';
CREATE DATABASE ezbookkeeping_db;
ALTER DATABASE ezbookkeeping_db OWNER TO ezbookkeeping;
```

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'ezbookkeeping.oidc.secret'`
- Save this value in secrets.yaml in `ezbookkeeping.oidc.secret` and `ezbookkeeping.oidc.hash`

### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    connected_services:
      - ...
      - "ezbookkeeping"
```
