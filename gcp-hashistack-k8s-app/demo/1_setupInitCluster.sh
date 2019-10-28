#!/bin/bash
#set -v

# Create an account for Tiller and grant it permissions.
if [[ ! $(kubectl get serviceAccounts/tiller -n kube-system > /dev/null 2>&1 ) ]]; then
    kubectl create serviceaccount --namespace kube-system tiller
fi
if [[ ! $(kubectl get clusterrolebinding/tiller-cluster-rule > /dev/null 2>&1) ]]; then
    kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller
fi

# Let Helm deploy and configure the Tiller service.
helm init --service-account tiller --wait

cd consul
./consul.sh
cd ..

cd mariadb
./mariadb.sh
cd ..

sleep 30s

cd vault
./vault.sh
sleep 30
cd ..
