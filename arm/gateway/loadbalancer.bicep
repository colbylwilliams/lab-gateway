param resourcePrefix string

param subnet string

param publicIPAddress string = ''
param privateIPAddress string = ''

var publicIPAddressRg = empty(publicIPAddress) ? '' : first(split(last(split(publicIPAddress, '/resourceGroups/')), '/'))
var publicIPAddressName = empty(publicIPAddress) ? '${resourcePrefix}-pip' : last(split(publicIPAddress, '/'))

var loadBalancerName = '${resourcePrefix}-lb'

var loadBalancerBackEndName = 'gatewayBackEnd'
var loadBalancerFrontEndName = 'gatewayFrontEnd'

var frontendIPConfiguration = {
  id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations/', loadBalancerName, loadBalancerFrontEndName)
}
var backendAddressPool = {
  id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, loadBalancerBackEndName)
}

var probe80 = {
  ref: {
    id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'Probe80')
  }
  value: {
    name: 'Probe80'
    properties: {
      protocol: 'Http'
      port: 80
      requestPath: '/api/health'
      intervalInSeconds: 300
      numberOfProbes: 2
    }
  }
}

var probe443 = {
  ref: {
    id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'Probe443')
  }
  value: {
    name: 'Probe443'
    properties: {
      protocol: 'Tcp'
      port: 443
      intervalInSeconds: 5
      numberOfProbes: 2
    }
  }
}

var probe3391 = {
  ref: {
    id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'Probe3391')
  }
  value: {
    name: 'Probe3391'
    properties: {
      protocol: 'Tcp'
      port: 3391
      intervalInSeconds: 5
      numberOfProbes: 2
    }
  }
}

var probes = [
  probe80.value
  probe443.value
  probe3391.value
]

var loadBalancingRules = [
  {
    name: 'TCP80'
    properties: {
      frontendIPConfiguration: frontendIPConfiguration
      backendAddressPool: backendAddressPool
      probe: probe80.ref
      protocol: 'Tcp'
      frontendPort: 80
      backendPort: 80
      enableFloatingIP: false
      idleTimeoutInMinutes: 5
      enableTcpReset: false
      loadDistribution: 'SourceIPProtocol'
    }
  }
  {
    name: 'TCP443'
    properties: {
      frontendIPConfiguration: frontendIPConfiguration
      backendAddressPool: backendAddressPool
      probe: probe443.ref
      protocol: 'Tcp'
      frontendPort: 443
      backendPort: 443
      enableFloatingIP: false
      idleTimeoutInMinutes: 4
      enableTcpReset: false
      loadDistribution: 'SourceIPProtocol'
    }
  }
  {
    name: 'UDP3391'
    properties: {
      frontendIPConfiguration: frontendIPConfiguration
      backendAddressPool: backendAddressPool
      probe: probe3391.ref
      protocol: 'Udp'
      frontendPort: 3391
      backendPort: 3391
      enableFloatingIP: false
      idleTimeoutInMinutes: 4
      enableTcpReset: false
      loadDistribution: 'SourceIPProtocol'
    }
  }
]

var createPublicIpAddress = empty(publicIPAddress) && empty(privateIPAddress)

resource rg_publicIPAddress_existing 'Microsoft.Resources/resourceGroups@2020-06-01' existing = if (!empty(publicIPAddress)) {
  name: publicIPAddressRg
  scope: subscription()
}

resource publicIPAddress_existing 'Microsoft.Network/publicIPAddresses@2020-06-01' existing = if (!empty(publicIPAddress)) {
  name: publicIPAddressName
  scope: rg_publicIPAddress_existing
}

resource publicIPAddress_new 'Microsoft.Network/publicIPAddresses@2020-06-01' = if (createPublicIpAddress) {
  name: publicIPAddressName
  location: resourceGroup().location
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv4'
    idleTimeoutInMinutes: 4
    dnsSettings: {
      domainNameLabel: resourcePrefix
    }
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2020-06-01' = {
  name: loadBalancerName
  location: resourceGroup().location
  sku: {
    name: 'Basic'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: loadBalancerFrontEndName
        properties: {
          publicIPAddress: createPublicIpAddress ? {
            id: publicIPAddress_new.id
          } : empty(publicIPAddress) ? json('null') : {
            id: publicIPAddress_existing.id
          }
          subnet: createPublicIpAddress || !empty(publicIPAddress) ? json('null') : {
            id: subnet
          }
          privateIPAddress: createPublicIpAddress || !empty(publicIPAddress) ? json('null') : empty(privateIPAddress) ? json('null') : privateIPAddress
          privateIPAllocationMethod: empty(privateIPAddress) ? 'Dynamic' : 'Static'
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    backendAddressPools: [
      {
        name: loadBalancerBackEndName
      }
    ]
    loadBalancingRules: loadBalancingRules
    probes: probes
    inboundNatPools: []
  }
}

output ip string = createPublicIpAddress ? publicIPAddress_new.properties.ipAddress : !empty(publicIPAddress) ? publicIPAddress_existing.properties.ipAddress : privateIPAddress
output backendAddressPools array = loadBalancer.properties.backendAddressPools
