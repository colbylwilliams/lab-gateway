param labName string
param keyvault string
param gatewayHostname string

@secure()
param gatewayToken string

param gatewayTokenName string = 'gateway'

param tags object = {}

var vaultName = last(split(keyvault, '/'))

resource lab 'Microsoft.DevTestLab/labs@2018-09-15' = {
  name: labName
  location: resourceGroup().location
  properties: {
    extendedProperties: {
      RdpGateway: gatewayHostname
      RdpConnectionType: '7'
      RdgTokenSecretName: 'gateway'
    }
  }
  tags: tags
}

resource token 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${vaultName}/${gatewayTokenName}'
  properties: {
    value: gatewayToken
    attributes: {
      enabled: true
    }
  }
  tags: tags
  dependsOn: [
    lab
  ]
}
