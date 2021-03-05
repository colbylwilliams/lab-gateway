import json
import argparse
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('version', help='version number string')

args = parser.parse_args()

version = args.version.lower()
if version[:1].isdigit():
    version = 'v' + version

index = {}

index['gateway'] = {
    'version': '{}'.format(version),
    'deployUrl': 'https://github.com/colbylwilliams/lab-gateway/releases/download/{}/azuredeploy.json'.format(version),
    'zipUrl': 'https://github.com/colbylwilliams/lab-gateway/releases/download/{}/Gateway.zip'.format(version),
    'scriptUrl': 'https://github.com/colbylwilliams/lab-gateway/releases/download/{}/gateway.ps1'.format(version),
}

index['lab'] = {
    'version': '{}'.format(version),
    'deployUrl': 'https://github.com/colbylwilliams/lab-gateway/releases/download/{}/azuredeploy.lab.json'.format(version),
}

with open(Path.cwd() / 'index.json', 'w') as f:
    json.dump(index, f, ensure_ascii=False, indent=4, sort_keys=True)
