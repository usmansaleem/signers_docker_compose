# Web3Signer/Hashicorp/PostgreSQL docker compose

Docker compose example showcasing Web3Signer and Hashicorp Vault integration with TLS enabled.

## Prerequisites
1. Ensure Docker is running
2. For profiling: Linux host or Docker Desktop with 4GB+ memory allocated

- Make sure Hashicorp docker compose is up (using different terminal window). See [README](./vault/README.md) for more details.
## 1. Start Hashicorp Vault
```sh

cd ./vault
docker compose up
```
See [detailed vault README](./vault/README.md)

## 2. Run Web3Signer

```sh
cd ./web3signer
docker compose up
```

## 3. Generate and Load Keys (Optional).
Generate and import BLS keys into Hashicorp Vault. Creates configs in `web3signer/config/keys` directory. 

### Option A: Generate Before running Web3Signer

```sh
cd ./gen-keys
docker compose up
# For custom key count:
KEYS_COUNT=10000 docker compose up
```

### Option B: Generate After running Web3Signer
1. Start Web3Signer (see step 2 above).
2. Then generate keys (see option A above).
3. Trigger Web3Signer to reload the keys:
```sh
curl -X POST http://localhost:9000/reload
```

## 4. Profiling (Optional)
To generate Web3Signer's Java process heapdump from the host machine:

```shell
# Heap dump
docker exec ws-develop jcmd 1 GC.heap_dump /tmp/profiler/heap_dump_4.hprof
```
## Clean up
```shell
# From another terminal window
docker compose down

# Full cleanup
./scripts/clear-all.sh
```
