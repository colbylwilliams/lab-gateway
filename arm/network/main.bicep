targetScope = 'subscription'

param location string
param initLabs bool = false
param initGateway bool = false

param hub object = {
  name: 'vnet-hub'
  addressPrefix: '10.0.0.0/20'
  resourceGroup: 'NetworkHub'
}

param spoke1 object = {
  name: 'vnet-spoke-one'
  addressPrefix: '10.100.0.0/16'
  subnetName: 'snet-spoke-resources'
  subnetPrefix: '10.100.0.0/16'
  subnetNsgName: 'nsg-spoke-one-resources'
  resourceGroup: 'NetworkSpokeOne'
}

param spoke2 object = {
  name: 'vnet-spoke-two'
  addressPrefix: '10.200.0.0/16'
  subnetName: 'snet-spoke-resources'
  subnetPrefix: '10.200.0.0/16'
  subnetNsgName: 'nsg-spoke-two-resources'
  resourceGroup: 'NetworkSpokeTwo'
}

param firewall object = {
  name: 'AzureFirewall'
  publicIPAddressName: 'pip-firewall'
  subnetName: 'AzureFirewallSubnet'
  subnetPrefix: '10.0.3.0/26'
  routeName: 'r-nexthop-to-fw'
}

resource hbrg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: hub.resourceGroup
  location: location
}

resource spk1rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: spoke1.resourceGroup
  location: location
}

resource spk2rg 'Microsoft.Resources/resourceGroups@2020-06-01' = {
  name: spoke2.resourceGroup
  location: location
}

module hb 'hub.bicep' = {
  name: hub.name
  scope: hbrg
  params: {
    name: hub.name
    addressPrefix: hub.addressPrefix
    firewall: firewall
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
    routeTableId: hb.outputs.routeTableId
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
    routeTableId: hb.outputs.routeTableId
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
  }
}

module lab2 '../lab/lab.bicep' = if (initLabs) {
  name: 'Spoke2Lab'
  scope: spk2rg
  params: {
    name: 'Spoke2Lab'
    vnetId: spk2.outputs.vnetId
    subnetId: spk2.outputs.subnetId
  }
}