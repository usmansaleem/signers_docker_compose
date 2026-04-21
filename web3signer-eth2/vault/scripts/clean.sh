#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Determine the directory this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Vault directory is one level up
VAULT_DIR="$SCRIPT_DIR/.."

# Optional: override via env; default matches the main scenario profile
PROFILE="${PROFILE:-vault-proxy}"

echo "🛑 Bringing down Vault Docker Compose stack (with --profile $PROFILE)…"
for file in "$VAULT_DIR"/compose*.yml; do
  echo "↓ docker compose --profile $PROFILE -f $file down --rmi all -v --remove-orphans"
  docker compose --profile "$PROFILE" -f "$file" down --rmi all -v --remove-orphans
done

echo

echo "🧹 Cleaning up Vault generated files…"

# Each of these directories keeps a .gitignore that must survive the wipe.
for sub in certs creds data vault-proxy-pid; do
  target="$VAULT_DIR/$sub"
  if [ -d "$target" ]; then
    echo "→ Cleaning $target (preserving .gitignore)"
    find "$target" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
  fi
done

echo

echo "✅ Vault clean!"
