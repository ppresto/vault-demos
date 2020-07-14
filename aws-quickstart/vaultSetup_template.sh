#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# Description: 
# Run this to copy the admin scripts to the bastion host managing your new vault cluster.
# We will use this bastion host to access, unseal, and upgrade your cluster.
# If using your own custom aws key for ssh you may need to manually update the key this script will create locally.
# Just cat your existing key > into the local one and rerun the vaultSetup_template.sh
#

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../demos/demo-magic.sh -d -p -w ${DEMO_WAIT}

# Set Env Variables using terraform output
VAULT_ADDR=$(cd ${DIR}; terraform output | grep "export VAULT_ADDR" | head -1 | cut -d= -f2)
CONSUL_ADDR=$(cd ${DIR}; terraform output | grep "export CONSUL_ADDR" | head -1 | cut -d= -f2)
BASTION_HOST=$(cd ${DIR}; terraform output bastion_ips_public)
PRIVATE_KEY=$(cd ${DIR}; terraform output private_key_filename)

# Note:  If ssh agent has too many keys it can break things.  Try cleaning them up with "ssh-add -D and readding manually"
#
# Create SSH Key Locally if using TFE
if [[ ! -f ${PRIVATE_KEY} ]]; then
    echo "$(terraform output private_key_pem)" \
      > ${PRIVATE_KEY} \
      && chmod 0600 ${PRIVATE_KEY}
fi

# Add TF generated SSH Key
if [[ $(ssh-add -l | grep ${PRIVATE_KEY}) ]]; then
    echo "Key already added.  Found - ${PRIVATE_KEY}"
else
    ssh-add -D
    ssh-add ${PRIVATE_KEY}
fi


# Get template script name and remove new script if it already exists.
template_script=$(basename "$0")
myscript="${template_script%%_*}.sh"

if [[ -f ${DIR}/${myscript} ]]; then
    rm ${DIR}/${myscript}

else    
    echo "Creating ${DIR}/${myscript}"
fi


# Create New Script to be run on the Bastion Host with access to Consul and Vault.  
# This will ssh to each vault instance and unseal with the three keys generated from 'vault operator init'.
(
cat <<'EOF'
#!/bin/bash

    vaultURL="MYVAULTADDR/v1/sys/init"
    if [[ $(curl -s http://127.0.0.1:8500/v1/agent/members) ]]; then

        if [[ $(curl -s ${vaultURL} | jq '.initialized') != "true" ]]; then
            # Initialize vault
            # Alternative API Doc: https://learn.hashicorp.com/vault/getting-started/apis

            init=$(ssh -oStrictHostKeyChecking=no -A ec2-user@$(curl -s http://127.0.0.1:8500/v1/agent/members | jq -M -r \
                '[.[] | select(.Name | contains ("ppresto-vault-dev-vault")) | .Addr][0]') \
                "vault operator init")
            if [[ $? != 0 ]]; then
                echo "Init Failure [ $? ]  Exiting Remote Script Now..."
                exit 1
            fi
            echo $init
            KEYS=$(echo $init | sed "s/Unseal Key [0-9]\+/\nKey/g" | sed "s/Initial Root Token/\nRoot/" | grep Key | cut -d " " -f2 | head -3 | tr "\n" " ")
            root_token=$(echo $init | sed "s/Unseal Key [0-9]\+/\nKey/g" | sed "s/Initial Root Token/\nRoot/" | grep Root | cut -d " " -f2)

            # Set Vault Env Variables
            if [[ $(grep -v "KEYS" $HOME/.bashrc) ]]; then
                echo "export VAULT_ADDR=MYVAULTADDR" >> $HOME/.bashrc
                echo "export CONSUL_ADDR=MYCONSULADDR" >> $HOME/.bashrc
                echo "export VAULT_TOKEN=${root_token}" >> $HOME/.bashrc
                echo "export KEYS=\"${KEYS}\"" >> $HOME/.bashrc
            fi
            echo "KEYS : $KEYS"
            echo "Root Token: $root_token"
        elif [[ $(curl -s ${vaultURL} | jq '.initialized') == "true" ]]; then
            echo "Vault is already Initialized"
        else
            echo "Failed to verify vault initialization status: ${vaultURL}"
        fi

        # Unseal Instances

        for addr in $(curl -s http://127.0.0.1:8500/v1/agent/members | jq -M -r '[.[] | select(.Name | contains ("ppresto-vault-dev-vault")) | .Addr][]')
        do
            if [[ $(curl -s http://${addr}:8200/v1/sys/health | jq '.sealed') == "true" ]]; then
                for key in $KEYS
                do 
                    ssh -oStrictHostKeyChecking=no -A ec2-user@${addr} "vault operator unseal ${key}"
                done
                echo $(ssh -oStrictHostKeyChecking=no -A ec2-user@${addr} "vault status | grep Sealed")
            fi
        done

    else
        echo "Copy this script to the bastion host that has access to consul @ http://127.0.0.1:8500/v1/agent/members"
    fi
EOF
) > ${DIR}/${myscript}


# Update new script ENV vars
sed -i '' "s|MYVAULTADDR|${VAULT_ADDR}|" ${DIR}/${myscript}
sed -i '' "s|MYCONSULADDR|${CONSUL_ADDR}|" ${DIR}/${myscript}


# scp this script to bastion host
cyan "Copying & Running initial Vault Setup Scripts on Bastion host"
chmod 750 ${DIR}/${myscript}
scp -oStrictHostKeyChecking=no -i ${DIR}/${PRIVATE_KEY} ${DIR}/${myscript} ec2-user@${BASTION_HOST}:
scp -oStrictHostKeyChecking=no -i ${DIR}/${PRIVATE_KEY} ${DIR}/vaultAdmin.sh ec2-user@${BASTION_HOST}:
echo "scp -oStrictHostKeyChecking=no -i ${DIR}/${PRIVATE_KEY} ${DIR}/${myscript} ec2-user@${BASTION_HOST}:"

# Execute script on bastion host
ssh -A -i ${DIR}/${PRIVATE_KEY} ec2-user@${BASTION_HOST} "./${myscript}"

# remove temp script locally to keep repo clean
rm ${DIR}/${myscript}

# Setup Workstaion Env
VAULT_ADDR=$(cd ${DIR}; terraform output | grep 'export VAULT_ADDR' | head -1 | cut -d= -f2)
CONSUL_ADDR=$(cd ${DIR}; terraform output | grep 'export CONSUL_ADDR' | head -1 | cut -d= -f2)
BASTION_HOST=$(cd ${DIR}; terraform output bastion_ips_public)
PRIVATE_KEY=$(cd ${DIR}; terraform output private_key_filename)

export VAULT_ADDR=${VAULT_ADDR}
export $(ssh -A -i ${DIR}/${PRIVATE_KEY} ec2-user@${BASTION_HOST} "env | grep VAULT_TOKEN")
export CONSUL_ADDR=${CONSUL_ADDR}
export CONSUL_HTTP_ADDR=${CONSUL_ADDR}

alias sshbastion="ssh -A -i ${DIR}/${PRIVATE_KEY} ec2-user@${BASTION_HOST}"
alias vaulttoken="export $(ssh -A -i ${DIR}/${PRIVATE_KEY} ec2-user@${BASTION_HOST} 'env | grep VAULT_TOKEN')"

(
cat <<'EOF'
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

EOF
) > ${DIR}/vaultENV.sh
chmod 750 vaultENV.sh

# Output Env Variables for Vault on workstation
echo
cyan "Setup your workstation Env"
echo
echo "\$ source vaultENV.sh"
echo
cyan "SSH to your bastion host and run vaultSetup.sh to init/unseal your cluster"
echo "\$ sshbastion"
echo
cyan "Run './vaultAdmin.sh upgrade' from the bastion host to upgrade your vault version"
