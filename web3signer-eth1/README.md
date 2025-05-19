# Web3Signer with KMS using localstack setup - eth1 mode

- See `./localstack-init-scripts/init-kms.sh` for the script that creates the KMS keys with various tags
- See `./config/config.yaml` for the Web3Signer configuration file that uses the KMS keys. Modify the tags accordingly. 
- Following configuration should load 4 keys from KMS.
```yaml
eth1.aws-kms-tag-names-filter: ["Org1"]
eth1.aws-kms-tag-values-filter: ["QA"]
``` 
- Run `docker compose up` to start a Web3Signer instance with KMS using localstack setup in eth1 mode.

## Signing Test

To test the `/api/v1/eth1/sign/` using the first available public key:

```sh
cd ./signing-test
npm install
node test.js
```
