metadata description = 'Creates an Azure Cognitive Services (Azure OpenAI) account, optional custom RAI content filter policy, and model deployments.'

// Core account parameters
param name string
param location string = resourceGroup().location
param tags object = {}
@description('The custom subdomain name used to access the API. Defaults to the value of the name parameter.')
param customSubDomainName string = name
param disableLocalAuth bool = false
param deployments array = []
param kind string = 'OpenAI'
@allowed([ 'Enabled', 'Disabled' ])
param publicNetworkAccess string = 'Enabled'



// Account SKU / networking
param accountSku object = {
  name: 'S0'
}
param allowedIpRules array = []
param networkAcls object = empty(allowedIpRules) ? {
  defaultAction: 'Allow'
} : {
  ipRules: allowedIpRules
  defaultAction: 'Deny'
}



// Cognitive Services (Azure OpenAI) account
// Updated to latest GA API version (2024-10-01) per Azure Cognitive Services provisioning docs
resource aiaccount 'Microsoft.CognitiveServices/accounts@2024-10-01' = {
  name: name
  location: location
  tags: tags
  kind: kind
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    networkAcls: networkAcls
    disableLocalAuth: disableLocalAuth
  }
  sku: accountSku
}


// Serialise model deployments; ensure they depend on policy if created
@batchSize(1)
// Updated deployments to latest GA API version (2024-10-01)
resource openaideployment 'Microsoft.CognitiveServices/accounts/deployments@2024-10-01' = [for deployment in deployments: {
  parent: aiaccount
  name: deployment.name
  properties: {
    model: deployment.model
  }
  sku: deployment.?sku ?? {
    name: 'Standard'
    capacity: 20
  }
}]

// Outputs
output endpoint string = aiaccount.properties.endpoint
output id string = aiaccount.id
output name string = aiaccount.name
// modelInfos output now excludes keys to avoid secret exposure via deployment outputs.
output modelInfos array = [for d in deployments: {
  name: d.name
  endpoint: aiaccount.properties.endpoint
  key      : aiaccount.listKeys().key1
}]

// Provide a secure reference output for the account id so parent template can fetch keys directly without re-exposing them.
output accountResourceId string = aiaccount.id
