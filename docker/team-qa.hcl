# If working with kv version 2 (dev server default)
path "secret/data/team-qa" {
   capabilities = [ "create", "read", "update", "delete" ]
}

# If working with kv version 1 (non-dev server)
path "secret/team-qa" {
   capabilities = [ "create", "read", "update", "delete" ]
}
