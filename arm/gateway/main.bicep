param utcValue string = utcNow('u')

@description('Admin username on all VMs.')
param adminUsername string

@secure()
@description('Admin password on all VMs.')
param adminPassword string

@description('The TTL of a generated token (default: 00:01:00)')
param tokenLifetime string = '00:01:00'

param hostName string

// @minLength(1)
// @description('Certificate as Base64 encoded string.')
// param sslCertificate string

param sslCertificateName string = 'SSLCertificate'
param signCertificateName string = '' // = 'SignCertificate'

// @secure()
// @description('Certificate password for installation.')
// param sslCertificatePassword string

// @minLength(1)
// @description('Certificate thumbprint for identification in the local certificate store.')
// param sslCertificateThumbprint string

// @description('Certificate as Base64 encoded string.')
// param signCertificate string = ''

// @secure()
// @description('Certificate password for installation.')
// param signCertificatePassword string = ''

// @description('Certificate thumbprint for identification in the local certificate store.')
// param signCertificateThumbprint string = ''

param vnet string = ''
param publicIPAddress string = ''
param privateIPAddress string = '10.0.2.5'

param gatewaySubnetName string = 'RDGatewaySubnet'

var resourcePrefix = 'rdg${uniqueString(resourceGroup().id)}'

var keyVaultName = '${resourcePrefix}-kv'

var sslCertificateSecretUri = 'https://${keyVaultName}.vault.azure.net/secrets/${sslCertificateName}'
var signCertificateSecretUri = 'https://${keyVaultName}.vault.azure.net/secrets/${signCertificateName}'

module kv 'keyvault.bicep' = {
  name: 'keyvault'
  params: {
    resourcePrefix: resourcePrefix
  }
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
    signCertificateSecretUri: certs.outputs.signCertificateSecretUri
  }
}

module functionAppSource 'functionSource.bicep' = {
  name: 'functionAppSource'
  params: {
    functionApp: functionApp.outputs.name
  }
}

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

module gw 'gateway.bicep' = {
  name: 'appGateway'
  params: {
    resourcePrefix: resourcePrefix
    apiHost: functionApp.outputs.defaultHostName
    keyVaultName: kv.outputs.name
    subnet: gwVnet.outputs.appGatewaySubnet
    gatewayHost: hostName
    privateIPAddress: '10.0.2.5' // privateIPAddress
    // sslCertificate: sslCertificate
    // sslCertificatePassword: sslCertificatePassword
    sslCertificateSecretUri: sslCertificateSecretUri //certs.outputs.sslCertificateSecretUri
  }
}

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
    // sslCertificateName: sslCertificateName // certs.outputs.sslCertificateName
    sslCertificateSecretUri: sslCertificateSecretUri // certs.outputs.sslCertificateSecretUri
    // signCertificateName: certs.outputs.signCertificateName
    signCertificateSecretUri: certs.outputs.signCertificateSecretUri
    applicationGatewayBackendAddressPools: gw.outputs.backendAddressPools
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
  ip: gw.outputs.ip
}
