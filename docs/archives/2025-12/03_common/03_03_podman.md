systTags: #common, #configuration, #virtualization, #container, #os 

## podman

The container is one of virtual technology to run applications independently regardless of what the host system is. One of them, Docker uses daemon(dockerd) and docker socket(root authority), so all container can access hosts' root authority. It causes danger that hackers can take down root authority via docker containers. Additionally, docker daemon system makes it hard to combine each container to systemd, because all containers are in charge of dockerd.

Podman is a new technology to solve docker's problems. It implements daemonless, and rootless container environment. It reduces the danger of the hacker getting root authority via containers, and it is easy to combine each container to systemd.

### Configuration

- File: /etc/containers/registries.conf

```bash
# Check the linger
loginctl show-user $(whoami)
# Linger=yes
```

```ini
# /etc/containers/registries.conf
unqualified-search-registries = ["docker.io"]
```

### Networking

Podman uses a specific IP address and domain names to communicate with its host system using pasta. Pasta is a new default network mode in podman 4.0 which can allow communication with the host system directly. Therefore, it doesn't need a bridge or network host. `169.254.1.2` is 'link-local address' to communicate with host's system. The pasta conduct the SNAT. Therefore, even though the packet's original source IP were container's IP, when the packet passes the pasta its source IP changes as 127.0.0.1 or its own IP (localhost).

- `/etc/hosts` in container
    - 169.254.1.2 host.containers.internal host.docker.internal

When you use the command below, you can add domain to the line.

- --host-name mydomain.internal:host-gateway

Additionally, rootless podman containers cannot bind host's privileged ports number(=<1024). Therefore, if container needed to use these ports, you would have to use iptables' nat table. The example of iptables' usage is [here](./03_02_iptables.md).

#### Bridge mode

Bridge mode create a separated virtual IP network from host's network. This mode supports simple DNS function between containers belonging to the same network. This mode basically uses SNAT(Source NAT) mutually; both inbound and outbond. It is because basically podman runs as rootless. So, the container can't distinguish where the packets come from, except from the container belonging to the same podman network. At the same time, client also can't distinguish where the packets come from. Because every packet seems like come from host server. It makes inspection hard for both of client and containers.

### ID mapping

Podman basically mapped container's root to host's executing user. Despite the root, podman uses subuid, subgid system. They are set on `/etc/subuid`, `/etc/subgid`.

- host(1000:1000) < container(0:0)
- host(100999:100999) < container(1000:1000) : subuid, subgid

When podman runs and executes commands with -u option, --userns=keep-id option, -uid, -gid option, it can adjust mapping.

- -u uid:gid: excute container with hosts's uid (bring the host's UID/GID towards container's `/etc/passwd` directly.)
- --userns=keep-id: mapping all container's file permission to host's file permission.
- --cap-add=DAC_READ_SEARCH option: without root authority, container can access every file regardless permission.

#### Mapping error

Some container doesn't execute a container with root permission. They execute the container with their specific uid (i.e. UID:53 - BIND). In this case, when the container runs with `-u` option or `--userns=keep-id` option can make mapping error very frequently.

- `-u` option

When the container runs with `-u` option, the entrypoint can't work properly in many cases because they were already set that runs entrypoint as specific uid. So, if `-u` option were set, then it would cause permission error.

- `--userns=keep-id` option

This option makes container's directory/file UID as the same as the host's directory/file UID. So, it turns off the UID/GID mapping itself. When some directory which has root authorization mapped with hosts' file it occurs UID mapping error.

#### Permission management

Use ACL packages, to give additional permission of directory. It can give the extra permission to subuid or host's uid.

```bash
# u:[subuid]:rwx
sudo getfacl /path/of/podman_directory
# `-d` option is to set permission for file or directory which are created automatically
# `-R` option is to set permission for file or directory which already existed
sudo setfacl -d -m u:[subuid]:rwx /path/of/podman_directory
sudo setfacl -d -m u:[hostuid]:rwx /path/of/podman_directory
```

### Usage of podman

#### Containerfile and build

Containerfile's format is compatible with dockerfile. Here is the example below. Containerfile can be built as podman image with `podman build` command.

```containerfile
FROM caddy:2.10.2-builder-alpine AS builder

RUN xcaddy build \
--with github.com/caddy-dns/rfc2136 \
--with github.com/hslatman/caddy-crowdsec-bouncer/crowdsec \
--with github.com/hslatman/caddy-crowdsec-bouncer/http \

FROM caddy:2.10.2

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
```

```bash
# Build container file as podman image
podman build -t caddy:2.10.2-main -f /path/of/containterfile-caddy-main . && podman image prune -f
# Delete source images
podman rmi caddy:2.10.2-builder-alpine
podman rmi caddy:2.10.2
```

#### Podman images

- `podman images`: Print list of all local podman images
- `podman image pull [image_name]`: Download podman images from repository
	- `podman pull` is the same command
- `podman image prune`: Remove unused and untagged images
- `podman image rm [images]`: Remove local podman image
	- `podman rmi` is the same command

#### Run and exec

podman ps \[--all\]: it shows podman container lists
- podman run
    - --name: container's name
    - --restart: restart mode - unless-stopped
    - --add-host: additional host domain name on 169.254.1.2
    - --cap-add: add some specific privileges without root authority
    - -p host_ports:container_port
    - -v host_path:container_path:permission(rw, ro, and when you use SELinux, you can use Z or z)
    - -e environment_value
    - -d: run background
    - image_name
- podman exec -it \[container_name\] \[command\]

#### Pod

Pod makes each container which are in the same pod share some specific resources. The network(IP address), storage volumes. However, each container has their own file system, process, and resource limits. So, this is very useful to use various containers which has close relationship like application and Redis(cache db).

- podman pod create
    - --name: pod's name
    - -p: host_ports:pod_ports
- podman run
    - ...
    - --pod pod's name
    > Don't use `-p` option. Pod already has `-p` option.

#### Container and file management

#### container

- check pure container

```bash
podman run --rm -it --entrypoint sh [image_name] --args
# or
podman run --rm -it [image_name] sh --args
```

#### file management

- Using `podman exec` to manage file
- Use ACL package `setfacl`
- `--cap-add=DAC_READ_SEARCH` option allows to read all file without permission to backup (for kopia)

### Quadlet and systemd

#### Register the secret on podman secret

- Using `edit_secret.sh` and `extract_secret.sh`
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

> ` podman secret inspect --showsecret --format '{{.SecretData}}' $secret_name` shows the content of secret


#### Define quadlet file

- File: 
	- ~/data/config/containers/app/app.container
	- ~/data/config/containers/app/app.pod

Quadlet is to define of specification as  `.quadlet` or `.container`. Quadlet uses these file to make `.service` file to combine container to systemd. Here is the example of `.container` file below.

```ini
# app.container
[Quadlet]
# Don't make a dependencies
DefaultDependencies=false

[Unit]
Description=app
After=a.service
Wants=a.service
Requires=a.service

[Service]
ExecStartPre=%h/data/config/scripts/wait-for-it.sh -h 192.168.10.1 -p 8080 -t 20

[Container]
# Pod=app.pod
Image=localhost/app:1.0.0

ContainerName=app

PublishPort=2080:80/tcp
PublishPort=2443:443/tcp

AddHost=app.service.internal:host-gateway

Volume=%h/data/containers/app:/home/app:rw

Environment="ENV1=ENV1"

Secret=ENV_NAME,type=env
Secret=app.file,target=/path/of/secret/file/name

# podman run [options] [image] example --config exconfig
Exec=example --config exconfig

# If you want to change Entrypoint itself, use
Entrypoint=sh -c 'command'

# For Diun
Label=diun.enable=true
# For Diun to track repository new version
Label=diun.watch_repo=true
# For Diun, and it needs `diun.yml` configuration
Label=diun.regopt=container-source


[Install]
WantedBy=default.target
```

```ini
# app.pod
[Quadlet]
# Don't make a dependencies
DefaultDependencies=false
[Pod]
Name=app

PublishPort=2080:80/tcp
```
#### Create systemd `.service` file

```bash
# linger has to be activated
mkdir -p ~/.config/containers/systemd

ln -s ~/data/config/containers/app/app.container ~/.config/containers/systemd/app.container 

# This command makes ~/.config/systemd/user/my-app.service
systemctl --user daemon-reload
```

#### Enable and start service

```bash
systemctl --user enable app.service
systemctl --user start app.service
```


---

## Following goal

### Health check

```ini
# i.e. caddy
# Podman [Container] section

[Container]
# Health check configuration 
# Health check command
HealthcheckCommand=curl -f http://localhost/ || exit 1
# Health check interval
HealthcheckInterval=30s
# the time to wait for health check
HealthcheckTimeout=5s
# the number to try to health check
HealthcheckRetries=3
# the time to wait to start first health check
HealthcheckStartPeriod=15s

# override.conf [Service] section
[Service]
# Restart, if it is not healthy
Restart=on-failure
```