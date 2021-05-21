param resourcePrefix string = 'rdg${uniqueString(resourceGroup().id)}'

output resourcePrefix string = resourcePrefix
output functionName string = '${resourcePrefix}-fa'
output keyvaultName string = '${resourcePrefix}-kv'
