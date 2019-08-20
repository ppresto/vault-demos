#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../../demo-magic.sh -d -p -w ${DEMO_WAIT}


#cyan "enable Check and Set (cas) for mount secret/"
#pe "vault write secret/config cas-required=true"

cyan "Enable cas_requied only on the secret/partner path"
pe "vault kv metadata put -cas-required=true secret/partner"

green "Once check-and-set is enabled, every write operation requires cas value to be passed. If you are sure that you want to overwrite the existing key-value, set cas to match the current version. Set cas to 0 if you want to write the secret only if the key does not exists."

cyan "Only write the secret if it doesn't already exist (-cas=0)"
pe "vault kv put -cas=0 secret/partner name=\"Example Co.\" partner_id=\"123456789\""

cyan "update the secret with cas enabled (-cas=:version)"
pe "vault kv put -cas=1 secret/partner name=\"Example Co.\" partner_id=\"ABCDEFGHIJKLMN\""

cyan "get metadata for secret/partner"
pe "vault kv metadata get secret/partner"

cyan "read version=1"
pe "vault kv get -version=1 secret/partner"

cyan "delete all secrets within secert/parter"
pe "vault kv metadata delete secret/partner"