resource "azurerm_servicebus_namespace" "sb" {
  name                = "${var.project_name}-servicebus"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Standard"
  tags                = var.tags
}

locals {
  queues = [
    "appointment-created",
    "appointment-confirmed",
    "appointment-cancelled",
    "appointment-completed",
    "prescription-created",
    "notification-dispatch"
  ]
}

resource "azurerm_servicebus_queue" "queues" {
  for_each                             = toset(local.queues)
  name                                 = each.key
  namespace_id                         = azurerm_servicebus_namespace.sb.id
  enable_partitioning                 = true
  max_delivery_count                   = 10
  lock_duration                        = "PT30S"
  default_message_ttl                  = "P14D"
  dead_lettering_on_message_expiration = true
}

resource "azurerm_servicebus_topic" "notifications" {
  name                  = "notifications"
  namespace_id          = azurerm_servicebus_namespace.sb.id
  enable_partitioning  = true
  max_size_in_megabytes = 1024
}

resource "azurerm_servicebus_subscription" "patient_sub" {
  name               = "patient-sub"
  topic_id           = azurerm_servicebus_topic.notifications.id
  max_delivery_count = 5
}

resource "azurerm_servicebus_subscription" "doctor_sub" {
  name               = "doctor-sub"
  topic_id           = azurerm_servicebus_topic.notifications.id
  max_delivery_count = 5
}