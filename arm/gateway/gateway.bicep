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

param vnet string = ''
param publicIPAddress string = ''
param privateIPAddress string = ''

param gatewaySubnetName string = 'RDGatewaySubnet'
param bastionSubnetName string = 'AzureBastionSubnet'

var resourcePrefix = 'rdg${uniqueString(resourceGroup().id)}'

module kv 'keyvault.bicep' = {
  name: 'keyvault'
  params: {
    resourcePrefix: resourcePrefix
  }
}

module sslCert 'sslCert.bicep' = {
  name: 'sslCert'
  params: {
    keyVaultName: kv.outputs.name
    certificate: sslCertificate
    certificatePassword: sslCertificatePassword
    certificateThumbprint: sslCertificateThumbprint
  }
}

module signCert 'signCert.bicep' = {
  name: 'signCert'
  params: {
    keyVaultName: kv.outputs.name
    certificate: signCertificate
    certificatePassword: signCertificatePassword
    certificateThumbprint: signCertificateThumbprint
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
    signCertSecretUriWithVersion: signCert.outputs.secretUriWithVersion
  }
}

module functionAppSource 'function_source.bicep' = {
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
    bastionSubnetName: bastionSubnetName
    bastionSubnetAddressPrefix: '10.0.1.0/27'
  }
}

module bastion 'bastion.bicep' = {
  name: 'bastion'
  params: {
    subnet: gwVnet.outputs.bastionSubnet
    resourcePrefix: resourcePrefix
  }
}

module vmss 'vmss.bicep' = {
  name: 'vmss'
  params: {
    resourcePrefix: resourcePrefix
    adminUsername: adminUsername
    adminPassword: adminPassword
    publicIPAddress: publicIPAddress
    privateIPAddress: privateIPAddress
    storageAccountName: storage.outputs.accountName
    storageAccountKey: storage.outputs.accountKey
    storageArtifactsEndpoint: storage.outputs.artifactsEndpoint
    keyVault: kv.outputs.id
    subnet: gwVnet.outputs.gatewaySubnet
    functionHostName: functionApp.outputs.defaultHostName
    sslCertThumbprint: sslCert.outputs.thumbprint
    sslCertSecretUriWithVersion: sslCert.outputs.secretUriWithVersion
    signCertThumbprint: signCert.outputs.thumbprint
    signCertSecretUriWithVersion: signCert.outputs.secretUriWithVersion
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
  ip: vmss.outputs.ip
}
