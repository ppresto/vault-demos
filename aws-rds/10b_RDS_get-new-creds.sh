#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Generate a token using our dev-policy so we cna request a dynamic secrets to access the DB".
. ${DIR}/../demo-magic.sh -d -p -w ${DEMO_WAIT}


cyan "Create dev-policy.json"
tee dev-policy.json <<EOF
{
  "policy": "path \"database/creds/pg-get-creds-dev\" {capabilities = [ \"read\" ]}"
}
EOF

pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" --request PUT \\
    --data @dev-policy.json \\
    ${VAULT_ADDR}/v1/sys/policies/acl/dev-policy"

cyan "Generate a token using this policy"


p "curl --header \"X-Vault-Token: $VAULT_TOKEN\"  --request POST \\
       --data '{\"policies\": [\"dev-policy\"]}' \\
       ${VAULT_ADDR}/v1/auth/token/create | jq '.auth.client_token'"
APP_TOKEN=$(
  curl --header "X-Vault-Token: $VAULT_TOKEN"  --request POST \
       --data '{"policies": ["dev-policy"]}' \
       ${VAULT_ADDR}/v1/auth/token/create | jq '.auth.client_token' | sed "s/\"//g"
)
echo "export APP_TOKEN=${APP_TOKEN}"

cyan "Request new db credentials with our APP_TOKEN(${APP_TOKEN})"


TEMP_CREDS=$(
  curl -s --header "X-Vault-Token: $APP_TOKEN" --request GET \
    ${VAULT_ADDR}/v1/database/creds/pg-get-creds-dev
)
p "curl -s --header \"X-Vault-Token: $APP_TOKEN\" --request GET \\
    ${VAULT_ADDR}/v1/database/creds/pg-get-creds-dev |jq"
echo ${TEMP_CREDS} | jq

db_username=$(echo ${TEMP_CREDS} | jq '.data.username' | sed "s/\"//g")
db_password=$(echo ${TEMP_CREDS} | jq '.data.password' | sed "s/\"//g")
lease=$(echo ${TEMP_CREDS} | jq '.lease_id' | sed "s/\"//g")

pe "ssh -A ec2-user@${BASTION_HOST} \"psql postgresql://${db_username}:${db_password}@${db_endpoint}/${db_name}?sslmode=disable -c '\du'\""

cyan "Cleanup - Removing dev policy files"
rm ${DIR}/*.json

echo
cyan "Update your Env with the latest TOKEN and DB Credentails and alias"
echo
psql_url="postgresql://${db_username}:${db_password}@${db_endpoint}/${db_name}?sslmode=disable"
echo "export db_username=${db_username}"
echo "export db_password=${db_password}"
echo "export db_lease=${lease}"
echo "alias dbtest=\"ssh -A ec2-user@${BASTION_HOST} \\\"psql ${psql_url} -c '\du'\\\"\""


# Get new db creds using CLI
# create policy file using command below
:'####################################

tee dev-policy.json <<EOF
path "database/creds/pg-dev-creds" {
  capabilities = [ "read" ]
}
EOF

#####################################'

# vault policy write dev-policy dev-policy.json
# export APP_TOKEN=$(vault token create -policy="dev-policy" | xargs -n2 | grep -w token | awk '{print $NF}')
    # vault token create -policy="dev-policy"
    # export APP_TOKEN=XXXX
    # vault token capabilities ${APP_TOKEN} sys/auth/approle

# vault read database/creds/pg-get-creds-dev   #use existing role from lab 10: pg-get-creds-dev