@secure()
param value string

param name string
param vaultName string

param tags object = {}

resource secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${vaultName}/${name}'
  properties: {
    value: value
    attributes: {
      enabled: true
    }
  }
  tags: tags
}
