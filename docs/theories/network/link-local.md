# Link-local address

link-local address is for reserved subnets for L2 communication. 

## IPv4

### APIPA

When the client couldn't get IP address from DHCP, OS automatically allocate IP address subnet 169.254.0.0/16. This address can never pass L3 point \(router\). It is usually used for internal communication in cloud environment, or PASTA network in containers.

### RFC1918

These are originally IP addresses subnet 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16 which can communicate beyond L3 point \(Router\). However, it is reserved for LAN \(Local Area Network\) because of the lack of the number of IPv4 address. They can communicate to the other subnets but they cannot be used on WAN environment, which means ISP cannot allocate these IP subnet to their client.

## IPv6

Link-local address is very important in IPv6 unlike IPv4. Basically, every edge node must have GUA in IPv6 protocol, and a node can have number of IPv6 addresses on an interface. So, they communicate with auto-generated linklocal address fe80::/10 in L2 area, and they communicate with ULA or GUA in L3 Area.

## Linklocal in PASTA

### IPv4
- 127.0.0.1: container itself
- 169.254.0.0/16: container and host communication \(linklocal\)
- RFC1918 for private LAN
- WAN
### IPv6
- \[::1\]: container itself
- \[fe80::\]: container and host communication \(linklocal\)
- \[fd00::\]: (ULA) for private LAN
- [ Global IPv6 ]
