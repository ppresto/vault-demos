shopt -s expand_aliases

DIRECTORY="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"
. ${DIRECTORY}/../../env.sh
. ${DIRECTORY}/getMongoEnterprise.sh
MONGO_DB_DATA="${DIRECTORY}/mongodb"
MONGO_LOG="mongodb.log"

echo
lblue "###########################"
lcyan "  Revoke KMIP Certificate"
lblue "###########################"
echo
green "List the admin roles certificaiton serial numbers"
#pe "vault list kmip/scope/salesforce/role/admin/credential"
p "curl --header \"X-Vault-Token: TOKEN\" \\
    --request LIST \\
    ${VAULT_ADDR}/v1/kmip/scope/salesforce/role/admin/credential \\
    | jq .data.keys[]"
serial=$(curl --header "X-Vault-Token: ${VAULT_TOKEN}" \
    --request LIST \
    ${VAULT_ADDR}/v1/kmip/scope/salesforce/role/admin/credential \
    | jq .data.keys[] | sed "s/\"//g" | head -1)

echo
green "revoke certificate"
pe "vault write kmip/scope/salesforce/role/admin/credential/revoke \\
    serial_number=\"${serial}\""


echo
lblue "#################################"
lcyan "  Restart mongod using Vault KMIP "
lblue "#################################"
echo
pkill mongod
green "Start Mongod enterprise with CA & Certificate locations"
#pe "mongod --dbpath ${MONGO_DB_DATA}  --enableEncryption --kmipServerName localhost --kmipPort 5696 --kmipServerCAFile ${DIRECTORY}/ca.pem --kmipClientCertificateFile ${DIRECTORY}/client.pem --fork --logpath ${DIRECTORY}/mongo.log"
p "mongod --dbpath ${MONGO_DB_DATA}  \\
    --enableEncryption \\
    --kmipServerName localhost \\
    --kmipPort 5696 \\
    --kmipServerCAFile ${DIRECTORY}/ca.pem \\
    --kmipClientCertificateFile ${DIRECTORY}/client.pem \\
    --logpath ${DIRECTORY}/${MONGO_LOG} \\
    --fork"
mongod --dbpath ${MONGO_DB_DATA} \
    --enableEncryption \
    --kmipServerName localhost \
     --kmipPort 5696 \
     --kmipServerCAFile ${DIRECTORY}/ca.pem \
     --kmipClientCertificateFile ${DIRECTORY}/client.pem \
     --logpath ${DIRECTORY}/${MONGO_LOG} \
     --fork
     
echo
cyan "View ${MONGO_LOG}"
pe "cat ${DIRECTORY}/${MONGO_LOG}"

pkill mongod
