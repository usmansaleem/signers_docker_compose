#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
declare -a services=("web3signer" "gen-keys" "vault")

clean_docker() {
    local service="$1"
    echo "Cleaning Docker resources for ${service}..."
    if [ -d "${SCRIPT_DIR}/../${service}" ]; then
        pushd "${SCRIPT_DIR}/../${service}" >/dev/null
        docker compose down --rmi all -v || {
            echo "Warning: Failed to clean ${service} Docker resources"
            popd >/dev/null
            return 1
        }
        popd >/dev/null
    else
        echo "Warning: ${service} directory not found"
    fi
}

clean_files() {
    local paths=("$@")
    for path in "${paths[@]}"; do
        if [ -e "${path}" ]; then
            echo "Removing ${path}..."
            rm -rf "${path}"
        else
            echo "Not found (skipping): ${path}"
        fi
    done
}

clean_key_files() {
    local dir="$1"
    if [ -d "${dir}" ]; then
        echo "Cleaning key files in ${dir}..."
        # Preserve .gitignore while removing other files
        find "${dir}" \( -name "*.json" -o -name "*.yaml" -o -name "knownhosts" \) -delete
        # Remove empty subdirectories (except the keys directory itself)
        find "${dir}" -mindepth 1 -type d -empty -delete
        echo "Preserved ${dir}/.gitignore"
    else
        echo "Directory not found (skipping): ${dir}"
    fi
}

main() {
    # Clean Docker resources
    for service in "${services[@]}"; do
        clean_docker "${service}"
    done

    # Vault files cleanup
    local vault_data=(
        "${SCRIPT_DIR}/../vault/data/core"
        "${SCRIPT_DIR}/../vault/data/logical"
        "${SCRIPT_DIR}/../vault/data/sys"
    )

    local vault_certs=(
        "${SCRIPT_DIR}/../vault/certs/server.crt"
        "${SCRIPT_DIR}/../vault/certs/server.key"
        "${SCRIPT_DIR}/../vault/certs/truststore.p12"
        "${SCRIPT_DIR}/../vault/certs/knownhosts"
    )

    local vault_creds=(
        "${SCRIPT_DIR}/../vault/creds/vault.token"
        "${SCRIPT_DIR}/../vault/creds/vault.unseal"
    )

    local web3signer_files=(
        "${SCRIPT_DIR}/../web3signer/config/knownhosts"
    )

    clean_files "${vault_data[@]}"
    clean_files "${vault_certs[@]}"
    clean_files "${vault_creds[@]}"
    clean_files "${web3signer_files[@]}"

    # Special handling for keys directory
    clean_key_files "${SCRIPT_DIR}/../web3signer/config/keys"

    echo "Cleanup completed successfully"
}

main "$@"