# ADR 001 - Architecture

## Date

- Feb/23/2026
    - First documentation
- Mar/4/2026
    - Refining sentences

## Status

- Accepted

## Context

- Maintaining multi nodes requires a huge amount of resources, including hardware, electricity, even administrative efforts
- All units which responsible for a single role should follow the Principle of Least Privilege (PoLP).
- All units should be interchangeable on standard to avoid vendor lock-in.

## Consideration

### Hypervisor

- Proxmox Virutal Environment (PVE)
    - Based on Debian.
    - PVE uses `qm` command which is not a standard to implement the virtual environment.
- VMware ESXi
    - Based on UNIX, deveoped by VMware (Licence is not free)
- Hyper-V
    - Based on Microsoft Windows (Licence is not free)
- Debian Stable
    - Based on standard linux (conservative)
    - Standard virtualization technology 'Libvirt, QEMU, KVM'

### Container

- Docker
    - Daemon is used to run containers
    - Root authority required
    - Socket and network problem is complex (Docker bridge)
    - docker-compose is an orchestration tool
- Rootless Podman
    - Daemonless design
    - Root authority not required
    - Orchestration is integrated into systemd
    - PASTA dumps packet via host-gateway
- K8S, K3S
    - HA is based on reprovisioning
    - Guarantee availability to create and destroy node dynamically

### IaC

- Terraform
    - Strength for initiating low-level and dynamic multi node environment
- Ansible
    - Declaritive and easy yaml grammar
    - SSH is the way to set

## Decisions

- Use Libvirt/KVM/QEMU on pure linux (Debian stable).
- Separate all services by VM, and podman rootless containers without K3S.
    - Orchestration stack is not needed in single node system
    - Services will be defined by Quadelt to integrate into systemd and to manage them declaratively
    - IaC will be implemented by Ansible only declaratively
- All VMs and services are isolated logically by VLAN and nftables

## Consequences

- All VMs have independent borderline by VLAN and nftables
- All services have independent namespaces by podman subuid without daemon
- Ansible can manage all configurations of services and VMs declaratively
