Tags: #os, #firewall, #configuration, #network 

## Web UI

### Access

- Browser: https://192.168.1.1
- Login with root

### Wizard setting

- Hostname: opnsense
- Domain: ilnmors.internal
- Timezone: Asia/Seoul
    > - System:Settings:General - Time Zone
- DNS Server: 1.1.1.2
    > Temporary DNS server, when Adguard home and BIND is building, the change it.
    > - System:Setting:General - DNS server
- \[  \] Override DNS
- \[  \] Enable Resolver
    
- WAN
    - type dhcp
    - \[\*\]Block RFC1918 Private Networks
    - \[\*\]Block bogon networks
- LAN
    - \[  \] Configure DHCP server
- Change root password

### User setting

- System:Access:Users - \[+\]
    - Name: opnsense
    - Full name: opnsense management account
    - E-mail: opnsense@ilnmors.internal
    - Group: admins

> When console access is needed, root account is necessary. Only root account can access console program. However, when using WebUI it is better to use separated account for security.

### system update and pkg

#### Updates

- System:Firmware:Updates

#### Plugins

- System:Firmware:Plugins
- \[\*\] Community plugins
    - os-crowdsec
    - os-acme-client
    - os-qemu-guest-agent
		>after install and restart plugin check with CLI `virsh qemu-agent-command opnsense '{"execute":"guest-get-osinfo"}'` on hypervisor
    - os-telegraf
    - os-sftp-backup


## Disable unused basic function

In this homelab project, Kea DHCP and AdGuard home, BIND will be used as DHCP server and DNS server. Therefore, it is necessary to disable Dnsmasq, ISC DHCP and Unbound which are used as basic function of DHCP and DNS in OPNsense.

- Services:Dnsmasq DNS&DHCP:General
    - \[  \] Enable
- `Apply`
- Services:ISC DHCPv4
    - \[  \] Enable
- `Apply`
- Services:ISC DHCPv6
    - \[  \] Enable
- `Apply`
- Services:Unbound DNS:General
    - \[  \] Enable
- `Apply`
## Backup

### ZFS Snapshot

Before major updating, it is important to make a ZFS snapshot.

- System:Snapshots - \[+\]
    - Name: \[Date\]
    - `Save`

### Setting backup

OPNsense is managed with configuration file. You can download the configuration file as XML format.

- System:Configuration:Backups
    - Download: `Download configuration`
    - Restore: Select file > `Restore configuration`
    - sftp: URL / SSH private key