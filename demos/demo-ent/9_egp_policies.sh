. env.sh

echo
lblue "######################################################"
lcyan "  Configure Global Policies"
yellow "     * All Changes happen from the Internal Network"
yellow "     * Enforce AWS & Azure Key Requirements"
yellow "     * IT: Only make changes during business hrs"
lblue "######################################################"
echo
p

echo
green "policies/cidr-check.sentinel: "
p "POLICY=\$(base64 policies/cidr-check.sentinel)"
POLICY=$(base64 policies/cidr-check.sentinel)

p "vault write sys/policies/egp/cidr-check \\
        policy=\"\${POLICY}\" \\
        paths=\"kv-blog/*\" \\
        enforcement_level=\"advisory\""

vault write sys/policies/egp/cidr-check \
        policy="${POLICY}" \
        paths="kv-blog/*" \
        enforcement_level="advisory"
vault read sys/policies/egp/cidr-check
p
echo
green "policies/business-hrs.sentinel:"
vault write sys/policies/egp/business-hrs \
        policy="$(base64 policies/business-hrs.sentinel)" \
        paths="kv-blog/it/*" \
        enforcement_level="advisory"
vault read sys/policies/egp/business-hrs

# This policy checks whether any secret being written has both of the keys 
# "access_key" and "secret_key" which are used by AWS IAM keys set when configuring 
# Vault's AWS secrets engine and AWS auth method. If both keys are present, the 
# policy requires that the values assigned to the "access_key" and "secret_key" 
# keys be 20 character and 40 character strings respectively with characters 
# allowed by AWS.
echo
green "policies/validate-aws-keys.sentinel:"
vault write sys/policies/egp/validate-aws-keys \
        policy="$(base64 policies/validate-aws-keys.sentinel)" \
        paths="*" \
        enforcement_level="hard-mandatory"
#vault read sys/policies/egp/validate-aws-keys

# This policy checks whether any secret being written has the 
# "tenant_id", "client_id", and "client_secret" keys used by Vault's 
# Azure secrets engine and Azure auth method. If so, it requires 
# that the values associated with those keys as well as the value 
# associated with the "subscription_id" key if present all adhere to 
# Azure requirements. While the "subscription_id" key will always be 
# used when setting up an instance of the Azure secrets engine, we 
# don't require it to be present because it is not used by the Azure auth method.
echo
green "policies/validate-azure-credentials.sentinel:"
vault write sys/policies/egp/validate-azure-credentials \
        policy="$(base64 policies/validate-azure-credentials.sentinel)" \
        paths="*" \
        enforcement_level="hard-mandatory"
#vault read sys/policies/egp/validate-azure-credentials


#vault delete sys/policies/egp/business-hrs
#vault delete sys/policies/egp/cidr-check