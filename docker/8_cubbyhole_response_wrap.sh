#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../demo-magic.sh -d -p -w ${DEMO_WAIT}


docker run -d --rm -p 8200:8200 --name vaultdev \
    --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=my_root_token_id' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault
    
export VAULT_TOKEN=my_root_token_id
export VAULT_ADDR="http://127.0.0.1:8200"

green "Cubbyhole Response Wrapping"
cyan "Create a policy for the app team that can only read /secret/dev"
pe 'vault policy write app-team -<<EOF
# For testing, read-only on secret/dev path
path "secret/data/dev" {
  capabilities = [ "read" ]
}
EOF'

echo
cyan "View Policy 'app-team'"
pe "vault policy read app-team"

yellow "Enabling k/v version 2. The k/v API requests in this example are using version=2."
vault kv enable-versioning secret/

cyan "create a k/v secret as root in /secret/dev for the app-team to read later"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" --request POST \\
    --data '{\"data\": {\"key\": \"GOOGLE-API-KEY-AAaaBBccDDeeOTXzSMT1234BB_Z8JzG7JkSVxI\"}}' \\
    ${VAULT_ADDR}/v1/secret/data/dev |jq"

cyan "Create a response wrapper token with the API using TTL=120 seconds"
# vault token create -policy=app-team -wrap-ttl=120  #CLI
p "curl --header \"X-Vault-Wrap-TTL: 120\" --header \"X-Vault-Token: ${VAULT_TOKEN}\" \\
      --request POST --data '{\"policies\":[\"app-team\"]}' \\
      ${VAULT_ADDR}/v1/auth/token/create | jq '.wrap_info.token'"

WRAPPER_TOKEN=$(
curl -s --header "X-Vault-Wrap-TTL: 120" --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data '{"policies":"app-team"}' \
  ${VAULT_ADDR}/v1/auth/token/create | jq '.wrap_info.token' | sed s"/\"//g"
)
echo $WRAPPER_TOKEN

cyan "Create a default token that can be used to unwrap the app-team token"
p "curl --header \"X-Vault-Token: ${VAULT_TOKEN}\" \\
      --request POST --data '{\"policies\":\"default\"}' \\
      ${VAULT_ADDR}/v1/auth/token/create | jq"

DEFAULT_TOKEN=$(
curl -s --header "X-Vault-Token: $VAULT_TOKEN" --request POST --data '{"policies":"default"}' \
  ${VAULT_ADDR}/v1/auth/token/create| jq '.auth.client_token' | sed s"/\"//g"
)
echo $DEFAULT_TOKEN

cyan "The default token should NOT be able to read secret/dev.  Lets Verify..."
pe "curl --header \"X-Vault-Token: ${DEFAULT_TOKEN}\" --request GET \\
      ${VAULT_ADDR}/v1/secret/dev | jq"

cyan "Unwrap the Wrapper_token (${WRAPPER_TOKEN}) using the default token (${DEFAULT_TOKEN})"
p "curl --header \"X-Vault-Token: ${WRAPPER_TOKEN}\" --request POST \\
      ${VAULT_ADDR}/v1/sys/wrapping/unwrap | jq '.auth.client_token'"

APP_TOKEN=$(
curl -s --header "X-Vault-Token: ${WRAPPER_TOKEN}" --request POST \
  ${VAULT_ADDR}/v1/sys/wrapping/unwrap | jq '.auth.client_token' | sed s"/\"//g"
)
echo "Unwrapped App-Team Token: $APP_TOKEN"
echo
#yellow "'unset VAULT_TOKEN' to ensure new credentials are used"
temp_token=${VAULT_TOKEN}
unset VAULT_TOKEN
echo
cyan "Lets Verify we can read /secret/dev with the newly unwrapped App-Team Token (${APP_TOKEN})"
pe "curl --header \"X-Vault-Token: ${APP_TOKEN}\" --request GET \\
      ${VAULT_ADDR}/v1/secret/data/dev | jq"

cyan "login and use the CLI"
pe "vault login ${APP_TOKEN}"

cyan "write app-team's dev secrets to the cubbyhole"
pe "vault write cubbyhole/dev/gcp access-token=my-long-token"

cyan "read app-team's dev secrets in the cubbyhole"
pe "vault read cubbyhole/dev/gcp"

cyan "now try to access the secret with the root Token.  This should NOT return a value!"
pe "VAULT_TOKEN=${temp_token} vault read cubbyhole/dev/gcp"

echo
#purple "Setting Vault token back to its original value"
export VAULT_TOKEN=${temp_token}

cyan "Removing containers and all generated files before exiting"
docker kill vaultdev