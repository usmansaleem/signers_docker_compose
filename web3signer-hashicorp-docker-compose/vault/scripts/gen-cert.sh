#! /bin/sh

set -e

if [ -f /certs/server.crt ]; then
  echo 'SSL certificate already exists'
  exit 0
fi

echo "Installing openssl ... "
apk update && apk add openssl && rm -rf /var/cache/apk/*
echo 'Generating SSL certificates ...'
openssl req -x509 -newkey rsa:2048 -nodes -days 36500 -keyout /certs/server.key -out /certs/server.crt -subj '/CN=vault' -addext 'subjectAltName = DNS:vault,DNS:localhost,IP:127.0.0.1'
echo "Generating truststore ..."
openssl pkcs12 -export -in /certs/server.crt -inkey /certs/server.key -out /certs/truststore.p12 -passout pass:test123
echo "Generating knownhosts file ..."
openssl x509 -in /certs/server.crt -noout -sha256 -fingerprint | awk -F= '{print $2}' | tr -d ': ' 
echo "vault $(openssl x509 -in /certs/server.crt -noout -sha256 -fingerprint | awk -F= '{print $2}' | tr -d ': ')" > /certs/knownhosts
