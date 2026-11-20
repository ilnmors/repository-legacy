Tags: #plan, #common 

## Hardware information

### Server Hardware

- Server: Aoostar WTR Pro N150
	- N150 Processor (4C4T)
	- Samsung DDR4 SO-DIM Memory (31GiB)
	- Samsung NVMe SSD (1TB)
	- SATA HDD (2TB) x 4

### BIOS configuration

- Access BIOS menu with `del`
- BIOS:Advanced:Hardware Monitor:Smart Fan Function
- CPU Fan / Sys Fan1 / Sys Fan2
	- Fan Start Temperture: 45

## VM Plans

### Local MAC address

- Private Local MAC address principal
- 0A:49:6E:4D:\[VM\]:\[Ports\]

### Hypervisor

- OS: Debian13
- CPU: pCPU
- Memory: 3GiB
	- This value is just margin of hypervisor. The rest of allocation of VMs.
	- KSM is activated by ksmtuned
- MAC: C8:FF:BF:05:AA:B0, C8:FF:BF:05:AA:B1
- Disk: 64GiB (`/`), 700 GiB (`/var/lib/libvirt`)

### Firewall

- OS: OPNsense25.7 (FreeBSD14.3)
- CPU: 2vCPU (cputune.shares 2048)
- Memory: 4GiB
- MAC: 0A:49:6E:4D:00:00, 0A:49:6E:4D:00:01
- Disk: 64GiB - qcow2
- Services:
	- Firewall
	- IPS/IDS (CrowdSec LAPI, Suricata)
	- Kea DHCP
	- Central ACME client (automation)

> Do not allow web ui access from WAN, and only allow specific console user to access its web ui. Do not open ssh port at all, when you need to access its console use virsh console on the hypervisor. Because this is the center of security in this homelab.

### Network server

- OS: Debian13
- CPU: 1vCPU (cputune.shares 512)
- Memory: 2GiB
- MAC: 0A:49:6E:4D:01:00
- Disk: 32GiB - qcow2
- Services:
	- DDNS script
	- AdGuard Home (Resolver DNS)
	- BIND9 (Authoritative DNS)

### Authorization server

- OS: Debian13
- CPU: 2vCPU (cputune.shares 1024)
- Memory: 4GiB
- MAC: 0A:49:6E:4D:02:00
- Disk: 64GiB - qcow2
- Services:
	- Step-CA (File based)
	- Caddy-main (Reverse proxy)
		- Infrastructure services won't use caddy.
		- OPNsense
		- CrowdSec
		- AdGuard Home
		- Step-CA 
	- Authellia (idP) + LLDAP (PostgreSQL)
### Development server

- OS: Debian13
- CPU: 2vCPU (cputune.shares 1024)
- Memory: 6GiB
- MAC: 0A:49:6E:4D:03:00
- Disk: 256GiB - qcow2
- Services:
    - Postgresql
    - Prometheus
	    - OS: node_exporter(and telegraf)
	    - VM: libvirt-exporter
	    - HDD: btrfs-exporter
    - Grafana 
    - Uptime kuma (SQLite)
    - Loki, Promtail
    - Code-server (File based)
    - Postfix, Dovecot, mbsync
	    - These services are only uses in local mail service (@ilnmors.intenral)
	    - Postfix (Split mail transper, @ilnmors.internal - directly process and @gmail.com - relayhost)
	    - Dovecot (IMAP/POP3 server, Save the mail itself)
	    - mbsync (Get external mail from external service to Dovecot with IMAP protocol)
	- Diun (File Provider mode + github provider mode)
> Volume:~/data/containers/code-server/workspace/homelab:/path/of/diun:ro
> File Provider activate and read `.container`
> `.container` needs to have label `Label=diun.enable=true`,  `Label=diun.watch_repo=true`. 
> In case of local image, use this way.

```yaml
# diun.yml
regopts:
  - name: "caddy-auth-source"
    image: "docker.io/caddy"
```

```ini
# container file
Label=diun.enable=true
Label=diun.watch_repo=true
Label=diun.regopt=caddy-auth-source
```


### Application server

- OS Debian13
- CPU 4vCPU (cputune.shares 2048)
- Memory: 12GiB
- MAC: 0A:49:6E:4D:04:00
- Disk:
	- 256GiB - qcow2
	- 4TB - RAID10, BTRFS
- Services (OIDC is supported):
	- OpenCloud (The fork of OwnCloud; It includes Radical, and LibreOffice. Radical will be used as only CardDAV)
	- Vikunja (CalDav and To-Do list server; PostgreSQL)
	- Gitea (Git service, and wiki; PostgreSQL)
	- Outline (Small memo note server; PostgreSQL)
	- Wiki.js (Report and book editor; PostgreSQL)
	- Immich (Photo album; PostgreSQL)
	- PeerTube (Private UCC platform; PostgreSQL)
	- Funkwhale (Music server; PostgreSQL)
	- Kavita (Web bookshelf; SQLite)
    - Audiobookshelf(SQLite)
	- Actual budget (Budget program; SQLite)
	- Paperless-ngx (Paper based information collection; OCR; PostgreSQL)
	- Miniflux (RSS management; PostgreSQL)
	- Linkwarden (Archaiving Website; PostgreSQL)
	- Ralph (IT products management; PostgreSQL)
    - Conduit (Rust matrix server; Local DB)
    - SnappyMail (Web mail service frontend with Dovecot)
    - Vaultwarden (Password manager; PostgreSQL)
    - n8n (Following goal, automation the flow; PostgreSQL)
- Services (Foward_Auth is needed): 
	- Kopia (backup)
	- Hompage
		- Define access control with yaml file via Authelia.
		```yaml
		  - Admin tools:
		    - group: admin
		    - OPNsense
		      - href: "https://opnsnese.iltnmors.internal"
		        
		 - Services:
		   - group: ["admin", "user"]
		   - Gitea:
		     - href:"https://gitea.iltnmors.com"
		```

- Services(Study): 
	- Kali (Container)
	- Alpine (Container)

> These containers will be isolated by podman network (which has no host gateway) and podman volume. The study and practice will be conducted only in container with `podman exec -it kali bash`

### RDBMS and Redis

#### RDBMS

Postgresql and mariaDB will be provide database for various services on `auth`, `dev`, `app` servers. Each app can access RDBMS, Postgresql and mariaDB on `dev` server which is the central DB server with TLS.

#### Redis

Redis is the cache database, it will operate on each server where Redis is needed `dev`, and `app`, and it supports various app as one container with its own id.

## Matrix

### Network matrix

#### LAN

- Subnet: 192.168.1.0/24
- tag: 1 (Native-untagged)
- Static IPs:
    - 1: Gateway (opnsense)
    - 2-9: Spare IP for APs
    - 10: Hypervisor (vmm)
    - 11-12: Console
    - 20: Backup Server
    - 30: Printer
- Dynamic IP pool
    - 100-254

#### VLAN10

- Subnet: 192.168.10.0/24
- tag: 10
- Static IPs:
    - 1: Gateway (opnsense)
    - 10: Hypervisor (vmm)
    - 11: Network server (net)
    - 12: Authorization server (auth)
    - 13: Development server (dev)
    - 14: Application server (app)

#### VPN

- Subnet: 10.10.10.0/24, 10.10.1.0/24
- Static IPs:
	- 10.10.10.1: Gateway(opnsense)
	- 10.10.10.2: console
	- 10.10.10.3: phone
	- 10.10.10.4: spare

### UID/GID matrix

#### Local UID/GID

- Pool: 2000-2999
- Static UID:
    - 2000: Hypervisor (vmm)
    - 2001: Network server (net)
    - 2002: Authorization server (auth)
    - 2003: Development server (dev)
    - 2004: Application server (app)
- Static GID: 2000 (svadmins)

#### LDAP reservation

- pool: 3000 - 60000

#### Sub id

- Subuid/Subgid: 100000:65536

## File management

### File name

- Code files have to use `_` as a separator. (`.sh`, `.py`, etc.)
- Normal files have to use `-` as a separator.

### Directory structure

#### Hypervisor

- ~/data/config/{scripts,server,services,vms}
- ~/data/config/vms/{networks,storages,dumps}
- /var/lib/libvirt/images

#### VMs

- ~/data/{config,containers}
- ~/data/config/{containers,scripts,secrets,server,services}
- ~/data/containers/apps/{certs,etc.}
- ~/kopia
- /etc/secrets/$UID

#### Application server

##### SSD

- ~/data/{config,containers}
- ~/data/config/{containers,secrets,scripts,services}
- ~/data/containers/app/{certs,etc.}
- ~/kopia
- /etc/secrets/$UID

##### HDD

- btrfs
- ~/hdd/data/containers
- ~/hdd/backups
- The scrub timer systemd is required for its integrity.

## Certificates management

- CA: Step-CA (private CA)
- DNS: BIND9 (private authoritative DNS)
### ACME client

- ACME client: opnsense's `os-acme-client`
- Automation:
	- `Upload certificate via SFTP`
	- `Run command via SSH`

### Caddy

- `caddy-dns/rfc2136`
- `hslatman/caddy-crowdsec-bouncer/crowdsec`
- `hslatman/caddy-crowdsec-bouncer/http`


## Secret management

> It is necessary external KMS or secret management server (like Vault, infisical) not to leave plain data on disk. It is to hard to manage in small homelab environment. Especially, even systemd-cred uses TPM or hardware module, this makes harder to use this on rootless and vm environment. This is why compromise with perfect secret management.

### Secret file

- Files: 
	- ~/data/config/secrets/.secret.yaml
	- ~/data/config/secrets/age-key.gpg
	- ~/data/config/scripts/edit_secret.sh
	- ~/data/config/scripts/extract_secret.sh
- Directories:
	- /etc/secrets
		- Ownership: root:root
		- permission: 511
	- /etc/secrets/$UID/file
		- Ownership: $UID:root
		- Permission: 500(directory), 400(file)
### Sequence

- Create `.secret.yaml`
- Cerate `age-key`
- Encrypt `.secret.yaml` with `sops` by `age` key
- Modify `.secret.yaml` with `edit_secret.sh` 
- Create `podman secret` or `/etc/secrets/$UID/file` with `extract_secret.sh`

> Creating podman secret is always manually conducted by `extract_secret.sh`. There is no plain text of secret data in backup target, or git target.

```yaml
# .secret.yaml
# ~/data/config/secrets/.secret.yaml
# Format of .secret.yaml

# app1.env:
1SECRET: '1secret'
2SECRET: '2secret'

app1.file: |
  -----TEXT-AREA-----
  contents of 3secret
  -----END-AREA-----

# app2.env
3SECRET: '3secret'
4SECRET: '4secret'

# ...
```

#### Secret scripts

- File:
	- ~/data/config/scripts/secrets/edit_secret.sh
	- ~/data/config/scripts/secrets/extract_secret.sh

```bash
#!/bin/bash
# edit_secret.sh /path/of/secret

set -e

KEY_PATH="$HOME/data/config/secrets"
SECRET_FILE="$1"

usage() {
        echo "Usage: $0 \"/path/of/secret/file\""
        exit 1
}


if [ -z "$SECRET_FILE" -o ! -f "$SECRET_FILE" ]; then
	echo "Error: Secret file path is needed"
	usage
fi


if [ ! -f "$KEY_PATH/age-key.gpg" ]; then
	echo "Error: There is no key file"
	exit 1
fi

# Delete password file after script
cleanup() {
	if [ -f "/run/user/$UID/age-key" ]; then
		rm -f "/run/user/$UID/age-key" 
	fi
}

trap cleanup EXIT



echo -n "Enter GPG passphrase: "
read -s GPG_PASSPHRASE
echo

echo "$GPG_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \
--output "/run/user/$UID/age-key" \
--decrypt "$KEY_PATH/age-key.gpg" && \
chmod 600 "/run/user/$UID/age-key"

if [ -z "/run/user/$UID/age-key" ]; then
	echo "Error: Key file does not exist"
	exit 1
fi

gpgconf --kill gpg-agent

SOPS_AGE_KEY="$(cat "/run/user/$UID/age-key")"

SOPS_AGE_KEY="$SOPS_AGE_KEY" sops "$SECRET_FILE"
```

```bash
#!/bin/bash
# extract_secret.sh /path/of/secret (-f|-e <value>)

set -e

KEY_PATH="$HOME/data/config/secrets"
SECRET_FILE=$1

# shift the $2 as $1 ($1 < $2)
shift

# usage() function
usage() {
        echo "Usage: $0 \"/path/of/secret/file\" (-f|-e \"yaml section name\")" >&2
        echo "-f <type name>: Print secret file" >&2
        echo "-e <type name>: Print secret env file" >&2
        exit 1
}

while getopts "f:e:" opt; do
    case $opt in
        f)
            VALUE="$OPTARG"
            TYPE="FILE"
            ;;
        e)
            VALUE="$OPTARG"
            TYPE="ENV"
            ;;
        \?) # unknown options
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :) # parameter required option
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Get option and move to parameters - This has no functional thing, because it only use arguments with parameters
shift $((OPTIND - 1))

# Check necessary options
if [ ! -f "$SECRET_FILE" ]; then
    echo "Error: secret file path is required" >&2
    usage
fi

if [ -z "$TYPE" ]; then
        echo "Error: -f or -e option requires" >&2
        usage
fi


if [ ! -f "$KEY_PATH/age-key.gpg" ]; then
        echo "Error: There is no key file" >&2
        usage
fi

# Delete password file after script
cleanup() {
        if [ -f "/run/user/$UID/age-key" ]; then
                rm -f "/run/user/$UID/age-key"
        fi
}

trap cleanup EXIT

echo -n "Enter GPG passphrase: " >&2
read -s GPG_PASSPHRASE
echo >&2

echo "$GPG_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \
--output "/run/user/$UID/age-key" \
--decrypt "$KEY_PATH/age-key.gpg" && \
chmod 600 "/run/user/$UID/age-key"

if [ ! -f "/run/user/$UID/age-key" ]; then
        echo "Error: Key file does not exist" >&2
        exit 1
fi

gpgconf --kill gpg-agent

SOPS_AGE_KEY="$(cat "/run/user/$UID/age-key")"

if [ "$TYPE" == "FILE" ]; then
        if RESULT=$(SOPS_AGE_KEY="$SOPS_AGE_KEY" sops --decrypt --extract "[\"$VALUE\"]" --output-type binary "$SECRET_FILE") ; then
                echo -n "$RESULT"
                exit 0
        else
                echo "Error: SOPS extract error" >&2
                exit 1
        fi
fi

if [ "$TYPE" == "ENV" ]; then
        if RESULT=$(SOPS_AGE_KEY="$SOPS_AGE_KEY" sops --decrypt --extract "[\"$VALUE\"]" --output-type dotenv "$SECRET_FILE") ; then
                echo -n "$RESULT"
                exit 0
        else
                echo "Error: SOPS extract error" >&2
                exit 1
        fi
fi
```

##### Secret value management

- Using `extract_secret.sh`
- Inject secret value to `podman secret` or `/etc/secrets/$UID`

```bash
# /etc/secrets/$UID
# Before use sudo tee, make sure sudo doesn't need password.
# i.e. sudo ps -ef command execute before this command.
# Env file
extract_secret.sh ~/data/config/secrets/.secret.yaml -e "$value" > /run/user/$UID/tmp.env \
&& sudo mv /run/user/$UID/tmp.env /etc/secrets/$UID/"$FILE_NAME" \
&& sudo chown $UID:root /etc/secrets/$UID/"$FILE_NAME" \
&& sudo chmod 400 /etc/secrets/$UID/"$FILE_NAME"
# Normal file
extract_secret.sh ~/data/config/secrets/.secret.yaml -f "$value" > /run/user/$UID/tmp.env \
&& sudo mv /run/user/$UID/tmp.env /etc/secrets/$UID/"$FILE_NAME" \
&& sudo chown $UID:root /etc/secrets/$UID/"$FILE_NAME" \
&& sudo chmod 400 /etc/secrets/$UID/"$FILE_NAME"

# Podman secret
# Podman doesn't supports .env file parsing, you have to enroll all values
extract_secret.sh ~/data/config/secrets/.secret.yaml -f "$value" | podman secret create "[$FILE_NAME|$ENV_NAME]" -
```
#### Use podman secret

```ini
# app.container
[Unit]
Description=app

[Service]
StartExecPre=/bin/bash -c "wait-for-it.sh ip:port -t 0"

[Container]
...
Secret=app.env,type=env,target=$ENVRIONMENT_NAME
# or
secret=app_data.file,target=/path/of/secret/file
...
```

> podman secret save the `secret data` as `plain text` in disk. However, it is not necessary to have full security in small homelab (practically, it is hard to realize in small environment without external secret server like infisical or vault). When the root permission or user permission compromised then it can be readable.

#### Change secret

- Edit `.secret.yaml`
- podman container stop (systemctl)
- `podman secret rm $target`
- Use `extract_secret.sh`
- Restart podman container

### After code-server building

Move all secret file on `dev` server's `code-server` container.

- Files:
	- .secret.yaml
	- age-key.gpg
	- edit_secret.sh
	- extract_secret.sh
- Path: $HOME/workspace/homelab/data/common/config/{secrets,scripts} (Mapped volume in container)
- Change the KEY_PATH as `$HOME/workspace/homelab/data/common/config/{secrets,scripts}` on scripts

#### Apply secrets from code-server

Use SFTP and SSH (or Ansible playbook), decrypt the secret values and make a file on container's `/run/user/$UID` and upload to target server's `/run/user/$UID`. Then use ssh remote command to add podman secret or mv command at the code-server container.

It can works on the code-server web terminal. However, if there were problems on caddy, which means not to access web console then just use ssh and podman exec.

## Update and upgrade policy

### Hypervisor

- Never update or upgrade hypervisor before the its stability is verified from other VMs

### VMs

- Make a qcow2 snapshot before major update or upgrade, using `virsh snapshot`
- If there were some problems, rollback using snapshot.

### Containers

- Check the version from Diun.
- Read caution and changes.
- Apply the update via container file (Prepare the containerfile to make image). `systemctl --user daemon-reload` and `systemctl --user restart container`

## Backup policy

### Kopia

- ~/kopia: The directory of kopia configuration files.
- ~/hdd/backups: The destination directory of each server's Kopia.
- Don't backup the live data such as live DB data.
- Only configuration files are backed up in hypervisor.

### Configuration file backup

- Save all configuration files in `code-server` container.
- Path: ~/data/containers/code-server/workspace/homelab
- Use `Gitea` container to track and manage files.
- Apply `Ansible` on `code-server` (Following goal)

### opnsense

- `os-sftp-backup` sends its configuration towards `code-server`

### Application data

#### Common data

- `Kopia` backup files to app server using sftp
- Backup target: ~/data
- Path: ~/hdd/backups

#### DB data

Only backup `dump` db data.

##### Schema backup

```bash
# Dev server
podman exec postgresql sh -c 'pg_dumpall --scheme-only' > ~/data/postgresql/backups/postgresql-cluster-\[date\].dump
```

##### DB data backup

```bash
# VM's application data backup
podman exec application sh -c 'pg_dump -U $DB_USER -p $DB_PW' > ~/data/containers/application/backups/application-\[date\].dump

# app's application data backup
podman exec application sh -c 'pg_dump -U $DB_USER -p $DB_PW' > ~/hdd/data/containers/application/backups/application-\[date\].dump
```

##### Container volume

```ini
# app.container
#...
[Container]
# ...
Volume=~/data/containers/application/backups:/backups:rw
```

##### Example of DB backup senario

```ini
# postgres-db-backup.service
[Unit]
Description=PostgreSQL Database Backup
After=postgresql.service
Requires=postgresql.service

[Service]
Type=oneshot
# %% is needed in systemd, because `%` has special meaning in systemd.
ExecStart=/bin/sh -c 'podman exec postgresql sh -c "pg_dumpall --scheme-only" > ~/data/containers/postgresql/backups/postgresql-cluster-$(date +%%Y-%%m-%%d_%%H-%%M-%%S).dump'

Nice=19
IOSchedulingClass=idle

# Management DB dump file
ExecStopPost=/bin/bash -c `find "~/data/containers/postgresql/backups/" -maxdepth 1 -type f -mtime +7 -delete`
```

```ini
# postgres-db-backup.timer
[Unit]
Description=Run PostgreSQL backup daily at 2:30 AM

[Timer]
# everyday 02:30 AM start
OnCalendar=*-*-* 02:30:00
# Random time to postpone the timer
RandomizedDelaySec=15min
Persistent=true

[Install]
WantedBy=timers.target
```

#### External backup

- Use `Kopia` in app server to backup files to external data server.

#### Verify backup

- Restore random directory from backup on dev server's test directory once a month (or week).
- Check its integrity and availability.
- If there were some problems, check the all backup data and conduct full backup immediately.

## Systemd

### `.service` file

- Path: ~/.config/systemd/user
- Example of `.service`

```ini
# ~/data/config/services/opnsense.service
# ~/.config/systemd/user/opnsense.service
[Unit]
Description=opnsense Auto Booting
After=network-online.target
Wants=network-online.target
# Requires=x.services

[Service]
Type=oneshot

# Maintain status as active
RemainAfterExit=yes

# Wait for other dependent services
# ExecStartPre=%h/data/config/scripts/wait-for-it.sh -h [ip] -p [port] -t 0

# Run the service
ExecStart=/usr/bin/virsh -c qemu:///system start opnsense

# Stop the service
ExecStop=/usr/bin/virsh -c qemu:///system shutdown opnsense

[Install]
WantedBy=default.target
```

### Hypervisor

- Adjust booting sequence of VMs via `.service`
- Use `wait-for-it.sh` and `Requires`
- Sequence
	- vmm
	- opnsense
	- net
	- auth
	- dev
	- app

### Containers

#### Quadlet

- Make the `.container` file
- Path: ~/data/config/containers/\[app_name\]
- Symbolic link path: ~/.config/systemd/containers
- `systemctl --user daemon-reload` makes `.service` file automatically
- If pod is needed, then set `.pod` file

```ini
# app.container
[Quadlet]
# Don't make a dependencies
DefaultDependencies=false

[Unit]
# Pod=app.pod
Description=app
After=network-online.target
Wants=network-online.target
Requires=required.service

[Service]
StartExecPre=%h/data/config/scripts/wait-for-it.sh dev.ilnmors.internal:8080 --timeout=0 --strict

[Container]
# pod=app-pod
Image=localhost/app:1.0.0
Name=app
Port=2080:80/tcp
Port=2443:443/tcp
Volume=%h/data/containers/app/etc:/etc/app:rw
Volume=%h/data/containers/app/data:/app:rw
Secret=app.env,type=env
Secret=app.file,type=file,target=/path/of/secret/file

[Install]
WantedBy=default.target
```

```ini
# app.pod
[Quadlet]
# Don't make a dependencies
DefaultDependencies=false

[Pod]
Name=app
PublishPort=2080:80/tcp
```