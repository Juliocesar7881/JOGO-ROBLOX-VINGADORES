-- Change deployment IDs only after creating both places in YOUR universe.
return {
	Version = "0.1.0",
	BalanceVersion = "2026.3",
	DataStoreName = "DoomsdayProfiles_v1",
	StudioMemory = true, -- Never used outside Studio. Studio profiles are temporary.
	ProfileLeaseSeconds = 180,
	AutoSaveSeconds = 45,
	ProfileRetries = 3,
	SeasonEpoch = 1789862400, -- 2026-09-20 UTC
	SeasonDays = 60,
	LobbyPlaceId = 0,
	MatchPlaceId = 0,
	MaxPartySize = 4,
	BaseHP = 100,
	StartEnergy = 600,
	PreparationSeconds = 10,
	ReconnectSeconds = 120,
	MaxEnemies = 180,
	MaxCoinPiles = 50,
	EnemySyncInterval = 0.2,
	SnapshotInterval = 0.5,
	SimulationStep = 0.1,
	TowerRadius = 3,
	PathHalfWidth = 6,
	CollectRadius = 6,
	Products = {
		Passes = {
			collector = { id = 0 }, training = { id = 0 },
			formations = { id = 0 }, vip = { id = 0 },
		},
		Consumables = {
			gold1000 = { id = 0 }, gold5000 = { id = 0 }, gold12000 = { id = 0 },
		},
	},
	-- Optional owned/licensed audio IDs. Zero keeps the experience silent.
	Audio = { lobby = 0, battle = 0, collect = 0, victory = 0, defeat = 0, breach = 0, place = 0, upgrade = 0, levelUp = 0, ability = 0, boss = 0, wave = 0, chest = 0 },
	-- Native Roblox client sounds; uploaded, configured IDs take precedence.
	-- Remove entries to mute fallbacks. Music still requires owned audio IDs.
	BuiltinCues = {
		collect = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.8},
		place = {path = "rbxasset://sounds/action_get_up.mp3", speed = 1.4},
		upgrade = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.35},
		levelUp = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.05},
		victory = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.2},
		defeat = {path = "rbxasset://sounds/volume_slider.ogg", speed = 0.6},
		breach = {path = "rbxasset://sounds/impact_explosion_03.mp3", speed = 0.85},
		ability = {path = "rbxasset://sounds/action_get_up.mp3", speed = 0.85},
		boss = {path = "rbxasset://sounds/impact_explosion_03.mp3", speed = 0.65},
		wave = {path = "rbxasset://sounds/volume_slider.ogg", speed = 0.9},
		chest = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.15},
	},
}
