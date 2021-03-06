#!/bin/sh

# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

set -e

NC='\033[0m' # No Color
RED='\033[0;31m'
GREEN='\033[0;32m'

die() { echo "${RED}Error: $1${NC}" >&2; exit 1; }

cdir=$(cd -P -- "$(dirname -- "$0")" && pwd -P)

template="$cdir/main.bicep"
kvtemplate="$cdir/gateway/keyvault.bicep"
labTemplate="$cdir/lab/lab.bicep"
artifactsSource="$cdir/artifacts"

helpText=$(cat << endHelp

Remote Desktop Gateway Deploy Utility

Options:

  -h  View this help output text again.


  Required

  -s  Name or ID of subscription.
        You can configure the default subscription using az account set -s NAME_OR_ID.

  -g  Resource Group: The Name for the new Azure Resource Group to create.
        The value must be a string.  Resource Group names are case insensitive.
        Alphanumeric, underscore, parentheses, hyphen, period (except at the end) are valid.

  -l  Location. Values from: az account list-locations.
        You can configure the default location using az configure --defaults location=<location>.

  -u  Admin username for the gateway VMs.

  -p  Admin password for the gateway VMs.

  -c  Path to the SSL certificate .pfx or .p12 file.

  -k  Password used to export the SSL certificate (for installation).

  -v  Vnet to use for the Gateway.

  -w  Public IP Address Resource ID.

  -r  Private IP Address.


  Optional

  -x  Path to self-signed certificate .pfx or .p12 file.
        If this option is ommitted, a new certificate will be generated during deployment using KeyVault.

  -t  Password used to export the self-signed certificate (for installation).

  -i  Number of VMs in the gateway scale set. default: 1

Examples:

    $ deploy.sh -g MyResoruceGroup -l eastus -u DevUser -p SoSecure1 -c ./Cert.p12 -k 12345

endHelp
)
helpText="${NC}$helpText${NC}\n"

# show help text if called with no args
if (($# == 0)); then
    echo "$helpText" >&2; exit 0
fi

# check for jq
[ -x "$(command -v jq)" ] || die "jq command is not installed.\njq is required to run this deploy script. Please install jq from https://stedolan.github.io/jq/download/, then try again."
# check for the azure cli
[ -x "$(command -v az)" ] || die "az command is not installed.\nThe Azure CLI is required to run this deploy script. Please install the Azure CLI, run az login, then try again."


# defaults
instances=1
sub=$( az account show --query id -o tsv )

# get arg values
while getopts ":hs:g:l:u:p:c:k:x:t:i:v:w:r:" opt; do
    case $opt in
        s)  sub=$OPTARG;;
        g)  rg=$OPTARG;;
        l)  region=$OPTARG;;
        u)  adminUsername=$OPTARG;;
        p)  adminPassword=$OPTARG;;
        c)  sslCert=$OPTARG;;
        k)  sslCertPassword=$OPTARG;;
        x)  signCert=$OPTARG;;
        t)  signCertPassword=$OPTARG;;
        v)  vnetId=$OPTARG;;
        w)  publicIp=$OPTARG;;
        r)  privateIp=$OPTARG;;
        i)  instances=$OPTARG;;
        h)  echo "$helpText" >&2; exit 0;;
        \?) die "Invalid option -$OPTARG \n$helpText";;
        :)  die "Option -$OPTARG requires an argument \n$helpText.";;
    esac
done


echo ""


# ensure required args
[ ! -z "$sub" ] || die "-s must have a value\n$helpText"
[ ! -z "$rg" ] || die "-g must have a value\n$helpText"
[ ! -z "$region" ] || die "-l must have a value\n$helpText"
[ ! -z "$adminUsername" ] || die "-u must have a value\n$helpText"
[ ! -z "$adminPassword" ] || die "-p must have a value\n$helpText"
[ ! -z "$sslCert" ] || die "-c must have a value\n$helpText"
[ ! -z "$sslCertPassword" ] || die "-k must have a value\n$helpText"
[ ! -z "$instances" ] || die "-i must have a value\n$helpText"

# ensure sslCert is a path to a file
[ -f "$sslCert" ] || die "-c $sslCert not found. Please check the path is correct and try again."


if [ ! -z "$signCert" ]; then
  # ensure signCert is a path to a file
  [ -f "$signCert" ] || die "-x $signCert not found. Please check the path is correct and try again."
  [ ! -z "$signCertPassword" ] || die "-t signing certificate password must have a value when -x signing certificate path is provided\n$helpText"
elif [ ! -z "$signCertPassword" ]; then
  die "-x signing certificate path must have a have value if -t signing certificate password is provided\n$helpText"
fi


# check if logged in to azure cli
az account show -s $sub 1> /dev/null

# check if the resource group exists. if not, create it
az group show --subscription $sub -g $rg 1> /dev/null || echo "Creating resource group '$rg-hub'." && az group create --subscription $sub -g "$rg-hub" -l $region 1> /dev/null


echo "\nParsing SSL certificate\n"
sslCertBase64=$( base64 $sslCert )
sslCertThumbprint=$( openssl pkcs12 -in $sslCert -nodes -passin pass:$sslCertPassword | openssl x509 -noout -fingerprint | cut -d "=" -f 2 | sed 's/://g' )
sslCertCommonName=$( openssl pkcs12 -in $sslCert -nodes -passin pass:$sslCertPassword | openssl x509 -noout -subject | rev | cut -d "=" -f 1 | rev | sed 's/ //g' )

echo "\nDeploying kv arm template to resource group '$rg-hub' in subscription '$sub'"
kvdeploy=$( az deployment group create --subscription $sub -g "$rg-hub" -f "$kvtemplate" )

[ ! -z "$kvdeploy" ] || die "Failed to deploy kv arm template."

kvname=$( echo $kvdeploy | jq -r '.properties.outputs.name.value' )
echo "$kvname"

azUser=$( az ad signed-in-user show --query userPrincipalName -o tsv )

az keyvault set-policy --upn "$azUser" -n "$kvname" --certificate-permissions import

az keyvault certificate import -f "$sslCert" --password "$sslCertPassword" -n "SSLCertificate" --vault-name "$kvname"


# if [ ! -z "$signCert" ]; then

#   echo "\nParsing signing certificate\n"
#   signCertBase64=$( base64 $signCert )
#   signCertThumbprint=$( openssl pkcs12 -in $signCert -nodes -passin pass:$signCertPassword | openssl x509 -noout -fingerprint | cut -d "=" -f 2 | sed 's/://g' )

#   echo "\nDeploying arm template to subscription '$sub'"
#   deploy=$( az deployment sub create --subscription $sub -l $region -f "$template" -p name="$rg" adminUsername="$adminUsername" adminPassword="$adminPassword" \
#                       sslCertificate="$sslCertBase64" sslCertificatePassword="$sslCertPassword" sslCertificateThumbprint="$sslCertThumbprint" \
#                       signCertificate="$signCertBase64" signCertificatePassword="$signCertPassword" signCertificateThumbprint="$signCertThumbprint" \
#                       hostName="$sslCertCommonName" )
# else

#   echo "\nDeploying arm template to subscription '$sub'"
#   deploy=$( az deployment sub create --subscription $sub -l $region -f "$template" -p name="$rg" adminUsername="$adminUsername" adminPassword="$adminPassword" \
#                       sslCertificate="$sslCertBase64" sslCertificatePassword="$sslCertPassword" sslCertificateThumbprint="$sslCertThumbprint" \
#                       hostName="$sslCertCommonName" )
# fi

echo "\nDeploying arm template to subscription '$sub'"
deploy=$( az deployment sub create --subscription $sub -l $region -f "$template" -p name="$rg" adminUsername="$adminUsername" adminPassword="$adminPassword" hostName="$sslCertCommonName" )


[ ! -z "$deploy" ] || die "Failed to deploy arm template."

outputs=$( echo $deploy | jq '.properties.outputs' )


if [ -d "$artifactsSource" ]; then

  artifacts=$( echo $outputs | jq '.artifactsStorage.value' )
  artifactsAccount=$( echo $artifacts | jq -r '.account' )
  artifactsContainer=$( echo $artifacts | jq -r '.container' )

  echo "\nSynchronizing artifacts"
  az storage blob sync --subscription $sub --account-name $artifactsAccount -c $artifactsContainer -s "$artifactsSource" > /dev/null 2>&1 &
fi

gateway=$( echo $outputs | jq '.gateway.value' )
gatewayIP=$( echo $gateway | jq -r '.ip' )
gatewayScaleSet=$( echo $gateway | jq -r '.scaleSet' )
gatewayFunction=$( echo $gateway | jq -r '.function' )

rgName=$( echo $outputs | jq -r '.rg.value' )

echo "\nScaling gateway to $instances instances"
az vmss scale --subscription $sub -g $rgName -n $gatewayScaleSet --new-capacity $instances > /dev/null 2>&1 &

if [ "$gatewayFunction" != "null" ]; then
  echo "\nGetting gateway token"
  gatewayToken=$( az functionapp function keys list --subscription $sub -g $rgName -n $gatewayFunction --function-name CreateToken | jq -r '.gateway' )

  if [ "$gatewayToken" == "null" ]; then
    echo "No gateway token found, creating"
    gatewayToken=$( az functionapp function keys set --subscription $sub -g $rgName -n $gatewayFunction --function-name CreateToken --key-name gateway --query value -o tsv )
  fi
fi

lab1=$( echo $outputs | jq '.lab1.value' )
lab1name=$( echo $lab1 | jq -r '.name' )
lab1group=$( echo $lab1 | jq -r '.group' )


echo "\nConnecting lab one to gateway"
az deployment group create --subscription $sub -g $lab1group -f "$labTemplate" -p name=$lab1name gatewayHostname=$sslCertCommonName gatewayToken=$gatewayToken

lab2=$( echo $outputs | jq '.lab2.value' )
lab2name=$( echo $lab2 | jq -r '.name' )
lab2group=$( echo $lab2 | jq -r '.group' )


echo "\nConnecting lab two to gateway"
az deployment group create --subscription $sub -g $lab2group -f "$labTemplate" -p name=$lab2name gatewayHostname=$sslCertCommonName gatewayToken=$gatewayToken


echo "\nDone."

if [ ! -z "$sslCertCommonName" ]; then
  echo "\n\n${GREEN}Register Remote Desktop Gateway with your DNS using one of the following two options:${NC}\n"
  echo "${GREEN}  - Create an A-Record:     $sslCertCommonName -> $gatewayIP ${NC}"
  if [ ! -z "$gatewayToken" ]; then
    echo "\n\n${GREEN}Use the following to configure your labs to use the gateway:${NC}\n"
    echo "${GREEN}  - Gateway hostname:     $sslCertCommonName ${NC}"
    echo "${GREEN}  - Gateway token secret: $gatewayToken ${NC}"
  fi
fi

echo ""
