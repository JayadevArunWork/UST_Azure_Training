resource "azurerm_logic_app_workflow" "this" {
  name                = var.logic_app_name
  location            = var.location
  resource_group_name = var.resource_group_name
}

# HTTP Trigger - receives alert webhook
resource "azurerm_logic_app_trigger_http_request" "this" {
  name         = "alert-trigger"
  logic_app_id = azurerm_logic_app_workflow.this.id

  schema = <<SCHEMA
{
  "type": "object",
  "properties": {
    "schemaId": { "type": "string" },
    "data": {
      "type": "object",
      "properties": {
        "essentials": {
          "type": "object",
          "properties": {
            "alertRule": { "type": "string" },
            "severity": { "type": "string" },
            "description": { "type": "string" },
            "firedDateTime": { "type": "string" }
          }
        }
      }
    }
  }
}
SCHEMA
}

# Service Bus API Connection
data "azurerm_client_config" "current" {}

resource "azurerm_api_connection" "servicebus" {
  name                = "servicebus-connection"
  resource_group_name = var.resource_group_name
  managed_api_id      = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Web/locations/${var.location}/managedApis/servicebus"
  display_name        = "ServiceBusConnection"

  parameter_values = {
    connectionString = var.sb_connection_string
  }
}

# Send message to Service Bus topic
resource "azurerm_logic_app_action_custom" "send_sb_message" {
  name         = "Send-To-ServiceBus"
  logic_app_id = azurerm_logic_app_workflow.this.id

  body = <<BODY
{
  "type": "ApiConnection",
  "inputs": {
    "host": {
      "connection": {
        "name": "@parameters('$connections')['servicebus']['connectionId']"
      }
    },
    "method": "post",
    "body": {
      "ContentData": "@{base64(concat('Alert: ', triggerBody()?['data']?['essentials']?['alertRule'], ' | Severity: ', triggerBody()?['data']?['essentials']?['severity'], ' | Time: ', triggerBody()?['data']?['essentials']?['firedDateTime']))}"
    },
    "path": "/@{encodeURIComponent(encodeURIComponent('${var.topic_name}'))}/messages"
  },
  "runAfter": {}
}
BODY

  depends_on = [azurerm_logic_app_trigger_http_request.this]
}