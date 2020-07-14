. env.sh

echo
lblue "#################################"
lcyan "  Enable Transit Secrets (EaaS)"
lblue "#################################"
echo
green "Namespace:${VAULT_NAMESPACE} - Enabling Transit Secret Engine"
pe "vault secrets enable -path=${TRANSIT_PATH} transit"

green "Create a transit key for the HR team."
pe "vault write -f ${TRANSIT_PATH}/keys/hr exportable=true allow_plaintext_backup=true"