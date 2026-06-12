output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "aks_subnet_id" {
  value = azurerm_subnet.aks.id
}

output "appgw_subnet_id" {
  value = azurerm_subnet.appgw.id
}

output "db_subnet_id" {
  value = azurerm_subnet.db.id
}

output "pe_subnet_id" {
  value = azurerm_subnet.pe.id
}
