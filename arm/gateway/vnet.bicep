param resourcePrefix string = 'rdg${uniqueString(resourceGroup().id)}'

param vnet string = ''

param addressPrefixes array = [
  '10.0.0.0/16'
]

param gatewaySubnetName string = 'RDGatewaySubnet'
param gatewaySubnetAddressPrefix string = '10.0.0.0/24'

param bastionSubnetName string = 'AzureBastionSubnet' // MUST be AzureBastionSubnet, DO NOT change
param bastionSubnetAddressPrefix string = '10.0.1.0/27'

param appGatewaySubnetName string = 'AppGatewaySubnet'
param appGatewaySubnetAddressPrefix string = '10.0.2.0/26'

param firewallSubnetName string = 'AzureFirewallSubnet'
param firewallSubnetAddressPrefix string = '10.0.3.0/26'

param privateIPAddress string = '10.0.2.5' // MUST be within appGatewaySubnetAddressPrefix and cannot end in .0 - .4 (reserved)

param tags object = {}

var vnetName = empty(vnet) ? '${resourcePrefix}-vnet' : last(split(vnet, '/'))
var vnetRg = empty(vnet) ? '' : first(split(last(split(vnet, '/resourceGroups/')), '/'))
var vnetId = empty(vnet) ? resourceId('Microsoft.Network/virtualNetworks', vnetName) : vnet

resource rg_vnet_existing 'Microsoft.Resources/resourceGroups@2020-06-01' existing = if (!empty(vnet)) {
  name: vnetRg
  scope: subscription()
}

resource vnet_existing 'Microsoft.Network/virtualNetworks@2020-06-01' existing = if (!empty(vnet)) {
  name: vnetName
  scope: rg_vnet_existing
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
      {
        name: firewallSubnetName
        properties: {
          addressPrefix: firewallSubnetAddressPrefix
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

output id string = vnetId
output name string = vnetName
output gatewaySubnet string = empty(vnet) ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnet_new.name, gatewaySubnetName) : resourceId(vnetRg, 'Microsoft.Network/virtualNetworks/subnets', vnet_existing.name, gatewaySubnetName)
output bastionSubnet string = empty(vnet) ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnet_new.name, bastionSubnetName) : resourceId(vnetRg, 'Microsoft.Network/virtualNetworks/subnets', vnet_existing.name, bastionSubnetName)
output appGatewaySubnet string = empty(vnet) ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnet_new.name, appGatewaySubnetName) : resourceId(vnetRg, 'Microsoft.Network/virtualNetworks/subnets', vnet_existing.name, appGatewaySubnetName)
