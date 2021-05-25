param vnet string
param name string
param addressPrefix string = ''

var use_existing = empty(addressPrefix)

var vnetName = last(split(vnet, '/'))
var vnetRg = first(split(last(split(vnet, '/resourceGroups/')), '/'))

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' = if (!use_existing) {
  name: '${vnetName}/${name}'
  properties: {
    addressPrefix: addressPrefix
    privateEndpointNetworkPolicies: 'Disabled'
    privateLinkServiceNetworkPolicies: 'Enabled'
  }
}

resource rg_vnet_existing 'Microsoft.Resources/resourceGroups@2020-06-01' existing = if (use_existing) {
  name: vnetRg
  scope: subscription()
}

resource subnet_existing 'Microsoft.Network/virtualNetworks/subnets@2020-06-01' existing = if (use_existing) {
  name: '${vnetName}/${name}'
  scope: rg_vnet_existing
}

output subnet string = use_existing ? subnet_existing.id : subnet.id
