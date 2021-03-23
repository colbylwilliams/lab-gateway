param resourcePrefix string

param subnet string
param apiHost string
param gatewayHost string

param rootCertData string
param rootSecretUriWithVersion string

@minLength(1)
@description('Certificate as Base64 encoded string.')
param sslCertificate string

@secure()
@description('Certificate password for installation.')
param sslCertificatePassword string

param publicIPAddress string = ''
// param privateIPAddress string = ''
param privateIPAddress string

// var backendName = 'gatewayBackend'
// var frontendName = 'gatewayFrontend'

var publicIPAddressName = empty(publicIPAddress) ? '${resourcePrefix}-gw-pip' : last(split(publicIPAddress, '/'))
// var publicIPAddressName = '${resourcePrefix}-gw-pip'

var appGatewayName = '${resourcePrefix}-gw'

var gateway = {
  frontendIp: {
    public: {
      name: 'publicFrontendIp'
      ref: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations/', appGatewayName, 'publicFrontendIp')
      }
    }
    private: {
      name: 'privateFrontendIp'
      ref: {
        id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations/', appGatewayName, 'privateFrontendIp')
      }
    }
  }
  httpListener: {
    public: {
      name: 'publicHttpListener'
      ref: {
        id: resourceId('Microsoft.Network/applicationGateways/httpListeners/', appGatewayName, 'publicHttpListener')
      }
    }
    private: {
      name: 'privateHttpListener'
      ref: {
        id: resourceId('Microsoft.Network/applicationGateways/httpListeners/', appGatewayName, 'privateHttpListener')
      }
    }
  }
  routingRule: {
    public: {
      name: 'publicRoutingRule'
      urlPathMapRef: {
        id: resourceId('Microsoft.Network/applicationGateways/urlPathMaps/', appGatewayName, 'publicRoutingRule')
      }
    }
    private: {
      name: 'privateRoutingRule'
      urlPathMapRef: {
        id: resourceId('Microsoft.Network/applicationGateways/urlPathMaps/', appGatewayName, 'privateRoutingRule')
      }
    }
  }
  backendAddressPool: {
    name: 'gatewayBackend'
    ref: {
      id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools/', appGatewayName, 'gatewayBackend')
    }
  }
  backendHttpSettings: {
    name: 'gatewayHttpSettings'
    ref: {
      id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection/', appGatewayName, 'gatewayHttpSettings')
    }
  }
  healthCheckProbe: {
    name: 'gatewayHealthCheck'
    ref: {
      id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'gatewayHealthCheck')
    }
  }
}

var api = {
  backendAddressPool: {
    name: 'apiBackend'
    ref: {
      id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools/', appGatewayName, 'apiBackend')
    }
  }
  backendHttpSettings: {
    name: 'apiHttpSettings'
    ref: {
      id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection/', appGatewayName, 'apiHttpSettings')
    }
  }
  healthCheckProbe: {
    name: 'apiHealthCheck'
    ref: {
      id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'apiHealthCheck')
    }
  }
}

resource pip_existing 'Microsoft.Network/publicIPAddresses@2020-06-01' existing = if (!empty(publicIPAddress)) {
  name: publicIPAddressName
}

resource pip_new 'Microsoft.Network/publicIPAddresses@2020-06-01' = if (empty(publicIPAddress)) {
  name: publicIPAddressName
  location: resourceGroup().location
  sku: {
    name: 'Standard'
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

resource gw 'Microsoft.Network/applicationGateways@2020-06-01' = {
  name: appGatewayName
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 10
    }
    gatewayIPConfigurations: [
      {
        name: 'gatewayIpConfig'
        properties: {
          subnet: {
            id: subnet
          }
        }
      }
    ]
    frontendIPConfigurations: [
      {
        name: gateway.frontendIp.public.name
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: empty(publicIPAddress) ? pip_new.id : pip_existing.id
          }
        }
      }
      {
        name: gateway.frontendIp.private.name
        properties: {
          privateIPAddress: privateIPAddress
          privateIPAllocationMethod: 'Static'
          subnet: {
            id: subnet
          }
        }
      }
    ]
    frontendPorts: [
      {
        name: 'Port443'
        properties: {
          port: 443
        }
      }
      {
        name: 'Port80'
        properties: {
          port: 80
        }
      }
    ]
    backendAddressPools: [
      {
        name: 'gatewayBackend'
        properties: {
          backendAddresses: []
        }
      }
      {
        name: 'apiBackend'
        properties: {
          backendAddresses: [
            {
              fqdn: apiHost
            }
          ]
        }
      }
    ]
    backendHttpSettingsCollection: [
      {
        name: gateway.backendHttpSettings.name
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: gatewayHost
          requestTimeout: 20
          pickHostNameFromBackendAddress: false
          probe: gateway.healthCheckProbe.ref
          trustedRootCertificates: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates/', appGatewayName, gatewayHost)
            }
          ]
        }
      }
      {
        name: api.backendHttpSettings.name
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 20
          pickHostNameFromBackendAddress: true
          probe: api.healthCheckProbe.ref
        }
      }
    ]
    httpListeners: [
      {
        name: gateway.httpListener.public.name
        properties: {
          protocol: 'Https'
          // hostName: host
          // requireServerNameIndication:false
          frontendIPConfiguration: gateway.frontendIp.public.ref
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts/', appGatewayName, 'Port443')
          }
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates/', appGatewayName, gatewayHost)
          }
        }
      }
      {
        name: gateway.httpListener.private.name
        properties: {
          protocol: 'Http'
          // hostName: host
          // requireServerNameIndication:false
          frontendIPConfiguration: gateway.frontendIp.private.ref
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts/', appGatewayName, 'Port80')
          }
          sslCertificate: null
        }
      }
    ]
    requestRoutingRules: [
      {
        name: gateway.routingRule.public.name
        properties: {
          ruleType: 'PathBasedRouting'
          httpListener: gateway.httpListener.public.ref
          urlPathMap: gateway.routingRule.public.urlPathMapRef
        }
      }
      {
        name: gateway.routingRule.private.name
        properties: {
          ruleType: 'PathBasedRouting'
          httpListener: gateway.httpListener.private.ref
          urlPathMap: gateway.routingRule.private.urlPathMapRef
        }
      }
    ]
    enableHttp2: false
    sslCertificates: [
      {
        name: gatewayHost
        properties: {
          data: sslCertificate
          password: sslCertificatePassword
        }
      }
    ]
    probes: [
      {
        name: gateway.healthCheckProbe.name
        properties: {
          backendHttpSettings: [
            gateway.backendHttpSettings.ref
          ]
          protocol: 'Https'
          path: '/api/health'
          interval: 300
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
        }
      }
      {
        name: api.healthCheckProbe.name
        properties: {
          backendHttpSettings: [
            api.backendHttpSettings.ref
          ]
          protocol: 'Https'
          path: '/api/health'
          interval: 300
          timeout: 30
          unhealthyThreshold: 3
          pickHostNameFromBackendHttpSettings: true
          minServers: 0
        }
      }
    ]
    webApplicationFirewallConfiguration: {
      enabled: true
      firewallMode: 'Detection'
      ruleSetType: 'OWASP'
      ruleSetVersion: '3.0'
    }
    trustedRootCertificates: [
      {
        name: gatewayHost
        properties: {
          // keyVaultSecretId: internalSslCertId
          keyVaultSecretId: rootSecretUriWithVersion
          // data: rootCertData
          backendHttpSettings: [
            gateway.backendHttpSettings.ref
          ]
        }
      }
    ]
    urlPathMaps: [
      {
        name: gateway.routingRule.public.name
        properties: {
          pathRules: [
            {
              name: 'apiTarget'
              properties: {
                paths: [
                  '/api/*'
                ]
                backendAddressPool: api.backendAddressPool.ref
                backendHttpSettings: api.backendHttpSettings.ref
              }
            }
          ]
          defaultBackendAddressPool: gateway.backendAddressPool.ref
          defaultBackendHttpSettings: gateway.backendHttpSettings.ref
        }
      }
      {
        name: gateway.routingRule.private.name
        properties: {
          pathRules: [
            {
              name: 'apiTarget'
              properties: {
                paths: [
                  '/api/*'
                ]
                backendAddressPool: api.backendAddressPool.ref
                backendHttpSettings: api.backendHttpSettings.ref
              }
            }
          ]
          defaultBackendAddressPool: gateway.backendAddressPool.ref
          defaultBackendHttpSettings: gateway.backendHttpSettings.ref
        }
      }
    ]
  }
}

// output ip string = createPublicIpAddress ? publicIPAddress_new.properties.ipAddress : !empty(publicIPAddress) ? publicIPAddress_existing.properties.ipAddress : privateIPAddress
output ip string = empty(publicIPAddress) ? pip_new.properties.ipAddress : pip_existing.properties.ipAddress
output backendAddressPools array = [
  {
    id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools/', appGatewayName, 'gatewayBackend')
  }
]
