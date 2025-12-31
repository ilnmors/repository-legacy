Tags: #theory, #network, #protocol 

## Email service

Email is the mail service online via the internet. ARPANET was developed in 1969, since then there has been many attempts to send messages via the internet. The mail which uses `@` character in 1971 and `SMTP(Simple Mail transfer Protocol)` was developed to standardize various ways to email.

### Component of Email service

#### Address

Basically, Email address has format like this. `local-parts@domain`. `local-parts` is identifier, and `domain` is service provider's domain. Following RFC 5321, `domain` doesn't distinguish it upper or lower case. `local-parts` must distinguish them, but practically they doesn't.

#### MUA (Mail User Agent)

MUA is the client of Email. The user can write Email, or read the Email which they got recieved. For instance, Outlook, Thunderbird, etc.

#### MTA (Mail Transfer Agent)

This is the essential part of Email service. MTA transpers the mail to other MTA or MDA. For instance, Postfix, sendmail, Exim, etc.

#### MDA (Mail Delivery Agent)

MDA recieves the mail from MTA, and it store the mail on receivers' mailbox. Sometimes, it is combined MTA or IMAP/POP3 servers. For instance, Dovecot LDA, Procmail, etc.

#### Flow of Email service

- User writes the mail on MUA.
- User sends the mail from MUA to MTA using SMTP submission protocol.
- MTA checks receiver's domain, and transfer the mail to other MTA which takes charge of that domain.
- MTA recieves the mail and sends receiver's MDA.
- The receiver's MUA access to the MDA such as IMAP or POP3 server. the receiver can check and read the email on their MUA.

## Protocols
### SMTP (Simple Mail Transfer Protocol)

SMTP is standard of email transfer protocol internet defined on RFC 5321. This protocol is used when MUA sends the mail to MTA, and MTA sends the mail other MTAs. This protocol takes charge of all process of transportation of the mails.

#### Detail of SMTP

##### Start

- Connection

The client and server make the connection via SMTP port (25/tcp).

##### Greeting

- `220` code

The server sends `220` code to the client, they are ready.

- `HELO` or `EHLO`

The client sends `HELO` or expand version of `HELO`; `EHLO` command to server to introduce itself.

##### Designate sender and recipient

Use the command below, they designate sender and recient.

- `MAIL FROM:<sender@domain>`
- `RCPT TO:<recipient@domain>`
	- If there were various recipients, use this command as much as recipients number.

##### Transper the mail data

- `DATA` and `354`

The client sends `DATA` command to server. After the server responds with `354` code, client sends the data including mail header (From, To, Subject), and content of mail. The end of data is `.`.

##### End

- `QUIT`

The client sends `QUIT` command, the connection is terminated.

##### Ports

- `25/tcp`

Traditional SMTP's standard port. All content using `25/tcp` is not encrypted. Because of security and SPAM problems, a lot of ISP block the `25/tcp` port of common user.

- `587/tcp` (Submission)

The standard port of SMTP for encryption. Generally MUA sends the mail to MTA with this port. It is needed to use encrypted connection via `STARTTLS`

- `465/tcp` (SMTPS)

This port used to be used for TLS/SSL for SMTP. This is not standard, so it is recommended to use `587/tcp` port for TLS/SSL of SMTP. However, even now this is generally and commonly used.

##### Security

SMTP is very old protocol, and this protocol use plain data. It is recommended to use `STARTTLS` or `SMTPS` to encrypt data for security.

- `SMTPS`

It uses TLS/SSL from the beginning of connection via `465/tcp`

- `STARTTLS`

It uses TLS/SSL after beginning of connection via `587/tcp` as plain data, and start encryption with `STARTTLS` command.

##### Authentication

It is necessary to use users' identity like name and password to prevent anyone can sends malicious mail using server. SMTP uses SASL (Simple Authentication and Secuirty Layer) machanism to authenticate its users.

##### Relay

MTA has to send the mail to the other MTA for guarantee the mail can arrive the recipitent. MTA uses `relay` function for this. Make sure to allow this function for authenticated user or trusted network to prevent malicious usage.

### IMAP (Internet Message Access Protocol)

IMAP is the protocol to read and manage the mails from remote MDA (mail server). The difference between POP3 is that IMAP can manage the mail and its mailbox remotely even without download. It is defined on RFC 3501.

#### Detail of IMAP

IMAP is the protocol to have a communication with various commands while the connection is stable. The client sends specific `tag` in front of command, and the server responds with `tag` to process the actions.

##### Authentication

- `LOGIN` or `AUTHETICATE`

IMAP authenticate the user with `LOGIN` command with ID and password or `AUTHENTICATE` command with SASL.

##### Mailbox

- `LIST`
- `SELECT`
- `CREATE`
- `DELETE`
- `RENAME`

##### Mail

- `FETCH`

IMAP can take the mail list, the mail itself, or content of the mail, even the attachment in the mail.

##### Statement

- `STORE`
	- `\Seen`
	- `\Flagged`
	- `\Answered`
	- `\Deleted`

IMAP can set the status flag of mail with command flags.


##### Search

- `SEARCH`

IMAP can search the mail with various condition of the mail (Sender, title, contents, date, etc) from server.

##### Ports

IMAP strongly recommend to use TLS/SSL with `STARTTLS`. Even though the beginning of conversation is not encrypted, TLS/SSL is applied with the `STARTTLS` command.

- `143/tcp`

The basic IMAP port. It is mendetory to use `STARTTLS` to use IMAP with this port.

- `993/tcp` (IMAPS)

This port uses TLS/SSL in the beginning of communication. It is not a standard but it is generally and commonly use for security.

##### Synchronization

IMAP basically server's mail and mail list, so wherever you access the mail you can see the same condition and status of mailbox. When one mail is modified on one device it is applied all devices simultanaeously.

- `IDLE`

This command supports to maintain connection between server and client, when the new mail comes or the status is changed the client can get notification immediately.

### POP3 (Post Office Protocol version 3)

POP3 protocol is basically designed to download the mail on local client from remote mail server. It is defined on RFC 1939. The biggest difference between IMAP and POP3 is, POP3 basically delete the mail at the server after downloading.

#### Detail of POP3

##### Authorization

- `USER` and `PASS`

The client connect to server and it conduct authentication with `USER` and `PASS` command.

##### Transcation

- `STAT`
- `LIST`
- `RETR <msg_number>`
- `DELE <msg_number>`
- `RETR`

POP3 uses various commands to download or delete the mail. It checks the number of mail and size with `STAT`, downloads the mail with `RETR`, deletes the mail with `DELE`, and save the mail on client with `RETR`.

##### Update

When the client sends `QUIT` command, then server deletes the mails which have `DELE` marks from server and terminate the connection.

##### Ports

POP3 strongly recommend to use TLS/SSL with `STARTTLS`. Even though the beginning of conversation is not encrypted, TLS/SSL is applied with the `STARTTLS` command.

- `110/tcp`

The basic port of POP3. It is mendetory to use `STARTTLS` to use IMAP with this port.

- `995/tcp` (POP3S)

This port uses TLS/SSL in the beginning of communication. It is not a standard but it is generally and commonly use for security.

##### Simplity and locality

POP3 basically delete the mail from mail server, the mail is only on the local client. However, it doesn't require the complex features like IMAP, it can have simplity.

---

## local mail service in homelab

### SMTP server (MTA)

#### Postfix

Postfix will be used as MTA which takes charge of `@ilnmors.internal` domain. However, Postfix in this homelab will never open towards WAN environment. It works as local private MTA. The internal services (Gitea, OPNsense, Prometheus, etc) will sends the mail via `587/tcp` to Postfix. When it needs to send mail towards WAN, it will use `relayhost` function and external Email services such as Google or Naver, etc. `relayhost` makes postfix as one of a `client` not a `MTA`. It means, administrator never takes care about IP reputation or SPAM problems. WAN area's `MTA` function is delegated to public mail service providers.

### IMAP/POP3 server (MDA)

#### Dovecot

Dovecot will be used as IMAP server of local private MTA; Postfix. The user can use MUA (Thunderbird, Outlook, or mail application, even Roundcube webmail) to access the private mail `
`@ilnmors.internal` via Dovecot. The user will ues `993/tcp` to access Dovecot, and Postfix store the mails on Dovecot.

#### mbsync

mbsync will be used as IMAP client of public MTA; Google or Naver. This will fetch public mail `@external-domain.com` to local Postfix from public mail service provider, and eventually the user can access the mail on Dovecot. However, it is important not to delete the mails from public mail servers with proper configuration.

### MUA

#### SnappyMail web mail

This will be used as MUA server on `app` server to access all mails at the same space.