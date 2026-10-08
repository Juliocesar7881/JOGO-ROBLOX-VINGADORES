-- Music and cues driven by the match phase.
--
-- Configured uploads override native cues. Original source audio is in assets/audio.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("DoomShared"):WaitForChild("Config"))

local Audio = {}
Audio.__index = Audio

local MUSIC = { lobby = true, battle = true }
-- Each map has its own ambience under the music: street, reactor, yard,
-- savanna, bridge or fortress.
local AMBIENCE = { manhattan = "ambManhattan", gamma = "ambGamma", hydra = "ambHydra", wakanda = "ambWakanda", asgard = "ambAsgard", latveria = "ambLatveria" }
local LOOPED = { lobby = true, battle = true }
for _, name in pairs(AMBIENCE) do LOOPED[name] = true end
local VOLUME = { lobby = 0.3, battle = 0.28, victory = 0.4, defeat = 0.3, collect = 0.18, breach = 0.22, place = 0.2, upgrade = 0.3, levelUp = 0.4, ability = 0.25, boss = 0.28, wave = 0.22, chest = 0.3,
	abilityReady = 0.35, click = 0.22, open = 0.14, shotTech = 0.13, shotArrow = 0.13, shotMagic = 0.12, shotMelee = 0.15, shotBlast = 0.16 }
for _, name in pairs(AMBIENCE) do VOLUME[name] = 0.2 end
-- Combat is dense: only a few weapon sounds per quarter second reach the
-- speakers, quieter with distance, and none from beyond earshot.
local SHOT_WINDOW, SHOT_VOICES, EARSHOT, VOICES_PER_SOUND = 0.25, 4, 90, 3
Audio.Ambiences = AMBIENCE

function Audio.new(getState)
	local self = setmetatable({ getState = getState, sounds = {}, fades = {}, track = nil, lastCue = {}, voices = {}, voiceIndex = {}, shotVoices = 0, ambient = nil }, Audio)
	self.folder = Instance.new("Folder")
	self.folder.Name = "DoomAudio"
	self.folder.Parent = SoundService
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
local INTERFACE = { chest = true, levelUp = true, upgrade = true, collect = true, click = true, open = true }

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
	for name, sound in pairs(self.sounds) do
		if MUSIC[name] and name ~= except then
			if sound.IsPlaying then self:_fade(name, 0) else sound:Stop() end
		end
	end
end

function Audio:Music(name)
	-- A track Roblox will not serve (still under review, or rejected) stands in with
	-- the lobby theme, so a moderated upload never leaves a match silent.
	if name and self.unplayable and self.unplayable[name] and name ~= "lobby" then name = "lobby" end
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
	local sound = self:_sound(name)
	if sound then
		local ok = pcall(function()
			if not sound.IsPlaying then sound.Volume = 0; sound:Play() end
			self:_fade(name, VOLUME[name] or 0.3)
		end)
		if not ok then self.sounds[name] = nil end
		-- Not loaded after a few seconds (IsLoaded is exactly false): remember it and
		-- switch to the lobby theme. A stand-in or an engine without IsLoaded never trips this.
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
function Audio:Cue(name, minimumGap)
	if not self:_allowed(true, name) then return end
	local now = os.clock()
	if now - (self.lastCue[name] or -1) < (minimumGap or 0.12) then return end
	self.lastCue[name] = now
	local fallback = (Config.BuiltinCues or {})[name]
	if fallback and fallback.notes and math.floor(tonumber((Config.Audio or {})[name]) or 0) <= 0 then
		self:_jingle(name, fallback)
		return
	end
	local sound = self:_sound(name)
	if not sound then return end
	local ok = pcall(function()
		if LOOPED[name] then sound:Play() else SoundService:PlayLocalSound(sound) end
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

-- The map's ambience loop, faded in under the music; nil fades it out. It
-- follows the effects switch, not the music one: it is sound of the place.
function Audio:Ambience(name)
	if not self:_allowed(true) then name = nil end
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
		pool[index] = voice
	end
	return voice
end

-- A weapon cue at a distance from the listener. Returns whether it played.
function Audio:Shot(name, distance)
	if not self:_allowed(true, name) then return false end
	distance = tonumber(distance) or 0
	if distance > EARSHOT then return false end
	local now = os.clock()
	if now - (self.shotWindowAt or -math.huge) >= SHOT_WINDOW then self.shotWindowAt, self.shotVoices = now, 0 end
	if self.shotVoices >= SHOT_VOICES then return false end
	if now - (self.lastCue[name] or -math.huge) < 0.05 then return false end
	local voice = self:_voice(name)
	if not voice then return false end
	self.shotVoices += 1
	self.lastCue[name] = now
	voice.Volume = (VOLUME[name] or 0.13) * math.clamp(1 - distance / EARSHOT, 0.2, 1)
	return (pcall(function() voice:Play() end))
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
		self:Ambience(nil)
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
