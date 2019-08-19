#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. demo-magic.sh -d -p -w ${DEMO_WAIT}


cyan "Create a policy for team-se"
pe 'vault policy write team-se-policy -<<EOF
# Normal servers have version 1 of KV mounted by default, so will need these
# paths:
path "secret/*" {
  capabilities = ["create", "update", "read", "list"]
}
path "secret/foo" {
  capabilities = ["read"]
}

# Dev servers have version 2 of KV mounted by default, so will need these
# paths:
path "secret/data/*" {
  capabilities = ["create", "update", "read", "list"]
}
path "secret/data/foo" {
  capabilities = ["read"]
}
EOF'

echo
cyan "List Policies"
pe "vault policy list"

cyan "View Policy 'team-se-policy'"
pe "vault policy read team-se-policy"