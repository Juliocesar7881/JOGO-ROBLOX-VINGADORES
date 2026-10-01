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
			-- Created in the Creator Hub by the director (2026-10-01). The VIP
			-- pass exists but its price still has to be switched on there.
			collector = { id = 2004326420 }, training = { id = 2001722936 },
			vip = { id = 2003954466 }, speed3 = { id = 2001776936 },
		},
		Consumables = {
			gold1000 = { id = 3715833438 }, gold5000 = { id = 3715833690 }, gold12000 = { id = 3715833842 }, gold30000 = { id = 3715833975 },
			starterPack = { id = 3715833256 },
		},
		-- One developer product per purchasable hero (Creator Hub, 2026-10-01).
		-- Heroes without an id here are not on sale yet.
		Heroes = {
			falcon = { id = 3715834320 }, bucky = { id = 3715834397 },
			spiderman = { id = 3715834470 }, widow = { id = 3715834541 }, antman = { id = 3715834624 },
			wasp = { id = 3715834861 }, rocket = { id = 3715834932 }, daredevil = { id = 3715835002 }, shangchi = { id = 3715835053 },
			captain = { id = 3715835121 }, panther = { id = 3715835190 }, hulk = { id = 3715835244 },
			vision = { id = 3715835303 }, warmachine = { id = 3715835379 }, starlord = { id = 3715835477 },
		},
	},
	-- Optional owned/licensed audio IDs. Zero keeps the experience silent.
	Audio = { lobby = 0, battle = 0, collect = 0, victory = 0, defeat = 0, breach = 0, place = 0, upgrade = 0, levelUp = 0, ability = 0, boss = 0, wave = 0, chest = 0,
		-- One ambience loop per map, and a short cue per weapon family.
		ambManhattan = 0, ambGamma = 0, ambHydra = 0, ambWakanda = 0, ambAsgard = 0, ambLatveria = 0,
		shotTech = 0, shotArrow = 0, shotMagic = 0, shotMelee = 0, shotBlast = 0, abilityReady = 0,
		-- Interface: every button press and every panel opening.
		click = 0, open = 0 },
	-- Real map photographs, uploaded by LoopsDev7881 via Studio's Asset Manager.
	-- Sources and upload IDs: assets/map-photos/manifest.json. Zero uses the fallback.
	MapImages = {
		manhattan = 106232571755279, gamma = 132922675966302,
		hydra = 77531885765033, wakanda = 83315123182560,
		asgard = 81125412205211, latveria = 124835578394292,
	},
	-- Native Roblox client sounds; uploaded, configured IDs take precedence.
	-- Remove entries to mute fallbacks. Music still requires owned audio IDs.
	-- A cue with notes plays a short jingle: each note is a built-in sample
	-- at a pitch (speed) and a time (at, seconds), tuned to a major scale.
	BuiltinCues = {
		click = {path = "rbxasset://sounds/volume_slider.ogg", speed = 2.2},
		open = {path = "rbxasset://sounds/action_get_up.mp3", speed = 1.7},
		collect = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.8},
		place = {path = "rbxasset://sounds/action_jump_land.mp3", speed = 1.2, notes = { { path = "rbxasset://sounds/action_jump_land.mp3", at = 0, speed = 1.2 }, { at = 0.03, speed = 2.247, volume = 0.6 } }},
		upgrade = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.5, notes = { { at = 0, speed = 1.5 }, { at = 0.06, speed = 2.247 }, { at = 0.12, speed = 3.0, volume = 1.1 } }},
		levelUp = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.5, notes = { { at = 0, speed = 1.5 }, { at = 0.07, speed = 1.89 }, { at = 0.14, speed = 2.247 }, { at = 0.21, speed = 3.0 }, { at = 0.3, speed = 3.78, volume = 1.2 } }},
		victory = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.5, notes = { { at = 0, speed = 1.5 }, { at = 0.1, speed = 1.89 }, { at = 0.2, speed = 2.247 }, { at = 0.3, speed = 3.0, volume = 1.1 }, { at = 0.46, speed = 3.78, volume = 1.1 }, { at = 0.46, speed = 4.495, volume = 0.8 }, { path = "rbxasset://sounds/impact_explosion_03.mp3", at = 0.3, speed = 0.9, volume = 0.45 } }},
		defeat = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.648, notes = { { at = 0, speed = 1.648 }, { at = 0.2, speed = 1.386 }, { at = 0.4, speed = 1.1 }, { at = 0.62, speed = 0.824, volume = 1.1 } }},
		breach = {path = "rbxasset://sounds/impact_explosion_03.mp3", speed = 0.85},
		ability = {path = "rbxasset://sounds/action_get_up.mp3", speed = 0.85},
		boss = {path = "rbxasset://sounds/impact_explosion_03.mp3", speed = 0.5, notes = { { path = "rbxasset://sounds/impact_explosion_03.mp3", at = 0, speed = 0.5 }, { path = "rbxasset://sounds/impact_explosion_03.mp3", at = 0.28, speed = 0.42, volume = 0.8 }, { at = 0.1, speed = 0.6, volume = 0.8 } }},
		wave = {path = "rbxasset://sounds/action_get_up.mp3", speed = 0.8, notes = { { path = "rbxasset://sounds/action_get_up.mp3", at = 0, speed = 0.8 }, { path = "rbxasset://sounds/impact_explosion_03.mp3", at = 0.05, speed = 0.6, volume = 0.6 } }},
		chest = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.5, notes = { { at = 0, speed = 1.5 }, { at = 0.07, speed = 1.89 }, { at = 0.14, speed = 2.247 }, { path = "rbxasset://sounds/impact_explosion_03.mp3", at = 0, speed = 1.7, volume = 0.5 } }},
		abilityReady = {path = "rbxasset://sounds/volume_slider.ogg", speed = 3.0, notes = { { at = 0, speed = 3.0 }, { at = 0.08, speed = 4.495 } }},
		shotTech = {path = "rbxasset://sounds/volume_slider.ogg", speed = 2.4},
		shotArrow = {path = "rbxasset://sounds/action_get_up.mp3", speed = 2.2},
		shotMagic = {path = "rbxasset://sounds/volume_slider.ogg", speed = 1.9},
		shotMelee = {path = "rbxasset://sounds/impact_explosion_03.mp3", speed = 1.7},
		shotBlast = {path = "rbxasset://sounds/impact_explosion_03.mp3", speed = 1.15},
	},
}
