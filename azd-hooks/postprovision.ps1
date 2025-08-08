param()

# Fail on any error
$ErrorActionPreference = 'Stop'

# Fetch value to determine if workflow should deploy Azure Container Apps
$deployApps = azd env get-value DEPLOY_AZURE_CONTAINERAPPS

# Deploys Frontend and Backend apps if the variable is set to "true"
if ($deployApps -eq 'true') {
    Write-Output "Deploying apps..."
    azd deploy
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
else {
    Write-Output "Skipping application deployment as DEPLOY_AZURE_CONTAINERAPPS is set to 'false'."

    # Fetch environment variables
    $serverName                 = azd env get-value POSTGRES_NAME
    $dbHost                     = azd env get-value POSTGRES_HOST
    $dbUser                     = azd env get-value POSTGRES_USERNAME
    $dbPassword                 = azd env get-value POSTGRES_PASSWORD
    $dbName                     = azd env get-value POSTGRES_DATABASE
    $llmApiKey                  = azd env get-value AZURE_OPENAI_KEY
    $llmEndpoint                = azd env get-value AZURE_OPENAI_ENDPOINT
    $llmApiversion              = azd env get-value AZURE_OPENAI_API_VERSION
    $embedApiVersion            = azd env get-value AZURE_OPENAI_API_VERSION_EMBED
    $arizeDBUrl                 = azd env get-value ARIZE_SQL_URI

    Write-Output "Creating Azure PostgreSQL extensions..."
    # Create extensions
    az postgres flexible-server execute `
        --name "$serverName" `
        --database-name "$dbName" `
        --admin-user "$dbUser" `
        --admin-password "$dbPassword" `
        --file-path "$PSScriptRoot/../scripts/create-extension.sql"

    # Create .env file with the fetched environment variables
    @"
DB_HOST=$dbHost
DB_USER=$dbUser
DB_PASSWORD=$dbPassword
DB_NAME=$dbName
AZURE_API_VERSION_LLM=$llmApiversion
AZURE_API_VERSION_EMBEDDING_MODEL=$embedApiVersion
AZURE_OPENAI_API_KEY=$llmApiKey
AZURE_OPENAI_ENDPOINT=$llmEndpoint
PHOENIX_SQL_DATABASE_URL=$arizeDBUrl
"@ | Out-File -FilePath .env -Encoding utf8

}
