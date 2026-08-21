#!/bin/bash

set -Eeuo pipefail

URL=""
ORG_ID=""
TOKEN=""
apply=false

page_size=100
page_index=0
documents_read=0
matched=0
unmatched=0
updated=0
failed=0

# usage() function
usage() {
    echo "Usage: $0 -u \"URL\" -o \"ORG_ID\" -t \"TOKEN\" [-a]"
    echo "-u <URL>: Specify the URL of Papra, including https://"
    echo "-o <ORG_ID>: Specify the organization ID of Papra"
    echo "-t <TOKEN>: Specify the token to access the Papra API"
    echo "-a: Apply changes. Without this option, only perform a dry run"
    echo "Token requires documents:read and documents:update permissions"
    exit 1
}

# Log function
log() {
    local timestamp
    local level="$1"
    local msg="$2"

    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "time=\"$timestamp\" level=\"$level\" msg=\"$msg\" source=\"papra-date-change.sh\"" >&2
}

# getopts to get arguments
while getopts ":u:o:t:ah" opt; do
    case "$opt" in
        u)
            URL="$OPTARG"
            ;;
        o)
            ORG_ID="$OPTARG"
            ;;
        t)
            TOKEN="$OPTARG"
            ;;
        a)
            apply=true
            ;;
        h)
            usage
            ;;
        \?) # unknown option
            log "error" "Invalid option: -$OPTARG"
            usage
            ;;
        :) # parameter required
            log "error" "Option -$OPTARG requires an argument"
            usage
            ;;
    esac
done

# Validate required arguments
if [[ -z "$URL" || -z "$ORG_ID" || -z "$TOKEN" ]]; then
    log "error" "URL, ORG_ID and TOKEN are required"
    usage
fi

# Require an explicit HTTPS URL
if [[ "$URL" != https://* ]]; then
    log "error" "URL must start with https://"
    exit 1
fi

# Remove trailing slash
URL="${URL%/}"

# Collect all documents before modifying them.
# This prevents pagination results from changing during updates.
documents_file="$(mktemp)"
trap 'rm -f -- "$documents_file"' EXIT

while true; do
    response="$(
        curl \
            --fail \
            --silent \
            --show-error \
            --get \
            --header "Authorization: Bearer $TOKEN" \
            --data-urlencode "pageIndex=$page_index" \
            --data-urlencode "pageSize=$page_size" \
            --data-urlencode "sortField=createdAt" \
            --data-urlencode "sortOrder=asc" \
            "$URL/api/organizations/$ORG_ID/documents"
    )"

    count="$(jq -r '.documents | length' <<<"$response")"
    total="$(jq -r '.documentsCount' <<<"$response")"

    jq -c '.documents[]' <<<"$response" >>"$documents_file"

    documents_read=$((documents_read + count))

    if (( count == 0 || documents_read >= total )); then
        break
    fi

    page_index=$((page_index + 1))
done

log "info" "Documents read: $documents_read"

while IFS= read -r document; do
    id="$(jq -r '.id' <<<"$document")"
    name="$(jq -r '.name // empty' <<<"$document")"

    if [[ -z "$id" || -z "$name" ]]; then
        unmatched=$((unmatched + 1))
        log "warning" "Skipped document with missing ID or name"
        continue
    fi

    # Extract the first _YYYY.MM.DD_ pattern.
    if [[ "$name" =~ (^|_)([0-9]{4})\.([0-9]{2})\.([0-9]{2})(_|$) ]]; then
        year="${BASH_REMATCH[2]}"
        month="${BASH_REMATCH[3]}"
        day="${BASH_REMATCH[4]}"
        document_date="$year-$month-$day"
    else
        unmatched=$((unmatched + 1))
        printf '[SKIP] %s: date pattern not found\n' "$name"
        continue
    fi

    # Reject impossible dates such as 2026.02.30.
    parsed_date="$(
        date \
            --utc \
            --date="$document_date" \
            +"%Y-%m-%d" \
            2>/dev/null ||
            true
    )"

    if [[ "$parsed_date" != "$document_date" ]]; then
        unmatched=$((unmatched + 1))
        printf '[SKIP] %s: invalid date %s\n' \
            "$name" \
            "$document_date"
        continue
    fi

    matched=$((matched + 1))

    if [[ "$apply" != true ]]; then
        printf '[DRY-RUN] %s -> %s\n' \
            "$name" \
            "$document_date"
        continue
    fi

    payload="$(
        jq \
            --null-input \
            --compact-output \
            --arg documentDate "$document_date" \
            '{documentDate: $documentDate}'
    )"

    if ! curl \
        --fail \
        --silent \
        --show-error \
        --request PATCH \
        --header "Authorization: Bearer $TOKEN" \
        --header "Content-Type: application/json" \
        --data "$payload" \
        --output /dev/null \
        "$URL/api/organizations/$ORG_ID/documents/$id"
    then
        failed=$((failed + 1))
        log "error" "Failed to update document: $id ($name)"
        continue
    fi

    updated=$((updated + 1))

    printf '[%d/%d] %s -> %s\n' \
        "$updated" \
        "$matched" \
        "$name" \
        "$document_date"
done <"$documents_file"

if [[ "$apply" == true ]]; then
    log "info" "Update completed: read=$documents_read matched=$matched unmatched=$unmatched updated=$updated failed=$failed"
else
    log "info" "Dry run completed: read=$documents_read matched=$matched unmatched=$unmatched"
    log "info" "No documents were modified. Run again with -a to apply"
fi

if (( failed > 0 )); then
    exit 1
fi
