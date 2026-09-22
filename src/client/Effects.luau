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

local function buildEnemy(def)
	local model = Instance.new("Model")
	model.Name = "EnemyVisual"
	local color = UI.color(def.color)
	local scale = def.boss and 2.1 or (def.id == "brute" and 1.45 or 1)
	local torso = part(model, Vector3.new(1.6, 1.7, 0.85) * scale, color)
	torso.Shape, torso.Material = Enum.PartType.Ball, def.boss and Enum.Material.SmoothPlastic or Enum.Material.Fabric
	torso.Name = "Torso"
	torso.CFrame = CFrame.new(0, 2 * scale, 0)
	model.PrimaryPart = torso
	local head = part(model, Vector3.new(1.05, 1, 0.95) * scale, color:Lerp(Color3.fromRGB(135, 174, 115), 0.35))
	head.Shape = Enum.PartType.Ball
	head.Name = "Head"
	head.CFrame = CFrame.new(0, 3.35 * scale, 0)
	local legHeight = 1.25 * scale
	local legs, arms, wings = {}, {}, {}
	for _, x in ipairs({-1, 1}) do
		local arm = part(model, Vector3.new(0.48, 1.6, 0.5) * scale, color:Lerp(Color3.new(), 0.2))
		arm.Shape = Enum.PartType.Ball
		arm.CFrame = CFrame.new(x * 1.05 * scale, 1.95 * scale, -0.18 * scale) * CFrame.Angles(-0.3, 0, x * 0.16)
		table.insert(arms, {part = arm, base = torso.CFrame:Inverse() * arm.CFrame, side = x})
		local leg = part(model, Vector3.new(0.56 * scale, legHeight, 0.6 * scale), Color3.fromRGB(34, 38, 43))
		local base = CFrame.new(x * 0.44 * scale, 0.57 * scale, 0)
		leg.CFrame = base
		table.insert(legs, {part = leg, base = torso.CFrame:Inverse() * base, side = x})
		local eye = part(model, Vector3.new(0.17, 0.13, 0.08) * scale, Color3.fromRGB(163, 255, 88), Enum.Material.Neon)
		eye.CFrame = CFrame.new(x * 0.24 * scale, 3.48 * scale, -0.5 * scale)
	end
	if def.air then
		for _, side in ipairs({ -1, 1 }) do
			local wing = part(model, Vector3.new(2.2, 0.2, 1.35), color:Lerp(Color3.new(), 0.3), Enum.Material.Metal)
			wing.CFrame = CFrame.new(side * 1.75, 2.6, 0.4) * CFrame.Angles(0, side * 0.35, 0)
			table.insert(wings, {part = wing, base = torso.CFrame:Inverse() * wing.CFrame, side = side})
		end
		local engine = part(model, Vector3.new(0.65, 1.1, 0.9), Color3.fromRGB(106, 245, 207), Enum.Material.Neon)
		engine.CFrame = CFrame.new(0, 1.6, 0.8)
	end
	if def.armor and def.armor > 0 then
		local plate = part(model, Vector3.new(1.5, 1.25, 0.15) * scale, Color3.fromRGB(104, 117, 122), Enum.Material.Metal)
		plate.CFrame = CFrame.new(0, 2.1 * scale, -0.48 * scale)
	end
	-- Recognizable silhouettes, not just eight differently colored torsos.
	-- Each common enemy adds at most three pieces; only bosses spend more.
	if def.id == "runner" then
		local scarf = part(model, Vector3.new(0.65, 0.18, 1.9), Color3.fromRGB(235, 156, 73))
		scarf.CFrame = CFrame.new(0, 2.7, 0.85) * CFrame.Angles(-0.22, 0, 0)
	elseif def.id == "brute" then
		for _, side in ipairs({-1, 1}) do
			local fist = part(model, Vector3.new(0.85, 0.8, 0.85) * scale, color:Lerp(Color3.new(), 0.25))
			fist.CFrame = CFrame.new(side * 1.2 * scale, 1.1 * scale, -0.3 * scale)
		end
	elseif def.id == "armored" then
		local helmet = part(model, Vector3.new(1.35, 0.6, 1.3), Color3.fromRGB(65, 80, 91), Enum.Material.Metal)
		helmet.CFrame = CFrame.new(0, 3.75, 0.08)
		local shield = part(model, Vector3.new(1.05, 1.8, 0.24), Color3.fromRGB(70, 88, 100), Enum.Material.Metal)
		shield.CFrame = CFrame.new(-1.15, 1.6, -0.6) * CFrame.Angles(0, -0.15, -0.12)
	elseif def.stealth then
		local hood = part(model, Vector3.new(1.3, 0.65, 1.3), Color3.fromRGB(49, 38, 68), Enum.Material.Fabric)
		hood.CFrame = CFrame.new(0, 3.7, 0.1)
		local cloak = part(model, Vector3.new(1.65, 2.6, 0.22), Color3.fromRGB(72, 48, 96), Enum.Material.Fabric)
		cloak.CFrame = CFrame.new(0, 1.95, 0.55)
	elseif def.id == "support" then
		for _, side in ipairs({-1, 1}) do
			local tank = part(model, Vector3.new(0.6, 1.5, 0.6), Color3.fromRGB(174, 248, 115), Enum.Material.Neon)
			tank.CFrame = CFrame.new(side * 0.55, 2.45, 0.72)
		end
	elseif def.id == "summoner" then
		local mantle = part(model, Vector3.new(2.2, 0.4, 1.3), Color3.fromRGB(65, 37, 86), Enum.Material.Fabric)
		mantle.CFrame = CFrame.new(0, 2.8, 0)
		local staff = part(model, Vector3.new(0.16, 3.8, 0.16), Color3.fromRGB(89, 65, 100), Enum.Material.Metal)
		staff.CFrame = CFrame.new(1.35, 1.9, -0.3)
		local orb = part(model, Vector3.new(0.75, 0.75, 0.75), Color3.fromRGB(220, 131, 255), Enum.Material.Neon)
		orb.Shape, orb.CFrame = Enum.PartType.Ball, CFrame.new(1.35, 3.9, -0.3)
	end
	-- Only one boss exists at a time, so its silhouette can afford real detail
	-- instead of reading as a scaled-up infected.
	if def.boss then
		local accent = color:Lerp(Color3.new(1, 1, 1), 0.3)
		if def.id == "lizard" then
			local tail = part(model, Vector3.new(0.9, 0.7, 5.5) * scale, color:Lerp(Color3.new(), 0.15))
			tail.CFrame = CFrame.new(0, 1.5 * scale, 2.9 * scale) * CFrame.Angles(0.22, 0, 0)
			for index = 1, 3 do
				local crest = part(model, Vector3.new(0.22, 0.85 - index * 0.14, 0.7) * scale, accent)
				crest.CFrame = CFrame.new(0, (3.9 - index * 0.25) * scale, (0.5 + index * 0.75) * scale)
			end
		elseif def.id == "abomination" then
			for _, side in ipairs({ -1, 1 }) do
				local spine = part(model, Vector3.new(0.35, 1.5, 0.35) * scale, accent)
				spine.CFrame = CFrame.new(side * 0.55 * scale, 3.1 * scale, 0.45 * scale) * CFrame.Angles(0.5, 0, side * 0.25)
			end
			local hump = part(model, Vector3.new(2.1, 1.1, 1.2) * scale, color:Lerp(Color3.new(), 0.2))
			hump.CFrame = CFrame.new(0, 2.95 * scale, 0.5 * scale)
		elseif def.id == "redskull" then
			local coat = part(model, Vector3.new(2.1, 2.6, 0.3) * scale, Color3.fromRGB(38, 34, 40), Enum.Material.Fabric)
			coat.CFrame = CFrame.new(0, 1.9 * scale, 0.55 * scale)
			local cap = part(model, Vector3.new(1.3, 0.35, 1.25) * scale, Color3.fromRGB(38, 34, 40))
			cap.CFrame = CFrame.new(0, 3.95 * scale, 0)
		elseif def.id == "killmonger" then
			for _, side in ipairs({ -1, 1 }) do
				local pauldron = part(model, Vector3.new(0.8, 0.8, 0.9) * scale, Color3.fromRGB(196, 158, 78), Enum.Material.Metal)
				pauldron.CFrame = CFrame.new(side * 1.15 * scale, 2.75 * scale, 0)
			end
			local mask = part(model, Vector3.new(1.15, 1.1, 0.25) * scale, Color3.fromRGB(196, 158, 78), Enum.Material.Metal)
			mask.CFrame = CFrame.new(0, 3.35 * scale, -0.55 * scale)
		elseif def.id == "doom" then
			local cloak = part(model, Vector3.new(2.6, 3.4, 0.35) * scale, Color3.fromRGB(41, 62, 48), Enum.Material.Fabric)
			cloak.CFrame = CFrame.new(0, 2.1 * scale, 0.6 * scale)
			local hood = part(model, Vector3.new(1.5, 0.9, 1.4) * scale, Color3.fromRGB(41, 62, 48), Enum.Material.Fabric)
			hood.CFrame = CFrame.new(0, 3.95 * scale, 0.12 * scale)
			local faceplate = part(model, Vector3.new(1.1, 1.05, 0.22) * scale, Color3.fromRGB(176, 186, 190), Enum.Material.Metal)
			faceplate.CFrame = CFrame.new(0, 3.35 * scale, -0.55 * scale)
		end
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
			if def.stealth and piece.Material ~= Enum.Material.Neon then piece.Transparency = 0.32 end
			table.insert(pieces, {part = piece, rest = torso.CFrame:Inverse() * piece.CFrame, transparency = piece.Transparency})
		end
	end
	model:PivotTo(CFrame.new(0, 0, 0))
	-- Torso and head are the two parts a hit flash recolors: a Highlight per
	-- enemy would be prettier and completely unaffordable at 180 of them.
	return {
		model = model, bar = hp, status = status, scale = scale, def = def, lastHP = nil,
		legs = def.air and nil or legs, arms = arms, wings = wings, legHeight = legHeight,
		pieces = pieces, billboard = billboard,
		flashParts = { { part = torso, color = torso.Color }, { part = head, color = head.Color } },
		flashUntil = nil,
	}
end

function Effects.new(player, request, getState, audio)
	local self = setmetatable({}, Effects)
	self.player, self.request, self.getState, self.audio = player, request, getState, audio
	self.folder = Instance.new("Folder")
	self.folder.Name = "DoomClientVisuals"
	self.folder.Parent = workspace
	self.enemies, self.pool, self.coins, self.shots = {}, {}, {}, {}
	self.shotPool, self.clock, self.collectAt = {}, 0, 0
	self.shakeAmount = 0
	self.towerModels, self.popups, self.popupPool = nil, {}, {}
	self.aims = {}
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
	record.hitAt, record.statusFlags = nil, nil
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
	local pose = model and self.aims[model]
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

function Effects:_aim(towerId, target)
	local model = self:_towerModel(towerId)
	local base = model and model.PrimaryPart
	if not base or typeof(target) ~= "Vector3" then return end
	local record = self.aims[model]
	if not record then
		local parts = {}
		for _, child in ipairs(model:GetChildren()) do
			if child:IsA("BasePart") and child:GetAttribute("HeroGeometry") and not FIXED_TOWER_PARTS[child.Name] then
				local joint = child:GetAttribute("PoseJoint")
				table.insert(parts, { part = child, rest = child.CFrame, group = child:GetAttribute("PoseGroup"),
					joint = typeof(joint) == "Vector3" and CFrame.new(joint) or nil })
			end
		end
		record = { parts = parts, pivot = CFrame.new(base.Position), yaw = 0, target = 0, active = false,
			heroId = model:GetAttribute("HeroId"), waist = CFrame.new(base.Position + Vector3.new(0, 2.4 * (model:GetAttribute("FigureScale") or 1), 0)) }
		self.aims[model] = record
	end
	local offset = target - base.Position
	if math.abs(offset.X) + math.abs(offset.Z) < 0.5 then return end
	-- Figures are built facing -Z.
	record.target = math.atan2(-offset.X, -offset.Z)
	record.active = true
end

function Effects:_turnTowers(dt)
	local state = self.getState()
	local reduced = state and state.profile and state.profile.settings and state.profile.settings.lowFX
	for model, record in pairs(self.aims) do
		if model.Parent == nil then
			self.aims[model] = nil
		elseif record.active then
			local delta = ((record.target - record.yaw + math.pi) % (2 * math.pi)) - math.pi
			local settled = math.abs(delta) < 0.01
			record.yaw = settled and record.target or record.yaw + delta * math.min(1, dt * 14)
			local turn = record.pivot * CFrame.Angles(0, record.yaw, 0) * record.pivot:Inverse()
			local age = record.firedAt and self.clock - record.firedAt or 1
			local firing = age < 0.42
			local pulse = firing and math.sin(math.clamp(age / 0.42, 0, 1) * math.pi) or 0
			if reduced then pulse = 0 end
			local melee = record.heroId == "hulk" or record.heroId == "thor" or record.heroId == "groot" or record.heroId == "shangchi"
			local magic = record.heroId == "wanda" or record.heroId == "strange" or record.heroId == "silversurfer"
			local body = record.waist * CFrame.Angles(-pulse * (melee and 0.12 or 0.035), 0, 0) * record.waist:Inverse()
			for _, entry in ipairs(record.parts) do
				if entry.part.Parent then
					local transform = turn
					if entry.group then transform *= body end
					if entry.joint then
						local side = entry.group == "LeftArm" and -1 or 1
						transform *= entry.joint * CFrame.Angles(-pulse * (melee and 0.65 or magic and 0.28 or 0.16), 0, magic and side * pulse * 0.16 or 0) * entry.joint:Inverse()
					end
					entry.part.CFrame = transform * entry.rest
				end
			end
			if settled and not firing then record.active = false end
		end
	end
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

local MUZZLE_PARTS = {ironman="Repulsor",hawkeye="Arrow",spiderman="Hand",thor="Mjolnir",captain="Shield",widow="BatonCharge",
	bucky="RifleBarrel",rocket="GunMuzzle",warmachine="CannonMuzzle",starlord="BlasterGlow",wanda="ChaosSpell",strange="SpellGlyph",vision="MindGem",captainmarvel="PhotonFist"}

function Effects:_heroShot(event, lowFX)
	local from, target = event.from, event.to
	local model = self:_towerModel(event.towerId)
	local heroId = model and model:GetAttribute("HeroId")
	local muzzle = model and model:FindFirstChild(MUZZLE_PARTS[heroId] or "Hand")
	if muzzle then from = muzzle.Position end
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
	if heroId == "thor" then
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
	elseif heroId == "panther" then
		for index = -1, 1 do
			local offset = Vector3.new(index * 0.4, 0, 0)
			self:_line(target + offset + Vector3.new(-0.6, 0.9, 0), target + offset + Vector3.new(0.6, -0.9, 0), Color3.fromRGB(192, 155, 255), 0.11, 0.18)
		end
	elseif heroId == "hulk" or heroId == "antman" then
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
	elseif heroId == "wanda" then
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
	elseif heroId == "vision" then
		self:_line(from, target, Color3.fromRGB(252, 205, 99), 0.36, 0.22)
		self:_line(from, target, white, 0.1, 0.13)
	elseif heroId == "widow" then
		self:_line(from, target, Color3.fromRGB(240, 87, 99), 0.1, 0.11)
		self:_impact(target, Color3.fromRGB(255, 165, 138), 0.4)
	elseif heroId == "falcon" then
		local swoop = self:_effect(Vector3.new(0.6, 0.15, 0.15), CFrame.new(from), Color3.fromRGB(255, 150, 110), 0.22, nil, 0.15)
		if swoop then swoop.from, swoop.to, swoop.arc = from, target, 2.5 end
		self:_impact(target, Color3.fromRGB(255, 150, 110), 0.35)
	elseif heroId == "bucky" then
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
	elseif event.kind == "Ability" then
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
			for _, status in ipairs({{16,"ESCUDO","SHIELD"},{1,"ATORDOADO","STUNNED"},{4,"MARCADO","MARKED"},{32,"FRÁGIL","WEAKENED"},{8,"QUEIMANDO","BURNING"},{2,"LENTO","SLOWED"}}) do
				if math.floor(flags/status[1])%2==1 then table.insert(words,status[english and 3 or 2]) end
				if #words==2 then break end
			end
			current.status.Visible = #words > 0
			current.status.Text = table.concat(words," · ")
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
		local coin = part(self.folder, Vector3.new(0.22, 1.15, 1.15), UI.Colors.gold, Enum.Material.Neon)
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
				coin.from, coin.born = coin.part.Position, self.clock
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
		if typeof(event.from) ~= "Vector3" or typeof(event.to) ~= "Vector3" or #self.shots >= 80 then return end
		self:_heroShot(event, state and state.profile and state.profile.settings.lowFX)
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
		self.aims = {}
		self.towerModels, self.shakeAmount, self.shotSerial = nil, 0, 0
		if self.drone then self.drone:Destroy(); self.drone = nil end
	end
end

function Effects:Step(dt)
	self.clock += dt
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
		local position = enemy.position + Vector3.new(0, 2 * enemy.scale + bob + (enemy.def.air and 6 or 0), 0)
		local pivot = CFrame.lookAt(position, position + enemy.direction)
		enemy.model:PivotTo(pivot)
		if enemy.flashUntil and self.clock >= enemy.flashUntil then clearFlash(enemy) end
		if not settings.lowFX or enemy.animated then
			-- All limb rests are relative to the torso pivot, not the floor.
			-- Reset them once when lowFX changes, so legs never freeze mid-stride.
			local phase = self.clock * (enemy.def.speed or 7) * 0.85 + enemy.phase
			local stopped = settings.lowFX or (enemy.statusFlags or 0)%2==1
			if enemy.legs then
				local hip = CFrame.new(0, enemy.legHeight / 2, 0)
				for _, leg in ipairs(enemy.legs) do
					local swing = stopped and 0 or math.sin(phase + (leg.side > 0 and math.pi or 0)) * 0.5
					leg.part.CFrame = pivot * leg.base * hip * CFrame.Angles(swing, 0, 0) * hip:Inverse()
				end
			end
			local shoulder = CFrame.new(0, 0.7 * enemy.scale, 0)
			for _, arm in ipairs(enemy.arms) do
				local swing = stopped and 0 or math.sin(phase + (arm.side < 0 and math.pi or 0)) * 0.23
				arm.part.CFrame = pivot * arm.base * shoulder * CFrame.Angles(swing, 0, 0) * shoulder:Inverse()
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
		local target = self.drone and self.drone.Position or (root and root.Position)
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
