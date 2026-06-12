locals {
  tags = merge({
    application         = "sentinel"
    environment         = "dev-minimal"
    managed_by          = "terraform"
    owner               = var.owner
    data_classification = "confidential"
  }, var.additional_tags)

  vnet_name             = "vnet-sentinel"
  aks_name              = "aks-sentinel"
  key_vault_name        = "kvsentinel${var.name_suffix}"
  postgres_server_name  = "psql-sentinel-${var.name_suffix}"
  gateway_pip_name      = "pip-sentinel-gateway"
  aks_outbound_pip_name = "pip-sentinel-aks-outbound"
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = local.vnet_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.20.0.0/16"]
  tags                = local.tags
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks"
  resource_group_name  = azurerm_resource_group.this.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = ["10.20.1.0/24"]
}

resource "azurerm_subnet" "private_endpoints" {
  name                              = "snet-private-endpoints"
  resource_group_name               = azurerm_resource_group.this.name
  virtual_network_name              = azurerm_virtual_network.this.name
  address_prefixes                  = ["10.20.2.0/24"]
  private_endpoint_network_policies = "Disabled"
}

resource "azurerm_private_dns_zone" "key_vault" {
  name                = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "key_vault" {
  name                  = "key-vault-vnet-link"
  resource_group_name   = azurerm_resource_group.this.name
  private_dns_zone_name = azurerm_private_dns_zone.key_vault.name
  virtual_network_id    = azurerm_virtual_network.this.id
  registration_enabled  = false
  tags                  = local.tags
}

resource "azurerm_public_ip" "aks_outbound" {
  name                = local.aks_outbound_pip_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  tags                = local.tags
}

resource "azurerm_public_ip" "gateway" {
  name                = local.gateway_pip_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  sku                 = "Standard"
  domain_name_label   = "sentinel-${var.name_suffix}"
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "aks_control_plane" {
  name                = "id-sentinel-aks-control"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_role_assignment" "aks_control_plane_network" {
  scope                = azurerm_subnet.aks.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_control_plane.principal_id
}

resource "azurerm_role_assignment" "aks_control_plane_outbound_ip" {
  scope                = azurerm_public_ip.aks_outbound.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_control_plane.principal_id
}

resource "azurerm_role_assignment" "aks_control_plane_gateway_ip" {
  scope                = azurerm_public_ip.gateway.id
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_user_assigned_identity.aks_control_plane.principal_id
}

resource "azurerm_user_assigned_identity" "sentinel_app" {
  name                = "id-sentinel-app"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags
}

resource "azurerm_kubernetes_cluster" "this" {
  name                = local.aks_name
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  node_resource_group = "${var.resource_group_name}-aks-nodes"
  dns_prefix          = local.aks_name

  role_based_access_control_enabled = true
  local_account_disabled            = false
  oidc_issuer_enabled               = true
  workload_identity_enabled         = true
  sku_tier                          = "Free"

  default_node_pool {
    name                 = "system"
    vm_size              = var.aks_node_vm_size
    node_count           = 1
    auto_scaling_enabled = false
    vnet_subnet_id       = azurerm_subnet.aks.id
    os_disk_type         = "Managed"
    os_disk_size_gb      = 64
    type                 = "VirtualMachineScaleSets"

    upgrade_settings {
      max_surge = "33%"
    }

    node_labels = {
      "sentinel.vaultrix.in/pool" = "combined"
    }
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [azurerm_user_assigned_identity.aks_control_plane.id]
  }

  dynamic "api_server_access_profile" {
    for_each = length(var.aks_api_authorized_ip_ranges) == 0 ? [] : [1]

    content {
      authorized_ip_ranges = var.aks_api_authorized_ip_ranges
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    load_balancer_sku   = "standard"
    outbound_type       = "loadBalancer"
    service_cidr        = "10.21.0.0/16"
    dns_service_ip      = "10.21.0.10"
    pod_cidr            = "10.244.0.0/16"

    load_balancer_profile {
      outbound_ip_address_ids = [azurerm_public_ip.aks_outbound.id]
    }
  }

  key_vault_secrets_provider {
    secret_rotation_enabled  = true
    secret_rotation_interval = "2m"
  }

  tags = local.tags

  depends_on = [
    azurerm_role_assignment.aks_control_plane_network,
    azurerm_role_assignment.aks_control_plane_outbound_ip,
    azurerm_role_assignment.aks_control_plane_gateway_ip,
  ]
}

resource "azurerm_federated_identity_credential" "web" {
  name                      = "fc-web"
  user_assigned_identity_id = azurerm_user_assigned_identity.sentinel_app.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject                   = "system:serviceaccount:sentinel-app:web"
}

resource "azurerm_federated_identity_credential" "identity" {
  name                      = "fc-identity-service"
  user_assigned_identity_id = azurerm_user_assigned_identity.sentinel_app.id
  audience                  = ["api://AzureADTokenExchange"]
  issuer                    = azurerm_kubernetes_cluster.this.oidc_issuer_url
  subject                   = "system:serviceaccount:sentinel-app:identity-service"
}

resource "azurerm_key_vault" "this" {
  name                          = local.key_vault_name
  location                      = azurerm_resource_group.this.location
  resource_group_name           = azurerm_resource_group.this.name
  tenant_id                     = var.tenant_id
  sku_name                      = "standard"
  rbac_authorization_enabled    = true
  public_network_access_enabled = false
  purge_protection_enabled      = false
  soft_delete_retention_days    = 7

  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
  }

  tags = local.tags
}

resource "azurerm_private_endpoint" "key_vault" {
  name                = "pe-kv-sentinel"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  subnet_id           = azurerm_subnet.private_endpoints.id
  tags                = local.tags

  private_service_connection {
    name                           = "psc-kv-sentinel"
    private_connection_resource_id = azurerm_key_vault.this.id
    subresource_names              = ["vault"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "default"
    private_dns_zone_ids = [azurerm_private_dns_zone.key_vault.id]
  }
}

resource "azurerm_role_assignment" "key_vault_secrets" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = azurerm_user_assigned_identity.sentinel_app.principal_id
}

resource "azurerm_postgresql_flexible_server" "this" {
  name                          = local.postgres_server_name
  resource_group_name           = azurerm_resource_group.this.name
  location                      = azurerm_resource_group.this.location
  version                       = "16"
  public_network_access_enabled = true
  administrator_login           = var.postgres_admin_login
  administrator_password        = var.postgres_admin_password
  storage_mb                    = 32768
  sku_name                      = var.postgres_sku_name
  backup_retention_days         = 7
  geo_redundant_backup_enabled  = false
  tags                          = local.tags
}

resource "azurerm_postgresql_flexible_server_database" "sentinel" {
  name      = "sentinel"
  server_id = azurerm_postgresql_flexible_server.this.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

resource "azurerm_postgresql_flexible_server_configuration" "extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.this.id
  value     = "PGCRYPTO"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "aks_outbound" {
  name             = "aks-outbound"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = azurerm_public_ip.aks_outbound.ip_address
  end_ip_address   = azurerm_public_ip.aks_outbound.ip_address
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "operator" {
  count = var.operator_postgres_ip == null ? 0 : 1

  name             = "operator"
  server_id        = azurerm_postgresql_flexible_server.this.id
  start_ip_address = var.operator_postgres_ip
  end_ip_address   = var.operator_postgres_ip
}
