# Server and client environments

## Console

- OS: WSL2 (Debian 13)
- Processor: 4vCPU
- Memory: 4GiB
- Disk:
    - 32GiB for `/` (VHD file)
- Services:
    - [x] Terminal
    - [x] Step-CLI
    - [x] Ansible
    - [x] Git
    - [x] Kopia
    - [x] cloud-image-utils

## vmm (Hypervisor)

- OS: Debian13
- Processor: pCPU (N150)
- Memory: 3GiB (margin)
    - KSM allows more than 3GiB for vmm
- MAC:
    - c8:ff:bf:05:aa:b0
    - c8:ff:bf:05:aa:b1
- Disk:
    - SSD:
        - 64GiB for `/` (ext4 in LVM)
        - 700GiB for `/var/lib/libvirt` (ext4 in LVM)
- Services:
    - [x] QEMU/KVM
    - [x] libvirtd
    - [x] ksmtuned

## fw (Firewall)

- OS: Debian13
- Processor: 2vCPU
    - cputune.shares 2048
- Memory: 4GiB
- MAC:
    - 0a:49:6e:4d:00:00
    - 0a:49:6e:4d:00:01
- Disk:
    - SSD: 64GiB for `/` (ext4 in qcow2 file)
- Services:
    - native packages:
        - [x] nftables (firewall based on ZONE)
        - [x] Suricata (IDS)
        - [x] CrowdSec LAPI (IPS)
        - [x] Kea DHCP
        - [x] Wireguard-tool
        - [x] BIND9 (Local authoritative DNS)
        - [x] Blocky (Resolver DNS)
    - Scripts:
        - [x] ddns.sh

## infra (Infrastructure)

- OS: Debian13
- Processor: 2vCPU
    - cputune.shares 1024
- Memory: 6GiB
- MAC: 0a:49:6e:4d:01:00
- Disk:
    - SSD: 256GiB for `/` (ext4 in qcow2 file)
- Services:
    - Rootless containers:
        - [x] PostgreSQL
        - [x] lldap
        - [x] Step-CA
        - [x] Caddy (with nsupdate)
        - [x] Prometheus (alloy - push)
        - [x] Loki (alloy)
        - [x] Grafana 
    <!-- 
        Mail service is not needed, especially Diun is not needed.
        - Postfix
        - Dovecot
        - mbsync
        - Diun
    - Study (Rootless container):
        - Kali
        - Debian 
    -->

## auth (Authorization)

- OS: Debian13
- Processor: 2vCPU
    - cputune.shares 512
- Memory: 2GiB
- MAC: 0a:49:6e:4d:02:00
- Disk:
    - SSD: 64GiB for `/` (ext4 in qcow2 file)
- Services:
    - Rootless containers:
        - [x] Caddy (with nsupdate, crowdsec-http, crowdsec-bouncer module)
        - [x] authelia

## app (Application)

- OS: Debian13
- Processor: 4vCPU
    - cputune.shares 1024
- Memory: 16GiB
- MAC: 0a:49:6e:4d:03:00
- Disk:
    - SSD: 256GiB for `/` (ext4 in qcow2 file)
    - HDD: 4TB for `/home/app/data` (btrfs)
- VFIO (Hardware passthrough):
    - Graphic: N150 iGPU
    - Disk: SATA Controller
- Services:
    - OIDC native services:
        - [x] Vaultwarden
        - [x] Gitea
        - [x] Immich
        - [x] Paperless-ngx
        - [x] affine
            - integrated document management via markdown, whiteboard, canvas
        - [x] Nextcloud
            - Use Nextcloud as CalDAV and CardDav, kanban and todo
        - [x] Collabora office
            - Link to Nextcloud
        - [x] sure
            - budget and finance
        - [ ] memos
        - WriteFreely or directus + frontend(Astro)
        - MediaCMS or PeerTube
        - Funkwhale or Navidrome or Jellyfin
        - Kavita
        - Audiobookshelf
        - Miniflux
        - Linkwarden
        - Ralph
        - Conduit
        - SnappyMail
    - archived services:
        - [x] Actual budget
            - YNAB way is hard to adjust
        - [x] OpenCloud
            - Nextcloud is more stable
        - [x] vikunja
            - integrated experience from Nextcloud is better
        - [x] ezBookkeeping
            - No sharing budget function
        - [x] wiki.js
            - Too complex, too heavy
        - [x] TriliumNext
            - OIDC errors, and trilium itself is unstable

## External Backup server

- OS: DSM (Synology)
- Processor: pCPU (Realtek RTD1619B)
- Memory: 1GiB
- MAC: 90:09:d0:65:a9:db
- Disk:
     - HDD: 4TB
- Services:
    - SFTP
    - Kopia repository server
    - CloudSync (Upload backup files to Cloud)
