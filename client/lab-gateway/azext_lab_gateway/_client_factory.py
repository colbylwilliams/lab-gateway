# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------
# pylint: disable=import-outside-toplevel

from azure.cli.core.commands.client_factory import get_mgmt_service_client
from azure.cli.core.profiles import get_api_version, ResourceType


def storage_client_factory(cli_ctx, **_):
    return get_mgmt_service_client(cli_ctx, ResourceType.MGMT_STORAGE)


def web_client_factory(cli_ctx, **_):
    return get_mgmt_service_client(cli_ctx, ResourceType.MGMT_APPSERVICE)


def resource_client_factory(cli_ctx, **_):
    return get_mgmt_service_client(cli_ctx, ResourceType.MGMT_RESOURCE_RESOURCES)


def cosmosdb_client_factory(cli_ctx, **_):
    from azure.mgmt.cosmosdb import CosmosDBManagementClient
    return get_mgmt_service_client(cli_ctx, CosmosDBManagementClient)


def appconfig_client_factory(cli_ctx, **_):
    from azure.mgmt.appconfiguration import AppConfigurationManagementClient
    return get_mgmt_service_client(cli_ctx, AppConfigurationManagementClient)


def network_client_factory(cli_ctx, **_):
    return get_mgmt_service_client(cli_ctx, ResourceType.MGMT_NETWORK)


def keyvault_client_factory(cli_ctx, **_):
    return get_mgmt_service_client(cli_ctx, ResourceType.MGMT_KEYVAULT)


def keyvault_data_client_factory(cli_ctx, **_):
    from azure.cli.core._profile import Profile
    version = str(get_api_version(cli_ctx, ResourceType.DATA_KEYVAULT))

    def get_token(server, resource, scope):  # pylint: disable=unused-argument
        return Profile(cli_ctx=cli_ctx).get_raw_token(resource)[0]

    from azure.keyvault import KeyVaultAuthentication, KeyVaultClient
    return KeyVaultClient(KeyVaultAuthentication(get_token), api_version=version)
