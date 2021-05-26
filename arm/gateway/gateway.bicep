param resourcePrefix string

param subnet string
param apiHost string
param gatewayHost string

param keyVaultName string

param sslCertificateSecretUri string

param publicIPAddress string = ''
param privateIPAddress string

param logAnalyticsWrokspaceId string = ''

param azureCloudPolicyMatchConditions array

param tags object = {}

var publicIPAddressName = empty(publicIPAddress) ? '${resourcePrefix}-gw-pip' : last(split(publicIPAddress, '/'))

var appGatewayName = '${resourcePrefix}-gw'

var gatewayFirewallPolicyName = '${resourcePrefix}-gw-waf'
var apiFirewallPolicyName = '${resourcePrefix}-gw-waf-api'

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

var dtlRpIpMatchCondition_centralus = {
  operator: 'IPMatch'
  negationConditon: true
  matchVariables: [
    {
      variableName: 'RemoteAddr'
    }
  ]
  // Central US
  matchValues: [
    '13.67.128.0/20'
    '13.67.144.0/21'
    '13.67.152.0/24'
    '13.67.153.0/28'
    '13.67.153.32/27'
    '13.67.153.64/26'
    '13.67.153.128/25'
    '13.67.155.0/24'
    '13.67.156.0/22'
    '13.67.160.0/19'
    '13.67.192.0/18'
    '13.86.0.0/17'
    '13.89.0.0/16'
    '13.104.147.128/25'
    '13.104.219.128/25'
    '13.105.17.192/26'
    '13.105.24.0/24'
    '13.105.37.0/26'
    '13.105.53.192/26'
    '20.37.128.0/18'
    '20.38.96.0/23'
    '20.38.122.0/23'
    '20.40.192.0/18'
    '20.44.8.0/21'
    '20.46.224.0/19'
    '20.47.58.0/23'
    '20.47.78.0/23'
    '20.60.18.0/24'
    '20.60.30.0/23'
    '20.60.178.0/23'
    '20.80.64.0/18'
    '20.83.0.0/18'
    '20.84.128.0/17'
    '20.135.0.0/22'
    '20.135.188.0/22'
    '20.135.192.0/23'
    '20.150.43.128/25'
    '20.150.58.0/24'
    '20.150.63.0/24'
    '20.150.77.0/24'
    '20.150.89.0/24'
    '20.150.95.0/24'
    '20.157.34.0/23'
    '20.184.64.0/18'
    '20.186.192.0/18'
    '20.190.134.0/24'
    '20.190.155.0/24'
    '23.99.128.0/17'
    '23.100.80.0/21'
    '23.100.240.0/20'
    '23.101.112.0/20'
    '23.102.202.0/24'
    '40.67.160.0/19'
    '40.69.128.0/18'
    '40.77.0.0/17'
    '40.77.130.128/26'
    '40.77.137.0/25'
    '40.77.138.0/25'
    '40.77.161.64/26'
    '40.77.166.192/26'
    '40.77.171.0/24'
    '40.77.175.192/27'
    '40.77.175.240/28'
    '40.77.182.16/28'
    '40.77.182.192/26'
    '40.77.184.128/25'
    '40.77.197.0/24'
    '40.77.255.128/26'
    '40.78.128.0/18'
    '40.78.221.0/24'
    '40.82.16.0/22'
    '40.82.96.0/22'
    '40.83.0.0/20'
    '40.83.16.0/21'
    '40.83.24.0/26'
    '40.83.24.64/27'
    '40.83.24.128/25'
    '40.83.25.0/24'
    '40.83.26.0/23'
    '40.83.28.0/22'
    '40.83.32.0/19'
    '40.86.0.0/17'
    '40.87.180.0/30'
    '40.87.180.4/31'
    '40.87.180.14/31'
    '40.87.180.16/30'
    '40.87.180.20/31'
    '40.87.180.28/30'
    '40.87.180.32/29'
    '40.87.180.42/31'
    '40.87.180.44/30'
    '40.87.180.48/28'
    '40.87.180.64/30'
    '40.87.180.74/31'
    '40.87.180.76/30'
    '40.87.182.4/30'
    '40.87.182.8/29'
    '40.87.182.24/29'
    '40.87.182.32/28'
    '40.87.182.48/29'
    '40.87.182.56/30'
    '40.87.182.62/31'
    '40.87.182.64/26'
    '40.87.182.128/25'
    '40.87.183.0/28'
    '40.87.183.16/29'
    '40.87.183.24/30'
    '40.87.183.34/31'
    '40.87.183.36/30'
    '40.87.183.42/31'
    '40.87.183.44/30'
    '40.87.183.54/31'
    '40.87.183.56/29'
    '40.87.183.64/26'
    '40.87.183.144/28'
    '40.87.183.160/27'
    '40.87.183.192/27'
    '40.87.183.224/29'
    '40.87.183.232/30'
    '40.87.183.236/31'
    '40.87.183.244/30'
    '40.87.183.248/29'
    '40.89.224.0/19'
    '40.90.16.0/27'
    '40.90.21.128/25'
    '40.90.22.0/25'
    '40.90.26.128/25'
    '40.90.129.224/27'
    '40.90.130.64/28'
    '40.90.130.192/28'
    '40.90.132.192/26'
    '40.90.137.224/27'
    '40.90.140.96/27'
    '40.90.140.224/27'
    '40.90.141.0/27'
    '40.90.142.128/27'
    '40.90.142.240/28'
    '40.90.144.0/27'
    '40.90.144.128/26'
    '40.90.148.176/28'
    '40.90.149.96/27'
    '40.90.151.144/28'
    '40.90.154.64/26'
    '40.90.156.192/26'
    '40.90.158.64/26'
    '40.93.8.0/24'
    '40.113.192.0/18'
    '40.122.16.0/20'
    '40.122.32.0/19'
    '40.122.64.0/18'
    '40.122.128.0/17'
    '40.126.6.0/24'
    '40.126.27.0/24'
    '52.101.8.0/24'
    '52.101.32.0/22'
    '52.102.130.0/24'
    '52.103.4.0/24'
    '52.103.130.0/24'
    '52.108.165.0/24'
    '52.108.166.0/23'
    '52.108.185.0/24'
    '52.108.208.0/21'
    '52.109.8.0/22'
    '52.111.227.0/24'
    '52.112.113.0/24'
    '52.113.129.0/24'
    '52.114.128.0/22'
    '52.115.76.0/22'
    '52.115.80.0/22'
    '52.115.88.0/22'
    '52.125.128.0/22'
    '52.136.30.0/24'
    '52.141.192.0/19'
    '52.141.240.0/20'
    '52.143.193.0/24'
    '52.143.224.0/19'
    '52.154.0.0/18'
    '52.154.128.0/17'
    '52.158.160.0/20'
    '52.158.192.0/19'
    '52.165.0.0/19'
    '52.165.32.0/20'
    '52.165.48.0/28'
    '52.165.49.0/24'
    '52.165.56.0/21'
    '52.165.64.0/19'
    '52.165.96.0/21'
    '52.165.104.0/25'
    '52.165.128.0/17'
    '52.173.0.0/16'
    '52.176.0.0/17'
    '52.176.128.0/19'
    '52.176.160.0/21'
    '52.176.176.0/20'
    '52.176.192.0/19'
    '52.176.224.0/24'
    '52.180.128.0/19'
    '52.180.184.0/27'
    '52.180.184.32/28'
    '52.180.185.0/24'
    '52.182.128.0/17'
    '52.185.0.0/19'
    '52.185.32.0/20'
    '52.185.48.0/21'
    '52.185.56.0/26'
    '52.185.56.64/27'
    '52.185.56.96/28'
    '52.185.56.128/27'
    '52.185.56.160/28'
    '52.185.64.0/19'
    '52.185.96.0/20'
    '52.185.112.0/26'
    '52.185.112.96/27'
    '52.185.120.0/21'
    '52.189.0.0/17'
    '52.228.128.0/17'
    '52.230.128.0/17'
    '52.232.157.0/24'
    '52.238.192.0/18'
    '52.239.150.0/23'
    '52.239.177.32/27'
    '52.239.177.64/26'
    '52.239.177.128/25'
    '52.239.195.0/24'
    '52.239.234.0/23'
    '52.242.128.0/17'
    '52.245.68.0/24'
    '52.245.69.32/27'
    '52.245.69.64/27'
    '52.245.69.96/28'
    '52.245.69.144/28'
    '52.245.69.160/27'
    '52.245.69.192/26'
    '52.245.70.0/23'
    '52.255.0.0/19'
    '65.55.144.0/23'
    '65.55.146.0/24'
    '104.43.128.0/17'
    '104.44.88.160/27'
    '104.44.91.160/27'
    '104.44.92.224/27'
    '104.44.94.80/28'
    '104.208.0.0/19'
    '104.208.32.0/20'
    '131.253.36.224/27'
    '157.55.108.0/23'
    '168.61.128.0/25'
    '168.61.128.128/28'
    '168.61.128.160/27'
    '168.61.128.192/26'
    '168.61.129.0/25'
    '168.61.129.128/26'
    '168.61.129.208/28'
    '168.61.129.224/27'
    '168.61.130.64/26'
    '168.61.130.128/25'
    '168.61.131.0/26'
    '168.61.131.128/25'
    '168.61.132.0/26'
    '168.61.144.0/20'
    '168.61.160.0/19'
    '168.61.208.0/20'
    '193.149.72.0/21'
    '2603:1030::/45'
    '2603:1030:9:2::/63'
    '2603:1030:9:4::/62'
    '2603:1030:9:8::/61'
    '2603:1030:9:10::/62'
    '2603:1030:9:14::/63'
    '2603:1030:9:17::/64'
    '2603:1030:9:18::/61'
    '2603:1030:9:20::/59'
    '2603:1030:9:40::/58'
    '2603:1030:9:80::/59'
    '2603:1030:9:a0::/60'
    '2603:1030:9:b3::/64'
    '2603:1030:9:b4::/63'
    '2603:1030:9:b7::/64'
    '2603:1030:9:b8::/63'
    '2603:1030:9:bd::/64'
    '2603:1030:9:be::/63'
    '2603:1030:9:c0::/58'
    '2603:1030:9:100::/64'
    '2603:1030:9:104::/62'
    '2603:1030:9:108::/62'
    '2603:1030:9:10c::/64'
    '2603:1030:9:111::/64'
    '2603:1030:9:112::/63'
    '2603:1030:9:114::/64'
    '2603:1030:9:118::/62'
    '2603:1030:9:11c::/63'
    '2603:1030:9:11f::/64'
    '2603:1030:9:120::/61'
    '2603:1030:9:128::/62'
    '2603:1030:9:12f::/64'
    '2603:1030:9:130::/63'
    '2603:1030:a::/47'
    '2603:1030:d::/48'
    '2603:1030:10::/48'
    '2603:1036:2403::/48'
    '2603:1036:2500:1c::/64'
    '2603:1036:3000:100::/59'
    '2603:1037:1:100::/59'
    '2a01:111:f403:c904::/62'
    '2a01:111:f403:d104::/62'
    '2a01:111:f403:d904::/62'
    '2a01:111:f403:e004::/62'
    '2a01:111:f403:f904::/62'
  ]
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
  tags: tags
}

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: appGatewayName
  location: resourceGroup().location
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

resource gatewayWafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2020-08-01' = {
  name: gatewayFirewallPolicyName
  location: resourceGroup().location
  properties: {
    policySettings: {
      mode: 'Prevention'
      state: 'Enabled'
    }
    customRules: [
      {
        name: 'AllowSpecificIPs'
        priority: 10
        ruleType: 'MatchRule'
        action: 'Block'
        matchConditions: [
          {
            operator: 'IPMatch'
            negationConditon: true
            matchVariables: [
              {
                variableName: 'RemoteAddr'
              }
            ]
            matchValues: []
          }
        ]
      }
    ]
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

resource apiWafPolicy 'Microsoft.Network/ApplicationGatewayWebApplicationFirewallPolicies@2020-08-01' = {
  name: apiFirewallPolicyName
  location: resourceGroup().location
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
        matchConditions: azureCloudPolicyMatchConditions
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
  location: resourceGroup().location
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
