--!nonstrict
-- The enemy inspector. Tapping or clicking an enemy on the road shows a small
-- card: its name, how much health it has left, its armour and speed, what it
-- is (flying, hidden, a boss) and, in a line, what it does and what to answer
-- it with. The card is read off the enemy's catalogue entry and the health the
-- server last synced; nothing here decides a rule. It folds away after a few
-- seconds, or when the enemy is gone or the match ends.
local Inspect = {}
Inspect.__index = Inspect

local SHOWN_SECONDS = 5

-- ctx: gui (the overlay frame), UI, C (colours), T (pt/en), L (a {pt,en} to
-- the current language), Catalog, effects, state().
function Inspect.new(ctx)
	return setmetatable({ ctx = ctx, id = nil, card = nil, left = 0 }, Inspect)
end

-- How fast an enemy walks, in words a player can compare.
function Inspect.SpeedWord(speed, T)
	if speed >= 12 then return T("RÁPIDO", "FAST") end
	if speed >= 9 then return T("MÉDIO", "MEDIUM") end
	return T("LENTO", "SLOW")
end

function Inspect:Hide()
	if self.card then self.card:Destroy() end
	self.card, self.id, self.refs = nil, nil, nil
end

-- pinned: stays up until hidden (the screen review uses it).
function Inspect:Show(key, record, pinned)
	local ctx = self.ctx
	local UI, C, T, L = ctx.UI, ctx.C, ctx.T, ctx.L
	local def = record.def
	self:Hide()
	local screen = UI.toLogical(ctx.gui.AbsoluteSize)
	local short = screen and screen.Y < 500
	local card = UI.roundFrame(ctx.gui, {
		Name = "EnemyCard", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, short and -74 or -112),
		Size = UDim2.new(1, -32, 0, short and 86 or 100), ZIndex = 58, Active = false,
	}, def.boss and C.red or C.stroke)
	UI.create("UISizeConstraint", { MaxSize = Vector2.new(440, 120) }, card)
	local name = UI.label(card, L(def.name), { Name = "EnemyName", Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -150, 0, 24),
		Font = UI.Fonts.display, TextSize = 19, TextColor3 = def.boss and C.gold or C.cream, TextTruncate = Enum.TextTruncate.AtEnd, ZIndex = 59 })
	local health = UI.label(card, "", { Name = "EnemyHealth", Position = UDim2.new(1, -140, 0, 6), Size = UDim2.fromOffset(128, 24),
		Font = UI.Fonts.display, TextSize = 16, TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Right, ZIndex = 59 })
	local track = UI.frame(card, { Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 6), BackgroundColor3 = C.ink, ZIndex = 59 })
	UI.corner(track, 3)
	local fill = UI.frame(track, { Name = "EnemyHealthFill", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.green, ZIndex = 60 })
	UI.corner(fill, 3)
	-- Chips: armour, pace and what kind of enemy it is.
	local chips, x = {}, 12
	local function chip(text, color, width)
		UI.chip(card, text, color, { Position = UDim2.fromOffset(x, 44), Size = UDim2.fromOffset(width, 20), TextSize = 12, ZIndex = 59 })
		x += width + 6
	end
	if (def.armor or 0) > 0 then chip(T("ARMADURA ", "ARMOR ") .. tostring(math.floor((def.armor or 0) * 100 + 0.5)) .. "%", C.blue, 112) end
	chip(Inspect.SpeedWord(def.speed or 9, T), C.violet, 74)
	if def.air then chip(T("VOADOR", "FLYING"), C.cyan or C.blue, 78) end
	if def.stealth then chip(T("CAMUFLADO", "HIDDEN"), C.violet, 96) end
	if def.boss then chip(T("CHEFE", "BOSS"), C.red, 64) end
	local note = def.boss and def.hint or def.trait
	if note then
		UI.label(card, L(note), { Name = "EnemyNote", Position = UDim2.fromOffset(12, short and 66 or 68), Size = UDim2.new(1, -24, 0, short and 18 or 28),
			TextSize = short and 12 or 13, TextWrapped = true, TextColor3 = C.muted, ZIndex = 59 })
	end
	self.card, self.id, self.left, self.pinned = card, key, SHOWN_SECONDS, pinned == true
	self.refs = { health = health, fill = fill }
	self:_refresh(record)
end

function Inspect:_refresh(record)
	local refs = self.refs
	if not refs then return end
	local maxHP = math.max(1, record.maxHP or record.lastHP or 1)
	local hp = math.clamp(record.lastHP or maxHP, 0, maxHP)
	refs.health.Text = tostring(math.ceil(hp)) .. " / " .. tostring(math.ceil(maxHP))
	refs.fill.Size = UDim2.fromScale(hp / maxHP, 1)
end

function Inspect:Step(dt)
	if not self.card then return end
	local state = self.ctx.state()
	-- Even a pinned card (the screen review) goes when the match is over.
	if self.pinned then
		if not state or state.phase == "Lobby" or state.phase == "Results" then self:Hide() end
		return
	end
	local record = self.ctx.effects.enemies[self.id]
	self.left -= dt
	if not record or self.left <= 0 or not state or state.phase == "Lobby" or state.phase == "Results" then
		self:Hide()
		return
	end
	self:_refresh(record)
end

return Inspect
