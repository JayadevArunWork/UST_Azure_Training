resource "azurerm_kubernetes_cluster" "aks" {
  name                      = "${var.project_name}-aks"
  location                  = var.location
  resource_group_name       = var.resource_group_name
  dns_prefix                = "${var.project_name}-aks"
  kubernetes_version        = var.kubernetes_version
  sku_tier                  = "Standard"
  #automatic_channel_upgrade = "patch"
  oidc_issuer_enabled       = true
  tags                      = var.tags

  default_node_pool {
    name                         = "system"
    vm_size                      = var.system_node_vm_size
    node_count                   = 2
    os_disk_size_gb              = 100
    vnet_subnet_id               = var.aks_subnet_id
    only_critical_addons_enabled = true
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin    = "azure"
    network_policy    = "calico"
    dns_service_ip    = "10.0.0.10"
    service_cidr      = "10.0.0.0/16"
    load_balancer_sku = "standard"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  azure_policy_enabled = true

  monitor_metrics {
    annotations_allowed = "*"
    labels_allowed      = "*"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "apppool" {
  name                  = "apppool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.app_node_vm_size
  auto_scaling_enabled  = true
  min_count             = var.app_node_min_count
  max_count             = var.app_node_max_count
  os_disk_size_gb       = 128
  vnet_subnet_id        = var.aks_subnet_id
  tags                  = var.tags
}