#!/bin/bash -e

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

cdir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

# create output file for local development
if [ -z "$AZ_SCRIPTS_OUTPUT_PATH" ]; then
    tdir="$cdir/tmp"

    if [ ! -d "$tdir" ]; then
        echo "Creating temporary directory $tdir"
        mkdir "$tdir"
    fi

    AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY="$tdir"
    AZ_SCRIPTS_PATH_SCRIPT_OUTPUT_FILE_NAME="scriptoutputs.json"
    AZ_SCRIPTS_OUTPUT_PATH="$AZ_SCRIPTS_PATH_OUTPUT_DIRECTORY/$AZ_SCRIPTS_PATH_SCRIPT_OUTPUT_FILE_NAME"
fi

helpText=$(cat << endHelp

Certificate Utility

Options:
  -h  View this help output text again.

  -v  KeyVault name.

  -x  Signing Certificate name in KeyVault. Defaults to SignCertificate

  -c  SSL Certificate name in KeyVault. Defaults to SSLCertificate

  -u  Hostname of the Gateway for the SSL Certificate.

Examples:

    $ create_cert.sh -v mykeyvault -x SignCert -c SSLCert -u mydomain.com

endHelp
)

# show help text if called with no args
if (($# == 0)); then
    echo "$helpText" >&2; exit 0
fi

signCertificateName="SignCertificate"
sslCertificateName="SSLCertificate"

# get arg values
while getopts ":hv:x:c:u:" opt; do
    case $opt in
        v)  vaultName=$OPTARG;;
        x)  signCertificateName=$OPTARG;;
        c)  sslCertificateName=$OPTARG;;
        u)  sslCertHostName=$OPTARG;;
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
        "subject": "'"CN=$sslCertHostName"'",
        "subjectAlternativeNames": {
            "dnsNames": [
                "'"$sslCertHostName"'"
            ]
        },
        "validityInMonths": 12
    }
}'

echo "Creating new signing certificate"
az keyvault certificate create --vault-name $vaultName -n $signCertificateName -p "$signCertPolicy"

echo "Getting signing certificate details"
signCert=$( az keyvault certificate show --vault-name $vaultName -n $signCertificateName )

echo "Getting id for signing certificate"
signCertId=$( echo $signCert | jq -r '.id' )

echo "Getting secret name signing for certificate"
signCertName=$( echo $signCert | jq -r '.name' )

echo "Getting secret id for signing certificate"
signCertSid=$( echo $signCert | jq -r '.sid' )


echo "Creating new ssl certificate"
az keyvault certificate create --vault-name $vaultName -n $sslCertificateName -p "$sslCertPolicy"

echo "Getting ssl certificate details"
sslCert=$( az keyvault certificate show --vault-name $vaultName -n $sslCertificateName )

echo "Getting id for ssl certificate"
sslCertId=$( echo $sslCert | jq -r '.id' )

echo "Getting secret name for ssl certificate"
sslCertName=$( echo $sslCert | jq -r '.name' )

echo "Getting secret id for ssl certificate"
sslCertSid=$( echo $sslCert | jq -r '.sid' )

outputJson='{
    "signCertificate": {
        "name": "'"$signCertName"'",
        "sid": "'"$signCertSid"'"
    },
    "sslCertificate": {
        "name": "'"$sslCertName"'",
        "sid": "'"$sslCertSid"'"
    }
}'

echo "$outputJson" > $AZ_SCRIPTS_OUTPUT_PATH

echo "Deleting script runner managed identity"
az identity delete --ids "$AZ_SCRIPTS_USER_ASSIGNED_IDENTITY"

echo "Done."
