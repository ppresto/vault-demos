#!/bin/bash
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null 2>&1 && pwd )"

# This is for the time to wait when using demo_magic.sh
if [[ -z ${DEMO_WAIT} ]];then
  DEMO_WAIT=0
fi

# Demo magic gives wrappers for running commands in demo mode.   Also good for learning via CLI.
. ${DIR}/demo-magic.sh -d -p -w ${DEMO_WAIT}

unset VAULT_TOKEN
export VAULT_ADDR=http://127.0.0.1:8200
export CONSUL_ADDR=http://127.0.0.1:8500

cget() { curl -sf "http://127.0.0.1:8500/v1/kv/service/vault/$1?raw"; }

if [[ ! $(curl -s ${VAULT_ADDR}/v1/sys/init | jq '.initialized') == "true" ]]; then
    echo
    cyan "Initialize and Unseal Vault"
    curl \
    --silent \
    --request PUT \
    --data '{"secret_shares": 1, "secret_threshold": 1}' \
    ${VAULT_ADDR}/v1/sys/init | tee \
    >(jq -r '.root_token' > /tmp/root-token) \
    >(jq -r '.keys[0]' > /tmp/unseal-key)

    curl -sfX PUT 127.0.0.1:8500/v1/kv/service/vault/unseal-key -d $(cat /tmp/unseal-key)
    curl -sfX PUT 127.0.0.1:8500/v1/kv/service/vault/root-token -d $(cat /tmp/root-token)

fi
pe "vault operator unseal $(cget unseal-key)"

export ROOT_TOKEN=$(cget root-token)
vault login $ROOT_TOKEN

#Create admin user
echo
cyan "Create our Vault Admin User and Login"
echo '
path "*" {
    capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}' | vault policy write vault_admin -

vault auth enable userpass
vault write auth/userpass/users/vault password=vault policies=vault_admin

#################################
# Transit-app-example Vault setup
#################################
pe "vault login -method=userpass username=vault password=vault"

# Enable secret engines
echo
cyan "Enable the Transit Engine (Encryption as a Service)"
pe "vault secrets enable -path=lob_a/workshop/kv kv"
pe "vault write lob_a/workshop/kv/transit-app-example username=vaultadmin password=vaultadminpassword"

vault secrets enable -path=lob_a/workshop/transit transit
pe "vault write -f lob_a/workshop/transit/keys/customer-key"
vault write -f lob_a/workshop/transit/keys/archive-key

# Configure our secret engine
echo
cyan "Enable MySQL Secrets Engine for Dynamic Credentials"
pe "vault secrets enable -path=lob_a/workshop/database database"
p "vault write lob_a/workshop/database/config/ws-mysql-database \\
    plugin_name=mysql-database-plugin \\
    connection_url=\"{{username}}:{{password}}@tcp(mariadb.service.consul:3306)/\" \\
    allowed_roles=\"workshop-app\" \\
    username=\"root\" \\
    password=\"vaultadminpassword\""

vault write lob_a/workshop/database/config/ws-mysql-database \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(mariadb.service.consul:3306)/" \
    allowed_roles="workshop-app" \
    username="root" \
    password="vaultadminpassword"

# Create our role
echo
cyan "Define a Role that creates our Dynamic MySQL Credentials"
p "vault write lob_a/workshop/database/roles/workshop-app \\
    db_name=ws-mysql-database \\
    creation_statements=\"CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL ON *.* TO '{{name}}'@'%';\" \\
    default_ttl=\"1m\" \\
    max_ttl=\"5m\""

vault write lob_a/workshop/database/roles/workshop-app-long \
    db_name=ws-mysql-database \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL ON *.* TO '{{name}}'@'%';" \
    default_ttl="12h" \
    max_ttl="24h"

vault write lob_a/workshop/database/roles/workshop-app \
    db_name=ws-mysql-database \
    creation_statements="CREATE USER '{{name}}'@'%' IDENTIFIED BY '{{password}}';GRANT ALL ON *.* TO '{{name}}'@'%';" \
    default_ttl="1m" \
    max_ttl="5m"


#Create Vault policy used by Nomad job
echo
cyan "Define transit-app policy"
echo
tee transit-app-example.policy << EOF
path "lob_a/workshop/database/creds/workshop-app" {
    capabilities = ["read", "list", "create", "update", "delete"]
}
path "lob_a/workshop/database/creds/workshop-app-long" {
    capabilities = ["read", "list", "create", "update", "delete"]
}
path "lob_a/workshop/transit/*" {
    capabilities = ["read", "list", "create", "update", "delete"]
}
path "lob_a/workshop/kv/*" {
    capabilities = ["read", "list", "create", "update", "delete"]
}
path "*" {
    capabilities = ["read", "list", "create", "update", "delete"]
}
EOF
pe "vault policy write transit-app-example transit-app-example.policy"

echo
cyan "Configure K8s as an Identity Provider for our transit-app"
pe "kubectl create serviceaccount vault-auth"
kubectl apply --filename vault/vault-auth-service-account.yaml

# Set VAULT_SA_NAME to the service account you created earlier
export VAULT_SA_NAME=$(kubectl get sa vault-auth -o jsonpath="{.secrets[*]['name']}")

# Set SA_JWT_TOKEN value to the service account JWT used to access the TokenReview API
export SA_JWT_TOKEN=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data.token}" | base64 --decode; echo)

# Set SA_CA_CRT to the PEM encoded CA cert used to talk to Kubernetes API
export SA_CA_CRT=$(kubectl get secret $VAULT_SA_NAME -o jsonpath="{.data['ca\.crt']}" | base64 --decode; echo)

export K8S_HOST="https://kubernetes.default.svc:443"
pe "vault auth enable kubernetes"

p "vault write auth/kubernetes/config \\
        token_reviewer_jwt=\"\$SA_JWT_TOKEN\" \\
        kubernetes_host=\"\$K8S_HOST\" \\
        kubernetes_ca_cert=\"\$SA_CA_CRT\""
        
vault write auth/kubernetes/config \
        token_reviewer_jwt="$SA_JWT_TOKEN" \
        kubernetes_host="$K8S_HOST" \
        kubernetes_ca_cert="$SA_CA_CRT"

vault write auth/kubernetes/role/example \
        bound_service_account_names=vault-auth \
        bound_service_account_namespaces=default \
        policies=transit-app-example \
        ttl=24h

