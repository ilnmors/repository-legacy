Tags: #os, #configuration, #network, #virtualization, #authorization, #authentication

## Preparation

### Set DHCP reservation and DNS record

#### Set DHCP reservation on KEA DHCP in OPNsense

Following [here](05_07_opnsense_kea.md)

- Services:Kea DHCP:Kea DHCPv4:Reservations - \[+\]
    - Subnet: 192.168.10.0/24
    - IP address: 192.168.10.12
    - MAC address: 0A:49:6E:4D:02:00
    - Hostname: auth
    - Description: auth
    - `save`

#### Set DNS records in BIND

Following [here](../06_network/06_03_net_bind.md).

- net server
- file:
    - ~/data/containers/bind/lib/db.ilnmors.internal
    - ~/data/containers/bind/lib/db.10.168.192.in-addr.arpa

```ini
# db.ilnmors.internal
# ...
auth     IN     A     192.168.10.12
# ...
# db.10.168.192.in-addr.arpa
# ...
12     IN     PTR     auth.ilnmors.internal.
# ...
```

```bash
# Adguard container has Requires=bind.service. When it restarted, then Adguard also restarted.
systemctl --user restart bind
```

### Create VM template

- ~/data/config/scripts/auth.sh

```bash
virt-install \
--boot uefi \
--name auth \
--os-variant debian13 \
--vcpus 2 \
--memory 4096 \
--location /var/lib/libvirt/images/debian-13.0.0-amd64-netinst.iso \ # For serial installing, use `--location` instead of `--cdrom`
--disk pool=vm-images,size=66,format=qcow2,discard=unmap \
--network network=ovs-lan-net,portgroup=vlan10-access,model=virtio,mac=0A:49:6E:4D:02:00 \ # Use designated ovs port group
--graphics none \
--console pty,target_type=serial \
--extra-args "console=ttyS0,115200"
# After enter this command, then the console start automatically
# Remove all annotation before you make the sh file.
```

### Debian installing

- Following [here](../03_common/03_01_debian_configuration.md) to install Debian.
- Debian installer supports serial mode regardless getty@ttyS0 service is enabled or not.
- Following [here](../03_common/03_02_iptables.md) to set iptables.
- Following [here](../03_common/03_04_crowdsec.md) to set CrowdSec

#### Serial console setting

After installation, use `ctrl + ]` to exit console. Before setting getty@ttyS0, you can't use serial console to access VM. Therefore, use IP address set on installation, and connect net server via ssh first, following the step to enable the getty.

### Modify VM template settings

After getty setting, shutdown auth vm with `shutdown` in VM or `sudo virsh shutdown auth` in hypervisor to turn off vm first.

```bash
virsh edit auth
```

```xml
<!-- auth -->
...
</vcpu>
<cputune>
  <shares>1024</shares>
</cputune>
<!-- cpu priority - 1024: default/2048: high/512: low -->

<!--
<disk type='file' device='cdrom'>
...
</disk>
# Remove booting disk 
-->
```

```bash
virsh dumpxml auth > ~/data/config/vms/dumps/auth.xml
virsh start auth && virsh console auth
# Start auth server with console
```

### Common setting

- auth.service

```ini
# ~/data/config/services/auth.service
# ~/.config/systemd/user/auth.service
[Unit]
Description=auth Auto Booting
After=network-online.target
Wants=network-online.target
Requires=opnsense.service

[Service]
Type=oneshot

# Maintain status as active
RemainAfterExit=yes

# CrowdSec should be set
ExecStartPre=%h/data/config/scripts/wait-for-it.sh 192.168.10.1:8080 -t 0
ExecStartPre=%h/data/config/scripts/wait-for-it.sh 192.168.10.11:53 -t 0

ExecStartPre=/bin/bash -c "sleep 15"

# Run the service
ExecStart=/usr/bin/virsh -c qemu:///system start auth

# Stop the service
ExecStop=/usr/bin/virsh -c qemu:///system shutdown auth

[Install]
WantedBy=default.target
```

```bash
ln -s ~/data/config/services/auth.service ~/.config/systemd/user/auth.service

systemctl --user daemon-reload
systemctl --user enable auth.service
systemctl --user start auth.service
```