param location string = resourceGroup().location

param name string = 'AzureFirewall'
param vnetName string
param publicIPAddressName string = 'pip-firewall'
param subnetName string = 'AzureFirewallSubnet'
param routeName string = 'r-nexthop-to-fw'

param tags object = {}

resource fwpip 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: publicIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
  tags: tags
}

resource fw 'Microsoft.Network/azureFirewalls@2020-06-01' = {
  name: name
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    ipConfigurations: [
      {
        name: name
        properties: {
          publicIPAddress: {
            id: fwpip.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, subnetName)
          }
        }
      }
    ]
    networkRuleCollections: [
      {
        name: 'AllowAll'
        properties: {
          priority: 200
          action: {
            type: 'Allow'
          }
          rules: [
            {
              name: 'AllowAll'
              protocols: [
                'TCP'
              ]
              sourceAddresses: [
                '*'
              ]
              destinationAddresses: [
                '*'
              ]
              sourceIpGroups: []
              destinationIpGroups: []
              destinationFqdns: []
              destinationPorts: [
                '*'
              ]
            }
          ]
        }
      }
    ]
    natRuleCollections: []
  }
  tags: tags
}

resource fwroutetable 'Microsoft.Network/routeTables@2020-06-01' = {
  name: routeName
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: routeName
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: fw.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
  tags: tags
}

output pipId string = fwpip.id
output routeTableId string = fwroutetable.id
