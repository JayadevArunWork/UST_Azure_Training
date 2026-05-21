location = "Central India"
rg_name  = "domain-routing-rg"

# Network
vnet_name             = "domain-routing-vnet"
vnet_address          = ["10.0.0.0/16"]
appgw_subnet_name     = "appgateway-subnet"
appgw_subnet_prefix   = ["10.0.1.0/24"]
vm_subnet_name        = "vm-subnet"
vm_subnet_prefix      = ["10.0.2.0/24"]
bastion_subnet_prefix = ["10.0.3.0/24"]
nsg_name              = "domain-routing-nsg"
nat_gw_name           = "domain-nat-gw"

# VMs
vm_size        = "Standard_F2s_v2"
admin_username = "jayadevazure"
admin_password = "JDkittu#2003AZ"

# Domains
organic_domain = "organic.project-carenest.online"
fitness_domain = "fitness.project-carenest.online"

# App Gateway
appgw_name = "domain-appgw"