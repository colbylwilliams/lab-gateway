param location string
param resourcePrefix string

param subnet string
param apiHost string
param gatewayHost string

param keyVaultName string

param sslCertificateSecretUri string

param publicIPAddress string = ''
param privateIPAddress string

param logAnalyticsWrokspaceId string = ''

param azureResourceProviderIps array

param tags object = {}

var appGatewayName = '${resourcePrefix}-gw'

var publicIPAddressName = empty(publicIPAddress) ? '${appGatewayName}-pip' : last(split(publicIPAddress, '/'))

var gatewayFirewallPolicyName = '${appGatewayName}-waf'
var apiFirewallPolicyName = '${appGatewayName}-waf-api'
var listenerFirewallPolicyName = '${appGatewayName}-waf-rdg'

var azureResourceProviderMatchConditions = [for ips in azureResourceProviderIps: {
  operator: 'IPMatch'
  negationConditon: true
  matchVariables: [
    {
      variableName: 'RemoteAddr'
    }
  ]
  matchValues: ips
}]

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
  location: location
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
  tags: tags
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: appGatewayName
  location: location
  tags: tags
}

module accessPolicy 'gatewayPolicy.bicep' = {
  name: 'gatewayIdentityAccessPolicy'
  params: {
    keyVaultName: keyVaultName
    tenantId: identity.properties.tenantId
    principalId: identity.properties.principalId
  }
}

resource listenerWafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2020-08-01' = {
  name: listenerFirewallPolicyName
  location: location
  properties: {
    policySettings: {
      mode: 'Prevention'
      state: 'Enabled'
    }
    customRules: []
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.1'
          ruleGroupOverrides: [
            {
              ruleGroupName: 'REQUEST-920-PROTOCOL-ENFORCEMENT'
              rules: [
                {
                  ruleId: '920100' // Invalid HTTP Request Line rule
                  state: 'Disabled' // Disabled to allow RDG_OUT_DATA and RPC_IN_DATA
                }
                {
                  ruleId: '920440' // URL file extension is restricted by policy
                  state: 'Disabled' // Disabled to allow connection to /rpc/rpcproxy.dll
                }
              ]
            }
            {
              ruleGroupName: 'REQUEST-911-METHOD-ENFORCEMENT'
              rules: [
                {
                  ruleId: '911100' // Method is not allowed by policy
                  state: 'Disabled' // Disabled to allow RDG_OUT_DATA and RPC_IN_DATA
                }
              ]
            }
          ]
        }
      ]
    }
  }
  tags: tags
}

resource gatewayWafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2020-08-01' = {
  name: gatewayFirewallPolicyName
  location: location
  properties: {
    policySettings: {
      mode: 'Prevention'
      state: 'Enabled'
    }
    customRules: []
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.1'
          // ruleGroupOverrides: [
          //   {
          //     ruleGroupName: 'REQUEST-920-PROTOCOL-ENFORCEMENT'
          //     rules: [
          //       {
          //         ruleId: '920100' // Invalid HTTP Request Line rule
          //         state: 'Disabled' // Disabled to allow RDG_OUT_DATA and RPC_IN_DATA
          //       }
          //       {
          //         ruleId: '920440' // URL file extension is restricted by policy
          //         state: 'Disabled' // Disabled to allow connection to /rpc/rpcproxy.dll
          //       }
          //     ]
          //   }
          //   {
          //     ruleGroupName: 'REQUEST-911-METHOD-ENFORCEMENT'
          //     rules: [
          //       {
          //         ruleId: '911100' // Method is not allowed by policy
          //         state: 'Disabled' // Disabled to allow RDG_OUT_DATA and RPC_IN_DATA
          //       }
          //     ]
          //   }
          // ]
        }
      ]
    }
  }
  tags: tags
}

resource apiWafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2020-08-01' = {
  name: apiFirewallPolicyName
  location: location
  properties: {
    policySettings: {
      mode: 'Prevention'
      state: 'Enabled'
    }
    customRules: [
      {
        name: 'AllowAzureCloudIPs'
        priority: 10
        ruleType: 'MatchRule'
        action: 'Block'
        matchConditions: azureResourceProviderMatchConditions
      }
    ]
    managedRules: {
      managedRuleSets: [
        {
          ruleSetType: 'OWASP'
          ruleSetVersion: '3.1'
          ruleGroupOverrides: []
        }
      ]
    }
  }
  tags: tags
}

resource gw 'Microsoft.Network/applicationGateways@2020-06-01' = {
  name: appGatewayName
  location: location
  dependsOn: [
    accessPolicy
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    sku: {
      name: 'WAF_v2'
      tier: 'WAF_v2'
      capacity: 2
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
          frontendIPConfiguration: gateway.frontendIp.public.ref
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts/', appGatewayName, 'Port443')
          }
          sslCertificate: {
            id: resourceId('Microsoft.Network/applicationGateways/sslCertificates/', appGatewayName, gatewayHost)
          }
          firewallPolicy: {
            id: listenerWafPolicy.id
          }
        }
      }
      {
        name: gateway.httpListener.private.name
        properties: {
          protocol: 'Http'
          frontendIPConfiguration: gateway.frontendIp.private.ref
          frontendPort: {
            id: resourceId('Microsoft.Network/applicationGateways/frontendPorts/', appGatewayName, 'Port80')
          }
          firewallPolicy: {
            id: listenerWafPolicy.id
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
          keyVaultSecretId: sslCertificateSecretUri
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
                firewallPolicy: {
                  id: apiWafPolicy.id
                }
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
                firewallPolicy: {
                  id: apiWafPolicy.id
                }
              }
            }
          ]
          defaultBackendAddressPool: gateway.backendAddressPool.ref
          defaultBackendHttpSettings: gateway.backendHttpSettings.ref
        }
      }
    ]
    firewallPolicy: {
      id: gatewayWafPolicy.id
    }
  }
  tags: tags
}

resource diagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = if (!empty(logAnalyticsWrokspaceId)) {
  name: 'diagnostics'
  scope: gw
  properties: {
    workspaceId: logAnalyticsWrokspaceId
    logs: [
      {
        category: 'ApplicationGatewayAccessLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayPerformanceLog'
        enabled: true
      }
      {
        category: 'ApplicationGatewayFirewallLog'
        enabled: true
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
