param location string = resourceGroup().location

param name string
param addressPrefix string
param subnetName string
param subnetPrefix string
param subnetNsgName string

param routeTableId string

resource nsg 'Microsoft.Network/networkSecurityGroups@2020-06-01' = {
  name: subnetNsgName
  location: location
  properties: {
    securityRules: [
      // {
      //   name: 'DenyAllInBound'
      //   properties: {
      //     protocol: 'Tcp'
      //     sourcePortRange: '*'
      //     sourceAddressPrefix: '*'
      //     destinationPortRange: '*'
      //     destinationAddressPrefix: '*'
      //     access: 'Deny'
      //     priority: 1000
      //     direction: 'Inbound'
      //   }
      // }
    ]
  }
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
  }
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = {
  name: '${vnet.name}/${subnetName}'
  properties: {
    addressPrefix: subnetPrefix
    networkSecurityGroup: {
      id: nsg.id
    }
    routeTable: {
      id: routeTableId
    }
  }
}

output vnetId string = vnet.id
output subnetId string = subnet.id
