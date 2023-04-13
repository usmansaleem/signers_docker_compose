# Web3Signer docker compose

- Make sure Hashicorp docker compose is up (using different terminal window)
```
cd ./vault
docker compose up
```

## Generate Hashicorp configuration for Web3Signer if required.
### Convert server cert to PKCS12 truststore
```
keytool -import -trustcacerts -alias vault_ca \
-file ./vault/certs/server.crt -keystore ./vault/certs/truststore.p12 \
-storepass test123 -noprompt
```
### Generate random keys and import it in Hashicorp

```
git submodule update --init --recursive
cd signer-configuration-generator
./gradlew clean build installdist
cd ./build/install/signer-configuration-generator/bin
JAVA_OPTS="-Djavax.net.ssl.trustStore=../../../../../vault/certs/truststore.p12 -Djavax.net.ssl.trustStorePassword=test123" \
./signer-configuration-generator hashicorp --token=$(cat ../../../../../vault/creds/vault.token) \
--count=1 --output=../../../../../web3signer/config/keys/ --url https://localhost:8200/v1/secret

```