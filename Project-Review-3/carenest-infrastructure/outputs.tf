output "resource_group_name" {
  value = module.resource_group.name
}

output "aks_cluster_name" {
  value = module.aks.cluster_name
}

output "aks_get_credentials_command" {
  value = "az aks get-credentials --resource-group ${module.resource_group.name} --name ${module.aks.cluster_name} --overwrite-existing"
}

output "acr_login_server" {
  value = module.acr.login_server
}

output "frontdoor_endpoint" {
  value = module.frontdoor.frontdoor_endpoint
}

output "cosmosdb_account_name" {
  value = module.cosmosdb.account_name
}

output "keyvault_name" {
  value = module.keyvault.keyvault_name
}

output "ai_foundry_openai_endpoint" {
  value = module.ai_foundry.openai_endpoint
}

output "servicebus_namespace_name" {
  value = module.servicebus.namespace_name
}

output "grafana_endpoint" {
  value = module.monitoring.grafana_endpoint
}

