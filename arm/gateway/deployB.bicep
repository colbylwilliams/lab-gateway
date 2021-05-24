param utcValue string = utcNow('u')

param resourcePrefix string = 'rdg${uniqueString(resourceGroup().id)}'

@description('Admin username on all VMs.')
param adminUsername string

@secure()
@description('Admin password on all VMs.')
param adminPassword string

@description('The TTL of a generated token (default: 00:01:00)')
param tokenLifetime string = '00:01:00'

param hostName string

param sslCertificateSecretUri string

param vnet string = ''
param publicIPAddress string = ''

param tokenPrivateEndpoint bool = true

param instanceCount int

// only used if an existing VNet is NOT provided
param vnetAddressPrefixs array

// If an existing VNet is provided, the following subnets must exist
// update the address prefixes with the prefixes used in the subnets

param gatewaySubnetName string
param gatewaySubnetAddressPrefix string

param bastionSubnetAddressPrefix string // MUST be at least /27 or larger

param appGatewaySubnetName string
param appGatewaySubnetAddressPrefix string // MUST be at least /26 or larger

// param firewallSubnetName string = 'AzureFirewallSubnet'
// param firewallSubnetAddressPrefix string = '10.0.3.0/26'

@description('MUST be within appGatewaySubnetAddressPrefix and cannot end in .0 - .4 (reserved)')
param privateIPAddress string

param tags object = {}

module logWorkspace 'logAnalytics.bicep' = {
  name: 'logWorkspace'
  params: {
    resourcePrefix: resourcePrefix
    tags: tags
  }
}

module kv 'keyvault.bicep' = {
  name: 'keyvault'
  params: {
    resourcePrefix: resourcePrefix
    logAnalyticsWrokspaceId: logWorkspace.outputs.id
    tags: tags
  }
}

module certs 'certs.bicep' = {
  name: 'certs'
  params: {
    utcValue: utcValue
    hostName: hostName
    keyVaultName: kv.outputs.name
    tags: tags
  }
}

module storage 'storage.bicep' = {
  name: 'storage'
  params: {
    accountName: resourcePrefix
    tags: tags
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
    logAnalyticsWrokspaceId: logWorkspace.outputs.id
    tags: tags
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
    addressPrefixes: vnetAddressPrefixs
    gatewaySubnetName: gatewaySubnetName
    gatewaySubnetAddressPrefix: gatewaySubnetAddressPrefix
    bastionSubnetAddressPrefix: bastionSubnetAddressPrefix
    appGatewaySubnetName: appGatewaySubnetName
    appGatewaySubnetAddressPrefix: appGatewaySubnetAddressPrefix
    // firewallSubnetName: firewallSubnetName
    // firewallSubnetAddressPrefix: firewallSubnetAddressPrefix
    tags: tags
  }
}

module bastion 'bastion.bicep' = {
  name: 'bastion'
  params: {
    subnet: gwVnet.outputs.bastionSubnet
    resourcePrefix: resourcePrefix
    tags: tags
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
    privateIPAddress: privateIPAddress
    publicIPAddress: publicIPAddress
    sslCertificateSecretUri: sslCertificateSecretUri
    logAnalyticsWrokspaceId: logWorkspace.outputs.id
    tags: tags
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
    keyVaultName: kv.outputs.name
    instanceCount: instanceCount
    functionHostName: functionApp.outputs.defaultHostName
    sslCertificateSecretUri: sslCertificateSecretUri
    signCertificateSecretUri: certs.outputs.signCertificateSecretUri
    applicationGatewayBackendAddressPools: gw.outputs.backendAddressPools
    tags: tags
  }
}

module privateEndpointDeployment 'privateEndpoint.bicep' = if (tokenPrivateEndpoint) {
  name: 'privateEndpoint'
  params: {
    resourcePrefix: resourcePrefix
    site: functionApp.outputs.id
    vnet: gwVnet.outputs.id
    subnet: gwVnet.outputs.gatewaySubnet
    tags: tags
  }
}

output vnetId string = gwVnet.outputs.id
output scaleSetName string = vmss.outputs.name
output functionName string = functionApp.outputs.name
output publicIpAddress string = gw.outputs.ip
