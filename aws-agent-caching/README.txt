
# create AWS Keypair and copy pen to working directory

cd /Users/patrickpresto/Projects/ppresto/forks/vault-guides/identity/vault-agent-caching/terraform-aws

#Update key_name
cp variables.tfvars.example variables.tfvars

terraform init. # 0.12
terraform plan
terraform apply

1. Setup Vault Server
    
    SSH Vault External IP

vault operator init
# Save Credentials

vault login

./aws_auth.sh
vault secrets enable kv

echo "path \"kv/*\" {
    capabilities = [\"create\", \"read\", \"update\", \"delete\"]
}
path \"aws/creds/*\" {
    capabilities = [\"read\", \"update\"]
}
path \"sys/leases/*\" {
    capabilities = [\"create\", \"update\"]
}
path \"auth/token/*\" {
    capabilities = [\"create\", \"update\"]
}" | vault policy write myapp -

vault auth enable aws
vault write -force auth/aws/config/client

vault write auth/aws/role/app-role auth_type=iam bound_iam_principal_arn="arn:aws:iam::753646501470:role/ppresto-agent-cache-learning-vault-client-role" policies=myapp ttl=24h

vault auth enable userpass
vault write auth/userpass/users/student password="pAssw0rd" policies="myapp" ttl=48h

verity auth policy
vault policy read myapp

./aws_secrets.sh
vault secrets enable aws
vault write aws/config/root access_key=AKIA266GU7ZPNHFMQE77 secret_key=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
vault write aws/config/lease lease="1h" lease_max="24h"

vault write aws/roles/readonly credential_type="iam_user" policy_arns="arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess"

2. Setup Client

    SSH Client

vault-agent.hcl :
exit_after_auth = false pid_file = "./pidfile" auto_auth { method "aws" { mount_path = "auth/aws" config = { type = "iam" role = "app-role" } } sink "file" { config = { path = "/home/ubuntu/vault-token-via-agent" } } } cache { use_auto_auth_token = true } listener "tcp" { address = "127.0.0.1:8200" tls_disable = true } vault { address = "http://<vault-server-host>:8200" }

Start Agent:
vault agent -config=/home/ubuntu/vault-agent.hcl -log-level=debug

New SSH session to Client (#2)
# verify a token was written after starting client
more vault-token-via-agent

# Read token details
VAULT_TOKEN="$(cat vault-token-via-agent)" vault token lookup

# Setup Env
export VAULT_AGENT_ADDR="http://127.0.0.1:8200"

# Request AWS Cred
vault read aws/creds/readonly

