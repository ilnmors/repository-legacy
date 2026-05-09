# Postgresql

## Operation
Refer to Ansible playbook

## File management
```bash
# console
## cluster
scp infra@infra:$POSTGRESQL_BACKUP_PATH/pg_cluster.sql $HOMELAB_PATH/data/backups/infra/postgresql/pg_cluster.sql
## data
scp infra@infra:$POSTGRESQL_BACKUP_PATH/pg_backup.sql $HOMELAB_PATH/data/backups/infra/postgresql/pg_backup.sql

## The data is managed by kopia.
```

## Verification

```bash
# ... Start postgresql service

# Create user and database
podman exec -it -u postgres postgresql "psql -U postgres"
> CREATE USER service WITH PASSWORD '<redacted>';
> CREATE DATABASE service_db;
> ALTER DATABASE service_db OWNER TO service;
> \du
> \l
> \q

# Reset database
> SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = 'service_db'; # connection reset
> DROP DATABASE service_db;
> CREATE DATABASE service_db;
> ALTER DATABASE service_db OWNER TO service;
> \du
> \l
> \q

# Restore database (manually)
podman exec -u postgres postgresql "psql -U postgres -f $POSTGRESQL_BACKUP_PATH_IN_CONTAINER/script.sql"

# Backup service executes
systemctl --user start postgresql-cluster-backup.service

# Stop and remove all data
systemctl --user stop postgresql
sudo find "/home/infra/data/containers/postgresql/data" -mindepth 1 -delete

# Restore database
# Just locate sql files on data_path, and use playbooks

# Check restoring
podman exec -it -u postgres postgresql psql -U postgres
> \du
> \l

# Check extension
postgres=# SHOW shared_preload_libraries;
 shared_preload_libraries
--------------------------
 vchord.so
(1 row)
```

## Update and upgrade version

### Update version

#### Prerequisite

- Shutdown all related services on [infra, auth, app] vms.
    - [service list](../../../ansible/roles/infra/tasks/services/set_postgresql.yaml)
    - `systemctl --user stop $SERVICE`

- Run backup service unit on infra vm.
    - `systemctl --user start postgresql-cluster-backup.service`
    - `systemctl --user start postgresql-data-backup@$SERVICE.service`

- Modify postgresql and extension version and run ansible playbook
    - [version info](../../../ansible/inventory/group_vars/all.yaml)
    - `ansible-playbook playbooks/infra/site.yaml --tags "postgresql"`

- Check postgresql container and update extension

```postgresql
# immich example
# extension should be checked on each database which needs the extension
\c immich_db
\dx
# check the installed_version and default_version
ALTER EXTENSION vchord UPDATE;
REINDEX INDEX face_index;
REINDEX INDEX clip_index;
```

- Run playbook to start all services
    - `ansible-playbook playbooks/[infra, auth, app]/site.yaml --tags "site"`

- Check all services
