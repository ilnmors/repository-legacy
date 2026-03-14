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

# Restor database (manually)
podman exec -u postgres postgresql "psql -U postgres -f $POSTGRESQL_BACKUP_PATH_IN_CONTAINER/script.sql"

# Backup service executes
systemctl --user start postgresql-cluster-backup.service

# Stop and remove all data
systemctl --stop postgresql
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
