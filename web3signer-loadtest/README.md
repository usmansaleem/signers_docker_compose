# Web3Signer eth2 sign load test (k6)

A [k6](https://k6.io) script that drives `POST /api/v1/eth2/sign/{pubkey}` against a running Web3Signer in eth2 mode with a block payload. Defaults: 10 VUs for 30s (see `sign-loadtest.js` to tune).

## Prerequisites
- A running Web3Signer eth2 instance on `http://localhost:9000` with at least one key loaded. See [`../web3signer-eth2/README.md`](../web3signer-eth2/README.md).
- k6 installed:
  - macOS: `brew install k6`
  - Debian/Ubuntu: see the apt repo steps at <https://k6.io/docs/get-started/installation/>
  - Other platforms: <https://k6.io/docs/get-started/installation/>

## Run
```sh
k6 run sign-loadtest.js
```

Override VUs / duration from the command line without editing the script:
```sh
k6 run --vus 50 --duration 2m sign-loadtest.js
```
