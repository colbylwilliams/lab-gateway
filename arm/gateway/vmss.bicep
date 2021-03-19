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
param functionHostName string

param sslCertThumbprint string
@secure()
param sslCertSecretUriWithVersion string

param signCertThumbprint string
@secure()
param signCertSecretUriWithVersion string

param backendAddressPools array

var vmssName = '${resourcePrefix}-vmss'
var vmNamePrefix = take(resourcePrefix, 9)

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
                    loadBalancerBackendAddressPools: backendAddressPools
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
