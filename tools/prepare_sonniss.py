"""Curate the owner's five ZIPs into seven private sound atlases.

python tools/prepare_sonniss.py --source "D:/Downloads google/audios sfx para games"
Requires PyAV and NumPy for rendering. Never uploads or accepts agreements.
Only metadata, recipes and the generated Luau index belong in the public repo.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
import wave
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'assets/audio/sonniss'
RATE = 32000
# bank, cue, bundle, distinctive filename substring, maximum duration, variants
RECIPES = [
 ('ui','click',2,'UIClick_UI Button Analog',.14,2),
 ('ui','open',2,'CLOTHFlp_Action Inventory',.36,1),
 ('ui','deny',5,'UIGlitch_Designed_Glitch_Corrupted',.32,1),
 ('ui','talentHover',2,'Interface Percussion Snap',.09,1),
 ('ui','talentSnap',2,'GAMEBoard_Game Play Piece',.32,1),
 ('ui','talentCenter',2,'Woosh Sweep Slide Infographics',.45,1),
 ('ui','card',2,'PAPRHndl_Game Play Cards',.3,2),
 ('events','collect',2,'Ting Coins',.28,2),
 ('events','place',2,'ROBTMvmt_Tower Deploy',.7,1),
 ('events','upgrade',2,'DSGNStngr_Power Up Bright',1.1,1),
 ('events','levelUp',2,'Game Entry Happy Short',1.6,1),
 ('events','wave',2,'DSGNStngr_Action Deploy',.75,1),
 ('events','abilityReady',2,'Interface Accept Glassy Snap',.26,1),
 ('events','victory',4,'CRWDCheer_Small Club',2.6,1),
 ('events','defeat',2,'Interface Arp Reveal Down',1.5,1),
 ('events','breach',5,'DSGNImpt_Metal Hit Thud',.65,1),
 ('summon','reelStart',4,'SBmb_Music Box C Wind Up',.8,1),
 ('summon','reelTick',4,'SBvr_Mode Select Wheel',.075,1),
 ('summon','rewardCommon',2,'Interface Accept Glassy Snap',.32,1),
 ('summon','rewardRare',2,'UIMisc_Kalimba 3 Up',.75,1),
 ('summon','rewardEpic',2,'GAMEMisc_Magic Creation 23',1.2,1),
 ('summon','rewardLegendary',2,'DSGNStngr_Power Up Bright',1.7,1),
 ('summon','rewardMythic',2,'Impact Hit Rapid Chord Reverb',2.2,1),
 ('combat','punch',1,'FGHTImpt_4 x Punch',.28,3),
 ('combat','heavy',2,'SWSH_SWING IMPACTS Quick Heavy',.52,2),
 ('combat','metal',1,'WEAPArmr_Metal Shield Spin',.38,2),
 ('combat','organic',1,'WEAPBlnt_Spear And Stick',.38,2),
 ('combat','web',2,'WEAPWhip_WHIP Snap Crack',.24,2),
 ('combat','arrow',2,'Arrow Hit Rattle',.32,2),
 ('combat','tech',3,'ELECArc_ArcDesign15',.32,2),
 ('combat','beam',5,'UIGlitch_User interface_Glitch_High',.32,2),
 ('combat','magic',2,'magic, energy flow, astonishment',.5,2),
 ('combat','ice',2,'ICEBrk_Skill Freeze',.4,2),
 ('combat','fire',2,'FIREWhsh_Whoosh Fire',.45,2),
 ('combat','blast',2,'EXPLDsgn_Explosion Small Blast',.7,2),
 ('combat','swift',2,'METLFric_SWING SCRAPE Swift',.24,2),
 ('powers','powerBlast',2,'EffectiveTrailer_Booms_Vol2_075',1.5,1),
 ('powers','powerLightning',3,'ELECArc_ArcPowerUpDesign04',1.2,1),
 ('powers','powerFreeze',2,'ICEBrk_Skill Freeze',1.4,1),
 ('powers','powerWeb',1,'WINDDsgn_Wind, Rush, Whoosh',.9,1),
 ('powers','powerMagic',2,'magic, energy flow, astral travel',1.6,1),
 ('powers','powerFire',2,'FIREWhsh_Whoosh Fire',1.1,1),
 ('powers','powerHeal',2,'MAGAngl_Magic Light Spell',1.2,1),
 ('powers','powerTaunt',5,'CREAHmn_Violent Humanoid Creature Exhale',.7,1),
 ('boss','boss',3,'Huge-32.wav',2.2,1),
 ('boss','bossMetal',5,'DSGNTonl_Metal Scrape Low Tonal',1.8,1),
 ('boss','bossBeast',1,'ANMLRept_Large Herbivore Roar',1.6,1),
 ('boss','bossIllusion',5,'CREAEthr_Ethereal Entity Grim',1.3,1),
 ('boss','bossDown',2,'EffectiveTrailer_Booms_Vol2_011',1.4,1),
 ('world','ambLobby',1,'AMBSubn_Ambience, Forest Crickets',18,1),
 ('world','ambManhattan',2,'AMBTown_City Courtyard Calm',18,1),
 ('world','ambGamma',2,'DSGNSynth_Scifi Loop Ship Reactor',18,1),
 ('world','ambHydra',3,'WATRWave_Soft Waves Cliffs',18,1),
 ('world','ambWakanda',3,'AMBSwmp_Meadow Pipits',18,1),
 ('world','ambAsgard',3,'WINDInt_ChimneyWind05',18,1),
 ('world','ambLatveria',5,'WINDInt_Wind Strong Metal Rattle',18,1),
]


def decode(member, seconds):
    import av
    import numpy as np
    resampler = av.AudioResampler(format='fltp', layout='mono', rate=RATE)
    chunks, count = [], 0
    with av.open(member) as source:
        for frame in source.decode(audio=0):
            for converted in resampler.resample(frame):
                samples = converted.to_ndarray().ravel()
                chunks.append(samples); count += len(samples)
            if count >= seconds * RATE:
                break
    if not chunks:
        raise ValueError('Empty recording')
    return np.concatenate(chunks).astype('float64')[:round(seconds * RATE)]


def cut(samples, duration, variant=0, loop=False):
    import numpy as np
    # Find audible onsets, not silence at the start of a source recording.
    frames = len(samples) // 320
    energy = np.sqrt(np.mean(samples[:frames*320].reshape(-1,320)**2,axis=1))
    threshold = max(float(energy.max()) * .18, .0005)
    onsets = np.flatnonzero((energy > threshold) & np.r_[True, energy[:-1] <= threshold])
    distinct = []
    for value in onsets:
        if not distinct or value - distinct[-1] >= max(24,round(duration*70)):
            distinct.append(int(value))
    offset = max(0,distinct[min(variant,len(distinct)-1)] * 320 - 160) if distinct else 0
    if loop: offset = 0
    clip = samples[offset:offset+round(duration*RATE)].copy()
    if len(clip)<320: raise ValueError('Recording too short')
    # Some source files contain a single transient. Small editorial pitch
    # variations keep their repeated regions distinct without cutting off
    # the attack or requiring another recording from the library.
    pitch = (1, .965, 1.035)[variant % 3] if not loop else 1
    if pitch != 1:
        clip = np.interp(np.arange(len(clip))*pitch,np.arange(len(clip)),clip,right=0).astype(np.float32)
    clip -= clip.mean()
    if loop:
        # Equal-power crossfade makes the end join the beginning of the loop.
        overlap = min(round(.45*RATE),len(clip)//8)
        ramp=np.linspace(0,1,overlap)
        clip[:overlap]=clip[-overlap:]*(1-ramp)+clip[:overlap]*ramp
        clip=clip[:-overlap]
    else:
        fade=min(round(.006*RATE),len(clip)//4)
        clip[:fade]*=np.linspace(0,1,fade)
        tail=min(round(.04*RATE),len(clip)//4)
        clip[-tail:]*=np.linspace(1,0,tail)
    peak=max(float(np.max(np.abs(clip))),1e-8)
    rms=max(float(np.sqrt(np.mean(clip**2))),1e-8)
    # Limit both loudness and peaks; quiet textures do not become harsh blasts.
    clip *= min(.72/peak,(.10 if loop else .16)/rms,8)
    return clip, dict(sourceStart=round(offset/RATE,6),sourceSeconds=round(len(clip)/RATE,6),pitch=pitch)


def pcm_write(path, samples):
    import numpy as np
    with wave.open(str(path),'wb') as output:
        output.setparams((1,2,RATE,0,'NONE','not compressed'))
        output.writeframes(np.round(np.clip(samples,-1,1)*32767).astype('<i2').tobytes())


def main():
    import numpy as np
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source',type=Path,required=True)
    args=parser.parse_args()
    DEST.mkdir(parents=True,exist_ok=True)
    rendered=DEST/'rendered';rendered.mkdir(exist_ok=True)
    audition=DEST/'audition';audition.mkdir(exist_ok=True)
    previous_path=DEST/'manifest.json'
    previous=json.loads(previous_path.read_text(encoding='utf-8')).get('assets',{}) if previous_path.exists() else {}
    banks, cues, origins, inventory = {}, {}, {}, []
    archives={}
    try:
        for index in range(1,6):
            path=args.source/f'Sonniss.com-GDC2026-GameAudioBundle{index}of5.zip'
            archives[index]=zipfile.ZipFile(path)
            inventory.append(dict(bundle=path.name,recordings=sum(n.lower().endswith('.wav') for n in archives[index].namelist()),
                licenseSha256=hashlib.sha256(archives[index].read('License - GDC Game Audio.pdf')).hexdigest()))
        for bank,cue,bundle,needle,duration,variants in RECIPES:
            z=archives[bundle]
            matches=[n for n in z.namelist() if needle.lower() in n.lower() and n.lower().endswith('.wav')]
            if len(matches)!=1: raise ValueError(f'{cue}: expected unique source: {matches}')
            member=matches[0]
            # Decode only the useful opening; never unpack the 8GB library.
            with z.open(member) as handle:
                samples=decode(handle,max(8,duration+1))
            origin=f'{bundle}:{member}'
            origins[origin]=dict(bundle=bundle,file=member,crc32=z.getinfo(member).CRC)
            variants_data=[]
            for variant in range(variants):
                clip, edit=cut(samples,duration,variant,loop=bank=='world')
                chunks=banks.setdefault(bank,[np.zeros(round(.15*RATE))])
                start=sum(len(chunk) for chunk in chunks)/RATE
                stop=start+len(clip)/RATE
                chunks.extend((clip,np.zeros(round(.15*RATE))))
                variants_data.append(dict(start=round(start,6),stop=round(stop,6),origin=origin,edit=edit))
                pcm_write(audition/f'{cue}-{variant+1}.wav',clip)
            cues[cue]=dict(bank=bank,loop=bank=='world',variants=variants_data)
        assets={}
        for name,chunks in banks.items():
            data=np.concatenate(chunks);path=rendered/f'sfx_{name}.wav';pcm_write(path,data)
            assert path.stat().st_size<20_000_000 and len(data)/RATE<420
            digest=hashlib.sha256(path.read_bytes()).hexdigest()
            uploaded=previous.get(name,{})
            # An existing upload is reusable only for byte-identical audio.
            asset_id=uploaded.get('assetId',0) if uploaded.get('sha256')==digest else 0
            assets[name]=dict(file=path.name,seconds=len(data)/RATE,bytes=path.stat().st_size,
                configKey='sfx'+name.title(),assetId=asset_id,sha256=digest)
        manifest=dict(version=1,rate=RATE,licenseUrl='https://sonniss.com/gdc-bundle-license/',
            reviewed='2026-10-09',inventory=inventory,sources=origins,assets=assets,cues=cues)
        (DEST/'manifest.json').write_text(json.dumps(manifest,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')
        lines=['-- Generated by tools/prepare_sonniss.py. Licensed PCM stays private.',
               '-- IDs live only in Config.Audio; these are timings, not game rules.', 'return {']
        for cue,entry in cues.items():
            segments=', '.join('{'+str(v['start'])+', '+str(v['stop'])+'}' for v in entry['variants'])
            lines.append(f'\t{cue} = {{asset = "sfx{entry["bank"].title()}", loop = {str(entry["loop"]).lower()}, regions = {{{segments}}}}},')
        lines.append('}')
        (ROOT/'src/client/SoundBank.luau').write_text('\n'.join(lines)+'\n',encoding='utf-8')
        print(f'Prepared {len(cues)} cues, {sum(len(c["variants"]) for c in cues.values())} regions, {len(origins)} sources, seven private uploads.',flush=True)
        print('Sonniss recordings were not uploaded, published or added to git.')
    finally:
        for archive in archives.values(): archive.close()


if __name__=='__main__': main()
