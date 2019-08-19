#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. demo-magic.sh -d -p -w ${DEMO_WAIT}

: 'multiline comment...
curl \
  --header "X-Vault-Token: $VAULT_TOKEN" \
  --request POST \
  --data '{"type": "approle"}' \
  ${VAULT_ADDR}/v1/sys/auth/approle
'

ROLE=se-app-role

cyan "Enable AppRole Auth using the API"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" \\
  --request POST \\
  --data '{\"type\": \"approle\"}' \\
  ${VAULT_ADDR}/v1/sys/auth/approle"

cyan "create an AppRole mapped to ACL policies"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" \\
  --request POST \\
  --data '{\"policies\": [\"team-se-policy\", \"my-policy\"]}' \\
  ${VAULT_ADDR}/v1/auth/approle/role/${ROLE}"

cyan "Request the role ID of the ${ROLE}"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" \\
  ${VAULT_ADDR}/v1/auth/approle/role/${ROLE}/role-id | jq"

ROLE_ID=$(
  curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
  ${VAULT_ADDR}/v1/auth/approle/role/${ROLE}/role-id | jq '.data.role_id' | sed s"/\"//g"
)

cyan "Create a new secret ID under the ${ROLE}"
p "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" \\
  --request POST \\
  ${VAULT_ADDR}/v1/auth/approle/role/${ROLE}/secret-id | jq '.data.secret_id'"

SECRET_ID=$(
curl -s --header "X-Vault-Token: $VAULT_TOKEN" --request POST \
  ${VAULT_ADDR}/v1/auth/approle/role/${ROLE}/secret-id | jq '.data.secret_id' | sed s"/\"//g"
)
echo $SECRET_ID

purple "Running 'unset VAULT_TOKEN' to ensure the new AppRole Auth is used"
temp_token=${VAULT_TOKEN}
pe "unset VAULT_TOKEN"

cyan "Fetch a Vault Token using the roleID and secretID"

pe "curl -s --request POST \\
  --data '{\"role_id\": \"${ROLE_ID}\", \"secret_id\": \"${SECRET_ID}\"}' \\
 ${VAULT_ADDR}/v1/auth/approle/login | jq"

p "export VAULT_TOKEN="
cmd

cyan "Verify we can write data to secret/, but only read from secret/foo"
green "write kv data to secret/bar: "
pe "curl --header \"X-Vault-Token: $VAULT_TOKEN\" --request POST \\
    --data '{\"robot\": \"beepboop\"}' \\
    ${VAULT_ADDR}/v1/secret/bar"

curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
    ${VAULT_ADDR}/v1/secret/bar | jq

echo
red "Expecting an Error: attempt to write data to secret/foo ... "
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" --request POST \\
    --data '{\"robot\": \"beepboop\"}' \\
    ${VAULT_ADDR}/v1/secret/foo | jq"
echo

cyan "Login to Vault UI using token: ${VAULT_TOKEN} and verify the similar access for this AppRole."
green "${VAULT_ADDR}"

export VAULT_TOKEN=${temp_token}
echo
yellow "Re-Enabling the Root Token to write data to secret/foo ... "
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" --request POST \\
  --data '{\"robot\": \"beepboop2\"}' \\
  ${VAULT_ADDR}/v1/secret/foo | jq"

curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
  ${VAULT_ADDR}/v1/secret/foo | jq

echo