"""Exercise independent mute, music transitions and stale fade cancellation."""
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / 'src/client/Audio.luau').read_text(encoding='utf-8')
harness = r'''
local delayed, sounds = {}, {}
local Config = {Audio={lobby=10,battle=11,collect=12,victory=13,wave=14,ambGamma=21,ambHydra=22,shotTech=23,shotBlast=24}}
local module={WaitForChild=function(self) return self end}
local clock=10
local os={clock=function() return clock end}
local task={delay=function(_,fn) table.insert(delayed,fn) end}
local TweenInfo={new=function() return {} end}
local effectsPlayed=0
local soundService={PlayLocalSound=function(_,sound) assert(sound.SoundId); effectsPlayed+=1 end}
local tweenService={Create=function(_,sound,_,goal)
 local tween={Cancel=function(self) self.cancelled=true end,Play=function() sound.Volume=goal.Volume end}
 return tween
end}
local game={GetService=function(_,name)
 return name=='SoundService' and soundService or name=='TweenService' and tweenService or module
end}
local require=function() return Config end
local Instance={new=function(kind)
 local value={IsPlaying=false,Play=function(self) self.IsPlaying=true end,Stop=function(self) self.IsPlaying=false end}
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
assert(audio.ambient==nil,'The lobby has no map ambience')
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
clock+=1;assert(not audio:Ability('shotTech',200),'Distant powers are silent')
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
'''.replace('__AUDIO__', source)
with tempfile.TemporaryDirectory(prefix='doom-audio-') as temp:
    path = Path(temp) / 'audio.luau'
    path.write_text(harness, encoding='utf-8')
    subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(path)], check=True, cwd=ROOT)
