# sure

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.sure`
  - Access infra server to create sure_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER sure WITH PASSWORD '<redacted>';
CREATE DATABASE sure_db;
ALTER DATABASE sure_db OWNER TO sure;
```

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'sure.oidc.secret'`
- Save this value in secrets.yaml in `sure.oidc.secret` and `sure.oidc.hash`

### Create session secret value

- Create the secret with `LC_ALL=C tr -dc 'A-Za-z0-9!#%&()*+,-./:;<=>?@[\]^_{|}~' </dev/urandom | head -c 32`
  - Save this value in secrets.yaml in `sure.session_secret`

### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    connected_services:
      - ...
      - "sure"
```

## Configuration

### Access to sure

- https://sure.ilnmors.com
  - Sign in with Authelia
  - Create account

### Account configuration

- Setup: 
  - First name and last name
  - Will be using sure with
    - [x] Family members
  - Country: South Korea
- Preference: 
  - South Korean Won (KRW)
  - date: YYYY-MM-DD
- Goals:
  - Next

### Group and user configuration

- Profile: Settings: Profile info:
  - Household: Set name
  - Invite member: input email of member
