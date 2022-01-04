## Test TLS

Bring Besu up
~~~
docker compose up
~~~

Should result in log similar to:
~~~
besu-docker-compose-besu-1  | 2022-01-04 09:31:21.520+00:00 | main | INFO  | JsonRpcHttpService | Starting JSON-RPC service on 0.0.0.0:8545
besu-docker-compose-besu-1  | 2022-01-04 09:31:21.700+00:00 | vert.x-eventloop-thread-6 | INFO  | JsonRpcHttpService | JSON-RPC service started and listening on 0.0.0.0:8545 with TLS enabled.
~~~

From another terminal, use curl to connect to Besu (via TLS - mutual client auth)
~~~
curl --cacert ./client1/besu.pem --cert-type P12 --cert ./client1/client1_keystore.p12:changeit \
 -X POST --data '{"jsonrpc":"2.0","method":"eth_chainId","params":[],"id":1}' \
 https://localhost:8545
 ~~~

## Steps to create self signed certificate both for Besu and the client

1. Create Besu keystore

~~~
keytool -genkeypair -keystore ./config/tls/keystore.p12 -storetype PKCS12 -storepass changeit -alias besu \
-keyalg RSA -keysize 2048 -validity 700 -dname "CN=localhost, OU=PegaSys, O=ConsenSys, L=Brisbane, ST=QLD, C=AU" \
-ext san=dns:localhost,ip:127.0.0.1
~~~

2. Export besu public key in pem format (to be used by client to accept Besu's self-signed cert)
~~~
keytool -exportcert -rfc -keystore ./config/tls/keystore.p12 -alias besu -storepass changeit -file ./client1/besu.pem
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
