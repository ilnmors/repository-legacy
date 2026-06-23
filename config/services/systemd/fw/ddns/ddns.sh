#!/bin/bash

## Change Log format as logfmt (refactoring)
# ddns.sh -d domain [-t <ttl>] [-p] [-r]

# Default Information
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
    echo "Usage: $0 -d \"domain\" [-t \"ttl\"] [-p] [-r]"
    echo "-d <domain>: Specify the domain to update"
    echo "-t <ttl>: Specify the TTL(Time to live)"
    echo "-p: Specify the cloudflare proxy to use"
    echo "-r: Delete the DNS record"
    exit 1
}

# Log function
log() {
    local timestamp
    local level="$1"
    local msg="$2"

    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "time=\"$timestamp\" level=\"$level\" msg=\"$msg\" source=\"ddns.sh\"" >&2
}

# getopts to get arguments
while getopts "d:t:pr" opt; do
    case "$opt" in
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
            log "error" "Invalid option: -$OPTARG"
            usage
            ;;
        :) # parameter required option
            log "error" "Option -$OPTARG requires an argument."
            usage
            ;;
    esac
done

# Get option and move to parameters - This has no functional thing, because it only use arguments with parameters
shift "$((OPTIND - 1))"

# Check necessary options
if [[ -z "$DOMAIN" ]]; then
    log "error" "-d option is required"
    usage
fi

if ! [[ "$TTL" =~ ^[0-9]+$ ]] || [[ "$TTL" -le 0 ]]; then
    log "error" "-t option (ttl) requires a number above 0."
    usage
fi

# Check necessary environment variables (Injected by systemd or shell)
if [[ -z "$ZONE_ID" ]]; then
    log "error" "ZONE_ID is required via environment variable."
    exit 1
fi

if [[ -z "$API_KEY" ]]; then
    log "error" "API_KEY is required via environment variable."
    exit 1
fi

# Check package
if ! command -v curl >/dev/null; then
    log "error" "curl is required"
    exit 1
fi

if ! command -v jq >/dev/null; then
    log "error" "jq is required"
    exit 1
fi

# API options
URL="https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records"
CONTENT_TYPE="Content-Type: application/json"
AUTHORIZATION="Authorization: Bearer $API_KEY"

# Current IP
CURRENT_IP="$(ip address show dev wan | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1)"

# Get current IP from external server when IP is private IP
if [[ -z "$CURRENT_IP" || "$CURRENT_IP" =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|127\.) ]]; then
    log "info" "IP from interface is private or empty. Fetching public IP..."
    CURRENT_IP="$(curl -sf "https://ifconfig.me")" || \
    CURRENT_IP="$(curl -sf "https://ifconfig.kr")" || \
    CURRENT_IP="$(curl -sf "https://api.ipify.org")"
fi

if [[ -z "$CURRENT_IP" ]]; then
    log "error" "Can't get an IP"
    exit 1
fi

# DNS functions

# build_dns_payload() function
build_dns_payload() {
    local type="$1"
    local name="$2"
    local ttl="$3"
    local comment="$4"
    local content="$5"

    jq -n \
        --arg name "$name" \
        --argjson ttl "$ttl" \
        --arg type "$type" \
        --arg comment "$comment" \
        --arg content "$content" \
        --argjson proxied "$PROXIED" \
        '{
            name: $name,
            ttl: $ttl,
            type: $type,
            comment: $comment,
            content: $content,
            proxied: $proxied
        }'
}

# get_dns_record() function
get_dns_record() {
    local type="$1"
    local name="$2"
    local response

    response="$(
        curl -s "$URL?type=$type&name=$name" \
            -H "$CONTENT_TYPE" \
            -H "$AUTHORIZATION"
    )"

    if [[ "$(jq -r '.success' <<< "$response")" == "false" ]]; then
        log "error" "Can't get dns record by $response"
        exit 1
    else
        # return
        echo "$response"
    fi
}

# create_dns_record() function
create_dns_record() {
    local type="$1"
    local name="$2"
    local ttl="$3"
    local comment="$4"
    local content="$5"
    local payload
    local response

    payload="$(build_dns_payload "$type" "$name" "$ttl" "$comment" "$content")"

    response="$(
        curl -s "$URL" \
            -X POST \
            -H "$CONTENT_TYPE" \
            -H "$AUTHORIZATION" \
            -d "$payload"
    )"

    if [[ "$(jq -r '.success' <<< "$response")" == "false" ]]; then
        log "error" "Can't create dns record by $response"
        exit 1
    else
        # return
        echo "$response"
    fi
}

# update_dns_record() function
update_dns_record() {
    local type="$1"
    local name="$2"
    local ttl="$3"
    local comment="$4"
    local content="$5"
    local id="$6"
    local payload
    local response

    payload="$(build_dns_payload "$type" "$name" "$ttl" "$comment" "$content")"

    response="$(
        curl -s "$URL/$id" \
            -X PUT \
            -H "$CONTENT_TYPE" \
            -H "$AUTHORIZATION" \
            -d "$payload"
    )"

    if [[ "$(jq -r '.success' <<< "$response")" == "false" ]]; then
        log "error" "Can't update dns record by $response"
        exit 1
    else
        # return
        echo "$response"
    fi
}

# delete_dns_record() function
delete_dns_record() {
    local type="$1"
    local id="$2"
    local response

    response="$(
        curl -s "$URL/$id" \
            -X DELETE \
            -H "$CONTENT_TYPE" \
            -H "$AUTHORIZATION"
    )"

    if [[ "$(jq -r '.success' <<< "$response")" == "false" ]]; then
        log "error" "Can't delete dns record by $response"
        exit 1
    else
        # return
        echo "$response"
    fi
}

# Get DNS A, and CNAME record
A_DNS_RECORD="$(get_dns_record "A" "$DOMAIN")"
S_DNS_RECORD="$(get_dns_record "CNAME" "*.$DOMAIN")"
W_DNS_RECORD="$(get_dns_record "CNAME" "www.$DOMAIN")"

# Delete DNS record with Delete flag
if [[ "$DELETE_FLAG" == "true" ]]; then
    FLAG="false"

    if [[ "$(jq -r '.result | length' <<< "$A_DNS_RECORD")" -eq 1 ]]; then
        A_DNS_ID="$(jq -r '.result[0].id' <<< "$A_DNS_RECORD")"
        delete_dns_record "A" "$A_DNS_ID"
        log "info" "root DNS record is deleted"
        FLAG="true"
    fi

    if [[ "$(jq -r '.result | length' <<< "$S_DNS_RECORD")" -eq 1 ]]; then
        S_DNS_ID="$(jq -r '.result[0].id' <<< "$S_DNS_RECORD")"
        delete_dns_record "CNAME" "$S_DNS_ID"
        log "info" "sub DNS record is deleted"
        FLAG="true"
    fi

    if [[ "$(jq -r '.result | length' <<< "$W_DNS_RECORD")" -eq 1 ]]; then
        W_DNS_ID="$(jq -r '.result[0].id' <<< "$W_DNS_RECORD")"
        delete_dns_record "CNAME" "$W_DNS_ID"
        log "info" "www DNS record is deleted"
        FLAG="true"
    fi

    if [[ "$FLAG" == "false" ]]; then
        log "info" "Nothing is Deleted. There are no DNS records"
    fi

    exit
fi

# Create or update DNS A record
if [[ "$(jq -r '.result | length' <<< "$A_DNS_RECORD")" -eq 1 ]]; then # root DNS record exist
    A_DNS_ID="$(jq -r '.result[0].id' <<< "$A_DNS_RECORD")"
    A_DNS_CONTENT="$(jq -r '.result[0].content' <<< "$A_DNS_RECORD")"
    A_DNS_TTL="$(jq -r '.result[0].ttl' <<< "$A_DNS_RECORD")"
    A_DNS_PROXIED="$(jq -r '.result[0].proxied' <<< "$A_DNS_RECORD")"

    if [[ "$A_DNS_CONTENT" != "$CURRENT_IP" || "$A_DNS_TTL" != "$TTL" || "$A_DNS_PROXIED" != "$PROXIED" ]]; then
        update_dns_record "A" "$DOMAIN" "$TTL" "$(date "+%Y-%m-%d %H:%M:%S"): root domain from ddns.sh" "$CURRENT_IP" "$A_DNS_ID"
        log "info" "Root DNS record is successfully changed Domain: $DOMAIN IP: $A_DNS_CONTENT to $CURRENT_IP TTL: $A_DNS_TTL to $TTL proxied: $A_DNS_PROXIED to $PROXIED"
    else
        log "info" "Root DNS record is not changed Domain: $DOMAIN IP: $CURRENT_IP TTL: $TTL proxied: $PROXIED"
    fi
else # root DNS record does not exist
    create_dns_record "A" "$DOMAIN" "$TTL" "$(date "+%Y-%m-%d %H:%M:%S"): root domain from ddns.sh" "$CURRENT_IP"
    log "info" "Root DNS record is successfully created Domain: $DOMAIN IP: $CURRENT_IP TTL: $TTL proxied: $PROXIED"
fi

# Create or update DNS CNAME records
if [[ "$(jq -r '.result | length' <<< "$S_DNS_RECORD")" -eq 1 ]]; then # sub DNS record exist
    S_DNS_ID="$(jq -r '.result[0].id' <<< "$S_DNS_RECORD")"
    S_DNS_CONTENT="$(jq -r '.result[0].content' <<< "$S_DNS_RECORD")"
    S_DNS_TTL="$(jq -r '.result[0].ttl' <<< "$S_DNS_RECORD")"
    S_DNS_PROXIED="$(jq -r '.result[0].proxied' <<< "$S_DNS_RECORD")"

    if [[ "$S_DNS_CONTENT" != "$DOMAIN" || "$S_DNS_TTL" != "$C_TTL" || "$S_DNS_PROXIED" != "$PROXIED" ]]; then
        update_dns_record "CNAME" "*.$DOMAIN" "$C_TTL" "$(date "+%Y-%m-%d %H:%M:%S"): sub domain from ddns.sh" "$DOMAIN" "$S_DNS_ID"
        log "info" "Sub DNS record is successfully changed Domain: $S_DNS_CONTENT to *.$DOMAIN CNAME: $DOMAIN  TTL: $S_DNS_TTL to $C_TTL proxied: $S_DNS_PROXIED to $PROXIED"
    else
        log "info" "Sub DNS record is not changed Domain: *.$DOMAIN CNAME: $DOMAIN TTL: $C_TTL proxied: $PROXIED"
    fi
else # sub DNS record does not exist
    create_dns_record "CNAME" "*.$DOMAIN" "$C_TTL" "$(date "+%Y-%m-%d %H:%M:%S"): sub domain from ddns.sh" "$DOMAIN"
    log "info" "Sub DNS record is successfully created Domain: *.$DOMAIN CNAME: $DOMAIN TTL: $C_TTL proxied: $PROXIED"
fi

if [[ "$(jq -r '.result | length' <<< "$W_DNS_RECORD")" -eq 1 ]]; then # www DNS record exist
    W_DNS_ID="$(jq -r '.result[0].id' <<< "$W_DNS_RECORD")"
    W_DNS_CONTENT="$(jq -r '.result[0].content' <<< "$W_DNS_RECORD")"
    W_DNS_TTL="$(jq -r '.result[0].ttl' <<< "$W_DNS_RECORD")"
    W_DNS_PROXIED="$(jq -r '.result[0].proxied' <<< "$W_DNS_RECORD")"

    if [[ "$W_DNS_CONTENT" != "$DOMAIN" || "$W_DNS_TTL" != "$C_TTL" || "$W_DNS_PROXIED" != "$PROXIED" ]]; then
        update_dns_record "CNAME" "www.$DOMAIN" "$C_TTL" "$(date "+%Y-%m-%d %H:%M:%S"): www domain from ddns.sh" "$DOMAIN" "$W_DNS_ID"
        log "info" "www DNS record is successfully changed Domain: $W_DNS_CONTENT to www.$DOMAIN CNAME: $DOMAIN TTL: $W_DNS_TTL to $C_TTL proxied: $W_DNS_PROXIED to $PROXIED"
    else
        log "info" "www DNS record is not changed Domain: www.$DOMAIN CNAME: $DOMAIN TTL: $C_TTL proxied: $PROXIED"
    fi
else # www DNS record does not exist
    create_dns_record "CNAME" "www.$DOMAIN" "$C_TTL" "$(date "+%Y-%m-%d %H:%M:%S"): www domain from ddns.sh" "$DOMAIN"
    log "info" "www DNS record is successfully created Domain: www.$DOMAIN CNAME: $DOMAIN TTL: $C_TTL proxied: $PROXIED"
fi
