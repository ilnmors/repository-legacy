Tags: #common, #configuration, #os, #filesystem

## BTRFS usage

### Setting

```bash
# All hdd needs partition, but it has no filesystem. To make a partition use `fdisk`.
sudo fdisk "$DIVICE_PATH"
> n # create the new parition
> 1 # Partition number
> Default # First Sector
> Default # Last Sectort
> w # write the new partition

# check btrfs-progs package
sudo apt list --installed | grep btrfs-progs
# btrfs-progs/stable,now 6.14-1 amd64 [installed]


sudo mkfs.btrfs -d raid10 -m raid10 -L hdd /dev/sda1 /dev/sdb1 /dev/sdc1 /dev/sdd1
# These are partition device files
```

### Snapshot

Usually, the Read-Only snapshot is used.

```bash
# Create snapshot_subvolume
sudo btrfs subvolume create /home/app/hdd/data
# Create snapshot_directory
mkdir /home/app/hdd/.snapshot
# Create snapshot
sudo btrfs subvolume snapshot -r /home/app/hdd/data /home/app/hdd/.snapshot/data_[date]

# Rollback (file)
cp /home/app/hdd/.snapshot/data_[date]/file /home/app/hdd/data/

# Roleback (volume)
# Current subvolume move
mv /home/app/hdd/data /home/app/hdd/data_fail
sudo btrfs subvolume snapshot /home/app/hdd/.snapshot/data_[date] /home/app/hdd/data
# If the data successfully recovered
sudo btrfs subvolume delete /home/app/hdd/data_fail
```

### replace HDD to new system

btrfs has its own volume manangement data and filesystem in hdd, as metadata. It has no dependency on specific OS or hardware but it can work on every linux system which supports btrfs.

```bash
# unmount filesystem
sudo umount /home/app/hdd

# turn off the system, and remove all hdd
# add all disk to new hardware(server), and turn on

# scan btrfs
sudo btrfs device scan
sudo btrfs filesystem show

# mount
sudo nano /etc/fstab
# LABEL=hdd    /home/app/hdd     btrfs     defaults,compress=zstd,autodefrag     0     0 
sudo mount -a
```

### add extra HDD

```bash
# Add HDD and check the device file
lsblk

# Add hdd to btrfs RAID
sudo btrfs device add /dev/xxx /dev/xxy /home/app/hdd

# Expand the volume
sudo btrfs balance start /home/app/hdd
```

### change HDD

#### btrfs replace

When sata slot is enough to connect new HDD and old HDD, you can use this way.

```bash
# check devid of old HDD
sudo btrfs device stats /home/app/hdd # you can check IO error
sudo btrfs filesystem show /home/app/hdd

# check the new disk's path
lsblk
# /dev/xxx

# Replace
sudo btrfs replace start [old HDD\'s devid] /dev/xxx /home/app/hdd

# check
sudo btrfs replace status /home/app/hdd
```

#### btrfs device add and delete

When sata slot is not enough to connect new HDD and old HDD simultaneously, you can use this way.

```bash
# Check the HDD which will change
sudo btrfs device stats /home/app/hdd # you can check IO error
sudo btrfs filesystem show /home/app/hdd # check disk's devid

# turn off the system and change the broken HDD to the new HDD
# Make sure the hardware supports Hot-Swap, if it didn't support, you would have to turn off your system fully when you are changing the HDD

# if the system couldn't mount automatically, mount it manually
# sudo mount -o degraded /dev/xxx /home/app/hdd # /dev/xxx is one of ordinary HDD

lsblk
# /dev/xxy # new HDD device file path

# Add new HDD
sudo btrfs device add /dev/xxy /home/app/hdd

# Delete broken HDD
sudo btrfs device delete missing /home/app/hdd

# To major balance
sudo btrfs balance start /home/app/hdd
```