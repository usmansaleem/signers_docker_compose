# Web3Signer/Hashicorp docker compose

- Make sure Hashicorp docker compose is up (using different terminal window)
```
cd ./vault
docker compose up
```

## Generate Hashicorp configuration for Web3Signer if required.

Use following commands to generate `n` random BLS keys, import it in Hashicorp and generate Web3Signer configuration files.
The config files will be generated in `web3signer/config/keys`

```
git submodule update --init --recursive
./scripts/gen-keys.sh 20000
```

## Run Web3Signer
Assuming that the above step is performed to generate configuration files and vault docker compose is up.

```
cd ./web3signer
docker compose up
```

## Clean up
`CTRL+C` followed by `docker compose down --rmi all`.
To remove generated keys, hashicorp cert, data, cred etc. run `./scripts/clear-all.sh`