# Grafana

## Operation
Refer to Ansible playbook
(Postgresql user and DB is needed)
(LDAP strict readonly account is needed)

## Verification
- Check Caddyfile (without caddy, use 3000 ports)
- https://grafana.ilnmors.internal
- login with LDAP user
    - connection:data sources: `[prometheus|loki]`: provisioned
        - https://prometheus.ilnmors.internal:9090
        - https://loki.ilnmors.internal:3100

    - check drill down:metrics

## Dashboard

- Dashboard isn't saved on local directory. They are saved on DB (Postgresql).