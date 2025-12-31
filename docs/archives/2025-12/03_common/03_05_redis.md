Tags: #os, #configuration, #virtualization, #container, #database, #cache

## Redis

Redis is the cache database. It doesn't use SQL, it is just key-value data storage.

### Redis in Pod

Redis is combined with master services in the pod. It allows master services and Redis can communication in localhost. It doesn't need TLS, password, or even ACL itself.

There is the list of services which use Redis in Pod.
#### Preperation

##### Create directory for container

```bash
mkdir -p ~/data/containers/app/redis
setfacl -m d:g::0 ~/data/containers/app/redis
setfacl -m d:o::0 ~/data/containers/app/redis
setfacl -m u:
$UID:rwx ~/data/containers/app/redis
setfacl -m u:100998:rwx ~/data/containers/app/redis
setfacl -d -m u:$UID:rwx ~/data/containers/app/redis
setfacl -d -m u:100998:rwx ~/data/containers/app/redis
```

>Redis container executes as 999:999(redis:redis) permission in container. It is mapped host's 100998. Therefore, directories have to have ACL via `setfacl`

### Podman Image

```bash
podman pull redis:8.2.2 # Do not use latest version to management
```

### Quadlet

- File: 
	- ~/data/config/containers/app/app.pod
	- ~/data/config/containers/app/app-redis.container
	- ~/data/config/containers/app/app.container

```ini
# ~/data/config/containers/app/app.pod
[Quadlet]
DefaultDependencies=false

[Pod]
PodName=app

# web port
PublishPort=9080:9000/tcp
# LDAP port
#PublishPort=[set_port]:3389
# Prometheus Port
#PublishPort=[set_port]:9300
```

```ini
# ~/data/config/containers/app/app-redis.container

[Quadlet]
DefaultDependencies=false

[Unit]
Description=app - redis
Before=app.service

[Container]
Pod=app.pod

Image=redis:8.2.2

ContainerName=app-redis

# Port 6379

Volume=%h/data/containers/app/redis:/data:rw

Environment="TZ=Asia/Seoul"

[Install]
WantedBy=default.target
```

```ini
# ~/data/config/containers/app/app.container
[Quadlet]
DefaultDependencies=false

[Unit]
Description=app

After=app-redis.service
Requires=app-redis.service

[Container]
Pod=app.pod

Image=app:version

Volume=%h/data/containers/app/app:/data:rw

Environment="TZ=Asia/Seoul"

[Install]
WantedBy=default.target
```