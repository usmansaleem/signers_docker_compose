pid_file = "/run/vault-proxy/pidfile"

vault {
   address = "$VAULT_ADDR"
   tls_skip_verify = true
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
            path = "/creds/vault-proxy"
      }
   }
}

listener "tcp" {
   address     = "[::]:8200"
   tls_disable = true
}

api_proxy {
   use_auto_auth_token = "force"
   enforce_consistency = "always"
}

// used by Vault Enterprise edition only
//cache {
//   cache_static_secrets = true
//   static_secret_token_capability_refresh_interval = "5m"
//}

