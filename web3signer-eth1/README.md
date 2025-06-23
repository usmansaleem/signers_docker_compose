# Web3Signer with Amazon KMS simulation using localstack setup - eth1 mode

- See `./localstack-init-scripts/init-kms.sh` for the script that creates the KMS keys with various tags
- See `./config/config.yaml` for the Web3Signer configuration file that uses the KMS keys. Modify the tags accordingly. 
- Run `docker compose up` to start a Web3Signer instance with KMS using localstack setup in eth1 mode.

## Signing Test

To test the `/api/v1/eth1/sign/` using the first available public key:

```sh
cd ./signing-test
npm install
node test.js
```

## EIP-712 eth_signTypedData Test
To test EIP-712 eth_signTypedData JSON-RPC:

```shell
cd ./signing-test
npm install
node testTypedData.js
```

## Clean up

```shell
docker compose down --rmi all -v
```