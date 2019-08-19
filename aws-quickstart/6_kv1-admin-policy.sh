#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. demo-magic.sh -d -p -w ${DEMO_WAIT}

cyan "what secrets engines are enabled?"
pe "vault secrets list -detailed"

cyan "Make sure kv engine v1 is enabled"
pe "vault secrets enable -path='kv-v1' -version=1 kv"

cyan "Check the kv engine version using the API"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" \\
  ${VAULT_ADDR}/v1/sys/mounts | jq"


cyan "Create a policy to administer the kv secret engine"
pe 'vault policy write kv-admin-policy -<<EOF
# Enable key/value secret engine at the kv-v1 path
path "sys/mounts/kv-v1" {
  capabilities = [ "update" ]
}

# To list the available secret engines
path "sys/mounts" {
  capabilities = [ "read" ]
}

# Write and manage secrets in key/value secret engine
path "kv-v1/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Create policies to permit apps to read secrets
path "sys/policies/acl/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Create tokens for verification & test
path "auth/token/create" {
  capabilities = [ "create", "update", "sudo" ]
}
EOF'

echo
cyan "List Policies"
pe "vault policy list"

cyan "View Policy 'kv-admin-policy'"
pe "vault policy read kv-admin-policy"