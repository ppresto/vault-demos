. env.sh

# KV Policies

echo
green "policies/kv-it-policy.hcl: "
cat << EOF
# Allow full access to the current version of the kv-blog
path "kv-blog/data/it/*"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "kv-blog/data/it"
{
  capabilities = ["create", "read", "update", "delete", "list"]
}
EOF

pe "vault policy write kv-it policies/kv-it-policy.hcl"
