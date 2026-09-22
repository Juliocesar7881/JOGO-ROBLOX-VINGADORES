-- Moments of joy: the chest reveal, big banners (boss down, level up, wave
-- cleared, victory), confetti and small "punch" pops on counters.
--
-- Every animation here is a pure function of elapsed time, driven from the
-- client's RenderStepped through Celebrate:Step. That keeps it deterministic
-- (the client test advances a fake clock and sees the final state) and lets a
-- tap skip straight to the end. Nothing here decides a reward: every result
-- shown was already committed by the server before the animation starts.
--
-- "Reduced effects" is the photosensitivity option: it removes the white
-- flash, the colour strobing while the chest charges, shaking and confetti,
-- and shortens the reveal, but still shows exactly the same result.
local Catalog = require(game:GetService("ReplicatedStorage"):WaitForChild("DoomShared"):WaitForChild("Catalog"))

local Celebrate = {}
Celebrate.__index = Celebrate

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.new(0, 0, 0)
local CONFETTI = {
	Color3.fromRGB(255, 206, 82), Color3.fromRGB(255, 129, 134), Color3.fromRGB(120, 212, 255),
	Color3.fromRGB(135, 235, 113), Color3.fromRGB(203, 170, 255), Color3.fromRGB(255, 159, 215),
}
-- Pieces of confetti per rarity: a common hero is still a hero, a mythic is a party.
local CONFETTI_BY_TIER = { 8, 16, 28, 44, 64 }

local function clamp01(x) return math.clamp(x, 0, 1) end
local function lerp(a, b, t) return a + (b - a) * t end
-- Overshoots a little and settles: the "pop" every celebration uses.
local function backOut(x)
	x = clamp01(x)
	local c1 = 1.70158
	local c3 = c1 + 1
	return 1 + c3 * (x - 1) ^ 3 + c1 * (x - 1) ^ 2
end

function Celebrate.new(options)
	local self = setmetatable({}, Celebrate)
	self.UI = options.UI
	self.root = options.root
	self.audio = options.audio
	self.portrait = options.portrait
	self.language = options.language or function() return "pt" end
	self.lowFX = options.lowFX or function() return false end
	self.clock = options.clock or os.clock
	self.random = Random.new(9001)
	self.animations = {}
	self.confetti = {}
	return self
end

function Celebrate:_t(value)
	if type(value) == "table" then return value[self.language()] or value.pt or "" end
	return tostring(value or "")
end

function Celebrate:_cue(name, gap)
	if self.audio then pcall(self.audio.Cue, self.audio, name, gap) end
end

function Celebrate:_add(record)
	record.start = self.clock()
	table.insert(self.animations, record)
	record.update(0, 0)
	return record
end

function Celebrate:Busy()
	return self.reveal ~= nil
end

--==============================================================================
-- Confetti
--==============================================================================
function Celebrate:Confetti(count, originScale)
	if self.lowFX() or count <= 0 then return end
	local size = self.root.AbsoluteSize
	local width, height = math.max(size.X, 320), math.max(size.Y, 280)
	originScale = originScale or 0.35
	for _ = 1, math.min(count, 80) do
		local piece = self.UI.frame(self.root, {
			Name = "Confetti", AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 95,
			Size = UDim2.fromOffset(self.random:NextInteger(6, 12), self.random:NextInteger(10, 18)),
			BackgroundColor3 = CONFETTI[self.random:NextInteger(1, #CONFETTI)],
		})
		table.insert(self.confetti, {
			part = piece, born = self.clock(),
			x = width * 0.5, y = height * originScale,
			vx = self.random:NextNumber(-1, 1) * width * 0.45, vy = -self.random:NextNumber(height * 0.35, height * 0.85),
			spin = self.random:NextNumber(-540, 540), life = self.random:NextNumber(1.6, 2.6),
		})
	end
end

function Celebrate:_stepConfetti(now)
	local height = math.max(self.root.AbsoluteSize.Y, 280)
	for index = #self.confetti, 1, -1 do
		local piece = self.confetti[index]
		local t = now - piece.born
		if t >= piece.life or not piece.part.Parent then
			if piece.part.Parent then piece.part:Destroy() end
			table.remove(self.confetti, index)
		else
			-- Thrown up, pulled down by a gravity scaled to the screen.
			local x = piece.x + piece.vx * t
			local y = piece.y + piece.vy * t + 0.5 * height * 1.9 * t * t
			piece.part.Position = UDim2.fromOffset(x, y)
			piece.part.Rotation = piece.spin * t
			piece.part.BackgroundTransparency = clamp01((t - piece.life * 0.7) / (piece.life * 0.3))
		end
	end
end

--==============================================================================
-- Pops and floating numbers on existing HUD elements
--==============================================================================
-- A quick squash-and-stretch on any GuiObject: gold counters, badges, cards.
function Celebrate:Pop(gui, strength)
	if not gui or not gui.Parent then return end
	local scale = gui:FindFirstChild("PopScale") or self.UI.create("UIScale", { Name = "PopScale", Scale = 1 }, gui)
	strength = strength or 0.18
	self:_add({ duration = 0.35, update = function(t)
		local x = clamp01(t / 0.35)
		scale.Scale = 1 + strength * math.sin(x * math.pi) * (1 - x * 0.5)
		if x >= 1 then scale.Scale = 1 end
	end })
end

-- "+150" rising from a HUD element and fading out.
function Celebrate:Float(text, anchor, color)
	if not anchor or not anchor.Parent then return end
	local position = anchor.AbsolutePosition or Vector2.new(0, 0)
	local size = anchor.AbsoluteSize or Vector2.new(0, 0)
	local label = self.UI.label(self.root, text, {
		Name = "FloatingGain", AnchorPoint = Vector2.new(0.5, 1), ZIndex = 96,
		Size = UDim2.fromOffset(160, 30), Font = Enum.Font.GothamBlack, TextSize = 20,
		TextColor3 = color or Color3.fromRGB(255, 206, 82), TextXAlignment = Enum.TextXAlignment.Center,
		TextStrokeTransparency = 0.35,
	})
	local x, y = position.X + size.X / 2, position.Y + size.Y + 26
	self:_add({ duration = 1.1, update = function(t)
		local x01 = clamp01(t / 1.1)
		label.Position = UDim2.fromOffset(x, y - 46 * backOut(math.min(1, t / 0.4)) - 12 * x01)
		label.TextTransparency = clamp01((x01 - 0.6) / 0.4)
		label.TextStrokeTransparency = 0.35 + 0.65 * clamp01((x01 - 0.6) / 0.4)
	end, done = function() if label.Parent then label:Destroy() end end })
end

-- A number rolling up to its value, like a slot machine settling on a prize.
-- format turns the running number into the label's text.
function Celebrate:CountUp(label, target, format, duration)
	if not label then return end
	target = tonumber(target) or 0
	format = format or tostring
	if self.lowFX() or target <= 0 then label.Text = format(target) return end
	duration = duration or 1.2
	local ticked = -1
	self:_add({ duration = duration, update = function(t)
		if not label.Parent then return end
		local x = clamp01(t / duration)
		local value = math.floor(target * (1 - (1 - x) ^ 3) + 0.5)
		label.Text = format(value)
		-- A soft tick every few steps: the counter sounds like it is filling.
		local step = math.floor(x * 8)
		if step ~= ticked then ticked = step; self:_cue("collect", 0.06) end
	end, done = function() if label.Parent then label.Text = format(target) end end })
end

--==============================================================================
-- Banners
--==============================================================================
-- One big line across the upper screen. big = boss down, level up, victory.
function Celebrate:Banner(title, subtitle, tint, options)
	options = options or {}
	if self.banner and self.banner.Parent then self.banner:Destroy() end
	tint = tint or Color3.fromRGB(255, 206, 82)
	local big = options.big == true
	local duration = options.duration or (big and 2.6 or 1.7)
	local banner = self.UI.frame(self.root, {
		Name = "CelebrationBanner", AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 90,
		Position = UDim2.new(0.5, 0, big and 0.3 or 0.24, 0), Size = UDim2.new(0.86, 0, 0, big and 92 or 62),
		BackgroundColor3 = tint:Lerp(BLACK, 0.55), BackgroundTransparency = 0.08,
	})
	self.UI.create("UISizeConstraint", { MaxSize = Vector2.new(big and 620 or 460, 200) }, banner)
	self.UI.corner(banner, 18)
	self.UI.stroke(banner, tint, big and 4 or 2)
	local scale = self.UI.create("UIScale", { Scale = 0.2 }, banner)
	local titleLabel = self.UI.label(banner, self:_t(title), {
		Name = "BannerTitle", Size = UDim2.new(1, -20, 0, big and 52 or 36), Position = UDim2.fromOffset(10, big and 6 or 3),
		Font = Enum.Font.GothamBlack, TextSize = big and 36 or 24, TextColor3 = tint:Lerp(WHITE, 0.35), TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, ZIndex = 91,
	})
	local subtitleLabel = subtitle and self.UI.label(banner, self:_t(subtitle), {
		Name = "BannerSubtitle", Size = UDim2.new(1, -20, 0, big and 26 or 20), Position = UDim2.new(0, 10, 1, big and -32 or -24),
		Font = Enum.Font.GothamBold, TextSize = big and 17 or 13, TextColor3 = WHITE,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 91,
	}) or nil
	self.banner = banner
	if options.cue then self:_cue(options.cue, 0.2) end
	if big then self:Confetti(options.confetti or 30, 0.3) end
	self:_add({ duration = duration, update = function(t)
		if not banner.Parent then return end
		local fadeOut = clamp01((t - (duration - 0.35)) / 0.35)
		scale.Scale = (self.lowFX() and 1 or backOut(t / 0.4)) * (1 - 0.15 * fadeOut)
		banner.BackgroundTransparency = 0.08 + 0.92 * fadeOut
		titleLabel.TextTransparency = fadeOut
		titleLabel.TextStrokeTransparency = 0.2 + 0.8 * fadeOut
		if subtitleLabel then subtitleLabel.TextTransparency = fadeOut end
		local stroke = banner:FindFirstChildOfClass("UIStroke")
		if stroke then stroke.Transparency = 0.15 + 0.85 * fadeOut end
	end, done = function() if banner.Parent then banner:Destroy() end end })
	return banner
end

--==============================================================================
-- The chest reveal
--==============================================================================
local function drawChest(UI, parent, tint)
	local gold = Color3.fromRGB(255, 206, 82)
	local body = UI.frame(parent, { Name = "ChestBody", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(0.9, 0, 0.55, 0), BackgroundColor3 = tint:Lerp(BLACK, 0.3), ZIndex = 84 })
	UI.corner(body, 14)
	UI.stroke(body, gold, 3)
	for _, x in ipairs({ 0.18, 0.72 }) do
		UI.frame(body, { Position = UDim2.new(x, 0, 0, 0), Size = UDim2.new(0.1, 0, 1, 0), BackgroundColor3 = gold, ZIndex = 85 })
	end
	local lock = UI.frame(body, { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.08, 0), Size = UDim2.new(0.2, 0, 0.42, 0), BackgroundColor3 = gold, ZIndex = 86 })
	UI.corner(lock, 8)
	local lid = UI.frame(parent, { Name = "ChestLid", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 0.47, 0), Size = UDim2.new(1, 0, 0.36, 0), BackgroundColor3 = tint, ZIndex = 87 })
	UI.corner(lid, 18)
	UI.stroke(lid, gold, 3)
	for _, x in ipairs({ 0.2, 0.7 }) do
		UI.frame(lid, { Position = UDim2.new(x, 0, 0, 0), Size = UDim2.new(0.09, 0, 1, 0), BackgroundColor3 = gold, ZIndex = 88 })
	end
	return lid
end

-- result: the server's committed OpenChest result {heroId, rarity, duplicate,
-- refundGold, refundMastery}. chestId picks the chest's own colour.
function Celebrate:Chest(result, chestId, onClosed)
	if type(result) ~= "table" or not Catalog.Heroes[result.heroId] then return end
	if self.reveal then self:_closeReveal() end
	local UI = self.UI
	local lowFX = self.lowFX()
	local hero = Catalog.Heroes[result.heroId]
	local rarity = Catalog.Rarities[result.rarity] or Catalog.Rarities[hero.rarity]
	local tiers = Catalog.RarityOrder
	local tierIndex = table.find(tiers, rarity.id) or 1
	local chest = Catalog.Chests[chestId or "rare"] or Catalog.Chests.rare
	local chestTint = UI.color(chest.color)
	local finalTint = UI.color(rarity.color)

	-- Suspense scales with the prize: a common opens quickly, a mythic makes
	-- the chest climb through every colour first.
	local tierTime = lowFX and 0 or 0.5
	local intro = 0.35
	local openAt = intro + tierIndex * tierTime + (lowFX and 0.15 or 0.35)
	local cardAt = openAt + 0.1
	local finalAt = cardAt + (lowFX and 0.1 or 0.55)

	local root = UI.frame(self.root, { Name = "ChestReveal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = BLACK, BackgroundTransparency = 1, ZIndex = 80, Active = true })
	local skip = UI.button(root, "", function() self:SkipReveal() end, { Name = "RevealSkip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 81, AutoButtonColor = false })
	local stage = UI.frame(root, { Name = "RevealStage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(380, 380), BackgroundTransparency = 1, ZIndex = 82 })
	local screen = self.root.AbsoluteSize
	UI.create("UIScale", { Scale = math.clamp(math.min(screen.X, screen.Y) / 460, 0.55, 1.35) }, stage)

	local rays = UI.frame(stage, { Name = "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 82, Visible = false })
	for index = 0, 7 do
		UI.frame(rays, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 640), Rotation = index * 22.5, BackgroundColor3 = finalTint, BackgroundTransparency = 0.72, ZIndex = 82 })
	end
	local glow = UI.frame(stage, { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(200, 200), BackgroundColor3 = UI.color(Catalog.Rarities[tiers[1]].color), BackgroundTransparency = 0.55, ZIndex = 83 })
	UI.corner(glow, 200)
	local chestGroup = UI.frame(stage, { Name = "RevealChest", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.55), Size = UDim2.fromOffset(190, 170), BackgroundTransparency = 1, ZIndex = 84 })
	local chestScale = UI.create("UIScale", { Scale = 0 }, chestGroup)
	local lid = drawChest(UI, chestGroup, chestTint)
	local lidRest = lid.Position
	local tierLabel = UI.label(stage, "", { Name = "TierLabel", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromOffset(360, 44), Font = Enum.Font.GothamBlack, TextSize = 30, TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.25, ZIndex = 89 })

	local card = UI.frame(stage, { Name = "RevealHeroCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(270, 350), BackgroundColor3 = finalTint:Lerp(BLACK, 0.7), Visible = false, ZIndex = 90 })
	UI.corner(card, 22)
	UI.stroke(card, finalTint, 4)
	local cardScale = UI.create("UIScale", { Scale = 0 }, card)
	UI.label(card, Catalog.Upper(self:_t(rarity.name)) .. "!", { Name = "RevealRarity", Position = UDim2.fromOffset(10, 10), Size = UDim2.new(1, -20, 0, 34), Font = Enum.Font.GothamBlack, TextSize = 28, TextColor3 = finalTint:Lerp(WHITE, 0.2), TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.3, ZIndex = 91 })
	if self.portrait then
		pcall(self.portrait, card, result.heroId, { Name = "RevealPortrait", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 48), Size = UDim2.fromOffset(190, 196), ZIndex = 91 })
	end
	UI.label(card, self:_t(hero.name), { Name = "RevealName", Position = UDim2.fromOffset(10, 250), Size = UDim2.new(1, -20, 0, 34), Font = Enum.Font.GothamBlack, TextSize = 24, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true, ZIndex = 91 })
	local statusText = result.duplicate
		and self:_t({ pt = "REPETIDO  •  +" .. tostring(result.refundGold or 0) .. " Ouro  •  +" .. tostring(result.refundMastery or 0) .. " XP do herói", en = "DUPLICATE  •  +" .. tostring(result.refundGold or 0) .. " Gold  •  +" .. tostring(result.refundMastery or 0) .. " hero XP" })
		or self:_t({ pt = "NOVO HERÓI!", en = "NEW HERO!" })
	local status = UI.label(card, statusText, { Name = "RevealStatus", Position = UDim2.fromOffset(10, 290), Size = UDim2.new(1, -20, 0, 48), Font = Enum.Font.GothamBlack, TextSize = result.duplicate and 13 or 24, TextWrapped = true, TextColor3 = result.duplicate and Color3.fromRGB(255, 206, 82) or Color3.fromRGB(135, 235, 113), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 91 })
	local statusScale = UI.create("UIScale", { Scale = 1 }, status)

	local continueButton = UI.button(root, self:_t({ pt = "INCRÍVEL!", en = "AWESOME!" }), function() self:_closeReveal() end, {
		Name = "RevealContinue", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(240, 56),
		BackgroundColor3 = finalTint, TextSize = 20, Visible = false, ZIndex = 95,
	})
	local flash = UI.frame(root, { Name = "RevealFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 94, Active = false })

	local lastTier, opened, carded = 0, false, false
	self:_cue("chest", 0.05)
	self.reveal = { root = root, finalAt = finalAt, onClosed = onClosed, result = result }
	self.reveal.anim = self:_add({ duration = math.huge, update = function(t, dt)
		if not root.Parent then return end
		root.BackgroundTransparency = lerp(1, 0.16, clamp01(t / 0.3))
		-- 1. The chest drops in.
		if t < openAt then
			chestScale.Scale = backOut(t / intro)
			-- 2. It charges, climbing one rarity colour at a time.
			local charging = t >= intro
			local tier = lowFX and tierIndex or (charging and math.min(tierIndex, math.floor((t - intro) / math.max(tierTime, 0.001)) + 1) or 1)
			if charging and tier ~= lastTier then
				lastTier = tier
				local tint = UI.color(Catalog.Rarities[tiers[tier]].color)
				glow.BackgroundColor3 = tint
				tierLabel.TextColor3 = tint:Lerp(WHITE, 0.25)
				tierLabel.Text = Catalog.Upper(self:_t(Catalog.Rarities[tiers[tier]].name)) .. string.rep("!", tier - 1)
				if not lowFX then self:_cue(tier >= 4 and "levelUp" or "collect", 0.05) end
			end
			local amplitude = lowFX and 0 or (charging and (2 + lastTier * 2.5) or 0)
			chestGroup.Rotation = math.sin(t * 46) * amplitude
			local pulse = lowFX and 0 or math.sin(t * 14) * (8 + lastTier * 5)
			glow.Size = UDim2.fromOffset(190 + lastTier * 18 + pulse, 190 + lastTier * 18 + pulse)
		else
			-- 3. It bursts open.
			if not opened then
				opened = true
				chestGroup.Rotation = 0
				glow.BackgroundColor3 = finalTint
				tierLabel.Text = ""
				rays.Visible = not lowFX
				self:_cue("victory", 0.05)
				self:Confetti(CONFETTI_BY_TIER[tierIndex] or 10, 0.4)
			end
			local burst = clamp01((t - openAt) / 0.35)
			lid.Position = UDim2.new(lidRest.X.Scale, lidRest.X.Offset, lidRest.Y.Scale, lidRest.Y.Offset - 90 * burst)
			lid.Rotation = -28 * burst
			lid.BackgroundTransparency = burst
			chestScale.Scale = 1 - 0.35 * burst
			chestGroup.Position = UDim2.new(0.5, 0, 0.55 + 0.25 * burst, 0)
			if not lowFX then
				flash.BackgroundTransparency = lerp(0.25, 1, clamp01((t - openAt) / 0.4))
				rays.Rotation = (t - openAt) * 22
			end
			glow.Size = UDim2.fromOffset(260 + 90 * burst, 260 + 90 * burst)
			glow.BackgroundTransparency = lerp(0.45, 0.7, burst)
		end
		-- 4. The hero pops out.
		if t >= cardAt then
			if not carded then
				carded = true
				card.Visible = true
				if tierIndex >= 4 then self:_cue("levelUp", 0.05) end
			end
			cardScale.Scale = lowFX and 1 or backOut((t - cardAt) / 0.45)
		end
		if t >= finalAt then
			continueButton.Visible = true
			if not result.duplicate and not lowFX then statusScale.Scale = 1 + 0.07 * math.sin(t * 6) end
		end
	end })
	return root
end

-- A tap during the build-up jumps straight to the revealed hero.
function Celebrate:SkipReveal()
	local reveal = self.reveal
	if not reveal or not reveal.anim then return end
	local elapsed = self.clock() - reveal.anim.start
	if elapsed < reveal.finalAt then
		reveal.anim.start = self.clock() - reveal.finalAt
		reveal.anim.update(reveal.finalAt, 0)
	end
end

function Celebrate:_closeReveal()
	local reveal = self.reveal
	if not reveal then return end
	self.reveal = nil
	for index, record in ipairs(self.animations) do
		if record == reveal.anim then table.remove(self.animations, index) break end
	end
	if reveal.root.Parent then reveal.root:Destroy() end
	if reveal.onClosed then pcall(reveal.onClosed, reveal.result) end
end

--==============================================================================
-- Frame driver
--==============================================================================
function Celebrate:Step(dt)
	local now = self.clock()
	for index = #self.animations, 1, -1 do
		local record = self.animations[index]
		if record then
			local t = now - record.start
			local ok = pcall(record.update, t, dt or 0)
			if not ok or t >= record.duration then
				table.remove(self.animations, index)
				if record.done then pcall(record.done) end
			end
		end
	end
	self:_stepConfetti(now)
end

-- Scene changes (lobby <-> match) clear anything still on screen.
function Celebrate:Clear()
	if self.reveal then self:_closeReveal() end
	for _, record in ipairs(self.animations) do
		if record.done then pcall(record.done) end
	end
	self.animations = {}
	for _, piece in ipairs(self.confetti) do
		if piece.part.Parent then piece.part:Destroy() end
	end
	self.confetti = {}
	if self.banner and self.banner.Parent then self.banner:Destroy() end
	self.banner = nil
end

return Celebrate
