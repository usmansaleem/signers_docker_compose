pid_file = "./pidfile"

vault {
   address = "$VAULT_ADDR"
   tls_skip_verify = true
}

listener "tcp" {
   address     = "[::]:8200"
   tls_disable = true
}

api_proxy {
   use_auto_auth_token = "force"
}

auto_auth {
   method {
      type = "token_file"
      config = {
         token_file_path = "/creds/vault.token"
      }
   }
   sink "file" {
      config = {
            path = "/creds/vault-token-via-agent"
      }
   }
}