. env.sh

echo
lblue "################################################"
lcyan "  Configure sub-namespace IT/hr for hr app team"
lblue "################################################"
echo

vault namespace create -namespace=IT hr
vault secrets enable -namespace=IT/hr -path=kv-blog -version=2 kv
vault policy write -namespace=IT/hr kv-blog policies/kv-blog-hr-policy.hcl
vault policy write -namespace=IT/hr it-hr-admin policies/it-hr-admin.hcl
vault policy write -namespace=IT/hr it-admin policies/it-admin.hcl