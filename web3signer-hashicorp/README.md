# Web3Signer/Hashicorp docker compose

Docker compose example showcase Web3Signer and Hashicorp Vault integration with TLS enabled.

- Make sure Hashicorp docker compose is up (using different terminal window). See [README](./vault/README.md) for more details.
```
cd ./vault
docker compose up
```

## Generate Hashicorp configuration for Web3Signer if required.

Assuming that vault is up and running using above `docker compose up` command, use following commands to generate 50
random BLS keys, import it in Hashicorp and generate Web3Signer configuration files. The config files will be generated 
in `web3signer/config/keys`

```
cd ./gen-keys
docker compose up
```

To change the number of keys to generate, use following variant instead:
```
KEYS_COUNT=10 docker compose up
```

## Run Web3Signer
Assuming that vault docker compose is up and gen-keys docker compose has been executed successfully

```
cd ./web3signer
docker compose up
```

## Clean up
- In vault and web3signer terminal windows, `CTRL+C` and/or `docker compose down`.
- To remove docker images, generated keys, hashicorp cert, data, cred, configuration files. run `./scripts/clear-all.sh`