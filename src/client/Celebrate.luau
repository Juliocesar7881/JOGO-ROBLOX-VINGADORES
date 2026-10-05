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
local Motion = require(script.Parent:WaitForChild("Motion"))

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
	self.livePortrait = options.livePortrait
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
	local size = self.UI.toLogical(self.root.AbsoluteSize)
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
	local height = math.max(self.UI.toLogical(self.root.AbsoluteSize).Y, 280)
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
	local origin = self.root.AbsolutePosition or Vector2.new(0, 0)
	local at = anchor.AbsolutePosition or origin
	local position = self.UI.toLogical(Vector2.new(at.X - origin.X, at.Y - origin.Y))
	local size = self.UI.toLogical(anchor.AbsoluteSize or Vector2.new(0, 0))
	local label = self.UI.label(self.root, text, {
		Name = "FloatingGain", AnchorPoint = Vector2.new(0.5, 1), ZIndex = 96,
		Size = UDim2.fromOffset(160, 30), Font = Enum.Font.FredokaOne, TextSize = 20,
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
		Font = Enum.Font.FredokaOne, TextSize = big and 36 or 24, TextColor3 = tint:Lerp(WHITE, 0.35), TextScaled = true,
		TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.2, ZIndex = 91,
	})
	local subtitleLabel = subtitle and self.UI.label(banner, self:_t(subtitle), {
		Name = "BannerSubtitle", Size = UDim2.new(1, -20, 0, big and 26 or 20), Position = UDim2.new(0, 10, 1, big and -32 or -24),
		Font = Enum.Font.BuilderSansExtraBold, TextSize = big and 17 or 13, TextColor3 = WHITE,
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
-- A real 3D treasure chest in a ViewportFrame: it drops in, shakes harder with
-- every rarity it climbs, bursts its lid open in a flash of light, and the
-- prize rises out of it on a card. Parts live only in the viewport.
local CHEST_GOLD = Color3.fromRGB(255, 200, 70)
local CHEST_INK = Color3.fromRGB(20, 22, 34)

local function chestModel(UI, world, tint)
	local rest, lid = {}, {}
	local function piece(name, size, cf, color, material, shape, onLid)
		local p = UI.create("Part", {
			Name = name, Size = size, CFrame = cf, Color = color, Material = material or Enum.Material.SmoothPlastic,
			Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
		}, world)
		if shape then p.Shape = shape end
		rest[p] = cf
		if onLid then lid[p] = true end
		return p
	end
	local dark = tint:Lerp(BLACK, 0.35)
	local cyl = Enum.PartType.Cylinder
	-- A gold chest gets bronze bands, or the bands would vanish into it.
	local near = math.abs(tint.R - CHEST_GOLD.R) + math.abs(tint.G - CHEST_GOLD.G) + math.abs(tint.B - CHEST_GOLD.B) < 0.45
	local CHEST_GOLD = near and Color3.fromRGB(140, 72, 34) or CHEST_GOLD
	-- Body, feet trim, gold bands and a lock plate on the front (-Z).
	piece("ChestBody", Vector3.new(4.4, 2.3, 3), CFrame.new(0, 1.35, 0), dark)
	piece("ChestFront", Vector3.new(4.1, 2.0, 0.1), CFrame.new(0, 1.35, -1.52), tint)
	piece("ChestFoot", Vector3.new(4.8, 0.4, 3.4), CFrame.new(0, 0.2, 0), CHEST_GOLD, Enum.Material.Metal)
	for _, x in ipairs({ -1.35, 1.35 }) do
		piece("ChestBand", Vector3.new(0.5, 2.35, 3.12), CFrame.new(x, 1.35, 0), CHEST_GOLD, Enum.Material.Metal)
	end
	piece("ChestLock", Vector3.new(1.1, 1.2, 0.3), CFrame.new(0, 1.85, -1.62), CHEST_GOLD, Enum.Material.Metal)
	piece("ChestKeyhole", Vector3.new(0.26, 0.5, 0.1), CFrame.new(0, 1.75, -1.8), CHEST_INK)
	-- The treasure glowing inside, seen once the lid lifts.
	local glow = piece("ChestTreasure", Vector3.new(3.9, 0.3, 2.6), CFrame.new(0, 2.45, 0), CHEST_GOLD, Enum.Material.Neon)
	-- The rounded lid: a half cylinder above the rim, hinged at the back.
	piece("ChestRim", Vector3.new(4.6, 0.3, 3.2), CFrame.new(0, 2.5, 0), CHEST_GOLD, Enum.Material.Metal, nil, true)
	piece("ChestLid", Vector3.new(4.4, 3, 3), CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, 0), tint, nil, cyl, true)
	for _, x in ipairs({ -1.35, 1.35 }) do
		piece("ChestLidBand", Vector3.new(0.5, 3.12, 3.12), CFrame.new(x, 2.5, 0), CHEST_GOLD, Enum.Material.Metal, cyl, true)
	end
	for _, x in ipairs({ -2.05, 2.05 }) do
		piece("ChestStud", Vector3.new(0.5, 0.5, 0.5), CFrame.new(x, 2.5, -1.55), CHEST_GOLD, Enum.Material.Metal, Enum.PartType.Ball, true)
	end
	return rest, lid, glow
end

-- result: the server's committed OpenChest result {heroId, rarity, duplicate,
-- refundGold, refundMastery}. chestId picks the chest's own colour.
-- options.quick skips the 3D chest's build-up (the reel has already built the
-- suspense); options.autoClose closes the card by itself that many seconds
-- after it is shown, which a run of several chests uses to flow on.
function Celebrate:Chest(result, chestId, onClosed, options)
	if type(result) ~= "table" or not (Catalog.Heroes[result.heroId] or Catalog.Bases[result.baseId]) then return end
	if self.reveal then self.reveal.onClosed = nil; self:_closeReveal() end
	local performer
	local UI = self.UI
	local lowFX = self.lowFX()
	local quick = options and options.quick == true
	local hero = Catalog.Bases[result.baseId] or Catalog.Heroes[result.heroId]
	local rarity = Catalog.Rarities[result.rarity] or Catalog.Rarities[hero.rarity]
	local tiers = Catalog.RarityOrder
	local tierIndex = table.find(tiers, rarity.id) or 1
	local chest = Catalog.Chests[chestId or "rare"] or Catalog.Chests.rare
	local chestTint = UI.color(chest.color)
	local finalTint = UI.color(rarity.color)

	-- Suspense scales with the prize: a common pops quickly, a mythic makes
	-- the chest climb through every colour first.
	local tierTime = (lowFX or quick) and 0 or 0.55
	local intro = lowFX and 0.1 or (quick and 0.12 or 0.45)
	local openAt = intro + tierIndex * tierTime + (lowFX and 0.1 or (quick and 0.12 or 0.3))
	local cardAt = openAt + (lowFX and 0.05 or (quick and 0.2 or 0.35))
	local finalAt = cardAt + (lowFX and 0.1 or (quick and 0.35 or 0.6))

	local root = UI.frame(self.root, { Name = "ChestReveal", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 30), BackgroundTransparency = 1, ZIndex = 80, Active = true })
	local skip = UI.button(root, "", function() self:SkipReveal() end, { Name = "RevealSkip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 81, AutoButtonColor = false })
	local stage = UI.frame(root, { Name = "RevealStage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(400, 400), BackgroundTransparency = 1, ZIndex = 82 })
	local screen = UI.toLogical(self.root.AbsoluteSize)
	UI.create("UIScale", { Scale = math.clamp(math.min(screen.X, screen.Y) / 470, 0.55, 1.4) }, stage)

	-- Light rays turn behind everything from the first frame, in the colour
	-- the chest has reached.
	local rays = UI.frame(stage, { Name = "Rays", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromOffset(10, 10), BackgroundTransparency = 1, ZIndex = 82, Visible = not lowFX })
	local rayBars = {}
	for index = 0, 11 do
		local bar = UI.frame(rays, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(index % 2 == 0 and 46 or 22, 760), Rotation = index * 15, BackgroundColor3 = WHITE, BackgroundTransparency = 0.86, ZIndex = 82 })
		table.insert(rayBars, bar)
	end
	local glow = UI.frame(stage, { Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(220, 220), BackgroundColor3 = UI.color(Catalog.Rarities[tiers[1]].color), BackgroundTransparency = 0.5, ZIndex = 83 })
	UI.corner(glow, 200)
	local halo = UI.frame(stage, { Name = "Halo", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(300, 300), BackgroundTransparency = 1, ZIndex = 83 })
	UI.corner(halo, 300)
	local haloStroke = UI.stroke(halo, WHITE, 6)
	haloStroke.Transparency = 1

	-- The 3D chest.
	local chestGroup = UI.frame(stage, { Name = "RevealChest", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.56), Size = UDim2.fromOffset(320, 280), BackgroundTransparency = 1, ZIndex = 84 })
	local view = UI.create("ViewportFrame", { Name = "ChestView", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 84,
		Ambient = Color3.fromRGB(170, 170, 190), LightColor = Color3.fromRGB(255, 244, 220), LightDirection = Vector3.new(-0.6, -1, 0.8) }, chestGroup)
	local world = UI.create("WorldModel", { Name = "ChestWorld" }, view)
	local camera = UI.create("Camera", { Name = "ChestCamera", FieldOfView = 36 }, view)
	camera.CFrame = CFrame.lookAt(Vector3.new(2.6, 4.6, -9.2), Vector3.new(0, 1.6, 0))
	view.CurrentCamera = camera
	local rest, lidParts, treasure = chestModel(UI, world, chestTint)
	local hinge = CFrame.new(0, 2.5, 1.5)
	local function pose(rig, lidAngle)
		local swing = hinge * CFrame.Angles(lidAngle, 0, 0) * hinge:Inverse()
		for p, cf in pairs(rest) do
			p.CFrame = lidParts[p] and rig * swing * cf or rig * cf
		end
	end
	pose(CFrame.new(0, 8, 0), 0)

	local tierLabel = UI.label(stage, "", { Name = "TierLabel", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.86), Size = UDim2.fromOffset(380, 48), Font = Enum.Font.FredokaOne, TextSize = 34, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 89 })
	UI.outline(tierLabel, 3)

	-- The prize card.
	local card = UI.frame(stage, { Name = "RevealHeroCard", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(280, 360), BackgroundColor3 = finalTint, Visible = false, ZIndex = 90 })
	UI.corner(card, 24)
	UI.stroke(card, WHITE, 5)
	UI.create("UIGradient", { Color = ColorSequence.new(finalTint:Lerp(WHITE, 0.15), finalTint:Lerp(BLACK, 0.55)), Rotation = 90 }, card)
	local cardScale = UI.create("UIScale", { Scale = 0 }, card)
	local stars = string.rep("★", tierIndex)
	local rarityLabel = UI.label(card, Catalog.Upper(self:_t(rarity.name)) .. "!", { Name = "RevealRarity", Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -20, 0, 36), Font = Enum.Font.FredokaOne, TextSize = 30, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 91 })
	UI.outline(rarityLabel, 3)
	local starLabel = UI.label(card, stars, { Name = "RevealStars", Position = UDim2.fromOffset(10, 42), Size = UDim2.new(1, -20, 0, 22), TextSize = 20, Font = Enum.Font.FredokaOne, TextColor3 = CHEST_GOLD, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 91 })
	UI.outline(starLabel, 2)
	local stageArt = UI.frame(card, { Name = "RevealArtStage", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 68), Size = UDim2.fromOffset(236, 190), BackgroundColor3 = BLACK, BackgroundTransparency = 0.7, ZIndex = 91 })
	UI.corner(stageArt, 18)
	if result.baseId then
		UI.basePortrait(card, hero, { Name = "RevealBase", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 72), Size = UDim2.fromOffset(220, 180), ZIndex = 92 })
	elseif self.portrait then
		local portraitProperties = { Name = "RevealPortrait", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 70), Size = UDim2.fromOffset(230, 186), BackgroundTransparency = 1, ZIndex = 92 }
		-- The hero is not a photograph: it jumps out of the chest, cheers and
		-- then keeps showing its signature move (see _performHero).
		if self.livePortrait and not lowFX then
			local made, live = pcall(self.livePortrait, card, result.heroId, portraitProperties)
			if made and live then
				if Motion.Prepare(live) then performer = live end
			end
		end
		if not performer then pcall(self.portrait, card, result.heroId, portraitProperties) end
	end
	local nameLabel = UI.label(card, self:_t(hero.name), { Name = "RevealName", Position = UDim2.fromOffset(10, 262), Size = UDim2.new(1, -20, 0, 38), Font = Enum.Font.FredokaOne, TextSize = 28, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, TextScaled = true, ZIndex = 91 })
	UI.outline(nameLabel, 3)
	local cardsPart = (result.cards or 0) > 0 and ("+" .. tostring(result.cards)) or nil
	local statusText = result.duplicate
		and self:_t({ pt = (cardsPart and (cardsPart .. (result.cards == 1 and " CARTA  •  " or " CARTAS  •  ")) or "") .. (result.starGained and ("+1 ★ (" .. tostring(result.stars or 1) .. "/5)  •  ") or "") .. "+" .. tostring(result.refundGold or 0) .. " Ouro",
			en = (cardsPart and (cardsPart .. (result.cards == 1 and " CARD  •  " or " CARDS  •  ")) or "") .. (result.starGained and ("+1 ★ (" .. tostring(result.stars or 1) .. "/5)  •  ") or "") .. "+" .. tostring(result.refundGold or 0) .. " Gold" })
		or self:_t({ pt = "NOVO HERÓI!", en = "NEW HERO!" })
	if result.shiny then statusText = self:_t({ pt = "◆ BRILHANTE!  ", en = "◆ SHINY!  " }) .. statusText end
	local status = UI.label(card, statusText, { Name = "RevealStatus", Position = UDim2.fromOffset(10, 302), Size = UDim2.new(1, -20, 0, 48), Font = Enum.Font.FredokaOne, TextSize = result.duplicate and 14 or 26, TextWrapped = true, TextColor3 = result.duplicate and CHEST_GOLD or Color3.fromRGB(150, 255, 120), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 91 })
	UI.outline(status, 2.5)
	if result.baseId then status.Text = result.duplicate and ("+" .. tostring(result.refundGold or 0) .. self:_t({ pt = " Ouro • base repetida", en = " Gold • duplicate base" })) or self:_t({ pt = "NOVA BASE!", en = "NEW BASE!" }) end
	local statusScale = UI.create("UIScale", { Scale = 1 }, status)

	local continueButton = UI.button(root, self:_t({ pt = "INCRÍVEL!", en = "AWESOME!" }), function() self:_closeReveal() end, {
		Name = "RevealContinue", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(260, 60),
		BackgroundColor3 = Color3.fromRGB(88, 224, 79), TextSize = 24, Visible = false, ZIndex = 95,
	})
	local flash = UI.frame(root, { Name = "RevealFlash", Size = UDim2.fromScale(1, 1), BackgroundColor3 = WHITE, BackgroundTransparency = 1, ZIndex = 94, Active = false })

	-- Sparkles thrown out of the chest when it opens.
	local sparkles = {}
	local function burstSparkles(count, tint)
		for index = 1, count do
			local angle = (index / count) * math.pi * 2 + self.random:NextNumber(-0.2, 0.2)
			local s = UI.label(stage, "✦", { Name = "RevealSparkle", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(34, 34), TextSize = self.random:NextInteger(18, 34), TextColor3 = index % 3 == 0 and WHITE or tint, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 93 })
			table.insert(sparkles, { label = s, angle = angle, speed = self.random:NextNumber(150, 260) })
		end
	end

	local lastTier, opened, carded = 0, false, false
	if performer then pcall(Motion.Perform, performer, 0, "rest") end
	self:_cue("chest", 0.05)
	self.reveal = { root = root, finalAt = finalAt, onClosed = onClosed, result = result }
	self.reveal.anim = self:_add({ duration = math.huge, update = function(t, dt)
		if not root.Parent then return end
		root.BackgroundTransparency = lerp(1, 0.12, clamp01(t / 0.3))
		if not lowFX then rays.Rotation = t * (opened and 40 or 14) end
		if t < openAt then
			-- 1. The chest drops in and lands with a bounce.
			local drop = backOut(t / math.max(intro, 0.01))
			local rig = CFrame.new(0, 8 * (1 - drop), 0)
			-- 2. It charges, climbing one rarity colour at a time; every step
			-- it hops, and it shakes harder the rarer the prize.
			local charging = t >= intro
			local tier = lowFX and tierIndex or (charging and math.min(tierIndex, math.floor((t - intro) / math.max(tierTime, 0.001)) + 1) or 1)
			if charging and tier ~= lastTier then
				lastTier = tier
				local tint = UI.color(Catalog.Rarities[tiers[tier]].color)
				glow.BackgroundColor3 = tint
				treasure.Color = tint
				for _, bar in ipairs(rayBars) do bar.BackgroundColor3 = tint:Lerp(WHITE, 0.4) end
				tierLabel.TextColor3 = tint:Lerp(WHITE, 0.2)
				tierLabel.Text = Catalog.Upper(self:_t(Catalog.Rarities[tiers[tier]].name)) .. string.rep("!", tier - 1)
				if not lowFX then self:_cue(tier >= 4 and "levelUp" or "collect", 0.05) end
			end
			if charging and not lowFX then
				local since = (t - intro) % math.max(tierTime, 0.001)
				local hop = math.max(0, math.sin(math.min(since / 0.22, 1) * math.pi)) * (0.35 + lastTier * 0.12)
				local amplitude = 0.04 + lastTier * 0.035
				rig = CFrame.new(0, hop, 0) * CFrame.Angles(0, math.sin(t * 38) * amplitude, math.sin(t * 47) * amplitude * 0.6)
				-- The lid rattles, letting light out.
				pose(rig, math.max(0, math.sin(t * 29)) * (0.05 + lastTier * 0.03))
			else
				pose(rig, 0)
			end
			local pulse = lowFX and 0 or math.sin(t * 14) * (8 + lastTier * 5)
			glow.Size = UDim2.fromOffset(200 + lastTier * 22 + pulse, 200 + lastTier * 22 + pulse)
		else
			-- 3. It bursts open.
			if not opened then
				opened = true
				glow.BackgroundColor3 = finalTint
				treasure.Color = finalTint
				for _, bar in ipairs(rayBars) do bar.BackgroundColor3 = finalTint:Lerp(WHITE, 0.3); bar.BackgroundTransparency = 0.7 end
				tierLabel.Text = ""
				self:_cue("victory", 0.05)
				self:Confetti(CONFETTI_BY_TIER[tierIndex] or 10, 0.4)
				if not lowFX then burstSparkles(10 + tierIndex * 4, finalTint:Lerp(WHITE, 0.3)) end
			end
			local since = t - openAt
			local burst = clamp01(since / 0.4)
			pose(CFrame.new(0, -0.6 * math.sin(math.min(since / 0.25, 1) * math.pi) * (lowFX and 0 or 1), 0), 1.95 * backOut(burst))
			chestGroup.Position = UDim2.new(0.5, 0, 0.56 + 0.22 * clamp01((since - 0.25) / 0.4), 0)
			if not lowFX then
				flash.BackgroundTransparency = lerp(0.15, 1, clamp01(since / 0.45))
				haloStroke.Transparency = lerp(0.1, 1, clamp01(since / 0.6))
				halo.Size = UDim2.fromOffset(120 + 520 * clamp01(since / 0.6), 120 + 520 * clamp01(since / 0.6))
			end
			glow.Size = UDim2.fromOffset(280 + 110 * burst, 280 + 110 * burst)
			glow.BackgroundTransparency = lerp(0.4, 0.65, burst)
			for _, s in ipairs(sparkles) do
				if s.label.Parent then
					local d = s.speed * clamp01(since / 0.9)
					s.label.Position = UDim2.new(0.5, math.cos(s.angle) * d, 0.52, math.sin(s.angle) * d - 40 * since)
					s.label.TextTransparency = clamp01((since - 0.5) / 0.5)
					s.label.Rotation = since * 200
				end
			end
		end
		-- 4. The prize rises out of the chest.
		if t >= cardAt then
			if not carded then
				carded = true
				card.Visible = true
				if tierIndex >= 4 then self:_cue("levelUp", 0.05) end
			end
			local rise = lowFX and 1 or backOut((t - cardAt) / 0.5)
			cardScale.Scale = rise
			card.Position = UDim2.fromScale(0.5, 0.5 + 0.18 * (1 - clamp01((t - cardAt) / 0.35)))
			card.Rotation = lowFX and 0 or math.sin(t * 2.2) * 2
			if performer then pcall(Motion.Perform, performer, t - cardAt, "reveal") end
		end
		if t >= finalAt then
			continueButton.Visible = true
			if not result.duplicate and not lowFX then statusScale.Scale = 1 + 0.08 * math.sin(t * 6) end
			local reveal = self.reveal
			if options and options.autoClose and reveal and not reveal.autoSet then
				reveal.autoSet = true
				reveal.anim.duration = finalAt + options.autoClose
				reveal.anim.done = function() if self.reveal == reveal then self:_closeReveal() end end
			end
		end
	end })
	return root
end

--==============================================================================
-- The reel: opening a chest like opening a case
--==============================================================================
local REEL_TILES, REEL_FINAL = 46, 38
local REEL_PITCH, REEL_TILE, REEL_WIDTH = 150, 138, 900
local REEL_INK = Color3.fromRGB(14, 18, 44)
local REEL_GOLD = Color3.fromRGB(255, 210, 63)

-- Picks a decoy for the strip, favouring what the chest really gives.
function Celebrate:_reelFiller(fillers)
	if type(fillers) == "table" and #fillers > 0 then
		local total = 0
		for _, entry in ipairs(fillers) do total += math.max(entry.chance or 0, 0.4) end
		local roll = self.random:NextNumber(0, total)
		for _, entry in ipairs(fillers) do
			roll -= math.max(entry.chance or 0, 0.4)
			if roll <= 0 then return entry.id, entry.rarity end
		end
		return fillers[1].id, fillers[1].rarity
	end
	local id = Catalog.HeroOrder[self.random:NextInteger(1, #Catalog.HeroOrder)]
	return id, Catalog.Heroes[id].rarity
end

-- One strip of prizes rushes past a marker and slows to a stop on the one the
-- server drew. Only the tiles near the window carry their artwork.
function Celebrate:_reelOne(result, chestId, fillers, position, total, onDone, flow)
	local UI = self.UI
	local lowFX = self.lowFX()
	local chest = Catalog.Chests[chestId or "rare"] or Catalog.Chests.rare
	local prizeRarity = Catalog.Rarities[result.rarity] or Catalog.Rarities.common
	local prizeTier = table.find(Catalog.RarityOrder, prizeRarity.id) or 1
	local root = UI.frame(self.root, { Name = "ChestReel", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 30), BackgroundTransparency = 0.08, ZIndex = 80, Active = true })
	UI.button(root, "", function() self:SkipReveal() end, { Name = "RevealSkip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 81, AutoButtonColor = false })
	local stage = UI.frame(root, { Name = "ReelStage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(REEL_WIDTH, 380), BackgroundTransparency = 1, ZIndex = 82 })
	local screen = UI.toLogical(self.root.AbsoluteSize)
	UI.create("UIScale", { Scale = math.clamp(math.min(screen.X / 960, screen.Y / 520), 0.5, 1.3) }, stage)
	local title = self:_t(chest.name) .. (total > 1 and ("   " .. position .. "/" .. total) or "")
	local titleLabel = UI.label(stage, Catalog.Upper(title), { Name = "ReelTitle", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 52), Font = Enum.Font.FredokaOne, TextSize = 36, TextColor3 = REEL_GOLD, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 84 })
	UI.outline(titleLabel, 3)
	local window = UI.frame(stage, { Name = "ReelWindow", Position = UDim2.fromOffset(0, 72), Size = UDim2.fromOffset(REEL_WIDTH, 196), BackgroundColor3 = REEL_INK, ClipsDescendants = true, ZIndex = 83 })
	UI.corner(window, 14)
	UI.stroke(window, REEL_GOLD, 3)
	local track = UI.frame(window, { Name = "ReelTrack", Position = UDim2.fromOffset(0, 29), Size = UDim2.fromOffset(REEL_PITCH * REEL_TILES, REEL_TILE), BackgroundTransparency = 1, ZIndex = 84 })
	-- The tiles: the prize at REEL_FINAL, decoys everywhere else.
	local tiles = {}
	for index = 1, REEL_TILES do
		local id, rarityId
		if index == REEL_FINAL then
			id, rarityId = result.baseId or result.heroId, result.rarity
		else
			id, rarityId = self:_reelFiller(fillers)
		end
		local def = Catalog.Bases[id] or Catalog.Heroes[id]
		local rarity = Catalog.Rarities[rarityId] or Catalog.Rarities.common
		local tint = UI.color(rarity.color)
		local frame = UI.frame(track, { Name = "ReelTile", Position = UDim2.fromOffset((index - 1) * REEL_PITCH + (REEL_PITCH - REEL_TILE) / 2, 0), Size = UDim2.fromOffset(REEL_TILE, REEL_TILE), BackgroundColor3 = tint:Lerp(REEL_INK, 0.62), ZIndex = 85 })
		UI.corner(frame, 12)
		UI.create("UIGradient", { Color = ColorSequence.new(tint:Lerp(WHITE, 0.1), tint:Lerp(BLACK, 0.45)), Rotation = 90 }, frame)
		UI.frame(frame, { Name = "RarityBar", AnchorPoint = Vector2.new(0, 1), Position = UDim2.fromScale(0, 1), Size = UDim2.new(1, 0, 0, 8), BackgroundColor3 = tint, ZIndex = 87 })
		local nameText = UI.label(frame, self:_t(def.name), { Name = "TileName", Position = UDim2.new(0, 4, 1, -44), Size = UDim2.new(1, -8, 0, 34), Font = Enum.Font.FredokaOne, TextSize = 15, TextWrapped = true, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 88 })
		UI.outline(nameText, 1.5)
		tiles[index] = { frame = frame, id = id, isBase = Catalog.Bases[id] ~= nil, def = def, art = nil }
	end
	local function ensureArt(index, wanted)
		local tile = tiles[index]
		if wanted and not tile.art then
			if tile.isBase then
				tile.art = UI.basePortrait(tile.frame, tile.def, { Name = "TileArt", Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 1, -54), ZIndex = 86 })
			elseif self.portrait then
				local made, art = pcall(self.portrait, tile.frame, tile.id, { Name = "TileArt", Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 1, -54), BackgroundTransparency = 1, ZIndex = 86 })
				if made then tile.art = art or tile.frame:FindFirstChild("TileArt") end
			end
		elseif not wanted and tile.art then
			if typeof(tile.art) == "Instance" then tile.art:Destroy() end
			tile.art = nil
		end
	end
	-- The marker.
	local marker = UI.frame(stage, { Name = "ReelMarker", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(REEL_WIDTH / 2, 62), Size = UDim2.fromOffset(5, 216), BackgroundColor3 = REEL_GOLD, ZIndex = 90 })
	for _, top in ipairs({ true, false }) do
		UI.frame(marker, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, top and 0 or 1, 0), Size = UDim2.fromOffset(26, 26), Rotation = 45, BackgroundColor3 = REEL_GOLD, ZIndex = 90 })
	end
	for _, left in ipairs({ true, false }) do
		local fade = UI.frame(window, { Name = "ReelFade", AnchorPoint = Vector2.new(left and 0 or 1, 0), Position = UDim2.fromScale(left and 0 or 1, 0), Size = UDim2.new(0, 160, 1, 0), BackgroundColor3 = Color3.fromRGB(8, 10, 30), ZIndex = 89 })
		UI.create("UIGradient", { Transparency = NumberSequence.new(left and 0 or 1, left and 1 or 0), Rotation = 0 }, fade)
	end
	local hint = UI.label(stage, self:_t({ pt = "TOQUE PARA PULAR", en = "TAP TO SKIP" }), { Name = "ReelHint", Position = UDim2.fromOffset(0, 290), Size = UDim2.new(1, 0, 0, 30), TextSize = 18, Font = UI.Fonts.bold, TextColor3 = Color3.fromRGB(206, 218, 255), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 84 })
	local nameLabel = UI.label(stage, "", { Name = "ReelPrize", Position = UDim2.fromOffset(0, 286), Size = UDim2.new(1, 0, 0, 52), Font = Enum.Font.FredokaOne, TextSize = 38, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 84 })
	UI.outline(nameLabel, 3)
	if flow and total > 1 then
		UI.button(root, self:_t({ pt = "PULAR TUDO", en = "SKIP ALL" }), function() flow.skipAll() end, { Name = "ReelSkipAll", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = UDim2.fromOffset(180, 52), BackgroundColor3 = Color3.fromRGB(255, 77, 94), TextSize = 18, ZIndex = 95 })
	end

	-- Where the strip stops: the prize's tile under the marker, a little off
	-- centre like a real case, never off the tile.
	local jitter = self.random:NextNumber(-0.28, 0.28) * REEL_TILE
	local distance = (REEL_FINAL - 1) * REEL_PITCH + REEL_PITCH / 2 + jitter - REEL_WIDTH / 2
	local duration = lowFX and 0.9 or (position == 1 and 6 or 3.6)
	local hold = lowFX and 0.4 or 1.0
	local landed, lastTile = false, 0
	local reveal = { root = root, finalAt = duration, onClosed = onDone, result = result }
	self.reveal = reveal
	reveal.anim = self:_add({ duration = duration + hold, update = function(t)
		if not root.Parent then return end
		local u = clamp01(t / duration)
		local travelled = distance * (1 - (1 - u) ^ 3.6)
		track.Position = UDim2.fromOffset(-travelled, 29)
		local crossing = math.floor((travelled + REEL_WIDTH / 2) / REEL_PITCH)
		if crossing ~= lastTile then
			lastTile = crossing
			if u < 0.97 then self:_cue("collect", 0.07) end
		end
		for index = 1, REEL_TILES do
			local x = (index - 1) * REEL_PITCH - travelled
			ensureArt(index, x > -REEL_PITCH * 1.5 and x < REEL_WIDTH + REEL_PITCH * 0.5)
		end
		hint.Visible = u < 1
		if u >= 1 and not landed then
			landed = true
			local win = tiles[REEL_FINAL]
			UI.stroke(win.frame, WHITE, 5)
			local tint = UI.color(prizeRarity.color)
			nameLabel.Text = Catalog.Upper(self:_t(win.def.name))
			nameLabel.TextColor3 = tint:Lerp(WHITE, 0.25)
			self:_cue(prizeTier >= 4 and "levelUp" or "chest", 0.05)
			self:Confetti(math.floor((CONFETTI_BY_TIER[prizeTier] or 8) / 2), 0.4)
		end
	end, done = function() if self.reveal == reveal then self:_closeReveal() end end })
	-- A second tap, once the strip has stopped, goes straight on.
	reveal.advance = function() reveal.anim.start = self.clock() - reveal.anim.duration end
	return root
end

-- Several chests, one after the other: reel, prize card, next reel. The last
-- screen sums them up. `options.fillers` are the chest's possible prizes
-- ({ id, rarity, chance }); `options.onClosed` runs when it is all over.
function Celebrate:Reel(results, chestId, options)
	options = options or {}
	if type(results) ~= "table" or #results == 0 then return end
	if self.reveal then self.reveal.onClosed = nil; self:_closeReveal() end
	local total = #results
	local flow = { stopped = false }
	local function finish()
		if flow.stopped then return end
		flow.stopped = true
		if total > 1 then
			self:_summary(results, options.onClosed)
		elseif options.onClosed then
			pcall(options.onClosed, results)
		end
	end
	flow.skipAll = function()
		if self.reveal then self.reveal.onClosed = nil; self:_closeReveal() end
		finish()
	end
	local function step(index)
		if flow.stopped then return end
		if index > total then finish() return end
		self:_reelOne(results[index], chestId, options.fillers, index, total, function()
			if flow.stopped then return end
			self:Chest(results[index], chestId, function() step(index + 1) end, { quick = true, autoClose = total > 1 and 1.3 or nil })
			if total > 1 and self.reveal then
				self.UI.button(self.reveal.root, self:_t({ pt = "PULAR TUDO", en = "SKIP ALL" }), function() flow.skipAll() end, { Name = "ReelSkipAll", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -18, 0, 18), Size = UDim2.fromOffset(180, 52), BackgroundColor3 = Color3.fromRGB(255, 77, 94), TextSize = 18, ZIndex = 96 })
			end
		end, flow)
	end
	step(1)
end

-- What a run of chests gave, at a glance: every prize with its rarity, which
-- were new, and the cards and Gold the repeats paid.
function Celebrate:_summary(results, onClosed)
	local UI = self.UI
	local root = UI.frame(self.root, { Name = "ChestSummary", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 30), BackgroundTransparency = 0.08, ZIndex = 80, Active = true })
	local screen = UI.toLogical(self.root.AbsoluteSize)
	local panelWidth = math.min(940, math.max(320, screen.X - 24))
	local panel = UI.frame(root, { Name = "SummaryPanel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromOffset(panelWidth, math.min(560, math.max(300, screen.Y - 24))), BackgroundTransparency = 1, ZIndex = 82 })
	local fresh, cards, gold = 0, 0, 0
	for _, r in ipairs(results) do
		if not r.duplicate then fresh += 1 end
		cards += r.cards or 0
		gold += r.refundGold or 0
	end
	local titleLabel = UI.label(panel, self:_t({ pt = "RESULTADO", en = "RESULTS" }), { Name = "SummaryTitle", Size = UDim2.new(1, 0, 0, 48), Font = Enum.Font.FredokaOne, TextSize = 38, TextColor3 = REEL_GOLD, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 83 })
	UI.outline(titleLabel, 3)
	UI.label(panel, self:_t({ pt = tostring(fresh) .. " novos  •  +" .. tostring(cards) .. " cartas  •  +" .. tostring(gold) .. " Ouro", en = tostring(fresh) .. " new  •  +" .. tostring(cards) .. " cards  •  +" .. tostring(gold) .. " Gold" }), { Name = "SummaryTotals", Position = UDim2.fromOffset(0, 50), Size = UDim2.new(1, 0, 0, 34), TextSize = 22, Font = UI.Fonts.bold, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 83 })
	local grid = UI.scroll(panel, { Name = "SummaryGrid", Position = UDim2.fromOffset(0, 92), Size = UDim2.new(1, 0, 1, -170), ZIndex = 83 })
	local columns = math.max(2, math.floor(panelWidth / 150))
	grid.CanvasSize = UDim2.fromOffset(0, math.ceil(#results / columns) * 158)
	for index, r in ipairs(results) do
		local def = Catalog.Bases[r.baseId] or Catalog.Heroes[r.heroId]
		local rarity = Catalog.Rarities[r.rarity] or Catalog.Rarities.common
		local tint = UI.color(rarity.color)
		local col, row = (index - 1) % columns, math.floor((index - 1) / columns)
		local tile = UI.frame(grid, { Name = "SummaryTile", Position = UDim2.fromOffset(col * 150, row * 158), Size = UDim2.fromOffset(142, 150), BackgroundColor3 = tint:Lerp(REEL_INK, 0.6), ZIndex = 84 })
		UI.corner(tile, 12)
		UI.stroke(tile, tint, 3)
		if r.baseId then
			UI.basePortrait(tile, def, { Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 1, -62), ZIndex = 85 })
		elseif self.portrait then
			pcall(self.portrait, tile, r.heroId, { Position = UDim2.fromOffset(8, 6), Size = UDim2.new(1, -16, 1, -62), BackgroundTransparency = 1, ZIndex = 85 })
		end
		local nameText = UI.label(tile, self:_t(def.name), { Position = UDim2.new(0, 4, 1, -54), Size = UDim2.new(1, -8, 0, 24), Font = Enum.Font.FredokaOne, TextSize = 14, TextColor3 = WHITE, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 86 })
		UI.outline(nameText, 1.5)
		local note
		if not r.duplicate then
			note = self:_t({ pt = "NOVO!", en = "NEW!" })
		elseif (r.cards or 0) > 0 then
			note = "+" .. tostring(r.cards) .. self:_t({ pt = " CARTA", en = " CARD" })
		else
			note = "+" .. tostring(r.refundGold or 0)
		end
		UI.label(tile, note, { Position = UDim2.new(0, 4, 1, -28), Size = UDim2.new(1, -8, 0, 22), Font = UI.Fonts.bold, TextSize = 15, TextColor3 = r.duplicate and REEL_GOLD or Color3.fromRGB(150, 255, 120), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 86 })
	end
	UI.button(root, self:_t({ pt = "INCRÍVEL!", en = "AWESOME!" }), function() self:_closeReveal() end, { Name = "RevealContinue", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -18), Size = UDim2.fromOffset(280, 64), BackgroundColor3 = Color3.fromRGB(88, 224, 79), TextSize = 26, ZIndex = 95 })
	self.reveal = { root = root, finalAt = 0, onClosed = onClosed, result = results }
	self:Confetti(30, 0.3)
end


-- A tap during the build-up jumps straight to the revealed hero.
function Celebrate:SkipReveal()
	local reveal = self.reveal
	if not reveal or not reveal.anim then return end
	local elapsed = self.clock() - reveal.anim.start
	if elapsed < reveal.finalAt then
		reveal.anim.start = self.clock() - reveal.finalAt
		reveal.anim.update(reveal.finalAt, 0)
	elseif reveal.advance then
		reveal.advance()
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
	if self.reveal then self.reveal.onClosed = nil; self:_closeReveal() end
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
