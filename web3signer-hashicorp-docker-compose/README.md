# Web3Signer docker compose

- Make sure Hashicorp docker compose is up (using different terminal window)
```
cd ../vault
docker compose up
```

- Generate Hashicorp configuration for Web3Signer

```
git submodule update --init --recursive
cd signer-configuration-generator

```