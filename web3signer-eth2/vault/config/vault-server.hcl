ui            = false
api_addr      = "https://127.0.0.1:8200"
disable_mlock = false

listener "tcp" {
  address       = "0.0.0.0:8200"
  tls_cert_file = "/tls/server.crt"
  tls_key_file  = "/tls/server.key"
}

storage "file" {
  path = "/data"
}