#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Determine the directory this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Project root is one level up
ROOT_DIR="$SCRIPT_DIR/.."

# Optional: change this to any profile you like
PROFILE="vault-proxy"

# Compose files live in these subfolders of the project root
COMPOSE_DIRS=(
  "$ROOT_DIR/gen-keys"
  "$ROOT_DIR/vault"
  "$ROOT_DIR/web3signer"
)

echo "🛑 Bringing down all Docker Compose stacks (with --profile $PROFILE)…"
for dir in "${COMPOSE_DIRS[@]}"; do
  for file in "$dir"/compose*.yml; do
    echo "↓ docker compose --profile $PROFILE -f $file down --rmi all -v --remove-orphans"
    docker compose --profile "$PROFILE" -f "$file" down --rmi all -v --remove-orphans
  done
done

echo

echo "🧹 Cleaning up generated files…"

# 1. vault/certs: remove everything except .gitignore
if [ -d "$ROOT_DIR/vault/certs" ]; then
  echo "→ Cleaning $ROOT_DIR/vault/certs (preserving .gitignore)"
  find "$ROOT_DIR/vault/certs" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
fi

# 2. vault/creds: remove everything except .gitignore
if [ -d "$ROOT_DIR/vault/creds" ]; then
  echo "→ Cleaning $ROOT_DIR/vault/creds (preserving .gitignore)"
  find "$ROOT_DIR/vault/creds" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
fi

# 3. vault/data: remove everything except .gitignore
if [ -d "$ROOT_DIR/vault/data" ]; then
  echo "→ Cleaning $ROOT_DIR/vault/data (preserving .gitignore)"
  find "$ROOT_DIR/vault/data" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
fi

# 4. vault/vault-proxy-pid: remove everything except .gitignore
if [ -d "$ROOT_DIR/vault/vault-proxy-pid" ]; then
  echo "→ Cleaning $ROOT_DIR/vault/vault-proxy-pid (preserving .gitignore)"
  find "$ROOT_DIR/vault/vault-proxy-pid" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
fi

# 5. web3signer/config/keys: remove everything except .gitignore
if [ -d "$ROOT_DIR/web3signer/config/keys" ]; then
  echo "→ Cleaning $ROOT_DIR/web3signer/config/keys (preserving .gitignore)"
  find "$ROOT_DIR/web3signer/config/keys" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
fi

# 5b. web3signer/config/keystores: remove everything except .gitignore
if [ -d "$ROOT_DIR/web3signer/config/keystores" ]; then
  echo "→ Cleaning $ROOT_DIR/web3signer/config/keystores (preserving .gitignore)"
  find "$ROOT_DIR/web3signer/config/keystores" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
fi

# 6. Remove knownhosts file
knownhosts_file="$ROOT_DIR/web3signer/config/knownhosts"
if [ -f "$knownhosts_file" ]; then
  echo "→ Removing $knownhosts_file"
  rm -f "$knownhosts_file"
fi

# 7. web3signer/config/heapdumps: remove everything except .gitignore
if [ -d "$ROOT_DIR/web3signer/config/heapdumps" ]; then
  echo "→ Cleaning $ROOT_DIR/web3signer/config/heapdumps (preserving .gitignore)"
  find "$ROOT_DIR/web3signer/config/heapdumps" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
fi

echo

echo "✅ All clean!"
