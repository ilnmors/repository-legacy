# ADR 010 - provisioning

## Date

- Mar/06/2026
    - First documentation
    
## Status

- Accepted

## Context

- Every sensitive process should be controlled and managed.

## Considerations

### Automate destroying process

- Destroying is not frequent process, there's no reason to make complex logic
- Sensitive process should be double checked by human manually

## Decisions

- Make provisioning process as auto
- Make sensitive process as manual
    - Removing
    - Formatting
    - Destroying
    - Certificates and CA ([ADR-003](./003-pki.md))
    - Etc. what operator decides that is sensitive

## Consequences

- All process can be under control of the operator
