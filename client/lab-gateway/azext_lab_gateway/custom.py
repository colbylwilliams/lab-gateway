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
                            get_resource_group_tags, create_subnet, get_azure_rp_ips,
                            update_api_waf_policy, add_ips_gateway_waf_policy,
                            remove_ips_gateway_waf_policy)
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

    logger.warning('Deploying%s version: %s', ' prerelease' if prerelease else '', version)

    hook = cmd.cli_ctx.get_progress_controller()
    hook.begin()

    a_template = get_arm_template(arm_templates, 'deployA')
    b_template = get_arm_template(arm_templates, 'deployB')

    hook.add(message='Getting current user info')
    user_object_id, user_tenant_id = get_user_info(cmd)

    # Creating a subnet as a child resource via ARM results in conflicts, and more importantly,
    # redeploying a template will delete and recreate the subnet, i.e. if the subnet is in use,
    # the deployments will fail. https://github.com/Azure/bicep/issues/2579
    # thus for existing vnets we create the missing subnets here vs the ARM template
    if vnet_type == 'existing':
        if rdgateway_subnet_type == 'new':
            hook.add(message='Creating {}'.format(rdgateway_subnet))
            create_subnet(cmd, vnet, rdgateway_subnet, rdgateway_subnet_address_prefix)
        if appgateway_subnet_type == 'new':
            hook.add(message='Creating {}'.format(appgateway_subnet))
            create_subnet(cmd, vnet, appgateway_subnet, appgateway_subnet_address_prefix)
        if bastion_subnet_type == 'new':
            hook.add(message='Creating {}'.format(bastion_subnet))
            create_subnet(cmd, vnet, bastion_subnet, bastion_subnet_address_prefix)

    a_params = []
    a_params.append('location={}'.format(location))
    a_params.append('resourcePrefix={}'.format(resource_prefix))
    a_params.append('userId={}'.format(user_object_id))
    a_params.append('tenantId={}'.format(user_tenant_id))
    a_params.append('tags={}'.format(json.dumps(tags)))

    # deployA template creates a keyvault, storage account, and log analytics workspace
    hook.add(message='Creating keyvault and storage account')
    _, a_outputs = deploy_arm_template_at_resource_group(cmd, resource_group_name, template_uri=a_template,
                                                         parameters=[a_params])

    keyvault_name = get_arm_output(a_outputs, 'keyvaultName')
    storage_connection_string = get_arm_output(a_outputs, 'storageConnectionString')
    storage_artifacts_container = get_arm_output(a_outputs, 'artifactsContainerName')

    cert_name = 'SSLCertificate'
    # import the ssl cert required by the application gateway and vmwss
    hook.add(message='Importing SSL certificate to keyvault')
    _, cert_cn, cert_secret_url = import_certificate(cmd, keyvault_name, cert_name, ssl_cert,
                                                     password=ssl_cert_password)

    artifact_items = [get_artifact(artifacts, i) for i in artifacts]

    BlobServiceClient = get_sdk(cmd.cli_ctx, ResourceType.DATA_STORAGE_BLOB,
                                '_blob_service_client#BlobServiceClient')
    blob_service_client = BlobServiceClient.from_connection_string(storage_connection_string)

    # upload the artifacts from the github repo
    for artifact_name, artifact_url in artifact_items:
        hook.add(message='Uploading {} to storage'.format(artifact_name))
        blob_client = blob_service_client.get_blob_client(storage_artifacts_container, artifact_name)
        blob_exists = blob_client.exists()
        if not blob_exists:
            response = requests.get(artifact_url)
            blob_client.upload_blob(response.content)

    # upload the RDGatewayFedAuth file
    hook.add(message='Uploading RDGatewayFedAuth.msi to storage')
    blob_client = blob_service_client.get_blob_client(storage_artifacts_container, 'RDGatewayFedAuth.msi')
    blob_exists = blob_client.exists()
    if not blob_exists:
        blob_client.upload_blob(auth_msi)

    b_params = []
    b_params.append('location={}'.format(location))
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
    b_params.append('vnetAddressPrefixes={}'.format(json.dumps([vnet_address_prefix])))

    b_params.append('gatewaySubnetName={}'.format(rdgateway_subnet))
    if rdgateway_subnet_address_prefix is not None:
        b_params.append('gatewaySubnetAddressPrefix={}'.format(rdgateway_subnet_address_prefix))

    if bastion_subnet_address_prefix is not None:
        b_params.append('bastionSubnetAddressPrefix={}'.format(bastion_subnet_address_prefix))

    b_params.append('appGatewaySubnetName={}'.format(appgateway_subnet))
    if appgateway_subnet_address_prefix is not None:
        b_params.append('appGatewaySubnetAddressPrefix={}'.format(appgateway_subnet_address_prefix))

    b_params.append('privateIPAddress={}'.format('' if private_ip_address is None else private_ip_address))

    hook.add(message='Getting Azure Cloud Resource Provider IPs')
    azure_rp_ips = get_azure_rp_ips(cmd, location)
    b_params.append('azureResourceProviderIps={}'.format(json.dumps(azure_rp_ips)))

    b_params.append('tags={}'.format(json.dumps(tags)))

    # deployB template creates a the rest of the solution
    hook.add(message='Deploying solution')
    _, b_outputs = deploy_arm_template_at_resource_group(cmd, resource_group_name, template_uri=b_template,
                                                         parameters=[b_params])

    function_name = get_arm_output(b_outputs, 'functionName')
    public_ip = get_arm_output(b_outputs, 'publicIpAddress')
    vnet_id = get_arm_output(b_outputs, 'vnetId')

    # create the function key for the CreatToken function if it does not exist
    hook.add(message='Generating auth token')
    _ = get_function_key(cmd, resource_group_name, function_name, 'CreateToken', 'gateway')

    tags.update({tag_key('creator'): user_object_id})
    tags.update({tag_key('hostname'): cert_cn})
    tags.update({tag_key('function'): function_name})
    tags.update({tag_key('publicIp'): public_ip})
    tags.update({tag_key('vnet'): vnet_id})
    tags.update({tag_key('privateIp'): '{}'.format(private_ip_address)})
    tags.update({tag_key('prefix'): '{}'.format(resource_prefix)})
    tags.update({tag_key('locations'): json.dumps(['{}'.format(location.lower().replace(' ', ''))])})

    # apply the tags at the resource group level
    hook.add(message='Tagging resource group')
    _ = tag_resource_group(cmd, resource_group_name, tags)

    sub = get_subscription_id(cmd.cli_ctx)

    hook.end(message=' ')
    logger.warning(' ')
    logger.warning('Gateway successfully created with the public IP address: %s', public_ip)
    logger.warning('')
    logger.warning('IMPORTANT: to complete setup you must register Gateway with your DNS')
    logger.warning('           by creating an A-Record: %s -> %s', cert_cn, public_ip)
    logger.warning('')

    result = {}
    result.update({'location': '{}'.format(location)})
    result.update({'subscription': sub})
    result.update({'resourceGroup': '{}'.format(resource_group_name)})

    for k in tags:
        if k.startswith(TAG_PREFIX):
            result.update({k.split(':')[1]: tags.get(k, None)})

    return result


def lab_gateway_show(cmd, resource_group_name, resource_prefix):
    tags = get_resource_group_tags(cmd, resource_group_name)
    sub = get_subscription_id(cmd.cli_ctx)

    result = {}

    # result.update({'location': location})
    result.update({'subscription': sub})
    result.update({'resourceGroup': resource_group_name})

    for k in tags:
        if k.startswith(TAG_PREFIX):
            result.update({k.split(':')[1]: tags.get(k, None)})

    return result


def lab_gateway_lab_connect(cmd, resource_group_name, lab_name, gateway_resource_group_name, resource_prefix,
                            lab_location=None, gateway_function_name=None, gateway_hostname=None,
                            gateway_locations=None, version=None, prerelease=False, index_url=None):

    version, _, arm_templates, _ = get_release_index(version, prerelease, index_url)

    logger.warning('Connecting lab using%s version: %s', ' prerelease' if prerelease else '', version)

    # foo = {
    #     'resource_group_name': '{}'.format(resource_group_name),
    #     'lab_name': '{}'.format(lab_name),
    #     'gateway_resource_group_name': '{}'.format(gateway_resource_group_name),
    #     'resource_prefix': '{}'.format(resource_prefix),
    #     'lab_location': '{}'.format(lab_location),
    #     'gateway_function_name': '{}'.format(gateway_function_name),
    #     'gateway_hostname': '{}'.format(gateway_hostname),
    #     'gateway_locations': '{}'.format(gateway_locations)
    # }

    # return foo

    hook = cmd.cli_ctx.get_progress_controller()
    hook.begin()

    template = get_arm_template(arm_templates, 'connect')

    hook.add(message='Getting gateway auth token')
    token = get_function_key(cmd, gateway_resource_group_name, gateway_function_name, 'CreateToken', 'gateway')

    if lab_location not in gateway_locations:
        hook.add(message='Adding {} Azure region IP addresses to gateway allow list'.format(lab_location))
        gateway_locations.append(lab_location)
        _ = update_api_waf_policy(cmd, resource_prefix, gateway_resource_group_name, gateway_locations)

    tags = {}
    tags.update({tag_key('locations'): json.dumps(gateway_locations)})

    hook.add(message='Updating gateway resource group tags')
    _ = tag_resource_group(cmd, gateway_resource_group_name, tags)

    params = []
    params.append('labName={}'.format(lab_name))
    params.append('location={}'.format(lab_location))
    params.append('gatewayHostname={}'.format(gateway_hostname))
    params.append('gatewayToken={}'.format(token))

    hook.add(message='Adding gateway settings to lab')
    result, _ = deploy_arm_template_at_resource_group(cmd, resource_group_name, template_uri=template,
                                                      parameters=[params])
    hook.end(message=' ')
    logger.warning(' ')

    result = {}

    # result.update({'location': location})
    result.update({'lab': lab_name})
    result.update({'labLocation': lab_location})
    result.update({'labResourceGroup': resource_group_name})
    result.update({'gatewayHostname': gateway_hostname})
    result.update({'gatewayResourceGroup': gateway_resource_group_name})

    return result


def lab_gateway_token_show(cmd, resource_group_name, resource_prefix, gateway_function_name=None):
    return get_function_key(cmd, resource_group_name, gateway_function_name, 'CreateToken', 'gateway')


def lab_gateway_ip_add(cmd, resource_group_name, resource_prefix, ips):
    ips = add_ips_gateway_waf_policy(cmd, resource_prefix, resource_group_name, ips)
    return ips


def lab_gateway_ip_remove(cmd, resource_group_name, resource_prefix, ips):
    ips = remove_ips_gateway_waf_policy(cmd, resource_prefix, resource_group_name, ips)
    return ips
