#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../demo-magic.sh -d -p -w ${DEMO_WAIT}

green "Many current/legacy applications use shared, static user accounts and need to periodically rotate the password.  the fully dynamic user/pass credentials would require script/code changes."
green "In this guide, you are going to configure PostgreSQL secret engine, and create a static read-only database role with username, "vault-edu". The Vault generated PostgreSQL credentials will only have read permission"
echo

cyan "Step 1: Start Vault and PostgreSQL Docker Containers for this exercise"
pe "docker run --rm --name postgres -e POSTGRES_USER=root \\
    -e POSTGRES_PASSWORD=rootpassword -d -p 5432:5432 postgres"

pe "docker run -d --rm -p 8200:8200 --name vaultdev \\
    --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=my_root_token_id' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault"

export VAULT_TOKEN=my_root_token_id
export VAULT_ADDR="http://127.0.0.1:8200"

cyan "Step 2: Enable the Database Dynamic Secrets Engine"
pe "curl -s --header \"X-Vault-Token: $VAULT_TOKEN\" --request POST \\
    --data '{\"type\": \"database\"}' \\
    ${VAULT_ADDR}/v1/sys/mounts/database |jq"

#
#
#
#
#
#

#



#yellow "'unset VAULT_TOKEN' to ensure new credentials are used"
#temp_token=${VAULT_TOKEN}
#unset VAULT_TOKEN

#purple "Setting Vault token back to its original value"
#export VAULT_TOKEN=${temp_token}
cyan "Removing containers and all generated files before exiting"
docker kill postgres vaultdev
rm ${DIR}/*.json