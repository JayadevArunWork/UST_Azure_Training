resource "azurerm_public_ip" "appgw_ip" {
  name                = "${var.appgw_name}-ip"
  location            = var.location
  resource_group_name = var.rg_name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# WAF Policy
resource "azurerm_web_application_firewall_policy" "this" {
  name                = "${var.appgw_name}-waf-policy"
  resource_group_name = var.rg_name
  location            = var.location

  managed_rules {
    managed_rule_set {
      type    = "OWASP"
      version = "3.2"
    }
  }

  policy_settings {
    enabled                     = true
    mode                        = "Detection"
    request_body_check          = true
    file_upload_limit_in_mb     = 100
    max_request_body_size_in_kb = 128
  }
}

resource "azurerm_application_gateway" "this" {
  name                = var.appgw_name
  resource_group_name = var.rg_name
  location            = var.location
  firewall_policy_id  = azurerm_web_application_firewall_policy.this.id

  sku {
    name = "WAF_v2"
    tier = "WAF_v2"
  }

  autoscale_configuration {
    min_capacity = 1
    max_capacity = 2
  }

  gateway_ip_configuration {
    name      = "appgw-ip-config"
    subnet_id = var.subnet_id
  }

  # Frontend
  frontend_ip_configuration {
    name                 = "appgw-frontend-ip"
    public_ip_address_id = azurerm_public_ip.appgw_ip.id
  }

  frontend_port {
    name = "http-port"
    port = 80
  }

  # Backend Pools
  backend_address_pool {
    name         = "organic-backend-pool"
    ip_addresses = [var.organic_vm_ip]
  }

  backend_address_pool {
    name         = "fitness-backend-pool"
    ip_addresses = [var.fitness_vm_ip]
  }

  # Backend HTTP Settings
  backend_http_settings {
    name                  = "organic-http-setting"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  backend_http_settings {
    name                  = "fitness-http-setting"
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 30
  }

  # Listener for Organic App
  http_listener {
    name                           = "organic-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
    host_name                      = var.organic_domain
  }

  # Listener for Fitness App
  http_listener {
    name                           = "fitness-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
    host_name                      = var.fitness_domain
  }

  # Default Listener
  http_listener {
    name                           = "default-listener"
    frontend_ip_configuration_name = "appgw-frontend-ip"
    frontend_port_name             = "http-port"
    protocol                       = "Http"
  }

  # Routing Rule - Organic
  request_routing_rule {
    name                       = "organic-routing-rule"
    priority                   = 100
    rule_type                  = "Basic"
    http_listener_name         = "organic-listener"
    backend_address_pool_name  = "organic-backend-pool"
    backend_http_settings_name = "organic-http-setting"
  }

  # Routing Rule - Fitness
  request_routing_rule {
    name                       = "fitness-routing-rule"
    priority                   = 200
    rule_type                  = "Basic"
    http_listener_name         = "fitness-listener"
    backend_address_pool_name  = "fitness-backend-pool"
    backend_http_settings_name = "fitness-http-setting"
  }

  # Routing Rule - Default
  request_routing_rule {
    name                       = "default-routing-rule"
    priority                   = 300
    rule_type                  = "Basic"
    http_listener_name         = "default-listener"
    backend_address_pool_name  = "organic-backend-pool"
    backend_http_settings_name = "organic-http-setting"
  }
}