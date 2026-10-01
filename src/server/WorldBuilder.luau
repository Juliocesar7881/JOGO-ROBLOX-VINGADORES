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
-- portraits — and changes nothing but the look.
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
	ironman = { colors = { chest = Color3.fromRGB(36, 110, 220), pelvis = HC.white, upperArm = Color3.fromRGB(36, 110, 220), lowerArm = HC.white, hand = Color3.fromRGB(36, 110, 220), upperLeg = Color3.fromRGB(36, 110, 220), lowerLeg = HC.white, foot = Color3.fromRGB(36, 110, 220), head = HC.white }, shiny = true },
	hawkeye = { colors = { chest = Color3.fromRGB(52, 128, 80), pelvis = HC.ink, upperArm = HC.skin, lowerArm = HC.ink, hand = HC.skin, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.leather }, face = "fierce", hair = { Color3.fromRGB(122, 88, 54), "fringe" } },
	falcon = { colors = { skin = HC.brown, chest = Color3.fromRGB(60, 150, 230), pelvis = HC.ink, upperArm = Color3.fromRGB(60, 150, 230), lowerArm = HC.ink, hand = HC.ink, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "smile", hair = { HC.ink } },
	bucky = { colors = { chest = Color3.fromRGB(78, 96, 58), pelvis = HC.ink, upperArm = HC.silver, lowerArm = HC.silver, hand = HC.silver, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "fierce", hair = { Color3.fromRGB(58, 42, 34), "long" } },
	spiderman = { body = { width = 0.9, arm = 0.9, leg = 0.92 }, colors = { chest = Color3.fromRGB(128, 70, 210), pelvis = Color3.fromRGB(250, 140, 40), upperArm = Color3.fromRGB(128, 70, 210), lowerArm = Color3.fromRGB(250, 140, 40), hand = Color3.fromRGB(250, 140, 40), upperLeg = Color3.fromRGB(128, 70, 210), lowerLeg = Color3.fromRGB(250, 140, 40), foot = Color3.fromRGB(128, 70, 210) }, face = "smile", hair = { Color3.fromRGB(92, 52, 34), "long" } },
	widow = { body = { width = 0.88, arm = 0.88, leg = 0.9, chest = 0.94 }, colors = { chest = Color3.fromRGB(34, 36, 80), pelvis = Color3.fromRGB(34, 36, 80), upperArm = Color3.fromRGB(34, 36, 80), lowerArm = Color3.fromRGB(34, 36, 80), hand = Color3.fromRGB(34, 36, 80), upperLeg = Color3.fromRGB(34, 36, 80), lowerLeg = Color3.fromRGB(34, 36, 80), foot = Color3.fromRGB(34, 36, 80) }, face = "fierce", hair = { Color3.fromRGB(220, 224, 236), "long" } },
	antman = { colors = { head = Color3.fromRGB(110, 200, 70), chest = Color3.fromRGB(110, 200, 70), pelvis = HC.ink, upperArm = Color3.fromRGB(110, 200, 70), lowerArm = HC.ink, hand = HC.ink, upperLeg = Color3.fromRGB(110, 200, 70), lowerLeg = HC.ink, foot = HC.ink }, shiny = true },
	wasp = { body = { scale = 0.9, width = 0.86, arm = 0.86, leg = 0.88 }, colors = { head = Color3.fromRGB(150, 230, 90), chest = Color3.fromRGB(150, 230, 90), pelvis = Color3.fromRGB(30, 70, 60), upperArm = Color3.fromRGB(30, 70, 60), lowerArm = Color3.fromRGB(150, 230, 90), hand = Color3.fromRGB(30, 70, 60), upperLeg = Color3.fromRGB(30, 70, 60), lowerLeg = Color3.fromRGB(150, 230, 90), foot = Color3.fromRGB(30, 70, 60) } },
	rocket = { body = { scale = 0.62, head = 1.36, legLength = 0.78, armLength = 0.9, width = 1.02 }, colors = { skin = Color3.fromRGB(150, 104, 72), head = Color3.fromRGB(150, 104, 72), chest = Color3.fromRGB(64, 150, 96), pelvis = HC.ink, upperArm = Color3.fromRGB(64, 150, 96), lowerArm = Color3.fromRGB(150, 104, 72), hand = Color3.fromRGB(150, 104, 72), upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "grin" },
	daredevil = { colors = { head = Color3.fromRGB(70, 82, 110), chest = Color3.fromRGB(70, 82, 110), pelvis = Color3.fromRGB(44, 52, 74), upperArm = Color3.fromRGB(70, 82, 110), lowerArm = Color3.fromRGB(70, 82, 110), hand = Color3.fromRGB(44, 52, 74), upperLeg = Color3.fromRGB(70, 82, 110), lowerLeg = Color3.fromRGB(70, 82, 110), foot = Color3.fromRGB(44, 52, 74) } },
	shangchi = { colors = { chest = Color3.fromRGB(40, 150, 110), pelvis = HC.ink, upperArm = Color3.fromRGB(40, 150, 110), lowerArm = HC.skin, hand = HC.skin, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "fierce", hair = { HC.ink, "fringe" } },
	captain = { colors = { chest = Color3.fromRGB(22, 150, 140), pelvis = Color3.fromRGB(196, 140, 72), upperArm = Color3.fromRGB(22, 150, 140), lowerArm = HC.white, hand = Color3.fromRGB(196, 140, 72), upperLeg = Color3.fromRGB(22, 150, 140), lowerLeg = HC.white, foot = Color3.fromRGB(196, 140, 72), head = Color3.fromRGB(22, 150, 140) } },
	panther = { colors = { head = Color3.fromRGB(58, 36, 96), chest = Color3.fromRGB(58, 36, 96), pelvis = Color3.fromRGB(44, 28, 74), upperArm = Color3.fromRGB(58, 36, 96), lowerArm = Color3.fromRGB(58, 36, 96), hand = Color3.fromRGB(44, 28, 74), upperLeg = Color3.fromRGB(58, 36, 96), lowerLeg = Color3.fromRGB(58, 36, 96), foot = Color3.fromRGB(44, 28, 74) }, shiny = true },
	hulk = { body = { scale = 1.72, width = 1.1, depth = 1.12, chest = 1.14, head = 0.8, arm = 1.55, hand = 1.3, leg = 1.36, legLength = 0.88, torsoLength = 1.1, foot = 1.1 },
		colors = { skin = Color3.fromRGB(152, 138, 120), head = Color3.fromRGB(152, 138, 120), chest = Color3.fromRGB(152, 138, 120), pelvis = Color3.fromRGB(86, 76, 66), upperArm = Color3.fromRGB(152, 138, 120), lowerArm = Color3.fromRGB(140, 126, 110), hand = Color3.fromRGB(152, 138, 120), upperLeg = Color3.fromRGB(86, 76, 66), lowerLeg = Color3.fromRGB(140, 126, 110), foot = Color3.fromRGB(120, 108, 96) }, face = "angry" },
	vision = { colors = { skin = Color3.fromRGB(220, 236, 248), head = Color3.fromRGB(220, 236, 248), chest = Color3.fromRGB(110, 150, 230), pelvis = Color3.fromRGB(110, 150, 230), upperArm = Color3.fromRGB(110, 150, 230), lowerArm = Color3.fromRGB(220, 236, 248), hand = Color3.fromRGB(220, 236, 248), upperLeg = Color3.fromRGB(110, 150, 230), lowerLeg = Color3.fromRGB(220, 236, 248), foot = HC.gold }, face = "smile", shiny = true },
	warmachine = { body = { width = 1.08, arm = 1.08, leg = 1.06 }, colors = { head = Color3.fromRGB(176, 108, 52), chest = Color3.fromRGB(176, 108, 52), pelvis = HC.ink, upperArm = Color3.fromRGB(176, 108, 52), lowerArm = HC.ink, hand = Color3.fromRGB(176, 108, 52), upperLeg = Color3.fromRGB(176, 108, 52), lowerLeg = HC.ink, foot = Color3.fromRGB(176, 108, 52) }, shiny = true },
	starlord = { colors = { chest = Color3.fromRGB(30, 110, 130), pelvis = HC.ink, upperArm = Color3.fromRGB(36, 126, 146), lowerArm = Color3.fromRGB(36, 126, 146), hand = HC.ink, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.leather, head = Color3.fromRGB(40, 60, 80) } },
	groot = { body = { scale = 1.52, width = 0.74, depth = 0.8, head = 0.92, arm = 0.8, leg = 0.86, legLength = 1.18, armLength = 1.24, torsoLength = 1.08, hand = 1.1 },
		colors = { skin = Color3.fromRGB(112, 82, 54), head = Color3.fromRGB(128, 94, 62), chest = Color3.fromRGB(112, 82, 54), pelvis = Color3.fromRGB(96, 70, 46), upperArm = Color3.fromRGB(112, 82, 54), lowerArm = Color3.fromRGB(104, 76, 50), hand = Color3.fromRGB(96, 70, 46), upperLeg = Color3.fromRGB(104, 76, 50), lowerLeg = Color3.fromRGB(96, 70, 46), foot = Color3.fromRGB(84, 60, 40) }, material = Enum.Material.Wood, face = "smile" },
	thor = { body = { width = 1.1, arm = 1.12, leg = 1.04 }, colors = { chest = Color3.fromRGB(54, 74, 120), pelvis = HC.ink, upperArm = Color3.fromRGB(54, 74, 120), lowerArm = HC.silver, hand = HC.silver, upperLeg = HC.ink, lowerLeg = Color3.fromRGB(54, 74, 120), foot = HC.ink }, face = "fierce", hair = { Color3.fromRGB(226, 234, 246), "spiky" } },
	wanda = { body = { width = 0.88, arm = 0.86, leg = 0.9 }, colors = { chest = Color3.fromRGB(196, 50, 140), pelvis = HC.ink, upperArm = Color3.fromRGB(196, 50, 140), lowerArm = Color3.fromRGB(196, 50, 140), hand = HC.skin, upperLeg = HC.ink, lowerLeg = HC.ink, foot = Color3.fromRGB(196, 50, 140) }, face = "smile", hair = { Color3.fromRGB(40, 30, 50), "long" } },
	strange = { colors = { chest = Color3.fromRGB(88, 48, 140), pelvis = Color3.fromRGB(90, 62, 44), upperArm = Color3.fromRGB(88, 48, 140), lowerArm = Color3.fromRGB(88, 48, 140), hand = HC.skin, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "fierce", hair = { HC.ink, "fringe" } },
	ghostrider = { colors = { head = Color3.fromRGB(200, 80, 30), chest = Color3.fromRGB(40, 36, 44), pelvis = HC.ink, upperArm = Color3.fromRGB(40, 36, 44), lowerArm = Color3.fromRGB(40, 36, 44), hand = HC.ink, upperLeg = HC.ink, lowerLeg = Color3.fromRGB(40, 36, 44), foot = HC.ink } },
	captainmarvel = { body = { width = 0.9, arm = 0.88, leg = 0.92 }, colors = { chest = HC.white, pelvis = Color3.fromRGB(236, 176, 60), upperArm = HC.white, lowerArm = Color3.fromRGB(236, 176, 60), hand = Color3.fromRGB(236, 176, 60), upperLeg = HC.white, lowerLeg = Color3.fromRGB(236, 176, 60), foot = Color3.fromRGB(236, 176, 60) }, face = "fierce", hair = { Color3.fromRGB(255, 132, 56), "long" } },
	silversurfer = { body = { width = 0.9, arm = 0.9 }, colors = { skin = Color3.fromRGB(172, 150, 240), head = Color3.fromRGB(172, 150, 240), chest = Color3.fromRGB(150, 128, 226), pelvis = Color3.fromRGB(122, 100, 206), upperArm = Color3.fromRGB(150, 128, 226), lowerArm = Color3.fromRGB(150, 128, 226), hand = Color3.fromRGB(172, 150, 240), upperLeg = Color3.fromRGB(122, 100, 206), lowerLeg = Color3.fromRGB(122, 100, 206), foot = Color3.fromRGB(172, 150, 240) }, face = "smile", shiny = true },
	wolverine = { body = { scale = 0.94, width = 1.12, arm = 1.08, leg = 1.02 }, colors = { chest = Color3.fromRGB(235, 130, 40), pelvis = HC.ink, upperArm = HC.ink, lowerArm = Color3.fromRGB(235, 130, 40), hand = HC.ink, upperLeg = Color3.fromRGB(235, 130, 40), lowerLeg = HC.ink, foot = HC.ink }, face = "fierce", hair = { Color3.fromRGB(46, 32, 24), "spiky" } },
	cyclops = { colors = { head = Color3.fromRGB(232, 236, 242), chest = Color3.fromRGB(232, 236, 242), pelvis = Color3.fromRGB(214, 60, 52), upperArm = Color3.fromRGB(232, 236, 242), lowerArm = Color3.fromRGB(214, 60, 52), hand = Color3.fromRGB(214, 60, 52), upperLeg = Color3.fromRGB(232, 236, 242), lowerLeg = Color3.fromRGB(232, 236, 242), foot = Color3.fromRGB(214, 60, 52) } },
	storm = { body = { width = 0.9, arm = 0.88, leg = 0.92 }, colors = { skin = HC.deep, chest = Color3.fromRGB(40, 170, 170), pelvis = Color3.fromRGB(24, 60, 70), upperArm = Color3.fromRGB(40, 170, 170), lowerArm = Color3.fromRGB(40, 170, 170), hand = HC.deep, upperLeg = Color3.fromRGB(24, 60, 70), lowerLeg = Color3.fromRGB(24, 60, 70), foot = Color3.fromRGB(24, 60, 70) }, face = "smile", hair = { Color3.fromRGB(40, 170, 170), "long" } },
	jean = { body = { width = 0.88, arm = 0.86, leg = 0.9 }, colors = { chest = Color3.fromRGB(150, 80, 220), pelvis = Color3.fromRGB(255, 150, 210), upperArm = Color3.fromRGB(150, 80, 220), lowerArm = Color3.fromRGB(150, 80, 220), hand = Color3.fromRGB(255, 150, 210), upperLeg = Color3.fromRGB(150, 80, 220), lowerLeg = Color3.fromRGB(150, 80, 220), foot = Color3.fromRGB(255, 150, 210) }, face = "smile", hair = { Color3.fromRGB(250, 230, 240), "long" } },
	iceman = { colors = { skin = Color3.fromRGB(172, 238, 255), head = Color3.fromRGB(172, 238, 255), chest = Color3.fromRGB(236, 246, 255), pelvis = Color3.fromRGB(110, 170, 230), upperArm = Color3.fromRGB(236, 246, 255), lowerArm = Color3.fromRGB(236, 246, 255), hand = Color3.fromRGB(172, 238, 255), upperLeg = Color3.fromRGB(110, 170, 230), lowerLeg = Color3.fromRGB(236, 246, 255), foot = Color3.fromRGB(172, 238, 255) }, material = Enum.Material.Ice, face = "smile" },
	gambit = { colors = { chest = Color3.fromRGB(200, 40, 60), pelvis = Color3.fromRGB(28, 28, 36), upperArm = Color3.fromRGB(60, 60, 72), lowerArm = Color3.fromRGB(60, 60, 72), hand = HC.ink, upperLeg = Color3.fromRGB(28, 28, 36), lowerLeg = Color3.fromRGB(28, 28, 36), foot = Color3.fromRGB(200, 40, 60) }, face = "fierce", hair = { Color3.fromRGB(94, 56, 38), "long" } },
	nightcrawler = { colors = { skin = Color3.fromRGB(236, 200, 72), head = Color3.fromRGB(236, 200, 72), chest = Color3.fromRGB(32, 32, 40), pelvis = Color3.fromRGB(255, 150, 40), upperArm = Color3.fromRGB(32, 32, 40), lowerArm = Color3.fromRGB(32, 32, 40), hand = Color3.fromRGB(236, 200, 72), upperLeg = Color3.fromRGB(32, 32, 40), lowerLeg = Color3.fromRGB(32, 32, 40), foot = Color3.fromRGB(236, 200, 72) }, face = "lens", faceOptions = { lens = Color3.fromRGB(255, 222, 90), glow = true, width = 0.3, height = 0.24 }, hair = { Color3.fromRGB(30, 34, 90), "spiky" } },
	beast = { body = { scale = 1.12, width = 1.24, chest = 1.1, arm = 1.3, hand = 1.3, leg = 1.12, legLength = 0.88, head = 0.92 }, colors = { skin = Color3.fromRGB(214, 160, 70), head = Color3.fromRGB(232, 180, 90), chest = Color3.fromRGB(214, 160, 70), pelvis = Color3.fromRGB(110, 60, 30), upperArm = Color3.fromRGB(214, 160, 70), lowerArm = Color3.fromRGB(214, 160, 70), hand = Color3.fromRGB(232, 180, 90), upperLeg = Color3.fromRGB(110, 60, 30), lowerLeg = Color3.fromRGB(214, 160, 70), foot = Color3.fromRGB(232, 180, 90) }, face = "grin", hair = { Color3.fromRGB(120, 70, 30), "spiky" } },
	psylocke = { body = { width = 0.88, arm = 0.86, leg = 0.9 }, colors = { chest = Color3.fromRGB(170, 30, 50), pelvis = Color3.fromRGB(170, 30, 50), upperArm = HC.skin, lowerArm = Color3.fromRGB(170, 30, 50), hand = Color3.fromRGB(240, 220, 200), upperLeg = HC.skin, lowerLeg = Color3.fromRGB(170, 30, 50), foot = Color3.fromRGB(170, 30, 50) }, face = "fierce", hair = { Color3.fromRGB(110, 20, 34), "long" } },
	deadpool = { colors = { head = Color3.fromRGB(40, 200, 190), chest = Color3.fromRGB(240, 90, 170), pelvis = Color3.fromRGB(40, 200, 190), upperArm = Color3.fromRGB(240, 90, 170), lowerArm = Color3.fromRGB(40, 200, 190), hand = HC.white, upperLeg = Color3.fromRGB(40, 200, 190), lowerLeg = Color3.fromRGB(240, 90, 170), foot = HC.white } },
	moonknight = { colors = { head = Color3.fromRGB(36, 38, 52), chest = Color3.fromRGB(36, 38, 52), pelvis = Color3.fromRGB(170, 176, 196), upperArm = Color3.fromRGB(36, 38, 52), lowerArm = Color3.fromRGB(36, 38, 52), hand = Color3.fromRGB(170, 176, 196), upperLeg = Color3.fromRGB(36, 38, 52), lowerLeg = Color3.fromRGB(36, 38, 52), foot = Color3.fromRGB(170, 176, 196) } },
	nova = { colors = { head = Color3.fromRGB(236, 244, 250), chest = Color3.fromRGB(40, 150, 200), pelvis = Color3.fromRGB(40, 150, 200), upperArm = Color3.fromRGB(40, 150, 200), lowerArm = Color3.fromRGB(236, 244, 250), hand = Color3.fromRGB(236, 244, 250), upperLeg = Color3.fromRGB(40, 150, 200), lowerLeg = Color3.fromRGB(236, 244, 250), foot = Color3.fromRGB(236, 244, 250) }, shiny = true },
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
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local bolt, spark = Color3.fromRGB(255, 214, 64), Color3.fromRGB(120, 230, 255)
	-- Volt: a white helmet with one wide visor and a crest, a lightning bolt
	-- across the chest and glowing palms.
	f.add("Head", "Visor", Vector3.new(h.X * 0.8, 0.24 * s, 0.08 * s), f.face(0, 0.08, 0.03), spark, NEON)
	f.add("Head", "HelmetCrest", Vector3.new(0.16 * s, h.Y * 0.5, h.Z * 0.9), CFrame.new(0, h.Y * 0.42, 0), Color3.fromRGB(36, 110, 220), METAL)
	f.add("UpperTorso", "BoltTop", Vector3.new(0.22, 0.62, 0.06) * s, CFrame.new(0.08 * s, 0.36 * s, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, -0.5), bolt, NEON)
	f.add("UpperTorso", "BoltBottom", Vector3.new(0.22, 0.62, 0.06) * s, CFrame.new(-0.08 * s, -0.06 * s, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, -0.5), bolt, NEON)
	for _, side in ipairs({ -1, 1 }) do
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "ShoulderPlate", f.sizes.upperArm * Vector3.new(1.18, 0.46, 1.16), CFrame.new(0, f.sizes.upperArm.Y * 0.3, 0), HC.white, METAL)
		f.disc(side < 0 and "LeftHand" or "RightHand", "Repulsor", 0.34 * s, 0.06 * s, CFrame.new(0, -f.sizes.hand.Y / 2 - 0.02 * s, 0) * CFrame.Angles(math.pi / 2, 0, 0), spark, NEON)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.captain = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local teal, bronze = Color3.fromRGB(22, 150, 140), Color3.fromRGB(196, 140, 72)
	-- Commander Aegis: a crested half-helm, a bronze chevron and the round
	-- aegis on the left forearm.
	f.add("Head", "Chin", Vector3.new(h.X * 0.66, h.Y * 0.38, 0.1 * s), f.face(0, -0.52, -0.03), HC.skin, FABRIC)
	f.add("Head", "Mouth", Vector3.new(0.26, 0.06, 0.05) * s, f.face(0, -0.52, 0.04), HC.ink, FABRIC)
	f.add("Head", "HelmetCrest", Vector3.new(0.14 * s, h.Y * 0.44, h.Z * 1.04), CFrame.new(0, h.Y * 0.44, 0), bronze, METAL)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Eye", Vector3.new(0.17, 0.26, 0.06) * s, f.face(side * 0.26, 0.14, 0.0), HC.ink, FABRIC, "ball")
		f.add("UpperTorso", "Chevron", Vector3.new(0.18 * s, 0.7 * s, 0.06 * s), CFrame.new(side * 0.2 * s, c.Y * 0.16, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, side * 0.75), bronze, METAL)
	end
	belt(f, HC.leather, bronze)
	local arm = f.sizes.lowerArm
	f.add("LeftLowerArm", "Shield", Vector3.new(0.14 * s, 2.3 * s, 2.3 * s), CFrame.new(-arm.X / 2 - 0.12 * s, 0, -0.1 * s), bronze, METAL, Enum.PartType.Cylinder)
	f.add("LeftLowerArm", "ShieldFace", Vector3.new(0.14 * s, 1.95 * s, 1.95 * s), CFrame.new(-arm.X / 2 - 0.16 * s, 0, -0.1 * s), teal, METAL, Enum.PartType.Cylinder)
	for _, side in ipairs({ -1, 1 }) do
		f.add("LeftLowerArm", "ShieldMark", Vector3.new(0.06 * s, 0.9 * s, 0.22 * s), CFrame.new(-arm.X / 2 - 0.24 * s, 0.05 * s, -0.1 * s + side * 0.22 * s) * CFrame.Angles(side * 0.75, 0, 0), HC.white, METAL)
	end
	muzzle(f, "LeftLowerArm", Vector3.new(-arm.X / 2 - 0.3 * s, 0, 0))
end
HERO_EXTRAS.spiderman = function(f)
	local s, c = f.scale, f.sizes.chest
	local rope, orange = Color3.fromRGB(214, 170, 96), Color3.fromRGB(250, 140, 40)
	-- Lasso: goggles on the forehead, a diamond on the chest, a rope coil on
	-- the hip and the lasso's loop in the right hand.
	f.add("Head", "Goggles", Vector3.new(f.parts.Head.Size.X * 0.84, 0.18 * s, 0.1 * s), f.face(0, 0.42, 0.02), Color3.fromRGB(60, 40, 90), METAL)
	for _, side in ipairs({ -1, 1 }) do f.disc("Head", "GoggleLens", 0.15 * s, 0.05 * s, f.face(side * 0.24, 0.42, 0.06), Color3.fromRGB(120, 230, 255), NEON) end
	f.add("UpperTorso", "Emblem", Vector3.new(0.48, 0.48, 0.06) * s, CFrame.new(0, 0.2 * s, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, math.pi / 4), orange, FABRIC)
	f.disc("LowerTorso", "LassoCoil", 0.42 * s, 0.14 * s, CFrame.new(f.sizes.pelvis.X / 2 + 0.06 * s, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), rope, FABRIC)
	local r = 0.6 * s
	for i = 0, 7 do
		local a0, a1 = i * math.pi / 4, (i + 1) * math.pi / 4
		f.rod("RightHand", "Lasso", Vector3.new(math.cos(a0) * r, -0.8 * s + math.sin(a0) * r, 0), Vector3.new(math.cos(a1) * r, -0.8 * s + math.sin(a1) * r, 0), 0.07 * s, rope, FABRIC)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.08 * s, 0))
end
HERO_EXTRAS.hulk = function(f)
	local s, c = f.scale, f.sizes.chest
	local stone, glow = Color3.fromRGB(168, 154, 134), Color3.fromRGB(255, 140, 50)
	-- Boulder: a living rock with lava in its cracks and stone plates on the
	-- shoulders and chest.
	for _, side in ipairs({ -1, 1 }) do
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "RockPlate", f.sizes.upperArm * Vector3.new(1.2, 0.5, 1.2), CFrame.new(0, f.sizes.upperArm.Y * 0.32, 0) * CFrame.Angles(0.2, 0, side * 0.2), stone, Enum.Material.Slate)
		f.add("UpperTorso", "ChestRock", Vector3.new(c.X * 0.42, c.Y * 0.36, 0.22 * s), CFrame.new(side * c.X * 0.22, c.Y * 0.16, -c.Z / 2 - 0.02 * s) * CFrame.Angles(0, 0, side * 0.08), stone, Enum.Material.Slate)
	end
	for i = -1, 1 do
		f.add("UpperTorso", "LavaCrack", Vector3.new(0.08 * s, c.Y * 0.5, 0.06 * s), CFrame.new(i * c.X * 0.16, -c.Y * 0.14, -c.Z / 2 - 0.06 * s) * CFrame.Angles(0, 0, i * 0.4), glow, NEON)
	end
	f.add("LowerTorso", "Waistband", f.sizes.pelvis * Vector3.new(1.06, 0.34, 1.08), CFrame.new(0, f.sizes.pelvis.Y * 0.3, 0), Color3.fromRGB(96, 84, 72), Enum.Material.Slate)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2, 0))
end
HERO_EXTRAS.hawkeye = function(f)
	local s = f.scale
	local hand = f.sizes.hand
	-- The bow in the left hand, an arrow nocked; a quiver on the back.
	local limbs = { Vector3.new(0, 1.4, -0.3), Vector3.new(0, 0.7, -0.62), Vector3.new(0, 0, -0.7), Vector3.new(0, -0.7, -0.62), Vector3.new(0, -1.4, -0.3) }
	for i = 1, #limbs - 1 do f.rod("LeftHand", "Bow", limbs[i] * s, limbs[i + 1] * s, 0.14 * s, Color3.fromRGB(70, 150, 96), METAL) end
	f.rod("LeftHand", "Bowstring", limbs[1] * s, limbs[#limbs] * s, 0.03 * s, HC.silver, METAL)
	f.add("UpperTorso", "Quiver", Vector3.new(0.5, 1.7, 0.5) * s, CFrame.new(0.4 * s, 0.2 * s, f.sizes.chest.Z / 2 + 0.25 * s) * CFrame.Angles(0, 0, -0.35), HC.leather, FABRIC)
	for i = 1, 3 do f.add("UpperTorso", "QuiverArrow", Vector3.new(0.06, 0.6, 0.06) * s, CFrame.new((0.62 + i * 0.1) * s, 1.1 * s, f.sizes.chest.Z / 2 + 0.25 * s) * CFrame.Angles(0, 0, -0.35), HC.silver, METAL) end
	f.rod("UpperTorso", "Harness", Vector3.new(-f.sizes.chest.X * 0.4, f.sizes.chest.Y * 0.44, -f.sizes.chest.Z / 2 - 0.03 * s), Vector3.new(f.sizes.chest.X * 0.4, -f.sizes.chest.Y * 0.44, -f.sizes.chest.Z / 2 - 0.03 * s), 0.14 * s, HC.leather, FABRIC)
	muzzle(f, "LeftHand", Vector3.new(0, 0, -0.75 * s))
end
HERO_EXTRAS.thor = function(f)
	local s, c = f.scale, f.sizes.chest
	local storm, spark = Color3.fromRGB(40, 70, 160), Color3.fromRGB(140, 220, 255)
	-- Brontus: a storm caller in silver pauldrons and a blue cape, with a
	-- staff that holds a crackling orb.
	cape(f, storm, 3.6, HC.silver)
	for _, side in ipairs({ -1, 1 }) do
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "Pauldron", f.sizes.upperArm * Vector3.new(1.22, 0.5, 1.2), CFrame.new(0, f.sizes.upperArm.Y * 0.3, 0), HC.silver, METAL)
	end
	f.add("UpperTorso", "StormSigil", Vector3.new(0.2, 0.7, 0.06) * s, CFrame.new(0, 0.18 * s, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, -0.45), spark, NEON)
	f.rod("RightHand", "StaffShaft", Vector3.new(0, 1.6 * s, 0), Vector3.new(0, -1.4 * s, 0), 0.16 * s, Color3.fromRGB(120, 96, 70), FABRIC)
	local orb = f.add("RightHand", "StormOrb", Vector3.new(0.7, 0.7, 0.7) * s, CFrame.new(0, 1.85 * s, 0), spark, NEON, "ball")
	orb.Transparency = 0.15
	muzzle(f, "RightHand", Vector3.new(0, 1.85 * s, 0))
end
HERO_EXTRAS.widow = function(f)
	local s = f.scale
	belt(f, HC.steel, Color3.fromRGB(150, 110, 255))
	for _, side in ipairs({ -1, 1 }) do
		local hand = side < 0 and "LeftHand" or "RightHand"
		f.add(hand, "Pistol", Vector3.new(0.16, 0.7, 0.34) * s, CFrame.new(0, -0.35 * s, -0.08 * s), HC.ink, METAL)
		f.add(side < 0 and "LeftLowerArm" or "RightLowerArm", "Bracelet", f.sizes.lowerArm * Vector3.new(1.08, 0.2, 1.08), CFrame.new(0, -f.sizes.lowerArm.Y * 0.36, 0), HC.gold, METAL)
	end
	f.add("UpperTorso", "WidowInsignia", Vector3.new(0.3, 0.3, 0.05) * s, CFrame.new(0, -0.3 * s, -f.sizes.chest.Z / 2 - 0.03 * s) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(150, 110, 255), NEON)
	muzzle(f, "RightHand", Vector3.new(0, -0.75 * s, -0.08 * s))
end
HERO_EXTRAS.falcon = function(f)
	local s, c = f.scale, f.sizes.chest
	f.add("Head", "Goggles", Vector3.new(f.parts.Head.Size.X * 0.84, 0.24 * s, 0.1 * s), f.face(0, 0.14, 0.03), Color3.fromRGB(255, 200, 60), NEON)
	f.add("UpperTorso", "Jetpack", Vector3.new(c.X * 0.66, c.Y * 0.8, 0.46 * s), CFrame.new(0, 0.05 * s, c.Z / 2 + 0.22 * s), HC.steel, METAL)
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "Wing", Vector3.new(2.6 * s, 0.1 * s, 0.9 * s), CFrame.new(side * (c.X * 0.33 + 1.1 * s), 0.3 * s, c.Z / 2 + 0.3 * s) * CFrame.Angles(0, side * 0.4, side * 0.5), HC.silver, METAL, "wedge")
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.bucky = function(f)
	local s = f.scale
	-- Only the left arm is metal.
	f.parts.RightUpperArm.Color, f.parts.RightLowerArm.Color, f.parts.RightHand.Color = Color3.fromRGB(78, 96, 58), Color3.fromRGB(78, 96, 58), HC.skin
	for i = 1, 3 do f.add("LeftUpperArm", "ArmPlate", f.sizes.upperArm * Vector3.new(1.04, 0.06, 1.04), CFrame.new(0, f.sizes.upperArm.Y * (0.3 - i * 0.18), 0), HC.steel, METAL) end
	f.add("LeftUpperArm", "RedStar", Vector3.new(0.06, 0.26, 0.26) * s, CFrame.new(-f.sizes.upperArm.X / 2 - 0.02 * s, 0.1 * s, 0), Color3.fromRGB(240, 200, 70), METAL)
	f.add("RightHand", "Rifle", Vector3.new(0.22, 1.6, 0.34) * s, CFrame.new(0, -0.7 * s, -0.12 * s), HC.ink, METAL)
	f.add("RightHand", "RifleBarrel", Vector3.new(0.1, 0.8, 0.1) * s, CFrame.new(0, -1.8 * s, -0.12 * s), HC.steel, METAL)
	belt(f, HC.leather, HC.silver)
	muzzle(f, "RightHand", Vector3.new(0, -2.2 * s, -0.12 * s))
end
HERO_EXTRAS.antman = function(f)
	local s, h = f.scale, f.parts.Head.Size
	f.add("Head", "HelmetJaw", Vector3.new(h.X * 0.8, h.Y * 0.4, 0.12 * s), f.face(0, -0.5, -0.03), HC.ink, METAL)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "RedLens", Vector3.new(0.4, 0.3, 0.06) * s, f.face(side * 0.26, 0.14, 0.02), Color3.fromRGB(120, 230, 255), NEON, "ball")
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
	f.add("Head", "SonarVisor", Vector3.new(f.parts.Head.Size.X * 0.8, 0.2 * f.scale, 0.08 * f.scale), f.face(0, 0.12, 0.03), Color3.fromRGB(120, 230, 255), NEON)
	local s, h = f.scale, f.parts.Head.Size
	f.add("Head", "Chin", Vector3.new(h.X * 0.6, h.Y * 0.36, 0.1 * s), f.face(0, -0.52, -0.03), HC.skin, FABRIC)
	f.add("Head", "Mouth", Vector3.new(0.24, 0.06, 0.05) * s, f.face(0, -0.52, 0.04), HC.ink, FABRIC)
	Figure.Face(f, "lens", { lens = Color3.fromRGB(40, 48, 70), rim = Color3.fromRGB(40, 48, 70), width = 0.34, height = 0.22, slant = 0.3 })
	f.rod("RightHand", "Billy", Vector3.new(0, 0.2 * s, 0), Vector3.new(0, -1.3 * s, -0.1 * s), 0.14 * s, Color3.fromRGB(56, 66, 92), METAL)
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
	local gold, gem = Color3.fromRGB(236, 190, 84), Color3.fromRGB(180, 120, 255)
	-- Onyx: a crystal crest and chest gem, gold trims and gold claws.
	Figure.Face(f, "lens", { width = 0.36, height = 0.2, slant = 0.36, lens = gem })
	f.add("Head", "CrystalCrest", Vector3.new(0.16, 0.5, 0.5) * s, CFrame.new(0, h.Y * 0.5, 0), gem, NEON, "wedge")
	for _, side in ipairs({ -1, 1 }) do
		for i = -1, 1 do f.add(side < 0 and "LeftHand" or "RightHand", "Claw", Vector3.new(0.06, 0.34, 0.06) * s, CFrame.new(i * 0.16 * s, -f.sizes.hand.Y / 2 - 0.14 * s, -0.12 * s), gold, METAL) end
		f.add("UpperTorso", "GoldTrim", Vector3.new(0.12 * s, c.Y * 0.9, 0.06 * s), CFrame.new(side * c.X * 0.3, 0, -c.Z / 2 - 0.03 * s), gold, METAL)
	end
	f.add("UpperTorso", "ChestGem", Vector3.new(0.34, 0.34, 0.08) * s, CFrame.new(0, c.Y * 0.16, -c.Z / 2 - 0.05 * s) * CFrame.Angles(0, 0, math.pi / 4), gem, NEON)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.2 * s, 0))
end
HERO_EXTRAS.vision = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	f.add("Head", "MindGem", Vector3.new(0.24, 0.3, 0.08) * s, f.face(0, 0.5, 0.03) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(120, 240, 255), NEON)
	cape(f, Color3.fromRGB(150, 220, 255), 3.4)
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
	Figure.Face(f, "lens", { lens = Color3.fromRGB(120, 230, 255), rim = HC.steel, glow = true, width = 0.42, height = 0.3, slant = 0.2 })
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EarPiece", Vector3.new(0.12, 0.44, 0.44) * s, CFrame.new(side * h.X * 0.52, 0, 0), HC.steel, METAL)
		local hand = side < 0 and "LeftHand" or "RightHand"
		f.add(hand, "Blaster", Vector3.new(0.2, 0.72, 0.34) * s, CFrame.new(0, -0.36 * s, -0.08 * s), HC.steel, METAL)
		f.add(hand, "BlasterGlow", Vector3.new(0.12, 0.12, 0.12) * s, CFrame.new(0, -0.74 * s, -0.08 * s), Color3.fromRGB(160, 240, 255), NEON)
	end
	f.add("UpperTorso", "Coat", Vector3.new(f.sizes.chest.X * 1.06, f.sizes.chest.Y * 1.5, f.sizes.chest.Z * 1.08), CFrame.new(0, -f.sizes.chest.Y * 0.28, 0.02 * s), Color3.fromRGB(36, 126, 146), FABRIC)
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
		f.add("Head", "Crown", Vector3.new(0.1, 0.5, 0.08) * s, f.face(side * 0.2, 0.62, 0.03) * CFrame.Angles(0, 0, side * 0.45), Color3.fromRGB(220, 170, 70), METAL)
		local glow = f.add(side < 0 and "LeftHand" or "RightHand", "ChaosSpell", Vector3.new(0.62, 0.62, 0.62) * s, CFrame.new(0, -0.5 * s, -0.1 * s), Color3.fromRGB(240, 200, 90), NEON, "ball")
		glow.Transparency = 0.2
	end
	cape(f, Color3.fromRGB(120, 40, 160), 3.0)
	muzzle(f, "RightHand", Vector3.new(0, -0.5 * s, -0.1 * s))
end
HERO_EXTRAS.strange = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	for _, side in ipairs({ -1, 1 }) do f.add("Head", "Temple", Vector3.new(0.08, 0.3, 0.3) * s, CFrame.new(side * h.X * 0.5, h.Y * 0.1, 0), HC.white, FABRIC) end
	cape(f, Color3.fromRGB(30, 150, 140), 3.4, Color3.fromRGB(30, 150, 140))
	belt(f, HC.leather, HC.gold)
	f.disc("UpperTorso", "Amulet", 0.44 * s, 0.08 * s, CFrame.new(0, c.Y * 0.3, -c.Z / 2 - 0.05 * s), HC.gold, METAL)
	f.disc("UpperTorso", "AmuletEye", 0.18 * s, 0.05 * s, CFrame.new(0, c.Y * 0.3, -c.Z / 2 - 0.1 * s), Color3.fromRGB(255, 200, 90), NEON)
	-- A glowing sigil in front of the left hand.
	for i = 0, 7 do
		local angle = i * math.pi / 4
		f.add("LeftHand", "SpellGlyph", Vector3.new(0.5, 0.06, 0.05) * s, CFrame.new(math.sin(angle) * 0.62 * s, -0.4 * s + math.cos(angle) * 0.62 * s, -0.5 * s) * CFrame.Angles(0, 0, -angle), HC.gold, NEON)
	end
	muzzle(f, "LeftHand", Vector3.new(0, -0.4 * s, -0.6 * s))
end
HERO_EXTRAS.ghostrider = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local spirit, ember = Color3.fromRGB(110, 230, 255), Color3.fromRGB(200, 80, 30)
	-- Ember Rider: an ember-orange helmet with a glowing visor, blue spirit
	-- flames on top and an ember mark on the riding jacket.
	f.add("Head", "Visor", Vector3.new(h.X * 0.8, 0.22 * s, 0.08 * s), f.face(0, 0.1, 0.03), spirit, NEON)
	for i = -1, 1 do
		local flame = f.add("Head", "Flame", Vector3.new(0.3, 0.7 - math.abs(i) * 0.16, 0.3) * s, CFrame.new(i * h.X * 0.22, h.Y * 0.6, 0.05 * s), spirit:Lerp(HC.white, math.abs(i) * 0.2), NEON, "ball")
		flame.Transparency = 0.2
	end
	for _, side in ipairs({ -1, 1 }) do
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "ShoulderPad", f.sizes.upperArm * Vector3.new(1.2, 0.45, 1.2), CFrame.new(0, f.sizes.upperArm.Y * 0.3, 0), ember, METAL)
	end
	f.add("UpperTorso", "Jacket", c * Vector3.new(1.06, 1.02, 1.08), CFrame.new(), Color3.fromRGB(40, 36, 44), FABRIC)
	f.add("UpperTorso", "EmberMark", Vector3.new(0.4, 0.4, 0.06) * s, CFrame.new(0, c.Y * 0.16, -c.Z * 0.54 - 0.04 * s) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(255, 140, 50), NEON)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.captainmarvel = function(f)
	local s, c = f.scale, f.sizes.chest
	local sun = Color3.fromRGB(255, 160, 40)
	-- Solaria: a sun on the chest, a golden sash and fists of light.
	f.disc("UpperTorso", "SunDisc", 0.3 * s, 0.06 * s, CFrame.new(0, c.Y * 0.18, -c.Z / 2 - 0.05 * s), sun, NEON)
	for i = 0, 7 do
		local a = i * math.pi / 4
		f.add("UpperTorso", "SunRay", Vector3.new(0.08, 0.22, 0.05) * s, CFrame.new(math.sin(a) * 0.42 * s, c.Y * 0.18 + math.cos(a) * 0.42 * s, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, -a), sun, NEON)
	end
	f.add("UpperTorso", "Sash", Vector3.new(c.X * 1.03, 0.2 * s, c.Z * 1.04), CFrame.new(0, -c.Y * 0.38, 0), sun, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add(side < 0 and "LeftHand" or "RightHand", "PhotonFist", Vector3.new(0.7, 0.62, 0.7) * s, CFrame.new(0, -0.05 * s, 0), Color3.fromRGB(255, 220, 110), NEON, "ball").Transparency = 0.45
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.silversurfer = function(f)
	local s = f.scale
	local ring = Color3.fromRGB(255, 230, 140)
	-- Orbit: a ring of light circles above the shoulders with a small moon.
	local r = 1.5 * s
	for i = 0, 11 do
		local a0, a1 = i * math.pi / 6, (i + 1) * math.pi / 6
		f.rod("UpperTorso", "OrbitRing", Vector3.new(math.cos(a0) * r, 0.9 * s, math.sin(a0) * r), Vector3.new(math.cos(a1) * r, 0.9 * s, math.sin(a1) * r), 0.08 * s, ring, NEON)
	end
	f.add("UpperTorso", "Moon", Vector3.new(0.4, 0.4, 0.4) * s, CFrame.new(r, 0.9 * s, 0), ring, NEON, "ball")
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.wolverine = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local stripe, orange = Color3.fromRGB(30, 24, 22), Color3.fromRGB(235, 130, 40)
	-- Fang: tiger stripes, ear tufts and two bone-white claws per hand.
	for i = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			f.add("UpperTorso", "TigerStripe", Vector3.new(0.5 * s, 0.1 * s, 0.06 * s), CFrame.new(side * c.X * 0.32, c.Y * (0.28 - i * 0.24), -c.Z / 2 - 0.03 * s) * CFrame.Angles(0, 0, side * 0.35), stripe, FABRIC)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EarTuft", Vector3.new(0.12, 0.42, 0.3) * s, CFrame.new(side * h.X * 0.42, h.Y * 0.5, 0) * CFrame.Angles(0, 0, -side * 0.3), orange, FABRIC, "wedge")
		for i = 0, 1 do f.add(side < 0 and "LeftHand" or "RightHand", "AdamantiumClaw", Vector3.new(0.07, 0.62, 0.1) * s, CFrame.new((i - 0.5) * 0.2 * s, -f.sizes.hand.Y / 2 - 0.32 * s, -0.12 * s), Color3.fromRGB(240, 232, 214), METAL) end
	end
	belt(f, stripe, HC.gold)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.62 * s, -0.12 * s))
end
HERO_EXTRAS.cyclops = function(f)
	local s, h = f.scale, f.parts.Head.Size
	f.add("Head", "Chin", Vector3.new(h.X * 0.6, h.Y * 0.36, 0.1 * s), f.face(0, -0.52, -0.03), HC.skin, FABRIC)
	f.add("Head", "Visor", Vector3.new(h.X * 0.9, 0.24 * s, 0.14 * s), f.face(0, 0.14, 0.04), Color3.fromRGB(255, 190, 60), NEON)
	belt(f, Color3.fromRGB(214, 60, 52), Color3.fromRGB(232, 236, 242))
	muzzle(f, "Head", Vector3.new(0, h.Y * 0.07, -h.Z / 2 - 0.2 * s))
end
HERO_EXTRAS.storm = function(f)
	cape(f, Color3.fromRGB(30, 120, 140), 3.4)
	f.add("Head", "Tiara", Vector3.new(0.5, 0.14, 0.06) * f.scale, f.face(0, 0.46, 0.03), HC.gold, METAL)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * f.scale, 0))
end
HERO_EXTRAS.jean = function(f)
	local s, c = f.scale, f.sizes.chest
	f.add("UpperTorso", "PhoenixEmblem", Vector3.new(0.5, 0.36, 0.06) * s, CFrame.new(0, c.Y * 0.18, -c.Z / 2 - 0.03 * s), Color3.fromRGB(255, 150, 210), METAL, "wedge")
	belt(f, Color3.fromRGB(255, 150, 210))
	for _, side in ipairs({ -1, 1 }) do
		f.add(side < 0 and "LeftHand" or "RightHand", "Flame", Vector3.new(0.5, 0.7, 0.5) * s, CFrame.new(0, -0.45 * s, 0), Color3.fromRGB(200, 140, 255), NEON, "ball").Transparency = 0.3
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
	f.add("Head", "Cowl", Vector3.new(f.parts.Head.Size.X * 1.08, f.parts.Head.Size.Y * 0.56, f.parts.Head.Size.Z * 1.08), CFrame.new(0, f.parts.Head.Size.Y * 0.32, 0.03 * s), Color3.fromRGB(200, 40, 60), FABRIC, "ball")
	f.add("UpperTorso", "TrenchCoat", Vector3.new(c.X * 1.08, c.Y * 1.9, c.Z * 1.12), CFrame.new(0, -c.Y * 0.44, 0.02 * s), Color3.fromRGB(36, 36, 46), FABRIC)
	f.add("RightHand", "ChargedCard", Vector3.new(0.36, 0.5, 0.04) * s, CFrame.new(0, -0.4 * s, -0.15 * s), Color3.fromRGB(255, 210, 80), NEON)
	muzzle(f, "RightHand", Vector3.new(0, -0.5 * s, -0.15 * s))
end
HERO_EXTRAS.nightcrawler = function(f)
	local s = f.scale
	f.add("LowerTorso", "Tail", Vector3.new(0.14, 0.14, 2.2) * s, CFrame.new(0, -0.1 * s, f.sizes.pelvis.Z / 2 + 1 * s) * CFrame.Angles(-0.8, 0, 0), Color3.fromRGB(255, 214, 90), FABRIC)
	f.add("LowerTorso", "TailTip", Vector3.new(0.3, 0.3, 0.1) * s, CFrame.new(0, 0.7 * s, f.sizes.pelvis.Z / 2 + 1.75 * s) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(255, 214, 90), FABRIC)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.beast = function(f)
	local s = f.scale
	for _, side in ipairs({ -1, 1 }) do f.add(side < 0 and "LeftHand" or "RightHand", "FurryFist", f.sizes.hand * 1.12, CFrame.new(), Color3.fromRGB(232, 180, 90), FABRIC, "ball") end
	f.add("Head", "Fang", Vector3.new(0.4, 0.1, 0.05) * s, f.face(0, -0.52, 0.04), HC.white, FABRIC)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.psylocke = function(f)
	local s = f.scale
	f.add("Head", "MaskBand", Vector3.new(f.parts.Head.Size.X * 0.9, 0.2 * s, 0.06 * s), f.face(0, 0.14, 0.03), Color3.fromRGB(40, 40, 48), FABRIC)
	f.add("RightHand", "Blade", Vector3.new(0.12, 1.4, 0.3) * s, CFrame.new(0, -0.8 * s, -0.1 * s), Color3.fromRGB(255, 120, 90), NEON)
	f.add("UpperTorso", "Sash", Vector3.new(f.sizes.chest.X * 1.03, 0.22 * s, f.sizes.chest.Z * 1.04), CFrame.new(0, -f.sizes.chest.Y * 0.38, 0), Color3.fromRGB(40, 40, 48), FABRIC)
	muzzle(f, "RightHand", Vector3.new(0, -1.4 * s, -0.1 * s))
end
HERO_EXTRAS.deadpool = function(f)
	local s, c = f.scale, f.sizes.chest
	-- Confetti: a grinning party mask, confetti dots on the chest and two
	-- foam party bats.
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Eye", Vector3.new(0.22, 0.22, 0.05) * s, f.face(side * 0.26, 0.14, 0.03), HC.white, FABRIC, "ball")
		f.add("Head", "Pupil", Vector3.new(0.09, 0.09, 0.05) * s, f.face(side * 0.26, 0.14, 0.06), HC.ink, FABRIC, "ball")
		f.add(side < 0 and "LeftHand" or "RightHand", "PartyBat", Vector3.new(0.24, 1.1, 0.24) * s, CFrame.new(0, -0.55 * s, -0.08 * s), side < 0 and Color3.fromRGB(255, 220, 60) or Color3.fromRGB(110, 200, 255), FABRIC)
	end
	f.add("Head", "Grin", Vector3.new(0.5, 0.08, 0.05) * s, f.face(0, -0.36, 0.04), HC.ink, FABRIC)
	local dots = { Color3.fromRGB(255, 220, 60), Color3.fromRGB(110, 200, 255), Color3.fromRGB(120, 230, 120), HC.white }
	for i = 1, 6 do
		f.disc("UpperTorso", "Confetti", 0.1 * s, 0.04 * s, CFrame.new(((i * 37) % 9 - 4) * 0.1 * s, ((i * 53) % 7 - 3) * 0.12 * s, -c.Z / 2 - 0.03 * s), dots[i % #dots + 1], FABRIC)
	end
	belt(f, HC.ink, Color3.fromRGB(255, 220, 60))
	muzzle(f, "RightHand", Vector3.new(0, -1.1 * s, -0.08 * s))
end
HERO_EXTRAS.moonknight = function(f)
	local s = f.scale
	Figure.Face(f, "lens", { width = 0.3, height = 0.3, slant = 0.1, lens = Color3.fromRGB(255, 200, 80), rim = HC.ink })
	f.add("Head", "Hood", f.parts.Head.Size * Vector3.new(1.12, 1.1, 1.0), CFrame.new(0, 0.04 * s, f.parts.Head.Size.Z * 0.24), HC.white, FABRIC, "ball")
	cape(f, Color3.fromRGB(28, 30, 42), 3.6)
	f.add("UpperTorso", "Crescent", Vector3.new(0.5, 0.5, 0.06) * s, CFrame.new(0, f.sizes.chest.Y * 0.16, -f.sizes.chest.Z / 2 - 0.03 * s), Color3.fromRGB(255, 200, 80), METAL, "ball")
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.nova = function(f)
	local s, h = f.scale, f.parts.Head.Size
	f.add("Head", "Helmet", h * Vector3.new(1.06, 0.62, 1.06), CFrame.new(0, h.Y * 0.28, 0), Color3.fromRGB(80, 210, 240), METAL, "ball")
	f.add("Head", "Crest", Vector3.new(0.14, 0.5, 0.9) * s, CFrame.new(0, h.Y * 0.62, 0), Color3.fromRGB(80, 210, 240), METAL, "wedge")
	f.add("Head", "Visor", Vector3.new(h.X * 0.84, 0.2 * s, 0.1 * s), f.face(0, 0.12, 0.03), Color3.fromRGB(120, 220, 255), NEON)
	star(f, "UpperTorso", CFrame.new(0, f.sizes.chest.Y * 0.16, -f.sizes.chest.Z / 2 - 0.04 * s), 0.36 * s, Color3.fromRGB(80, 210, 240))
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
			-- Gold trim reads as "upgraded" on every costume, whatever its colours.
			local pad = gear(name .. "UpperArm", "GearShoulder", upper.Size * Vector3.new(1.34, 0.42, 1.34), CFrame.new(0, upper.Size.Y * 0.36, 0), Color3.fromRGB(240, 190, 70))
			if pad then pad.Reflectance = 0.15 end
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
-- Up to 180 of them walk at once, so the common face is four pieces; a boss
-- (one on the road) adds dark sockets and a tooth.
local function infectedFace(f, eye, detailed)
	local k = f.parts.Head.Size.X / BODY.head.X
	for _, side in ipairs({ -1, 1 }) do
		local size = side < 0 and Vector3.new(0.26, 0.28, 0.06) or Vector3.new(0.2, 0.22, 0.06)
		if detailed then f.add("Head", "Socket", (size + Vector3.new(0.1, 0.1, 0)) * k, f.face(side * 0.28, 0.12, -0.01), EC.ink, FABRIC, "ball") end
		f.add("Head", "Eye", size * k, f.face(side * 0.28, 0.12, 0.02), eye or EC.eye, NEON, "ball")
	end
	f.add("Head", "Brow", Vector3.new(0.9, 0.14, 0.12) * k, f.face(0, 0.42, -0.02), f.parts.Head.Color:Lerp(EC.ink, 0.35), FABRIC)
	f.add("Head", "Jaw", Vector3.new(0.46, 0.2, 0.06) * k, f.face(0.04, -0.42, 0.0), EC.ink, FABRIC, "ball")
	if detailed then f.add("Head", "Tooth", Vector3.new(0.1, 0.08, 0.05) * k, f.face(-0.08, -0.36, 0.02), EC.bone, FABRIC) end
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
	infectedFace(f, Color3.fromRGB(255, 140, 50), true)
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

-- A hero's figure wherever it appears: the tower, the portrait, the
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

-- A hero standing still as scenery (statues, display cases). Every part is
-- anchored before the body is placed: a released body (heroFigure) follows
-- its root only on the next physics step, so anchoring it afterwards would
-- pin the limbs wherever they were built.
local function staticFigure(parent, heroId, hero, origin, scale)
	local emphasis = (scale or FIGURE_SCALE[heroId] or 1) / (FIGURE_SCALE[heroId] or 1)
	local template = artTemplate("Heroes", heroId)
	local model
	if template then
		model = template:Clone()
		model.Name = "HeroFigure"
		for _, item in ipairs(model:GetDescendants()) do if item:IsA("BasePart") then item.Anchored = true end end
		if emphasis ~= 1 and model.ScaleTo then pcall(function() model:ScaleTo(model:GetScale() * emphasis) end) end
		model.Parent = parent
	else
		model = Figure.Hero(parent, heroId, hero, emphasis).model
	end
	model:SetAttribute("HeroArt", true)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch = true, false, false, false end
	end
	model:PivotTo(origin)
	return model
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
		sun=2.6,clockTime=15.5,exposure=0.15,ambient={128,115,99},outdoor={174,153,120},
		atmosphereColor={242,215,174},atmosphereDensity=0.2,glare=0.12,
		tint={255,239,205},contrast=0.04,saturation=0.06,brightness=0.02,
		bloom=0.25,fogColor={178,157,137},fogEnd=720,
	},
	manhattan = {
		sun = 2.3, clockTime = 15.2, exposure = 0.6, ambient = { 128, 124, 128 }, outdoor = { 150, 148, 150 },
		atmosphereColor = { 205, 214, 232 }, atmosphereDensity = 0.22, glare = 0.08,
		tint = { 255, 248, 238 }, contrast = 0.04, saturation = 0.08, brightness = 0.02,
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
		sun = 1.8, clockTime = 18.5, exposure = 0.05, ambient = { 100, 102, 137 }, outdoor = { 117, 129, 167 },
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
	lighting.Ambient = rgb(preset.ambient):Lerp(Color3.fromRGB(176, 184, 200), 0.84)
	lighting.OutdoorAmbient = rgb(preset.outdoor):Lerp(Color3.fromRGB(168, 178, 196), 0.8)
	lighting.ExposureCompensation = preset.exposure or 0.35
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

--==============================================================================
-- The Heroes' HQ: the lobby world
--==============================================================================
-- Art direction (docs/ART_DIRECTION.md, "Lobby"): a sunny island base at sea
-- level. Light stone and dark steel, cyan hero-tech light, warm gold lamps;
-- every area has one signature colour, one giant illustrated sign and one
-- landmark. Terrain lays the sea, beaches, grass and rock; parts build the
-- crisp world on top. The kit below is the only vocabulary the lobby uses,
-- so every fence, lamp and sign across the island belongs to one family.
local HQ = {
	stone = Color3.fromRGB(206, 213, 224), stoneDark = Color3.fromRGB(150, 162, 180), stoneWarm = Color3.fromRGB(226, 216, 196),
	steel = Color3.fromRGB(70, 84, 110), navy = Color3.fromRGB(28, 38, 64), trim = Color3.fromRGB(240, 244, 250),
	cyan = Color3.fromRGB(64, 212, 255), glow = Color3.fromRGB(150, 240, 255), gold = Color3.fromRGB(255, 196, 64),
	lamp = Color3.fromRGB(255, 212, 128), leaf = Color3.fromRGB(70, 170, 80), leafLight = Color3.fromRGB(128, 208, 92),
	trunk = Color3.fromRGB(128, 88, 58), white = Color3.fromRGB(255, 255, 255), ink = Color3.fromRGB(16, 22, 40),
}
local HUB = Vector3.new(0, 0, 480)
-- Heights: the sea, the island's grass, the paved ground, the raised plaza.
local SEA_Y, GRASS_Y, GROUND_Y, PLAZA_Y = -3, -0.6, 0.3, 1.5
World.HQ = { hub = HUB, groundY = GROUND_Y, plazaY = PLAZA_Y }

local Kit = {}
function Kit.block(parent, name, size, cf, color, material, solid)
	local p = artPart(parent, name, size, cf, color, material)
	if solid then p.CanCollide, p.CanQuery = true, true end
	return p
end
function Kit.round(p)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType, mesh.Parent = Enum.MeshType.Sphere, p
	return p
end
function Kit.blob(parent, name, size, cf, color, material)
	return Kit.round(Kit.block(parent, name, size, cf, color, material))
end
-- A flat round slab centred on `center` (a cylinder's axis runs along X).
function Kit.disc(parent, name, center, diameter, thickness, color, material, solid)
	local p = Kit.block(parent, name, Vector3.new(thickness, diameter, diameter), CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), color, material, solid)
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- An upright cylinder standing on `base`.
function Kit.column(parent, name, base, height, diameter, color, material, solid)
	local p = Kit.block(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(base + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.pi / 2), color, material, solid)
	p.Shape = Enum.PartType.Cylinder
	return p
end
-- A box from a to b.
function Kit.beam(parent, name, a, b, width, height, color, material, solid)
	return Kit.block(parent, name, Vector3.new(width, height, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material, solid)
end
-- A right triangle: right angle at `corner`, perpendicular legs `span` and
-- `chord`, extruded by `thickness`. Wings, fins, roofs, crystal facets.
function Kit.triangle(parent, name, corner, span, chord, thickness, color, material)
	local y, z = span.Unit, -chord.Unit
	local made = Instance.new("WedgePart")
	made.Name, made.Size = name, Vector3.new(thickness, span.Magnitude, chord.Magnitude)
	made.CFrame = CFrame.fromMatrix(corner + span / 2 + chord / 2, y:Cross(z), y, z)
	made.Color, made.Material, made.Anchored = color, material or Enum.Material.SmoothPlastic, true
	made.CanCollide, made.CanQuery, made.CanTouch, made.CastShadow = false, false, false, false
	made.TopSurface, made.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	made.Parent = parent
	return made
end
function Kit.light(p, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color, light.Range, light.Brightness, light.Shadows, light.Parent = color, range or 14, brightness or 0.8, false, p
	return light
end
-- Client-side motion, by attribute (init.client animateLobby): spin in
-- radians per second about a vertical axis through `center` (the part's own
-- centre by default), bob in studs.
function Kit.animate(p, spin, bob, center)
	p:SetAttribute("Spin", spin or 0)
	p:SetAttribute("Bob", bob or 0)
	if center then p:SetAttribute("SpinCenter", center) end
	return p
end
-- Points on a circle in the ground plane, from angle a0 to a1 (radians).
function Kit.arcPoints(center, radius, a0, a1, steps, y)
	local points = {}
	for i = 0, steps do
		local a = a0 + (a1 - a0) * i / steps
		table.insert(points, Vector3.new(center.X + math.cos(a) * radius, y, center.Z + math.sin(a) * radius))
	end
	return points
end

-- The HQ's signature fence: a steel curb, a lit glass panel and a dark rail,
-- with a post and a glowing cap at every corner. Points are on the walking
-- surface.
function Kit.fence(parent, points, height, glow, closed)
	height = height or 3.4
	glow = glow or HQ.glow
	local count = #points
	for i = 1, closed and count or count - 1 do
		local a, b = points[i], points[i % count + 1]
		local length = (b - a).Magnitude
		if length > 0.5 then
			local look = CFrame.lookAt((a + b) / 2, b)
			Kit.block(parent, "FenceCurb", Vector3.new(1.3, 1, length), look * CFrame.new(0, 0.5, 0), HQ.steel, Enum.Material.Metal, true)
			local glass = Kit.block(parent, "FenceGlass", Vector3.new(0.35, height - 1.6, math.max(0.4, length - 1.2)), look * CFrame.new(0, 1 + (height - 1.6) / 2, 0), glow, Enum.Material.Neon)
			glass.Transparency = 0.3
			Kit.block(parent, "FenceRail", Vector3.new(0.9, 0.5, length + 0.4), look * CFrame.new(0, height - 0.15, 0), HQ.navy, Enum.Material.Metal, true)
		end
	end
	for i = 1, count do
		local base = points[i]
		Kit.block(parent, "FencePost", Vector3.new(1.5, height + 0.5, 1.5), CFrame.new(base + Vector3.new(0, (height + 0.5) / 2, 0)), HQ.navy, Enum.Material.Metal, true)
		Kit.block(parent, "FenceCap", Vector3.new(1.1, 0.35, 1.1), CFrame.new(base + Vector3.new(0, height + 0.65, 0)), glow, Enum.Material.Neon)
	end
end

-- A street lamp: steel foot, slim pole, warm lantern under a cap.
function Kit.lamp(parent, base, height)
	height = height or 9
	Kit.disc(parent, "LampFoot", base + Vector3.new(0, 0.3, 0), 2.2, 0.6, HQ.steel, Enum.Material.Metal)
	Kit.column(parent, "LampPole", base, height, 0.6, HQ.navy, Enum.Material.Metal)
	local glow = Kit.block(parent, "LampGlow", Vector3.new(1.5, 1.6, 1.5), CFrame.new(base + Vector3.new(0, height + 0.8, 0)), HQ.lamp, Enum.Material.Neon)
	Kit.block(parent, "LampCap", Vector3.new(2.3, 0.45, 2.3), CFrame.new(base + Vector3.new(0, height + 1.8, 0)), HQ.navy, Enum.Material.Metal)
	Kit.light(glow, HQ.lamp, 18, 0.9)
	return glow
end

-- Round-crowned trees in two greens; a whole tree is one Model.
function Kit.tree(parent, base, scale, tint)
	scale, tint = scale or 1, tint or HQ.leaf
	local tree = Instance.new("Model")
	tree.Name, tree.Parent = "HQTree", parent
	Kit.column(tree, "TreeTrunk", base - Vector3.new(0, 0.5, 0), 7 * scale, 1.4 * scale, HQ.trunk, Enum.Material.Wood)
	local light = tint:Lerp(HQ.leafLight, 0.5)
	for i, c in ipairs({ { 0, 8.6, 0, 9.5, tint }, { -2.6, 7.2, 1.3, 6.8, light }, { 2.4, 7.6, -1.2, 7, tint:Lerp(HQ.leafLight, 0.25) } }) do
		local crown = Kit.blob(tree, "TreeCrown", Vector3.new(c[4], c[4] * 0.86, c[4]) * scale, CFrame.new(base + Vector3.new(c[1], c[2], c[3]) * scale), c[5])
		if i == 1 then crown.CastShadow = true end
	end
	return tree
end
-- A beach palm: a leaning trunk in three pieces, six fronds and coconuts.
function Kit.palm(parent, base, scale, lean)
	scale, lean = scale or 1, lean or 0
	local palm = Instance.new("Model")
	palm.Name, palm.Parent = "HQPalm", parent
	local dir = Vector3.new(math.cos(lean), 0, math.sin(lean))
	local points = { base - Vector3.new(0, 0.5, 0) }
	for i = 1, 3 do table.insert(points, base + Vector3.new(0, i * 4 * scale, 0) + dir * (i * i * 0.45 * scale)) end
	for i = 1, 3 do Kit.beam(palm, "PalmTrunk", points[i], points[i + 1], (1.3 - i * 0.15) * scale, (1.3 - i * 0.15) * scale, HQ.trunk:Lerp(HQ.stoneWarm, 0.25), Enum.Material.Wood) end
	local top = points[4]
	for i = 0, 5 do
		local a = i * math.pi / 3 + lean
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		Kit.blob(palm, "PalmFrond", Vector3.new(2 * scale, 0.35 * scale, 7.5 * scale), CFrame.lookAt(top + out * 3.2 * scale - Vector3.new(0, 0.9 * scale, 0), top + out * 7 * scale - Vector3.new(0, 2.6 * scale, 0)),
			i % 2 == 0 and HQ.leaf or HQ.leafLight)
	end
	Kit.blob(palm, "Coconut", Vector3.new(1.3, 1.3, 1.3) * scale, CFrame.new(top - Vector3.new(0, 0.9 * scale, 0)), Color3.fromRGB(110, 76, 44))
	return palm
end
function Kit.bush(parent, pos, size, tint)
	size, tint = size or 3, tint or HQ.leaf
	Kit.blob(parent, "Bush", Vector3.new(size, size * 0.8, size), CFrame.new(pos + Vector3.new(0, size * 0.25, 0)), tint)
	Kit.blob(parent, "Bush", Vector3.new(size * 0.7, size * 0.6, size * 0.7), CFrame.new(pos + Vector3.new(size * 0.45, size * 0.2, size * 0.2)), tint:Lerp(HQ.leafLight, 0.4))
end
-- Flower beds: a few blossoms on a low green mound.
function Kit.flowers(parent, pos, colors)
	Kit.blob(parent, "FlowerBed", Vector3.new(4.2, 1, 3.2), CFrame.new(pos + Vector3.new(0, 0.3, 0)), HQ.leaf)
	for i = 1, 5 do
		local a = i * 1.26
		Kit.blob(parent, "Blossom", Vector3.new(0.8, 0.5, 0.8), CFrame.new(pos + Vector3.new(math.cos(a) * 1.3, 0.85, math.sin(a) * 1.0)), colors[i % #colors + 1])
	end
end
-- A stone planter with a tree or a bush.
function Kit.planter(parent, center, size, withTree)
	Kit.block(parent, "PlanterWall", Vector3.new(size, 1.6, size), CFrame.new(center + Vector3.new(0, 0.8, 0)), HQ.stoneDark, Enum.Material.Slate, true)
	Kit.block(parent, "PlanterTrim", Vector3.new(size + 0.6, 0.35, size + 0.6), CFrame.new(center + Vector3.new(0, 1.7, 0)), HQ.trim, Enum.Material.SmoothPlastic, true)
	Kit.block(parent, "PlanterSoil", Vector3.new(size - 0.8, 0.3, size - 0.8), CFrame.new(center + Vector3.new(0, 1.62, 0)), Color3.fromRGB(88, 64, 44), Enum.Material.Ground)
	if withTree then
		Kit.tree(parent, center + Vector3.new(0, 1.7, 0), size / 7):SetAttribute("Planted", true)
	else
		Kit.bush(parent, center + Vector3.new(0, 1.7, 0), size * 0.7)
	end
end
-- Stairs down from the edge of a platform at `topY` to the ground at
-- `bottomY`, walking along `outward` (a unit vector). Each tread has a
-- glowing nose, like the big games' plazas.
function Kit.stairs(parent, edge, outward, width, topY, bottomY, steps)
	local rise, run = (topY - bottomY) / (steps + 1), 2.2
	local flat = Vector3.new(edge.X, 0, edge.Z)
	for i = 1, steps do
		local top = topY - rise * i
		local foot = bottomY - 0.6
		local mid = flat + outward * (run * (i - 0.5))
		local center = mid + Vector3.new(0, (top + foot) / 2, 0)
		Kit.block(parent, "Step", Vector3.new(width, top - foot, run), CFrame.lookAt(center, center + outward), HQ.stone, Enum.Material.Pavement, true)
		local nose = mid + outward * (run / 2 - 0.25) + Vector3.new(0, top + 0.04, 0)
		Kit.block(parent, "StepNose", Vector3.new(width - 0.8, 0.08, 0.3), CFrame.lookAt(nose, nose + outward), HQ.cyan, Enum.Material.Neon)
	end
end
-- The yellow corner marks the big games paint around every pad.
function Kit.cornerMarks(parent, center, halfX, halfZ, color, y, yaw)
	local frame = CFrame.new(center.X, y, center.Z) * CFrame.Angles(0, yaw or 0, 0)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			Kit.block(parent, "FloorMark", Vector3.new(3.4, 0.08, 0.7), frame * CFrame.new(sx * (halfX - 1.35), 0, sz * halfZ), color, Enum.Material.Neon)
			Kit.block(parent, "FloorMark", Vector3.new(0.7, 0.08, 2.7), frame * CFrame.new(sx * halfX, 0, sz * (halfZ - 1.7)), color, Enum.Material.Neon)
		end
	end
end
-- A treasure chest, front toward the frame's +Z: a painted body with gold
-- bands and a lock, a rounded lid hinged at the back (opened by `open`
-- radians) and the treasure glowing inside with coins spilling over the rim.
function Kit.treasureChest(parent, frame, color, glow, open, scale)
	local made = {}
	scale = scale or 1
	-- Author at size 1; offsets and sizes grow together.
	local function place(cf) return cf - cf.Position + frame * ((frame:Inverse() * cf.Position) * scale) end
	local function piece(name, size, cf, tint, material, shape)
		local p = Kit.block(parent, name, size * scale, place(cf), tint, material)
		if shape then p.Shape = shape end
		table.insert(made, p)
		return p
	end
	local dark = color:Lerp(HQ.ink, 0.3)
	local gold, cyl = HQ.gold, Enum.PartType.Cylinder
	piece("ChestBody", Vector3.new(4.4, 2.3, 3), frame * CFrame.new(0, 1.35, 0), dark)
	piece("ChestFront", Vector3.new(4.1, 2, 0.12), frame * CFrame.new(0, 1.35, 1.52), color)
	piece("ChestFoot", Vector3.new(4.8, 0.4, 3.4), frame * CFrame.new(0, 0.2, 0), gold, Enum.Material.Metal)
	for _, x in ipairs({ -1.35, 1.35 }) do piece("ChestBand", Vector3.new(0.5, 2.35, 3.12), frame * CFrame.new(x, 1.35, 0), gold, Enum.Material.Metal) end
	piece("ChestLock", Vector3.new(1.1, 1.2, 0.3), frame * CFrame.new(0, 1.85, 1.62), gold, Enum.Material.Metal)
	piece("ChestKeyhole", Vector3.new(0.26, 0.5, 0.1), frame * CFrame.new(0, 1.75, 1.8), HQ.ink)
	piece("ChestTreasure", Vector3.new(3.9, 0.3, 2.6), frame * CFrame.new(0, 2.45, 0), glow, Enum.Material.Neon)
	for i, spot in ipairs({ { -1.2, 0.8 }, { 0.4, 1.2 }, { 1.4, 0.6 }, { -0.3, 1.45 } }) do
		piece("ChestCoin", Vector3.new(0.18, 0.9, 0.9), frame * CFrame.new(spot[1], 2.62 + i * 0.03, spot[2]) * CFrame.Angles(0.4 * i, 0, math.pi / 2 + 0.3 * i), gold, Enum.Material.Metal, cyl)
	end
	local hinge = frame * CFrame.new(0, 2.5, -1.5)
	local swing = hinge * CFrame.Angles(open or 0, 0, 0) * hinge:Inverse()
	piece("ChestRim", Vector3.new(4.6, 0.3, 3.2), swing * frame * CFrame.new(0, 2.5, 0), gold, Enum.Material.Metal)
	piece("ChestLid", Vector3.new(4.4, 3, 3), swing * frame * CFrame.new(0, 2.5, 0), color, nil, cyl)
	for _, x in ipairs({ -1.35, 1.35 }) do piece("ChestLidBand", Vector3.new(0.5, 3.12, 3.12), swing * frame * CFrame.new(x, 2.5, 0), gold, Enum.Material.Metal, cyl) end
	for _, x in ipairs({ -2.05, 2.05 }) do piece("ChestStud", Vector3.new(0.5, 0.5, 0.5), swing * frame * CFrame.new(x, 2.5, 1.55), gold, Enum.Material.Metal, Enum.PartType.Ball) end
	return made
end

-- A flag on a pole; the cloth waves on the client, hinged at the pole.
function Kit.flag(parent, base, height, color, width)
	width = width or 4
	Kit.column(parent, "FlagPole", base, height, 0.4, HQ.trim, Enum.Material.Metal)
	Kit.blob(parent, "FlagTop", Vector3.new(0.9, 0.9, 0.9), CFrame.new(base + Vector3.new(0, height + 0.3, 0)), HQ.gold, Enum.Material.Metal)
	local cloth = Kit.block(parent, "FlagCloth", Vector3.new(width, width * 0.62, 0.15), CFrame.new(base + Vector3.new(width / 2 + 0.2, height - width * 0.35, 0)), color, Enum.Material.Fabric)
	cloth:SetAttribute("Sway", 0.18)
	return cloth
end
-- A flat five-point star in the plane of `right`/`up`, facing right × up.
function Kit.star(parent, name, center, right, up, radius, color, material, thickness)
	local inner = radius * 0.4
	local half, height = inner * math.sin(math.pi / 5), radius - inner * math.cos(math.pi / 5)
	for k = 0, 4 do
		local a = k * 2 * math.pi / 5
		local u = right * math.sin(a) + up * math.cos(a)
		local t = right * math.cos(a) - up * math.sin(a)
		local base = center + u * (inner * math.cos(math.pi / 5))
		for _, s in ipairs({ -1, 1 }) do Kit.triangle(parent, name, base, u * height, t * (s * half), thickness, color, material) end
	end
	local core = Kit.block(parent, name, Vector3.new(thickness, inner * 2, inner * 2), CFrame.fromMatrix(center, right:Cross(up), up), color, material)
	core.Shape = Enum.PartType.Cylinder
	return core
end

--==============================================================================
-- Signs: big illustrated billboards and floating titles
--==============================================================================
-- Every sign is drawn with GUI shapes, not uploaded images: a sky gradient, a
-- sunburst, a small illustration and a title in fat outlined letters.
local SignArt = {}
local function frame2d(parent, pos, size, color, radius, rotation, transparency)
	local f = Instance.new("Frame")
	f.BorderSizePixel, f.Position, f.Size, f.BackgroundColor3 = 0, pos, size, color
	f.Rotation, f.BackgroundTransparency, f.AnchorPoint = rotation or 0, transparency or 0, Vector2.new(0.5, 0.5)
	if radius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius, corner.Parent = radius, f
	end
	f.Parent = parent
	return f
end
local function circle(parent, x, y, w, h, color, transparency)
	return frame2d(parent, UDim2.fromScale(x, y), UDim2.fromScale(w, h), color, UDim.new(0.5, 0), 0, transparency)
end
local function box(parent, x, y, w, h, color, rotation, radius, transparency)
	return frame2d(parent, UDim2.fromScale(x, y), UDim2.fromScale(w, h), color, radius and UDim.new(radius, 0) or nil, rotation, transparency)
end
local function stroke(item, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color, s.Thickness, s.Parent = color, thickness, item
	return s
end
local function gradient(item, top, bottom, rotation)
	local g = Instance.new("UIGradient")
	g.Color, g.Rotation, g.Parent = ColorSequence.new(top, bottom), rotation or 90, item
	return g
end
-- A four-point sparkle.
function SignArt.sparkle(host, x, y, size, color)
	box(host, x, y, size * 0.22, size, color, 0, 0.5)
	box(host, x, y, size * 0.22, size, color, 90, 0.5)
end
function SignArt.skyline(host, tint)
	local heights = { 0.42, 0.62, 0.5, 0.78, 0.56, 0.7, 0.46 }
	for i, h in ipairs(heights) do
		local x = 0.08 + (i - 1) * 0.14
		local building = box(host, x, 1 - h / 2, 0.12, h, HQ.navy:Lerp(tint, (i % 2) * 0.15))
		for row = 1, math.floor(h * 8) do
			for col = -1, 1 do
				if (row + col + i) % 3 ~= 0 then box(building, 0.5 + col * 0.28, row / (h * 9) + 0.02, 0.16, 0.035 / h, HQ.gold) end
			end
		end
	end
	box(host, 0.45, 0.97, 1, 0.06, tint)
end
function SignArt.trophy(host, tint)
	local cup = box(host, 0.5, 0.36, 0.42, 0.42, HQ.gold, 0, 0.35)
	stroke(cup, HQ.ink, 4)
	for _, side in ipairs({ -1, 1 }) do
		local handle = circle(host, 0.5 + side * 0.26, 0.34, 0.16, 0.2, HQ.gold, 1)
		stroke(handle, HQ.gold, 10)
	end
	box(host, 0.5, 0.62, 0.1, 0.16, HQ.gold)
	box(host, 0.5, 0.74, 0.34, 0.1, tint, 0, 0.3)
	SignArt.sparkle(cup, 0.5, 0.42, 0.34, HQ.white)
end
function SignArt.chest(host, tint)
	local body = box(host, 0.5, 0.6, 0.66, 0.38, Color3.fromRGB(122, 74, 40), 0, 0.12)
	stroke(body, HQ.ink, 4)
	local lid = box(host, 0.5, 0.36, 0.66, 0.2, Color3.fromRGB(150, 94, 52), -6, 0.3)
	stroke(lid, HQ.ink, 4)
	box(host, 0.5, 0.6, 0.66, 0.07, HQ.gold)
	box(host, 0.5, 0.52, 0.12, 0.16, HQ.gold, 0, 0.2)
	for i = 1, 5 do SignArt.sparkle(host, 0.18 + i * 0.13, 0.16 + (i % 2) * 0.08, 0.1, i % 2 == 0 and tint or HQ.white) end
end
function SignArt.mountains(host, tint)
	circle(host, 0.72, 0.3, 0.2, 0.3, HQ.gold)
	for i, spec in ipairs({ { 0.3, 0.72, 0.62 }, { 0.62, 0.68, 0.78 }, { 0.9, 0.78, 0.5 } }) do
		local peak = box(host, spec[1], spec[2], spec[3] * 0.72, spec[3] * 0.72, tint:Lerp(HQ.navy, 0.35 + i * 0.1), 45)
		box(peak, 0.2, 0.2, 0.34, 0.34, HQ.white)
	end
	box(host, 0.5, 1, 1, 0.16, tint:Lerp(HQ.navy, 0.6))
end
function SignArt.castle(host, tint)
	local wall = box(host, 0.5, 0.72, 0.8, 0.46, Color3.fromRGB(84, 92, 104))
	stroke(wall, HQ.ink, 3)
	for i = 0, 6 do box(host, 0.14 + i * 0.12, 0.47, 0.07, 0.07, Color3.fromRGB(84, 92, 104)) end
	for _, x in ipairs({ 0.18, 0.82 }) do
		box(host, x, 0.56, 0.16, 0.7, Color3.fromRGB(70, 78, 90))
		box(host, x, 0.18, 0.2, 0.14, tint, 45)
	end
	box(host, 0.5, 0.8, 0.16, 0.3, HQ.ink, 0, 0.5)
	for _, x in ipairs({ 0.34, 0.66 }) do box(host, x, 0.66, 0.08, 0.22, tint) end
end
function SignArt.target(host, tint)
	for i, color in ipairs({ HQ.white, Color3.fromRGB(230, 60, 70), HQ.white, Color3.fromRGB(230, 60, 70) }) do
		local size = 0.8 - (i - 1) * 0.18
		circle(host, 0.5, 0.5, size * 0.62, size, color)
	end
	box(host, 0.62, 0.38, 0.5, 0.04, HQ.navy, -35)
	box(host, 0.84, 0.23, 0.1, 0.1, tint, -35)
end
function SignArt.shield(host, tint)
	for i, color in ipairs({ Color3.fromRGB(220, 40, 50), HQ.white, Color3.fromRGB(220, 40, 50), Color3.fromRGB(30, 80, 190) }) do
		local size = 0.9 - (i - 1) * 0.18
		local ring = circle(host, 0.5, 0.5, size * 0.56, size, color)
		if i == 1 then stroke(ring, HQ.ink, 4) end
	end
	SignArt.sparkle(host, 0.5, 0.5, 0.26, HQ.white)
	SignArt.sparkle(host, 0.84, 0.16, 0.12, tint)
end
function SignArt.moon(host, tint)
	circle(host, 0.46, 0.5, 0.5, 0.82, HQ.gold)
	circle(host, 0.58, 0.44, 0.46, 0.76, tint)
	for _, spec in ipairs({ { 0.74, 0.3, 0.16 }, { 0.84, 0.18, 0.12 }, { 0.92, 0.08, 0.08 } }) do
		local z = Instance.new("TextLabel")
		z.BackgroundTransparency, z.Text, z.Font, z.TextScaled = 1, "Z", Enum.Font.FredokaOne, true
		z.AnchorPoint, z.Position, z.Size, z.TextColor3 = Vector2.new(0.5, 0.5), UDim2.fromScale(spec[1], spec[2]), UDim2.fromScale(spec[3], spec[3] * 1.4), HQ.white
		z.Parent = host
	end
end
function SignArt.cards(host, tint)
	for i, spec in ipairs({ { 0.34, -14, Color3.fromRGB(230, 60, 90) }, { 0.5, 0, HQ.white }, { 0.66, 14, Color3.fromRGB(70, 160, 240) } }) do
		local card = box(host, spec[1], 0.52, 0.3, 0.78, spec[3], spec[2], 0.12)
		stroke(card, HQ.ink, 4)
		SignArt.sparkle(card, 0.5, 0.5, 0.5, i == 2 and tint or HQ.white)
	end
end
function SignArt.bolt(host, tint)
	box(host, 0.46, 0.34, 0.14, 0.5, HQ.gold, 22)
	box(host, 0.54, 0.64, 0.14, 0.5, HQ.gold, 22)
	box(host, 0.5, 0.5, 0.3, 0.1, HQ.gold, -20)
	SignArt.sparkle(host, 0.2, 0.3, 0.16, tint)
	SignArt.sparkle(host, 0.8, 0.7, 0.12, HQ.white)
end
World.SignArt = SignArt

-- The big illustrated billboard: a lit frame and a SurfaceGui drawn with a
-- sky gradient, a sunburst, the area's illustration and an outlined title.
-- `cf` faces the reader (its -Z looks at them). Text is localized by the
-- client (LobbyTextPT/LobbyTextEN).
function Kit.sign(parent, name, cf, width, height, spec)
	local model = Instance.new("Model")
	model.Name, model.Parent = name, parent
	local accent = spec.accent or HQ.cyan
	local back = Kit.block(model, "SignBack", Vector3.new(width + 2.4, height + 2.4, 1.4), cf * CFrame.new(0, 0, 0.9), HQ.navy, Enum.Material.Metal)
	back.CastShadow = true
	local face = Kit.block(model, "SignFace", Vector3.new(width, height, 0.4), cf, HQ.ink, Enum.Material.SmoothPlastic)
	for _, side in ipairs({ -1, 1 }) do
		Kit.block(model, "SignRim", Vector3.new(width + 1.6, 0.45, 0.4), cf * CFrame.new(0, side * (height / 2 + 0.55), -0.1), accent, Enum.Material.Neon)
		Kit.block(model, "SignRim", Vector3.new(0.45, height + 1.6, 0.4), cf * CFrame.new(side * (width / 2 + 0.55), 0, -0.1), accent, Enum.Material.Neon)
		Kit.blob(model, "SignStud", Vector3.new(1.3, 1.3, 0.8), cf * CFrame.new(side * (width / 2 + 0.55), height / 2 + 0.55, -0.2), HQ.gold, Enum.Material.Metal)
		Kit.blob(model, "SignStud", Vector3.new(1.3, 1.3, 0.8), cf * CFrame.new(side * (width / 2 + 0.55), -(height / 2 + 0.55), -0.2), HQ.gold, Enum.Material.Metal)
	end
	if spec.legs then
		-- Freestanding: two legs down to the ground.
		local bottom = cf * CFrame.new(0, -height / 2 - 1.2, 0.9)
		for _, side in ipairs({ -1, 1 }) do
			local top = (bottom * CFrame.new(side * width * 0.32, 0, 0)).Position
			Kit.column(model, "SignLeg", Vector3.new(top.X, spec.legs, top.Z), top.Y - spec.legs, 1.3, HQ.steel, Enum.Material.Metal, true)
		end
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.LightInfluence = "Artwork", Enum.NormalId.Front, 0
	gui.SizingMode, gui.PixelsPerStud, gui.Parent = Enum.SurfaceGuiSizingMode.PixelsPerStud, 22, face
	local sky = frame2d(gui, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), HQ.white)
	sky.Name = "Sky"
	gradient(sky, spec.top or Color3.fromRGB(70, 170, 255), spec.bottom or Color3.fromRGB(34, 60, 150))
	-- Sunburst rays from behind the title.
	for i = 0, 5 do
		box(sky, 0.5, 0.45, 0.07, 2.4, HQ.white, i * 30, nil, 0.88)
	end
	local artHost = frame2d(sky, UDim2.fromScale(spec.artX or 0.5, spec.artY or 0.52), UDim2.fromScale(spec.artW or 0.36, spec.artH or 0.84), HQ.white, nil, 0, 1)
	artHost.Name = "Illustration"
	if spec.art and SignArt[spec.art] then SignArt[spec.art](artHost, accent) end
	for i = 1, 4 do SignArt.sparkle(sky, 0.06 + i * 0.2, 0.12 + (i % 2) * 0.72, 0.05, HQ.white) end
	local title = Instance.new("TextLabel")
	title.Name, title.BackgroundTransparency, title.Font, title.TextScaled = "Title", 1, Enum.Font.LuckiestGuy, true
	title.AnchorPoint, title.Position, title.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(spec.titleX or 0.5, spec.titleY or 0.42), UDim2.fromScale(spec.titleW or 0.9, spec.titleH or 0.46)
	title.TextColor3, title.Text, title.Parent = HQ.white, spec.title[1], sky
	title:SetAttribute("LobbyTextPT", spec.title[1]); title:SetAttribute("LobbyTextEN", spec.title[2])
	gradient(title, HQ.white, Color3.fromRGB(255, 226, 120))
	stroke(title, HQ.ink, math.max(4, height * 0.5))
	if spec.subtitle then
		local ribbon = box(sky, spec.titleX or 0.5, 0.84, 0.72, 0.2, accent, 0, 0.5)
		stroke(ribbon, HQ.ink, 3)
		local sub = Instance.new("TextLabel")
		sub.Name, sub.BackgroundTransparency, sub.Font, sub.TextScaled = "Subtitle", 1, Enum.Font.FredokaOne, true
		sub.AnchorPoint, sub.Position, sub.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.92, 0.78)
		sub.TextColor3, sub.Text, sub.Parent = HQ.white, spec.subtitle[1], ribbon
		sub:SetAttribute("LobbyTextPT", spec.subtitle[1]); sub:SetAttribute("LobbyTextEN", spec.subtitle[2])
		stroke(sub, HQ.ink, 3)
	end
	return model, face
end

-- A title floating in the air above an area, in world size (studs), like the
-- big games' zone names.
function Kit.floatText(parent, name, position, pt, en, color, width)
	width = width or 34
	local anchor = Kit.block(parent, name, Vector3.new(1, 1, 1), CFrame.new(position), HQ.white)
	anchor.Transparency = 1
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Size, gui.LightInfluence, gui.MaxDistance = "Title", UDim2.fromScale(width, width * 0.2), 0, 360
	gui.AlwaysOnTop, gui.Parent = false, anchor
	local text = Instance.new("TextLabel")
	text.Name, text.BackgroundTransparency, text.Size, text.Font, text.TextScaled = "Text", 1, UDim2.fromScale(1, 1), Enum.Font.LuckiestGuy, true
	text.TextColor3, text.Text, text.Parent = HQ.white, pt, gui
	text:SetAttribute("LobbyTextPT", pt); text:SetAttribute("LobbyTextEN", en)
	gradient(text, HQ.white, color)
	stroke(text, HQ.ink, 5)
	return anchor
end

-- Where each area of the island sits, as offsets from the hub (spawn plaza,
-- moat, bridges). Angles are degrees from +X toward +Z (north), radii in
-- studs from the hub. The island lies well north of the battlefield square
-- (World:Build, 176 studs around the origin): servers that host both see the
-- city across the water, not at the foot of the portals.
local function hubAt(dx, dz, y) return Vector3.new(HUB.X + dx, y or 0, HUB.Z + dz) end
-- The city skyline across the bay to the north-east.
local CITY_CENTER = hubAt(700, 640)
local LAYOUT = {
	islandRadius = 160,
	hubDeck = 70, moat = 86, ringRoad = { 92, 100 },
	market = { { 125, 118 }, { 150, 118 } }, -- the two summon halls
	armory = { 45, 118 },
	hangar = hubAt(-86, -83), command = hubAt(86, -83),
	towerPlaza = { x = 46, dz0 = 91, dz1 = 117 }, tower = hubAt(0, 132),
	-- The three island extensions and their bridges.
	islands = {
		west = { center = hubAt(-215, 85), radius = 58, bridge = { hubAt(-133, 78), hubAt(-162, 87) } },
		east = { center = hubAt(205, 117), radius = 60, bridge = { hubAt(114, 79), hubAt(151, 103) } },
		north = { center = hubAt(0, 255), radius = 78, bridge = { hubAt(0, 156), hubAt(0, 183) } },
	},
	-- Paved floors the areas stand on: offset x/z, width, depth.
	floors = {
		campaign = { 0, -117.5, 124, 35 }, arena = { 125, 0, 42, 110 }, afk = { -125, -1, 46, 100 },
		academy = { 0, 245, 84, 60 }, expedition = { -231, 81, 36, 70 }, latveria = { 233, 117, 38, 48 },
	},
	kiosks = { -38, -27, -16, 16, 27 }, kioskDz = 107,
	services = {
		{ id = "guide", angle = 120, pt = "NICO • GUIA", en = "NICO • GUIDE", color = Color3.fromRGB(255, 205, 90) },
		{ id = "maps", angle = 150, pt = "ESCOLHER MAPA", en = "CHOOSE MAP", color = Color3.fromRGB(110, 220, 170) },
		{ id = "inventory", angle = 210, pt = "SUA EQUIPE", en = "YOUR TEAM", color = Color3.fromRGB(255, 150, 110) },
		{ id = "bases", angle = 240, pt = "SUAS BASES", en = "YOUR BASES", color = Color3.fromRGB(150, 215, 140) },
		{ id = "talents", angle = 300, pt = "ACADEMIA", en = "ACADEMY", color = Color3.fromRGB(200, 160, 255) },
	},
	boards = { quests = 30, leaderboard = 60 },
}
World.Layout = LAYOUT
local function polar(degrees, radius, y)
	local a = math.rad(degrees)
	return Vector3.new(HUB.X + math.cos(a) * radius, y or 0, HUB.Z + math.sin(a) * radius)
end
-- Facing yaw so that a model's local +Z looks from `from` toward `to`.
local function yawToward(from, to)
	local d = to - from
	return math.atan2(d.X, d.Z)
end
-- A walk-in box the server reads. `frame` turns it with a building that is
-- not square to the world; the box is measured in that frame.
local function inZone(position, zone, margin, center, size, frame)
	center, size, frame, margin = center or zone.center, size or zone.size, frame or zone.frame, margin or 0
	local offset = frame and frame:Inverse() * position or position - center
	return math.abs(offset.X) <= size.X / 2 + margin and math.abs(offset.Y) <= size.Y / 2 + margin and math.abs(offset.Z) <= size.Z / 2 + margin
end

-- Lighting is one global service, shared by the lobby and whichever match map
-- is built. Standalone servers keep both areas in the same Workspace, so
-- whoever finishes a match and walks back must see the lobby's own mood
-- again, not whatever chapter they were just fighting in. World:Build applies
-- a map mood; this is the only thing that puts it back afterward.
function World:ApplyLobbyLighting()
	local lighting = game:GetService("Lighting")
	-- A bright tropical afternoon: saturated colour, soft shadows and enough
	-- bloom that every neon strip glows. No depth blur: the lobby is read, not
	-- admired through a lens.
	lighting.ClockTime, lighting.Brightness = 14.3, 3
	lighting.ExposureCompensation = 0.1
	lighting.Ambient, lighting.OutdoorAmbient = Color3.fromRGB(112, 120, 142), Color3.fromRGB(150, 158, 176)
	lighting.FogColor, lighting.FogStart, lighting.FogEnd = Color3.fromRGB(176, 214, 245), 700, 2600
	local atmos = ensureLightingEffect(lighting, "Atmosphere", "Atmosphere")
	atmos.Density, atmos.Offset, atmos.Color, atmos.Decay, atmos.Glare, atmos.Haze = 0.28, 0.2, Color3.fromRGB(199, 226, 255), Color3.fromRGB(104, 150, 206), 0.25, 1.3
	local bloom = ensureLightingEffect(lighting, "BloomEffect", "Bloom")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.45, 26, 1.05
	local grade = ensureLightingEffect(lighting, "ColorCorrectionEffect", "ColorGrade")
	grade.TintColor, grade.Contrast, grade.Saturation, grade.Brightness = Color3.fromRGB(255, 251, 244), 0.1, 0.2, 0.02
	local rays = ensureLightingEffect(lighting, "SunRaysEffect", "SunRays")
	rays.Intensity, rays.Spread = 0.06, 0.5
	local dof = ensureLightingEffect(lighting, "DepthOfFieldEffect", "DOF")
	dof.FarIntensity, dof.NearIntensity, dof.FocusDistance, dof.InFocusRadius = 0, 0, 100, 200
	lighting.EnvironmentDiffuseScale, lighting.EnvironmentSpecularScale = 0.8, 1
	lighting.GlobalShadows, lighting.ShadowSoftness = true, 0.2
	-- The sea, the island's own terrain colours and the sky; a chapter may
	-- have recoloured all of them, so they are put back here too.
	local terrain = workspace.Terrain
	terrain.WaterColor, terrain.WaterTransparency, terrain.WaterReflectance = Color3.fromRGB(20, 150, 215), 0.45, 0.45
	terrain.WaterWaveSize, terrain.WaterWaveSpeed = 0.18, 9
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(106, 178, 74))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(240, 220, 168))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(136, 140, 150))
	terrain:SetMaterialColor(Enum.Material.Pavement, Color3.fromRGB(150, 156, 170))
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover, clouds.Density, clouds.Color = 0.55, 0.62, Color3.fromRGB(255, 255, 255)
	clouds.Parent = terrain
end

function World.new(catalog, openPanel, config)
	upper = catalog.Upper or string.upper
	campaignWaves = catalog.CampaignWaves or {}
	local self = setmetatable({ catalog = catalog, openPanel = openPanel, mapImages = config and config.MapImages or {} }, World)
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

-- Station text, localized by the client (LobbyTextPT/LobbyTextEN).
local function stationText(parent, name, pt, en, position, size, tint, fontSize)
	local text=Instance.new("TextLabel")
	text.Name,text.BackgroundTransparency,text.Position,text.Size=name,1,position,size
	text.Font,text.TextColor3,text.TextSize=Enum.Font.FredokaOne,tint,fontSize
	text.TextWrapped,text.TextStrokeTransparency,text.Text= true,0.35,pt
	text:SetAttribute("LobbyTextPT",pt); text:SetAttribute("LobbyTextEN",en)
	text.Parent=parent
	return text
end

-- A real 3D vignette with this map's authored roads. Rendering it into the
-- sign avoids blank thumbnails while an image upload is awaiting moderation.
-- Its camera is bound again by each client (CurrentCamera does not replicate).
local function mapVignette(parent,map,tint)
	local viewport=Instance.new("ViewportFrame")
	viewport.Name,viewport.Size,viewport.BackgroundColor3="MapPicture",UDim2.fromScale(1,0.75),Color3.fromRGB(116,193,225)
	viewport.BorderSizePixel=0; viewport.Ambient=Color3.fromRGB(190,190,190)
	viewport.LightColor,viewport.LightDirection=Color3.fromRGB(255,240,211),Vector3.new(-1,-1,-0.5)
	viewport.Parent=parent
	local scene=Instance.new("WorldModel"); scene.Name="MapScene"; scene.Parent=viewport
	local green=map.id=="wakanda" or map.id=="gamma"
	local ground=green and Color3.fromRGB(69,126,75) or Color3.fromRGB(86,96,108)
	if map.id=="asgard" then ground=Color3.fromRGB(172,154,102) end
	part(scene,"Ground",Vector3.new(210,2,210),CFrame.new(0,-1,0),ground)
	for _,route in ipairs(map.paths) do
		for i=2,#route do
			local a,b=Vector3.new(route[i-1][1],0.3,route[i-1][2]),Vector3.new(route[i][1],0.3,route[i][2])
			part(scene,"Road",Vector3.new(12,0.4,(a-b).Magnitude+8),CFrame.lookAt((a+b)/2,b),Color3.fromRGB(217,209,185))
		end
	end
	for i=1,12 do
		local x=(i%2==0 and -1 or 1)*(82+(i%3)*8)
		local z=-90+math.floor((i-1)/2)*35
		local h=20+(i%4)*9
		local color=map.id=="latveria" and Color3.fromRGB(60,68,91) or Color3.fromRGB(126,153,171)
		if map.id=="manhattan" or map.id=="hydra" then
			local block=part(scene,"Building",Vector3.new(15,h,18),CFrame.new(x,h/2,z),color)
			for floor=1,3 do part(scene,"Windows",Vector3.new(15.2,2,18.2),block.CFrame*CFrame.new(0,-h/2+floor*h/4,0),tint) end
		elseif map.id=="gamma" then
			local tank=part(scene,"Reactor",Vector3.new(h,16,16),CFrame.new(x,h/2,z)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(88,122,108))
			tank.Shape=Enum.PartType.Cylinder
			part(scene,"Energy",Vector3.new(16.5,3,16.5),CFrame.new(x,h*0.7,z),tint)
		elseif map.id=="wakanda" then
			part(scene,"Trunk",Vector3.new(4,h,4),CFrame.new(x,h/2,z),Color3.fromRGB(102,77,53))
			local leaf=part(scene,"Crown",Vector3.new(26,18,24),CFrame.new(x,h,z),Color3.fromRGB(81,159,85)); leaf.Shape=Enum.PartType.Ball
		else
			part(scene,"Citadel",Vector3.new(12,h+15,12),CFrame.new(x,(h+15)/2,z),map.id=="asgard" and ART.pearl or color)
			part(scene,"Crown",Vector3.new(16,4,16),CFrame.new(x,h+15,z),map.id=="asgard" and ART.gold or tint)
		end
	end
	local camera=Instance.new("Camera"); camera.Name="PictureCamera"
	camera.CFrame=CFrame.lookAt(Vector3.new(100,120,140),Vector3.new(0,7,0)); camera.FieldOfView=40
	viewport:SetAttribute("PictureCFrame",camera.CFrame)
	viewport:SetAttribute("PictureFieldOfView",camera.FieldOfView)
	camera.Parent=viewport; viewport.CurrentCamera=camera
	for _,p in ipairs(scene:GetDescendants()) do if p:IsA("BasePart") then
		p.CanCollide,p.CanTouch,p.CanQuery=false,false,false
		p:SetAttribute("MapPicturePart",true)
	end end
end

-- A destination is a boarding station: a steel deck with three glowing pads
-- (independent four-player queues), each under its own lit gate, and the
-- map's billboard framed in neon above them. Each zone retains its catalog
-- destination, never a client map.
local function buildModePortal(lobby,x,z,portalId,mode,destination,map,photo)
	local tint=rgb(PORTAL_COLORS[destination.mapId])
	local yaw=destination.facing or 0
	local base=CFrame.new(x,GROUND_Y,z)*CFrame.Angles(0,yaw,0)
	local function at(dx,y,dz) return base*CFrame.new(dx,y,dz) end
	local model=Instance.new("Model"); model.Name,model.Parent="Portal_"..portalId,lobby
	model:SetAttribute("Kind","ModePortal"); model:SetAttribute("ModeId",destination.modeId)
	model:SetAttribute("PortalId",portalId); model:SetAttribute("MapId",map.id)
	model:SetAttribute("District",destination.district or "center")
	local plinth=part(model,"Plinth",Vector3.new(32,0.5,13),at(0,0.25,0),HQ.navy,Enum.Material.Metal)
	model.PrimaryPart=plinth
	artPart(model,"PlinthLip",Vector3.new(33,0.36,14),at(0,0.14,0),HQ.trim,Enum.Material.SmoothPlastic)
	artPart(model,"PlinthGlow",Vector3.new(32.6,0.14,0.3),at(0,0.36,6.72),tint,Enum.Material.Neon)
	for _,side in ipairs({-1,1}) do
		part(model,"SignPillar",Vector3.new(1.4,17,1.6),at(side*14.6,8.5,-4.8),HQ.navy,Enum.Material.Metal).CastShadow=true
		artPart(model,"SignLight",Vector3.new(0.3,14,0.2),at(side*14.6,9,-3.95),tint,Enum.Material.Neon)
	end
	local board=part(model,"MapBillboard",Vector3.new(32,12.5,0.8),at(0,20,-4.5)*CFrame.Angles(0,math.pi,0),HQ.ink,Enum.Material.Metal)
	-- A thick navy frame, a neon rim in the map's colour and gold studs: the
	-- same family as every other sign on the island.
	artPart(model,"BillboardBack",Vector3.new(34.6,14.9,0.6),at(0,20,-5.2),HQ.navy,Enum.Material.Metal).CastShadow=true
	for _,side in ipairs({-1,1}) do
		artPart(model,"BillboardRim",Vector3.new(33.8,0.5,0.4),at(0,20+side*6.72,-4.05),tint,Enum.Material.Neon)
		artPart(model,"BillboardRim",Vector3.new(0.5,13.9,0.4),at(side*16.45,20,-4.05),tint,Enum.Material.Neon)
		for _,up in ipairs({-1,1}) do
			Kit.blob(model,"BillboardStud",Vector3.new(1.3,1.3,0.8),at(side*16.45,20+up*6.72,-3.9),HQ.gold,Enum.Material.Metal)
		end
	end
	local surface=Instance.new("SurfaceGui"); surface.Name="MapBoard"; surface.Face=Enum.NormalId.Front
	surface.LightInfluence,surface.CanvasSize,surface.SizingMode=0,Vector2.new(880,344),Enum.SurfaceGuiSizingMode.FixedSize
	surface.Parent=board
	mapVignette(surface,map,tint)
	-- A photograph of the real map, once imported and configured
	-- (Config.MapImages), covers the rendered diorama.
	if (tonumber(photo) or 0)>0 then
		local image=Instance.new("ImageLabel")
		image.Name,image.Size,image.BackgroundTransparency,image.ZIndex="MapPhoto",UDim2.fromScale(1,0.75),1,0
		image.Image,image.ScaleType="rbxassetid://"..tostring(math.floor(photo)),Enum.ScaleType.Crop
		image.Parent=surface
		surface.MapPicture.Visible=false
	end
	local title=stationText(surface,"MapTitle",map.name.pt,map.name.en,UDim2.fromScale(0.02,0.24),UDim2.fromScale(0.96,0.35),Color3.new(1,1,1),64)
	title.Font,title.TextStrokeTransparency=Enum.Font.LuckiestGuy,0
	local waves=destination.modeId=="normal" and campaignWaves[map.id] or mode.waves
	local suffix=waves==0 and "INFINITO" or tostring(waves).." ONDAS"
	local suffixEN=waves==0 and "ENDLESS" or tostring(waves).." WAVES"
	stationText(surface,"MapRules",upper(mode.name.pt).."  •  "..suffix,upper(mode.name.en).."  •  "..suffixEN,UDim2.fromScale(0.02,0.75),UDim2.fromScale(0.96,0.13),tint,25)
	stationText(surface,"MapCapacity","3 FILAS  •  ATÉ 4 JOGADORES CADA","3 QUEUES  •  UP TO 4 PLAYERS EACH",UDim2.fromScale(0.02,0.89),UDim2.fromScale(0.96,0.1),ART.pearl,18)
	local zones={}
	for slot=1,3 do
		local dx=(slot-2)*10.2
		local pad=part(model,slot==1 and "Pad" or "Pad"..slot,Vector3.new(8.4,0.18,8.4),at(dx,0.58,0.4),tint,Enum.Material.Neon)
		pad.Transparency=0.25; pad.CanCollide=false
		artPart(model,"PadFrame",Vector3.new(9.4,0.2,9.4),at(dx,0.52,0.4),HQ.trim,Enum.Material.SmoothPlastic)
		local queueId=slot==1 and portalId or portalId..":"..slot
		pad:SetAttribute("QueueId",queueId)
		for _,side in ipairs({-1,1}) do
			artPart(model,"QueueRail",Vector3.new(0.35,1.6,8.7),at(dx+side*4.9,1.3,0.4),HQ.steel,Enum.Material.Metal)
			artPart(model,"QueueGate",Vector3.new(0.6,7.5,0.9),at(dx+side*3.4,4.25,-3.8),HQ.navy,Enum.Material.Metal)
			artPart(model,"QueueGateLight",Vector3.new(0.18,6,0.2),at(dx+side*3.05,4.4,-3.3),tint,Enum.Material.Neon)
		end
		artPart(model,"QueueLintel",Vector3.new(7.4,0.6,0.9),at(dx,8.1,-3.8),tint,Enum.Material.Neon)
		local door=at(dx,4.35,-3.8)*CFrame.Angles(0,math.pi/2,0)
		local rim=artPart(model,"PortalRim",Vector3.new(0.3,6.3,6.3),door,tint:Lerp(Color3.new(1,1,1),0.25),Enum.Material.Neon)
		rim.Shape=Enum.PartType.Cylinder
		local membrane=artPart(model,"PortalMembrane",Vector3.new(0.34,5.7,5.7),door,tint:Lerp(HQ.ink,0.45),Enum.Material.SmoothPlastic)
		membrane.Shape=Enum.PartType.Cylinder
		-- The vortex: a pinwheel of light drawn on a clear pane in front of
		-- the membrane; the client turns it (PortalSwirl).
		local pane=artPart(model,"PortalPane",Vector3.new(5.7,5.7,0.05),at(dx,4.35,-3.55),tint,Enum.Material.SmoothPlastic)
		pane.Transparency=1
		local gui=Instance.new("SurfaceGui")
		gui.Name,gui.Face,gui.LightInfluence,gui.CanvasSize=  "PortalSwirl",Enum.NormalId.Back,0,Vector2.new(256,256)
		gui.SizingMode,gui.Parent=Enum.SurfaceGuiSizingMode.FixedSize,pane
		local swirl=frame2d(gui,UDim2.fromScale(0.5,0.5),UDim2.fromScale(1,1),tint,UDim.new(0.5,0),0,1)
		swirl.Name="Swirl"
		for arm=0,5 do
			local bar=box(swirl,0.5+math.cos(math.rad(arm*60))*0.2,0.5+math.sin(math.rad(arm*60))*0.2,0.14,0.52,tint:Lerp(HQ.white,arm%2==0 and 0.55 or 0.15),arm*60+40,0.5,0.25)
			bar.Name="SwirlArm"
		end
		local ring=circle(swirl,0.5,0.5,0.72,0.72,tint,1)
		stroke(ring,tint:Lerp(HQ.white,0.4),6)
		local core=circle(gui,0.5,0.5,0.3,0.3,HQ.white,0.15)
		core.Name="SwirlCore"
		local sign=part(model,"QueueSign"..slot,Vector3.new(8.3,2.5,0.25),at(dx,10,-3.8)*CFrame.Angles(0,math.pi,0),HQ.ink)
		local gui=Instance.new("SurfaceGui"); gui.Name="QueueBoard"; gui.Face=Enum.NormalId.Front; gui.LightInfluence=0
		gui.CanvasSize=Vector2.new(290,94); gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize; gui.Parent=sign
		stationText(gui,"QueueTitle","FILA "..slot,"QUEUE "..slot,UDim2.fromScale(0,0),UDim2.fromScale(1,0.36),ART.pearl,20)
		local status=stationText(gui,"QueueStatus","0/4  •  ENTRE","0/4  •  STEP IN",UDim2.fromScale(0,0.36),UDim2.fromScale(1,0.62),tint,26)
		zones[queueId]={destinationId=portalId,slot=slot,center=at(dx,4,0.4).Position,
			size=Vector3.new(8.4,8,8.4),exit=at(dx,4,10).Position,pad=pad,label=status,tint=tint,membrane=membrane,core=core}
	end
	return model,zones
end

-- Separate physical summon halls. A player near one doorway can only buy
-- that collection, even if a forged request names a chest from the other.
-- The hall's door (+Z) faces `yaw`; its zones are measured in its own frame.
local function buildChestStand(lobby,x,z,chestId,chest,openPanel,yaw)
	local model=Instance.new("Model"); model.Name,model.Parent="Chest_"..chestId,lobby
	model:SetAttribute("Kind","ChestStand"); model:SetAttribute("ChestId",chestId)
	local isBase=chest.kind=="base"
	model:SetAttribute("SummonKind",isBase and "base" or "hero")
	local tint=isBase and Color3.fromRGB(115,227,165) or Color3.fromRGB(255,180,79)
	local secondary=isBase and Color3.fromRGB(80,170,239) or Color3.fromRGB(180,131,247)
	local origin=CFrame.new(x,GROUND_Y,z)*CFrame.Angles(0,yaw or 0,0)
	local function at(dx,y,dz) return origin*CFrame.new(dx,y,dz) end
	local floor=part(model,"Plinth",Vector3.new(28,0.6,22),at(0,0.3,0),HQ.navy,Enum.Material.Metal)
	model.PrimaryPart=floor
	part(model,"BackWall",Vector3.new(28,16,1.2),at(0,8,-10.5),HQ.navy,Enum.Material.Metal).CastShadow=true
	for _,side in ipairs({-1,1}) do
		part(model,"HallWall",Vector3.new(1.2,16,22),at(side*13.4,8,0),HQ.steel,Enum.Material.Metal).CastShadow=true
		part(model,"FrontWing",Vector3.new(7.5,15,1.3),at(side*9.6,7.8,10),HQ.navy,Enum.Material.Metal)
		artPart(model,"SummonTrim",Vector3.new(0.3,13,0.3),at(side*6,7.3,10.8),tint,Enum.Material.Neon)
		artPart(model,"EnergyConduit",Vector3.new(0.26,9,0.3),at(side*12,8,10.8),secondary,Enum.Material.Neon)
	end
	part(model,"Roof",Vector3.new(29,1,23),at(0,16.5,0),HQ.trim,Enum.Material.SmoothPlastic).CastShadow=true
	artPart(model,"RoofGlow",Vector3.new(29.3,0.3,23.3),at(0,15.9,0),tint,Enum.Material.Neon)
	part(model,"EntranceLintel",Vector3.new(13,4,1.4),at(0,14,10),HQ.navy,Enum.Material.Metal)
	Kit.sign(model,"SummonHeader",at(0,21.2,9.6)*CFrame.Angles(0,math.pi,0),22,6.4,{
		title=isBase and {"INVOCAR BASES","SUMMON BASES"} or {"INVOCAR HERÓIS","SUMMON HEROES"},
		top=isBase and Color3.fromRGB(110,230,170) or Color3.fromRGB(255,200,90),
		bottom=isBase and Color3.fromRGB(30,110,120) or Color3.fromRGB(190,70,150),
		accent=tint,art="chest",artX=0.12,artW=0.2,titleX=0.58,titleW=0.8,titleY=0.5,titleH=0.7,
	})
	local reactor=artPart(model,"SummonCore",Vector3.new(0.8,9,9),at(0,6,-8.6)*CFrame.Angles(0,math.pi/2,0),secondary,Enum.Material.Neon)
	reactor.Shape=Enum.PartType.Cylinder; reactor.Transparency=0.35
	arc(model,"SummonRing",at(0,6,-8.9),5.3,0.45,0.65,tint,Enum.Material.Metal,16)
	for i=-1,1 do
		local column=artPart(model,"SummonColumn",Vector3.new(2.2,2.5+math.abs(i),2.2),at(i*4.2,1.85+math.abs(i)/2,-3),HQ.trim,Enum.Material.Metal)
		artPart(model,"SummonChip",Vector3.new(1.7,0.18,1.7),column.CFrame*CFrame.new(0,column.Size.Y/2+0.05,0),tint,Enum.Material.Neon)
	end
	-- The prize: a giant treasure chest floating over the roof, lid open
	-- and treasure glowing, turning slowly: seen from anywhere on the plaza.
	local chestAt=at(0,28,-1)
	local turn=chestAt.Position
	for _,piece in ipairs(Kit.treasureChest(model,chestAt,isBase and Color3.fromRGB(70,190,120) or Color3.fromRGB(235,110,60),tint,-0.55,1.9)) do
		Kit.animate(piece,0.45,0.8,turn)
	end
	local beam=artPart(model,"PrizeBeam",Vector3.new(11,4.5,4.5),at(0,22.5,-1)*CFrame.Angles(0,0,math.pi/2),tint,Enum.Material.Neon)
	beam.Shape,beam.Transparency=Enum.PartType.Cylinder,0.55
	Kit.light(reactor,secondary,26,1.6)
	artPart(model,"HallGlow",Vector3.new(24,0.4,0.3),at(0,13.5,-9.85),tint,Enum.Material.Neon)
	artPart(model,"HallFloorRing",Vector3.new(14,0.1,14),at(0,0.62,-3),secondary,Enum.Material.Neon).Transparency=0.6
	local pad=artPart(model,"ShopEntryPad",Vector3.new(11,0.16,12),at(0,0.64,11.5),Color3.fromRGB(81,220,130),Enum.Material.Neon)
	pad.Transparency=0.35; pad.CanCollide=false
	for _,side in ipairs({-1,1}) do artPart(model,"ShopEntryBorder",Vector3.new(0.3,0.15,12),at(side*5.65,0.77,11.5),tint,Enum.Material.Neon) end
	local plaque=wallSign(model,"SummonDoorHint",at(0,11,10.9)*CFrame.Angles(0,math.pi,0),Vector3.new(10.4,1.6,0.15),"APROXIME-SE","ESCOLHA • INVOQUE • EQUIPE",ART.pearl)
	for _,node in ipairs(plaque:GetDescendants()) do
		if node:IsA("TextLabel") then
			node:SetAttribute("LobbyTextPT",node.Text)
			node:SetAttribute("LobbyTextEN",node.Name=="Title" and "STEP CLOSER" or "CHOOSE • SUMMON • EQUIP")
		end
	end
	interactable(pad,isBase and "Invocar bases" or "Invocar heróis",function(player)
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position-pad.Position).Magnitude<=14 then openPanel(player,"chests",{chestId=chestId}) end
	end,12)
	return model,{center=at(0,4,11.5).Position,size=Vector3.new(12,8,14),frame=at(0,4,11.5),
		purchaseCenter=at(0,4,3).Position,purchaseSize=Vector3.new(26,10,31),purchaseFrame=at(0,4,3),
		chestId=chestId,kind=isBase and "base" or "hero"}
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
	local y = GROUND_Y
	local stand = part(model, "Stand", Vector3.new(6.4,1,6.4), CFrame.new(x,y+0.5,z), HQ.trim, Enum.Material.SmoothPlastic)
	artPart(model,"DisplayInset",Vector3.new(5.8,0.15,5.8),CFrame.new(x,y+1.06,z),HQ.navy,Enum.Material.DiamondPlate)
	artPart(model,"StandGlow",Vector3.new(6.6,0.2,6.6),CFrame.new(x,y+0.15,z),HQ.gold,Enum.Material.Neon)
	for _,side in ipairs({-1,1}) do
		artPart(model,"ShowcasePillar",Vector3.new(0.5,5.6,0.5),CFrame.new(x+side*2.9,y+3.8,z-2.9),HQ.navy,Enum.Material.Metal)
		artPart(model,"DisplayLight",Vector3.new(0.14,4.1,0.14),CFrame.new(x+side*2.62,y+3.8,z-2.62),HQ.gold,Enum.Material.Neon)
	end
	artPart(model,"ShowcaseCanopy",Vector3.new(6.8,0.4,6),CFrame.new(x,y+6.8,z-0.4),HQ.navy,Enum.Material.Metal)
	artPart(model,"CanopyGlow",Vector3.new(6.9,0.22,0.3),CFrame.new(x,y+6.72,z+2.55),HQ.gold,Enum.Material.Neon)
	if shopKey == "heroes" and showcase then
		-- Recruitment card marks direct purchases without a character statue.
		artPart(model,"RecruitCard",Vector3.new(0.4,3.6,2.8),CFrame.new(x,y+3,z),ART.gold,Enum.Material.Metal)
		artPart(model,"RecruitStar",Vector3.new(0.5,1.2,1.2),CFrame.new(x+0.25,y+3,z)*CFrame.Angles(math.pi/4,0,0),ART.cyan,Enum.Material.Neon)
		part(model, "DisplayRing", Vector3.new(4.6, 0.15, 4.6), CFrame.new(x, y+1.15, z), ART.gold, Enum.Material.Neon).CanCollide = false
	elseif shopKey == "collector" then
		-- A body with two crossed rotor arms, so the client's showroom spin is
		-- actually visible; a lone sphere turning looks exactly like one standing.
		local drone = part(model, "Drone", Vector3.new(1.4, 1.4, 1.4), CFrame.new(x, y+3, z), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
		drone.Shape = Enum.PartType.Ball
		for _, angle in ipairs({ math.pi / 4, -math.pi / 4 }) do
			part(model, "Drone", Vector3.new(3.2, 0.14, 0.3), CFrame.new(x, y+3, z) * CFrame.Angles(0, angle, 0), Color3.fromRGB(150, 172, 190), Enum.Material.Metal)
		end
		part(model, "DroneRing", Vector3.new(2.6, 0.15, 2.6), CFrame.new(x, y+2.1, z), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
	elseif shopKey == "vip" then
		part(model, "Mannequin", Vector3.new(1.6, 3.6, 1), CFrame.new(x, y+2.8, z), Color3.fromRGB(255, 210, 103), Enum.Material.Neon)
		part(model, "MannequinHead", Vector3.new(1, 1, 1), CFrame.new(x, y+5, z), Color3.fromRGB(255, 210, 103))
	elseif shopKey == "gold" then
		for i = 1, 3 do
			-- A Cylinder's axis runs along X, so a coin lying flat needs its
			-- thickness in X and a quarter turn to stand the axis upright.
			local diameter = 1.7 - i * 0.12
			local coin = part(model, "Coin", Vector3.new(0.4, diameter, diameter), CFrame.new(x, y + 0.75 + i * 0.42, z) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(255, 210, 103), Enum.Material.Neon)
			coin.Shape = Enum.PartType.Cylinder
		end
	else
		part(model, "Chip", Vector3.new(1.4, 1.8, 1.4), CFrame.new(x, y+2.4, z), Color3.fromRGB(120, 220, 255), Enum.Material.Neon)
	end
	label(stand, displayName, Vector3.new(0, 7.4, 0), Color3.fromRGB(255, 210, 103), 220, 40)
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
		-- Pictures have separate coordinate spaces, not coplanar lobby faces.
		if item:IsA("BasePart") and not item:IsA("MeshPart") and not item:GetAttribute("MapPicturePart") then alignedFaces(item, faces) end
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

--==============================================================================
-- The lobby: the Heroes' HQ island
--==============================================================================
-- A raised hero plaza on a round hub in a moat, four lit bridges, a ring road
-- and the areas around it: the campaign terrace (south), the arena (east), the
-- AFK lounge (west), the summon halls (north-west), the tower with the Robux
-- kiosks (north), S.H.I.E.L.D. on the corners, three island extensions and a
-- city skyline across the bay. Functional pieces (portals, halls, kiosks,
-- boards, AFK chambers, the scoreboard) are direct
-- children of the lobby; scenery lives in HeroesHQ.
function World:BuildLobby()
	local old = workspace:FindFirstChild("DoomLobby")
	if old then old:Destroy() end
	local lobby = Instance.new("Model")
	lobby.Name, lobby.Parent = "DoomLobby", workspace
	self.lobby, self.portalZones, self.shopZones, self.shopOccupants = lobby, {}, {}, {}
	self:BuildLobbyTerrain()
	-- Everyone arrives on the hero star, facing the campaign gate.
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size, spawn.CFrame = "LobbySpawn", Vector3.new(14, 0.2, 14), CFrame.new(HUB.X, PLAZA_Y + 0.1, HUB.Z)
	spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.Transparency = true, true, 0, 1
	spawn.Parent = lobby
	self.lobbySpawn = Vector3.new(HUB.X, PLAZA_Y + 4, HUB.Z)
	local hq = self:BuildHeroesHub(lobby)
	-- Fixed destinations, each with three independent four-player queues.
	for _, portalId in ipairs(self.catalog.DestinationOrder) do
		local destination = self.catalog.Destinations[portalId]
		local _, zones = buildModePortal(lobby, destination.x, destination.z, portalId, self.catalog.Modes[destination.modeId], destination, self.catalog.Maps[destination.mapId], self.mapImages[destination.mapId])
		for queueId, zone in pairs(zones) do self.portalZones[queueId] = zone end
	end
	self:BuildHeroBeacon(lobby)
	self:BuildHeroStatues(lobby)
	self:BuildServiceDesks(lobby)
	self:BuildCampaignTerrace(hq)
	self:BuildArena(lobby, hq)
	self:BuildAfkLounge(lobby, hq)
	self:BuildMarket(lobby, hq)
	self:BuildTowerPlaza(hq)
	self:BuildHeroTower(lobby)
	self:BuildShieldSites(hq)
	self:BuildIslands(hq)
	self:BuildHeroCameos(hq)
	self:BuildHorizon(hq)
	self:DressHeroesHQ(hq)
	-- Last: no two surfaces of the finished lobby may share a plane.
	World.SeparateCoplanar(lobby)
end

--------------------------------------------------------------------------------
-- Terrain: the sea, the islands' beaches, grass and rock, the moat and a ring
-- of far islands on the horizon. Water surfaces sit at a fill's top; solid
-- terrain renders two studs above it (4-stud voxels).
--------------------------------------------------------------------------------
function World:BuildLobbyTerrain()
	local terrain = workspace.Terrain
	local role = workspace:GetAttribute("DoomRole")
	-- Servers that also build battlefields (standalone, match) keep the sea
	-- out of the battlefield's square: World:Build owns 176 studs around the
	-- origin and clears only that volume.
	local shared = role ~= "Lobby" and role ~= "Afk"
	local keep, reach = 180, 1000
	local function sea(x0, x1, z0, z1)
		terrain:FillBlock(CFrame.new((x0 + x1) / 2, SEA_Y - 8, (z0 + z1) / 2), Vector3.new(x1 - x0, 16, z1 - z0), Enum.Material.Water)
	end
	if shared then
		sea(-reach, reach, keep, HUB.Z + reach)
		sea(-reach, reach, -reach, -keep)
		sea(-reach, -keep, -keep, keep)
		sea(keep, reach, -keep, keep)
	else
		sea(-reach, reach, -reach, HUB.Z + reach)
	end
	-- Rocks gather along the shores, never where a bridge lands.
	local landings = {}
	for _, def in pairs(LAYOUT.islands) do table.insert(landings, def.bridge[1]); table.insert(landings, def.bridge[2]) end
	local function island(center, radius, rocks, height)
		terrain:FillCylinder(CFrame.new(center.X, SEA_Y - 5, center.Z), 7, radius + 10, Enum.Material.Sand)
		terrain:FillCylinder(CFrame.new(center.X, GRASS_Y - 5.5 + (height or 0), center.Z), 7, radius, Enum.Material.Grass)
		local rng = Random.new(math.floor(center.X * 7 + center.Z))
		for _ = 1, rocks or 10 do
			local a = rng:NextNumber(0, math.pi * 2)
			local r = radius + rng:NextNumber(2, 8)
			local at = Vector3.new(center.X + math.cos(a) * r, SEA_Y + rng:NextNumber(-1, 1.5), center.Z + math.sin(a) * r)
			local clear = true
			for _, landing in ipairs(landings) do
				if (Vector3.new(at.X, 0, at.Z) - landing).Magnitude < 18 then clear = false end
			end
			if clear then terrain:FillBall(at, rng:NextNumber(2.5, 5.5), Enum.Material.Rock) end
		end
	end
	island(HUB + Vector3.new(0, 0, 5), LAYOUT.islandRadius, 30)
	for _, def in pairs(LAYOUT.islands) do island(def.center, def.radius, 12) end
	-- The moat: clear shallow water over a sand floor around the hub deck.
	terrain:FillCylinder(CFrame.new(HUB.X, -7, HUB.Z), 6, LAYOUT.moat, Enum.Material.Sand)
	terrain:FillCylinder(CFrame.new(HUB.X, -2.45, HUB.Z), 3.1, LAYOUT.moat, Enum.Material.Water)
	-- Far islands: grassy hills and cliffs frame every direction of view.
	for _, spec in ipairs({ { -430, -15, 90, 26 }, { 440, 35, 80, 20 }, { -300, 415, 110, 34 }, { 330, 300, 90, 26 }, { 0, 560, 120, 40 },
		{ -520, 215, 70, 18 }, { 560, 160, 75, 24 }, { -170, -330, 90, 22 }, { 190, -340, 80, 18 } }) do
		local center = hubAt(spec[1], spec[2])
		local near = math.abs(center.X) < keep + spec[3] + 12 and math.abs(center.Z) < keep + spec[3] + 12
		if not (shared and near) then
			island(center, spec[3], 8)
			terrain:FillBall(center + Vector3.new(0, spec[4] * 0.2, 0), spec[4], Enum.Material.Grass)
			terrain:FillBall(center + Vector3.new(spec[3] * 0.35, spec[4] * 0.05, spec[3] * 0.2), spec[4] * 0.7, Enum.Material.Rock)
		end
	end
	-- The city across the bay stands on its own island.
	island(CITY_CENTER, 200, 20)
	pcall(function() terrain.Decoration = true end)
end

--------------------------------------------------------------------------------
-- The hub: a paved island in the moat, the raised hero plaza where everyone
-- spawns, four bridges with gates, and the ring road that ties the areas.
--------------------------------------------------------------------------------
function World:BuildHeroesHub(lobby)
	local V = Vector3.new
	local hq = Instance.new("Model")
	hq.Name, hq.Parent = "HeroesHQ", lobby
	self.hq = hq
	local metal, pave = Enum.Material.Metal, Enum.Material.Pavement
	-- Hub deck, its white lip and the glowing waterline.
	Kit.disc(hq, "HubDeck", HUB + V(0, GROUND_Y - 1.5, 0), LAYOUT.hubDeck * 2, 3, HQ.stone, pave, true).CastShadow = true
	Kit.disc(hq, "HubCoping", HUB + V(0, GROUND_Y - 0.35, 0), LAYOUT.hubDeck * 2 + 2, 0.5, HQ.trim, Enum.Material.SmoothPlastic, true)
	Kit.disc(hq, "HubWaterline", HUB + V(0, GROUND_Y - 0.9, 0), LAYOUT.hubDeck * 2 + 3.2, 0.3, HQ.cyan, Enum.Material.Neon)
	-- A darker paving band rings the square.
	Kit.disc(hq, "HubBand", HUB + V(0, GROUND_Y - 0.02, 0), 122, 0.1, HQ.stoneDark, pave, true)
	Kit.disc(hq, "HubInner", HUB + V(0, GROUND_Y + 0.01, 0), 116, 0.1, HQ.stone, pave, true)
	-- The raised hero plaza: a steel plinth, a band of light, a pale deck.
	Kit.disc(hq, "PlazaBase", HUB + V(0, GROUND_Y + 0.4, 0), 71, 0.8, HQ.steel, metal, true).CastShadow = true
	Kit.disc(hq, "PlazaGlow", HUB + V(0, 1.2, 0), 70.6, 0.2, HQ.cyan, Enum.Material.Neon)
	Kit.disc(hq, "PlazaDeck", HUB + V(0, PLAZA_Y - 0.1, 0), 71, 0.2, HQ.stoneWarm, pave, true)
	Kit.disc(hq, "PlazaRing", HUB + V(0, PLAZA_Y + 0.02, 0), 46, 0.1, HQ.navy, Enum.Material.SmoothPlastic, true)
	Kit.disc(hq, "PlazaRingInner", HUB + V(0, PLAZA_Y + 0.05, 0), 42, 0.1, HQ.stone, pave, true)
	Kit.disc(hq, "PlazaStarDisc", HUB + V(0, PLAZA_Y + 0.11, 0), 20, 0.1, HQ.navy, Enum.Material.SmoothPlastic, true)
	-- Everyone arrives standing on the hero star.
	Kit.disc(hq, "HeroStarHalo", HUB + V(0, PLAZA_Y + 0.12, 0), 21.2, 0.04, HQ.cyan, Enum.Material.Neon)
	-- A deeper gold than the HUD's: in the lobby's bright light the plain one burns
	-- out to flat yellow, and a tip near the camera then fills the screen.
	Kit.star(hq, "HeroStar", HUB + V(0, PLAZA_Y + 0.18, 0), V(1, 0, 0), V(0, 0, 1), 8.5, Color3.fromRGB(176, 128, 36), Enum.Material.SmoothPlastic, 0.1)
	for i = 0, 7 do
		local a = i * math.pi / 4 + math.pi / 8
		local dir = V(math.cos(a), 0, math.sin(a))
		local from, to = HUB + dir * 11.5 + V(0, PLAZA_Y + 0.12, 0), HUB + dir * 20.5 + V(0, PLAZA_Y + 0.12, 0)
		Kit.beam(hq, "PlazaRay", from, to, 0.5, 0.06, HQ.cyan, Enum.Material.Neon)
	end
	-- Stairs down from the plaza on the four compass lines.
	for _, dir in ipairs({ V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1) }) do
		Kit.stairs(hq, HUB + dir * 35.5, dir, 14, PLAZA_Y, GROUND_Y, 2)
	end
	-- The big games' yellow corner marks frame the square around the plaza,
	-- and lit lines run out along its diagonals.
	Kit.cornerMarks(hq, HUB, 42, 42, HQ.gold, GROUND_Y + 0.05, 0)
	for i = 0, 3 do
		local dir = V(math.cos(i * math.pi / 2 + math.pi / 4), 0, math.sin(i * math.pi / 2 + math.pi / 4))
		Kit.beam(hq, "DeckLine", HUB + dir * 38 + V(0, GROUND_Y + 0.04, 0), HUB + dir * 55 + V(0, GROUND_Y + 0.04, 0), 0.6, 0.08, HQ.cyan, Enum.Material.Neon)
	end
	-- The glass fence along the quay, open where the four bridges leave.
	local gap = 0.14
	for q = 0, 3 do
		local a0, a1 = q * math.pi / 2 + gap, (q + 1) * math.pi / 2 - gap
		Kit.fence(hq, Kit.arcPoints(HUB, LAYOUT.hubDeck - 1.2, a0, a1, 6, GROUND_Y), 4, HQ.glow)
	end
	-- Four bridges over the moat, each ending in a lit gate.
	local gates = {
		{ dir = V(0, 0, -1), pt = "CAMPANHA", en = "CAMPAIGN", color = Color3.fromRGB(90, 230, 170) },
		{ dir = V(1, 0, 0), pt = "ARENA", en = "ARENA", color = Color3.fromRGB(255, 150, 70) },
		{ dir = V(-1, 0, 0), pt = "ZONA AFK", en = "AFK ZONE", color = Color3.fromRGB(120, 200, 255) },
		{ dir = V(0, 0, 1), pt = "TORRE • LOJA", en = "TOWER • SHOP", color = HQ.gold },
	}
	for _, gate in ipairs(gates) do
		local dir = gate.dir
		local right = V(-dir.Z, 0, dir.X)
		local a, b = HUB + dir * (LAYOUT.hubDeck - 4), HUB + dir * (LAYOUT.moat + 5)
		Kit.beam(hq, "BridgeDeck", a + V(0, GROUND_Y - 0.4, 0), b + V(0, GROUND_Y - 0.4, 0), 14, 1, HQ.stone, pave, true):SetAttribute("BridgeId", gate.en)
		for _, side in ipairs({ -1, 1 }) do
			local sa, sb = a + dir * 4 + right * side * 7.4, b + right * side * 7.4
			Kit.beam(hq, "BridgeBeam", sa + V(0, GROUND_Y - 1.4, 0), sb + V(0, GROUND_Y - 1.4, 0), 1.4, 2.2, HQ.steel, metal, true)
			Kit.fence(hq, { sa + V(0, GROUND_Y + 0.1, 0), sb + V(0, GROUND_Y + 0.1, 0) }, 3, gate.color)
			-- The gate at the far end of the bridge.
			local foot = b - dir * 1 + right * side * 8.6
			Kit.block(hq, "GatePillar", V(2, 12, 2), CFrame.new(foot + V(0, GROUND_Y + 6, 0)), HQ.navy, metal, true).CastShadow = true
			Kit.block(hq, "GateLight", V(0.4, 9, 0.4), CFrame.new(foot - dir * 1.05 + V(0, GROUND_Y + 6, 0)), gate.color, Enum.Material.Neon)
			Kit.blob(hq, "GateOrb", V(1.8, 1.8, 1.8), CFrame.new(foot + V(0, GROUND_Y + 13.9, 0)), gate.color, Enum.Material.Neon)
		end
		local top = b - dir * 1 + V(0, GROUND_Y + 12.4, 0)
		local lintel = Kit.block(hq, "GateLintel", V(19.6, 2.2, 2.4), CFrame.lookAt(top, top - dir), HQ.navy, metal)
		Kit.block(hq, "GateTrim", V(19.8, 0.4, 2.6), CFrame.lookAt(top - V(0, 1.3, 0), top - V(0, 1.3, 0) - dir), gate.color, Enum.Material.Neon)
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face, gui.LightInfluence = "GateSign", Enum.NormalId.Front, 0
		gui.SizingMode, gui.PixelsPerStud, gui.Parent = Enum.SurfaceGuiSizingMode.PixelsPerStud, 24, lintel
		local text = Instance.new("TextLabel")
		text.Name, text.BackgroundTransparency, text.Size, text.Font, text.TextScaled = "Title", 1, UDim2.fromScale(1, 1), Enum.Font.LuckiestGuy, true
		text.TextColor3, text.Text, text.Parent = gate.color:Lerp(HQ.white, 0.4), gate.pt, gui
		text:SetAttribute("LobbyTextPT", gate.pt); text:SetAttribute("LobbyTextEN", gate.en)
		local back = gui:Clone()
		back.Face, back.Parent = Enum.NormalId.Back, lintel
	end
	-- The ring road around the moat: every area opens onto it.
	local inner, outer = LAYOUT.ringRoad[1], LAYOUT.ringRoad[2]
	local segments = 36
	for i = 0, segments - 1 do
		local a = (i + 0.5) * math.pi * 2 / segments
		local center = polar(math.deg(a), (inner + outer) / 2, GROUND_Y - 0.75)
		local length = 2 * outer * math.sin(math.pi / segments) + 0.4
		local frame = CFrame.new(center) * CFrame.Angles(0, -a, 0)
		Kit.block(hq, "RingRoad", V(outer - inner, 1.5, length), frame, Color3.fromRGB(132, 142, 164), pave, true)
		-- Lit edges, like the big games' glowing streets.
		for _, side in ipairs({ -1, 1 }) do
			Kit.block(hq, "RoadGlow", V(0.5, 0.06, length - 0.3), frame * CFrame.new(side * ((outer - inner) / 2 - 0.6), 0.78, 0), HQ.cyan, Enum.Material.Neon)
		end
	end
	return hq
end

-- Paved floors the areas stand on: a slab with a white edge.
function World:AreaFloor(parent, name, cx, cz, width, depth, yaw, color, material)
	local frame = CFrame.new(cx, GROUND_Y - 0.75, cz) * CFrame.Angles(0, yaw or 0, 0)
	local floor = Kit.block(parent, name, Vector3.new(width, 1.5, depth), frame, color or HQ.stone, material or Enum.Material.Pavement, true)
	Kit.block(parent, name .. "Edge", Vector3.new(width + 1.2, 1.2, depth + 1.2), frame * CFrame.new(0, -0.35, 0), HQ.trim, Enum.Material.SmoothPlastic, true)
	return floor
end

--------------------------------------------------------------------------------
-- Landmarks: the hero beacon on the plaza (with the parkour spiral), the
-- Avengers tower over the north road, two golden statues at the south bridge.
--------------------------------------------------------------------------------
function World:BuildHeroBeacon(lobby)
	local V = Vector3.new
	local model = Instance.new("Model")
	model.Name, model.Parent = "HeroBeacon", lobby
	-- Far enough south that the lobby camera, which starts 23 studs behind the spawn,
	-- is not inside the spinning orbits: their gold neon swept across the first view.
	local base = HUB + V(0, PLAZA_Y, 46)
	Kit.disc(model, "BeaconStep", base + V(0, 0.6, 0), 16, 1.2, HQ.steel, Enum.Material.Metal, true)
	Kit.disc(model, "BeaconStepGlow", base + V(0, 1.3, 0), 15.4, 0.2, HQ.cyan, Enum.Material.Neon)
	Kit.disc(model, "BeaconStepTop", base + V(0, 1.6, 0), 16, 0.4, HQ.stoneWarm, Enum.Material.Pavement, true)
	local pillar = Kit.column(model, "BeaconPillar", base + V(0, 1.8, 0), 8.5, 3.2, HQ.navy, Enum.Material.Metal, true)
	pillar.CastShadow = true
	for i = 0, 3 do
		local a = i * math.pi / 2
		Kit.block(model, "BeaconStrip", V(0.3, 7.6, 0.3), CFrame.new(base + V(math.cos(a) * 1.65, 5.8, math.sin(a) * 1.65)), HQ.cyan, Enum.Material.Neon)
	end
	Kit.disc(model, "BeaconCup", base + V(0, 10.6, 0), 7.5, 0.8, HQ.gold, Enum.Material.Metal)
	-- The hologram of the Earth: a glass ocean over a bright core, green
	-- continents turning with it inside two tilted orbits.
	local center = base + V(0, 16.2, 0)
	local globe = Kit.block(model, "BeaconGlobe", V(10, 10, 10), CFrame.new(center), Color3.fromRGB(70, 170, 255), Enum.Material.Glass)
	globe.Shape, globe.Transparency, globe.Reflectance = Enum.PartType.Ball, 0.25, 0.2
	Kit.animate(globe, 0.3, 0)
	local core = Kit.block(model, "BeaconCore", V(8, 8, 8), CFrame.new(center), Color3.fromRGB(60, 150, 255), Enum.Material.Neon)
	core.Shape, core.Transparency = Enum.PartType.Ball, 0.35
	Kit.light(core, HQ.cyan, 32, 1.5)
	for _, spec in ipairs({ { 0.4, 0.5, 3.6, 2.8 }, { 2.3, -0.3, 3.1, 2.2 }, { 4.0, 0.8, 2.5, 3.3 }, { 5.3, -0.9, 2.2, 1.7 }, { 1.2, 1.2, 2, 1.4 } }) do
		local dir = V(math.cos(spec[1]) * math.cos(spec[2]), math.sin(spec[2]), math.sin(spec[1]) * math.cos(spec[2]))
		local land = Kit.blob(model, "BeaconLand", V(spec[3], spec[4], 0.9), CFrame.lookAt(center + dir * 4.7, center + dir * 6), Color3.fromRGB(110, 235, 140), Enum.Material.Neon)
		Kit.animate(land, 0.3, 0, center)
	end
	for ring = 1, 2 do
		local tilt = CFrame.new(center) * CFrame.Angles(ring == 1 and 0.5 or -0.35, ring * 1.2, ring == 1 and 0.2 or -0.4)
		local radius = ring == 1 and 7.4 or 6.6
		for i = 0, 15 do
			local angle = i * math.pi * 2 / 16
			local segment = Kit.block(model, "BeaconOrbit", V(2 * radius * math.sin(math.pi / 16) + 0.05, 0.35, 0.35),
				tilt * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius, 0), ring == 1 and HQ.gold or HQ.glow, Enum.Material.Neon)
			Kit.animate(segment, ring == 1 and 0.6 or -0.45, 0, center)
		end
	end
	emitter(core, HQ.cyan, 5, 2, 0.5, 2.2, V(0, 1.5, 0))
	-- The parkour: seven floating stones spiral up around the beacon; the
	-- last, golden one is the goal (World:ParkourReached).
	for i = 1, 7 do
		local a = math.rad(200 + (i - 1) * 50)
		local at = base + V(math.cos(a) * 10.5, 2.8 + i * 2.35, math.sin(a) * 10.5)
		local stone = Kit.disc(model, "JumpStone", at, 5, 1, i == 7 and HQ.gold or HQ.stoneDark, i == 7 and Enum.Material.Metal or Enum.Material.Slate, true)
		Kit.disc(model, "JumpGlow", at - V(0, 0.6, 0), 5.4, 0.12, i == 7 and HQ.gold or HQ.cyan, Enum.Material.Neon)
		if i == 7 then
			self.parkourGoal = at
			label(stone, "PARKOUR ★", V(0, 3.4, 0), HQ.gold, 140, 40)
		end
	end
	return model
end

-- The tower: a podium the north road passes through, a glass shaft with lit
-- floors, a landing deck and the hero emblem near the top. Seen from
-- everywhere on the island.
function World:BuildHeroTower(lobby)
	local V = Vector3.new
	local model = Instance.new("Model")
	model.Name, model.Parent = "HeroTower", lobby
	local base = LAYOUT.tower + V(0, GROUND_Y, 0)
	local glass = Color3.fromRGB(96, 170, 220)
	-- Podium: two wings and a bridge over the passage.
	for _, side in ipairs({ -1, 1 }) do
		Kit.block(model, "PodiumWing", V(18, 12, 30), CFrame.new(base + V(side * 17, 6, 0)), HQ.stone, Enum.Material.Concrete, true).CastShadow = true
		Kit.block(model, "PodiumGlass", V(16, 7, 0.4), CFrame.new(base + V(side * 17, 5.5, -15.1)), glass, Enum.Material.Glass)
		Kit.block(model, "PodiumTrim", V(18.4, 0.6, 30.4), CFrame.new(base + V(side * 17, 12.2, 0)), HQ.navy, Enum.Material.Metal, true)
		Kit.block(model, "ArchLight", V(0.4, 9.5, 0.4), CFrame.new(base + V(side * 8.2, 4.8, -15.2)), HQ.gold, Enum.Material.Neon)
	end
	Kit.block(model, "PodiumBridge", V(16, 5, 30), CFrame.new(base + V(0, 12, 0)), HQ.stone, Enum.Material.Concrete, true).CastShadow = true
	Kit.block(model, "ArchLintel", V(16.4, 0.5, 0.4), CFrame.new(base + V(0, 9.4, -15.2)), HQ.gold, Enum.Material.Neon)
	-- The shaft: three stacked volumes, each a little slimmer, with lit floors.
	local y = 14.5
	for level, spec in ipairs({ { 30, 34, 22 }, { 24, 30, 18 }, { 18, 24, 14 } }) do
		local w, h, d = spec[1], spec[2], spec[3]
		local x = level == 3 and 2 or 0
		local body = Kit.block(model, "TowerShaft", V(w, h, d), CFrame.new(base + V(x, y + h / 2, level * 1.5)), glass, Enum.Material.Glass)
		body.Reflectance, body.CastShadow = 0.25, true
		for f = 1, math.floor(h / 6) do
			Kit.block(model, "TowerFloor", V(w + 0.3, 0.45, d + 0.3), CFrame.new(base + V(x, y + f * 6 - 0.5, level * 1.5)), HQ.trim, Enum.Material.SmoothPlastic)
		end
		Kit.block(model, "TowerFin", V(1.2, h, 1.2), CFrame.new(base + V(x - w / 2 - 0.4, y + h / 2, level * 1.5 - d / 2)), HQ.navy, Enum.Material.Metal)
		Kit.block(model, "TowerFinLight", V(0.3, h - 2, 0.3), CFrame.new(base + V(x + w / 2 + 0.2, y + h / 2, level * 1.5 - d / 2 - 0.2)), HQ.cyan, Enum.Material.Neon)
		y += h
	end
	-- The landing deck juts out toward the island with a Quinjet pad light.
	local deck = base + V(-4, y - 8, -18)
	Kit.disc(model, "LandingDeck", deck, 18, 1.2, HQ.steel, Enum.Material.Metal)
	Kit.disc(model, "LandingRing", deck + V(0, 0.65, 0), 15, 0.1, HQ.gold, Enum.Material.Neon)
	Kit.block(model, "LandingArm", V(5, 1.2, 12), CFrame.new(deck + V(0, 0, 8)), HQ.steel, Enum.Material.Metal)
	-- Crown and spire with a warning light.
	Kit.block(model, "TowerCrown", V(20, 3, 16), CFrame.new(base + V(2, y + 1.5, 4.5)), HQ.navy, Enum.Material.Metal)
	Kit.column(model, "TowerSpire", base + V(2, y + 3, 4.5), 22, 1.2, HQ.trim, Enum.Material.Metal)
	Kit.animate(Kit.block(model, "SpireLight", V(1.6, 1.6, 1.6), CFrame.new(base + V(2, y + 25.6, 4.5)), Color3.fromRGB(255, 70, 70), Enum.Material.Neon), 0, 0.3)
	-- The hero emblem on the shaft's face: a giant star shield.
	local emblemAt = CFrame.lookAt(base + V(0, 60, -6.35), base + V(0, 60, -40))
	Kit.disc(model, "TowerEmblemRing", emblemAt.Position, 16, 0.6, HQ.trim, Enum.Material.Metal).CFrame = emblemAt * CFrame.Angles(0, math.pi / 2, 0)
	Kit.disc(model, "TowerEmblemField", emblemAt.Position, 13, 0.7, Color3.fromRGB(30, 80, 170), Enum.Material.SmoothPlastic).CFrame = emblemAt * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, math.pi / 2, 0)
	Kit.star(model, "TowerEmblemStar", emblemAt.Position + emblemAt.LookVector * 0.5, emblemAt.RightVector, emblemAt.UpVector, 5.6, HQ.white, Enum.Material.Neon, 0.3)
	-- The tower's name runs along the podium bridge over the road.
	local nameplate = Kit.block(model, "TowerNameplate", V(15.6, 3.6, 0.3), CFrame.new(base + V(0, 12, -15.2)), HQ.navy, Enum.Material.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.LightInfluence = "Nameplate", Enum.NormalId.Front, 0
	gui.SizingMode, gui.PixelsPerStud, gui.Parent = Enum.SurfaceGuiSizingMode.PixelsPerStud, 30, nameplate
	local title = Instance.new("TextLabel")
	title.Name, title.BackgroundTransparency, title.Size, title.Font, title.TextScaled = "Title", 1, UDim2.fromScale(1, 1), Enum.Font.LuckiestGuy, true
	title.TextColor3, title.Text, title.Parent = HQ.gold, "TORRE DOS HERÓIS", gui
	title:SetAttribute("LobbyTextPT", "TORRE DOS HERÓIS"); title:SetAttribute("LobbyTextEN", "HEROES TOWER")
	-- The Robux kiosks' title floats over the left row of stands.
	Kit.floatText(model, "StarkShopTitle", V(HUB.X - 27, GROUND_Y + 12.5, HUB.Z + LAYOUT.kioskDz), "LOJA VOLT", "VOLT SHOP", HQ.gold, 26)
	return model
end

-- Two founding heroes, larger than life in their own colours, greet
-- everyone at the south bridge from gold-trimmed pedestals with name plaques.
function World:BuildHeroStatues(lobby)
	local V = Vector3.new
	local model = Instance.new("Model")
	model.Name, model.Parent = "HeroStatues", lobby
	for _, spec in ipairs({ { "ironman", -15 }, { "captain", 15 } }) do
		local foot = V(HUB.X + spec[2], GROUND_Y, HUB.Z - 55)
		Kit.disc(model, "StatueBase", foot + V(0, 1.2, 0), 9, 2.4, HQ.navy, Enum.Material.Metal, true)
		Kit.disc(model, "StatueGlow", foot + V(0, 2.5, 0), 8.4, 0.2, HQ.gold, Enum.Material.Neon)
		Kit.disc(model, "StatueTop", foot + V(0, 2.8, 0), 9, 0.4, HQ.gold, Enum.Material.Metal, true)
		local hero = self.catalog.Heroes[spec[1]]
		-- The plaque faces the plaza.
		local plaque = Kit.block(model, "StatuePlaque", V(5.4, 1.3, 0.3), CFrame.new(foot + V(0, 1.3, 4.45)), HQ.gold, Enum.Material.Metal)
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face, gui.LightInfluence = "Plaque", Enum.NormalId.Back, 0
		gui.SizingMode, gui.PixelsPerStud, gui.Parent = Enum.SurfaceGuiSizingMode.PixelsPerStud, 40, plaque
		local text = Instance.new("TextLabel")
		text.Name, text.BackgroundTransparency, text.Size, text.Font, text.TextScaled = "Title", 1, UDim2.fromScale(1, 1), Enum.Font.LuckiestGuy, true
		text.TextColor3, text.Text, text.Parent = HQ.navy, upper(hero.name.pt), gui
		text:SetAttribute("LobbyTextPT", upper(hero.name.pt)); text:SetAttribute("LobbyTextEN", upper(hero.name.en))
		local figure = Instance.new("Model")
		figure.Name, figure.Parent = "Statue_" .. spec[1], model
		-- The statue looks toward the plaza where everyone arrives.
		staticFigure(figure, spec[1], hero, CFrame.new(foot + V(0, 3, 0)) * CFrame.Angles(0, math.pi, 0), 2.4)
		for _, item in ipairs(figure:GetDescendants()) do
			if item:IsA("BasePart") then item.CastShadow = item.Size.Magnitude > 3 end
		end
	end
	return model
end

--------------------------------------------------------------------------------
-- Service desks around the hub: the guide with Nico, maps, team, bases, the
-- academy, and the two notice boards. Each is a small lit kiosk facing the
-- plaza.
--------------------------------------------------------------------------------
function World:BuildServiceDesks(lobby)
	local V = Vector3.new
	local scene = Instance.new("Model")
	scene.Name, scene.Parent = "HubServices", lobby
	local function localized(target, pt, en) target:SetAttribute("LobbyTextPT", pt); target:SetAttribute("LobbyTextEN", en) end
	local function kiosk(center, facing, color)
		local frame = CFrame.new(center) * CFrame.Angles(0, facing, 0)
		Kit.block(scene, "DeskBody", V(9, 2.6, 3.2), frame * CFrame.new(0, 1.3 + GROUND_Y, 0), HQ.navy, Enum.Material.Metal, true)
		Kit.block(scene, "DeskTop", V(9.6, 0.4, 3.8), frame * CFrame.new(0, 2.8 + GROUND_Y, 0), HQ.trim, Enum.Material.SmoothPlastic, true)
		Kit.block(scene, "DeskStripe", V(8.4, 0.4, 0.2), frame * CFrame.new(0, 1.9 + GROUND_Y, 1.7), color, Enum.Material.Neon)
		for _, side in ipairs({ -1, 1 }) do
			Kit.block(scene, "DeskPost", V(0.6, 9, 0.6), frame * CFrame.new(side * 4.6, 4.5 + GROUND_Y, -1.6), HQ.steel, Enum.Material.Metal)
		end
		Kit.block(scene, "DeskCanopy", V(11, 0.6, 5), frame * CFrame.new(0, 9.2 + GROUND_Y, -0.2) * CFrame.Angles(-0.12, 0, 0), color:Lerp(HQ.navy, 0.35), Enum.Material.SmoothPlastic)
		Kit.block(scene, "DeskCanopyGlow", V(11.2, 0.25, 0.3), frame * CFrame.new(0, 8.95 + GROUND_Y, 2.2), color, Enum.Material.Neon)
		return frame
	end
	-- A big icon floats and bobs over every desk, readable from the plaza.
	local function icon(frame, glyph)
		local anchor = Kit.block(scene, "DeskIcon", Vector3.new(1, 1, 1), frame * CFrame.new(0, 12.6 + GROUND_Y, -0.2), HQ.white)
		anchor.Transparency = 1
		Kit.animate(anchor, 0, 0.45)
		local gui = Instance.new("BillboardGui")
		gui.Name, gui.Size, gui.LightInfluence, gui.MaxDistance, gui.Parent = "Icon", UDim2.fromScale(4.2, 4.2), 0, 160, anchor
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency, text.Size, text.TextScaled, text.Text, text.Parent = 1, UDim2.fromScale(1, 1), true, glyph, gui
	end
	local glyphs = { guide = "🤖", maps = "🗺️", inventory = "🦸", bases = "🛡️", talents = "🎓", quests = "📜", leaderboard = "🏆" }
	-- A desk's local +Z looks at the hub.
	for _, def in ipairs(LAYOUT.services) do
		local at = polar(def.angle, 54, 0)
		local frame = kiosk(at, yawToward(at, HUB), def.color)
		local board, text = buildBoard(lobby, at.X, at.Z, def.id, def.pt, self.openPanel)
		local panel = board.PrimaryPart
		local post = board:FindFirstChild("Post")
		if post then post:Destroy() end
		panel.CFrame = frame * CFrame.new(0, 6.2 + GROUND_Y, -1.2) * CFrame.Angles(0, math.pi, 0)
		panel.Color, panel.Material = HQ.navy, Enum.Material.Metal
		text.TextScaled, text.RichText, text.TextSize = false, true, 36
		local tint = string.format('<font color="#%02x%02x%02x">', math.floor(def.color.R * 255), math.floor(def.color.G * 255), math.floor(def.color.B * 255))
		local how = '</font>\n<font size="17" color="#b8cdd8">'
		localized(text, tint .. def.pt .. how .. "TOQUE OU PRESSIONE E</font>", tint .. def.en .. how .. "TAP OR PRESS E</font>")
		text.Text = text:GetAttribute("LobbyTextPT")
		local prompt = panel:FindFirstChildOfClass("ProximityPrompt")
		if prompt then localized(prompt, def.pt, def.en) end
		if def.id == "guide" then self.guideDesk = frame end
		icon(frame, glyphs[def.id] or "⭐")
	end
	-- The two public boards: missions and the hall of fame.
	for _, id in ipairs({ "quests", "leaderboard" }) do
		local at = polar(LAYOUT.boards[id], 54, 0)
		local frame = kiosk(at, yawToward(at, HUB), id == "quests" and Color3.fromRGB(143, 208, 122) or HQ.gold)
		icon(frame, glyphs[id])
		local board, text = buildBoard(lobby, at.X, at.Z, id, id == "quests" and "MISSÕES" or "SALÃO DA FAMA\nCarregando…", self.openPanel)
		local post = board:FindFirstChild("Post")
		if post then post:Destroy() end
		board.PrimaryPart.CFrame = frame * CFrame.new(0, 6.2 + GROUND_Y, -1.2) * CFrame.Angles(0, math.pi, 0)
		board.PrimaryPart.Color, board.PrimaryPart.Material = HQ.navy, Enum.Material.Metal
		if id == "quests" then
			text.TextScaled, text.RichText, text.TextSize = false, true, 36
			text:SetAttribute("LobbyTextPT", '<font color="#8fd07a">MISSÕES</font>\n<font size="17" color="#b8cdd8">TOQUE OU PRESSIONE E</font>')
			text:SetAttribute("LobbyTextEN", '<font color="#8fd07a">MISSIONS</font>\n<font size="17" color="#b8cdd8">TAP OR PRESS E</font>')
			text.Text = text:GetAttribute("LobbyTextPT")
		else
			self.leaderboardText = text
		end
	end
	-- Nico, the HQ's little caretaker robot, beside the guide desk. Its prompt
	-- is the guide desk's prompt; there is only one tap target.
	local origin = (self.guideDesk or CFrame.new(HUB)) * CFrame.new(6.5, GROUND_Y, 1.5) * CFrame.Angles(0, math.pi + 0.3, 0)
	local wood, pale, green = Color3.fromRGB(104, 72, 46), Color3.fromRGB(231, 213, 173), Color3.fromRGB(63, 109, 96)
	local smooth = Enum.Material.SmoothPlastic
	for _, side in ipairs({ -1, 1 }) do
		Kit.blob(scene, "GuideBoot", V(0.9, 0.6, 1.3), origin * CFrame.new(side * 0.5, 0.35, -0.1), wood, smooth)
		Kit.blob(scene, "GuideArm", V(0.55, 1.45, 0.6), origin * CFrame.new(side * 1.15, 1.9, 0) * CFrame.Angles(0, 0, side * 0.2), pale, smooth)
		Kit.blob(scene, "GuideHand", V(0.62, 0.62, 0.62), origin * CFrame.new(side * 1.3, 1.15, 0), green, smooth)
		Kit.blob(scene, "GuideEar", V(0.32, 0.66, 0.66), origin * CFrame.new(side * 1.1, 3.55, 0), ART.gold, smooth)
		Kit.blob(scene, "GuideEye", V(0.3, 0.36, 0.1), origin * CFrame.new(side * 0.36, 3.58, -0.84), Color3.fromRGB(158, 237, 197), Enum.Material.Neon)
	end
	Kit.blob(scene, "GuideBody", V(1.9, 2.1, 1.4), origin * CFrame.new(0, 1.75, 0), green, smooth)
	Kit.blob(scene, "GuidePanel", V(1.1, 0.9, 0.3), origin * CFrame.new(0, 1.6, -0.62), pale, smooth)
	Kit.blob(scene, "GuideScarf", V(1.95, 0.45, 1.45), origin * CFrame.new(0, 2.72, 0), ART.gold, smooth)
	Kit.blob(scene, "GuideHead", V(2.2, 1.6, 1.7), origin * CFrame.new(0, 3.55, 0), pale, smooth)
	Kit.blob(scene, "GuideVisor", V(1.6, 0.8, 0.5), origin * CFrame.new(0, 3.58, -0.62), Color3.fromRGB(29, 50, 47), Enum.Material.Glass)
	Kit.block(scene, "GuideAntenna", V(0.13, 0.8, 0.13), origin * CFrame.new(0.7, 4.5, 0), wood, Enum.Material.Metal)
	local tip = Kit.block(scene, "GuideAntennaTip", V(0.35, 0.35, 0.35), origin * CFrame.new(0.7, 4.95, 0), ART.gold, Enum.Material.Neon)
	tip.Shape = Enum.PartType.Ball
	Kit.animate(tip, 0, 0.15)
	-- Benches with real seats face the plaza between the desks.
	for _, angle in ipairs({ 90 - 16, 90 + 16, 270 - 16 }) do
		local at = polar(angle, 60, GROUND_Y)
		local frame = CFrame.new(at) * CFrame.Angles(0, yawToward(at, HUB), 0)
		local seat = Instance.new("Seat")
		seat.Name, seat.Size, seat.CFrame = "HubSeat", V(6, 0.45, 2), frame * CFrame.new(0, 1.9, 0) * CFrame.Angles(0, math.pi, 0)
		seat.Anchored, seat.Material, seat.Color, seat.Parent = true, Enum.Material.WoodPlanks, wood, scene
		Kit.block(scene, "BenchBack", V(6, 1.8, 0.4), frame * CFrame.new(0, 3, -1), wood, Enum.Material.WoodPlanks, true)
		for _, x in ipairs({ -2.4, 2.4 }) do Kit.block(scene, "BenchLeg", V(0.5, 1.7, 1.8), frame * CFrame.new(x, 0.85, 0), HQ.steel, Enum.Material.Metal, true) end
	end
	return scene
end

--------------------------------------------------------------------------------
-- The areas around the ring road.
--------------------------------------------------------------------------------
local function floorOf(id)
	local f = LAYOUT.floors[id]
	return hubAt(f[1], f[2]), f[3], f[4]
end
World.LobbyFloor = function(id)
	local center, width, depth = floorOf(id)
	return center, width, depth
end

function World:BuildCampaignTerrace(hq)
	local V = Vector3.new
	local c, width, depth = floorOf("campaign")
	self:AreaFloor(hq, "CampaignTerrace", c.X, c.Z, width, depth)
	local backZ = c.Z - depth / 2 + 0.6
	local back = {}
	for i = 0, 8 do table.insert(back, V(c.X - 62 + i * 15.5, GROUND_Y, backZ)) end
	Kit.fence(hq, back, 3.4, Color3.fromRGB(120, 240, 190))
	Kit.sign(hq, "CampaignSign", CFrame.lookAt(V(c.X, 38, backZ - 4.6), V(c.X, 38, HUB.Z)), 58, 18, {
		title = { "CAMPANHA", "CAMPAIGN" }, subtitle = { "SALVE MANHATTAN • GAMA • FUNDIÇÃO", "SAVE MANHATTAN • GAMMA • FOUNDRY" },
		top = Color3.fromRGB(90, 215, 255), bottom = Color3.fromRGB(30, 110, 170), accent = Color3.fromRGB(90, 230, 170),
		art = "skyline", artX = 0.5, artY = 0.62, artW = 0.96, artH = 0.62, titleY = 0.36, legs = GRASS_Y,
	})
	for _, x in ipairs({ -64, 64 }) do Kit.flag(hq, V(c.X + x, GROUND_Y, backZ + 3.4), 18, Color3.fromRGB(70, 200, 150), 5) end
	for _, x in ipairs({ -21, 21 }) do Kit.lamp(hq, V(c.X + x, GROUND_Y, c.Z + 16.5)) end
	for _, x in ipairs({ -59, 59 }) do Kit.planter(hq, V(c.X + x, GROUND_Y, c.Z - 11.5), 6, true) end
	Kit.cornerMarks(hq, c, width / 2 - 2, depth / 2 - 2, HQ.gold, GROUND_Y + 0.05, 0)
end

function World:BuildArena(lobby, hq)
	local V = Vector3.new
	local c, width, depth = floorOf("arena")
	self:AreaFloor(hq, "ArenaFloor", c.X, c.Z, width, depth, 0, Color3.fromRGB(196, 190, 186))
	local orange = Color3.fromRGB(255, 140, 60)
	local board = Instance.new("Model")
	board.Name, board.Parent = "Scoreboard_arena", lobby
	board:SetAttribute("Kind", "Scoreboard")
	board:SetAttribute("BoardId", "arena")
	-- Raised above the three ranked stations so it reads from the plaza.
	local x, y = c.X + 16, 40 + GROUND_Y
	for _, dz in ipairs({ -27, 27 }) do
		Kit.block(board, "ScoreboardLeg", V(2, y, 2), CFrame.new(x + 1, y / 2, c.Z + dz), HQ.navy, Enum.Material.Metal, true).CastShadow = true
	end
	local panel = part(board, "ScoreboardPanel", V(56, 20, 1.2), CFrame.new(x, y, c.Z) * CFrame.Angles(0, math.pi / 2, 0), HQ.ink, Enum.Material.Metal)
	panel.CastShadow = true
	Kit.block(board, "ScoreboardFrame", V(58, 22, 0.8), CFrame.new(x + 0.9, y, c.Z) * CFrame.Angles(0, math.pi / 2, 0), HQ.navy, Enum.Material.Metal)
	for _, dy in ipairs({ -10.6, 10.6 }) do
		Kit.block(board, "ScoreboardTrim", V(57, 0.6, 1.4), CFrame.new(x - 0.2, y + dy, c.Z) * CFrame.Angles(0, math.pi / 2, 0), orange, Enum.Material.Neon)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.LightInfluence = "Scores", Enum.NormalId.Front, 0
	gui.SizingMode, gui.CanvasSize, gui.Parent = Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(1120, 400), panel
	local title = Instance.new("TextLabel")
	title.Name, title.BackgroundTransparency, title.Size = "Title", 1, UDim2.new(1, 0, 0, 70)
	title.Font, title.TextSize, title.TextColor3, title.Text = Enum.Font.LuckiestGuy, 50, orange, "ARENA COMPETITIVA • PLACAR SOLO"
	title.Parent = gui
	title:SetAttribute("LobbyTextPT", "ARENA COMPETITIVA • PLACAR SOLO"); title:SetAttribute("LobbyTextEN", "COMPETITIVE ARENA • SOLO LEADERBOARD")
	self.arenaColumns = {}
	local maps = {}
	for _, id in ipairs(self.catalog.DestinationOrder) do
		local def = self.catalog.Destinations[id]
		if def.modeId == "ranked" then table.insert(maps, def.mapId) end
	end
	for i, mapId in ipairs(maps) do
		local map = self.catalog.Maps[mapId]
		local column = Instance.new("Frame")
		column.Name, column.BackgroundTransparency = "Column_" .. mapId, 1
		column.Position, column.Size = UDim2.new((i - 1) / #maps, 8, 0, 76), UDim2.new(1 / #maps, -16, 1, -84)
		column.Parent = gui
		local head = Instance.new("TextLabel")
		head.BackgroundTransparency, head.Size, head.Font, head.TextSize = 1, UDim2.new(1, 0, 0, 44), Enum.Font.LuckiestGuy, 34
		head.TextColor3, head.Text, head.Parent = rgb(PORTAL_COLORS[mapId] or map.color), upper(map.name.pt), column
		local rows = Instance.new("TextLabel")
		rows.Name, rows.BackgroundTransparency, rows.Position, rows.Size = "Rows", 1, UDim2.fromOffset(0, 50), UDim2.new(1, 0, 1, -50)
		rows.Font, rows.TextSize, rows.TextColor3 = Enum.Font.GothamBold, 26, Color3.fromRGB(230, 240, 244)
		rows.TextXAlignment, rows.TextYAlignment, rows.Text = Enum.TextXAlignment.Left, Enum.TextYAlignment.Top, "Carregando…"
		rows.Parent = column
		table.insert(self.arenaColumns, { mapId = mapId, label = rows })
	end
	Kit.floatText(board, "ArenaTitle", V(x - 2, y + 17, c.Z), "ARENA COMPETITIVA", "COMPETITIVE ARENA", orange, 44)
	local kiosk = part(board, "ScoreKiosk", V(2.4, 3.4, 4), CFrame.new(c.X - 4, 1.9 + GROUND_Y, c.Z - 48), HQ.navy, Enum.Material.Metal)
	Kit.block(board, "KioskScreen", V(0.2, 2, 3.2), CFrame.new(c.X - 5.3, 2.6 + GROUND_Y, c.Z - 48), orange, Enum.Material.Neon)
	label(kiosk, "PLACAR\nLEADERBOARD", V(0, 3.6, 0), orange, 160, 60)
	board.PrimaryPart = kiosk
	interactable(kiosk, "Placar / Leaderboard", function(player) self.openPanel(player, "leaderboard", { board = "arena" }) end)
	-- Stadium floodlights on the four corners.
	for _, corner in ipairs({ { -19, -52 }, { 20, -52 }, { -19, 52 }, { 20, 52 } }) do
		local foot = V(c.X + corner[1], GROUND_Y, c.Z + corner[2])
		Kit.column(hq, "FloodMast", foot, 30, 1.2, HQ.navy, Enum.Material.Metal)
		local aim = CFrame.lookAt(foot + V(0, 30.5, 0), c)
		local lamp = Kit.block(hq, "FloodLamp", V(5, 3, 1.4), aim, HQ.lamp, Enum.Material.Neon)
		Kit.block(hq, "FloodFrame", V(5.6, 3.6, 1), aim * CFrame.new(0, 0, 0.7), HQ.navy, Enum.Material.Metal)
		Kit.light(lamp, HQ.lamp, 40, 0.8)
	end
	for _, dz in ipairs({ -45, 45 }) do Kit.flag(hq, V(c.X + 21, GROUND_Y, c.Z + dz), 16, orange, 5) end
	Kit.cornerMarks(hq, c, width / 2 - 2, depth / 2 - 2, orange, GROUND_Y + 0.05, 0)
end

function World:BuildAfkLounge(lobby, hq)
	local V = Vector3.new
	local c, width, depth = floorOf("afk")
	self:AreaFloor(hq, "AfkFloor", c.X, c.Z, width, depth, 0, HQ.stoneWarm)
	self.afkZones = {}
	for _, kind in ipairs(self.catalog.AfkOrder or {}) do
		local def = self.catalog.Afk[kind]
		local tint = rgb(def.color)
		local x, z = def.x, def.z
		local model = Instance.new("Model")
		model.Name, model.Parent = "AfkZone_" .. kind, lobby
		model:SetAttribute("Kind", "AfkZone")
		model:SetAttribute("AfkKind", kind)
		local platform = Kit.disc(model, "AfkPlatform", V(x, GROUND_Y + 0.25, z), 22, 0.5, HQ.navy, Enum.Material.Slate, true)
		Kit.disc(model, "AfkRim", V(x, GROUND_Y + 0.2, z), 23, 0.36, tint, Enum.Material.Neon)
		local rune = Kit.disc(model, "AfkRune", V(x, GROUND_Y + 0.55, z), 8, 0.1, tint, Enum.Material.Neon)
		rune.Transparency = 0.35
		-- Open toward the plaza (+X): pillars stand on the diagonals.
		for _, a in ipairs({ math.pi / 4, 3 * math.pi / 4, 5 * math.pi / 4, 7 * math.pi / 4 }) do
			local px, pz = x + math.cos(a) * 10, z + math.sin(a) * 10
			Kit.block(model, "AfkPillar", V(1.3, 11, 1.3), CFrame.new(px, 5.8 + GROUND_Y, pz), HQ.trim, Enum.Material.Marble, true).CastShadow = true
			Kit.block(model, "AfkPillarLight", V(0.25, 9, 0.25), CFrame.new(px + math.cos(a + math.pi) * 0.72, 5.8 + GROUND_Y, pz + math.sin(a + math.pi) * 0.72), tint, Enum.Material.Neon)
		end
		arc(model, "AfkHalo", CFrame.new(x, 11.6 + GROUND_Y, z) * CFrame.Angles(math.pi / 2, 0, 0), 10, 0.7, 0.7, tint, Enum.Material.Neon, 20)
		local icon
		if kind == "gold" then
			icon = Kit.block(model, "AfkIcon", V(0.8, 5, 5), CFrame.new(x, 6 + GROUND_Y, z), tint, Enum.Material.Neon)
			icon.Shape = Enum.PartType.Cylinder
		else
			icon = Kit.block(model, "AfkIcon", V(4.2, 4.2, 4.2), CFrame.new(x, 6 + GROUND_Y, z), tint, Enum.Material.Neon)
			icon.Shape = Enum.PartType.Ball
		end
		emitter(icon, tint, 6, 2.5, 0.6, 1.6, V(0, 3, 0))
		Kit.light(icon, tint, 16, 1)
		label(icon, def.rate.pt, V(0, 4.2, 0), tint, 240, 70)
		-- Seats face the plaza, so resting players watch the island go by.
		for _, dz in ipairs({ -5, 0, 5 }) do
			local seat = Instance.new("Seat")
			seat.Name, seat.Size, seat.CFrame = "AfkSeat", V(3, 0.6, 2.4), CFrame.lookAt(V(x - 6, 1.2 + GROUND_Y, z + dz), V(x + 10, 1.2 + GROUND_Y, z + dz))
			seat.Anchored, seat.Color, seat.Material, seat.CastShadow = true, tint:Lerp(HQ.navy, 0.55), Enum.Material.Fabric, false
			seat.Parent = model
		end
		model.PrimaryPart = platform
		self.afkZones[kind] = { center = V(x, 4 + GROUND_Y, z), size = V(20, 10, 20) }
		Kit.floatText(model, "AfkHeader", V(x - 4, 17 + GROUND_Y, z), upper(def.name.pt), upper(def.name.en), tint, 26)
	end
	Kit.sign(hq, "AfkSign", CFrame.lookAt(V(c.X - 25, 22, c.Z - 1), V(HUB.X, 22, c.Z - 1)), 30, 13, {
		title = { "ZONA AFK", "AFK ZONE" }, subtitle = { "FIQUE PARADO E GANHE", "STAND STILL AND EARN" },
		top = Color3.fromRGB(110, 150, 255), bottom = Color3.fromRGB(40, 50, 140), accent = Color3.fromRGB(120, 200, 255),
		art = "moon", artX = 0.18, artW = 0.3, titleX = 0.6, titleW = 0.72, legs = GROUND_Y,
	})
	-- Palms in round sand beds shade the lounge.
	for _, spot in ipairs({ { -20, -46, 0.4 }, { -19, 42, -0.3 }, { 20, -46, 2.6 }, { -15, -24, 0.1 }, { -15, 20, -0.2 } }) do
		local bed = V(c.X + spot[1], GROUND_Y, c.Z + spot[2])
		Kit.disc(hq, "PalmBed", bed + V(0, 0.2, 0), 5, 0.4, Color3.fromRGB(236, 214, 160), Enum.Material.Sand, true)
		Kit.palm(hq, bed + V(0, 0.4, 0), 1, spot[3]):SetAttribute("Planted", true)
	end
	Kit.cornerMarks(hq, c, width / 2 - 2, depth / 2 - 2, Color3.fromRGB(120, 200, 255), GROUND_Y + 0.05, 0)
end

function World:BuildMarket(lobby, hq)
	local V = Vector3.new
	local chests = { "rare", "base_rare" }
	for i, spec in ipairs(LAYOUT.market) do
		local at = polar(spec[1], spec[2], 0)
		local yaw = yawToward(at, HUB)
		-- The floor reaches past the entry pad toward the ring road.
		local floorAt = at + Vector3.new(math.sin(yaw), 0, math.cos(yaw)) * 3
		self:AreaFloor(hq, "MarketFloor", floorAt.X, floorAt.Z, 34, 40, yaw, HQ.stoneWarm)
		local _, zone = buildChestStand(lobby, at.X, at.Z, chests[i], self.catalog.Chests[chests[i]], self.openPanel, yaw)
		self.shopZones[chests[i]] = zone
	end
	local signAt = polar(137.5, 142, 0)
	Kit.sign(hq, "SummonSign", CFrame.lookAt(signAt + V(0, 34, 0), V(HUB.X, 34, HUB.Z)), 40, 15, {
		title = { "INVOCAÇÃO", "SUMMONING" }, subtitle = { "BAÚS DE HERÓIS E DE BASES", "HERO AND BASE CHESTS" },
		top = Color3.fromRGB(255, 190, 90), bottom = Color3.fromRGB(190, 70, 150), accent = HQ.gold,
		art = "chest", artX = 0.18, artW = 0.32, titleX = 0.62, titleW = 0.72, legs = GRASS_Y,
	})
	-- The Robux kiosks line the tower plaza: the Stark shop.
	local showcase = self.catalog.Heroes.silversurfer
	for index, entry in ipairs(SHOP_STANDS) do
		local pass = entry.kind == "pass" and self.catalog.Products.Passes[entry.key]
		local displayName = pass and pass.name.pt or (entry.kind == "hero" and "Vitrine de Heróis" or "Cofre de Ouro")
		buildShopStand(lobby, HUB.X + LAYOUT.kiosks[index], HUB.Z + LAYOUT.kioskDz, entry.kind, entry.key, displayName, self.openPanel, entry.kind == "hero" and showcase or nil)
	end
end

function World:BuildTowerPlaza(hq)
	local V = Vector3.new
	local p = LAYOUT.towerPlaza
	self:AreaFloor(hq, "TowerPlaza", HUB.X, HUB.Z + (p.dz0 + p.dz1) / 2, p.x * 2, p.dz1 - p.dz0 + 2)
	-- The road runs on through the tower's arch to the north bridge.
	self:AreaFloor(hq, "TowerRoad", HUB.X, LAYOUT.tower.Z + 20, 16, 12)
	for _, x in ipairs({ -44, 44 }) do Kit.lamp(hq, V(HUB.X + x, GROUND_Y, HUB.Z + p.dz0 + 4)) end
	-- An armour display case: a golden suit behind glass at the plaza's end.
	local foot = V(HUB.X + 38, GROUND_Y, HUB.Z + LAYOUT.kioskDz)
	Kit.disc(hq, "SuitPlinth", foot + V(0, 0.6, 0), 6, 1.2, HQ.navy, Enum.Material.Metal, true)
	local case = Kit.block(hq, "SuitCase", V(5.4, 9.5, 5.4), CFrame.new(foot + V(0, 6, 0)), Color3.fromRGB(170, 220, 255), Enum.Material.Glass)
	case.Transparency = 0.7
	Kit.block(hq, "SuitCaseCap", V(6, 0.6, 6), CFrame.new(foot + V(0, 11, 0)), HQ.gold, Enum.Material.Neon)
	local figure = Instance.new("Model")
	figure.Name, figure.Parent = "SuitDisplay", hq
	staticFigure(figure, "ironman", self.catalog.Heroes.ironman, CFrame.new(foot + V(0, 1.2, 0)), 1.2)
	Kit.cornerMarks(hq, V(HUB.X, 0, HUB.Z + (p.dz0 + p.dz1) / 2), p.x - 2, (p.dz1 - p.dz0) / 2 - 1, HQ.gold, GROUND_Y + 0.05, 0)
end

--------------------------------------------------------------------------------
-- S.H.I.E.L.D.: the Quinjet hangar (south-west), the command post (south-
-- east), the armory (north-east), agents on duty, the Helicarrier holding
-- station over the sea and a Quinjet patrolling the island.
--------------------------------------------------------------------------------
-- A Quinjet on frame J (belly at J, nose toward J's +Z). Returns its parts.
local function quinjet(parent, J, gear)
	local V = Vector3.new
	local made = {}
	local jet, steel, pale, white = Color3.fromRGB(42, 46, 56), Color3.fromRGB(98, 110, 124), Color3.fromRGB(196, 204, 212), Color3.fromRGB(236, 240, 244)
	local blue = Color3.fromRGB(84, 156, 232)
	local metal = Enum.Material.Metal
	local function keep(p) table.insert(made, p); return p end
	local function at(x, y, z) return J * CFrame.new(x, y, z) end
	local function pt(x, y, z) return J * V(x, y, z) end
	local function dir(x, y, z) return J * V(x, y, z) - J.Position end
	keep(Kit.blob(parent, "QuinjetHull", V(5.2, 4, 22), at(0, 4.2, -1), jet, metal)).CastShadow = true
	keep(Kit.blob(parent, "QuinjetNose", V(3.8, 2.9, 9), at(0, 3.9, 9.5), jet, metal))
	keep(Kit.blob(parent, "QuinjetSpine", V(2.2, 1.4, 14), at(0, 6, -3), jet:Lerp(pale, 0.15), metal))
	keep(Kit.blob(parent, "QuinjetCanopy", V(3.3, 1.9, 6.4), at(0, 5.6, 6.5), Color3.fromRGB(46, 76, 104), Enum.Material.Glass)).Transparency = 0.15
	for _, side in ipairs({ -1, 1 }) do
		keep(Kit.triangle(parent, "QuinjetWing", pt(side * 2.3, 3.6, -6.5), dir(side * 10.5, 0.9, 0), dir(0, 0, 12.5), 0.5, jet, metal))
		keep(Kit.triangle(parent, "QuinjetFin", pt(side * 1.4, 5.8, -11.6), dir(side * 1.3, 4.6, 0), dir(0, 0, 5.2), 0.35, jet, metal))
		local engine = keep(Kit.block(parent, "QuinjetEngine", V(6, 2.2, 2.2), at(side * 3.6, 3.4, -8) * CFrame.Angles(0, math.pi / 2, 0), steel, metal))
		engine.Shape = Enum.PartType.Cylinder
		local exhaust = keep(Kit.block(parent, "QuinjetExhaust", V(0.12, 1.8, 1.8), at(side * 3.6, 3.4, -11.05) * CFrame.Angles(0, math.pi / 2, 0), blue, Enum.Material.Neon))
		exhaust.Shape = Enum.PartType.Cylinder
		if gear then keep(Kit.column(parent, "QuinjetGear", pt(side * 2.4, 0, -4), 2.2, 0.4, steel, metal)) end
		keep(Kit.blob(parent, "QuinjetStripe", V(0.12, 0.5, 9), at(side * 2.62, 4.4, 1), white))
	end
	if gear then keep(Kit.column(parent, "QuinjetGear", pt(0, 0, 9), 2.2, 0.4, steel, metal)) end
	return made
end

function World:BuildShieldSites(hq)
	local V = Vector3.new
	local outpost = Instance.new("Model")
	outpost.Name, outpost.Parent = "ShieldOutpost", hq
	local navy, steel, pale = HQ.navy, Color3.fromRGB(98, 110, 124), Color3.fromRGB(196, 204, 212)
	local blue, white, yellow = Color3.fromRGB(84, 156, 232), Color3.fromRGB(236, 240, 244), Color3.fromRGB(242, 192, 64)
	local suit = Color3.fromRGB(24, 26, 32)
	local metal, glass = Enum.Material.Metal, Enum.Material.Glass
	local function p(name, size, cf, tint, material) return Kit.block(outpost, name, size, cf, tint, material or Enum.Material.SmoothPlastic) end
	local function plate(name, frame, diameter, thickness, tint, material)
		local made = p(name, V(thickness, diameter, diameter), frame * CFrame.Angles(0, math.pi / 2, 0), tint, material)
		made.Shape = Enum.PartType.Cylinder
		return made
	end
	local function toWorld(frame, v) return frame * v - frame.Position end
	local function emblem(frame, size)
		plate("EmblemRing", frame, size, 0.2, pale, metal)
		plate("EmblemField", frame * CFrame.new(0, 0, -0.08), size * 0.84, 0.2, navy)
		Kit.blob(outpost, "EmblemEagle", V(size * 0.16, size * 0.36, 0.12), frame * CFrame.new(0, size * 0.04, -0.22), white)
		for _, side in ipairs({ -1, 1 }) do
			Kit.triangle(outpost, "EmblemWing", frame * V(side * size * 0.05, size * 0.12, -0.22), toWorld(frame, V(side * size * 0.3, 0, 0)), toWorld(frame, V(0, -size * 0.26, 0)), 0.1, white)
		end
	end
	local SKIN = { Color3.fromRGB(232, 181, 147), Color3.fromRGB(141, 92, 64), Color3.fromRGB(198, 146, 108), Color3.fromRGB(96, 64, 46) }
	local HAIR = { Color3.fromRGB(38, 30, 28), Color3.fromRGB(96, 64, 40), Color3.fromRGB(20, 20, 24), Color3.fromRGB(150, 110, 60) }
	local agents = 0
	local function agent(frame)
		agents += 1
		for _, side in ipairs({ -1, 1 }) do
			Kit.blob(outpost, "AgentLeg", V(0.62, 1.7, 0.66), frame * CFrame.new(side * 0.34, 0.8, 0), suit)
			Kit.blob(outpost, "AgentArm", V(0.5, 1.55, 0.54), frame * CFrame.new(side * 1.02, 2.35, 0) * CFrame.Angles(0, 0, side * 0.12), suit)
		end
		Kit.blob(outpost, "AgentBody", V(1.8, 1.95, 1.1), frame * CFrame.new(0, 2.45, 0), suit)
		Kit.blob(outpost, "AgentShirt", V(0.62, 0.95, 0.3), frame * CFrame.new(0, 2.95, -0.46), white)
		Kit.blob(outpost, "AgentTie", V(0.18, 0.75, 0.12), frame * CFrame.new(0, 2.8, -0.6), navy)
		Kit.blob(outpost, "AgentHead", V(1.26, 1.3, 1.2), frame * CFrame.new(0, 4.05, 0), SKIN[(agents - 1) % #SKIN + 1])
		Kit.blob(outpost, "AgentHair", V(1.32, 0.62, 1.26), frame * CFrame.new(0, 4.5, 0.08), HAIR[(agents - 1) % #HAIR + 1])
		Kit.blob(outpost, "AgentShades", V(1.1, 0.3, 0.26), frame * CFrame.new(0, 4.12, -0.56), Color3.fromRGB(12, 14, 18), glass)
	end
	-- A site's frame: local +Z faces the hub, local -Z is the back.
	local function site(position)
		return CFrame.new(position.X, GROUND_Y, position.Z) * CFrame.Angles(0, yawToward(position, HUB), 0)
	end
	-- Agents' figures face their local -Z, so they are turned to look the way
	-- a site does.
	local function standing(frame, x, z, turn) return frame * CFrame.new(x, 0, z) * CFrame.Angles(0, math.pi + (turn or 0), 0) end

	-- Hangar: a Quinjet on its pad, crates and fuel drums.
	do
		local S = site(LAYOUT.hangar)
		self:AreaFloor(hq, "HangarFloor", LAYOUT.hangar.X, LAYOUT.hangar.Z, 38, 38, yawToward(LAYOUT.hangar, HUB), Color3.fromRGB(96, 104, 116), Enum.Material.Concrete)
		local up = CFrame.Angles(math.pi / 2, 0, 0)
		plate("PadRim", S * CFrame.new(0, 0.05, 0) * up, 31, 0.2, yellow)
		plate("LandingPad", S * CFrame.new(0, 0.12, 0) * up, 29, 0.2, Color3.fromRGB(52, 58, 66))
		emblem(S * CFrame.new(0, 0.24, 0) * up, 8)
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			p("PadLight", V(0.8, 0.5, 0.8), S * CFrame.new(math.cos(a) * 16.5, 0.25, math.sin(a) * 16.5), blue, Enum.Material.Neon)
		end
		quinjet(outpost, S * CFrame.new(0, 0.25, 0), true)
		for i, spot in ipairs({ { -15, -15 }, { -10, -15.5 }, { -15, -10 } }) do
			p("SupplyCrate", V(4.4, 3.4, 4.4), S * CFrame.new(spot[1], 1.7, spot[2]) * CFrame.Angles(0, i * 0.2, 0), Color3.fromRGB(70, 82, 64), Enum.Material.WoodPlanks)
		end
		p("SupplyCrate", V(4, 3, 4), S * CFrame.new(-13.5, 4.9, -13.5) * CFrame.Angles(0, 0.5, 0), Color3.fromRGB(70, 82, 64), Enum.Material.WoodPlanks)
		for _, spot in ipairs({ { 15, -15 }, { 12.6, -16.4 } }) do Kit.column(outpost, "FuelDrum", S * V(spot[1], 0, spot[2]), 3.2, 2.2, Color3.fromRGB(178, 52, 44), metal) end
		agent(standing(S, 9, 12, 0.3))
		agent(standing(S, -11, 11, -0.4))
		Kit.floatText(outpost, "HangarTitle", (S * CFrame.new(0, 17, -8)).Position, "HANGAR DA AGÊNCIA", "AGENCY HANGAR", blue, 34)
	end

	-- Command post: a field HQ module, the holo table, radar and signal mast.
	do
		local S = site(LAYOUT.command)
		self:AreaFloor(hq, "CommandFloor", LAYOUT.command.X, LAYOUT.command.Z, 38, 38, yawToward(LAYOUT.command, HUB), Color3.fromRGB(96, 104, 116), Enum.Material.Concrete)
		p("CommandModule", V(16, 7, 9), S * CFrame.new(0, 3.5, -10), steel, metal).CastShadow = true
		p("CommandRoof", V(17, 0.6, 10), S * CFrame.new(0, 7.3, -10), navy, metal)
		p("CommandDoor", V(3, 5, 0.2), S * CFrame.new(-4.5, 2.5, -5.4), navy, metal)
		p("CommandWindows", V(6, 1.2, 0.2), S * CFrame.new(4, 4.6, -5.4), blue, Enum.Material.Neon)
		emblem(S * CFrame.new(-0.5, 5, -5.25) * CFrame.Angles(0, math.pi, 0), 2.6)
		Kit.column(outpost, "CommandMast", S * V(6, 7.6, -10), 5, 0.3, pale, metal)
		Kit.column(outpost, "HoloPedestal", S * V(0, 0, 4), 3, 1.6, navy, metal)
		plate("HoloTable", S * CFrame.new(0, 3.2, 4) * CFrame.Angles(math.pi / 2, 0, 0), 6.5, 0.4, steel, metal)
		plate("HoloMap", S * CFrame.new(0, 3.47, 4) * CFrame.Angles(math.pi / 2, 0, 0), 5.8, 0.08, blue, Enum.Material.Neon).Transparency = 0.35
		local globe = p("HoloGlobe", V(2.6, 2.6, 2.6), S * CFrame.new(0, 5.25, 4), blue, Enum.Material.ForceField)
		globe.Shape = Enum.PartType.Ball
		Kit.animate(globe, 0.8, 0.2)
		Kit.light(globe, blue, 12, 0.8)
		Kit.block(outpost, "RadarBase", V(3.2, 1, 3.2), S * CFrame.new(12, 0.5, -2), steel, metal)
		local mast = Kit.column(outpost, "RadarMast", S * V(12, 1, -2), 5.5, 0.8, pale, metal)
		local aim = CFrame.new((S * CFrame.new(12, 7.2, -2)).Position) * CFrame.Angles(0.9, 0.6, 0)
		Kit.animate(plate("RadarDish", aim, 7.5, 0.5, white, metal), 0.9, 0, mast.Position)
		Kit.animate(Kit.block(outpost, "RadarFeed", V(0.25, 0.25, 3), aim * CFrame.new(0, 0, -1.5), pale, metal), 0.9, 0, mast.Position)
		Kit.column(outpost, "SignalMast", S * V(-13, 0, -12), 18, 1, pale, metal)
		for _, y in ipairs({ 7, 13 }) do p("SignalBar", V(6, 0.4, 0.4), S * CFrame.new(-13, y, -12), pale, metal) end
		local beacon = p("SignalBeacon", V(1.2, 1.2, 1.2), S * CFrame.new(-13, 18.6, -12), Color3.fromRGB(255, 70, 60), Enum.Material.Neon)
		beacon.Shape = Enum.PartType.Ball
		for i = 0, 2 do p("JerseyBarrier", V(5, 2.2, 1.4), S * CFrame.new(-6 + i * 6, 1.1, -16.5), pale, Enum.Material.Concrete) end
		agent(standing(S, 3, 7, 0.4))
		agent(standing(S, -7, 5, -0.2))
		Kit.floatText(outpost, "CommandTitle", (S * CFrame.new(0, 22, -12)).Position, "POSTO DE COMANDO", "COMMAND POST", blue, 32)
	end

	-- Armory: a vaulted depot, weapon lockers and the agents' black SUV.
	do
		local at = polar(LAYOUT.armory[1], LAYOUT.armory[2], 0)
		local S = site(at)
		self:AreaFloor(hq, "ArmoryFloor", at.X, at.Z, 40, 34, yawToward(at, HUB), Color3.fromRGB(96, 104, 116), Enum.Material.Concrete)
		p("ArmoryDepot", V(20, 8, 12), S * CFrame.new(0, 4, -9), steel, metal).CastShadow = true
		local vault = p("ArmoryRoof", V(20.4, 12.4, 12.4), S * CFrame.new(0, 8, -9), navy, metal)
		vault.Shape = Enum.PartType.Cylinder
		p("ArmoryDoor", V(10, 6.4, 0.2), S * CFrame.new(0, 3.2, -2.9), Color3.fromRGB(62, 70, 80), Enum.Material.DiamondPlate)
		p("ArmoryDoorLight", V(10.4, 0.35, 0.3), S * CFrame.new(0, 6.65, -2.85), blue, Enum.Material.Neon)
		emblem(S * CFrame.new(0, 10.75, -2.7) * CFrame.Angles(0, math.pi, 0), 3.4)
		for i = 0, 1 do
			p("WeaponLocker", V(3, 6, 2), S * CFrame.new(14 - i * 4, 3, -6), navy, metal)
			p("LockerLight", V(0.2, 4.6, 0.3), S * CFrame.new(14 - i * 4, 3, -4.95) * CFrame.Angles(0, math.pi / 2, 0), blue, Enum.Material.Neon)
		end
		local C = S * CFrame.new(-11, 0, 5) * CFrame.Angles(0, 0.6, 0)
		local function suv(x, y, z) return C * CFrame.new(x, y, z) end
		local black = Color3.fromRGB(18, 20, 24)
		p("SuvBody", V(5.2, 2.3, 11), suv(0, 1.6, 0), black, metal).CastShadow = true
		p("SuvCabin", V(4.8, 2, 6.6), suv(0, 3.7, -1), black, metal)
		p("SuvGlass", V(4.9, 1.3, 6.7), suv(0, 3.8, -1), Color3.fromRGB(40, 56, 70), glass)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -3.6, 3.6 }) do
				local wheel = p("SuvWheel", V(1.1, 2.4, 2.4), suv(sx * 2.55, 0.95, sz), Color3.fromRGB(26, 26, 28))
				wheel.Shape = Enum.PartType.Cylinder
			end
			p("SuvHeadlight", V(1.1, 0.5, 0.2), suv(sx * 1.8, 2.05, 5.55), Color3.fromRGB(240, 244, 255), Enum.Material.Neon)
		end
		p("SuvGrille", V(2.2, 0.8, 0.15), suv(0, 1.85, 5.55), pale, metal)
		for _, spot in ipairs({ { 12, 6, 1.7 }, { 16.5, 6, 1.7 }, { 14.2, 6, 5.1 } }) do
			p("SupplyCrate", V(4.2, 3.4, 4.2), S * CFrame.new(spot[1], spot[3], spot[2]), Color3.fromRGB(70, 82, 64), Enum.Material.WoodPlanks)
		end
		agent(standing(S, -3, 9, 0.2))
		agent(standing(S, 6, 11, -0.5))
		Kit.floatText(outpost, "ArmoryTitle", (S * CFrame.new(0, 21, -9)).Position, "ARSENAL DA AGÊNCIA", "AGENCY ARMORY", blue, 34)
	end

	-- The Helicarrier holds station over the north-west sea, rotors turning,
	-- rising and settling on its lift fans.
	do
		local H = CFrame.new(HUB.X - 430, 190, HUB.Z + 380) * CFrame.Angles(0, 0.35, 0)
		local function at(x, y, z) return H * CFrame.new(x, y, z) end
		local hull, deck = Color3.fromRGB(58, 64, 74), Color3.fromRGB(84, 92, 104)
		local first = #outpost:GetChildren()
		p("HelicarrierHull", V(170, 12, 34), at(0, 0, 0), hull, metal)
		p("HelicarrierDeck", V(176, 1.4, 38), at(4, 6.7, 0), deck, metal)
		p("HelicarrierIsland", V(18, 16, 9), at(10, 15.4, -13), hull, metal)
		p("HelicarrierBridge", V(18.3, 1.6, 9.3), at(10, 19.6, -13), blue, Enum.Material.Neon)
		Kit.column(outpost, "HelicarrierMast", H * V(14, 23.4, -13), 10, 0.8, pale, metal)
		for _, side in ipairs({ -1, 1 }) do
			Kit.triangle(outpost, "HelicarrierBow", H * V(85, 0, 0), toWorld(H, V(0, 0, side * 17)), toWorld(H, V(28, 0, 0)), 12, hull, metal)
			p("HelicarrierStripe", V(160, 0.1, 0.7), at(4, 7.45, side * 7), white)
			p("HelicarrierLight", V(150, 0.4, 0.8), at(0, -6.2, side * 9), blue, Enum.Material.Neon)
			for _, x in ipairs({ -50, 50 }) do
				p("RotorArm", V(8, 3, 16), at(x, -2, side * 25), hull, metal)
				local housing = p("RotorHousing", V(3, 30, 30), at(x, -2, side * 41) * CFrame.Angles(0, 0, math.pi / 2), hull, metal)
				housing.Shape = Enum.PartType.Cylinder
				local rotor = p("RotorGlow", V(3.4, 25, 25), at(x, -2, side * 41) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(150, 210, 255), Enum.Material.Neon)
				rotor.Shape, rotor.Transparency = Enum.PartType.Cylinder, 0.55
				local hub = at(x, -0.2, side * 41).Position
				for blade = 0, 1 do
					Kit.animate(p("RotorBlade", V(24, 0.5, 2.2), at(x, -0.2, side * 41) * CFrame.Angles(0, blade * math.pi / 2, 0), pale, metal), 4, 0, hub)
				end
			end
		end
		-- The whole ship bobs as one; blades keep their spin while it does.
		local children = outpost:GetChildren()
		for index = first + 1, #children do
			local piece = children[index]
			if piece:IsA("BasePart") then
				piece:SetAttribute("Bob", 1.6)
				piece:SetAttribute("BobRate", 0.5)
				if not piece:GetAttribute("Spin") then piece:SetAttribute("Spin", 0) end
			end
		end
	end

	-- A second Quinjet patrols the island in a wide banking circle (client).
	do
		local radius, height = 190, 70
		local center = HUB + V(0, height, 40)
		local J = CFrame.new(center + V(radius, 0, 0)) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, -0.28)
		local flyer = Instance.new("Model")
		flyer.Name, flyer.Parent = "QuinjetPatrol", outpost
		for _, piece in ipairs(quinjet(flyer, J, false)) do
			Kit.animate(piece, 0.085, 0, center)
			piece.CastShadow = false
		end
		for _, side in ipairs({ -1, 1 }) do
			local trail = Kit.block(flyer, "QuinjetTrail", V(0.8, 0.8, 16), J * CFrame.new(side * 3.6, 3.4, -19.5), Color3.fromRGB(150, 210, 255), Enum.Material.Neon)
			trail.Transparency = 0.6
			Kit.animate(trail, 0.085, 0, center)
		end
	end
end

--------------------------------------------------------------------------------
-- The three island extensions: expeditions (west), Latveria (east), the
-- academy with training and cards (north). Each has a paved plaza, a bridge,
-- themed set pieces and a big sign.
--------------------------------------------------------------------------------
function World:BuildIslands(hq)
	local V = Vector3.new
	local defs = LAYOUT.islands
	-- Island bridges: a lit steel deck over the channel.
	for id, def in pairs(defs) do
		local a, b = def.bridge[1] + V(0, GROUND_Y, 0), def.bridge[2] + V(0, GROUND_Y, 0)
		local dir = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Unit
		local right = V(-dir.Z, 0, dir.X)
		Kit.beam(hq, "IslandBridge", a - V(0, 0.4, 0) - dir * 4, b - V(0, 0.4, 0) + dir * 4, 12, 1, HQ.stone, Enum.Material.Pavement, true):SetAttribute("BridgeId", id)
		for _, side in ipairs({ -1, 1 }) do
			Kit.beam(hq, "BridgeBeam", a + right * side * 6.4 - V(0, 1.3, 0), b + right * side * 6.4 - V(0, 1.3, 0), 1.2, 2, HQ.steel, Enum.Material.Metal, true)
			Kit.fence(hq, { a + right * side * 5.6 + V(0, 0.1, 0), b + right * side * 5.6 + V(0, 0.1, 0) }, 3, HQ.glow)
		end
	end
	-- West: the expedition outpost, Wakanda's crystals and Asgard's gold.
	do
		local c, width, depth = floorOf("expedition")
		self:AreaFloor(hq, "ExpeditionPlaza", c.X, c.Z, width, depth, 0, HQ.stoneWarm)
		Kit.beam(hq, "IslandPath", hubAt(-162, 87, GROUND_Y - 0.75), V(c.X + width / 2, GROUND_Y - 0.75, HUB.Z + 83), 12, 1.5, HQ.stone, Enum.Material.Pavement, true)
		local purple, gold = Color3.fromRGB(170, 110, 255), Color3.fromRGB(255, 205, 80)
		-- Vibranium crystals rise south of the Wakanda station.
		local rng = Random.new(1966)
		for i, spec in ipairs({ { -226, 38, 11 }, { -233, 35, 15 }, { -240, 39, 8 }, { -220, 34, 7 }, { -246, 34, 10 }, { -230, 42, 6 } }) do
			local foot = hubAt(spec[1], spec[2], GRASS_Y - 0.6)
			local h = spec[3]
			local shard = CFrame.new(foot) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), 0, rng:NextNumber(-0.3, 0.3))
			local shell = Kit.block(hq, "VibraniumCrystal", V(2.6, h, 2.6), shard * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, math.pi / 4, 0), purple:Lerp(HQ.white, 0.2), Enum.Material.Glass)
			shell.Transparency, shell.Reflectance = 0.35, 0.3
			Kit.block(hq, "VibraniumCore", V(1.2, h - 1.4, 1.2), shard * CFrame.new(0, h / 2 - 0.3, 0) * CFrame.Angles(0, math.pi / 4, 0), purple, Enum.Material.Neon)
			if i == 2 then Kit.light(shell, purple, 24, 1.2) end
		end
		-- Asgard: a golden arch over a rainbow walk to its station.
		local asgard = self.catalog.Destinations.normal_asgard
		local walkZ = asgard and asgard.z or HUB.Z + 99
		local archX = c.X + width / 2 - 3
		for _, dz in ipairs({ -7, 7 }) do
			Kit.block(hq, "AsgardPillar", V(2.4, 16, 2.4), CFrame.new(archX, GROUND_Y + 8, walkZ + dz), gold, Enum.Material.Metal, true).CastShadow = true
			Kit.blob(hq, "AsgardOrb", V(2.6, 2.6, 2.6), CFrame.new(archX, GROUND_Y + 17.6, walkZ + dz), HQ.glow, Enum.Material.Neon)
		end
		Kit.block(hq, "AsgardLintel", V(3, 2, 18), CFrame.new(archX, GROUND_Y + 16.6, walkZ), gold, Enum.Material.Metal)
		for i, color in ipairs({ Color3.fromRGB(255, 80, 80), Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 230, 80), Color3.fromRGB(90, 220, 120), Color3.fromRGB(80, 160, 255), Color3.fromRGB(170, 110, 255) }) do
			Kit.block(hq, "RainbowBridge", V(12, 0.1, 1.5), CFrame.new(archX - 5, GROUND_Y + 0.05, walkZ - 5.25 + i * 1.5), color, Enum.Material.Neon)
		end
		Kit.sign(hq, "ExpeditionSign", CFrame.lookAt(hubAt(-272, 81, 38), hubAt(-150, 81, 38)), 38, 15, {
			title = { "EXPEDIÇÕES", "EXPEDITIONS" }, subtitle = { "SELVA • PONTE CELESTE", "SELVA • PONTE CELESTE" },
			top = Color3.fromRGB(190, 140, 255), bottom = Color3.fromRGB(80, 40, 150), accent = purple,
			art = "mountains", artX = 0.5, artY = 0.6, artW = 0.96, artH = 0.7, titleY = 0.34, legs = GRASS_Y,
		})
		for _, spot in ipairs({ { -190, 125, 0.3 }, { -176, 50, -0.2 }, { -230, 136, 1 }, { -200, 31, 2 }, { -262, 124, 0.8 }, { -255, 45, 2.4 } }) do
			Kit.palm(hq, hubAt(spot[1], spot[2], GRASS_Y), 1.1, spot[3])
		end
	end
	-- East: the gates of Doom's fortress.
	do
		local c, width, depth = floorOf("latveria")
		self:AreaFloor(hq, "LatveriaPlaza", c.X, c.Z, width, depth, 0, Color3.fromRGB(150, 156, 150), Enum.Material.Cobblestone)
		Kit.beam(hq, "IslandPath", hubAt(151, 103, GROUND_Y - 0.75), V(c.X - width / 2, GROUND_Y - 0.75, c.Z - 2), 12, 1.5, HQ.stone, Enum.Material.Pavement, true)
		local rock, green = Color3.fromRGB(90, 96, 104), Color3.fromRGB(80, 220, 120)
		Kit.block(hq, "FortressWall", V(6, 18, 56), CFrame.new(c.X + 25, GROUND_Y + 9, c.Z), rock, Enum.Material.Cobblestone, true).CastShadow = true
		for i = -3, 3 do Kit.block(hq, "Battlement", V(6.4, 3, 4), CFrame.new(c.X + 25, GROUND_Y + 19.5, c.Z + i * 8), rock, Enum.Material.Cobblestone) end
		for _, dz in ipairs({ -30, 30 }) do
			local foot = V(c.X + 25, GROUND_Y, c.Z + dz)
			Kit.column(hq, "FortressTower", foot, 28, 12, rock:Lerp(HQ.navy, 0.2), Enum.Material.Cobblestone, true).CastShadow = true
			Kit.disc(hq, "FortressCap", foot + V(0, 28.5, 0), 14, 1, green:Lerp(HQ.navy, 0.5), Enum.Material.Metal)
			local flame = Kit.blob(hq, "GreenFlame", V(3, 5, 3), CFrame.new(foot + V(0, 31.5, 0)), green, Enum.Material.Neon)
			Kit.animate(flame, 0, 0.4)
			Kit.light(flame, green, 26, 1.2)
		end
		for _, dz in ipairs({ -22, 22 }) do
			Kit.block(hq, "DoomBanner", V(0.3, 12, 5), CFrame.new(c.X + 21.8, GROUND_Y + 11, c.Z + dz), Color3.fromRGB(40, 110, 60), Enum.Material.Fabric)
			Kit.block(hq, "BannerTrim", V(0.35, 0.6, 5.2), CFrame.new(c.X + 21.7, GROUND_Y + 5.3, c.Z + dz), HQ.gold, Enum.Material.Metal)
		end
		Kit.sign(hq, "LatveriaSign", CFrame.lookAt(V(c.X + 21, 36, c.Z), V(HUB.X, 36, c.Z)), 34, 13, {
			title = { "CIDADELA", "LATVERIA" }, subtitle = { "EXPEDIÇÃO FINAL • 70 ONDAS", "FINAL EXPEDITION • 70 WAVES" },
			top = Color3.fromRGB(90, 200, 130), bottom = Color3.fromRGB(20, 60, 50), accent = green,
			art = "castle", artX = 0.17, artW = 0.3, titleX = 0.6, titleW = 0.74, legs = GROUND_Y,
		})
		for _, spot in ipairs({ { 180, 155, 0.5 }, { 175, 80, -0.4 }, { 215, 160, 1.2 }, { 250, 80, 0.9 } }) do Kit.tree(hq, hubAt(spot[1], spot[2], GRASS_Y), 1.1, Color3.fromRGB(60, 130, 80)) end
	end
	-- North: the Heroes' Academy, training and cards.
	do
		local c, width, depth = floorOf("academy")
		self:AreaFloor(hq, "AcademyPlaza", c.X, c.Z, width, depth, 0, HQ.stoneWarm)
		self:AreaFloor(hq, "AcademyRoad", HUB.X, HUB.Z + 199, 16, 34)
		local violet = Color3.fromRGB(190, 140, 255)
		local hallZ = c.Z + depth / 2 + 8
		-- The academy hall: columns and a pediment behind the two stations.
		Kit.block(hq, "AcademyHall", V(70, 16, 10), CFrame.new(c.X, GROUND_Y + 8, hallZ), HQ.trim, Enum.Material.Marble, true).CastShadow = true
		for i = -3, 3 do
			Kit.column(hq, "AcademyColumn", V(c.X + i * 10, GROUND_Y, hallZ - 6.5), 16, 2.2, HQ.stoneWarm, Enum.Material.Marble, true)
		end
		Kit.block(hq, "AcademyEntablature", V(74, 3, 13), CFrame.new(c.X, GROUND_Y + 17.5, hallZ - 1.5), HQ.stone, Enum.Material.Marble)
		for _, side in ipairs({ -1, 1 }) do
			Kit.triangle(hq, "AcademyPediment", V(c.X, GROUND_Y + 19, hallZ - 7.5), V(0, 9, 0), V(side * 37, 0, 0), 2, HQ.trim, Enum.Material.Marble)
		end
		Kit.sign(hq, "AcademySign", CFrame.lookAt(V(c.X, 36, hallZ - 10), V(c.X, 36, HUB.Z)), 36, 12, {
			title = { "ACADEMIA", "ACADEMY" }, subtitle = { "TREINO • CARTAS", "TRAINING • CARDS" },
			top = Color3.fromRGB(200, 150, 255), bottom = Color3.fromRGB(90, 50, 170), accent = violet,
			art = "target", artX = 0.14, artW = 0.24, titleX = 0.6, titleW = 0.74,
		})
		for _, x in ipairs({ -40, 40 }) do Kit.flag(hq, V(c.X + x, GROUND_Y, c.Z + 25), 16, violet, 5) end
		-- Giant playing cards stand beside the cards station.
		for i, spec in ipairs({ { 37, -2, 0.3, Color3.fromRGB(230, 60, 90) }, { 40, 4, -0.2, HQ.white } }) do
			local card = Kit.block(hq, "GiantCard", V(0.6, 11, 7.5), CFrame.new(c.X + spec[1], GROUND_Y + 5.5, c.Z + spec[2]) * CFrame.Angles(0, 0, spec[3]), spec[4], Enum.Material.SmoothPlastic)
			Kit.star(hq, "CardStar", card.Position - card.CFrame.RightVector * 0.35, card.CFrame.LookVector, card.CFrame.UpVector, 2, i == 1 and HQ.white or Color3.fromRGB(230, 60, 90), Enum.Material.Neon, 0.1)
		end
		Kit.cornerMarks(hq, c, width / 2 - 2, depth / 2 - 2, violet, GROUND_Y + 0.05, 0)
		-- The academy crest: a violet ring and a gold star inlaid in the plaza.
		local crest = V(c.X, GROUND_Y, c.Z - 11)
		Kit.disc(hq, "AcademyCrestRing", crest + V(0, 0.04, 0), 16, 0.08, violet, Enum.Material.Neon)
		Kit.disc(hq, "AcademyCrest", crest + V(0, 0.07, 0), 14.6, 0.08, HQ.navy, Enum.Material.SmoothPlastic)
		Kit.star(hq, "AcademyStar", crest + V(0, 0.13, 0), V(1, 0, 0), V(0, 0, 1), 6, HQ.gold, Enum.Material.SmoothPlastic, 0.06)
		for _, spot in ipairs({ { -60, -30, 1 }, { 60, -30, 0.9 }, { -64, 38, 1.1 }, { 64, 38, 1 } }) do Kit.tree(hq, V(c.X + spot[1], GRASS_Y, c.Z + spot[2]), spot[3]) end
	end
end

--------------------------------------------------------------------------------
-- Heroes hanging around the HQ, each where they belong: Thor at Asgard's arch,
-- Black Panther by the vibranium, Strange at the academy, Hulk at the arena,
-- Groot among the AFK palms, Rocket on the hangar crates, Spider-Man on the
-- command post roof. Scenery only; the collection lives in the HUD.
--------------------------------------------------------------------------------
function World:BuildHeroCameos(hq)
	local V = Vector3.new
	local cast = Instance.new("Model")
	cast.Name, cast.Parent = "HeroCameos", hq
	local function cameo(heroId, foot, lookAt, scale, pedestal)
		local hero = self.catalog.Heroes[heroId]
		if not hero then return end
		local figure = Instance.new("Model")
		figure.Name, figure.Parent = "Cameo_" .. heroId, cast
		local ground = foot
		if pedestal then
			Kit.disc(figure, "CameoBase", foot + V(0, 0.3, 0), 5, 0.6, HQ.navy, Enum.Material.Metal, true)
			Kit.disc(figure, "CameoGlow", foot + V(0, 0.3, 0), 5.4, 0.1, rgb(hero.color), Enum.Material.Neon)
			ground = foot + V(0, 0.6, 0)
		end
		local model = staticFigure(figure, heroId, hero, CFrame.lookAt(ground, V(lookAt.X, ground.Y, lookAt.Z)), scale)
		local head = model and model:FindFirstChild("Head", true)
		if head then
			local name = label(head, upper(hero.name.pt), V(0, 2.4, 0), rgb(hero.color):Lerp(HQ.white, 0.55), 200, 70)
			name.Font, name.TextSize = Enum.Font.FredokaOne, 20
			name:SetAttribute("LobbyTextPT", upper(hero.name.pt)); name:SetAttribute("LobbyTextEN", upper(hero.name.en))
		end
	end
	local path = hubAt(-162, 87)
	cameo("thor", hubAt(-214, 111, GROUND_Y), path, 1.2, true)
	cameo("panther", hubAt(-228, 48, GRASS_Y), path, 1.2, true)
	cameo("strange", hubAt(-34, 236, GROUND_Y), hubAt(0, 180), 1.2, true)
	cameo("hulk", hubAt(134, -50, GROUND_Y), HUB, 1.1, true)
	cameo("groot", hubAt(-142, -3, GROUND_Y), hubAt(0, 40), 1.1, false)
	local hangar = CFrame.new(LAYOUT.hangar.X, GROUND_Y, LAYOUT.hangar.Z) * CFrame.Angles(0, yawToward(LAYOUT.hangar, HUB), 0)
	cameo("rocket", (hangar * CFrame.new(-13.5, 6.4, -13.5)).Position, HUB, 1, false)
	local command = CFrame.new(LAYOUT.command.X, GROUND_Y, LAYOUT.command.Z) * CFrame.Angles(0, yawToward(LAYOUT.command, HUB), 0)
	cameo("spiderman", (command * CFrame.new(-4, 7.6, -6.5)).Position, HUB, 1, false)
end

--------------------------------------------------------------------------------
-- The horizon: a city skyline across the bay to the north-east.
--------------------------------------------------------------------------------
function World:BuildHorizon(hq)
	local V = Vector3.new
	local city = Instance.new("Model")
	city.Name, city.Parent = "CitySkyline", hq
	local rng = Random.new(20260928)
	local skins = {
		{ Color3.fromRGB(52, 82, 132), Enum.Material.Glass, 0.3 }, { Color3.fromRGB(214, 220, 230), Enum.Material.Concrete, 0 },
		{ Color3.fromRGB(70, 140, 160), Enum.Material.Glass, 0.3 }, { Color3.fromRGB(206, 186, 156), Enum.Material.Concrete, 0 },
		{ Color3.fromRGB(38, 50, 80), Enum.Material.Glass, 0.25 },
	}
	local center = CITY_CENTER
	for i = 1, 16 do
		local a = i * 2.39996
		local r = 26 + math.sqrt(i / 16) * 150
		local foot = center + V(math.cos(a) * r, GRASS_Y, math.sin(a) * r)
		local w, d = rng:NextNumber(24, 38), rng:NextNumber(24, 38)
		local h = rng:NextNumber(70, 130) * (1.6 - r / 260)
		local skin = skins[i % #skins + 1]
		local body = Kit.block(city, "SkylineTower", V(w, h, d), CFrame.new(foot + V(0, h / 2, 0)), skin[1], skin[2])
		body.Reflectance = skin[3]
		-- Floors read at a distance: pale bands up the whole height.
		for band = 1, 3 do
			Kit.block(city, "SkylineBand", V(w + 0.6, 1.4, d + 0.6), CFrame.new(foot + V(0, h * band / 4, 0)), HQ.trim, Enum.Material.SmoothPlastic)
		end
		-- A stepped crown with a lit rim; the tallest carry a spire.
		Kit.block(city, "SkylineCrown", V(w * 0.72, 7, d * 0.72), CFrame.new(foot + V(0, h + 3.5, 0)), skin[1]:Lerp(HQ.navy, 0.4), Enum.Material.Metal)
		Kit.block(city, "SkylineGlow", V(w * 0.74, 1, d * 0.74), CFrame.new(foot + V(0, h + 5.5, 0)), i % 3 == 0 and HQ.gold or HQ.cyan, Enum.Material.Neon)
		if h > 150 then Kit.column(city, "SkylineSpire", foot + V(0, h + 7, 0), 26, 1.2, HQ.trim, Enum.Material.Metal) end
	end
end

--------------------------------------------------------------------------------
-- Nature and street furniture across the main island.
--------------------------------------------------------------------------------
-- Whether a spot on the main island is free grass: off the hub and the ring
-- road, off every area floor, hall, site and bridge, and back from the shore.
local function freeGrass(x, z, radius)
	local dx, dz = x - HUB.X, z - HUB.Z
	if math.sqrt(dx * dx + dz * dz) < LAYOUT.ringRoad[2] + 3 + radius then return false end
	if math.sqrt(dx * dx + (dz - 5) ^ 2) > LAYOUT.islandRadius - 8 - radius then return false end
	for _, f in pairs(LAYOUT.floors) do
		if math.abs(dx - f[1]) <= f[3] / 2 + 4 + radius and math.abs(dz - f[2]) <= f[4] / 2 + 4 + radius then return false end
	end
	local p = LAYOUT.towerPlaza
	-- The tower plaza, the tower and its road north, the campaign sign.
	for _, rect in ipairs({ { 0, (p.dz0 + p.dz1) / 2, p.x * 2, p.dz1 - p.dz0 + 2 }, { 0, 132, 56, 36 }, { 0, 160, 22, 60 }, { 0, -140, 66, 8 } }) do
		if math.abs(dx - rect[1]) <= rect[3] / 2 + 3 + radius and math.abs(dz - rect[2]) <= rect[4] / 2 + 3 + radius then return false end
	end
	local sites = { { polar(LAYOUT.market[1][1], LAYOUT.market[1][2] + 3), 26 }, { polar(LAYOUT.market[2][1], LAYOUT.market[2][2] + 3), 26 },
		{ polar(LAYOUT.armory[1], LAYOUT.armory[2]), 26 }, { LAYOUT.hangar, 28 }, { LAYOUT.command, 28 }, { polar(137.5, 142), 24 } }
	for _, site in ipairs(sites) do
		if (Vector3.new(x, 0, z) - Vector3.new(site[1].X, 0, site[1].Z)).Magnitude < site[2] + radius then return false end
	end
	for _, def in pairs(LAYOUT.islands) do
		local a, b = def.bridge[1], def.bridge[2]
		local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local t = math.clamp(((x - a.X) * ab.X + (z - a.Z) * ab.Z) / (ab.Magnitude ^ 2), -1, 2)
		local nearest = Vector3.new(a.X + ab.X * t, 0, a.Z + ab.Z * t)
		if (Vector3.new(x, 0, z) - nearest).Magnitude < 12 + radius then return false end
	end
	return true
end
World.FreeGrass = freeGrass

function World:DressHeroesHQ(hq)
	local V = Vector3.new
	-- Lamps around the hub quay, between the bridges.
	for i = 0, 11 do
		Kit.lamp(hq, polar(i * 30 + 15, 66, GROUND_Y))
	end
	-- Lamps along the outer edge of the ring road, where no area opens onto it.
	for i = 0, 23 do
		local at = polar(i * 15 + 7.5, 103, GRASS_Y)
		local blocked = false
		for _, f in pairs(LAYOUT.floors) do
			if math.abs(at.X - HUB.X - f[1]) <= f[3] / 2 + 3 and math.abs(at.Z - HUB.Z - f[2]) <= f[4] / 2 + 3 then blocked = true end
		end
		local p = LAYOUT.towerPlaza
		if math.abs(at.X - HUB.X) <= p.x + 3 and at.Z - HUB.Z >= p.dz0 - 3 then blocked = true end
		for _, spec in ipairs(LAYOUT.market) do
			if (at - polar(spec[1], spec[2] + 3, GRASS_Y)).Magnitude < 24 then blocked = true end
		end
		if (at - polar(LAYOUT.armory[1], LAYOUT.armory[2], GRASS_Y)).Magnitude < 24 then blocked = true end
		for _, site in ipairs({ LAYOUT.hangar, LAYOUT.command }) do
			if (Vector3.new(at.X, 0, at.Z) - site).Magnitude < 27 then blocked = true end
		end
		if not blocked then Kit.lamp(hq, at, 8) end
	end
	-- Groves on every patch of free grass: round trees, palms and bushes.
	local rng = Random.new(20260927)
	for ring = 0, 3 do
		local radius = 112 + ring * 11
		local step = 360 / math.floor(2 * math.pi * radius / 17)
		for angle = rng:NextNumber(0, step), 360, step do
			local at = polar(angle + rng:NextNumber(-3, 3), radius + rng:NextNumber(-3, 3), GRASS_Y)
			if freeGrass(at.X, at.Z, 4) and rng:NextNumber() < 0.8 then
				local kind = rng:NextNumber()
				if kind < 0.45 then
					Kit.tree(hq, at, rng:NextNumber(0.85, 1.3), HQ.leaf:Lerp(Color3.fromRGB(40, 150, 90), rng:NextNumber(0, 0.6)))
				elseif kind < 0.8 then
					Kit.palm(hq, at, rng:NextNumber(0.9, 1.2), rng:NextNumber(0, 6.28))
				end
				Kit.bush(hq, at + V(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)), rng:NextNumber(2.5, 4))
			end
		end
	end
	local blossoms = { Color3.fromRGB(255, 120, 150), Color3.fromRGB(255, 220, 90), HQ.white, Color3.fromRGB(170, 120, 255) }
	for i = 0, 7 do
		Kit.flowers(hq, polar(i * 45 + 22.5, 89, GRASS_Y + 0.2), blossoms)
	end
	-- Planters with trees on the hub between the desks; the south side stays
	-- open so nothing stands in front of the statues.
	for _, angle in ipairs({ 15, 75, 105, 165, 195, 345 }) do Kit.planter(hq, polar(angle, 44, GROUND_Y), 5, angle % 90 == 15) end
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
			return zone~=nil and root~=nil and inZone(root.Position,zone,margin)
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

-- Chests are bought at the shop: standing in a summon hall or on its
-- doorstep, measured in the hall's own frame.
function World:NearMarket(player,kind)
	local root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not self.lobby then return false end
	for _,zone in pairs(self.shopZones) do
		if zone.chestId and (not kind or zone.kind==kind) then
			if inZone(root.Position,zone,0,zone.purchaseCenter,zone.purchaseSize,zone.purchaseFrame) then return true end
		end
	end
	return false
end

function World:UpdatePortalQueues(snapshot)
	for queueId,zone in pairs(self.portalZones) do
		local state=snapshot[queueId] or {count=0,max=4,remaining=0}
		local suffix=state.departing and "PARTINDO" or state.count>=4 and "LOTADO" or state.count>0 and tostring(state.remaining).."s" or "ENTRE"
		local suffixEN=state.departing and "DEPARTING" or state.count>=4 and "FULL" or state.count>0 and tostring(state.remaining).."s" or "STEP IN"
		local prefix=tostring(state.count).."/4  •  "
		local pt,en=prefix..suffix,prefix..suffixEN
		if zone.label and zone.label:GetAttribute("LobbyTextPT")~=pt then
			zone.label:SetAttribute("LobbyTextPT",pt); zone.label:SetAttribute("LobbyTextEN",en); zone.label.Text=pt
			zone.label.TextColor3=state.count>=4 and Color3.fromRGB(255,119,103) or zone.tint
			zone.pad.Color=state.count>=4 and Color3.fromRGB(255,119,103) or zone.tint
			-- A queue with riders glows white-hot in its door; a full one turns red.
			if zone.membrane then zone.membrane.Color=state.count>=4 and Color3.fromRGB(255,119,103) or zone.tint end
			if zone.core then zone.core.BackgroundTransparency=state.departing and 0 or state.count>0 and 0.05 or 0.15 end
		end
	end
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
		ground = { Enum.Material.Pavement, Color3.fromRGB(128, 134, 142) },
		patches = { { Enum.Material.LeafyGrass, Color3.fromRGB(86, 138, 62) }, { Enum.Material.Concrete, Color3.fromRGB(146, 148, 152) } },
		road = { Enum.Material.Asphalt, Color3.fromRGB(38, 40, 45) },
		walk = { Enum.Material.Pavement, Color3.fromRGB(168, 170, 174) },
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
	-- Marble is valid on Parts, but Terrain:FillBlock/FillBall rejects it.
	ground={Enum.Material.Sandstone,Color3.fromRGB(210,197,167)},
	patches={{Enum.Material.Rock,Color3.fromRGB(191,172,133)},{Enum.Material.Sandstone,Color3.fromRGB(237,219,184)}},
	road={Enum.Material.Marble,Color3.fromRGB(196,158,74)},
	walk={Enum.Material.Sandstone,Color3.fromRGB(224,208,176)},
	curb={Enum.Material.Metal,Color3.fromRGB(243,199,93)},
	lamp="crystal",lampColor=Color3.fromRGB(153,226,246),poleColor=Color3.fromRGB(212,172,74),
	facade="castle",bodies={{Enum.Material.Marble,Color3.fromRGB(233,214,168)},{Enum.Material.Sandstone,Color3.fromRGB(194,160,96)}},
	glass=Color3.fromRGB(60,121,151),lit=Color3.fromRGB(147,224,255),accent=Color3.fromRGB(239,190,67),
	heights={24,45},outer={"pine","rock","statue"},rock=Enum.Material.Rock,
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
	{ "VOLT INDÚSTRIAS", { 255, 196, 72 } }, { "DAILY BUGLE", { 255, 90, 90 } }, { "OSCORP", { 110, 220, 255 } },
	{ "MULTIVERSO", { 240, 240, 255 } }, { "AGÊNCIA", { 140, 200, 255 } }, { "QUANTUM TECH", { 255, 120, 150 } },
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
	local routeColors={manhattan=Color3.fromRGB(255,206,93),gamma=Color3.fromRGB(122,255,151),hydra=Color3.fromRGB(255,131,103),wakanda=Color3.fromRGB(207,151,255),latveria=Color3.fromRGB(105,229,255),asgard=Color3.fromRGB(140,232,255)}
	-- A map without its own trail colour still gets one: a nil Color3 stops
	-- the whole map from building in Roblox.
	local routeTint=routeColors[mapId] or rgb(map.color or {255,255,255})
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
	-- "BASE" reads the same in both languages, like the HUD's health bar.
	label(base, "BASE", Vector3.new(0, 9, 0), coreTint)
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
