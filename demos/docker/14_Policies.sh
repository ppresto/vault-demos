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
lblue "#############"
lcyan "  Policies"
lblue "#############"

echo
lpurple "Gather Policy Requirements ..."
echo
cyan "Admin:\nWill manage a vault infra for a team or org.  Needs to config and maint the health of the vault cluster and support users. \nRequirements:\nManage auth methods, k/v engines, and ACL policies across Vault"
echo
cyan "Provisioner:\nUser or Service tha twill provision/configure a namespace within a vault secret engine for new users to access and write secrets. \nRequirements:\nManage auth methods, k/v engines, and ACL policies"

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
cyan "### Create admin-policy.hcl"
cyan "#"
tee admin-policy.hcl <<EOF
# Manage auth methods broadly across Vault
path "auth/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Create, update, and delete auth methods
path "sys/auth/*"
{
  capabilities = ["create", "update", "delete", "sudo"]
}

# List auth methods
path "sys/auth"
{
  capabilities = ["read"]
}

# List existing policies
path "sys/policies/acl"
{
  capabilities = ["list"]
}

# Create and manage ACL policies
path "sys/policies/acl/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List, create, update, and delete key/value secrets
path "secret/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Manage secret engines
path "sys/mounts/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List existing secret engines.
path "sys/mounts"
{
  capabilities = ["read"]
}

# Read health checks
path "sys/health"
{
  capabilities = ["read", "sudo"]
}
EOF
echo
cyan "Write admin-policy"
pe "vault policy write admin admin-policy.hcl"

echo
cyan "Verify the admin-policy"
pe "vault policy list"
pe "vault policy read admin"
echo
cyan "#"
cyan "### Test policy by creating a token and fetching the capabilities"
cyan "#"
p "vault token create -policy=admin"
t_admin=$(vault token create -policy="admin")
token=$(echo ${t_admin} | xargs -n2 | grep -w token | awk '{ print $NF }')
echo ${t_admin} | xargs -n2
echo
cyan "Fetch token capabilities on path sys/auth/approle"
pe "vault token capabilities ${token} sys/auth/approle"
lgreen "you should see create, delete, sudo, update"

echo
cyan "Create provisioner-policy.hcl"
tee provisioner-policy.hcl <<EOF
# Manage auth methods broadly across Vault
path "auth/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# Create, update, and delete auth methods
path "sys/auth/*"
{
  capabilities = ["create", "update", "delete", "sudo"]
}

# List auth methods
path "sys/auth"
{
  capabilities = ["read"]
}

# List existing policies
path "sys/policies/acl"
{
  capabilities = ["list"]
}

# Create and manage ACL policies via API & UI
path "sys/policies/acl/*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}

# List, create, update, and delete key/value secrets
path "secret/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
echo
cyan "Write provisioner-policy"
pe "vault policy write provisioner provisioner-policy.hcl"

echo
cyan "Removing containers and all generated files before exiting"
pe "docker kill vaultdev"
#rm ${DIR}/admin-policy.hcl ${DIR}/provisioner-policy.hcl