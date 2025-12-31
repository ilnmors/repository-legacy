Tags: #common, #configuration, #network, #security

## CrowdSec

CrowdSec is the free, open-source IPS(Intrusion Prevention System). It has a distributed architecture. When an agent detects malicious IPs from log, it reports the information to LAPI. This information is shared to CrowdSec's central server anonymously and is spread across the world. Additionally, bouncer receives a blacklist from LAPI and when they approach the server, the bouncer blocks them.


### Collection

#### Parser

It is how to organize the raw logs to the parsed log that scenario can understand. It is works on agent, and parsed log is transferred to LAPI to decide.
#### Scenario

It is how to analyze the malicious attack from the parsed log from the Agent. The LAPI decides what to do for malicious attack, and transfers the result to Bouncer to block.

### Agent

Agent is the detector in each server. They analyze the logs. When they find malicious approaches, or abnormal and harmful actions, they report the information to LAPI(Local API). It analizes the log following `Parsers`.

### LAPI

LAPI server is a local central collector and reporter of malicious attack information. It decides what to apply for traffic following `Scenarios`.  In this homelab it is located in OPNsense, because the center of gateway of home network is Firewall. When agent reports threats to the LAPI server, LAPI decides whether or not to block them, and reports to the central CrowdSec server. This information will be spread to all CrowdSec users in the world.

### Bouncer

When LAPI decides to block some IPs, they create a blacklist and give it to bouncer. Bouncer blocks and bans some IPs depending on LAPI's blacklist. `Caddy-auth (L7)` and `OPNsense (L4)` will be bouncer to ban. The most important thing is LAPI just decide what to ban, and Bouncer conducts ban practically.

## CrowdSec in OPNsense

OPNsense supports CrowdSec with community plugin. This is not a basic function so when you want to use it in OPNsense you should install the community plugin.

### Installation

- System:Firmware:Plugins
    - \[\*\] Show community plugins
    - `os-crowdsec`

### General configuration

Services:CrowdSec:Settings
    - \[\*\] Enable Log Processor (IDS)
    - \[\*\] Enable LAPI
    - \[\*\] Enable Remediation Component (IPS)
    - \[ \] Manual LAPI configuration
    - LAPI listen address: \[opnsense IP: 192.168.10.1\]
    - LAPI listen port: 8080
    - \[\*\] Create blocklist rules
    - `Apply`

> Enable Remediation Component (IPS) option means, Bouncer will be integrated with OPNsense's firewall rules

> Set LAPI configuration manually, `Manual LAPI configuration` is needed.

### Machines configuration

#### OPNsense console

```sh
# 8) shell
cscli machines add [server_name] -a -f -
# ---
# Machine 'server_name' successfully added to the local API.
# url: http://192.168.10.1:8080
# login: [server_name]
# password: (API key)
# ---
```

#### Each server

```ini
# /etc/crowdsec/local_api_credentials.yaml
url: http://192.168.10.1:8080
login: [server_name]
password: (API key)
# /etc/crowdsec/acquis.d/sshd.yaml
---
source: journalctl
journalctl_filter:
	- "_SYSTEMD_UNIT=ssh.service" labels: 
	  type: sshd
	  # origin value is syslog
---

```

```bash
sudo systemctl restart crowdsec
```

#### OPNsense web UI

- Services:CrowdSec:Machines
- checking the lists of server
- Main CLI commands of CrowdSec

```sh
# View active decisions(Ban list)
cscli decisions list

# View alerts
cscli alerts list

# Check connected machines(agents)
cscli machines list
```

---
## TLS on crowdsec communication

TLS can be applied in CrowdSec communication when internal PKI are set (BIND, Step-CA, ACME-Client in OPNsense). CrowdSec communication can contain sensitive information such as API key, it is recommended to set TLS.

### General configuration

- Services:CrowdSec:Settings
    - \[\*\] Manual LAPI configuration

### DNS setting

### Add new domain in BIND

Following [here](../06_network/06_03_net_bind.md).
- net server
- file: ~/data/containers/bind/lib/db.ilnmors.internal

```text
...
crowdsec     IN     CNAME     opnsense.ilnmors.internal.
...
```

### ACME setting

#### Use opnsense certificates

- Services:ACME Client:Certificates - Certificates
	- Alt name: crowdsec.ilnmors.internal

#### Certificate and key file

- opnsense
- file:
    - /var/etc/acme-client/cert-home/\[ramdom_string\]/opnsense.ilnmors.internal/
        - fullchain.cer
        - opnsense.ilnmors.internal.key
         > There is `opnsense.ilnmors.internal.cer` file. However, when client verify the certificate, it verify the intermediate CA's certificate and root CA's certificate both. Therefore, in this case, use fullchain.cer
    - /usr/local/etc/ssl/cert.pem

### Add TLS setting in LAPI configuration

- opnsense
- file:
    - /usr/local/etc/crowdsec/config.yaml
    - /usr/local/etc/crowdsec/local_api_credentials.yaml
    - /usr/local/etc/crowdsec/bouncer/crowdsec-firewall-bouncer.yaml

```yaml
# config.yaml
api:
  client:
    # ...client configurations
  server:
    enable: true
    listen_uri: 192.168.10.1:8080 # actual IP address is required. (Do not use FQDN in here, the service listener is binded on network interface)
    # ... server configurations
    tls:
      cert_file: /var/etc/acme-client/cert-home/[random_string]/opnsense.ilnmors.internal/fullchain.cer
      key_file: /var/etc/acme-client/cert-home/[ramdom_string]/opnsense.ilnmors.internal/opnsense.ilnmors.internal.key
# random string is generated by opnsense itself. In real environment, check it first.
```

```yaml
# local_api_credentials.yaml
...
url: https://crowdsec.ilnmors.internal:8080/
```

```yaml
# crowdsec-firewall-bouncer.yaml 
...
api_url: https://crowdsec.ilnmors.internal:8080/
...
```

```sh
service crowdsec restart
```

#### CrowdSec LAPI restart setting

- opnsense
- file: /usr/local/etc/cron.d/crowdsec

```text
#minute hour    mday    month   wday    who     command
0       3       *       *       *       root    /usr/local/libexec/crowdsec/upgrade-hub
30      3       *       *       *       root    /usr/sbin/service crowdsec reload # Add this line to reload every day.
```

### Each server configuration

#### Server's certificate trust

- each server
- file: /usr/local/share/ca-certificates/root_ca.crt

```bash
sudo update-ca-certificates
```

#### CrowdSec Agent setting

```ini
# /etc/crowdsec/local_api_credentials.yaml
url: https://crowdsec.ilnmors.internal:8080
login: [server_name]
password: (API key)
```

```bash
sudo systemctl restart crowdsec
```

---

## Crowdsec in Caddy-auth

Caddy supports bouncer. Also, it can be work as agent via auth server where Caddy-auth is located.

### Bouncer configuration

> Caddy has to contain local CA's root_ca.crt (Step-CA). - containerfile already includes root_ca.crt in container when it was built

#### OPNsense console

```sh
cscli bouncer add caddy-auth

> API key for 'caddy-auth':

>	Secret_value

> Please keep this key since you will not be able to retrieve it!
> 
> 
cscli collections install crowdsecurity/caddy
```

#### Caddyfile

```ini
# ...
# Crowdsec bouncer setting
{
        crowdsec {
                # CrowdSec LAPI
                api_url https://crowdsec.ilnmors.internal:8080
                api_key "{env.CADDY_CROWDSEC_KEY}"
        }
}
# ...
```

- `podman exec caddy-auth caddy reload --config /etc/caddy/Caddyfile`
### Agent configuration

#### auth sv

- File:
	- /etc/crowdsec/acquis.yaml
	- ~/data/container/caddy_auth/data/access.log

```yaml
# /etc/crowdsec/acquis.d/caddy-auth.yaml
filenames: 
  - /var/log/caddy.log
labels:
  type: caddy 
```

```ini
# Caddyfile
# ...
(crowdsec_log) {
	log {
		output file /data/access.log {
			roll_size 10mb
			roll_keep 5
		}
	}
}
# ...
caddy.ilnmors.com {
	import crowdsec_log
	route {
		crowdsec
		root * /usr/share/caddy
		file_server
	}
}
```

```bash
podman exec caddy-auth caddy reload --config /etc/caddy/Caddyfile
sudo mkdir /etc/crowdsec/acquis.d
sudo nano /etc/crowdsec/acquis.d/caddy-auth.yaml
ln -s /home/auth/data/containers/caddy-auth/data/access.log /var/log/caddy.log
# install collection(senario + parser) crowdsecurity/caddy
sudo cscli collections install crowdsecurity/caddy
sudo systemctl restart crowdsec
sudo cscli metrics
```

---
## PLAN

- distributed bouncer
    - [x] Caddy bouncer

- [ ] dash board