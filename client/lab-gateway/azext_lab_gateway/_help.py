# coding=utf-8
# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

from knack.help_files import helps  # pylint: disable=unused-import

# ----------------
# Lab Gateway
# ----------------

helps['lab-gateway'] = """
type: group
short-summary: Manage DevTestLabs Remote Desktop Gateways.
"""

helps['lab-gateway create'] = """
type: command
short-summary: Create a new gateway.
examples:
  - name: Create a new gateway.
    text: |
      az lab-gateway create -g ResourceGroup -l eastus \\
        --admin-username azureuser \\
        --admin-password Secure1! \\
        --ssl-cert /path/to/SSLCertificate.pfx \\
        --ssl-cert-password DontRepeatPasswords1 \\
        --auth-msi /path/to/RDGatewayFedAuth.msi

  - name: Create a new gateway using a specific version.
    text: |
      az lab-gateway create -g ResourceGroup -l eastus \\
        --admin-username azureuser \\
        --admin-password Secure1! \\
        --ssl-cert /path/to/SSLCertificate.pfx \\
        --ssl-cert-password DontRepeatPasswords1 \\
        --auth-msi /path/to/RDGatewayFedAuth.msi \\
        --version v0.1.1
"""

helps['lab-gateway show'] = """
type: command
short-summary: Get details for an existing gateway.
examples:
  - name: Get details for an existing gateway.
    text: az lab-gateway show -g ResourceGroup
"""

helps['lab-gateway connect'] = """
type: command
short-summary: Connect a gateway to a DevTest Lab.
examples:
  - name: Connect a gateway to a DevTest Lab.
    text: |
      az lab-gateway connect -g GatewayResourceGroup \\
        --lab-group LabResourceGroup \\
        --lab MyLab
"""

helps['lab-gateway token'] = """
type: group
short-summary: Manage gateway tokens.
"""

helps['lab-gateway token show'] = """
type: command
short-summary: Get the gateway token needed configure a Lab.
examples:
  - name: Get the Gateway token.
    text: az lab-gateway token show -g ResourceGroup
"""
