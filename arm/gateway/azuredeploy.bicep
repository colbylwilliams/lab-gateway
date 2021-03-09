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
param utcValue string = utcNow('u')

var resourcePrefix = 'rdg${uniqueString(resourceGroup().id)}'
var vmNamePrefix = take(resourcePrefix, 9)
var vmssName = '${resourcePrefix}-vmss'
var storageAccountName_var = resourcePrefix
var artifactsContainerName = 'artifacts'
var keyVaultName = '${resourcePrefix}-kv'
var hostingPlanName = '${resourcePrefix}-hp'
var functionAppName = '${resourcePrefix}-fa'
var appInsightsName = '${resourcePrefix}-ai'
var keyVaultSecretSSLCertificate = 'SSLCertificate'
var keyVaultSecretSignCertificate = 'SignCertificate'
var vnetName = '${resourcePrefix}-vnet'
var snetGatewayName = 'RDGateway'
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
var createSignCertificateIdentity_var = 'createSignCertificateIdentity'
var createSignCertificateScriptUri = 'https://raw.githubusercontent.com/colbylwilliams/lab-gateway/main/tools/create_cert.sh'
var createSignCertificateRoleAssignmentId_var = guid('${resourceGroup().id}${createSignCertificateIdentity_var}contributor${utcValue}')
var contributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: keyVaultName
  location: resourceGroup().location
  properties: {
    enabledForDeployment: true
    enabledForTemplateDeployment: false
    enabledForDiskEncryption: false
    // enabledForVolumeEncryption: false
    tenantId: subscription().tenantId
    sku: {
      name: 'standard'
      family: 'A'
    }
    accessPolicies: []
  }
  dependsOn: [
    createSignCertificateIdentity
  ]
}

resource keyVault_keyVaultSecretSSLCertificate 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/${keyVaultSecretSSLCertificate}'
  properties: {
    value: base64('{ "data":"${sslCertificate}", "dataType":"pfx", "password":"${sslCertificatePassword}" }')
  }
}

resource keyVault_keyVaultSecretSignCertificate 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVault.name}/${keyVaultSecretSignCertificate}'
  properties: {
    value: base64('{ "data":"${(createSignCertificate ? reference('createSignCertificateScript').outputs.base64 : signCertificate)}", "dataType":"pfx", "password":"${(createSignCertificate ? reference('createSignCertificateScript').outputs.password : signCertificatePassword)}" }')
  }
  dependsOn: [
    createSignCertificateScript
  ]
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2020-08-01-preview' = {
  name: storageAccountName_var
  location: resourceGroup().location
  sku: {
    name: 'Standard_RAGRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
}

resource storageAccountName_default_artifactsContainerName 'Microsoft.Storage/storageAccounts/blobServices/containers@2020-08-01-preview' = {
  name: '${storageAccountName_var}/default/${artifactsContainerName}'
  dependsOn: [
    storageAccount
  ]
}

resource appInsights 'microsoft.insights/components@2015-05-01' = {
  kind: 'web'
  name: appInsightsName
  location: resourceGroup().location
  properties: {
    Application_Type: 'web'
    // ApplicationId: appInsightsName_var
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2018-02-01' = {
  name: hostingPlanName
  location: resourceGroup().location
  sku: {
    tier: 'ElasticPremium'
    name: 'EP1'
  }
  properties: {
    // name: hostingPlanName_var
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
      // minimumElasticInstanceCount: 1
      // functionsRuntimeScaleMonitoringEnabled: true
      appSettings: [
        {
          name: 'AzureWebJobsDashboard'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName_var};AccountKey=${listKeys(storageAccount.id, '2015-05-01-preview').key1}'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName_var};AccountKey=${listKeys(storageAccount.id, '2015-05-01-preview').key1}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName_var};AccountKey=${listKeys(storageAccount.id, '2015-05-01-preview').key1}'
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
          value: '@Microsoft.KeyVault(SecretUri=${keyVault_keyVaultSecretSignCertificate.properties.secretUriWithVersion})'
        }
        {
          name: 'TokenLifetime'
          value: tokenLifetime
        }
      ]
    }
  }
  dependsOn: [
    createSignCertificateScript

    vnet
  ]
}

resource functionAppSourceControl 'Microsoft.Web/sites/sourcecontrols@2020-06-01' = {
  name: '${functionApp.name}/web'
  properties: {
    repoUrl: githubRepoUrl
    branch: githubBranch
    isManualIntegration: true
  }
}

resource keyVault_add 'Microsoft.KeyVault/vaults/accessPolicies@2019-09-01' = {
  name: '${keyVault.name}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: reference(functionApp.id, '2020-09-01', 'Full').identity.tenantId
        objectId: reference(functionApp.id, '2020-09-01', 'Full').identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
  }
}

resource createSignCertificateIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if (createSignCertificate) {
  name: createSignCertificateIdentity_var
  location: resourceGroup().location
}

resource createSignCertificateRoleAssignmentId 'Microsoft.Authorization/roleAssignments@2018-09-01-preview' = if (createSignCertificate) {
  name: createSignCertificateRoleAssignmentId_var
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: (createSignCertificate ? reference(createSignCertificateIdentity_var, '2018-11-30').principalId : json('null'))
    scope: resourceGroup().id
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    createSignCertificateIdentity
  ]
}

module createSignCertificateIdentityAccessPolicyDeployment './createSignCertificateIdentityAccessPolicyDeployment.bicep' = if (createSignCertificate) {
  name: 'createSignCertificateIdentityAccessPolicyDeployment'
  params: {
    createSignCertificate: createSignCertificate
    keyVaultName: keyVaultName
    createSignCertificateIdentityTenantId: (createSignCertificate ? reference(createSignCertificateIdentity_var, '2018-11-30').tenantId : json('null'))
    createSignCertificateIdentityPrincipalId: (createSignCertificate ? reference(createSignCertificateIdentity_var, '2018-11-30').principalId : json('null'))
  }
  dependsOn: [
    createSignCertificateIdentity
    keyVault
  ]
}

resource createSignCertificateScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (createSignCertificate) {
  kind: 'AzureCLI'
  name: 'createSignCertificateScript'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${createSignCertificateIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.18.0'
    timeout: 'PT1H'
    arguments: '-v ${keyVaultName}'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
    primaryScriptUri: createSignCertificateScriptUri
  }
  dependsOn: [
    createSignCertificateRoleAssignmentId
    createSignCertificateIdentityAccessPolicyDeployment
    keyVault
  ]
}

resource vnet 'Microsoft.Network/virtualNetworks@2020-05-01' = {
  name: vnetName
  location: resourceGroup().location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: snetGatewayName
        properties: {
          addressPrefix: '10.0.0.0/24'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
      {
        name: snetBastionName
        properties: {
          addressPrefix: '10.0.1.0/27'
          delegations: []
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
        }
      }
    ]
    virtualNetworkPeerings: []
    enableDdosProtection: false
    enableVmProtection: false
  }
}

resource publicIPAddress 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
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
      domainNameLabel: toLower(resourcePrefix)
    }
  }
}

resource bastionIPAddress 'Microsoft.Network/publicIPAddresses@2020-05-01' = {
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
      domainNameLabel: '${toLower(resourcePrefix)}-admin'
    }
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2020-07-01' = {
  name: bastionHostName
  location: resourceGroup().location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, snetBastionName)
          }
          publicIPAddress: {
            id: bastionIPAddress.id
          }
        }
      }
    ]
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2020-05-01' = {
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
        properties: {}
      }
    ]
    loadBalancingRules: [
      {
        name: 'TCP80'
        properties: {
          frontendIPConfiguration: {
            id: '${loadBalancer.id}/frontendIPConfigurations/${loadBalancerFrontEndName}'
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, loadBalancerBackEndName)
          }
          probe: {
            id: '${loadBalancer.id}/probes/HealthCheck'
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
            id: '${loadBalancer.id}/frontendIPConfigurations/${loadBalancerFrontEndName}'
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, loadBalancerBackEndName)
          }
          probe: {
            id: '${loadBalancer.id}/probes/Probe443'
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
            id: '${loadBalancer.id}/frontendIPConfigurations/${loadBalancerFrontEndName}'
          }
          backendAddressPool: {
            id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, loadBalancerBackEndName)
          }
          probe: {
            id: '${loadBalancer.id}/probes/Probe3391'
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

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2019-07-01' = {
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
                certificateUrl: keyVault_keyVaultSecretSSLCertificate.properties.secretUriWithVersion
                certificateStore: 'My'
              }
              {
                certificateUrl: keyVault_keyVaultSecretSignCertificate.properties.secretUriWithVersion
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
              dnsSettings: {
                dnsServers: []
              }
              enableIPForwarding: false
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    privateIPAddressVersion: 'IPv4'
                    subnet: {
                      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, snetGatewayName)
                    }
                    loadBalancerBackendAddressPools: [
                      {
                        id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, loadBalancerBackEndName)
                      }
                    ]
                    loadBalancerInboundNatPools: []
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
                  '${reference(storageAccount.id, '2017-10-01').primaryEndpoints.blob}${artifactsContainerName}/gateway.ps1'
                  '${reference(storageAccount.id, '2017-10-01').primaryEndpoints.blob}${artifactsContainerName}/RDGatewayFedAuth.msi'
                ]
                commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -Command "& { $script = gci -Filter gateway.ps1 -Recurse | sort -Descending -Property LastWriteTime | select -First 1 -ExpandProperty FullName; . $script -SslCertificateThumbprint ${sslCertificateThumbprint} -SignCertificateThumbprint ${(createSignCertificate ? reference('createSignCertificateScript').outputs.thumbprint : signCertificateThumbprint)} -TokenFactoryHostname ${reference(functionApp.id, '2018-02-01').defaultHostName} }"'
              }
              protectedSettings: {
                storageAccountName: storageAccountName_var
                storageAccountKey: listKeys(storageAccount.id, '2019-04-01').keys[0].value
              }
            }
          }
        ]
      }
    }
  }
  dependsOn: [
    createSignCertificateScript
    vnet
    loadBalancer
  ]
}

module privateEndpointDeployment './privateEndpointDeployment.bicep' = {
  name: 'privateEndpointDeployment'
  params: {
    resourcePrefix: resourcePrefix
    site: functionApp.id
    vnet: vnet.id
    subnet: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, snetGatewayName)
  }
  dependsOn: [
    publicIPAddress
    loadBalancer
  ]
}

output artifactsStorage object = {
  account: storageAccountName_var
  container: artifactsContainerName
}

output gateway object = {
  scaleSet: vmssName
  function: functionAppName
  ip: reference(publicIPAddress.id, '2017-04-01').ipAddress
  fqdn: reference(publicIPAddress.id, '2017-04-01').dnsSettings.fqdn
}
