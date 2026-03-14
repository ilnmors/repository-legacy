# systemd-quadlet

Quadlet is for defining container configuration and lifecycle combining systemd and podman.

## Rootless container

Containers should be isolated from host OS. However, docker runs with root permission on daemon \(dockerd\). This means when one docker container has vulnerability and it is taken over, all the host system authority is threatened. Rootless container, podman runs without root permission and daemon so that even if one of containers is taken over, prevent the damage in host's normal user authority.

Rootless container maps UID/GID between host and its own following namespace. Host's user UID/GID is mapped with container's root, and host's subuid/subgid defined on `/etc/subuid`, `/etc/subgid` is mapped with container's user UID/GID by default.

- Default `/etc/subuid` and `/etc/subgid`
  - user:100000:65536
  - host user 1000 > container root 0
  - host subuid 100999 > containers 1000

Rootless services originally depends on session. It is necessary to set `linger` to guarantee the service health regardless the session.

- sudo loginctl enable-linger user
  - ls /var/lib/systemd/linger/user

## Quadlet

Quadlet defines specification of container in `.container` file and generates `.service` automatically for systemd. systemd can manage the container like its own service with `systemctl` command.

```ini
# $HOME/.config/containers/systemd/a.container
[Quadlet]
# Don't make a dependencies
DefaultDependencies=false

[Unit]
Description=app
After=network-online.target
Wants=network-online.target
BindsTo=a.service
Requires=a.service

[Service]
ExecStartPre=/bin/sh -c 'echo "Waiting for infra-postgresql..."; until nc -z postgresql.ilnmors.internal 5432; do sleep 1; done;'

[Container]
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

[Install]
# Guarantee auto start
WantedBy=default.target
```
