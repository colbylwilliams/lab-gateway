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

helps['lab-gateway deploy'] = """
type: command
short-summary: Deploy a new DevTestLabs Remote Desktop Gateway.
examples:
  - name: Deploy a new DevTestLabs Remote Desktop Gateway.
    text: az lab-gateway deploy -g ResourceGroup -l eastus \
          --admin-username azureuser \
          --admin-password Secure1! \
          --ssl-cert /path/to/SSLCertificate.pfx \
          --ssl-cert-password DontRepeatPasswords1 \
          --auth-msi /path/to/RDGatewayFedAuth.msi

  - name: Deploy a new DevTestLabs Remote Desktop Gateway to a specific pre-release.
    text: az lab-gateway deploy -g ResourceGroup -l eastus \
        --admin-username azureuser \
        --admin-password Secure1! \
        --ssl-cert /path/to/SSLCertificate.pfx \
        --ssl-cert-password DontRepeatPasswords1 \
        --auth-msi /path/to/RDGatewayFedAuth.msi \
        --version v0.1.1
"""
