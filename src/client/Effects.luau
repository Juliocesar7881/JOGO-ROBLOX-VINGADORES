local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Catalog = require(ReplicatedStorage:WaitForChild("DoomShared"):WaitForChild("Catalog"))
local UI = require(script.Parent:WaitForChild("UI"))

local Effects = {}
Effects.__index = Effects

local function part(parent, size, color, material)
	local p = Instance.new("Part")
	p.Size, p.Color, p.Material = size, color, material or Enum.Material.SmoothPlastic
	p.Anchored, p.CanCollide, p.CanTouch, p.CanQuery = true, false, false, false
	p.CastShadow = false
	p.Parent = parent
	return p
end

-- Infected used to be people: each one keeps whatever it was wearing.
local SHIRTS = {
	Color3.fromRGB(176, 58, 52), Color3.fromRGB(58, 96, 160), Color3.fromRGB(214, 190, 120), Color3.fromRGB(92, 128, 72),
	Color3.fromRGB(226, 226, 218), Color3.fromRGB(122, 74, 150), Color3.fromRGB(230, 140, 50), Color3.fromRGB(64, 64, 72),
}
local PANTS = { Color3.fromRGB(48, 66, 104), Color3.fromRGB(34, 38, 43), Color3.fromRGB(110, 96, 70), Color3.fromRGB(70, 74, 82) }

local function artTemplate(kind, id)
	local art = ReplicatedStorage:FindFirstChild("DoomArt")
	local folder = art and art:FindFirstChild(kind)
	local template = folder and id and folder:FindFirstChild(id)
	return template and template:IsA("Model") and template or nil
end

-- An animation id stored as an attribute on the art model, loaded once.
local function artTrack(record, holder, key)
	record.tracks = record.tracks or {}
	if record.tracks[key] ~= nil then return record.tracks[key] or nil end
	local id = tonumber(holder:GetAttribute(key)) or 0
	local track = false
	if id > 0 and record.animator then
		local ok, loaded = pcall(function()
			local animation = Instance.new("Animation")
			animation.AnimationId = "rbxassetid://" .. tostring(math.floor(id))
			return record.animator:LoadAnimation(animation)
		end)
		if ok and loaded then track = loaded end
	end
	record.tracks[key] = track
	return track or nil
end

local function playArt(record, holder, key, looped)
	local track = artTrack(record, holder, key)
	if track then pcall(function() track.Looped = looped == true; track:Play() end) end
end

-- Final art for an enemy: pivot at the feet, animated only by its Animator
-- (WalkAnimation); the record keeps the fields every enemy record has.
local function buildArtEnemy(def, template)
	local model = template:Clone()
	model.Name = "EnemyVisual"
	local pieces, torso = {}, model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	for _, piece in ipairs(model:GetDescendants()) do
		if piece:IsA("BasePart") then
			piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
			table.insert(pieces, {part = piece, rest = piece.CFrame, transparency = piece.Transparency or 0})
		end
	end
	local _, size = model:GetBoundingBox()
	local scale = math.max(0.5, (size and size.Y or 4.4) / 4.4)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(def.boss and 108 or 45, 8)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, (size and size.Y or 4.4) + 0.6, 0)
	billboard.AlwaysOnTop, billboard.MaxDistance, billboard.Adornee, billboard.Parent = true, 180, torso, model
	local bg = UI.frame(billboard, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(22, 19, 26)})
	UI.corner(bg, 3)
	local hp = UI.frame(bg, {Name = "HP", Size = UDim2.fromScale(1, 1), BackgroundColor3 = def.boss and UI.Colors.red or UI.Colors.green})
	UI.corner(hp, 3)
	local status = UI.label(billboard, "", {Name="Status", Position=UDim2.new(0.5,-75,0,-19), Size=UDim2.fromOffset(150,17),
		TextSize=11, TextColor3=UI.Colors.gold, TextStrokeTransparency=0.25, Visible=false})
	local record = {
		model = model, bar = hp, status = status, scale = scale, def = def, lastHP = nil, art = true,
		legs = nil, arms = {}, wings = {}, legHeight = 0, pieces = pieces, billboard = billboard,
		flashParts = { torso and { part = torso, color = torso.Color } or nil }, flashUntil = nil,
	}
	local controller = model:FindFirstChildWhichIsA("AnimationController", true) or model:FindFirstChildWhichIsA("Humanoid", true)
	record.animator = controller and controller:FindFirstChildOfClass("Animator") or nil
	playArt(record, model, "WalkAnimation", true)
	return record
end

-- Enemies share the heroes' vinyl-toy look: every volume is an ellipsoid (a
-- block with a sphere mesh keeps its exact proportions). A common enemy stays
-- near sixteen parts, because up to 180 of them move every frame; only the
-- one boss on the field spends more.
local function blob(parent, name, size, cf, color, material)
	local p = part(parent, size, color, material)
	p.Name, p.CFrame = name, cf
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

local INFECTED_EYES, INK, BONE = Color3.fromRGB(163, 255, 88), Color3.fromRGB(28, 22, 26), Color3.fromRGB(232, 226, 204)
-- Each boss's own body colours, eye glow and face.
local BOSS_LOOK = {
	lizard = { torso = Color3.fromRGB(96, 170, 70), head = Color3.fromRGB(113, 205, 85), arm = Color3.fromRGB(96, 170, 70),
		leg = Color3.fromRGB(84, 54, 120), eye = Color3.fromRGB(255, 214, 60), noJaw = true },
	abomination = { torso = Color3.fromRGB(128, 132, 74), head = Color3.fromRGB(150, 150, 84), arm = Color3.fromRGB(128, 132, 74),
		leg = Color3.fromRGB(58, 52, 44), eye = Color3.fromRGB(255, 140, 50) },
	redskull = { torso = Color3.fromRGB(38, 34, 40), head = Color3.fromRGB(206, 52, 44), arm = Color3.fromRGB(38, 34, 40),
		leg = Color3.fromRGB(38, 34, 40), eye = Color3.fromRGB(255, 90, 60), eyeSize = Vector3.new(0.13, 0.15, 0.14), noJaw = true },
	killmonger = { torso = Color3.fromRGB(34, 32, 38), head = Color3.fromRGB(212, 166, 71), arm = Color3.fromRGB(34, 32, 38),
		leg = Color3.fromRGB(34, 32, 38), eye = Color3.fromRGB(255, 240, 190), eyeSize = Vector3.new(0.3, 0.17, 0.14), noJaw = true },
	loki = { torso = Color3.fromRGB(30, 44, 36), head = Color3.fromRGB(226, 206, 184), arm = Color3.fromRGB(30, 44, 36),
		leg = Color3.fromRGB(30, 34, 32), eye = Color3.fromRGB(120, 255, 150), eyeSize = Vector3.new(0.18, 0.2, 0.14) },
	doom = { torso = Color3.fromRGB(108, 118, 126), head = Color3.fromRGB(150, 160, 166), arm = Color3.fromRGB(108, 118, 126),
		leg = Color3.fromRGB(98, 108, 116), eye = Color3.fromRGB(110, 255, 150), noJaw = true, material = Enum.Material.Metal },
}

local function buildEnemy(def)
	local template = artTemplate("Enemies", def.id) or artTemplate("Enemies", def.family)
	if template then return buildArtEnemy(def, template) end
	local family = def.family or def.id
	local model = Instance.new("Model")
	model.Name = "EnemyVisual"
	local color = UI.color(def.color)
	local scale = def.boss and 2.1 or (family == "brute" and 1.45 or 1)
	-- Only the plain infected varies in height: other families hang props
	-- at fixed offsets that a different scale would leave floating.
	if def.id == "zombie" then scale *= 0.93 + math.random() * 0.14 end
	local V = Vector3.new
	local look = def.boss and BOSS_LOOK[def.id] or nil
	local shambler, brute, hulking = family == "zombie", family == "brute", def.id == "abomination"
	-- Model space: feet on y = 0, the torso's centre at y = 2 (the runtime
	-- lifts the pivot by 2 * scale), the face toward -Z. Sizes are unscaled.
	local function at(x, y, z) return CFrame.new(x * scale, y * scale, z * scale) end
	local function add(name, size, cf, tint, material) return blob(model, name, size * scale, cf, tint, material) end
	local bulk = brute and 1.2 or (hulking and 1.3 or (def.boss and 1.08 or 1))
	-- The infected used to be people: the torso is the torn shirt each one
	-- still wears, the belly showing through; brutes burst out of theirs.
	local shirtColor = not def.boss and not brute and SHIRTS[math.random(1, #SHIRTS)] or nil
	local bodyMaterial = look and look.material or nil
	local torso = add("Torso", V(1.9 * bulk, 1.9, 1.15 * bulk), at(0, 2, 0), shirtColor or (look and look.torso) or color, bodyMaterial)
	model.PrimaryPart = torso
	local stooped = brute or hulking
	local headSize = stooped and V(1.1, 1.05, 1.05) or V(1.3, 1.25, 1.2)
	local headY, headZ = stooped and 3.15 or 3.45, stooped and -0.4 or -0.05
	local head = add("Head", headSize, at(0, headY, headZ), look and look.head or color:Lerp(Color3.fromRGB(135, 174, 115), 0.35))
	-- A point on the face: x across, dy up from the head's centre, out = how
	-- far it stands proud of the surface.
	local hr = headSize / 2
	local function face(x, dy, out)
		local k = math.max(1 - (x / hr.X) ^ 2 - (dy / hr.Y) ^ 2, 0.04)
		return at(x, headY + dy, headZ - hr.Z * math.sqrt(k) - (out or 0))
	end
	local glow = look and look.eye or INFECTED_EYES
	for _, x in ipairs({ -1, 1 }) do
		-- The infected stare with one eye wider than the other.
		local size = look and look.eyeSize or (shambler and x < 0 and V(0.32, 0.34, 0.14) or V(0.24, 0.27, 0.14))
		add("Eye", size, face(x * 0.43 * hr.X, 0.08 * hr.Y / 0.625), glow, Enum.Material.Neon)
	end
	if not (look and look.noJaw) then add("Jaw", V(0.5, 0.2, 0.14) * (hr.X / 0.65), face(0, -0.3 * hr.Y / 0.625), INK) end
	if not def.boss then
		-- A heavy brow turns a round toy face into a hostile one.
		add("Brow", V(0.95, 0.2, 0.26) * (hr.X / 0.65), face(0, 0.3 * hr.Y / 0.625, -0.04), color:Lerp(INK, 0.45))
	end
	local shirt
	if shirtColor then
		shirt = add("Belly", V(1.2, 0.75, 0.45), at(0, 1.45, -0.38), color)
		add("Tear", V(0.4, 0.35, 0.2), at(0.45, 2.5, -0.42), color)
		if def.id == "zombie" and math.random() < 0.55 then
			add("Hair", V(1.26, 0.6, 1.16), at(0.06, headY + 0.42, headZ + 0.08) * CFrame.Angles(-0.12, 0, 0.1),
				Color3.fromRGB(math.random(30, 90), math.random(22, 60), math.random(18, 40)), Enum.Material.SmoothPlastic)
		end
	end
	local legHeight = 1.5 * scale
	local legs, arms, wings = {}, {}, {}
	local torsoInverse = torso.CFrame:Inverse()
	local armColor = look and look.arm or color:Lerp(Color3.new(), 0.15)
	local pants = look and look.leg or PANTS[math.random(1, #PANTS)]
	local armSize = stooped and V(0.82, 1.7, 0.84) or V(0.52, 1.55, 0.54)
	local limbOf = { arm = {}, leg = {} }
	for _, x in ipairs({ -1, 1 }) do
		local arm
		if shambler then
			-- The classic shamble: both arms reaching for the core ahead.
			arm = add("Arm", armSize, at(x * 1.02, 2.47, -0.86) * CFrame.Angles(1.25, 0, x * 0.06), armColor, bodyMaterial)
		else
			arm = add("Arm", armSize, at(x * (1.05 * bulk + (stooped and 0.12 or 0)), 1.95, -0.18) * CFrame.Angles(-0.3, 0, x * 0.16), armColor, bodyMaterial)
		end
		limbOf.arm[x] = { part = arm, base = torsoInverse * arm.CFrame, side = x }
		table.insert(arms, limbOf.arm[x])
		-- Legs sink a little into the road, so their round ends read as feet.
		local leg = add("Leg", V(bulk > 1 and 0.8 or 0.64, 1.5, bulk > 1 and 0.84 or 0.68), at(x * 0.44 * bulk, 0.5, 0), pants, bodyMaterial)
		limbOf.leg[x] = { part = leg, base = torsoInverse * leg.CFrame, side = x }
		table.insert(legs, limbOf.leg[x])
	end
	-- A piece that swings with a limb: its joint is the limb's, seen from it.
	local SHOULDER, HIP = CFrame.new(0, 0.7 * scale, 0), CFrame.new(0, legHeight / 2, 0)
	local function follow(kind, x, extra)
		local limb = limbOf[kind][x]
		local base = torsoInverse * extra.CFrame
		table.insert(kind == "arm" and arms or legs, { part = extra, base = base, side = x, joint = base:Inverse() * limb.base * (kind == "arm" and SHOULDER or HIP) })
		return extra
	end
	local function handAt(x) return limbOf.arm[x].part.CFrame * CFrame.new(0, -armSize.Y * 0.46 * scale, 0) end
	local function segment(name, a, b, thick, tint, material)
		local length = (b - a).Magnitude
		return add(name, V(thick, thick, length + thick * 0.8), CFrame.lookAt((a + b) / 2 * scale, b * scale), tint, material)
	end
	local function boot(x, tint, material)
		return follow("leg", x, add("Boot", V(0.74 * bulk, 0.5, 1.02 * bulk), at(x * 0.44 * bulk, 0.2, -0.2), tint, material))
	end
	if not def.air then
		local shadow = part(model, V(0.05, 2.3 * scale * bulk, 2.3 * scale * bulk), Color3.new(0, 0, 0))
		shadow.Name, shadow.Shape, shadow.Transparency = "Shadow", Enum.PartType.Cylinder, 0.55
		shadow.CFrame = CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2)
	end
	if def.air then
		add("Jetpack", V(1.2, 1.3, 0.7), at(0, 2.3, 0.72), Color3.fromRGB(70, 78, 88), Enum.Material.Metal)
		add("Thruster", V(0.5, 0.9, 0.5), at(0, 1.35, 0.8), Color3.fromRGB(106, 245, 207), Enum.Material.Neon)
		for _, side in ipairs({ -1, 1 }) do
			local wing = add("Wing", V(2.5, 0.18, 1.3), at(side * 1.75, 2.7, 0.45) * CFrame.Angles(0, side * 0.35, side * 0.12), color:Lerp(Color3.new(), 0.3), Enum.Material.SmoothPlastic)
			table.insert(wings, { part = wing, base = torsoInverse * wing.CFrame, side = side })
		end
	end
	if not def.boss and (def.armor or 0) >= 0.25 then
		add("Plate", V(1.7, 1.3, 0.5), at(0, 2.25, -0.5), Color3.fromRGB(104, 117, 122), Enum.Material.Metal)
	end
	-- Recognizable silhouettes, not just eight differently colored torsos.
	-- Each common enemy adds at most three pieces; only bosses spend more.
	local charges = nil
	if family == "runner" then
		add("Scarf", V(0.6, 0.2, 1.9), at(0, 2.85, 0.9) * CFrame.Angles(-0.25, 0, 0), Color3.fromRGB(235, 156, 73), Enum.Material.SmoothPlastic)
		add("Headband", V(1.36, 0.2, 1.26), at(0, headY + 0.18, headZ), Color3.fromRGB(200, 60, 52), Enum.Material.SmoothPlastic)
	elseif brute then
		add("Hump", V(1.6, 0.9, 1.0), at(0, 2.55, 0.5), color:Lerp(Color3.new(), 0.12))
		for _, x in ipairs({ -1, 1 }) do follow("arm", x, add("Fist", V(0.95, 0.9, 0.95), handAt(x), color:Lerp(Color3.new(), 0.22))) end
	elseif family == "armored" then
		add("Helmet", V(1.42, 0.95, 1.34), at(0, headY + 0.3, headZ + 0.04), Color3.fromRGB(65, 80, 91), Enum.Material.Metal)
		follow("arm", -1, add("Shield", V(1.15, 1.9, 0.3), CFrame.new(handAt(-1).Position + V(-0.05, 0.35, -0.3) * scale) * CFrame.Angles(0, -0.15, -0.12),
			Color3.fromRGB(70, 88, 100), Enum.Material.Metal))
	elseif def.stealth then
		add("Hood", V(1.46, 1.3, 1.4), at(0, headY + 0.14, headZ + 0.2), Color3.fromRGB(49, 38, 68), Enum.Material.SmoothPlastic)
		add("Cloak", V(2.1, 2.9, 0.4), at(0, 1.95, 0.55), Color3.fromRGB(72, 48, 96), Enum.Material.SmoothPlastic)
	elseif def.id == "support" then
		for _, x in ipairs({ -1, 1 }) do add("Tank", V(0.62, 1.5, 0.62), at(x * 0.5, 2.45, 0.78), Color3.fromRGB(174, 248, 115), Enum.Material.Neon) end
		add("Antenna", V(0.12, 1.1, 0.12), at(0.42, 3.6, 0.7), Color3.fromRGB(80, 90, 96), Enum.Material.Metal)
	elseif def.id == "summoner" then
		add("Mantle", V(2.4, 0.6, 1.5), at(0, 2.85, 0), Color3.fromRGB(65, 37, 86), Enum.Material.SmoothPlastic)
		add("Hood", V(1.46, 1.3, 1.4), at(0, headY + 0.14, headZ + 0.2), Color3.fromRGB(65, 37, 86), Enum.Material.SmoothPlastic)
		local staff = part(model, V(0.16, 3.8, 0.16) * scale, Color3.fromRGB(89, 65, 100), Enum.Material.Metal)
		staff.Name, staff.CFrame = "Staff", at(1.35, 1.9, -0.3)
		follow("arm", 1, staff)
		local orb = part(model, V(0.75, 0.75, 0.75) * scale, Color3.fromRGB(220, 131, 255), Enum.Material.Neon)
		orb.Name, orb.Shape, orb.CFrame = "Orb", Enum.PartType.Ball, at(1.35, 3.9, -0.3)
		follow("arm", 1, orb)
		-- One small orb per summons left: the limit of reinforcements is visible.
		charges = {}
		for index = 1, 2 do
			local charge = part(model, V(0.38, 0.38, 0.38) * scale, Color3.fromRGB(240, 190, 255), Enum.Material.Neon)
			charge.Name, charge.Shape = "Charge", Enum.PartType.Ball
			charge.CFrame = at(1.35 + (index == 1 and -0.42 or 0.42), 3.5, -0.3)
			follow("arm", 1, charge)
			table.insert(charges, charge)
		end
	end
	if def.faction then
		add("Badge", V(0.46, 0.5, 0.14), at(0, 2.5, -0.66), color:Lerp(Color3.new(1, 1, 1), 0.45), Enum.Material.Neon)
		if def.faction == "gamma" then
			for _, x in ipairs({ -1, 1 }) do add("Growth", V(0.85, 0.8, 0.85), at(x * 1.05, 2.85, 0.2), color, Enum.Material.Slate) end
		elseif def.faction == "doombot" then
			add("Mask", V(1.2, 1.1, 0.4), face(0, 0, -0.12), Color3.fromRGB(187, 203, 207), Enum.Material.Metal)
			add("Hood", V(1.46, 1.3, 1.4), at(0, headY + 0.14, headZ + 0.2), Color3.fromRGB(41, 90, 58), Enum.Material.SmoothPlastic)
			for _, x in ipairs({ -1, 1 }) do add("Slit", V(0.26, 0.08, 0.08), face(x * 0.26, 0.1, 0.1), INFECTED_EYES, Enum.Material.Neon) end
		elseif def.faction == "sinister" then
			add("Vest", V(2.08 * bulk, 1.3, 1.36 * bulk), at(0, 2.3, 0), Color3.fromRGB(164, 92, 49), Enum.Material.SmoothPlastic)
			add("Bandana", V(1.1, 0.5, 0.5), face(0, -0.3, -0.12), Color3.fromRGB(176, 48, 44), Enum.Material.SmoothPlastic)
		else
			add("Helmet", V(1.42, 0.9, 1.34), at(0, headY + 0.32, headZ + 0.04), def.faction == "vibranium" and Color3.fromRGB(96, 62, 140) or color:Lerp(Color3.new(), 0.25), Enum.Material.Metal)
		end
	end
	-- Only one boss exists at a time, so its silhouette can afford real detail
	-- instead of reading as a scaled-up infected.
	if def.id == "lizard" then
		local coat = Color3.fromRGB(232, 234, 228)
		add("Snout", V(0.95, 0.62, 1.15), at(0, headY - 0.14, headZ - 0.62), look.head)
		add("Teeth", V(0.82, 0.1, 0.9), at(0, headY - 0.36, headZ - 0.7), BONE)
		for _, x in ipairs({ -1, 1 }) do
			add("Pupil", V(0.06, 0.2, 0.06), face(x * 0.28, 0.05, 0.07), INK)
			add("Coat", V(0.74, 2.5, 1.24), at(x * 0.8, 1.8, -0.02), coat, Enum.Material.SmoothPlastic)
			follow("arm", x, add("Claw", V(0.66, 0.5, 0.74), handAt(x), look.head))
			boot(x, look.head)
		end
		add("Coat", V(2.1, 2.6, 0.5), at(0, 1.8, 0.42), coat, Enum.Material.SmoothPlastic)
		for i = 0, 3 do
			add("Tail", V(0.9 - i * 0.16, 0.8 - i * 0.14, 1.3), at(0, 1.3 - i * 0.28, 0.95 + i * 0.95) * CFrame.Angles(0.25, 0, 0), look.torso)
			add("Crest", V(0.16, 0.62 - i * 0.08, 0.5), at(0, 3.95 - i * 0.5, 0.45 + i * 0.1), look.head:Lerp(Color3.new(1, 1, 1), 0.3))
		end
	elseif def.id == "abomination" then
		local ridge = look.head:Lerp(Color3.new(1, 1, 1), 0.15)
		add("Brow", V(1.1, 0.3, 0.5), face(0, 0.26, 0.02), ridge)
		for _, x in ipairs({ -1, 1 }) do
			add("Ear", V(0.16, 0.7, 0.6), at(x * 0.6, headY + 0.1, headZ + 0.1) * CFrame.Angles(0.3, 0, -x * 0.5), look.head)
			add("Shoulder", V(1.5, 1.3, 1.4), at(x * 1.4, 2.85, 0.1), look.torso)
			add("Gill", V(0.08, 0.45, 0.3), face(x * 0.5, -0.2, -0.02), INK)
			follow("arm", x, add("Fist", V(1.15, 1.05, 1.15), handAt(x), look.torso:Lerp(Color3.new(), 0.2)))
			boot(x, look.head)
		end
		for i = 0, 4 do add("Spine", V(0.3, 0.8 - i * 0.08, 0.3), at(0, 3.55 - i * 0.45, 0.72 - i * 0.02) * CFrame.Angles(0.5, 0, 0), ridge) end
		add("Shorts", V(2.3, 0.95, 1.4), at(0, 1.2, 0), look.leg, Enum.Material.SmoothPlastic)
	elseif def.id == "redskull" then
		for _, x in ipairs({ -1, 1 }) do
			add("Socket", V(0.42, 0.44, 0.12), face(x * 0.28, 0.06, -0.01), INK)
			add("Cheek", V(0.3, 0.2, 0.14), face(x * 0.34, -0.14, -0.02), look.head:Lerp(Color3.new(1, 1, 1), 0.12))
			follow("arm", x, add("Glove", V(0.62, 0.56, 0.64), handAt(x), INK))
			boot(x, INK)
		end
		add("Nose", V(0.16, 0.2, 0.1), face(0, -0.12, 0.0), INK)
		add("Teeth", V(0.62, 0.22, 0.12), face(0, -0.36, 0.0), BONE)
		add("Coat", V(2.3, 3.1, 0.6), at(0, 1.6, 0.34), look.torso, Enum.Material.SmoothPlastic)
		add("Collar", V(1.7, 0.5, 1.26), at(0, 2.95, 0.05), look.torso:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.SmoothPlastic)
		add("Belt", V(2.08 * bulk, 0.3, 1.28 * bulk), at(0, 1.62, 0), Color3.fromRGB(70, 56, 40), Enum.Material.SmoothPlastic)
		follow("arm", -1, add("Armband", V(0.62, 0.3, 0.62), limbOf.arm[-1].part.CFrame * CFrame.new(0, 0.3 * scale, 0), Color3.fromRGB(180, 30, 36), Enum.Material.SmoothPlastic))
		local cube = part(model, V(0.6, 0.6, 0.6) * scale, Color3.fromRGB(110, 200, 255), Enum.Material.Neon)
		cube.Name, cube.CFrame = "Cube", CFrame.new((handAt(1) * CFrame.new(0, -0.35 * scale, -0.2 * scale)).Position) * CFrame.Angles(0.6, 0.6, 0)
		follow("arm", 1, cube)
	elseif def.id == "killmonger" then
		local gold = look.head
		for _, x in ipairs({ -1, 1 }) do
			add("Ear", V(0.2, 0.5, 0.2), at(x * 0.42, headY + 0.6, headZ + 0.05) * CFrame.Angles(0, 0, -x * 0.25), gold, Enum.Material.Metal)
			add("Brow", V(0.44, 0.12, 0.14), face(x * 0.26, 0.24, 0.03) * CFrame.Angles(0, 0, x * 0.35), INK)
			add("Pauldron", V(0.95, 0.6, 1.0), at(x * 1.12 * bulk, 2.8, 0), gold, Enum.Material.Metal)
			add("Trace", V(0.12, 1.3, 0.12), at(x * 0.4, 2.0, -0.58) * CFrame.Angles(0, 0, x * 0.3), Color3.fromRGB(255, 196, 90), Enum.Material.Neon)
			follow("arm", x, add("Claw", V(0.62, 0.56, 0.68), handAt(x), gold, Enum.Material.Metal))
			boot(x, gold, Enum.Material.Metal)
		end
		add("Muzzle", V(0.55, 0.32, 0.34), face(0, -0.28, 0.02), gold:Lerp(INK, 0.5), Enum.Material.Metal)
		for i = -2, 2 do
			add("Fang", V(0.14, 0.34, 0.12), at(i * 0.24, 2.58 + math.abs(i) * 0.05, -0.58 + math.abs(i) * 0.05) * CFrame.Angles(0, 0, i * 0.2), BONE)
		end
	elseif def.id == "loki" then
		local gold, cape = Color3.fromRGB(226, 183, 72), Color3.fromRGB(38, 102, 58)
		add("Helmet", V(1.4, 0.8, 1.32), at(0, headY + 0.38, headZ + 0.02), gold, Enum.Material.Metal)
		for _, x in ipairs({ -1, 1 }) do
			-- The horns rise from the brow, sweep out and curl back.
			local root, bend, tip = V(x * 0.42, headY + 0.42, headZ - 0.38), V(x * 0.8, headY + 1.15, headZ - 0.2), V(x * 1.02, headY + 1.75, headZ + 0.45)
			segment("Horn", root, bend, 0.3, gold, Enum.Material.Metal)
			segment("Horn", bend, tip, 0.22, gold, Enum.Material.Metal)
			add("Hair", V(0.42, 1.1, 0.5), at(x * 0.56, headY - 0.4, headZ + 0.35), INK, Enum.Material.SmoothPlastic)
			add("Cape", V(1.1, 3.5, 0.35), at(x * 0.6, 1.7, 0.72) * CFrame.Angles(-0.12, x * 0.2, 0), cape, Enum.Material.SmoothPlastic)
			add("Trim", V(0.2, 1.7, 0.14), at(x * 0.36, 2.1, -0.6), gold, Enum.Material.Metal)
			boot(x, cape:Lerp(INK, 0.4))
		end
		add("Collar", V(1.9, 0.45, 1.3), at(0, 2.95, 0), gold, Enum.Material.Metal)
		local hand = handAt(1)
		local scepter = part(model, V(0.14, 3.2, 0.14) * scale, gold, Enum.Material.Metal)
		scepter.Name, scepter.CFrame = "Scepter", CFrame.new(hand.Position + V(0, 0.9, -0.1) * scale)
		follow("arm", 1, scepter)
		follow("arm", 1, add("Gem", V(0.36, 0.46, 0.36), CFrame.new(hand.Position + V(0, 2.55, -0.1) * scale), Color3.fromRGB(90, 200, 255), Enum.Material.Neon))
	elseif def.id == "doom" then
		local cloth, gold = Color3.fromRGB(41, 90, 58), Color3.fromRGB(214, 172, 72)
		add("Mask", V(1.16, 1.12, 0.4), face(0, -0.02, -0.12), look.head:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Metal)
		add("Grille", V(0.4, 0.06, 0.06), face(0, -0.32, 0.12), INK)
		for _, x in ipairs({ -1, 1 }) do
			add("Slit", V(0.3, 0.09, 0.08), face(x * 0.26, 0.12, 0.12), look.eye, Enum.Material.Neon)
			add("Cloak", V(1.3, 3.6, 0.4), at(x * 0.62, 1.8, 0.7) * CFrame.Angles(-0.1, x * 0.2, 0), cloth, Enum.Material.SmoothPlastic)
			add("Clasp", V(0.34, 0.34, 0.16), at(x * 0.7, 2.8, -0.42), gold, Enum.Material.Metal)
			follow("arm", x, add("Gauntlet", V(0.68, 0.68, 0.72), handAt(x), look.arm:Lerp(INK, 0.2), Enum.Material.Metal))
			boot(x, look.leg:Lerp(INK, 0.2), Enum.Material.Metal)
		end
		add("Hood", V(1.56, 1.4, 1.46), at(0, headY + 0.16, headZ + 0.16), cloth, Enum.Material.SmoothPlastic)
		add("Tunic", V(2.1 * bulk, 1.8, 1.32 * bulk), at(0, 1.55, 0), cloth, Enum.Material.SmoothPlastic)
		add("Belt", V(2.06 * bulk, 0.3, 1.34 * bulk), at(0, 1.95, 0), Color3.fromRGB(70, 60, 44), Enum.Material.SmoothPlastic)
		add("Buckle", V(0.36, 0.36, 0.12), at(0, 1.95, -0.74), gold, Enum.Material.Metal)
	end
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(def.boss and 108 or 45, 8)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.7 * scale, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = 180
	billboard.Adornee = torso
	billboard.Parent = model
	local bg = UI.frame(billboard, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(22, 19, 26)})
	UI.corner(bg, 3)
	local hp = UI.frame(bg, {Name = "HP", Size = UDim2.fromScale(1, 1), BackgroundColor3 = def.boss and UI.Colors.red or UI.Colors.green})
	UI.corner(hp, 3)
	local status = UI.label(billboard, "", {Name="Status", Position=UDim2.new(0.5,-75,0,-19), Size=UDim2.fromOffset(150,17),
		TextSize=11, TextColor3=UI.Colors.gold, TextStrokeTransparency=0.25, Visible=false})
	local pieces = {}
	for _, piece in ipairs(model:GetChildren()) do
		if piece:IsA("BasePart") then
			if def.stealth and piece.Material ~= Enum.Material.Neon and piece.Name ~= "Shadow" then piece.Transparency = 0.32 end
			-- Loki's illusions shimmer: half there, so they read as fakes.
			if def.illusion and piece.Name ~= "Shadow" then piece.Transparency = math.max(piece.Transparency, 0.45) end
			table.insert(pieces, {part = piece, rest = torso.CFrame:Inverse() * piece.CFrame, transparency = piece.Transparency})
		end
	end
	-- Flyers keep a shadow on the road below them, so their lane reads from
	-- above; it is repositioned every frame, apart from the bobbing body.
	local groundShadow
	if def.air then
		groundShadow = part(model, Vector3.new(0.05, 2.6 * scale, 2.6 * scale), Color3.new(0, 0, 0))
		groundShadow.Name, groundShadow.Shape, groundShadow.Transparency = "GroundShadow", Enum.PartType.Cylinder, 0.62
	end
	model:PivotTo(CFrame.new(0, 0, 0))
	-- Torso and head are the two parts a hit flash recolors: a Highlight per
	-- enemy would be prettier and completely unaffordable at 180 of them.
	return {
		model = model, bar = hp, status = status, scale = scale, def = def, lastHP = nil,
		legs = def.air and nil or legs, arms = arms, wings = wings, legHeight = legHeight,
		pieces = pieces, billboard = billboard, groundShadow = groundShadow, charges = charges,
		flashParts = { { part = torso, color = torso.Color }, { part = head, color = head.Color }, shirt and { part = shirt, color = shirt.Color } or nil },
		flashUntil = nil,
	}
end

-- Exposed for tools (the Studio showroom) and tests; gameplay uses Handle.
Effects.BuildEnemy = buildEnemy

function Effects.new(player, request, getState, audio)
	local self = setmetatable({}, Effects)
	self.player, self.request, self.getState, self.audio = player, request, getState, audio
	self.folder = Instance.new("Folder")
	self.folder.Name = "DoomClientVisuals"
	self.folder.Parent = workspace
	self.enemies, self.pool, self.coins, self.shots = {}, {}, {}, {}
	self.soldiers={}
	self.shotPool, self.clock, self.collectAt = {}, 0, 0
	self.shakeAmount = 0
	self.towerModels, self.popups, self.popupPool = nil, {}, {}
	self.aims, self.aimsOrder = {}, {}
	self.links, self.dustBudget = {}, 0
	self.dying, self.collecting = {}, {}
	self.shotSerial = 0
	self.connection = RunService.RenderStepped:Connect(function(dt) self:Step(dt) end)
	-- Runs after the camera has been positioned for this frame, so the offset
	-- is not immediately overwritten.
	RunService:BindToRenderStep("DoomShake", Enum.RenderPriority.Camera.Value + 1, function(dt)
		self:_shakeStep(dt)
	end)
	return self
end

-- Camera movement is an accessibility setting, so it is checked here rather
-- than at each call site.
function Effects:Shake(intensity)
	local state = self.getState()
	local settings = state and state.profile and state.profile.settings or {}
	if settings.shake == false then return end
	intensity = math.clamp(tonumber(intensity) or 0, 0, 1.5)
	if settings.lowFX then intensity *= 0.35 end
	self.shakeAmount = math.min(1.2, self.shakeAmount + intensity)
end

function Effects:_shakeStep(dt)
	if self.shakeAmount <= 0.002 then return end
	self.shakeAmount = math.max(0, self.shakeAmount - dt * 2.4)
	local camera = workspace.CurrentCamera
	if not camera then return end
	local amount = self.shakeAmount
	local time = os.clock() * 33
	camera.CFrame = camera.CFrame
		* CFrame.new(math.sin(time) * amount * 0.5, math.cos(time * 1.43) * amount * 0.38, 0)
		* CFrame.Angles(0, 0, math.sin(time * 0.91) * amount * 0.011)
end

local FLASH_COLOR = Color3.fromRGB(255, 244, 222)

local function clearFlash(record)
	if not record.flashUntil then return end
	for _, entry in ipairs(record.flashParts) do entry.part.Color = entry.color end
	record.flashUntil = nil
end

function Effects:_poolEnemy(record)
	clearFlash(record)
	for _, piece in ipairs(record.pieces) do
		piece.part.Transparency = piece.transparency
		piece.part.CFrame = piece.rest
	end
	record.billboard.Enabled = true
	record.lastHP, record.target, record.phase, record.animated = nil, nil, nil, nil
	record.hitAt, record.statusFlags, record.revealed, record.link, record.lastStep = nil, nil, nil, nil, nil
	record.model.Parent = nil
	self.pool[record.def.id] = self.pool[record.def.id] or {}
	table.insert(self.pool[record.def.id], record)
	-- A sudden wave clear must not leave 180 sleeping Models per archetype.
	if #self.pool[record.def.id] > 24 then table.remove(self.pool[record.def.id], 1).model:Destroy() end
end

function Effects:Release(id, instant)
	local record = self.enemies[id]
	if not record then return end
	self.enemies[id] = nil
	clearFlash(record)
	local state = self.getState()
	local lowFX = state and state.profile and state.profile.settings.lowFX
	if not instant and not lowFX and #self.dying < 12 then
		record.billboard.Enabled = false
		table.insert(self.dying, {record = record, pivot = record.model.PrimaryPart.CFrame, born = self.clock})
	else
		self:_poolEnemy(record)
	end
end

-- Lazily rebuilt: towers are placed rarely compared to how often they fire,
-- so a stale cache just costs one extra folder scan on the next miss.
function Effects:_towerModel(towerId)
	if not towerId then return nil end
	-- The lobby training yard's hero is not a tower, but aims and fires like one.
	if towerId == "training" then
		local lobby = workspace:FindFirstChild("DoomLobby")
		local yard = lobby and lobby:FindFirstChild("TrainingYard")
		return yard and yard:FindFirstChild("TrainingHero")
	end
	local cached = self.towerModels and self.towerModels[towerId]
	if cached and cached.Parent then return cached end
	local world = workspace:FindFirstChild("DoomWorld")
	local towers = world and world:FindFirstChild("Towers")
	if not towers then return nil end
	self.towerModels = {}
	for _, model in ipairs(towers:GetChildren()) do
		local id = model:GetAttribute("TowerId")
		if id ~= nil then self.towerModels[id] = model end
	end
	return self.towerModels[towerId]
end

-- Attack poses use authored shoulder joints, including attached weapons.
-- Every transform starts from the rest pose; repeated shots cannot drift.
function Effects:_recoil(towerId)
	local model = self:_towerModel(towerId)
	local pose = model and self:_record(model)
	if pose then pose.firedAt, pose.active = self.clock, true end
	local ring = model and model:FindFirstChild("PowerRing")
	if not ring or ring:GetAttribute("Recoiling") then return end
	local function canonical()
		local width = tonumber(ring:GetAttribute("BaseSize")) or ring.Size.Y
		return Vector3.new(ring.Size.X, width, width)
	end
	ring:SetAttribute("Recoiling", true)
	TweenService:Create(ring, TweenInfo.new(0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = canonical() + Vector3.new(0, 0.45, 0.45)}):Play()
	task.delay(0.07, function()
		-- Read the canonical width again here: an upgrade may have widened the
		-- ring while this recoil was in flight, and the restore must not undo it.
		if ring.Parent then TweenService:Create(ring, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Size = canonical()}):Play() end
		ring:SetAttribute("Recoiling", false)
	end)
end

-- Heroes turn to face what they shoot at. Only the figure turns: the platform,
-- the power ring and the rank markers belong to the server, which resizes
-- and rebuilds them on upgrade, so those are never touched here. The figure's
-- parts are never moved by the server after MakeTower, which is what makes it
-- safe to capture their resting CFrames once and rotate from those.
local FIXED_TOWER_PARTS = { Platform = true, PowerRing = true }

-- One pose record per hero figure, created the first time the figure needs to
-- move (aim, idle, upgrade, cast or interruption) and dropped with the model.
function Effects:_record(model)
	local record = self.aims[model]
	if record then return record end
	local base = model.PrimaryPart
	if not base then return nil end
	local parts = {}
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("BasePart") and child:GetAttribute("HeroGeometry") and not FIXED_TOWER_PARTS[child.Name] then
			local joint = child:GetAttribute("PoseJoint")
			table.insert(parts, { part = child, rest = child.CFrame, group = child:GetAttribute("PoseGroup"),
				joint = typeof(joint) == "Vector3" and CFrame.new(joint) or nil })
		end
	end
	local scale = model:GetAttribute("FigureScale") or 1
	local figure = model:FindFirstChild("HeroFigure")
	if figure and not figure:GetAttribute("HeroArt") then figure = nil end
	record = { parts = parts, pivot = CFrame.new(base.Position), yaw = 0, target = 0, active = false, scale = scale,
		figure = figure, figureRest = figure and figure:GetPivot() or nil,
		heroId = model:GetAttribute("HeroId"), ownerId = model:GetAttribute("OwnerId"),
		waist = CFrame.new(base.Position + Vector3.new(0, 2.4 * scale, 0)),
		head = base.Position + Vector3.new(0, 6.2 * scale, 0), breath = (#self.aimsOrder + 1) * 1.7 }
	self.aims[model] = record
	table.insert(self.aimsOrder, model)
	if figure then
		local controller = figure:FindFirstChildWhichIsA("AnimationController", true) or figure:FindFirstChildWhichIsA("Humanoid", true)
		record.animator = controller and controller:FindFirstChildOfClass("Animator") or nil
		playArt(record, figure, "IdleAnimation", true)
	end
	return record
end

function Effects:_aim(towerId, target)
	local model = self:_towerModel(towerId)
	local base = model and model.PrimaryPart
	if not base or typeof(target) ~= "Vector3" then return end
	local record = self:_record(model)
	if not record then return end
	local offset = target - base.Position
	if math.abs(offset.X) + math.abs(offset.Z) < 0.5 then return end
	-- Figures are built facing -Z.
	record.target = math.atan2(-offset.X, -offset.Z)
	record.active = true
end

-- A tower hit by a boss power is interrupted for a moment. It slumps and a
-- ring of stars circles its head, so an idle hero never looks like a bug.
function Effects:_stun(towerId, duration)
	local model = self:_towerModel(towerId)
	local record = model and self:_record(model)
	if not record then return end
	record.stunUntil = self.clock + math.clamp(tonumber(duration) or 1.5, 0.2, 6)
	record.stars = record.stars or {}
	if #record.stars == 0 then
		for index = 1, 3 do
			local star = part(self.folder, Vector3.new(0.45, 0.45, 0.45), Color3.fromRGB(255, 226, 92), Enum.Material.Neon)
			star.Name, star.Shape = "StunStar", Enum.PartType.Ball
			record.stars[index] = star
		end
	end
end

-- Idle heroes breathe, but only the ones near the camera: a full map of
-- sixteen towers rewriting every part each frame is wasted work on a phone.
local IDLE_DISTANCE = 110
local IDLE_SCAN = 1

function Effects:_registerIdle()
	local world = workspace:FindFirstChild("DoomWorld")
	local towers = world and world:FindFirstChild("Towers")
	for _, model in ipairs(towers and towers:GetChildren() or {}) do
		if not self.aims[model] and model.PrimaryPart then self:_record(model) end
	end
end

function Effects:_turnTowers(dt)
	local state = self.getState()
	local reduced = state and state.profile and state.profile.settings and state.profile.settings.lowFX
	if self.clock >= (self.idleScanAt or 0) then
		self.idleScanAt = self.clock + IDLE_SCAN
		if not reduced then self:_registerIdle() end
	end
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position
	for index = #self.aimsOrder, 1, -1 do
		local model = self.aimsOrder[index]
		local record = self.aims[model]
		if model.Parent == nil or not record then
			if record then for _, star in ipairs(record.stars or {}) do star:Destroy() end end
			self.aims[model] = nil
			table.remove(self.aimsOrder, index)
			continue
		end
		local age = record.firedAt and self.clock - record.firedAt or 1
		local firing = age < 0.42
		local castAge = record.castAt and self.clock - record.castAt or 1
		local casting = castAge < 0.75
		local hopAge = record.hopAt and self.clock - record.hopAt or 1
		local hopping = hopAge < 0.55
		local stunned = record.stunUntil and self.clock < record.stunUntil
		local near = eye and (eye - record.pivot.Position).Magnitude < IDLE_DISTANCE
		local idle = not reduced and near
		if record.stars and not stunned then
			for _, star in ipairs(record.stars) do star:Destroy() end
			record.stars = nil
		end
		if record.active or casting or hopping or stunned or idle or record.posed then
			local delta = ((record.target - record.yaw + math.pi) % (2 * math.pi)) - math.pi
			local settled = math.abs(delta) < 0.01
			record.yaw = settled and record.target or record.yaw + delta * math.min(1, dt * 14)
			local pulse = firing and math.sin(math.clamp(age / 0.42, 0, 1) * math.pi) or 0
			local cast = casting and math.sin(math.clamp(castAge / 0.75, 0, 1) * math.pi) or 0
			local hop = hopping and math.sin(math.clamp(hopAge / 0.55, 0, 1) * math.pi) or 0
			local breathe = idle and math.sin(self.clock * 2.1 + record.breath) * 0.05 * record.scale or 0
			local slump = stunned and 1 or 0
			if reduced then pulse, cast, hop = 0, 0, 0 end
			local melee = record.heroId == "hulk" or record.heroId == "thor" or record.heroId == "groot" or record.heroId == "shangchi"
			local magic = record.heroId == "wanda" or record.heroId == "strange" or record.heroId == "silversurfer"
			-- Upgrades lift the whole figure off the pedestal; everything else
			-- bends from the waist or the shoulders over planted legs.
			local lift = CFrame.new(0, hop * 1.1 * record.scale, 0)
			local turn = lift * record.pivot * CFrame.Angles(0, record.yaw, 0) * record.pivot:Inverse()
			if record.figure then
				-- Final art turns and hops as one piece; its own animations do the rest.
				record.figure:PivotTo(turn * record.figureRest)
				if record.firedAt ~= record.playedFire and firing then record.playedFire = record.firedAt; playArt(record, record.figure, "AttackAnimation") end
				if record.castAt ~= record.playedCast and casting then record.playedCast = record.castAt; playArt(record, record.figure, "AbilityAnimation") end
				if record.hopAt ~= record.playedHop and hopping then record.playedHop = record.hopAt; playArt(record, record.figure, "UpgradeAnimation") end
			end
			local wobble = stunned and math.sin(self.clock * 6) * 0.1 or 0
			local lean = -pulse * (melee and 0.12 or 0.035) + cast * 0.2 + slump * 0.22
			local body = record.waist * CFrame.Angles(lean, 0, wobble) * record.waist:Inverse() * CFrame.new(0, breathe, 0)
			for _, entry in ipairs(record.parts) do
				if entry.part.Parent then
					local transform = turn
					if entry.group then transform *= body end
					if entry.joint then
						local side = entry.group == "LeftArm" and -1 or 1
						-- Figures face -Z, so a positive turn about X swings an arm forward
						-- and up: overhead for a cast, a little for the hop, down and limp
						-- when interrupted. The firing kick stays the existing small recoil.
						local raise = -pulse * (melee and 0.65 or magic and 0.28 or 0.16) + cast * 2.1 - slump * 0.35 + hop * 0.6
						transform *= entry.joint * CFrame.Angles(raise, 0, (magic and side * pulse * 0.16 or 0) + side * cast * 0.35) * entry.joint:Inverse()
					end
					entry.part.CFrame = transform * entry.rest
				end
			end
			if record.stars then
				for number, star in ipairs(record.stars) do
					local angle = self.clock * 4 + number * math.pi * 2 / 3
					star.CFrame = CFrame.new(record.head + Vector3.new(math.cos(angle) * 1.4, 0.3 + math.sin(self.clock * 5 + number) * 0.15, math.sin(angle) * 1.4))
				end
			end
			-- A figure that has come to rest keeps its last pose until the next
			-- motion; one extra pass returns it exactly to rest.
			record.posed = firing or casting or hopping or stunned or idle
			if settled and not firing then record.active = false end
		end
	end
end

-- A support hastens the infected around it; a thin green line joins it to
-- every enemy it is speeding up, as named by the server (EnemySync "lk").
local MAX_LINKS = 24
function Effects:_drawLinks(lowFX)
	local used = 0
	if not lowFX then
		for _, enemy in pairs(self.enemies) do
			local support = enemy.link and self.enemies[enemy.link]
			if support and used < MAX_LINKS then
				local a = support.position + Vector3.new(0, 2.8 * support.scale, 0)
				local b = enemy.position + Vector3.new(0, 2 * enemy.scale, 0)
				if (b - a).Magnitude > 0.3 then
					used += 1
					local line = self.links[used]
					if not line then
						line = part(nil, Vector3.one, Color3.fromRGB(174, 248, 115), Enum.Material.Neon)
						line.Name, line.Transparency = "SupportLink", 0.45
						self.links[used] = line
					end
					line.Size, line.CFrame = Vector3.new(0.12, 0.12, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b)
					line.Parent = self.folder
				end
			end
		end
	end
	for index = used + 1, #self.links do self.links[index].Parent = nil end
end

-- Floating damage numbers read straight off the HP the periodic EnemySync
-- snapshot already carries, so no new network event is needed per hit. A
-- BillboardGui with no BasePart parent has no adornee and never renders, so
-- each popup gets its own tiny invisible anchor part, exactly like coins.
function Effects:_popup(position, amount, color, prefix)
	if #self.popups >= 40 then return end
	local pooled = table.remove(self.popupPool)
	local anchor, label
	if pooled then
		anchor, label = pooled.anchor, pooled.label
		anchor.Parent = self.folder
	else
		anchor = part(self.folder, Vector3.new(0.2, 0.2, 0.2), Color3.new(), Enum.Material.SmoothPlastic)
		anchor.Transparency = 1
		local billboard = Instance.new("BillboardGui")
		billboard.Size, billboard.AlwaysOnTop, billboard.MaxDistance = UDim2.fromOffset(90, 30), true, 140
		billboard.Parent = anchor
		label = UI.label(billboard, "", {Size = UDim2.fromScale(1, 1), Font = Enum.Font.GothamBold, TextSize = 16, TextStrokeTransparency = 0.3, TextXAlignment = Enum.TextXAlignment.Center})
	end
	label.Text, label.TextColor3, label.TextTransparency, label.TextStrokeTransparency = (prefix or "-") .. tostring(math.max(1, math.floor(amount))), color, 0, 0.3
	anchor.CFrame = CFrame.new(position + Vector3.new(math.random(-8, 8) * 0.08, 1, 0))
	table.insert(self.popups, {anchor = anchor, label = label, expires = self.clock + 0.7})
end

-- Shared, capped pool for every short-lived attack primitive. Each acquisition
-- resets the properties touched by any other style (especially cylinder/ball).
function Effects:_effect(size, frame, color, duration, shape, fade)
	if #self.shots >= 80 then return nil end
	local visual = table.remove(self.shotPool) or part(nil, Vector3.one, color, Enum.Material.Neon)
	visual.Name, visual.Shape = "CombatEffect", shape or Enum.PartType.Block
	visual.Size, visual.CFrame, visual.Color = size, frame, color
	visual.Material, visual.Transparency = Enum.Material.Neon, fade or 0.12
	local warning = visual:FindFirstChild("Warning")
	if warning then warning.Enabled = false end
	visual.Parent = self.folder
	local effect = {part = visual, born = self.clock, expires = self.clock + duration, fade = fade or 0.12}
	table.insert(self.shots, effect)
	return effect
end

function Effects:_line(from, to, color, width, duration)
	if (to - from).Magnitude < 0.02 then return nil end
	return self:_effect(Vector3.new(width, width, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), color, duration)
end

function Effects:_impact(position, color, diameter)
	local effect = self:_effect(Vector3.one * diameter, CFrame.new(position), color, 0.18, Enum.PartType.Ball, 0.4)
	if effect then effect.ballFrom, effect.ballTo = diameter, diameter * 1.9 end
end

function Effects:_groundImpact(position, color, radius)
	local center = Vector3.new(position.X, 0.18, position.Z)
	local effect = self:_effect(Vector3.new(0.09, radius, radius), CFrame.new(center) * CFrame.Angles(0, 0, math.pi / 2), color, 0.28, Enum.PartType.Cylinder, 0.78)
	if effect then effect.growFrom, effect.growTo = radius, radius * 2 end
end

-- The signature of an ultimate: a pillar of light and three shockwaves rolling
-- out from the cast point, then one ring per extra effect in that effect's own
-- color so a player can read what the ultimate just did. Reduced effects keeps a
-- single ring and no strobing.
local EXTRA_TINT = {
	stun = Color3.fromRGB(255, 255, 255), weaken = Color3.fromRGB(190, 120, 255), reveal = Color3.fromRGB(255, 90, 90),
	slow = Color3.fromRGB(120, 200, 255), pull = Color3.fromRGB(255, 190, 90), blast = Color3.fromRGB(255, 160, 90),
	chain = Color3.fromRGB(140, 225, 255), barrier = Color3.fromRGB(110, 160, 255), heal = Color3.fromRGB(150, 255, 170),
}
function Effects:_ultimateBurst(event, tint, lowFX)
	local position = event.position
	local radius = math.max(event.radius or 0, 30)
	if lowFX then
		self:_groundImpact(position, tint, radius)
		return
	end
	local pale = tint:Lerp(Color3.new(1, 1, 1), 0.55)
	local width = math.clamp(radius * 0.18, 3, 12)
	self:_effect(Vector3.new(120, width, width), CFrame.new(position + Vector3.new(0, 60, 0)) * CFrame.Angles(0, 0, math.pi / 2), pale, 0.7, Enum.PartType.Cylinder, 0.35)
	for wave = 1, 3 do
		task.delay((wave - 1) * 0.14, function()
			self:_groundImpact(position, tint, radius * (0.55 + 0.3 * wave))
			self:_impact(position + Vector3.new(0, 1.5, 0), pale, radius * 0.12 * wave)
		end)
	end
	for index, extra in ipairs(event.extras or {}) do
		local color = EXTRA_TINT[extra.kind]
		if color then
			task.delay(0.1 + index * 0.16, function()
				self:_groundImpact(position, color, math.max(extra.radius or 0, radius * 0.5) * 0.8)
			end)
		end
	end
end

-- Which weapon cue a hero's shot makes: bows and thrown cards whoosh, area
-- attacks boom, magic and energy chains shimmer, close fighters thud and the
-- rest (repulsors, blasters, rifles) zap.
local WHOOSH_HEROES = { hawkeye = true, gambit = true, spiderman = true, falcon = true, moonknight = true }
local THUD_HEROES = { hulk = true, groot = true, panther = true, wolverine = true, shangchi = true, daredevil = true,
	beast = true, psylocke = true, captain = true, antman = true, thor = true }
function Effects.ShotSound(heroId)
	local def = Catalog.Heroes[heroId]
	if WHOOSH_HEROES[heroId] then return "shotArrow" end
	if THUD_HEROES[heroId] then return "shotMelee" end
	if def and def.attack == "splash" then return "shotBlast" end
	if def and (def.damageType == "magic" or def.attack == "chain" or def.attack == "beam" or def.attack == "dot") then return "shotMagic" end
	return "shotTech"
end

local MUZZLE_PARTS = {ironman="Repulsor",hawkeye="Arrow",spiderman="Hand",thor="Mjolnir",captain="Shield",widow="BatonCharge",
	bucky="RifleBarrel",rocket="GunMuzzle",warmachine="CannonMuzzle",starlord="BlasterGlow",wanda="ChaosSpell",strange="SpellGlyph",vision="MindGem",captainmarvel="PhotonFist",
	wolverine="AdamantiumClaw",cyclops="Visor",gambit="ChargedCard",iceman="IceFist",psylocke="Blade",nova="Visor",beast="FurryFist"}

function Effects:_heroShot(event, lowFX)
	local from, target = event.from, event.to
	local model = self:_towerModel(event.towerId)
	local heroId = model and model:GetAttribute("HeroId") or event.heroId
	local muzzle = model and model:FindFirstChild(MUZZLE_PARTS[heroId] or "Hand")
	if muzzle then from = muzzle.Position end
	-- Final art names its own emission point.
	local attachment = model and model:FindFirstChild("Muzzle", true)
	if attachment and attachment:IsA("Attachment") and typeof(attachment.WorldPosition) == "Vector3" then from = attachment.WorldPosition end
	local color = UI.color(event.color)
	local white = Color3.fromRGB(218, 246, 255)
	local delta = target - from
	if delta.Magnitude < 0.02 then return end
	self.shotSerial += 1
	-- Reduced effects retains a quiet attack cue; no rapid stochastic flashes.
	if lowFX then
		if self.shotSerial % 3 == 0 then self:_line(from, target, color, 0.08, 0.1) end
		return
	end
	if heroId == "thor" or heroId=="storm" then
		local previous = from
		local side = delta.Unit:Cross(Vector3.new(0, 1, 0))
		for index = 1, 4 do
			local point = index == 4 and target or from:Lerp(target, index / 4) + side * (index % 2 == 0 and 1.3 or -1.3)
			self:_line(previous, point, Color3.fromRGB(149, 218, 255), 0.2, 0.19)
			previous = point
		end
		self:_impact(target, white, 0.65)
	elseif heroId == "spiderman" then
		self:_line(from, target, white, 0.09, 0.2)
		for index = 0, 2 do
			local angle = index * math.pi / 3
			local offset = Vector3.new(math.cos(angle) * 1.3, math.sin(angle) * 1.3, 0)
			self:_line(target - offset, target + offset, white, 0.07, 0.3)
		end
	elseif heroId == "panther" or heroId=="wolverine" or heroId=="psylocke" then
		for index = -1, 1 do
			local offset = Vector3.new(index * 0.4, 0, 0)
			self:_line(target + offset + Vector3.new(-0.6, 0.9, 0), target + offset + Vector3.new(0.6, -0.9, 0), Color3.fromRGB(192, 155, 255), 0.11, 0.18)
		end
	elseif heroId == "hulk" or heroId == "antman" or heroId=="beast" then
		self:_groundImpact(target, color, heroId == "hulk" and 5 or 3.5)
		for index = 0, 2 do
			local angle = index * math.pi * 2 / 3 + self.shotSerial
			local offset = Vector3.new(math.cos(angle), 0, math.sin(angle))
			local fragment = self:_effect(Vector3.new(0.32, 0.32, 0.32), CFrame.new(target), color:Lerp(Color3.new(), 0.4), 0.32, nil, 0.15)
			if fragment then fragment.from, fragment.to, fragment.arc = target, target + offset * 2, 1.8 end
		end
	elseif heroId == "captain" then
		local shield = self:_effect(Vector3.new(0.15, 1.4, 1.4), CFrame.new(from), Color3.fromRGB(223, 62, 70), 0.38, Enum.PartType.Cylinder)
		if shield then shield.from, shield.to, shield.returning, shield.disc = from, target, true, true end
		self:_impact(target, white, 0.45)
	elseif heroId == "hawkeye" then
		local arrow = self:_effect(Vector3.new(0.11, 0.11, 2.4), CFrame.lookAt(from, target), Color3.fromRGB(205, 179, 243), 0.17)
		if arrow then arrow.from, arrow.to, arrow.arrow = from, target, true end
	elseif heroId=="gambit" or heroId=="moonknight" then
		local card=self:_effect(Vector3.new(0.7,1,0.1),CFrame.new(from),color,0.25,nil,0.1)
		if card then card.from,card.to,card.arc=from,target,1.4 end
		self:_groundImpact(target,color,2)
	elseif heroId=="iceman" then
		self:_line(from,target,color,0.2,0.2)
		for index=-1,1 do self:_effect(Vector3.new(0.3,1.5,0.3),CFrame.new(target+Vector3.new(index*0.8,-0.4,0))*CFrame.Angles(0,0,index*0.2),color,0.35,nil,0.15) end
	elseif heroId=="nightcrawler" then
		self:_impact(from,color,1.2); self:_impact(target,color,1.6)
	elseif heroId == "wanda" or heroId=="jean" then
		local bolt = self:_effect(Vector3.one * 0.65, CFrame.new(from), Color3.fromRGB(255, 85, 131), 0.22, Enum.PartType.Ball, 0.1)
		if bolt then bolt.from, bolt.to, bolt.arc = from, target, 2 end
		self:_groundImpact(target, Color3.fromRGB(204, 57, 105), 3)
	elseif heroId == "strange" then
		self:_line(from, target, Color3.fromRGB(255, 181, 91), 0.13, 0.2)
		for index = 0, 2 do
			local angle = index * math.pi * 2 / 3 + self.shotSerial
			local offset = Vector3.new(math.cos(angle), math.sin(angle), 0) * 1.2
			self:_effect(Vector3.new(0.35, 0.35, 0.09), CFrame.new(target + offset) * CFrame.Angles(0, 0, angle), Color3.fromRGB(255, 196, 112), 0.32)
		end
	elseif heroId == "vision" or heroId=="cyclops" or heroId=="nova" then
		self:_line(from, target, heroId=="cyclops" and Color3.fromRGB(255,80,90) or Color3.fromRGB(252, 205, 99), 0.36, 0.22)
		self:_line(from, target, white, 0.1, 0.13)
	elseif heroId == "widow" then
		self:_line(from, target, Color3.fromRGB(240, 87, 99), 0.1, 0.11)
		self:_impact(target, Color3.fromRGB(255, 165, 138), 0.4)
	elseif heroId == "falcon" then
		local swoop = self:_effect(Vector3.new(0.6, 0.15, 0.15), CFrame.new(from), Color3.fromRGB(255, 150, 110), 0.22, nil, 0.15)
		if swoop then swoop.from, swoop.to, swoop.arc = from, target, 2.5 end
		self:_impact(target, Color3.fromRGB(255, 150, 110), 0.35)
	elseif heroId == "bucky" or heroId=="deadpool" then
		self:_line(from, target, Color3.fromRGB(200, 208, 216), 0.06, 0.09)
		self:_impact(target, Color3.fromRGB(160, 170, 180), 0.3)
	elseif heroId == "wasp" then
		local previous = from
		local side = delta.Unit:Cross(Vector3.new(0, 1, 0))
		for index = 1, 3 do
			local point = index == 3 and target or from:Lerp(target, index / 3) + side * (index % 2 == 0 and 0.7 or -0.7)
			self:_line(previous, point, Color3.fromRGB(255, 224, 110), 0.07, 0.12)
			previous = point
		end
	elseif heroId == "rocket" then
		local shell = self:_effect(Vector3.one * 0.3, CFrame.new(from), Color3.fromRGB(200, 160, 90), 0.3, Enum.PartType.Ball, 0.1)
		if shell then shell.from, shell.to, shell.arc = from, target, 4 end
		self:_groundImpact(target, Color3.fromRGB(255, 150, 60), 4)
	elseif heroId == "daredevil" then
		self:_line(target + Vector3.new(-0.9, 0.9, 0), target + Vector3.new(0.9, -0.9, 0), Color3.fromRGB(220, 50, 60), 0.09, 0.16)
		self:_line(target + Vector3.new(0.9, 0.9, 0), target + Vector3.new(-0.9, -0.9, 0), Color3.fromRGB(220, 50, 60), 0.09, 0.16)
	elseif heroId == "shangchi" then
		self:_line(from, target, Color3.fromRGB(255, 150, 90), 0.08, 0.14)
		for index = 0, 3 do
			local angle = index * math.pi / 2 + self.shotSerial
			local offset = Vector3.new(math.cos(angle), math.sin(angle), 0) * 0.9
			self:_line(target - offset, target + offset, Color3.fromRGB(255, 180, 110), 0.05, 0.18)
		end
	elseif heroId == "warmachine" then
		local missile = self:_effect(Vector3.new(0.22, 0.22, 1.6), CFrame.lookAt(from, target), Color3.fromRGB(180, 190, 200), 0.2)
		if missile then missile.from, missile.to = from, target end
		self:_groundImpact(target, Color3.fromRGB(255, 140, 60), 5.5)
	elseif heroId == "starlord" then
		local side = delta.Unit:Cross(Vector3.new(0, 1, 0)) * 0.5
		self:_line(from + side, target + side, Color3.fromRGB(255, 120, 90), 0.07, 0.1)
		self:_line(from - side, target - side, Color3.fromRGB(120, 200, 255), 0.07, 0.1)
	elseif heroId == "groot" then
		self:_line(from, target, Color3.fromRGB(110, 85, 55), 0.28, 0.18)
		self:_groundImpact(target, Color3.fromRGB(130, 100, 62), 3.5)
	elseif heroId == "ghostrider" then
		local previous = from
		for index = 1, 3 do
			local point = index == 3 and target or from:Lerp(target, index / 3)
			self:_line(previous, point, Color3.fromRGB(255, 140, 40), 0.14, 0.16)
			previous = point
		end
		self:_groundImpact(target, Color3.fromRGB(255, 90, 20), 4)
	elseif heroId == "captainmarvel" then
		self:_line(from, target, Color3.fromRGB(255, 220, 140), 0.4, 0.2)
		self:_line(from, target, white, 0.14, 0.12)
		self:_impact(target, Color3.fromRGB(255, 230, 160), 0.6)
	elseif heroId == "silversurfer" then
		self:_line(from, target, Color3.fromRGB(210, 225, 245), 0.16, 0.16)
		self:_impact(target, Color3.fromRGB(190, 210, 230), 0.45)
	else
		-- Repulsors remain pale blue even though Iron Man's suit is red.
		local tint = heroId == "ironman" and Color3.fromRGB(136, 225, 255) or color
		self:_line(from, target, tint, 0.23, 0.16)
		self:_impact(target, tint, 0.65)
	end
end

function Effects:Handle(event)
	if type(event)~="table" then return end
	if event.kind=="BaseShot" then
		self:_line(event.from,event.to,event.color,0.3,0.18); self:_impact(event.to,event.color,2)
		return
	elseif event.kind=="SoldierSync" then
		local seen={}
		for _,s in ipairs(event.soldiers or {}) do
			seen[s.id]=true
			local record=self.soldiers[s.id]
			if not record then
				local model=Instance.new("Model"); model.Name="AllySoldier"; model.Parent=self.folder
				local tint=UI.color(Catalog.Bases[s.baseId].color)
				local torso=part(model,Vector3.new(1.3,1.6,0.7),tint,Enum.Material.Metal); torso.CFrame=CFrame.new(0,2,0); model.PrimaryPart=torso
				local head=part(model,Vector3.new(0.9,0.9,0.9),Color3.fromRGB(226,232,223)); head.Shape=Enum.PartType.Ball; head.CFrame=CFrame.new(0,3.2,0)
				local legs={}
				for _,side in ipairs({-1,1}) do
					local limb=part(model,Vector3.new(0.45,1.3,0.5),tint); limb.CFrame=CFrame.new(side*0.4,0.65,0)
					table.insert(legs,{part=limb,base=CFrame.new(side*0.4,-1.35,0),side=side})
					local arm=part(model,Vector3.new(0.4,1.1,0.5),tint); arm.CFrame=CFrame.new(side*0.9,2.1,-0.15)
				end
				local helmet=part(model,Vector3.new(1.1,0.35,1),tint,Enum.Material.Metal); helmet.CFrame=CFrame.new(0,3.65,0)
				local mark=part(model,Vector3.new(1.5,0.15,1.5),UI.Colors.green,Enum.Material.Neon); mark.CFrame=CFrame.new(0,0.15,0)
				local tag=UI.create("BillboardGui",{Size=UDim2.fromOffset(44,6),StudsOffsetWorldSpace=Vector3.new(0,2.5,0),Adornee=torso,AlwaysOnTop=true,MaxDistance=110},model)
				local hp=UI.bar(tag,UI.Colors.green,UDim2.fromOffset(0,0),UDim2.fromScale(1,1))
				record={model=model,position=s.position,target=s.position,legs=legs,hp=hp}; self.soldiers[s.id]=record
			end
			record.target=s.position
			record.hp.Size=UDim2.fromScale(math.clamp(s.hp/s.maxHP,0,1),1)
		end
		for id,record in pairs(self.soldiers) do if not seen[id] then record.model:Destroy(); self.soldiers[id]=nil end end
		return
	end
	if type(event) ~= "table" then return end
		if event.kind == "Notice" and event.tone == "boss" and self.audio then self.audio:Cue("boss", 4) end
	if event.shake then self:Shake(event.shake) end
	if event.kind == "EnemyDown" then
		self:Release(tostring(event.id))
		if event.boss and typeof(event.position)=="Vector3" then self:_groundImpact(event.position,UI.Colors.gold,12) end
		return
	elseif event.kind == "CardPicked" then
		if self.audio then self.audio:Cue("upgrade") end
		return
	elseif event.kind == "TowerUpgrade" then
		-- The upgraded hero hops off its pedestal in a column of gold.
		local model = self:_towerModel(event.towerId)
		local record = model and self:_record(model)
		if record then
			record.hopAt = self.clock
			local state = self.getState()
			local lowFX = state and state.profile and state.profile.settings and state.profile.settings.lowFX
			if not lowFX then
				local base = model.PrimaryPart.Position
				self:_groundImpact(base, UI.Colors.gold, 4 + (tonumber(event.level) or 1))
				self:_effect(Vector3.new(8 * record.scale, 1.2, 1.2), CFrame.new(base + Vector3.new(0, 4 * record.scale, 0)) * CFrame.Angles(0, 0, math.pi / 2), UI.Colors.gold, 0.45, Enum.PartType.Cylinder, 0.55)
			end
			if self.audio and record.ownerId == self.player.UserId then self.audio:Cue("upgrade", 0.2) end
		end
		return
	elseif event.kind == "TowersStunned" then
		for _, id in ipairs(event.towerIds or {}) do self:_stun(id, event.duration) end
		return
	elseif event.kind == "Ability" then
		-- The caster's own copies of the leader hero raise their arms.
		local world = workspace:FindFirstChild("DoomWorld")
		local towers = world and world:FindFirstChild("Towers")
		for _, model in ipairs(towers and towers:GetChildren() or {}) do
			if model:GetAttribute("HeroId") == event.heroId and model:GetAttribute("OwnerId") == event.ownerId then
				local record = self:_record(model)
				if record then record.castAt = self.clock end
			end
		end
		local state=self.getState()
		local lowFX=state and state.profile and state.profile.settings and state.profile.settings.lowFX
		local tint=UI.color(event.color)
		local kind=event.abilityKind
		if typeof(event.position)=="Vector3" then
			self:Handle({kind="Pulse",position=event.position,color=event.color,radius=math.max(event.radius or 0,5),duration=math.clamp(event.duration or 0.5,0.5,6)})
			if not lowFX then
				local radius=math.max(event.radius or 0,5)
				if kind=="blast" or kind=="smite" or kind=="execute" then
					self:_groundImpact(event.position,tint,radius)
					self:_impact(event.position+Vector3.new(0,2,0),tint,4)
				elseif kind=="heal" or kind=="barrier" or kind=="rally" then
					for i=1,3 do
						self:_effect(Vector3.new(0.12,radius*1.5,radius*1.5),CFrame.new(event.position+Vector3.new(0,i*2,0))*CFrame.Angles(0,0,math.pi/2),tint,0.45,Enum.PartType.Cylinder,0.8)
					end
				end
				for i=1,6 do
					local a=i*math.pi/3
					local at=event.position+Vector3.new(math.cos(a)*radius*0.65,0.5,math.sin(a)*radius*0.65)
					if kind=="slow" or kind=="stun" or kind=="reveal" then
						self:_line(event.position+Vector3.new(0,0.5,0),at,tint,0.1,0.7)
					else self:_line(at+Vector3.new(0,12,0),at,tint,0.17,0.35) end
				end
			end
		end
		if event.ultimate and typeof(event.position)=="Vector3" then self:_ultimateBurst(event,tint,lowFX) end
		for i,point in ipairs(event.points or {}) do
			if i>(lowFX and 2 or 12) then break end
			if typeof(point)=="Vector3" then self:_line(point+Vector3.new(0,15,0),point,UI.color(event.color),0.3,0.4) end
		end
		if self.audio then self.audio:Cue("ability",0.35) end
		return
	end
	if event.kind == "Breach" then
		if typeof(event.position) == "Vector3" then
			self:Handle({kind = "Pulse", position = event.position, radius = 9 + (tonumber(event.damage) or 1),
				color = UI.Colors.red})
		end
		if self.audio then self.audio:Cue("breach", 0.25) end
		return
	end
	if event.kind == "EnemySync" then
		local seen = {}
		local lowFX = (function() local s = self.getState() return s and s.profile and s.profile.settings.lowFX end)()
		for _, enemy in ipairs(event.enemies or {}) do
			if typeof(enemy.position) ~= "Vector3" then continue end
			local key = tostring(enemy.id)
			seen[key] = true
			local current = self.enemies[key]
			if not current then
				local def = Catalog.Enemies[enemy.enemyId] or Catalog.Enemies.zombie
				local pool = self.pool[def.id]
				current = pool and table.remove(pool) or buildEnemy(def)
				current.position, current.direction = enemy.position, Vector3.new(0, 0, -1)
				current.phase = (tonumber(enemy.id) or #key * 17) * 1.73
				current.model.Parent = self.folder
				current.lastHP = enemy.hp
				self.enemies[key] = current
			end
			current.target = enemy.position
			local hp = enemy.hp or 1
			if current.lastHP and hp < current.lastHP - 0.5 then
				current.hitAt = self.clock
				-- The hit tell survives lowFX, because it is how a player reads which
				-- enemy their towers are working on. But reduced effects is also the
				-- design's "reduce flashes" option: eighty enemies strobing pure white
				-- is exactly what a photosensitive player turned it on to avoid, so
				-- under lowFX the tell becomes a low-contrast tint instead.
				if not current.flashUntil then
					for _, entry in ipairs(current.flashParts) do
						entry.part.Color = lowFX and entry.color:Lerp(FLASH_COLOR, 0.3) or FLASH_COLOR
					end
				end
				current.flashUntil = self.clock + 0.1
				if not lowFX then
					self:_popup(enemy.position + Vector3.new(0, 2.6 * current.scale, 0), current.lastHP - hp, current.def.boss and UI.Colors.gold or UI.Colors.red)
				end
			end
			current.lastHP = hp
			current.maxHP = enemy.maxHP or hp
			current.bar.Size = UDim2.fromScale(math.clamp(hp / math.max(enemy.maxHP or 1, 1), 0, 1), 1)
			local state = self.getState()
			local english = state and state.profile and state.profile.settings and state.profile.settings.language == "en"
			local flags, words = tonumber(enemy.st) or 0, {}
			current.statusFlags = flags
			for _, status in ipairs({{64,"VULNERÁVEL!","VULNERABLE!"},{128,"REVELADO","REVEALED"},{16,"ESCUDO","SHIELD"},{1,"ATORDOADO","STUNNED"},{4,"MARCADO","MARKED"},{32,"FRÁGIL","WEAKENED"},{8,"QUEIMANDO","BURNING"},{2,"LENTO","SLOWED"},{256,"ACELERADO","HASTED"}}) do
				if math.floor(flags/status[1])%2==1 then table.insert(words,status[english and 3 or 2]) end
				if #words==2 then break end
			end
			current.status.Visible = #words > 0
			current.status.Text = table.concat(words," · ")
			-- A cloaked enemy turns solid, with a red flash, the moment it is revealed.
			if current.def.stealth then
				local revealed = math.floor(flags / 128) % 2 == 1
				if revealed ~= (current.revealed == true) then
					current.revealed = revealed
					for _, piece in ipairs(current.pieces) do
						if piece.part.Name ~= "Shadow" and piece.part.Material ~= Enum.Material.Neon then
							piece.part.Transparency = revealed and 0 or piece.transparency
						end
					end
					if revealed and not lowFX then self:_impact(enemy.position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 90, 90), 1.4) end
				end
			end
			current.link = enemy.lk and tostring(enemy.lk) or nil
			if current.charges then
				local left = tonumber(enemy.ch) or 0
				for index, charge in ipairs(current.charges) do charge.Parent = index <= left and current.model or nil end
			end
		end
		for id in pairs(self.enemies) do if not seen[id] then self:Release(id) end end
		-- A dense horde must stay visible beneath its UI. Boss bars always
		-- remain; a small budget shows wounded/status enemies, newest hits first.
		local labels = {}
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position or Vector3.zero
		for id, enemy in pairs(self.enemies) do
			enemy.billboard.Enabled = enemy.def.boss == true
			if not enemy.def.boss and (enemy.lastHP < enemy.maxHP or (enemy.statusFlags or 0)>0) then
				table.insert(labels,{enemy=enemy,id=id,distance=(enemy.position-eye).Magnitude})
			end
		end
		table.sort(labels,function(a,b)
			local ah,bh=a.enemy.hitAt or -1,b.enemy.hitAt or -1
			if ah~=bh then return ah>bh end
			if a.distance~=b.distance then return a.distance<b.distance end
			return a.id<b.id
		end)
		for index=1,math.min(#labels,lowFX and 6 or 12) do labels[index].enemy.billboard.Enabled=true end
	elseif event.kind == "CoinSpawn" then
		if typeof(event.position) ~= "Vector3" then return end
		local key = tostring(event.id)
		local current = self.coins[key]
		if current then current.position, current.value = event.position, event.value; return end
		-- Match Gold pays for heroes now, so the coins are big enough to spot.
		local coin = part(self.folder, Vector3.new(0.3, 1.7, 1.7), UI.Colors.gold, Enum.Material.Neon)
		coin.Name, coin.Shape = "PersonalGold", Enum.PartType.Cylinder
		self.coins[key] = {part = coin, position = event.position, id = event.id, value = event.value, requestedAt = -10, born = self.clock}
	elseif event.kind == "CoinRemove" then
		local key = tostring(event.id)
		local coin = self.coins[key]
		if coin then
			self.coins[key] = nil
			local character = self.player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if root and #self.collecting < 16 then
				-- Coins swept up by a tower or a power fly there, not to the commander.
				coin.from, coin.born, coin.to = coin.part.Position, self.clock, typeof(event.to) == "Vector3" and event.to or nil
				table.insert(self.collecting, coin)
			else
				coin.part:Destroy()
			end
			if self.audio then self.audio:Cue("collect", 0.07) end
		end
	elseif event.kind == "Shot" then
		local state = self.getState()
		self:_aim(event.towerId, event.to)
		self:_recoil(event.towerId)
		local camera = workspace.CurrentCamera
		if self.audio and camera and typeof(event.to) == "Vector3" then
			self.audio:Shot(Effects.ShotSound(event.heroId), (event.to - camera.CFrame.Position).Magnitude)
		end
		if typeof(event.from) ~= "Vector3" or typeof(event.to) ~= "Vector3" or #self.shots >= 80 then return end
		local lowFX = state and state.profile and state.profile.settings.lowFX
		self:_heroShot(event, lowFX)
		-- Armour takes part of the hit: pale sparks fly off instead of a clean impact.
		if event.armored and not lowFX then
			for index = 1, 3 do
				local angle = index * 2.1 + self.shotSerial
				local away = event.to + Vector3.new(math.cos(angle) * 1.1, 0.9, math.sin(angle) * 1.1)
				local spark = self:_effect(Vector3.new(0.08, 0.08, 0.6), CFrame.lookAt(event.to, away), Color3.fromRGB(236, 234, 214), 0.16, nil, 0.1)
				if spark then spark.part.Name, spark.from, spark.to = "ArmorSpark", event.to, away end
			end
		end
	elseif event.kind == "Pulse" and typeof(event.position) == "Vector3" then
		local radius = event.radius or 8
		-- A telegraph carries its own duration and holds at full size: it marks
		-- an area the player has to read and act on, not an impact already over.
		local duration = math.clamp(tonumber(event.duration) or 0.42, 0.1, 6)
		local telegraph = duration > 1
		-- A disc, not a square: every area in the match is a radius check, and a
		-- square's corners would mark danger where there is none. A Cylinder's
		-- axis is X, so its thickness goes there and a quarter turn lays it flat.
		local width = radius * (telegraph and 2 or 0.7)
		-- Gameplay telegraphs have priority over cosmetic tracers at the cap.
		if #self.shots >= 80 then
			for index, effect in ipairs(self.shots) do
				if not effect.telegraph then
					effect.part.Parent = nil
					table.insert(self.shotPool, effect.part)
					table.remove(self.shots, index)
					break
				end
			end
		end
		local pulse = self:_effect(Vector3.new(0.14, width, width),
			CFrame.new(event.position + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2),
			UI.color(event.color), duration, Enum.PartType.Cylinder, 0.68)
		if pulse then
			pulse.telegraph = telegraph
			pulse.followEnemyId = event.followEnemyId and tostring(event.followEnemyId) or nil
			pulse.requiresShield = event.requiresShield == true
			if telegraph and type(event.warningText)=="table" then
				local board = pulse.part:FindFirstChild("Warning")
				if not board then
					board = Instance.new("BillboardGui")
					board.Name, board.Size, board.AlwaysOnTop, board.MaxDistance = "Warning", UDim2.fromOffset(180,32), true, 220
					board.StudsOffsetWorldSpace, board.Parent = Vector3.new(0,9,0), pulse.part
					UI.label(board,"",{Name="Text",Size=UDim2.fromScale(1,1),TextSize=13,TextColor3=UI.Colors.gold,TextStrokeTransparency=0.15})
				end
				local state = self.getState()
				local english = state and state.profile and state.profile.settings and state.profile.settings.language=="en"
				pulse.warning = event.warningText[english and "en" or "pt"] or "!"
				board.Text.Text, board.Enabled = pulse.warning, true
				pulse.warningBoard = board
			end
			pulse.growFrom, pulse.growTo = not telegraph and radius * 0.7 or nil, not telegraph and radius * 2.1 or nil
		end
	elseif event.kind == "Clear" then
		for _,record in pairs(self.soldiers) do record.model:Destroy() end; self.soldiers={}
		for id in pairs(self.enemies) do self:Release(id, true) end
		for _, death in ipairs(self.dying) do self:_poolEnemy(death.record) end
		self.dying = {}
		for _, coin in pairs(self.coins) do coin.part:Destroy() end
		for _, coin in ipairs(self.collecting) do coin.part:Destroy() end
		self.coins = {}
		self.collecting = {}
		for _, effect in ipairs(self.shots) do
			effect.part.Parent = nil
			table.insert(self.shotPool, effect.part)
		end
		self.shots = {}
		for _, popup in ipairs(self.popups) do
			popup.anchor.Parent = nil
			table.insert(self.popupPool, popup)
		end
		self.popups = {}
		for _, record in pairs(self.aims) do
			for _, star in ipairs(record.stars or {}) do star:Destroy() end
		end
		self.aims, self.aimsOrder = {}, {}
		self.towerModels, self.shakeAmount, self.shotSerial = nil, 0, 0
		if self.drone then self.drone:Destroy(); self.drone = nil end
	end
end

function Effects:Step(dt)
	local allyState=self.getState()
	local lowAllyFX=allyState and allyState.profile and allyState.profile.settings and allyState.profile.settings.lowFX
	for _,record in pairs(self.soldiers) do
		local previous=record.position; record.position=previous:Lerp(record.target,math.min(1,dt*12))
		local delta=record.target-previous
		local center=record.position+Vector3.new(0,2,0)
		if delta.Magnitude>0.02 then record.direction=delta.Unit end
		local pivot=CFrame.lookAt(center,center+(record.direction or Vector3.new(0,0,-1)))
		record.model:PivotTo(pivot)
		for _,leg in ipairs(record.legs) do leg.part.CFrame=pivot*leg.base*CFrame.Angles(lowAllyFX and 0 or math.sin(self.clock*10+leg.side*math.pi/2)*0.4,0,0) end
	end
	self.clock += dt
	if self.clock >= (self.dustResetAt or 0) then self.dustBudget, self.dustResetAt = 0, self.clock + 0.5 end
	local state = self.getState()
	local settings = state and state.profile and state.profile.settings or {}
	for _, enemy in pairs(self.enemies) do
		local delta = enemy.target - enemy.position
		if delta.Magnitude > 0.04 then
			local horizontal = Vector3.new(delta.X, 0, delta.Z)
			if horizontal.Magnitude > 0.04 then
				local facing = enemy.direction:Lerp(horizontal.Unit, math.min(1, dt * 14))
				if facing.Magnitude > 0.001 then enemy.direction = facing.Unit end
			end
		end
		enemy.position = enemy.position:Lerp(enemy.target, math.min(1, dt * 12))
		local bob = settings.lowFX and 0 or math.sin(self.clock * (enemy.def.air and 4 or 8) + enemy.phase) * (enemy.def.air and 0.2 or 0.055)
		local position = enemy.position + Vector3.new(0, (enemy.art and 0 or 2 * enemy.scale) + bob + (enemy.def.air and 6 or 0), 0)
		local pivot = CFrame.lookAt(position, position + enemy.direction)
		local family = enemy.def.family or enemy.def.id
		-- Runners sprint leaning into the road; everyone else walks upright.
		if family == "runner" and (enemy.statusFlags or 0) % 2 == 0 and not settings.lowFX then pivot *= CFrame.Angles(-0.3, 0, 0) end
		enemy.model:PivotTo(pivot)
		if enemy.groundShadow then
			enemy.groundShadow.CFrame = CFrame.new(enemy.position.X, enemy.position.Y + 0.08, enemy.position.Z) * CFrame.Angles(0, 0, math.pi / 2)
		end
		if enemy.flashUntil and self.clock >= enemy.flashUntil then clearFlash(enemy) end
		if not settings.lowFX or enemy.animated then
			-- All limb rests are relative to the torso pivot, not the floor.
			-- Reset them once when lowFX changes, so legs never freeze mid-stride.
			local phase = self.clock * (enemy.def.speed or 7) * 0.85 + enemy.phase
			local stopped = settings.lowFX or (enemy.statusFlags or 0)%2==1
			-- A brute's footfalls raise dust: a small, budgeted ring on the road.
			if family == "brute" and not stopped and not settings.lowFX then
				local stride = math.floor(phase / math.pi)
				if enemy.lastStep and stride ~= enemy.lastStep and self.dustBudget < 8 then
					self.dustBudget += 1
					self:_groundImpact(enemy.position, Color3.fromRGB(150, 128, 98), 1.4 * enemy.scale)
				end
				enemy.lastStep = stride
			end
			if enemy.legs then
				local hip = CFrame.new(0, enemy.legHeight / 2, 0)
				for _, leg in ipairs(enemy.legs) do
					local swing = stopped and 0 or math.sin(phase + (leg.side > 0 and math.pi or 0)) * 0.5
					local joint = leg.joint or hip
					leg.part.CFrame = pivot * leg.base * joint * CFrame.Angles(swing, 0, 0) * joint:Inverse()
				end
			end
			local shoulder = CFrame.new(0, 0.7 * enemy.scale, 0)
			for _, arm in ipairs(enemy.arms) do
				local swing = stopped and 0 or math.sin(phase + (arm.side < 0 and math.pi or 0)) * 0.23
				local joint = arm.joint or shoulder
				arm.part.CFrame = pivot * arm.base * joint * CFrame.Angles(swing, 0, 0) * joint:Inverse()
			end
			for _, wing in ipairs(enemy.wings) do
				local flap = settings.lowFX and 0 or math.sin(self.clock * 7 + enemy.phase) * 0.24
				wing.part.CFrame = pivot * wing.base * CFrame.Angles(0, 0, wing.side * flap)
			end
			enemy.animated = not settings.lowFX
		end
	end
	for index = #self.dying, 1, -1 do
		local death = self.dying[index]
		local life = math.clamp((self.clock - death.born) / 0.32, 0, 1)
		if life >= 1 then
			self:_poolEnemy(death.record)
			table.remove(self.dying, index)
		else
			death.record.model:PivotTo(death.pivot * CFrame.new(0, -life * 1.4, 0) * CFrame.Angles(life * 0.35, 0, 0))
			for _, piece in ipairs(death.record.pieces) do piece.part.Transparency = piece.transparency + (1 - piece.transparency) * life end
		end
	end
	self:_drawLinks(settings.lowFX)
	self:_turnTowers(dt)
	for i = #self.shots, 1, -1 do
		local effect = self.shots[i]
		if self.clock >= effect.expires then
			effect.part.Parent = nil
			table.insert(self.shotPool, effect.part)
			table.remove(self.shots, i)
		elseif effect.born then
			local life = math.clamp((self.clock - effect.born) / (effect.expires - effect.born), 0, 1)
			if effect.followEnemyId then
				local enemy = self.enemies[effect.followEnemyId]
				if enemy then
					effect.part.CFrame = CFrame.new(enemy.position.X,0.2,enemy.position.Z) * CFrame.Angles(0,0,math.pi/2)
					if effect.requiresShield and self.clock-effect.born>0.3 and math.floor((enemy.statusFlags or 0)/16)%2==0 then effect.expires=self.clock end
				else effect.expires = self.clock end
			end
			if effect.warningBoard then effect.warningBoard.Text.Text = effect.warning .. "  " .. math.max(1,math.ceil(effect.expires-self.clock)) .. "s" end
			if effect.fade then
				local fadeLife = effect.telegraph and math.max(0, (life - 0.78) / 0.22) or life
				effect.part.Transparency = effect.fade + (1 - effect.fade) * fadeLife
			end
			if effect.growFrom then
				local width = effect.growFrom + (effect.growTo - effect.growFrom) * life
				effect.part.Size = Vector3.new(effect.part.Size.X, width, width)
			end
			if effect.ballFrom then effect.part.Size = Vector3.one * (effect.ballFrom + (effect.ballTo - effect.ballFrom) * life) end
			if effect.from then
				local travel = effect.returning and math.sin(life * math.pi) or life
				local position = effect.from:Lerp(effect.to, travel) + Vector3.new(0, math.sin(life * math.pi) * (effect.arc or 0), 0)
				if effect.disc then
					effect.part.CFrame = CFrame.new(position) * CFrame.Angles(0, life * 18, math.pi / 2)
				elseif effect.arrow then
					effect.part.CFrame = CFrame.lookAt(position, position + (effect.to - effect.from))
				else
					effect.part.CFrame = CFrame.new(position) * CFrame.Angles(life * 3, 0, life * 4)
				end
			end
		end
	end
	for i = #self.popups, 1, -1 do
		local popup = self.popups[i]
		if self.clock >= popup.expires then
			popup.anchor.Parent = nil
			table.insert(self.popupPool, popup)
			table.remove(self.popups, i)
		else
			popup.anchor.CFrame += Vector3.new(0, dt * 1.6, 0)
			local remaining = popup.expires - self.clock
			popup.label.TextTransparency = remaining < 0.2 and (1 - remaining / 0.2) or 0
		end
	end
	local character = self.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	for index = #self.collecting, 1, -1 do
		local coin = self.collecting[index]
		local life = math.clamp((self.clock - coin.born) / 0.3, 0, 1)
		local target = coin.to or (self.drone and self.drone.Position) or (root and root.Position)
		if life >= 1 or not target then
			if target and not settings.lowFX and (coin.value or 0) > 0 then self:_popup(target, coin.value, UI.Colors.gold, "+") end
			coin.part:Destroy()
			table.remove(self.collecting, index)
		else
			local position = coin.from:Lerp(target, life * life) + Vector3.new(0, math.sin(life * math.pi) * 1.5, 0)
			coin.part.CFrame = CFrame.new(position) * CFrame.Angles(0, self.clock * 8, 0)
			coin.part.Size = Vector3.new(0.22, 1.15, 1.15) * (1 - life * 0.65)
		end
	end
	local radius = 6
	local profile = state and state.profile
	if profile then radius *= 1+((profile.talents or {}).magnet or 0)*0.08 end
	for _, coin in pairs(self.coins) do
		local age = self.clock - coin.born
		local pop = math.max(0, 1 - age / 0.35)
		local bob = settings.lowFX and 0 or math.sin(self.clock * 3 + coin.position.X) * 0.18
		coin.part.CFrame = CFrame.new(coin.position + Vector3.new(0, 1.2 + bob + math.sin(pop * math.pi) * 0.8, 0)) * CFrame.Angles(0, self.clock * 1.8, 0)
	end
	if root and self.clock >= self.collectAt then
		self.collectAt = self.clock + 0.18
		local nearest, distance
		for _, coin in pairs(self.coins) do
			local d = (Vector3.new(root.Position.X, 0, root.Position.Z) - Vector3.new(coin.position.X, 0, coin.position.Z)).Magnitude
			if d <= radius and self.clock - coin.requestedAt > 1 and (not distance or d < distance) then nearest, distance = coin, d end
		end
		if nearest then
			nearest.requestedAt = self.clock
			task.spawn(function() self.request("CollectCoin", {coinId = nearest.id}, true) end)
		end
	end
	local collector = profile and profile.passes and profile.passes.collector and state.phase ~= "Lobby" and state.phase ~= "Results"
	local vip = profile and profile.passes and profile.passes.vip == true
	if collector and root then
		-- The VIP shell is rebuilt when the pass arrives mid-session.
		if self.drone and self.droneVip ~= vip then
			self.drone:Destroy()
			self.drone = nil
		end
		if not self.drone then
			self.droneVip = vip
			self.drone = part(self.folder, vip and Vector3.new(1.5, 0.55, 1.5) or Vector3.new(1.2, 0.4, 1.2),
				vip and UI.Colors.gold or Color3.fromRGB(150, 172, 190), vip and Enum.Material.Neon or Enum.Material.Metal)
			self.drone.Name = "CollectorDrone"
			local light = Instance.new("PointLight")
			light.Color, light.Range, light.Brightness, light.Parent =
				vip and UI.Colors.gold or UI.Colors.green, vip and 9 or 5, vip and 1.3 or 0.7, self.drone
		end
		self.drone.CFrame = root.CFrame * CFrame.new(2.5, 2.6 + math.sin(self.clock * 2) * 0.25, 1)
	elseif self.drone then self.drone:Destroy(); self.drone = nil end
end

return Effects
