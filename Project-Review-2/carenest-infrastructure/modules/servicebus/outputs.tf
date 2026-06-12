output "namespace_name" {
  value = azurerm_servicebus_namespace.sb.name
}

output "namespace_id" {
  value = azurerm_servicebus_namespace.sb.id
}

output "primary_connection_string" {
  value     = azurerm_servicebus_namespace.sb.default_primary_connection_string
  sensitive = true
}