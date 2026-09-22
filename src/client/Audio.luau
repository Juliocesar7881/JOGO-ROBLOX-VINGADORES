-- Music and cues driven by the match phase.
--
-- Configured uploads override native cues. Original source audio is in assets/audio.
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("DoomShared"):WaitForChild("Config"))

local Audio = {}
Audio.__index = Audio

local LOOPED = { lobby = true, battle = true }
local VOLUME = { lobby = 0.3, battle = 0.28, victory = 0.4, defeat = 0.3, collect = 0.18, breach = 0.22, place = 0.2, upgrade = 0.3, levelUp = 0.4, ability = 0.25, boss = 0.28, wave = 0.22, chest = 0.3 }

function Audio.new(getState)
	local self = setmetatable({ getState = getState, sounds = {}, fades = {}, track = nil, lastCue = {} }, Audio)
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

function Audio:_allowed(effects)
	local state = self.getState()
	local settings = state and state.profile and state.profile.settings
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
		if LOOPED[name] and name ~= except then
			if sound.IsPlaying then self:_fade(name, 0) else sound:Stop() end
		end
	end
end

function Audio:Music(name)
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
	end
end

-- Short cues are rate limited so a wave of coin pickups cannot turn into a
-- continuous tone.
function Audio:Cue(name, minimumGap)
	if not self:_allowed(true) then return end
	local now = os.clock()
	if now - (self.lastCue[name] or -1) < (minimumGap or 0.12) then return end
	self.lastCue[name] = now
	local sound = self:_sound(name)
	if not sound then return end
	local ok = pcall(function()
		if LOOPED[name] then sound:Play() else SoundService:PlayLocalSound(sound) end
	end)
	if not ok then self.sounds[name] = nil end
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
	elseif phase == "Preparing" or phase == "Wave" then
		self:Music("battle")
	elseif phase == "Results" then
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
