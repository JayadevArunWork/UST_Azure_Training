# Resource Group
module "rg" {
  source   = "./modules/resource_group"
  name     = var.resource_group_name
  location = var.location
}

# Virtual Network + Subnet
module "vnet" {
  source              = "./modules/vnet"
  resource_group_name = module.rg.name
  location            = module.rg.location
  vnet_name           = var.vnet_name
  address_space       = var.vnet_address_space
  subnet_name         = var.subnet_name
  subnet_prefix       = var.subnet_prefix
  depends_on          = [module.rg]
}

# NSG - Opens Port 80, 443, 22
module "nsg" {
  source              = "./modules/nsg"
  resource_group_name = module.rg.name
  location            = module.rg.location
  nsg_name            = var.nsg_name
  subnet_id           = module.vnet.subnet_id
  depends_on          = [module.vnet]
}

# NAT Gateway - Allows VMs to reach internet for apt-get
module "nat_gateway" {
  source              = "./modules/nat_gateway"
  resource_group_name = module.rg.name
  location            = module.rg.location
  nat_gw_name         = var.nat_gw_name
  subnet_id           = module.vnet.subnet_id
  depends_on          = [module.vnet]
}

# Load Balancer
module "lb" {
  source              = "./modules/load_balancer"
  resource_group_name = module.rg.name
  location            = module.rg.location
  lb_name             = var.lb_name
  depends_on          = [module.rg]
}

# VM Scale Set
module "vmss" {
  source              = "./modules/vmss"
  resource_group_name = module.rg.name
  location            = module.rg.location
  vmss_name           = var.vmss_name
  vmss_sku            = var.vmss_sku
  vmss_instances      = var.vmss_instances
  admin_username      = var.vmss_admin_username
  admin_password      = var.vmss_admin_password
  subnet_id           = module.vnet.subnet_id
  lb_backend_pool_id  = module.lb.backend_pool_id
  nsg_id              = module.nsg.nsg_id
  depends_on          = [module.lb, module.nsg, module.nat_gateway]
}

# Autoscale Rules
module "autoscale" {
  source              = "./modules/autoscale"
  resource_group_name = module.rg.name
  location            = module.rg.location
  vmss_id             = module.vmss.vmss_id
  vmss_name           = var.vmss_name
  autoscale_min       = var.autoscale_min
  autoscale_max       = var.autoscale_max
  scale_out_cpu       = var.scale_out_cpu
  scale_in_cpu        = var.scale_in_cpu
  depends_on          = [module.vmss]
}

# Service Bus - Topic + Subscription
module "service_bus" {
  source              = "./modules/service_bus"
  resource_group_name = module.rg.name
  location            = module.rg.location
  namespace_name      = var.servicebus_name
  topic_name          = var.topic_name
  subscription_name   = var.subscription_name
  depends_on          = [module.rg]
}

# Logic App
module "logic_app" {
  source              = "./modules/logic_app"
  resource_group_name = module.rg.name
  location            = module.rg.location
  logic_app_name      = var.logic_app_name
  sb_connection_string = module.service_bus.connection_string
  topic_name          = var.topic_name
  depends_on          = [module.service_bus]
}

# Azure Monitor Alerts
module "monitor" {
  source              = "./modules/monitor"
  resource_group_name = module.rg.name
  vmss_id             = module.vmss.vmss_id
  alert_email         = var.alert_email
  logic_app_id        = module.logic_app.logic_app_id
  logic_app_url       = module.logic_app.trigger_url
  depends_on          = [module.vmss, module.logic_app]
}