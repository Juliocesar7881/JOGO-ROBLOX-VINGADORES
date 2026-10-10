-- Music and cues driven by the match phase.
--
-- Configured uploads override native cues. Original source audio is in assets/audio.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("DoomShared"):WaitForChild("Config"))
local SoundBank = require(script.Parent:WaitForChild("SoundBank"))

local Audio = {}
Audio.__index = Audio

local MUSIC = { lobby = true, battle = true }
-- Each map has its own ambience under the music: street, reactor, yard,
-- savanna, bridge or fortress.
local AMBIENCE = { manhattan = "ambManhattan", gamma = "ambGamma", hydra = "ambHydra", wakanda = "ambWakanda", asgard = "ambAsgard", latveria = "ambLatveria" }
local LOOPED = { lobby = true, battle = true }
for _, name in pairs(AMBIENCE) do LOOPED[name] = true end
local VOLUME = { lobby = 0.16, battle = 0.18, victory = 0.26, defeat = 0.18, collect = 0.08, breach = 0.16, place = 0.12, upgrade = 0.16, levelUp = 0.22, ability = 0.17, boss = 0.2, wave = 0.1, chest = 0.2,
	abilityReady = 0.09, click = 0.065, open = 0.085, shotTech = 0.085, shotArrow = 0.075, shotMagic = 0.07, shotMelee = 0.1, shotBlast = 0.11 }
for _, name in pairs(AMBIENCE) do VOLUME[name] = 0.1 end
-- Combat is dense: only a few weapon sounds per quarter second reach the
-- speakers, quieter with distance, and none from beyond earshot.
local SHOT_WINDOW, SHOT_VOICES, EARSHOT, VOICES_PER_SOUND = 0.3, 3, 90, 3
Audio.Ambiences = AMBIENCE
local BANK_LIMITS = {ui=3,events=4,summon=2,combat=6,powers=3,boss=2,world=2}
local WEAPON_BANK = {
	hulk="heavy", capmen="heavy", beast="punch", shangchi="punch", ironfist="punch", antman="punch",
	captain="metal", panther="swift", wolverine="swift", daredevil="swift", blade="swift",
	groot="organic", spiderman="web", hawkeye="arrow", thor="tech", storm="tech", wasp="tech",
	ironman="tech", starlord="tech", vision="beam", cyclops="beam", nova="beam", captainmarvel="beam",
	wanda="magic", strange="magic", jean="magic", gambit="magic", nightcrawler="magic", emerald="magic",
	iceman="ice", ghostrider="fire", torch="fire", rocket="blast", warmachine="blast", nightstalker="blast",
	falcon="swift", bucky="tech", widow="swift", silversurfer="beam", psylocke="magic", deadpool="tech",
	moonknight="arrow", solartitan="beam", speedster="swift", amazon="metal", seaking="organic",
}
local FAMILY_BANK = {shotTech="tech",shotArrow="arrow",shotMagic="magic",shotMelee="punch",shotBlast="blast"}
local POWER_BANK = {blast="powerBlast",smite="powerLightning",freeze="powerFreeze",web="powerWeb",lightning="powerLightning",chain="powerLightning",
	heal="powerHeal",buff="powerHeal",rally="powerHeal",barrier="powerHeal",shield="powerHeal",overdrive="powerHeal",
	taunt="powerTaunt",meteor="powerFire",fire="powerFire",burn="powerFire",execute="powerBlast",
	pull="powerMagic",teleport="powerMagic",slow="powerFreeze",stun="powerLightning",reveal="powerMagic",weaken="powerMagic",energy="powerHeal"}
local HERO_POWER_BANK = {spiderman="powerWeb",iceman="powerFreeze",groot="powerTaunt",wanda="powerMagic",strange="powerMagic",jean="powerFire"}
local function bankChannel(asset) return string.lower(string.sub(asset,4)) end

function Audio.WeaponProfile(heroId, family)
	return WEAPON_BANK[heroId] or FAMILY_BANK[family] or "tech"
end

function Audio.PowerProfile(heroId, kind, family)
	return HERO_POWER_BANK[heroId] or POWER_BANK[kind] or (family=="shotBlast" and "powerBlast" or "powerMagic")
end
-- Material language using our existing owned recordings: a tactile click,
-- a mechanical placement, a charging upgrade and a soft wave whoosh.
-- Repeated ordinary actions no longer all play a melodic reward arpeggio.
local PALETTES = {
	collect = {{"click", 1.22, 0.075}},
	place = {{"shotMelee", 1.25, 0.085}, {"click", 0.9, 0.035, 0.045}},
	upgrade = {{"shotTech", 0.72, 0.085}, {"click", 1.3, 0.045, 0.08}},
	wave = {{"shotArrow", 0.82, 0.075}},
	breach = {{"shotBlast", 0.8, 0.12}},
	abilityReady = {{"click", 1.1, 0.05}},
	deny = {{"click", 0.65, 0.075}},
}
local CUE_GAPS = {click=0.08,open=0.25,deny=0.6,collect=0.2,place=0.14,upgrade=0.3,abilityReady=1,wave=0.6,breach=0.4}
local PITCHES = {0.96, 1.03, 0.99, 1.06, 0.93}
-- Timbre belongs to the weapon, not the rarity. Heavy equipment gets a
-- lower register; agile tools stay short and bright. Shared voices remain
-- capped at three per family even with the entire roster on screen.
local WEAPON_TONE = {
	ironman = {1.12, 1, 1, -3}, warmachine = {0.74, 1.05, -5, 3}, rocket = {0.8, 0.95, -3, 2},
	hulk = {0.68, 1.1, -9, 5}, groot = {0.8, 0.85, -8, 1}, beast = {0.9, 0.9, -4, 1},
	hawkeye = {1.12, 0.82, 2, -7}, spiderman = {0.88, 0.75, -3, -6},
	wanda = {0.9, 0.85, -4, -3}, strange = {1.05, 0.8, -2, -5}, thor = {0.83, 1, -4, 3},
	starlord = {1.2, 0.82, 3, -6}, cyclops = {0.9, 0.9, -1, -4},
}
-- A playable action arrangement while the dedicated battle upload is under
-- moderation. All stems are our owned recordings: minor choir, bass drum
-- and filtered noise percussion. It never substitutes the lobby melody.
local ACTION_STEP = 60 / 96 / 2
local ACTION_STEMS = {
	bed = {"ambLatveria", 1, 0.18, -12, 3, -5},
	kick = {"shotMelee", 0.85, 0.10, -22, -8, 4},
	snare = {"shotArrow", 1.45, 0.065, 4, -12, -24},
}

-- Five reward signatures, from a short confirmation to a layered fanfare.
-- Values: existing owned sample, pitch, volume, delay. Dedicated uploads
-- replace the whole signature, never layer a second ending over it.
local REWARDS = {
	common = {name="rewardCommon", notes={{"click",0.82,0.10,0},{"click",1.1,0.07,0.075}}},
	rare = {name="rewardRare", notes={{"shotMagic",0.75,0.095,0},{"shotMagic",1,0.11,0.15}}},
	epic = {name="rewardEpic", notes={{"shotTech",0.6,0.055,0},{"shotMagic",0.84,0.09,0.06},{"shotMagic",1.12,0.10,0.22},{"shotMagic",1.33,0.09,0.38}}},
	legendary = {name="rewardLegendary", notes={{"shotMelee",0.9,0.075,0},{"shotMagic",0.75,0.11,0},{"shotMagic",1,0.11,0.18},{"shotMagic",1.5,0.10,0.36},{"shotMagic",1.19,0.075,0.36}}},
	mythic = {name="rewardMythic", notes={{"shotBlast",0.82,0.07,0},{"shotMagic",0.5,0.10,0.02},{"shotMagic",0.75,0.10,0.16},{"shotMagic",1,0.11,0.30},{"shotMagic",1.5,0.10,0.5},{"shotMagic",1.26,0.075,0.5}}},
}

function Audio.new(getState)
	local self = setmetatable({ getState = getState, sounds = {}, fades = {}, track = nil, lastCue = {}, voices = {}, voiceIndex = {}, shotVoices = 0, ambient = nil }, Audio)
	self.folder = Instance.new("Folder")
	self.folder.Name = "DoomAudio"
	self.folder.Parent = SoundService
	-- Parenting starts Roblox's normal download before the first action.
	local loaded = {}
	for _, entry in pairs(SoundBank) do
		if not loaded[entry.asset] then loaded[entry.asset] = true; self:_bankSound(entry.asset) end
	end
	return self
end

function Audio:_sound(name)
	local id = math.floor(tonumber((Config.Audio or {})[name]) or 0)
	local fallback = (Config.BuiltinCues or {})[name]
	if id <= 0 and not fallback then return nil end
	local sound = self.sounds[name]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name = name
		sound.SoundId = id > 0 and "rbxassetid://" .. tostring(id) or fallback.path
		sound.PlaybackSpeed = id > 0 and 1 or fallback.speed
		sound.Volume = VOLUME[name] or 0.35
		sound.Looped = LOOPED[name] == true
		sound.Parent = self.folder
		self.sounds[name] = sound
	end
	return sound
end

-- Menu and reward sounds have their own switch, separate from the battle's.
local INTERFACE = { chest = true, levelUp = true, upgrade = true, collect = true, click = true, open = true, card = true, deny = true }

-- A built-in jingle: one Sound per note, played at its time and pitch.
function Audio:_jingle(name, fallback)
	local pool = self.voices["jingle:" .. name] or {}
	self.voices["jingle:" .. name] = pool
	for index, note in ipairs(fallback.notes) do
		local sound = pool[index]
		if not sound then
			sound = Instance.new("Sound")
			sound.Name, sound.SoundId = name .. "_" .. index, note.path or fallback.path
			sound.PlaybackSpeed, sound.Volume = note.speed or fallback.speed or 1, (VOLUME[name] or 0.35) * (note.volume or 1)
			sound.Parent = self.folder
			pool[index] = sound
		end
		local function play() pcall(function() SoundService:PlayLocalSound(sound) end) end
		if (note.at or 0) <= 0 then play() else task.delay(note.at, play) end
	end
end

function Audio:_allowed(effects, name)
	local state = self.getState()
	local settings = state and state.profile and state.profile.settings
	if effects and name and INTERFACE[name] and settings and settings.interface == false then return false end
	-- Preserve the old combined mute until the player explicitly changes it.
	if effects and settings and settings.effects ~= nil then return settings.effects ~= false end
	return settings == nil or settings.music ~= false
end

-- One privately uploaded atlas per category, with bounded reusable voices.
-- Missing, loading or moderated uploads keep the existing playable sound.
function Audio:_bankSound(asset)
	local id = tonumber((Config.Audio or {})[asset]) or 0
	if id <= 0 then return nil end
	return self:_sound(asset)
end

function Audio:_bankPlay(name, options)
	options = options or {}
	local entry = SoundBank[name]
	if not entry or not self:_allowed(true, options.interface and "click" or nil) then return false end
	local template = self:_bankSound(entry.asset)
	if not template or template.IsLoaded == false then return false end
	local channel = bankChannel(entry.asset)
	self.bankPools, self.bankIndex, self.bankVariants = self.bankPools or {}, self.bankIndex or {}, self.bankVariants or {}
	local pool = self.bankPools[channel] or {}; self.bankPools[channel] = pool
	local index = (self.bankIndex[channel] or 0) % (BANK_LIMITS[channel] or 2) + 1
	self.bankIndex[channel] = index
	local variant = (self.bankVariants[name] or 0) % #entry.regions + 1
	self.bankVariants[name] = variant
	local region = entry.regions[variant]
	local sound = pool[index]
	if not sound then
		sound = Instance.new("Sound"); sound.Name, sound.Parent = "Bank_" .. channel .. "_" .. index, self.folder
		pool[index] = sound
	end
	sound:Stop()
	sound.SoundId, sound.PlaybackRegionsEnabled = template.SoundId, true
	sound.PlaybackRegion, sound.LoopRegion = NumberRange.new(region[1], region[2]), NumberRange.new(region[1], region[2])
	sound.Looped = entry.loop == true
	sound.PlaybackSpeed = options.pitch or 1
	sound.Volume = options.volume or VOLUME[name] or 0.12
	sound.TimePosition = region[1]
	self.bankInterfaceVoices = self.bankInterfaceVoices or {}
	self.bankInterfaceVoices[sound] = options.interface == true
	local ok = pcall(function() sound:Play() end)
	if ok and options.duck then self.duckUntil = os.clock() + options.duck end
	return ok, sound
end

function Audio:_stopBank(channel)
	for _, sound in ipairs((self.bankPools or {})[channel] or {}) do sound:Stop() end
end

-- Non-weapon battle events share a separate, restrained budget.
function Audio:Event(name, distance)
	if not self:_allowed(true) or (distance or 0) > EARSHOT then return false end
	local now = os.clock()
	if now - (self.lastCue["event:" .. name] or -math.huge) < (name=="bossDown" and 2 or .5) then return false end
	self.lastCue["event:" .. name] = now
	local played = self:_bankPlay(name, {volume=.16*math.clamp(1-(distance or 0)/EARSHOT,.1,1),duck=name=="bossDown" and .8 or nil})
	if not played and name == "bossDown" then self:Cue("victory",2) end
	return played
end

function Audio:_fade(name, volume)
	local sound = self.sounds[name]
	if not sound then return end
	if self.fades[name] then self.fades[name]:Cancel() end
	local tween = TweenService:Create(sound, TweenInfo.new(0.65), { Volume = volume })
	self.fades[name] = tween
	tween:Play()
	if volume == 0 then
		task.delay(0.7, function()
			if self.fades[name] == tween then sound:Stop(); self.fades[name] = nil end
		end)
	end
end

function Audio:_stopMusic(except)
	if except ~= "action" then self:_action(false) end
	for name, sound in pairs(self.sounds) do
		if MUSIC[name] and name ~= except then
			if sound.IsPlaying then self:_fade(name, 0) else sound:Stop() end
		end
	end
end

function Audio:_actionVoice(stem)
	self.actionVoices = self.actionVoices or {}
	if self.actionVoices[stem] then return self.actionVoices[stem] end
	local def = ACTION_STEMS[stem]
	local template = self:_sound(def[1])
	if not template then return nil end
	local sound = Instance.new("Sound")
	sound.Name, sound.SoundId, sound.Parent = "Action_" .. stem, template.SoundId, self.folder
	sound.PlaybackSpeed, sound.Volume, sound.Looped = def[2], def[3], stem == "bed"
	local eq = Instance.new("EqualizerSoundEffect")
	eq.HighGain, eq.MidGain, eq.LowGain, eq.Parent = def[4], def[5], def[6], sound
	self.actionVoices[stem] = sound
	return sound
end

function Audio:_action(enabled)
	if enabled == self.actionPlaying then return end
	self.actionPlaying = enabled
	if not enabled then
		for _, sound in pairs(self.actionVoices or {}) do sound:Stop() end
		return
	end
	self.actionEpoch, self.actionBeat = os.clock(), -1
	local bed = self:_actionVoice("bed")
	if bed then bed.TimePosition = 0; bed:Play() end
end

-- The render driver plays only the current beat: a slow frame never queues
-- a burst of missed drums. Three reusable voices are independent of combat
-- sounds and follow Music, including when Effects is muted.
function Audio:Step()
	local effectsAllowed = self:_allowed(true)
	local interfaceAllowed = self:_allowed(true, "click")
	if self.bankEffectsAllowed ~= effectsAllowed or self.bankInterfaceAllowed ~= interfaceAllowed then
		self.bankEffectsAllowed, self.bankInterfaceAllowed = effectsAllowed, interfaceAllowed
		for channel in pairs(self.bankPools or {}) do
			if not effectsAllowed or (not interfaceAllowed and (channel == "ui" or channel == "summon")) then self:_stopBank(channel) end
		end
		if not interfaceAllowed then
			for sound, interface in pairs(self.bankInterfaceVoices or {}) do if interface then sound:Stop() end end
		end
	end
	local ducked = effectsAllowed and os.clock() < (self.duckUntil or 0)
	if self.ducked ~= ducked then
		self.ducked = ducked
		local current = self.track and self.sounds[self.track]
		if current and MUSIC[self.track] and current.IsPlaying then current.Volume = (VOLUME[self.track] or .18) * (ducked and .64 or 1) end
		local bed = self.actionVoices and self.actionVoices.bed
		if bed then bed.Volume = ACTION_STEMS.bed[3] * (ducked and .64 or 1) end
	end
	if not self.actionPlaying then return end
	if not self:_allowed() then self:_action(false); return end
	local step = math.floor((os.clock() - self.actionEpoch) / ACTION_STEP)
	if step == self.actionBeat then return end
	self.actionBeat = step
	local eighth, bar = step % 8, math.floor(step / 8) % 8
	local stem
	if eighth == 0 or eighth == 4 or (bar % 2 == 1 and eighth == 7) then stem = "kick"
	elseif eighth == 2 or eighth == 6 then stem = "snare" end
	if stem then
		local voice = self:_actionVoice(stem)
		if voice then
			voice.Volume = ACTION_STEMS[stem][3] * (eighth == 7 and 0.55 or 1) * (bar == 7 and 0.75 or 1) * (ducked and .64 or 1)
			voice.TimePosition = 0
			voice:Play()
		end
	end
end

function Audio:Music(name)
	-- Keep the lobby untouched. An unavailable battle upload uses the action
	-- stems rather than the lobby's peaceful melody.
	if name == "battle" and (((Config.Audio or {}).battle or 0) <= 0 or (self.unplayable and self.unplayable.battle)) then name = "action" end
	local allowed = self:_allowed()
	if self.track == name and self.musicAllowed == allowed then return end
	self.musicAllowed = allowed
	if not allowed then
		self.track = name
		self:_stopMusic(nil)
		return
	end
	self.track = name
	self:_stopMusic(name)
	if not name then return end
	if name == "action" then self:_action(true); return end
	local sound = self:_sound(name)
	if sound then
		local ok = pcall(function()
			if not sound.IsPlaying then sound.Volume = 0; sound:Play() end
			self:_fade(name, VOLUME[name] or 0.3)
		end)
		if not ok then self.sounds[name] = nil end
		-- Not loaded after a few seconds (IsLoaded is exactly false): remember it and
		-- switch to the action arrangement. A stand-in without IsLoaded never trips this.
		if name ~= "lobby" and ((Config.Audio or {})[name] or 0) > 0 then
			task.delay(6, function()
				if self.track == name and sound.IsLoaded == false then
					self.unplayable = self.unplayable or {}
					self.unplayable[name] = true
					self:_stopMusic(nil)
					self.track = nil
					self:Music(name)
				end
			end)
		end
	end
end

-- Short cues are rate limited so a wave of coin pickups cannot turn into a
-- continuous tone.
function Audio:BossProfile(enemyId)
	self.bossCue = ({doom="bossMetal",redskull="bossMetal",killmonger="bossMetal",
		lizard="bossBeast",abomination="bossBeast",loki="bossIllusion"})[enemyId] or "boss"
end

function Audio:Cue(name, minimumGap)
	if not self:_allowed(true, name) then return end
	local now = os.clock()
	if now - (self.lastCue[name] or -1) < math.max(minimumGap or 0.12, CUE_GAPS[name] or 0) then return end
	self.lastCue[name] = now
	if self:_bankPlay(name=="boss" and (self.bossCue or "boss") or name, {interface=INTERFACE[name],volume=VOLUME[name] or .12,
		duck=(name=="boss" or name=="victory" or name=="defeat") and .8 or nil}) then return end
	if name == "card" then name = "upgrade" end
	if PALETTES[name] and not (Config.DirectAudioCues or {})[name] then
		for _, layer in ipairs(PALETTES[name]) do
			local function play()
				-- Recheck mute for a delayed layer; closing/muting never leaves
				-- a pending sound behind. Missing aliases keep the original cue.
				if not self:_allowed(true,name) then return end
				local voice = self:_voice(layer[1]) or self:_voice(name)
				if voice then
					voice.Volume, voice.PlaybackSpeed = layer[3], (self:_sound(layer[1]) or self:_sound(name)).PlaybackSpeed * layer[2]
					pcall(function() SoundService:PlayLocalSound(voice) end)
				end
			end
			if (layer[4] or 0) > 0 then task.delay(layer[4],play) else play() end
		end
		return
	end
	local fallback = (Config.BuiltinCues or {})[name]
	if fallback and fallback.notes and math.floor(tonumber((Config.Audio or {})[name]) or 0) <= 0 then
		self:_jingle(name, fallback)
		return
	end
	local sound = self:_sound(name)
	if not sound then return end
	local ok = pcall(function()
		if LOOPED[name] then sound:Play()
		else
			local voice = self:_voice(name)
			if voice then
				self.cueSequence = (self.cueSequence or 0) + 1
				voice.Volume, voice.PlaybackSpeed = VOLUME[name] or 0.2, sound.PlaybackSpeed * PITCHES[(self.cueSequence-1)%#PITCHES+1]
				SoundService:PlayLocalSound(voice)
			end
		end
	end)
	if not ok then self.sounds[name] = nil end
end

-- Original research-board cues derived from our own uploaded clicks/thunks.
-- A private three-voice pool keeps hover notes quiet and stops a fast pan
-- from producing dozens of overlapping sounds. Interface mute still applies.
function Audio:Talent(action)
	if not self:_allowed(true, "click") then return end
	local settings = {
		hover = {"click", 1.45, 0.055, 0.10},
		snap = {"place", 1.2, 0.12, 0.07},
		center = {"open", 1.1, 0.1, 0.15},
	}
	local cue = settings[action]
	if not cue then return end
	local key, now = "talent:" .. action, os.clock()
	if now - (self.lastCue[key] or -1) < cue[4] then return end
	self.lastCue[key] = now
	local bank = {hover="talentHover",snap="talentSnap",center="talentCenter"}
	if self:_bankPlay(bank[action], {interface=true,volume=cue[3]}) then return end
	local template = self:_sound(cue[1])
	if not template then return end
	local pool = self.voices[key] or {}
	self.voices[key] = pool
	local index = (self.voiceIndex[key] or 0) % 3 + 1
	self.voiceIndex[key] = index
	local sound = pool[index]
	if not sound then
		sound = Instance.new("Sound")
		sound.Name, sound.SoundId, sound.Parent = "Talent_" .. action, template.SoundId, self.folder
		pool[index] = sound
	end
	sound.Volume, sound.PlaybackSpeed = cue[3], template.PlaybackSpeed * cue[2]
	pcall(function() SoundService:PlayLocalSound(sound) end)
end

-- The reel owns these voices: the tick is independent of coin collection
-- and follows actual tile crossings, including the slow last few cards.
function Audio:Summon(action, rarity)
	if action == "cancel" or action == "start" then
		self.summonEpoch = (self.summonEpoch or 0) + 1
		for _, voice in pairs(self.summonVoices or {}) do voice:Stop() end
		self:_stopBank("summon")
		if action == "cancel" then return end
	end
	if not self:_allowed(true, "chest") then return end
	self.summonVoices = self.summonVoices or {}
	local function play(key, source, pitch, volume, segment)
		if not self:_allowed(true, "chest") then return end
		local template = self:_sound(source)
		if not template then return end
		local voice = self.summonVoices[key]
		if not voice then
			voice = Instance.new("Sound")
			voice.Name, voice.Parent = "Summon_" .. key, self.folder
			self.summonVoices[key] = voice
		end
		voice:Stop()
		voice.SoundId, voice.PlaybackSpeed, voice.Volume = template.SoundId, template.PlaybackSpeed * pitch, volume
		-- The fallback uses the initial transient, not the entire melodic cue.
		voice.PlaybackRegionsEnabled = segment ~= nil
		if segment then voice.PlaybackRegion = NumberRange.new(0, segment) end
		voice.TimePosition = 0
		pcall(function() voice:Play() end)
	end
	if action == "tick" or action == "start" then
		local key = action == "tick" and "reelTick" or "reelStart"
		local now = os.clock()
		if action == "tick" and now - (self.lastCue[key] or -math.huge) < 0.045 then return end
		self.lastCue[key] = now
		if self:_bankPlay(key, {interface=true,volume=action=="tick" and .11 or .12}) then return end
		local dedicated = ((Config.Audio or {})[key] or 0) > 0
		play(key, dedicated and key or (action == "tick" and "click" or "open"), dedicated and 1 or 0.72,
			action == "tick" and 0.13 or 0.10, not dedicated and (action == "tick" and 0.065 or 0.24) or nil)
	elseif action == "reward" then
		local cue = REWARDS[rarity] or REWARDS.common
		self.summonEpoch = (self.summonEpoch or 0) + 1
		local epoch = self.summonEpoch
		self:_stopBank("summon")
		if self:_bankPlay(cue.name, {interface=true,volume=.19,duck=.6}) then return end
		if ((Config.Audio or {})[cue.name] or 0) > 0 then
			play("reward", cue.name, 1, 0.20)
			return
		end
		for index, note in ipairs(cue.notes) do
			local function layer()
				if self.summonEpoch == epoch then play("reward_" .. index, note[1], note[2], note[3]) end
			end
			if note[4] == 0 then layer() else task.delay(note[4], layer) end
		end
	end
end

-- The map's ambience loop, faded in under the music; nil fades it out. It
-- follows the effects switch, not the music one: it is sound of the place.
function Audio:Ambience(name)
	if not self:_allowed(true) then name = nil end
	-- Retry a loading atlas on the next snapshot, without restarting a loop
	-- that is already playing. Scene changes stop the previous region.
	if self.bankAmbientName == name and self.bankAmbientVoice and self.bankAmbientVoice.IsPlaying then return end
	if self.bankAmbientVoice then self.bankAmbientVoice:Stop(); self.bankAmbientVoice = nil end
	self.bankAmbientName = nil
	if name then
		local ok, voice = self:_bankPlay(name, {volume=name=="ambLobby" and .045 or .065})
		if ok then
			if self.ambient and self.sounds[self.ambient] then self:_fade(self.ambient, 0) end
			self.ambient, self.bankAmbientName, self.bankAmbientVoice = name, name, voice
			return
		end
	end
	if self.ambient == name then return end
	if self.ambient and self.sounds[self.ambient] then self:_fade(self.ambient, 0) end
	self.ambient = name
	if not name then return end
	local sound = self:_sound(name)
	if not sound then return end
	local ok = pcall(function()
		if not sound.IsPlaying then sound.Volume = 0; sound:Play() end
		self:_fade(name, VOLUME[name] or 0.2)
	end)
	if not ok then self.sounds[name] = nil end
end

-- A few Sound voices per weapon cue, used round robin, so overlapping shots
-- do not cut each other off.
function Audio:_voice(name)
	local template = self:_sound(name)
	if not template then return nil end
	local pool = self.voices[name] or {}
	self.voices[name] = pool
	local index = (self.voiceIndex[name] or 0) % VOICES_PER_SOUND + 1
	self.voiceIndex[name] = index
	local voice = pool[index]
	if not voice then
		voice = Instance.new("Sound")
		voice.Name, voice.SoundId, voice.PlaybackSpeed = name, template.SoundId, template.PlaybackSpeed
		voice.Parent = self.folder
		local filter = Instance.new("EqualizerSoundEffect")
		filter.Name, filter.Parent = "WeaponTone", voice
		pool[index] = voice
	end
	return voice
end

-- A weapon cue at a distance from the listener. Returns whether it played.
function Audio:Shot(name, distance, heroId)
	if not self:_allowed(true, name) then return false end
	distance = tonumber(distance) or 0
	if distance > EARSHOT then return false end
	local now = os.clock()
	if now - (self.shotWindowAt or -math.huge) >= SHOT_WINDOW then self.shotWindowAt, self.shotVoices = now, 0 end
	if self.shotVoices >= SHOT_VOICES then return false end
	if now - (self.lastCue[name] or -math.huge) < 0.12 then return false end
	local tone = WEAPON_TONE[heroId]
	local volume = (VOLUME[name] or .085) * math.clamp((1-distance/EARSHOT)^1.5,.06,1) * (tone and tone[2] or 1)
	local sequence = (self.shotSequence or 0) + 1
	if self:_bankPlay(Audio.WeaponProfile(heroId,name), {volume=volume,pitch=PITCHES[(sequence-1)%#PITCHES+1]}) then
		self.shotVoices += 1; self.lastCue[name] = now; self.shotSequence = sequence
		return true
	end
	local voice = self:_voice(name)
	if not voice then return false end
	self.shotVoices += 1
	self.lastCue[name] = now
	self.shotSequence = (self.shotSequence or 0) + 1
	voice.PlaybackSpeed = self:_sound(name).PlaybackSpeed * PITCHES[(self.shotSequence-1)%#PITCHES+1] * (tone and tone[1] or 1)
	voice.Volume = volume
	local filter = voice:FindFirstChild("WeaponTone")
	if filter then filter.HighGain, filter.MidGain, filter.LowGain = tone and tone[3] or 0, -2, tone and tone[4] or 0 end
	return (pcall(function() voice:Play() end))
end

-- Powers inherit the leader's weapon family instead of one identical jingle.
function Audio:Ability(family, distance, kind, heroId)
	if not self:_allowed(true,"ability") then return false end
	local now = os.clock()
	if now-(self.lastCue.ability or -math.huge)<0.6 or (distance or 0)>EARSHOT then return false end
	self.lastCue.ability=now
	if self:_bankPlay(Audio.PowerProfile(heroId,kind,family),
		{volume=.15*math.clamp(1-(distance or 0)/EARSHOT,.12,1),duck=.45}) then return true end
	local voice=self:_voice(family) or self:_voice("ability")
	if not voice then return false end
	voice.Volume=0.15*math.clamp(1-(distance or 0)/EARSHOT,0.12,1)
	voice.PlaybackSpeed=(self:_sound(family) or self:_sound("ability")).PlaybackSpeed*0.78
	local filter=voice:FindFirstChild("WeaponTone")
	if filter then filter.HighGain,filter.MidGain,filter.LowGain=-3,0,1 end
	return pcall(function() SoundService:PlayLocalSound(voice) end)
end

function Audio:Update(state)
	if not state then return end
	local phase = state.phase
	if phase == "Wave" and (self.lastWave ~= state.wave or self.lastPhase ~= "Wave") then
		self:Cue("wave", 2)
	end
	self.lastWave, self.lastPhase = state.wave, phase
	if phase == "Lobby" then
		self:Music("lobby")
		self:Ambience("ambLobby")
	elseif phase == "Preparing" or phase == "Wave" then
		self:Music("battle")
		self:Ambience(AMBIENCE[state.match and state.match.mapId])
	elseif phase == "Results" then
		self:Ambience(nil)
		if self.track ~= "results" then
			self.track = "results"
			self:_stopMusic(nil)
			self:Cue(state.results and state.results.victory and "victory" or "defeat", 0)
		end
	end
	-- Music is re-evaluated on every state update, so toggling the setting in
	-- the options page takes effect without waiting for a phase change.
end

return Audio
