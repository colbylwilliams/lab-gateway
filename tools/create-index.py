import os
import json
import argparse
import subprocess
from pathlib import Path

parser = argparse.ArgumentParser()
parser.add_argument('version', help='version number string')

args = parser.parse_args()

version = args.version.lower()
if version[:1].isdigit():
    version = 'v' + version

templates = []

arm_dir = '{}/{}'.format(Path.cwd(), 'arm')
# arm_dir = '{}/{}'.format(Path.cwd(), 'tools/tmp/arm')

with os.scandir(Path.cwd() / 'arm/gateway') as s:
    for f in s:
        if f.name.endswith('.bicep') and f.is_file():
            name = f.name.rsplit('.bicep', 1)[0]
            arm_name = '{}.json'.format(name)
            templates.append({
                'name': name,
                'bicep': {
                    'name': f.name,
                    'path': f.path,
                },
                'arm': {
                    'name': arm_name,
                    'path': '{}/{}'.format(arm_dir, arm_name)
                }
            })

for t in templates:
    print('Compiling template: {}'.format(t['name']))
    subprocess.run(['az', 'bicep', 'build', '-f', t['bicep']['path'], '--outfile', t['arm']['path']])

print("::set-output name=templates::{}".format(json.dumps(templates)))

index = {}
assets = []

index['arm'] = {}

for t in templates:
    assets.append({'name': t['arm']['name'], 'path': t['arm']['path']})
    index['arm'][t['name']] = {
        'name': t['name'],
        'version': '{}'.format(version),
        'deployUrl': 'https://github.com/colbylwilliams/lab-gateway/releases/download/{}/{}'.format(version, t['arm']['name'])
    }

print("::set-output name=assets::{}".format(json.dumps(assets)))

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
    # with open(Path.cwd() / 'tools/tmp/index.json', 'w') as f:
    json.dump(index, f, ensure_ascii=False, indent=4, sort_keys=True)

with open(Path.cwd() / 'assets.json', 'w') as f:
    # with open(Path.cwd() / 'tools/tmp/assets.json', 'w') as f:
    json.dump(assets, f, ensure_ascii=False, indent=4, sort_keys=True)
