resource "azurerm_servicebus_namespace" "this" {
  name                = var.namespace_name
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  local_auth_enabled  = true
}

resource "azurerm_servicebus_topic" "this" {
  name                = var.topic_name
  namespace_id        = azurerm_servicebus_namespace.this.id
  enable_partitioning = true
}

resource "azurerm_servicebus_subscription" "this" {
  name               = var.subscription_name
  topic_id           = azurerm_servicebus_topic.this.id
  max_delivery_count = 10
  dead_lettering_on_message_expiration = true
}