# ADR 005 - IDS/IPS

## Date

- Feb/23/2026
    - First documentation


## Status

- Accepted

## Context

- Automized detection and prevention threats via network

## considerations

### IPS
- Operate suricata as IDS and IPS
    - Suricata IPS mode blocks packets by itself, bypassing nftables integration
    - Suricata IPS mode overhead is very higher than IDS mode.
    - Suricata IPS mode cannot detect and prevent TLS based communication.
    - Homelab server resources are not enough to deal with high overhead.

- fail2ban
    - Single node only, no centralized decision sharing
    - No community-based threat intelligence (CAPI)
    - Regex based log parsing is less structured than CrowdSec's parser/scenario model

- Crowdsec
    - Community based rules and sinario \(CAPI\)
    - Prevention based on local machines and parsers \(LAPI\)
    - Bouncers can use nftables to prevent threats
    - Parser can detect even L7 attack under TLS

## Decisions

- Operate suricata as IDS
    - suricata IDS mode mirror all packets from interfaces
    - match the packets based on its rules and writes log as fast.log, and eve.json

- Operate Crowdsec as IPS
    - CrowdSec uses two API server, CAPI, LAPI.
        - CAPI updates malicious IPs based on community decisions
        - LAPI decides malicious attack based on log from its parser and scenario \(Suricata, caddy, etc\)
        - When CAPI, and LAPI decides block some IP based on log parsed by parser and scenarios, bouncer block the malicious accesses.
    - Crowdsec register blacklist on nftables or iptables.


## Consequences

- All malicious attack from WAN, even from LAN is controlled by CrowdSec and Suricata
- The firewall maintains high network throughput because blocking is performed efficiently at the OS network level (`nftables` sets) rather than through deep inline packet inspection.
