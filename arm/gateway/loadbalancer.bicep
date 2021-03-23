param resourcePrefix string

param subnet string

param publicIPAddress string = ''
param privateIPAddress string = ''

var publicIPAddressName = empty(publicIPAddress) ? '${resourcePrefix}-fw-pip' : last(split(publicIPAddress, '/'))

var loadBalancerName = '${resourcePrefix}-lb'
var backendAddressPoolName = 'gatewayBackend'
var frontendIPConfigurationName = 'gatewayFrontend'

var frontendIPConfiguration = {
  id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations/', loadBalancerName, frontendIPConfigurationName)
}
var backendAddressPool = {
  id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, backendAddressPoolName)
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

resource pip_existing 'Microsoft.Network/publicIPAddresses@2020-06-01' existing = if (!empty(publicIPAddress)) {
  name: publicIPAddressName
}

resource pip_new 'Microsoft.Network/publicIPAddresses@2020-06-01' = if (createPublicIpAddress) {
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
        name: frontendIPConfigurationName
        properties: {
          publicIPAddress: createPublicIpAddress ? {
            id: pip_new.id
          } : empty(publicIPAddress) ? json('null') : {
            id: pip_existing.id
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
        name: backendAddressPoolName
      }
    ]
    loadBalancingRules: loadBalancingRules
    probes: probes
    inboundNatPools: []
  }
}

output ip string = createPublicIpAddress ? pip_new.properties.ipAddress : !empty(publicIPAddress) ? pip_existing.properties.ipAddress : privateIPAddress
output backendAddressPools array = loadBalancer.properties.backendAddressPools
