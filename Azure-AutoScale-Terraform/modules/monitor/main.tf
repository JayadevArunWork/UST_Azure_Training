resource "azurerm_monitor_action_group" "this" {
  name                = "ghee-action-group"
  resource_group_name = var.resource_group_name
  short_name          = "GheeAlerts"
  enabled             = true

  email_receiver {
    name                    = "EmailAlert"
    email_address           = var.alert_email
    use_common_alert_schema = true
  }

  logic_app_receiver {
    name                    = "LogicAppAlert"
    resource_id             = var.logic_app_id
    callback_url            = var.logic_app_url
    use_common_alert_schema = true
  }
}

# High CPU Alert
resource "azurerm_monitor_metric_alert" "cpu_alert" {
  name                = "High-CPU-Alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.vmss_id]
  description         = "CPU exceeded 70 percent"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 70
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}

# High Network Alert
resource "azurerm_monitor_metric_alert" "network_alert" {
  name                = "High-Network-Alert"
  resource_group_name = var.resource_group_name
  scopes              = [var.vmss_id]
  description         = "High network traffic detected"
  severity            = 2
  frequency           = "PT1M"
  window_size         = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachineScaleSets"
    metric_name      = "Network In Total"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 104857600
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}