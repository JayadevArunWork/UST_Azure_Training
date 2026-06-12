# Sentinel Dev-Minimal Terraform

This Terraform root creates the smallest Azure environment needed to open Sentinel and
complete Microsoft sign-in successfully.

It intentionally deploys only these long-running Kubernetes workloads:

- `web`
- `identity-service`
- `sentinel-gateway`

The migration image runs once as a Kubernetes Job. It creates and upgrades the
PostgreSQL schema required by Identity Service, then exits. Inventory, subscriptions,
resource discovery, workers, Audit, Relationship, Operations, and Change Intelligence
are not included.

## Architecture

```text
Internet
   |
sentinel.vaultrix.in
   |
Azure Load Balancer public IP
   |
sentinel-gateway (Nginx/TLS)
   |--------------------|
   |                    |
web                identity-service
                         |       |
                    PostgreSQL  Key Vault CSI
```

Terraform creates:

- one resource group
- one VNet with an AKS subnet and a private-endpoint subnet
- one single-node-pool AKS cluster
- one fixed AKS outbound public IP
- one fixed gateway public IP
- one user-assigned workload identity with federated credentials for Web and Identity
- one private Key Vault and private DNS zone
- one PostgreSQL Flexible Server and `sentinel` database

It does not create ACR, a build VM, Front Door, Application Gateway, Storage Account,
or any resource-inventory services. Existing public Docker Hub images are used:

| Component | Image |
|---|---|
| Web | `elzabeth03/sentinel-web:v1.0.5` |
| Identity | `elzabeth03/sentinel-identity-service:v1.0.3` |
| Migration Job | `elzabeth03/sentinel-migration:v1.0.3` |
| Gateway | `nginx:1.27-alpine` |

## 1. Entra Application

Keep the Entra application registration outside Terraform so its client secret never
enters Terraform state.

Configure:

- Redirect URI: `https://sentinel.vaultrix.in/auth/callback`
- Platform: Web
- Microsoft API: Azure Service Management
- Delegated permission: `user_impersonation`
- Grant consent when required by the tenant

Record the application client ID and create a client secret value. Store the value in
Key Vault later; do not add it to Terraform files.

## 2. Configure Terraform

From `terraform/dev-minimal`:

```powershell
Copy-Item terraform.tfvars.example terraform.tfvars
```

Edit `name_suffix` so it is globally unique. Replace the example IPs or remove the
optional entries. Supply the PostgreSQL password only through the process environment:

```powershell
$env:TF_VAR_postgres_admin_password = "<strong-password>"
az login --tenant 83474cb5-f1fa-4d06-906c-e5dad12ce3b9
az account set --subscription 6b01db76-626a-44a2-8119-17682410914a

terraform init
terraform plan -out dev-minimal.tfplan
terraform apply dev-minimal.tfplan
```

Before planning, confirm that Azure CLI can see the development subscription:

```powershell
az account show --subscription 6b01db76-626a-44a2-8119-17682410914a
```

At the time this root was validated, the current local Azure CLI session could see the
production subscription in tenant `83474cb5-f1fa-4d06-906c-e5dad12ce3b9`, but not this
development subscription. If the command fails, refresh the login with an account that
has access to `sentinel-dev` or restore its RBAC assignment before running `apply`.

This root currently uses local Terraform state. The state contains the PostgreSQL
administrator password and must not be committed or shared.

## 3. Connect To AKS

```powershell
$rg = terraform output -raw resource_group_name
$aks = terraform output -raw aks_name
az aks get-credentials --resource-group $rg --name $aks --overwrite-existing
```

## 4. Add Key Vault Secrets

Create these five secrets:

| Key Vault secret | Purpose |
|---|---|
| `postgres-runtime-url` | Identity database connection |
| `internal-api-token` | Internal API authentication |
| `identity-microsoft-client-secret` | Entra application secret value |
| `identity-session-signing-key` | Browser session signing |
| `identity-token-encryption-key` | Refresh-token encryption |

The database URL format is:

```text
postgresql+asyncpg://sentineladmin:<URL_ENCODED_PASSWORD>@<POSTGRES_FQDN>:5432/sentinel?ssl=require
```

URL-encode reserved password characters inside this URL. For example, `@` becomes
`%40`. The Key Vault secret for the Microsoft client must contain the secret **value**,
not its secret ID.

The vault is private by default. Seed it from a machine with private VNet connectivity,
or temporarily grant your operator identity `Key Vault Secrets Officer` and temporarily
enable selected public-network access for your current IP in the Azure portal. Remove
that role and restore public access to **Disabled** immediately after adding the five
secrets. Do not make this temporary operator access part of Terraform.

Generate strong random values locally when needed:

```powershell
$bytes = New-Object byte[] 48
[Security.Cryptography.RandomNumberGenerator]::Fill($bytes)
[Convert]::ToBase64String($bytes)
```

## 5. Render Kubernetes Manifests

Run:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\render-manifests.ps1 -EntraClientId "<ENTRA-APPLICATION-CLIENT-ID>"
```

Rendered YAML is written to `rendered/`, which is ignored by Git. Review it and confirm
that no `REPLACE_ME_` placeholders remain:

```powershell
rg "REPLACE_ME_" rendered
```

The command should return no matches.

## 6. Create TLS Secret

Use a certificate valid for `sentinel.vaultrix.in`:

```powershell
kubectl apply -f rendered/00-auth-foundation.yaml

kubectl create secret tls sentinel-gateway-tls `
  --cert="sentinel.vaultrix.in.crt" `
  --key="sentinel.vaultrix.in.key" `
  --namespace sentinel-app
```

## 7. Run Migration

The CSI mount first synchronizes Key Vault values into
`identity-service-runtime`. Then the Job applies Alembic migrations:

```powershell
kubectl delete job sentinel-database-migration -n sentinel-app --ignore-not-found
kubectl apply -f rendered/04-database-migration-job.yaml
kubectl wait --for=condition=complete job/sentinel-database-migration `
  -n sentinel-app --timeout=300s
kubectl logs job/sentinel-database-migration -n sentinel-app
```

Expected output includes:

```text
Context impl PostgresqlImpl.
Will assume transactional DDL.
```

## 8. Deploy Authentication Workloads

```powershell
kubectl apply -f rendered/10-web.yaml
kubectl apply -f rendered/11-identity-service.yaml
kubectl apply -f rendered/50-gateway-auth-only.yaml

kubectl rollout status deployment/web -n sentinel-app --timeout=300s
kubectl rollout status deployment/identity-service -n sentinel-app --timeout=300s
kubectl rollout status deployment/sentinel-gateway -n sentinel-app --timeout=300s
kubectl get pods,svc -n sentinel-app
```

## 9. Configure DNS

Read the fixed gateway address:

```powershell
terraform output -raw gateway_public_ip
```

At the authoritative DNS provider for `vaultrix.in`, create or update:

```text
Type: A
Name: sentinel
Value: <gateway_public_ip>
```

Wait for DNS propagation:

```powershell
Resolve-DnsName sentinel.vaultrix.in
```

## 10. Verify Login

Health:

```powershell
curl.exe -k https://sentinel.vaultrix.in/api/v1/auth/health/live
curl.exe -k https://sentinel.vaultrix.in/api/v1/auth/health/ready
```

Then open `https://sentinel.vaultrix.in`, select Microsoft sign-in, and complete the
callback. A successful callback creates the Sentinel session cookie and returns to the
web application.

The UI may display empty or failed inventory panels because this deployment deliberately
does not include Inventory Service. That does not indicate an authentication failure.

Useful diagnostics:

```powershell
kubectl logs deployment/identity-service -n sentinel-app --tail=200
kubectl logs deployment/sentinel-gateway -n sentinel-app --tail=200
kubectl describe pod -n sentinel-app -l app.kubernetes.io/name=identity-service
```

## Destroy

```powershell
terraform destroy
```

Key Vault soft deletion can retain the vault name after destroy. This Terraform root
does not purge the vault automatically.
