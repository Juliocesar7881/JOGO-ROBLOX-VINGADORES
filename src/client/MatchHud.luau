-- The battle's own panels, split out of init.client to keep that script
-- small: the selected tower's panel, the upgrade boards over your towers, the
-- card choice, the base upgrade and the results screen. Every number shown
-- is one the server sent; every button is an intent through ctx.act.
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
		-- One stat as "now -> next": the next value in green, as the server sent it.
		local function statChange(icon, now, after, format)
			local text = icon .. " " .. format(now or 0)
			if after and math.abs((after or 0) - (now or 0)) > 0.001 then
				text ..= ' <font color="#6BE38A">→ ' .. format(after) .. "</font>"
			end
			return text
		end
		local now, nextStats = tower.base or tower, tower.next
		local function whole(v) return number(math.floor(v + 0.5)) end
		local function tenth(v) return string.format("%.1f", v) end
		local function rate(v) return string.format("%.2f", v) end
		local lines = {
			statChange("⚔", tower.damage, nextStats and nextStats.damage * ((tower.damage or 0) / math.max(0.001, now.damage or 1)), whole),
			statChange("◎", tower.range, nextStats and nextStats.range, tenth),
			statChange("⚡", tower.rate, nextStats and nextStats.rate * ((tower.rate or 0) / math.max(0.001, now.rate or 1)), rate),
		}
		local hero = Catalog.Heroes[tower.heroId]
		if hero and hero.pickup then table.insert(lines, "🧲 " .. hero.pickup) end
		return table.concat(lines, wide and "    " or "\n")
	end

	local function towerPanel(tower)
		if ctx.refs().towerPanel then ctx.refs().towerPanel:Destroy() end
		local layout = ctx.refs().layout or currentMatchLayout()
		local slot, wide = layout.tower, layout.towerVariant == "wide"
		local w = slot.w
		local panel = UI.roundFrame(main, {Position = at(slot), Size = dims(slot), BackgroundColor3 = C.background})
		ctx.refs().towerPanel, ctx.refs().towerWide = panel, wide
		local def = Catalog.Heroes[tower.heroId]
		local own = tower.ownerId == player.UserId
		local half = math.floor((w - 30) / 2)
		local levelText = T("Melhoria ", "Upgrade ") .. tostring(tower.level) .. "/5" .. (tower.branch and "  •  " .. L(def.branches[tower.branch].name) or "")
		UI.secondary(panel, "×", closeTowerPanel, {Name="CloseTower",Position = UDim2.fromOffset(w - 46, 4), Size = UDim2.fromOffset(40, 40), TextSize = 24})
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
			UI.label(panel, heroName(tower.heroId), {Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(w - 54, 24), TextSize = 18, Font = UI.Fonts.display, TextColor3 = colorFor(tower.heroId), TextTruncate = Enum.TextTruncate.AtEnd})
			UI.label(panel, levelText, {Position = UDim2.fromOffset(12, 32), Size = UDim2.fromOffset(w - 54, 18), TextSize = 13, TextColor3 = C.muted, TextTruncate = Enum.TextTruncate.AtEnd})
			ctx.refs().towerStats = UI.label(panel, "", {Name = "TowerStats", Position = UDim2.fromOffset(12, 54), Size = UDim2.fromOffset(w - 24, 62), TextSize = 15, Font = UI.Fonts.display, RichText = true, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.05})
			actionY, actionH, rowY, rowH = 122, 46, 176, 40
		end
		local function note(text)
			UI.label(panel, text, {Position = UDim2.fromOffset(12, actionY), Size = UDim2.fromOffset(w - 24, (own and rowY - 6 or slot.h - 6) - actionY), TextSize = 12, TextColor3 = C.muted, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top})
		end
		if not own then
			note(T("Torre de um aliado. Somente o dono pode modificá-la.", "Ally tower. Only its owner can modify it."))
			return
		end
		if tower.level < 4 then
			local upgrade = UI.button(panel, T("MELHORAR  •  ", "UPGRADE  •  ") .. "💰 " .. number(tower.upgradeCost), function() act("UpgradeTower", {towerId = tower.id}) end, {Name = "TowerUpgrade", Position = UDim2.fromOffset(12, actionY), Size = UDim2.fromOffset(w - 24, actionH), TextSize = wide and 15 or 18, BackgroundColor3 = C.green})
			local match = ctx.state().match
			if (match and match.cash or 0) < (tower.upgradeCost or 0) then upgrade.BackgroundColor3 = C.card end
		elseif tower.level == 4 then
			-- Two specializations side by side, each with its new damage.
			for branch = 1, 2 do
				local after = tower.branches and tower.branches[branch]
				local label = L(def.branches[branch].name) .. "\n" .. (after and ("⚔ " .. number(math.floor(after.damage + 0.5)) .. "  •  ") or "") .. "💰 " .. number(tower.upgradeCost)
				UI.button(panel, label, function() act("UpgradeTower", {towerId = tower.id, branch = branch}) end, {Name = "TowerBranch" .. branch, Position = UDim2.fromOffset(12 + (branch - 1) * (half + 6), actionY), Size = UDim2.fromOffset(half, actionH), TextSize = wide and 11 or 12, TextWrapped = true, BackgroundColor3 = branch == 1 and C.green or C.blue})
			end
		else
			note(L(def.branches[tower.branch or 1].description))
		end
		UI.secondary(panel, T("Alvo: ", "Target: ") .. L(kit.priorityNames[tower.priority] or tower.priority), function()
			local index = table.find(kit.priorityOrder, tower.priority) or 1
			act("SetPriority", {towerId = tower.id, priority = kit.priorityOrder[index % #kit.priorityOrder + 1]})
		end, {Position = UDim2.fromOffset(12, rowY), Size = UDim2.fromOffset(half, rowH), TextSize = 12})
		UI.secondary(panel, T("Vender • ", "Sell • ") .. "💰 " .. number(math.floor((tower.invested or 0) * 0.7)), function()
			act("SellTower", {towerId = tower.id}, closeTowerPanel)
		end, {Position = UDim2.fromOffset(18 + half, rowY), Size = UDim2.fromOffset(half, rowH), TextColor3 = C.red, TextSize = 12})
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
					gui.Name, gui.Size, gui.AlwaysOnTop, gui.Active = "Upgrade_" .. id, UDim2.fromOffset(128, 34), true, true
					gui.StudsOffset, gui.MaxDistance, gui.ResetOnSpawn = Vector3.new(0, height + 2.6, 0), 200, false
					gui.Adornee = anchor
					board = {gui = gui}
					board.button = UI.button(gui, "", function()
						local current = board.tower
						if not current then return end
						if (current.level or 1) >= 4 then selectTower(current.id) else act("UpgradeTower", {towerId = current.id}) end
					end, {Size = UDim2.fromScale(1, 1), TextSize = 13})
					UI.stroke(board.button, C.background, 2)
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
				board.button.Text = (nextLevel == 5 and ("★ " .. T("EVOLUIR", "EVOLVE")) or ("⬆ " .. tostring(nextLevel) .. "/5")) .. "  💰" .. number(cost)
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
	local function protocolModal(offers)
		if ctx.refs().protocolPanel then ctx.refs().protocolPanel:Destroy(); ctx.refs().protocolPanel = nil end
		if #offers == 0 then return end
		local size = screenSize()
		local P = UI.protocolLayout(size.X, size.Y)
		local veil = UI.frame(overlays, {BackgroundColor3 = C.background, BackgroundTransparency = 0.22, Size = UDim2.fromScale(1, 1), ZIndex = 51, Active = true})
		ctx.refs().protocolPanel = veil
		local panel = UI.roundFrame(veil, {Position = at(P.panel), Size = dims(P.panel), ZIndex = 52}, C.green)
		UI.label(panel, T("ESCOLHA SUA CARTA", "CHOOSE YOUR CARD"), {Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 30), TextColor3 = C.green, Font = Enum.Font.GothamBold, TextSize = P.class.compact and 18 or 21, ZIndex = 53})
		UI.label(panel, T("Escolha um bônus para esta partida.", "Choose a bonus for this match."), {Position = UDim2.fromOffset(20, 48), Size = UDim2.new(1, -40, 0, 24), TextColor3 = C.muted, TextSize = 13, ZIndex = 53})
		for index, id in ipairs(offers) do
			local def = Catalog.Cards[id]
			local cardRect = P.cards[index]
			if not def or not cardRect then continue end
			local rarity=Catalog.Rarities[def.rarity]
			local tint=rarity and UI.color(rarity.color) or C.green
			local card = UI.roundFrame(panel, {Position = at(cardRect, P.panel), Size = dims(cardRect), BackgroundColor3 = tint:Lerp(C.card,0.88), ZIndex = 53},tint)
			UI.shade(card,30)
			UI.frame(card,{Position=UDim2.fromOffset(0,6),Size=UDim2.new(0,3,1,-12),BackgroundColor3=tint,ZIndex=54})
			UI.label(card, L(def.name), {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 24), Font = Enum.Font.GothamBold, TextSize = P.class.compact and 13 or 15, TextWrapped = true, ZIndex = 54})
			-- Side by side, a card has room for a big glyph of what it does and a
			-- readable description; stacked on a phone it keeps the compact rows.
			local desc = P.descriptions[index]
			local descSize = 12
			if not P.stacked then
				local effects, instant = def.effects or {}, def.instant or {}
				local glyph = (instant.energy or effects.killGold or effects.energyIncome) and "💰"
					or (instant.heal or instant.maxHealth) and "❤️" or instant.gamble and "🎲"
					or (effects.damage or effects.bossDamage or effects.airDamage or effects.stealthDamage or effects.pierce) and "💥"
					or effects.speed and "⚡" or (effects.range or effects.supportRange or effects.area) and "🎯"
					or (effects.cooldown or effects.abilityPower) and "✨" or effects.discount and "🏷️" or "🃏"
				UI.label(card, glyph, {Name = "CardGlyph", Position = at(desc, cardRect), Size = UDim2.fromOffset(desc.w, 52), TextSize = 40, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 54})
				desc = { x = desc.x, y = desc.y + 54, w = desc.w, h = desc.h - 54 }
				descSize = 16
			end
			UI.label(card, L(def.description), {Position = at(desc, cardRect), Size = dims(desc), TextSize = descSize, TextColor3 = P.stacked and C.muted or C.text, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Top, TextXAlignment = P.stacked and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center, ZIndex = 54})
			UI.button(card, T("ESCOLHER", "CHOOSE").." • "..Catalog.Upper(rarity and L(rarity.name) or ""), function() act("ChooseCard", {cardId = id}) end, {Position = at(P.buttons[index], cardRect), Size = dims(P.buttons[index]), BackgroundColor3=tint, TextSize = P.stacked and 12 or 14, ZIndex = 54})
		end
	end

	local function openBaseUpgrade()
		local state = ctx.state()
		if not activeMatch() or not state.match.base then return end
		local old=overlays:FindFirstChild("BaseUpgrade"); if old then old:Destroy() end
		local base=state.match.base; local def=Catalog.Bases[base.id]; local stats=base.stats
		local nextStats=Rules.BaseStats(base.id,math.min(5,base.level+1))
		local screen=screenSize()
		local shade=UI.frame(overlays,{Name="BaseUpgrade",Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,BackgroundTransparency=0.25,Active=true,ZIndex=45})
		local panel=UI.roundFrame(shade,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(math.min(420,screen.X-24),math.min(486,screen.Y-24)),BackgroundColor3=C.background,ZIndex=46},C.green)
		UI.label(panel,T("EVOLUIR BASE","UPGRADE BASE"),{Position=UDim2.fromOffset(14,12),Size=UDim2.new(1,-72,0,30),TextColor3=C.green,TextSize=19,Font=Enum.Font.GothamBlack,ZIndex=47})
		UI.button(panel,"×",function() shade:Destroy() end,{Position=UDim2.new(1,-50,0,6),Size=UDim2.fromOffset(44,44),BackgroundColor3=C.red,TextSize=25,ZIndex=47})
		local body=UI.scroll(panel,{Position=UDim2.fromOffset(14,58),Size=UDim2.new(1,-28,1,-70),ZIndex=47}); UI.list(body,10)
		local art=UI.row(body,106); art.ZIndex=47
		UI.basePortrait(art,def,{Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(104,104),ZIndex=48})
		UI.label(art,L(def.name).."\n"..T("MELHORIA ","UPGRADE ")..base.level.." / 5",{Position=UDim2.fromOffset(114,4),Size=UDim2.new(1,-124,1,-8),TextSize=18,Font=Enum.Font.GothamBlack,TextWrapped=true,ZIndex=48})
		local function line(text,color,height) UI.label(body,text,{Size=UDim2.new(1,-8,0,height or 28),TextSize=13,TextWrapped=true,TextColor3=color or C.text,ZIndex=48}) end
		line(L(def.description),C.muted,46)
		line(T("RENDA POR ONDA: ","INCOME PER WAVE: ")..stats.income.." → "..nextStats.income..T(" Ouro"," Gold"),C.gold)
		line(T("VIDA EXTRA DO NÚCLEO: ","EXTRA CORE HP: ")..math.floor(stats.hp/(state.match.partySize or 1)).." → "..math.floor(nextStats.hp/(state.match.partySize or 1)),C.green)
		if stats.damage>0 then line(T("DANO: ","DAMAGE: ")..stats.damage.." → "..nextStats.damage..T(" • ALCANCE: "," • RANGE: ")..stats.range.." → "..nextStats.range,C.coral) end
		if stats.wall>0 then line(T("BARRICADA: ","BARRICADE: ")..(base.wall or 0).."/"..stats.wall.." → "..nextStats.wall..T(" HP • regenera após 5 s"," HP • regenerates after 5 s"),C.blue,40) end
		if stats.soldier>0 then line(T("SOLDADO: ","SOLDIER: ")..stats.soldier.." → "..nextStats.soldier..T(" HP • a cada "," HP • every ")..stats.interval.." s",C.violet,40) end
		local button=UI.button(body,base.level>=5 and T("NÍVEL MÁXIMO","MAXIMUM LEVEL") or T("EVOLUIR • ","UPGRADE • ").."💰 "..stats.upgradeCost,function()
			act("UpgradeBase",{expectedLevel=base.level},function() audio:Cue("upgrade"); shade:Destroy() end)
		end,{Name="ConfirmBaseUpgrade",Size=UDim2.new(1,-8,0,48),TextSize=14,BackgroundColor3=C.green,ZIndex=48})
		if base.level>=5 or (state.match.cash or 0)<stats.upgradeCost then UI.disabled(button) end
		ctx.refs().refreshBaseModal=function()
			if not shade.Parent then ctx.refs().refreshBaseModal=nil; return end
			local current=ctx.state().match
			if not current or not current.base or current.base.level~=base.level then shade:Destroy(); ctx.refs().refreshBaseModal=nil; return end
			local missing=math.max(0,stats.upgradeCost-(current.cash or 0))
			if base.level>=5 then return end
			button.Text=missing>0 and T("FALTAM ","NEED ").."💰 "..number(missing) or T("EVOLUIR • ","UPGRADE • ").."💰 "..stats.upgradeCost
			if missing>0 then UI.disabled(button)
			else button.Active=true; button.AutoButtonColor=true; button.BackgroundColor3=C.green; button.TextColor3=C.background end
		end
		ctx.refs().refreshBaseModal()
		line(T("Usa o Ouro desta partida. O Ouro do lobby nunca é gasto aqui. Renda exige contribuição na onda.","Uses this match's Gold. Lobby Gold is never spent here. Income requires contribution to the wave."),C.muted,48)
	end

	local function renderResults()
		local result = ctx.state().results or {}
		local victory = result.victory == true or result.ended == true
		local veil = UI.frame(main, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.background, BackgroundTransparency = 0.12})
		local panel = UI.roundFrame(veil, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -32, 1, -50), BackgroundColor3 = C.panel}, victory and C.green or C.red)
		UI.create("UISizeConstraint", {MaxSize = Vector2.new(580, 720)}, panel)
		local content = UI.scroll(panel, {Name="ResultBody",Position = UDim2.fromOffset(20, 18), Size = UDim2.new(1, -40, 1, -98)})
		UI.frame(panel,{Position=UDim2.new(0,18,1,-75),Size=UDim2.new(1,-36,0,1),BackgroundColor3=C.stroke})
		-- Like the genre's best: one tap runs the same map again; going back to
		-- base is the quieter choice. Training always returns to the lobby.
		if result.modeId=="tutorial" then
			UI.button(panel,T("VOLTAR À BASE","RETURN TO BASE"),function() act("ReturnLobby",{}) end,{Name="ResultReturn",Position=UDim2.new(0,18,1,-64),Size=UDim2.new(1,-36,0,48),TextSize=15})
		else
			local waiting=result.again==true
			local again=UI.button(panel,waiting and (T("ESPERANDO ","WAITING ")..tostring(result.againVotes or 1).."/"..tostring(result.againTotal or 1)) or T("▶ JOGAR DE NOVO","▶ PLAY AGAIN"),
				function() act("PlayAgain",{}) end,{Name="ResultPlayAgain",Position=UDim2.new(0,18,1,-64),Size=UDim2.new(0.62,-24,0,48),BackgroundColor3=C.green,TextSize=16})
			if waiting then UI.disabled(again) end
			UI.secondary(panel,T("LOBBY","LOBBY"),function() act("ReturnLobby",{}) end,{Name="ResultReturn",Position=UDim2.new(0.62,0,1,-64),Size=UDim2.new(0.38,-18,0,48),TextSize=15})
		end
		UI.list(content, 12)
		local short=sizeClass().short
		local celebration=UI.row(content,short and 44 or 72)
		local emblemSize=short and 36 or 48
		UI.icon(celebration,victory and "trophy" or "heart",victory and C.gold or C.blue,{Position=UDim2.fromOffset(2,short and 4 or 12),Size=UDim2.fromOffset(emblemSize,emblemSize)})
		UI.label(celebration, result.ended and T("RECORDE GUARDADO!", "RECORD SAVED!") or victory and T("VOCÊS CONSEGUIRAM!", "YOU DID IT!") or T("VAMOS TENTAR DE NOVO?", "LET'S TRY AGAIN!"), {Position=UDim2.fromOffset(emblemSize+14,0),Size = UDim2.new(1, -emblemSize-20, 1, 0), TextSize = short and 20 or (mobile() and 22 or 27), Font = Enum.Font.GothamBlack, TextWrapped = true, TextColor3 = victory and C.green or C.blue})
		UI.label(content, mapName(result.mapId or "manhattan") .. "  /  " .. modeName(result.modeId or "normal", result.difficultyId), {Size = UDim2.new(1, -6, 0, short and 18 or 26), TextColor3 = C.muted, TextSize = short and 11 or 13, TextXAlignment = Enum.TextXAlignment.Center})
		if (tonumber(result.party) or 1) > 1 then
			UI.label(content, "👥 " .. T("BÔNUS DE GRUPO +", "PARTY BONUS +") .. math.floor((result.party - 1) * 100 + 0.5) .. "%", {Name = "ResultParty", Size = UDim2.new(1, -6, 0, short and 18 or 24), TextColor3 = C.gold, TextSize = short and 12 or 14, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center})
		end
		-- Core rewards stay together and appear before the optional detailed history,
		-- including on short screens where three large rows needed several scrolls.
		local rewards=UI.row(content,short and 64 or 82)
		rewards.Name="ResultRewards"
		for index,reward in ipairs({{T("ONDAS", "WAVES"), tostring(result.waves or 0), C.green}, {T("OURO", "GOLD"), "+" .. number(result.gold or 0), C.gold}, {"XP", "+" .. number(result.xp or 0), C.blue}}) do
			local tile=UI.roundFrame(rewards,{Name="Reward_"..index,Position=UDim2.new((index-1)/3,0,0,0),Size=UDim2.new(1/3,-6,1,0),BackgroundColor3=reward[3]:Lerp(C.card,0.9)},reward[3]:Lerp(C.stroke,0.5))
			UI.label(tile,reward[1],{Position=UDim2.fromOffset(4,6),Size=UDim2.new(1,-8,0,18),TextSize=12,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Center,Font=Enum.Font.GothamBold})
			UI.label(tile,reward[2],{Name="RewardValue_"..index,Position=UDim2.fromOffset(4,26),Size=UDim2.new(1,-8,1,-32),TextSize=mobile() and 19 or 24,TextColor3=reward[3],TextXAlignment=Enum.TextXAlignment.Center,Font=Enum.Font.GothamBlack})
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
			local card=UI.roundFrame(content,{Name="ResultMvp",Size=UDim2.new(1,-6,0,short and 54 or 66),BackgroundColor3=C.gold:Lerp(C.panel,0.72)},C.gold)
			UI.label(card,"⭐ MVP",{Position=UDim2.fromOffset(12,4),Size=UDim2.new(0,90,1,-8),TextSize=short and 18 or 22,Font=UI.Fonts.display,TextColor3=C.gold})
			UI.label(card,mine and T("VOCÊ!","YOU!") or tostring(mvp.name),{Name="MvpName",Position=UDim2.fromOffset(102,4),Size=UDim2.new(1,-112,0.5,-2),TextSize=short and 15 or 18,Font=UI.Fonts.display,TextTruncate=Enum.TextTruncate.AtEnd})
			UI.label(card,"⚔ "..number(mvp.damage).."   💀 "..number(mvp.kills).."   💰 "..number(mvp.gold),{Name="MvpStats",Position=UDim2.new(0,102,0.5,0),Size=UDim2.new(1,-112,0.5,-4),TextSize=short and 13 or 15,Font=UI.Fonts.display,TextColor3=C.cream})
			for index=2,#team do
				local entry=team[index]
				local row=UI.row(content,short and 26 or 30)
				row.Name="ResultTeam_"..index
				UI.label(row,(entry.userId==player.UserId and T("Você","You") or tostring(entry.name)),{Size=UDim2.new(0.5,0,1,0),TextSize=14,Font=UI.Fonts.display,TextTruncate=Enum.TextTruncate.AtEnd})
				UI.label(row,"⚔ "..number(entry.damage).."   💀 "..number(entry.kills),{Position=UDim2.fromScale(0.5,0),Size=UDim2.new(0.5,0,1,0),TextSize=14,Font=UI.Fonts.display,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Right})
			end
		end
		if result.modeId=="ranked" then
			local tier=Rules.RankForWaves(result.waves)
			UI.section(content,"RANK: "..(ctx.language()=="en" and tier.en or tier.pt),T("Seu melhor resultado fica no placar da temporada.","Your best result stays on the seasonal leaderboard."))
		end
		local earnedPoints = math.max(0, (profile().level or 1) - (result.startLevel or profile().level or 1))
		local evolution = UI.roundFrame(content, {Name = "ResultEvolution", Size = UDim2.new(1, -6, 0, 98), BackgroundColor3 = C.gold:Lerp(C.background, 0.88)}, C.gold)
		UI.label(evolution, T("COMANDANTE • NÍVEL ", "COMMANDER • LEVEL ") .. tostring(profile().level or 1), {Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 24), Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.gold})
		UI.label(evolution, earnedPoints > 0 and ("+" .. earnedPoints .. T(" ponto(s) para sua árvore!", " point(s) for your talent tree!")) or T("Continue ganhando XP para liberar outro ponto.", "Keep earning XP to unlock another point."), {Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 0, 36), TextWrapped = true, TextSize = 13})
		local xpTrack = UI.frame(evolution, {Position = UDim2.fromOffset(12, 82), Size = UDim2.new(1, -24, 0, 5), BackgroundColor3 = C.stroke})
		UI.frame(xpTrack, {Size = UDim2.fromScale(levelProgress(), 1), BackgroundColor3 = C.gold})
		-- The season pass: where this match's XP took it, and whether a claim waits.
		local season = profile().seasonStatus
		if season then
			local seasonCard = UI.roundFrame(content, {Name = "ResultSeason", Size = UDim2.new(1, -6, 0, 78), BackgroundColor3 = C.violet:Lerp(C.background, 0.86)}, C.violet)
			UI.label(seasonCard, T("TEMPORADA • NÍVEL ", "SEASON • LEVEL ") .. tostring(season.level) .. "/" .. tostring(season.maxLevel), {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 22), Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.violet})
			local seasonTrack = UI.frame(seasonCard, {Position = UDim2.fromOffset(12, 36), Size = UDim2.new(1, -24, 0, 8), BackgroundColor3 = C.stroke})
			UI.corner(seasonTrack, 4)
			local seasonFill = UI.frame(seasonTrack, {Size = UDim2.fromScale(math.clamp(season.xpInto / season.xpPerLevel, 0, 1), 1), BackgroundColor3 = C.violet})
			UI.corner(seasonFill, 4)
			UI.label(seasonCard, season.claimable > 0 and (tostring(season.claimable) .. T(" prêmio(s) esperando em PRÊMIOS!", " reward(s) waiting in GIFTS!")) or (number(season.xpInto) .. " / " .. number(season.xpPerLevel) .. " XP"),
				{Name = "ResultSeasonHint", Position = UDim2.fromOffset(12, 50), Size = UDim2.new(1, -24, 0, 22), TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = season.claimable > 0 and C.gold or C.muted})
		end
		local gains = {}
		for heroId, earned in pairs(result.mastery or {}) do
			if Catalog.Heroes[heroId] and earned > 0 then table.insert(gains, {id = heroId, xp = earned}) end
		end
		table.sort(gains, function(a, b) return a.xp > b.xp end)
		if #gains > 0 then
			local card = UI.roundFrame(content, {Size = UDim2.new(1, -6, 0, 34 + #gains * 26), BackgroundColor3 = C.card})
			UI.label(card, T("SEUS HERÓIS APRENDERAM!", "YOUR HEROES GREW!"), {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 20), TextSize = 12, TextColor3 = C.muted, Font = Enum.Font.GothamBold})
			for index, gain in ipairs(gains) do
				local y = 30 + (index - 1) * 26
				UI.label(card, heroName(gain.id), {Position = UDim2.fromOffset(12, y), Size = UDim2.new(0.62, -12, 0, 22), TextSize = 13, TextColor3 = colorFor(gain.id)})
				UI.label(card, "+" .. number(gain.xp) .. " XP", {Position = UDim2.new(0.62, 0, 0, y), Size = UDim2.new(0.38, -12, 0, 22), TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right})
			end
		end
		UI.label(content,T("Próximo objetivo: evolua a habilidade do líder ou recrute nos baús.","Next goal: upgrade your leader ability or recruit from chests."),{Size=UDim2.new(1,-6,0,50),TextWrapped=true,TextColor3=C.muted})
		welcomePanel(panel)
	end

	return {
		towerStatsText = towerStatsText, towerPanel = towerPanel,
		clearUpgradeBoards = clearUpgradeBoards, updateUpgradeBoards = updateUpgradeBoards,
		protocolModal = protocolModal, openBaseUpgrade = openBaseUpgrade, renderResults = renderResults,
	}
end

return MatchHud
