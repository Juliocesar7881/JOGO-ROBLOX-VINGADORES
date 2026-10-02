-- Appended to the match simulation by `python tests/test_match_simulation.py --sweep heroes`.
-- Every hero is paired with Iron Man, a middling all-rounder that can hit flyers,
-- and plays ranked mode: ranked is the discriminating mode, normal is a walkover for
-- any roster. Alone, a ground-only hero would just be blamed for the flyers it can
-- never hit. Compare each row with the Iron Man baseline: a hero well above it
-- earns more than its price, one below it is being carried by its partner.
local unlocked = { campaign = { manhattan = { normal = true, ranked = true }, hydra = { normal = true, ranked = true }, wakanda = { normal = true, ranked = true }, latveria = { normal = true, ranked = true } } }
local MAPS = Rules.MapsForMode("ranked")
local rows = {}
local function wanted(heroId)
	if not ONLY_HEROES then return true end
	return table.find(ONLY_HEROES, heroId) ~= nil
end
for _, heroId in ipairs(Catalog.HeroOrder) do
	if not wanted(heroId) then continue end
	local hero = Catalog.Heroes[heroId]
	local reached, minutes = 0, 0
	for _, mapId in ipairs(MAPS) do
		local run = simulate({ mapId = mapId, modeId = "ranked", profile = unlocked, loadout = { heroId, "ironman" } })
		reached += run.results.waves
		minutes += run.seconds / 60
	end
	table.insert(rows, { id = heroId, rarity = hero.rarity, cost = hero.cost, kind = hero.attack, waves = reached / #MAPS, minutes = minutes / #MAPS })
end
print(string.format("%-14s %-10s %5s  %-7s %s", "heroi", "raridade", "custo", "ataque", "ondas (ranked, media dos mapas)"))
local byRarity = {}
for _, row in ipairs(rows) do
	print(string.format("%-14s %-10s %5d  %-7s %5.1f %6.1f min  %s", row.id, row.rarity, row.cost, row.kind, row.waves, row.minutes, string.rep("#", math.floor(row.waves / 2))))
	byRarity[row.rarity] = byRarity[row.rarity] or { sum = 0, count = 0 }
	byRarity[row.rarity].sum += row.waves
	byRarity[row.rarity].count += 1
end
print("")
for _, rarity in ipairs(Catalog.RarityOrder) do
	local entry = byRarity[rarity]
	if entry then print(string.format("%-10s media %5.1f ondas", rarity, entry.sum / entry.count)) end
end
