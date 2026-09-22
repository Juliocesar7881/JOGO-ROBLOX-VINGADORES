-- Real Luau execution; these tests need no Roblox engine mocks.
local Catalog = require("../src/shared/Catalog")
local Rules = require("../src/shared/Rules")
local Waves = require("../src/shared/Waves")
local assertions = 0
local function check(condition, message)
	assertions += 1
	assert(condition, message)
end
local function equal(actual, expected, message)
	check(actual == expected, (message or "Mismatch") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local function approx(actual, expected, message)
	check(math.abs(actual - expected) < 0.000001, (message or "Approximate equality failed") .. ": " .. tostring(actual) .. " vs " .. tostring(expected))
end

--==============================================================================
-- Catalog shape
--==============================================================================
equal(#Catalog.HeroOrder, 24, "Roster size")
-- Shouted names keep their accents (string.upper alone produced "BAú LENDáRIO").
equal(Catalog.Upper("Baú Lendário"), "BAÚ LENDÁRIO", "Accent-aware uppercase")
equal(Catalog.Upper("Instalação da HYDRA"), "INSTALAÇÃO DA HYDRA", "Cedilla and tilde uppercase")
equal(Catalog.Upper("Nova Fotônica"), "NOVA FOTÔNICA", "Circumflex uppercase")
-- Plain finds: a Lua character class compares bytes, and every accented
-- UTF-8 letter shares its first byte with every other one.
for _, rarity in Catalog.RarityOrder do
	local shouted = Catalog.Upper(Catalog.Rarities[rarity].name.pt)
	for _, lower in { "á", "à", "â", "ã", "é", "ê", "í", "ó", "ô", "õ", "ú", "ç" } do
		check(not string.find(shouted, lower, 1, true), "No lowercase accent survives: " .. rarity .. " " .. shouted)
	end
end
equal(#Catalog.MapOrder, 5, "Campaign map count")
equal(#Catalog.EnemyOrder, 8, "Enemy families")
equal(#Catalog.BossOrder, 5, "Boss count")
equal(#Catalog.ModeOrder, 5, "Four modes plus training")
equal(#Catalog.PortalOrder, 4, "Four portals")
equal(#Catalog.AbilityOrder, 24, "One ability per hero")
check(Catalog.Modes.daily == nil and Catalog.Modes.bossrush == nil, "Daily challenge and boss rush are gone")
check(Catalog.Skills == nil and Catalog.Protocols == nil, "The old skill and protocol systems are gone")
for _, modeId in { "normal", "ranked", "cards" } do equal(Catalog.Modes[modeId].waves, 50, modeId .. " runs 50 waves") end
equal(Catalog.Modes.infinite.waves, 0, "Endless has no last wave")
check(Catalog.Modes.cards.cards == true, "Only the card mode offers cards")
check(not Catalog.Modes.normal.cards and not Catalog.Modes.ranked.cards and not Catalog.Modes.infinite.cards, "Other modes offer no cards")

local rarityCount = {}
local seenAbility = {}
for _, id in Catalog.HeroOrder do
	local hero = Catalog.Heroes[id]
	equal(hero.id, id, "Stable hero id")
	check(hero.name.pt and hero.name.en and hero.description.pt and hero.description.en and hero.role.pt and hero.role.en, "Localized hero " .. id)
	check(Catalog.Rarities[hero.rarity] ~= nil, "Hero has a known rarity: " .. id)
	rarityCount[hero.rarity] = (rarityCount[hero.rarity] or 0) + 1
	local ability = Catalog.Abilities[hero.ability]
	check(ability ~= nil, "Hero has an ability: " .. id)
	check(not seenAbility[hero.ability], "Abilities are not shared between heroes: " .. hero.ability)
	seenAbility[hero.ability] = true
	equal(#hero.branches, 2, "Two exclusive branches")
	for _, branch in hero.branches do check(type(branch.mods) == "table" and #branch.mods > 0, "Every branch changes something: " .. id) end
	local previous = 0
	for level = 1, 4 do
		local stats = Rules.TowerStats(hero, level)
		check(stats.damage > previous, "Upgrades increase base damage")
		check(stats.upgradeCost > 0 and stats.range > 0 and stats.interval > 0, "Valid tower economy and stats")
		previous = stats.damage
	end
	for branch = 1, 2 do
		local stats = Rules.TowerStats(hero, 5, branch)
		equal(stats.upgradeCost, 0, "Final upgrade ends progression")
		check(stats.damage > 0 and stats.splash >= 0 and stats.chain >= 1, "Valid final stats")
	end
	check(not pcall(function() Rules.TowerStats(hero, 5, 3) end), "Reject invalid specialization")
	-- Starters are free; everything else costs Robux in the premium shop.
	if hero.starter then
		check(Catalog.Products.Heroes[id] == nil, "Starters are never sold: " .. id)
	else
		local product = Catalog.Products.Heroes[id]
		check(product ~= nil, "A purchasable hero has a product: " .. id)
		equal(product.price, Catalog.Rarities[hero.rarity].robux, "Robux price follows rarity: " .. id)
		equal(product.id, 0, "Unconfigured hero products stay disabled: " .. id)
	end
end
equal(rarityCount.common, 4, "Commons"); equal(rarityCount.rare, 7, "Rares"); equal(rarityCount.epic, 7, "Epics")
equal(rarityCount.legendary, 4, "Legendaries"); equal(rarityCount.mythic, 2, "Mythics")
check(Catalog.Heroes.ironman.starter and Catalog.Heroes.hawkeye.starter, "Iron Man and Hawkeye are the starters")
local starters = 0
for _, id in Catalog.HeroOrder do if Catalog.Heroes[id].starter then starters += 1 end end
equal(starters, 2, "Exactly two starters")

-- Rarer heroes cost more Robux and more gold to improve.
for index = 2, #Catalog.RarityOrder do
	local lower, higher = Catalog.Rarities[Catalog.RarityOrder[index - 1]], Catalog.Rarities[Catalog.RarityOrder[index]]
	check(higher.robux > lower.robux, "Robux price rises with rarity")
	check(higher.abilityCost > lower.abilityCost, "Ability upgrades cost more for rarer heroes")
	check(higher.duplicate.gold > lower.duplicate.gold, "Duplicates of rarer heroes refund more")
end

-- Branch data reproduces the behaviour the game was balanced around.
equal(Rules.TowerStats("ironman", 5, 1).attack, "splash", "Iron Man missiles")
check(Rules.TowerStats("ironman", 5, 2).armorPierce > 0.5, "Iron Man laser")
check(Rules.TowerStats("hawkeye", 5, 2).bossDamage > 0.5, "Hawkeye boss specialization")
check(Rules.TowerStats("spiderman", 5, 1).splash > Rules.TowerStats("spiderman", 5, 2).splash, "Web area branch")
check(Rules.TowerStats("widow", 5, 2).mark > Rules.TowerStats("widow", 5, 1).mark, "Widow marking branch")
check(Rules.TowerStats("captain", 5, 2).supportBoost > 0.1, "Captain support branch")
check(Rules.TowerStats("hulk", 5, 2).armorShred > 0, "Hulk armor break")
check(Rules.TowerStats("panther", 5, 2).armorShred > 0.2, "Panther support shred")
check(Rules.TowerStats("panther", 1).armorShred > 0, "Panther shreds armor from level one")
check(Rules.TowerStats("thor", 5, 1).chain > Rules.TowerStats("thor", 5, 2).chain, "Thor chain branch")
check(Rules.TowerStats("antman", 5, 1).periodicSplash < Rules.TowerStats("antman", 5, 2).periodicSplash, "Ant-Man stomp frequency")
check(Rules.TowerStats("vision", 5, 1).beamWidth > 3, "Vision piercing width")
check(Rules.TowerStats("wanda", 5, 2).dotDuration > Rules.TowerStats("wanda", 5, 1).dotDuration, "Wanda persistent damage")
check(Rules.TowerStats("strange", 5, 1).portal, "Strange spatial branch")
-- New heroes behave the way their branches say.
equal(Rules.TowerStats("wasp", 5, 1).attack, "chain", "Wasp swarm chains")
check(Rules.TowerStats("wasp", 5, 2).slow > Rules.TowerStats("wasp", 1).slow, "Wasp sting slows harder")
equal(Rules.TowerStats("starlord", 5, 2).attack, "splash", "Star-Lord grenades explode")
check(Rules.TowerStats("starlord", 5, 1).interval < Rules.TowerStats("starlord", 5, 2).interval, "Star-Lord twin blasters fire faster")
check(Rules.TowerStats("captainmarvel", 5, 1).beamWidth == 8, "Captain Marvel pulse widens the beam")
check(Rules.TowerStats("silversurfer", 5, 1).chain == 10, "Silver Surfer wave chains widely")
check(Rules.TowerStats("ghostrider", 5, 1).splash == 13, "Ghost Rider flames spread")
check(Rules.TowerStats("daredevil", 1).reveal and Rules.TowerStats("widow", 1).reveal, "Reveal heroes reveal")

for level = 1, 50 do
	equal(Rules.LevelFromXP(Rules.LevelXP(level)), level, "Account threshold inclusive")
	if level > 1 then equal(Rules.LevelFromXP(Rules.LevelXP(level) - 1), level - 1, "Account threshold boundary") end
	equal(Rules.TalentPointsEarned(level), level - 1, "One talent point per level after the first")
end
for level = 1, 20 do
	equal(Rules.MasteryLevel(Rules.MasteryXP(level)), level, "Mastery threshold inclusive")
	if level > 1 then equal(Rules.MasteryLevel(Rules.MasteryXP(level) - 1), level - 1, "Mastery threshold boundary") end
end
equal(Rules.LevelFromXP(1e10), 50, "Account cap")
equal(Rules.MasteryLevel(1e10), 20, "Mastery cap")
equal(Rules.LevelFromXP(0 / 0), 1, "Reject NaN experience")
equal(Rules.LevelFromXP(-40), 1, "Nonnegative experience")
check(not Rules.IsFinite(math.huge), "Reject infinite numbers")
for size, limit in { 16, 12, 10, 8 } do equal(Rules.TowerLimit(size), limit, "Per-player tower cap") end

-- Permanent bonuses are capped no matter how much progression stacks up.
local maxed = Rules.PermanentModifiers({ heroes = { ironman = { xp = 1e9 } }, talents = { towerPower = 5, reach = 5 } }, "ironman")
approx(maxed.damageBonus, 0.15, "Permanent damage cap")
approx(maxed.rangeBonus, 0.088, "Maxed talents plus mastery stay under the range cap")
check(maxed.attackSpeedBonus <= 0.10, "Permanent attack speed cap")
-- The caps are a safety net: even impossible input cannot break them.
local hostile = Rules.PermanentModifiers({ heroes = { ironman = { xp = 1e12 } }, talents = { towerPower = 500, reach = 500 } }, "ironman")
approx(hostile.damageBonus, 0.15, "Damage cap holds against hostile input")
approx(hostile.rangeBonus, 0.10, "Range cap holds against hostile input")
check(hostile.attackSpeedBonus <= 0.10, "Attack speed cap holds against hostile input")
local rookie = Rules.PermanentModifiers({ heroes = { ironman = { xp = 0 } }, talents = {} }, "ironman")
approx(rookie.damageBonus, 0, "A fresh hero has no permanent bonus")
local stats = Rules.TowerStats("ironman", 1, nil, { damageBonus = 0.2, rangeBonus = 0.1, attackSpeedBonus = 0.25 })
approx(stats.damage, Catalog.Heroes.ironman.damage * 1.2, "Fractional damage modifier")
approx(stats.range, Catalog.Heroes.ironman.range * 1.1, "Fractional range modifier")
approx(stats.interval, Catalog.Heroes.ironman.interval / 1.25, "Attack speed divides interval")
approx(Rules.TowerStats("ironman", 1, nil, { airDamageBonus = 0.25 }).airDamage, 0, "Unrelated modifiers do not leak")
approx(Rules.TowerStats("ironman", 1, nil, { airDamage = 0.25 }).airDamage, 0.25, "Air damage passes through")

--==============================================================================
-- Unlocks, portals and the random map
--==============================================================================
local profile = { tutorialComplete = false, campaign = {} }
check(Rules.CanStart(profile, "manhattan", "tutorial"), "Training always available")
check(not Rules.CanStart(profile, "gamma", "tutorial"), "Training map fixed")
check(Rules.CanStart(profile, "manhattan", "normal"), "Campaign is available immediately")
profile.tutorialComplete = true
for _, mapId in Catalog.MapOrder do check(Rules.CanStart(profile, mapId, "normal"), "Every map can be drawn for the campaign: " .. mapId) end
check(not Rules.CanStart(profile, "manhattan", "ranked"), "Hard requires a normal clear")
check(not Rules.CanStart(profile, "manhattan", "cards"), "Cards require a normal clear")
check(not Rules.CanStart(profile, "manhattan", "infinite"), "Endless requires a ranked clear")
profile.campaign.gamma = { normal = true }
check(Rules.CanStart(profile, "wakanda", "ranked"), "Any map's normal clear opens ranked everywhere")
check(Rules.CanStart(profile, "hydra", "cards"), "Any map's normal clear opens cards everywhere")
check(not Rules.CanStart(profile, "manhattan", "infinite"), "A normal clear does not open endless")
profile.campaign.latveria = { ranked = true }
check(Rules.CanStart(profile, "manhattan", "infinite"), "A ranked clear opens endless")
check(not Rules.CanStart(profile, "invalid", "normal"), "Unknown maps rejected")
check(not Rules.CanStart(profile, "manhattan", "daily"), "The removed daily mode cannot start")
check(not Rules.CanStart(profile, "manhattan", "bossrush"), "The removed boss rush cannot start")

do
	local gate = { tutorialComplete = false, campaign = {} }
	check(Rules.ModeUnlocked(gate, "tutorial"), "Portal gate: training is open to a newcomer")
	for _, modeId in { "ranked", "cards", "infinite" } do check(not Rules.ModeUnlocked(gate, modeId), "Portal gate: " .. modeId .. " needs training") end
	gate.tutorialComplete = true
	check(Rules.ModeUnlocked(gate, "normal"), "Portal gate: campaign opens after training")
	check(not Rules.ModeUnlocked(gate, "ranked") and not Rules.ModeUnlocked(gate, "cards"), "Portal gate: ranked and cards need a normal clear")
	gate.campaign.manhattan = { normal = true }
	check(Rules.ModeUnlocked(gate, "ranked") and Rules.ModeUnlocked(gate, "cards"), "Portal gate: ranked and cards open after any clear")
	check(not Rules.ModeUnlocked(gate, "infinite"), "Portal gate: endless still needs a ranked clear")
	gate.campaign.hydra = { ranked = true }
	check(Rules.ModeUnlocked(gate, "infinite"), "Portal gate: endless opens after a ranked clear")
	check(not Rules.ModeUnlocked(gate, "invalid"), "Portal gate: unknown modes stay locked")
	check(not Rules.ModeUnlocked(nil, "normal"), "Portal gate: missing profile stays locked")
	check(not Rules.ModeUnlocked({ tutorialComplete = true, campaign = "corrupt" }, "ranked"), "A damaged campaign record locks instead of crashing")
end

equal(Rules.PortalMode({ tutorialComplete = false }, "normal"), "normal", "Campaign always launches 50 waves")
equal(Rules.PortalMode({ tutorialComplete = false }, "ranked"), "ranked", "Only the campaign portal redirects to training")
equal(Rules.PortalMode({ tutorialComplete = true }, "normal"), "normal", "Trained commanders get the campaign")
for _, modeId in Catalog.PortalOrder do
	check(string.find(Rules.ModeLockReason(modeId), " / ", 1, true) ~= nil, "Localized lock reason for " .. modeId)
	check(type(Rules.ModeLockReason(modeId, { tutorialComplete = false })) == "string", "Missing unlock is explained for " .. modeId)
end

-- The map is drawn, never chosen, and every map is reachable.
equal(Rules.PickMap("tutorial", 0.9), "manhattan", "Training is always Manhattan")
local drawn = {}
for step = 0, 999 do drawn[Rules.PickMap("normal", step / 1000)] = (drawn[Rules.PickMap("normal", step / 1000)] or 0) + 1 end
for _, mapId in Catalog.MapOrder do equal(drawn[mapId], 200, "The draw is even across maps: " .. mapId) end
check(Catalog.Maps[Rules.PickMap("normal", 1)] ~= nil and Catalog.Maps[Rules.PickMap("normal", -3)] ~= nil, "Out-of-range rolls still land on a map")
check(Catalog.Maps[Rules.PickMap("normal", 0 / 0)] ~= nil, "A NaN roll still lands on a map")

--==============================================================================
-- Bosses and waves
--==============================================================================
for wave = 1, 60 do
	local boss = wave % 10 == 0
	equal(Rules.IsBossWave("normal", wave), boss, "Boss on every tenth wave: " .. wave)
	check(not Rules.IsBossWave("tutorial", wave), "Training has no scheduled boss")
end
equal(Rules.BossId(10), "lizard", "Wave 10 boss"); equal(Rules.BossId(20), "abomination", "Wave 20 boss")
equal(Rules.BossId(30), "redskull", "Wave 30 boss"); equal(Rules.BossId(40), "killmonger", "Wave 40 boss")
equal(Rules.BossId(50), "doom", "Wave 50 boss is Doctor Doom"); equal(Rules.BossId(60), "lizard", "Endless keeps cycling the bosses")
check(Rules.IsFinalWave("normal", 50) and not Rules.IsFinalWave("normal", 40), "Wave 50 is the final wave")
check(not Rules.IsFinalWave("infinite", 50), "Endless has no final wave")

for _, mapId in Catalog.MapOrder do
	local map = Catalog.Maps[mapId]
	for _, path in map.paths do
		check(#path >= 3, "Map has a navigable path")
		for index = 2, #path do
			check(path[index][1] ~= path[index-1][1] or path[index][2] ~= path[index-1][2], "No zero-length path segment")
		end
	end
	for _, modeId in Catalog.ModeOrder do
		local waves = if modeId == "infinite" then 70 else Rules.WaveCount(modeId)
		for partySize = 1, 4 do
			local totalGold = 0
			for wave = 1, waves do
				local specs = Waves.Generate(mapId, modeId, wave, partySize, 12345)
				check(#specs > 0 and #specs <= 180, "Wave bounded by active enemy budget")
				local waveGold, bosses = 0, 0
				for _, spec in specs do
					local enemy = Catalog.Enemies[spec.enemyId]
					check(enemy ~= nil, "Wave references a real enemy")
					check(spec.pathIndex >= 1 and spec.pathIndex <= #map.paths, "Valid path assignment")
					check(spec.hpMultiplier > 0 and Rules.IsFinite(spec.hpMultiplier), "Finite positive HP")
					check(spec.delay >= 0 and spec.gold >= 0 and spec.gold % 1 == 0, "Valid spawn timing and gold")
					if enemy.boss then bosses += 1 end
					if mapId == "hydra" then equal(spec.pathIndex, (wave - 1) % 2 + 1, "Announced alternating HYDRA path") end
					waveGold += spec.gold
				end
				equal(waveGold, Rules.RewardBudget(modeId, wave), "Integer reward conservation")
				local expectedBosses = if modeId == "tutorial" then (wave == 8 and 1 or 0) else (Rules.IsBossWave(modeId, wave) and 1 or 0)
				equal(bosses, expectedBosses, string.format("Exactly the scheduled bosses: %s %s wave %d", mapId, modeId, wave))
				totalGold += waveGold
			end
			if modeId == "normal" then equal(totalGold, 1400, "Normal gold budget independent of group size") end
			if modeId == "ranked" then equal(totalGold, 2200, "Hard gold budget") end
			if modeId == "cards" then equal(totalGold, 1800, "Card mode gold budget") end
			if modeId == "tutorial" then equal(totalGold, 0, "Tutorial receives one-time completion gold") end
			if modeId == "infinite" then equal(totalGold, 70 * 25 + 7 * 100, "Endless rewards") end
		end
	end
end
check(Rules.VictoryGold("normal") > 0 and Rules.VictoryGold("ranked") > Rules.VictoryGold("normal"), "Victory pays more on ranked")
equal(Rules.VictoryGold("tutorial"), 0, "Training pays its bonus elsewhere")

-- Every enemy family appears in a normal run, on every map, with no chapter gate.
do
	local seen = {}
	for wave = 1, 50 do
		for _, spec in Waves.Generate("manhattan", "normal", wave, 1, 7) do seen[spec.enemyId] = true end
	end
	for _, id in Catalog.EnemyOrder do check(seen[id], "Manhattan meets every family, including " .. id) end
	for _, id in Catalog.BossOrder do check(seen[id], "A normal run meets every boss, including " .. id) end
end

-- The final boss is the strongest thing in the run.
do
	local function bossHP(wave)
		for _, spec in Waves.Generate("gamma", "normal", wave, 1, 3) do
			local enemy = Catalog.Enemies[spec.enemyId]
			if enemy.boss then return enemy.hp * spec.hpMultiplier end
		end
	end
	local best = 0
	for _, wave in { 10, 20, 30, 40 } do best = math.max(best, bossHP(wave)) end
	check(bossHP(50) > best * 1.5, "The wave-50 boss towers over every earlier boss")
	check(bossHP(20) > bossHP(10) and bossHP(30) > bossHP(20) and bossHP(40) > bossHP(30), "Each boss is tougher than the one before")
end

local first = Waves.Generate("latveria", "ranked", 30, 4, 818)
local second = Waves.Generate("latveria", "ranked", 30, 4, 818)
equal(#first, #second, "Deterministic spawn count")
for index, spec in first do
	for key, value in spec do equal(second[index][key], value, "Deterministic wave specification") end
end
equal(#Waves.Generate("manhattan", "normal", 51, 1), 0, "Campaign terminates after 50")
equal(#Waves.Generate("manhattan", "cards", 51, 1), 0, "Card mode terminates after 50")
check(#Waves.Generate("manhattan", "infinite", 51, 1) > 0, "Endless keeps going")
local final = Waves.Generate("manhattan", "normal", 50, 1)
check(Catalog.Enemies[final[#final].enemyId].boss, "Final campaign boss")
local threats = Waves.Threats(final)
check(threats.boss and threats.air and threats.armor, "Upcoming wave warns about threats")
local solo = Waves.Generate("manhattan", "normal", 1, 1)
local squad = Waves.Generate("manhattan", "normal", 1, 4)
check(squad[1].hpMultiplier > solo[1].hpMultiplier, "Fixed-size cooperative difficulty")
check(Waves.Generate("manhattan", "ranked", 20, 1)[1].hpMultiplier > Waves.Generate("manhattan", "normal", 20, 1)[1].hpMultiplier, "Hard is harder")
check(not pcall(function() Waves.Generate("manhattan", "normal", 1, 0) end), "Reject invalid party size")
check(not pcall(function() Waves.Generate("manhattan", "normal", 0 / 0, 1) end), "Reject malformed wave")
-- The map changes the roads, not the difficulty.
equal(Waves.Generate("manhattan", "normal", 30, 1, 5)[1].hpMultiplier, Waves.Generate("latveria", "normal", 30, 1, 5)[1].hpMultiplier, "No map is secretly harder")

--==============================================================================
-- Hero abilities
--==============================================================================
local ranks = Catalog.AbilityRanks
equal(ranks.max, 5, "Five ability ranks")
equal(ranks.cost[1], 0, "Rank one is free")
for rank = 2, ranks.max do
	check(ranks.cost[rank] > ranks.cost[rank - 1], "Each rank costs more than the last")
	check(ranks.mastery[rank] > ranks.mastery[rank - 1], "Each rank needs more mastery than the last")
end
local KINDS = { blast = true, execute = true, rally = true, stun = true, slow = true, reveal = true, overdrive = true, chain = true, energy = true, pull = true, barrier = true, heal = true, weaken = true, burn = true, smite = true }
local kindsUsed = {}
for _, id in Catalog.AbilityOrder do
	local def = Catalog.Abilities[id]
	check(KINDS[def.kind], "Known ability kind: " .. id)
	kindsUsed[def.kind] = true
	check(def.target == "area" or def.target == "tower" or def.target == "self", "Known ability target: " .. id)
	check(def.cooldown >= 30 and def.cooldown <= 120, "Sane cooldown: " .. id)
	check(def.name.pt and def.name.en and def.description.pt and def.description.en, "Localized ability: " .. id)
	check(def.color and #def.color == 3, "Ability has a color: " .. id)
	if def.target == "area" then check((def.radius or 0) > 0, "Area abilities have a radius: " .. id) end
	local previous = Rules.AbilityStats(def, 1)
	for rank = 2, ranks.max do
		local current = Rules.AbilityStats(def, rank)
		check(current.cooldown < previous.cooldown, "Higher ranks recharge faster: " .. id)
		check(current.power >= previous.power and current.duration >= previous.duration and current.radius >= previous.radius, "Higher ranks are never weaker: " .. id)
		check((def.power and current.power > previous.power) or (def.duration and current.duration > previous.duration) or current.radius > previous.radius, "Every rank improves something: " .. id)
		previous = current
	end
	for _, language in { "pt", "en" } do
		for rank = 1, ranks.max do
			local text = Rules.AbilityText(def, rank, language)
			check(not string.find(text, "{", 1, true) and #text > 12, "Ability text has no unfilled placeholder: " .. id .. " " .. language)
		end
	end
end
for kind in KINDS do check(kindsUsed[kind], "Every ability kind is used by some hero: " .. kind) end
-- Ultimates: the rarest heroes carry several effects in one cast.
for _, id in Catalog.AbilityOrder do
	local def = Catalog.Abilities[id]
	for _, extra in def.extras or {} do check(KINDS[extra.kind], "Known extra kind: " .. id .. "/" .. tostring(extra.kind)) end
	local extras = Rules.AbilityExtras(def, 1)
	equal(#extras, #(def.extras or {}), "AbilityExtras returns one entry per extra: " .. id)
	if def.ultimate then check(#extras >= 1, "An ultimate has extras: " .. id) end
end
for _, heroId in Catalog.HeroOrder do
	local hero = Catalog.Heroes[heroId]
	if hero.rarity == "mythic" or hero.rarity == "legendary" then
		check(Catalog.Abilities[hero.ability].ultimate == true, "Legendary and mythic heroes own an ultimate: " .. heroId)
	end
end
do
	local nova = Catalog.Abilities.photonNova
	check(Rules.AbilityExtras(nova, 5)[1].duration > Rules.AbilityExtras(nova, 1)[1].duration, "Extras grow with the rank")
	check(Rules.AbilityExtras(nova, 1, { abilityPower = 0.5 })[2].power > Rules.AbilityExtras(nova, 1)[2].power, "Extras follow ability power")
	local text = Rules.AbilityText(nova, 1, "en")
	check(string.find(text, "stuns for 2.5 s", 1, true) ~= nil, "Extra numbers are printed in the description: " .. text)
end
-- Every hero's ability is reachable from that hero and the two stay in step.
for _, heroId in Catalog.HeroOrder do
	check(Catalog.Abilities[Catalog.Heroes[heroId].ability] ~= nil, "Ability resolves from " .. heroId)
end

do
	local def = Catalog.Abilities.repulsorBarrage
	local base = Rules.AbilityStats(def, 1)
	approx(base.power, 0.35, "Rank one power"); approx(base.cooldown, 55, "Rank one cooldown")
	approx(Rules.AbilityStats(def, 5).cooldown, 55 * 0.84, "Rank five cooldown")
	approx(Rules.AbilityStats(def, 5).power, 0.35 * 1.72, "Rank five power")
	approx(Rules.AbilityStats(def, 1, { abilityPower = 0.5 }).power, 0.35 * 1.5, "Ability power scales magnitude")
	approx(Rules.AbilityStats(def, 1, { cooldownReduction = 0.2 }).cooldown, 55 * 0.8, "Cooldown reduction shortens recharge")
	check(Rules.AbilityStats(def, 1, { cooldownReduction = 5 }).cooldown >= 55 * 0.6 - 0.0001, "Cooldown reduction is capped")
	equal(Rules.AbilityStats(def, 99).rank, 5, "Rank is clamped"); equal(Rules.AbilityStats(def, -3).rank, 1, "Rank floor")
	-- A stun has no magnitude, so ability power lengthens it instead.
	local stun = Catalog.Abilities.rootWall
	check(Rules.AbilityStats(stun, 1, { abilityPower = 0.5 }).duration > Rules.AbilityStats(stun, 1).duration, "Ability power extends a stun")
	equal(Rules.AbilityStats(Catalog.Abilities.thunderCall, 1).count, 10, "Chain count at rank one")
	equal(Rules.AbilityStats(Catalog.Abilities.thunderCall, 5).count, 12, "Chain count grows with rank")
	check(string.find(Rules.AbilityText(def, 1, "pt"), "35%", 1, true) ~= nil, "Description shows this rank's real number")
	check(string.find(Rules.AbilityText(def, 5, "pt"), "60%", 1, true) ~= nil, "Description follows the rank")
end

do
	local iron, myth = Catalog.Heroes.ironman, Catalog.Heroes.captainmarvel
	local first = Rules.AbilityUpgrade(iron, 1)
	equal(first.rank, 2, "Next rank"); equal(first.cost, 300, "Common rank two price"); equal(first.mastery, 3, "Mastery gate")
	equal(Rules.AbilityUpgrade(iron, 4).cost, 3000, "Common rank five price")
	equal(Rules.AbilityUpgrade(iron, 5), nil, "A maxed ability has no next rank")
	check(Rules.AbilityUpgrade(myth, 1).cost > first.cost, "The same rank costs more on a mythic hero")
	equal(Rules.AbilityUpgrade(myth, 1).cost, math.floor(300 * 4.5 + 0.5), "Rarity multiplies the price")
	equal(Rules.AbilityUpgrade("thor", 2).cost, math.floor(700 * 3 + 0.5), "Heroes can be named by id")
end

--==============================================================================
-- Chests
--==============================================================================
for _, chestId in Catalog.ChestOrder do
	local chest = Catalog.Chests[chestId]
	local total = 0
	for _, rarity in Catalog.RarityOrder do total += chest.odds[rarity] or 0 end
	equal(total, 100, chestId .. " odds sum to 100")
	for rarity in chest.odds do check(Catalog.Rarities[rarity] ~= nil, "Known rarity in " .. chestId .. " odds") end
end
equal(Catalog.Chests.legendary.cost, Catalog.Chests.rare.cost * 2, "The rare chest costs half of the legendary chest")
check(Catalog.Chests.rare.odds.mythic == 0 and Catalog.Chests.rare.odds.legendary <= 2, "The rare chest barely holds a top hero")
check(Catalog.Chests.legendary.odds.common == 0, "The legendary chest never wastes a common")
-- The best heroes come from the legendary chest, and the best of them are the rarest.
check(Catalog.Chests.legendary.odds.legendary > Catalog.Chests.rare.odds.legendary, "Legendaries are far likelier in the legendary chest")
check(Catalog.Chests.legendary.odds.mythic > Catalog.Chests.rare.odds.mythic, "Only the legendary chest holds mythics")
local ordered = { "rare", "epic", "legendary", "mythic" }
check(Catalog.Chests.legendary.odds.epic > Catalog.Chests.legendary.odds.legendary and Catalog.Chests.legendary.odds.legendary > Catalog.Chests.legendary.odds.mythic,
	"Inside the legendary chest, better rarities are less likely")
check(Catalog.Chests.rare.odds.rare > Catalog.Chests.rare.odds.epic and Catalog.Chests.rare.odds.epic > Catalog.Chests.rare.odds.legendary, "Inside the rare chest, better rarities are less likely")

-- Chest pools never contain a starter, and cover every other hero exactly once.
do
	local covered = {}
	for _, rarity in Catalog.RarityOrder do
		for _, id in Rules.ChestPool(rarity) do
			check(not Catalog.Heroes[id].starter, "No starter in a chest pool")
			check(not covered[id], "A hero sits in one pool only")
			covered[id] = true
		end
	end
	for _, id in Catalog.HeroOrder do
		check(covered[id] or Catalog.Heroes[id].starter, "Every non-starter can be won from a chest: " .. id)
	end
end

-- Deterministic edges of the draw.
do
	local low = Rules.RollChest("legendary", 0, 0, 0, {})
	equal(low.rarity, "rare", "The lowest roll in the legendary chest is a rare")
	local high = Rules.RollChest("legendary", 0.999999, 0, 0, {})
	equal(high.rarity, "mythic", "The highest roll in the legendary chest is a mythic")
	local rareLow = Rules.RollChest("rare", 0, 0, 0, {})
	equal(rareLow.rarity, "common", "The lowest roll in the rare chest is a common")
	check(Catalog.Heroes[rareLow.heroId].rarity == "common" and not Catalog.Heroes[rareLow.heroId].starter, "A common draw is a chestable common")
	for _, roll in { 0, 0.25, 0.5, 0.75, 0.999999, -1, 2, 0 / 0 } do
		local result = Rules.RollChest("rare", roll, roll, 0, {})
		check(Catalog.Heroes[result.heroId] ~= nil, "A hostile roll still resolves to a hero")
	end
	check(not pcall(function() Rules.RollChest("nope", 0.5, 0.5, 0, {}) end), "Unknown chests are rejected")
end

-- The published odds are what actually happens: 200,000 seeded openings per chest.
do
	local state = 987654321
	local function roll()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	for _, chestId in Catalog.ChestOrder do
		local counts, trials = {}, 200000
		for _ = 1, trials do
			local result = Rules.RollChest(chestId, roll(), roll(), 0, {})
			counts[result.rarity] = (counts[result.rarity] or 0) + 1
		end
		for _, rarity in Catalog.RarityOrder do
			local expected = Catalog.Chests[chestId].odds[rarity] or 0
			local actual = (counts[rarity] or 0) / trials * 100
			check(math.abs(actual - expected) < 0.6, string.format("%s chest %s rate is %.2f%%, published %d%%", chestId, rarity, actual, expected))
		end
	end
end

-- Duplicates: a chest prefers something new, and only repeats once that rarity is complete.
do
	local ownedAllEpics = {}
	for _, id in Rules.ChestPool("epic") do ownedAllEpics[id] = true end
	local pool = Rules.ChestPool("epic")
	local missing = pool[3]
	ownedAllEpics[missing] = nil
	for step = 0, 99 do
		local result = Rules.RollChest("legendary", 0.65, step / 100, 0, ownedAllEpics)
		equal(result.rarity, "epic", "Fixture rolls an epic")
		equal(result.heroId, missing, "The one missing epic is always the one delivered")
		check(not result.duplicate, "A new hero is not a duplicate")
	end
	ownedAllEpics[missing] = true
	local dupe = Rules.RollChest("legendary", 0.65, 0.4, 0, ownedAllEpics)
	check(dupe.duplicate, "A completed rarity yields a duplicate")
	check(Catalog.Heroes[dupe.heroId].rarity == "epic", "The duplicate still keeps its rarity")
end

-- Pity: the tenth legendary chest without a top hero is guaranteed to be one.
do
	local chest = Catalog.Chests.legendary
	equal(chest.pity.after, 10, "Pity threshold")
	for step = 0, 99 do
		local result = Rules.RollChest("legendary", step / 100, 0.5, chest.pity.after - 1, {})
		check(result.rarity == "legendary" or result.rarity == "mythic", "Pity guarantees a legendary or better")
		check(result.pity and result.top, "The result reports the pity")
	end
	local normal = Rules.RollChest("legendary", 0.05, 0.5, chest.pity.after - 2, {})
	check(not normal.pity, "Pity is not triggered early")
	local mythics = 0
	for step = 0, 999 do
		if Rules.RollChest("legendary", step / 1000, 0.5, chest.pity.after - 1, {}).rarity == "mythic" then mythics += 1 end
	end
	check(mythics > 0 and mythics < 300, "A pity opening keeps mythic the rarest outcome")
	check(Catalog.Chests.rare.pity == nil, "The rare chest has no pity")
end

--==============================================================================
-- Cards
--==============================================================================
equal(#Catalog.CardOrder, 23, "Card count")
for _, id in Catalog.CardOrder do
	local card = Catalog.Cards[id]
	equal(card.id, id, "Stable card id")
	check(card.name.pt and card.name.en and card.description.pt and card.description.en, "Localized card " .. id)
	check(Catalog.CardRarityWeight[card.rarity] ~= nil and card.maxStacks >= 1, "Valid rarity and stack limit: " .. id)
	check((card.effects ~= nil) ~= (card.instant ~= nil), "A card is either a stat change or an instant: " .. id)
end
for wave = 1, 60 do
	local expected = wave % 5 == 0 and wave < 50
	equal(Rules.CardWave("cards", wave), expected, "Cards after every fifth wave until the boss: " .. wave)
	check(not Rules.CardWave("normal", wave) and not Rules.CardWave("ranked", wave) and not Rules.CardWave("tutorial", wave), "Only the card mode offers cards")
end
check(Rules.CardWave("cards", 45) and not Rules.CardWave("cards", 50), "Nine picks per run, none before the final boss")

do
	local owned = {}
	local picks = 0
	for wave = 5, 45, 5 do
		local offers = Rules.CardOffers(542, wave, 1, owned)
		equal(#offers, 3, "Three card choices")
		local unique = {}
		for _, id in offers do check(not unique[id], "No duplicate offered card"); unique[id] = true end
		equal(table.concat(offers, ","), table.concat(Rules.CardOffers(542, wave, 1, owned), ","), "A reconnect sees the same offer")
		table.insert(owned, offers[1])
		picks += 1
	end
	equal(picks, 9, "Nine picks per run")
	check(table.concat(Rules.CardOffers(542, 5, 1, {}), ",") ~= table.concat(Rules.CardOffers(542, 5, 2, {}), ","), "Teammates are offered different cards")
	-- Stack limits remove a card from the offer once it is maxed out.
	local maxedOut = {}
	for _, id in Catalog.CardOrder do for _ = 1, Catalog.Cards[id].maxStacks do table.insert(maxedOut, id) end end
	equal(#Rules.CardOffers(1, 25, 1, maxedOut), 0, "A fully stacked deck offers nothing")
	local nearly = {}
	for _, id in Catalog.CardOrder do if id ~= "warChest" then for _ = 1, Catalog.Cards[id].maxStacks do table.insert(nearly, id) end end end
	local last = Rules.CardOffers(1, 25, 1, nearly)
	equal(#last, 1, "Exhausted cards are excluded"); equal(last[1], "warChest", "The last card standing is offered")
end

-- Offers follow the rarity weights: commons are far likelier than epics.
do
	local counts = { common = 0, rare = 0, epic = 0 }
	for seed = 1, 3000 do
		for _, id in Rules.CardOffers(seed, 10, 1, {}) do counts[Catalog.Cards[id].rarity] += 1 end
	end
	check(counts.common > counts.rare and counts.rare > counts.epic, "Card rarity weighting favours the common cards")
	check(counts.epic > 0, "Epic cards do appear")
end

do
	local totals = Rules.CardTotals({ "sharpen", "sharpen", "glassCannon", "supplyDrop" })
	approx(totals.damage, 0.10 + 0.10 + 0.35, "Card damage stacks")
	approx(totals.range, -0.15, "A card can cost you something")
	equal(totals.energy, nil, "Instant cards add no stat")
	equal(next(Rules.CardTotals({})), nil, "No cards, no effects")
	equal(next(Rules.CardTotals({ "notACard" })), nil, "Unknown cards are ignored")
end

--==============================================================================
-- Talents
--==============================================================================
local seenTalent = {}
for _, branch in Catalog.TalentBranches do
	for index, id in ipairs(branch.nodes) do
		local node = Catalog.Talents[id]
		check(node ~= nil, "Talent exists: " .. id)
		check(not seenTalent[id], "A talent sits in one branch: " .. id)
		seenTalent[id] = true
		check(node.name.pt and node.name.en and node.description.pt and node.description.en, "Localized talent: " .. id)
		if index == 1 then check(node.parent == nil, "A branch starts with a free node: " .. id)
		else equal(node.parent, branch.nodes[index - 1], "Nodes chain in order: " .. id) end
		if node.parent then check(node.requiredRank >= 1 and node.requiredRank <= Catalog.Talents[node.parent].maxRank, "A reachable prerequisite: " .. id) end
	end
end
for id in Catalog.Talents do check(seenTalent[id], "Every talent belongs to a branch: " .. id) end
do
	local total = 0
	for id, node in Catalog.Talents do total += node.maxRank end
	check(total > Rules.TalentPointsEarned(50), "Not every talent can be maxed: choices matter")
end

for _, product in Catalog.Products.Passes do equal(product.id, 0, "Unconfigured passes disabled") end
for _, product in Catalog.Products.Consumables do equal(product.id, 0, "Unconfigured products disabled") end

--==============================================================================
-- Rewards: free chest, login streak, playtime gifts, collection milestones
--==============================================================================
-- PlayerService's own spec exercises these end to end against mocked
-- DataStores; these are the pure-function cases, which run in milliseconds
-- and pin down the exact day-boundary arithmetic without a fake clock.
local DAY = 86400
equal(Rules.UtcDay(0), 0, "Day zero is the epoch's own day")
equal(Rules.UtcDay(DAY - 1), 0, "One second before the boundary is still day zero")
equal(Rules.UtcDay(DAY), 1, "The boundary itself starts the next day")
equal(Rules.UtcDay(DAY * 30 + 1), 30, "Days accumulate exactly")

do
	local fresh = Rules.NewRewardsState()
	equal(fresh.loginDay, -1, "A fresh reward state has never logged in")
	equal(fresh.freeChestAt, 0, "A fresh free chest is immediately ready")
	local seconds, claimed = Rules.PlaytimeToday(fresh, 12345)
	equal(seconds, 0, "A fresh state has played no time today")
	equal(next(claimed), nil, "A fresh state has claimed no gift")
end

do
	-- Playtime resets when the stored day differs from now's day, regardless
	-- of how much time or which gifts were logged for the old day.
	local state = { playDay = 5, playSeconds = 900, playClaimed = { [1] = true, [3] = true } }
	local seconds, claimed = Rules.PlaytimeToday(state, 5 * DAY + 100)
	equal(seconds, 900, "Same-day playtime is returned as stored")
	check(claimed[1] and claimed[3], "Same-day claims are returned as stored")
	local staleSeconds, staleClaimed = Rules.PlaytimeToday(state, 6 * DAY + 1)
	equal(staleSeconds, 0, "A new day resets playtime to zero")
	equal(next(staleClaimed), nil, "A new day resets claimed gifts")
end

do
	local cycle = #Catalog.Rewards.login
	-- Never logged in: always claimable, always starts the cycle at day one.
	local first = Rules.LoginClaim(Rules.NewRewardsState(), 100 * DAY)
	check(first ~= nil, "A fresh account can claim today")
	equal(first.streak, 1, "The first claim starts a streak of one")
	equal(first.index, 1, "The first claim is day one of the cycle")
	equal(first.reward, Catalog.Rewards.login[1], "The first claim's reward is the cycle's first entry")

	-- Already claimed today: nothing to claim.
	equal(Rules.LoginClaim({ loginDay = 10, loginStreak = 3 }, 10 * DAY + 500), nil, "Today's claim cannot repeat")

	-- Consecutive day: streak continues.
	local consecutive = Rules.LoginClaim({ loginDay = 10, loginStreak = 4 }, 11 * DAY)
	equal(consecutive.streak, 5, "A consecutive day extends the streak")
	equal(consecutive.index, 5, "The index tracks the streak while under one cycle")

	-- Exactly at the grace boundary (loginGraceDays): still forgiven.
	local grace = Rules.LoginClaim({ loginDay = 10, loginStreak = 4 }, (10 + Catalog.Rewards.loginGraceDays) * DAY)
	equal(grace.streak, 5, "A gap of exactly the grace period still continues the streak")

	-- One day past the grace boundary: streak resets to one.
	local expired = Rules.LoginClaim({ loginDay = 10, loginStreak = 4 }, (10 + Catalog.Rewards.loginGraceDays + 1) * DAY)
	equal(expired.streak, 1, "A gap past the grace period resets the streak")
	equal(expired.index, 1, "A reset streak restarts the cycle at day one")

	-- The cycle wraps: streak keeps counting, index loops back to one.
	local wrapped = Rules.LoginClaim({ loginDay = 10, loginStreak = cycle }, 11 * DAY)
	equal(wrapped.streak, cycle + 1, "The streak keeps counting past one full cycle")
	equal(wrapped.index, 1, "The reward index wraps back to day one")
end

do
	-- RewardsStatus assembles all four loops from one state; check the shape
	-- and that "claimable" really counts what the four sub-sections report ready.
	local state = Rules.NewRewardsState()
	local profile = { rewards = state, heroes = { ironman = true, hawkeye = true } }
	local status = Rules.RewardsStatus(profile, 50 * DAY, 0)
	check(status.freeChest.ready and status.login.claimable, "A fresh profile has its free chest and login ready")
	equal(#status.playtime.gifts, #Catalog.Rewards.playtime, "One playtime entry per configured gift")
	equal(#status.collection.milestones, #Catalog.Rewards.collection, "One collection entry per configured milestone")
	for _, gift in status.playtime.gifts do check(not gift.ready, "No playtime gift is ready with zero seconds played: " .. gift.index) end
	for _, milestone in status.collection.milestones do check(not milestone.ready, "No milestone is ready with two heroes: " .. milestone.index) end
	equal(status.claimable, 2, "Only the free chest and the login are claimable on a fresh profile")

	-- Playtime seconds come from pendingSeconds when the stored day matches now.
	local todayState = { freeChestAt = 51 * DAY, loginDay = 50, loginStreak = 1, playDay = 50, playSeconds = 100, playClaimed = {}, collection = {} }
	local minutes = Catalog.Rewards.playtime[1].minutes
	local mid = Rules.RewardsStatus({ rewards = todayState, heroes = {} }, 50 * DAY + 500, minutes * 60 - 100 - 1)
	check(not mid.playtime.gifts[1].ready, "One second short of a gift is not ready")
	local ready = Rules.RewardsStatus({ rewards = todayState, heroes = {} }, 50 * DAY + 500, minutes * 60 - 100)
	check(ready.playtime.gifts[1].ready, "Reaching a gift's exact minute makes it ready")

	-- Collection milestones ready exactly at their threshold, not before.
	local justUnder = {}
	for index = 1, Catalog.Rewards.collection[1].count - 1 do justUnder["hero" .. index] = true end
	local underStatus = Rules.RewardsStatus({ rewards = Rules.NewRewardsState(), heroes = justUnder }, 0, 0)
	check(not underStatus.collection.milestones[1].ready, "One hero short of a milestone is not ready")
	justUnder["hero" .. Catalog.Rewards.collection[1].count] = true
	local atStatus = Rules.RewardsStatus({ rewards = Rules.NewRewardsState(), heroes = justUnder }, 0, 0)
	check(atStatus.collection.milestones[1].ready, "Reaching a milestone's exact count makes it ready")
end

print("PASS " .. assertions .. " assertions: catalog, heroes, abilities, chests and odds, cards, talents, unlocks, random map, 50-wave bosses, wave economy on every map/mode/party size, daily rewards")
