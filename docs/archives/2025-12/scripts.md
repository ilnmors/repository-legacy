```bash
#!/bin/bash

# edit_secret.sh /path/of/secret

  

set -e

  

KEY_PATH="$HOME/workspace/homelab/data/secrets"

TMP_PATH="/run/user/$UID"

SECRET_FILE="$1"

  

# Usage function

usage() {

    echo "Usage: $0 \"/path/of/secret/file\"" >&2

    exit 1

}

  

# log function

log()

{

    local text="$1"

    echo -e "$(date "+%Y-%m-%d %H:%M:%S"): [edit_script] $text" >&2

}

  

# Secret file check

if [ -z "$SECRET_FILE" -o ! -f "$SECRET_FILE" ]; then

    log "Error: Secret file path is needed"

    usage

fi

  

# age-key file check

if [ ! -f "$KEY_PATH/age-key.gpg" ]; then

    log "Error: There is no key file"

    exit 1

fi

  

# Dependency check

if ! command -v sops >/dev/null; then

    log "Error: sops package is needed"

    exit

fi

  

if ! command -v gpg >/dev/null; then

    log "Error: gnupg package is needed"

    exit

fi

  
  

# Delete password file after script certainly

cleanup() {

    if [ -f "$TMP_PATH/age-key" ]; then

        log "Notice: age-key was deleted"

        rm -f "$TMP_PATH/age-key"

    fi

}

  

trap cleanup EXIT

  
  

# Get GPG password from prompt

echo -n "Enter GPG passphrase: " >&2

read -s GPG_PASSPHRASE

echo "" >&2

  

# Decrypt age-key on memory

echo "$GPG_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \

--output "$TMP_PATH/age-key" \

--decrypt "$KEY_PATH/age-key.gpg" && \

chmod 600 "$TMP_PATH/age-key"

  

unset GPG_PASSPHRASE

  

# Check the decrypted key on memory

if [ ! -f "$TMP_PATH/age-key" ]; then

        log "Error: Decrypted key file does not exist"

        exit 1

fi

  

# kill the gpg session

gpgconf --kill gpg-agent

  

# Open sops editor

SOPS_AGE_KEY_FILE="$TMP_PATH/age-key" sops "$SECRET_FILE"

rm -f "$TMP_PATH/age-key" >&2

  

exit 0
```

```bash
#!/bin/bash

# extract_secret.sh /path/of/secret [-n] (-f|-e <value>)

  

set -e

  

KEY_PATH="$HOME/workspace/homelab/data/secrets"

TMP_PATH="/run/user/$UID"

SECRET_FILE=$1

VALUE=""

TYPE=""

NEWLINE="true"

  

# Remove $1 and shift $(n-1) < $n

shift

  

# usage() function

usage() {

        echo "Usage: $0 \"/path/of/secret/file\" [-n] (-f|-e \"yaml section name\")" >&2

        echo "-n: remove the newline" >&2

        echo "-f <type name>: Print secret file" >&2

        echo "-e <type name>: Print secret env file" >&2

        exit 1

}

  

# log() function

log()

{

    local text="$1"

    echo -e "$(date "+%Y-%m-%d %H:%M:%S"): [extract_script] $text" >&2

}

  

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

        \?) # unknown options

            log "Invalid option: -$OPTARG"

            usage

            ;;

        :) # parameter required option

            log "Option -$OPTARG requires an argument."

            usage

            ;;

    esac

done

  

# Get option and move to parameters

shift $((OPTIND - 1))

  

# Check necessary options

if [ -z "$SECRET_FILE" -o ! -f "$SECRET_FILE" ]; then

    log "Error: secret file path is required"

    usage

fi

  

if [ -z "$TYPE" ]; then

        log "Error: -f or -e option requires"

        usage

fi

  

# age-key file check

if [ ! -f "$KEY_PATH/age-key.gpg" ]; then

    log "Error: There is no key file"

    exit 1

fi

  

# Dependency check

if ! command -v sops >/dev/null; then

    log "Error: sops package is needed"

    exit

fi

  

if ! command -v gpg >/dev/null; then

    log "Error: gnupg package is needed"

    exit

fi

  
  

# Delete password file after script certainly

cleanup() {

    if [ -f "$TMP_PATH/age-key" ]; then

        log "Notice: age-key was deleted"

        rm -f "$TMP_PATH/age-key"

    fi

}

  

trap cleanup EXIT

  

echo -n "Enter GPG passphrase: " >&2

read -s GPG_PASSPHRASE

echo "" >&2

  

echo "$GPG_PASSPHRASE" | gpg --batch --yes --passphrase-fd 0 \

--output "$TMP_PATH/age-key" \

--decrypt "$KEY_PATH/age-key.gpg" && \

chmod 600 "$TMP_PATH/age-key"

  

unset GPG_PASSPHRASE

  

if [ ! -f "$TMP_PATH/age-key" ]; then

        log "Error: Decrypted key file does not exist"

        exit 1

fi

  

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

                log "Error: SOPS extract error"

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

                log "Error: SOPS extract error"

                exit 1

        fi

fi
```