# Web3Signer Load Test #

This directory contains a Gatling-based load test for Web3Signer’s block‐signing API. By default, it targets a local 
Web3Signer instance at http://localhost:9000, sending 10 requests per second over a 10‐minute window. Each virtual user 
picks one random public key and a monotonically increasing slot, then calls the /api/v1/eth2/sign/{publicKey} endpoint.


## Running the Load Test
1. Ensure Web3Signer is running and exposed at http://localhost:9000.
2. Execute on shell:
   ```bash
   ./gradlew clean gatlingRun --simulation web3signer.SignSingleKeySimulation
   ```
   
## Customizing the Endpoint
If your Web3Signer instance runs on a different host/port, pass in a system property:
```shell
./gradlew gatlingRun \
  --simulation web3signer.SignSingleKeySimulation \
  -Dweb3signer.endpoint="http://<hostname>:<port>"

```
