param location string = resourceGroup().location

@description('Name of the lab.')
param name string

param vnetId string = ''
param subnetId string = ''

@secure()
@description('The name of a secret in the labs keyvault with a token for the remote desktop gateway used by this lab.')
param gatewayToken string = ''

@description('The hostname for the remote desktop gateway used by this lab.')
param gatewayHostname string = ''

param tags object = {}

var setVnet = !empty(vnetId) && !empty(subnetId)
var setGateway = !empty(gatewayToken) && !empty(gatewayHostname)

var subnetName = setVnet ? last(split(subnetId, '/')) : ''

resource lab 'Microsoft.DevTestLab/labs@2018-09-15' = {
  name: name
  location: location
  properties: {
    extendedProperties: setGateway ? {
      RdpGateway: gatewayHostname
      RdpConnectionType: '7'
      RdgTokenSecretName: 'gateway'
    } : {}
  }
  tags: tags
}

resource vnet 'Microsoft.DevTestLab/labs/virtualnetworks@2018-09-15' = if (setVnet) {
  name: '${lab.name}/${name}-vnet'
  location: location
  properties: {
    externalProviderResourceId: vnetId
    subnetOverrides: [
      {
        resourceId: subnetId
        labSubnetName: subnetName
        useInVmCreationPermission: 'Allow'
        usePublicIpAddressPermission: 'Deny'
      }
    ]
  }
  tags: tags
}

module secret 'secret.bicep' = if (setGateway) {
  name: 'secret'
  params: {
    name: 'gateway'
    vaultName: last(split(lab.properties.vaultName, '/'))
    value: gatewayToken
    tags: tags
  }
}

output name string = name
// output rg string = resourceGroup().name
// output location string = resourceGroup().location
output vault string = last(split(lab.properties.vaultName, '/'))
