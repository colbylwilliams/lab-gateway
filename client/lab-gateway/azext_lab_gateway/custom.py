# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------
# pylint: disable=unused-argument, too-many-statements, too-many-locals, too-many-lines

import json
import requests
from knack.log import get_logger
from azure.cli.core.profiles import ResourceType, get_sdk
from azure.cli.core.commands.client_factory import get_subscription_id
from ._utils import (get_user_info)
from ._github_utils import (get_release_index, get_arm_template, get_artifact)
from ._deploy_utils import (get_function_key, get_arm_output, import_certificate,
                            deploy_arm_template_at_resource_group, tag_resource_group,
                            get_resource_group_tags, create_subnet)
from ._constants import TAG_PREFIX, tag_key


logger = get_logger(__name__)


def lab_gateway_create(cmd, resource_group_name, admin_username, admin_password, auth_msi,
                       resource_prefix, ssl_cert, ssl_cert_password, instance_count=1, token_lifetime=1,
                       vnet=None, vnet_address_prefix='10.0.0.0/16', vnet_type=None,
                       rdgateway_subnet='RDGatewaySubnet', rdgateway_subnet_address_prefix='10.0.0.0/24',
                       appgateway_subnet='AppGatewaySubnet', appgateway_subnet_address_prefix='10.0.2.0/26',
                       bastion_subnet='AzureBastionSubnet', bastion_subnet_address_prefix='10.0.1.0/27',
                       rdgateway_subnet_type=None, appgateway_subnet_type=None, bastion_subnet_type=None,
                       public_ip_address=None, public_ip_address_type=None, private_ip_address='10.0.2.5',
                       location=None, tags=None, version=None, prerelease=False, index_url=None):

    version, _, arm_templates, artifacts = get_release_index(version, prerelease, index_url)

    a_template = get_arm_template(arm_templates, 'deployA')
    b_template = get_arm_template(arm_templates, 'deployB')

    user_object_id, user_tenant_id = get_user_info(cmd)

    if vnet_type == 'existing':
        if rdgateway_subnet_type == 'new':
            create_subnet(cmd, vnet, rdgateway_subnet, rdgateway_subnet_address_prefix)
        if appgateway_subnet_type == 'new':
            create_subnet(cmd, vnet, appgateway_subnet, appgateway_subnet_address_prefix)
        if bastion_subnet_type == 'new':
            create_subnet(cmd, vnet, bastion_subnet, bastion_subnet_address_prefix)

    a_params = []
    a_params.append('resourcePrefix={}'.format(resource_prefix))
    a_params.append('userId={}'.format(user_object_id))
    a_params.append('tenantId={}'.format(user_tenant_id))
    a_params.append('tags={}'.format(json.dumps(tags)))

    _, a_outputs = deploy_arm_template_at_resource_group(cmd, resource_group_name, template_uri=a_template,
                                                         parameters=[a_params])

    keyvault_name = get_arm_output(a_outputs, 'keyvaultName')
    storage_connection_string = get_arm_output(a_outputs, 'storageConnectionString')
    storage_artifacts_container = get_arm_output(a_outputs, 'artifactsContainerName')

    cert_name = 'SSLCertificate'
    _, cert_cn, cert_secret_url = import_certificate(cmd, keyvault_name, cert_name, ssl_cert,
                                                     password=ssl_cert_password)

    artifact_items = [get_artifact(artifacts, i) for i in artifacts]

    BlobServiceClient = get_sdk(cmd.cli_ctx, ResourceType.DATA_STORAGE_BLOB,
                                '_blob_service_client#BlobServiceClient')

    blob_service_client = BlobServiceClient.from_connection_string(storage_connection_string)

    for artifact_name, artifact_url in artifact_items:
        blob_client = blob_service_client.get_blob_client(storage_artifacts_container, artifact_name)
        response = requests.get(artifact_url)
        blob_client.upload_blob(response.content)

    blob_client = blob_service_client.get_blob_client(storage_artifacts_container, 'RDGatewayFedAuth.msi')
    blob_client.upload_blob(auth_msi)

    b_params = []
    b_params.append('resourcePrefix={}'.format(resource_prefix))
    b_params.append('adminUsername={}'.format(admin_username))
    b_params.append('adminPassword={}'.format(admin_password))
    b_params.append('tokenLifetime={}'.format(token_lifetime))
    b_params.append('hostName={}'.format(cert_cn))
    b_params.append('sslCertificateSecretUri={}'.format(cert_secret_url))
    b_params.append('vnet={}'.format('' if vnet is None else vnet))
    b_params.append('publicIPAddress={}'.format('' if public_ip_address is None else public_ip_address))
    b_params.append('tokenPrivateEndpoint={}'.format('false'))
    b_params.append('instanceCount={}'.format(instance_count))
    b_params.append('vnetAddressPrefixs={}'.format(json.dumps([vnet_address_prefix])))

    b_params.append('gatewaySubnetName={}'.format(rdgateway_subnet))
    if rdgateway_subnet_address_prefix is not None:
        b_params.append('gatewaySubnetAddressPrefix={}'.format(rdgateway_subnet_address_prefix))

    if bastion_subnet_address_prefix is not None:
        b_params.append('bastionSubnetAddressPrefix={}'.format(bastion_subnet_address_prefix))

    b_params.append('appGatewaySubnetName={}'.format(appgateway_subnet))
    if appgateway_subnet_address_prefix is not None:
        b_params.append('appGatewaySubnetAddressPrefix={}'.format(appgateway_subnet_address_prefix))

    # b_params.append('firewallSubnetName={}'.format())
    # b_params.append('firewallSubnetAddressPrefix={}'.format())

    b_params.append('privateIPAddress={}'.format('' if private_ip_address is None else private_ip_address))
    b_params.append('tags={}'.format(json.dumps(tags)))

    _, b_outputs = deploy_arm_template_at_resource_group(cmd, resource_group_name, template_uri=b_template,
                                                         parameters=[b_params])

    function_name = get_arm_output(b_outputs, 'functionName')
    public_ip = get_arm_output(b_outputs, 'publicIpAddress')
    vnet_id = get_arm_output(b_outputs, 'vnetId')

    _ = get_function_key(cmd, resource_group_name, function_name, 'CreateToken', 'gateway')

    tags.update({tag_key('creator'): user_object_id})
    tags.update({tag_key('hostname'): cert_cn})
    tags.update({tag_key('function'): function_name})
    tags.update({tag_key('publicIp'): public_ip})
    tags.update({tag_key('privateIp'): private_ip_address})
    tags.update({tag_key('vnet'): vnet_id})
    tags.update({tag_key('prefix'): resource_prefix})

    _ = tag_resource_group(cmd, resource_group_name, tags)

    logger.warning('')
    logger.warning('Gateway successfully created with the public IP address: %s', public_ip)
    logger.warning('')
    logger.warning('IMPORTANT: to complete setup you must register Gateway with your DNS')
    logger.warning('by creating an A-Record: %s -> %s', cert_cn, public_ip)
    logger.warning('')

    allargs = {
        'public_ip': '{}'.format(public_ip),
        'resourcePrefix': '{}'.format(resource_prefix),
        'keyvault_name': '{}'.format(keyvault_name),
        'storage_connection_string': '******',
        'storage_artifacts_container': '{}'.format(storage_artifacts_container),
        'resource_group_name': '{}'.format(resource_group_name),
        'location': '{}'.format(location),
        # 'tags': '{}'.format(tags),
        'admin_username': '{}'.format(admin_username),
        'admin_password': '******',
        'ssl_cert_password': '******',
        'instance_count': '{}'.format(instance_count),
        'token_lifetime': '{}'.format(token_lifetime),
        'vnet': '{}'.format(vnet),
        # 'vnet_type': '{}'.format(vnet_type),
        'vnet_address_prefix': '{}'.format(vnet_address_prefix),
        'rdgateway_subnet': '{}'.format(rdgateway_subnet),
        'rdgateway_subnet_address_prefix': '{}'.format(rdgateway_subnet_address_prefix),
        # 'rdgateway_subnet_type': '{}'.format(rdgateway_subnet_type),
        'appgateway_subnet': '{}'.format(appgateway_subnet),
        'appgateway_subnet_address_prefix': '{}'.format(appgateway_subnet_address_prefix),
        # 'appgateway_subnet_type': '{}'.format(appgateway_subnet_type),
        'bastion_subnet': '{}'.format(bastion_subnet),
        'bastion_subnet_address_prefix': '{}'.format(bastion_subnet_address_prefix),
        # 'bastion_subnet_type': '{}'.format(bastion_subnet_type),
        'private_ip_address': '{}'.format(private_ip_address),
        'public_ip_address': '{}'.format(public_ip_address),
        # 'public_ip_address_type': '{}'.format(public_ip_address_type),
        'version': '{}'.format(version),
        'prerelease': '{}'.format(prerelease),
        'index_url': '{}'.format(index_url),
        # 'scale_set_name': '{}'.format(scale_set_name),
        'function_name': '{}'.format(function_name),
    }

    return allargs


def lab_gateway_show(cmd, resource_group_name, resource_prefix):
    tags = get_resource_group_tags(cmd, resource_group_name)
    sub = get_subscription_id(cmd.cli_ctx)

    result = {}

    result.update({'subscriptionId': sub})
    result.update({'resourceGroup': resource_group_name})

    for k in tags:
        if k.startswith(TAG_PREFIX):
            result.update({k.split(':')[1]: tags.get(k, None)})

    return result


def lab_gateway_connect(cmd, resource_group_name, resource_prefix, lab_resource_group_name, lab,
                        function_name=None, gateway_hostname=None,
                        version=None, prerelease=False, index_url=None):

    _, _, arm_templates, _ = get_release_index(version, prerelease, index_url)

    template = get_arm_template(arm_templates, 'connect')

    token = get_function_key(cmd, resource_group_name, function_name, 'CreateToken', 'gateway')

    params = []
    params.append('labName={}'.format(lab))
    params.append('gatewayHostname={}'.format(gateway_hostname))
    params.append('gatewayToken={}'.format(token))

    result, _ = deploy_arm_template_at_resource_group(cmd, lab_resource_group_name, template_uri=template,
                                                      parameters=[params])

    return result


def lab_gateway_token_show(cmd, resource_group_name, resource_prefix, function_name=None):
    return get_function_key(cmd, resource_group_name, function_name, 'CreateToken', 'gateway')
