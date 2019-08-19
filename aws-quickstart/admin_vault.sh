#!/bin/bash

#
# Upgrade Vault
#
# Run this script from bastion host to access vault nodes directly.
#

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
VER="1.2.2"
COUNT=0

nodeUnseal() {
  node=$1
  echo "UnSeal Node: ${node}"
  for key in $KEYS
  do 
    ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "vault operator unseal ${key}"
  done
  echo "Vault Sealed : $(curl -s http://${node}:8200/v1/sys/health | jq '.sealed')"
}

nodeHealth() {
  node=$1
  VERSION=$(curl -s http://${node}:8200/v1/sys/health | jq '.version' | sed s"/\"//g")
  SEALED=$(curl -s http://${node}:8200/v1/sys/health | jq '.sealed' | sed s"/\"//g")
  URL_CODE=$(curl -sL -w "%{http_code}" http://${node}:8200/v1/sys/health -o /dev/null)
  LEADER=$(curl -s ${VAULT_ADDR}/v1/sys/leader | jq '.leader_address')

  if [[ ${URL_CODE} == 000 ]]; then
    echo "${node} API is unhealthy.  Restarting"
    ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "sudo systemctl restart vault.service"
    ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "sudo systemctl status vault.service"
    echo "${node}: $(curl -s http://${node}:8200/v1/sys/health | jq)"

  elif [[ ${SEALED} == "true" ]]; then
    echo "${node} needs to be unsealed."
    nodeUnseal ${node}
  
  else  
    if [[ ! $(echo $LEADER | grep $node) ]]; then
      echo "$node healthy (ver=$VERSION, sealed=$SEALED, HTTP_CODE=$URL_CODE)"
    else
      echo "$node healthy (ver=$VERSION, sealed=$SEALED, HTTP_CODE=$URL_CODE) - Leader"
    fi
  fi
}

if [[ $(curl -s http://127.0.0.1:8500/v1/agent/members) ]]; then

  # Get all nodes
  Nodes=$(curl -s ${CONSUL_ADDR}/v1/agent/members | jq -M -r \
    '[.[] | select(.Name | contains ("ppresto-vault-dev-vault")) | .Addr][]')

  # Get Leader Node
  LEADER_URL=$(curl -s ${VAULT_ADDR}/v1/sys/leader | jq '.leader_address')

  if [[ $1 == "health" || -z $1 ]]; then
    for node in $Nodes
    do
      nodeHealth $node
    done
    exit 0

  elif [[ $1 == "upgrade" ]]; then
    break

  else 
    echo "Usage: This script accepts a single arg of 'health or upgrade'"
    exit 1
  fi

  if [[ -z ${LEADER_URL} ]]; then 
    exit 1; 
  else
    echo "Leader URL: ${LEADER_URL}"
  fi

  for node in $Nodes
  do
    nodeHealth $node
    # If not the Leader Node upgrade vault binary
    if [[ ! $(echo $LEADER_URL | grep $node) ]]; then
      cur_VER=$(curl -s http://${node}:8200/v1/sys/health | jq '.version' | sed s"/\"//g")
      URL_STATUS=$(curl -sL -w "%{http_code}" http://${node}:8200/v1/sys/health -o /dev/null)
      if [[ ${cur_VER} != ${VER} && ! -z ${cur_VER} ]]; then
        COUNT=$((COUNT++))
        echo "Upgrading ${node} : Current version: ${cur_VER}"
        FLAG="true"
        ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "curl -O https://releases.hashicorp.com/vault/${VER}/vault_${VER}_linux_amd64.zip"
        ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "sudo unzip -o vault_${VER}_linux_amd64.zip -d /usr/local/bin"
        ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "sudo systemctl restart vault.service"
        ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "sudo systemctl status vault.service"
        sleep 2
        echo "${node} : New Version: $(curl -s http://${node}:8200/v1/sys/health | jq '.version')"
        echo "Upgraded $COUNT Nodes"
      else
        echo "${node} (ver:${cur_VER}, health status: ${URL_STATUS}) Skipping Upgrade"
      fi

      # Unseal Vault.  Assuming we have the minimum set of keys in KEYS.
      if [[ $(curl -s http://${node}:8200/v1/sys/health | jq '.sealed') == "true" ]]; then
          nodeUnseal $node
      fi

    fi
  done

  #
  ### Initiate Failover.  Stop Leader and have standby take over.
  #

  node=$(echo ${LEADER_URL} | cut -d: -f2 | sed s"/\///g")
  cur_VER=$(curl -s http://${node}:8200/v1/sys/health | jq '.version' | sed s"/\"//g")
  URL_STATUS=$(curl -sL -w "%{http_code}" http://${node}:8200/v1/sys/health -o /dev/null)

  if [[ ${cur_VER} != ${VER} && ! -z ${cur_VER} ]]; then

    ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "sudo systemctl stop vault.service"
    # Query API for New Leader
    test=$(curl -s ${VAULT_ADDR}/v1/sys/leader | jq '.leader_address' | sed s'/"//g')

    if [[ $(echo "${test}" | grep "${LEADER_URL}") ]]; then
      echo "WARNING: ${LEADER_URL} is still active leader.  Standby should take over before proceeding..."
      curl -s ${VAULT_ADDR}/v1/sys/leader | jq
      exit 1
    fi

    # Upgrade Leader Node
    if [[ ${cur_VER} != ${VER} && ${URL_STATUS} == 200 ]]; then
      echo "Upgrading ${node} : Current version: ${cur_VER}"
      COUNT=$((COUNT++))
      ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "curl -O https://releases.hashicorp.com/vault/${VER}/vault_${VER}_linux_amd64.zip"
      ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "sudo unzip -o vault_${VER}_linux_amd64.zip -d /usr/local/bin"
      ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "sudo systemctl restart vault.service"
      ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "sudo systemctl status vault.service"
      sleep 2
      echo "${node} : New Version: $(curl -s http://${node}:8200/v1/sys/health | jq '.version')"
      echo "Upgraded $COUNT Nodes"
    else
      echo "${node} : Skipping Upgrade already at version ${cur_VER}"
    fi

    # Unseal Vault.  Assuming we have the minimum set of keys in KEYS.
      if [[ $(curl -s http://${node}:8200/v1/sys/health | jq '.sealed') == "true" ]]; then
          nodeUnseal $node
      fi

  else
    echo "${node} (Leader:true, ver:${cur_VER}, health status: ${URL_STATUS}) Skipping Upgrade"
  fi

else
  echo "Copy this script to the bastion host that has access to vault and consul nodes. Ex: http://127.0.0.1:8500/v1/agent/members"
fi
exit