. env.sh
# DB Policies
echo
green "policies/db-hr-policy.hcl: "
cat << EOF
path "db-blog/creds/mother-hr-full-1h" {
    capabilities = [ "read" ]
}
EOF

pe "vault policy write db-hr policies/db-hr-policy.hcl"
vault policy write db-full-read policies/db-full-read-policy.hcl
vault policy write db-engineering policies/db-engineering-policy.hcl
