"""Compose the project's original audio pack. Standard library only.

No samples, existing melodies, downloaded recordings or random loudness spikes.
Loops use wrapped note/reverb tails so there is no silent seam at the boundary.
Run: python tools/generate_audio.py
"""
from array import array
import hashlib
import json
import math
from pathlib import Path
import random
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
RATE = 32000
TAU = math.tau


class Song:
    def __init__(self, seconds, loop=False):
        self.samples = array('f', [0]) * round(seconds * RATE)
        self.loop = loop

    def note(self, start, duration, midi, gain=0.1, voice='bell'):
        frequency = 440 * 2 ** ((midi - 69) / 12)
        offset = round(start * RATE)
        count = round(duration * RATE)
        length = len(self.samples)
        for i in range(count):
            t = i / RATE
            phase = TAU * frequency * t
            attack = min(1, t / (0.12 if voice == 'pad' else 0.009))
            release = min(1, (count - i) / (RATE * 0.09))
            if voice == 'pad':
                signal = (math.sin(phase) + 0.27 * math.sin(phase * 2) + 0.12 * math.sin(phase * 3)) / 1.39
                envelope = attack * release * 0.75
            elif voice == 'bass':
                signal = math.sin(phase) + 0.18 * math.sin(phase * 2)
                envelope = attack * release * math.exp(-t * 3)
            else:
                signal = math.sin(phase) + 0.25 * math.sin(phase * 2) * math.exp(-t * 5)
                envelope = attack * release * math.exp(-t * 3.7)
            index = offset + i
            if self.loop: index %= length
            if index < length: self.samples[index] += signal * envelope * gain

    def drum(self, start, gain, snare=False):
        rng = random.Random(round(start * 1000) + 51)
        for i in range(round(RATE * 0.15)):
            t = i / RATE
            noise = rng.uniform(-1, 1)
            signal = noise * math.exp(-t * 34) if snare else math.sin(TAU * (58 * t + 2 * (1 - math.exp(-t * 35)))) * math.exp(-t * 24)
            index = round(start * RATE) + i
            if self.loop: index %= len(self.samples)
            if index < len(self.samples): self.samples[index] += signal * gain * min(1, t / 0.003)

    def save(self, path):
        # Quiet short reflections add space without masking the lead melody.
        dry = self.samples[:]
        for seconds, gain in ((0.087, 0.10), (0.173, 0.055)):
            delay = round(seconds * RATE)
            for i in range(len(dry)):
                source = i - delay
                if source >= 0 or self.loop:
                    self.samples[i] += dry[source % len(dry)] * gain
        peak = max(abs(value) for value in self.samples) or 1
        scale = min(1, 0.72 / peak)
        pcm = array('h', (round(value * scale * 32767) for value in self.samples))
        if sys.byteorder != 'little': pcm.byteswap()
        with wave.open(str(path), 'wb') as output:
            output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
            output.writeframes(pcm.tobytes())
        return dict(file=path.name, seconds=round(len(pcm) / RATE, 3), loop=self.loop,
                    peak=round(peak * scale, 4), sha256=hashlib.sha256(path.read_bytes()).hexdigest(), assetId=0)


def lobby():
    beat = 60 / 80
    song = Song(64 * beat, True)
    # Cmaj7 / Am7 / Fmaj7 / Gsus: a warm forest courtyard, with a small
    # original call-and-response motif and room between phrases.
    chords = [(48, 55, 59, 64), (45, 52, 55, 60), (41, 48, 52, 57), (43, 50, 55, 60)]
    motif = [76, 79, 74, 72, 71, 74, 76, 67]
    for bar in range(16):
        chord = chords[(bar // 2) % 4]
        start = bar * 4 * beat
        for note in chord: song.note(start, beat * 4.2, note, 0.032, 'pad')
        for step in range(4): song.note(start + step * beat, beat * 1.4, chord[step] + 12, 0.065)
        if bar % 4 != 3:
            for step in range(2): song.note(start + (step * 1.5 + 0.5) * beat, beat * 1.7, motif[(bar * 2 + step) % 8], 0.11)
    return song


def battle():
    beat = 60 / 112
    song = Song(64 * beat, True)
    chords = [(38, 45, 53, 57), (34, 41, 50, 53), (41, 48, 53, 57), (36, 43, 52, 55)]
    for bar in range(16):
        chord = chords[(bar // 2) % 4]
        start = bar * 4 * beat
        for note in chord[1:]: song.note(start, beat * 4.1, note, 0.025, 'pad')
        for step in range(8):
            at = start + step * beat / 2
            song.note(at, beat * 0.62, chord[step % 4] + 12, 0.065)
            if step % 2 == 0: song.note(at, beat * 0.8, chord[0], 0.12, 'bass')
        for step in range(4): song.drum(start + step * beat, 0.07 if step % 2 else 0.12, step % 2 == 1)
        if bar % 2:
            for step, note in enumerate([69, 72, 77, 76]): song.note(start + step * beat, beat * 0.9, note, 0.07)
    return song


def main():
    output = ROOT / 'assets' / 'audio'
    output.mkdir(parents=True, exist_ok=True)
    assets = {}
    for name, song in [('lobby', lobby()), ('battle', battle())]:
        assets[name] = song.save(output / f'{name}.wav')
    cues = {
        'collect': ([84, 91], 0.07), 'place': ([60, 67, 72], 0.065),
        'upgrade': ([72, 76, 79, 84], 0.10), 'levelUp': ([67, 72, 76, 79, 84], 0.13),
        'victory': ([60, 64, 67, 72, 76, 79, 84], 0.17),
        'defeat': ([67, 64, 60, 57], 0.24), 'breach': ([48, 43], 0.12),
        'ability': ([55, 67, 74, 79], 0.055), 'boss': ([38, 45, 50], 0.23),
        'wave': ([67, 72, 76], 0.11), 'chest': ([60, 67, 72, 76, 79, 84], 0.12),
    }
    for name, (notes, gap) in cues.items():
        song = Song(len(notes) * gap + 0.55)
        for i, note in enumerate(notes): song.note(i * gap, 0.55, note, 0.23)
        assets[name] = song.save(output / f'{name}.wav')
    manifest = dict(sampleRate=RATE, channels=1, bits=16, provenance='Original procedural compositions; no third-party samples.', assets=assets)
    (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Generated {len(assets)} original WAV assets in {output}')


if __name__ == '__main__': main()
