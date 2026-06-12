param(
    [Parameter(Mandatory = $true)]
    [string]$EntraClientId,

    [string]$Domain = "sentinel.vaultrix.in",

    [string]$OutputDirectory = (Join-Path $PSScriptRoot "rendered")
)

$ErrorActionPreference = "Stop"

$terraformOutput = terraform -chdir="$PSScriptRoot" output -json | ConvertFrom-Json
$replacements = @{
    "REPLACE_ME_ENTRA_CLIENT_ID"       = $EntraClientId
    "REPLACE_ME_DOMAIN"                = $Domain
    "REPLACE_ME_TENANT_ID"             = "83474cb5-f1fa-4d06-906c-e5dad12ce3b9"
    "REPLACE_ME_UAMI_CLIENT_ID"         = $terraformOutput.sentinel_app_identity_client_id.value
    "REPLACE_ME_KEY_VAULT_NAME"         = $terraformOutput.key_vault_name.value
    "REPLACE_ME_GATEWAY_PUBLIC_IP_NAME" = $terraformOutput.gateway_public_ip_name.value
    "REPLACE_ME_RESOURCE_GROUP"         = $terraformOutput.resource_group_name.value
}

New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null

Get-ChildItem (Join-Path $PSScriptRoot "kubernetes") -Filter "*.yaml" | ForEach-Object {
    $content = Get-Content $_.FullName -Raw
    foreach ($item in $replacements.GetEnumerator()) {
        $content = $content.Replace($item.Key, [string]$item.Value)
    }
    Set-Content -Path (Join-Path $OutputDirectory $_.Name) -Value $content -Encoding utf8
}

Write-Output "Rendered manifests to $OutputDirectory"
