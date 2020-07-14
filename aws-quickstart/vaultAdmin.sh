#!/bin/bash

#
# Vault Administration (stop cluster, start/unseal cluster, upgrade cluster)
#
# Run this script from bastion host to access vault nodes directly.
#
# Manual Tasks:  
#
# Migrate from Shamir to kms auto-unseal
# Create AWS KMS Key and include vault nodes in policy. 
# Stop your cluster, and update each server's config with new seal awskms options
# vi /etc/vault.d/vault.hcl:  (systemctl vault.service defines vault.hcl)
#   VAULT_SEAL_TYPE="awskms"
#   AWS_DEFAULT_REGION="us-west-2"
#   AWS_ACCESS_KEY_ID="x"
#   AWS_SECRET_ACCESS_KEY="y"
#   VAULT_AWSKMS_SEAL_KEY_ID="z"
#
# Start Service on 1 node
# sudo systemctl start vault.service
#
# Unseal using shamir keys with -migrate option
# vault operator unseal -migrate
#
# Start all remaining servers and they should be using auto-unseal.
#


DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
VER="1.2.2"
COUNT=0
source $HOME/.bashrc

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

nodeUpgrade () {
    if [[ -z $2 || -z $1 ]]; then 
      exit 1; 
    else
      Nodes="$1"
      LEADER_URL="$2"
      if [[ ! -z $3 ]]; then
        VER="$3"
      fi
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
}

stopCluster() {
  if [[ -z $2 || -z $1 ]]; then 
      exit 1; 
  else
    Nodes="$1"
    LEADER_URL="$2"
    echo "Leader URL: ${LEADER_URL}"
  fi

  for node in $Nodes
    do
      echo
      echo "${node} : Stopping"
      ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "sudo systemctl stop vault.service"
      ssh -oStrictHostKeyChecking=no -A ec2-user@${node} "sudo systemctl status vault.service | grep systemd"
      echo
    done
}

usage () {
  echo "Usage:"
  echo -e "\t./`basename \"$0\"` health  \t\t# if needed fix cluster health, return status"
  echo -e "\t./`basename \"$0\"` upgrade \t\t# upgrade cluster to default version: 1.2.2"
  echo -e "\t./`basename \"$0\"` upgrade <ver> \t# upgrade cluster to <version>"
  echo -e "\t./`basename \"$0\"` stopCluster \t# migrate from Shamir to aws KMS auto-unseal"
  exit 0 
}
#
### Main
#
if [[ $(curl -s http://127.0.0.1:8500/v1/agent/members) ]]; then

    # Get all nodes
    Nodes=$(curl -s ${CONSUL_ADDR}/v1/agent/members | jq -M -r \
      '[.[] | select(.Name | contains ("ppresto-vault-dev-vault")) | .Addr][]')

    # Get Leader Node
    LEADER_URL=$(curl -s ${VAULT_ADDR}/v1/sys/leader | jq '.leader_address')

    if [[ $1 == "health" ]]; then
      for node in $Nodes
      do
        nodeHealth $node
      done
      exit 0 
    elif [[ $1 == "upgrade" ]]; then
      echo "Upgrading:  $(echo $Nodes)"
      if [[ ! -z $2 ]]; then 
        VER="$2"
      fi
      nodeUpgrade "$Nodes" "$LEADER_URL" "$VER"
    elif [[ $1 == "stopCluster" ]]; then
      stopCluster "$Nodes" "$LEADER_URL"
    else 
      usage
    fi
else
    echo "Copy this script to the bastion host that has access to vault and consul nodes. Ex: http://127.0.0.1:8500/v1/agent/members"
fi
exit