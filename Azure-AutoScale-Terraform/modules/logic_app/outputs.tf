output "logic_app_id" {
  value = azurerm_logic_app_workflow.this.id
}

output "trigger_url" {
  value     = azurerm_logic_app_trigger_http_request.this.callback_url
  sensitive = true
}