# Hashicorp Vault (without TLS) Docker Compose

Run Hashicorp vault on port 8200 with TLS disabled.

* The creds (root token and unseal key) is generated in `creds` directory on first run. The contents should not be checked into git.
* The Hashicorp data is saved in `data` directory. The contents should not be checked into git.

## Commands

Start: ```docker compose up```

Shutdown: ```CTRL+C``` Or ```docker compose down``` Or ``` docker compose rm -f```.

To remove the init-vault image, use ```docker image rm usmans/init-vault```.

