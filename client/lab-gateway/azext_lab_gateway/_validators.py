# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from re import match
# from uuid import UUID
from azure.cli.core.util import CLIError
from knack.log import get_logger

logger = get_logger(__name__)

# pylint: disable=unused-argument, protected-access


def lab_gateway_deploy_validator(cmd, ns):
    # if ns.principal_name is not None:
    #     if ns.principal_password is None:
    #         raise CLIError(
    #             'usage error: --principal-password must be have a value if --principal-name is specified')
    # if ns.principal_password is not None:
    #     if ns.principal_name is None:
    #         raise CLIError(
    #             'usage error: --principal-name must be have a value if --principal-password is specified')

    if sum(1 for ct in [ns.version, ns.prerelease, ns.index_url] if ct) > 1:
        raise CLIError(
            'usage error: can only use one of --index-url | --version/-v | --pre')

    if ns.version:
        ns.version = ns.version.lower()
        if ns.version[:1].isdigit():
            ns.version = 'v' + ns.version
        if not _is_valid_version(ns.version):
            raise CLIError(
                '--version/-v should be in format v0.0.0 do not include -pre suffix')

        from ._deploy_utils import github_release_version_exists

        if not github_release_version_exists(cmd.cli_ctx, ns.version, 'TeamCloud'):
            raise CLIError('--version/-v {} does not exist'.format(ns.version))

    if ns.tags:
        from azure.cli.core.commands.validators import validate_tags
        validate_tags(ns)

    if ns.index_url:
        if not _is_valid_url(ns.index_url):
            raise CLIError(
                '--index-url should be a valid url')

    # if ns.name is not None:
    #     name_clean = ''
    #     for n in ns.name.lower():
    #         if n.isalpha() or n.isdigit() or n == '-':
    #             name_clean += n

        # ns.name = name_clean

        # if ns.skip_name_validation:
        #     logger.warning('IMPORTANT: --skip-name-validation prevented unique name validation.')
        # else:
        #     from ._client_factory import web_client_factory

        #     web_client = web_client_factory(cmd.cli_ctx)
        #     availability = web_client.check_name_availability(ns.name, 'Site')
        #     if not availability.name_available:
        #         raise CLIError(
        #             '--name/-n {}'.format(availability.message))


def _is_valid_url(url):
    return match(
        r'^http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\(\), ]|(?:%[0-9a-fA-F][0-9a-fA-F]))+$', url) is not None


def _is_valid_version(version):
    return match(r'^v[0-9]+\.[0-9]+\.[0-9]+$', version) is not None
