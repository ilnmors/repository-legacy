Tags: #os, #firewall, #configuration, #network 

## Interface configuration

### VLAN setting

- Interfaces:Devices:VLAN - \[+\]

|   Device   | Parent | Tag | Description |
| :--------: | :----: | :-: | :---------: |
| vlan0.1.10 | vtnet1 | 10  |   Server    |

> The device name is reserved in Web UI; Name of VLAN device must start with `vlan0` or `qinq0`. In this project, name of vlan device would be `vlan0.[interface_num].[tag_num]`

- `Apply`

### VPN setting

- VPN:WireGuard
    - \[\*\] Enable WireGuard
- VPN:WireGuard:Instance - \[+\]

|   Name    | Listen Port | Tunnel Address |
| :-------: | :---------: | :------------: |
| WG_SERVER |    11290    | 10.10.10.1/24  |
|  WG_USER  |    11291    |  10.10.1.1/24  |

- VPN:WireGuard:PeerGenerate

| Instance  |     End point     |  Name   |    Address    | Pre-shared Key |   Allowed IP   | Keepalive interval |      DNS      |
| :-------: | :---------------: | :-----: | :-----------: | :------------: | :------------: | :----------------: | :-----------: |
| WG_SERVER | ilnmors.com:11290 | console | 10.10.10.2/32 |    Generate    | 192.168.0.0/16 |         25         | 192.168.10.11 |
| WG_SERVER | ilnmors.com:11290 |  phone  | 10.10.10.3/32 |    Generate    | 192.168.0.0/16 |         25         | 192.168.10.11 |
| WG_SERVER | ilnmors.com:11290 |  spare  | 10.10.10.4/32 |    Generate    | 192.168.0.0/16 |         25         | 192.168.10.11 |

> Set `PersistentKeepalive = 25` on peer, to avoid NAT timeout.

> Press `Store and generate next` button after generate each row.

> Before building net server (Private DNS), use 1.1.1.2 instead of 192.168.10.11.


```ini
# console
[Interface]
PrivateKey = <redacted>
Address = 10.10.10.2/32
DNS = 192.168.10.11

[Peer]
PublicKey = jqDJKe8pZSK8GXwBnrjBJiflYvJDB7GfgogLsSSdnA4=
PresharedKey = <redacted>
Endpoint = ilnmors.com:11290
AllowedIPs = 192.168.0.0/16
PersistentKeepalive = 25

# phone
[Interface]
PrivateKey = <redacted>
Address = 10.10.10.3/32
DNS = 192.168.10.11

[Peer]
PublicKey = jqDJKe8pZSK8GXwBnrjBJiflYvJDB7GfgogLsSSdnA4=
PresharedKey = <redacted>
Endpoint = ilnmors.com:11290
AllowedIPs = 192.168.0.0/16
PersistentKeepalive = 25

# spare
[Interface]
PrivateKey = <redacted>
Address = 10.10.10.4/32
DNS = 192.168.10.11

[Peer]
PublicKey = jqDJKe8pZSK8GXwBnrjBJiflYvJDB7GfgogLsSSdnA4=
PresharedKey = <redacted>
Endpoint = ilnmors.com:11290
AllowedIPs = 192.168.0.0/16
PersistentKeepalive = 25
```

- `Apply`

### Interface assignment

- Interface:Assignments
    - vlan0.1.10 - VLAN10 - `Add`
    - wg0 - WG_SERVER - `Add`
    - wg1 - WG_USER - `Add`
- `Save`

### Assigned interface setting

- Interface:WAN
    - \[\*\] Enable
    - \[\*\] Block private
    - \[\*\] Block bogon
    - \[\*\] IPv4 DHCP
- `Save`
- Interface:LAN
    - \[\*\] Enable
    - IPv4 Static (IPv6 Configuration Type: None)
    - 192.168.1.1/24
- `Save`
- Interface:VLAN10
    - \[\*\] Enable
    - IPv4 Static
    - 192.168.10.1/24
- Interface:WG_SERVER
    - \[\*\] Enable
- `Save`
- Interface:WG_USER
    - \[\*\] Enable
- `Save`
- `Apply change`

### Web UI itself settings

- System:Settings:Administration
    - Web GUI
    - Listen Interfaces: LAN, VLAN10
- `Save`
- Firewall:Settings:Advanced
    - \[\*\] Disable anti-lockout
- `Save`

## Aliases and group configuration

### Aliases setting

- Firewall:Aliases - \[+\]

|      Name      |  Type   |                                                Content                                                 |           Description           |
| :------------: | :-----: | :----------------------------------------------------------------------------------------------------: | :-----------------------------: |
|   ports_vpn    | port(s) |                                              11290,11291                                               |          ports udp vpn          |
|   ports_web    | port(s) |                                                 80,443                                                 |          ports tcp web          |
|  ports_dhcp4   | port(s) |                                                 67,68                                                  |         ports udp dhcp4         |
|   ports_dns    | port(s) |                                                 53,443                                                 | ports tcp/udp dns including DoH |
| ports_crowdsec | port(s) |                                                  8080                                                  |       ports tcp crowdsec        |
| hosts_console  | host(s) |                             192.168.1.11,10.10.10.2,10.10.10.3,10.10.10.4                              |          hosts console          |
|  hosts_server  | host(s) | 192.168.10.10,192.168.10.11,192.168.10.12,192.168.10.13,192.168.10.14,10.10.10.2,10.10.10.3,10.10.10.4 |          hosts servers          |
|   hosts_net    | host(s) |                                             192.168.10.11                                              |            hosts net            |
|   hosts_auth   | host(s) |                                             192.168.10.12                                              |           hosts auth            |


- `Apply`

### Group setting

- Firewall:Groups - \[+\]

|  Name  |      Members      | Description  |
| :----: | :---------------: | :----------: |
| SERVER | VLAN10, WG_SERVER | Server group |
|  USER  |   LAN, WG_USER    |  User group  |

- `Apply`