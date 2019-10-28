#!/bin/bash
#set -v


kubectl apply -f ./application_deploy
while [[ $(kubectl get svc k8s-transit-app | grep pending) ]];
    do
        kubectl get svc k8s-transit-app | grep k8s-transit-app;
        sleep 2;
    done
echo
echo "kubectl get svc k8s-transit-app"
echo
kubectl get svc k8s-transit-app
ext_ip=$(kubectl get svc k8s-transit-app | grep k8s-transit-app | awk '{ print $4 }')
port=$(kubectl get svc k8s-transit-app | grep k8s-transit-app | awk '{ print $5 }' | cut -d: -f1)
open http://${ext_ip}:${port}

echo
echo "To add Replicas"
echo "kubectl scale deployments k8s-transit-app --replicas=2"
