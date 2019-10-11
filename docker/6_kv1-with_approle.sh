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

cyan "what secrets engines are enabled?"
pe "vault secrets list -detailed"

cyan "Make sure kv engine v1 is enabled"
vault secrets enable -path='kv-v1' -version=1 kv

cyan "Check the kv engine version using the API"
curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
  ${VAULT_ADDR}/v1/sys/mounts | jq


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
green "Excersise:   Store our Secret (ex: Google API Key) in vault"
green "   
Creating an AppRole for our k/v Administrator using the kv-admin policy.  
Using this Role get a vault token to access the vault API.
Create our secret and then read/fetch it.
"

ROLE=kv-admin-role
POLICY=kv-admin-policy

cyan "Enable AppRole Auth using the API"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" \\
  --request POST \\
  --data '{\"type\": \"approle\"}' \\
  ${VAULT_ADDR}/v1/sys/auth/approle"

cyan "create the AppRole ${ROLE} mapped to policy ${POLICY}"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" \\
  --request POST \\
  --data '{\"policies\": [\"${POLICY}\", \"default-policy\"]}' \\
  ${VAULT_ADDR}/v1/auth/approle/role/${ROLE}"

cyan "Request the role ID of role: ${ROLE}"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" \\
  ${VAULT_ADDR}/v1/auth/approle/role/${ROLE}/role-id | jq"

ROLE_ID=$(
  curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
  ${VAULT_ADDR}/v1/auth/approle/role/${ROLE}/role-id | jq '.data.role_id' | sed s"/\"//g"
)

cyan "Create a new secret ID under role: ${ROLE}"
p "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" \\
  --request POST \\
  ${VAULT_ADDR}/v1/auth/approle/role/${ROLE}/secret-id | jq '.data.secret_id'"

SECRET_ID=$(
curl -s --header "X-Vault-Token: $VAULT_TOKEN" --request POST \
  ${VAULT_ADDR}/v1/auth/approle/role/${ROLE}/secret-id | jq '.data.secret_id' | sed s"/\"//g"
)
echo $SECRET_ID

yellow "unset VAULT_TOKEN # Ensure the new AppRole Auth is used and not root token"
temp_token=${VAULT_TOKEN}
pe "unset VAULT_TOKEN"

cyan "Fetch a Vault Token using the roleID and new secretID"

p "curl -s --request POST \\
  --data '{\"role_id\": \"${ROLE_ID}\", \"secret_id\": \"${SECRET_ID}\"}' \\
 ${VAULT_ADDR}/v1/auth/approle/login | jq '.auth.client_token'"

TOKEN=$(curl -s --request POST \
  --data "{\"role_id\": \"${ROLE_ID}\", \"secret_id\": \"${SECRET_ID}\"}" \
 ${VAULT_ADDR}/v1/auth/approle/login | jq '.auth.client_token' | sed s"/\"//g")

echo $TOKEN

pe "export VAULT_TOKEN=${TOKEN}"

cyan "create a k/v secret for our Ex Google API Key"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" --request POST \\
    --data '{\"key\": \"GOOGLE-API-KEY-AAaaBBccDDeeOTXzSMT1234BB_Z8JzG7JkSVxI\"}' \\
    ${VAULT_ADDR}/v1/kv-v1/eng/apikey/Google"

cyan "Read/Fetch the newly created Google API Key using API"
pe "curl --header \"X-Vault-Token: $VAULT_TOKEN\" \\
    ${VAULT_ADDR}/v1/kv-v1/eng/apikey/Google | jq"

cyan "Fetch key value only using the CLI"
pe "vault kv get -field=key kv-v1/eng/apikey/Google"

export VAULT_TOKEN=${temp_token}
echo
cyan "Removing containers and all generated files before exiting"
pe "docker kill vaultdev"
# Kill terminal window
cpid=$!
ppid=$(ps -o ppid= -p $cpid)
# kill terminal window not working...