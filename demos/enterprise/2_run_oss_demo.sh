shopt -s expand_aliases

. env.sh

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
unset PGUSER PGPASSWORD
unset VAULT_TOKEN

# Open Vault UI
open "http://${IP_ADDRESS}:8200"

echo
lblue "#######################"
lcyan "  HR App Team - frank"
lblue "#######################"
echo
green "Using LDAP login as frank (HR App Team)"
unset VAULT_TOKEN
p "vault login -method=ldap -path=ldap username=frank password=${USER_PASSWORD}"
token=$(vault login -method=ldap -path=ldap username=frank password=${USER_PASSWORD} -format=json | jq -r '.auth.client_token')

echo
green "Use the CLI to write Frank's secret (kv-blog/frank/*)"
pe "vault kv put kv-blog/frank/email password=doesntlooklikeanythingtome"
echo
green "Use the API to get Frank's secret"
p "curl \\
    --header \"X-Vault-Token: ${token}\" \\
    http://${IP_ADDRESS}:8200/v1/kv-blog/data/frank/email"
curl \
    --header "X-Vault-Token: ${token}" \
    http://${IP_ADDRESS}:8200/v1/kv-blog/data/frank/email | jq -r

echo
green "Verify Frank can't access deepak's secrets (kv-blog/deepak/*)"
#pe "vault kv put kv-blog/deepak/email password=doesntlooklikeanythingtome"
pe "vault kv get kv-blog/deepak/email"
red "This should fail.  Frank shouldn't have access to deepak's path (kv-blog/deepak/*)"

echo
#./enable_okta_mfa.sh
echo
echo
lblue "##########################################################"
lcyan "  Access the HR App's DB using Dynamic Credentials"
lblue "##########################################################"

export VAULT_NAMESPACE="IT/hr"
p
# Open pg4admin UI
open "http://${PGHOST}"
echo
p "vault read db-blog/creds/mother-hr-full-2m"
creds=$(vault read db-blog/creds/mother-hr-full-2m)
PGUSER="$(echo $creds | xargs -n2 | grep -w username | awk '{ print $NF}')"
PGPASSWORD="$(echo $creds | xargs -n2 | grep -w password | awk '{ print $NF}')"
echo $creds | xargs -n2
#pe "vault read -format=json db-blog/creds/mother-hr-full-1h | jq -r '.data | .[\"PGUSER\"] = .username | .[\"PGPASSWORD\"] = .password | del(.username, .password) | to_entries | .[] | .key + \"=\" + .value ' > .temp_db_creds"
#pe ". .temp_db_creds && rm .temp_db_creds"
echo
green "By setting the postgres environment variables to the dynamic creds, we can now run PSQL with the dynamic creds"
yellow "export PGUSER=${PGUSER}"
yellow "export PGPASSWORD=${PGPASSWORD}"

export PGUSER=${PGUSER}
export PGPASSWORD=${PGPASSWORD}
echo
#green "Turn off globbing for the database query in an environment variable so it doesn't pick up file names instead"
set -o noglob
pe "QUERY='select email,id from hr.people;'"
psql
echo
lblue "###########################################"
lcyan "  Encrypt Alice's id using EaaS (Transit)"
lblue "###########################################"
yellow "WARNING:  If your app logic can't consume both encrypted and unencrypted values schedule a maint window for this activity"
echo
green "Step 1: get Alice's id"
pe "QUERY=\"select id from hr.people where email='alice@ourcorp.com'\""
export PG_OPTIONS="-A -t"
user_id=$(psql)
echo "user_id = ${user_id}"
export PG_OPTIONS=""
echo
green "Step 2: Encrypt Alice's id"
pe "enc_id=\$(vault write -field=ciphertext transit-blog/encrypt/hr plaintext=\$( base64 <<< \${user_id} ) )"
echo ${enc_id}
echo
green "Step 3: Update the DB with Alice's Encrypted id"
pe "QUERY=\"UPDATE hr.people SET id='\${enc_id}' WHERE email='alice@ourcorp.com'\""
psql

# Turn off headings and aligned output
QUERY="select email,id from hr.people"
psql

echo
lblue "###########################################"
lcyan "  Decrypt Alice's id using EaaS (Transit)"
lblue "###########################################"
echo
green "Step 1: Get Alice's encrypted id"
pe "QUERY=\"select id from hr.people where email='alice@ourcorp.com'\""
export PG_OPTIONS="-A -t"
enc_user_id=$(psql)
echo "enc_user_id=${enc_user_id}"
export PG_OPTIONS=""
echo
green "Step 2: Decrypt Alice's id"
pe "user_id=\$(vault write -field=plaintext transit-blog/decrypt/hr ciphertext=\${enc_user_id} | base64 --decode)"
echo ${user_id}

echo
green "Notice the value is still encrypted in the database.   It should only be decrypted by your applications when needed to be displayed"
pe "QUERY=\"select email,id from hr.people\""
psql
unset VAULT_NAMESPACE