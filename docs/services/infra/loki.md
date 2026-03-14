# loki

## Operation
Refer to Ansible playbook
## Verification
- fw@fw:/var/lib/bind$ curl -k https://loki.ilnmors.internal:3100/ready \(Node which is in NET_SERVER except infra itself\)
    - ready
- fw@fw:/var/lib/bind$ curl -k https://loki.ilnmors.internal:3100/metrics
    - metrics lists
- fw@fw:/var/lib/bind$ curl -k https://loki.ilnmors.internal:3100/loki/api/v1/labels
    - no org id
    - JSON format labels when alloy is set
