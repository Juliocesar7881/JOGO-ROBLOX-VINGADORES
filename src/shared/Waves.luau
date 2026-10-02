--!nonstrict
local Catalog = require(if script then script.Parent.Catalog else "./Catalog")
local Rules = require(if script then script.Parent.Rules else "./Rules")
local Waves = {}

-- Stable generator: no server/client clock or global random state affects a wave.
--
-- A run's length comes from Rules.WaveCount (per map for the campaign, endless
-- in the competitive arena). A boss walks in on every tenth wave and the last
-- wave of a fixed run brings that map's own boss at full strength. Enemies
-- carry no lobby Gold: they drop match Gold (Rules.KillCash) when they die.
function Waves.Generate(mapId, modeId, wave, partySize, seed, difficultyId)
	local map, mode = Catalog.Maps[mapId], Catalog.Modes[modeId]
	assert(map and mode, "Unknown map or mode")
	-- A campaign difficulty (Catalog.Difficulties) scales health and pace;
	-- the server has already refused one the party may not use.
	local difficulty = Catalog.Difficulties[difficultyId or "normal"]
	assert(difficulty, "Unknown difficulty")
	assert(Rules.IsFinite(wave) and wave >= 1 and wave == math.floor(wave), "Invalid wave")
	assert(Rules.IsFinite(partySize) and partySize >= 1 and partySize <= 4 and partySize == math.floor(partySize), "Invalid party size")
	local total = Rules.WaveCount(modeId, mapId)
	if total > 0 and wave > total then return {} end
	seed = if Rules.IsFinite(seed) then math.floor(seed) else 0
	local randomState = (math.abs(seed) + wave * 7919 + map.chapter * 97) % 2147483647
	local function random(count)
		randomState = (randomState * 48271 + 1) % 2147483647
		return randomState % count + 1
	end
	local result = {}
	local partyScale = ({ 1, 1.65, 2.25, 2.85 })[partySize]
	-- Training climbs at half speed, so its 12 waves stay gentle.
	local progress = if modeId == "tutorial" then math.floor((math.min(wave, 20) + 1) / 2) else wave
	-- Health climbs steadily, then a little faster once the late waves begin.
	local growth = 1 + (progress - 1) * 0.045 + math.max(0, progress - 30) * 0.012
	local hpMultiplier = mode.hpMultiplier * partyScale * growth * (map.difficulty or 1) * difficulty.hpMultiplier
	-- Competitive never ends: past wave 50 health keeps climbing while the
	-- head count stays capped, so the arena gets harder, not more crowded.
	if modeId == "ranked" and wave > 50 then hpMultiplier *= 1.045 ^ math.min(250, wave - 50) end
	-- A mutated wave changes the whole wave (see Catalog.Mutations).
	local mutation = Catalog.Mutations[Rules.WaveMutation(modeId, mapId, wave, seed) or ""]
	if mutation then hpMultiplier *= mutation.hp or 1 end
	local function pathFor(index)
		if mapId == "hydra" then return (wave - 1) % #map.paths + 1 end
		if mapId == "latveria" then
			return if wave >= 15 and wave % 5 == 0 and index % 4 == 0 then 3 else (index - 1) % 2 + 1
		end
		return (index - 1) % #map.paths + 1
	end
	local function add(enemyId, index, override)
		if wave>=4 and index%2==0 and modeId~="tutorial" then
			enemyId=(Catalog.MapEnemyVariants[mapId] or {})[enemyId] or enemyId
		end
		local enemy = Catalog.Enemies[enemyId]
		table.insert(result, {
			enemyId = enemyId,
			delay = if index == 1 then 0 else (if modeId == "tutorial" then 1.25 else math.max(0.35, 0.85 - wave * 0.011)),
			pathIndex = pathFor(index), hpMultiplier = hpMultiplier * (override or 1),
			speedMultiplier = difficulty.speedMultiplier * (mutation and mutation.speed or 1), rewardless = false,
			cash = math.floor(Rules.KillCash(enemyId) * (mutation and mutation.cash or 1) + 0.5),
		})
	end
	local count = if modeId == "tutorial" then 6 + wave else math.min(100, 9 + math.floor(wave * 1.4))
	if mutation and mutation.count then count = math.min(100, math.floor(count * mutation.count)) end
	local pool = { "zombie", "zombie", "zombie" }
	local ranked = modeId == "ranked"
	if wave >= 3 then table.insert(pool, "runner") end
	if wave >= 5 then table.insert(pool, "brute") end
	if modeId ~= "tutorial" then
		if wave >= (ranked and 5 or 7) then table.insert(pool, "armored") end
		if wave >= 9 then table.insert(pool, "flyer") end
		if wave >= (ranked and 10 or 14) then table.insert(pool, "stealth") end
		if wave >= 17 then table.insert(pool, "support") end
		if wave >= (ranked and 8 or 12) then table.insert(pool, "splitter") end
		if wave >= (ranked and 14 or 18) then table.insert(pool, "saboteur") end
		if wave >= 21 then table.insert(pool, "summoner") end
		-- The late game leans on the heavy families.
		if wave >= 28 then table.insert(pool, "armored"); table.insert(pool, "brute") end
		if wave >= 30 then table.insert(pool, "splitter") end
		if wave >= 33 then table.insert(pool, "saboteur") end
		if wave >= 36 then table.insert(pool, "flyer"); table.insert(pool, "stealth"); table.insert(pool, "summoner") end
		if ranked and wave >= 20 then table.insert(pool, "armored"); table.insert(pool, "support") end
	elseif wave >= 12 then
		table.insert(pool, "flyer")
	end
	for index = 1, count do add(pool[random(#pool)], index) end
	-- Bosses: one on every tenth wave, the map's own boss on the last.
	if modeId == "tutorial" then
		if Rules.IsFinalWave(modeId, wave, mapId) then add("lizard", #result + 1, 0.25) end
	elseif Rules.IsBossWave(modeId, wave, mapId) then
		local override
		if Rules.IsFinalWave(modeId, wave, mapId) then override = 1.2
		elseif modeId == "ranked" then override = 1
		else override = 0.3 + wave * 0.012 end
		add(Rules.BossId(wave, mapId, modeId), #result + 1, override)
	end
	return result
end

function Waves.Threats(specs)
	local flags = { air = false, stealth = false, armor = false, boss = false }
	local paths = {}
	for _, spec in specs do
		local enemy = Catalog.Enemies[spec.enemyId]
		flags.air = flags.air or enemy.air
		flags.stealth = flags.stealth or enemy.stealth
		flags.armor = flags.armor or enemy.armor >= 0.3
		flags.boss = flags.boss or enemy.boss
		paths[spec.pathIndex] = true
	end
	flags.paths = paths
	return flags
end

return Waves
