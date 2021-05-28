path "identity/oidc/token/*" {
  capabilities = ["list", "read", "create", "update"]
}

path "identity/oidc/introspect" {
  capabilities = ["list", "read", "create", "update"]
}
