# Web3Signer BLS Key Generation Utility

Uses docker images generated from: https://github.com/usmansaleem/signer-configuration-generator

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

Light Keys (default KDF Counter = 16)
```shell
KEYS_COUNT=500 docker compose -f ./compose.bls.yml up
```

Or KDF Counter 2^14 = 16384, 
```shell
KEYS_COUNT=500 KDF_COUNTER=16384 docker compose -f ./compose.bls.yml up
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