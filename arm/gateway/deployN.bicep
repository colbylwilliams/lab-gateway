param resourcePrefix string = 'rdg${uniqueString(resourceGroup().id)}'

output resourcePrefix string = resourcePrefix
