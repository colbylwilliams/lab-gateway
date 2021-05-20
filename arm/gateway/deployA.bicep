param resourcePrefix string = 'rdg${uniqueString(resourceGroup().id)}'

param userId string
param tenantId string

param tags object = {}

module logWorkspace 'logAnalytics.bicep' = {
  name: 'logWorkspace'
  params: {
    resourcePrefix: resourcePrefix
    tags: tags
  }
}

module kv 'keyvault.bicep' = {
  name: 'keyvault'
  params: {
    resourcePrefix: resourcePrefix
    logAnalyticsWrokspaceId: logWorkspace.outputs.id
    tags: tags
  }
}

module kvPolicy 'importPolicy.bicep' = {
  name: 'certImportPolicy'
  params: {
    keyVaultName: kv.outputs.name
    tenantId: tenantId
    principalId: userId
  }
}

module storage 'storage.bicep' = {
  name: 'storage'
  params: {
    accountName: resourcePrefix
    tags: tags
  }
}

output resourcePrefix string = resourcePrefix

output keyvault object = {
  id: kv.outputs.id
  name: kv.outputs.name
}

output storage object = {
  connectionString: storage.outputs.connectionString
  artifactsContainerName: storage.outputs.artifactsContainerName
}
