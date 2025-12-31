Tags: #os, #configuration, #network, #virtualization 

## Preparation

### Create VM template

- ~/data/config/scripts/net.sh

```bash
virt-install \
--boot uefi \
--name net \
--os-variant debian13 \
--vcpus 1 \
--memory 2048 \
--location /var/lib/libvirt/images/debian-13.0.0-amd64-netinst.iso \ # For serial installing, use `--location` instead of `--cdrom`
--disk pool=vm-images,size=34,format=qcow2,discard=unmap \
--network network=ovs-lan-net,portgroup=vlan10-access,model=virtio,mac=0A:49:6E:4D:01:00 \ # Use designated ovs port group
--graphics none \
--console pty,target_type=serial \
--extra-args "console=ttyS0,115200"
# After enter this command, then the console starts automatically
# Remove all annotation before you make the sh file.
```

### Debian installation

- Following [here](../03_common/03_01_debian_configuration.md) to install Debian.
- Debian installer supports serial mode regardless getty@ttyS0 service is enabled or not.
- Following [here](../03_common/03_02_iptables.md) to set iptables.
- Following [here](../03_common/03_04_crowdsec.md) to set CrowdSec

#### Serial console setting

After installation, use `ctrl + ]` to exit console. Before setting getty@ttyS0, you can't use serial console to access VM. Therefore, use IP address set on installation, and connect net server via ssh first, following the step to enable the getty.

### Modify VM template settings

After getty setting, shutdown net vm with `shutdown` in VM or `sudo virsh shutdown net` in hypervisor to turn off vm first.

```bash
virsh edit net
```

```xml
<!-- net -->
...
</vcpu>
<cputune>
  <shares>512</shares>
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
virsh dumpxml net > ~/data/config/vms/dumps/net.xml
# Start net server with console
```

### Common setting

- net.service

```ini
# ~/data/config/services/net.service
# ~/.config/systemd/user/net.service
[Unit]
Description=net Auto Booting
After=network-online.target
Wants=network-online.target
Requires=opnsense.service

[Service]
Type=oneshot

# Maintain status as active
RemainAfterExit=yes

# CrowdSec should be set
ExecStartPre=%h/data/config/scripts/wait-for-it.sh 192.168.10.1:8080 -t 0

ExecStartPre=/bin/bash -c "sleep 15"

# Run the service
ExecStart=/usr/bin/virsh -c qemu:///system start net

# Stop the service
ExecStop=/usr/bin/virsh -c qemu:///system shutdown net

[Install]
WantedBy=default.target
```

```bash
ln -s ~/data/config/services/net.service ~/.config/systemd/user/net.service

systemctl --user daemon-reload
systemctl --user enable net.service
systemctl --user start net.service
```