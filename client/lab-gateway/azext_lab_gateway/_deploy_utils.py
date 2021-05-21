# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------
# pylint: disable=too-many-statements, too-many-locals

import json
import requests
import urllib3
from re import match
from time import sleep
from knack.log import get_logger
from knack.util import CLIError
from azure.cli.core.commands import LongRunningOperation
from azure.cli.core.profiles import ResourceType, get_sdk
from azure.cli.core.util import (should_disable_connection_verify, random_string, sdk_no_wait)
from azure.cli.core.azclierror import ResourceNotFoundError

from ._client_factory import (resource_client_factory, web_client_factory)

TRIES = 3

logger = get_logger(__name__)


def get_resource_group_by_name(cli_ctx, resource_group_name):

    try:
        resource_client = resource_client_factory(cli_ctx).resource_groups
        return resource_client.get(resource_group_name), resource_client.config.subscription_id
    except Exception as ex:  # pylint: disable=broad-except
        error = getattr(ex, 'Azure Error', ex)
        if error != 'ResourceGroupNotFound':
            return None, resource_client.config.subscription_id
        raise


def create_resource_group_name(cli_ctx, resource_group_name, location, tags=None):

    ResourceGroup = get_sdk(cli_ctx, ResourceType.MGMT_RESOURCE_RESOURCES,
                            'ResourceGroup', mod='models')
    resource_client = resource_client_factory(cli_ctx).resource_groups
    parameters = ResourceGroup(location=location.lower(), tags=tags)
    return resource_client.create_or_update(resource_group_name, parameters), resource_client.config.subscription_id


def set_appconfig_keys(cmd, appconfig_conn_string, kvs):
    from azure.cli.command_modules.appconfig.keyvalue import set_key   # pylint: disable=import-outside-toplevel

    for kv in kvs:
        set_key(cmd, key=kv['key'], value=kv['value'], yes=True,
                connection_string=appconfig_conn_string)


def zip_deploy_app(cli_ctx, resource_group_name, name, zip_url, slot=None, app_instance=None, timeout=None):
    web_client = web_client_factory(cli_ctx).web_apps

    #  work around until the timeout limits issue for linux is investigated & fixed
    creds = web_client.list_publishing_credentials(resource_group_name, name)
    creds = creds.result()

    try:
        scm_url = _get_scm_url(cli_ctx, resource_group_name, name,
                               slot=slot, app_instance=app_instance)
    except ValueError as e:
        raise CLIError('Failed to fetch scm url for azure app service app') from e

    zipdeploy_url = scm_url + '/api/zipdeploy?isAsync=true'
    deployment_status_url = scm_url + '/api/deployments/latest'

    authorization = urllib3.util.make_headers(basic_auth='{}:{}'.format(
        creds.publishing_user_name, creds.publishing_password))

    res = requests.put(zipdeploy_url, headers=authorization,
                       json={'packageUri': zip_url}, verify=not should_disable_connection_verify())

    # check if there's an ongoing process
    if res.status_code == 409:
        raise CLIError('There may be an ongoing deployment or your app setting has WEBSITE_RUN_FROM_PACKAGE. '
                       'Please track your deployment in {} and ensure the WEBSITE_RUN_FROM_PACKAGE app setting '
                       'is removed.'.format(deployment_status_url))

    # check the status of async deployment
    response = _check_zip_deployment_status(cli_ctx, resource_group_name, name, deployment_status_url,
                                            authorization, slot=slot, app_instance=app_instance, timeout=timeout)

    return response

# pylint: disable=inconsistent-return-statements


def deploy_arm_template_at_resource_group(cmd, resource_group_name=None, template_file=None,
                                          template_uri=None, parameters=None, no_wait=False):

    from azure.cli.command_modules.resource.custom import _prepare_deployment_properties_unmodified   # pylint: disable=import-outside-toplevel

    properties = _prepare_deployment_properties_unmodified(cmd, 'resourceGroup', template_file=template_file,
                                                           template_uri=template_uri, parameters=parameters,
                                                           mode='Incremental')

    client = resource_client_factory(cmd.cli_ctx).deployments

    for try_number in range(TRIES):
        try:
            deployment_name = random_string(length=14, force_lower=True) + str(try_number)

            if cmd.supported_api_version(min_api='2019-10-01', resource_type=ResourceType.MGMT_RESOURCE_RESOURCES):
                Deployment = cmd.get_models(
                    'Deployment', resource_type=ResourceType.MGMT_RESOURCE_RESOURCES)

                deployment = Deployment(properties=properties)
                deploy_poll = sdk_no_wait(no_wait, client.create_or_update, resource_group_name,
                                          deployment_name, deployment)
            else:
                deploy_poll = sdk_no_wait(no_wait, client.create_or_update, resource_group_name,
                                          deployment_name, properties)

            result = LongRunningOperation(cmd.cli_ctx, start_msg='Deploying ARM template',
                                          finish_msg='Finished deploying ARM template')(deploy_poll)

            props = getattr(result, 'properties', None)
            return getattr(props, 'outputs', None)
        except CLIError as err:
            if try_number == TRIES - 1:
                raise err
            try:
                response = getattr(err, 'response', None)
                message = json.loads(response.text)['error']['details'][0]['message']
                if '(ServiceUnavailable)' not in message:
                    raise err
            except:
                raise err from err
            sleep(5)
            continue


def get_app_name(url):
    name = ''
    m = match(r'^https?://(?P<name>[a-zA-Z0-9-]+)\.azurewebsites\.net[/a-zA-Z0-9.\:]*$', url)
    try:
        name = m.group('name') if m is not None else None
    except IndexError:
        pass

    if name is None:
        raise CLIError('Unable to get app name from url.')

    return name


def get_app_info(cmd, url):
    name = get_app_name(url)

    from azure.cli.command_modules.resource.custom import list_resources  # pylint: disable=import-outside-toplevel

    resources = list_resources(cmd, name=name, resource_type='microsoft.web/sites')

    if not resources:
        raise CLIError('Unable to find site from url.')
    if len(resources) > 1:
        raise CLIError('Found multiple sites from url.')

    return resources[0]


def get_arm_output(outputs, key, raise_on_error=True):
    try:
        value = outputs[key]['value']
    except KeyError as e:
        if raise_on_error:
            raise CLIError(
                "A value for '{}' was not provided in the ARM template outputs".format(key)) from e
        value = None

    return value


def _check_zip_deployment_status(cli_ctx, resource_group_name, name, deployment_status_url,
                                 authorization, slot=None, app_instance=None, timeout=None):
    total_trials = (int(timeout) // 2) if timeout else 450
    num_trials = 0

    while num_trials < total_trials:
        sleep(2)
        response = requests.get(deployment_status_url, headers=authorization,
                                verify=not should_disable_connection_verify())
        sleep(2)
        try:
            res_dict = response.json()
        except json.decoder.JSONDecodeError:
            logger.warning("Deployment status endpoint %s returned malformed data. Retrying...",
                           deployment_status_url)
            res_dict = {}
        finally:
            num_trials = num_trials + 1

        if res_dict.get('status', 0) == 3:
            _configure_default_logging(cli_ctx, resource_group_name, name,
                                       slot=slot, app_instance=app_instance)
            raise CLIError('Zip deployment failed. {}. Please run the command az webapp log tail -n {} -g {}'.format(
                res_dict, name, resource_group_name))
        if res_dict.get('status', 0) == 4:
            break
        if 'progress' in res_dict:
            # show only in debug mode, customers seem to find this confusing
            logger.info(res_dict['progress'])
    # if the deployment is taking longer than expected
    if res_dict.get('status', 0) != 4:
        _configure_default_logging(cli_ctx, resource_group_name, name,
                                   slot=slot, app_instance=app_instance)
        raise CLIError(
            'Timeout reached by the command, however, the deployment operation is still on-going. '
            'Navigate to your scm site to check the deployment status')
    return res_dict


# TODO: expose new blob suport
def _configure_default_logging(cli_ctx, resource_group_name, name, slot=None, app_instance=None, level=None,  # pylint: disable=unused-argument
                               web_server_logging='filesystem', docker_container_logging='true'):
    from azure.mgmt.web.models import (FileSystemApplicationLogsConfig, ApplicationLogsConfig,  # pylint: disable=import-outside-toplevel
                                       SiteLogsConfig, HttpLogsConfig, FileSystemHttpLogsConfig)

    # logger.warning('Configuring default logging for the app, if not already enabled...')

    site = _get_webapp(cli_ctx, resource_group_name, name, slot=slot, app_instance=app_instance)

    location = site.location

    fs_log = FileSystemApplicationLogsConfig(level='Error')
    application_logs = ApplicationLogsConfig(file_system=fs_log)

    http_logs = None
    server_logging_option = web_server_logging or docker_container_logging
    if server_logging_option:
        # TODO: az blob storage log config currently not in use, will be impelemented later.
        # Tracked as Issue: #4764 on Github
        filesystem_log_config = None
        turned_on = server_logging_option != 'off'
        if server_logging_option in ['filesystem', 'off']:
            # 100 mb max log size, retention lasts 3 days. Yes we hard code it, portal does too
            filesystem_log_config = FileSystemHttpLogsConfig(
                retention_in_mb=100, retention_in_days=3, enabled=turned_on)

        http_logs = HttpLogsConfig(file_system=filesystem_log_config, azure_blob_storage=None)

    site_log_config = SiteLogsConfig(location=location, application_logs=application_logs,
                                     http_logs=http_logs, failed_requests_tracing=None,
                                     detailed_error_messages=None)

    web_client = web_client_factory(cli_ctx).web_apps

    return web_client.update_diagnostic_logs_config(resource_group_name, name, site_log_config)

# pylint: disable=inconsistent-return-statements


def _get_scm_url(cli_ctx, resource_group_name, name, slot=None, app_instance=None):
    from azure.mgmt.web.models import HostType  # pylint: disable=import-outside-toplevel

    webapp = _get_webapp(cli_ctx, resource_group_name, name, slot=slot, app_instance=app_instance)
    for host in webapp.host_name_ssl_states or []:
        if host.host_type == HostType.repository:
            return 'https://{}'.format(host.name)


def _get_webapp(cli_ctx, resource_group_name, name, slot=None, app_instance=None):  # pylint: disable=unused-argument
    webapp = app_instance
    if not app_instance:
        web_client = web_client_factory(cli_ctx).web_apps
        webapp = web_client.get(resource_group_name, name)
    if not webapp:
        raise CLIError("'{}' app doesn't exist".format(name))

    # Should be renamed in SDK in a future release
    try:
        setattr(webapp, 'app_service_plan_id', webapp.server_farm_id)
        del webapp.server_farm_id
    except AttributeError:
        pass

    return webapp


def get_function_key(cmd, resource_group_name, function_app_name, function_name, key_name):
    web_client = web_client_factory(cmd.cli_ctx).web_apps

    keys = web_client.list_function_keys(resource_group_name, function_app_name, function_name)

    try:
        key = keys.additional_properties[key_name]
        return key
    except KeyError:
        KeyInfo = get_sdk(cmd.cli_ctx, ResourceType.MGMT_APPSERVICE, 'KeyInfo', mod='models')

        # pylint: disable=protected-access
        key_info = KeyInfo(name=key_name, value=None)
        KeyInfo._attribute_map = {
            'name': {'key': 'properties.name', 'type': 'str'},
            'value': {'key': 'properties.value', 'type': 'str'},
        }
        new_key = web_client.create_or_update_function_secret(resource_group_name, function_app_name,
                                                              function_name, key_name, key_info)

        return new_key.value


def _asn1_to_iso8601(asn1_date):
    import dateutil.parser  # pylint: disable=import-outside-toplevel
    if isinstance(asn1_date, bytes):
        asn1_date = asn1_date.decode('utf-8')
    return dateutil.parser.parse(asn1_date)


def import_certificate(cmd, vault_name, certificate_name, certificate_data,
                       disabled=False, password=None, certificate_policy=None, tags=None):
    import binascii  # pylint: disable=import-outside-toplevel
    from OpenSSL import crypto  # pylint: disable=import-outside-toplevel
    CertificateAttributes = cmd.get_models('CertificateAttributes', resource_type=ResourceType.DATA_KEYVAULT)
    SecretProperties = cmd.get_models('SecretProperties', resource_type=ResourceType.DATA_KEYVAULT)
    CertificatePolicy = cmd.get_models('CertificatePolicy', resource_type=ResourceType.DATA_KEYVAULT)

    x509 = None
    content_type = None
    try:
        x509 = crypto.load_certificate(crypto.FILETYPE_PEM, certificate_data)
        # if we get here, we know it was a PEM file
        content_type = 'application/x-pem-file'
        try:
            # for PEM files (including automatic endline conversion for Windows)
            certificate_data = certificate_data.decode('utf-8').replace('\r\n', '\n')
        except UnicodeDecodeError:
            certificate_data = binascii.b2a_base64(certificate_data).decode('utf-8')
    except (ValueError, crypto.Error):
        pass

    if not x509:
        try:
            if password:
                x509 = crypto.load_pkcs12(certificate_data, password).get_certificate()
            else:
                x509 = crypto.load_pkcs12(certificate_data).get_certificate()
            content_type = 'application/x-pkcs12'
            certificate_data = binascii.b2a_base64(certificate_data).decode('utf-8')
        except crypto.Error as e:
            raise CLIError(
                'We could not parse the provided certificate as .pem or .pfx.'
                'Please verify the certificate with OpenSSL.') from e

    not_before, not_after = None, None

    cn = x509.get_subject().CN

    if x509.get_notBefore():
        not_before = _asn1_to_iso8601(x509.get_notBefore())

    if x509.get_notAfter():
        not_after = _asn1_to_iso8601(x509.get_notAfter())

    cert_attrs = CertificateAttributes(
        enabled=not disabled,
        not_before=not_before,
        expires=not_after)

    if certificate_policy:
        secret_props = certificate_policy.get('secret_properties')
        if secret_props:
            secret_props['content_type'] = content_type
        elif certificate_policy and not secret_props:
            certificate_policy['secret_properties'] = SecretProperties(content_type=content_type)

        attributes = certificate_policy.get('attributes')
        if attributes:
            attributes['created'] = None
            attributes['updated'] = None
    else:
        certificate_policy = CertificatePolicy(
            secret_properties=SecretProperties(content_type=content_type))

    vault_base_url = 'https://{}{}'.format(vault_name, cmd.cli_ctx.cloud.suffixes.keyvault_dns)

    logger.info("Starting 'keyvault certificate import'")
    from ._client_factory import keyvault_data_client_factory  # pylint: disable=import-outside-toplevel
    client = keyvault_data_client_factory(cmd.cli_ctx)
    result = client.import_certificate(vault_base_url=vault_base_url,
                                       certificate_name=certificate_name,
                                       base64_encoded_certificate=certificate_data,
                                       certificate_attributes=cert_attrs,
                                       certificate_policy=certificate_policy,
                                       tags=tags,
                                       password=password)
    logger.info("Finished 'keyvault certificate import'")

    if result.sid is None:
        raise ResourceNotFoundError('Unable to get certificate secret uri from import result')

    secret_url = result.sid.rsplit('/', 1)[0]

    return result, cn, secret_url


# def upload_artifacts_to_storage(cmd, connection_string, container, artifacts):
#     BlobServiceClient, BlobClient = get_sdk(cmd.cli_ctx, ResourceType.DATA_STORAGE_BLOB,
#                                             '_blob_service_client#BlobServiceClient', '_blob_client#BlobClient')

#     blob_service_client = BlobServiceClient.from_connection_string(connection_string)

#     for name, url in artifacts:
#         blob_client = blob_service_client.get_blob_client(container, name)
#         response = requests.get(url)
#         blob_client.upload_blob(response.content)
