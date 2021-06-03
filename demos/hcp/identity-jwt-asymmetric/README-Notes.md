# Notes

## pre-create named entities and aliases
create entity (ops-team)
```
curl \
--header "X-Vault-Token: $VAULT_TOKEN" \
--header "X-Vault-Namespace: admin/dev" \
--request POST \
--data @payload.txt \
${VAULT_ADDR}/v1/identity/entity/name/ops-team
```
read entity
```
curl \
--header "X-Vault-Token: $VAULT_TOKEN" \
--header "X-Vault-Namespace: admin/dev" \
${VAULT_ADDR}/identity/entity/name/ops-team
```

enable userpass
```
cat <<-EOF > auth.txt
{
  "type": "userpass",
  "description": "Login with Vault userpass",
  "config": {
    "default_lease_ttl": 0,
    "max_lease_ttl": 0
  }
}
EOF
```
```
curl \
--header "X-Vault-Token: $VAULT_TOKEN" \
--header "X-Vault-Namespace: admin/dev" \
--request POST \
--data @auth.txt \
${VAULT_ADDR}/v1/sys/auth/userpass
```
read userpass/ accessor
```
USERPASS_ACCESSOR=$(curl -s \
--header "X-Vault-Token: $VAULT_TOKEN" \
--header "X-Vault-Namespace: admin/dev" \
${VAULT_ADDR}/v1/sys/auth \
| jq -r '.data."userpass/".accessor')
```

create identity alias
```
cat <<-EOF > entity_alias.txt
{
  "name": "ops-userpass",
  "canonical_id": "404e57bc-a0b1-a80f-0a73-b6e92e8a52d3",
  "mount_accessor": "${USERPASS_ACCESSOR}"
}

curl \
    --header "X-Vault-Token: ..." \
    --request POST \
    --data @payload.json \
    http://127.0.0.1:8200/v1/identity/entity-alias