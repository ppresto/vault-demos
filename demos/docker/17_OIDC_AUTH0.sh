#!/bin/bash
#
#
#  https://learn.hashicorp.com/vault/identity-access-management/oidc-auth
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
lcyan "  OIDC Auth Method with AUTH0"
lblue "###########################################"
echo
echo "Delegated authorization methods based on OAuth 2.0 are convenient for users and have become increasingly common"
echo
echo "The OIDC auth method allows a user's browser to be redirected to a configured identity provider, complete login, and then be routed back to Vault's UI with a newly-created Vault token."
echo
echo "PreReq:  Setup Free Auth0 Account: https://manage.auth0.com"
echo "\t Allowed Callback URLS: http://127.0.0.1:8200/ui/vault/auth/oidc/oidc/callback, http://127.0.0.1:8250/oidc/callback"
echo "Advanced Settings: Select Algorith RS256"
echo
echo "\tEnv:"
echo "\texport AUTH0_DOMAIN AUTH0_CLIENT_ID AUTH0_CLIENT_SECRET"
echo
if [[ ! $(env | grep AUTH0) ]]; then
  echo "THis script requires the following variables to be set"
  echo "AUTH0_DOMAIN, AUTH0_CLIENT_ID, AUTH0_CLIENT_SECRET"
  exit 1
fi

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
cyan "### Create Policy: manager.hcl"
cyan "#"
tee manager.hcl <<EOF
# Manage k/v secrets
path "/secret/*" {
    capabilities = ["create", "read", "update", "delete", "list"]
}
EOF
pe "vault policy write manager manager.hcl"
echo
cyan "#"
cyan "### Create Policy: reader.hcl"
cyan "#"
tee reader.hcl <<EOF
# Read permission on the k/v secrets
path "/secret/*" {
    capabilities = ["read", "list"]
}
EOF
pe "vault policy write reader reader.hcl"
echo
cyan "List Polcies"
pe "vault policy list"
echo
cyan "#"
cyan "### Enable OIDC auth method"
cyan "#"
pe "vault auth enable oidc"
echo
cyan "Configure OIDC Auth with AUTH0"
p "vault write auth/oidc/config \\
        oidc_discovery_url=\"https://$AUTH0_DOMAIN/\" \\
        oidc_client_id=\"$AUTH0_CLIENT_ID\" \\
        oidc_client_secret=\"$AUTH0_CLIENT_SECRET\" \\
        default_role=\"reader\""

vault write auth/oidc/config \
        oidc_discovery_url="https://$AUTH0_DOMAIN/" \
        oidc_client_id="$AUTH0_CLIENT_ID" \
        oidc_client_secret="$AUTH0_CLIENT_SECRET" \
        default_role="reader"
echo
cyan "Create the reader role with the AUTH0 Allowed_Callback_URLs as allowed_redirect_uris"
p "vault write auth/oidc/role/reader \\
        bound_audiences=\"$AUTH0_CLIENT_ID\" \\
        allowed_redirect_uris=\"http://localhost:8200/ui/vault/auth/oidc/oidc/callback\" \\
        allowed_redirect_uris=\"http://localhost:8250/oidc/callback\" \\
        user_claim=\"sub\" \\
        policies=\"reader\""

vault write auth/oidc/role/reader \
        bound_audiences="${AUTH0_CLIENT_ID}" \
        allowed_redirect_uris="http://localhost:8200/ui/vault/auth/oidc/oidc/callback" \
        allowed_redirect_uris="http://localhost:8250/oidc/callback" \
        user_claim="sub" \
        policies="reader"
echo
TMP_TOKEN=${VAULT_TOKEN}
unset VAULT_TOKEN
cyan "Login with OIDC (accept Default App Auth Propmt)"
pe "vault login -method=oidc role=\"reader\""

# Set VAULT_TOKEN back to root to create the ext group and alias
export VAULT_TOKEN=my_root_token_id

echo
cyan "Create a 'manager' group in AUTH0"
lpurple "https://learn.hashicorp.com/vault/identity-access-management/oidc-auth"
p ""
cyan "#"
cyan "### Create an External Group in vault"
cyan "#"

echo
cyan "Creating role 'kv-mgr' for our Auth0 User"
p "vault write auth/oidc/role/kv-mgr \\
        bound_audiences=\"$AUTH0_CLIENT_ID\" \\
        allowed_redirect_uris=\"http://127.0.0.1:8200/ui/vault/auth/oidc/oidc/callback\" \\
        allowed_redirect_uris=\"http://localhost:8250/oidc/callback\" \\
        user_claim=\"sub\" \\
        policies=\"reader\" \\
        groups_claim=\"https://example.com/roles\""

vault write auth/oidc/role/kv-mgr \
        bound_audiences="$AUTH0_CLIENT_ID" \
        allowed_redirect_uris="http://127.0.0.1:8200/ui/vault/auth/oidc/oidc/callback" \
        allowed_redirect_uris="http://localhost:8250/oidc/callback" \
        user_claim="sub" \
        policies="reader" \
        groups_claim="https://example.com/roles"

echo
cyan "Create ext group 'manager' with policy attached"
p "vault write identity/group name=\"manager\" type=\"external\" \\
        policies=\"manager\" \\
        metadata=responsibility=\"Manage K/V Secrets\""

group_mgr=$(vault write identity/group name="manager" type="external" \
        policies="manager" \
        metadata=responsibility="Manage K/V Secrets")
group_id=$(echo ${group_mgr} | xargs -n2 | grep id | awk '{ print $2 }')

accessor=$(vault auth list -format=json | jq -r '."oidc/".accessor')

echo
cyan "Create a group alias"
p "vault write identity/group-alias name=\"kv-mgr\" \\
        mount_accessor=${accessor} \\
        canonical_id=\"${group_id}\""

vault write identity/group-alias name="kv-mgr" \
        mount_accessor=${accessor} \
        canonical_id="${group_id}"

echo
cyan "#"
cyan "### Login with the 'kv-mgr' role"
cyan "#"
green "Notice: the token should inherit the manager policy from the manager group since the kv-mgr belongs to the manager group."
unset VAULT_TOKEN
p "vault login -method=oidc role=\"kv-mgr\""
vault login -method=oidc role="kv-mgr"

echo
cyan "Removing containers and all generated files before exiting"
pe "docker kill vaultdev"
rm ${DIR}/*.hcl
