locals {
  common_tags = {
    Project     = "CareNest"
    ManagedBy   = "Terraform"
    Environment = var.environment
    Owner       = var.owner
    Location    = var.location
  }
}

module "resource_group" {
  source       = "./modules/resource_group"
  project_name = var.project_name
  location     = var.location
  tags         = local.common_tags
}

module "networking" {
  source              = "./modules/networking"
  project_name        = var.project_name
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = local.common_tags
}

module "acr" {
  source              = "./modules/acr"
  project_name        = var.project_name
  location            = var.location
  resource_group_name = module.resource_group.name
  sku                 = var.acr_sku
  tags                = local.common_tags
}

module "keyvault" {
  source              = "./modules/keyvault"
  project_name        = var.project_name
  location            = var.location
  resource_group_name = module.resource_group.name
  pe_subnet_id        = module.networking.pe_subnet_id
  tags                = local.common_tags
}

module "monitoring" {
  source              = "./modules/monitoring"
  project_name        = var.project_name
  location            = var.location
  resource_group_name = module.resource_group.name
  ops_email           = var.ops_email
  aks_cluster_id      = module.aks.cluster_id
  appgw_id            = module.application_gateway.appgw_id
  tags                = local.common_tags
}

module "aks" {
  source                     = "./modules/aks"
  project_name               = var.project_name
  location                   = var.location
  resource_group_name        = module.resource_group.name
  kubernetes_version         = var.kubernetes_version
  system_node_vm_size        = var.system_node_vm_size
  app_node_vm_size           = var.app_node_vm_size
  app_node_min_count         = var.app_node_min_count
  app_node_max_count         = var.app_node_max_count
  aks_subnet_id              = module.networking.aks_subnet_id
  acr_id                     = module.acr.id
  keyvault_id                = module.keyvault.keyvault_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  monitor_workspace_id       = module.monitoring.monitor_workspace_id
  tags                       = local.common_tags
}

module "cosmosdb" {
  source              = "./modules/cosmosdb"
  project_name        = var.project_name
  location            = var.location
  resource_group_name = module.resource_group.name
  throughput          = var.cosmos_throughput
  keyvault_id         = module.keyvault.keyvault_id
  tags                = local.common_tags
}

module "blob_storage" {
  source              = "./modules/blob_storage"
  project_name        = var.project_name
  location            = var.location
  resource_group_name = module.resource_group.name
  pe_subnet_id        = module.networking.pe_subnet_id
  keyvault_id         = module.keyvault.keyvault_id
  tags                = local.common_tags
}

module "servicebus" {
  source              = "./modules/servicebus"
  project_name        = var.project_name
  location            = var.location
  resource_group_name = module.resource_group.name
  keyvault_id         = module.keyvault.keyvault_id
  tags                = local.common_tags
}

# module "ai_foundry" {
#   source              = "./modules/ai_foundry"
#   project_name        = var.project_name
#   location            = var.location
#   resource_group_name = module.resource_group.name
#   pe_subnet_id        = module.networking.pe_subnet_id
#   keyvault_id         = module.keyvault.keyvault_id
#   appinsights_id      = module.monitoring.appinsights_id
#   tags                = local.common_tags
# }

module "application_gateway" {
  source              = "./modules/application_gateway"
  project_name        = var.project_name
  location            = var.location
  resource_group_name = module.resource_group.name
  appgw_subnet_id     = module.networking.appgw_subnet_id
  tags                = local.common_tags
}

module "frontdoor" {
  source              = "./modules/frontdoor"
  project_name        = var.project_name
  location            = var.location
  resource_group_name = module.resource_group.name
  appgw_fqdn          = module.application_gateway.public_ip_fqdn
  tags                = local.common_tags
}