param utcValue string = utcNow('u')

@description('Admin username on all VMs.')
param adminUsername string

@secure()
@description('Admin password on all VMs.')
param adminPassword string

@description('The TTL of a generated token (default: 00:01:00)')
param tokenLifetime string = '00:01:00'

param hostName string

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

param vnet string = ''
param publicIPAddress string = ''
param privateIPAddress string = ''

param gatewaySubnetName string = 'RDGatewaySubnet'

param skipKeyVaultDeployment bool = false

var resourcePrefix = 'rdg${uniqueString(resourceGroup().id)}'

module kv 'keyvault.bicep' = {
  name: 'keyvault'
  params: {
    resourcePrefix: resourcePrefix
  }
}

resource kv2 'Microsoft.KeyVault/vaults@2019-09-01' existing = if (skipKeyVaultDeployment) {
  name: '${resourcePrefix}-kv'
}

module certs 'certs.bicep' = {
  name: 'certs'
  params: {
    utcValue: utcValue
    hostName: hostName
    keyVaultName: kv.outputs.name
  }
}

module storage 'storage.bicep' = {
  name: 'storage'
  params: {
    accountName: resourcePrefix
  }
}

module functionApp 'function.bicep' = {
  name: 'functionApp'
  params: {
    keyVaultName: kv.outputs.name
    resourcePrefix: resourcePrefix
    tokenLifetime: tokenLifetime
    storageConnectionString: storage.outputs.connectionString
    signCertificateSecretUriWithVersion: certs.outputs.signCertificateSecretUriWithVersion
  }
}

// module functionAppSource 'function_source.bicep' = {
//   name: 'functionAppSource'
//   params: {
//     functionApp: functionApp.outputs.name
//   }
// }

module gwVnet 'vnet.bicep' = {
  name: 'vnet'
  params: {
    vnet: vnet
    resourcePrefix: resourcePrefix
    addressPrefixes: [
      '10.0.0.0/16'
    ]
    gatewaySubnetName: gatewaySubnetName
    gatewaySubnetAddressPrefix: '10.0.0.0/24'
    bastionSubnetAddressPrefix: '10.0.1.0/27'
    appGatewaySubnetAddressPrefix: '10.0.2.0/26'
  }
}

module bastion 'bastion.bicep' = {
  name: 'bastion'
  params: {
    subnet: gwVnet.outputs.bastionSubnet
    resourcePrefix: resourcePrefix
  }
}

// module gw 'agw.bicep' = {
//   name: 'appGateway'
//   params: {
//     resourcePrefix: resourcePrefix
//     apiHost: functionApp.outputs.defaultHostName
//     keyVaultName: kv.outputs.name
//     subnet: gwVnet.outputs.appGatewaySubnet
//     gatewayHost: hostName
//     privateIPAddress: '10.0.2.5' // privateIPAddress
//     sslCertificate: sslCertificate
//     sslCertificatePassword: sslCertificatePassword
//     vmssCertificateSecretUriWithVersion: certs.outputs.sslCertificateSecretUriWithVersion
//   }
// }

module vmss 'vmss.bicep' = {
  name: 'vmss'
  params: {
    resourcePrefix: resourcePrefix
    adminUsername: adminUsername
    adminPassword: adminPassword
    storageAccountName: storage.outputs.accountName
    storageAccountKey: storage.outputs.accountKey
    storageArtifactsEndpoint: storage.outputs.artifactsEndpoint
    subnet: gwVnet.outputs.gatewaySubnet
    keyVault: kv.outputs.id
    keyVaultName: kv.outputs.name
    functionHostName: functionApp.outputs.defaultHostName
    sslCertificateName: certs.outputs.sslCertificateName
    sslCertificateSecretUriWithVersion: certs.outputs.sslCertificateSecretUriWithVersion
    signCertificateName: certs.outputs.signCertificateName
    signCertificateSecretUriWithVersion: certs.outputs.signCertificateSecretUriWithVersion
    applicationGatewayBackendAddressPools: [] // gw.outputs.backendAddressPools
  }
}

module privateEndpointDeployment 'privateEndpoint.bicep' = {
  name: 'privateEndpoint'
  params: {
    resourcePrefix: resourcePrefix
    site: functionApp.outputs.id
    vnet: gwVnet.outputs.id
    subnet: gwVnet.outputs.gatewaySubnet
  }
}

output artifactsStorage object = {
  account: storage.outputs.accountName
  container: storage.outputs.artifactsContainerName
}

output gateway object = {
  scaleSet: vmss.outputs.name
  function: functionApp.outputs.name
  ip: 'foo' // gw.outputs.ip
}
