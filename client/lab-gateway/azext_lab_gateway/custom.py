# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------
# pylint: disable=unused-argument, protected-access, too-many-lines

from knack.util import CLIError
from knack.log import get_logger

logger = get_logger(__name__)


# def _ensure_base_url(client, base_url):
#     client._client._base_url = base_url

def lab_gateway_deploy(cmd, client, resource_group_name, admin_username, admin_password, auth_msi,  # pylint: disable=too-many-statements, too-many-locals
                       ssl_cert, ssl_cert_password, signing_cert=None, signing_cert_password=None,
                       instance_count=1, location=None, tags=None, version=None, prerelease=False, index_url=None):
    # from azure.cli.core._profile import Profile
    from ._deploy_utils import (
        get_index_gateway, deploy_arm_template_at_resource_group, get_resource_group_by_name,
        create_resource_group_name)
    # set_appconfig_keys, zip_deploy_app, get_arm_output)

    cli_ctx = cmd.cli_ctx

    hook = cli_ctx.get_progress_controller()
    hook.begin()

    hook.add(message='Fetching index.json from GitHub')
    # version, deploy_url, zip_url, script_url = get_index_gateway(
    version, deploy_url, _, _ = get_index_gateway(
        cli_ctx, version, prerelease, index_url)

    hook.add(message='Getting resource group {}'.format(resource_group_name))
    rg, _ = get_resource_group_by_name(cli_ctx, resource_group_name)
    if rg is None:
        if location is None:
            raise CLIError(
                "--location/-l is required if resource group '{}' does not exist".format(resource_group_name))
        hook.add(message="Resource group '{}' not found".format(resource_group_name))
        hook.add(message="Creating resource group '{}'".format(resource_group_name))
        rg, _ = create_resource_group_name(cli_ctx, resource_group_name, location)

    # profile = Profile(cli_ctx=cli_ctx)

    parameters = []
    parameters.append('adminUsername={}'.format(admin_username))
    parameters.append('adminPassword={}'.format(admin_password))
    # parameters.append('sslCertificate={}'.format())
    parameters.append('sslCertificatePassword={}'.format(ssl_cert_password))
    # parameters.append('sslCertificateThumbprint={}'.format())

    if signing_cert:
        # parameters.append('signCertificate={}'.format())
        parameters.append('signCertificatePassword={}'.format(signing_cert_password))
        # parameters.append('signCertificateThumbprint={}'.format())

    hook.add(message='Deploying ARM template')
    # outputs = deploy_arm_template_at_resource_group(
    _ = deploy_arm_template_at_resource_group(
        cmd, resource_group_name, template_uri=deploy_url, parameters=[parameters])

    result = {
        'version': version or 'latest',
        # 'name': name,
        # 'base_url': api_url,
        'location': rg.location,
    }

    return result
