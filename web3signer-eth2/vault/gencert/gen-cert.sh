#!/bin/sh

set -e

# Create directories if they don't exist
mkdir -p /certs /web3signer/config

# Skip if certificates already exist
if [ -f /certs/server.crt ]; then
  echo 'SSL certificate already exists'
  exit 0
fi

# Cleanup function for error handling
cleanup() {
  echo "Error occurred during certificate generation"
  rm -f /certs/server.crt /certs/server.key /certs/truststore.p12 /certs/knownhosts
  exit 1
}
trap cleanup EXIT ERR

echo 'Generating SSL certificates...'
openssl req -x509 -newkey rsa:4096 -nodes -days 365 \
  -keyout /certs/server.key -out /certs/server.crt \
  -subj '/CN=vault' \
  -addext 'subjectAltName = DNS:vault,DNS:localhost,IP:127.0.0.1'

echo "Generating truststore..."
TRUSTSTORE_PASS=${TRUSTSTORE_PASSWORD:-test123}
openssl pkcs12 -export -nokeys \
  -in /certs/server.crt \
  -out /certs/truststore.p12 \
  -passout "pass:$TRUSTSTORE_PASS" \
  -name vault -caname vault

echo "Generating knownhosts file..."
echo "vault:8200 $(openssl x509 -in /certs/server.crt -noout -sha256 -fingerprint | awk -F= '{print $2}' | tr -d ': ')" > /certs/knownhosts

# Set proper permissions
chmod 644 /certs/server.crt
chmod 600 /certs/server.key
chmod 600 /certs/truststore.p12
chmod 644 /certs/knownhosts

# Copy to web3signer
cp /certs/knownhosts /web3signer/config/knownhosts
chmod 644 /web3signer/config/knownhosts

trap - EXIT ERR
echo "Certificate generation completed successfully"
