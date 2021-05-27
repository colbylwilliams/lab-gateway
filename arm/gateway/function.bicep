param location string
param resourcePrefix string

param keyVaultName string
param tokenLifetime string = '00:01:00'

@secure()
param storageConnectionString string

@secure()
param signCertificateSecretUri string

param logAnalyticsWrokspaceId string = ''

param tags object = {}

var hostingPlanName = '${resourcePrefix}-hp'
var functionAppName = '${resourcePrefix}-fa'
var appInsightsName = '${resourcePrefix}-ai'

var githubRepoPath = 'api'

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  kind: 'web'
  name: appInsightsName
  location: location
  properties: {
    Application_Type: 'web'
  }
  tags: tags
}

resource hostingPlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: hostingPlanName
  location: location
  sku: {
    tier: 'ElasticPremium'
    name: 'EP1'
  }
  tags: tags
}

resource functionApp 'Microsoft.Web/sites@2020-06-01' = {
  kind: 'functionapp'
  name: functionAppName
  location: location
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsDashboard'
          value: storageConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: storageConnectionString
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: functionAppName
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'AZURE_FUNCTIONS_ENVIRONMENT'
          value: 'Production'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~3'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
        }
        {
          name: 'Project'
          value: githubRepoPath
        }
        {
          name: 'SignCertificate'
          value: '@Microsoft.KeyVault(SecretUri=${signCertificateSecretUri})'
        }
        {
          name: 'TokenLifetime'
          value: tokenLifetime
        }
      ]
    }
  }
  tags: tags
}

resource functionAppKeyVaultPolicy 'Microsoft.KeyVault/vaults/accessPolicies@2019-09-01' = {
  name: any('${keyVaultName}/add')
  properties: {
    accessPolicies: [
      {
        tenantId: functionApp.identity.tenantId
        objectId: functionApp.identity.principalId
        permissions: {
          secrets: [
            'get'
          ]
        }
      }
    ]
  }
}

resource diagnostics 'microsoft.insights/diagnosticSettings@2017-05-01-preview' = if (!empty(logAnalyticsWrokspaceId)) {
  name: 'diagnostics'
  scope: functionApp
  properties: {
    workspaceId: logAnalyticsWrokspaceId
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
  }
}

output id string = functionApp.id
output name string = functionApp.name
output defaultHostName string = functionApp.properties.defaultHostName
