#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. demo-magic.sh -d -p -w ${DEMO_WAIT}


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
red "Expected Error: attempt to write data to secret/foo ... "
pe "vault kv put secret/foo robot=beepboop"

echo
purple "Setting Vault token back to its original value"
export VAULT_TOKEN=${temp_token}