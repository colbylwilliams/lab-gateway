import os
import json
import argparse
import subprocess
from pathlib import Path
from re import search

parser = argparse.ArgumentParser()
parser.add_argument('version', help='version number string')

args = parser.parse_args()

version = args.version.lower()
if version[:1].isdigit():
    version = 'v' + version

index = {}
index['arm'] = {}
index['artifacts'] = {}

assets = []

ci = os.environ.get('CI', False)

arm_dir = 'assets/arm' if ci else 'tools/tmp/arm'
artifacts_dir = 'assets/artifacts' if ci else 'tools/tmp/artifacts'
index_path = 'index.json' if ci else 'tools/tmp/index.json'

with os.scandir(Path.cwd() / arm_dir) as s:
    for f in s:
        if f.is_file():
            print(f.path)
            name = f.name.rsplit('.', 1)[0]
            assets.append({'name': f.name, 'path': f.path})
            index['arm'][name] = {
                'name': f.name,
                'version': '{}'.format(version),
                'url': 'https://github.com/colbylwilliams/lab-gateway/releases/download/{}/{}'.format(version, f.name)
            }

with os.scandir(Path.cwd() / artifacts_dir) as s:
    for f in s:
        if f.is_file():
            print(f.path)
            name = f.name.rsplit('.', 1)[0]
            assets.append({'name': f.name, 'path': f.path})
            index['artifacts'][name] = {
                'name': f.name,
                'version': '{}'.format(version),
                'url': 'https://github.com/colbylwilliams/lab-gateway/releases/download/{}/{}'.format(version, f.name)
            }

index['gateway'] = {
    'version': '{}'.format(version),
    'zipUrl': 'https://github.com/colbylwilliams/lab-gateway/releases/download/{}/Gateway.zip'.format(version),
}

assets.append({'name': 'Gateway.zip', 'path': '{}/{}'.format(Path.cwd(), 'Gateway.zip')})

with open(Path(Path.cwd() / 'client/lab-gateway') / 'setup.py', 'r') as f:
    for line in f:
        if line.startswith('VERSION'):
            txt = str(line).rstrip()
            match = search(r'VERSION = [\'\"](.*)[\'\"]$', txt)
            if match:
                cli_ver = match.group(1)
                cli_name = 'lab_gateway-{}-py2.py3-none-any.whl'.format(cli_ver)
                # assets.append({'name': cli_name, 'path': '{}/dist/{}'.format(Path.cwd(), cli_name)})
                print("::set-output name=version::{}".format(cli_ver))

with open(Path.cwd() / index_path, 'w') as f:
    json.dump(index, f, ensure_ascii=False, indent=4, sort_keys=True)

assets.append({'name': 'index.json', 'path': '{}/{}'.format(Path.cwd(), 'index.json')})

if ci:
    with open(Path.cwd() / 'tools/tmp/assets.json', 'w') as f:
        json.dump(assets, f, ensure_ascii=False, indent=4, sort_keys=True)

print("::set-output name=assets::{}".format(json.dumps(assets)))
