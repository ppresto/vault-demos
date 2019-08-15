#!/bin/bash

# Usage: 
# source ./setupAWSSecretsEngine.sh

# Note:
# if you source the script then your current shell will be updated with the current AWS CREDENTIALS being generaged so you can use them.

# This script assumes you have a working vault cluster and your environment is properly setup to access vault.
# You can refer to the 2 "Set Env Variables" sections in vaultSetupSCript_template.sh to quickly setup your local env fo this scripts.

# source creds from your local env.  example awsSetEnv.sh is available in this repo.
if [[ -f $HOME/.aws/credentials ]]; then
    AWS_ACCESS_KEY="$(cat ${HOME}/.aws/credentials | grep aws_access_key_id | awk '{ print $NF }')"
    AWS_SECRET_ACCESS_KEY="$(cat ${HOME}/.aws/credentials | grep aws_secret_access_key| awk '{ print $NF }')"
    AWS_DEFAULT_REGION="us-west-2"
else
    echo "mising .aws/credentials that setup env."
    exit 1
fi

AWS_ROLE="ec2-admin-role-pp"

# enable aws secrets engine
echo "Enabling AWS Secrets: vault secrets enable -path=aws aws"
vault secrets enable -path=aws aws

# add aws creds to use for future transactions
echo -e "\nWriting AWS Credentials to vault for use with IAM roles"
echo "COMMAND: vault write aws/config/root access_key='' secret_key='' region=${AWS_DEFAULT_REGION}"

vault write aws/config/root \
    access_key=${AWS_ACCESS_KEY} \
    secret_key=${AWS_SECRET_ACCESS_KEY} \
    region=${AWS_DEFAULT_REGION}

# create aws role
echo -e "\nCreating AWS Role to allow ec2 administration permissions"
echo "COMMAND: vault write aws/roles/${AWS_ROLE} credential_type=iam_user policy_document=ec2-admin.policy.txt"
vault write aws/roles/${AWS_ROLE} \
        credential_type=iam_user \
        policy_document=-<<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Stmt1426528957000",
      "Effect": "Allow",
      "Action": [
        "ec2:*"
      ],
      "Resource": [
        "*"
      ]
    }
  ]
}
EOF

# read role to verify
echo -e "\nVerifying vault role creation..."
vault read aws/roles/${AWS_ROLE}

# create credentials (aws access key pair)
echo -e "\nCreating new credentials"
create=$(vault read aws/creds/${AWS_ROLE})
echo $create | xargs -n2

# setting variables from $create output
lease_id=$(echo ${create} | xargs -n2 | grep -w lease_id | awk '{ print $NF }')
access_key=$(echo ${create} | xargs -n2 | grep -w access_key | awk '{ print $NF }')
secret_key=$(echo ${create} | xargs -n2 | grep -w secret_key | awk '{ print $NF }')

echo -e "\nConfiguring local env variables to use new AWS Credentials"
unset AWS_ACCESS_KEY  # may be set for terraform by profile. Adds confusion to output.
export AWS_ACCESS_KEY_ID=${access_key}
export AWS_SECRET_ACCESS_KEY=${secret_key}
export AWS_DEFAULT_REGION="us-west-2"


env | grep AWS

#use aws cli to view instances in us-west-2 with tag Name=ppresto-vault-dev-vault-node
echo -e "\nTesting new credentials using the aws cli: $(aws --version)"
echo "Requesting the current vault cluster public dns names:"
echo "COMMAND: aws ec2 describe-instances --filters "Name=tag:Name,Values=ppresto-vault-dev-vault-node" --query "Reservations[].Instances[].PublicDnsName" --region us-west-2"
echo -e "waiting 15 seconds...\n\n"
sleep 15
aws ec2 describe-instances \
--filters "Name=tag:Name,Values=ppresto-vault-dev-vault-node" \
--query "Reservations[].Instances[].PublicDnsName" \
--region us-west-2

# List t2.micro instances for easier test
#aws ec2 describe-instances --filters "Name=instance-type,Values=t2.micro" --query "Reservations[].Instances[].InstanceId"

# Administration

# Admin: List all roles
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request LIST \
    $VAULT_ADDR/v1/sys/leases/lookup/aws/creds/ | jq


# Admin: List leases for a given role (${AWS_ROLE})
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request LIST \
    $VAULT_ADDR/v1/sys/leases/lookup/aws/creds/${AWS_ROLE}/

# Get latest lease_id
lease_id=$(
  curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request LIST \
    $VAULT_ADDR/v1/sys/leases/lookup/aws/creds/${AWS_ROLE}/ | jq '.data.keys[0]' | sed "s/\"//g"
  )
# Admin: Get Lease information for the latest lease 
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request PUT \
    --data "{\"lease_id\": \"aws/creds/${AWS_ROLE}/${lease_id}\"}" \
    $VAULT_ADDR/v1/sys/leases/lookup | jq

# Admin: Get full lease_id path to revoke
lease_id_path=$(
  curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request PUT \
    --data "{\"lease_id\": \"aws/creds/${AWS_ROLE}/${lease_id}\"}" \
    $VAULT_ADDR/v1/sys/leases/lookup | jq '.data.id' | sed "s/\"//g"
)

# Revoke credentials using lease_id_path
echo -e "\nRevoking new Credentials using lease_id"
echo "COMMAND: vault lease revoke ${lease_id_path}"
vault lease revoke ${lease_id_path}

# Use revoked creds to see instances.  you should get an error.
echo -e "\nTry getting vault cluster public dns names now.  This should fail in a minute!"
echo "COMMAND: aws ec2 describe-instances --filters "Name=tag:Name,Values=ppresto-vault-dev-vault-node" --query "Reservations[].Instances[].PublicDnsName" --region us-west-2"

sleep 15
# List leases to verify the latest is gone.
curl \
    --header "X-Vault-Token: $VAULT_TOKEN" \
    --request LIST \
    $VAULT_ADDR/v1/sys/leases/lookup/aws/creds/${AWS_ROLE}/
    
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=ppresto-vault-dev-vault-node" \
    --query "Reservations[].Instances[].PublicDnsName" \
    --region us-west-2
echo $?