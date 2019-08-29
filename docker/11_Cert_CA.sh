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


green "create Certificate Root Authority"
echo

cyan "Step 1: Start Vault and PostgreSQL Docker Containers for this exercise"
pe "docker run -d --rm -p 8200:8200 --name vaultdev \\
    --cap-add=IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=my_root_token_id' -e 'VAULT_DEV_LISTEN_ADDRESS=0.0.0.0:8200' vault"

export VAULT_TOKEN=my_root_token_id
export VAULT_ADDR="http://127.0.0.1:8200"

cyan "Check Vault Env"
pe "env | grep VAULT"
vault status

echo
cyan "Step 2: Setup CA Admin Policy and Token"
tee ca-admin-policy.hcl <<EOF
# Enable secrets engine
path "sys/mounts/*" {
  capabilities = [ "create", "read", "update", "delete", "list" ]
}

# List enabled secrets engine
path "sys/mounts" {
  capabilities = [ "read", "list" ]
}

# Work with pki secrets engine
path "pki*" {
  capabilities = [ "create", "read", "update", "delete", "list", "sudo" ]
}
EOF

pe "vault policy write ca-admin-policy ca-admin-policy.hcl"
vault policy read ca-admin-policy

green "Create Token with the ca-admin-policy"
p "vault token create -policy=\"ca-admin-policy\""
TOKEN=$(vault token create -policy="ca-admin-policy")
echo $TOKEN | xargs -n2 | column -t
TOKEN_VALUE=$(echo $TOKEN | xargs -n2 | grep -w token | awk '{ print $2 }')

echo
green "Get Token Capabilities ( ${TOKEN_VALUE} )"
vault token capabilities ${TOKEN_VALUE} sys/auth/pki

cyan "Setup PKI Secrets Engine and Create Root CA"
pe "vault secrets enable pki"

pe "vault secrets tune -max-lease-ttl=87600h pki"

green "Generate the Root Certification Authority"
p "vault write -field=certificate pki/root/generate/internal \\
        common_name=\"example.com\" \\
        ttl=87600h > CA_cert.crt"

vault write -field=certificate pki/root/generate/internal \
        common_name="example.com" \
        ttl=87600h > CA_cert.crt

green "Configure the CA and CRL (Cert Revocation List)"
p "vault write pki/config/urls \\
        issuing_certificates=\"http://127.0.0.1:8200/v1/pki/ca\" \\
        crl_distribution_points=\"http://127.0.0.1:8200/v1/pki/crl\""

vault write pki/config/urls \
        issuing_certificates="http://127.0.0.1:8200/v1/pki/ca" \
        crl_distribution_points="http://127.0.0.1:8200/v1/pki/crl"

green "Print CA_cert.crt in text form"
pe "openssl x509 -in CA_cert.crt -text"

echo
green "Print the validity dates"
pe "openssl x509 -in CA_cert.crt -noout -dates"

echo
cyan "Generate the Intermediate CA"

green "enable pki secrets engine at /pki_int"
pe "vault secrets enable -path=pki_int pki"
pe "vault secrets tune -max-lease-ttl=43800h pki_int"
echo
green "Generate the intermediate cert and save the CSR as pki_intermediate.csr"
p "vault write -format=json pki_int/intermediate/generate/internal \\
        common_name=\"example.com Intermediate Authority\" \\
        | jq -r '.data.csr' > pki_intermediate.csr"

vault write -format=json pki_int/intermediate/generate/internal \
        common_name="example.com Intermediate Authority" \
        | jq -r '.data.csr' > pki_intermediate.csr

green "Sign the intermediate cert with the root CA and save to intermediate.cert.pem"
p "vault write -format=json pki/root/sign-intermediate csr=@pki_intermediate.csr \\
        format=pem_bundle ttl=\"43800h\" \\
        | jq -r '.data.certificate' > intermediate.cert.pem"

vault write -format=json pki/root/sign-intermediate csr=@pki_intermediate.csr \
        format=pem_bundle ttl="43800h" \
        | jq -r '.data.certificate' > intermediate.cert.pem

echo
green "After CSR is signed and the root CA returns a cert, it can be imported back into Vault"
pe "vault write pki_int/intermediate/set-signed certificate=@intermediate.cert.pem"

echo
cyan "Create a Role for example.com to allow subdomains"
p "vault write pki_int/roles/example-dot-com \\
        allowed_domains=\"example.com\" \\
        allow_subdomains=true \\
        max_ttl=\"720h\""

vault write pki_int/roles/example-dot-com \
        allowed_domains="example.com" \
        allow_subdomains=true \
        max_ttl="720h"

cyan "Removing containers and all generated files before exiting"
#docker kill vaultdev
#rm ${DIR}/ca-admin-policy.hcl
#rm ${DIR}/CA_cert.crt
