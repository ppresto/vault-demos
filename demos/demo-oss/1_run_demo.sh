#!/bin/bash

. env.sh
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

if [[ ! $( ps -ef | grep "vault server" | grep -v grep) ]]; then
  echo "Start vault server in a new window first"
  echo "ex: ./0_start_vault.sh"
  exit
fi

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/demo-magic.sh -d -p -w ${DEMO_WAIT}

echo
lblue "###########################################"
lcyan "  Setup Vault Environment"
lcyan "  Configure Vault Services"
cyan  "    * LDAP Provider"
cyan  "    * K/V Engine"
cyan  "    * Transit (Encryption as a Service)"
cyan  "    * DB Engine (Dynamic Secrets)"
lcyan "  Demo Vault Services"
lblue "###########################################"
echo
p

export VAULT_TOKEN=notsosecure
export VAULT_ADDR="http://${IP_ADDRESS}:8200"
echo
yellow "export VAULT_TOKEN=notsosecure"
yellow "export VAULT_ADDR=\"http://${IP_ADDRESS}:8200\""

vault status
open "http://${IP_ADDRESS}:8200"

echo
vault read sys/license

echo
cyan "Apply New License"
vault_key=$(cat /Users/patrickpresto/Projects/binaries/vault/*.hclic)
p "vault write sys/license text=\$(cat vault_license.hclic)"
vault write sys/license text=${vault_key}
vault read sys/license

echo
cyan "Enable Vault Audit Logging"
pe "vault audit enable file file_path=/tmp/vault_audit.log"

echo
cyan "Tail Vault Audit Log"
${DIR}/launch_iterm.sh /tmp "tail -f /tmp/vault_audit.log | jq " &
echo

echo
lblue "###########################################"
lcyan "  Enable the LDAP Auth Method"
lblue "###########################################"
echo
./6_enable_ldap_auth.sh

echo
lblue "###########################################"
lcyan "  Enable KV Secrets Engine"
lblue "###########################################"
echo
./3_enable_kv.sh
./3_kv_policy.sh
./7_generate_dynamic_policy.sh

# associate policies
echo
cyan "Associate policies to members of the IT group"
pe "vault write auth/ldap/groups/it policies=kv-it,kv-user-template"

echo
lblue "#################################"
lcyan "  Enable Transit Secrets (EaaS)"
lblue "#################################"
echo
./5_enable_transit.sh
./5_transit_policy.sh
echo
yellow "Note:"
green "We will associate this policy to the HR team \\
at the same time as the DB Policies we are building next..."
echo
lblue "####################################"
lcyan "  Enable Dynamic DB Secrets Engine"
lblue "####################################"
echo
./4_enable_db.sh
./4_db_policy.sh

echo
green "Associate DB policies to the proper team"
pe "vault write auth/ldap/groups/hr policies=db-hr,transit-hr,kv-user-template"
vault write auth/ldap-mo/groups/hr policies=db-hr,transit-hr,kv-user-template
echo
green "Associate policies to members of the Security group"
vault write auth/ldap/groups/security policies=db-full-read,kv-user-template
echo
green "Associate policies to members of the Engineering group"
vault write auth/ldap-mo/groups/engineering policies=db-engineering,kv-user-template

echo
lblue "#"
lcyan "###  Testing Time"
lblue "#"
echo
./test_hr.sh

echo
cyan "Clean Up"
pe "./shutdown.sh"
kill % 1
