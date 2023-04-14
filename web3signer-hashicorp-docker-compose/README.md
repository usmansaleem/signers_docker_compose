# Web3Signer/Hashicorp docker compose

- Make sure Hashicorp docker compose is up (using different terminal window)
```
cd ./vault
docker compose up
```

## Generate Hashicorp configuration for Web3Signer if required.

Use following commands to generate n random BLS keys, import it in Hashicorp and generate Web3Signer configuration files.
The config files will be generated in `web3signer/config/keys`

```
git submodule update --init --recursive
./scripts/gen-keys.sh 1000
```

## Run Web3Signer
```
cd ./web3signer
docker compose up
```