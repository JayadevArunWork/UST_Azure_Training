############################
# Resource Group
############################
 
resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}
 
############################
# Storage Account
############################
 
resource "azurerm_storage_account" "storage" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
 
  account_tier             = "Standard"
  account_replication_type = "GRS"
 
  tags = {
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
}
 
############################
# Wait for Storage Account
############################
 
resource "time_sleep" "wait_for_storage" {
  depends_on = [
    azurerm_storage_account.storage
  ]
 
  create_duration = "60s"
}
 
############################
# App Service Plan
############################
 
resource "azurerm_service_plan" "plan" {
  name                = var.app_service_plan_name
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
 
  os_type  = "Linux"
  sku_name = "B1"
 
  tags = {
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
 
  depends_on = [
    time_sleep.wait_for_storage
  ]
}
 
############################
# Wait for App Service Plan
############################
 
resource "time_sleep" "wait_for_plan" {
  depends_on = [
    azurerm_service_plan.plan
  ]
 
  create_duration = "90s"
}
 
############################
# Linux Web App
############################
 
resource "azurerm_linux_web_app" "webapp" {
  name                = var.app_service_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
 
  service_plan_id = azurerm_service_plan.plan.id
 
  https_only = true
 
  site_config {
    always_on = false
 
    application_stack {
      node_version = "18-lts"
    }
  }
 
  tags = {
    Environment = "Dev"
    ManagedBy   = "Terraform"
  }
 
  depends_on = [
    time_sleep.wait_for_plan
  ]
}
