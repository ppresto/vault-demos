#!/bin/bash

. ../env.sh

echo
vault status

echo
cyan "Enable the transform engine"
pe "vault secrets enable transform"

echo
cyan "Create a role: (payments)"
blue "\tRoles hold the set of transformations allowed."

pe "vault write transform/role/payments transformations=ccn-fpe"

echo
cyan "Create the transformation: (ccn-fpe)"
blue "Type : fpe, masking"
blue "Tweak_source: supplied, generated, or internal"
blue "Templates: creditcardnumber, socialsecuritynumber, or custom"
pe "vault write transform/transformation/ccn-fpe \\
type=fpe \\
tweak_source=internal \\
template=ccn \\
allowed_roles=payments"

echo
cyan "Create the template: (ccn)"
blue "Templates allow us to determine what and how to capture the value that we want to transform."
pe "vault write transform/template/ccn \\
type=regex \\
pattern='\d{4}-\d{2}(\d{2})-(\d{4})-(\d{4})' \\
alphabet=numerics"

echo
cyan "Create the alphabet (numerics)"
blue "Alphabets provide the set of valid UTF-8 character contained within both the input and transformed value on FPE transformations"
#pe "vault list transform/alphabet"
pe "vault write transform/alphabet/numerics alphabet=\""0123456789\"""
echo
lblue "#############################"
lcyan " Configuration Completed"
lblue "#############################"
echo
echo
cyan "Let's Encrypt a credit card number"
blue "The output format and first 6 digits should be the same. The rest of the value is encoded ciphertext"
pe "vault write transform/encode/payments value=1111-2222-3333-4444"
ccn=$(vault write transform/encode/payments value=1111-2222-3333-4444 | grep "encoded_value" | awk '{ print $NF }')

pe "vault write transform/decode/payments value=${ccn}"

#cyan "References"
#blue "https://www.hashicorp.com/blog/transform-secrets-engine/"

echo
lblue "##############################"
lcyan " Add a Masking Transformation"
lblue "##############################"

echo
cyan "Update our role: (payments)"
blue "\tAdd a new masking transformation to the same role"
pe "vault write transform/role/payments transformations=ccn-fpe,ccn-masking"

echo
cyan "Create the new masking transformation: (ccn-masking)"
# vault list transform/template
pe "vault write transform/transformation/ccn-masking \\
type=masking \\
template=ccn_last4 \\
masking_character=# \\
allowed_roles=*"

echo
cyan "Create a custom template to show the credit cards last 4 digits (ccn_last4)"
pe "vault write transform/template/ccn_last4 \\
type=regex \\
pattern='(\d{4})-(\d{4})-(\d{4})-\d{4}' \\
alphabet=builtin/numeric"

echo
lblue "#############################"
lcyan " Configuration Completed"
lblue "#############################"
echo
echo
cyan "Lets mask the output excluding the last 4 digits of our credit card"
pe "vault write transform/encode/payments value=\"1234-1234-1234-1234\" \\
transformation=ccn-masking"
