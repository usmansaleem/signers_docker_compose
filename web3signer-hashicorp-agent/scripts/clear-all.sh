#! /bin/sh

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

echo "Vault: Docker compose down ..."
pushd $SCRIPT_DIR/../vault
docker compose down --rmi all
popd

echo "Vault: Web3Signer compose down ..."
pushd $SCRIPT_DIR/../web3signer
docker compose down --rmi all
popd

echo "Gen Keys: compose down ..."
pushd $SCRIPT_DIR/../gen-keys
docker compose down --rmi all
popd

echo "Vault: Removing data ..."
rm -rf $SCRIPT_DIR/../vault/data/core
rm -rf $SCRIPT_DIR/../vault/data/logical
rm -rf $SCRIPT_DIR/../vault/data/sys

echo "Vault: Removing creds ..."
rm -f $SCRIPT_DIR/../vault/creds/vault.token
rm -f $SCRIPT_DIR/../vault/creds/vault.unseal

echo "Web3Signer: Removing configuration files ..."
rm -rf $SCRIPT_DIR/../web3signer/config/keys
