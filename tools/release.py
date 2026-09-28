"""Configure and assemble owner-specific places without editing gameplay source.

python tools/release.py --template deployment/template.json
python tools/release.py --config deployment/local.json --check
python tools/release.py --config deployment/local.json --output dist/release
Use --private to build an incomplete private test package with a blockers report.
Never uploads, publishes, creates products or reads Roblox credentials.
"""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

import build

ROOT = Path(__file__).resolve().parents[1]


def catalog():
    cli = ROOT / '.tools/luau/luau.exe'
    executable = str(cli) if cli.is_file() else shutil.which('luau')
    if not executable: raise ValueError('Install the official Luau CLI with tools/setup_luau.py.')
    result = subprocess.run([executable, 'tools/release_catalog.luau'], cwd=ROOT, check=True, capture_output=True, text=True, encoding='utf-8')
    products, audio, images = {}, [], []
    for line in result.stdout.splitlines():
        parts = line.split('|')
        if parts[0] == 'PRODUCT': products.setdefault(parts[1], {})[parts[2]] = int(parts[3])
        elif parts[0] == 'AUDIO': audio.append(parts[1])
        elif parts[0] == 'IMAGE': images.append(parts[1])
    return products, audio, images


def template():
    products, audio, images = catalog()
    # GroupId is optional: 0 simply hides the join-the-group reward.
    # AfkPlaceId is optional too: 0 keeps AFK farming inside the lobby.
    # MapImages are optional overrides: 0 keeps the shipped map photographs.
    return {'UniverseId': 0, 'LobbyPlaceId': 0, 'MatchPlaceId': 0, 'AfkPlaceId': 0, 'GroupId': 0,
            'Products': {group: {key: {'id': 0} for key in rows} for group, rows in products.items()},
            'Audio': {key: 0 for key in audio}, 'MapImages': {key: 0 for key in images}}


def validate(data, expected):
    if not isinstance(data, dict): raise ValueError('Configuration must be a JSON object.')
    unknown = set(data) - set(expected)
    if unknown: raise ValueError(f'Unknown configuration keys: {sorted(unknown)}')
    missing, configured = [], []
    def asset(value, key):
        if type(value) is not int or not 0 <= value <= 9007199254740991:
            raise ValueError(f'{key} must be a nonnegative integer Roblox ID.')
        if value == 0: missing.append(key)
        else: configured.append((key, value))
    for key in ('UniverseId', 'LobbyPlaceId', 'MatchPlaceId'): asset(data.get(key, 0), key)
    afk = data.get('AfkPlaceId', 0)
    if type(afk) is not int or not 0 <= afk <= 9007199254740991: raise ValueError('AfkPlaceId must be a nonnegative integer Roblox ID.')
    if afk: configured.append(('AfkPlaceId', afk))
    if afk and afk in (data.get('LobbyPlaceId', 0), data.get('MatchPlaceId', 0)):
        raise ValueError('The AFK place must be its own place.')
    group = data.get('GroupId', 0)
    if type(group) is not int or not 0 <= group <= 9007199254740991: raise ValueError('GroupId must be a nonnegative integer Roblox ID.')
    if group: configured.append(('GroupId', group))
    if data.get('LobbyPlaceId', 0) and data.get('LobbyPlaceId') == data.get('MatchPlaceId'):
        raise ValueError('Lobby and Match must be different places.')
    for group in ('Products', 'Audio', 'MapImages'):
        entries = data.get(group, {})
        if not isinstance(entries, dict) or set(entries) - set(expected[group]): raise ValueError(f'Invalid {group} keys.')
    product_ids = set()
    for category, rows in expected['Products'].items():
        entries = data.get('Products', {}).get(category, {})
        if not isinstance(entries, dict) or set(entries) - set(rows): raise ValueError(f'Invalid Products.{category} keys.')
        for key in rows:
            entry = entries.get(key, {'id': 0})
            if not isinstance(entry, dict) or set(entry) != {'id'}: raise ValueError(f'Products.{category}.{key} needs only an id.')
            value = entry['id']
            asset(value, f'Products.{category}.{key}')
            # Pass IDs and Developer Product IDs belong to distinct namespaces.
            namespace = 'pass' if category == 'Passes' else 'product'
            if value and (namespace, value) in product_ids: raise ValueError(f'Duplicate {namespace} ID: {value}')
            if value: product_ids.add((namespace, value))
    for key in expected['Audio']: asset(data.get('Audio', {}).get(key, 0), f'Audio.{key}')
    for key in expected['MapImages']:
        value = data.get('MapImages', {}).get(key, 0)
        if type(value) is not int or not 0 <= value <= 9007199254740991: raise ValueError(f'MapImages.{key} must be a nonnegative integer Roblox ID.')
        if value: configured.append((f'MapImages.{key}', value))
    return missing, configured


def config_source(source, data, expected):
    # Only validated integer IDs and catalog-derived keys are inserted into Luau.
    lines = ['local configured = (function()', source, 'end)()']
    for key in ('UniverseId', 'LobbyPlaceId', 'MatchPlaceId', 'AfkPlaceId', 'GroupId'):
        lines.append(f'configured.{key} = {data.get(key, 0)}')
    for category, rows in expected['Products'].items():
        lines.append(f'configured.Products.{category} = {{}}')
        for key in rows:
            value = data.get('Products', {}).get(category, {}).get(key, {}).get('id', 0)
            lines.append(f'configured.Products.{category}[{json.dumps(key)}] = {{ id = {value} }}')
    for key in expected['Audio']:
        lines.append(f'configured.Audio[{json.dumps(key)}] = {data.get("Audio", {}).get(key, 0)}')
    for key in expected['MapImages']:
        value = data.get('MapImages', {}).get(key, 0)
        if value:
            lines.append(f'configured.MapImages[{json.dumps(key)}] = {value}')
    lines.append('return configured')
    return '\n'.join(lines) + '\n'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--template', type=Path)
    parser.add_argument('--config', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / 'dist/release')
    parser.add_argument('--check', action='store_true')
    parser.add_argument('--private', action='store_true')
    args = parser.parse_args()
    expected = template()
    if args.template:
        args.template.parent.mkdir(parents=True, exist_ok=True)
        with args.template.open('x', encoding='utf-8') as output: json.dump(expected, output, indent=2); output.write('\n')
        print(f'Created {args.template}')
        return
    if not args.config: parser.error('--config or --template is required')
    data = json.loads(args.config.read_text(encoding='utf-8-sig'))
    missing, configured = validate(data, expected)
    print(f'Configured: {len(configured)} IDs. Missing: {len(missing)}.')
    for key in missing: print(f'  MISSING {key}')
    if missing and not args.private: raise SystemExit('Incomplete owner configuration. No release artifacts were written. Use --private for a private preview.')
    if args.check: return
    paths = build.build(args.output)
    for path in paths:
        tree = ET.parse(path)
        modules = [node for node in tree.findall('.//Item[@class="ModuleScript"]') if node.findtext('Properties/string[@name="Name"]') == 'Config']
        if len(modules) != 1: raise ValueError('Expected exactly one embedded Config module.')
        node = modules[0].find('Properties/ProtectedString[@name="Source"]')
        node.text = config_source(node.text, data, expected)
        tree.write(path, encoding='utf-8', xml_declaration=True)
    manifest_path = args.output / 'build-manifest.json'
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    for path in paths: manifest['artifacts'][path.name]['sha256'] = hashlib.sha256(path.read_bytes()).hexdigest()
    manifest['deployment'] = {'sha256': hashlib.sha256(args.config.read_bytes()).hexdigest(), 'missing': missing,
                              'privatePreview': args.private, 'cloudValidated': False}
    manifest_path.write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    (args.output / 'deployment-report.json').write_text(json.dumps(manifest['deployment'], indent=2) + '\n', encoding='utf-8')
    print(f'Built {len(paths)} configured places in {args.output}. Cloud ownership, prices and permissions still require published testing.')


if __name__ == '__main__':
    try: main()
    except (ValueError, OSError) as error: raise SystemExit(str(error))
