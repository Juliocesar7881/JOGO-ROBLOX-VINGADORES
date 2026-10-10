--!nonstrict
-- The commander's sheet, openable at any time during a match: what you have
-- (your talents, your active base, the cards you picked) laid out to read,
-- never to change. Talents and the equipped base are chosen in the lobby; this
-- only shows them, and points at the one thing a match does allow, upgrading
-- the base with the match's own Gold. Pure presentation: nothing here asks the
-- server for anything.
local CardArt = require(script.Parent:WaitForChild("CardArt"))
local Sheet = {}
Sheet.__index = Sheet

-- ctx: UI, C, T, L, Catalog, Rules, overlays, screenSize(), state(), profile(),
-- number(), buildTalents(body, options), openBaseUpgrade().
function Sheet.new(ctx)
	return setmetatable({ ctx = ctx, tab = "talents" }, Sheet)
end

function Sheet:IsOpen()
	return self.shade ~= nil and self.shade.Parent ~= nil
end

function Sheet:Close()
	if self.shade then self.shade:Destroy() end
	self.shade, self.body = nil, nil
end

-- Called every frame: the sheet belongs to a match, so it goes with it, and its
-- numbers follow the base upgrades and the cards picked while it is open.
function Sheet:Sync()
	if not self:IsOpen() then return end
	local state = self.ctx.state()
	local match = state and state.match
	if not match or state.phase == "Lobby" or state.phase == "Results" then
		self:Close()
		return
	end
	local signature = Sheet._signature(match)
	if signature ~= self.signature then
		self.signature = signature
		self:_render()
	end
end

function Sheet._signature(match)
	return tostring(match.base and match.base.level) .. ":" .. tostring(#(match.cards or {})) .. ":" .. tostring(match.cardMode)
end

function Sheet:Toggle()
	if self:IsOpen() then self:Close() else self:Open() end
end

-- Tabs shown for this match: cards only appear in the cards mode, once picked.
function Sheet:_tabs()
	local ctx = self.ctx
	local T = ctx.T
	local match = ctx.state() and ctx.state().match
	-- The base is upgraded at the base agent standing beside it, not here.
	local tabs = {
		{ id = "talents", label = T("Talentos", "Talents") },
	}
	if match and match.cardMode then table.insert(tabs, { id = "cards", label = T("Cartas", "Cards") }) end
	return tabs
end

function Sheet:Open(tab)
	local ctx = self.ctx
	local UI, C, T = ctx.UI, ctx.C, ctx.T
	local state = ctx.state()
	if not state or not state.match then return end
	self:Close()
	self.signature = Sheet._signature(state.match)
	self.tab = tab or self.tab or "talents"
	local screen = ctx.screenSize()
	local shade = UI.frame(ctx.overlays, { Name = "CommanderSheet", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.background, BackgroundTransparency = 0.5, Active = true, ZIndex = 45 })
	self.panelWidth, self.panelHeight = math.min(560, screen.X - 24), math.min(620, screen.Y - 24)
	local panel = UI.roundFrame(shade, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(self.panelWidth, self.panelHeight), BackgroundColor3 = C.background, ZIndex = 46 }, C.violet)
	UI.windowSkin(panel, C.violet)
	UI.titleRibbon(panel, T("Ficha do comandante", "Commander sheet"), C.violet, {Position=UDim2.fromOffset(-8,-8), width=self.panelWidth-60, height=54, TextSize=26, ZIndex=47})
	UI.closeButton(panel, function() self:Close() end, { Name = "CloseSheet", Position = UDim2.new(1, -50, 0, 6), Size = UDim2.fromOffset(44, 44), TextSize = 25, ZIndex = 47 })
	self.shade, self.panel = shade, panel
	self:_render()
end

function Sheet:_render()
	local ctx = self.ctx
	local UI, C, T, L, Catalog = ctx.UI, ctx.C, ctx.T, ctx.L, ctx.Catalog
	local panel = self.panel
	if not (panel and panel.Parent) then return end
	local state = ctx.state()
	local match = state and state.match
	if not match then self:Close() return end
	local oldBody = panel:FindFirstChild("SheetBody")
	local outerPosition = oldBody and oldBody.CanvasPosition
	local oldTree = oldBody and oldBody:FindFirstChild("TalentScroll", true)
	local treePosition = oldTree and oldTree.CanvasPosition
	for _, child in ipairs(panel:GetChildren()) do
		if child.Name == "SheetTabs" or child.Name == "SheetBody" then child:Destroy() end
	end
	local tabs = self:_tabs()
	local known = false
	for _, tab in ipairs(tabs) do if tab.id == self.tab then known = true end end
	if not known then self.tab = "talents" end
	local width = self.panelWidth or (panel.AbsoluteSize.X > 0 and UI.toLogical(panel.AbsoluteSize.X) or 480)
	local tabBar = UI.frame(panel, { Name = "SheetTabs", Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -28, 0, 40), BackgroundTransparency = 1, ZIndex = 47 })
	local tabW = math.floor((width - 28 - (#tabs - 1) * 6) / #tabs)
	for index, tab in ipairs(tabs) do
		local on = tab.id == self.tab
		UI.button(tabBar, tab.label, function() self.tab = tab.id self:_render() end, {
			Name = "SheetTab_" .. tab.id, Position = UDim2.fromOffset((index - 1) * (tabW + 6), 0), Size = UDim2.fromOffset(tabW, 40),
			BackgroundColor3 = on and C.violet or C.card, TextColor3 = C.text, TextSize = 19, ZIndex = 48,
		})
	end
	local body = UI.scroll(panel, { Name = "SheetBody", Position = UDim2.fromOffset(14, 98), Size = UDim2.new(1, -28, 1, -110), ZIndex = 47 })
	UI.list(body, 8)
	self.body = body
	if self.tab == "talents" then
		local height = self.panelHeight or (panel.AbsoluteSize.Y > 0 and UI.toLogical(panel.AbsoluteSize.Y) or 540)
		-- The tree fills the window: the info card under it needs about 130.
		ctx.buildTalents(body, { readOnly = true, rerender = function() self:_render() end, canvasHeight = math.clamp(height - 260, 100, 420), canvasWidth = self.panelWidth and (self.panelWidth - 40) or nil, canvasPosition = treePosition })
	else
		self:_cardsTab(body, match)
	end
	if outerPosition then body.CanvasPosition = outerPosition end
end

function Sheet:_cardsTab(body, match)
	local ctx = self.ctx
	local UI, C, T, L, Catalog, Rules = ctx.UI, ctx.C, ctx.T, ctx.L, ctx.Catalog, ctx.Rules
	-- match.cards lists one id per stack: tally them.
	local counts, ids = {}, {}
	for _, id in ipairs(match.cards or {}) do
		if Catalog.Cards[id] then
			if not counts[id] then table.insert(ids, id) end
			counts[id] = (counts[id] or 0) + 1
		end
	end
	table.sort(ids)
	if #ids == 0 then
		UI.label(body, T("Nenhuma carta ainda. Você escolhe uma a cada 5 ondas.", "No cards yet. You pick one every 5 waves."), { Name = "NoCardsYet", Size = UDim2.new(1, -8, 0, 54), TextSize = 17, TextColor3 = C.muted, TextWrapped = true, ZIndex = 48 })
		return
	end
	-- Totals first: what the whole deck does to you, green or red.
	UI.label(body, T("Seu total", "Your total"), { Size = UDim2.new(1, -8, 0, 28), TextSize = 20, Font = UI.Fonts.display, TextColor3 = C.gold, ZIndex = 48 })
	local totals = UI.frame(body, { Name = "CardTotals", Size = UDim2.new(1, -8, 0, 10), BackgroundTransparency = 1, AutomaticSize = Enum.AutomaticSize.Y })
	UI.list(totals, 5)
	CardArt.totalRows(UI, Rules, T, totals, match.cards, 32, 17, 20, 0)
	UI.label(body, T("Cartas escolhidas", "Cards taken"), { Size = UDim2.new(1, -8, 0, 32), TextSize = 20, Font = UI.Fonts.display, TextColor3 = C.gold, ZIndex = 48 })
	for _, id in ipairs(ids) do
		local def = Catalog.Cards[id]
		local count = counts[id]
		local rarity = Catalog.Rarities[def.rarity]
		local tint = rarity and UI.color(rarity.color) or C.violet
		local rows = CardArt.rows(Rules, def, {}, T, count)
		local height = 70 + math.max(0, #rows - 1) * 34
		local row = UI.roundFrame(body, { Name = "SheetCard_" .. id, Size = UDim2.new(1, -8, 0, height), BackgroundColor3 = tint:Lerp(C.card, 0.8), ZIndex = 48 }, tint)
		CardArt.medallion(UI, row, def, tint, 54, { Position = UDim2.fromOffset(10, 8), ZIndex = 49 })
		UI.label(row, L(def.name) .. (count > 1 and ("  ×" .. count) or ""), { Position = UDim2.fromOffset(74, 6), Size = UDim2.new(1, -86, 0, 28), TextSize = 20, Font = UI.Fonts.display, TextColor3 = tint:Lerp(C.text, 0.4), ZIndex = 49 })
		for index, effect in ipairs(rows) do
			CardArt.chip(UI, row, effect, 220, 30, 15, 49).Position = UDim2.fromOffset(74, 36 + (index - 1) * 34)
		end
	end
end

return Sheet
