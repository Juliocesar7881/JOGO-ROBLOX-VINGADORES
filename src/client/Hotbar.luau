-- The match's hero bar (owner, 17/10: "o hud que mostra os heróis na partida
-- tá um pouco feio"): every slot a trading card in its rarity's colours, a
-- standing sunburst behind the hero, the slot's key in one corner, how many of
-- it stand on the field in the other, and the price in a gold pill with a coin.
-- A hero the match Gold cannot pay for dims under a veil with its price in red;
-- the hero in hand lifts with a white frame and a gold line. Purely
-- presentation: the price is Rules.PlacementCost, the one the server charges.
local Hotbar = {}

-- ctx: UI, C, Catalog, heroPortrait, colorFor, hover (the hero tooltip).
function Hotbar.card(ctx, parent, id, index, width, height, callback)
	local UI, C, Catalog = ctx.UI, ctx.C, ctx.Catalog
	local def = Catalog.Heroes[id]
	local rarity = Catalog.Rarities[def.rarity]
	local tint = rarity and UI.color(rarity.color) or ctx.colorFor(id)
	local small = height < 62
	local button = UI.secondary(parent, "", callback, {
		Name = "HeroCard_" .. id, LayoutOrder = index,
		Size = UDim2.fromOffset(width, height), BackgroundColor3 = tint:Lerp(C.background, 0.2),
	})
	local light = button:FindFirstChildOfClass("UIGradient")
	if light then light.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(120, 120, 130)) end
	UI.cardSkin(button, tint)
	-- A standing sunburst: the bar is in view all battle long, so it stays still.
	UI.cardBackdrop(button, tint, def.rarity, nil, { still = true })
	UI.stroke(button, index == 1 and C.gold or tint, index == 1 and 3.5 or 2.5)
	local priceH = small and 18 or 22
	ctx.heroPortrait(button, id, { Position = UDim2.fromOffset(3, small and 2 or 4), Size = UDim2.new(1, -6, 1, -(priceH + (small and 4 or 8))) })
	local z = (button.ZIndex or 1) + 3
	-- The veil over a hero the Gold cannot pay for yet.
	local veil = UI.frame(button, { Name = "CostVeil", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 1, Active = false, ZIndex = z - 1 })
	UI.corner(veil, 14)
	-- The price: a coin and the number in a dark pill along the bottom edge.
	local pill = UI.frame(button, { Name = "PricePill", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -3), Size = UDim2.new(1, -8, 0, priceH),
		BackgroundColor3 = C.ink, BackgroundTransparency = 0.05, Active = false, ZIndex = z })
	UI.corner(pill, priceH)
	UI.stroke(pill, tint:Lerp(Color3.new(1, 1, 1), 0.3), 1.5)
	local coinSize = priceH - 6
	UI.icon(pill, "coin", C.gold, { Name = "PriceCoin", Position = UDim2.new(0, 3, 0.5, -coinSize / 2), Size = UDim2.fromOffset(coinSize, coinSize), ZIndex = z + 1 })
	local price = UI.label(pill, tostring(def.cost), { Name = "EnergyCost", Position = UDim2.fromOffset(coinSize + 2, 0), Size = UDim2.new(1, -(coinSize + 6), 1, 0),
		TextColor3 = C.gold, TextSize = small and 14 or 17, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = z + 1 })
	UI.outline(price, 2)
	-- The slot's key (the leader wears a star) and how many stand on the field.
	local badgeSize = small and 18 or 22
	local badge = UI.label(button, index == 1 and "★" or tostring(index), { Name = "SlotNumber", Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(badgeSize, badgeSize),
		BackgroundColor3 = index == 1 and C.gold or C.ink, BackgroundTransparency = 0.05, TextSize = small and 12 or 14,
		TextColor3 = index == 1 and C.ink or C.text, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = z })
	UI.corner(badge, badgeSize)
	UI.stroke(badge, index == 1 and C.ink or tint, 1.5)
	local count = UI.label(button, "", { Name = "PlacedCount", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(small and 26 or 32, small and 16 or 19),
		BackgroundColor3 = C.green:Lerp(C.ink, 0.35), BackgroundTransparency = 0.05, TextSize = small and 12 or 14, Font = UI.Fonts.display,
		TextXAlignment = Enum.TextXAlignment.Center, Visible = false, ZIndex = z })
	UI.corner(count, 9)
	local line = UI.frame(button, { Name = "SelectionLine", Position = UDim2.new(0, 6, 1, -2), Size = UDim2.new(1, -12, 0, 3), BackgroundColor3 = C.gold, BackgroundTransparency = 1, ZIndex = z })
	-- Hovering a slot tells what the hero does now: damage, range, speed, traits.
	if ctx.hover then UI.hover(button, function(box) ctx.hover(box, id) end, 320) end
	local border = button:FindFirstChild("Border")
	return { button = button, price = price, line = line, count = count, veil = veil, tint = tint,
		border = border, borderColor = border and border.Color, borderThickness = border and border.Thickness }
end

-- Every slot as the match stands: selected, affordable, how many placed.
-- ctx: UI, C, Catalog, Rules, profile (the commander's), selected (hero id).
function Hotbar.update(ctx, cards, match, ownerId)
	local UI, C, Catalog, Rules = ctx.UI, ctx.C, ctx.Catalog, ctx.Rules
	local totals = Rules.CardTotals(match.cards)
	for id, card in pairs(cards or {}) do
		local selected = ctx.selected == id
		card.button.BackgroundColor3 = card.tint:Lerp(C.background, selected and 0.05 or 0.2)
		card.line.BackgroundTransparency = selected and 0 or 1
		-- The hero in hand wears a thick white frame on the bar.
		if card.border then
			card.border.Color = selected and Color3.new(1, 1, 1) or card.borderColor
			card.border.Thickness = selected and 4.5 or card.borderThickness
		end
		local cost = Rules.PlacementCost(Catalog.Heroes[id], ctx.profile, totals)
		local affordable = (match.cash or 0) >= cost
		local text = tostring(cost)
		if card.price.Text ~= text then card.price.Text = text end
		card.price.TextColor3 = affordable and C.gold or C.red
		card.veil.BackgroundTransparency = affordable and 1 or 0.45
		local placed = 0
		for _, tower in ipairs(match.towers or {}) do if tower.ownerId == ownerId and tower.heroId == id then placed += 1 end end
		card.count.Visible = placed > 0
		card.count.Text = "x" .. tostring(placed)
		card.count.TextColor3 = C.text
	end
end

return Hotbar
