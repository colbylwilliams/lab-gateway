param vnetId string
param toVnetId string

var vnetName = last(split(vnetId, '/'))
var toVnetName = last(split(toVnetId, '/'))

resource peer 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2020-06-01' = {
  name: '${vnetName}/${vnetName}-to-${toVnetName}'
  properties: {
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: false
    allowGatewayTransit: false
    useRemoteGateways: false
    remoteVirtualNetwork: {
      id: toVnetId
    }
  }
}
