Tags: #plan, #milestone, #common 

## Homelab Project

### Plans

- [x] Build plans

### Organize theory

- [x] Organize DNS
- [x] Organize DHCP
- [x] Organize PKI
- [x] Organize TLS
- [x] Organize SSO
- [x] Organize Email service
### Organize configuration

- [x] Organize Debian installation
- [x] Organize Debian common configuration
- [x] Organize iptables
- [x] Organize podman
- [x] Organize CrowdSec
- [x] Organize BTRFS

### Hypervisor

- [x] Install Debian13
- [x] Set common configuration
- [x] Set network interfaces
- [x] Set QEMU/KVM and Libvirt environment

### opnsense vm

- [x] Generate opnsense template
- [x] Install opnsense
- [x] Set interface configuration
- [x] Set CrowdSec LAPI configuration (without TLS)
- [x] Set KEA DHCPv4 configuration

### net vm

- [x] Generate net vm template
- [x] Install Debian13
- [x] Set common configuration
- [x] Set network interfaces
- [x] Set DDNS script
- [x] Set BIND container
- [x] Set AdGuard Home container
	- [x] Fix DHCP and Static IP server's `resolv.conf`, and opnsense dns

### auth vm

- [x] Generate auth vm template
- [x] Install Debian13
- [x] Set common configuration
- [x] Set Step-CA container

### opnsense vm

- [x] Set ACME client in OPNsense
- [x] Set TLS on OPNsense with ACME client
- [x] Set TLS on CrowdSec LAPI with ACME client
- [x] Set ACME automation

### net vm

 - [x] Set TLS on AdGuard Home container with ACME client

### dev vm

- [x] Generate dev vm template
- [x] Install Debian13
- [x] Set common configuration

### app vm

- [x] Generate app vm template
- [x] Install Debian13
- [x] Set common configuration
- [x] Set BTRFS on `$HOME/hdd`
 
### auth vm

- [x] Set Caddy - auth container (Main caddy)
	- [x] Caddy TLS certificates
	- [x] Caddy bouncer
	- [x] Caddy log agent
- [x] Set crowdsec bouncer
	- [x] Set collection in LAPI (parser + scenario)
	- [x] Set collection in auth vm
	- [x] Set acquis.d/caddy-auth.yaml
- [x] Set LLDAP container
- [x] Set Authelia container
	- [x] Forward_Auth setting

### dev vm
- [x] Set Postgresql container
	- [x] Set TLS on Postgresql with ACME client
- [x] Set Caddy - dev container (sidecar caddy)
	- [x] Verify TLS re-encryption
	- [x] Veryfiy Forward_Auth from Caddy - auth
- [ ] Set code-server container
	- [ ] Generate container file (with Git and Ansible)
	- [ ] Apply SSO with Authelia and Forward_Auth
	- [ ] SSH setting
	- [ ] Upload opnsense backup file via SFTP
	- [ ] Get all server's configuration file via from terminal

### app vm

- [ ] Gitea container
	- [ ] DB setting
	- [ ] OIDC apply with Authelia
	- [ ] Code and configuration file Git
- [ ] Vaultwarden container (User secret management)
	- [ ] DB setting
	- [ ] OIDC apply with Authelia
	- [ ] TOTP setting (recovery code will be saved in .secret.yaml)
### dev container

- [ ] Set Diun container
- [ ] Set Prometheus and grafana container
- [ ] Set Loki and promtail container
- [ ] Set Postfix
- [ ] Set Dovecot
- [ ] Set Fetchmail
- [ ] Set Mariadb conatiner (when it needs)
	- [ ] Set TLS on Mariadb with ACME client

### app vm

- [ ] Set Caddy - app container (sidecar caddy)
- [ ] Set app service containers
- [ ] Set all server's Kopia and Gitea (with code-server)
	- [ ] Conduct backup verification
	- [ ] `Git` all code on Gitea

---
## Following goals

- [ ] Ansible

> To manage and automate this project, the tool of automation is necessary. In modern architecture, Ansible is one of most powerful tools to automate configuration. After the project will be finished, Ansible will be adopted to manage server's configurations. It supports idempotency powerfully, so from the basic configuration the dev-ops system will be applied on this project. Idempotence is very important.

- [ ] self inspection or mock audit

> Every architecture has their own vulnerability. It is because always the administrator itself is the weakest chain in the security. So, it is necessary to inspect the system based on external criteria. There's the list of criteria below.
> 
> - ISMS-P - Korean standard
> - ISO/IEC 27001 - International standard/Annex A
> - NIST SP 800-53 - NIST CSF
> - CIS Benchmark - checklist of Debian/OPNsense/RDBMS/etc
> - OWASP Top 10

- [ ] documentation deeper

> The system itself can't prove anything. When the document that everyone can understand what it is supports the system, then the system become the most powerful weapon.
> 
> - The code and configuration files, and Ansible playbook based on Git (private Gitea)
> - Architecture Report based on bookstack (As-Is)
> - Policy and Norms Report based on bookstack (To-Be)
> - Audit Report based on bookstack (Proof of Compliance)

- [ ] hacking simulation for public licence

> Use podman network and podman volume, create `kali` and `alpin` container to train and study about hacking in `dev` server. These containers won't combined with `systemd` via `Quadlet`