output "namespace_id" {
  value = azurerm_servicebus_namespace.this.id
}

output "connection_string" {
  value     = azurerm_servicebus_namespace.this.default_primary_connection_string
  sensitive = true
}