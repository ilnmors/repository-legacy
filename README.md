# ilnmors homelab README

This homelab project implements single-node On-premise IaaS system. The homelab contains virtual machines which are divided by their roles, such as private firewall, DNS, PKI, LDAP and database, SSO(OIDC). The standard domain is used to implement this system without specific vendors. All components are defined as code and initiated by IaC (Ansible) except hypervisor initial configuration.

## RTO and RPO

### RPO
- Each backup guarantees 24 hours RPO
    - DB dumps are backed up at 12:00 AM
    - Stateful data in app vm is backed up at 03:00 AM
- The maximum inconsistency window between DB dumps and stateful data can be 27 hours.
    - The different backup time.

### RTO
- Feb/25/2026 - Reprovisioning Hypervisor and vms
    - RTO: 1 hour 30 min - verified
        - Manual install and set vmm: 20 min
        - Create and reprovision fw including services: 15 min
        - Create and reprovision infra including services: 20 min
        - Create and reprovision auth including services: 10 min
        - Create and reprovision app except services: 10 min
        - Intermediate tasks (ACME issuance, DNS propagation, etc.): 15 min

- Mar/5/2026 - Reprovisioning Hardware and Hypervisor and vms
    - RTO: 2 hour 20 min
        - console: 15min - verified
        - certificate: 0 min (When it needs to be created, RTO will be 20 min) - not verified
        - wireguard: 0 min (When it needs to be created, RTO will be 1 min) - not verified
        - hypervisor(+fw): 45 min - verified
        - switch: 1 min - verified
        - dsm: 30 min - verified
        - kopia: 0 min (When it needs to be created, RTO will be 10 min) - verified
        - Extra vms: 30 min - verified
        - Etc: 30 min

