param labName string

param location string
param gatewayHostname string

@secure()
param gatewayToken string

param gatewayTokenName string = 'gateway'

param tags object = {}

resource lab 'Microsoft.DevTestLab/labs@2018-09-15' = {
  name: labName
  location: location
  properties: {
    extendedProperties: {
      RdpGateway: gatewayHostname
      RdpConnectionType: '7'
      RdgTokenSecretName: gatewayTokenName
    }
  }
  tags: tags
}

module secret 'labSecret.bicep' = {
  name: 'gatewaySecret'
  params: {
    name: gatewayTokenName
    vaultName: last(split(lab.properties.vaultName, '/'))
    value: gatewayToken
    tags: tags
  }
}

// resource token 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
//   name: '${vaultName}/${gatewayTokenName}'
//   properties: {
//     value: gatewayToken
//     attributes: {
//       enabled: true
//     }
//   }
//   tags: tags
//   dependsOn: [
//     lab
//   ]
// }
