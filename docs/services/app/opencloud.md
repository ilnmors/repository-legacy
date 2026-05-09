# opencloud

## Prerequisite

### oidc secret and hash

- Opencloud uses PKEC, therefore it doesn't need client secret

### Create admin password

- Create the password with `openssl rand -base64 32`
  - Save this value in secrets.yaml in `opencloud.admin.password`

## Configuration

- **!CAUTION!** OpenCloud application (Android, IOS, Desktop) doesn't support standard OIDC. Every scopes and client id is hardcoded.
  - `WEBFINGER_[DESKTOP|ANDROID|IOS]_OIDC_CLIENT_ID`, `WEBFINGER_[DESKTOP|ANDROID|IOS]_OIDC_CLIENT_SCOPES` don't work on official app.
  - It is impossible to set group claim in scopes. Therefore, it is hard to control roles with token including group claim.
- When authelia doesn't work, annotate `OC_EXCLUDE_RUN_SERVICES=idp` and restart to container to use local admin.
- This app doesn't support regex on role_assignment mapping.
  - When the new user added, manage proxy.yaml.j2 manually until they will support regex or fallback mapping, or fix the hardcoded scopes on applications.

### csp

- Fix `csp.yaml`
