#!/bin/bash
#
#
#  https://learn.hashicorp.com/vault/identity-access-management/iam-identity
#  
#  

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi


# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../demo-magic.sh -d -p -w ${DEMO_WAIT}

echo
lblue "#######################"
lcyan "  Entities and Groups"
lblue "#######################"

echo
cyan "Start your Vault Server"
pe "docker run -d --rm -p 8200:8200 --name vaultdev \\
    --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=my_root_token_id' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault"

export VAULT_TOKEN=my_root_token_id
export VAULT_ADDR="http://127.0.0.1:8200"
env | grep VAULT
sleep 1
vault status

echo
cyan "#"
cyan "### Create base.hcl"
cyan "#"
tee base.hcl <<EOF
# If working with kv version 2 (dev server default)
path "secret/data/training_*" {
   capabilities = ["create", "read"]
}

# If working with kv version 1 (non-dev server)
path "secret/training_*" {
   capabilities = ["create", "read"]
}
EOF
echo
cyan "Write base policy"
pe "vault policy write base base.hcl"

cyan "#"
cyan "### Create test.hcl"
cyan "#"
tee test.hcl <<EOF
# If working with kv version 2 (dev server default)
path "secret/data/test" {
   capabilities = [ "create", "read", "update", "delete" ]
}

# If working with kv version 1 (non-dev server)
path "secret/test" {
   capabilities = [ "create", "read", "update", "delete" ]
}
EOF
echo
cyan "Write test policy"
pe "vault policy write test test.hcl"

cyan "#"
cyan "### Create team-qa.hcl"
cyan "#"
tee team-qa.hcl <<EOF
# If working with kv version 2 (dev server default)
path "secret/data/team-qa" {
   capabilities = [ "create", "read", "update", "delete" ]
}

# If working with kv version 1 (non-dev server)
path "secret/team-qa" {
   capabilities = [ "create", "read", "update", "delete" ]
}
EOF
echo
cyan "Write team-qa policy"
pe "vault policy write team-qa team-qa.hcl"

echo
cyan "List all policies to verify that 'base', 'test' and 'team-qa' policies exist"
pe "vault policy list"

echo
cyan "enable userpass auth method"
pe "vault auth enable userpass"

pe "vault write auth/userpass/users/bob password=\"training\" policies=\"test\""
pe "vault write auth/userpass/users/bsmith password=\"training\" policies=\"team-qa\""
echo
cyan "Discover the mount accessor for the userpass auth method"
pe "vault auth list -detailed"
accessor=$(vault auth list -format=json | jq -r '.["userpass/"].accessor')
cyan "store accessor: ${accessor} into accessor.txt"
vault auth list -format=json | jq -r '.["userpass/"].accessor' > accessor.txt

cyan "Create an entity for bob-smith"
p "vault write identity/entity name=\"bob-smith\" policies=\"base\" \\
metadata=organization=\"ACME Inc.\" \\
metadata=team=\"QA\""

entity=$(vault write identity/entity name="bob-smith" policies="base" \
metadata=organization="ACME Inc." \
metadata=team="QA")
entity_id=$(echo ${entity} | xargs -n2 | grep -w id | awk '{ print $2 }')
echo ${entity} | xargs -n2

echo
cyan "Add user bob to the bob-smith identity"
p "vault write identity/entity-alias name=\"bob\" \\
        canonical_id=${entity_id} \\
        mount_accessor=$(cat accessor.txt)"

vault write identity/entity-alias name="bob" \
        canonical_id=${entity_id} \
        mount_accessor=$(cat accessor.txt)

cyan "Add user bsmith to the bob-smith identity"
p "vault write identity/entity-alias name=\"bsmith\" \\
        canonical_id=${entity_id} \\
        mount_accessor=$(cat accessor.txt)"

vault write identity/entity-alias name="bsmith" \
        canonical_id=${entity_id} \
        mount_accessor=$(cat accessor.txt)
echo
cyan "Review the Entity Details"
pe "vault read identity/entity/id/${entity_id}"
green "The output should include the entity aliases, metadata (organization, and team), and base policy."
echo
cyan "enable secrets engine at secret/"
pe "vault secrets enable -path=secret/ kv-v2"

echo
cyan "Removing containers and all generated files before exiting"
pe "docker kill vaultdev"
rm ${DIR}/*.hcl