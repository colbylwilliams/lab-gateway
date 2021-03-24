#!/bin/bash -e

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

cdir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)
tdir="$cdir/tmp"

if [ ! -d "$tdir" ]; then
    echo "Creating temporary directory $tdir"
    mkdir "$tdir"
fi

# signSecretFile="$tdir/sign_cert_in.pfx"
# signExportFile="$tdir/sign_cert_out.pfx"

# sslSecretFile="$tdir/ssl_cert_in.pfx"
# sslExportFile="$tdir/ssl_cert_out.pfx"

# create output file for local development
if [ -z "$AZ_SCRIPTS_OUTPUT_PATH" ]; then
    AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY="$tdir"
    AZ_SCRIPTS_PATH_SCRIPT_OUTPUT_FILE_NAME="scriptoutputs.json"
    AZ_SCRIPTS_OUTPUT_PATH="$AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY/$AZ_SCRIPTS_PATH_SCRIPT_OUTPUT_FILE_NAME"
fi

helpText=$(cat << endHelp

Signing Certificate Utility

Options:
  -h  View this help output text again.

  -v  KeyVault name.

  -n  Signing Certificate name in KeyVault. Defaults to SignCertificate

  -l  SSL Certificate name in KeyVault. Defaults to SSLCertificate

  -u  Hostname of the Gateway for the SSL Certificate.

Examples:

    $ create_cert.sh -v mykeyvault

endHelp
)

# show help text if called with no args
if (($# == 0)); then
    echo "$helpText" >&2; exit 0
fi

signCertName="SignCertificate"
sslCertName="SSLCertificate"

# get arg values
while getopts ":v:n:l:u:h:" opt; do
    case $opt in
        v)  vaultName=$OPTARG;;
        n)  signCertName=$OPTARG;;
        l)  sslCertName=$OPTARG;;
        u)  hostName=$OPTARG;;
        h)  echo "$helpText" >&2; exit 0;;
        \?) echo "    Invalid option -$OPTARG $helpText" >&2; exit 1;;
        :)  echo "    Option -$OPTARG requires an argument $helpText." >&2; exit 1;;
    esac
done


# check for the azure cli
if ! [ -x "$(command -v az)" ]; then
    echo 'Error: az command is not installed.\nThe Azure CLI is required to run this deploy script. Please install the Azure CLI, run az login, then try again.' >&2
    exit 1
fi

# check for jq
if ! [ -x "$(command -v jq)" ]; then
    echo 'Error: jq command is not installed.\njq is required to run this deploy script. Please install jq from https://stedolan.github.io/jq/download/, then try again.' >&2
    exit 1
fi

signCertPolicy='{
    "issuerParameters": {
        "name": "Self"
    },
    "keyProperties": {
        "exportable": true,
        "keySize": 2048,
        "keyType": "RSA",
        "reuseKey": false
    },
    "lifetimeActions": [
        {
            "action": { "actionType": "AutoRenew" },
            "trigger": { "daysBeforeExpiry": 90 }
        }
    ],
    "secretProperties": {
        "contentType": "application/x-pkcs12"
    },
    "x509CertificateProperties": {
        "ekus": [ "1.3.6.1.5.5.7.3.2" ],
        "keyUsage": [ "digitalSignature" ],
        "subject": "CN=Azure DTL Gateway",
        "validityInMonths": 12
    }
}'

sslCertPolicy='{
    "issuerParameters": {
        "name": "Self"
    },
    "keyProperties": {
        "exportable": true,
        "keySize": 2048,
        "keyType": "RSA",
        "reuseKey": true
    },
    "lifetimeActions": [
        {
            "action": { "actionType": "AutoRenew" },
            "trigger": { "daysBeforeExpiry": 90 }
        }
    ],
    "secretProperties": {
        "contentType": "application/x-pkcs12"
    },
    "x509CertificateProperties": {
        "ekus": [ "1.3.6.1.5.5.7.3.1", "1.3.6.1.5.5.7.3.2" ],
        "keyUsage": [ "digitalSignature", "keyEncipherment" ],
        "subject": "'"CN=$hostName"'",
        "subjectAlternativeNames": {
            "dnsNames": [
                "'"$hostName"'"
            ]
        },
        "validityInMonths": 12
    }
}'

# private key is added as a secret that can be retrieved in the Resource Manager template
echo "Creating new certificate '$signCertName'"
az keyvault certificate create --vault-name $vaultName -n $signCertName -p "$signCertPolicy"

echo "Getting certificate '$signCertName' details"
signCert=$( az keyvault certificate show --vault-name $vaultName -n $signCertName )

echo "Getting id for certificate '$signCertName'"
signId=$( echo $signCert | jq -r '.id' )

echo "Getting secret name for certificate '$signCertName'"
signName=$( echo $signCert | jq -r '.name' )

echo "Getting secret id for certificate '$signCertName'"
signSid=$( echo $signCert | jq -r '.sid' )

# echo "Getting secret id for certificate '$signCertName'"
# signCer=$( echo $signCert | jq -r '.cer' )

# echo "Getting thumbprint for certificate '$signCertName'"
# signThumbprint=$( echo $signCert | jq -r '.x509ThumbprintHex' )

# echo "Downloading certificate '$signCertName'"
# az keyvault secret download --id $signSid -f "$signSecretFile"

# echo "Generating random password for certificate '$signCertName' export"
# signPassword=$( openssl rand -base64 32 | tr -d /=+ | cut -c -16 )

# echo "Exporting certificate '$signCertName' file '$signExportFile'"
# openssl pkcs12 -export -in "$signSecretFile" -out "$signExportFile" -password pass:$signPassword -name "Azure DTL Gateway"
# signCertBase64=$( openssl base64 -A -in "$signExportFile" )


echo "Creating new certificate '$sslCertName'"
az keyvault certificate create --vault-name $vaultName -n $sslCertName -p "$sslCertPolicy"

echo "Getting certificate '$sslCertName' details"
sslCert=$( az keyvault certificate show --vault-name $vaultName -n $sslCertName )

echo "Getting id for certificate '$sslCertName'"
sslId=$( echo $sslCert | jq -r '.id' )

echo "Getting secret name for certificate '$sslCertName'"
sslName=$( echo $sslCert | jq -r '.name' )

echo "Getting secret id for certificate '$sslCertName'"
sslSid=$( echo $sslCert | jq -r '.sid' )

# echo "Getting cer for certificate '$sslCertName'"
# sslCer=$( echo $sslCert | jq -r '.cer' )

# echo "Getting thumbprint for certificate '$sslCertName'"
# sslThumbprint=$( echo $sslCert | jq -r '.x509ThumbprintHex' )

# echo "Downloading certificate '$sslCertName'"
# az keyvault secret download --id $sslSid -f "$sslSecretFile"

# echo "Generating random password for certificate '$sslCertName' export"
# sslPassword=$( openssl rand -base64 32 | tr -d /=+ | cut -c -16 )

# echo "Exporting certificate '$sslCertName' file '$sslExportFile'"
# openssl pkcs12 -export -in "$sslSecretFile" -out "$sslExportFile" -password pass:$sslPassword -name "$hostName"
# sslCertBase64=$( openssl base64 -A -in "$sslExportFile" )

echo "{ \"signCertificate\": { \"id\": \"$signId\", \"name\": \"$signName\", \"sid\": \"$signSid\" }, \"sslCertificate\": { \"id\": \"$sslId\", \"name\": \"$sslName\", \"sid\": \"$sslSid\" } }" > $AZ_SCRIPTS_OUTPUT_PATH

# echo "{ \"signCert\": { \"id\": \"$signId\", \"name\": \"$signName\", \"thumbprint\": \"$signThumbprint\", \"secretUriWithVersion\": \"$signSid\" }, \"sslCert\": { \"id\": \"$sslId\", \"name\": \"$sslName\", \"thumbprint\": \"$sslThumbprint\", \"secretUriWithVersion\": \"$sslSid\" } }" > $AZ_SCRIPTS_OUTPUT_PATH

# echo "{ \"signCert\": { \"id\": \"$signId\", \"thumbprint\": \"$signThumbprint\", \"secretUriWithVersion\": \"$signSid\", \"cer\": \"$signCer\" }, \"sslCert\": { \"id\": \"$sslId\", \"thumbprint\": \"$sslThumbprint\", \"secretUriWithVersion\": \"$sslSid\", \"cer\": \"$sslCer\" } }" > $AZ_SCRIPTS_OUTPUT_PATH
# echo "{ \"signCert\": { \"id\": \"$signId\", \"thumbprint\": \"$signThumbprint\", \"password\": \"$signPassword\", \"base64\": \"$signCertBase64\", \"secretUriWithVersion\": \"$signSid\", \"cer\": \"$signCer\" }, \"sslCert\": { \"id\": \"$sslId\", \"thumbprint\": \"$sslThumbprint\", \"password\": \"$sslPassword\", \"base64\": \"$sslCertBase64\", \"secretUriWithVersion\": \"$sslSid\", \"cer\": \"$sslCer\" } }" > $AZ_SCRIPTS_OUTPUT_PATH
# echo "{ \"thumbprint\": \"$thumbprint\", \"password\": \"$password\", \"base64\": \"$signCertBase64\" }" > $AZ_SCRIPTS_OUTPUT_PATH

echo "Cleaning up temporary files"
rm -rf "$tdir"

echo "Deleting script runner managed identity"
az identity delete --ids "$AZ_SCRIPTS_USER_ASSIGNED_IDENTITY"

echo "Done."
