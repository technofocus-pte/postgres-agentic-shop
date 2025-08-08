targetScope = 'resourceGroup'

@minLength(1)
@maxLength(64)
@description('Name which is used for each resource')
param name string

@minLength(1)
@description('Primary location for all resources')
@allowed([
  'australiacentral'
  'australiacentral2'
  'australiaeast'
  'australiasoutheast'
  'austriaeast'
  'brazilsouth'
  'canadacentral'
  'canadaeast'
  'centralindia'
  'centralus'
  'chilecentral'
  'eastasia'
  'eastus'
  'eastus2'
  'francecentral'
  'germanywestcentral'
  'indonesiacentral'
  'israelcentral'
  'italynorth'
  'japaneast'
  'japanwest'
  'koreacentral'
  'koreasouth'
  'malaysiawest'
  'mexicocentral'
  'newzealandnorth'
  'northcentralus'
  'northeurope'
  'norwayeast'
  'polandcentral'
  'qatarcentral'
  'southafricanorth'
  'southcentralus'
  'southeastasia'
  'southindia'
  'spaincentral'
  'swedencentral'
  'switzerlandnorth'
  'uaenorth'
  'uksouth'
  'ukwest'
  'westcentralus'
  'westeurope'
  'westindia'
  'westus'
  'westus2'
  'westus3'
])
@metadata({
  azd: {
    type: 'location'
  }
})
param location string

@description('Name of the user to add in PostgreSQL server as administrator')
param principalName string = ''

@minLength(1)
@description('Location for the OpenAI resource supporting Global Standard Deployment type')
// Look for desired models on the availability table:
// https://learn.microsoft.com/azure/ai-services/openai/concepts/models#global-standard-model-availability
@allowed([
  'australiaeast'
  'brazilsouth'
  'canadaeast'
  'eastus'
  'eastus2'
  'francecentral'
  'germanywestcentral'
  'italynorth'
  'japaneast'
  'koreacentral'
  'northcentralus'
  'norwayeast'
  'polandcentral'
  'spaincentral'
  'southafricanorth'
  'southcentralus'
  'southindia'
  'swedencentral'
  'switzerlandnorth'
  'uaenorth'
  'uksouth'
  'westeurope'
  'westus'
  'westus3'
])
@metadata({
  azd: {
    type: 'location'
    usageName : [
      'OpenAI.GlobalStandard.gpt-4o, 50'
      'OpenAI.GlobalStandard.text-embedding-3-small, 70'
    ]
  }
})
param openAILocation string

@description('Whether to deploy Azure OpenAI resources')
param deployAzureOpenAI bool = true

@description('Version of the Azure OpenAI API to use for chat models')
// Check supported versions here
// https://learn.microsoft.com/azure/ai-services/openai/concepts/models#global-standard-model-availability
param azureOpenAIAPIVersion string = '2024-10-21'

@description('Version of the Azure OpenAI API to use for embedding models')
// Check supported version here
// https://learn.microsoft.com/azure/ai-services/openai/concepts/models#global-standard-model-availability
param azureEmbedAIAPIVersion string = '2024-10-21'

// Chat completion model
@description('Name of the chat model to deploy')
param chatModelName string                                // Set in main.parameters.json

@description('Name of the model deployment')
param chatDeploymentName string                           // Set in main.parameters.json

@description('Version of the chat model to deploy')
// See version availability in this table:
// https://learn.microsoft.com/azure/ai-services/openai/concepts/models#global-standard-model-availability
// Leave empty to use latest available version
param chatDeploymentVersion string = ''                   // Set in main.parameters.json

@description('Sku of the chat deployment')
param chatDeploymentSku string                            // Set in main.parameters.json

@description('Capacity of the chat deployment')
// You can increase this, but capacity is limited per model/region, check the following for limits
// https://learn.microsoft.com/en-us/azure/ai-services/openai/quotas-limits
param chatDeploymentCapacity int                          // Set in main.parameters.json

// Embedding model
@description('Name of the embedding model to deploy')
param embedModelName string                               // Set in main.parameters.json

@description('Name of the embedding model deployment')
param embedDeploymentName string                          // Set in main.parameters.json

@description('Version of the embedding model to deploy')
// See version availability in this table:
// https://learn.microsoft.com/azure/ai-services/openai/concepts/models#embeddings-models
// Leave empty to use latest available version
param embedDeploymentVersion string = ''                  // Set in main.parameters.json

@description('Sku of the embeddings model deployment')
param embedDeploymentSku string                           // Set in main.parameters.json

@description('Capacity of the embedding deployment')
// You can increase this, but capacity is limited per model/region, so you will get errors if you go over
// https://learn.microsoft.com/en-us/azure/ai-services/openai/quotas-limits
param embedDeploymentCapacity int                         // Set in main.parameters.json

@description('Username for the PostgreSQL server')
param administratorLoginUser string                       // Set in main.parameters.json

@secure()
@description('Password for the PostgreSQL server')
param administratorLoginPassword string                   // Set in main.parameters.json

@description('Unique string creation')
var resourceToken = toLower(uniqueString(subscription().id, name, location))

@description('Prefix to be used for all resources')
var prefix = '${toLower(name)}-${resourceToken}'

@description('Tags to be applied to all resources')
var tags = { 'azd-env-name': name }

@description('Whether deploy container Apps module or not')
param deployContainerApps bool

@description('Name of content filter policy to be created for OpenAI')
param contentFilterPolicyName string = 'rai-policy'

@description('Name of the frontend app')
var frontendAppName = 'rt-frontend'

@description('Name of the identity attached to frontend app')
var frontAppIdentityName = 'id-rt-frontend'

@description('Name of the backend app')
var backendAppName = 'rt-backend'

@description('Name of the identity attached to backend app')
var backendAppIdentityName = 'id-rt-backend'

@description('Name of the identity attached to backend app')
var arizeAppIdentityName = 'id-arize'

@description('Name of PostgreSQL server')
var postgresServerName = '${prefix}-postgresql'

@description('Name of the Backend app database')
var backendappDatabaseName = 'agentic_shop'

@description('Name of the Arize Phoenix app database')
var arizeDatabaseName = 'arize_db'

@description('Name of PostgreSQL server')
var postgresServerPort = '5432'

@description('Storage parameters of PostgreSQL Flexible server')
param postgresServerStorage object = {
  autoGrow: 'Disabled'
  iops: '3000'
  storageSizeGB: '32'
  throughput: '125'
  tier: 'P20'
  type: 'PremiumV2_LRS'
}

@description('Sku of PostgreSQL Flexible server')
param postgresServerSku object = {
  name: 'Standard_D2ds_v4'
  tier: 'GeneralPurpose'
}

@description('PostgreSQL version for Flexible server')
param postgresVersion string = '16'

@allowed([
  'Password'
  'EntraPassword'
])
param postgresServerAuthType string = 'Password'

@description('Arize Phoenix Database URL to connect with')
var arizeSQLUrl = 'postgresql://${administratorLoginUser}:${administratorLoginPassword}@${postgresServer.outputs.POSTGRES_DOMAIN_NAME}:${postgresServerPort}/${arizeDatabaseName}'

@description('Flags to control additional port mapping')
param addPortsFE bool = false
param addPortsBE bool = false
param addPortsArize bool = true

@description('Additional port mapping for Azure Container Apps')
param feExPort int = 0
param feTgPort int = 0

param arizeExPort int = 4317
param arizeTgPort int = 4317

param beExPort int = 0
param beTgPort int = 0

// Module for Flexible server PostgreSQL
module postgresServer 'core/database/flexibleserver.bicep' = {
  name: 'postgresql'
  params: {
    name: postgresServerName
    location: location
    // certain regions do not support zones
    // before speciying zone, please check https://learn.microsoft.com/en-us/azure/reliability/availability-zones-region-support
    zone: ''
    tags: tags
    sku: postgresServerSku
    storage: postgresServerStorage
    version: postgresVersion
    authType: postgresServerAuthType
    administratorLogin: administratorLoginUser
    administratorLoginPassword: administratorLoginPassword
    databaseNames: [
      backendappDatabaseName
      arizeDatabaseName
    ]
    allowAzureIPsFirewall: true
    allowAllIPsFirewall: true       // Necessary for post-provision script, can be disabled after
  }
}

// Module for PostgreSQL access through Entra ID when local development environment is setup
module postgresqlAdmin 'core/database/flexibleserver_adminaccess.bicep' = if (!deployContainerApps  && postgresServerAuthType == 'EntraPassword') {
  name: 'postgresqlAdminUser'
  params: {
    postgresqlServerName: postgresServer.outputs.serverName
    principalId: deployer().objectId
    principalName: principalName
  }
}

// Container apps environment and container registry
module containerApps 'core/host/container-apps-env-registry.bicep' = if (deployContainerApps) {
  name: 'container-apps'
  params: {
    name: 'app'
    location: location
    containerAppsEnvironmentName: '${prefix}-containerapps-env'
    containerRegistryName: '${replace(prefix, '-', '')}registry'
  }
}

//keyvautl module
module keyVault 'core/keyvault/keyvault.bicep' = if (deployContainerApps) {
  name: 'keyVault'
  params: {
    location: location
    keyVaultName: '${take(replace(prefix, '-', ''), 15)}keyvault'
    postgresUsername: administratorLoginUser
    postgresPassword: administratorLoginPassword
    postgresDatabase: backendappDatabaseName
    postgresHost: postgresServer.outputs.POSTGRES_DOMAIN_NAME
    postgresPort: postgresServerPort
    arizeSQLUrl: arizeSQLUrl
    openAIendpoint: openAI.outputs.modelInfos[0].endpoint
    openAIkey: openAI.outputs.modelInfos[0].key
  }
  dependsOn: [ postgresServer, openAI ]
}

// Frontend app module
module frontend 'app/frontend.bicep' = if (deployContainerApps) {
  name: 'frontend'
  params: {
    name: frontendAppName
    location: location
    tags: tags
    identityName: frontAppIdentityName
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerApps.outputs.registryName
    // params to add 1 additional port if required in future, not required by for this service
    addPorts: addPortsFE
    addexposedport: feExPort
    addtargetport: feTgPort
    environmentVariables: frontendEnv
    secrets: []
  }
}

// Backend app module
module backend 'app/backend.bicep' = if (deployContainerApps) {
  name: 'backend'
  params: {
    name: backendAppName
    location: location
    tags: tags
    identityName: backendAppIdentityName
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerApps.outputs.registryName
    // params to add 1 additional port if required in future, not required by for this service
    addPorts: addPortsBE
    addexposedport: beExPort
    addtargetport: beTgPort
    environmentVariables: backendEnv
    secrets: backendSecrets
  }
  dependsOn: [ checkSecrets ]
}

// Arize Phoenix module
module arize 'core/arize-phoenix/arize.bicep' = if (deployContainerApps) {
  name: 'arize'
  params: {
    name: 'arize'
    location: location
    tags: tags
    identityName: arizeAppIdentityName
    containerAppsEnvironmentName: containerApps.outputs.environmentName
    containerRegistryName: containerApps.outputs.registryName
    // params to add 1 additional port, required by for this service
    addPorts: addPortsArize
    addexposedport: arizeExPort
    addtargetport: arizeTgPort
    environmentVariables: arizeEnv
    secrets: arizeSecrets
  }
  dependsOn: [ checkSecrets ]
}

// Create backend app identity
@description('Name of the Backend app identity')
resource webIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (deployContainerApps) {
  name: backendAppIdentityName
  location: location
}

// Attach key vault access policy to the Backend app identity
@description('Key vault role assignment for the Backend app identity')
resource keyvrole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployContainerApps) {
  name: guid(webIdentity.id, resourceGroup().id, '4633458b-17de-408a-b874-0445c86b69e6')
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: webIdentity.properties.principalId
  }
}

// Create Arize app identity
@description('Name of the Arize app identity')
resource arizewebIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = if (deployContainerApps) {
  name: arizeAppIdentityName
  location: location
}

// Attach key vault access policy to the Arize app identity
@description('Key vault role assignment for the Arize app identity')
resource arizekeyvrole 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (deployContainerApps) {
  name: guid(arizewebIdentity.id, resourceGroup().id, '4633458b-17de-408a-b874-0445c86b69e6')
  properties: {
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: arizewebIdentity.properties.principalId
  }
}

// Check if all required secrets exist in the Key Vault
@description('Check if all required secrets exist in the Key Vault')
resource checkSecrets 'Microsoft.Resources/deploymentScripts@2023-08-01' = if (deployContainerApps) {
  name: 'checkSecrets'
  location: location
  identity: {
      type: 'UserAssigned'
      userAssignedIdentities: {
        '${webIdentity.id}': {}
      }
    }
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.70.0' // Ensure the Azure CLI version supports Key Vault commands
    scriptContent: '''
      #!/bin/bash
      set -e
      # Variables
      KEYVAULT_NAME="${KEYVAULT_NAME}"
      SECRETS=("postgres-host" "postgres-username" "postgres-database" "postgres-password" "postgres-port" "azure-openai-endpoint" "azure-openai-key")

      # Check each secret
      for SECRET in "${SECRETS[@]}"; do
        echo -e "\nChecking if secret $SECRET exists in Key Vault $KEYVAULT_NAME..."
        az keyvault secret show --vault-name "$KEYVAULT_NAME" --name "$SECRET" > /dev/null 2>&1
        if [ $? -ne 0 ]; then
          echo -e "\nSecret $SECRET does not exist in Key Vault $KEYVAULT_NAME."
          exit 1
        fi
      done

      echo "All secrets exist in Key Vault $KEYVAULT_NAME."
    '''
    arguments: '--KEYVAULT_NAME ${take(replace(prefix, '-', ''), 15)}keyvault'
    forceUpdateTag: uniqueString(resourceGroup().id)
    retentionInterval: 'PT1H' // Retain the script container for 1 hour
    timeout: 'PT5M'
    environmentVariables: [
      {
        name: 'KEYVAULT_NAME'
        value: '${take(replace(prefix, '-', ''), 15)}keyvault'
      }
    ]
  }
  dependsOn: [
    keyVault
  ]
}

@description('Secrets for the Arize Phoenix app')
var arizeSecrets = {
  keyVaultReferences: [
    {
      name: 'phoenix-sql-database-url'
      keyVaultUrl: '${keyVault.outputs.keyVaultUri}secrets/phoenix-sql-database-url'
    }
  ]
}

@description('Secrets for the Backend app')
var backendSecrets = {
  keyVaultReferences: [
    {
      name: 'postgres-host'
      keyVaultUrl: '${keyVault.outputs.keyVaultUri}secrets/postgres-host'
    }
    {
      name: 'postgres-username'
      keyVaultUrl: '${keyVault.outputs.keyVaultUri}secrets/postgres-username'
    }
    {
      name: 'postgres-database'
      keyVaultUrl: '${keyVault.outputs.keyVaultUri}secrets/postgres-database'
    }
    {
      name: 'postgres-password'
      keyVaultUrl: '${keyVault.outputs.keyVaultUri}secrets/postgres-password'
    }
    {
      name: 'postgres-port'
      keyVaultUrl: '${keyVault.outputs.keyVaultUri}secrets/postgres-port'
    }
    {
      name: 'azure-openai-endpoint'
      keyVaultUrl: '${keyVault.outputs.keyVaultUri}secrets/azure-openai-endpoint'
    }
    {
      name: 'azure-openai-key'
      keyVaultUrl: '${keyVault.outputs.keyVaultUri}secrets/azure-openai-key'
    }
  ]
}

@description('Environment variables for the Backend app')
var backendEnv = [
  {
    name: 'DB_HOST'
    secretRef: 'postgres-host'
  }
  {
    name: 'DB_USER'
    secretRef: 'postgres-username'
  }
  {
    name: 'DB_NAME'
    secretRef: 'postgres-database'
  }
  {
    name: 'DB_PORT'
    secretRef: 'postgres-port'
  }
  {
    name: 'DB_PASSWORD'
    secretRef: 'postgres-password'
  }
  {
    name: 'APP_VERSION'
    value: '0.1.0'
  }
  {
    name: 'ENVIRONMENT'
    value: 'prod'
  }
  {
    name: 'DB_EMBEDDING_TABLE_FOR_PRODUCTS'
    value: 'embeddings_products'
  }
  {
    name: 'DB_EMBEDDING_TABLE_FOR_REVIEWS'
    value: 'embeddings_reviews'
  }
  {
    name: 'LLM_MODEL'
    value: chatModelName
  }
  {
    name: 'EMBEDDING_MODEL'
    value: deployAzureOpenAI ? embedModelName : ''
  }
  {
    name: 'AZURE_API_VERSION_LLM'
    value: deployAzureOpenAI ? azureOpenAIAPIVersion : ''
  }
  {
    name: 'AZURE_API_VERSION_EMBEDDING_MODEL'
    value: deployAzureOpenAI ? azureEmbedAIAPIVersion : ''
  }
  {
    name: 'AZURE_OPENAI_API_KEY'
    secretRef: 'azure-openai-key'
  }
  {
    name: 'AZURE_OPENAI_ENDPOINT'
    secretRef: 'azure-openai-endpoint'
  }
  {
    name: 'MEM0_LLM_PROVIDER'
    value: 'azure_openai'
  }
  {
    name: 'MEM0_MEMORY_PROVIDER'
    value: 'pgvector'
  }
  {
    name: 'MEM0_MEMORY_TABLE_NAME'
    value: 'mem0_chatstore'
  }
  {
    name: 'PHOENIX_COLLECTOR_ENDPOINT'
    value: '${arize.outputs.SERVICE_WEB_URI}/v1/traces'
  }
  {
    name: 'PHOENIX_CLIENT_ENDPOINT'
    value: arize.outputs.SERVICE_WEB_URI
  }
  {
    name: 'PHOENIX_PROJECT_NAME'
    value: 'Agentic Shop'
  }
  {
    name: 'SQLALCHEMY_CONNECTION_POOL_SIZE'
    value: '20'
  }
]

@description('Environment variables for the Arize Phoenix app')
var arizeEnv = [
  {
    name: 'PHOENIX_SQL_DATABASE_URL'
    secretRef: 'phoenix-sql-database-url'
  }
]

@description('Environment variables for the Frontend app')
var frontendEnv = [
  {
    name: 'VITE_BE_APP_ENDPOINT'
    value: backend.outputs.SERVICE_WEB_URI
  }
]

@description('Params for the OpenAI deployments')
var modelDeployments = [
  {
  name: chatDeploymentName
  model: union({
    format: 'OpenAI'
    name: chatModelName
  }, empty(chatDeploymentVersion) ? {} : { version: chatDeploymentVersion })
  sku: {
    name: chatDeploymentSku
    capacity: chatDeploymentCapacity
  }
}
{
  name: embedDeploymentName
  model: union({
    format: 'OpenAI'
    name: embedModelName
  }, empty(embedDeploymentVersion) ? {} : { version: embedDeploymentVersion })
  sku: {
    name: embedDeploymentSku
    capacity: embedDeploymentCapacity
  }
}]

// OpenAI module
module openAI 'core/ai/cognitiveservices.bicep' = if (deployAzureOpenAI) {
  name: 'openai'
  params: {
    name: '${prefix}-openai'
    location: openAILocation
    tags: tags
    sku: {
      name: 'S0'
    }
    disableLocalAuth: false
    deployments: modelDeployments
    contentFilterPolicyName: contentFilterPolicyName
  }
}

// Content filter Responsible AI policy for OpenAI models
module raiPolicy 'core/ai/content-filter.bicep' = if (deployAzureOpenAI) {
  name: 'raiPolicy'
  params: {
    name: '${prefix}-openai'
    policyName: contentFilterPolicyName
  }
  dependsOn: [
    openAI
  ]
}

output AZURE_LOCATION string = location
output AZURE_TENANT_ID string = tenant().tenantId
output DEPLOY_AZURE_CONTAINERAPPS bool = deployContainerApps

output AZURE_CONTAINER_ENVIRONMENT_NAME string = deployContainerApps ? containerApps.outputs.environmentName : ''
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = deployContainerApps ? containerApps.outputs.registryLoginServer : ''
output AZURE_CONTAINER_REGISTRY_NAME string = deployContainerApps ? containerApps.outputs.registryName : ''

output POSTGRES_HOST string = postgresServer.outputs.POSTGRES_DOMAIN_NAME
output POSTGRES_NAME string = postgresServer.outputs.POSTGRES_NAME
output POSTGRES_USERNAME string = administratorLoginUser
output POSTGRES_DATABASE string = backendappDatabaseName
output POSTGRES_PASSWORD string = administratorLoginPassword

output AZURE_OPENAI_ENDPOINT string = deployAzureOpenAI ? openAI.outputs.endpoint : ''
output AZURE_OPENAI_KEY string = deployAzureOpenAI ? openAI.outputs.modelInfos[0].key : ''
output AZURE_OPENAI_API_VERSION string = deployAzureOpenAI ? azureOpenAIAPIVersion : ''
output AZURE_OPENAI_CHAT_DEPLOYMENT string = deployAzureOpenAI ? chatDeploymentName : ''
output AZURE_OPENAI_CHAT_DEPLOYMENT_VERSION string = deployAzureOpenAI ? chatDeploymentVersion : ''
output AZURE_OPENAI_CHAT_DEPLOYMENT_CAPACITY int = deployAzureOpenAI ? chatDeploymentCapacity : 1
output AZURE_OPENAI_CHAT_DEPLOYMENT_SKU string = deployAzureOpenAI ? chatDeploymentSku : ''
output AZURE_OPENAI_CHAT_MODEL string = deployAzureOpenAI ? chatModelName : ''
output AZURE_OPENAI_EMBED_DEPLOYMENT string = deployAzureOpenAI ? embedDeploymentName : ''
output AZURE_OPENAI_EMBED_DEPLOYMENT_VERSION string = deployAzureOpenAI ? embedDeploymentVersion : ''
output AZURE_OPENAI_API_VERSION_EMBED string = deployAzureOpenAI ? azureEmbedAIAPIVersion : ''
output AZURE_OPENAI_EMBED_DEPLOYMENT_CAPACITY int = deployAzureOpenAI ? embedDeploymentCapacity : 1
output AZURE_OPENAI_EMBED_DEPLOYMENT_SKU string = deployAzureOpenAI ? embedDeploymentSku : ''
output AZURE_OPENAI_EMBED_MODEL string = deployAzureOpenAI ? embedModelName : ''

output SERVICE_BACKEND_IDENTITY_PRINCIPAL_ID string = deployContainerApps ? backend.outputs.SERVICE_WEB_IDENTITY_PRINCIPAL_ID : ''
output SERVICE_BACKEND_IDENTITY_NAME string = deployContainerApps ? backend.outputs.SERVICE_WEB_IDENTITY_NAME : ''
output SERVICE_BACKEND_NAME string = deployContainerApps ? backend.outputs.SERVICE_WEB_NAME : ''
output SERVICE_BACKEND_URI string = deployContainerApps ? backend.outputs.SERVICE_WEB_URI : ''
output SERVICE_BACKEND_IMAGE_NAME string = deployContainerApps ? backend.outputs.SERVICE_WEB_IMAGE_NAME : ''

output SERVICE_ARIZE_URI string = deployContainerApps ? arize.outputs.SERVICE_WEB_URI : ''
output SERVICE_ARIZE_IDENTITY_PRINCIPAL_ID string = deployContainerApps ? arize.outputs.SERVICE_WEB_IDENTITY_PRINCIPAL_ID : ''
output ARIZE_SQL_URI string = !deployContainerApps ? arizeSQLUrl : ''

output SERVICE_FRONTEND_IDENTITY_PRINCIPAL_ID string = deployContainerApps ? frontend.outputs.SERVICE_WEB_IDENTITY_PRINCIPAL_ID : ''
output SERVICE_FRONTEND_IDENTITY_NAME string = deployContainerApps ? frontend.outputs.SERVICE_WEB_IDENTITY_NAME : ''
output SERVICE_FRONTEND_NAME string = deployContainerApps ? frontend.outputs.SERVICE_WEB_NAME : ''
output SERVICE_FRONTEND_URI string = deployContainerApps ? frontend.outputs.SERVICE_WEB_URI : ''
output SERVICE_FRONTEND_IMAGE_NAME string = deployContainerApps ? frontend.outputs.SERVICE_WEB_IMAGE_NAME : ''
