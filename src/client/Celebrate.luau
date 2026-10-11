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
	self.bannerY = options.bannerY
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

function Celebrate:_summon(action, rarity)
	if self.audio then pcall(self.audio.Summon, self.audio, action, rarity) end
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
	-- The host may ask for a lower line (a boss bar and its notices hold the top).
	local y = options.y or (self.bannerY and self.bannerY()) or (big and 0.3 or 0.24)
	local banner = self.UI.frame(self.root, {
		Name = "CelebrationBanner", AnchorPoint = Vector2.new(0.5, 0.5), ZIndex = 90,
		Position = UDim2.new(0.5, 0, y, 0), Size = UDim2.new(0.86, 0, 0, big and 92 or 62),
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
-- Rarity accents belong to the receipt; the reel owns the opening.
local CHEST_GOLD = Color3.fromRGB(255, 200, 70)

-- result: the server's committed OpenChest result {heroId, rarity, duplicate,
-- refundGold, refundMastery}. chestId picks the chest's own colour.
-- options.quick is a receipt only: no second chest, charge, flash or sound
-- after the reel. options.autoClose closes the card by itself that many seconds
-- after it is shown, which a run of several chests uses to flow on.
function Celebrate:Chest(result, chestId, onClosed, options)
	if type(result) ~= "table" or not (Catalog.Heroes[result.heroId] or Catalog.Bases[result.baseId]) then return end
	if self.reveal then self.reveal.onClosed=nil; self:_closeReveal() end
	options=options or {}
	local UI=self.UI
	local lowFX=self.lowFX()
	local def=Catalog.Bases[result.baseId] or Catalog.Heroes[result.heroId]
	local rarity=Catalog.Rarities[result.rarity] or Catalog.Rarities[def.rarity]
	local tier=table.find(Catalog.RarityOrder,rarity.id) or 1
	local tint=UI.color(rarity.color)
	local screen=UI.toLogical(self.root.AbsoluteSize)
	local portrait=screen.X<600
	local w,h=portrait and 500 or 900,portrait and 620 or 440
	local root=UI.frame(self.root,{Name="ChestReveal",Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.fromRGB(5,12,26),BackgroundTransparency=0.08,Active=true,ZIndex=80})
	UI.button(root,"",function() self:SkipReveal() end,{Name="RevealSkip",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=81,AutoButtonColor=false})
	local stage=UI.frame(root,{Name="RevealStage",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.46),Size=UDim2.fromOffset(w,h),BackgroundTransparency=1,ZIndex=82})
	UI.create("UIScale",{Scale=math.min(screen.X/(w+40),screen.Y/(h+120),1.35)},stage)
	local card=UI.frame(stage,{Name="RevealHeroCard",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Visible=true,ZIndex=83})
	-- Compatibility marker: there is one reveal, never another chest or flash
	-- after the reel has already landed on a server-committed reward.
	UI.frame(stage,{Name="RevealChest",Visible=false,BackgroundTransparency=1})
	UI.frame(root,{Name="RevealFlash",Visible=false,BackgroundTransparency=1})
	local cx,cy=portrait and 250 or 230,portrait and 158 or 215
	local radius=portrait and 260 or 350
	local halo=UI.frame(card,{Name="RecruitPortal",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(cx,cy),Size=UDim2.fromOffset(radius,radius),BackgroundColor3=tint,BackgroundTransparency=0.93,ZIndex=84})
	UI.corner(halo,200)
	local haloStroke=UI.stroke(halo,tint,3)
	local orbit=UI.frame(card,{Name="RecruitOrbit",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(cx,cy),Size=UDim2.fromOffset(radius*0.82,radius*0.82),BackgroundTransparency=1,Rotation=45,ZIndex=84})
	UI.angular(orbit,tint,{cut=32})
	local rays={}
	for i=1,12 do
		local angle=i*math.pi/6
		local ray=UI.frame(card,{Name="RecruitParticle",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset(cx+math.cos(angle)*radius/2,cy+math.sin(angle)*radius/2),Size=UDim2.fromOffset(5,i%3==0 and 22 or 10),Rotation=i*30,BackgroundColor3=tint,BackgroundTransparency=0.25,ZIndex=85,Visible=not lowFX})
		table.insert(rays,{frame=ray,angle=angle})
	end
	local px,py,pw,ph=portrait and 45 or -5,portrait and -16 or -20,portrait and 410 or 470,portrait and 340 or 460
	local properties={Name="RevealPortrait",Position=UDim2.fromOffset(px,py),Size=UDim2.fromOffset(pw,ph),BackgroundTransparency=1,NoBackdrop=true,FullFigure=true,ZIndex=88}
	local performer
	if result.baseId then
		local baseProperties=table.clone(properties)
		baseProperties.FullFigure=nil; baseProperties.NoBackdrop=nil
		UI.basePortrait(card,def,baseProperties)
	elseif self.livePortrait then
		local ok,live=pcall(self.livePortrait,card,result.heroId,properties)
		if ok and live and Motion.Prepare(live) then performer=live end
	end
	if not result.baseId and not performer and self.portrait then pcall(self.portrait,card,result.heroId,properties) end
	local x,y,dw=portrait and 24 or 470,portrait and 324 or 48,portrait and 452 or 414
	local dossier=UI.frame(card,{Name="RecruitDossier",Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(dw,portrait and 282 or 344),BackgroundColor3=Color3.fromRGB(10,22,40),BackgroundTransparency=0.05,ZIndex=89})
	UI.angular(dossier,tint,{cut=16})
	local function words(name,text,yy,height,size,color)
		local label=UI.label(dossier,text,{Name=name,Position=UDim2.fromOffset(22,yy),Size=UDim2.fromOffset(dw-44,height),Font=UI.Fonts.display,TextSize=size,TextColor3=color or WHITE,TextWrapped=true,ZIndex=90})
		UI.fit(label,14)
		return label
	end
	words("RecruitKicker",self:_t(result.baseId and {pt="ARSENAL / NOVA DESCOBERTA",en="ARSENAL / NEW DISCOVERY"} or {pt="MULTIVERSO / RECRUTAMENTO",en="MULTIVERSE / RECRUITMENT"}),18,26,14,Color3.fromRGB(180,201,219))
	local rarityLabel=words("RevealRarity",Catalog.Upper(self:_t(rarity.name)).."!",52,36,25,tint)
	UI.oneLine(rarityLabel,16)
	words("RevealName",self:_t(def.name),portrait and 94 or 104,portrait and 54 or 80,portrait and 32 or 38)
	UI.frame(dossier,{Name="RecruitDivider",Position=UDim2.fromOffset(22,portrait and 156 or 196),Size=UDim2.fromOffset(dw-44,2),BackgroundColor3=tint,BackgroundTransparency=0.35,ZIndex=90})
	local cards=result.cards or 0
	local statusText
	if result.duplicate then
		statusText=(cards>0 and ("+"..cards..self:_t(cards==1 and {pt=" CARTA  •  ",en=" CARD  •  "} or {pt=" CARTAS  •  ",en=" CARDS  •  "})) or "")
			..(result.starGained and ("+1 ★ ("..tostring(result.stars or 1).."/5)  •  ") or "")
			.."+"..tostring(result.refundGold or 0)..self:_t({pt=" Ouro",en=" Gold"})
	else
		statusText=self:_t(result.baseId and {pt="NOVA BASE!",en="NEW BASE!"} or {pt="NOVO HERÓI!",en="NEW HERO!"})
	end
	if result.shiny then statusText=self:_t({pt="BRILHANTE!  ",en="SHINY!  "})..statusText end
	words("RevealStatus",statusText,portrait and 170 or 212,56,result.duplicate and 20 or 27,result.duplicate and CHEST_GOLD or tint:Lerp(WHITE,0.35))
	words("RecruitSaved",self:_t({pt="Adicionado à sua coleção",en="Added to your collection"}),portrait and 238 or 290,26,16,Color3.fromRGB(180,201,219))
	local continueButton=UI.button(root,self:_t({pt="CONTINUAR",en="CONTINUE"}),function() self:_closeReveal() end,{
		Name="RevealContinue",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-18),Size=UDim2.fromOffset(math.min(screen.X-32,300),52),BackgroundColor3=tint,TextSize=22,Visible=true,ZIndex=95})
	-- The reel owns the impact sound; direct grants own it here. A receipt
	-- never plays a second reward fanfare, but its hero still performs.
	if not options.quick then self:_summon("reward",rarity.id) end
	local finalAt=0
	local reveal={root=root,finalAt=finalAt,onClosed=onClosed,result=result}
	self.reveal=reveal
	local nextPose=0
	reveal.anim=self:_add({duration=options.autoClose or math.huge,update=function(t)
		if not root.Parent then return end
		local enter=lowFX and 1 or backOut(t/0.55)
		dossier.Position=UDim2.fromOffset(x+(1-enter)*45,y)
		halo.Size=UDim2.fromOffset(radius*(0.88+0.12*math.min(t/0.5,1)),radius*(0.88+0.12*math.min(t/0.5,1)))
		haloStroke.Transparency=lowFX and 0.25 or 0.2+0.18*math.sin(t*1.8)^2
		if not lowFX then
			orbit.Rotation=45+t*4
			for _,particle in ipairs(rays) do
				local distance=radius*(0.50+0.12*math.min(t,1))
				particle.frame.Position=UDim2.fromOffset(cx+math.cos(particle.angle+t*0.12)*distance,cy+math.sin(particle.angle+t*0.12)*distance)
			end
		end
		-- A capped pose update costs the same for common and mythic heroes.
		if performer and t>=nextPose then
			nextPose=t+1/30
			pcall(Motion.Perform,performer,t,lowFX and "rest" or "arrival")
		end
	end,done=function() if self.reveal==reveal then self:_closeReveal() end end})
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
	if not fillers then
		-- Reward chests use the same eligible collection as shop chests. These
		-- are visual decoys only; the server's committed result stays final.
		fillers = {}
		local catalog = chest.kind == "base" and Catalog.Bases or Catalog.Heroes
		for id, def in pairs(catalog) do
			if (chest.odds[def.rarity] or 0) > 0 then
				table.insert(fillers, {id=id,rarity=def.rarity,chance=chest.odds[def.rarity]})
			end
		end
	end
	local prizeRarity = Catalog.Rarities[result.rarity] or Catalog.Rarities.common
	local prizeTier = table.find(Catalog.RarityOrder, prizeRarity.id) or 1
	local root = UI.frame(self.root, { Name = "ChestReel", Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(8, 10, 30), BackgroundTransparency = 0.5, ZIndex = 80, Active = true })
	UI.button(root, "", function() self:SkipReveal() end, { Name = "RevealSkip", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 81, AutoButtonColor = false })
	local stage = UI.frame(root, { Name = "ReelStage", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.46), Size = UDim2.fromOffset(REEL_WIDTH, 380), BackgroundTransparency = 1, ZIndex = 82 })
	local screen = UI.toLogical(self.root.AbsoluteSize)
	UI.create("UIScale", { Scale = math.clamp(math.min(screen.X / 960, screen.Y / 520), 0.5, 1.3) }, stage)
	local title = self:_t(chest.name) .. (total > 1 and ("   " .. position .. "/" .. total) or "")
	local titleLabel = UI.label(stage, Catalog.Upper(title), { Name = "ReelTitle", Position = UDim2.fromOffset(0, 0), Size = UDim2.new(1, 0, 0, 52), Font = Enum.Font.FredokaOne, TextSize = 36, TextColor3 = REEL_GOLD, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 84 })
	UI.outline(titleLabel, 3)
	local titlePlate=UI.frame(stage,{Name="ReelTitlePlate",Position=UDim2.fromOffset(100,0),Size=UDim2.new(1,-200,0,52),BackgroundColor3=UI.Colors.background,ZIndex=83})
	UI.angular(titlePlate,REEL_GOLD,{cut=12})
	UI.oneLine(titleLabel,22)
	local window = UI.frame(stage, { Name = "ReelWindow", Position = UDim2.fromOffset(0, 72), Size = UDim2.fromOffset(REEL_WIDTH, 196), BackgroundColor3 = REEL_INK, ClipsDescendants = true, ZIndex = 83 })
	UI.corner(window, 14)
	UI.stroke(window, REEL_GOLD, 3)
	UI.angular(window, REEL_GOLD, {cut=14})
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
		UI.cardSkin(frame, tint)
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
	local hold = lowFX and 0.15 or 0.45
	local landed, lastTile = false, 0
	self:_summon("start")
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
			-- A skipped/slow frame never queues the missed ticks. The final
			-- slow crossings stay audible; landing has one rarity signature.
			if t > 0 and u < 1 then self:_summon("tick") end
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
			self:_summon("reward", prizeRarity.id)
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
		local source = results[index].chestId or chestId
		self:_reelOne(results[index], source, options.fillers, index, total, function()
			if flow.stopped then return end
			self:Chest(results[index], source, function() step(index + 1) end, { quick = true, autoClose = total > 1 and 1.3 or nil })
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
	grid.CanvasSize = UDim2.fromOffset(0, math.ceil(#results / columns) * 158 + 12)
	for index, r in ipairs(results) do
		local def = Catalog.Bases[r.baseId] or Catalog.Heroes[r.heroId]
		local rarity = Catalog.Rarities[r.rarity] or Catalog.Rarities.common
		local tint = UI.color(rarity.color)
		local col, row = (index - 1) % columns, math.floor((index - 1) / columns)
		local tile = UI.frame(grid, { Name = "SummaryTile", Position = UDim2.fromOffset(col * 150 + 6, row * 158 + 6), Size = UDim2.fromOffset(138, 146), BackgroundColor3 = tint:Lerp(REEL_INK, 0.6), ZIndex = 84 })
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
	self:_summon("cancel")
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
