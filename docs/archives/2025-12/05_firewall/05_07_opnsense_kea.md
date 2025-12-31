Tags: #os, #firewall, #configuration, #network 

## Kea DHCP in OPNsense

Kea DHCP is the next generation DHCP server of ISC(Internet Systems Consortium) to supersede ISC DHCP. Kea has more flexibility in configuration, and higher performance, and modern API than ISC DHCP. OPNsense also select Kea as the future DHCP server than ISC DHCP. Basically, Kea supports container(Docker or podman) but it doesn't use docker.io repository but cloudsmith.io repository. Moreover, Kea DHCP is separated into 3 module kea ddns, kea dhcp 4, kea dhcp 6 as containers. This fact makes network environment (especially when the rootless podman network and DHCP relay are considered.) complex. Therefore, even though Kea in OPNsense doesn't support DDNS module, in this home lab Kea DHCP will be located in OPNsense.

### Kea DHCP setting

- Services:Kea DHCP:Kea DHCPv4 - Settings
    - \[\*\] Enabled
    - Interfaces: LAN, VLAN10
    - \[ \] Firewall rules (Manually created)
- Services:Kea DHCP:Kea DHCPv4 - Subnets - \[+\]
    - \[ \] Match client-id (To match based on MAC)
    - \[ \] Auto collect option data (To designate optional data manually)

|     Subnet      | Description |             Pool              | Routers(gateway) |      DNS      |   Domain name    |
| :-------------: | :---------: | :---------------------------: | :--------------: | :-----------: | :--------------: |
| 192.168.1.0/24  |     LAN     |  192.168.1.100-192.168.1.254  |   192.168.1.1    | 192.168.10.11 | ilnmors.internal |
| 192.168.10.0/24 |   VLAN10    | 192.168.10.254-192.168.10.254 |   192.168.10.1   | 192.168.10.11 | ilnmors.internal |

> Before building net server (Private DNS), use 1.1.1.2 instead of 192.168.10.11.

> The reason why VLAN10's pool has only 192.168.1.254 is VLAN10 allows only reservation IP.

- Services:Kea DHCP:KeaDHCPv4 - Reservation
    - Delete all rows.
    - Import csv file: kea_dhcp_v4_reservation.csv

```csv
ip_address,hw_address,hostname,description,option_data,
192.168.1.11,D8:E2:DF:FF:1B:D5,surface,console eth,
192.168.1.30,38:CA:84:94:5E:06,printer,printer,
192.168.10.12,0A:49:6E:4D:02:00,auth,auth,
192.168.10.13,0A:49:6E:4D:03:00,dev,dev,
192.168.10.14,0A:49:6E:4D:04:00,app,app,
```
- `Apply`

> vmm(Hypervisor), opnsense(firewall), net(Net server which has DNS in it) should use static IP instead of DHCP reservation. Because these servers are fundamental servers for building network and DHCP. It is very stable for DNS, hypervisor, firewall themselves to use static IP.