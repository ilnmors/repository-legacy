Tags: #common, #configuration, #os 

## Installation

### General setting

- Language: English - English
- Location: Other > Asia > South Korea
- Locale: United State - en_US.UTF-8
- Keymap to use: American English

### Network setting

#### Auto Configuration

- Auto Configuration: Using DHCP

#### Manual configuration

> `net` server should be configured manually - It has no private DHCP server and DNS server

- `cancel` auto configuration is needed
- IP address: 192.168.10.11/24
- Gateway: 192.168.10.1
- Name server address: 1.1.1.2
  > After AdGuard home and BIND are set, change 192.168.10.11 on `/etc/resolv.conf`
  
#### Common setting

- Hostname: \[vmm, net, auth, dev, app\]
- Domain: ilnmors.internal

### User setting

- Root Password
- User name: \[vmm, net, auth, dev, app\]
- User account: \[vmm, net, auth, dev, app\]
- User Password

### Partition setting

- Partitioning method: Manual

#### Common

- 512MiB - EFI system partition (Boot flag: on)
- 1GiB - Ext4 Journaling (Mount: `/boot`)

#### Hypervisor

- 780GiB - Physical volume for LVM
	- Configure the Logical Volume Manager
	- Create volume group - vmm
	- Create logical volume - vmm - \[root, swap, data\]
	- Finish
- vmm-root: 64GiB - Ext Journaling (Mount: `/`)
- vmm-swap: 16GiB - SWAP area
- vmm-libvirt: 700GiB - Ext4 Journaling (Mount: `/var/lib/libvirt`)

#### VM servers

- 32GiB(net), 64GiB(auth), 256GiB(dev,app) - Ext4 Journaling(mount: /)
  > Don't set swap partition, in qcow2 it is not effective but causes over head(CoW)
  
#### Application server

- Don't set HDD's partition
- Each HDD (2TB)
  > btrfs supports RAID itself. After installing, set RAID10. These will be set with `fdisk`
  
### Debian package manager setting

- Scan extra installation media: no
- Mirror country: South Korea
- Archive mirror: deb.debian.org
- Proxy: \[blank\]
- Popularity-contest: no

### Installing packages setting

- \[\*\] SSH server
- \[\*\] Standard system utilities

## Environment configuration

### Package configuration

#### Common packages

```bash
apt update && apt upgrade
apt install sudo iptables-persistent crowdsec acl
```

- wait-for-it.sh
	- Download it [here](https://github.com/vishnubob/wait-for-it/blob/master/wait-for-it.sh)
	- ~/data/config/scripts
#### Hypervisor

```bash
apt install qemu-system-x86 ksmtuned libvirt-daemon-system virtinst virt-top ifupdown2 openvswitch-switch

# ksmtuned automatically adjusts ksm following its usage
# `cat /sys/kernel/mm/ksm/pages_sharing` shows the page shared by ksmtuned, result * 4KiB is sharing volume
```

#### VMs

```bash
apt install podman curl jq age

# app

apt install btrfs-progs

# SOPS package
curl -LO https://github.com/getsops/sops/releases/download/v3.11.0/sops-v3.11.0.linux.amd64

mv sops-v3.11.0.linux.amd64 /usr/local/bin/sops

chmod +x /usr/local/bin/sops
# Check update this via Diun
```

### User configuration

```bash
usermod [user_name] -u [uid]

# Change default group as svadmins
groupmod [group_name] -g 2000 -n svadmins
chown -R [user_name]:svadmins /home/[user_name]
chmod 770 /home/[user_name]
usermod -aG sudo [user_name]

# Hypervisor
usermod -aG kvm vmm
usermod -aG libvirt vmm

# After user configuration, proceed all step as user with sudo
```

### Make directory structure

#### Common

- /etc/secrets (root:root 711)
- /etc/secrets/\$UID (\$UID:root 500, files: $UID:root 400)

#### Hypervisor

- (vmm:svadmins 700)
- ~/data/config/{scripts,server,services,vms}
- ~/data/config/vms/{networks,storages,dumps}
- /var/lib/libvirt/images

#### VMs

- (\[vms\]:svadmins 700)
- ~/data/{config,containers}
- ~/data/config/{containers,scripts,secrets,server,services}
- ~/data/containers/apps/{certs,etc.}
- ~/kopia

#### Application server

##### SSD

- (app:svadmins 700)
- ~/data/{config,containers}
- ~/data/config/{containers,scripts,secrets,server,services}
- ~/data/containers/app/{certs,etc.}
- ~/kopia

##### HDD

RAID10 HDDs mount on this directory. Following 08_01_app_vm before you set.
- (app:svadmins 700)
- ~/hdd/data/containers
- (app:svadmins 770)
- ~/hdd/backups
- The scrub timer systemd is required for its integrity.

### SSH configuration


- File:
	- /etc/ssh/sshd_config
	- ~/.ssh/authorized_keys

```ini
# /etc/ssh/sshd_config
# key generation
ssh-keygen -t ed25519 -f ~/.ssh/key_name -C "comment"
# ...
PermitRootLogin no
# ...
```

```bash
# Reload sshd
sudo systemctl restart sshd

# Deploy publicly key for ssh
mkdir ~/.ssh && chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys
# Paste public key from the client
```

> If the ICMP protocol doesn't work towards Windows, check Windows' firewall inbound `파일 및 프린터 공유(에코 요청 - ICMPv4-In)" and "파일 및 프린터 공유(에코 요청 - ICMPv6-In)` activatation

### Linger configuration

```bash
sudo loginctl enable-linger [user_name]
loginctl show-user $(whoami)
# Linger=yes 
```

> Linger is necessary to execute services regardless their login session. If linger option were not activated, all the process would be terminated after logout.

### Network configuration

- File:
	- /etc/hosts
	- /etc/resolv.conf
	- /etc/network/interfaces

#### Hostname

```ini
# /etc/hosts
[ip_address] [FQDN] [hostname]
```

#### DNS

- Only for `hypervisor` and `net` which are set manually.

```ini
# /etc/resolv.conf
# Before setting local DNS
nameserver 1.1.1.2
# After setting local DNS (net server)
# nameserver 192.168.10.11
```

#### Interface

- Only for `hypervisor` and `net` which are set manually

##### Hypervisor

```ini
# /etc/network/interfaces
# ifupdown2 and openvswitch-switch are required

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The openvswitch virtual bridge interfaces
auto ovsbr0
iface ovsbr0 inet manual
        ovs_type OVSBridge
        ovs_ports enp2s0

auto ovsbr1
iface ovsbr1 inet manual
        ovs_type OVSBridge
        ovs_ports enp3s0 vlan1 vlan10

# The primary network interfaces
auto enp2s0
iface enp2s0 inet manual
        ovs_type OVSPort
        ovs_bridge ovsbr0

auto enp3s0
iface enp3s0 inet manual
        ovs_type OVSPort
        ovs_bridge ovsbr1
        ovs_options vlan_mode=native-untagged tag=1 trunks=10

# The vlan interfaces
auto vlan1
iface vlan1 inet static
        ovs_type OVSIntPort
        ovs_bridge ovsbr1
        ovs_options tag=1
        address 192.168.1.10/24


auto vlan10
iface vlan10 inet static
        ovs_type OVSIntPort
        ovs_bridge ovsbr1
        ovs_options tag=10
        address 192.168.10.10/24
        gateway 192.168.10.1

# The primary network interfaces for IPv6
# iface enp2s0 inet6 auto
# iface enp3s0 inet6 auto
# openvswitch vlan options
# ovs_options tag=n : access mode
# ovs_options trunk=n : trunk mode
# ovs_options vlan_mode=native-untagged tag=n trunk=m: native untagged mode
```

> Having two IP addresses in a client can cause some problems. One of them is `Asymmetric routing`. When it gets the packet via vlan10 interface from vlan1 client, the server uses vlan1 interface, because client and server are in the same subnet (L2). It can cause problem, like disconnection usually. There is the solution to solve this.
> 
> - Use `mangle` table in iptables, you can solve this, but it is complex to use.
> - Use `IP rule` command, it is easier to set.

##### net

```ini
# /etc/network/interfaces

source /etc/network/interfaces.d/*

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
auto enp1s0
iface enp1s0 inet static
        address 192.168.10.11/24
        gateway 192.168.10.1
# Don't set dns options. It will be set on /etc/resolv.conf
```

### Hypervisor

#### VFIO configuration

##### IOMMU setting

- File: /etc/default/grub

```ini
# /etc/default/grub
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on"
# Intel CPU: intel_iommu=on, AMD CPU: amd_iommu=on
```

##### Device setting

- File: /etc/modprobe.d/vfio.conf

```bash
# Check device
lspci -nn | grep -i sata
# 04:00.0 STAT controller [0106] ... [1b21:1064]
# PCI address: 04:00.00 / Device ID 1b21:1064

# IOMMU group checking
readlink /sys/bus/pci/devices/0000\:04\:00.0/iommu_group
# ../../../../kernel/iommu_groups/14

# The group of PCI device which is needed to passthrough is 14
ls /sys/kernel/iommu_groups/devices/14
# 04:00.00 # To passthrough device, it has to be only device in its IOMMU group
```

```ini
# /etc/modprobe.d/vfio.conf
options vfio-pci ids=1b21:1064
softdep ahci pre: vfio-pci
```

##### Apply all configuration

```bash
sudo update-grub
sudo update-initramfs -u
sudo reboot

# Check IOMMU enable message
dmesg | grep -e DMAR -e IOMMU
# Check the driver
lspci -nnk -d 1b21:1064
# Kernel driver in user: vfio-pci
```

### VM servers

#### Serial console setting

```bash
# It is necessary to connect via ssh to set serial setting
sudo systemctl enable getty@ttyS0
sudo systemctl start getty@ttyS0
```

#### Secret management

##### SOPS setting

- File:
	- ~/data/config/secrets/age-key.gpg
	- ~/data/config/secrets/.sops.yaml
	- ~/data/config/secrets/.secret.yaml
	- /etc/secrets/\$UID (\$UID:root 500)

```bash
# Generate the key for sops
age-keygen -o ~/data/config/secrets/age-key

# # created: 2025-10-17T13:30:00Z
# # public key: age1ql3z7h0cfscg...... 
# AGE-SECRET-KEY-1.....

# Public key is printed when key generated

gpg --symmetric age-key && rm age-key
> GPG password: password

nano ~/data/config/secrets/.sops.yaml && chmod 600 ~/data/config/secrets/.sops.yaml
```

```yaml
# ~/data/config/secrets/.sops.yaml
creation_rules:
  - path_regex: \.secret\.yaml$
    age: [public_key]
```


##### Create Secret file

```yaml
# ~/data/config/secrets/.secret.yaml
# Format of .secret.yaml
# app1.env:
1SECRET: '1secret'
2SECRET: '2secret'

app1.file: |
  -----TEXT-AREA-----
  contents of 3secret
  -----END-AREA-----

# app2.env
3SECRET: '3secret'
4SECRET: '4secret'

# ...
```

```bash
sops --encrypt --in-place ~/data/config/secrets/.secret.yaml
```

##### Secret scripts

- File:
	- ~/data/config/scripts/secrets/edit_secret.sh
	- ~/data/config/scripts/secrets/extract_secret.sh

```bash
#!/bin/bash
# edit_secret.sh /path/of/secret

set -e

KEY_PATH="$HOME/data/config/secrets"
SECRET_FILE="$1"

usage() {
        echo "Usage: $0 \"/path/of/secret/file\""
        exit 1
}


if [ -z "$SECRET_FILE" -o ! -f "$SECRET_FILE" ]; then
	echo "Error: Secret file path is needed"
	usage
fi


if [ ! -f "$KEY_PATH/age-key.gpg" ]; then
	echo "Error: There is no key file"
	exit 1
fi

# Delete password file after script
cleanup() {
	if [ -f "/run/user/$UID/age-key" ]; then
		rm -f "/run/user/$UID/age-key" 
	fi
}

trap cleanup EXIT



echo -n "Enter GPG passphrase: "
read -s GPG_PASSPHRASE
echo

echo "$GPG_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \
--output "/run/user/$UID/age-key" \
--decrypt "$KEY_PATH/age-key.gpg" && \
chmod 600 "/run/user/$UID/age-key"

if [ -z "/run/user/$UID/age-key" ]; then
	echo "Error: Key file does not exist"
	exit 1
fi

gpgconf --kill gpg-agent

SOPS_AGE_KEY="$(cat "/run/user/$UID/age-key")"

SOPS_AGE_KEY="$SOPS_AGE_KEY" sops "$SECRET_FILE"
```

```bash
#!/bin/bash
# extract_secret.sh /path/of/secret (-f|-e <value>)

set -e

KEY_PATH="$HOME/data/config/secrets"
SECRET_FILE=$1

# shift the $2 as $1 ($1 < $2)
shift

# usage() function
usage() {
        echo "Usage: $0 \"/path/of/secret/file\" (-f|-e \"yaml section name\")" >&2
        echo "-f <type name>: Print secret file" >&2
        echo "-e <type name>: Print secret env file" >&2
        exit 1
}

while getopts "f:e:" opt; do
    case $opt in
        f)
            VALUE="$OPTARG"
            TYPE="FILE"
            ;;
        e)
            VALUE="$OPTARG"
            TYPE="ENV"
            ;;
        \?) # unknown options
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :) # parameter required option
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Get option and move to parameters - This has no functional thing, because it only use arguments with parameters
shift $((OPTIND - 1))

# Check necessary options
if [ ! -f "$SECRET_FILE" ]; then
    echo "Error: secret file path is required" >&2
    usage
fi

if [ -z "$TYPE" ]; then
        echo "Error: -f or -e option requires" >&2
        usage
fi


if [ ! -f "$KEY_PATH/age-key.gpg" ]; then
        echo "Error: There is no key file" >&2
        usage
fi

# Delete password file after script
cleanup() {
        if [ -f "/run/user/$UID/age-key" ]; then
                rm -f "/run/user/$UID/age-key"
        fi
}

trap cleanup EXIT

echo -n "Enter GPG passphrase: " >&2
read -s GPG_PASSPHRASE
echo >&2

echo "$GPG_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \
--output "/run/user/$UID/age-key" \
--decrypt "$KEY_PATH/age-key.gpg" && \
chmod 600 "/run/user/$UID/age-key"

if [ ! -f "/run/user/$UID/age-key" ]; then
        echo "Error: Key file does not exist" >&2
        exit 1
fi

gpgconf --kill gpg-agent

SOPS_AGE_KEY="$(cat "/run/user/$UID/age-key")"

if [ "$TYPE" == "FILE" ]; then
        if RESULT=$(SOPS_AGE_KEY="$SOPS_AGE_KEY" sops --decrypt --extract "[\"$VALUE\"]" --output-type binary "$SECRET_FILE") ; then
                echo -n "$RESULT"
                exit 0
        else
                echo "Error: SOPS extract error" >&2
                exit 1
        fi
fi

if [ "$TYPE" == "ENV" ]; then
        if RESULT=$(SOPS_AGE_KEY="$SOPS_AGE_KEY" sops --decrypt --extract "[\"$VALUE\"]" --output-type dotenv "$SECRET_FILE") ; then
                echo -n "$RESULT"
                exit 0
        else
                echo "Error: SOPS extract error" >&2
                exit 1
        fi
fi
```

##### Secret value management

- Using `extract_secret.sh`
- Inject secret value to `podman secret` or `/etc/secrets/$UID`

```bash
# /etc/secrets/$UID
# Before use sudo tee, make sure sudo doesn't need password.
# i.e. sudo ps -ef command execute before this command.
# Env file
extract_secret.sh ~/data/config/secrets/.secret.yaml -e "$value" > /run/user/$UID/tmp.env \
&& sudo mv /run/user/$UID/tmp.env /etc/secrets/$UID/"$FILE_NAME" \
&& sudo chown $UID:root /etc/secrets/$UID/"$FILE_NAME" \
&& sudo chmod 400 /etc/secrets/$UID/"$FILE_NAME"
# Normal file
extract_secret.sh ~/data/config/secrets/.secret.yaml -f "$value" > /run/user/$UID/tmp.env \
&& sudo mv /run/user/$UID/tmp.env /etc/secrets/$UID/"$FILE_NAME" \
&& sudo chown $UID:root /etc/secrets/$UID/"$FILE_NAME" \
&& sudo chmod 400 /etc/secrets/$UID/"$FILE_NAME"

# Podman secret
# Podman doesn't supports .env file parsing, you have to enroll all values
extract_secret.sh ~/data/config/secrets/.secret.yaml -f "$value" | podman secret create "[$FILE_NAME|$ENV_NAME]" -
```

> The reason why apply the secret value manually is its complexity. The `yaml` file can hold a lot of values in one section. It is hard to make the script to deal with a lot of exception and senario. The simple way is the best way.