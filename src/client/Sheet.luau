--!nonstrict
-- The commander's sheet, openable at any time during a match: what you have
-- (your talents, your active base, the cards you picked) laid out to read,
-- never to change. Talents and the equipped base are chosen in the lobby; this
-- only shows them, and points at the one thing a match does allow, upgrading
-- the base with the match's own Gold. Pure presentation: nothing here asks the
-- server for anything.
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
		{ id = "talents", label = T("TALENTOS", "TALENTS") },
	}
	if match and match.cardMode and #(match.cards or {}) > 0 then table.insert(tabs, { id = "cards", label = T("CARTAS", "CARDS") }) end
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
	local shade = UI.frame(ctx.overlays, { Name = "CommanderSheet", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.background, BackgroundTransparency = 0.25, Active = true, ZIndex = 45 })
	local panel = UI.roundFrame(shade, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(math.min(520, screen.X - 24), math.min(600, screen.Y - 24)), BackgroundColor3 = C.background, ZIndex = 46 }, C.violet)
	UI.label(panel, T("FICHA DO COMANDANTE", "COMMANDER SHEET"), { Position = UDim2.fromOffset(14, 10), Size = UDim2.new(1, -72, 0, 30), TextColor3 = C.violet, TextSize = 19, Font = Enum.Font.GothamBlack, ZIndex = 47 })
	UI.button(panel, "×", function() self:Close() end, { Name = "CloseSheet", Position = UDim2.new(1, -50, 0, 6), Size = UDim2.fromOffset(44, 44), BackgroundColor3 = C.red, TextSize = 25, ZIndex = 47 })
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
	for _, child in ipairs(panel:GetChildren()) do
		if child.Name == "SheetTabs" or child.Name == "SheetBody" then child:Destroy() end
	end
	local tabs = self:_tabs()
	local known = false
	for _, tab in ipairs(tabs) do if tab.id == self.tab then known = true end end
	if not known then self.tab = "talents" end
	local width = panel.AbsoluteSize.X > 0 and panel.AbsoluteSize.X or 480
	local tabBar = UI.frame(panel, { Name = "SheetTabs", Position = UDim2.fromOffset(14, 50), Size = UDim2.new(1, -28, 0, 40), BackgroundTransparency = 1, ZIndex = 47 })
	local tabW = math.floor((width - 28 - (#tabs - 1) * 6) / #tabs)
	for index, tab in ipairs(tabs) do
		local on = tab.id == self.tab
		UI.button(tabBar, tab.label, function() self.tab = tab.id self:_render() end, {
			Name = "SheetTab_" .. tab.id, Position = UDim2.fromOffset((index - 1) * (tabW + 6), 0), Size = UDim2.fromOffset(tabW, 40),
			BackgroundColor3 = on and C.violet or C.card, TextColor3 = on and C.background or C.text, TextSize = 14, ZIndex = 48,
		})
	end
	local body = UI.scroll(panel, { Name = "SheetBody", Position = UDim2.fromOffset(14, 98), Size = UDim2.new(1, -28, 1, -110), ZIndex = 47 })
	UI.list(body, 10)
	self.body = body
	if self.tab == "talents" then
		local height = panel.AbsoluteSize.Y > 0 and panel.AbsoluteSize.Y or 540
		ctx.buildTalents(body, { readOnly = true, rerender = function() self:_render() end, canvasHeight = math.clamp(height - 300, 170, 400) })
	else
		self:_cardsTab(body, match)
	end
end

function Sheet:_cardsTab(body, match)
	local ctx = self.ctx
	local UI, C, T, L, Catalog = ctx.UI, ctx.C, ctx.T, ctx.L, ctx.Catalog
	-- match.cards lists one id per stack: tally them.
	local counts, ids = {}, {}
	for _, id in ipairs(match.cards or {}) do
		if Catalog.Cards[id] then
			if not counts[id] then table.insert(ids, id) end
			counts[id] = (counts[id] or 0) + 1
		end
	end
	table.sort(ids)
	UI.label(body, T("Cartas escolhidas nesta partida.", "Cards picked in this match."), { Size = UDim2.new(1, -8, 0, 24), TextSize = 13, TextColor3 = C.muted, ZIndex = 48 })
	for _, id in ipairs(ids) do
		local def = Catalog.Cards[id]
		local count = counts[id]
		local row = UI.roundFrame(body, { Name = "SheetCard_" .. id, Size = UDim2.new(1, -8, 0, 62), BackgroundColor3 = C.card, ZIndex = 48 })
		UI.label(row, L(def.name) .. (count > 1 and ("  ×" .. count) or ""), { Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -24, 0, 24), TextSize = 16, Font = UI.Fonts.display, TextColor3 = C.gold, ZIndex = 49 })
		UI.label(row, L(def.description), { Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 28), TextSize = 12, TextWrapped = true, TextColor3 = C.text, ZIndex = 49 })
	end
end

return Sheet
