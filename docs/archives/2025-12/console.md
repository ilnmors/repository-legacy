# Console client

Tags: #os, #windows, #virtualization, #wsl, #vscode

## Preparation

### WSL

#### WSL command

Run the commands in PowerShell or CMD. Installation and uninstallation process needs admin privileges.

```PowerShell
# --- Install and setup ---
# Activate WSL (First time only)
wsl --install

# Install specific OS
wsl --install -d Debian

# Check the list
wsl --list --online

# Check the version
wsl -l -v

# --- Run and manage ---
# Run WSL
wsl -d Debian # -u root # run with root

# Shutdown WSL
# This is needed when the configuration is changed
wsl --shutdown

# Shutdown specific version
wsl --terminate Debian

# --- Backup and restore ---

# Backup WSL
wsl --export Debian C:\backups\wsl.tar
# Import WSL
wsl --import Debian C:\WSL\Debian C:\backups\wsl.tar

# Open the linux directory on windows explorer
# bash
# explorer.exe .
# Windows explorer
# \\wsl$ on the windows explorer

# --- Reset or inactivate ---
# Reset the specific version
wsl --unregister Debian

# Inactive WSL
wsl --uninstall
```

#### WSL configuration

##### Installation

```PowerShell
# Activate WSL and install Debian
wsl --install -d Debian
# Enter new UNIX username: debian
# Enter new password: debian

```

##### Configuration

- `Win`:Windows Linux Subsystem Configuration \(GUI\)
- Processor and memory
	- Processor: 4
	- Memory: 4096MB
	- Swap: 0
- Filesystem
	- Basic VHD: 32768MB
- Networking
	- Mode: Mirrored

#### WSL Start

```PowerShell
# Start WSL
wsl -d Debian
# User and group configuration
sudo groupadd -g 2000 svadmins
sudo useradd -u 2999 -g svadmins -G sudo -c "Console Client" -m -d /home/console -s /bin/bash console
sudo passwd console
# New password: random string
exit

# PowerShell
wsl --shutdown
wsl -d Debian -u console

# Delete default account
sudo userdel -r debian

# Set default user
sudo nano /etc/wsl.conf
# ...
# [user]
# default=console
exit

# PowerShell
wsl --shutdown
wsl -d Debian
# Check `console` login

# Create the directory for VS Code
mkdir workspace && chmod 700 workspace
```

### VS Code

#### Installation

- Site: https://code.visualstudio.com/
	- Download for Windows
- Execute the installation file

#### Configuration

- Extensions\(`Ctrl` + `shift` + `x`\):WSL
	- Install WSL by Microsoft
- Remote Explorer:Debian:Connect in Current Windows
- `Ctrl` + `k` and `Ctrl` + `t` for theme
	- Dark Modern
- `Ctrl` + `k` and `Ctrl` + `o` for `open folder`
	- /home/console/workspace/
	- Do you trust the authors of the files in this folder - `Yes, I trust the authors`
- `Ctrl` + `Shift` + `` ` `` for `open terminal`

## Bastion host

### Directory structures

Use `mkdir` to make these directories.
- ~/workspace/homelab/data/
	- utils
		- common - wait-for-it.sh, sops, etc... 
		-  \[server_name\]/\[bin_name\] - ddns, init_db, etc ... 
	- servers
		- os/\[iso or img files for installation\]
		- \[server_name\]/\[service_name; iptables, interface, ssh, vfio, etc..\] - rules.v4, sshd_config, etc... 
	- services
		- \[server_name\]/\[services_name\]
			- *.containers or *.service (systemd files)
			- config - services configuration (named.conf, etc; !No live data files like DB file or media file. Only configuration files based on text or binary files.) 
	- secrets - secret_scripts, secret.yaml (central secret management)
-  ~/workspace/homelab/docs 
	- library
		- archives 
			- before_bastion_host/current_documents_and_directories
		- references
		- techs
			- current_common_documents 
		- theories
			- current_theory_documents 
		- images 
		 - media 
		 - etc. 
	- plans 
		- plan.md 
		- milestone.md 
	- infrastructures
		- common
			- debian_configuration.md (OS, network, uid/gid, packages) 
			- deployment.md 
			- security_policies.md (iptables, crowdsec) 
			- data_polices.md (storage, backup, database)
		- \[server_name\]
			- \[server_name\].md - virtual hardware, security, services, etc...
			- \[services_name\].md

### Packages

- External binary packages are located in here
	- ~/workspace/homelab/data/bin/common
	
```bash
sudo apt update && sudo apt upgrade
# Packages from repository
sudo apt install gnupg acl curl jq age git openssh-client

# Git config
git config --global user.name "il"
git config --global user.email "il@ilnmors.internal"

# Sops
## Sops for amd processor (N150)
curl -LO https://github.com/getsops/sops/releases/download/v3.11.0/sops-v3.11.0.linux.amd64

## Sops for arm processor (Snapdragon Plus)
curl -LO https://github.com/getsops/sops/releases/download/v3.11.0/sops-v3.11.0.linux.arm64

mkdir -p ~/workspace/homelab/data/bin/common && chmod 700 ~/workspace/homelab/data/bin/common

mv sops-v3.11.0.linux.amd64 sops-v3.11.0.linux.arm64 ~/workspace/homelab/data/bin/common/

sudo cp ~/workspace/homelab/data/bin/common/sops-v3.11.0.linux.arm64 /usr/local/bin/sops

sudo chmod +x /usr/local/bin/sops

# wait-for-it.sh
curl -LO https://github.com/vishnubob/wait-for-it/blob/master/wait-for-it.sh

mv wait-for-it.sh ~/workspace/homelab/data/bin/common/

# acme.sh
curl -LO https://github.com/acmesh-official/acme.sh/blob/master/acme.sh
mv acme.sh ~/workspace/homelab/data/bin/common/
```

### Secret management

- Files:
	- ~/workspace/homelab/data/secrets/secret.yaml
	- ~/workspace/homelab/data/secrets/.sops.yaml
	- ~/workspace/homelab/data/secrets/age-key.gpg
	- ~/workspace/homelab/data/secrets/edit_secret.sh
	- ~/workspace/homelab/data/secrets/extract_secret.sh

#### Apply the secrets

- Server: console

##### Generate and encrypt age key


```bash
# Generate the key for sops
age-keygen -o ~/workspace/homelab/data/secrets/age-key
# # created: 2025-10-17T13:30:00Z
# # public key: age1ql3z7h0cfscg......
# AGE-SECRET-KEY-1.....

# Public key is printed when key generated
gpg --symmetric age-key && rm age-key
> GPG password: password

nano ~/workspace/homelab/data/secrets/.sops.yaml
```

##### Key value setting for sops

```yaml
# ~/workspace/homelab/data/secrets/.sops.yaml
creation_rules:
  - path_regex: secret\.yaml$
    age: [public_key value; age~~~]
```

##### Mnagement secret  

```bash
# Create secret
cd ~/workspace/homelab/data/secrets
nano secret.yaml

# Replace the file as secret file
sops --encrypt --in-place secret.yaml

# edit secret.yaml
./edit_secret.sh secret.yaml

# Create secret files in each server
./extract_secret.sh secret.yaml [-n] (-e|-f $ENV) > $TMP_PATH/tmp_secret

# deploy the tmp_secret to server to /run/user/$UID/filename
scp $TMP_PATH/tmp_secret [server]:/run/user/$TARGET_UID/filename

# `<< 'EOF'` sends string itself
# `<< EOF` sends string after interpreting
ssh [server] << 'EOF'
    sudo mv /run/user/$UID/filename /etc/secrets/$UID/secret_file
    rm -rf /run/user/$UID/filename
    sudo chown $UID:root /etc/secrets/$UID/secret_file
    sudo chmod 400 /etc/secrets/$UID/secret_file
EOF

rm -rf $TMP_PATH/tmp_secret

# Podman secret in each server
./extract_secret.sh secret.yaml [-n] -f $ENV | ssh sv "podman secret create $ENV -"
```

#### Usage of podman secret

```container
#...
#...
[Container]
# ..
Secret=env,type=env,target=env
Secret=app,target=/run/secrets/app
```

### ssh configuration

#### ssh key gen

```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t ed25519 -f ~/.ssh/id_console -C "il@ilnmors.internal"

# Add private key value to ~/workspace/homelab/data/secret/secret.yaml with sops
## # console ssh public key:
## # ed25519 ~~~~ il@ilnmors.internal
## # console ssh private key
## CONSOLE_SSH_PRIVATE_KEY: |
## ----BEGIN----
## ...
## ----END----

sudo mkdir -p /etc/secrets/2999 # $UID of `console`
sudo chown root:root /etc/secrets && sudo chmod 711 /etc/secrets
sudo chown console:root /etc/secrets/2999 && sudo chmod 500 /etc/secrets/2999
sudo mv ~/.ssh/id_console /etc/secrets/2999/ && sudo chown console:root /etc/secrets/2999/id_console && sudo chmod 400 /etc/secrets/2999/id_console
```

#### ssh key config

```ini
# ~/.ssh/config

Host vmm
	HostName [vmm ip from ncpa.cpl's temporary dhcp ip address]
	User vmm
	IdentityFile /etc/secrets/2999/id_console

# Host vmm
#    HostName 192.168.10.10
#    User vmm
#    IdentityFile /etc/secrets/2999/id_console

# Host net
#    HostName 192.168.10.11
#    User net
#    IdentityFile /etc/secrets/2999/id_console

# Host auth
#    HostName 192.168.10.12
#    User auth
#    IdentityFile /etc/secrets/2999/id_console
    
# Host dev
#    HostName 192.168.10.13
#    User dev
#    IdentityFile /etc/secrets/2999/id_console

# Host app
#    HostName 192.168.10.14
#    User app
#    IdentityFile /etc/secrets/2999/id_console
```