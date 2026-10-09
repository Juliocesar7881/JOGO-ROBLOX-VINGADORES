"""Prepare the owner's reel reference and five original rarity endings.

Run: python tools/generate_summon_audio.py
The reference MP3 is supplied by the owner; it is not our original synthesis.
Decoding that file requires PyAV and NumPy. Nothing is uploaded by this tool.
"""
from array import array
import hashlib
import json
from pathlib import Path
import sys
import wave

from generate_audio import ROOT, RATE, Song, remove_dc
from generate_refined_audio import acoustic, impact, resonator, sweep

DIRECTORY = ROOT / 'assets' / 'audio' / 'summon'
REFERENCE = DIRECTORY / 'reference.mp3'
RARITIES = ('Common', 'Rare', 'Epic', 'Legendary', 'Mythic')


def excerpt(decoded, name, start, end):
    import numpy as np
    samples = decoded[round(start * RATE):round(end * RATE)].astype(float).copy()
    samples -= samples.mean()
    fade = round(.003 * RATE)
    samples[:fade] *= np.linspace(0, 1, fade)
    samples[-fade:] *= np.linspace(1, 0, fade)
    samples *= .68 / max(abs(samples))
    path = DIRECTORY / (name + '.wav')
    pcm = array('h', (round(v * 32767) for v in samples))
    if sys.byteorder != 'little':
        pcm.byteswap()
    with wave.open(str(path), 'wb') as output:
        output.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        output.writeframes(pcm.tobytes())
    return dict(file=path.name, seconds=len(samples) / RATE, assetId=0,
                origin='owner-provided reference excerpt', sourceSeconds=[start, end],
                sha256=hashlib.sha256(path.read_bytes()).hexdigest())


def ending(tier):
    song = Song((.5, .9, 1.25, 1.65, 2.15)[tier])
    if tier == 0:
        # Two warm confirmations, no fanfare for an everyday reward.
        for at, note in ((0, 72), (.085, 79)):
            acoustic(song, at, note, .28, .22, 'pluck')
    elif tier == 1:
        for at, note in ((0, 76), (.15, 83)):
            resonator(song, at, .64, 440 * 2 ** ((note - 69) / 12), .19,
                      ((1, 1), (2, .25), (3.9, .07)), decay=7)
    elif tier == 2:
        sweep(song, 0, .25, 320, 1450, .12, seed=16)
        for at, note in ((.02, 72), (.16, 79), (.32, 84)):
            acoustic(song, at, note, .65, .2, 'pluck')
        song.note(.32, .75, 88, .065)
    elif tier == 3:
        impact(song, 0, .25, seed=29, seconds=.18, tone=110)
        for at, note in ((0, 60), (.16, 67), (.32, 72), (.48, 79)):
            acoustic(song, at, note, .85, .17, 'brass')
        for note in (72, 76, 79):
            song.note(.48, 1.05, note, .045, 'pad')
    else:
        impact(song, 0, .3, seed=31, seconds=.24, tone=65)
        sweep(song, .02, .44, 180, 2000, .11, seed=32)
        for at, note in ((.02, 48), (.16, 60), (.30, 67), (.46, 72), (.64, 84)):
            acoustic(song, at, note, 1.15, .14, 'brass')
        for note in (72, 76, 79, 84):
            song.note(.64, 1.3, note, .042, 'pad')
        song.note(.8, .9, 91, .055)
    remove_dc(song)
    return song


def main():
    import av
    import numpy as np
    DIRECTORY.mkdir(parents=True, exist_ok=True)
    converter = av.AudioResampler(format='fltp', layout='mono', rate=RATE)
    chunks = []
    with av.open(str(REFERENCE)) as source:
        for frame in source.decode(audio=0):
            chunks.extend(f.to_ndarray().ravel() for f in converter.resample(frame))
        chunks.extend(f.to_ndarray().ravel() for f in converter.resample(None))
    decoded = np.concatenate(chunks)
    assets = {
        'reelStart': excerpt(decoded, 'reelStart', .13, 1.5),
        'reelTick': excerpt(decoded, 'reelTick', 2.16, 2.26),
    }
    for tier, rarity in enumerate(RARITIES):
        name = 'reward' + rarity
        assets[name] = ending(tier).save(DIRECTORY / (name + '.wav'))
        assets[name]['origin'] = 'original synthesis'
    manifest = dict(rate=RATE, reference=dict(file=REFERENCE.name,
                    origin='MP3 supplied by owner, Nexiz case-opening reference',
                    sha256=hashlib.sha256(REFERENCE.read_bytes()).hexdigest()), assets=assets)
    (DIRECTORY / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    print('Prepared seven WAVs; no Roblox uploads or asset IDs created.')


if __name__ == '__main__':
    main()
