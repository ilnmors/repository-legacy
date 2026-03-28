# vikunja

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.vikunja`
  - Access infra server to create vikunja_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER vikunja WITH PASSWORD '<redacted>';
CREATE DATABASE vikunja_db;
ALTER DATABASE vikunja_db OWNER TO vikunja;
```

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'vikunja.oidc.secret'`
- Save this value in secrets.yaml in `vikunja.oidc.secret` and `vikunja.oidc.hash`

### Create session secret value

- Create the secret with `LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32`
  - Save this value in secrets.yaml in `vikunja.session_secret`

### Create admin password

- Create the secret with `openssl rand -base64 32`
- Save this value in secrets.yaml in `vikunja.il.password`

### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    connected_services:
      - ...
      - "vikunja"
```

## Configuration

### Create local account

- Access to app vm via ssh

```bash
ssh app
podman exec -it vikunja /app/vikunja/vikunja user create --email il@ilnmors.internal --username il
# Enter Password: vikunja.il.password
# Confirm Password: vikunja.il.password
```

- https://vikunja.ilnmors.com
  - Try to login locally
  - Try to login via Authelia
