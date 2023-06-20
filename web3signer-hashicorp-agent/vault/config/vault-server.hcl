ui            = false
api_addr      = "http://127.0.0.1:8200"
disable_mlock = false

listener "tcp" {
  address       = "[::]:8200"
  tls_disable = "true"
}

storage "file" {
  path = "/data"
}