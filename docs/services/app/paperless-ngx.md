# paperless

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.paperless`
  - Access infra server to create paperless_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER paperless WITH PASSWORD '<redacted>';
CREATE DATABASE paperless_db;
ALTER DATABASE paperless_db OWNER TO paperless;
```

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'paperless.oidc.secret'`
- Save this value in secrets.yaml in `paperless.oidc.secret` and `paperless.oidc.hash`
- Use `client_secret_post`, django encodes the secret value wrong frequently.

### Create session secret value

- Create the secret with `LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32`
  - Save this value in secrets.yaml in `paperless.session_secret`

### Create admin password

- Create the secret with `openssl rand -base64 32`
- Save this value in secrets.yaml in `paperless.il.password`

### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    connected_services:
      - ...
      - "paperless"
```

## Configuration

### Access to paperless

- https://paperless.ilnmors.com
  - name: il
  - E-mail: il@ilnmors.internal
  - password: `paperless.il.password`

### Oauth configuration

- My Profiles: Connect new social account: Authelia
  - Continue
  - Login with Authelia
