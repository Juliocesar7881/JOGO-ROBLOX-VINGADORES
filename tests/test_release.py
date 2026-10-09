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
        self.assertEqual(len(missing), 88)
        self.assertEqual(configured, [])

    def test_uploaded_audio_ids_match_the_manifest_and_the_files(self):
        """Config.Audio carries the uploaded IDs, one per WAV, none repeated."""
        uploads = json.loads((ROOT / 'assets/audio/uploads.json').read_text(encoding='utf-8'))['ids']
        config = (ROOT / 'src/shared/Config.luau').read_text(encoding='utf-8')
        start = config.index('Audio = {')
        block = config[start:config.index('MapImages', start)]
        import re
        found = {key: int(value) for key, value in re.findall(r'(\w+) = (\d+)', block)}
        wavs = sorted(path.stem for path in (ROOT / 'assets/audio').glob('*.wav'))
        self.assertEqual(sorted(uploads), wavs)
        for key in wavs:
            self.assertEqual(found.get(key), uploads[key], key)
        self.assertEqual(len(set(uploads.values())), len(uploads))
        for value in uploads.values():
            self.assertTrue(10**13 < value < 10**16)

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

    def test_afk_place_is_optional_and_distinct(self):
        data = release.template()
        missing, configured = release.validate(data, release.template())
        self.assertNotIn('AfkPlaceId', missing)
        data['LobbyPlaceId'], data['MatchPlaceId'], data['AfkPlaceId'] = 123, 456, 777
        missing, configured = release.validate(data, release.template())
        self.assertIn(('AfkPlaceId', 777), configured)
        data['AfkPlaceId'] = 123
        with self.assertRaises(ValueError): release.validate(data, release.template())
        data['AfkPlaceId'] = -1
        with self.assertRaises(ValueError): release.validate(data, release.template())

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
        harness = 'local c=(function()\n' + source + '\nend)()\nassert(c.StartCash==600 and c.MaxPartySize==4 and c.LobbyPlaceId==123 and c.MatchPlaceId==456 and c.Audio.lobby==314 and c.Products.Heroes.thor.id==271 and c.GroupId==555 and c.AfkPlaceId==0)\n'
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'config.luau'
            path.write_text(harness, encoding='utf-8')
            subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(path)], check=True)

    def test_map_images_are_optional_and_configured(self):
        data = copy.deepcopy(self.template)
        self.assertEqual(set(data['MapImages']), {'manhattan', 'gamma', 'hydra', 'wakanda', 'asgard', 'latveria'})
        missing, _ = release.validate(data, self.template)
        self.assertFalse([key for key in missing if key.startswith('MapImages')], 'A diorama is a valid sign, never a release blocker')
        data['MapImages']['asgard'] = 4242
        missing, configured = release.validate(data, self.template)
        self.assertIn(('MapImages.asgard', 4242), configured)
        original = (ROOT / 'src/shared/Config.luau').read_text(encoding='utf-8')
        source = release.config_source(original, data, self.template)
        harness = 'local original=(function()\n' + original + '\nend)()\nlocal c=(function()\n' + source + '\nend)()\nassert(c.MapImages.asgard==4242)\nfor key,id in pairs(original.MapImages) do if key~="asgard" then assert(id>0 and c.MapImages[key]==id, "release must preserve shipped photographs") end end\n'
        with tempfile.TemporaryDirectory() as temp:
            path = Path(temp) / 'config.luau'
            path.write_text(harness, encoding='utf-8')
            subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(path)], check=True)
        for invalid in (-1, 1.5, '12', True):
            data['MapImages']['asgard'] = invalid
            with self.assertRaises(ValueError): release.validate(data, self.template)

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

    def test_summon_audio_preserves_reference_and_distinct_endings(self):
        base = ROOT / 'assets/audio/summon'
        manifest = json.loads((base / 'manifest.json').read_text(encoding='utf-8'))
        expected = {'reelStart', 'reelTick', 'rewardCommon', 'rewardRare',
                    'rewardEpic', 'rewardLegendary', 'rewardMythic'}
        self.assertEqual(set(manifest['assets']), expected)
        reference = manifest['reference']
        self.assertEqual(hashlib.sha256((base / reference['file']).read_bytes()).hexdigest(), reference['sha256'])
        hashes = set()
        for name, entry in manifest['assets'].items():
            self.assertEqual(entry['assetId'], 0, 'Prepared files must not claim uploads')
            path = base / entry['file']
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), entry['sha256'])
            hashes.add(entry['sha256'])
            with wave.open(str(path)) as sound:
                self.assertEqual((sound.getnchannels(), sound.getsampwidth(), sound.getframerate()), (1, 2, 32000))
                samples = [v[0] for v in struct.iter_unpack('<h', sound.readframes(sound.getnframes()))]
            self.assertGreater(max(abs(v) for v in samples), 1000)
            self.assertLessEqual(max(abs(v) for v in samples), 23600)
            self.assertAlmostEqual(len(samples) / 32000, entry['seconds'], places=2)
            if name.startswith('reward'):
                self.assertEqual(entry['origin'], 'original synthesis')
                self.assertNotIn('sourceSeconds', entry)
            else:
                self.assertEqual(entry['origin'], 'owner-provided reference excerpt')
                self.assertLess(entry['sourceSeconds'][1], 7.7, 'Never use the reference ending')
        self.assertEqual(len(hashes), 7, 'Every rarity ending and reel cue is distinct')

    def test_refined_audio_sources_are_complete_and_not_claimed_as_uploads(self):
        base = ROOT / 'assets/audio/refined'
        manifest = json.loads((base / 'manifest.json').read_text(encoding='utf-8'))
        expected = {'lobby', 'battle', 'click', 'collect', 'open', 'place', 'upgrade',
                    'shotTech', 'shotArrow', 'shotMagic', 'shotMelee', 'shotBlast'}
        self.assertEqual(set(manifest['assets']), expected)
        self.assertEqual(set(path.stem for path in base.glob('*.wav')), expected)
        hashes = set()
        for name, entry in manifest['assets'].items():
            path = base / entry['file']
            self.assertEqual(entry['assetId'], 0, 'Unuploaded sources must not claim Roblox IDs')
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), entry['sha256'])
            hashes.add(entry['sha256'])
            with wave.open(str(path)) as sound:
                self.assertEqual((sound.getnchannels(), sound.getsampwidth(), sound.getframerate()), (1, 2, 32000))
                samples = [v[0] for v in struct.iter_unpack('<h', sound.readframes(sound.getnframes()))]
            self.assertGreater(max(abs(v) for v in samples), 1000, name + ' must be audible')
            self.assertLessEqual(max(abs(v) for v in samples), 23600, name + ' must not clip')
            self.assertLess(abs(sum(samples) / len(samples)), 100, name + ' DC offset')
            self.assertAlmostEqual(len(samples) / 32000, entry['seconds'], places=2)
            if entry['loop']:
                self.assertGreater(entry['seconds'], 30)
                self.assertLess(abs(samples[0] - samples[-1]), 2500, name + ' loop seam')
            else:
                self.assertLessEqual(entry['seconds'], .65, 'Ordinary actions must stay short')
        self.assertEqual(len(hashes), len(expected), 'Material sounds must be distinct files')

    def test_audio_samples_match_manifest_and_are_not_clipped(self):
        base = ROOT / 'assets/audio'
        manifest = json.loads((base / 'manifest.json').read_text(encoding='utf-8'))
        summon = json.loads((base / 'summon/manifest.json').read_text(encoding='utf-8'))
        self.assertEqual(set(manifest['assets']) | set(summon['assets']), set(self.template['Audio']),
                         'Every configured sound must have a source in one of the packs')
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
