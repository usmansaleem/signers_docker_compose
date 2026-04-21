#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Determine the directory this script lives in
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# gen-keys directory is one level up
GEN_KEYS_DIR="$SCRIPT_DIR/.."
# Web3Signer config is where gen-keys writes its output
W3S_CONFIG_DIR="$GEN_KEYS_DIR/../web3signer/config"

# Optional: override via env; default matches the main scenario profile
PROFILE="${PROFILE:-vault-proxy}"

echo "🛑 Bringing down gen-keys Docker Compose stacks (with --profile $PROFILE)…"
for file in "$GEN_KEYS_DIR"/compose*.yml; do
  echo "↓ docker compose --profile $PROFILE -f $file down --rmi all -v --remove-orphans"
  docker compose --profile "$PROFILE" -f "$file" down --rmi all -v --remove-orphans
done

echo

echo "🧹 Cleaning up gen-keys output files…"

# keys/ and keystores/ each keep a .gitignore that must survive the wipe.
for sub in keys keystores; do
  target="$W3S_CONFIG_DIR/$sub"
  if [ -d "$target" ]; then
    echo "→ Cleaning $target (preserving .gitignore)"
    find "$target" -mindepth 1 ! -name ".gitignore" -exec rm -rf {} +
  fi
done

# knownhosts is written by the hashicorp profile
knownhosts_file="$W3S_CONFIG_DIR/knownhosts"
if [ -f "$knownhosts_file" ]; then
  echo "→ Removing $knownhosts_file"
  rm -f "$knownhosts_file"
fi

echo

echo "✅ gen-keys clean!"
