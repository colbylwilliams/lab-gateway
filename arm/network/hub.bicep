param location string = resourceGroup().location

param name string
param addressPrefix string

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
    subnets: [
      {
        name: firewall.subnetName
        properties: {
          addressPrefix: firewall.subnetPrefix
        }
      }
    ]
  }
}

resource fwsnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = {
  name: '${vnet.name}/${firewall.subnetName}'
  properties: {
    addressPrefix: firewall.subnetPrefix
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
            id: fwsnet.id
          }
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

output vnetId string = vnet.id
output routeTableId string = fwroutetable.id
