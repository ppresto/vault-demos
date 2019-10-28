#!/bin/bash
set -v

# Clone the repo
git clone https://github.com/hashicorp/vault-helm.git
helm install  --name=vault -f ./values.yaml ./vault-helm

sleep 30s

#nohup kubectl port-forward service/vault 8200:8200 --pod-running-timeout=1m &

echo ""
echo -n "Get your Vault UI Service name and run 'minikube service vault-ui'"

minikube service list

export VAULT_ADDR=$(minikube service list | grep "vault-ui" | awk '{ print $6 }')
echo $VAULT_ADDR