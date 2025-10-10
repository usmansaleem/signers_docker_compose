# Web3Signer/Hashicorp/PostgreSQL docker compose

Docker compose example showcasing Web3Signer and Hashicorp Vault integration with TLS enabled.

## Prerequisites
1. Ensure Docker is running
2. A custom docker network named `w3s_network` exists or created:

```sh
docker network create w3s_network
```

3. For profiling: Linux host or Docker Desktop with 4GB+ memory allocated

---

## 1. Start Hashicorp Vault

Using a different terminal window, bring Hashicorp Vault up. See [README](./vault/README.md) for more details.

```sh

cd ./vault
docker compose up
```
---

## 2. Generate and Load Keys.

The `gen-keys` [docker compose](./gen-keys/README.md) can be used to set up BLS keys that will be loaded into
Web3Signer. Based on your testing needs, you can generate the following configurations:

- Generate and insert BLS Keys into Hashicorp Vault to be loaded via yaml config files. Generated in
  `./web3signer/config/keys` directory.
- Generate and insert BLS Keys into Hashicorp Proxy to be loaded via yaml config files. Generated in
  `./web3signer/config/keys` directory.
- Generate (Light) BLS keystores and password files to be loaded via yaml config files. Generated in
  `./web3signer/config/keys` directory.
- Generate (Light) BLS Keystores and password files to be bulkloaded. Generated in `./web3signer/config/keystores`
  directory.

You can mix and match the above configurations based on your testing needs.

The Keys can either be generated before starting Web3Signer or after it is running.


## 3. Run Web3Signer

```sh
cd ./web3signer
docker compose up
```
[!NOTE] If you are modifying SQL files and want to rebuild sql-copier image, run:

```shell
docker compose build --no-cache && docker compose up
```

Reload the Web3Signer configuration to load the keys (if generated after starting Web3Signer):
```sh
curl -X POST http://localhost:9000/reload
```

To test Key Manager API:

```sh
CONFIG_FILE_NAME=config-km.yaml docker compose up
```
Followed by running `import_keystores.sh` which will upload keystores from `./config/keystores` directory. They should 
be uploaded to `config/km/ks` directory or skip storage on disk depending on the setting in `config-km.yaml`.


---

## 4. Profiling (Optional)
To generate Web3Signer's Java process heapdump from the host machine:

```shell
# Heap dump
docker exec ws-develop jcmd 1 GC.heap_dump /heapsumps/w3s_heapdump.hprof
```
## Clean up
```shell
# From another terminal window
docker compose down

# Full cleanup
./scripts/clear-all.sh
```

---
