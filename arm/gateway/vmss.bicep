param resourcePrefix string

param adminUsername string
@secure()
param adminPassword string

param publicIPAddress string = ''
param privateIPAddress string = ''

param storageAccountName string
@secure()
param storageAccountKey string
param storageArtifactsEndpoint string

param keyVault string
param subnet string
param functionHostName string

param sslCertThumbprint string
@secure()
param sslCertSecretUriWithVersion string

param signCertThumbprint string
@secure()
param signCertSecretUriWithVersion string

var publicIPAddressRg = empty(publicIPAddress) ? '' : first(split(last(split(publicIPAddress, '/resourceGroups/')), '/'))
var publicIPAddressName = empty(publicIPAddress) ? '${resourcePrefix}-pip' : last(split(publicIPAddress, '/'))

var vmNamePrefix = take(resourcePrefix, 9)

var vmssName = '${resourcePrefix}-vmss'
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

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2020-06-01' = {
  name: vmssName
  location: resourceGroup().location
  sku: {
    name: 'Standard_B4ms'
    capacity: 0
  }
  properties: {
    overprovision: true
    singlePlacementGroup: true
    doNotRunExtensionsOnOverprovisionedVMs: false
    upgradePolicy: {
      mode: 'Manual'
    }
    virtualMachineProfile: {
      osProfile: {
        adminUsername: adminUsername
        adminPassword: adminPassword
        computerNamePrefix: vmNamePrefix
        windowsConfiguration: {
          provisionVMAgent: true
          enableAutomaticUpdates: true
        }
        secrets: [
          {
            sourceVault: {
              id: keyVault
            }
            vaultCertificates: [
              {
                certificateUrl: sslCertSecretUriWithVersion
                certificateStore: 'My'
              }
              {
                certificateUrl: signCertSecretUriWithVersion
                certificateStore: 'My'
              }
            ]
          }
        ]
      }
      storageProfile: {
        osDisk: {
          osType: 'Windows'
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: {
            storageAccountType: 'Premium_LRS'
          }
          diskSizeGB: 127
        }
        imageReference: {
          publisher: 'MicrosoftWindowsServer'
          offer: 'WindowsServer'
          sku: '2019-Datacenter'
          version: 'latest'
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic'
            properties: {
              primary: true
              enableAcceleratedNetworking: false
              enableIPForwarding: false
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    privateIPAddressVersion: 'IPv4'
                    subnet: {
                      id: subnet
                    }
                    loadBalancerBackendAddressPools: loadBalancer.properties.backendAddressPools
                  }
                }
              ]
            }
          }
        ]
      }
      extensionProfile: {
        extensions: [
          {
            name: 'Initialize'
            properties: {
              publisher: 'Microsoft.Compute'
              type: 'CustomScriptExtension'
              typeHandlerVersion: '1.8'
              autoUpgradeMinorVersion: true
              settings: {
                fileUris: [
                  '${storageArtifactsEndpoint}/gateway.ps1'
                  '${storageArtifactsEndpoint}/RDGatewayFedAuth.msi'
                ]
                commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -Command "& { $script = gci -Filter gateway.ps1 -Recurse | sort -Descending -Property LastWriteTime | select -First 1 -ExpandProperty FullName; . $script -SslCertificateThumbprint ${sslCertThumbprint} -SignCertificateThumbprint ${signCertThumbprint} -TokenFactoryHostname ${functionHostName} }"'
              }
              protectedSettings: {
                storageAccountName: storageAccountName
                storageAccountKey: storageAccountKey
              }
            }
          }
        ]
      }
    }
  }
}

output name string = vmss.name
output ip string = createPublicIpAddress ? publicIPAddress_new.properties.ipAddress : !empty(publicIPAddress) ? publicIPAddress_existing.properties.ipAddress : privateIPAddress
