#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Determine the directory this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# web3signer directory is one level up
W3S_DIR="$SCRIPT_DIR/.."

# Optional: override via env; default matches the main scenario profile
PROFILE="${PROFILE:-vault-proxy}"

echo "🛑 Bringing down Web3Signer Docker Compose stack (with --profile $PROFILE)…"
for file in "$W3S_DIR"/compose*.yml; do
  echo "↓ docker compose --profile $PROFILE -f $file down --rmi all -v --remove-orphans"
  docker compose --profile "$PROFILE" -f "$file" down --rmi all -v --remove-orphans
done

echo

echo "🧹 Cleaning up Web3Signer generated files…"

# Each of these directories keeps a .gitignore that must survive the wipe.
#   heapdumps      — heap dumps captured via jcmd GC.heap_dump
#   config/km/ks   — keystores uploaded via Key Manager API
#   config/km/pwds — matching keystore passwords
for sub in heapdumps config/km/ks config/km/pwds; do
  target="$W3S_DIR/$sub"
  if [ -d "$target" ]; then
    echo "→ Cleaning $target (preserving .gitignore)"
    find "$target" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
  fi
done

echo

echo "✅ Web3Signer clean!"
