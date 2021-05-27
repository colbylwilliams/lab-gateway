param location string
param resourcePrefix string

param subnet string

param tags object = {}

var bastionHostName = '${resourcePrefix}-bh'
var bastionIPAddressName = '${resourcePrefix}-bh-pip'

resource bastionIPAddress 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: bastionIPAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: '${resourcePrefix}-admin'
    }
  }
  tags: tags
}

resource bastionHost 'Microsoft.Network/bastionHosts@2020-06-01' = {
  name: bastionHostName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: subnet
          }
          publicIPAddress: {
            id: bastionIPAddress.id
          }
        }
      }
    ]
  }
  tags: tags
}
