resource "azurerm_storage_account" "ai_sa" {
    name                     = replace("${var.project_name}aisa", "-", "")
    resource_group_name      = var.resource_group_name
    location                 = var.location
    account_tier             = "Standard"
    account_replication_type = "LRS"
    min_tls_version          = "TLS1_2"
    tags                     = var.tags
}

resource "azurerm_machine_learning_workspace" "hub" {
    name                    = "${var.project_name}-ai-hub"
    location                = var.location
    resource_group_name     = var.resource_group_name
    storage_account_id      = azurerm_storage_account.ai_sa.id
    key_vault_id            = var.keyvault_id
    application_insights_id = var.appinsights_id
    kind                    = "Default"
    identity {
        type = "SystemAssigned"
    }
    tags = var.tags
}

resource "azurerm_cognitive_account" "openai" {
    name                  = "${var.project_name}-openai"
    location              = "eastus"
    resource_group_name   = var.resource_group_name
    kind                  = "OpenAI"
    sku_name              = "S0"
    custom_subdomain_name = replace("${var.project_name}ai", "-", "")

    network_acls {
        default_action = "Allow"
    }
    tags = var.tags
}

resource "azurerm_cognitive_account" "language" {
    name                = "${var.project_name}-language"
    location            = var.location
    resource_group_name = var.resource_group_name
    kind                = "TextAnalytics"
    sku_name            = "S"
    tags                = var.tags
}

resource "azurerm_cognitive_deployment" "gpt4o" {
  name                 = "gpt-4o"
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = "gpt-4o"
    version = "2024-11-20"
  }
  scale {
    type     = "GlobalStandard"
    capacity = 10
  }
}

resource "azurerm_cognitive_deployment" "gpt4omini_prescription" {
  name                 = "gpt-4o-mini-prescription"
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
    version = "2024-07-18"
  }
  scale {
    type     = "GlobalStandard"
    capacity = 10
  }
}

resource "azurerm_cognitive_deployment" "gpt4omini_chatbot" {
  name                 = "gpt-4o-mini-chatbot"
  cognitive_account_id = azurerm_cognitive_account.openai.id
  model {
    format  = "OpenAI"
    name    = "gpt-4o-mini"
    version = "2024-07-18"
  }
  scale {
    type     = "GlobalStandard"
    capacity = 10
  }
}