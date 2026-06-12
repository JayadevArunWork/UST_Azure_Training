output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "storage_account_name" {
  value = azurerm_storage_account.storage.name
}

output "web_app_name" {
  value = azurerm_linux_web_app.webapp.name
}