# vaultwarden

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.vaultwarden`
  - Access infra server to create vaultwarden_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER vaultwarden WITH PASSWORD '<redacted>';
CREATE DATABASE vaultwarden_db;
ALTER DATABASE vaultwarden_db OWNER TO vaultwarden;
```

### Create admin hash

- Create the password with `openssl rand -base64 32`
  - https://argon2.online/
  - salt: auto generate
  - parallelism: factor 4
  - memory cost: 65536
  - iterations: 3
  - hash length: 32
  - type: argon2id
- Save this value in secrets.yaml in `vaultwarden.admin.password` and `vaultwarden.admin.hash`

### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    # telegraf has no database
    connected_services:
      - ...
      - "vaultwarden"

```

## Configuration

- https://vault.ilnmors.com/admin
  - token value: vaultwarden.admin.password
- Users:Invite User:Email
  - add
- https://vault.ilnmors.com
  - Create account and input the Email which added in admin page
