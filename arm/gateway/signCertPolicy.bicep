param tenantId string
param principalId string
param keyVaultName string

resource policy 'Microsoft.KeyVault/vaults/accessPolicies@2019-09-01' = {
  name: any('${keyVaultName}/add')
  properties: {
    accessPolicies: [
      {
        tenantId: tenantId
        objectId: principalId
        permissions: {
          keys: [
            'get'
            'create'
          ]
          secrets: [
            'get'
            'set'
          ]
          certificates: [
            'get'
            'create'
          ]
        }
      }
    ]
  }
}
