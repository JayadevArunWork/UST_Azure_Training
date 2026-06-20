output "storage_account_name" {
  value = azurerm_storage_account.sa.name
}

output "storage_account_id" {
  value = azurerm_storage_account.sa.id
}

output "primary_connection_string" {
  value     = azurerm_storage_account.sa.primary_connection_string
  sensitive = true
}