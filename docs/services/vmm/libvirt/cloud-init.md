# cloud-init and seed.iso

## reference

- https://cloudinit.readthedocs.io/en/latest/reference/examples.html#yaml-examples

## packages

- cloud-image-utils
- genisoimage

## meta-data

- meta-data.yaml

```yaml
instance-id: test-vm-$DATE
local-hostname: test
```

## user-data

- user-data.yaml

```yaml
#cloud-config

# Command which is excuted when systemd boots
bootcmd:
    - groupadd -g 2000 svadmins || true

hostname: test

# auto resize partition and filesystem depends on virtual disk image
growpart:
    mode: auto
    devices: ['/']
    ignore_growroot_disabled: false
resize_rootfs: true

# prohibit root login
disable_root: true

users:
    - name: test
      gecos: test
      primary_group: svadmins
      groups: sudo
      lock_passwd: false
      passwd: $(openssl passwd -6 'password')
      shell: /bin/bash
      ssh_authorized_keys:
        - 'ssh-ed25519 KEY_VALUE'

write_files:
    # ip_forward option
    - path: /etc/sysctl.d/ipforward.conf
      content: |
        net.ipv4.ip_forward=1
      permissions: '0644'
    # systemd-networkd files
    - path: /etc/systemd/network/00-eth0.link
      content: |
        [Match]
        MACAddress=0a:49:6e:4d:00:00
        [Link]
        Name=eth0
      permissions: '0644'
    # - path: /etc/systemd/network/files....
    # ssh host files
    - path: /etc/ssh/id_test_ssh_host
      content: |
        -----BEGIN OPENSSH PRIVATE KEY----- <redacted> -----END OPENSSH PRIVATE KEY-----
      permissions: '0600'
    - path: /etc/ssh/id_test_ssh_host.pub
      content: |
        ssh-ed25519 KEY_VALUE TEST_SSH_HOST
      permissions: '0644'
    - path: /etc/ssh/id_test_ssh_host-cert.pub
      content: |
        ssh-ed25519-cert-v01@openssh.com KEY_VALUE TEST_SSH_HOST
      permissions: '0644'
    # sshd_config
    - path: /etc/ssh/sshd_config.d/cert.conf
      content: |
        HostKey /etc/ssh/id_test_ssh_host
        HostCertificate /etc/ssh/id_test_ssh_host-cert.pub
      permissions: '0644'
    - path: /etc/ssh/sshd_config.d/permit_root_login.conf
      content: |
        PermitRootLogin no
      permissions: '0644'

runcmd:
    # systemd-networkd interface loading
    - update-initramfs -u
    - systemctl disable networking
    - systemctl enable systemd-networkd
    - systemctl enable getty@ttyS0
    - sync

power_state:
    delay: "now"
    mode: reboot
    message: "rebooting after cloud-init configuration"
    timeout: 30
```

## network-config

- network-config.yaml

```yaml
version: 2
ethernets: {}
network:
    config: disabled
```

## Create seed.iso

```bash
cloud-localds  -N network-config test_seed.iso user-data.yaml meta-data
```
