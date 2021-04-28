targetScope = 'subscription'

param name string = 'network'
param initLabs bool = false
param location string = deployment().location
// param initGateway bool = false

// ====================
// Manual variables

param tags object = {}

// only used if an existing VNet is NOT provided
param vnetName string = 'vnet-hub'
param vnetAddressPrefixs array = [
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
      addressPrefix: '10.0.0.0/24'
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
  tags: tags
}

module hb 'hub.bicep' = {
  name: vnetName
  scope: hbrg
  params: {
    name: vnetName
    addressPrefixs: vnetAddressPrefixs
    subnets: subnets
    tags: tags
  }
}

module fw 'firewall.bicep' = {
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

module spk1 'spoke.bicep' = {
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

module spk2 'spoke.bicep' = {
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

module peerHubToSpoke1 'peer.bicep' = {
  name: 'peerHubToSpoke1'
  scope: spk1rg
  params: {
    vnetId: spk1.outputs.vnetId
    toVnetId: hb.outputs.vnetId
  }
}

module peerSpoke1ToHub 'peer.bicep' = {
  name: 'peerSpoke1ToHub'
  scope: hbrg
  params: {
    vnetId: hb.outputs.vnetId
    toVnetId: spk1.outputs.vnetId
  }
}

module peerHubToSpoke2 'peer.bicep' = {
  name: 'peerHubToSpoke2'
  scope: spk2rg
  params: {
    vnetId: spk2.outputs.vnetId
    toVnetId: hb.outputs.vnetId
  }
}

module peerSpoke2ToHub 'peer.bicep' = {
  name: 'peerSpoke2ToHub'
  scope: hbrg
  params: {
    vnetId: hb.outputs.vnetId
    toVnetId: spk2.outputs.vnetId
  }
}

module lab1 '../lab/lab.bicep' = if (initLabs) {
  name: 'Spoke1Lab'
  scope: spk1rg
  params: {
    name: 'Spoke1Lab'
    vnetId: spk1.outputs.vnetId
    subnetId: spk1.outputs.subnetId
    tags: tags
  }
}

module lab2 '../lab/lab.bicep' = if (initLabs) {
  name: 'Spoke2Lab'
  scope: spk2rg
  params: {
    name: 'Spoke2Lab'
    vnetId: spk2.outputs.vnetId
    subnetId: spk2.outputs.subnetId
    tags: tags
  }
}
