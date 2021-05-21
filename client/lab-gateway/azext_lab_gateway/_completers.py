# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

# from azure.cli.core.decorators import Completer
from knack.log import get_logger
from azure.cli.core.decorators import Completer
from ._client_factory import network_client_factory

logger = get_logger(__name__)

# pylint: disable=inconsistent-return-statements


@Completer
def subnet_completion_list(cmd, prefix, namespace, **kwargs):  # pylint: disable=unused-argument
    client = network_client_factory(cmd.cli_ctx)
    if namespace.resource_group_name and namespace.vnet_name:
        rg = namespace.resource_group_name
        vnet = namespace.vnet_name
        return [r.name for r in client.subnets.list(resource_group_name=rg, virtual_network_name=vnet)]
