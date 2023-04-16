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

echo "Vault: Removing data ..."
rm -rf $SCRIPT_DIR/../vault/data/.
echo "Vault: Removing certs ..."
rm -rf $SCRIPT_DIR/../vault/certs/.
echo "Vault: Removing creds ..."
rm -rf $SCRIPT_DIR/../vault/creds/.
echo "Web3Signer: Removing configuration files ..."
rm -rf $SCRIPT_DIR/../web3signer/config/keys/
echo "Web3Signer: Removing knownhosts file ..."
rm -fv $SCRIPT_DIR/../web3signer/config/knownhosts