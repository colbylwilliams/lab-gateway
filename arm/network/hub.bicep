param location string = resourceGroup().location

param name string
param addressPrefix string
param gatewayIpAddress string = '10.0.0.4'

param otherSubnets array = []

param firewall object = {
  name: 'AzureFirewall'
  publicIPAddressName: 'pip-firewall'
  subnetName: 'AzureFirewallSubnet'
  subnetPrefix: '10.0.3.0/26'
  routeName: 'r-nexthop-to-fw'
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: concat([
      {
        name: firewall.subnetName
        properties: {
          addressPrefix: firewall.subnetPrefix
        }
      }
    ], otherSubnets)
  }
}

resource fwpip 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: firewall.publicIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource fw 'Microsoft.Network/azureFirewalls@2020-06-01' = {
  name: firewall.name
  location: location
  properties: {
    sku: {
      name: 'AZFW_VNet'
      tier: 'Standard'
    }
    threatIntelMode: 'Alert'
    ipConfigurations: [
      {
        name: firewall.name
        properties: {
          publicIPAddress: {
            id: fwpip.id
          }
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnet.name, firewall.subnetName)
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
    natRuleCollections: [
      {
        name: 'GatewayDNAT'
        properties: {
          priority: 200
          action: {
            type: 'Dnat'
          }
          rules: [
            {
              name: 'GW-TCP-80'
              protocols: [
                'TCP'
              ]
              translatedAddress: gatewayIpAddress
              translatedPort: '80'
              sourceAddresses: [
                '*'
              ]
              sourceIpGroups: []
              destinationAddresses: [
                fwpip.properties.ipAddress
              ]
              destinationPorts: [
                '80'
              ]
            }
            {
              name: 'GW-TCP-443'
              protocols: [
                'TCP'
              ]
              translatedAddress: gatewayIpAddress
              translatedPort: '443'
              sourceAddresses: [
                '*'
              ]
              sourceIpGroups: []
              destinationAddresses: [
                fwpip.properties.ipAddress
              ]
              destinationPorts: [
                '443'
              ]
            }
            {
              name: 'GW-UDP-3391'
              protocols: [
                'UDP'
              ]
              translatedAddress: gatewayIpAddress
              translatedPort: '3391'
              sourceAddresses: [
                '*'
              ]
              sourceIpGroups: []
              destinationAddresses: [
                fwpip.properties.ipAddress
              ]
              destinationPorts: [
                '3391'
              ]
            }
          ]
        }
      }
    ]
  }
}

resource fwroutetable 'Microsoft.Network/routeTables@2020-06-01' = {
  name: firewall.routeName
  location: location
  properties: {
    disableBgpRoutePropagation: false
    routes: [
      {
        name: firewall.routeName
        properties: {
          addressPrefix: '0.0.0.0/0'
          nextHopType: 'VirtualAppliance'
          nextHopIpAddress: fw.properties.ipConfigurations[0].properties.privateIPAddress
        }
      }
    ]
  }
}

output pipId string = fwpip.id
output vnetId string = vnet.id
output routeTableId string = fwroutetable.id
