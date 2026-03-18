# gitea

## Prerequisite

### Create database

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `postgresql.password.gitea`
  - Access infra server to create gitea_db with `podman exec -it postgresql psql -U postgres`

```SQL
CREATE USER gitea WITH PASSWORD '<redacted>';
CREATE DATABASE gitea_db;
ALTER DATABASE gitea_db OWNER TO gitea;
```

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'gitea.oidc.secret'`
- Save this value in secrets.yaml in `gitea.oidc.secret` and `gitea.oidc.hash`

### Create admin password

- Create the secret with `openssl rand -base64 32`
- Save this value in secrets.yaml in `gitea.admin.password`
- 
### Add postgresql dump backup list

- [set_postgresql.yaml](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)

```yaml
- name: Set connected services list
  ansible.builtin.set_fact:
    connected_services:
      - ...
      - "gitea"
```

## Configuration

### Site installation

- **!CAUTION!** This is needed Only when first installing. This process isn't needed when the data is restored on `~/data/containers/gitea`
- https://gitea.ilnmors.com
- General setting
  - Site Title: Gitea: ilnmors
- Administrator Account Setting
  - Administrator Username: il
  - Email Address il@ilnmors.internal
  - Password & confirm password: gitea.il.password
- Install Gitea

### Oauth configuration

- Site Administration
- Identity & Access: Authentication Sources: Add Authentication Source
- Configure the following options:
  - Authentication Type: OAuth2
  - Authentication Name: authelia
  - OAuth2 Provider: OpenID Connect
  - Client ID (Key): gitea
  - Client Secret: gitea.oidc.secret
  - OpenID Connect Auto Discovery URL: https://authelia.ilnmors.com/.well-known/openid-configuration

### Link Account via OAuth2

- Login with autheila
  - Register New Account
  - Link to Existing Account
    - Link the account of administrational account which set at the inital install page
    - id and password

### Set repository access token

- Settings: Applications: Generate New Token
  - Token name: ilnmors-homelab
  - Repository and Organization Access: All
  - repository - Read and Write
- Generate Token
- Copy token value and save this in `secrets.yaml`

## Connect with loacl git repository

### Create remote git repository

- Repository: `+`
  - Name: ilnmors-homelab
  - etc: default vaules

- Following [07-git.md](../../runbook/07-git.md)
