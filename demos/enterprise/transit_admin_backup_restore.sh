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
cyan "  Transit Engine Administration"
yellow "     * Rotate Keys"
yellow "     * Export Keys"
lblue "###########################################"
echo
p

# vault login -method=ldap -path=ldap username=frank password=${USER_PASSWORD}"

# No ldap auth available in IT/hr namespace use root
#curl --header "X-Vault-Namespace: IT/hr" \
token=$(curl  \
    --request POST \
    --data "{\"password\": \"${USER_PASSWORD}\"}" \
    http://${IP_ADDRESS}:8200/v1/auth/ldap/login/deepak | jq -j '.auth.client_token')

export VAULT_TOKEN=$token
#curl \
#    --header "X-Vault-Token: ${token}" \
#    -X LIST \
#    http://${IP_ADDRESS}:8200/v1/sys/namespaces

# Rotate Key
curl \
    --header "X-Vault-Token: ${token}" \
    --header "X-Vault-Namespace: IT/hr" \
    --request POST \
    http://${IP_ADDRESS}:8200/v1/transit-blog/keys/hr/rotate

# List All Keys
curl \
    --header "X-Vault-Token: ${token}" \
    --header "X-Vault-Namespace: IT/hr" \
    http://${IP_ADDRESS}:8200/v1/transit-blog/keys/hr | jq '.data.keys'

backup="$(curl \
    --header "X-Vault-Token: ${token}" \
    --header "X-Vault-Namespace: IT/hr" \
    http://${IP_ADDRESS}:8200/v1/transit-blog/backup/hr | jq -r '.data.backup')"

tee backup.json <<-EOF
"backup": "${backup}"
"name":"NewKey"
"force":false
EOF

# delete key
curl \
    --header "X-Vault-Token: ${token}" \
    --header "X-Vault-Namespace: IT/hr" \
    --request DELETE http://${IP_ADDRESS}:8200/v1/transit-blog/keys/hr

#restore key
curl \
    --header "X-Vault-Token: ${token}" \
    --header "X-Vault-Namespace: IT/hr" \
    --request POST \
    --data @backup.json \
    http://${IP_ADDRESS}:8200/v1/transit-blog/restore 

# Export a Key  ** This must be created with the export option enabled!
#curl \
#    --header "X-Vault-Token: ${token}" \
#    --header "X-Vault-Namespace: IT/hr" \
#    http://${IP_ADDRESS}:8200/v1/transit-blog/export/encryption-key/hr/latest | jq