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

function Rules.TowerLimit(size)
	return ({ 16, 12, 10, 8 })[math.clamp(math.floor(number(size, 1)), 1, 4)]
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
	return {
		damageBonus = math.min(0.15, math.floor(masteryLevel / 2) * 0.01 + (talents.towerPower or 0) * 0.01),
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
function Rules.CardTotals(owned)
	local totals = {}
	for _, id in ipairs(owned or {}) do
		local card = Catalog.Cards[id]
		for key, value in pairs(card and card.effects or {}) do totals[key] = (totals[key] or 0) + value end
	end
	return totals
end

return Rules
