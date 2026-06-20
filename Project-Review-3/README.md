# CareNest Azure Cloud Native Deployment

CareNest is a full-stack healthcare management platform deployed entirely on Azure using cloud-native technologies.

## Architecture

- **Infrastructure as Code**: Terraform modules
- **Compute**: Azure Kubernetes Service (AKS) with Azure CNI and Calico Network Policies
- **API Gateway**: Envoy Gateway (Gateway API)
- **Identity**: Microsoft Entra ID
- **Database**: Azure Cosmos DB for MongoDB
- **Messaging**: Azure Service Bus
- **Storage**: Azure Blob Storage
- **AI**: Azure AI Foundry (OpenAI gpt-4o, gpt-4o-mini, and Language Text Analytics)
- **Security**: Azure Key Vault integrated via Secrets Store CSI Driver, Azure Application Gateway with WAF v2, Azure Front Door
- **Monitoring**: Azure Monitor with Managed Prometheus and Managed Grafana
- **Container Registry**: Azure Container Registry (ACR)

## Prerequisites

1. Azure CLI (`az`)
2. Terraform (`terraform`)
3. `kubectl`

## Deployment Steps

1. **Deploy Infrastructure**:
   Navigate to `carenest-infrastructure/` and run:
   ```bash
   terraform init
   terraform apply
   ```

2. **Entra ID Post-Deployment**:
   - Navigate to Microsoft Entra ID in the Azure Portal.
   - Find the registered Enterprise Application for `jd-carenest-app`.
   - Manually assign the App Roles `Doctor` and `Patient` to the respective users or groups.

3. **Deploy Application**:
   Run the deployment script from the root directory to build images, push to ACR, and apply Kubernetes manifests:
   ```bash
   chmod +x deploy.sh
   ./deploy.sh
   ```

## Services

- **frontend**: React application (MSAL integrated)
- **auth-service**: Entra ID and local JWT auth
- **appointment-service**: Appointment management and Service Bus event publisher
- **pharmacy-service**: Prescriptions, PDF generation, Blob Storage, Service Bus event publisher
- **notify-service**: Service Bus consumer for notifications
- **ai-service**: AI Foundry integration (Symptom Checker, Prescription Summary, Chatbot)
