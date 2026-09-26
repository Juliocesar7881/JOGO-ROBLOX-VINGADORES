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



# ---------------------------------------------------------------------------
# Map ambiences and combat cues. Everything below is synthesised here: filtered
# noise, sines and the same bell/pad voices as the music. Ambience loops filter
# their noise circularly (two passes around the buffer), so the last sample
# flows into the first with no click at the seam.
# ---------------------------------------------------------------------------
AMBIENCE_SECONDS = 20.0


def circular_lowpass(values, alpha):
    """One-pole lowpass run twice around a looping buffer (seamless)."""
    state = 0.0
    out = array('f', [0]) * len(values)
    for _ in range(2):
        for i, value in enumerate(values):
            state += alpha * (value - state)
            out[i] = state
    return out


def noise(count, seed):
    rng = random.Random(seed)
    return array('f', (rng.uniform(-1, 1) for _ in range(count)))


def loop_cycles(song, cycles):
    """A frequency that fits a whole number of times in the loop."""
    return cycles / (len(song.samples) / RATE)


def add_wind(song, seed, gain, alpha=0.012, swells=(3, 5)):
    body = circular_lowpass(noise(len(song.samples), seed), alpha)
    peak = max(abs(v) for v in body) or 1
    slow = [loop_cycles(song, c) for c in swells]
    for i, value in enumerate(body):
        t = i / RATE
        swell = 0.55 + 0.25 * math.sin(TAU * slow[0] * t) + 0.2 * math.sin(TAU * slow[1] * t + 1.3)
        song.samples[i] += value / peak * swell * gain


def add_drone(song, frequency, gain, beat_cycles=4):
    beat = loop_cycles(song, beat_cycles)
    f = loop_cycles(song, round(frequency * AMBIENCE_SECONDS))
    for i in range(len(song.samples)):
        t = i / RATE
        wobble = 0.8 + 0.2 * math.sin(TAU * beat * t)
        song.samples[i] += (math.sin(TAU * f * t) + 0.35 * math.sin(TAU * 2 * f * t)) * wobble * gain


def add_blip(song, start, seconds, f0, f1, gain, decay=12.0):
    """A pitch glide, wrapped around the loop."""
    count = round(seconds * RATE)
    phase = 0.0
    for i in range(count):
        t = i / RATE
        frequency = f0 + (f1 - f0) * (i / count)
        phase += TAU * frequency / RATE
        envelope = min(1, t / 0.004) * math.exp(-t * decay)
        index = (round(start * RATE) + i) % len(song.samples)
        song.samples[index] += math.sin(phase) * envelope * gain


def add_clank(song, start, gain, seed):
    rng = random.Random(seed)
    partials = [rng.uniform(380, 2600) for _ in range(5)]
    for i in range(round(RATE * 0.7)):
        t = i / RATE
        value = sum(math.sin(TAU * p * t) * math.exp(-t * (6 + k * 3)) for k, p in enumerate(partials)) / 5
        index = (round(start * RATE) + i) % len(song.samples)
        song.samples[index] += value * gain * min(1, t / 0.002)


def add_hiss(song, start, seconds, gain, seed):
    body = noise(round(seconds * RATE), seed)
    smooth = 0.0
    for i, value in enumerate(body):
        smooth += 0.35 * (value - smooth)
        t = i / RATE
        envelope = math.sin(math.pi * min(1, t / seconds))
        index = (round(start * RATE) + i) % len(song.samples)
        song.samples[index] += (value - smooth) * envelope * gain


def ambience(name):
    song = Song(AMBIENCE_SECONDS, True)
    rng = random.Random(name)
    if name == 'ambManhattan':
        # Night city: a low traffic rumble, far horns, one siren passing.
        add_wind(song, 11, 0.5, alpha=0.004, swells=(2, 5))
        for start in (3.1, 11.4, 16.8):
            song.note(start, 0.5, 58 + rng.choice((0, 3)), 0.03, 'pad')
            song.note(start + 0.18, 0.4, 62, 0.02, 'pad')
        add_blip(song, 6.0, 4.0, 620, 760, 0.018, decay=0.4)
        add_blip(song, 10.0, 4.0, 760, 620, 0.016, decay=0.5)
    elif name == 'ambGamma':
        # Reactor: a beating drone, a slow hum and Geiger ticks.
        add_drone(song, 55, 0.12, beat_cycles=10)
        add_wind(song, 23, 0.12, alpha=0.02, swells=(4, 7))
        for _ in range(38):
            add_blip(song, rng.uniform(0, AMBIENCE_SECONDS), 0.012, 3200, 2800, 0.12, decay=300)
    elif name == 'ambHydra':
        # Industrial yard: mains hum, metal clanks and steam.
        add_drone(song, 60, 0.07, beat_cycles=2)
        for index, start in enumerate((1.2, 5.9, 9.3, 14.1, 17.7)):
            add_clank(song, start, 0.16, 90 + index)
        for index, start in enumerate((3.4, 12.2)):
            add_hiss(song, start, 1.6, 0.1, 70 + index)
        add_wind(song, 31, 0.18, alpha=0.006)
    elif name == 'ambWakanda':
        # Savanna evening: warm wind, birdsong and a far insect buzz.
        add_wind(song, 41, 0.35, alpha=0.01, swells=(3, 4))
        for _ in range(14):
            start = rng.uniform(0, AMBIENCE_SECONDS)
            base = rng.uniform(2200, 3400)
            for chirp in range(rng.randint(2, 4)):
                add_blip(song, start + chirp * 0.11, 0.07, base, base * 1.35, 0.05, decay=30)
        insect = loop_cycles(song, 5200 * AMBIENCE_SECONDS // 1)
        buzz = loop_cycles(song, 60)
        for i in range(len(song.samples)):
            t = i / RATE
            song.samples[i] += math.sin(TAU * insect * t) * (0.5 + 0.5 * math.sin(TAU * buzz * t)) * 0.004
    elif name == 'ambAsgard':
        # Rainbow bridge: high wind and a slow, bright choir of pads, far bells.
        add_wind(song, 53, 0.3, alpha=0.015, swells=(2, 3))
        for bar, chord in enumerate([(62, 69, 74), (64, 71, 76), (60, 67, 72), (62, 69, 74)]):
            for note in chord: song.note(bar * 5, 5.4, note, 0.022, 'pad')
        for start in (2.5, 9.0, 14.5):
            song.note(start, 1.6, rng.choice((86, 88, 91)), 0.035)
    elif name == 'ambLatveria':
        # Snow fortress: howling wind and a low, minor choir.
        add_wind(song, 67, 0.45, alpha=0.008, swells=(2, 5))
        add_blip(song, 1.0, 5.0, 320, 470, 0.012, decay=0.3)
        add_blip(song, 11.0, 5.0, 470, 300, 0.012, decay=0.3)
        for bar, chord in enumerate([(45, 52, 57), (43, 50, 55), (41, 48, 53), (40, 47, 52)]):
            for note in chord: song.note(bar * 5, 5.4, note, 0.03, 'pad')
    return song


def cue(name):
    if name == 'shotTech':
        song = Song(0.35)
        add_blip(song, 0, 0.14, 1900, 620, 0.5, decay=18)
        add_hiss(song, 0, 0.05, 0.2, 5)
    elif name == 'shotArrow':
        song = Song(0.45)
        add_hiss(song, 0, 0.22, 0.55, 7)
        add_blip(song, 0.0, 0.3, 230, 210, 0.3, decay=14)
    elif name == 'shotMagic':
        song = Song(0.6)
        for index, note in enumerate((88, 91, 95)): song.note(index * 0.04, 0.4, note, 0.12)
        add_blip(song, 0, 0.3, 900, 1500, 0.08, decay=9)
    elif name == 'shotMelee':
        song = Song(0.4)
        add_blip(song, 0, 0.22, 90, 38, 0.8, decay=16)
        add_hiss(song, 0, 0.04, 0.25, 9)
    elif name == 'shotBlast':
        song = Song(0.8)
        burst = noise(round(0.6 * RATE), 13)
        smooth = 0.0
        for i, value in enumerate(burst):
            smooth += 0.06 * (value - smooth)
            t = i / RATE
            song.samples[i] += smooth * math.exp(-t * 7) * 1.6
        add_blip(song, 0, 0.5, 60, 34, 0.5, decay=7)
    elif name == 'abilityReady':
        song = Song(0.9)
        song.note(0, 0.5, 79, 0.2)
        song.note(0.12, 0.6, 86, 0.2)
    else:
        raise ValueError(name)
    return song


AMBIENCES = ('ambManhattan', 'ambGamma', 'ambHydra', 'ambWakanda', 'ambAsgard', 'ambLatveria')
COMBAT_CUES = ('shotTech', 'shotArrow', 'shotMagic', 'shotMelee', 'shotBlast', 'abilityReady')


def remove_dc(song):
    mean = sum(song.samples) / len(song.samples)
    for i in range(len(song.samples)): song.samples[i] -= mean
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
    for name in AMBIENCES:
        assets[name] = remove_dc(ambience(name)).save(output / f'{name}.wav')
    for name in COMBAT_CUES:
        assets[name] = remove_dc(cue(name)).save(output / f'{name}.wav')
    manifest = dict(sampleRate=RATE, channels=1, bits=16, provenance='Original procedural compositions; no third-party samples.', assets=assets)
    (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Generated {len(assets)} original WAV assets in {output}')


if __name__ == '__main__': main()
