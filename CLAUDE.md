# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository purpose

This repo is a collection of **docker-compose test harnesses** for Besu, Web3Signer, Hashicorp Vault, PostgreSQL, and LocalStack (AWS KMS simulation). It does not build any application — each subdirectory is a self-contained scenario that pulls pre-built images (typically `consensys/web3signer:develop` or `web3signer/web3signer:develop`) and wires them together for manual / scripted testing.

Four independent scenarios, each with its own README:

| Directory | Scenario |
|---|---|
| `besu/` | Besu JSON-RPC with TLS + mutual client auth (uses `docker-compose.yml`) |
| `web3signer-eth1/` | Web3Signer eth1 mode + LocalStack KMS (uses `compose.yaml`) |
| `web3signer-eth2/` | Web3Signer eth2 mode + Hashicorp Vault + PostgreSQL/Flyway (multi-stack, see below) |
| `web3signer-eip-4844/` | Web3Signer eth1 against a Kurtosis-launched Besu+Teku FULU network, driven by Python tests |
| `web3signer-loadtest/` | k6 load test script targeting a running Web3Signer eth2 signing endpoint |

Each scenario operates **independently** — there is no top-level build or orchestration. Read the scenario's own README before modifying.

## Common commands

### web3signer-eth2 (most complex; three stacks sharing one external network)
Before anything else, create the shared network (required by all three compose stacks in this scenario):
```sh
docker network create w3s_network
```

Order matters — vault → gen-keys → web3signer:
```sh
# 1. Vault (TLS; generates self-signed certs + root token on first run under vault/certs, vault/creds, vault/data)
cd web3signer-eth2/vault && docker compose up

# 2. Generate BLS keys (pick one profile depending on what you are testing)
cd web3signer-eth2/gen-keys
KEYS_COUNT=500 docker compose -f compose.bls.yml up            # bulkload keystores
KEYS_COUNT=500 docker compose -f compose.bls.config.yml up     # yaml config files
KEYS_COUNT=500 docker compose -f compose.hashicorp.yml up      # Vault-backed via yaml
KEYS_COUNT=500 docker compose -f compose.hashicorp.proxy.yml up # Vault-proxy-backed via yaml
# Optional: KDF_COUNTER=16384 for stronger (slower) keystores; default is 16

# 3. Web3Signer + Postgres + Flyway
cd web3signer-eth2/web3signer && docker compose up
# Or with custom image / config:
WEB3SIGNER_IMAGE=web3signer:keymanager_pr CONFIG_FILE_NAME=config-km.yaml docker compose up
# Rebuild sql-copier if SQL files changed:
docker compose build --no-cache && docker compose up

# Reload keys after generating them into a running Web3Signer:
curl -X POST http://localhost:9000/reload

# Key Manager API import (requires CONFIG_FILE_NAME=config-km.yaml):
cd web3signer-eth2/web3signer && ./import_keystores.sh

# Heap dump (profiling requires Linux host or Docker Desktop ≥ 4GB):
docker exec ws-develop jcmd 1 GC.heap_dump /heapdumps/w3s_heapdump.hprof

# Full teardown (delegates to per-service clean.sh scripts that bring down each stack and scrub generated certs/creds/data/keys, preserving .gitignore files):
./web3signer-eth2/scripts/clean-all.sh
# Or per-service, in isolation:
./web3signer-eth2/gen-keys/scripts/clean.sh
./web3signer-eth2/vault/scripts/clean.sh
./web3signer-eth2/web3signer/scripts/clean.sh
```

### web3signer-eth1
```sh
cd web3signer-eth1 && docker compose up
# JDWP debug port 5005 is exposed; image defaults to web3signer/web3signer:develop (override via IMAGE_NAME).
# KMS keys defined in localstack-init-scripts/init-kms.sh; Web3Signer filters them via eth1.aws-kms-tag in config/config.yaml.

# Node-based signing tests:
cd signing-test && npm install
node test.js              # /api/v1/eth1/sign/ using first public key
node testTypedData.js     # EIP-712 eth_signTypedData

# Clean:
docker compose down --rmi all -v
```

### besu (TLS test)
```sh
cd besu && docker compose up
# Exercise mutual-TLS from another terminal:
curl --cacert ./client1/besu.pem --cert-type P12 --cert ./client1/client1_keystore.p12:changeit \
  -X POST --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
  https://localhost:8545
```
The besu README also contains the exact `keytool` sequence for regenerating the self-signed server/client certs and the `knownClients.txt` SHA-256 fingerprint.

### web3signer-eip-4844
Three moving parts in separate terminals:
```sh
# 1. Besu + Teku devnet via Kurtosis
cd web3signer-eip-4844/kurtosis
kurtosis run --enclave besu-teku github.com/ethpandaops/ethereum-package --args-file besu-teku-minimal.yml
# Watch genesis at http://127.0.0.1:36000 (Dora)

# 2. Web3Signer (eth1 mode) in a *separate* copy under this scenario
cd web3signer-eip-4844/web3signer-eth1 && docker compose up

# 3. Python test (create venv first)
cd web3signer-eip-4844/python-test
python3 -m venv venv && source ./venv/bin/activate
pip install -r ./requirements.txt
python3 test_blob_tx.py

# Teardown: kurtosis clean -a  +  docker compose down
```

### web3signer-loadtest
```sh
# Requires a running Web3Signer eth2 instance (see web3signer-eth2 above) with keys loaded.
k6 run web3signer-loadtest/sign-loadtest.js
# Defaults: 10 VUs, 30s; hits /api/v1/eth2/sign/{pubkey} with a block payload.
```

## Architecture notes that require reading multiple files

### web3signer-eth2 service dependency chain
`web3signer/compose.yml` wires four services with explicit ordering:

1. `web3signer_sql_scripts` — a one-shot build using `Dockerfile.sql-copier` to extract Flyway SQL migrations from the Web3Signer image into a named `sql` volume (`restart: "no"` is deliberate — it must run exactly once per `up`).
2. `db` — Postgres, depends on the SQL scripts container succeeding.
3. `flyway` — runs migrations from the `sql` volume against `db`.
4. `web3signer` — depends on `flyway` completing successfully, mounts `./config` and `./heapdumps`, exposes 9000 (HTTP API), 9001 (metrics), 9010 (JMX), and runs with `cap_add: SYS_ADMIN` + `seccomp:unconfined` for async-profiler support. CPU/memory are capped (2 CPUs, 4 GB) to make profiling results reproducible.

All four services join the externally-created `w3s_network` — if you forget `docker network create w3s_network` the stack will not start. Vault and gen-keys attach to the same network so Web3Signer can resolve them by container name.

Environment variables that shape behaviour: `WEB3SIGNER_IMAGE` (default `consensys/web3signer:develop`), `CONFIG_FILE_NAME` (default `config.yaml`; switch to `config-km.yaml` for Key Manager API), `PG_TAG`, `FLYWAY_TAG`, `INTERNAL_NETWORK_NAME`.

### web3signer-eth1 LocalStack/KMS contract
`compose.yaml` wires Web3Signer against LocalStack acting as an AWS KMS endpoint. Two files must agree:

- `localstack-init-scripts/init-kms.sh` creates the KMS keys and their **tags** when LocalStack boots.
- `config/config.yaml` points Web3Signer at `http://localstack:4566` with `SPECIFIED` auth (`test1`/`test1`) and filters keys by tag via the commented-out `eth1.aws-kms-tag` line.

Changing tags in one file without the other will break key discovery. `localstack-volume/` persists LocalStack state between runs.

### Vault generated artifacts
`web3signer-eth2/vault/` generates certs (`certs/`), root-token+unseal-key (`creds/`), and storage (`data/`) on first run — all gitignored. `vault/scripts/clean.sh` (or the top-level `scripts/clean-all.sh`) is the canonical way to reset them; deleting `data/` alone leaves stale certs that will not match a newly initialized Vault.

### Key generation utility
`gen-keys/` uses pre-built images from https://github.com/usmansaleem/signer-configuration-generator. The four compose profiles are **mutually compatible** — you can mix (e.g., some keys bulkloaded, some via Vault yaml) because each writes to a different subdirectory under `web3signer/config/` (`keys/` vs `keystores/`).

### Port map (useful when running multiple scenarios at once — they will conflict)
| Port | Service |
|---|---|
| 8200 | Vault |
| 8545 / 8546 | Besu JSON-RPC (TLS) |
| 9000 | Web3Signer HTTP API |
| 9001 | Web3Signer metrics |
| 9010 | Web3Signer JMX |
| 5005 | Web3Signer JDWP (eth1 scenario only) |
| 5432 | Postgres |
| 4566 / 4510–4559 | LocalStack |
| 36000 | Kurtosis Dora dashboard |
