param utcValue string = utcNow('u')

param keyVaultName string

@secure()
param certificatePassword string = ''
param certificateThumbprint string = ''
param certificate string = ''

var signCertificateSecretName = 'SignCertificate'
var scriptIdentityName = 'createSignCertificateIdentity'
var scriptIdentiyRoleAssignmentIdName = guid('${resourceGroup().id}${scriptIdentityName}contributor${utcValue}')
var contributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
var createSignCertificateScriptUri = 'https://raw.githubusercontent.com/colbylwilliams/lab-gateway/main/tools/create_cert.sh'

var createSignCertificate = (empty(certificate) || empty(certificatePassword) || empty(certificateThumbprint))

resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = if (createSignCertificate) {
  name: scriptIdentityName
  location: resourceGroup().location
}

resource scriptIdentityRoleAssignmentId 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = if (createSignCertificate) {
  name: scriptIdentiyRoleAssignmentIdName
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: createSignCertificate ? scriptIdentity.properties.principalId : json('null')
    principalType: 'ServicePrincipal'
  }
}

module scriptIdentityAccessPolicy 'signCertPolicy.bicep' = if (createSignCertificate) {
  name: 'scriptIdentityAccessPolicy'
  params: {
    keyVaultName: keyVaultName
    tenantId: createSignCertificate ? scriptIdentity.properties.tenantId : json('null')
    principalId: createSignCertificate ? scriptIdentity.properties.principalId : json('null')
  }
}

resource createSignCertificateScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = if (createSignCertificate) {
  kind: 'AzureCLI'
  name: 'createSignCertificateScript'
  location: resourceGroup().location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${scriptIdentity.id}': {}
    }
  }
  properties: {
    forceUpdateTag: utcValue
    azCliVersion: '2.18.0'
    timeout: 'PT1H'
    arguments: '-v ${keyVaultName}'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
    primaryScriptUri: createSignCertificateScriptUri
  }
  dependsOn: [
    scriptIdentityRoleAssignmentId
    scriptIdentityAccessPolicy
  ]
}

resource secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/${signCertificateSecretName}'
  properties: {
    value: base64('{ "data":"${(createSignCertificate ? createSignCertificateScript.properties.outputs.base64 : certificate)}", "dataType":"pfx", "password":"${(createSignCertificate ? createSignCertificateScript.properties.outputs.password : certificatePassword)}" }')
  }
}

output thumbprint string = createSignCertificate ? createSignCertificateScript.properties.outputs.thumbprint : certificateThumbprint
output secretUriWithVersion string = secret.properties.secretUriWithVersion
