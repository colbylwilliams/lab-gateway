# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

# pylint: disable=too-many-statements
# pylint: disable=line-too-long

# from knack.arguments import CLIArgumentType
from argcomplete.completers import FilesCompleter

from azure.cli.core.commands.parameters import (get_location_type, tags_type,
                                                get_resource_group_completion_list,)

from azure.cli.core.commands.template_create import (get_folded_parameter_help_string)

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
                   help='Username for the VM. Default value is current username of OS. If the default value is system reserved, then default value will be set to azureuser. Please refer to https://docs.microsoft.com/en-us/rest/api/compute/virtualmachines/createorupdate#osprofile to get a full list of reserved values.')
        c.argument('admin_password', options_list=['--admin-password', '-p'],
                   help="Password for the VM if authentication type is 'Password'.")

        c.argument('auth_msi', help='Path to RDGatewayFedAuth.msi.', completer=FilesCompleter(), type=msi_type)

        c.argument('ssl_cert', help='Path to the SSL Certificate .pfx or .p12 file.',
                   completer=FilesCompleter(), type=certificate_type)
        c.argument('ssl_cert_password', help='Password used to export the SSL certificate (for installation).')

        c.argument('instance_count', help='Number of VMs in the scale set.', type=int, default=1)
        c.argument('token_lifetime', help='TTL of a generated token embedded in RDP files in minutes.', default=1)

        # c.argument('signing_cert', help='Self-signed certificate .pfx or .p12 file. If this option is ommitted, a new certificate will be generated during deployment using KeyVault.')
        # c.argument('signing_cert_password', help='Password used to export the SSL certificate (for installation).')
        # c.argument('public_ip', help='Pub')

        # c.argument('vnet', vnet_name_type)
        vnet_help = get_folded_parameter_help_string('virtual network', allow_none=True, allow_new=False, default_none=True, allow_cross_sub=False)
        c.argument('vnet', help=vnet_help, completer=get_resource_name_completion_list('Microsoft.Network/virtualNetworks'), arg_group='Network')
        c.argument('vnet_address_prefix', arg_group='Network', help='The CIDR prefix to use when creating the vnet')

        c.argument('rdgateway_subnet', completer=subnet_completion_list, arg_group='Network',
                   help=get_folded_parameter_help_string('rdgateway_subnet', other_required_option='--vnet', allow_new=True, allow_cross_sub=False))
        c.argument('rdgateway_subnet_address_prefix', arg_group='Network', help='The CIDR prefix to use when creating the RDGateway subnet')

        c.argument('appgateway_subnet', completer=subnet_completion_list, arg_group='Network',
                   help=get_folded_parameter_help_string('appgateway_subnet', other_required_option='--vnet', allow_new=True, allow_cross_sub=False))
        c.argument('appgateway_subnet_address_prefix', arg_group='Network', help='The CIDR prefix to use when creating the App Gateway subnet')

        c.argument('bastion_subnet', completer=subnet_completion_list, arg_group='Network',
                   help=get_folded_parameter_help_string('bastion_subnet', other_required_option='--vnet', allow_new=True, allow_cross_sub=False))
        c.argument('bastion_subnet_address_prefix', arg_group='Network', help='The CIDR prefix to use when creating the Bastion Host subnet')

        c.argument('private_ip_address', help='Private IP Address. Must be within AppGatewaySubnet address prefix and cannot end in .0 - .4 (reserved)')
        public_ip_help = get_folded_parameter_help_string('public IP address', allow_none=True, allow_new=True, default_none=True, allow_cross_sub=False)
        c.argument('public_ip_address', help=public_ip_help, completer=get_resource_name_completion_list('Microsoft.Network/publicIPAddresses'), arg_group='Network')
        # subnet_help = get_folded_parameter_help_string('subnet', other_required_option='--vnet-name', allow_new=True)
        # c.argument('subnet', help=subnet_help, completer=subnet_completion_list, arg_group='Network')

        # c.argument('skip_app_deployment', action='store_true', help="Only create Azure resources, skip deploying the TeamCloud API and Orchestrator apps.")
        # c.argument('skip_name_validation', action='store_true', help="Skip name validaiton. Useful when attempting to redeploy a partial or failed deployment.")
        c.ignore('vnet_type')
        c.ignore('rdgateway_subnet_type')
        c.ignore('appgateway_subnet_type')
        c.ignore('bastion_subnet_type')
        c.ignore('public_ip_address_type')
    # with self.argument_context('lab-gateway ssl update')

    with self.argument_context('lab-gateway connect') as c:
        c.argument('lab', help='The Lab',
                   completer=get_lab_name_completion_list('lab_resource_group_name'))
        c.argument('lab_resource_group_name', options_list=['--lab-resource-group', '--lab-group'],
                   help="Name of Labs resource group", completer=get_resource_group_completion_list)
        c.ignore('lab_vnet')
        c.ignore('lab_keyvault')
        c.ignore('function_name')
        c.ignore('gateway_hostname')

    for scope in ['lab-gateway token show']:
        with self.argument_context(scope) as c:
            # c.argument('location', get_location_type(self.cli_ctx))
            c.ignore('function_name')
