#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../demo-magic.sh -d -p -w ${DEMO_WAIT}

green "Applications ask Vault for database credential rather than setting them as environment variables. The administrator specifies the TTL of the database credentials to enforce its validity so that they are automatically revoked when they are no longer used.  Each app instance can get unique credentials that they don't have to share. By making those credentials to be short-lived, you reduced the chance of the secret being compromised."
echo

cyan "Step 1: Verify Vault Env Setup from rdsSetup_temmplate.sh: (VAULT_TOKEN, VAULT_ADDR, db_, and BASTION_HOST)"
env | grep VAULT
env | grep db_
env | grep BASTION_HOST

echo
cyan "Step 2: Enable the Database Dynamic Secrets Engine"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" --request POST \\
    --data '{\"type\": \"database\"}' \\
    ${VAULT_ADDR}/v1/sys/mounts/database |jq"

cyan "Step 3: Configure the Postgres DB Connection using templates instead of the actual user/pass values"
tee postgres.json <<EOF
{
  "plugin_name": "postgresql-database-plugin",
  "allowed_roles": "*",
  "connection_url": "postgresql://{{username}}:{{password}}@${db_endpoint}/${db_name}?sslmode=disable",
  "username": "${db_username}",
  "password": "${db_password}"
}
EOF

pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" --request POST \\
    --data @postgres.json \\
    ${VAULT_ADDR}/v1/database/config/postgresql |jq"

cyan "Step 4: Create the Role vault will use to generate postgres user credentials"
tee pg-get-creds-dev.json <<EOF
{
    "db_name": "postgresql",
    "creation_statements": ["CREATE ROLE \"{{name}}\" WITH LOGIN PASSWORD '{{password}}' VALID UNTIL '{{expiration}}';
  GRANT SELECT ON ALL TABLES IN SCHEMA public TO \"{{name}}\";"],
    "default_ttl": "1h",
    "max_ttl": "24h"
}
EOF

pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" --request POST \\
    --data @pg-get-creds-dev.json \\
    ${VAULT_ADDR}/v1/database/roles/pg-get-creds-dev"

cyan "Step 5: Rotate Root Credentials"
blue "Lets test the current root credentials, rotate them, and verify the original credentials no longer work"
blue "Testing Connection with known root credentials"
pe "ssh -A ec2-user@${BASTION_HOST} \"psql postgresql://${db_username}:${db_password}@${db_endpoint}/${db_name}?sslmode=disable -c '\du'\""

blue "Rotate Root Credentials"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" --request POST \\
    ${VAULT_ADDR}/v1/database/rotate-root/postgresql"

blue "Lets test our original root credentials again.  This should fail"
pe "ssh -A ec2-user@${BASTION_HOST} \"psql postgresql://${db_username}:${db_password}@${db_endpoint}/${db_name}?sslmode=disable -c '\du'\""


cyan "Step 6: Lets Verify the new credentials are working and we can generate dynamic secrets still"
tee dev-policy.json <<EOF
{
  "policy": "path \"database/creds/pg-get-creds-dev\" {capabilities = [ \"read\" ]}"
}
EOF

pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" --request PUT \\
    --data @dev-policy.json \\
    ${VAULT_ADDR}/v1/sys/policies/acl/dev-policy"

cyan "Step 6: Generate our dev-team a token using this policy.  We will use this token to generate postgres credentials."
p "curl --header \"X-Vault-Token: $VAULT_TOKEN\"  --request POST \\
       --data '{\"policies\": [\"dev-policy\"]}' \\
       ${VAULT_ADDR}/v1/auth/token/create | jq '.auth.client_token'"
APP_TOKEN=$(
  curl --header "X-Vault-Token: $VAULT_TOKEN"  --request POST \
       --data '{"policies": ["dev-policy"]}' \
       ${VAULT_ADDR}/v1/auth/token/create | jq '.auth.client_token' | sed "s/\"//g"
)
echo "dev-team's new token: ${APP_TOKEN}"

cyan "Let's request db credentials and test our DB Connection"

TEMP_CREDS=$(
  curl -s --header "X-Vault-Token: $APP_TOKEN" --request GET \
    ${VAULT_ADDR}/v1/database/creds/pg-get-creds-dev
)
p "curl -s --header \"X-Vault-Token: $APP_TOKEN\" --request GET \\
    ${VAULT_ADDR}/v1/database/creds/pg-get-creds-dev |jq"
echo ${TEMP_CREDS} | jq

username=$(echo ${TEMP_CREDS} | jq '.data.username' | sed "s/\"//g")
password=$(echo ${TEMP_CREDS} | jq '.data.password' | sed "s/\"//g")
lease=$(echo ${TEMP_CREDS} | jq '.lease_id' | sed "s/\"//g")

pe "ssh -A ec2-user@${BASTION_HOST} \"psql postgresql://${username}:${password}@${db_endpoint}/${db_name}?sslmode=disable -c '\du'\""

cyan "Finally lets revoke the lease and connect to the DB.  We should see an authentication error"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" --request PUT \\
    --data '{\"lease_id\": \"${lease}\"}' \\
    ${VAULT_ADDR}/v1/sys/leases/revoke"

pe "ssh -A ec2-user@${BASTION_HOST} \"psql postgresql://${username}:${password}@${db_endpoint}/${db_name}?sslmode=disable -c '\du'\""

#yellow "'unset VAULT_TOKEN' to ensure new credentials are used"
#temp_token=${VAULT_TOKEN}
#unset VAULT_TOKEN

#purple "Setting Vault token back to its original value"
#export VAULT_TOKEN=${temp_token}
cyan "Removing all generated files before exiting"
rm ${DIR}/*.json