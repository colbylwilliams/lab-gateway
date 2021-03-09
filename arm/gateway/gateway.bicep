param utcValue string = utcNow('u')

@description('Admin username on all VMs.')
param adminUsername string

@secure()
@description('Admin password on all VMs.')
param adminPassword string

@description('The TTL of a generated token (default: 00:01:00)')
param tokenLifetime string = '00:01:00'

@minLength(1)
@description('Certificate as Base64 encoded string.')
param sslCertificate string

@secure()
@description('Certificate password for installation.')
param sslCertificatePassword string

@minLength(1)
@description('Certificate thumbprint for identification in the local certificate store.')
param sslCertificateThumbprint string

@description('Certificate as Base64 encoded string.')
param signCertificate string = ''

@secure()
@description('Certificate password for installation.')
param signCertificatePassword string = ''

@description('Certificate thumbprint for identification in the local certificate store.')
param signCertificateThumbprint string = ''

param useVnet string = ''
param useGatewaySubnet string = ''
param useBastionSubnet string = ''

var resourcePrefix = 'rdg${uniqueString(resourceGroup().id)}'
var vmNamePrefix = take(resourcePrefix, 9)
var vmssName = '${resourcePrefix}-vmss'
var storageAccountName = resourcePrefix
var artifactsContainerName = 'artifacts'
var keyVaultName = '${resourcePrefix}-kv'
var hostingPlanName = '${resourcePrefix}-hp'
var functionAppName = '${resourcePrefix}-fa'
var appInsightsName = '${resourcePrefix}-ai'
var SSLCertificateSecretName = 'SSLCertificate'
var SignCertificateSecretName = 'SignCertificate'
var vnetName = '${resourcePrefix}-vnet'
var snetGatewayName = 'RDGatewaySubnet'
var snetBastionName = 'AzureBastionSubnet'
var loadBalancerName = '${resourcePrefix}-lb'
var publicIPAddressName = '${resourcePrefix}-pip'
var loadBalancerBackEndName = 'gatewayBackEnd'
var loadBalancerFrontEndName = 'gatewayFrontEnd'
var bastionHostName = '${resourcePrefix}-bh'
var bastionIPAddressName = '${resourcePrefix}-bh-pip'
var githubBranch = 'main'
var githubRepoUrl = 'https://github.com/colbylwilliams/lab-gateway'
var githubRepoPath = 'api'
var createSignCertificate = (empty(signCertificate) || empty(signCertificatePassword) || empty(signCertificateThumbprint))
var scriptIdentityName = 'createSignCertificateIdentity'
var createSignCertificateScriptUri = 'https://raw.githubusercontent.com/colbylwilliams/lab-gateway/main/tools/create_cert.sh'
var scriptIdentiyRoleAssignmentIdName = guid('${resourceGroup().id}${scriptIdentityName}contributor${utcValue}')
var contributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

resource existingVnet 'Microsoft.Network/virtualNetworks@2020-06-01' existing = if (!empty(useVnet)) {
  name: useVnet
}

resource existingGatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' existing = if (!empty(useGatewaySubnet)) {
  name: useGatewaySubnet
}

resource existingBastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' existing = if (!empty(useBastionSubnet)) {
  name: useBastionSubnet
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: resourceGroup().location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    tenantId: subscription().tenantId
    accessPolicies: []
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

resource sslCertificateSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/${SSLCertificateSecretName}'
  properties: {
    value: base64('{ "data":"${sslCertificate}", "dataType":"pfx", "password":"${sslCertificatePassword}" }')
  }
}

resource signCertificateSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/${SignCertificateSecretName}'
  properties: {
    value: base64('{ "data":"${(createSignCertificate ? createSignCertificateScript.properties.outputs.base64 : signCertificate)}", "dataType":"pfx", "password":"${(createSignCertificate ? createSignCertificateScript.properties.outputs.password : signCertificatePassword)}" }')
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2020-08-01-preview' = {
  name: storageAccountName
  location: resourceGroup().location
  sku: {
    name: 'Standard_RAGRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
}

resource artifactsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2020-08-01-preview' = {
  name: '${storageAccount.name}/default/${artifactsContainerName}'
}

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  kind: 'web'
  name: appInsightsName
  location: resourceGroup().location
  properties: {
    Application_Type: 'web'
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: hostingPlanName
  location: resourceGroup().location
  sku: {
    tier: 'ElasticPremium'
    name: 'EP1'
  }
}

resource functionApp 'Microsoft.Web/sites@2020-06-01' = {
  kind: 'functionapp'
  name: functionAppName
  location: resourceGroup().location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsDashboard'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: functionAppName
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'AZURE_FUNCTIONS_ENVIRONMENT'
          value: 'Production'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'Project'
          value: githubRepoPath
        }
        {
          name: 'SignCertificate'
          value: '@Microsoft.KeyVault(SecretUri=${signCertificateSecret.properties.secretUriWithVersion})'
        }
        {
          name: 'TokenLifetime'
          value: tokenLifetime
        }
      ]
    }
  }
}

resource functionAppSourceControl 'Microsoft.Web/sites/sourcecontrols@2020-06-01' = {
  name: '${functionApp.name}/web'
  properties: {
    repoUrl: githubRepoUrl
    branch: githubBranch
    isManualIntegration: true
  }
}

resource functionAppKeyVaultPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2019-09-01' = {
  name: any('${keyVault.name}/add')
  properties: {
    accessPolicies: [
      {
        tenantId: functionApp.identity.tenantId
        objectId: functionApp.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
  }
}

resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if (createSignCertificate) {
  name: scriptIdentityName
  location: resourceGroup().location
}

resource scriptIdentityRoleAssignmentId 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (createSignCertificate) {
  name: scriptIdentiyRoleAssignmentIdName
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: createSignCertificate ? scriptIdentity.properties.principalId : json('null')
    principalType: 'ServicePrincipal'
  }
}

module scriptIdentityAccessPolicy 'signCertPolicy.bicep' = if (createSignCertificate) {
  name: 'scriptIdentityAccessPolicy'
  params: {
    keyVaultName: keyVault.name
    tenantId: createSignCertificate ? scriptIdentity.properties.tenantId : json('null')
    principalId: createSignCertificate ? scriptIdentity.properties.principalId : json('null')
  }
}

resource createSignCertificateScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (createSignCertificate) {
  kind: 'AzureCLI'
  name: 'createSignCertificateScript'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.18.0'
    timeout: 'PT1H'
    arguments: '-v ${keyVault.name}'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
    primaryScriptUri: createSignCertificateScriptUri
  }
  dependsOn: [
    scriptIdentityRoleAssignmentId
    scriptIdentityAccessPolicy
  ]
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-06-01' = if (empty(useVnet)) {
  name: vnetName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource gatewaySubnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = if (empty(useGatewaySubnet)) {
  name: '${empty(useVnet) ? vnet.name : existingVnet.name}/${snetGatewayName}'
  properties: {
    addressPrefix: '10.0.0.0/24'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource bastionSubnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = if (empty(useBastionSubnet)) {
  name: '${empty(useVnet) ? vnet.name : existingVnet.name}/${snetBastionName}'
  properties: {
    addressPrefix: '10.0.1.0/27'
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2020-06-01' = {
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
            id: empty(useBastionSubnet) ? bastionSubnet.id : existingBastionSubnet.id
          }
          publicIPAddress: {
            id: bastionIPAddress.id
          }
        }
      }
    ]
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2020-06-01' = {
  name: loadBalancerName
  location: resourceGroup().location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        name: loadBalancerFrontEndName
        properties: {
          publicIPAddress: {
            id: publicIPAddress.id
          }
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
        }
      }
    ]
    backendAddressPools: [
      {
        name: loadBalancerBackEndName
      }
    ]
    loadBalancingRules: [
      {
        name: 'TCP80'
        properties: {
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations/', loadBalancerName, loadBalancerFrontEndName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, loadBalancerBackEndName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'HealthCheck')
          }
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
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations/', loadBalancerName, loadBalancerFrontEndName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, loadBalancerBackEndName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'Probe443')
          }
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
          frontendIPConfiguration: {
            id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations/', loadBalancerName, loadBalancerFrontEndName)
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, loadBalancerBackEndName)
          }
          probe: {
            id: resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, 'Probe3391')
          }
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
    probes: [
      {
        name: 'HealthCheck'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/api/health'
          intervalInSeconds: 300
          numberOfProbes: 2
        }
      }
      {
        name: 'Probe443'
        properties: {
          protocol: 'Tcp'
          port: 443
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
      {
        name: 'Probe3391'
        properties: {
          protocol: 'Tcp'
          port: 3391
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
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
              id: keyVault.id
            }
            vaultCertificates: [
              {
                certificateUrl: sslCertificateSecret.properties.secretUriWithVersion
                certificateStore: 'My'
              }
              {
                certificateUrl: signCertificateSecret.properties.secretUriWithVersion
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
                      id: empty(useGatewaySubnet) ? gatewaySubnet.id : existingGatewaySubnet.id
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
                  '${storageAccount.properties.primaryEndpoints.blob}${artifactsContainerName}/gateway.ps1'
                  '${storageAccount.properties.primaryEndpoints.blob}${artifactsContainerName}/RDGatewayFedAuth.msi'
                ]
                commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -Command "& { $script = gci -Filter gateway.ps1 -Recurse | sort -Descending -Property LastWriteTime | select -First 1 -ExpandProperty FullName; . $script -SslCertificateThumbprint ${sslCertificateThumbprint} -SignCertificateThumbprint ${(createSignCertificate ? createSignCertificateScript.properties.outputs.thumbprint : signCertificateThumbprint)} -TokenFactoryHostname ${functionApp.properties.defaultHostName} }"'
              }
              protectedSettings: {
                storageAccountName: storageAccount.name
                storageAccountKey: listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
              }
            }
          }
        ]
      }
    }
  }
}

// module privateEndpointDeployment 'privateEndpoint.bicep' = {
//   name: 'privateEndpoint'
//   params: {
//     resourcePrefix: resourcePrefix
//     site: functionApp.id
//     vnet: empty(useVnet) ? vnet.id : existingVnet.id
//     subnet: empty(useGatewaySubnet) ? gatewaySubnet.id : existingGatewaySubnet.id
//   }
// }

output artifactsStorage object = {
  account: storageAccount.name
  container: artifactsContainerName
}

output gateway object = {
  scaleSet: vmss.name
  function: functionApp.name
  ip: publicIPAddress.properties.ipAddress
  fqdn: publicIPAddress.properties.dnsSettings.fqdn
}
