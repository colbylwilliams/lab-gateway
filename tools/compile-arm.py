import os
import json
import subprocess
from pathlib import Path

templates = []

arm_dir = '{}/{}'.format(Path.cwd(), 'assets/arm')
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