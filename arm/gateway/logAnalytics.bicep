param resourcePrefix string

var workspaceName = '${resourcePrefix}-logs'

resource workspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: workspaceName
  location: resourceGroup().location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

output id string = workspace.id
