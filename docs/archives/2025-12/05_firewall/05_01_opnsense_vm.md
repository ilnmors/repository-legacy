Tags: #os, #firewall, #configuration, #network, #virtualization 


## Preparation

### Create VM template

- ~/data/config/scripts/opnsense.sh

```bash
virt-install \
--import \ # Start without CD-ROM or location - This is for Serial installation.
--boot uefi \ # Supports secure booting
--name opnsense \ # VM name
--os-variant freebsd14.2 \ # Choose kind of OS
--vcpus 2 \ # Set number of vcpu (It means core of pcpu)
--memory 4096 \ # Set the memory volume (Default: MiB)
--disk path=/var/lib/libvirt/images/OPNs
ense-25.7-serial-amd64.img,format=raw \ # Installation image file, format raw
--disk pool=vm-images,size=72,format=qcow2,discard=unmap \ # The target disk to install opnsense, it is on SSD; discard=unmap option will emulate SSD. 
--network network=ovs-wan-net,model=virtio,mac=0A:49:6E:4D:00:00 \ # Use pre-designated network and specific MAC address
--network network=ovs-lan-net,portgroup=vlan-trunk,model=virtio,mac=0A:49:6E:4D:00:01 \
--graphics none \ # Don't use any graphic
--console pty,target_type=serial # Use console serial
# After enter this command, then the console start automatically
# Remove all annotation before you make the sh file.
```

### OPNsense installation

```sh
# Interface setting
Press any key to start the manual interface assignment: [enter]
LAGGs: N
VLANs: N
Enter the WAN interface name or 'a' for auto-detection: vtnet0
Enter the LAN interface name or 'a' for auto-detection: vtnet1 
Enter the Optional interface 1 name or 'a' for auto-detection:  [blank]
Do you want to proceed? : Y

# Login as an installer account
login: installer
password: opnsense

# installing
Continue with default keymap
Install (ZFS)
stripe
[*] vtbd1: yes
Complete Install: Halt Now
```

### Modify VM template

- virsh edit

```bash
virsh edit opnsense
```

- Edit template file

```xml
<!-- opnsense -->
...
</vcpu>
<cputune>
  <shares>2048</shares>
</cputune>
<!-- cpu priority - 1024: default/2048: high/512: low -->

<!--
<disk>
...
<source file='/var/lib/libvirt/images/opnsense.img'/>
...
</disk>
# Remove booting disk
-->
...
</console>
<channel type='unix'>
  <target type='virtio' name='org.qemu.guest_agent.0'/>
</channel>
<!-- Define QEMU-Guest-Agent channel -->
```

- Save template file

```bash
virsh dumpxml opnsense > ~/data/config/vms/dumps/opnsense.xml
```

- opnsense.service

```ini
# ~/data/config/services/opnsense.service
# ~/.config/systemd/user/opnsense.service
[Unit]
Description=opnsense Auto Booting
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot

# Maintain status as active
RemainAfterExit=yes

# Run the service
ExecStart=/usr/bin/virsh -c qemu:///system start opnsense

# Stop the service
ExecStop=/usr/bin/virsh -c qemu:///system shutdown opnsense

[Install]
WantedBy=default.target
```

```bash
mkdir -p ~/.config/systemd/user

chmod -R 700 ~/.config

ln -s ~/data/config/services/opnsense.service ~/.config/systemd/user/opnsense.service

systemctl --user daemon-reload
systemctl --user enable opnsense.service
systemctl --user start opnsense.service
```