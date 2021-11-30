# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------
# pylint: disable=too-many-statements, too-many-locals, too-many-lines

import requests
from knack.log import get_logger
from azure.cli.core.util import should_disable_connection_verify
from azure.cli.core.azclierror import (MutuallyExclusiveArgumentError, ResourceNotFoundError,
                                       ClientRequestError)

ERR_TMPL_PRDR_INDEX = 'Unable to get provider index.\n'
ERR_TMPL_NON_200 = f'{ERR_TMPL_PRDR_INDEX}Server returned status code {{}} for {{}}'
ERR_TMPL_NO_NETWORK = f'{ERR_TMPL_PRDR_INDEX}Please ensure you have network connection. Error detail: {{}}'
ERR_TMPL_BAD_JSON = f'{ERR_TMPL_PRDR_INDEX}Response body does not contain valid json. Error detail: {{}}'

TRIES = 3

logger = get_logger(__name__)


def get_github_release(org='colbylwilliams', repo='lab-gateway', version=None, prerelease=False):

    if version and prerelease:
        raise MutuallyExclusiveArgumentError(
            'Only use one of --version/-v | --pre')

    url = f'https://api.github.com/repos/{org}/{repo}/releases'

    if prerelease:
        version_res = requests.get(url, verify=not should_disable_connection_verify())
        version_json = version_res.json()

        version_prerelease = next((v for v in version_json if v['prerelease']), None)
        if not version_prerelease:
            raise ResourceNotFoundError(f'--pre no prerelease versions found for {org}/{repo}')

        return version_prerelease

    url += (f'/tags/{version}' if version else '/latest')

    version_res = requests.get(url, verify=not should_disable_connection_verify())

    if version_res.status_code == 404:
        raise ResourceNotFoundError(
            f'No release version exists for {org}/{repo}. '
            f'Specify a specific prerelease version with --version '
            f'or use latest prerelease with --pre')

    return version_res.json()


def get_github_latest_release_version(org='colbylwilliams', repo='lab-gateway', prerelease=False):
    version_json = get_github_release(org, repo, prerelease=prerelease)
    return version_json['tag_name']


def github_release_version_exists(version, org='colbylwilliams', repo='lab-gateway'):
    version_url = f'https://api.github.com/repos/{org}/{repo}/releases/tags/{version}'
    version_res = requests.get(version_url, verify=not should_disable_connection_verify())
    return version_res.status_code < 400


def get_index(index_url):  # pylint: disable=inconsistent-return-statements
    for try_number in range(TRIES):
        try:
            response = requests.get(index_url, verify=(not should_disable_connection_verify()))
            if response.status_code == 200:
                return response.json()
            msg = ERR_TMPL_NON_200.format(response.status_code, index_url)
            raise ClientRequestError(msg)
        except (requests.exceptions.ConnectionError, requests.exceptions.HTTPError) as err:
            msg = ERR_TMPL_NO_NETWORK.format(str(err))
            raise ClientRequestError(msg) from err
        except ValueError as err:
            # Indicates that url is not redirecting properly to intended index url, we stop retrying after TRIES calls
            if try_number == TRIES - 1:
                msg = ERR_TMPL_BAD_JSON.format(str(err))
                raise ClientRequestError(msg) from err
            import time  # pylint: disable=import-outside-toplevel
            time.sleep(0.5)
            continue


def get_release_index(version=None, prerelease=False, index_url=None):
    if index_url is None:
        version = version or get_github_latest_release_version(prerelease=prerelease)
        index_url = f'https://github.com/colbylwilliams/lab-gateway/releases/download/{version}/index.json'
    index = get_index(index_url=index_url)
    gateway = index.get('gateway')
    if gateway is None:
        raise ResourceNotFoundError('Unable to get gateway node from index.json. Improper index format.')
    arm = index.get('arm')
    if arm is None:
        raise ResourceNotFoundError('Unable to get arm node from index.json. Improper index format.')
    artifacts = index.get('artifacts')
    if artifacts is None:
        raise ResourceNotFoundError('Unable to get artifacts node from index.json. Improper index format.')
    return version, gateway, arm, artifacts


def get_arm_template(arm_templates, name):
    template = arm_templates.get(name)
    if template is None:
        raise ResourceNotFoundError(f'Unable to get arm template {name} from index.json.')
    template_url = template.get('url')
    if template_url is None:
        raise ResourceNotFoundError(f'Unable to get arm template {name} url from index.json.')

    return template_url


def get_artifact(artifacts, name):
    artifact = artifacts.get(name)
    if artifact is None:
        raise ResourceNotFoundError(f'Unable to get artifact {name} from index.json.')
    artifact_url = artifact.get('url')
    artifact_name = artifact.get('name')
    if artifact_url is None:
        raise ResourceNotFoundError(f'Unable to get artifact {name} url from index.json.')
    if artifact_name is None:
        raise ResourceNotFoundError(f'Unable to get artifact {name} name from index.json.')

    return artifact_name, artifact_url
