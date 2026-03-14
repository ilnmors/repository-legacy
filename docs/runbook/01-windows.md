# Windows prerequisite

## Installation

- Language: English (US)
- Region: Korea
- Keyboard: US
- Internet connection
- Account setting: DOS prompt (Shift + F10)
```dos
start ms-cxh:localonly
```

## Initial configuration

### Time and language

- Preferred Languages: Add a Language: Korean
    - Don't set additional options
- Typing: Advanced Keyboard setting: Override for default input method: Korean: Microsoft IME

### Set the password
- Settings: Accounts: Sign-in options
- Password
- PIN
- Windows Hello

### Disable unused functions

```PowerShell
# Administrator privileges are required
## Disable Recall
DISM /Online /Disable-Feature /FeatureName:Recall /NoRestart

## Disable Copilot
reg add "HKCU\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f
reg add "HKLM\Software\Policies\Microsoft\Windows\WindowsCopilot" /v TurnOffWindowsCopilot /t REG_DWORD /d 1 /f

## Delete programs
Get-AppxPackage *bingnews* | Remove-AppxPackage
Get-AppxPackage *bingweather* | Remove-AppxPackage
Get-AppxPackage *gethelp* | Remove-AppxPackage
Get-AppxPackage *tips* | Remove-AppxPackage
Get-AppxPackage *feedbackhub* | Remove-AppxPackage

Get-AppxPackage *solitairecollection* | Remove-AppxPackage
Get-AppxPackage *windowscommunicationsapps* | Remove-AppxPackage
Get-AppxPackage *outlookforwindows* | Remove-AppxPackage
Get-AppxPackage *people* | Remove-AppxPackage
Get-AppxPackage *clipchamp* | Remove-AppxPackage

Get-AppxPackage *todos* | Remove-AppxPackage
Get-AppxPackage *quickassist* | Remove-AppxPackage

Get-AppxPackage *windowsmaps* | Remove-AppxPackage

Get-AppxPackage *xbox* | Remove-AppxPackage
Get-AppxPackage *gamingapp* | Remove-AppxPackage

## Disable telemetry
Stop-Service DiagTrack
Set-Service DiagTrack -StartupType Disable
Stop-Service dmwappushservice
Set-Service dmwappushservice -StartupType Disable

## Compact OS configuration
compact /compactos:always
```

### Delete programs

- Add or remove programs
    - Copilot
    - Family
    - Microsoft 365 (Other languages; except en-us, ko-kr)
    - Microsoft 365 copilot
    - Microsoft edge game assist
    - Microsoft Onedrive
    - Microsoft Teams
    - Speech pack

### Edge configuration
- Settings: System and performance: System
    - Disable All options 

### Explorer configuration

- Settings: Privacy
    - Disable All options

### Login on Microsoft account

sign in on app only
- surface app
- microsoft office 365

### Install Microsoft app

- Microsoft PC manager

### Firewall configuration

- WindowsDefender Firewall:Inbound Rules:
    - File and Printer Sharing (Echo Request - ICMPv4-In) - Profile: Private, Public
        - General: \[x\] Enable
        - Scope: 192.168.1.0/24, 192.168.10.0/24, 192.168.99.0/24
    - File and Printer Sharing (Echo Request - ICMPv6-In) - Profile: Private, Public
        - General: \[x\] Enable
        - Scope: fd00::/8
    - Apply

### NIC VLAN configuration

<!-- There is no physical managed switch, only hub. It is necessary to set so that filter vlan tag from the dummy hub -->
- Device Manager:Network Adapters:Surface network adpaters
    - Advanced:Priority & VLAN: Priority & VLAN disable

## Set WSL2

### Create wsl config

- C:\Users\$USERNAME\.wslconfig
```ini
[wsl2]
processors=4
memory=4294967296
swap=0
defaultVhdSize=34359738368
networkingMode=Mirrored
```

### Installation

```PowerShell
# Run with administrator's authority
# Install wsl
wsl --install -d Debian
# Enter new UNIX username: debian
# Enter new password: debian
wsl --shutdown
# --- Uninstall Debian ---
# wsl --unregister Debian
# wsl --uninstall
# ------
```

### WSL Debian configuration

```bash
# PowerShell
wsl -d Debian
# bash
## User create
sudo groupadd -g 2000 svadmins
sudo useradd -u 2999 -g svadmins -G sudo -c "Console Client" -m -d /home/console -s /bin/bash console
sudo passwd console
# New password: [password]
exit

# PowerShell
wsl --shutdown
wsl -d Debian -u console

# bash
## User delete and set wsl.conf
sudo userdel -r debian
echo '[user]' | sudo tee -a /etc/wsl.conf
echo 'default=console' | sudo tee -a /etc/wsl.conf
echo '[network]' | sudo tee -a /etc/wsl.conf
echo 'generateHosts = false' | sudo tee -a /etc/wsl.conf
exit

wsl --shutdown

wsl -d Debian

## package
sudo apt update && sudo apt upgrade
sudo apt install curl jq gnupg git fuse3
sudo apt install ansible-core ansible-lint --no-install-recommends
ansible-galaxy collection install community.libvirt
ansible-galaxy collection install community.general
ansible-galaxy collection install ansible.posix

## SOPS (arm64)
## Check for latest release: Current version: 3.12.1
## x86_64 url: https://github.com/getsops/sops/releases/download/v3.12.1/sops_3.12.1_amd64.deb

curl -L -o sops_3.12.1.deb https://github.com/getsops/sops/releases/download/v3.12.1/sops_3.12.1_arm64.deb 
sudo apt install ./sops_3.12.1.deb
rm -rf ./sops_3.12.1.deb

mkdir ~/workspace
```

### VS Code

#### VS Code Download
- Download from https://code.visualstudio.com/Download#
  - `User Installer Arm64`

#### VS Code configuration

- WSL extension\(`Ctrl + shift + x`\)
    - Install `WSL` by Microsoft
        - Remote Explorer:Debian:Connect in Current Windows
- `Ctrl + k` and `Ctrl + o`
    - Open folder: `/home/console/workspace`
- `` Ctrl + shift + ` `` for Terminal
- Extensions\(`Ctrl + shift + x`\)
    - Install `Ansible` by RedHat

### Playbooks

```bash
# Ansible playbook

# Copy all files "workspace" directory to Debian via VS Code

cd ~/workspace/homelab/ansible
ansible-playbook playbooks/console/site.yaml --tags "init"
```

#### Terminal configuration

- Terminal: Setting: Startup
    - Default profile
        - Debian
    - Profile: Debian: 
        - Icon
            - "ms-appx:///ProfileIcons/{61c54bbd-c2c6-5271-96e7-009a87ff44bf}.png"
        - Starting Directory
            - ~

## Secret management

### Flow

- Secret data
    - `secrets.yaml`
    - encrypted by sops with age-key
- age-key
    - `age-key.gpg` and `ansible/group_vars/all.yaml`
    - encrypted by gpg and ansible vault with master key
- Master key
    - The key which has above 40 characters containing upper and lower letters, numbers, and special letters
    - managed by physical media \(Mind, MDisc, paper\) as file, string, and QR
    - This value is never saved in server or console.
- Root CA \(including ssh CA\) must not be deployed.
     - The tasks with root CA must be performed manually. The source of Trust is the most important in security.
- Intermediate CA can be deployed.
    - Intermediate CA is operated as a live server. 
    - Intermediate CA can be revoked by the root CA 
    - Only encrypted intermediate CA's private key is deployed.
    - CA server decrypts intermediate CA's private key in memory at runtime.
