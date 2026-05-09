# trilium

## Prerequisite

### Create oidc secret and hash

- Create the secret with `openssl rand -base64 32`
- access to auth vm
  - `podman exec -it authelia sh`
  - `authelia crypto hash generate pbkdf2 --password 'trilium.oidc.secret'`
- Save this value in secrets.yaml in `trilium.oidc.secret` and `trilium.oidc.hash`

## Configuration

### Access

- https://notes.ilnmors.com
    - `[x]` I'm a new user, and I want to create a new Trilium document for my notes
    - Next
    - Password configuration
    - local password login

### OIDC

- Menu: Options: MFA
    - `[x]` Enable MFA
    - `[x]` OAuth/OpenID
    - logout
- Authelia

### about ERRORS

- This is so unstable to use, especially OIDC is one of terrible experience.
