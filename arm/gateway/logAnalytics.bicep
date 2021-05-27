param location string
param resourcePrefix string

param tags object = {}

var workspaceName = '${resourcePrefix}-logs'

resource workspace 'Microsoft.OperationalInsights/workspaces@2020-10-01' = {
  name: workspaceName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
  tags: tags
}

output id string = workspace.id
