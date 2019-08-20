#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../../demo-magic.sh -d -p -w ${DEMO_WAIT}

green "Excersise:   Store the root certificate for MySQL"
green " 
Create our root certification for MySQL  
Create an AppRole for our k/v Administrator using the kv-admin policy.  
Using this Role get a vault token to access the vault API.
Store our secret and then read/fetch it.
"

ROLE=kv-admin-role
POLICY=kv-admin-policy

cyan "Create root certification for MySQL (cert.pem)"
p "openssl req -x509 -sha256 -nodes -newkey rsa:2048 -keyout selfsigned.key -out cert.pem"

if [[ ! -f cert.pem ]]; then
  openssl req -x509 -sha256 -nodes -newkey rsa:2048 -keyout selfsigned.key -out cert.pem
else
  cat cert.pem
fi

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

cyan "Store the root cert from cert.pem to kv-v1/prod/cert/mysql"
pe "vault kv put kv-v1/prod/cert/mysql cert=@cert.pem"

cyan "Lets build an ops-app policy so our app team can read the certificate"
tee payload-ops-app-policy.json <<EOF
{
  "policy":  "# Read-only permit\npath \"kv-v1/eng/apikey/Google\" {\n  capabilities = [ \"read\" ]\n}\n\n# Read-only permit\npath \"kv-v1/prod/cert/mysql\" {\n  capabilities = [ \"read\" ]\n}"
}
EOF

curl --header "X-Vault-Token: $VAULT_TOKEN" \
       --request PUT \
       --data @payload-ops-app-policy.json \
       ${VAULT_ADDR}/v1/sys/policies/acl/apps

cyan "generate a token for use by App Ops"
APPOPS_TOKEN=$(curl -s --header "X-Vault-Token: $VAULT_TOKEN" \
       --request POST \
       --data '{"policies": ["apps"]}' \
       ${VAULT_ADDR}/v1/auth/token/create | jq '.auth.client_token'| sed s"/\"//g")
green "APPOPS_TOKEN=$APPOPS_TOKEN"

cyan "As the AppOps team, Read the root certifiate using API"
pe "curl -s --header \"X-Vault-Token: $APPOPS_TOKEN\" \\
    ${VAULT_ADDR}/v1/kv-v1/prod/cert/mysql | jq '.data.cert'"

cyan "Read the root certificate using the CLI"
pe "vault kv get -field=cert kv-v1/prod/cert/mysql"


export VAULT_TOKEN=${temp_token}
echo
yellow "Re-Enabling original Vault token"