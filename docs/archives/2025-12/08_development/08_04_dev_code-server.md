Tags: #os, #configuration, #security , #virtualization, #container, #development 

## Code-Server

Code-Server is an open source and self-hosted Code editer (or IDE with its plugins) to use on web browser. This supports terminal and code editer, git, and ansible. It will be used as a bastion host in the home-lab. Code-Server doesn't support login system. Therefore, authelia and caddy's Forward-Auth function will be used in this homelab system.

### Secret management

- File: 
	- ~/data/config/secrets/.secret.yaml

- Edit `.secret.yaml` with `edit_secret.sh`

```yaml
# ~/data/config/secrets/.secret.yaml
# CODE-SERVER:
CODESERVER_SSH_KEY: SSH_KEY_VALUE
```

```bash

ssh-keygen -t ed25519 -f /run/user/$UID/codeserver -C "code-server@ilnmors.internal"
> [enter] # no passphrase

cat /run/user/$UID/codeserver
> Private key value
# add in .secret.yaml as CODESERVER_SSH_KEY
cat /run/user/$UID/codeserver.pub
> Public key value
# add in .secret.yaml as a annotation

rm -rf /run/user/$UID/codeserver*

extract_secret.sh .secret.yaml -f CODESERVER_SSH_KEY | podman secret create CODESERVER_SSH_KEY -
```

### Preparation

#### Create directory for container

```bash
mkdir -p ~/data/containers/code-server
chmod -R 700 ~/data/containers/code-server
setfacl -m d:g::0 ~/data/containers/code-server
setfacl -m d:o::0 ~/data/containers/code-server
setfacl -m u:dev:rwx ~/data/containers/code-server
setfacl -m u:100999:rwx ~/data/containers/code-server
setfacl -d -m u:dev:rwx ~/data/containers/code-server
setfacl -d -m u:100999:rwx ~/data/containers/code-server
mkdir -p ~/data/containers/code-server/{config,local,ssh,workspace}
echo $PUBLIC_SSH_KEY_VALUE > ~/data/containers/code-server/ssh/id_codeserver.pub

```

> Code-Server container executes as 1000:1000(coder:coder) permission in container. It is mapped host's 100999. Therefore, directories have to have ACL via `setfacl`

#### Add new domain in BIND

Following [here](../06_network/06_03_net_bind.md).

- net server
- file: ~/data/containers/bind/lib/db.ilnmors.internal
  
```ini
# ...
code-server     IN     CNAME     auth.ilnmors.internal.
# ...
```

```bash
# Adguard container has Requires=bind.service. When it restarted, then Adguard also restarted.
systemctl --user restart bind
```

#### Add new rules in Caddy and authelia

##### caddy-auth

- auth server
- file: ~/data/containers/caddy-auth/etc/Caddyfile

```ini
# ...
code-server.ilnmors.internal {
        import private_tls
        import crowdsec_log
        route {
                crowdsec
                import apply_forward_auth https://dev.ilnmors.internal
        }
# ...
```

##### caddy-dev

- dev server
- file: ~/data/containers/caddy-dev/etc/Caddyfile

```ini
# ...
dev.ilnmors.internal {
        import private_tls
        # ...
		@code-server header X-Forwarded-Host code-server.ilnmors.internal
		# ...
		        route @code-server {
                reverse_proxy host.containers.internal:8000 {
                # Sidecar caddy's Caddyfile should change `Host` header as original `Host` value from `X-Forwarded-Host` to prevent websocket problem.
					header_up Host {http.request.header.X-Forwarded-Host}
                }
        }
}
```

##### authelia

```yaml
# configuration.yml

# ...
# Access control configuration
access_control:
  default_policy: 'deny'
  rules:
    # authelia portal
    - domain: 'authelia.ilnmors.internal'
      policy: 'bypass'
    - domain: 'authelia.ilnmors.com'
      policy: 'bypass'
    - domain: 'dev-test.ilnmors.com'
      policy: 'one_factor'
	  # Access control for Forward_Auth
	  subject:
	    - 'group:admins'
	- domain: 'code-server.ilnmors.internal'
	  policy: 'one_factor'
	  subject:
	    - 'group:admins'

# ...
```

#### SSH configuration

##### Each server

- file: ~/.ssh/authorized_keys

```ini
# ...
Contents of code-server's public key value
# ...
```

##### Code-Server container

- file: ~/data/containers/code-server/ssh/config

```ini
Host vmm
    HostName 192.168.1.10
    User vmm
    IdentityFile /run/secrets/CODESERVER_SSH_KEY

Host net
    HostName 192.168.10.11
    User net
    IdentityFile /run/secrets/CODESERVER_SSH_KEY

Host auth
    HostName 192.168.10.12
    User auth
    IdentityFile /run/secrets/CODESERVER_SSH_KEY

# dev is the server where code-server is located. It needs host.containers.internal
Host dev
    HostName host.containers.internal
    User dev
    IdentityFile /run/secrets/CODESERVER_SSH_KEY

Host app
    HostName 192.168.10.14
    User app
    IdentityFile /run/secrets/CODESERVER_SSH_KEY
```

```bash
podman unshare chown 1000:1000 ~/data/containers/code-server/ssh/config
```

### Podman Image

#### Podman containerfile

Code-server supports various module for it. Git and ansible will be used in this project.

- file: 
	- ~/data/config/containers/code-server/containerfile-code-server-4.105.1
	- ~/data/config/containers/code-server/root_ca.crt

```containerfile
FROM codercom/code-server:4.105.1

USER root

RUN export SUDO_FORCE_REMOVE=yes && \
apt-get update && \
apt-get install -y --no-install-recommends git ansible curl jq age gnupg && \
apt-get purge -y --auto-remove sudo && \
apt-get clean

RUN curl -LO https://github.com/getsops/sops/releases/download/v3.11.0/sops-v3.11.0.linux.amd64 && \
mv sops-v3.11.0.linux.amd64 /usr/local/bin/sops && \
chmod +x /usr/local/bin/sops  && \
rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY ./root_ca.crt /usr/local/share/ca-certificates/root_ca.crt

RUN update-ca-certificates

USER coder
```

#### Podman image build

```bash
podman build -t code-server:4.105.1 -f ~/data/config/containers/code-server/containerfile-code-server-4.105.1 . && podman image prune -f
# Delete pure code-server
```

### Quadlet

- File: 
	- ~/data/config/containers/code-server/code-server.container

```ini
# ~/data/config/containers/code-server/code-server.container
# ~/.config/containers/systemd/code-server.container
[Quadlet]
DefaultDependencies=false

[Unit]
Description=Code-Server

After=caddy-dev.service
Wants=caddy-dev.service

[Container]
Image=localhost/code-server:4.105.1

ContainerName=code-server

HostName=code-server

# CrowdSec uses 8080 port
PublishPort=8000:8080/tcp

Volume=%h/data/containers/code-server/workspace:/home/coder/workspace:rw
Volume=%h/data/containers/code-server/config:/home/coder/.config:rw
Volume=%h/data/containers/code-server/local:/home/coder/.local:rw
Volume=%h/data/containers/code-server/ssh:/home/coder/.ssh:rw

Environment="TZ=Asia/Seoul"
# when you needs root permission, you have to access the container via dev server's command 'poman exec -it code-server'

Secret=CODESERVER_SSH_KEY,target=/run/secrets/CODESERVER_SSH_KEY

Label=diun.enable=true
Label=diun.watch_repo=true
# This label need configuration on `diun.yml`
Label=diun.regopt=code-server-source


[Install]
WantedBy=default.target
```

#### Create systemd `.service` file

```bash
# linger has to be activated
ln -s ~/data/config/containers/code-server/code-server.container ~/.config/containers/systemd/code-server.container

systemctl --user daemon-reload
```

#### Enable and start service

```bash
systemctl --user start code-server.service
```

#### Disable password

```bash
nano ~/data/containers/code-server/config/code-server/config.yaml
# bind-addr: 127.0.0.1:8080
# auth: none <- edit this as `none` from `password`
# password: <- remove this part
# cert: false
```


#### Set default workspace

- Setting:Profile:Default:Folders&workspaces
	- Add Folder > /home/coder/workspace
- Setting:Settings:Workbench:Settings Editor
	- Terminal > Integrated: Gpu Acceleration: off
	- Edit in settings.json

```json
{

    "workbench.settings.applyToAllProfiles": [

    ],

    "workbench.colorCustomizations": {

      "terminal.background": "#0C0C0C",

      "terminal.foreground": "#CCCCCC"

    },

    "files.associations": {

        "*.container": "ini",

        "*.service": "ini",

        "*.timer": "ini",

        "containerfile*": "dockerfile"

    }

}
```
#### Verification
