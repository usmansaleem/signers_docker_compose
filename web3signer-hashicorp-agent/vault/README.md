# Hashicorp Vault and Agent (without TLS) Docker Compose

Run Hashicorp agent on port 8200 with TLS disabled. Vault agent will proxy to Vault instance without client requiring auth token.

* The creds (root token and unseal key) is generated in `creds` directory on first run. The contents should not be checked into git.
* The Hashicorp data is saved in `data` directory. The contents should not be checked into git.

## Commands

Start: ```docker compose up```

Shutdown: ```CTRL+C``` Or ```docker compose down``` Or ``` docker compose rm -f```.

To remove the init-vault image, use ```docker image rm usmans/init-vault```.

