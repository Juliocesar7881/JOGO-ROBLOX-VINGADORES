-- Music and cues driven by the match phase.
--
-- Configured uploads override native client cues. Music remains unconfigured.
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage:WaitForChild("DoomShared"):WaitForChild("Config"))

local Audio = {}
Audio.__index = Audio

local LOOPED = { lobby = true, battle = true }
local VOLUME = { lobby = 0.3, battle = 0.34, victory = 0.4, defeat = 0.3, collect = 0.18, breach = 0.22, place = 0.2, upgrade = 0.3, levelUp = 0.4 }

function Audio.new(getState)
	local self = setmetatable({ getState = getState, sounds = {}, track = nil, lastCue = {} }, Audio)
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

function Audio:_allowed()
	local state = self.getState()
	local settings = state and state.profile and state.profile.settings
	-- Profiles saved before this setting existed default to music on.
	return settings == nil or settings.music ~= false
end

function Audio:_stopMusic(except)
	for name, sound in pairs(self.sounds) do
		if LOOPED[name] and name ~= except then sound:Stop() end
	end
end

function Audio:Music(name)
	local allowed = self:_allowed()
	if not allowed then
		self.track = name
		self:_stopMusic(nil)
		return
	end
	self.track = name
	self:_stopMusic(name)
	if not name then return end
	local sound = self:_sound(name)
	if sound and not sound.IsPlaying then
		local ok = pcall(function() sound:Play() end)
		if not ok then self.sounds[name] = nil end
	end
end

-- Short cues are rate limited so a wave of coin pickups cannot turn into a
-- continuous tone.
function Audio:Cue(name, minimumGap)
	if not self:_allowed() then return end
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
