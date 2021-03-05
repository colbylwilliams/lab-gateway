# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from ._client_factory import resource_client_factory
from ._validators import lab_gateway_deploy_validator


def load_command_table(self, _):  # pylint: disable=too-many-statements

    with self.command_group('lab-gateway', is_preview=True):
        pass

    with self.command_group('lab-gateway', client_factory=resource_client_factory) as g:
        g.custom_command('deploy', 'lab_gateway_deploy', validator=lab_gateway_deploy_validator)
