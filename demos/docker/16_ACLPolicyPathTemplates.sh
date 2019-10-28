#!/bin/bash
#
#
#  https://learn.hashicorp.com/vault/identity-access-management/iam-policies
#  
#  Root/Sudo protect API endpoints
#  https://learn.hashicorp.com/vault/identity-access-management/iam-policies#root-protected-api-endpoints
#  

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi


# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../demo-magic.sh -d -p -w ${DEMO_WAIT}

echo
lblue "###########################################"
lcyan "  ACL Policy Path Templating Requirements"
lblue "###########################################"
echo
echo "Each user can perform all operations on their allocated key/value secret path (user-kv/data/<user_name>)"
echo
echo "The education group has a dedicated key/value secret store for each region where all operations can be performed by the group members (group-kv/data/education/<region>)"
echo
echo "The group members can update the group information such as metadata about the group (identity/group/id/<group_id>)"
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
cyan "### Create templated ACL Policy: user-tmpl.hcl"
cyan "#"
tee user-tmpl.hcl <<EOF
# Grant permissions on user specific path.
path "user-kv/data/{{identity.entity.name}}/*" {
    capabilities = [ "create", "update", "read", "delete", "list" ]
}

# For Web UI usage
path "user-kv/metadata" {
  capabilities = ["list"]
}
EOF
lpurple "The above Path will translate to /user-kv/data/bob_smith/* after we create this Entity"
echo
pe "vault policy write user-tmpl user-tmpl.hcl"

echo
cyan "#"
cyan "### Create templated ACL Policy: group-tmpl.hcl"
cyan "#"
tee group-tmpl.hcl <<EOF
# Grant permissions on the group specific path
# The region is specified in the group metadata
path "group-kv/data/education/{{identity.groups.names.education.metadata.region}}/*" {
    capabilities = [ "create", "update", "read", "delete", "list" ]
}

# Group member can update the group information
path "identity/group/id/{{identity.groups.names.education.id}}" {
  capabilities = [ "update", "read" ]
}

# For Web UI usage
path "group-kv/metadata" {
  capabilities = ["list"]
}

path "identity/group/id" {
  capabilities = [ "list" ]
}
EOF
lpurple "The top path will translate to group-kv/data/education/us-west/* once we create the education group with metadata (region=us-west)"
echo
pe "vault policy write group-tmpl group-tmpl.hcl"

echo
cyan "#"
cyan "### Setup an Entity (bob_smith) with user (bob).  Add the Entity to Group: education"
cyan "#"
echo
cyan "Enable userpass"
pe "vault auth enable userpass"
echo
cyan "Create User: bob"
pe "vault write auth/userpass/users/bob password=\"training\""
echo
cyan "Get the userpass mount accessor for the entity alias later"
p "accessor=\$(vault auth list -format=json | jq -r '.[\"userpass/\"].accessor'"
accessor=$(vault auth list -format=json | jq -r '.["userpass/"].accessor')
echo
cyan "Create Entity: bob_smith"
p "entity=\$(vault write -format=json identity/entity name=\"bob_smith\" policies=\"user-tmpl\" | jq -r \".data.id\""
entity=$(vault write -format=json identity/entity name="bob_smith" policies="user-tmpl" | jq -r ".data.id")
echo
cyan "Add an Entity Alias mapping bob to the bob_smith entity"
p "vault write identity/entity-alias name=\"bob\" \\
       canonical_id=${entity} \\
       mount_accessor=${accessor}"

vault write identity/entity-alias name="bob" \
       canonical_id=${entity} \
       mount_accessor=${accessor}
echo
cyan "Create Group: education and add Entity: bob_smith as a member"
p "vault write -format=json identity/group name=\"education\" \\
      policies=\"group-tmpl\" \\
      metadata=region=\"us-west\" \\
      member_entity_ids=${entity} \\
      | jq -r \".data.id\""

group=$(vault write -format=json identity/group name="education" \
      policies="group-tmpl" \
      metadata=region="us-west" \
      member_entity_ids=${entity})
echo $group | jq -r
groupid=$(echo ${group} | jq -r ".data.id")
echo
cyan "Enable key/value v2 secrets engine at user-kv, and group-kv"
pe "vault secrets enable -path=user-kv kv-v2"
pe "vault secrets enable -path=group-kv kv-v2"

TMP_TOKEN=${VAULT_TOKEN}
unset VAULT_TOKEN
echo
cyan "Login (bob)"
pe "vault login -method=userpass username=\"bob\" password=\"training\""
echo
cyan "Verify the user-tmpl policy (user-kv/data/bob_smith)"
pe "vault kv put user-kv/bob_smith/apikey webapp=\"myApiKey##\""
echo
cyan "Verify the group-tmpl policy (group-kv/data/education/us-west/*)"
pe "vault kv put group-kv/education/us-west/db_cred password=\"us-west-PASSWORD###\""
echo
cyan "Verify group-tmpl allows us to update identity/group/id/${groupid}"
p "vault write identity/group/id/${groupid} \\
        policies=\"group-tmpl\" \\
        metadata=region=\"us-west\" \\
        metadata=contact_email=\"ppresto@hashicorp.com\""

vault write identity/group/id/${groupid} \
        policies="group-tmpl" \
        metadata=region="us-west" \
        metadata=contact_email="ppresto@hashicorp.com"
pe "vault read identity/group/id/${groupid}"
export VAULT_TOKEN=${TMP_TOKEN}

echo
cyan "Removing containers and all generated files before exiting"
pe "docker kill vaultdev"
rm ${DIR}/*.hcl