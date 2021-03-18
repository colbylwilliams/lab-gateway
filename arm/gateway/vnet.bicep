param resourcePrefix string

param vnet string = ''

param addressPrefixes array
param gatewaySubnetName string
param gatewaySubnetAddressPrefix string

param bastionSubnetName string
param bastionSubnetAddressPrefix string

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
          addressPrefix: gatewaySubnetAddressPrefix // '10.0.0.0/24'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: bastionSubnetAddressPrefix // '10.0.1.0/27'
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    enableDdosProtection: false
    enableVmProtection: false
  }
}

output id string = vnetId
output name string = vnetName
output gatewaySubnet string = empty(vnet) ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnet_new.name, gatewaySubnetName) : resourceId(vnetRg, 'Microsoft.Network/virtualNetworks/subnets', vnet_existing.name, gatewaySubnetName)
output bastionSubnet string = empty(vnet) ? resourceId('Microsoft.Network/virtualNetworks/subnets', vnet_new.name, bastionSubnetName) : resourceId(vnetRg, 'Microsoft.Network/virtualNetworks/subnets', vnet_existing.name, bastionSubnetName)
