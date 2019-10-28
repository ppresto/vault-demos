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
cyan "#"
cyan "### enable userpass auth method"
cyan "#"
pe "vault auth enable userpass"
echo
cyan "#"
cyan "### create users bob (test), and bsmith (team-qa)"
cyan "#"
pe "vault write auth/userpass/users/bob password=\"training\" policies=\"test\""
pe "vault write auth/userpass/users/bsmith password=\"training\" policies=\"team-qa\""
echo
cyan "Discover the mount accessor for the userpass auth method"
pe "vault auth list -detailed"
accessor=$(vault auth list -format=json | jq -r '.["userpass/"].accessor')
cyan "store accessor: ${accessor} into accessor.txt"
vault auth list -format=json | jq -r '.["userpass/"].accessor' > accessor.txt
echo
cyan "#"
cyan "### Create an entity for bob-smith"
cyan "#"
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
TMP_TOKEN=${VAULT_TOKEN}
unset VAULT_TOKEN
echo
lcyan "#"
lcyan "### Test the Entity's attached policies"
lcyan "#"
cyan "Login as bob"
pe "vault login -method=userpass username=bob password=training"
green "Notice: the generated token has both test and base policies attached"
echo
cyan "Verify the 'test' policy by writing secrets in secret/test"
pe "vault kv put secret/test owner=\"bob\""
green "bob is a member of entity bob-smith and should inherit the base policy"
echo
cyan "check the tokens capabilities"
pe "vault token capabilities secret/data/training_test"
green "The base policy grants create/read on secret/training_*"
echo
cyan "verify secret/team-qa path isn't available to bob"
pe "vault token capabilities secret/team-qa"
green "to access team-qa path try logging in with bsmith credentials"
export VAULT_TOKEN=${TMP_TOKEN}

echo
lcyan "#"
lcyan "### Create an Interanl Group : team-eng"
lcyan "#"
echo
cyan "Create the group policy : team-eng"
p ""
tee team-eng.hcl <<EOF
# If working with kv version 2
path "secret/data/team/eng" {
  capabilities = [ "create", "read", "update", "delete"]
}

# If working with kv version 1
path "secret/team/eng" {
  capabilities = [ "create", "read", "update", "delete"]
}
EOF
pe "vault policy write team-eng ./team-eng.hcl"

echo
cyan "Create Internal Group (engineers) adding Entity (bob-smith) with Policy (team-eng)"
p "vault write identity/group name=\"engineers\" \\
        policies=\"team-eng\" \\
        member_entity_ids=${entity_id} \\
        metadata=team=\"Engineering\" \\
        metadata=region=\"North America\""

vault write identity/group name="engineers" \
        policies="team-eng" \
        member_entity_ids=${entity_id} \
        metadata=team="Engineering" \
        metadata=region="North America"

TMP_TOKEN=${VAULT_TOKEN}
unset VAULT_TOKEN
echo
lcyan "#"
lcyan "### Test the Internal Group using user: bob"
lcyan "#"
cyan "Login as bob"
pe "vault login -method=userpass username=bob password=training"
green "Notice: the generated token has team-eng policies attached"
echo
cyan "Verify the 'team-eng' policy by writing secrets in secret/team/eng"
pe "vault kv put secret/team/eng owner=\"bob\""
green "bob is a member of entity bob-smith and should inherit the team-eng policy from the Internal Group: engineers"
echo
cyan "check the tokens capabilities"
pe "vault token capabilities secret/data/team/eng"
export VAULT_TOKEN=${TMP_TOKEN}

echo
lcyan "#"
lcyan "### Create an External Group : team-eng"
lcyan "#"
echo
echo "Use External Groups to link vault with external identity providers like LDAP, Okta, AD and leverage their users -> security groups.  In this example we will allow any user who belongs to the Github organization: hashicorp, and team: se-team to perform all operations against the secret/eduction path"
echo
cyan "Setup GitHub Auth"
pe "vault auth enable github"
accessor=$(vault auth list -format=json | jq -r '."github/".accessor')
pe "vault write auth/github/config organization=hashicorp"

echo
cyan "Create the group policy : education"
p ""
tee education.hcl <<EOF
# If working with kv version 2
path "secret/data/education" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# If working with kv version 1
path "secret/education" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}
EOF
pe "vault policy write education education.hcl"

echo
cyan "Create External Group: education"
p "vault write identity/group name=\"education\" \\
        policies=\"education\" \\
        type=\"external\" \\
        metadata=organization=\"Product Education\""

ext_group=$(vault write identity/group name="education" \
        policies="education" \
        type="external" \
        metadata=organization="Product Education")
ext_groupid=$(echo ${ext_group} | xargs -n2 | grep -w id | awk '{ print $NF }')
echo ${ext_group} | xargs -n2

echo
cyan "Create a group alias mapping to your Github Team: 'team-se', and Ext Group: 'education'"
p "vault write identity/group-alias name=\"team-se\" \\
        mount_accessor=${accessor} \\
        canonical_id=\"${ext_groupid}\""

ext_groupalias=$(vault write identity/group-alias name="team-se" \
        mount_accessor="${accessor}" \
        canonical_id="${ext_groupid}")
ext_groupaliasid=$(echo ${ext_groupalias} | xargs -n2 | grep -w id | awk '{ print $NF }')
echo ${ext_groupalias} | xargs -n2

echo 
cyan "#"
cyan "### Test the External group by logging in with a Github account in Hashicorp / se-team"
cyan "#"
TMP_TOKEN=${VAULT_TOKEN}
unset VAULT_TOKEN
echo
cyan "Login with your Github token (as Hashicorp SE)"
p "vault login -method=github token=:TOKEN"
vault login -method=github token=${GITHUB_TOKEN}
green "You should see the 'education' policy attached to your token if you're in Org: Hashicorp, Team: team-se."
echo
cyan "verify the tokens capabilities (secret/education)"
pe "vault token capabilities secret/data/education"
echo
cyan "Test the 'education' policy by writing secrets in secret/education"
pe "vault kv put secret/education owner=\"se-ppresto\""
export VAULT_TOKEN=${TMP_TOKEN}

echo
cyan "Admin:  Useful Identity Lookups to Navigate Vault groups"
pe "vault list -format=json  identity/group/id | jq -r .[]"
p "for id in \$(vault list -format=json  identity/group/id | jq -r .[]); do vault read identity/group/id/\${id}; done"
   for id in $(vault list -format=json  identity/group/id | jq -r .[]); do vault read identity/group/id/${id}; done
pe "vault read identity/group/id/${ext_groupid}"
pe "vault list identity/group-alias/id   #get all external group alias ids"
pe "vault read identity/group-alias/id/${ext_groupaliasid}"

echo
cyan "Removing containers and all generated files before exiting"
export VAULT_TOKEN=${TMP_TOKEN}
docker kill vaultdev
rm ${DIR}/*.hcl
rm ${DIR}/accessor.txt