$ErrorActionPreference = "Stop"

Write-Host "Logging into Azure..."
az account show 2>$null
if ($LASTEXITCODE -ne 0) {
    az login
}

Write-Host "Building and pushing Docker images..."
az acr build --registry jdcarenestnewacr --image jdcarenestnewacr.azurecr.io/frontend:latest ./CareNest/frontend
az acr build --registry jdcarenestnewacr --image jdcarenestnewacr.azurecr.io/auth:latest ./CareNest/services/auth
az acr build --registry jdcarenestnewacr --image jdcarenestnewacr.azurecr.io/appointment:latest ./CareNest/services/appointment
az acr build --registry jdcarenestnewacr --image jdcarenestnewacr.azurecr.io/pharmacy:latest ./CareNest/services/pharmacy
az acr build --registry jdcarenestnewacr --image jdcarenestnewacr.azurecr.io/notify:latest ./CareNest/services/notify
az acr build --registry jdcarenestnewacr --image jdcarenestnewacr.azurecr.io/ai:latest ./CareNest/services/ai

Write-Host "Getting AKS credentials..."
az aks get-credentials --resource-group jd-carenest-new-rg --name jd-carenest-new-aks --overwrite-existing

Write-Host "Applying Kubernetes manifests..."
kubectl apply -f ./k8s/namespace.yaml
kubectl apply -f ./k8s/secrets/secret-provider-class.yaml
kubectl apply -f ./k8s/configmaps/
kubectl apply -f ./k8s/rbac/
kubectl apply -f ./k8s/networkpolicies/
kubectl apply -f ./k8s/ingress/
kubectl apply -f ./k8s/deployments/
kubectl apply -f ./k8s/services/
kubectl apply -f ./k8s/hpa/
kubectl apply -f ./k8s/pdb/

Write-Host "Deployment initiated successfully!"
