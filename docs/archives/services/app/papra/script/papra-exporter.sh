#!/bin/bash

set -Eeuo pipefail

URL=""
ORG_ID=""
TOKEN=""

output_dir="$PWD/papra-export"
page_size=100
page_index=0
downloaded=0

# usage() function
usage() {
    echo "Usage: $0 -u \"URL\" -o \"ORG_ID\" -t \"TOKEN\""
    echo "-u <URL>: Specify the URL of Papra, including https://"
    echo "-o <ORG_ID>: Specify the organization ID of Papra"
    echo "-t <TOKEN>: Specify the token to access the Papra API"
    echo "Token requires READ permissions"
    exit 1
}

# Log function
log() {
    local timestamp
    local level="$1"
    local msg="$2"

    timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    echo "time=\"$timestamp\" level=\"$level\" msg=\"$msg\" source=\"papra-exporter.sh\"" >&2
}

# getopts to get arguments
while getopts ":u:o:t:" opt; do
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

# Always create a fresh export
rm -rf -- "$output_dir"
mkdir -p -- "$output_dir"

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
            "$URL/api/organizations/$ORG_ID/documents"
    )"

    count="$(jq -r '.documents | length' <<<"$response")"
    total="$(jq -r '.documentsCount' <<<"$response")"

    while IFS= read -r document; do
        id="$(jq -r '.id' <<<"$document")"
        name="$(jq -r '.name // empty' <<<"$document")"

        # Prevent document names from creating subdirectories.
        name="${name//\//_}"

        if [[ -z "$name" || "$name" == "." || "$name" == ".." ]]; then
            name="$id"
        fi

        destination="$output_dir/$name"

        # Preserve both files when names collide.
        if [[ -e "$destination" ]]; then
            if [[ "$name" == *.* && "$name" != .* ]]; then
                stem="${name%.*}"
                extension=".${name##*.}"
                destination="$output_dir/${stem}__${id}${extension}"
            else
                destination="$output_dir/${name}__${id}"
            fi
        fi

        temporary="${destination}.part"
        rm -f -- "$temporary"

        if ! curl \
            --fail \
            --silent \
            --show-error \
            --location \
            --header "Authorization: Bearer $TOKEN" \
            --output "$temporary" \
            "$URL/api/organizations/$ORG_ID/documents/$id/file"
        then
            rm -f -- "$temporary"
            log "error" "Failed to download document: $id"
            exit 1
        fi

        mv -f -- "$temporary" "$destination"

        downloaded=$((downloaded + 1))

        printf '[%d/%d] %s\n' \
            "$downloaded" \
            "$total" \
            "${destination#"$output_dir"/}"

    done < <(jq -c '.documents[]' <<<"$response")

    if (( count == 0 || downloaded >= total )); then
        break
    fi

    page_index=$((page_index + 1))
done

log "info" "Export completed: $downloaded document(s)"
