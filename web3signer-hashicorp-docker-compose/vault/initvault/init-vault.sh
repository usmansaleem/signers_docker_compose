#!/bin/bash

set -e

if [ $# -eq 0 ]; then
  echo "Error: No argument provided. Usage: $0 [URL]"
  exit 1
fi

url=$1
VAULT_HOST="$url/v1"

status=$(curl -I -k -s -o /dev/null -w "%{http_code}" $url/v1/sys/health)

if [ "$status" = "501" ]; then
  echo "Initializing Hashicorp vault ..."
elif [ "$status" = "200" ]; then
  echo "Initializing not required (status code 200)"
  exit 0
elif [ "$status" = "503" ]; then
  echo "Unsealing (status code 503...)"
  VAULT_KEY=$(cat /creds/vault.unseal)
  curl -s -k -X POST -d "{\"key\": \"$VAULT_KEY\"}" "$VAULT_HOST/sys/unseal" | jq
  echo "Vault successfully initialized."
  exit 0
else
  echo "Vault is in unexpected state (unknown status code: $status)"
  exit 1
fi

INIT_OUT=$(curl -s -k -X POST \
    -d '{"secret_shares": 1, "secret_threshold": 1}' "$VAULT_HOST/sys/init" | jq)

VAULT_TOKEN=$(echo $INIT_OUT | jq --raw-output '.root_token')
VAULT_KEY=$(echo $INIT_OUT | jq --raw-output '.keys_base64[0]')

echo "$VAULT_TOKEN" > /creds/vault.token
echo "$VAULT_KEY" > /creds/vault.unseal

echo "Unsealing Hashicorp Vault ..."
curl -s -k -X POST -d "{\"key\": \"$VAULT_KEY\"}" "$VAULT_HOST/sys/unseal" | jq

## Enable KV-v2 /secret mount
echo "Enable kv-v2 secret engine path at /secret ..."
curl -s -k -X POST -H "X-Vault-Token: $VAULT_TOKEN" \
 -d '{"type": "kv", "options": {"version": "2"}}' "$VAULT_HOST/sys/mounts/secret" | jq

echo "Vault successfully initialized."
exit 0