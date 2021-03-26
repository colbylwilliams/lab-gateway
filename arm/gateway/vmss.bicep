param resourcePrefix string

param adminUsername string
@secure()
param adminPassword string

param storageAccountName string
@secure()
param storageAccountKey string
param storageArtifactsEndpoint string

param subnet string
param keyVault string
param keyVaultName string
param functionHostName string

param sslCertificateSecretUri string
param signCertificateSecretUri string

param loadBalancerBackendAddressPools array = []
param applicationGatewayBackendAddressPools array = []

var vmssName = '${resourcePrefix}-vmss'
var vmNamePrefix = take(resourcePrefix, 9)

var sslCertificateName = last(split(sslCertificateSecretUri, '/'))
var signCertificateName = last(split(signCertificateSecretUri, '/'))

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: vmssName
  location: resourceGroup().location
}

module accessPolicy 'vmssPolicy.bicep' = {
  name: 'vmssIdentityAccessPolicy'
  params: {
    keyVaultName: keyVaultName
    tenantId: identity.properties.tenantId
    principalId: identity.properties.principalId
  }
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2020-06-01' = {
  name: vmssName
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
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
                    loadBalancerBackendAddressPools: loadBalancerBackendAddressPools
                    applicationGatewayBackendAddressPools: applicationGatewayBackendAddressPools
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
                  '${storageArtifactsEndpoint}/IIS-AutoCertRebind.xml'
                ]
                commandToExecute: 'powershell.exe -ExecutionPolicy Unrestricted -Command "& { $script = gci -Filter gateway.ps1 -Recurse | sort -Descending -Property LastWriteTime | select -First 1 -ExpandProperty FullName; . $script -KeyVaultName ${keyVaultName} -SslCertificateName ${sslCertificateName} -SignCertificateName ${signCertificateName} -TokenFactoryHostname ${functionHostName} }"'
              }
              protectedSettings: {
                storageAccountName: storageAccountName
                storageAccountKey: storageAccountKey
              }
              provisionAfterExtensions: [
                'KeyVault'
              ]
            }
          }
          {
            name: 'KeyVault'
            properties: {
              publisher: 'Microsoft.Azure.KeyVault'
              type: 'KeyVaultForWindows'
              typeHandlerVersion: '1.0'
              autoUpgradeMinorVersion: true
              settings: {
                secretsManagementSettings: {
                  linkOnRenewal: true
                  requireInitialSync: true
                  pollingIntervalInS: '3600'
                  certificateStoreName: 'My'
                  certificateStoreLocation: 'LocalMachine'
                  observedCertificates: [
                    sslCertificateSecretUri
                    signCertificateSecretUri
                  ]
                }
              }
            }
          }
        ]
      }
    }
  }
}

output name string = vmss.name
