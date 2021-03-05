# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

# pylint: disable=too-many-statements
# pylint: disable=line-too-long
# from knack.arguments import CLIArgumentType
from azure.cli.core.commands.parameters import tags_type


def load_arguments(self, _):

    # lab-gateway deploy uses a command level validator, param validators will be ignored
    with self.argument_context('lab-gateway deploy') as c:
        c.argument('admin_username', options_list=['--admin-username', '-u'],
                   help='Username for the VM. Default value is current username of OS. If the default value is system reserved, then default value will be set to azureuser. Please refer to https://docs.microsoft.com/en-us/rest/api/compute/virtualmachines/createorupdate#osprofile to get a full list of reserved values.')
        c.argument('admin_password', options_list=['--admin-password', '-p'],
                   help="Password for the VM if authentication type is 'Password'.")
        c.argument('instance_count', help='Number of VMs in the scale set.', type=int)
        c.argument('ssl_cert', help='SSL Certificate .pfx or .p12 file.')
        c.argument('ssl_cert_password', help='Password used to export the SSL certificate (for installation).')
        c.argument('auth_msi', help='Path to RDGatewayFedAuth.msi.')
        c.argument('signing_cert', help='Self-signed certificate .pfx or .p12 file. If this option is ommitted, a new certificate will be generated during deployment using KeyVault.')
        c.argument('signing_cert_password', help='Password used to export the SSL certificate (for installation).')
        c.argument('tags', tags_type)
        c.argument('version', options_list=['--version', '-v'], help='TeamCloud version. Default: latest stable.')
        c.argument('prerelease', options_list=['--pre'], action='store_true', help='Deploy latest prerelease version.')
        c.argument('index_url', help='URL to custom index.json file.')
        # c.argument('skip_app_deployment', action='store_true', help="Only create Azure resources, skip deploying the TeamCloud API and Orchestrator apps.")
        # c.argument('skip_name_validation', action='store_true', help="Skip name validaiton. Useful when attempting to redeploy a partial or failed deployment.")
