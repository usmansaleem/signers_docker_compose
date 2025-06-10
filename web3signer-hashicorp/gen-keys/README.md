# Web3Signer BLS Key Generation Utility

The docker compose files in this directory provide the capability to generate BLS keys for Web3Signer in three modes:

- **BLS Keys Generation - Bulkload**
- **BLS Keys Generation - HashiCorp Vault integration**
- **BLS Keys Generation - HashiCorp Vault proxy integration**

Each mode uses a dedicated Docker Compose file. You can generate keys before or after starting Web3Signer—if you 
generate them afterwards, be sure to reload the keys via the Web3Signer HTTP API.

---

## Prerequisites

- Docker and Docker Compose installed on your machine.
- (Vault modes only) A HashiCorp Vault server configured and running. See [`../vault/README.md`](../vault/README.md) 
- for Vault setup instructions.

---

## Reloading Keys

If you add or regenerate keys while Web3Signer is running, trigger a reload:

```sh
curl -X POST http://localhost:9000/reload
```

---

## 1. BLS Keys Generation - Bulkload
Generate BLS Keys that can be bulkloaded into Web3Signer. They are stored in the `../web3signer/config/keystores` 
directory.
```shell
KEYS_COUNT=500 \
  docker compose -f ./compose.bls.yml up
```

---

## 2. BLS Keys Generation - HashiCorp Vault integration
Generate and insert BLS keys into HashiCorp Vault. Generates Web3Signer configuration files in 
`../web3signer/config/keys` directory.

```shell
KEYS_COUNT=500 \
  docker compose -f ./compose.hashicorp.yml up
```

---

## 3. BLS Keys Generation - HashiCorp Vault Proxy integration
Generate and insert BLS keys into HashiCorp Vault via Vault Proxy. Generates Web3Signer configuration files in
`../web3signer/config/keys` directory.

```shell
KEYS_COUNT=500 \
  docker compose -f ./compose.hashicorp.yml up
```

---

## Clean Up and Tear Down
Either run `../scripts/clear-all.sh` that will stop and clean up everything, or manually run:
```shell
docker compose -f <compose-file> down --rmi all -v --remove-orphans
```
Replace `<compose-file>` with the specific compose file you used (e.g., `compose.bls.yml`, `compose.hashicorp.yml`).