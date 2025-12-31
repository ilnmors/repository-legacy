Tags: #os, #configuration, #application, #virtualization

## Preparation

### Set DHCP reservation and DNS record

#### Set DHCP reservation on KEA DHCP in OPNsense

Following [here](05_07_opnsense_kea.md)

- Services:Kea DHCP:Kea DHCPv4:Reservations - \[+\]
    - Subnet: 192.168.10.0/24
    - IP address: 192.168.10.14
    - MAC address: 0A:49:6E:4D:04:00
    - Hostname: app
    - Description: app
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
app     IN     A     192.168.10.14
# ...
# db.10.168.192.in-addr.arpa
# ...
14     IN     PTR     app.ilnmors.internal.
# ...
```

### Create VM template

```bash
virt-install \
--boot uefi \
--name app \
--os-variant debian13 \
--vcpus 4 \
--memory 12288 \
--location /home/vmm/data/vms/images/debian-13.0.0-amd64-netinst.iso \ # For serial installing, use `--location` instead of `--cdrom`
--disk pool=vm-images,size=258,format=qcow2,discard=unmap \
--network network=ovs-lan-net,portgroup=vlan10-access,model=virtio,mac=0A:49:6E:4D:04:00 \ # Use designated ovs port group
--graphics none \
--console pty,target_type=serial \
--extra-args "console=ttyS0,115200"
# After enter this command, then the console start automatically
# Remove all annotation before you make the sh file.
```

### Debian installing

- Following [here](../03_common/03_01_debian_configuration.md) to install Debian.
- Debian installer supports serial mode regardless getty@ttyS0 service is enabled or not.
- Following [here](../03_common/03_02_iptables.mc) to set iptables.
- Following [here](../03_common/03_04_crowdsec.md) to set CrowdSec

#### Serial console setting

After installation, use `ctrl + ]` to exit console. Before setting getty@ttyS0, you can't use serial console to access VM. Therefore, use IP address set on installation, and connect net server via ssh first, following the step to enable the getty.

#### btrfs RAID setting

Following [here](03_06_btrfs.md) how to use btrfs

- directory: /home/app/hdd

```bash
# Make the directory, RAID partition will be mounted
mkdir /home/app/hdd

# check btrfs-progs package
sudo apt list --installed | grep btrfs-progs
# btrfs-progs/stable,now 6.14-1 amd64 [installed]

# Check the disk status
lsblk -o NAME,PTTYPE,FSTYPE,SIZE,MOUNTPOINT
# - /dev/sda: Physical slot 2
# - /dev/sdb: Physical slot 1
# - /dev/sdc: Physical slot 4
# - /dev/sdd: Physical slot 3
# If you want to manage the partition or disk, then use fsdisk.

sudo fdisk "$DIVICE_PATH"
> n # create the new parition
> 1 # Partition number
> Default # First Sector
> Default # Last Sectort
> w # write the new partition

lsblk -o NAME,PTTYPE,FSTYPE,SIZE,MOUNTPOINT
# - /dev/sda1: partition of slot 2
# - /dev/sdb1: partition of slot 1
# - /dev/sdc1: partition of slot 4
# - /dev/sdd1: partition of slot 3

# btrfs RAID10 volume creation
# -d: the way data store, -m: the way metadata store, -L: create label
sudo mkfs.btrfs -d raid10 -m raid10 -L hdd /dev/sda1 /dev/sdb1 /dev/sdc1 /dev/sdd1

# check the RAID10 volume, it shows label and uuid.
sudo btrfs filesystem show
lsblk -f

# Mount RAID10 volume permanently
sudo nano /etc/fstab
# # btrfs RAID10 storage pool; mount option, compress=zstd: realtime compression. autodefrag: conduct auto defragmentation
# LABEL=hdd    /home/app/hdd     btrfs     defaults,compress=zstd,autodefrag     0     0

# release the fs
sudo systemctl daemon-reload
sudo mount -a

# check the mount
df -h
/dev/sda1 3.7T /home/app/hdd

# Scrubbing btrfs
sudo btrfs scrub start /home/app/hdd
sudo btrfs scrub status /home/app/hdd
```
> btrfs RAID doesn't use fixed hdds pair. It uses flexible chunck unit data management. Therefore user doesn't have to know about which disks are the pair, just change the disk which is broken.

#### btrfs scrub on systemd

File:
	- ~/data/config/services/btrfs-scrub/btrfs-scrub.service
	- ~/data/config/services/btrfs-scrub/btrfs-scrub.timer

```ini
# ~/data/config/services/btrfs-scrub/btrfs-scrub.service
# /etc/systemd/system
[Unit]
Description=BTRFS Scrub for /home/app/hdd
After=home-app-hdd.mount
Wants=home-app-hdd.mount

[Service]
Type=oneshot
ExecStart=btrfs scrub start /home/app/hdd

Nice=19
IOSchedulingClass=idle
# Nice: CPU priority; -20: highest, 0: default, 19: lowest
# IOSchedulingClass: Disk priority; realtime: highest, best-effort: default, idle: lowest 
```

```ini
# ~/data/config/services/btrfs-scrub/btrfs-scrub.timer
# /etc/systemd/system
[Unit]
Description=Run BTRFS scrub for /home/app/hdd monthly

[Timer]
OnCalendar=*-*-01 03:00:00
Persistent=true
# Persistent=true: If the service couldn't run because of some reasons, it execute the service immediately when it is possible

[Install]
WantedBy=timers.target
```

```bash

sudo ln -s ~/data/config/services/btrfs-scrub/btrfs-scrub.service /etc/systemd/system/btrfs-scrub.service

sudo ln -s ~/data/config/services/btrfs-scrub/btrfs-scrub.timer /etc/systemd/system/btrfs-scrub.timer

sudo systemctl daemon-reload

sudo systemctl enable --now btrfs-scrub.timer
```
### Modify VM template settings

After getty setting, shutdown app vm with `shutdown` in VM or `sudo virsh shutdown app` in hypervisor to turn off vm first.

```bash
virsh edit app
```

```xml
<!-- app -->
...
</vcpu>
<cputune>
  <shares>2048</shares>
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
virsh dumpxml app > ~/data/config/vms/dumps/app.xml
virsh start app && virsh console app
# Start app server with console
```

### Common setting

- app.service

```ini
# ~/data/config/services/app.service
# ~/.config/systemd/user/app.service
[Unit]
Description=app Auto Booting
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
ExecStartPre=%h/data/config/scripts/wait-for-it.sh 192.168.10.12:9000 -t 0

ExecStartPre=/bin/bash -c "sleep 15"

# Run the service
ExecStart=/usr/bin/virsh -c qemu:///system start app

# Stop the service
ExecStop=/usr/bin/virsh -c qemu:///system shutdown app

[Install]
WantedBy=default.target
```

```bash
ln -s ~/data/config/services/app.service ~/.config/systemd/user/app.service

systemctl --user daemon-reload
systemctl --user enable app.service
systemctl --user start app.service
```