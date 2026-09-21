-- Effective damage per Energy at level one, so heroes of one rarity can be
-- compared with each other and with the next rarity up. Area and chain attacks
-- are credited with the extra targets they typically reach; nothing here is a
-- rule of the game, it only informs how the catalog numbers were chosen.
local Catalog = require("../src/shared/Catalog")

local function targets(hero)
	local attack = hero.attack
	if attack == "splash" then return 1 + (hero.splash or 6) / 4.5 end
	if attack == "chain" then return 1 + 0.7 * ((hero.chain or 3) - 1) end
	if attack == "beam" then return 1 + (hero.beamWidth or 3) / 1.6 end
	if attack == "dot" then return 1 + (hero.splash or 6) / 4.5 end
	return 1
end

local rows = {}
for _, id in ipairs(Catalog.HeroOrder) do
	local hero = Catalog.Heroes[id]
	local perHit = hero.damage * (attackDot == nil and 1 or 1)
	if hero.attack == "dot" then perHit = hero.damage * (1 + 0.2 * (hero.dotDuration or 3)) end
	if hero.stompEvery then perHit = perHit * (1 + (0.6 / hero.stompEvery)) end
	local dps = perHit / hero.interval * targets(hero)
	local utility = 1
	if hero.air then utility += 0.12 end
	if hero.reveal then utility += 0.1 end
	if hero.support then utility += 0.08 end
	if (hero.slow or 0) > 0 then utility += 0.06 end
	if hero.armorPierce then utility += hero.armorPierce * 0.5 end
	table.insert(rows, { id = id, rarity = hero.rarity, cost = hero.cost, dps = dps * utility, ratio = dps * utility / hero.cost })
end
local byRarity = {}
print(string.format("%-14s %-10s %5s %8s %10s", "heroi", "raridade", "custo", "dps ef.", "dps/energia"))
for _, row in ipairs(rows) do
	print(string.format("%-14s %-10s %5d %8.1f %10.3f", row.id, row.rarity, row.cost, row.dps, row.ratio))
	byRarity[row.rarity] = byRarity[row.rarity] or { sum = 0, count = 0 }
	byRarity[row.rarity].sum += row.ratio; byRarity[row.rarity].count += 1
end
print("")
for _, rarity in ipairs(Catalog.RarityOrder) do
	local entry = byRarity[rarity]
	print(string.format("%-10s media dps/energia %.3f", rarity, entry.sum / entry.count))
end
