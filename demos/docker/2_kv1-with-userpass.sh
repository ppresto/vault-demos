#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../demo-magic.sh -d -p -w ${DEMO_WAIT}

#docker run -d --rm -p 8200:8200 --name vaultdev \
#    --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=my_root_token_id' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault:1.2.1

docker run -d --rm -p 8200:8200 --name vaultdev \
    --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=my_root_token_id' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault

export VAULT_TOKEN=my_root_token_id
export VAULT_ADDR="http://127.0.0.1:8200"

echo
cyan "Enable Audit Logging"
pe "vault audit enable file file_path=/vault/logs/vault_audit.log"

echo
cyan "Tail Audit Log"
pe "${DIR}/../launch_iterm.sh $HOME \"docker exec vaultdev tail -f /vault/logs/vault_audit.log | jq\" &"

echo
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
cyan "View Policy 'team-se-policy'"
pe "vault policy read team-se-policy"

echo
cyan "As the Vault Admin add a secret to secret/foo which isn't writeable by our team-se policy"
pe "vault kv put secret/foo robot=beepboopfoo"

echo
cyan "Lets test our new policy 'team-se-policy'"
green "To use a policy, lets create a user, and assign the policy"
vault auth enable userpass
vault write auth/userpass/users/ppresto \
password=password \
policies=team-se-policy

echo
yellow "'unset VAULT_TOKEN' to ensure new credentials are used"
temp_token=${VAULT_TOKEN}
unset VAULT_TOKEN
echo
green "Next login using the new token"
pe "vault login -method=userpass username=ppresto password=password"

green "Verify we can write data to secret/bar"
green "write kv data to secret/bar "
pe "vault kv put secret/bar robot=beepboop"
echo
green "read kv data from secret/bar"
pe "vault kv get secret/bar"
echo
green "read kv data from an undefined path (secret/bar/undefined)"
pe "vault kv get secret/bar/undefined"

echo
green "Now lets attempt to write data to secret/foo ... "
pe "vault kv put secret/foo robot=beepboop"
red "Writing to secret/foo should fail"
echo
green "Now lets attempt to read data to secret/foo ... "
pe "vault kv get secret/foo"

export VAULT_TOKEN=${temp_token}
echo
cyan "Removing containers and all generated files before exiting"
pe "docker kill vaultdev"
# Kill terminal window
cpid=$!
ppid=$(ps -o ppid= -p $cpid)
# kill terminal window not working...