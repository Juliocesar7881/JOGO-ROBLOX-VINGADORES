"""Exercise independent mute, music transitions and stale fade cancellation."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'src/client/Audio.luau').read_text(encoding='utf-8')
bank_source = (ROOT / 'src/client/SoundBank.luau').read_text(encoding='utf-8')
harness = r'''
local delayed, sounds, objects = {}, {}, {}
local Config = {Audio={lobby=10,battle=11,collect=12,victory=13,wave=14,ambGamma=21,ambHydra=22,shotTech=23,shotBlast=24}}
local Bank=(function()
__BANK__
end)()
local module={WaitForChild=function(self,name) return {Name=name,WaitForChild=self.WaitForChild} end}
local script={Parent=module}
local clock=10
local os={clock=function() return clock end}
local task={delay=function(_,fn) table.insert(delayed,fn) end}
local TweenInfo={new=function() return {} end}
local NumberRange={new=function(a,b) return {Min=a,Max=b or a} end}
local effectsPlayed=0
local soundService={PlayLocalSound=function(_,sound) assert(sound.SoundId); effectsPlayed+=1 end}
local tweenService={Create=function(_,sound,_,goal)
 local tween={Cancel=function(self) self.cancelled=true end,Play=function() sound.Volume=goal.Volume end}
 return tween
end}
local game={GetService=function(_,name)
 return name=='SoundService' and soundService or name=='TweenService' and tweenService or module
end}
local require=function(dependency) return dependency.Name=='SoundBank' and Bank or Config end
local Instance={new=function(kind)
 local value={IsPlaying=false,Play=function(self) self.IsPlaying=true end,Stop=function(self) self.IsPlaying=false end}
 value.FindFirstChild=function(self,name)
  for _,child in ipairs(objects) do if child.Parent==self and child.Name==name then return child end end
  return nil
 end
 table.insert(objects,value)
 if kind=='Sound' then table.insert(sounds,value) end
 return value
end}
local Audio=(function()
__AUDIO__
end)()
local settings={music=true,effects=true}
local state={phase='Lobby',profile={settings=settings}}
local audio=Audio.new(function() return state end)
audio:Update(state)
assert(audio.sounds.lobby.IsPlaying,'Lobby music starts')
state.phase='Wave';state.wave=1;audio:Update(state)
assert(audio.sounds.battle.IsPlaying,'Wave starts battle music')
state.phase='Lobby';audio:Update(state)
for _,fn in ipairs(delayed) do fn() end
assert(audio.sounds.lobby.IsPlaying and not audio.sounds.battle.IsPlaying,'Stale fade cannot stop the current track')
settings.music=false;audio:Update(state)
for _,fn in ipairs(delayed) do fn() end
assert(not audio.sounds.lobby.IsPlaying,'Music setting stops music')
local count=effectsPlayed;audio:Cue('collect');assert(effectsPlayed==count+1,'Music mute preserves enabled effects')
settings.effects=false;clock+=1;audio:Cue('collect');assert(effectsPlayed==count+1,'Effects mute suppresses cues')
settings.effects=nil;clock+=1;audio:Cue('collect');assert(effectsPlayed==count+1,'Legacy combined mute is respected')
settings.effects=true;state.phase='Results';state.results={victory=true};audio:Update(state)
count=effectsPlayed;audio:Update(state);assert(count==effectsPlayed,'Result cue does not repeat on state refresh')
assert(audio.sounds.collect.SoundId=='rbxassetid://12','Configured assets take precedence')
-- Map ambience: plays under the battle music, follows the map, stops after.
state.phase='Wave';state.results=nil;state.match={mapId='gamma'};audio:Update(state)
assert(audio.ambient=='ambGamma' and audio.sounds.ambGamma.IsPlaying,'A match plays its map ambience')
state.match={mapId='hydra'};audio:Update(state)
assert(audio.ambient=='ambHydra','A different map switches the ambience')
state.phase='Lobby';audio:Update(state)
assert(audio.ambient=='ambLobby','Returning restores the lobby ambience instead of keeping a battle map loop')
-- Each map's own battle track: played when uploaded, the shared one otherwise,
-- and the shared one again when the map's own will not load.
local musicBefore=settings.music
settings.music=true
Config.Audio.battleGamma=31
state.phase='Wave';state.match={mapId='gamma'};audio:Update(state)
assert(audio.track=='battleGamma' and audio.sounds.battleGamma.IsPlaying and audio.sounds.battleGamma.Looped,'A map with its own track plays it in battle')
assert(audio.sounds.battleGamma.SoundId=='rbxassetid://31','The map track uses its configured upload')
state.match={mapId='hydra'};audio:Update(state)
assert(audio.track=='battle' and audio.sounds.battle.IsPlaying,'A map without its own upload plays the shared battle track')
state.match={mapId='gamma'};delayed={};audio:Update(state)
audio.sounds.battleGamma.IsLoaded=false
for _,fn in ipairs(table.clone(delayed)) do fn() end
assert(audio.track=='battle' and audio.sounds.battle.IsPlaying,'A map track that will not load falls back to the shared battle track')
assert(audio:BattleTrack('gamma')=='battle','A map track that failed to load is not tried again in this session')
Config.Audio.battleGamma=nil
state.phase='Lobby';state.match=nil;audio:Update(state)
settings.music=musicBefore
-- Weapon cues: a hard budget per 300 ms, per-family spacing and distance.
local plays=0
local originalNew=Instance.new
Instance.new=function(kind)
 local value=originalNew(kind)
 if kind=='Sound' then value.Play=function(self) plays+=1 end end
 return value
end
clock+=5
assert(not audio:Shot('shotTech',200),'A shot beyond earshot is silent')
local heard=0
for index=1,10 do clock+=0.01; if audio:Shot(index%2==0 and 'shotTech' or 'shotBlast',10) then heard+=1 end end
assert(heard==2,'Repeated families are spaced by 120 ms, got '..heard)
clock+=1;heard=0
for index=1,6 do clock+=0.055; if audio:Shot(index%2==0 and 'shotTech' or 'shotBlast',10) then heard+=1 end end
assert(heard==3,'No more than three shots play in a 300 ms window, got '..heard)
clock+=1
assert(audio:Shot('shotTech',80),'A far shot within earshot still plays')
local farVolume=audio.voices.shotTech[audio.voiceIndex.shotTech].Volume
clock+=1
assert(audio:Shot('shotTech',5),'A near shot plays')
local nearVolume=audio.voices.shotTech[audio.voiceIndex.shotTech].Volume
assert(nearVolume>farVolume,'Nearer shots are louder')
settings.effects=false;clock+=1
assert(not audio:Shot('shotTech',5),'The effects switch silences weapons too')
settings.effects=true
-- Timbre is distinct per hero and never leaks to the next reused voice.
Config.Audio.shotMelee=25
clock+=1;assert(audio:Shot('shotMelee',5,'hulk'))
local heavy=audio.voices.shotMelee[audio.voiceIndex.shotMelee]
local heavyPitch=heavy.PlaybackSpeed
assert(heavy:FindFirstChild('WeaponTone').HighGain<0 and heavy:FindFirstChild('WeaponTone').LowGain>0,'Heavy fists have a darker, bassier timbre')
clock+=1;assert(audio:Shot('shotMelee',5,'beast'))
assert(audio.voices.shotMelee[audio.voiceIndex.shotMelee].PlaybackSpeed>heavyPitch,'An agile fighter has a higher register than the giant')
for i=1,5 do clock+=1;assert(audio:Shot('shotMelee',5)) end
local neutral=audio.voices.shotMelee[audio.voiceIndex.shotMelee]
assert(neutral:FindFirstChild('WeaponTone').HighGain==0 and neutral:FindFirstChild('WeaponTone').LowGain==0,'Pooled equalization resets for an ordinary fighter')
assert(#audio.voices.shotMelee==3,'Hero timbres do not grow the voice pool')
-- A built-in jingle: the first note now, the rest on their beat, once per cue.
Config.BuiltinCues={levelUp={path='rbxasset://sounds/volume_slider.ogg',speed=1.5,notes={{at=0,speed=1.5},{at=0.1,speed=1.89},{at=0.2,speed=2.25}}}}
delayed={}
clock+=1
count=effectsPlayed
audio:Cue('levelUp')
assert(effectsPlayed==count+1 and #delayed==2,'A jingle plays its first note and schedules the others')
for _,fn in ipairs(delayed) do fn() end
assert(effectsPlayed==count+3,'Every note of the jingle plays')
Config.Audio.levelUp=77;clock+=1;count=effectsPlayed;delayed={}
audio:Cue('levelUp')
assert(effectsPlayed==count+1 and #delayed==0,'An uploaded sound replaces the jingle')
-- Research board: quiet own cues, a bounded pool and both mute switches.
Config.Audio.click=78;Config.Audio.place=79;Config.Audio.open=80
settings.interface=true;settings.effects=true;clock+=1;count=effectsPlayed
audio:Talent('hover');audio:Talent('hover')
assert(effectsPlayed==count+1,'Repeated hover notes are rate limited')
for i=1,20 do clock+=.2;audio:Talent('hover') end
assert(#audio.voices['talent:hover']==3,'Hover audio reuses three voices')
local hover=audio.voices['talent:hover'][audio.voiceIndex['talent:hover']]
assert(hover.Volume<=.06 and hover.PlaybackSpeed>1,'Research hover stays quiet and has its own pitch')
settings.interface=false;clock+=1;count=effectsPlayed
audio:Talent('snap');audio:Talent('center')
assert(effectsPlayed==count,'Interface mute silences all research sounds')
settings.interface=true;settings.effects=false;clock+=1;audio:Talent('snap')
assert(effectsPlayed==count,'Effects mute also silences research sounds')
settings.effects=true;clock+=1;audio:Talent('snap');audio:Talent('center')
assert(effectsPlayed==count+2,'Research snap and center have independent cues')
-- Quiet material palettes: pickup bursts do not turn into a repeated melody;
-- delayed layers obey mute and placements cannot double from reply + FX.
Config.Audio.shotMelee=81;Config.Audio.shotArrow=82
clock+=1;count=effectsPlayed;delayed={}
audio:Cue('collect',.01)
for i=1,12 do clock+=.01;audio:Cue('collect',.01) end
assert(effectsPlayed==count+1,'A burst of pickups produces one quiet tick')
local pickup=audio.voices.click[audio.voiceIndex.click]
assert(pickup.SoundId=='rbxassetid://78' and pickup.Volume<=.08,'Pickup uses a short owned click, not the old arpeggio')
clock+=1;count=effectsPlayed;delayed={}
audio:Cue('place',.01);audio:Cue('place',.01)
assert(effectsPlayed==count+1 and #delayed==1,'Reply and FX cannot double a placement sound')
settings.effects=false
for _,fn in ipairs(delayed) do fn() end
assert(effectsPlayed==count+1,'Mute cancels a scheduled placement layer')
settings.interface=true;settings.effects=true;clock+=1;delayed={};audio:Cue('upgrade')
local upgrade=audio.voices.shotTech[audio.voiceIndex.shotTech]
assert(upgrade.SoundId=='rbxassetid://23' and upgrade.PlaybackSpeed<1,'Upgrade has a mechanical charge timbre')
clock+=1;count=effectsPlayed
assert(audio:Ability('shotMelee',5),'Melee leader power plays')
assert(not audio:Ability('shotTech',5),'Repeated power messages are rate limited')
clock+=1;assert(audio:Ability('shotTech',5),'Tech leader has a distinct power source')
assert(audio.voices.shotMelee[audio.voiceIndex.shotMelee].SoundId~=audio.voices.shotTech[audio.voiceIndex.shotTech].SoundId,'Power sounds follow the leader family')
clock+=1;assert(not audio:Ability('shotTech',260),'A teammate power far beyond earshot is silent')
clock+=1;assert(audio:Ability('shotTech',400,nil,nil,true),'The commander hears their own power however far it lands')
settings.effects=false;clock+=1;assert(not audio:Ability('shotMelee',5),'Power honours effects mute')
-- Owner-uploaded material cues replace the compatibility remix, preserving
-- all rate limits and settings. No fictitious production IDs are introduced.
Config.DirectAudioCues={collect=true,place=true,upgrade=true}
local refined=Audio.new(function() return state end)
settings.effects=true;clock+=1;delayed={};count=effectsPlayed
refined:Cue('place')
assert(effectsPlayed==count+1 and #delayed==0,'Dedicated placement replaces both remixed layers')
assert(refined.voices.place[1].SoundId=='rbxassetid://79','Dedicated recording uses its configured asset')
refined:Cue('place',0);assert(effectsPlayed==count+1,'Dedicated cue keeps anti-repeat spacing')
settings.effects=false;clock+=1;refined:Cue('place')
assert(effectsPlayed==count+1,'Dedicated cue keeps effects mute')
-- Moderated battle uploads use an action arrangement, never the lobby song.
Instance.new=originalNew
Config.Audio.ambLatveria,Config.Audio.shotMelee,Config.Audio.shotArrow=81,82,83
settings.music,settings.effects=true,false
state.phase,state.wave='Wave',9
local action=Audio.new(function() return state end)
delayed={}
action:Update(state)
action.sounds.battle.IsLoaded=false
for _,fn in ipairs(table.clone(delayed)) do fn() end
assert(action.track=='action' and action.actionPlaying,'Unloaded battle starts the action arrangement')
assert(not action.sounds.lobby or not action.sounds.lobby.IsPlaying,'It never plays the peaceful lobby as battle fallback')
assert(action.actionVoices.bed.SoundId=='rbxassetid://81' and action.actionVoices.bed.Looped,'Action uses the owned minor choir')
action:Step()
assert(action.actionVoices.kick.IsPlaying,'Action drums play with Music enabled even when Effects is muted')
clock+=.625;action:Step()
assert(action.actionVoices.snare.IsPlaying,'Backbeat uses a different owned percussion stem')
local voiceCount=#sounds
for index=1,100 do clock+=.3125;action:Step() end
assert(#sounds==voiceCount,'Long playback reuses its three voices')
settings.music=false;action:Update(state)
for _,sound in pairs(action.actionVoices) do assert(not sound.IsPlaying,'Music mute stops every action stem') end
settings.music=true;action:Update(state)
assert(action.actionPlaying,'Music can resume the action arrangement')
state.phase='Results';state.results={victory=false};action:Update(state)
assert(not action.actionPlaying,'Results stop the percussion without delayed beats')
state.phase='Lobby';action:Update(state)
assert(action.track=='lobby' and action.sounds.lobby.PlaybackSpeed==1,'Lobby keeps the original track and speed')
print('PASS audio: transitions, mute, legacy settings, result cues, map ambience, weapon voice budget and jingles')
-- Reel ticks are mechanical, independent of pickup throttling, with one
-- final signature per rarity. Reusing voices never leaves old regions.
Config.Audio.shotMagic=84
settings.effects,settings.interface=true,true
local reel=Audio.new(function() return state end)
local summonPlays=0
Instance.new=function(kind)
 local value=originalNew(kind)
 if kind=='Sound' then value.Play=function(self) self.IsPlaying=true;summonPlays+=1 end end
 return value
end
clock+=1;reel:Summon('start');reel:Summon('tick')
local tick=reel.summonVoices.reelTick
assert(tick.SoundId=='rbxassetid://78' and tick.PlaybackRegion.Max==.065 and tick.PlaybackRegionsEnabled,'Fallback tick is a short owned transient')
local before=summonPlays
for i=1,10 do clock+=.001;reel:Summon('tick') end
assert(summonPlays==before,'A fast frame cannot queue a burst of ticks')
clock+=.05;reel:Summon('tick');assert(summonPlays==before+1,'The next crossed tile can tick independently of pickups')
local patterns={}
for _,rarity in ipairs({'common','rare','legendary'}) do
 delayed={};reel:Summon('start');reel:Summon('reward',rarity)
 local immediate=summonPlays
 for _,fn in ipairs(delayed) do fn() end
 local signature=tostring(summonPlays-immediate)..':'
 for i=1,6 do
  local voice=reel.summonVoices['reward_'..i]
  if voice and voice.IsPlaying then signature..=voice.SoundId..':'..voice.PlaybackSpeed..':'..voice.Volume..';' end
 end
 assert(not patterns[signature],'Every rarity has a distinct ending: '..rarity)
 patterns[signature]=true
end
local voices=0;for _ in pairs(reel.summonVoices) do voices+=1 end
assert(voices<=8,'The whole summon uses at most eight reusable voices')
delayed={};reel:Summon('reward','legendary');reel:Summon('cancel');before=summonPlays
for _,fn in ipairs(delayed) do fn() end
assert(summonPlays==before,'Leaving a scene cancels pending reward layers')
delayed={};reel:Summon('reward','legendary');settings.interface=false;before=summonPlays
for _,fn in ipairs(delayed) do fn() end
reel:Summon('tick');reel:Summon('reward','common')
assert(summonPlays==before,'Interface mute also cancels delayed summon audio')
settings.interface=true;settings.effects=false;reel:Summon('start');reel:Summon('reward','rare')
assert(summonPlays==before,'Effects mute applies to the reel')
settings.effects=true;Config.Audio.reelTick=85;clock+=1;reel:Summon('tick')
assert(tick.SoundId=='rbxassetid://85' and not tick.PlaybackRegionsEnabled and tick.PlaybackSpeed==1,'The reference tick replaces the fallback without truncation or altered pitch')
Config.Audio.rewardLegendary=86;delayed={};before=summonPlays;reel:Summon('reward','legendary')
assert(summonPlays==before+1 and #delayed==0 and reel.summonVoices.reward.SoundId=='rbxassetid://86','A dedicated ending replaces all layers with one sound')
print('PASS summon audio: independent ticks, three rarity signatures, voice limits, mute, cancellation and upload replacement')
-- Private atlases: actual region selection, fallback while downloading,
-- family-specific weapons/powers, independent settings and bounded reuse.
for index,key in ipairs({'sfxUi','sfxEvents','sfxSummon','sfxCombat','sfxPowers','sfxBoss','sfxWorld'}) do Config.Audio[key]=900+index end
settings.effects,settings.interface,settings.music=true,true,true
local bank=Audio.new(function() return state end)
clock+=2;bank:Cue('click')
local click=bank.bankPools.ui[1]
assert(click.SoundId=='rbxassetid://901' and click.PlaybackRegionsEnabled,'Configured private atlas replaces the old click')
assert(click.PlaybackRegion.Min==Bank.click.regions[1][1] and click.TimePosition==click.PlaybackRegion.Min,'Playback starts at the exact cue, not the start of the atlas')
clock+=1;bank:Cue('click')
assert(bank.bankPools.ui[2].PlaybackRegion.Min==Bank.click.regions[2][1],'Repeated clicks rotate source variations')
for i=1,80 do clock+=1;bank:Cue('click') end
assert(#bank.bankPools.ui==3,'80 interface actions still use only three Sound voices')
bank.sounds.sfxCombat.IsLoaded=false
clock+=1;assert(bank:Shot('shotTech',5,'ironman'))
assert(bank.voices.shotTech[1].SoundId=='rbxassetid://23','Loading atlases keep working fallback shots')
bank.sounds.sfxCombat.IsLoaded=true
local starts={}
for _,entry in ipairs({{'hulk','shotMelee'},{'spiderman','shotArrow'},{'iceman','shotMagic'},{'torch','shotTech'},{'rocket','shotBlast'}}) do
 clock+=1;assert(bank:Shot(entry[2],5,entry[1]))
 local sound=bank.bankPools.combat[bank.bankIndex.combat]
 local profile=Audio.WeaponProfile(entry[1],entry[2])
 assert(sound.SoundId=='rbxassetid://904' and sound.PlaybackRegion.Min==Bank[profile].regions[1][1],'Weapons select the correct material: '..entry[1])
 assert(not starts[sound.PlaybackRegion.Min],'Fists, webs, ice, fire and rockets have distinct recordings')
 starts[sound.PlaybackRegion.Min]=true
end
for i=1,80 do clock+=.01;bank:Shot('shotMelee',5,'hulk') end
assert(#bank.bankPools.combat<=6,'Dense combat cannot allocate unbounded bank voices')
assert(not bank:Shot('shotMelee',200,'hulk'),'Atlas shots still obey earshot')
assert(Audio.PowerProfile('spiderman','slow','shotArrow')=='powerWeb','A slowing web uses web audio rather than ice')
assert(Audio.PowerProfile('wanda','stun','shotMagic')=='powerMagic','Magical control does not inherit an electric stun')
assert(Audio.PowerProfile('ghostrider','burn','shotMagic')=='powerFire','Persistent fire has a fire signature')
assert(Audio.PowerProfile('falcon','rally','shotArrow')=='powerHeal','Support commands have a supportive cue')
clock+=1;assert(bank:Ability('shotTech',5,'freeze'))
assert(bank.bankPools.powers[1].PlaybackRegion.Min==Bank.powerFreeze.regions[1][1],'Freeze uses the ice power, not the ordinary weapon')
clock+=1;assert(bank:Ability('shotTech',5,'lightning'))
assert(bank.bankPools.powers[2].PlaybackRegion.Min==Bank.powerLightning.regions[1][1],'Lightning has its own power cue')
clock+=1;assert(bank:Ability('shotArrow',5,'slow','spiderman'))
assert(bank.bankPools.powers[3].PlaybackRegion.Min==Bank.powerWeb.regions[1][1],'The web profile reaches real playback selection')
for _,entry in ipairs({{'doom','bossMetal'},{'lizard','bossBeast'},{'loki','bossIllusion'}}) do
 clock+=2;bank:BossProfile(entry[1]);bank:Cue('boss')
 assert(bank.bankPools.boss[bank.bankIndex.boss].PlaybackRegion.Min==Bank[entry[2]].regions[1][1],'Boss arrivals distinguish armor, beasts and illusion')
end
clock+=1;bank:Cue('deny');local denied=bank.bankIndex.ui;bank:Cue('deny')
assert(bank.bankIndex.ui==denied,'Repeated rejected actions cannot spam the refusal cue')
bank:Ambience('ambGamma')
local reactor=bank.bankAmbientVoice
assert(reactor.Looped and reactor.LoopRegion.Min==Bank.ambGamma.regions[1][1] and reactor.LoopRegion.Max==Bank.ambGamma.regions[1][2],'World loops stay inside their own region')
bank:Ambience('ambGamma');assert(bank.bankAmbientVoice==reactor,'Snapshots do not restart the current loop')
bank:Ambience('ambHydra');assert(not reactor.IsPlaying and bank.bankAmbientVoice~=reactor,'Changing maps stops the old ambience')
bank:Ambience(nil);assert(not bank.bankPools.world[2].IsPlaying,'Returning stops the ambient region')
local rarityStarts={}
for _,rarity in ipairs({'common','rare','legendary'}) do
 bank:Summon('start');clock+=.1;bank:Summon('tick');delayed={};before=summonPlays
 bank:Summon('reward',rarity)
 assert(summonPlays==before+1,'The rarity fanfare starts exactly once')
 assert(#delayed==(rarity=='common' and 0 or 1),'Rarer rewards have one restrained texture on their own channel')
 local sound=bank.bankPools.summon[bank.bankIndex.summon]
 assert(not rarityStarts[sound.PlaybackRegion.Min],'Each rarity has a distinct ending region')
 rarityStarts[sound.PlaybackRegion.Min]=true
 for _,fn in ipairs(delayed) do fn() end
 assert(not bank.bankPools.rewardAccent or #bank.bankPools.rewardAccent<=2,'Reward textures have a separate bounded two-voice pool')
end
bank:Summon('cancel');for _,channel in ipairs({'summon','rewardAccent'}) do for _,sound in ipairs(bank.bankPools[channel] or {}) do assert(not sound.IsPlaying,'Cancel stops the fanfare and its texture') end end
delayed={};bank:Summon('reward','legendary');bank:Summon('cancel');before=summonPlays
for _,fn in ipairs(delayed) do fn() end
assert(summonPlays==before,'A pending rarity texture cannot survive cancellation')
clock+=1;bank:Talent('hover');bank:Summon('start');bank:Cue('collect')
settings.interface=false;bank:Step()
for _,channel in ipairs({'ui','summon'}) do for _,sound in ipairs(bank.bankPools[channel]) do assert(not sound.IsPlaying,'Interface mute stops active regions') end end
assert(not bank.bankPools.events[bank.bankIndex.events].IsPlaying,'Interface mute stops an active pickup too')
settings.interface=true;bank:Ambience('ambGamma');settings.effects=false;bank:Step()
assert(not bank.bankAmbientVoice.IsPlaying,'Effects mute immediately stops looping bank ambience')
settings.effects=true;bank:Music('lobby');clock+=2;bank:Cue('boss');bank:Step()
assert(bank.sounds.lobby.Volume<.16,'Boss cue briefly makes room in the music')
clock+=1;bank:Step();assert(bank.sounds.lobby.Volume==.16,'Music returns after the priority cue')
print('PASS Sonniss banks: regions, variations, loading fallback, weapon/power identity, budgets, loops, three endings and live mute')
'''.replace('__AUDIO__', source).replace('__BANK__', bank_source)
with tempfile.TemporaryDirectory(prefix='doom-audio-') as temp:
    path = Path(temp) / 'audio.luau'
    path.write_text(harness, encoding='utf-8')
    subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(path)], check=True, cwd=ROOT)
