shopt -s expand_aliases

. env.sh

echo
lblue "#############################################"
lcyan "  Login as an IT user and test IT policies"
lblue "#############################################"
unset PGUSER PGPASSWORD
unset VAULT_TOKEN
echo
green "LDAP User deepak is on the IT Team"
pe "vault login -method=ldap -path=ldap username=deepak password=${USER_PASSWORD}"
echo
green "Test KV paths for IT"
pe "vault kv put kv-blog/it/servers/hr/root password=rootntootn"
vault kv get kv-blog/it/servers/hr/root
echo
green "Test our ACL template (kv-blog/deepak/*)"
pe "vault kv put kv-blog/deepak/email password=doesntlooklikeanythingtome"
vault kv get kv-blog/deepak/email

echo
lblue "####################################################"
lcyan "  Test HR Policies (Dynamic DB Credentials & EaaS)"
lblue "####################################################"
echo
green "Login as frank who is on the HR Team"
unset VAULT_TOKEN
pe "vault login -method=ldap -path=ldap-mo username=frank password=${USER_PASSWORD}"

green "Test our ACL template (kv-blog/frank/*)"
pe "vault kv put kv-blog/frank/email password=doesntlooklikeanythingtome"

green "Read Dynamic DB credentials"
echo
p "vault read db-blog/creds/mother-hr-full-1h"
creds=$(vault read db-blog/creds/mother-hr-full-1h)
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
pe "psql"
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
echo ${user_id}
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
echo "${enc_user_id}"
export PG_OPTIONS=""
echo
green "Step 2: Decrypt Alice's id"
pe "user_id=\$(vault write -field=plaintext transit-blog/decrypt/hr ciphertext=\${enc_user_id} | base64 --decode)"
echo ${user_id}

echo
green "Notice the value is still encrypted in the database.   It should only be decrypted by your applications when needed to be displayed"
pe "QUERY=\"select email,id from hr.people\""
psql

echo
red "#"
red "### Negative Tests - Expect Failures Here"
red "#"
echo
yellow "Write kv secrets to another LDAP users path"
pe "vault kv put kv-blog/deepak/email password=doesntlooklikeanythingtome"

yellow "Try to query the engineering schema from here."
pe "QUERY=\"select * from engineering.catalog\""
psql

yellow "Can the Vault token read IT kv secrets?"
#pe "vault read db-blog/creds/mother-full-read-1h"
pe "vault kv get kv-blog/it/servers/hr/root"
