#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Determine the directory this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root is one level up
ROOT_DIR="$SCRIPT_DIR/.."

# Optional: change this to any profile you like
PROFILE="${PROFILE:-vault-proxy}"

# Non-vault compose stacks (vault is handled by vault/scripts/clean.sh below)
COMPOSE_DIRS=(
  "$ROOT_DIR/gen-keys"
  "$ROOT_DIR/web3signer"
)

echo "🛑 Bringing down gen-keys and web3signer Docker Compose stacks (with --profile $PROFILE)…"
for dir in "${COMPOSE_DIRS[@]}"; do
  for file in "$dir"/compose*.yml; do
    echo "↓ docker compose --profile $PROFILE -f $file down --rmi all -v --remove-orphans"
    docker compose --profile "$PROFILE" -f "$file" down --rmi all -v --remove-orphans
  done
done

echo

# Delegate vault teardown + cleanup to the vault-local script
echo "🏛  Delegating Vault cleanup to vault/scripts/clean.sh…"
PROFILE="$PROFILE" "$ROOT_DIR/vault/scripts/clean.sh"

echo

echo "🧹 Cleaning up generated files…"

# web3signer/config/keys: remove everything except .gitignore
if [ -d "$ROOT_DIR/web3signer/config/keys" ]; then
  echo "→ Cleaning $ROOT_DIR/web3signer/config/keys (preserving .gitignore)"
  find "$ROOT_DIR/web3signer/config/keys" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
fi

# web3signer/config/keystores: remove everything except .gitignore
if [ -d "$ROOT_DIR/web3signer/config/keystores" ]; then
  echo "→ Cleaning $ROOT_DIR/web3signer/config/keystores (preserving .gitignore)"
  find "$ROOT_DIR/web3signer/config/keystores" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
fi

# Remove knownhosts file
knownhosts_file="$ROOT_DIR/web3signer/config/knownhosts"
if [ -f "$knownhosts_file" ]; then
  echo "→ Removing $knownhosts_file"
  rm -f "$knownhosts_file"
fi

# web3signer/config/heapdumps: remove everything except .gitignore
if [ -d "$ROOT_DIR/web3signer/config/heapdumps" ]; then
  echo "→ Cleaning $ROOT_DIR/web3signer/config/heapdumps (preserving .gitignore)"
  find "$ROOT_DIR/web3signer/config/heapdumps" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
fi

echo

echo "✅ All clean!"
