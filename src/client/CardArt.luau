--!nonstrict
-- How a roguelike card looks and reads. The medallion is drawn from what the
-- card does (a sword for damage, a bow for attack speed, a ring for range, a
-- bank for Gold...), every number is green when it helps and red when it
-- costs, and each stat shows the total it would reach. The corner panel keeps
-- the running totals in view. Pure presentation: Rules.CardTotals does the
-- maths (every copy multiplies what is already there).
local CardArt = {}

-- Stats in the order a player reads them. `color` tints the medallion glyph.
local GOLD, CORAL, GREEN = Color3.fromRGB(255, 210, 63), Color3.fromRGB(255, 138, 61), Color3.fromRGB(88, 224, 79)
local BLUE, VIOLET, RED, CREAM = Color3.fromRGB(63, 169, 255), Color3.fromRGB(169, 112, 255), Color3.fromRGB(255, 77, 94), Color3.fromRGB(255, 241, 204)
local STATS = {
	{ key = "damage", icon = "sword", color = CORAL, pt = "DANO", en = "DAMAGE" },
	{ key = "speed", icon = "bow", color = GOLD, pt = "VELOCIDADE", en = "ATTACK SPEED" },
	{ key = "range", icon = "ring", color = GREEN, pt = "ALCANCE", en = "RANGE" },
	{ key = "area", icon = "ring", color = BLUE, pt = "ÁREA", en = "AREA" },
	{ key = "pierce", icon = "sword", color = CREAM, pt = "PERFURAÇÃO", en = "PIERCING" },
	{ key = "bossDamage", icon = "skull", color = RED, pt = "CONTRA CHEFES", en = "VS BOSSES" },
	{ key = "airDamage", icon = "wing", color = BLUE, pt = "CONTRA VOADORES", en = "VS FLYERS" },
	{ key = "stealthDamage", icon = "eye", color = VIOLET, pt = "CONTRA CAMUFLADOS", en = "VS HIDDEN" },
	{ key = "killGold", icon = "bank", color = GOLD, pt = "OURO POR ABATE", en = "KILL GOLD" },
	{ key = "energyIncome", icon = "bank", color = GOLD, pt = "RENDA POR ONDA", en = "WAVE INCOME" },
	{ key = "discount", icon = "bank", color = GREEN, pt = "DESCONTO", en = "DISCOUNT" },
	{ key = "cooldown", icon = "clock", color = CREAM, pt = "RECARGA DO PODER", en = "POWER RECHARGE" },
	{ key = "abilityPower", icon = "sparkle", color = VIOLET, pt = "FORÇA DO PODER", en = "POWER STRENGTH" },
	{ key = "supportRange", icon = "ring", color = GREEN, pt = "ALCANCE DE APOIO", en = "SUPPORT RANGE" },
}
CardArt.STATS = STATS

local function percent(value)
	local whole = math.floor(math.abs(value) * 100 + 0.5)
	return (value >= 0 and "+" or "-") .. whole .. "%"
end
CardArt.percent = percent

local function times(bonus)
	return string.format("x%.2f", 1 + bonus)
end
CardArt.times = times

-- The glyph and colour of a card's medallion.
function CardArt.glyph(def)
	local instant = def.instant or {}
	if instant.gamble then return "dice", CREAM end
	if instant.energy then return "bank", GOLD end
	if instant.heal or instant.maxHealth then return "heart", RED end
	for _, stat in ipairs(STATS) do
		if def.effects and def.effects[stat.key] then return stat.icon, stat.color end
	end
	return "cards", VIOLET
end

-- One row per thing the card changes: { icon, color, label, text, good, now,
-- after }. `now` and `after` are the totals (x1.10 -> x1.21) before and after
-- taking this card on top of `owned`.
-- `copies` (default 1) shows a stack of the same card: x2 of +10% is +21%.
function CardArt.rows(Rules, def, owned, T, copies)
	local rows = {}
	local before = Rules.CardTotals(owned)
	local with = table.clone(owned or {})
	table.insert(with, def.id)
	local after = Rules.CardTotals(with)
	for _, stat in ipairs(STATS) do
		local value = def.effects and def.effects[stat.key]
		if value then
			local shown = (copies and copies > 1) and ((1 + value) ^ copies - 1) or value
			table.insert(rows, { icon = stat.icon, color = stat.color, label = T(stat.pt, stat.en), text = percent(shown), good = value >= 0,
				now = 1 + (before[stat.key] or 0), after = 1 + (after[stat.key] or 0) })
		end
	end
	local instant = def.instant or {}
	if instant.energy then table.insert(rows, { icon = "bank", color = GOLD, label = T("OURO", "GOLD"), text = "+" .. instant.energy, good = true }) end
	if instant.heal then table.insert(rows, { icon = "heart", color = RED, label = T("VIDA DA BASE", "BASE HEALTH"), text = "+" .. instant.heal, good = true }) end
	if instant.maxHealth then table.insert(rows, { icon = "heart", color = RED, label = T("VIDA MÁXIMA", "MAX HEALTH"), text = "+" .. instant.maxHealth, good = true }) end
	if instant.gamble then table.insert(rows, { icon = "dice", color = CREAM, label = T("50% GANHA / 50% PERDE", "50% WIN / 50% LOSE"), text = "+600 / -200", good = true, mixed = true }) end
	return rows
end

-- The round emblem on top of a card.
function CardArt.medallion(UI, parent, def, tint, size, properties)
	local glyph, glyphColor = CardArt.glyph(def)
	local frame = UI.frame(parent, {
		Name = "CardMedallion", BackgroundColor3 = tint:Lerp(UI.Colors.ink, 0.62), Size = UDim2.fromOffset(size, size),
	})
	for key, value in pairs(properties or {}) do frame[key] = value end
	UI.corner(frame, math.floor(size / 2))
	UI.stroke(frame, tint, math.max(3, size * 0.06))
	UI.shade(frame, 90, 0.3)
	UI.icon(frame, glyph, glyphColor, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(size * 0.62, size * 0.62),
		ZIndex = (properties and properties.ZIndex or 1) + 1,
	})
	return frame
end

-- A bar for one effect: icon, name and the signed number in green or red.
function CardArt.chip(UI, parent, row, width, height, textSize, zIndex)
	local C = UI.Colors
	local tint = row.good and C.green or C.red
	local chip = UI.frame(parent, { Name = "CardEffect", Size = UDim2.fromOffset(width, height), BackgroundColor3 = C.ink, BackgroundTransparency = 0.25, ZIndex = zIndex })
	UI.corner(chip, math.floor(height / 2))
	UI.stroke(chip, tint, 2)
	UI.icon(chip, row.icon, row.color, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 6, 0.5, 0), Size = UDim2.fromOffset(height - 8, height - 8), ZIndex = (zIndex or 1) + 1 })
	UI.label(chip, row.label, { Name = "EffectName", Position = UDim2.fromOffset(height + 2, 0), Size = UDim2.new(1, -height - 6 - math.floor(width * 0.34), 1, 0), TextSize = textSize - 3, Font = UI.Fonts.bold, TextColor3 = C.muted, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = (zIndex or 1) + 1 })
	UI.label(chip, row.text, { Name = "EffectValue", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 0), Size = UDim2.new(0, math.floor(width * 0.34), 1, 0), TextSize = textSize + 2, Font = UI.Fonts.display, TextColor3 = tint, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = (zIndex or 1) + 1 })
	return chip
end

-- The totals of every card taken: icon, name and x1.21 (green at 1x or more,
-- red below). Returns how many rows were drawn.
function CardArt.totalRows(UI, Rules, T, parent, cards, rowH, textSize, maxRows, width)
	local C = UI.Colors
	local totals = Rules.CardTotals(cards)
	local drawn, hidden = 0, 0
	for _, stat in ipairs(STATS) do
		local bonus = totals[stat.key]
		if bonus and math.abs(bonus) > 1e-9 then
			if drawn >= maxRows then
				hidden += 1
			else
				drawn += 1
				local good = 1 + bonus >= 1
				local row = UI.frame(parent, { Name = "CardTotal_" .. stat.key, Size = UDim2.new(1, 0, 0, rowH), BackgroundColor3 = C.ink, BackgroundTransparency = 0.3, LayoutOrder = drawn })
				UI.corner(row, math.floor(rowH / 2))
				UI.stroke(row, good and C.green or C.red, 1.5)
				UI.icon(row, stat.icon, stat.color, { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 5, 0.5, 0), Size = UDim2.fromOffset(rowH - 8, rowH - 8) })
				UI.label(row, T(stat.pt, stat.en), { Name = "TotalName", Position = UDim2.fromOffset(rowH, 0), Size = UDim2.new(1, -rowH - 54, 1, 0), TextSize = textSize - 2, Font = UI.Fonts.bold, TextColor3 = C.muted })
				UI.label(row, times(bonus), { Name = "TotalValue", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 0), Size = UDim2.fromOffset(52, rowH), TextSize = textSize + 1, Font = UI.Fonts.display, TextColor3 = good and C.green or C.red, TextXAlignment = Enum.TextXAlignment.Right })
			end
		end
	end
	return drawn, hidden
end

return CardArt
