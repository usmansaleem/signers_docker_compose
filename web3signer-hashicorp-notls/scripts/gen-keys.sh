#! /bin/sh

set -e

# Check if an argument was provided
if [ -z "$1" ]; then
    echo "Error: an integer argument is required"
    echo "Usage ./gen-keys.sh <num_of_keys>"
    exit 1
fi

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

pushd $SCRIPT_DIR/../signer-configuration-generator

./gradlew installdist
./build/install/signer-configuration-generator/bin/signer-configuration-generator hashicorp \
--token-file="$SCRIPT_DIR/../vault/creds/vault.token" --count="$1" --output="$SCRIPT_DIR/../web3signer/config/keys" \
--url=http://localhost:8200/v1/secret \
--override-vault-host="vault"

popd

echo "Done"