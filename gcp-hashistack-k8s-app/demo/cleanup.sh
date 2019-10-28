#!/bin/bash

kubectl delete -f ./application_deploy

helm delete --purge consul
kubectl delete svc consul

helm delete --purge vault
kubectl delete serviceaccounts/vault-auth

helm delete --purge mariadb

kubectl delete pvc data-default-consul-consul-server-0
kubectl delete pvc data-default-consul-consul-server-1
kubectl delete pvc data-default-consul-consul-server-2

kubectl delete clusterrolebinding/tiller-cluster-rule
kubectl delete serviceaccounts/tiller -n kube-system
kubectl delete deployment tiller-deploy -n kube-system
kubectl delete service tiller-deploy -n kube-system

pkill kubectl
rm /tmp/root-token
rm /tmp/unseal-key
rm transit-app-example.policy