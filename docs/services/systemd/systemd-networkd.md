# systemd-networkd

- Use `networkctl` and the files in `/etc/systemd/network`
- link file
    Link file links hardware interface and kernel while booting
- netdev file
    netdev file defines virtual interface \(port, bridge\)
- network file
    network file defines network option above interfaces

## commands

- reload
  - networkctl reload
  - networkctl reconfigure \[interface name\]

## references

- https://manpages.debian.org/testing/systemd/systemd/networkctl.1.en.html
- https://manpages.debian.org/testing/systemd/systemd.link.5.en.html
- https://manpages.debian.org/testing/systemd/systemd.network.5.en.html
- https://manpages.debian.org/testing/systemd/systemd.netdev.5.en.html

## Plans

- Hypervisor's linux bridges work as L2 switch
  - br0 is completely L2 switch \(LinkLocalAddressing=no\)
  - br1 has ip address for hypervisor itself, but basically works as L2 switch whitch can deal with VLAN tags; id=1,10
- Firewall's port \(wan\) works as Gateway which can conduct NAT
- Firewall's port \(clients\) works as trunk port which can deal with VLAN tags; id=1,10,20
- Firewall's port
  - client, id = 1
  - server, id = 10
  - user, id = 20
  - wg0
