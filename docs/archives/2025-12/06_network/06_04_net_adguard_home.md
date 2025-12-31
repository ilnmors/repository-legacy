Tags: #os, #configuration, #network, #virtualization, #container

## AdGuard Home

AdGuard Home is one of open sourced recursive DNS resolver which can block malicious domain. It supports powerful DNS query filter based on ruleset and split horizon DNS service, plus recursive query on DoH and DoT towards public or internal authoritative DNS server.

### Secret

Adgaurd Home container doesn't need any secret value.

### Preparation

#### Add new domain in BIND

Following [here](../06_network/06_03_net_bind.md).

- net server
- file: ~/data/containers/bind/lib/db.ilnmors.internal
  
```ini
# ...
adguard     IN     CNAME     net.ilnmors.internal.
# ...
```

```bash
# Adguard container has Requires=bind.service. When it restarted, then Adguard also restarted.
systemctl --user restart bind
```
#### iptables and firewall rules

- Set iptables first, following [here](../03_common/03_02_iptables.md).
- Set firewall rules first, following [here](Latest/05_firewall/05_04_opnsense_rules.md).

#### Create directory for container

```bash
mkdir -p ~/data/containers/adguard
chmod 700 ~/data/containers/adguard
sudo setfacl -m d:g::0 ~/data/containers/adguard
sudo setfacl -m d:o::0 ~/data/containers/adguard
mkdir -p ~/data/containers/adguard/{work,config,certs}

```

> AdGuard Home container executes as root permission in container. It is not necessary to give `setfacl`. Because the container's root account is mapped as host's uid.

### Podman Image

```bash
podman pull adguard/adguardhome:v0.107.68 # Do not use latest version to management
```

### Quadlet

- File: 
	- ~/data/config/containers/adguard/adguard.container

```ini
# ~/data/config/containers/adguard/adguard.container
[Quadlet]
DefaultDependencies=false

[Unit]
Description=AdGuard Home DNS

After=bind.service
Requires=bind.service


[Container]
Image=docker.io/adguard/adguardhome:v0.107.68

ContainerName=adguard

AddHost=bind.ilnmors.internal:host-gateway

PublishPort=2053:53/tcp
PublishPort=2053:53/udp
PublishPort=2443:443/tcp
PublishPort=2443:443/udp
PublishPort=3000:3000/tcp
# 3000 is temporary port, After TLS setting, delete it.

Volume=%h/data/containers/adguard/work:/opt/adguardhome/work:rw
Volume=%h/data/containers/adguard/config:/opt/adguardhome/conf:rw
Volume=%h/data/containers/adguard/certs:/etc/ssl/adguard:ro

Environment="TZ=Asia/Seoul"

Label=diun.enable=true
Label=diun.watch_repo=true

[Install]
WantedBy=default.target
```

#### Create systemd `.service` file

```bash
ln -s ~/data/config/containers/adguard/adguard.container ~/.config/containers/systemd/adguard.container 

systemctl --user daemon-reload
```

#### Enable and start service

```bash
systemctl --user start adguard.service
```


### Web UI configuration

#### Access web UI and initial setting

- URL: http://192.168.10.11:3000
	> After TLS certificate setting, access to adguard via https `https://192.168.10.11` or `https://adguard.ilnmors.internal`

#### Initial setting wizard

- Administrator interface
    - Network interface: all
    - Interface port: 3000
- DNS server
    - Network interface: all
    - Interface port: 53
- Authentication
    - User: adguard
    - Password: Password

### AdGuard Configuration

#### General setting

- Filter update interval: 1 hour
- \[\*\] Use AdGuard browsing security web service
- \[\*\] Enable log
- Query logs rotation - 90 days
- \[\*\] Enable statistics
- `Save`

#### DNS settings

- Upstream DNS servers

```text
# Cloudflare DNS
tls://security.cloudflare-dns.com
# Internal DNS bind.ilnmors.internal:2253
[/ilnmors.internal/]udp://bind.ilnmors.internal:2253
# Split Horizon DNS
[/*.ilnmors.com/]udp://bind.ilnmors.internal:2253
```

> Internal authoritative DNS will be BIND. BIND will use 2253 port. `bind.ilnmors.internal` is defined on container's `/etc/hosts`, it allows communication with host system.

- \[\*\] Parallel requests
- Private reverse DNS servers

```text
udp://bind.ilnmors.internal:2253
```

> Set this option after BIND prepared

- \[\*\] Use private reverse DNS resolvers
- \[\*\] Enable reverse resolving of client's IP addresses
- `Apply` and `Test upstreams`

- \[ \] Enable cache

- `Save`
- Disallowed domains

```text
...
wpad.ilnmors.internal
_ldap._tcp.dc._msdcs.ilnmors.internal
```

- `Save configuration`

#### Client settings

- Add Client

|                      Client                      |   Name    |
| :----------------------------------------------: | :-------: |
|            169.254.1.2, 192.168.10.11            | localhost |
| 10.10.10.2, 10.10.10.3, 10.10.10.4, 192.168.1.11 |  console  |

#### Filters - DNS blocklists

- Add blocklist - Choose from the list
    - 1Hosts (Lite)
    - AdGuard DNS filter
    - AdAway DNS Popup Hosts filter
    - HaGeZi's Ultimate Blocklist
    - OISD Blocklist Big
    - KOR: List-KR DNS

#### DNS rewrites

- Filters:DNS rewrites
	- bind.ilnmors.internal - 192.168.10.11

#### Clients' DNS setting

##### OPNsense

- System:Settings:General
	- DNS server: 192.168.10.11
- Services:KEA DHCP:KEA DHCPv4:Subnets
	- DNS server: 192.168.10.11

##### Hypervisor

- /etc/resolv.conf
	- nameserver 192.168.10.11

##### net

- /etc/resolv.conf
	- nameserver 192.168.10.11

##### VPN client
```ini
[Interface]
DNS = 192.168.10.11
```


---
#### Encryption setting

> It requires `BIND` and `Step-CA`

- \[\*\] Enable Encryption (HTTPS, DNS-over_HTTPS, and DNS-over-TLS)
- \[\*\] Enable plain DNS
- \[\*\] Redirect to HTTPS automatically
- HTTPS port: 443

##### Certificates

> AdGuard home doesn't support ACME protocol by itself. It is necessary to use OPNsense's ACME client function to automate adguard home certificates.

- Add new domain in BIND, Following [here](../06_network/06_03_net_bind.md).
    - net server
    - file: ~/data/containers/bind/lib/db.ilnmors.internal
    ```text
    ...
    adguard     IN     CNAME     net.ilnmors.internal.
    ...
    ```

- ACME setting (OPNsense)
    - Services:ACME Client:Certificates - Certificates - \[+\]
    - Common Name: adguard.ilnmors.internal
    - Description: adguard
    - ACME Account: acme.ilnmors.internal
        > Even though provisioner's name includes `@`, it has to use as `.`.
        > 
        > i.e. `acme@ilnmors.internal` > `acme.ilnmors.internal`
    - Challenge Type: ilnmors.internal-dns-01-challenge
    - \[\*\] Auto Renewal
    - Automations: adguard-auto-acme, adguard-auto-restart

- Automations (OPNsense)
    - Services:ACME Client:Automations - Automation - \[+\]
    - Name: adguard-auto-acme / adguard-auto-restart
    - Description: adguard acme crt issue / restart adguard after crt is issued
    - Run Command: Upload certificate via SFTP / Remote command via SSH
    - SFTP Host: adguard.ilnmors.internal
    - Username: net
    - Identity Type: ed25519
    - Remote Path(SFTP): /home/net/data/containers/adguard/certs
    - Command(SSH): systemctl --user restart adguard
    - `Show Identity`
        > Copy Required parameters `ssh-ed25519 ~~~ root@opnsense.ilnmors.internal`
        > 
        > Add parameters in net server's ~/.ssh/authorized_keys
    - `Test Connect` and `Save`

- \[\*\] Set a certificates file path: `/etc/ssl/adguard/adguard.ilnmors.internal/fullchain.pem`
- \[\*\] Set a private key file: `/etc/ssl/adguard/adguard.ilnmors.internal/key.pem`
- \[Save configuration\]

##### Modify container file

- Delete `PublishPort=3000:3000/tcp` part
- `systemctl --user daemon-reload`
- `systemctl --user start adguard`