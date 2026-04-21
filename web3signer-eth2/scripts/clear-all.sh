#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Determine the directory this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root is one level up
ROOT_DIR="$SCRIPT_DIR/.."

# Optional: change this to any profile you like
PROFILE="${PROFILE:-vault-proxy}"

# Delegate gen-keys teardown + cleanup to the gen-keys-local script
echo "🔑 Delegating gen-keys cleanup to gen-keys/scripts/clean.sh…"
PROFILE="$PROFILE" "$ROOT_DIR/gen-keys/scripts/clean.sh"

echo

# Delegate vault teardown + cleanup to the vault-local script
echo "🏛  Delegating Vault cleanup to vault/scripts/clean.sh…"
PROFILE="$PROFILE" "$ROOT_DIR/vault/scripts/clean.sh"

echo

echo "🛑 Bringing down web3signer Docker Compose stack (with --profile $PROFILE)…"
for file in "$ROOT_DIR/web3signer"/compose*.yml; do
  echo "↓ docker compose --profile $PROFILE -f $file down --rmi all -v --remove-orphans"
  docker compose --profile "$PROFILE" -f "$file" down --rmi all -v --remove-orphans
done

echo

echo "🧹 Cleaning up web3signer generated files…"

# web3signer/config/heapdumps: remove everything except .gitignore
if [ -d "$ROOT_DIR/web3signer/config/heapdumps" ]; then
  echo "→ Cleaning $ROOT_DIR/web3signer/config/heapdumps (preserving .gitignore)"
  find "$ROOT_DIR/web3signer/config/heapdumps" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
fi

echo

echo "✅ All clean!"
