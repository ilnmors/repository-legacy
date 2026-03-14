# PKI(Public Key Infrastructure)

PKI is defined on RFC4949 and RFC5280. PKI is neither one of the protocols nor algorithms, it is a huge infrastructure itself. It has various parts which are CA(Certification Authority), RA(Registration Authority), VA(Validation Authority) and Certificates.

## CA (Certification Authority)

CA is the most important part in PKI. It is the source of certification for the secure communication. CA has various roles, some can be delegated to the RA or VA. However, CA is essential in PKI. RA or VA are optional to support CA. The purposes of CA are as follows:

- Managing certification policy
- Issuing certificates
- Verifying certificates validity
- Managing CRL(Certification Revocation List)
- Cross-certification between root CAs

CAs often operate in a hierarchy. Each CA has their own role, and they are basically PAA(Policy Approving Authority), PCA(Policy Certification Authority), and CA(Certification Authority). Normally, PAA and PCA are usually combined as root CA, and CA is an intermediate CA.

### root CA

Root CA is simply CA of CA. It is the source of trust chain. Only a root CA can authenticate itself alongside other root CAs(cross certification) or intermediate CAs below it. Theoretically, and precisely root CA can be divided into PAA and PCA, but practically they operate as one authority, root CA.

### intermediate CA

Intermediate CA is the authority which issues certificates for end entities we can use (i.e. web servers). Their certificate is digitally signed (the hash value is signed by root CA's private key) by root CA, so every user can verify their trust with root CA's certificate (root CA's public key). The reason for using intermediate CA is for security. If CA's private key was violated, all chain of trust will be disrupted. When only root CA exists and its private key was violated, all secure communication will be threatened. To avoid and manage these threats root CA and intermediate CA are divided.

### Structure of CA

The basic structure of CA is very simple. It only contains private key, certificate (which is designated by X.509), and provisioner. When CA gets a request of sign on services' certificates it operates as shown below.

- Provisioner checks CSR (Certificate Signing Request) is valid on its policy
- When CSR is valid, it checks the content of certificates(x.509) and its policy
- CSR and content of certificates are valid, CA signs on the certificate with its private key (sign on hash value with CA's private key)

After CA's signing, every client can check its validation with CA's certificates (CA's public key)

## RA (Registration Authority)

Due to CAs many roles, all processes above are made to be inefficient when conducted. Therefore, CA delegates its registration role to RA. RA seeks to examine CSR and certificates' content. When the content of certificate and CSR are valid under its policy, RA would send request to CA to sign.

## VA (Validation Authority)

Additionally, just as RA, CA can delegate its validation role to VA. Basically, VA manages certificates' validation based on CRL (Certificate Revocation List). However, in modern internet environment, it is inefficient to manage all invalid certificates based on a list. To solve this problem, OCSP (Online Certificate Status Protocol) was developed. However, OCSP also has its limitation, the advanced way is being suggested.

### CRL (Certificate Revocation List)

Once the certificate gets signed from CA, it is always a valid cryptograph before it expires. However, in the real world some certificates have to be revoked in case CA's key is violated or the service no longer operates, etc. So, CA needs to manage these kinds of invalid certificates which doesn't expire, such as letting clients know that their certificates are not valid anymore. This is a concept of CRL. VA releases the CRL to clients, the clients download or update the list to judge the certificates' validation.

### OCSP (Online Certificate Status Protocol)

CRL was very effective to revoke invalid certificates but when internet is growing, a massive of invalid certificates appears it shows its limitation. Because to check certificates validation, clients need to download and update CRL from CA or VA. There are tons of invalid certificates, and CRL's size become bigger and bigger. OCSP's concept is when client request to check certificates validation, OCSP server response it. To use OCSP, clients don't need to download full CRL anymore. It is very effective to solve CRL's problem. However, it has problems too. OCSP is defined on RFC6960. OCSP's problems are below.

- Clients should expose its identity(IP address) to check certificates validation.
- VA can be SPOF(Single Point of Failure).
- It is very hard to match time syncronization
- The more requests come to VA, the more burden is on VA.(DoS, DDoS problem)

### OCSP stapling

OCSP's problem was that client should request to VA directly. So, when the certificate providers(like web server, db, etc.) request its validation and give the proof to client it, clients doesn't need to check the validation of certificate to VA anymore. It reduces VA's burden and time synchronization problems.

## Certificate

The form and content of certificate are standardized by X.509. X.509 format contains server's public key, domain(SAN), expired date, and sign of CA, and etc. When CA validate services or people who sent CSR(which contains information to create certificate with x.509 form), CA signs on their certificates (sign on hash value with CA's private key). Then, all clients can validate that certificates with CA's public key(CA's certificate) cryptographically. Ultimately, when clients trust CA, then they can trust services that have certificate signed by CA. However, even if the certificate were valid cryptographically, some certificates would not be valid. It is reason why CRL or OCSP is needed.

### The way to issue certificate

#### ACME

Basically, certificate is formed by X.509. The services which want to get certificate send request(CSR) to CA. When the services were open internet, and it should get the certificate from public CA like let's encrypt on its public domain name. Public CA always sign on public domain which is open internet, and it is the role of public CA. The protocol to automate this process is ACME. Before ACME protocol, getting a certificate was manual. The person in charge should send CSR to CA, and CA checks the CSR and return the certificate ... All process was manual. ACME protocol made this process automatically. Simply, ACME protocol checks services authority on domain with various way, and issues certificate.

- http-01 challenge

The server creates certificate file for CA. CA accesses the service server's specific directory via 80/TCP. When CA checked the file, CA issues certificate.

- DNS-01 challenge

The server sends request to authoritative DNS server to add specific record with TSIG key(API key). When the specific record successfully added on DNS server and CA can check this, CA issues certificate. This challenge can verify full authority of domain including sub domain, so CA can issue wildcard certificate.

- TLS_ALPN-01 challenge

It uses TLS handshake process on 443/TCP. ALPN(Application Layer Protocol Negotiation) is the protocol to decide what protocol server and client will use. In this challenge, CA sends some token to service server. Service server creates temporary TLS certificates using `acme-tls/1` protocol with token from CA. When CA access to server, it asks `acme-tls/1` protocol to server. The server presents the temporary certificate, then CA issues certificate.

#### Based on identity

ACME is powerful protocol to automate issuing certificate. However, it is necessary to check ownership of domain to use ACME challenge (Usually, using http or https). However, It is possible to use TLS protocol without http or https. Originally, the process was also manual way called PKIX(Public-Key Infrastructure). It is so complex and slow, and it is impossible to use ACME. To automate this process, modern CA uses JWK(JSON Web Key) and JWT(JSON Web Token). The process is below.

- The administrator registers system's public key as JWK at CA.

    > JWK is a format of specification of key. It shows key and its information as JSON format.

- The system sends the JWT to get certificate signed by its private key to CA.

    > JWT is a specification of what client can do after connection or of proof this request is valid. In this process, JWT substitute CSR.

- CA verify JWT by pre-registered JWK. When JWT is valid, it issues X.509 certificate.

#### Usage of X.509 Certificates

Regardless the way to issue certificate, either ACME or the way based on its identity, the certificate which is already issued is always valid before it is revoked. You can use X.509 certificate from the way based on its identity for https, oppositely you can use X.509 certificate from ACME for other TLS protocols (like LDAPS, DB TLS communication, etc).

### X.500 and LDAP(Lightweight Directory Access Protocol)

In the beginning of PKI, there was plan to make a server for all certificates. It is X.500. However, the protocol to implement X.500, DAP(Directory Access Protocol) was too complex and heavy to use internet environment. To make way easy and light, LDAP(Lightweight Directory Access Protocol) was developed to store certificates. However, there are a lot more efficient way to manage certificates appeared already. LDAP could not realize X.500, but it is utilized as centralized authentication system like [SSO](./sso.md), or OS account management.
