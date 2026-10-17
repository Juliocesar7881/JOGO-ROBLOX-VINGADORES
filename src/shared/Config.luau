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
	-- One published place, two kinds of server (Rules.PlaceRole): public
	-- servers are lobbies and each battle runs in a reserved server of the same
	-- place, so a lobby never waits for another group's battle to end.
	SinglePlace = true,
	LobbyPlaceId = 0,
	MatchPlaceId = 0,
	-- Optional light AFK place (0 = AFK stays in the lobby chambers).
	AfkPlaceId = 0,
	-- Roblox badges (Creator Hub > Engagement > Badges, created 2026-10-15),
	-- awarded by the server once the profile that earns them is saved
	-- (Rules.EarnedBadges). 0 turns one off.
	Badges = {
		tutorial = 2496029722635949, firstWin = 4403390299371408, firstBoss = 2901295397250104,
		collector = 1329107087739180, fearless = 2993058614693693,
	},
	-- Optional Roblox group for the one-time join-the-group reward. 0 hides it.
	GroupId = 0,
	MaxPartySize = 4,
	-- Text-free, authored comic art. Sources, prompts and delivery hashes:
	-- assets/ui/illustrated/manifest.json. IDs are set only after Studio upload.
	UiArt = {window=117794482905127,button=91879736431596,icons=76122046230704,observatory=93095245078402,chests=137153627143583,card=77752406707285,launch=113377652302568,afk=126038966446275},
	-- The heroes' armour block and its painted finish (tools/gen_armor_assets.py,
	-- uploaded through Studio's 3D importer). 0 keeps the classic chamfered blocks.
	-- Signature patterns (tools/gen_hero_textures.py): the Surfer's galaxy cape,
	-- the Rider's flames, the Mystic's runes; armour finishes: web, scales, circuit,
	-- tiger stripes (Figure HERO_FINISH). 0 leaves the piece plain.
	Art = { armorMesh = 117802835003514, armorTexture = 117812857455019, galaxy = 98885280567335, flames = 111186421217436, runes = 118425714210399,
		web = 99334513899048, scales = 117029856228705, circuit = 104273646071216, tiger = 91303391426074,
		-- Ornate armour (tools/gen_ornate_assets.py): domed pauldron and chest filigree.
		padMesh = 113935066525487, padTexture = 102954478036198, filigree = 132068800303676 },
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
			-- Five passes enabled in the official Creator Hub (2026-10-12).
			collector = { id = 2004326420 }, training = { id = 2001722936 },
			vip = { id = 2003954466 }, speed3 = { id = 2001776936 }, season = { id = 2026575250 },
		},
		Consumables = {
			gold1000 = { id = 3715833438 }, gold5000 = { id = 3715833690 }, gold12000 = { id = 3715833842 }, gold30000 = { id = 3715833975 },
			starterPack = { id = 3715833256 },
			-- Created in the official Creator Hub on 2026-10-14 (Managed Pricing on).
			goldBoost = { id = 3718674787 }, seasonPass = { id = 3718674866 }, legendaryBundle = { id = 3718674909 }, teamBundle = { id = 3718675077 },
		},
		-- All 41 direct hero products registered in the official Creator Hub.
		-- Two starter heroes remain free; receipts use these stable IDs.
		Heroes = {
			seaking = { id = 3718187883 },
			captainmarvel = { id = 3718187847 },
			emerald = { id = 3718187811 },
			groot = { id = 3718187771 },
			iceman = { id = 3718187741 },
			wolverine = { id = 3718187710 },
			moonknight = { id = 3718187669 },
			strange = { id = 3718187623 },
			nova = { id = 3718187579 },
			nightcrawler = { id = 3718187550 },
			solartitan = { id = 3718186894 },
			capmen = { id = 3718186861 },
			nightstalker = { id = 3718186834 },
			gambit = { id = 3718186805 },
			beast = { id = 3718186763 },
			wanda = { id = 3718186734 },
			speedster = { id = 3718186702 },
			thor = { id = 3718186668 },
			ghostrider = { id = 3718186629 },
			psylocke = { id = 3718186588 },
			silversurfer = { id = 3718186558 },
			cyclops = { id = 3718186531 },
			storm = { id = 3718186499 },
			jean = { id = 3718186464 },
			deadpool = { id = 3718186419 },
			amazon = { id = 3718184374 },
			falcon = { id = 3715834320 }, bucky = { id = 3715834397 },
			spiderman = { id = 3715834470 }, widow = { id = 3715834541 }, antman = { id = 3715834624 },
			wasp = { id = 3715834861 }, rocket = { id = 3715834932 }, daredevil = { id = 3715835002 }, shangchi = { id = 3715835053 },
			captain = { id = 3715835121 }, panther = { id = 3715835190 }, hulk = { id = 3715835244 },
			vision = { id = 3715835303 }, warmachine = { id = 3715835379 }, starlord = { id = 3715835477 },
		},
	},
	-- Optional owned/licensed audio IDs. Zero keeps the experience silent.
	-- The project's own synthesized sounds (assets/audio, tools/generate_audio.py),
	-- uploaded 2026-10-02 by LoopsDev7881 through Studio's Asset Manager. Sources and
	-- IDs: assets/audio/uploads.json. A zero falls back to the built-in sounds.
	Audio = {
		battle = 138426860300125, collect = 89386392576030, victory = 85206381307425, defeat = 89940652537869,
		breach = 88806730855390, place = 110695275250497, upgrade = 123473912601268, levelUp = 87307736942781, ability = 106314680284413,
		boss = 78255398419469, wave = 75814374915023, chest = 121229565044752,
		-- The lobby's music since 16/10 (the owner's pick): "Marlboro Lite" by
		-- Spazz Cardigan, a YouTube Audio Library track marked Creative Commons
		-- Attribution (CC BY 3.0), prepared by tools/prepare_music.py and credited
		-- in Options like the battle tracks. Uploaded to the owner's account on
		-- 16/10 (Creator Hub). Before it: "Electrodoodle" by Kevin MacLeod
		-- (96735553222959, 15/10).
		lobby = 124459741137134,
		-- One battle track per map: licensed Creative Commons BY music prepared by
		-- tools/prepare_music.py (credits: assets/audio/music_credits.json and
		-- Catalog.MusicCredits, shown in Options). 0 = that map plays `battle`.
		-- Uploaded to the owner's account on 15/10 (Creator Hub, moderation applies).
		-- Manhattan, Wakanda and Asgard were uploaded again the same day with Kevin
		-- MacLeod tracks: moderation rejected their first ones.
		battleManhattan = 126920682041461, battleGamma = 131099793893363, battleHydra = 123106203425536,
		battleWakanda = 114624051816618, battleLatveria = 94715672061348, battleAsgard = 91724157195350,
		-- One ambience loop per map, and a short cue per weapon family.
		ambManhattan = 132352626399475, ambGamma = 101885347333293, ambHydra = 134964091158105,
		ambWakanda = 109955783634978, ambAsgard = 107103621057466, ambLatveria = 131878071679857,
		shotTech = 113181820392283, shotArrow = 78755893231166, shotMagic = 116245675467513, shotMelee = 79230559057938,
		shotBlast = 108098929987722, abilityReady = 116839098197325,
		-- Interface: every button press and every panel opening.
		click = 74693654931748, open = 78745367903334,
		-- Prepared in assets/audio/summon. Zero uses the live owned-sample mix;
		-- replace only after uploading and granting this experience access.
		reelStart = 0, reelTick = 0,
		rewardCommon = 0, rewardRare = 0, rewardEpic = 0, rewardLegendary = 0, rewardMythic = 0,
		-- Seven private Sonniss atlases. Timings live in client/SoundBank.luau.
		-- Uploaded through the official place's Asset Manager on 2026-10-10.
		sfxUi = 85369475902522, sfxEvents = 75724766927443, sfxSummon = 78967956683172, sfxCombat = 106008096538276,
		sfxPowers = 85187270766836, sfxBoss = 88205770181304, sfxWorld = 140273603492577,
	},
	-- Enable each dedicated material cue only AFTER its refined WAV is uploaded
	-- and Audio[name] contains the real ID. Empty keeps the quieter live remix.
	-- Sources/instructions: assets/audio/refined/README.md.
	DirectAudioCues = {},
	-- Real map photographs, uploaded by LoopsDev7881 via Studio's Asset Manager.
	-- Sources and upload IDs: assets/map-photos/manifest.json. Zero uses the fallback.
	MapImages = {
		-- manhattan = 0: its photo showed third-party storefront names; the
		-- drawn diorama stands in until a clean photo is uploaded.
		manhattan = 0, gamma = 132922675966302,
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
