#!/bin/bash
#
#
#  https://learn.hashicorp.com/vault/identity-access-management/tokens
#
#

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
lblue "####################################################"
lcyan " Create Different Types of Tokens (Service & Batch)"
lblue "####################################################"

echo
cyan "Start your Vault Server"
pe "docker run -d --rm -p 8200:8200 --name vaultdev \\
    --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=my_root_token_id' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault"

export VAULT_TOKEN=my_root_token_id
export VAULT_ADDR="http://127.0.0.1:8200"
env | grep VAULT
sleep 1
vault status

echo
lpurple "#"
lpurple "### Service Tokens with -use-limit"
lpurple "#"
echo
cyan "Use limit tokens expire at the end of their last use regardless of their remaining TTLs. On the same note, use limit tokens expire at the end of their TTLs regardless of their remaining uses."

p "vault token create -policy=default -use-limit=3"
t_uselimit=$(vault token create -policy=default -use-limit=3)
echo ${t_uselimit} | xargs -n2
token=$(echo ${t_uselimit} | xargs -n2 | grep -w token | awk '{ print $NF }')

echo 
cyan "Verify -use-limit=3 is working"
pe "VAULT_TOKEN=${token} vault token lookup"

pe "VAULT_TOKEN=${token} vault write cubbyhole/token value=testUseLimit"
pe "VAULT_TOKEN=${token} vault read cubbyhole/token"
pe "VAULT_TOKEN=${token} vault read cubbyhole/token"

echo
lpurple "#"
lpurple "### Periodic Service Tokens"
lpurple "#"
echo
cyan "Periodic tokens have a TTL (validity period), but no max TTL; therefore, they may live for an infinite duration of time to better support long-running services \nFYI: when you set period and max TTL the token behaves as a periodic token but will be revoked once TTL is reached"
echo
cyan "create a role for zabbix using the default policy"
pe "vault write auth/token/roles/zabbix allowed_policies=\"default\" period=\"24h\""
echo
cyan "Generate a token"
p "vault token create -role=zabbix"
t_periodic=$(vault token create -role=zabbix)
token=$(echo ${t_periodic} | xargs -n2 | grep -w token | awk '{ print $NF }')
echo ${t_periodic} | xargs -n2
#pe "vault token lookup ${token}"

echo
lpurple "#"
lpurple "### Short lived Orphan service token"
lpurple "#"
echo
cyan "create an orphan service token with a 60 second TTL. \nAn Orphan token is not a child of a parent so they dont expire when thier parent does."
p "vault token create -policy=default -ttl=60s -orphan"
t_renew=$(vault token create -policy=default -ttl=60s -orphan)
token=$(echo ${t_renew} | xargs -n2 | grep -w token | awk '{ print $NF }')
echo ${t_renew} | xargs -n2

echo
lpurple "#"
lpurple "### Renew a service token"
lpurple "#"
echo
cyan "renew & extend TTL to 24 hours"
pe "vault token renew -increment=24h ${token}"
pe "vault token lookup ${token}"

echo
lpurple "#"
lpurple "### Revoke a service token"
lpurple "#"
echo
pe "vault token revoke ${token}"
echo
cyan "lookup token information should fail"
pe "vault token lookup ${token}"

echo
lpurple "#"
lpurple "### Create batch tokens"
lpurple "#"
cyan "Batch tokens are designed to be lightweight with limited flexibility (fixed TTL).  \nThey can be used across Performance replication clusters. \nThey can not be a root token"
p "vault token create -type=batch -policy=default"
t_batch=$(vault token create -type=batch -policy=default)
token=$(echo ${t_batch} | xargs -n2 | grep -w token | awk '{ print $NF }')
echo ${t_batch} | xargs -n2
pe "vault token lookup ${token}"
cyan "Notice: renewable is set to false"
pe "vault token revoke ${token}"
TMP_TOKEN=${VAULT_TOKEN}
unset VAULT_TOKEN
pe "vault login ${token}"
pe "vault write cubbyhole/token value='xyz'"
pe "vault token create -policy=default"
cyan "batch tokens can't create child tokens"

export VAULT_TOKEN=${TMP_TOKEN}
echo
lpurple "#"
lpurple "### Administration: View Token Defaults"
lpurple "#"
echo
cyan "View auth methods with auth"
pe "vault auth list -detailed"
echo
cyan "view mounts with read"
pe "vault read sys/mounts/auth/token/tune"
echo
lpurple "#"
lpurple "### Administration: Change Token Default Settings"
lpurple "#"
cyan "Change the default token TTL (which is 2764800 seconds or 32 days for ttl & max_ttl)"
pe "vault write sys/mounts/auth/token/tune default_lease_ttl=6m max_lease_ttl=24h"
echo
cyan "Verify changes"
pe "vault read sys/mounts/auth/token/tune"

echo
cyan "Removing containers and all generated files before exiting"
pe "docker kill vaultdev"