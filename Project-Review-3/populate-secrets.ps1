$ErrorActionPreference = "Stop"
$rg = "jd-carenest-new-rg"
$kv = "jd-carenest-new-kv"

Write-Host "Getting cosmos connection string..."
$cosmos = az cosmosdb keys list --type connection-strings --name jd-carenest-new-cosmos --resource-group $rg --query "connectionStrings[0].connectionString" -o tsv
az keyvault secret set --vault-name $kv --name "cosmos-connection-string" --value $cosmos

Write-Host "Getting storage connection string..."
$storage = az storage account show-connection-string --name jdcarenestnewsa --resource-group $rg --query "connectionString" -o tsv
az keyvault secret set --vault-name $kv --name "storage-connection-string" --value $storage

Write-Host "Getting servicebus connection string..."
$sb = az servicebus namespace authorization-rule keys list --resource-group $rg --namespace-name jd-carenest-new-servicebus --name RootManageSharedAccessKey --query "primaryConnectionString" -o tsv
az keyvault secret set --vault-name $kv --name "servicebus-connection-string" --value $sb

Write-Host "Getting openai info..."
$openaiKey = az cognitiveservices account keys list --name jd-carenest-new-openai --resource-group $rg --query "key1" -o tsv
$openaiEndpoint = az cognitiveservices account show --name jd-carenest-new-openai --resource-group $rg --query "properties.endpoint" -o tsv
az keyvault secret set --vault-name $kv --name "openai-api-key" --value $openaiKey
az keyvault secret set --vault-name $kv --name "openai-endpoint" --value $openaiEndpoint

Write-Host "Getting language info..."
$langKey = az cognitiveservices account keys list --name jd-carenest-new-language --resource-group $rg --query "key1" -o tsv
$langEndpoint = az cognitiveservices account show --name jd-carenest-new-language --resource-group $rg --query "properties.endpoint" -o tsv
az keyvault secret set --vault-name $kv --name "language-api-key" --value $langKey
az keyvault secret set --vault-name $kv --name "language-endpoint" --value $langEndpoint

Write-Host "Setting JWT..."
az keyvault secret set --vault-name $kv --name "jwt-secret" --value "supersecretjwtkey123"
az keyvault secret set --vault-name $kv --name "jwt-expires-in" --value "7d"

Write-Host "All secrets populated!"
