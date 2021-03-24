param keyVaultName string
param resourcePrefix string
param tokenLifetime string = '00:01:00'

@secure()
param storageConnectionString string

@secure()
param signCertificateSecretUriWithVersion string

var hostingPlanName = '${resourcePrefix}-hp'
var functionAppName = '${resourcePrefix}-fa'
var appInsightsName = '${resourcePrefix}-ai'

var githubRepoPath = 'api'

resource appInsights 'Microsoft.Insights/components@2020-02-02-preview' = {
  kind: 'web'
  name: appInsightsName
  location: resourceGroup().location
  properties: {
    Application_Type: 'web'
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2020-06-01' = {
  name: hostingPlanName
  location: resourceGroup().location
  sku: {
    tier: 'ElasticPremium'
    name: 'EP1'
  }
}

resource functionApp 'Microsoft.Web/sites@2020-06-01' = {
  kind: 'functionapp'
  name: functionAppName
  location: resourceGroup().location
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
          value: '@Microsoft.KeyVault(SecretUri=${signCertificateSecretUriWithVersion})'
        }
        {
          name: 'TokenLifetime'
          value: tokenLifetime
        }
      ]
    }
  }
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

output id string = functionApp.id
output name string = functionApp.name
output defaultHostName string = functionApp.properties.defaultHostName
