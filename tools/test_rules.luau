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

require("../tests/rarity_compatibility")(check,equal,approx)
require("../tests/next_goal")(check,equal)

--==============================================================================
-- Catalog shape
--==============================================================================
equal(#Catalog.HeroOrder, 43, "Roster size")
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
equal(#Catalog.MapOrder, 6, "Campaign map count")
equal(#Catalog.EnemyOrder, 25, "Enemy families")
equal(#Catalog.BossOrder, 6, "Six bosses: one per map, Loki for Asgard")
equal(#Catalog.ModeOrder, 4, "Campaign, competitive and cards plus training")
equal(#Catalog.PortalOrder, 4, "Four kinds of portal")
equal(#Catalog.AbilityOrder, 43, "One ability per hero")
check(Catalog.Modes.daily == nil and Catalog.Modes.bossrush == nil, "Daily challenge and boss rush are gone")
check(Catalog.Modes.infinite == nil and Catalog.Modes.hard == nil, "The casual endless and hard modes are gone")
check(Catalog.Skills == nil and Catalog.Protocols == nil, "The old skill and protocol systems are gone")
equal(Catalog.Modes.tutorial.waves, 6, "Training runs 6 waves (a short first session)")
equal(Catalog.Modes.cards.waves, 50, "Cards run 50 waves")
equal(Catalog.Modes.ranked.waves, 0, "Competitive is endless")
for mapId, waves in { manhattan = 40, gamma = 50, hydra = 50, wakanda = 50, asgard = 50, latveria = 70 } do
	equal(Rules.WaveCount("normal", mapId), waves, "Campaign length on " .. mapId)
end
equal(Rules.WaveCount("ranked", "hydra"), 0, "Competitive never ends")
equal(Catalog.Maps.asgard.bossId, "loki", "Asgard's final boss is Loki")
check(Catalog.Modes.cards.cards == true, "Only the card mode offers cards")
check(not Catalog.Modes.normal.cards and not Catalog.Modes.ranked.cards and not Catalog.Modes.tutorial.cards, "Other modes offer no cards")

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
		check(product.price > 0 and product.rarity==hero.rarity, "Explicit existing price and current rarity: " .. id)
		equal(product.id, 0, "Unconfigured hero products stay disabled: " .. id)
	end
end
equal(rarityCount.common, 16, "Commons"); equal(rarityCount.rare, 15, "Rares")
equal(rarityCount.legendary, 12, "Legendaries")
check(Catalog.Heroes.ironman.starter and Catalog.Heroes.hawkeye.starter, "Iron Man and Hawkeye are the starters")
local starters = 0
for _, id in Catalog.HeroOrder do if Catalog.Heroes[id].starter then starters += 1 end end
equal(starters, 2, "Exactly two starters")

-- Economy is per hero; merging collectible colours must not rebalance combat.
for _,id in ipairs(Catalog.HeroOrder) do check(Catalog.Heroes[id].economy.abilityCost>0,"Explicit hero economy: "..id) end
-- Every hero hits ground and flying enemies (owner, 16/10), at every level.
for _,id in ipairs(Catalog.HeroOrder) do
	check(Catalog.Heroes[id].air==true and Rules.TowerStats(id,1).air==true and Rules.TowerStats(id,5,2).air==true,"Hits flyers too: "..id)
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

for level = 1, Rules.MaxLevel do
	equal(Rules.LevelFromXP(Rules.LevelXP(level)), level, "Account threshold inclusive")
	if level > 1 then equal(Rules.LevelFromXP(Rules.LevelXP(level) - 1), level - 1, "Account threshold boundary") end
	equal(Rules.TalentPointsEarned(level), level - 1, "One talent point per level after the first")
end
for level = 1, 20 do
	equal(Rules.MasteryLevel(Rules.MasteryXP(level)), level, "Mastery threshold inclusive")
	if level > 1 then equal(Rules.MasteryLevel(Rules.MasteryXP(level) - 1), level - 1, "Mastery threshold boundary") end
end
equal(Rules.MaxLevel, 100, "The account levels up to 100 (six-branch talent tree)")
equal(Rules.LevelFromXP(1e10), Rules.MaxLevel, "Account cap")
equal(Rules.MasteryLevel(1e10), 20, "Mastery cap")
equal(Rules.LevelFromXP(0 / 0), 1, "Reject NaN experience")
equal(Rules.LevelFromXP(-40), 1, "Nonnegative experience")
check(not Rules.IsFinite(math.huge), "Reject infinite numbers")
for size = 1, 4 do equal(Rules.TowerLimit(size), Rules.SafetyTowerCeiling, "Towers are only capped by the anti-flood ceiling") end
check(Rules.SafetyTowerCeiling >= 100, "the anti-flood ceiling is far above anything Gold can buy")
equal(Rules.HeroLimit("ironman"), Rules.SafetyTowerCeiling, "copies of a hero are not limited")

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
-- Wave mutations: rare, deterministic, never in training, before wave 6 or on a boss wave.
do
	local mutated, total, kinds = 0, 0, {}
	for seed = 20000, 20019 do
		for wave = 1, 50 do
			local id = Rules.WaveMutation("normal", "manhattan", wave, seed)
			equal(id, Rules.WaveMutation("normal", "manhattan", wave, seed), "A mutation is deterministic")
			if id then
				check(Catalog.Mutations[id] ~= nil, "A mutation names a real kind: " .. id)
				check(wave >= 6 and not Rules.IsBossWave("normal", wave, "manhattan"), "Never before wave 6 or on a boss wave: " .. wave)
				mutated += 1
				kinds[id] = true
			end
			if wave >= 6 and not Rules.IsBossWave("normal", wave, "manhattan") then total += 1 end
			equal(Rules.WaveMutation("tutorial", "manhattan", wave, seed), nil, "Training is never mutated")
		end
	end
	check(mutated / total > 0.15 and mutated / total < 0.35, "About one wave in four is mutated, got " .. mutated .. "/" .. total)
	for _, id in ipairs(Catalog.MutationOrder) do check(kinds[id], "Every kind turns up: " .. id) end
	for _, id in ipairs(Catalog.MutationOrder) do
		local def = Catalog.Mutations[id]
		check(def.name.pt and def.name.en and def.description.pt and def.description.en and def.icon, "A mutation is named and described in both languages: " .. id)
	end
end

-- The map of the day: every campaign map takes its turn, only normal mode benefits.
do
	local normals = Rules.MapsForMode("normal")
	local seen = {}
	for day = 20000, 20000 + #normals - 1 do seen[Rules.FeaturedMap(day)] = (seen[Rules.FeaturedMap(day)] or 0) + 1 end
	for _, mapId in ipairs(normals) do equal(seen[mapId], 1, "Every campaign map is featured once per cycle: " .. mapId) end
	equal(Rules.FeaturedMap(20000), Rules.FeaturedMap(20000 + #normals), "The cycle repeats")
	local today = Rules.FeaturedMap(20123)
	approx(Rules.FeaturedBonus(today, "normal", 20123), 1 + Catalog.DailyFeature.bonus, "The featured map pays more")
	equal(Rules.FeaturedBonus(today, "ranked", 20123), 1, "Only the campaign benefits")
	equal(Rules.FeaturedBonus("nowhere", "normal", 20123), 1, "Other maps pay as usual")
	equal(Rules.FeaturedMap(0 / 0), nil, "A bad day names no map")
end

-- Party bonus: each extra commander adds the same share, from 1 to 4, no more.
approx(Rules.PartyBonus(1), 1, "Playing alone has no party bonus")
approx(Rules.PartyBonus(3), 1 + 2 * Catalog.PartyBonus.perPlayer, "A party of three earns two shares")
approx(Rules.PartyBonus(4), 1 + 3 * Catalog.PartyBonus.perPlayer, "A party of four earns three shares")
approx(Rules.PartyBonus(40), Rules.PartyBonus(4), "The bonus stops at four players")
approx(Rules.PartyBonus(0 / 0), 1, "A bad size is no bonus")

-- Stars: each adds damage on top of the mastery/talent cap, and they cap too.
local starred = Rules.PermanentModifiers({ heroes = { ironman = { xp = 0, stars = 3 } }, talents = {} }, "ironman")
approx(starred.damageBonus, 3 * Catalog.Stars.damage, "Three stars are +9% damage")
local allStars = Rules.PermanentModifiers({ heroes = { ironman = { xp = 1e9, stars = 99 } }, talents = { towerPower = 500 } }, "ironman")
approx(allStars.damageBonus, 0.15 + Catalog.Stars.max * Catalog.Stars.damage, "Stars are clamped to the maximum and add to the capped mastery bonus")
approx(Rules.PermanentModifiers({ heroes = { ironman = { xp = 0, stars = -4 } }, talents = {} }, "ironman").damageBonus, 0, "A negative star count is no bonus")
-- Hero cards: the ladder has no top, the stats it adds do.
local carded = Rules.CardBonus(1000, { damage = 400, speed = 300, range = 299 })
approx(carded.damage, Catalog.HeroCards.cap.damage, "A thousand card ranks stop at the damage cap")
approx(carded.speed, Catalog.HeroCards.cap.speed, "A thousand card ranks stop at the speed cap")
approx(carded.range, Catalog.HeroCards.cap.range, "A thousand card ranks stop at the range cap")
check(Rules.CardBonus(2, nil).damage < Catalog.HeroCards.cap.damage, "An early rank is still under the cap")
approx(Rules.PermanentModifiers({ heroes = { ironman = { xp = 1e9, stars = 99, rank = 1000 } }, talents = { towerPower = 500 } }, "ironman").damageBonus,
	0.15 + Catalog.Stars.max * Catalog.Stars.damage + Catalog.HeroCards.cap.damage, "Every permanent source has a ceiling, and they add up to a known number")
equal(Rules.RunGold("normal", "manhattan", 40, true, "hard"), 2400, "Hard pays its 40-wave victory over: 1,600 x 1.5")
equal(Rules.RunGold("normal", "manhattan", 40, true, "nightmare"), 3200, "Nightmare pays double")
equal(Rules.RunGold("normal", "manhattan", 40, true, "normal"), 1600, "Normal pays the base")
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
check(Rules.CanStart(profile, "manhattan", "normal"), "Campaign is available immediately, training is only recommended")
for _, mapId in Catalog.MapOrder do check(Rules.CanStart(profile, mapId, "normal"), "Every map has a campaign: " .. mapId) end
equal(#Catalog.DestinationOrder, 11, "Six campaigns, three competitive, cards and training")
do
	local perMode, campaigns = {}, {}
	for _, id in Catalog.DestinationOrder do
		local def = Catalog.Destinations[id]
		check(def and Catalog.Maps[def.mapId] and Catalog.Modes[def.modeId], "Destination is a real map/mode pair: " .. id)
		check(({ center = true, expedition = true, arena = true, special = true })[def.district], "Destination belongs to a lobby district: " .. id)
		perMode[def.modeId] = (perMode[def.modeId] or 0) + 1
		if def.modeId == "normal" then campaigns[def.mapId] = (campaigns[def.mapId] or 0) + 1 end
	end
	equal(perMode.normal, 6, "Six campaign entrances"); equal(perMode.ranked, 3, "Three competitive entrances")
	equal(perMode.cards, 1, "One card entrance"); equal(perMode.tutorial, 1, "One training entrance")
	for _, mapId in Catalog.MapOrder do equal(campaigns[mapId], 1, "One campaign entrance per map: " .. mapId) end
end

-- One placement rule for the preview and the server, with a reason for every refusal.
do
	local config = { PathHalfWidth = 6, TowerRadius = 3 }
	local function at(x, z) return { X = x, Y = 0, Z = z } end
	-- Manhattan's first road runs along z = -80 from x = -92 (see its paths).
	local road = Catalog.Maps.manhattan.paths[1]
	local a, b = road[1], road[2]
	local mid = { (a[1] + b[1]) / 2, (a[2] + b[2]) / 2 }
	local ok, reason = Rules.BuildCheck("manhattan", at(mid[1], mid[2]), {}, config)
	check(not ok and reason == "path", "building on the road is refused as too close to the path")
	local function clearSpot()
		for x = -100, 100, 2 do
			for z = -100, 100, 2 do
				if Rules.BuildCheck("manhattan", at(x, z), {}, config) then return x, z end
			end
		end
	end
	local x, z = clearSpot()
	check(x ~= nil, "Manhattan has open ground")
	ok, reason = Rules.BuildCheck("manhattan", at(x, z), { at(x + 2, z) }, config)
	check(not ok and reason == "occupied", "a spot next to another tower is taken")
	check(Rules.BuildCheck("manhattan", at(x, z), { at(x + 6.01, z) }, config), "towers may stand two radii apart")
	ok, reason = Rules.BuildCheck("manhattan", at(x, z), {}, config, { { x = x + 5, z = z, r = 6.5 } })
	check(not ok and reason == "occupied", "a base or the core blocks building on it")
	ok, reason = Rules.BuildCheck("manhattan", at(Rules.BUILD_LIMIT + 0.5, 0), {}, config)
	check(not ok and reason == "bounds", "outside the build area is refused")
	check(not Rules.BuildCheck("manhattan", at(0 / 0, 0), {}, config), "a NaN position is refused")
	check(not Rules.BuildCheck("nowhere", at(x, z), {}, config), "an unknown map is refused")
	for _, key in { "bounds", "path", "occupied", "cash", "limit" } do
		check(Rules.BuildReasons[key] and Rules.BuildReasons[key].pt and Rules.BuildReasons[key].en, "every refusal has a bilingual reason: " .. key)
	end
end

-- Base chests: every base comes from exactly one chest, a chest draws only
-- its own bases and never an empty tier, and the two passives grow with the
-- level within their caps.
do
	local seen = {}
	for _, chestId in Catalog.BaseChestOrder do
		local chest = Catalog.Chests[chestId]
		check(chest.kind == "base" and #chest.bases >= 3, "a base chest has at least three bases of its own: " .. chestId)
		for _, group in chest.groups do
			check(group.weight == 0 or #group.items > 0, "a base chest never draws an empty tier: " .. chestId)
			for _, id in group.items do check(table.find(chest.bases, id) ~= nil, "a base chest draws only its own bases: " .. chestId .. "/" .. id) end
		end
		for _, id in chest.bases do
			check(Catalog.Bases[id] ~= nil and not Catalog.Bases[id].starter and seen[id] == nil, "each base is in one chest only: " .. id)
			seen[id] = chestId
		end
	end
	for _, id in Catalog.BaseOrder do
		check(Catalog.Bases[id].starter or seen[id] ~= nil, "every base can be found in a chest: " .. id)
		check(Catalog.Bases[id].description ~= nil, "every base style is described: " .. id)
	end
	local polar1, polar5 = Rules.BaseStats("polar", 1), Rules.BaseStats("polar", 5)
	check(polar1.chill > 0 and polar5.chill > polar1.chill and polar5.chill <= 0.4 and polar5.range > polar1.range, "the ice field grows with the level, capped")
	check(Rules.BaseChill(polar1, true) > 0 and Rules.BaseChill(polar1, true) < Rules.BaseChill(polar1, false), "a boss resists the ice field")
	check(Rules.BaseStats("outpost", 5).chill == 0 and Rules.BaseStats("outpost", 5).interest == 0, "other bases have neither passive")
	local vault1, vault5 = Rules.BaseStats("vault", 1), Rules.BaseStats("vault", 5)
	equal(Rules.BaseInterest(vault1, 500), math.floor(500 * vault1.interest), "the vault pays its rate on the Gold kept")
	check(Rules.BaseInterest(vault1, 1e9) == vault1.interestCap and vault5.interestCap > vault1.interestCap and vault5.interest > vault1.interest, "the interest has a cap that grows with the level")
	check(Rules.BaseInterest(vault1, -50) == 0 and Rules.BaseInterest(Rules.BaseStats("workshop", 3), 5000) == 0, "no interest on nothing, nor without a vault")
	-- Bounty bases: more match Gold per enemy, growing with the level, one at
	-- every rarity a player sees (the top one included).
	local seenBounty = {}
	for _, id in Catalog.BaseOrder do
		local def = Catalog.Bases[id]
		if def.style == "bounty" then
			local one, five = Rules.BaseStats(id, 1), Rules.BaseStats(id, 5)
			check(one.bounty > 0 and five.bounty > one.bounty, "a bounty base pays more per enemy as it levels: " .. id)
			seenBounty[def.rarity] = true
		else
			check(Rules.BaseStats(id, 5).bounty == 0, "only bounty bases pay per enemy: " .. id)
		end
	end
	for _, rarity in Catalog.RarityOrder do check(seenBounty[rarity], "a bounty base at every rarity: " .. rarity) end
end

-- Guaranteed purchase for restricted accounts: priced at the expected chest cost.
do
	local cheapest = math.huge
	for _, chest in pairs(Catalog.Chests) do cheapest = math.min(cheapest, chest.cost) end
	for _, id in Catalog.HeroOrder do
		local price = Rules.GuaranteedPrice(id)
		check(price ~= nil and price % 50 == 0 and price >= cheapest, "every hero has a guaranteed price at least a chest's: " .. id)
	end
	for _, id in Catalog.BaseOrder do
		local price = Rules.GuaranteedPrice(id)
		check(price == nil or price >= cheapest, "a base's guaranteed price is never below a chest: " .. id)
	end
	local byRarity = {}
	for _, id in Catalog.HeroOrder do
		local rarity = Catalog.Heroes[id].rarity
		byRarity[rarity] = math.max(byRarity[rarity] or 0, Rules.GuaranteedPrice(id))
	end
	check(byRarity.legendary > byRarity.rare and byRarity.rare > byRarity.common, "rarer hero groups cost more to guarantee")
	check(Rules.GuaranteedPrice("nobody") == nil, "unknown items have no price")
	-- The day's market: one hero per rarity, never a starter, the same for everyone that day, new the next.
	local today = Rules.DailyMarket(20740)
	check(#today.offers == #Catalog.Market.rarities and today.renewsAt == 20741 * 86400, "the market has one offer per rarity and renews at midnight UTC")
	for index, offer in ipairs(today.offers) do
		local hero = Catalog.Heroes[offer.heroId]
		check(hero ~= nil and hero.rarity == Catalog.Market.rarities[index] and not hero.starter, "offer " .. index .. " is a non-starter hero of its rarity")
		check(offer.price == Rules.MarketPrice(offer.heroId) and offer.price % 50 == 0 and offer.price < Rules.GuaranteedPrice(offer.heroId) and offer.price >= cheapest, "an offer costs less than the guarantee, more than a chest, in steps of 50")
	end
	check(Rules.DailyMarket(20740).offers[1].heroId == today.offers[1].heroId, "the same day gives the same market")
	local differs = false
	for day = 20741, 20760 do if Rules.DailyMarket(day).offers[1].heroId ~= today.offers[1].heroId then differs = true end end
	check(differs, "the market changes from day to day")
	check(Rules.MarketPrice("nobody") == nil, "an unknown hero has no market price")
	-- The quick session: the first 20 waves of any campaign map, never a campaign victory.
	check(Rules.WaveCount("quick", "latveria") == 20 and Rules.WaveCount("quick", "manhattan") == 20, "the quick session is 20 waves on every map")
	check(Rules.ModeUnlocked({}, "quick"), "the quick session is open to everyone")
	for _, id in ipairs(Catalog.DestinationOrder) do
		local def = Catalog.Destinations[id]
		local quickOk = Rules.CanStart({}, def.mapId, "quick")
		if def.modeId == "normal" then check(quickOk, "the quick session plays on campaign map " .. def.mapId) end
	end
	check(not Rules.CanStart({}, "nowhere", "quick"), "the quick session needs a real map")
	check(Rules.IsFinalWave("quick", 20, "gamma") and Rules.BossId(20, "gamma", "quick") == Catalog.Maps.gamma.bossId, "the quick session ends with the map's own boss")
	check(Rules.RunGold("quick", "manhattan", 20, true) == 800 and Rules.RunGold("normal", "manhattan", 40, true) == 1600, "a quick win pays the campaign's rate for its 20 waves")
	check(not Rules.CanUseDifficulty({}, "manhattan", "quick", "hard") and Rules.CanUseDifficulty({}, "manhattan", "quick", "normal"), "the quick session plays at Normal only")
	local quickSpecs = Waves.Generate("manhattan", "quick", 20, 1, 7)
	local quickBoss = false
	for _, spec in ipairs(quickSpecs) do if spec.enemyId == Catalog.Maps.manhattan.bossId then quickBoss = true end end
	check(quickBoss and #Waves.Generate("manhattan", "quick", 21, 1, 7) == 0, "quick waves end at 20 with the map's boss")
	-- Codes from Experience Configs: only well-formed entries become codes.
	local configCodes, refusedCodes = Rules.ConfigCodes({
		video1 = { gold = 300, chest = "rare", expires = 1798761600 }, XP = { xp = 10 },
		LOTS = { gold = 99999 }, ODD = { gold = 10, title = "x" }, NOCHEST = { chest = "platinum" }, EMPTY = {},
		["two words"] = { gold = 5 }, ZERO = { gold = 0 }, FRACTION = { gold = 1.5 },
	})
	check(configCodes.VIDEO1 ~= nil and configCodes.VIDEO1.gold == 300 and configCodes.VIDEO1.chest == "rare" and configCodes.VIDEO1.expires == 1798761600, "a config code is read in capitals with its reward")
	check(configCodes.XP == nil and configCodes.LOTS == nil and configCodes.ODD == nil and configCodes.NOCHEST == nil and configCodes.EMPTY == nil and configCodes.ZERO == nil and configCodes.FRACTION == nil, "short, oversized, unknown, empty or broken config codes are refused")
	check(#refusedCodes == 8 and table.find(refusedCodes, "two words") ~= nil, "every refused config code is named for the warning")
	check(next((Rules.ConfigCodes(nil))) == nil and next((Rules.ConfigCodes("codes"))) == nil, "a missing or non-table config gives no codes")
	-- Badges follow the saved profile.
	local function has(list, key) return table.find(list, key) ~= nil end
	check(#Rules.EarnedBadges({}) == 0 and #Rules.EarnedBadges(nil) == 0, "a fresh or missing profile earns no badge")
	local badged = { tutorialComplete = true, campaign = { gamma = { normal = true } }, stats = { bosses = 2 }, heroes = {}, achievements = { hardWin = { name = "x" } } }
	for index = 1, Rules.BadgeCollection do badged.heroes["h" .. index] = {} end
	local all = Rules.EarnedBadges(badged)
	check(has(all, "tutorial") and has(all, "firstWin") and has(all, "firstBoss") and has(all, "collector") and has(all, "fearless"), "every badge condition is read off the profile")
	badged.heroes.h1 = nil
	check(not has(Rules.EarnedBadges(badged), "collector"), "the collector badge needs the full count")
	-- Server roles. One place: public servers are lobbies, reserved ones are battles.
	local PLACE = 97132875544830
	local single = { SinglePlace = true, LobbyPlaceId = 0, MatchPlaceId = 0, AfkPlaceId = 0 }
	local lobbyRole = Rules.PlaceRole({ studio = false, placeId = PLACE, privateServerId = "", privateServerOwnerId = 0, builtRole = "Standalone" }, single)
	check(lobbyRole.role == "Lobby" and lobbyRole.travel and lobbyRole.single and lobbyRole.lobbyPlaceId == PLACE and lobbyRole.matchPlaceId == PLACE, "a public server of the single place is a lobby that travels to its own place")
	local matchRole = Rules.PlaceRole({ studio = false, placeId = PLACE, privateServerId = "abc", privateServerOwnerId = 0, builtRole = "Standalone" }, single)
	check(matchRole.role == "Match" and matchRole.travel, "a reserved server of the single place is a battle server")
	check(Rules.PlaceRole({ studio = false, placeId = PLACE, privateServerId = "abc", privateServerOwnerId = 77, builtRole = "Standalone" }, single).role == "Lobby", "an owner's private server is a lobby, not a battle")
	check(Rules.PlaceRole({ studio = true, placeId = PLACE, privateServerId = "", builtRole = "Standalone" }, single).role == "Standalone", "Studio stays self-contained: teleports never work in a playtest")
	check(Rules.PlaceRole({ studio = false, placeId = 0, privateServerId = "", builtRole = "Standalone" }, single).role == "Standalone", "an unpublished place stays self-contained")
	check(not lobbyRole.afkTravel and Rules.PlaceRole({ studio = false, placeId = PLACE, privateServerId = "" }, { SinglePlace = true, AfkPlaceId = 55 }).afkTravel == false, "the single place keeps AFK in the lobby chambers")
	-- Separate places keep the stamped role; studio and missing IDs fall back.
	local separate = { SinglePlace = false, LobbyPlaceId = 1, MatchPlaceId = 2, AfkPlaceId = 0 }
	check(Rules.PlaceRole({ studio = false, placeId = 2, builtRole = "Match" }, separate).role == "Match" and Rules.PlaceRole({ studio = false, placeId = 1, builtRole = "Lobby" }, separate).role == "Lobby", "separate places keep their built roles")
	check(Rules.PlaceRole({ studio = false, placeId = 1, builtRole = "Lobby" }, { LobbyPlaceId = 1, MatchPlaceId = 0 }).role == "Standalone", "without a battle place a lobby build runs self-contained")
	check(Rules.PlaceRole({ studio = false, placeId = 9, privateServerId = "" }, { SinglePlace = true, LobbyPlaceId = 1, MatchPlaceId = 2 }).single == false, "configured separate places win over SinglePlace")
	-- The weekend event: Saturday and Sunday UTC, one campaign map paying over; the next one is announced in between.
	local saturday, sunday, monday = Rules.WeekendEvent(2 * 86400), Rules.WeekendEvent(3 * 86400 + 100), Rules.WeekendEvent(4 * 86400)
	check(saturday.active and sunday.active and not monday.active, "the event runs Saturday and Sunday")
	check(saturday.mapId == sunday.mapId and saturday.startsAt == 2 * 86400 and saturday.endsAt == 4 * 86400, "both days share one map and the event ends Monday 00:00 UTC")
	check(monday.startsAt == 9 * 86400 and monday.mapId == Rules.WeekendEvent(9 * 86400).mapId, "a weekday announces next Saturday's event and its map")
	check(Rules.EventBonus(saturday.mapId, "normal", 2 * 86400) == Catalog.Events.weekend.goldScale and Rules.EventBonus(saturday.mapId, "ranked", 2 * 86400) == 1 and Rules.EventBonus(saturday.mapId, "normal", 4 * 86400) == 1, "only the event map in campaign mode, only on the weekend, pays the event Gold")
	check(Catalog.Maps[saturday.mapId] ~= nil and saturday.name ~= nil, "the event names a real map and a theme")
	-- Four weeks of login prizes, ending in a legendary hero of the player's choice.
	check(#Catalog.Rewards.login == 28 and Catalog.Rewards.login[28].heroPick == "legendary", "the login cycle is 28 days and ends in a legendary pick")
	for index, prize in ipairs(Catalog.Rewards.login) do
		check(prize.gold > 0 and (prize.chest == nil or Catalog.Chests[prize.chest] ~= nil) and (prize.heroPick == nil or Catalog.Rarities[prize.heroPick] ~= nil), "login prize " .. index .. " is well formed")
		check(index % 7 ~= 0 or prize.chest ~= nil, "every seventh login day opens a chest")
	end
end

-- AFK farm: a small, fixed pay per whole minute, and nothing for nonsense.
equal(Rules.AfkReward("gold", 1).gold, Catalog.Afk.gold.gold, "Gold farm pays its rate")
equal(Rules.AfkReward("gold", 1).xp, 0, "Gold farm pays no XP")
equal(Rules.AfkReward("xp", 3).xp, Catalog.Afk.xp.xp * 3, "XP farm scales with whole minutes")
equal(Rules.AfkReward("xp", 1).gold, 0, "XP farm pays no gold")
check(Catalog.Afk.gold.gold <= 10 and Catalog.Afk.xp.xp <= 20, "AFK farms pay very little per minute")
for _, bad in { { "gold", 0 }, { "gold", 1.5 }, { "gold", 11 }, { "gems", 1 }, { nil, 1 }, { "xp", "1" } } do
	check(Rules.AfkReward(bad[1], bad[2]) == nil, "Invalid AFK payout refused: " .. tostring(bad[1]) .. "/" .. tostring(bad[2]))
end
check(not Rules.CanStart(profile, "hydra", "ranked"), "Competitive waits for training")
profile.tutorialComplete = true
check(Rules.CanStart(profile, "hydra", "ranked"), "Finishing training opens the competitive arena")
check(not Rules.CanStart(profile, "gamma", "cards"), "Cards require a campaign victory")
check(not Rules.CanStart(profile, "asgard", "infinite"), "The removed endless mode cannot start")
profile.campaign.asgard = { normal = true }
check(Rules.CanStart(profile, "wakanda", "ranked"), "Any campaign victory opens every competitive map")
check(Rules.CanStart(profile, "gamma", "cards"), "Any campaign victory opens cards")
check(not Rules.CanStart(profile, "manhattan", "ranked"), "Only authored competitive maps start")
check(not Rules.CanStart(profile, "invalid", "normal"), "Unknown maps rejected")
check(not Rules.CanStart(profile, "manhattan", "daily"), "The removed daily mode cannot start")
check(not Rules.CanStart(profile, "manhattan", "bossrush"), "The removed boss rush cannot start")

do
	local gate = { tutorialComplete = false, campaign = {} }
	check(Rules.ModeUnlocked(gate, "tutorial") and Rules.ModeUnlocked(gate, "normal"), "Portal gate: training and campaign are open to a newcomer")
	for _, modeId in { "ranked", "cards" } do check(not Rules.ModeUnlocked(gate, modeId), "Portal gate: " .. modeId .. " stays closed to a brand-new commander") end
	gate.tutorialComplete = true
	check(Rules.ModeUnlocked(gate, "ranked") and not Rules.ModeUnlocked(gate, "cards"), "Portal gate: finishing training opens the competitive arena")
	gate.stats = { waves = Rules.CardsAfterWaves - 1 }
	check(not Rules.ModeUnlocked(gate, "cards"), "Portal gate: cards wait for enough waves")
	gate.stats.waves = Rules.CardsAfterWaves
	check(Rules.ModeUnlocked(gate, "cards"), "Portal gate: enough waves played open cards")
	gate.stats, gate.tutorialComplete = nil, false
	gate.campaign.manhattan = { normal = true }
	check(Rules.ModeUnlocked(gate, "ranked") and Rules.ModeUnlocked(gate, "cards"), "Portal gate: ranked and cards open after any clear")
	check(not Rules.ModeUnlocked(gate, "infinite"), "Portal gate: no endless mode to unlock")
	check(not Rules.ModeUnlocked(gate, "invalid"), "Portal gate: unknown modes stay locked")
	-- Difficulty chain, per map: Normal → Hard → Nightmare.
	check(Rules.DifficultyUnlocked(gate, "gamma", "normal"), "Difficulty: Normal is always open")
	check(Rules.DifficultyUnlocked(gate, "manhattan", "hard") and not Rules.DifficultyUnlocked(gate, "gamma", "hard"), "Difficulty: a Normal win opens Hard on that map only")
	check(not Rules.DifficultyUnlocked(gate, "manhattan", "nightmare"), "Difficulty: Nightmare needs a Hard win")
	check(Rules.HighestDifficulty(gate, "manhattan") == "hard" and Rules.HighestDifficulty(gate, "gamma") == "normal", "Difficulty: highest opened per map")
	check(not Rules.CanUseDifficulty(gate, "gamma", "normal", "hard"), "Difficulty: a locked difficulty is refused, not downgraded")
	check(not Rules.CanUseDifficulty(gate, "manhattan", "ranked", "hard"), "Difficulty: only the campaign has difficulties")
	check(not Rules.CanUseDifficulty(gate, "manhattan", "normal", "insane"), "Difficulty: unknown ids are refused")
	check(Rules.CanUseDifficulty(gate, "manhattan", "normal", "hard") and Rules.CanUseDifficulty(gate, "gamma", "ranked", nil), "Difficulty: an opened one and the default are accepted")
	gate.campaign.manhattan.hard = true
	check(Rules.DifficultyUnlocked(gate, "manhattan", "nightmare") and Rules.HighestDifficulty(gate, "manhattan") == "nightmare", "Difficulty: a Hard win opens Nightmare")
	check(not Rules.DifficultyUnlocked(gate, "nowhere", "normal") and not Rules.DifficultyUnlocked(nil, "manhattan", "normal"), "Difficulty: bad map or profile stays locked")
	local previous = 0
	for _, id in ipairs(Catalog.DifficultyOrder) do
		local def = Catalog.Difficulties[id]
		check(def and def.hpMultiplier > previous and def.rewardMultiplier >= 1 and def.name.pt ~= "" and def.name.en ~= "", "Difficulty: " .. id .. " is harder than the one before and fully named")
		previous = def and def.hpMultiplier or previous
		local base = Waves.Generate("gamma", "normal", 25, 2, 99)
		local scaled = Waves.Generate("gamma", "normal", 25, 2, 99, id)
		check(#base == #scaled and math.abs(scaled[1].hpMultiplier - base[1].hpMultiplier * def.hpMultiplier) < 1e-6 and scaled[1].speedMultiplier == def.speedMultiplier,
			"Difficulty: " .. id .. " scales the same wave's health and pace")
	end
	check(not Rules.ModeUnlocked(nil, "normal"), "Portal gate: missing profile stays locked")
	check(not Rules.ModeUnlocked({ tutorialComplete = false, campaign = "corrupt", stats = "corrupt" }, "cards"), "A damaged campaign record locks instead of crashing")
end

equal(Rules.PortalMode({ tutorialComplete = false }, "normal"), "normal", "The campaign portal launches the campaign")
equal(Rules.PortalMode({ tutorialComplete = false }, "training"), "tutorial", "The training portal launches training")
for _, modeId in { "ranked", "cards" } do
	check(string.find(Rules.ModeLockReason(modeId), " / ", 1, true) ~= nil, "Localized lock reason for " .. modeId)
end

-- The map is drawn, never chosen, and every map is reachable.
equal(Rules.PickMap("tutorial", 0.9), "manhattan", "Training is always Manhattan")
local playable={tutorialComplete=true,campaign={manhattan={normal=true}}}
for _,map in ipairs(Catalog.MapOrder) do
	for _,mode in ipairs(Catalog.PortalOrder) do
		local expected=false
		for _,def in pairs(Catalog.Destinations) do if def.mapId==map and def.modeId==mode then expected=true end end
		equal(Rules.CanStart(playable,map,mode),expected,"Only authored combinations start: "..map.."/"..mode)
	end
end

--==============================================================================
-- Bosses and waves
--==============================================================================
for wave = 1, 80 do
	equal(Rules.IsBossWave("normal", wave, "latveria"), wave % 10 == 0, "Boss on every tenth wave: " .. wave)
	equal(Rules.IsBossWave("ranked", wave, "hydra"), wave % 10 == 0, "Competitive boss on every tenth wave: " .. wave)
	equal(Rules.IsBossWave("tutorial", wave, "manhattan"), wave == Catalog.Modes.tutorial.waves, "Training has one simplified boss, at the end")
end
for _, mapId in Catalog.MapOrder do
	local total = Rules.WaveCount("normal", mapId)
	check(Rules.IsFinalWave("normal", total, mapId) and not Rules.IsFinalWave("normal", total - 10, mapId), "Final wave is the map's last: " .. mapId)
	equal(Rules.BossId(total, mapId, "normal"), Catalog.Maps[mapId].bossId, "The campaign ends with the map's own boss: " .. mapId)
	for wave = 10, total - 10, 10 do
		check(Rules.BossId(wave, mapId, "normal") ~= Catalog.Maps[mapId].bossId, "The final boss is never met early: " .. mapId .. " wave " .. wave)
	end
end
check(not Rules.IsFinalWave("ranked", 50, "hydra"), "Competitive has no final wave")
equal(Rules.BossId(10, "hydra", "ranked"), "lizard", "Competitive cycles the whole cast in order")
equal(Rules.BossId(70, "hydra", "ranked"), "lizard", "Competitive keeps cycling the bosses")
equal(Rules.BossId(12, "manhattan", "tutorial"), "lizard", "Training's boss is the Lizard")

-- Match Gold is what enemies drop; lobby Gold is paid for the run.
for _, id in Catalog.EnemyOrder do check(Rules.KillCash(id) >= 2, "Every enemy drops match Gold: " .. id) end
equal(Rules.KillCash("illusion"), 0, "Loki's illusions drop nothing")
check(Rules.WaveCash(10) > Rules.WaveCash(1), "Later waves pay more match Gold")
equal(Rules.RunGold("normal", "gamma", 50, true), 2000, "A 50-wave campaign victory pays 2,000")
equal(Rules.RunGold("normal", "manhattan", 40, true), 1600, "A 40-wave campaign victory pays 1,600")
equal(Rules.RunGold("normal", "latveria", 70, true), 2800, "A 70-wave campaign victory pays 2,800")
equal(Rules.RunGold("cards", "gamma", 50, true), 2500, "A card victory pays 2,500")
check(Rules.RunGold("normal", "gamma", 25, false) * 4 < Rules.RunGold("normal", "gamma", 50, true), "A defeat pays far less than a victory")
for waves = 1, 49 do
	check(Rules.RunGold("normal", "gamma", waves + 1, false) > Rules.RunGold("normal", "gamma", waves, false), "More waves always pay more")
end
equal(Rules.RunGold("ranked", "hydra", 70, false), 70 * 25 + 7 * 100, "Competitive: 25 a wave and 100 every ten")
equal(Rules.VictoryGold("tutorial", "manhattan"), 0, "Training pays its first-clear bonus elsewhere")
equal(Rules.VictoryGold("ranked", "hydra"), 0, "Competitive has no victory")

for _, mapId in Catalog.MapOrder do
	local map = Catalog.Maps[mapId]
	for _, path in map.paths do
		check(#path >= 3, "Map has a navigable path")
		for index = 2, #path do
			check(path[index][1] ~= path[index-1][1] or path[index][2] ~= path[index-1][2], "No zero-length path segment")
		end
	end
	for _, modeId in Catalog.ModeOrder do
		local authored = false
		for _, def in pairs(Catalog.Destinations) do if def.mapId == mapId and def.modeId == modeId then authored = true end end
		if not authored then continue end
		local total = Rules.WaveCount(modeId, mapId)
		local waves = if total == 0 then 70 else total
		for partySize = 1, 4 do
			for wave = 1, waves do
				local specs = Waves.Generate(mapId, modeId, wave, partySize, 12345)
				check(#specs > 0 and #specs <= 180, "Wave bounded by active enemy budget")
				local bosses, bossId = 0, nil
				for _, spec in specs do
					local enemy = Catalog.Enemies[spec.enemyId]
					check(enemy ~= nil, "Wave references a real enemy")
					check(spec.pathIndex >= 1 and spec.pathIndex <= #map.paths, "Valid path assignment")
					check(spec.hpMultiplier > 0 and Rules.IsFinite(spec.hpMultiplier), "Finite positive HP")
					check(spec.delay >= 0, "Valid spawn timing")
					local wavePayout = Catalog.Mutations[Rules.WaveMutation(modeId, mapId, wave, 12345) or ""]
					equal(spec.cash, math.floor(Rules.KillCash(spec.enemyId) * (wavePayout and wavePayout.cash or 1) + 0.5), "Each enemy drops its own match Gold")
					if enemy.boss then bosses += 1; bossId = spec.enemyId end
					if mapId == "hydra" then equal(spec.pathIndex, (wave - 1) % 2 + 1, "Announced alternating HYDRA path") end
				end
				equal(bosses, Rules.IsBossWave(modeId, wave, mapId) and 1 or 0, string.format("Exactly the scheduled bosses: %s %s wave %d", mapId, modeId, wave))
				if bossId then equal(bossId, Rules.BossId(wave, mapId, modeId), "The scheduled boss walks in") end
			end
		end
	end
end

-- Every enemy family appears in a campaign run, and every boss in some campaign.
do
	local seen, bosses = {}, {}
	for wave = 1, 40 do
		for _, spec in Waves.Generate("manhattan", "normal", wave, 1, 7) do seen[spec.enemyId] = true end
	end
	for _, id in Catalog.EnemyOrder do
		if not Catalog.Enemies[id].faction or Catalog.Enemies[id].faction=="sinister" then check(seen[id], "Manhattan meets its families and variants, including " .. id) end
	end
	for _, mapId in Catalog.MapOrder do
		for wave = 10, Rules.WaveCount("normal", mapId), 10 do bosses[Rules.BossId(wave, mapId, "normal")] = true end
	end
	for _, id in Catalog.BossOrder do check(bosses[id], "The campaigns meet every boss, including " .. id) end
end

-- A splitter's fragments exist only as what it leaves behind: a real enemy
-- that cannot split again and is never part of a wave of its own.
do
	local fragmentSeen, splitterFirst = false, nil
	for _, modeId in { "normal", "ranked", "tutorial" } do
		for wave = 1, 60 do
			for _, spec in Waves.Generate("manhattan", modeId, wave, 1, 11) do
				if Catalog.Enemies[spec.enemyId].fragment then fragmentSeen = true end
				if spec.enemyId == "splitter" and modeId == "normal" and not splitterFirst then splitterFirst = wave end
				if spec.enemyId == "splitter" then check(modeId ~= "tutorial", "Training teaches the basics without splitters") end
			end
		end
	end
	check(not fragmentSeen, "A fragment never walks in a wave of its own")
	check(splitterFirst ~= nil and splitterFirst >= 12, "Splitters wait for wave 12 in the campaign, first seen on wave " .. tostring(splitterFirst))
	for id, def in Catalog.Enemies do
		if def.split then
			local child = Catalog.Enemies[def.split.into]
			check(child ~= nil and child.fragment == true and child.split == nil, id .. " splits into a fragment that does not split again")
			check(def.split.count >= 2 and def.split.count <= 3, id .. " bursts into two or three pieces")
			-- The pieces together are tougher than the parent alone, but not absurdly.
			local total = def.hp + def.split.count * child.hp
			check(total <= def.hp * 2, id .. " does not hide more than twice its own health in fragments")
			check(Rules.KillCash(def.split.into) < Rules.KillCash(id), id .. " fragments pay less than the parent")
		end
	end
end

-- A saboteur's shock is data, bounded, and never part of the training map.
do
	local first
	for _, modeId in { "normal", "ranked", "tutorial" } do
		for wave = 1, 60 do
			for _, spec in Waves.Generate("gamma", modeId, wave, 1, 5) do
				if spec.enemyId == "saboteur" then
					check(modeId ~= "tutorial", "Training teaches the basics without saboteurs")
					if modeId == "normal" and not first then first = wave end
				end
			end
		end
	end
	check(first ~= nil and first >= 18, "Saboteurs wait for wave 18 in the campaign, first seen on wave " .. tostring(first))
	for id, def in Catalog.Enemies do
		if def.shock then
			check(def.shock.radius >= 8 and def.shock.radius <= 20, id .. " shocks a nearby circle, not the whole map")
			check(def.shock.seconds > 0 and def.shock.seconds <= 2.5, id .. " stuns for a moment, not for good")
			check(def.shock.every >= def.shock.seconds * 3, id .. " leaves long gaps between shocks")
			check(def.shock.warn >= 1, id .. " warns at least a second ahead")
		end
	end
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
equal(#Waves.Generate("manhattan", "normal", 41, 1), 0, "Manhattan's campaign ends after 40")
equal(#Waves.Generate("gamma", "normal", 51, 1), 0, "A 50-wave campaign ends after 50")
check(#Waves.Generate("latveria", "normal", 70, 1) > 0 and #Waves.Generate("latveria", "normal", 71, 1) == 0, "Latveria runs exactly 70")
equal(#Waves.Generate("gamma", "cards", 51, 1), 0, "Card mode terminates after 50")
equal(#Waves.Generate("manhattan", "tutorial", 13, 1), 0, "Training terminates after 12")
check(#Waves.Generate("hydra", "ranked", 120, 1) > 0, "Competitive keeps going")
check(#Waves.Generate("hydra", "ranked", 120, 4) <= 101, "Competitive grows tougher, not more crowded (100 plus its boss)")
check(Waves.Generate("hydra", "ranked", 120, 1)[1].hpMultiplier > Waves.Generate("hydra", "ranked", 60, 1)[1].hpMultiplier, "Competitive health keeps climbing")
local final = Waves.Generate("gamma", "normal", 50, 1)
check(Catalog.Enemies[final[#final].enemyId].boss, "Final campaign boss")
local threats = Waves.Threats(final)
check(threats.boss and threats.air and threats.armor, "Upcoming wave warns about threats")
local solo = Waves.Generate("manhattan", "normal", 1, 1)
local squad = Waves.Generate("manhattan", "normal", 1, 4)
check(squad[1].hpMultiplier > solo[1].hpMultiplier, "Fixed-size cooperative difficulty")
check(Waves.Generate("hydra", "ranked", 20, 1)[1].hpMultiplier > Waves.Generate("hydra", "normal", 20, 1)[1].hpMultiplier, "Competitive is harder")
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
-- A power that falls or flies lands when its look does (Catalog impact): soon,
-- on a chosen area, and only a power that strikes enemies waits (a buff, Gold,
-- a shield or a heal never does). A barrage only splits a blast's damage.
do
	local SELF_KINDS = { rally = true, energy = true, barrier = true, heal = true, overdrive = true }
	local landed = 0
	for _, id in Catalog.AbilityOrder do
		local def = Catalog.Abilities[id]
		local impact = def.impact
		if impact then
			landed += 1
			check(type(impact.at) == "number" and impact.at > 0 and impact.at <= 1.2, "A landing comes soon after the cast: " .. id)
			check(not SELF_KINDS[def.kind], "Only a power that strikes enemies waits to land: " .. id)
			check(def.target == "area", "A falling power lands on a chosen area: " .. id)
			if impact.hits then check(def.kind == "blast" and impact.hits >= 2 and (impact.every or 0) > 0, "Only a blast splits into a barrage: " .. id) end
			if def.kind == "chain" then check((impact.every or 0) > 0, "A chain's bolts reach their targets one by one: " .. id) end
			local last = if def.kind == "chain" then Rules.AbilityStats(def, ranks.max).count else Rules.AbilityHits(def)
			check(Rules.AbilityLanding(def, last) <= 1.5, "Every landing of a power comes within 1.5 s: " .. id)
		else
			equal(Rules.AbilityLanding(def, 1), 0, "A power without an impact strikes as it is cast: " .. id)
			equal(Rules.AbilityHits(def), 1, "A power without an impact lands in one piece: " .. id)
		end
	end
	check(landed >= 10, "The powers that fall or fly land with their look, got " .. landed)
	approx(Rules.AbilityLanding(Catalog.Abilities.solarWrath, 1), 0.55, "The sun lands as it reaches the ground")
	approx(Rules.AbilityLanding(Catalog.Abilities.repulsorBarrage, 3), 0.42 + 2 * 0.07, "The third missile lands two gaps after the first")
	equal(Rules.AbilityHits(Catalog.Abilities.repulsorBarrage), 7, "The barrage lands in seven missiles")
	approx(Rules.AbilityLanding(Catalog.Abilities.thunderCall, 10), 0.54 + 9 * 0.04, "The tenth bolt reaches its target last")
	equal(Rules.AbilityLanding(nil, 1), 0, "No ability, no wait")
	equal(Rules.AbilityLanding({ impact = { at = -1, every = 0 / 0 } }, 3), 0, "A broken impact never waits a negative or undefined time")
	equal(Rules.AbilityHits({ impact = { hits = 0 } }), 1, "A barrage always lands at least once")
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
check(Catalog.Chests.rare.odds.legendary <= 2, "The Alliance chest barely holds a top hero")
equal(Catalog.Chests.legendary.odds.common,30,"Legends chest keeps its former entry-tier pool")
-- The best heroes come from the legendary chest, and the best of them are the rarest.
check(Catalog.Chests.legendary.odds.legendary > Catalog.Chests.rare.odds.legendary, "Legendaries are far likelier in the legendary chest")
check(Catalog.Chests.legendary.odds.rare > Catalog.Chests.legendary.odds.legendary,"Legends chest keeps top items less likely than the middle group")
check(Catalog.Chests.rare.odds.common > Catalog.Chests.rare.odds.rare and Catalog.Chests.rare.odds.rare > Catalog.Chests.rare.odds.legendary,"Alliance chest shows three descending odds")

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
	equal(low.rarity, "common", "The lowest roll in the Legends chest is common")
	local high = Rules.RollChest("legendary", 0.999999, 0, 0, {})
	equal(high.rarity, "legendary", "The highest roll in the Legends chest is legendary")
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
	for _, id in Rules.ChestPool("rare") do ownedAllEpics[id] = true end
	local pool = Rules.ChestPool("rare")
	local missing = pool[3]
	ownedAllEpics[missing] = nil
	for step = 0, 99 do
		local result = Rules.RollChest("legendary", 0.65, step / 100, 0, ownedAllEpics)
		equal(result.rarity, "rare", "Fixture rolls the merged middle rarity")
		equal(result.heroId, missing, "The one missing epic is always the one delivered")
		check(not result.duplicate, "A new hero is not a duplicate")
	end
	ownedAllEpics[missing] = true
	local dupe = Rules.RollChest("legendary", 0.65, 0.4, 0, ownedAllEpics)
	check(dupe.duplicate, "A completed rarity yields a duplicate")
	check(Catalog.Heroes[dupe.heroId].rarity == "rare", "The duplicate still keeps its rarity")
end

-- Pity: the tenth legendary chest without a top hero is guaranteed to be one.
do
	local chest = Catalog.Chests.legendary
	equal(chest.pity.after, 10, "Pity threshold")
	for step = 0, 99 do
		local result = Rules.RollChest("legendary", step / 100, 0.5, chest.pity.after - 1, {})
		equal(result.rarity,"legendary","Pity guarantees the top collectible rarity")
		check(result.pity and result.top, "The result reports the pity")
	end
	local normal = Rules.RollChest("legendary", 0.05, 0.5, chest.pity.after - 2, {})
	check(not normal.pity, "Pity is not triggered early")
	local mythics = 0
	for step = 0, 999 do
		if Catalog.Heroes[Rules.RollChest("legendary", step / 1000, 0.5, chest.pity.after - 1, {}).heroId].cosmicAchievement then mythics += 1 end
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
check(Rules.CardWave("cards", 45) and not Rules.CardWave("cards", 50), "Nine picks per run, none after the victory")

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
	local counts = { common = 0, rare = 0, legendary = 0 }
	for seed = 1, 3000 do
		for _, id in Rules.CardOffers(seed, 10, 1, {}) do counts[Catalog.Cards[id].rarity] += 1 end
	end
	check(counts.common > counts.rare and counts.rare > counts.legendary, "Card weighting keeps common cards more frequent")
	check(counts.legendary > 0, "Renamed top cards retain their old weighting")
end

-- A slowing hero slows harder with every level.
do
	local one = Rules.TowerStats("iceman", 1).slow
	local four = Rules.TowerStats("iceman", 4).slow
	approx(one, Catalog.Heroes.iceman.slow, "Level 1 slows by the hero's base")
	check(four > one and four <= 0.75, "Level 4 slows harder, never past 75%")
	approx(Rules.TowerStats("ironman", 4).slow, 0, "A hero that does not slow never starts")
end

do
	local totals = Rules.CardTotals({ "sharpen", "sharpen", "glassCannon", "supplyDrop" })
	approx(totals.damage, 1.10 * 1.10 * 1.35 - 1, "Card damage compounds: each copy multiplies the total")
	approx(totals.range, -0.15, "A card can cost you something")
	equal(totals.energy, nil, "Instant cards add no stat")
	approx(Rules.CardTotals({ "sharpen", "sharpen" }).damage, 0.21, "Two +10% cards make +21%")
	approx(Rules.CardTotals({ "sharpen", "sharpen", "overclock" }).damage, 1.21 * 0.88 - 1, "A -12% card cuts 12% of the larger total, not a flat 12 points")
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
	check(total > Rules.TalentPointsEarned(Rules.MaxLevel), "Not every talent can be maxed: choices matter")
	-- The owner's 17/10 ask: almost double the tree (it had 13 talents, 3 branches).
	local count = 0
	for _ in Catalog.Talents do count += 1 end
	check(count >= 25 and #Catalog.TalentBranches == 6, "The talent tree has six branches and about twice its 13 talents, got " .. count)
	-- Every branch fits a row of the board: a side (-1 left, 1 right) and a row
	-- (0, -2, 2), never two branches in the same place.
	local places = {}
	for _, branch in Catalog.TalentBranches do
		check(branch.side == -1 or branch.side == 1, "A branch has a side: " .. branch.id)
		check(branch.row == 0 or branch.row == -2 or branch.row == 2, "A branch has a row: " .. branch.id)
		local key = branch.side .. ":" .. branch.row
		check(not places[key], "Two branches never share a row: " .. branch.id)
		places[key] = true
		check(branch.name.pt and branch.name.en, "A branch is named: " .. branch.id)
	end
	-- Every branch, maxed on its own, fits in the points of a top account.
	for _, branch in Catalog.TalentBranches do
		local need = 0
		for _, id in ipairs(branch.nodes) do need += Catalog.Talents[id].maxRank end
		check(need <= Rules.TalentPointsEarned(Rules.MaxLevel), "A whole branch is earnable: " .. branch.id)
	end
end

-- What each new talent does, through the same functions the server uses.
do
	equal(Rules.TalentEffect({ talents = { heroFury = 10 } }, "heroFury"), 0.2, "Heroes' fury: +2% damage a point")
	equal(Rules.TalentEffect({ talents = { heroFury = 99 } }, "heroFury"), 0.2, "A talent's effect stops at its top rank")
	equal(Rules.TalentEffect({ talents = { waveShield = 2 } }, "waveShield"), 2, "The wave shield counts leaks, not a share")
	equal(Rules.TalentEffect({}, "heroFury"), 0, "No talents, no effect")
	equal(Rules.TalentEffect({ talents = { heroFury = 3 } }, "nonsense"), 0, "An unknown talent has no effect")
	equal(Rules.TalentEffect(nil, "critical"), 0, "No profile, no effect")
	-- Heroes' fury adds on top of the 15% permanent cap.
	local capped = Rules.PermanentModifiers({ talents = { towerPower = 5 }, heroes = {} }, "ironman")
	local furious = Rules.PermanentModifiers({ talents = { towerPower = 5, heroFury = 10 }, heroes = {} }, "ironman")
	check(math.abs(furious.damageBonus - capped.damageBonus - 0.2) < 1e-9, "Heroes' fury adds +20% on top of Elite formation")
	local tactics = Rules.PermanentModifiers({ talents = { drillSpeed = 5, bossHunter = 5, skyGuard = 5, nightSight = 5, piercing = 5, shockwave = 5, critical = 5, upgradeDiscount = 5 }, heroes = {} }, "ironman")
	check(math.abs(tactics.attackSpeedBonus - capped.attackSpeedBonus - 0.10) < 1e-9, "Combat drills: +10% attack speed at 5")
	check(math.abs(tactics.bossDamageBonus - 0.25) < 1e-9 and math.abs(tactics.airDamage - 0.25) < 1e-9 and math.abs(tactics.stealthDamage - 0.30) < 1e-9, "Boss, air and hidden talents")
	check(math.abs(tactics.armorPierceBonus - 0.20) < 1e-9 and math.abs(tactics.splashBonus - 0.25) < 1e-9, "Piercing and shockwave talents")
	check(math.abs(tactics.critChance - 0.15) < 1e-9 and math.abs(tactics.upgradeDiscount - 0.10) < 1e-9, "Critical and workshop talents")
	local plain = Rules.TowerStats("hulk", 1, nil, {})
	local tuned = Rules.TowerStats("hulk", 1, nil, { bossDamageBonus = tactics.bossDamageBonus, splashBonus = tactics.splashBonus, armorPierceBonus = tactics.armorPierceBonus })
	check(tuned.bossDamage > plain.bossDamage and tuned.splash >= plain.splash and tuned.armorPierce > plain.armorPierce, "The tactics talents reach the tower's stats")
	-- Placement: the talent and the card discounts add up, never past half.
	local hero = Catalog.Heroes.ironman
	equal(Rules.PlacementCost(hero, {}, nil), hero.cost, "No discount: the hero's price")
	equal(Rules.PlacementCost("ironman", { talents = { towerDiscount = 5 } }, nil), math.floor(hero.cost * 0.9), "Recruiting contracts: -10% at 5")
	equal(Rules.PlacementCost(hero, { talents = { towerDiscount = 5 } }, { discount = 0.08 }), math.floor(hero.cost * (1 - 0.18)), "Talent and card discounts add up")
	equal(Rules.PlacementCost(hero, { talents = { towerDiscount = 5 } }, { discount = 0.9 }), math.floor(hero.cost * 0.5), "Never more than half off")
	-- Leaks: double every 4 waves, at most 4 times.
	equal(Rules.LeakScale(1), 1, "Wave 1 leaks hurt as written")
	equal(Rules.LeakScale(4), 1, "Waves 1-4 at 1x")
	equal(Rules.LeakScale(5), 2, "Wave 5: twice")
	equal(Rules.LeakScale(8), 2, "Waves 5-8 at 2x")
	equal(Rules.LeakScale(9), 4, "Wave 9: four times")
	equal(Rules.LeakScale(40), 4, "Never past four times")
	equal(Rules.LeakScale(0 / 0), 1, "A bad wave counts as the first")
	-- The Iron armour skin: a Robux pass, on sale only once configured, with a
	-- small repulsor whose damage grows with the wave.
	local skin = Catalog.Products.Passes.ironSkin
	check(skin ~= nil and skin.price >= 499 and skin.skinHero == "ironman" and Catalog.Heroes[skin.skinHero] ~= nil, "The Iron armour skin is a premium pass for an existing hero")
	check(Rules.SkinShotDamage(1) > 0 and Rules.SkinShotDamage(20) > Rules.SkinShotDamage(1) and Rules.SkinShotDamage(0 / 0) == Rules.SkinShotDamage(1), "The repulsor grows with the wave")
	check(Rules.SkinShot.cooldown > 0 and Rules.SkinShot.range > 0 and Rules.SkinShot.radius > 0, "The repulsor has a cooldown, a range and a radius")
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
	check(Rules.RewardsStatus(profile, 50 * DAY, 0, true).freeChest.cooldown < Rules.RewardsStatus(profile, 50 * DAY, 0).freeChest.cooldown, "A VIP's free chest wait is shorter")
	-- The season's exclusive hero sits at the top of the premium track, and every theme names one that exists.
	for index, theme in ipairs(Catalog.SeasonThemes) do
		check(Catalog.Heroes[theme.hero] ~= nil, "season theme " .. index .. " names a real hero")
		check(Rules.SeasonReward(Catalog.Season.levels, "premium", index).hero == theme.hero, "premium level 30 of season " .. index .. " pays its hero")
		check(Rules.SeasonReward(Catalog.Season.levels - 1, "premium", index).hero == nil and Rules.SeasonReward(Catalog.Season.levels, "free", index).hero == nil, "no other level, and never the free track, pays the hero")
	end
	check(Rules.SeasonStatus({ id = 1, xp = 0, freeClaimed = 0, premiumClaimed = 0, premium = true }, false).owned, "This season's own purchase opens the premium track")
	-- A friend's gift waits on the gifts page and counts as claimable; the day's send is remembered.
	local gifted = Rules.RewardsStatus({ rewards = { freeChestAt = 1e12, loginDay = 50, loginStreak = 1, playDay = 50, playSeconds = 0, playClaimed = {}, collection = {}, giftsPending = 2, giftDay = 50 }, heroes = {} }, 50 * DAY + 10, 0)
	check(gifted.gift.pending == 2 and gifted.gift.sentToday == true and gifted.gift.chestId == Catalog.Rewards.gift.chestId and gifted.claimable == 2, "two gifts waiting are two claims; today's gift went out")
	check(Rules.RewardsStatus({ rewards = Rules.NewRewardsState(), heroes = {} }, 50 * DAY, 0).gift.pending == 0, "a fresh state has no gift waiting")
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

print("PASS " .. assertions .. " assertions: catalog, heroes, abilities, chests and odds, cards, talents, unlocks, fixed destinations, 50-wave bosses, wave economy on every map/mode/party size, daily rewards")
