# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------
# pylint: disable=too-many-statements, too-many-locals

import json
from time import sleep
from knack.log import get_logger
from knack.util import CLIError
from msrestazure.tools import resource_id, parse_resource_id
from azure.cli.core.commands import LongRunningOperation
from azure.cli.core.commands.client_factory import get_subscription_id
from azure.cli.core.profiles import ResourceType, get_sdk
from azure.cli.core.util import (random_string, sdk_no_wait)
from azure.cli.core.azclierror import ResourceNotFoundError

from ._client_factory import (resource_client_factory, web_client_factory, network_client_factory)
from ._utils import same_location

TRIES = 3

logger = get_logger(__name__)

# pylint: disable=inconsistent-return-statements


def deploy_arm_template_at_resource_group(cmd, resource_group_name=None, template_file=None,
                                          template_uri=None, parameters=None, no_wait=False):

    from azure.cli.command_modules.resource.custom import _prepare_deployment_properties_unmodified   # pylint: disable=import-outside-toplevel

    properties = _prepare_deployment_properties_unmodified(cmd, 'resourceGroup', template_file=template_file,
                                                           template_uri=template_uri, parameters=parameters,
                                                           mode='Incremental')

    client = resource_client_factory(cmd.cli_ctx).deployments

    for try_number in range(TRIES):
        try:
            deployment_name = random_string(length=14, force_lower=True) + str(try_number)

            Deployment = cmd.get_models('Deployment', resource_type=ResourceType.MGMT_RESOURCE_RESOURCES)
            deployment = Deployment(properties=properties)

            deploy_poll = sdk_no_wait(no_wait, client.begin_create_or_update, resource_group_name,
                                      deployment_name, deployment)

            result = LongRunningOperation(cmd.cli_ctx, start_msg='Deploying ARM template',
                                          finish_msg='Finished deploying ARM template')(deploy_poll)

            props = getattr(result, 'properties', None)
            return result, getattr(props, 'outputs', None)
        except CLIError as err:
            if try_number == TRIES - 1:
                raise err
            try:
                response = getattr(err, 'response', None)
                message = json.loads(response.text)['error']['details'][0]['message']
                if '(ServiceUnavailable)' not in message:
                    raise err
            except:
                raise err from err
            sleep(5)
            continue


def get_arm_output(outputs, key, raise_on_error=True):
    try:
        value = outputs[key]['value']
    except KeyError as e:
        if raise_on_error:
            raise CLIError(
                "A value for '{}' was not provided in the ARM template outputs".format(key)) from e
        value = None

    return value


def get_function_key(cmd, resource_group_name, function_app_name, function_name, key_name):
    web_client = web_client_factory(cmd.cli_ctx).web_apps

    keys = web_client.list_function_keys(resource_group_name, function_app_name, function_name)

    try:
        key = keys.additional_properties[key_name]
        return key
    except KeyError:
        KeyInfo = get_sdk(cmd.cli_ctx, ResourceType.MGMT_APPSERVICE, 'KeyInfo', mod='models')

        # pylint: disable=protected-access
        key_info = KeyInfo(name=key_name, value=None)
        KeyInfo._attribute_map = {
            'name': {'key': 'properties.name', 'type': 'str'},
            'value': {'key': 'properties.value', 'type': 'str'},
        }
        new_key = web_client.create_or_update_function_secret(resource_group_name, function_app_name,
                                                              function_name, key_name, key_info)

        return new_key.value


def get_azure_rp_ips(cmd, location):

    client = network_client_factory(cmd.cli_ctx).service_tags
    service_tags = client.list(location)

    bcdrs = []
    if same_location(location, 'centralus'):
        bcdrs = ['AzureCloud.centralus', 'AzureCloud.eastus']
    elif same_location(location, 'eastus'):
        bcdrs = ['AzureCloud.eastus', 'AzureCloud.canadacentral', 'AzureCloud.japaneast', 'AzureCloud.eastasia',
                 'AzureCloud.northeurope', 'AzureCloud.australiaeast']
    elif same_location(location, 'eastus2'):
        bcdrs = ['AzureCloud.eastus2', 'AzureCloud.northcentralus', 'AzureCloud.southeastasia',
                 'AzureCloud.uksouth', 'AzureCloud.westus2', 'AzureCloud.westeurope', 'AzureCloud.australiaeast']

    ips = []
    if bcdrs:
        ips = [a for tag in service_tags.values if tag.id in bcdrs for a in tag.properties.address_prefixes]
        ips = list(dict.fromkeys(ips))  # unique
    else:
        tag = next(t for t in service_tags.values if t.id == 'AzureCloud')
        ips = tag.properties.address_prefixes

    return ips


# def update_gateway_ip_rule(cmd):
    # WebApplicationFirewallCustomRule, MatchCondition, MatchVariable = cmd.get_models(
    #     'WebApplicationFirewallCustomRule', 'MatchCondition', 'MatchVariable',
    #     resource_type=ResourceType.MGMT_NETWORK)

    # match_conditions = [MatchCondition(
    #     match_variables=[MatchVariable(variable_name='RequestUri')],
    #     operator='IPMatch',
    #     negation_conditon=True,
    #     match_values=t.properties.address_prefixes
    # ) for t in service_tags.values if t.id in bcdrs]


def _asn1_to_iso8601(asn1_date):
    import dateutil.parser  # pylint: disable=import-outside-toplevel
    if isinstance(asn1_date, bytes):
        asn1_date = asn1_date.decode('utf-8')
    return dateutil.parser.parse(asn1_date)


def import_certificate(cmd, vault_name, certificate_name, certificate_data,
                       disabled=False, password=None, certificate_policy=None, tags=None):
    import binascii  # pylint: disable=import-outside-toplevel
    from OpenSSL import crypto  # pylint: disable=import-outside-toplevel
    CertificateAttributes, SecretProperties, CertificatePolicy = cmd.get_models(
        'CertificateAttributes', 'SecretProperties', 'CertificatePolicy',
        resource_type=ResourceType.DATA_KEYVAULT)
    # CertificateAttributes = cmd.get_models('CertificateAttributes', resource_type=ResourceType.DATA_KEYVAULT)
    # SecretProperties = cmd.get_models('SecretProperties', resource_type=ResourceType.DATA_KEYVAULT)
    # CertificatePolicy = cmd.get_models('CertificatePolicy', resource_type=ResourceType.DATA_KEYVAULT)

    x509 = None
    content_type = None
    try:
        x509 = crypto.load_certificate(crypto.FILETYPE_PEM, certificate_data)
        # if we get here, we know it was a PEM file
        content_type = 'application/x-pem-file'
        try:
            # for PEM files (including automatic endline conversion for Windows)
            certificate_data = certificate_data.decode('utf-8').replace('\r\n', '\n')
        except UnicodeDecodeError:
            certificate_data = binascii.b2a_base64(certificate_data).decode('utf-8')
    except (ValueError, crypto.Error):
        pass

    if not x509:
        try:
            if password:
                x509 = crypto.load_pkcs12(certificate_data, password).get_certificate()
            else:
                x509 = crypto.load_pkcs12(certificate_data).get_certificate()
            content_type = 'application/x-pkcs12'
            certificate_data = binascii.b2a_base64(certificate_data).decode('utf-8')
        except crypto.Error as e:
            raise CLIError(
                'We could not parse the provided certificate as .pem or .pfx.'
                'Please verify the certificate with OpenSSL.') from e

    not_before, not_after = None, None

    cn = x509.get_subject().CN

    if x509.get_notBefore():
        not_before = _asn1_to_iso8601(x509.get_notBefore())

    if x509.get_notAfter():
        not_after = _asn1_to_iso8601(x509.get_notAfter())

    cert_attrs = CertificateAttributes(
        enabled=not disabled,
        not_before=not_before,
        expires=not_after)

    if certificate_policy:
        secret_props = certificate_policy.get('secret_properties')
        if secret_props:
            secret_props['content_type'] = content_type
        elif certificate_policy and not secret_props:
            certificate_policy['secret_properties'] = SecretProperties(content_type=content_type)

        attributes = certificate_policy.get('attributes')
        if attributes:
            attributes['created'] = None
            attributes['updated'] = None
    else:
        certificate_policy = CertificatePolicy(
            secret_properties=SecretProperties(content_type=content_type))

    vault_base_url = 'https://{}{}'.format(vault_name, cmd.cli_ctx.cloud.suffixes.keyvault_dns)

    logger.info("Starting 'keyvault certificate import'")
    from ._client_factory import keyvault_data_client_factory  # pylint: disable=import-outside-toplevel
    client = keyvault_data_client_factory(cmd.cli_ctx)
    result = client.import_certificate(vault_base_url=vault_base_url,
                                       certificate_name=certificate_name,
                                       base64_encoded_certificate=certificate_data,
                                       password=password,
                                       certificate_policy=certificate_policy,
                                       certificate_attributes=cert_attrs,
                                       tags=tags)
    logger.info("Finished 'keyvault certificate import'")

    if result.sid is None:
        raise ResourceNotFoundError('Unable to get certificate secret uri from import result')

    secret_url = result.sid.rsplit('/', 1)[0]

    return result, cn, secret_url


def create_subnet(cmd, vnet, subnet_name, address_prefix):
    Subnet = cmd.get_models('Subnet', resource_type=ResourceType.MGMT_NETWORK)

    vnet_parts = parse_resource_id(vnet)

    vnet_name = vnet_parts['name']
    resource_group_name = vnet_parts['resource_group']

    subnet = Subnet(name=subnet_name, address_prefix=address_prefix)
    subnet.private_endpoint_network_policies = "Disabled"
    subnet.private_link_service_network_policies = "Enabled"

    client = network_client_factory(cmd.cli_ctx).subnets

    create_poller = client.begin_create_or_update(resource_group_name, vnet_name, subnet_name, subnet)

    result = LongRunningOperation(cmd.cli_ctx, start_msg='Creating {}'.format(subnet_name),
                                  finish_msg='Finished creating {}'.format(subnet_name))(create_poller)

    logger.warning(result)

    return result


def tag_resource_group(cmd, resource_group_name, tags):
    Tags, TagsPatchResource = cmd.get_models(
        'Tags', 'TagsPatchResource', resource_type=ResourceType.MGMT_RESOURCE_RESOURCES)

    sub = get_subscription_id(cmd.cli_ctx)
    scope = resource_id(subscription=sub, resource_group=resource_group_name)

    properties = Tags(tags=tags)
    paramaters = TagsPatchResource(operation='Merge', properties=properties)

    client = resource_client_factory(cmd.cli_ctx).tags

    result = client.update_at_scope(scope, paramaters)

    return result


def get_resource_group_tags(cmd, resource_group_name):
    sub = get_subscription_id(cmd.cli_ctx)
    scope = resource_id(subscription=sub, resource_group=resource_group_name)

    client = resource_client_factory(cmd.cli_ctx).tags

    result = client.get_at_scope(scope)

    return result.properties.tags
