# Alloy

## Communication

Alloy runs on systemd (host), and postgresql runs as container (rootless podman). When host system and container communicate, container recognizes host system as host-gateway (Link local address).

## postgresql monitor
 
### Monitor exporter 

```sql
postgres=# CREATE USER alloy WITH PASSWORD '<redacted>';
CREATE ROLE
postgres=# GRANT pg_monitor TO alloy;
GRANT ROLE
postgres=# \drg
               List of role grants
 Role name | Member of  |   Options    | Grantor
-----------+------------+--------------+----------
 alloy  | pg_monitor | INHERIT, SET | postgres
(1 row)
```
### pg_hba.conf
```conf
hostssl postgres   alloy {{ hostvars['fw']['network4']['infra']['server'] }}/32    trust
hostssl postgres   alloy {{ hostvars['fw']['network6']['infra']['server'] }}/128    trust
hostssl postgres   alloy {{ hostvars['fw']['network4']['subnet']['lla'] }}    trust
hostssl postgres   alloy {{ hostvars['fw']['network6']['subnet']['lla'] }}    trust
```

### check

```bash
curl http://localhost:12345/metrics
```
