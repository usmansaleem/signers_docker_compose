#! /bin/sh

set -e

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

rm -rf $SCRIPT_DIR/../vault/data/*
rm -rf $SCRIPT_DIR/../vault/certs/*
rm -rf $SCRIPT_DIR/../vault/creds/*
rm -rf $SCRIPT_DIR/../web3signer/config/keys/*
rm $SCRIPT_DIR/../web3signer/config/knownhosts