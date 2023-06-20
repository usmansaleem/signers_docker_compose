#! /bin/sh

set -e

# Check if an argument was provided
if [ -z "$1" ]; then
    echo "Error: an integer argument is required"
    exit 1
fi

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

pushd $SCRIPT_DIR/../../signer-configuration-generator

./gradlew installdist
export JAVA_OPTS="-Djavax.net.ssl.trustStore=$SCRIPT_DIR/../vault/certs/truststore.p12 -Djavax.net.ssl.trustStorePassword=test123"
./build/install/signer-configuration-generator/bin/signer-configuration-generator hashicorp \
--token-file="$SCRIPT_DIR/../vault/creds/vault.token" --count="$1" --output="$SCRIPT_DIR/../web3signer/config/keys" \
--tls-knownhosts-file="/var/config/knownhosts" --url=https://localhost:8200/v1/secret \
--override-vault-host="vault"

popd

cp "$SCRIPT_DIR/../vault/certs/knownhosts" "$SCRIPT_DIR/../web3signer/config/"

echo "Done"