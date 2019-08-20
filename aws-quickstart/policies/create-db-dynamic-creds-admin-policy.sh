#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"



echo "Create a policy to administer the database dynacmic credentials engine"
vault policy write db-dynamic-creds-admin-policy -<<EOF
# Mount secret engines
path "sys/mounts/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Configure the database secret engine and create roles
path "database/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Write ACL policies
path "sys/policies/acl/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Manage tokens for verification
path "auth/token/create" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}
EOF

echo "View Policy"
vault policy read db-dynamic-creds-admin-policy