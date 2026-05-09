# Operation

## Migration backup

When the migration is decided, the manual backup after shutting all services down is necessary. Run the DB dump backup and kopia backup manually before reset the system.

## Windows

- Following the process step.
    - [01-windows.md](./01-windows.md)

## Certificates and wireguard

- Following the process two steps.
    - [02-certificates.md](./02-certificates.md)
    - [03-wireguard.md](./03-wireguard.md)

## console

### Data restore

Only when kopia repository exists.

```bash
kopia repository connect server \
--url=https://nas.ilnmors.internal:51515 \
--override-username=console \
--override-hostname=console.ilnmors.internal
# Enter the password

kopia snapshot list --all

# mount volumes
kopia mount $CONSOLE_SNAPSHOT_ID ~/workspace/homelab/volumes/console
kopia mount $INFRA_SNAPSHOT_ID ~/workspace/homelab/volumes/infra
kopia mount $APP_SNAPSHOT_ID ~/workspace/homelab/volumes/app

# Set initiating db dump files
cp ~/workspace/homelab/volumes/infra/cluster/cluster.sql ~/workspace/homelab/config/services/containers/infra/postgresql/init/cluster.sql
# ...
```

### Provisioning

Ansible playbooks should be declarative. This won't contain complex branch logics (Declarative over imperative). Playbooks describes what should be there, not how to. The basic rule is manual destroy and auto reprovisioning.

#### vmm and fw

- Following the process step.
    - [04-hypervisor.md](./04-hypervisor.md)

```bash
# Sign on vmm's host ssh keys and set libvirt environment # Ignore fingerprint just once
cd ~/workspace/homelab/ansible

# Disconnect all internet connection except LAN between vmm
ansible-playbook playbooks/vmm/site.yaml --tags "init" --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
# Create fw
ansible-playbook playbooks/vmm/create_vm.yaml --tags "fw"
# Make it sure disable other NIC (Wifi or etc) before run playbooks, and set gateway
ansible-playbook playbooks/fw/site.yaml --tags "init" --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'  # When nftables is changed, crowdsec handlers work. However, when it is in initiating, handler is failed. It is normal work.
ansible-playbook playbooks/fw/site.yaml --tags "site"
# Set vmm after air-gap
ansible-playbook playbooks/vmm/site.yaml --tags "site"
```

## External hardware on CLIENT

- Following the process two steps.
    - [05-hardwares.md](./05-hardwares.md)
    - [06-kopia.md](./06-kopia.md)

## Other vms

```bash
# Kopia mount
## Create Kopia password file
touch /etc/secret/$CONSOLE_UID/kopia_password
### Add kopia.user.console value from secrets.yaml
## Connect repository
KOPIA_PASSWORD="$(cat /etc/secrets/$CONSOLE_UID/kopia_password)" \ 
/usr/bin/kopia repository connect server \
--url=https://nas.ilnmors.internal:51515 \
--override-username=console \
--override-hostname=console.ilnmors.internal
## mount kopia directories
kopia mount $INFRA_SNAPSHOT_ID ~/workspace/data/volumes/infra
kopia mount $APP_SNAPSHOT_ID ~/workspace/data/volumes/app
## bringing sql dump files to init directory
cp ~/workspace/data/volumes/infra/cluster/$FILE_NAME ~/workspace/config/services/containers/infra/postgresql/init/pg_cluster.sql
## repeate for every service
# Create vms (Possible tags = ["fw", "infra", "auth", "app"])
ansible-playbook playbooks/vmm/create_vm.yaml --tags "$VM_NAME"
# Sign on vms' host ssh keys # Ignore fingerprint just once
ansible-playbook playbooks/$VM_NAME/site.yaml --tags "init" --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
ansible-playbook playbooks/$VM_NAME/site.yaml --tags "site"
# app
ansible-playbook playbooks/app/site.yaml --tags "init" --ssh-common-args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null'
## Rsync app data
rsync -avz --numeric-ids -e ssh --rsync-path="sudo rsync" ~/workspace/homelab/volumes/kopia/app/ app@app.ilnmors.internal:/home/app/data/
# --numeric-ids: set owner and groups based on uid and gid
# -e ssh --rsync-path="sudo rsync": run rsync as root permission, sudo password needed
# Maybe rsync-path is run on background, it might not print prompt for password. Just enter the password
ansible-playbook playbooks/app/site.yaml --tags "site" 

# Create console snapshot
kopia snapshot create ~/workspace
```
