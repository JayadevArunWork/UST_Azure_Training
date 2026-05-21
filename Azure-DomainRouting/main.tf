module "rg" {
  source   = "./modules/resource_group"
  rg_name  = var.rg_name
  location = var.location
}

module "vnet" {
  source                = "./modules/vnet"
  rg_name               = module.rg.name
  location              = module.rg.location
  vnet_name             = var.vnet_name
  vnet_address          = var.vnet_address
  appgw_subnet_name     = var.appgw_subnet_name
  appgw_subnet_prefix   = var.appgw_subnet_prefix
  vm_subnet_name        = var.vm_subnet_name
  vm_subnet_prefix      = var.vm_subnet_prefix
  bastion_subnet_prefix = var.bastion_subnet_prefix
  depends_on            = [module.rg]
}

module "nsg" {
  source    = "./modules/nsg"
  rg_name   = module.rg.name
  location  = module.rg.location
  nsg_name  = var.nsg_name
  subnet_id = module.vnet.vm_subnet_id
  depends_on = [module.vnet]
}

module "nat_gateway" {
  source      = "./modules/nat_gateway"
  rg_name     = module.rg.name
  location    = module.rg.location
  nat_gw_name = var.nat_gw_name
  subnet_id   = module.vnet.vm_subnet_id
  depends_on  = [module.vnet]
}

# Organic App VM
module "organic_vm" {
  source         = "./modules/vm"
  rg_name        = module.rg.name
  location       = module.rg.location
  vm_name        = "organic-app-vm"
  vm_size        = var.vm_size
  admin_username = var.admin_username
  admin_password = var.admin_password
  subnet_id      = module.vnet.vm_subnet_id
  nsg_id         = module.nsg.nsg_id
  zone           = "1"
  custom_data    = "organic_app.sh"
  depends_on     = [module.nsg, module.nat_gateway]
}

# Fitness App VM
module "fitness_vm" {
  source         = "./modules/vm"
  rg_name        = module.rg.name
  location       = module.rg.location
  vm_name        = "fitness-app-vm"
  vm_size        = var.vm_size
  admin_username = var.admin_username
  admin_password = var.admin_password
  subnet_id      = module.vnet.vm_subnet_id
  nsg_id         = module.nsg.nsg_id
  zone           = "2"
  custom_data    = "fitness_app.sh"
  depends_on     = [module.nsg, module.nat_gateway]
}

# Application Gateway with WAF
module "app_gateway" {
  source          = "./modules/app_gateway"
  rg_name         = module.rg.name
  location        = module.rg.location
  appgw_name      = var.appgw_name
  subnet_id       = module.vnet.appgw_subnet_id
  organic_vm_ip   = module.organic_vm.private_ip
  fitness_vm_ip   = module.fitness_vm.private_ip
  organic_domain  = var.organic_domain
  fitness_domain  = var.fitness_domain
  depends_on      = [module.organic_vm, module.fitness_vm]
}