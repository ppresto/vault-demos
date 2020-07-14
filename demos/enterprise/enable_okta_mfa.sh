DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. env.sh

export VAULT_TOKEN=notsosecure

echo
lblue "####################################"
lcyan "  Enable MFA for the HR App DB Creds"
lblue "####################################"
echo

accessor=$(vault auth list -format=json | jq -r '.["ldap/"].accessor')

green "Configure Okta (my_okta)"
p "vault write sys/mfa/method/okta/my_okta \\
    mount_accessor=${accessor} \\
    org_name=\"dev-394102\" \\
    base_url=\"okta.com\" \\
    username_format=\"{{alias.name}}@example.com\" \\
    api_token=\"xxxxxxxxx\""      

vault write sys/mfa/method/okta/my_okta \
    mount_accessor=${accessor} \
    org_name="dev-394102" \
    base_url="okta.com" \
    username_format="{{alias.name}}@example.com" \
    api_token="00mV62G5aNT2izelMSwvblxK40U-0_OpYuiAHD-lq6"

echo
green "Review our HR DB Policy requiring MFA"
pe "cat policies/hr-okta-mfa.hcl"
p

#green "Write MFA Policy"
#cat ${DIR}/policies/okta_mfa.hcl
#p "vault policy write -namespace=IT/hr okta-policy ${DIR}/policies/okta_mfa.hcl"

#green "Re-Map IT policies to members of the 'it' LDAP group"
# Create an Ext Group in the Root NS for each ldap group you want to map policies too.
#accessor=$(vault auth list -format=json | jq -r '.["ldap/"].accessor')
#it_groupid=$(vault write -format=json identity/group name="egroup_it" type="external" | jq -r ".data.id")
# Alias Name must match LDAP group name exactly
# vault write -format=json identity/group-alias name="it" mount_accessor=$accessor canonical_id=$it_groupid
#echo
#cyan "Create Internal Group with member (egroup_it)"
# Create an Internal group in the namespace (ns-it) that has the external group as a member.
#vault write -namespace=IT identity/group name="igroup_it" policies="kv-blog,it-admin,it-admin2,okta-policy" member_group_ids=$it_groupid

# Test
#unset VAULT_TOKEN
#vault login -method=ldap -path=ldap username=deepak password=thispasswordsucks
#vault kv put -namespace=IT /kv-blog/it/servers/node2 root=notsogreat