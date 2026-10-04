--!nonstrict
-- Pure calculations, with module resolution for Studio and the official Luau CLI.
-- Nothing here touches the engine, so every rule can be tested exhaustively.
local Catalog = require(if script then script.Parent.Catalog else "./Catalog")
local Rules = {}

function Rules.IsFinite(value)
	return type(value) == "number" and value == value and value > -math.huge and value < math.huge
end

local function number(value, fallback)
	return if Rules.IsFinite(value) then value else fallback
end

--==============================================================================
-- Account level and hero mastery
--==============================================================================
function Rules.LevelXP(level)
	level = math.clamp(math.floor(number(level, 1)), 1, 50)
	return math.floor(150 * (level - 1) ^ 1.65)
end

function Rules.LevelFromXP(xp)
	xp = math.max(0, number(xp, 0))
	local level = 1
	while level < 50 and xp >= Rules.LevelXP(level + 1) do level += 1 end
	return level
end

function Rules.MasteryXP(level)
	level = math.clamp(math.floor(number(level, 1)), 1, 20)
	return math.floor(90 * (level - 1) ^ 1.55)
end

function Rules.MasteryLevel(xp)
	xp = math.max(0, number(xp, 0))
	local level = 1
	while level < 20 and xp >= Rules.MasteryXP(level + 1) do level += 1 end
	return level
end

-- One point per level after the first, spent one at a time on the talent tree.
function Rules.TalentPointsEarned(level)
	return math.clamp(math.floor(number(level, 1)), 1, 50) - 1
end

-- There is no design limit on towers: a commander fields as many heroes (of any
-- mix, any number of copies) as their Gold allows. This ceiling only keeps one
-- account from flooding a server (a tower is a rig, a projectile source and a
-- sync record); nobody reaches it by spending Gold.
Rules.SafetyTowerCeiling = 150
function Rules.TowerLimit(size)
	return Rules.SafetyTowerCeiling
end

-- Copies of one hero are not limited either; the ceiling above is the only cap.
function Rules.HeroLimit(heroId)
	return Rules.SafetyTowerCeiling
end

--==============================================================================
-- Modes, unlocks and the random map
--==============================================================================
-- How many waves a run lasts; 0 is endless. The campaign's length belongs to
-- the map (Catalog.CampaignWaves); every other mode has one length.
function Rules.WaveCount(modeId, mapId)
	local mode = Catalog.Modes[modeId]
	if not mode then return 0 end
	if modeId == "normal" and mapId and Catalog.CampaignWaves[mapId] then return Catalog.CampaignWaves[mapId] end
	return mode.waves
end

local function anyWon(profile, key)
	for _, entry in pairs(type(profile.campaign) == "table" and profile.campaign or {}) do
		if type(entry) == "table" and entry[key] == true then return true end
	end
	return false
end

-- Whether a commander may enter a mode at all. This is the only unlock rule:
-- the portals dim from it and the server re-checks it before every launch.
--   training and the campaign are always open (training is recommended, never
--   required); the first campaign victory on any map opens cards and the
--   competitive arena. Nothing depends on beating an endless mode.
function Rules.ModeUnlocked(profile, modeId)
	if type(profile) ~= "table" or not Catalog.Modes[modeId] then return false end
	if modeId == "tutorial" then return true end
	if modeId == "normal" then return true end
	if modeId == "ranked" or modeId == "cards" then return anyWon(profile, "normal") end
	return false
end

local LOCK_REASON = {
	ranked = "Vença qualquer mapa da campanha / Win any campaign map",
	cards = "Vença qualquer mapa da campanha / Win any campaign map",
}

-- Why a mode's portal refuses someone, in the "pt / en" form the router uses.
-- A newcomer is always sent to training first.
function Rules.ModeLockReason(modeId, profile)
	return LOCK_REASON[modeId] or "Modo indisponível / Mode unavailable"
end

function Rules.CanStart(profile, mapId, modeId)
	if not Catalog.Maps[mapId] or not Catalog.Modes[modeId] then return false, "Mapa ou modo inválido / Invalid map or mode" end
	if type(profile) ~= "table" then return false, "Perfil indisponível / Profile unavailable" end
	if modeId == "tutorial" then
		if mapId ~= "manhattan" then return false, "O treinamento acontece em Manhattan / Training takes place in Manhattan" end
		return true
	end
	local destination=false
	for _,def in pairs(Catalog.Destinations) do
		if def.mapId==mapId and def.modeId==modeId then destination=true; break end
	end
	if not destination then return false,"Este mapa tem seu próprio modo. / This map has its own mode." end
	if not Rules.ModeUnlocked(profile, modeId) then return false, Rules.ModeLockReason(modeId, profile) end
	return true
end

-- Campaign difficulty, in a chain per map: Normal is always open, and each
-- harder one opens once the one it requires was beaten on that same map.
-- Only the campaign has difficulties; every other mode plays at Normal.
function Rules.DifficultyUnlocked(profile, mapId, difficultyId)
	local def = Catalog.Difficulties[difficultyId]
	if type(profile) ~= "table" or not def or not Catalog.Maps[mapId] then return false end
	if not def.requires then return true end
	local required = Catalog.Difficulties[def.requires]
	local entry = type(profile.campaign) == "table" and profile.campaign[mapId]
	return type(entry) == "table" and entry[required.winKey] == true
end

-- The difficulty a run really plays at: a refusal, never a silent downgrade.
function Rules.CanUseDifficulty(profile, mapId, modeId, difficultyId)
	if difficultyId == nil or difficultyId == "normal" then return true end
	if not Catalog.Difficulties[difficultyId] then return false, "Dificuldade inválida / Invalid difficulty" end
	if modeId ~= "normal" then return false, "Só a campanha tem dificuldades / Only the campaign has difficulties" end
	if not Rules.DifficultyUnlocked(profile, mapId, difficultyId) then
		local required = Catalog.Difficulties[Catalog.Difficulties[difficultyId].requires]
		return false, "Vença este mapa no " .. required.name.pt .. " / Beat this map on " .. required.name.en
	end
	return true
end

-- The hardest difficulty a commander has opened on a map.
function Rules.HighestDifficulty(profile, mapId)
	local best = "normal"
	for _, id in ipairs(Catalog.DifficultyOrder) do
		if Rules.DifficultyUnlocked(profile, mapId, id) then best = id end
	end
	return best
end

-- Training is a separate opt-in choice; portals retain their named mode.
function Rules.PortalMode(profile, portalId)
	local def=Catalog.Destinations[portalId]
	return def and def.modeId or nil
end

function Rules.PortalMap(portalId)
	local def=Catalog.Destinations[portalId]
	return def and def.mapId or nil
end

function Rules.MapsForMode(modeId)
	local maps={}
	for _,id in ipairs(Catalog.DestinationOrder) do
		local def=Catalog.Destinations[id]
		if def.modeId==modeId then table.insert(maps,def.mapId) end
	end
	return maps
end

--==============================================================================
-- Building: the one placement rule
--==============================================================================
-- The client's preview and the server's check call this same function, so a
-- spot the preview shows green is a spot the server accepts. blockers are the
-- solid things of a match that are not roads: the core and every base, as
-- { x, z, r } circles. config supplies PathHalfWidth and TowerRadius.
Rules.BUILD_LIMIT = 106
Rules.BuildReasons = {
	bounds = { pt = "Fora da área de construção", en = "Outside the build area" },
	path = { pt = "Muito perto do caminho", en = "Too close to the path" },
	occupied = { pt = "Espaço ocupado", en = "Space taken" },
	cash = { pt = "Ouro insuficiente", en = "Not enough Gold" },
	limit = { pt = "Limite de heróis", en = "Hero limit reached" },
	unitLimit = { pt = "Limite deste herói", en = "Limit for this hero" },
}

local function segmentDistanceXZ(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local square = dx * dx + dz * dz
	local t = if square > 0 then math.clamp(((px - ax) * dx + (pz - az) * dz) / square, 0, 1) else 0
	local cx, cz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(cx * cx + cz * cz)
end

function Rules.BuildCheck(mapId, position, towers, config, blockers)
	local map = Catalog.Maps[mapId]
	if not map or type(position) ~= "table" and typeof(position) ~= "Vector3" then return false, "bounds" end
	local x, z = position.X, position.Z
	if not Rules.IsFinite(x) or not Rules.IsFinite(z) then return false, "bounds" end
	if math.abs(x) > Rules.BUILD_LIMIT or math.abs(z) > Rules.BUILD_LIMIT then return false, "bounds" end
	local radius = number(config and config.TowerRadius, 3)
	local clearance = number(config and config.PathHalfWidth, 6) + radius
	for _, route in ipairs(map.paths) do
		for index = 1, #route - 1 do
			local a, b = route[index], route[index + 1]
			if segmentDistanceXZ(x, z, a[1], a[2], b[1], b[2]) < clearance then return false, "path" end
		end
	end
	for _, tower in ipairs(towers or {}) do
		local tx, tz = tower.X or (tower.position and tower.position.X), tower.Z or (tower.position and tower.position.Z)
		if tx and tz and math.sqrt((tx - x) ^ 2 + (tz - z) ^ 2) < radius * 2 then return false, "occupied" end
	end
	for _, blocker in ipairs(blockers or {}) do
		if math.sqrt((blocker.x - x) ^ 2 + (blocker.z - z) ^ 2) < (blocker.r or 0) + radius then return false, "occupied" end
	end
	return true
end

-- Guaranteed purchase for accounts where paid random items are restricted
-- (PolicyService): the Gold price of one exact hero or base is what it costs
-- on average to draw it from the cheapest chest that holds its rarity
-- (chest price / chance of that item), rounded up to 50. Pity and the
-- unowned-first rule are ignored, so it is never cheaper than the chests.
function Rules.GuaranteedPrice(itemId)
	local hero, base = Catalog.Heroes[itemId], Catalog.Bases and Catalog.Bases[itemId]
	local def = hero or base
	if not def then return nil end
	local kind = if hero then "hero" else "base"
	local count = 0
	for _, id in ipairs(if hero then Catalog.HeroOrder else Catalog.BaseOrder) do
		local other = if hero then Catalog.Heroes[id] else Catalog.Bases[id]
		if other.rarity == def.rarity then count += 1 end
	end
	local best
	for _, chest in pairs(Catalog.Chests) do
		local chestKind = if chest.kind == "base" then "base" else "hero"
		local odds = chest.odds and chest.odds[def.rarity] or 0
		if chestKind == kind and odds > 0 and count > 0 then
			local price = chest.cost / (odds / 100 / count)
			if not best or price < best then best = price end
		end
	end
	return if best then math.ceil(best / 50) * 50 else nil
end

-- What a stretch of whole minutes in an AFK chamber pays. nil for anything
-- that is not a farm or not a sane number of minutes.
function Rules.AfkReward(kind, minutes)
	local farm = type(kind) == "string" and Catalog.Afk and Catalog.Afk[kind]
	if type(farm) ~= "table" or type(minutes) ~= "number" or minutes ~= math.floor(minutes) or minutes < 1 or minutes > 10 then return nil end
	return { gold = (farm.gold or 0) * minutes, xp = (farm.xp or 0) * minutes }
end

-- Legacy callers get the first authored destination, never a random map.
function Rules.PickMap(modeId, _roll)
	if modeId=="tutorial" then return "manhattan" end
	for _,id in ipairs(Catalog.DestinationOrder) do
		local def=Catalog.Destinations[id]
		if def.modeId==modeId then return def.mapId end
	end
	return nil
end

function Rules.RankForWaves(waves)
 local tiers = {
  {minimum=0,pt="Iniciante",en="Rookie"}, {minimum=10,pt="Bronze",en="Bronze"},
  {minimum=20,pt="Prata",en="Silver"}, {minimum=30,pt="Ouro",en="Gold"},
  {minimum=40,pt="Diamante",en="Diamond"}, {minimum=50,pt="Lenda",en="Legend"},
 }
 local result=tiers[1]
 for _,tier in ipairs(tiers) do if number(waves,0)>=tier.minimum then result=tier end end
 return result
end

--==============================================================================
-- Waves and bosses
--==============================================================================
-- A boss on every tenth wave. The last wave of a fixed-length run is the
-- final boss, the strongest of them all.
function Rules.IsBossWave(modeId, wave, mapId)
	wave = math.floor(number(wave, 0))
	if modeId == "tutorial" then return Rules.IsFinalWave(modeId, wave, mapId) end
	return wave >= 10 and wave % 10 == 0
end

function Rules.IsFinalWave(modeId, wave, mapId)
	local count = Rules.WaveCount(modeId, mapId)
	return count > 0 and math.floor(number(wave, 0)) == count
end

-- Which boss walks in on a boss wave. A fixed-length run ends with its map's
-- own boss (training: the Lizard, simplified); the bosses before it cycle
-- through the rest of the cast in story order, so the finale is never met
-- early. The competitive arena cycles through the whole cast, stronger
-- every lap.
function Rules.BossId(wave, mapId, modeId)
	local step = math.max(1, math.floor(number(wave, 10) / 10))
	local map = mapId and Catalog.Maps[mapId]
	if modeId == "tutorial" then return "lizard" end
	if map and modeId and modeId ~= "ranked" then
		if Rules.IsFinalWave(modeId, wave, mapId) then return map.bossId end
		local others = {}
		for _, id in ipairs(Catalog.BossOrder) do if id ~= map.bossId then table.insert(others, id) end end
		return others[(step - 1) % #others + 1]
	end
	return Catalog.BossOrder[(step - 1) % #Catalog.BossOrder + 1]
end

--==============================================================================
-- Rewards
--==============================================================================
-- Lobby Gold is paid for the run itself, never out of what was spent in it:
-- the Gold enemies drop during a match is match money (Rules.KillCash) and
-- stays in the match. Every completed wave banks a guaranteed share (kept
-- even after a defeat or a disconnect); a victory pays the rest, so a full
-- win is worth far more than a loss, and more waves are always worth more.
--   campaign: 40 per wave (2,000 for 50 waves, 1,600 for 40, 2,800 for 70)
--   cards: 50 per wave; training: nothing per wave, a one-off first clear
--   competitive: 25 per wave and 100 more every ten waves, all of it kept
local RUN_GOLD_PER_WAVE = { normal = 40, cards = 50 }
local DEFEAT_SHARE = 0.4

-- The lobby Gold banked when a wave is completed.
function Rules.WaveGold(modeId, wave)
	wave = math.max(1, math.floor(number(wave, 1)))
	if modeId == "ranked" then return 25 + (if wave % 10 == 0 then 100 else 0) end
	local rate = RUN_GOLD_PER_WAVE[modeId]
	return if rate then math.floor(rate * DEFEAT_SHARE) else 0
end

-- The multiplier on lobby Gold and XP for playing in a party of `size`.
function Rules.PartyBonus(size)
	size = math.clamp(math.floor(number(size, 1)), 1, 4)
	return 1 + Catalog.PartyBonus.perPlayer * (size - 1)
end

-- The mutation of a wave, or nil: decided by the match seed and the wave number
-- alone, so every server and the preview agree.
function Rules.WaveMutation(modeId, mapId, wave, seed)
	if modeId == "tutorial" or type(wave) ~= "number" or wave ~= wave or wave < 6 or Rules.IsBossWave(modeId, wave, mapId) then return nil end
	local hash = (math.abs(math.floor(number(seed, 0))) * 2654435761 + math.floor(wave) * 40503 + 17) % 4093
	if hash % 4 ~= 0 then return nil end
	return Catalog.MutationOrder[math.floor(hash / 4) % #Catalog.MutationOrder + 1]
end

-- The campaign map featured on a given day (the day number is the Unix day,
-- decided by the server), and the multiplier it pays on that day.
function Rules.FeaturedMap(day)
	local maps = Rules.MapsForMode("normal")
	if #maps == 0 or type(day) ~= "number" or day ~= day then return nil end
	return maps[math.floor(day) % #maps + 1]
end

function Rules.FeaturedBonus(mapId, modeId, day)
	if modeId == "normal" and mapId ~= nil and mapId == Rules.FeaturedMap(day) then return 1 + Catalog.DailyFeature.bonus end
	return 1
end

-- What a victory adds on top of the banked waves.
function Rules.VictoryGold(modeId, mapId)
	local rate = RUN_GOLD_PER_WAVE[modeId]
	local count = Rules.WaveCount(modeId, mapId)
	if not rate or count <= 0 then return 0 end
	return rate * count - Rules.WaveGold(modeId, 1) * count
end

-- The whole lobby Gold of a run that stopped after `waves` completed waves.
function Rules.RunGold(modeId, mapId, waves, victory)
	local total = 0
	for wave = 1, math.max(0, math.floor(number(waves, 0))) do total += Rules.WaveGold(modeId, wave) end
	if victory then total += Rules.VictoryGold(modeId, mapId) end
	return total
end

-- Match Gold: what an enemy drops on the ground when it dies. Collected by
-- walking near it (or the collector drone); spent on heroes, never saved.
function Rules.KillCash(enemyId)
	local enemy = Catalog.Enemies[enemyId]
	if not enemy or enemy.illusion then return 0 end
	return math.max(2, enemy.reward or 4)
end

-- The match Gold every commander receives when a wave is cleared.
function Rules.WaveCash(wave)
	return 90 + math.max(1, math.floor(number(wave, 1))) * 12
end

function Rules.WaveXP(wave)
	return 18 + math.max(1, math.floor(number(wave, 1))) * 2
end

function Rules.WaveMastery(wave)
	return 10 + math.max(1, math.floor(number(wave, 1)))
end

--==============================================================================
-- Towers
--==============================================================================
-- Permanent bonuses are capped so that no amount of progression outgrows the
-- game: 15% damage, 10% attack speed, 10% range.
function Rules.PermanentModifiers(profile, heroId)
	local mastery = profile and profile.heroes and profile.heroes[heroId]
	local masteryLevel = Rules.MasteryLevel(if type(mastery) == "table" then mastery.xp else 0)
	local talents = profile and profile.talents or {}
	local stars = type(mastery) == "table" and math.clamp(math.floor(number(mastery.stars, 0)), 0, Catalog.Stars.max) or 0
	return {
		damageBonus = math.min(0.15, math.floor(masteryLevel / 2) * 0.01 + (talents.towerPower or 0) * 0.01) + stars * Catalog.Stars.damage,
		rangeBonus = math.min(0.10, (masteryLevel - 1) * 0.002 + (talents.reach or 0) * 0.01),
		attackSpeedBonus = math.min(0.10, (masteryLevel - 1) * 0.003),
	}
end

local function applyMod(stats, mod)
	if mod.op == "set" then stats[mod.key] = mod.value
	elseif mod.op == "mul" then stats[mod.key] = stats[mod.key] * mod.value
	elseif mod.op == "add" then stats[mod.key] = stats[mod.key] + mod.value end
end

-- A tower's stats from its hero, level, chosen branch and the bonuses around it.
-- Levels 1-4 are a linear climb; level 5 applies the branch the player chose,
-- and that branch is plain data on the hero (see Catalog).
function Rules.TowerStats(hero, level, branch, modifiers)
	if type(hero) == "string" then hero = Catalog.Heroes[hero] end
	assert(type(hero) == "table" and hero.cost, "Unknown hero")
	level = math.clamp(math.floor(number(level, 1)), 1, 5)
	modifiers = modifiers or {}
	local function bonus(key) return math.max(-0.9, number(modifiers[key], 0)) end
	local linear = math.min(level, 4) - 1
	local stats = {
		damage = hero.damage * 1.45 ^ linear,
		range = hero.range + linear * 1.75,
		interval = hero.interval * 0.96 ^ linear,
		attack = hero.attack, damageType = hero.damageType, air = hero.air == true,
		reveal = hero.reveal == true, support = hero.support == true,
		splash = hero.splash or 0, chain = hero.chain or 1, slow = hero.slow or 0,
		mark = hero.mark or 0, armorPierce = hero.armorPierce or 0,
		armorShred = if hero.shredBase then hero.shredBase + hero.shredPerLevel * level else 0,
		supportBoost = hero.supportBoost or 0, bossDamage = 0,
		-- Punches that push an enemy back along the road (never a boss), a tower
		-- no stun can touch, and the radius within which allies are as steady.
		knockback = hero.knockback or 0, stunProof = hero.stunProof == true, stunAura = hero.stunAura or 0,
		-- Mines: how many a tower keeps on the road, the blast radius and the stun.
		mineMax = hero.mineMax or 0, mineRadius = hero.mineRadius or 0, mineStun = hero.mineStun or 0,
		portal = false, periodicSplash = hero.stompEvery or 0,
		dotDuration = hero.dotDuration or 0, beamWidth = hero.beamWidth or 3,
		upgradeCost = if level < 5 then math.floor(hero.cost * ({ 0.9, 1.4, 2.2, 3.5 })[level]) else 0,
	}
	if level == 5 then
		assert(branch == 1 or branch == 2, "Final upgrade requires branch 1 or 2")
		stats.damage *= 1.25
		for _, mod in ipairs(hero.branches[branch].mods or {}) do applyMod(stats, mod) end
	end
	stats.damage *= 1 + bonus("damageBonus")
	stats.range *= 1 + bonus("rangeBonus")
	stats.interval = math.max(0.08, stats.interval / (1 + bonus("attackSpeedBonus")))
	stats.rate = 1 / stats.interval
	stats.bossDamage += bonus("bossDamageBonus")
	stats.armorPierce = math.clamp(stats.armorPierce + bonus("armorPierceBonus"), 0, 0.9)
	stats.splash *= 1 + bonus("splashBonus")
	stats.supportBoost = math.max(stats.supportBoost, bonus("supportBoost"))
	stats.airDamage, stats.stealthDamage = bonus("airDamage"), bonus("stealthDamage")
	return stats
end

--==============================================================================
-- Hero abilities
--==============================================================================
-- What an ability does at a given rank. abilityPower (talents, cards) scales its
-- magnitude, or its duration when it has no magnitude (a stun); cooldownReduction
-- shortens its recharge and is capped so an ability can never be spammed.
function Rules.AbilityStats(def, rank, options)
	options = options or {}
	local ranks = Catalog.AbilityRanks
	rank = math.clamp(math.floor(number(rank, 1)), 1, ranks.max)
	local step = rank - 1
	local strength = 1 + math.max(-0.5, number(options.abilityPower, 0))
	local power = (def.power or 0) * (1 + ranks.growth.power * step)
	local duration = (def.duration or 0) * (1 + ranks.growth.duration * step)
	if def.power then power *= strength elseif def.duration then duration *= strength end
	local cut = math.clamp(number(options.cooldownReduction, 0), -0.5, 0.4)
	return {
		kind = def.kind, target = def.target, stat = def.stat, unit = def.unit,
		power = power, duration = duration,
		radius = (def.radius or 0) * (1 + ranks.growth.radius * step),
		count = if def.count then def.count + math.floor(step / 2) else 0,
		cooldown = def.cooldown * (1 + ranks.growth.cooldown * step) * (1 - cut),
		rank = rank,
	}
end

local function trimmed(value)
	local rounded = math.floor(value * 10 + 0.5) / 10
	return if rounded % 1 == 0 then tostring(math.floor(rounded)) else string.format("%.1f", rounded)
end

-- The secondary effects of an ultimate, at this rank. Each one rides on the
-- primary effect's target and radius unless it names its own, and grows with
-- the rank and with the same ability-power bonuses.
function Rules.AbilityExtras(def, rank, options)
	local extras = {}
	for _, extra in ipairs(def.extras or {}) do
		local synthetic = {
			kind = extra.kind, target = def.target, power = extra.power, duration = extra.duration,
			radius = extra.radius or def.radius, count = extra.count, cooldown = def.cooldown, stat = extra.stat,
			unit = extra.unit or (if extra.kind == "pull" then "studs" elseif extra.kind == "barrier" or extra.kind == "heal" then "hp" else "pct"),
		}
		table.insert(extras, Rules.AbilityStats(synthetic, rank, options))
	end
	return extras
end

local function formatPower(stats)
	return if stats.unit == "pct" then tostring(math.floor(stats.power * 100 + 0.5)) else trimmed(stats.power)
end

-- The ability's description with this rank's real numbers filled in. Extras are
-- named {e1.power}, {e1.duration}, {e1.radius}, {e1.count}, {e2...} in the order
-- they are listed on the ability.
function Rules.AbilityText(def, rank, language, options)
	local stats = Rules.AbilityStats(def, rank, options)
	local text = def.description[language] or def.description.pt
	for index, extra in ipairs(Rules.AbilityExtras(def, rank, options)) do
		local key = "{e" .. index .. "."
		text = text:gsub(key .. "power}", formatPower(extra)):gsub(key .. "duration}", trimmed(extra.duration))
			:gsub(key .. "radius}", tostring(math.floor(extra.radius + 0.5))):gsub(key .. "count}", tostring(extra.count))
	end
	return (text:gsub("{power}", formatPower(stats)):gsub("{duration}", trimmed(stats.duration)):gsub("{radius}", tostring(math.floor(stats.radius + 0.5))):gsub("{count}", tostring(stats.count)))
end

-- The next rank of a hero's ability: its gold price and the mastery that unlocks
-- it. nil once the ability is maxed. Rarer heroes cost more to improve.
function Rules.AbilityUpgrade(hero, currentRank)
	if type(hero) == "string" then hero = Catalog.Heroes[hero] end
	local ranks = Catalog.AbilityRanks
	local nextRank = math.clamp(math.floor(number(currentRank, 1)), 1, ranks.max) + 1
	if nextRank > ranks.max then return nil end
	local multiplier = Catalog.Rarities[hero.rarity].abilityCost
	return { rank = nextRank, cost = math.floor(ranks.cost[nextRank] * multiplier + 0.5), mastery = ranks.mastery[nextRank] }
end

--==============================================================================
-- Rewards (reasons to come back)
--==============================================================================
-- State lives in profile.rewards: freeChestAt, loginDay, loginStreak, playDay,
-- playSeconds, playClaimed (index set) and collection (index set). All of it is
-- decided here from the server's clock, never from a number the client sent.
local DAY_SECONDS = 86400

function Rules.UtcDay(now)
	return math.floor(now / DAY_SECONDS)
end

function Rules.NewRewardsState()
	return { freeChestAt = 0, loginDay = -1, loginStreak = 0, playDay = -1, playSeconds = 0, playClaimed = {}, collection = {} }
end

-- Time played today; a state from an earlier day counts as no time and no claims.
function Rules.PlaytimeToday(state, now)
	if state.playDay ~= Rules.UtcDay(now) then return 0, {} end
	return state.playSeconds or 0, state.playClaimed or {}
end

-- The claim a player would get today, or nil when today's is already taken.
-- streak is the day of the cycle this claim continues from.
function Rules.LoginClaim(state, now)
	local rewards = Catalog.Rewards
	local today = Rules.UtcDay(now)
	local last = state.loginDay or -1
	if last >= today then return nil end
	local streak = 1
	if last >= 0 and today - last <= rewards.loginGraceDays then streak = (state.loginStreak or 0) + 1 end
	local index = (streak - 1) % #rewards.login + 1
	return { streak = streak, index = index, reward = rewards.login[index], today = today }
end

-- Everything the rewards panel and the lobby badge need, in one table.
-- pendingSeconds is time played since the profile was last written.
function Rules.RewardsStatus(profile, now, pendingSeconds)
	local rewards = Catalog.Rewards
	local state = profile.rewards or Rules.NewRewardsState()
	local status = { claimable = 0 }

	local remaining = math.max(0, (state.freeChestAt or 0) - now)
	status.freeChest = { ready = remaining == 0, remaining = remaining, chestId = rewards.freeChest.chestId, cooldown = rewards.freeChest.cooldown }
	if status.freeChest.ready then status.claimable += 1 end

	local claim = Rules.LoginClaim(state, now)
	status.login = { claimable = claim ~= nil, streak = state.loginStreak or 0, cycle = #rewards.login }
	if claim then
		status.login.nextIndex, status.login.nextStreak = claim.index, claim.streak
		status.claimable += 1
	else
		status.login.nextIndex = ((state.loginStreak or 0)) % #rewards.login + 1
	end

	local seconds, claimed = Rules.PlaytimeToday(state, now)
	seconds += math.max(0, pendingSeconds or 0)
	status.playtime = { seconds = seconds, gifts = {} }
	for index, gift in ipairs(rewards.playtime) do
		local entry = { index = index, minutes = gift.minutes, gold = gift.gold, xp = gift.xp, chest = gift.chest,
			claimed = claimed[index] == true, ready = seconds >= gift.minutes * 60 and claimed[index] ~= true }
		if entry.ready then status.claimable += 1 end
		table.insert(status.playtime.gifts, entry)
	end

	-- Membership lives on Roblox's servers, so the group reward is never counted
	-- as claimable here; the panel offers it and the server checks on claim.
	status.group = { claimed = state.groupClaimed == true, gold = rewards.group and rewards.group.gold or 0 }

	local owned = 0
	for _ in pairs(profile.heroes or {}) do owned += 1 end
	status.collection = { owned = owned, milestones = {} }
	local done = state.collection or {}
	for index, milestone in ipairs(rewards.collection) do
		local entry = { index = index, count = milestone.count, gold = milestone.gold, title = milestone.title,
			claimed = done[index] == true, ready = owned >= milestone.count and done[index] ~= true }
		if entry.ready then status.claimable += 1 end
		table.insert(status.collection.milestones, entry)
	end
	return status
end

--==============================================================================
-- Season pass
--==============================================================================
-- What a level pays on a track ("free" or "premium"): Gold, plus a chest on
-- the milestone levels and, at the top of the premium track, a title.
function Rules.SeasonReward(level, track)
	level = math.clamp(math.floor(number(level, 1)), 1, Catalog.Season.levels)
	if track == "premium" then
		local reward = { gold = 200 + level * 40 }
		if level % 5 == 0 then reward.chest = (level % 10 == 0) and (level == Catalog.Season.levels and "legendary" or "epic") or "rare" end
		if level == Catalog.Season.levels then reward.title = { id = "seasonPremium", pt = "Campeão da temporada", en = "Season champion" } end
		return reward
	end
	local reward = { gold = 80 + level * 20 }
	if level % 10 == 0 then reward.chest = "rare" end
	return reward
end

-- The season's name: the list cycles, season 1 is the first entry.
function Rules.SeasonTheme(id)
	local themes = Catalog.SeasonThemes
	return themes[(math.max(1, math.floor(number(id, 1))) - 1) % #themes + 1]
end

-- The XP that level `level` costs, and the total needed to reach it.
function Rules.SeasonLevelXp(level)
	level = math.clamp(math.floor(number(level, 1)), 1, Catalog.Season.levels)
	return Catalog.Season.firstXp + Catalog.Season.stepXp * (level - 1)
end

function Rules.SeasonThreshold(level)
	level = math.clamp(math.floor(number(level, 0)), 0, Catalog.Season.levels)
	return level * Catalog.Season.firstXp + Catalog.Season.stepXp * level * (level - 1) / 2
end

-- The player's season at a glance. `season` is the stored record
-- ({ id, xp, freeClaimed, premiumClaimed }); `owned` whether the premium
-- pass is held. Levels are claimed in order, so a claimed count is enough.
function Rules.SeasonStatus(season, owned)
	season = type(season) == "table" and season or {}
	local config = Catalog.Season
	local xp = math.max(0, math.floor(number(season.xp, 0)))
	local level = 0
	while level < config.levels and xp >= Rules.SeasonThreshold(level + 1) do level += 1 end
	local freeClaimed = math.clamp(math.floor(number(season.freeClaimed, 0)), 0, config.levels)
	local premiumClaimed = math.clamp(math.floor(number(season.premiumClaimed, 0)), 0, config.levels)
	local status = {
		id = season.id, level = level, xp = xp, maxLevel = config.levels,
		-- The bar of the level being climbed (the last one stays full).
		xpNeed = Rules.SeasonLevelXp(math.min(config.levels, level + 1)),
		xpInto = level >= config.levels and Rules.SeasonLevelXp(config.levels) or xp - Rules.SeasonThreshold(level),
		owned = owned == true, freeClaimed = freeClaimed, premiumClaimed = premiumClaimed,
		claimableFree = math.max(0, level - freeClaimed),
		claimablePremium = owned and math.max(0, level - premiumClaimed) or 0,
		upcoming = {},
	}
	status.claimable = status.claimableFree + status.claimablePremium
	-- The next few levels, whatever their state, for the panel's strip.
	for next = math.min(freeClaimed, premiumClaimed) + 1, math.min(config.levels, math.min(freeClaimed, premiumClaimed) + 6) do
		table.insert(status.upcoming, { level = next, reached = level >= next, free = Rules.SeasonReward(next, "free"), premium = Rules.SeasonReward(next, "premium"),
			freeClaimed = next <= freeClaimed, premiumClaimed = next <= premiumClaimed })
	end
	return status
end

--==============================================================================
-- Chests
--==============================================================================
-- Starters are never in a chest: a chest exists to bring you something new.
function Rules.ChestPool(rarity, kind)
	local pool = {}
	for _, id in ipairs(kind=="base" and Catalog.BaseOrder or Catalog.HeroOrder) do
		local hero = (kind=="base" and Catalog.Bases or Catalog.Heroes)[id]
		if hero.rarity == rarity and not hero.starter then table.insert(pool, id) end
	end
	return pool
end

-- Opens a chest from three random numbers in [0,1), so the outcome is a pure
-- function that can be tested against the published odds.
--   rarityRoll picks the rarity; heroRoll picks the hero inside it.
--   A hero you do not own yet is always preferred over one you do, so a chest
--   only hands you a duplicate once that rarity is complete.
--   pity counts legendary-chest openings without a top hero: when it reaches
--   the chest's threshold the next opening is guaranteed to be one.
-- Returns { rarity, heroId, duplicate, pity }.
function Rules.RollChest(chestId, rarityRoll, heroRoll, pity, owned)
	local chest = Catalog.Chests[chestId]
	assert(chest, "Unknown chest")
	owned = owned or {}
	rarityRoll = math.clamp(number(rarityRoll, 0), 0, 0.999999)
	heroRoll = math.clamp(number(heroRoll, 0), 0, 0.999999)
	local order, forced = Catalog.RarityOrder, false
	local floorIndex = 1
	if chest.pity and number(pity, 0) + 1 >= chest.pity.after then
		forced = true
		floorIndex = table.find(order, chest.pity.minimum) or 1
	end
	local total = 0
	for index, rarity in ipairs(order) do
		if index >= floorIndex then total += chest.odds[rarity] or 0 end
	end
	local target, chosen = rarityRoll * total, nil
	for index, rarity in ipairs(order) do
		local weight = if index >= floorIndex then (chest.odds[rarity] or 0) else 0
		if weight > 0 then
			chosen = rarity
			if target < weight then break end
			target -= weight
		end
	end
	local pool = Rules.ChestPool(chosen, chest.kind)
	local fresh = {}
	for _, id in ipairs(pool) do if not owned[id] then table.insert(fresh, id) end end
	local candidates = if #fresh > 0 then fresh else pool
	local heroId = candidates[math.floor(heroRoll * #candidates) + 1]
	local topIndex = table.find(order, chest.pity and chest.pity.minimum or "legendary") or #order
	return {
		rarity = chosen, heroId = chest.kind~="base" and heroId or nil, baseId = chest.kind=="base" and heroId or nil, itemId=heroId, duplicate = owned[heroId] == true,
		pity = forced, top = (table.find(order, chosen) or 1) >= topIndex,
	}
end

function Rules.BaseStats(id, level)
	local def=Catalog.Bases[id] or Catalog.Bases.outpost
	level=math.clamp(math.floor(number(level,1)),1,5)
	local growth=1+(level-1)*0.7
	return {id=def.id,level=level,style=def.style,income=math.floor(def.income*growth),
		hp=def.hp+(level-1)*12,damage=math.floor(def.damage*growth),range=30+(level-1)*3,
		wall=math.floor(def.wall*growth),regen=def.wall>0 and (5+level*3) or 0,
		soldier=math.floor(def.soldier*growth),interval=math.max(12,24-level*2),
		upgradeCost=Catalog.BaseUpgradeCosts[level] or 0}
end

--==============================================================================
-- Cards (the roguelike mode)
--==============================================================================
-- Three distinct cards, drawn by rarity weight and never one already at its
-- stack limit. Deterministic in (seed, wave, player) so a reconnect sees the
-- same offer. owned is a list of card ids, one entry per stack.
function Rules.CardOffers(seed, wave, playerIndex, owned)
	owned = owned or {}
	local counts = {}
	for _, id in ipairs(owned) do counts[id] = (counts[id] or 0) + 1 end
	local available = {}
	for _, id in ipairs(Catalog.CardOrder) do
		if (counts[id] or 0) < Catalog.Cards[id].maxStacks then table.insert(available, id) end
	end
	local state = math.abs(math.floor(number(seed, 0) + number(wave, 0) * 7919 + number(playerIndex, 1) * 104729)) % 2147483646 + 1
	local function nextRoll()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end
	local offers = {}
	while #offers < 3 and #available > 0 do
		local total = 0
		for _, id in ipairs(available) do total += Catalog.CardRarityWeight[Catalog.Cards[id].rarity] end
		local target = nextRoll() * total
		local pick = #available
		for index, id in ipairs(available) do
			target -= Catalog.CardRarityWeight[Catalog.Cards[id].rarity]
			if target < 0 then pick = index break end
		end
		table.insert(offers, table.remove(available, pick))
	end
	return offers
end

-- Waves after which a card is offered: every fifth, up to the last wave before
-- the final boss. Only the card mode offers any.
function Rules.CardWave(modeId, wave)
	local mode = Catalog.Modes[modeId]
	wave = math.floor(number(wave, 0))
	if not mode or not mode.cards or wave < 5 or wave % 5 ~= 0 then return false end
	return mode.waves > 0 and wave < mode.waves
end

-- The sum of every stacked card's stat changes.
-- Cards compound instead of adding: every copy multiplies what is already
-- there. Two +10% cards make x1.21 (+21%); a -10% card taken afterwards cuts
-- 10% of that larger number (x1.089), never a flat 10 points. The result is
-- still a bonus fraction per stat (x1.21 is 0.21), so every consumer reads it
-- exactly as before.
function Rules.CardTotals(owned)
	local factors = {}
	for _, id in ipairs(owned or {}) do
		local card = Catalog.Cards[id]
		for key, value in pairs(card and card.effects or {}) do factors[key] = (factors[key] or 1) * (1 + value) end
	end
	local totals = {}
	-- Rounded to nine places so 1.08 - 1 stays exactly 0.08 (a price is floored).
	for key, factor in pairs(factors) do totals[key] = math.floor((factor - 1) * 1e9 + 0.5) / 1e9 end
	return totals
end

return Rules
