# Sentinel Dev-Minimal Portal Deployment Guide

This guide shows how another user can deploy the minimal Sentinel login demo into their own Azure subscription, AKS cluster, Key Vault, PostgreSQL database, and custom domain.

The guide is portal-first, with commands only where the Azure Portal is not practical. It deploys only the login path:

`Internet -> AKS LoadBalancer -> Nginx gateway -> Web + Identity Service -> PostgreSQL + Key Vault`

It does not deploy the full inventory/resource graph microservice setup.

No App Service, ACR, Front Door, or Application Gateway is used in this minimal version. The application runs on AKS and pulls the existing public Docker Hub images listed below.

## 0. End-to-End Flow

1. Choose a public subdomain, for example `sentinel.yourdomain.com`.
2. Create one Azure resource group.
3. Create one VNet with an AKS subnet and a private endpoint subnet.
4. Create static public IPs for AKS outbound traffic and the gateway LoadBalancer.
5. Create AKS with workload identity, OIDC issuer, Key Vault CSI provider, and one node pool.
6. Create a user-assigned managed identity for the application pods.
7. Add federated credentials for the Kubernetes service accounts.
8. Create Key Vault with private endpoint and RBAC.
9. Create PostgreSQL Flexible Server and database.
10. Create or update the Microsoft Entra app registration with `https://<DOMAIN>/auth/callback`.
11. Point the public DNS subdomain to the AKS gateway public IP.
12. Apply the Kubernetes manifests for web, identity, migration, gateway, and TLS.
13. Issue a trusted Let's Encrypt certificate for the custom domain.
14. Test Microsoft login at `https://<DOMAIN>`.

## 1. Placeholder Values

Replace these before running commands:

| Placeholder | Meaning | Example format |
| --- | --- | --- |
| `<SUBSCRIPTION_ID>` | Azure subscription ID | `00000000-0000-0000-0000-000000000000` |
| `<TENANT_ID>` | Microsoft Entra tenant ID | `00000000-0000-0000-0000-000000000000` |
| `<RESOURCE_GROUP>` | Main resource group | `rg-your-app-dev` |
| `<LOCATION>` | Azure region | `southindia`, `centralindia`, etc. |
| `<UNIQUE_SUFFIX>` | 4-8 lowercase alphanumeric suffix | `abc123` |
| `<DOMAIN>` | Public app DNS name | `sentinel.example.com` |
| `<DNS_HOST>` | Host part of the subdomain | `sentinel` |
| `<DNS_ZONE>` | Parent DNS zone/domain | `example.com` |
| `<OWNER>` | Owner tag value | `your-name` |
| `<ENTRA_CLIENT_ID>` | App registration client ID | GUID |
| `<ENTRA_CLIENT_SECRET_VALUE>` | App registration client secret value | secret value, not secret ID |
| `<UAMI_CLIENT_ID>` | User-assigned managed identity client ID | GUID |
| `<KEY_VAULT_NAME>` | Key Vault name | `kvsentinel<suffix>` |
| `<POSTGRES_SERVER_NAME>` | PostgreSQL server name | `psql-sentinel-<suffix>` |
| `<POSTGRES_ADMIN_LOGIN>` | PostgreSQL admin login | `sentineladmin` |
| `<POSTGRES_ADMIN_PASSWORD>` | PostgreSQL admin password | never commit |
| `<GATEWAY_PUBLIC_IP_NAME>` | Gateway public IP resource name | `pip-sentinel-gateway` |
| `<AKS_NAME>` | AKS cluster name | `aks-sentinel` |

Images used:

| Component | Image |
| --- | --- |
| Web | `elzabeth03/sentinel-web:v1.0.5` |
| Identity service | `elzabeth03/sentinel-identity-service:v1.0.3` |
| Migration | `elzabeth03/sentinel-migration:v1.0.3` |
| Gateway | `nginx:1.27-alpine` |
| Key Vault seeder | `mcr.microsoft.com/azure-cli:2.75.0` |
| TLS certificate job | `certbot/certbot:v5.6.0` |

Do not rebuild the images for this minimal demo. The gateway rewrites the frontend's baked API URL to your `<DOMAIN>` at runtime.

## 2. Target Network Design

Use one resource group and one virtual network.

| Item | Value |
| --- | --- |
| Resource group | `<RESOURCE_GROUP>` |
| Region | `<LOCATION>` |
| VNet name | `vnet-sentinel` |
| VNet address space | `10.20.0.0/16` |
| AKS subnet | `snet-aks`, `10.20.1.0/24` |
| Private endpoint subnet | `snet-private-endpoints`, `10.20.2.0/24` |
| AKS service CIDR | `10.21.0.0/16` |
| AKS DNS service IP | `10.21.0.10` |
| AKS pod CIDR | `10.244.0.0/16` |

If your existing network already uses `10.20.0.0/16`, choose another non-overlapping private range and keep the subnet/service/pod CIDRs non-overlapping.

## 3. Domain and Subdomain Plan

Each deployer should use their own real public domain or subdomain. Do not use the LoadBalancer IP as the final application URL because Microsoft OAuth redirect URIs and HTTPS certificates need a stable hostname.

Recommended format:

```text
<DOMAIN> = <DNS_HOST>.<DNS_ZONE>
Example: sentinel.example.com
```

If the domain is hosted in GoDaddy, Namecheap, Cloudflare, Azure DNS, or another provider, create the DNS record after the gateway public IP is created:

| Type | Host/name | Value |
| --- | --- | --- |
| `A` | `<DNS_HOST>` | AKS gateway public IP |

Examples:

| Desired URL | DNS zone | Record host/name | Record value |
| --- | --- | --- | --- |
| `https://sentinel.example.com` | `example.com` | `sentinel` | Gateway public IP |
| `https://demo.company.com` | `company.com` | `demo` | Gateway public IP |

### GoDaddy example

If the domain is in GoDaddy and you want `https://sentinel.example.com`:

1. Open GoDaddy -> **My Products** -> your domain -> **DNS**.
2. Under **Records**, select **Add New Record**.
3. Type: `A`.
4. Name: `sentinel`.
5. Value: gateway public IP.
6. TTL: `600 seconds` or the lowest available value.
7. Save.

If a record named `sentinel` already exists:

- Delete the old `A` record before adding the new one, or edit it to the gateway public IP.
- Delete any `CNAME` record named `sentinel`; DNS cannot have an `A` and `CNAME` for the same host.

### Azure DNS example

If the domain is hosted in Azure DNS:

1. Go to **DNS zones**.
2. Open `<DNS_ZONE>`.
3. Select **Record set**.
4. Name: `<DNS_HOST>`.
5. Type: `A`.
6. TTL: `600`.
7. IP address: gateway public IP.
8. Save.

Important:

- Remove any existing `A` or `CNAME` record for the same host before adding the new one.
- Use a low TTL such as `600` seconds for demo deployments.
- Wait until `Resolve-DnsName <DOMAIN>` or `nslookup <DOMAIN>` returns the gateway public IP before requesting TLS.

## 4. Create Resource Group

Azure Portal:

1. Go to **Resource groups**.
2. Select **Create**.
3. Subscription: `<SUBSCRIPTION_ID>`.
4. Resource group: `<RESOURCE_GROUP>`.
5. Region: `<LOCATION>`.
6. Tags:
   - `application = sentinel`
   - `environment = dev-minimal`
   - `owner = <OWNER>`
   - `data_classification = confidential`
   - `managed_by = portal`

## 5. Create Virtual Network

Azure Portal:

1. Go to **Virtual networks** -> **Create**.
2. Resource group: `<RESOURCE_GROUP>`.
3. Name: `vnet-sentinel`.
4. Region: `<LOCATION>`.
5. Address space: `10.20.0.0/16`.
6. Add subnet:
   - Name: `snet-aks`
   - Address range: `10.20.1.0/24`
7. Add subnet:
   - Name: `snet-private-endpoints`
   - Address range: `10.20.2.0/24`
   - Private endpoint network policies: **Disabled**

## 6. Create Public IPs

Create two Standard static public IPs.

### AKS outbound IP

Azure Portal:

1. Go to **Public IP addresses** -> **Create**.
2. Name: `pip-sentinel-aks-outbound`.
3. SKU: **Standard**.
4. Tier: **Regional**.
5. IP assignment: **Static**.
6. Resource group: `<RESOURCE_GROUP>`.
7. Region: `<LOCATION>`.

### Gateway LoadBalancer IP

Azure Portal:

1. Go to **Public IP addresses** -> **Create**.
2. Name: `<GATEWAY_PUBLIC_IP_NAME>`.
3. SKU: **Standard**.
4. Tier: **Regional**.
5. IP assignment: **Static**.
6. DNS name label: `sentinel-<UNIQUE_SUFFIX>`.
7. Resource group: `<RESOURCE_GROUP>`.
8. Region: `<LOCATION>`.

After creation, copy the gateway public IP address. Use it in your DNS `A` record:

| Type | Name | Value |
| --- | --- | --- |
| `A` | `sentinel` or your chosen host | Gateway public IP |

For example, `<DOMAIN>` should resolve to the gateway public IP.

Verify from your machine:

```powershell
Resolve-DnsName <DOMAIN>
```

The answer must be the gateway public IP.

## 7. Create Managed Identities

Create two user-assigned managed identities.

### AKS control plane identity

Azure Portal:

1. Go to **Managed Identities** -> **Create**.
2. Resource group: `<RESOURCE_GROUP>`.
3. Region: `<LOCATION>`.
4. Name: `id-sentinel-aks-control`.
5. After creation, open the identity and copy:
   - **Client ID**
   - **Object/principal ID**

For a Portal-only setup, assign `Network Contributor` to this identity on these scopes:

| Scope | Role |
| --- | --- |
| `vnet-sentinel` virtual network | `Network Contributor` |
| `pip-sentinel-aks-outbound` public IP | `Network Contributor` |
| `<GATEWAY_PUBLIC_IP_NAME>` public IP | `Network Contributor` |

These are required because AKS must attach nodes to the VNet/subnet, use the outbound public IP, and later bind the gateway LoadBalancer service to the reserved gateway public IP.

Terraform used the narrower subnet scope for `snet-aks`, but the Azure Portal commonly does not expose a clean subnet IAM flow. For this Portal guide, use the VNet scope. It is still correct for the deployment and is the practical Portal path.

#### Assign VNet role in the Portal

1. Open **Virtual networks**.
2. Open `vnet-sentinel`.
3. Select **Access control (IAM)** from the left menu.
4. Select **Add** -> **Add role assignment**.
5. On **Role**, search for `Network Contributor`.
6. Select `Network Contributor`, then **Next**.
7. On **Members**, set **Assign access to** as `Managed identity`.
8. Select **+ Select members**.
9. Managed identity type: **User-assigned managed identity**.
10. Subscription: `<SUBSCRIPTION_ID>`.
11. Select `id-sentinel-aks-control`.
12. Select **Select**.
13. Select **Review + assign**.

#### Assign public IP roles in the Portal

Do this once for `pip-sentinel-aks-outbound` and once for `<GATEWAY_PUBLIC_IP_NAME>`:

1. Open **Public IP addresses**.
2. Open the public IP resource.
3. Select **Access control (IAM)**.
4. Select **Add** -> **Add role assignment**.
5. Role: `Network Contributor`.
6. Assign access to: **Managed identity**.
7. Managed identity: `id-sentinel-aks-control`.
8. Review + assign.

### App workload identity

Azure Portal:

1. Go to **Managed Identities** -> **Create**.
2. Resource group: `<RESOURCE_GROUP>`.
3. Region: `<LOCATION>`.
4. Name: `id-sentinel-app`.
5. Copy its **Client ID** as `<UAMI_CLIENT_ID>`.

## 8. Create AKS Cluster

Azure Portal:

1. Go to **Kubernetes services** -> **Create** -> **Create a Kubernetes cluster**.
2. Basics:
   - Subscription: `<SUBSCRIPTION_ID>`
   - Resource group: `<RESOURCE_GROUP>`
   - Cluster name: `<AKS_NAME>`
   - Region: `<LOCATION>`
   - Kubernetes version: default stable
   - Node resource group: `<RESOURCE_GROUP>-aks-nodes`
   - Pricing tier: **Free**
3. Node pools:
   - Keep only one system node pool.
   - Node pool name: `system`
   - Mode: `System`
   - VM size: `Standard_D2s_v3`
   - Scale method: **Manual**
   - Node count: `1`
   - OS disk size: `64 GiB`
   - Node labels:
     - `<DOMAIN>/pool = combined`
4. Authentication and authorization:
   - Authentication method: local accounts allowed for this dev setup
   - Kubernetes RBAC: **Enabled**
5. Networking:
   - Network configuration: **Azure CNI Overlay**
   - Network policy: **Cilium**
   - Network dataplane: **Cilium**
   - Bring your own virtual network: **Yes**
   - Virtual network: `vnet-sentinel`
   - Cluster subnet: `snet-aks`
   - Kubernetes service address range: `10.21.0.0/16`
   - Kubernetes DNS service IP: `10.21.0.10`
   - Pod CIDR: `10.244.0.0/16`
   - Load balancer SKU: **Standard**
   - Outbound type: **Load balancer**
   - Outbound public IP: `pip-sentinel-aks-outbound`
6. Integrations:
   - Azure Key Vault Secrets Provider: **Enabled**
   - Secret rotation: **Enabled**
   - Rotation interval: `2m`
7. Advanced:
   - OIDC issuer: **Enabled**
   - Workload identity: **Enabled**
   - Managed identity: user-assigned `id-sentinel-aks-control`

After creation, copy the AKS **OIDC issuer URL**.

## 9. Add Federated Credentials

Azure Portal:

1. Open `id-sentinel-app`.
2. Go to **Federated credentials** -> **Add credential**.
3. Scenario: **Kubernetes accessing Azure resources**.

Create credential 1:

| Field | Value |
| --- | --- |
| Cluster issuer URL | AKS OIDC issuer URL |
| Namespace | `sentinel-app` |
| Service account | `web` |
| Name | `fc-web` |
| Audience | `api://AzureADTokenExchange` |

Create credential 2:

| Field | Value |
| --- | --- |
| Cluster issuer URL | AKS OIDC issuer URL |
| Namespace | `sentinel-app` |
| Service account | `identity-service` |
| Name | `fc-identity-service` |
| Audience | `api://AzureADTokenExchange` |

## 10. Create Key Vault

Azure Portal:

1. Go to **Key vaults** -> **Create**.
2. Resource group: `<RESOURCE_GROUP>`.
3. Name: `<KEY_VAULT_NAME>`.
4. Region: `<LOCATION>`.
5. Pricing tier: **Standard**.
6. Permission model: **Azure role-based access control**.
7. Soft-delete retention: `7 days`.
8. Purge protection: **Disabled** for dev-minimal. Use **Enabled** for production.
9. Networking:
   - Public network access: **Disabled**
   - Firewall bypass: **Allow trusted Microsoft services**.

Assign role:

| Principal | Scope | Role |
| --- | --- | --- |
| `id-sentinel-app` | Key Vault | `Key Vault Secrets User` |

Temporarily, for the seeding step only, also assign:

| Principal | Scope | Role |
| --- | --- | --- |
| `id-sentinel-app` | Key Vault | `Key Vault Secrets Officer` |

Remove `Key Vault Secrets Officer` after the secrets are written.

## 11. Create Key Vault Private Endpoint

Azure Portal:

1. Open `<KEY_VAULT_NAME>`.
2. Go to **Networking** -> **Private endpoint connections** -> **Create**.
3. Name: `pe-kv-sentinel`.
4. Region: `<LOCATION>`.
5. Virtual network: `vnet-sentinel`.
6. Subnet: `snet-private-endpoints`.
7. Target sub-resource: `vault`.
8. Integrate with private DNS zone: **Yes**.
9. Private DNS zone: `privatelink.vaultcore.azure.net`.

Verify that the private DNS zone is linked to `vnet-sentinel`.

## 12. Create PostgreSQL Flexible Server

Azure Portal:

1. Go to **Azure Database for PostgreSQL flexible servers** -> **Create**.
2. Resource group: `<RESOURCE_GROUP>`.
3. Server name: `<POSTGRES_SERVER_NAME>`.
4. Region: `<LOCATION>`.
5. PostgreSQL version: `16`.
6. Workload type: development.
7. Compute SKU: `B_Standard_B1ms`. If unavailable, use `B_Standard_B2ms`.
8. Storage: `32 GiB`.
9. Administrator login: `<POSTGRES_ADMIN_LOGIN>`.
10. Password: `<POSTGRES_ADMIN_PASSWORD>`.
11. Networking:
    - Public access: **Enabled**
    - Add firewall rule for AKS outbound public IP:
      - Name: `aks-outbound`
      - Start IP: AKS outbound public IP
      - End IP: AKS outbound public IP
12. Backup:
    - Retention: `7 days`
    - Geo-redundant backup: **Disabled**

After creation:

1. Open the server.
2. Go to **Databases** -> **Add**.
3. Database name: `sentinel`.
4. Charset: `UTF8`.
5. Collation: `en_US.utf8`.

Enable extension allow-list:

```powershell
az postgres flexible-server parameter set `
  --subscription "<SUBSCRIPTION_ID>" `
  --resource-group "<RESOURCE_GROUP>" `
  --server-name "<POSTGRES_SERVER_NAME>" `
  --name azure.extensions `
  --value PGCRYPTO
```

## 13. Create Microsoft Entra App Registration and Callback URI

Azure Portal:

1. Go to **Microsoft Entra ID** -> **App registrations** -> **New registration**.
2. Name: `APP-REG-AUTH`.
3. Supported account types:
   - If each deployer uses only their own tenant, choose **Accounts in this organizational directory only**.
   - If the same app registration must support multiple tenants, choose **Accounts in any organizational directory**.
4. Redirect URI:
   - Platform: Web
   - URI: `https://<DOMAIN>/auth/callback`
5. Copy the application client ID as `<ENTRA_CLIENT_ID>`.

If you already created the app registration but forgot the callback URL:

1. Open **Microsoft Entra ID** -> **App registrations**.
2. Open your application.
3. Go to **Authentication**.
4. If no web platform exists, select **Add a platform** -> **Web**.
5. Add this redirect URI:

   ```text
   https://<DOMAIN>/auth/callback
   ```

6. Under **Implicit grant and hybrid flows**, leave access tokens and ID tokens unchecked for this Authorization Code + PKCE flow.
7. Select **Save**.

The callback URI must exactly match the deployed domain and path. These are different values and must not be mixed:

| Environment | Callback URI |
| --- | --- |
| Custom domain | `https://<DOMAIN>/auth/callback` |
| Temporary Azure public IP | Do not use for OAuth |
| Old/other domain | Do not leave as the only redirect URI |

Create a client secret:

1. Go to **Certificates & secrets**.
2. Add a new client secret.
3. Copy the **Value** immediately as `<ENTRA_CLIENT_SECRET_VALUE>`.

API permissions:

| API | Permission |
| --- | --- |
| Microsoft Graph | `User.Read` |
| Azure Service Management | `user_impersonation` |

Grant admin consent if your tenant requires it.

## 14. Render Kubernetes Manifests

Use the manifest templates from this repo, or replace placeholders manually.

```powershell
cd terraform/dev-minimal
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\render-manifests.ps1 `
  -EntraClientId "<ENTRA_CLIENT_ID>" `
  -Domain "<DOMAIN>" `
  -OutputDirectory ".\rendered"
```

Confirm no placeholders remain:

```powershell
rg "REPLACE_ME_" rendered
```

The rendered ConfigMap must contain your own domain:

```yaml
SENTINEL_MICROSOFT_REDIRECT_URI: https://<DOMAIN>/auth/callback
SENTINEL_FRONTEND_URL: https://<DOMAIN>
SENTINEL_CORS_ORIGINS: '["https://<DOMAIN>"]'
```

## 15. Connect to AKS

From Azure Cloud Shell or your terminal:

```powershell
az account set --subscription "<SUBSCRIPTION_ID>"
az aks get-credentials `
  --resource-group "<RESOURCE_GROUP>" `
  --name "<AKS_NAME>" `
  --overwrite-existing
```

If your local environment cannot use `kubectl`, use AKS Run Command from the portal:

1. Open AKS.
2. Go to **Run command**.
3. Upload the manifest file if needed.
4. Run the `kubectl` commands shown below.

## 16. Apply Foundation

```powershell
kubectl apply -f rendered/00-auth-foundation.yaml
```

This creates:

- Namespace `sentinel-app`
- ConfigMap `sentinel-runtime-config`
- ServiceAccounts `web` and `identity-service`
- SecretProviderClass `identity-service-secrets`

## 17. Seed Key Vault from AKS

Build the database URL. URL-encode special password characters, for example `@` becomes `%40`.

```powershell
$DATABASE_URL = "postgresql+asyncpg://<POSTGRES_ADMIN_LOGIN>:<URL_ENCODED_POSTGRES_PASSWORD>@<POSTGRES_SERVER_NAME>.postgres.database.azure.com:5432/sentinel?ssl=require"
```

Generate runtime secrets:

```powershell
$INTERNAL_API_TOKEN = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
$SESSION_SIGNING_KEY = [Convert]::ToBase64String([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
```

Generate a Fernet key for token encryption:

```powershell
python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"
```

Create a temporary Kubernetes secret containing base64-encoded values:

```powershell
kubectl create secret generic sentinel-seed-values `
  -n sentinel-app `
  --from-literal=KEY_VAULT_NAME="<KEY_VAULT_NAME>" `
  --from-literal=DATABASE_URL_B64="$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($DATABASE_URL)))" `
  --from-literal=INTERNAL_API_TOKEN_B64="$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($INTERNAL_API_TOKEN)))" `
  --from-literal=MICROSOFT_CLIENT_SECRET_B64="$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('<ENTRA_CLIENT_SECRET_VALUE>')))" `
  --from-literal=SESSION_SIGNING_KEY_B64="$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($SESSION_SIGNING_KEY)))" `
  --from-literal=TOKEN_ENCRYPTION_KEY_B64="$([Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes('<FERNET_KEY>')))"
```

Run the seeder:

```powershell
kubectl delete job sentinel-key-vault-seeder -n sentinel-app --ignore-not-found
kubectl apply -f rendered/05-key-vault-seeder-job.yaml
kubectl wait --for=condition=complete job/sentinel-key-vault-seeder -n sentinel-app --timeout=300s
kubectl logs job/sentinel-key-vault-seeder -n sentinel-app
```

Clean up temporary data:

```powershell
kubectl delete secret sentinel-seed-values -n sentinel-app
kubectl delete job sentinel-key-vault-seeder -n sentinel-app --ignore-not-found
```

Then remove the temporary `Key Vault Secrets Officer` role from `id-sentinel-app`. Keep only `Key Vault Secrets User`.

## 18. Bootstrap TLS Secret

The gateway needs an initial TLS secret before it can start. Use a temporary one-day self-signed certificate:

```powershell
openssl req -x509 -nodes -newkey rsa:2048 -days 1 `
  -keyout sentinel-bootstrap.key `
  -out sentinel-bootstrap.crt `
  -subj "/CN=<DOMAIN>" `
  -addext "subjectAltName=DNS:<DOMAIN>"

kubectl create secret tls sentinel-gateway-tls `
  --cert=sentinel-bootstrap.crt `
  --key=sentinel-bootstrap.key `
  --namespace sentinel-app `
  --dry-run=client -o yaml | kubectl apply -f -
```

## 19. Run Database Migration

```powershell
kubectl delete job sentinel-database-migration -n sentinel-app --ignore-not-found
kubectl apply -f rendered/04-database-migration-job.yaml
kubectl wait --for=condition=complete job/sentinel-database-migration -n sentinel-app --timeout=300s
kubectl logs job/sentinel-database-migration -n sentinel-app
```

Expected log lines:

```text
Context impl PostgresqlImpl.
Will assume transactional DDL.
```

## 20. Deploy Web, Identity, and Gateway

```powershell
kubectl apply -f rendered/10-web.yaml
kubectl apply -f rendered/11-identity-service.yaml
kubectl apply -f rendered/50-gateway-auth-only.yaml

kubectl rollout status deployment/web -n sentinel-app --timeout=300s
kubectl rollout status deployment/identity-service -n sentinel-app --timeout=300s
kubectl rollout status deployment/sentinel-gateway -n sentinel-app --timeout=300s

kubectl get pods,svc -n sentinel-app -o wide
```

Confirm that `service/sentinel-gateway` shows the gateway public IP.

## 21. Issue Trusted TLS Certificate

Confirm DNS first:

```powershell
Resolve-DnsName <DOMAIN>
```

It must resolve to the gateway public IP.

Run the certificate Job:

```powershell
kubectl delete job sentinel-tls-certificate -n sentinel-app --ignore-not-found
kubectl apply -f rendered/06-tls-certificate-job.yaml
```

Wait for the certificate file:

```powershell
$POD = kubectl get pod -n sentinel-app -l app.kubernetes.io/name=sentinel-tls-certificate -o jsonpath='{.items[0].metadata.name}'
kubectl logs -n sentinel-app $POD -f
```

When Certbot succeeds, copy the generated certificate from the pod:

```powershell
kubectl exec -n sentinel-app $POD -- cat /acme/letsencrypt/live/<DOMAIN>/fullchain.pem > fullchain.pem
kubectl exec -n sentinel-app $POD -- cat /acme/letsencrypt/live/<DOMAIN>/privkey.pem > privkey.pem
```

Update the TLS secret:

```powershell
kubectl create secret tls sentinel-gateway-tls `
  -n sentinel-app `
  --cert=fullchain.pem `
  --key=privkey.pem `
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment/sentinel-gateway -n sentinel-app
kubectl rollout restart deployment/identity-service -n sentinel-app
kubectl rollout status deployment/sentinel-gateway -n sentinel-app --timeout=300s
kubectl rollout status deployment/identity-service -n sentinel-app --timeout=300s
kubectl delete job sentinel-tls-certificate -n sentinel-app --ignore-not-found
```

The Let's Encrypt certificate is valid for 90 days. Renew before expiry by rerunning this section.

## 22. Verify

```powershell
curl.exe https://<DOMAIN>/
curl.exe https://<DOMAIN>/api/v1/auth/health/live
curl.exe https://<DOMAIN>/api/v1/auth/health/ready
```

Expected:

- Web returns `200 OK`.
- Identity health returns `{"status":"ok"}`.
- Browser opens `https://<DOMAIN>`.
- Microsoft login redirects back to `https://<DOMAIN>/auth/callback`.

Check login URL:

```powershell
curl.exe "https://<DOMAIN>/auth/login?tenant_id=<TENANT_ID>"
```

The response should contain:

```text
redirect_uri=https%3A%2F%2F<DOMAIN>%2Fauth%2Fcallback
```

## 23. Troubleshooting

### Browser shows HSTS/certificate error

Check the certificate from outside the corporate network. Some corporate proxies, such as Zscaler, replace the site certificate. If the issuer shown in the browser is not Let's Encrypt, ask IT to bypass TLS inspection for `<DOMAIN>` or test from a mobile hotspot.

### Microsoft login says redirect URI mismatch

This means the Entra app registration does not have the exact callback URI the app is using.

Fix:

1. Open **Microsoft Entra ID** -> **App registrations** -> your app.
2. Go to **Authentication**.
3. Add:

   ```text
   https://<DOMAIN>/auth/callback
   ```

4. Save.
5. Confirm the Kubernetes ConfigMap has the same value:

   ```powershell
   kubectl get configmap sentinel-runtime-config -n sentinel-app -o yaml
   ```

6. Restart identity service:

   ```powershell
   kubectl rollout restart deployment/identity-service -n sentinel-app
   kubectl rollout status deployment/identity-service -n sentinel-app --timeout=300s
   ```

### Microsoft login button does nothing

Check that the frontend can reach the auth endpoint through the gateway:

```powershell
curl.exe "https://<DOMAIN>/auth/login?tenant_id=<TENANT_ID>"
```

The response should include an `authorization_url`. If it points to an old domain, rerender and reapply:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\render-manifests.ps1 `
  -EntraClientId "<ENTRA_CLIENT_ID>" `
  -Domain "<DOMAIN>" `
  -OutputDirectory ".\rendered"

kubectl apply -f rendered/00-auth-foundation.yaml
kubectl apply -f rendered/50-gateway-auth-only.yaml
kubectl rollout restart deployment/identity-service -n sentinel-app
kubectl rollout restart deployment/sentinel-gateway -n sentinel-app
```

### Pod stuck in ContainerCreating

Check Key Vault CSI mount errors:

```powershell
kubectl describe pod -n sentinel-app -l app.kubernetes.io/name=identity-service
kubectl get events -n sentinel-app --sort-by=.lastTimestamp
```

Common causes:

- Key Vault private DNS not linked to the AKS VNet.
- Missing federated credential for `system:serviceaccount:sentinel-app:identity-service`.
- Missing `Key Vault Secrets User` role on `id-sentinel-app`.

### Identity starts but crashes

Check logs:

```powershell
kubectl logs deployment/identity-service -n sentinel-app --previous --tail=150
```

For this image, keep these ConfigMap values as JSON strings:

```yaml
SENTINEL_ALLOWED_TENANTS: "[]"
SENTINEL_CORS_ORIGINS: '["https://<DOMAIN>"]'
```

### Database connection timeout

Confirm PostgreSQL firewall allows the AKS outbound public IP:

```powershell
az network public-ip show `
  --subscription "<SUBSCRIPTION_ID>" `
  --resource-group "<RESOURCE_GROUP>" `
  --name pip-sentinel-aks-outbound `
  --query ipAddress -o tsv
```

Add that exact IP to PostgreSQL firewall rules.

## 24. What This Minimal Setup Does Not Include

This guide intentionally excludes:

- Azure Front Door
- Application Gateway
- ACR
- Inventory/resource graph worker
- Audit, operations, relationship, and change intelligence services
- Production-grade HA node pools
- Private PostgreSQL subnet delegation
- Centralized monitoring and policy packs

Use this only for the minimal demo/login flow. For production, use the full architecture guide.
