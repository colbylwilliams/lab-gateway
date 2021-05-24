# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from ._validators import (process_gateway_create_namespace, process_gateway_connect_namespace,
                          process_gateway_token_namespace, process_gateway_show_namespace)


def load_command_table(self, _):  # pylint: disable=too-many-statements

    with self.command_group('lab-gateway', is_preview=True):
        pass

    with self.command_group('lab-gateway') as g:
        g.custom_command('create', 'lab_gateway_create', validator=process_gateway_create_namespace)
        g.custom_show_command('show', 'lab_gateway_show', validator=process_gateway_show_namespace)
        g.custom_command('connect', 'lab_gateway_connect', validator=process_gateway_connect_namespace)

    with self.command_group('lab-gateway token') as g:
        g.custom_show_command('show', 'lab_gateway_token_show', validator=process_gateway_token_namespace)
