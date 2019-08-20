#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../../demo-magic.sh -d -p -w ${DEMO_WAIT}

# Policy Example
: 'vault policy write kv2-admin-policy -<<EOF
# Write and manage secrets in key/value secret engine
path "secret*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Enable key/value secret engine at the kv-v1 path
path "sys/mounts/kv-v1" {
  capabilities = [ "update" ]
}

# To enable secret engines
path "sys/mounts/*" {
  capabilities = [ "create", "read", "update", "delete" ]
}

# Create policies to permit apps to read secrets
path "sys/policies/acl/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# Create tokens for verification & test
path "auth/token/create" {
  capabilities = [ "create", "update", "sudo" ]
}
EOF'


cyan "Is secret/ using k/v version 2?"
pe "vault secrets list -detailed"

cyan "If not, lets upgrade to v2"
pe "vault kv enable-versioning secret/"

cyan "Check the kv engine version using the API"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" \\
  ${VAULT_ADDR}/v1/sys/mounts | jq"

cyan "Lets create a secret"
pe "vault kv put secret/customer/acme name=\"ACME Inc.\" contact_email=\"jsmith@acme.com\""

cyan "lets update the secret with a new email address"
pe "vault kv put secret/customer/acme name=\"ACME Inc.\" contact_email=\"john.smith@acme.com\""

cyan "Now we have 2 versions of a secret.  Lets read version=1"
pe "vault kv get -version=1 secret/customer/acme"

cyan "if you just want to update a single field in a secret use 'patch'"
pe "vault kv patch secret/customer/acme contact_email=\"admin@acme.com\""

cyan "limit the number of versions to 4 for secret/customer/acme"
pe "vault kv metadata put -max-versions=4 secret/customer/acme"

cyan "write a few more versions of the secret to test -max-versions setting"
vault kv put secret/customer/acme name="ACME Inc." contact_email="john1@acme.com"
vault kv put secret/customer/acme name="ACME Inc." contact_email="john2@acme.com"
vault kv put secret/customer/acme name="ACME Inc." contact_email="john3@acme.com"

cyan "read the secret metadata and notice version 1,2 are no longer available"
pe "vault kv metadata get secret/customer/acme"

cyan "Accidental data loss with 'put'. The updated secret will contain email and the name field will be lost"
pe "vault kv put secret/customer/acme contact_email=\"admin@acme.com\""
echo
cyan "Previous Version Has both fields: name and contact_email"
vault kv get -version=6 secret/customer/acme
cyan "Current Version is missing the name field"
vault kv get secret/customer/acme

cyan "Lets delete the latest version"
pe "vault kv delete -versions="7" secret/customer/acme"

cyan "If we want to recover version 7 we can undelete"
pe "vault kv undelete -versions=7 secret/customer/acme"
vault kv get -version=7 secret/customer/acme

cyan "Permanently delete a version of a secret (destroy)"
pe "vault kv destroy -versions=7 secret/customer/acme"
vault kv get -version=7 secret/customer/acme

red "Destroy all keays and versions of a secret !!"
pe "vault kv metadata delete secret/customer/acme"

cyan "Configure automatic data deletion"
pe "vault kv metadata put -delete-version-after=30s secret/test"

cyan "write some test secrets"
vault kv put secret/test message="data1"
vault kv put secret/test message="data2"
vault kv put secret/test message="data3"

cyan "check the secret metadata for deletion_time on each version"
pe "vault kv metadata get secret/test"

cyan "read version 1."
pe "vault kv get -version=1 secret/test"

cyan "Wait 30 sec.  Read again and see it has been deleted"
pe "vault kv get -version=1 secret/test"

vault kv metadata delete secret/test


#cyan "enable Check and Set (cas) for mount secret/"
#pe "vault write secret/config cas-required=true"

cyan "Enable cas_requied only on the secret/partner path"
pe "vault kv metadata put -cas-required=true secret/partner"

green "Once check-and-set is enabled, every write operation requires cas value to be passed. If you are sure that you want to overwrite the existing key-value, set cas to match the current version. Set cas to 0 if you want to write the secret only if the key does not exists."