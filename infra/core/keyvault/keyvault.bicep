param location string

@description('PostgreSQL Username to store in Key Vault')
@secure()
param postgresUsername string

@description('PostgreSQL Password to store in Key Vault')
@secure()
param postgresPassword string

@description('PostgreSQL Port to store in Key Vault')
@secure()
param postgresPort string

@description('PostgreSQL Backend Database to store in Key Vault')
@secure()
param postgresDatabase string

@description('PostgreSQL Hostname to store in Key Vault')
@secure()
param postgresHost string

@description('Azure OpenAI endpoint URL to store in Key Vault')
@secure()
param openAIendpoint string

@description('Azure OpenAI API Key to store in Key Vault')
@secure()
param openAIkey string

@description('Arize SQL DATABASE URL to store in Key Vault')
@secure()
param arizeSQLUrl string

@description('Name of the key vault')
param keyVaultName string

resource keyVault 'Microsoft.KeyVault/vaults@2024-11-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: false
    enabledForTemplateDeployment: true
    enabledForDiskEncryption: false
    tenantId: subscription().tenantId
    enableRbacAuthorization: true
    provisioningState: 'Succeeded'
    sku: {
      name: 'standard'
      family: 'A'
    }
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource postgresUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: keyVault
  name: 'postgres-username'
  properties: {
    value: postgresUsername
  }
}

resource postgresPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: keyVault
  name: 'postgres-password'
  properties: {
    value: postgresPassword
  }
}

resource postgresDBPort 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: keyVault
  name: 'postgres-port'
  properties: {
    value: postgresPort
  }
}

resource postgresDB 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: keyVault
  name: 'postgres-database'
  properties: {
    value: postgresDatabase
  }
}

resource postgresHostURL 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: keyVault
  name: 'postgres-host'
  properties: {
    value: postgresHost
  }
}

resource openAIApiKey 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: keyVault
  name: 'azure-openai-key'
  properties: {
    value: openAIkey
  }
}

resource openAIendpointURL 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: keyVault
  name: 'azure-openai-endpoint'
  properties: {
    value: openAIendpoint
  }
}

resource arizeSQLEndpoint 'Microsoft.KeyVault/vaults/secrets@2024-11-01' = {
  parent: keyVault
  name: 'phoenix-sql-database-url'
  properties: {
    value: arizeSQLUrl
  }
}

output keyVaultName string = keyVault.name
output keyVaultUri string = keyVault.properties.vaultUri
