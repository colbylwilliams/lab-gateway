param createSignCertificate bool
param keyVaultName string
param createSignCertificateIdentityTenantId string
param createSignCertificateIdentityPrincipalId string

resource keyVaultName_add 'Microsoft.KeyVault/vaults/accessPolicies@2019-09-01' = if (createSignCertificate) {
  name: '${keyVaultName}/add'
  properties: {
    accessPolicies: [
      {
        tenantId: createSignCertificateIdentityTenantId
        objectId: createSignCertificateIdentityPrincipalId
        permissions: {
          keys: [
            'get'
            'create'
          ]
          secrets: [
            'get'
            'set'
          ]
          certificates: [
            'get'
            'create'
          ]
        }
      }
    ]
  }
}