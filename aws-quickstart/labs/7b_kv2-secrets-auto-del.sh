#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../../demo-magic.sh -d -p -w ${DEMO_WAIT}

cyan "Configure automatic data deletion"
pe "vault kv metadata put -delete-version-after=30s secret/test"

cyan "write some test secrets"
vault kv put secret/test message="data1"
vault kv put secret/test message="data2"
vault kv put secret/test message="data3"

cyan "check the secret metadata for deletion_time on each version"
pe "vault kv metadata get secret/test"

cyan "read version 1."
pe "vault kv get -version=1 secret/test"

cyan "Wait 30 sec.  Read again and see it has been deleted"
pe "vault kv get -version=1 secret/test"

vault kv metadata delete secret/test