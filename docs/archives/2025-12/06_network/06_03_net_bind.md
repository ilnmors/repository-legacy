Tags: #os, #configuration, #network, #virtualization, #container

## BIND9

BIND9 is an open source authoritative DNS software of ISC. It can work as a personal authoritative in private network environment.

### Secret management

- File: 
	- ~/data/config/secrets/.secret.yaml

- Edit `.secret.yaml` with `edit_secret.sh`

#### Generate TSIG key as ACME key

```bash
podman run --rm --entrypoint /bin/sh internetsystemsconsortium/bind9:9.20 -c "tsig-keygen -a hmac-sha256 acme-key"
# Paste and add on .secret.yaml
# key "acme-key" {
#     algorithm hmac-sha256;
#     secret "your_base64_tsig_secret_here";
# };'
```

```yaml
# ~/data/config/secrets/.secret.yaml
BIND9_ACME_KEY: |
    key "acme-key" {
      algorithm hmac-sha256;
      secret "your_base64_tsig_secret_here";
    };
```

```bash
# Copy the secret value from .secret.yaml

# Podman secret
extract_secret.sh ~/data/config/secrets/.secret.yaml -f "BIND9_ACME_KEY" | podman secret create "acme-key" -
```


### Preparation

#### iptables and firewall rules

- Set iptables first, following [here](../03_common/03_02_iptables.md).
- Set firewall rules first, following [here](Latest/05_firewall/05_04_opnsense_rules.md).

#### Create directory for container

```bash
mkdir -p ~/data/containers/bind
chmod 700 ~/data/containers/bind
sudo setfacl -m d:g::0 ~/data/containers/bind
sudo setfacl -m d:o::0 ~/data/containers/bind
sudo setfacl -m u:net:rwx ~/data/containers/bind
sudo setfacl -m u:100052:rwx ~/data/containers/bind
sudo setfacl -d -m u:net:rwx ~/data/containers/bind
sudo setfacl -d -m u:100052:rwx ~/data/containers/bind
mkdir -p ~/data/containers/bind/{cache,etc,lib,log}
nano ~/data/containers/bind/{etc,lib}/configuration_files
```

> BIND9 container executes as 53:53(bind:bind) permission in container. It is mapped host's 100052. Therefore, directories have to have ACL via `setfacl`


### Podman Image

```bash
podman pull internetsystemsconsortium/bind9:9.20 # Do not use latest version to management
```

### Configuration files

> If `named.conf` file didn't exist in `/etc/bind` or it had error in it, the container would be terminated without any logs. Before starting BIND container, you should makes all configuration file already.

#### named.conf

- file: ~/data/containers/bind/etc/named.conf

```ini
include "/run/secrets/keys/acme-key";
include "/run/secrets/keys/ddns-key";

options {
        directory "/var/cache/bind";

        listen-on { any; };
        listen-on-v6 { ::1; };

        // Authoritative DNS setting
        allow-recursion { none; };
        allow-transfer { none; };
        allow-update { none; };

        dnssec-validation no;

        check-names master warn;
};

zone "ilnmors.internal." {
        type primary;
        file "/var/lib/bind/db.ilnmors.internal";
        notify yes;
        // ACME-01 challenge policy. It allows only subdomain's TXT record update.
        update-policy {
                grant acme-key subdomain ilnmors.internal. TXT;
                grant ddns-key subdomain ilnmors.internal. A AAAA DHCID;
        };
};

zone "1.168.192.in-addr.arpa" {
        type primary;
        file "/var/lib/bind/db.1.168.192.in-addr.arpa";
        notify yes;
        update-policy {
                grant ddns-key subdomain 1.168.192.in-addr.arpa PTR DHCID;
        };
};

zone "10.168.192.in-addr.arpa" {
        type primary;
        file "/var/lib/bind/db.10.168.192.in-addr.arpa";
        notify yes;
        update-policy {
                grant ddns-key subdomain 10.168.192.in-addr.arpa PTR DHCID;
        };
};

zone "ilnmors.com." {
        //split horizon dns
        type primary;
        file "/var/lib/bind/db.ilnmors.com";
        notify yes;
};

logging {
        channel default_log {
                stderr;
                severity info;
        };
        category default { default_log; };
        category config { default_log; };
        category queries { default_log; };
};
```

 >If ddns function were required, generate tsig key for ddns and give update policy for each zone like below.
> 
> - include "/etc/bind/ddns-key";
> - update-policy { grant ddns-key subdomain \[zone_domain\] ANY A AAAA TXT; };

- Verify the named.conf with the command `named-checkconf`

#### Zone files

> When you add the record, you should use `.` at the end of the domain. i.e. mydomain.internal.

- file:
    - ~/data/containers/bind/lib/db.ilnmors.internal

```ini
$TTL 86400

@       IN SOA bind.ilnmors.internal. mail.ilnmors.internal. (
                2025113001 ; serial
                3600       ; refresh (1 hour)
                1800       ; retry (30 minutes)
                604800     ; expire (1 week)
                86400      ; minimum (1 day)
        )
        IN      NS      bind.ilnmors.internal.
bind    IN      A       192.168.10.11
opnsense        IN      A       192.168.10.1
vmm     IN      A       192.168.10.10
net     IN      A       192.168.10.11
crowdsec     IN     CNAME     opnsense.ilnmors.internal.
adguard     IN     CNAME     net.ilnmors.internal.
step-ca     IN     CNAME     auth.ilnmors.internal.
caddy     IN     CNAME     auth.ilnmors.internal.
ldap     IN     CNAME     auth.ilnmors.internal.
authelia        IN      CNAME   auth.ilnmors.internal.
code-server     IN      CNAME   dev.ilnmors.internal.
postgresql     IN     CNAME     dev.ilnmors.internal.
```

- ~/data/containers/bind/lib/db.1.168.192.in-addr.arpa

```ini
$TTL 86400

@       IN SOA bind.ilnmors.internal. mail.ilnmors.internal. (
                yyyymmdd01 ; serial
                3600       ; refresh (1 hour)
                1800       ; retry (30 minutes)
                604800     ; expire (1 week)
                86400      ; minimum (1 day)
        )
        IN      NS      bind.ilnmors.internal.
1       IN      PTR     opnsense.ilnmors.internal.
11      IN      PTR     console.ilnmors.internal.
30      IN      PTR     printer.ilnmors.internal.
```

- ~/data/containers/bind/lib/db.10.168.192.in-addr.arpa

```ini
$TTL 86400

@       IN SOA bind.ilnmors.internal. mail.ilnmors.internal. (
                yyyymmdd01 ; serial
                3600       ; refresh (1 hour)
                1800       ; retry (30 minutes)
                604800     ; expire (1 week)
                86400      ; minimum (1 day)
        )
        IN      NS      bind.ilnmors.internal.
1       IN      PTR     opnsense.ilnmors.internal.
10      IN      PTR     vmm.ilnmors.internal.
11      IN      PTR     net.ilnmors.internal.
12      IN      PTR     auth.ilnmors.internal.
13      IN      PTR     dev.ilnmors.internal.
14      IN      PTR     app.ilnmors.internal.
```

- ~/data/containers/bind/lib/db.ilnmors.com

```ini
$TTL 86400

@       IN SOA bind.ilnmors.internal. mail.ilnmors.internal. (
                yyyymmdd01 ; serial
                3600       ; refresh (1 hour)
                1800       ; retry (30 minutes)
                604800     ; expire (1 week)
                86400      ; minimum (1 day)
        )
        IN      NS      bind.ilnmors.internal.
*       IN      A       192.168.10.12
```

```bash
# Adguard container has Requires=bind.service. When it restarted, then Adguard also restarted.
systemctl --user restart bind
```
### Quadlet

- File: 
	- ~/data/config/containers/bind/bind.container

```ini
# ~/data/config/containers/bind/bind.container
[Quadlet]
DefaultDependencies=false

[Unit]
Description=BIND9 DNS

After=network-online.target
Wants=network-online.target

[Container]
Image=docker.io/internetsystemsconsortium/bind9:9.20

ContainerName=bind

PublishPort=2253:53/tcp
PublishPort=2253:53/udp

Volume=%h/data/containers/bind/etc:/etc/bind:rw
Volume=%h/data/containers/bind/lib:/var/lib/bind:rw
Volume=%h/data/containers/bind/cache:/var/cache/bind:rw
Volume=%h/data/containers/bind/log:/var/log:rw

Environment="TZ=Asia/Seoul"
Secret=acme-key,target=/run/secrets/key/acme-key
Secret=ddns-key,target=/run/secrets/key/ddns-key

Label=diun.enable=true
Label=diun.watch_repo=true

[Install]
WantedBy=default.target
```

#### Create systemd `.service` file

```bash
# linger has to be activated
mkdir -p ~/.config/containers/systemd

ln -s ~/data/config/containers/bind/bind.container ~/.config/containers/systemd/bind.container

# This command makes bind.service
systemctl --user daemon-reload
```

#### Enable and start service

```bash
systemctl --user start bind.service
```


### nsupdate (RFC 2136) verification

```bash
# Update query at net server
# Before test, create temp file .bind.acme-key
nsupdate -k /run/user/$UID/.bind.acme-key
> server 127.0.0.1 2253
> zone ilnmors.internal
> update add _acme-challenge.ilnmors.internal. 60 TXT "validation-test"
> send
> `ctrl+c`

# Verify
dig @127.0.0.1 -p 2253 _acme-challenge.ilnmors.internal. TXT
# Print
;; QUESTION SECTION:
;_acme-challenge.ilnmors.internal. IN   TXT

;; ANSWER SECTION:
_acme-challenge.ilnmors.internal. 60 IN TXT     "validation-test"

# Delete query at net server
nsupdate -k /run/user/$UID/.bind.acme-key
> server 127.0.0.1 2253
> zone ilnmors.internal
> update delete _acme-challenge.ilnmors.internal. 60 TXT "validation-test"
> send
> `ctrl+c`

# Verify
dig @127.0.0.1 -p 2253 _acme-challenge.ilnmors.internal. TXT
# Print
;; ->>HEADER<<- opcode: QUERY, status: NXDOMAIN, id: 17572
```