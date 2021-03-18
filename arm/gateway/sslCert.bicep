param keyVaultName string

@secure()
param certificatePassword string = ''
param certificateThumbprint string = ''
param certificate string = ''

var sslCertificateSecretName = 'SSLCertificate'

resource secret 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  name: '${keyVaultName}/${sslCertificateSecretName}'
  properties: {
    value: base64('{ "data":"${certificate}", "dataType":"pfx", "password":"${certificatePassword}" }')
  }
}

output thumbprint string = certificateThumbprint
output secretUriWithVersion string = secret.properties.secretUriWithVersion
