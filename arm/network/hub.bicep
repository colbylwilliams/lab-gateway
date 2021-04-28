param location string = resourceGroup().location

param name string
param addressPrefixs array

param subnets array = []

param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = {
  name: name
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: addressPrefixs
    }
    subnets: subnets
  }
  tags: tags
}

output vnetId string = vnet.id
output vnetName string = vnet.name
