# ADR 012 - Alerting

## Date

- Mar/08/2026
    - First documentation
    
## Status

- Accepted

## Context

- The necessity of observability
- Difficulty of realizing present status of services
- Stable restoring process already exists

## Considerations

### Mail based

- MTA is hard to manage even when operator uses this as relay host
- The mail protocol is complex to implement only for internal mail system for single operator

### Chat based

- Using discord, telegram is easy to get announcment automatically
- The dependency of external services

## Decisions

- Do not operate alerting system
    - Single node system for small group doesn't need HA
    - When single node system is down, the alerting system is also down.
- When the alert system is needed, implement the system on free instance of external IaaS like AWS or Azure

## Consequences

- Simple management and stable restoring
    - Check service availability
    - Check from grafana
    - Access to node via vpn with ssh
    - Access to node via physical VLAN
    - Reprovisioning the node
- The additional possibility of extension with Cloud services.
