-- Regenerates docs/HEROES.md straight from the real Catalog and Rules data,
-- so the hero reference in the repo can never drift from the game itself.
-- Run: .tools/luau/luau.exe tools/gen_heroes_doc.luau > docs/HEROES.md
local Catalog = require("../src/shared/Catalog")
local Rules = require("../src/shared/Rules")

local ATTACK_PT = {
	single = "único", splash = "área", chain = "corrente", beam = "feixe", dot = "queima contínua",
}

local function fmtPct(value) return tostring(math.floor(value * 100 + 0.5)) .. "%" end

local out = {}
local function line(text) table.insert(out, text or "") end

line("# Heróis")
line("")
line("Gerado por `tools/gen_heroes_doc.luau` a partir de `src/shared/Catalog.luau` e")
line("`src/shared/Rules.luau` — não edite este arquivo à mão, rode o gerador de novo.")
line("")
line("São 43 heróis em três raridades: Comum, Raro e Lendário. Heróis chegam")
line("pelos cinco baús do lobby ou pela compra direta na Loja Robux. Cada herói tem uma")
line("única habilidade, e é sempre a do herói no **slot 1** da formação que o")
line("comandante usa em combate — por isso o slot 1 é visualmente destacado na UI.")
line("Habilidades dos heróis lendários são **ultimates**: além do efeito principal,")
line("elas disparam um ou mais efeitos secundários (`extras`) no mesmo cast.")
line("")

for _, rarity in ipairs(Catalog.RarityOrder) do
	local rarityInfo = Catalog.Rarities[rarity]
	local count=0;for _,id in ipairs(Catalog.HeroOrder) do if Catalog.Heroes[id].rarity==rarity then count+=1 end end
	line("## " .. rarityInfo.name.pt .. " — " .. count .. " heróis")
	line("")
	line("| Herói | Custo (Ouro da partida) | Ataque | Dano | Alcance | Intervalo | Habilidade |")
	line("| --- | --- | --- | --- | --- | --- | --- |")
	for _, id in ipairs(Catalog.HeroOrder) do
		local hero = Catalog.Heroes[id]
		if hero.rarity == rarity then
			local ability = Catalog.Abilities[hero.ability]
			local abilityName = ability.name.pt .. (ability.ultimate and " ⚡ (ultimate)" or "")
			line(string.format("| **%s** — %s | %d | %s%s | %d | %d | %.2fs | %s |",
				hero.name.pt, hero.role.pt, hero.cost, ATTACK_PT[hero.attack] or hero.attack,
				hero.air and " (ar)" or "", hero.damage, hero.range, hero.interval, abilityName))
		end
	end
	line("")
end

line("## Habilidades")
line("")
line("Toda habilidade tem 5 ranks (`Catalog.AbilityRanks`); cada rank melhora poder")
line("e/ou duração em " .. fmtPct(Catalog.AbilityRanks.growth.power) .. " e reduz a recarga em até " ..
	fmtPct(-Catalog.AbilityRanks.growth.cooldown) .. ", com o custo em Ouro e a")
line("maestria exigida crescendo por rank. O multiplicador de custo de cada herói")
line("foi preservado na unificação (`hero.economy.abilityCost`)")
line("(`Rules.AbilityUpgrade`). Os valores abaixo são do **rank 1**.")
line("")
line("| Habilidade | Herói | Recarga | Descrição (rank 1) |")
line("| --- | --- | --- | --- |")
for _, abilityId in ipairs(Catalog.AbilityOrder) do
	local def = Catalog.Abilities[abilityId]
	local heroId
	for _, id in ipairs(Catalog.HeroOrder) do
		if Catalog.Heroes[id].ability == abilityId then heroId = id end
	end
	local text = Rules.AbilityText(def, 1, "pt")
	line(string.format("| %s%s | %s | %ds | %s |",
		def.name.pt, def.ultimate and " ⚡" or "", heroId and Catalog.Heroes[heroId].name.pt or "?", def.cooldown, text))
end
line("")

print(table.concat(out, "\n"))
