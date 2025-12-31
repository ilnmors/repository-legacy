Tags: #os, #firewall, #configuration, #network, #security 

## ACME client in OPNsense

ACME client needs private CA(Step-CA) and BIND to issue private certificates for TLS.

### Plugin package

- os-acme-client

### DNS records

- Add new domain in BIND, Following [here](../06_network/06_03_net_bind.md).
    - net server
    - file: ~/data/containers/bind/lib/db.ilnmors.internal
    ```text
    ...
    opnsense     IN     A     192.168.10.1
    ...
    ```

### Trust setting (CA)

- Add root CA's crt
- System:Settings:Trust:Authorities - \[+\]
    - Method: Import an existing Certificate Authority
    - Description: step-ca.ilnmors.internal
    - Certificate Data: Content of root_ca.crt of Step-CA
    - `Save`

### ACME Client setting

#### ACME account and server setting

- Services:ACME Client:Settings
	- \[\*\] Enable Plugin
	- \[\*\] Auto Renewal
- `Apply`

- Services:ACME Client:Accounts - \[+\]
    - Name: acme.ilnmors.internal
    > It is only referred to OPNsense itself. It is not the provisioner name. It doesn't support special characters such as `@` or `!`.
    - Description: acme
    - Custom CA URL: https://step-ca.ilnmors.internal:9000/acme/acme@ilnmors.internal/directory

    > `[CA_URL]:[port]/acme/[provisioner_name]/directory`

    - `Save`
    - `Register account` and check Status column `OK (registered)`

#### ACME challenge

There is private authoritative DNS server in this homelab, therefore DNS-01 challenge will be used.

- Services:ACME Client:Challenge Types - \[+\]
    - Name: ilnmors.internal-dns-01-challenge
    - Description: step-ca.ilnmors.internal dns-01 challenge
    - Challenge Type: DNS-01
    - DNS service: nsupdate (RFC 2136)
    - DNS Sleep Time: 10
    > If this option weren't set, ACME client send query towards public DNS. It is necessary to set this option to use private authoritative DNS server. After set value(second) ACME client send the query towards private authoritative DNS.

    - Server (FQDN): bind.ilnmors.internal 2253
    > DNS server domain and port. It uses \[space\] as separator.

    - Secret Key:
    ```text
    key "acme-key" {
            algorithm hmac-sha256;
            secret "secret value";
    };
    ```
    > About key, following [here](../06_network/06_03_net_bind.md)

    - Zone: ilnmors.internal

#### Certificates

- Services:ACME Client:Certificates - \[+\]
    - Common name: opnsense.ilnmors.internal
    - Description: opnsense
    - Alt Names: crowdsec.ilnmors.internal
    - ACME account: acme.ilnmors.internal
    - Challenge Type: ilnmors.internal-dns-01-challenge
    - \[\*\] Auto Renewal
    - `Save`
    - Click `Issue or renew certificate` and check Last ACME status `OK`

#### Automations

##### Web UI restart automation configuration

- Services:ACME Client:Automations - \[\+\]
	- Name: opnsense-auto-restart-web-ui
	- Description: restart opnsense web ui
	- Run Command: Restart OPNsense web UI

> Web UI account `opnsense` doesn't use `sh`, it makes hard ACME client run the command via sh. Just use crontab to reload the crowdsec service everyday in `/usr/local/etc/cron.d/crowdsec`.

##### Example of remote automations

OPNsense's ACME client can upload certificates to other server or run specific command when the certificates is issued or renewed. Here is the example to upload the certificate towards other server via sftp.

- Services:ACME Client:Automations - \[+\]
    - Name: test_acme
    - Description: certificate upload test
    - Run Command: Upload certificate via SFTP
    - SFTP Host: net.ilnmors.internal
    - Host Key: \[blank\]
    > When it is not set, it automatically registers host key in `known_hosts`.
    - Username: net
    - Identity Type: ed25519
    - Remote Path: /home/net/certificate_test
    - `Show Identity` and copy the key value
    ```text
    ssh-ed25519 [key_value] root@opnsense.ilnmors.internal
    ```
    - Add this key on target server's ~/.ssh/authorized_keys
    - `Test Connection`
    - `Save`

- Services:ACME Client:Certificates - \[Edit Certificates\]
   - Automations: test_acme


### OPNsense Web UI certificate setting

- System:Settings:Administration
    - SSL certificate: opnsense.ilnmors.internal (ACME Client)

### Crowdsec TLS setting

Following [here](../03_common/03_04_crowdsec.md)