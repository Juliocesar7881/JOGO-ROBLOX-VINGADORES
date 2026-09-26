-- Authored procedural art: no unreviewed Toolbox models or external scripts.
local World = {}
World.__index = World

-- Mobile performance budget: almost everything built here is small set
-- dressing, and shadow-casting is the cheapest thing to cut before it ever
-- costs a gameplay rule. Callers opt individual landmark parts back in.
local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
	p.Anchored, p.TopSurface, p.BottomSurface = true, Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.CastShadow = false
	p.Parent = parent
	return p
end
local function rgb(value) return Color3.fromRGB(value[1], value[2], value[3]) end

-- Architectural kit: panel seams, brushed metal, porcelain and inset light.
-- Shapes and signage are authored here and render without uploaded assets.
local ART = {ink=Color3.fromRGB(22,38,62), pearl=Color3.fromRGB(206,218,222),
	steel=Color3.fromRGB(108,137,155), cyan=Color3.fromRGB(64,217,248), gold=Color3.fromRGB(255,193,72)}
local function artPart(parent,name,size,cf,tint,material)
	local p=part(parent,name,size,cf,tint,material)
	p.CanCollide,p.CanQuery,p.CanTouch=false,false,false
	return p
end
local function arc(parent,name,cf,radius,width,depth,tint,material,segments)
	segments=segments or 32
	for i=0,segments-1 do
		local angle=i*math.pi*2/segments
		artPart(parent,name,Vector3.new(2*radius*math.sin(math.pi/segments)+0.05,width,depth),
			cf*CFrame.Angles(0,0,angle)*CFrame.new(0,radius,0),tint,material)
	end
end
local function wallSign(parent,name,cf,size,title,subtitle,tint)
	local panel=artPart(parent,name,size,cf,ART.ink,Enum.Material.Metal)
	local gui=Instance.new("SurfaceGui")
	gui.Name,gui.Face,gui.CanvasSize="Artwork",Enum.NormalId.Front,Vector2.new(900,220)
	gui.LightInfluence,gui.Parent=0,panel
	local function text(value,y,h,color,fontSize)
		local t=Instance.new("TextLabel")
		t.Name=y==34 and "Title" or "Subtitle"
		t.BackgroundTransparency,t.Text,t.Font=1,value,Enum.Font.GothamBlack
		t.Position,t.Size=UDim2.new(0.04,0,0,y),UDim2.new(0.92,0,0,h)
		t.TextColor3,t.TextSize,t.Parent=color,fontSize,gui
	end
	text(title,34,90,tint,62)
	text(subtitle,133,46,Color3.fromRGB(184,205,220),24)
	local stripe=Instance.new("Frame")
	stripe.Size,stripe.Position=UDim2.new(0.22,0,0,5),UDim2.new(0.39,0,1,-18)
	stripe.BorderSizePixel,stripe.BackgroundColor3,stripe.Parent=0,tint,gui
	return panel
end
local function commas(value)
	local digits = tostring(math.floor(math.abs(value or 0)))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
	return (value or 0) < 0 and ("-" .. formatted) or formatted
end
local function label(parent, text, offset, color, size, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Size, gui.StudsOffset = "Label", UDim2.fromOffset(size or 230, 54), offset or Vector3.new(0, 5, 0)
	gui.AlwaysOnTop, gui.MaxDistance, gui.Parent = false, maxDistance or 170, parent
	local t = Instance.new("TextLabel")
	t.Size, t.BackgroundTransparency, t.Text = UDim2.fromScale(1, 1), 1, text
	t.Font, t.TextSize, t.TextColor3 = Enum.Font.GothamBold, 17, color or Color3.fromRGB(223, 235, 241)
	t.TextStrokeTransparency, t.TextWrapped, t.Parent = 0.45, true, gui
	return t
end

-- Particle emitters are used sparingly and only on singular landmarks —
-- enemy portals, the resistance core, the mode portals — never per enemy or
-- per tower, where the instance count would sink a phone. Texture is left at
-- the engine default on purpose: no third-party art enters this project.
local function emitter(parent, tint, rate, speed, size, lifetime, drift)
	local particles = Instance.new("ParticleEmitter")
	particles.Name = "Particles"
	particles.Color = ColorSequence.new(tint, tint:Lerp(Color3.new(1, 1, 1), 0.45))
	particles.Rate, particles.Speed = rate, NumberRange.new(speed * 0.5, speed)
	particles.Lifetime = NumberRange.new(lifetime * 0.6, lifetime)
	particles.Size = NumberSequence.new(size, size * 0.15)
	particles.Transparency = NumberSequence.new(0.25, 1)
	particles.LightEmission, particles.LightInfluence = 0.8, 0
	particles.Acceleration = drift or Vector3.new(0, 2.5, 0)
	particles.SpreadAngle = Vector2.new(22, 22)
	particles.Parent = parent
	return particles
end

-- One ProximityPrompt convention for every physical interaction in the lobby:
-- a small activation radius plus a defensive server-side distance re-check, so
-- a client cannot fire a prompt it is nowhere near.
local function interactable(anchor, objectLabel, callback, distance)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText, prompt.ObjectText = "Abrir / Open", objectLabel
	prompt.MaxActivationDistance, prompt.HoldDuration = 10, 0
	prompt.RequiresLineOfSight, prompt.Parent = false, anchor
	prompt.Triggered:Connect(function(player)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - anchor.Position).Magnitude <= (distance or 14) then callback(player) end
	end)
	return prompt
end

-- Shared authored silhouette for every hero: match towers and the lobby's
-- hero-gallery statues both call this, so a hero looks like the same
-- character everywhere instead of two unrelated blockouts.
local FIGURE_SCALE = { hulk = 1.35, groot = 1.55, rocket = 0.72, wasp = 0.9, silversurfer = 1.05 }
-- Sign text is shouted in capitals; string.upper does not know accents, so
-- World.new swaps in the catalog's accent-aware version.
local upper = string.upper

local function heroFigure(parent, heroId, hero, origin, scale)
	scale = scale or FIGURE_SCALE[heroId] or 1
	parent:SetAttribute("FigureScale", scale)
	-- The local -Z axis is the face of every figure, also used by portrait
	-- cameras. Posed limbs and all accessories share the same scale/origin.
	local V = Vector3.new
	-- Clean toy-like surfaces keep faces and costume colors readable at game scale.
	local metal, fabric = Enum.Material.SmoothPlastic, Enum.Material.SmoothPlastic
	local red, gold = Color3.fromRGB(183, 36, 49), Color3.fromRGB(227, 181, 78)
	local navy, ink = Color3.fromRGB(24, 53, 98), Color3.fromRGB(24, 28, 39)
	local silver, skin = Color3.fromRGB(184, 198, 212), Color3.fromRGB(232, 181, 147)
	local white, energy = Color3.fromRGB(233, 238, 243), Color3.fromRGB(137, 226, 255)
	local palette = {
		ironman = { red, gold, red, metal }, hawkeye = { Color3.fromRGB(75, 42, 106), ink, skin, fabric },
		spiderman = { red, navy, red, fabric }, widow = { ink, Color3.fromRGB(77, 90, 102), skin, fabric },
		captain = { navy, red, navy, fabric }, hulk = { Color3.fromRGB(96, 158, 72), Color3.fromRGB(82, 49, 109), Color3.fromRGB(96, 158, 72), Enum.Material.SmoothPlastic },
		panther = { ink, silver, ink, metal }, thor = { Color3.fromRGB(51, 60, 74), silver, skin, metal },
		antman = { red, silver, silver, metal }, vision = { Color3.fromRGB(45, 117, 100), gold, Color3.fromRGB(164, 55, 74), metal },
		wanda = { Color3.fromRGB(128, 24, 49), ink, skin, fabric }, strange = { navy, Color3.fromRGB(154, 34, 46), skin, fabric },
		falcon = { Color3.fromRGB(122, 28, 38), Color3.fromRGB(45, 45, 52), skin, fabric },
		bucky = { Color3.fromRGB(46, 52, 62), Color3.fromRGB(150, 158, 170), skin, fabric },
		wasp = { Color3.fromRGB(235, 188, 52), ink, skin, fabric },
		rocket = { Color3.fromRGB(150, 104, 72), Color3.fromRGB(196, 72, 52), Color3.fromRGB(170, 122, 84), fabric },
		daredevil = { Color3.fromRGB(148, 26, 34), ink, skin, fabric },
		shangchi = { Color3.fromRGB(190, 52, 38), gold, skin, fabric },
		warmachine = { Color3.fromRGB(102, 110, 122), ink, Color3.fromRGB(150, 158, 170), metal },
		starlord = { Color3.fromRGB(96, 40, 40), Color3.fromRGB(196, 62, 62), skin, fabric },
		groot = { Color3.fromRGB(112, 82, 54), Color3.fromRGB(88, 128, 62), Color3.fromRGB(128, 94, 62), Enum.Material.Wood },
		ghostrider = { ink, Color3.fromRGB(255, 128, 30), Color3.fromRGB(232, 228, 214), fabric },
		captainmarvel = { Color3.fromRGB(44, 78, 178), red, skin, fabric },
		silversurfer = { Color3.fromRGB(186, 200, 215), Color3.fromRGB(226, 236, 246), Color3.fromRGB(205, 218, 232), metal },
		wolverine={gold,navy,skin,fabric},cyclops={navy,gold,skin,fabric},
		storm={white,gold,Color3.fromRGB(140,91,65),fabric},jean={Color3.fromRGB(61,139,97),gold,skin,fabric},
		iceman={Color3.fromRGB(139,225,255),white,Color3.fromRGB(172,238,255),Enum.Material.Ice},
		gambit={Color3.fromRGB(138,80,62),Color3.fromRGB(230,106,184),skin,fabric},
		nightcrawler={Color3.fromRGB(156,53,65),ink,Color3.fromRGB(89,96,191),fabric},
		beast={Color3.fromRGB(73,123,194),navy,Color3.fromRGB(83,140,205),fabric},
		psylocke={Color3.fromRGB(96,63,170),Color3.fromRGB(211,95,176),skin,fabric},
		deadpool={red,ink,red,fabric},moonknight={white,Color3.fromRGB(195,198,202),white,fabric},
		nova={navy,gold,gold,metal},
	}
	local colors = palette[heroId] or { rgb(hero.color), ink, rgb(hero.color), fabric }
	local suit, trim, face, material = colors[1], colors[2], colors[3], colors[4]
	local bulky = heroId == "hulk" or heroId == "groot"
	local slim = heroId == "wanda" or heroId == "widow" or heroId == "wasp" or heroId == "silversurfer"
	local width = bulky and 1.32 or (slim and 0.82 or 1)
	local armPieces = {
		Shoulder=true, UpperArm=true, Elbow=true, Gauntlet=true, Hand=true,
		Repulsor=true, Shield=true, ShieldBand=true, ShieldStar=true,
		Bow=true, Bowstring=true, Arrow=true, ShockBaton=true, BatonCharge=true,
		Claw=true, HammerHandle=true, Mjolnir=true, HammerInset=true,
		ChaosSpell=true, SpellGlyph=true, MetalArm=true, MetalForearm=true,
		MetalHand=true, StarMark=true, RifleBarrel=true, BigGun=true, GunMuzzle=true,
		Billy=true, BillyTip=true, TenRing=true, Blaster=true, BlasterGlow=true, PhotonFist=true,
		AdamantiumClaw=true,ChargedCard=true,Staff=true,Blade=true,IceFist=true,FurryFist=true,
	}
	local function piece(name, size, position, tint, surface, rotation, shape)
		local made = part(parent, name, size * scale, origin * CFrame.new(position * scale) * (rotation or CFrame.new()), tint, surface or material)
		made.CanCollide = false
		made:SetAttribute("HeroGeometry", true)
		made:SetAttribute("HeroVisual", true)
		-- Authored joints keep weapons attached to the same arm during local
		-- firing poses. The platform and lower body remain planted.
		if armPieces[name] then
			local side = (name == "Arrow" or name == "Bowstring") and -1 or (position.X < 0 and -1 or 1)
			made:SetAttribute("PoseGroup", side < 0 and "LeftArm" or "RightArm")
			made:SetAttribute("PoseJoint", (origin * CFrame.new(V(side * 1.14 * width, 4.22, 0) * scale)).Position)
		elseif position.Y > 2.45 then made:SetAttribute("PoseGroup", "Body") end
		made.Shape = shape or Enum.PartType.Block
		return made
	end
	local function oval(name, size, position, tint, surface, rotation)
		local made=piece(name, size, position, tint, surface, rotation)
		-- PartType.Ball normalizes dimensions in the renderer: it turns long
		-- body pieces into disconnected beads. A mesh preserves this ellipsoid.
		local mesh=Instance.new("SpecialMesh")
		mesh.MeshType=Enum.MeshType.Sphere
		mesh.Parent=made
		return made
	end
	local function link(name, from, to, thickness, tint, surface)
		local length = (to - from).Magnitude
		return piece(name, V(thickness, thickness, length + thickness * 0.25), (from + to) / 2,
			tint, surface, CFrame.lookAt(V(), to - from))
	end
	local function disc(name, center, diameter, thickness, tint, surface)
		return piece(name, V(thickness, diameter, diameter), center, tint, surface,
			CFrame.Angles(0, math.pi / 2, 0), Enum.PartType.Cylinder)
	end
	local torso = piece("Suit", V(2.1 * width, 1.9, 1.25), V(0, 3.48, 0), suit)
	piece("Abdomen", V(1.72 * width, 1.1, 1.15), V(0, 2.67, 0), suit)
	piece("Belt", V(1.85 * width, 0.3, 1.28), V(0, 2.35, 0), bulky and trim or ink, metal)
	piece("Buckle", V(0.38, 0.34, 0.13), V(0, 2.35, -0.7), trim, metal)
	oval("Collar", V(1.18, 0.5, 1.02), V(0, 4.56, 0), suit)
	local head = oval("Mask", V(bulky and 1.6 or 1.45, 1.6, 1.38), V(0, 5.38, -0.05), face, Enum.Material.SmoothPlastic)
	local hands = {}
	for _, side in ipairs({ -1, 1 }) do
		local hip, knee, ankle = V(side * 0.57 * width, 2.12, 0), V(side * 0.69 * width, 1.21, -side * 0.07), V(side * 0.78 * width, 0.37, side * 0.13)
		local legColor = (heroId == "spiderman" or bulky) and trim or suit:Lerp(ink, 0.25)
		link("Thigh", hip, knee, bulky and 1.1 or 0.8, legColor)
		link("Shin", knee, ankle, bulky and 0.86 or 0.65, bulky and suit or trim)
		piece("Boot", V(bulky and 1.15 or 0.83, 0.54, 1.12), ankle + V(0, -0.1, -0.18), bulky and suit or (heroId == "spiderman" and red or trim), Enum.Material.SmoothPlastic)
		local shoulder = V(side * 1.14 * width, 4.22, 0)
		local elbow = V(side * 1.65 * width, 3.53, -0.15)
		local hand = V(side * 1.58 * width, 2.84, -0.49)
		if heroId == "ironman" and side == 1 then elbow, hand = V(1.72, 3.94, -0.43), V(1.76, 4.14, -1.3)
		elseif heroId == "hawkeye" then elbow, hand = side == -1 and V(-1.75, 4.1, -0.38) or V(1.45, 4.18, 0.14), side == -1 and V(-2.25, 4.08, -0.65) or V(0.45, 4.08, -0.87)
		elseif heroId == "spiderman" and side == 1 then elbow, hand = V(1.67, 3.82, -0.43), V(1.68, 4.12, -1.19)
		elseif heroId == "thor" and side == 1 then elbow, hand = V(1.75, 4.05, 0), V(2, 4.7, -0.2)
		elseif heroId == "wanda" or heroId == "strange" then elbow, hand = V(side * 1.56, 3.57, -0.08), V(side * 1.95, 4.14, -0.65)
		elseif bulky then elbow, hand = V(side * 2.05, 3.6, -0.14), V(side * 2.18, 2.63, -0.45)
		elseif heroId == "captain" and side == -1 then elbow, hand = V(-1.67, 3.69, -0.35), V(-1.7, 3.52, -1.1)
		end
		hands[side] = hand
		oval("Shoulder", V(bulky and 1.7 or 1.05, bulky and 1.48 or 0.94, bulky and 1.47 or 1.08), shoulder, suit)
		link("UpperArm", shoulder, elbow, bulky and 1.25 or 0.72, suit)
		oval("Elbow", V(0.6, 0.6, 0.6), elbow, suit)
		link("Gauntlet", elbow, hand, bulky and 1.12 or 0.76, (heroId == "spiderman" or bulky) and suit or trim)
		oval("Hand", V(bulky and 1.18 or 0.67, bulky and 1.06 or 0.67, bulky and 1.05 or 0.72), hand, bulky and suit or (heroId == "wanda" or heroId == "strange") and skin or suit)
	end
	-- Facial planes: a mask is a mask, exposed faces have brows and a nose.
	local exposed = heroId == "hawkeye" or heroId == "widow" or heroId == "thor" or heroId == "wanda" or heroId == "strange" or bulky
		or heroId == "falcon" or heroId == "bucky" or heroId == "shangchi" or heroId == "captainmarvel" or heroId == "rocket"
		or heroId=="storm" or heroId=="jean" or heroId=="gambit" or heroId=="psylocke" or heroId=="cyclops"
	for _, side in ipairs({ -1, 1 }) do
		local eyeWidth = heroId == "spiderman" and 0.48 or 0.34
		piece("Eye", V(eyeWidth, heroId == "spiderman" and 0.34 or 0.16, 0.12), V(side * 0.31, 5.49, -0.716), exposed and ink or white,
			(heroId == "ironman" or heroId == "vision" or heroId == "warmachine" or heroId == "silversurfer" or heroId == "ghostrider") and Enum.Material.Neon or Enum.Material.SmoothPlastic, CFrame.Angles(0, 0, side * 0.13))
		if exposed then piece("Brow", V(0.43, 0.1, 0.12), V(side * 0.31, 5.66, -0.7), ink, fabric, CFrame.Angles(0, 0, side * 0.18)) end
	end
	if exposed then
		oval("Nose", V(0.23, 0.3, 0.26), V(0, 5.28, -0.76), face)
		piece("Mouth", V(0.44, 0.08, 0.08), V(0, 5.03, -0.665), bulky and white or ink)
		local hair = heroId == "widow" and Color3.fromRGB(139, 45, 29) or heroId == "wanda" and Color3.fromRGB(100, 39, 31) or heroId == "thor" and gold
			or heroId == "captainmarvel" and gold or heroId == "rocket" and Color3.fromRGB(60, 46, 40) or Color3.fromRGB(39, 31, 30)
		if heroId=="storm" then hair=white elseif heroId=="jean" then hair=Color3.fromRGB(175,72,42) elseif heroId=="psylocke" then hair=Color3.fromRGB(73,42,119) end
		oval("Hair", V(1.52, 0.69, 1.37), V(0, 6.02, 0.02), hair, fabric)
		for _, side in ipairs({ -1, 1 }) do
			if heroId == "widow" or heroId == "wanda" or heroId == "thor" then
				oval("HairLock", V(0.5, 1.65, 0.75), V(side * 0.64, 5.38, 0.25), hair, fabric, CFrame.Angles(0, 0, side * 0.1))
			end
		end
	end
	if heroId == "ironman" then
		oval("FacePlate", V(1.23, 1.15, 0.3), V(0, 5.34, -0.58), gold, metal)
		-- Recessed sockets sit in front of the gold plate.
		for _, side in ipairs({ -1, 1 }) do
			piece("Visor", V(0.37, 0.13, 0.1), V(side * 0.29, 5.5, -0.775), energy, Enum.Material.Neon, CFrame.Angles(0, 0, side * 0.12))
			oval("ChestPlate", V(1.09, 1.13, 0.46), V(side * 0.58, 3.94, -0.52), red:Lerp(white, 0.08), metal, CFrame.Angles(0, 0, side * 0.14))
		end
		disc("ReactorHousing", V(0, 3.95, -0.8), 0.65, 0.16, gold, metal)
		disc("Reactor", V(0, 3.95, -0.9), 0.43, 0.1, energy, Enum.Material.Neon)
		disc("Repulsor", hands[1] + V(0, 0, -0.37), 0.32, 0.12, energy, Enum.Material.Neon)
	elseif heroId == "captain" then
		local shield = V(-1.94, 3.5, -1.32)
		for i, layer in ipairs({ { 3.12, red }, { 2.55, white }, { 1.99, red }, { 1.35, navy } }) do
			disc(i == 1 and "Shield" or "ShieldBand", shield + V(0, 0, -i * 0.07), layer[1], 0.19, layer[2], metal)
		end
		for i = 0, 4 do
			piece("ShieldStar", V(0.2, 0.75, 0.06), shield + V(math.sin(i * math.pi * 0.4) * 0.21, math.cos(i * math.pi * 0.4) * 0.21, -0.42), white, metal, CFrame.Angles(0, 0, -i * math.pi * 0.4))
		end
		piece("ChestInsignia", V(0.65, 0.65, 0.13), V(0, 3.95, -0.74), white, metal, CFrame.Angles(0, 0, math.pi / 4))
		for side = -1, 1 do piece("UniformStripe", V(0.24, 0.77, 0.15), V(side * 0.49, 2.95, -0.6), white, fabric) end
	elseif heroId == "hawkeye" then
		local bow = { V(-2.23, 5.77, -0.5), V(-2.65, 5.07, -0.64), V(-2.45, 4.09, -0.67), V(-2.65, 3.1, -0.64), V(-2.23, 2.4, -0.5) }
		for i = 1, #bow - 1 do link("Bow", bow[i], bow[i + 1], 0.19, trim:Lerp(suit, 0.6), metal) end
		link("Bowstring", bow[1], bow[#bow], 0.04, silver, metal)
		link("Arrow", V(-2.4, 4.09, -0.77), V(0.48, 4.09, -0.77), 0.09, gold, metal)
		piece("Quiver", V(0.58, 2.1, 0.65), V(0.71, 3.9, 0.92), ink, fabric, CFrame.Angles(0, 0, -0.25))
		for i = 1, 3 do link("QuiverArrow", V(0.44 + i * 0.2, 4.1, 0.9), V(0.21 + i * 0.2, 5.2, 0.9), 0.07, silver, metal) end
		link("Harness", V(-0.83, 4.38, -0.59), V(0.72, 2.7, -0.57), 0.18, ink, fabric)
	elseif heroId == "spiderman" then
		oval("SpiderEmblem", V(0.35, 0.6, 0.14), V(0, 3.9, -0.75), ink)
		for _, side in ipairs({ -1, 1 }) do
			for i = 1, 3 do link("SpiderLeg", V(side * 0.1, 3.83 + i * 0.06, -0.77), V(side * (0.48 + i * 0.05), 3.53 + i * 0.22, -0.66), 0.075, ink) end
			link("WebSeam", V(side * 0.2, 6.07, -0.52), V(side * 0.58, 4.93, -0.48), 0.05, ink)
		end
	elseif heroId == "widow" then
		link("SuitZip", V(0, 4.38, -0.64), V(0, 2.7, -0.59), 0.06, silver, metal)
		piece("WidowInsignia", V(0.36, 0.36, 0.12), V(0, 2.35, -0.81), red, metal, CFrame.Angles(0, 0, math.pi / 4))
		for _, side in ipairs({ -1, 1 }) do
			piece("Holster", V(0.38, 0.78, 0.6), V(side * 0.75, 1.72, 0), ink, metal)
			link("ShockBaton", hands[side] + V(0, 0.45, 0), hands[side] - V(0, 0.83, 0), 0.16, silver, metal)
			link("BatonCharge", hands[side] + V(0, 0.45, 0), hands[side] + V(0, 0.16, 0), 0.2, energy, Enum.Material.Neon)
		end
	elseif bulky then
		for _, side in ipairs({ -1, 1 }) do
			oval("Pectoral", V(1.72, 1.07, 0.81), V(side * 0.79, 4.03, -0.5), suit:Lerp(white, 0.09))
			oval("Trapezius", V(1.25, 0.87, 1.04), V(side * 0.81, 4.51, 0.06), suit)
			piece("RippedShorts", V(0.99, 0.64, 0.95), V(side * 0.77, 1.81, 0), trim, fabric, CFrame.Angles(0, 0, side * 0.08))
		end
		for y = 1, 2 do oval("Muscle", V(1.47, 0.42, 0.35), V(0, 2.73 + y * 0.41, -0.67), suit) end
	elseif heroId == "panther" then
		for _, side in ipairs({ -1, 1 }) do
			piece("Ear", V(0.28, 0.61, 0.32), V(side * 0.51, 6.18, 0), ink, metal, CFrame.Angles(0, 0, -side * 0.2))
			link("MaskTrace", V(side * 0.61, 5.7, -0.4), V(side * 0.26, 5.01, -0.62), 0.075, silver, metal)
			for i = 1, 3 do link("Claw", hands[side] + V(i * 0.13 - 0.26, -0.17, -0.15), hands[side] + V(i * 0.13 - 0.26, -0.65, -0.24), 0.07, silver, metal) end
		end
		for i = -2, 2 do piece("NecklaceFang", V(0.18, 0.44, 0.16), V(i * 0.3, 4.07 + math.abs(i) * 0.1, -0.64), silver, metal, CFrame.Angles(0, 0, i * 0.3)) end
	elseif heroId == "thor" then
		link("HammerHandle", hands[1] - V(0, 0.45, 0), hands[1] + V(0, 0.87, 0), 0.22, Color3.fromRGB(95, 60, 40), fabric)
		piece("Mjolnir", V(1.68, 0.96, 1.06), hands[1] + V(0, 1.14, 0), silver, metal)
		piece("HammerInset", V(1.34, 0.62, 0.09), hands[1] + V(0, 1.14, -0.58), Color3.fromRGB(96, 115, 136), metal)
		for _, side in ipairs({ -1, 1 }) do
			for i = 1, 2 do disc("ArmorDisc", V(side * 0.6, 4.36 - i * 0.59, -0.62), 0.55, 0.15, silver, metal) end
		end
	elseif heroId == "antman" then
		oval("HelmetJaw", V(1.16, 0.58, 0.6), V(0, 5.02, -0.45), ink, metal)
		for _, side in ipairs({ -1, 1 }) do
			link("Antenna", V(side * 0.65, 5.7, 0), V(side * 0.87, 6.62, -0.08), 0.12, silver, metal)
			piece("RedLens", V(0.43, 0.27, 0.2), V(side * 0.3, 5.5, -0.75), red, Enum.Material.Neon)
			disc("Respirator", V(side * 0.46, 5.04, -0.65), 0.28, 0.18, silver, metal)
			link("SuitPiping", V(side * 0.94, 4.32, -0.42), V(side * 0.52, 2.73, -0.57), 0.14, silver, metal)
		end
	elseif heroId == "vision" then
		piece("MindGem", V(0.25, 0.4, 0.13), V(0, 5.94, -0.52), gold, Enum.Material.Neon, CFrame.Angles(0, 0, math.pi / 4))
		piece("ChestDiamond", V(0.75, 0.75, 0.18), V(0, 3.98, -0.74), gold, metal, CFrame.Angles(0, 0, math.pi / 4))
	elseif heroId == "wanda" then
		for _, side in ipairs({ -1, 1 }) do
			link("Crown", V(side * 0.08, 5.76, -0.63), V(side * 0.63, 6.3, -0.4), 0.2, red, metal)
			oval("ChaosSpell", V(0.75, 0.75, 0.75), hands[side] + V(0, 0.23, -0.3), Color3.fromRGB(248, 64, 104), Enum.Material.Neon).Transparency = 0.16
		end
	elseif heroId == "strange" then
		piece("Goatee", V(0.52, 0.29, 0.1), V(0, 4.97, -0.61), ink, fabric)
		disc("Amulet", V(0, 4.13, -0.75), 0.46, 0.16, gold, metal)
		disc("AmuletEye", V(0, 4.13, -0.85), 0.18, 0.08, Color3.fromRGB(91, 230, 161), Enum.Material.Neon)
		local center = hands[-1] + V(0, 0.1, -0.48)
		for i = 0, 7 do
			local angle = i * math.pi / 4
			piece("SpellGlyph", V(0.55, 0.09, 0.08), center + V(math.sin(angle) * 0.66, math.cos(angle) * 0.66, 0), gold, Enum.Material.Neon, CFrame.Angles(0, 0, -angle))
		end
	end
	-- Heroes added after launch each carry their own silhouette accents.
	local metallic = Color3.fromRGB(150, 158, 170)
	local flame = Color3.fromRGB(255, 130, 30)
	if heroId == "falcon" then
		for _, side in ipairs({ -1, 1 }) do
			for feather = 0, 3 do
				piece("WingFeather", V(0.12, 2.5 - feather * 0.34, 0.72), V(side * (1.75 + feather * 0.46), 4.2 - feather * 0.18, 1.0),
					red:Lerp(ink, 0.25), metal, CFrame.Angles(0, side * 0.45, side * (0.35 + feather * 0.09)))
			end
			disc("GogglesLens", V(side * 0.3, 5.5, -0.84), 0.36, 0.1, energy, Enum.Material.Neon)
		end
		piece("Goggles", V(1.25, 0.34, 0.16), V(0, 5.5, -0.74), ink, metal)
	elseif heroId == "bucky" then
		-- The left arm is bare metal, marked with a red star.
		link("MetalArm", V(-1.14, 4.22, 0), V(-1.65, 3.53, -0.15), 0.84, metallic, metal)
		link("MetalForearm", V(-1.65, 3.53, -0.15), hands[-1], 0.8, metallic, metal)
		oval("MetalHand", V(0.74, 0.74, 0.8), hands[-1], metallic, metal)
		piece("StarMark", V(0.36, 0.36, 0.14), V(-1.5, 4.05, -0.62), red, Enum.Material.Neon, CFrame.Angles(0, 0, math.pi / 4))
		piece("FaceGuard", V(1.3, 0.62, 0.3), V(0, 5.02, -0.7), ink, fabric)
		link("RifleBarrel", hands[1] + V(0, 0.2, 0.2), hands[1] + V(0, 0.25, -1.9), 0.16, ink, metal)
	elseif heroId == "wasp" then
		for _, side in ipairs({ -1, 1 }) do
			local wing = piece("InsectWing", V(0.06, 2.1, 1.15), V(side * 0.95, 4.6, 0.85), energy, Enum.Material.Neon, CFrame.Angles(0, side * 0.3, side * 0.5))
			wing.Transparency = 0.5
			link("Antenna", V(side * 0.4, 5.9, 0), V(side * 0.75, 6.65, -0.05), 0.1, ink, metal)
			piece("Stripe", V(0.9, 0.16, 1.3), V(side * 0.0, 3.3 - side * 0.3, -0.05), ink, fabric)
		end
	elseif heroId == "rocket" then
		for _, side in ipairs({ -1, 1 }) do oval("Ear", V(0.5, 0.75, 0.3), V(side * 0.6, 6.15, 0), suit:Lerp(ink, 0.3)) end
		for i = 0, 4 do link("TailBand", V(0.1, 2.3 + i * 0.28, 0.85 + i * 0.35), V(0.1, 2.6 + i * 0.28, 1.15 + i * 0.35), 0.5 - i * 0.05, i % 2 == 0 and ink or suit, fabric) end
		link("BigGun", hands[1] + V(0, 0.2, 0.9), hands[1] + V(0, 0.35, -1.7), 0.45, metallic, metal)
		piece("GunMuzzle", V(0.62, 0.62, 0.3), hands[1] + V(0, 0.35, -1.85), energy, Enum.Material.Neon)
	elseif heroId == "daredevil" then
		for _, side in ipairs({ -1, 1 }) do
			piece("Horn", V(0.16, 0.55, 0.18), V(side * 0.56, 6.1, 0), red, metal, CFrame.Angles(0, 0, -side * 0.4))
			link("Billy", hands[side] + V(0, 0.5, 0), hands[side] - V(0, 1.0, 0), 0.15, ink, metal)
			link("BillyTip", hands[side] + V(0, 0.5, 0), hands[side] + V(0, 0.22, 0), 0.19, red, metal)
		end
		piece("ChestDD", V(0.42, 0.42, 0.13), V(0, 3.95, -0.74), ink, fabric, CFrame.Angles(0, 0, math.pi / 4))
	elseif heroId == "shangchi" then
		for _, side in ipairs({ -1, 1 }) do
			for i = 0, 2 do disc("TenRing", hands[side] + V(0, 0.5 - i * 0.34, -0.02), 1.0 - i * 0.08, 0.14, gold, metal) end
		end
		link("DragonCollar", V(-0.85, 4.5, -0.6), V(0.85, 4.5, -0.6), 0.2, gold, metal)
		piece("Sash", V(1.9, 0.34, 1.3), V(0, 2.4, 0), ink, fabric)
	elseif heroId == "warmachine" then
		piece("ShoulderCannon", V(0.7, 0.55, 1.5), V(1.35, 4.75, -0.1), metallic, metal)
		link("CannonBarrel", V(1.35, 4.75, -0.7), V(1.35, 4.75, -1.85), 0.3, ink, metal)
		disc("CannonMuzzle", V(1.35, 4.75, -1.9), 0.4, 0.1, energy, Enum.Material.Neon)
		disc("ReactorHousing", V(0, 3.95, -0.8), 0.65, 0.16, metallic, metal)
		disc("Reactor", V(0, 3.95, -0.9), 0.43, 0.1, energy, Enum.Material.Neon)
		oval("FacePlate", V(1.3, 1.2, 0.34), V(0, 5.34, -0.6), metallic, metal)
		for _, side in ipairs({ -1, 1 }) do piece("MissilePod", V(0.4, 0.4, 1.0), V(side * 0.85, 4.95, 0.7), ink, metal) end
	elseif heroId == "starlord" then
		oval("Helmet", V(1.72, 1.72, 1.56), V(0, 5.4, -0.03), red:Lerp(ink, 0.35), metal)
		piece("HelmetVisor", V(1.1, 0.34, 0.14), V(0, 5.42, -0.74), Color3.fromRGB(255, 92, 92), Enum.Material.Neon)
		for _, side in ipairs({ -1, 1 }) do
			link("Blaster", hands[side], hands[side] + V(0, 0.12, -1.0), 0.22, metallic, metal)
			piece("BlasterGlow", V(0.28, 0.28, 0.2), hands[side] + V(0, 0.12, -1.1), Color3.fromRGB(255, 108, 108), Enum.Material.Neon)
		end
		piece("Coat", V(2.3, 1.7, 0.16), V(0, 2.35, 0.7), suit:Lerp(ink, 0.2), fabric)
	elseif heroId == "groot" then
		for _, side in ipairs({ -1, 1 }) do
			link("Branch", V(side * 1.2, 4.7, 0), V(side * 1.95, 5.9, -0.2), 0.34, trim, Enum.Material.Wood)
			oval("Leaf", V(0.7, 0.16, 0.42), V(side * 2.0, 6.0, -0.2), Color3.fromRGB(86, 146, 64), fabric, CFrame.Angles(0, 0, side * 0.5))
			oval("Leaf", V(0.6, 0.14, 0.38), V(side * 0.7, 6.55, 0), Color3.fromRGB(112, 168, 78), fabric, CFrame.Angles(0, 0, -side * 0.6))
			link("BarkRidge", V(side * 0.5, 4.1, -0.7), V(side * 0.4, 2.5, -0.7), 0.24, trim, Enum.Material.Wood)
		end
	elseif heroId == "ghostrider" then
		for i = 1, 5 do
			oval("SkullFlame", V(0.5, 0.95 + (3 - math.abs(i - 3)) * 0.22, 0.5), V((i - 3) * 0.3, 6.25 + (3 - math.abs(i - 3)) * 0.12, 0), flame, Enum.Material.Neon).Transparency = 0.12
		end
		link("ChainA", V(-0.95, 4.45, -0.62), V(0.95, 2.85, -0.62), 0.13, silver, metal)
		link("ChainB", V(0.95, 4.45, -0.62), V(-0.95, 2.85, -0.62), 0.13, silver, metal)
		piece("JacketFlame", V(2.4, 0.1, 1.5), V(0, 2.05, 0), flame, Enum.Material.Neon).Transparency = 0.4
	elseif heroId == "captainmarvel" then
		piece("MarvelStar", V(0.74, 0.74, 0.14), V(0, 3.95, -0.74), gold, Enum.Material.Neon, CFrame.Angles(0, 0, math.pi / 4))
		link("Sash", V(-0.95, 4.35, -0.6), V(0.95, 2.5, -0.58), 0.36, red, fabric)
		for _, side in ipairs({ -1, 1 }) do
			oval("PhotonFist", V(0.95, 0.95, 0.95), hands[side], Color3.fromRGB(255, 225, 110), Enum.Material.Neon).Transparency = 0.15
		end
	elseif heroId == "silversurfer" then
		piece("Surfboard", V(2.3, 0.2, 6.2), V(0, 0.18, 0), Color3.fromRGB(214, 226, 238), metal, CFrame.Angles(0.06, 0, 0))
		piece("BoardGlow", V(1.5, 0.1, 5.0), V(0, 0.06, 0), energy, Enum.Material.Neon)
		piece("BoardTail", V(0.6, 0.18, 1.2), V(0, 0.28, 3.4), silver, metal)
		for _, side in ipairs({ -1, 1 }) do
			piece("CosmicEye", V(0.36, 0.14, 0.12), V(side * 0.3, 5.5, -0.74), energy, Enum.Material.Neon)
		end
	end
	-- Reinforcements carry recognizable silhouettes and weapons, not recolors.
	if hero.costume then
		local style=hero.costume
		local accent=Color3.fromRGB(unpack(hero.color))
		if style=="claws" then
			for _,side in ipairs({-1,1}) do
				for n=-1,1 do piece("AdamantiumClaw",V(0.08,0.09,1.65),hands[side]+V(n*0.17,0,-0.9),silver,metal) end
				piece("MaskFin",V(0.28,1.1,0.3),V(side*0.7,5.95,0),ink,metal,CFrame.Angles(0,0,-side*0.3))
			end
		elseif style=="visor" or style=="nova" then
			piece("Visor",V(1.3,0.24,0.2),V(0,5.48,-0.77),style=="visor" and red or gold,Enum.Material.Neon)
			disc("ChestStar",V(0,3.9,-0.75),0.7,0.12,gold,Enum.Material.Neon)
		elseif style=="cape" or style=="phoenix" or style=="moon" then
			for strip=-1,1 do piece("Cape",V(1.15,3.8,0.18),V(strip*0.9,2.8,0.95),accent,fabric,CFrame.Angles(-0.15,strip*0.2,0)) end
			disc("Crest",V(0,4,-0.72),0.7,0.15,gold,Enum.Material.Neon)
			if style=="phoenix" then
				for _,side in ipairs({-1,1}) do for n=1,3 do piece("PhoenixFeather",V(0.45,2.8-n*0.3,0.22),V(side*(1+n*0.45),4.6,0.5),accent,Enum.Material.Neon,CFrame.Angles(0,0,-side*(0.35+n*0.15))) end end
			end
		elseif style=="ice" then
			for n=-1,1 do piece("IceCrown",V(0.3,0.8+math.abs(n)*0.3,0.3),V(n*0.4,6.2,0),accent,Enum.Material.Ice) end
			for _,side in ipairs({-1,1}) do oval("IceFist",V(0.9,0.9,1.1),hands[side],accent,Enum.Material.Ice) end
		elseif style=="cards" then
			link("Staff",hands[-1]+V(0,-1.3,0),hands[-1]+V(0,2.7,0),0.14,silver)
			for n=-1,1 do piece("ChargedCard",V(0.5,0.8,0.08),hands[1]+V(n*0.4,0.4,-0.3),accent,Enum.Material.Neon,CFrame.Angles(0,0,n*0.3)) end
		elseif style=="tail" then
			for n=1,4 do oval("Tail",V(0.28,0.3,0.9),V(0,1.9-n*0.2,0.5+n*0.65),accent) end
		elseif style=="fur" then
			for _,side in ipairs({-1,1}) do oval("FurryFist",V(1.2,1.1,1.2),hands[side],accent,fabric) end
			for n=-1,1 do piece("HairTuft",V(0.4,0.65,0.45),V(n*0.5,6.1,0),accent,fabric,CFrame.Angles(0,0,n*0.2)) end
		elseif style=="blade" or style=="swords" then
			for _,side in ipairs({-1,1}) do piece("Blade",V(0.13,2.7,0.24),hands[side]+V(0,1.1,-0.5),style=="blade" and accent or silver,style=="blade" and Enum.Material.Neon or metal,CFrame.Angles(-0.3,0,-side*0.2)) end
		end
	end
	-- Cloth is separate from each hero's feature branch: Vision gets his cape.
	if heroId == "thor" or heroId == "strange" or heroId == "vision" or heroId == "wanda" then
		local capeColor = heroId == "vision" and gold or red
		for strip = -1, 1 do
			piece("Cape", V(1.13, heroId == "wanda" and 2.5 or 3.62, 0.15), V(strip * 0.88, heroId == "wanda" and 1.89 or 2.9, 0.98), capeColor, fabric, CFrame.Angles(-0.17, strip * 0.23, -strip * 0.07))
		end
		if heroId == "strange" then
			for _, side in ipairs({ -1, 1 }) do piece("CloakCollar", V(0.47, 1.15, 0.37), V(side * 0.79, 4.83, 0.42), red, fabric, CFrame.Angles(0.2, 0, -side * 0.27)) end
		end
	end
	return torso, head
end

-- Lighting effects are created once, by name, and adjusted afterward instead
-- of re-instanced on every Build: a match can rebuild its map several times
-- in one server (map hop, retry), and PostEffect instances would otherwise
-- pile up unnoticed since nothing else ever destroys them.
local function ensureLightingEffect(lighting, className, name)
	local existing = lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then return existing end
	if existing then existing:Destroy() end
	local instance = Instance.new(className)
	instance.Name, instance.Parent = name, lighting
	return instance
end

-- One authored mood per chapter, per the design brief: Manhattan's cold
-- night blue, Gamma's radioactive green, HYDRA's industrial grey/red,
-- Wakanda's purple and gold, Latveria's cold magic. Kept deliberately mild —
-- this is a top-down tower defense, and reading 80 enemies at once matters
-- more than atmosphere.
local MAP_LIGHTING = {
	asgard = {
		sun=2.6,clockTime=15.5,ambient={128,115,99},outdoor={174,153,120},
		atmosphereColor={242,215,174},atmosphereDensity=0.2,glare=0.12,
		tint={255,239,205},contrast=0.04,saturation=0.06,brightness=0.02,
		bloom=0.25,fogColor={178,157,137},fogEnd=720,
	},
	manhattan = {
		sun = 2.3, clockTime = 16.4, ambient = { 104, 107, 128 }, outdoor = { 128, 137, 151 },
		atmosphereColor = { 190, 208, 235 }, atmosphereDensity = 0.22, glare = 0.08,
		tint = { 244, 240, 255 }, contrast = 0.04, saturation = 0.08, brightness = 0.02,
		bloom = 0.25, fogColor = { 123, 148, 176 }, fogEnd = 680,
	},
	gamma = {
		sun = 2.6, clockTime = 14, ambient = { 40, 70, 45 }, outdoor = { 70, 110, 60 },
		atmosphereColor = { 140, 200, 120 }, atmosphereDensity = 0.38, glare = 0.18,
		tint = { 170, 255, 150 }, contrast = 0.12, saturation = 0.05, brightness = 0,
		bloom = 0.5, fogColor = { 32, 55, 30 }, fogEnd = 520,
	},
	hydra = {
		sun = 1.8, clockTime = 6.5, ambient = { 90, 96, 110 }, outdoor = { 105, 116, 135 },
		atmosphereColor = { 110, 110, 120 }, atmosphereDensity = 0.34, glare = 0.08,
		tint = { 224, 231, 255 }, contrast = 0.07, saturation = 0.02, brightness = 0.02,
		bloom = 0.28, fogColor = { 24, 25, 28 }, fogEnd = 480,
	},
	wakanda = {
		sun = 2.4, clockTime = 17.5, ambient = { 70, 55, 90 }, outdoor = { 110, 85, 60 },
		atmosphereColor = { 190, 150, 210 }, atmosphereDensity = 0.26, glare = 0.22,
		tint = { 230, 200, 255 }, contrast = 0.1, saturation = 0.08, brightness = 0.02,
		bloom = 0.48, fogColor = { 45, 35, 55 }, fogEnd = 650,
	},
	latveria = {
		sun = 1.8, clockTime = 18.5, ambient = { 100, 102, 137 }, outdoor = { 117, 129, 167 },
		atmosphereColor = { 140, 150, 220 }, atmosphereDensity = 0.4, glare = 0.26,
		tint = { 219, 225, 255 }, contrast = 0.07, saturation = 0.05, brightness = 0.02,
		bloom = 0.56, fogColor = { 30, 32, 50 }, fogEnd = 460,
	},
}

-- Applied per match map. DepthOfField is deliberately left at zero here even
-- though the lobby uses a soft one: blurring any part of an 80-enemy
-- battlefield would fight the project's own legibility rule.
local function applyMapLighting(mapId)
	local lighting = game:GetService("Lighting")
	local preset = MAP_LIGHTING[mapId] or MAP_LIGHTING.manhattan
	-- Renderer technology is authored in the place, not writable by game scripts.
	lighting.ClockTime = preset.clockTime
	-- Image-based lighting on the built-in materials: asphalt, brick and metal
	-- pick up the sky and the street lamps instead of looking like plastic.
	lighting.Brightness = preset.sun or 2
	lighting.EnvironmentDiffuseScale, lighting.EnvironmentSpecularScale = 0.55, 0.8
	lighting.GlobalShadows, lighting.ShadowSoftness = true, 0.3
	-- Night palettes need fill light: dark materials plus a saturated multiply
	-- grade made towers almost black in the actual Future renderer.
	lighting.Ambient = rgb(preset.ambient):Lerp(Color3.fromRGB(168, 176, 193), 0.7)
	lighting.OutdoorAmbient = rgb(preset.outdoor):Lerp(Color3.fromRGB(155, 165, 184), 0.65)
	lighting.ExposureCompensation = 0.25
	lighting.FogColor = rgb(preset.fogColor)
	lighting.FogEnd = preset.fogEnd
	lighting.FogStart = preset.fogEnd * 0.3
	local atmosphere = ensureLightingEffect(lighting, "Atmosphere", "Atmosphere")
	atmosphere.Density, atmosphere.Offset = preset.atmosphereDensity, 0.15
	atmosphere.Color, atmosphere.Decay, atmosphere.Glare, atmosphere.Haze = rgb(preset.atmosphereColor), rgb(preset.atmosphereColor):Lerp(Color3.new(), 0.35), preset.glare, 1.1
	local bloom = ensureLightingEffect(lighting, "BloomEffect", "Bloom")
	bloom.Intensity, bloom.Size, bloom.Threshold = preset.bloom, 24, 0.9
	local grade = ensureLightingEffect(lighting, "ColorCorrectionEffect", "ColorGrade")
	grade.TintColor = rgb(preset.tint):Lerp(Color3.new(1, 1, 1), 0.8)
	grade.Contrast, grade.Saturation, grade.Brightness = preset.contrast * 0.4, preset.saturation, 0.025
	local rays = ensureLightingEffect(lighting, "SunRaysEffect", "SunRays")
	rays.Intensity, rays.Spread = 0.1, 0.6
	local dof = ensureLightingEffect(lighting, "DepthOfFieldEffect", "DOF")
	dof.FarIntensity, dof.NearIntensity, dof.FocusDistance, dof.InFocusRadius = 0, 0, 100, 200
end

local MODE_COLOR = {
	normal = Color3.fromRGB(65, 216, 173),
	ranked = Color3.fromRGB(255, 138, 61),
	cards = Color3.fromRGB(233, 96, 214),
	infinite = Color3.fromRGB(110, 140, 255),
}
-- Four modes, evenly spaced along the operations gates.

-- The premium shop: everything sold for Robux, kept apart from the chest shop.
local SHOP_STANDS = {
	{ kind = "hero", key = "heroes" },
	{ kind = "product", key = "gold" },
	{ kind = "pass", key = "collector" },
	{ kind = "pass", key = "training" },
	{ kind = "pass", key = "formations" },
	{ kind = "pass", key = "vip" },
}

-- Lighting is one global service, shared by the lobby and whichever match map
-- is built. Standalone servers keep both areas in the same Workspace, so
-- whoever finishes a match and walks back must see the lobby's own mood
-- again, not whatever chapter they were just fighting in. World:Build applies
-- a map mood; this is the only thing that puts it back afterward.
function World:ApplyLobbyLighting()
	local lighting = game:GetService("Lighting")
	lighting.ClockTime, lighting.Brightness = 15.6, 2.5
	lighting.ExposureCompensation = 0.1
	lighting.Ambient, lighting.OutdoorAmbient = Color3.fromRGB(88, 95, 96), Color3.fromRGB(137, 146, 136)
	lighting.FogColor, lighting.FogStart, lighting.FogEnd = Color3.fromRGB(31, 40, 58), 260, 900
	local atmos = ensureLightingEffect(lighting, "Atmosphere", "Atmosphere")
	atmos.Density, atmos.Offset, atmos.Color, atmos.Decay, atmos.Glare, atmos.Haze = 0.26, 0.15, Color3.fromRGB(147, 179, 184), Color3.fromRGB(90, 110, 130), 0.1, 1
	local bloom = ensureLightingEffect(lighting, "BloomEffect", "Bloom")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.16, 18, 1.25
	local grade = ensureLightingEffect(lighting, "ColorCorrectionEffect", "ColorGrade")
	grade.TintColor, grade.Contrast, grade.Saturation, grade.Brightness = Color3.fromRGB(255, 245, 225), 0.04, 0.04, 0
	-- The lobby is the one place a soft depth blur is safe: no battlefield to
	-- keep legible, just a helicarrier deck worth a little cinematic depth.
	local dof = ensureLightingEffect(lighting, "DepthOfFieldEffect", "DOF")
	dof.FarIntensity, dof.NearIntensity, dof.FocusDistance, dof.InFocusRadius = 0.08, 0, 85, 70
	lighting.EnvironmentDiffuseScale, lighting.EnvironmentSpecularScale = 0.6, 0.9
	lighting.GlobalShadows, lighting.ShadowSoftness = true, 0.25
	-- The ocean below the deck and the sky above it; a chapter may have
	-- recoloured both, so they are put back here too.
	local terrain = workspace.Terrain
	terrain.WaterColor, terrain.WaterTransparency, terrain.WaterReflectance = Color3.fromRGB(18, 58, 86), 0.2, 0.9
	terrain.WaterWaveSize, terrain.WaterWaveSpeed = 0.4, 12
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover, clouds.Density, clouds.Color = 0.62, 0.45, Color3.fromRGB(255, 214, 190)
	clouds.Parent = terrain
end

function World.new(catalog, openPanel)
	upper = catalog.Upper or string.upper
	local self = setmetatable({ catalog = catalog, openPanel = openPanel }, World)
	-- Match places need the same portraits even when their lobby is removed.
	local storage = game:GetService("ReplicatedStorage")
	local previous = storage:FindFirstChild("DoomHeroPortraits")
	if previous then previous:Destroy() end
	local portraits = Instance.new("Folder")
	portraits.Name, portraits.Parent = "DoomHeroPortraits", storage
	for _, id in ipairs(catalog.HeroOrder) do
		local model = Instance.new("Model")
		model.Name, model.Parent = id, portraits
		model:SetAttribute("HeroId", id)
		local torso = heroFigure(model, id, catalog.Heroes[id], CFrame.new())
		model.PrimaryPart = torso
	end
	self:ApplyLobbyLighting()
	self:BuildLobby()
	return self
end

-- Every mode is its own portal, and a portal is an elevator: stepping onto
-- its pad boards it and the match starts after a short countdown, with no
-- menu at all (ElevatorService owns the pad). The sign beside it is written
-- by each viewer's client with the map this portal will take *them* to, and
-- a portal they cannot use yet is shrouded locally, per viewer.
local function buildModePortal(lobby, x, z, portalId, mode, destination, map)
	local modeId=destination.modeId
	local colors={manhattan={255,164,112},gamma={135,235,113},asgard={255,206,82},hydra={255,129,134},wakanda={203,170,255},latveria={104,232,190}}
	local tint = rgb(colors[destination.mapId])
	local model = Instance.new("Model")
	model.Name, model.Parent = "Portal_" .. portalId, lobby
	model:SetAttribute("Kind", "ModePortal")
	model:SetAttribute("ModeId", modeId)
	model:SetAttribute("PortalId", portalId)
	model:SetAttribute("MapId", destination.mapId)
	local plinth = part(model, "Plinth", Vector3.new(15, 1, 10), CFrame.new(x, 0.5, z), Color3.fromRGB(38, 50, 65), Enum.Material.DiamondPlate)
	local pad = part(model, "Pad", Vector3.new(12, 0.12, 7), CFrame.new(x, 1.06, z + 0.5), tint, Enum.Material.Neon)
	pad.CanCollide, pad.Transparency = false, 0.35
	local ringFrame=CFrame.new(x,7.5,z-3.6)
	arc(model,"PortalArmor",ringFrame,6.8,1.5,2.3,ART.pearl,Enum.Material.Metal,24)
	arc(model,"PortalGasket",ringFrame*CFrame.new(0,0,1.2),6.25,0.52,0.25,ART.ink,Enum.Material.Metal,32)
	arc(model,"Frame",ringFrame*CFrame.new(0,0,1.4),6.2,0.18,0.18,tint,Enum.Material.Neon,32)
	for i=0,7 do
		local a=i*math.pi/4
		artPart(model,"PortalBrace",Vector3.new(1.5,1.9,2.8),ringFrame*CFrame.Angles(0,0,a)*CFrame.new(0,7.1,0),ART.ink,Enum.Material.DiamondPlate)
		artPart(model,"PortalIndicator",Vector3.new(0.8,0.3,0.15),ringFrame*CFrame.Angles(0,0,a)*CFrame.new(0,7.1,1.5),tint,Enum.Material.Neon)
	end
	local glass = part(model, "Glass", Vector3.new(0.2,11.6,11.6), ringFrame*CFrame.Angles(0,math.pi/2,0), tint, Enum.Material.ForceField)
	glass.Shape,glass.Transparency=Enum.PartType.Cylinder,0.72
	for i=1,3 do
		arc(model,"PortalEcho",ringFrame*CFrame.new(0,0,-i*0.6),5.8-i*0.9,0.065,0.06,tint,Enum.Material.Neon,24)
	end
	emitter(glass, tint, 8, 3.5, 1.1, 1.6)
	emitter(pad, tint, 6, 2, 0.7, 1.2, Vector3.new(0, 5, 0))
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Parent = tint, 18, 0.9, glass
	wallSign(model,"ModeHeader",CFrame.new(x,17,z-3.6)*CFrame.Angles(0,math.pi,0),Vector3.new(23,4.5,0.5),upper(map.name.pt),upper(mode.name.pt),tint)
	-- Small landmarks identify the destination even before the sign is read.
	for _,side in ipairs({-1,1}) do
		local at=CFrame.new(x+side*10,0,z-4)
		local function detail(name,size,offset,color,material)
			return artPart(model,name,size,at*offset,color,material)
		end
		if map.id=="manhattan" then
			detail("SkylineTower",Vector3.new(3.5,10,4),CFrame.new(0,5,0),Color3.fromRGB(123,91,72),Enum.Material.Brick)
			for floor=1,4 do
				for column=-1,1,2 do detail("SkylineWindow",Vector3.new(0.8,1,0.1),CFrame.new(column,1+floor*1.8,2.06),ART.gold,Enum.Material.Neon) end
			end
		elseif map.id=="gamma" then
			local tank=detail("GammaTank",Vector3.new(3.8,7,3.8),CFrame.new(0,3.5,0),Color3.fromRGB(89,111,81),Enum.Material.Metal)
			tank.Shape=Enum.PartType.Cylinder; tank.CFrame=at*CFrame.new(0,3.5,0)*CFrame.Angles(0,0,math.pi/2); tank.Size=Vector3.new(7,3.8,3.8)
			detail("GammaWindow",Vector3.new(2.4,4,0.2),CFrame.new(0,3.8,1.9),tint,Enum.Material.Neon)
		elseif map.id=="wakanda" then
			detail("VibraniumPlinth",Vector3.new(4,2,4),CFrame.new(0,1,0),ART.gold,Enum.Material.Marble)
			detail("VibraniumCrystal",Vector3.new(2.6,6,2.6),CFrame.new(0,5,0)*CFrame.Angles(0.16,0,side*0.2),tint,Enum.Material.Neon)
		elseif map.id=="hydra" then
			detail("HydraBunker",Vector3.new(4.5,5,4.5),CFrame.new(0,2.5,0),Color3.fromRGB(70,77,70),Enum.Material.DiamondPlate)
			detail("HydraBand",Vector3.new(4.6,0.7,4.6),CFrame.new(0,4.2,0),tint,Enum.Material.Neon)
		else
			local golden=map.id=="asgard"
			detail("CitadelPillar",Vector3.new(3.5,10,3.5),CFrame.new(0,5,0),golden and ART.pearl or Color3.fromRGB(90,93,99),golden and Enum.Material.Marble or Enum.Material.Cobblestone)
			detail("CitadelCrown",Vector3.new(4.4,0.9,4.4),CFrame.new(0,10,0),golden and ART.gold or tint,Enum.Material.Metal)
			for corner=-1,1,2 do detail("CitadelFinial",Vector3.new(0.8,2,0.8),CFrame.new(corner*1.5,11,1.5),golden and ART.gold or tint,Enum.Material.Metal) end
		end
	end
	-- The per-viewer sign: which map, how many waves, or what is still missing.
	local sign = part(model, "Sign", Vector3.new(11, 2.2, 0.3), CFrame.new(x, 1.9, z + 5.6) * CFrame.Angles(0, math.pi, 0), ART.ink, Enum.Material.Metal)
	local surface = Instance.new("SurfaceGui")
	surface.Name, surface.Face, surface.Parent = "Board", Enum.NormalId.Front, sign
	surface.LightInfluence, surface.SizingMode, surface.CanvasSize = 0, Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(280, 136)
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.TextScaled, text.TextWrapped = UDim2.fromScale(1, 1), 1, true, true
	text.Font, text.TextColor3, text.Parent = Enum.Font.GothamBold, tint, surface
	text.Text = (mode.waves == 0 and "ONDAS INFINITAS" or (tostring(mode.waves) .. " ONDAS")) .. "\nENTRE PARA JOGAR"
	for _, p in ipairs(model:GetChildren()) do if p:IsA("BasePart") and p ~= plinth then p.CanCollide = false end end
	model.PrimaryPart = plinth
	return model, {
		center = Vector3.new(x, 4, z + 0.5), size = Vector3.new(12, 9, 7),
		-- Toward the spawn, clear of the pad and of the sign.
		exit = Vector3.new(x, 4, z + 9),
	}
end

-- The chest shop: heroes are found in chests, paid for with Gold. Two chests sit
-- on lit plinths, the rare one and the legendary one, each with its price on a
-- sign and a beam of light so it can be seen from across the deck.
local function buildChestStand(lobby, x, z, chestId, chest, openPanel)
	local model = Instance.new("Model")
	model.Name, model.Parent = "Chest_" .. chestId, lobby
	model:SetAttribute("Kind", "ChestStand")
	model:SetAttribute("ChestId", chestId)
	local tint = rgb(chest.color)
	local legendary = chestId == "legendary"
	local plinth = part(model, "Plinth", Vector3.new(9, 1.2, 9), CFrame.new(x, 0.6, z), ART.pearl, Enum.Material.Metal)
	artPart(model, "PlinthInset", Vector3.new(8, 0.15, 8), CFrame.new(x, 1.25, z), ART.ink, Enum.Material.DiamondPlate)
	artPart(model, "GlowRing", Vector3.new(8.4, 0.12, 8.4), CFrame.new(x, 1.3, z), tint, Enum.Material.Neon)
	local wood = legendary and Color3.fromRGB(78, 48, 22) or Color3.fromRGB(46, 62, 88)
	local scale = legendary and 1.2 or 1
	local function sized(v) return Vector3.new(v.X * scale, v.Y * scale, v.Z * scale) end
	part(model, "ChestBody", sized(Vector3.new(5.6, 2.8, 3.6)), CFrame.new(x, 1.2 + 1.4 * scale, z), wood, Enum.Material.Wood).CanCollide = false
	part(model, "ChestBand", sized(Vector3.new(5.8, 0.5, 3.8)), CFrame.new(x, 1.2 + 1.2 * scale, z), tint, Enum.Material.Metal).CanCollide = false
	for _, side in ipairs({ -1, 1 }) do
		part(model, "ChestStrap", sized(Vector3.new(0.5, 3.0, 3.8)), CFrame.new(x + side * 1.9 * scale, 1.2 + 1.4 * scale, z), tint, Enum.Material.Metal).CanCollide = false
		part(model, "ChestStud", Vector3.new(0.5, 0.5, 0.5) * scale, CFrame.new(x + side * 2.7 * scale, 1.2 + 0.4 * scale, z - 1.7 * scale), ART.gold, Enum.Material.Metal).CanCollide = false
	end
	-- The lid stands open so the light inside spills out.
	local lidY = 1.2 + 3.6 * scale
	part(model, "ChestLid", sized(Vector3.new(5.6, 1.1, 3.6)), CFrame.new(x, lidY + 0.6 * scale, z + 1.9 * scale) * CFrame.Angles(-1.0, 0, 0), wood, Enum.Material.Wood).CanCollide = false
	part(model, "ChestLidBand", sized(Vector3.new(5.8, 0.4, 3.8)), CFrame.new(x, lidY + 0.9 * scale, z + 2.05 * scale) * CFrame.Angles(-1.0, 0, 0), tint, Enum.Material.Metal).CanCollide = false
	local treasure = part(model, "Treasure", sized(Vector3.new(4.8, 0.3, 2.8)), CFrame.new(x, 1.2 + 2.9 * scale, z), tint, Enum.Material.Neon)
	treasure.CanCollide = false
	local beam = part(model, "LightBeam", Vector3.new(3.6, 16, 3.6), CFrame.new(x, 11, z), tint, Enum.Material.Neon)
	beam.Shape, beam.CanCollide, beam.CanQuery, beam.Transparency = Enum.PartType.Cylinder, false, false, 1
	beam.CFrame = CFrame.new(x, 11, z) * CFrame.Angles(0, 0, math.pi / 2)
	beam.Size = Vector3.new(16, 3.6, 3.6)
	emitter(treasure, tint, legendary and 14 or 8, 5, 0.6, 1.8, Vector3.new(0, 5, 0))
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Parent = tint, legendary and 24 or 16, 1.1, treasure
	if legendary then
		-- Gems crown the legendary chest.
		for i = 0, 5 do
			local angle = i * math.pi / 3
			part(model, "Gem", Vector3.new(0.6, 0.9, 0.6), CFrame.new(x + math.sin(angle) * 3.4, lidY + 2.6, z + math.cos(angle) * 2.2) * CFrame.Angles(0, angle, 0.4), tint:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.Neon).CanCollide = false
		end
	end
	wallSign(model, "ChestNameplate", CFrame.new(x - 4.8, 2.6, z) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(7.2, 1.9, 0.2),
		chest.kind=="base" and "BAÚS DE BASES" or "BAÚS DE HERÓIS", "5 TIPOS • A PARTIR DE 400 OURO", tint)
	for _, p in ipairs(model:GetChildren()) do if p:IsA("BasePart") and p ~= plinth then p.CanCollide = false end end
	model.PrimaryPart = plinth
	interactable(plinth, chest.name.pt, function(player) openPanel(player, "chests", { chestId = chestId }) end, 16)
	local green = Color3.fromRGB(82, 235, 146)
	local pad = artPart(model, "ShopEntryPad", Vector3.new(12, 0.18, 12), CFrame.new(x - 15, 0.48, z), green:Lerp(ART.ink, 0.58), Enum.Material.SmoothPlastic)
	for _,side in ipairs({-1,1}) do
		artPart(model,"ShopEntryBorder",Vector3.new(12,0.12,0.24),CFrame.new(x-15,0.61,z+side*5.9),green,Enum.Material.Neon)
		artPart(model,"ShopEntryBorder",Vector3.new(0.24,0.12,12),CFrame.new(x-15+side*5.9,0.61,z),green,Enum.Material.Neon)
	end
	local sign=label(pad,"PISE PARA ABRIR\nSTEP TO OPEN",Vector3.new(0,2.4,0),green,210,48)
	sign.Parent.Name="ShopEntryHint"
	return model, {center=Vector3.new(x-15,3,z),size=Vector3.new(12,7,12),chestId=chestId}
end

-- The store as a physical kiosk row: the drone spins in a display case, the
-- vault holds the gold packs, the mannequin wears the VIP look. No aisle of
-- buttons, one stand per product.
local function buildShopStand(lobby, x, z, shopKind, shopKey, displayName, openPanel, showcase)
	local model = Instance.new("Model")
	model.Name, model.Parent = "Shop_" .. shopKey, lobby
	model:SetAttribute("Kind", "ShopStand")
	model:SetAttribute("ShopKind", shopKind)
	model:SetAttribute("ShopKey", shopKey)
	local stand = part(model, "Stand", Vector3.new(6.4,1,6.4), CFrame.new(x,0.5,z), ART.pearl, Enum.Material.Metal)
	artPart(model,"DisplayInset",Vector3.new(5.8,0.15,5.8),CFrame.new(x,1.06,z),ART.ink,Enum.Material.DiamondPlate)
	for _,side in ipairs({-1,1}) do
		artPart(model,"ShowcasePillar",Vector3.new(0.45,5.6,0.45),CFrame.new(x+side*2.9,3.2,z-2.9),ART.steel,Enum.Material.Metal)
		artPart(model,"DisplayLight",Vector3.new(0.1,4.1,0.1),CFrame.new(x+side*2.65,3.2,z-2.65),ART.gold,Enum.Material.Neon)
	end
	artPart(model,"ShowcaseCanopy",Vector3.new(6.5,0.35,5.8),CFrame.new(x,6,z),ART.ink,Enum.Material.Metal)
	if shopKey == "heroes" and showcase then
		-- Recruitment card marks direct purchases without a character statue.
		artPart(model,"RecruitCard",Vector3.new(0.4,3.6,2.8),CFrame.new(x,3,z),ART.gold,Enum.Material.Metal)
		artPart(model,"RecruitStar",Vector3.new(0.5,1.2,1.2),CFrame.new(x+0.25,3,z)*CFrame.Angles(math.pi/4,0,0),ART.cyan,Enum.Material.Neon)
		part(model, "DisplayRing", Vector3.new(4.6, 0.15, 4.6), CFrame.new(x, 1.1, z), ART.gold, Enum.Material.Neon).CanCollide = false
	elseif shopKey == "collector" then
		-- A body with two crossed rotor arms, so the client's showroom spin is
		-- actually visible; a lone sphere turning looks exactly like one standing.
		local drone = part(model, "Drone", Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, 3, z), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
		drone.Shape = Enum.PartType.Ball
		for _, angle in ipairs({ math.pi / 4, -math.pi / 4 }) do
			part(model, "Drone", Vector3.new(3.2, 0.14, 0.3), CFrame.new(x, 3, z) * CFrame.Angles(0, angle, 0), Color3.fromRGB(150, 172, 190), Enum.Material.Metal)
		end
		part(model, "DroneRing", Vector3.new(2.6, 0.15, 2.6), CFrame.new(x, 2.1, z), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
	elseif shopKey == "vip" then
		part(model, "Mannequin", Vector3.new(1.6, 3.6, 1), CFrame.new(x, 2.8, z), Color3.fromRGB(255, 210, 103), Enum.Material.Neon)
		part(model, "MannequinHead", Vector3.new(1, 1, 1), CFrame.new(x, 5, z), Color3.fromRGB(255, 210, 103))
	elseif shopKey == "formations" then
		for i = 1, 3 do part(model, "Rack", Vector3.new(2.6, 0.15, 1.1), CFrame.new(x, 1.2 + i * 0.85, z), Color3.fromRGB(150, 160, 170), Enum.Material.Metal) end
	elseif shopKey == "gold" then
		for i = 1, 3 do
			-- A Cylinder's axis runs along X, so a coin lying flat needs its
			-- thickness in X and a quarter turn to stand the axis upright.
			local diameter = 1.7 - i * 0.12
			local coin = part(model, "Coin", Vector3.new(0.4, diameter, diameter), CFrame.new(x, 0.75 + i * 0.42, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 210, 103), Enum.Material.Neon)
			coin.Shape = Enum.PartType.Cylinder
		end
	else
		part(model, "Chip", Vector3.new(1.4, 1.8, 1.4), CFrame.new(x, 2.4, z), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
	end
	label(stand, displayName, Vector3.new(0, 5.6, 0), Color3.fromRGB(255, 210, 103), 220, 40)
	for _, p in ipairs(model:GetChildren()) do if p:IsA("BasePart") and p ~= stand then p.CanCollide = false end end
	model.PrimaryPart = stand
	interactable(stand, displayName, function(player) openPanel(player, "shop", { shopKind = shopKind, shopKey = shopKey }) end)
	return model
end

-- Missions and the scoreboard are signage, not windows: read from up close,
-- with the actual list opening in a small panel anchored to that board.
local function buildBoard(lobby, x, z, boardId, titleText, openPanel)
	local model = Instance.new("Model")
	model.Name, model.Parent = "Board_" .. boardId, lobby
	model:SetAttribute("Kind", "Board")
	model:SetAttribute("BoardId", boardId)
	part(model, "Post", Vector3.new(1, 8, 1), CFrame.new(x, 4, z), Color3.fromRGB(40, 54, 44), Enum.Material.Metal)
	local board = part(model, "Panel", Vector3.new(8, 5, 0.3), CFrame.new(x, 7.2, z), Color3.fromRGB(19, 27, 39), Enum.Material.Metal)
	local surface = Instance.new("SurfaceGui")
	surface.Name, surface.Face, surface.Parent = "Board", Enum.NormalId.Front, board
	surface.LightInfluence, surface.PixelsPerStud, surface.SizingMode = 0, 36, Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(288, 180)
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	text.Font, text.TextColor3, text.TextScaled = Enum.Font.GothamBold, Color3.fromRGB(230, 240, 244), true
	text.Text, text.TextWrapped, text.Parent = titleText, true, surface
	for _, p in ipairs(model:GetChildren()) do if p:IsA("BasePart") and p ~= board then p.CanCollide = false end end
	board.CanCollide = false
	model.PrimaryPart = board
	interactable(board, titleText, function(player) openPanel(player, boardId, {}) end)
	return model, text
end

function World:BuildLobby()
	local old = workspace:FindFirstChild("DoomLobby")
	if old then old:Destroy() end
	local lobby = Instance.new("Model")
	lobby.Name, lobby.Parent = "DoomLobby", workspace
	self.lobby, self.portalZones, self.shopZones, self.shopOccupants = lobby, {}, {}, {}
	local center = Vector3.new(0, 0, 320)
	local hull = part(lobby, "Helicarrier", Vector3.new(180, 8, 150), CFrame.new(center - Vector3.new(0, 5, 0)), Color3.fromRGB(23, 32, 47), Enum.Material.Metal)
	hull.CastShadow = true
	part(lobby, "FlightDeck", Vector3.new(178, 1, 148), CFrame.new(center - Vector3.new(0, 0.5, 0)), ART.steel, Enum.Material.Concrete)
	for x = -80, 80, 20 do
		part(lobby, "DeckLine", Vector3.new(0.25, 0.05, 140), CFrame.new(x, 0.03, 320), Color3.fromRGB(45, 62, 78))
	end
	for _, x in ipairs({ -86, 86 }) do
		part(lobby, "RunwayLight", Vector3.new(1, 0.4, 145), CFrame.new(x, 0.2, 320), Color3.fromRGB(71, 232, 178), Enum.Material.Neon)
		for z = 260, 380, 15 do
			part(lobby, "Rail", Vector3.new(1, 5, 1), CFrame.new(x, 2.5, z), Color3.fromRGB(64, 85, 103), Enum.Material.Metal)
		end
	end
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size, spawn.CFrame = "LobbySpawn", Vector3.new(14, 0.2, 14), CFrame.new(0, 0.2, 345)
	spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.Transparency = true, true, 0, 1
	spawn.Parent = lobby
	self.lobbySpawn = Vector3.new(0, 4, 345)

	-- The bridge is a landmark, not a menu: branding and a skyline view of the
	-- deck, with every actual function living at its own physical location.
	local bridge = part(lobby, "Bridge", Vector3.new(44, 7, 18), CFrame.new(0, 3.5, 265), Color3.fromRGB(19, 27, 39), Enum.Material.Metal)
	bridge.CastShadow = true
	wallSign(lobby,"CommandIdentity",CFrame.new(0,8,276)*CFrame.Angles(0,math.pi,0),Vector3.new(18,4,0.5),"DOOMSDAY","REFÚGIO DA AURORA / AURORA REFUGE",ART.gold)

	-- Four mode portals: color, signage and unlock state are all per mode,
	-- never a shared tabbed list. Each group's host may choose its map.
	for _, portalId in ipairs(self.catalog.DestinationOrder) do
		local destination=self.catalog.Destinations[portalId]
		local _, zone = buildModePortal(lobby, destination.x, destination.z, portalId, self.catalog.Modes[destination.modeId], destination, self.catalog.Maps[destination.mapId])
		self.portalZones[portalId] = zone
	end

	-- The collection lives in the HUD; the plaza stays clear of hero statues.

	-- The chest shop, east of the plaza: Gold for heroes, by chance.
	local chestZ = { rare = 338, legendary = 374 }
	-- Two welcoming shop pads; all ten chest tiers live in the shop selector.
	for _, chestId in ipairs({"rare", "base_rare"}) do
		chestZ.base_rare=374
		local _,zone=buildChestStand(lobby, 58, chestZ[chestId], chestId, self.catalog.Chests[chestId], self.openPanel)
		self.shopZones[chestId]=zone
	end
	wallSign(lobby, "ChestShopSign", CFrame.new(67, 8, 356) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(16, 3.4, 0.5),
		"LOJA DE BAÚS", "OURO / GOLD", ART.gold)
	for _, z in ipairs({ 322, 390 }) do
		artPart(lobby, "ChestShopPillar", Vector3.new(2, 15, 2), CFrame.new(69, 7.5, z), ART.pearl, Enum.Material.Metal).CastShadow = true
		artPart(lobby, "ChestShopPillarLight", Vector3.new(0.3, 12, 0.3), CFrame.new(67.9, 7.5, z), ART.gold, Enum.Material.Neon)
	end

	-- The premium shop, west of the plaza: everything sold for Robux.
	local showcase = self.catalog.Heroes.silversurfer
	local shopZ = { 316, 330, 344, 358, 372, 386 }
	for index, entry in ipairs(SHOP_STANDS) do
		local pass = entry.kind == "pass" and self.catalog.Products.Passes[entry.key]
		local displayName = pass and pass.name.pt or (entry.kind == "hero" and "Vitrine de Heróis" or "Cofre de Ouro")
		buildShopStand(lobby, -66, shopZ[index], entry.kind, entry.key, displayName, self.openPanel, entry.kind == "hero" and showcase or nil)
	end
	wallSign(lobby, "PremiumShopSign", CFrame.new(-74, 8, 351) * CFrame.Angles(0, -math.pi / 2, 0), Vector3.new(18, 3.4, 0.5),
		"LOJA PREMIUM", "ROBUX", Color3.fromRGB(207, 180, 231))

	-- Mission board and hall-of-fame totem flank the bridge entrance.
	buildBoard(lobby, -23, 393, "quests", "MISSÕES\nDA RESISTÊNCIA", self.openPanel)
	local _, leaderboardText = buildBoard(lobby, 23, 405, "leaderboard", "SALÃO DA FAMA\nCarregando…", self.openPanel)
	self.leaderboardText = leaderboardText

	-- Engine nacelles and a suspended deck silhouette make the hub readable from above.
	for _, x in ipairs({ -65, 65 }) do
		for _, z in ipairs({ 270, 370 }) do
			local engine = part(lobby, "Engine", Vector3.new(22, 8, 22), CFrame.new(x, -10, z), Color3.fromRGB(17, 25, 37), Enum.Material.Metal)
			engine.Shape = Enum.PartType.Cylinder
			part(lobby, "Thruster", Vector3.new(14, 1, 14), CFrame.new(x, -15, z), Color3.fromRGB(59, 195, 239), Enum.Material.Neon)
		end
	end
	self:DressLobby(lobby)
	self:ArtDirectLobby(lobby)
	self:BuildForestSanctuary(lobby)
	self:FinishLobby(lobby)
	self:ExpandForestVillage(lobby)
end

-- Check root positions on the server, not Touched events from every limb.
-- Closing a menu while standing on a pad keeps it closed until re-entry.
function World:RecoverLobbyVisitors(players)
	-- Only visitors supplied by the lobby loop are eligible: never teleport a
	-- commander out of an active battle or an account waiting on a transfer.
	for _,player in ipairs(players) do
		local character=player.Character
		local root=character and character:FindFirstChild("HumanoidRootPart")
		if root and root.Position.Y < -24 then
			character:PivotTo(CFrame.new(self.lobbySpawn))
			root.AssemblyLinearVelocity=Vector3.zero
			root.AssemblyAngularVelocity=Vector3.zero
		end
	end
end

function World:StepShopEntries(players)
	local occupants={}
	for _,player in ipairs(players) do
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		local previous=self.shopOccupants[player.UserId]
		local function inside(zone,margin)
			if not zone or not root then return false end
			local offset=root.Position-zone.center
			return math.abs(offset.X)<=zone.size.X/2+margin and math.abs(offset.Y)<=zone.size.Y/2+margin and math.abs(offset.Z)<=zone.size.Z/2+margin
		end
		if previous and inside(self.shopZones[previous],1) then
			occupants[player.UserId]=previous
		else
			for _,id in ipairs(self.catalog.ChestOrder) do
				if inside(self.shopZones[id],0) then
					occupants[player.UserId]=id
					self.openPanel(player,"chests",{chestId=id})
					break
				end
			end
		end
	end
	self.shopOccupants=occupants
end

-- A recognizable social world around the operations plaza. All terrain is
-- owned by DoomLobby, so rebuilding never leaves grass or trees in a match.
function World:BuildForestSanctuary(lobby)
	local V=Vector3.new
	local forest=Instance.new("Model")
	forest.Name,forest.Parent="AuroraSanctuary",lobby
	forest:SetAttribute("ArtTheme","ForestSanctuary")
	local grass=Color3.fromRGB(82,151,82)
	local stone=Color3.fromRGB(86,102,111)
	local wood=Color3.fromRGB(105,69,44)
	local function piece(name,size,cf,color,material,solid)
		local p=artPart(forest,name,size,cf,color,material)
		p.CanCollide=solid==true
		return p
	end
	local function disk(name,at,size,color,material,solid)
		local p=piece(name,size,CFrame.new(at)*CFrame.Angles(0,0,math.pi/2),color,material,solid)
		p.Shape=Enum.PartType.Cylinder
		return p
	end
	-- A broad, layered island instead of a bigger empty flight deck.
	disk("IslandCliff",V(0,-18,350),V(34,336,306),stone,Enum.Material.Slate,true)
	disk("IslandFoundation",V(0,-39,350),V(26,280,257),Color3.fromRGB(67,79,92),Enum.Material.Rock,true)
	disk("IslandUnderside",V(0,-60,350),V(22,206,189),Color3.fromRGB(52,64,79),Enum.Material.Slate,true)
	disk("ForestGround",V(0,-2.1,350),V(4,340,310),grass,Enum.Material.Grass,true)
	-- The retired carrier is nested in the island. Remove aircraft hardware
	-- that would otherwise protrude through walking trails and foliage.
	for _,child in ipairs(lobby:GetChildren()) do
		if child.Name=="Rotor" or child.Name=="Engine" or child.Name=="Thruster" or child.Name=="Rail" or child.Name=="RunwayLight" then child:Destroy() end
	end
	local function beam(name,a,b,width,tint,material,solid)
		return piece(name,V(width,width,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),tint,material,solid)
	end
	local function path(a,b,width)
		local mid=(a+b)/2
		piece("ForestTrail",V(width,0.16,(b-a).Magnitude+1),CFrame.lookAt(mid,b),Color3.fromRGB(195,169,115),Enum.Material.Sand,true)
		for t=0.1,0.9,0.2 do
			local p=a:Lerp(b,t)
			piece("TrailPaver",V(width*0.62,0.09,2.4),CFrame.lookAt(p+V(0,0.13,0),b),Color3.fromRGB(204,197,168),Enum.Material.Cobblestone,true)
		end
	end
	path(V(0,0.05,389),V(0,0.05,440),12)
	path(V(-85,0.05,345),V(-120,0.05,345),10)
	path(V(-120,0.05,345),V(-120,0.05,418),10)
	path(V(-120,0.05,418),V(0,0.05,440),10)
	path(V(85,0.05,345),V(119,0.05,345),10)
	path(V(119,0.05,345),V(119,0.05,431),10)
	path(V(119,0.05,431),V(0,0.05,440),10)
	local function tree(x,z,height,seed,ancient)
		local trunkWidth=ancient and 7 or 2.1
		local crown=ancient and 29 or 11
		local a=V(x,0,z)
		local trunk=beam(ancient and "AuroraTrunk" or "ForestTrunk",a,V(x+1,height*0.7,z),trunkWidth,wood,Enum.Material.Wood,true)
		trunk.CastShadow=ancient==true
		for i=1,4 do
			local angle=i*math.pi/2+seed
			local endpoint=V(x+math.cos(angle)*crown*0.55,height*(0.67+(i%2)*0.16),z+math.sin(angle)*crown*0.55)
			beam("TreeBranch",V(x,height*0.43,z),endpoint,trunkWidth*0.55,wood,Enum.Material.Wood,false)
			local tint=ancient and Color3.fromRGB(225-i*12,159+i*11,53+i*9) or Color3.fromRGB(48+i*8,116+i*12,61+i*7)
			local leaf=piece(ancient and "AuroraCanopy" or "ForestCanopy",V(crown,crown*0.77,crown),CFrame.new(endpoint)*CFrame.Angles(0,seed,0),tint,Enum.Material.Grass,false)
			leaf.Shape=Enum.PartType.Ball
			leaf.CastShadow=ancient or i==1
		end
	end
	-- Deliberately keep the plaza, portal approach and signed trails clear.
	local rng=Random.new(73419)
	for i=0,23 do
		local angle=i*math.pi*2/24
		local rock=piece("IslandCrag",V(26+rng:NextNumber(0,9),24,24),CFrame.new(math.cos(angle)*153,-13,350+math.sin(angle)*140)*CFrame.Angles(0,angle,0.2),stone,Enum.Material.Rock,true)
		rock.Shape=Enum.PartType.Ball
	end
	for i=0,39 do
		local angle=i*math.pi*2/40
		local x=math.cos(angle)*(143+rng:NextNumber(-7,7))
		local z=350+math.sin(angle)*(134+rng:NextNumber(-5,5))
		if not (math.abs(x)<37 and z>450) then tree(x,z,rng:NextNumber(19,30),i,false) end
	end
	for _,spot in ipairs({{-103,270},{-119,290},{-104,310},{106,270},{121,291},{105,313},{-103,374},{104,375},{-95,452},{94,455},{-57,469},{59,471}}) do
		tree(spot[1],spot[2],rng:NextNumber(19,25),spot[1],false)
		for i=1,3 do
			local x,z=spot[1]+rng:NextNumber(-6,6),spot[2]+rng:NextNumber(-6,6)
			local shrub=piece("WoodlandShrub",V(4,2.6,4),CFrame.new(x,1,z),Color3.fromRGB(56,126+i*9,78),Enum.Material.LeafyGrass,false)
			shrub.Shape=Enum.PartType.Ball
			local flower=piece("Wildflower",V(0.75,0.6,0.75),CFrame.new(x+1.3,2.2,z),i==1 and Color3.fromRGB(255,208,93) or Color3.fromRGB(189,137,230),Enum.Material.SmoothPlastic,false)
			flower.Shape=Enum.PartType.Ball
		end
	end
	-- The landmark children can describe later: the huge golden tree with
	-- a luminous blue heart, roots to climb and a circular gathering seat.
	tree(0,455,49,0.4,true)
	-- Overlapping, irregular crown tiers replace the four isolated leaf balls.
	for i=0,11 do
		local a=i*math.pi*2/12
		local tier=i%3
		local leaf=piece("AuroraCrownCluster",V(19+tier*2,15,19+tier),CFrame.new(math.cos(a)*(17-tier*3),37+tier*5,455+math.sin(a)*(17-tier*3)),Color3.fromRGB(242-tier*10,172+tier*15,64+tier*9),Enum.Material.Grass,false)
		leaf.Shape=Enum.PartType.Ball
	end
	for i=0,5 do
		local a=i*math.pi/3
		local start=V(math.cos(a)*2,6,455+math.sin(a)*2)
		beam("AncientBarkRidge",start,start+V(math.cos(a)*0.5,19,math.sin(a)*0.5),0.6,Color3.fromRGB(138,90,49),Enum.Material.Wood,false)
	end
	for i=0,7 do
		local a=i*math.pi/4
		beam("AuroraRoot",V(math.cos(a)*3,4,455+math.sin(a)*3),V(math.cos(a)*17,0.5,455+math.sin(a)*17),2.2,wood,Enum.Material.Wood,true)
	end
	local heart=piece("AuroraHeart",V(3,4.7,2),CFrame.new(0,9,451.1),ART.cyan,Enum.Material.Neon,false)
	heart.Shape=Enum.PartType.Ball
	local light=Instance.new("PointLight")
	light.Color,light.Brightness,light.Range,light.Parent=ART.cyan,1.4,20,heart
	for _,side in ipairs({-1,1}) do
		piece("GatheringBench",V(12,0.7,2.5),CFrame.new(side*13,2,441)*CFrame.Angles(0,side*0.3,0),wood,Enum.Material.WoodPlanks,true)
		piece("GatheringBackrest",V(12,1.8,0.4),CFrame.new(side*13,3.1,442.1)*CFrame.Angles(0,side*0.3,0),wood,Enum.Material.WoodPlanks,true)
		for dx=-4,4,8 do piece("BenchStone",V(1.3,2,2),CFrame.new(side*13+dx,1,441),stone,Enum.Material.Cobblestone,true) end
	end
	wallSign(forest,"AuroraWelcome",CFrame.new(-17,4,427),V(13,3,0.5),"ÁRVORE DA AURORA","UM LUGAR PARA VOLTAR",ART.gold)
	-- An entrance arch makes the forest trail visible from the spawn plaza.
	for _,side in ipairs({-1,1}) do
		piece("WoodlandArchFoot",V(3.3,2,3.3),CFrame.new(side*9,1,406),stone,Enum.Material.Cobblestone,true)
		beam("WoodlandArchPost",V(side*9,1,406),V(side*8,12,406),1.4,wood,Enum.Material.Wood,true)
		beam("WoodlandArchBrace",V(side*8.7,7,406),V(side*4.5,12,406),0.65,wood,Enum.Material.Wood,false)
	end
	beam("WoodlandArchCrown",V(-10,12,406),V(10,12,406),1.5,wood,Enum.Material.Wood,true)
	wallSign(forest,"SanctuaryArchSign",CFrame.new(0,10.9,405.4),V(11,2.4,0.4),"BOSQUE DA AURORA","EXPLORE  /  DESCANSE  /  ENCONTRE AMIGOS",ART.gold)
	for i=0,6 do
		local x=-8+i*2.65
		local shrub=piece("ArchIvy",V(3.8,2,3),CFrame.new(x,13,406),Color3.fromRGB(60,134+i*4,79),Enum.Material.LeafyGrass,false)
		shrub.Shape=Enum.PartType.Ball
	end
	-- Warm hanging lights and a few slow motes are a local visual effect.
	for i=0,7 do
		local a=i*math.pi/4
		local x,z=math.cos(a)*16,455+math.sin(a)*16
		local bottom=14+(i%3)*2
		beam("HangingCord",V(x,29,z),V(x,bottom,z),0.09,wood,Enum.Material.Wood,false)
		piece("HangingLanternRoof",V(1.4,0.25,1.4),CFrame.new(x,bottom+0.65,z),wood,Enum.Material.WoodPlanks,false)
		piece("HangingLanternGlass",V(0.8,1,0.8),CFrame.new(x,bottom,z),Color3.fromRGB(255,217,131),Enum.Material.Neon,false)
		piece("HangingLanternBase",V(1.1,0.2,1.1),CFrame.new(x,bottom-0.6,z),wood,Enum.Material.Wood,false)
	end
	for i=0,11 do
		local a=i*math.pi/6
		local mote=piece("ForestMote",V(0.18,0.18,0.18),CFrame.new(math.cos(a)*21,3+(i%4),452+math.sin(a)*20),Color3.fromRGB(255,229,156),Enum.Material.Neon,false)
		mote.Shape=Enum.PartType.Ball
	end
	-- Quiet woodland camp: logs, a warm lantern and a little timber shelter.
	for i=0,2 do
		local a=i*math.pi*2/3
		piece("CampLog",V(7,1.5,1.6),CFrame.new(-121+math.cos(a)*7,0.8,403+math.sin(a)*7)*CFrame.Angles(0,-a,0),wood,Enum.Material.Wood,true)
	end
	disk("CampRing",V(-121,0.3,403),V(0.6,5,5),stone,Enum.Material.Cobblestone,true)
	local lantern=piece("CampLantern",V(1.4,2,1.4),CFrame.new(-121,1.4,403),Color3.fromRGB(255,181,76),Enum.Material.Neon,false)
	local warm=Instance.new("PointLight")
	warm.Color,warm.Range,warm.Brightness,warm.Parent=Color3.fromRGB(255,194,103),16,1.3,lantern
	for _,side in ipairs({-1,1}) do
		piece("CampShelter",V(8,0.6,10),CFrame.new(-140+side*3,4.5,398)*CFrame.Angles(0,0,side*0.65),Color3.fromRGB(62,102,109),Enum.Material.WoodPlanks,true)
	end
	-- A waterfall and its timber overlook give the opposite trail a distinct destination.
	for i=0,5 do
		local rock=piece("WaterfallRock",V(12,15+i%3*3,12),CFrame.new(147+(i%2)*9,-5,365+math.floor(i/2)*9),stone,Enum.Material.Rock,true)
		rock.Shape=Enum.PartType.Ball
	end
	local water=piece("AuroraFalls",V(11,48,0.5),CFrame.new(158,-22,382)*CFrame.Angles(0,-0.4,0),Color3.fromRGB(86,205,218),Enum.Material.Glass,false)
	water.Transparency=0.24
	for i=0,4 do
		piece("WaterfallFoam",V(0.35,44-i*2,0.2),CFrame.new(154+i*2,-20,382.3-i*0.85),Color3.fromRGB(210,247,238),Enum.Material.SmoothPlastic,false).Transparency=0.35
	end
	path(V(119,0.05,374),V(146,0.05,374),7)
	for i=0,12 do piece("LookoutPlank",V(8,0.35,1.5),CFrame.new(142,0.3,367+i*1.5),wood,Enum.Material.WoodPlanks,true) end
	for _,z in ipairs({367,376,385}) do
		piece("LookoutPost",V(0.6,4,0.6),CFrame.new(146,2,z),wood,Enum.Material.Wood,true)
	end
	beam("LookoutRail",V(146,3.8,367),V(146,3.8,386),0.4,wood,Enum.Material.Wood,true)
	wallSign(forest,"LookoutPlaque",CFrame.new(140,2.8,385),V(6,1.6,0.2),"MIRANTE","CACHOEIRA DA AURORA",ART.cyan)
	-- Short optional jumping trail, with a safe landing on the island.
	for i=1,7 do
		disk("JumpStone",V(43+i*8,0.6+(i%4)*1.2,457+math.sin(i*0.8)*7),V(1.2,5,5),stone,Enum.Material.Slate,true)
	end
	for _,spot in ipairs({{-109,341},{-115,420},{24,421},{108,429},{112,338}}) do
		piece("TrailLanternPost",V(0.55,6,0.55),CFrame.new(spot[1],3,spot[2]),wood,Enum.Material.Wood,true)
		piece("TrailLantern",V(1.1,1.3,1.1),CFrame.new(spot[1],6,spot[2]),Color3.fromRGB(255,213,130),Enum.Material.Neon,false)
	end
	wallSign(forest,"ForestDirections",CFrame.new(14,3.2,398),V(11,3,0.45),"BOSQUE DA AURORA","TRILHAS  /  MIRANTE  /  ENCONTROS",ART.gold)
end

-- Optional exploration radiates from the compact service plaza. Each island
-- has a different silhouette and a continuous route back to the main woods.
function World:ExpandForestVillage(lobby)
	local scene=Instance.new("Model")
	scene.Name,scene.Parent="AuroraArchipelago",lobby
	local V=Vector3.new
	local wood=Color3.fromRGB(119,81,51)
	local cream=Color3.fromRGB(234,215,176)
	local stone=Color3.fromRGB(99,115,103)
	local grass=Color3.fromRGB(92,153,78)
	local gold=Color3.fromRGB(236,186,84)
	local leaf=Color3.fromRGB(68,127,88)
	local function p(name,size,cf,color,material,solid)
		local obj=artPart(scene,name,size,cf,color,material)
		obj.CanCollide=solid==true
		return obj
	end
	local function disk(name,at,diameter,height,color,material,solid)
		local obj=p(name,V(height,diameter,diameter),CFrame.new(at)*CFrame.Angles(0,0,math.pi/2),color,material,solid)
		obj.Shape=Enum.PartType.Cylinder
		return obj
	end
	local function beam(name,a,b,width,height,color,material,solid)
		return p(name,V(width,height,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),color,material,solid)
	end
	local function trail(a,b,width)
		beam("IslandTrail",a,b,width,0.16,Color3.fromRGB(204,183,137),Enum.Material.Sand,true)
	end
	local function sign(name,position,pt,en,subPT,subEN,tint)
		local facing=name=="PlazaDirections" and math.pi or 0
		wallSign(scene,name,CFrame.new(position)*CFrame.Angles(0,facing,0),V(17,4,0.4),pt,subPT,tint)
		local board=scene:FindFirstChild(name)
		local surface=board and board:FindFirstChild("Artwork")
		if surface then
			for _,entry in ipairs({{"Title",pt,en},{"Subtitle",subPT,subEN}}) do
				local text=surface:FindFirstChild(entry[1])
				if text then text:SetAttribute("LobbyTextPT",entry[2]); text:SetAttribute("LobbyTextEN",entry[3]) end
			end
		end
		for _,side in ipairs({-1,1}) do p("IslandSignPost",V(0.6,5,0.6),CFrame.new(position+V(side*7.4,-3,0)),wood,Enum.Material.Wood,true) end
	end
	local function island(id,x,z,diameter)
		disk(id.."Cliff",V(x,-11,z),diameter-3,21,stone,Enum.Material.Slate,true)
		local top=disk(id.."Ground",V(x,-1,z),diameter,2,grass,Enum.Material.Grass,true)
		top:SetAttribute("ExplorationIsland",id)
		disk(id.."Underside",V(x,-27,z),diameter*0.7,14,Color3.fromRGB(75,93,88),Enum.Material.Rock,true)
	end
	local function bridge(id,a,b)
		local direction=(b-a).Unit
		local side=V(-direction.Z,0,direction.X)
		local deck=beam("BridgeDeck",a,b,10,0.7,wood,Enum.Material.WoodPlanks,true)
		deck:SetAttribute("BridgeId",id)
		for _,s in ipairs({-1,1}) do
			beam("BridgeRail",a+side*s*5+V(0,3,0),b+side*s*5+V(0,3,0),0.3,0.4,cream,Enum.Material.Wood,true)
			for i=0,4 do
				local at=a:Lerp(b,i/4)+side*s*5
				p("BridgePost",V(0.65,4,0.65),CFrame.new(at+V(0,1.6,0)),wood,Enum.Material.Wood,true)
			end
		end
		for i=1,5 do
			local at=a:Lerp(b,i/6)
			p("BridgeCrossPlank",V(10,0.12,0.3),CFrame.lookAt(at+V(0,0.4,0),at+direction+V(0,0.4,0)),cream,Enum.Material.Wood,false)
		end
	end
	local function tree(x,z,h,tint)
		p("OuterTrunk",V(2,h*0.7,2),CFrame.new(x,h*0.35,z),wood,Enum.Material.Wood,true)
		for i=0,2 do
			local crown=p("OuterCanopy",V(14-i*2,10,14-i*2),CFrame.new(x+(i-1)*2,h*0.62+i*3,z),tint,Enum.Material.Grass,false)
			local mesh=Instance.new("SpecialMesh"); mesh.MeshType=Enum.MeshType.Sphere; mesh.Parent=crown
		end
	end
	local function seat(x,y,z,angle)
		local cf=CFrame.new(x,y,z)*CFrame.Angles(0,angle or 0,0)
		local chair=Instance.new("Seat")
		chair.Name,chair.Size,chair.CFrame="ExplorerSeat",V(3,0.6,2.4),cf
		chair.Anchored,chair.Color,chair.Material=true,wood,Enum.Material.WoodPlanks
		chair.Parent=scene
		p("ExplorerSeatBack",V(3,2,0.4),cf*CFrame.new(0,1,1.2),cream,Enum.Material.Wood,true)
	end
	island("Explorer",-204,426,124)
	island("Starlight",194,460,136)
	island("Woodland",0,556,178)
	bridge("explorers",V(-120,0.65,400),V(-165,0.65,419))
	bridge("starlight",V(119,0.65,431),V(157,0.65,447))
	bridge("woodland",V(0,0.65,484),V(0,0.65,516))
	-- Walk around the Aurora tree's trunk and roots to reach the north bridge.
	trail(V(28,0.18,438),V(28,0.18,478),12)
	trail(V(28,0.18,478),V(0,0.18,484),12)
	trail(V(0,0.18,516),V(0,0.18,581),13)
	trail(V(-165,0.18,419),V(-216,0.18,432),11)
	trail(V(157,0.18,447),V(222,0.18,461),11)
	trail(V(-43,0.18,535),V(43,0.18,535),11)
	trail(V(-43,0.18,535),V(-43,0.18,541),10)
	trail(V(43,0.18,535),V(43,0.18,541),10)
	-- Small village: open frontages, colored roofs and places to sit together.
	for i,def in ipairs({{-43,550,Color3.fromRGB(171,86,74)},{43,550,Color3.fromRGB(77,132,139)},{0,598,Color3.fromRGB(128,103,166)}}) do
		local x,z,tint=def[1],def[2],def[3]
		p("CottageDeck",V(22,1,18),CFrame.new(x,0.5,z),wood,Enum.Material.WoodPlanks,true)
		p("CottageBack",V(22,9,0.8),CFrame.new(x,5,z+8),cream,Enum.Material.Plaster,true)
		for _,side in ipairs({-1,1}) do
			p("CottageWall",V(0.8,9,16),CFrame.new(x+side*10.6,5,z),cream,Enum.Material.Plaster,true)
			p("CottageRoof",V(12.5,0.8,21),CFrame.new(x+side*5.6,11,z)*CFrame.Angles(0,0,-side*0.3),tint,Enum.Material.WoodPlanks,true)
			p("CottagePillar",V(1,10,1),CFrame.new(x+side*9,5,z-8),wood,Enum.Material.Wood,true)
			p("CottageWindow",V(0.1,3.2,3),CFrame.new(x+side*11.1,5,z),Color3.fromRGB(164,219,205),Enum.Material.Glass,false)
		end
		p("CottageCounter",V(9,2.5,3),CFrame.new(x,2.2,z+4),tint,Enum.Material.WoodPlanks,true)
		seat(x-5,1.4,z+3,math.pi/2); seat(x+5,1.4,z+3,-math.pi/2)
		p("CottageStep",V(10,0.45,3),CFrame.new(x,0.2,z-10),stone,Enum.Material.Cobblestone,true)
		p("CottageLintel",V(21,0.8,0.9),CFrame.new(x,9,z-8.3),wood,Enum.Material.Wood,true)
		p("CottageRidge",V(0.7,0.7,22),CFrame.new(x,13,z),cream,Enum.Material.Wood,false)
		p("CottageChimney",V(2.4,6,2.4),CFrame.new(x+6,12,z+3),stone,Enum.Material.Brick,true)
		p("CottageChimneyCap",V(3.2,0.6,3.2),CFrame.new(x+6,15.2,z+3),cream,Enum.Material.Slate,false)
		for _,side in ipairs({-1,1}) do
			p("CottageFrontWall",V(4.2,8,0.8),CFrame.new(x+side*8,5,z-8),cream,Enum.Material.Plaster,true)
			p("CottagePlanter",V(4.5,1.4,2.3),CFrame.new(x+side*8,1,z-10),wood,Enum.Material.WoodPlanks,true)
			p("CottageHerbs",V(4,0.7,2),CFrame.new(x+side*8,2,z-10),leaf,Enum.Material.Grass,false)
			for f=-1,1 do p("CottageBlossom",V(0.6,0.35,0.6),CFrame.new(x+side*8+f*1.2,2.5,z-10),i==1 and gold or Color3.fromRGB(232,152,174),Enum.Material.SmoothPlastic,false) end
		end
	end
	-- A shared well and picnic corner give the village a lived-in centre.
	disk("VillageWellBase",V(22,0.4,574),12,0.8,stone,Enum.Material.Cobblestone,true)
	disk("VillageWellWater",V(22,1,574),7,0.3,Color3.fromRGB(89,161,172),Enum.Material.Glass,false)
	for i=0,9 do
		local a=i*math.pi/5
		p("VillageWellStone",V(2.7,2.4,1.3),CFrame.new(22+math.sin(a)*4,1.6,574+math.cos(a)*4)*CFrame.Angles(0,a,0),cream,Enum.Material.Cobblestone,true)
	end
	for _,side in ipairs({-1,1}) do
		p("VillageWellPost",V(0.8,9,0.8),CFrame.new(22+side*5,4.5,574),wood,Enum.Material.Wood,true)
		p("VillageWellRoof",V(7,0.6,12),CFrame.new(22+side*3,10,574)*CFrame.Angles(0,0,-side*0.3),Color3.fromRGB(109,136,123),Enum.Material.WoodPlanks,true)
	end
	beam("VillageWellSpindle",V(17,6,574),V(27,6,574),0.6,0.6,wood,Enum.Material.Wood,false)
	p("VillageWellRope",V(0.14,4,0.14),CFrame.new(22,4,574),cream,Enum.Material.Fabric,false)
	p("PicnicTable",V(10,0.6,5),CFrame.new(-27,3,577),wood,Enum.Material.WoodPlanks,true)
	for _,side in ipairs({-1,1}) do
		p("PicnicLeg",V(0.8,3,4),CFrame.new(-27+side*3.5,1.5,577),wood,Enum.Material.Wood,true)
		seat(-27,1.7,577+side*4,side==1 and 0 or math.pi)
	end
	-- Explorer tower has real stairs and a safe, fenced viewing deck.
	p("ExplorerTowerFoot",V(16,2,16),CFrame.new(-218,1,445),stone,Enum.Material.Cobblestone,true)
	for i=1,14 do
		p("ExplorerStair",V(9,0.75,2.3),CFrame.new(-218,i*0.75,421+i*1.65),wood,Enum.Material.WoodPlanks,true)
	end
	p("ExplorerTowerDeck",V(20,1,20),CFrame.new(-218,10.9,454),wood,Enum.Material.WoodPlanks,true)
	for _,side in ipairs({-1,1}) do
		p("TowerSupport",V(1.2,11,1.2),CFrame.new(-218+side*9,5.5,461),wood,Enum.Material.Wood,true)
		beam("TowerRail",V(-218+side*9,14,445),V(-218+side*9,14,463),0.6,0.6,cream,Enum.Material.Wood,true)
	end
	beam("TowerRail",V(-227,14,463),V(-209,14,463),0.6,0.6,cream,Enum.Material.Wood,true)
	seat(-218,12,459,0)
	for i=1,8 do
		disk("ExplorerJump",V(-186+math.sin(i)*5,0.4+(i%3)*0.55,391+i*5),4.8,0.8,i%2==0 and gold or stone,Enum.Material.Slate,true)
	end
	-- Star garden surrounds a shallow reflecting pool; the telescope is a landmark.
	disk("StarPoolRim",V(205,0.25,480),27,0.5,cream,Enum.Material.Marble,true)
	local pool=disk("StarPoolWater",V(205,0.55,480),24,0.2,Color3.fromRGB(96,185,183),Enum.Material.Glass,false)
	pool.Transparency=0.28
	disk("ObservatoryDeck",V(215,0.5,442),24,1,wood,Enum.Material.WoodPlanks,true)
	for _,side in ipairs({-1,1}) do
		for _,depth in ipairs({-1,1}) do p("ObservatoryPillar",V(1,11,1),CFrame.new(215+side*8,6,442+depth*8),cream,Enum.Material.Marble,true) end
		p("ObservatoryRoof",V(12,0.8,23),CFrame.new(215+side*5,12.2,442)*CFrame.Angles(0,0,-side*0.35),Color3.fromRGB(77,100,143),Enum.Material.WoodPlanks,true)
	end
	p("TelescopeStand",V(1.2,4,1.2),CFrame.new(215,3,442),gold,Enum.Material.Metal,true)
	beam("TelescopeTube",V(215,4.5,444),V(215,7,437),2,2,Color3.fromRGB(65,96,127),Enum.Material.Metal,false)
	seat(203,1.3,460,math.pi/2); seat(228,1.3,463,-math.pi/2)
	for i=1,10 do
		local angle=i*math.pi*2/10
		local x,z=205+math.cos(angle)*20,480+math.sin(angle)*20
		p("StarFlowerStem",V(0.18,1.6,0.18),CFrame.new(x,0.8,z),leaf,Enum.Material.SmoothPlastic,false)
		p("StarFlower",V(1.1,0.25,1.1),CFrame.new(x,1.7,z)*CFrame.Angles(0,angle,0),i%2==0 and gold or cream,Enum.Material.SmoothPlastic,false)
	end
	for _,center in ipairs({{-204,426,52},{194,460,58},{0,556,77}}) do
		for i=0,7 do
			local a=i*math.pi/4
			-- The southern entrance stays open, so the bridge is visible.
			if i~=6 then tree(center[1]+math.cos(a)*center[3],center[2]+math.sin(a)*center[3],20+(i%3)*4,i%2==0 and leaf or Color3.fromRGB(119,158,82)) end
		end
		for i=1,3 do
			local a=i*1.7
			-- The west edge of the star island is the bridge landing.
			if not (center[1]==194 and i==2) then
				p("IslandOutcrop",V(7+i,3+i,5+i),CFrame.new(center[1]+math.cos(a)*(center[3]-7),1.5,center[2]+math.sin(a)*(center[3]-7))*CFrame.Angles(0,a,0.15),stone,Enum.Material.Rock,true)
			end
		end
	end
	for _,at in ipairs({{-57,580},{54,583},{-29,611},{30,611},{-226,414},{-181,453},{232,487},{180,490}}) do
		tree(at[1],at[2],17,Color3.fromRGB(101,145,79))
	end
	for _,at in ipairs({{-157,407},{144,453},{11,519},{-27,526},{27,526},{-12,584},{-200,441},{195,465}}) do
		local x,z=at[1],at[2]
		p("VillageLampFoot",V(2.5,0.7,2.5),CFrame.new(x,0.35,z),stone,Enum.Material.Cobblestone,true)
		p("VillageLampPost",V(0.5,7,0.5),CFrame.new(x,3.5,z),wood,Enum.Material.Wood,true)
		local lamp=p("VillageLantern",V(1.3,1.8,1.3),CFrame.new(x,7,z),Color3.fromRGB(255,217,144),Enum.Material.Neon,false)
		p("VillageLanternCap",V(1.8,0.35,1.8),CFrame.new(x,8,z),wood,Enum.Material.Wood,false)
		local light=Instance.new("PointLight"); light.Color=lamp.Color; light.Brightness=0.5; light.Range=10; light.Shadows=false; light.Parent=lamp
	end
	sign("ExplorerSign",V(-184,6,410),"ILHA DOS EXPLORADORES","EXPLORER ISLAND","SUBA • PULE • DESCUBRA","CLIMB • JUMP • EXPLORE",gold)
	sign("StarlightSign",V(177,6,437),"JARDIM DAS ESTRELAS","STARLIGHT GARDEN","UM CANTINHO PARA ENCONTRAR AMIGOS","A PLACE TO MEET FRIENDS",Color3.fromRGB(159,201,235))
	sign("WoodlandSign",V(0,8,535),"ALDEIA DO BOSQUE","WOODLAND VILLAGE","SUA AVENTURA CONTINUA AQUI","YOUR ADVENTURE CONTINUES HERE",Color3.fromRGB(176,216,134))
	sign("PlazaDirections",V(17,5,481),"PRAÇA E PORTAIS","PLAZA & PORTALS","VOLTE PELA TRILHA CENTRAL","FOLLOW THE CENTRAL TRAIL BACK",cream)
end

function World:ArtDirectLobby(lobby)
	local V=Vector3.new
	local art=Instance.new("Model")
	art.Name,art.Parent="CommandAtrium",lobby
	art:SetAttribute("ArtTheme","WoodlandOutpost")
	local stone=Color3.fromRGB(166,151,121)
	local mortar=Color3.fromRGB(99,101,82)
	local timber=Color3.fromRGB(98,64,43)
	local cream=Color3.fromRGB(246,225,178)
	local moss=Color3.fromRGB(78,118,65)
	local function piece(name,size,cf,tint,material)
		return artPart(art,name,size,cf,tint,material)
	end
	local function disk(name,at,diameter,thickness,tint,material)
		local p=piece(name,V(thickness,diameter,diameter),CFrame.new(at)*CFrame.Angles(0,0,math.pi/2),tint,material)
		p.Shape=Enum.PartType.Cylinder
		return p
	end
	-- The arrival square is a compact cobbled courtyard. Grass continues into
	-- it from the forest; paths connect actual doors rather than an empty grid.
	local deck=lobby:FindFirstChild("FlightDeck")
	if deck then deck.Color=Color3.fromRGB(98,139,77); deck.Material=Enum.Material.Grass end
	for _,child in ipairs(lobby:GetChildren()) do
		if child.Name=="DeckLine" or child.Name=="ChestShopPillar" or child.Name=="ChestShopPillarLight" then child:Destroy() end
	end
	disk("ArrivalCourt",V(0,0.04,345),57,0.12,mortar,Enum.Material.Cobblestone)
	disk("CourtInset",V(0,0.12,345),53,0.12,stone,Enum.Material.Cobblestone)
	local function walk(a,b,width)
		local distance=(b-a).Magnitude
		local cf=CFrame.lookAt((a+b)/2,b)
		piece("VillagePath",V(width,0.15,distance+1),cf,stone,Enum.Material.Cobblestone)
		for _,side in ipairs({-1,1}) do
			piece("PathBorder",V(0.5,0.22,distance+1),cf*CFrame.new(side*(width/2+0.2),0.04,0),mortar,Enum.Material.Slate)
		end
	end
	walk(V(0,0.11,320),V(0,0.11,402),12)
	walk(V(-78,0.11,352),V(67,0.11,352),11)
	walk(V(-66,0.11,307),V(-66,0.11,394),12)
	walk(V(43,0.11,326),V(43,0.11,385),13)
	walk(V(-54,0.11,314),V(54,0.11,314),13)
	for _,portalId in ipairs(self.catalog.DestinationOrder) do
		local destination=self.catalog.Destinations[portalId]
		local x=destination.x
		walk(V(x,0.12,destination.z),V(x,0.12,322),10)
	end
	walk(V(24,0.11,318),V(96,0.11,318),13)
	wallSign(lobby,"RankedQuarter",CFrame.new(58,24,278)*CFrame.Angles(0,math.pi,0),V(36,4,0.5),"ARENA COMPETITIVA","3 MAPAS • 3 ESTRATÉGIAS",ART.gold)
	-- Broken stone gatehouse behind the retained magic rings, with cloth
	-- pennants and masonry instead of a metal roof spanning the whole square.
	for _,x in ipairs({-61,-20,20,61}) do
		for level=0,3 do
			local p=piece("GatehouseStone",V(5.8-level*0.2,4.5,5),CFrame.new(x,2.25+level*4.4,282),stone:Lerp(mortar,level*0.08),Enum.Material.Cobblestone)
			p.CastShadow=true
		end
		piece("GatehouseCap",V(7,1.2,6.2),CFrame.new(x,18,282),cream,Enum.Material.Slate)
		piece("GatehouseBanner",V(2.8,8,0.18),CFrame.new(x,11.5,284.6),Color3.fromRGB(46,102,101),Enum.Material.Fabric)
		piece("BannerEmblem",V(1.3,1.3,0.12),CFrame.new(x,12,284.74)*CFrame.Angles(0,0,math.pi/4),ART.gold,Enum.Material.Metal)
		piece("MossCap",V(5.9,0.28,2),CFrame.new(x,18.75,280.6),moss,Enum.Material.Grass)
	end
	-- Small watch-house anchors the skyline; openings and roof overhangs give
	-- depth without needing a building the player must enter to use a menu.
	local bridge=lobby:FindFirstChild("Bridge")
	if bridge then bridge.Color=stone; bridge.Material=Enum.Material.Cobblestone end
	for _,side in ipairs({-1,1}) do
		piece("LodgeRoof",V(26,1.2,22),CFrame.new(side*11,10.2,265)*CFrame.Angles(0,0,-side*0.28),Color3.fromRGB(63,99,89),Enum.Material.WoodPlanks).CastShadow=true
		piece("LodgeWindow",V(7,3.8,0.25),CFrame.new(side*12,4.1,274.2),timber,Enum.Material.Wood)
		piece("LodgeWindowGlass",V(5.8,2.8,0.2),CFrame.new(side*12,4.1,274.4),Color3.fromRGB(219,164,89),Enum.Material.Glass)
		piece("LodgeWindowCross",V(0.24,3.1,0.2),CFrame.new(side*12,4.1,274.6),timber,Enum.Material.Wood)
	end
	-- An asymmetric stone fountain makes a landmark beside the main route.
	-- Solid footing and a low rim let avatars walk around it without snagging.
	local at=V(24,0,352)
	disk("FountainFoot",at+V(0,0.3,0),14,0.6,mortar,Enum.Material.Slate)
	disk("FountainBowl",at+V(0,0.8,0),12,0.7,stone,Enum.Material.Cobblestone)
	disk("FountainWater",at+V(0,1.2,0),10.5,0.15,Color3.fromRGB(76,165,163),Enum.Material.Glass).Transparency=0.18
	for i=0,11 do
		local a=i*math.pi/6
		piece("FountainRim",V(3,1,1.1),CFrame.new(at+V(math.sin(a)*5.8,1.2,math.cos(a)*5.8))*CFrame.Angles(0,a,0),cream,Enum.Material.Slate)
	end
	piece("FountainPillar",V(2,3.8,2),CFrame.new(at+V(0,2.4,0)),mortar,Enum.Material.Cobblestone)
	local crystal=piece("AuroraCrystal",V(1.7,2.7,1.7),CFrame.new(at+V(0,5.1,0))*CFrame.Angles(0,0,0.35),Color3.fromRGB(151,232,186),Enum.Material.Glass)
	crystal.Transparency=0.12
	disk("CrystalCollar",at+V(0,3.9,0),3,0.3,ART.gold,Enum.Material.Metal)
	-- Tailored canvas stalls: visible seams, scalloped valances, timber posts,
	-- crates and warm lamps. Open fronts preserve every existing shop trigger.
	local function stall(x,z,width,depth,tint,side)
		local cf=CFrame.new(x,0,z)*CFrame.Angles(0,side*math.pi/2,0)
		for _,sx in ipairs({-1,1}) do
			for _,sz in ipairs({-1,1}) do
				piece("MarketPost",V(0.65,10,0.65),cf*CFrame.new(sx*(width/2-0.6),5,sz*(depth/2-0.6)),timber,Enum.Material.Wood).CastShadow=true
				piece("PostFoot",V(1.2,0.8,1.2),cf*CFrame.new(sx*(width/2-0.6),0.4,sz*(depth/2-0.6)),stone,Enum.Material.Cobblestone)
			end
		end
		local strips=math.floor(width/2)
		for i=1,strips do
			local u=-width/2+(i-0.5)*width/strips
			local color=i%2==0 and cream or tint
			piece("CanvasAwning",V(width/strips+0.03,0.22,depth+2),cf*CFrame.new(u,10.7,0)*CFrame.Angles(0.12,0,0),color,Enum.Material.Fabric)
			piece("CanvasValance",V(width/strips,0.9,0.15),cf*CFrame.new(u,9.5,-depth/2-0.9),color,Enum.Material.Fabric)
		end
		piece("MarketRidge",V(width+1,0.35,0.35),cf*CFrame.new(0,11.1,0),timber,Enum.Material.Wood)
		for i=0,2 do
			local box=cf*CFrame.new(width/2+2,1+i*1.4,depth/2-1-i*0.4)
			piece("SupplyCrate",V(2.3,1.4,2),box,Color3.fromRGB(147,101,56),Enum.Material.WoodPlanks)
			piece("CrateStrap",V(0.2,1.45,2.05),box,Color3.fromRGB(80,76,63),Enum.Material.Metal)
		end
	end
	stall(59,338,17,13,Color3.fromRGB(183,115,57),-1)
	stall(59,374,17,13,Color3.fromRGB(87,127,96),-1)
	for _,z in ipairs({323,351,379}) do stall(-67,z,24,12,Color3.fromRGB(124,103,153),1) end
	-- Interior gardens bring foliage into the arrival view, rather than only
	-- outlining the edge of the island with identical spherical trees.
	local function garden(x,z,radius)
		disk("GardenBed",V(x,0.24,z),radius*2,0.45,mortar,Enum.Material.Cobblestone)
		disk("GardenSoil",V(x,0.5,z),radius*2-1,0.14,Color3.fromRGB(77,75,47),Enum.Material.Ground)
		for i=0,6 do
			local a=i*2.4
			local px,pz=x+math.cos(a)*radius*0.58,z+math.sin(a)*radius*0.58
			local bush=piece("GardenShrub",V(3.3,2.5+(i%2),3),CFrame.new(px,1.7,pz),Color3.fromRGB(69+i*3,115+i*5,69),Enum.Material.Grass)
			bush.Shape=Enum.PartType.Ball
			piece("GardenBlossom",V(0.65,0.3,0.65),CFrame.new(px,3.1+(i%2)*0.45,pz),i%2==0 and Color3.fromRGB(245,195,91) or Color3.fromRGB(229,161,168),Enum.Material.SmoothPlastic)
		end
	end
	for _,p in ipairs({{-29,337,6},{-29,366,6},{23,382,7},{-41,287,5},{41,287,5}}) do garden(p[1],p[2],p[3]) end
	local function oak(x,z)
		piece("PlazaTreeTrunk",V(2.5,12,2.5),CFrame.new(x,6,z)*CFrame.Angles(0,0,0.06),timber,Enum.Material.Wood).CastShadow=true
		for i=0,4 do
			local a=i*2.4
			local leaf=piece("PlazaTreeCrown",V(11,8,10),CFrame.new(x+math.cos(a)*3.5,12+i%2*3,z+math.sin(a)*3.5),Color3.fromRGB(85+i*5,131+i*5,66+i*3),Enum.Material.Grass)
			leaf.Shape=Enum.PartType.Ball
		end
	end
	oak(-29,337); oak(-29,366); oak(23,382)
	-- Two strings of cloth flags tie the market together. No large floating
	-- billboard blocks the forest skyline from the player's normal camera.
	for _,z in ipairs({330,391}) do
		for _,x in ipairs({-47,47}) do piece("FestivalPole",V(0.45,15,0.45),CFrame.new(x,7.5,z),timber,Enum.Material.Wood) end
		for i=0,15 do
			local x=-45+i*6
			local y=14.7-2.6*(1-(x/47)^2)
			piece("FestivalCord",V(6.15,0.08,0.08),CFrame.new(x,y,z),timber,Enum.Material.SmoothPlastic)
			piece("FestivalPennant",V(1.8,2.3,0.09),CFrame.new(x,y-1.2,z)*CFrame.Angles(0,0,i%2==0 and 0.08 or -0.08),i%3==0 and cream or i%3==1 and Color3.fromRGB(201,125,72) or Color3.fromRGB(68,124,114),Enum.Material.Fabric)
		end
	end
	for _,p in ipairs({{-18,327},{18,327},{-17,375},{16,397}}) do
		piece("VillageLampPost",V(0.45,7,0.45),CFrame.new(p[1],3.5,p[2]),timber,Enum.Material.Wood)
		piece("VillageLampRoof",V(1.6,0.25,1.6),CFrame.new(p[1],7.8,p[2]),timber,Enum.Material.Wood)
		local lamp=piece("VillageLampGlass",V(1,1.3,1),CFrame.new(p[1],7,p[2]),Color3.fromRGB(255,213,141),Enum.Material.Neon)
		local glow=Instance.new("PointLight")
		glow.Color,glow.Range,glow.Brightness,glow.Parent=Color3.fromRGB(255,217,159),13,0.65,lamp
	end
end


-- Authored service locations and finishing pass. Every new desk opens an
-- existing lobby screen; no progression or purchase is granted by scenery.
function World:FinishLobby(lobby)
	local V=Vector3.new
	local scene=Instance.new("Model")
	scene.Name,scene.Parent="VillageDetails",lobby
	local wood=Color3.fromRGB(104,72,46)
	local pale=Color3.fromRGB(231,213,173)
	local green=Color3.fromRGB(63,109,96)
	local stone=Color3.fromRGB(155,145,116)
	local function p(name,size,cf,color,material,solid)
		local obj=artPart(scene,name,size,cf,color,material)
		obj.CanCollide=solid==true
		return obj
	end
	local function localized(target,pt,en)
		target:SetAttribute("LobbyTextPT",pt)
		target:SetAttribute("LobbyTextEN",en)
	end
	local signs={
		CommandIdentity={"DOOMSDAY","DOOMSDAY","REFÚGIO DA AURORA","AURORA REFUGE"},
		ChestShopSign={"BAÚS","CHESTS","OURO","GOLD"},
		PremiumShopSign={"LOJA ROBUX","ROBUX SHOP","HERÓIS • PASSES • OURO","HEROES • PASSES • GOLD"},
		SanctuaryArchSign={"BOSQUE DA AURORA","AURORA WOODS","EXPLORE COM AMIGOS","EXPLORE WITH FRIENDS"},
		AuroraWelcome={"ÁRVORE DA AURORA","AURORA TREE","UM LUGAR PARA VOLTAR","A PLACE TO RETURN TO"},
		LookoutPlaque={"MIRANTE","LOOKOUT","CACHOEIRA DA AURORA","AURORA FALLS"},
		ForestDirections={"BOSQUE DA AURORA","AURORA WOODS","TRILHAS • MIRANTE","TRAILS • LOOKOUT"},
	}
	for _,obj in ipairs(lobby:GetDescendants()) do
		local texts=signs[obj.Name]
		if obj.Name=="ModeHeader" then
			local def=self.catalog.Modes[obj.Parent:GetAttribute("ModeId")]
			local map=self.catalog.Maps[obj.Parent:GetAttribute("MapId")]
			if def and map then texts={upper(map.name.pt),upper(map.name.en),upper(def.name.pt),upper(def.name.en)} end
		elseif obj.Name=="RankedQuarter" then
			texts={"ARENA COMPETITIVA","COMPETITIVE ARENA","3 MAPAS • 3 ESTRATÉGIAS","3 MAPS • 3 STRATEGIES"}
		elseif obj.Name=="ChestNameplate" then
			local base=obj.Parent:GetAttribute("ChestId")=="base_rare"
			texts={base and "BASES" or "HERÓIS",base and "BASES" or "HEROES","BAÚS A PARTIR DE 400 OURO","CHESTS FROM 400 GOLD"}
		end
		if texts then
			obj.Color,obj.Material=Color3.fromRGB(40,66,56),Enum.Material.WoodPlanks
			local surface=obj:FindFirstChild("Artwork")
			if surface then
				localized(surface:FindFirstChild("Title"),texts[1],texts[2])
				localized(surface:FindFirstChild("Subtitle"),texts[3],texts[4])
			end
		end
	end
	local services={
		{id="maps",x=-37,z=315,pt="ESCOLHER MAPA",en="CHOOSE MAP",color=Color3.fromRGB(238,190,88)},
		{id="guide",x=-13,z=360,pt="NICO • GUIA",en="NICO • GUIDE",color=Color3.fromRGB(238,190,88)},
		{id="inventory",x=-43,z=355,pt="SUA EQUIPE",en="YOUR TEAM",color=Color3.fromRGB(242,160,111)},
		{id="talents",x=-43,z=379,pt="ACADEMIA",en="ACADEMY",color=Color3.fromRGB(189,158,218)},
		{id="bases",x=67,z=355,pt="SUAS BASES",en="YOUR BASES",color=Color3.fromRGB(150,209,141)},
	}
	for _,def in ipairs(services) do
		local board,text=buildBoard(lobby,def.x,def.z,def.id,def.pt,self.openPanel)
		localized(text,def.pt.."\nTOQUE OU PRESSIONE E",def.en.."\nTAP OR PRESS E")
		local prompt=board.PrimaryPart:FindFirstChildOfClass("ProximityPrompt")
		if prompt then localized(prompt,def.pt,def.en) end
		p("ServiceDesk",V(8,2.4,3),CFrame.new(def.x,1.2,def.z),wood,Enum.Material.WoodPlanks,true)
		p("ServiceDeskTop",V(8.6,0.35,3.5),CFrame.new(def.x,2.6,def.z),pale,Enum.Material.WoodPlanks,true)
		p("ServiceDeskStripe",V(7.4,0.45,0.15),CFrame.new(def.x,1.8,def.z-1.6),def.color,Enum.Material.Fabric)
		for i=-1,1 do
			p("DeskBook",V(1.4,0.2,1.8),CFrame.new(def.x+i*1.6,2.9,def.z)*CFrame.Angles(0,i*0.12,0),i==0 and def.color or green,Enum.Material.SmoothPlastic)
		end
	end
	-- Notice boards face the arrival square and have real frames and feet.
	for _,model in ipairs(lobby:GetChildren()) do
		if model:GetAttribute("Kind")=="Board" then
			local board=model.PrimaryPart
			local oldPost=model:FindFirstChild("Post")
			if oldPost then oldPost:Destroy() end
			local point=board.Position
			local facing=CFrame.lookAt(V(point.X,5.4,point.Z),V(0,5.4,345))
			board.CFrame=facing
			board.Color,board.Material=Color3.fromRGB(40,66,56),Enum.Material.Wood
			for _,side in ipairs({-1,1}) do
				p("NoticeLeg",V(0.65,4,0.65),facing*CFrame.new(side*3.65,-3.4,0.45),wood,Enum.Material.Wood)
				p("NoticeFrame",V(0.35,5.7,0.65),facing*CFrame.new(side*4.25,0,0),wood,Enum.Material.Wood)
				p("NoticeFrame",V(8.8,0.35,0.65),facing*CFrame.new(0,side*2.7,0),pale,Enum.Material.Wood)
			end
			p("NoticeRoof",V(9.6,0.55,2.2),facing*CFrame.new(0,3,0)*CFrame.Angles(0.16,0,0),green,Enum.Material.WoodPlanks)
		end
	end
	-- Nico is an original little mechanical caretaker, not a hero exhibit.
	-- Its prompt is the guide desk's prompt; there is only one tap target.
	local origin=CFrame.new(-7,0,361)*CFrame.Angles(0,-0.2,0)
	p("GuideBoot",V(0.8,0.6,1.3),origin*CFrame.new(-0.5,0.4,0),wood,Enum.Material.Metal)
	p("GuideBoot",V(0.8,0.6,1.3),origin*CFrame.new(0.5,0.4,0),wood,Enum.Material.Metal)
	p("GuideBody",V(1.8,2,1.1),origin*CFrame.new(0,1.7,0),green,Enum.Material.Metal)
	p("GuideScarf",V(1.9,0.4,1.2),origin*CFrame.new(0,2.65,0),ART.gold,Enum.Material.Fabric)
	local head=p("GuideHead",V(2.1,1.5,1.5),origin*CFrame.new(0,3.5,0),pale,Enum.Material.Metal)
	head.Shape=Enum.PartType.Ball
	p("GuideVisor",V(1.5,0.65,0.15),origin*CFrame.new(0,3.55,-0.73),Color3.fromRGB(29,50,47),Enum.Material.Glass)
	for _,side in ipairs({-1,1}) do
		p("GuideEye",V(0.18,0.23,0.08),origin*CFrame.new(side*0.37,3.57,-0.85),Color3.fromRGB(158,237,197),Enum.Material.Neon)
		p("GuideArm",V(0.6,1.5,0.65),origin*CFrame.new(side*1.2,1.8,0)*CFrame.Angles(0,0,side*0.17),pale,Enum.Material.Metal)
	end
	p("GuideAntenna",V(0.13,0.8,0.13),origin*CFrame.new(0.7,4.5,0),wood,Enum.Material.Metal)
	local tip=p("GuideAntennaTip",V(0.35,0.35,0.35),origin*CFrame.new(0.7,4.95,0),ART.gold,Enum.Material.Neon)
	tip.Shape=Enum.PartType.Ball
	-- Beacon above the lodge is visible between the gates and from the forest.
	for _,x in ipairs({-4,4}) do
		for _,z in ipairs({262,270}) do
			p("BeaconColumn",V(1,17,1),CFrame.new(x,17,z),wood,Enum.Material.Wood).CastShadow=true
		end
	end
	for _,y in ipairs({13,21}) do
		p("BeaconDeck",V(11,0.7,11),CFrame.new(0,y,266),green,Enum.Material.WoodPlanks).CastShadow=true
	end
	for i=0,3 do
		local cf=CFrame.new(0,24.6,266)*CFrame.Angles(0,i*math.pi/2,0)
		p("BeaconWindow",V(6,6,0.16),cf*CFrame.new(0,0,-4),Color3.fromRGB(164,217,197),Enum.Material.Glass).Transparency=0.55
		p("BeaconRoof",V(12,0.7,7.3),CFrame.new(0,29.5,266)*CFrame.Angles(0,i*math.pi/2,0)*CFrame.new(0,0,-2.7)*CFrame.Angles(-0.45,0,0),green,Enum.Material.WoodPlanks).CastShadow=true
	end
	local crystal=p("BeaconCrystal",V(2.6,4,2.6),CFrame.new(0,24.6,266)*CFrame.Angles(0,0,0.4),Color3.fromRGB(255,219,135),Enum.Material.Neon)
	local light=Instance.new("PointLight")
	light.Color,light.Range,light.Brightness,light.Parent=ART.gold,24,0.8,crystal
	-- The square reads as one space; remove dark borders that crossed its
	-- centre like a giant grid, and keep a ring of individually laid stones.
	local art=lobby:FindFirstChild("CommandAtrium")
	for _,obj in ipairs(art and art:GetChildren() or {}) do
		if obj.Name=="PathBorder" then obj.Color=Color3.fromRGB(150,145,113); obj.Transparency=0.55 end
		if obj.Name=="CourtInset" then obj.Material=Enum.Material.Concrete; obj.Color=Color3.fromRGB(191,178,144) end
		if obj.Name=="VillagePath" then obj.Color=Color3.fromRGB(175,164,130) end
		if obj.Name=="FountainRim" or obj.Name=="FountainPillar" then obj.CanCollide=true end
	end
	for i=0,31 do
		local a=i*math.pi/16
		p("CourtyardPaver",V(4.4,0.18,1.8),CFrame.new(math.sin(a)*26,0.25,345+math.cos(a)*26)*CFrame.Angles(0,a,0),i%3==0 and pale or stone,Enum.Material.Slate)
	end
	-- Benches have real seats. Stay outside every interaction pad and path.
	for _,spot in ipairs({{-17,380},{36,369},{-36,326}}) do
		local cf=CFrame.new(spot[1],0,spot[2])
		local seat=Instance.new("Seat")
		seat.Name,seat.Size,seat.CFrame="VillageSeat",V(6,0.45,2),cf*CFrame.new(0,1.9,0)
		seat.Anchored,seat.Material,seat.Color,seat.Parent=true,Enum.Material.WoodPlanks,wood,scene
		p("BenchBack",V(6,1.8,0.4),cf*CFrame.new(0,3,1),wood,Enum.Material.WoodPlanks,true)
		for _,x in ipairs({-2,2}) do p("BenchLeg",V(0.5,1.7,1.8),cf*CFrame.new(x,0.85,0),stone,Enum.Material.Slate,true) end
	end
	-- Painted wooden counters replace the old metal display boxes underneath
	-- the awnings. Retain stand names and prompts for purchase validation.
	for _,model in ipairs(lobby:GetChildren()) do
		if model:GetAttribute("Kind")=="ShopStand" then
			for _,obj in ipairs(model:GetChildren()) do
				if obj.Name=="ShowcaseCanopy" or obj.Name=="ShowcasePillar" or obj.Name=="DisplayLight" then obj:Destroy()
				elseif obj.Name=="Stand" then obj.Color=wood; obj.Material=Enum.Material.WoodPlanks
				elseif obj.Name=="DisplayInset" then obj.Color=pale; obj.Material=Enum.Material.WoodPlanks end
			end
		end
	end
	-- Flower clusters and stones soften the grass/path junctions, deliberately
	-- avoiding the open plaza and the green chest pads.
	for _,spot in ipairs({{-35,344},{-35,370},{32,331},{34,382},{-16,398},{16,398},{77,329},{77,385}}) do
		for i=1,5 do
			local x,z=spot[1]+math.cos(i*2.4)*2,spot[2]+math.sin(i*2.4)*2
			p("FlowerStem",V(0.12,0.8,0.12),CFrame.new(x,0.6,z),green,Enum.Material.SmoothPlastic)
			for petal=0,3 do
				local a=petal*math.pi/2
				local leaf=p("FlowerPetal",V(0.5,0.15,0.35),CFrame.new(x+math.cos(a)*0.2,1,z+math.sin(a)*0.2)*CFrame.Angles(0,-a,0),i%2==0 and Color3.fromRGB(239,168,139) or pale,Enum.Material.SmoothPlastic)
				leaf.Shape=Enum.PartType.Ball
			end
			p("FlowerCenter",V(0.16,0.12,0.16),CFrame.new(x,1.1,z),ART.gold,Enum.Material.SmoothPlastic)
		end
	end
end


local OCEAN_Y = -134

function World:DressLobby(lobby)
	workspace.Terrain:FillBlock(CFrame.new(0, OCEAN_Y, 320), Vector3.new(1400, 12, 1400), Enum.Material.Water)
end

-- Called on a slow server timer with the top rows for a representative
-- board; the totem is shared scenery, so it shows one public leaderboard
-- rather than trying to be personal to whoever is looking at it.
function World:UpdateLeaderboardBoard(rows, mapName)
	if not self.leaderboardText then return end
	local lines = { "SALÃO DA FAMA", upper(mapName or "MANHATTAN") .. " • SOLO" }
	for index, row in ipairs(rows or {}) do
		if index > 5 then break end
		table.insert(lines, string.format("#%d  %s — %d", row.rank, row.name or tostring(row.userId), row.waves))
	end
	if #(rows or {}) == 0 then table.insert(lines, "Seja o primeiro a deixar sua marca.") end
	self.leaderboardText.Text = table.concat(lines, "\n")
end

--==============================================================================
-- Streets and city: the map is a place, not a board
--==============================================================================
-- Every route is a real street — asphalt with a dashed centre line, raised
-- curbs and sidewalks that meet cleanly at every corner and junction — and a
-- city closes in around the playfield: a continuous wall of buildings with lit
-- windows and storefronts, parked cars, trees, lamps and chapter props, over
-- native Roblox terrain. Two rules keep it honest with the gameplay:
--   * nothing solid stands where a tower may be built (world_boot.spec checks
--     every part against the real build rule, below);
--   * street furniture on a sidewalk is "clutter", and building a tower over
--     it clears it away (World:MakeTower).
-- Native materials, terrain and built-in effects only: no textures, meshes,
-- decals or audio.
local BUILD_LIMIT = 106 -- MatchService._validBuild
local ROAD_HALF = 6 -- Config.PathHalfWidth
local CLEARANCE = 9 -- Config.PathHalfWidth + Config.TowerRadius
local WALK = 3 -- sidewalk beyond the curb
local EDGE = 118 -- inner face of the city wall
local BOUND = 115 -- invisible limit for walking commanders
local EXTENSION = 36 -- a street runs on past its enemy portal, out of the city
local GROUND_REACH = 176 -- terrain half-extent, past the backs of the buildings
local RING = 110 -- centre line of the boulevard around the district
local RING_HALF = 3
local CURBSIDE = 115.5 -- trees and street props along the boulevard's far sidewalk
World.StreetRules = { BUILD_LIMIT = BUILD_LIMIT, CLEARANCE = CLEARANCE, EDGE = EDGE, BOUND = BOUND }

local STREET_THEME = {
	manhattan = {
		ground = { Enum.Material.Pavement, Color3.fromRGB(84, 88, 94) },
		patches = { { Enum.Material.LeafyGrass, Color3.fromRGB(58, 86, 50) }, { Enum.Material.Concrete, Color3.fromRGB(98, 100, 104) } },
		road = { Enum.Material.Asphalt, Color3.fromRGB(38, 40, 45) },
		walk = { Enum.Material.Pavement, Color3.fromRGB(116, 118, 122) },
		curb = { Enum.Material.Concrete, Color3.fromRGB(150, 150, 146) },
		marking = Color3.fromRGB(232, 196, 76),
		lamp = "street", lampColor = Color3.fromRGB(255, 196, 132), poleColor = Color3.fromRGB(36, 42, 48),
		facade = "city",
		bodies = {
			{ Enum.Material.Brick, Color3.fromRGB(122, 64, 50) }, { Enum.Material.Concrete, Color3.fromRGB(146, 138, 122) },
			{ Enum.Material.Brick, Color3.fromRGB(92, 66, 58) }, { Enum.Material.Slate, Color3.fromRGB(66, 70, 78) },
			{ Enum.Material.Limestone, Color3.fromRGB(168, 158, 138) },
		},
		glass = Color3.fromRGB(36, 52, 72), lit = Color3.fromRGB(255, 206, 138),
		signs = { Color3.fromRGB(64, 224, 208), Color3.fromRGB(255, 72, 150), Color3.fromRGB(255, 176, 60), Color3.fromRGB(235, 60, 60) },
		heights = { 26, 86 },
		outer = { "car", "car", "car", "tree", "tree", "wreck", "fireBarrel" }, fires = 3,
		sidewalk = { "hydrant", "bench", "bin", "hydrant", "bin" },
		clouds = { cover = 0.6, density = 0.32, color = Color3.fromRGB(92, 104, 132) },
	},
	gamma = {
		ground = { Enum.Material.Ground, Color3.fromRGB(74, 70, 56) },
		patches = { { Enum.Material.Mud, Color3.fromRGB(60, 66, 46) }, { Enum.Material.Concrete, Color3.fromRGB(112, 116, 108) } },
		road = { Enum.Material.Concrete, Color3.fromRGB(96, 100, 96) },
		walk = { Enum.Material.Pavement, Color3.fromRGB(132, 134, 124) },
		curb = { Enum.Material.Metal, Color3.fromRGB(214, 178, 48) },
		marking = Color3.fromRGB(120, 230, 90),
		lamp = "lab", lampColor = Color3.fromRGB(150, 255, 140), poleColor = Color3.fromRGB(60, 66, 62),
		facade = "lab",
		bodies = {
			{ Enum.Material.Concrete, Color3.fromRGB(176, 180, 172) }, { Enum.Material.Concrete, Color3.fromRGB(150, 156, 150) },
			{ Enum.Material.Metal, Color3.fromRGB(120, 128, 124) },
		},
		glass = Color3.fromRGB(38, 70, 64), lit = Color3.fromRGB(150, 255, 170), accent = Color3.fromRGB(110, 235, 90),
		heights = { 18, 44 },
		outer = { "barrel", "barrel", "fence", "deadTree", "crate", "wreck" }, fires = 1,
		sidewalk = { "hazard", "barrel", "hazard" },
		water = Color3.fromRGB(70, 190, 80),
		clouds = { cover = 0.5, density = 0.45, color = Color3.fromRGB(140, 170, 120) },
	},
	hydra = {
		ground = { Enum.Material.Concrete, Color3.fromRGB(98, 100, 104) },
		patches = { { Enum.Material.Asphalt, Color3.fromRGB(70, 72, 76) }, { Enum.Material.Slate, Color3.fromRGB(80, 82, 86) } },
		road = { Enum.Material.DiamondPlate, Color3.fromRGB(46, 48, 54) },
		walk = { Enum.Material.Concrete, Color3.fromRGB(92, 94, 98) },
		curb = { Enum.Material.Metal, Color3.fromRGB(170, 44, 40) },
		marking = Color3.fromRGB(230, 230, 230),
		lamp = "flood", lampColor = Color3.fromRGB(255, 120, 100), poleColor = Color3.fromRGB(46, 48, 52),
		facade = "industrial",
		bodies = {
			{ Enum.Material.CorrodedMetal, Color3.fromRGB(78, 76, 72) }, { Enum.Material.Metal, Color3.fromRGB(64, 68, 74) },
			{ Enum.Material.DiamondPlate, Color3.fromRGB(70, 72, 76) },
		},
		glass = Color3.fromRGB(30, 30, 34), lit = Color3.fromRGB(255, 110, 90), accent = Color3.fromRGB(214, 60, 52),
		heights = { 22, 52 },
		outer = { "container", "container", "crate", "crate", "wreck" }, fires = 2,
		sidewalk = { "barrier", "crate", "barrier" },
		clouds = { cover = 0.75, density = 0.5, color = Color3.fromRGB(70, 72, 78) },
	},
	wakanda = {
		ground = { Enum.Material.Grass, Color3.fromRGB(92, 116, 60) },
		patches = { { Enum.Material.Sand, Color3.fromRGB(196, 160, 110) }, { Enum.Material.LeafyGrass, Color3.fromRGB(80, 110, 54) } },
		road = { Enum.Material.Sandstone, Color3.fromRGB(176, 136, 96) },
		walk = { Enum.Material.Ground, Color3.fromRGB(128, 100, 72) },
		curb = { Enum.Material.Marble, Color3.fromRGB(214, 200, 176) },
		marking = nil,
		lamp = "crystal", lampColor = Color3.fromRGB(196, 130, 255), poleColor = Color3.fromRGB(214, 176, 96),
		facade = "wakanda",
		bodies = {
			{ Enum.Material.Marble, Color3.fromRGB(214, 196, 168) }, { Enum.Material.Foil, Color3.fromRGB(70, 60, 92) },
			{ Enum.Material.Sandstone, Color3.fromRGB(186, 150, 108) },
		},
		glass = Color3.fromRGB(60, 44, 90), lit = Color3.fromRGB(214, 160, 255), accent = Color3.fromRGB(236, 190, 90),
		heights = { 24, 70 },
		outer = { "acacia", "acacia", "acacia", "rock", "rock" },
		sidewalk = { "planter", "planter" },
		clouds = { cover = 0.45, density = 0.25, color = Color3.fromRGB(236, 196, 170) },
	},
	latveria = {
		ground = { Enum.Material.Snow, Color3.fromRGB(206, 214, 226) },
		patches = { { Enum.Material.Rock, Color3.fromRGB(96, 100, 108) }, { Enum.Material.Slate, Color3.fromRGB(88, 92, 100) } },
		road = { Enum.Material.Cobblestone, Color3.fromRGB(86, 88, 96) },
		walk = { Enum.Material.Slate, Color3.fromRGB(104, 108, 116) },
		curb = { Enum.Material.Granite, Color3.fromRGB(130, 134, 140) },
		marking = nil,
		lamp = "brazier", lampColor = Color3.fromRGB(120, 255, 170), poleColor = Color3.fromRGB(70, 74, 80),
		facade = "castle",
		bodies = {
			{ Enum.Material.Slate, Color3.fromRGB(70, 74, 82) }, { Enum.Material.Cobblestone, Color3.fromRGB(84, 88, 94) },
		},
		glass = Color3.fromRGB(20, 30, 30), lit = Color3.fromRGB(110, 255, 170), accent = Color3.fromRGB(40, 110, 70),
		heights = { 22, 30 },
		outer = { "pine", "pine", "pine", "rock", "statue" }, rock = Enum.Material.Basalt,
		sidewalk = { "brazierSmall", "pine" },
		clouds = { cover = 0.8, density = 0.55, color = Color3.fromRGB(120, 130, 160) },
	},
}

-- Parts of the city are scenery: shadows only where they add depth, and never
STREET_THEME.asgard = {
	ground={Enum.Material.Marble,Color3.fromRGB(210,197,167)},
	patches={{Enum.Material.Sandstone,Color3.fromRGB(191,172,133)},{Enum.Material.Marble,Color3.fromRGB(237,219,184)}},
	road={Enum.Material.Marble,Color3.fromRGB(196,158,74)},
	walk={Enum.Material.Sandstone,Color3.fromRGB(224,208,176)},
	curb={Enum.Material.Metal,Color3.fromRGB(243,199,93)},
	lamp="crystal",lampColor=Color3.fromRGB(153,226,246),poleColor=Color3.fromRGB(212,172,74),
	facade="castle",bodies={{Enum.Material.Marble,Color3.fromRGB(233,214,168)},{Enum.Material.Sandstone,Color3.fromRGB(194,160,96)}},
	glass=Color3.fromRGB(60,121,151),lit=Color3.fromRGB(147,224,255),accent=Color3.fromRGB(239,190,67),
	heights={24,45},outer={"pine","rock","statue"},rock=Enum.Material.Marble,
	sidewalk={"planter","brazierSmall"},clouds={cover=0.3,density=0.2,color=Color3.fromRGB(246,222,192)},
}

-- Parts of the city are scenery: shadows only where they add depth, and never
-- in the way of a raycast from the placement cursor or the tower picker.
local function prop(parent, name, size, cf, color, material)
	local p = part(parent, name, size, cf, color, material)
	p.CanQuery, p.CanTouch = false, false
	return p
end

local function upright(cf) return cf * CFrame.Angles(0, 0, math.pi / 2) end

local function distanceToSegment(px, pz, ax, az, bx, bz)
	local dx, dz = bx - ax, bz - az
	local lengthSq = dx * dx + dz * dz
	local t = lengthSq > 0 and math.clamp(((px - ax) * dx + (pz - az) * dz) / lengthSq, 0, 1) or 0
	local qx, qz = ax + dx * t - px, az + dz * t - pz
	return math.sqrt(qx * qx + qz * qz)
end

-- The real build rule, asked the other way round: could a circle of this
-- radius at (x, z) cover any spot where a tower is allowed to stand?
function World.CoversBuildArea(map, x, z, radius)
	radius = radius or 0
	if math.abs(x) - radius > BUILD_LIMIT or math.abs(z) - radius > BUILD_LIMIT then return false end
	for _, route in ipairs(map.paths) do
		for i = 1, #route - 1 do
			if distanceToSegment(x, z, route[i][1], route[i][2], route[i + 1][1], route[i + 1][2]) + radius < CLEARANCE then
				return false
			end
		end
	end
	return true
end

-- One street per distinct stretch: routes that share a stretch share one
-- street. Each enemy entrance on the map's edge also gets a street running on
-- out of the city, so the horde visibly comes from somewhere.
local function streetsOf(map)
	local streets, seen = {}, {}
	local function add(ax, az, bx, bz, routeIndex, gameplay)
		local key = string.format("%.1f,%.1f,%.1f,%.1f", ax, az, bx, bz)
		local back = string.format("%.1f,%.1f,%.1f,%.1f", bx, bz, ax, az)
		if seen[key] or seen[back] then return end
		seen[key] = true
		local alongX = math.abs(az - bz) < 1e-6
		table.insert(streets, {
			ax = ax, az = az, bx = bx, bz = bz, route = routeIndex, gameplay = gameplay, half = ROAD_HALF,
			alongX = alongX, aligned = alongX or math.abs(ax - bx) < 1e-6,
			lo = alongX and math.min(ax, bx) or math.min(az, bz),
			hi = alongX and math.max(ax, bx) or math.max(az, bz),
			cross = alongX and az or ax,
		})
	end
	for index, route in ipairs(map.paths) do
		for i = 1, #route - 1 do add(route[i][1], route[i][2], route[i + 1][1], route[i + 1][2], index, true) end
		local first, second = route[1], route[2]
		if math.max(math.abs(first[1]), math.abs(first[2])) >= 88 then
			local dx, dz = first[1] - second[1], first[2] - second[2]
			local length = math.sqrt(dx * dx + dz * dz)
			add(first[1], first[2], first[1] + dx / length * EXTENSION, first[2] + dz / length * EXTENSION, index, false)
		end
	end
	-- The boulevard around the district, outside the build area on every
	-- side: where the parked cars are, and what the entrance streets cross on
	-- their way out of the city.
	for _, ring in ipairs({ { false, -RING }, { false, RING }, { true, -RING }, { true, RING } }) do
		table.insert(streets, {
			alongX = ring[1], aligned = true, ring = true, gameplay = false, half = RING_HALF,
			lo = -RING, hi = RING, cross = ring[2], outward = ring[2] > 0 and 1 or -1,
		})
	end
	return streets
end

local function streetXZ(s, along, offset)
	if s.alongX then return along, s.cross + offset end
	return s.cross + offset, along
end

-- Strictly inside a street's asphalt rectangle grown by `margin` all round.
local function insideStreet(s, x, z, margin)
	local reach = s.half + (margin or 0)
	local along, across = s.alongX and x or z, s.alongX and z or x
	return along > s.lo - reach and along < s.hi + reach and across > s.cross - reach and across < s.cross + reach
end

-- A box in street coordinates: [a0, a1] along the street, [c0, c1] across it
-- (offsets from the centre line), [y0, y1] up.
local function streetBox(parent, name, s, a0, a1, c0, c1, y0, y1, surface)
	local x, z = streetXZ(s, (a0 + a1) / 2, (c0 + c1) / 2)
	local size = s.alongX and Vector3.new(a1 - a0, y1 - y0, c1 - c0) or Vector3.new(c1 - c0, y1 - y0, a1 - a0)
	local p = part(parent, name, size, CFrame.new(x, (y0 + y1) / 2, z), surface[2], surface[1])
	p.CanTouch = false
	return p
end

-- Remove every (from, to) range from a list of intervals.
local function subtract(intervals, from, to)
	local out = {}
	for _, range in ipairs(intervals) do
		if to <= range[1] or from >= range[2] then
			table.insert(out, range)
		else
			if from > range[1] then table.insert(out, { range[1], from }) end
			if to < range[2] then table.insert(out, { to, range[2] }) end
		end
	end
	return out
end

-- A curb line runs the street's length plus a corner's worth at each end, then
-- loses every stretch that falls inside another street's asphalt: what is left
-- is exactly the outline of the road network, corners and junctions included.
function World.CurbRuns(streets, s, side)
	local line = s.cross + side * s.half
	local runs = { { s.lo - s.half, s.hi + s.half } }
	for _, o in ipairs(streets) do
		if o ~= s and o.aligned then
			if o.alongX ~= s.alongX then
				if line > o.lo - o.half and line < o.hi + o.half then
					runs = subtract(runs, o.cross - o.half, o.cross + o.half)
				end
			elseif line > o.cross - o.half and line < o.cross + o.half then
				runs = subtract(runs, o.lo - o.half, o.hi + o.half)
			end
		end
	end
	return runs, line
end

local function buildBoulevard(self, theme, streets)
	for _, s in ipairs(streets) do
		if not s.ring then continue end
		local road = streetBox(self.Scenery, "Boulevard", s, s.lo - s.half, s.hi + s.half, -s.half, s.half, -0.05, 0.24, theme.road)
		road.CanQuery = false
		local near, far = s.half, s.half + (EDGE - RING - s.half)
		local walk = streetBox(self.Scenery, "BoulevardWalk", s, s.lo - far, s.hi + far, math.min(near * s.outward, far * s.outward), math.max(near * s.outward, far * s.outward), -0.1, 0.2, theme.walk)
		walk.CanQuery = false
		for _, run in ipairs((World.CurbRuns(streets, s, s.outward))) do
			if run[2] - run[1] > 0.3 then
				local inner, outer = s.outward * s.half, s.outward * (s.half + 0.5)
				streetBox(self.Scenery, "Curb", s, run[1], run[2], math.min(inner, outer), math.max(inner, outer), 0, 0.45, theme.curb).CanQuery = false
			end
		end
	end
end

local function buildStreets(self, map, theme, streets)
	buildBoulevard(self, theme, streets)
	for _, s in ipairs(streets) do
		if s.ring then continue end
		if not s.aligned then
			-- Diagonal stretches are not used by any map today; they still render
			-- as a plain street rather than failing.
			local a, b = Vector3.new(s.ax, 0.1, s.az), Vector3.new(s.bx, 0.1, s.bz)
			local length = (b - a).Magnitude
			part(self.Paths, s.gameplay and ("Route" .. s.route) or "Street", Vector3.new(ROAD_HALF * 2, 0.3, length + ROAD_HALF * 2), CFrame.lookAt((a + b) / 2, b), theme.road[2], theme.road[1])
			continue
		end
		local walk = streetBox(self.Paths, "Sidewalk", s, s.lo - ROAD_HALF - WALK, s.hi + ROAD_HALF + WALK, -(ROAD_HALF + WALK), ROAD_HALF + WALK, -0.1, 0.2, theme.walk)
		walk.CanQuery = true
		local road = streetBox(self.Paths, s.gameplay and ("Route" .. s.route) or "Street", s, s.lo - ROAD_HALF, s.hi + ROAD_HALF, -ROAD_HALF, ROAD_HALF, -0.05, 0.25, theme.road)
		road:SetAttribute("Gameplay", s.gameplay)
	end
	for _, s in ipairs(streets) do
		if s.ring or not s.aligned then continue end
		for _, side in ipairs({ -1, 1 }) do
			local runs = World.CurbRuns(streets, s, side)
			for _, run in ipairs(runs) do
				if run[2] - run[1] > 0.3 then
					local inner, outer = side * ROAD_HALF, side * (ROAD_HALF + 0.5)
					streetBox(self.Paths, "Curb", s, run[1], run[2], math.min(inner, outer), math.max(inner, outer), 0, 0.45, theme.curb)
				end
			end
		end
		-- The centre line: dashes that stop short of every junction.
		if theme.marking then
			for along = s.lo + 9, s.hi - 9, 7 do
				local x, z = streetXZ(s, along, 0)
				local clear = true
				for _, o in ipairs(streets) do
					if o ~= s and insideStreet(o, x, z, 1) then clear = false break end
				end
				if clear then
					local size = s.alongX and Vector3.new(3, 0.04, 0.35) or Vector3.new(0.35, 0.04, 3)
					local dash = prop(self.Paths, "LaneMark", size, CFrame.new(x, 0.27, z), theme.marking, Enum.Material.SmoothPlastic)
					dash.CanCollide = false
				end
			end
		end
		-- Manhole covers, off the centre line.
		if s.gameplay then
			for along = s.lo + 14, s.hi - 10, 38 do
				local x, z = streetXZ(s, along, 3)
				local cover = prop(self.Paths, "Manhole", Vector3.new(0.06, 1.8, 1.8), upright(CFrame.new(x, 0.26, z)), Color3.fromRGB(34, 34, 36), Enum.Material.DiamondPlate)
				cover.Shape, cover.CanCollide = Enum.PartType.Cylinder, false
			end
		end
	end
	-- A zebra crossing in front of the core, where the last street arrives.
	local route = map.paths[1]
	local last, before = route[#route], route[#route - 1]
	local dx, dz = last[1] - before[1], last[2] - before[2]
	local length = math.sqrt(dx * dx + dz * dz)
	if length >= 30 and (dx == 0 or dz == 0) then
		local ux, uz = dx / length, dz / length
		local cx, cz = last[1] - ux * 17, last[2] - uz * 17
		for offset = -4.5, 4.5, 1.8 do
			local x, z = cx + uz * offset, cz + ux * offset
			local size = dz == 0 and Vector3.new(3.2, 0.04, 1) or Vector3.new(1, 0.04, 3.2)
			local stripe = prop(self.Paths, "Crosswalk", size, CFrame.new(x, 0.27, z), Color3.fromRGB(226, 226, 220), Enum.Material.SmoothPlastic)
			stripe.CanCollide = false
		end
	end
end

--==============================================================================
-- Street furniture ("clutter"): lamps and small props on the sidewalks
--==============================================================================
local function clutterModel(self, name, x, z, radius)
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("ClutterX", x)
	model:SetAttribute("ClutterZ", z)
	model:SetAttribute("ClutterRadius", radius)
	model.Parent = self.Clutter
	return model
end

local LAMP_LIGHT_BUDGET = 22

local function buildLamp(self, theme, x, z, faceX, faceZ, withLight)
	local model = clutterModel(self, "Lamp", x, z, 0.7)
	local base = CFrame.new(x, 0, z)
	local head
	if theme.lamp == "street" or theme.lamp == "flood" then
		local tall = theme.lamp == "flood" and 12 or 10
		prop(model, "LampPole", Vector3.new(tall, 0.42, 0.42), upright(base * CFrame.new(0, tall / 2, 0)), theme.poleColor, Enum.Material.Metal).Shape = Enum.PartType.Cylinder
		prop(model, "LampFoot", Vector3.new(0.9, 0.5, 0.9), base * CFrame.new(0, 0.25, 0), theme.poleColor, Enum.Material.Metal)
		local reach = base * CFrame.new(0, tall, 0)
		local arm = CFrame.lookAt(reach.Position, reach.Position + Vector3.new(faceX, 0, faceZ))
		prop(model, "LampArm", Vector3.new(0.22, 0.22, 2.4), arm * CFrame.new(0, 0, -1.1), theme.poleColor, Enum.Material.Metal)
		head = prop(model, "LampHead", theme.lamp == "flood" and Vector3.new(1.6, 0.7, 1.1) or Vector3.new(0.9, 0.3, 1.5), arm * CFrame.new(0, -0.2, -2.2), theme.lampColor, Enum.Material.Neon)
	elseif theme.lamp == "lab" then
		prop(model, "LampPole", Vector3.new(0.7, 1.6, 0.7), base * CFrame.new(0, 0.8, 0), theme.poleColor, Enum.Material.Metal)
		head = prop(model, "LampHead", Vector3.new(0.8, 0.35, 0.8), base * CFrame.new(0, 1.75, 0), theme.lampColor, Enum.Material.Neon)
	elseif theme.lamp == "crystal" then
		prop(model, "LampPole", Vector3.new(7, 0.36, 0.36), upright(base * CFrame.new(0, 3.5, 0)), theme.poleColor, Enum.Material.Foil).Shape = Enum.PartType.Cylinder
		head = prop(model, "LampHead", Vector3.new(0.9, 1.6, 0.9), base * CFrame.new(0, 7.6, 0) * CFrame.Angles(0, math.pi / 4, 0), theme.lampColor, Enum.Material.Neon)
		prop(model, "LampCrown", Vector3.new(0.3, 1.4, 1.4), upright(base * CFrame.new(0, 6.8, 0)), theme.poleColor, Enum.Material.Foil).Shape = Enum.PartType.Cylinder
	else -- brazier
		prop(model, "LampPole", Vector3.new(1.1, 3, 1.1), base * CFrame.new(0, 1.5, 0), theme.poleColor, Enum.Material.Slate)
		local bowl = prop(model, "LampBowl", Vector3.new(0.7, 2, 2), upright(base * CFrame.new(0, 3.2, 0)), Color3.fromRGB(46, 48, 52), Enum.Material.Metal)
		bowl.Shape = Enum.PartType.Cylinder
		head = prop(model, "LampHead", Vector3.new(1.3, 0.5, 1.3), base * CFrame.new(0, 3.6, 0), theme.lampColor, Enum.Material.Neon)
	end
	if withLight and head then
		local light = Instance.new("PointLight")
		light.Color, light.Range, light.Brightness, light.Shadows = theme.lampColor, theme.lamp == "lab" and 12 or 20, 1.3, false
		light.Parent = head
	end
	return model
end

local SIDEWALK_PROPS = {}
function SIDEWALK_PROPS.hydrant(model, x, z)
	local base = CFrame.new(x, 0, z)
	prop(model, "Hydrant", Vector3.new(1.2, 0.7, 0.7), upright(base * CFrame.new(0, 0.6, 0)), Color3.fromRGB(196, 40, 36), Enum.Material.Metal).Shape = Enum.PartType.Cylinder
	prop(model, "HydrantCap", Vector3.new(0.6, 0.6, 0.6), base * CFrame.new(0, 1.3, 0), Color3.fromRGB(210, 190, 60), Enum.Material.Metal).Shape = Enum.PartType.Ball
end
function SIDEWALK_PROPS.bench(model, x, z, faceX, faceZ)
	local cf = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x + faceX, 0, z + faceZ))
	prop(model, "BenchSeat", Vector3.new(3.2, 0.25, 1), cf * CFrame.new(0, 0.9, 0), Color3.fromRGB(110, 76, 48), Enum.Material.WoodPlanks)
	prop(model, "BenchBack", Vector3.new(3.2, 0.9, 0.2), cf * CFrame.new(0, 1.4, 0.45), Color3.fromRGB(110, 76, 48), Enum.Material.WoodPlanks)
	for _, side in ipairs({ -1.3, 1.3 }) do prop(model, "BenchLeg", Vector3.new(0.2, 0.8, 0.9), cf * CFrame.new(side, 0.4, 0), Color3.fromRGB(40, 44, 48), Enum.Material.Metal) end
end
function SIDEWALK_PROPS.bin(model, x, z)
	prop(model, "Bin", Vector3.new(1.3, 0.9, 0.9), upright(CFrame.new(x, 0.65, z)), Color3.fromRGB(46, 70, 56), Enum.Material.Metal).Shape = Enum.PartType.Cylinder
end
function SIDEWALK_PROPS.hazard(model, x, z)
	prop(model, "HazardPost", Vector3.new(0.5, 1.4, 0.5), CFrame.new(x, 0.7, z), Color3.fromRGB(230, 190, 40), Enum.Material.Metal)
	prop(model, "HazardBand", Vector3.new(0.55, 0.25, 0.55), CFrame.new(x, 1.1, z), Color3.fromRGB(24, 24, 24), Enum.Material.SmoothPlastic)
end
function SIDEWALK_PROPS.barrel(model, x, z)
	prop(model, "Barrel", Vector3.new(1.8, 1.3, 1.3), upright(CFrame.new(x, 0.9, z)), Color3.fromRGB(200, 170, 40), Enum.Material.Metal).Shape = Enum.PartType.Cylinder
	local lid = prop(model, "BarrelGlow", Vector3.new(0.08, 1.1, 1.1), upright(CFrame.new(x, 1.84, z)), Color3.fromRGB(110, 240, 90), Enum.Material.Neon)
	lid.Shape = Enum.PartType.Cylinder
end
function SIDEWALK_PROPS.barrier(model, x, z, faceX, faceZ)
	local cf = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x + faceX, 0, z + faceZ))
	prop(model, "Barrier", Vector3.new(3, 1.1, 0.8), cf * CFrame.new(0, 0.55, 0), Color3.fromRGB(150, 150, 146), Enum.Material.Concrete)
	prop(model, "BarrierStripe", Vector3.new(3.02, 0.25, 0.82), cf * CFrame.new(0, 0.8, 0), Color3.fromRGB(190, 50, 44), Enum.Material.SmoothPlastic)
end
function SIDEWALK_PROPS.crate(model, x, z)
	prop(model, "Crate", Vector3.new(1.6, 1.6, 1.6), CFrame.new(x, 0.8, z) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(120, 92, 60), Enum.Material.WoodPlanks)
end
function SIDEWALK_PROPS.planter(model, x, z)
	prop(model, "Planter", Vector3.new(1.6, 0.8, 1.6), CFrame.new(x, 0.4, z), Color3.fromRGB(200, 186, 160), Enum.Material.Marble)
	prop(model, "Shrub", Vector3.new(1.7, 1.7, 1.7), CFrame.new(x, 1.3, z), Color3.fromRGB(70, 110, 50), Enum.Material.LeafyGrass).Shape = Enum.PartType.Ball
end
function SIDEWALK_PROPS.brazierSmall(model, x, z)
	prop(model, "Post", Vector3.new(0.8, 1.6, 0.8), CFrame.new(x, 0.8, z), Color3.fromRGB(70, 74, 80), Enum.Material.Slate)
	prop(model, "Ember", Vector3.new(0.9, 0.3, 0.9), CFrame.new(x, 1.75, z), Color3.fromRGB(110, 255, 170), Enum.Material.Neon)
end
function SIDEWALK_PROPS.pine(model, x, z)
	prop(model, "Trunk", Vector3.new(1.2, 0.5, 0.5), upright(CFrame.new(x, 0.6, z)), Color3.fromRGB(70, 50, 36), Enum.Material.Wood).Shape = Enum.PartType.Cylinder
	for tier, width in ipairs({ 1.8, 1.3, 0.8 }) do
		prop(model, "Needles", Vector3.new(0.7, width, width), upright(CFrame.new(x, 0.9 + tier * 0.6, z)), Color3.fromRGB(40, 70, 52), Enum.Material.Grass).Shape = Enum.PartType.Cylinder
	end
end

local function buildSidewalks(self, map, theme, streets, rng)
	local lamps, placed = 0, {}
	local function free(x, z, gap)
		for _, spot in ipairs(placed) do
			if (spot[1] - x) ^ 2 + (spot[2] - z) ^ 2 < gap * gap then return false end
		end
		return true
	end
	local function onOtherStreet(s, x, z)
		for _, o in ipairs(streets) do
			if o ~= s and insideStreet(o, x, z, WALK + 0.5) then return true end
		end
		return false
	end
	local function nearLandmark(x, z)
		for _, route in ipairs(map.paths) do
			local first, last = route[1], route[#route]
			if (first[1] - x) ^ 2 + (first[2] - z) ^ 2 < 12 ^ 2 then return true end
			if (last[1] - x) ^ 2 + (last[2] - z) ^ 2 < 13 ^ 2 then return true end
		end
		return false
	end
	local side = 1
	for _, s in ipairs(streets) do
		if s.ring or not s.aligned then continue end
		for along = s.lo + 12, s.hi - 6, 22 do
			side = -side
			local x, z = streetXZ(s, along, side * 7.6)
			if not onOtherStreet(s, x, z) and not nearLandmark(x, z) and not World.CoversBuildArea(map, x, z, 0.7) and free(x, z, 6) then
				local fx, fz = streetXZ(s, along, 0)
				lamps += 1
				buildLamp(self, theme, x, z, fx - x, fz - z, lamps <= LAMP_LIGHT_BUDGET)
				table.insert(placed, { x, z })
			end
		end
	end
	-- Small furniture between the lamps, only along the playable streets.
	local kinds = theme.sidewalk or {}
	if #kinds == 0 then return end
	for _, s in ipairs(streets) do
		if not (s.aligned and s.gameplay) then continue end
		for along = s.lo + 7, s.hi - 7, 13 do
			if rng:NextNumber() > 0.55 then continue end
			local sideHere = rng:NextNumber() < 0.5 and -1 or 1
			local x, z = streetXZ(s, along, sideHere * 7.4)
			if not onOtherStreet(s, x, z) and not nearLandmark(x, z) and not World.CoversBuildArea(map, x, z, 1.1) and free(x, z, 4) then
				local kind = kinds[rng:NextInteger(1, #kinds)]
				local model = clutterModel(self, "Furniture", x, z, 1.1)
				local fx, fz = streetXZ(s, along, 0)
				SIDEWALK_PROPS[kind](model, x, z, fx - x, fz - z)
				table.insert(placed, { x, z })
			end
		end
	end
end

--==============================================================================
-- Outer ring: cars, trees and chapter props between the playfield and the wall
--==============================================================================
local OUTER_PROPS = {}
local CAR_COLORS = {
	Color3.fromRGB(230, 184, 40), Color3.fromRGB(230, 184, 40), Color3.fromRGB(150, 32, 36), Color3.fromRGB(40, 66, 110),
	Color3.fromRGB(190, 192, 196), Color3.fromRGB(28, 30, 34), Color3.fromRGB(70, 96, 70),
}
local function car(folder, cf, color, wrecked)
	local body = wrecked and color:Lerp(Color3.fromRGB(40, 36, 32), 0.6) or color
	local material = wrecked and Enum.Material.CorrodedMetal or Enum.Material.Metal
	local chassis = prop(folder, "CarBody", Vector3.new(4.2, 1.3, 8.8), cf * CFrame.new(0, 1.05, 0), body, material)
	chassis.CastShadow = true
	prop(folder, "CarCabin", Vector3.new(3.7, 1.2, 4.4), cf * CFrame.new(0, 2.3, 0.4), wrecked and Color3.fromRGB(20, 20, 22) or Color3.fromRGB(34, 46, 60), Enum.Material.Glass)
	prop(folder, "CarRoof", Vector3.new(3.6, 0.2, 3.8), cf * CFrame.new(0, 3, 0.4), body, material)
	for _, wx in ipairs({ -2.05, 2.05 }) do
		for _, wz in ipairs({ -2.8, 2.8 }) do
			prop(folder, "Wheel", Vector3.new(0.7, 1.7, 1.7), cf * CFrame.new(wx, 0.85, wz), Color3.fromRGB(22, 22, 24), Enum.Material.SmoothPlastic).Shape = Enum.PartType.Cylinder
		end
	end
	if not wrecked then
		for _, lx in ipairs({ -1.4, 1.4 }) do
			prop(folder, "Headlight", Vector3.new(0.8, 0.35, 0.1), cf * CFrame.new(lx, 1.3, -4.42), Color3.fromRGB(255, 244, 214), Enum.Material.Neon)
			prop(folder, "Taillight", Vector3.new(0.8, 0.3, 0.1), cf * CFrame.new(lx, 1.3, 4.42), Color3.fromRGB(220, 30, 30), Enum.Material.Neon)
		end
	end
	return chassis
end
function OUTER_PROPS.car(ctx, x, z, yaw)
	car(ctx.folder, CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0), CAR_COLORS[ctx.rng:NextInteger(1, #CAR_COLORS)], false)
	return 4.6
end
function OUTER_PROPS.wreck(ctx, x, z, yaw)
	local chassis = car(ctx.folder, CFrame.new(x, 0.2, z) * CFrame.Angles(0.05, yaw + ctx.rng:NextNumber(-0.25, 0.25), 0.1), CAR_COLORS[ctx.rng:NextInteger(1, #CAR_COLORS)], true)
	if ctx.fires > 0 then
		ctx.fires -= 1
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat, fire.Color, fire.SecondaryColor = 6, 9, Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 200, 80)
		fire.Parent = chassis
		local smoke = Instance.new("Smoke")
		smoke.Color, smoke.Opacity, smoke.RiseVelocity, smoke.Size = Color3.fromRGB(40, 40, 44), 0.18, 6, 5
		smoke.Parent = chassis
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness = Color3.fromRGB(255, 140, 60), 16, 1.6
		glow.Parent = chassis
	end
	return 4.6
end
function OUTER_PROPS.fireBarrel(ctx, x, z)
	local barrel = prop(ctx.folder, "FireBarrel", Vector3.new(2, 1.4, 1.4), upright(CFrame.new(x, 1, z)), Color3.fromRGB(70, 54, 40), Enum.Material.CorrodedMetal)
	barrel.Shape = Enum.PartType.Cylinder
	if ctx.fires > 0 then
		ctx.fires -= 1
		local fire = Instance.new("Fire")
		fire.Size, fire.Heat = 3, 6
		fire.Parent = barrel
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness = Color3.fromRGB(255, 150, 70), 12, 1.4
		glow.Parent = barrel
	end
	return 1.2
end
function OUTER_PROPS.tree(ctx, x, z)
	local folder, rng = ctx.folder, ctx.rng
	prop(folder, "Planter", Vector3.new(3.6, 0.9, 3.6), CFrame.new(x, 0.45, z), Color3.fromRGB(120, 118, 112), Enum.Material.Concrete)
	prop(folder, "Trunk", Vector3.new(6, 0.8, 0.8), upright(CFrame.new(x, 3.4, z)), Color3.fromRGB(78, 56, 40), Enum.Material.Wood).Shape = Enum.PartType.Cylinder
	for i = 1, 3 do
		local size = rng:NextNumber(3.6, 5.2)
		local leaf = prop(folder, "Leaves", Vector3.new(size, size, size), CFrame.new(x + rng:NextNumber(-1.1, 1.1), 6.6 + i * 0.7, z + rng:NextNumber(-1.1, 1.1)), Color3.fromRGB(56, 92, 48):Lerp(Color3.fromRGB(90, 120, 60), rng:NextNumber()), Enum.Material.LeafyGrass)
		leaf.Shape, leaf.CastShadow = Enum.PartType.Ball, true
	end
	return 2.6
end
function OUTER_PROPS.deadTree(ctx, x, z)
	local folder, rng = ctx.folder, ctx.rng
	prop(folder, "Trunk", Vector3.new(7, 0.9, 0.9), upright(CFrame.new(x, 3.5, z)), Color3.fromRGB(58, 50, 42), Enum.Material.Wood).Shape = Enum.PartType.Cylinder
	for i = 1, 3 do
		prop(folder, "Branch", Vector3.new(0.35, 0.35, 3.4), CFrame.new(x, 4 + i * 1.1, z) * CFrame.Angles(0.6, rng:NextNumber(0, math.pi * 2), 0) * CFrame.new(0, 0, -1.5), Color3.fromRGB(58, 50, 42), Enum.Material.Wood)
	end
	return 2
end
function OUTER_PROPS.acacia(ctx, x, z)
	local folder, rng = ctx.folder, ctx.rng
	local lean = rng:NextNumber(-0.08, 0.08)
	prop(folder, "Trunk", Vector3.new(8, 0.9, 0.9), upright(CFrame.new(x, 4, z) * CFrame.Angles(lean, 0, 0)), Color3.fromRGB(96, 70, 48), Enum.Material.Wood).Shape = Enum.PartType.Cylinder
	local crown = prop(folder, "Canopy", Vector3.new(1.4, 10, 10), upright(CFrame.new(x, 8.2, z)), Color3.fromRGB(88, 118, 52), Enum.Material.LeafyGrass)
	crown.Shape, crown.CastShadow = Enum.PartType.Cylinder, true
	prop(folder, "Canopy", Vector3.new(1, 6.5, 6.5), upright(CFrame.new(x + rng:NextNumber(-1, 1), 9.2, z + rng:NextNumber(-1, 1))), Color3.fromRGB(100, 130, 60), Enum.Material.LeafyGrass).Shape = Enum.PartType.Cylinder
	return 4.8
end
function OUTER_PROPS.pine(ctx, x, z)
	local folder, rng = ctx.folder, ctx.rng
	local scale = rng:NextNumber(0.85, 1.3)
	prop(folder, "Trunk", Vector3.new(3 * scale, 0.9, 0.9), upright(CFrame.new(x, 1.5 * scale, z)), Color3.fromRGB(66, 48, 36), Enum.Material.Wood).Shape = Enum.PartType.Cylinder
	for tier, width in ipairs({ 7, 5.4, 3.8, 2.6 }) do
		local y = (1.6 + tier * 2) * scale
		local needles = prop(folder, "Needles", Vector3.new(2 * scale, width * scale, width * scale), upright(CFrame.new(x, y, z)), Color3.fromRGB(38, 66, 50), Enum.Material.Grass)
		needles.Shape, needles.CastShadow = Enum.PartType.Cylinder, true
		prop(folder, "SnowCap", Vector3.new(0.35, width * scale * 0.8, width * scale * 0.8), upright(CFrame.new(x, y + 1.2 * scale, z)), Color3.fromRGB(230, 236, 244), Enum.Material.Snow).Shape = Enum.PartType.Cylinder
	end
	return 3.6 * scale
end
function OUTER_PROPS.rock(ctx, x, z)
	local radius = ctx.rng:NextNumber(2, 4)
	workspace.Terrain:FillBall(Vector3.new(x, 0, z), radius, ctx.rockMaterial or Enum.Material.Rock)
	return radius
end
function OUTER_PROPS.barrel(ctx, x, z)
	for i = 0, 2 do
		local bx, bz = x + (i - 1) * 2.1, z + (i % 2) * 1.2
		SIDEWALK_PROPS.barrel(ctx.folder, bx, bz)
	end
	return 3.4
end
function OUTER_PROPS.crate(ctx, x, z)
	local rng = ctx.rng
	for i = 1, 3 do
		local size = rng:NextNumber(2.4, 3.4)
		prop(ctx.folder, "Crate", Vector3.new(size, size, size), CFrame.new(x + rng:NextNumber(-1.4, 1.4), size / 2 + (i == 3 and 2.6 or 0), z + rng:NextNumber(-1.4, 1.4)) * CFrame.Angles(0, rng:NextNumber(0, 1.5), 0), Color3.fromRGB(118, 90, 58), Enum.Material.WoodPlanks)
	end
	return 3.4
end
function OUTER_PROPS.container(ctx, x, z, yaw)
	local colors = { Color3.fromRGB(150, 50, 40), Color3.fromRGB(40, 84, 130), Color3.fromRGB(60, 110, 70), Color3.fromRGB(190, 110, 40) }
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local stack = ctx.rng:NextInteger(1, 2)
	for level = 1, stack do
		local color = colors[ctx.rng:NextInteger(1, #colors)]
		local box = prop(ctx.folder, "Container", Vector3.new(6.4, 6.6, 12), cf * CFrame.new(0, 3.3 + (level - 1) * 6.7, 0), color, Enum.Material.Metal)
		box.CastShadow = true
		for rib = -4.5, 4.5, 3 do
			prop(ctx.folder, "ContainerRib", Vector3.new(6.6, 6.2, 0.35), cf * CFrame.new(0, 3.3 + (level - 1) * 6.7, rib), color:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Metal)
		end
	end
	return 6.4
end
function OUTER_PROPS.fence(ctx, x, z, yaw)
	local cf = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	for post = -6, 6, 4 do prop(ctx.folder, "FencePost", Vector3.new(0.3, 4, 0.3), cf * CFrame.new(0, 2, post), Color3.fromRGB(120, 124, 120), Enum.Material.Metal) end
	local mesh = prop(ctx.folder, "FenceMesh", Vector3.new(0.1, 3.6, 12), cf * CFrame.new(0, 2.1, 0), Color3.fromRGB(150, 156, 150), Enum.Material.DiamondPlate)
	mesh.Transparency = 0.55
	return 6.2
end
function OUTER_PROPS.statue(ctx, x, z)
	-- A generic armoured sentinel: stone, faceless, no licensed likeness.
	local stone, dark = Color3.fromRGB(110, 116, 122), Color3.fromRGB(64, 70, 76)
	prop(ctx.folder, "StatuePlinth", Vector3.new(4, 2, 4), CFrame.new(x, 1, z), dark, Enum.Material.Slate)
	prop(ctx.folder, "StatueBody", Vector3.new(2.4, 4, 1.6), CFrame.new(x, 4, z), stone, Enum.Material.Granite).CastShadow = true
	prop(ctx.folder, "StatueHead", Vector3.new(1.4, 1.5, 1.4), CFrame.new(x, 6.8, z), stone, Enum.Material.Granite)
	prop(ctx.folder, "StatueCape", Vector3.new(3, 5, 0.3), CFrame.new(x, 4, z + 0.9), Color3.fromRGB(40, 90, 60), Enum.Material.Fabric)
	prop(ctx.folder, "StatueEyes", Vector3.new(0.9, 0.2, 0.1), CFrame.new(x, 6.9, z - 0.72), Color3.fromRGB(110, 255, 170), Enum.Material.Neon)
	return 2.4
end

local function buildOuterRing(self, map, theme, streets, rng)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "Outskirts", self.Scenery
	local ctx = { folder = folder, rng = rng, fires = theme.fires or 0, rockMaterial = theme.rock or Enum.Material.Rock }
	local kinds = theme.outer
	local exits = {}
	for _, s in ipairs(streets) do
		if not s.gameplay and not s.ring then table.insert(exits, s) end
	end
	local function blockedByExit(x, z, radius)
		for _, s in ipairs(exits) do
			if insideStreet(s, x, z, WALK + radius + 1) then return true end
		end
		return false
	end
	local ON_ROAD = { car = true, wreck = true, container = true, fence = true, barrel = true, crate = true, fireBarrel = true }
	for _, sideInfo in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local nx, nz = sideInfo[1], sideInfo[2]
		local along = -100 + rng:NextNumber(0, 8)
		while along < 100 do
			local kind = kinds[rng:NextInteger(1, #kinds)]
			-- Vehicles park toward the far side of the boulevard, clear of the field.
			local ring = ON_ROAD[kind] and RING + 0.8 or CURBSIDE
			local x, z = nx ~= 0 and nx * ring or along, nz ~= 0 and nz * ring or along
			local yaw = nx ~= 0 and 0 or math.pi / 2
			if not blockedByExit(x, z, 5) then
				local radius = OUTER_PROPS[kind](ctx, x, z, yaw)
				along += (radius or 3) * 2 + rng:NextNumber(3, 10)
			else
				along += 6
			end
		end
	end
	for _, corner in ipairs({ { 1, 1 }, { 1, -1 }, { -1, 1 }, { -1, -1 } }) do
		local kind = kinds[rng:NextInteger(1, #kinds)]
		if kind == "car" or kind == "wreck" or kind == "container" or kind == "fence" then kind = kinds[#kinds] end
		OUTER_PROPS[kind](ctx, corner[1] * CURBSIDE, corner[2] * CURBSIDE, 0)
	end
	-- The walls commanders cannot walk through: the city is the edge of the map.
	for _, wall in ipairs({ { BOUND + 1, 0, 2, 320 }, { -BOUND - 1, 0, 2, 320 }, { 0, BOUND + 1, 320, 2 }, { 0, -BOUND - 1, 320, 2 } }) do
		local barrier = part(self.Scenery, "CityLimit", Vector3.new(wall[3], 60, wall[4]), CFrame.new(wall[1], 30, wall[2]), Color3.new(0, 0, 0))
		barrier.Transparency, barrier.CanQuery, barrier.CanTouch = 1, false, false
	end
end

--==============================================================================
-- The city wall: buildings with a face toward the battlefield
--==============================================================================
local FACADES = {}

-- `face` sits at the bottom centre of the building's inner face, looking into
-- the map; the body extends behind it (+Z in face space).
local function body(folder, theme, rng, face, width, height, depth)
	local look = theme.bodies[rng:NextInteger(1, #theme.bodies)]
	local block = prop(folder, "Skyline", Vector3.new(width, height, depth), face * CFrame.new(0, height / 2, depth / 2), look[2], look[1])
	block.CastShadow, block.CanCollide = true, true
	return block, look
end

local function roofline(folder, face, width, height, depth, color, material)
	prop(folder, "Cornice", Vector3.new(width + 0.6, 0.9, depth + 0.6), face * CFrame.new(0, height + 0.45, depth / 2), color, material)
end

function FACADES.city(folder, theme, rng, face, width, height, depth)
	local _, look = body(folder, theme, rng, face, width, height, depth)
	local trim = look[2]:Lerp(Color3.fromRGB(220, 214, 200), 0.25)
	-- Street level: a lit shopfront, an awning, sometimes a neon sign.
	local shop = prop(folder, "Storefront", Vector3.new(width - 2, 4.6, 0.3), face * CFrame.new(0, 2.8, -0.1), theme.glass:Lerp(theme.lit, 0.45), Enum.Material.Glass)
	shop.Transparency = 0.1
	prop(folder, "Awning", Vector3.new(width - 2.6, 0.25, 2.6), face * CFrame.new(0, 5.6, -1.3) * CFrame.Angles(-0.28, 0, 0), theme.signs[rng:NextInteger(1, #theme.signs)]:Lerp(Color3.fromRGB(30, 30, 30), 0.35), Enum.Material.Fabric)
	if rng:NextNumber() < 0.65 then
		prop(folder, "ShopSign", Vector3.new(math.min(width * 0.55, 9), 1, 0.3), face * CFrame.new(0, 6.7, -0.25), theme.signs[rng:NextInteger(1, #theme.signs)], Enum.Material.Neon)
	end
	-- Floors: a dark glass band each, a few windows lit behind it, piers
	-- between the bays so the facade reads as a grid of windows.
	for y = 9.5, height - 3.5, 4.5 do
		prop(folder, "WindowBand", Vector3.new(width - 2.2, 2.2, 0.2), face * CFrame.new(0, y, -0.08), theme.glass, Enum.Material.Glass)
		if rng:NextNumber() < 0.55 then
			local slots = math.max(1, math.floor((width - 3) / 3.2))
			for _ = 1, rng:NextInteger(1, math.min(3, slots)) do
				local slot = rng:NextInteger(0, slots - 1)
				local lateral = -width / 2 + 2.6 + slot * 3.2
				prop(folder, "LitWindow", Vector3.new(2.2, 1.8, 0.25), face * CFrame.new(lateral, y, -0.12), theme.lit:Lerp(Color3.fromRGB(60, 50, 40), rng:NextNumber(0, 0.45)), Enum.Material.Neon)
			end
		end
	end
	local piers = math.max(1, math.floor(width / 7))
	for i = 1, piers do
		local lateral = -width / 2 + i * width / (piers + 1)
		prop(folder, "Pier", Vector3.new(0.8, height - 8, 0.5), face * CFrame.new(lateral, 8 + (height - 8) / 2, -0.2), trim, look[1])
	end
	roofline(folder, face, width, height, depth, trim, look[1])
	local roll = rng:NextNumber()
	if roll < 0.35 then
		-- The rooftop water tank, on legs.
		local top = face * CFrame.new(rng:NextNumber(-width / 4, width / 4), height + 0.9, depth / 2)
		for _, leg in ipairs({ { -1.2, -1.2 }, { 1.2, -1.2 }, { -1.2, 1.2 }, { 1.2, 1.2 } }) do
			prop(folder, "TankLeg", Vector3.new(0.3, 2.4, 0.3), top * CFrame.new(leg[1], 1.2, leg[2]), Color3.fromRGB(40, 40, 42), Enum.Material.Metal)
		end
		prop(folder, "WaterTank", Vector3.new(4, 3.6, 3.6), upright(top * CFrame.new(0, 4.4, 0)), Color3.fromRGB(104, 76, 54), Enum.Material.WoodPlanks).Shape = Enum.PartType.Cylinder
	elseif roll < 0.7 then
		prop(folder, "RoofUnit", Vector3.new(3, 1.6, 2.4), face * CFrame.new(rng:NextNumber(-width / 4, width / 4), height + 1.7, depth / 2 + rng:NextNumber(-3, 3)), Color3.fromRGB(120, 124, 128), Enum.Material.Metal)
	end
	if height > 60 then
		prop(folder, "Antenna", Vector3.new(0.3, 8, 0.3), face * CFrame.new(0, height + 4.9, depth / 2), Color3.fromRGB(60, 62, 66), Enum.Material.Metal)
		prop(folder, "Beacon", Vector3.new(0.6, 0.6, 0.6), face * CFrame.new(0, height + 9, depth / 2), Color3.fromRGB(255, 40, 40), Enum.Material.Neon)
	end
end

function FACADES.lab(folder, theme, rng, face, width, height, depth)
	local _, look = body(folder, theme, rng, face, width, height, depth)
	prop(folder, "HazardBand", Vector3.new(width, 0.8, 0.3), face * CFrame.new(0, 0.4, -0.1), Color3.fromRGB(214, 178, 48), Enum.Material.SmoothPlastic)
	prop(folder, "LabStripe", Vector3.new(width, 0.5, 0.3), face * CFrame.new(0, 4.2, -0.1), theme.accent, Enum.Material.Neon)
	local door = prop(folder, "Airlock", Vector3.new(math.min(6, width - 4), 3.4, 0.3), face * CFrame.new(0, 1.9, -0.1), Color3.fromRGB(60, 64, 62), Enum.Material.DiamondPlate)
	door.CanCollide = false
	for y = 7.5, height - 3, 5 do
		prop(folder, "WindowBand", Vector3.new(width - 3, 1.6, 0.2), face * CFrame.new(0, y, -0.08), theme.glass, Enum.Material.Glass)
		if rng:NextNumber() < 0.4 then
			prop(folder, "LitWindow", Vector3.new(math.min(6, width - 4), 1.3, 0.25), face * CFrame.new(rng:NextNumber(-width / 4, width / 4), y, -0.12), theme.lit:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0.2, 0.5)), Enum.Material.Neon)
		end
	end
	-- A cylinder's axis is its X, which in face space runs along the facade.
	prop(folder, "Pipe", Vector3.new(width, 0.9, 0.9), face * CFrame.new(0, height * 0.55, -0.6), Color3.fromRGB(150, 156, 150), Enum.Material.Metal).Shape = Enum.PartType.Cylinder
	roofline(folder, face, width, height, depth, look[2]:Lerp(Color3.new(1, 1, 1), 0.1), look[1])
	for _ = 1, rng:NextInteger(1, 2) do
		local vent = prop(folder, "RoofVent", Vector3.new(2.4, 2.2, 2.2), upright(face * CFrame.new(rng:NextNumber(-width / 3, width / 3), height + 2.1, depth / 2 + rng:NextNumber(-3, 3))), Color3.fromRGB(110, 116, 112), Enum.Material.Metal)
		vent.Shape = Enum.PartType.Cylinder
	end
	if rng:NextNumber() < 0.3 then
		-- A cooling tower behind the block, venting a slow green haze.
		local tower = prop(folder, "CoolingTower", Vector3.new(height + 16, 22, 22), upright(face * CFrame.new(0, (height + 16) / 2, depth + 12)), Color3.fromRGB(160, 164, 158), Enum.Material.Concrete)
		tower.Shape, tower.CastShadow = Enum.PartType.Cylinder, true
		prop(folder, "CoolingGlow", Vector3.new(0.6, 20, 20), upright(face * CFrame.new(0, height + 16.1, depth + 12)), theme.accent, Enum.Material.Neon).Shape = Enum.PartType.Cylinder
	end
end

function FACADES.industrial(folder, theme, rng, face, width, height, depth)
	local _, look = body(folder, theme, rng, face, width, height, depth)
	local rib = look[2]:Lerp(Color3.new(0, 0, 0), 0.25)
	for lateral = -width / 2 + 1.5, width / 2 - 1.5, 3.5 do
		prop(folder, "Rib", Vector3.new(0.6, height, 0.5), face * CFrame.new(lateral, height / 2, -0.2), rib, Enum.Material.Metal)
	end
	local doorWidth = math.min(width - 4, 10)
	prop(folder, "HangarDoor", Vector3.new(doorWidth, math.min(9, height - 6), 0.4), face * CFrame.new(0, math.min(9, height - 6) / 2, -0.4), Color3.fromRGB(58, 60, 64), Enum.Material.DiamondPlate)
	prop(folder, "DoorStripe", Vector3.new(doorWidth, 0.6, 0.45), face * CFrame.new(0, 0.3, -0.45), theme.accent, Enum.Material.SmoothPlastic)
	prop(folder, "WindowBand", Vector3.new(width - 2, 1.2, 0.3), face * CFrame.new(0, height - 3, -0.3), theme.glass:Lerp(theme.lit, 0.25), Enum.Material.Neon)
	roofline(folder, face, width, height, depth, rib, Enum.Material.Metal)
	prop(folder, "Beacon", Vector3.new(0.8, 0.8, 0.8), face * CFrame.new(width / 2 - 1, height + 1.3, -0.2), theme.accent, Enum.Material.Neon)
	if rng:NextNumber() < 0.35 then
		prop(folder, "Banner", Vector3.new(3.4, 8, 0.2), face * CFrame.new(rng:NextNumber(-width / 3, width / 3), height - 7, -0.6), theme.accent:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.Fabric)
	end
	if rng:NextNumber() < 0.3 then
		prop(folder, "Chimney", Vector3.new(16, 3, 3), upright(face * CFrame.new(width / 3, height + 8, depth / 2)), rib, Enum.Material.CorrodedMetal).Shape = Enum.PartType.Cylinder
	end
end

function FACADES.wakanda(folder, theme, rng, face, width, height, depth)
	local look = theme.bodies[rng:NextInteger(1, #theme.bodies)]
	if rng:NextNumber() < 0.5 then
		-- A round tower with vibranium rings and a gold crown.
		local diameter = math.min(width, depth) + 2
		local tower = prop(folder, "Skyline", Vector3.new(height, diameter, diameter), upright(face * CFrame.new(0, height / 2, diameter / 2)), look[2], look[1])
		tower.Shape, tower.CastShadow, tower.CanCollide = Enum.PartType.Cylinder, true, true
		for _, ratio in ipairs({ 0.3, 0.62, 0.9 }) do
			prop(folder, "VibraniumRing", Vector3.new(0.7, diameter + 0.8, diameter + 0.8), upright(face * CFrame.new(0, height * ratio, diameter / 2)), theme.lit, Enum.Material.Neon).Shape = Enum.PartType.Cylinder
		end
		prop(folder, "GoldCrown", Vector3.new(3, diameter * 0.55, diameter * 0.55), upright(face * CFrame.new(0, height + 1.5, diameter / 2)), theme.accent, Enum.Material.Foil).Shape = Enum.PartType.Cylinder
		-- A block behind the tower keeps the wall closed.
		local block = prop(folder, "Skyline", Vector3.new(width, height * 0.45, depth), face * CFrame.new(0, height * 0.225, depth / 2 + 4), look[2]:Lerp(Color3.new(0, 0, 0), 0.2), look[1])
		block.CastShadow, block.CanCollide = true, true
		return
	end
	local block = prop(folder, "Skyline", Vector3.new(width, height, depth), face * CFrame.new(0, height / 2, depth / 2), look[2], look[1])
	block.CastShadow, block.CanCollide = true, true
	-- Woven bands of colour, echoing textile patterns, and a terraced top.
	for y = 4, height - 6, 7 do
		prop(folder, "PatternBand", Vector3.new(width, 1.1, 0.3), face * CFrame.new(0, y, -0.1), rng:NextNumber() < 0.5 and theme.accent or Color3.fromRGB(150, 60, 50), Enum.Material.Fabric)
		prop(folder, "WindowBand", Vector3.new(width - 3, 2, 0.2), face * CFrame.new(0, y + 3, -0.08), theme.glass:Lerp(theme.lit, rng:NextNumber(0, 0.6)), Enum.Material.Glass)
	end
	-- A WedgePart's slope faces its front (-Z), which here is the battlefield:
	-- the roof steps down toward the player.
	local terrace = Instance.new("WedgePart")
	terrace.Name, terrace.Size = "Terrace", Vector3.new(width, 6, depth * 0.6)
	terrace.CFrame = face * CFrame.new(0, height + 3, depth * 0.3)
	terrace.Color, terrace.Material, terrace.Anchored = look[2]:Lerp(Color3.new(1, 1, 1), 0.1), look[1], true
	terrace.CanQuery, terrace.CanTouch, terrace.CastShadow = false, false, true
	terrace.Parent = folder
	prop(folder, "Garden", Vector3.new(width - 2, 0.6, depth * 0.35), face * CFrame.new(0, height + 0.3, depth * 0.8), Color3.fromRGB(80, 116, 54), Enum.Material.LeafyGrass)
end

function FACADES.castle(folder, theme, rng, face, width, height, depth)
	local block, look = body(folder, theme, rng, face, width, height, depth)
	block.Name = "Skyline"
	-- Battlements along the top.
	for lateral = -width / 2 + 1.5, width / 2 - 1.5, 5 do
		prop(folder, "Merlon", Vector3.new(2.6, 2.6, 2.6), face * CFrame.new(lateral, height + 1.3, 1.3), look[2], look[1])
	end
	prop(folder, "Walkway", Vector3.new(width, 0.6, 3.2), face * CFrame.new(0, height - 0.3, -1.6), look[2]:Lerp(Color3.new(0, 0, 0), 0.2), look[1])
	for lateral = -width / 2 + 3, width / 2 - 3, 6 do
		if rng:NextNumber() < 0.5 then
			prop(folder, "ArrowSlit", Vector3.new(0.6, 2.6, 0.2), face * CFrame.new(lateral, height * 0.6, -0.1), rng:NextNumber() < 0.5 and theme.lit or Color3.fromRGB(12, 14, 16), rng:NextNumber() < 0.5 and Enum.Material.Neon or Enum.Material.SmoothPlastic)
		end
	end
	if rng:NextNumber() < 0.45 then
		prop(folder, "Banner", Vector3.new(3, 9, 0.2), face * CFrame.new(rng:NextNumber(-width / 4, width / 4), height - 6, -0.3), theme.accent, Enum.Material.Fabric)
	end
	if rng:NextNumber() < 0.4 then
		-- A round tower rising above the wall, with a stepped slate roof.
		-- It stands 2.5 studs proud of the wall, so it reads from the field.
		local diameter = 11
		local towerHeight = height + 14
		local center = diameter / 2 - 2.5
		local tower = prop(folder, "Skyline", Vector3.new(towerHeight, diameter, diameter), upright(face * CFrame.new(0, towerHeight / 2, center)), look[2], look[1])
		tower.Shape, tower.CastShadow, tower.CanCollide = Enum.PartType.Cylinder, true, true
		for step, ratio in ipairs({ 1.15, 0.8, 0.45 }) do
			prop(folder, "TowerRoof", Vector3.new(2.6, diameter * ratio, diameter * ratio), upright(face * CFrame.new(0, towerHeight + step * 2.4 - 1, center)), Color3.fromRGB(44, 52, 60), Enum.Material.Slate).Shape = Enum.PartType.Cylinder
		end
		prop(folder, "TowerWindow", Vector3.new(1.4, 2.4, 0.3), face * CFrame.new(0, towerHeight - 4, center - diameter / 2 - 0.1), theme.lit, Enum.Material.Neon)
	end
end

local function buildCityWall(self, map, theme, streets, rng)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "City", self.Scenery
	local build = FACADES[theme.facade] or FACADES.city
	local gaps = { west = {}, east = {}, north = {}, south = {} }
	for _, s in ipairs(streets) do
		if not s.gameplay and not s.ring then
			local endX, endZ = s.alongX and (s.ax + s.bx) / 2 or s.cross, s.alongX and s.cross or (s.az + s.bz) / 2
			if s.alongX then table.insert(endX < 0 and gaps.west or gaps.east, s.cross)
			else table.insert(endZ < 0 and gaps.south or gaps.north, s.cross) end
		end
	end
	local function inGap(list, from, to)
		for _, center in ipairs(list) do
			if to > center - (ROAD_HALF + WALK + 1) and from < center + (ROAD_HALF + WALK + 1) then return center end
		end
		return nil
	end
	local sides = {
		-- name, inward normal, along-axis range
		{ "west", 1, 0, -EDGE, EDGE }, { "east", -1, 0, -EDGE, EDGE },
		{ "south", 0, 1, -EDGE - 26, EDGE + 26 }, { "north", 0, -1, -EDGE - 26, EDGE + 26 },
	}
	for _, side in ipairs(sides) do
		local name, nx, nz, from, to = side[1], side[2], side[3], side[4], side[5]
		local cursor = from
		while cursor < to - 1 do
			local width = math.min(rng:NextNumber(13, 24), to - cursor)
			-- A sliver too thin for its own building joins this one.
			if to - cursor - width < 6 then width = to - cursor end
			local gap = inGap(gaps[name], cursor, cursor + width)
			if gap then
				local stop = gap - (ROAD_HALF + WALK + 1)
				if stop - cursor >= 5 then width = stop - cursor else width = 0 end
			elseif width < 5 then
				break
			end
			if width >= 5 then
				local center = cursor + width / 2
				local x = nx ~= 0 and -nx * EDGE or center
				local z = nz ~= 0 and -nz * EDGE or center
				local face = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x + nx, 0, z + nz))
				local height = rng:NextNumber(theme.heights[1], theme.heights[2])
				if rng:NextNumber() < 0.12 then height *= 1.35 end
				build(folder, theme, rng, face, width, height, rng:NextNumber(16, 24))
				cursor += width
			end
			if gap then
				-- The street leaves the map through this opening; a taller block
				-- further back closes the view down the alley.
				local x = nx ~= 0 and -nx * (EDGE + 30) or gap
				local z = nz ~= 0 and -nz * (EDGE + 30) or gap
				local face = CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(x + nx, 0, z + nz))
				build(folder, theme, rng, face, 2 * (ROAD_HALF + WALK + 1) + 6, theme.heights[2], 20)
				cursor = gap + ROAD_HALF + WALK + 1
			end
		end
	end
end

--==============================================================================
-- Terrain, clouds and water for a chapter
--==============================================================================
local function buildTerrain(self, map, theme, rng)
	local terrain = workspace.Terrain
	-- Clear only the battlefield's own volume, so terrain elsewhere survives.
	terrain:FillBlock(CFrame.new(0, 24, 0), Vector3.new(GROUND_REACH * 2, 64, GROUND_REACH * 2), Enum.Material.Air)
	-- Smooth terrain's voxel surface sits about two studs above FillBlock's
	-- nominal top. Offset soil so the rendered surface meets streets at y=0.
	terrain:FillBlock(CFrame.new(0, -6, 0), Vector3.new(GROUND_REACH * 2, 8, GROUND_REACH * 2), theme.ground[1])
	terrain:SetMaterialColor(theme.ground[1], theme.ground[2])
	for _, patch in ipairs(theme.patches) do
		terrain:SetMaterialColor(patch[1], patch[2])
		for _ = 1, 5 do
			local size = Vector3.new(rng:NextNumber(14, 34), 8, rng:NextNumber(14, 34))
			terrain:FillBlock(CFrame.new(rng:NextNumber(-96, 96), -6, rng:NextNumber(-96, 96)), size, patch[1])
		end
	end
	if theme.water then
		terrain.WaterColor, terrain.WaterTransparency, terrain.WaterReflectance = theme.water, 0.35, 0.6
		terrain.WaterWaveSize, terrain.WaterWaveSpeed = 0.08, 6
		-- Toxic run-off pools in the outskirts, never on buildable ground.
		for _, spot in ipairs({ { -112, 96 }, { 112, -96 }, { 112, 30 } }) do
			terrain:FillBlock(CFrame.new(spot[1], -1.5, spot[2]), Vector3.new(8, 3, 16), Enum.Material.Water)
		end
	end
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover, clouds.Density, clouds.Color = theme.clouds.cover, theme.clouds.density, theme.clouds.color
	clouds.Parent = terrain
end

local BLOCKS = {}
function BLOCKS.plaza(folder, theme, rng, x, z)
	local tile = theme.walk[2]:Lerp(Color3.fromRGB(200, 196, 186), 0.18)
	prop(folder, "Plaza", Vector3.new(21, 0.24, 21), CFrame.new(x, 0.02, z), tile, theme.walk[1]).CanCollide = true
	for _, edge in ipairs({ { 0, 10.5, 21.6, 0.8 }, { 0, -10.5, 21.6, 0.8 }, { 10.5, 0, 0.8, 21.6 }, { -10.5, 0, 0.8, 21.6 } }) do
		prop(folder, "PlazaEdge", Vector3.new(edge[3], 0.3, edge[4]), CFrame.new(x + edge[1], 0.05, z + edge[2]), theme.curb[2], theme.curb[1])
	end
	local rose = prop(folder, "PlazaMosaic", Vector3.new(0.06, 9, 9), upright(CFrame.new(x, 0.15, z)), (theme.accent or theme.marking or theme.lit):Lerp(tile, 0.55), Enum.Material.Marble)
	rose.Shape = Enum.PartType.Cylinder
	prop(folder, "PlazaMosaic", Vector3.new(0.07, 4.5, 4.5), upright(CFrame.new(x, 0.16, z)), tile:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.Slate).Shape = Enum.PartType.Cylinder
end
function BLOCKS.parking(folder, theme, rng, x, z)
	local horizontal = rng:NextNumber() < 0.5
	prop(folder, "ParkingLot", horizontal and Vector3.new(22, 0.2, 15) or Vector3.new(15, 0.2, 22), CFrame.new(x, 0.02, z), Color3.fromRGB(46, 48, 52), Enum.Material.Asphalt).CanCollide = true
	for stall = -9, 9, 3 do
		local size = horizontal and Vector3.new(0.25, 0.04, 5.5) or Vector3.new(5.5, 0.04, 0.25)
		for _, row in ipairs({ -3.8, 3.8 }) do
			local lx, lz = horizontal and x + stall or x + row, horizontal and z + row or z + stall
			prop(folder, "StallLine", size, CFrame.new(lx, 0.13, lz), Color3.fromRGB(220, 220, 214), Enum.Material.SmoothPlastic).CanCollide = false
		end
	end
end
function BLOCKS.court(folder, theme, rng, x, z)
	prop(folder, "Court", Vector3.new(22, 0.2, 13), CFrame.new(x, 0.02, z), Color3.fromRGB(150, 70, 46), Enum.Material.SmoothPlastic).CanCollide = true
	prop(folder, "CourtLine", Vector3.new(20, 0.04, 0.2), CFrame.new(x, 0.13, z - 5.6), Color3.fromRGB(236, 236, 230), Enum.Material.SmoothPlastic)
	prop(folder, "CourtLine", Vector3.new(20, 0.04, 0.2), CFrame.new(x, 0.13, z + 5.6), Color3.fromRGB(236, 236, 230), Enum.Material.SmoothPlastic)
	prop(folder, "CourtLine", Vector3.new(0.2, 0.04, 11.4), CFrame.new(x, 0.13, z), Color3.fromRGB(236, 236, 230), Enum.Material.SmoothPlastic)
	prop(folder, "CourtCircle", Vector3.new(0.04, 3.6, 3.6), upright(CFrame.new(x, 0.12, z)), Color3.fromRGB(236, 236, 230), Enum.Material.SmoothPlastic).Shape = Enum.PartType.Cylinder
end
function BLOCKS.helipad(folder, theme, rng, x, z)
	local pad = prop(folder, "Helipad", Vector3.new(0.2, 18, 18), upright(CFrame.new(x, 0.02, z)), Color3.fromRGB(58, 62, 66), Enum.Material.Concrete)
	pad.Shape, pad.CanCollide = Enum.PartType.Cylinder, true
	prop(folder, "HelipadRing", Vector3.new(0.05, 15.5, 15.5), upright(CFrame.new(x, 0.12, z)), theme.accent or Color3.fromRGB(230, 200, 60), Enum.Material.Neon).Shape = Enum.PartType.Cylinder
	prop(folder, "HelipadInner", Vector3.new(0.06, 14.5, 14.5), upright(CFrame.new(x, 0.13, z)), Color3.fromRGB(58, 62, 66), Enum.Material.Concrete).Shape = Enum.PartType.Cylinder
	for _, bar in ipairs({ { -2.2, 0, 0.9, 7 }, { 2.2, 0, 0.9, 7 }, { 0, 0, 4.4, 0.9 } }) do
		prop(folder, "HelipadMark", Vector3.new(bar[3], 0.05, bar[4]), CFrame.new(x + bar[1], 0.15, z + bar[2]), Color3.fromRGB(236, 236, 230), Enum.Material.SmoothPlastic)
	end
end
function BLOCKS.lawn(folder, theme, rng, x, z)
	workspace.Terrain:FillBlock(CFrame.new(x, -6, z), Vector3.new(20, 8, 20), Enum.Material.LeafyGrass)
	local colors = { Color3.fromRGB(220, 80, 90), Color3.fromRGB(240, 200, 70), Color3.fromRGB(170, 110, 220), Color3.fromRGB(240, 240, 230) }
	for bed = -6, 6, 6 do
		prop(folder, "FlowerBed", Vector3.new(14, 0.28, 1.4), CFrame.new(x, 0.1, z + bed), colors[rng:NextInteger(1, #colors)], Enum.Material.Fabric)
	end
end

local BLOCK_KINDS = {
	manhattan = { "plaza", "parking", "court", "lawn" },
	gamma = { "helipad", "parking", "plaza" },
	hydra = { "helipad", "parking", "parking" },
	wakanda = { "plaza", "lawn", "lawn" },
	latveria = { "plaza", "plaza", "lawn" },
}

local function buildBlocks(self, mapId, theme, streets, rng)
	local folder = Instance.new("Folder")
	folder.Name, folder.Parent = "Blocks", self.Scenery
	local open = {}
	for cx = -84, 84, 24 do
		for cz = -84, 84, 24 do
			local clear = true
			for _, s in ipairs(streets) do
				if insideStreet(s, cx, cz, WALK + 14) then clear = false break end
			end
			if clear then table.insert(open, { cx + rng:NextNumber(-3, 3), cz + rng:NextNumber(-3, 3) }) end
		end
	end
	local kinds = BLOCK_KINDS[mapId] or BLOCK_KINDS.manhattan
	for index = 1, math.min(5, #open) do
		local pick = rng:NextInteger(index, #open)
		open[index], open[pick] = open[pick], open[index]
		local spot = open[index]
		BLOCKS[kinds[(index - 1) % #kinds + 1]](folder, theme, rng, spot[1], spot[2])
	end
end

function World:DressMap(mapId, map)
	local theme = STREET_THEME[mapId] or STREET_THEME.manhattan
	local rng = Random.new(map.chapter * 977 + 13)
	local streets = streetsOf(map)
	self.streets = streets
	buildTerrain(self, map, theme, rng)
	buildStreets(self, map, theme, streets)
	buildBlocks(self, mapId, theme, streets, rng)
	buildSidewalks(self, map, theme, streets, rng)
	buildOuterRing(self, map, theme, streets, rng)
	buildCityWall(self, map, theme, streets, rng)
end

-- Building a tower clears any street furniture under its platform.
function World:ClearClutter(position, radius)
	if not self.Clutter then return 0 end
	local cleared = 0
	for _, model in ipairs(self.Clutter:GetChildren()) do
		local x, z = model:GetAttribute("ClutterX"), model:GetAttribute("ClutterZ")
		if x and z then
			local reach = (radius or 2.9) + (model:GetAttribute("ClutterRadius") or 1)
			if (x - position.X) ^ 2 + (z - position.Z) ^ 2 < reach * reach then
				model:Destroy()
				cleared += 1
			end
		end
	end
	return cleared
end

function World:Build(mapId)
	applyMapLighting(mapId)
	if self.root then self.root:Destroy() end
	local map = self.catalog.Maps[mapId]
	local root = Instance.new("Model")
	root.Name, root.Parent = "DoomWorld", workspace
	self.root = root
	for _, name in ipairs({ "BuildZones", "Paths", "Towers", "Scenery", "Clutter" }) do
		local f = Instance.new("Folder") f.Name, f.Parent = name, root self[name] = f
	end
	local color = rgb(map.color)
	-- The placement cursor raycasts against this slab. Nobody sees or stands
	-- on it: the chapter's terrain is the ground.
	local ground = part(self.BuildZones, "BuildGround", Vector3.new(224, 2, 224), CFrame.new(0, -1, 0), Color3.fromRGB(29, 41, 49), Enum.Material.Slate)
	ground:SetAttribute("BuildZone", true)
	ground.Transparency, ground.CanCollide = 1, false
	self:DressMap(mapId, map)
	-- Readable route overlay follows the exact simulation segments, including
	-- alternate entrances. Streets used only as scenery never get this marking.
	local routeColors={manhattan=Color3.fromRGB(255,206,93),gamma=Color3.fromRGB(122,255,151),hydra=Color3.fromRGB(255,131,103),wakanda=Color3.fromRGB(207,151,255),latveria=Color3.fromRGB(105,229,255)}
	local routeTint=routeColors[mapId]
	local drawn={}
	for routeIndex,route in ipairs(map.paths) do
		for segment=1,#route-1 do
			local a=Vector3.new(route[segment][1],0.53,route[segment][2])
			local b=Vector3.new(route[segment+1][1],0.53,route[segment+1][2])
			local key=tostring(a)..":"..tostring(b)
			if drawn[key] then continue end
			drawn[key]=true
			local length=(b-a).Magnitude
			local strip=prop(self.Paths,"MobTrail",Vector3.new(3.4,0.07,length),CFrame.lookAt((a+b)/2,b),routeTint,Enum.Material.SmoothPlastic)
			strip.Transparency=0.22
			strip.CanCollide=false
			strip:SetAttribute("RouteIndex",routeIndex)
			strip:SetAttribute("SegmentIndex",segment)
			for distance=5,length-2,12 do
				local cf=CFrame.lookAt(a:Lerp(b,distance/length)+Vector3.new(0,0.06,0),b+Vector3.new(0,0.06,0))
				for _,side in ipairs({-1,1}) do
					prop(self.Paths,"TrailArrow",Vector3.new(0.28,0.06,1.65),cf*CFrame.new(side*0.5,0,0.5)*CFrame.Angles(0,side*math.pi/4,0),Color3.fromRGB(255,251,218),Enum.Material.Neon).CanCollide=false
				end
			end
		end
	end
	for index, route in ipairs(map.paths) do
		-- Each entrance is a gate the street runs through, facing the way the
		-- horde walks.
		local entrance, following = route[1], route[2]
		local cf = CFrame.lookAt(Vector3.new(entrance[1], 7, entrance[2]), Vector3.new(following[1], 7, following[2]))
		for _, side in ipairs({ -1, 1 }) do
			part(self.Scenery,"PortalPylon",Vector3.new(2.2,11,3.4),cf*CFrame.new(side*7,-1.5,0)*CFrame.Angles(0,0,side*0.16),Color3.fromRGB(43,53,66),Enum.Material.Slate)
		end
		arc(self.Scenery,"InfectionGateArmor",cf,6.7,1.1,2.3,Color3.fromRGB(66,78,85),Enum.Material.CorrodedMetal,24)
		arc(self.Scenery,"InfectionGateRunes",cf*CFrame.new(0,0,1.3),6.25,0.14,0.12,Color3.fromRGB(106,255,146),Enum.Material.Neon,32)
		local portal = part(self.Scenery,"EnemyPortal",Vector3.new(12,12,0.2),cf,Color3.fromRGB(44,240,126),Enum.Material.ForceField)
		portal.Transparency,portal.CanCollide=1,false
		local membrane=artPart(self.Scenery,"PortalMembrane",Vector3.new(0.35,12,12),cf*CFrame.Angles(0,math.pi/2,0),Color3.fromRGB(44,240,126),Enum.Material.ForceField)
		membrane.Shape,membrane.Transparency=Enum.PartType.Cylinder,0.62
		emitter(portal, Color3.fromRGB(44, 240, 126), 14, 5, 1.6, 1.4)
		label(portal, "PORTAL " .. index, Vector3.new(0, 10, 0), color)
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness, glow.Parent = Color3.fromRGB(44, 240, 126), 22, 1.4, portal
	end
	-- The core is the one thing the whole match is about, and it used to be a
	-- single glass box. It gets a tiered plinth, buttress pylons, containment
	-- rings and an energy column: a silhouette readable from the far camera.
	local last = map.paths[1][#map.paths[1]]
	local coreX, coreZ = last[1], last[2]
	local coreTint = Color3.fromRGB(95, 221, 255)
	part(self.Scenery, "CorePedestal", Vector3.new(20, 1, 20), CFrame.new(coreX, 0.4, coreZ), Color3.fromRGB(44, 59, 73), Enum.Material.Metal)
	part(self.Scenery, "CoreTier", Vector3.new(16, 1.2, 16), CFrame.new(coreX, 1.4, coreZ), Color3.fromRGB(51, 69, 85), Enum.Material.Metal)
	local trim = part(self.Scenery, "CoreTrim", Vector3.new(14.4, 0.25, 14.4), CFrame.new(coreX, 2.1, coreZ), coreTint, Enum.Material.Neon)
	trim.CanCollide = false
	for _, corner in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		part(self.Scenery, "CoreButtress", Vector3.new(1.6, 7, 1.6), CFrame.new(coreX + corner[1] * 6.6, 3.5, coreZ + corner[2] * 6.6), Color3.fromRGB(58, 78, 94), Enum.Material.Metal)
		local cap = part(self.Scenery, "CoreButtressCap", Vector3.new(2.2, 0.5, 2.2), CFrame.new(coreX + corner[1] * 6.6, 7.1, coreZ + corner[2] * 6.6), coreTint, Enum.Material.Neon)
		cap.CanCollide = false
	end
	local base = part(self.Scenery, "ResistanceCore", Vector3.new(9, 8, 9), CFrame.new(coreX, 6, coreZ), Color3.fromRGB(62, 193, 235), Enum.Material.Glass)
	base.Shape=Enum.PartType.Ball
	base.CanCollide, base.Transparency = false, 0.25
	local column = part(self.Scenery, "CoreColumn", Vector3.new(9.5, 3.4, 3.4), CFrame.new(coreX, 6, coreZ), coreTint, Enum.Material.Neon)
	column.Shape, column.CanCollide = Enum.PartType.Cylinder, false
	column.CFrame = CFrame.new(coreX, 6, coreZ) * CFrame.Angles(0, 0, math.pi / 2)
	for index, height in ipairs({ 3.4, 6.2, 9 }) do
		local ring = part(self.Scenery, "CoreRing", Vector3.new(0.4, 11 - index * 1.4, 11 - index * 1.4), CFrame.new(coreX, height, coreZ) * CFrame.Angles(0, 0, math.pi / 2), coreTint, Enum.Material.Neon)
		ring.Shape, ring.CanCollide, ring.Transparency = Enum.PartType.Cylinder, false, 0.45
	end
	emitter(base, coreTint, 9, 3, 1.2, 2.2)
	local coreLight = Instance.new("PointLight")
	coreLight.Color, coreLight.Range, coreLight.Brightness, coreLight.Parent = coreTint, 30, 1.6, base
	label(base, "NÚCLEO / CORE", Vector3.new(0, 9, 0), coreTint)
	self.base = base
	self.mapId = mapId
end

function World:UpdateBase(index, base, core)
	local name="PlayerBase_"..index
	local old=self.Scenery:FindFirstChild(name); if old then old:Destroy() end
	local model=Instance.new("Model"); model.Name=name; model.Parent=self.Scenery
	local def=self.catalog.Bases[base.id]; local tint=Color3.fromRGB(unpack(def.color))
	local offsets={{-12,-12},{12,-12},{-12,12},{12,12}}
	local at=Vector3.new(math.clamp(core.X+offsets[index][1],-100,100),0,math.clamp(core.Z+offsets[index][2],-100,100))
	local function block(key,size,offset,color,material)
		local p=part(model,key,size,CFrame.new(at+offset),color or tint,material or Enum.Material.Metal)
		p.CanCollide=false; return p
	end
	block("Foundation",Vector3.new(9,1,9),Vector3.new(0,0.5,0),Color3.fromRGB(53,48,61))
	block("Trim",Vector3.new(9.3,0.2,9.3),Vector3.new(0,1.1,0),tint,Enum.Material.Neon)
	local building=block("Building",Vector3.new(6,3+base.level*0.4,5),Vector3.new(0,2.7,0))
	block("Roof",Vector3.new(7,0.65,6),Vector3.new(0,4.4+base.level*0.2,0),tint:Lerp(Color3.new(1,1,1),0.35))
	for n=1,base.level do block("LevelLamp",Vector3.new(0.7,0.4,0.15),Vector3.new(-2.4+n*0.8,2.4,-2.6),Color3.fromRGB(255,233,146),Enum.Material.Neon) end
	if def.style=="farm" then
		for x=-1,1 do
			block("SupplyBed",Vector3.new(1.5,0.5,3),Vector3.new(x*2.4,1.4,2.6),Color3.fromRGB(101,73,46),Enum.Material.Wood)
			for z=0,1 do local crop=block("EnergyCrop",Vector3.new(1,1+base.level*0.22,1),Vector3.new(x*2.4,2.2,2+z*1.2),tint,Enum.Material.Neon); crop.Shape=Enum.PartType.Ball end
		end
	elseif def.style=="turret" then
		block("Turret",Vector3.new(2.8,2,2.8),Vector3.new(0,6,0),Color3.fromRGB(69,74,89))
		for x=-1,1,2 do block("CannonBarrel",Vector3.new(0.65,0.65,4+base.level*0.3),Vector3.new(x*0.8,6,-2),tint) end
	elseif def.style=="wall" then
		for x=-1,1 do block("WallSection",Vector3.new(2.8,3+base.level*0.4,1),Vector3.new(x*3,2.4,-4),tint,Enum.Material.Concrete) end
		block("ShieldEmitter",Vector3.new(8.4,0.3,0.3),Vector3.new(0,4.3,-4.6),tint,Enum.Material.Neon)
	elseif def.style=="soldiers" then
		block("Door",Vector3.new(2.4,2.8,0.15),Vector3.new(0,2.5,-2.6),Color3.fromRGB(27,28,39))
		for x=-1,1,2 do
			block("Flagpole",Vector3.new(0.15,5,0.15),Vector3.new(x*3.5,3.5,1))
			block("Banner",Vector3.new(1.3,1.8,0.15),Vector3.new(x*3.5+0.55,5,1),tint,Enum.Material.Fabric)
		end
	end
	label(building,def.name.pt.." • "..base.level.."/5",Vector3.new(0,6,0),tint)
	return at
end

function World:MakeTower(id, heroId, position, ownerId)
	local hero = self.catalog.Heroes[heroId]
	local model = Instance.new("Model")
	model.Name = heroId .. "_" .. id
	model:SetAttribute("TowerId", id) model:SetAttribute("OwnerId", ownerId) model:SetAttribute("HeroId", heroId)
	local color = rgb(hero.color)
	local flat = CFrame.Angles(0,0,math.pi/2)
	local base = part(model, "Platform", Vector3.new(0.45, 5.5, 5.5), CFrame.new(position.X, 0.35, position.Z)*flat, Color3.fromRGB(65, 83, 107), Enum.Material.Metal)
	local ring = part(model, "PowerRing", Vector3.new(0.15, 5.8, 5.8), CFrame.new(position.X, 0.12, position.Z)*flat, color, Enum.Material.Neon)
	base.Shape, ring.Shape = Enum.PartType.Cylinder, Enum.PartType.Cylinder
	ring.CanCollide = false
	-- The server owns the ring's canonical width; the client's firing recoil
	-- animates around it and restores to whatever this says, so an upgrade
	-- landing mid-recoil is never undone by the animation finishing late.
	ring:SetAttribute("BaseSize", 5.8)
	local scale = FIGURE_SCALE[heroId] or 1
	local origin = CFrame.new(position.X, 0.55, position.Z)
	local torso, head = heroFigure(model, heroId, hero, origin, scale)
	for _, p in ipairs(model:GetChildren()) do if p:IsA("BasePart") then p.CanCollide = false p:SetAttribute("TowerId", id) end end
	model.PrimaryPart, model.Parent = base, self.Towers
	self:ClearClutter(position, 2.9)
	local title = label(head, hero.name.pt, Vector3.new(0, 2, 0), Color3.fromRGB(229, 243, 247), 145, 55)
	title.TextSize = 12
	return model
end

function World:UpgradeTower(model, level, branch, mastery)
	model:SetAttribute("Level", level) model:SetAttribute("Branch", branch or 0)
	local ring = model:FindFirstChild("PowerRing")
	if ring then
		local width = 5.8 + level * 0.12
		ring.Size = Vector3.new(0.15, width, width)
		ring:SetAttribute("BaseSize", width)
		-- The two final specializations must look different from each other,
		-- not just different from an unspecialized tower: warm for the first
		-- branch, cool for the second, on every hero alike.
		if branch == 1 then ring.Color = ring.Color:Lerp(Color3.fromRGB(255, 140, 60), 0.5)
		elseif branch == 2 then ring.Color = ring.Color:Lerp(Color3.fromRGB(90, 200, 255), 0.5) end
	end
	local old = model:FindFirstChild("UpgradeMarkers") if old then old:Destroy() end
	local folder = Instance.new("Folder") folder.Name, folder.Parent = "UpgradeMarkers", model
	for i = 1, level - 1 do
		part(folder, "Rank", Vector3.new(0.55, 0.3 + i * 0.15, 0.55), CFrame.new(model.PrimaryPart.Position) * CFrame.new(-2.2 + i, 0.4, 2.1), Color3.fromRGB(255, 208, 92), Enum.Material.Neon)
	end
	local head = model:FindFirstChild("Mask")
	if branch and head then
		local emblem = part(folder, "BranchEmblem", Vector3.new(0.85, 0.85, 0.85), head.CFrame * CFrame.new(0, 1.35, 0),
			branch == 1 and Color3.fromRGB(255, 140, 60) or Color3.fromRGB(90, 200, 255), Enum.Material.Neon)
		emblem.Shape, emblem.CanCollide = branch == 1 and Enum.PartType.Ball or Enum.PartType.Cylinder, false
	end
	if (mastery or 1) >= 20 or branch then
		local highlight = model:FindFirstChildOfClass("Highlight") or Instance.new("Highlight")
		highlight.FillTransparency, highlight.OutlineTransparency, highlight.OutlineColor = 1, 0.35, Color3.fromRGB(246, 216, 115)
		highlight.Parent = model
	end
end

function World:MovePlayer(player, inMatch, index)
	local function move(character)
		local hrp = character:WaitForChild("HumanoidRootPart", 8)
		if not hrp then return end
		local pos = inMatch and Vector3.new(-18 + (index or 1) * 8, 4, 80) or self.lobbySpawn
		character:PivotTo(CFrame.new(pos))
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then humanoid.WalkSpeed, humanoid.MaxHealth, humanoid.Health = 23, 100000, 100000 end
		for _, item in ipairs(character:GetDescendants()) do
			if item:IsA("BasePart") then item.CollisionGroup = "Commanders" end
		end
	end
	if player.Character then task.spawn(move, player.Character) end
end

return World
