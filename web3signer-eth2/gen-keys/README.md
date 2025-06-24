# Web3Signer BLS Key Generation Utility

The docker compose files in this directory provide the capability to generate BLS keys for Web3Signer in the following 
modes:

- Generate and insert BLS Keys into Hashicorp Vault to be loaded via yaml config files. Generated in
  `../web3signer/config/keys` directory.
- Generate and insert BLS Keys into Hashicorp Proxy to be loaded via yaml config files. Generated in
  `../web3signer/config/keys` directory.
- Generate (Light) BLS keystores and password files to be loaded via yaml config files. Generated in
  `../web3signer/config/keys` directory.
- Generate (Light) BLS Keystores and password files to be bulkloaded. Generated in `../web3signer/config/keystores`
  directory.

Each mode uses a dedicated Docker Compose file. You can generate keys before or after starting Web3Signer—if you 
generate them afterwards, be sure to reload the keys via the Web3Signer HTTP API.

---

## Prerequisites

- Docker and Docker Compose installed on your machine.
- A custom docker network named `w3s_network` is created. If not, run:
```sh
docker network create w3s_network
```
- (Vault modes only) A HashiCorp Vault server configured and running. See [`../vault/README.md`](../vault/README.md) for
Vault setup instructions.
- Web3Signer is running (to test reload endpoint)
---

## 1. BLS Keystores - Bulkload

```shell
KEYS_COUNT=500 docker compose -f ./compose.bls.yml up
```

---

## 2. BLS Keystores - Configuration Files

```shell
KEYS_COUNT=500 docker compose -f ./compose.bls.config.yml up
```

---

## 3. HashiCorp Vault - Yaml Configuration Files

```shell
KEYS_COUNT=500 docker compose -f ./compose.hashicorp.yml up
```

---

## 4. HashiCorp Vault Proxy - Yaml Configuration Files


```shell
KEYS_COUNT=500 docker compose -f ./compose.hashicorp.proxy.yml up
```

---

## Clean Up and Tear Down
Either run `../scripts/clear-all.sh` that will stop and clean up everything, or manually run:
```shell
docker compose -f <compose-file> down --rmi all -v --remove-orphans
```
Replace `<compose-file>` with the specific compose file you used (e.g., `compose.bls.yml`, `compose.hashicorp.yml`).