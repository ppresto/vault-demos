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
green "Setup OTP for SSH"
echo

cyan "Step 1: Start Vault and openssh container"
pe "docker run -d --rm -p 8200:8200 --name vaultdev \\
    --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=my_root_token_id' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault"

export VAULT_TOKEN=my_root_token_id
export VAULT_ADDR="http://127.0.0.1:8200"

green "Check Vault Env"
pe "env | grep VAULT"
vault status

green "Build openssh image..."
pe "docker build -t ppresto/ubuntu ."
cd ./image-ubuntu-SSH_OTP
docker build -t ppresto/ubuntu .

#pe "docker run -d --rm --name ubuntu ppresto/ubuntu tail -f /dev/null"
echo
pe "docker run -d -p 2222:22 --rm --name ubuntu --link=vaultdev ppresto/ubuntu"

echo
green "Review /etc/pam.d/sshd"
docker exec ubuntu cat /etc/pam.d/sshd

echo
green "Review /etc/ssh/sshd_config"
docker exec ubuntu cat /etc/ssh/sshd_config

green "Verify vault-ssh-helper"
pe "docker exec ubuntu which vault-ssh-helper"

green "Review /etc/vault-ssh-helper.d/config.hcl"
pe "docker exec ubuntu cat /etc/vault-ssh-helper.d/config.hcl"

echo
cyan "Step 3: Setup the SSH Secrets Engine on Vault"

echo
green "enable ssh"
pe "vault secrets enable ssh"

echo
green "Create OTP role (default user: ubuntu)"
p "vault write ssh/roles/otp_key_role key_type=otp \\
        default_user=ubuntu \\
        cidr_list=0.0.0.0/0"

vault write ssh/roles/otp_key_role key_type=otp \
        default_user=ubuntu \
        cidr_list=0.0.0.0/0


echo
cyan "Step 4: Request an OTP with role: otp_key_role"
p "vault write ssh/creds/otp_key_role ip=127.0.0.1"

otp=$(vault write ssh/creds/otp_key_role ip=127.0.0.1)
echo $otp | xargs -n2
mykey=$(echo ${otp} | xargs -n2 | grep -w key | awk '{ print $NF}')

echo
green "ssh -p 2222 ubuntu@127.0.0.1"

cyan "verify our OTP with vault server"
pe "vault write ssh/verify otp=${mykey}"

cyan "use sshpass to automatically ssh to the host"
# OS X - brew install https://raw.githubusercontent.com/kadwanev/bigboybrew/master/Library/Formula/sshpass.rb
# ubuntu - apt-get install sshpass
pe "vault ssh -role otp_key_role -mode otp -strict-host-key-checking=no ubuntu@127.0.0.1 -p 2222"

echo
cyan "verify our OTP is no longer valid"
pe "vault write ssh/verify otp=${mykey}"

echo
cyan "Removing containers and all generated files before exiting"
pe "docker kill vaultdev ubuntu"