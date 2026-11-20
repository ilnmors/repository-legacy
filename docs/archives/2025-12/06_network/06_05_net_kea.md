Tags: #os, #configuration, #network, #virtualization, #container


# KEA

#### Generate TSIG key as DDNS key

```bash
podman run --rm --entrypoint /bin/sh internetsystemsconsortium/bind9:9.20 -c "tsig-keygen -a hmac-sha256 acme-key"
# Paste and add on .secret.yaml
# key "acme-key" {
#     algorithm hmac-sha256;
#     secret "your_base64_tsig_secret_here";
# };'
```

### DHCPv4
#### Add user to group

```bash
sudo apt install kea-dhcp4-server kea-dhcp-ddns-server
sudo usermod -aG _kea net
sudo chmod 770 /etc/kea /var/lib/kea
sudo chmod 660 /etc/kea/kea-dhcp4.conf
sudo mkdir /etc/secrets/$(id -u _kea)
sudo chown _kea:root /etc/secrets/$(id -u _kea)
sudo chmod 500 /etc/secrets/$(id -u _kea)
sudo touch /etc/secrets/$(id -u _kea)/ddns-key
sudo nano /etc/secrets/$(id -u _kea)/ddns-key
sudo chown _kea:root /etc/secrets/$(id -u _kea)/ddns-key
sudo chmod 400 /etc/secrets/$(id -u _kea)/ddns-key
```

iptables
```
*mangle

*filter
-A INPUT -p udp -m udp --dport 67 -m comment --comment "allow upd DHCPv4 connection" -j ACCEPT

# check
sudo bash -c 'iptables-restore --test < /etc/iptables/rules.v4'
```

 kea-dhcp4.conf
```json
{
    "Dhcp4": {
        "subnet4": [
                {
                "subnet": "192.168.10.0/24",
                "pools" : [
                    {
                        "pool": "192.168.10.254-192.168.10.254"
                    }
                ],
                "option-data": [
                    {
                        "name": "routers",
                        "data": "192.168.10.1"
                    },
                    {
                        "name": "ntp-servers",
                        "data": "192.168.10.1"
                    },
                    {
                        "name": "domain-name-servers",
                        "data": "192.168.10.11"
                    },
                    {
                        "name": "domain-name",
                        "data": "ilnmors.internal"
                    }
                ],
                "reservations": [
                    {
                        "hw-address": "0a:49:6e:4d:02:00",
                        "ip-address": "192.168.10.12",
                        "hostname": "auth"
                    },
                    {
                        "hw-address": "0a:49:6e:4d:03:00",
                        "ip-address": "192.168.10.13",
                        "hostname": "dev"
                    },
                    {
                        "hw-address": "0a:49:6e:4d:04:00",
                        "ip-address": "192.168.10.14",
                        "hostname": "app"
                    }
                ],
                "id": 1,
                "interface": "enp1s0"
            },
            {
                "subnet": "192.168.1.0/24",
                "relay": {
                    "ip-addresses": [ "192.168.1.1" ]
                },
                "pools": [
                    {
                        "pool": "192.168.1.100-192.168.1.254"
                    }
                ],
                "option-data": [
                    {
                        "name": "routers",
                        "data": "192.168.1.1"
                    },
                    {
                        "name": "ntp-servers",
                        "data": "192.168.1.1"
                    },
                    {
                        "name": "domain-name-servers",
                        "data": "192.168.10.11"
                    },
                    {
                        "name": "domain-name",
                        "data": "ilnmors.internal"
                    }
                ],
                "reservations": [
                    {
                        "hw-address": "d8:e2:df:ff:1b:d5",
                        "ip-address": "192.168.1.11",
                        "hostname": "surface"
                    },
                    {
                        "hw-address": "38:ca:84:94:5e:06",
                        "ip-address": "192.168.1.30",
                        "hostname": "printer"
                    }
                ],
                "id": 2,
                "interface": "enp1s0"
            }
        ],
        "interfaces-config": {
            "interfaces": [
                "enp1s0"
            ],
            "dhcp-socket-type": "raw",
            "service-sockets-max-retries": 5,
            "service-sockets-require-all": true
        },
        "renew-timer": 1000,
        "rebind-timer": 2000,
        "valid-lifetime": 4000,
        "loggers": [
            {
                "name": "kea-dhcp4",
                "output_options": [
                    {
                        "output": "stdout"
                    }
                ],
                "severity": "INFO"
            }
        ],
        "lease-database": {
            "type": "memfile",
            "persist": true,
            "name": "/var/lib/kea/kea-leases4.csv",
            "lfc-interval": 3600
        },
        "dhcp-ddns": {
            "enable-updates": false,
            "server-ip": "127.0.0.1",
            "server-port": 53001
            "ncr-protocol": "UDP"
            "ncr-format": "JSON"
        },
        "ddns-send-updates": true,
        "ddns-update-on-renew": true,
        "ddns-qualifying-suffix": "ilnmors.internal",
        "ddns-override-no-update": true,
        "ddns-override-client-update": true,
        "ddns-replace-client-name": "when-present",
        "ddns-generated-prefix": "host"
        "hostname-char-set": "[^a-zA-Z0-9.-]",
        "hostname-char-replacement": "-"
    }
}

// There is one interface for DHCP host. In this case, the subnet which has dhcp server should be `id=1`. Because Kea DHCP allocate IP from the `id=1` subnet when it recieve pacekt has no giaddr. When Kea DHCP is running on Router, then id is not important because DHCP allocate IP based on their interface.
```

#### OPNsense
- Services:Kea DHCP:Kea DHCPv4
	- \[ \] Enabled
- Services:DHCP Relay:Configuration
	- Destination - \[+\]
		- Name: kea-dhcp-v4
		- Server: 192.168.10.11
	- Relays - \[+\]
		- \[\*\] Enabled
		- Interface: LAN
		- Desitination kea-dhcp-v4
		- \[ \]Agent Information
	- Status `green box` check

### DDNS

```bash
sudo nano /etc/apparmor.d/local/usr.sbin.kea-dhcp-ddns

# /etc/secrets/** r,

sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.kea-dhcp-ddns
sudo systemctl restart kea-dhcp-ddns-server.service
```

/etc/secrets/102/ddns-key
```json
[
    {
        "name": "ddns-key",
        "algorithm": hmac-sha256;
        "secret": "secret_value"
    }
]
```

/etc/kea/kea-dhcp-ddns.conf
```json
{
    "DhcpDdns":
    {
        "ip-address": "127.0.0.1",
        "port": 53001,
        "control-socket": {
            "socket-type": "unix",
            "socket-name": "/run/kea/kea-ddns-ctrl-socket"
        },
        "tsig-keys": <?include "/etc/secrets/102/ddns-key"?>,
        "forward-ddns" : {
            "ddns-domains": [
                {
                    "name": "ilnmors.internal.",
                    "key-name": "ddns-key",
                    "dns-servers": [
                        {
                            "ip-address": "127.0.0.1",
                            "port": 2053
                        }
                    ]
                }
            ]
        },
        "reverse-ddns" : {
            "ddns-domains": [
                {
                    "name": "10.168.192.in-addr.arpa.",
                    "key-name": "ddns-key",
                    "dns-servers": [
                        {
                            "ip-address": "127.0.0.1",
                            "port": 2053
                        }
                    ]
                },
                {
                    "name": "1.168.192.in-addr.arpa.",
                    "key-name": "ddns-key",
                    "dns-servers": [
                        {
                            "ip-address": "127.0.0.1",
                            "port": 2053
                        }
                    ]
                }
            ]
        },
        "loggers": [
            {
                "name": "kea-dhcp-ddns",
                "output-options": [
                    {
                        "output": "stdout"
                    }
                ],
              "severity": "INFO",
            }
        ]
    }
}
```

 kea-dhcp4.conf
 ``` json
 // ...
 "dhcp-ddns": {
            "enable-updates": true,
            // ...
}
 ```

---

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
include "/etc/bind/key/acme-key";

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
        };
};

zone "1.168.192.in-addr.arpa" {
        type primary;
        file "/var/lib/bind/db.1.168.192.in-addr.arpa";
        notify yes;
};

zone "10.168.192.in-addr.arpa" {
        type primary;
        file "/var/lib/bind/db.10.168.192.in-addr.arpa";
        notify yes;
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
                yyyymmdd01 ; serial
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
auth     IN     A     192.168.10.12
dev     IN     A     192.168.10.13
app     IN     A     192.168.10.14
console     IN     A     192.168.1.11
printer     IN     A     192.168.1.30
crowdsec     IN     CNAME     opnsense.ilnmors.internal.
adguard     IN     CNAME     net.ilnmors.internal.
step-ca     IN     CNAME     auth.ilnmors.internal.
caddy     IN     CNAME     auth.ilnmors.internal.
ldap     IN     CNAME     auth.ilnmors.internal.
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
Secret=acme-key,target=/etc/bind/key/acme-key

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