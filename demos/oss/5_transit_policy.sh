. env.sh

# Transit Policies
echo
green "policies/transit-hr-policy.hcl: "
cat << EOF
path "transit-blog/encrypt/hr" {
  capabilities = [ "create", "read", "update" ]
}

path "transit-blog/decrypt/hr" {
  capabilities = [ "create", "read", "update" ]
}
EOF

pe "vault policy write transit-hr policies/transit-hr-policy.hcl"
