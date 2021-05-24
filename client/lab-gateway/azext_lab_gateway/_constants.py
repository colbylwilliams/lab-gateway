# --------------------------------------------------------------------------------------------
# Copyright (c) Microsoft Corporation. All rights reserved.
# Licensed under the MIT License. See License.txt in the project root for license information.
# --------------------------------------------------------------------------------------------

TAG_PREFIX = 'hidden-lgw:'


def tag_key(key):
    return '{}{}'.format(TAG_PREFIX, key)


def get_resource_name(unique_string):
    return 'lgw{}a'.format(unique_string)


def get_function_name(prefix):
    return '{}-fa'.format(prefix)
