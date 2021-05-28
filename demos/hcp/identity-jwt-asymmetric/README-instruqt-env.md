open https://play.instruqt.com/hashicorp/tracks/vault-ea-lab4

# If the Vault token is needed
cat config-files/vault/initialization.txt

# Install JWT Cli for decoding JWTs
apt-get update
apt install -y cargo
cargo install jwt-cli
export PATH=$PATH:/root/.cargo/bin

# policy.hcl
```hcl
path "identity/oidc/token/*" {
  capabilities = ["list", "read", "create", "update"]
}

path "identity/oidc/introspect" {
  capabilities = ["list", "read", "create", "update"]
}
```

# template.json
```json
{
    "entity_id": {{identity.entity.id}},
    "entity_name": {{identity.entity.name}}
}
```

# Enable the userpass auth method
vault auth enable userpass

# Write the Ops Team and App Team KV policies
vault policy write app-team policy.hcl
vault policy write ops-team policy.hcl

# Create sample Userpass users
vault write auth/userpass/users/ops-1 password=ops-1 policies=ops-team
vault write auth/userpass/users/app-1 password=app-1 policies=app-team

# Create sample OIDC roles
vault write identity/oidc/role/role-001 \
    key="named-key-001" ttl="12h" template=@template.json
vault write identity/oidc/role/role-002 \
    key="named-key-002" ttl="12h" template=@template.json

# Get the Role IDs
ROLE_1_CLIENT_ID=$(vault read -format=json identity/oidc/role/role-001 | jq -r .data.client_id)
ROLE_2_CLIENT_ID=$(vault read -format=json identity/oidc/role/role-002 | jq -r .data.client_id)

# Create two named keys
vault write identity/oidc/key/named-key-001 \
    rotation_period="10m" verification_ttl="30m" allowed_client_ids=$ROLE_1_CLIENT_ID

vault write identity/oidc/key/named-key-002 \
    rotation_period="10m" verification_ttl="30m" allowed_client_ids=$ROLE_2_CLIENT_ID

# Log in as one user
unset VAULT_TOKEN
vault login -format=json -method=userpass username=ops-1 password=ops-1

# Generate a signed token
vault read identity/oidc/token/role-001

# Login as the next user
export VAULT_TOKEN=$(vault login -format=json -method=userpass username=app-1 password=app-1 | jq -r .auth.client_token)

# Decode and verify the JWT (introspect won't work with a different issuer)
echo $ID_TOKEN | jwt decode -

# Show the Well Known keys on EU
curl \
    --request GET \
    --cacert /etc/consul.d/tls/consul-agent-ca.pem \
    --key /etc/consul.d/tls/eu1-client-vault-1-key.pem \
    --cert /etc/consul.d/tls/eu1-client-vault-1.pem \
    https://127.0.0.1:443/v1/identity/oidc/.well-known/keys | jq -r .


# Show the Well Known keys on NA
curl \
    --request GET \
    --cacert /etc/consul.d/tls/consul-agent-ca.pem \
    --key /etc/consul.d/tls/na1-client-vault-1-key.pem \
    --cert /etc/consul.d/tls/na1-client-vault-1.pem \
    https://127.0.0.1:443/v1/identity/oidc/.well-known/keys | jq -r .

