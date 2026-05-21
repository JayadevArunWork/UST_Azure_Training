resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  address_space       = var.vnet_address
  location            = var.location
  resource_group_name = var.rg_name
}

# App Gateway Subnet
resource "azurerm_subnet" "appgw" {
  name                 = var.appgw_subnet_name
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.appgw_subnet_prefix
}

# VM Subnet
resource "azurerm_subnet" "vm" {
  name                 = var.vm_subnet_name
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.vm_subnet_prefix
}

# Bastion Subnet - must be named exactly AzureBastionSubnet
resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.rg_name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = var.bastion_subnet_prefix
}