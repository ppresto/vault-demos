#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. demo-magic.sh -d -p -w ${DEMO_WAIT}


cyan "Enable Github Auth using default path"
pe "vault auth enable -path=github github"

cyan "Next Steps..."
green "Define what Organization users need to be a member of"
pe "vault write auth/github/config organization=hashicorp"

green "Map Github teams to vault policies.  These can exist or be created later."
pe "vault write auth/github/map/teams/team-se value=default,se-policy"

yellow "Run 'unset VAULT_TOKEN' to ensure Github Auth is used"
temp_token=${VAULT_TOKEN}
pe "unset VAULT_TOKEN"

green "Login to vault by including your personal Github token"
p "vault login -method=github token=:TOKEN"
vault login -method=github token=${GITHUB_TOKEN}

echo
purple "Setting Vault root token for higher privilages to allow revoke/disable commands"
export VAULT_TOKEN=${temp_token}

purple "Revoke github logins and all children."
pe "vault token revoke -mode path auth/github"

purple "Alternatively you can disable the Github Auth Engine"
pe "vault auth disable github"