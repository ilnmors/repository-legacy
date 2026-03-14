# ADR 009 - isolation

## Date

- Mar/06/2026
    - First documentation

## Status

- Accepted

## Context

- Distinguish borderline for service unit including hypervisor, vm, container

## Considerations

### Hypervisor

- As a pure hypervisor, it should only operate virtualization for VM.
- Hypervisor just provides resources and dummy hub \(br\)

### VM

- VM should be distinguished based on their logical role.
    - Firewall is responsible for networking
    - Infra is responsible for infrastructure services such as DB, Monitoring, CA server
    - Auth is responsible for authentication and authorization for services
    - App is responsible for applications

### Services

- Services should be distinguished based on their needs \(Privilege\)
    - Network stack, backup stack needs special privilege for low level ACL or networks.
    - application stack doesn't need low level privilege usually

## Decisions

- Hypervisor: Only supply pure virtualization for VM
- VM: isolated by hypervisor from the other vms based on their role
- Services:
    - the one which needs previlieges: Run as native on vm. Don't make overhead for virtualization.
    - the one which doesn't need previlieges: Isolate as container from host.

## Consequences

- Guarantee scurity integrity
- Simple operational rules
- Optimize the limited resources