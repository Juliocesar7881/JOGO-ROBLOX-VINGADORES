-- Appended to the match simulation by `python tests/test_match_simulation.py --sweep`.
-- Not part of the test suite: it prints how the bot fares on every map and mode
-- with three rosters, so the balance can be read as a table instead of guessed.
local unlocked = { campaign = { manhattan = { normal = true, ranked = true } } }
local ROSTERS = {
	{ name = "iniciais", loadout = { "ironman", "hawkeye" } },
	{ name = "decente", loadout = { "ironman", "hawkeye", "hulk", "thor", "widow" } },
	{ name = "forte", loadout = { "ironman", "widow", "thor", "ghostrider", "silversurfer" } },
}
local totals = {}
for _, roster in ipairs(ROSTERS) do
	print("== elenco: " .. roster.name .. " ==")
	for _, modeId in ipairs({ "normal", "ranked", "cards" }) do
		for _, mapId in ipairs(Catalog.MapOrder) do
			local run = simulate({ mapId = mapId, modeId = modeId, profile = unlocked, loadout = roster.loadout })
			print(string.format("%-7s %-9s onda %2d  %5.1f min  nucleo %3d/%d  pico %3d  %s",
				modeId, mapId, run.results.waves, run.seconds / 60, run.match.baseHP, run.match.maxBaseHP, run.peakEnemies,
				run.results.victory and "VITORIA" or "derrota"))
			local key = roster.name .. "/" .. modeId
			totals[key] = totals[key] or { waves = 0, minutes = 0, wins = 0, runs = 0 }
			local t = totals[key]
			t.waves += run.results.waves; t.minutes += run.seconds / 60; t.runs += 1
			if run.results.victory then t.wins += 1 end
		end
	end
end
print("")
for _, roster in ipairs(ROSTERS) do
	for _, modeId in ipairs({ "normal", "ranked", "cards" }) do
		local t = totals[roster.name .. "/" .. modeId]
		print(string.format("%-9s %-7s media %4.1f ondas, %4.1f min, %d/%d vitorias", roster.name, modeId, t.waves / t.runs, t.minutes / t.runs, t.wins, t.runs))
	end
end
