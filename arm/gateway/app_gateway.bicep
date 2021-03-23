param resourcePrefix string

param subnet string
param apiHost string
param gatewayHost string

param rootCertData string

@minLength(1)
@description('Certificate as Base64 encoded string.')
param sslCertificate string

@secure()
@description('Certificate password for installation.')
param sslCertificatePassword string

// param publicIPAddress string = ''
// param privateIPAddress string = ''
param privateIPAddress string

// var backendName = 'gatewayBackend'
// var frontendName = 'gatewayFrontend'

// var publicIPAddressName = empty(publicIPAddress) ? '${resourcePrefix}-fw-pip' : last(split(publicIPAddress, '/'))
var publicIPAddressName = '${resourcePrefix}-gw-pip'

var appGatewayName = '${resourcePrefix}-gw'

// resource ip 'Microsoft.Network/publicIPAddresses@2020-06-01' = if (createPublicIpAddress) {
resource pip 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
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

resource gateway 'Microsoft.Network/applicationGateways@2020-06-01' = {
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
        name: 'publicFrontendIp'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: pip.id
          }
        }
      }
      {
        name: 'privateFrontendIp'
        properties: {
          privateIPAddress: privateIPAddress // '10.0.2.5'
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
        name: 'gatewayHttpSettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          hostName: gatewayHost
          requestTimeout: 20
          pickHostNameFromBackendAddress: false
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'gatewayHealthCheck')
          }
          trustedRootCertificates: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/trustedRootCertificates/', appGatewayName, gatewayHost)
            }
          ]
        }
      }
      {
        name: 'apiHttpSettings'
        properties: {
          port: 443
          protocol: 'Https'
          cookieBasedAffinity: 'Disabled'
          requestTimeout: 20
          pickHostNameFromBackendAddress: true
          probe: {
            id: resourceId('Microsoft.Network/applicationGateways/probes', appGatewayName, 'apiHealthCheck')
          }
        }
      }
    ]
    httpListeners: [
      {
        name: 'publicHttpListener'
        properties: {
          protocol: 'Https'
          // hostName: host
          // requireServerNameIndication:false
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations/', appGatewayName, 'publicFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts/', appGatewayName, 'Port443')
          }
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates/', appGatewayName, gatewayHost)
          }
        }
      }
      {
        name: 'privateHttpListener'
        properties: {
          protocol: 'Http'
          // hostName: host
          // requireServerNameIndication:false
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendIPConfigurations/', appGatewayName, 'privateFrontendIp')
          }
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts/', appGatewayName, 'Port80')
          }
          sslCertificate: null
        }
      }
    ]
    requestRoutingRules: [
      {
        name: 'publicRoutingRule'
        properties: {
          ruleType: 'PathBasedRouting'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners/', appGatewayName, 'publicHttpListener')
          }
          urlPathMap: {
            id: resourceId('Microsoft.Network/applicationGateways/urlPathMaps/', appGatewayName, 'publicRoutingRule')
          }
        }
      }
      {
        name: 'privateRoutingRule'
        properties: {
          ruleType: 'PathBasedRouting'
          httpListener: {
            id: resourceId('Microsoft.Network/applicationGateways/httpListeners/', appGatewayName, 'privateHttpListener')
          }
          urlPathMap: {
            id: resourceId('Microsoft.Network/applicationGateways/urlPathMaps/', appGatewayName, 'privateRoutingRule')
          }
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
        name: 'gatewayHealthCheck'
        properties: {
          backendHttpSettings: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection/', appGatewayName, 'gatewayHttpSettings')
            }
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
        name: 'apiHealthCheck'
        properties: {
          backendHttpSettings: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection/', appGatewayName, 'apiHttpSettings')
            }
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
          data: rootCertData
          backendHttpSettings: [
            {
              id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection/', appGatewayName, 'gatewayHttpSettings')
            }
          ]
        }
      }
    ]
    urlPathMaps: [
      {
        name: 'publicRoutingRule'
        properties: {
          pathRules: [
            {
              name: 'apiTarget'
              properties: {
                paths: [
                  '/api/*'
                ]
                backendAddressPool: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools/', appGatewayName, 'apiBackend')
                }
                backendHttpSettings: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection/', appGatewayName, 'apiHttpSettings')
                }
              }
            }
          ]
          defaultBackendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools/', appGatewayName, 'gatewayBackend')
          }
          defaultBackendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection/', appGatewayName, 'gatewayHttpSettings')
          }
        }
      }
      {
        name: 'privateRoutingRule'
        properties: {
          pathRules: [
            {
              name: 'apiTarget'
              properties: {
                paths: [
                  '/api/*'
                ]
                backendAddressPool: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools/', appGatewayName, 'apiBackend')
                }
                backendHttpSettings: {
                  id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection/', appGatewayName, 'apiHttpSettings')
                }
              }
            }
          ]
          defaultBackendAddressPool: {
            id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools/', appGatewayName, 'gatewayBackend')
          }
          defaultBackendHttpSettings: {
            id: resourceId('Microsoft.Network/applicationGateways/backendHttpSettingsCollection/', appGatewayName, 'gatewayHttpSettings')
          }
        }
      }
    ]
  }
}

// output ip string = createPublicIpAddress ? publicIPAddress_new.properties.ipAddress : !empty(publicIPAddress) ? publicIPAddress_existing.properties.ipAddress : privateIPAddress
output ip string = pip.properties.ipAddress
output backendAddressPools array = [
  {
    id: resourceId('Microsoft.Network/applicationGateways/backendAddressPools/', appGatewayName, 'gatewayBackend')
  }
]
