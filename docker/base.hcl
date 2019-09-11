# If working with kv version 2 (dev server default)
path "secret/data/training_*" {
   capabilities = ["create", "read"]
}

# If working with kv version 1 (non-dev server)
path "secret/training_*" {
   capabilities = ["create", "read"]
}
