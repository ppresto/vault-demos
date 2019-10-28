#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../demo-magic.sh -d -p -w ${DEMO_WAIT}

env | grep VAULT
env | grep db_
env | grep BASTION_HOST

echo
echo
green "create static roles that have static usernames with dynamic credentials"
echo

cyan "Step 1: Start Vault and PostgreSQL Docker Containers for this exercise"
pe "docker run --rm --name postgres -e POSTGRES_USER=root \\
    -e POSTGRES_PASSWORD=rootpassword -d -p 5432:5432 postgres"

pe "docker run -d --rm -p 8200:8200 --name vaultdev \\
    --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=my_root_token_id' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault"

export VAULT_TOKEN=my_root_token_id
export VAULT_ADDR="http://127.0.0.1:8200"

echo
cyan "Step 2: Create our static vault-edu user to use as an example"
docker exec -it postgres psql -c "CREATE ROLE \"vault-edu\" WITH LOGIN PASSWORD 'mypassword';"
docker exec -it postgres psql -c "GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO \"vault-edu\";"
docker exec -it postgres psql -c "\du"
echo

cyan "Step 3: Enable database secrets engin at databse/"
pe "vault secrets enable database"
echo
cyan "Step 4: Configure postgresql plugin for database secrets engine"
p "vault write database/config/postgresql \\
        plugin_name=postgresql-database-plugin \\
        allowed_roles=\"*\" \\
        connection_url=postgresql://{{username}}:{{password}}@host.docker.internal:5432/postgres?sslmode=disable \\
        username=\"root\" \\
        password=\"rootpassword\""

vault write database/config/postgresql \
        plugin_name=postgresql-database-plugin \
        allowed_roles="*" \
        connection_url=postgresql://{{username}}:{{password}}@host.docker.internal:5432/postgres?sslmode=disable \
        username="root" \
        password="rootpassword"

cyan "Its Best Practices to rotate the root credentials. printing for reference only..."
p "vault write -force database/rotate-root/postgresql"

echo
cyan "Step 5: Create the Static Role 'education-role' well use for the psql vault-edu user"

tee rotation.sql <<EOF
ALTER USER "{{name}}" WITH PASSWORD '{{password}}';
EOF

p "vault write database/static-roles/education-role \\
    db_name=postgresql \\
    rotation_statements=@rotation.sql \\
    username=\"vault-edu\" \\
    rotation_period=86400"

vault write database/static-roles/education-role \
        db_name=postgresql \
        rotation_statements=@rotation.sql \
        username="vault-edu" \
        rotation_period=86400
echo
cyan "Verify by reading the education-role"
pe "vault read database/static-roles/education-role"

cyan "Now our client needs a read policy to access the education-role.  Lets create it"
echo "apps.hcl:"
tee apps.hcl <<EOF
path "database/static-creds/education-role" {
  capabilities = [ "read" ]
}
EOF

pe "vault policy write apps apps.hcl"

echo
cyan "Create a token using the apps policy"
p "vault token create -policy=\"apps\""
TOKEN_OUT=$(vault token create -policy="apps")
echo $TOKEN_OUT | xargs -n2 | column -t
TOKEN=$(echo $TOKEN_OUT | xargs -n2 | grep -w token | awk '{ print $2 }')

echo
cyan "Use the new token to request credentials for our psql user: vault-edu"
pe "VAULT_TOKEN=${TOKEN} vault read database/static-creds/education-role"
echo
cyan "Rerun the command and verify the returned password is the same with an updated TTL"
pe "VAULT_TOKEN=${TOKEN} vault read database/static-creds/education-role"

echo
cyan "Lets connect to the DB with our new password. Input it at the prompt below.  (quit: \q)"
pe "psql -h localhost -d postgres -U vault-edu"


#yellow "'unset VAULT_TOKEN' to ensure new credentials are used"
#temp_token=${VAULT_TOKEN}
#unset VAULT_TOKEN

#purple "Setting Vault token back to its original value"
#export VAULT_TOKEN=${temp_token}
cyan "Removing containers and all generated files before exiting"
docker kill postgres vaultdev
rm ${DIR}/rotation.sql
rm ${DIR}/apps.hcl