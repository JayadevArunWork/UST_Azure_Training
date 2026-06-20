output "account_name" {
  value = azurerm_cosmosdb_account.cosmos.name
}

output "account_id" {
  value = azurerm_cosmosdb_account.cosmos.id
}

output "primary_connection_string" {
  value     = azurerm_cosmosdb_account.cosmos.primary_mongodb_connection_string
  sensitive = true
}