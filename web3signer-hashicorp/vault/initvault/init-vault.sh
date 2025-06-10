#!/bin/bash

set -euo pipefail

# Configuration
: ${MAX_RETRIES:=10}
: ${RETRY_DELAY:=3}
: ${VAULT_SECRET_SHARES:=1}
: ${VAULT_SECRET_THRESHOLD:=1}
: ${VAULT_KV_PATH:="secret"}
: ${VAULT_KV_VERSION:="2"}

# Functions
log() {
    echo "[$(date '+%Y-%m-%d %T')] $1" >&2
}

get_vault_status() {
    local url=$1
    local attempt=0
    local status=""

    until [ $attempt -ge $MAX_RETRIES ]; do
        if status=$(curl -s -k -o /dev/null -w "%{http_code}" "${url}/v1/sys/health"); then
            case "$status" in
                200|501|503)
                    echo "$status"  # This is what gets captured when calling status=$(get_vault_status)
                    return 0
                    ;;
            esac
        fi

        attempt=$((attempt+1))
        log "Attempt $attempt/$MAX_RETRIES: Vault not ready (code: ${status:-unknown}), retrying in $RETRY_DELAY seconds..."
        sleep $RETRY_DELAY
    done

    log "Error: Failed to get valid response from Vault after $MAX_RETRIES attempts"
    return 1
}

initialize_vault() {
    local url=$1/v1
    log "Initializing Vault with ${VAULT_SECRET_SHARES} shares and threshold ${VAULT_SECRET_THRESHOLD}"

    INIT_OUT=$(curl -s -k -X POST \
        -d "{\"secret_shares\": $VAULT_SECRET_SHARES, \"secret_threshold\": $VAULT_SECRET_THRESHOLD}" \
        "${url}/sys/init")

    if ! jq -e '.root_token and .keys_base64[0]' <<< "$INIT_OUT" >/dev/null; then
        log "Error: Failed to initialize Vault - invalid response"
        return 1
    fi

    VAULT_TOKEN=$(jq -r '.root_token' <<< "$INIT_OUT")
    VAULT_KEY=$(jq -r '.keys_base64[0]' <<< "$INIT_OUT")

    # Secure credential storage
    if [ -w "$CREDS_DIR" ]; then
        echo -n "$VAULT_TOKEN" > "$CREDS_DIR/vault.token" && chmod 600 "$CREDS_DIR/vault.token"
        echo -n "$VAULT_KEY" > "$CREDS_DIR/vault.unseal" && chmod 600 "$CREDS_DIR/vault.unseal"
        # For Vault Proxy mode, use empty.token as it is rquired by the web3signer file
         echo -n "Token not required in Proxy Mode" > "$CREDS_DIR/empty.token" && chmod 600 "$CREDS_DIR/empty.token"
        log "Vault credentials securely stored in $CREDS_DIR"
    else
        log "Error: Credentials directory $CREDS_DIR is not writable"
        return 1
    fi

    unseal_vault "$url" "$VAULT_KEY"
}

unseal_vault() {
    local url=$1
    local key=$2

    log "Unsealing Vault..."
    for attempt in $(seq 1 $MAX_RETRIES); do
        response=$(curl -s -k -X POST -d "{\"key\": \"$key\"}" "${url}/sys/unseal")
        if jq -e '.sealed == false' <<< "$response" >/dev/null; then
            log "Vault successfully unsealed"
            return 0
        fi
        log "Attempt $attempt/$MAX_RETRIES: Unseal not complete, retrying..."
        sleep $RETRY_DELAY
    done

    log "Error: Failed to unseal Vault after $MAX_RETRIES attempts"
    return 1
}

setup_kv_store() {
    local url=$1/v1
    local token=$2

    log "Setting up KV v${VAULT_KV_VERSION} store at path ${VAULT_KV_PATH}"

    curl -s -k -X POST -H "X-Vault-Token: $token" \
        -d "{\"type\": \"kv\", \"options\": {\"version\": \"${VAULT_KV_VERSION}\"}}" \
        "${url}/sys/mounts/${VAULT_KV_PATH}" | jq

    log "KV store setup complete"
}

# Main execution
if [ $# -eq 0 ]; then
    log "Error: Vault URL argument required"
    exit 1
fi

VAULT_URL="${1%/}"  # Remove trailing slash if present
CREDS_DIR="/creds"

log "Starting Vault initialization process for $VAULT_URL"
if ! status=$(get_vault_status "$VAULT_URL"); then
    exit 1
fi

case "$status" in
    501)
        log "Vault needs initialization (status code: 501)"
        initialize_vault "$VAULT_URL" || exit 1
        setup_kv_store "$VAULT_URL" "$VAULT_TOKEN"
        ;;
    503)
        log "Vault needs unsealing (status code: 503)"
        if [ -f "$CREDS_DIR/vault.unseal" ]; then
            VAULT_KEY=$(cat "$CREDS_DIR/vault.unseal")
            unseal_vault "$VAULT_URL/v1" "$VAULT_KEY" || exit 1
        else
            log "Error: Vault is sealed but no unseal key found in $CREDS_DIR"
            exit 1
        fi
        ;;
    200)
        log "Vault is already initialized and unsealed (status code: 200)"
        ;;
    *)
        log "Error: Vault is in unexpected state (status code: $status)"
        exit 1
        ;;
esac

log "Vault initialization process completed successfully"
exit 0