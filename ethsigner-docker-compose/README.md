## Test TLS

Bring EthSigner up
~~~
docker compose up
~~~

From another terminal, use curl to connect to EthSigner (via TLS - mutual client auth)
~~~
curl --cacert ./client1/ethsigner.pem --cert-type P12 --cert ./client1/client1_keystore.p12:changeit \
 https://localhost:8545/upcheck
~~~

## Steps to create self signed certificate both for EthSigner and the client

1. Create EthSigner keystore

~~~
keytool -genkeypair -keystore ./config/tls/keystore.p12 -storetype PKCS12 -storepass changeit -alias ethsigner \
-keyalg RSA -keysize 2048 -validity 700 -dname "CN=localhost, OU=PegaSys, O=ConsenSys, L=Brisbane, ST=QLD, C=AU" \
-ext san=dns:localhost,ip:127.0.0.1
~~~

2. Export EthSigner public key in pem format (to be used by client to accept EthSigner's self-signed cert)
~~~
keytool -exportcert -rfc -keystore ./config/tls/keystore.p12 -alias ethsigner -storepass changeit -file ./client1/ethsigner.pem
~~~

3. Create `client1` keystore (client self-signed certificate)

~~~
keytool -genkeypair -keystore ./client1/client1_keystore.p12 -storetype PKCS12 -storepass changeit -alias client1 \
-keyalg RSA -keysize 2048 -validity 700 -dname "CN=client1, OU=PegaSys, O=ConsenSys, L=Brisbane, ST=QLD, C=AU"
~~~

4. Obtain sha256 signature of client1
~~~
keytool -list -v -keystore ./client1/client1_keystore.p12 -storetype PKCS12 -storepass changeit
~~~

5. Store sha256 signature in `./config/tls/knownClients.txt`
~~~
client1 2F:0B:82:D5:34:4E:8E:20:89:78:88:F1:2D:8C:B2:5D:27:FF:21:7A:FC:41:47:DB:9B:97:95:F1:8E:C5:6E:13
~~~
