#!/bin/bash
set -e

# Generate 4 QBFT node keys and a QBFT genesis. Use the built-in
# `besu operator generate-blockchain-config` to do both in one shot.
#
# Output layout under ./data/:
#   data/genesis.json
#   data/node-{0,1,2,3}/key            (32-byte hex private key)
#   data/node-{0,1,2,3}/key.pub        (uncompressed pubkey hex)
#   data/node-{0,1,2,3}/address        (validator address)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA_DIR="${SCRIPT_DIR}/data"
IMAGE="${IMAGE:-hyperledger/besu:roundchangefixdevelop}"

if [ -d "${DATA_DIR}" ]; then
  echo "Refusing to overwrite existing ${DATA_DIR}. Delete it first if you want a clean run."
  exit 1
fi

mkdir -p "${DATA_DIR}"

# QBFT generator config — generate: true asks Besu to mint 4 fresh keypairs.
CONFIG_FILE="${DATA_DIR}/qbftConfig.json"
cat > "${CONFIG_FILE}" <<'EOF'
{
  "genesis": {
    "config": {
      "chainId": 1337,
      "berlinBlock": 0,
      "londonBlock": 0,
      "shanghaiTime": 0,
      "qbft": {
        "blockperiodseconds": 2,
        "epochlength": 30000,
        "requesttimeoutseconds": 4
      }
    },
    "nonce": "0x0",
    "timestamp": "0x0",
    "gasLimit": "0x1fffffffffffff",
    "difficulty": "0x1",
    "mixHash": "0x63746963616c2062797a616e74696e65206661756c7420746f6c6572616e6365",
    "coinbase": "0x0000000000000000000000000000000000000000",
    "alloc": {
      "fe3b557e8fb62b89f4916b721be55ceb828dbd73": {
        "balance": "0xad78ebc5ac6200000"
      }
    }
  },
  "blockchain": {
    "nodes": {
      "generate": true,
      "count": 4
    }
  }
}
EOF

echo "Running besu operator generate-blockchain-config inside ${IMAGE} ..."
docker run --rm \
  -v "${DATA_DIR}:/data" \
  --entrypoint /opt/besu/bin/besu \
  "${IMAGE}" \
  operator generate-blockchain-config \
  --config-file=/data/qbftConfig.json \
  --to=/data/output

cp "${DATA_DIR}/output/genesis.json" "${DATA_DIR}/genesis.json"

# Distribute the 4 generated key directories into node-0..3 (deterministic alphabetical order).
i=0
for key_dir in $(ls -d "${DATA_DIR}/output/keys/"*/ | sort); do
  addr="$(basename "${key_dir}")"
  node_dir="${DATA_DIR}/node-${i}"
  mkdir -p "${node_dir}"
  cp "${key_dir}/key.priv" "${node_dir}/key"
  cp "${key_dir}/key.pub" "${node_dir}/key.pub"
  echo "${addr}" > "${node_dir}/address"
  pubkey_no_prefix="$(cat "${node_dir}/key.pub" | sed 's/^0x//')"
  echo "node-${i}  addr=${addr}  pubkey=${pubkey_no_prefix:0:16}..."
  i=$((i + 1))
done

# Drop the staging output dir; node-* dirs are the canonical key location.
rm -rf "${DATA_DIR}/output" "${CONFIG_FILE}"

# Write a .env file with the bootnode public key so docker-compose can substitute it.
NODE0_PUBKEY="$(cat "${DATA_DIR}/node-0/key.pub" | sed 's/^0x//')"
cat > "${SCRIPT_DIR}/.env" <<EOF
NODE0_PUBKEY=${NODE0_PUBKEY}
EOF

echo
echo "Setup complete. .env written with NODE0_PUBKEY=${NODE0_PUBKEY:0:16}..."
echo "Run: docker compose up -d"
echo "Watch logs: docker compose logs -f"
