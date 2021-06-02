# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------
# pylint: disable=too-many-statements, too-many-locals, too-many-lines

import os
import ipaddress
from re import match
from knack.log import get_logger
from msrestazure.tools import resource_id  # , parse_resource_id
from azure.core.exceptions import ResourceNotFoundError
from azure.cli.core.azclierror import (MutuallyExclusiveArgumentError, InvalidArgumentValueError)
from azure.cli.core.commands.client_factory import get_subscription_id
from azure.cli.core.commands.validators import (get_default_location_from_resource_group,
                                                validate_tags)
from azure.cli.core.commands.template_create import (_validate_name_or_id)
from azure.cli.core.extension import get_extension
from azure.cli.core.util import hash_string

from ._github_utils import (github_release_version_exists, get_github_latest_release_version)
from ._deploy_utils import (get_resource_group_tags)
from ._client_factory import (network_client_factory, labs_client_factory)
from ._constants import (tag_key, get_resource_name, get_function_name)
from ._utils import (get_tag, same_location)


logger = get_logger(__name__)


def none_or_empty(val):
    return val in ('', '""', "''") or val is None


def get_public_ip(cmd, parts):
    client = network_client_factory(cmd.cli_ctx).public_ip_addresses
    rg, name = parts['resource_group'], parts['name']
    if not all([rg, name]):
        return None
    try:
        vnet = client.get(rg, name)
        return vnet
    except ResourceNotFoundError:
        return None


def get_vnet(cmd, parts):
    client = network_client_factory(cmd.cli_ctx).virtual_networks
    rg, name = parts['resource_group'], parts['name']
    if not all([rg, name]):
        return None
    try:
        vnet = client.get(rg, name)
        return vnet
    except ResourceNotFoundError:
        return None


def get_subnet(cmd, parts):
    client = network_client_factory(cmd.cli_ctx).subnets
    rg, vnet, name = parts['resource_group'], parts['name'], parts['child_name_1']
    if not all([rg, vnet, name]):
        return None
    try:
        subnet = client.get(rg, vnet, name)
        return subnet
    except ResourceNotFoundError:
        return None


def get_lab(cmd, parts):
    client = labs_client_factory(cmd.cli_ctx).labs
    rg, name = parts['resource_group'], parts['name']
    if not all([rg, name]):
        return None
    try:
        lab = client.get(rg, name)
        return lab
    except ResourceNotFoundError:
        return None


def get_lab_vnets(cmd, parts):
    client = labs_client_factory(cmd.cli_ctx).virtual_networks
    rg, name = parts['resource_group'], parts['name']
    if not all([rg, name]):
        return None
    try:
        lab = client.list(rg, name, expand="properties($expand=externalSubnets)")
        return lab
    except ResourceNotFoundError:
        return None


def process_gateway_create_namespace(cmd, ns):
    get_default_location_from_resource_group(cmd, ns)
    validate_resource_prefix(cmd, ns)
    index_version_validator(cmd, ns)
    validate_gateway_tags(ns)
    validate_token_lifetime(cmd, ns)
    validate_vnet(cmd, ns)
    validate_public_ip(cmd, ns)


def process_gateway_connect_namespace(cmd, ns):
    validate_resource_prefix(cmd, ns)
    index_version_validator(cmd, ns)

    tags = get_resource_group_tags(cmd, ns.resource_group_name)
    validate_function_name(ns, tags)
    validate_gateway_hostname(ns, tags)

    lab_parts, _ = _validate_name_or_id(
        cmd.cli_ctx, ns.lab_resource_group_name, ns.lab, 'Microsoft.DevTestLab/labs',
        parent_value=None, parent_type=None)

    lab = get_lab(cmd, lab_parts)
    if lab:
        # ns.lab = lab_parts['name']
        ns.lab = lab.name
        ns.location = lab.location
    else:
        raise ResourceNotFoundError('Lab {} not found'.format(ns.lab))

    # lab_vnets = get_lab_vnets(cmd, lab_parts)

    # for lab_vnet in lab_vnets:
    #     logger.warning('vnet.name: %s', lab_vnet.name)
    #     logger.warning('vnet.external_provider_resource_id: %s', lab_vnet.external_provider_resource_id)
    #     logger.warning('')

    #     allowed_subnets = lab_vnet.allowed_subnets
    #     external_subnets = lab_vnet.external_subnets
    #     subnet_overrides = lab_vnet.subnet_overrides

    #     if allowed_subnets:
    #         logger.warning('  allowed_subnets:')
    #         for allowed_subnet in allowed_subnets:
    #             logger.warning('    resource_id: %s', allowed_subnet.resource_id)
    #             logger.warning('    lab_subnet_name: %s', allowed_subnet.lab_subnet_name)
    #             logger.warning('    allow_public_ip: %s', allowed_subnet.allow_public_ip)
    #             logger.warning(' ')

    #         logger.warning(' ')

    #     if external_subnets:
    #         logger.warning('  external_subnets:')
    #         for external_subnet in external_subnets:
    #             logger.warning('    id: %s', external_subnet.id)
    #             logger.warning('    name: %s', external_subnet.name)
    #             logger.warning('    ')

    #         logger.warning('    ')

    #     if external_subnets:
    #         logger.warning('  subnet_overrides:')
    #         for subnet_override in subnet_overrides:
    #             logger.warning('    resource_id: %s:', subnet_override.resource_id)
    #             logger.warning('    lab_subnet_name: %s:', subnet_override.lab_subnet_name)
    #             logger.warning('    use_in_vm_creation_permission: %s:',
    #                            subnet_override.use_in_vm_creation_permission)
    #             logger.warning('    use_public_ip_address_permission: %s:',
    #                            subnet_override.use_public_ip_address_permission)
    #             logger.warning('    shared_public_ip_address_configuration: %s:',
    #                            subnet_override.shared_public_ip_address_configuration)
    #             logger.warning('    virtual_network_pool_name: %s:',
    #                            subnet_override.virtual_network_pool_name)
    #             logger.warning('    ')

    #         logger.warning(' ')

    #     logger.warning(' ')

    # vnets = [get_vnet(cmd, parse_resource_id(v.external_provider_resource_id)) for v in lab_vnets]

    # ns.lab_vnets = [v.id for v in vnets]
    # ns.lab_keyvault = lab.vault_name


def process_gateway_show_namespace(cmd, ns):
    validate_resource_prefix(cmd, ns)


def process_gateway_token_namespace(cmd, ns):
    validate_resource_prefix(cmd, ns)
    tags = get_resource_group_tags(cmd, ns.resource_group_name)
    validate_function_name(ns, tags)


def validate_function_name(ns, tags):
    function_name = get_tag(tags, 'function')

    if not function_name:
        prefix = get_tag(tags, 'prefix')
        function_name = get_function_name(prefix) if prefix else get_function_name(ns.resource_prefix)

    if not function_name:
        raise ResourceNotFoundError('Unable to resolve function app name from resource group')

    ns.function_name = function_name


def validate_gateway_hostname(ns, tags):
    hostname = get_tag(tags, 'hostname')

    if not hostname:
        raise ResourceNotFoundError('Unable to resolve gateway hostname from resource group')

    # TODO: resolve from gateway

    ns.gateway_hostname = hostname


def validate_resource_prefix(cmd, ns):
    sub = get_subscription_id(cmd.cli_ctx)
    resource_group_name_upper = ns.resource_group_name.upper()
    group_id = resource_id(subscription=sub, resource_group=resource_group_name_upper)
    unique_string = hash_string(group_id, length=12, force_lower=True)
    prefix = get_resource_name(unique_string)
    ns.resource_prefix = prefix


def validate_gateway_tags(ns):
    if ns.tags:
        validate_tags(ns)

    tags_dict = {} if ns.tags is None else ns.tags

    if ns.version:
        tags_dict.update({tag_key('version'): ns.version})
    if ns.prerelease:
        tags_dict.update({tag_key('prerelease'): ns.prerelease})

    ext = get_extension('lab-gateway')
    cur_version = ext.get_version()
    cur_version_str = 'v{}'.format(cur_version)

    tags_dict.update({tag_key('cli'): cur_version_str})

    ns.tags = tags_dict


def validate_vnet(cmd, ns):
    subnets = ['rdgateway', 'appgateway', 'bastion']

    # Create a resource ID we can check for existence.
    vnet_parts, _ = _validate_name_or_id(
        cmd.cli_ctx, ns.resource_group_name, ns.vnet, 'Microsoft.Network/virtualNetworks',
        parent_value=None, parent_type=None)

    vnet_name = vnet_parts['name']

    default_prefix = hasattr(getattr(ns, 'vnet_address_prefix'), 'is_default')

    vnet = get_vnet(cmd, vnet_parts)

    if vnet is not None:
        logger.info('vnet exists: %s', vnet_name)
        setattr(ns, 'vnet_type', 'existing')
        if not same_location(ns.location, vnet.location):
            raise InvalidArgumentValueError(
                '--vnet {} must be in the same location as the gateway'.format(vnet_name))
        if ns.vnet_address_prefix not in ('', '""', "''") or ns.vnet_address_prefix is not None:
            ns.vnet_address_prefix = None
            if not default_prefix:
                logger.warning('Ignoring option --vnet-address-prefix because vnet %s already esists', vnet_name)

    elif none_or_empty(ns.vnet_address_prefix):
        raise InvalidArgumentValueError(
            '--vnet-address-prefix must have a valid CIDR prefix when an esisting vnet is not provided')

    else:
        setattr(ns, 'vnet_type', 'new')
        logger.info('vnet does not exists: %s', vnet_name)

    prefixes = vnet.address_space.address_prefixes if vnet is not None else [
        ns.vnet_address_prefix] if ns.vnet_address_prefix is not None else None

    for subnet in subnets:
        validate_subnet(cmd, ns, subnet, vnet_parts, prefixes)

    # if vnet address prefix (entered by user or from existing vnet)
    #   should always have something because new vnet requires prefix and existing vnets have one
    # for each subnet that has prefix (after subnet val clears them for existing) validate


def validate_subnet(cmd, ns, subnet, vnet_parts, vnet_prefixes):
    property_option = '--{}-subnet'.format(subnet)
    prefix_property_option = '--{}-subnet-address-prefix'.format(subnet)

    property_name = '{}_subnet'.format(subnet)
    type_property_name = '{}_subnet_type'.format(subnet)
    prefix_property_name = '{}_subnet_address_prefix'.format(subnet)

    property_val = getattr(ns, property_name, None)

    if none_or_empty(property_val):
        raise InvalidArgumentValueError('{} must have a value'.format(property_option))

    vnet_name = vnet_parts['name']
    vnet_group = vnet_parts['resource_group']

    resource_id_parts, _ = _validate_name_or_id(
        cmd.cli_ctx, vnet_group, property_val, 'subnets', vnet_name, 'Microsoft.Network/virtualNetworks')

    subnet_name = resource_id_parts['child_name_1']

    if subnet == 'bastion' and subnet_name != 'AzureBastionSubnet':
        raise InvalidArgumentValueError('{} must be AzureBastionSubnet'.format(property_option))

    if vnet_name is None and resource_id_parts['name'] is not None:
        # user didn't specify a vnet but provided an resource id (opposed to a name) for the subnet
        raise InvalidArgumentValueError(
            '--vnet must have a value that matches the subnet id provided for {}'.format(property_option))

    missmatch_parts = [k for k in ['subscription', 'resource_group', 'name'] if resource_id_parts[k] != vnet_parts[k]]
    if missmatch_parts:
        raise InvalidArgumentValueError('{} must in the vnet {}'.format(property_option, vnet_name))

    setattr(ns, property_name, subnet_name)

    prefix_property_val = getattr(ns, prefix_property_name, None)
    prefix_property_val_default = hasattr(getattr(ns, prefix_property_name), 'is_default')

    existing_subnet = get_subnet(cmd, resource_id_parts)

    if existing_subnet is not None:
        logger.info('subnet exists: %s', subnet_name)
        setattr(ns, type_property_name, 'existing')

        if not none_or_empty(prefix_property_val):
            setattr(ns, prefix_property_name, None)  # remove/ignore the subet prefix for existing subnet
            if not prefix_property_val_default:
                logger.warning('Ignoring option %s because subnet %s already esists',
                               prefix_property_option, subnet_name)

        if subnet == 'appgateway':
            prefix = existing_subnet.address_prefix
            validate_private_ip(cmd, ns, prefix)

    elif none_or_empty(prefix_property_val):
        raise InvalidArgumentValueError(
            '{} must have a valid CIDR prefix when subnet {} does not esist'.format(
                prefix_property_option, subnet_name))

    else:
        setattr(ns, type_property_name, 'new')
        logger.info('subnet does not exist: %s', subnet_name)
        if vnet_prefixes is not None:
            vnet_networks = [ipaddress.ip_network(p) for p in vnet_prefixes]
            if not all(any(h in n for n in vnet_networks) for h in ipaddress.ip_network(
                    prefix_property_val).hosts()):
                raise InvalidArgumentValueError(
                    '{} {} is not within the vnet address space (prefixed: {})'.format(
                        prefix_property_option, prefix_property_val, ', '.join(vnet_prefixes)))

        if subnet == 'appgateway':
            validate_private_ip(cmd, ns, prefix_property_val)


def validate_token_lifetime(cmd, ns):  # pylint: disable=unused-argument
    if ns.token_lifetime:
        lifetime = ns.token_lifetime
        if isinstance(lifetime, str):
            try:
                lifetime = int(lifetime)
            except ValueError as e:
                raise InvalidArgumentValueError(
                    '--token-lifetime must be a number between 1 and 59') from e
        if not isinstance(lifetime, int) or lifetime < 1 or lifetime > 59:
            raise InvalidArgumentValueError(
                '--token-lifetime must be a number between 1 and 59')

        ns.token_lifetime = '00:0{}:00'.format(lifetime) if lifetime < 10 else '00:{}:00'.format(lifetime)


def validate_public_ip(cmd, ns):

    if none_or_empty(ns.public_ip_address):
        setattr(ns, 'public_ip_address_type', 'new')

    else:
        ip_parts, _ = _validate_name_or_id(
            cmd.cli_ctx, ns.resource_group_name, ns.public_ip_address, 'Microsoft.Network/publicIPAddresses',
            parent_value=None, parent_type=None)

        ip_name = ip_parts['name']

        ip = get_public_ip(cmd, ip_parts)
        sub = get_subscription_id(cmd.cli_ctx)

        if ip is not None:
            setattr(ns, 'public_ip_address_type', 'existing')
            logger.info('public ip address exists: %s', ip_name)

            if ip_parts['subscription'] != sub:
                raise InvalidArgumentValueError(
                    '--public-ip-address {} must in the same subscription as the gateway'.format(ip_name))

            if ip_parts['resource_group'].lower() != ns.resource_group_name.lower():
                raise InvalidArgumentValueError(
                    '--public-ip-address {} must in the same resource group as the gateway'.format(ip_name))

            if not same_location(ns.location, ip.location):
                raise InvalidArgumentValueError(
                    '--public-ip-address {} must in the same location as the gateway'.format(ip_name))

            if ip.sku.name.lower() != 'standard':
                raise InvalidArgumentValueError(
                    '--public-ip-address {} sku must be Standard'.format(ip_name))

            if ip.public_ip_allocation_method.lower() != 'static':
                raise InvalidArgumentValueError(
                    '--public-ip-address {} public_ip_allocation_method must static'.format(ip_name))

            if ip.public_ip_address_version.lower() != 'ipv4':
                raise InvalidArgumentValueError(
                    '--public-ip-address {} public_ip_address_version must be IPv4'.format(ip_name))

        else:
            raise InvalidArgumentValueError(
                '--public-ip-address {} could not be found'.format(ip_name))


def validate_private_ip(cmd, ns, prefix):  # pylint: disable=unused-argument
    if none_or_empty(ns.private_ip_address) or none_or_empty(prefix):
        raise InvalidArgumentValueError('--private-ip-address and prefix must both have values')

    private_ip = ipaddress.ip_address(ns.private_ip_address)

    if private_ip not in ipaddress.ip_network(prefix):
        raise InvalidArgumentValueError(
            '--private-ip-address {} is not in subnet network {}'.format(ns.private_ip_address, prefix))

    ip_host = ns.private_ip_address.rsplit('.', 1)[1]
    if int(ip_host) < 5:
        raise InvalidArgumentValueError(
            '--private-ip-address {} is invalid, addresses ending in .0 - .4 are reserved'.format(
                ns.private_ip_address))


def index_version_validator(cmd, ns):  # pylint: disable=unused-argument
    if sum(1 for ct in [ns.version, ns.prerelease, ns.index_url] if ct) > 1:
        raise MutuallyExclusiveArgumentError(
            'Only use one of --index-url | --version/-v | --pre',
            recommendation='Remove all --index-url, --version/-v, and --pre to use the latest'
            'stable release, or only specify --pre to use the latest pre-release')

    if ns.version:
        ns.version = ns.version.lower()
        if ns.version[:1].isdigit():
            ns.version = 'v' + ns.version
        if not _is_valid_version(ns.version):
            raise InvalidArgumentValueError(
                '--version/-v should be in format v0.0.0 do not include -pre suffix')

        if not github_release_version_exists(ns.version):
            raise InvalidArgumentValueError('--version/-v {} does not exist'.format(ns.version))

    elif ns.index_url:
        if not _is_valid_url(ns.index_url):
            raise InvalidArgumentValueError(
                '--index-url should be a valid url')

    else:
        ns.version = ns.version or get_github_latest_release_version(prerelease=ns.prerelease)
        ns.index_url = 'https://github.com/colbylwilliams/lab-gateway/releases/download/{}/index.json'.format(
            ns.version)


def _is_valid_url(url):
    return match(
        r'^http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\(\), ]|(?:%[0-9a-fA-F][0-9a-fA-F]))+$', url) is not None


def _is_valid_version(version):
    return match(r'^v[0-9]+\.[0-9]+\.[0-9]+$', version) is not None


# ARGUMENT TYPES


def certificate_type(string):
    """ Loads file and outputs contents as base64 encoded string. """
    try:
        with open(os.path.expanduser(string), 'rb') as f:
            cert_data = f.read()
        return cert_data
    except (IOError, OSError) as e:
        raise InvalidArgumentValueError("Unable to load certificate file '{}': {}.".format(string, e.strerror)) from e


def msi_type(string):
    """ Loads msi file and outputs contents. """
    try:
        with open(os.path.expanduser(string), 'rb') as f:
            mis_data = f.read()
        return mis_data
    except (IOError, OSError) as e:
        raise InvalidArgumentValueError("Unable to load msi file '{}': {}.".format(string, e.strerror)) from e

# def validate_subnet_address_prefixes(ns, subnet):
#     type_property_name = '{}_subnet_type'.format(subnet)
#     prefix_property_name = '{}_subnet_address_prefix'.format(subnet)

#     type_property = getattr(ns, type_property_name, None)

#     if ns.subnet_name and not ns.subnet_prefix:
#         if isinstance(ns.vnet_prefixes, str):
#             ns.vnet_prefixes = [ns.vnet_prefixes]
#         prefix_components = ns.vnet_prefixes[0].split('/', 1)
#         address = prefix_components[0]
#         bit_mask = int(prefix_components[1])
#         subnet_mask = 24 if bit_mask < 24 else bit_mask
#         subnet_prefix = '{}/{}'.format(address, subnet_mask)

    # if type_property != 'new':
    #     validate_parameter_set(ns, required=[],
    #                            forbidden=[prefix_property_name, 'vnet_address_prefix'],
    #                            description='existing subnet')
