## Operation
Refer to Ansible playbook
(Postgresql user and DB is needed)

Integrate configuration with various app: https://github.com/lldap/lldap/blob/main/example_configs

## Configuration
### DB URL

Jinja2 `urlencode` module doesn't replace `/` as `%2F`. replace('/', '%2F') is necessary.
ex) {{ var | urlencode | replace('/', '%2F') }}

### Reset administrator password

```bash
# infra
sudo nano $LDAP_PATH/data/lldap_config.toml
# Add below on file
ldap_user_pass = "REPLACE_WITH_PASSWORD"
force_ldap_user_pass_reset = true
# Restart lldap
systemctl --user restart ldap.service
# Delete added lines from lldap_config.toml
# ldap_user_pass = "REPLACE_WITH_PASSWORD"
# *YOU MUST DELETE PASSWORD PART*
# force_ldap_user_pass_reset = true
```

### Access web UI and Login

- URL: http://ldap.ilnmors.internal:17170 (This is temporary access way before Caddy, which is reverse proxy, is set)
- ID: admin
- PW: $LLDAP_LDAP_USER_PASSWORD

### Create the groups

- Groups - `[+]` Create a group
	- Group: admins
	- Group: users
    
It is necessary to manage ACL via authelia based on groups.

### Create the authelia user for OCID (OP)

- Users: `[+]` Create a user
	- Username (cn; uid): authelia
	- Display name: Authelia
	- First Name: Authelia
	- Last Name (sn): Service
	- Email (mail): authelia@ilnmors.internal
	- Password: "$(openssl rand -base64 32)"
- Groups:lldap_strict_readonly: `[Add to group]`
	- This group allow search authority.
- Users: `[+]` Create a user
	- Username (cn; uid): grafana
	- Display name: Grafana
	- First Name: Grafana
	- Last Name (sn): Service
	- Email (mail): grafana@ilnmors.internal
	- Password: "$(openssl rand -base64 32)"
- Groups:lldap_strict_readonly: `[Add to group]`
	- This group allow search authority.
> Save the password in .secret.yaml

### Create the normal users

- Users: `[+]` Create a user
	- Username (cn; uid): il
	- First Name: Il
	- Last Name (sn): Lee
	- Email (mail): il@ilnmors.internal
	- Password: "$PASSWORD"
- Groups:lldap_admin&admins&users: `[Add to group]`
- Users: `[+]` Create a user
	- Username (cn; uid): user
	- First Name: John
	- Last Name (sn): Doe
	- Email (mail): john_doe@ilnmors.internal
	- Password: "$PASSWORD"
- Groups:(admins|users): `[Add to group]`

> Custom schema in `User schema`, `Group schema` doesn't need to be added. This is for advanced function to add additional value such as `identity number` or `phone number`. Hardcoded schema, which means basic schema the lldap provides is enough to use Authelia.

> After all these steps, now you can integrate the Authelia for SSO.

## Usage of LDAP

### Service Bind

LDAP call `login` as Bind. When the authelia Bind to the LDAP server, it can get the authority to search in `lldap_strict_readonly` group.

### Search

authelia account has the authority to search, it can search to send the query. 

#### Flow of search

- Client (authelia) sends the query
	- `uid=user in dc=ilnmors,dc=internal`
- LDAP server searches the DN of entry
	- `uid=user,ou=people,dc=ilnmors,dc=internal`
- LDAP sends the DN to Client (authelia)

## Authelia's work flow

### First login

#### User login query

User try to login on login page of Authelia.

- id: user
- password: 1234

#### Service Bind (Bind and search)

authelia binds to LLDAP server based on the information in configuration.yml.

- dn: authelia
- password: authelia's password

#### Search

authelia sends the query to LLDAP after bind. 
- `uid=user in dc=ilnmors,dc=internal`

#### Request

LLDAP server searches the entry and send the DN information query to authelia.

- `uid=user,ou=people,dc=ilnmors,dc=internal`

### Verify the user login (Second login)

#### User Bind (Bind only)

authelia tries to bind LLDAP server based on the information that user input.

- dn: requested uid
- password: 1234

#### Verification from LLDAP

LLDAP verify the password from authelia with its hash value saved in LLDAP's database.

#### Request

LLDAP server sends the result as `Success` or `Fail`.

> Search authority is basic authority of user who binds to LDAP server. It is just the way to check success or fail bind is the charge of Authelia.

## verify

- openssl s_client -connect ldap.ilnmors.internal:636 -tls1_3
