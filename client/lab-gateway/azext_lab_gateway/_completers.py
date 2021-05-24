# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

# from azure.cli.core.decorators import Completer
from knack.log import get_logger
from azure.cli.core.decorators import Completer
from azure.cli.core.commands.parameters import (get_resources_in_subscription,
                                                get_resources_in_resource_group)

from ._client_factory import (network_client_factory, labs_client_factory)

logger = get_logger(__name__)

# pylint: disable=inconsistent-return-statements


@Completer
def subnet_completion_list(cmd, prefix, ns, **kwargs):  # pylint: disable=unused-argument
    client = network_client_factory(cmd.cli_ctx)
    if ns.resource_group_name and ns.vnet_name:
        rg = ns.resource_group_name
        vnet = ns.vnet_name
        return [r.name for r in client.subnets.list(resource_group_name=rg, virtual_network_name=vnet)]


def get_lab_name_completion_list(group_option='resource_group_name'):

    @Completer
    def completer(cmd, prefix, ns, **kwargs):  # pylint: disable=unused-argument
        rg = getattr(ns, group_option, None)
        client = labs_client_factory(cmd.cli_ctx)
        filter_str = None if prefix is None else "startsWith(name, '{}')".format(prefix)

        if rg:
            return [r.name for r in client.labs.list_by_resource_group(rg, filter=filter_str)]
        return [r.name for r in client.labs.list_by_subscription(filter=filter_str)]

    return completer


def get_resource_name_completion_list(group_option='resource_group_name', resource_type=None):

    @Completer
    def completer(cmd, prefix, ns, **kwargs):  # pylint: disable=unused-argument
        rg = getattr(ns, group_option, None)
        if rg:
            return [r.name for r in get_resources_in_resource_group(cmd.cli_ctx, rg, resource_type=resource_type)]
        return [r.name for r in get_resources_in_subscription(cmd.cli_ctx, resource_type)]

    return completer
