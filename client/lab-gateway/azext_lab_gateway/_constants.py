# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

TAG_PREFIX = 'hidden-lgw:'

API_WAF_RULE_NAME = 'AllowAzureCloudIPs'
GATEWAY_WAF_RULE_NAME = 'AllowKnownIPs'
# GATEWAY_WAF_RULE_NAME = 'BlockUnknownUris'

LAB_REGIONS_CANARY = ['westcentralus']
LAB_REGIONS_LOW_VOL = ['southcentralus']
LAB_REGIONS_HIGH_VOL = ['centralus']
LAB_REGIONS_ROW_1 = [
    'australiacentral',
    'australiasoutheast',
    'canadacentral',
    'centralindia',
    'eastasia',
    'eastus',
    'francecentral',
    'japaneast',
    'koreacentral',
    'northeurope',
    'southafricanorth',
    'switzerlandnorth',
    'uaenorth',
    'ukwest',
    'westindia'
]
LAB_REGIONS_ROW_2 = [
    'australiacentral2',
    'australiaeast',
    'brazilsouth',
    'canadaeast',
    'eastus2',
    'francesouth',
    'germanywestcentral',
    'japanwest',
    'koreasouth',
    'northcentralus',
    'norwayeast',
    'southindia',
    'southeastasia',
    'switzerlandwest',
    'uksouth',
    'westeurope',
    'westus',
    'westus2',
    'westus3'
]

SERVICE_TAGS_CANARY = [
    'AzureCloud.southcentralus',
    'AzureCloud.westus2'
]
SERVICE_TAGS_LOW_VOL = [
    'AzureCloud.southcentralus',
    'AzureCloud.westus'
]
SERVICE_TAGS_HIGH_VOL = [
    'AzureCloud.centralus',
    'AzureCloud.eastus'
]
SERVICE_TAGS_ROW_1 = [
    'AzureCloud.canadacentral',
    'AzureCloud.japaneast',
    'AzureCloud.eastasia',
    'AzureCloud.northeurope',
    'AzureCloud.australiaeast'
]
SERVICE_TAGS_ROW_2 = [
    'AzureCloud.northcentralus',
    'AzureCloud.southeastasia',
    'AzureCloud.uksouth',
    'AzureCloud.westus2',
    'AzureCloud.westeurope',
    'AzureCloud.australiaeast'
]

SERVICE_TAGS_ALL = [
    'AzureCloud.southcentralus',
    'AzureCloud.westus2',
    'AzureCloud.southcentralus',
    'AzureCloud.westus',
    'AzureCloud.centralus',
    'AzureCloud.eastus',
    'AzureCloud.canadacentral',
    'AzureCloud.japaneast',
    'AzureCloud.eastasia',
    'AzureCloud.northeurope',
    'AzureCloud.australiaeast',
    'AzureCloud.northcentralus',
    'AzureCloud.southeastasia',
    'AzureCloud.uksouth',
    'AzureCloud.westus2',
    'AzureCloud.westeurope',
    'AzureCloud.australiaeast'
]


def tag_key(key):
    return '{}{}'.format(TAG_PREFIX, key)


def get_resource_name(unique_string):
    return 'lgw{}a'.format(unique_string)


def get_function_name(prefix):
    return '{}-fa'.format(prefix)


def get_gateway_name(prefix):
    return '{}-gw'.format(prefix)


def get_gateway_waf_name(prefix):
    return '{}-gw-waf'.format(prefix)


def get_api_waf_name(prefix):
    return '{}-gw-waf-api'.format(prefix)


def get_service_tags(locations):

    locs = [l.lower().replace(' ', '') for l in locations]

    tags = []
    regions = []

    for loc in locs:
        if loc in LAB_REGIONS_CANARY and 'Canary' not in regions:
            regions.append('Canary')
        elif loc in LAB_REGIONS_LOW_VOL and 'LowVol' not in regions:
            regions.append('LowVol')
        elif loc in LAB_REGIONS_HIGH_VOL and 'HighVol' not in regions:
            regions.append('HighVol')
        elif loc in LAB_REGIONS_ROW_1 and 'ROW1' not in regions:
            regions.append('ROW1')
        elif loc in LAB_REGIONS_ROW_2 and 'ROW2' not in regions:
            regions.append('ROW2')

    if 'Canary' in regions:
        tags.extend(SERVICE_TAGS_CANARY)
    if 'LowVol' in regions:
        tags.extend(SERVICE_TAGS_LOW_VOL)
    if 'HighVol' in regions:
        tags.extend(SERVICE_TAGS_HIGH_VOL)
    if 'ROW1' in regions:
        tags.extend(SERVICE_TAGS_ROW_1)
    if 'ROW2' in regions:
        tags.extend(SERVICE_TAGS_ROW_2)

    for loc in locs:
        tag = 'AzureCloud.{}'.format(loc)
        if tag not in tags:
            tags.append(tag)

    return tags
