# Actual budget

## Prerequisite

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'actualbudget.oidc.secret'`
- Save this value in secrets.yaml in `actualbudget.oidc.secret` and `actualbudget.oidc.hash`

## Configuration

### Initialization

- Use current domain
  - ok
- Start Using OpenID
  - Start fresh
- Server Online: User directory: Add User: the user name which is defined on LDAP
- Server Online: User Access: enable user
