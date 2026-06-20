resource "azurerm_log_analytics_workspace" "law" {
  name                = "${var.project_name}-law"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_log_analytics_solution" "container_insights" {
  solution_name         = "ContainerInsights"
  location              = var.location
  resource_group_name   = var.resource_group_name
  workspace_resource_id = azurerm_log_analytics_workspace.law.id
  workspace_name        = azurerm_log_analytics_workspace.law.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/ContainerInsights"
  }
}

resource "azurerm_application_insights" "appinsights" {
  name                = "${var.project_name}-appinsights"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type    = "web"
  workspace_id        = azurerm_log_analytics_workspace.law.id
  tags                = var.tags
}

resource "azurerm_monitor_workspace" "amw" {
  name                = "${var.project_name}-monitor-workspace"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_monitor_action_group" "ag" {
  name                = "${var.project_name}-action-group"
  resource_group_name = var.resource_group_name
  short_name          = "carenestag"

  email_receiver {
    name          = "ops-team"
    email_address = var.ops_email
  }
}

resource "azurerm_monitor_metric_alert" "aks_cpu" {
  name                = "${var.project_name}-aks-cpu-high"
  resource_group_name = var.resource_group_name
  scopes              = [var.aks_cluster_id]
  description         = "Alert when AKS CPU is high"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_cpu_usage_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag.id
  }
}

resource "azurerm_monitor_metric_alert" "aks_mem" {
  name                = "${var.project_name}-aks-mem-high"
  resource_group_name = var.resource_group_name
  scopes              = [var.aks_cluster_id]
  description         = "Alert when AKS Memory is high"

  criteria {
    metric_namespace = "Microsoft.ContainerService/managedClusters"
    metric_name      = "node_memory_rss_percentage"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = 80
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag.id
  }
}

resource "azurerm_monitor_metric_alert" "appgw_5xx" {
  name                = "${var.project_name}-appgw-5xx"
  resource_group_name = var.resource_group_name
  scopes              = [var.appgw_id]
  description         = "Alert when App Gateway has 5xx errors"

  criteria {
    metric_namespace = "Microsoft.Network/applicationGateways"
    metric_name      = "FailedRequests"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 10
  }

  action {
    action_group_id = azurerm_monitor_action_group.ag.id
  }
}

resource "azurerm_monitor_alert_prometheus_rule_group" "prom_rules" {
  name                = "${var.project_name}-prom-rules"
  location            = var.location
  resource_group_name = var.resource_group_name
  cluster_name        = split("/", var.aks_cluster_id)[8]
  description         = "Prometheus alert rules for AKS"
  rule_group_enabled  = true
  interval            = "PT1M"
  scopes              = [azurerm_monitor_workspace.amw.id, var.aks_cluster_id]

  rule {
    enabled    = true
    record     = "node_cpu_high"
    expression = "100 - (avg by (instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100) > 80"
  }

  rule {
    enabled    = true
    record     = "node_mem_high"
    expression = "(node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 80"
  }

  rule {
    enabled    = true
    record     = "pod_restarts"
    expression = "rate(kube_pod_container_status_restarts_total[15m]) * 900 > 5"
  }

  rule {
    enabled    = true
    record     = "pod_pending"
    expression = "kube_pod_status_phase{phase=\"Pending\"} > 0"
  }
}

data "azurerm_client_config" "current" {}

resource "azurerm_monitor_data_collection_endpoint" "dce" {
  name                = "${var.project_name}-dce"
  resource_group_name = var.resource_group_name
  location            = var.location
  kind                = "Linux"
  tags                = var.tags
}

resource "azurerm_monitor_data_collection_rule" "dcr" {
  name                        = "${var.project_name}-dcr"
  resource_group_name         = var.resource_group_name
  location                    = var.location
  data_collection_endpoint_id = azurerm_monitor_data_collection_endpoint.dce.id
  kind                        = "Linux"
  tags                        = var.tags

  data_sources {
    prometheus_forwarder {
      name    = "PrometheusDataSource"
      streams = ["Microsoft-PrometheusMetrics"]
    }
  }

  destinations {
    monitor_account {
      monitor_account_id = azurerm_monitor_workspace.amw.id
      name               = "MonitoringAccount1"
    }
  }

  data_flow {
    streams      = ["Microsoft-PrometheusMetrics"]
    destinations = ["MonitoringAccount1"]
  }
}

resource "azurerm_monitor_data_collection_rule_association" "dcra" {
  name                    = "${var.project_name}-dcra"
  target_resource_id      = var.aks_cluster_id
  data_collection_rule_id = azurerm_monitor_data_collection_rule.dcr.id
  description             = "Association of DCR to AKS Cluster"
}

resource "azurerm_resource_group_template_deployment" "grafana" {
  name                = "${var.project_name}-grafana-deployment"
  resource_group_name = var.resource_group_name
  deployment_mode     = "Incremental"

  template_content = <<TEMPLATE
{
  "$schema": "https://schema.management.azure.com/schemas/2019-04-01/deploymentTemplate.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "grafanaName": { "type": "string" },
    "location": { "type": "string" },
    "amwId": { "type": "string" }
  },
  "resources": [
    {
      "type": "Microsoft.Dashboard/grafana",
      "apiVersion": "2023-09-01",
      "name": "[parameters('grafanaName')]",
      "location": "[parameters('location')]",
      "sku": {
        "name": "Standard"
      },
      "identity": {
        "type": "SystemAssigned"
      },
      "properties": {
        "grafanaMajorVersion": "12",
        "publicNetworkAccess": "Enabled",
        "grafanaIntegrations": {
          "azureMonitorWorkspaceIntegrations": [
            {
              "azureMonitorWorkspaceResourceId": "[parameters('amwId')]"
            }
          ]
        }
      }
    }
  ],
  "outputs": {
    "endpoint": {
      "type": "string",
      "value": "[reference(resourceId('Microsoft.Dashboard/grafana', parameters('grafanaName')), '2023-09-01').endpoint]"
    },
    "principalId": {
      "type": "string",
      "value": "[reference(resourceId('Microsoft.Dashboard/grafana', parameters('grafanaName')), '2023-09-01', 'Full').identity.principalId]"
    }
  }
}
TEMPLATE

  parameters_content = jsonencode({
    "grafanaName" = { value = "${var.project_name}-grafana" }
    "location"    = { value = var.location }
    "amwId"       = { value = azurerm_monitor_workspace.amw.id }
  })
}

resource "azurerm_role_assignment" "grafana_monitor_reader" {
  scope                = azurerm_monitor_workspace.amw.id
  role_definition_name = "Monitoring Data Reader"
  principal_id         = jsondecode(azurerm_resource_group_template_deployment.grafana.output_content).principalId.value
}

data "azurerm_subscription" "primary" {}

resource "azurerm_role_assignment" "grafana_admin" {
  scope                = "${data.azurerm_subscription.primary.id}/resourceGroups/${var.resource_group_name}/providers/Microsoft.Dashboard/grafana/${var.project_name}-grafana"
  role_definition_name = "Grafana Admin"
  principal_id         = data.azurerm_client_config.current.object_id
  depends_on           = [azurerm_resource_group_template_deployment.grafana]
}