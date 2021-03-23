param utcValue string = utcNow('u')

param hostName string
param keyVaultName string

// @secure()
// param certificatePassword string = ''
// param certificateThumbprint string = ''
// param certificate string = ''

var sslCertificateSecretName = 'SSLCertificate'
var signCertificateSecretName = 'SignCertificate'

var scriptIdentityName = 'createCertificatesIdentity'

var scriptIdentiyRoleAssignmentIdName = guid('${resourceGroup().id}${scriptIdentityName}contributor${utcValue}')
var contributorRoleDefinitionId = '/subscriptions/${subscription().subscriptionId}/providers/Microsoft.Authorization/roleDefinitions/b24988ac-6180-42a0-ab88-20f7382dd24c'
var createCertificatesScriptUri = 'https://raw.githubusercontent.com/colbylwilliams/lab-gateway/main/tools/create_certs.sh'

// var createSignCertificate = (empty(certificate) || empty(certificatePassword) || empty(certificateThumbprint))

resource scriptIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' = {
  name: scriptIdentityName
  location: resourceGroup().location
}

resource scriptIdentityRoleAssignmentId 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  name: scriptIdentiyRoleAssignmentIdName
  properties: {
    roleDefinitionId: contributorRoleDefinitionId
    principalId: scriptIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

module scriptIdentityAccessPolicy 'certsPolicy.bicep' = {
  name: 'scriptIdentityAccessPolicy'
  params: {
    keyVaultName: keyVaultName
    tenantId: scriptIdentity.properties.tenantId
    principalId: scriptIdentity.properties.principalId
  }
}

resource createCertificatesScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  kind: 'AzureCLI'
  name: 'createCertificatesScript'
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
    arguments: '-v ${keyVaultName} -u ${hostName}'
    cleanupPreference: 'Always'
    retentionInterval: 'PT1H'
    primaryScriptUri: createCertificatesScriptUri
  }
  dependsOn: [
    scriptIdentityRoleAssignmentId
    scriptIdentityAccessPolicy
  ]
}

resource signSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/${signCertificateSecretName}'
  properties: {
    value: base64('{ "data":"${createCertificatesScript.properties.outputs.signCert.base64}", "dataType":"pfx", "password":"${createCertificatesScript.properties.outputs.signCert.password}" }')
  }
}

resource sslSecret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/${sslCertificateSecretName}'
  properties: {
    value: base64('{ "data":"${createCertificatesScript.properties.outputs.sslCert.base64}", "dataType":"pfx", "password":"${createCertificatesScript.properties.outputs.sslCert.password}" }')
  }
}

// output thumbprint string = createCertificatesScript.properties.outputs.sslCert.thumbprint
// output secretUriWithVersion string = secret.properties.secretUriWithVersion

output signCert object = {
  // id: createCertificatesScript.properties.outputs.signCert.thumbprint
  thumbprint: createCertificatesScript.properties.outputs.signCert.thumbprint
  secretUriWithVersion: signSecret.properties.secretUriWithVersion
}

output sslCert object = {
  id: createCertificatesScript.properties.outputs.sslCert.id
  cer: createCertificatesScript.properties.outputs.sslCert.cer
  thumbprint: createCertificatesScript.properties.outputs.sslCert.thumbprint
  secretUriWithVersion: sslSecret.properties.secretUriWithVersion
  // TODO: check if we can just use the existing secretUriWithVersion
  // secretUriWithVersion: createCertificatesScript.properties.outputs.sslCert.secretUriWithVersion
}
