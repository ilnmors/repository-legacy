# TLS/SSL

TLS(Transport Layer Security) is the protocol that encrypts communication with certificates under [PKI](../pki/pki.md). Originally, the communication encryption protocol was suggested as SSL(Secure Socket Layer) in 1995 by Netscape. Before the emergence of TLS/SSL protocol, all communication in web(or database, some more protocols) used plain text, even it contained sensitive data like password. After 1996, the update of SSL protocol stopped at version 3.0, and it has its own vulnerability. The next version of SSL is TLS. Virtually, a lot of people treat SSL as the same as TLS.

## Encryption

Before talking about TLS, it is essential to understand what is encryption. Basically, encryption is to hide plain data using algorithm and key mathematically. Encryption can categorized by various criteria, but in this case focusing on key.

### Symmetric key encryption

This way needs only one key to encrypt and decrypt. Just because using one key to encrypt and decrypt, it doesn't require complex calculation. This algorithm is fast, and easy to handle huge data. However, the key is only one so for security the key should be protected.

### Asymmetric key encryption

This way needs two keys to encrypt and decrypt. It means the key for encryption and the key for decryption are different. This uses very complex algorithm to seperate keys. It makes this slow and hard to handle huge data. However, the keys are devided so, one key can be publically shared.

## Principle of TLS

The PKI is necessary to use TLS communication. TLS uses both of algorithm to encrypt the communication. When the communication were encrypted, the key should exist. For this process(to generate key for encryption), server needs X.509 certificate. The certificate contains data of server's public key, domain, and extra informations. To start communication, the server and the client conduct specific process, called `TLS-handshake`. A client sends the request to start communication. The server accepts this request, and negotiates the protocol what they will use in communication. After negotiation, they start to process to generate symmetric key for communication. In this part, there are two protocol to generate symmetric key: RSA and Diffie-hellman.

### RSA (Legacy way)

In this process server and client uses server's public key and private key. A client generates metadata (Pre-master secret) to generate symmetric key. Metadata is encrypted with server's public key and sent to the server. The server decrypts the data from a client with its private key. They uses this data to generate symmetric key. When this process ends, they share the same symmetric key to encrypt content of communication.

- Cons of RSA

Security strength of RSA depends on the server's private key. The server's private key was taken from whom have the record of past communication, all communication can be decrypted. Because session key itself (precisely, pre-master secret) is in the communication encrypted by server's public key. So, this way can't guarantee Forward Secrecy which means security of previous communication. Additionally, RSA needs high resource to encrypt and decrypt. Therefore, modern internet environment RSA way is not used frequently.

### Diffie-Hellman & ECDHE(Modern standard)

On the other hand, TLS can use Diffie-Hellman algorithm. This process doesn't exchange any clue of session key. In this process, the server and clients generate secret values. And they make specific results from calculation with public parameters. The server's private key signs on its results just for prooving they are not altered and authenticated. When they exchange each other's results, both of them generate the same session key from results and their own secret value. All process is publically open, but except the server and client themselves, nobody can calculate the secret values and session key mathematically. After all process is done, finally the client combines all communication value between server. And it makes hash value of this, and encrypt the hash value with the session key. The client sends it to the server as finished message, and server verify this. This key is not permanent, it is temporary. There is no encryption way, so even if hacker could get the secret key of server, he wouldn't know what was the session key.

- Pros of DHE & ECDHE

On the contrary with RSA case, security strength of DHE & ECDHE doesn't depend on some specific key. Because when it generate session key, the server and client don't send any sensitive values (like pre-master secret) in this protocol. What they send to each other is open values. The server's public key is used for only signing. So, every session key can never exist after each session; PFS (Perfect Forward Secrecy). Additionally, Elliptic curve way can provide the same strength with shorter key comparing RSA.

The detail of `TLS-handshake` process is below.

## Detail of TLS handshake

### Start

- Client hello

The client sends the request to server with information including SNI (Server Name Indication), TLS version, cipher suite, and client random. SNI is the server's domain information to access. cipher suite is the protocol of encryption, and client random will be used to generate session key. Basically, the content of `client hello` isn't encrypted. It has a problem that ISP(Internet Service Provider) or government can conduct sniffing attack to the Client hello packet. To solve this problem, ECH (Encrypted Client Hello) was developed. However, ECH needs the support of DNS server, browser(host), and server itself. Today, a lot of servers and DNS servers don't support ECH, so it is hard to apply ECH in every environment.

- Server hello

When the server receives clients request, it designate how to communicate from the list of client hello. The server sends to the client with the information of what protocol, TLS version, cipher suite to use, and certificate, and server random. The way of encryption: RSA, DHE, ECDHE are including in the cipher suite.

### RSA

When the server and client decide to use RSA way, server sends certificate including public key to the client.

- Client key exchange

The client verifies `Server hello` with server's certificate using client's trusted CA list. The certificate is valid then the client generates `Pre-master secret` and encrypts this value with server's public key to send to the server.

- Session key generation

The server recieves `pre-master secret` encrypted by its public key that only server (who knows the private key of server) can decrypt. When the server decrypts this value successfully, the server and client knows three values: `Client random`, `Server random`, and `Pre-master secret`. The server and client generate `Session key` from these values individually.

### DHE or ECDHE

DHE and ECDHE follows the exactly same principle of Diffie-hellman algorithm. However, they have a difference of basement in mathematic. DHE is using discrete logarithm, but ECDHE is using elliptic curve discrete logrithm. This is a mathametical topic, so this is skipped. Just important thing is ECDHE is more efficient than RSA or DHE.

> Key length to guarantee the same level of security:
> 
> - RSA/DHE: above 2048 bit
> - ECDHE: above 256 bit

- Server key exchange

The server generate the pair of temporary key based on its own principal. The server sends public temporary key to the client. The public temporary key is signed by server's private key.

- Client key exchange

The client verify server's temporary public key with server's public key. Simultaneously, client also generate the pair of temporary key based on its own principal. The client sends its public temporary key to the server.

- Session key generation

Both of them have their pair of temporary key, and other's temporary public key. They generate the same `Pre-master secret` from their temporary secret key and other's temporary public key. This process has no communication, they calculate the same `Pre-master secret` from themselves. When they have `Pre-master secret`, they generate session key from pre-master secret and client random and server random.

### Finish

After all process is done, the server and client both sends the `Finished message` encrypted by session key. When they can decrypt this messages, the session key is generated properly. They can start communication securely with session key.

## TLS 1.3

Current standard TLS 1.3 changed handshake process as 1-RTT(1 Round Trip Time) and there are no longer available to use RSA way (Legacy).
