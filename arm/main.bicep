targetScope = 'subscription'

param name string = 'network'
param location string = deployment().location

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

param gatewaySubnetName string = 'RDGatewaySubnet'
param bastionSubnetName string = 'AzureBastionSubnet'

// var resourcePrefix = 'rdg${uniqueString(resourceGroup().id)}'

param hub object = {
  name: 'vnet-hub'
  addressPrefix: '10.0.0.0/20'
}

param spoke1 object = {
  name: 'vnet-spoke-one'
  addressPrefix: '10.100.0.0/16'
  subnetName: 'snet-spoke-resources'
  subnetPrefix: '10.100.0.0/16'
  subnetNsgName: 'nsg-spoke-one-resources'
}

param spoke2 object = {
  name: 'vnet-spoke-two'
  addressPrefix: '10.200.0.0/16'
  subnetName: 'snet-spoke-resources'
  subnetPrefix: '10.200.0.0/16'
  subnetNsgName: 'nsg-spoke-two-resources'
}

var gatewaySubnets = [
  {
    name: gatewaySubnetName
    properties: {
      addressPrefix: '10.0.0.0/24'
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
  {
    name: bastionSubnetName
    properties: {
      addressPrefix: '10.0.1.0/27'
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
]

resource hbrg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${name}-hub'
  location: location
}

resource spk1rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${name}-spoke-one'
  location: location
}

resource spk2rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${name}-spoke-two'
  location: location
}

module hb 'network/hub.bicep' = {
  name: hub.name
  scope: hbrg
  params: {
    name: hub.name
    addressPrefix: hub.addressPrefix
    otherSubnets: gatewaySubnets
  }
}

module spk1 'network/spoke.bicep' = {
  name: spoke1.name
  scope: spk1rg
  params: {
    name: spoke1.name
    addressPrefix: spoke1.addressPrefix
    subnetName: spoke1.subnetName
    subnetPrefix: spoke1.subnetPrefix
    subnetNsgName: spoke1.subnetNsgName
    routeTableId: hb.outputs.routeTableId
  }
}

module spk2 'network/spoke.bicep' = {
  name: spoke2.name
  scope: spk2rg
  params: {
    name: spoke2.name
    addressPrefix: spoke2.addressPrefix
    subnetName: spoke2.subnetName
    subnetPrefix: spoke2.subnetPrefix
    subnetNsgName: spoke2.subnetNsgName
    routeTableId: hb.outputs.routeTableId
  }
}

module peerHubToSpoke1 'network/peer.bicep' = {
  name: 'peerHubToSpoke1'
  scope: spk1rg
  params: {
    vnetId: spk1.outputs.vnetId
    toVnetId: hb.outputs.vnetId
  }
}

module peerSpoke1ToHub 'network/peer.bicep' = {
  name: 'peerSpoke1ToHub'
  scope: hbrg
  params: {
    vnetId: hb.outputs.vnetId
    toVnetId: spk1.outputs.vnetId
  }
}

module peerHubToSpoke2 'network/peer.bicep' = {
  name: 'peerHubToSpoke2'
  scope: spk2rg
  params: {
    vnetId: spk2.outputs.vnetId
    toVnetId: hb.outputs.vnetId
  }
}

module peerSpoke2ToHub 'network/peer.bicep' = {
  name: 'peerSpoke2ToHub'
  scope: hbrg
  params: {
    vnetId: hb.outputs.vnetId
    toVnetId: spk2.outputs.vnetId
  }
}

module lab1 'lab/lab.bicep' = {
  name: 'spoke-one-lab'
  scope: spk1rg
  params: {
    name: 'Spoke1Lab'
    vnetId: spk1.outputs.vnetId
    subnetId: spk1.outputs.subnetId
  }
}

module lab2 'lab/lab.bicep' = {
  name: 'spoke-two-lab'
  scope: spk2rg
  params: {
    name: 'Spoke2Lab'
    vnetId: spk2.outputs.vnetId
    subnetId: spk2.outputs.subnetId
  }
}

module gateway 'gateway/gateway.bicep' = {
  name: 'gateway'
  scope: hbrg
  params: {
    adminPassword: adminPassword
    adminUsername: adminUsername
    gatewaySubnetName: gatewaySubnetName
    signCertificate: signCertificate
    signCertificatePassword: signCertificatePassword
    signCertificateThumbprint: signCertificateThumbprint
    sslCertificate: sslCertificate
    sslCertificatePassword: sslCertificatePassword
    sslCertificateThumbprint: sslCertificateThumbprint
    tokenLifetime: tokenLifetime
    utcValue: utcValue
    vnet: hb.outputs.vnetId
    privateIPAddress: '10.0.0.4'
  }
}

output artifactsStorage object = {
  account: gateway.outputs.artifactsStorage.account
  container: gateway.outputs.artifactsStorage.container
}

output gateway object = {
  scaleSet: gateway.outputs.gateway.scaleSet
  function: gateway.outputs.gateway.function
  ip: gateway.outputs.gateway.ip
}

output rg string = hbrg.name

output lab1 object = {
  name: lab1.outputs.name
  group: spk1rg.name
}

output lab2 object = {
  name: lab2.outputs.name
  group: spk2rg.name
}

// module lab1b 'lab/lab.bicep' = {
//   name: 'spoke-one-lab-secrets'
//   scope: spk1rg
//   params: {
//     name: 'Spoke1Lab'
//     gatewayHostname: gateway.outputs.gateway.fqdn
//     gatewayToken:
//   }
// }

// module lab2b 'lab/lab.bicep' = {
//   name: 'spoke-two-lab-secrets'
//   scope: spk2rg
//   params: {
//     name: 'Spoke2Lab'
//   }
// }
