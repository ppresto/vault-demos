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
cyan "  Setup Vault Environment"
yellow "     * Install Ent License"
yellow "     * Enable Audit Log"
yellow "     * Configure Global Policies"
cyan "  Configure Namespace /root"
yellow  "    * OurCorp LDAP Auth"
yellow  "    * K/V Store for all LDAP users"
cyan "  Configure Namespace /IT"
yellow "     * Allow IT Team to admin /IT"
cyan "  As IT Team create Sub-Namespace /IT/hr"
yellow  "    * Enable hr app team access"
yellow  "    * Enable Transit (EaaS)"
yellow  "    * Enable DB Engine (Dynamic Secrets)"
cyan "  Demo Vault Services"
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

# Global Policies
./9_egp_policies.sh

# Configure Namespace /root, /IT.  As IT team configure /IT/hr
./3_config_ns_main.sh


# Populate IT Data for Validation Testing
vault kv put kv-blog/deepak/email password=doesntlooklikeanythingtome
export VAULT_NAMESPACE="IT"
vault kv put kv-blog/it/servers/hr/root password=rootntootn
unset VAULT_NAMESPACE

echo
lblue   "###########################################"
black   "  Setup Vault Environment"
black   "     * Install Ent License"
black   "     * Enable Audit Log"
black   "  Configure Namespace /root"
black   "    * OurCorp LDAP Auth"
black   "    * K/V Store for all LDAP users"
black   "  Configure Namespace /IT"
black   "     * Allow IT Team to admin /IT"
black   "  As IT Team create Sub-Namespace /IT/hr"
black   "    * Enable hr app team access"
black   "    * Enable Transit (EaaS)"
black   "    * Enable DB Engine (Dynamic Secrets)"
cyan    "  Demo Vault Services"
lblue   "###########################################"
p

./test_hr.sh

echo
cyan "Clean Up"
pe "./shutdown.sh"
kill % 1
