output "frontdoor_endpoint" {
  value = azurerm_cdn_frontdoor_endpoint.endpoint.host_name
}
