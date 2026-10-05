-- The battle's own panels, split out of init.client to keep that script
-- small: the selected tower's panel, the upgrade boards over your towers, the
-- card choice, the base upgrade and the results screen. Every number shown
-- is one the server sent; every button is an intent through ctx.act.
local CardArt = require(script.Parent:WaitForChild("CardArt"))
local MatchHud = {}

function MatchHud.new(ctx)
	local Catalog, Rules, UI, C, kit = ctx.Catalog, ctx.Rules, ctx.UI, ctx.C, ctx.kit
	local T, L, number, player, act, audio, celebrate = ctx.T, ctx.L, ctx.number, ctx.player, ctx.act, ctx.audio, ctx.celebrate
	local main, overlays, at, dims, screenSize, sizeClass, mobile = ctx.main, ctx.overlays, ctx.at, ctx.dims, ctx.screenSize, ctx.sizeClass, ctx.mobile
	local heroName, colorFor, mapName, modeName, profile = ctx.heroName, ctx.colorFor, ctx.mapName, ctx.modeName, ctx.profile
	local activeMatch, levelProgress, welcomePanel = ctx.activeMatch, ctx.levelProgress, ctx.welcomePanel
	local currentMatchLayout, closeTowerPanel, selectTower = ctx.currentMatchLayout, ctx.closeTowerPanel, ctx.selectTower

	-- Two arrangements of the same controls, chosen by UI.matchLayout: a single
	-- tall column where the screen has height to spare, and a short two-row
	-- panel for a phone on its side, where the old 306px column started above
	-- the top of the screen and took the upgrade button with it.
	local function towerStatsText(tower, wide)
		local now, nextStats = tower.base or tower, tower.next
		local function whole(v) return number(math.floor(v + 0.5)) end
		local function tenth(v) return string.format("%.1f", v) end
		local function rate(v) return string.format("%.2f", v) end
		local function percent(v) return math.floor(v * 100 + 0.5) .. "%" end
		-- One stat as "now -> next (+n%)": the next value in green, as the server sent it.
		local function line(label, a, b, format, relative)
			local text = '<font color="#CED8FF">' .. label .. "</font>  " .. format(a or 0)
			if b and math.abs((b or 0) - (a or 0)) > 0.001 then
				text ..= ' <font color="#6BE38A">→ ' .. format(b)
				if relative and (a or 0) > 0 and not wide then text ..= string.format("  (+%d%%)", math.floor((b / a - 1) * 100 + 0.5)) end
				text ..= "</font>"
			end
			return text
		end
		local damageAfter = nextStats and nextStats.damage * ((tower.damage or 0) / math.max(0.001, now.damage or 1))
		local rateAfter = nextStats and nextStats.rate * ((tower.rate or 0) / math.max(0.001, now.rate or 1))
		local lines = {
			line(T("Dano", "Dmg"), tower.damage, damageAfter, whole, true),
			line(T("Alcance", "Range"), tower.range, nextStats and nextStats.range, tenth, true),
			line(T("Vel.", "Rate"), tower.rate, rateAfter, rate, true),
		}
		if (tower.slow or 0) > 0 then table.insert(lines, line(T("Lentidão", "Slow"), tower.slow, nextStats and nextStats.slow, percent, false)) end
		if (tower.splash or 0) > 0 then table.insert(lines, line(T("Área", "Area"), tower.splash, nextStats and nextStats.splash, tenth, false)) end
		local hero = Catalog.Heroes[tower.heroId]
		if hero and hero.pickup then table.insert(lines, hero.pickup) end
		return table.concat(lines, wide and "    " or "\n")
	end

	local function towerPanel(tower)
		if ctx.refs().towerPanel then ctx.refs().towerPanel:Destroy() end
		local layout = ctx.refs().layout or currentMatchLayout()
		local slot, wide = layout.tower, layout.towerVariant == "wide"
		local w = slot.w
		local panel = UI.roundFrame(main, {Position = at(slot), Size = dims(slot), BackgroundColor3 = C.background})
		UI.windowSkin(panel, UI.color(Catalog.Rarities[Catalog.Heroes[tower.heroId].rarity].color))
		ctx.refs().towerPanel, ctx.refs().towerWide, ctx.refs().towerRefresh = panel, wide, nil
		local def = Catalog.Heroes[tower.heroId]
		local own = tower.ownerId == player.UserId
		local half = math.floor((w - 30) / 2)
		local levelText = T("Melhoria ", "Upgrade ") .. tostring(tower.level) .. "/5" .. (tower.branch and "  •  " .. L(def.branches[tower.branch].name) or "")
		UI.closeButton(panel, closeTowerPanel, {Name="CloseTower",Position = UDim2.fromOffset(w - (wide and 46 or 52), wide and 4 or 10), Size = UDim2.fromOffset(wide and 40 or 42, wide and 40 or 42), TextSize = 24})
		local actionY, actionH, rowY, rowH
		-- Every stat reads as now -> after (the server's preview of the next
		-- upgrade), in text a thumb-length away can still read.
		if wide then
			local nameW = math.floor((w - 66) * 0.55)
			UI.label(panel, heroName(tower.heroId), {Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(nameW, 22), TextSize = 16, Font = UI.Fonts.display, TextColor3 = colorFor(tower.heroId), TextTruncate = Enum.TextTruncate.AtEnd})
			UI.label(panel, levelText, {Position = UDim2.fromOffset(12 + nameW + 4, 8), Size = UDim2.fromOffset(w - 66 - nameW - 4, 18), TextSize = 12, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd})
			ctx.refs().towerStats = UI.label(panel, "", {Name = "TowerStats", Position = UDim2.fromOffset(12, 29), Size = UDim2.fromOffset(w - 24, 18), TextSize = 13, Font = UI.Fonts.display, RichText = true, TextTruncate = Enum.TextTruncate.AtEnd})
			actionY, actionH, rowY, rowH = 50, 40, 94, 34
		else
			-- The tall panel, like the big games' unit cards: the hero on its rarity
			-- colour, the name, the upgrade level as five pips, then a table of the
			-- three numbers that matter with the next upgrade's value in green.
			local tint = UI.color(Catalog.Rarities[def.rarity].color)
			local face = UI.frame(panel, {Name = "TowerPortrait", Position = UDim2.fromOffset(12, 12), Size = UDim2.fromOffset(70, 70), BackgroundColor3 = tint})
			UI.corner(face, 12)
			UI.stroke(face, C.ink, 2.5)
			UI.create("UIGradient", {Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 150)), Rotation = 90}, face)
			if ctx.heroPortrait then ctx.heroPortrait(face, tower.heroId, {Position = UDim2.fromOffset(3, 3), Size = UDim2.new(1, -6, 1, -6)}) end
			UI.label(panel, heroName(tower.heroId), {Name = "TowerName", Position = UDim2.fromOffset(92, 10), Size = UDim2.fromOffset(w - 148, 32), TextSize = 25, Font = UI.Fonts.display, TextColor3 = colorFor(tower.heroId):Lerp(Color3.new(1, 1, 1), 0.3), TextScaled = false, TextTruncate = Enum.TextTruncate.AtEnd})
			UI.label(panel, levelText, {Name = "TowerLevel", Position = UDim2.fromOffset(92, 42), Size = UDim2.fromOffset(w - 104, 20), TextSize = 15, Font = UI.Fonts.display, TextColor3 = C.muted, TextTruncate = Enum.TextTruncate.AtEnd})
			for pip = 1, 5 do
				local lit = pip <= (tower.level or 1)
				local mark = UI.frame(panel, {Name = "LevelPip" .. pip, Position = UDim2.fromOffset(92 + (pip - 1) * 26, 66), Size = UDim2.fromOffset(22, 10), BackgroundColor3 = lit and (pip == 5 and C.violet or C.gold) or UI.Skin.slotLine})
				UI.corner(mark, 5)
				UI.stroke(mark, C.ink, 1.5)
			end
			-- The table: header, value now, and the value after the next upgrade.
			local grid = UI.frame(panel, {Name = "TowerTable", Position = UDim2.fromOffset(12, 92), Size = UDim2.fromOffset(w - 24, 96), BackgroundColor3 = UI.Skin.slot})
			UI.corner(grid, 12)
			UI.stroke(grid, UI.Skin.slotLine, 2)
			local cells = {}
			for index, key in ipairs({ "damage", "range", "rate" }) do
				local cell = UI.frame(grid, {Name = "TowerStat_" .. key, BackgroundTransparency = 1, Position = UDim2.fromScale((index - 1) / 3, 0), Size = UDim2.fromScale(1 / 3, 1)})
				if index > 1 then UI.frame(cell, {Position = UDim2.new(0, 0, 0.14, 0), Size = UDim2.new(0, 2, 0.72, 0), BackgroundColor3 = UI.Skin.slotLine}) end
				UI.label(cell, ({ T("Dano", "Damage"), T("Alcance", "Range"), T("Ataques/s", "Hits/s") })[index], {Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 0, 20), TextSize = 16, Font = UI.Fonts.display, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center})
				local value = UI.label(cell, "", {Name = "TowerNow_" .. key, Position = UDim2.fromOffset(4, 28), Size = UDim2.new(1, -8, 0, 32), TextSize = 28, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Center})
				UI.outline(value, 2.5)
				local after = UI.label(cell, "", {Name = "TowerNext_" .. key, Position = UDim2.fromOffset(2, 64), Size = UDim2.new(1, -4, 0, 24), TextSize = 16, Font = UI.Fonts.display, TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = false})
				cells[key] = { value = value, after = after }
			end
			-- Slow, area and the like as pills under the table, with their next value.
			local extras = UI.frame(panel, {Name = "TowerExtras", Position = UDim2.fromOffset(12, 196), Size = UDim2.fromOffset(w - 24, 30), BackgroundTransparency = 1})
			UI.list(extras, 6, true)
			local function refresh(current)
				local now, nextStats = current.base or current, current.next
				local function whole(v) return number(math.floor((v or 0) + 0.5)) end
				local function tenth(v) return string.format("%.1f", v or 0) end
				local function rate(v) return string.format("%.2f", v or 0) end
				local damageAfter = nextStats and nextStats.damage * ((current.damage or 0) / math.max(0.001, now.damage or 1))
				local rateAfter = nextStats and nextStats.rate * ((current.rate or 0) / math.max(0.001, now.rate or 1))
				local rows = { damage = { current.damage, damageAfter, whole }, range = { current.range, nextStats and nextStats.range, tenth }, rate = { current.rate, rateAfter, rate } }
				for key, row in pairs(rows) do
					local a, b, format = row[1] or 0, row[2], row[3]
					cells[key].value.Text = format(a)
					if b and math.abs(b - a) > 0.001 then
						local gain = a > 0 and math.floor((b / a - 1) * 100 + 0.5) or 0
						cells[key].after.Text = "→ " .. format(b) .. (gain ~= 0 and string.format("  (%+d%%)", gain) or "")
						cells[key].after.TextColor3 = b >= a and C.green or C.red
					else
						cells[key].after.Text = (current.level or 1) >= 5 and T("máximo", "max") or ""
						cells[key].after.TextColor3 = C.muted
					end
				end
				UI.clear(extras)
				UI.list(extras, 6, true)
				local function percent(v) return math.floor((v or 0) * 100 + 0.5) .. "%" end
				if (current.slow or 0) > 0 then
					local nextSlow = nextStats and nextStats.slow
					UI.pill(extras, T("Lentidão ", "Slow ") .. percent(current.slow) .. ((nextSlow and nextSlow > current.slow + 0.001) and ("  → " .. percent(nextSlow)) or ""), Color3.fromRGB(70, 150, 230), {TextSize = 14, Size = UDim2.fromOffset(0, 26)})
				end
				if (current.splash or 0) > 0 then UI.pill(extras, T("Área ", "Area ") .. tenth(current.splash), C.coral:Lerp(C.ink, 0.15), {TextSize = 14, Size = UDim2.fromOffset(0, 26)}) end
				UI.pill(extras, def.air and T("Chão e ar", "Ground + air") or T("Só chão", "Ground only"), def.air and C.green:Lerp(C.ink, 0.25) or C.coral:Lerp(C.ink, 0.25), {TextSize = 14, Size = UDim2.fromOffset(0, 26)})
			end
			refresh(tower)
			ctx.refs().towerRefresh = refresh
			local traits = UI.heroTraits(def, T, tower.slow)
			local traitLabel
			if #traits > 0 then
				traitLabel = UI.label(panel, table.concat(traits, "  •  "), {Name = "TowerTraits", Position = UDim2.fromOffset(12, 232), Size = UDim2.fromOffset(w - 24, 36), TextSize = 14, TextColor3 = C.cream, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Top})
			end
			rowH = 44
			rowY = slot.h - 12 - rowH
			actionH = (tower.level == 4) and 96 or 56
			actionY = rowY - 8 - actionH
			-- A short column keeps what matters: the buttons first, then the
			-- pills, then the trait line (the specializations explain themselves).
			if traitLabel and 232 + 36 > actionY - 4 then
				if 232 + 20 <= actionY - 4 then traitLabel.Size, traitLabel.TextSize = UDim2.fromOffset(w - 24, 20), 13 else traitLabel.Visible = false end
			end
			if 196 + 30 > actionY - 4 then extras.Visible = false end
		end
		local function note(text)
			UI.label(panel, text, {Position = UDim2.fromOffset(12, actionY), Size = UDim2.fromOffset(w - 24, (own and rowY - 6 or slot.h - 6) - actionY), TextSize = wide and 12 or 15, TextColor3 = C.muted, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top})
		end
		if not own then
			note(T("Torre de um aliado. Somente o dono pode modificá-la.", "Ally tower. Only its owner can modify it."))
			return
		end
		if tower.level < 4 then
			local upgrade = UI.button(panel, T("Melhorar  •  ", "Upgrade  •  ") .. number(tower.upgradeCost), function() act("UpgradeTower", {towerId = tower.id}) end, {Name = "TowerUpgrade", Position = UDim2.fromOffset(12, actionY), Size = UDim2.fromOffset(w - 24, actionH), TextSize = wide and 16 or 24, BackgroundColor3 = C.green})
			local match = ctx.state().match
			if (match and match.cash or 0) < (tower.upgradeCost or 0) then upgrade.BackgroundColor3 = C.card end
		elseif tower.level == 4 then
			-- Two specializations side by side: each says what it does and what it will hit for.
			for branch = 1, 2 do
				local after = tower.branches and tower.branches[branch]
				local label = L(def.branches[branch].name) .. "\n" .. (after and (T("Dano ", "Dmg ") .. number(math.floor(after.damage + 0.5)) .. "  •  ") or "") .. number(tower.upgradeCost)
				local choose = UI.button(panel, label, function() act("UpgradeTower", {towerId = tower.id, branch = branch}) end, {Name = "TowerBranch" .. branch, Position = UDim2.fromOffset(12 + (branch - 1) * (half + 6), actionY), Size = UDim2.fromOffset(half, wide and actionH or 48), TextSize = wide and 11 or 14, TextWrapped = true, BackgroundColor3 = branch == 1 and C.green or C.blue})
				if not wide then
					UI.label(panel, L(def.branches[branch].description), {Name = "BranchInfo" .. branch, Position = UDim2.fromOffset(12 + (branch - 1) * (half + 6), actionY + 52), Size = UDim2.fromOffset(half, 44), TextSize = 13, TextColor3 = C.cream, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Top})
				end
			end
		else
			note(L(def.branches[tower.branch or 1].description))
		end
		UI.secondary(panel, T("Alvo: ", "Target: ") .. L(kit.priorityNames[tower.priority] or tower.priority), function()
			local index = table.find(kit.priorityOrder, tower.priority) or 1
			act("SetPriority", {towerId = tower.id, priority = kit.priorityOrder[index % #kit.priorityOrder + 1]})
		end, {Position = UDim2.fromOffset(12, rowY), Size = UDim2.fromOffset(half, rowH), TextSize = wide and 12 or 16})
		UI.secondary(panel, T("Vender • ", "Sell • ") .. number(math.floor((tower.invested or 0) * 0.7)), function()
			act("SellTower", {towerId = tower.id}, closeTowerPanel)
		end, {Position = UDim2.fromOffset(18 + half, rowY), Size = UDim2.fromOffset(half, rowH), BackgroundColor3 = C.red:Lerp(UI.Skin.body, 0.35), TextSize = wide and 12 or 16})
	end

	-- Every tower you own carries its next upgrade above it, in the world: tap
	-- to buy, green when the energy is there. The panel stays one tap away for
	-- targeting and selling, and it is where level 4 picks a branch, but a
	-- plain upgrade never needs it. Billboards live in PlayerGui, so they are
	-- this player's alone and survive HUD re-layouts.
	local upgradeBoards = {}
	local function clearUpgradeBoards()
		for id, board in pairs(upgradeBoards) do
			board.gui:Destroy()
			upgradeBoards[id] = nil
		end
	end

	local function towerAnchor(id)
		local world = workspace:FindFirstChild("DoomWorld")
		local folder = world and world:FindFirstChild("Towers")
		for _, model in ipairs(folder and folder:GetChildren() or {}) do
			if tostring(model:GetAttribute("TowerId")) == tostring(id) then return model.PrimaryPart end
		end
		return nil
	end

	local function updateUpgradeBoards(match)
		local seen = {}
		for _, tower in ipairs(match.towers or {}) do
			if tower.ownerId ~= player.UserId or (tower.level or 1) >= 5 then continue end
			local id = tostring(tower.id)
			local board = upgradeBoards[id]
			if board and (board.gui.Adornee == nil or board.gui.Adornee.Parent == nil) then
				-- The model was rebuilt (an upgrade swaps parts); re-anchor.
				board.gui:Destroy()
				upgradeBoards[id], board = nil, nil
			end
			if not board then
				local anchor = towerAnchor(tower.id)
				if anchor then
					-- Above the hero's own head: Hulk is far taller than Rocket.
					local figure = anchor.Parent and anchor.Parent:FindFirstChild("HeroFigure")
					local height = figure and tonumber(figure:GetAttribute("FigureHeight")) or 6.5
					local gui = Instance.new("BillboardGui")
					gui.Name, gui.Size, gui.AlwaysOnTop, gui.Active = "Upgrade_" .. id, UDim2.fromOffset(150, 40), true, true
					gui.StudsOffset, gui.MaxDistance, gui.ResetOnSpawn = Vector3.new(0, height + 2.6, 0), 200, false
					gui.Adornee = anchor
					board = {gui = gui}
					board.button = UI.button(gui, "", function()
						local current = board.tower
						if not current then return end
						if (current.level or 1) >= 4 then selectTower(current.id) else act("UpgradeTower", {towerId = current.id}) end
					end, {Size = UDim2.fromScale(1, 1), TextSize = 16})
					UI.stroke(board.button, C.background, 2)
					UI.scaleBillboard(gui)
					gui.Parent = player:WaitForChild("PlayerGui")
					upgradeBoards[id] = board
				end
			end
			if board then
				seen[id] = true
				board.tower = tower
				local cost = tower.upgradeCost or 0
				local affordable = (match.cash or 0) >= cost
				local nextLevel = (tower.level or 1) + 1
				board.button.Text = (nextLevel == 5 and ("★ " .. T("Evoluir", "Evolve")) or ("▲ " .. tostring(nextLevel) .. "/5")) .. "  " .. number(cost)
				board.button.BackgroundColor3 = affordable and C.green or C.card
				-- Light text on green: dark text under the dark outline read as blots.
				board.button.TextColor3 = affordable and C.text or C.muted
			end
		end
		for id, board in pairs(upgradeBoards) do
			if not seen[id] then
				board.gui:Destroy()
				upgradeBoards[id] = nil
			end
		end
	end

	-- Stacked cards on a tall portrait screen, three across everywhere else, and
	-- always sized to the screen's real height so every CHOOSE button is on it.
	-- A card reads like a game card: a round medallion drawn from what it does,
	-- the name, and one bar per effect with its number in green (you gain) or
	-- red (you pay), then the total each stat would reach.
	local function protocolModal(offers)
		if ctx.refs().protocolPanel then ctx.refs().protocolPanel:Destroy(); ctx.refs().protocolPanel = nil end
		if #offers == 0 then return end
		local size = screenSize()
		local P = UI.protocolLayout(size.X, size.Y)
		local veil = UI.frame(overlays, {BackgroundColor3 = C.background, BackgroundTransparency = 0.12, Size = UDim2.fromScale(1, 1), ZIndex = 51, Active = true})
		ctx.refs().protocolPanel = veil
		local panel = UI.roundFrame(veil, {Position = at(P.panel), Size = dims(P.panel), ZIndex = 52}, C.gold)
		UI.windowSkin(panel, C.gold)
		local short = P.class.short
		UI.label(panel, T("Escolha sua carta", "Choose your card"), {Position = UDim2.fromOffset(20, short and 6 or 12), Size = UDim2.new(1, -40, 0, short and 28 or 38), TextColor3 = C.gold, Font = UI.Fonts.display, TextSize = short and 24 or (P.class.compact and 28 or 36), ZIndex = 53})
		UI.fit(UI.label(panel, T("O jogo segue em velocidade normal enquanto você escolhe.", "The game runs at normal speed while you choose."), {Name = "CardsNote", Position = UDim2.fromOffset(20, short and 34 or 52), Size = UDim2.new(1, -40, 0, 22), TextColor3 = C.muted, TextSize = short and 12 or 15, TextWrapped = true, ZIndex = 53}), 9)
		local owned = (ctx.state().match and ctx.state().match.cards) or {}
		for index, id in ipairs(offers) do
			local def = Catalog.Cards[id]
			local cardRect = P.cards[index]
			if not def or not cardRect then continue end
			local rarity = Catalog.Rarities[def.rarity]
			local tint = rarity and UI.color(rarity.color) or C.green
			-- A game card: dark face, the rarity's colour around it and lighting its top.
			local card = UI.roundFrame(panel, {Name = "Card_" .. id, Position = at(cardRect, P.panel), Size = dims(cardRect), BackgroundColor3 = UI.Skin.slot, ZIndex = 53}, tint)
			UI.stroke(card, tint, 3.5)
			local light = card:FindFirstChildOfClass("UIGradient")
			if light then light.Color = ColorSequence.new(tint:Lerp(Color3.new(1, 1, 1), 0.1), UI.Skin.slot); light.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.45, 0.92), NumberSequenceKeypoint.new(1, 1)}) end
			local buttonRect = P.buttons[index]
			local rows = CardArt.rows(Rules, def, owned, T)
			local function chipsAt(x, y, width, room, chipH, textSize)
				local count = 0
				for _, row in ipairs(rows) do
					if y + chipH > room then break end
					CardArt.chip(UI, card, row, width, chipH, textSize, 55).Position = UDim2.fromOffset(x, y)
					y += chipH + 5
					count += 1
				end
				return y, count
			end
			local nameText = L(def.name)
			if P.stacked then
				-- Medallion left, name and bars to its right.
				local medal = math.min(78, cardRect.h - 64)
				CardArt.medallion(UI, card, def, tint, medal, {Position = UDim2.fromOffset(10, 8), ZIndex = 54})
				UI.label(card, nameText, {Position = UDim2.fromOffset(medal + 22, 6), Size = UDim2.new(1, -medal - 32, 0, 26), Font = UI.Fonts.display, TextSize = 19, TextColor3 = tint:Lerp(C.text, 0.4), ZIndex = 54})
				chipsAt(medal + 22, 32, cardRect.w - medal - 32, cardRect.h - 58, 22, 13)
			else
				local medal = short and 54 or math.min(96, math.floor(cardRect.h * 0.27))
				CardArt.medallion(UI, card, def, tint, medal, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, short and 6 or 10), ZIndex = 54})
				local nameY = (short and 6 or 10) + medal + 4
				UI.label(card, nameText, {Position = UDim2.fromOffset(8, nameY), Size = UDim2.new(1, -16, 0, short and 22 or 30), Font = UI.Fonts.display, TextSize = short and 16 or 22, TextColor3 = tint:Lerp(C.text, 0.4), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 54})
				local chipH = short and 24 or 34
				local y = nameY + (short and 24 or 34)
				local nextY, drawn = chipsAt(10, y, cardRect.w - 20, buttonRect.y - cardRect.y - 4, chipH, short and 14 or 17)
				local first = rows[1]
				if first and first.now and drawn > 0 and nextY + 20 <= buttonRect.y - cardRect.y then
					local after = first.after
					UI.label(card, T("Total ", "Total ") .. CardArt.times(first.now - 1) .. "  →  " .. CardArt.times(after - 1), {Name = "CardTotalLine", Position = UDim2.fromOffset(8, nextY), Size = UDim2.new(1, -16, 0, 20), TextSize = short and 12 or 15, Font = UI.Fonts.bold, TextColor3 = after >= 1 and C.green or C.red, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 54})
					nextY += 22
				end
				-- The description fills what is left, when there is room for it.
				local room = buttonRect.y - cardRect.y - 4 - nextY
				if not short and room >= 36 then
					UI.label(card, L(def.description), {Position = UDim2.fromOffset(10, nextY), Size = UDim2.new(1, -20, 0, room), TextSize = 14, TextColor3 = C.muted, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 54})
				end
			end
			UI.button(card, T("Escolher", "Choose").." • "..(rarity and L(rarity.name) or ""), function() act("ChooseCard", {cardId = id}) end, {Position = at(buttonRect, cardRect), Size = dims(buttonRect), BackgroundColor3 = tint, TextSize = short and 14 or (P.stacked and 17 or 21), TextWrapped = false, TextScaled = short, ZIndex = 54})
		end
	end

	-- The running totals of the cards taken, kept in a corner while a cards-mode
	-- match is on: green at 1x or above, red below. Rebuilt when the deck grows.
	local function cardStats(match)
		local existing = main:FindFirstChild("CardStats")
		local cards = match and match.cardMode and match.cards or {}
		local signature = table.concat(cards, ",")
		if #cards == 0 then
			if existing then existing:Destroy() end
			ctx.refs().cardStatsKey = nil
			return
		end
		if existing and ctx.refs().cardStatsKey == signature then return end
		if existing then existing:Destroy() end
		ctx.refs().cardStatsKey = signature
		local layout = ctx.refs().layout or currentMatchLayout()
		local compact = sizeClass().compact
		local rowH, textSize = compact and 22 or 28, compact and 13 or 16
		local width = compact and 138 or 190
		local top = layout.waveInfo.y + layout.waveInfo.h + 8
		local room = math.max(rowH, layout.actionTop - 8 - top - 4)
		local maxRows = math.max(1, math.floor((room + 4) / (rowH + 4)))
		local holder = UI.frame(main, {Name = "CardStats", BackgroundTransparency = 1, Position = UDim2.fromOffset(layout.waveInfo.x, top), Size = UDim2.fromOffset(width, room)})
		UI.list(holder, 4)
		CardArt.totalRows(UI, Rules, T, holder, cards, rowH, textSize, maxRows, width)
	end

	local function openBaseUpgrade()
		local state = ctx.state()
		if not activeMatch() or not state.match.base then return end
		local old=overlays:FindFirstChild("BaseUpgrade"); if old then old:Destroy() end
		local base=state.match.base; local def=Catalog.Bases[base.id]; local stats=base.stats
		local nextStats=Rules.BaseStats(base.id,math.min(5,base.level+1))
		local screen=screenSize()
		local shade=UI.frame(overlays,{Name="BaseUpgrade",Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,BackgroundTransparency=0.25,Active=true,ZIndex=45})
		local panel=UI.roundFrame(shade,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(math.min(520,screen.X-24),math.min(470,screen.Y-24)),BackgroundColor3=C.background,ZIndex=46},C.green)
		UI.windowSkin(panel,C.green)
		UI.label(panel,T("Evoluir base","Upgrade base"),{Position=UDim2.fromOffset(16,8),Size=UDim2.new(1,-76,0,36),TextColor3=C.green,TextSize=27,Font=UI.Fonts.display,ZIndex=47})
		UI.closeButton(panel,function() shade:Destroy() end,{Position=UDim2.new(1,-50,0,6),Size=UDim2.fromOffset(44,44),TextSize=25,ZIndex=47})
		local body=UI.scroll(panel,{Position=UDim2.fromOffset(16,54),Size=UDim2.new(1,-32,1,-66),ZIndex=47,ScrollBarThickness=8}); UI.list(body,10)
		local art=UI.row(body,112); art.ZIndex=47
		local stage=UI.frame(art,{Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(112,112),BackgroundColor3=C.green:Lerp(C.ink,0.55),ZIndex=47})
		UI.corner(stage,14)
		UI.basePortrait(stage,def,{Position=UDim2.fromOffset(4,4),Size=UDim2.fromOffset(104,104),ZIndex=48})
		UI.fit(UI.label(art,L(def.name),{Name="BaseUpgradeName",Position=UDim2.fromOffset(124,4),Size=UDim2.new(1,-130,0,34),TextSize=25,Font=UI.Fonts.display,TextWrapped=true,ZIndex=48}),13)
		-- The level as five pips, like a tower's.
		for pip=1,5 do
			local lit=pip<=base.level
			local mark=UI.frame(art,{Name="BasePip"..pip,Position=UDim2.fromOffset(124+(pip-1)*30,46),Size=UDim2.fromOffset(26,12),BackgroundColor3=lit and C.gold or UI.Skin.slotLine,ZIndex=48})
			UI.corner(mark,6)
			UI.stroke(mark,C.ink,1.5)
		end
		UI.label(art,T("Melhoria ","Upgrade ")..base.level.." / 5",{Position=UDim2.fromOffset(124,64),Size=UDim2.new(1,-130,0,26),TextSize=19,Font=UI.Fonts.display,TextColor3=C.muted,ZIndex=48})
		local function line(text,color,height) UI.label(body,text,{Size=UDim2.new(1,-8,0,height or 30),TextSize=17,Font=UI.Fonts.display,TextWrapped=true,TextColor3=color or C.text,ZIndex=48,RichText=true}) end
		UI.label(body,L(def.description),{Size=UDim2.new(1,-8,0,48),TextSize=16,TextWrapped=true,TextColor3=C.muted,ZIndex=48})
		-- Each line reads now -> after the upgrade, the new value in green.
		local function arrow(a,b) return tostring(a)..'  <font color="#58E04F">→ '..tostring(b)..'</font>' end
		line(T("Renda por onda: ","Income per wave: ")..arrow(stats.income,nextStats.income)..T(" Ouro"," Gold"),C.gold)
		line(T("Vida extra do núcleo: ","Extra core HP: ")..arrow(math.floor(stats.hp/(state.match.partySize or 1)),math.floor(nextStats.hp/(state.match.partySize or 1))),C.cream)
		if stats.damage>0 then line(T("Dano: ","Damage: ")..arrow(stats.damage,nextStats.damage)..T("  •  Alcance: ","  •  Range: ")..arrow(stats.range,nextStats.range),C.coral,44) end
		if stats.wall>0 then line(T("Barricada: ","Barricade: ")..(base.wall or 0).."/"..arrow(stats.wall,nextStats.wall)..T(" vida • volta após 5 s"," HP • regrows after 5 s"),C.blue,44) end
		if stats.soldier>0 then line(T("Soldado: ","Soldier: ")..arrow(stats.soldier,nextStats.soldier)..T(" vida • a cada "," HP • every ")..stats.interval.." s",C.violet,44) end
		local button=UI.button(body,base.level>=5 and T("Nível máximo","Maximum level") or T("Evoluir • ","Upgrade • ")..stats.upgradeCost,function()
			-- The window stays: it redraws with the new level and the next price.
			act("UpgradeBase",{expectedLevel=base.level},function() audio:Cue("upgrade") end)
		end,{Name="ConfirmBaseUpgrade",Size=UDim2.new(1,-8,0,56),TextSize=22,BackgroundColor3=C.green,ZIndex=48})
		if base.level>=5 or (state.match.cash or 0)<stats.upgradeCost then UI.disabled(button) end
		ctx.refs().refreshBaseModal=function()
			if not shade.Parent then ctx.refs().refreshBaseModal=nil; return end
			local current=ctx.state().match
			if not current or not current.base then shade:Destroy(); ctx.refs().refreshBaseModal=nil; return end
			if current.base.level~=base.level then ctx.refs().refreshBaseModal=nil; openBaseUpgrade(); return end
			local missing=math.max(0,stats.upgradeCost-(current.cash or 0))
			if base.level>=5 then return end
			button.Text=missing>0 and T("Faltam ","Need ")..number(missing)..T(" Ouro"," Gold") or T("Evoluir • ","Upgrade • ")..stats.upgradeCost
			if missing>0 then UI.disabled(button)
			else button.Active=true; button.AutoButtonColor=true; button.BackgroundColor3=C.green; button.TextColor3=C.background end
		end
		ctx.refs().refreshBaseModal()
		UI.label(body,T("Usa o Ouro desta partida. O Ouro do lobby nunca é gasto aqui. Renda exige contribuição na onda.","Uses this match's Gold. Lobby Gold is never spent here. Income requires contribution to the wave."),{Size=UDim2.new(1,-8,0,48),TextSize=15,TextWrapped=true,TextColor3=C.muted,ZIndex=48})
	end

	local function renderResults()
		local result = ctx.state().results or {}
		local victory = result.victory == true or result.ended == true
		local veil = UI.frame(main, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.background, BackgroundTransparency = 0.12})
		local panel = UI.roundFrame(veil, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 8), Size = UDim2.new(1, -32, 1, -60), BackgroundColor3 = C.panel}, victory and C.green or C.red)
		UI.create("UISizeConstraint", {MaxSize = Vector2.new(640, 720)}, panel)
		UI.windowSkin(panel, victory and C.green or C.blue)
		-- The window's title tab, like every other screen: victory green, retry blue.
		UI.titleRibbon(panel, result.ended and T("Recorde!", "Record!") or victory and T("Vitória!", "Victory!") or T("Fim de jogo", "Game over"), victory and C.green or C.blue,
			{Name = "ResultRibbon", Position = UDim2.fromOffset(-10, -14), width = 320, height = 54, TextSize = 32, ZIndex = 3})
		local content = UI.scroll(panel, {Name="ResultBody",Position = UDim2.fromOffset(20, 48), Size = UDim2.new(1, -40, 1, -128), ScrollBarThickness = 8})
		UI.frame(panel,{Position=UDim2.new(0,18,1,-75),Size=UDim2.new(1,-36,0,2),BackgroundColor3=UI.Skin.slotLine})
		-- Like the genre's best: one tap runs the same map again; going back to
		-- base is the quieter choice. Training always returns to the lobby.
		if result.modeId=="tutorial" then
			UI.button(panel,T("Voltar ao lobby","Back to the lobby"),function() act("ReturnLobby",{}) end,{Name="ResultReturn",Position=UDim2.new(0,18,1,-64),Size=UDim2.new(1,-36,0,52),TextSize=22})
		else
			local waiting=result.again==true
			local again=UI.button(panel,waiting and (T("Esperando ","Waiting ")..tostring(result.againVotes or 1).."/"..tostring(result.againTotal or 1)) or T("▶ Jogar de novo","▶ Play again"),
				function() act("PlayAgain",{}) end,{Name="ResultPlayAgain",Position=UDim2.new(0,18,1,-64),Size=UDim2.new(0.62,-24,0,52),BackgroundColor3=C.green,TextSize=22})
			if waiting then UI.disabled(again) end
			UI.secondary(panel,T("Lobby","Lobby"),function() act("ReturnLobby",{}) end,{Name="ResultReturn",Position=UDim2.new(0.62,0,1,-64),Size=UDim2.new(0.38,-18,0,52),TextSize=20,BackgroundColor3=UI.Skin.bodyTop})
		end
		UI.list(content, 8)
		local short=sizeClass().short
		local celebration=UI.row(content,short and 44 or 64)
		local emblemSize=short and 36 or 48
		UI.icon(celebration,victory and "trophy" or "heart",victory and C.gold or C.blue,{Position=UDim2.fromOffset(2,short and 4 or 12),Size=UDim2.fromOffset(emblemSize,emblemSize)})
		UI.label(celebration, result.ended and T("Recorde guardado!", "Record saved!") or victory and T("Vocês conseguiram!", "You did it!") or T("Vamos tentar de novo?", "Let's try again!"), {Position=UDim2.fromOffset(emblemSize+14,0),Size = UDim2.new(1, -emblemSize-20, 1, 0), TextSize = short and 20 or (mobile() and 22 or 27), Font = Enum.Font.FredokaOne, TextWrapped = true, TextColor3 = victory and C.green or C.blue})
		UI.label(content, mapName(result.mapId or "manhattan") .. "  /  " .. modeName(result.modeId or "normal", result.difficultyId), {Size = UDim2.new(1, -6, 0, short and 20 or 28), TextColor3 = C.muted, TextSize = short and 14 or 17, TextXAlignment = Enum.TextXAlignment.Center})
		if (tonumber(result.featured) or 1) > 1 then
			UI.label(content, "★ " .. T("Mapa do dia +", "Map of the day +") .. math.floor((result.featured - 1) * 100 + 0.5) .. "%", {Name = "ResultFeatured", Size = UDim2.new(1, -6, 0, short and 18 or 24), TextColor3 = C.gold, TextSize = short and 12 or 14, Font = Enum.Font.BuilderSansExtraBold, TextXAlignment = Enum.TextXAlignment.Center})
		end
		if (tonumber(result.party) or 1) > 1 then
			UI.label(content, "★ " .. T("Bônus de grupo +", "Party bonus +") .. math.floor((result.party - 1) * 100 + 0.5) .. "%", {Name = "ResultParty", Size = UDim2.new(1, -6, 0, short and 18 or 24), TextColor3 = C.gold, TextSize = short and 12 or 14, Font = Enum.Font.BuilderSansExtraBold, TextXAlignment = Enum.TextXAlignment.Center})
		end
		-- Core rewards stay together and appear before the optional detailed history,
		-- including on short screens where three large rows needed several scrolls.
		local rewards=UI.row(content,short and 70 or 92)
		rewards.Name="ResultRewards"
		for index,reward in ipairs({{T("Ondas", "Waves"), tostring(result.waves or 0), C.green}, {T("Ouro", "Gold"), "+" .. number(result.gold or 0), C.gold}, {"XP", "+" .. number(result.xp or 0), C.blue}}) do
			local tile=UI.roundFrame(rewards,{Name="Reward_"..index,Position=UDim2.new((index-1)/3,0,0,0),Size=UDim2.new(1/3,-6,1,0),BackgroundColor3=UI.Skin.slot},reward[3])
			UI.stroke(tile,reward[3],2.5)
			UI.label(tile,reward[1],{Position=UDim2.fromOffset(4,6),Size=UDim2.new(1,-8,0,22),TextSize=17,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Center,Font=UI.Fonts.display})
			UI.label(tile,reward[2],{Name="RewardValue_"..index,Position=UDim2.fromOffset(4,28),Size=UDim2.new(1,-8,1,-32),TextSize=mobile() and 24 or 32,TextColor3=reward[3],TextXAlignment=Enum.TextXAlignment.Center,Font=Enum.Font.FredokaOne})
		end
		if not kit.resultsCelebrated then
			-- Once per results screen: a re-render while rewards finish saving must
			-- not throw a second round of confetti.
			kit.resultsCelebrated=true
			celebrate:CountUp(rewards:FindFirstChild("Reward_1") and rewards.Reward_1:FindFirstChild("RewardValue_1"),result.waves or 0,function(v) return tostring(v) end,1)
			celebrate:CountUp(rewards:FindFirstChild("Reward_2") and rewards.Reward_2:FindFirstChild("RewardValue_2"),result.gold or 0,function(v) return "+"..number(v) end,1.4)
			celebrate:CountUp(rewards:FindFirstChild("Reward_3") and rewards.Reward_3:FindFirstChild("RewardValue_3"),result.xp or 0,function(v) return "+"..number(v) end,1.4)
			if victory then
				celebrate:Banner({pt="VITÓRIA!",en="VICTORY!"},{pt=tostring(result.waves or 0).." ondas defendidas",en=tostring(result.waves or 0).." waves defended"},C.gold,{big=true,cue="victory",confetti=60})
			else
				celebrate:Banner({pt="QUASE LÁ!",en="SO CLOSE!"},{pt="Você chegou à onda "..tostring(result.waves or 0)..". Da próxima vez vai!",en="You reached wave "..tostring(result.waves or 0)..". Next time!"},C.blue,{duration=2.2})
			end
		end
		-- The squad's scoreboard: the MVP on top in gold, everyone's damage and
		-- kills under it (a solo commander sees their own numbers).
		local team=result.team or {}
		if #team>0 then
			local mvp=team[1]
			local mine=mvp.userId==player.UserId
			local card=UI.roundFrame(content,{Name="ResultMvp",Size=UDim2.new(1,-6,0,short and 60 or 76),BackgroundColor3=UI.Skin.slot},C.gold)
			UI.stroke(card,C.gold,3)
			UI.label(card,"★ MVP",{Position=UDim2.fromOffset(12,4),Size=UDim2.new(0,100,1,-8),TextSize=short and 22 or 28,Font=UI.Fonts.display,TextColor3=C.gold})
			UI.label(card,mine and T("Você!","You!") or tostring(mvp.name),{Name="MvpName",Position=UDim2.fromOffset(112,4),Size=UDim2.new(1,-122,0.5,-2),TextSize=short and 18 or 22,Font=UI.Fonts.display,TextTruncate=Enum.TextTruncate.AtEnd})
			UI.fit(UI.label(card,T("Dano ","Dmg ")..number(mvp.damage).."   "..T("Abates ","Kills ")..number(mvp.kills).."   "..T("Ouro ","Gold ")..number(mvp.gold),{Name="MvpStats",Position=UDim2.new(0,112,0.5,0),Size=UDim2.new(1,-122,0.5,-4),TextSize=short and 15 or 18,Font=UI.Fonts.display,TextColor3=C.cream}),9)
			for index=2,#team do
				local entry=team[index]
				local row=UI.row(content,short and 28 or 34)
				row.Name="ResultTeam_"..index
				UI.label(row,(entry.userId==player.UserId and T("Você","You") or tostring(entry.name)),{Size=UDim2.new(0.5,0,1,0),TextSize=18,Font=UI.Fonts.display,TextTruncate=Enum.TextTruncate.AtEnd})
				UI.fit(UI.label(row,T("Dano ","Dmg ")..number(entry.damage).."   "..T("Abates ","Kills ")..number(entry.kills),{Name="TeamStats",Position=UDim2.fromScale(0.5,0),Size=UDim2.new(0.5,0,1,0),TextSize=17,Font=UI.Fonts.display,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Right}),9)
			end
		end
		if result.modeId=="ranked" then
			local tier=Rules.RankForWaves(result.waves)
			local rankRow=UI.row(content,54)
			rankRow.Name="ResultRank"
			UI.label(rankRow,"Rank: "..(ctx.language()=="en" and tier.en or tier.pt),{Size=UDim2.new(1,-6,0,28),Font=UI.Fonts.display,TextSize=22,TextColor3=C.gold})
			UI.label(rankRow,T("Seu melhor resultado fica no placar da temporada.","Your best result stays on the seasonal leaderboard."),{Position=UDim2.fromOffset(0,30),Size=UDim2.new(1,-6,0,22),TextSize=15,TextColor3=C.muted})
		end
		local earnedPoints = math.max(0, (profile().level or 1) - (result.startLevel or profile().level or 1))
		local evolution = UI.roundFrame(content, {Name = "ResultEvolution", Size = UDim2.new(1, -6, 0, 90), BackgroundColor3 = UI.Skin.slot}, C.gold)
		UI.label(evolution, T("Comandante • nível ", "Commander • level ") .. tostring(profile().level or 1), {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 28), Font = UI.Fonts.display, TextSize = 20, TextColor3 = C.gold})
		UI.label(evolution, earnedPoints > 0 and ("+" .. earnedPoints .. T(" ponto(s) para sua árvore!", " point(s) for your talent tree!")) or T("Continue ganhando XP para liberar outro ponto.", "Keep earning XP to unlock another point."), {Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 0, 26), TextWrapped = true, TextSize = 16})
		local xpTrack = UI.frame(evolution, {Position = UDim2.fromOffset(12, 72), Size = UDim2.new(1, -24, 0, 8), BackgroundColor3 = C.stroke})
		UI.corner(xpTrack, 4)
		UI.frame(xpTrack, {Size = UDim2.fromScale(levelProgress(), 1), BackgroundColor3 = C.gold})
		-- The season pass: where this match's XP took it, and whether a claim waits.
		local season = profile().seasonStatus
		if season then
			local seasonCard = UI.roundFrame(content, {Name = "ResultSeason", Size = UDim2.new(1, -6, 0, 76), BackgroundColor3 = UI.Skin.slot}, C.violet)
			UI.label(seasonCard, T("Temporada • nível ", "Season • level ") .. tostring(season.level) .. "/" .. tostring(season.maxLevel), {Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 26), Font = UI.Fonts.display, TextSize = 19, TextColor3 = C.violet:Lerp(Color3.new(1, 1, 1), 0.25)})
			local seasonTrack = UI.frame(seasonCard, {Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 8), BackgroundColor3 = C.stroke})
			UI.corner(seasonTrack, 4)
			local seasonFill = UI.frame(seasonTrack, {Size = UDim2.fromScale(math.clamp(season.xpInto / season.xpNeed, 0, 1), 1), BackgroundColor3 = C.violet})
			UI.corner(seasonFill, 4)
			UI.label(seasonCard, season.claimable > 0 and (tostring(season.claimable) .. T(" prêmio(s) esperando em PRÊMIOS!", " reward(s) waiting in GIFTS!")) or (number(season.xpInto) .. " / " .. number(season.xpNeed) .. " XP"),
				{Name = "ResultSeasonHint", Position = UDim2.fromOffset(12, 46), Size = UDim2.new(1, -24, 0, 24), TextSize = 16, Font = UI.Fonts.display, TextColor3 = season.claimable > 0 and C.gold or C.muted})
		end
		local gains = {}
		for heroId, earned in pairs(result.mastery or {}) do
			if Catalog.Heroes[heroId] and earned > 0 then table.insert(gains, {id = heroId, xp = earned}) end
		end
		table.sort(gains, function(a, b) return a.xp > b.xp end)
		if #gains > 0 then
			local card = UI.roundFrame(content, {Size = UDim2.new(1, -6, 0, 40 + #gains * 30), BackgroundColor3 = UI.Skin.slot}, UI.Skin.slotLine)
			UI.label(card, T("Seus heróis aprenderam!", "Your heroes grew!"), {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 24), TextSize = 18, TextColor3 = C.cream, Font = UI.Fonts.display})
			for index, gain in ipairs(gains) do
				local y = 36 + (index - 1) * 30
				UI.label(card, heroName(gain.id), {Position = UDim2.fromOffset(12, y), Size = UDim2.new(0.62, -12, 0, 26), TextSize = 17, Font = UI.Fonts.display, TextColor3 = colorFor(gain.id):Lerp(Color3.new(1, 1, 1), 0.3)})
				UI.label(card, "+" .. number(gain.xp) .. " XP", {Position = UDim2.new(0.62, 0, 0, y), Size = UDim2.new(0.38, -12, 0, 26), TextSize = 17, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Right})
			end
		end
		UI.label(content,T("Próximo objetivo: evolua a habilidade do líder ou recrute nos baús.","Next goal: upgrade your leader ability or recruit from chests."),{Size=UDim2.new(1,-6,0,36),TextWrapped=true,TextColor3=C.muted,TextSize=13})
		welcomePanel(panel)
	end

	return {
		towerStatsText = towerStatsText, towerPanel = towerPanel,
		clearUpgradeBoards = clearUpgradeBoards, updateUpgradeBoards = updateUpgradeBoards,
		protocolModal = protocolModal, cardStats = cardStats, openBaseUpgrade = openBaseUpgrade, renderResults = renderResults,
	}
end

return MatchHud
