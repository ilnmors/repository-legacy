# SSO (Single Sign On)

When someone wants to use some services, usually they have to identify themselves to the services. The service verifies who you are (authentication), and what you can do (authorization). Originally, each service has their own authentication and authorization system. However, in modern internet environment, a lot of services are organically connected to each other. It is common for one provider to operate various services. So, it is very inefficient and complex to operate authentication and authorization system like this way. To solve this problem, the concept of SSO which is to centralize all services' authentication and authorization system at once emerged.

## LDAP (Lightweight Directory Access Protocol)

To centralize authentication and authorization system, it is necessary to kind of central database of user list naturally. Fortunately, there was a very good and suitable protocol already; LDAP. LDAP was originally suggested to replace DAP (Directory Access Protocol) for X.500 in [PKI](./pki.md). Even though X.500 didn't materialized, the potentiality of LDAP was selected to materialize SSO. Because LDAP's structure which was designed for manage certificates itself allows to manage user and its authorization. In modern internet environment, many services don't usually use LDAP itself directly in SSO anymore, but it is still used as database of user and their authorization.

### Structrue of LDAP

LLDAP will be used in this homelab. It is the easiest way to understand LDAP is comparing each part of LDAP with filesystem. Because LDAP itself is fundamentally the database which has the tree structure like filesystem.

#### DN (Distinguished Name)

DN is the unique path of some specific entry in tree. It is like an absolute path in filesystem.

- Example:
	- `uid=admin,ou=people,dc=ilnmors,dc=internal`
	- `uid=authelia,ou=people,dc=ilnmors,dc=internal`

#### Base DN (Base Distinguished Name)

Base DN is the root of the tree of LDAP. it is like root path of filesystem `/`. All the actions such as search or work are started from Base DN.

- LLDAP setting
	- Environment.="LLDAP_LDAP_BASE_DN=dc=ilnmors,dc=internal"
	- It means, the domain 'ilnmors.internal' will be the Base DN (the root of tree).

#### Components of DN

DN has components what has ordinary order. The order of these components are `cn(or uid)`, `ou`, `dc`. They are special attributes, which makes DN.

- cn (Common name): The name of object. It is like a file itself in filesystem.
- ou (Organizational Unit): The name of the container which contain entries. It is like a folder in filesystem.
- dc (domain component): The domain components, Usually, it devides the full domain `ilnmors.internal` as `dc=ilnmors`, `dc=internal`.

#### Object (or Entry)

Object is the real data item the DN defines, like file or folder itself in filesystem.

#### ObjectClass

This is the template or blueprint of object. ObjectClass defines what is this object; Either a person or a group, or an organization unit.

- What is this object; user (cn or uid) or group (ou).
- What is the attribute object must have, and might have.
- Example: 
	- `ObjectClass: person`: This must have `sn` and `cn` attributes.
	- `ObjectClass: organizationalPerson`: This is inherited the `ObjectClass: person`, and it can have `mail` or `number` attributes.
- LLDAP uses standard ObjectClass: `person`, `groupOfNames`.

#### Attribute

Attribute is the value of object, like the content of file or folder in filesystem. It is saved as the pairs of key-value. This values are following the definition of ObjectClass.

- Example
	- `uid=user1` has the value following `objectClass: person`, `objectClass: organizationalPerson`
	- It must have `sn`, and `cn`
	- It can have `mail`, or `number`
	- It can have special attribute `memberOf: cn=admins,ou=admin_group, ...` (The attribute that shows the group the user belongs to)

## IdP (Identity Provider)

Many of modern services, SP (Service provider), use SAML (Security Assertion Markup Language) or OIDC (OAuth 2.0/OpenID Connect) protocol to implement SSO. Originally, each service had to send request of authentication to central server (which can be LDAP or else) individually to implement SSO. It means each service should protect the sensitive data itself, and some services which have vulnerability can threaten all system. This is why many of modern services use and support SAML or OIDC protocols. The IdP is needed to use these protocols. The IdP acts as the agent of all services to substitute authentication process on their behalf. Only IdP can access the real database, and all services trust IdP's authentication in this model.

### SAML (Security Assertion Markup Language)

SAML protocol was developed in 2001 for SSO. This protocol works on XML (eXtensible Markup Language) format which can meet complex security requirements in enterprise environments. It has been used for a long time, it makes this protocol very stable. However, XML itself is a complex and heavy format. This fact makes the protocol complex and heavy to use in common and small environment. There is the process of SAML below.

- Start

User sends the request to the service. When SP recieves the request, it redirect the request to IdP.

- Authentication

IdP asks the login information to the user and it authenticate user from database (like LDAP). When authentication process succeed, IdP generates SAML assertion including user's identity based on XML with sign to ensure integrity. IdP sends the this assertion to SP via user's browser.

- Finish

SP receives the assertion from IdP via user's browser, it verify the assertion. When it is valid, they allow login.

### OIDC (OpenID Connect) and OAuth 2.0

OIDC was developed in 2014, it is newer than SAML. This is an authentication layer on OAuth 2.0 protocol. Basically, OAuth 2.0 is for authorization, and OIDC is for authentication. OAuth 2.0 protocol works on JSON/REST format, especially JWT (JSON Web Token) which is lighter and simpler than XML. OIDC is latest standard of SSO, it supports social login, and friendly to API. These features makes this protocol use on small and personal environment easily. There is the process of OIDC below.

- Start

User sends the requset to the service (in OIDC, RP; Relying Party). When RP receives the request, it redirects to IdP (in OIDC, OP; OpenID Provider).

- Authentication

IdP (OP) asks login information, and simultaneously asks permission to provide the information to RP. After getting information and permission, IdP generates two tokens which are for different purposes. One is an ID token (JWT) which contains user identity for authentication, the other is an access token for authorization. IdP sends these token to RP. The differences between SAML are what data format does protocol use, and whether IdP gets permission or not.

- Finish

RP recieves the tokens from IdP, and it verify the tokens. When it is valid, they allow login.

### Reverse proxy

When application doesn't support SSO, then you can use reverse proxy as the door of SSO using `Forward Authentication`. Usually, every web packet pass through reverse proxy in modern internet environment. Therefore, reverse proxy (i.e. Caddy) can intercepts the packets and force them to SSO from IdP or OP (or LDAP itself) before they reach to the application.

- Header based

When Authelia success to authenticate someone, Caddy sends specific header which contains user information like `X-Forwarded-User: A`. Application gets this header, it automatically allows login to A. However, it is needed the ID in the application manually.

> If hacker can access to application without reverse proxy, it can make X header to fake application. In this homelab, all access towards application will be limited by iptables from reverse proxy or sidecar reverse proxy.

- LDAP based

LLDAP will be a light and simple LDAP server. Authelia supports OIDC OP(idP) based on external LDAP server. LLDAP server will becom the external LDAP server for Authelia


---
# Example of Authelia flow

## Flow

- Define the user and group in LLDAP server

### OIDC supported app

- At the service, choose login way as Authelia (OP)
- Login at the Authelia.
- Authelia access to LLDAP server to authenticate the user based on LDAP.
- Login succeed, Authelia generate token and Service turst OP's token, and allow login (authentication and authorization)

### Non-OIDC supported app

- Foward_Auth function with Authelia.
