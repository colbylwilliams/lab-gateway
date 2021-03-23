param location string = resourceGroup().location

param name string
param addressPrefix string

param subnets array = []

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: subnets
  }
}

output vnetId string = vnet.id
output vnetName string = vnet.name
