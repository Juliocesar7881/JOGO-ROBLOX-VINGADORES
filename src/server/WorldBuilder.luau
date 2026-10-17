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

-- Smooth mesh helper: creates a MeshPart with a specific Roblox asset ID for
-- organic shapes (capsules, rounded boxes, spheres) instead of blocky Parts.
-- This is the key to achieving the "Neon Heroes" look without external assets.
-- Smooth geometry helper: uses SpecialMesh on standard Parts to achieve
-- organic shapes (spheres, cylinders, heads) without external asset IDs,
-- complying with the project's zero-Toolbox rule while improving the look.
local function smoothPart(parent, name, size, cf, color, material, meshType)
	local p = Instance.new("Part")
	p.Name, p.Size, p.CFrame = name, size, cf
	p.Color, p.Material = color, material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	local mesh = Instance.new("SpecialMesh")
	if meshType == "sphere" then
		mesh.MeshType = Enum.MeshType.Sphere
	elseif meshType == "cylinder" then
		mesh.MeshType = Enum.MeshType.Cylinder
	elseif meshType == "head" then
		mesh.MeshType = Enum.MeshType.Head
	else
		mesh.MeshType = Enum.MeshType.Brick
	end
	mesh.Scale = Vector3.new(1, 1, 1)
	mesh.Parent = p
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
		t.BackgroundTransparency,t.Text,t.Font=1,value,Enum.Font.FredokaOne
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
	t.Font, t.TextSize, t.TextColor3 = Enum.Font.BuilderSansExtraBold, 17, color or Color3.fromRGB(223, 235, 241)
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

-- The rounded mesh a piece can wear, as Roblox draws it (checked in Studio,
-- 16/10): the Head mesh is always round across, its diameter the smaller of
-- the part's X and Z (a mesh scale does not stretch it to an oval), so on a
-- wide plate it shrinks to a thin rod; only a piece nearly round across gets
-- it. Any other gets the Torso mesh, which Roblox draws as a plain box.
local function roundedMeshType(size)
	local wide, deep = math.max(size.X, size.Z), math.min(size.X, size.Z)
	return deep >= wide * 0.85 and Enum.MeshType.Head or Enum.MeshType.Torso
end

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
-- hand, foot, footHeight, legLength, armLength, torsoLength, neck, stance
-- (how far apart the legs stand, in thigh widths between the hips' outer edges).
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
		foot = V(BODY.foot.X * leg, BODY.foot.Y * (spec.footHeight or 1), BODY.foot.Z * (spec.foot or 1) * math.sqrt(leg)) * s,
		lowerLeg = V(BODY.lowerLeg.X * leg, BODY.lowerLeg.Y * legLength, BODY.lowerLeg.Z * leg) * s,
		upperLeg = V(BODY.upperLeg.X * leg, BODY.upperLeg.Y * legLength, BODY.upperLeg.Z * leg) * s,
		chest = V(BODY.chest.X * w * (spec.chest or 1), BODY.chest.Y * (spec.torsoLength or 1), BODY.chest.Z * d) * s,
		upperArm = V(BODY.upperArm.X * arm, BODY.upperArm.Y * armLength, BODY.upperArm.Z * arm) * s,
		lowerArm = V(BODY.lowerArm.X * arm, BODY.lowerArm.Y * armLength, BODY.lowerArm.Z * arm) * s,
		hand = V(BODY.hand.X * arm * hand, BODY.hand.Y * hand * math.sqrt(arm), BODY.hand.Z * arm * hand) * s,
		head = BODY.head * (spec.head or 1) * s,
	}
	sizes.pelvis = V(math.max(BODY.pelvis.X * w, sizes.upperLeg.X * (spec.stance or 2.02) / s), BODY.pelvis.Y, BODY.pelvis.Z * d) * s
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
		elseif shape == "torso" then
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType, mesh.Parent = Enum.MeshType.Torso, made
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
	-- Authored Roblox body meshes soften corners and taper shoulders into the
	-- waist without adding BaseParts or changing the joint/weapon contract.
	for _, name in ipairs({"UpperTorso","LowerTorso","LeftHand","RightHand","LeftFoot","RightFoot",
		"LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm","LeftUpperLeg","RightUpperLeg","LeftLowerLeg","RightLowerLeg"}) do
		local bodyPart=parts[name]
		local mesh=Instance.new("SpecialMesh")
		mesh.Name="BodyContour"
		mesh.MeshType=(name=="UpperTorso" or name=="LowerTorso") and Enum.MeshType.Torso or Enum.MeshType.Head
		mesh.Scale=name=="LowerTorso" and Vector3.new(1,0.94,0.96) or Vector3.one
		mesh.Parent=bodyPart
	end
	model:SetAttribute("BodyFinish","contoured")
	return figure
end

-- A narrow core plus two authored wedges gives a real shoulder-to-waist
-- silhouette. Keep the rig part's bounds intact: costumes, shoulders and
-- emission attachments are authored against them. Finish after the costume
-- chooses its colours/materials, including enemy faction tints.
function Figure.Finish(f, detailed, compact)
	local c = f.sizes.chest
	local core = f.parts.UpperTorso:FindFirstChild("BodyContour")
	core.MeshType, core.Scale = Enum.MeshType.Brick, Vector3.new(compact and 1 or 0.76, 1, 1)
	for _, side in ipairs({ -1, 1 }) do
		local chest = f.parts.UpperTorso
		local basis = CFrame.fromMatrix(Vector3.new(side * c.X * 0.44, 0, 0),
			Vector3.new(0, 0, side), Vector3.new(side, 0, 0), Vector3.new(0, 1, 0))
		if not compact then
			local slope = f.add("UpperTorso", "TorsoSlope", Vector3.new(c.Z, c.X * 0.12, c.Y), basis,
				chest.Color, chest.Material, "wedge")
			slope:SetAttribute("Tint", chest:GetAttribute("Tint"))
		end
		local name = side < 0 and "Left" or "Right"
		for _, segment in ipairs({"UpperArm","LowerArm","UpperLeg","LowerLeg"}) do
			local contour = f.parts[name .. segment]:FindFirstChild("BodyContour")
			contour.MeshType = Enum.MeshType.Head
			contour.Scale = Vector3.new(0.96, 1, 0.96)
		end
		if detailed then
			local hand, foot = f.parts[name .. "Hand"], f.parts[name .. "Foot"]
			f.add(name .. "Hand", "Thumb", hand.Size * Vector3.new(0.33, 0.65, 0.52),
				CFrame.new(-side * hand.Size.X * 0.48, hand.Size.Y * 0.08, -hand.Size.Z * 0.12)
					* CFrame.Angles(0, 0, -side * 0.22), hand.Color, hand.Material, "head")
			f.add(name .. "Foot", "BootSole", foot.Size * Vector3.new(1.02, 0.28, 1.04),
				CFrame.new(0, -foot.Size.Y * 0.37, 0), foot.Color:Lerp(FIGURE_INK, 0.38), foot.Material, "head")
		end
	end
	local hips = f.parts.LowerTorso:FindFirstChild("BodyContour")
	hips.MeshType, hips.Scale = Enum.MeshType.Head, Vector3.new(0.94, 0.96, 0.96)
	f.model:SetAttribute("BodyFinish", "sculpted")
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

-- A hero's face (owner, 15/10: refine the faces above all): eyes with a white,
-- a coloured iris, a pupil and a highlight; rounded brows in the hair's colour;
-- a mouth that is a shape, not a line (an open smile with a tongue, a grin with
-- teeth, a half smile, a roar); lids that narrow a determined eye, rosy cheeks
-- on a cheerful one, lashes where the hero wears them. Every feature is a small
-- part that follows the round of the head (placed on its curve and turned to
-- face out), so the three-quarter portraits read it as well as the front does,
-- and viewports draw it like the world. Masks, lenses and visors use Figure.Face.
function Figure.HeroFace(figure, style, options)
	options = options or {}
	if style ~= "smile" and style ~= "grin" and style ~= "fierce" and style ~= "angry" then
		return Figure.Face(figure, style, options)
	end
	local head = figure.parts.Head
	local h = head.Size
	local k = h.X / BODY.head.X
	local ink = options.ink or FIGURE_INK
	local V = Vector3.new
	local smooth = Enum.Material.SmoothPlastic
	-- A point on the round of the head, turned to face out from it.
	local function on(x, y, lift)
		local a = math.asin(math.clamp(x * h.X / h.Z, -0.95, 0.95))
		local recess = h.Z / 2 * (1 - math.cos(a))
		return figure.face(x, y, (lift or 0) - recess) * CFrame.Angles(0, -a, 0)
	end
	local iris = options.iris or Color3.fromRGB(92, 58, 40)
	local brow = options.brow or ink
	local determined = style == "fierce" or style == "angry"
	local tilt = style == "angry" and 0.42 or (style == "fierce" and 0.24 or -0.12)
	for _, side in ipairs({ -1, 1 }) do
		local x = side * 0.27
		-- The eye: the white, an iris looking a touch inward, the pupil, a highlight.
		figure.add("Head", "Sclera", V(0.29, 0.36, 0.05) * k, on(x, 0.1, 0.0), FIGURE_WHITE, smooth, "ball")
		figure.add("Head", "Iris", V(0.19, 0.26, 0.05) * k, on(x - side * 0.03, 0.07, 0.01), iris, smooth, "ball")
		figure.add("Head", "Pupil", V(0.1, 0.15, 0.05) * k, on(x - side * 0.03, 0.06, 0.02), ink, smooth, "ball")
		figure.add("Head", "Catchlight", V(0.07, 0.08, 0.04) * k, on(x - side * 0.065, 0.16, 0.032), FIGURE_WHITE, smooth, "ball")
		-- The upper lid is a drawn line along the top of the white: thin on a
		-- cheerful eye, thick and slanted like the brow on a determined one.
		if determined then
			figure.add("Head", "EyeLine", V(0.35, 0.075, 0.04) * k, on(x, 0.255, 0.038) * CFrame.Angles(0, 0, side * tilt * 0.75), ink, smooth, "ball")
		else
			figure.add("Head", "EyeLine", V(0.3, 0.05, 0.04) * k, on(x, 0.27, 0.036), ink, smooth, "ball")
		end
		if options.lashes then
			figure.add("Head", "Lash", V(0.12, 0.05, 0.04) * k, on(side * 0.41, 0.25, 0.034) * CFrame.Angles(0, 0, side * 0.62), ink, smooth, "ball")
		end
		-- A determined brow sits a little higher, so it never reads as a second lid.
		figure.add("Head", "Brow", V(0.38, determined and 0.09 or 0.1, 0.05) * k, on(side * 0.29, determined and 0.5 or 0.45, 0.034) * CFrame.Angles(0, 0, side * tilt), brow, smooth, "ball")
		if not determined then
			local cheek = figure.add("Head", "Blush", V(0.19, 0.1, 0.03) * k, on(side * 0.4, -0.17, 0.006), Color3.fromRGB(255, 142, 152), smooth, "ball")
			cheek.Transparency = 0.45
		end
	end
	local mouthInk = Color3.fromRGB(78, 26, 36)
	if style == "smile" then
		-- A smile: a curve of five strokes, each turned along it.
		for index = 0, 4 do
			local x = -0.18 + index * 0.09
			local y = -0.47 + 2.2 * x * x
			local slope = 4.4 * x * h.Y / h.X
			figure.add("Head", "Mouth", V(0.12, 0.06, 0.04) * k, on(x, y, 0.012) * CFrame.Angles(0, 0, math.atan(slope)), mouthInk, smooth, "ball")
		end
	elseif style == "grin" then
		-- A laugh: an open mouth, the top teeth and the tongue showing.
		figure.add("Head", "Mouth", V(0.34, 0.2, 0.03) * k, on(0, -0.43, 0.004), mouthInk, smooth, "ball")
		figure.add("Head", "Teeth", V(0.27, 0.06, 0.03) * k, on(0, -0.365, 0.012), FIGURE_WHITE, smooth, "ball")
		figure.add("Head", "Tongue", V(0.16, 0.075, 0.03) * k, on(0, -0.485, 0.012), Color3.fromRGB(236, 104, 118), smooth, "ball")
	elseif style == "fierce" then
		-- A confident half smile: a thin line that curls up on one side (two fat
		-- strokes read as painted lips in Studio's light).
		for index = 0, 3 do
			local x = -0.15 + index * 0.1
			local y = -0.455 + 1.9 * (x + 0.03) ^ 2
			local slope = 3.8 * (x + 0.03) * h.Y / h.X
			figure.add("Head", "Mouth", V(0.12, 0.045, 0.04) * k, on(x, y, 0.012) * CFrame.Angles(0, 0, math.atan(slope)), mouthInk, smooth, "ball")
		end
	else
		-- A roar: an open mouth with its teeth showing.
		figure.add("Head", "Mouth", V(0.32, 0.17, 0.04) * k, on(0, -0.43, 0.0), mouthInk, smooth, "ball")
		figure.add("Head", "Teeth", V(0.28, 0.06, 0.04) * k, on(0, -0.38, 0.008), FIGURE_WHITE, smooth)
	end
	figure.model:SetAttribute("FaceStyle", style)
end

-- Eye colours and lashes, by hero; everyone else has warm brown eyes.
local HERO_IRIS = {
	captain = Color3.fromRGB(70, 130, 210), thor = Color3.fromRGB(70, 130, 210), captainmarvel = Color3.fromRGB(70, 130, 210), iceman = Color3.fromRGB(110, 190, 240),
	jean = Color3.fromRGB(70, 150, 90), wanda = Color3.fromRGB(80, 140, 70), strange = Color3.fromRGB(90, 150, 110),
	emerald = Color3.fromRGB(60, 170, 100), seaking = Color3.fromRGB(60, 150, 170), amazon = Color3.fromRGB(90, 120, 190),
	vision = Color3.fromRGB(230, 180, 60), solartitan = Color3.fromRGB(240, 170, 60), silversurfer = Color3.fromRGB(150, 170, 200),
	storm = Color3.fromRGB(120, 130, 160), widow = Color3.fromRGB(80, 140, 90),
}
local HERO_LASHES = { widow = true, wanda = true, captainmarvel = true, storm = true, jean = true, psylocke = true, amazon = true }
-- Costume bands that cross the eyes, and the pieces an eye is made of.
local EYE_BANDS = { VisorBand = true, EyeBand = true, GoggleBand = true, Visor = true, VisorRidge = true, MaskBand = true }
-- Pieces that wrap a whole head, and the heroes whose coloured head is their skin.
local HEAD_SHELLS = { HoodShell = true, HelmetBase = true, MaskBase = true, MaskShell = true, HelmetShell = true, HelmShell = true, CowlShell = true, CowlBase = true }
local COLOURED_SKIN = { vision = true, silversurfer = true, groot = true, hulk = true, iceman = true, rocket = true }
-- The league's faces are open: no visor across the eyes.
local OPEN_LEAGUE = { capmen = true, amazon = true, seaking = true, solartitan = true, speedster = true }
local EYE_PIECES = { Sclera = true, Iris = true, Pupil = true, Catchlight = true, EyeLine = true, Lash = true }

-- Hair: a cap over the crown and back of the head, plus an optional style.
-- Every lock is rounded (a slab of hair read as a plank in a close portrait):
-- long hair falls down the back with a lock at each side framing the face; a
-- fringe sweeps across the forehead. `plain` leaves out the side locks (a
-- crowd figure counts every part).
function Figure.Hair(figure, color, style, plain)
	local h = figure.parts.Head.Size
	-- The cap is tilted: high at the forehead, low at the nape, and it wraps
	-- the whole crown (an upright one let the top of the head show through as
	-- a band of skin across the hair) while the brows stay clear.
	figure.add("Head", "Hair", Vector3.new(h.X * 1.12, h.Y * 0.76, h.Z * 1.2), CFrame.new(0, h.Y * 0.26, h.Z * 0.08) * CFrame.Angles(0.25, 0, 0), color, Enum.Material.SmoothPlastic, "ball")
	if style == "long" then
		figure.add("Head", "HairBack", Vector3.new(h.X * 1.06, h.Y * 1.1, h.Z * 0.5), CFrame.new(0, -h.Y * 0.16, h.Z * 0.34), color, Enum.Material.SmoothPlastic, "ball")
		for _, side in ipairs(plain and {} or { -1, 1 }) do
			figure.add("Head", "HairLock", Vector3.new(h.X * 0.2, h.Y * 0.84, h.Z * 0.62), CFrame.new(side * h.X * 0.5, -h.Y * 0.1, h.Z * 0.1), color, Enum.Material.SmoothPlastic, "ball")
		end
	elseif style == "fringe" then
		figure.add("Head", "Fringe", Vector3.new(h.X * 0.66, h.Y * 0.22, h.Z * 0.26), CFrame.new(h.X * 0.14, h.Y * 0.36, -h.Z * 0.43) * CFrame.Angles(0, 0, -0.22), color, Enum.Material.SmoothPlastic, "ball")
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
-- Flat costume colours keep silhouettes readable; equipment has a distinct
-- metal response without covering uniforms in a noisy repeating texture.
local METAL, FABRIC, NEON = Enum.Material.Metal, Enum.Material.SmoothPlastic, Enum.Material.Neon

-- How each hero moves when it attacks (read by the client's Motion).
local HERO_POSE = {
	hawkeye = "bow", widow = "dual", starlord = "dual", deadpool = "dual", bucky = "rifle", warmachine = "rifle", rocket = "rifle",
	hulk = "smash", thor = "smash", groot = "smash", beast = "smash", shangchi = "strike", daredevil = "strike",
	wolverine = "slash", psylocke = "slash", panther = "slash", moonknight = "strike", captain = "throw", gambit = "throw",
	wanda = "magic", strange = "magic", jean = "magic", storm = "magic", iceman = "magic", silversurfer = "magic",
	vision = "beam", captainmarvel = "beam", cyclops = "beam", nova = "shoot", ghostrider = "magic", nightcrawler = "strike",
	-- The league: alternating jabs, a hovering flier, a spear thrust.
	capmen = "punch", speedster = "punch", emerald = "magic", solartitan = "fly", amazon = "throw", seaking = "strike", nightstalker = "throw",
}

-- body, colors, face and hair per hero; `extras` below adds what makes each
-- one recognizable without its name: shield, hammer, web, bow, claws, cape.
local HERO_LOOK = {
	-- The base suit matches the armour above it: the old blue showed through at the torso sides and shoulders.
	ironman = { suit = Color3.fromRGB(236, 240, 246), colors = { chest = Color3.fromRGB(236, 240, 246), pelvis = Color3.fromRGB(40, 92, 200), upperArm = Color3.fromRGB(236, 240, 246), lowerArm = Color3.fromRGB(40, 92, 200), hand = Color3.fromRGB(40, 92, 200), upperLeg = Color3.fromRGB(236, 240, 246), lowerLeg = Color3.fromRGB(40, 92, 200), foot = Color3.fromRGB(40, 92, 200), head = Color3.fromRGB(236, 240, 246) }, shiny = true },
	hawkeye = { colors = { chest = Color3.fromRGB(52, 128, 80), pelvis = HC.ink, upperArm = HC.skin, lowerArm = HC.ink, hand = HC.skin, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.leather }, face = "fierce", hair = { Color3.fromRGB(122, 88, 54), "fringe" } },
	falcon = { colors = { skin = HC.brown, chest = Color3.fromRGB(60, 150, 230), pelvis = HC.ink, upperArm = Color3.fromRGB(60, 150, 230), lowerArm = HC.ink, hand = HC.ink, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "smile", hair = { HC.ink } },
	bucky = { colors = { chest = Color3.fromRGB(78, 96, 58), pelvis = HC.ink, upperArm = HC.silver, lowerArm = HC.silver, hand = HC.silver, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "fierce", hair = { Color3.fromRGB(58, 42, 34), "long" } },
	spiderman = { body = { width = 0.9, arm = 0.9, leg = 0.92 }, colors = { chest = Color3.fromRGB(128, 70, 210), pelvis = Color3.fromRGB(250, 140, 40), upperArm = Color3.fromRGB(128, 70, 210), lowerArm = Color3.fromRGB(250, 140, 40), hand = Color3.fromRGB(250, 140, 40), upperLeg = Color3.fromRGB(128, 70, 210), lowerLeg = Color3.fromRGB(250, 140, 40), foot = Color3.fromRGB(128, 70, 210) }, face = "smile" },
	widow = { body = { width = 0.88, arm = 0.88, leg = 0.9, chest = 0.94 }, colors = { chest = Color3.fromRGB(34, 36, 80), pelvis = Color3.fromRGB(34, 36, 80), upperArm = Color3.fromRGB(34, 36, 80), lowerArm = Color3.fromRGB(34, 36, 80), hand = Color3.fromRGB(34, 36, 80), upperLeg = Color3.fromRGB(34, 36, 80), lowerLeg = Color3.fromRGB(34, 36, 80), foot = Color3.fromRGB(34, 36, 80) }, face = "fierce", hair = { Color3.fromRGB(220, 224, 236), "long" } },
	antman = { colors = { head = Color3.fromRGB(110, 200, 70), chest = Color3.fromRGB(110, 200, 70), pelvis = HC.ink, upperArm = Color3.fromRGB(110, 200, 70), lowerArm = HC.ink, hand = HC.ink, upperLeg = Color3.fromRGB(110, 200, 70), lowerLeg = HC.ink, foot = HC.ink }, shiny = true },
	wasp = { body = { scale = 0.9, width = 0.86, arm = 0.86, leg = 0.88 }, colors = { head = Color3.fromRGB(150, 230, 90), chest = Color3.fromRGB(150, 230, 90), pelvis = Color3.fromRGB(30, 70, 60), upperArm = Color3.fromRGB(30, 70, 60), lowerArm = Color3.fromRGB(150, 230, 90), hand = Color3.fromRGB(30, 70, 60), upperLeg = Color3.fromRGB(30, 70, 60), lowerLeg = Color3.fromRGB(150, 230, 90), foot = Color3.fromRGB(30, 70, 60) } },
	rocket = { body = { scale = 0.62, head = 1.36, legLength = 0.78, armLength = 0.9, width = 1.02 }, colors = { skin = Color3.fromRGB(150, 104, 72), head = Color3.fromRGB(150, 104, 72), chest = Color3.fromRGB(64, 150, 96), pelvis = HC.ink, upperArm = Color3.fromRGB(64, 150, 96), lowerArm = Color3.fromRGB(150, 104, 72), hand = Color3.fromRGB(150, 104, 72), upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "grin" },
	daredevil = { colors = { head = Color3.fromRGB(70, 82, 110), chest = Color3.fromRGB(70, 82, 110), pelvis = Color3.fromRGB(44, 52, 74), upperArm = Color3.fromRGB(70, 82, 110), lowerArm = Color3.fromRGB(70, 82, 110), hand = Color3.fromRGB(44, 52, 74), upperLeg = Color3.fromRGB(70, 82, 110), lowerLeg = Color3.fromRGB(70, 82, 110), foot = Color3.fromRGB(44, 52, 74) } },
	shangchi = { colors = { chest = Color3.fromRGB(40, 150, 110), pelvis = HC.ink, upperArm = Color3.fromRGB(40, 150, 110), lowerArm = HC.skin, hand = HC.skin, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.ink }, face = "fierce", hair = { HC.ink, "fringe" } },
	-- Shield Captain: teal uniform, navy trousers, gloves and boots; a bigger head and hands read at the game camera.
	captain = { suit = Color3.fromRGB(28, 50, 108), body = { width = 1.08, chest = 1.06, arm = 1.08, hand = 1.18, head = 1.1, leg = 1.04 }, colors = { skin = Color3.fromRGB(222, 164, 124), head = Color3.fromRGB(222, 164, 124), chest = Color3.fromRGB(20, 148, 140), pelvis = Color3.fromRGB(28, 50, 108), upperArm = Color3.fromRGB(20, 148, 140), lowerArm = Color3.fromRGB(28, 50, 108), hand = Color3.fromRGB(28, 50, 108), upperLeg = Color3.fromRGB(28, 50, 108), lowerLeg = Color3.fromRGB(28, 50, 108), foot = Color3.fromRGB(28, 50, 108) }, face = "fierce" },
	panther = { colors = { head = Color3.fromRGB(58, 36, 96), chest = Color3.fromRGB(58, 36, 96), pelvis = Color3.fromRGB(44, 28, 74), upperArm = Color3.fromRGB(58, 36, 96), lowerArm = Color3.fromRGB(58, 36, 96), hand = Color3.fromRGB(44, 28, 74), upperLeg = Color3.fromRGB(58, 36, 96), lowerLeg = Color3.fromRGB(58, 36, 96), foot = Color3.fromRGB(44, 28, 74) }, shiny = true },
	hulk = { body = { scale = 1.72, width = 1.1, depth = 1.12, chest = 1.14, head = 0.8, arm = 1.55, hand = 1.3, leg = 1.36, legLength = 0.88, torsoLength = 1.1, foot = 1.1 },
		colors = { skin = Color3.fromRGB(152, 138, 120), head = Color3.fromRGB(152, 138, 120), chest = Color3.fromRGB(152, 138, 120), pelvis = Color3.fromRGB(86, 76, 66), upperArm = Color3.fromRGB(152, 138, 120), lowerArm = Color3.fromRGB(140, 126, 110), hand = Color3.fromRGB(152, 138, 120), upperLeg = Color3.fromRGB(86, 76, 66), lowerLeg = Color3.fromRGB(140, 126, 110), foot = Color3.fromRGB(120, 108, 96) }, face = "angry", matte = true },
	vision = { colors = { skin = Color3.fromRGB(220, 236, 248), head = Color3.fromRGB(220, 236, 248), chest = Color3.fromRGB(110, 150, 230), pelvis = Color3.fromRGB(110, 150, 230), upperArm = Color3.fromRGB(110, 150, 230), lowerArm = Color3.fromRGB(220, 236, 248), hand = Color3.fromRGB(220, 236, 248), upperLeg = Color3.fromRGB(110, 150, 230), lowerLeg = Color3.fromRGB(220, 236, 248), foot = HC.gold }, face = "smile", shiny = true },
	warmachine = { body = { width = 1.08, arm = 1.08, leg = 1.06 }, colors = { head = Color3.fromRGB(176, 108, 52), chest = Color3.fromRGB(176, 108, 52), pelvis = HC.ink, upperArm = Color3.fromRGB(176, 108, 52), lowerArm = HC.ink, hand = Color3.fromRGB(176, 108, 52), upperLeg = Color3.fromRGB(176, 108, 52), lowerLeg = HC.ink, foot = Color3.fromRGB(176, 108, 52) }, shiny = true },
	starlord = { colors = { chest = Color3.fromRGB(30, 110, 130), pelvis = HC.ink, upperArm = Color3.fromRGB(36, 126, 146), lowerArm = Color3.fromRGB(36, 126, 146), hand = HC.ink, upperLeg = HC.ink, lowerLeg = HC.ink, foot = HC.leather, head = Color3.fromRGB(40, 60, 80) } },
	groot = { body = { scale = 1.52, width = 0.74, depth = 0.8, head = 0.92, arm = 0.8, leg = 0.86, legLength = 1.18, armLength = 1.24, torsoLength = 1.08, hand = 1.1 },
		-- A warm, light bark: Studio's wood texture darkens it, the old browns read as black.
		colors = { skin = Color3.fromRGB(156, 114, 74), head = Color3.fromRGB(168, 124, 82), chest = Color3.fromRGB(156, 114, 74), pelvis = Color3.fromRGB(134, 98, 64), upperArm = Color3.fromRGB(156, 114, 74), lowerArm = Color3.fromRGB(146, 106, 68), hand = Color3.fromRGB(134, 98, 64), upperLeg = Color3.fromRGB(146, 106, 68), lowerLeg = Color3.fromRGB(134, 98, 64), foot = Color3.fromRGB(116, 84, 54) }, material = Enum.Material.Wood, face = "smile", matte = true },
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
	capmen = { body = { width = 1.14, arm = 1.2, chest = 1.08, leg = 1.04, hand = 1.15 }, colors = { chest = Color3.fromRGB(214, 58, 52), pelvis = Color3.fromRGB(30, 44, 92), upperArm = Color3.fromRGB(214, 58, 52), lowerArm = Color3.fromRGB(236, 184, 76), hand = Color3.fromRGB(236, 184, 76), upperLeg = Color3.fromRGB(30, 44, 92), lowerLeg = Color3.fromRGB(214, 58, 52), foot = Color3.fromRGB(236, 184, 76) }, face = "fierce", hair = { Color3.fromRGB(40, 30, 28), "fringe" } },
	emerald = { colors = { chest = Color3.fromRGB(40, 176, 94), pelvis = Color3.fromRGB(20, 26, 24), upperArm = Color3.fromRGB(40, 176, 94), lowerArm = Color3.fromRGB(20, 26, 24), hand = Color3.fromRGB(236, 240, 238), upperLeg = Color3.fromRGB(20, 26, 24), lowerLeg = Color3.fromRGB(20, 26, 24), foot = Color3.fromRGB(40, 176, 94) }, face = "smile", hair = { Color3.fromRGB(112, 78, 50), "fringe" } },
	solartitan = { body = { scale = 1.12, width = 1.1, arm = 1.12, chest = 1.1, leg = 1.06 }, colors = { chest = Color3.fromRGB(38, 100, 220), pelvis = Color3.fromRGB(200, 40, 48), upperArm = Color3.fromRGB(38, 100, 220), lowerArm = Color3.fromRGB(38, 100, 220), hand = HC.skin, upperLeg = Color3.fromRGB(38, 100, 220), lowerLeg = Color3.fromRGB(38, 100, 220), foot = Color3.fromRGB(200, 40, 48) }, face = "smile", hair = { Color3.fromRGB(28, 28, 36), "fringe" } },
	speedster = { body = { width = 0.9, arm = 0.88, leg = 1.04, legLength = 1.06 }, colors = { head = Color3.fromRGB(222, 50, 50), chest = Color3.fromRGB(222, 50, 50), pelvis = Color3.fromRGB(222, 50, 50), upperArm = Color3.fromRGB(222, 50, 50), lowerArm = Color3.fromRGB(240, 196, 60), hand = Color3.fromRGB(222, 50, 50), upperLeg = Color3.fromRGB(222, 50, 50), lowerLeg = Color3.fromRGB(222, 50, 50), foot = Color3.fromRGB(240, 196, 60) }, face = "fierce" },
	amazon = { body = { width = 0.9, arm = 0.88, leg = 0.94 }, colors = { chest = Color3.fromRGB(196, 40, 56), pelvis = Color3.fromRGB(30, 56, 140), upperArm = HC.skin, lowerArm = Color3.fromRGB(240, 196, 60), hand = HC.skin, upperLeg = HC.skin, lowerLeg = Color3.fromRGB(30, 56, 140), foot = Color3.fromRGB(196, 40, 56) }, face = "smile", hair = { Color3.fromRGB(36, 28, 30), "long" } },
	nightstalker = { body = { width = 1.04, arm = 1.0, leg = 1.0 }, colors = { head = Color3.fromRGB(26, 28, 40), chest = Color3.fromRGB(52, 60, 86), pelvis = Color3.fromRGB(26, 28, 40), upperArm = Color3.fromRGB(52, 60, 86), lowerArm = Color3.fromRGB(26, 28, 40), hand = Color3.fromRGB(26, 28, 40), upperLeg = Color3.fromRGB(52, 60, 86), lowerLeg = Color3.fromRGB(26, 28, 40), foot = Color3.fromRGB(26, 28, 40) } },
	seaking = { body = { width = 1.12, arm = 1.12, chest = 1.08, leg = 1.04 }, colors = { chest = Color3.fromRGB(232, 150, 44), pelvis = Color3.fromRGB(20, 120, 124), upperArm = Color3.fromRGB(232, 150, 44), lowerArm = Color3.fromRGB(20, 120, 124), hand = HC.tan, upperLeg = Color3.fromRGB(20, 120, 124), lowerLeg = Color3.fromRGB(20, 120, 124), foot = Color3.fromRGB(232, 150, 44) }, face = "fierce", hair = { Color3.fromRGB(240, 216, 150), "long" } },
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
	if not figure.model:GetAttribute("HeroId") then
		-- A villain's cape stays one board (a boss's illusion lives in the crowd's 40 parts).
		figure.add("UpperTorso", "Cape", Vector3.new(chest.X * 0.96, long * s, 0.1 * s), CFrame.new(0, chest.Y / 2 - long * s / 2 + 0.05 * s, chest.Z / 2 + 0.08 * s) * CFrame.Angles(-0.06, 0, 0), color, FABRIC)
		if trim then figure.add("UpperTorso", "CapeCollar", Vector3.new(chest.X * 0.7, 0.34 * s, 0.4 * s), CFrame.new(0, chest.Y / 2 + 0.05 * s, chest.Z / 2 - 0.05 * s), trim, FABRIC) end
		return
	end
	-- A hero's cape hangs from the shoulders and flares out below the waist, a
	-- trim along its hem (owner's pictures, 16/10: a flat board read as a sign).
	local upper = long * 0.55
	figure.add("UpperTorso", "Cape", Vector3.new(chest.X * 0.96, upper * s, 0.1 * s), CFrame.new(0, chest.Y / 2 - upper * s / 2 + 0.05 * s, chest.Z / 2 + 0.08 * s) * CFrame.Angles(-0.06, 0, 0), color, FABRIC)
	local hemTop = chest.Y / 2 + 0.05 * s - upper * s
	local hem = long * 0.5 * s
	local flare = CFrame.new(0, hemTop, chest.Z / 2 + 0.08 * s + upper * s * 0.06) * CFrame.Angles(-0.2, 0, 0)
	figure.add("UpperTorso", "CapeHem", Vector3.new(chest.X * 1.24, hem, 0.1 * s), flare * CFrame.new(0, -hem / 2 + 0.04 * s, 0), color, FABRIC)
	if trim then
		figure.add("UpperTorso", "CapeCollar", Vector3.new(chest.X * 0.7, 0.34 * s, 0.4 * s), CFrame.new(0, chest.Y / 2 + 0.05 * s, chest.Z / 2 - 0.05 * s), trim, FABRIC)
		figure.add("UpperTorso", "CapeTrim", Vector3.new(chest.X * 1.26, 0.12 * s, 0.13 * s), flare * CFrame.new(0, -hem + 0.06 * s, 0), trim, METAL)
	end
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
	local cobalt, pearl, neonBlue, steel = Color3.fromRGB(40, 92, 200), Color3.fromRGB(236, 240, 246), Color3.fromRGB(80, 220, 255), Color3.fromRGB(150, 160, 176)
	-- Neon Sentinel: pearl-white armour with cobalt joints and cyan energy
	-- lines, a wide visor, a lightning bolt on the chest and repulsor
	-- gauntlets; it reads as a high-tech hero even at thumbnail size. Its own
	-- colours and emblem (IP_POLICY: never red and cobalt with a round chest
	-- reactor; world_boot holds it to that).
	-- Head: smooth helmet shell with wide glowing visor and chin guard.
	f.add("Head", "HelmetShell", Vector3.new(h.X * 0.96, h.Y * 0.94, h.Z * 0.96), CFrame.new(), pearl, METAL)
	f.add("Head", "VisorBand", Vector3.new(h.X * 0.78, 0.18 * s, 0.08 * s), f.face(0, 0.12, -0.02), neonBlue, NEON)
	f.add("Head", "ChinGuard", Vector3.new(h.X * 0.52, h.Y * 0.28, 0.14 * s), f.face(0, -0.46, 0.02), cobalt, METAL, "wedge")
	f.add("Head", "HelmetCrest", Vector3.new(0.1 * s, h.Y * 0.36, h.Z * 0.88), CFrame.new(0, h.Y * 0.34, 0), cobalt, METAL, "wedge")
	-- Torso: armoured chest plate with a lightning bolt on a cobalt diamond,
	-- glowing energy lines and segmented abdominal plates.
	f.add("UpperTorso", "ChestArmor", Vector3.new(c.X * 0.92, c.Y * 0.86, 0.14 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), pearl, METAL)
	local bolt = CFrame.new(0, c.Y * 0.16, -c.Z / 2 - 0.08 * s)
	f.add("UpperTorso", "BoltPlate", Vector3.new(0.62 * s, 0.62 * s, 0.06 * s), bolt * CFrame.Angles(0, 0, math.pi / 4), cobalt, METAL)
	f.add("UpperTorso", "ChestBolt", Vector3.new(0.12 * s, 0.34 * s, 0.05 * s), bolt * CFrame.new(0.05 * s, 0.14 * s, -0.05 * s) * CFrame.Angles(0, 0, -0.5), neonBlue, NEON)
	f.add("UpperTorso", "ChestBoltJog", Vector3.new(0.26 * s, 0.09 * s, 0.05 * s), bolt * CFrame.new(0, 0, -0.05 * s), neonBlue, NEON)
	f.add("UpperTorso", "ChestBoltTail", Vector3.new(0.12 * s, 0.34 * s, 0.05 * s), bolt * CFrame.new(-0.05 * s, -0.14 * s, -0.05 * s) * CFrame.Angles(0, 0, -0.5), neonBlue, NEON)
	f.add("UpperTorso", "EnergyLineL", Vector3.new(0.06 * s, c.Y * 0.5, 0.04 * s), CFrame.new(-c.X * 0.28, 0, -c.Z / 2 - 0.05 * s) * CFrame.Angles(0, 0, 0.15), neonBlue, NEON)
	f.add("UpperTorso", "EnergyLineR", Vector3.new(0.06 * s, c.Y * 0.5, 0.04 * s), CFrame.new(c.X * 0.28, 0, -c.Z / 2 - 0.05 * s) * CFrame.Angles(0, 0, -0.15), neonBlue, NEON)
	for i = 1, 3 do
		local width = 1 - (i - 2) * 0.1
		f.add("LowerTorso", "AbdomenPlate" .. i, Vector3.new(c.X * 0.68 * width, 0.18 * s, 0.1 * s), CFrame.new(0, -c.Y * 0.2 + (i - 2) * 0.16 * s, -c.Z / 2 - 0.02 * s), pearl, METAL)
	end
	belt(f, steel, neonBlue)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and repulsor
	-- gauntlets with glowing palm cores.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.28, 0.54, 1.22), CFrame.new(0, f.sizes.upperArm.Y * 0.3, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.12), pearl, METAL, "wedge")
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.06, 0.07 * s, f.sizes.upperArm.Z * 1.02), CFrame.new(0, f.sizes.upperArm.Y * 0.12, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.12), neonBlue, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.14, 0.6, 1.12), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), pearl, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.18, 0.72, 1.16), CFrame.new(0, -f.sizes.hand.Y * 0.08, 0), cobalt, METAL)
		f.disc(handName, "RepulsorCore", 0.32 * s, 0.06 * s, CFrame.new(0, -f.sizes.hand.Y / 2 - 0.02 * s, 0) * CFrame.Angles(math.pi / 2, 0, 0), neonBlue, NEON)
	end
	-- Legs: armored thigh plates with glowing knee caps, shin guards and
	-- boots with neon thruster soles.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.16, 0.68, 1.14), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), pearl, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.66, 0.22 * s, f.sizes.lowerLeg.Z * 0.58), CFrame.new(0, f.sizes.lowerLeg.Y * 0.42, -f.sizes.lowerLeg.Z * 0.26), neonBlue, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.1, 0.7, 1.08), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), cobalt, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.18, 0.62, 1.22), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), pearl, METAL)
		f.add(footName, "ThrusterSole", Vector3.new(f.sizes.foot.X * 0.85, 0.07 * s, f.sizes.foot.Z * 0.85), CFrame.new(0, -f.sizes.foot.Y * 0.34, 0), neonBlue, NEON)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.12 * s, 0))
end
HERO_EXTRAS.captain = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local teal, navy, gold, cream = Color3.fromRGB(20, 148, 140), Color3.fromRGB(28, 50, 108), Color3.fromRGB(244, 190, 58), Color3.fromRGB(240, 232, 212)
	-- Shield Captain: an open-faced teal dome helmet with a gold ridge, a teal
	-- uniform with gold epaulettes over navy trousers, gloves and boots, and a
	-- big round shield of concentric bands. His badge is his own: a gold
	-- diamond with two raised wings (an upward arrow), on the chest and on the
	-- shield. No star, no stripes.
	local function bar(host, name, frame, ax, ay, bx, by, width, depth, color)
		local dx, dy = bx - ax, by - ay
		local length = math.sqrt(dx * dx + dy * dy) + width * 0.5
		return f.add(host, name, Vector3.new(width, length, depth), frame * CFrame.new((ax + bx) / 2, (ay + by) / 2, 0) * CFrame.Angles(0, 0, math.atan2(-dx, dy)), color, METAL)
	end
	-- The winged badge, facing `frame`'s -Z.
	local function badge(host, prefix, frame, size)
		f.add(host, prefix .. "Badge", Vector3.new(0.4, 0.4, 0.1) * size, frame * CFrame.Angles(0, 0, math.pi / 4), gold, METAL)
		for _, side in ipairs({ -1, 1 }) do
			f.add(host, prefix .. "Wing", Vector3.new(0.62, 0.16, 0.1) * size, frame * CFrame.new(side * 0.4 * size, 0.08 * size, 0) * CFrame.Angles(0, 0, side * 0.42), gold, METAL)
		end
	end
	-- Head: a smooth teal dome, open at the face. Its Size stays under half the
	-- head (the costume finish would otherwise paint the whole head teal); the
	-- sphere mesh's Scale draws the full dome.
	local dome = CFrame.new(0, h.Y * 0.21, h.Z * 0.055) * CFrame.Angles(0.2, 0, 0)
	local helmet = f.add("Head", "Helmet", Vector3.new(h.X * 1.12, h.Y * 0.38, h.Z * 1.13), dome, teal, FABRIC, "ball")
	helmet:FindFirstChildOfClass("SpecialMesh").Scale = Vector3.new(1, 2.58, 1)
	-- The back and sides down to the nape frame the face like cheek guards.
	local nape = f.add("Head", "HelmetNape", Vector3.new(h.X * 1.12, h.Y * 0.45, h.Z * 0.95), CFrame.new(0, -h.Y * 0.06, h.Z * 0.1), teal, FABRIC, "head")
	nape:FindFirstChildOfClass("SpecialMesh").Scale = Vector3.new(1, 1.67, 1)
	-- A low gold ridge: a disc standing front to back, only its arc shows above the dome.
	f.disc("Head", "HelmetCrest", h.Y * 1.06, 0.18 * s, dome * CFrame.new(0, h.Y * 0.015, 0) * CFrame.Angles(0, math.pi / 2, 0), gold, METAL)
	local brow = dome * CFrame.new(0, h.Y * 0.07, -h.Z * 0.555) * CFrame.Angles(0.17, 0, 0)
	for _, side in ipairs({ -1, 1 }) do
		bar("Head", "HelmetBadge", brow, 0, 0.1 * s, side * 0.2 * s, -0.06 * s, 0.1 * s, 0.06 * s, gold)
	end
	-- His face is the roster's drawn hero face (Figure.HeroFace): determined,
	-- blue-eyed, under the open helmet.
	-- Torso: the winged badge on the teal chest, a navy collar seating the head,
	-- a gold belt with a navy buckle.
	badge("UpperTorso", "Chest", CFrame.new(0, c.Y * 0.14, -c.Z / 2 - 0.03 * s), s * 1.25)
	f.add("UpperTorso", "Collar", Vector3.new(0.24 * s, h.X * 0.86, h.Z * 0.86), CFrame.new(0, c.Y / 2 + 0.06 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), navy, FABRIC, Enum.PartType.Cylinder)
	local p = f.sizes.pelvis
	f.add("LowerTorso", "Belt", Vector3.new(p.X * 1.04, p.Y * 0.36, p.Z * 1.06), CFrame.new(0, p.Y * 0.28, 0), gold, METAL)
	f.add("LowerTorso", "BeltBuckle", Vector3.new(0.42, 0.3, 0.1) * s, CFrame.new(0, p.Y * 0.28, -p.Z * 0.55), navy, METAL)
	-- Arms and legs: round gold epaulettes, gold cuffs on the gloves and boots.
	local ua, la, ll = f.sizes.upperArm, f.sizes.lowerArm, f.sizes.lowerLeg
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "Left" or "Right"
		-- On the shoulders, not the sleeves: a raised arm leaves them in place.
		local pad = f.add("UpperTorso", "ShoulderPad", Vector3.new(ua.X * 1.6, 0.26 * s, ua.Z * 1.25), CFrame.new(side * (c.X / 2 + ua.X * 0.34 - 0.02 * s), c.Y / 2 - 0.04 * s - ua.Y * 0.04, 0), gold, METAL, "ball")
		pad:FindFirstChildOfClass("SpecialMesh").Scale = Vector3.new(1, 1.4, 1)
		f.add(name .. "LowerArm", "GloveCuff", Vector3.new(la.X * 1.18, 0.22 * s, la.Z * 1.18), CFrame.new(0, la.Y * 0.38, 0), gold, METAL)
		f.add(name .. "LowerLeg", "BootCuff", Vector3.new(ll.X * 1.16, 0.22 * s, ll.Z * 1.16), CFrame.new(0, ll.Y * 0.38, 0), gold, METAL)
	end
	-- The shield: strapped to the outer front of the left forearm and turned
	-- 35 degrees toward the front, so it reads as a full disc from the front
	-- and from the game camera. Gold rim, teal band, cream ring, navy core.
	local turn = math.rad(35)
	local normal = Vector3.new(-math.sin(turn), 0, -math.cos(turn))
	local D, t = 2.45 * s, 0.16 * s
	local centre = Vector3.new(-la.X / 2, -0.05 * s, -la.Z / 2) + normal * (t / 2 - 0.03 * s)
	local base = CFrame.new(centre) * CFrame.Angles(0, turn, 0)
	f.disc("LeftLowerArm", "Shield", D, t, base, gold, METAL)
	f.disc("LeftLowerArm", "ShieldBack", D * 0.84, 0.04 * s, base * CFrame.new(0, 0, t / 2 + 0.01 * s), navy, METAL)
	f.disc("LeftLowerArm", "ShieldBand", D * 0.86, 0.06 * s, base * CFrame.new(0, 0, -0.09 * s), teal, METAL)
	f.disc("LeftLowerArm", "ShieldRing", D * 0.64, 0.06 * s, base * CFrame.new(0, 0, -0.12 * s), cream, METAL)
	f.disc("LeftLowerArm", "ShieldCore", D * 0.44, 0.06 * s, base * CFrame.new(0, 0, -0.15 * s), navy, METAL)
	badge("LeftLowerArm", "Shield", base * CFrame.new(0, -0.03 * s, -0.19 * s), s * 0.78)
	muzzle(f, "LeftLowerArm", centre + normal * 0.3 * s)
end
HERO_EXTRAS.spiderman = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	-- The mask and plates wear the suit's own violet, the webbing a deep violet
	-- (its original look of 01/10): no stray red mask or hair over the mask.
	local crimson, navy, webWhite = Color3.fromRGB(128, 70, 210), Color3.fromRGB(64, 30, 118), Color3.fromRGB(220, 220, 230)
	-- Arachnid: sleek red/blue suit with segmented web-pattern armor,
	-- large expressive eye lenses, chest emblem and wrist-mounted web
	-- shooter; silhouette reads as agile acrobat even at thumbnail size.
	-- Head: full mask with raised web ridges and oversized angular eye lenses.
	f.add("Head", "MaskBase", Vector3.new(h.X * 0.92, h.Y * 0.88, h.Z * 0.92), CFrame.new(0, 0, 0), crimson, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyeLens", Vector3.new(h.X * 0.32, h.Y * 0.38, 0.08 * s), f.face(side * 0.22, 0.08, -0.04), webWhite, METAL, "wedge")
		f.add("Head", "EyeRim", Vector3.new(h.X * 0.36, h.Y * 0.42, 0.04 * s), f.face(side * 0.22, 0.08, -0.06), HC.ink, METAL)
	end
	for i = 0, 3 do
		local angle = i * math.pi / 2
		f.add("Head", "WebRidge" .. i, Vector3.new(h.X * 0.88, 0.04 * s, 0.04 * s), CFrame.new(0, h.Y * 0.1, 0) * CFrame.Angles(0, angle, 0), navy, FABRIC)
	end
	-- Torso: athletic build with central spider emblem, segmented pectoral
	-- plates and abdominal segments that follow the waist taper; web pattern
	-- lines trace the musculature.
	f.add("UpperTorso", "SpiderEmblem", Vector3.new(0.36 * s, 0.42 * s, 0.06 * s), CFrame.new(0, c.Y * 0.12, -c.Z / 2 - 0.04 * s), HC.ink, METAL)
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "PectoralPlate", Vector3.new(c.X * 0.4, c.Y * 0.44, 0.08 * s), CFrame.new(side * c.X * 0.2, c.Y * 0.14, -c.Z / 2 - 0.03 * s) * CFrame.Angles(0, side < 0 and math.pi or 0, side * 0.04), crimson, FABRIC)
		f.add("UpperTorso", "WebLine" .. side, Vector3.new(c.X * 0.38, 0.03 * s, 0.03 * s), CFrame.new(side * c.X * 0.18, c.Y * 0.06, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, side * 0.6), navy, FABRIC)
	end
	for i = 1, 3 do
		local width = 1 - (i - 2) * 0.12
		f.add("LowerTorso", "AbdomenSegment" .. i, Vector3.new(c.X * 0.62 * width, 0.16 * s, 0.08 * s), CFrame.new(0, -c.Y * 0.2 + (i - 2) * 0.14 * s, -c.Z / 2 - 0.02 * s), navy, FABRIC)
	end
	-- Arms: shoulder pads with web accents, forearm bracers and wrist-mounted
	-- web shooters; hands are gloved with reinforced knuckles.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "ShoulderPad", f.sizes.upperArm * Vector3.new(1.18, 0.48, 1.14), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.08), crimson, FABRIC)
		f.add(armName, "WebAccent", Vector3.new(f.sizes.upperArm.X * 0.5, 0.06 * s, f.sizes.upperArm.Z * 0.4), CFrame.new(0, f.sizes.upperArm.Y * 0.38, -f.sizes.upperArm.Z * 0.16), navy, FABRIC)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), crimson, FABRIC)
		f.add(handName, "WebShooter", Vector3.new(f.sizes.hand.X * 0.6, 0.14 * s, f.sizes.hand.Z * 0.7), CFrame.new(0, -f.sizes.hand.Y * 0.08, -f.sizes.hand.Z * 0.14), navy, METAL)
		f.add(handName, "Glove", f.sizes.hand * Vector3.new(1.14, 0.68, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), crimson, FABRIC)
	end
	-- Legs: thigh plates with web lines, knee caps and shin guards; boots
	-- are streamlined for agility with reinforced toes.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.16, 0.68, 1.14), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), crimson, FABRIC)
		f.add(legName, "WebLine", Vector3.new(f.sizes.upperLeg.X * 0.4, 0.03 * s, f.sizes.upperLeg.Z * 0.3), CFrame.new(0, f.sizes.upperLeg.Y * 0.22, -f.sizes.upperLeg.Z * 0.12), navy, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.66, 0.2 * s, f.sizes.lowerLeg.Z * 0.58), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), crimson, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.1, 0.7, 1.08), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), navy, FABRIC)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.18, 0.62, 1.22), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), crimson, FABRIC)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.08 * s, 0))
end
HERO_EXTRAS.hulk = function(f)
	local s, c = f.scale, f.sizes.chest
	local stone, glow, moss = Color3.fromRGB(150, 136, 116), Color3.fromRGB(255, 140, 50), Color3.fromRGB(90, 110, 70)
	-- Titan: massive segmented rock armor with glowing magma veins, heavy
	-- pauldrons, forearm boulders and reinforced knuckles; silhouette reads
	-- as immovable force even at thumbnail size.
	-- Head: the drawn angry face, a magma glow deep in each eye (the brow ridge
	-- sat inside the head and the jaw wedges stuck out like ear flaps).
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyeGlow", Vector3.new(0.14 * s, 0.12 * s, 0.08 * s), f.face(side * 0.22, 0.16, -0.02), glow, NEON, "ball")
	end
	-- Rocks are rounded boulders in two tones of smooth stone (owner, 16/10:
	-- wedge slabs read as planks nailed to the body).
	local rock, darkRock = Enum.Material.SmoothPlastic, Color3.fromRGB(116, 104, 90)
	-- Torso: layered pectoral slabs with magma cracks between them, abdominal
	-- segments that follow the waist taper and a reinforced spine ridge.
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "PectoralSlab", Vector3.new(c.X * 0.46, c.Y * 0.52, 0.32 * s), CFrame.new(side * c.X * 0.24, c.Y * 0.14, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, side < 0 and math.pi or 0, side * 0.06), darkRock, rock, "ball")
	end
	for i = -1, 1 do
		f.add("UpperTorso", "MagmaVein", Vector3.new(0.1 * s, c.Y * 0.48, 0.07 * s), CFrame.new(i * c.X * 0.18, -c.Y * 0.12, -c.Z / 2 - 0.06 * s) * CFrame.Angles(0, 0, i * 0.35), glow, NEON)
		f.add("UpperTorso", "SpineRidge", Vector3.new(0.14 * s, c.Y * 0.6, 0.12 * s), CFrame.new(0, c.Y * 0.08, c.Z / 2 + 0.04 * s), stone, rock, "wedge")
	end
	for i = 1, 3 do
		local width = 1 - (i - 2) * 0.14
		f.add("LowerTorso", "AbdomenSegment" .. i, Vector3.new(c.X * 0.68 * width, 0.2 * s, 0.22 * s), CFrame.new(0, -c.Y * 0.22 + (i - 2) * 0.18 * s, -c.Z / 2 - 0.02 * s), stone, rock, "torso")
	end
	-- Arms: massive shoulder boulders, forearm plates with moss accents and
	-- reinforced knuckle guards that sell the punch impact.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "ShoulderBoulder", f.sizes.upperArm * Vector3.new(1.38, 0.72, 1.34), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0.18, side < 0 and math.pi or 0, side * 0.16), stone, rock, "ball")
		f.add(armName, "MossPatch", Vector3.new(f.sizes.upperArm.X * 0.6, 0.12 * s, f.sizes.upperArm.Z * 0.5), CFrame.new(0, f.sizes.upperArm.Y * 0.42, -f.sizes.upperArm.Z * 0.2), moss, FABRIC, "ball")
		f.add(forearmName, "ForearmPlate", f.sizes.lowerArm * Vector3.new(1.22, 0.68, 1.18), CFrame.new(0, f.sizes.lowerArm.Y * 0.16, 0), darkRock, rock, "head")
		f.add(handName, "KnuckleGuard", f.sizes.hand * Vector3.new(1.24, 0.52, 1.16), CFrame.new(0, -f.sizes.hand.Y * 0.18, -f.sizes.hand.Z * 0.12), stone, rock, "ball")
	end
	-- Legs: thigh slabs, knee caps and shin guards; feet are wide and heavy
	-- to ground the silhouette.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighSlab", f.sizes.upperLeg * Vector3.new(1.24, 0.74, 1.2), CFrame.new(0, f.sizes.upperLeg.Y * 0.16, 0), darkRock, rock, "head")
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.72, 0.26 * s, f.sizes.lowerLeg.Z * 0.64), CFrame.new(0, f.sizes.lowerLeg.Y * 0.44, -f.sizes.lowerLeg.Z * 0.26), stone, rock, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.16, 0.76, 1.14), CFrame.new(0, f.sizes.lowerLeg.Y * 0.1, 0), stone, rock, "head")
		f.add(footName, "HeavyBoot", f.sizes.foot * Vector3.new(1.28, 0.68, 1.32), CFrame.new(0, -f.sizes.foot.Y * 0.12, 0), stone, rock)
	end
	f.add("LowerTorso", "Waistband", f.sizes.pelvis * Vector3.new(1.08, 0.36, 1.1), CFrame.new(0, f.sizes.pelvis.Y * 0.3, 0), Color3.fromRGB(96, 84, 72), rock)
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2, 0))
end
HERO_EXTRAS.hawkeye = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local forest, steel, leather, neonGreen = Color3.fromRGB(70, 150, 96), HC.steel, HC.leather, Color3.fromRGB(100, 255, 120)
	-- Neon Marksman: sleek tactical suit with glowing green accents,
	-- streamlined hood, energy bow and holographic quiver; silhouette
	-- reads as futuristic archer even at thumbnail size.
	-- Head: smooth hood with glowing visor band and chin guard.
	f.add("Head", "HoodShell", Vector3.new(h.X * 0.96, h.Y * 0.94, h.Z * 0.96), CFrame.new(), forest, FABRIC)
	f.add("Head", "VisorBand", Vector3.new(h.X * 0.72, 0.14 * s, 0.07 * s), f.face(0, 0.12, -0.02), neonGreen, NEON)
	f.add("Head", "ChinGuard", Vector3.new(h.X * 0.5, h.Y * 0.28, 0.13 * s), f.face(0, -0.46, 0.02), steel, METAL, "wedge")
	-- Torso: fitted armor vest with central glowing seam, diagonal
	-- harness and utility belt; quiver is holographic/energy based.
	-- Note: TorsoSlope is added automatically by Figure.Finish later.
	f.add("UpperTorso", "ArmorVest", Vector3.new(c.X * 0.9, c.Y * 0.84, 0.13 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), forest, METAL)
	f.add("UpperTorso", "CoreSeam", Vector3.new(0.08 * s, c.Y * 0.6, 0.04 * s), CFrame.new(0, 0, -c.Z / 2 - 0.06 * s), neonGreen, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.36, c.Y * 0.4, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.36, -c.Y * 0.36, -c.Z / 2 - 0.04 * s), 0.1 * s, steel, METAL)
	belt(f, steel, neonGreen)
	-- Holographic Quiver: glowing frame with energy arrows.
	f.add("UpperTorso", "QuiverFrame", Vector3.new(0.42 * s, 1.6 * s, 0.42 * s), CFrame.new(0.36 * s, 0.16 * s, c.Z / 2 + 0.22 * s) * CFrame.Angles(0, 0, -0.3), steel, METAL)
	for i = 1, 3 do
		f.add("UpperTorso", "EnergyArrow" .. i, Vector3.new(0.05 * s, 0.58 * s, 0.05 * s), CFrame.new((0.54 + i * 0.09) * s, 1.02 * s, c.Z / 2 + 0.22 * s) * CFrame.Angles(0, 0, -0.3), neonGreen, NEON)
	end
	-- Arms: sleek pauldrons with neon trim, forearm bracers and gauntlets;
	-- left hand grips the energy bow.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), forest, METAL)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonGreen, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), forest, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), steel, METAL)
		-- Note: Thumb is added automatically by Figure.Finish later.
	end
	-- Energy Bow: sleek curved limbs with glowing string; no physical
	-- wood, pure energy construction.
	local limbs = { Vector3.new(0, 1.38, -0.26), Vector3.new(0, 0.7, -0.58), Vector3.new(0, 0, -0.7), Vector3.new(0, -0.7, -0.58), Vector3.new(0, -1.38, -0.26) }
	for i = 1, #limbs - 1 do f.rod("LeftHand", "BowLimb" .. i, limbs[i] * s, limbs[i + 1] * s, 0.12 * s, steel, METAL) end
	f.add("LeftHand", "BowTipTop", Vector3.new(0.1 * s, 0.2 * s, 0.1 * s), CFrame.new(limbs[1].X * s, limbs[1].Y * s, limbs[1].Z * s), neonGreen, NEON, "ball")
	f.add("LeftHand", "BowTipBottom", Vector3.new(0.1 * s, 0.2 * s, 0.1 * s), CFrame.new(limbs[#limbs].X * s, limbs[#limbs].Y * s, limbs[#limbs].Z * s), neonGreen, NEON, "ball")
	f.rod("LeftHand", "EnergyString", limbs[1] * s, limbs[#limbs] * s, 0.025 * s, neonGreen, NEON)
	-- Legs: armored thigh plates with glowing knee caps and shin guards;
	-- boots are reinforced with neon soles.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), forest, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonGreen, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), forest, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), steel, METAL)
		-- Note: BootSole is added automatically by Figure.Finish later.
	end
	muzzle(f, "LeftHand", Vector3.new(0, 0, -0.74 * s))
end
HERO_EXTRAS.thor = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local storm, spark, steel = Color3.fromRGB(40, 70, 160), Color3.fromRGB(140, 220, 255), Color3.fromRGB(180, 185, 190)
	-- Stormbreaker: winged helmet with glowing eyes, layered silver/blue
	-- armor with lightning sigils, heavy cape and a war hammer that channels
	-- the storm; silhouette reads as divine warrior even at distance.
	-- Head: open helm with wing ornaments, brow ridge and glowing eye slits.
	f.add("Head", "BrowRidge", Vector3.new(h.X * 0.84, h.Y * 0.2, h.Z * 0.24), CFrame.new(0, h.Y * 0.36, -h.Z * 0.1), steel, METAL)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "WingOrnament", Vector3.new(0.18 * s, h.Y * 0.32, h.Z * 0.4), CFrame.new(side * h.X * 0.42, h.Y * 0.28, -h.Z * 0.06) * CFrame.Angles(0, side * 0.4, side * -0.2), steel, METAL, "wedge")
		f.add("Head", "EyeGlow", Vector3.new(0.14 * s, 0.12 * s, 0.06 * s), f.face(side * 0.22, 0.14, -0.02), spark, NEON, "ball")
	end
	f.add("Head", "HelmetCrest", Vector3.new(0.14 * s, h.Y * 0.42, h.Z * 0.9), CFrame.new(0, h.Y * 0.4, 0), storm, METAL)
	-- Torso: segmented chest plates with central lightning sigil, abdominal
	-- segments and reinforced belt; cape anchors at the shoulders.
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "PectoralPlate", Vector3.new(c.X * 0.44, c.Y * 0.48, 0.1 * s), CFrame.new(side * c.X * 0.22, c.Y * 0.14, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, side < 0 and math.pi or 0, side * 0.05), steel, METAL)
	end
	f.add("UpperTorso", "StormSigil", Vector3.new(0.18 * s, 0.68 * s, 0.07 * s), CFrame.new(0, 0.16 * s, -c.Z / 2 - 0.05 * s) * CFrame.Angles(0, 0, -0.42), spark, NEON)
	for i = 1, 3 do
		local width = 1 - (i - 2) * 0.12
		f.add("LowerTorso", "AbdomenPlate" .. i, Vector3.new(c.X * 0.66 * width, 0.18 * s, 0.08 * s), CFrame.new(0, -c.Y * 0.2 + (i - 2) * 0.16 * s, -c.Z / 2 - 0.03 * s), steel, METAL)
	end
	belt(f, HC.leather, steel)
	cape(f, storm, 3.8, steel)
	-- Arms: heavy pauldrons with wing motifs, forearm bracers and gauntlets;
	-- right hand grips the hammer shaft.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.28, 0.56, 1.22), CFrame.new(0, f.sizes.upperArm.Y * 0.3, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.12), steel, METAL, "wedge")
		f.add(armName, "WingMotif", Vector3.new(f.sizes.upperArm.X * 0.5, 0.14 * s, f.sizes.upperArm.Z * 0.4), CFrame.new(0, f.sizes.upperArm.Y * 0.42, -f.sizes.upperArm.Z * 0.18) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), storm, METAL, "wedge")
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.16, 0.64, 1.14), CFrame.new(0, f.sizes.lowerArm.Y * 0.14, 0), steel, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.18, 0.72, 1.16), CFrame.new(0, -f.sizes.hand.Y * 0.1, 0), steel, METAL)
	end
	-- Legs: thigh plates with knee caps, shin guards and heavy boots; stance
	-- is wide and grounded to sell the divine weight.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.2, 0.72, 1.18), CFrame.new(0, f.sizes.upperLeg.Y * 0.16, 0), steel, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.7, 0.24 * s, f.sizes.lowerLeg.Z * 0.62), CFrame.new(0, f.sizes.lowerLeg.Y * 0.42, -f.sizes.lowerLeg.Z * 0.26), steel, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.14, 0.74, 1.12), CFrame.new(0, f.sizes.lowerLeg.Y * 0.1, 0), steel, METAL)
		f.add(footName, "HeavyBoot", f.sizes.foot * Vector3.new(1.24, 0.66, 1.28), CFrame.new(0, -f.sizes.foot.Y * 0.12, 0), steel, METAL)
	end
	-- Hammer: short shaft with a blocky head and glowing runes; muzzle at the
	-- head so projectiles emit from the weapon, not the hand.
	f.rod("RightHand", "HammerShaft", Vector3.new(0, 1.2 * s, 0), Vector3.new(0, -0.6 * s, 0), 0.14 * s, Color3.fromRGB(100, 80, 60), FABRIC)
	f.add("RightHand", "HammerHead", Vector3.new(0.52 * s, 0.42 * s, 0.36 * s), CFrame.new(0, 1.3 * s, 0), steel, METAL)
	f.add("RightHand", "HammerRune", Vector3.new(0.28 * s, 0.28 * s, 0.06 * s), CFrame.new(0, 1.3 * s, -0.2 * s), spark, NEON)
	muzzle(f, "RightHand", Vector3.new(0, 1.3 * s, 0))
end
HERO_EXTRAS.widow = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local ink, violet, gold = HC.ink, Color3.fromRGB(150, 110, 255), HC.gold
	-- Shadow Operative: sleek stealth suit with violet insignia, tactical
	-- harness, dual pistols and forearm bracelets; silhouette reads as
	-- agile infiltrator even at thumbnail size.
	-- Head: an open face under the long hair (no mask: a dark head read as a
	-- dark skin with drawn eyes).
	-- Torso: fitted suit with central insignia, tactical harness and belt.
	f.add("UpperTorso", "WidowInsignia", Vector3.new(0.32 * s, 0.32 * s, 0.05 * s), CFrame.new(0, c.Y * 0.12, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, math.pi / 4), violet, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.38, c.Y * 0.42, -c.Z / 2 - 0.03 * s), Vector3.new(c.X * 0.38, -c.Y * 0.38, -c.Z / 2 - 0.03 * s), 0.12 * s, ink, FABRIC)
	belt(f, HC.steel, violet)
	-- Arms: shoulder pads, forearm bracelets and dual pistols; hands are
	-- gloved with reinforced knuckles.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "ShoulderPad", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.08), ink, FABRIC)
		f.add(forearmName, "Bracelet", f.sizes.lowerArm * Vector3.new(1.1, 0.22, 1.1), CFrame.new(0, -f.sizes.lowerArm.Y * 0.34, 0), gold, METAL)
		f.add(handName, "Glove", f.sizes.hand * Vector3.new(1.12, 0.66, 1.1), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), ink, FABRIC)
		f.add(handName, "Pistol", Vector3.new(0.18 * s, 0.72 * s, 0.36 * s), CFrame.new(0, -0.36 * s, -0.1 * s), HC.steel, METAL)
	end
	-- Legs: thigh plates with knee caps and shin guards; boots are
	-- streamlined for agility with reinforced toes.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), ink, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), ink, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), ink, FABRIC)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), ink, FABRIC)
	end
	muzzle(f, "RightHand", Vector3.new(0, -0.76 * s, -0.1 * s))
end
HERO_EXTRAS.falcon = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local crimson, steel, gold = Color3.fromRGB(160, 30, 50), HC.steel, HC.gold
	-- Sky Marshal: tactical flight helmet with amber visor, segmented
	-- jetpack with articulated wings and dual thrusters; silhouette reads
	-- as aerial ace even at thumbnail size.
	-- Head: streamlined helmet with raised visor ridge and chin guard.
	f.add("Head", "HelmetBase", Vector3.new(h.X * 0.92, h.Y * 0.88, h.Z * 0.92), CFrame.new(), crimson, FABRIC)
	f.add("Head", "VisorRidge", Vector3.new(h.X * 0.78, 0.16 * s, 0.08 * s), f.face(0, 0.16, 0.02), gold, METAL)
	f.add("Head", "ChinGuard", Vector3.new(h.X * 0.52, h.Y * 0.24, 0.12 * s), f.face(0, -0.46, 0.02), steel, METAL, "wedge")
	-- Torso: fitted flight suit with central harness, jetpack housing
	-- and wing anchor points; belt secures the pack.
	f.add("UpperTorso", "HarnessStrap", Vector3.new(c.X * 0.72, 0.14 * s, 0.08 * s), CFrame.new(0, c.Y * 0.18, -c.Z / 2 - 0.03 * s), steel, METAL)
	f.add("UpperTorso", "JetpackHousing", Vector3.new(c.X * 0.68, c.Y * 0.82, 0.48 * s), CFrame.new(0, 0.04 * s, c.Z / 2 + 0.22 * s), steel, METAL)
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "ThrusterNozzle", Vector3.new(0.22 * s, 0.32 * s, 0.28 * s), CFrame.new(side * c.X * 0.24, -c.Y * 0.28, c.Z / 2 + 0.38 * s), HC.ink, METAL)
		f.add("UpperTorso", "WingRoot", Vector3.new(0.4 * s, 0.18 * s, 0.6 * s), CFrame.new(side * (c.X * 0.34 + 0.4 * s), 0.28 * s, c.Z / 2 + 0.28 * s) * CFrame.Angles(0, side * 0.3, side * 0.4), steel, METAL)
		-- Three broad feathers fanned out behind the shoulder, their faces to
		-- the front and the back (a single blade seen edge-on read as a stick).
		for i, feather in ipairs({ { 2.7, 0.56, 0.62, 0.58 }, { 2.3, 0.5, 0.2, 0.32 }, { 1.9, 0.44, -0.18, 0.06 } }) do
			local length, width, rise, tilt = feather[1] * s, feather[2] * s, feather[3] * s, feather[4]
			f.add("UpperTorso", "WingFeather" .. i, Vector3.new(length, width, 0.07 * s), CFrame.new(side * (c.X * 0.34 + length * 0.46), rise, c.Z / 2 + 0.34 * s + i * 0.03 * s) * CFrame.Angles(0, side * 0.32, side * tilt), i == 1 and HC.silver or steel, METAL)
		end
	end
	belt(f, HC.leather, steel)
	-- Arms: shoulder pads with wing motifs, forearm bracers and gauntlets;
	-- hands are gloved for flight control.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "ShoulderPad", f.sizes.upperArm * Vector3.new(1.2, 0.48, 1.16), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), crimson, FABRIC)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), crimson, FABRIC)
		f.add(handName, "Glove", f.sizes.hand * Vector3.new(1.14, 0.68, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), crimson, FABRIC)
	end
	-- Legs: thigh plates with knee caps and shin guards; boots are
	-- reinforced for landing impact.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.16, 0.68, 1.14), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), crimson, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.66, 0.22 * s, f.sizes.lowerLeg.Z * 0.58), CFrame.new(0, f.sizes.lowerLeg.Y * 0.42, -f.sizes.lowerLeg.Z * 0.26), steel, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.1, 0.7, 1.08), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), crimson, FABRIC)
		f.add(footName, "LandingBoot", f.sizes.foot * Vector3.new(1.2, 0.64, 1.24), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), crimson, FABRIC)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.bucky = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local olive, steel, gold = Color3.fromRGB(78, 96, 58), HC.steel, Color3.fromRGB(240, 200, 70)
	-- Winter Soldier: tactical olive drab suit with segmented metal left
	-- arm bearing a red star insignia, chest harness and assault rifle;
	-- silhouette reads as covert operative even at thumbnail size.
	-- Head: his own face under the long hair, dark paint around the eyes.
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyeLens", Vector3.new(h.X * 0.26, h.Y * 0.2, 0.06 * s), f.face(side * 0.22, 0.12, -0.02), steel, METAL, "wedge")
	end
	f.add("Head", "ChinStrap", Vector3.new(h.X * 0.52, h.Y * 0.14, 0.08 * s), f.face(0, -0.48, -0.02), steel, METAL)
	-- Torso: fitted tactical vest with central seam, diagonal harness
	-- and utility belt; left arm is fully metal with star emblem.
	f.add("UpperTorso", "VestFront", Vector3.new(c.X * 0.88, c.Y * 0.82, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), olive, FABRIC)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.36, c.Y * 0.4, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.36, -c.Y * 0.36, -c.Z / 2 - 0.04 * s), 0.12 * s, HC.leather, FABRIC)
	belt(f, HC.leather, steel)
	-- Arms: right arm is organic olive fabric; left arm is segmented
	-- metal plates with red star insignia on the upper arm.
	f.parts.RightUpperArm.Color, f.parts.RightLowerArm.Color, f.parts.RightHand.Color = olive, olive, HC.skin
	f.add("RightUpperArm", "ShoulderPad", f.sizes.upperArm * Vector3.new(1.14, 0.44, 1.1), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, math.pi, 0.06), olive, FABRIC)
	f.add("RightLowerArm", "Bracer", f.sizes.lowerArm * Vector3.new(1.1, 0.56, 1.08), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), olive, FABRIC)
	f.add("RightHand", "Glove", f.sizes.hand * Vector3.new(1.12, 0.64, 1.1), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), olive, FABRIC)
	for i = 1, 3 do
		f.add("LeftUpperArm", "ArmPlate" .. i, f.sizes.upperArm * Vector3.new(1.06, 0.08, 1.06), CFrame.new(0, f.sizes.upperArm.Y * (0.32 - i * 0.18), 0), steel, METAL)
	end
	f.add("LeftUpperArm", "RedStar", Vector3.new(0.08 * s, 0.28 * s, 0.28 * s), CFrame.new(-f.sizes.upperArm.X / 2 - 0.03 * s, 0.1 * s, 0), gold, METAL)
	f.add("LeftLowerArm", "ForearmPlate", f.sizes.lowerArm * Vector3.new(1.12, 0.62, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.14, 0), steel, METAL)
	f.add("LeftHand", "MetalGauntlet", f.sizes.hand * Vector3.new(1.16, 0.7, 1.14), CFrame.new(0, -f.sizes.hand.Y * 0.08, 0), steel, METAL)
	-- Rifle: compact assault weapon with barrel extension; muzzle at
	-- barrel tip so projectiles emit from the weapon, not the hand.
	f.add("RightHand", "RifleBody", Vector3.new(0.24 * s, 1.62 * s, 0.36 * s), CFrame.new(0, -0.72 * s, -0.14 * s), HC.ink, METAL)
	f.add("RightHand", "RifleBarrel", Vector3.new(0.12 * s, 0.82 * s, 0.12 * s), CFrame.new(0, -1.82 * s, -0.14 * s), steel, METAL)
	-- Legs: thigh plates with knee caps and shin guards; boots are
	-- reinforced for tactical movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), olive, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), steel, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), olive, FABRIC)
		f.add(footName, "TacticalBoot", f.sizes.foot * Vector3.new(1.18, 0.62, 1.22), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), olive, FABRIC)
	end
	muzzle(f, "RightHand", Vector3.new(0, -2.24 * s, -0.14 * s))
end
HERO_EXTRAS.antman = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local crimson, steel, neonBlue = Color3.fromRGB(160, 30, 50), HC.steel, Color3.fromRGB(80, 220, 255)
	-- Quantum Scout: sleek helmet with glowing blue lenses, segmented
	-- armor with neon accents and antennae; silhouette reads as
	-- size-shifting hero even at thumbnail size.
	-- Head: streamlined helmet with wide visor band and chin guard.
	f.add("Head", "HelmetShell", Vector3.new(h.X * 0.94, h.Y * 0.92, h.Z * 0.94), CFrame.new(), crimson, METAL)
	f.add("Head", "VisorBand", Vector3.new(h.X * 0.76, 0.16 * s, 0.07 * s), f.face(0, 0.12, -0.02), neonBlue, NEON)
	f.add("Head", "ChinGuard", Vector3.new(h.X * 0.5, h.Y * 0.26, 0.12 * s), f.face(0, -0.46, 0.02), steel, METAL, "wedge")
	for _, side in ipairs({ -1, 1 }) do
		f.rod("Head", "Antenna", Vector3.new(side * h.X * 0.42, h.Y * 0.32, 0), Vector3.new(side * h.X * 0.64, h.Y * 0.96, 0.1 * s), 0.07 * s, steel, METAL)
		f.disc("Head", "Respirator", 0.24 * s, 0.09 * s, f.face(side * 0.32, -0.42, 0.04), steel, METAL)
	end
	-- Torso: fitted armor vest with central seam, diagonal harness
	-- and utility belt; no bulky plates to impede shrinking.
	f.add("UpperTorso", "ArmorVest", Vector3.new(c.X * 0.88, c.Y * 0.82, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), crimson, METAL)
	f.add("UpperTorso", "CoreSeam", Vector3.new(0.07 * s, c.Y * 0.58, 0.04 * s), CFrame.new(0, 0, -c.Z / 2 - 0.05 * s), neonBlue, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, steel, METAL)
	belt(f, steel, neonBlue)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and
	-- gauntlets; hands are gloved for Pym particle control.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), crimson, METAL)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonBlue, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), crimson, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), steel, METAL)
	end
	-- Legs: armored thigh plates with glowing knee caps and shin
	-- guards; boots are reinforced with neon soles.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), crimson, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonBlue, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), crimson, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), steel, METAL)
		-- Note: BootSole is added automatically by Figure.Finish later.
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.wasp = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local gold, black, neonBlue = Color3.fromRGB(240, 200, 60), Color3.fromRGB(24, 28, 39), Color3.fromRGB(110, 190, 255)
	-- Quantum Flyer: sleek helmet with glowing blue lenses, segmented
	-- armor with neon accents, translucent wings and antennae; silhouette
	-- reads as agile aerial hero even at thumbnail size.
	-- Head: streamlined helmet with wide visor band and chin guard.
	f.add("Head", "HelmetShell", Vector3.new(h.X * 0.94, h.Y * 0.92, h.Z * 0.94), CFrame.new(), black, METAL)
	f.add("Head", "VisorBand", Vector3.new(h.X * 0.76, 0.16 * s, 0.07 * s), f.face(0, 0.12, -0.02), neonBlue, NEON)
	f.add("Head", "ChinGuard", Vector3.new(h.X * 0.5, h.Y * 0.26, 0.12 * s), f.face(0, -0.46, 0.02), gold, METAL, "wedge")
	for _, side in ipairs({ -1, 1 }) do
		f.rod("Head", "Antenna", Vector3.new(side * 0.22 * s, 0.52 * s, -0.32 * s), Vector3.new(side * 0.42 * s, 0.98 * s, -0.42 * s), 0.06 * s, gold, METAL)
	end
	-- Torso: fitted armor vest with central seam, diagonal harness
	-- and utility belt; wing anchors at the shoulders.
	f.add("UpperTorso", "ArmorVest", Vector3.new(c.X * 0.88, c.Y * 0.82, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), black, METAL)
	f.add("UpperTorso", "CoreSeam", Vector3.new(0.07 * s, c.Y * 0.58, 0.04 * s), CFrame.new(0, 0, -c.Z / 2 - 0.05 * s), neonBlue, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, gold, METAL)
	belt(f, gold, neonBlue)
	-- Wings: four translucent glass wings (two per side) with neon edges.
	for _, side in ipairs({ -1, 1 }) do
		for _, up in ipairs({ 1, -1 }) do
			local wing = f.add("UpperTorso", "Wing", Vector3.new(1.42 * s, 0.06 * s, 0.72 * s), CFrame.new(side * 0.82 * s, up * 0.36 * s, c.Z / 2 + 0.22 * s) * CFrame.Angles(0, side * 0.3, side * up * 0.45), neonBlue, Enum.Material.Glass, "ball")
			wing.Transparency = 0.32
		end
	end
	-- Arms: sleek pauldrons with neon trim, forearm bracers and
	-- gauntlets; hands are gloved for Pym particle control.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), black, METAL)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonBlue, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), black, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), gold, METAL)
	end
	-- Legs: armored thigh plates with glowing knee caps and shin guards;
	-- boots are reinforced with neon soles.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), black, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonBlue, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), black, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), gold, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.rocket = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local fur, steel, neonOrange = Color3.fromRGB(120, 80, 56), HC.steel, Color3.fromRGB(255, 140, 40)
	-- Heavy Gunner: tactical vest with neon accents, oversized energy
	-- cannon and armored gauntlets; silhouette reads as explosive
	-- specialist even at thumbnail size.
	-- Head: furry face with pointed ears, snout and glowing goggles.
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Ear", Vector3.new(0.34, 0.44, 0.14) * h.X / 1.36, CFrame.new(side * h.X * 0.4, h.Y * 0.56, 0) * CFrame.Angles(0, 0, -side * 0.2), fur, FABRIC, "wedge")
	end
	f.add("Head", "Snout", Vector3.new(h.X * 0.44, h.Y * 0.26, h.Z * 0.24), f.face(0, -0.32, 0.04), Color3.fromRGB(220, 200, 180), FABRIC, "ball")
	f.add("Head", "Nose", Vector3.new(0.18, 0.12, 0.08) * h.X / 1.36, f.face(0, -0.22, 0.12), HC.ink, FABRIC, "ball")
	f.add("Head", "GoggleBand", Vector3.new(h.X * 0.82, 0.14 * s, 0.07 * s), f.face(0, 0.18, -0.02), neonOrange, NEON)
	f.add("LowerTorso", "Tail", Vector3.new(0.5, 0.5, 1.4) * s, CFrame.new(0, -0.1 * s, f.sizes.pelvis.Z / 2 + 0.6 * s) * CFrame.Angles(-0.5, 0, 0), fur, FABRIC, "ball")
	-- Torso: tactical vest with central seam, diagonal harness and
	-- utility belt; ammo pouches on the sides.
	f.add("UpperTorso", "TacticalVest", Vector3.new(c.X * 0.9, c.Y * 0.84, 0.13 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), steel, METAL)
	f.add("UpperTorso", "CoreSeam", Vector3.new(0.07 * s, c.Y * 0.58, 0.04 * s), CFrame.new(0, 0, -c.Z / 2 - 0.05 * s), neonOrange, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, steel, METAL)
	belt(f, steel, neonOrange)
	-- Arms: armored pauldrons with neon trim, forearm bracers and
	-- heavy gauntlets; right hand grips the oversized cannon.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.18, 0.48, 1.14), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), steel, METAL)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonOrange, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), steel, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), steel, METAL)
	end
	-- Cannon: oversized energy weapon with glowing muzzle; held in
	-- both hands for stability.
	f.add("RightHand", "BigGun", Vector3.new(0.52 * s, 2.22 * s, 0.62 * s), CFrame.new(-0.2 * s, -0.9 * s, -0.2 * s), steel, METAL)
	f.add("RightHand", "GunMuzzle", Vector3.new(0.62 * s, 0.32 * s, 0.62 * s), CFrame.new(-0.2 * s, -2.05 * s, -0.2 * s), neonOrange, NEON)
	-- Legs: armored thigh plates with glowing knee caps and shin
	-- guards; boots are reinforced for heavy weapon recoil.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), steel, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonOrange, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), steel, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), steel, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(-0.2 * s, -2.2 * s, -0.2 * s))
end
HERO_EXTRAS.daredevil = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local crimson, steel, neonRed = Color3.fromRGB(160, 30, 50), HC.steel, Color3.fromRGB(255, 60, 60)
	-- Blind Guardian: sleek red suit with glowing sonar visor, armored
	-- chest plate and billy club; silhouette reads as fearless vigilante
	-- even at thumbnail size.
	-- Head: streamlined mask with wide sonar visor band and chin guard.
	f.add("Head", "MaskShell", Vector3.new(h.X * 0.94, h.Y * 0.92, h.Z * 0.94), CFrame.new(), crimson, FABRIC)
	f.add("Head", "SonarVisor", Vector3.new(h.X * 0.78, 0.18 * s, 0.08 * s), f.face(0, 0.12, -0.02), neonRed, NEON)
	f.add("Head", "ChinGuard", Vector3.new(h.X * 0.5, h.Y * 0.26, 0.12 * s), f.face(0, -0.46, 0.02), steel, METAL, "wedge")
	-- Torso: fitted armor vest with central seam, diagonal harness
	-- and utility belt; no bulky plates to impede agility.
	f.add("UpperTorso", "ArmorVest", Vector3.new(c.X * 0.88, c.Y * 0.82, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), crimson, METAL)
	f.add("UpperTorso", "CoreSeam", Vector3.new(0.07 * s, c.Y * 0.58, 0.04 * s), CFrame.new(0, 0, -c.Z / 2 - 0.05 * s), neonRed, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, steel, METAL)
	belt(f, steel, neonRed)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and
	-- gauntlets; right hand grips the billy club.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), crimson, METAL)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonRed, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), crimson, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), steel, METAL)
	end
	f.rod("RightHand", "BillyClub", Vector3.new(0, 0.2 * s, 0), Vector3.new(0, -1.3 * s, -0.1 * s), 0.14 * s, steel, METAL)
	f.add("RightHand", "ClubGlow", Vector3.new(0.16 * s, 0.16 * s, 0.16 * s), CFrame.new(0, -1.3 * s, -0.1 * s), neonRed, NEON, "ball")
	-- Legs: armored thigh plates with glowing knee caps and shin
	-- guards; boots are reinforced for acrobatic movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), crimson, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonRed, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), crimson, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), steel, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -1.3 * s, -0.1 * s))
end
HERO_EXTRAS.shangchi = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local crimson, gold, neonGold = Color3.fromRGB(160, 30, 50), HC.gold, Color3.fromRGB(255, 220, 80)
	-- Ten Rings Master: sleek martial arts suit with glowing golden rings,
	-- armored chest plate and flowing sash; silhouette reads as mystical
	-- warrior even at thumbnail size.
	-- Head: an open face under the fringe.
	-- Torso: fitted martial arts vest with central seam, diagonal harness
	-- and utility belt; ten rings glow on the left forearm.
	f.add("UpperTorso", "VestFront", Vector3.new(c.X * 0.88, c.Y * 0.82, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), crimson, FABRIC)
	f.add("UpperTorso", "CoreSeam", Vector3.new(0.07 * s, c.Y * 0.58, 0.04 * s), CFrame.new(0, 0, -c.Z / 2 - 0.05 * s), neonGold, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, gold, METAL)
	f.add("UpperTorso", "Sash", Vector3.new(c.X * 1.04, 0.24 * s, c.Z * 1.06), CFrame.new(0, -c.Y * 0.36, 0) * CFrame.Angles(0, 0, -0.18), gold, FABRIC)
	belt(f, HC.leather, gold)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and gauntlets;
	-- left forearm bears five glowing ten rings.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), crimson, FABRIC)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonGold, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), crimson, FABRIC)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), gold, METAL)
	end
	local forearm = f.sizes.lowerArm
	for i = 1, 5 do
		f.add("LeftLowerArm", "TenRing", Vector3.new(0.07 * s, forearm.X * 1.5, forearm.X * 1.5), CFrame.new(0, (0.45 - i * 0.15) * forearm.Y, 0) * CFrame.Angles(0, 0, math.pi / 2), neonGold, NEON, Enum.PartType.Cylinder)
	end
	-- Legs: armored thigh plates with glowing knee caps and shin guards;
	-- boots are reinforced for martial arts movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), crimson, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonGold, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), crimson, FABRIC)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), gold, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.panther = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local onyx, gold, neonViolet = Color3.fromRGB(24, 28, 39), Color3.fromRGB(236, 190, 84), Color3.fromRGB(180, 120, 255)
	-- Vibranium King: sleek black suit with glowing violet accents,
	-- golden claws and chest gem; silhouette reads as royal protector
	-- even at thumbnail size.
	-- Head: masked face with angular eye lenses and crystal crest.
	f.add("Head", "MaskShell", Vector3.new(h.X * 0.94, h.Y * 0.92, h.Z * 0.94), CFrame.new(), onyx, METAL)
	f.add("Head", "CrystalCrest", Vector3.new(0.16 * s, 0.5 * s, 0.5 * s), CFrame.new(0, h.Y * 0.5, 0), neonViolet, NEON, "wedge")
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyeLens", Vector3.new(h.X * 0.28, h.Y * 0.2, 0.06 * s), f.face(side * 0.24, 0.12, -0.02), neonViolet, NEON, "wedge")
	end
	-- Torso: fitted vibranium weave with central gem, diagonal harness
	-- and utility belt; gold trim lines the torso edges.
	f.add("UpperTorso", "WeaveFront", Vector3.new(c.X * 0.88, c.Y * 0.82, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), onyx, METAL)
	f.add("UpperTorso", "ChestGem", Vector3.new(0.34 * s, 0.34 * s, 0.08 * s), CFrame.new(0, c.Y * 0.16, -c.Z / 2 - 0.05 * s) * CFrame.Angles(0, 0, math.pi / 4), neonViolet, NEON)
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "GoldTrim", Vector3.new(0.12 * s, c.Y * 0.9, 0.06 * s), CFrame.new(side * c.X * 0.3, 0, -c.Z / 2 - 0.03 * s), gold, METAL)
	end
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, gold, METAL)
	belt(f, onyx, gold)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and
	-- gauntlets; three golden claws extend from each hand.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), onyx, METAL)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonViolet, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), onyx, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), gold, METAL)
		for i = -1, 1 do
			f.add(handName, "Claw", Vector3.new(0.06 * s, 0.34 * s, 0.06 * s), CFrame.new(i * 0.16 * s, -f.sizes.hand.Y / 2 - 0.14 * s, -0.12 * s), gold, METAL)
		end
	end
	-- Legs: armored thigh plates with glowing knee caps and shin
	-- guards; boots are reinforced for silent stalking.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), onyx, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonViolet, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), onyx, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), onyx, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.2 * s, 0))
end
HERO_EXTRAS.vision = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local emerald, gold, neonCyan = Color3.fromRGB(40, 180, 80), HC.gold, Color3.fromRGB(120, 240, 255)
	-- Synthetic Avenger: sleek green/gold android body with glowing
	-- mind gem, chest diamond and flowing cape; silhouette reads as
	-- density-shifting sentinel even at thumbnail size.
	-- Head: smooth android helm with forehead mind gem and visor band.
	f.add("Head", "HelmShell", Vector3.new(h.X * 0.94, h.Y * 0.92, h.Z * 0.94), CFrame.new(), emerald, METAL)
	f.add("Head", "MindGem", Vector3.new(0.24 * s, 0.3 * s, 0.08 * s), f.face(0, 0.5, 0.03) * CFrame.Angles(0, 0, math.pi / 4), neonCyan, NEON)
	f.add("Head", "VisorBand", Vector3.new(h.X * 0.76, 0.14 * s, 0.06 * s), f.face(0, 0.12, -0.02), neonCyan, NEON)
	-- Torso: fitted android chassis with central diamond, diagonal
	-- harness and utility belt; cape anchors at the shoulders.
	f.add("UpperTorso", "ChassisFront", Vector3.new(c.X * 0.88, c.Y * 0.82, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), emerald, METAL)
	f.add("UpperTorso", "ChestDiamond", Vector3.new(0.6 * s, 0.6 * s, 0.06 * s), CFrame.new(0, 0.1 * s, -c.Z / 2 - 0.03 * s) * CFrame.Angles(0, 0, math.pi / 4), gold, METAL)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, gold, METAL)
	belt(f, gold, neonCyan)
	cape(f, Color3.fromRGB(150, 220, 255), 3.4, gold)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and
	-- gauntlets; hands are smooth android constructs.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), emerald, METAL)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonCyan, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), emerald, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), gold, METAL)
	end
	-- Legs: armored thigh plates with glowing knee caps and shin
	-- guards; boots are smooth android constructs.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), emerald, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonCyan, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), emerald, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), gold, METAL)
	end
	muzzle(f, "Head", Vector3.new(0, h.Y * 0.25, -h.Z / 2 - 0.1 * s))
end
HERO_EXTRAS.warmachine = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local gunmetal, steel, neonOrange = Color3.fromRGB(60, 65, 75), HC.steel, Color3.fromRGB(255, 140, 40)
	-- Heavy Ordnance: bulky armored suit with shoulder-mounted cannon,
	-- glowing reactor core and reinforced plating; silhouette reads as
	-- walking arsenal even at thumbnail size.
	-- Head: armored helmet with glowing eye slits and faceplate.
	f.add("Head", "HelmetShell", Vector3.new(h.X * 0.96, h.Y * 0.94, h.Z * 0.96), CFrame.new(), gunmetal, METAL)
	f.add("Head", "EyeSlits", Vector3.new(h.X * 0.72, 0.14 * s, 0.07 * s), f.face(0, 0.12, -0.02), neonOrange, NEON)
	f.add("Head", "FacePlate", Vector3.new(h.X * 0.66, h.Y * 0.6, 0.08 * s), f.face(0, -0.1, -0.02), steel, METAL)
	-- Torso: heavy chest armor with central reactor, diagonal harness
	-- and utility belt; shoulder cannon mounts on the right side.
	f.add("UpperTorso", "ChestArmor", Vector3.new(c.X * 0.92, c.Y * 0.86, 0.14 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), gunmetal, METAL)
	f.disc("UpperTorso", "ReactorCore", 0.36 * s, 0.06 * s, CFrame.new(0, 0.2 * s, -c.Z / 2 - 0.04 * s), neonOrange, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, steel, METAL)
	belt(f, steel, neonOrange)
	f.add("UpperTorso", "ShoulderCannon", Vector3.new(0.52 * s, 0.52 * s, 1.82 * s), CFrame.new(c.X * 0.36, c.Y / 2 + 0.3 * s, -0.2 * s), gunmetal, METAL)
	f.add("UpperTorso", "CannonMuzzle", Vector3.new(0.34 * s, 0.34 * s, 0.2 * s), CFrame.new(c.X * 0.36, c.Y / 2 + 0.3 * s, -1.1 * s), neonOrange, NEON)
	-- Arms: heavy pauldrons with neon trim, forearm bracers and
	-- gauntlets; hands are reinforced for weapon recoil.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.28, 0.54, 1.22), CFrame.new(0, f.sizes.upperArm.Y * 0.3, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.12), gunmetal, METAL, "wedge")
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.06, 0.07 * s, f.sizes.upperArm.Z * 1.02), CFrame.new(0, f.sizes.upperArm.Y * 0.12, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.12), neonOrange, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.14, 0.6, 1.12), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), gunmetal, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.18, 0.72, 1.16), CFrame.new(0, -f.sizes.hand.Y * 0.08, 0), steel, METAL)
	end
	-- Legs: armored thigh plates with glowing knee caps and shin
	-- guards; boots are heavy and reinforced for stability.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.16, 0.68, 1.14), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), gunmetal, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.66, 0.22 * s, f.sizes.lowerLeg.Z * 0.58), CFrame.new(0, f.sizes.lowerLeg.Y * 0.42, -f.sizes.lowerLeg.Z * 0.26), neonOrange, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.1, 0.7, 1.08), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), gunmetal, METAL)
		f.add(footName, "HeavyBoot", f.sizes.foot * Vector3.new(1.2, 0.64, 1.24), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), gunmetal, METAL)
	end
	muzzle(f, "UpperTorso", Vector3.new(c.X * 0.36, c.Y / 2 + 0.3 * s, -1.3 * s))
end
HERO_EXTRAS.starlord = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local maroon, steel, neonCyan = Color3.fromRGB(120, 30, 40), HC.steel, Color3.fromRGB(120, 230, 255)
	-- Cosmic Outlaw: long leather coat with neon accents, glowing visor
	-- mask and dual blasters; silhouette reads as space pirate even at
	-- thumbnail size.
	-- Head: sleek mask with wide glowing visor and ear pieces.
	f.add("Head", "MaskShell", Vector3.new(h.X * 0.94, h.Y * 0.92, h.Z * 0.94), CFrame.new(), maroon, FABRIC)
	f.add("Head", "VisorBand", Vector3.new(h.X * 0.78, 0.18 * s, 0.08 * s), f.face(0, 0.12, -0.02), neonCyan, NEON)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EarPiece", Vector3.new(0.14 * s, 0.46 * s, 0.46 * s), CFrame.new(side * h.X * 0.52, 0, 0), steel, METAL)
	end
	-- Torso: long trench coat with central seam, diagonal harness and
	-- utility belt; coat tails extend below the waist for dramatic flow.
	f.add("UpperTorso", "CoatBody", Vector3.new(c.X * 1.08, c.Y * 1.52, c.Z * 1.1), CFrame.new(0, -c.Y * 0.28, 0.02 * s), maroon, FABRIC)
	f.add("UpperTorso", "CoreSeam", Vector3.new(0.07 * s, c.Y * 0.58, 0.04 * s), CFrame.new(0, 0, -c.Z / 2 - 0.05 * s), neonCyan, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, steel, METAL)
	belt(f, HC.leather, steel)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and gauntlets;
	-- both hands grip glowing blasters.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), maroon, FABRIC)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonCyan, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), maroon, FABRIC)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), steel, METAL)
		f.add(handName, "Blaster", Vector3.new(0.22 * s, 0.74 * s, 0.36 * s), CFrame.new(0, -0.38 * s, -0.1 * s), steel, METAL)
		f.add(handName, "BlasterGlow", Vector3.new(0.14 * s, 0.14 * s, 0.14 * s), CFrame.new(0, -0.76 * s, -0.1 * s), neonCyan, NEON, "ball")
	end
	-- Legs: armored thigh plates with glowing knee caps and shin guards;
	-- boots are reinforced for zero-gravity movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), maroon, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonCyan, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), maroon, FABRIC)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), steel, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -0.8 * s, -0.1 * s))
end
HERO_EXTRAS.groot = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local bark, leaf, neonGreen = Color3.fromRGB(134, 98, 64), Color3.fromRGB(96, 170, 72), Color3.fromRGB(120, 255, 140)
	-- Flora Guardian: living wood body with glowing green veins,
	-- leafy crown and root-like limbs; silhouette reads as nature
	-- sentinel even at thumbnail size.
	-- Head: wooden face with glowing eyes and leafy crown.
	f.add("Head", "WoodFace", Vector3.new(h.X * 0.92, h.Y * 0.9, h.Z * 0.92), CFrame.new(), bark, Enum.Material.Wood)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyeGlow", Vector3.new(0.16 * s, 0.14 * s, 0.06 * s), f.face(side * 0.22, 0.12, -0.02), neonGreen, NEON, "ball")
		f.rod("Head", "Twig", Vector3.new(side * h.X * 0.2, h.Y * 0.4, 0), Vector3.new(side * h.X * 0.5, h.Y * 0.95, 0.1 * s), 0.1 * s, bark, Enum.Material.Wood)
	end
	for i = -1, 1 do
		f.add("Head", "CrownLeaf", Vector3.new(0.36 * s, 0.1 * s, 0.24 * s), CFrame.new(i * h.X * 0.26, h.Y * 0.56, i * 0.1 * s) * CFrame.Angles(0.2, i * 0.6, i * 0.5), leaf, Enum.Material.Grass, "ball")
	end
	-- Torso: wooden chest with glowing veins and bark ridges;
	-- no fabric, only living wood texture.
	f.add("UpperTorso", "WoodChest", Vector3.new(c.X * 0.9, c.Y * 0.84, 0.13 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), bark, Enum.Material.Wood)
	f.add("UpperTorso", "VeinCore", Vector3.new(0.08 * s, c.Y * 0.6, 0.04 * s), CFrame.new(0, 0, -c.Z / 2 - 0.06 * s), neonGreen, NEON)
	for i = -1, 1 do
		f.rod("UpperTorso", "BarkRidge", Vector3.new(i * c.X * 0.32, -c.Y * 0.45, -c.Z / 2 - 0.025 * s), Vector3.new(i * c.X * 0.18, c.Y * 0.44, -c.Z / 2 - 0.025 * s), 0.16 * s, bark, Enum.Material.Wood)
	end
	-- Arms: wooden limbs with leafy shoulders and root-like hands;
	-- glowing veins trace the arm length.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "WoodLimb", f.sizes.upperArm * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.14, 0), bark, Enum.Material.Wood)
		f.add(armName, "LeafShoulder", Vector3.new(0.74 * s, 0.16 * s, 0.5 * s), CFrame.new(side * 0.12 * s, f.sizes.upperArm.Y * 0.45, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * 0.35), leaf, Enum.Material.Grass, "wedge")
		f.add(forearmName, "WoodForearm", f.sizes.lowerArm * Vector3.new(1.1, 0.68, 1.08), CFrame.new(0, f.sizes.lowerArm.Y * 0.08, 0), bark, Enum.Material.Wood)
		f.rod(handName, "RootHand", Vector3.new(0, 0, 0), Vector3.new(side * 0.2 * s, -0.7 * s, -0.1 * s), 0.12 * s, bark, Enum.Material.Wood)
	end
	-- Legs: wooden thighs with glowing knee caps and root-like feet;
	-- no boots, only living wood extending into the ground.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "WoodThigh", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), bark, Enum.Material.Wood)
		f.add(lowerName, "KneeGlow", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonGreen, NEON, "ball")
		f.add(lowerName, "WoodShin", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), bark, Enum.Material.Wood)
		f.add(footName, "RootFoot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), bark, Enum.Material.Wood)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.3 * s, 0))
end
-- A circlet: a thin rounded band around the head at the hairline. Its top and
-- inside sit in the hair, so only the gold ring shows across the forehead (a
-- flat plate up there read as a box hat). Returns the band's height on the
-- face (figure.face units), for a gem or a point standing on it.
local function circlet(f, name, color)
	local h = f.parts.Head.Size
	f.add("Head", name, Vector3.new(h.X * 1.14, h.Y * 0.12, h.Z * 1.14), CFrame.new(0, h.Y * 0.34, h.Z * 0.02), color, METAL, "head")
	return 0.68
end

HERO_EXTRAS.wanda = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local crimson, chaos, gold = Color3.fromRGB(160, 30, 50), Color3.fromRGB(240, 200, 90), Color3.fromRGB(220, 170, 70)
	-- Chaos Weaver: regal crimson gown with golden crown tiara, flowing
	-- cape and chaos orbs hovering above both palms; silhouette reads as
	-- arcane sovereign even at thumbnail size.
	-- Head: crowned tiara with side spikes and glowing brow gem.
	local band = circlet(f, "TiaraBase", gold)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "CrownSpike", Vector3.new(0.1 * s, 0.46 * s, 0.08 * s), f.face(side * 0.2, band + 0.3, 0.06) * CFrame.Angles(0, 0, side * 0.42), gold, METAL, "wedge")
	end
	f.add("Head", "BrowGem", Vector3.new(0.18 * s, 0.18 * s, 0.08 * s), f.face(0, band, 0.1), chaos, NEON, "ball")
	-- Torso: fitted bodice with central gem, layered skirt segments and
	-- sash; cape anchors at the shoulders.
	f.add("UpperTorso", "BodiceGem", Vector3.new(0.22 * s, 0.28 * s, 0.06 * s), CFrame.new(0, c.Y * 0.18, -c.Z / 2 - 0.04 * s), chaos, NEON)
	for i = 1, 3 do
		local width = 1 - (i - 2) * 0.1
		f.add("LowerTorso", "SkirtSegment" .. i, Vector3.new(c.X * 0.72 * width, 0.2 * s, 0.1 * s), CFrame.new(0, -c.Y * 0.22 + (i - 2) * 0.18 * s, -c.Z / 2 - 0.02 * s), crimson, FABRIC)
	end
	belt(f, HC.leather, gold)
	cape(f, Color3.fromRGB(120, 40, 160), 3.2, gold)
	-- Arms: pauldrons with gold trim, forearm bracers and chaos orbs
	-- hovering above both palms; hands are gloved.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.22, 0.5, 1.18), CFrame.new(0, f.sizes.upperArm.Y * 0.3, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), crimson, FABRIC)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.02, 0.07 * s, f.sizes.upperArm.Z * 0.98), CFrame.new(0, f.sizes.upperArm.Y * 0.12, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), gold, METAL)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), crimson, FABRIC)
		f.add(handName, "Glove", f.sizes.hand * Vector3.new(1.14, 0.68, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), crimson, FABRIC)
		local orb = f.add(handName, "ChaosOrb", Vector3.new(0.64 * s, 0.64 * s, 0.64 * s), CFrame.new(0, -0.52 * s, -0.12 * s), chaos, NEON, "ball")
		orb.Transparency = 0.2
	end
	-- Legs: thigh plates with knee caps and shin guards; boots are
	-- elegant with gold trim.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.16, 0.68, 1.14), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), crimson, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.66, 0.22 * s, f.sizes.lowerLeg.Z * 0.58), CFrame.new(0, f.sizes.lowerLeg.Y * 0.42, -f.sizes.lowerLeg.Z * 0.26), gold, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.1, 0.7, 1.08), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), crimson, FABRIC)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.18, 0.62, 1.22), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), crimson, FABRIC)
		f.add(footName, "BootTrim", Vector3.new(f.sizes.foot.X * 0.9, 0.08 * s, f.sizes.foot.Z * 0.9), CFrame.new(0, -f.sizes.foot.Y * 0.28, 0), gold, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -0.52 * s, -0.12 * s))
end
HERO_EXTRAS.strange = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local teal, gold, amber = Color3.fromRGB(30, 150, 140), HC.gold, Color3.fromRGB(255, 200, 90)
	-- Mystic Sorcerer: flowing teal robes with golden amulet, high collar,
	-- levitation cloak and spell glyphs orbiting the left hand; silhouette
	-- reads as arcane master even at thumbnail size.
	-- Head: tall mystic hat with folded brim and temple ornaments.
	f.add("Head", "HatBrim", Vector3.new(h.X * 1.1, 0.12 * s, h.Z * 1.1), CFrame.new(0, h.Y * 0.48, 0), teal, FABRIC)
	f.add("Head", "HatCone", Vector3.new(h.X * 0.7, h.Y * 0.6, h.Z * 0.7), CFrame.new(0, h.Y * 0.78, 0) * CFrame.Angles(-0.1, 0, 0), teal, FABRIC, "wedge")
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "TempleOrnament", Vector3.new(0.1 * s, 0.32 * s, 0.28 * s), CFrame.new(side * h.X * 0.48, h.Y * 0.12, 0), gold, METAL)
	end
	-- Torso: layered robes with central amulet, high collar and sash;
	-- cape anchors at the shoulders with golden clasp.
	f.add("UpperTorso", "HighCollar", Vector3.new(c.X * 0.82, 0.22 * s, c.Z * 0.78), CFrame.new(0, c.Y * 0.46, 0), teal, FABRIC)
	f.disc("UpperTorso", "AmuletBase", 0.48 * s, 0.08 * s, CFrame.new(0, c.Y * 0.28, -c.Z / 2 - 0.05 * s), gold, METAL)
	f.disc("UpperTorso", "AmuletEye", 0.2 * s, 0.06 * s, CFrame.new(0, c.Y * 0.28, -c.Z / 2 - 0.1 * s), amber, NEON)
	for i = 1, 3 do
		local width = 1 - (i - 2) * 0.1
		f.add("LowerTorso", "RobeLayer" .. i, Vector3.new(c.X * 0.74 * width, 0.22 * s, 0.12 * s), CFrame.new(0, -c.Y * 0.2 + (i - 2) * 0.18 * s, -c.Z / 2 - 0.02 * s), teal, FABRIC)
	end
	belt(f, HC.leather, gold)
	cape(f, teal, 3.6, gold)
	-- Arms: wide sleeves with gold trim, forearm wraps and spell glyphs
	-- orbiting the left hand; right hand holds a mystic gesture.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Sleeve", f.sizes.upperArm * Vector3.new(1.24, 0.52, 1.2), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.08), teal, FABRIC)
		f.add(armName, "SleeveTrim", Vector3.new(f.sizes.upperArm.X * 1.04, 0.08 * s, f.sizes.upperArm.Z * 1.0), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.08), gold, METAL)
		f.add(forearmName, "Wrap", f.sizes.lowerArm * Vector3.new(1.14, 0.6, 1.12), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), teal, FABRIC)
		f.add(handName, "Glove", f.sizes.hand * Vector3.new(1.16, 0.7, 1.14), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), teal, FABRIC)
	end
	-- Spell glyphs orbit the left hand in a ring formation.
	for i = 0, 7 do
		local angle = i * math.pi / 4
		f.add("LeftHand", "SpellGlyph", Vector3.new(0.48 * s, 0.07 * s, 0.06 * s), CFrame.new(math.sin(angle) * 0.64 * s, -0.42 * s + math.cos(angle) * 0.64 * s, -0.52 * s) * CFrame.Angles(0, 0, -angle), gold, NEON)
	end
	-- Legs: robe skirts covering thigh plates, shin wraps and soft boots
	-- with gold buckles for silent mystical movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "RobeSkirt", f.sizes.upperLeg * Vector3.new(1.18, 0.7, 1.16), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), teal, FABRIC)
		f.add(lowerName, "ShinWrap", f.sizes.lowerLeg * Vector3.new(1.1, 0.68, 1.08), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), teal, FABRIC)
		f.add(footName, "SoftBoot", f.sizes.foot * Vector3.new(1.18, 0.62, 1.22), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), teal, FABRIC)
		f.add(footName, "BootBuckle", Vector3.new(f.sizes.foot.X * 0.5, 0.1 * s, f.sizes.foot.Z * 0.4), CFrame.new(0, -f.sizes.foot.Y * 0.22, -f.sizes.foot.Z * 0.2), gold, METAL)
	end
	muzzle(f, "LeftHand", Vector3.new(0, -0.42 * s, -0.62 * s))
end
HERO_EXTRAS.ghostrider = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local spirit, ember, ash = Color3.fromRGB(110, 230, 255), Color3.fromRGB(200, 80, 30), Color3.fromRGB(40, 36, 44)
	-- Hellfire Rider: skeletal helmet with blazing spirit visor, crown of
	-- ethereal flames, charred leather jacket with ember sigils and spiked
	-- pauldrons; silhouette reads as supernatural avenger even at distance.
	-- Head: skull-like helm with recessed glowing visor and flame crown.
	f.add("Head", "SkullBase", Vector3.new(h.X * 0.92, h.Y * 0.9, h.Z * 0.92), CFrame.new(), HC.white, METAL)
	f.add("Head", "SpiritVisor", Vector3.new(h.X * 0.72, 0.18 * s, 0.06 * s), f.face(0, 0.08, -0.04), spirit, NEON)
	for i = -1, 1 do
		local height = 0.72 - math.abs(i) * 0.14
		local flame = f.add("Head", "CrownFlame" .. i, Vector3.new(0.28 * s, height * s, 0.28 * s), CFrame.new(i * h.X * 0.24, h.Y * 0.58 + math.abs(i) * 0.06 * s, 0.04 * s), spirit:Lerp(HC.white, math.abs(i) * 0.18), NEON, "ball")
		flame.Transparency = 0.18
	end
	f.add("Head", "JawRidge", Vector3.new(h.X * 0.54, h.Y * 0.22, 0.1 * s), f.face(0, -0.44, -0.02), HC.steel, METAL, "wedge")
	-- Torso: charred riding jacket with central ember sigil, layered collar
	-- and harness straps; spine ridge hints at supernatural armor beneath.
	f.add("UpperTorso", "JacketBody", c * Vector3.new(1.08, 1.04, 1.1), CFrame.new(), ash, FABRIC)
	f.add("UpperTorso", "CollarLip", Vector3.new(c.X * 0.82, 0.18 * s, c.Z * 0.78), CFrame.new(0, c.Y * 0.48, 0), ash, FABRIC)
	f.add("UpperTorso", "EmberSigil", Vector3.new(0.42 * s, 0.42 * s, 0.06 * s), CFrame.new(0, c.Y * 0.14, -c.Z / 2 - 0.05 * s) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(255, 140, 50), NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, HC.leather, FABRIC)
	belt(f, HC.leather, HC.steel)
	-- Arms: spiked pauldrons with ember trim, forearm wraps and gauntlets;
	-- hands are gloved with reinforced knuckles for chain-whip combat.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "SpikedPauldron", f.sizes.upperArm * Vector3.new(1.24, 0.52, 1.22), CFrame.new(0, f.sizes.upperArm.Y * 0.3, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.12), ember, METAL, "wedge")
		f.add(armName, "EmberTrim", Vector3.new(f.sizes.upperArm.X * 1.04, 0.08 * s, f.sizes.upperArm.Z * 1.0), CFrame.new(0, f.sizes.upperArm.Y * 0.12, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.12), Color3.fromRGB(255, 140, 50), NEON)
		f.add(forearmName, "Wrap", f.sizes.lowerArm * Vector3.new(1.12, 0.6, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), ash, FABRIC)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.16, 0.7, 1.14), CFrame.new(0, -f.sizes.hand.Y * 0.08, 0), HC.steel, METAL)
	end
	-- Legs: thigh plates with knee caps and shin guards; boots are heavy
	-- and reinforced for motorcycle landings and hellfire stomps.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.16, 0.68, 1.14), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), ash, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.66, 0.22 * s, f.sizes.lowerLeg.Z * 0.58), CFrame.new(0, f.sizes.lowerLeg.Y * 0.42, -f.sizes.lowerLeg.Z * 0.26), HC.steel, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.1, 0.7, 1.08), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), ash, FABRIC)
		f.add(footName, "HeavyBoot", f.sizes.foot * Vector3.new(1.22, 0.66, 1.26), CFrame.new(0, -f.sizes.foot.Y * 0.12, 0), ash, FABRIC)
		f.add(footName, "BootBuckle", Vector3.new(f.sizes.foot.X * 0.5, 0.1 * s, f.sizes.foot.Z * 0.4), CFrame.new(0, -f.sizes.foot.Y * 0.24, -f.sizes.foot.Z * 0.2), HC.steel, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.captainmarvel = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local crimson, gold, photon = Color3.fromRGB(160, 30, 50), Color3.fromRGB(255, 200, 60), Color3.fromRGB(255, 220, 110)
	-- Nova Prime: regal flight suit with radiant sun emblem, golden sash,
	-- photon-charged gauntlets and aerodynamic helmet; silhouette reads as
	-- cosmic powerhouse even at thumbnail size.
	-- Head: an open face framed by the long hair; the star sits on the forehead.
	f.add("Head", "BrowStar", Vector3.new(0.2 * s, 0.2 * s, 0.06 * s), f.face(0, 0.64, 0.04) * CFrame.Angles(0, 0, math.pi / 4), gold, METAL)
	-- Torso: fitted flight suit with central sun emblem and radiating rays,
	-- diagonal sash and reinforced collar; belt anchors the waist.
	f.disc("UpperTorso", "SunEmblem", 0.32 * s, 0.07 * s, CFrame.new(0, c.Y * 0.16, -c.Z / 2 - 0.05 * s), gold, METAL)
	for i = 0, 7 do
		local angle = i * math.pi / 4
		f.add("UpperTorso", "SunRay" .. i, Vector3.new(0.08 * s, 0.24 * s, 0.05 * s), CFrame.new(math.sin(angle) * 0.44 * s, c.Y * 0.16 + math.cos(angle) * 0.44 * s, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, -angle), photon, NEON)
	end
	f.add("UpperTorso", "Sash", Vector3.new(c.X * 1.04, 0.22 * s, c.Z * 1.06), CFrame.new(0, -c.Y * 0.36, 0) * CFrame.Angles(0, 0, -0.18), gold, FABRIC)
	f.add("UpperTorso", "CollarReinforce", Vector3.new(c.X * 0.78, 0.18 * s, c.Z * 0.76), CFrame.new(0, c.Y * 0.46, 0), crimson, METAL)
	belt(f, HC.leather, gold)
	-- Arms: pauldrons with gold trim, forearm bracers and photon-charged
	-- gauntlets; hands glow with contained stellar energy.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.24, 0.52, 1.2), CFrame.new(0, f.sizes.upperArm.Y * 0.3, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), crimson, METAL, "wedge")
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.04, 0.08 * s, f.sizes.upperArm.Z * 1.0), CFrame.new(0, f.sizes.upperArm.Y * 0.12, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), gold, METAL)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), crimson, METAL)
		local fist = f.add(handName, "PhotonGauntlet", f.sizes.hand * Vector3.new(1.18, 0.72, 1.16), CFrame.new(0, -f.sizes.hand.Y * 0.08, 0), photon, NEON)
		fist.Transparency = 0.4
	end
	-- Legs: thigh plates with knee caps and shin guards; boots are
	-- reinforced for high-velocity landings with gold accent stripes.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.16, 0.68, 1.14), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), crimson, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.66, 0.22 * s, f.sizes.lowerLeg.Z * 0.58), CFrame.new(0, f.sizes.lowerLeg.Y * 0.42, -f.sizes.lowerLeg.Z * 0.26), gold, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.1, 0.7, 1.08), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), crimson, METAL)
		f.add(footName, "LandingBoot", f.sizes.foot * Vector3.new(1.2, 0.64, 1.24), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), crimson, METAL)
		f.add(footName, "BootStripe", Vector3.new(f.sizes.foot.X * 0.9, 0.08 * s, f.sizes.foot.Z * 0.9), CFrame.new(0, -f.sizes.foot.Y * 0.28, 0), gold, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.silversurfer = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local chrome, cosmic, starlight = Color3.fromRGB(200, 210, 220), Color3.fromRGB(100, 180, 255), Color3.fromRGB(255, 230, 140)
	-- Cosmic Herald: sleek metallic skin with orbiting energy rings,
	-- celestial crest and glowing moon orb; silhouette reads as silver
	-- sentinel even at thumbnail size.
	-- Head: smooth helm with raised crest fin and recessed eye band.
	f.add("Head", "HelmShell", Vector3.new(h.X * 0.92, h.Y * 0.9, h.Z * 0.92), CFrame.new(), chrome, METAL)
	f.add("Head", "CrestFin", Vector3.new(0.1 * s, h.Y * 0.44, h.Z * 0.86), CFrame.new(0, h.Y * 0.4, 0), chrome, METAL, "wedge")
	f.add("Head", "EyeBand", Vector3.new(h.X * 0.78, 0.14 * s, 0.06 * s), f.face(0, 0.12, -0.02), cosmic, NEON)
	-- Torso: seamless metallic torso with orbiting energy rings and
	-- central cosmic sigil; no fabric or seams to break the flow.
	f.add("UpperTorso", "CosmicSigil", Vector3.new(0.28 * s, 0.28 * s, 0.06 * s), CFrame.new(0, c.Y * 0.16, -c.Z / 2 - 0.04 * s), starlight, NEON)
	local orbitRadius = 1.52 * s
	for i = 0, 11 do
		local a0 = i * math.pi / 6
		local a1 = (i + 1) * math.pi / 6
		f.rod("UpperTorso", "OrbitSegment" .. i, Vector3.new(math.cos(a0) * orbitRadius, 0.92 * s, math.sin(a0) * orbitRadius), Vector3.new(math.cos(a1) * orbitRadius, 0.92 * s, math.sin(a1) * orbitRadius), 0.07 * s, starlight, NEON)
	end
	f.add("UpperTorso", "MoonOrb", Vector3.new(0.38 * s, 0.38 * s, 0.38 * s), CFrame.new(orbitRadius, 0.92 * s, 0), starlight, NEON, "ball")
	-- Arms: seamless metallic limbs with subtle joint rings; hands are
	-- smooth gauntlets that channel cosmic energy.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "JointRing", Vector3.new(f.sizes.upperArm.X * 1.02, 0.06 * s, f.sizes.upperArm.Z * 1.02), CFrame.new(0, -f.sizes.upperArm.Y * 0.46, 0), cosmic, METAL)
		f.add(forearmName, "JointRing", Vector3.new(f.sizes.lowerArm.X * 1.02, 0.06 * s, f.sizes.lowerArm.Z * 1.02), CFrame.new(0, -f.sizes.lowerArm.Y * 0.46, 0), cosmic, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.1, 0.66, 1.1), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), chrome, METAL)
	end
	-- Legs: seamless metallic legs with knee caps and smooth boots;
	-- no fabric or armor plates to interrupt the silver flow.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.62, 0.18 * s, f.sizes.lowerLeg.Z * 0.54), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), cosmic, METAL, "ball")
		f.add(footName, "SmoothBoot", f.sizes.foot * Vector3.new(1.14, 0.6, 1.18), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), chrome, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.wolverine = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local stripe, orange, bone = Color3.fromRGB(30, 24, 22), Color3.fromRGB(235, 130, 40), Color3.fromRGB(240, 232, 214)
	-- Berserker Feral: tiger-striped suit with pointed ear tufts, mask
	-- fins and three adamantium claws per hand; silhouette reads as
	-- feral predator even at thumbnail size.
	-- Head: masked face with angular eye slits, cheek guards and tall
	-- ear tufts that break the head outline.
	f.add("Head", "MaskBase", Vector3.new(h.X * 0.9, h.Y * 0.86, h.Z * 0.9), CFrame.new(), stripe, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyeSlit", Vector3.new(h.X * 0.24, h.Y * 0.18, 0.06 * s), f.face(side * 0.22, 0.12, -0.02), orange, NEON, "wedge")
		f.add("Head", "CheekGuard", Vector3.new(h.X * 0.18, h.Y * 0.32, 0.1 * s), CFrame.new(side * h.X * 0.38, h.Y * 0.06, -0.02 * s) * CFrame.Angles(0, 0, -side * 0.25), orange, FABRIC, "wedge")
		f.add("Head", "EarTuft", Vector3.new(0.14 * s, 0.48 * s, 0.32 * s), CFrame.new(side * h.X * 0.44, h.Y * 0.52, 0) * CFrame.Angles(0, 0, -side * 0.32), orange, FABRIC, "wedge")
	end
	-- Torso: fitted suit with diagonal tiger stripes across the chest
	-- and abdomen; belt anchors the waist with gold buckle.
	for i = 0, 2 do
		for _, side in ipairs({ -1, 1 }) do
			f.add("UpperTorso", "TigerStripe" .. i .. (side < 0 and "L" or "R"), Vector3.new(0.52 * s, 0.12 * s, 0.07 * s), CFrame.new(side * c.X * 0.34, c.Y * (0.3 - i * 0.24), -c.Z / 2 - 0.03 * s) * CFrame.Angles(0, 0, side * 0.36), stripe, FABRIC)
		end
	end
	belt(f, stripe, HC.gold)
	-- Arms: shoulder pads with orange trim, forearm wraps and gauntlets;
	-- three adamantium claws extend from each knuckle row.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "ShoulderPad", f.sizes.upperArm * Vector3.new(1.18, 0.46, 1.14), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), orange, FABRIC)
		f.add(forearmName, "Wrap", f.sizes.lowerArm * Vector3.new(1.1, 0.58, 1.08), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), stripe, FABRIC)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.68, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), stripe, FABRIC)
		for i = 0, 2 do
			f.add(handName, "AdamantiumClaw" .. i, Vector3.new(0.06 * s, 0.68 * s, 0.08 * s), CFrame.new((i - 1) * 0.22 * s, -f.sizes.hand.Y / 2 - 0.36 * s, -0.14 * s), bone, METAL)
		end
	end
	-- Legs: thigh plates with knee caps and shin guards; boots are
	-- reinforced for feral pounces and clawed landings.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), stripe, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), orange, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), stripe, FABRIC)
		f.add(footName, "FeralBoot", f.sizes.foot * Vector3.new(1.18, 0.62, 1.22), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), stripe, FABRIC)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.68 * s, -0.14 * s))
end
HERO_EXTRAS.cyclops = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local ruby, blue, steel = Color3.fromRGB(214, 60, 52), Color3.fromRGB(30, 80, 180), Color3.fromRGB(232, 236, 242)
	-- Optic Blaster: tactical visor with ruby quartz lens, segmented
	-- blue/steel armor and utility belt; silhouette reads as precision
	-- leader even at thumbnail size.
	-- Head: streamlined helm with chin guard and wide optic visor.
	f.add("Head", "HelmetShell", Vector3.new(h.X * 0.92, h.Y * 0.88, h.Z * 0.92), CFrame.new(), blue, METAL)
	f.add("Head", "OpticVisor", Vector3.new(h.X * 0.88, 0.22 * s, 0.12 * s), f.face(0, 0.14, -0.02), ruby, NEON)
	f.add("Head", "ChinGuard", Vector3.new(h.X * 0.54, h.Y * 0.26, 0.1 * s), f.face(0, -0.48, 0.02), steel, METAL, "wedge")
	-- Torso: fitted chest plate with central seam, abdominal segments
	-- and utility belt; harness straps cross the torso.
	f.add("UpperTorso", "ChestPlate", Vector3.new(c.X * 0.88, c.Y * 0.82, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), blue, METAL)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, steel, METAL)
	for i = 1, 3 do
		local width = 1 - (i - 2) * 0.1
		f.add("LowerTorso", "AbdomenSegment" .. i, Vector3.new(c.X * 0.68 * width, 0.18 * s, 0.1 * s), CFrame.new(0, -c.Y * 0.2 + (i - 2) * 0.16 * s, -c.Z / 2 - 0.02 * s), blue, METAL)
	end
	belt(f, ruby, steel)
	-- Arms: pauldrons with steel trim, forearm bracers and gauntlets;
	-- hands are gloved for optic blast control.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.2, 0.48, 1.16), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), blue, METAL, "wedge")
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.02, 0.07 * s, f.sizes.upperArm.Z * 0.98), CFrame.new(0, f.sizes.upperArm.Y * 0.12, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), steel, METAL)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.1, 0.56, 1.08), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), blue, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.12, 0.66, 1.1), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), steel, METAL)
	end
	-- Legs: thigh plates with knee caps and shin guards; boots are
	-- reinforced for tactical movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), blue, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), steel, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), blue, METAL)
		f.add(footName, "TacticalBoot", f.sizes.foot * Vector3.new(1.18, 0.62, 1.22), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), blue, METAL)
	end
	muzzle(f, "Head", Vector3.new(0, h.Y * 0.07, -h.Z / 2 - 0.2 * s))
end
HERO_EXTRAS.storm = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local sky, silver, gold = Color3.fromRGB(30, 120, 140), Color3.fromRGB(200, 210, 220), HC.gold
	-- Tempest Queen: flowing white gown with golden tiara, billowing cape
	-- and lightning-charged hands; silhouette reads as weather sovereign
	-- even at thumbnail size.
	-- Head: regal tiara with central gem and side wings; hair flows back.
	local band = circlet(f, "TiaraBase", gold)
	f.add("Head", "TiaraGem", Vector3.new(0.16 * s, 0.16 * s, 0.08 * s), f.face(0, band, 0.1), sky, NEON, "ball")
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "TiaraWing", Vector3.new(0.08 * s, 0.3 * s, 0.26 * s), CFrame.new(side * h.X * 0.58, h.Y * 0.42, -h.Z * 0.1) * CFrame.Angles(0, 0, side * 0.5), gold, METAL, "wedge")
	end
	-- Torso: fitted bodice with silver trim, layered skirt segments and
	-- sash; cape anchors at the shoulders with golden clasps.
	f.add("UpperTorso", "BodiceFront", Vector3.new(c.X * 0.86, c.Y * 0.8, 0.1 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), HC.white, FABRIC)
	f.add("UpperTorso", "SilverTrim", Vector3.new(c.X * 0.88, 0.1 * s, 0.08 * s), CFrame.new(0, c.Y * 0.38, -c.Z / 2 - 0.03 * s), silver, METAL)
	for i = 1, 3 do
		local width = 1 - (i - 2) * 0.1
		f.add("LowerTorso", "SkirtSegment" .. i, Vector3.new(c.X * 0.74 * width, 0.22 * s, 0.12 * s), CFrame.new(0, -c.Y * 0.2 + (i - 2) * 0.18 * s, -c.Z / 2 - 0.02 * s), HC.white, FABRIC)
	end
	belt(f, HC.leather, gold)
	cape(f, sky, 3.6, gold)
	-- Arms: pauldrons with silver trim, forearm bracers and gauntlets;
	-- hands crackle with contained storm energy.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.2, 0.48, 1.16), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), HC.white, FABRIC)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.02, 0.07 * s, f.sizes.upperArm.Z * 0.98), CFrame.new(0, f.sizes.upperArm.Y * 0.12, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), silver, METAL)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.1, 0.56, 1.08), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), HC.white, FABRIC)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.12, 0.66, 1.1), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), silver, METAL)
	end
	-- Legs: thigh plates with knee caps and shin guards; boots are
	-- elegant with silver trim for silent storm movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), HC.white, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), silver, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), HC.white, FABRIC)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), HC.white, FABRIC)
		f.add(footName, "BootTrim", Vector3.new(f.sizes.foot.X * 0.9, 0.08 * s, f.sizes.foot.Z * 0.9), CFrame.new(0, -f.sizes.foot.Y * 0.28, 0), silver, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.jean = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local rose, phoenix, psychic = Color3.fromRGB(255, 150, 210), Color3.fromRGB(255, 100, 60), Color3.fromRGB(200, 140, 255)
	-- Phoenix Host: regal rose gown with phoenix emblem, flowing cape and
	-- psychic flames hovering above both palms; silhouette reads as
	-- telekinetic sovereign even at thumbnail size.
	-- Head: circlet with central gem and side ornaments; hair flows back.
	local band = circlet(f, "CircletBase", HC.gold)
	f.add("Head", "CircletGem", Vector3.new(0.16 * s, 0.16 * s, 0.08 * s), f.face(0, band, 0.1), phoenix, NEON, "ball")
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "CircletOrnament", Vector3.new(0.08 * s, 0.24 * s, 0.2 * s), CFrame.new(side * h.X * 0.58, h.Y * 0.4, -h.Z * 0.1) * CFrame.Angles(0, 0, side * 0.4), HC.gold, METAL, "wedge")
	end
	-- Torso: fitted bodice with phoenix emblem, layered skirt segments
	-- and sash; cape anchors at the shoulders with golden clasps.
	f.add("UpperTorso", "PhoenixEmblem", Vector3.new(0.52 * s, 0.38 * s, 0.07 * s), CFrame.new(0, c.Y * 0.18, -c.Z / 2 - 0.04 * s), phoenix, METAL, "wedge")
	for i = 1, 3 do
		local width = 1 - (i - 2) * 0.1
		f.add("LowerTorso", "SkirtSegment" .. i, Vector3.new(c.X * 0.74 * width, 0.22 * s, 0.12 * s), CFrame.new(0, -c.Y * 0.2 + (i - 2) * 0.18 * s, -c.Z / 2 - 0.02 * s), rose, FABRIC)
	end
	belt(f, rose, HC.gold)
	cape(f, rose, 3.4, HC.gold)
	-- Arms: pauldrons with gold trim, forearm bracers and gauntlets;
	-- psychic flames hover above both palms.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.2, 0.48, 1.16), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), rose, FABRIC)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.02, 0.07 * s, f.sizes.upperArm.Z * 0.98), CFrame.new(0, f.sizes.upperArm.Y * 0.12, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), HC.gold, METAL)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.1, 0.56, 1.08), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), rose, FABRIC)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.12, 0.66, 1.1), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), rose, FABRIC)
		local flame = f.add(handName, "PsychicFlame", Vector3.new(0.52 * s, 0.72 * s, 0.52 * s), CFrame.new(0, -0.48 * s, 0), psychic, NEON, "ball")
		flame.Transparency = 0.28
	end
	-- Legs: thigh plates with knee caps and shin guards; boots are
	-- elegant with gold trim for silent psychic movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), rose, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), HC.gold, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), rose, FABRIC)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), rose, FABRIC)
		f.add(footName, "BootTrim", Vector3.new(f.sizes.foot.X * 0.9, 0.08 * s, f.sizes.foot.Z * 0.9), CFrame.new(0, -f.sizes.foot.Y * 0.28, 0), HC.gold, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -0.52 * s, 0))
end
HERO_EXTRAS.iceman = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local ice, frost, crystal = Color3.fromRGB(210, 246, 255), Color3.fromRGB(160, 220, 255), Color3.fromRGB(230, 250, 255)
	-- Cryokinetic: living ice form with crystalline spikes, frost aura
	-- and glacial gauntlets; silhouette reads as elemental force even
	-- at thumbnail size.
	-- Head: icy crown with three central spikes and frosted brow ridge.
	for i = -1, 1 do
 local height = 0.48 - math.abs(i) * 0.12
 f.add("Head", "IceSpike" .. i, Vector3.new(0.22 * s, height * s, 0.32 * s), CFrame.new(i * 0.36 * s, h.Y * 0.56 + math.abs(i) * 0.04 * s, 0) * CFrame.Angles(0, 0, -i * 0.28), ice, Enum.Material.Ice, "wedge")
	end
	f.add("Head", "FrostBrow", Vector3.new(h.X * 0.82, h.Y * 0.16, h.Z * 0.22), CFrame.new(0, h.Y * 0.34, -h.Z * 0.1), frost, Enum.Material.Ice)
	-- Torso: segmented ice armor with crystalline chest plate and
	-- abdominal ridges; no fabric, only frozen surfaces.
	f.add("UpperTorso", "ChestCrystal", Vector3.new(c.X * 0.86, c.Y * 0.78, 0.14 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), crystal, Enum.Material.Ice)
	for i = 1, 3 do
 local width = 1 - (i - 2) * 0.12
 f.add("LowerTorso", "AbdomenRidge" .. i, Vector3.new(c.X * 0.66 * width, 0.2 * s, 0.12 * s), CFrame.new(0, -c.Y * 0.2 + (i - 2) * 0.18 * s, -c.Z / 2 - 0.02 * s), ice, Enum.Material.Ice)
	end
	-- Arms: icy pauldrons with frost trim, forearm bracers and glacial
	-- gauntlets; right hand encased in oversized ice fist.
	for _, side in ipairs({ -1, 1 }) do
 local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
 local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
 local handName = side < 0 and "LeftHand" or "RightHand"
 f.add(armName, "IcePauldron", f.sizes.upperArm * Vector3.new(1.22, 0.5, 1.18), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), ice, Enum.Material.Ice, "wedge")
 f.add(armName, "FrostTrim", Vector3.new(f.sizes.upperArm.X * 1.04, 0.08 * s, f.sizes.upperArm.Z * 1.0), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), frost, Enum.Material.Ice)
 f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), ice, Enum.Material.Ice)
 f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.68, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), crystal, Enum.Material.Ice)
	end
	local iceFist = f.add("RightHand", "IceFist", Vector3.new(0.82 * s, 0.82 * s, 0.82 * s), CFrame.new(0, -0.12 * s, 0), ice, Enum.Material.Ice, "ball")
	iceFist.Transparency = 0.22
	-- Legs: thigh plates with knee caps and shin guards; boots are
	-- solid ice with frost accents for silent glacial movement.
	for _, side in ipairs({ -1, 1 }) do
 local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
 local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
 local footName = side < 0 and "LeftFoot" or "RightFoot"
 f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.16, 0.68, 1.14), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), ice, Enum.Material.Ice)
 f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.66, 0.22 * s, f.sizes.lowerLeg.Z * 0.58), CFrame.new(0, f.sizes.lowerLeg.Y * 0.42, -f.sizes.lowerLeg.Z * 0.26), crystal, Enum.Material.Ice, "ball")
 f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.1, 0.7, 1.08), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), ice, Enum.Material.Ice)
 f.add(footName, "IceBoot", f.sizes.foot * Vector3.new(1.18, 0.62, 1.22), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), ice, Enum.Material.Ice)
 f.add(footName, "FrostAccent", Vector3.new(f.sizes.foot.X * 0.9, 0.08 * s, f.sizes.foot.Z * 0.9), CFrame.new(0, -f.sizes.foot.Y * 0.28, 0), frost, Enum.Material.Ice)
	end
	muzzle(f, "RightHand", Vector3.new(0, -0.52 * s, 0))
end
HERO_EXTRAS.gambit = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local crimson, ash, charge = Color3.fromRGB(200, 40, 60), Color3.fromRGB(36, 36, 46), Color3.fromRGB(255, 210, 80)
	-- Bayou Rogue: armored trench coat with high collar, crimson cowl
	-- with glowing eyes and charged kinetic cards; silhouette reads as
	-- suave thief even at thumbnail size.
	-- Head: sleek cowl covering upper face with angular eye lenses and
	-- chin guard exposing the jaw.
	f.add("Head", "CowlBase", Vector3.new(h.X * 0.94, h.Y * 0.58, h.Z * 0.94), CFrame.new(0, h.Y * 0.32, 0.02 * s), crimson, FABRIC, "ball")
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyeLens", Vector3.new(h.X * 0.26, h.Y * 0.18, 0.06 * s), f.face(side * 0.24, 0.14, -0.02), charge, NEON, "wedge")
	end
	f.add("Head", "ChinGuard", Vector3.new(h.X * 0.52, h.Y * 0.22, 0.1 * s), f.face(0, -0.48, 0.02), ash, METAL, "wedge")
	-- Torso: long trench coat with layered collar, chest harness and
	-- belt; coat tails extend below the waist for dramatic flow.
	f.add("UpperTorso", "TrenchCoatBody", Vector3.new(c.X * 1.1, c.Y * 1.92, c.Z * 1.14), CFrame.new(0, -c.Y * 0.44, 0.02 * s), ash, FABRIC)
	f.add("UpperTorso", "HighCollar", Vector3.new(c.X * 0.84, 0.2 * s, c.Z * 0.8), CFrame.new(0, c.Y * 0.48, 0), ash, FABRIC)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.32, c.Y * 0.36, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.32, -c.Y * 0.32, -c.Z / 2 - 0.04 * s), 0.1 * s, HC.leather, FABRIC)
	belt(f, HC.leather, HC.steel)
	-- Arms: shoulder pads with crimson trim, forearm bracers and
	-- gauntlets; right hand holds a glowing kinetic card.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "ShoulderPad", f.sizes.upperArm * Vector3.new(1.2, 0.48, 1.16), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), ash, FABRIC)
		f.add(armName, "ShoulderTrim", Vector3.new(f.sizes.upperArm.X * 1.02, 0.07 * s, f.sizes.upperArm.Z * 0.98), CFrame.new(0, f.sizes.upperArm.Y * 0.12, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), crimson, FABRIC)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), ash, FABRIC)
		f.add(handName, "Glove", f.sizes.hand * Vector3.new(1.14, 0.68, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), ash, FABRIC)
	end
	f.add("RightHand", "ChargedCard", Vector3.new(0.38 * s, 0.52 * s, 0.05 * s), CFrame.new(0, -0.42 * s, -0.16 * s), charge, NEON)
	-- Legs: thigh plates with knee caps and shin guards; boots are
	-- reinforced for agile rooftop movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.16, 0.68, 1.14), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), ash, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.66, 0.22 * s, f.sizes.lowerLeg.Z * 0.58), CFrame.new(0, f.sizes.lowerLeg.Y * 0.42, -f.sizes.lowerLeg.Z * 0.26), HC.steel, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.1, 0.7, 1.08), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), ash, FABRIC)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.18, 0.62, 1.22), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), ash, FABRIC)
	end
	muzzle(f, "RightHand", Vector3.new(0, -0.52 * s, -0.16 * s))
end
HERO_EXTRAS.nightcrawler = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local indigo, gold, glow = Color3.fromRGB(40, 30, 80), Color3.fromRGB(255, 214, 90), Color3.fromRGB(255, 240, 100)
	-- Bamf Acrobat: agile indigo suit with golden belt and prehensile
	-- tail; pointed ears and glowing yellow eyes sell the mutant
	-- teleporter silhouette even at thumbnail size.
	-- Head: masked face with pointed ears, angular eye lenses and
	-- chin strap; hair swept back in a widow's peak.
	f.add("Head", "MaskBase", Vector3.new(h.X * 0.9, h.Y * 0.88, h.Z * 0.9), CFrame.new(), indigo, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "PointedEar", Vector3.new(0.14 * s, 0.32 * s, 0.12 * s), CFrame.new(side * h.X * 0.46, h.Y * 0.38, -0.04 * s) * CFrame.Angles(0, 0, -side * 0.4), indigo, FABRIC, "wedge")
		f.add("Head", "EyeLens", Vector3.new(h.X * 0.24, h.Y * 0.18, 0.06 * s), f.face(side * 0.22, 0.12, -0.02), glow, NEON, "ball")
	end
	f.add("Head", "ChinStrap", Vector3.new(h.X * 0.5, h.Y * 0.14, 0.08 * s), f.face(0, -0.48, -0.02), gold, METAL)
	-- Torso: fitted acrobat suit with central seam, diagonal harness
	-- and golden belt; no bulky armor to impede agility.
	f.add("UpperTorso", "SuitFront", Vector3.new(c.X * 0.86, c.Y * 0.82, 0.1 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), indigo, FABRIC)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, gold, METAL)
	belt(f, indigo, gold)
	-- Arms: lightweight shoulder pads, forearm wraps and gloves;
	-- hands are nimble for card-throwing and teleport gestures.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "ShoulderPad", f.sizes.upperArm * Vector3.new(1.14, 0.42, 1.1), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.08), indigo, FABRIC)
		f.add(forearmName, "Wrap", f.sizes.lowerArm * Vector3.new(1.08, 0.54, 1.06), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), indigo, FABRIC)
		f.add(handName, "Glove", f.sizes.hand * Vector3.new(1.12, 0.64, 1.1), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), indigo, FABRIC)
	end
	-- Tail: segmented prehensile appendage with tapered tip; anchors
	-- at the pelvis and curves behind for balance and expression.
	f.add("LowerTorso", "TailBase", Vector3.new(0.16 * s, 0.16 * s, 0.8 * s), CFrame.new(0, -0.08 * s, f.sizes.pelvis.Z / 2 + 0.4 * s) * CFrame.Angles(-0.6, 0, 0), indigo, FABRIC)
	f.add("LowerTorso", "TailMid", Vector3.new(0.14 * s, 0.14 * s, 0.9 * s), CFrame.new(0, -0.12 * s, f.sizes.pelvis.Z / 2 + 1.1 * s) * CFrame.Angles(-0.9, 0, 0), indigo, FABRIC)
	f.add("LowerTorso", "TailTip", Vector3.new(0.28 * s, 0.28 * s, 0.12 * s), CFrame.new(0, 0.68 * s, f.sizes.pelvis.Z / 2 + 1.78 * s) * CFrame.Angles(0, 0, math.pi / 4), gold, METAL, "ball")
	-- Legs: thigh wraps with knee caps and shin guards; boots are
	-- soft-soled for silent landings after bamf teleports.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighWrap", f.sizes.upperLeg * Vector3.new(1.12, 0.64, 1.1), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), indigo, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.62, 0.18 * s, f.sizes.lowerLeg.Z * 0.54), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), gold, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.06, 0.66, 1.04), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), indigo, FABRIC)
		f.add(footName, "SoftBoot", f.sizes.foot * Vector3.new(1.14, 0.58, 1.18), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), indigo, FABRIC)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.beast = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local azure, fur, steel = Color3.fromRGB(60, 100, 180), Color3.fromRGB(232, 180, 90), HC.steel
	-- Feral Genius: muscular blue-furred physique with tactical harness,
	-- oversized furry fists and prominent fangs; silhouette reads as
	-- agile brute even at thumbnail size.
	-- Head: feline muzzle with brow ridge, glowing eyes and lower fangs.
	f.add("Head", "MuzzleBase", Vector3.new(h.X * 0.72, h.Y * 0.42, h.Z * 0.6), CFrame.new(0, -h.Y * 0.18, -h.Z * 0.12), azure, FABRIC)
	f.add("Head", "BrowRidge", Vector3.new(h.X * 0.84, h.Y * 0.18, h.Z * 0.28), CFrame.new(0, h.Y * 0.32, -h.Z * 0.08), azure, FABRIC, "wedge")
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyeGlow", Vector3.new(0.14 * s, 0.12 * s, 0.06 * s), f.face(side * 0.22, 0.14, -0.02), Color3.fromRGB(255, 220, 80), NEON, "ball")
		f.add("Head", "EarTuft", Vector3.new(0.12 * s, 0.28 * s, 0.1 * s), CFrame.new(side * h.X * 0.42, h.Y * 0.48, -0.02 * s) * CFrame.Angles(0, 0, -side * 0.3), fur, FABRIC, "wedge")
	end
	f.add("Head", "LowerFang", Vector3.new(0.38 * s, 0.12 * s, 0.06 * s), f.face(0, -0.48, 0.04), HC.white, METAL, "wedge")
	-- Torso: barrel chest with tactical harness straps and belt; no
	-- fabric shirt to hide the muscular blue fur texture.
	f.add("UpperTorso", "ChestFur", Vector3.new(c.X * 0.9, c.Y * 0.84, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), azure, FABRIC)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.36, c.Y * 0.4, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.36, -c.Y * 0.36, -c.Z / 2 - 0.04 * s), 0.12 * s, steel, METAL)
	belt(f, HC.leather, steel)
	-- Arms: massive shoulder muscles, forearm wraps and oversized furry
	-- fists that sell the punch impact and dexterity.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "ShoulderMuscle", f.sizes.upperArm * Vector3.new(1.26, 0.56, 1.22), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), azure, FABRIC)
		f.add(forearmName, "Wrap", f.sizes.lowerArm * Vector3.new(1.14, 0.6, 1.12), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), azure, FABRIC)
		f.add(handName, "FurryFist", f.sizes.hand * Vector3.new(1.24, 0.78, 1.2), CFrame.new(0, -f.sizes.hand.Y * 0.08, 0), fur, FABRIC, "ball")
	end
	-- Legs: powerful thigh muscles with knee caps and shin guards;
	-- boots are reinforced for acrobatic landings.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighMuscle", f.sizes.upperLeg * Vector3.new(1.2, 0.72, 1.18), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), azure, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.68, 0.22 * s, f.sizes.lowerLeg.Z * 0.6), CFrame.new(0, f.sizes.lowerLeg.Y * 0.42, -f.sizes.lowerLeg.Z * 0.26), steel, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.12, 0.72, 1.1), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), azure, FABRIC)
		f.add(footName, "AcroBoot", f.sizes.foot * Vector3.new(1.2, 0.64, 1.24), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), azure, FABRIC)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.psylocke = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local violet, steel, psychic = Color3.fromRGB(120, 40, 160), HC.steel, Color3.fromRGB(255, 120, 90)
	-- Shadow Blade: sleek ninja suit with violet accents, face mask band,
	-- glowing psychic blade and flowing sash; silhouette reads as
	-- stealthy assassin even at thumbnail size.
	-- Head: masked face with angular eye lenses and headband crest.
	f.add("Head", "MaskBase", Vector3.new(h.X * 0.9, h.Y * 0.86, h.Z * 0.9), CFrame.new(), HC.ink, FABRIC)
	f.add("Head", "MaskBand", Vector3.new(h.X * 0.92, 0.22 * s, 0.07 * s), f.face(0, 0.14, 0.03), violet, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyeLens", Vector3.new(h.X * 0.24, h.Y * 0.18, 0.06 * s), f.face(side * 0.22, 0.12, -0.02), psychic, NEON, "wedge")
	end
	f.add("Head", "HeadbandCrest", Vector3.new(0.1 * s, h.Y * 0.32, h.Z * 0.88), CFrame.new(0, h.Y * 0.36, 0), steel, METAL, "wedge")
	-- Torso: fitted bodysuit with central seam, diagonal sash and
	-- tactical harness; belt secures the waist with steel buckle.
	f.add("UpperTorso", "SuitFront", Vector3.new(c.X * 0.86, c.Y * 0.82, 0.1 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), HC.ink, FABRIC)
	f.add("UpperTorso", "Sash", Vector3.new(c.X * 1.04, 0.24 * s, c.Z * 1.06), CFrame.new(0, -c.Y * 0.36, 0) * CFrame.Angles(0, 0, -0.18), violet, FABRIC)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, steel, METAL)
	belt(f, HC.leather, steel)
	-- Arms: shoulder pads with violet trim, forearm bracers and gauntlets;
	-- right hand grips the glowing psychic blade.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "ShoulderPad", f.sizes.upperArm * Vector3.new(1.18, 0.46, 1.14), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.08), HC.ink, FABRIC)
		f.add(armName, "ShoulderTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.07 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.12, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.08), violet, FABRIC)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.1, 0.56, 1.08), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), HC.ink, FABRIC)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.12, 0.66, 1.1), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), HC.ink, FABRIC)
	end
	f.add("RightHand", "PsychicBlade", Vector3.new(0.14 * s, 1.42 * s, 0.32 * s), CFrame.new(0, -0.82 * s, -0.12 * s), psychic, NEON)
	-- Legs: thigh plates with knee caps and shin guards; boots are
	-- streamlined for silent acrobatic movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), HC.ink, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), steel, METAL, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), HC.ink, FABRIC)
		f.add(footName, "NinjaBoot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), HC.ink, FABRIC)
	end
	muzzle(f, "RightHand", Vector3.new(0, -1.42 * s, -0.12 * s))
end
HERO_EXTRAS.deadpool = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local crimson, black, neonYellow = Color3.fromRGB(180, 30, 40), Color3.fromRGB(24, 28, 39), Color3.fromRGB(255, 220, 60)
	-- Merc with a Mouth: tactical red/black suit with glowing yellow accents,
	-- expressive mask eyes and dual katanas; silhouette reads as chaotic
	-- antihero even at thumbnail size.
	-- Head: full mask with large expressive eyes and grin line.
	f.add("Head", "MaskShell", Vector3.new(h.X * 0.94, h.Y * 0.92, h.Z * 0.94), CFrame.new(), crimson, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyePatch", Vector3.new(h.X * 0.32, h.Y * 0.28, 0.06 * s), f.face(side * 0.24, 0.12, -0.02), black, FABRIC)
		f.add("Head", "EyeGlow", Vector3.new(h.X * 0.22, h.Y * 0.18, 0.05 * s), f.face(side * 0.24, 0.12, -0.04), neonYellow, NEON, "ball")
	end
	f.add("Head", "GrinLine", Vector3.new(h.X * 0.5, 0.06 * s, 0.04 * s), f.face(0, -0.38, 0.02), black, FABRIC)
	-- Torso: tactical vest with central seam, diagonal harness and
	-- utility belt; confetti dots replaced with neon accent lines.
	f.add("UpperTorso", "TacticalVest", Vector3.new(c.X * 0.9, c.Y * 0.84, 0.13 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), crimson, METAL)
	f.add("UpperTorso", "CoreSeam", Vector3.new(0.07 * s, c.Y * 0.58, 0.04 * s), CFrame.new(0, 0, -c.Z / 2 - 0.05 * s), neonYellow, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, black, METAL)
	belt(f, black, neonYellow)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and gauntlets;
	-- both hands grip katanas with glowing hilts.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), crimson, METAL)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonYellow, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), crimson, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), black, METAL)
		f.add(handName, "KatanaHilt", Vector3.new(0.12 * s, 0.4 * s, 0.12 * s), CFrame.new(0, -0.5 * s, -0.1 * s), neonYellow, NEON)
		f.rod(handName, "KatanaBlade", Vector3.new(0, -0.5 * s, -0.1 * s), Vector3.new(0, -1.6 * s, -0.1 * s), 0.06 * s, HC.steel, METAL)
	end
	-- Legs: armored thigh plates with glowing knee caps and shin guards;
	-- boots are reinforced for acrobatic combat.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), crimson, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonYellow, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), crimson, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), black, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -1.6 * s, -0.1 * s))
end
HERO_EXTRAS.moonknight = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local white, silver, neonGold = Color3.fromRGB(240, 240, 245), HC.steel, Color3.fromRGB(255, 220, 100)
	-- Lunar Vigilante: flowing white hooded suit with silver armor accents,
	-- glowing crescent emblem and dark cape; silhouette reads as mystical
	-- avenger even at thumbnail size.
	-- Head: deep hood with glowing eye lenses and silver trim.
	f.add("Head", "HoodShell", f.parts.Head.Size * Vector3.new(1.14, 1.12, 1.02), CFrame.new(0, 0.04 * s, f.parts.Head.Size.Z * 0.24), white, FABRIC, "ball")
	f.add("Head", "HoodTrim", Vector3.new(h.X * 0.96, 0.12 * s, 0.06 * s), f.face(0, 0.32, -0.02), silver, METAL)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyeLens", Vector3.new(h.X * 0.26, h.Y * 0.2, 0.06 * s), f.face(side * 0.22, 0.12, -0.02), neonGold, NEON, "wedge")
	end
	-- Torso: fitted white suit with central crescent emblem, diagonal
	-- harness and utility belt; dark cape anchors at the shoulders.
	f.add("UpperTorso", "SuitFront", Vector3.new(c.X * 0.88, c.Y * 0.82, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), white, FABRIC)
	f.add("UpperTorso", "CrescentEmblem", Vector3.new(0.5 * s, 0.5 * s, 0.06 * s), CFrame.new(0, c.Y * 0.16, -c.Z / 2 - 0.03 * s), neonGold, METAL, "ball")
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, silver, METAL)
	belt(f, silver, neonGold)
	cape(f, Color3.fromRGB(28, 30, 42), 3.6, silver)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and gauntlets;
	-- hands are gloved for stealth combat.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), white, FABRIC)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonGold, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), white, FABRIC)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), silver, METAL)
	end
	-- Legs: armored thigh plates with glowing knee caps and shin guards;
	-- boots are reinforced for silent movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), white, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonGold, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), white, FABRIC)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), silver, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.nova = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local cosmic, gold, neonBlue = Color3.fromRGB(20, 40, 80), HC.gold, Color3.fromRGB(80, 210, 240)
	-- Cosmic Centurion: sleek blue/gold armor with glowing star emblem,
	-- streamlined helmet and energy aura; silhouette reads as space
	-- guardian even at thumbnail size.
	-- Head: smooth helmet with wide visor band and crest fin.
	f.add("Head", "HelmetShell", Vector3.new(h.X * 0.96, h.Y * 0.94, h.Z * 0.96), CFrame.new(), cosmic, METAL)
	f.add("Head", "VisorBand", Vector3.new(h.X * 0.78, 0.18 * s, 0.08 * s), f.face(0, 0.12, -0.02), neonBlue, NEON)
	f.add("Head", "CrestFin", Vector3.new(0.14 * s, 0.5 * s, 0.9 * s), CFrame.new(0, h.Y * 0.62, 0), gold, METAL, "wedge")
	-- Torso: fitted cosmic armor with central star emblem, diagonal
	-- harness and utility belt; energy lines trace the chest.
	f.add("UpperTorso", "CosmicArmor", Vector3.new(c.X * 0.9, c.Y * 0.84, 0.13 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), cosmic, METAL)
	star(f, "UpperTorso", CFrame.new(0, c.Y * 0.16, -c.Z / 2 - 0.04 * s), 0.36 * s, neonBlue)
	f.add("UpperTorso", "EnergyLineL", Vector3.new(0.06 * s, c.Y * 0.5, 0.04 * s), CFrame.new(-c.X * 0.28, 0, -c.Z / 2 - 0.05 * s) * CFrame.Angles(0, 0, 0.15), neonBlue, NEON)
	f.add("UpperTorso", "EnergyLineR", Vector3.new(0.06 * s, c.Y * 0.5, 0.04 * s), CFrame.new(c.X * 0.28, 0, -c.Z / 2 - 0.05 * s) * CFrame.Angles(0, 0, -0.15), neonBlue, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, gold, METAL)
	belt(f, gold, neonBlue)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and
	-- gauntlets; hands channel cosmic energy.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.18, 0.48, 1.14), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), cosmic, METAL)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonBlue, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), cosmic, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), gold, METAL)
	end
	-- Legs: armored thigh plates with glowing knee caps and shin
	-- guards; boots are reinforced for zero-gravity combat.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), cosmic, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonBlue, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), cosmic, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), gold, METAL)
	end
	muzzle(f, "Head", Vector3.new(0, h.Y * 0.1, -h.Z / 2 - 0.2 * s))
end

-- The league -------------------------------------------------------------------
HERO_EXTRAS.capmen = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local gold, white, neonOrange = Color3.fromRGB(236, 184, 76), Color3.fromRGB(246, 246, 250), Color3.fromRGB(255, 150, 60)
	-- Golden Champion: regal gold/white armor with glowing bolt emblem,
	-- flowing cape and energy-charged fists; silhouette reads as
	-- inspirational leader even at thumbnail size.
	-- Head: streamlined helmet with wide visor band and crest fin.
	f.add("Head", "HelmetShell", Vector3.new(h.X * 0.94, h.Y * 0.92, h.Z * 0.94), CFrame.new(), gold, METAL)
	f.add("Head", "VisorBand", Vector3.new(h.X * 0.76, 0.16 * s, 0.07 * s), f.face(0, 0.12, -0.02), white, NEON)
	f.add("Head", "CrestFin", Vector3.new(0.12 * s, h.Y * 0.38, h.Z * 0.88), CFrame.new(0, h.Y * 0.36, 0), gold, METAL, "wedge")
	-- Torso: fitted golden armor with central bolt emblem, diagonal
	-- harness and utility belt; short cape anchors at the shoulders.
	f.add("UpperTorso", "GoldenArmor", Vector3.new(c.X * 0.9, c.Y * 0.84, 0.13 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), gold, METAL)
	f.disc("UpperTorso", "Roundel", 0.62 * s, 0.07 * s, CFrame.new(0, c.Y * 0.14, -c.Z / 2 - 0.04 * s), gold, METAL)
	f.add("UpperTorso", "BoltTop", Vector3.new(0.2 * s, 0.46 * s, 0.06 * s), CFrame.new(0.06 * s, c.Y * 0.2, -c.Z / 2 - 0.09 * s) * CFrame.Angles(0, 0, -0.5), white, NEON)
	f.add("UpperTorso", "BoltBottom", Vector3.new(0.2 * s, 0.46 * s, 0.06 * s), CFrame.new(-0.06 * s, c.Y * 0.06, -c.Z / 2 - 0.09 * s) * CFrame.Angles(0, 0, -0.5), white, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, white, METAL)
	belt(f, HC.leather, gold)
	cape(f, gold, 2.8, white)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and
	-- gauntlets; hands glow with contained energy.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.2, 0.48, 1.16), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.08), gold, METAL)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.02, 0.07 * s, f.sizes.upperArm.Z * 0.98), CFrame.new(0, f.sizes.upperArm.Y * 0.12, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.08), white, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), gold, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), gold, METAL)
		local fist = f.add(handName, "FistGlow", Vector3.new(0.78 * s, 0.7 * s, 0.78 * s), CFrame.new(0, -0.04 * s, 0), neonOrange, NEON, "ball")
		fist.Transparency = 0.45
	end
	-- Legs: armored thigh plates with glowing knee caps and shin
	-- guards; boots are reinforced for heroic landings.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.16, 0.68, 1.14), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), gold, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.66, 0.22 * s, f.sizes.lowerLeg.Z * 0.58), CFrame.new(0, f.sizes.lowerLeg.Y * 0.42, -f.sizes.lowerLeg.Z * 0.26), white, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.1, 0.7, 1.08), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), gold, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.18, 0.62, 1.22), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), gold, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.emerald = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local emerald, black, neonGreen = Color3.fromRGB(20, 80, 40), Color3.fromRGB(20, 26, 24), Color3.fromRGB(70, 255, 140)
	-- Willpower Guardian: sleek green/black suit with glowing power ring,
	-- construct fist and domino mask; silhouette reads as cosmic sentinel
	-- even at thumbnail size.
	-- Head: masked face with glowing eye lenses and headband crest.
	f.add("Head", "MaskShell", Vector3.new(h.X * 0.94, h.Y * 0.92, h.Z * 0.94), CFrame.new(), black, FABRIC)
	f.add("Head", "MaskBand", Vector3.new(h.X * 0.92, 0.22 * s, 0.07 * s), f.face(0, 0.14, 0.03), emerald, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyeLens", Vector3.new(h.X * 0.24, h.Y * 0.18, 0.06 * s), f.face(side * 0.22, 0.12, -0.02), neonGreen, NEON, "wedge")
	end
	-- Torso: fitted suit with central ring emblem, diagonal harness
	-- and utility belt; construct fist floats at the shoulder.
	f.add("UpperTorso", "SuitFront", Vector3.new(c.X * 0.88, c.Y * 0.82, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), black, FABRIC)
	f.disc("UpperTorso", "ChestRing", 0.62 * s, 0.07 * s, CFrame.new(0, c.Y * 0.14, -c.Z / 2 - 0.04 * s), neonGreen, NEON)
	f.disc("UpperTorso", "ChestRingCore", 0.34 * s, 0.08 * s, CFrame.new(0, c.Y * 0.14, -c.Z / 2 - 0.06 * s), black, FABRIC)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, emerald, METAL)
	belt(f, emerald, neonGreen)
	local fist = f.add("UpperTorso", "ConstructFist", Vector3.new(1.0 * s, 0.9 * s, 0.9 * s), CFrame.new(c.X * 0.78, c.Y * 0.62, 0.1 * s), neonGreen, NEON, "ball")
	fist.Transparency = 0.42
	f.add("UpperTorso", "ConstructKnuckles", Vector3.new(1.05 * s, 0.34 * s, 0.95 * s), CFrame.new(c.X * 0.78, c.Y * 0.84, 0.1 * s), neonGreen, NEON).Transparency = 0.52
	-- Arms: sleek pauldrons with neon trim, forearm bracers and gauntlets;
	-- right hand bears the glowing power ring.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), black, FABRIC)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonGreen, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), black, FABRIC)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), emerald, METAL)
	end
	f.disc("RightHand", "PowerRing", 0.5 * s, 0.1 * s, CFrame.new(0, -0.1 * s, 0) * CFrame.Angles(0, 0, math.pi / 2), neonGreen, NEON)
	-- Legs: armored thigh plates with glowing knee caps and shin guards;
	-- boots are reinforced for cosmic flight.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), black, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonGreen, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), black, FABRIC)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), emerald, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.solartitan = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local crimson, gold, neonRed = Color3.fromRGB(160, 30, 50), Color3.fromRGB(246, 200, 64), Color3.fromRGB(255, 70, 50)
	-- Solar Sovereign: regal red/gold armor with glowing sun emblem,
	-- flowing cape and heat-vision eyes; silhouette reads as cosmic
	-- powerhouse even at thumbnail size.
	-- Head: streamlined helmet with wide visor band and crest fin.
	f.add("Head", "HelmetShell", Vector3.new(h.X * 0.96, h.Y * 0.94, h.Z * 0.96), CFrame.new(), crimson, METAL)
	f.add("Head", "VisorBand", Vector3.new(h.X * 0.78, 0.18 * s, 0.08 * s), f.face(0, 0.12, -0.02), gold, NEON)
	f.add("Head", "CrestFin", Vector3.new(0.12 * s, h.Y * 0.38, h.Z * 0.88), CFrame.new(0, h.Y * 0.36, 0), gold, METAL, "wedge")
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "HeatEye", Vector3.new(0.2 * s, 0.12 * s, 0.06 * s), f.face(side * 0.25, 0.14, -0.14), neonRed, NEON)
	end
	-- Torso: fitted golden armor with central sun emblem, diagonal
	-- harness and utility belt; long cape anchors at the shoulders.
	f.add("UpperTorso", "GoldenArmor", Vector3.new(c.X * 0.9, c.Y * 0.84, 0.13 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), gold, METAL)
	f.disc("UpperTorso", "SunShield", 0.78 * s, 0.07 * s, CFrame.new(0, c.Y * 0.14, -c.Z / 2 - 0.04 * s), gold, METAL)
	star(f, "UpperTorso", CFrame.new(0, c.Y * 0.14, -c.Z / 2 - 0.1 * s), 0.34 * s, neonRed)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, crimson, METAL)
	belt(f, gold, neonRed)
	cape(f, crimson, 4.6, gold)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and
	-- gauntlets; hands channel solar energy.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.2, 0.48, 1.16), CFrame.new(0, f.sizes.upperArm.Y * 0.28, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.08), gold, METAL)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.02, 0.07 * s, f.sizes.upperArm.Z * 0.98), CFrame.new(0, f.sizes.upperArm.Y * 0.12, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.08), neonRed, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), gold, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), gold, METAL)
	end
	-- Legs: armored thigh plates with glowing knee caps and shin
	-- guards; boots are reinforced for heroic landings.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.16, 0.68, 1.14), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), gold, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.66, 0.22 * s, f.sizes.lowerLeg.Z * 0.58), CFrame.new(0, f.sizes.lowerLeg.Y * 0.42, -f.sizes.lowerLeg.Z * 0.26), neonRed, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.1, 0.7, 1.08), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), gold, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.18, 0.62, 1.22), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), gold, METAL)
	end
	muzzle(f, "Head", Vector3.new(0, h.Y * 0.1, -h.Z / 2 - 0.2 * s))
end
HERO_EXTRAS.speedster = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local crimson, gold, neonYellow = Color3.fromRGB(180, 30, 40), Color3.fromRGB(240, 196, 60), Color3.fromRGB(255, 232, 90)
	-- Velocity Vanguard: sleek red/gold suit with glowing lightning bolt,
	-- winged cowl and speed trails; silhouette reads as fastest hero
	-- even at thumbnail size.
	-- Head: streamlined cowl with wide visor band and wing ears.
	f.add("Head", "CowlShell", Vector3.new(h.X * 0.94, h.Y * 0.92, h.Z * 0.94), CFrame.new(), crimson, FABRIC)
	f.add("Head", "VisorBand", Vector3.new(h.X * 0.76, 0.16 * s, 0.07 * s), f.face(0, 0.12, -0.02), neonYellow, NEON)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EarWing", Vector3.new(0.14 * s, 0.52 * s, 0.8 * s), CFrame.new(side * h.X * 0.55, h.Y * 0.18, 0.04 * s) * CFrame.Angles(0, 0, side * -0.5), gold, METAL, "wedge")
	end
	-- Torso: fitted speed suit with central bolt emblem, diagonal
	-- harness and utility belt; speed trails extend from the back.
	f.add("UpperTorso", "SpeedSuit", Vector3.new(c.X * 0.88, c.Y * 0.82, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), crimson, FABRIC)
	f.add("UpperTorso", "BoltTop", Vector3.new(0.22 * s, 0.5 * s, 0.06 * s), CFrame.new(0.07 * s, c.Y * 0.2, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, -0.5), neonYellow, NEON)
	f.add("UpperTorso", "BoltBottom", Vector3.new(0.22 * s, 0.5 * s, 0.06 * s), CFrame.new(-0.07 * s, c.Y * 0.0, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, -0.5), neonYellow, NEON)
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, gold, METAL)
	belt(f, gold, neonYellow)
	for i = 1, 3 do
		f.add("UpperTorso", "SpeedTrail", Vector3.new(0.1 * s, 0.1 * s, (1.8 + i * 0.7) * s), CFrame.new((i - 2) * 0.34 * s, c.Y * 0.1 - i * 0.18 * s, c.Z / 2 + (1.1 + i * 0.35) * s), neonYellow, NEON).Transparency = 0.45 + i * 0.1
	end
	-- Arms: sleek pauldrons with neon trim, forearm bracers and
	-- gauntlets; hands are streamlined for aerodynamic movement.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), crimson, FABRIC)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonYellow, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), crimson, FABRIC)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), gold, METAL)
	end
	-- Legs: armored thigh plates with glowing knee caps and shin
	-- guards; boots are reinforced for high-speed running.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), crimson, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonYellow, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), crimson, FABRIC)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), gold, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.amazon = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local crimson, gold, neonBlue = Color3.fromRGB(160, 30, 50), Color3.fromRGB(240, 196, 60), Color3.fromRGB(80, 220, 255)
	-- Warrior Princess: regal red/gold armor with glowing tiara,
	-- eagle emblem, shield and lasso; silhouette reads as divine
	-- champion even at thumbnail size.
	-- Head: streamlined helmet with wide visor band and tiara crest.
	f.add("Head", "HelmetShell", Vector3.new(h.X * 0.94, h.Y * 0.92, h.Z * 0.94), CFrame.new(), crimson, METAL)
	f.add("Head", "VisorBand", Vector3.new(h.X * 0.76, 0.16 * s, 0.07 * s), f.face(0, 0.12, -0.02), neonBlue, NEON)
	local band = circlet(f, "Tiara", gold)
	f.add("Head", "TiaraStar", Vector3.new(0.2 * s, 0.2 * s, 0.06 * s), f.face(0, band, 0.1) * CFrame.Angles(0, 0, math.pi / 4), neonBlue, METAL)
	-- Torso: fitted golden armor with central eagle emblem, diagonal
	-- harness and utility belt; shield mounts on the left forearm.
	f.add("UpperTorso", "GoldenArmor", Vector3.new(c.X * 0.9, c.Y * 0.84, 0.13 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), gold, METAL)
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "EagleWing", Vector3.new(c.X * 0.36, 0.14 * s, 0.06 * s), CFrame.new(side * c.X * 0.22, c.Y * 0.28, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, side * -0.28), neonBlue, METAL)
	end
	belt(f, HC.leather, gold)
	local arm = f.sizes.lowerArm
	f.add("LeftLowerArm", "Shield", Vector3.new(0.14 * s, 2.2 * s, 2.2 * s), CFrame.new(-arm.X / 2 - 0.12 * s, 0, -0.1 * s), gold, METAL, Enum.PartType.Cylinder)
	f.add("LeftLowerArm", "ShieldFace", Vector3.new(0.14 * s, 1.7 * s, 1.7 * s), CFrame.new(-arm.X / 2 - 0.16 * s, 0, -0.1 * s), crimson, METAL, Enum.PartType.Cylinder)
	f.add("LeftLowerArm", "ShieldStar", Vector3.new(0.06 * s, 0.7 * s, 0.7 * s), CFrame.new(-arm.X / 2 - 0.24 * s, 0, -0.1 * s), gold, METAL, Enum.PartType.Cylinder)
	local r = 0.55 * s
	for i = 0, 7 do
		local a0, a1 = i * math.pi / 4, (i + 1) * math.pi / 4
		f.rod("LowerTorso", "Lasso", Vector3.new(f.sizes.pelvis.X / 2 + 0.2 * s, math.cos(a0) * r, math.sin(a0) * r), Vector3.new(f.sizes.pelvis.X / 2 + 0.2 * s, math.cos(a1) * r, math.sin(a1) * r), 0.07 * s, Color3.fromRGB(255, 226, 120), NEON)
	end
	muzzle(f, "LeftLowerArm", Vector3.new(-arm.X / 2 - 0.3 * s, 0, 0))
end
HERO_EXTRAS.nightstalker = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local ink, steel, neonGold = Color3.fromRGB(26, 28, 40), Color3.fromRGB(170, 178, 200), Color3.fromRGB(255, 196, 60)
	-- Shadow Vigilante: sleek dark suit with glowing gold accents,
	-- pointed cowl, bat emblem and scalloped cape; silhouette reads as
	-- nocturnal guardian even at thumbnail size.
	-- Head: pointed cowl with glowing eye lenses and ear fins.
	f.add("Head", "CowlShell", h * Vector3.new(1.12, 0.72, 1.1), CFrame.new(0, h.Y * 0.2, h.Z * 0.04), ink, FABRIC, "ball")
	f.add("Head", "ChinGuard", Vector3.new(h.X * 0.5, h.Y * 0.24, 0.1 * s), f.face(0, -0.62, -0.03), HC.skin, FABRIC)
	f.add("Head", "MouthLine", Vector3.new(0.2 * s, 0.05 * s, 0.05 * s), f.face(0, -0.64, 0.04), HC.ink, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "EyeLens", Vector3.new(h.X * 0.26, h.Y * 0.16, 0.06 * s), f.face(side * 0.22, 0.12, -0.02), neonGold, NEON, "wedge")
		f.add("Head", "EarFin", Vector3.new(0.18 * s, 0.55 * s, 0.18 * s), CFrame.new(side * h.X * 0.32, h.Y * 0.62, 0), ink, FABRIC, "wedge")
	end
	-- Torso: fitted dark suit with central bat emblem, diagonal harness
	-- and utility belt; scalloped cape anchors at the shoulders.
	f.add("UpperTorso", "SuitFront", Vector3.new(c.X * 0.88, c.Y * 0.82, 0.12 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), ink, FABRIC)
	f.add("UpperTorso", "BatEmblem", Vector3.new(0.34 * s, 0.3 * s, 0.06 * s), CFrame.new(0, c.Y * 0.18, -c.Z / 2 - 0.05 * s), neonGold, METAL, "ball")
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "WingTip", Vector3.new(c.X * 0.3, 0.16 * s, 0.06 * s), CFrame.new(side * c.X * 0.2, c.Y * 0.2, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, side * -0.3), neonGold, METAL)
	end
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, steel, METAL)
	belt(f, Color3.fromRGB(70, 74, 96), neonGold)
	cape(f, Color3.fromRGB(34, 38, 56), 3.0, ink)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and
	-- gauntlets with fin accents; hands are gloved for stealth.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.16, 0.46, 1.12), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), ink, FABRIC)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonGold, NEON)
		f.add(forearmName, "Gauntlet", f.sizes.lowerArm * Vector3.new(1.18, 0.6, 1.18), CFrame.new(0, -f.sizes.lowerArm.Y * 0.18, 0), ink, METAL)
		f.add(forearmName, "Fin", Vector3.new(0.06 * s, 0.6 * s, 0.5 * s), CFrame.new(side * f.sizes.lowerArm.X * 0.62, -f.sizes.lowerArm.Y * 0.1, 0), steel, METAL, "wedge")
		f.add(handName, "Glove", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), ink, FABRIC)
	end
	-- Legs: armored thigh plates with glowing knee caps and shin
	-- guards; boots are reinforced for silent movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), ink, FABRIC)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonGold, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), ink, FABRIC)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), steel, METAL)
	end
	for i = -1, 1, 2 do
		f.add("LowerTorso", "MinePouch", Vector3.new(0.44, 0.44, 0.3) * s, CFrame.new(i * f.sizes.pelvis.X * 0.42, f.sizes.pelvis.Y * 0.1, -f.sizes.pelvis.Z * 0.56), Color3.fromRGB(50, 54, 72), METAL, "ball")
		f.add("LowerTorso", "MineLight", Vector3.new(0.14, 0.14, 0.14) * s, CFrame.new(i * f.sizes.pelvis.X * 0.42, f.sizes.pelvis.Y * 0.1, -f.sizes.pelvis.Z * 0.56 - 0.18 * s), Color3.fromRGB(255, 90, 80), NEON, "ball")
	end
	muzzle(f, "RightHand", Vector3.new(0, -f.sizes.hand.Y / 2 - 0.1 * s, 0))
end
HERO_EXTRAS.seaking = function(f)
	local s, h, c = f.scale, f.parts.Head.Size, f.sizes.chest
	local deepSea, gold, neonTeal = Color3.fromRGB(20, 80, 100), Color3.fromRGB(240, 196, 60), Color3.fromRGB(70, 220, 230)
	-- Ocean Sovereign: regal deep-sea armor with glowing teal accents,
	-- golden crown, scale plates and trident; silhouette reads as
	-- aquatic ruler even at thumbnail size.
	-- Head: streamlined helmet with wide visor band and crown crest.
	f.add("Head", "HelmetShell", Vector3.new(h.X * 0.94, h.Y * 0.92, h.Z * 0.94), CFrame.new(), deepSea, METAL)
	f.add("Head", "VisorBand", Vector3.new(h.X * 0.76, 0.16 * s, 0.07 * s), f.face(0, 0.12, -0.02), neonTeal, NEON)
	-- The crown rings the hair; three points rise from its front.
	f.add("Head", "Crown", Vector3.new(h.X * 1.18, h.Y * 0.14, h.Z * 1.22), CFrame.new(0, h.Y * 0.42, h.Z * 0.06), gold, METAL, "head")
	for i = -1, 1 do
		local x = i * 0.3
		local z = 0.06 - 0.61 * math.sqrt(1 - (x / 0.59) ^ 2)
		f.add("Head", "CrownPoint", Vector3.new(0.14 * s, 0.34 * s, 0.14 * s), CFrame.new(x * h.X, h.Y * 0.49 + 0.17 * s, z * h.Z), gold, METAL, "wedge")
	end
	-- Torso: fitted deep-sea armor with scale plates, central tide
	-- emblem and diagonal harness; utility belt secures the waist.
	f.add("UpperTorso", "SeaArmor", Vector3.new(c.X * 0.9, c.Y * 0.84, 0.13 * s), CFrame.new(0, 0, -c.Z / 2 - 0.02 * s), deepSea, METAL)
	for row = 0, 2 do
		for col = -1, 1 do
			f.add("UpperTorso", "Scale", Vector3.new(0.34 * s, 0.26 * s, 0.05 * s), CFrame.new(col * 0.36 * s + (row % 2) * 0.18 * s, c.Y * 0.26 - row * 0.28 * s, -c.Z / 2 - 0.03 * s), neonTeal, METAL, "ball")
		end
	end
	f.add("UpperTorso", "TideEmblem", Vector3.new(0.36 * s, 0.5 * s, 0.06 * s), CFrame.new(0, c.Y * 0.16, -c.Z / 2 - 0.1 * s), neonTeal, NEON, "ball")
	f.rod("UpperTorso", "HarnessStrap", Vector3.new(-c.X * 0.34, c.Y * 0.38, -c.Z / 2 - 0.04 * s), Vector3.new(c.X * 0.34, -c.Y * 0.34, -c.Z / 2 - 0.04 * s), 0.1 * s, gold, METAL)
	belt(f, gold, neonTeal)
	-- Arms: sleek pauldrons with neon trim, forearm bracers and
	-- gauntlets; right hand grips the glowing trident.
	for _, side in ipairs({ -1, 1 }) do
		local armName = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local forearmName = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local handName = side < 0 and "LeftHand" or "RightHand"
		f.add(armName, "Pauldron", f.sizes.upperArm * Vector3.new(1.18, 0.48, 1.14), CFrame.new(0, f.sizes.upperArm.Y * 0.26, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), deepSea, METAL)
		f.add(armName, "PauldronTrim", Vector3.new(f.sizes.upperArm.X * 1.0, 0.06 * s, f.sizes.upperArm.Z * 0.96), CFrame.new(0, f.sizes.upperArm.Y * 0.1, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.06), neonTeal, NEON)
		f.add(forearmName, "Bracer", f.sizes.lowerArm * Vector3.new(1.12, 0.58, 1.1), CFrame.new(0, f.sizes.lowerArm.Y * 0.12, 0), deepSea, METAL)
		f.add(handName, "Gauntlet", f.sizes.hand * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, -f.sizes.hand.Y * 0.06, 0), gold, METAL)
	end
	-- Trident: golden shaft with three glowing teal prongs.
	f.rod("RightHand", "TridentShaft", Vector3.new(0, 1.4 * s, 0), Vector3.new(0, -1.5 * s, 0), 0.16 * s, gold, METAL)
	for _, x in ipairs({ -0.5, 0, 0.5 }) do
		f.rod("RightHand", "TridentProng", Vector3.new(x * s, 1.55 * s, 0), Vector3.new(x * s, (x == 0 and 2.5 or 2.2) * s, 0), 0.12 * s, neonTeal, NEON)
	end
	f.rod("RightHand", "TridentBar", Vector3.new(-0.5 * s, 1.55 * s, 0), Vector3.new(0.5 * s, 1.55 * s, 0), 0.14 * s, gold, METAL)
	-- Legs: armored thigh plates with glowing knee caps and shin
	-- guards; boots are reinforced for underwater movement.
	for _, side in ipairs({ -1, 1 }) do
		local legName = side < 0 and "LeftUpperLeg" or "RightUpperLeg"
		local lowerName = side < 0 and "LeftLowerLeg" or "RightLowerLeg"
		local footName = side < 0 and "LeftFoot" or "RightFoot"
		f.add(legName, "ThighPlate", f.sizes.upperLeg * Vector3.new(1.14, 0.66, 1.12), CFrame.new(0, f.sizes.upperLeg.Y * 0.14, 0), deepSea, METAL)
		f.add(lowerName, "KneeCap", Vector3.new(f.sizes.lowerLeg.X * 0.64, 0.2 * s, f.sizes.lowerLeg.Z * 0.56), CFrame.new(0, f.sizes.lowerLeg.Y * 0.4, -f.sizes.lowerLeg.Z * 0.24), neonTeal, NEON, "ball")
		f.add(lowerName, "ShinGuard", f.sizes.lowerLeg * Vector3.new(1.08, 0.68, 1.06), CFrame.new(0, f.sizes.lowerLeg.Y * 0.08, 0), deepSea, METAL)
		f.add(footName, "Boot", f.sizes.foot * Vector3.new(1.16, 0.6, 1.2), CFrame.new(0, -f.sizes.foot.Y * 0.1, 0), gold, METAL)
	end
	muzzle(f, "RightHand", Vector3.new(0, 2.5 * s, 0))
end

-- Faces for the heroes whose extras do not already draw one.
local DRAWN_FACE = { nightstalker = true, ironman = true, spiderman = true, antman = true, wasp = true, daredevil = true, panther = true,
	warmachine = true, starlord = true, ghostrider = true, wolverine = true, cyclops = true, deadpool = true, moonknight = true, nova = true }

-- The whole roster gets the finish of a painted action figure (owner, 15/10:
-- refine the heroes): a soft gloss on costume and armour, never on skin, so
-- every fold catches the light; and no costume colour so dark that it reads as
-- a hole in a small portrait. Glow, eyes and mouths keep their own colours.
local HERO_SKIN = Color3.fromRGB(232, 181, 147)
local FACE_PARTS = { Sclera = true, Eye = true, Iris = true, Pupil = true, EyeRim = true, Catchlight = true, Brow = true, Lash = true,
	EyeLine = true, Mouth = true, Teeth = true, Tongue = true, Blush = true }
local NIGHT_LIFT = Color3.fromRGB(70, 74, 88)
local function polishHero(f, skin, matte)
	for _, item in ipairs(f.model:GetChildren()) do
		if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and not FACE_PARTS[item.Name] and item.Material ~= Enum.Material.Neon
			and item.Material ~= Enum.Material.Glass and item.Material ~= Enum.Material.ForceField then
			local color = item.Color
			if math.max(color.R, color.G, color.B) < 0.2 then item.Color = color:Lerp(NIGHT_LIFT, 0.42) end
			local skinLike = math.abs(color.R - skin.R) + math.abs(color.G - skin.G) + math.abs(color.B - skin.B) < 0.06
			-- A matte hero (stone, bark) catches no gloss: a varnish on stone mirrored the sky.
			if not skinLike and not matte then item.Reflectance = math.max(item.Reflectance or 0, item.Material == Enum.Material.Metal and 0.15 or 0.1) end
		end
		-- A flat plate of costume (a chest panel, a pauldron, a slab, a belt) is
		-- moulded with rounded rims: plain boxes read as planks in Studio next
		-- to the drawn faces. Rods, cubes and the head's own pieces keep their shape.
		if item:IsA("Part") and item.Shape == Enum.PartType.Block and not item:FindFirstChildOfClass("SpecialMesh") then
			local fit = item:FindFirstChild("Fit")
			local host = fit and fit.Part0
			if host and host.Name ~= "Head" and not string.find(item.Name, "Hair") then
				local dims = { item.Size.X, item.Size.Y, item.Size.Z }
				table.sort(dims)
				if dims[2] >= 0.12 * f.scale and dims[1] < dims[2] * 0.5 then
					local mesh = Instance.new("SpecialMesh")
					mesh.Name, mesh.MeshType, mesh.Parent = "CostumeContour", roundedMeshType(item.Size), item
				end
			end
		end
	end
	f.model:SetAttribute("HeroFinish", "polished")
end

-- A sculpted torso (owner, 16/10: the last pass on the heroes, "make them
-- incredible"): a broad, rounded chest over a narrower rounded waist, like an
-- action figure, instead of a box with a wedge for each shoulder (the box was
-- the one square shape left among the rounded limbs). One part for two.
local function sculptTorso(f)
	local chest, c = f.parts.UpperTorso, f.sizes.chest
	local core = chest:FindFirstChild("BodyContour")
	if not core then return end
	for _, item in ipairs(f.model:GetChildren()) do
		if item.Name == "TorsoSlope" then item:Destroy() end
	end
	-- Chamfered blocks: Roblox's own classic torso mesh (see armourHero).
	core.MeshType, core.MeshId = Enum.MeshType.FileMesh, "rbxasset://avatar/meshes/torso.mesh"
	core.Scale, core.Offset = Vector3.new(c.X / 2, c.Y * 0.68 / 2, c.Z * 1.02), Vector3.new(0, c.Y * 0.16, 0)
	core:SetAttribute("MeshNative", Vector3.new(2, 2, 1))
	local waist = f.add("UpperTorso", "Waist", Vector3.new(c.X * 0.74, c.Y * 0.56, c.Z * 0.92), CFrame.new(0, -c.Y * 0.22, 0), chest.Color, chest.Material, "torso")
	local waistMesh = waist:FindFirstChildOfClass("SpecialMesh")
	waistMesh.MeshType, waistMesh.MeshId = Enum.MeshType.FileMesh, "rbxasset://avatar/meshes/torso.mesh"
	waistMesh.Scale = Vector3.new(waist.Size.X / 2, waist.Size.Y / 2, waist.Size.Z)
	waistMesh:SetAttribute("MeshNative", Vector3.new(2, 2, 1))
	waist:SetAttribute("Tint", chest:GetAttribute("Tint"))
	waist.Reflectance = chest.Reflectance
	f.model:SetAttribute("TorsoFinish", "sculpted")
end

-- Armour finish (owner, 16/10, with two pictures of the level they want: "não
-- vai deixar meus heróis palito"): every limb segment, fist, boot, shoulder pad
-- and chest plate is a chunky block with chamfered edges, and each segment
-- stops a little short of its elbow or knee, where a dark under-suit joint
-- shows; the wrist, ankle and shoulder ends still reach their joints, so
-- nothing opens there. Roblox ships the classic avatar's blocks with every
-- client, a 1x2x1 limb and a 2x2x1 torso whose edges are chamfered (decoded
-- and checked in Studio, 16/10): the armour wears them as file meshes, so the
-- bevels cost no part. Stone and bark keep their rounded, overlapping limbs:
-- a golem's boulders and a tree's logs are not armour.
local UNDERSUIT = Color3.fromRGB(46, 48, 60)
-- A trim colour other than the catalogue's, where the costume asks for it.
local HERO_GLOW = {
	thor = Color3.fromRGB(90, 170, 255), wanda = Color3.fromRGB(255, 60, 190), strange = Color3.fromRGB(255, 196, 60),
	ghostrider = Color3.fromRGB(255, 120, 30), silversurfer = Color3.fromRGB(80, 210, 255),
}
local CHAMFER_LIMB, CHAMFER_TORSO = "rbxasset://avatar/meshes/leftarm.mesh", "rbxasset://avatar/meshes/torso.mesh"
-- Dresses a mesh as a chamfered block `size` big (the wide block for a piece
-- much wider than it is deep, so the bevels stay even).
local function chamfer(mesh, size)
	local torso = size.X > size.Z * 1.35
	mesh.MeshType, mesh.MeshId = Enum.MeshType.FileMesh, torso and CHAMFER_TORSO or CHAMFER_LIMB
	local native = torso and Vector3.new(2, 2, 1) or Vector3.new(1, 2, 1)
	mesh.Scale = Vector3.new(size.X / native.X, size.Y / native.Y, size.Z / native.Z)
	mesh:SetAttribute("MeshNative", native)
	return mesh
end
-- The armour's own block and finish (owner, 16/10: "faça tudo necessário...
-- só precisa ser gratuito"): a unit box with well-rounded edges and a painted
-- near-white finish tinted by VertexColor, made by tools/gen_armor_assets.py
-- and uploaded once (Config.Art). While their ids are 0 the classic chamfered
-- blocks stay. Set by World.new from the config.
local ARMOUR_ART = { mesh = 0, texture = 0, galaxy = 0, flames = 0, runes = 0, web = 0, scales = 0, circuit = 0, tiger = 0,
	padMesh = 0, padTexture = 0, filigree = 0 }
-- Heroes of rank whose chest plate carries gold filigree (tools/gen_ornate_assets.py).
local FILIGREE = { thor = true, strange = true, wanda = true, captain = true, captainmarvel = true, seaking = true, amazon = true,
	storm = true, jean = true, solartitan = true, capmen = true, vision = true, panther = true }
-- A hero's own armour finish (tools/gen_hero_textures.py): a pattern in the
-- armour block's layout that the piece's colour tints. The galaxy is painted,
-- not tinted, and only on the suit's coloured pieces (the herald's white
-- armour stays white).
local HERO_FINISH = {
	spiderman = "web", seaking = "scales", wolverine = "tiger",
	ironman = "circuit", warmachine = "circuit", vision = "circuit", antman = "circuit", wasp = "circuit",
	silversurfer = "galaxy",
}
-- A painted pattern on one face of a piece (tools/gen_hero_textures.py), when
-- its id is set.
local function pattern(part, key, face)
	local id = ARMOUR_ART[key] or 0
	if id == 0 or not part then return nil end
	local decal = Instance.new("Decal")
	decal.Name, decal.Texture, decal.Face, decal.Parent = "Pattern", "rbxassetid://" .. tostring(id), face, part
	return decal
end
-- Last pass on a hero: every chamfered piece wears the armour's own block and
-- finish in its own colour (after every recolour of the costume).
local function paintArmour(f)
	if (ARMOUR_ART.mesh or 0) == 0 then return end
	local meshId = "rbxassetid://" .. tostring(ARMOUR_ART.mesh)
	local textureId = (ARMOUR_ART.texture or 0) ~= 0 and "rbxassetid://" .. tostring(ARMOUR_ART.texture) or ""
	local padId = (ARMOUR_ART.padMesh or 0) ~= 0 and "rbxassetid://" .. tostring(ARMOUR_ART.padMesh) or nil
	local padTexture = (ARMOUR_ART.padTexture or 0) ~= 0 and "rbxassetid://" .. tostring(ARMOUR_ART.padTexture) or ""
	local finishKey = HERO_FINISH[f.model:GetAttribute("HeroId") or ""]
	local finishId = finishKey and (ARMOUR_ART[finishKey] or 0) ~= 0 and "rbxassetid://" .. tostring(ARMOUR_ART[finishKey]) or nil
	for _, part in ipairs(f.model:GetDescendants()) do
		if part:IsA("BasePart") then
			for _, mesh in ipairs(part:GetChildren()) do
				local native = mesh:IsA("SpecialMesh") and mesh:GetAttribute("MeshNative")
				if native and (mesh.MeshId == CHAMFER_LIMB or mesh.MeshId == CHAMFER_TORSO) then
					local drawn = Vector3.new(mesh.Scale.X * native.X, mesh.Scale.Y * native.Y, mesh.Scale.Z * native.Z)
					mesh.MeshId, mesh.TextureId, mesh.Scale = meshId, textureId, drawn
					if padId and part.Name == "Pauldron" then
						-- A domed pauldron with a rim, curved like the pictures' (a block read as a crate).
						mesh.MeshId, mesh.TextureId = padId, padTexture
						part:SetAttribute("PadShape", "dome")
					end
					mesh:SetAttribute("MeshNative", Vector3.new(1, 1, 1))
					local c = part.Color
					mesh.VertexColor = Vector3.new(c.R, c.G, c.B)
					if finishId then
						if finishKey == "galaxy" then
							-- The galaxy shows on the suit's saturated pieces, untinted.
							if math.max(c.R, c.G, c.B) - math.min(c.R, c.G, c.B) > 0.25 then
								mesh.TextureId, mesh.VertexColor = finishId, Vector3.new(1, 1, 1)
							end
						else
							mesh.TextureId = finishId
						end
					end
				end
			end
		end
	end
	if padId then
		for _, stud in ipairs(f.model:GetChildren()) do
			local fit = stud.Name == "PadStud" and stud:FindFirstChild("Fit")
			if fit then
				-- On the dome's curve, a little lower and further in than on the block.
				local at = fit.C0.Position
				fit.C0 = CFrame.new(at.X * 0.85, at.Y - 0.06 * f.scale, at.Z * 0.88) * (fit.C0 - at)
				stud.CFrame = fit.Part0.CFrame * fit.C0
			end
		end
	end
	f.model:SetAttribute("ArmourArt", true)
end
-- Gold filigree on the chest plate of a hero of rank: a see-through plate just
-- in front of the chest with the scrollwork as its decal (the middle stays
-- free for the hero's emblem).
local function filigree(f, heroId)
	if not FILIGREE[heroId] or (ARMOUR_ART.filigree or 0) == 0 then return end
	local c, s = f.sizes.chest, f.scale
	local plate = f.add("UpperTorso", "Filigree", Vector3.new(c.X * 0.78, c.Y * 0.62, 0.02 * s), CFrame.new(0, c.Y * 0.14, -c.Z / 2 - 0.17 * s), Color3.new(1, 1, 1), FABRIC)
	plate.Transparency = 1
	local decal = Instance.new("Decal")
	decal.Name, decal.Texture, decal.Face, decal.Parent = "Pattern", "rbxassetid://" .. tostring(ARMOUR_ART.filigree), Enum.NormalId.Front, plate
end
Figure.ArmourArt = ARMOUR_ART
Figure.Chamfer = chamfer
-- Each segment's length (of the limb), how far it slides away from the elbow
-- or knee (mesh offset, in lengths: the far end stays on its joint) and its
-- girth: gauntlets and greaves are bulkier than the upper arm and the thigh,
-- like the pictures' armour.
local ARMOUR_SEGMENTS = { UpperArm = { 0.94, 0.03, 1 }, LowerArm = { 0.95, -0.025, 1.14 }, UpperLeg = { 0.94, 0.03, 1.02 }, LowerLeg = { 0.95, -0.025, 1.12 } }
-- The shoulder pieces that become the armour's pads (a spiked, icy or rocky
-- pad keeps its own shape).
local PADS = { Pauldron = true, ShoulderPad = true, ShoulderGuard = true }
local function armourHero(f, look)
	if look.matte then return end
	for _, side in ipairs({ "Left", "Right" }) do
		for segment, fit in pairs(ARMOUR_SEGMENTS) do
			local limb = f.parts[side .. segment]
			local contour = chamfer(limb:FindFirstChild("BodyContour"), Vector3.new(limb.Size.X * fit[3], limb.Size.Y * fit[1], limb.Size.Z * fit[3]))
			contour.Offset = Vector3.new(0, limb.Size.Y * fit[2], 0)
		end
		for _, name in ipairs({ "Hand", "Foot" }) do
			local part = f.parts[side .. name]
			chamfer(part:FindFirstChild("BodyContour"), part.Size)
		end
		local ua, la, ul, ll = f.sizes.upperArm, f.sizes.lowerArm, f.sizes.upperLeg, f.sizes.lowerLeg
		f.add(side .. "UpperArm", "ElbowJoint", Vector3.one * math.min(ua.X, ua.Z, la.X, la.Z) * 0.84, CFrame.new(0, -ua.Y / 2, 0), UNDERSUIT, FABRIC, "ball")
		f.add(side .. "UpperLeg", "KneeJoint", Vector3.one * math.min(ul.X, ul.Z, ll.X, ll.Z) * 0.84, CFrame.new(0, -ul.Y / 2, 0), UNDERSUIT, FABRIC, "ball")
	end
	if not look.suit then
		local pelvis = f.parts.LowerTorso
		chamfer(pelvis:FindFirstChild("BodyContour"), pelvis.Size)
	end
	-- The under-suit shows at the waist too, between the chest armour and the belt.
	local waist = f.model:FindFirstChild("Waist")
	if waist then waist.Color = UNDERSUIT:Lerp(f.parts.UpperTorso.Color, 0.2) end
	-- Colour reads as colour, like the pictures' glossy toys: Roblox's Metal
	-- mirrors the sky and washed a gold, red or blue suit out to khaki and
	-- grey in Studio (16/10), so a coloured metal piece is smooth plastic with
	-- a light gloss; grey metals stay metal. Gold takes a rich gold.
	for _, item in ipairs(f.model:GetDescendants()) do
		if item:IsA("BasePart") and item.Material == METAL then
			local c = item.Color
			if math.max(c.R, c.G, c.B) - math.min(c.R, c.G, c.B) > 0.25 then
				if c.R > 0.78 and c.G > 0.5 and c.G < 0.84 and c.B < 0.42 then c = Color3.fromRGB(255, 186, 38):Lerp(c, 0.2) end
				item.Color, item.Material, item.Reflectance = c, FABRIC, 0.06
			end
		end
	end
	local shelled, pads, trims, kneeCaps = {}, {}, {}, {}
	for _, piece in ipairs(f.model:GetChildren()) do
		local fit = piece:IsA("BasePart") and piece:FindFirstChild("Fit")
		if fit and fit.Part0 and (piece.Name == "PauldronTrim" or piece.Name == "ShoulderTrim") then trims[fit.Part0.Name] = piece.Color end
		if fit and fit.Part0 and piece.Name == "KneeCap" then kneeCaps[fit.Part0.Name] = piece.Color end
	end
	for _, piece in ipairs(f.model:GetChildren()) do
		local fit = piece:IsA("BasePart") and piece:FindFirstChild("Fit")
		local host = fit and fit.Part0
		if not host or piece.Material == NEON then continue end
		local limb = string.find(host.Name, "Arm") or string.find(host.Name, "Leg") or string.find(host.Name, "Hand") or string.find(host.Name, "Foot")
		if PADS[piece.Name] and string.find(host.Name, "UpperArm") and not pads[host.Name] then
			-- A big chamfered block over the shoulder: its top stands above the
			-- shoulder line and its sides overhang the arm.
			local arm = host.Size
			local pad = f.add(host.Name, "Pauldron", Vector3.new(arm.X * 1.36, arm.Y * 0.56, arm.Z * 1.32), CFrame.new(0, arm.Y * 0.32, 0), piece.Color, piece.Material)
			chamfer(Instance.new("SpecialMesh"), pad.Size).Parent = pad
			pad.Reflectance = piece.Reflectance
			pad:SetAttribute("Tint", piece:GetAttribute("Tint"))
			pads[host.Name] = pad
			piece:Destroy()
		elseif string.find(host.Name, "Foot") then
			-- Boots are tall chamfered blocks over the whole foot, on a dark sole
			-- that shows around them (a low slab read as a sandal).
			local ratio = Vector3.new(piece.Size.X / host.Size.X, piece.Size.Y / host.Size.Y, piece.Size.Z / host.Size.Z)
			if piece.Name == "BootSole" then
				piece.Size = host.Size * Vector3.new(1.3, 0.26, 1.3)
				fit.C0 = CFrame.new(0, -host.Size.Y * 0.4, -host.Size.Z * 0.02)
			elseif ratio.X >= 1.04 and ratio.Z >= 1.04 then
				piece.Size = Vector3.new(piece.Size.X, host.Size.Y * 1.02, piece.Size.Z)
				fit.C0 = CFrame.new(0, host.Size.Y * 0.02, fit.C0.Position.Z)
			end
			piece.CFrame = host.CFrame * fit.C0
			if piece:IsA("Part") and piece.Shape == Enum.PartType.Block then
				chamfer(piece:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh"), piece.Size).Parent = piece
			end
		elseif limb then
			-- A plate around an arm or a leg becomes the armour of its whole
			-- segment, one block from joint to joint like the pictures' (a band
			-- round the middle of each read as a stack of tyres); other pieces on
			-- the limbs (pads, bracers, gloves) are chamfered blocks too.
			local segment = string.match(host.Name, "^%a-(%u%l+%u%l+)$")
			local shell = ARMOUR_SEGMENTS[segment]
			local ratio = Vector3.new(piece.Size.X / host.Size.X, piece.Size.Y / host.Size.Y, piece.Size.Z / host.Size.Z)
			local mesh = piece:FindFirstChildOfClass("SpecialMesh")
			if shell and ratio.X >= 1.04 and ratio.Z >= 1.04 and ratio.Y >= 0.3 and ratio.Y <= 1.05
				and not shelled[host] and not string.find(piece.Name, "Pauldron") and not string.find(piece.Name, "Shoulder") then
				shelled[host] = true
				local girth = math.max(ratio.X, shell[3] + 0.06)
				piece.Size = Vector3.new(host.Size.X * girth, host.Size.Y * shell[1], host.Size.Z * math.max(ratio.Z, shell[3] + 0.06))
				fit.C0 = CFrame.new(0, host.Size.Y * shell[2], 0)
				piece.CFrame = host.CFrame * fit.C0
				mesh = mesh or Instance.new("SpecialMesh")
				mesh.Name = "CostumeContour"
				chamfer(mesh, piece.Size).Parent = piece
			elseif piece:IsA("Part") and piece.Shape == Enum.PartType.Block and piece.Name ~= "Thumb"
				and (not mesh or mesh.MeshType == Enum.MeshType.Head or mesh.MeshType == Enum.MeshType.Torso or mesh.MeshType == Enum.MeshType.Brick)
				and math.min(piece.Size.X, piece.Size.Y, piece.Size.Z) >= 0.12 * f.scale then
				chamfer(mesh or Instance.new("SpecialMesh"), piece.Size).Parent = piece
			end
		elseif (piece.Name == "Buckle" or piece.Name == "BeltBuckle") and host.Name == "LowerTorso" then
			-- A big buckle, like the pictures' belts.
			local front = fit.C0.Position
			piece.Size = Vector3.new(0.6, 0.44, 0.12) * f.scale
			fit.C0 = CFrame.new(front.X, front.Y, -host.Size.Z * 0.56 - 0.04 * f.scale)
			piece.CFrame = host.CFrame * fit.C0
			chamfer(piece:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh"), piece.Size).Parent = piece
		elseif (host.Name == "UpperTorso" or host.Name == "LowerTorso") and piece:IsA("Part") and piece.Shape == Enum.PartType.Block then
			-- Chest plates, belts and packs are chamfered blocks.
			local mesh = piece:FindFirstChildOfClass("SpecialMesh")
			if (not mesh or mesh.MeshType == Enum.MeshType.Torso or mesh.MeshType == Enum.MeshType.Brick)
				and math.min(piece.Size.X, piece.Size.Y, piece.Size.Z) >= 0.12 * f.scale then
				chamfer(mesh or Instance.new("SpecialMesh"), piece.Size).Parent = piece
			end
		end
	end
	-- Glowing trims in the hero's own colour, like the pictures' edges: round
	-- each gauntlet's wrist, round each boot's top and along the chest plate's
	-- lower edge. A pad's gold trim runs round its lower rim.
	local glow = f.glow
	if glow then
		local s = f.scale
		for _, side in ipairs({ "Left", "Right" }) do
			local forearm = f.parts[side .. "LowerArm"].Size
			local girth = 0
			for _, piece in ipairs(f.model:GetChildren()) do
				local fit = piece:IsA("BasePart") and piece:FindFirstChild("Fit")
				if fit and fit.Part0 and fit.Part0.Name == side .. "LowerArm" and shelled[fit.Part0] and piece.Name ~= "ElbowJoint" then girth = math.max(girth, piece.Size.X / forearm.X) end
			end
			girth = math.max(girth, ARMOUR_SEGMENTS.LowerArm[3]) + 0.04
			f.add(side .. "LowerArm", "CuffGlow", Vector3.new(forearm.X * girth, 0.08 * s, forearm.Z * girth), CFrame.new(0, -forearm.Y * 0.42, 0), glow, NEON)
			local foot = f.parts[side .. "Foot"].Size
			local boot = 1.04
			for _, piece in ipairs(f.model:GetChildren()) do
				local fit = piece:IsA("BasePart") and piece:FindFirstChild("Fit")
				if fit and fit.Part0 and fit.Part0.Name == side .. "Foot" and piece.Name ~= "BootSole" and piece.Material ~= NEON then boot = math.max(boot, piece.Size.X / foot.X) end
			end
			f.add(side .. "Foot", "BootGlow", Vector3.new(foot.X * (boot + 0.04), 0.08 * s, foot.Z * 0.62), CFrame.new(0, foot.Y * 0.5, foot.Z * 0.2), glow, NEON)
			local pad = pads[side .. "UpperArm"]
			if pad then
				local arm = f.parts[side .. "UpperArm"].Size
				local rim = Vector3.new(pad.Size.X * 1.03, 0.08 * s, pad.Size.Z * 1.03)
				local trim = trims[side .. "UpperArm"] or HC.gold
				f.add(side .. "UpperArm", "PadRim", rim, CFrame.new(0, arm.Y * 0.32 - pad.Size.Y / 2 + 0.04 * s, 0), trim, METAL)
			end
		end
		for _, piece in ipairs(f.model:GetChildren()) do
			if piece.Name == "PauldronTrim" and piece:FindFirstChild("Fit") and pads[piece.Fit.Part0.Name] then piece:Destroy() end
		end
		local c = f.sizes.chest
		f.add("UpperTorso", "ChestTrim", Vector3.new(c.X * 1.01, 0.08 * s, c.Z * 1.05), CFrame.new(0, -c.Y * 0.18, 0), glow, NEON)
		-- And a gold collar line along the plate's top edge, framing the chest.
		local collar = trims.LeftUpperArm or trims.RightUpperArm or HC.gold
		f.add("UpperTorso", "CollarLine", Vector3.new(c.X * 0.86, 0.1 * s, 0.06 * s), CFrame.new(0, c.Y * 0.43, -c.Z * 0.51 - 0.03 * s), collar, METAL)
	end
	-- Gold studs like the pictures': a diamond on the front of each shoulder
	-- pad and on each knee that has no cap of its own, in the hero's trim colour.
	for _, side in ipairs({ "Left", "Right" }) do
		local sign = side == "Left" and -1 or 1
		local accent = trims[side .. "UpperArm"] or HC.gold
		local s = f.scale
		if pads[side .. "UpperArm"] then
			local arm = f.parts[side .. "UpperArm"].Size
			f.add(side .. "UpperArm", "PadStud", Vector3.new(0.24, 0.24, 0.08) * s, CFrame.new(sign * arm.X * 0.28, arm.Y * 0.34, -arm.Z * 0.66 - 0.03 * s) * CFrame.Angles(0, 0, math.pi / 4), accent, METAL)
		end
		if not kneeCaps[side .. "LowerLeg"] then
			local thigh = f.sizes.upperLeg
			local reach = math.min(thigh.X, thigh.Z, f.sizes.lowerLeg.X, f.sizes.lowerLeg.Z) * 0.42 + 0.03 * s
			f.add(side .. "UpperLeg", "KneeStud", Vector3.new(0.26, 0.26, 0.08) * s, CFrame.new(0, -thigh.Y / 2, -reach) * CFrame.Angles(0, 0, math.pi / 4), accent, METAL)
		end
	end
	f.model:SetAttribute("ArmourFinish", "chunky")
end

-- Signatures (owner, 16/10, with a picture of five heroes "neste nível"): each
-- hero's power shows on the figure itself in glowing shapes, fire, lightning,
-- a spell circle, chaos shards, orbiting moons. Shapes, never particles: a
-- battle of towers emits only at its portals and core (world_boot keeps it so).
local HERO_SIGNATURE = {}
-- Glowing power pieces of the costumes that pulse (or flicker, for flames).
local LIVING_POWERS = {
	FistGlow = "pulse", BlasterGlow = "pulse", ClubGlow = "pulse", MindGem = "pulse", PowerRing = "pulse", ConstructFist = "pulse",
	ConstructKnuckles = "pulse", SpeedTrail = "pulse", MineLight = "pulse", PsychicBlade = "pulse", PsychicFlame = "flicker",
	HeatEye = "pulse", TenRing = "pulse", CannonMuzzle = "pulse", ReactorCore = "pulse", GunMuzzle = "pulse", EnergyString = "pulse",
	EnergyArrow = "pulse", SonarVisor = "pulse", CosmicSigil = "pulse", TridentProng = "pulse", TiaraGem = "pulse", CoreSeam = "pulse",
	PhotonGauntlet = "pulse", StormSigil = "pulse", EmberSigil = "pulse", HammerRune = "pulse", ChestRingCore = "pulse",
	MagmaVein = "pulse", MagmaCrack = "pulse", VeinCore = "pulse", GlowBud = "pulse",
	Lasso = "pulse", BoltTop = "pulse", BoltBottom = "pulse", TideEmblem = "pulse", CircletGem = "pulse", ChestRing = "pulse",
}
-- Tags a piece for the client to move (Motion.Accents): orbit (rad/s) round
-- an axis through a pivot in its host's frame, flicker or pulse.
local function animate(part, kind, amount, pivot, axis)
	part:SetAttribute(kind, amount)
	if pivot then part:SetAttribute("FxPivot", pivot) end
	if axis then part:SetAttribute("FxAxis", axis) end
	return part
end
local function cylinderAt(f, host, name, diameter, height, offset, color, surface)
	return f.add(host, name, Vector3.new(height, diameter, diameter), offset * CFrame.Angles(0, 0, math.pi / 2), color, surface, Enum.PartType.Cylinder)
end
-- A zigzag bolt of glowing segments through the given points (host frame).
local function bolt(f, host, name, points, thickness, color)
	for i = 1, #points - 1 do f.rod(host, name, points[i], points[i + 1], thickness, color, NEON) end
end
-- A glowing seam down the outer side of a limb segment's armour.
local function seam(f, host, name, side, color)
	local size, girth = f.parts[host].Size, 1
	for _, piece in ipairs(f.model:GetChildren()) do
		local fit = piece:IsA("BasePart") and piece:FindFirstChild("Fit")
		if fit and fit.Part0 and fit.Part0.Name == host and piece.Material ~= NEON and piece.Size.Y > size.Y * 0.5 then girth = math.max(girth, piece.Size.X / size.X) end
	end
	local contour = f.parts[host]:FindFirstChild("BodyContour")
	if contour and contour.MeshType == Enum.MeshType.FileMesh then girth = math.max(girth, contour.Scale.X / size.X) end
	return f.add(host, name, Vector3.new(0.08 * f.scale, size.Y * 0.66, 0.08 * f.scale), CFrame.new(side * (size.X * girth / 2 + 0.02 * f.scale), 0, -size.Z * 0.16), color, NEON)
end
-- The armour heroes: their tech glows along the arms and legs.
local function seams(f, color, legs)
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "Left" or "Right"
		seam(f, name .. "LowerArm", "EnergySeam", side, color)
		if legs then seam(f, name .. "LowerLeg", "EnergySeam", side, color) end
	end
end
HERO_SIGNATURE.hulk = function(f)
	-- The stone giant cracks with lava down its arms and thighs.
	local glow, s = Color3.fromRGB(255, 140, 50), f.scale
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "Left" or "Right"
		for _, segment in ipairs({ "UpperArm", "UpperLeg" }) do
			local size = f.parts[name .. segment].Size
			local reach = math.min(size.X, size.Z) * 0.5
			f.add(name .. segment, "MagmaCrack", Vector3.new(0.09 * s, size.Y * 0.56, 0.07 * s), CFrame.new(side * reach * 0.82, 0, -reach * 0.56) * CFrame.Angles(0, side * 0.6, side * 0.35), glow, NEON)
		end
	end
end
HERO_SIGNATURE.groot = function(f)
	-- The tree giant buds with glowing green life on its shoulders and crown.
	local bud, s, h = Color3.fromRGB(120, 255, 140), f.scale, f.parts.Head.Size
	for _, side in ipairs({ -1, 1 }) do
		local arm = side < 0 and "LeftUpperArm" or "RightUpperArm"
		f.add(arm, "GlowBud", Vector3.new(0.22, 0.22, 0.22) * s, CFrame.new(side * f.sizes.upperArm.X * 0.3, f.sizes.upperArm.Y * 0.56, -0.1 * s), bud, NEON, "ball")
	end
	f.add("Head", "GlowBud", Vector3.new(0.24, 0.24, 0.24) * s, CFrame.new(-h.X * 0.18, h.Y * 0.62, 0.04 * s), bud, NEON, "ball")
end
HERO_SIGNATURE.wasp = function(f)
	-- Her wings shimmer as if buzzing.
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "Wing" then animate(piece, "FxPulse", 0.25) end
	end
	seams(f, f.glow or Color3.fromRGB(255, 220, 60), true)
end
HERO_SIGNATURE.spiderman = function(f)
	-- The spider on his chest glows orange.
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "SpiderEmblem" then piece.Color, piece.Material = Color3.fromRGB(255, 140, 40), NEON; animate(piece, "FxPulse", 0.25) end
	end
	seams(f, f.glow or Color3.fromRGB(255, 140, 40), true)
end
-- The rest of the roster (owner, 16/10: "continue até terminar todos os
-- heróis"): each hero gets a piece of silhouette or a glowing signature in the
-- pictures' spirit, on top of the armour, the trims and the seams.
local function glowSeams(f, fallback) seams(f, f.glow or fallback, true) end
HERO_SIGNATURE.hawkeye = function(f)
	-- An archer's short cloak.
	seams(f, Color3.fromRGB(100, 255, 120), false)
	cape(f, Color3.fromRGB(38, 92, 60), 2.4, HC.leather)
end
HERO_SIGNATURE.antman = function(f)
	-- Two particle canisters on his back, their caps glowing red.
	local c, s = f.sizes.chest, f.scale
	for _, side in ipairs({ -1, 1 }) do
		local at = CFrame.new(side * c.X * 0.2, -c.Y * 0.02, c.Z / 2 + 0.24 * s)
		cylinderAt(f, "UpperTorso", "PymCanister", 0.42 * s, c.Y * 0.62, at, Color3.fromRGB(150, 156, 166), FABRIC)
		animate(cylinderAt(f, "UpperTorso", "PymCap", 0.34 * s, 0.1 * s, at * CFrame.new(0, c.Y * 0.33, 0), Color3.fromRGB(255, 60, 60), NEON), "FxPulse", 0.3)
	end
	glowSeams(f, Color3.fromRGB(255, 60, 60))
end
HERO_SIGNATURE.rocket = function(f)
	-- A jet pack with two burning nozzles.
	local c, s = f.sizes.chest, f.scale
	f.add("UpperTorso", "JetPack", Vector3.new(c.X * 0.66, c.Y * 0.78, 0.5 * s), CFrame.new(0, 0, c.Z / 2 + 0.27 * s), Color3.fromRGB(70, 76, 88), FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		animate(cylinderAt(f, "UpperTorso", "JetFlame", 0.26 * s, 0.22 * s, CFrame.new(side * c.X * 0.2, -c.Y * 0.45, c.Z / 2 + 0.3 * s), Color3.fromRGB(255, 140, 40), NEON), "FxPulse", 0.35)
	end
	glowSeams(f, Color3.fromRGB(255, 140, 40))
end
HERO_SIGNATURE.daredevil = function(f)
	-- Horns on the mask and a glowing red mark on the chest.
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "MaskHorn", Vector3.new(0.12 * s, 0.4 * s, 0.22 * s), CFrame.new(side * h.X * 0.24, h.Y * 0.52, -h.Z * 0.06) * CFrame.Angles(0, math.pi / 2, side * 0.22), Color3.fromRGB(176, 30, 40), FABRIC, "wedge")
	end
	animate(f.add("UpperTorso", "ChestMark", Vector3.new(0.3, 0.3, 0.06) * s, CFrame.new(0, c.Y * 0.2, -c.Z * 0.51 - 0.06 * s) * CFrame.Angles(0, 0, math.pi / 4), Color3.fromRGB(255, 50, 60), NEON), "FxPulse", 0.3)
	glowSeams(f, Color3.fromRGB(255, 50, 60))
end
HERO_SIGNATURE.vision = function(f)
	-- Gold lines framing the chest, like the pictures' plates.
	local c, s = f.sizes.chest, f.scale
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "ChestGoldLine", Vector3.new(0.08 * s, c.Y * 0.62, 0.06 * s), CFrame.new(side * c.X * 0.36, c.Y * 0.12, -c.Z * 0.51 - 0.03 * s), Color3.fromRGB(255, 196, 60), FABRIC)
	end
	glowSeams(f, Color3.fromRGB(120, 240, 255))
end
HERO_SIGNATURE.warmachine = function(f)
	-- A missile pod on the other shoulder, warheads glowing, and an ammo belt.
	local c, s = f.sizes.chest, f.scale
	local pod = CFrame.new(-c.X * 0.36, c.Y / 2 + 0.32 * s, -0.1 * s)
	f.add("UpperTorso", "MissilePod", Vector3.new(0.7 * s, 0.56 * s, 0.9 * s), pod, Color3.fromRGB(70, 74, 82), FABRIC)
	for i, x in ipairs({ -0.16, 0.16 }) do
		for _, y in ipairs({ -0.12, 0.12 }) do
			animate(f.add("UpperTorso", "Warhead", Vector3.new(0.14, 0.14, 0.08) * s, pod * CFrame.new(x * s, y * s, -0.47 * s), Color3.fromRGB(255, 70, 50), NEON), "FxPulse", 0.25)
		end
	end
	f.rod("UpperTorso", "AmmoBelt", Vector3.new(-c.X * 0.34, c.Y * 0.4, -c.Z * 0.53), Vector3.new(c.X * 0.3, -c.Y * 0.36, -c.Z * 0.53), 0.14 * s, Color3.fromRGB(200, 160, 60), FABRIC)
	glowSeams(f, Color3.fromRGB(255, 140, 40))
end
HERO_SIGNATURE.starlord = function(f)
	-- Coat tails behind and jet boots that burn.
	local p, s = f.parts.LowerTorso.Size, f.scale
	local coat = Color3.fromRGB(110, 40, 46)
	for _, side in ipairs({ -1, 1 }) do
		local frame = CFrame.new(side * p.X * 0.27, -p.Y * 0.4, p.Z * 0.56) * CFrame.Angles(0.16, 0, side * 0.06)
		f.add("LowerTorso", "CoatTail", Vector3.new(p.X * 0.46, 1.9 * s, 0.08 * s), frame * CFrame.new(0, -0.95 * s, 0), coat, FABRIC)
		local foot = side < 0 and "LeftFoot" or "RightFoot"
		local b = f.parts[foot].Size
		animate(f.add(foot, "JetSole", Vector3.new(b.X * 0.8, 0.08 * s, b.Z * 0.6), CFrame.new(0, -b.Y * 0.56, 0.05 * s), Color3.fromRGB(255, 130, 40), NEON), "FxPulse", 0.35)
	end
	-- A star pirate's coat: the night sky on its tails.
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "CoatTail" then pattern(piece, "galaxy", Enum.NormalId.Back) end
	end
	glowSeams(f, Color3.fromRGB(255, 130, 40))
end
HERO_SIGNATURE.emerald = function(f)
	-- A shield of green light on the left arm, breathing.
	local s, arm = f.scale, f.sizes.lowerArm
	local shield = f.disc("LeftLowerArm", "ConstructShield", 1.8 * s, 0.06 * s, CFrame.new(-arm.X * 0.75, 0, -0.1 * s) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(90, 255, 120), NEON)
	shield.Transparency = 0.45
	animate(shield, "FxPulse", 0.25)
	glowSeams(f, Color3.fromRGB(90, 255, 120))
end
HERO_SIGNATURE.speedster = function(f)
	-- The speed force crackles behind him in two golden trails.
	local c, s = f.sizes.chest, f.scale
	local gold = Color3.fromRGB(255, 214, 70)
	for _, side in ipairs({ -1, 1 }) do
		local x = side * c.X * 0.32
		bolt(f, "UpperTorso", "SpeedBolt", { Vector3.new(x, c.Y * 0.2, c.Z * 0.55), Vector3.new(x + side * 0.2 * s, c.Y * 0.05, c.Z * 0.55 + 0.5 * s), Vector3.new(x, -c.Y * 0.1, c.Z * 0.55 + 0.9 * s), Vector3.new(x + side * 0.2 * s, -c.Y * 0.25, c.Z * 0.55 + 1.4 * s) }, 0.07 * s, gold)
	end
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "SpeedBolt" then animate(piece, "FxPulse", 0.6) end
	end
	glowSeams(f, gold)
end
HERO_SIGNATURE.wolverine = function(f)
	-- A red X on the belt buckle.
	local p, s = f.parts.LowerTorso.Size, f.scale
	for _, tilt in ipairs({ -0.7, 0.7 }) do
		f.add("LowerTorso", "BuckleX", Vector3.new(0.08 * s, 0.46 * s, 0.04 * s), CFrame.new(0, p.Y * 0.26, -p.Z * 0.56 - 0.13 * s) * CFrame.Angles(0, 0, tilt), Color3.fromRGB(220, 40, 40), FABRIC)
	end
	glowSeams(f, Color3.fromRGB(255, 200, 60))
end
HERO_SIGNATURE.jean = function(f)
	-- Phoenix wings of flame behind her, three feathers a side, licking.
	local c, s = f.sizes.chest, f.scale
	local flame, ember = Color3.fromRGB(255, 120, 40), Color3.fromRGB(255, 210, 80)
	for _, side in ipairs({ -1, 1 }) do
		for i, feather in ipairs({ { 2.2, 0.5, 0.55, 0.6 }, { 1.9, 0.44, 0.15, 0.3 }, { 1.5, 0.38, -0.2, 0.02 } }) do
			local length, width, rise, tilt = feather[1] * s, feather[2] * s, feather[3] * s, feather[4]
			animate(f.add("UpperTorso", "PhoenixFeather", Vector3.new(length, width, 0.07 * s), CFrame.new(side * (c.X * 0.34 + length * 0.46), rise, c.Z / 2 + 0.3 * s + i * 0.03 * s) * CFrame.Angles(0, side * 0.3, side * tilt), i == 1 and ember or flame, NEON), "FxFlicker", 0.08)
		end
	end
	-- The phoenix's cape burns at the hem.
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "Cape" or piece.Name == "CapeHem" then pattern(piece, "flames", Enum.NormalId.Back) end
	end
	glowSeams(f, flame)
end
HERO_SIGNATURE.beast = function(f)
	-- Shaggy fur on the shoulders.
	local s, arm = f.scale, f.sizes.upperArm
	for _, side in ipairs({ -1, 1 }) do
		local name = side < 0 and "LeftUpperArm" or "RightUpperArm"
		f.add(name, "FurTuft", Vector3.new(arm.X * 1.2, arm.Y * 0.5, arm.Z * 1.15), CFrame.new(side * arm.X * 0.1, arm.Y * 0.42, 0), Color3.fromRGB(48, 84, 160), FABRIC, "ball")
	end
	glowSeams(f, Color3.fromRGB(110, 170, 255))
end
HERO_SIGNATURE.psylocke = function(f)
	-- Sash tails fluttering behind and a psychic mark over the eye.
	local p, h, s = f.parts.LowerTorso.Size, f.parts.Head.Size, f.scale
	local violet = Color3.fromRGB(120, 40, 160)
	for _, side in ipairs({ -1, 1 }) do
		f.add("LowerTorso", "SashTail", Vector3.new(0.28 * s, 1.6 * s, 0.06 * s), CFrame.new(side * p.X * 0.16, -p.Y * 0.2 - 0.8 * s, p.Z * 0.58) * CFrame.Angles(0.22, 0, side * 0.18), violet, FABRIC)
	end
	animate(f.add("Head", "PsychicMark", Vector3.new(0.16, 0.24, 0.05) * s, f.face(-0.36, 0.34, 0.05) * CFrame.Angles(0, 0, 0.4), Color3.fromRGB(255, 110, 200), NEON), "FxPulse", 0.3)
	glowSeams(f, Color3.fromRGB(255, 110, 200))
end
HERO_SIGNATURE.nightstalker = function(f)
	-- A gold utility belt of pouches.
	local p, s = f.parts.LowerTorso.Size, f.scale
	for _, x in ipairs({ -0.36, -0.18, 0.18, 0.36 }) do
		f.add("LowerTorso", "BeltPouch", Vector3.new(0.26, 0.3, 0.16) * s, CFrame.new(p.X * x, p.Y * 0.2, -p.Z * 0.56 - 0.06 * s), Color3.fromRGB(230, 180, 50), FABRIC)
	end
	glowSeams(f, Color3.fromRGB(80, 140, 255))
end
HERO_SIGNATURE.seaking = function(f)
	-- A sea-green cape with a gold hem.
	cape(f, Color3.fromRGB(22, 112, 104), 3.4, Color3.fromRGB(240, 196, 60))
	glowSeams(f, Color3.fromRGB(60, 230, 210))
end
HERO_SIGNATURE.capmen = function(f)
	-- A glowing ring round his chest roundel.
	local c, s = f.sizes.chest, f.scale
	animate(f.disc("UpperTorso", "RoundelGlow", 0.76 * s, 0.03 * s, CFrame.new(0, c.Y * 0.14, -c.Z / 2 - 0.022 * s), Color3.fromRGB(255, 170, 60), NEON), "FxPulse", 0.3)
	glowSeams(f, Color3.fromRGB(255, 150, 60))
end
HERO_SIGNATURE.solartitan = function(f)
	-- A sun's halo behind his head.
	local h, s = f.parts.Head.Size, f.scale
	-- The sun's fire on his cape.
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "CapeHem" then pattern(piece, "flames", Enum.NormalId.Back) end
	end
	local halo = f.disc("Head", "SunHalo", h.X * 1.9, 0.04 * s, CFrame.new(0, h.Y * 0.1, h.Z * 0.62), Color3.fromRGB(255, 200, 70), NEON)
	halo.Transparency = 0.45
	animate(halo, "FxPulse", 0.25)
	glowSeams(f, Color3.fromRGB(255, 200, 70))
end
HERO_SIGNATURE.amazon = function(f)
	-- A warrior's skirt of blue and gold strips.
	local p, s = f.parts.LowerTorso.Size, f.scale
	for i, x in ipairs({ -0.36, -0.12, 0.12, 0.36 }) do
		f.add("LowerTorso", "SkirtStrip", Vector3.new(p.X * 0.22, 0.7 * s, 0.07 * s), CFrame.new(p.X * x, -p.Y * 0.5 - 0.3 * s, -p.Z * 0.55) * CFrame.Angles(-0.12, 0, x * 0.3), i % 2 == 0 and Color3.fromRGB(240, 186, 50) or Color3.fromRGB(40, 70, 160), FABRIC)
	end
	glowSeams(f, Color3.fromRGB(255, 200, 70))
end
HERO_SIGNATURE.storm = function(f)
	local spark, s = Color3.fromRGB(170, 230, 255), f.scale
	bolt(f, "RightHand", "Lightning", { Vector3.new(-0.2, -0.3, -0.2) * s, Vector3.new(0.1, -0.7, -0.3) * s, Vector3.new(-0.12, -1.0, -0.2) * s, Vector3.new(0.18, -1.4, -0.3) * s }, 0.06 * s, spark)
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "Lightning" then animate(piece, "FxPulse", 0.7) end
	end
	seams(f, f.glow or spark, true)
end
HERO_SIGNATURE.ironman = function(f)
	local cyan = Color3.fromRGB(80, 214, 255)
	seams(f, cyan, true)
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "RepulsorCore" or piece.Name == "ThrusterSole" or piece.Name == "EnergyLineL" or piece.Name == "EnergyLineR" then piece.Color, piece.Material = cyan, NEON end
		if piece.Name == "PadRim" then piece.Color = cyan; piece.Material = NEON end
	end
	-- The reactor glows round the bolt's diamond, just in front of the armour.
	local c, s = f.sizes.chest, f.scale
	animate(f.add("UpperTorso", "ReactorGlow", Vector3.new(0.86 * s, 0.86 * s, 0.012 * s), CFrame.new(0, c.Y * 0.16, -c.Z / 2 - 0.097 * s) * CFrame.Angles(0, 0, math.pi / 4), cyan, NEON), "FxPulse", 0.3)
end
HERO_SIGNATURE.falcon = function(f)
	-- The jetpack's thrusters burn.
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "ThrusterNozzle" then animate(piece, "FxPulse", 0.3); piece.Color, piece.Material = Color3.fromRGB(255, 140, 40), NEON end
	end
	seams(f, f.glow or Color3.fromRGB(80, 210, 255), true)
end
HERO_SIGNATURE.captainmarvel = function(f)
	-- Her sun's rays breathe light.
	for _, piece in ipairs(f.model:GetChildren()) do
		if string.find(piece.Name, "^SunRay") then animate(piece, "FxPulse", 0.35) end
	end
	seams(f, f.glow or Color3.fromRGB(255, 200, 60), true)
end
HERO_SIGNATURE.bucky = function(f)
	-- The red star on the metal arm glows.
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "RedStar" then piece.Color, piece.Material = Color3.fromRGB(255, 50, 64), NEON end
	end
	seams(f, f.glow or Color3.fromRGB(80, 210, 255), true)
end
HERO_SIGNATURE.captain = function(f)
	-- A glowing ring round the shield's rim, just behind it.
	local shield = f.model:FindFirstChild("Shield")
	local fit = shield and shield:FindFirstChild("Fit")
	if fit then
		local base = fit.C0 * CFrame.Angles(0, -math.pi / 2, 0)
		f.disc(fit.Part0.Name, "ShieldGlow", shield.Size.Y * 1.07, 0.05 * f.scale, base * CFrame.new(0, 0, shield.Size.X / 2 + 0.04 * f.scale), Color3.fromRGB(80, 230, 220), NEON)
	end
end
HERO_SIGNATURE.panther = function(f)
	-- Vibranium energy: violet lines down the arms and legs, glowing claws and
	-- a necklace of claws at the collar.
	local violet = Color3.fromRGB(186, 104, 255)
	seams(f, violet, true)
	local c, s = f.sizes.chest, f.scale
	for i, x in ipairs({ -0.27, -0.09, 0.09, 0.27 }) do
		f.add("UpperTorso", "NecklaceClaw", Vector3.new(0.12, 0.3, 0.1) * s, CFrame.new(c.X * x, c.Y * 0.36 - math.abs(x) * 0.25 * s, -c.Z * 0.51 - 0.06 * s) * CFrame.Angles(0, 0, x * 1.2), violet, NEON)
	end
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "Claw" or piece.Name == "ChestGem" then piece.Color, piece.Material = violet, NEON end
	end
end
HERO_SIGNATURE.widow = function(f)
	-- Electric bracelets and a glowing hourglass.
	local shock = Color3.fromRGB(70, 196, 255)
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "Bracelet" then piece.Color, piece.Material = shock, NEON end
		if piece.Name == "WidowInsignia" then piece.Color, piece.Material = Color3.fromRGB(255, 50, 70), NEON end
	end
	seams(f, shock, false)
end
-- (The rider's chain: links hanging from his belt on the left hip.)
local function chain(f, links, color)
	local p, s = f.parts.LowerTorso.Size, f.scale
	for i = 1, links do
		local turn = (i % 2 == 0) and math.pi / 2 or 0
		f.add("LowerTorso", "ChainLink", Vector3.new(0.08, 0.3, 0.2) * s, CFrame.new(-p.X * 0.42 - 0.02 * s * i, -p.Y * 0.3 - i * 0.24 * s, -p.Z * 0.3 + i * 0.06 * s) * CFrame.Angles(0, turn, 0.25), color, METAL)
	end
end
HERO_SIGNATURE.ghostrider = function(f)
	local s, h = f.scale, f.parts.Head.Size
	local fire, flare = Color3.fromRGB(255, 118, 28), Color3.fromRGB(255, 214, 84)
	-- A crown of fire: the three tongues burn orange and gold, taller, with two
	-- more behind them.
	for _, piece in ipairs(f.model:GetChildren()) do
		local i = tonumber(string.match(piece.Name, "^CrownFlame(%-?%d)$"))
		if i then
			piece.Size = Vector3.new(0.46 * s, (1.5 - math.abs(i) * 0.34) * s, 0.46 * s)
			piece.Color, piece.Material, piece.Transparency = i == 0 and flare or fire, NEON, 0.05
			local fit = piece:FindFirstChild("Fit")
			fit.C0 = CFrame.new(i * h.X * 0.26, h.Y * 0.5 + piece.Size.Y * 0.42, 0.04 * s) * CFrame.Angles(0, math.pi / 4, i * -0.18)
			piece.CFrame = f.parts.Head.CFrame * fit.C0
		end
	end
	for _, piece in ipairs(f.model:GetChildren()) do
		if string.find(piece.Name, "^CrownFlame") then animate(piece, "FxFlicker", 0.12) end
	end
	chain(f, 5, Color3.fromRGB(196, 200, 208))
	-- Dark leather pads and sleeves with flames painted on them, like the picture's.
	if ARMOUR_ART.flames ~= 0 then
		for _, name in ipairs({ "LeftUpperArm", "RightUpperArm" }) do f.parts[name].Color = Color3.fromRGB(46, 42, 50) end
	end
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "SpikedPauldron" then
			if ARMOUR_ART.flames ~= 0 then piece.Color = Color3.fromRGB(38, 34, 40) end
			-- Every face: the pad is a wedge turned round for the left arm.
			for _, face in ipairs({ Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right }) do pattern(piece, "flames", face) end
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		animate(f.add("Head", "CrownFlameBack", Vector3.new(0.4, 1.0, 0.4) * s, CFrame.new(side * h.X * 0.16, h.Y * 0.62, h.Z * 0.28) * CFrame.Angles(0.3, math.pi / 4, side * -0.3), fire, NEON), "FxFlicker", 0.12)
		-- Flames licking up from each shoulder pad.
		local arm = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local a = f.parts[arm].Size
		for i, tongue in ipairs({ { 0.14, 0.9, flare }, { -0.2, 0.66, fire } }) do
			animate(f.add(arm, "PadFlame", Vector3.new(0.28 * s, tongue[2] * s, 0.28 * s), CFrame.new(side * a.X * tongue[1], a.Y * 0.62 + tongue[2] * s * 0.32, 0) * CFrame.Angles(0, math.pi / 4, side * (0.3 + i * 0.25)), tongue[3], NEON), "FxFlicker", 0.14)
		end
		-- A glowing rim under each spiked pad.
		f.add(arm, "PadGlow", Vector3.new(a.X * 1.3, 0.08 * s, a.Z * 1.26), CFrame.new(0, a.Y * 0.04, 0), fire, NEON)
		-- And from each boot's heel.
		local foot = side < 0 and "LeftFoot" or "RightFoot"
		local b = f.parts[foot].Size
		animate(f.add(foot, "HeelFlame", Vector3.new(0.18, 0.5, 0.18) * s, CFrame.new(side * b.X * 0.3, b.Y * 0.6, b.Z * 0.42) * CFrame.Angles(0.3, math.pi / 4, side * 0.4), fire, NEON), "FxFlicker", 0.14)
	end
end
HERO_SIGNATURE.strange = function(f)
	local s, h = f.scale, f.parts.Head.Size
	local gold, amber = HC.gold, Color3.fromRGB(255, 200, 90)
	local teal = Color3.fromRGB(30, 150, 140)
	-- A wizard's hat: a wide round brim, a cone of three tiers bending back
	-- and a gold band with a glowing gem.
	for _, name in ipairs({ "HatBrim", "HatCone" }) do
		local old = f.model:FindFirstChild(name)
		if old then teal = old.Color; old:Destroy() end
	end
	cylinderAt(f, "Head", "HatBrim", h.X * 1.8, 0.1 * s, CFrame.new(0, h.Y * 0.47, 0), teal, FABRIC)
	f.add("Head", "HatCone", Vector3.new(h.X * 0.86, h.Y * 0.74, h.X * 0.86), CFrame.new(0, h.Y * 0.62, 0), teal, FABRIC, "ball")
	f.add("Head", "HatCone", Vector3.new(h.X * 0.48, h.Y * 0.72, h.X * 0.48), CFrame.new(0, h.Y * 0.98, h.Z * 0.1) * CFrame.Angles(0.34, 0, 0), teal, FABRIC, "ball")
	f.add("Head", "HatTip", Vector3.new(0.24, 0.24, 0.24) * s, CFrame.new(0, h.Y * 1.3, h.Z * 0.3), teal, FABRIC, "ball")
	cylinderAt(f, "Head", "HatBand", h.X * 0.87, 0.12 * s, CFrame.new(0, h.Y * 0.56, 0), gold, METAL)
	f.add("Head", "HatGem", Vector3.new(0.26, 0.26, 0.08) * s, CFrame.new(0, h.Y * 0.62, -h.X * 0.45) * CFrame.Angles(0, 0, math.pi / 4), amber, NEON)
	-- The spell circle at his left hand is a glowing disc behind its glyphs.
	-- (Off the glyphs' planes: coplanar faces flicker.)
	animate(f.disc("LeftHand", "MagicCircle", 1.56 * s, 0.03 * s, CFrame.new(0, -0.42 * s, -0.463 * s), amber, NEON), "FxPulse", 0.2).Transparency = 0.62
	f.disc("LeftHand", "MagicCore", 0.5 * s, 0.05 * s, CFrame.new(0, -0.42 * s, -0.533 * s), gold, NEON).Transparency = 0.2
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "SpellGlyph" then animate(piece, "FxOrbit", 0.9, Vector3.new(0, -0.42 * s, -0.52 * s), Vector3.new(0, 0, 1)) end
	end
	-- A long open coat: two front panels and two tails hanging from the waist
	-- to the shins, gold along their outer edges, a glowing rune on each front.
	local p = f.parts.LowerTorso.Size
	for _, side in ipairs({ -1, 1 }) do
		for _, back in ipairs({ false, true }) do
			local z = back and p.Z * 0.56 or -p.Z * 0.56
			local frame = CFrame.new(side * p.X * 0.27, -p.Y * 0.4, z) * CFrame.Angles(back and 0.16 or -0.1, 0, side * 0.06)
			local length = (back and 2.3 or 1.9) * s
			pattern(f.add("LowerTorso", "CoatPanel", Vector3.new(p.X * 0.46, length, 0.08 * s), frame * CFrame.new(0, -length / 2, 0), teal, FABRIC), "runes", back and Enum.NormalId.Back or Enum.NormalId.Front)
			f.add("LowerTorso", "CoatEdge", Vector3.new(0.09 * s, length, 0.1 * s), frame * CFrame.new(side * p.X * 0.23, -length / 2, 0), gold, FABRIC)
			if not back then
				animate(f.add("LowerTorso", "CoatRune", Vector3.new(0.22, 0.22, 0.06) * s, frame * CFrame.new(0, -length * 0.55, -0.05 * s) * CFrame.Angles(0, 0, math.pi / 4), amber, NEON), "FxPulse", 0.35)
			end
		end
	end
	local c = f.sizes.chest
	f.add("UpperTorso", "CollarFlare", Vector3.new(c.X * 0.84, 0.62 * s, 0.1 * s), CFrame.new(0, c.Y / 2 + 0.2 * s, c.Z * 0.42) * CFrame.Angles(-0.32, 0, 0), teal, FABRIC)
end
HERO_SIGNATURE.wanda = function(f)
	local s = f.scale
	local chaos, deep = Color3.fromRGB(255, 56, 190), Color3.fromRGB(176, 30, 130)
	-- Chaos magic is magenta: the orbs, the gems and shards floating round
	-- each hand.
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "ChaosOrb" or piece.Name == "BrowGem" or piece.Name == "BodiceGem" then piece.Color = chaos end
		if piece.Name == "ChaosOrb" then animate(piece, "FxPulse", 0.3) end
	end
	for _, side in ipairs({ -1, 1 }) do
		local hand = side < 0 and "LeftHand" or "RightHand"
		for i, shard in ipairs({ { 0.5, -0.2 }, { -0.42, -0.62 }, { 0.36, -0.95 } }) do
			animate(f.add(hand, "ChaosShard", Vector3.new(0.18, 0.28, 0.06) * s, CFrame.new(side * shard[1] * s, shard[2] * s, -0.3 * s) * CFrame.Angles(0, i, math.pi / 4), chaos, NEON),
				"FxOrbit", side * 1.3, Vector3.new(0, -0.52 * s, -0.12 * s), Vector3.new(0, 1, 0))
		end
	end
	-- Gold lines down the bodice, like a corset's.
	local c = f.sizes.chest
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "BodiceLine", Vector3.new(0.08 * s, c.Y * 0.6, 0.06 * s), CFrame.new(side * c.X * 0.24, c.Y * 0.12, -c.Z * 0.51 - 0.03 * s), Color3.fromRGB(255, 196, 60), FABRIC)
	end
	-- A long flared skirt from the belt, front, back and sides, gold at the hem.
	local p = f.parts.LowerTorso.Size
	for i = 0, 3 do
		local yaw = i * math.pi / 2
		local wide = (i % 2 == 0) and p.X * 0.96 or p.Z * 0.9
		local reach = (i % 2 == 0) and p.Z * 0.5 or p.X * 0.5
		local hang = CFrame.Angles(0, yaw, 0) * CFrame.new(0, -p.Y * 0.2, -reach - 0.08 * s) * CFrame.Angles(0.24, 0, 0)
		f.add("LowerTorso", "SkirtFlare", Vector3.new(wide * 1.08, 1.6 * s, 0.1 * s), hang * CFrame.new(0, -0.8 * s, 0), deep, FABRIC)
		f.add("LowerTorso", "SkirtHem", Vector3.new(wide * 1.12, 0.12 * s, 0.12 * s), hang * CFrame.new(0, -1.6 * s, 0), Color3.fromRGB(255, 196, 60), FABRIC)
	end
end
HERO_SIGNATURE.thor = function(f)
	local s = f.scale
	local spark, cloud = Color3.fromRGB(140, 220, 255), Color3.fromRGB(244, 248, 255)
	for _, side in ipairs({ -1, 1 }) do
		local arm = side < 0 and "LeftUpperArm" or "RightUpperArm"
		local a = f.parts[arm].Size
		-- Storm-cloud pads: two white puffs on each.
		f.add(arm, "CloudPuff", Vector3.new(0.7, 0.56, 0.7) * s, CFrame.new(side * a.X * 0.34, a.Y * 0.62, -a.Z * 0.12), cloud, FABRIC, "ball")
		f.add(arm, "CloudPuff", Vector3.new(0.56, 0.46, 0.56) * s, CFrame.new(side * a.X * 0.62, a.Y * 0.5, a.Z * 0.18), cloud, FABRIC, "ball")
		-- Lightning crawling down each gauntlet.
		local forearm = side < 0 and "LeftLowerArm" or "RightLowerArm"
		local l = f.parts[forearm].Size
		local x = side * l.X * 0.66
		bolt(f, forearm, "Lightning", { Vector3.new(x, l.Y * 0.42, -l.Z * 0.1), Vector3.new(x + side * 0.16 * s, l.Y * 0.12, l.Z * 0.12), Vector3.new(x, -l.Y * 0.14, -l.Z * 0.14), Vector3.new(x + side * 0.2 * s, -l.Y * 0.46, 0) }, 0.06 * s, spark)
	end
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "PadStud" then piece.Color, piece.Material = spark, NEON end
		if piece.Name == "Lightning" then animate(piece, "FxPulse", 0.7) end
	end
	local c = f.sizes.chest
	f.add("UpperTorso", "StormGem", Vector3.new(0.34, 0.34, 0.08) * s, CFrame.new(0, c.Y * 0.2, -c.Z * 0.51 - 0.07 * s) * CFrame.Angles(0, 0, math.pi / 4), spark, NEON)
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "ChestGoldLine", Vector3.new(0.08 * s, c.Y * 0.62, 0.06 * s), CFrame.new(side * c.X * 0.36, c.Y * 0.12, -c.Z * 0.51 - 0.03 * s), Color3.fromRGB(255, 196, 60), FABRIC)
	end
	-- And arcing round the hammer's head.
	bolt(f, "RightHand", "Lightning", { Vector3.new(-0.42, 1.0, -0.1) * s, Vector3.new(-0.2, 1.24, -0.32) * s, Vector3.new(0.1, 1.08, -0.3) * s, Vector3.new(0.4, 1.4, -0.12) * s }, 0.05 * s, spark)
end
HERO_SIGNATURE.silversurfer = function(f)
	local s, c = f.scale, f.sizes.chest
	local cosmic, starlight, night = Color3.fromRGB(100, 180, 255), Color3.fromRGB(255, 230, 140), Color3.fromRGB(58, 34, 132)
	-- Three moons on the orbit, and a cape of the night sky with stars on it.
	local orbitRadius = 1.52 * s
	for i, tint in ipairs({ cosmic, Color3.fromRGB(196, 120, 255) }) do
		local a = i * math.pi * 2 / 3
		f.add("UpperTorso", "MoonOrb", Vector3.new(0.3, 0.3, 0.3) * s, CFrame.new(math.cos(a) * orbitRadius, 0.92 * s, math.sin(a) * orbitRadius), tint, NEON, "ball")
	end
	for _, piece in ipairs(f.model:GetChildren()) do
		if string.find(piece.Name, "^OrbitSegment") or piece.Name == "MoonOrb" then animate(piece, "FxOrbit", 0.6, Vector3.new(0, 0.92 * s, 0), Vector3.new(0, 1, 0)) end
	end
	cape(f, night, 3.4, Color3.fromRGB(200, 210, 220))
	for _, piece in ipairs(f.model:GetChildren()) do
		if piece.Name == "Cape" or piece.Name == "CapeHem" then pattern(piece, "galaxy", Enum.NormalId.Back) end
	end
	-- White armour over the cosmic suit (forearms, shins, boots), like the
	-- picture's two-tone herald.
	local white = Color3.fromRGB(232, 238, 248)
	for _, name in ipairs({ "LeftLowerArm", "RightLowerArm", "LeftLowerLeg", "RightLowerLeg", "LeftFoot", "RightFoot" }) do
		f.parts[name].Color = white
	end
	for _, piece in ipairs(f.model:GetChildren()) do
		local fit = piece:IsA("BasePart") and piece:FindFirstChild("Fit")
		local host = fit and fit.Part0 and fit.Part0.Name
		if host and (string.find(host, "LowerArm") or string.find(host, "LowerLeg") or string.find(host, "Foot")) and piece.Material ~= NEON and piece.Name ~= "BootSole" and piece.Name ~= "KneeCap" then
			piece.Color = white
		end
	end
	f.add("UpperTorso", "CosmicCore", Vector3.new(0.5, 0.5, 0.08) * s, CFrame.new(0, c.Y * 0.16, -c.Z * 0.51 - 0.06 * s), Color3.fromRGB(255, 236, 160), NEON)
	for i, star in ipairs({ { -0.3, -0.5 }, { 0.22, -0.95 }, { -0.12, -1.45 }, { 0.36, -1.85 }, { -0.4, -2.2 } }) do
		local depth = c.Z / 2 + 0.16 * s - star[2] * s * 0.08 + (star[2] < -1.6 and 0.2 * s or 0)
		f.add("UpperTorso", "CapeStar", Vector3.new(0.14, 0.14, 0.06) * s, CFrame.new(c.X * star[1], c.Y / 2 + star[2] * s, depth) * CFrame.Angles(0, 0, math.pi / 4), i % 2 == 0 and starlight or cosmic, NEON)
	end
end

-- Masked and helmeted heroes (owner, 15/10: refine the faces). A visor or a
-- jaw plate was a flat bar that stood out past the round head in a
-- three-quarter view: each now wraps the front of the head, a band whose back
-- half sits inside it (depth: how far its front stands off the face, in head
-- depths); lenses and eye slits turn with the round of the face.
local FRONT_WRAP = { VisorBand = 0.085, SonarVisor = 0.085, EyeSlits = 0.085, SpiritVisor = 0.085, OpticVisor = 0.085, HoodTrim = 0.07,
	ChinGuard = 0.06, JawRidge = 0.06, FacePlate = 0.05 }
-- Lenses: how far each stands off the face (a rim or patch under its lens).
local FRONT_TURN = { EyeLens = 0.026, EyeSlit = 0.026, EyeGlow = 0.03, EyeRim = 0.012, EyePatch = 0.012 }
local function wrapMaskedFace(figure)
	local head = figure.parts.Head
	local h = head.Size
	-- The lenses of a pair stand apart by the widest of them, so two ovals
	-- never run into one another between the eyes.
	local spread = 0
	for _, piece in ipairs(figure.model:GetChildren()) do
		if FRONT_TURN[piece.Name] and piece:IsA("BasePart") then
			spread = math.max(spread, math.max(piece.Size.X, piece.Size.Y) / h.X / 2 + 0.025)
		end
	end
	for _, piece in ipairs(figure.model:GetChildren()) do
		local fit = piece:IsA("BasePart") and piece:FindFirstChild("Fit")
		if not (fit and fit.Part0 == head) then continue end
		local depth = FRONT_WRAP[piece.Name]
		if depth then
			local band = piece
			if not piece:IsA("Part") then
				-- A wedge takes no mesh: a plain part takes its place.
				band = figurePart(figure.model, piece.Name, piece.Size, piece.CFrame, piece.Color, piece.Material)
				band.Transparency, band.Reflectance = piece.Transparency or 0, piece.Reflectance or 0
				band:SetAttribute("HeroVisual", true)
				piece:Destroy()
				figureWeld(head, band)
				fit = band:FindFirstChild("Fit")
			end
			local y = fit.C0.Position.Y
			-- A jaw piece is a little narrower than the head, so the head's own
			-- round hides it at the sides and the back: it shows only at the front
			-- (a full ring read as a collar, a skin-coloured one as a scarf).
			local jaw = band.Name == "ChinGuard" or band.Name == "JawRidge" or band.Name == "FacePlate"
			local across = jaw and 0.93 or 1
			band.Size = Vector3.new(h.X * across, math.min(band.Size.Y, h.Y * 0.62), h.Z * across)
			local mesh = band:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh")
			mesh.MeshType, mesh.Parent = Enum.MeshType.Head, band
			fit.C0 = CFrame.new(0, y, -h.Z * depth)
			band.CFrame = head.CFrame * fit.C0
		elseif FRONT_TURN[piece.Name] then
			-- A lens is an oval laid on the round of the face, wider than tall,
			-- its inner corner a little lower (a wedge read as a jagged crown
			-- up close, half buried in the head).
			local lens = piece
			if not piece:IsA("Part") then
				lens = figurePart(figure.model, piece.Name, piece.Size, piece.CFrame, piece.Color, piece.Material)
				lens.Transparency, lens.Reflectance = piece.Transparency or 0, piece.Reflectance or 0
				lens:SetAttribute("HeroVisual", true)
				piece:Destroy()
				figureWeld(head, lens)
				fit = lens:FindFirstChild("Fit")
			end
			local mesh = lens:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh")
			mesh.MeshType, mesh.Parent = Enum.MeshType.Sphere, lens
			local wide, tall = math.max(lens.Size.X, lens.Size.Y), math.min(lens.Size.X, lens.Size.Y)
			lens.Size = Vector3.new(wide, tall * 0.9, h.Z * 0.05)
			local at = fit.C0.Position
			local side = at.X >= 0 and 1 or -1
			local x = side * math.max(math.abs(at.X), spread * h.X)
			local a = math.asin(math.clamp(x / (h.Z / 2), -0.95, 0.95))
			local recess = h.Z / 2 * (1 - math.cos(a))
			fit.C0 = CFrame.new(x, at.Y, -h.Z / 2 - h.Z * FRONT_TURN[piece.Name] + recess) * CFrame.Angles(0, -a, 0) * CFrame.Angles(0, 0, side * 0.22)
			lens.CFrame = head.CFrame * fit.C0
		elseif piece.Name == "MouthLine" then
			-- The mouth is drawn on the wrapped chin, in front of it.
			local at = fit.C0.Position
			fit.C0 = CFrame.new(at.X, at.Y, -h.Z * (0.5 + FRONT_WRAP.ChinGuard) - piece.Size.Z / 2)
			piece.CFrame = head.CFrame * fit.C0
		end
	end
end

-- Finish the entire roster from its authored costume. Undersuits follow the
-- armour above them, rather than exposing unrelated bright balls at joints.
-- No extra BaseParts: portraits and a crowded match share this same budget.
local function finishHeroCostume(f)
	local rounded = {"HelmetShell", "ChestArmor", "ChestPlate", "Breastplate", "Bracer", "Gauntlet", "ShinGuard", "ThighPlate", "Boot", "HeavyBoot", "ShoulderGuard", "ShoulderPad", "BeltBuckle"}
	local roundSet = {}; for _, name in ipairs(rounded) do roundSet[name] = true end
	local cover, seen = {}, {}
	local chestFront=-f.sizes.chest.Z/2
	for _, piece in ipairs(f.model:GetChildren()) do
		if not piece:IsA("BasePart") then continue end
		local fit = piece:FindFirstChild("Fit")
		if not fit then continue end
		local host = fit.Part0
		-- Remove accidentally repeated costume plates at the exact same pose.
		local signature = host.Name .. piece.Name .. tostring(fit.C0) .. tostring(piece.Size)
		if seen[signature] then piece:Destroy(); continue end
		seen[signature] = true
		if roundSet[piece.Name] and piece:IsA("Part") and piece.Shape == Enum.PartType.Block and not piece:FindFirstChildOfClass("SpecialMesh") then
			local bevel = Instance.new("SpecialMesh")
			bevel.Name, bevel.MeshType, bevel.Parent = "CostumeContour", roundedMeshType(piece.Size), piece
		end
		if piece.Material ~= NEON and not string.find(piece.Name,"Cape") and not string.find(piece.Name,"Hair") then
			local ratio = Vector3.new(piece.Size.X/host.Size.X,piece.Size.Y/host.Size.Y,piece.Size.Z/host.Size.Z)
			local volume = ratio.X * ratio.Y * ratio.Z
			local chestPlate=host.Name=="UpperTorso" and fit.C0.Position.Z < -host.Size.Z*0.3 and ratio.X>0.55 and ratio.Y>0.4 and ratio.Z<0.5
			if chestPlate then
				-- Flat costume panels follow the tapered torso silhouette instead
				-- of forming a square bib with a differently coloured frame.
				cover[host]={volume=2,color=piece.Color}
				chestFront=math.min(chestFront,fit.C0.Position.Z-piece.Size.Z/2)
				if piece:IsA("Part") and piece.Shape==Enum.PartType.Block then
					local bevel=piece:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh")
					-- A breastplate with rounded edges that fills the chest (the Head
					-- mesh shrank it to a rod down the middle).
					bevel.Name,bevel.MeshType,bevel.Parent="CostumeContour",Enum.MeshType.Torso,piece
				end
			end
			if ratio.X <= 1.5 and ratio.Y <= 1.3 and ratio.Z <= 1.5 and volume > 0.5 and (not cover[host] or volume > cover[host].volume) and not piece:GetAttribute("OpenFace") then
				cover[host] = {volume=volume, color=piece.Color}
			end
			if ratio.X<=1.5 and ratio.Y<=1.3 and ratio.Z<=1.5 and volume>0.35 and piece:IsA("Part") and piece.Shape==Enum.PartType.Block and not piece:FindFirstChildOfClass("SpecialMesh") then
				local bevel=Instance.new("SpecialMesh")
				bevel.Name,bevel.MeshType,bevel.Parent="CostumeContour",roundedMeshType(piece.Size),piece
			end
			local contour=piece:FindFirstChild("CostumeContour")
			-- Sleeves, cuffs and guards are round like the limbs under them (16/10:
			-- square cuffs on round limbs read as a robot's joints) when they are
			-- round across; a flat guard keeps rounded edges.
			if contour and (string.find(host.Name,"Arm") or string.find(host.Name,"Leg")) then contour.MeshType=roundedMeshType(piece.Size) end
		end
		-- Secondary luminous piping should read as enamel; eyes and power
		-- sources keep their glow and their individual colour signatures.
		if piece.Material == NEON and (string.find(piece.Name,"Trim") or string.find(piece.Name,"Sole") or string.find(piece.Name,"Knee") or string.find(piece.Name,"Line")) then
			piece.Material, piece.Reflectance = METAL, 0.04
		end
	end
	for name, body in pairs(f.parts) do
		if name == "HumanoidRootPart" then continue end
		if cover[body] then body.Color = cover[body].color:Lerp(FIGURE_INK,0.18) end
		local contour = body:FindFirstChild("BodyContour")
		if contour and (string.find(name,"Arm") or string.find(name,"Leg")) then
			-- Rounded vinyl-toy limbs (16/10, checked in Studio): each segment runs
			-- 16% past its joint, so the round ends overlap and no gap opens when a
			-- limb bends. Plated suits keep straight sleeves (Figure.Hero).
			contour.MeshType = Enum.MeshType.Head
			contour.Scale = Vector3.new(1,1.16,1)
		end
		-- Flat matte cloth stays legible in small portraits; the repeating
		-- fabric texture otherwise overwhelms seams and costume colours.
		if body.Material == Enum.Material.Fabric then
			body.Material = Enum.Material.SmoothPlastic
		end
		body.Reflectance = math.min(body.Reflectance or 0,0.06)
	end
	for _,piece in ipairs(f.model:GetChildren()) do
		local fit=piece:IsA("BasePart") and piece:FindFirstChild("Fit")
		if fit and fit.Part0==f.parts.UpperTorso and fit.C0.Position.Z < -f.sizes.chest.Z*0.35 then
			local accent=string.find(piece.Name,"Core") or string.find(piece.Name,"Reactor") or string.find(piece.Name,"Line") or string.find(piece.Name,"Emblem") or string.find(piece.Name,"Mark") or string.find(piece.Name,"Gem")
			if accent and fit.C0.Position.Z>chestFront-0.08*f.scale then
				fit.C0=fit.C0+Vector3.new(0,0,chestFront-0.08*f.scale-fit.C0.Position.Z)
				piece.CFrame=fit.Part0.CFrame*fit.C0
			end
		end
	end
	f.model:SetAttribute("CostumeFinish","tailored")
end

function Figure.Hero(parent, heroId, hero, scale)
	local look = HERO_LOOK[heroId] or { colors = { chest = rgb(hero.color) } }
	local spec = table.clone(look.body or {})
	spec.scale = (spec.scale or 1) * (scale or 1)
	-- A hero's head is a touch bigger than a stranger's: a friendlier figure
	-- whose face reads in a small portrait (owner, 15/10). The body gives back
	-- what the head gained, so a hero stands as tall as before (a boss is twice it).
	spec.head = (spec.head or 1) * 1.2
	spec.scale = spec.scale * 0.955
	-- Chunky armoured-toy proportions (owner, 16/10, with a picture: "não vai
	-- deixar meus heróis palito"): limbs about 40% thicker, the slender and the
	-- brawny closer together, big fists and boots and a deeper chest. Lengths
	-- stay, so every pose, pedestal and portrait frame still fits.
	local function toward(value, amount) return 1 + ((value or 1) - 1) * amount end
	spec.depth = toward(spec.depth or spec.width, 0.5) * 1.12
	spec.width = toward(spec.width, 0.5)
	spec.chest = (spec.chest or 1) * 1.16
	-- A planted stance: a gap between the thighs and between the boots.
	spec.stance = 2.3
	spec.arm = toward(spec.arm, 0.5) * 1.4
	spec.leg = toward(spec.leg, 0.5) * 1.28
	spec.hand = (spec.hand or 1) * 1.04
	-- Tall, heavy boots: the sole and ankle rise and the shins give it back.
	spec.foot = (spec.foot or 1) * 1.12
	spec.footHeight = (spec.footHeight or 1) * 1.5
	spec.legLength = (spec.legLength or 1) * 0.94
	local figure = Figure.Build(parent, spec, look.colors, look.material or Enum.Material.SmoothPlastic)
	-- The same finish applies to towers, portraits, ghosts and lobby cameos.
	-- Use existing rig parts, so the entire roster gains material separation
	-- without multiplying geometry or changing pivots and emission points.
	for name, body in pairs(figure.parts) do
		if name ~= "HumanoidRootPart" and not look.material then
			if look.shiny then
				body.Material = Enum.Material.Metal
			end
		end
	end
	figure.model:SetAttribute("HeroId", heroId)
	figure.model:SetAttribute("PoseStyle", HERO_POSE[heroId] or "shoot")
	if look.shiny then
		for _, item in ipairs(figure.model:GetChildren()) do if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then item.Reflectance = 0.06 end end
	end
	if look.hair then Figure.Hair(figure, look.hair[1], look.hair[2]) end
	if not DRAWN_FACE[heroId] then
		local faceOptions = table.clone(look.faceOptions or {})
		faceOptions.iris = faceOptions.iris or HERO_IRIS[heroId]
		-- Brows follow the hair, always darker than the skin (white hair gets grey brows).
		local hair = look.hair and look.hair[1]
		local browTone = hair and hair:Lerp(FIGURE_INK, math.max(hair.R, hair.G, hair.B) > 0.55 and 0.62 or 0.35)
		faceOptions.brow = faceOptions.brow or browTone
		faceOptions.lashes = faceOptions.lashes or HERO_LASHES[heroId]
		Figure.HeroFace(figure, look.face or "smile", faceOptions)
	end
	local extras = HERO_EXTRAS[heroId]
	if extras then extras(figure) end
	if DRAWN_FACE[heroId] then wrapMaskedFace(figure) end
	-- An open face (owner, 15/10: refine the faces): a hero with drawn eyes is
	-- never a coloured head (a red or green face read as the hero's skin). A
	-- hood, cowl, mask or helmet that wrapped the whole head goes when the hero
	-- has hair (the hair is the head's outline); on a hairless hero it becomes a
	-- cowl over the crown and the nape around a face of the hero's own skin. It
	-- no longer tints the head. Coloured-skin heroes keep their shell.
	if figure.model:FindFirstChild("Sclera") and not COLOURED_SKIN[heroId] then
		local head = figure.parts.Head
		for _, piece in ipairs(figure.model:GetChildren()) do
			local fit = piece:IsA("BasePart") and piece:FindFirstChild("Fit")
			if fit and fit.Part0 == head and HEAD_SHELLS[piece.Name] then
				if figure.model:FindFirstChild("Hair") then
					-- Under hair the shell only peeked out behind the ears as a
					-- patch of colour: the hair is the head's outline, the shell goes.
					head.Color = look.colors and look.colors.skin or HERO_SKIN
					piece:Destroy()
					continue
				else
					-- No hair: the cowl takes its place over the crown, the same tilted
					-- cap, and a second shell covers the back of the head to the neck.
					local h = head.Size
					local nape = figure.add("Head", "CowlNape", Vector3.new(h.X * 1.03, h.Y * 0.98, h.Z * 0.94), CFrame.new(0, -h.Y * 0.02, h.Z * 0.15), piece.Color, piece.Material, "head")
					nape:SetAttribute("OpenFace", true)
					piece.Size = Vector3.new(h.X * 1.16, h.Y * 0.8, h.Z * 1.24)
					fit.C0 = CFrame.new(0, h.Y * 0.26, h.Z * 0.08) * CFrame.Angles(0.25, 0, 0)
					local mesh = piece:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh")
					mesh.MeshType, mesh.Parent = Enum.MeshType.Sphere, piece
				end
				piece.CFrame = head.CFrame * fit.C0
				piece:SetAttribute("OpenFace", true)
				head.Color = look.colors and look.colors.skin or HERO_SKIN
			end
		end
	end
	-- Bands across the eyes (a domino mask, a goggle strap, a glowing visor)
	-- sit behind them: the eyes come forward through the band, so a mask frames
	-- the eyes instead of hiding them. A drawn face keeps its chin and mouth
	-- free: a hood's chin plate covered the smile like a gag.
	if not DRAWN_FACE[heroId] then
		local head = figure.parts.Head
		local drawn = figure.model:FindFirstChild("Sclera") ~= nil
		local solidFront, banded
		for _, piece in ipairs(figure.model:GetChildren()) do
			local fit = piece:IsA("BasePart") and piece:FindFirstChild("Fit")
			if not (fit and fit.Part0 == head) then continue end
			if drawn and (piece.Name == "ChinGuard" or piece.Name == "ChinStrap" or piece.Name == "EyeLens"
				or (EYE_BANDS[piece.Name] and (OPEN_LEAGUE[heroId] or banded))) then
				-- Leftovers of a full mask (lenses, chin plates), a second band, and the
				-- visors of the league, whose faces are open.
				piece:Destroy()
			elseif EYE_BANDS[piece.Name] then
				if drawn then
					-- A band across drawn eyes is a mask tied round the head at eye
					-- level: it follows the round of the head (a flat bar stood out past
					-- the cheeks) and the eyes come forward through it, without glow.
					piece.Size = Vector3.new(head.Size.X * 1.06, head.Size.Y * 0.26, head.Size.Z * 1.06)
					if piece.Material == Enum.Material.Neon then piece.Material = Enum.Material.SmoothPlastic end
					piece.Transparency = 0
					local mesh = piece:FindFirstChildOfClass("SpecialMesh") or Instance.new("SpecialMesh")
					mesh.MeshType, mesh.Parent = Enum.MeshType.Head, piece
					fit.C0 = CFrame.new(0, head.Size.Y * 0.05, 0)
					piece.CFrame = head.CFrame * fit.C0
					banded = true
				end
				local z = (head.CFrame:Inverse() * piece.CFrame).Position.Z - piece.Size.Z / 2
				solidFront = math.min(solidFront or z, z)
			end
		end
		if banded then
			for _, piece in ipairs(figure.model:GetChildren()) do
				if piece.Name == "Blush" then piece:Destroy() end
			end
		end
		local sclera = figure.model:FindFirstChild("Sclera")
		if solidFront and sclera then
			local shift = (head.CFrame:Inverse() * sclera.CFrame).Position.Z - sclera.Size.Z / 2 - solidFront + 0.012
			if shift > 0 then
				for _, piece in ipairs(figure.model:GetChildren()) do
					if EYE_PIECES[piece.Name] and piece:IsA("BasePart") then
						piece.CFrame = head.CFrame * CFrame.new(0, 0, -shift) * (head.CFrame:Inverse() * piece.CFrame)
						local fit = piece:FindFirstChild("Fit")
						if fit then fit.C0 = head.CFrame:Inverse() * piece.CFrame end
					end
				end
			end
		end
	end
	-- A face drawn over a full mask does not blush.
	local masked = false
	for _, piece in ipairs(figure.model:GetChildren()) do
		local fit = piece:IsA("BasePart") and piece:FindFirstChild("Fit")
		if fit and fit.Part0 == figure.parts.Head and (piece.Name == "MaskBase" or piece.Name == "MaskShell" or piece.Name == "WarMask") and not piece:GetAttribute("OpenFace") then masked = true; break end
	end
	if masked then
		for _, piece in ipairs(figure.model:GetChildren()) do
			if piece.Name == "Blush" then piece:Destroy() end
		end
	end
	Figure.Finish(figure, true)
	finishHeroCostume(figure)
	sculptTorso(figure)
	polishHero(figure, look.colors and look.colors.skin or HERO_SKIN, look.matte)
	if look.suit then
		-- Plated suits (look.suit is the suit colour) need continuous solid
		-- sleeves and a full waist. A tapered torso mesh on each limb left
		-- notches and visible hips in the base colour.
		local suit = look.suit
		figure.parts.LowerTorso.Color = suit:Lerp(FIGURE_INK,0.18)
		local hips = figure.parts.LowerTorso:FindFirstChild("BodyContour")
		hips.MeshType, hips.Scale = Enum.MeshType.Brick, Vector3.one
		for _, piece in ipairs(figure.model:GetChildren()) do
			local fit = piece:IsA("BasePart") and piece:FindFirstChild("Fit")
			local host = fit and fit.Part0 or piece
			if string.find(host.Name,"Arm") or string.find(host.Name,"Leg") then
				local contour = piece:FindFirstChild("BodyContour") or piece:FindFirstChild("CostumeContour")
				if contour then contour.MeshType = Enum.MeshType.Brick end
			end
		end
	end
	-- The hero's own colour (the catalogue's), bright and saturated, for the
	-- armour's glowing trims; HERO_GLOW overrides it where the costume asks.
	local tone = HERO_GLOW[heroId] or (hero and hero.color and Color3.fromRGB(hero.color[1], hero.color[2], hero.color[3]))
	if tone then
		-- Stretched so the strongest channel is full and the weakest drops: a
		-- saturated glow, never a pale one (a near-grey colour gets cyan).
		local high, low = math.max(tone.R, tone.G, tone.B), math.min(tone.R, tone.G, tone.B)
		if high - low < 0.15 then
			figure.glow = Color3.fromRGB(80, 210, 255)
		else
			local function vivid(x) return math.clamp((x - low) / (high - low) * 0.85 + 0.15 * x / high, 0, 1) end
			figure.glow = Color3.new(vivid(tone.R), vivid(tone.G), vivid(tone.B))
		end
	end
	armourHero(figure, look)
	-- Every hero's glowing power pieces come alive (the client pulses or
	-- flickers them): fists, blasters, rings, blades, flames, prongs, visors.
	for _, piece in ipairs(figure.model:GetDescendants()) do
		local living = piece:IsA("BasePart") and piece.Material == NEON and LIVING_POWERS[piece.Name]
		if living and not piece:GetAttribute("FxPulse") and not piece:GetAttribute("FxFlicker") then
			piece:SetAttribute(living == "flicker" and "FxFlicker" or "FxPulse", living == "flicker" and 0.12 or 0.3)
		end
	end
	if HERO_SIGNATURE[heroId] then
		HERO_SIGNATURE[heroId](figure)
	elseif figure.glow and not look.matte then
		-- Every other armoured hero: glowing seams down the gauntlets and
		-- greaves in its own colour, like the pictures' armour.
		seams(figure, figure.glow, true)
	end
	if not figure.model:FindFirstChild("Muzzle", true) then muzzle(figure, "RightHand", Vector3.new(0, -figure.sizes.hand.Y / 2 - 0.1 * figure.scale, 0)) end
	paintArmour(figure)
	filigree(figure, heroId)
	return figure
end

-- The agency's staff: the same jointed human the heroes are, in a dark suit,
-- white shirt and tie, dark glasses, an earpiece with its wire. They stand
-- still as scenery but breathe and glance about (the client animates every
-- figure tagged IdleFigure; `guard` folds their hands in front of them).
local AGENT_SKIN = { Color3.fromRGB(232, 181, 147), Color3.fromRGB(141, 92, 64), Color3.fromRGB(198, 146, 108), Color3.fromRGB(96, 64, 46) }
local AGENT_HAIR = { Color3.fromRGB(38, 30, 28), Color3.fromRGB(96, 64, 40), Color3.fromRGB(20, 20, 24), Color3.fromRGB(150, 110, 60) }
function Figure.Agent(parent, index)
	local suit, white, navy = Color3.fromRGB(26, 28, 36), Color3.fromRGB(240, 242, 246), Color3.fromRGB(28, 38, 84)
	local skin = AGENT_SKIN[(index - 1) % #AGENT_SKIN + 1]
	local figure = Figure.Build(parent, { scale = 1.02, width = 1.04 }, {
		skin = skin, head = skin, chest = suit, pelvis = suit, upperArm = suit, lowerArm = suit, hand = skin,
		upperLeg = suit, lowerLeg = suit, foot = Color3.fromRGB(14, 14, 18),
	})
	figure.model.Name = "Agent"
	local f, c, h, s = figure, figure.sizes.chest, figure.parts.Head.Size, figure.scale
	f.add("UpperTorso", "Shirt", Vector3.new(c.X * 0.3, c.Y * 0.78, 0.06 * s), CFrame.new(0, c.Y * 0.08, -c.Z / 2 - 0.03 * s), white, FABRIC)
	f.add("UpperTorso", "Tie", Vector3.new(0.2 * s, c.Y * 0.62, 0.08 * s), CFrame.new(0, c.Y * 0.02, -c.Z / 2 - 0.07 * s), navy, FABRIC)
	f.add("UpperTorso", "TieKnot", Vector3.new(0.26, 0.2, 0.1) * s, CFrame.new(0, c.Y * 0.4, -c.Z / 2 - 0.08 * s), navy, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "Lapel", Vector3.new(0.34 * s, c.Y * 0.84, 0.1 * s), CFrame.new(side * c.X * 0.26, c.Y * 0.04, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, side * 0.16), Color3.fromRGB(14, 16, 22), FABRIC)
	end
	f.add("LowerTorso", "Belt", Vector3.new(f.sizes.pelvis.X * 1.04, f.sizes.pelvis.Y * 0.4, f.sizes.pelvis.Z * 1.06), CFrame.new(0, f.sizes.pelvis.Y * 0.28, 0), Color3.fromRGB(10, 10, 14), FABRIC)
	Figure.Hair(f, AGENT_HAIR[(index * 3 - 1) % #AGENT_HAIR + 1])
	-- Dark glasses and a firm mouth.
	Figure.Face(f, "lens", { lens = Color3.fromRGB(10, 12, 18), rim = Color3.fromRGB(10, 12, 18), width = 0.38, height = 0.2, slant = 0.06 })
	f.add("Head", "Mouth", Vector3.new(0.3, 0.06, 0.05) * s, f.face(0, -0.5, 0.0), Color3.fromRGB(70, 40, 40), FABRIC)
	-- The earpiece and its wire running down into the collar.
	f.add("Head", "Earpiece", Vector3.new(0.18, 0.26, 0.2) * s, CFrame.new(-h.X / 2 - 0.05 * s, -h.Y * 0.04, 0.1 * s), Color3.fromRGB(20, 20, 24), METAL, "ball")
	f.rod("Head", "EarWire", Vector3.new(-h.X / 2 - 0.08 * s, -h.Y * 0.14, 0.12 * s), Vector3.new(-h.X * 0.4, -h.Y * 0.68, 0.3 * s), 0.05 * s, Color3.fromRGB(150, 150, 160), METAL)
	f.model:SetAttribute("IdleFigure", true)
	f.model:SetAttribute("IdleGuard", true)
	f.model:SetAttribute("IdlePhase", index * 1.7)
	return f
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
	saboteur = { gait = "stalk", body = { scale = 0.82, width = 0.88, arm = 0.92, leg = 0.92 }, skin = Color3.fromRGB(150, 176, 198) },
	splitter = { gait = "shamble", body = { scale = 0.86, width = 1.32, depth = 1.2, chest = 1.3, head = 0.82, arm = 0.92, leg = 0.92, legLength = 0.84 }, skin = Color3.fromRGB(112, 196, 150) },
	splitling = { gait = "sprint", body = { scale = 0.5, width = 0.96 }, skin = Color3.fromRGB(150, 226, 184) },
	illusion = { gait = "glide", body = { scale = 2.0, width = 0.92, arm = 0.9 }, skin = Color3.fromRGB(226, 206, 184) },
	-- Bosses tower over the defence: about twice to two and a half times a
	-- hero tower, so a boss reads as the threat of the wave from any camera.
	lizard = { gait = "reptile", body = { scale = 2.48, width = 1.16, depth = 1.1, head = 1.02, arm = 1.12, hand = 1.3, leg = 1.2, legLength = 0.9 }, skin = Color3.fromRGB(206, 128, 50) },
	abomination = { gait = "stomp", body = { scale = 2.75, width = 1.46, depth = 1.3, chest = 1.3, head = 0.78, arm = 1.7, hand = 1.4, leg = 1.45, legLength = 0.84 }, skin = Color3.fromRGB(104, 98, 124) },
	redskull = { gait = "march", body = { scale = 2.32, width = 1.04 }, skin = Color3.fromRGB(52, 50, 56) },
	killmonger = { gait = "stalk", body = { scale = 2.32, width = 1.08, arm = 1.06 }, skin = Color3.fromRGB(96, 64, 46) },
	doom = { gait = "regal", body = { scale = 2.48, width = 1.14, arm = 1.1, leg = 1.08 }, skin = Color3.fromRGB(126, 96, 62) },
	loki = { gait = "glide", body = { scale = 2.32, width = 0.92, arm = 0.9 }, skin = Color3.fromRGB(226, 206, 184) },
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
	-- Two crooked brows (one higher than the other) and a snaggle tooth: a
	-- goofy grump, not a blank bar (owner, 16/10: refine the villains).
	local brow = f.parts.Head.Color:Lerp(EC.ink, 0.45)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Brow", Vector3.new(0.42, 0.13, 0.12) * k, f.face(side * 0.28, side < 0 and 0.44 or 0.38, -0.02) * CFrame.Angles(0, 0, side * (side < 0 and 0.32 or 0.18)), brow, FABRIC)
	end
	f.add("Head", "Jaw", Vector3.new(0.46, 0.2, 0.06) * k, f.face(0.04, -0.42, 0.0), EC.ink, FABRIC, "ball")
	f.add("Head", "Tooth", Vector3.new(0.1, 0.09, 0.05) * k, f.face(-0.08, -0.36, 0.02), EC.bone, FABRIC)
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
	-- The Shadow Foundry's workers, in their commander's soot and molten orange.
	hydra = function(f)
		local h = f.parts.Head.Size
		f.add("Head", "Helmet", h * Vector3.new(1.1, 0.62, 1.1), CFrame.new(0, h.Y * 0.3, 0), Color3.fromRGB(46, 44, 50), FABRIC, "ball")
		f.add("UpperTorso", "FoundryBadge", Vector3.new(0.36, 0.36, 0.05) * f.scale, CFrame.new(0, f.sizes.chest.Y * 0.2, -f.sizes.chest.Z / 2 - 0.03 * f.scale), Color3.fromRGB(255, 150, 50), NEON, "ball")
	end,
	vibranium = function(f)
		local h = f.parts.Head.Size
		f.add("Head", "Helmet", h * Vector3.new(1.1, 0.6, 1.1), CFrame.new(0, h.Y * 0.3, 0), Color3.fromRGB(96, 62, 140), METAL, "ball")
		f.add("UpperTorso", "VibraniumTrace", Vector3.new(0.12, f.sizes.chest.Y * 0.8, 0.05) * Vector3.new(f.scale, 1, f.scale), CFrame.new(0, 0, -f.sizes.chest.Z / 2 - 0.03 * f.scale), Color3.fromRGB(200, 150, 255), NEON)
	end,
	doombot = function(f)
		-- A robot of the Iron Tyrant's guard, in his bronze and midnight blue: the
		-- face becomes a faceplate with one cyan visor and a crest.
		for _, item in ipairs(f.model:GetChildren()) do
			if item:IsA("BasePart") and (item.Name == "Socket" or item.Name == "Eye" or item.Name == "Jaw" or item.Name == "Tooth" or item.Name == "Brow" or item.Name == "Hair") then item:Destroy() end
		end
		for _, item in ipairs(f.model:GetChildren()) do
			if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then item.Color, item.Reflectance = Color3.fromRGB(126, 96, 62), 0.12; item:SetAttribute("Tint", nil) end
		end
		-- Added after the bronze wash so they keep their own colours.
		f.add("Head", "Visor", Vector3.new(0.62, 0.09, 0.05) * f.scale, f.face(0, 0.14, 0.03), Color3.fromRGB(80, 210, 255), NEON)
		for i = -1, 1 do f.add("Head", "VentBar", Vector3.new(0.05, 0.26, 0.05) * f.scale, f.face(i * 0.12, -0.42, 0.03), EC.ink, METAL) end
		local h = f.parts.Head.Size
		f.add("Head", "Crest", Vector3.new(0.14 * f.scale, h.Y * 0.36, h.Z * 0.9), CFrame.new(0, h.Y * 0.56, 0), Color3.fromRGB(214, 172, 72), METAL, "wedge")
		f.add("UpperTorso", "Tunic", f.sizes.chest * Vector3.new(1.04, 0.7, 1.06), CFrame.new(0, -f.sizes.chest.Y * 0.16, 0), Color3.fromRGB(28, 36, 74), FABRIC)
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
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "Pauldron", f.sizes.upperArm * Vector3.new(1.5, 0.6, 1.36), CFrame.new(0, f.sizes.upperArm.Y * 0.32, 0) * CFrame.Angles(0, side < 0 and math.pi or 0, side * -0.1), EC.metal, METAL, "wedge")
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
-- The saboteur: goggles, a humming coil on its back and live electrodes in
-- both fists, so the danger is readable from the road.
ENEMY_EXTRAS.saboteur = function(f)
	clothes(f, true)
	-- One uniform dark-blue jacket (not the random shirt) so the family reads on the road.
	for _, name in ipairs({ "UpperTorso", "LeftUpperArm", "RightUpperArm" }) do
		f.parts[name]:SetAttribute("Tint", nil)
		f.parts[name].Color = Color3.fromRGB(34, 46, 92)
	end
	infectedFace(f, Color3.fromRGB(150, 225, 255))
	local c, s = f.sizes.chest, f.scale
	local volt = Color3.fromRGB(110, 210, 255)
	f.add("Head", "Goggles", f.parts.Head.Size * Vector3.new(0.9, 0.24, 0.12), f.face(0, 0.14, 0.03), volt, NEON)
	f.add("UpperTorso", "Pack", Vector3.new(c.X * 0.7, c.Y * 0.8, 0.6 * s), CFrame.new(0, 0, c.Z / 2 + 0.3 * s), Color3.fromRGB(64, 74, 88), METAL)
	f.add("UpperTorso", "Coil", Vector3.new(0.5, 0.5, 0.5) * s, CFrame.new(0, c.Y * 0.1, c.Z / 2 + 0.75 * s), volt, NEON, "ball")
	f.add("UpperTorso", "CoilRod", Vector3.new(0.1, 1.2, 0.1) * s, CFrame.new(0, c.Y * 0.1 + 0.9 * s, c.Z / 2 + 0.75 * s), Color3.fromRGB(190, 200, 210), METAL)
	for _, name in ipairs({ "LeftHand", "RightHand" }) do
		f.add(name, "Electrode", Vector3.new(0.62, 0.62, 0.62) * s, CFrame.new(0, -0.3 * s, -0.1 * s), volt, NEON, "ball")
	end
	-- A lightning bolt across the chest, readable from the front.
	local z = -c.Z / 2 - 0.05 * s
	local bolt = { Vector3.new(0.22, 0.34, z), Vector3.new(-0.12, 0.04, z), Vector3.new(0.12, -0.04, z), Vector3.new(-0.22, -0.34, z) }
	for index = 1, 3 do
		local a, b = bolt[index], bolt[index + 1]
		f.rod("UpperTorso", "Bolt", Vector3.new(a.X * c.X, a.Y * c.Y, a.Z), Vector3.new(b.X * c.X, b.Y * c.Y, b.Z), 0.16 * s, volt, NEON)
	end
end
-- The splitter carries its two fragments inside a swollen sac: two glowing
-- cores behind a seam down the middle, so the split is no surprise.
ENEMY_EXTRAS.splitter = function(f)
	infectedFace(f, Color3.fromRGB(196, 255, 150))
	local c, s = f.sizes.chest, f.scale
	local slime = Color3.fromRGB(130, 232, 170)
	-- No shirt: the whole body is the same wet green, so the sac is the focus.
	for _, name in ipairs({ "UpperTorso", "LeftUpperArm", "RightUpperArm" }) do f.parts[name].Color = Color3.fromRGB(86, 172, 138) end
	for _, name in ipairs({ "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }) do f.parts[name].Color = Color3.fromRGB(54, 108, 100) end
	local sac = f.add("UpperTorso", "Sac", c * Vector3.new(1.02, 0.92, 0.72), CFrame.new(0, -c.Y * 0.02, -c.Z / 2 - 0.12 * s), slime, FABRIC, "ball")
	sac.Transparency = 0.3
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "Core", Vector3.new(0.5, 0.5, 0.5) * s, CFrame.new(side * c.X * 0.2, -c.Y * 0.02, -c.Z / 2 - 0.22 * s), Color3.fromRGB(204, 255, 150), NEON, "ball")
	end
	f.add("UpperTorso", "Seam", Vector3.new(0.07 * s, c.Y * 0.8, 0.06 * s), CFrame.new(0, -c.Y * 0.02, -c.Z / 2 - 0.5 * s), EC.ink, FABRIC)
	f.add("Head", "Drip", Vector3.new(0.3, 0.46, 0.3) * s, CFrame.new(-f.parts.Head.Size.X * 0.34, f.parts.Head.Size.Y * 0.5, 0), slime, FABRIC, "ball")
end
ENEMY_EXTRAS.splitling = function(f)
	infectedFace(f, Color3.fromRGB(196, 255, 150))
	local c, s = f.sizes.chest, f.scale
	for _, name in ipairs({ "UpperTorso", "LeftUpperArm", "RightUpperArm" }) do f.parts[name].Color = Color3.fromRGB(112, 202, 162) end
	for _, name in ipairs({ "LowerTorso", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }) do f.parts[name].Color = Color3.fromRGB(70, 130, 118) end
	f.add("UpperTorso", "Core", Vector3.new(0.7, 0.7, 0.5) * s, CFrame.new(0, 0, -c.Z / 2 - 0.1 * s), Color3.fromRGB(204, 255, 150), NEON, "ball")
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
-- silhouette instead of reading as a scaled-up infected. Each is the warlord
-- the infection raised on its map, original in palette, emblem and signature
-- item (IP_POLICY: never a known villain's combination; world_boot checks):
--   Gekko Colosso (Manhattan): an amber sewer gecko with a teal frill and
--     throat, a work harness and a manhole cover for a pauldron.
--   Megabruto (Gamma Complex): a slate-violet brute split by glowing orange
--     cracks, reactor canisters on its back and a broken restraint collar.
--   Comandante Sombra (Shadow Foundry): a foundry master in a soot-black helm
--     with one molten visor, a bronze-plated apron and a forge hammer.
--   Rei Saqueador (Crystal Jungle): a raider king behind a bone war mask,
--     crowned and armoured in violet crystal, with a crystal spear.
--   Tirano de Ferro (Tyrant's Citadel): bronze armour and midnight cloth, a
--     spiked crown over a faceplate with one cyan visor, and an orb scepter.
--   Mestre das Ilusões (Sky Bridge): midnight violet and silver, white hair, a
--     halo of floating mirror shards and a magenta prism staff.
local CRYSTAL = Enum.Material.Glass
ENEMY_EXTRAS.lizard = function(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	local hide = f.parts.Head.Color
	local spot, teal, frill, strap, iron = Color3.fromRGB(112, 62, 28), Color3.fromRGB(70, 222, 200), Color3.fromRGB(36, 150, 140), Color3.fromRGB(52, 44, 40), Color3.fromRGB(80, 86, 96)
	f.parts.UpperTorso.Color = hide
	for _, name in ipairs({ "LowerTorso", "LeftUpperLeg", "RightUpperLeg" }) do f.parts[name].Color = Color3.fromRGB(64, 68, 78) end
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg" }) do f.parts[name].Color = hide end
	-- A long snout with teeth, teal slit-pupil eyes and a glowing throat sac.
	f.add("Head", "Snout", Vector3.new(h.X * 0.7, h.Y * 0.44, h.Z * 0.7), CFrame.new(0, -h.Y * 0.18, -h.Z * 0.56), hide, FABRIC, "head")
	f.add("Head", "Teeth", Vector3.new(h.X * 0.64, 0.1 * s, h.Z * 0.5), CFrame.new(0, -h.Y * 0.4, -h.Z * 0.6), EC.bone, FABRIC)
	f.add("Head", "ThroatSac", Vector3.new(h.X * 0.46, h.Y * 0.3, h.Z * 0.36), CFrame.new(0, -h.Y * 0.46, -h.Z * 0.46), teal, NEON, "ball")
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Eye", Vector3.new(0.3, 0.26, 0.06) * s, f.face(side * 0.32, 0.22, 0.0), teal, NEON, "ball")
		f.add("Head", "Pupil", Vector3.new(0.06, 0.22, 0.05) * s, f.face(side * 0.32, 0.22, 0.03), EC.ink, FABRIC)
		local arm = side < 0 and "LeftUpperArm" or "RightUpperArm"
		f.add(arm, "Spot", f.sizes.upperArm * Vector3.new(0.46, 0.28, 0.5), CFrame.new(side * f.sizes.upperArm.X * 0.3, f.sizes.upperArm.Y * 0.08, -f.sizes.upperArm.Z * 0.1), spot, FABRIC, "ball")
		f.add("UpperTorso", "Spot", Vector3.new(0.5, 0.36, 0.3) * s, CFrame.new(side * c.X * 0.34, -c.Y * 0.24, -c.Z / 2 + 0.08 * s), spot, FABRIC, "ball")
		for i = -1, 1 do f.add(side < 0 and "LeftHand" or "RightHand", "Claw", Vector3.new(0.08, 0.3, 0.08) * s, CFrame.new(i * 0.16 * s, -f.sizes.hand.Y / 2 - 0.1 * s, -0.1 * s), EC.bone, FABRIC) end
		-- A work harness crossing the chest.
		f.add("UpperTorso", "Harness", Vector3.new(0.24 * s, c.Y * 1.2, 0.08 * s), CFrame.new(0, 0, -c.Z / 2 - 0.04 * s) * CFrame.Angles(0, 0, side * 0.6), strap, FABRIC)
	end
	-- A manhole cover strapped to the left shoulder, facing out and forward so
	-- its round face and grid read from the front and the side.
	local coverAt = Vector3.new(-f.sizes.upperArm.X * 0.42, f.sizes.upperArm.Y * 0.36, -f.sizes.upperArm.Z * 0.1)
	local cover = CFrame.lookAt(coverAt, coverAt + Vector3.new(-1, 0.5, -0.55))
	local coverSize = f.sizes.upperArm.X * 1.9
	f.disc("LeftUpperArm", "ManholeCover", coverSize, 0.18 * s, cover, iron, METAL)
	for i = -1, 1, 2 do f.add("LeftUpperArm", "CoverGrid", Vector3.new(coverSize * 0.78, 0.07 * s, 0.05 * s), cover * CFrame.new(0, i * 0.22 * s, -0.11 * s), iron:Lerp(EC.ink, 0.45), METAL) end
	-- A teal frill down the back, and the tail swinging on four joints.
	for i = 0, 3 do f.add("UpperTorso", "Frill", Vector3.new(0.1, 0.5 - i * 0.07, 0.46) * s, CFrame.new(0, c.Y * (0.46 - i * 0.28), c.Z / 2 + 0.12 * s), frill, FABRIC, "wedge") end
	local previous, at = f.parts.LowerTorso, f.parts.LowerTorso.CFrame * CFrame.new(0, -0.1 * s, f.sizes.pelvis.Z / 2)
	for i = 1, 4 do
		local length = (1.8 - i * 0.2) * s
		local width = (0.8 - i * 0.14) * s
		local segment = figurePart(f.model, "Tail" .. i, Vector3.new(width, width * 0.9, length), at * CFrame.Angles(i == 1 and 0.45 or 0.08, 0, 0) * CFrame.new(0, 0, length / 2), i % 2 == 0 and hide:Lerp(spot, 0.35) or hide, FABRIC)
		segment:SetAttribute("HeroVisual", true)
		f.joints["Tail" .. i] = figureJoint("Tail" .. i, previous, segment, at.Position)
		previous, at = segment, segment.CFrame * CFrame.new(0, 0, length / 2)
	end
end
ENEMY_EXTRAS.abomination = function(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	local hide = f.parts.Head.Color
	local stone, glow, iron = hide:Lerp(EC.ink, 0.35), Color3.fromRGB(255, 132, 48), Color3.fromRGB(86, 90, 100)
	infectedFace(f, glow, true)
	-- Bare hide above ragged dark shorts, split by glowing cracks.
	f.parts.UpperTorso.Color = hide
	for _, name in ipairs({ "LowerTorso", "LeftUpperLeg", "RightUpperLeg" }) do f.parts[name].Color = Color3.fromRGB(58, 52, 44) end
	for _, name in ipairs({ "LeftLowerLeg", "RightLowerLeg" }) do f.parts[name].Color = hide end
	for _, crack in ipairs({ { -0.22, 0.2, 0.5 }, { 0.2, -0.04, -0.6 }, { -0.04, -0.3, 0.3 } }) do
		f.add("UpperTorso", "Crack", Vector3.new(0.08 * s, c.Y * 0.34, 0.05 * s), CFrame.new(c.X * crack[1], c.Y * crack[2], -c.Z / 2 - 0.03 * s) * CFrame.Angles(0, 0, crack[3]), glow, NEON)
	end
	for _, side in ipairs({ -1, 1 }) do
		local arm = side < 0 and "LeftUpperArm" or "RightUpperArm"
		-- The shoulder ridge projects beyond the body even in the battle camera.
		f.add(arm, "BossShoulderSpine", Vector3.new(0.38, 0.72, 0.64) * s, CFrame.new(side * f.sizes.upperArm.X * 0.45, f.sizes.upperArm.Y * 0.4, 0) * CFrame.Angles(0, 0, -side * 0.45), stone, Enum.Material.Slate, "wedge")
		f.add(arm, "Crack", Vector3.new(0.07 * s, f.sizes.upperArm.Y * 0.5, 0.05 * s), CFrame.new(0, -f.sizes.upperArm.Y * 0.1, -f.sizes.upperArm.Z / 2 - 0.02 * s) * CFrame.Angles(0, 0, side * 0.4), glow, NEON)
		-- Two reactor canisters strapped to the back, their caps glowing.
		local back = CFrame.new(side * c.X * 0.24, c.Y * 0.04, c.Z / 2 + 0.34 * s)
		f.add("UpperTorso", "Canister", Vector3.new(c.Y * 0.78, 0.62 * s, 0.62 * s), back * CFrame.Angles(0, 0, math.pi / 2), iron, METAL, Enum.PartType.Cylinder)
		f.add("UpperTorso", "CanisterCap", Vector3.new(0.12 * s, 0.5 * s, 0.5 * s), back * CFrame.new(0, c.Y * 0.4, 0) * CFrame.Angles(0, 0, math.pi / 2), glow, NEON, Enum.PartType.Cylinder)
	end
	-- A broken restraint collar, two chain links still hanging from it.
	f.add("UpperTorso", "RestraintCollar", Vector3.new(c.X * 0.6, 0.36 * s, c.Z * 0.98), CFrame.new(0, c.Y * 0.52, 0), iron, METAL)
	for i = 1, 2 do f.add("UpperTorso", "Chain", Vector3.new(0.16, 0.3, 0.08) * s, CFrame.new(-c.X * 0.16, c.Y * 0.36 - i * 0.28 * s, -c.Z / 2 - 0.08 * s) * CFrame.Angles(0, i * 1.2, 0), iron, METAL) end
	for i = 0, 4 do f.add("UpperTorso", "Spine", Vector3.new(0.2, 0.6 - i * 0.06, 0.5) * s, CFrame.new(0, c.Y * (0.44 - i * 0.2), c.Z / 2 + 0.1 * s) * CFrame.Angles(0.4, 0, 0), stone, FABRIC, "wedge") end
end
ENEMY_EXTRAS.redskull = function(f)
	local h, c, p, s = f.parts.Head.Size, f.sizes.chest, f.sizes.pelvis, f.scale
	local soot, bronze, molten = Color3.fromRGB(46, 44, 50), Color3.fromRGB(150, 104, 58), Color3.fromRGB(255, 150, 50)
	for _, name in ipairs({ "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }) do f.parts[name].Color = soot end
	for _, name in ipairs({ "LeftHand", "RightHand", "LeftFoot", "RightFoot" }) do f.parts[name].Color = bronze:Lerp(EC.ink, 0.45) end
	-- A soot-black foundry helm: one molten visor slit, a respirator, a ridge.
	f.add("Head", "ForgeHelm", h * Vector3.new(1.08, 1.06, 1.08), CFrame.new(0, 0.02 * s, 0), soot:Lerp(EC.ink, 0.3), METAL, "head")
	f.add("Head", "Visor", Vector3.new(h.X * 0.74, 0.12 * s, 0.06 * s), f.face(0, 0.18, 0.06), molten, NEON)
	f.add("Head", "Respirator", Vector3.new(h.X * 0.46, h.Y * 0.3, 0.16 * s), f.face(0, -0.42, 0.08), bronze, METAL)
	for i = -1, 1 do f.add("Head", "RespiratorSlot", Vector3.new(0.05, 0.2, 0.04) * s, f.face(i * 0.12, -0.42, 0.18), EC.ink, METAL) end
	f.add("Head", "HelmRidge", Vector3.new(0.14 * s, h.Y * 0.3, h.Z * 0.9), CFrame.new(0, h.Y * 0.5, 0), bronze, METAL, "wedge")
	-- A bronze-plated apron with a molten seam, heavy pauldrons, apron tails.
	f.add("UpperTorso", "ApronPlate", Vector3.new(c.X * 0.7, c.Y * 0.62, 0.12 * s), CFrame.new(0, -c.Y * 0.06, -c.Z / 2 - 0.05 * s), bronze, METAL)
	f.add("UpperTorso", "Seam", Vector3.new(c.X * 0.56, 0.06 * s, 0.04 * s), CFrame.new(0, c.Y * 0.08, -c.Z / 2 - 0.12 * s), molten, NEON)
	for _, side in ipairs({ -1, 1 }) do
		local arm = side < 0 and "LeftUpperArm" or "RightUpperArm"
		f.add(arm, "Pauldron", f.sizes.upperArm * Vector3.new(1.42, 0.42, 1.3), CFrame.new(side * 0.06 * s, f.sizes.upperArm.Y * 0.42, 0), bronze, METAL)
		f.add(arm, "Rivet", Vector3.new(0.14, 0.14, 0.14) * s, CFrame.new(side * 0.06 * s, f.sizes.upperArm.Y * 0.42, -f.sizes.upperArm.Z * 0.66), molten, NEON, "ball")
		f.add(side < 0 and "LeftLowerArm" or "RightLowerArm", "Gauntlet", f.sizes.lowerArm * Vector3.new(1.16, 0.56, 1.14), CFrame.new(0, -f.sizes.lowerArm.Y * 0.16, 0), bronze, METAL)
		f.add("LowerTorso", "ApronTail", Vector3.new(p.X * 0.5, 1.8 * s, 0.14 * s), CFrame.new(side * p.X * 0.26, -0.82 * s, -p.Z / 2 - 0.02 * s), soot:Lerp(bronze, 0.25), FABRIC)
	end
	belt(f, Color3.fromRGB(70, 56, 40), bronze)
	-- The forge hammer, its striking face still glowing.
	f.rod("RightHand", "HammerHaft", Vector3.new(0, 0.3 * s, -0.1 * s), Vector3.new(0, -2.3 * s, -0.1 * s), 0.16 * s, Color3.fromRGB(72, 54, 40), FABRIC)
	f.add("RightHand", "HammerHead", Vector3.new(0.9, 0.56, 0.56) * s, CFrame.new(0, -2.45 * s, -0.1 * s), soot:Lerp(EC.ink, 0.2), METAL)
	f.add("RightHand", "HammerFace", Vector3.new(0.06, 0.48, 0.48) * s, CFrame.new(0.47 * s, -2.45 * s, -0.1 * s), molten, NEON)
end
ENEMY_EXTRAS.killmonger = function(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	local suit, bone, crystal, deep = Color3.fromRGB(42, 36, 64), Color3.fromRGB(232, 224, 206), Color3.fromRGB(176, 120, 255), Color3.fromRGB(104, 64, 178)
	for _, name in ipairs({ "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }) do f.parts[name].Color = suit end
	-- A bone war mask with crystal eyes, under a crown of crystal shards.
	f.add("Head", "WarMask", Vector3.new(h.X * 0.86, h.Y * 0.84, 0.14 * s), f.face(0, -0.04, 0.0), bone, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Eye", Vector3.new(0.3, 0.14, 0.05) * s, f.face(side * 0.26, 0.16, 0.08 * s) * CFrame.Angles(0, 0, -side * 0.2), crystal, NEON, "ball")
		f.add("Head", "MaskMark", Vector3.new(0.07 * s, h.Y * 0.42, 0.04 * s), f.face(side * 0.26, -0.24, 0.08 * s), deep, FABRIC)
	end
	for i = -2, 2 do
		local tall = 1 - math.abs(i) * 0.24
		f.add("Head", "CrystalCrown", Vector3.new(0.2 * s, h.Y * 0.62 * tall, 0.2 * s), CFrame.new(i * h.X * 0.19, h.Y * 0.5 + h.Y * 0.3 * tall, 0) * CFrame.Angles(0, math.pi / 4, i * 0.16), i == 0 and crystal or deep, CRYSTAL)
	end
	-- Crystal clusters for pauldrons, a crystal brooch, a crystal-tipped spear.
	for _, side in ipairs({ -1, 1 }) do
		local arm = side < 0 and "LeftUpperArm" or "RightUpperArm"
		for k = 0, 2 do
			f.add(arm, "CrystalPauldron", Vector3.new(0.24, 0.62 - k * 0.12, 0.24) * s, CFrame.new(side * (0.08 + k * 0.18) * s, f.sizes.upperArm.Y * 0.44 + (0.24 - k * 0.06) * s, (k - 1) * 0.16 * s) * CFrame.Angles(0, math.pi / 4, -side * (0.25 + k * 0.2)), k == 0 and crystal or deep, CRYSTAL)
		end
	end
	f.add("UpperTorso", "Brooch", Vector3.new(0.3, 0.42, 0.12) * s, CFrame.new(0, c.Y * 0.24, -c.Z / 2 - 0.06 * s) * CFrame.Angles(0, 0, math.pi / 4), crystal, NEON)
	belt(f, Color3.fromRGB(70, 52, 40), bone)
	f.rod("RightHand", "SpearShaft", Vector3.new(0, 1.4 * s, -0.3 * s), Vector3.new(0, -2.2 * s, -0.3 * s), 0.12 * s, Color3.fromRGB(70, 52, 40), FABRIC)
	f.add("RightHand", "SpearTip", Vector3.new(0.3, 0.8, 0.3) * s, CFrame.new(0, 1.8 * s, -0.3 * s) * CFrame.Angles(0, math.pi / 4, 0), crystal, CRYSTAL)
end
ENEMY_EXTRAS.doom = function(f)
	local h, c, p, s = f.parts.Head.Size, f.sizes.chest, f.sizes.pelvis, f.scale
	local cloth, gold, armor, cyan = Color3.fromRGB(28, 36, 74), Color3.fromRGB(214, 172, 72), Color3.fromRGB(126, 96, 62), Color3.fromRGB(80, 210, 255)
	for _, item in ipairs(f.model:GetChildren()) do if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" then item.Color, item.Reflectance = armor, 0.14 end end
	f.parts.UpperTorso.Color, f.parts.LowerTorso.Color = cloth, cloth
	f.parts.UpperTorso.Reflectance, f.parts.LowerTorso.Reflectance = 0, 0
	-- A bronze faceplate with one cyan visor, under a spiked crown.
	f.add("Head", "Faceplate", Vector3.new(h.X * 0.8, h.Y * 0.82, 0.12 * s), f.face(0, -0.04, -0.02), armor:Lerp(FIGURE_WHITE, 0.1), METAL).Reflectance = 0.2
	f.add("Head", "Visor", Vector3.new(h.X * 0.62, 0.1 * s, 0.05 * s), f.face(0, 0.14, 0.07 * s), cyan, NEON)
	f.add("Head", "CrownBand", Vector3.new(h.X * 1.08, h.Y * 0.22, h.Z * 1.08), CFrame.new(0, h.Y * 0.42, 0), gold, METAL)
	for i = 0, 5 do
		local a = i * math.pi / 3
		local tall = i == 0 and 1 or 0.7
		f.add("Head", "CrownSpike", Vector3.new(0.18 * s, h.Y * 0.7 * tall, 0.18 * s), CFrame.new(math.sin(a) * h.X * 0.46, h.Y * 0.52 + h.Y * 0.35 * tall, -math.cos(a) * h.Z * 0.46) * CFrame.Angles(0, -a + math.pi / 4, 0), gold, METAL)
	end
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "Clasp", Vector3.new(0.3, 0.3, 0.1) * s, CFrame.new(side * c.X * 0.36, c.Y * 0.4, -c.Z / 2 - 0.05 * s), gold, METAL, Enum.PartType.Ball)
		f.add(side < 0 and "LeftUpperArm" or "RightUpperArm", "Pauldron", f.sizes.upperArm * Vector3.new(1.36, 0.4, 1.28), CFrame.new(side * 0.05 * s, f.sizes.upperArm.Y * 0.42, 0), armor:Lerp(gold, 0.3), METAL)
	end
	f.add("LowerTorso", "Tunic", Vector3.new(p.X * 1.12, 1.3 * s, p.Z * 1.14), CFrame.new(0, -0.5 * s, 0), cloth, FABRIC)
	cape(f, cloth, 4.2, gold)
	belt(f, Color3.fromRGB(70, 60, 44), gold)
	-- The orb scepter, held upright beside him.
	f.rod("LeftHand", "Scepter", Vector3.new(0, 1.8 * s, -0.36 * s), Vector3.new(0, -1.6 * s, -0.36 * s), 0.14 * s, gold, METAL)
	f.add("LeftHand", "Orb", Vector3.new(0.5, 0.5, 0.5) * s, CFrame.new(0, 2.05 * s, -0.36 * s), cyan, NEON, "ball")
end
ENEMY_EXTRAS.loki = function(f, def)
	local h, c, p, s = f.parts.Head.Size, f.sizes.chest, f.sizes.pelvis, f.scale
	local robe, silver, mantle, magenta, mirror = Color3.fromRGB(46, 32, 74), Color3.fromRGB(204, 210, 222), Color3.fromRGB(92, 50, 150), Color3.fromRGB(236, 96, 220), Color3.fromRGB(220, 226, 255)
	for _, name in ipairs({ "UpperTorso", "LowerTorso", "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }) do f.parts[name].Color = robe end
	Figure.Face(f, "fierce", { eye = magenta })
	Figure.Hair(f, Color3.fromRGB(236, 236, 242), "long", def and def.illusion)
	-- A silver circlet; behind the head, a halo of floating mirror shards.
	f.add("Head", "Circlet", h * Vector3.new(1.06, 0.14, 1.06), CFrame.new(0, h.Y * 0.32, 0), silver, METAL)
	-- The decoys keep the crowd budget: everything but the circlet's gem.
	if not (def and def.illusion) then f.add("Head", "CircletGem", Vector3.new(0.2, 0.26, 0.06) * s, f.face(0, 0.32, 0.06) * CFrame.Angles(0, 0, math.pi / 4), magenta, NEON) end
	for i = 0, 4 do
		local a = (i - 2) * 0.55
		f.add("Head", "MirrorShard", Vector3.new(0.18, 0.5, 0.06) * s, CFrame.new(math.sin(a) * h.X * 0.95, h.Y * 0.3 + math.cos(a) * h.Y * 0.66, h.Z * 0.66) * CFrame.Angles(0, 0, -a), mirror, CRYSTAL)
	end
	for _, side in ipairs({ -1, 1 }) do
		f.add("UpperTorso", "Trim", Vector3.new(0.12 * s, c.Y * 0.9, 0.05 * s), CFrame.new(side * c.X * 0.2, 0, -c.Z / 2 - 0.03 * s), silver, METAL)
	end
	f.add("UpperTorso", "Collar", c * Vector3.new(0.9, 0.24, 1.1), CFrame.new(0, c.Y * 0.44, 0), silver, METAL)
	cape(f, mantle, 4)
	f.add("LowerTorso", "Robe", Vector3.new(p.X * 1.1, 1.5 * s, p.Z * 1.1), CFrame.new(0, -0.6 * s, 0), robe:Lerp(mantle, 0.35), FABRIC)
	-- The prism staff, held upright.
	f.rod("RightHand", "Staff", Vector3.new(0, 1.6 * s, -0.32 * s), Vector3.new(0, -2.4 * s, -0.32 * s), 0.14 * s, silver, METAL)
	f.add("RightHand", "Prism", Vector3.new(0.42, 0.66, 0.42) * s, CFrame.new(0, 1.95 * s, -0.32 * s) * CFrame.Angles(0, math.pi / 4, 0), magenta, NEON)
end
ENEMY_EXTRAS.illusion = ENEMY_EXTRAS.loki

-- Outfits (owner, 16/10: variety of villains is very good): the plain
-- families come in several looks, so a wave is a crowd of different people
-- and not copies of one. Each look is a few pieces over the family's own, in
-- the crowd's part budget. The server publishes every look ("zombie",
-- "zombie#2"...) and the client picks one per enemy from its server id, so
-- every player sees the same enemy dressed the same. Rules never read it.
local function strip(f, names)
	for _, item in ipairs(f.model:GetChildren()) do
		if table.find(names, item.Name) then item:Destroy() end
	end
end
-- A fixed colour on these body parts instead of the crowd's random shirt.
local function wear(f, names, color)
	for _, name in ipairs(names) do
		local body = f.parts[name]
		if body then body:SetAttribute("Tint", nil); body.Color = color end
	end
end
local function brimmed(f, name, height, color)
	local h, s = f.parts.Head.Size, f.scale
	return f.add("Head", name, Vector3.new(0.1 * s, h.X * 1.4, h.Z * 1.4), CFrame.new(0, h.Y * height, 0) * CFrame.Angles(0, 0, math.pi / 2), color, FABRIC, Enum.PartType.Cylinder)
end
local OUTFITS = {}
-- The office worker: a white shirt, a blue tie and a staff badge.
OUTFITS.office = function(f)
	local c, s = f.sizes.chest, f.scale
	local tie = Color3.fromRGB(46, 78, 168)
	wear(f, { "UpperTorso", "LeftUpperArm", "RightUpperArm" }, Color3.fromRGB(226, 232, 240))
	f.add("UpperTorso", "Tie", Vector3.new(0.26 * s, c.Y * 0.66, 0.06 * s), CFrame.new(0, -c.Y * 0.06, -c.Z / 2 - 0.04 * s), tie, FABRIC)
	f.add("UpperTorso", "TieKnot", Vector3.new(0.3, 0.22, 0.1) * s, CFrame.new(0, c.Y * 0.36, -c.Z / 2 - 0.05 * s), tie, FABRIC, "ball")
	f.add("UpperTorso", "Badge", Vector3.new(0.34, 0.24, 0.05) * s, CFrame.new(c.X * 0.26, c.Y * 0.14, -c.Z / 2 - 0.04 * s), Color3.fromRGB(250, 250, 250), FABRIC)
end
-- The builder: a hard hat and a hi-vis vest with reflective stripes.
OUTFITS.builder = function(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	local yellow, orange, silver = Color3.fromRGB(250, 200, 40), Color3.fromRGB(255, 122, 32), Color3.fromRGB(222, 228, 234)
	strip(f, { "Hair" })
	f.add("Head", "HardHat", h * Vector3.new(1.12, 0.62, 1.12), CFrame.new(0, h.Y * 0.34, 0), yellow, FABRIC, "ball")
	brimmed(f, "HatBrim", 0.2, yellow)
	f.add("UpperTorso", "Vest", c * Vector3.new(0.82, 0.92, 1.08), CFrame.new(0, -c.Y * 0.03, 0), orange, FABRIC)
	for _, y in ipairs({ -0.2, 0.14 }) do
		f.add("UpperTorso", "VestStripe", Vector3.new(c.X * 0.84, 0.12 * s, c.Z * 1.1), CFrame.new(0, c.Y * y, 0), silver, FABRIC)
	end
end
-- The cook: a tall white hat, an apron and a red neckerchief.
OUTFITS.chef = function(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	local white = Color3.fromRGB(244, 244, 238)
	strip(f, { "Hair" })
	f.add("Head", "ChefHat", Vector3.new(h.Y * 0.62, h.X * 0.84, h.X * 0.84), CFrame.new(0, h.Y * 0.74, 0) * CFrame.Angles(0, 0, math.pi / 2), white, FABRIC, Enum.PartType.Cylinder)
	f.add("Head", "ChefPuff", Vector3.new(h.X * 1.02, h.Y * 0.42, h.Z * 1.02), CFrame.new(0, h.Y * 1.06, 0), white, FABRIC, "ball")
	f.add("UpperTorso", "Apron", Vector3.new(c.X * 0.62, c.Y * 1.5, 0.06 * s), CFrame.new(0, -c.Y * 0.3, -c.Z / 2 - 0.05 * s), white, FABRIC)
	f.add("UpperTorso", "Neckerchief", Vector3.new(0.56, 0.3, 0.3) * s, CFrame.new(0, c.Y * 0.44, -c.Z * 0.34), Color3.fromRGB(214, 52, 52), FABRIC, "ball")
end
-- The gamer: a cap turned backwards, headphones and a backpack.
OUTFITS.gamer = function(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	local cap, phones = Color3.fromRGB(40, 176, 124), Color3.fromRGB(36, 38, 46)
	strip(f, { "Hair" })
	f.add("Head", "Cap", h * Vector3.new(1.08, 0.5, 1.08), CFrame.new(0, h.Y * 0.32, 0), cap, FABRIC, "ball")
	f.add("Head", "CapBrim", Vector3.new(h.X * 0.62, 0.08 * s, h.Z * 0.5), CFrame.new(0, h.Y * 0.2, h.Z * 0.62), cap, FABRIC)
	f.add("Head", "PhoneBand", Vector3.new(h.X * 1.12, 0.12 * s, 0.16 * s), CFrame.new(0, h.Y * 0.5, 0), phones, FABRIC)
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "PhoneCup", Vector3.new(0.2, 0.5, 0.46) * s, CFrame.new(side * h.X * 0.54, 0, 0), phones, FABRIC, "ball")
	end
	f.add("UpperTorso", "Backpack", Vector3.new(c.X * 0.66, c.Y * 0.8, 0.5 * s), CFrame.new(0, -c.Y * 0.04, c.Z / 2 + 0.25 * s), Color3.fromRGB(222, 82, 60), FABRIC)
end
-- The tourist: a bucket hat and a camera on its strap.
OUTFITS.tourist = function(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	local hat, camera = Color3.fromRGB(236, 214, 150), Color3.fromRGB(40, 42, 48)
	strip(f, { "Hair" })
	f.add("Head", "BucketHat", h * Vector3.new(1.06, 0.46, 1.06), CFrame.new(0, h.Y * 0.36, 0), hat, FABRIC, "ball")
	brimmed(f, "HatBrim", 0.22, hat)
	f.add("UpperTorso", "Camera", Vector3.new(0.6, 0.42, 0.26) * s, CFrame.new(0, -c.Y * 0.1, -c.Z / 2 - 0.16 * s), camera, METAL)
	f.disc("UpperTorso", "CameraLens", 0.3 * s, 0.2 * s, CFrame.new(0, -c.Y * 0.1, -c.Z / 2 - 0.34 * s), Color3.fromRGB(120, 170, 220), Enum.Material.Glass)
	f.rod("UpperTorso", "CameraStrap", Vector3.new(-c.X * 0.3, c.Y * 0.48, -c.Z / 2 - 0.04 * s), Vector3.new(-0.2 * s, -c.Y * 0.04, -c.Z / 2 - 0.05 * s), 0.08 * s, camera, FABRIC)
end
-- The rocker: a pink mohawk, a black leather jacket and studded shoulders.
OUTFITS.rocker = function(f)
	local h, s = f.parts.Head.Size, f.scale
	local leather, spike, stud = Color3.fromRGB(34, 34, 40), Color3.fromRGB(236, 60, 160), Color3.fromRGB(210, 214, 222)
	strip(f, { "Hair" })
	wear(f, { "UpperTorso", "LeftUpperArm", "RightUpperArm" }, leather)
	for i = -1.5, 1.5 do
		f.add("Head", "Mohawk", Vector3.new(0.22 * s, h.Y * 0.5, h.Z * 0.3), CFrame.new(0, h.Y * 0.66, i * h.Z * 0.2), spike, FABRIC, "wedge")
	end
	for _, side in ipairs({ -1, 1 }) do
		local arm = side < 0 and "LeftUpperArm" or "RightUpperArm"
		f.add(arm, "Stud", Vector3.new(0.22, 0.22, 0.22) * s, CFrame.new(0, f.sizes.upperArm.Y * 0.36, -f.sizes.upperArm.Z * 0.5), stud, METAL, "ball")
	end
end
-- The jogger: earbuds and wristbands, no scarf.
OUTFITS.jogger = function(f)
	local h, s = f.parts.Head.Size, f.scale
	strip(f, { "Scarf" })
	for _, side in ipairs({ -1, 1 }) do
		f.add("Head", "Earbud", Vector3.new(0.2, 0.2, 0.2) * s, CFrame.new(side * h.X * 0.52, -h.Y * 0.04, 0), Color3.fromRGB(245, 245, 245), FABRIC, "ball")
		local arm = side < 0 and "LeftLowerArm" or "RightLowerArm"
		f.add(arm, "Wristband", f.sizes.lowerArm * Vector3.new(1.12, 0.22, 1.12), CFrame.new(0, -f.sizes.lowerArm.Y * 0.36, 0), Color3.fromRGB(80, 200, 255), FABRIC)
	end
end
-- The delivery rider: a red cap and the delivery box on its back.
OUTFITS.delivery = function(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	local red, white = Color3.fromRGB(214, 54, 48), Color3.fromRGB(250, 246, 236)
	strip(f, { "Headband", "Scarf" })
	f.add("Head", "Cap", h * Vector3.new(1.06, 0.48, 1.06), CFrame.new(0, h.Y * 0.33, 0), red, FABRIC, "ball")
	f.add("Head", "CapBrim", Vector3.new(h.X * 0.62, 0.08 * s, h.Z * 0.5), CFrame.new(0, h.Y * 0.18, -h.Z * 0.62), red, FABRIC)
	f.add("UpperTorso", "DeliveryBox", Vector3.new(c.X * 0.9, c.Y * 0.9, 0.9 * s), CFrame.new(0, c.Y * 0.06, c.Z / 2 + 0.46 * s), red, FABRIC)
	f.add("UpperTorso", "BoxLogo", Vector3.new(c.X * 0.5, c.Y * 0.36, 0.05 * s), CFrame.new(0, c.Y * 0.1, c.Z / 2 + 0.93 * s), white, FABRIC)
end
-- The skater: a helmet, knee pads and elbow pads.
OUTFITS.skater = function(f)
	local h, s = f.parts.Head.Size, f.scale
	local helmet, pad = Color3.fromRGB(90, 200, 90), Color3.fromRGB(40, 44, 52)
	strip(f, { "Headband", "Scarf" })
	f.add("Head", "SkateHelmet", h * Vector3.new(1.14, 0.66, 1.14), CFrame.new(0, h.Y * 0.3, 0), helmet, FABRIC, "ball")
	for _, side in ipairs({ -1, 1 }) do
		local leg, arm = side < 0 and "LeftLowerLeg" or "RightLowerLeg", side < 0 and "LeftLowerArm" or "RightLowerArm"
		f.add(leg, "KneePad", f.sizes.lowerLeg * Vector3.new(1.12, 0.32, 0.9), CFrame.new(0, f.sizes.lowerLeg.Y * 0.38, -f.sizes.lowerLeg.Z * 0.22), pad, FABRIC, "ball")
		f.add(arm, "ElbowPad", f.sizes.lowerArm * Vector3.new(1.12, 0.28, 0.9), CFrame.new(0, f.sizes.lowerArm.Y * 0.38, f.sizes.lowerArm.Z * 0.16), pad, FABRIC, "ball")
	end
end
-- The wrestler: a champion's belt, a bandana and wristbands.
OUTFITS.wrestler = function(f)
	local h, p, s = f.parts.Head.Size, f.sizes.pelvis, f.scale
	local gold, band = Color3.fromRGB(240, 196, 60), Color3.fromRGB(200, 40, 60)
	f.add("LowerTorso", "ChampionBelt", p * Vector3.new(1.1, 0.42, 1.12), CFrame.new(0, p.Y * 0.2, 0), Color3.fromRGB(40, 36, 44), FABRIC)
	f.disc("LowerTorso", "BeltPlate", p.X * 0.36, 0.14 * s, CFrame.new(0, p.Y * 0.1, -p.Z * 0.66), gold, METAL)
	f.add("Head", "Bandana", h * Vector3.new(1.06, 0.26, 1.06), CFrame.new(0, h.Y * 0.3, 0), band, FABRIC, "head")
	for _, side in ipairs({ -1, 1 }) do
		local arm = side < 0 and "LeftLowerArm" or "RightLowerArm"
		f.add(arm, "Wristband", f.sizes.lowerArm * Vector3.new(1.1, 0.28, 1.1), CFrame.new(0, -f.sizes.lowerArm.Y * 0.34, 0), band, FABRIC)
	end
end
-- The lumberjack: a red shirt, an orange beanie and a big beard.
OUTFITS.lumberjack = function(f)
	local h = f.parts.Head.Size
	strip(f, { "Jaw", "Tooth" })
	wear(f, { "UpperTorso" }, Color3.fromRGB(196, 50, 46))
	f.add("Head", "Beanie", h * Vector3.new(1.08, 0.56, 1.08), CFrame.new(0, h.Y * 0.36, 0), Color3.fromRGB(230, 120, 40), FABRIC, "ball")
	f.add("Head", "Beard", Vector3.new(h.X * 0.92, h.Y * 0.56, h.Z * 0.44), CFrame.new(0, -h.Y * 0.2, -h.Z * 0.38), Color3.fromRGB(96, 60, 36), FABRIC, "ball")
end
-- The scrap knight: a bucket for a helmet and a bin lid for a shield.
OUTFITS.scrap = function(f)
	local h, s = f.parts.Head.Size, f.scale
	local tin = Color3.fromRGB(150, 156, 162)
	strip(f, { "Helmet", "Shield" })
	f.add("Head", "Bucket", Vector3.new(h.Y * 0.62, h.X * 1.12, h.X * 1.12), CFrame.new(0, h.Y * 0.36, 0) * CFrame.Angles(0, 0, math.pi / 2), tin, METAL, Enum.PartType.Cylinder)
	local arm = f.sizes.lowerArm
	f.disc("LeftLowerArm", "BinLid", 1.7 * s, 0.14 * s, CFrame.new(-arm.X / 2 - 0.12 * s, 0.1 * s, -0.1 * s) * CFrame.Angles(0, math.pi / 2, 0), tin, METAL)
	f.add("LeftLowerArm", "LidHandle", Vector3.new(0.12, 0.2, 0.5) * s, CFrame.new(-arm.X / 2 - 0.26 * s, 0.1 * s, -0.1 * s), tin:Lerp(EC.ink, 0.3), METAL)
end
-- The guard: a navy helmet with a clear visor and a clear riot shield.
OUTFITS.guard = function(f)
	local h, s = f.parts.Head.Size, f.scale
	local navy, glass = Color3.fromRGB(40, 50, 76), Color3.fromRGB(150, 200, 230)
	strip(f, { "Helmet", "Shield" })
	f.add("Head", "GuardHelmet", h * Vector3.new(1.14, 0.7, 1.14), CFrame.new(0, h.Y * 0.28, 0), navy, METAL, "ball")
	f.add("Head", "GuardVisor", Vector3.new(h.X * 0.96, h.Y * 0.5, 0.06 * s), f.face(0, 0.1, 0.08), glass, Enum.Material.Glass, "ball").Transparency = 0.55
	local arm = f.sizes.lowerArm
	f.add("LeftLowerArm", "ClearShield", Vector3.new(0.12, 2.6, 1.5) * s, CFrame.new(-arm.X / 2 - 0.14 * s, 0.2 * s, -0.1 * s), glass, Enum.Material.Glass).Transparency = 0.45
end
-- The propeller flyer: a beanie with a propeller on top.
OUTFITS.propeller = function(f)
	local h, s = f.parts.Head.Size, f.scale
	f.add("Head", "Beanie", h * Vector3.new(1.08, 0.54, 1.08), CFrame.new(0, h.Y * 0.34, 0), Color3.fromRGB(70, 130, 230), FABRIC, "ball")
	f.add("Head", "PropellerHub", Vector3.new(0.4 * s, 0.16 * s, 0.16 * s), CFrame.new(0, h.Y * 0.66, 0) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(250, 210, 60), METAL, Enum.PartType.Cylinder)
	for _, angle in ipairs({ 0, math.pi / 2 }) do
		f.add("Head", "PropellerBlade", Vector3.new(1.6 * s, 0.06 * s, 0.28 * s), CFrame.new(0, h.Y * 0.86, 0) * CFrame.Angles(0, angle, 0.15), Color3.fromRGB(230, 60, 60), FABRIC)
	end
end
-- The aviator: a leather flying cap and a long white scarf.
OUTFITS.aviator = function(f)
	local h, c, s = f.parts.Head.Size, f.sizes.chest, f.scale
	f.add("Head", "AviatorCap", h * Vector3.new(1.1, 0.8, 1.1), CFrame.new(0, h.Y * 0.18, h.Z * 0.06), Color3.fromRGB(120, 76, 44), FABRIC, "ball")
	f.add("UpperTorso", "Scarf", Vector3.new(0.5, 0.16, 2.2) * s, CFrame.new(-0.3 * s, c.Y * 0.42, c.Z / 2 + 0.9 * s) * CFrame.Angles(-0.4, 0, 0), Color3.fromRGB(245, 240, 230), FABRIC)
end
-- The looks each plain family comes in, besides its own.
local ENEMY_OUTFITS = {
	zombie = { "office", "builder", "chef", "gamer", "tourist", "rocker" },
	runner = { "jogger", "delivery", "skater" },
	brute = { "wrestler", "lumberjack" },
	armored = { "scrap", "guard" },
	flyer = { "propeller", "aviator" },
}
Figure.EnemyOutfits = ENEMY_OUTFITS

-- Villains get the heroes' finish (owner, 16/10: refine every villain):
-- rounded vinyl limbs whose ends overlap at the joints and flat costume plates
-- with rounded edges instead of planks. The big bodies keep their V of chest
-- and shoulders (a round barrel read as a balloon). No part is added.
local LIMBS = { "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm", "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg" }
local function polishVillain(f, family)
	for _, name in ipairs(LIMBS) do
		local contour = f.parts[name] and f.parts[name]:FindFirstChild("BodyContour")
		if contour then contour.MeshType, contour.Scale = Enum.MeshType.Head, Vector3.new(0.98, 1.14, 0.98) end
	end
	for _, item in ipairs(f.model:GetChildren()) do
		if item:IsA("Part") and item.Shape == Enum.PartType.Block and not item:FindFirstChildOfClass("SpecialMesh") and item.Material ~= NEON then
			local fit = item:FindFirstChild("Fit")
			local host = fit and fit.Part0
			if host and host.Name ~= "Head" then
				local dims = { item.Size.X, item.Size.Y, item.Size.Z }
				table.sort(dims)
				if dims[2] >= 0.12 * f.scale and dims[1] < dims[2] * 0.5 then
					local mesh = Instance.new("SpecialMesh")
					mesh.Name, mesh.MeshType, mesh.Parent = "CostumeContour", roundedMeshType(item.Size), item
				end
			end
		end
	end
	f.model:SetAttribute("VillainFinish", "polished")
end

function Figure.Enemy(parent, def, outfit)
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
	if outfit and OUTFITS[outfit] then
		OUTFITS[outfit](figure)
		figure.model:SetAttribute("Outfit", outfit)
	end
	for name, body in pairs(figure.parts) do
		if name ~= "HumanoidRootPart" then
			if family == "doom" then
				body.Material = name == "LowerTorso" and FABRIC or METAL
				body.Reflectance = name == "LowerTorso" and 0 or 0.04
			elseif name ~= "Head" and body.Color ~= skin then
				body.Material = FABRIC
			end
		end
	end
	-- The disposable illusion already carries the boss's coat/horns. Preserve
	-- its 40-part crowd budget rather than duplicating an obscured torso edge.
	Figure.Finish(figure, def.boss == true, def.id == "illusion")
	polishVillain(figure, family)
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
		-- The plain families' other looks, published beside it as "id#2", "id#3"...
		local outfits = not def.faction and not def.boss and ENEMY_OUTFITS[id]
		if outfits then
			figure.model:SetAttribute("Outfits", #outfits + 1)
			for index, outfit in ipairs(outfits) do
				local look = Figure.Enemy(holder, def, outfit)
				look.model.Name = id .. "#" .. (index + 1)
				look.model.Parent = enemies
			end
		end
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
-- A statue holds a heroic pose instead of standing to attention. Every joint
-- of a figure is a Motor6D between anchored parts, so a pose turns the part on
-- the far side of each joint about the joint's pivot, together with all that
-- hangs from it (the next limbs and the costume pieces welded to them).
-- Angles follow the client's Motion: X lifts a limb forward, Z swings it out
-- (negative on the left side, positive on the right), Y twists it. Parents
-- are listed before their children.
local STATUE_POSE = {
	-- Repulsor raised at the plaza: the glowing palm faces whoever walks up.
	ironman = {
		{ "Waist", CFrame.Angles(0, -0.12, 0) },
		{ "RightShoulder", CFrame.Angles(1.48, 0, 0.12) },
		{ "RightElbow", CFrame.Angles(0.06, 0, 0) },
		{ "LeftShoulder", CFrame.Angles(0.1, 0, -0.16) },
		{ "LeftElbow", CFrame.Angles(0.28, 0, 0) },
		{ "Neck", CFrame.Angles(0.04, 0.1, 0) },
		{ "LeftHip", CFrame.Angles(0, 0, -0.1) }, { "LeftAnkle", CFrame.Angles(0, 0, 0.1) },
		{ "RightHip", CFrame.Angles(0, 0, 0.1) }, { "RightAnkle", CFrame.Angles(0, 0, -0.1) },
	},
	-- Fist raised, shield held out toward the plaza.
	captain = {
		{ "Waist", CFrame.Angles(0, -0.16, 0) },
		{ "RightShoulder", CFrame.Angles(2.65, 0, 0.32) },
		{ "RightElbow", CFrame.Angles(0.3, 0, 0) },
		{ "LeftShoulder", CFrame.Angles(0.14, 0, -0.14) },
		{ "LeftElbow", CFrame.Angles(0.1, 0, 0) },
		{ "Neck", CFrame.Angles(0.08, 0.12, 0) },
		{ "LeftHip", CFrame.Angles(0, 0, -0.12) }, { "LeftAnkle", CFrame.Angles(0, 0, 0.12) },
		{ "RightHip", CFrame.Angles(0, 0, 0.12) }, { "RightAnkle", CFrame.Angles(0, 0, -0.12) },
	},
}
World.StatuePose = STATUE_POSE

function Figure.PoseStatic(model, pose)
	if not pose then return end
	local motors, hung = {}, {}
	local function hang(from, part)
		if not from or not part then return end
		hung[from] = hung[from] or {}
		table.insert(hung[from], part)
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("Motor6D") then
			motors[item.Name] = item
			hang(item.Part0, item.Part1)
		elseif item:IsA("Weld") and item.Name == "Fit" then
			hang(item.Part0, item.Part1)
		end
	end
	local function collect(part, out)
		table.insert(out, part)
		for _, child in ipairs(hung[part] or {}) do collect(child, out) end
		return out
	end
	for _, step in ipairs(pose) do
		local motor = motors[step[1]]
		if motor and motor.Part0 and motor.Part1 then
			local pivot = motor.Part0.CFrame * motor.C0
			local turn = pivot * step[2] * pivot:Inverse()
			for _, part in ipairs(collect(motor.Part1, {})) do part.CFrame = turn * part.CFrame end
		end
	end
	model:SetAttribute("StatuePosed", true)
end

-- A hero standing as scenery in the lobby (statues, cameos) glows with its
-- power (owner, 16/10: "faíscas e raios em volta dos heróis", only where few
-- heroes stand, never in a battle): one slow emitter of the engine's own
-- sparkle, spark or ember texture around the chest.
local HERO_AURA = {
	thor = { "spark", Color3.fromRGB(150, 215, 255) }, storm = { "spark", Color3.fromRGB(170, 230, 255) },
	strange = { "sparkle", Color3.fromRGB(255, 200, 90) }, wanda = { "sparkle", Color3.fromRGB(255, 70, 190) },
	panther = { "sparkle", Color3.fromRGB(190, 130, 255) }, hulk = { "ember", Color3.fromRGB(255, 140, 50) },
	groot = { "sparkle", Color3.fromRGB(130, 255, 140) }, ironman = { "spark", Color3.fromRGB(110, 220, 255) },
	captain = { "sparkle", Color3.fromRGB(255, 214, 110) }, ghostrider = { "ember", Color3.fromRGB(255, 130, 40) },
	silversurfer = { "sparkle", Color3.fromRGB(170, 190, 255) }, jean = { "ember", Color3.fromRGB(255, 160, 60) },
	captainmarvel = { "sparkle", Color3.fromRGB(255, 210, 120) }, solartitan = { "sparkle", Color3.fromRGB(255, 200, 70) },
	emerald = { "sparkle", Color3.fromRGB(110, 255, 150) }, speedster = { "spark", Color3.fromRGB(255, 220, 80) },
}
local AURA_TEXTURE = {
	spark = "rbxasset://textures/particles/sparkles_main.dds", sparkle = "rbxasset://textures/particles/sparkles_main.dds",
	ember = "rbxasset://textures/particles/fire_sparks_main.dds",
}
local function heroAura(model, heroId)
	local aura = HERO_AURA[heroId]
	local chest = model:FindFirstChild("UpperTorso")
	if not (aura and chest) then return end
	local kind, tint = aura[1], aura[2]
	local particles = Instance.new("ParticleEmitter")
	particles.Name, particles.Texture = "HeroAura", AURA_TEXTURE[kind]
	particles.Color = ColorSequence.new(tint:Lerp(Color3.new(1, 1, 1), 0.35), tint)
	-- Bright enough to read in daylight (the lobby's Bloom stays tame).
	particles.LightEmission, particles.LightInfluence, particles.Brightness = 1, 0, 2
	local size = chest.Size.X
	if kind == "ember" then
		particles.Rate, particles.Lifetime, particles.Speed = 12, NumberRange.new(0.8, 1.4), NumberRange.new(2, 4)
		particles.Size = NumberSequence.new(size * 0.3, size * 0.06)
		particles.Acceleration = Vector3.new(0, 5, 0)
	elseif kind == "spark" then
		-- Crackling: quick, bright and scattered.
		particles.Rate, particles.Lifetime, particles.Speed = 16, NumberRange.new(0.15, 0.35), NumberRange.new(4, 8)
		particles.Size = NumberSequence.new(size * 0.45, size * 0.04)
	else
		particles.Rate, particles.Lifetime, particles.Speed = 9, NumberRange.new(1, 1.8), NumberRange.new(0.8, 1.8)
		particles.Size = NumberSequence.new(size * 0.4, 0)
		particles.Acceleration = Vector3.new(0, 1.2, 0)
	end
	particles.Transparency = NumberSequence.new(0.1, 1)
	particles.SpreadAngle = Vector2.new(180, 180)
	particles.Rotation, particles.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-90, 90)
	particles.Parent = chest
	return particles
end

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
	heroAura(model, heroId)
	-- A figure standing as scenery still breathes and looks about (client side).
	model:SetAttribute("IdleFigure", true)
	model:SetAttribute("IdlePhase", (origin.Position.X * 0.37 + origin.Position.Z * 0.21) % 6.28)
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch = true, false, false, false end
	end
	model:PivotTo(origin)
	-- The figure's parts breathe (client side) and never collide, so one plain
	-- invisible block stands in for the body: nobody walks through a statue.
	local ok, frame, size = pcall(function() return model:GetBoundingBox() end)
	if ok and frame and size then
		local blocker = Instance.new("Part")
		blocker.Name, blocker.Anchored, blocker.CanCollide, blocker.CanQuery, blocker.CanTouch = "FigureBlocker", true, true, false, false
		blocker.Transparency, blocker.CastShadow = 1, false
		blocker.Size = Vector3.new(math.max(1.5, size.X * 0.6), size.Y, math.max(1.5, size.Z * 0.6))
		blocker.CFrame = frame
		blocker.Parent = model
	end
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
		sun = 2.6, clockTime = 14, ambient = { 70, 100, 70 }, outdoor = { 100, 140, 88 },
		atmosphereColor = { 140, 200, 120 }, atmosphereDensity = 0.38, glare = 0.18,
		tint = { 170, 255, 150 }, contrast = 0.12, saturation = 0.05, brightness = 0,
		bloom = 0.5, fogColor = { 32, 55, 30 }, fogEnd = 520,
	},
	-- The foundry: a warm late-afternoon furnace glow over iron, not a cold dawn.
	hydra = {
		sun = 2.2, clockTime = 16.5, exposure = 0.55, ambient = { 112, 102, 102 }, outdoor = { 138, 124, 120 },
		atmosphereColor = { 150, 120, 110 }, atmosphereDensity = 0.3, glare = 0.1,
		tint = { 255, 236, 222 }, contrast = 0.07, saturation = 0.04, brightness = 0.02,
		bloom = 0.3, fogColor = { 56, 40, 36 }, fogEnd = 520,
	},
	wakanda = {
		sun = 2.4, clockTime = 17.5, exposure = 0.5, ambient = { 70, 55, 90 }, outdoor = { 110, 85, 60 },
		atmosphereColor = { 190, 150, 210 }, atmosphereDensity = 0.26, glare = 0.22,
		tint = { 230, 200, 255 }, contrast = 0.1, saturation = 0.08, brightness = 0.02,
		bloom = 0.48, fogColor = { 45, 35, 55 }, fogEnd = 650,
	},
	latveria = {
		sun = 1.8, clockTime = 18.5, exposure = 0.4, ambient = { 100, 102, 137 }, outdoor = { 117, 129, 167 },
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
	-- The owner's rule: never a blown-out glow (bloom stays at or under 0.2).
	bloom.Intensity, bloom.Size, bloom.Threshold = math.min(preset.bloom * 0.55, 0.2), 24, 1.1
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
	stone = Color3.fromRGB(193, 203, 214), stoneDark = Color3.fromRGB(124, 143, 164), stoneWarm = Color3.fromRGB(221, 215, 201),
	steel = Color3.fromRGB(61, 81, 111), navy = Color3.fromRGB(20, 35, 61), trim = Color3.fromRGB(230, 237, 240),
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
			local glass = Kit.block(parent, "FenceGlass", Vector3.new(0.35, height - 1.6, math.max(0.4, length - 1.2)), look * CFrame.new(0, 1 + (height - 1.6) / 2, 0), glow:Lerp(HQ.navy, 0.35), Enum.Material.Glass)
			glass.Transparency = 0.55
			Kit.block(parent, "FenceRail", Vector3.new(0.9, 0.5, length + 0.4), look * CFrame.new(0, height - 0.15, 0), HQ.navy, Enum.Material.Metal, true)
		end
	end
	for i = 1, count do
		local base = points[i]
		Kit.block(parent, "FencePost", Vector3.new(1.5, height + 0.5, 1.5), CFrame.new(base + Vector3.new(0, (height + 0.5) / 2, 0)), HQ.navy, Enum.Material.Metal, true)
		Kit.block(parent, "FenceCap", Vector3.new(1.6, 0.35, 1.6), CFrame.new(base + Vector3.new(0, height + 0.65, 0)), HQ.gold, Enum.Material.Metal)
	end
end

-- A street lamp: steel foot, slim pole, warm lantern under a cap.
function Kit.lamp(parent, base, height)
	height = height or 9
	Kit.disc(parent, "LampFoot", base + Vector3.new(0, 0.3, 0), 2.2, 0.6, HQ.steel, Enum.Material.Metal)
	Kit.column(parent, "LampPole", base, height, 0.6, HQ.navy, Enum.Material.Metal)
	local glow = Kit.block(parent, "LampGlow", Vector3.new(1.5, 1.6, 1.5), CFrame.new(base + Vector3.new(0, height + 0.8, 0)), HQ.lamp:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.Glass)
	Kit.block(parent, "LampCap", Vector3.new(2.3, 0.45, 2.3), CFrame.new(base + Vector3.new(0, height + 1.8, 0)), HQ.gold, Enum.Material.Metal)
	Kit.light(glow, HQ.lamp, 14, 0.55)
	return glow
end

-- Short architectural lanterns mark stair edges without blocking the route.
function Kit.bollard(parent, base)
	local V = Vector3.new
	Kit.block(parent, "LanternPlinth", V(2.2, 0.45, 2.2), CFrame.new(base + V(0, 0.225, 0)), HQ.stoneWarm, Enum.Material.Slate, true)
	Kit.block(parent, "LanternBody", V(1.65, 2.7, 1.65), CFrame.new(base + V(0, 1.8, 0)), HQ.navy, Enum.Material.Metal, true)
	Kit.block(parent, "LanternInset", V(0.16, 1.5, 0.1), CFrame.new(base + V(0, 1.8, -0.86)), HQ.gold, Enum.Material.Metal)
	local light = Kit.block(parent, "LanternLens", V(1.4, 0.85, 1.4), CFrame.new(base + V(0, 3.4, 0)), HQ.lamp:Lerp(Color3.new(1, 1, 1), 0.35), Enum.Material.Glass)
	Kit.block(parent, "LanternCrown", V(1.9, 0.28, 1.9), CFrame.new(base + V(0, 3.96, 0)), HQ.gold, Enum.Material.Metal)
	Kit.light(light, HQ.lamp, 9, 0.25)
end

-- A continuous curved garden with a deep stone base and inset gold coping.
-- Five broad sections replace dozens of tiny disconnected flower-bed parts.
function Kit.crescentGarden(parent, center, outward, withTree)
	local V = Vector3.new
	local garden = Instance.new("Model")
	garden.Name, garden.Parent = "PlazaGarden", parent
	garden:SetAttribute("Grounded", true)
	local inner, outer, steps = 40.5, 47.5, 5
	local width = math.rad(26)
	for i = 1, steps do
		local angle = outward + (i - (steps + 1) / 2) * width / steps
		local dir = V(math.cos(angle), 0, math.sin(angle))
		local frame = CFrame.new(center + dir * ((inner + outer) / 2)) * CFrame.Angles(0, -angle, 0)
		local length = 2 * outer * math.sin(width / steps / 2) + 0.08
		-- Embed the footing so face separation at adjacent sections cannot lift
		-- its underside above the plaza paving.
		Kit.block(garden, "GardenFoundation", V(outer - inner, 1.8, length), frame * CFrame.new(0, 0.6, 0), HQ.navy, Enum.Material.Slate, true)
		Kit.block(garden, "GardenSoil", V(outer - inner - 0.9, 0.18, length - 0.2), frame * CFrame.new(0, 1.6, 0), Color3.fromRGB(74, 61, 44), Enum.Material.Ground)
		for _, side in ipairs({-1, 1}) do
			Kit.block(garden, "GardenCoping", V(0.65, 0.45, length), frame * CFrame.new(side * 3.25, 1.55, 0), HQ.stoneWarm, Enum.Material.SmoothPlastic, true)
			Kit.block(garden, "GardenGoldInlay", V(0.12, 0.08, length - 0.1), frame * CFrame.new(side * 3.25, 1.82, 0), HQ.gold, Enum.Material.Metal)
		end
		local shrubAt = center + dir * (i % 2 == 0 and 45.1 or 42.7) + V(0, 1.8, 0)
		Kit.blob(garden, "GardenShrub", V(3.7, 2.3, 3.1), CFrame.new(shrubAt), i % 2 == 0 and HQ.leafLight or HQ.leaf, Enum.Material.Grass)
		local bloomAt = center + dir * (i % 2 == 0 and 42 or 46) + V(0, 2.2, 0)
		Kit.blob(garden, "GardenBlossom", V(1.1, 0.6, 1.4), CFrame.new(bloomAt), i % 2 == 0 and Color3.fromRGB(235, 134, 164) or Color3.fromRGB(244, 204, 93), Enum.Material.SmoothPlastic)
	end
	if withTree then
		local foot = center + V(math.cos(outward) * 44, 1.78, math.sin(outward) * 44)
		Kit.tree(garden, foot, 0.9):SetAttribute("Planted", true)
	end
	return garden
end

-- A tree with some body to it: a trunk that flares at the roots and forks into
-- two limbs, and a crown of overlapping lobes in three greens, darker under and
-- lighter on top, so it reads as foliage instead of two balls. A whole tree is
-- one Model.
function Kit.tree(parent, base, scale, tint)
	scale, tint = scale or 1, tint or HQ.leaf
	local tree = Instance.new("Model")
	tree.Name, tree.Parent = "HQTree", parent
	local bark = HQ.trunk
	local barkDark = bark:Lerp(Color3.new(0, 0, 0), 0.22)
	Kit.column(tree, "TreeTrunk", base - Vector3.new(0, 0.5, 0), 3.4 * scale, 1.9 * scale, barkDark, Enum.Material.Wood)
	Kit.column(tree, "TreeTrunk", base + Vector3.new(0, 2.6 * scale, 0), 3.8 * scale, 1.35 * scale, bark, Enum.Material.Wood)
	for index = 0, 1 do
		local a = index * 2.1 + 0.4
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		Kit.blob(tree, "TreeRoot", Vector3.new(1.3, 0.8, 1.0) * scale, CFrame.lookAt(base + out * 0.85 * scale + Vector3.new(0, 0.05, 0), base + Vector3.new(0, 0.05, 0)), barkDark, Enum.Material.Wood)
	end
	local fork = base + Vector3.new(0, 6 * scale, 0)
	for _, side in ipairs({ -1, 1 }) do
		Kit.beam(tree, "TreeLimb", fork, fork + Vector3.new(side * 1.9, 2.3, side * 0.7) * scale, 0.62 * scale, 0.62 * scale, bark, Enum.Material.Wood)
	end
	tint = tint:Lerp(HQ.leafLight, 0.2)
	local shade, light = tint:Lerp(Color3.new(0, 0, 0), 0.16), tint:Lerp(HQ.leafLight, 0.55)
	-- { x, y, z, diameter, colour }: five broad masses form the crown.
	local lobes = {
		{ 0, 8.7, 0, 8.4, tint },
		{ -3.4, 7.4, 0.8, 5.6, shade }, { 3.2, 7.6, -1, 5.9, shade }, { 0.6, 7.2, 3.6, 5.4, tint },
		{ 0.2, 11.6, 0.2, 5.2, light },
	}
	for index, c in ipairs(lobes) do
		local crown = Kit.blob(tree, "TreeCrown", Vector3.new(c[4], c[4] * 0.86, c[4]) * scale, CFrame.new(base + Vector3.new(c[1], c[2], c[3]) * scale), c[5], Enum.Material.Grass)
		if index == 1 then crown.CastShadow = true end
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
		local frond = i % 2 == 0 and HQ.leaf or HQ.leafLight
		-- A single tapered frond has a more intentional silhouette than two
		-- overlapping pills and halves the foliage geometry on distant shores.
		local right = Vector3.new(-out.Z, 0, out.X)
		Kit.triangle(palm, "PalmFrond", top, (out * 7.8 - Vector3.new(0, 2.6, 0)) * scale, right * 2.1 * scale, 0.28 * scale, frond, Enum.Material.Grass)
	end
	Kit.blob(palm, "Coconut", Vector3.new(1.3, 1.3, 1.3) * scale, CFrame.new(top - Vector3.new(0, 0.9 * scale, 0)), Color3.fromRGB(110, 76, 44))
	return palm
end
function Kit.bush(parent, pos, size, tint)
	size, tint = size or 3, (tint or HQ.leaf):Lerp(HQ.leafLight, 0.15)
	local shade, light = tint:Lerp(Color3.new(0, 0, 0), 0.16), tint:Lerp(HQ.leafLight, 0.5)
	-- Three broad clumps read cleanly and leave geometry budget for landmarks.
	for _, c in ipairs({ { 0, 0.3, 0, 1, tint }, { 0.45, 0.3, 0.2, 0.8, light }, { -0.42, 0.25, -0.2, 0.78, shade } }) do
		Kit.blob(parent, "Bush", Vector3.new(size * c[4], size * c[4] * 0.8, size * c[4]), CFrame.new(pos + Vector3.new(c[1] * size, c[2] * size, c[3] * size)), c[5], Enum.Material.Grass)
	end
	-- One berry cluster reads better than a scatter of tiny beads and leaves
	-- geometry for the foundations of the lobby's landmarks.
	for index = 1, 1 do
		local a = index * 2.3
		Kit.blob(parent, "BushBerry", Vector3.new(0.3, 0.3, 0.3) * math.max(1, size / 4), CFrame.new(pos + Vector3.new(math.cos(a) * size * 0.5, size * 0.5, math.sin(a) * size * 0.5)), Color3.fromRGB(236, 84, 96))
	end
end
-- Flower beds: a low stone border, dark soil, a few leaf tufts and flowers with
-- real stems, a yellow heart and a flat ring of petals.
function Kit.flowers(parent, pos, colors)
	local stone = HQ.stoneDark
	for _, side in ipairs({ -1, 1 }) do
		Kit.block(parent, "BedBorder", Vector3.new(4.6, 0.7, 0.55), CFrame.new(pos + Vector3.new(0, 0.35, side * 1.7)), stone, Enum.Material.Slate, true)
		Kit.block(parent, "BedBorder", Vector3.new(0.55, 0.7, 3.4), CFrame.new(pos + Vector3.new(side * 2.0, 0.35, 0)), stone, Enum.Material.Slate, true)
	end
	Kit.block(parent, "BedSoil", Vector3.new(3.8, 0.5, 2.8), CFrame.new(pos + Vector3.new(0, 0.3, 0)), Color3.fromRGB(78, 56, 40), Enum.Material.Ground)
	for index = 1, 3 do
		local a = index * 2.1
		Kit.blob(parent, "BedTuft", Vector3.new(1.3, 0.9, 1.3), CFrame.new(pos + Vector3.new(math.cos(a) * 1.2, 0.8, math.sin(a) * 0.8)), HQ.leaf:Lerp(HQ.leafLight, 0.3), Enum.Material.Grass)
	end
	-- Four separated blooms read as flowers rather than a packed bead cluster.
	for index = 1, 4 do
		local a = index * math.pi / 2 + 0.3
		local at = pos + Vector3.new(math.cos(a) * 1.3, 0, math.sin(a) * 0.85)
		local height = 1.5 + (index % 3) * 0.45
		Kit.column(parent, "BlossomStem", at + Vector3.new(0, 0.5, 0), height - 0.5, 0.14, HQ.leaf:Lerp(Color3.new(0, 0, 0), 0.25), Enum.Material.SmoothPlastic)
		local top = at + Vector3.new(0, height, 0)
		Kit.disc(parent, "BlossomPetals", top, 1.15, 0.12, colors[index % #colors + 1], Enum.Material.SmoothPlastic)
		Kit.blob(parent, "BlossomHeart", Vector3.new(0.5, 0.4, 0.5), CFrame.new(top + Vector3.new(0, 0.1, 0)), Color3.fromRGB(255, 214, 72))
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
function Kit.stairs(parent, edge, outward, width, topY, bottomY, steps, skipNose)
	local rise, run = (topY - bottomY) / (steps + 1), 2.2
	local flat = Vector3.new(edge.X, 0, edge.Z)
	for i = 1, steps do
		local top = topY - rise * i
		local foot = bottomY - 0.6
		local mid = flat + outward * (run * (i - 0.5))
		local center = mid + Vector3.new(0, (top + foot) / 2, 0)
		Kit.block(parent, "Step", Vector3.new(width, top - foot, run), CFrame.lookAt(center, center + outward), HQ.stone, Enum.Material.Pavement, true)
		if not skipNose then
			local nose = mid + outward * (run / 2 - 0.25) + Vector3.new(0, top + 0.04, 0)
			Kit.block(parent, "StepNose", Vector3.new(width - 0.8, 0.08, 0.3), CFrame.lookAt(nose, nose + outward), HQ.cyan, Enum.Material.Neon)
		end
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

-- Desk emblems: a small coat of arms drawn from parts and floating over a
-- service desk (never text, never an emoji). `frame` is the emblem's own
-- frame: +Z looks at the plaza, +Y is up; it fits a circle of about 5.4 studs.
-- Every part bobs together (Kit.animate), so it reads as one object.
function Kit.emblem(parent, kind, frame, tint)
	local V = Vector3.new
	local model = Instance.new("Model")
	model.Name, model.Parent = "DeskEmblem_" .. tostring(kind), parent
	local gold, ink, white = HQ.gold, HQ.navy, HQ.trim
	local glowTint = tint:Lerp(white, 0.2)
	local function bob(part) Kit.animate(part, 0, 0.35) return part end
	local function box(name, size, offset, color, material, roll)
		return bob(Kit.block(model, name, size, frame * CFrame.new(offset) * CFrame.Angles(0, 0, roll or 0), color, material or Enum.Material.SmoothPlastic))
	end
	local function ring(name, offset, diameter, thickness, color, material)
		local made = bob(Kit.block(model, name, V(thickness, diameter, diameter), frame * CFrame.new(offset) * CFrame.Angles(0, math.pi / 2, 0), color, material or Enum.Material.SmoothPlastic))
		made.Shape = Enum.PartType.Cylinder
		return made
	end
	local function ball(name, offset, size, color, material)
		return bob(Kit.blob(model, name, size, frame * CFrame.new(offset), color, material or Enum.Material.SmoothPlastic))
	end
	local function link(name, a, b, width, color, material)
		return bob(Kit.beam(model, name, frame * a, frame * b, width, 0.2, color, material or Enum.Material.SmoothPlastic))
	end
	local function toWorld(v) return frame * v - frame.Position end
	local function wedge(name, corner, span, chord, color)
		return bob(Kit.triangle(model, name, frame * corner, toWorld(span), toWorld(chord), 0.3, color, Enum.Material.Metal))
	end
	-- The medal every emblem sits on: a dark field, a gold rim, a glowing edge.
	ring("EmblemBack", V(0, 0, -0.2), 5.2, 0.3, ink, Enum.Material.Metal)
	ring("EmblemRim", V(0, 0, 0), 5.5, 0.2, gold, Enum.Material.Metal)
	ring("EmblemField", V(0, 0, 0.08), 4.9, 0.12, ink, Enum.Material.SmoothPlastic)
	ring("EmblemGlow", V(0, 0, 0.16), 4.6, 0.06, glowTint, Enum.Material.Neon)
	ring("EmblemInner", V(0, 0, 0.2), 4.3, 0.1, ink, Enum.Material.SmoothPlastic)
	local z = 0.36
	if kind == "maps" then
		-- A compass rose: long blades north-south and east-west, short ones between.
		box("CompassNS", V(0.55, 3.7, 0.2), V(0, 0, z), white, Enum.Material.Metal)
		box("CompassEW", V(3.7, 0.55, 0.2), V(0, 0, z + 0.02), white, Enum.Material.Metal)
		-- Compass markers removed to stay within the 4,500-part lobby budget
		-- after M22.7 hero refinements; cardinal orientation is preserved by
		-- district signs and portal placements around the plaza.
		ring("CompassHub", V(0, 0, z + 0.1), 1.0, 0.14, gold, Enum.Material.Metal)
		ball("CompassNorth", V(0, 1.75, z + 0.1), V(0.5, 0.5, 0.3), gold, Enum.Material.Metal)
	elseif kind == "inventory" then
		-- A squad: three heads and shoulders, the leader in front and bigger.
		for _, spec in ipairs({ { -1.35, -0.45, 0.8, tint }, { 1.35, -0.45, 0.8, tint }, { 0, -0.2, 1.1, white } }) do
			local x, y, k, color = spec[1], spec[2], spec[3], spec[4]
			ball("SquadHead", V(x, y + 1.1 * k, z), V(0.85, 0.85, 0.5) * k, color, Enum.Material.SmoothPlastic)
			ball("SquadBody", V(x, y - 0.1 * k, z), V(1.5, 1.35, 0.5) * k, color:Lerp(ink, 0.15), Enum.Material.SmoothPlastic)
		end
		box("SquadBand", V(2.6, 0.18, 0.12), V(0, -1.45, z + 0.12), gold, Enum.Material.Metal)
	elseif kind == "bases" then
		-- A shield with a star: a block and two triangles that meet in a point.
		box("ShieldTop", V(3.0, 2.0, 0.28), V(0, 0.75, z), white, Enum.Material.Metal)
		wedge("ShieldLeft", V(0, -0.25, z - 0.14), V(-1.5, 0, 0), V(0, -2.1, 0), white)
		wedge("ShieldRight", V(0, -0.25, z - 0.14), V(1.5, 0, 0), V(0, -2.1, 0), white)
		box("ShieldField", V(2.4, 1.5, 0.12), V(0, 0.75, z + 0.18), tint, Enum.Material.SmoothPlastic)
		Kit.star(model, "ShieldStar", frame * V(0, 0.6, z + 0.3), frame.RightVector, frame.UpVector, 0.95, gold, Enum.Material.Metal, 0.12)
	elseif kind == "talents" then
		-- A talent tree: nodes joined by lines, the root in gold.
		local nodes = { V(0, 1.45, z), V(-1.3, 0.25, z), V(1.3, 0.25, z), V(-1.3, -1.25, z), V(0, -1.25, z), V(1.3, -1.25, z) }
		for _, edge in ipairs({ { 1, 2 }, { 1, 3 }, { 2, 4 }, { 2, 5 }, { 3, 5 }, { 3, 6 } }) do
			link("TalentLine", nodes[edge[1]], nodes[edge[2]], 0.14, glowTint, Enum.Material.Neon)
		end
		for index, at in ipairs(nodes) do
			ring("TalentNode", at + V(0, 0, 0.1), index == 1 and 1.1 or 0.85, 0.2, index == 1 and gold or white, Enum.Material.Metal)
			ring("TalentCore", at + V(0, 0, 0.2), index == 1 and 0.5 or 0.38, 0.12, index == 1 and white or tint, Enum.Material.Neon)
		end
	elseif kind == "quests" then
		-- A clipboard with three lines and a check.
		box("QuestBoard", V(2.7, 3.7, 0.22), V(0, -0.1, z), white, Enum.Material.SmoothPlastic)
		box("QuestClip", V(1.2, 0.5, 0.3), V(0, 1.85, z + 0.05), gold, Enum.Material.Metal)
		for index = 0, 2 do
			box("QuestLine", V(1.55 - index * 0.2, 0.2, 0.1), V(0.2, 0.85 - index * 0.62, z + 0.15), tint, Enum.Material.SmoothPlastic)
			ball("QuestDot", V(-0.95, 0.85 - index * 0.62, z + 0.16), V(0.28, 0.28, 0.12), gold, Enum.Material.Metal)
		end
		box("QuestCheckShort", V(0.2, 0.7, 0.12), V(-0.55, -1.2, z + 0.2), glowTint, Enum.Material.Neon, math.pi / 4)
		box("QuestCheckLong", V(0.2, 1.3, 0.12), V(0.05, -1.05, z + 0.2), glowTint, Enum.Material.Neon, -math.pi / 4)
	elseif kind == "leaderboard" then
		-- A podium of three steps under a gold star.
		box("PodiumFirst", V(1.25, 2.3, 0.5), V(0, -0.65, z), white, Enum.Material.SmoothPlastic)
		box("PodiumSecond", V(1.25, 1.6, 0.5), V(-1.35, -1.0, z), tint, Enum.Material.SmoothPlastic)
		box("PodiumThird", V(1.25, 1.1, 0.5), V(1.35, -1.25, z), tint:Lerp(ink, 0.25), Enum.Material.SmoothPlastic)
		Kit.star(model, "PodiumStar", frame * V(0, 1.15, z + 0.1), frame.RightVector, frame.UpVector, 0.95, gold, Enum.Material.Metal, 0.14)
		for index, x in ipairs({ -1.35, 0, 1.35 }) do
			box("PodiumRank", V(0.3, 0.3, 0.12), V(x, index == 2 and 0.2 or (index == 1 and -0.45 or -0.85), z + 0.28), gold, Enum.Material.Metal, math.pi / 4)
		end
	else
		Kit.star(model, "EmblemStar", frame * V(0, 0, z + 0.1), frame.RightVector, frame.UpVector, 1.7, gold, Enum.Material.Metal, 0.16)
	end
	for _, item in ipairs(model:GetDescendants()) do
		if item:IsA("BasePart") then
			item.CastShadow = false
			-- Include compound stars: their triangles are not made by bob().
			Kit.animate(item, 0, 0.35)
		end
	end
	return model
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
		Kit.block(model, "SignRim", Vector3.new(width + 1.6, 0.45, 0.4), cf * CFrame.new(0, side * (height / 2 + 0.55), -0.1), accent, not spec.premium and side == -1 and Enum.Material.Neon or Enum.Material.Metal)
		Kit.block(model, "SignRim", Vector3.new(0.45, height + 1.6, 0.4), cf * CFrame.new(side * (width / 2 + 0.55), 0, -0.1), accent, Enum.Material.Metal)
		Kit.blob(model, "SignStud", Vector3.new(1.3, 1.3, 0.8), cf * CFrame.new(side * (width / 2 + 0.55), height / 2 + 0.55, -0.2), HQ.gold, Enum.Material.Metal)
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
	-- Rounded corners: a sign reads as a screen, not a slab.
	local sky = frame2d(gui, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), HQ.white, UDim.new(0, 30))
	sky.Name, sky.ClipsDescendants = "Sky", true
	gradient(sky, spec.premium and HQ.steel or spec.top or Color3.fromRGB(70, 170, 255), spec.premium and HQ.navy or spec.bottom or Color3.fromRGB(34, 60, 150))
	-- Sunburst rays from behind the title.
	for i = 0, spec.premium and -1 or 5 do
		box(sky, 0.5, 0.45, 0.07, 2.4, HQ.white, i * 30, nil, 0.88)
	end
	local artHost = frame2d(sky, UDim2.fromScale(spec.artX or 0.5, spec.artY or 0.52), UDim2.fromScale(spec.artW or 0.36, spec.artH or 0.84), HQ.white, nil, 0, 1)
	artHost.Name = "Illustration"
	if not spec.premium and spec.art and SignArt[spec.art] then SignArt[spec.art](artHost, accent) end
	for i = 1, spec.premium and 0 or 4 do SignArt.sparkle(sky, 0.06 + i * 0.2, 0.12 + (i % 2) * 0.72, 0.05, HQ.white) end
	local title = Instance.new("TextLabel")
	title.Name, title.BackgroundTransparency, title.Font, title.TextScaled = "Title", 1, Enum.Font.FredokaOne, true
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(spec.premium and 0.5 or spec.titleX or 0.5, spec.premium and (spec.subtitle and 0.36 or 0.5) or spec.titleY or 0.42)
	title.Size = UDim2.fromScale(spec.premium and 0.94 or spec.titleW or 0.9, spec.premium and (spec.subtitle and 0.5 or 0.7) or spec.titleH or 0.46)
	title.TextColor3, title.Text, title.Parent = HQ.white, spec.title[1], sky
	title:SetAttribute("LobbyTextPT", spec.title[1]); title:SetAttribute("LobbyTextEN", spec.title[2])
	gradient(title, HQ.white, Color3.fromRGB(255, 226, 120))
	stroke(title, HQ.ink, math.max(4, height * 0.5))
	if spec.subtitle then
		local ribbon = box(sky, spec.premium and 0.5 or spec.titleX or 0.5, 0.84, spec.premium and 0.94 or 0.72, 0.2, accent, 0, 0.5)
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
	text.Name, text.BackgroundTransparency, text.Size, text.Font, text.TextScaled = "Text", 1, UDim2.fromScale(1, 1), Enum.Font.FredokaOne, true
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
		{ id = "maps", angle = 150, pt = "MAPAS", en = "MAPS", color = Color3.fromRGB(110, 220, 170) },
		{ id = "inventory", angle = 210, pt = "EQUIPE", en = "TEAM", color = Color3.fromRGB(255, 150, 110) },
		{ id = "bases", angle = 240, pt = "BASES", en = "BASES", color = Color3.fromRGB(150, 215, 140) },
		{ id = "talents", angle = 300, pt = "EVOLUÇÃO", en = "TALENTS", color = Color3.fromRGB(200, 160, 255) },
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
	lighting.ClockTime, lighting.Brightness = 14.3, 2.3
	lighting.ExposureCompensation = -0.15
	lighting.Ambient, lighting.OutdoorAmbient = Color3.fromRGB(96, 104, 126), Color3.fromRGB(132, 140, 158)
	lighting.FogColor, lighting.FogStart, lighting.FogEnd = Color3.fromRGB(176, 214, 245), 700, 2600
	local atmos = ensureLightingEffect(lighting, "Atmosphere", "Atmosphere")
	atmos.Density, atmos.Offset, atmos.Color, atmos.Decay, atmos.Glare, atmos.Haze = 0.28, 0.2, Color3.fromRGB(199, 226, 255), Color3.fromRGB(104, 150, 206), 0.25, 1.3
	local bloom = ensureLightingEffect(lighting, "BloomEffect", "Bloom")
	bloom.Intensity, bloom.Size, bloom.Threshold = 0.16, 18, 1.5
	local grade = ensureLightingEffect(lighting, "ColorCorrectionEffect", "ColorGrade")
	grade.TintColor, grade.Contrast, grade.Saturation, grade.Brightness = Color3.fromRGB(255, 251, 244), 0.06, 0.1, 0
	local rays = ensureLightingEffect(lighting, "SunRaysEffect", "SunRays")
	rays.Intensity, rays.Spread = 0.02, 0.5
	local dof = ensureLightingEffect(lighting, "DepthOfFieldEffect", "DOF")
	dof.FarIntensity, dof.NearIntensity, dof.FocusDistance, dof.InFocusRadius = 0, 0, 100, 200
	lighting.EnvironmentDiffuseScale, lighting.EnvironmentSpecularScale = 0.7, 0.7
	lighting.GlobalShadows, lighting.ShadowSoftness = true, 0.2
	-- The sea, the island's own terrain colours and the sky; a chapter may
	-- have recoloured all of them, so they are put back here too.
	local terrain = workspace.Terrain
	terrain.WaterColor, terrain.WaterTransparency, terrain.WaterReflectance = Color3.fromRGB(26, 137, 184), 0.35, 0.22
	terrain.WaterWaveSize, terrain.WaterWaveSpeed = 0.18, 9
	terrain:SetMaterialColor(Enum.Material.Grass, Color3.fromRGB(106, 178, 74))
	terrain:SetMaterialColor(Enum.Material.Sand, Color3.fromRGB(240, 220, 168))
	terrain:SetMaterialColor(Enum.Material.Rock, Color3.fromRGB(136, 140, 150))
	terrain:SetMaterialColor(Enum.Material.Pavement, Color3.fromRGB(150, 156, 170))
	local clouds = terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover, clouds.Density, clouds.Color = 0.55, 0.62, Color3.fromRGB(255, 255, 255)
	clouds.Parent = terrain
end

-- options.lobby = false (a battle server): the bay and an arrival deck, no lobby.
function World.new(catalog, openPanel, config, options)
	upper = catalog.Upper or string.upper
	campaignWaves = catalog.CampaignWaves or {}
	local self = setmetatable({ catalog = catalog, openPanel = openPanel, mapImages = config and config.MapImages or {} }, World)
	-- The armour's own block and finish, once uploaded (0 keeps the classic chamfer).
	local art = config and config.Art
	ARMOUR_ART.mesh, ARMOUR_ART.texture = art and art.armorMesh or 0, art and art.armorTexture or 0
	ARMOUR_ART.padMesh, ARMOUR_ART.padTexture, ARMOUR_ART.filigree = art and art.padMesh or 0, art and art.padTexture or 0, art and art.filigree or 0
	ARMOUR_ART.galaxy, ARMOUR_ART.flames, ARMOUR_ART.runes = art and art.galaxy or 0, art and art.flames or 0, art and art.runes or 0
	for _, key in ipairs({ "web", "scales", "circuit", "tiger" }) do ARMOUR_ART[key] = art and art[key] or 0 end
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
	if type(options) == "table" and options.lobby == false then
		self:BuildArrival()
	else
		self:BuildLobby()
	end
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
-- `bare` (a photograph covers the sign) keeps the frame and its camera but
-- builds no scene: hidden parts would only cost the lobby's budget.
local function mapVignette(parent,map,tint,bare)
	local viewport=Instance.new("ViewportFrame")
	viewport.Name,viewport.Size,viewport.BackgroundColor3="MapPicture",UDim2.fromScale(1,0.75),Color3.fromRGB(116,193,225)
	viewport.BorderSizePixel=0; viewport.Ambient=Color3.fromRGB(190,190,190)
	viewport.LightColor,viewport.LightDirection=Color3.fromRGB(255,240,211),Vector3.new(-1,-1,-0.5)
	viewport.Parent=parent
	local scene=Instance.new("WorldModel"); scene.Name="MapScene"; scene.Parent=viewport
	local function bindCamera()
		local camera=Instance.new("Camera"); camera.Name="PictureCamera"
		camera.CFrame=CFrame.lookAt(Vector3.new(100,120,140),Vector3.new(0,7,0)); camera.FieldOfView=40
		viewport:SetAttribute("PictureCFrame",camera.CFrame)
		viewport:SetAttribute("PictureFieldOfView",camera.FieldOfView)
		camera.Parent=viewport; viewport.CurrentCamera=camera
	end
	if bare then bindCamera(); return end
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
	bindCamera()
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
		-- Behind the board: their tops crossed its lower corners, over the text.
		part(model,"SignPillar",Vector3.new(1.4,17,1.6),at(side*14.6,8.5,-5.9),HQ.navy,Enum.Material.Metal).CastShadow=true
		artPart(model,"SignLight",Vector3.new(0.3,14,0.2),at(side*14.6,9,-5.0),tint,Enum.Material.Neon)
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
	-- A photograph of the real map, once imported and configured
	-- (Config.MapImages), covers the rendered diorama.
	local photographed=(tonumber(photo) or 0)>0
	mapVignette(surface,map,tint,photographed)
	if photographed then
		local image=Instance.new("ImageLabel")
		image.Name,image.Size,image.BackgroundTransparency,image.ZIndex="MapPhoto",UDim2.fromScale(1,0.75),1,0
		image.Image,image.ScaleType="rbxassetid://"..tostring(math.floor(photo)),Enum.ScaleType.Crop
		image.Parent=surface
		surface.MapPicture.Visible=false
	end
	local title=stationText(surface,"MapTitle",map.name.pt,map.name.en,UDim2.fromScale(0.02,0.24),UDim2.fromScale(0.96,0.35),Color3.new(1,1,1),64)
	title.Font,title.TextStrokeTransparency=Enum.Font.FredokaOne,0
	local waves=destination.modeId=="normal" and campaignWaves[map.id] or mode.waves
	local suffix=waves==0 and "INFINITO" or tostring(waves).." ONDAS"
	local suffixEN=waves==0 and "ENDLESS" or tostring(waves).." WAVES"
	stationText(surface,"MapRules",upper(mode.name.pt).."  •  "..suffix,upper(mode.name.en).."  •  "..suffixEN,UDim2.fromScale(0.02,0.75),UDim2.fromScale(0.96,0.13),tint,25)
	stationText(surface,"MapCapacity","3 FILAS  •  ATÉ 4 JOGADORES CADA","3 QUEUES  •  UP TO 4 PLAYERS EACH",UDim2.fromScale(0.02,0.89),UDim2.fromScale(0.96,0.1),ART.pearl,18)
	local zones={}
	for slot=1,3 do
		local dx=(slot-2)*10.2
		-- The pad: a round landing ring in the destination's colour around a dark
		-- core, with chevrons pointing into the door, so it reads "step in here".
		local pad=part(model,slot==1 and "Pad" or "Pad"..slot,Vector3.new(0.18,8.4,8.4),at(dx,0.58,0.4)*CFrame.Angles(0,0,math.pi/2),tint,Enum.Material.Neon)
		pad.Shape=Enum.PartType.Cylinder
		pad.Transparency=0.3; pad.CanCollide=false
		local padFrame=artPart(model,"PadFrame",Vector3.new(0.2,9.6,9.6),at(dx,0.5,0.4)*CFrame.Angles(0,0,math.pi/2),HQ.trim,Enum.Material.SmoothPlastic)
		padFrame.Shape=Enum.PartType.Cylinder
		local padCore=artPart(model,"PadCore",Vector3.new(0.24,6.8,6.8),at(dx,0.6,0.4)*CFrame.Angles(0,0,math.pi/2),HQ.navy,Enum.Material.SmoothPlastic)
		padCore.Shape=Enum.PartType.Cylinder
		-- One big chevron (the lobby keeps a part budget for phones).
		local lean=math.rad(40)
		for _,side in ipairs({-1,1}) do
			artPart(model,"PadArrow",Vector3.new(0.42,0.08,2.6),at(dx+side*math.sin(lean)*1.3,0.74,-0.9+math.cos(lean)*1.3)*CFrame.Angles(0,side*lean,0),tint,Enum.Material.Neon)
		end
		local queueId=slot==1 and portalId or portalId..":"..slot
		pad:SetAttribute("QueueId",queueId)
		for _,side in ipairs({-1,1}) do
			artPart(model,"QueueRail",Vector3.new(0.35,1.6,8.7),at(dx+side*4.9,1.3,0.4),HQ.steel,Enum.Material.Metal)
			-- Two pillars hold the round door and the queue sign above it.
			artPart(model,"QueueGate",Vector3.new(0.7,10.4,0.8),at(dx+side*4.55,5.6,-3.8),HQ.navy,Enum.Material.Metal)
		end
		-- The door: a thick round frame, a coloured rim, and inside it a deep,
		-- dark well with a galaxy of light turning in it (PortalSwirl, turned by
		-- the client). No particles: the lobby keeps emitters to a handful.
		local door=at(dx,4.7,-3.8)*CFrame.Angles(0,math.pi/2,0)
		local frame=artPart(model,"PortalFrame",Vector3.new(0.9,7.7,7.7),door,HQ.navy,Enum.Material.Metal)
		frame.Shape=Enum.PartType.Cylinder
		frame.CastShadow=true
		-- Two mounting bolts leave the silhouette of the ring clear.
		for stud=0,1 do
			local angle=stud*math.pi+math.pi/4
			Kit.blob(model,"PortalStud",Vector3.new(0.5,0.5,0.5),at(dx+math.cos(angle)*3.55,4.7+math.sin(angle)*3.55,-3.32),HQ.gold,Enum.Material.Metal)
		end
		local rim=artPart(model,"PortalRim",Vector3.new(0.96,6.9,6.9),door,tint,Enum.Material.Neon)
		rim.Shape=Enum.PartType.Cylinder
		-- Deep space with a hint of the destination colour: never brown or grey.
		local well=Color3.fromRGB(16,12,38):Lerp(tint,0.18)
		local membrane=artPart(model,"PortalMembrane",Vector3.new(1.02,6.3,6.3),door,well,Enum.Material.SmoothPlastic)
		membrane.Shape=Enum.PartType.Cylinder
		local pane=artPart(model,"PortalPane",Vector3.new(6.3,6.3,0.05),at(dx,4.7,-3.25),tint,Enum.Material.SmoothPlastic)
		pane.Transparency=1
		local gui=Instance.new("SurfaceGui")
		gui.Name,gui.Face,gui.LightInfluence,gui.CanvasSize="PortalSwirl",Enum.NormalId.Back,0,Vector2.new(256,256)
		gui.SizingMode,gui.Parent=Enum.SurfaceGuiSizingMode.FixedSize,pane
		-- Depth: rings of the well, each a shade lighter towards the middle.
		for layer=1,4 do
			local scale=1-layer*0.17
			circle(gui,0.5,0.5,scale,scale,well:Lerp(tint,layer*0.09),0.1).Name="WellLayer"
		end
		-- Two layers that turn against each other: three curved arms of light
		-- (the galaxy) and broken outer arcs.
		local swirl=frame2d(gui,UDim2.fromScale(0.5,0.5),UDim2.fromScale(1,1),tint,UDim.new(0.5,0),0,1)
		swirl.Name="Swirl"
		-- Each arm is a chain of short rounded strokes laid along a spiral, so it
		-- reads as one curved swoosh that narrows and brightens into the centre.
		local steps,turn,reach,shrink=14,math.rad(300),0.46,0.84
		for arm=0,2 do
			for step=1,steps do
				local t=(step-0.5)/steps
				local angle=math.rad(arm*120)+t*turn
				local radius=reach*(1-t*shrink)
				local dr,dtheta=-reach*shrink,turn
				local tx=dr*math.cos(angle)-radius*math.sin(angle)*dtheta
				local ty=dr*math.sin(angle)+radius*math.cos(angle)*dtheta
				local length=math.sqrt(tx*tx+ty*ty)/steps*1.35
				local width=0.075*(1-t*0.55)
				local bar=frame2d(swirl,UDim2.fromScale(0.5+math.cos(angle)*radius,0.5+math.sin(angle)*radius),UDim2.fromScale(length,width),
					tint:Lerp(HQ.white,0.2+t*0.7),UDim.new(0.5,0),math.deg(math.atan2(ty,tx)),0.05+(1-t)*0.3)
				bar.Name="SwirlArm"
			end
		end
		local outer=frame2d(gui,UDim2.fromScale(0.5,0.5),UDim2.fromScale(1,1),tint,UDim.new(0.5,0),0,1)
		outer.Name="SwirlOuter"
		for index=1,3 do
			local ring=circle(outer,0.5,0.5,1.02-index*0.12,1.02-index*0.12,tint,1)
			local line=stroke(ring,tint:Lerp(HQ.white,0.25+index*0.12),7-index)
			-- A fading arc, not a closed ring: it reads as motion when it turns.
			local fade=Instance.new("UIGradient")
			fade.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.45,0.05),NumberSequenceKeypoint.new(0.55,1),NumberSequenceKeypoint.new(1,1)})
			fade.Rotation=index*110
			fade.Parent=line
		end
		local glow=circle(gui,0.5,0.5,0.36,0.36,tint:Lerp(HQ.white,0.5),0.7)
		glow.Name="SwirlGlow"
		local core=circle(gui,0.5,0.5,0.22,0.22,HQ.white,0.15)
		core.Name="SwirlCore"
		local sign=part(model,"QueueSign"..slot,Vector3.new(8.3,2.5,0.25),at(dx,10,-3.8)*CFrame.Angles(0,math.pi,0),HQ.ink)
		local gui=Instance.new("SurfaceGui"); gui.Name="QueueBoard"; gui.Face=Enum.NormalId.Front; gui.LightInfluence=0
		gui.CanvasSize=Vector2.new(290,94); gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize; gui.Parent=sign
		stationText(gui,"QueueTitle","FILA "..slot,"QUEUE "..slot,UDim2.fromScale(0,0),UDim2.fromScale(1,0.36),ART.pearl,20)
		local status=stationText(gui,"QueueStatus","0/4  •  ENTRE","0/4  •  STEP IN",UDim2.fromScale(0,0.36),UDim2.fromScale(1,0.62),tint,26)
		zones[queueId]={destinationId=portalId,slot=slot,center=at(dx,4,0.4).Position,
			size=Vector3.new(8.4,8,8.4),exit=at(dx,4,10).Position,pad=pad,label=status,tint=tint,membrane=membrane,core=core,well=well}
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
	local tint=HQ.gold
	local secondary=isBase and Color3.fromRGB(47,191,236) or Color3.fromRGB(157,78,236)
	local origin=CFrame.new(x,GROUND_Y,z)*CFrame.Angles(0,yaw or 0,0)
	local function at(dx,y,dz) return origin*CFrame.new(dx,y,dz) end
	local floor=part(model,"Plinth",Vector3.new(28,0.6,22),at(0,0.3,0),HQ.navy,Enum.Material.Metal)
	model.PrimaryPart=floor
	part(model,"BackWall",Vector3.new(28,16,1.2),at(0,8,-10.5),HQ.navy,Enum.Material.Metal).CastShadow=true
	for _,side in ipairs({-1,1}) do
		part(model,"HallWall",Vector3.new(1.2,16,22),at(side*13.4,8,0),HQ.steel,Enum.Material.Metal).CastShadow=true
		-- Deep round glazing breaks the broad side wall into recognisable bays.
		-- These are facade details; the solid wall still owns its collision.
		for _, dz in ipairs({-4,4}) do
			local frame = Kit.disc(model,"HallWindowFrame",at(side*14.18,8,dz).Position,6,0.25,HQ.gold,Enum.Material.Metal)
			frame.CFrame = at(side*14.18,8,dz)
			local pane = Kit.disc(model,"HallWindowGlass",at(side*14.38,8,dz).Position,4.8,0.18,secondary:Lerp(HQ.navy,0.6),Enum.Material.Glass)
			pane.CFrame, pane.Reflectance = at(side*14.38,8,dz), 0.18
		end
		-- Round towers frame the door, each with a dome: the hall reads as a
		-- castle of the summons, not a box.
		Kit.block(model,"HallPier",Vector3.new(4,15.4,4),at(side*9.6,7.7,10),HQ.navy,Enum.Material.Metal,true).CastShadow=true
		Kit.block(model,"HallPierFoot",Vector3.new(5.2,1.3,5.2),at(side*9.6,0.65,10),HQ.stoneWarm,Enum.Material.Slate,true)
		Kit.block(model,"HallCapital",Vector3.new(5.1,0.7,5.1),at(side*9.6,15.5,10),HQ.gold,Enum.Material.Metal)
		artPart(model,"SummonTrim",Vector3.new(0.25,12.5,0.2),at(side*9.6,7.5,12.15),HQ.gold,Enum.Material.Metal)
		artPart(model,"EnergyConduit",Vector3.new(0.15,8,0.15),at(side*6.2,6,10.8),secondary,Enum.Material.Neon)
		Kit.block(model,"HallBanner",Vector3.new(3.6,7.5,0.2),at(side*11.5,8,12.1),HQ.navy,Enum.Material.Fabric)
		for _, edge in ipairs({-1,1}) do artPart(model,"HallBannerEdge",Vector3.new(0.12,7.5,0.15),at(side*11.5+edge*1.8,8,12.3),HQ.gold,Enum.Material.Metal) end
		Kit.star(model,"HallBannerStar",at(side*11.5,8.6,12.35).Position,origin.RightVector,origin.UpVector,1.1,HQ.gold,Enum.Material.Metal,0.08)
	end
	part(model,"Roof",Vector3.new(29,1,23),at(0,16.5,0),HQ.navy,Enum.Material.Metal).CastShadow=true
	-- The roof's front edge is rolled, not cut square.
	local rolled=Kit.block(model,"RoofRoll",Vector3.new(19,1.3,1.3),at(0,16.5,11.3),HQ.gold,Enum.Material.Metal)
	rolled.Shape=Enum.PartType.Cylinder
	artPart(model,"RoofGlow",Vector3.new(29.3,0.3,23.3),at(0,15.9,0),HQ.gold,Enum.Material.Metal)
	-- Sloping eaves give each hall a roof silhouette instead of a flat box.
	-- (The front gable stands behind the header sign: owner, 16/10, nothing may
	-- cross a sign's letters. The sign's back reaches z = 8.)
	for _, side in ipairs({-1,1}) do
		local span = origin*Vector3.new(0,3.5,0)-origin.Position
		local chord = origin*Vector3.new(side*14.5,0,0)-origin.Position
		Kit.triangle(model,"HallEave",at(0,17,-10).Position,span,chord,0.5,HQ.navy,Enum.Material.Metal)
		Kit.triangle(model,"HallEave",at(0,17,7.5).Position,span,chord,0.5,HQ.navy,Enum.Material.Metal)
	end
	part(model,"EntranceLintel",Vector3.new(13,2,1.4),at(0,15,10),HQ.gold,Enum.Material.Metal)
	for _,side in ipairs({-1,1}) do
		Kit.beam(model,"HallPediment",at(side*7,15.2,10.8).Position,at(side*5,17.2,10.8).Position,0.8,1.2,HQ.gold,Enum.Material.Metal)
		-- The header's supports hold it from behind (they used to cross its letters).
		Kit.block(model,"HallHeaderSupport",Vector3.new(1,4.2,1),at(side*7,18.5,7.6),HQ.gold,Enum.Material.Metal)
	end
	Kit.sign(model,"SummonHeader",at(0,21.2,9.6)*CFrame.Angles(0,math.pi,0),22,6.4,{
		title=isBase and {"INVOCAR BASES","SUMMON BASES"} or {"INVOCAR HERÓIS","SUMMON HEROES"},
		top=isBase and Color3.fromRGB(110,230,170) or Color3.fromRGB(255,200,90),
		bottom=isBase and Color3.fromRGB(30,110,120) or Color3.fromRGB(190,70,150),
		accent=tint,premium=true,titleX=0.5,titleW=0.94,titleY=0.5,titleH=0.66,
	})
	local reactor=artPart(model,"SummonCore",Vector3.new(0.8,11,11),at(0,6,-8.6)*CFrame.Angles(0,math.pi/2,0),HQ.gold,Enum.Material.Metal)
	reactor.Shape=Enum.PartType.Cylinder
	local well=artPart(model,"SummonWell",Vector3.new(0.9,10.2,10.2),at(0,6,-8.45)*CFrame.Angles(0,math.pi/2,0),HQ.navy,Enum.Material.SmoothPlastic)
	well.Shape=Enum.PartType.Cylinder
	local pane=artPart(model,"SummonPortalPane",Vector3.new(10.1,10.1,0.04),at(0,6,-7.95),secondary)
	pane.Transparency=1
	local vortex=Instance.new("SurfaceGui")
	vortex.Name,vortex.Face,vortex.LightInfluence,vortex.CanvasSize,vortex.Parent="PortalSwirl",Enum.NormalId.Back,0,Vector2.new(384,384),pane
	local swirl=frame2d(vortex,UDim2.fromScale(0.5,0.5),UDim2.fromScale(1,1),secondary,UDim.new(0.5,0),0,1)
	swirl.Name="Swirl"
	for arm=0,2 do for step=1,12 do
		local t=(step-0.5)/12
		local a=arm*math.pi*2/3+t*math.pi*1.8
		local radius=0.46*(1-t*0.85)
		frame2d(swirl,UDim2.fromScale(0.5+math.cos(a)*radius,0.5+math.sin(a)*radius),UDim2.fromScale(0.13-t*0.06,0.055-t*0.025),secondary:Lerp(HQ.white,t*0.55),UDim.new(0.5,0),math.deg(a)+110,0.1)
	end end
	for layer=1,3 do
		local ring=circle(vortex,0.5,0.5,1-layer*0.07,1-layer*0.07,secondary,1)
		stroke(ring,secondary:Lerp(HQ.white,layer*0.08),4-layer)
	end
	circle(vortex,0.5,0.5,0.16,0.16,secondary:Lerp(HQ.white,0.6),0.1)
	for i=-1,1 do
		local column=artPart(model,"SummonColumn",Vector3.new(2.2,2.5+math.abs(i),2.2),at(i*4.2,1.85+math.abs(i)/2,-3),HQ.trim,Enum.Material.Metal)
		artPart(model,"SummonChip",Vector3.new(1.7,0.18,1.7),column.CFrame*CFrame.new(0,column.Size.Y/2+0.05,0),tint,Enum.Material.Neon)
	end
	-- The crest sits on the roof/header, replacing unsupported floating chests.
	-- It stands on the header's top rim, clear of the title.
	local crest=artPart(model,"HallCrest",Vector3.new(0.5,5.2,5.2),at(0,26.7,9.7)*CFrame.Angles(0,math.pi/2,0),HQ.navy,Enum.Material.Metal)
	crest.Shape=Enum.PartType.Cylinder
	Kit.star(model,"HallCrestStar",at(0,26.7,10.05).Position,origin.RightVector,origin.UpVector,1.9,HQ.gold,Enum.Material.Metal,0.1)
	Kit.light(reactor,secondary,20,0.6)
	artPart(model,"HallGlow",Vector3.new(24,0.4,0.3),at(0,13.5,-9.85),tint,Enum.Material.Neon)
	Kit.disc(model,"HallFloorRing",at(0,0.62,-3).Position,13,0.1,secondary,Enum.Material.Metal)
	Kit.disc(model,"HallFloorInset",at(0,0.7,-3).Position,11.8,0.06,HQ.navy,Enum.Material.Slate)
	local pad=artPart(model,"ShopEntryPad",Vector3.new(11,0.16,12),at(0,0.64,11.5),HQ.navy,Enum.Material.Slate)
	pad.CanCollide=false
	for i=1,2 do Kit.block(model,"HallEntranceStep",Vector3.new(12.8,0.22,1.6),at(0,0.11+(i-1)*0.22,19.1-(i-1)*1.6),HQ.stoneWarm,Enum.Material.Pavement,true) end
	for _,side in ipairs({-1,1}) do artPart(model,"ShopEntryBorder",Vector3.new(0.3,0.15,12),at(side*5.65,0.77,11.5),tint,Enum.Material.Neon) end
	local plaque=wallSign(model,"SummonDoorHint",at(0,11,10.9)*CFrame.Angles(0,math.pi,0),Vector3.new(10.4,1.6,0.15),"APROXIME-SE","ESCOLHA • INVOQUE • EQUIPE",ART.pearl)
	for _,node in ipairs(plaque:GetDescendants()) do
		if node:IsA("TextLabel") then
			node:SetAttribute("LobbyTextPT",node.Text)
			node:SetAttribute("LobbyTextEN",node.Name=="Title" and "STEP CLOSER" or "CHOOSE • SUMMON • EQUIP")
		end
	end
	local hallPrompt=interactable(pad,isBase and "Invocar bases" or "Invocar heróis",function(player)
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position-pad.Position).Magnitude<=14 then openPanel(player,"chests",{chestId=chestId}) end
	end,12)
	hallPrompt:SetAttribute("ObjectPT",isBase and "Invocar bases" or "Invocar heróis"); hallPrompt:SetAttribute("ObjectEN",isBase and "Summon bases" or "Summon heroes")
	hallPrompt:SetAttribute("ActionPT","Abrir"); hallPrompt:SetAttribute("ActionEN","Open")
	return model,{center=at(0,4,11.5).Position,size=Vector3.new(12,8,14),frame=at(0,4,11.5),
		purchaseCenter=at(0,4,3).Position,purchaseSize=Vector3.new(26,10,31),purchaseFrame=at(0,4,3),
		chestId=chestId,kind=isBase and "base" or "hero"}
end

-- The store as a physical kiosk row: powered drone rotors, a gold vault,
-- a training console and a VIP crest. No aisle of
-- buttons, one stand per product.
local function buildShopStand(lobby, x, z, shopKind, shopKey, displayName, openPanel, showcase, displayEN)
	local model = Instance.new("Model")
	model.Name, model.Parent = "Shop_" .. shopKey, lobby
	model:SetAttribute("Kind", "ShopStand")
	model:SetAttribute("ShopKind", shopKind)
	model:SetAttribute("ShopKey", shopKey)
	local y = GROUND_Y
	local V = Vector3.new
	local accents = { heroes = HQ.cyan, gold = HQ.gold, collector = Color3.fromRGB(118, 211, 183), training = Color3.fromRGB(172, 149, 239), vip = Color3.fromRGB(235, 173, 93) }
	local tint = accents[shopKey] or HQ.gold
	local stand = Kit.disc(model, "Stand", V(x,y+0.5,z), 7.4, 1, HQ.steel, Enum.Material.Metal, true)
	Kit.disc(model, "DisplayInset", V(x,y+1.04,z), 6.6, 0.12, HQ.navy, Enum.Material.Slate)
	Kit.disc(model, "StandRim", V(x,y+0.95,z), 7.6, 0.18, tint, Enum.Material.Metal)
	-- One sculpted backrest, rather than a box of oversized neon pillars.
	Kit.block(model, "ShowcaseBack", V(5.8, 5.6, 0.45), CFrame.new(x,y+3.7,z+2.7), HQ.navy, Enum.Material.Metal)
	for _,side in ipairs({-1,1}) do
		Kit.column(model, "ShowcasePillar", V(x+side*3,y+1,z+2.6), 5.3, 0.7, HQ.steel, Enum.Material.Metal)
	end
	Kit.block(model, "ShowcaseCanopy", V(6.7,0.4,2.6), CFrame.new(x,y+6.6,z+1.6), HQ.navy, Enum.Material.Metal)
	Kit.block(model, "DisplayLight", V(5.6,0.1,0.18), CFrame.new(x,y+6.35,z+0.4), HQ.lamp, Enum.Material.Neon)
	if shopKey == "heroes" and showcase then
		local frame = CFrame.new(x, y+3.4, z-0.3) * CFrame.Angles(0,0,-0.12)
		Kit.block(model, "RecruitCard", V(3.5,4.4,0.25), frame, HQ.trim, Enum.Material.Metal)
		Kit.block(model, "RecruitFace", V(3.1,4,0.12), frame*CFrame.new(0,0,-0.19), HQ.navy, Enum.Material.SmoothPlastic)
		Kit.star(model, "RecruitStar", frame*V(0,0.65,-0.3), frame.RightVector, frame.UpVector, 1.15, tint, Enum.Material.Metal, 0.12)
		for i=1,2 do Kit.block(model, "RecruitLine", V(2.1,0.14,0.1), frame*CFrame.new(0,-0.6-i*0.4,-0.28), HQ.trim, Enum.Material.Metal) end
	elseif shopKey == "collector" then
		-- A recognisable quadcopter: shell, camera, four motor pods and rotors.
		Kit.blob(model, "DroneShell", V(2.2,1.1,1.8), CFrame.new(x,y+3.4,z), HQ.trim, Enum.Material.Metal)
		Kit.block(model, "DroneCamera", V(0.6,0.6,0.3), CFrame.new(x,y+3.15,z-1), HQ.navy, Enum.Material.Metal)
		Kit.disc(model, "DroneLens", V(x,y+3.15,z-1.18), 0.35,0.14,tint,Enum.Material.Glass).CFrame=CFrame.new(x,y+3.15,z-1.18)*CFrame.Angles(0,math.pi/2,0)
		for _, sx in ipairs({-1,1}) do for _, sz in ipairs({-1,1}) do
			local motor = V(x+sx*1.7,y+3.5,z+sz*1.2)
			Kit.beam(model, "DroneArm", V(x,y+3.4,z),motor,0.22,0.25,HQ.steel,Enum.Material.Metal)
			Kit.column(model, "DroneMotor", motor-V(0,0.25,0),0.5,0.6,HQ.navy,Enum.Material.Metal)
			Kit.animate(Kit.block(model,"DroneRotor",V(1.3,0.08,0.22),CFrame.new(motor+V(0,0.3,0)),HQ.steel,Enum.Material.Metal),2.5,0)
		end end
		Kit.column(model,"DroneSupport",V(x,y+1.1,z),1.6,0.2,HQ.steel,Enum.Material.Metal)
	elseif shopKey == "vip" then
		Kit.disc(model,"VipShield",V(x,y+3.4,z),3.6,0.35,HQ.gold,Enum.Material.Metal).CFrame=CFrame.new(x,y+3.4,z)*CFrame.Angles(0,math.pi/2,0)
		Kit.disc(model,"VipField",V(x,y+3.4,z-0.2),2.9,0.12,HQ.navy,Enum.Material.SmoothPlastic).CFrame=CFrame.new(x,y+3.4,z-0.2)*CFrame.Angles(0,math.pi/2,0)
		Kit.star(model,"VipStar",V(x,y+3.4,z-0.35),V(1,0,0),V(0,1,0),1.1,HQ.gold,Enum.Material.Metal,0.13)
		for i=-1,1 do
			Kit.block(model,"VipCrown",V(0.35,0.6+(i==0 and 0.3 or 0),0.25),CFrame.new(x+i*0.65,y+5.25,z),HQ.gold,Enum.Material.Metal)
		end
	elseif shopKey == "gold" then
		Kit.block(model,"VaultBody",V(3.6,3,2.5),CFrame.new(x,y+2.6,z),HQ.steel,Enum.Material.Metal)
		Kit.block(model,"VaultDoor",V(3.25,2.65,0.18),CFrame.new(x,y+2.6,z-1.38)*CFrame.Angles(0,-0.25,0),HQ.navy,Enum.Material.DiamondPlate)
		Kit.disc(model,"VaultDial",V(x,y+2.65,z-1.6),1.1,0.2,HQ.gold,Enum.Material.Metal).CFrame=CFrame.new(x,y+2.65,z-1.6)*CFrame.Angles(0,math.pi/2,0)
		for i=1,5 do Kit.disc(model,"Coin",V(x+0.9,y+1.14+i*0.18,z-1.55),1.05,0.16,HQ.gold,Enum.Material.Metal) end
	else
		Kit.block(model,"TrainingConsole",V(3.8,1.3,2.4),CFrame.new(x,y+1.9,z),HQ.steel,Enum.Material.Metal)
		Kit.block(model,"TrainingScreen",V(3.3,1.9,0.18),CFrame.new(x,y+3.35,z+0.55)*CFrame.Angles(-0.12,0,0),HQ.ink,Enum.Material.SmoothPlastic)
		for i=1,3 do Kit.block(model,"TrainingBar",V(0.4,0.45+i*0.35,0.12),CFrame.new(x-1.25+i*0.62,y+3.1,z+0.4),tint,Enum.Material.Metal) end
	end
	-- A pass stand sells that pass (owner, 15/10): pressing E shows its card,
	-- with what it gives, and the Robux purchase opens at once (the server
	-- prompts it, init.server). The hero and Gold stands open their list.
	local offer = shopKind == "pass"
	-- The plaque stands clear of the ring road's light strips at its feet.
	local plaque = wallSign(model,"ProductPlaque",CFrame.new(x,y+1.2,z-3.7),V(6.6,1.3,0.15),displayName,offer and "COMPRAR" or "VER LOJA",tint)
	local nameTag = plaque:FindFirstChild("Title",true)
	nameTag:SetAttribute("LobbyTextPT",displayName); nameTag:SetAttribute("LobbyTextEN",displayEN or displayName)
	local hint=plaque:FindFirstChild("Subtitle",true)
	hint:SetAttribute("LobbyTextPT",offer and "COMPRAR" or "VER LOJA"); hint:SetAttribute("LobbyTextEN",offer and "BUY" or "VIEW SHOP")
	for _, p in ipairs(model:GetChildren()) do if p:IsA("BasePart") and p ~= stand then p.CanCollide = false end end
	model.PrimaryPart = stand
	local prompt = interactable(stand, displayName, function(player) openPanel(player, offer and "offer" or "shop", { shopKind = shopKind, shopKey = shopKey }) end)
	prompt:SetAttribute("ObjectPT", displayName); prompt:SetAttribute("ObjectEN", displayEN or displayName)
	prompt:SetAttribute("ActionPT", offer and "Comprar" or "Abrir"); prompt:SetAttribute("ActionEN", offer and "Buy" or "Open")
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
	surface.Name, surface.Face, surface.Parent = "Board", Enum.NormalId.Back, board
	surface.LightInfluence, surface.PixelsPerStud, surface.SizingMode = 0, 36, Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(480, 216)
	local bezel = Instance.new("Frame")
	bezel.Name, bezel.Size, bezel.BorderSizePixel, bezel.BackgroundColor3, bezel.Parent = "Bezel", UDim2.fromScale(1, 1), 0, HQ.navy, surface
	gradient(bezel, HQ.navy, HQ.ink)
	local outline = Instance.new("UIStroke")
	outline.Color, outline.Thickness, outline.Parent = HQ.gold, 3, bezel
	local text = Instance.new("TextLabel")
	text.Name, text.Position, text.Size, text.BackgroundTransparency = "Status", UDim2.fromOffset(16, 102), UDim2.new(1, -32, 0, 54), 1
	text.Font, text.TextColor3, text.TextSize = Enum.Font.BuilderSansMedium, Color3.fromRGB(205, 223, 232), 29
	text.Text, text.TextWrapped, text.Parent = "", true, surface
	local title = Instance.new("TextLabel")
	title.Name, title.Position, title.Size, title.BackgroundTransparency = "Title", UDim2.fromOffset(16, 24), UDim2.new(1, -32, 0, 70), 1
	title.Font, title.TextColor3, title.TextSize = Enum.Font.FredokaOne, HQ.trim, 60
	title.TextScaled, title.TextWrapped = true, false
	title.Text, title.Parent = titleText, surface
	local hint = Instance.new("TextLabel")
	hint.Name, hint.Position, hint.Size, hint.BackgroundTransparency = "Hint", UDim2.fromOffset(16, 166), UDim2.new(1, -32, 0, 28), 1
	hint.Font, hint.TextColor3, hint.TextSize, hint.Text = Enum.Font.BuilderSansMedium, Color3.fromRGB(184, 205, 216), 20, ""
	hint.Parent = surface
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
-- Scenery a visitor can walk into must be solid: the agency's set pieces,
-- tree and palm trunks, crystals, giant cards and the tower's glass podium.
-- Light strips, glass panes you see through, floor markings, foliage and
-- everything high above the ground stay passable. Returns how many parts it
-- made solid.
-- Props a player bumps into (the owner walked through lamp posts, desk legs and
-- bushes): solid like the trunks and crystals.
local SOLID_NAMES = { TreeTrunk = true, PalmTrunk = true, VibraniumCrystal = true, GiantCard = true, PodiumGlass = true, LampPole = true, DeskPost = true, Bush = true,
	-- The portal doors: their pillars and round frames stand behind the pads.
	QueueGate = true, PortalFrame = true }
function World.SolidifyProps(root)
	local made = 0
	local function within(item, name)
		local cursor = item.Parent
		while cursor do
			if cursor.Name == name then return true end
			cursor = cursor.Parent
		end
		return false
	end
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("BasePart") and not item.CanCollide then
			local inOutpost = within(item, "ShieldOutpost")
			if (inOutpost or SOLID_NAMES[item.Name]) and item.Material ~= Enum.Material.Neon and item.Material ~= Enum.Material.ForceField
				and (item.Transparency or 0) < 0.45 then
				local size = item.Size
				-- Thin plates are markings and emblems; high pieces are out of reach.
				if size and math.min(size.X, size.Y, size.Z) >= 0.35 and item.Position and item.Position.Y < 24 then
					item.CanCollide, item.CanQuery = true, true
					made += 1
				end
			end
		end
	end
	return made
end

-- Neon blows out to flat white when its colour is pale: a light cyan or pale
-- yellow plate next to the camera turns into a white wall. Every neon part of
-- the lobby is pulled to a deeper, more saturated version of its own colour, so
-- the glow stays a glow and reads as the colour it was meant to be.
function World.TameNeon(root)
	local tamed = 0
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("BasePart") and item.Material == Enum.Material.Neon and item.Color then
			local c = item.Color
			local r, g, b = c.R, c.G, c.B
			local high, low = math.max(r, g, b), math.min(r, g, b)
			if high - low < 0.15 then
				-- Whitish: just a little dimmer.
				r, g, b = r * 0.86, g * 0.86, b * 0.86
			else
				local pull = low * 0.25
				r, g, b = r * 0.82 - pull, g * 0.82 - pull, b * 0.82 - pull
			end
			item.Color = Color3.new(math.max(0, r), math.max(0, g), math.max(0, b))
			tamed += 1
		end
	end
	return tamed
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
	World.SolidifyProps(lobby)
	World.TameNeon(lobby)
	-- Last: no two surfaces of the finished lobby may share a plane.
	World.SeparateCoplanar(lobby)
end

-- A battle server never shows the lobby: with Config.SinglePlace its players
-- arrive from a lobby server, wait a moment for their group, play and travel
-- back. It builds the same bay (terrain, so the battlefield keeps its horizon)
-- and a plain round deck with the spawn where the hero plaza would stand, so a
-- phone in a battle loads the sea and a few dozen parts instead of the ~4,500
-- of the lobby (nothing streams: StreamingEnabled is off).
function World:BuildArrival()
	for _, name in ipairs({ "DoomLobby", "DoomArrival" }) do
		local old = workspace:FindFirstChild(name)
		if old then old:Destroy() end
	end
	local arrival = Instance.new("Model")
	arrival.Name, arrival.Parent = "DoomArrival", workspace
	self.lobby, self.portalZones, self.shopZones, self.shopOccupants = arrival, {}, {}, {}
	self:BuildLobbyTerrain()
	Kit.disc(arrival, "ArrivalDeck", Vector3.new(HUB.X, PLAZA_Y - 1, HUB.Z), 56, 2, HQ.stone, Enum.Material.Concrete, true)
	Kit.disc(arrival, "ArrivalRing", Vector3.new(HUB.X, PLAZA_Y + 0.06, HUB.Z), 44, 0.12, HQ.stoneDark, Enum.Material.Concrete, true)
	Kit.disc(arrival, "ArrivalCentre", Vector3.new(HUB.X, PLAZA_Y + 0.12, HUB.Z), 30, 0.12, HQ.stoneWarm, Enum.Material.Concrete, true)
	local spawn = Instance.new("SpawnLocation")
	spawn.Name, spawn.Size, spawn.CFrame = "LobbySpawn", Vector3.new(14, 0.2, 14), CFrame.new(HUB.X, PLAZA_Y + 0.3, HUB.Z)
	spawn.Anchored, spawn.Neutral, spawn.Duration, spawn.Transparency = true, true, 0, 1
	spawn.Parent = arrival
	self.lobbySpawn = Vector3.new(HUB.X, PLAZA_Y + 4, HUB.Z)
	World.SolidifyProps(arrival)
	World.TameNeon(arrival)
	World.SeparateCoplanar(arrival)
end

--------------------------------------------------------------------------------
-- Terrain: the sea, the islands' beaches, grass and rock, the moat and a ring
-- of far islands on the horizon. Water surfaces sit at a fill's top; solid
-- terrain renders two studs above it (4-stud voxels).
--------------------------------------------------------------------------------
function World:BuildLobbyTerrain()
	local terrain = workspace.Terrain
	local role = workspace:GetAttribute("DoomRole")
	-- Before the first match this is an uninterrupted bay, not a square void.
	-- An existing battlefield still owns its volume; Build clears that same
	-- volume before laying any map, so lobby water never changes its ground.
	local shared = role ~= "Lobby" and role ~= "Afk" and self.root ~= nil
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
	-- Shallow coves break the perfect circular shore. Low sand lobes and
	-- submerged rocks meet the water without obstructing bridge landings.
	for i = 0, 11 do
		local a = i * math.pi / 6 + 0.16
		local shore = HUB + Vector3.new(math.cos(a) * 160, SEA_Y - 5, 5 + math.sin(a) * 160)
		local clear = true
		for _, landing in ipairs(landings) do if (Vector3.new(shore.X, 0, shore.Z) - landing).Magnitude < 25 then clear = false end end
		if clear then terrain:FillBall(shore, 7 + i % 3, Enum.Material.Sand) end
	end
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
			-- Terraced coastal cliffs give the skyline a designed silhouette.
			-- Terrain, rather than hundreds of distant rock parts, owns the mass.
			local height, radius = spec[4] * 1.6, spec[3] * 0.6
			terrain:FillCylinder(CFrame.new(center + Vector3.new(0, height / 2 - 4, 0)), height, radius, Enum.Material.Rock)
			terrain:FillCylinder(CFrame.new(center + Vector3.new(0, height - 4, 0)), 4, radius * 0.97, Enum.Material.Grass)
			local ledge = center + Vector3.new(spec[3] * 0.34, height * 0.3 - 4, spec[3] * 0.2)
			terrain:FillCylinder(CFrame.new(ledge), height * 0.6, radius * 0.65, Enum.Material.Rock)
			terrain:FillCylinder(CFrame.new(ledge + Vector3.new(0, height * 0.3, 0)), 3, radius * 0.63, Enum.Material.Grass)
			for crown = 0, 2 do
				terrain:FillBall(center + Vector3.new((crown - 1) * radius * 0.48, height - 3, math.sin(crown * 2.4) * radius * 0.45), 5 + crown, Enum.Material.Grass)
			end
			if spec[1] == -300 or spec[1] == 330 then
				-- At this distance a trunk and three broad crowns do the work of a
				-- complete tree rig. Keep the detailed roots near the walking routes.
				for i = -1, 2 do
					local tree = center + Vector3.new(i * radius * 0.3, height - 2, math.sin(i * 2.4) * radius * 0.3)
					Kit.column(self.lobby, "CliffTrunk", tree, 7, 1.6, HQ.trunk, Enum.Material.Wood)
					for lobe = -1, 1 do
						Kit.blob(self.lobby, "CliffCanopy", Vector3.new(9, 7, 9), CFrame.new(tree + Vector3.new(lobe * 3, 8 + (lobe == 0 and 2 or 0), 0)), lobe == 0 and HQ.leafLight or HQ.leaf, Enum.Material.Grass)
					end
				end
			end
			if spec[1] == -300 or spec[1] == 330 then
				local down = (Vector3.new(HUB.X, 0, HUB.Z) - Vector3.new(center.X, 0, center.Z)).Unit
				local lip = center + down * radius + Vector3.new(0, height - 5, 0)
				terrain:FillBall(lip - Vector3.new(0, 2, 0), 5, Enum.Material.Rock)
				local waterfall = Instance.new("Model")
				waterfall.Name, waterfall.Parent = "CoastalCascade", self.lobby
				local fall = height - 5 - SEA_Y
				local sheet = Kit.block(waterfall, "CascadeSheet", Vector3.new(12, fall, 0.35), CFrame.lookAt(lip - Vector3.new(0, fall / 2, 0), lip - Vector3.new(0, fall / 2, 0) + down), Color3.fromRGB(121, 210, 237), Enum.Material.Glass)
				sheet.Transparency = 0.35
				for i = -1, 1 do
					local ribbon = Kit.block(waterfall, "CascadeRibbon", Vector3.new(0.9 + (i + 1) * 0.3, fall - 0.4, 0.1), sheet.CFrame * CFrame.new(i * 3.2, 0, -0.24), Color3.fromRGB(202, 232, 238), Enum.Material.SmoothPlastic)
					ribbon.Transparency = 0.4
				end
				Kit.blob(waterfall, "CascadeFoam", Vector3.new(15, 0.7, 7), CFrame.new(lip.X, SEA_Y + 0.2, lip.Z), Color3.fromRGB(202, 232, 238), Enum.Material.SmoothPlastic).Transparency = 0.25
			end
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
-- Pilings continue below the water and join the underside of the deck. They
-- stay outside the walking surface: scenery supports never obstruct a queue.
function Kit.bridgeSupports(parent, a, b, halfWidth, name)
	local V = Vector3.new
	local dir = V(b.X - a.X, 0, b.Z - a.Z).Unit
	local right = V(-dir.Z, 0, dir.X)
	local bottom, top = SEA_Y - 7, GROUND_Y - 0.35
	for _, fraction in ipairs({ 0.3, 0.7 }) do
		local center = a:Lerp(b, fraction)
		for _, side in ipairs({ -1, 1 }) do
			local foot = V(center.X, bottom, center.Z) + right * side * halfWidth
			local pier = Kit.column(parent, name, foot, top - bottom, 1.7, HQ.steel, Enum.Material.Metal, true)
			pier.CastShadow = true
			Kit.disc(parent, name .. "Foot", foot, 3, 0.7, HQ.stoneDark, Enum.Material.Concrete, true)
		end
	end
end

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
	Kit.disc(hq, "HubBand", HUB + V(0, GROUND_Y - 0.02, 0), 122, 0.1, HQ.navy, Enum.Material.Slate, true)
	Kit.disc(hq, "HubInner", HUB + V(0, GROUND_Y + 0.01, 0), 116, 0.1, HQ.stone, pave, true)
	-- The raised hero plaza: a steel plinth, a band of light, a pale deck.
	Kit.disc(hq, "PlazaBase", HUB + V(0, GROUND_Y + 0.4, 0), 71, 0.8, HQ.navy, metal, true).CastShadow = true
	Kit.disc(hq, "PlazaGlow", HUB + V(0, 1.14, 0), 70.6, 0.12, HQ.cyan, Enum.Material.Neon)
	Kit.disc(hq, "PlazaGoldCoping", HUB + V(0, 1.31, 0), 71.2, 0.16, HQ.gold, metal, true)
	Kit.disc(hq, "PlazaDeck", HUB + V(0, PLAZA_Y - 0.1, 0), 69.8, 0.2, HQ.stoneWarm, pave, true)
	Kit.disc(hq, "PlazaOuterBand", HUB + V(0, PLAZA_Y + 0.01, 0), 64, 0.06, HQ.navy, Enum.Material.Slate)
	Kit.disc(hq, "PlazaOuterInlay", HUB + V(0, PLAZA_Y + 0.045, 0), 62.8, 0.06, HQ.gold, metal)
	Kit.disc(hq, "PlazaPromenade", HUB + V(0, PLAZA_Y + 0.075, 0), 61.8, 0.06, HQ.stoneDark, pave)
	Kit.disc(hq, "PlazaInnerCoping", HUB + V(0, PLAZA_Y + 0.11, 0), 49, 0.06, HQ.gold, metal)
	Kit.disc(hq, "PlazaRing", HUB + V(0, PLAZA_Y + 0.15, 0), 48.2, 0.06, HQ.navy, Enum.Material.SmoothPlastic, true)
	Kit.disc(hq, "PlazaRingInner", HUB + V(0, PLAZA_Y + 0.185, 0), 44, 0.06, HQ.stone, pave, true)
	-- Everyone arrives standing on the hero star.
	Kit.disc(hq, "HeroStarHalo", HUB + V(0, PLAZA_Y + 0.23, 0), 23, 0.04, HQ.cyan, Enum.Material.Neon)
	Kit.disc(hq, "PlazaStarDisc", HUB + V(0, PLAZA_Y + 0.265, 0), 21.8, 0.04, HQ.navy, Enum.Material.SmoothPlastic, true)
	-- A deeper gold than the HUD's: in the lobby's bright light the plain one burns
	-- out to flat yellow, and a tip near the camera then fills the screen.
	Kit.star(hq, "HeroStar", HUB + V(0, PLAZA_Y + 0.32, 0), V(1, 0, 0), V(0, 0, 1), 9.5, HQ.gold, metal, 0.08)
	for i = 0, 7 do
		local a = i * math.pi / 4 + math.pi / 8
		local dir = V(math.cos(a), 0, math.sin(a))
		local from, to = HUB + dir * 12 + V(0, PLAZA_Y + 0.23, 0), HUB + dir * 21.5 + V(0, PLAZA_Y + 0.23, 0)
		Kit.beam(hq, "PlazaRay", from, to, 0.25, 0.04, HQ.cyan, Enum.Material.Neon)
	end
	-- Stairs down from the plaza on the four compass lines. Bollards and
	-- promenade inlays only on the east/west approaches; the north/south
	-- stairs rely on corner marks alone to stay within the 4,500-part lobby
	-- budget after M22.7 hero refinements added geometry to five roster figures.
	for _, dir in ipairs({ V(1, 0, 0), V(-1, 0, 0), V(0, 0, 1), V(0, 0, -1) }) do
		-- StepNose disabled on all stairs to stay within the 4,500-part lobby
		-- budget after M22.7 hero refinements; stair readability is preserved
		-- by PromenadeInlay beams and bollards on east/west approaches.
		Kit.stairs(hq, HUB + dir * 35.5, dir, 14, PLAZA_Y, GROUND_Y, 2, true)
		local right = V(-dir.Z, 0, dir.X)
		local hasDetail = (dir.X ~= 0)
		for _, side in ipairs({-1, 1}) do
			if hasDetail then
				Kit.bollard(hq, HUB + dir * 37.6 + right * side * 9.2 + V(0, GROUND_Y, 0))
				Kit.beam(hq, "PromenadeInlay", HUB + dir * 40.5 + right * side * 7.8 + V(0, GROUND_Y + 0.12, 0), HUB + dir * 62 + right * side * 7.8 + V(0, GROUND_Y + 0.12, 0), 0.18, 0.04, HQ.gold, metal)
			end
		end
	end
	-- The big games' yellow corner marks frame the square around the plaza,
	-- and lit lines run out along its diagonals.
	-- Navigational inlays replace the square of disconnected neon corners.
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
		Kit.bridgeSupports(hq, a, b, 6.1, "MoatPier")
		for _, side in ipairs({ -1, 1 }) do
			local sa, sb = a + dir * 4 + right * side * 7.4, b + right * side * 7.4
			Kit.beam(hq, "BridgeBeam", sa + V(0, GROUND_Y - 1.4, 0), sb + V(0, GROUND_Y - 1.4, 0), 1.4, 2.2, HQ.steel, metal, true)
			Kit.fence(hq, { sa + V(0, GROUND_Y + 0.1, 0), sb + V(0, GROUND_Y + 0.1, 0) }, 3, gate.color)
			-- The gate at the far end of the bridge.
			local foot = b - dir * 1 + right * side * 8.6
			Kit.block(hq, "GatePillar", V(2, 12, 2), CFrame.new(foot + V(0, GROUND_Y + 6, 0)), HQ.navy, metal, true).CastShadow = true
			Kit.block(hq, "GateLight", V(0.4, 9, 0.4), CFrame.new(foot - dir * 1.05 + V(0, GROUND_Y + 6, 0)), gate.color, Enum.Material.Neon)
			-- The capital crowns the pillar just under the lintel (it crossed the sign).
			Kit.block(hq, "GateCapital", V(2.7, 0.7, 2.7), CFrame.new(foot + V(0, GROUND_Y + 10.9, 0)), HQ.gold, metal)
		end
		local top = b - dir * 1 + V(0, GROUND_Y + 12.4, 0)
		local lintel = Kit.block(hq, "GateLintel", V(19.6, 2.2, 2.4), CFrame.lookAt(top, top - dir), HQ.navy, metal)
		Kit.block(hq, "GateTrim", V(19.8, 0.4, 2.6), CFrame.lookAt(top - V(0, 1.3, 0), top - V(0, 1.3, 0) - dir), gate.color, Enum.Material.Neon)
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face, gui.LightInfluence = "GateSign", Enum.NormalId.Front, 0
		gui.SizingMode, gui.PixelsPerStud, gui.Parent = Enum.SurfaceGuiSizingMode.PixelsPerStud, 24, lintel
		local text = Instance.new("TextLabel")
		text.Name, text.BackgroundTransparency, text.Size, text.Font, text.TextScaled = "Title", 1, UDim2.fromScale(1, 1), Enum.Font.FredokaOne, true
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
			Kit.block(hq, "RoadGlow", V(0.5, 0.06, length - 0.3), frame * CFrame.new(side * ((outer - inner) / 2 - 0.6), 0.78, 0), HQ.cyan, i % 6 == 0 and Enum.Material.Neon or Enum.Material.Metal)
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
	-- This landmark stands outside the raised plaza, on the lower hub deck.
	local base = HUB + V(0, GROUND_Y + 0.06, 46)
	Kit.disc(model, "BeaconStep", base + V(0, 0.6, 0), 16, 1.2, HQ.steel, Enum.Material.Metal, true)
	Kit.disc(model, "BeaconStepGlow", base + V(0, 1.3, 0), 15.4, 0.2, HQ.cyan, Enum.Material.Neon)
	Kit.disc(model, "BeaconStepTop", base + V(0, 1.6, 0), 16, 0.4, HQ.gold, Enum.Material.Metal, true)
	Kit.disc(model, "BeaconStepInset", base + V(0, 1.85, 0), 14.8, 0.08, HQ.navy, Enum.Material.Metal)
	local pillar = Kit.column(model, "BeaconPillar", base + V(0, 1.8, 0), 8.5, 3.2, HQ.navy, Enum.Material.Metal, true)
	pillar.CastShadow = true
	for i = 0, 3 do
		local a = i * math.pi / 2
		Kit.block(model, "BeaconStrip", V(0.3, 7.6, 0.3), CFrame.new(base + V(math.cos(a) * 1.65, 5.8, math.sin(a) * 1.65)), HQ.cyan, Enum.Material.Neon)
	end
	Kit.disc(model, "BeaconCup", base + V(0, 10.6, 0), 7.5, 0.8, HQ.gold, Enum.Material.Metal)
	-- A navigational globe: cyan meridians inside gold orbital braces. No
	-- green blobs masking the sphere or competing with the surrounding gardens.
	local center = base + V(0, 16.2, 0)
	local globe = Kit.block(model, "BeaconGlobe", V(10, 10, 10), CFrame.new(center), Color3.fromRGB(70, 170, 255), Enum.Material.Glass)
	globe.Shape, globe.Transparency, globe.Reflectance = Enum.PartType.Ball, 0.25, 0.2
	Kit.animate(globe, 0.3, 0)
	local core = Kit.block(model, "BeaconCore", V(8, 8, 8), CFrame.new(center), Color3.fromRGB(60, 150, 255), Enum.Material.Neon)
	core.Shape, core.Transparency = Enum.PartType.Ball, 0.62
	Kit.light(core, HQ.cyan, 28, 0.7)
	for ring = 1, 3 do
		local tilt = CFrame.new(center) * CFrame.Angles(ring == 3 and math.pi / 2 or 0, ring == 2 and math.pi / 2 or 0, 0)
		for i = 0, 11 do
			local a, b = i * math.pi / 6, (i + 1) * math.pi / 6
			local line = Kit.beam(model, "GlobeMeridian", tilt * V(math.cos(a) * 5.1, math.sin(a) * 5.1, 0), tilt * V(math.cos(b) * 5.1, math.sin(b) * 5.1, 0), 0.14, 0.14, HQ.cyan, Enum.Material.Neon)
			Kit.animate(line, 0.3, 0, center)
		end
	end
	for ring = 1, 2 do
		local tilt = CFrame.new(center) * CFrame.Angles(ring == 1 and 0.5 or -0.35, ring * 1.2, ring == 1 and 0.2 or -0.4)
		local radius = ring == 1 and 7.4 or 6.6
		for i = 0, 11 do
			local angle = i * math.pi * 2 / 12
			local segment = Kit.block(model, "BeaconOrbit", V(2 * radius * math.sin(math.pi / 12) + 0.05, 0.35, 0.35),
				tilt * CFrame.Angles(0, 0, angle) * CFrame.new(0, radius, 0), HQ.gold, Enum.Material.Metal)
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
	local glass = Color3.fromRGB(35, 72, 111)
	-- A finished portico: rounded masonry ends, inset glazing and a paved
	-- through-route at exactly the same height as both connecting roads.
	Kit.block(model, "TowerPassageFloor", V(16, 1.5, 28), CFrame.new(base + V(0, -0.75, 0)), HQ.stoneWarm, Enum.Material.Pavement, true)
	Kit.block(model, "PassageRunner", V(8, 0.04, 27.8), CFrame.new(base + V(0, 0.035, 0)), Color3.fromRGB(60, 83, 104), Enum.Material.Slate)
	for _, side in ipairs({ -1, 1 }) do
		Kit.block(model, "PassageEdge", V(0.18, 0.05, 27.8), CFrame.new(base + V(side * 4.5, 0.06, 0)), HQ.gold, Enum.Material.Metal)
	end
	for _, side in ipairs({ -1, 1 }) do
		local wingX = side * 17
		Kit.block(model, "PodiumWing", V(14, 12, 26), CFrame.new(base + V(wingX, 6, 0)), HQ.navy, Enum.Material.Metal, true).CastShadow = true
		Kit.block(model, "PodiumCross", V(18, 12, 22), CFrame.new(base + V(wingX, 6, 0)), HQ.navy, Enum.Material.Metal, true)
		for _, endX in ipairs({ -7, 7 }) do
			for _, endZ in ipairs({ -11, 11 }) do
				Kit.column(model, "PodiumRoundEnd", base + V(wingX + endX, 0, endZ), 12, 4, HQ.steel, Enum.Material.Metal, true)
			end
		end
		local pane = Kit.block(model, "PodiumGlass", V(12, 6.4, 0.4), CFrame.new(base + V(wingX, 5.7, -13.25)), Color3.fromRGB(40, 83, 109), Enum.Material.Glass)
		pane.Reflectance = 0.12
		for i = -1, 1 do
			Kit.block(model, "WindowMullion", V(0.28, 6.7, 0.55), CFrame.new(base + V(wingX + i * 3.7, 5.7, -13.6)), HQ.gold, Enum.Material.Metal)
		end
		for _, y in ipairs({ 2.3, 9.1 }) do
			Kit.block(model, "WindowSill", V(12.5, 0.35, 0.7), CFrame.new(base + V(wingX, y, -13.65)), HQ.navy, Enum.Material.Metal)
		end
		Kit.block(model, "PodiumTrim", V(18.6, 0.7, 27), CFrame.new(base + V(wingX, 12.2, 0)), HQ.gold, Enum.Material.Metal, true)
		Kit.block(model, "PodiumSkirting", V(18.6, 1.1, 27), CFrame.new(base + V(wingX, 0.55, 0)), HQ.stoneWarm, Enum.Material.Slate, true)
		Kit.column(model, "PorticoColumn", base + V(side * 8.6, 0, -14), 9.3, 1.5, HQ.steel, Enum.Material.Metal, true)
		Kit.block(model, "ArchLight", V(0.18, 6.2, 0.22), CFrame.new(base + V(side * 8.6, 5.4, -14.82)), HQ.lamp, Enum.Material.Neon)
		for _, z in ipairs({ -7, 7 }) do
			local panel = Kit.block(model, "PassageWallPanel", V(0.16, 4, 4.6), CFrame.new(base + V(side * 8.03, 4.5, z)), Color3.fromRGB(42, 77, 94), Enum.Material.Glass)
			panel.Reflectance = 0.15
			Kit.block(model, "PassageSconce", V(0.25, 1.8, 0.6), CFrame.new(base + V(side * 7.87, 5.8, z)), HQ.lamp, Enum.Material.Neon)
			-- Sloping ribs join the floor to the canopy rather than floating
			-- decoration in the passage. Keep the central fourteen studs clear.
			Kit.beam(model, "PassageRib", base + V(side * 7.8, 0, z + 3), base + V(side * 7.25, 8.7, z + 3), 0.5, 0.7, HQ.steel, Enum.Material.Metal, true)
		end
	end
	Kit.block(model, "PodiumBridge", V(16, 5, 30), CFrame.new(base + V(0, 12, 0)), HQ.navy, Enum.Material.Metal, true).CastShadow = true
	Kit.block(model, "PorticoCanopy", V(19.5, 0.65, 5.5), CFrame.new(base + V(0, 9.3, -13.2)), HQ.navy, Enum.Material.Metal, true)
	Kit.block(model, "ArchLintel", V(14, 0.12, 0.3), CFrame.new(base + V(0, 8.91, -15.9)), HQ.lamp, Enum.Material.Neon)
	for _, z in ipairs({ -8, 0, 8 }) do
		Kit.block(model, "PassageCrossbeam", V(15, 0.45, 0.8), CFrame.new(base + V(0, 9.15, z)), HQ.steel, Enum.Material.Metal)
		local fixture = Kit.block(model, "PassageCeiling", V(4.8, 0.12, 0.4), CFrame.new(base + V(0, 8.87, z)), Color3.fromRGB(242, 217, 172), Enum.Material.SmoothPlastic)
		Kit.light(fixture, Color3.fromRGB(255, 221, 173), 14, 0.3)
	end
	-- The shaft: three stacked volumes, each a little slimmer, with lit floors.
	local y = 14.5
	for level, spec in ipairs({ { 30, 34, 22 }, { 24, 30, 18 }, { 18, 24, 14 } }) do
		local w, h, d = spec[1], spec[2], spec[3]
		local x = level == 3 and 2 or 0
		local chamfer = 1.4
		local body = Kit.block(model, "TowerShaft", V(w - chamfer * 2, h, d), CFrame.new(base + V(x, y + h / 2, level * 1.5)), glass, Enum.Material.Glass, true)
		body.Reflectance, body.CastShadow = 0.25, true
		Kit.block(model, "TowerCross", V(w, h, d - chamfer * 2), body.CFrame, glass, Enum.Material.Glass, true).Reflectance = 0.25
		for _, sx in ipairs({-1, 1}) do for _, sz in ipairs({-1, 1}) do
			local corner = base + V(x + sx * (w / 2 - chamfer), y + h / 2, level * 1.5 + sz * (d / 2 - chamfer))
			local bevel = Kit.triangle(model, "TowerBevel", corner, V(sx * chamfer, 0, 0), V(0, 0, sz * chamfer), h, glass, Enum.Material.Glass)
			bevel.CanCollide, bevel.Reflectance = true, 0.25
		end end
		for f = 1, math.floor(h / 6) do
			Kit.block(model, "TowerFloor", V(w + 0.3, 0.3, d + 0.3), CFrame.new(base + V(x, y + f * 6 - 0.5, level * 1.5)), HQ.steel, Enum.Material.Metal)
		end
		for _, side in ipairs({ -1, 1 }) do
			Kit.block(model, "TowerMullion", V(0.6, h, 0.8), CFrame.new(base + V(x + side * w * 0.28, y + h / 2, level * 1.5 - d / 2 - 0.18)), HQ.gold, Enum.Material.Metal)
			Kit.block(model, "TowerButtress", V(2.3, h, 2.3), CFrame.new(base + V(x + side * (w / 2 - 0.35), y + h / 2, level * 1.5 - d / 2)), HQ.navy, Enum.Material.Metal)
			Kit.block(model, "TowerButtressInlay", V(0.25, h - 1.6, 0.15), CFrame.new(base + V(x + side * (w / 2 - 0.35), y + h / 2, level * 1.5 - d / 2 - 1.21)), HQ.gold, Enum.Material.Metal)
		end
		Kit.block(model, "TowerCornice", V(w + 3.4, 0.6, d + 3), CFrame.new(base + V(x, y + h, level * 1.5)), HQ.gold, Enum.Material.Metal)
		Kit.block(model, "TowerCorniceCap", V(w + 2.6, 0.9, d + 2.2), CFrame.new(base + V(x, y + h + 0.75, level * 1.5)), HQ.navy, Enum.Material.Metal)
		Kit.block(model, "TowerFin", V(1.2, h, 1.2), CFrame.new(base + V(x - w / 2 - 0.4, y + h / 2, level * 1.5 - d / 2)), HQ.navy, Enum.Material.Metal)
		Kit.block(model, "TowerFinLight", V(0.3, h - 2, 0.3), CFrame.new(base + V(x + w / 2 + 0.2, y + h / 2, level * 1.5 - d / 2 - 0.2)), HQ.cyan, Enum.Material.Neon)
		y += h
	end
	-- One vertical energy spine is the tower's focal point; the facade's
	-- remaining lines are metal so the landmark never becomes a wall of neon.
	Kit.block(model, "TowerSpineHousing", V(4.8, 77, 12), CFrame.new(base + V(0, 53, -5.9)), HQ.navy, Enum.Material.Metal)
	Kit.block(model, "TowerEnergySpine", V(1.2, 74, 0.18), CFrame.new(base + V(0, 53, -12.05)), HQ.cyan, Enum.Material.Neon)
	for _, side in ipairs({-1, 1}) do
		Kit.block(model, "TowerSpineEdge", V(0.3, 77, 0.22), CFrame.new(base + V(side * 2.3, 53, -12.1)), HQ.gold, Enum.Material.Metal)
		local flag = base + V(side * 11, 29, -11.4)
		Kit.block(model, "TowerStandard", V(5.2, 18, 0.22), CFrame.new(flag), HQ.navy, Enum.Material.Fabric)
		Kit.block(model, "TowerStandardMount", V(6.6, 0.55, 0.8), CFrame.new(flag + V(0, 9.2, 0)), HQ.gold, Enum.Material.Metal)
		for _, edge in ipairs({-1, 1}) do Kit.block(model, "TowerStandardEdge", V(0.2, 18, 0.15), CFrame.new(flag + V(edge * 2.6, 0, -0.2)), HQ.gold, Enum.Material.Metal) end
		Kit.star(model, "TowerStandardStar", flag + V(0, 1, -0.3), V(1,0,0), V(0,1,0), 1.8, HQ.gold, Enum.Material.Metal, 0.1)
	end
	-- The landing deck juts out toward the island with a Quinjet pad light.
	local deck = base + V(-4, y - 8, -18)
	Kit.disc(model, "LandingDeck", deck, 18, 1.2, HQ.steel, Enum.Material.Metal)
	Kit.disc(model, "LandingRing", deck + V(0, 0.65, 0), 15, 0.1, HQ.gold, Enum.Material.Neon)
	Kit.block(model, "LandingArm", V(5, 1.2, 12), CFrame.new(deck + V(0, 0, 8)), HQ.steel, Enum.Material.Metal)
	for _, side in ipairs({-1, 1}) do Kit.beam(model, "LandingStrut", deck + V(side * 5.2, -0.6, 1), base + V(-4 + side * 5.2, y - 20, -4), 0.8, 1.1, HQ.gold, Enum.Material.Metal) end
	-- Crown and spire with a warning light.
	Kit.block(model, "TowerCrown", V(20, 3, 16), CFrame.new(base + V(2, y + 1.5, 4.5)), HQ.navy, Enum.Material.Metal)
	Kit.column(model, "TowerSpire", base + V(2, y + 3, 4.5), 22, 1.2, HQ.trim, Enum.Material.Metal)
	Kit.animate(Kit.block(model, "SpireLight", V(1.6, 1.6, 1.6), CFrame.new(base + V(2, y + 25.6, 4.5)), Color3.fromRGB(255, 70, 70), Enum.Material.Neon), 0, 0.3)
	-- The hero emblem on the shaft's face: a giant star shield.
	local emblemAt = CFrame.lookAt(base + V(0, 60, -12.3), base + V(0, 60, -40))
	Kit.disc(model, "TowerEmblemRing", emblemAt.Position, 16, 0.6, HQ.gold, Enum.Material.Metal).CFrame = emblemAt * CFrame.Angles(0, math.pi / 2, 0)
	Kit.disc(model, "TowerEmblemField", emblemAt.Position, 13, 0.7, Color3.fromRGB(30, 80, 170), Enum.Material.SmoothPlastic).CFrame = emblemAt * CFrame.new(0, 0, -0.1) * CFrame.Angles(0, math.pi / 2, 0)
	Kit.star(model, "TowerEmblemStar", emblemAt.Position + emblemAt.LookVector * 0.5, emblemAt.RightVector, emblemAt.UpVector, 5.6, HQ.white, Enum.Material.Neon, 0.3)
	-- The tower's name runs along the podium bridge over the road.
	local nameplate = Kit.block(model, "TowerNameplate", V(15.6, 3.6, 0.3), CFrame.new(base + V(0, 12, -15.2)), HQ.navy, Enum.Material.Metal)
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.LightInfluence = "Nameplate", Enum.NormalId.Front, 0
	gui.SizingMode, gui.PixelsPerStud, gui.Parent = Enum.SurfaceGuiSizingMode.PixelsPerStud, 30, nameplate
	local title = Instance.new("TextLabel")
	title.Name, title.BackgroundTransparency, title.Size, title.Font, title.TextScaled = "Title", 1, UDim2.fromScale(1, 1), Enum.Font.FredokaOne, true
	title.TextColor3, title.Text, title.Parent = HQ.gold, "TORRE DOS HERÓIS", gui
	title:SetAttribute("LobbyTextPT", "TORRE DOS HERÓIS"); title:SetAttribute("LobbyTextEN", "HEROES TOWER")
	-- Shop identity belongs to a physical sign, not text floating in the bay.
	local shopSign = wallSign(model, "PremiumShopSign", CFrame.new(base + V(0, 16, -16)), V(20, 4, 0.3), "LOJA • EQUIPAMENTOS", "ESCOLHA SUA VANTAGEM", HQ.gold)
	for _, text in ipairs(shopSign:GetDescendants()) do
		if text:IsA("TextLabel") then
			local isTitle = text.Text == "LOJA • EQUIPAMENTOS"
			text.Name = isTitle and "Title" or "Subtitle"
			text:SetAttribute("LobbyTextPT", text.Text)
			text:SetAttribute("LobbyTextEN", isTitle and "SHOP • EQUIPMENT" or "CHOOSE YOUR PERK")
		end
	end
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
		Kit.disc(model, "StatueFoundation", foot + V(0, 0.3, 0), 13.4, 0.6, HQ.stoneWarm, Enum.Material.Slate, true)
		Kit.disc(model, "StatueBase", foot + V(0, 1.4, 0), 12.6, 1.6, HQ.navy, Enum.Material.Metal, true)
		Kit.disc(model, "StatueGoldBand", foot + V(0, 2.25, 0), 12.8, 0.18, HQ.gold, Enum.Material.Metal)
		Kit.disc(model, "StatueGlow", foot + V(0, 2.43, 0), 12.4, 0.12, HQ.cyan, Enum.Material.Neon)
		Kit.disc(model, "StatueTop", foot + V(0, 2.72, 0), 12.4, 0.4, HQ.navy, Enum.Material.Metal, true)
		Kit.disc(model, "StatueTopInlay", foot + V(0, 2.96, 0), 11, 0.06, HQ.gold, Enum.Material.Metal)
		Kit.disc(model, "StatueTopField", foot + V(0, 3.005, 0), 10.4, 0.02, HQ.navy, Enum.Material.Metal)
		for _, side in ipairs({-1, 1}) do
			Kit.bollard(model, foot + V(math.sign(spec[2]) * 7.6, 0, side * 4.2))
		end
		local hero = self.catalog.Heroes[spec[1]]
		-- The plaque faces the plaza.
		local plaque = Kit.block(model, "StatuePlaque", V(5.4, 1.3, 0.3), CFrame.new(foot + V(0, 1.3, 6.25)), HQ.gold, Enum.Material.Metal)
		local gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face, gui.LightInfluence = "Plaque", Enum.NormalId.Back, 0
		gui.SizingMode, gui.PixelsPerStud, gui.Parent = Enum.SurfaceGuiSizingMode.PixelsPerStud, 40, plaque
		local text = Instance.new("TextLabel")
		text.Name, text.BackgroundTransparency, text.Size, text.Font, text.TextScaled = "Title", 1, UDim2.fromScale(1, 1), Enum.Font.FredokaOne, true
		text.TextColor3, text.Text, text.Parent = HQ.navy, upper(hero.name.pt), gui
		text:SetAttribute("LobbyTextPT", upper(hero.name.pt)); text:SetAttribute("LobbyTextEN", upper(hero.name.en))
		-- Reuse the gameplay costume at twice its authored scale, with every
		-- piece anchored in the same pose. The pedestal remains separate.
		local figureContainer = Instance.new("Model")
		figureContainer.Name, figureContainer.Parent = "Statue_" .. spec[1], model
		figureContainer:SetAttribute("HeroId", spec[1])
		local origin = CFrame.new(foot + V(0, 3.02, 0)) * CFrame.Angles(0, math.pi, 0)
		local figure = staticFigure(figureContainer, spec[1], hero, origin, 2.0)
		-- Disable idle on the actual nested figure, which LobbyWorld discovers.
		figure:SetAttribute("IdleFigure", nil)
		figure:SetAttribute("IdlePhase", nil)
		-- A monument strikes the hero's pose; the walk-through blocker stays.
		Figure.PoseStatic(figure, STATUE_POSE[spec[1]])
	end
	return model
end

--------------------------------------------------------------------------------
-- Service desks around the hub: maps, team, bases, the
-- academy, and the two notice boards. Each is a small lit kiosk facing the
-- plaza.
--------------------------------------------------------------------------------
function World:BuildServiceDesks(lobby)
	local V = Vector3.new
	local scene = Instance.new("Model")
	scene.Name, scene.Parent = "HubServices", lobby
	local function localized(target, pt, en) target:SetAttribute("LobbyTextPT", pt); target:SetAttribute("LobbyTextEN", en) end
	-- A rounded booth, not a box: a counter with round ends (a capsule), round
	-- posts and an open sign frame, all in the service's colour.
	local function kiosk(center, facing, color)
		local frame = CFrame.new(center) * CFrame.Angles(0, facing, 0)
		Kit.block(scene, "DeskBody", V(6, 2.6, 3.2), frame * CFrame.new(0, 1.3 + GROUND_Y, 0), HQ.navy, Enum.Material.Metal, true)
		Kit.block(scene, "DeskTop", V(6.4, 0.4, 3.8), frame * CFrame.new(0, 2.8 + GROUND_Y, 0), HQ.trim, Enum.Material.SmoothPlastic, true)
		for _, side in ipairs({ -1, 1 }) do
			local ending = (frame * CFrame.new(side * 3, 0, 0)).Position
			Kit.column(scene, "DeskEnd", V(ending.X, GROUND_Y, ending.Z), 2.6, 3.2, HQ.navy, Enum.Material.Metal, true)
			Kit.disc(scene, "DeskTopEnd", V(ending.X, 2.8 + GROUND_Y, ending.Z), 3.8, 0.4, HQ.trim, Enum.Material.SmoothPlastic, true)
			local post = (frame * CFrame.new(side * 4.6, 0, -1.6)).Position
			Kit.column(scene, "DeskPost", V(post.X, GROUND_Y, post.Z), 9, 0.7, HQ.steel, Enum.Material.Metal)
			Kit.blob(scene, "DeskPostCap", V(1.1, 1.1, 1.1), CFrame.new(post.X, 9.1 + GROUND_Y, post.Z), HQ.gold, Enum.Material.Metal)
		end
		Kit.block(scene, "DeskStripe", V(6, 0.4, 0.2), frame * CFrame.new(0, 1.9 + GROUND_Y, 1.7), color, Enum.Material.Neon)
		-- The open frame keeps the screen and its emblem unobstructed.
		for _, side in ipairs({-1, 1}) do
			Kit.block(scene, "ServicePierCap", V(1.5, 0.4, 1.6), frame * CFrame.new(side * 4.6, 8.8 + GROUND_Y, -1.6), HQ.gold, Enum.Material.Metal)
		end
		return frame
	end
	-- A coat of arms floats and bobs over every desk, readable from the plaza:
	-- built from parts, so no emoji and no font decides how it looks.
	local function icon(frame, kind, tint)
		return Kit.emblem(scene, kind, frame * CFrame.new(0, 12.6 + GROUND_Y, -0.2), tint)
	end
	local details = {
		maps = { "Escolha seu destino", "Choose your destination" },
		inventory = { "Monte sua equipe", "Build your team" },
		bases = { "Escolha sua defesa", "Choose your defense" },
		talents = { "Fortaleça seus heróis", "Strengthen your heroes" },
		quests = { "Jogue e ganhe prêmios", "Play and earn rewards" },
		leaderboard = { "Ver classificação", "View leaderboard" },
	}
	local desks = table.clone(LAYOUT.services)
	table.insert(desks, { id = "quests", angle = LAYOUT.boards.quests, pt = "MISSÕES", en = "MISSIONS", color = Color3.fromRGB(143, 208, 122) })
	table.insert(desks, { id = "leaderboard", angle = LAYOUT.boards.leaderboard, pt = "SALÃO DA FAMA", en = "HALL OF FAME", color = HQ.gold })
	-- Every desk and its Back SurfaceGui face the plaza along local +Z.
	for _, def in ipairs(desks) do
		local at = polar(def.angle, 54, 0)
		local frame = kiosk(at, yawToward(at, HUB), def.color)
		local board, text = buildBoard(lobby, at.X, at.Z, def.id, def.pt, self.openPanel)
		local panel = board.PrimaryPart
		local post = board:FindFirstChild("Post")
		if post then post:Destroy() end
		-- Mount above the rear of the counter, between its two posts.
		panel.CFrame = frame * CFrame.new(0, 6.4 + GROUND_Y, -1.15)
		panel.Color, panel.Material = HQ.navy, Enum.Material.Metal
		panel.Size = V(9.2, 4.14, 0.3)
		board:SetAttribute("ServiceFrame", frame)
		Kit.block(scene, "ServiceScreenMount", V(0.45, 3.6, 0.7), frame * CFrame.new(0, 4.8 + GROUND_Y, -1.6), HQ.steel, Enum.Material.Metal)
		local title = panel.Board.Title
		title.TextColor3 = def.color
		panel.Board.Bezel.UIStroke.Color = def.color
		localized(title, def.pt, def.en)
		localized(text, details[def.id][1], details[def.id][2])
		text.Text = text:GetAttribute("LobbyTextPT")
		-- Interaction instructions belong to the nearby prompt, not another
		-- paragraph on every sign. The title remains independent of live status.
		local prompt = panel:FindFirstChildOfClass("ProximityPrompt")
		if prompt then localized(prompt, def.pt, def.en) end
		icon(frame, def.id, def.color)
		if def.id == "leaderboard" then self.leaderboardText = text end
	end
	local wood = Color3.fromRGB(104, 72, 46)
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
	Kit.sign(hq, "CampaignSign", CFrame.lookAt(V(c.X, 34, backZ - 4.6), V(c.X, 34, HUB.Z)), 44, 8, {
		premium = true,
		title = { "CAMPANHA", "CAMPAIGN" }, subtitle = { "SALVE MANHATTAN • GAMA • FUNDIÇÃO", "SAVE MANHATTAN • GAMMA • FOUNDRY" },
		top = Color3.fromRGB(90, 215, 255), bottom = Color3.fromRGB(30, 110, 170), accent = Color3.fromRGB(90, 230, 170),
		art = "skyline", artX = 0.5, artY = 0.62, artW = 0.96, artH = 0.62, titleY = 0.36, legs = GRASS_Y,
	})
	for _, x in ipairs({ -64, 64 }) do Kit.flag(hq, V(c.X + x, GROUND_Y, backZ + 3.4), 18, Color3.fromRGB(70, 200, 150), 5) end
	for _, x in ipairs({ -21, 21 }) do Kit.lamp(hq, V(c.X + x, GROUND_Y, c.Z + 16.5)) end
	-- Planters removed to stay within the 4,500-part lobby budget after M22.7
	-- hero refinements added geometry; the arena entrance remains legible via
	-- corner marks and floor inlays alone.
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
	local face = CFrame.new(x, y, c.Z) * CFrame.Angles(0, math.pi / 2, 0)
	local panel = part(board, "ScoreboardPanel", V(56, 20, 1.2), face, HQ.navy, Enum.Material.Metal)
	panel.CastShadow = true
	Kit.block(board, "ScoreboardFrame", V(58, 22, 0.8), face * CFrame.new(0, 0, 0.9), HQ.steel, Enum.Material.Metal)
	for _, dy in ipairs({ -10.6, 10.6 }) do
		Kit.block(board, "ScoreboardTrim", V(57, 0.6, 1.4), face * CFrame.new(0, dy, -0.2), HQ.gold, Enum.Material.Metal)
	end
	for _, side in ipairs({-1, 1}) do
		Kit.block(board, "ScoreboardSide", V(0.6, 21, 1.4), face * CFrame.new(side * 28.5, 0, -0.2), HQ.gold, Enum.Material.Metal)
		Kit.block(board, "ScoreboardFoot", V(4.4, 1.2, 4.4), CFrame.new(x + 1, GROUND_Y + 0.6, c.Z + side * 27), HQ.steel, Enum.Material.Metal, true)
		Kit.beam(board, "ScoreboardBrace", face * V(side * 27, -2, 1), face * V(side * 23, -10.5, 1), 0.65, 0.85, HQ.gold, Enum.Material.Metal, true)
	end
	local gui = Instance.new("SurfaceGui")
	gui.Name, gui.Face, gui.LightInfluence = "Scores", Enum.NormalId.Front, 0
	gui.SizingMode, gui.CanvasSize, gui.Parent = Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(1120, 400), panel
	local screen = frame2d(gui, UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), HQ.white)
	screen.Name, screen.ClipsDescendants = "ArenaArtwork", true
	gradient(screen, Color3.fromRGB(42, 74, 113), Color3.fromRGB(14, 28, 51))
	-- The area's identity belongs to its mounted board. A tournament header,
	-- three coloured divisions and quiet podium art also fill an empty season.
	box(screen, 0.5, 0.135, 1, 0.27, HQ.navy)
	box(screen, 0.5, 0.274, 0.94, 0.008, HQ.gold)
	local trophy = box(screen, 0.075, 0.13, 0.08, 0.23, HQ.white, 0, nil, 1)
	SignArt.trophy(trophy, orange)
	local function arenaText(parent, name, pt, en, position, size, fontSize, color)
		local text = Instance.new("TextLabel")
		text.Name, text.BackgroundTransparency, text.Position, text.Size = name, 1, position, size
		text.Font, text.TextSize, text.TextColor3, text.Text = Enum.Font.FredokaOne, fontSize, color or HQ.white, pt
		text.TextXAlignment, text.TextYAlignment = Enum.TextXAlignment.Center, Enum.TextYAlignment.Center
		text.Parent = parent
		text:SetAttribute("LobbyTextPT", pt); text:SetAttribute("LobbyTextEN", en)
		return text
	end
	arenaText(screen, "ArenaTitle", "ARENA COMPETITIVA", "COMPETITIVE ARENA", UDim2.fromOffset(150, 6), UDim2.fromOffset(820, 58), 52, HQ.gold)
	arenaText(screen, "SeasonTitle", "MELHORES DA TEMPORADA • SOLO", "SEASON'S BEST • SOLO", UDim2.fromOffset(150, 65), UDim2.fromOffset(820, 30), 25, Color3.fromRGB(210, 226, 245))
	for index = 1, 3 do box(screen, 0.915 + index * 0.018, 0.13, 0.009, 0.12, orange, 20) end
	self.arenaColumns = {}
	local maps = {}
	for _, id in ipairs(self.catalog.DestinationOrder) do
		local def = self.catalog.Destinations[id]
		if def.modeId == "ranked" then table.insert(maps, def.mapId) end
	end
	for i, mapId in ipairs(maps) do
		local map = self.catalog.Maps[mapId]
		local tint = rgb(PORTAL_COLORS[mapId] or map.color)
		local column = Instance.new("Frame")
		column.Name, column.BackgroundColor3, column.BorderSizePixel = "Column_" .. mapId, HQ.white, 0
		column.Position, column.Size = UDim2.new((i - 1) / #maps, 18, 0, 121), UDim2.new(1 / #maps, -36, 0, 233)
		column.Parent = screen
		stroke(column, tint:Lerp(HQ.steel, 0.25), 3)
		gradient(column, tint:Lerp(HQ.navy, 0.78), HQ.navy)
		local ribbon = box(column, 0.5, 0.11, 0.99, 0.22, tint:Lerp(HQ.navy, 0.5))
		arenaText(ribbon, "MapTitle", upper(map.name.pt), upper(map.name.en), UDim2.fromScale(0.025, 0.1), UDim2.fromScale(0.95, 0.8), 29)
		local podium = box(column, 0.5, 0.56, 0.55, 0.5, HQ.white, 0, nil, 1)
		podium.Name, podium.Visible = "PodiumArtwork", false
		for rank, slot in ipairs({{0.5, 0.38}, {0.22, 0.64}, {0.78, 0.78}}) do
			box(podium, slot[1], 0.5 + slot[2] / 2, 0.23, 1 - slot[2], tint, 0, nil, 0.45)
		end
		local award = box(podium, 0.5, 0.28, 0.4, 0.66, HQ.white, 0, nil, 1)
		SignArt.trophy(award, tint)
		local rows = arenaText(column, "Rows", "Carregando…", "Loading…", UDim2.fromOffset(12, 67), UDim2.new(1, -24, 0, 154), 26, Color3.fromRGB(230, 240, 244))
		-- Five rows can contain full Roblox usernames. Scale their explicit
		-- lines together instead of wrapping a long name into the next rank.
		rows.Font, rows.TextWrapped, rows.TextScaled = Enum.Font.BuilderSansExtraBold, false, true
		table.insert(self.arenaColumns, { mapId = mapId, label = rows })
	end
	arenaText(screen, "ArenaFooter", "ENTRE NA FILA • SUPERE SEU RECORDE", "JOIN A QUEUE • BEAT YOUR RECORD", UDim2.fromOffset(16, 365), UDim2.new(1, -32, 0, 27), 24, HQ.gold)
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
	Kit.sign(hq, "AfkSign", CFrame.lookAt(V(c.X - 25, 22, c.Z - 1), V(HUB.X, 22, c.Z - 1)), 26, 7, {
		premium = true,
		title = { "ZONA AFK", "AFK ZONE" }, subtitle = { "FIQUE PARADO E GANHE", "STAND STILL AND EARN" },
		top = Color3.fromRGB(110, 150, 255), bottom = Color3.fromRGB(40, 50, 140), accent = Color3.fromRGB(120, 200, 255),
		art = "moon", artX = 0.18, artW = 0.3, titleX = 0.6, titleW = 0.72, legs = GROUND_Y,
	})
	-- Palms in round sand beds shade the lounge.
	-- Reduced to two palms to stay within the 4,500-part lobby budget after
	-- M22.7 Neon Heroes refinements added geometry to all 43 roster figures.
	for _, spot in ipairs({ { -20, -46, 0.4 }, { 20, -46, 2.6 } }) do
		local bed = V(c.X + spot[1], GROUND_Y, c.Z + spot[2])
		Kit.disc(hq, "PalmBed", bed + V(0, 0.2, 0), 5, 0.4, Color3.fromRGB(236, 214, 160), Enum.Material.Sand, true)
		Kit.palm(hq, bed + V(0, 0.4, 0), 1, spot[3]):SetAttribute("Planted", true)
	end
	Kit.cornerMarks(hq, c, width / 2 - 2, depth / 2 - 2, Color3.fromRGB(120, 200, 255), GROUND_Y + 0.05, 0)
end

function World:BuildMarket(lobby, hq)
	local V = Vector3.new
	local chests = { "rare", "base_epic" }
	for i, spec in ipairs(LAYOUT.market) do
		local at = polar(spec[1], spec[2], 0)
		local yaw = yawToward(at, HUB)
		-- The floor reaches past the entry pad toward the ring road.
		local floorAt = at + Vector3.new(math.sin(yaw), 0, math.cos(yaw)) * 3
		self:AreaFloor(hq, "MarketFloor", floorAt.X, floorAt.Z, 34, 40, yaw, HQ.stoneWarm)
		local _, zone = buildChestStand(lobby, at.X, at.Z, chests[i], self.catalog.Chests[chests[i]], self.openPanel, yaw)
		self.shopZones[chests[i]] = zone
	end
	-- The district's name stands behind the two halls, high enough to read over
	-- their headers from the plaza (at 28 studs its ends hid behind them).
	local signAt = polar(137.5, 142, 0)
	Kit.sign(hq, "SummonSign", CFrame.lookAt(signAt + V(0, 33, 0), V(HUB.X, 33, HUB.Z)), 32, 6, {
		title = { "INVOCAÇÃO", "SUMMONING" }, premium = true,
		top = Color3.fromRGB(255, 190, 90), bottom = Color3.fromRGB(190, 70, 150), accent = HQ.gold,
		titleX = 0.5, titleY = 0.5, titleW = 0.94, titleH = 0.7, legs = GRASS_Y,
	})
	-- The Robux kiosks line the tower plaza: the Stark shop.
	local showcase = self.catalog.Heroes.silversurfer
	for index, entry in ipairs(SHOP_STANDS) do
		local pass = entry.kind == "pass" and self.catalog.Products.Passes[entry.key]
		local displayName = pass and pass.name.pt or (entry.kind == "hero" and "Vitrine de Heróis" or "Cofre de Ouro")
		local displayEN = pass and pass.name.en or (entry.kind == "hero" and "Hero Showcase" or "Gold Vault")
		buildShopStand(lobby, HUB.X + LAYOUT.kiosks[index], HUB.Z + LAYOUT.kioskDz, entry.kind, entry.key, displayName, self.openPanel, entry.kind == "hero" and showcase or nil, displayEN)
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
	local agents = 0
	local function agent(frame)
		agents += 1
		-- The jointed figure, placed after it is anchored (see staticFigure).
		local made = Figure.Agent(outpost, agents)
		for _, item in ipairs(made.model:GetDescendants()) do
			if item:IsA("BasePart") then item.Anchored, item.CanCollide, item.CanQuery, item.CanTouch = true, false, false, false end
		end
		made.model:PivotTo(frame)
		-- A solid, invisible body: staff are not walked through.
		local body = Kit.block(outpost, "AgentBody", V(2.4, 6.4, 2.4), frame * CFrame.new(0, 3.2, 0), HQ.ink, Enum.Material.SmoothPlastic, true)
		body.Transparency = 1
	end
	-- A site's frame: local +Z faces the hub, local -Z is the back.
	local function site(position)
		return CFrame.new(position.X, GROUND_Y, position.Z) * CFrame.Angles(0, yawToward(position, HUB), 0)
	end
	-- Agents' figures face their local -Z, so they are turned to look the way
	-- a site does.
	local function standing(frame, x, z, turn) return frame * CFrame.new(x, 0, z) * CFrame.Angles(0, math.pi + (turn or 0), 0) end

	-- Every set piece is fenced in the same way so it reads as a finished
	-- compound: low concrete barriers with hazard stripes along the back and the
	-- two sides (the front stays open to the plaza), a lamp at each corner and
	-- traffic cones at the gap. Purely scenery.
	local function compound(S, halfX, backZ, frontZ)
		-- Continuous kerbs read as one compound and avoid fifty duplicated
		-- five-stud barriers; the geometry goes to the pedestrian plaza instead.
		local back = S * CFrame.new(0, 1.1, backZ)
		p("PerimeterBarrier", V(halfX * 2, 2.2, 1.4), back, pale, Enum.Material.Concrete)
		p("BarrierStripe", V(halfX * 2 + 0.04, 0.5, 1.44), back * CFrame.new(0, 0.5, 0), yellow)
		for _, side in ipairs({-1, 1}) do
			local length = frontZ - backZ - 8
			local frame = S * CFrame.new(side * halfX, 1.1, backZ + length / 2)
			p("PerimeterBarrier", V(1.4, 2.2, length), frame, pale, Enum.Material.Concrete)
			p("BarrierStripe", V(1.44, 0.5, length), frame * CFrame.new(0, 0.5, 0), yellow)
		end
		for _, corner in ipairs({ { -halfX, backZ }, { halfX, backZ }, { -halfX, frontZ - 3 }, { halfX, frontZ - 3 } }) do
			Kit.lamp(outpost, S * V(corner[1], 0, corner[2]), 8)
		end
		for _, side in ipairs({ -1, 1 }) do
			local cone = Kit.column(outpost, "TrafficCone", S * V(side * (halfX - 1.5), 0, frontZ - 6), 1.8, 1.1, Color3.fromRGB(255, 122, 40), Enum.Material.SmoothPlastic)
			cone.CanCollide = true
			Kit.column(outpost, "ConeBand", S * V(side * (halfX - 1.5), 0.9, frontZ - 6), 0.4, 1.12, white, Enum.Material.SmoothPlastic)
		end
	end

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
		compound(S, 18.2, -18, 18)
		Kit.flag(outpost, S * V(14, 0, 10), 12, blue, 4)
		for _, spot in ipairs({ { 14.5, -9 }, { 16, -6.5 } }) do
			Kit.column(outpost, "TireStack", S * V(spot[1], 0, spot[2]), 2.2, 2.4, Color3.fromRGB(34, 34, 38), Enum.Material.SmoothPlastic, true)
		end
		-- Scenery only: no title, so nobody expects a door to open.
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
		compound(S, 18.2, -18, 18)
		-- Scenery only: no title, so nobody expects a door to open.
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
		compound(S, 19, -16.2, 17)
		-- Scenery only: no title, so nobody expects a door to open.
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
		Kit.bridgeSupports(hq, a, b, 5.1, "IslandPier")
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
			Kit.block(hq, "RainbowBridge", V(12, 0.1, 1.5), CFrame.new(archX - 5, GROUND_Y + 0.05, walkZ - 5.25 + i * 1.5), color, Enum.Material.SmoothPlastic)
		end
		Kit.sign(hq, "ExpeditionSign", CFrame.lookAt(hubAt(-272, 81, 34), hubAt(-150, 81, 34)), 32, 8, {
			premium = true,
			title = { "EXPEDIÇÕES", "EXPEDITIONS" }, subtitle = { "SELVA • PONTE CELESTE", "JUNGLE • SKY BRIDGE" },
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
		Kit.sign(hq, "LatveriaSign", CFrame.lookAt(V(c.X + 21, 33, c.Z), V(HUB.X, 33, c.Z)), 30, 8, {
			premium = true,
			title = { "CIDADELA", "CITADEL" }, subtitle = { "EXPEDIÇÃO FINAL • 70 ONDAS", "FINAL EXPEDITION • 70 WAVES" },
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
		Kit.sign(hq, "AcademySign", CFrame.lookAt(V(c.X, 33, hallZ - 10), V(c.X, 33, HUB.Z)), 32, 8, {
			premium = true,
			title = { "ACADEMIA", "ACADEMY" }, subtitle = { "TREINO • CARTAS", "TRAINING • CARDS" },
			top = Color3.fromRGB(200, 150, 255), bottom = Color3.fromRGB(90, 50, 170), accent = violet,
			art = "target", artX = 0.14, artW = 0.24, titleX = 0.6, titleW = 0.74, legs = GROUND_Y,
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
		-- Reduced fixed trees to two to stay within the 4,500-part lobby budget
-- after M22.7 Neon Heroes refinements added geometry to all 43 roster figures.
for _, spot in ipairs({ { -60, -30, 1 }, { 60, -30, 0.9 } }) do Kit.tree(hq, V(c.X + spot[1], GRASS_Y, c.Z + spot[2]), spot[3]) end
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
		-- A cameo standing on the ground is a solid thing: an invisible body the
		-- size of the figure stops anyone walking through it.
		if not pedestal and foot.Y < 3 then
			local body = Kit.block(figure, "CameoBody", V(3 * scale, 8 * scale, 3 * scale), CFrame.new(ground + V(0, 4 * scale, 0)), HQ.ink, Enum.Material.SmoothPlastic, true)
			body.Transparency = 1
		end
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
		for band = 1, 1 do
			Kit.block(city, "SkylineBand", V(w + 0.6, 1.4, d + 0.6), CFrame.new(foot + V(0, h * band / 2, 0)), HQ.trim, Enum.Material.SmoothPlastic)
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
	for ring = 0, 2 do
		local radius = 112 + ring * 16
		local step = 360 / math.floor(2 * math.pi * radius / 17)
		for angle = rng:NextNumber(0, step), 360, step do
			local at = polar(angle + rng:NextNumber(-3, 3), radius + rng:NextNumber(-3, 3), GRASS_Y)
			if freeGrass(at.X, at.Z, 4) and rng:NextNumber() < 0.8 then
				local kind = rng:NextNumber()
				if kind < 0.12 then
					Kit.tree(hq, at, rng:NextNumber(0.85, 1.3), HQ.leaf:Lerp(Color3.fromRGB(40, 150, 90), rng:NextNumber(0, 0.6)))
				elseif kind < 0.18 then
					Kit.palm(hq, at, rng:NextNumber(0.9, 1.2), rng:NextNumber(0, 6.28))
				end
				Kit.bush(hq, at + V(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4)), rng:NextNumber(2.5, 4))
			end
		end
	end
	-- The old tiny beds beside the moat were too far away to read. Four
	-- generous gardens frame the star, with clear compass routes between them.
	for _, angle in ipairs({45, 135, 225, 315}) do
		Kit.crescentGarden(hq, HUB + V(0, GROUND_Y, 0), math.rad(angle), true)
	end
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
			if zone.membrane then zone.membrane.Color=state.count>=4 and Color3.fromRGB(150,52,60) or (zone.well or zone.tint) end
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
			local empty = #lines == 0
			local pt = empty and "Seja o primeiro!" or table.concat(lines,"\n")
			local en = empty and "Be the first!" or pt
			column.label.Text = pt
			column.label:SetAttribute("LobbyTextPT", pt); column.label:SetAttribute("LobbyTextEN", en)
			column.label.TextXAlignment = empty and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left
			column.label.TextYAlignment = empty and Enum.TextYAlignment.Center or Enum.TextYAlignment.Top
			column.label.Position = UDim2.fromOffset(12, empty and 187 or 67)
			column.label.Size = UDim2.new(1, -24, 0, empty and 34 or 154)
			local art = column.label.Parent:FindFirstChild("PodiumArtwork")
			if art then art.Visible = empty end
		end
	end
end

-- Called on a slow server timer with the top rows for a representative
-- board; the totem is shared scenery, so it shows one public leaderboard
-- rather than trying to be personal to whoever is looking at it.
function World:UpdateLeaderboardBoard(rows, mapName)
	if not self.leaderboardText then return end
	-- A single record invites interaction; the full ranking belongs in its panel.
	local first = (rows or {})[1]
	local pt, en = "Seu nome pode estar aqui", "Your name could be here"
	if first then
		local shown = string.gsub(tostring(first.name or first.userId), "[<>&]", "")
		pt = string.format("#%d %s • %d %s", first.rank, shown, first.waves, first.waves == 1 and "onda" or "ondas")
		en = string.format("#%d %s • %d %s", first.rank, shown, first.waves, first.waves == 1 and "wave" or "waves")
	end
	self.leaderboardText:SetAttribute("LobbyTextPT", pt)
	self.leaderboardText:SetAttribute("LobbyTextEN", en)
	self.leaderboardText.Text = pt
	local hint = self.leaderboardText.Parent:FindFirstChild("Hint")
	if hint then
		hint:SetAttribute("LobbyTextPT", "Toque para ver o ranking")
		hint:SetAttribute("LobbyTextEN", "Tap to view the ranking")
		hint.Text = "Toque para ver o ranking"
	end
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
		ground = { Enum.Material.Ground, Color3.fromRGB(112, 108, 80) },
		patches = { { Enum.Material.Grass, Color3.fromRGB(104, 150, 64) }, { Enum.Material.Concrete, Color3.fromRGB(150, 154, 146) } },
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
		ground = { Enum.Material.Concrete, Color3.fromRGB(118, 104, 96) },
		patches = { { Enum.Material.Asphalt, Color3.fromRGB(78, 70, 66) }, { Enum.Material.Slate, Color3.fromRGB(96, 84, 78) } },
		road = { Enum.Material.DiamondPlate, Color3.fromRGB(46, 48, 54) },
		walk = { Enum.Material.Concrete, Color3.fromRGB(108, 98, 92) },
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
	{ "FERRO INDÚSTRIAS", { 255, 196, 72 } }, { "NOTÍCIAS DA CIDADE", { 255, 90, 90 } }, { "NEO CORP", { 110, 220, 255 } },
	{ "MULTIVERSO", { 240, 240, 255 } }, { "AGÊNCIA", { 140, 200, 255 } }, { "QUANTUM TECH", { 255, 120, 150 } },
	{ "ÓRBITA", { 255, 160, 60 } }, { "VOLT ENERGIA", { 120, 170, 255 } },
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
		local set = string.format("%.1f:%.1f", spot.X, spot.Z)
		for _, lateral in ipairs({ -w / 3, w / 3 }) do
			prop(folder, "BillboardLeg", Vector3.new(0.35, 1.6, 0.35), face * CFrame.new(lateral, height + 1.7, 2.3), Color3.fromRGB(40, 42, 46), Enum.Material.Metal):SetAttribute("BillboardSet", set)
		end
		local panel = prop(folder, "Billboard", Vector3.new(w, h, 0.4), panelCf, Color3.fromRGB(18, 20, 30), Enum.Material.SmoothPlastic)
		panel:SetAttribute("BillboardSet", set)
		for _, edge in ipairs({ -1, 1 }) do
			prop(folder, "BillboardTrim", Vector3.new(w + 0.4, 0.3, 0.5), panelCf * CFrame.new(0, edge * (h / 2 + 0.1), -0.02), tint, Enum.Material.Neon):SetAttribute("BillboardSet", set)
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

-- Oriented boxes ({c = centre, a = three unit axes, h = three half sizes})
-- that intersect, by the separating-axis test.
local function boxesOverlap(A, B)
	local function dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
	local axes = {}
	for _, u in ipairs(A.a) do table.insert(axes, u) end
	for _, u in ipairs(B.a) do table.insert(axes, u) end
	for _, u in ipairs(A.a) do for _, w in ipairs(B.a) do
		local c = u:Cross(w)
		if c.Magnitude > 1e-6 then table.insert(axes, c.Unit) end
	end end
	local d = B.c - A.c
	for _, axis in ipairs(axes) do
		local ra, rb = 0, 0
		for i = 1, 3 do ra += A.h[i] * math.abs(dot(A.a[i], axis)); rb += B.h[i] * math.abs(dot(B.a[i], axis)) end
		if math.abs(dot(d, axis)) > ra + rb then return false end
	end
	return true
end
local function partBox(p)
	return { c = p.Position, a = { p.CFrame.RightVector, p.CFrame.UpVector, p.CFrame.LookVector }, h = { p.Size.X / 2, p.Size.Y / 2, p.Size.Z / 2 } }
end

-- A rooftop billboard at a street corner can have the next street's corner
-- building, taller, standing right in front of it (owner, 16/10: nothing may
-- hide a sign's letters). Such a billboard, its trims and its legs go.
local function clearBlockedBillboards(folder)
	local bodies, sets = {}, {}
	for _, item in ipairs(folder:GetChildren()) do
		if item:IsA("BasePart") then
			if item.Name == "Skyline" then table.insert(bodies, item) end
			local set = item:GetAttribute("BillboardSet")
			if set then sets[set] = sets[set] or {}; table.insert(sets[set], item) end
		end
	end
	for _, pieces in pairs(sets) do
		for _, panel in ipairs(pieces) do
			if panel.Name == "Billboard" then
				local n = panel.CFrame.LookVector
				local front = { c = panel.Position + n * (panel.Size.Z / 2 + 3.05), a = { panel.CFrame.RightVector, panel.CFrame.UpVector, n },
					h = { panel.Size.X / 2 * 0.92, panel.Size.Y / 2 * 0.86, 3 } }
				for _, body in ipairs(bodies) do
					if boxesOverlap(front, partBox(body)) then
						for _, piece in ipairs(pieces) do piece:Destroy() end
						break
					end
				end
			end
		end
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
	clearBlockedBillboards(folder)
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
		table.insert(self.blockSpots, spot)
		BLOCKS[kinds[(index - 1) % #kinds + 1]](folder, theme, rng, spot[1], spot[2])
	end
end

--==============================================================================
-- Ground detail: tufts, pebbles and stains scattered over the open ground, so a
-- map is not one flat colour seen from above. Each is a tiny model in the
-- Clutter folder, which a tower's platform clears (World:ClearClutter).
--==============================================================================
local function buildGroundScatter(self, mapId, theme, streets, rng)
	local ground = theme.ground[2]
	local grassy = theme.ground[1] == Enum.Material.Grass or theme.ground[1] == Enum.Material.LeafyGrass
	local spots = self.blockSpots or {}
	local made, tries = 0, 0
	while made < 64 and tries < 600 do
		tries += 1
		local x, z = rng:NextNumber(-100, 100), rng:NextNumber(-100, 100)
		local clear = true
		for _, s in ipairs(streets) do
			if insideStreet(s, x, z, WALK + 5) then clear = false break end
		end
		for _, spot in ipairs(spots) do
			if (spot[1] - x) ^ 2 + (spot[2] - z) ^ 2 < 18 * 18 then clear = false break end
		end
		if (x * x + z * z) < 14 * 14 then clear = false end
		if clear then
			made += 1
			local kind = rng:NextInteger(1, 10)
			local model = clutterModel(self, "GroundDetail", x, z, 1.4)
			if grassy and kind <= 6 then
				-- A tuft: three blades of lawn leaning apart.
				local leaf = ground:Lerp(Color3.fromRGB(120, 190, 80), 0.35 + rng:NextNumber() * 0.25)
				for blade = 1, 3 do
					local a = blade * 2.1 + rng:NextNumber()
					Kit.blob(model, "Tuft", Vector3.new(0.55, 0.6, 0.55), CFrame.new(x + math.cos(a) * 0.35, 0.1, z + math.sin(a) * 0.35) * CFrame.Angles(math.sin(a) * 0.25, 0, math.cos(a) * 0.25), leaf, Enum.Material.Grass)
				end
			elseif kind <= 8 then
				-- Pebbles: a big one and a small one.
				local stone = theme.curb[2]:Lerp(ground, 0.4)
				Kit.blob(model, "Pebble", Vector3.new(1.4, 0.6, 1.1), CFrame.new(x, 0.1, z) * CFrame.Angles(0, rng:NextNumber() * 3, 0), stone, Enum.Material.Slate)
				Kit.blob(model, "Pebble", Vector3.new(0.7, 0.4, 0.6), CFrame.new(x + 1.1, 0.08, z + 0.5), stone:Lerp(Color3.new(0, 0, 0), 0.15), Enum.Material.Slate)
			else
				-- A stain or a worn patch: a flat disc a shade off the ground.
				local disc = Kit.disc(model, "Stain", Vector3.new(x, 0.06, z), rng:NextNumber(2.4, 4.2), 0.05, ground:Lerp(Color3.new(0, 0, 0), 0.18 + rng:NextNumber() * 0.12), Enum.Material.Slate)
				disc.CanCollide = false
			end
			for _, item in ipairs(model:GetDescendants()) do
				if item:IsA("BasePart") then item.CanCollide, item.CanTouch, item.CanQuery, item.CastShadow = false, false, false, false end
			end
		end
	end
end

function World:DressMap(mapId, map)
	local theme = STREET_THEME[mapId] or STREET_THEME.manhattan
	local rng = Random.new(map.chapter * 977 + 13)
	local streets = streetsOf(map)
	self.streets = streets
	self.blockSpots = {}
	buildTerrain(self, map, theme, rng)
	buildStreets(self, map, theme, streets)
	buildBlocks(self, mapId, theme, streets, rng)
	buildSidewalks(self, map, theme, streets, rng)
	buildOuterRing(self, map, theme, streets, rng)
	buildCityWall(self, map, theme, streets, rng)
	buildGroundScatter(self, mapId, theme, streets, rng)
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
	-- Saturated paint, not pale light: under a bright sky a pale strip read as a glowing tube.
	local routeColors={manhattan=Color3.fromRGB(255,184,62),gamma=Color3.fromRGB(96,232,118),hydra=Color3.fromRGB(255,116,86),wakanda=Color3.fromRGB(186,124,255),latveria=Color3.fromRGB(84,206,255),asgard=Color3.fromRGB(112,210,255)}
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
			strip.Transparency=0.3
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
	-- The trim is a thin lit border round the tier, not a lit slab: a 14-stud
	-- square of neon washed the whole core into one cyan blob from the camera.
	for _, edge in ipairs({ { 0, -7, 14.4, 0.5 }, { 0, 7, 14.4, 0.5 }, { -7, 0, 0.5, 13.4 }, { 7, 0, 0.5, 13.4 } }) do
		local trim = part(self.Scenery, "CoreTrim", Vector3.new(edge[3], 0.25, edge[4]), CFrame.new(coreX + edge[1], 2.1, coreZ + edge[2]), coreTint, Enum.Material.Neon)
		trim.CanCollide = false
	end
	for _, corner in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
		part(self.Scenery, "CoreButtress", Vector3.new(1.6, 7, 1.6), CFrame.new(coreX + corner[1] * 6.6, 3.5, coreZ + corner[2] * 6.6), Color3.fromRGB(58, 78, 94), Enum.Material.Metal).CanCollide = true
		-- A metal cap with a lit band under it, so the four corners read as
		-- pylons and not as four glowing cubes.
		local cap = part(self.Scenery, "CoreButtressCap", Vector3.new(2.2, 0.5, 2.2), CFrame.new(coreX + corner[1] * 6.6, 7.1, coreZ + corner[2] * 6.6), Color3.fromRGB(84, 108, 126), Enum.Material.Metal)
		cap.CanCollide = false
		local band = part(self.Scenery, "CoreTrim", Vector3.new(1.75, 0.3, 1.75), CFrame.new(coreX + corner[1] * 6.6, 6.65, coreZ + corner[2] * 6.6), coreTint, Enum.Material.Neon)
		band.CanCollide = false
	end
	local base = part(self.Scenery, "ResistanceCore", Vector3.new(9, 8, 9), CFrame.new(coreX, 6, coreZ), Color3.fromRGB(62, 193, 235), Enum.Material.Glass)
	base.Shape=Enum.PartType.Ball
	base.CanCollide, base.Transparency = true, 0.25
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
	World.TameNeon(self.Scenery)
end

function World:UpdateBase(index, base, core, ownerId)
	local name="PlayerBase_"..index
	local old=self.Scenery:FindFirstChild(name); if old then old:Destroy() end
	local model=Instance.new("Model"); model.Name=name; model.Parent=self.Scenery
	local def=self.catalog.Bases[base.id]; local tint=Color3.fromRGB(unpack(def.color))
	local offsets={{-12,-12},{12,-12},{-12,12},{12,12}}
	local at=Vector3.new(math.clamp(core.X+offsets[index][1],-100,100),0,math.clamp(core.Z+offsets[index][2],-100,100))
	-- The body of the outpost is solid (a commander walks around it, not through
	-- it); lamps, crops and trim stay passable.
	local SOLID={Foundation=true,Building=true,Roof=true,WallSection=true,Turret=true}
	local function block(key,size,offset,color,material)
		local p=part(model,key,size,CFrame.new(at+offset),color or tint,material or Enum.Material.Metal)
		p.CanCollide=SOLID[key]==true; return p
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
	elseif def.style=="frost" then
		-- The ice field on the ground, as wide as its slow reaches (the base
		-- range), and ice spires around a cryo core that grow with the level.
		local radius=base.stats and base.stats.range or 30
		local field=part(model,"FrostField",Vector3.new(0.1,radius*2,radius*2),CFrame.new(at+Vector3.new(0,0.32,0))*CFrame.Angles(0,0,math.pi/2),tint,Enum.Material.ForceField)
		field.Shape,field.Transparency=Enum.PartType.Cylinder,0.35
		field.CanCollide,field.CanQuery,field.CanTouch=false,false,false
		for i,spot in ipairs({{-3,-3.4},{3,-3.4},{-3.7,2.4},{3.7,2.4}}) do
			local height=2.2+base.level*0.45+(i%2)*0.6
			block("IceSpire",Vector3.new(1.1,height,1.1),Vector3.new(spot[1],1+height/2,spot[2]),tint:Lerp(Color3.new(1,1,1),0.3),Enum.Material.Ice)
		end
		local cryo=block("CryoCore",Vector3.new(1.8,1.8,1.8),Vector3.new(0,6.2+base.level*0.2,0),tint,Enum.Material.Neon)
		cryo.Shape=Enum.PartType.Ball
	elseif def.style=="vault" then
		-- A round vault door with its wheel, and gold bars that pile up with the level.
		local door=part(model,"VaultDoor",Vector3.new(0.5,3,3),CFrame.new(at+Vector3.new(0,2.9,-2.75))*CFrame.Angles(0,math.pi/2,0),Color3.fromRGB(150,156,170),Enum.Material.DiamondPlate)
		door.Shape,door.CanCollide=Enum.PartType.Cylinder,false
		local wheel=part(model,"VaultWheel",Vector3.new(0.3,1.5,1.5),CFrame.new(at+Vector3.new(0,2.9,-3.1))*CFrame.Angles(0,math.pi/2,0),tint,Enum.Material.Metal)
		wheel.Shape,wheel.CanCollide=Enum.PartType.Cylinder,false
		for n=1,base.level+1 do
			block("GoldBar",Vector3.new(1.3,0.45,0.65),Vector3.new(-3.6+((n-1)%3)*1.4,1.23+math.floor((n-1)/3)*0.47,-3.6),Color3.fromRGB(255,204,72),Enum.Material.Metal)
		end
	end
	-- Both languages ride along; each client shows its own (see init.client).
	local baseName=label(building,def.name.pt.." • "..base.level.."/5",Vector3.new(0,6,0),tint)
	baseName:SetAttribute("LobbyTextPT",def.name.pt.." • "..base.level.."/5")
	baseName:SetAttribute("LobbyTextEN",def.name.en.." • "..base.level.."/5")
	-- The base agent: the only place a base is upgraded. Pressing E beside the
	-- agent opens the upgrade (the client listens for the prompt); the server
	-- still decides everything when the upgrade is requested.
	do
		local frame=CFrame.new(at+Vector3.new(3.1,1,3.5))*CFrame.Angles(0,math.pi,0)
		local made=Figure.Agent(model,index)
		for _,item in ipairs(made.model:GetDescendants()) do
			if item:IsA("BasePart") then item.Anchored,item.CanCollide,item.CanQuery,item.CanTouch=true,false,false,false end
		end
		made.model.Name="BaseAgent"
		made.model:PivotTo(frame)
		local ring=part(model,"AgentRing",Vector3.new(0.15,4.6,4.6),CFrame.new(at+Vector3.new(3.1,1.1,3.5))*CFrame.Angles(0,0,math.pi/2),tint,Enum.Material.Neon)
		ring.Shape,ring.CanCollide,ring.Transparency=Enum.PartType.Cylinder,false,0.35
		local anchor=part(model,"AgentTrigger",Vector3.new(2.4,6.4,2.4),frame*CFrame.new(0,3.2,0),tint,Enum.Material.SmoothPlastic)
		-- Invisible but solid: the agent is a person, not a hologram to walk through.
		anchor.Transparency,anchor.CanCollide,anchor.CanQuery=1,true,false
		local prompt=Instance.new("ProximityPrompt")
		prompt.Name,prompt.ActionText,prompt.ObjectText="BaseUpgradePrompt","Evoluir base / Upgrade base","Agente da Base / Base Agent"
		-- Each client shows the prompt in its own language (see init.client, PromptShown).
		prompt:SetAttribute("ActionPT","Evoluir base"); prompt:SetAttribute("ActionEN","Upgrade base")
		prompt:SetAttribute("ObjectPT","Agente da Base"); prompt:SetAttribute("ObjectEN","Base Agent")
		prompt.MaxActivationDistance,prompt.HoldDuration,prompt.RequiresLineOfSight=14,0,false
		prompt:SetAttribute("BaseOwnerId",ownerId or 0)
		prompt.Parent=anchor
	end
	World.TameNeon(model)
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

-- options.shiny: the commander owns the shiny copy of this hero (a collectible
-- finish, no stat change): the figure gleams and sheds a few gold sparks, so
-- the shine from the collection card is seen on the battlefield too.
function World:MakeTower(id, heroId, position, ownerId, options)
	local hero = self.catalog.Heroes[heroId]
	local model = Instance.new("Model")
	model.Name = heroId .. "_" .. id
	model:SetAttribute("TowerId", id) model:SetAttribute("OwnerId", ownerId) model:SetAttribute("HeroId", heroId)
	local shiny = type(options) == "table" and options.shiny == true
	if shiny then model:SetAttribute("Shiny", true) end
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
	local inset = part(model, "PlatformInset", Vector3.new(0.06, 4.1, 4.1), CFrame.new(position.X, 0.6, position.Z)*flat, color:Lerp(Color3.fromRGB(30, 35, 48), 0.7), Enum.Material.Metal)
	skirt.Shape, inset.Shape = Enum.PartType.Cylinder, Enum.PartType.Cylinder
	inset.Transparency = 0
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
	if shiny then
		local figureModel = model:FindFirstChild("HeroFigure")
		for _, piece in ipairs(figureModel and figureModel:GetDescendants() or {}) do
			if piece:IsA("BasePart") and piece.Name ~= "HumanoidRootPart" then piece.Reflectance = math.max(piece.Reflectance, 0.22) end
		end
		if head then emitter(head, Color3.fromRGB(255, 214, 110), 2.5, 1.2, 0.35, 1.4, Vector3.new(0, 1.2, 0)) end
	end
	-- The figure's own parts take no clicks (they are never queried), so an
	-- invisible box as tall as the hero lets a tap or click land on the hero
	-- itself, not just on the circle under its feet.
	local figure = model:FindFirstChild("HeroFigure")
	local height = figure and tonumber(figure:GetAttribute("FigureHeight")) or 6.5
	local hitbox = part(model, "TowerHitbox", Vector3.new(4.4, height + 1, 4.4), CFrame.new(position.X, 0.55 + (height + 1) / 2, position.Z), color, Enum.Material.SmoothPlastic)
	hitbox.Transparency, hitbox.CanCollide, hitbox.CanTouch, hitbox.CanQuery = 1, false, false, true
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

-- Where a commander stands at the start of a match: on open ground just beside
-- their own base, clear of the core and of every other base (they are solid).
function World:CommanderSpot(index)
	local fallback = Vector3.new(-18 + (index or 1) * 8, 4, 80)
	local scenery = self.Scenery
	local mine = scenery and scenery:FindFirstChild("PlayerBase_" .. tostring(index or 1))
	local foundation = mine and mine:FindFirstChild("Foundation")
	if not foundation then return fallback end
	local obstacles = {}
	if self.base then table.insert(obstacles, { self.base.Position, 8.5 }) end
	for other = 1, 4 do
		local base = other ~= index and scenery:FindFirstChild("PlayerBase_" .. other)
		local piece = base and base:FindFirstChild("Foundation")
		if piece then table.insert(obstacles, { piece.Position, 8.5 }) end
	end
	local center = foundation.Position
	for _, offset in ipairs({ { 0, 9 }, { 0, -9 }, { 9, 0 }, { -9, 0 }, { 9, 9 }, { -9, -9 }, { 9, -9 }, { -9, 9 } }) do
		local spot = Vector3.new(center.X + offset[1], 4, center.Z + offset[2])
		local clear = math.abs(spot.X) <= 104 and math.abs(spot.Z) <= 104
		for _, obstacle in ipairs(obstacles) do
			local flat = Vector3.new(spot.X - obstacle[1].X, 0, spot.Z - obstacle[1].Z)
			if flat.Magnitude < obstacle[2] then clear = false end
		end
		if clear then return spot end
	end
	return fallback
end

function World:MovePlayer(player, inMatch, index)
	local function move(character)
		local hrp = character:WaitForChild("HumanoidRootPart", 8)
		if not hrp then return end
		local pos = inMatch and self:CommanderSpot(index) or self.lobbySpawn
		character:PivotTo(CFrame.new(pos))
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local movement = self.catalog.Movement
			humanoid.WalkSpeed, humanoid.MaxHealth, humanoid.Health = movement.walk, 100000, 100000
			humanoid.UseJumpPower, humanoid.JumpPower = true, movement.jumpPower
		end
		for _, item in ipairs(character:GetDescendants()) do
			if item:IsA("BasePart") then item.CollisionGroup = "Commanders" end
		end
	end
	if player.Character then task.spawn(move, player.Character) end
end

return World
