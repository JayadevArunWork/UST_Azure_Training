output "log_analytics_workspace_id" {
  value = azurerm_log_analytics_workspace.law.id
}

output "appinsights_id" {
  value = azurerm_application_insights.appinsights.id
}

output "monitor_workspace_id" {
  value = azurerm_monitor_workspace.amw.id
}

output "action_group_id" {
  value = azurerm_monitor_action_group.ag.id
}

output "grafana_endpoint" {
  value = jsondecode(azurerm_resource_group_template_deployment.grafana.output_content).endpoint.value
}