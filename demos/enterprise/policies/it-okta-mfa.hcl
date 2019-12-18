path "kv-blog/data/it/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
  mfa_methods  = ["my_okta"]
}