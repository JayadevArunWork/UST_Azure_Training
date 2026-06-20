output "public_ip_fqdn" {
  value = azurerm_public_ip.appgw_pip.fqdn
}

output "public_ip_address" {
  value = azurerm_public_ip.appgw_pip.ip_address
}

output "appgw_id" {
  value = azurerm_application_gateway.appgw.id
}
