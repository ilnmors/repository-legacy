Tags: #os, #configuration, #network

## DDNS

### Secret management

- File: 
	- ~/data/config/secrets/.secret.yaml
	- /etc/secrets/2001/ddns.env

- Edit `.secret.yaml` with `edit_secret.sh`

```yaml
# ~/data/config/secrets/.secret.yaml
# DDNS
DDNS:
  ZONE_ID: 'encrypted value'
  API_KEY: 'encrypted value'
```

```bash
extract_secret.sh ~/data/config/secrets/.secret.yaml -e "DDNS" > /run/user/$UID/tmp.env && sudo mv /run/user/$UID/tmp.env /etc/secrets/$UID/ddns.env && sudo chown $UID:root /etc/secrets/$UID/ddns.env && sudo chmod 400 /etc/secrets/$UID/ddns.env
```

### ddns.sh

- File: ~/data/config/scripts/ddns/ddns.sh

```bash
#!/bin/bash
# ~/data/config/scripts/ddns.sh

# Designate directory
# DIRECTORY="$HOME/data/config/scripts"

# Information
DOMAIN=""
TTL=180
C_TTL=86400
PROXIED="false"
DELETE_FLAG="false"
CURRENT_IP=""

# These will be injected by systemd
# ZONE_ID='.secret'
# API_KEY='.secret'

# usage() function
usage() {
        echo "Usage: $0 -d \"domain\" [-t \"ttl\"] [-p] [-r] [-c]"
        echo "-d <domain>: Specify the domain to update"
        echo "-t <ttl>: Specify the TTL(Time to live)"
        echo "-p: Specify the cloudflare proxy to use"
        echo "-r: Delete the DNS record"
        exit 1
}

# getopts to get arguments
while getopts "d:t:pr" opt; do
    case $opt in
        d)
            DOMAIN="$OPTARG"
            ;;
        t)
            TTL="$OPTARG"
            ;;
        p)
            PROXIED="true"
            ;;
        r)
            DELETE_FLAG="true"
            ;;
        \?) # unknown options
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
        :) # parameter required option
            echo "Option -$OPTARG requires an argument." >&2
            usage
            ;;
    esac
done

# Get option and move to parameters - This has no functional thing, because it only use arguments with parameters
shift $((OPTIND - 1))

# Check necessary options
if [ -z "$DOMAIN" ]; then
    echo "Error: -d option is required" >&2
    usage
fi

if ! [[ "$TTL" =~ ^[0-9]+$ ]] || [ "$TTL" -le 0 ]; then
    echo "Error: -t option (ttl) requires a number above 0." >&2
    usage
fi

# log() function
log()
{
    local text="$1"
    echo -e "$(date "+%Y-%m-%d %H:%M:%S"): [ddns] $text"
}

# Make log directory
# if [ ! -d "$DIRECTORY/log" ]; then
#    mkdir "$DIRECTORY/log"
# fi

# Check and create log file
# LOG_FILE="$DIRECTORY/log/ddns_$(date "+%Y-%m-%d").log"
# if [ ! -f "$LOG_FILE" ]; then
#    log "Notice: log file is created"
# fi

# Check package
if ! command -v curl &> /dev/null; then
    log "Error: curl package is needed"
    exit
fi
if ! command -v jq &> /dev/null; then
    log "Error: jq package is needed"
    exit
fi

# API options
URL="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"
CONTENT_TYPE="Content-Type: application/json"
AUTHORIZATION="Authorization: Bearer $API_KEY"

# Current IP check
CURRENT_IP=$(curl -sf "https://ifconfig.me") ||\
CURRENT_IP=$(curl -sf "https://ifconfig.kr") ||\
CURRENT_IP=$(curl -sf "https://api.ipify.org")
if [ "$CURRENT_IP" == "" ]; then
    log "Error: Can't get an IP"
    exit
fi

# DNS functions

# get_dns_record() function
get_dns_record()
{
    local type="$1"
    local name="$2"

    local response="$(
        curl -s "$URL?type=$type&name=$name"\
            -H "$CONTENT_TYPE"\
            -H "$AUTHORIZATION")"
    if [ "$(echo "$response" | jq -r '.success')" == "false" ]; then
        log "Error: Can't get dns record\"Reason: $response"
        exit
    else
        echo "$response"
    fi
}

# create_dns_record() function
create_dns_record()
{
    local type="$1"
    local name="$2"
    local ttl="$3"
    local comment="$4"
    local content="$5"
    local response="$(
        curl -s "$URL"\
            -X POST\
            -H "$CONTENT_TYPE"\
            -H "$AUTHORIZATION"\
            -d "{
            \"name\": \"$name\",
            \"ttl\": $ttl,
            \"type\": \"$type\",
            \"comment\": \"$comment\",
            \"content\": \"$content\",
            \"proxied\": $PROXIED
            }")"
    if [ "$(echo "$response" | jq -r '.success')" == "false" ]; then
        log "Error: Can't create dns record\"Reason: $response"
        exit
    else
        echo "$response"
    fi
}

# update_dns_record() function
update_dns_record()
{
    local type="$1"
    local name="$2"
    local ttl="$3"
    local comment="$4"
    local content="$5"
    local id="$6"
    local response=$(
        curl -s "$URL/$id"\
            -X PUT\
            -H "$CONTENT_TYPE"\
            -H "$AUTHORIZATION"\
            -d "{
            \"name\": \"$name\",
            \"ttl\": $ttl,
            \"type\": \"$type\",
            \"comment\": \"$comment\",
            \"content\": \"$content\",
            \"proxied\": $PROXIED
            }")
    if [ "$(echo "$response" | jq -r '.success')" == "false" ]; then
        log "Error: Can't update dns record\"Reason: $response"
        exit
    else
        echo "$response"
    fi
}

# delete_dns_record() function
delete_dns_record()
{
    local type="$1"
    local id="$2"

    local response=$(
        curl -s "$URL/$id"\
            -X DELETE\
            -H "$CONTENT_TYPE"\
            -H "$AUTHORIZATION"
    )
    if [ "$(echo "$response" | jq -r '.success')" == "false" ]; then
        log "Error: Can't delete dns record\"Reason: $response"
        exit
    else
        echo "$response"
    fi
}

# Get DNS A, and CNAME record
A_DNS_RECORD=$(get_dns_record "A" "$DOMAIN")
S_DNS_RECORD=$(get_dns_record "cname" "*.$DOMAIN")
W_DNS_RECORD=$(get_dns_record "cname" "www.$DOMAIN")

# Delete DNS record with Delete flag
if [ "$DELETE_FLAG" == "true" ]; then
    FLAG="false"
    if [ "$(echo $A_DNS_RECORD | jq -r '.result | length')" -eq 1 ]; then
        A_DNS_ID="$(echo $A_DNS_RECORD | jq -r '.result[0].id')"
        delete_dns_record "A" "$A_DNS_ID"
        log "Delete: root DNS record is deleted"
        FLAG="true"
    fi
    if [ "$(echo $S_DNS_RECORD | jq -r '.result | length')" -eq 1 ]; then
        S_DNS_ID="$(echo $S_DNS_RECORD | jq -r '.result[0].id')"
        delete_dns_record "cname" "$S_DNS_ID"
        log "Delete: sub DNS record is deleted"
        FLAG="true"
    fi
    if [ "$(echo $W_DNS_RECORD | jq -r '.result | length')" -eq 1 ]; then
        W_DNS_ID="$(echo $W_DNS_RECORD | jq -r '.result[0].id')"
        delete_dns_record "cname" "$W_DNS_ID"
        log "Delete: www DNS record is deleted"
        FLAG="true"
    fi
    if [ "$FLAG" == "false" ]; then
        log "Notice: Nothing is Deleted. There are no DNS records"
    fi
    exit
fi

# Create or update DNS A record
if [ "$(echo $A_DNS_RECORD | jq -r '.result | length')" -eq 1 ]; then # root DNS record exist
    A_DNS_ID="$(echo $A_DNS_RECORD | jq -r '.result[0].id')"
    A_DNS_CONTENT="$(echo $A_DNS_RECORD | jq -r '.result[0].content')"
    A_DNS_TTL="$(echo $A_DNS_RECORD | jq -r '.result[0].ttl')"
    A_DNS_PROXIED="$(echo $A_DNS_RECORD | jq -r '.result[0].proxied')"
    if [ "$A_DNS_CONTENT" != $CURRENT_IP -o "$A_DNS_TTL" != "$TTL" -o "$A_DNS_PROXIED" != "$PROXIED" ]; then
        update_dns_record "A" "$DOMAIN" "$TTL" "$(date "+%Y-%m-%d %H:%M:%S"): root domain from ddns.sh" "$CURRENT_IP" "$A_DNS_ID"
        log "Update: Root DNS record is successfully changed\nDomain: $DOMAIN\nIP: $A_DNS_CONTENT to $CURRENT_IP\nTTL: $A_DNS_TTL to $TTL\nproxied: $A_DNS_PROXIED to $PROXIED"
    else
        log "Notice: Root DNS record is not changed\nDomain: $DOMAIN\nIP: $CURRENT_IP\nTTL: $TTL\nproxied: $PROXIED"
    fi
else # root DNS record does not exist
    create_dns_record "A" "$DOMAIN" "$TTL" "$(date "+%Y-%m-%d %H:%M:%S"): root domain from ddns.sh" "$CURRENT_IP"
    log "Create: Root DNS record is successfully created\nDomain: $DOMAIN\nIP: $CURRENT_IP\nTTL: $TTL\nproxied: $PROXIED"
fi

# Create or update DNS CNAME records
if [ "$(echo $S_DNS_RECORD | jq -r '.result | length')" -eq 1 ]; then # sub DNS record exist
    S_DNS_ID="$(echo $S_DNS_RECORD | jq -r '.result[0].id')"
    S_DNS_CONTENT="$(echo $S_DNS_RECORD | jq -r '.result[0].content')"
    S_DNS_TTL="$(echo $S_DNS_RECORD | jq -r '.result[0].ttl')"
    S_DNS_PROXIED="$(echo $S_DNS_RECORD | jq -r '.result[0].proxied')"
    if [ "$S_DNS_CONTENT" != "$DOMAIN" -o "$S_DNS_TTL" != "$C_TTL" -o "$S_DNS_PROXIED" != "$PROXIED" ]; then
        update_dns_record "cname" "*.$DOMAIN" "$C_TTL" "$(date "+%Y-%m-%d %H:%M:%S"): sub domain from ddns.sh" "$DOMAIN" "$S_DNS_ID"
        log "Update: Sub DNS record is successfully changed\nDomain: $S_DNS_CONTENT to *.$DOMAIN\ncname: $DOMAIN \nTTL: $S_DNS_TTL to $C_TTL\nproxied: $S_DNS_PROXIED to $PROXIED"
    else
        log "Notice: Sub DNS record is not changed\nDomain: *.$DOMAIN\ncname: $DOMAIN\nTTL: $C_TTL\nproxied: $PROXIED"
    fi
else # sub DNS record does not exist
    create_dns_record "cname" "*.$DOMAIN" "$C_TTL" "$(date "+%Y-%m-%d %H:%M:%S"): sub domain from ddns.sh" "$DOMAIN"
    log "Create: Sub DNS record is successfully created\nDomain: *.$DOMAIN\ncname: $DOMAIN\nTTL: $C_TTL\nproxied: $PROXIED"
fi

if [ "$(echo $W_DNS_RECORD | jq -r '.result | length')" -eq 1 ]; then # www DNS record exist
    W_DNS_ID="$(echo $W_DNS_RECORD | jq -r '.result[0].id')"
    W_DNS_CONTENT="$(echo $W_DNS_RECORD | jq -r '.result[0].content')"
    W_DNS_TTL="$(echo $W_DNS_RECORD | jq -r '.result[0].ttl')"
    W_DNS_PROXIED="$(echo $W_DNS_RECORD | jq -r '.result[0].proxied')"
    if [ "$W_DNS_CONTENT" != "$DOMAIN" -o "$W_DNS_TTL" != "$C_TTL" -o "$W_DNS_PROXIED" != "$PROXIED" ]; then
        update_dns_record "cname" "www.$DOMAIN" "$C_TTL" "$(date "+%Y-%m-%d %H:%M:%S"): www domain from ddns.sh" "$DOMAIN" "$W_DNS_ID"
        log "Update: www DNS record is successfully changed\nDomain: $W_DNS_CONTENT to www.$DOMAIN\ncname: $DOMAIN\nTTL: $W_DNS_TTL to $C_TTL\nproxied: $W_DNS_PROXIED to $PROXIED"
    else
        log "Notice: www DNS record is not changed\nDomain: www.$DOMAIN\ncname: $DOMAIN\nTTL: $C_TTL\nproxied: $PROXIED"
    fi
else # www DNS record does not exist
    create_dns_record "cname" "www.$DOMAIN" "$C_TTL" "$(date "+%Y-%m-%d %H:%M:%S"): www domain from ddns.sh" "$DOMAIN"
    log "Create: www DNS record is successfully created\nDomain: www.$DOMAIN\ncname: $DOMAIN\nTTL: $C_TTL\nproxied: $PROXIED"
fi

# Remove old backup file (7days before)
# find "$DIRECTORY/log" -maxdepth 1 -type f -mtime +7 -delete
```

### Systemd

- File:
	- ~/data/config/services/ddns/ddns.service
	- ~/data/config/services/ddns/ddns.timer
	- /etc/secrets/2001/ddns.env

```ini
# ~/data/config/services/ddns/ddns.service
# ~/.config/systemd/user/ddns.service
[Unit]
Description=DDNS Update Service
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot

# logging
StandardOutput=journal
StandardError=journal

# EnvironmentFile
EnvironmentFile=/etc/secrets/%U/ddns.env

# Run the script
ExecStart=/bin/bash -c '%h/data/config/scripts/ddns/ddns.sh -d "ilnmors.com"'

```

```ini
# ~/data/config/services/ddns/ddns.timer
# ~/.config/systemd/user/ddns.timer
[Unit]
Description=Run DDNS update service every 5 minutes

[Timer]
# Execute service after 1 min on booting
OnBootSec=1min

# Execute service every 5mins
OnUnitActiveSec=5min

# When timer is activated, Service also starts.
Persistent=true

[Install]
WantedBy=timers.target
```

```bash
# Register service 
mkdir -p ~/.config/systemd/user && chmod -R 700 ~/.config

ln -s ~/data/config/services/ddns/ddns.service ~/.config/systemd/user/ddns.service

ln -s ~/data/config/services/ddns/ddns.timer ~/.config/systemd/user/ddns.timer

systemctl --user daemon-reload 

# Start timer and enable
systemctl --user enable --now ddns.timer
```