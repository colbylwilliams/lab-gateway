param resourcePrefix string
param site string
param vnet string
param subnet string

var privateEndpointName = '${resourcePrefix}-pe'
var privateDnsZoneName = 'privatelink.azurewebsites.net'
var privateDnsZoneLinkName = '${resourcePrefix}-dnslink'

resource privateEndpoint 'Microsoft.Network/privateEndpoints@2020-05-01' = {
  name: privateEndpointName
  location: 'eastus'
  properties: {
    subnet: {
      id: subnet
    }
    privateLinkServiceConnections: [
      {
        name: privateEndpointName
        properties: {
          privateLinkServiceId: site
          groupIds: [
            'sites'
          ]
        }
      }
    ]
    manualPrivateLinkServiceConnections: []
    customDnsConfigs: []
  }
}

resource privateDnsZone 'Microsoft.Network/privateDnsZones@2018-09-01' = {
  name: privateDnsZoneName
  location: 'global'
  properties: {}
}

resource privateDnsZoneName_privateDnsZoneLinkName 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2018-09-01' = {
  name: '${privateDnsZone.name}/${privateDnsZoneLinkName}'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet
    }
  }
}

resource privateEndpoint_default 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2020-05-01' = {
  name: '${privateEndpoint.name}/default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink-azurewebsites-net'
        properties: {
          privateDnsZoneId: privateDnsZone.id
        }
      }
    ]
  }
}
