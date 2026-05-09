# kopia

## Create repository

```bash
# export KOPIA_PASSWORD="your_repository_password"
# It exists by Docker environment, however when it is used by pure linux server this environemnt is needed.

# *! CAUTION !*
# THIS PROCESS CONTAINING SECRET VALUES.
# WHEN YOU TYPE THE COMMAND ON SHELL, YOU MUST USE [blank] BEFORE COMMAND
# e.g.
# shell@shell$ command (X)
# shell@shell$ [blank]command (O)
# [blank] prevent the command to save on .bash_history
# After finish this process, use `history -c` and `clear` for just in case.


# Kopia CLI Create repository
mkdir -p /home/console/workspace/kopia_tmp/{repository,config,cache}

/usr/bin/kopia repository create filesystem \
--password="<redacted>" \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--path="/home/console/workspace/kopia_tmp/repository" \
--description="ilnmors.internal kopia repository" \
--create-only

# block hash: BLAKE2B-256-128
# encryption: AES256-GCM-HMAC-SHA256
# key derivation: scrypt-65536-8-1
# splitter: DYNAMIC-4M-BUZHASH

# Kopia CLI Connect repository
/usr/bin/kopia repository connect filesystem \
--password="<redacted>" \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--path="/home/console/workspace/kopia_tmp/repository" \
--override-username="il" \
--override-hostname="nas.ilnmors.internal" \
--description="ilnmors.internal kopia repository"

# Connected to repository

# Start kopia server on pure linux server

# /usr/bin/kopia server start \
# --password="<redacted>" \
# --config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
# --cache-directory="/home/console/workspace/kopia_tmp/cache" \
# --no-ui \
# --address=localhost:51515 \
# --insecure \
# --log-level=info &

# All after these processes reset history.
clear
history -c
```

### Set users

- Container manager: container: kopia-server: Action: Open terminal: Create: bash

```bash
# export KOPIA_PASSWORD="your_repository_password"
# It exists by Docker environment, however when it is used by pure linux server this environemnt is needed.

# Create users
## console@console.ilnmors.internal, infra@infra.ilnmors.internal, app@app.ilnmors.internal
## Repository pasword is not required, because it is already connected
/usr/bin/kopia server users add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user-password="$kopia.user.console" \
console@console.ilnmors.internal

/usr/bin/kopia server users add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user-password="$kopia.user.infra" \
infra@infra.ilnmors.internal

/usr/bin/kopia server users add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user-password="$kopia.user.app" \
app@app.ilnmors.internal

## verify
/usr/bin/kopia server users list \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache"

# ACL
## Console - Run these commands on local container
## snapshot, policy, user, acl, content
/usr/bin/kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="console@console.ilnmors.internal" \
--target="type=snapshot" \
--access=FULL

/usr/bin/kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="console@console.ilnmors.internal" \
--target="type=policy" \
--access=FULL

/usr/bin/kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="console@console.ilnmors.internal" \
--target="type=user" \
--access=FULL

/usr/bin/kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="console@console.ilnmors.internal" \
--target="type=acl" \
--access=FULL

/usr/bin/kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="console@console.ilnmors.internal" \
--target="type=content" \
--access=FULL

## app and infra - Run these command on console
### Global pull to remove duplicates
/usr/bin/kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="infra@infra.ilnmors.internal" \
--target="type=content" \
--access=APPEND

/usr/bin/kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="app@app.ilnmors.internal" \
--target="type=content" \
--access=APPEND

### Snapshot
/usr/bin/kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="infra@infra.ilnmors.internal" \
--target=type=snapshot,username=infra,hostname=infra.ilnmors.internal \
--access=FULL

/usr/bin/kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="app@app.ilnmors.internal" \
--target=type=snapshot,username=app,hostname=app.ilnmors.internal \
--access=FULL

### Policy
kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="infra@infra.ilnmors.internal" \
--target="type=policy" \
--access=READ

kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="infra@infra.ilnmors.internal" \
--target="type=policy,username=infra,hostname=infra.ilnmors.internal" \
--access=FULL

kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="app@app.ilnmors.internal" \
--target="type=policy" \
--access=READ

kopia server acl add \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--user="app@app.ilnmors.internal" \
--target="type=policy,username=app,hostname=app.ilnmors.internal" \
--access=FULL
```

### Set policy

- Container manager: container: kopia-server: Action: Open terminal: Create: bash

```bash
# compression
/usr/bin/kopia policy set \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--global \
--compression=zstd

# infra for db dump sql
kopia policy set infra@infra.ilnmors.internal \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--compression=zstd \
--keep-latest=10 \
--keep-hourly=0 \
--keep-daily=14 \
--keep-weekly=4 \
--keep-monthly=6 \
--keep-annual=1

# app for media, stateful data
kopia policy set app@app.ilnmors.internal \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
--compression=none \
--keep-latest=10 \
--keep-hourly=0 \
--keep-daily=14 \
--keep-weekly=4 \
--keep-monthly=6 \
--keep-annual=1

# verify
kopia server acl list \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \

kopia policy list \
--config-file="/home/console/workspace/kopia_tmp/config/repository.config" \
--cache-directory="/home/console/workspace/kopia_tmp/cache" \
```

## Remove repository from Console

```bash
# After uploading repository to DSM
rm -rf /home/console/workspace/kopia_tmp
history -c 
```
