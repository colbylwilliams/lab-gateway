# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------
# pylint: disable=unused-argument, protected-access, too-many-lines

from knack.log import get_logger
from msrestazure.azure_exceptions import CloudError
from azure.graphrbac import GraphRbacManagementClient
from azure.graphrbac.models import GraphErrorException
from azure.cli.core._profile import Profile
from azure.cli.core.util import (can_launch_browser, open_page_in_browser, in_cloud_console)
from azure.cli.core.azclierror import AzureResponseError
from ._constants import tag_key

TRIES = 3

logger = get_logger(__name__)


def get_tag(tags, key):
    val = tags.get(tag_key(key), None) if tags else None
    return val


def open_url_in_browser(url):
    # if we are not in cloud shell and can launch a browser, launch it with the issue draft
    if can_launch_browser() and not in_cloud_console():
        open_page_in_browser(url)
    else:
        print("There isn't an available browser finish the setup. Please copy and paste the url"
              " below in a browser to complete the configuration.\n\n{}\n\n".format(url))


def same_location(loc_a, loc_b):
    if loc_a is None or loc_b is None:
        return False
    loc_a_clean = loc_a.lower().replace(' ', '')
    loc_b_clean = loc_b.lower().replace(' ', '')
    if loc_a_clean == loc_b_clean:
        return True
    return False

# pylint: disable=inconsistent-return-statements


def _get_current_user_object_id(graph_client):
    try:
        current_user = graph_client.signed_in_user.get()
        if current_user and current_user.object_id:  # pylint:disable=no-member
            return current_user.object_id  # pylint:disable=no-member
    except CloudError:
        pass


def _get_object_id_by_spn(graph_client, spn):
    accounts = list(graph_client.service_principals.list(
        filter="servicePrincipalNames/any(c:c eq '{}')".format(spn)))
    if not accounts:
        logger.warning("Unable to find user with spn '%s'", spn)
        return None
    if len(accounts) > 1:
        logger.warning("Multiple service principals found with spn '%s'. "
                       "You can avoid this by specifying object id.", spn)
        return None
    return accounts[0].object_id


def _get_object_id_by_upn(graph_client, upn):
    accounts = list(graph_client.users.list(filter="userPrincipalName eq '{}'".format(upn)))
    if not accounts:
        logger.warning("Unable to find user with upn '%s'", upn)
        return None
    if len(accounts) > 1:
        logger.warning("Multiple users principals found with upn '%s'. "
                       "You can avoid this by specifying object id.", upn)
        return None
    return accounts[0].object_id


def _get_object_id_from_subscription(graph_client, subscription):
    if not subscription:
        return None

    if subscription['user']:
        if subscription['user']['type'] == 'user':
            return _get_object_id_by_upn(graph_client, subscription['user']['name'])
        if subscription['user']['type'] == 'servicePrincipal':
            return _get_object_id_by_spn(graph_client, subscription['user']['name'])
        logger.warning("Unknown user type '%s'", subscription['user']['type'])
    else:
        logger.warning('Current credentials are not from a user or service principal. '
                       'Azure Key Vault does not work with certificate credentials.')
    return None


def _get_object_id(graph_client, subscription=None, spn=None, upn=None):
    if spn:
        return _get_object_id_by_spn(graph_client, spn)
    if upn:
        return _get_object_id_by_upn(graph_client, upn)
    return _get_object_id_from_subscription(graph_client, subscription)


def get_user_info(cmd):

    profile = Profile(cli_ctx=cmd.cli_ctx)
    cred, _, tenant_id = profile.get_login_credentials(
        resource=cmd.cli_ctx.cloud.endpoints.active_directory_graph_resource_id)

    graph_client = GraphRbacManagementClient(
        cred,
        tenant_id,
        base_url=cmd.cli_ctx.cloud.endpoints.active_directory_graph_resource_id)
    subscription = profile.get_subscription()

    try:
        object_id = _get_current_user_object_id(graph_client)
    except GraphErrorException:
        object_id = _get_object_id(graph_client, subscription=subscription)
    if not object_id:
        raise AzureResponseError('Cannot create vault.\nUnable to query active directory for information '
                                 'about the current user.\nYou may try the --no-self-perms flag to '
                                 'create a vault without permissions.')

    return object_id, tenant_id
