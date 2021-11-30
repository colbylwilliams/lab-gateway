targetScope = 'subscription'

param name string = 'network'
param location string = deployment().location

param hostName string

param utcValue string = utcNow('u')

@description('Admin username on all VMs.')
param adminUsername string

@secure()
@description('Admin password on all VMs.')
param adminPassword string

@description('The TTL of a generated token (default: 00:01:00)')
param tokenLifetime string = '00:01:00'

param sslCertificateName string = 'SSLCertificate'

// ====================
// Manual variables

param tags object = {}

// only used if an existing VNet is NOT provided
param vnetName string = 'vnet-hub'
param vnetAddressPrefixes array = [
  '10.0.0.0/16'
]

// If an existing VNet is provided, the following subnets must exist
// update the address prefixes with the prefixes used in the subnets

param gatewaySubnetName string = 'RDGatewaySubnet'
param gatewaySubnetAddressPrefix string = '10.0.0.0/24'

param bastionSubnetName string = 'AzureBastionSubnet' // MUST be AzureBastionSubnet, DO NOT change
param bastionSubnetAddressPrefix string = '10.0.1.0/27' // MUST be at least /27 or larger

param appGatewaySubnetName string = 'AppGatewaySubnet'
param appGatewaySubnetAddressPrefix string = '10.0.2.0/26' // MUST be at least /26 or larger

param privateIPAddress string = '10.0.2.5' // MUST be within appGatewaySubnetAddressPrefix and cannot end in .0 - .4 (reserved)

// ====================

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

param firewall object = {
  name: 'AzureFirewall'
  publicIPAddressName: 'pip-firewall'
  subnetName: 'AzureFirewallSubnet'
  subnetPrefix: '10.0.3.0/26'
  routeName: 'r-nexthop-to-fw'
}

var subnets = [
  {
    name: gatewaySubnetName
    properties: {
      addressPrefix: gatewaySubnetAddressPrefix
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
  {
    name: bastionSubnetName
    properties: {
      addressPrefix: bastionSubnetAddressPrefix
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
  {
    name: appGatewaySubnetName
    properties: {
      addressPrefix: appGatewaySubnetAddressPrefix
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
  {
    name: firewall.subnetName
    properties: {
      addressPrefix: firewall.subnetPrefix
      privateEndpointNetworkPolicies: 'Disabled'
      privateLinkServiceNetworkPolicies: 'Enabled'
    }
  }
]

resource hbrg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${name}-hub'
  location: location
  tags: tags
}

resource spk1rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${name}-spoke-one'
  location: location
  tags: tags
}

resource spk2rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: '${name}-spoke-two'
  location: location
}

module hb 'network/hub.bicep' = {
  name: vnetName
  scope: hbrg
  params: {
    name: vnetName
    addressPrefixs: vnetAddressPrefixes
    subnets: subnets
    tags: tags
  }
}

module fw 'network/firewall.bicep' = {
  name: 'firewall'
  scope: hbrg
  params: {
    vnetName: hb.outputs.vnetName
    name: firewall.name
    publicIPAddressName: firewall.publicIPAddressName
    subnetName: firewall.subnetName
    routeName: firewall.routeName
    tags: tags
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
    routeTableId: fw.outputs.routeTableId
    tags: tags
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
    routeTableId: fw.outputs.routeTableId
    tags: tags
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

module gateway 'gateway/main.bicep' = {
  name: 'gateway'
  scope: hbrg
  params: {
    hostName: hostName
    adminPassword: adminPassword
    adminUsername: adminUsername
    gatewaySubnetName: gatewaySubnetName
    gatewaySubnetAddressPrefix: gatewaySubnetAddressPrefix
    bastionSubnetName: bastionSubnetName
    bastionSubnetAddressPrefix: bastionSubnetAddressPrefix
    appGatewaySubnetName: appGatewaySubnetName
    appGatewaySubnetAddressPrefix: appGatewaySubnetAddressPrefix
    privateIPAddress: privateIPAddress
    sslCertificateName: sslCertificateName
    tokenLifetime: tokenLifetime
    utcValue: utcValue
    vnet: hb.outputs.vnetId
    tags: tags
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
//     tags: tags
//   }
// }

// module lab2b 'lab/lab.bicep' = {
//   name: 'spoke-two-lab-secrets'
//   scope: spk2rg
//   params: {
//     name: 'Spoke2Lab'
//     tags: tags
//   }
// }
