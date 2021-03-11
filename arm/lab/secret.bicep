@secure()
param value string

param name string
param vaultName string

resource secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${vaultName}/${name}'
  properties: {
    value: value
    attributes: {
      enabled: true
    }
  }
}
