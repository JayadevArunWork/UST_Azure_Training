output "resource_group_name" {
  value = azurerm_resource_group.this.name
}

output "aks_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "aks_oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "aks_outbound_public_ip" {
  value = azurerm_public_ip.aks_outbound.ip_address
}

output "gateway_public_ip" {
  value = azurerm_public_ip.gateway.ip_address
}

output "gateway_public_ip_name" {
  value = azurerm_public_ip.gateway.name
}

output "gateway_fqdn" {
  value = azurerm_public_ip.gateway.fqdn
}

output "key_vault_name" {
  value = azurerm_key_vault.this.name
}

output "key_vault_id" {
  value = azurerm_key_vault.this.id
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.this.fqdn
}

output "postgres_database_name" {
  value = azurerm_postgresql_flexible_server_database.sentinel.name
}

output "sentinel_app_identity_client_id" {
  value = azurerm_user_assigned_identity.sentinel_app.client_id
}

output "verified_docker_images" {
  value = {
    web       = "elzabeth03/sentinel-web:v1.0.5"
    identity  = "elzabeth03/sentinel-identity-service:v1.0.3"
    migration = "elzabeth03/sentinel-migration:v1.0.3"
    gateway   = "nginx:1.27-alpine"
  }
}

output "database_url_template" {
  value = "postgresql+asyncpg://${var.postgres_admin_login}:<URL_ENCODED_PASSWORD>@${azurerm_postgresql_flexible_server.this.fqdn}:5432/sentinel?ssl=require"
}
