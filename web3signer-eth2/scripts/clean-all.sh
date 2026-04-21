#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Determine the directory this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root is one level up
ROOT_DIR="$SCRIPT_DIR/.."

# Optional: change this to any profile you like
PROFILE="${PROFILE:-vault-proxy}"

# Delegate gen-keys teardown + cleanup
echo "🔑 Delegating gen-keys cleanup to gen-keys/scripts/clean.sh…"
PROFILE="$PROFILE" "$ROOT_DIR/gen-keys/scripts/clean.sh"

echo

# Delegate Vault teardown + cleanup
echo "🏛  Delegating Vault cleanup to vault/scripts/clean.sh…"
PROFILE="$PROFILE" "$ROOT_DIR/vault/scripts/clean.sh"

echo

# Delegate Web3Signer teardown + cleanup
echo "✍️  Delegating Web3Signer cleanup to web3signer/scripts/clean.sh…"
PROFILE="$PROFILE" "$ROOT_DIR/web3signer/scripts/clean.sh"

echo

echo "✅ All clean!"
