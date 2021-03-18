param accountName string

var artifactsContainerName = 'artifacts'

resource storageAccount 'Microsoft.Storage/storageAccounts@2020-08-01-preview' = {
  name: accountName
  location: resourceGroup().location
  sku: {
    name: 'Standard_RAGRS'
    tier: 'Standard'
  }
  kind: 'StorageV2'
}

resource artifactsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2020-08-01-preview' = {
  name: '${storageAccount.name}/default/${artifactsContainerName}'
}

output accountName string = accountName
output accountKey string = listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value
output connectionString string = 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};AccountKey=${listKeys(storageAccount.id, storageAccount.apiVersion).keys[0].value}'
output artifactsEndpoint string = '${storageAccount.properties.primaryEndpoints.blob}${artifactsContainerName}'
output artifactsContainerName string = artifactsContainerName
