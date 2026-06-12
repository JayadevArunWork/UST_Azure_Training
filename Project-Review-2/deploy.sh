#!/bin/bash

# Configuration
RG_NAME="jd-carenest-rg"
ACR_NAME="jdcarenestacr"
AKS_NAME="jd-carenest-aks"
LOCATION="Switzerland North"
FRONTEND_IMAGE="$ACR_NAME.azurecr.io/frontend:latest"

# 1. Login to Azure
echo "Logging into Azure..."
az account show || az login

# 2. Build and Push Docker Images
echo "Building and pushing Docker images..."
SERVICES=("frontend" "auth" "appointment" "pharmacy" "notify" "ai")

for SERVICE in "${SERVICES[@]}"; do
    echo "Building $SERVICE..."
    if [ "$SERVICE" == "frontend" ]; then
        az acr build --registry $ACR_NAME --image $ACR_NAME.azurecr.io/$SERVICE:latest ./CareNest/frontend
    else
        az acr build --registry $ACR_NAME --image $ACR_NAME.azurecr.io/$SERVICE:latest ./CareNest/services/$SERVICE
    fi
done

# 3. Get AKS Credentials
echo "Getting AKS credentials..."
az aks get-credentials --resource-group $RG_NAME --name $AKS_NAME --overwrite-existing

# 4. Apply Kubernetes Manifests
echo "Applying Kubernetes manifests..."
kubectl apply -f ./k8s/namespace.yaml

# Create secret provider class
kubectl apply -f ./k8s/secrets/secret-provider-class.yaml

# ConfigMaps
kubectl apply -f ./k8s/configmaps/

# RBAC and Network Policies
kubectl apply -f ./k8s/rbac/
kubectl apply -f ./k8s/networkpolicies/

# Gateway
kubectl apply -f ./k8s/gateway/

# Deployments, Services, HPA, PDB
kubectl apply -f ./k8s/deployments/
kubectl apply -f ./k8s/services/
kubectl apply -f ./k8s/hpa/
kubectl apply -f ./k8s/pdb/

echo "Deployment initiated. Waiting for pods to spin up..."
kubectl get pods -n carenest-dev -w
