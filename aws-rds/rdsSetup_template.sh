#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"


#  USAGE:
#
#   This script depends on aws-quickstart setup to have already ran 
#   successfully and configured your Vault Cluster and Local Env.
#
#
QUICKSTART="../aws-quickstart"
PRIVATE_KEY="${DIR}/${QUICKSTART}/$(ls -1tr ${QUICKSTART} | grep key.pem | tail -1)"


if [[ -z $BASTION_HOST ]]; then
    echo " Usage: $(basename \"$0\")"
    echo "BASTION_HOST must be set in your environment for this script to properly ssh to the BASTION_HOST"
    exit 0
fi
# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/../demo-magic.sh -d -p -w ${DEMO_WAIT}

# Set Env Variables using terraform output
this_db_instance_endpoint=$(cd ${DIR}; terraform output this_db_instance_endpoint)
this_db_instance_username=$(cd ${DIR}; terraform output this_db_instance_username)
this_db_instance_password=$(cd ${DIR}; terraform output this_db_instance_password)
this_db_instance_name=$(cd ${DIR}; terraform output this_db_instance_name)
this_project_name_prefix=$(cd ${DIR}; terraform output name_prefix)
psql_url="postgresql://${this_db_instance_username}:${this_db_instance_password}@${this_db_instance_endpoint}/${this_db_instance_name}"

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

export project_name_prefix=MY_PROJECT_NAME
export this_db_instance_endpoint=MY_ENDPOINT
export this_db_instance_name=MY_DBNAME

dbtest () {
    user=$1
    pass=$2
    cmd=$3

    for addr in $(curl -s http://127.0.0.1:8500/v1/agent/members | jq -M -r "[.[] | select(.Name | contains (\"${project_name_prefix}-vault\")) | .Addr][]")
    do
        echo "${addr} : Query - psql postgresql://${user}:${pass}@${this_db_instance_endpoint}/${this_db_instance_name} -c \"${cmd}\""
        ssh -oStrictHostKeyChecking=no -A ec2-user@${addr} "psql postgresql://${user}:${pass}@${this_db_instance_endpoint}/${this_db_instance_name} -c \"${cmd}\""
    done
}

if [[ ! -z $1 && ! -z $2 && ! -z $3 ]]; then
  dbtest "${1}" "${2}" "${3}"
  exit
fi


if [[ $(curl -s http://127.0.0.1:8500/v1/agent/members) ]]; then

    # Get Vault Instances
    for addr in $(curl -s http://127.0.0.1:8500/v1/agent/members | jq -M -r "[.[] | select(.Name | contains (\"${project_name_prefix}-vault\") or contains (\"${project_name_prefix}-bastion\")) | .Addr][]")
    do
        ssh -oStrictHostKeyChecking=no -A ec2-user@${addr} "which psql"
        if [[ $? != 0 ]]; then
            # Install psql client on vault instances for testing...
            echo "${addr} installing psql client. Test: \"ssh -oStrictHostKeyChecking=no -A ec2-user@${addr} 'which psql'\""
            ssh -oStrictHostKeyChecking=no -A ec2-user@${addr} "sudo yum -y install https://download.postgresql.org/pub/repos/yum/reporpms/EL-7-x86_64/pgdg-redhat-repo-latest.noarch.rpm"
            ssh -oStrictHostKeyChecking=no -A ec2-user@${addr} "sudo yum -y install sudo yum install postgresql96"
            echo "Testing Connection: ssh -oStrictHostKeyChecking=no -A ec2-user@${addr} \"psql MY_PSQL_URL -c '\du'\""
            ssh -oStrictHostKeyChecking=no -A ec2-user@${addr} "psql MY_PSQL_URL -c '\du'"
        else
            echo "$addr : Skipping - psql already installed"
            echo "ssh -oStrictHostKeyChecking=no -A ec2-user@${addr} \"which psql\""
        fi
    done

else
    echo "Copy this script to the bastion host that has access to consul @ http://127.0.0.1:8500/v1/agent/members"
fi
EOF
) > ${DIR}/${myscript}

# Update new script variables
sed -i '' "s|MY_PROJECT_NAME|${this_project_name_prefix}|" ${DIR}/${myscript}
sed -i '' "s|MY_PSQL_URL|${psql_url}|" ${DIR}/${myscript}
sed -i '' "s|MY_ENDPOINT|${this_db_instance_endpoint}|" ${DIR}/${myscript}
sed -i '' "s|MY_DBNAME|${this_db_instance_name}|" ${DIR}/${myscript}


# scp this script to bastion host
cyan "Copying & Running initial RDS Setup Script on Bastion host"
chmod 750 ${DIR}/${myscript}
echo "scp -oStrictHostKeyChecking=no -i ${PRIVATE_KEY} ${DIR}/${myscript} ec2-user@${BASTION_HOST}:"
scp -oStrictHostKeyChecking=no -i ${PRIVATE_KEY} ${DIR}/${myscript} ec2-user@${BASTION_HOST}:
echo

# Execute script on bastion host
ssh -A -i ${PRIVATE_KEY} ec2-user@${BASTION_HOST} "./${myscript}"

# remove temp script locally to keep repo clean
rm ${DIR}/${myscript}

# Output Env Variables for Vault on workstation
echo
cyan "Copy and Export the following Vars, Aliases for the lab"
echo
echo "export db_endpoint=$this_db_instance_endpoint"
echo "export db_username=$this_db_instance_username"
echo "export db_password=$this_db_instance_password"
echo "export db_name=$this_db_instance_name"
echo "export psql_url=$psql_url"
echo "alias dbtest=\"ssh -A ec2-user@${BASTION_HOST} \\\"psql ${psql_url} -c '\du'\\\"\""
