-- Change deployment IDs only after creating both places in YOUR universe.
return {
	Version = "0.1.0",
	BalanceVersion = "2026.4",
	DataStoreName = "DoomsdayProfiles_v1",
	StudioMemory = true, -- Never used outside Studio. Studio profiles are temporary.
	ProfileLeaseSeconds = 180,
	AutoSaveSeconds = 45,
	ProfileRetries = 3,
	SeasonEpoch = 1789862400, -- 2026-09-20 UTC
	SeasonDays = 60,
	LobbyPlaceId = 0,
	MatchPlaceId = 0,
	-- Optional light AFK place (0 = AFK stays in the lobby chambers).
	AfkPlaceId = 0,
	-- Optional Roblox group for the one-time join-the-group reward. 0 hides it.
	GroupId = 0,
	MaxPartySize = 4,
	BaseHP = 100,
	-- Match Gold each commander starts a run with (enemies drop the rest).
	StartCash = 600,
	PreparationSeconds = 10,
	ReconnectSeconds = 120,
	MaxEnemies = 180,
	MaxCoinPiles = 50,
	EnemySyncInterval = 0.2,
	SnapshotInterval = 0.5,
	SimulationStep = 0.1,
	TowerRadius = 3,
	PathHalfWidth = 6,
	-- Base magnet reach for match Gold on the ground; Magnetism widens it.
	CollectRadius = 8,
	Products = {
		Passes = {
			collector = { id = 0 }, training = { id = 0 },
			vip = { id = 0 },
		},
		Consumables = {
			gold1000 = { id = 0 }, gold5000 = { id = 0 }, gold12000 = { id = 0 },
		},
	},
	-- Optional owned/licensed audio IDs. Zero keeps the experience silent.
	Audio = { lobby = 0, battle = 0, collect = 0, victory = 0, defeat = 0, breach = 0, place = 0, upgrade = 0, levelUp = 0, ability = 0, boss = 0, wave = 0, chest = 0,
		-- One ambience loop per map, and a short cue per weapon family.
		ambManhattan = 0, ambGamma = 0, ambHydra = 0, ambWakanda = 0, ambAsgard = 0, ambLatveria = 0,
		shotTech = 0, shotArrow = 0, shotMagic = 0, shotMelee = 0, shotBlast = 0, abilityReady = 0 },
	-- Optional portal-sign photographs of each map (assets/map-photos, imported
	-- in Studio's Asset Manager). Zero keeps the rendered 3D diorama.
	MapImages = { manhattan = 0, gamma = 0, hydra = 0, wakanda = 0, asgard = 0, latveria = 0 },
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
		abilityReady = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.5},
		shotTech = {path = "rbxasset://sounds/volume_slider.ogg", speed = 2.4},
		shotArrow = {path = "rbxasset://sounds/action_get_up.mp3", speed = 2.2},
		shotMagic = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.9},
		shotMelee = {path = "rbxasset://sounds/impact_explosion_03.mp3", speed = 1.7},
		shotBlast = {path = "rbxasset://sounds/impact_explosion_03.mp3", speed = 1.15},
	},
}
