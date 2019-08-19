#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. demo-magic.sh -d -p -w ${DEMO_WAIT}

green "We will create a policy for team-se that will allow them to writ k/v secrets everywhere but /secret/foo and then test the policy.  This policy will permit viewing policies too."
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

cyan "Test Policy 'team-se-policy'"
green "To use a policy, first create a token, and assign it to the policy"
p "vault token create -policy=team-se-policy"
new_token=$(vault token create -policy=team-se-policy)
echo ${new_token} | xargs -n2
token_value=$(echo $new_token | xargs -n2 | grep -w token | cut -d " " -f2)

echo
yellow "'unset VAULT_TOKEN' to ensure new credentials are used"
temp_token=${VAULT_TOKEN}
unset VAULT_TOKEN
echo
green "Next login using the new token"
pe "vault login ${token_value}"

green "Verify we can write data to secret/, but only read from secret/foo"
green "write kv data to secret/bar: "
pe "vault kv put secret/bar robot=beepboop"
echo
green "Now lets attempt to write data to secret/foo ... "
pe "vault kv put secret/foo robot=beepboop"
red "Wriging to secret/foo should have Failed"

echo
purple "Setting Vault token back to its original value"
export VAULT_TOKEN=${temp_token}