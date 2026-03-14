# Matrix

## UID/GID Matrix

### Table

|name|uid|gid|comments|
|:-:|:-:|:-:|:-:|
|svadmins|-|2000|server group|
|vmm|2000|2000|hypervisor|
|fw|2001|2000|firewall|
|infra|2002|2000|infrastructure|
|auth|2003|2000|authentication and authorization|
|app|2004|2000|services|
|console|2999|2000|console node\(surface\)|

### subuid and subgid

- user:100000:65536

## Switch ports matrix

### 8 Ports main switch

|port number|node|subnet|id|
|:-:|:-:|:-:|:-:|
|1|WTR Pro N150|Trunk|-|
|2|AP\(Preparation\)|USER|20|
|3|DS124\(NAS\)|CLIENT|1|
|4|Console|CLIENT|1|
|5|Printer|CLIENT|1|
|6|-|-|-|
|7|-|-|-|
|8|-|-|-|

## IP matrix

### Subnet

|name|IPv4|IPv6|id|
|:-:|:-:|:-:|:-:|
|CLIENT|192.168.1.0/24|fd00:1::/64\(ULA\)|1|
|SERVER|192.168.10.0/24|fd00:10::/64\(ULA\)|10|
|USER|192.168.20.0/24|GUA from ISP|20|
|WG0|192.168.99.0/24|fd00:99::/64\(ULA\)|-|

### Host

####  console:
- CLIENT
    - 192.168.1.20
    - fd00:1::20
- WG0
    - 192.168.99.20
    - fd00:99::20

#### fw
- CLIENT
    - 192.168.1.1
    - fd00:1::1
- SERVER
    - 192.168.10.1
    - fd00:10::1
- USER
    - 192.168.20.1
    - GUA SLAAC
- WG0
    - 192.168.99.1
    - fd00:99::1

#### blocky \(fw\)
- SERVER
    - 192.168.10.2
    - fd00:10::2

#### bind \(fw\)
- SERVER
    - 192.168.10.3
    - fd00:10::3

#### vmm
- CLIENT
    - 192.168.1.10
    - fd00:1::10
- SERVER
    - 192.168.10.10
    - fd00:10::10

#### infra
- SERVER
    - 192.168.10.11
    - fd00:10::11

#### auth
- SERVER
    - 192.168.10.12
    - fd00:10::12

#### app
- SERVER
    - 192.168.10.13
    - fd00:10::13

#### VLAN switch
- CLIENT
    - 192.168.1.2
    - fd00:1::2

#### ds124
- CLIENT
    - 192.168.1.11
    - fd00:1::11

#### Printer
- CLIENT
    - 192.168.1.101
    - fd00:1::101
