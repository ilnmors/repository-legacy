Tags: #os, #hypervisor, #configuration, #virtualization 

## Hypervisor configuration

### Debian installation and configuration

- Following [debian configuration](../03_common/03_01_debian_configuration).
- Following [iptables configuration](../03_common/03_02_iptables.md).
- Following [crowdsec](../03_common/03_04_crowdsec.md) (After OPNsense LAPI configuration).

### QEMU/KVM

#### KVM

KVM is a virtualization engine to share and to allocate physical resource to VM. It works on Linux kernel.

#### QEMU

QEMU is an emulator. It works with KVM frequently, and it emulates hardware or other OS on hypervisor.

### Libvirtd

Libvirtd is a daemon to use libvirt API and command to manage virtualization engines and emulators including QEMU/KVM. It supports not only QEMU/KVM but also XEN, VMWare or etc.

#### Libvirtd configuration

##### LIBVIRT_DEFAULT_URI setting

Basically, KVM and libvirtd require root permission to access low-level device and configuration to implement virtual machines. However, it is possible to use libvirtd command without root permission; `sudo`. When the common user has its group as `kvm`, and `libvirt`, and export environment variable `export LIBVIRT_DEFAULT_URI='qemu:///system'` on `~/.bashrc`.

```bash
# ~/.bashrc
# If the file doesn't exist, execute the commands below
# sudo cp /etc/skel/.bashrc /home/vmm
# sudo cp /etc/skel/.profile /home/vmm
# sudo chown vmm:svadmins .bashrc .profile

# add the line below in .bashrc
echo "export LIBVIRT_DEFAULT_URI='qemu:///system'" >> ~/.bashrc
source ~/.bashrc
```
##### Directory

- ~/data/config/{scripts,server,services,vms}
- ~/data/config/vms/{networks,storages}

#### virsh

##### VM management

- virsh list \[--all\]: Print vm list
- virsh start \[vm_name\]: Start vm
- virsh shutdown \[vm_name\]: Send ACPI signal to vm (shutdown)
- virsh destroy \[vm_name\]: Stop vm forcefully
- virsh reboot \[vm_name\]: Reboot vm
- virsh autostart \[--disable\]: Register vm autostart
- qemu-img create -f \[format\] /path \[volume\]: Create the virtual disk file

##### VM configuration

- virsh edit \[vm_name\]: Open vm template file (xml) and edit
- virsh dumpxml \[vm_name\] > \[file\].xml: Backup vm template file
- virsh define \[file\].xml: Create vm from backup file
- virsh undefine \[vm_name\] \[--nvram\]: Remove vm
> When vm is set as uefi, `--nvram` option is required.
- virsh domrename \[old_vm_name\] \[new_vm_name\]: Rename vm

##### VM access

- virsh console \[vm_name\]: Access vm via serial console

##### Virtual network

- virsh net-define \[file\].xml: Create virtual network from xml file
- virsh net-start \[network_name\]: Start virtual network
- virsh net-autostart \[network_name\]: Register virtual network auto start
##### Snapshot

- virsh snapshot-create-as --domain \[vm_name\] --name \[snapshot_name\] --description \[description\] --disk-only --atomic (for qcow2 format)
-  virsh snapshot-list \[vm_name\]

##### VM pool management

- virsh pool-define ~/data/config/vms/storages/vm-images.xml
- virsh pool-start vm-images
- virsh pool-autostart vm-images
- virsh pool-refresh vm-images - After put the images in the pool
- virsh vol-list vm-images
#### virt-install

virt-install command helps to define vm template file with various options.

```bash
virt-install \
[--import] \ # without booting images, boot with disk. [--cdrom|--location] is not available
--boot uefi \ # activate secure booting
--name vm_name \
--os-variant [os] \ # set optimized setting for each OS
--vcpu [num] \
--memory [num] \ # memory size(unit: MiB)
--location [path] \ # or cdrom, add booting images, location is for serial booting
# --disk path=[path],format=[raw|qcow2],discard=unmap \ # discard=unmap: ssd emulation
# --disk vol=vm-images/my-existing-disk.qcow2 \ # To use pool's volume
--disk pool=vms-images,size=[num],format=qcow2,discard=unmap \ # Create qcow2 image with pool configuration
--network network=[network_name],model=virtio,mac=[mac_address] \
--graphics none \
--console pty,target_type=serial \
--extra-args "console=ttyS0,115200" # Define the console configuration
```

#### virsh network configuration

Libvirt's network is defined and saved as a XML. There is setting below. It can be compatible with host's `open vswitch` interfaces.

- Make xml files
    - ~/data/config/vms/networks/ovs-wan-net.xml
    - ~/data/config/vms/networks/ovs-lan-net.xml
    - `chmod 600 ~/data/config/vms/networks/*`

```xml
<!-- WAN network for OVS -->
<!-- ovs-wan-net.xml -->
<network>
  <name>ovs-wan-net</name>
  <forward mode='bridge'/>
  <bridge name='ovsbr0'/>
  <virtualport type='openvswitch'/> 
</network>
```

```xml
<!-- LAN network for OVS -->
<!-- ovs-lan-net.xml -->
<network>
  <name>ovs-lan-net</name>
  <forward mode='bridge'/>
  <bridge name='ovsbr1'/>
  <virtualport type='openvswitch'/>
  <portgroup name='vlan-trunk'>
    <vlan trunk='yes'>
      <tag id='1' nativeMode='untagged'/>
      <tag id='10'/>
    </vlan>
  </portgroup>
  <portgroup name='vlan10-access'>
    <vlan>
      <tag id='10'/>
    </vlan>
  </portgroup>
</network>
```

- Define XML files

```bash
virsh net-define ~/data/config/vms/networks/ovs-wan-net.xml
virsh net-define ~/data/config/vms/networks/ovs-lan-net.xml
virsh net-start ovs-wan-net
virsh net-start ovs-lan-net
virsh net-autostart ovs-wan-net
virsh net-autostart ovs-lan-net
```

#### virsh storage pool configuration

- Make a storage pool file
	- ~/data/config/vms/storages/vm-images.xml
	- `chmod 600 ~/data/config/vms/storages/*`

```xml
<!-- Storage pool define -->
<!-- vm-images.xml -->
<pool type='dir'>
  <name>vm-images</name>
  <target>
    <path>/var/lib/libvirt/images</path>
  </target>
</pool> 
```

- Define XML files

```bash
virsh pool-define ~/data/config/vms/storages/vm-images.xml
virsh pool-start vm-images
virsh pool-autostart vm-images
```

#### ACL setting

```bash
# To manage qcow2 file without non-root user
sudo setfacl -R -m u:vmm:rwx /var/lib/libvirt/images
sudo setfacl -d -m u:vmm:rwx /var/lib/libvirt/images
```

### Backup configuration

```bash
cp /etc/network/interfaces /etc/default/grub /etc/modprobe.d/vfio.conf ~/data/config/server

sudo cp /etc/iptables/rules.v4 ~/data/config/server
```

### Systemd

#### Linger configuration

```bash
# Check linger configuration
loginctl show-user vmm
# Linger=yes
# It is necessary to use the services after session is done
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
```

- net.service

```ini
# ~/data/config/services/net.service
# ~/.config/systemd/user/net.service
[Unit]
Description=net Auto Booting
After=opnsense.service
Requires=opnsense.service

[Service]
Type=oneshot

# Maintain status as active
RemainAfterExit=yes

# 8080 is CrowdSec API
ExecStartPre=%h/data/config/scripts/wait-for-it.sh -h 192.168.10.1 -p 8080 -t 20

# Run the service
ExecStart=/usr/bin/virsh -c qemu:///system start net

# Stop the service
ExecStop=/usr/bin/virsh -c qemu:///system shutdown net

[Install]
WantedBy=default.target
```
