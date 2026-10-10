"""Check licensed atlas metadata, runtime regions and private rendering integrity."""
import array
import hashlib
import json
from pathlib import Path
import re
import subprocess
import unittest
import wave

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/audio/sonniss'


class SoundBankTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((BASE / 'manifest.json').read_text(encoding='utf-8'))

    def test_every_bundle_contributes_and_origins_are_traceable(self):
        manifest = self.manifest
        self.assertEqual(sum(item['recordings'] for item in manifest['inventory']), 347)
        self.assertEqual({item['bundle'] for item in manifest['sources'].values()}, set(range(1, 6)))
        self.assertEqual(len(manifest['assets']), 7)
        self.assertEqual(len(manifest['cues']), 56)
        for cue in manifest['cues'].values():
            for variant in cue['variants']:
                self.assertIn(variant['origin'], manifest['sources'])

    def test_runtime_regions_match_rendered_timeline_and_do_not_overlap(self):
        source = (ROOT / 'src/client/SoundBank.luau').read_text(encoding='utf-8')
        intervals = {}
        for name, cue in self.manifest['cues'].items():
            asset = self.manifest['assets'][cue['bank']]
            match = re.search(r'\b' + re.escape(name) + r' = \{asset = "([^"]+)", loop = (\w+), regions = \{(.*?)\}\},', source)
            self.assertIsNotNone(match, name)
            self.assertEqual(match[1], asset['configKey'])
            self.assertEqual(match[2], str(cue['loop']).lower())
            regions = [[float(a), float(b)] for a, b in re.findall(r'\{([\d.]+), ([\d.]+)\}', match[3])]
            self.assertEqual(regions, [[v['start'], v['stop']] for v in cue['variants']])
            for start, stop in regions:
                self.assertGreater(stop, start)
                self.assertLess(stop, asset['seconds'])
                intervals.setdefault(cue['bank'], []).append((start, stop))
        for regions in intervals.values():
            regions.sort()
            for current, following in zip(regions, regions[1:]):
                self.assertGreaterEqual(following[0] - current[1], .14999)

    def test_recordings_cannot_be_in_the_public_git_package(self):
        tracked = subprocess.run(['git', 'ls-files', 'assets/audio/sonniss'], cwd=ROOT, capture_output=True, text=True, check=True).stdout.splitlines()
        self.assertFalse([path for path in tracked if Path(path).suffix.lower() in {'.wav', '.mp3', '.zip'}])
        result = subprocess.run(['git', 'check-ignore', 'assets/audio/sonniss/rendered/sfx_combat.wav',
                                 'assets/audio/sonniss/audition/heavy-1.wav'], cwd=ROOT, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0)
        self.assertEqual(len(result.stdout.splitlines()), 2)

    def test_local_pcm_when_present_is_complete_and_not_clipped(self):
        paths = [BASE / 'rendered' / asset['file'] for asset in self.manifest['assets'].values()]
        if not any(path.exists() for path in paths):
            self.skipTest('Licensed PCM is deliberately absent from public checkouts; owner rebuilds from ZIPs')
        for asset, path in zip(self.manifest['assets'].values(), paths):
            self.assertTrue(path.is_file(), path.name)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), asset['sha256'])
            self.assertLess(path.stat().st_size, 20_000_000)
            with wave.open(str(path)) as audio:
                self.assertEqual((audio.getnchannels(), audio.getsampwidth(), audio.getframerate()), (1, 2, 32000))
                self.assertAlmostEqual(audio.getnframes() / 32000, asset['seconds'], places=5)
                pcm = array.array('h', audio.readframes(audio.getnframes()))
            self.assertGreater(max(abs(value) for value in pcm), 1000)
            self.assertLessEqual(max(abs(value) for value in pcm), 23594)


if __name__ == '__main__':
    unittest.main()
