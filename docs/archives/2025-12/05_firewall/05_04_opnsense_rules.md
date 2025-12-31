Tags: #os, #firewall, #configuration, #network, #security 

## OPNsense rules

### NAT

- Firewall:NAT:Outbound
    - Mode: Automatic outbound NAT rule generation (no manual rules can be used)
- Firewall:NAT:Port Forward - \[+\]

| Interface | TCP/IP version | Proto | Destination | Destination port | Redirect target IP | Redirect target port |                    Description                    |
| :-------: | :------------: | :---: | :---------: | :--------------: | :----------------: | :------------------: | :-----------------------------------------------: |
|    WAN    |      IPv4      |  TCP  | WAN address |    ports_web     |     hosts_auth     |      ports_web       | allow wan clients to access web services from WAN |

> Set after building main reverse proxy, all web packets from WAN are going to the reverse proxy.

> Filter rule association's `Add associated filter rule` option will automatically generate the `Pass` rule on WAN interface for Port Forwarding rule.

### Firewall rules

OPNsense has prioirty in order to rule's squence. The upper rule is prior than below one. Moreover, when `Quick` option is enabled, OPNsense doesn't check the rule below. It means OPNsense just applies the rule what it is first matched (First match). Reversely, when `Quick` option is disabled, OPNsense checks all rules to apply the packet (Last match).

#### WAN interface

- Firewall:Rules:WAN - \[+\]

| Action | Quick | Interface | Direction | TCP/IP version | Proto | Source | Destination | Destination port |                                Description                                 |
| :----: | :---: | :-------: | :-------: | :------------: | :---: | :----: | :---------: | :--------------: | :------------------------------------------------------------------------: |
|  Pass  |   *   |    WAN    |    IN     |      IPv4      |  UDP  |   *    | WAN address |    ports_vpn     |                         allow vpn clients from WAN                         |
|  Pass  |   *   |    WAN    |    IN     |      IPv4      |  TCP  |   *    | WAN address |    ports_web     | allow wan clients to access web services from WAN(Automatically generated) |

- `Apply changes`

#### SERVER interface

- Firewall:Rules:SERVER - \[+\]

| Action | Quick | Interface | Direction | TCP/IP version | Proto |    Srouce     |  Destination  | Destination port |                              Description                               |
| :----: | :---: | :-------: | :-------: | :------------: | :---: | :-----------: | :-----------: | :--------------: | :--------------------------------------------------------------------: |
|  Pass  |   *   |  SERVER   |    IN     |      IPv4      |  UDP  |       *       |       *       |   ports_dhcpv4   |      allow server clients to access DHCPv4 server from SERVER net      |
|  Pass  |   *   |  SERVER   |    IN     |      IPv4      | ICMP  |  SERVER net   | This Firewall |        -         | allow server clients to access This Firewall with ICMP from SERVER net |
| Block  |   *   |  SERVER   |    IN     |      IPv4      |   *   | !hosts_server |       *       |        *         |    block undesignated server clients to access any from SERVER net     |
|  Pass  |   *   |  SERVER   |    IN     |      IPv4      |  UDP  |  SERVER net   | This Firewall |       NTP        |           allow server clients to access NTP from SERVER net           |
|  Pass  |   *   |  SERVER   |    IN     |      IPv4      |  TCP  |  SERVER net   | This Firewall |  ports_crowdsec  |      allow server clients to access CrowdSec LAPI from SERVER net      |
|  Pass  |   *   |  SERVER   |    IN     |      IPv4      |  TCP  | hosts_console | This Firewall |    ports_web     |     allow console to access This Firewall web GUI from SERVER net      |
|  Pass  |   *   |  SERVER   |    IN     |      IPv4      |   *   | hosts_console |   USER net    |        *         |            allow console to access USER net from SERVER net            |
| Block  |   *   |  SERVER   |    IN     |      IPv4      |  TCP  |  SERVER net   | This Firewall |        *         |      block server clients to access This Firewall from SERVER net      |
| Block  |   *   |  SERVER   |    IN     |      IPv4      |   *   |  SERVER net   |   USER net    |        *         |        block server clients to access USER net from SERVER net         |
|  Pass  |   -   |  SERVER   |    IN     |      IPv4      |   *   |  SERVER net   |       *       |        *         |           allow server clients to access WAN from SERVER net           |

- `Apply changes`

> When you add the new server client, you must edit alias `hosts_server`

#### USER interface

- Firewall:Rules:USER - \[+\]

| Action | Quick | Interface | Direction | TCP/IP version |  Proto  |    Srouce     |  Destination  | Destination port |                            Description                             |
| :----: | :---: | :-------: | :-------: | :------------: | :-----: | :-----------: | :-----------: | :--------------: | :----------------------------------------------------------------: |
|  Pass  |   *   |   USER    |    IN     |      IPv4      |   UDP   |       *       |       *       |   ports_dhcpv4   |      allow user clients to access DHCPv4 server from USER net      |
|  Pass  |   *   |   USER    |    IN     |      IPv4      |  ICMP   |   USER net    | This Firewall |        -         | allow user clients to access This Firewall with ICMP from USER net |
|  Pass  |   *   |   USER    |    IN     |      IPv4      | TCP/UDP |   USER net    |   hosts_net   |    ports_dns     |       allow user clients to access DNS server from USER net        |
|  Pass  |   *   |   USER    |    IN     |      IPv4      |   TCP   |   USER net    |  hosts_auth   |    ports_web     |      allow user clients to access reverse proxy from USER net      |
|  Pass  |   *   |   USER    |    IN     |      IPv4      |   TCP   | hosts_console | This Firewall |    ports_web     |    allow console to access This Firewall web GUI from USER net     |
|  Pass  |   *   |   USER    |    IN     |      IPv4      |    *    | hosts_console |  SERVER net   |        *         |          allow console to access SERVER net from USER net          |
| Block  |   *   |   USER    |    IN     |      IPv4      |    *    |   USER net    | This Firewall |        *         |      block user clients to access This Firewall from USER net      |
| Block  |   *   |   USER    |    IN     |      IPv4      |    *    |   USER net    |  SERVER net   |        *         |       block user clients to access SERVER net from USER net        |
|  Pass  |   -   |   USER    |    IN     |      IPv4      |    *    |   USER net    |       *       |        *         |           allow user clients to access WAN from USER net           |

- `Apply changes`

#### LAN interface

OPNsense automatically generates all pass rules on LAN interface. The USER group will be used instead of LAN interface, all rules will be disabled after USER interface rules set.

- Firewall:Rules:LAN
    - Disable all auto generated rules
- `Apply changes`