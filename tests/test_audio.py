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
-- Weapon cues: a budget per quarter second, nothing beyond earshot, quieter far away.
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
assert(heard==4,'Dense fire is thinned to four voices, got '..heard)
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
print('PASS audio: transitions, mute, legacy settings, result cues, map ambience, weapon voice budget and jingles')
'''.replace('__AUDIO__', source)
with tempfile.TemporaryDirectory(prefix='doom-audio-') as temp:
    path = Path(temp) / 'audio.luau'
    path.write_text(harness, encoding='utf-8')
    subprocess.run([str(ROOT / '.tools/luau/luau.exe'), str(path)], check=True, cwd=ROOT)
