Docker compose files for Besu, Web3Signer and EthSigner to test various configurations.

| **Examples**               | **Description**                                                                                     |
|----------------------------|-----------------------------------------------------------------------------------------------------|
| [besu](besu/README.md)                       | Docker compose example for Besu RPC with TLS enabled                                                |
| [ethsigner](ethsigner/README.md)                  | Docker compose example for EthSigner with TLS enabled                                               |
| [web3signer](web3signer/README.md)                 | Docker compose example for web3signer with TLS disabled and using unencrypted private keys.         |
| [web3signer-hashicorp](web3signer-hashicorp/README.md)       | Docker compose example showcase Web3Signer and Hashicorp Vault integration with TLS enabled.        |
| [web3signer-hashicorp-agent](web3signer-hashicorp-agent/README.md) | Docker compose example showcase Web3Signer and Hashicorp Vault/Agent integration with TLS disabled. |
| [web3signer-pg](web3signer-pg/README.md)              | Docker compose examples showcasing slashing protection with Postgresql integration                  |
| [web3signer-loadtest](web3signer-loadtest/README.md)        | Web3Signer block signing load testing using Gatling (Scala)                                         |
