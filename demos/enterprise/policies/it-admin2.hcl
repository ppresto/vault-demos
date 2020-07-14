# Manage namespaces
path "hr/sys/namespaces/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage policies
path "hr/sys/policies/acl/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List policies
path "hr/sys/policies/acl" {
   capabilities = ["list"]
}

# Enable and manage secrets engines
path "hr/sys/mounts/*" {
   capabilities = ["create", "read", "update", "delete", "list"]
}

# List available secret engines
path "hr/sys/mounts" {
  capabilities = [ "read" ]
}
path "hr/*" {
  capabilities = [ "read", "list" ]
}

# Allow UI updates in Enterprise
path "hr/sys/capabilities-self" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Create and manage entities and groups
path "hr/identity/*" {
   capabilities = ["create", "read", "update", "delete", "list"]
}

# Manage tokens
path "hr/auth/token/*" {
   capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

path "hr/transit-blog/*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo"]
}