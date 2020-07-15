shopt -s expand_aliases

DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. ${DIRECTORY}/../../env.sh

#MONGO_DB_DATA="/usr/local/var/mongodb"
MONGO_DB_DATA="${DIRECTORY}/mongodb"
MONGO_LOG="mongodb.log"


if [[ -d ${MONGO_DB_DATA} ]]; then
    rm -rf ${MONGO_DB_DATA}/*
else
    mkdir -p ${MONGO_DB_DATA}
fi
if [[ -f ${DIRECTORY}/ca.pem ]]; then
    rm -rf ${DIRECTORY}/*.pem
fi
if [[ -f ${DIRECTORY}/${MONGO_LOG} ]]; then
    rm -rf ${DIRECTORY}/${MONGO_LOG}*
fi
if [[ ! $(ps -ef | grep mongod | grep -v grep) ]]; then
    source ${DIRECTORY}/getMongoEnterprise.sh
else
    pkill mongod
fi

echo
lblue "##########################################"
lcyan "  Apply License and Enable Audit Logging"
lblue "##########################################"
echo
cyan "Apply New License"
vault_key=$(cat /Users/patrickpresto/Projects/binaries/vault/*.hclic)
p "vault write sys/license text=\$(cat vault_license.hclic)"
vault write sys/license text=${vault_key}
vault read sys/license

echo
cyan "Enable Vault Audit Logging"
pe "vault audit enable file file_path=/tmp/vault_audit.log"

# Open Vault UI
open "http://${IP_ADDRESS}:8200"

echo
lblue "#######################"
lcyan "  Enable KMIP"
lblue "#######################"
echo
green "Enable the kmip secrets engine"
pe "vault secrets enable kmip"
echo
green "Configure KMIP to listen on default port 5696"
pe "vault write kmip/config listen_addrs=0.0.0.0:5696"

echo
green "Read KMIP secrets engine configuration"
vault read kmip/config
echo
yellow "Retrieve the CA and save to ca.pem"
pe "vault read -field=ca_pem kmip/ca > ca.pem"
# pe "vault read -format=json kmip/ca | jq -r .data.ca_pem > ca.pem"
echo
echo
lblue "####################################"
lcyan "  Create a Scope and Role for KMIP"
lblue "####################################"
echo
green "Enable a Scope named, 'salesforce'"
pe "vault write -f kmip/scope/salesforce"
vault list kmip/scope
echo
green "Create a new role, 'admin' under salesforce"
pe "vault write kmip/scope/salesforce/role/admin operation_all=true"
vault list kmip/scope/salesforce/role
#echo
#green "Read the new admin role"
#vault read kmip/scope/salesforce/role/admin
echo
lblue "#################################"
lcyan "  Generate a Client Certificate "
lblue "#################################"
echo
green "Generate the certification and save as client.pem"
pe "vault write -format=json kmip/scope/salesforce/role/admin/credential/generate format=pem_bundle | jq -r .data.certificate > client.pem"


echo
lblue "#################################"
lcyan "  Start mongod using Vault KMIP "
lblue "#################################"
echo
green "Start Mongod enterprise with CA & Certificate locations"
#pe "mongod --dbpath ${MONGO_DB_DATA}  --enableEncryption --kmipServerName localhost --kmipPort 5696 --kmipServerCAFile ${DIRECTORY}/ca.pem --kmipClientCertificateFile ${DIRECTORY}/client.pem --fork --logpath ${DIRECTORY}/mongo.log"
p "mongod --dbpath ${MONGO_DB_DATA}  \\
    --enableEncryption \\
    --kmipServerName localhost \\
    --kmipPort 5696 \\
    --kmipServerCAFile ${DIRECTORY}/ca.pem \\
    --kmipClientCertificateFile ${DIRECTORY}/client.pem \\
    --fork --logpath ${DIRECTORY}/${MONGO_LOG}"
mongod --dbpath ${MONGO_DB_DATA}  \
    --enableEncryption \
    --kmipServerName localhost \
     --kmipPort 5696 \
     --kmipServerCAFile ${DIRECTORY}/ca.pem \
     --kmipClientCertificateFile ${DIRECTORY}/client.pem \
     --fork --logpath ${DIRECTORY}/${MONGO_LOG}

kmip=$(cat ${DIRECTORY}/${MONGO_LOG} | grep "Created KMIP key with id" | awk '{ print $NF }')

echo
cyan "Verify the Encryption Key Manager is initialized"
echo
green "This should now be using KMIP"
pe "cat ${DIRECTORY}/${MONGO_LOG} | grep -i kmip"


echo
cyan "View Vault Audit Log"
green "Look for the KMIP Key ID: ${kmip}"
p "cat /tmp/vault_audit.log | jq"
${DIRECTORY}/../../launch_iterm.sh /tmp "cat /tmp/vault_audit.log | jq &"
