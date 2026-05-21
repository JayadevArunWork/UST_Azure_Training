output "vnet_id" {
  value = azurerm_virtual_network.this.id
}

output "appgw_subnet_id" {
  value = azurerm_subnet.appgw.id
}

output "vm_subnet_id" {
  value = azurerm_subnet.vm.id
}

output "bastion_subnet_id" {
  value = azurerm_subnet.bastion.id
}