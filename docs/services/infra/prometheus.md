# Prometheus

## Operation
Refer to Ansible playbook
## Verification
- Check Caddyfile \(without caddy, use 9090 ports\)
- https://prometheus.ilnmors.internal
- Status:Target Health
    - Check `Endpoint localhost:9090 ` with green circle
- Status:command-line flag
    - Check `--web.enable-remote-write-receiver: true`

