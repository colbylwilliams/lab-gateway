param location string
param resourcePrefix string

param logAnalyticsWrokspaceId string = ''

param tags object = {}

var keyVaultName = '${resourcePrefix}-kv'

resource vault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    tenantId: subscription().tenantId
    accessPolicies: []
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
  tags: tags
}

resource diagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = if (!empty(logAnalyticsWrokspaceId)) {
  name: 'diagnostics'
  scope: vault
  properties: {
    workspaceId: logAnalyticsWrokspaceId
    logs: [
      {
        category: 'AuditEvent'
        enabled: true
      }
    ]
  }
}

output id string = vault.id
output name string = vault.name
