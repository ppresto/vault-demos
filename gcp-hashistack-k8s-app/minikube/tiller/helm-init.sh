    
#!/bin/bash

# Create an account for Tiller and grant it permissions.
kubectl create serviceaccount --namespace kube-system tiller
kubectl create clusterrolebinding tiller-cluster-rule --clusterrole=cluster-admin --serviceaccount=kube-system:tiller

# BUG: Let Helm deploy and configure the Tiller service.
#helm init --service-account tiller

# Workaround
# helm init --output yaml > tiller.yaml
# Change apiVersion: apps/v1, and Add selector field
#---
#apiVersion: apps/v1
#spec:
#  replicas: 1
#  strategy: {}
#  selector:
#    matchLabels:
#      app: helm
#      name: tiller
#---
kubectl apply -f tiller.yaml