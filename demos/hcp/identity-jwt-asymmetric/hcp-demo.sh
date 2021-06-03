#!/bin/bash

# References:
# Identity Backend: https://www.vaultproject.io/api/secret/identity/tokens
# Identity Token Claims: https://www.vaultproject.io/docs/secrets/identity#token-contents-and-templates
# Identity API: https://www.vaultproject.io/api/secret/identity
# JWT Claims: https://www.vaultproject.io/docs/auth/jwt#bound-claims

# Pre-Reqs:
# Set the required env variables to use the CLI.  Use TFCB outputs for this.
# export VAULT_ADDR=https://hcp-vault-cluster.vault.11eb13d3-0dd1-af4a-9eb3-0242ac110018.aws.hashicorp.cloud:8200
# export VAULT_TOKEN=s.######
# export VAULT_NAMESPACE=admin

# Create dev namespace
vault namespace create dev

# Manage namespace admin/dev
export VAULT_NAMESPACE=admin/dev

# Enable the userpass auth method
# Auth methods: https://www.vaultproject.io/docs/auth
vault auth enable userpass

# Write the Ops Team and App Team KV policies
vault policy write app-team policies/app-team-policy.hcl
vault policy write ops-team policies/ops-team-policy.hcl

# Create sample Userpass users
vault write auth/userpass/users/ops-1 password=ops-1 policies=ops-team
vault write auth/userpass/users/app-1 password=app-1 policies=app-team

# Write the configuration
echo "Write OIDC configuration"

vault write identity/oidc/config issuer="${VAULT_ADDR}"

# Read the configuration
vault read -format=json identity/oidc/config | jq -r .data

# Create two roles.  ID tokens are generated against a role and its  configured key.
# Define Claims in token_template: https://www.vaultproject.io/docs/secrets/identity#token-contents-and-templates
vault write identity/oidc/role/role-ops \
    key="key-ops-1" ttl="12h" template=@token_template.json
vault write identity/oidc/role/role-app \
    key="key-app-1" ttl="12h" template=@token_template.json

# Get the Role IDs
vault read -format=json identity/oidc/role/role-ops | jq -r
ROLE_OPS_1_CLIENT_ID=$(vault read -format=json identity/oidc/role/role-ops | jq -r .data.client_id)
ROLE_APP_1_CLIENT_ID=$(vault read -format=json identity/oidc/role/role-app | jq -r .data.client_id)

# Create two named keys.  The associated role uses the key to sign the token.
vault write identity/oidc/key/key-ops-1 \
    rotation_period="10m" verification_ttl="30m" allowed_client_ids=$ROLE_OPS_1_CLIENT_ID

vault write identity/oidc/key/key-app-1 \
    rotation_period="10m" verification_ttl="30m" allowed_client_ids=$ROLE_APP_1_CLIENT_ID

# Read the keys
vault read identity/oidc/key/key-ops-1
vault read identity/oidc/key/key-app-1

# Sign in as the ops-1 user
echo "Sign in as the ops-1 user"

unset VAULT_TOKEN
vault login -format=json -method=userpass username=ops-1 password=ops-1

# Generate a signed ID (OIDC) token
echo "Generate a signed ID (OIDC) token"

vault read identity/oidc/token/role-ops
TOKEN_DATA=$(vault read -format=json identity/oidc/token/role-ops)
CLIENT_ID=$(echo $TOKEN_DATA | jq -r .data.client_id)
ID_TOKEN=$(echo $TOKEN_DATA | jq -r .data.token)

# Sign in as the App user
export VAULT_TOKEN=$(vault login -format=json -method=userpass username=app-1 password=app-1 | jq -r .auth.client_token)

# Get the key id from the JWT
echo $TOKEN_DATA | jq -r .data.token | jwt decode -

# create verify.json payload for introspection/validation
cat <<-EOF > verify.json
{
    "token": "${ID_TOKEN}"
}
EOF

# Verify the authenticity and active state of the signed ID token.
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --header "X-Vault-Namespace: admin/dev" \
    --request POST \
    --data @verify.json \
    ${VAULT_ADDR}/v1/identity/oidc/introspect


# Read the Well Known config to retrieve a set of claims about the identity tokens' configuration.
# this response is a compliant OpenID Provider configuration response.
curl \
    --header "X-Vault-Namespace: admin/dev" \
    --request GET \
    ${VAULT_ADDR}/v1/identity/oidc/.well-known/openid-configuration | jq -r .

# Show the Well Known keys
# This is the public portion of the named keys. Clients can use this to validate the authenticity of an identity token
curl \
    --header "X-Vault-Namespace: admin/dev" \
    --request GET \
    ${VAULT_ADDR}/v1/identity/oidc/.well-known/keys | jq -r .

# Rotate a Named Key as app1 fails
vault write -force -format=json identity/oidc/key/key-app-1/rotate

# Rotate a Named Key successfully as user ops-1
echo "Login as ops-1 user with policy that allows key rotation"
unset VAULT_TOKEN
export VAULT_TOKEN=$(vault login -format=json -method=userpass username=ops-1 password=ops-1 | jq -r .auth.client_token)

echo "Current well-known keys:"
curl \
    --header "X-Vault-Namespace: admin/dev" \
    --request GET \
    ${VAULT_ADDR}/v1/identity/oidc/.well-known/keys | jq -r '.keys[].kid'
echo 
echo "Rotate key-app-1"
echo
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --header "X-Vault-Namespace: admin/dev" \
    --request POST \
    --data '{"verification_ttl": 0}' \
    ${VAULT_ADDR}/v1/identity/oidc/key/key-app-1/rotate

echo "Updated well-known keys:"
curl \
    --header "X-Vault-Namespace: admin/dev" \
    --request GET \
    ${VAULT_ADDR}/v1/identity/oidc/.well-known/keys | jq -r '.keys[].kid'