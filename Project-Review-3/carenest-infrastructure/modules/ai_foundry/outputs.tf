output "openai_endpoint" {
    value = azurerm_cognitive_account.openai.endpoint
}

output "openai_id" {
    value = azurerm_cognitive_account.openai.id
}

output "language_endpoint" {
    value = azurerm_cognitive_account.language.endpoint
}

output "ai_hub_id" {
    value = azurerm_machine_learning_workspace.hub.id
}