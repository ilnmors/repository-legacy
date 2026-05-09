# Hypervisor (vmm)

Initiating hypervisor doesn't use ansible. Hypervisor is working on hardware itself, so there is a lot of possible variables like IOMMU id, MAC addresses, etc.

Hypervisor is initiated manually with the configuration files which are stored in USB or External HDD and, WAN connection is from ISP DHCP. All the files in `~/workspace/homelab/data/vmm_init/`

## Installing Debian on server

- BIOS:
    - Check BIOS configuration; IOMMU/VT-d
- General:
    - Language: English - English
    - Location: Other > Asia > South Korea
    - Locale: United State - en_US.UTF-8
    - Keymap to use: American English
- Network:
    - Auto Configuration: Using DHCP
- Server:
    - Hostname: vmm
    - Domain: ilnmors.internal
- User:
    - Root Password: `[blank]`
    - Full name for the new user: vmm
    - User Name: bootstrap
    - User Password: debian
- Partition setting: manual
    - 512MiB - EFI system partition (Booting flag: on) 
    - 1GiB - Ext4 Journaling (Mount: /boot)
    - 800 GiB -LVM
        - 64GiB: vmm-root - Ext4 Journaling (Mount: /)
        - 700GiB: vmm-libvirt - Ext4 (Mount: /var/lib/libvirt)
- Debian package manager setting
    - Scan extra installation media: no
    - Mirror country: South Korea
    - Archive mirror: deb.debian.org
    - Proxy: `[blank]`
    - Popularity-contest: no
- Installing packages setting
    - `[*]` SSH server
    - `[*]` Standard system utilities

### Initial configuration

Hypervisor operates pure L2 switch for fw and it never can access WAN without fw after initial configuration. This means, there is an air-gap which means hypervisor cannot access to WAN for a while (from end of initial setting to the beginning of fw setting).

Hypervisor operates on hardware. Hardware information is always uncertain, and it is set only once. Managing this process as IaC is over engineering.

```bash
# Mount USB on server
lsblk -l
# /dev/xxx # USB
sudo mkdir /mnt/usb
sudo mount /dev/xxx /mnt/usb

# Setting user and groups
sudo groupadd svadmins -g 2000
sudo useradd -u 2000 -g svadmins -G sudo -c "Hypervisor" -m -d /home/vmm -s /bin/bash vmm

# Installing packages
sudo apt update && sudo apt upgrade

sudo apt install -y \
acl curl jq crowdsec systemd-resolved \
qemu-system-x86 ksmtuned libvirt-daemon-system virt-top \
python3 python3-apt python3-libvirt python3-lxml

# Deploy ssh ca
sudo cp /mnt/usb/vmm/ssh/local_ssh_ca.pub /etc/ssh/
sudo chmod 644 /etc/ssh/local_ssh_ca.pub
sudo cp /mnt/usb/vmm/ssh/sshd_config.d/*.conf /etc/ssh/sshd_conifg.d/
sudo chmod 644 /etc/ssh/sshd_config.d/

# Deploy networkd configuration files
sudo cp /mnt/usb/vmm/network/* /etc/systemd/network/

sudo chmod 644 /etc/systemd/network/*

sudo cp /mnt/usb/vmm/sysctl.d/bridge.conf /etc/sysctl.d/bridge.conf
sudo chmod 644 /etc/sysctl.d/bridge.conf

# Check physical MAC address and modify .link file
ip addr
sudo nano /etc/systemd/network/eth0.link
sudo nano /etc/systemd/network/eth1.link

sudo systemctl disable networking.service
sudo systemctl enable systemd-networkd.service

# Deploy nftables config files
sudo cp /mnt/usb/vmm/nftables.conf /etc/nftables.conf

sudo chmod 700 /etc/nftables.conf

# Fix grub
sudo cp /mnt/usb/vmm/grub.d/iommu.cfg /etc/default/grub.d/iommu.cfg
# GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt"
## Intel CPU: intel_iommu=on, AMD CPU: amd_iommu=on
sudo chmod 644 /etc/default/grub.d/iommu.cfg

# Check PCIE ID and IOMMU group
lspci -nn | grep -i -e "SATA" -e "VGA"

# 00:02.0 VGA compatible controller [0300] ... [8086:46d4]
# PCI address: 00:02.0 / Device ID 8086:46d4

# 04:00.0 SATA controller [0106] ... [1b21:1064]
# PCI address: 04:00.00 / Device ID 1b21:1064

# Check the iommu group of devices
## VGA
readlink /sys/bus/pci/devices/0000\:02\:00.0/iommu_group
# ../../../../kernel/iommu_groups/12
ls /sys/kernel/iommu_groups/12/devices/
# 02:00.00
## SATA Controller
readlink /sys/bus/pci/devices/0000\:04\:00.0/iommu_group
# ../../../../kernel/iommu_groups/14
ls /sys/kernel/iommu_groups/14/devices/
# 04:00.00

# To passthrough device, it has to be only device in its IOMMU group or All devices in the same group should be passthroughed simultanaeously.

# Add modprobe.d/vfio.conf
sudo cp /mnt/usb/vmm/modprobe.d/vfio.conf /etc/modprobe.d/vfio.conf
sudo nano /etc/modprobe.d/vfio.conf
# options vfio-pci ids=8086:46d4,1b21:1064
# softdep i915 pre: vfio-pci
# softdep ahci pre: vfio-pci
sudo chmod 644 /etc/modprobe.d/vfio.conf

# Apply vfio configurations
sudo update-grub
sudo update-initramfs -u

# umount usb
sudo umount -f -l /mnt/usb

# reboot system
sudo reboot

# Connect console and vmm via lan cable, Set console's NIC as 192.168.1.11
# delete default user
# ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null vmm_init 
# login: vmm

# check vfio-pci
lspci -nnk -d 8086:46d4
lspci -nnk -d 1b21:1064
# Kernel driver in user: vfio-pci

id vmm
# check sudo group
su - bootstrap
sudo passwd vmm
# enter new password
exit

# delete default user
sudo userdel -r bootstrap
id bootstrap
# id: 'bootstrap': no such user
```
