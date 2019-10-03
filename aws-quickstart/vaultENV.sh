#!/bin/bash

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

VAULT_ADDR=$(cd ${DIR}; terraform output | grep 'export VAULT_ADDR' | head -1 | cut -d= -f2)
CONSUL_ADDR=$(cd ${DIR}; terraform output | grep 'export CONSUL_ADDR' | head -1 | cut -d= -f2)
BASTION_HOST=$(cd ${DIR}; terraform output bastion_ips_public)
PRIVATE_KEY=$(cd ${DIR}; terraform output private_key_filename)

export VAULT_ADDR=${VAULT_ADDR}
export CONSUL_ADDR=${CONSUL_ADDR}
export CONSUL_HTTP_ADDR=${CONSUL_ADDR}
export BASTION_HOST=${BASTION_HOST}
export PROXY_COMMAND="proxycommand ssh -A ec2-user@${BASTION_HOST} -W %h:%p"
alias sshbastion='ssh -A -i ${DIR}/${PRIVATE_KEY} ec2-user@${BASTION_HOST}'
alias vaulttoken='export $(ssh -A -i ${DIR}/${PRIVATE_KEY} ec2-user@${BASTION_HOST} "env | grep VAULT_TOKEN")'
export $(ssh -A -i ${DIR}/${PRIVATE_KEY} ec2-user@${BASTION_HOST} "env | grep VAULT_TOKEN")

echo '# PROXY_COMMAND: SSH through bastion to instances'
echo '# consul members   # Get Internal IPs'
echo '# vault status'    # Get Vault status
echo '# sshbastion'      # alias - ssh to aws bastion host
echo '# vaulttoken'      # alias - ssh to bastion host and get root Vault Token
echo '# ssh ec2-user@${BASTION_HOST} -o "${PROXY_COMMAND}"'

