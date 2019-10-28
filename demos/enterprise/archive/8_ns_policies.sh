. env.sh

echo
lblue "###########################################"
lcyan "  Configure IT Namespaces"
lblue "###########################################"
echo
green "Create namespace IT "
pe "vault namespace create IT"
echo
green "enable the kv engine in the IT namespace"
pe "vault secrets enable -namespace=IT -path=kv-blog -version=2 kv"
echo 
green "create a policy to make the IT team admins in the IT namesapce"
vault policy write -namespace=IT it-admin policies/it-admin.hcl
# KV Policies
echo
green "create a policy that only allows the IT team access to this kv"
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
pe "vault policy write -namespace=IT kv-blog policies/kv-blog-it-policy.hcl"

echo
# "Create Ext/Int Group for IT"
green "Apply policies in the IT namespace to LDAP users in the IT group"
# Get the LDAP Accessor
accessor=$(vault auth list -format=json | jq -r '.["ldap/"].accessor')
# Create an Ext Group in the Root NS (which is hosting LDAP) for each group you want to map policies too.
it_groupid=$(vault write -format=json identity/group name="egroup_it" type="external" | jq -r ".data.id")
# Create a Group Alias Name which must match LDAP group name exactly
vault write -format=json identity/group-alias name="it" mount_accessor=$accessor canonical_id=$it_groupid
# Create an Int group in the namespace (IT), apply policies to it, and add the external group as a member.
pe "vault write -namespace=IT identity/group name="igroup_it" policies="kv-blog,it-admin" member_group_ids=$it_groupid"


echo
green "Create another namespace for IT's hr support team (IT/hr)"
pe "vault namespace create -namespace=IT hr"
#vault secrets enable -namespace=IT/hr -path=kv-blog -version=2 kv
#vault policy write -namespace=IT/hr kv-blog policies/kv-blog-hr-policy.hcl
vault policy write -namespace=IT/hr it-hr-admin policies/it-hr-admin.hcl


# "Create Ext/Int Group for Engineering"
#echo
#green "Engineering"
#eng_groupid=$(vault write -format=json identity/group name="egroup_eng" type="external" | jq -r ".data.id")
#vault write -format=json identity/group-alias name="engineering" mount_accessor=$accessor canonical_id=$eng_groupid
#vault write identity/group name="igroup_eng" policies="db-engineering,kv-user-template" member_group_ids=$eng_groupid

# "Create Ext/Int Group for Security"
#echo
#green "Security"
#sec_groupid=$(vault write -format=json identity/group name="egroup_security" type="external" | jq -r ".data.id")
#vault write -format=json identity/group-alias name="security" mount_accessor=$accessor canonical_id=$sec_groupid
#vault write identity/group name="igroup_security" policies="db-full-read,kv-user-template" member_group_ids=$sec_groupid

