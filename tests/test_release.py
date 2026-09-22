"""Deployment validation, emitted configuration and original audio integrity."""
import copy
import hashlib
import json
import math
from pathlib import Path
import struct
import subprocess
import sys
import tempfile
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
import release


class ReleaseTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.template = release.template()

    def test_catalog_template_has_every_product_and_sound(self):
        checked = json.loads((ROOT / 'deployment/template.json').read_text(encoding='utf-8'))
        self.assertEqual(checked, self.template)
        missing, configured = release.validate(checked, self.template)
        self.assertEqual(len(missing), 45)
        self.assertEqual(configured, [])

    def test_invalid_and_duplicate_ids_are_rejected(self):
        for invalid in (True, -1, 1.5, '123', 10**20):
            data = copy.deepcopy(self.template)
            data['MatchPlaceId'] = invalid
            with self.assertRaises(ValueError): release.validate(data, self.template)
        data = copy.deepcopy(self.template)
        data['Products']['Heroes']['thor']['id'] = 99
        data['Products']['Consumables']['gold1000']['id'] = 99
        with self.assertRaises(ValueError): release.validate(data, self.template)
        data = copy.deepcopy(self.template)
        data['MatchPlaceId'] = data['LobbyPlaceId'] = 99
        with self.assertRaises(ValueError): release.validate(data, self.template)

    def test_configured_source_executes_and_keeps_gameplay(self):
        data = copy.deepcopy(self.template)
        data['LobbyPlaceId'], data['MatchPlaceId'], data['UniverseId'] = 123, 456, 789
        data['Audio']['lobby'] = 314
        data['Products']['Heroes']['thor']['id'] = 271
        data['GroupId'] = 555
        missing, configured = release.validate(data, self.template)
        self.assertIn(('GroupId', 555), configured)
        self.assertNotIn('GroupId', missing)
        source = release.config_source((ROOT / 'src/shared/Config.luau').read_text(encoding='utf-8'), data, self.template)
        harness = 'local c=(function()\n' + source + '\nend)()\nassert(c.StartEnergy==600 and c.MaxPartySize==4 and c.LobbyPlaceId==123 and c.MatchPlaceId==456 and c.Audio.lobby==314 and c.Products.Heroes.thor.id==271 and c.GroupId==555)\n'
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'config.luau'
            path.write_text(harness, encoding='utf-8')
            subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(path)], check=True)

    def test_group_is_optional_and_validated(self):
        data = copy.deepcopy(self.template)
        missing, _ = release.validate(data, self.template)
        self.assertNotIn('GroupId', missing, 'No group is a valid choice, never a release blocker')
        for invalid in (-5, 1.5, '12', True):
            data['GroupId'] = invalid
            with self.assertRaises(ValueError): release.validate(data, self.template)

    def test_unconfigured_public_build_writes_nothing(self):
        with tempfile.TemporaryDirectory() as temp:
            output = Path(temp) / 'release'
            result = subprocess.run([sys.executable, str(ROOT / 'tools/release.py'), '--config', str(ROOT / 'deployment/template.json'), '--output', str(output)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output.exists())

    def test_audio_samples_match_manifest_and_are_not_clipped(self):
        base = ROOT / 'assets/audio'
        manifest = json.loads((base / 'manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(set(manifest['assets']), set(self.template['Audio']))
        for name, entry in manifest['assets'].items():
            path = base / entry['file']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), entry['sha256'])
            with wave.open(str(path)) as sound:
                self.assertEqual((sound.getnchannels(), sound.getsampwidth(), sound.getframerate()), (1, 2, 32000))
                data = sound.readframes(sound.getnframes())
            samples = [value[0] for value in struct.iter_unpack('<h', data)]
            self.assertGreater(max(abs(value) for value in samples), 1000, name)
            self.assertLessEqual(max(abs(value) for value in samples), 23600, name)
            self.assertLess(abs(sum(samples) / len(samples)), 100, name)
            self.assertLess(abs(samples[0] - samples[-1]), 2500, name + ' loop seam')
            self.assertAlmostEqual(len(samples) / 32000, entry['seconds'], places=2)


if __name__ == '__main__': unittest.main(verbosity=2)
