#!/bin/bash
# extract_secret.sh /path/of/secret/secret.yaml [-n] (-f|-e <value>)

set -e

# Varibles
KEY_PATH="$HOME/workspace/homelab/config/secrets"
TMP_PATH="/run/user/$UID"
SECRET_FILE="$1"
VALUE=""
TYPE=""
NEWLINE="true"

# Remove $1 and shift $(n-1) < $n
shift

# Usage function

usage () {
    echo "Usage: $0 \"/path/of/secret/secret.yaml\" [-n] (-f|-e \"yaml section name\")"
    echo "-n: remove the newline"
    echo "-f <type name>: Print secret file"
    echo "-e <type name>: Print secret env file"
    exit 1
}

# Log function
log() {
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local level="$1"
    local msg="$2"
    echo "time=\"$timestamp\" level=\"$level\" msg=\"$msg\" source=\"extract_secret.sh\"">&2
}

# getops to get parameters
while getopts "f:e:n" opt; do
    case $opt in
        f)
            VALUE="$OPTARG"
            TYPE="FILE"
            ;;
        e)
            VALUE="$OPTARG"
            TYPE="ENV"
            ;;
        n)
            NEWLINE="false"
            ;;
        \?)
            log "error" "Invalid option: -$OPTARG"
            usage
            ;;
        :)
            log "error" "Option -$OPTARG requires an argument"
            usage
            ;;
    esac
done

# Secret file check
if [ -z "$SECRET_FILE" -o ! -f "$SECRET_FILE" ]; then
    log "error" "Secret file path is required"
    usage
    exit 1
fi

# -f or -e option check
if [ -z "$TYPE" ]; then
    log "error" "-f or -e option requires"
    usage
    exit 1
fi

# age-key file check
if [ ! -f "$KEY_PATH/age-key.gpg" ]; then
    log "error" "Key file is required: $KEY_PATH/age-key.gpg"
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
        log "info" "age-key was deleted"
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
    log "error" "age key file does not exist"
    exit 1
fi

# Kill the gpg session value
gpgconf --kill gpg-agent

if [ "$TYPE" == "FILE" ]; then
    if RESULT=$(SOPS_AGE_KEY_FILE="$TMP_PATH/age-key" sops --decrypt --extract "[\"$VALUE\"]" --output-type binary "$SECRET_FILE") ; then
        if [ "$NEWLINE" == "true" ]; then
            echo "$RESULT"
        else
            echo -n "$RESULT"
        fi
        exit 0
    else
        log "error" "SOPS extract error"
        exit 1
    fi
fi

if [ "$TYPE" == "ENV" ]; then
    if RESULT=$(SOPS_AGE_KEY_FILE="$TMP_PATH/age-key" sops --decrypt --extract "[\"$VALUE\"]" --output-type dotenv "$SECRET_FILE") ; then
        if [ "$NEWLINE" == "true" ]; then
            echo "$RESULT"
        else
            echo -n "$RESULT"
        fi
        exit 0
    else
        log "error" "SOPS extract error"
        exit 1
    fi
fi
