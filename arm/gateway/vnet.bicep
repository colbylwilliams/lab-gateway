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

resource rg_vnet_existing 'Microsoft.Resources/resourceGroups@2020-06-01' existing = if (!empty(vnet)) {
  name: vnetRg
  scope: subscription()
}

resource vnet_new 'Microsoft.Network/virtualNetworks@2020-06-01' = if (empty(vnet)) {
  name: vnetName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixes
    }
    subnets: [
      {
        name: gatewaySubnetName
        properties: {
          addressPrefix: gatewaySubnetAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: bastionSubnetAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: appGatewaySubnetName
        properties: {
          addressPrefix: appGatewaySubnetAddressPrefix
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
    enableVmProtection: false
  }
  tags: tags
}

module gateway_subnet 'subnet.bicep' = if (!empty(vnet)) {
  name: 'gatewaySubnet'
  scope: rg_vnet_existing
  params: {
    vnet: vnet
    name: gatewaySubnetName
    addressPrefix: gatewaySubnetAddressPrefix
  }
  dependsOn: []
}

module appgateway_subnet 'subnet.bicep' = if (!empty(vnet)) {
  name: 'appGatewaySubnet'
  scope: rg_vnet_existing
  params: {
    vnet: vnet
    name: appGatewaySubnetName
    addressPrefix: appGatewaySubnetAddressPrefix
  }
  dependsOn: [
    // gateway_subnet
  ]
}

module bastion_subnet 'subnet.bicep' = if (!empty(vnet)) {
  name: 'bastionSubnet'
  scope: rg_vnet_existing
  params: {
    vnet: vnet
    name: bastionSubnetName
    addressPrefix: bastionSubnetAddressPrefix
  }
  dependsOn: [
    // gateway_subnet
    // appgateway_subnet
  ]
}

output id string = vnetId
output name string = vnetName
output gatewaySubnet string = empty(vnet) ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, gatewaySubnetName) : resourceId(vnetRg, 'Microsoft.Network/virtualNetworks/subnets', vnetName, gatewaySubnetName)
output bastionSubnet string = empty(vnet) ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, bastionSubnetName) : resourceId(vnetRg, 'Microsoft.Network/virtualNetworks/subnets', vnetName, bastionSubnetName)
output appGatewaySubnet string = empty(vnet) ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, appGatewaySubnetName) : resourceId(vnetRg, 'Microsoft.Network/virtualNetworks/subnets', vnetName, appGatewaySubnetName)
