# Outline

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.outline`
  - Access infra server to create outline_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER outline WITH PASSWORD '<redacted>';
CREATE DATABASE outline_db;
ALTER DATABASE outline_db OWNER TO outline;
```

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'outline.oidc.secret'`
- Save this value in secrets.yaml in `outline.oidc.secret` and `outline.oidc.hash`

### Create session secret and utils value

- Create two secrets with `openssl rand -hex 32`
  - Save this value in secrets.yaml in `outline.session_secret`
  - Save this value in secrets.yaml in `outline.utils_secret`

### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    connected_services:
      - ...
      - "outline"
```

## Configuration

### Notice

- Outline is a BSL, not fully open-sourced stack. Always ensure they can change their policy of the outline

### Access to outline

- https://outline.ilnmors.com
  - Authelia redirect and automatically sign-up
