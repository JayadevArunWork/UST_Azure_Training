# Sentinel Dev-Minimal Manifest Deployment Guide

Use this guide after the Azure resources have already been created through the Portal. It explains what deployers must change in the repo manifests and which commands must be run from Azure Cloud Shell to deploy the minimal login demo.

This guide deploys only:

- Web frontend
- Identity service
- Nginx gateway
- Database migration job
- Key Vault secret sync through CSI
- Let's Encrypt TLS for the deployer's own domain

It does not deploy inventory, audit, relationship, operations, change intelligence, workers, ACR, Front Door, Application Gateway, or App Service.

## 1. Images Used

Deployers do not need to build images. The manifests use these public images:

| Component | Image |
| --- | --- |
| Web | `elzabeth03/sentinel-web:v1.0.5` |
| Identity service | `elzabeth03/sentinel-identity-service:v1.0.3` |
| Migration | `elzabeth03/sentinel-migration:v1.0.3` |
| Gateway | `nginx:1.27-alpine` |
| Key Vault seeder | `mcr.microsoft.com/azure-cli:2.75.0` |
| TLS certificate job | `certbot/certbot:v5.6.0` |

The web image was originally built with a fixed API URL, so the gateway manifest rewrites that URL at runtime to the deployer's own domain.

## 2. Required Values

Collect these values before editing or applying manifests:

| Variable | Description |
| --- | --- |
| `<SUBSCRIPTION_ID>` | Azure subscription ID |
| `<TENANT_ID>` | Microsoft Entra tenant ID |
| `<RESOURCE_GROUP>` | Resource group containing AKS and gateway public IP |
| `<AKS_NAME>` | AKS cluster name |
| `<DOMAIN>` | Public app domain, for example `sentinel.example.com` |
| `<ENTRA_CLIENT_ID>` | App registration application/client ID |
| `<ENTRA_CLIENT_SECRET_VALUE>` | App registration client secret value |
| `<UAMI_CLIENT_ID>` | Client ID of `id-sentinel-app` user-assigned managed identity |
| `<KEY_VAULT_NAME>` | Key Vault name |
| `<GATEWAY_PUBLIC_IP_NAME>` | Reserved gateway public IP resource name |
| `<POSTGRES_SERVER_NAME>` | PostgreSQL Flexible Server name |
| `<POSTGRES_DATABASE>` | Database name, usually `sentinel` |
| `<POSTGRES_ADMIN_LOGIN>` | PostgreSQL administrator username |
| `<POSTGRES_ADMIN_PASSWORD>` | PostgreSQL administrator password |

The app registration must contain this redirect URI before login will work:

```text
https://<DOMAIN>/auth/callback
```

If it was missed, add it in the Azure Portal:

`Microsoft Entra ID -> App registrations -> your app -> Authentication -> Add URI -> https://<DOMAIN>/auth/callback -> Save`

## 3. Clone Repo and Set Context

Run in Azure Cloud Shell:

```bash
az account set --subscription "<SUBSCRIPTION_ID>"

git clone <YOUR_REPO_URL>
cd <YOUR_REPO_FOLDER>

az aks get-credentials \
  --resource-group "<RESOURCE_GROUP>" \
  --name "<AKS_NAME>" \
  --overwrite-existing

kubectl get nodes
```

Use the minimal manifests in:

```text
terraform/dev-minimal/kubernetes/
```

## 4. Create a Rendered Manifest Folder

The template files contain placeholders such as `REPLACE_ME_DOMAIN`. Do not edit the templates directly during a demo. Copy them into a rendered folder and replace placeholders there.

```bash
cd terraform/dev-minimal

rm -rf rendered
mkdir -p rendered
cp kubernetes/*.yaml rendered/
```

Set deployment variables:

```bash
export TENANT_ID="<TENANT_ID>"
export DOMAIN="<DOMAIN>"
export ENTRA_CLIENT_ID="<ENTRA_CLIENT_ID>"
export UAMI_CLIENT_ID="<UAMI_CLIENT_ID>"
export KEY_VAULT_NAME="<KEY_VAULT_NAME>"
export GATEWAY_PUBLIC_IP_NAME="<GATEWAY_PUBLIC_IP_NAME>"
export RESOURCE_GROUP="<RESOURCE_GROUP>"
```

Replace placeholders:

```bash
for file in rendered/*.yaml; do
  sed -i "s|REPLACE_ME_TENANT_ID|$TENANT_ID|g" "$file"
  sed -i "s|REPLACE_ME_DOMAIN|$DOMAIN|g" "$file"
  sed -i "s|REPLACE_ME_ENTRA_CLIENT_ID|$ENTRA_CLIENT_ID|g" "$file"
  sed -i "s|REPLACE_ME_UAMI_CLIENT_ID|$UAMI_CLIENT_ID|g" "$file"
  sed -i "s|REPLACE_ME_KEY_VAULT_NAME|$KEY_VAULT_NAME|g" "$file"
  sed -i "s|REPLACE_ME_GATEWAY_PUBLIC_IP_NAME|$GATEWAY_PUBLIC_IP_NAME|g" "$file"
  sed -i "s|REPLACE_ME_RESOURCE_GROUP|$RESOURCE_GROUP|g" "$file"
done
```

Check that no placeholders remain:

```bash
grep -R "REPLACE_ME_" rendered || true
```

Expected: no output.

## 5. What Changed in the Manifests

These are the important generated values:

### `rendered/00-auth-foundation.yaml`

Must contain:

```yaml
SENTINEL_ENTRA_AUDIENCE: <ENTRA_CLIENT_ID>
SENTINEL_MICROSOFT_CLIENT_ID: <ENTRA_CLIENT_ID>
SENTINEL_MICROSOFT_REDIRECT_URI: https://<DOMAIN>/auth/callback
SENTINEL_FRONTEND_URL: https://<DOMAIN>
SENTINEL_ALLOWED_TENANTS: "[]"
SENTINEL_CORS_ORIGINS: '["https://<DOMAIN>"]'
AZURE_TENANT_ID: <TENANT_ID>
```

Service accounts must contain:

```yaml
azure.workload.identity/client-id: <UAMI_CLIENT_ID>
```

The SecretProviderClass must contain:

```yaml
clientID: <UAMI_CLIENT_ID>
keyvaultName: <KEY_VAULT_NAME>
tenantId: <TENANT_ID>
```

### `rendered/50-gateway-auth-only.yaml`

The LoadBalancer service annotations must contain:

```yaml
service.beta.kubernetes.io/azure-pip-name: <GATEWAY_PUBLIC_IP_NAME>
service.beta.kubernetes.io/azure-load-balancer-resource-group: <RESOURCE_GROUP>
```

The runtime rewrite must contain:

```nginx
sub_filter 'https://sentinel.vaultrix.in' 'https://<DOMAIN>';
```

This is needed because the frontend image was built for the original domain, but the gateway rewrites it to the deployer's custom domain.

### Image tags

Check:

```bash
grep -R "image:" rendered
```

Expected important images:

```text
elzabeth03/sentinel-web:v1.0.5
elzabeth03/sentinel-identity-service:v1.0.3
elzabeth03/sentinel-migration:v1.0.3
nginx:1.27-alpine
mcr.microsoft.com/azure-cli:2.75.0
certbot/certbot:v5.6.0
```

## 6. Apply Foundation

```bash
kubectl apply -f rendered/00-auth-foundation.yaml
kubectl get namespace sentinel-app
kubectl get serviceaccount -n sentinel-app
kubectl get secretproviderclass -n sentinel-app
```

This creates:

- Namespace: `sentinel-app`
- ConfigMap: `sentinel-runtime-config`
- ServiceAccounts: `web`, `identity-service`
- SecretProviderClass: `identity-service-secrets`

## 7. Seed Key Vault from Inside AKS

If Key Vault public access is disabled, Cloud Shell cannot directly write secrets into Key Vault. Use the seeder job from AKS instead.

Before this step, temporarily assign this role in the Portal:

| Principal | Scope | Role |
| --- | --- | --- |
| `id-sentinel-app` | `<KEY_VAULT_NAME>` | `Key Vault Secrets Officer` |

Keep the permanent role:

| Principal | Scope | Role |
| --- | --- | --- |
| `id-sentinel-app` | `<KEY_VAULT_NAME>` | `Key Vault Secrets User` |

Build the PostgreSQL URL. The password must be URL encoded.

```bash
export POSTGRES_SERVER_NAME="<POSTGRES_SERVER_NAME>"
export POSTGRES_DATABASE="sentinel"
export POSTGRES_ADMIN_LOGIN="<POSTGRES_ADMIN_LOGIN>"
export POSTGRES_ADMIN_PASSWORD='<POSTGRES_ADMIN_PASSWORD>'

ENCODED_POSTGRES_PASSWORD="$(python3 -c 'import os, urllib.parse; print(urllib.parse.quote(os.environ["POSTGRES_ADMIN_PASSWORD"], safe=""))')"

DATABASE_URL="postgresql+asyncpg://${POSTGRES_ADMIN_LOGIN}:${ENCODED_POSTGRES_PASSWORD}@${POSTGRES_SERVER_NAME}.postgres.database.azure.com:5432/${POSTGRES_DATABASE}?ssl=require"
```

Generate runtime secrets:

```bash
INTERNAL_API_TOKEN="$(openssl rand -base64 32)"
SESSION_SIGNING_KEY="$(openssl rand -base64 32)"
TOKEN_ENCRYPTION_KEY="$(python3 -c 'import base64, os; print(base64.urlsafe_b64encode(os.urandom(32)).decode())')"
MICROSOFT_CLIENT_SECRET='<ENTRA_CLIENT_SECRET_VALUE>'
```

Create the temporary seed secret:

```bash
kubectl delete secret sentinel-seed-values -n sentinel-app --ignore-not-found

kubectl create secret generic sentinel-seed-values \
  -n sentinel-app \
  --from-literal=KEY_VAULT_NAME="$KEY_VAULT_NAME" \
  --from-literal=DATABASE_URL_B64="$(printf '%s' "$DATABASE_URL" | base64 -w0)" \
  --from-literal=INTERNAL_API_TOKEN_B64="$(printf '%s' "$INTERNAL_API_TOKEN" | base64 -w0)" \
  --from-literal=MICROSOFT_CLIENT_SECRET_B64="$(printf '%s' "$MICROSOFT_CLIENT_SECRET" | base64 -w0)" \
  --from-literal=SESSION_SIGNING_KEY_B64="$(printf '%s' "$SESSION_SIGNING_KEY" | base64 -w0)" \
  --from-literal=TOKEN_ENCRYPTION_KEY_B64="$(printf '%s' "$TOKEN_ENCRYPTION_KEY" | base64 -w0)"
```

Run the seeder:

```bash
kubectl delete job sentinel-key-vault-seeder -n sentinel-app --ignore-not-found
kubectl apply -f rendered/05-key-vault-seeder-job.yaml
kubectl wait --for=condition=complete job/sentinel-key-vault-seeder -n sentinel-app --timeout=300s
kubectl logs job/sentinel-key-vault-seeder -n sentinel-app
```

Expected output:

```text
Required Key Vault secrets were written.
```

Clean up:

```bash
kubectl delete secret sentinel-seed-values -n sentinel-app --ignore-not-found
kubectl delete job sentinel-key-vault-seeder -n sentinel-app --ignore-not-found
```

Then remove the temporary `Key Vault Secrets Officer` role from `id-sentinel-app` in the Portal. Keep `Key Vault Secrets User`.

## 8. Bootstrap Temporary TLS Secret

The gateway pod cannot start unless the Kubernetes TLS secret exists. Create a temporary self-signed certificate first. It will be replaced by Let's Encrypt later.

```bash
openssl req -x509 -nodes -newkey rsa:2048 -days 1 \
  -keyout sentinel-bootstrap.key \
  -out sentinel-bootstrap.crt \
  -subj "/CN=${DOMAIN}" \
  -addext "subjectAltName=DNS:${DOMAIN}"

kubectl create secret tls sentinel-gateway-tls \
  --cert=sentinel-bootstrap.crt \
  --key=sentinel-bootstrap.key \
  --namespace sentinel-app \
  --dry-run=client -o yaml | kubectl apply -f -

rm -f sentinel-bootstrap.key sentinel-bootstrap.crt
```

## 9. Run Database Migration

The migration job reads the database URL from the Kubernetes secret synchronized by the Key Vault CSI driver.

```bash
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

If the job stays in `ContainerCreating`, check Key Vault CSI errors:

```bash
kubectl describe pod -n sentinel-app -l app.kubernetes.io/name=sentinel-database-migration
kubectl get events -n sentinel-app --sort-by=.lastTimestamp | tail -40
```

## 10. Deploy Web, Identity, and Gateway

```bash
kubectl apply -f rendered/10-web.yaml
kubectl apply -f rendered/11-identity-service.yaml
kubectl apply -f rendered/50-gateway-auth-only.yaml

kubectl rollout status deployment/web -n sentinel-app --timeout=300s
kubectl rollout status deployment/identity-service -n sentinel-app --timeout=300s
kubectl rollout status deployment/sentinel-gateway -n sentinel-app --timeout=300s

kubectl get pods,svc -n sentinel-app -o wide
```

Confirm:

- `web` is `1/1 Running`
- `identity-service` is `1/1 Running`
- `sentinel-gateway` is `1/1 Running`
- `service/sentinel-gateway` has the gateway external IP

## 11. Create DNS A Record

In the DNS provider, create:

| Type | Name | Value |
| --- | --- | --- |
| `A` | host part of `<DOMAIN>` | gateway external IP |

Example:

| Domain | Host/name | Value |
| --- | --- | --- |
| `sentinel.example.com` | `sentinel` | gateway external IP |

Check:

```bash
nslookup "$DOMAIN"
```

The answer must be the gateway external IP before issuing TLS.

## 12. Issue Trusted TLS Certificate

The Certbot job uses HTTP-01 validation through the gateway. Port `80` must be reachable from the internet.

Run:

```bash
kubectl delete job sentinel-tls-certificate -n sentinel-app --ignore-not-found
kubectl apply -f rendered/06-tls-certificate-job.yaml
```

Watch logs:

```bash
POD="$(kubectl get pod -n sentinel-app -l app.kubernetes.io/name=sentinel-tls-certificate -o jsonpath='{.items[0].metadata.name}')"
kubectl logs -n sentinel-app "$POD" -f
```

When the certificate is ready, copy it out and replace the TLS secret:

```bash
kubectl exec -n sentinel-app "$POD" -- cat "/acme/letsencrypt/live/${DOMAIN}/fullchain.pem" > fullchain.pem
kubectl exec -n sentinel-app "$POD" -- cat "/acme/letsencrypt/live/${DOMAIN}/privkey.pem" > privkey.pem

kubectl create secret tls sentinel-gateway-tls \
  -n sentinel-app \
  --cert=fullchain.pem \
  --key=privkey.pem \
  --dry-run=client -o yaml | kubectl apply -f -

kubectl rollout restart deployment/sentinel-gateway -n sentinel-app
kubectl rollout restart deployment/identity-service -n sentinel-app
kubectl rollout status deployment/sentinel-gateway -n sentinel-app --timeout=300s
kubectl rollout status deployment/identity-service -n sentinel-app --timeout=300s

kubectl delete job sentinel-tls-certificate -n sentinel-app --ignore-not-found
rm -f fullchain.pem privkey.pem
```

The Let's Encrypt certificate is valid for 90 days. Rerun this section before expiry.

## 13. Verify the Application

```bash
curl -I "https://${DOMAIN}/"
curl "https://${DOMAIN}/api/v1/auth/health/live"
curl "https://${DOMAIN}/api/v1/auth/health/ready"
curl "https://${DOMAIN}/auth/login?tenant_id=${TENANT_ID}"
```

Expected:

- Web returns `HTTP/2 200` or `HTTP/1.1 200 OK`.
- Health endpoints return `{"status":"ok"}`.
- Login endpoint returns JSON containing `authorization_url`.
- The `authorization_url` includes:

```text
redirect_uri=https%3A%2F%2F<DOMAIN>%2Fauth%2Fcallback
```

Then open:

```text
https://<DOMAIN>
```

Select Microsoft login and complete the flow.

## 14. Common Fixes

### Login redirects to the wrong domain

Rerender and reapply:

```bash
sed -i "s|https://old-domain.example.com|https://${DOMAIN}|g" rendered/*.yaml
kubectl apply -f rendered/00-auth-foundation.yaml
kubectl apply -f rendered/50-gateway-auth-only.yaml
kubectl rollout restart deployment/identity-service -n sentinel-app
kubectl rollout restart deployment/sentinel-gateway -n sentinel-app
```

Also confirm the Entra app registration has:

```text
https://<DOMAIN>/auth/callback
```

### Identity pod cannot mount Key Vault secrets

Check:

```bash
kubectl describe pod -n sentinel-app -l app.kubernetes.io/name=identity-service
kubectl get events -n sentinel-app --sort-by=.lastTimestamp | tail -40
```

Common causes:

- `id-sentinel-app` missing `Key Vault Secrets User`.
- Federated credential subject does not match `system:serviceaccount:sentinel-app:identity-service`.
- Key Vault private DNS zone `privatelink.vaultcore.azure.net` is not linked to the AKS VNet.
- Key Vault secret names do not match the SecretProviderClass object names.

### Identity pod crashes on config parsing

For the current Docker image, these must be JSON strings:

```yaml
SENTINEL_ALLOWED_TENANTS: "[]"
SENTINEL_CORS_ORIGINS: '["https://<DOMAIN>"]'
```

### Browser shows HSTS or wrong certificate

Check the issuer:

```bash
echo | openssl s_client -connect "${DOMAIN}:443" -servername "$DOMAIN" 2>/dev/null | openssl x509 -noout -subject -issuer -dates -ext subjectAltName
```

Expected issuer is Let's Encrypt. If the browser shows a corporate issuer such as Zscaler, test from a mobile hotspot or ask IT to bypass TLS inspection for the domain.

## 15. Files Used

Minimal manifest templates:

```text
terraform/dev-minimal/kubernetes/00-auth-foundation.yaml
terraform/dev-minimal/kubernetes/04-database-migration-job.yaml
terraform/dev-minimal/kubernetes/05-key-vault-seeder-job.yaml
terraform/dev-minimal/kubernetes/06-tls-certificate-job.yaml
terraform/dev-minimal/kubernetes/10-web.yaml
terraform/dev-minimal/kubernetes/11-identity-service.yaml
terraform/dev-minimal/kubernetes/50-gateway-auth-only.yaml
```

Do not apply the full `deploy/kubernetes/` folder for this minimal login demo. That folder contains the broader microservice deployment.
