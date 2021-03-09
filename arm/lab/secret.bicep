@secure()
param value string

param name string
param vaultName string

resource secret 'Microsoft.KeyVault/vaults/secrets@2020-04-01-preview' = {
  name: '${vaultName}/${name}'
  properties: {
    value: value
    attributes: {
      enabled: true
    }
  }
}
