# Web3Signer/Hashicorp (via Agent) docker compose

Docker compose example showcase Web3Signer and Hashicorp Vault/Agent integration with TLS disabled.

- Make sure Hashicorp docker compose is up (using different terminal window). See [README](./vault/README.md) for more details.
```
cd ./vault
docker compose up
```

## Generate Hashicorp configuration for Web3Signer if required.

Assuming that vault-agent is up and running using above `docker compose up` command, use following commands to generate 5
random BLS keys, import it in Hashicorp and generate Web3Signer configuration files. The config files will be generated in `web3signer/config/keys`

```
cd ./gen-keys
docker compose up
```

To change the number of keys to generate, use following variant instead:
```
KEYS_COUNT=10 docker compose up
```

## Run Web3Signer
Assuming that the above step is performed to generate configuration files and vault docker compose is up.

```
cd ./web3signer
docker compose up
```

You should observe following kind of output in docker logs:
```
ws-develop  | 2023-06-21 12:08:20.899+00:00 | ForkJoinPool-1-worker-1 | DEBUG | SignerLoader | Signing metadata mapped to Artifact Signer: 5
ws-develop  | 2023-06-21 12:08:20.899+00:00 | pool-2-thread-1 | INFO  | SignerLoader | Total Artifact Signer loaded via configuration files: 5
ws-develop  | Error count 0
ws-develop  | Time Taken: 00:00:00.198.
ws-develop  | 2023-06-21 12:08:20.902+00:00 | pool-2-thread-1 | INFO  | DefaultArtifactSignerProvider | Total signers (keys) currently loaded in memory: 5
ws-develop  | 2023-06-21 12:08:20.912+00:00 | main | INFO  | Runner | Web3Signer has started with TLS disabled, and ready to handle signing requests on 0.0.0.0:9000
```

## Clean up
- In vault and web3signer terminal windows, `CTRL+C` and/or `docker compose down`.
- To remove docker images, generated keys, hashicorp cert, data, cred, configuration files. run `./scripts/clear-all.sh`