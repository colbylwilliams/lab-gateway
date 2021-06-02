# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------
# pylint: disable=too-many-statements, disable=line-too-long

# from knack.arguments import CLIArgumentType
from argcomplete.completers import FilesCompleter

from azure.cli.core.commands.parameters import (get_location_type, tags_type,
                                                get_resource_group_completion_list,)

from ._validators import (certificate_type, msi_type)
from ._completers import (subnet_completion_list, get_resource_name_completion_list,
                          get_lab_name_completion_list)


# vnet_type = CLIArgumentType(
#     options_list=['--vnet', '-v'],
#     completer=''
#     id_part='resource_group',
# )

def load_arguments(self, _):

    for scope in ['lab-gateway create', 'lab-gateway show', 'lab-gateway connect', 'lab-gateway token show']:
        with self.argument_context(scope) as c:
            c.ignore('resource_prefix')

    for scope in ['lab-gateway create', 'lab-gateway connect']:
        with self.argument_context(scope) as c:
            c.argument('version', options_list=['--version', '-v'], help='Gateway version. Default: latest stable.', arg_group='Advanced')
            c.argument('prerelease', options_list=['--pre'], action='store_true', help='Deploy latest prerelease version.', arg_group='Advanced')
            c.argument('index_url', help='URL to custom index.json file.', arg_group='Advanced')

    # lab-gateway deploy uses a command level validator, param validators will be ignored
    # for scope in ['lab-gateway create', 'lab-gateway test']:
    #     with self.argument_context(scope) as c:
    with self.argument_context('lab-gateway create') as c:
        c.argument('location', get_location_type(self.cli_ctx))
        c.argument('tags', tags_type)

        c.argument('admin_username', options_list=['--admin-username', '-u'],
                   help='Username for the gateway VMs. Value must not be system reserved. Please refer to https://docs.microsoft.com/en-us/rest/api/compute/virtualmachines/createorupdate#osprofile to get a full list of reserved values.')
        c.argument('admin_password', options_list=['--admin-password', '-p'],
                   help="Password for the gateway VMs.")

        c.argument('auth_msi', help='Path to RDGatewayFedAuth.msi file. RDGatewayFedAuth comes with System Center Virtual Machine Manager (VMM) images. With an MSDN account, the latest VMM .iso download can be found at https://my.visualstudio.com/Downloads?q=System%20Center%20Virtual%20Machine%20Manager%202019&pgroup=. Download the .iso and extract RDGatewayFedAuth.msi from: System Center Virtual Machine Manager > amd64 > Setup > msi > RDGatewayFedAuth.msi', completer=FilesCompleter(), type=msi_type)

        c.argument('ssl_cert', help='Path to the SSL Certificate .pfx or .p12 file. This must match the FQDN of the gateway, wildcard certs will not work.',
                   completer=FilesCompleter(), type=certificate_type)
        c.argument('ssl_cert_password', help='Password used to export the SSL certificate (for installation).')

        c.argument('instance_count', help='Number of gateway VMs in the scale set.', type=int, default=1)
        c.argument('token_lifetime', help='TTL of a token embedded in RDP files in minutes.', default=1)

        vnet_help = 'Name or ID of an existing vnet. Must be in the same location as the gateway. Will create resource if it does not exist. If you want to use an existing vnet in other resource group, please provide the ID instead of the name of the vnet.'
        c.argument('vnet', help=vnet_help, completer=get_resource_name_completion_list('Microsoft.Network/virtualNetworks'), arg_group='Network')
        c.argument('vnet_address_prefix', arg_group='Network', help='The CIDR prefix to use when creating the vnet')

        subnet_help = 'Name or ID of an existing subnet in vnet provided for --vnet. Will create a new subnet if a subnet with the name does not exist.'
        c.argument('rdgateway_subnet', completer=subnet_completion_list, arg_group='Network', help=subnet_help)
        c.argument('rdgateway_subnet_address_prefix', arg_group='Network', help='The CIDR prefix to use when creating the RDGateway subnet')

        c.argument('appgateway_subnet', completer=subnet_completion_list, arg_group='Network', help=subnet_help)
        c.argument('appgateway_subnet_address_prefix', arg_group='Network', help='The CIDR prefix to use when creating the App Gateway subnet')

        c.argument('bastion_subnet', completer=subnet_completion_list, arg_group='Network', help=subnet_help)
        c.argument('bastion_subnet_address_prefix', arg_group='Network', help='The CIDR prefix to use when creating the Bastion Host subnet')

        c.argument('private_ip_address', arg_group='Network', help='Private IP Address. Must be within AppGatewaySubnet address prefix and cannot end in .0 - .4 (reserved)')

        public_ip_help = 'Name or ID of an existing Public IP Address resource. Must be in the same resource group and location as the gateway. Will create new resource if none is specified.'
        c.argument('public_ip_address', help=public_ip_help, completer=get_resource_name_completion_list('Microsoft.Network/publicIPAddresses'), arg_group='Network')

        c.ignore('vnet_type')
        c.ignore('rdgateway_subnet_type')
        c.ignore('appgateway_subnet_type')
        c.ignore('bastion_subnet_type')
        c.ignore('public_ip_address_type')

    with self.argument_context('lab-gateway connect') as c:
        c.argument('lab', help='The Lab',
                   completer=get_lab_name_completion_list('lab_resource_group_name'))
        c.argument('lab_resource_group_name', options_list=['--lab-resource-group', '--lab-group'],
                   help="Name of Labs resource group", completer=get_resource_group_completion_list)
        c.ignore('lab_vnet')
        c.ignore('lab_keyvault')
        c.ignore('function_name')
        c.ignore('gateway_hostname')
        c.ignore('location')

    for scope in ['lab-gateway token show']:
        with self.argument_context(scope) as c:
            # c.argument('location', get_location_type(self.cli_ctx))
            c.ignore('function_name')
