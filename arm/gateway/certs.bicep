param utcValue string

param hostName string
param keyVaultName string

// @secure()
// param certificatePassword string = ''
// param certificateThumbprint string = ''
// param certificate string = ''

var sslCertificateName = 'SSLCertificate'
var signCertificateName = 'SignCertificate'

var identityName = 'createCertificatesIdentity'

var roleAssignmentIdName = guid('${resourceGroup().id}${identityName}contributor${utcValue}')
var contributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
var scriptUri = 'https://raw.githubusercontent.com/colbylwilliams/lab-gateway/main/tools/create_certs.sh'

// var createSignCertificate = (empty(certificate) || empty(certificatePassword) || empty(certificateThumbprint))

resource identity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: identityName
  location: resourceGroup().location
}

resource roleAssignmentId 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: roleAssignmentIdName
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: identity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

module accessPolicy 'certsPolicy.bicep' = {
  name: 'scriptIdentityAccessPolicy'
  params: {
    keyVaultName: keyVaultName
    tenantId: identity.properties.tenantId
    principalId: identity.properties.principalId
  }
}

resource script 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzureCLI'
  name: 'createCertificatesScript'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${identity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.18.0'
    timeout: 'PT1H'
    arguments: '-v ${keyVaultName} -n ${signCertificateName} -l ${sslCertificateName} -u ${hostName}'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
    primaryScriptUri: scriptUri
  }
  dependsOn: [
    roleAssignmentId
    accessPolicy
  ]
}

output signCertificateId string = script.properties.outputs.signCertificate.id
output signCertificateName string = script.properties.outputs.signCertificate.name
output signCertificateSecretUriWithVersion string = script.properties.outputs.signCertificate.sid

output sslCertificateId string = script.properties.outputs.sslCertificate.id
output sslCertificateName string = script.properties.outputs.sslCertificate.name
output sslCertificateSecretUriWithVersion string = script.properties.outputs.sslCertificate.sid
