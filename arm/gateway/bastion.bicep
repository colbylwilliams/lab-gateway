param subnet string
param resourcePrefix string

var bastionHostName = '${resourcePrefix}-bh'
var bastionIPAddressName = '${resourcePrefix}-bh-pip'

resource bastionIPAddress 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
  name: bastionIPAddressName
  location: resourceGroup().location
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
}

resource bastionHost 'Microsoft.Network/bastionHosts@2020-06-01' = {
  name: bastionHostName
  location: resourceGroup().location
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
}
