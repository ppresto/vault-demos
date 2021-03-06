#!/bin/bash

echo "Installing Consul from Helm chart repo..."
git clone https://github.com/hashicorp/consul-helm.git
helm install --name=consul -f ./values.yaml ./consul-helm

sleep 10s

cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  labels:
    addonmanager.kubernetes.io/mode: EnsureExists
  name: kube-dns
  namespace: kube-system
data:
  stubDomains: |
    {"consul": ["$(kubectl get svc consul-consul-dns -o jsonpath='{.spec.clusterIP}')"]}
EOF

sleep 5s

echo ""
echo -n "Get your Consul UI Service name and run 'minikube service <service-ui-name>'"

minikube service list

minikube service consul-consul-ui