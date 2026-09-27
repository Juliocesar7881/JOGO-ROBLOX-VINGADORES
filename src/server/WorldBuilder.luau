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

-- The whole-figure size callers still pass for a hero (towers multiply it by
-- their 15% emphasis). The jointed figures carry their own proportions, so
-- only that emphasis survives; final art from Studio is sized by its artist.
local FIGURE_SCALE = { hulk = 1.65, groot = 1.6, rocket = 0.6, wasp = 0.9, silversurfer = 1.05 }
-- Sign text is shouted in capitals; string.upper does not know accents, so
-- World.new swaps in the catalog's accent-aware version.
local upper = string.upper
-- Per-map campaign lengths for the portal signs, set by World.new.
local campaignWaves = {}

-- Final art made in Studio (tools/build.py embeds assets/models into
-- ReplicatedStorage.DoomArt): a Model per hero or enemy id. When one exists it
-- replaces the generated figure everywhere the figure is used — towers,
-- portraits, the training yard — and changes nothing but the look.
local function artTemplate(kind, id)
	local art = game:GetService("ReplicatedStorage"):FindFirstChild("DoomArt")
	local folder = art and art:FindFirstChild(kind)
	local template = folder and id and folder:FindFirstChild(id)
	return template and template:IsA("Model") and template or nil
end
World.ArtTemplate = artTemplate

-- The authoring contract (assets/models/README.md): facing -Z, pivot at the
-- centre of the feet, an optional Attachment named Muzzle where shots leave,
-- optional Animator with animation ids in attributes. Visual size is the
-- artist's; a tower adds only its usual emphasis. Rigged models keep their
-- joints alive: only the root stays anchored.
local function artFigure(parent, template, origin, emphasis)
	local figure = template:Clone()
	figure.Name = "HeroFigure"
	figure:SetAttribute("HeroArt", true)
	local rigged = figure:FindFirstChildWhichIsA("Motor6D", true) ~= nil
	for _, item in ipairs(figure:GetDescendants()) do
		if item:IsA("BasePart") then
			item.CanCollide, item.CanTouch = false, false
			item.Anchored = not rigged or item == figure.PrimaryPart
			item:SetAttribute("HeroVisual", true)
		end
	end
	if emphasis and emphasis ~= 1 and figure.ScaleTo then
		pcall(function() figure:ScaleTo(figure:GetScale() * emphasis) end)
	end
	figure:PivotTo(origin)
	figure.Parent = parent
	parent:SetAttribute("FigureScale", 1)
	local torso = figure.PrimaryPart or figure:FindFirstChildWhichIsA("BasePart", true)
	return torso, figure:FindFirstChild("Head", true) or torso
end


--==============================================================================
-- Jointed figures
--==============================================================================
-- Every hero, enemy and boss is a jointed body in the Roblox avatar layout
-- (R15 part names): blocks for the body, the classic rounded head, and a
-- Motor6D at each joint so the client can pose and walk it. Size comes from
-- proportions, not a uniform zoom: Hulk has a broad chest, thick arms and a
-- small head; Rocket is short with a big head; Groot is tall and narrow.
-- Costume pieces are welded to the body part they belong to and follow every
-- pose. The server only builds; poses and walking are the client's (Motion).
-- Purely visual: range, collision and rules never read a figure.
local Figure = {}
World.Figure = Figure

local FIGURE_INK = Color3.fromRGB(24, 28, 39)
local FIGURE_WHITE = Color3.fromRGB(236, 240, 244)

local function figurePart(parent, name, size, cf, color, material, class)
	local made = Instance.new(class or "Part")
	made.Name, made.Size, made.CFrame = name, size, cf
	made.Color, made.Material = color, material or Enum.Material.SmoothPlastic
	made.Anchored, made.CanCollide, made.CanTouch, made.CanQuery, made.CastShadow = true, false, false, false, false
	made.TopSurface, made.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	made.Parent = parent
	return made
end

-- A Motor6D whose pivot is `at` (model space), axis-aligned with the body, so a
-- pose is plain CFrame.Angles: X swings forward and back, Z out to the side.
local function figureJoint(name, part0, part1, at)
	local motor = Instance.new("Motor6D")
	local frame = CFrame.new(at)
	motor.Name, motor.Part0, motor.Part1 = name, part0, part1
	motor.C0, motor.C1 = part0.CFrame:Inverse() * frame, part1.CFrame:Inverse() * frame
	motor.Parent = part1
	return motor
end

local function figureWeld(host, made)
	local fit = Instance.new("Weld")
	fit.Name, fit.Part0, fit.Part1 = "Fit", host, made
	fit.C0 = host.CFrame:Inverse() * made.CFrame
	fit.Parent = made
	return made
end

-- Body plan of a 6-stud human (unscaled sizes). Feet stand on y = 0 and the
-- face looks down -Z, the contract every figure user relies on.
local BODY = {
	foot = Vector3.new(0.74, 0.34, 1.04), lowerLeg = Vector3.new(0.7, 1.22, 0.72),
	upperLeg = Vector3.new(0.8, 1.26, 0.84), pelvis = Vector3.new(1.62, 0.5, 0.94),
	chest = Vector3.new(2.02, 1.48, 1.0), upperArm = Vector3.new(0.64, 1.12, 0.66),
	lowerArm = Vector3.new(0.58, 1.02, 0.6), hand = Vector3.new(0.6, 0.5, 0.62),
	head = Vector3.new(1.36, 1.3, 1.32),
}
Figure.Body = BODY

-- spec: scale, width, depth, chest (shoulders over hips), head, arm, leg,
-- hand, foot, legLength, armLength, torsoLength, neck.
-- colors: skin, head, chest, pelvis, upperArm, lowerArm, hand, upperLeg,
-- lowerLeg, foot (each falls back to the one it sits next to).
function Figure.Build(parent, spec, colors, material)
	spec, colors = spec or {}, colors or {}
	local V = Vector3.new
	local s = spec.scale or 1
	local w, d = spec.width or 1, spec.depth or spec.width or 1
	local arm, leg = spec.arm or 1, spec.leg or 1
	local hand, legLength, armLength = spec.hand or 1, spec.legLength or 1, spec.armLength or 1
	local skin = colors.skin or Color3.fromRGB(232, 181, 147)
	local chestColor = colors.chest or skin
	local pelvisColor = colors.pelvis or chestColor
	local upperArmColor = colors.upperArm or chestColor
	local lowerArmColor = colors.lowerArm or upperArmColor
	local upperLegColor = colors.upperLeg or pelvisColor
	local lowerLegColor = colors.lowerLeg or upperLegColor
	local footColor = colors.foot or lowerLegColor:Lerp(FIGURE_INK, 0.25)
	local model = Instance.new("Model")
	model.Name = "HeroFigure"
	model.Parent = parent
	local sizes = {
		foot = V(BODY.foot.X * leg, BODY.foot.Y, BODY.foot.Z * (spec.foot or 1) * math.sqrt(leg)) * s,
		lowerLeg = V(BODY.lowerLeg.X * leg, BODY.lowerLeg.Y * legLength, BODY.lowerLeg.Z * leg) * s,
		upperLeg = V(BODY.upperLeg.X * leg, BODY.upperLeg.Y * legLength, BODY.upperLeg.Z * leg) * s,
		chest = V(BODY.chest.X * w * (spec.chest or 1), BODY.chest.Y * (spec.torsoLength or 1), BODY.chest.Z * d) * s,
		upperArm = V(BODY.upperArm.X * arm, BODY.upperArm.Y * armLength, BODY.upperArm.Z * arm) * s,
		lowerArm = V(BODY.lowerArm.X * arm, BODY.lowerArm.Y * armLength, BODY.lowerArm.Z * arm) * s,
		hand = V(BODY.hand.X * arm * hand, BODY.hand.Y * hand * math.sqrt(arm), BODY.hand.Z * arm * hand) * s,
		head = BODY.head * (spec.head or 1) * s,
	}
	sizes.pelvis = V(math.max(BODY.pelvis.X * w, sizes.upperLeg.X * 2.02 / s), BODY.pelvis.Y, BODY.pelvis.Z * d) * s
	local hipX = sizes.pelvis.X / 2 - sizes.upperLeg.X / 2
	local ankleY = sizes.foot.Y
	local kneeY = ankleY + sizes.lowerLeg.Y
	local hipTop = kneeY + sizes.upperLeg.Y
	local pelvisY = hipTop - 0.06 * s + sizes.pelvis.Y / 2
	local waistY = pelvisY + sizes.pelvis.Y / 2
	local neckY = waistY + sizes.chest.Y
	local shoulderX = sizes.chest.X / 2 + sizes.upperArm.X / 2 - 0.02 * s
	local elbowY = neckY - 0.04 * s - sizes.upperArm.Y
	local wristY = elbowY - sizes.lowerArm.Y + 0.03 * s
	local parts, joints = {}, {}
	local root = figurePart(model, "HumanoidRootPart", V(0.2, 0.2, 0.2) * s, CFrame.new(), skin)
	root.Transparency = 1
	root:SetAttribute("HeroVisual", true)
	model.PrimaryPart = root
	parts.HumanoidRootPart = root
	local function body(name, size, center, color)
		local made = figurePart(model, name, size, CFrame.new(center), color, material)
		made:SetAttribute("HeroVisual", true)
		parts[name] = made
		return made
	end
	local pelvis = body("LowerTorso", sizes.pelvis, V(0, pelvisY, 0), pelvisColor)
	local chest = body("UpperTorso", sizes.chest, V(0, waistY + sizes.chest.Y / 2, 0), chestColor)
	local head = body("Head", sizes.head, V(0, neckY + sizes.head.Y / 2 + (spec.neck or 0.02) * s, 0), colors.head or skin)
	local shape = Instance.new("SpecialMesh")
	shape.MeshType, shape.Parent = Enum.MeshType.Head, head
	joints.Root = figureJoint("Root", root, pelvis, V(0, pelvisY, 0))
	joints.Waist = figureJoint("Waist", pelvis, chest, V(0, waistY, 0))
	joints.Neck = figureJoint("Neck", chest, head, V(0, neckY, 0))
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "Left" or "Right"
		local upperArm = body(name .. "UpperArm", sizes.upperArm, V(side * shoulderX, neckY - 0.04 * s - sizes.upperArm.Y / 2, 0), upperArmColor)
		local lowerArm = body(name .. "LowerArm", sizes.lowerArm, V(side * shoulderX, elbowY + 0.02 * s - sizes.lowerArm.Y / 2, 0), lowerArmColor)
		local handPart = body(name .. "Hand", sizes.hand, V(side * shoulderX, wristY - sizes.hand.Y / 2 + 0.04 * s, 0), colors.hand or skin)
		local upperLeg = body(name .. "UpperLeg", sizes.upperLeg, V(side * hipX, kneeY + sizes.upperLeg.Y / 2, 0), upperLegColor)
		local lowerLeg = body(name .. "LowerLeg", sizes.lowerLeg, V(side * hipX, ankleY + sizes.lowerLeg.Y / 2, 0), lowerLegColor)
		local foot = body(name .. "Foot", sizes.foot, V(side * hipX, sizes.foot.Y / 2, -(sizes.foot.Z - sizes.lowerLeg.Z) / 2), footColor)
		joints[name .. "Shoulder"] = figureJoint(name .. "Shoulder", chest, upperArm, V(side * shoulderX, neckY - sizes.upperArm.X * 0.5, 0))
		joints[name .. "Elbow"] = figureJoint(name .. "Elbow", upperArm, lowerArm, V(side * shoulderX, elbowY, 0))
		joints[name .. "Wrist"] = figureJoint(name .. "Wrist", lowerArm, handPart, V(side * shoulderX, wristY, 0))
		joints[name .. "Hip"] = figureJoint(name .. "Hip", pelvis, upperLeg, V(side * hipX, hipTop - 0.22 * s, 0))
		joints[name .. "Knee"] = figureJoint(name .. "Knee", upperLeg, lowerLeg, V(side * hipX, kneeY, 0))
		joints[name .. "Ankle"] = figureJoint(name .. "Ankle", lowerLeg, foot, V(side * hipX, ankleY, 0))
	end
	model:SetAttribute("HeroRig", true)
	model:SetAttribute("FigureScale", s)
	model:SetAttribute("FigureHeight", head.Position.Y + sizes.head.Y / 2)
	-- Where shots aim: the middle of the chest, above the feet.
	model:SetAttribute("ChestHeight", chest.Position.Y)
	local figure = { model = model, parts = parts, joints = joints, scale = s, material = material, sizes = sizes }
	-- A costume piece welded to a body part. `offset` is in the part's own
	-- frame (body parts are built unrotated, so this is model axes too).
	function figure.add(host, name, size, offset, color, surface, shape)
		local base = parts[host]
		local made = figurePart(model, name, size, base.CFrame * offset, color, surface or material)
		if shape == "ball" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType, mesh.Parent = Enum.MeshType.Sphere, made
		elseif shape == "head" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType, mesh.Parent = Enum.MeshType.Head, made
		elseif shape == "wedge" then
			made:Destroy()
			made = figurePart(model, name, size, base.CFrame * offset, color, surface or material, "WedgePart")
		elseif shape then
			made.Shape = shape
		end
		made:SetAttribute("HeroVisual", true)
		return figureWeld(base, made)
	end
	-- A round plate facing the part's front (-Z), or `axis` for other facings.
	function figure.disc(host, name, diameter, thickness, offset, color, surface)
		return figure.add(host, name, Vector3.new(thickness, diameter, diameter), offset * CFrame.Angles(0, math.pi / 2, 0), color, surface, Enum.PartType.Cylinder)
	end
	-- A straight rod between two points given in the host part's frame.
	function figure.rod(host, name, from, to, thickness, color, surface)
		local length = (to - from).Magnitude
		return figure.add(host, name, Vector3.new(thickness, thickness, length), CFrame.lookAt((from + to) / 2, to), color, surface)
	end
	-- A point on the face: x across (-1 left of the viewer's... the figure's
	-- left) to 1, y from the chin (-1) to the crown (1), `lift` out of the skin.
	function figure.face(x, y, lift)
		local size = parts.Head.Size
		return CFrame.new(x * size.X / 2, y * size.Y / 2, -size.Z / 2 - (lift or 0))
	end
	return figure
end

-- Faces. "smile" and "grin" are the classic Roblox face (two dark ovals and a
-- curve); "fierce" adds angled brows; "lens" is a mask's white eyes with a rim;
-- "visor" and "slits" are glowing bars. A face never uses an image asset.
function Figure.Face(figure, style, options)
	options = options or {}
	local head = figure.parts.Head
	local h = head.Size
	local ink = options.ink or FIGURE_INK
	local k = h.X / BODY.head.X
	if style == "smile" or style == "grin" or style == "fierce" or style == "angry" then
		for _, side in ipairs({ -1, 1 }) do
			figure.add("Head", "Eye", Vector3.new(0.17, 0.27, 0.06) * k, figure.face(side * 0.28, 0.14, 0.0), options.eye or ink, Enum.Material.SmoothPlastic, "ball")
			figure.add("Head", "Catchlight", Vector3.new(0.06, 0.07, 0.04) * k, figure.face(side * 0.28 - 0.03, 0.22, 0.02), FIGURE_WHITE, Enum.Material.Neon, "ball")
			if style == "fierce" or style == "angry" then
				local tilt = style == "angry" and 0.42 or 0.24
				figure.add("Head", "Brow", Vector3.new(0.36, 0.08, 0.06) * k, figure.face(side * 0.3, 0.42, 0.0) * CFrame.Angles(0, 0, side * tilt), options.brow or ink, Enum.Material.SmoothPlastic)
			end
		end
		if style == "angry" then
			figure.add("Head", "Mouth", Vector3.new(0.42, 0.09, 0.05) * k, figure.face(0, -0.42, 0.0), options.mouth or ink, Enum.Material.SmoothPlastic)
		else
			local wide = style == "grin" and 1.25 or 1
			figure.add("Head", "Mouth", Vector3.new(0.26 * wide, 0.07, 0.05) * k, figure.face(0, -0.44, 0.0), options.mouth or ink, Enum.Material.SmoothPlastic)
			for _, side in ipairs({ -1, 1 }) do
				figure.add("Head", "Mouth", Vector3.new(0.16, 0.07, 0.05) * k, figure.face(side * 0.24 * wide, -0.36, 0.0) * CFrame.Angles(0, 0, side * 0.55), options.mouth or ink, Enum.Material.SmoothPlastic)
			end
		end
	elseif style == "lens" then
		local lens = options.lens or FIGURE_WHITE
		local width, height, slant = options.width or 0.4, options.height or 0.3, options.slant or 0.3
		for _, side in ipairs({ -1, 1 }) do
			local at = figure.face(side * 0.3, 0.12, 0.0) * CFrame.Angles(0, 0, side * slant)
			figure.add("Head", "EyeRim", Vector3.new(width + 0.1, height + 0.1, 0.05) * k, at, options.rim or ink, Enum.Material.SmoothPlastic, "ball")
			figure.add("Head", "Eye", Vector3.new(width, height, 0.06) * k, at * CFrame.new(0, 0, -0.012), lens, options.glow and Enum.Material.Neon or Enum.Material.SmoothPlastic, "ball")
		end
	elseif style == "visor" or style == "slits" then
		local glow = options.glow or Color3.fromRGB(137, 226, 255)
		if style == "visor" then
			figure.add("Head", "Visor", Vector3.new(0.86, 0.14, 0.05) * k, figure.face(0, 0.14, 0.0), glow, Enum.Material.Neon)
		else
			for _, side in ipairs({ -1, 1 }) do
				figure.add("Head", "Visor", Vector3.new(0.3, 0.1, 0.05) * k, figure.face(side * 0.26, 0.14, 0.0) * CFrame.Angles(0, 0, -side * 0.14), glow, Enum.Material.Neon)
			end
		end
	end
end

-- Hair: a cap over the crown and back of the head, plus an optional style.
function Figure.Hair(figure, color, style)
	local h = figure.parts.Head.Size
	figure.add("Head", "Hair", Vector3.new(h.X * 1.08, h.Y * 0.62, h.Z * 1.08), CFrame.new(0, h.Y * 0.28, h.Z * 0.04), color, Enum.Material.SmoothPlastic, "ball")
	if style == "long" then
		figure.add("Head", "HairBack", Vector3.new(h.X * 1.02, h.Y * 1.05, h.Z * 0.34), CFrame.new(0, -h.Y * 0.18, h.Z * 0.42), color, Enum.Material.SmoothPlastic)
	elseif style == "fringe" then
		figure.add("Head", "Fringe", Vector3.new(h.X * 0.62, h.Y * 0.2, h.Z * 0.2), CFrame.new(h.X * 0.14, h.Y * 0.36, -h.Z * 0.46) * CFrame.Angles(0, 0, -0.22), color, Enum.Material.SmoothPlastic)
	elseif style == "spiky" then
		for i = -2, 2 do
			figure.add("Head", "HairSpike", Vector3.new(h.X * 0.2, h.Y * 0.34, h.Z * 0.5), CFrame.new(i * h.X * 0.2, h.Y * 0.5, -h.Z * 0.1) * CFrame.Angles(0, 0, -i * 0.28), color, Enum.Material.SmoothPlastic, "wedge")
		end
	end
end


-- Heroes ----------------------------------------------------------------------
local HC = {
	red = Color3.fromRGB(190, 38, 50), darkRed = Color3.fromRGB(128, 24, 36), gold = Color3.fromRGB(232, 184, 76),
	navy = Color3.fromRGB(28, 58, 112), blue = Color3.fromRGB(44, 88, 186), ink = FIGURE_INK,
	silver = Color3.fromRGB(184, 198, 212), steel = Color3.fromRGB(110, 120, 132), white = FIGURE_WHITE,
	skin = Color3.fromRGB(234, 184, 148), tan = Color3.fromRGB(198, 146, 108), brown = Color3.fromRGB(141, 92, 64),
	deep = Color3.fromRGB(96, 64, 46), energy = Color3.fromRGB(137, 226, 255), green = Color3.fromRGB(96, 160, 72),
	purple = Color3.fromRGB(82, 49, 118), leather = Color3.fromRGB(92, 62, 44), yellow = Color3.fromRGB(245, 196, 52),
}
local METAL, FABRIC, NEON = Enum.Material.SmoothPlastic, Enum.Material.SmoothPlastic, Enum.Material.Neon

-- How each hero moves when it attacks (read by the client's Motion).
local HERO_POSE = {
	hawkeye = "bow", widow = "dual", starlord = "dual", deadpool = "dual", bucky = "rifle", warmachine = "rifle", rocket = "rifle",
	hulk = "smash", thor = "smash", groot = "smash", beast = "smash", shangchi = "strike", daredevil = "strike",
	wolverine = "slash", psylocke = "slash", panther = "slash", moonknight = "strike", captain = "throw", gambit = "throw",
	wanda = "magic", strange = "magic", jean = "magic", storm = "magic", iceman = "magic", silversurfer = "magic",
	vision = "beam", captainmarvel = "beam", cyclops = "beam", nova = "shoot", ghostrider = "magic", nightcrawler = "strike",
}

-- body, colors, face and hair per hero; `extras` below adds what makes each
-- one recognizable without its name: shield, hammer, web, bow, claws, cape.
local HERO_LOOK = {
	ironman = { colors = { chest = HC.red, pelvis = HC.gold, upperArm = HC.red, lowerArm = HC.gold, hand = HC.red, upperLeg = HC.red, lowerLeg = HC.gold, foot = HC.red, head = HC.red }, shiny = true },
	hawkeye = { colors = { chest = Color3.fromRGB(75, 42, 106), pelvis = HC.ink, upperArm = HC.skin, lowerArm = HC.ink, hand = HC.skin, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.leather }, face = "fierce", hair = { Color3.fromRGB(122, 88, 54), "fringe" } },
	falcon = { colors = { skin = HC.brown, chest = Color3.fromRGB(122, 28, 38), pelvis = HC.ink, upperArm = Color3.fromRGB(122, 28, 38), lowerArm = HC.ink, hand = HC.ink, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "smile", hair = { HC.ink } },
	bucky = { colors = { chest = Color3.fromRGB(46, 52, 62), pelvis = HC.ink, upperArm = HC.silver, lowerArm = HC.silver, hand = HC.silver, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "fierce", hair = { Color3.fromRGB(58, 42, 34), "long" } },
	spiderman = { body = { width = 0.94, arm = 0.94, leg = 0.94 }, colors = { head = HC.red, chest = HC.red, pelvis = HC.blue, upperArm = HC.red, lowerArm = HC.red, hand = HC.red, upperLeg = HC.blue, lowerLeg = HC.blue, foot = HC.red } },
	widow = { body = { width = 0.88, arm = 0.88, leg = 0.9, chest = 0.94 }, colors = { chest = HC.ink, pelvis = HC.ink, upperArm = HC.ink, lowerArm = HC.ink, hand = HC.ink, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "fierce", hair = { Color3.fromRGB(160, 50, 30), "long" } },
	antman = { colors = { head = HC.red, chest = HC.red, pelvis = HC.ink, upperArm = HC.red, lowerArm = HC.ink, hand = HC.ink, upperLeg = HC.red, lowerLeg = HC.ink, foot = HC.ink }, shiny = true },
	wasp = { body = { scale = 0.9, width = 0.86, arm = 0.86, leg = 0.88 }, colors = { head = HC.yellow, chest = HC.yellow, pelvis = HC.ink, upperArm = HC.ink, lowerArm = HC.yellow, hand = HC.ink, upperLeg = HC.ink, lowerLeg = HC.yellow, foot = HC.ink } },
	rocket = { body = { scale = 0.62, head = 1.36, legLength = 0.78, armLength = 0.9, width = 1.02 }, colors = { skin = Color3.fromRGB(150, 104, 72), head = Color3.fromRGB(150, 104, 72), chest = Color3.fromRGB(196, 92, 46), pelvis = HC.ink, upperArm = Color3.fromRGB(196, 92, 46), lowerArm = Color3.fromRGB(150, 104, 72), hand = Color3.fromRGB(150, 104, 72), upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "grin" },
	daredevil = { colors = { head = Color3.fromRGB(148, 26, 34), chest = Color3.fromRGB(148, 26, 34), pelvis = HC.darkRed, upperArm = Color3.fromRGB(148, 26, 34), lowerArm = Color3.fromRGB(148, 26, 34), hand = HC.darkRed, upperLeg = Color3.fromRGB(148, 26, 34), lowerLeg = Color3.fromRGB(148, 26, 34), foot = HC.darkRed } },
	shangchi = { colors = { chest = Color3.fromRGB(190, 52, 38), pelvis = HC.ink, upperArm = Color3.fromRGB(190, 52, 38), lowerArm = HC.skin, hand = HC.skin, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "fierce", hair = { HC.ink, "fringe" } },
	captain = { colors = { chest = HC.navy, pelvis = HC.red, upperArm = HC.navy, lowerArm = HC.navy, hand = HC.red, upperLeg = HC.navy, lowerLeg = HC.navy, foot = HC.red, head = HC.navy } },
	panther = { colors = { head = HC.ink, chest = HC.ink, pelvis = HC.ink, upperArm = HC.ink, lowerArm = HC.ink, hand = HC.ink, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, shiny = true },
	hulk = { body = { scale = 1.72, width = 1.1, depth = 1.12, chest = 1.14, head = 0.8, arm = 1.55, hand = 1.3, leg = 1.36, legLength = 0.88, torsoLength = 1.1, foot = 1.1 },
		colors = { skin = HC.green, head = HC.green, chest = HC.green, pelvis = HC.purple, upperArm = HC.green, lowerArm = HC.green, hand = HC.green, upperLeg = HC.purple, lowerLeg = HC.green, foot = HC.green }, face = "angry", hair = { Color3.fromRGB(34, 42, 30), "spiky" } },
	vision = { colors = { skin = Color3.fromRGB(176, 58, 74), head = Color3.fromRGB(176, 58, 74), chest = Color3.fromRGB(45, 117, 100), pelvis = Color3.fromRGB(45, 117, 100), upperArm = Color3.fromRGB(45, 117, 100), lowerArm = Color3.fromRGB(176, 58, 74), hand = Color3.fromRGB(176, 58, 74), upperLeg = Color3.fromRGB(45, 117, 100), lowerLeg = Color3.fromRGB(176, 58, 74), foot = HC.gold }, face = "smile", shiny = true },
	warmachine = { body = { width = 1.08, arm = 1.08, leg = 1.06 }, colors = { head = HC.steel, chest = HC.steel, pelvis = HC.ink, upperArm = HC.steel, lowerArm = HC.ink, hand = HC.steel, upperLeg = HC.steel, lowerLeg = HC.ink, foot = HC.steel }, shiny = true },
	starlord = { colors = { chest = Color3.fromRGB(96, 40, 40), pelvis = HC.ink, upperArm = Color3.fromRGB(110, 44, 42), lowerArm = Color3.fromRGB(110, 44, 42), hand = HC.ink, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.leather, head = HC.darkRed } },
	groot = { body = { scale = 1.52, width = 0.74, depth = 0.8, head = 0.92, arm = 0.8, leg = 0.86, legLength = 1.18, armLength = 1.24, torsoLength = 1.08, hand = 1.1 },
		colors = { skin = Color3.fromRGB(112, 82, 54), head = Color3.fromRGB(128, 94, 62), chest = Color3.fromRGB(112, 82, 54), pelvis = Color3.fromRGB(96, 70, 46), upperArm = Color3.fromRGB(112, 82, 54), lowerArm = Color3.fromRGB(104, 76, 50), hand = Color3.fromRGB(96, 70, 46), upperLeg = Color3.fromRGB(104, 76, 50), lowerLeg = Color3.fromRGB(96, 70, 46), foot = Color3.fromRGB(84, 60, 40) }, material = Enum.Material.Wood, face = "smile" },
	thor = { body = { width = 1.1, arm = 1.12, leg = 1.04 }, colors = { chest = Color3.fromRGB(51, 60, 74), pelvis = HC.ink, upperArm = HC.skin, lowerArm = Color3.fromRGB(51, 60, 74), hand = HC.skin, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "fierce", hair = { HC.gold, "long" } },
	wanda = { body = { width = 0.88, arm = 0.86, leg = 0.9 }, colors = { chest = Color3.fromRGB(128, 24, 49), pelvis = HC.ink, upperArm = Color3.fromRGB(128, 24, 49), lowerArm = Color3.fromRGB(128, 24, 49), hand = HC.skin, upperLeg = HC.ink, lowerLeg = HC.ink, foot = Color3.fromRGB(128, 24, 49) }, face = "smile", hair = { Color3.fromRGB(110, 36, 30), "long" } },
	strange = { colors = { chest = HC.navy, pelvis = Color3.fromRGB(90, 62, 44), upperArm = HC.navy, lowerArm = HC.navy, hand = HC.skin, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "fierce", hair = { HC.ink, "fringe" } },
	ghostrider = { colors = { head = Color3.fromRGB(232, 228, 214), chest = HC.ink, pelvis = HC.ink, upperArm = HC.ink, lowerArm = HC.ink, hand = HC.ink, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink } },
	captainmarvel = { body = { width = 0.9, arm = 0.88, leg = 0.92 }, colors = { chest = HC.blue, pelvis = HC.red, upperArm = HC.red, lowerArm = HC.blue, hand = HC.red, upperLeg = HC.blue, lowerLeg = HC.red, foot = HC.red }, face = "fierce", hair = { HC.gold, "long" } },
	silversurfer = { body = { width = 0.9, arm = 0.9 }, colors = { skin = Color3.fromRGB(205, 218, 232), head = Color3.fromRGB(205, 218, 232), chest = Color3.fromRGB(196, 208, 222), pelvis = Color3.fromRGB(186, 200, 215), upperArm = Color3.fromRGB(196, 208, 222), lowerArm = Color3.fromRGB(196, 208, 222), hand = Color3.fromRGB(205, 218, 232), upperLeg = Color3.fromRGB(186, 200, 215), lowerLeg = Color3.fromRGB(186, 200, 215), foot = Color3.fromRGB(205, 218, 232) }, face = "smile", shiny = true },
	wolverine = { body = { scale = 0.94, width = 1.12, arm = 1.08, leg = 1.02 }, colors = { head = HC.yellow, chest = HC.yellow, pelvis = HC.navy, upperArm = HC.navy, lowerArm = HC.yellow, hand = HC.navy, upperLeg = HC.yellow, lowerLeg = HC.navy, foot = HC.navy } },
	cyclops = { colors = { head = HC.navy, chest = HC.navy, pelvis = HC.yellow, upperArm = HC.navy, lowerArm = HC.yellow, hand = HC.yellow, upperLeg = HC.navy, lowerLeg = HC.navy, foot = HC.yellow } },
	storm = { body = { width = 0.9, arm = 0.88, leg = 0.92 }, colors = { skin = HC.deep, chest = HC.white, pelvis = HC.ink, upperArm = HC.white, lowerArm = HC.white, hand = HC.deep, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "smile", hair = { HC.white, "long" } },
	jean = { body = { width = 0.88, arm = 0.86, leg = 0.9 }, colors = { chest = Color3.fromRGB(61, 139, 97), pelvis = HC.gold, upperArm = Color3.fromRGB(61, 139, 97), lowerArm = Color3.fromRGB(61, 139, 97), hand = HC.gold, upperLeg = Color3.fromRGB(61, 139, 97), lowerLeg = Color3.fromRGB(61, 139, 97), foot = HC.gold }, face = "smile", hair = { Color3.fromRGB(190, 72, 40), "long" } },
	iceman = { colors = { skin = Color3.fromRGB(172, 238, 255), head = Color3.fromRGB(172, 238, 255), chest = Color3.fromRGB(139, 225, 255), pelvis = Color3.fromRGB(120, 205, 240), upperArm = Color3.fromRGB(139, 225, 255), lowerArm = Color3.fromRGB(139, 225, 255), hand = Color3.fromRGB(172, 238, 255), upperLeg = Color3.fromRGB(120, 205, 240), lowerLeg = Color3.fromRGB(139, 225, 255), foot = Color3.fromRGB(172, 238, 255) }, material = Enum.Material.Ice, face = "smile" },
	gambit = { colors = { chest = Color3.fromRGB(190, 88, 160), pelvis = Color3.fromRGB(44, 56, 104), upperArm = Color3.fromRGB(138, 80, 62), lowerArm = Color3.fromRGB(138, 80, 62), hand = HC.ink, upperLeg = Color3.fromRGB(44, 56, 104), lowerLeg = Color3.fromRGB(44, 56, 104), foot = Color3.fromRGB(190, 88, 160) }, face = "fierce", hair = { Color3.fromRGB(94, 56, 38), "long" } },
	nightcrawler = { colors = { skin = Color3.fromRGB(58, 62, 142), head = Color3.fromRGB(58, 62, 142), chest = Color3.fromRGB(44, 40, 58), pelvis = Color3.fromRGB(156, 53, 65), upperArm = Color3.fromRGB(44, 40, 58), lowerArm = Color3.fromRGB(44, 40, 58), hand = Color3.fromRGB(58, 62, 142), upperLeg = Color3.fromRGB(44, 40, 58), lowerLeg = Color3.fromRGB(44, 40, 58), foot = Color3.fromRGB(58, 62, 142) }, face = "lens", faceOptions = { lens = Color3.fromRGB(255, 222, 90), glow = true, width = 0.3, height = 0.24 }, hair = { Color3.fromRGB(30, 34, 90), "spiky" } },
	beast = { body = { scale = 1.12, width = 1.24, chest = 1.1, arm = 1.3, hand = 1.3, leg = 1.12, legLength = 0.88, head = 0.92 }, colors = { skin = Color3.fromRGB(73, 123, 194), head = Color3.fromRGB(83, 140, 205), chest = Color3.fromRGB(73, 123, 194), pelvis = HC.navy, upperArm = Color3.fromRGB(73, 123, 194), lowerArm = Color3.fromRGB(73, 123, 194), hand = Color3.fromRGB(83, 140, 205), upperLeg = HC.navy, lowerLeg = Color3.fromRGB(73, 123, 194), foot = Color3.fromRGB(83, 140, 205) }, face = "grin", hair = { Color3.fromRGB(36, 52, 110), "spiky" } },
	psylocke = { body = { width = 0.88, arm = 0.86, leg = 0.9 }, colors = { chest = Color3.fromRGB(96, 63, 170), pelvis = Color3.fromRGB(96, 63, 170), upperArm = HC.skin, lowerArm = Color3.fromRGB(96, 63, 170), hand = Color3.fromRGB(211, 95, 176), upperLeg = HC.skin, lowerLeg = Color3.fromRGB(96, 63, 170), foot = Color3.fromRGB(96, 63, 170) }, face = "fierce", hair = { Color3.fromRGB(73, 42, 119), "long" } },
	deadpool = { colors = { head = HC.red, chest = HC.red, pelvis = HC.ink, upperArm = HC.red, lowerArm = HC.red, hand = HC.ink, upperLeg = HC.red, lowerLeg = HC.red, foot = HC.ink } },
	moonknight = { colors = { head = HC.white, chest = HC.white, pelvis = Color3.fromRGB(195, 198, 202), upperArm = HC.white, lowerArm = HC.white, hand = Color3.fromRGB(195, 198, 202), upperLeg = HC.white, lowerLeg = HC.white, foot = Color3.fromRGB(195, 198, 202) } },
	nova = { colors = { head = HC.gold, chest = HC.navy, pelvis = HC.navy, upperArm = HC.navy, lowerArm = HC.gold, hand = HC.gold, upperLeg = HC.navy, lowerLeg = HC.gold, foot = HC.gold }, shiny = true },
}
Figure.HeroLook = HERO_LOOK

local function muzzle(figure, host, position)
	local attachment = Instance.new("Attachment")
	attachment.Name, attachment.Position, attachment.Parent = "Muzzle", position, figure.parts[host]
end

local function cape(figure, color, length, trim)
	local chest = figure.parts.UpperTorso.Size
	local s = figure.scale
	local long = length or 3.4
	figure.add("UpperTorso", "Cape", Vector3.new(chest.X * 0.96, long * s, 0.1 * s), CFrame.new(0, chest.Y / 2 - long * s / 2 + 0.05 * s, chest.Z / 2 + 0.08 * s) * CFrame.Angles(-0.06, 0, 0), color, FABRIC)
	if trim then figure.add("UpperTorso", "CapeCollar", Vector3.new(chest.X * 0.7, 0.34 * s, 0.4 * s), CFrame.new(0, chest.Y / 2 + 0.05 * s, chest.Z / 2 - 0.05 * s), trim, FABRIC) end
end

local function belt(figure, color, buckle)
	local p = figure.parts.LowerTorso.Size
	figure.add("LowerTorso", "Belt", Vector3.new(p.X * 1.04, p.Y * 0.42, p.Z * 1.06), CFrame.new(0, p.Y * 0.26, 0), color, METAL)
	if buckle then figure.add("LowerTorso", "Buckle", Vector3.new(0.34, 0.26, 0.08) * figure.scale, CFrame.new(0, p.Y * 0.26, -p.Z * 0.54), buckle, METAL) end
end

-- A five-point star on a plate facing the offset's -Z: a disc and five
-- diamond tips, which reads as a star from the game camera.
local function star(figure, host, offset, radius, color)
	for i = 0, 4 do
		local angle = i * 2 * math.pi / 5
		figure.add(host, "Star", Vector3.new(radius * 0.42, radius * 0.42, 0.05), offset * CFrame.Angles(0, 0, -angle) * CFrame.new(0, radius * 0.6, 0) * CFrame.Angles(0, 0, math.pi / 4), color, METAL)
	end
	return figure.disc(host, "Star", radius * 0.8, 0.06, offset, color, METAL)
end

local HERO_EXTRAS = {}
HERO_EXTRAS.ironman = function(f)
	local s, h = f.scale, f.parts.Head.Size
	-- The helmet: a gold faceplate, glowing slits and a mouth line.
	f.add("Head", "FacePlate", Vector3.new(h.X * 0.7, h.Y * 0.66, 0.1 * s), f.face(0, -0.08, -0.02), HC.gold, METAL)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Visor", Vector3.new(0.3, 0.1, 0.06) * s, f.face(side * 0.22, 0.1, 0.04) * CFrame.Angles(0, 0, -side * 0.16), HC.energy, NEON)
		f.add("UpperTorso", "ChestPlate", Vector3.new(0.8, 0.62, 0.08) * s, CFrame.new(side * 0.5 * s, 0.26 * s, -f.sizes.chest.Z / 2 - 0.03 * s), HC.red:Lerp(HC.white, 0.1), METAL)
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "ShoulderPlate", f.sizes.upperArm * Vector3.new(1.18, 0.46, 1.16), CFrame.new(0, f.sizes.upperArm.Y * 0.3, 0), HC.red, METAL)
		f.disc(side < 0 and "LeftHand" or "RightHand", "Repulsor", 0.34 * s, 0.06 * s, CFrame.new(0, -f.sizes.hand.Y / 2 - 0.02 * s, 0) * CFrame.Angles(math.pi / 2, 0, 0), HC.energy, NEON)
	end
	f.add("Head", "MouthLine", Vector3.new(0.34, 0.05, 0.05) * s, f.face(0, -0.4, 0.04), HC.gold:Lerp(HC.ink, 0.45), METAL)
	f.disc("UpperTorso", "ReactorHousing", 0.58 * s, 0.08 * s, CFrame.new(0, 0.22 * s, -f.sizes.chest.Z / 2 - 0.05 * s), HC.gold, METAL)
	f.disc("UpperTorso", "Reactor", 0.4 * s, 0.06 * s, CFrame.new(0, 0.22 * s, -f.sizes.chest.Z / 2 - 0.09 * s), HC.energy, NEON)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.captain = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	-- An open-jaw helmet: skin chin, white "A", small white wings.
	f.add("Head", "Chin", Vector3.new(h.X * 0.66, h.Y * 0.38, 0.1 * s), f.face(0, -0.52, -0.03), HC.skin, FABRIC)
	f.add("Head", "Mouth", Vector3.new(0.26, 0.06, 0.05) * s, f.face(0, -0.52, 0.04), HC.ink, FABRIC)
	f.add("Head", "HelmetLetter", Vector3.new(0.22, 0.28, 0.05) * s, f.face(0, 0.56, 0.02), HC.white, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Eye", Vector3.new(0.17, 0.26, 0.06) * s, f.face(side * 0.26, 0.14, 0.0), HC.ink, FABRIC, "ball")
		f.add("Head", "HelmetWing", Vector3.new(0.08, 0.3, 0.46) * s, CFrame.new(side * h.X * 0.52, h.Y * 0.14, 0) * CFrame.Angles(-0.4, 0, 0), HC.white, FABRIC, "wedge")
	end
	-- Stripes on the belly and the star on the chest.
	for i = -1, 1 do f.add("UpperTorso", "UniformStripe", Vector3.new(0.3 * s, c.Y * 0.4, 0.06 * s), CFrame.new(i * 0.34 * s, -c.Y * 0.28, -c.Z / 2 - 0.02 * s), i == 0 and HC.white or HC.red, FABRIC) end
	star(f, "UpperTorso", CFrame.new(0, c.Y * 0.18, -c.Z / 2 - 0.04 * s), 0.46 * s, HC.white)
	belt(f, HC.leather, HC.gold)
	-- The shield rides on the left forearm, face out.
	local rings = { { 2.3, HC.red }, { 1.86, HC.white }, { 1.42, HC.red }, { 0.96, HC.blue } }
	local arm = f.sizes.lowerArm
	for i, ring in ipairs(rings) do
		f.add("LeftLowerArm", i == 1 and "Shield" or "ShieldBand", Vector3.new(0.12 * s, ring[1] * s, ring[1] * s), CFrame.new(-arm.X / 2 - 0.1 * s - i * 0.03 * s, 0, -0.1 * s), ring[2], METAL, Enum.PartType.Cylinder)
	end
	star(f, "LeftLowerArm", CFrame.new(-arm.X / 2 - 0.26 * s, 0, -0.1 * s) * CFrame.Angles(0, math.pi / 2, 0), 0.32 * s, HC.white)
	muzzle(f, "LeftLowerArm", Vector3.new(-arm.X / 2 - 0.3 * s, 0, 0))
end
HERO_EXTRAS.spiderman = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	Figure.Face(f, "lens", { width = 0.46, height = 0.36, slant = 0.42 })
	-- The mask's web: spokes from between the eyes and two rings.
	for spoke = 0, 5 do
		local angle = spoke * math.pi / 3 + math.pi / 6
		f.add("Head", "WebLine", Vector3.new(0.035 * s, h.Y * 0.5, 0.04 * s), f.face(math.sin(angle) * 0.42, 0.1 + math.cos(angle) * 0.42, 0.005) * CFrame.Angles(0, 0, -angle), HC.ink, FABRIC)
	end
	-- Blue sides of the suit and the black spider.
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "SuitSide", Vector3.new(0.3 * s, c.Y * 0.96, c.Z * 1.02), CFrame.new(side * (c.X / 2 - 0.14 * s), -0.02 * s, 0), HC.blue, FABRIC)
		for i = 1, 3 do
			f.add("UpperTorso", "SpiderLeg", Vector3.new(0.34 * s, 0.05 * s, 0.05 * s), CFrame.new(side * 0.2 * s, (0.36 - i * 0.12) * s, -c.Z / 2 - 0.03 * s) * CFrame.Angles(0, 0, side * (0.6 - i * 0.35)), HC.ink, FABRIC)
		end
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "SleeveSide", f.sizes.upperArm * Vector3.new(0.5, 1.0, 1.02), CFrame.new(side * f.sizes.upperArm.X * 0.28, 0, 0), HC.blue, FABRIC)
	end
	f.add("UpperTorso", "SpiderEmblem", Vector3.new(0.18, 0.42, 0.06) * s, CFrame.new(0, 0.24 * s, -c.Z / 2 - 0.04 * s), HC.ink, FABRIC, "ball")
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.08 * s, 0))
end
HERO_EXTRAS.hulk = function(f)
	local s, c = f.scale, f.sizes.chest
	-- Muscle: pecs and a ridge of abs over the bare chest; torn purple shorts.
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "Pectoral", Vector3.new(c.X * 0.42, c.Y * 0.36, 0.2 * s), CFrame.new(side * c.X * 0.22, c.Y * 0.16, -c.Z / 2 - 0.02 * s), HC.green:Lerp(HC.white, 0.06), FABRIC, "ball")
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "Bicep", f.sizes.upperArm * Vector3.new(0.8, 0.5, 0.74), CFrame.new(0, 0.05 * s, -f.sizes.upperArm.Z * 0.2), HC.green:Lerp(HC.white, 0.05), FABRIC, "ball")
		local leg = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		for i = -1, 1 do
			f.add(leg, "ShortsTear", Vector3.new(f.sizes.upperLeg.X * 0.34, 0.26 * s, f.sizes.upperLeg.Z * 1.04), CFrame.new(i * f.sizes.upperLeg.X * 0.32, -f.sizes.upperLeg.Y / 2 - 0.1 * s + math.abs(i) * 0.08 * s, 0) * CFrame.Angles(0, 0, math.pi), HC.purple, FABRIC, "wedge")
		end
	end
	for row = 0, 1 do
		for _, side in ipairs({ -1, 1 }) do
			f.add("UpperTorso", "Ab", Vector3.new(c.X * 0.18, c.Y * 0.14, 0.14 * s), CFrame.new(side * c.X * 0.1, -c.Y * (0.14 + row * 0.18), -c.Z / 2 - 0.02 * s), HC.green:Lerp(HC.ink, 0.06), FABRIC)
		end
	end
	f.add("LowerTorso", "Waistband", f.sizes.pelvis * Vector3.new(1.04, 0.3, 1.06), CFrame.new(0, f.sizes.pelvis.Y * 0.3, 0), HC.purple:Lerp(HC.ink, 0.3), FABRIC)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2, 0))
end
HERO_EXTRAS.hawkeye = function(f)
	local s = f.scale
	local hand = f.sizes.hand
	-- The bow in the left hand, an arrow nocked; a quiver on the back.
	local limbs = { Vector3.new(0, 1.4, -0.3), Vector3.new(0, 0.7, -0.62), Vector3.new(0, 0, -0.7), Vector3.new(0, -0.7, -0.62), Vector3.new(0, -1.4, -0.3) }
	for i = 1, #limbs - 1 do f.rod("LeftHand", "Bow", limbs[i] * s, limbs[i + 1] * s, 0.14 * s, Color3.fromRGB(96, 52, 120), METAL) end
	f.rod("LeftHand", "Bowstring", limbs[1] * s, limbs[#limbs] * s, 0.03 * s, HC.silver, METAL)
	f.add("UpperTorso", "Quiver", Vector3.new(0.5, 1.7, 0.5) * s, CFrame.new(0.4 * s, 0.2 * s, f.sizes.chest.Z / 2 + 0.25 * s) * CFrame.Angles(0, 0, -0.35), HC.leather, FABRIC)
	for i = 1, 3 do f.add("UpperTorso", "QuiverArrow", Vector3.new(0.06, 0.6, 0.06) * s, CFrame.new((0.62 + i * 0.1) * s, 1.1 * s, f.sizes.chest.Z / 2 + 0.25 * s) * CFrame.Angles(0, 0, -0.35), HC.silver, METAL) end
	f.rod("UpperTorso", "Harness", Vector3.new(-f.sizes.chest.X * 0.4, f.sizes.chest.Y * 0.44, -f.sizes.chest.Z / 2 - 0.03 * s), Vector3.new(f.sizes.chest.X * 0.4, -f.sizes.chest.Y * 0.44, -f.sizes.chest.Z / 2 - 0.03 * s), 0.14 * s, HC.leather, FABRIC)
	muzzle(f, "LeftHand", Vector3.new(0, 0, -0.75 * s))
end
HERO_EXTRAS.thor = function(f)
	local s, c = f.scale, f.sizes.chest
	cape(f, Color3.fromRGB(176, 30, 38), 3.6)
	for _, side in ipairs({ -1, 1 }) do
		for row = 0, 1 do f.disc("UpperTorso", "ArmorDisc", 0.44 * s, 0.06 * s, CFrame.new(side * c.X * 0.22, c.Y * (0.18 - row * 0.3), -c.Z / 2 - 0.04 * s), HC.silver, METAL) end
	end
	f.add("Head", "Beard", Vector3.new(f.parts.Head.Size.X * 0.6, 0.3 * s, 0.1 * s), f.face(0, -0.66, -0.02), HC.gold:Lerp(HC.ink, 0.2), FABRIC)
	-- Mjolnir in the right hand.
	f.rod("RightHand", "HammerHandle", Vector3.new(0, 0, 0), Vector3.new(0, -1.1 * s, 0), 0.2 * s, HC.leather, FABRIC)
	f.add("RightHand", "Mjolnir", Vector3.new(1.3, 0.8, 0.8) * s, CFrame.new(0, -1.35 * s, 0), HC.silver, METAL)
	muzzle(f, "RightHand", Vector3.new(0, -1.35 * s, 0))
end
HERO_EXTRAS.widow = function(f)
	local s = f.scale
	belt(f, HC.steel, Color3.fromRGB(200, 40, 40))
	for _, side in ipairs({ -1, 1 }) do
		local hand = side < 0 and "LeftHand" or "RightHand"
		f.add(hand, "Pistol", Vector3.new(0.16, 0.7, 0.34) * s, CFrame.new(0, -0.35 * s, -0.08 * s), HC.ink, METAL)
		f.add(side < 0 and "LeftLowerArm" or "RightLowerArm", "Bracelet", f.sizes.lowerArm * Vector3.new(1.08, 0.2, 1.08), CFrame.new(0, -f.sizes.lowerArm.Y * 0.36, 0), HC.gold, METAL)
	end
	f.add("UpperTorso", "WidowInsignia", Vector3.new(0.3, 0.3, 0.05) * s, CFrame.new(0, -0.3 * s, -f.sizes.chest.Z / 2 - 0.03 * s) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(210, 40, 40), NEON)
	muzzle(f, "RightHand", Vector3.new(0, -0.75 * s, -0.08 * s))
end
HERO_EXTRAS.falcon = function(f)
	local s, c = f.scale, f.sizes.chest
	f.add("Head", "Goggles", Vector3.new(f.parts.Head.Size.X * 0.84, 0.24 * s, 0.1 * s), f.face(0, 0.14, 0.03), Color3.fromRGB(210, 40, 44), NEON)
	f.add("UpperTorso", "Jetpack", Vector3.new(c.X * 0.66, c.Y * 0.8, 0.46 * s), CFrame.new(0, 0.05 * s, c.Z / 2 + 0.22 * s), HC.steel, METAL)
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "Wing", Vector3.new(2.6 * s, 0.1 * s, 0.9 * s), CFrame.new(side * (c.X * 0.33 + 1.1 * s), 0.3 * s, c.Z / 2 + 0.3 * s) * CFrame.Angles(0, side * 0.4, side * 0.5), HC.silver, METAL, "wedge")
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.bucky = function(f)
	local s = f.scale
	-- Only the left arm is metal.
	f.parts.RightUpperArm.Color, f.parts.RightLowerArm.Color, f.parts.RightHand.Color = Color3.fromRGB(46, 52, 62), Color3.fromRGB(46, 52, 62), HC.skin
	for i = 1, 3 do f.add("LeftUpperArm", "ArmPlate", f.sizes.upperArm * Vector3.new(1.04, 0.06, 1.04), CFrame.new(0, f.sizes.upperArm.Y * (0.3 - i * 0.18), 0), HC.steel, METAL) end
	f.add("LeftUpperArm", "RedStar", Vector3.new(0.06, 0.26, 0.26) * s, CFrame.new(-f.sizes.upperArm.X / 2 - 0.02 * s, 0.1 * s, 0), Color3.fromRGB(200, 40, 40), METAL)
	f.add("RightHand", "Rifle", Vector3.new(0.22, 1.6, 0.34) * s, CFrame.new(0, -0.7 * s, -0.12 * s), HC.ink, METAL)
	f.add("RightHand", "RifleBarrel", Vector3.new(0.1, 0.8, 0.1) * s, CFrame.new(0, -1.8 * s, -0.12 * s), HC.steel, METAL)
	belt(f, HC.leather, HC.silver)
	muzzle(f, "RightHand", Vector3.new(0, -2.2 * s, -0.12 * s))
end
HERO_EXTRAS.antman = function(f)
	local s, h = f.scale, f.parts.Head.Size
	f.add("Head", "HelmetJaw", Vector3.new(h.X * 0.8, h.Y * 0.4, 0.12 * s), f.face(0, -0.5, -0.03), HC.ink, METAL)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "RedLens", Vector3.new(0.4, 0.3, 0.06) * s, f.face(side * 0.26, 0.14, 0.02), Color3.fromRGB(230, 40, 40), NEON, "ball")
		f.rod("Head", "Antenna", Vector3.new(side * h.X * 0.4, h.Y * 0.3, 0), Vector3.new(side * h.X * 0.62, h.Y * 0.95, 0.1 * s), 0.08 * s, HC.silver, METAL)
		f.disc("Head", "Respirator", 0.26 * s, 0.1 * s, f.face(side * 0.3, -0.42, 0.04), HC.silver, METAL)
	end
	belt(f, HC.silver)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.wasp = function(f)
	local s, c = f.scale, f.sizes.chest
	Figure.Face(f, "lens", { lens = Color3.fromRGB(110, 190, 255), width = 0.46, height = 0.34, slant = 0.3 })
	for _, side in ipairs({ -1, 1 }) do
		for _, up in ipairs({ 1, -1 }) do
			local wing = f.add("UpperTorso", "Wing", Vector3.new(1.4 * s, 0.05 * s, 0.7 * s), CFrame.new(side * 0.8 * s, up * 0.35 * s, c.Z / 2 + 0.2 * s) * CFrame.Angles(0, side * 0.3, side * up * 0.45), Color3.fromRGB(190, 230, 255), Enum.Material.Glass, "ball")
			wing.Transparency = 0.35
		end
		f.rod("Head", "Antenna", Vector3.new(side * 0.2 * s, 0.5 * s, -0.3 * s), Vector3.new(side * 0.4 * s, 0.95 * s, -0.4 * s), 0.06 * s, HC.ink, FABRIC)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.rocket = function(f)
	local s, h = f.scale, f.parts.Head.Size
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Ear", Vector3.new(0.34, 0.44, 0.14) * h.X / 1.36, CFrame.new(side * h.X * 0.4, h.Y * 0.56, 0) * CFrame.Angles(0, 0, -side * 0.2), Color3.fromRGB(120, 80, 56), FABRIC, "wedge")
	end
	f.add("Head", "Snout", Vector3.new(h.X * 0.44, h.Y * 0.26, h.Z * 0.24), f.face(0, -0.32, 0.04), Color3.fromRGB(220, 200, 180), FABRIC, "ball")
	f.add("Head", "Nose", Vector3.new(0.18, 0.12, 0.08) * h.X / 1.36, f.face(0, -0.22, 0.12), HC.ink, FABRIC, "ball")
	f.add("LowerTorso", "Tail", Vector3.new(0.5, 0.5, 1.4) * s, CFrame.new(0, -0.1 * s, f.sizes.pelvis.Z / 2 + 0.6 * s) * CFrame.Angles(-0.5, 0, 0), Color3.fromRGB(120, 80, 56), FABRIC, "ball")
	-- A cannon bigger than he is, held in both hands.
	f.add("RightHand", "BigGun", Vector3.new(0.5, 2.2, 0.6) * s, CFrame.new(-0.2 * s, -0.9 * s, -0.2 * s), HC.steel, METAL)
	f.add("RightHand", "GunMuzzle", Vector3.new(0.6, 0.3, 0.6) * s, CFrame.new(-0.2 * s, -2.05 * s, -0.2 * s), HC.energy, NEON)
	muzzle(f, "RightHand", Vector3.new(-0.2 * s, -2.2 * s, -0.2 * s))
end
HERO_EXTRAS.daredevil = function(f)
	local s, h = f.scale, f.parts.Head.Size
	f.add("Head", "Chin", Vector3.new(h.X * 0.6, h.Y * 0.36, 0.1 * s), f.face(0, -0.52, -0.03), HC.skin, FABRIC)
	f.add("Head", "Mouth", Vector3.new(0.24, 0.06, 0.05) * s, f.face(0, -0.52, 0.04), HC.ink, FABRIC)
	Figure.Face(f, "lens", { lens = Color3.fromRGB(96, 18, 26), rim = Color3.fromRGB(96, 18, 26), width = 0.34, height = 0.22, slant = 0.3 })
	for _, side in ipairs({ -1, 1 }) do f.add("Head", "Horn", Vector3.new(0.14, 0.34, 0.14) * s, CFrame.new(side * h.X * 0.3, h.Y * 0.55, -h.Z * 0.1) * CFrame.Angles(0, 0, -side * 0.3), Color3.fromRGB(148, 26, 34), FABRIC, "wedge") end
	f.rod("RightHand", "Billy", Vector3.new(0, 0.2 * s, 0), Vector3.new(0, -1.3 * s, -0.1 * s), 0.14 * s, Color3.fromRGB(120, 20, 28), METAL)
	muzzle(f, "RightHand", Vector3.new(0, -1.3 * s, -0.1 * s))
end
HERO_EXTRAS.shangchi = function(f)
	local s = f.scale
	local forearm = f.sizes.lowerArm
	for i = 1, 5 do
		f.add("LeftLowerArm", "TenRing", Vector3.new(0.07 * s, forearm.X * 1.5, forearm.X * 1.5), CFrame.new(0, (0.45 - i * 0.15) * forearm.Y, 0) * CFrame.Angles(0, 0, math.pi / 2), HC.gold, NEON, Enum.PartType.Cylinder)
	end
	f.add("UpperTorso", "Sash", Vector3.new(f.sizes.chest.X * 1.02, 0.24 * s, f.sizes.chest.Z * 1.04), CFrame.new(0, -f.sizes.chest.Y * 0.36, 0), HC.gold, FABRIC)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.panther = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	Figure.Face(f, "lens", { width = 0.36, height = 0.2, slant = 0.36 })
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Ear", Vector3.new(0.3, 0.36, 0.12) * s, CFrame.new(side * h.X * 0.34, h.Y * 0.56, 0) * CFrame.Angles(0, 0, -side * 0.22), HC.ink, METAL, "wedge")
		f.rod("Head", "MaskTrace", Vector3.new(side * h.X * 0.42, h.Y * 0.36, -h.Z * 0.5 - 0.02 * s), Vector3.new(side * h.X * 0.1, -h.Y * 0.3, -h.Z * 0.5 - 0.02 * s), 0.05 * s, HC.silver, METAL)
		for i = -1, 1 do f.add(side < 0 and "LeftHand" or "RightHand", "Claw", Vector3.new(0.06, 0.34, 0.06) * s, CFrame.new(i * 0.16 * s, -f.sizes.hand.Y / 2 - 0.14 * s, -0.12 * s), HC.silver, METAL) end
	end
	for i = -2, 2 do f.add("UpperTorso", "NecklaceFang", Vector3.new(0.12, 0.3, 0.08) * s, CFrame.new(i * 0.24 * s, c.Y * 0.4 - math.abs(i) * 0.06 * s, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, i * 0.3), HC.silver, METAL) end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.2 * s, 0))
end
HERO_EXTRAS.vision = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	f.add("Head", "MindGem", Vector3.new(0.24, 0.3, 0.08) * s, f.face(0, 0.5, 0.03) * CFrame.Angles(0, 0, math.pi / 4), HC.yellow, NEON)
	cape(f, HC.gold, 3.4)
	f.add("UpperTorso", "ChestDiamond", Vector3.new(0.6, 0.6, 0.06) * s, CFrame.new(0, 0.1 * s, -c.Z / 2 - 0.03 * s) * CFrame.Angles(0, 0, math.pi / 4), HC.gold, METAL)
	muzzle(f, "Head", Vector3.new(0, h.Y * 0.25, -h.Z / 2 - 0.1 * s))
end
HERO_EXTRAS.warmachine = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	Figure.Face(f, "slits", { glow = Color3.fromRGB(255, 190, 90) })
	f.add("Head", "FacePlate", Vector3.new(h.X * 0.66, h.Y * 0.6, 0.08 * s), f.face(0, -0.1, -0.02), HC.steel:Lerp(HC.ink, 0.2), METAL)
	f.add("UpperTorso", "ShoulderCannon", Vector3.new(0.5, 0.5, 1.8) * s, CFrame.new(c.X * 0.36, c.Y / 2 + 0.3 * s, -0.2 * s), HC.ink, METAL)
	f.add("UpperTorso", "CannonMuzzle", Vector3.new(0.34, 0.34, 0.2) * s, CFrame.new(c.X * 0.36, c.Y / 2 + 0.3 * s, -1.1 * s), Color3.fromRGB(255, 190, 90), NEON)
	f.disc("UpperTorso", "Reactor", 0.36 * s, 0.06 * s, CFrame.new(0, 0.2 * s, -c.Z / 2 - 0.04 * s), HC.energy, NEON)
	muzzle(f, "UpperTorso", Vector3.new(c.X * 0.36, c.Y / 2 + 0.3 * s, -1.3 * s))
end
HERO_EXTRAS.starlord = function(f)
	local s, h = f.scale, f.parts.Head.Size
	Figure.Face(f, "lens", { lens = Color3.fromRGB(230, 60, 50), rim = HC.steel, glow = true, width = 0.42, height = 0.3, slant = 0.2 })
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EarPiece", Vector3.new(0.12, 0.44, 0.44) * s, CFrame.new(side * h.X * 0.52, 0, 0), HC.steel, METAL)
		local hand = side < 0 and "LeftHand" or "RightHand"
		f.add(hand, "Blaster", Vector3.new(0.2, 0.72, 0.34) * s, CFrame.new(0, -0.36 * s, -0.08 * s), HC.steel, METAL)
		f.add(hand, "BlasterGlow", Vector3.new(0.12, 0.12, 0.12) * s, CFrame.new(0, -0.74 * s, -0.08 * s), Color3.fromRGB(255, 120, 60), NEON)
	end
	f.add("UpperTorso", "Coat", Vector3.new(f.sizes.chest.X * 1.06, f.sizes.chest.Y * 1.5, f.sizes.chest.Z * 1.08), CFrame.new(0, -f.sizes.chest.Y * 0.28, 0.02 * s), Color3.fromRGB(110, 44, 42), FABRIC)
	muzzle(f, "RightHand", Vector3.new(0, -0.8 * s, -0.08 * s))
end
HERO_EXTRAS.groot = function(f)
	local s, h = f.scale, f.parts.Head.Size
	-- Bark ridges, a crown of twigs and leaves on the shoulders.
	for _, side in ipairs({ -1, 1 }) do
		f.rod("Head", "Twig", Vector3.new(side * h.X * 0.2, h.Y * 0.4, 0), Vector3.new(side * h.X * 0.5, h.Y * 0.95, 0.1 * s), 0.1 * s, Color3.fromRGB(96, 70, 46), Enum.Material.Wood)
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "Leaf", Vector3.new(0.6, 0.12, 0.4) * s, CFrame.new(0, f.sizes.upperArm.Y * 0.45, 0) * CFrame.Angles(0, 0, side * 0.4), Color3.fromRGB(96, 170, 72), Enum.Material.Grass, "ball")
		f.rod(side < 0 and "LeftHand" or "RightHand", "Root", Vector3.new(0, 0, 0), Vector3.new(side * 0.2 * s, -0.7 * s, -0.1 * s), 0.12 * s, Color3.fromRGB(96, 70, 46), Enum.Material.Wood)
	end
	for i = -1, 1 do f.add("UpperTorso", "Bark", Vector3.new(0.14 * s, f.sizes.chest.Y * 0.9, 0.06 * s), CFrame.new(i * f.sizes.chest.X * 0.28, 0, -f.sizes.chest.Z / 2 - 0.02 * s), Color3.fromRGB(88, 62, 40), Enum.Material.Wood) end
	-- A few leaves sprouting from the crown.
	for i = -1, 1 do f.add("Head", "Leaf", Vector3.new(0.36, 0.1, 0.24) * s, CFrame.new(i * h.X * 0.26, h.Y * 0.56, i * 0.1 * s) * CFrame.Angles(0.2, i * 0.6, i * 0.5), Color3.fromRGB(110, 190, 80), Enum.Material.Grass, "ball") end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.3 * s, 0))
end
HERO_EXTRAS.wanda = function(f)
	local s, h = f.scale, f.parts.Head.Size
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Crown", Vector3.new(0.1, 0.5, 0.08) * s, f.face(side * 0.2, 0.62, 0.03) * CFrame.Angles(0, 0, side * 0.45), Color3.fromRGB(196, 30, 60), METAL)
		local glow = f.add(side < 0 and "LeftHand" or "RightHand", "ChaosSpell", Vector3.new(0.62, 0.62, 0.62) * s, CFrame.new(0, -0.5 * s, -0.1 * s), Color3.fromRGB(248, 64, 104), NEON, "ball")
		glow.Transparency = 0.2
	end
	cape(f, Color3.fromRGB(150, 28, 56), 3.0)
	muzzle(f, "RightHand", Vector3.new(0, -0.5 * s, -0.1 * s))
end
HERO_EXTRAS.strange = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	f.add("Head", "Goatee", Vector3.new(0.3, 0.2, 0.06) * s, f.face(0, -0.58, 0.02), HC.ink, FABRIC)
	for _, side in ipairs({ -1, 1 }) do f.add("Head", "Temple", Vector3.new(0.08, 0.3, 0.3) * s, CFrame.new(side * h.X * 0.5, h.Y * 0.1, 0), HC.white, FABRIC) end
	cape(f, Color3.fromRGB(176, 34, 46), 3.4, Color3.fromRGB(176, 34, 46))
	belt(f, HC.leather, HC.gold)
	f.disc("UpperTorso", "Amulet", 0.44 * s, 0.08 * s, CFrame.new(0, c.Y * 0.3, -c.Z / 2 - 0.05 * s), HC.gold, METAL)
	f.disc("UpperTorso", "AmuletEye", 0.18 * s, 0.05 * s, CFrame.new(0, c.Y * 0.3, -c.Z / 2 - 0.1 * s), Color3.fromRGB(91, 230, 161), NEON)
	-- A glowing sigil in front of the left hand.
	for i = 0, 7 do
		local angle = i * math.pi / 4
		f.add("LeftHand", "SpellGlyph", Vector3.new(0.5, 0.06, 0.05) * s, CFrame.new(math.sin(angle) * 0.62 * s, -0.4 * s + math.cos(angle) * 0.62 * s, -0.5 * s) * CFrame.Angles(0, 0, -angle), HC.gold, NEON)
	end
	muzzle(f, "LeftHand", Vector3.new(0, -0.4 * s, -0.6 * s))
end
HERO_EXTRAS.ghostrider = function(f)
	local s, h = f.scale, f.parts.Head.Size
	for _, side in ipairs({ -1, 1 }) do f.add("Head", "Socket", Vector3.new(0.3, 0.34, 0.06) * s, f.face(side * 0.26, 0.1, 0.0), HC.ink, FABRIC, "ball") end
	f.add("Head", "Teeth", Vector3.new(0.5, 0.16, 0.06) * s, f.face(0, -0.44, 0.0), HC.ink, FABRIC)
	for i = -2, 2 do
		local flame = f.add("Head", "Flame", Vector3.new(0.34, 0.9 - math.abs(i) * 0.18, 0.34) * s, CFrame.new(i * h.X * 0.2, h.Y * 0.62, 0.05 * s), Color3.fromRGB(255, 130 + math.abs(i) * 20, 30), NEON, "ball")
		flame.Transparency = 0.1
	end
	f.add("UpperTorso", "Jacket", f.sizes.chest * Vector3.new(1.06, 1.02, 1.08), CFrame.new(), Color3.fromRGB(30, 30, 34), FABRIC)
	for _, side in ipairs({ -1, 1 }) do f.rod("UpperTorso", "Chain", Vector3.new(side * f.sizes.chest.X * 0.45, f.sizes.chest.Y * 0.46, -f.sizes.chest.Z * 0.56), Vector3.new(-side * f.sizes.chest.X * 0.1, -f.sizes.chest.Y * 0.4, -f.sizes.chest.Z * 0.56), 0.08 * s, HC.silver, METAL) end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.captainmarvel = function(f)
	local s, c = f.scale, f.sizes.chest
	star(f, "UpperTorso", CFrame.new(0, c.Y * 0.18, -c.Z / 2 - 0.04 * s), 0.4 * s, HC.gold)
	f.add("UpperTorso", "Sash", Vector3.new(c.X * 1.03, 0.2 * s, c.Z * 1.04), CFrame.new(0, -c.Y * 0.38, 0), HC.red, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add(side < 0 and "LeftHand" or "RightHand", "PhotonFist", Vector3.new(0.7, 0.62, 0.7) * s, CFrame.new(0, -0.05 * s, 0), Color3.fromRGB(255, 220, 110), NEON, "ball").Transparency = 0.45
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.silversurfer = function(f)
	local s = f.scale
	-- The board stands on its tail beside him, held in the left hand.
	f.add("LeftHand", "Board", Vector3.new(0.18, 3.8, 1.3) * s, CFrame.new(-0.4 * s, -0.7 * s, 0) * CFrame.Angles(0, 0, 0.08), Color3.fromRGB(226, 236, 246), METAL, "ball").Reflectance = 0.25
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.wolverine = function(f)
	local s, h = f.scale, f.parts.Head.Size
	Figure.Face(f, "lens", { width = 0.4, height = 0.26, slant = 0.5, lens = HC.white, rim = HC.ink })
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "MaskFin", Vector3.new(0.1, 0.9, 0.6) * s, CFrame.new(side * h.X * 0.46, h.Y * 0.5, 0) * CFrame.Angles(0, 0, -side * 0.35), HC.ink, FABRIC, "wedge")
		for i = -1, 1 do f.add(side < 0 and "LeftHand" or "RightHand", "AdamantiumClaw", Vector3.new(0.05, 0.8, 0.08) * s, CFrame.new(i * 0.14 * s, -f.sizes.hand.Y / 2 - 0.42 * s, -0.12 * s), HC.silver, METAL) end
	end
	belt(f, Color3.fromRGB(190, 40, 40), HC.gold)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.8 * s, -0.12 * s))
end
HERO_EXTRAS.cyclops = function(f)
	local s, h = f.scale, f.parts.Head.Size
	f.add("Head", "Chin", Vector3.new(h.X * 0.6, h.Y * 0.36, 0.1 * s), f.face(0, -0.52, -0.03), HC.skin, FABRIC)
	f.add("Head", "Visor", Vector3.new(h.X * 0.9, 0.24 * s, 0.14 * s), f.face(0, 0.14, 0.04), Color3.fromRGB(240, 40, 50), NEON)
	belt(f, HC.yellow, HC.navy)
	muzzle(f, "Head", Vector3.new(0, h.Y * 0.07, -h.Z / 2 - 0.2 * s))
end
HERO_EXTRAS.storm = function(f)
	cape(f, HC.white, 3.4)
	f.add("Head", "Tiara", Vector3.new(0.5, 0.14, 0.06) * f.scale, f.face(0, 0.46, 0.03), HC.gold, METAL)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * f.scale, 0))
end
HERO_EXTRAS.jean = function(f)
	local s, c = f.scale, f.sizes.chest
	f.add("UpperTorso", "PhoenixEmblem", Vector3.new(0.5, 0.36, 0.06) * s, CFrame.new(0, c.Y * 0.18, -c.Z / 2 - 0.03 * s), HC.gold, METAL, "wedge")
	belt(f, HC.gold)
	for _, side in ipairs({ -1, 1 }) do
		f.add(side < 0 and "LeftHand" or "RightHand", "Flame", Vector3.new(0.5, 0.7, 0.5) * s, CFrame.new(0, -0.45 * s, 0), Color3.fromRGB(255, 150, 60), NEON, "ball").Transparency = 0.3
	end
	muzzle(f, "RightHand", Vector3.new(0, -0.5 * s, 0))
end
HERO_EXTRAS.iceman = function(f)
	local s = f.scale
	for i = -1, 1 do f.add("Head", "IceSpike", Vector3.new(0.2, 0.44, 0.3) * s, CFrame.new(i * 0.34 * s, f.parts.Head.Size.Y * 0.55, 0) * CFrame.Angles(0, 0, -i * 0.3), Color3.fromRGB(210, 246, 255), Enum.Material.Ice, "wedge") end
	f.add("RightHand", "IceFist", Vector3.new(0.8, 0.8, 0.8) * s, CFrame.new(0, -0.1 * s, 0), Color3.fromRGB(210, 246, 255), Enum.Material.Ice, "ball").Transparency = 0.25
	muzzle(f, "RightHand", Vector3.new(0, -0.5 * s, 0))
end
HERO_EXTRAS.gambit = function(f)
	local s, c = f.scale, f.sizes.chest
	f.add("Head", "Cowl", Vector3.new(f.parts.Head.Size.X * 1.08, f.parts.Head.Size.Y * 0.56, f.parts.Head.Size.Z * 1.08), CFrame.new(0, f.parts.Head.Size.Y * 0.32, 0.03 * s), Color3.fromRGB(190, 88, 160), FABRIC, "ball")
	f.add("UpperTorso", "TrenchCoat", Vector3.new(c.X * 1.08, c.Y * 1.9, c.Z * 1.12), CFrame.new(0, -c.Y * 0.44, 0.02 * s), Color3.fromRGB(122, 74, 52), FABRIC)
	f.add("RightHand", "ChargedCard", Vector3.new(0.36, 0.5, 0.04) * s, CFrame.new(0, -0.4 * s, -0.15 * s), Color3.fromRGB(240, 90, 200), NEON)
	muzzle(f, "RightHand", Vector3.new(0, -0.5 * s, -0.15 * s))
end
HERO_EXTRAS.nightcrawler = function(f)
	local s = f.scale
	f.add("LowerTorso", "Tail", Vector3.new(0.14, 0.14, 2.2) * s, CFrame.new(0, -0.1 * s, f.sizes.pelvis.Z / 2 + 1 * s) * CFrame.Angles(-0.8, 0, 0), Color3.fromRGB(58, 62, 142), FABRIC)
	f.add("LowerTorso", "TailTip", Vector3.new(0.3, 0.3, 0.1) * s, CFrame.new(0, 0.7 * s, f.sizes.pelvis.Z / 2 + 1.75 * s) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(58, 62, 142), FABRIC)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.beast = function(f)
	local s = f.scale
	for _, side in ipairs({ -1, 1 }) do f.add(side < 0 and "LeftHand" or "RightHand", "FurryFist", f.sizes.hand * 1.12, CFrame.new(), Color3.fromRGB(83, 140, 205), FABRIC, "ball") end
	f.add("Head", "Fang", Vector3.new(0.4, 0.1, 0.05) * s, f.face(0, -0.52, 0.04), HC.white, FABRIC)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.psylocke = function(f)
	local s = f.scale
	f.add("Head", "MaskBand", Vector3.new(f.parts.Head.Size.X * 0.9, 0.2 * s, 0.06 * s), f.face(0, 0.14, 0.03), Color3.fromRGB(211, 95, 176), FABRIC)
	f.add("RightHand", "Blade", Vector3.new(0.12, 1.4, 0.3) * s, CFrame.new(0, -0.8 * s, -0.1 * s), Color3.fromRGB(240, 110, 220), NEON)
	f.add("UpperTorso", "Sash", Vector3.new(f.sizes.chest.X * 1.03, 0.22 * s, f.sizes.chest.Z * 1.04), CFrame.new(0, -f.sizes.chest.Y * 0.38, 0), Color3.fromRGB(211, 95, 176), FABRIC)
	muzzle(f, "RightHand", Vector3.new(0, -1.4 * s, -0.1 * s))
end
HERO_EXTRAS.deadpool = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyePatch", Vector3.new(0.5, 0.46, 0.05) * s, f.face(side * 0.28, 0.12, 0.0), HC.ink, FABRIC, "ball")
		f.add("Head", "Eye", Vector3.new(0.22, 0.14, 0.05) * s, f.face(side * 0.28, 0.12, 0.03) * CFrame.Angles(0, 0, side * 0.25), HC.white, FABRIC, "ball")
		f.add("UpperTorso", "Katana", Vector3.new(0.1, 2.4, 0.2) * s, CFrame.new(side * 0.34 * s, 0.9 * s, c.Z / 2 + 0.14 * s) * CFrame.Angles(0, 0, side * 0.3), HC.silver, METAL)
		f.add(side < 0 and "LeftHand" or "RightHand", "Pistol", Vector3.new(0.16, 0.66, 0.32) * s, CFrame.new(0, -0.33 * s, -0.08 * s), HC.ink, METAL)
	end
	belt(f, HC.ink, Color3.fromRGB(230, 200, 60))
	muzzle(f, "RightHand", Vector3.new(0, -0.7 * s, -0.08 * s))
end
HERO_EXTRAS.moonknight = function(f)
	local s = f.scale
	Figure.Face(f, "lens", { width = 0.3, height = 0.3, slant = 0.1, lens = HC.white, rim = HC.ink })
	f.add("Head", "Hood", f.parts.Head.Size * Vector3.new(1.12, 1.1, 1.0), CFrame.new(0, 0.04 * s, f.parts.Head.Size.Z * 0.24), HC.white, FABRIC, "ball")
	cape(f, HC.white, 3.6)
	f.add("UpperTorso", "Crescent", Vector3.new(0.5, 0.5, 0.06) * s, CFrame.new(0, f.sizes.chest.Y * 0.16, -f.sizes.chest.Z / 2 - 0.03 * s), Color3.fromRGB(195, 198, 202), METAL, "ball")
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.nova = function(f)
	local s, h = f.scale, f.parts.Head.Size
	f.add("Head", "Helmet", h * Vector3.new(1.06, 0.62, 1.06), CFrame.new(0, h.Y * 0.28, 0), HC.gold, METAL, "ball")
	f.add("Head", "Crest", Vector3.new(0.14, 0.5, 0.9) * s, CFrame.new(0, h.Y * 0.62, 0), HC.gold, METAL, "wedge")
	f.add("Head", "Visor", Vector3.new(h.X * 0.84, 0.2 * s, 0.1 * s), f.face(0, 0.12, 0.03), Color3.fromRGB(120, 220, 255), NEON)
	star(f, "UpperTorso", CFrame.new(0, f.sizes.chest.Y * 0.16, -f.sizes.chest.Z / 2 - 0.04 * s), 0.36 * s, HC.gold)
	muzzle(f, "Head", Vector3.new(0, h.Y * 0.1, -h.Z / 2 - 0.2 * s))
end

-- Faces for the heroes whose extras do not already draw one.
local DRAWN_FACE = { ironman = true, captain = true, spiderman = true, antman = true, wasp = true, daredevil = true, panther = true,
	warmachine = true, starlord = true, ghostrider = true, wolverine = true, cyclops = true, deadpool = true, moonknight = true, nova = true }

function Figure.Hero(parent, heroId, hero, scale)
	local look = HERO_LOOK[heroId] or { colors = { chest = rgb(hero.color) } }
	local spec = table.clone(look.body or {})
	spec.scale = (spec.scale or 1) * (scale or 1)
	local figure = Figure.Build(parent, spec, look.colors, look.material or Enum.Material.SmoothPlastic)
	figure.model:SetAttribute("HeroId", heroId)
	figure.model:SetAttribute("PoseStyle", HERO_POSE[heroId] or "shoot")
	if look.shiny then
		for _, item in ipairs(figure.model:GetChildren()) do if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then item.Reflectance = 0.1 end end
	end
	if look.hair then Figure.Hair(figure, look.hair[1], look.hair[2]) end
	if not DRAWN_FACE[heroId] then Figure.Face(figure, look.face or "smile", look.faceOptions) end
	local extras = HERO_EXTRAS[heroId]
	if extras then extras(figure) end
	if not figure.model:FindFirstChild("Muzzle", true) then muzzle(figure, "RightHand", Vector3.new(0, -figure.sizes.hand.Y / 2 - 0.1 * figure.scale, 0)) end
	return figure
end

-- Tower evolutions show on the hero: shoulder guards at level 2, glowing
-- bracers at 3, a chest crest at 4, and at 5 the branch's colour burns in
-- both hands and in a halo. Rebuilt from scratch on every upgrade.
function Figure.Gear(model, level, branch, tint)
	local figure = model and model:FindFirstChild("HeroFigure")
	if not figure or not figure:GetAttribute("HeroRig") then return end
	for _, item in ipairs(figure:GetDescendants()) do if item:IsA("BasePart") and item:GetAttribute("Gear") then item:Destroy() end end
	local s = figure:GetAttribute("FigureScale") or 1
	local function gear(host, name, size, offset, color, material, shape)
		local base = figure:FindFirstChild(host)
		if not base then return end
		local made = figurePart(figure, name, size, base.CFrame * offset, color, material or METAL)
		if shape == "ball" then local mesh = Instance.new("SpecialMesh"); mesh.MeshType, mesh.Parent = Enum.MeshType.Sphere, made
		elseif shape then made.Shape = shape end
		made:SetAttribute("Gear", true)
		made:SetAttribute("HeroVisual", true)
		made.Anchored = false
		figureWeld(base, made)
		return made
	end
	local warm, cool = Color3.fromRGB(255, 140, 60), Color3.fromRGB(90, 200, 255)
	local accent = branch == 1 and warm or (branch == 2 and cool or tint)
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "Left" or "Right"
		local upper, lower = figure:FindFirstChild(name .. "UpperArm"), figure:FindFirstChild(name .. "LowerArm")
		if level >= 2 and upper then
			gear(name .. "UpperArm", "GearShoulder", upper.Size * Vector3.new(1.3, 0.4, 1.3), CFrame.new(0, upper.Size.Y * 0.36, 0), tint:Lerp(FIGURE_WHITE, 0.2))
		end
		if level >= 3 and lower then
			gear(name .. "LowerArm", "GearBracer", lower.Size * Vector3.new(1.22, 0.34, 1.22), CFrame.new(0, -lower.Size.Y * 0.2, 0), accent, NEON)
		end
		if level >= 5 then
			local glow = gear(name .. "Hand", "GearFlare", Vector3.new(0.8, 0.8, 0.8) * s, CFrame.new(), accent, NEON, "ball")
			if glow then glow.Transparency = 0.45 end
		end
	end
	local chest, head = figure:FindFirstChild("UpperTorso"), figure:FindFirstChild("Head")
	if level >= 4 and chest then
		gear("UpperTorso", "GearCrest", Vector3.new(0.5, 0.5, 0.06) * s, CFrame.new(0, chest.Size.Y * 0.36, -chest.Size.Z / 2 - 0.08 * s) * CFrame.Angles(0, 0, math.pi / 4), accent, NEON)
	end
	if level >= 5 and head then
		gear("Head", "GearHalo", Vector3.new(0.12, head.Size.X * 1.3, head.Size.X * 1.3), CFrame.new(0, head.Size.Y * 0.78, 0) * CFrame.Angles(0, 0, math.pi / 2), accent, NEON, Enum.PartType.Cylinder).Transparency = 0.25
	end
end


-- Only the root stays anchored: the body hangs from it on its joints, so the
-- client can pose it and a single PivotTo moves everything.
function Figure.Release(figure)
	for _, item in ipairs(figure.model:GetDescendants()) do
		if item:IsA("BasePart") then item.Anchored = item == figure.parts.HumanoidRootPart end
	end
end

-- Enemies ---------------------------------------------------------------------
-- The infected used to be people: each keeps the clothes it was wearing (the
-- client tints every "shirt" and "pants" piece per enemy, so a crowd is never
-- one uniform). Families differ by body, posture, gear and gait, not colour.
local EC = {
	infected = Color3.fromRGB(128, 170, 104), pale = Color3.fromRGB(150, 176, 132), dark = Color3.fromRGB(96, 132, 78),
	shirt = Color3.fromRGB(176, 58, 52), pants = Color3.fromRGB(48, 66, 104), eye = Color3.fromRGB(190, 255, 110),
	metal = Color3.fromRGB(104, 117, 128), ink = FIGURE_INK, bone = Color3.fromRGB(232, 226, 204),
}

-- Each family's body, how it walks (Motion reads Gait) and its base colours.
local ENEMY_LOOK = {
	zombie = { gait = "shamble", body = { scale = 0.8 }, skin = EC.infected },
	runner = { gait = "sprint", body = { scale = 0.78, width = 0.86, arm = 0.86, leg = 0.88, legLength = 1.1 }, skin = EC.pale },
	brute = { gait = "stomp", body = { scale = 1.02, width = 1.42, depth = 1.25, chest = 1.26, head = 0.72, arm = 1.75, hand = 1.35, leg = 1.45, legLength = 0.82 }, skin = EC.dark },
	armored = { gait = "march", body = { scale = 0.84, width = 1.1, arm = 1.06, leg = 1.04 }, skin = EC.infected },
	stealth = { gait = "sneak", body = { scale = 0.8, width = 0.84, arm = 0.84, leg = 0.86 }, skin = Color3.fromRGB(136, 150, 140) },
	flyer = { gait = "hover", body = { scale = 0.72, width = 0.9, arm = 0.9, leg = 0.84, legLength = 0.9 }, skin = EC.infected },
	support = { gait = "march", body = { scale = 0.84, width = 1.04 }, skin = Color3.fromRGB(150, 210, 110) },
	summoner = { gait = "glide", body = { scale = 0.9, width = 0.94 }, skin = Color3.fromRGB(170, 160, 190) },
	illusion = { gait = "glide", body = { scale = 1.25, width = 0.92, arm = 0.9 }, skin = Color3.fromRGB(226, 206, 184) },
	lizard = { gait = "reptile", body = { scale = 1.55, width = 1.16, depth = 1.1, head = 1.02, arm = 1.12, hand = 1.3, leg = 1.2, legLength = 0.9 }, skin = Color3.fromRGB(96, 170, 70) },
	abomination = { gait = "stomp", body = { scale = 1.8, width = 1.46, depth = 1.3, chest = 1.3, head = 0.78, arm = 1.7, hand = 1.4, leg = 1.45, legLength = 0.84 }, skin = Color3.fromRGB(128, 136, 80) },
	redskull = { gait = "march", body = { scale = 1.45, width = 1.04 }, skin = Color3.fromRGB(206, 52, 44) },
	killmonger = { gait = "stalk", body = { scale = 1.45, width = 1.08, arm = 1.06 }, skin = Color3.fromRGB(96, 64, 46) },
	doom = { gait = "regal", body = { scale = 1.55, width = 1.14, arm = 1.1, leg = 1.08 }, skin = Color3.fromRGB(150, 160, 166) },
	loki = { gait = "glide", body = { scale = 1.45, width = 0.92, arm = 0.9 }, skin = Color3.fromRGB(226, 206, 184) },
}
Figure.EnemyLook = ENEMY_LOOK

local function tinted(part, kind)
	part:SetAttribute("Tint", kind)
	return part
end

-- The infected face: mismatched glowing eyes, heavy brow and a dark jaw.
local function infectedFace(f, eye)
	local k = f.parts.Head.Size.X / BODY.head.X
	for _, side in ipairs({ -1, 1 }) do
		local size = side < 0 and Vector3.new(0.26, 0.28, 0.06) or Vector3.new(0.2, 0.22, 0.06)
		f.add("Head", "Socket", (size + Vector3.new(0.1, 0.1, 0)) * k, f.face(side * 0.28, 0.12, -0.01), EC.ink, FABRIC, "ball")
		f.add("Head", "Eye", size * k, f.face(side * 0.28, 0.12, 0.02), eye or EC.eye, NEON, "ball")
	end
	f.add("Head", "Brow", Vector3.new(0.9, 0.14, 0.12) * k, f.face(0, 0.42, -0.02), f.parts.Head.Color:Lerp(EC.ink, 0.35), FABRIC)
	f.add("Head", "Jaw", Vector3.new(0.46, 0.2, 0.06) * k, f.face(0.04, -0.42, 0.0), EC.ink, FABRIC, "ball")
	f.add("Head", "Tooth", Vector3.new(0.1, 0.08, 0.05) * k, f.face(-0.08, -0.36, 0.02), EC.bone, FABRIC)
end

-- Clothes: a shirt over chest and upper arms, pants over hips and thighs.
local function clothes(f, sleeves, shorts)
	for _, name in ipairs({ "UpperTorso", sleeves and "LeftUpperArm" or nil, sleeves and "RightUpperArm" or nil }) do tinted(f.parts[name], "shirt") end
	for _, name in ipairs({ "LowerTorso", "LeftUpperLeg", "RightUpperLeg", not shorts and "LeftLowerLeg" or nil, not shorts and "RightLowerLeg" or nil }) do tinted(f.parts[name], "pants") end
	-- A torn hem and a rip across the chest.
	local c = f.sizes.chest
	f.add("UpperTorso", "Tear", Vector3.new(c.X * 0.24, c.Y * 0.22, 0.05 * f.scale), CFrame.new(c.X * 0.22, -c.Y * 0.2, -c.Z / 2 - 0.02 * f.scale) * CFrame.Angles(0, 0, 0.4), f.parts.Head.Color, FABRIC)
end

local FACTION_GEAR = {
	sinister = function(f)
		local c = f.sizes.chest
		f.add("UpperTorso", "Vest", c * Vector3.new(1.06, 0.86, 1.08), CFrame.new(0, c.Y * 0.06, 0), Color3.fromRGB(164, 92, 49), FABRIC)
		f.add("Head", "Bandana", f.parts.Head.Size * Vector3.new(0.9, 0.34, 0.2), f.face(0, -0.42, 0.02), Color3.fromRGB(176, 48, 44), FABRIC)
	end,
	gamma = function(f)
		for _, side in ipairs({ -1, 1 }) do
			f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "Growth", f.sizes.upperArm * Vector3.new(1.3, 0.6, 1.3), CFrame.new(0, f.sizes.upperArm.Y * 0.3, 0), Color3.fromRGB(120, 200, 80), Enum.Material.Slate, "ball")
		end
		f.add("UpperTorso", "GammaGlow", Vector3.new(0.4, 0.4, 0.05) * f.scale, CFrame.new(0, f.sizes.chest.Y * 0.1, -f.sizes.chest.Z / 2 - 0.03 * f.scale), Color3.fromRGB(160, 255, 90), NEON, "ball")
	end,
	hydra = function(f)
		local h = f.parts.Head.Size
		f.add("Head", "Helmet", h * Vector3.new(1.1, 0.62, 1.1), CFrame.new(0, h.Y * 0.3, 0), Color3.fromRGB(58, 84, 70), FABRIC, "ball")
		f.add("UpperTorso", "HydraBadge", Vector3.new(0.36, 0.36, 0.05) * f.scale, CFrame.new(0, f.sizes.chest.Y * 0.2, -f.sizes.chest.Z / 2 - 0.03 * f.scale), Color3.fromRGB(210, 40, 40), NEON, "ball")
	end,
	vibranium = function(f)
		local h = f.parts.Head.Size
		f.add("Head", "Helmet", h * Vector3.new(1.1, 0.6, 1.1), CFrame.new(0, h.Y * 0.3, 0), Color3.fromRGB(96, 62, 140), METAL, "ball")
		f.add("UpperTorso", "VibraniumTrace", Vector3.new(0.12, f.sizes.chest.Y * 0.8, 0.05) * Vector3.new(f.scale, 1, f.scale), CFrame.new(0, 0, -f.sizes.chest.Z / 2 - 0.03 * f.scale), Color3.fromRGB(200, 150, 255), NEON)
	end,
	doombot = function(f)
		-- A robot, not an infected: the face becomes an iron mask with slits.
		for _, item in ipairs(f.model:GetChildren()) do
			if item:IsA("BasePart") and (item.Name == "Socket" or item.Name == "Eye" or item.Name == "Jaw" or item.Name == "Tooth" or item.Name == "Brow" or item.Name == "Hair") then item:Destroy() end
		end
		for _, side in ipairs({ -1, 1 }) do
			f.add("Head", "Slit", Vector3.new(0.3, 0.08, 0.05) * f.scale, f.face(side * 0.24, 0.14, 0.03), Color3.fromRGB(110, 255, 150), NEON)
		end
		for i = -1, 1 do f.add("Head", "Grille", Vector3.new(0.05, 0.26, 0.05) * f.scale, f.face(i * 0.12, -0.42, 0.03), EC.ink, METAL) end
		for _, item in ipairs(f.model:GetChildren()) do
			if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then item.Color, item.Reflectance = Color3.fromRGB(150, 164, 170), 0.12; item:SetAttribute("Tint", nil) end
		end
		local h = f.parts.Head.Size
		f.add("Head", "Hood", h * Vector3.new(1.12, 0.9, 1.0), CFrame.new(0, h.Y * 0.2, h.Z * 0.24), Color3.fromRGB(41, 90, 58), FABRIC, "ball")
		f.add("UpperTorso", "Tunic", f.sizes.chest * Vector3.new(1.04, 0.7, 1.06), CFrame.new(0, -f.sizes.chest.Y * 0.16, 0), Color3.fromRGB(41, 90, 58), FABRIC)
	end,
}

local ENEMY_EXTRAS = {}
ENEMY_EXTRAS.zombie = function(f, def)
	clothes(f, true)
	infectedFace(f)
	if not def.faction then Figure.Hair(f, Color3.fromRGB(60, 44, 32)) end
end
ENEMY_EXTRAS.runner = function(f)
	clothes(f, false, true)
	infectedFace(f)
	f.add("Head", "Headband", f.parts.Head.Size * Vector3.new(1.04, 0.14, 1.04), CFrame.new(0, f.parts.Head.Size.Y * 0.3, 0), Color3.fromRGB(200, 60, 52), FABRIC)
	f.add("UpperTorso", "Scarf", Vector3.new(0.4, 0.16, 1.8) * f.scale, CFrame.new(0.2 * f.scale, f.sizes.chest.Y * 0.4, f.sizes.chest.Z / 2 + 0.7 * f.scale) * CFrame.Angles(-0.35, 0, 0), Color3.fromRGB(235, 156, 73), FABRIC)
end
ENEMY_EXTRAS.brute = function(f)
	clothes(f, false)
	infectedFace(f, Color3.fromRGB(255, 190, 80))
	local c = f.sizes.chest
	f.add("UpperTorso", "Hump", Vector3.new(c.X * 0.7, c.Y * 0.5, c.Z * 0.5), CFrame.new(0, c.Y * 0.28, c.Z * 0.42), f.parts.Head.Color:Lerp(EC.ink, 0.1), FABRIC, "ball")
	for _, side in ipairs({ -1, 1 }) do
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "Vein", Vector3.new(0.08, f.sizes.upperArm.Y * 0.7, 0.08) * Vector3.new(f.scale, 1, f.scale), CFrame.new(side * f.sizes.upperArm.X * 0.3, 0, -f.sizes.upperArm.Z / 2), Color3.fromRGB(150, 220, 90), NEON)
	end
end
ENEMY_EXTRAS.armored = function(f)
	clothes(f, true)
	infectedFace(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	f.add("Head", "Helmet", h * Vector3.new(1.12, 0.66, 1.12), CFrame.new(0, h.Y * 0.28, 0), EC.metal, METAL, "ball").Reflectance = 0.1
	f.add("UpperTorso", "Plate", c * Vector3.new(0.86, 0.72, 0.3), CFrame.new(0, c.Y * 0.06, -c.Z / 2 - 0.1 * s), EC.metal, METAL).Reflectance = 0.1
	for _, side in ipairs({ -1, 1 }) do
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "Pauldron", f.sizes.upperArm * Vector3.new(1.4, 0.5, 1.36), CFrame.new(0, f.sizes.upperArm.Y * 0.32, 0), EC.metal, METAL)
	end
	local arm = f.sizes.lowerArm
	f.add("LeftLowerArm", "Shield", Vector3.new(0.18, 1.8, 1.2) * s, CFrame.new(-arm.X / 2 - 0.12 * s, 0.1 * s, -0.1 * s), Color3.fromRGB(70, 88, 100), METAL)
end
ENEMY_EXTRAS.stealth = function(f)
	clothes(f, true)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	for _, side in ipairs({ -1, 1 }) do f.add("Head", "Eye", Vector3.new(0.2, 0.08, 0.05) * s, f.face(side * 0.26, 0.1, 0.02) * CFrame.Angles(0, 0, -side * 0.2), Color3.fromRGB(220, 150, 255), NEON) end
	f.add("Head", "Hood", h * Vector3.new(1.14, 1.1, 1.0), CFrame.new(0, 0.06 * s, h.Z * 0.24), Color3.fromRGB(49, 38, 68), FABRIC, "ball")
	f.add("Head", "Veil", h * Vector3.new(0.92, 0.4, 0.1), f.face(0, -0.36, 0.02), Color3.fromRGB(49, 38, 68), FABRIC)
	f.add("UpperTorso", "Cloak", Vector3.new(c.X * 1.08, c.Y * 2.2, 0.12 * s), CFrame.new(0, -c.Y * 0.5, c.Z / 2 + 0.08 * s), Color3.fromRGB(72, 48, 96), FABRIC)
end
ENEMY_EXTRAS.flyer = function(f)
	clothes(f, true)
	infectedFace(f)
	local c, s = f.sizes.chest, f.scale
	f.add("Head", "Goggles", f.parts.Head.Size * Vector3.new(0.9, 0.24, 0.12), f.face(0, 0.14, 0.03), Color3.fromRGB(106, 245, 207), NEON)
	f.add("UpperTorso", "Jetpack", Vector3.new(c.X * 0.6, c.Y * 0.8, 0.6 * s), CFrame.new(0, 0, c.Z / 2 + 0.3 * s), Color3.fromRGB(70, 78, 88), METAL)
	f.add("UpperTorso", "Thruster", Vector3.new(0.4, 0.5, 0.4) * s, CFrame.new(0, -c.Y * 0.56, c.Z / 2 + 0.32 * s), Color3.fromRGB(106, 245, 207), NEON)
	-- Wings hang on their own joints, so they flap.
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "Left" or "Right"
		local wing = figurePart(f.model, name .. "Wing", Vector3.new(2.4, 0.12, 1.1) * s, f.parts.UpperTorso.CFrame * CFrame.new(side * (c.X * 0.3 + 1.2 * s), c.Y * 0.2, c.Z / 2 + 0.3 * s) * CFrame.Angles(0, side * 0.3, 0), Color3.fromRGB(58, 120, 104), METAL)
		wing:SetAttribute("HeroVisual", true)
		f.parts[name .. "Wing"] = wing
		f.joints[name .. "Wing"] = figureJoint(name .. "Wing", f.parts.UpperTorso, wing, (f.parts.UpperTorso.CFrame * CFrame.new(side * c.X * 0.3, c.Y * 0.2, c.Z / 2 + 0.3 * s)).Position)
	end
end
ENEMY_EXTRAS.support = function(f)
	clothes(f, true)
	infectedFace(f)
	local c, s = f.sizes.chest, f.scale
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "Tank", Vector3.new(0.5, 1.3, 0.5) * s, CFrame.new(side * 0.34 * s, 0.1 * s, c.Z / 2 + 0.3 * s), Color3.fromRGB(174, 248, 115), NEON, Enum.PartType.Cylinder)
	end
	f.add("UpperTorso", "Pack", Vector3.new(c.X * 0.72, c.Y * 0.6, 0.3 * s), CFrame.new(0, -0.1 * s, c.Z / 2 + 0.12 * s), Color3.fromRGB(80, 90, 96), METAL)
	-- The emitter on its chest pulses toward the infected it hastens.
	for _, side in ipairs({ -1, 1 }) do f.rod("UpperTorso", "Strap", Vector3.new(side * c.X * 0.3, c.Y * 0.5, -c.Z / 2 - 0.03 * s), Vector3.new(side * c.X * 0.3, -c.Y * 0.3, -c.Z / 2 - 0.03 * s), 0.14 * s, Color3.fromRGB(80, 90, 96), METAL) end
	f.disc("UpperTorso", "Emitter", 0.6 * s, 0.1 * s, CFrame.new(0, c.Y * 0.08, -c.Z / 2 - 0.06 * s), Color3.fromRGB(174, 248, 115), NEON)
	f.rod("UpperTorso", "Antenna", Vector3.new(0.36 * s, c.Y * 0.4, c.Z / 2 + 0.2 * s), Vector3.new(0.4 * s, c.Y * 0.4 + 1.3 * s, c.Z / 2 + 0.3 * s), 0.08 * s, Color3.fromRGB(80, 90, 96), METAL)
	f.add("UpperTorso", "AntennaLight", Vector3.new(0.26, 0.26, 0.26) * s, CFrame.new(0.4 * s, c.Y * 0.4 + 1.4 * s, c.Z / 2 + 0.3 * s), Color3.fromRGB(174, 248, 115), NEON, "ball")
end
ENEMY_EXTRAS.summoner = function(f)
	local h, c, p, s = f.parts.Head.Size, f.sizes.chest, f.sizes.pelvis, f.scale
	local robe = Color3.fromRGB(65, 37, 86)
	for _, name in ipairs({ "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm" }) do f.parts[name].Color = robe end
	for _, side in ipairs({ -1, 1 }) do f.add("Head", "Eye", Vector3.new(0.2, 0.2, 0.05) * s, f.face(side * 0.26, 0.1, 0.02), Color3.fromRGB(220, 131, 255), NEON, "ball") end
	f.add("Head", "Hood", h * Vector3.new(1.16, 1.12, 1.0), CFrame.new(0, 0.08 * s, h.Z * 0.24), robe, FABRIC, "ball")
	-- A robe to the ground hides the legs; the staff's orbs count the summons.
	local skirtHeight = f.parts.LowerTorso.Position.Y
	f.add("LowerTorso", "Robe", Vector3.new(p.X * 1.24, skirtHeight + p.Y * 0.4, p.Z * 1.3), CFrame.new(0, -skirtHeight / 2 + p.Y * 0.2, 0), robe, FABRIC)
	f.add("UpperTorso", "Mantle", c * Vector3.new(1.2, 0.4, 1.3), CFrame.new(0, c.Y * 0.36, 0), robe:Lerp(FIGURE_WHITE, 0.08), FABRIC)
	f.rod("RightHand", "Staff", Vector3.new(0, 1.6 * s, -0.1 * s), Vector3.new(0, -2.2 * s, -0.1 * s), 0.14 * s, Color3.fromRGB(89, 65, 100), METAL)
	f.add("RightHand", "Orb", Vector3.new(0.6, 0.6, 0.6) * s, CFrame.new(0, 1.9 * s, -0.1 * s), Color3.fromRGB(220, 131, 255), NEON, Enum.PartType.Ball)
	for index = 1, 2 do
		f.add("RightHand", "Charge", Vector3.new(0.3, 0.3, 0.3) * s, CFrame.new((index == 1 and -0.36 or 0.36) * s, 1.55 * s, -0.1 * s), Color3.fromRGB(240, 190, 255), NEON, Enum.PartType.Ball)
	end
end

-- Bosses: one on the field at a time, so each spends real detail on its own
-- silhouette instead of reading as a scaled-up infected.
ENEMY_EXTRAS.lizard = function(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	local scale = f.parts.Head.Color
	local coat = Color3.fromRGB(236, 238, 232)
	for _, name in ipairs({ "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }) do f.parts[name].Color = Color3.fromRGB(84, 54, 120) end
	f.parts.UpperTorso.Color = Color3.fromRGB(196, 206, 214)
	-- A long snout with teeth, slit-pupil eyes and a crest down the back.
	f.add("Head", "Snout", Vector3.new(h.X * 0.7, h.Y * 0.44, h.Z * 0.7), CFrame.new(0, -h.Y * 0.18, -h.Z * 0.56), scale, FABRIC)
	f.add("Head", "Teeth", Vector3.new(h.X * 0.64, 0.1 * s, h.Z * 0.5), CFrame.new(0, -h.Y * 0.4, -h.Z * 0.6), EC.bone, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Eye", Vector3.new(0.3, 0.26, 0.06) * s, f.face(side * 0.32, 0.22, 0.0), Color3.fromRGB(255, 214, 60), NEON, "ball")
		f.add("Head", "Pupil", Vector3.new(0.06, 0.22, 0.05) * s, f.face(side * 0.32, 0.22, 0.03), EC.ink, FABRIC)
		-- The lab coat: open front panels over the chest, tails to the knee.
		f.add("UpperTorso", "Coat", Vector3.new(c.X * 0.36, c.Y * 1.02, c.Z * 1.08), CFrame.new(side * c.X * 0.33, 0, 0.01 * s), coat, FABRIC)
		f.add("LowerTorso", "CoatTail", Vector3.new(f.sizes.pelvis.X * 0.52, 1.8 * s, 0.12 * s), CFrame.new(side * f.sizes.pelvis.X * 0.26, -0.8 * s, f.sizes.pelvis.Z / 2 + 0.06 * s), coat, FABRIC)
		for i = -1, 1 do f.add(side < 0 and "LeftHand" or "RightHand", "Claw", Vector3.new(0.08, 0.3, 0.08) * s, CFrame.new(i * 0.16 * s, -f.sizes.hand.Y / 2 - 0.1 * s, -0.1 * s), EC.bone, FABRIC) end
	end
	for i = 0, 3 do f.add("UpperTorso", "Crest", Vector3.new(0.1, 0.44 - i * 0.07, 0.4) * s, CFrame.new(0, c.Y * (0.46 - i * 0.28), c.Z / 2 + 0.1 * s), scale:Lerp(FIGURE_WHITE, 0.3), FABRIC, "wedge") end
	-- The tail swings on four joints.
	local previous, at = f.parts.LowerTorso, f.parts.LowerTorso.CFrame * CFrame.new(0, -0.1 * s, f.sizes.pelvis.Z / 2)
	for i = 1, 4 do
		local length = (1.2 - i * 0.16) * s
		local width = (0.8 - i * 0.14) * s
		local segment = figurePart(f.model, "Tail" .. i, Vector3.new(width, width * 0.9, length), at * CFrame.Angles(i == 1 and 0.45 or 0.08, 0, 0) * CFrame.new(0, 0, length / 2), scale, FABRIC)
		segment:SetAttribute("HeroVisual", true)
		f.joints["Tail" .. i] = figureJoint("Tail" .. i, previous, segment, at.Position)
		previous, at = segment, segment.CFrame * CFrame.new(0, 0, length / 2)
	end
end
ENEMY_EXTRAS.abomination = function(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	local ridge = f.parts.Head.Color:Lerp(FIGURE_WHITE, 0.15)
	infectedFace(f, Color3.fromRGB(255, 140, 50))
	-- Bare, scaly skin above ragged dark shorts.
	f.parts.UpperTorso.Color = f.parts.Head.Color
	for _, name in ipairs({ "LowerTorso", "LeftUpperLeg", "RightUpperLeg" }) do f.parts[name].Color = Color3.fromRGB(58, 52, 44) end
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg" }) do f.parts[name].Color = f.parts.Head.Color end
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Fin", Vector3.new(0.12, 0.8, 0.7) * s, CFrame.new(side * h.X * 0.52, h.Y * 0.1, 0.1 * s) * CFrame.Angles(0.3, 0, -side * 0.4), ridge, FABRIC, "wedge")
		f.add("Head", "Gill", Vector3.new(0.06, 0.3, 0.26) * s, CFrame.new(side * h.X * 0.5, -h.Y * 0.25, -0.1 * s), EC.ink, FABRIC)
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "ScaleRidge", f.sizes.upperArm * Vector3.new(0.5, 0.8, 0.5), CFrame.new(side * f.sizes.upperArm.X * 0.35, 0, f.sizes.upperArm.Z * 0.2), ridge, Enum.Material.Slate, "ball")
	end
	for i = 0, 4 do f.add("UpperTorso", "Spine", Vector3.new(0.2, 0.6 - i * 0.06, 0.5) * s, CFrame.new(0, c.Y * (0.44 - i * 0.2), c.Z / 2 + 0.1 * s) * CFrame.Angles(0.4, 0, 0), ridge, FABRIC, "wedge") end
end
ENEMY_EXTRAS.redskull = function(f)
	local h, c, p, s = f.parts.Head.Size, f.sizes.chest, f.sizes.pelvis, f.scale
	local coat = Color3.fromRGB(38, 34, 40)
	for _, name in ipairs({ "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }) do f.parts[name].Color = coat end
	for _, name in ipairs({ "LeftHand", "RightHand", "LeftFoot", "RightFoot" }) do f.parts[name].Color = EC.ink end
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Socket", Vector3.new(0.36, 0.38, 0.06) * s, f.face(side * 0.28, 0.12, 0.0), EC.ink, FABRIC, "ball")
		f.add("Head", "Eye", Vector3.new(0.1, 0.1, 0.05) * s, f.face(side * 0.28, 0.12, 0.03), Color3.fromRGB(255, 90, 60), NEON, "ball")
		f.add("LowerTorso", "CoatTail", Vector3.new(p.X * 0.52, 1.9 * s, 0.14 * s), CFrame.new(side * p.X * 0.26, -0.85 * s, 0), coat, FABRIC)
	end
	f.add("Head", "Nose", Vector3.new(0.16, 0.18, 0.05) * s, f.face(0, -0.12, 0.0), EC.ink, FABRIC, "wedge")
	f.add("Head", "Teeth", Vector3.new(0.6, 0.2, 0.06) * s, f.face(0, -0.44, 0.0), EC.bone, FABRIC)
	f.add("UpperTorso", "Collar", c * Vector3.new(0.8, 0.26, 1.1), CFrame.new(0, c.Y * 0.44, 0), coat:Lerp(FIGURE_WHITE, 0.08), FABRIC)
	f.add("LeftUpperArm", "Armband", f.sizes.upperArm * Vector3.new(1.08, 0.26, 1.08), CFrame.new(0, -0.1 * s, 0), Color3.fromRGB(180, 30, 36), FABRIC)
	belt(f, Color3.fromRGB(70, 56, 40), Color3.fromRGB(214, 172, 72))
	f.add("RightHand", "Cube", Vector3.new(0.6, 0.6, 0.6) * s, CFrame.new(0, -0.5 * s, -0.1 * s) * CFrame.Angles(0.6, 0.6, 0), Color3.fromRGB(110, 200, 255), NEON)
end
ENEMY_EXTRAS.killmonger = function(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	local suit, gold = Color3.fromRGB(34, 32, 38), Color3.fromRGB(212, 166, 71)
	for _, name in ipairs({ "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }) do f.parts[name].Color = suit end
	f.parts.Head.Color = gold
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Ear", Vector3.new(0.3, 0.38, 0.12) * s, CFrame.new(side * h.X * 0.34, h.Y * 0.56, 0) * CFrame.Angles(0, 0, -side * 0.22), gold, METAL, "wedge")
		f.add("Head", "Eye", Vector3.new(0.34, 0.16, 0.05) * s, f.face(side * 0.28, 0.14, 0.02) * CFrame.Angles(0, 0, side * 0.3), Color3.fromRGB(255, 240, 190), NEON, "ball")
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "Pauldron", f.sizes.upperArm * Vector3.new(1.3, 0.44, 1.3), CFrame.new(0, f.sizes.upperArm.Y * 0.32, 0), gold, METAL)
		f.add("UpperTorso", "Trace", Vector3.new(0.08 * s, c.Y * 0.8, 0.05 * s), CFrame.new(side * c.X * 0.2, 0, -c.Z / 2 - 0.03 * s) * CFrame.Angles(0, 0, side * 0.25), Color3.fromRGB(255, 196, 90), NEON)
		for i = -1, 1 do f.add(side < 0 and "LeftHand" or "RightHand", "Claw", Vector3.new(0.07, 0.34, 0.07) * s, CFrame.new(i * 0.16 * s, -f.sizes.hand.Y / 2 - 0.14 * s, -0.1 * s), gold, METAL) end
	end
	f.add("Head", "Muzzle", Vector3.new(0.5, 0.3, 0.08) * s, f.face(0, -0.36, 0.02), gold:Lerp(EC.ink, 0.5), METAL)
	for i = -2, 2 do f.add("UpperTorso", "Fang", Vector3.new(0.12, 0.32, 0.08) * s, CFrame.new(i * 0.22 * s, c.Y * 0.38 - math.abs(i) * 0.05 * s, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, i * 0.25), EC.bone, FABRIC) end
end
ENEMY_EXTRAS.doom = function(f)
	local h, c, p, s = f.parts.Head.Size, f.sizes.chest, f.sizes.pelvis, f.scale
	local cloth, gold, armor = Color3.fromRGB(41, 90, 58), Color3.fromRGB(214, 172, 72), Color3.fromRGB(150, 160, 166)
	for _, item in ipairs(f.model:GetChildren()) do if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then item.Color, item.Reflectance = armor, 0.14 end end
	f.parts.UpperTorso.Color, f.parts.LowerTorso.Color = cloth, cloth
	f.parts.UpperTorso.Reflectance, f.parts.LowerTorso.Reflectance = 0, 0
	-- The iron mask: slits, a grille, under a green hood; a cape and a tunic.
	f.add("Head", "Mask", Vector3.new(h.X * 0.78, h.Y * 0.8, 0.12 * s), f.face(0, -0.06, -0.02), armor:Lerp(FIGURE_WHITE, 0.12), METAL).Reflectance = 0.2
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Slit", Vector3.new(0.3, 0.08, 0.05) * s, f.face(side * 0.24, 0.14, 0.06), Color3.fromRGB(110, 255, 150), NEON)
		f.add("UpperTorso", "Clasp", Vector3.new(0.3, 0.3, 0.1) * s, CFrame.new(side * c.X * 0.36, c.Y * 0.4, -c.Z / 2 - 0.05 * s), gold, METAL, Enum.PartType.Ball)
	end
	for i = -1, 1 do f.add("Head", "Grille", Vector3.new(0.05, 0.28, 0.05) * s, f.face(i * 0.12, -0.44, 0.06), EC.ink, METAL) end
	f.add("Head", "Hood", h * Vector3.new(1.18, 1.14, 1.0), CFrame.new(0, 0.1 * s, h.Z * 0.26), cloth, FABRIC, "ball")
	f.add("LowerTorso", "Tunic", Vector3.new(p.X * 1.12, 1.3 * s, p.Z * 1.14), CFrame.new(0, -0.5 * s, 0), cloth, FABRIC)
	cape(f, cloth, 4.2)
	belt(f, Color3.fromRGB(70, 60, 44), gold)
end
ENEMY_EXTRAS.loki = function(f)
	local h, c, p, s = f.parts.Head.Size, f.sizes.chest, f.sizes.pelvis, f.scale
	local leather, gold, cape_ = Color3.fromRGB(30, 44, 36), Color3.fromRGB(226, 183, 72), Color3.fromRGB(38, 102, 58)
	for _, name in ipairs({ "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }) do f.parts[name].Color = leather end
	Figure.Face(f, "fierce", { eye = Color3.fromRGB(40, 110, 60) })
	Figure.Hair(f, EC.ink, "long")
	-- The horned helmet: a gold cap and two horns sweeping back.
	f.add("Head", "Helmet", h * Vector3.new(1.1, 0.5, 1.1), CFrame.new(0, h.Y * 0.36, 0), gold, METAL, "ball")
	for _, side in ipairs({ -1, 1 }) do
		f.rod("Head", "Horn", Vector3.new(side * h.X * 0.3, h.Y * 0.5, -h.Z * 0.4), Vector3.new(side * h.X * 0.62, h.Y * 1.2, -h.Z * 0.1), 0.2 * s, gold, METAL)
		f.rod("Head", "Horn", Vector3.new(side * h.X * 0.62, h.Y * 1.2, -h.Z * 0.1), Vector3.new(side * h.X * 0.78, h.Y * 1.6, h.Z * 0.5), 0.14 * s, gold, METAL)
		f.add("UpperTorso", "Trim", Vector3.new(0.14 * s, c.Y * 0.9, 0.05 * s), CFrame.new(side * c.X * 0.2, 0, -c.Z / 2 - 0.03 * s), gold, METAL)
	end
	f.add("UpperTorso", "Collar", c * Vector3.new(0.9, 0.24, 1.1), CFrame.new(0, c.Y * 0.44, 0), gold, METAL)
	cape(f, cape_, 4)
	f.add("LowerTorso", "Coat", Vector3.new(p.X * 1.1, 1.5 * s, p.Z * 1.1), CFrame.new(0, -0.6 * s, 0), leather:Lerp(cape_, 0.3), FABRIC)
	f.rod("RightHand", "Scepter", Vector3.new(0, 0.6 * s, -0.1 * s), Vector3.new(0, -2.6 * s, -0.1 * s), 0.14 * s, gold, METAL)
	f.add("RightHand", "Gem", Vector3.new(0.36, 0.5, 0.36) * s, CFrame.new(0, -2.85 * s, -0.1 * s), Color3.fromRGB(90, 200, 255), NEON, "ball")
end
ENEMY_EXTRAS.illusion = ENEMY_EXTRAS.loki

function Figure.Enemy(parent, def)
	local family = def.family or def.id
	local look = ENEMY_LOOK[def.id] or ENEMY_LOOK[family] or ENEMY_LOOK.zombie
	local skin = look.skin
	local figure = Figure.Build(parent, look.body, { skin = skin, head = skin, chest = EC.shirt, pelvis = EC.pants, upperArm = skin, lowerArm = skin, hand = skin, upperLeg = EC.pants, lowerLeg = EC.pants, foot = EC.ink }, Enum.Material.SmoothPlastic)
	figure.model.Name = "EnemyFigure"
	figure.model:SetAttribute("EnemyId", def.id)
	figure.model:SetAttribute("Gait", look.gait)
	local extras = ENEMY_EXTRAS[def.id] or ENEMY_EXTRAS[family] or ENEMY_EXTRAS.zombie
	extras(figure, def)
	if def.faction and FACTION_GEAR[def.faction] then FACTION_GEAR[def.faction](figure) end
	Figure.Release(figure)
	return figure
end

-- Where a shot should land on this enemy (the chest of its figure). Flyers
-- are drawn with their chest at the eight studs the flight rules use.
local aimHeights = {}
function World:AimHeight(enemyId)
	return aimHeights[enemyId]
end

-- Every enemy's figure, built once on the server and cloned by each client.
function Figure.PublishEnemies(catalog)
	local storage = game:GetService("ReplicatedStorage")
	local folder = storage:FindFirstChild("DoomFigures")
	if folder then folder:Destroy() end
	folder = Instance.new("Folder")
	folder.Name = "DoomFigures"
	local enemies = Instance.new("Folder")
	enemies.Name, enemies.Parent = "Enemies", folder
	for id, def in pairs(catalog.Enemies) do
		local holder = Instance.new("Folder")
		local figure = Figure.Enemy(holder, def)
		figure.model.Name = id
		aimHeights[id] = def.air and 8 or figure.model:GetAttribute("ChestHeight")
		figure.model.Parent = enemies
		holder:Destroy()
	end
	folder.Parent = storage
	return folder
end

-- A hero's figure wherever it appears: the tower, the portrait, the training
-- yard. Final art from Studio wins; otherwise the jointed figure is built.
local function heroFigure(parent, heroId, hero, origin, scale)
	local template = artTemplate("Heroes", heroId)
	if template then return artFigure(parent, template, origin, (scale or 1) / (FIGURE_SCALE[heroId] or 1)) end
	-- Callers pass the old whole-figure scale; only the tower's emphasis over
	-- the hero's own size is kept (1.15 on a pedestal, 1 in a portrait).
	local emphasis = (scale or FIGURE_SCALE[heroId] or 1) / (FIGURE_SCALE[heroId] or 1)
	local figure = Figure.Hero(parent, heroId, hero, emphasis)
	Figure.Release(figure)
	figure.model:SetAttribute("HeroArt", true)
	figure.model:PivotTo(origin)
	parent:SetAttribute("FigureScale", figure.scale)
	return figure.parts.UpperTorso, figure.parts.Head
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
	{ kind = "pass", key = "vip" },
}

-- The lobby's districts around the central plaza. Each footprint is cleared
-- of scenery before its own floor and props are laid, so nothing from the
-- forest pokes through a shop counter or a portal pad.
local MARKET = { chestZ = 412, standZ = 436, standX = { -104, -90.5, -77, -63.5, -50 } }
local DISTRICTS = {
	{ id = "market", x0 = -114, x1 = -44, z0 = 394, z1 = 446, color = Color3.fromRGB(207, 180, 231),
		title = { "MERCADO", "MARKET" }, subtitle = { "BAÚS • LOJA ROBUX", "CHESTS • ROBUX SHOP" } },
	-- The three island extensions hold their portals' plazas.
	{ id = "special", x0 = -38, x1 = 38, z0 = 566, z1 = 612, color = Color3.fromRGB(177, 119, 243),
		title = { "TREINO E CARTAS", "TRAINING & CARDS" }, subtitle = { "APRENDA • ROGUELIKE DE CARTAS", "LEARN • CARD ROGUELIKE" } },
	{ id = "expeditionWest", x0 = -246, x1 = -216, z0 = 397, z1 = 455, color = Color3.fromRGB(203, 170, 255),
		title = { "EXPEDIÇÕES", "EXPEDITIONS" }, subtitle = { "WAKANDA • ASGARD", "WAKANDA • ASGARD" } },
	{ id = "expeditionEast", x0 = 216, x1 = 250, z0 = 440, z1 = 480, color = Color3.fromRGB(104, 232, 190),
		title = { "EXPEDIÇÃO FINAL", "FINAL EXPEDITION" }, subtitle = { "LATVÉRIA • 70 ONDAS", "LATVERIA • 70 WAVES" } },
	-- S.H.I.E.L.D. keeps the refuge: hangar, command post and armory on the
	-- main island's corners, on a steel deck instead of paving.
	{ id = "shieldHangar", x0 = -122, x1 = -65, z0 = 246, z1 = 284, color = Color3.fromRGB(84, 156, 232),
		floor = { Color3.fromRGB(70, 78, 88), Enum.Material.Concrete }, sign = { -71, 10, 281 },
		title = { "HANGAR DA S.H.I.E.L.D.", "S.H.I.E.L.D. HANGAR" }, subtitle = { "QUINJET PRONTO PARA DECOLAR", "QUINJET READY FOR TAKEOFF" } },
	{ id = "shieldCommand", x0 = 72, x1 = 112, z0 = 246, z1 = 284, color = Color3.fromRGB(84, 156, 232),
		floor = { Color3.fromRGB(70, 78, 88), Enum.Material.Concrete }, sign = { 75, 10, 281 },
		title = { "POSTO DE COMANDO", "COMMAND POST" }, subtitle = { "S.H.I.E.L.D. • VIGILÂNCIA DO REFÚGIO", "S.H.I.E.L.D. • REFUGE WATCH" } },
	{ id = "shieldArmory", x0 = 44, x1 = 114, z0 = 394, z1 = 446, color = Color3.fromRGB(84, 156, 232),
		floor = { Color3.fromRGB(70, 78, 88), Enum.Material.Concrete }, sign = { 50, 13, 398 },
		title = { "ARSENAL DA S.H.I.E.L.D.", "S.H.I.E.L.D. ARMORY" }, subtitle = { "AGENTES DE PLANTÃO", "AGENTS ON DUTY" } },
	{ id = "arena", x0 = 86, x1 = 140, z0 = 288, z1 = 392, color = Color3.fromRGB(255, 138, 61),
		title = { "ARENA COMPETITIVA", "COMPETITIVE ARENA" }, subtitle = { "3 MAPAS • PLACAR DA TEMPORADA", "3 MAPS • SEASON LEADERBOARD" } },
	{ id = "afk", x0 = -140, x1 = -86, z0 = 288, z1 = 392, color = Color3.fromRGB(120, 200, 255),
		title = { "ZONA AFK", "AFK ZONE" }, subtitle = { "FIQUE PARADO E GANHE", "STAND STILL AND EARN" } },
}
World.Districts = DISTRICTS

-- Training yard in front of the training and cards portals on the north
-- island, between their two lanes: a stage, a pad and three dummies. Watching
-- a hero attack here grants nothing; it only shows how far and how fast each
-- one reaches.
local TRAINING = { stage = Vector3.new(0, 0, 579), pad = Vector3.new(0, 0, 585.5),
	-- Narrow enough that, seen from the bridge, the dummies stay between the
	-- two portals instead of covering their "ENTER" plates.
	dummies = { Vector3.new(-4, 0, 573.5), Vector3.new(0, 0, 571.5), Vector3.new(4, 0, 573.5) } }
World.Training = TRAINING

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
	campaignWaves = catalog.CampaignWaves or {}
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
	-- Every enemy's jointed figure, cloned by the clients for the road.
	Figure.PublishEnemies(catalog)
	self:ApplyLobbyLighting()
	self:BuildLobby()
	return self
end

-- Each map's signature colour on portals and lobby signage.
local PORTAL_COLORS={manhattan={255,164,112},gamma={135,235,113},asgard={255,206,82},hydra={255,129,134},wakanda={203,170,255},latveria={104,232,190}}

-- Every mode is its own portal, and a portal is an elevator: stepping onto
-- its pad boards it and the match starts after a short countdown, with no
-- menu at all (ElevatorService owns the pad). The sign beside it is written
-- by each viewer's client with the map this portal will take *them* to, and
-- a portal they cannot use yet is shrouded locally, per viewer.
local function buildModePortal(lobby, x, z, portalId, mode, destination, map)
	local modeId=destination.modeId
	local tint = rgb(PORTAL_COLORS[destination.mapId])
	-- Everything is authored facing +Z (the spawn) and turned as one piece, so
	-- a district can face its portals toward its own entrance.
	local yaw = destination.facing or 0
	local base = CFrame.new(x, 0, z) * CFrame.Angles(0, yaw, 0)
	local function at(dx, y, dz) return base * CFrame.new(dx, y, dz) end
	local model = Instance.new("Model")
	model.Name, model.Parent = "Portal_" .. portalId, lobby
	model:SetAttribute("Kind", "ModePortal")
	model:SetAttribute("ModeId", modeId)
	model:SetAttribute("PortalId", portalId)
	model:SetAttribute("MapId", destination.mapId)
	model:SetAttribute("District", destination.district or "center")
	local plinth = part(model, "Plinth", Vector3.new(15, 1, 10), at(0, 0.5, 0), Color3.fromRGB(38, 50, 65), Enum.Material.DiamondPlate)
	local pad = part(model, "Pad", Vector3.new(12, 0.12, 7), at(0, 1.06, 0.5), tint, Enum.Material.Neon)
	pad.CanCollide, pad.Transparency = false, 0.35
	local ringFrame=at(0,7.5,-3.6)
	-- Eleven portals share the lobby's mobile part budget: segment counts are
	-- the lowest that still read as smooth rings from the plaza.
	arc(model,"PortalArmor",ringFrame,6.8,1.5,2.3,ART.pearl,Enum.Material.Metal,20)
	arc(model,"PortalGasket",ringFrame*CFrame.new(0,0,1.2),6.25,0.52,0.25,ART.ink,Enum.Material.Metal,20)
	arc(model,"Frame",ringFrame*CFrame.new(0,0,1.4),6.2,0.18,0.18,tint,Enum.Material.Neon,24)
	for i=0,7 do
		local a=i*math.pi/4
		artPart(model,"PortalBrace",Vector3.new(1.5,1.9,2.8),ringFrame*CFrame.Angles(0,0,a)*CFrame.new(0,7.1,0),ART.ink,Enum.Material.DiamondPlate)
		artPart(model,"PortalIndicator",Vector3.new(0.8,0.3,0.15),ringFrame*CFrame.Angles(0,0,a)*CFrame.new(0,7.1,1.5),tint,Enum.Material.Neon)
	end
	local glass = part(model, "Glass", Vector3.new(0.2,11.6,11.6), ringFrame*CFrame.Angles(0,math.pi/2,0), tint, Enum.Material.ForceField)
	glass.Shape,glass.Transparency=Enum.PartType.Cylinder,0.72
	for i=1,2 do
		arc(model,"PortalEcho",ringFrame*CFrame.new(0,0,-i*0.7),5.6-i*1.1,0.065,0.06,tint,Enum.Material.Neon,16)
	end
	emitter(glass, tint, 8, 3.5, 1.1, 1.6)
	emitter(pad, tint, 6, 2, 0.7, 1.2, Vector3.new(0, 5, 0))
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness, glow.Parent = tint, 18, 0.9, glass
	wallSign(model,"ModeHeader",at(0,17,-3.6)*CFrame.Angles(0,math.pi,0),Vector3.new(23,4.5,0.5),upper(map.name.pt),upper(mode.name.pt),tint)
	-- Small landmarks identify the destination even before the sign is read.
	for _,side in ipairs({-1,1}) do
		local landmark=at(side*10,0,-4)
		local function detail(name,size,offset,color,material)
			return artPart(model,name,size,landmark*offset,color,material)
		end
		if map.id=="manhattan" then
			detail("SkylineTower",Vector3.new(3.5,10,4),CFrame.new(0,5,0),Color3.fromRGB(123,91,72),Enum.Material.Brick)
			for floor=1,4 do
				for column=-1,1,2 do detail("SkylineWindow",Vector3.new(0.8,1,0.1),CFrame.new(column,1+floor*1.8,2.06),ART.gold,Enum.Material.Neon) end
			end
		elseif map.id=="gamma" then
			local tank=detail("GammaTank",Vector3.new(3.8,7,3.8),CFrame.new(0,3.5,0),Color3.fromRGB(89,111,81),Enum.Material.Metal)
			tank.Shape=Enum.PartType.Cylinder; tank.CFrame=landmark*CFrame.new(0,3.5,0)*CFrame.Angles(0,0,math.pi/2); tank.Size=Vector3.new(7,3.8,3.8)
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
	local sign = part(model, "Sign", Vector3.new(11, 2.2, 0.3), at(0, 1.9, 5.6) * CFrame.Angles(0, math.pi, 0), ART.ink, Enum.Material.Metal)
	local surface = Instance.new("SurfaceGui")
	surface.Name, surface.Face, surface.Parent = "Board", Enum.NormalId.Front, sign
	surface.LightInfluence, surface.SizingMode, surface.CanvasSize = 0, Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(280, 136)
	local text = Instance.new("TextLabel")
	text.Size, text.BackgroundTransparency, text.TextScaled, text.TextWrapped = UDim2.fromScale(1, 1), 1, true, true
	text.Font, text.TextColor3, text.Parent = Enum.Font.GothamBold, tint, surface
	local waves = (mode.id == "normal" and campaignWaves[destination.mapId]) or mode.waves
	text.Text = (waves == 0 and "ONDAS INFINITAS" or (tostring(waves) .. " ONDAS")) .. "\nENTRE PARA JOGAR"
	for _, p in ipairs(model:GetChildren()) do if p:IsA("BasePart") and p ~= plinth then p.CanCollide = false end end
	model.PrimaryPart = plinth
	-- The rider box is axis-aligned; a quarter turn swaps its width and depth.
	local sideways = math.abs(math.sin(yaw)) > 0.5
	return model, {
		center = at(0, 4, 0.5).Position, size = sideways and Vector3.new(7, 9, 12) or Vector3.new(12, 9, 7),
		-- Toward the district's entrance, clear of the pad and of the sign.
		exit = at(0, 4, 9).Position,
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

-- Z-fighting: two faces in one plane that overlap flicker as the camera
-- moves. Faces are compared when they are aligned with a world axis (nearly
-- every lobby surface: floors, trails, curbs, walls, signs). A pair is
-- harmless only when both parts are the same flat colour on an untextured
-- material; everything else is a flicker the players see.
local FLAT_MATERIALS = { [Enum.Material.SmoothPlastic] = true, [Enum.Material.Neon] = true, [Enum.Material.Glass] = true,
	[Enum.Material.ForceField] = true, [Enum.Material.Plastic] = true }
local function alignedFaces(item, out)
	if (item.Transparency or 0) >= 0.95 or not item.Size or not item.CFrame or item:FindFirstChildOfClass("SpecialMesh") then return end
	local shape = item:IsA("Part") and item.Shape or nil
	if shape == Enum.PartType.Ball then return end
	local wedge = item:IsA("WedgePart")
	local cf, size = item.CFrame, item.Size
	local axes, half = { cf.RightVector, cf.UpVector, cf.LookVector }, { size.X / 2, size.Y / 2, size.Z / 2 }
	for i = 1, 3 do
		-- A cylinder is flat only at its ends; a wedge only underneath and behind.
		if not (shape == Enum.PartType.Cylinder and i ~= 1) then
			local a = axes[i]
			local world = math.abs(a.X) > 0.999 and 1 or math.abs(a.Y) > 0.999 and 2 or math.abs(a.Z) > 0.999 and 3 or nil
			if world then
				for _, sign in ipairs({ -1, 1 }) do
					if not wedge or (i == 2 and sign < 0) or (i == 3 and sign > 0) then
						local center = cf.Position + a * (half[i] * sign)
						local c, e = { center.X, center.Y, center.Z }, { 0, 0, 0 }
						for j = 1, 3 do
							if j ~= i then
								local b = axes[j] * half[j]
								e[1] += math.abs(b.X); e[2] += math.abs(b.Y); e[3] += math.abs(b.Z)
							end
						end
						local normal = (world == 1 and a.X or world == 2 and a.Y or a.Z) * sign > 0 and 1 or -1
						-- Undersides rest on the ground or face it: nobody sees them.
						if not (world == 2 and normal < 0) then
							table.insert(out, { part = item, axis = world, plane = c[world], normal = normal,
								lo = { c[1] - e[1], c[2] - e[2], c[3] - e[3] }, hi = { c[1] + e[1], c[2] + e[2], c[3] + e[3] } })
						end
					end
				end
			end
		end
	end
end
local function sameLook(a, b)
	local ca, cb = a.Color, b.Color
	return a.Material == b.Material and FLAT_MATERIALS[a.Material] == true
		and math.abs(ca.R - cb.R) + math.abs(ca.G - cb.G) + math.abs(ca.B - cb.B) < 0.01
end
local function faceArea(face)
	local area = 1
	for k = 1, 3 do if k ~= face.axis then area *= face.hi[k] - face.lo[k] end end
	return area
end
local function coplanarPairs(root)
	local faces = {}
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("BasePart") and not item:IsA("MeshPart") then alignedFaces(item, faces) end
	end
	table.sort(faces, function(a, b)
		if a.axis ~= b.axis then return a.axis < b.axis end
		return a.plane < b.plane
	end)
	local found = {}
	for i = 1, #faces do
		local f = faces[i]
		for j = i + 1, #faces do
			local g = faces[j]
			if g.axis ~= f.axis or g.plane - f.plane > 0.012 then break end
			if g.part ~= f.part and g.normal == f.normal and not sameLook(f.part, g.part) then
				local overlapping = true
				for k = 1, 3 do
					if k ~= f.axis and math.min(f.hi[k], g.hi[k]) - math.max(f.lo[k], g.lo[k]) <= 0.02 then overlapping = false; break end
				end
				if overlapping then table.insert(found, { f, g }) end
			end
		end
	end
	return found
end
-- How many flickering pairs remain, and the first few by name for a report.
World.CoplanarConflicts = function(root)
	local found, names = coplanarPairs(root), {}
	for index = 1, math.min(#found, 8) do
		local f, g = found[index][1], found[index][2]
		table.insert(names, string.format("%s/%s@%s%.2f", f.part.Name, g.part.Name, ({ "x", "y", "z" })[f.axis], f.plane))
	end
	return #found, table.concat(names, " ")
end
-- Push the smaller face of every flickering pair out along its normal; the
-- big surface stays put. A few rounds settle stacks of three or more.
function World.SeparateCoplanar(root)
	for _ = 1, 24 do
		local found = coplanarPairs(root)
		if #found == 0 then return 0 end
		local moved = {}
		for _, pair in ipairs(found) do
			local f, g = pair[1], pair[2]
			if not moved[f.part] and not moved[g.part] then
				local face, other = f, g
				if faceArea(f) > faceArea(g) then face, other = g, f end
				-- Just beyond the other face, whichever side of it it started.
				local step = other.plane - face.plane + 0.04 * face.normal
				face.part.CFrame = face.part.CFrame + Vector3.new(face.axis == 1 and step or 0, face.axis == 2 and step or 0, face.axis == 3 and step or 0)
				moved[face.part] = true
			end
		end
	end
	return #coplanarPairs(root)
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

	-- The market fills the north-west corner: the Gold chests in front, the
	-- Robux counters along the back, both facing the plaza.
	local chestX = { rare = -80, base_rare = -50 }
	-- Two welcoming shop pads; all ten chest tiers live in the shop selector.
	for _, chestId in ipairs({"rare", "base_rare"}) do
		local _,zone=buildChestStand(lobby, chestX[chestId], MARKET.chestZ, chestId, self.catalog.Chests[chestId], self.openPanel)
		self.shopZones[chestId]=zone
	end
	wallSign(lobby, "ChestShopSign", CFrame.new(-65, 11, MARKET.chestZ + 7), Vector3.new(16, 3.4, 0.5),
		"LOJA DE BAÚS", "OURO / GOLD", ART.gold)

	-- The premium row: everything sold for Robux.
	local showcase = self.catalog.Heroes.silversurfer
	for index, entry in ipairs(SHOP_STANDS) do
		local pass = entry.kind == "pass" and self.catalog.Products.Passes[entry.key]
		local displayName = pass and pass.name.pt or (entry.kind == "hero" and "Vitrine de Heróis" or "Cofre de Ouro")
		buildShopStand(lobby, MARKET.standX[index], MARKET.standZ, entry.kind, entry.key, displayName, self.openPanel, entry.kind == "hero" and showcase or nil)
	end
	wallSign(lobby, "PremiumShopSign", CFrame.new(-77, 12.5, MARKET.standZ + 6.5), Vector3.new(18, 3.4, 0.5),
		"LOJA ROBUX", "ROBUX", Color3.fromRGB(207, 180, 231))

	-- Mission board and hall-of-fame totem flank the bridge entrance.
	local _, questsText = buildBoard(lobby, -23, 393, "quests", "MISSÕES", self.openPanel)
	-- Like the service desks: a coloured title and a small how-to line.
	questsText.TextScaled, questsText.RichText, questsText.TextSize = false, true, 36
	questsText:SetAttribute("LobbyTextPT", '<font color="#8fd07a">MISSÕES</font>\n<font size="17" color="#b8cdd8">TOQUE OU PRESSIONE E</font>')
	questsText:SetAttribute("LobbyTextEN", '<font color="#8fd07a">MISSIONS</font>\n<font size="17" color="#b8cdd8">TAP OR PRESS E</font>')
	questsText.Text = questsText:GetAttribute("LobbyTextPT")
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
	self:BuildDistricts(lobby)
	self:BuildShieldOutpost(lobby)
	self:BuildTrainingYard(lobby)
	-- Wood and lamp posts read as turned timber, not square beams. The long
	-- axis becomes the cylinder's X; position and footprint are unchanged.
	local ROUND = { ForestTrunk = true, AuroraTrunk = true, TreeBranch = true, PlazaTreeTrunk = true, FestivalPole = true,
		VillageLampPost = true, MarketPost = true, BeaconColumn = true, NoticeLeg = true }
	for _, item in ipairs(lobby:GetDescendants()) do
		if item:IsA("Part") and ROUND[item.Name] and item.Shape == Enum.PartType.Block then
			local size = item.Size
			if size.Z >= size.Y and math.abs(size.X - size.Y) <= 0.05 * size.X then
				item.Size, item.CFrame = Vector3.new(size.Z, size.Y, size.X), item.CFrame * CFrame.Angles(0, math.pi / 2, 0)
				item.Shape = Enum.PartType.Cylinder
			elseif size.Y >= size.X and math.abs(size.X - size.Z) <= 0.05 * size.X then
				item.Size, item.CFrame = Vector3.new(size.Y, size.X, size.Z), item.CFrame * CFrame.Angles(0, 0, math.pi / 2)
				item.Shape = Enum.PartType.Cylinder
			end
		end
	end
	-- Last: no two surfaces of the finished lobby may share a plane.
	World.SeparateCoplanar(lobby)
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
			if not occupants[player.UserId] and inside(self.shopZones.training,0) then
				occupants[player.UserId]="training"
				self.openPanel(player,"training",{})
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
		-- One model per tree: clearing a district removes or keeps a whole
		-- tree, never a trunk without its crown.
		local model=Instance.new("Model")
		model.Name,model.Parent=ancient and "AuroraTree" or "ForestTree",forest
		local trunk=beam(ancient and "AuroraTrunk" or "ForestTrunk",a,V(x+1,height*0.7,z),trunkWidth,wood,Enum.Material.Wood,true)
		trunk.CastShadow=ancient==true
		trunk.Parent=model
		for i=1,4 do
			local angle=i*math.pi/2+seed
			local endpoint=V(x+math.cos(angle)*crown*0.55,height*(0.67+(i%2)*0.16),z+math.sin(angle)*crown*0.55)
			beam("TreeBranch",V(x,height*0.43,z),endpoint,trunkWidth*0.55,wood,Enum.Material.Wood,false).Parent=model
			local tint=ancient and Color3.fromRGB(225-i*12,159+i*11,53+i*9) or Color3.fromRGB(48+i*8,116+i*12,61+i*7)
			local leaf=piece(ancient and "AuroraCanopy" or "ForestCanopy",V(crown,crown*0.77,crown),CFrame.new(endpoint)*CFrame.Angles(0,seed,0),tint,Enum.Material.Grass,false)
			leaf.Shape=Enum.PartType.Ball
			leaf.CastShadow=ancient or i==1
			leaf.Parent=model
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
		local stoneAt=V(43+i*8,0.6+(i%4)*1.2,457+math.sin(i*0.8)*7)
		local jump=disk("JumpStone",stoneAt,V(1.2,5,5),stone,Enum.Material.Slate,true)
		-- The last stone is the parkour goal: landing on it earns a title.
		if i==7 then
			self.parkourGoal=stoneAt
			jump.Color=ART.gold
			local flag=piece("ParkourFlag",V(0.3,4,0.3),CFrame.new(stoneAt+V(1.6,2.6,0)),Color3.fromRGB(98,64,43),Enum.Material.Wood,false)
			piece("ParkourBanner",V(1.6,1,0.1),CFrame.new(stoneAt+V(2.45,4.1,0)),ART.gold,Enum.Material.Fabric,false)
			label(flag,"PARKOUR ★",V(0,3.2,0),ART.gold,140,40)
		end
	end
	for _,spot in ipairs({{-109,341},{-115,420},{24,421},{108,429},{112,338}}) do
		piece("TrailLanternPost",V(0.55,6,0.55),CFrame.new(spot[1],3,spot[2]),wood,Enum.Material.Wood,true)
		piece("TrailLantern",V(1.1,1.3,1.1),CFrame.new(spot[1],6,spot[2]),Color3.fromRGB(255,213,130),Enum.Material.Neon,false)
	end
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
		local model=Instance.new("Model")
		model.Name,model.Parent="OuterTree",scene
		p("OuterTrunk",V(2,h*0.7,2),CFrame.new(x,h*0.35,z),wood,Enum.Material.Wood,true).Parent=model
		for i=0,2 do
			local crown=p("OuterCanopy",V(14-i*2,10,14-i*2),CFrame.new(x+(i-1)*2,h*0.62+i*3,z),tint,Enum.Material.Grass,false)
			local mesh=Instance.new("SpecialMesh"); mesh.MeshType=Enum.MeshType.Sphere; mesh.Parent=crown
			crown.Parent=model
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
	trail(V(0,0.18,516),V(0,0.18,562),13)
	trail(V(-165,0.18,419),V(-212,0.18,426),11)
	trail(V(157,0.18,447),V(210,0.18,459),11)
	trail(V(-43,0.18,535),V(43,0.18,535),11)
	trail(V(-43,0.18,535),V(-43,0.18,541),10)
	trail(V(43,0.18,535),V(43,0.18,541),10)
	-- Small village: two cottages flank the way to the training and cards
	-- portals, with open frontages and places to sit together.
	for i,def in ipairs({{-43,550,Color3.fromRGB(171,86,74)},{43,550,Color3.fromRGB(77,132,139)}}) do
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
	-- The village well and picnic corner sit beside the portal plaza.
	local wx,wz=58,596
	disk("VillageWellBase",V(wx,0.4,wz),12,0.8,stone,Enum.Material.Cobblestone,true)
	disk("VillageWellWater",V(wx,1,wz),7,0.3,Color3.fromRGB(89,161,172),Enum.Material.Glass,false)
	for i=0,9 do
		local a=i*math.pi/5
		p("VillageWellStone",V(2.7,2.4,1.3),CFrame.new(wx+math.sin(a)*4,1.6,wz+math.cos(a)*4)*CFrame.Angles(0,a,0),cream,Enum.Material.Cobblestone,true)
	end
	for _,side in ipairs({-1,1}) do
		p("VillageWellPost",V(0.8,9,0.8),CFrame.new(wx+side*5,4.5,wz),wood,Enum.Material.Wood,true)
		p("VillageWellRoof",V(7,0.6,12),CFrame.new(wx+side*3,10,wz)*CFrame.Angles(0,0,-side*0.3),Color3.fromRGB(109,136,123),Enum.Material.WoodPlanks,true)
	end
	beam("VillageWellSpindle",V(wx-5,6,wz),V(wx+5,6,wz),0.6,0.6,wood,Enum.Material.Wood,false)
	p("VillageWellRope",V(0.14,4,0.14),CFrame.new(wx,4,wz),cream,Enum.Material.Fabric,false)
	p("PicnicTable",V(10,0.6,5),CFrame.new(-58,3,596),wood,Enum.Material.WoodPlanks,true)
	for _,side in ipairs({-1,1}) do
		p("PicnicLeg",V(0.8,3,4),CFrame.new(-58+side*3.5,1.5,596),wood,Enum.Material.Wood,true)
		seat(-58,1.7,596+side*4,side==1 and 0 or math.pi)
	end
	-- Explorer tower has real stairs and a safe, fenced viewing deck; it stands
	-- beside the expedition portals, looking over them.
	p("ExplorerTowerFoot",V(16,2,16),CFrame.new(-190,1,450),stone,Enum.Material.Cobblestone,true)
	for i=1,14 do
		p("ExplorerStair",V(9,0.75,2.3),CFrame.new(-190,i*0.75,426+i*1.65),wood,Enum.Material.WoodPlanks,true)
	end
	p("ExplorerTowerDeck",V(20,1,20),CFrame.new(-190,10.9,459),wood,Enum.Material.WoodPlanks,true)
	for _,side in ipairs({-1,1}) do
		p("TowerSupport",V(1.2,11,1.2),CFrame.new(-190+side*9,5.5,466),wood,Enum.Material.Wood,true)
		beam("TowerRail",V(-190+side*9,14,450),V(-190+side*9,14,468),0.6,0.6,cream,Enum.Material.Wood,true)
	end
	beam("TowerRail",V(-199,14,468),V(-181,14,468),0.6,0.6,cream,Enum.Material.Wood,true)
	seat(-190,12,464,0)
	-- The east island watches Latveria: the observatory stands north of the
	-- portal plaza, its telescope a landmark.
	disk("ObservatoryDeck",V(180,0.5,500),24,1,wood,Enum.Material.WoodPlanks,true)
	for _,side in ipairs({-1,1}) do
		for _,depth in ipairs({-1,1}) do p("ObservatoryPillar",V(1,11,1),CFrame.new(180+side*8,6,500+depth*8),cream,Enum.Material.Marble,true) end
		p("ObservatoryRoof",V(12,0.8,23),CFrame.new(180+side*5,12.2,500)*CFrame.Angles(0,0,-side*0.35),Color3.fromRGB(77,100,143),Enum.Material.WoodPlanks,true)
	end
	p("TelescopeStand",V(1.2,4,1.2),CFrame.new(180,3,500),gold,Enum.Material.Metal,true)
	beam("TelescopeTube",V(180,4.5,502),V(180,7,495),2,2,Color3.fromRGB(65,96,127),Enum.Material.Metal,false)
	seat(172,1.3,500,math.pi/2); seat(188,1.3,500,-math.pi/2)
	-- Rim trees and rocks, kept clear of each island's portal plaza.
	local clearTrees={[-204]={[3]=true,[4]=true,[5]=true},[194]={[0]=true},[0]={}}
	local clearRocks={[-204]={[2]=true},[194]={[1]=true,[2]=true},[0]={}}
	for _,center in ipairs({{-204,426,52},{194,460,58},{0,556,77}}) do
		for i=0,7 do
			local a=i*math.pi/4
			-- The southern entrance stays open, so the bridge is visible.
			if i~=6 and not clearTrees[center[1]][i] then tree(center[1]+math.cos(a)*center[3],center[2]+math.sin(a)*center[3],20+(i%3)*4,i%2==0 and leaf or Color3.fromRGB(119,158,82)) end
		end
		for i=1,3 do
			local a=i*1.7
			if not clearRocks[center[1]][i] then
				p("IslandOutcrop",V(7+i,3+i,5+i),CFrame.new(center[1]+math.cos(a)*(center[3]-7),1.5,center[2]+math.sin(a)*(center[3]-7))*CFrame.Angles(0,a,0.15),stone,Enum.Material.Rock,true)
			end
		end
	end
	for _,at in ipairs({{-66,575},{66,575},{-226,470},{-181,406},{232,500},{182,470}}) do
		tree(at[1],at[2],17,Color3.fromRGB(101,145,79))
	end
	for _,at in ipairs({{-157,407},{144,453},{11,519},{-27,526},{27,526},{-41,572},{-208,404},{195,465}}) do
		local x,z=at[1],at[2]
		p("VillageLampFoot",V(2.5,0.7,2.5),CFrame.new(x,0.35,z),stone,Enum.Material.Cobblestone,true)
		p("VillageLampPost",V(0.5,7,0.5),CFrame.new(x,3.5,z),wood,Enum.Material.Wood,true)
		local lamp=p("VillageLantern",V(1.3,1.8,1.3),CFrame.new(x,7,z),Color3.fromRGB(255,217,144),Enum.Material.Neon,false)
		p("VillageLanternCap",V(1.8,0.35,1.8),CFrame.new(x,8,z),wood,Enum.Material.Wood,false)
		local light=Instance.new("PointLight"); light.Color=lamp.Color; light.Brightness=0.5; light.Range=10; light.Shadows=false; light.Parent=lamp
	end
	sign("ExplorerSign",V(-184,6,410),"POSTO DE EXPEDIÇÕES","EXPEDITION OUTPOST","WAKANDA • ASGARD","WAKANDA • ASGARD",gold)
	sign("StarlightSign",V(177,6,437),"VIGIA DA LATVÉRIA","LATVERIA WATCH","EXPEDIÇÃO FINAL • 70 ONDAS","FINAL EXPEDITION • 70 WAVES",Color3.fromRGB(159,201,235))
	sign("WoodlandSign",V(0,8,535),"ACADEMIA DO BOSQUE","WOODLAND ACADEMY","TREINO • CARTAS","TRAINING • CARDS",Color3.fromRGB(176,216,134))
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
	-- Only the campaign portals open straight onto the plaza; the districts
	-- lay their own floors and trails (World:BuildDistricts).
	for _,portalId in ipairs(self.catalog.DestinationOrder) do
		local destination=self.catalog.Destinations[portalId]
		if (destination.district or "center")=="center" then
			walk(V(destination.x,0.12,destination.z),V(destination.x,0.12,322),10)
		end
	end
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
		for _,x in ipairs({-47,47}) do piece("FestivalPole",V(0.45,19,0.45),CFrame.new(x,9.5,z),timber,Enum.Material.Wood) end
		local colors={Color3.fromRGB(238,190,88),Color3.fromRGB(226,110,90),Color3.fromRGB(68,160,150),cream}
		for i=0,15 do
			local x=-45+i*6
			local y=18.6-2.6*(1-(x/47)^2)
			piece("FestivalCord",V(6.15,0.08,0.08),CFrame.new(x,y,z),timber,Enum.Material.SmoothPlastic)
			-- A WedgePart turned upside down and edge-on: a hanging triangle.
			for _,dx in ipairs({-1.5,1.5}) do
				local flag=Instance.new("WedgePart")
				flag.Name,flag.Size="FestivalPennant",V(0.08,1.9,1.5)
				flag.CFrame=CFrame.new(x+dx,y-0.95,z)*CFrame.Angles(0,math.pi/2,0)*CFrame.Angles(math.pi,0,0)
				flag.Color,flag.Material=colors[(i*2+(dx>0 and 1 or 0))%4+1],Enum.Material.SmoothPlastic
				flag.Anchored,flag.CanCollide,flag.CanQuery,flag.CanTouch,flag.CastShadow=true,false,false,false,false
				flag.Parent=art
			end
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
		-- A readable title in the desk's colour and a small how-to line, not
		-- the whole board filled with capitals.
		text.TextScaled,text.RichText,text.TextSize=false,true,36
		local tint=string.format('<font color="#%02x%02x%02x">',math.floor(def.color.R*255),math.floor(def.color.G*255),math.floor(def.color.B*255))
		local how='</font>\n<font size="17" color="#b8cdd8">'
		localized(text,tint..def.pt..how.."TOQUE OU PRESSIONE E</font>",tint..def.en..how.."TAP OR PRESS E</font>")
		text.Text=text:GetAttribute("LobbyTextPT")
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
	local function round(obj)
		local mesh=Instance.new("SpecialMesh")
		mesh.MeshType,mesh.Parent=Enum.MeshType.Sphere,obj
		return obj
	end
	local smooth=Enum.Material.SmoothPlastic
	for _,side in ipairs({-1,1}) do
		round(p("GuideBoot",V(0.9,0.6,1.3),origin*CFrame.new(side*0.5,0.35,-0.1),wood,smooth))
		round(p("GuideArm",V(0.55,1.45,0.6),origin*CFrame.new(side*1.15,1.9,0)*CFrame.Angles(0,0,side*0.2),pale,smooth))
		round(p("GuideHand",V(0.62,0.62,0.62),origin*CFrame.new(side*1.3,1.15,0),green,smooth))
		round(p("GuideEar",V(0.32,0.66,0.66),origin*CFrame.new(side*1.1,3.55,0),ART.gold,smooth))
		round(p("GuideEye",V(0.3,0.36,0.1),origin*CFrame.new(side*0.36,3.58,-0.84),Color3.fromRGB(158,237,197),Enum.Material.Neon))
	end
	round(p("GuideBody",V(1.9,2.1,1.4),origin*CFrame.new(0,1.75,0),green,smooth))
	round(p("GuidePanel",V(1.1,0.9,0.3),origin*CFrame.new(0,1.6,-0.62),pale,smooth))
	round(p("GuideScarf",V(1.95,0.45,1.45),origin*CFrame.new(0,2.72,0),ART.gold,smooth))
	round(p("GuideHead",V(2.2,1.6,1.7),origin*CFrame.new(0,3.55,0),pale,smooth))
	round(p("GuideVisor",V(1.6,0.8,0.5),origin*CFrame.new(0,3.58,-0.62),Color3.fromRGB(29,50,47),Enum.Material.Glass))
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


-- The districts around the plaza (see DISTRICTS): the scenery inside each
-- footprint is cleared, then the district lays its own floor, signage and
-- props, and trails tie it back to the plaza and to the island bridges.
-- Functional models (portals, stands, boards) are never scenery: they are
-- direct children of the lobby, and only the four art models are cleared.
function World:BuildDistricts(lobby)
	local V=Vector3.new
	local districts=Instance.new("Model")
	districts.Name,districts.Parent="LobbyDistricts",lobby
	local byId={}
	for _,d in ipairs(DISTRICTS) do byId[d.id]=d end
	local function overlaps(p,d)
		local cf,size=p.CFrame,p.Size
		local hx,hy,hz=size.X/2,size.Y/2,size.Z/2
		local right,up,look=cf.RightVector,cf.UpVector,cf.LookVector
		local ex=math.abs(right.X)*hx+math.abs(up.X)*hy+math.abs(look.X)*hz
		local ez=math.abs(right.Z)*hx+math.abs(up.Z)*hy+math.abs(look.Z)*hz
		local x,z=cf.Position.X,cf.Position.Z
		return x+ex>d.x0 and x-ex<d.x1 and z+ez>d.z0 and z-ez<d.z1
	end
	for _,name in ipairs({"AuroraSanctuary","CommandAtrium","VillageDetails","AuroraArchipelago"}) do
		local scenery=lobby:FindFirstChild(name)
		for _,obj in ipairs(scenery and scenery:GetDescendants() or {}) do
			local grove=obj.Parent and obj.Parent:IsA("Model") and (obj.Parent.Name=="ForestTree" or obj.Parent.Name=="OuterTree") and obj.Parent
			if grove then
				-- A tree goes as a whole when its trunk stands in a district;
				-- a crown merely leaning over one stays with its trunk.
				if obj.Name:find("Trunk") then
					for _,d in ipairs(DISTRICTS) do
						if overlaps(obj,d) then grove:Destroy(); break end
					end
				end
			-- The island itself (ground discs, cliffs) is far bigger than any prop.
			elseif obj:IsA("BasePart") and obj.Parent and math.max(obj.Size.X,obj.Size.Y,obj.Size.Z)<120 and obj.Position.Y>-3 then
				for _,d in ipairs(DISTRICTS) do
					if overlaps(obj,d) then obj:Destroy(); break end
				end
			end
		end
	end
	local function localized(target,pt,en)
		if target then target:SetAttribute("LobbyTextPT",pt); target:SetAttribute("LobbyTextEN",en) end
	end
	local function sign(parent,name,cf,size,title,subtitle,tint)
		local panel=wallSign(parent,name,cf,size,title[1],subtitle[1],tint)
		local art=panel:FindFirstChild("Artwork")
		localized(art and art:FindFirstChild("Title"),title[1],title[2])
		localized(art and art:FindFirstChild("Subtitle"),subtitle[1],subtitle[2])
		return panel
	end
	-- Floors sit a hair above the deck and the grass so neither shows through.
	for _,d in ipairs(DISTRICTS) do
		local cx,cz,w,h=(d.x0+d.x1)/2,(d.z0+d.z1)/2,d.x1-d.x0,d.z1-d.z0
		local floor=part(districts,"DistrictFloor",V(w,0.3,h),CFrame.new(cx,0.1,cz),d.floor and d.floor[1] or Color3.fromRGB(196,184,152):Lerp(d.color,0.1),d.floor and d.floor[2] or Enum.Material.Cobblestone)
		floor:SetAttribute("District",d.id)
		for _,edge in ipairs({{V(w,0.12,0.5),V(cx,0.31,d.z0)},{V(w,0.12,0.5),V(cx,0.31,d.z1)},{V(0.5,0.12,h),V(d.x0,0.31,cz)},{V(0.5,0.12,h),V(d.x1,0.31,cz)}}) do
			artPart(districts,"DistrictCurb",edge[1]+V(edge[1].X>1 and 0.6 or 1.1,0.2,edge[1].Z>1 and 0.6 or 1.1),CFrame.new(edge[2]-V(0,0.12,0)),Color3.fromRGB(214,204,176),Enum.Material.Slate)
			artPart(districts,"DistrictBorder",edge[1],CFrame.new(edge[2]+V(0,0.05,0)),d.color,Enum.Material.Neon)
		end
	end
	local function trail(a,b,width)
		local sanctuary=lobby:FindFirstChild("AuroraSanctuary") or districts
		local t=part(sanctuary,"ForestTrail",V(width,0.16,(b-a).Magnitude+1),CFrame.lookAt((a+b)/2,b),Color3.fromRGB(195,169,115),Enum.Material.Sand)
		t.CanCollide=true
		return t
	end
	trail(V(-78,0.12,352),V(-88,0.12,352),10) -- plaza -> AFK zone
	trail(V(-54,0.12,314),V(-88,0.12,314),9)
	trail(V(-120,0.12,391),V(-120,0.12,402),10) -- AFK zone -> explorers' bridge
	trail(V(-44,0.12,414),V(-6,0.12,414),8) -- market -> forest avenue
	trail(V(44,0.12,414),V(6,0.12,414),8) -- special modes -> forest avenue
	trail(V(72,0.12,352),V(88,0.12,352),9) -- plaza -> arena
	trail(V(54,0.12,314),V(88,0.12,314),9)
	trail(V(118,0.12,391),V(119,0.12,431),8) -- arena -> starlight bridge
	trail(V(-92,0.12,284),V(-56,0.12,312),8) -- western expeditions -> plaza
	trail(V(92,0.12,284),V(58,0.12,312),8) -- final expedition -> plaza

	-- Market: a striped awning shades the Robux counters.
	do
		local d=byId.market
		local stripes={d.color,Color3.fromRGB(246,225,178)}
		for i=0,13 do
			local x=-112+i*5+2.5
			artPart(districts,"MarketAwning",V(5.05,0.22,11),CFrame.new(x,10.3,MARKET.standZ)*CFrame.Angles(0.12,0,0),stripes[i%2+1],Enum.Material.Fabric)
			artPart(districts,"MarketValance",V(5,0.9,0.15),CFrame.new(x,9.2,MARKET.standZ-5.6),stripes[i%2+1],Enum.Material.Fabric)
		end
		for _,x in ipairs({-112,-77,-42}) do
			for _,z in ipairs({MARKET.standZ-5,MARKET.standZ+5}) do
				part(districts,"MarketPost",V(0.7,10,0.7),CFrame.new(x,5,z),Color3.fromRGB(98,64,43),Enum.Material.Wood)
			end
		end
		sign(districts,"MarketTitle",CFrame.lookAt(V(-50,15,398),V(0,15,345)),V(17,4,0.5),d.title,d.subtitle,d.color)
	end

	-- Districts with a sign on posts facing the plaza (the islands are signed
	-- at their bridges instead).
	for _,d in ipairs(DISTRICTS) do
		if d.sign then
			local frame=CFrame.lookAt(V(d.sign[1],d.sign[2],d.sign[3]),V(0,d.sign[2],345))
			sign(districts,d.id.."Title",frame,V(17,4,0.5),d.title,d.subtitle,d.color)
			for _,side in ipairs({-1,1}) do
				local foot=frame*V(side*7.6,-d.sign[2],0.4)
				part(districts,"DistrictSignPost",V(0.8,d.sign[2]-1.6,0.8),CFrame.new(foot.X,(d.sign[2]-1.6)/2,foot.Z),Color3.fromRGB(64,72,84),Enum.Material.Metal)
			end
		end
	end

	-- Competitive arena: a raised season scoreboard behind the three ranked
	-- portals, readable from the plaza over their rings, plus a kiosk in
	-- front that opens the full leaderboard.
	do
		local d=byId.arena
		local board=Instance.new("Model")
		board.Name,board.Parent="Scoreboard_arena",lobby
		board:SetAttribute("Kind","Scoreboard")
		board:SetAttribute("BoardId","arena")
		for _,z in ipairs({316,366}) do
			part(board,"ScoreboardLeg",V(1.6,33,1.6),CFrame.new(135,16.5,z),Color3.fromRGB(40,50,64),Enum.Material.Metal).CastShadow=true
		end
		local panel=part(board,"ScoreboardPanel",V(52,18,1),CFrame.new(134,24,341)*CFrame.Angles(0,math.pi/2,0),Color3.fromRGB(19,27,39),Enum.Material.Metal)
		panel.CastShadow=true
		artPart(board,"ScoreboardTrim",V(53,0.6,1.2),CFrame.new(134,33.2,341)*CFrame.Angles(0,math.pi/2,0),d.color,Enum.Material.Neon)
		artPart(board,"ScoreboardTrim",V(53,0.6,1.2),CFrame.new(134,14.8,341)*CFrame.Angles(0,math.pi/2,0),d.color,Enum.Material.Neon)
		local gui=Instance.new("SurfaceGui")
		gui.Name,gui.Face,gui.LightInfluence=  "Scores",Enum.NormalId.Front,0
		gui.SizingMode,gui.CanvasSize,gui.Parent=Enum.SurfaceGuiSizingMode.FixedSize,Vector2.new(1040,360),panel
		local title=Instance.new("TextLabel")
		title.Name,title.BackgroundTransparency,title.Size=  "Title",1,UDim2.new(1,0,0,64)
		title.Font,title.TextSize,title.TextColor3,title.Text=Enum.Font.GothamBlack,44,d.color,"ARENA COMPETITIVA • PLACAR SOLO"
		title.Parent=gui
		localized(title,"ARENA COMPETITIVA • PLACAR SOLO","COMPETITIVE ARENA • SOLO LEADERBOARD")
		self.arenaColumns={}
		local maps={}
		for _,id in ipairs(self.catalog.DestinationOrder) do
			local def=self.catalog.Destinations[id]
			if def.modeId=="ranked" then table.insert(maps,def.mapId) end
		end
		for i,mapId in ipairs(maps) do
			local map=self.catalog.Maps[mapId]
			local column=Instance.new("Frame")
			column.Name,column.BackgroundTransparency="Column_"..mapId,1
			column.Position,column.Size=UDim2.new((i-1)/#maps,8,0,70),UDim2.new(1/#maps,-16,1,-78)
			column.Parent=gui
			local head=Instance.new("TextLabel")
			head.BackgroundTransparency,head.Size,head.Font,head.TextSize=1,UDim2.new(1,0,0,40),Enum.Font.GothamBlack,30
			head.TextColor3,head.Text,head.Parent=rgb(PORTAL_COLORS[mapId] or map.color),upper(map.name.pt),column
			local rows=Instance.new("TextLabel")
			rows.Name,rows.BackgroundTransparency,rows.Position,rows.Size="Rows",1,UDim2.fromOffset(0,46),UDim2.new(1,0,1,-46)
			rows.Font,rows.TextSize,rows.TextColor3=Enum.Font.GothamBold,24,Color3.fromRGB(230,240,244)
			rows.TextXAlignment,rows.TextYAlignment,rows.Text=Enum.TextXAlignment.Left,Enum.TextYAlignment.Top,"Carregando…"
			rows.Parent=column
			table.insert(self.arenaColumns,{mapId=mapId,label=rows})
		end
		sign(board,"ArenaTitle",CFrame.new(135,37,341)*CFrame.Angles(0,math.pi/2,0),V(36,4,0.5),d.title,d.subtitle,ART.gold)
		local kiosk=part(board,"ScoreKiosk",V(2.4,3.4,4),CFrame.new(121,1.9,323.5),Color3.fromRGB(40,50,64),Enum.Material.Metal)
		artPart(board,"KioskScreen",V(0.2,2,3.2),CFrame.new(119.7,2.6,323.5),d.color,Enum.Material.Neon)
		label(kiosk,"PLACAR\nLEADERBOARD",V(0,3.6,0),d.color,160,60)
		board.PrimaryPart=kiosk
		interactable(kiosk,"Placar / Leaderboard",function(player) self.openPanel(player,"leaderboard",{board="arena"}) end)
	end

	-- AFK zone: two open chambers facing the plaza. Standing inside one is the
	-- whole interaction; the server pays each full minute (World:AfkZoneOf).
	do
		local d=byId.afk
		self.afkZones={}
		for _,kind in ipairs(self.catalog.AfkOrder or {}) do
			local def=self.catalog.Afk[kind]
			local tint=rgb(def.color)
			local x,z=def.x,def.z
			local model=Instance.new("Model")
			model.Name,model.Parent="AfkZone_"..kind,lobby
			model:SetAttribute("Kind","AfkZone")
			model:SetAttribute("AfkKind",kind)
			local function disk(name,y,diameter,thickness,color,material)
				local p=part(model,name,V(thickness,diameter,diameter),CFrame.new(x,y,z)*CFrame.Angles(0,0,math.pi/2),color,material)
				p.Shape=Enum.PartType.Cylinder
				return p
			end
			local platform=disk("AfkPlatform",0.35,22,0.5,Color3.fromRGB(40,50,64),Enum.Material.Slate)
			disk("AfkRim",0.3,23,0.36,tint,Enum.Material.Neon).CanCollide=false
			local rune=disk("AfkRune",0.62,8,0.1,tint,Enum.Material.Neon)
			rune.CanCollide,rune.Transparency=false,0.35
			-- Open toward the plaza (+X): pillars stand on the diagonals.
			for _,a in ipairs({math.pi/4,3*math.pi/4,5*math.pi/4,7*math.pi/4}) do
				local px,pz=x+math.cos(a)*10,z+math.sin(a)*10
				part(model,"AfkPillar",V(1.2,11,1.2),CFrame.new(px,5.8,pz),Color3.fromRGB(206,218,222),Enum.Material.Marble).CastShadow=true
				artPart(model,"AfkPillarLight",V(0.25,9,0.25),CFrame.new(px+math.cos(a+math.pi)*0.7,5.8,pz+math.sin(a+math.pi)*0.7),tint,Enum.Material.Neon)
			end
			arc(model,"AfkHalo",CFrame.new(x,11.6,z)*CFrame.Angles(math.pi/2,0,0),10,0.7,0.7,tint,Enum.Material.Neon,24)
			local icon
			if kind=="gold" then
				icon=part(model,"AfkIcon",V(0.8,5,5),CFrame.new(x,6,z),tint,Enum.Material.Neon)
				icon.Shape=Enum.PartType.Cylinder
			else
				icon=part(model,"AfkIcon",V(4.2,4.2,4.2),CFrame.new(x,6,z),tint,Enum.Material.Neon)
				icon.Shape=Enum.PartType.Ball
			end
			icon.CanCollide=false
			emitter(icon,tint,6,2.5,0.6,1.6,Vector3.new(0,3,0))
			local glow=Instance.new("PointLight")
			glow.Color,glow.Range,glow.Brightness,glow.Parent=tint,16,1,icon
			label(icon,def.rate.pt,V(0,4.2,0),tint,240,70)
			-- Seats face the plaza, so resting players watch the lobby go by.
			for _,dz in ipairs({-5,0,5}) do
				local seat=Instance.new("Seat")
				seat.Name,seat.Size,seat.CFrame="AfkSeat",V(3,0.6,2.4),CFrame.lookAt(V(x-6,1.2,z+dz),V(x+10,1.2,z+dz))
				seat.Anchored,seat.Color,seat.Material,seat.CastShadow=true,tint:Lerp(Color3.fromRGB(40,50,64),0.55),Enum.Material.Fabric,false
				seat.Parent=model
			end
			sign(model,"AfkHeader",CFrame.new(x-9.5,15.5,z)*CFrame.Angles(0,-math.pi/2,0),V(17,4,0.5),{upper(def.name.pt),upper(def.name.en)},{def.rate.pt,def.rate.en},tint)
			model.PrimaryPart=platform
			self.afkZones[kind]={center=V(x,4,z),size=V(20,10,20)}
		end
		sign(districts,"AfkTitle",CFrame.new(-133,12,343)*CFrame.Angles(0,-math.pi/2,0),V(17,4,0.5),d.title,d.subtitle,d.color)
	end
end

-- S.H.I.E.L.D. keeps the refuge: a Quinjet on its pad, a field command post,
-- an armory with the agents' black SUV, agents on duty and the Helicarrier
-- holding station in the sky. Scenery only: nothing here opens a menu or
-- changes a rule.
function World:BuildShieldOutpost(lobby)
	local V = Vector3.new
	local outpost = Instance.new("Model")
	outpost.Name, outpost.Parent = "ShieldOutpost", lobby
	local navy, steel, pale = Color3.fromRGB(30, 38, 54), Color3.fromRGB(98, 110, 124), Color3.fromRGB(196, 204, 212)
	local blue, white, yellow = Color3.fromRGB(84, 156, 232), Color3.fromRGB(236, 240, 244), Color3.fromRGB(242, 192, 64)
	local jet, suit = Color3.fromRGB(42, 46, 56), Color3.fromRGB(24, 26, 32)
	local metal, smooth, glass = Enum.Material.Metal, Enum.Material.SmoothPlastic, Enum.Material.Glass
	local function p(name, size, cf, tint, material) return artPart(outpost, name, size, cf, tint, material or smooth) end
	local function blob(name, size, cf, tint, material)
		local made = p(name, size, cf, tint, material)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType, mesh.Parent = Enum.MeshType.Sphere, made
		return made
	end
	-- A round plate whose face looks along frame's -Z.
	local function plate(name, frame, diameter, thickness, tint, material)
		local made = p(name, V(thickness, diameter, diameter), frame * CFrame.Angles(0, math.pi / 2, 0), tint, material)
		made.Shape = Enum.PartType.Cylinder
		return made
	end
	-- An upright column standing on base (a cylinder's axis runs along X).
	local function column(name, base, height, diameter, tint, material)
		local made = p(name, V(height, diameter, diameter), CFrame.new(base + V(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), tint, material)
		made.Shape = Enum.PartType.Cylinder
		return made
	end
	-- A right triangle: the right angle at corner, perpendicular legs span and
	-- chord, extruded by thickness. Wings, fins and a ship's bow.
	local function triangle(name, corner, span, chord, thickness, tint, material)
		local y, z = span.Unit, -chord.Unit
		local made = Instance.new("WedgePart")
		made.Name, made.Size = name, V(thickness, span.Magnitude, chord.Magnitude)
		made.CFrame = CFrame.fromMatrix(corner + span / 2 + chord / 2, y:Cross(z), y, z)
		made.Color, made.Material, made.Anchored = tint, material or smooth, true
		made.CanCollide, made.CanQuery, made.CanTouch, made.CastShadow = false, false, false, false
		made.TopSurface, made.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		made.Parent = outpost
		return made
	end
	local function toWorld(frame, v) return frame * v - frame.Position end
	local function facingToward(x, z, tx, tz) return math.atan2(-(tx - x), -(tz - z)) end
	-- The emblem: a silver ring, a navy field and a white eagle with spread
	-- wings, facing frame's -Z.
	local function emblem(frame, size)
		plate("EmblemRing", frame, size, 0.2, pale, metal)
		plate("EmblemField", frame * CFrame.new(0, 0, -0.08), size * 0.84, 0.2, navy)
		blob("EmblemEagle", V(size * 0.16, size * 0.36, 0.12), frame * CFrame.new(0, size * 0.04, -0.22), white)
		for _, side in ipairs({ -1, 1 }) do
			triangle("EmblemWing", frame * V(side * size * 0.05, size * 0.12, -0.22), toWorld(frame, V(side * size * 0.3, 0, 0)),
				toWorld(frame, V(0, -size * 0.26, 0)), 0.1, white)
		end
	end
	-- Agents on duty: black suits and dark glasses, in the refuge's rounded style.
	local SKIN = { Color3.fromRGB(232, 181, 147), Color3.fromRGB(141, 92, 64), Color3.fromRGB(198, 146, 108), Color3.fromRGB(96, 64, 46) }
	local HAIR = { Color3.fromRGB(38, 30, 28), Color3.fromRGB(96, 64, 40), Color3.fromRGB(20, 20, 24), Color3.fromRGB(150, 110, 60) }
	local function agent(x, z, facing, index)
		local frame = CFrame.new(x, 0.25, z) * CFrame.Angles(0, facing, 0)
		for _, side in ipairs({ -1, 1 }) do
			blob("AgentLeg", V(0.62, 1.7, 0.66), frame * CFrame.new(side * 0.34, 0.8, 0), suit)
			blob("AgentArm", V(0.5, 1.55, 0.54), frame * CFrame.new(side * 1.02, 2.35, 0) * CFrame.Angles(0, 0, side * 0.12), suit)
		end
		blob("AgentBody", V(1.8, 1.95, 1.1), frame * CFrame.new(0, 2.45, 0), suit)
		blob("AgentShirt", V(0.62, 0.95, 0.3), frame * CFrame.new(0, 2.95, -0.46), white)
		blob("AgentTie", V(0.18, 0.75, 0.12), frame * CFrame.new(0, 2.8, -0.6), navy)
		blob("AgentHead", V(1.26, 1.3, 1.2), frame * CFrame.new(0, 4.05, 0), SKIN[(index - 1) % #SKIN + 1])
		blob("AgentHair", V(1.32, 0.62, 1.26), frame * CFrame.new(0, 4.5, 0.08), HAIR[(index - 1) % #HAIR + 1])
		blob("AgentShades", V(1.1, 0.3, 0.26), frame * CFrame.new(0, 4.12, -0.56), Color3.fromRGB(12, 14, 18), glass)
	end

	-- Hangar: a Quinjet on its pad, facing the plaza, crates and fuel drums.
	do
		local cx, cz = -94, 265
		local up = CFrame.Angles(math.pi / 2, 0, 0)
		plate("PadRim", CFrame.new(cx, 0.32, cz) * up, 31, 0.2, yellow)
		plate("LandingPad", CFrame.new(cx, 0.4, cz) * up, 29, 0.2, Color3.fromRGB(52, 58, 66))
		emblem(CFrame.new(cx, 0.52, cz) * up, 8)
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			p("PadLight", V(0.8, 0.5, 0.8), CFrame.new(cx + math.cos(a) * 16.5, 0.55, cz + math.sin(a) * 16.5), blue, Enum.Material.Neon)
		end
		local J = CFrame.new(cx, 0.5, cz) * CFrame.Angles(0, 0.86, 0)
		local function at(x, y, z) return J * CFrame.new(x, y, z) end
		local function pt(x, y, z) return J * V(x, y, z) end
		local function dir(x, y, z) return toWorld(J, V(x, y, z)) end
		blob("QuinjetHull", V(5.2, 4, 22), at(0, 4.2, -1), jet, metal).CastShadow = true
		blob("QuinjetNose", V(3.8, 2.9, 9), at(0, 3.9, 9.5), jet, metal)
		blob("QuinjetSpine", V(2.2, 1.4, 14), at(0, 6, -3), jet:Lerp(pale, 0.15), metal)
		blob("QuinjetCanopy", V(3.3, 1.9, 6.4), at(0, 5.6, 6.5), Color3.fromRGB(46, 76, 104), glass).Transparency = 0.15
		for _, side in ipairs({ -1, 1 }) do
			triangle("QuinjetWing", pt(side * 2.3, 3.6, -6.5), dir(side * 10.5, 0.9, 0), dir(0, 0, 12.5), 0.5, jet, metal)
			triangle("QuinjetFin", pt(side * 1.4, 5.8, -11.6), dir(side * 1.3, 4.6, 0), dir(0, 0, 5.2), 0.35, jet, metal)
			local engine = p("QuinjetEngine", V(6, 2.2, 2.2), at(side * 3.6, 3.4, -8) * CFrame.Angles(0, math.pi / 2, 0), steel, metal)
			engine.Shape = Enum.PartType.Cylinder
			plate("QuinjetExhaust", at(side * 3.6, 3.4, -11.05), 1.8, 0.12, blue, Enum.Material.Neon)
			column("QuinjetGear", pt(side * 2.4, 0, -4), 2.2, 0.4, steel, metal)
			blob("QuinjetStripe", V(0.12, 0.5, 9), at(side * 2.62, 4.4, 1), white)
		end
		column("QuinjetGear", pt(0, 0, 9), 2.2, 0.4, steel, metal)
		for i, spot in ipairs({ { -114, 252 }, { -114, 258 }, { -109, 252 } }) do
			p("SupplyCrate", V(4.6, 3.4, 4.6), CFrame.new(spot[1], 1.95, spot[2]) * CFrame.Angles(0, i * 0.2, 0), Color3.fromRGB(70, 82, 64), Enum.Material.WoodPlanks)
		end
		p("SupplyCrate", V(4.2, 3, 4.2), CFrame.new(-113.5, 5.15, 254.5) * CFrame.Angles(0, 0.5, 0), Color3.fromRGB(70, 82, 64), Enum.Material.WoodPlanks)
		for _, spot in ipairs({ { -74, 250 }, { -71.4, 251.6 } }) do column("FuelDrum", V(spot[1], 0.25, spot[2]), 3.2, 2.2, Color3.fromRGB(178, 52, 44), metal) end
		agent(-78, 257, facingToward(-78, 257, cx, cz), 1)
		agent(-110, 276, facingToward(-110, 276, 0, 345), 2)
	end

	-- Command post: a field HQ module, the holo table, radar and signal mast.
	do
		p("CommandModule", V(16, 7, 9), CFrame.new(99, 3.75, 256), steel, metal).CastShadow = true
		p("CommandRoof", V(17, 0.6, 10), CFrame.new(99, 7.55, 256), navy, metal)
		p("CommandDoor", V(3, 5, 0.2), CFrame.new(94, 2.75, 260.6), navy, metal)
		p("CommandWindows", V(6, 1.2, 0.2), CFrame.new(104, 4.85, 260.6), blue, Enum.Material.Neon)
		emblem(CFrame.new(98.5, 5.2, 260.75) * CFrame.Angles(0, math.pi, 0), 2.6)
		column("CommandMast", V(105, 7.85, 256), 5, 0.3, pale, metal)
		column("HoloPedestal", V(86, 0.25, 270), 3, 1.6, navy, metal)
		plate("HoloTable", CFrame.new(86, 3.45, 270) * CFrame.Angles(math.pi / 2, 0, 0), 6.5, 0.4, steel, metal)
		plate("HoloMap", CFrame.new(86, 3.72, 270) * CFrame.Angles(math.pi / 2, 0, 0), 5.8, 0.08, blue, Enum.Material.Neon).Transparency = 0.35
		local globe = p("HoloGlobe", V(2.6, 2.6, 2.6), CFrame.new(86, 5.5, 270), blue, Enum.Material.ForceField)
		globe.Shape = Enum.PartType.Ball
		local glow = Instance.new("PointLight")
		glow.Color, glow.Range, glow.Brightness, glow.Parent = blue, 12, 0.8, globe
		p("RadarBase", V(3.2, 1, 3.2), CFrame.new(108, 0.75, 278), steel, metal)
		column("RadarMast", V(108, 1.25, 278), 5.5, 0.8, pale, metal)
		local aim = CFrame.new(108, 7.4, 278) * CFrame.Angles(0.9, 0.6, 0)
		plate("RadarDish", aim, 7.5, 0.5, white, metal)
		p("RadarFeed", V(0.25, 0.25, 3), aim * CFrame.new(0, 0, -1.5), pale, metal)
		column("SignalMast", V(76, 0.25, 252), 18, 1, pale, metal)
		for _, y in ipairs({ 7, 13 }) do p("SignalBar", V(6, 0.4, 0.4), CFrame.new(76, y, 252), pale, metal) end
		local beacon = p("SignalBeacon", V(1.2, 1.2, 1.2), CFrame.new(76, 18.9, 252), Color3.fromRGB(255, 70, 60), Enum.Material.Neon)
		beacon.Shape = Enum.PartType.Ball
		for i = 0, 2 do p("JerseyBarrier", V(5, 2.2, 1.4), CFrame.new(82 + i * 6, 1.35, 249), pale, Enum.Material.Concrete) end
		agent(89, 274, facingToward(89, 274, 86, 270), 3)
		agent(80, 266, facingToward(80, 266, 0, 345), 4)
	end

	-- Armory: a vaulted depot, weapon lockers and the agents' black SUV.
	do
		p("ArmoryDepot", V(20, 8, 12), CFrame.new(96, 4.25, 437), steel, metal).CastShadow = true
		local vault = p("ArmoryRoof", V(20.4, 12.4, 12.4), CFrame.new(96, 8.25, 437), navy, metal)
		vault.Shape = Enum.PartType.Cylinder
		p("ArmoryDoor", V(10, 6.4, 0.2), CFrame.new(96, 3.45, 430.9), Color3.fromRGB(62, 70, 80), Enum.Material.DiamondPlate)
		p("ArmoryDoorLight", V(10.4, 0.35, 0.3), CFrame.new(96, 6.9, 430.85), blue, Enum.Material.Neon)
		emblem(CFrame.new(96, 11, 430.7), 3.4)
		for i = 0, 1 do
			p("WeaponLocker", V(3, 6, 2), CFrame.new(108.5, 3.25, 412 + i * 4), navy, metal)
			p("LockerLight", V(0.2, 4.6, 0.3), CFrame.new(106.95, 3.25, 412 + i * 4), blue, Enum.Material.Neon)
		end
		local S = CFrame.new(62, 0.25, 424) * CFrame.Angles(0, -math.pi / 2 + 0.25, 0)
		local function suv(x, y, z) return S * CFrame.new(x, y, z) end
		local black = Color3.fromRGB(18, 20, 24)
		p("SuvBody", V(5.2, 2.3, 11), suv(0, 1.85, 0), black, metal).CastShadow = true
		p("SuvCabin", V(4.8, 2, 6.6), suv(0, 3.95, -1), black, metal)
		p("SuvGlass", V(4.9, 1.3, 6.7), suv(0, 4.05, -1), Color3.fromRGB(40, 56, 70), glass)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -3.6, 3.6 }) do
				local wheel = p("SuvWheel", V(1.1, 2.4, 2.4), suv(sx * 2.55, 1.2, sz), Color3.fromRGB(26, 26, 28))
				wheel.Shape = Enum.PartType.Cylinder
			end
			p("SuvHeadlight", V(1.1, 0.5, 0.2), suv(sx * 1.8, 2.3, 5.55), Color3.fromRGB(240, 244, 255), Enum.Material.Neon)
		end
		p("SuvGrille", V(2.2, 0.8, 0.15), suv(0, 2.1, 5.55), pale, metal)
		for _, spot in ipairs({ { 50, 440, 1.95 }, { 55, 440, 1.95 }, { 52.5, 440, 5.35 } }) do
			p("SupplyCrate", V(4.2, 3.4, 4.2), CFrame.new(spot[1], spot[3], spot[2]), Color3.fromRGB(70, 82, 64), Enum.Material.WoodPlanks)
		end
		agent(70, 431, facingToward(70, 431, 62, 424), 5)
		agent(84, 404, facingToward(84, 404, 0, 345), 6)
	end

	-- The Helicarrier holds station over the north-west sea: hull and bow, a
	-- flight deck with its island, four rotors in their outriggers.
	do
		local H = CFrame.new(-310, 150, 610) * CFrame.Angles(0, 0.35, 0)
		local function at(x, y, z) return H * CFrame.new(x, y, z) end
		local hull, deck = Color3.fromRGB(58, 64, 74), Color3.fromRGB(84, 92, 104)
		p("HelicarrierHull", V(170, 12, 34), at(0, 0, 0), hull, metal)
		p("HelicarrierDeck", V(176, 1.4, 38), at(4, 6.7, 0), deck, metal)
		p("HelicarrierIsland", V(18, 16, 9), at(10, 15.4, -13), hull, metal)
		p("HelicarrierBridge", V(18.3, 1.6, 9.3), at(10, 19.6, -13), blue, Enum.Material.Neon)
		column("HelicarrierMast", H * V(14, 23.4, -13), 10, 0.8, pale, metal)
		for _, side in ipairs({ -1, 1 }) do
			triangle("HelicarrierBow", H * V(85, 0, 0), toWorld(H, V(0, 0, side * 17)), toWorld(H, V(28, 0, 0)), 12, hull, metal)
			p("HelicarrierStripe", V(160, 0.1, 0.7), at(4, 7.45, side * 7), white)
			p("HelicarrierLight", V(150, 0.4, 0.8), at(0, -6.2, side * 9), blue, Enum.Material.Neon)
			for _, x in ipairs({ -50, 50 }) do
				p("RotorArm", V(8, 3, 16), at(x, -2, side * 25), hull, metal)
				local housing = p("RotorHousing", V(3, 30, 30), at(x, -2, side * 41) * CFrame.Angles(0, 0, math.pi / 2), hull, metal)
				housing.Shape = Enum.PartType.Cylinder
				local rotor = p("RotorGlow", V(3.4, 25, 25), at(x, -2, side * 41) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(150, 210, 255), Enum.Material.Neon)
				rotor.Shape, rotor.Transparency = Enum.PartType.Cylinder, 0.45
			end
		end
	end
end

-- Whether a lobby visitor is standing on the last jump stone of the parkour.
function World:BuildTrainingYard(lobby)
	local yard = Instance.new("Model")
	yard.Name, yard.Parent = "TrainingYard", lobby
	local flat = CFrame.Angles(0, 0, math.pi / 2)
	local stage = TRAINING.stage
	local platform = artPart(yard, "TrainingStage", Vector3.new(0.5, 6, 6), CFrame.new(stage.X, 0.25, stage.Z) * flat, Color3.fromRGB(65, 83, 107), Enum.Material.Metal)
	platform.Shape = Enum.PartType.Cylinder
	local range = artPart(yard, "TrainingRange", Vector3.new(0.08, 20, 20), CFrame.new(stage.X, 0.16, stage.Z) * flat, ART.gold, Enum.Material.Neon)
	range.Shape, range.Transparency = Enum.PartType.Cylinder, 1
	local pad = artPart(yard, "TrainingPad", Vector3.new(5, 0.12, 5), CFrame.new(TRAINING.pad.X, 0.2, TRAINING.pad.Z), Color3.fromRGB(88, 214, 141), Enum.Material.Neon)
	pad.Transparency = 0.3
	local title = label(pad, "CAMPO DE TREINO\npise aqui • sem recompensas", Vector3.new(0, 8.5, 0), ART.gold, 230, 90)
	title.Font = Enum.Font.FredokaOne
	for _, spot in ipairs(TRAINING.dummies) do
		local dummy = Instance.new("Model")
		dummy.Name, dummy.Parent = "TrainingDummy", yard
		artPart(dummy, "Post", Vector3.new(0.5, 3.4, 0.5), CFrame.new(spot.X, 1.7, spot.Z), Color3.fromRGB(122, 86, 58), Enum.Material.Wood)
		artPart(dummy, "Body", Vector3.new(2, 2.2, 1), CFrame.new(spot.X, 3.6, spot.Z), Color3.fromRGB(238, 214, 160), Enum.Material.Fabric)
		local head = artPart(dummy, "Head", Vector3.new(1.4, 1.4, 1.4), CFrame.new(spot.X, 5.4, spot.Z), Color3.fromRGB(238, 214, 160), Enum.Material.Fabric)
		head.Shape = Enum.PartType.Ball
		-- The target faces the stage, so every shot visibly lands on it.
		artPart(dummy, "Target", Vector3.new(1.1, 1.1, 0.1), CFrame.new(spot.X, 3.7, spot.Z + 0.52), Color3.fromRGB(233, 72, 72), Enum.Material.Neon)
	end
	self.trainingYard, self.trainingRange = yard, range
	self.shopZones.training = { center = Vector3.new(TRAINING.pad.X, 3, TRAINING.pad.Z), size = Vector3.new(5, 6, 5) }
end

-- One hero at a time stands on the stage; the ring on the floor is its real
-- reach at level one. Purely visual: nothing here is a tower or earns anything.
function World:ShowTrainingHero(heroId, range)
	self:ClearTrainingHero()
	local hero = self.catalog.Heroes[heroId]
	if not hero or not self.trainingYard then return nil end
	local stage = TRAINING.stage
	local figure = Instance.new("Model")
	figure.Name = "TrainingHero"
	figure:SetAttribute("TowerId", "training") figure:SetAttribute("HeroId", heroId)
	local anchor = artPart(figure, "Platform", Vector3.new(1, 0.2, 1), CFrame.new(stage.X, 0.4, stage.Z), Color3.fromRGB(65, 83, 107), Enum.Material.Metal)
	anchor.Transparency = 1
	local _, head = heroFigure(figure, heroId, hero, CFrame.new(stage.X, 0.5, stage.Z), (FIGURE_SCALE[heroId] or 1) * 1.15)
	for _, p in ipairs(figure:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide, p.CanQuery, p.CanTouch = false, false, false end end
	figure.PrimaryPart, figure.Parent = anchor, self.trainingYard
	if head then
		local title = label(head, hero.name.pt, Vector3.new(0, 2, 0), rgb(hero.color):Lerp(Color3.new(1, 1, 1), 0.75), 145, 60)
		title.Font = Enum.Font.FredokaOne
	end
	if self.trainingRange then
		self.trainingRange.Size = Vector3.new(0.08, range * 2, range * 2)
		self.trainingRange.Color = rgb(hero.color)
		self.trainingRange.Transparency = 0.72
	end
	return figure
end

function World:ClearTrainingHero()
	local old = self.trainingYard and self.trainingYard:FindFirstChild("TrainingHero")
	if old then old:Destroy() end
	if self.trainingRange then self.trainingRange.Transparency = 1 end
end

function World:TrainingShot(index)
	local stage, spot = TRAINING.stage, TRAINING.dummies[(index - 1) % #TRAINING.dummies + 1]
	return Vector3.new(stage.X, 4, stage.Z), Vector3.new(spot.X, 3.7, spot.Z + 0.5)
end

-- Chests are bought at the shop: standing in the Market, around its pads
-- and counters, on the island's ground.
function World:NearMarket(player)
	local root = player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not self.lobby then return false end
	local at = root.Position
	for _, d in ipairs(DISTRICTS) do
		if d.id == "market" then
			return at.X > d.x0 - 8 and at.X < d.x1 + 8 and at.Z > d.z0 - 8 and at.Z < d.z1 + 8 and at.Y < 30
		end
	end
	return false
end

function World:NearTraining(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - Vector3.new(TRAINING.pad.X, root.Position.Y, TRAINING.pad.Z)).Magnitude <= 28
end

function World:ParkourReached(player)
	local goal=self.parkourGoal
	local root=goal and player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return false end
	local offset=root.Position-goal
	return math.sqrt(offset.X*offset.X+offset.Z*offset.Z)<=3 and offset.Y>=1 and offset.Y<=8
end

-- Which AFK farm (if any) a lobby visitor stands in, from the server's own
-- view of their character. The payout loop in the bootstrap asks this.
function World:AfkZoneOf(player)
	local root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	for _,kind in ipairs(self.catalog.AfkOrder or {}) do
		local zone=self.afkZones and self.afkZones[kind]
		if zone then
			local offset=root.Position-zone.center
			if math.abs(offset.X)<=zone.size.X/2 and math.abs(offset.Y)<=zone.size.Y/2 and math.abs(offset.Z)<=zone.size.Z/2 then return kind end
		end
	end
	return nil
end

-- The arena's three-column season board: { [mapId] = rows } from the same
-- solo ranked leaderboards the in-game panel reads.
function World:UpdateArenaScoreboard(boards)
	for _,column in ipairs(self.arenaColumns or {}) do
		local rows=boards and boards[column.mapId]
		if rows then
			local lines={}
			for index,row in ipairs(rows) do
				if index>5 then break end
				table.insert(lines,string.format("#%d  %s — %d",row.rank,row.name or tostring(row.userId),row.waves))
			end
			if #lines==0 then lines={"Seja o primeiro!"} end
			column.label.Text=table.concat(lines,"\n")
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
local CITY_BILLBOARDS = {
	{ "STARK INDUSTRIES", { 255, 196, 72 } }, { "DAILY BUGLE", { 255, 90, 90 } }, { "OSCORP", { 110, 220, 255 } },
	{ "AVENGERS", { 240, 240, 255 } }, { "S.H.I.E.L.D.", { 140, 200, 255 } }, { "PYM TECH", { 255, 120, 150 } },
	{ "ROXXON", { 255, 160, 60 } }, { "BAXTER", { 120, 170, 255 } },
}

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
	elseif width >= 12 then
		-- An empty roof gets a lit billboard facing the battlefield. The brand
		-- comes from the building's position, not the RNG, so adding signs
		-- never reshuffles the rest of the city.
		local spot = face.Position
		local brand = CITY_BILLBOARDS[math.floor(math.abs(spot.X) * 7 + math.abs(spot.Z) * 3) % #CITY_BILLBOARDS + 1]
		local tint = Color3.fromRGB(brand[2][1], brand[2][2], brand[2][3])
		local w, h = math.min(width * 0.75, 15), 4.6
		local panelCf = face * CFrame.new(0, height + 2.5 + h / 2, 2)
		for _, lateral in ipairs({ -w / 3, w / 3 }) do
			prop(folder, "BillboardLeg", Vector3.new(0.35, 1.6, 0.35), face * CFrame.new(lateral, height + 1.7, 2.3), Color3.fromRGB(40, 42, 46), Enum.Material.Metal)
		end
		local panel = prop(folder, "Billboard", Vector3.new(w, h, 0.4), panelCf, Color3.fromRGB(18, 20, 30), Enum.Material.SmoothPlastic)
		for _, edge in ipairs({ -1, 1 }) do
			prop(folder, "BillboardTrim", Vector3.new(w + 0.4, 0.3, 0.5), panelCf * CFrame.new(0, edge * (h / 2 + 0.1), -0.02), tint, Enum.Material.Neon)
		end
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face, gui.CanvasSize = "Artwork", Enum.NormalId.Front, Vector2.new(math.floor(w * 40), math.floor(h * 40))
		gui.LightInfluence, gui.Brightness, gui.Parent = 0, 1.6, panel
		local text = Instance.new("TextLabel")
		text.Name, text.BackgroundTransparency, text.Size = "Brand", 1, UDim2.fromScale(0.92, 0.8)
		text.Position, text.Text, text.Font = UDim2.fromScale(0.04, 0.1), brand[1], Enum.Font.FredokaOne
		text.TextScaled, text.TextColor3 = true, tint:Lerp(Color3.new(1, 1, 1), 0.3)
		text.TextStrokeColor3, text.TextStrokeTransparency, text.Parent = Color3.fromRGB(8, 8, 12), 0.2, gui
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

-- A barricade stands across each road exactly where its rule stops enemies:
-- BARRIER_DISTANCE studs before the core (MatchService._basesStep). Roads
-- that share their last stretch share one barrier.
local BARRIER_DISTANCE = 15
World.BarrierDistance = BARRIER_DISTANCE
function World:UpdateBarrier(index, base, routes, health)
	local name = "PlayerBarrier_" .. index
	local old = self.Scenery and self.Scenery:FindFirstChild(name)
	if old then old:Destroy() end
	if not self.Scenery or not base.stats or (base.stats.wall or 0) <= 0 then return end
	local model = Instance.new("Model")
	model.Name, model.Parent = name, self.Scenery
	local tint = Color3.fromRGB(unpack(self.catalog.Bases[base.id].color))
	local placed = {}
	for _, route in ipairs(routes or {}) do
		local remaining, at, direction = math.max(0, route.total - BARRIER_DISTANCE), nil, nil
		for i, length in ipairs(route.lengths) do
			if remaining <= length then
				local a, b = route.points[i], route.points[i + 1]
				at, direction = a:Lerp(b, if length > 0 then remaining / length else 0), (b - a).Unit
				break
			end
			remaining -= length
		end
		local duplicate = false
		for _, other in ipairs(placed) do if at and (other - at).Magnitude < 3 then duplicate = true end end
		if at and not duplicate then
			table.insert(placed, at)
			local cf = CFrame.lookAt(at + Vector3.new(0, 2.2, 0), at + direction + Vector3.new(0, 2.2, 0))
			local field = part(model, "BarrierField", Vector3.new(12, 4.4, 0.5), cf, tint, Enum.Material.ForceField)
			field.CanCollide, field.CanQuery = false, false
			for _, side in ipairs({ -1, 1 }) do
				local post = part(model, "BarrierPost", Vector3.new(0.8, 5.4, 0.8), cf * CFrame.new(side * 6.4, 0.5, 0), Color3.fromRGB(53, 48, 61), Enum.Material.Metal)
				post.CanCollide = false
				local cap = part(model, "BarrierLight", Vector3.new(0.9, 0.35, 0.9), cf * CFrame.new(side * 6.4, 3.3, 0), tint, Enum.Material.Neon)
				cap.CanCollide = false
			end
		end
	end
	self:SetBarrierHealth(index, health or 1)
end

-- A worn barricade fades; a fresh one glows solid.
function World:SetBarrierHealth(index, ratio)
	local model = self.Scenery and self.Scenery:FindFirstChild("PlayerBarrier_" .. index)
	if not model then return end
	for _, piece in ipairs(model:GetChildren()) do
		if piece.Name == "BarrierField" then piece.Transparency = 0.25 + 0.7 * (1 - math.clamp(ratio, 0, 1)) end
	end
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
	-- A layered emplacement instead of a flat disc: a dark skirt under the
	-- ring (never above it, or the recoil animation would be hidden), a
	-- glowing inset in the hero's colour and three studs on the rim.
	local skirt = part(model, "PlatformSkirt", Vector3.new(0.12, 6.6, 6.6), CFrame.new(position.X, 0.06, position.Z)*flat, Color3.fromRGB(30, 35, 48), Enum.Material.Metal)
	local inset = part(model, "PlatformInset", Vector3.new(0.06, 4.1, 4.1), CFrame.new(position.X, 0.6, position.Z)*flat, color, Enum.Material.Neon)
	skirt.Shape, inset.Shape = Enum.PartType.Cylinder, Enum.PartType.Cylinder
	inset.Transparency = 0.45
	for _, offset in ipairs({ { 2.45, 0 }, { -2.45, 0 }, { 0, -2.45 } }) do
		part(model, "PlatformStud", Vector3.new(0.42, 0.22, 0.42), CFrame.new(position.X + offset[1], 0.62, position.Z + offset[2]), color:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.Neon)
	end
	-- The server owns the ring's canonical width; the client's firing recoil
	-- animates around it and restores to whatever this says, so an upgrade
	-- landing mid-recoil is never undone by the animation finishing late.
	ring:SetAttribute("BaseSize", 5.8)
	-- Towers stand a head taller than a commander, so a hero reads as the
	-- defence it is from the far camera, not as another avatar in the crowd.
	local scale = (FIGURE_SCALE[heroId] or 1) * 1.15
	local origin = CFrame.new(position.X, 0.55, position.Z)
	local torso, head = heroFigure(model, heroId, hero, origin, scale)
	for _, p in ipairs(model:GetDescendants()) do if p:IsA("BasePart") then p.CanCollide = false p:SetAttribute("TowerId", id) end end
	model.PrimaryPart, model.Parent = base, self.Towers
	self:ClearClutter(position, 2.9)
	local title = label(head, hero.name.pt, Vector3.new(0, 2, 0), color:Lerp(Color3.new(1, 1, 1), 0.75), 145, 55)
	title.Font, title.TextSize = Enum.Font.FredokaOne, 15
	title.TextStrokeColor3, title.TextStrokeTransparency = Color3.fromRGB(12, 13, 20), 0
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
	-- A jointed hero wears its evolution; final art keeps the floating emblem.
	local figure = model:FindFirstChild("HeroFigure")
	if figure and figure:GetAttribute("HeroRig") then
		local hero = self.catalog.Heroes[model:GetAttribute("HeroId")]
		Figure.Gear(model, level, branch, hero and rgb(hero.color) or Color3.fromRGB(255, 208, 92))
	end
	local head = figure and not figure:GetAttribute("HeroRig") and figure:FindFirstChild("Head", true)
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
