param resourcePrefix string

param vnet string = ''

param addressPrefixes array

param gatewaySubnetName string
param gatewaySubnetAddressPrefix string = '' // '10.0.0.0/24'

param bastionSubnetAddressPrefix string = '' // '10.0.1.0/27'

param appGatewaySubnetName string
param appGatewaySubnetAddressPrefix string = '' // '10.0.2.0/26'

var bastionSubnetName = 'AzureBastionSubnet' // MUST be AzureBastionSubnet, DO NOT change

param tags object = {}

var vnetName = empty(vnet) ? '${resourcePrefix}-vnet' : last(split(vnet, '/'))
var vnetRg = empty(vnet) ? '' : first(split(last(split(vnet, '/resourceGroups/')), '/'))
var vnetId = empty(vnet) ? resourceId('Microsoft.Network/virtualNetworks', vnetName) : vnet

resource vnet_new 'Microsoft.Network/virtualNetworks@2020-06-01' = if (empty(vnet)) {
  name: vnetName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: []
    enableDdosProtection: false
    enableVmProtection: false
  }
  tags: tags
}

module gateway_subnet 'subnet.bicep' = {
  name: 'gatewaySubnet'
  params: {
    vnet: empty(vnet) ? vnet_new.id : vnet
    name: gatewaySubnetName
    addressPrefix: gatewaySubnetAddressPrefix
  }
  dependsOn: [
    vnet_new
  ]
}

module appgateway_subnet 'subnet.bicep' = {
  name: 'appGatewaySubnet'
  params: {
    vnet: empty(vnet) ? vnet_new.id : vnet
    name: appGatewaySubnetName
    addressPrefix: appGatewaySubnetAddressPrefix
  }
  dependsOn: [
    vnet_new
    gateway_subnet
  ]
}

module bastion_subnet 'subnet.bicep' = {
  name: 'bastionSubnet'
  params: {
    vnet: empty(vnet) ? vnet_new.id : vnet
    name: bastionSubnetName
    addressPrefix: bastionSubnetAddressPrefix
  }
  dependsOn: [
    vnet_new
    gateway_subnet
    appgateway_subnet
  ]
}

output id string = vnetId
output name string = vnetName
output gatewaySubnet string = gateway_subnet.outputs.subnet
output bastionSubnet string = bastion_subnet.outputs.subnet
output appGatewaySubnet string = appgateway_subnet.outputs.subnet
