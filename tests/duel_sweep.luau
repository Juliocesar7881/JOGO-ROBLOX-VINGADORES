-- Appended to the match simulation by `python tests/test_match_simulation.py --sweep duel`.
-- A controlled bout: every hero gets the same Energy budget, spends all of it on
-- towers of its own kind (each taken to level three) and faces the same ranked wave.
-- No ability, no economy to mismanage. The score is the share of the wave's total
-- health that the towers manage to destroy, which still tells heroes apart when
-- nobody holds the line.
local unlocked = { campaign = { manhattan = { normal = true, ranked = true } } }
local BUDGETS = { 3000, 5000, 7000 }
local WAVE = 30
local MAPS = { "manhattan", "gamma" }

local function bout(heroId, budget, mapId)
	local player = newPlayer(1)
	local profile = newProfile(unlocked)
	profile.loadout = { heroId, "ironman" }
	local match = MatchService.new(Config, Catalog, Rules, Waves, newProfiles(profile), newWorld(), newRemotes({}), function() end)
	assert(match:Start({ player }, mapId, "normal", "duel"))
	local p = match.participants[player.UserId]
	p.cash = budget
	local hero = Catalog.Heroes[heroId]
	local placed = 0
	while placed < 16 do
		local snapshot = match:Snapshot(player)
		local need = hero.cost + math.floor(hero.cost * 0.9) + math.floor(hero.cost * 1.4)
		if p.cash < need then break end
		local done = false
		for _, spot in ipairs(buildSpots(mapId)) do
			local crowded = false
			for _, tower in ipairs(snapshot.towers) do
				if (tower.position - spot.point).Magnitude < 9 then crowded = true break end
			end
			if not crowded then
				local ok, reply = match:Handle(player, "PlaceTower", { heroId = heroId, position = spot.point })
				if ok then
					match:Handle(player, "UpgradeTower", { towerId = reply.towerId })
					match:Handle(player, "UpgradeTower", { towerId = reply.towerId })
					placed += 1
					done = true
					break
				end
			end
		end
		if not done then break end
	end
	match.wave, match.completedWaves = WAVE - 1, WAVE - 1
	match.phase = "Preparing"
	match.prepRemaining = 0
	local dealt = 0
	local original = match._recordHit
	match._recordHit = function(self, enemy, amount)
		dealt += math.min(amount, math.max(0, enemy.hp + amount))
		return original(self, enemy, amount)
	end
	match:Step(0.1) -- begins the wave
	local total = 0
	for _, spec in ipairs(match.pendingSpawns) do total += Catalog.Enemies[spec.enemyId].hp * spec.hpMultiplier end
	local steps = 0
	while match.running and match.phase == "Wave" and steps < 4000 do
		steps += 1
		match:Step(0.1)
	end
	return placed, math.min(100, dealt / total * 100)
end

print(string.format("%-14s %-10s %5s  %s", "heroi", "raridade", "custo", "% do HP da onda 30 destruido (orcamento 3000 / 5000 / 7000)"))
local byRarity = {}
for _, heroId in ipairs(Catalog.HeroOrder) do
	local hero = Catalog.Heroes[heroId]
	local cells, sums = {}, {}
	for _, budget in ipairs(BUDGETS) do
		local total, towers = 0, 0
		for _, mapId in ipairs(MAPS) do
			local placed, hp = bout(heroId, budget, mapId)
			total += hp; towers += placed
		end
		table.insert(cells, string.format("%5.1f%% (%2d torres)", total / #MAPS, towers / #MAPS))
		table.insert(sums, total / #MAPS)
	end
	print(string.format("%-14s %-10s %5d  %s   %s   %s", heroId, hero.rarity, hero.cost, cells[1], cells[2], cells[3]))
	byRarity[hero.rarity] = byRarity[hero.rarity] or { a = 0, b = 0, c = 0, n = 0 }
	local r = byRarity[hero.rarity]
	r.a += sums[1]; r.b += sums[2]; r.c += sums[3]; r.n += 1
end
print("")
for _, rarity in ipairs(Catalog.RarityOrder) do
	local r = byRarity[rarity]
	print(string.format("%-10s media %5.1f / %5.1f / %5.1f", rarity, r.a / r.n, r.b / r.n, r.c / r.n))
end
