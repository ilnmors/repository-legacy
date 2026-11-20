Tags: #os, #configuration, #virtualization, #container, #database

## postgresql

Postgresql is one of most famous open source RDBMS (Relational Database Management System). RDBMS saves the data as table which is based on row and coloumn. This uses SQL (Structure Quarey Language) to manage a lot of data and guarantee integrity of data.

### Secret management

All transaction of postgresql which needs root permission will be conducted on local container or podman exec (without other Pod) in this porject. However, the environment value `POSTGRES_PASSWORD` should be set when the database is initiated. It makes postgresql programs root permission access way as trust which means only local access is allowed. This infromation will be set on `pg_hba.conf` like below.

- `local all postgres trust`
- `hostssl all all 192.168.10.x/32 scram-sha-256` (The server that uses postgresql)
- `host all all 127.0.0.1/32 scram-sha-256`

#### Secret

- File: 
	- ~/data/config/secrets/.secret.yaml

- Edit `.secret.yaml` with `edit_secret.sh`


```yaml
# ~/data/config/secrets/.secret.yaml
# postgresql
POSTGRES_PASSWORD: secret
```

### Preparation

#### iptables and firewall rules

- Set iptables first, following [here](../03_common/03_02_iptables.md).
	- 5432: auth, app
- Set firewall rules first, following [here](Latest/05_firewall/05_04_opnsense_rules.md).

#### Create directory for container

```bash
mkdir -p ~/data/containers/postgresql
chmod 700 ~/data/containers/postgresql
setfacl -m d:g::0 ~/data/containers/postgresql
setfacl -m d:o::0 ~/data/containers/postgresql
setfacl -m u:dev:rwx ~/data/containers/postgresql
setfacl -m u:100998:rwx ~/data/containers/postgresql
setfacl -d -m u:dev:rwx ~/data/containers/postgresql
setfacl -d -m u:100998:rwx ~/data/containers/postgresql
mkdir ~/data/containers/postgresql/{backups,config,certs,data,initdb}

# After generating
c
sudo find ~/data/containers/postgresql -type d -exec setfacl -m m::rwx {} \;
```

> postgresql container executes as 999:999(postgres:postgres) permission in container. It is mapped host's 100998. Therefore, directories have to have ACL via `setfacl`

#### Add new domain in BIND

Following [here](../06_network/06_03_net_bind.md).

- net server
- file: ~/data/containers/bind/lib/db.ilnmors.internal
  
```ini
# ...
postgresql     IN     CNAME     dev.ilnmors.internal.
# ...
```

```bash
# Adguard container has Requires=bind.service. When it restarted, then Adguard also restarted.
systemctl --user restart bind
```

### Podman Image

```bash
podman pull postgres:18.0 # Do not use latest version to management
```

### Config file

- File:
	- ~/data/containers/postgresql/config/postgresql.conf
	- ~/data/containers/postgresql/config/pg_hba.conf


```bash
# extracting config file
podman run --rm postgres:18.0 cat /usr/share/postgresql/postgresql.conf.sample > ~/data/containers/postgresql/config/postgresql.conf

podman run --rm postgres:18.0 cat /usr/share/postgresql/18/pg_hba.conf.sample > ~/data/containers/postgresql/config/pg_hba.conf

# Generate the password
openssl rand -base64 32

# Podman secret
extract_secret.sh ~/data/config/secrets/.secret.yaml -f "POSTGRES_PASSWORD" | podman secret create "POSTGRES_PASSWORD" -
```

> If there were the schema backup file, then go to the `Restore` section.

```ini
# ~/data/containers/postgresql/config/postgresql.conf

# Add settings for extensions here

# hba_file directory
hba_file = '/config/pg_hba.conf'

# Listen_address
listen_addresses = '*'

# listen_port
port = 5432

# SSL
ssl = on
ssl_ca_file = '/etc/ssl/postgresql/root_ca.crt'
ssl_cert_file = '/etc/ssl/postgresql/postgresql.ilnmors.internal/fullchain.pem'
ssl_key_file = '/etc/ssl/postgresql/postgresql.ilnmors.internal/key.pem'
ssl_ciphers = 'HIGH:!aNULL:!MD5'
ssl_prefer_server_ciphers = on

# log
log_destination = 'stderr'
log_checkpoints = on
log_temp_files = 0
log_min_duration_statement = 500

```

```ini
# ~/data/containers/postgresql/config/pg_hba.conf

# Local host `trust`
local   all     all     trust

# Local connection (container) needs password (127.0.0.1 - container loopback)
host    all     all     127.0.0.1/32    scram-sha-256
# Local connection (dev) needs password (169.254.1.2 - host-gateway)
# Maybe Grafana(SQLite), Uptime kuma(SQLite), Loki(BoltDB), Dovecot(LDAP or />
#hostssl        all     all     169.254.1.2/32  scram-sha-256

# auth VM (Authentik, 192.168.10.12)
hostssl all     all     192.168.10.12/32   scram-sha-256

# app VM (Applications, 192.168.10.14)
hostssl all     all     192.168.10.14/32   scram-sha-256

# explicit deny
host    all     all     192.168.10.0/24 reject
```

#### Initiating (Restoring)

- File: 
	- ~/data/config/scripts/postgresql/postgresql_init.sh
	- ~/data/containers/postgresql/backups/postgresql-cluster_$(date "+%Y-%m-%d").sql


```bash
#!/bin/bash
# ~/data/config/scripts/postgresql/postgresql_init.sh [FILE_PATH]
set -e
DATA_PATH="$HOME/data/containers/postgresql/data"
FILE_PATH="$1"
VERSION=18
FLAG=""

# Check the PostgreSQL service

if [ $(systemctl --user is-active postgresql) == "active" ]; then
        echo "PostgreSQL should be terminated"
        exit 1
fi

# Check the podman secret

if [ -z "$(podman secret list | grep "POSTGRES_PASSWORD")" ]; then
        echo "POSTGRES_PASSWORD has to be in podman secret"
        exit 1
fi

# Check the data path

if [ -n "$(ls -A $DATA_PATH)" ]; then
        echo "$DATA_PATH should be empty"
        exit 1
fi

# Check the sql file

if [ -z "$FILE_PATH" ]; then
        echo "Initiating PostgreSQL"
        FLAG="FALSE"
else
        if [ ! -f "$FILE_PATH" -o ! -s "$FILE_PATH" -o -z "$(echo $FILE_PATH | grep "\.sql$")" ]; then
                echo "Availavble .sql format file is needed"
                exit 1
        fi
        echo "Restoring PostgreSQL"
        FLAG="TRUE"
fi



# Initiating
podman run --rm \
--secret POSTGRES_PASSWORD,type=env \
-e TZ="Asia/Seoul" \
-v "$DATA_PATH":/var/lib/postgresql:rw \
postgres:18.0 \
-C "port" || true

# postgresql start
echo "Start postgresql service"
systemctl --user start postgresql

# Restoring
if [ "$FLAG" == "TRUE" ]; then
        while [ -z "$(systemctl --user status postgresql | grep "database system is ready to accept connections")" ]; do
                sleep 1
        done
        echo "Start restoring PostgreSQL"
        cat "$FILE_PATH" | podman exec -i -u postgres postgresql psql -U postgres
        echo "Finish restoring PostgreSQL"
fi

exit 0
```
#### Certificates configuration

- File: ~/data/containers/postgresql/certs/root_ca.crt

- ACME setting (OPNsense)
    - Services:ACME Client:Certificates - Certificates - \[+\]
    - Common Name: postgresql.ilnmors.internal
    - Description: postgresql
    - ACME Account: acme.ilnmors.internal
        > Even though provisioner's name includes `@`, it has to use as `.`.
        > 
        > i.e. `acme@ilnmors.internal` > `acme.ilnmors.internal`
    - Challenge Type: ilnmors.internal-dns-01-challenge
    - \[\*\] Auto Renewal
    - Automations: postgresql-auto-acme, postgresql-auto-restart

- Automations (OPNsense)
    - Services:ACME Client:Automations - Automation - \[+\]
    - Name: postgresql-auto-acme / postgresql-auto-reload
    - Description: postgresql acme crt issue / reload postgresql after crt is issued
    - Run Command: Upload certificate via SFTP / Remote command via SSH
    - SFTP Host: postgresql.ilnmors.internal
    - Username: dev
    - Identity Type: ed25519
    - Remote Path(SFTP): /home/dev/data/containers/postgresql/certs
    - Command(SSH): setfacl -m m::r /home/dev/data/containers/postgresql/certs/postgresql.ilnmors.internal/*  &&  podman exec -u postgres postgresql pg_ctl reload
    - `Show Identity`
        > Copy Required parameters `ssh-ed25519 ~~~ root@opnsense.ilnmors.internal`
        > 
        > Add parameters in net server's ~/.ssh/authorized_keys
    - `Test Connect` and `Save`

- SSH command will be applied after postgresql start.

#### Quadlet

- File: 
	- ~/data/config/containers/postgresql/postgresql.container

```ini
# ~/data/config/containers/postgresql/postgresql.container
[Quadlet]
DefaultDependencies=false

[Unit]
Description=PostgreSQL

After=network-online.target
Wants=network-online.target

[Container]
Image=postgres:18.0

ContainerName=postgresql

PublishPort=5432:5432/tcp

Volume=%h/data/containers/postgresql/data:/var/lib/postgresql:rw
Volume=%h/data/containers/postgresql/config:/config:ro
Volume=%h/data/containers/postgresql/backups:/backups:rw
Volume=%h/data/containers/postgresql/certs:/etc/ssl/postgresql:ro

Environment="TZ=Asia/Seoul"

Exec=postgres -c 'config_file=/config/postgresql.conf'

Label=diun.enable=true
Label=diun.watch_repo=true

[Install]
WantedBy=default.target
```

#### Create systemd `.service` file

```bash
mkdir -p ~/.config/containers/systemd
chmod -R 700 ~/.config/containers/systemd

ln -s ~/data/config/containers/postgresql/postgresql.container ~/.config/containers/systemd/postgresql.container

systemctl --user daemon-reload
```

#### Enable and start service

```bash
# Before start service, setfacl for certificates (before register automation)
setfacl -m m::r /home/dev/data/containers/postgresql/certs/postgresql.ilnmors.internal/*

systemctl --user start postgresql.service
```

### Create user

- Login to psql in the container

```bash
podman exec -it -u postgres postgresql psql -U postgres
> # Create user and database
> CREATE USER $USER WITH PASSWORD '<redacted>';
> CREATE DATABASE $DB;
> ALTER DATABASE $DB OWNER TO $USER;
> \du
> \l

# Whenever you modify the schema including user or database structure, conduct postgresql-cluster-backup.service
systemctl --user start postgresql-cluster-backup.service 


> # If you want to change the password
> ALTER USER $USER WITH PASSWORD '<redacted>';
> # After this, update the .secret.yaml file and podman secret
```

### Backup

#### Backup service

- File:
	- ~/data/config/services/postgresql/postgresql-cluster-backup.service
	- ~/data/config/services/postgresql/postgresql-cluster-backup.timer
	- ~/data/config/services/postgresql/postgresql-data-backup@.service
	- ~/data/config/services/postgresql/postgresql-data-backup@.timer

#### Cluster

```ini
# ~/data/config/services/postgresql/postgresql-cluster-backup.service
# ~/.config/systemd/user/postgresql-cluster-backup.service
[Unit]
Description=PostgreSQL Cluster Backup Service
After=postgresql.service
BindsTo=postgresql.service

[Service]
Type=oneshot

# logging
StandardOutput=journal
StandardError=journal

ExecStartPre=podman exec -u postgres postgresql sh -c "mkdir -p /backups/cluster"

# Run the script
ExecStart=podman exec -u postgres postgresql sh -c "pg_dumpall -U postgres --schema-only | grep -v -E \"ROLE postgres\" > /backups/cluster/postgresql-cluster_$(date "+%%Y-%%m-%%d").sql"

ExecStop=podman exec -u postgres postgresql sh -c "find /backups/cluster -maxdepth 1 -type f -mtime +7 -delete"
```

```ini
# ~/data/config/services/postgresql/postgresql-cluster-backup.timer
# ~/.config/systemd/user/postgresql-cluster-backup.timer
[Unit]
Description=Run PostgreSQL Cluster Backup service every day

[Timer]
# Execute service after 1 min on booting
OnBootSec=1min

# Execute service every day 00:00
OnCalendar=*-*-* 00:00:00
# Random time to postpone the timer
RandomizedDelaySec=15min
Persistent=true

# When timer is activated, Service also starts.
Persistent=true

[Install]
WantedBy=timers.target
```

##### Restore cluster

- File: 
	- ~/data/config/scripts/postgresql/postgresql_init.sh
	- ~/data/containers/postgresql/backups/cluster/postgresql-cluster_$(date "+%Y-%m-%d").sql

- Use `postgresql_init.sh postgresql-cluster_$(date "+%Y-%m-%d").sql` command

#### Data for each app

```ini
# ~/data/config/services/postgresql/postgresql-data-backup@.service
# ~/.config/systemd/user/postgresql-data-backup@.service
[Unit]
Description=PostgreSQL Data %i Backup Service
After=postgresql.service
BindsTo=postgresql.service

[Service]
Type=oneshot

# logging
StandardOutput=journal
StandardError=journal

ExecStartPre=podman exec -u postgres postgresql sh -c "mkdir -p /backups/%i"
# Run the script
ExecStart=podman exec -u postgres postgresql sh -c "pg_dump -U postgres -d %i_db --data-only > /backups/%i/postgresql-%i-data_$(date "+%%Y-%%m-%%d").sql"

ExecStop=podman exec -u postgres postgresql sh -c "find "/backups/%i" -maxdepth 1 -type f -mtime +7 -delete"
```

```ini
# ~/data/config/services/postgresql/postgresql-data-backup@.timer
# ~/data/config/services/postgresql/postgresql-data-backup@.timer
[Unit]
Description=Run %i Data Backup service every day

[Timer]
# Execute service after 1 min on booting
OnBootSec=1min

# Execute service every day 00:00
OnCalendar=*-*-* 00:00:00
# Random time to postpone the timer
RandomizedDelaySec=15min
Persistent=true

# When timer is activated, Service also starts.
Persistent=true

[Install]
WantedBy=timers.target
```

##### Data restore

- File: postgresql-app-data_$(date "+%Y-%m-%d").sql

```bash
# The Schema must be needed. (cluster, DB and user)

# DB owner's session terminate
# server where app is located
systemctl --user stop app.service
# Check session
# dev server
# Print the all session
podman exec -u postgres postgresql psql -U postgres -c "SELECT * from pg_stat_activity;"
> $TARGET_PID
# exit session
podman exec -u postgres postgresql psql -U postgres -c "SELECT pg_terminate_backend($TARGET_PID);"

# Using psql
cat postgresql-app-data_$(date "+%Y-%m-%d").sql | podman exec -i -u postgres postgresql psql -U app
```

#### Register service

```bash
# Register service 
mkdir -p ~/.config/systemd/user && chmod 700 ~/.config/systemd/user

ln -s ~/data/config/services/postgresql/postgresql-cluster-backup.service ~/.config/systemd/user/postgresql-cluster-backup.service

ln -s ~/data/config/services/postgresql/postgresql-cluster-backup.timer ~/.config/systemd/user/postgresql-cluster-backup.timer

ln -s ~/data/config/services/postgresql/postgresql-data-backup\@.service ~/.config/systemd/user/postgresql-data-backup\@.service

ln -s ~/data/config/services/postgresql/postgresql-data-backup\@.timer ~/.config/systemd/user/postgresql-data-backup\@.timer

systemctl --user daemon-reload 

# Start timer and enable
systemctl --user enable --now postgresql-cluster-backup.timer
systemctl --user enable --now postgresql-data-backup@app.timer
```

### Verification

```bash
# Init database
postgresql_init.sh
# ... Start postgresql service

 # Create user and database
podman exec -it -u postgres postgresql psql -U postgres
> CREATE USER test WITH PASSWORD '<redacted>';
> CREATE DATABASE test_db;
> ALTER DATABASE test_db OWNER TO test;
> \du
> \l
> \q

# Backup service executes
systemctl --user start postgresql-cluster-backup.service

# Stop and remove all data
systemctl --stop postgresql
sudo find "/home/dev/data/containers/postgresql/data" -mindepth 1 -delete

# Restore database
postgresql_init.sh ~/data/containers/backups/filename.sql

# Check restoring
podman exec -it -u postgres postgresql psql -U postgres
> \du
> \l
```

