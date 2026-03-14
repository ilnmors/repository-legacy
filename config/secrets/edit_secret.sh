#!/bin/bash
# edit_secret.sh /path/of/secret/secret.yaml

set -e

# Varibles
KEY_PATH="$HOME/workspace/homelab/config/secrets"
TMP_PATH="/run/user/$UID"
SECRET_FILE="$1"

# Usage function
usage() {
    echo "Usage: $0 \"/path/of/secret/secret.yaml\"" >&2
    exit 1
}

# Log function
log() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local level="$1"
    local msg="$2"
    echo "time=\"$timestamp\" level=\"$level\" msg=\"$msg\" source=\"edit_secret.sh\"">&2
}

# Secret file check
if [ -z "$SECRET_FILE" -o ! -f "$SECRET_FILE" ]; then
    log "error" "Secret file path is required"
    usage
    exit 1
fi

# age-key file check
if [ ! -f "$KEY_PATH/age-key.gpg" ]; then
    log "error" "age key path is required"
    exit 1
fi

# Dependency check
if ! command -v sops >/dev/null; then
    log "error" "sops is required"
    exit 1
fi

if ! command -v gpg >/dev/null; then
    log "error" "gnupg is required"
    exit 1
fi

# Cleanup function for trap
cleanup() {
    if [ -f "$TMP_PATH/age-key" ]; then
        rm -f "$TMP_PATH/age-key"
        log "info" "age key is deleted"
    fi
}

# Trap
trap cleanup EXIT

# Get GPG password from prompt
echo -n "Enter GPG passphrase: " >&2
read -s GPG_PASSPHRASE
echo "" >&2

# Decrypt age-key on the tmpfs (memory)
echo "$GPG_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \
--output "$TMP_PATH/age-key" \
--decrypt "$KEY_PATH/age-key.gpg" &&\
chmod 600 "$TMP_PATH/age-key"

# Unset environment varibles
unset GPG_PASSPHRASE

# Check the key on memory
if [ ! -f "$TMP_PATH/age-key" ]; then
    log "error" "age key does not exist"
    exit 1
fi

# Kill the gpg session value
gpgconf --kill gpg-agent

# Open sops editor and delete the key
SOPS_AGE_KEY_FILE="$TMP_PATH/age-key" sops "$SECRET_FILE"

exit 0
