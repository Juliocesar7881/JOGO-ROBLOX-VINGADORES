"""Original material sounds and quieter music, prepared for owner upload.

Keeps the currently uploaded pack untouched. No external samples or melodies.
Run: python tools/generate_refined_audio.py
"""
from array import array
import json
import math
import random

from generate_audio import ROOT, RATE, TAU, Song, add_wind, remove_dc


def resonator(song, start, seconds, frequency, gain, partials, decay=10):
    """Damped resonances: inharmonic metal, wood, or pitched acoustic voices."""
    for i in range(round(seconds * RATE)):
        t = i / RATE
        attack = min(1, t / 0.003)
        release = min(1, (seconds - t) / 0.035)
        value = sum(weight * math.sin(TAU * frequency * ratio * t)
                    * math.exp(-t * decay * (1 + index * 0.3))
                    for index, (ratio, weight) in enumerate(partials))
        at = round(start * RATE) + i
        if song.loop:
            at %= len(song.samples)
        if at < len(song.samples):
            song.samples[at] += value * attack * release * gain


def sweep(song, start, seconds, low, high, gain, seed=0, texture=0.15):
    rng = random.Random(seed)
    phase, smooth = 0.0, 0.0
    for i in range(round(seconds * RATE)):
        t = i / RATE
        phase += TAU * (low + (high - low) * t / seconds) / RATE
        smooth += 0.16 * (rng.uniform(-1, 1) - smooth)
        envelope = math.sin(math.pi * t / seconds) ** 1.4
        at = round(start * RATE) + i
        if song.loop:
            at %= len(song.samples)
        if at < len(song.samples):
            song.samples[at] += (math.sin(phase) * (1 - texture) + smooth * texture) * envelope * gain


def impact(song, start, gain, seed, seconds=0.12, tone=115):
    rng = random.Random(seed)
    smooth = 0.0
    for i in range(round(seconds * RATE)):
        t = i / RATE
        smooth += 0.18 * (rng.uniform(-1, 1) - smooth)
        at = round(start * RATE) + i
        if song.loop:
            at %= len(song.samples)
        if at < len(song.samples):
            value = 0.6 * smooth + 0.4 * math.sin(TAU * tone * t)
            song.samples[at] += value * min(1, t / 0.002) * math.exp(-t * 38) * gain


def acoustic(song, start, midi, seconds, gain, voice='pluck'):
    f = 440 * 2 ** ((midi - 69) / 12)
    if voice == 'pluck':
        resonator(song, start, seconds, f, gain, ((1, 1), (2, .3), (3, .12), (4, .04)), 2.6)
    elif voice == 'wood':
        resonator(song, start, seconds, f, gain, ((1, 1), (2.76, .35), (5.4, .06)), 5.5)
    else:
        # Soft sustained strings; no bright repeated bell melody.
        for i in range(round(seconds * RATE)):
            t = i / RATE
            envelope = min(1, t / .3) * min(1, (seconds - t) / .5)
            value = sum(math.sin(TAU * f * (k + 1) * t) / (k + 1) ** 2 for k in range(4))
            at = (round(start * RATE) + i) % len(song.samples)
            song.samples[at] += value * envelope * gain


def music(battle=False):
    beat = 60 / (104 if battle else 76)
    song = Song(64 * beat, True)
    chords = [(45, 52, 59, 60), (41, 48, 55, 57), (48, 55, 59, 64), (43, 50, 57, 60)]
    motif = (72, 76, 74, 67, 69, 72, 71, 67)
    for bar in range(16):
        chord = chords[(bar // 2) % 4]
        at = bar * 4 * beat
        for note in chord:
            acoustic(song, at, note, 4.3 * beat, .013, 'strings')
        acoustic(song, at, chord[0] - (12 if battle else 0), 2 * beat, .075)
        for step in range(4 if battle else 2):
            acoustic(song, at + (step + .5) * beat, chord[1 + step % 3], beat * 1.8, .055)
        if battle:
            for step in (0, 2, 3):
                impact(song, at + step * beat, .1 if step == 0 else .055, 500 + bar * 4 + step, tone=65)
            if bar % 2:
                acoustic(song, at + 2.5 * beat, chord[2] + 12, .7, .045, 'wood')
        elif bar % 4 in (0, 2):
            for step in range(2):
                acoustic(song, at + (step * 1.5 + 1) * beat, motif[(bar + step) % 8], 1.6, .065, 'wood')
    if not battle:
        add_wind(song, 831, .025, alpha=.005, swells=(2, 5))
    return song


def cue(name):
    song = Song(.65 if name in ('open', 'shotMagic', 'upgrade') else .4)
    if name == 'click':
        impact(song, 0, .7, 201, .055, 380)
    elif name == 'collect':
        resonator(song, 0, .2, 1380, .16, ((1, 1), (1.43, .34), (2.73, .14)), 24)
    elif name == 'open':
        sweep(song, 0, .16, 280, 510, .12, 212, .8)
        impact(song, .12, .25, 213, .07, 240)
    elif name == 'shotTech':
        sweep(song, 0, .13, 680, 120, .19, 221, .18)
        impact(song, .1, .28, 222)
    elif name == 'shotArrow':
        sweep(song, 0, .14, 900, 410, .15, 231, .92)
        impact(song, .1, .22, 232, .08, 180)
    elif name == 'shotMagic':
        sweep(song, 0, .33, 240, 620, .11, 241, .32)
        resonator(song, .06, .4, 330, .08, ((1, 1), (1.5, .35), (3.01, .1)), 6)
    elif name == 'shotMelee':
        impact(song, 0, .8, 251, .16, 92)
        resonator(song, .015, .25, 140, .06, ((1, 1), (2.76, .22)), 20)
    elif name == 'shotBlast':
        impact(song, 0, .75, 261, .2, 52)
        sweep(song, .02, .24, 160, 40, .1, 262, .75)
    elif name == 'place':
        impact(song, 0, .7, 271, .12, 95)
        impact(song, .07, .2, 272, .08, 340)
    elif name == 'upgrade':
        sweep(song, 0, .3, 110, 370, .11, 281, .2)
        resonator(song, .28, .2, 560, .09, ((1, 1), (1.5, .3)), 18)
    else:
        raise ValueError(name)
    return song


def main():
    output = ROOT / 'assets/audio/refined'
    output.mkdir(parents=True, exist_ok=True)
    assets = {}
    for name, song in [('lobby', music()), ('battle', music(True))]:
        assets[name] = remove_dc(song).save(output / f'{name}.wav')
    for name in ('click', 'collect', 'open', 'place', 'upgrade', 'shotTech', 'shotArrow', 'shotMagic', 'shotMelee', 'shotBlast'):
        assets[name] = remove_dc(cue(name)).save(output / f'{name}.wav')
    manifest = dict(sampleRate=RATE, channels=1, bits=16,
                    status='Prepared locally; not uploaded or active Roblox asset IDs.',
                    provenance='Original deterministic synthesis; no external recordings, samples or melodies.',
                    assets=assets)
    (output / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'Generated {len(assets)} refined audio sources in {output}; owner upload pending.')


if __name__ == '__main__':
    main()
