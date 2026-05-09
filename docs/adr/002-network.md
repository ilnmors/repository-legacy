# ADR 002 - Network

## Date

- Feb/23/2026
    - First documentation


## Status

- Accepted

## Context

- All L3 communications should be contolled by central firewall node.
- Every firewall rule should be managed by code, not clicks.
- Every edge node takes charge of L2 communication rules.
- IPv4 and IPv6 dual stack should be supported for future network environment.

## Consideration

### Firewall

- OPNSense/pfSense
    - vendor lock-in
    - GUI environment (WebGUI) can contain vulnerability
    - It is hard to manage configurations by IaC
- iptables
    - Previous standard of Linux
    - IPv4 and IPv6 configuration is separated (no inet)
- nftables
    - New standard of Linux
    - English grammar friendly
    - IPv4 and IPv6 configuration can be set on the same table (inet)

### Flat network structure
- LAN only
    - L2 communication doesn't need to pass through gateway
    - They use MAC address with ARP. Unicast communication is hard to manage.
    - It is hard to manage and apply the policy centrally

## Decisions

- Categorize all nodes in 4 roles 'client', 'server', 'user', 'wg0; vpn connections'
- Implement role separation with VLAN tagging on L2 switch (systemd-networkd bridge)
    - VLAN 1: client (vmm, console, nas)
    - VLAN 10: server (vmm, infra, auth, app)
    - VLAN 20: user (DHCP allocated devices)
    - wg0: VPN connections
- Manage the rules based on roles fundamentally, furthermore manage them based on ip and ports when it is needed
- All L3 communication which needs to pass gateway should be on control of firewall (fw)
- All nodes including firewall uses nftables (modern standard) to manage the packets based on zone concept
- IPv6 has two track strategy
    - Client and server, wg nodes has static ULA IP, and use NAT66 for permanency
    - User nodes has GUA SLAAC IP from ISP for compatibility


## Consequences

- Firewall takes charge of L3 communications
- Each nodes takes charge of L2 communications and communication from FW
- All nodes can communicate under both IPv4 and IPv6
- All policies can be managed by Code
