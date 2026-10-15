-- Hero powers a child falls in love with. Each of the 43 heroes casts with a
-- look of its own (SIGNATURES), composed from a dozen animated layers: rings
-- that sweep the ground, strikes and bolts from the sky, ice and wooden
-- spikes, flame rings, whirlpools, blade arcs, rains of missiles, cards and
-- coins, magic circles, shield domes, a sweeping beam. Particles use the
-- engine's own textures (rbxasset://textures/particles), nothing from the
-- Toolbox.
--
-- Purely cosmetic: it draws what the server's Ability event already decided.
-- Its parts come from a pool of their own (MAX_PARTS), apart from the attacks'
-- pool, so a power is never starved by a busy wave, and every delay runs on
-- its own clock (Step), so a test or a scene change sees a final state. No
-- light emission and Neon only in small cores: the tame bloom never washes
-- out. Reduced effects draws none of it (Effects keeps its single ring).
local PowerFX = {}
PowerFX.__index = PowerFX

local WHITE = Color3.new(1, 1, 1)
local UP = Vector3.new(0, 1, 0)
local FLAT = CFrame.Angles(0, 0, math.pi / 2)
local MAX_PARTS, MAX_EMITTERS = 110, 32
PowerFX.MAX_PARTS = MAX_PARTS

-- Particle looks: texture, lifetime, speed, size from/to, drag, pull, spread
-- (degrees), starting transparency, spin.
local PARTICLES = {
	spark = { "sparkles_main.dds", { 0.25, 0.5 }, { 14, 26 }, { 0.8, 0 }, 5, Vector3.new(0, -18, 0), 180, 0.05, 180 },
	star = { "sparkles_main.dds", { 0.7, 1.2 }, { 2, 6 }, { 1.3, 0 }, 1.5, Vector3.new(0, 5, 0), 180, 0.05, 120 },
	fire = { "fire_main.dds", { 0.45, 0.8 }, { 4, 9 }, { 2.4, 0.6 }, 1, Vector3.new(0, 12, 0), 16, 0.2, 90 },
	ember = { "fire_sparks_main.dds", { 0.5, 1 }, { 7, 15 }, { 0.6, 0.1 }, 1.5, Vector3.new(0, 7, 0), 70, 0.05, 180 },
	smoke = { "explosion01_smoke_main.dds", { 0.9, 1.5 }, { 2, 5 }, { 3, 7.5 }, 2, Vector3.new(0, 1.5, 0), 180, 0.35, 40 },
	core = { "explosion01_core_main.dds", { 0.28, 0.42 }, { 0, 1 }, { 3, 9 }, 0, Vector3.zero, 180, 0.15, 60 },
	implode = { "explosion01_implosion_main.dds", { 0.35, 0.45 }, { 0, 0.5 }, { 9, 1 }, 0, Vector3.zero, 180, 0.2, 60 },
	vortex = { "forcefield_vortex_main.dds", { 0.6, 0.9 }, { 0, 0.5 }, { 7, 2 }, 0, Vector3.zero, 180, 0.3, 400 },
	snow = { "sparkles_main.dds", { 0.9, 1.4 }, { 3, 7 }, { 0.6, 0.2 }, 1, Vector3.new(0, -4, 0), 180, 0.1, 90 },
	leaf = { "sparkles_main.dds", { 0.8, 1.3 }, { 5, 10 }, { 0.9, 0.3 }, 2, Vector3.new(0, -6, 0), 120, 0.1, 300 },
}
PowerFX.PARTICLES = PARTICLES

local function ease(kind, t)
	if kind == "linear" then return t end
	if kind == "in" then return t * t end
	if kind == "back" then
		local c = 1.70158
		return 1 + (c + 1) * (t - 1) ^ 3 + c * (t - 1) ^ 2
	end
	return 1 - (1 - t) * (1 - t)
end

local function ground(point, height)
	return Vector3.new(point.X, height or 0.28, point.Z)
end

local function around(center, radius, angle, height)
	return center + Vector3.new(math.cos(angle) * radius, height or 0, math.sin(angle) * radius)
end

function PowerFX.new(parent)
	local self = setmetatable({}, PowerFX)
	self.folder = Instance.new("Folder")
	self.folder.Name = "PowerFX"
	self.folder.Parent = parent
	self.live, self.pool, self.queue = {}, {}, {}
	self.emitters, self.emitterCount = {}, 0
	self.clock = 0
	self.random = Random.new(4242)
	return self
end

--==============================================================================
-- Pools: parts, particle emitters, delays
--==============================================================================
function PowerFX:_part(shape, color, material, transparency)
	if #self.live >= MAX_PARTS then return nil end
	local part = table.remove(self.pool)
	if not part then
		part = Instance.new("Part")
		part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch, part.CastShadow = true, false, false, false, false
		part.TopSurface, part.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	end
	part.Name = "PowerEffect"
	part.Shape = shape or Enum.PartType.Block
	part.Color, part.Material, part.Transparency = color, material or Enum.Material.Neon, transparency or 0.2
	local ring = part:FindFirstChild("RingGui")
	if ring then ring.Enabled = false end
	return part
end

-- A live record: animated every frame until its life runs out. Fields read by
-- _animate: from, to, arc, look, turn, spin, orbit, size0/size1, fade0/fade1,
-- ease, update (a custom motion instead of all of these).
function PowerFX:_spawn(record)
	record.born = self.clock + (record.delay or 0)
	record.life = math.max(record.life or 0.5, 0.05)
	record.part.Parent = nil
	table.insert(self.live, record)
	return record
end

function PowerFX:_release(record)
	local part = record.part
	if record.trail then record.trail.Enabled = false end
	part.Parent = nil
	table.insert(self.pool, part)
end

function PowerFX:_later(delay, action)
	table.insert(self.queue, { at = self.clock + delay, action = action })
end

function PowerFX:_emitter(kind, color)
	local spec = PARTICLES[kind]
	if not spec then return nil end
	if not self.root or self.root.Parent == nil then
		local root = Instance.new("Part")
		root.Name, root.Anchored, root.CanCollide, root.CanQuery, root.CanTouch = "PowerParticles", true, false, false, false
		root.Transparency, root.Size, root.CFrame = 1, Vector3.one, CFrame.new()
		root.Parent = self.folder
		self.root, self.emitters, self.emitterCount = root, {}, 0
	end
	local key = string.format("%s:%d:%d:%d", kind, math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
	local found = self.emitters[key]
	if found then return found end
	if self.emitterCount >= MAX_EMITTERS then
		-- Past the cap a burst borrows another colour's emitter of its kind.
		for other, entry in pairs(self.emitters) do
			if string.sub(other, 1, #kind + 1) == kind .. ":" then return entry end
		end
		return nil
	end
	local attachment = Instance.new("Attachment")
	attachment.Name = key
	attachment.Parent = self.root
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name, emitter.Texture, emitter.Rate, emitter.Enabled = kind, "rbxasset://textures/particles/" .. spec[1], 0, true
	emitter.Color = ColorSequence.new(color:Lerp(WHITE, 0.35), color)
	emitter.Lifetime, emitter.Speed = NumberRange.new(spec[2][1], spec[2][2]), NumberRange.new(spec[3][1], spec[3][2])
	emitter.Size, emitter.Transparency = NumberSequence.new(spec[4][1], spec[4][2]), NumberSequence.new(spec[8], 1)
	emitter.Drag, emitter.Acceleration, emitter.SpreadAngle = spec[5], spec[6], Vector2.new(spec[7], spec[7])
	emitter.Rotation, emitter.RotSpeed = NumberRange.new(0, 360), NumberRange.new(-spec[9], spec[9])
	emitter.LightEmission, emitter.LightInfluence = 0, 0.3
	emitter.Parent = attachment
	local entry = { attachment = attachment, emitter = emitter }
	self.emitters[key] = entry
	self.emitterCount += 1
	return entry
end

-- A burst of particles of a kind at a point, now or after a delay.
function PowerFX:Emit(kind, position, color, count, delay)
	if delay and delay > 0 then
		self:_later(delay, function() self:Emit(kind, position, color, count) end)
		return
	end
	local entry = self:_emitter(kind, color)
	if not entry then return end
	entry.attachment.WorldPosition = position
	entry.emitter:Emit(count)
end

-- A ribbon of light behind a moving part (Trail between two attachments).
function PowerFX:_trail(part, color, width, life)
	local trail = part:FindFirstChild("PowerTrail")
	if not trail then
		local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
		a0.Name, a1.Name = "TrailTop", "TrailBottom"
		a0.Parent, a1.Parent = part, part
		trail = Instance.new("Trail")
		trail.Name, trail.Attachment0, trail.Attachment1 = "PowerTrail", a0, a1
		trail.FaceCamera, trail.LightEmission, trail.LightInfluence, trail.MinLength = true, 0.1, 0.2, 0.05
		trail.Parent = part
	end
	trail.Attachment0.Position, trail.Attachment1.Position = Vector3.new(0, width / 2, 0), Vector3.new(0, -width / 2, 0)
	trail.Color = ColorSequence.new(color:Lerp(WHITE, 0.45), color)
	trail.Transparency = NumberSequence.new(0.2, 1)
	trail.WidthScale = NumberSequence.new(1, 0.15)
	trail.Lifetime = life or 0.3
	trail.Enabled = false
	return trail
end

local function ringGui(part, color)
	local gui = part:FindFirstChild("RingGui")
	if not gui then
		gui = Instance.new("SurfaceGui")
		gui.Name, gui.Face, gui.SizingMode, gui.CanvasSize, gui.LightInfluence = "RingGui", Enum.NormalId.Right, Enum.SurfaceGuiSizingMode.FixedSize, Vector2.new(256, 256), 0
		gui.Parent = part
		local frame = Instance.new("Frame")
		frame.Name, frame.BackgroundTransparency, frame.Size = "Ring", 1, UDim2.fromScale(1, 1)
		frame.Parent = gui
		local round = Instance.new("UICorner")
		round.CornerRadius = UDim.new(0.5, 0)
		round.Parent = frame
		local line = Instance.new("UIStroke")
		line.Name, line.Thickness = "Line", 14
		line.Parent = frame
	end
	gui.Enabled = true
	local line = gui.Ring.Line
	line.Color, line.Transparency = color:Lerp(WHITE, 0.3), 0
	return line
end

--==============================================================================
-- The clock
--==============================================================================
function PowerFX:_animate(record, t)
	local part = record.part
	if record.update then
		record.update(record, t, self.clock - record.born)
		return
	end
	local e = ease(record.ease, t)
	local position
	if record.orbit then
		local orbit = record.orbit
		local angle = orbit.angle + orbit.speed * (self.clock - record.born)
		local radius = orbit.r0 + (orbit.r1 - orbit.r0) * e
		position = orbit.center + Vector3.new(math.cos(angle) * radius, orbit.h0 + (orbit.h1 - orbit.h0) * e, math.sin(angle) * radius)
	elseif record.to then
		position = record.from:Lerp(record.to, e) + Vector3.new(0, math.sin(t * math.pi) * (record.arc or 0), 0)
	else
		position = record.from
	end
	local frame = CFrame.new(position)
	if record.look and record.to then
		local ahead = record.to - record.from
		if ahead.Magnitude > 0.01 then frame = CFrame.lookAt(position, position + ahead + Vector3.new(0.001, 0, 0.001)) end
	end
	if record.turn then frame *= record.turn end
	if record.spin then
		local age = self.clock - record.born
		frame *= CFrame.Angles(record.spin.X * age, record.spin.Y * age, record.spin.Z * age)
	end
	part.CFrame = frame
	if record.size1 then part.Size = record.size0:Lerp(record.size1, record.sizeEase and ease(record.sizeEase, t) or e) end
	if record.fade1 then
		local fade = record.lateFade and math.max(0, (t - 0.65) / 0.35) or t
		part.Transparency = record.fade0 + (record.fade1 - record.fade0) * fade
	end
	if record.stroke then record.stroke.Transparency = math.clamp(t * t, 0, 1) end
end

function PowerFX:Step(dt)
	self.clock += dt
	for index = #self.queue, 1, -1 do
		local entry = self.queue[index]
		if self.clock >= entry.at then
			table.remove(self.queue, index)
			-- A broken layer never stops the others; the client test reads lastError.
			local ok, problem = pcall(entry.action)
			if not ok then self.lastError = problem end
		end
	end
	for index = #self.live, 1, -1 do
		local record = self.live[index]
		if self.clock >= record.born then
			local t = (self.clock - record.born) / record.life
			if t >= 1 then
				table.remove(self.live, index)
				self:_release(record)
			else
				if record.part.Parent == nil then
					record.part.Parent = self.folder
					if record.trail then
						self:_animate(record, 0)
						record.trail:Clear()
						record.trail.Enabled = true
					end
				end
				self:_animate(record, t)
			end
		end
	end
end

-- A scene change: everything goes back to the pool at once.
function PowerFX:Clear()
	for _, record in ipairs(self.live) do self:_release(record) end
	self.live, self.queue = {}, {}
end

function PowerFX:Count()
	local shown = 0
	for _, record in ipairs(self.live) do if record.part.Parent ~= nil then shown += 1 end end
	return shown, #self.live
end

--==============================================================================
-- Layers
--==============================================================================
-- A ring on the ground that swells from r0 to r1 (or closes in, r0 > r1): a
-- faint disc with a bright rim, so it reads as a shockwave and not a stain.
function PowerFX:Ring(center, color, r0, r1, life, delay, height)
	local part = self:_part(Enum.PartType.Cylinder, color, Enum.Material.Neon, 0.88)
	if not part then return nil end
	return self:_spawn({ part = part, from = ground(center, height), turn = FLAT, size0 = Vector3.new(0.12, r0 * 2, r0 * 2), size1 = Vector3.new(0.12, r1 * 2, r1 * 2),
		fade0 = 0.88, fade1 = 1, stroke = ringGui(part, color), life = life or 0.5, delay = delay })
end

-- A ball of light that swells and fades: the heart of a blast.
function PowerFX:Flash(at, color, d0, d1, life, delay, fade0)
	local part = self:_part(Enum.PartType.Ball, color, Enum.Material.Neon, fade0 or 0.35)
	if not part then return nil end
	return self:_spawn({ part = part, from = at, size0 = Vector3.one * d0, size1 = Vector3.one * d1, fade0 = fade0 or 0.35, fade1 = 1, life = life or 0.3, delay = delay })
end

-- A column of light standing on a point that narrows as it fades.
function PowerFX:Column(at, color, height, width, life, delay, fade0)
	local part = self:_part(Enum.PartType.Cylinder, color, Enum.Material.Neon, fade0 or 0.45)
	if not part then return nil end
	local base = ground(at, 0.2)
	return self:_spawn({ part = part, from = base + Vector3.new(0, height / 2, 0), turn = FLAT, size0 = Vector3.new(height, width, width),
		size1 = Vector3.new(height, width * 0.2, width * 0.2), sizeEase = "in", fade0 = fade0 or 0.45, fade1 = 1, life = life or 0.5, delay = delay })
end

-- The burst every explosion shares: a ball of light, a ring, sparks, a core and smoke.
function PowerFX:Boom(at, color, size, delay)
	local base = ground(at, 0.3)
	self:Flash(base + UP * size * 0.45, color:Lerp(WHITE, 0.25), size * 0.6, size * 2.4, 0.3, delay)
	self:Ring(base, color, size * 0.3, size * 2, 0.42, delay)
	self:Emit("core", base + UP * size * 0.4, color, 2, delay)
	self:Emit("spark", base + UP, color, 12, delay)
	self:Emit("smoke", base, color:Lerp(Color3.fromRGB(70, 70, 82), 0.65), 3, delay)
end

-- A pillar of light from the sky that slams down on a point and thins out.
function PowerFX:SkyStrike(at, color, width, delay)
	local base = ground(at, 0.2)
	local part = self:_part(Enum.PartType.Cylinder, color, Enum.Material.Neon, 0.3)
	if part then
		self:_spawn({ part = part, from = base + Vector3.new(0, 35, 0), turn = FLAT, size0 = Vector3.new(70, width, width),
			size1 = Vector3.new(70, width * 0.12, width * 0.12), sizeEase = "in", fade0 = 0.3, fade1 = 1, life = 0.5, delay = delay })
	end
	self:Flash(base + UP, color:Lerp(WHITE, 0.35), width, width * 4, 0.35, delay)
	self:Ring(base, color, width * 0.4, width * 4.5, 0.5, delay)
	self:Emit("spark", base + UP, color, 26, delay)
	self:Emit("core", base + UP * 2, color, 3, delay)
end

-- A jagged bolt between two points, gone in a blink, with a spark where it lands.
function PowerFX:Bolt(from, to, color, width, delay, segments)
	segments = segments or 4
	local delta = to - from
	if delta.Magnitude < 0.1 then return end
	local side = delta.Unit:Cross(UP)
	if side.Magnitude < 0.1 then side = Vector3.new(1, 0, 0) end
	side = side.Unit
	local bright = color:Lerp(WHITE, 0.5)
	local previous = from
	for index = 1, segments do
		local point = index == segments and to
			or from:Lerp(to, index / segments) + side * self.random:NextNumber(-1.6, 1.6) + Vector3.new(0, self.random:NextNumber(-0.8, 0.8), 0)
		local length = (point - previous).Magnitude
		local part = length > 0.05 and self:_part(Enum.PartType.Block, bright, Enum.Material.Neon, 0.05)
		if part then
			part.Size = Vector3.new(width, width, length)
			self:_spawn({ part = part, from = (previous + point) / 2, turn = nil, life = 0.22, delay = delay, fade0 = 0.05, fade1 = 1,
				update = function(record, t)
					record.part.CFrame = CFrame.lookAt(record.from, point + Vector3.new(0.001, 0, 0.001))
					record.part.Transparency = 0.05 + 0.95 * t
				end })
		end
		previous = point
	end
	self:Flash(to, bright, width * 4, width * 9, 0.22, delay, 0.3)
	self:Emit("spark", to, color, 8, delay)
end

-- Something flying from one point to another with a ribbon of light behind it
-- (a meteor, a missile, a card, an arrow, a coin), then landing. options:
-- shape, size, material, life, delay, arc, trail (width), spin, look, land.
function PowerFX:Projectile(from, to, color, options)
	options = options or {}
	local part = self:_part(options.shape or Enum.PartType.Block, color, options.material or Enum.Material.Neon, options.fade or 0.05)
	if not part then return nil end
	part.Size = options.size or Vector3.new(0.6, 0.6, 1.6)
	local record = { part = part, from = from, to = to, arc = options.arc, look = options.look ~= false, spin = options.spin, life = options.life or 0.45,
		delay = options.delay, ease = options.ease or "in" }
	if options.trail then record.trail = self:_trail(part, options.trailColor or color, options.trail, options.trailLife or 0.28) end
	self:_spawn(record)
	if options.land then self:_later((options.delay or 0) + record.life, options.land) end
	return record
end

-- A rain of projectiles over an area, each ending in its own small blast.
-- options: count, height, spacing, size, shape, boom (blast size), spin, trail.
function PowerFX:Rain(center, radius, color, options)
	options = options or {}
	for index = 1, options.count or 6 do
		local angle = index * 2.39996 + self.random:NextNumber(0, 0.4)
		local spot = ground(around(center, radius * math.sqrt(index / (options.count or 6)), angle), 0.3)
		local from = spot + Vector3.new(options.slant or 10, options.height or 38, (options.slant or 10) * 0.4)
		local delay = (options.delay or 0) + (index - 1) * (options.spacing or 0.07)
		local boom = options.boom or 2.2
		self:Projectile(from, spot, color, { size = options.size, shape = options.shape, spin = options.spin, delay = delay, life = options.life or 0.42,
			trail = options.trail or 0.45, trailColor = options.trailColor, material = options.material,
			land = boom > 0 and function() self:Boom(spot, options.boomColor or color, boom) end or nil })
	end
end

-- Spikes bursting out of the ground in a ring (ice, wood, crystal): each one
-- shoots up in a blink, stands, then sinks back as it fades.
function PowerFX:Spikes(center, radius, color, count, height, material, delay)
	for index = 1, count do
		local angle = index * math.pi * 2 / count + self.random:NextNumber(-0.15, 0.15)
		local reach = radius * (index % 2 == 0 and 0.95 or 0.6)
		local base = ground(around(center, reach, angle), 0)
		local tall = height * (0.7 + 0.3 * ((index * 7) % 3) / 2)
		local width = math.max(0.6, tall * 0.28)
		local lean = CFrame.Angles(0, -angle, 0) * CFrame.Angles(0, 0, -0.32)
		local part = self:_part(Enum.PartType.Block, color, material or Enum.Material.Ice, 0.1)
		if part then
			part.Size = Vector3.new(width, tall, width)
			self:_spawn({ part = part, life = 1.25, delay = (delay or 0) + index * 0.025,
				update = function(record, t)
					local rise = ease("back", math.min(1, t / 0.18))
					local sink = math.max(0, (t - 0.72) / 0.28)
					local lift = tall * (rise - sink) - tall / 2
					record.part.CFrame = CFrame.new(base + Vector3.new(0, lift, 0)) * lean
					record.part.Transparency = 0.1 + 0.9 * sink
				end })
		end
	end
end

-- Flames dancing up from points on a circle, embers drifting off them.
function PowerFX:FlameRing(center, radius, color, points, delay, burst)
	for index = 1, points do
		local at = ground(around(center, radius, index * math.pi * 2 / points), 0.6)
		local when = (delay or 0) + index * 0.03
		self:Emit("fire", at, color, burst or 4, when)
		self:Emit("ember", at + UP, color:Lerp(WHITE, 0.3), 2, when)
	end
end

-- Pieces orbiting a point (rings, runes, stars, a swarm): from radius r0 to
-- r1 over their life. options: count, r0, r1, h0, h1, speed, size, shape,
-- material, life, delay, trail, flat (lie them flat), spin.
function PowerFX:Orbit(center, color, options)
	local count = options.count or 6
	for index = 1, count do
		local part = self:_part(options.shape or Enum.PartType.Ball, color, options.material or Enum.Material.Neon, options.fade or 0.1)
		if part then
			part.Size = options.size or Vector3.one * 0.8
			local record = { part = part, life = options.life or 0.9, delay = (options.delay or 0) + (options.stagger or 0) * index,
				orbit = { center = center, angle = index * math.pi * 2 / count, speed = (options.speed or 6) * ((options.alternate and index % 2 == 0) and -1 or 1),
					r0 = options.r0 or 4, r1 = options.r1 or 1, h0 = options.h0 or 1.5, h1 = options.h1 or (options.h0 or 1.5) },
				turn = options.flat and FLAT or nil, spin = options.spin, ease = options.ease or "out", fade0 = options.fade or 0.1, fade1 = options.fadeTo or 0.85, lateFade = true }
			if options.trail then record.trail = self:_trail(part, options.trailColor or color, options.trail, options.trailLife or 0.25) end
			if options.ring then record.stroke = ringGui(part, color); part.Transparency = 1; record.fade0, record.fade1 = 1, 1 end
			self:_spawn(record)
		end
	end
end

-- A blade's arc: a crescent of five short segments revealed in a sweep,
-- standing up toward the camera, with sparks along it.
function PowerFX:Slash(at, color, length, yaw, delay, width)
	width = width or 0.45
	local bright = color:Lerp(WHITE, 0.4)
	local center = ground(at, 2.2)
	local basis = CFrame.new(center) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(-60), 0, 0)
	for index = 1, 5 do
		local a = (index - 3) * 0.28
		local point = basis * CFrame.new(math.sin(a) * length / 2, math.cos(a) * length * 0.18 - length * 0.12, 0)
		local part = self:_part(Enum.PartType.Block, bright, Enum.Material.Neon, 0.05)
		if part then
			local thick = width * (1 - math.abs(index - 3) * 0.25)
			part.Size = Vector3.new(length / 4.2, thick, 0.12)
			self:_spawn({ part = part, from = point.Position, turn = (point - point.Position) * CFrame.Angles(0, 0, -a), life = 0.32, delay = (delay or 0) + index * 0.025,
				fade0 = 0.05, fade1 = 1, size0 = part.Size, size1 = Vector3.new(length / 4.2, thick * 0.3, 0.12), ease = "in" })
		end
	end
	self:Emit("spark", center, color, 8, (delay or 0) + 0.06)
end

-- A dome of shimmering force over the area, swelling in with a bounce.
function PowerFX:Dome(center, radius, color, life, delay)
	local part = self:_part(Enum.PartType.Ball, color, Enum.Material.ForceField, 0.15)
	if part then
		local base = ground(center, 0)
		self:_spawn({ part = part, from = base, size0 = Vector3.one * radius * 0.6, size1 = Vector3.one * radius * 2, sizeEase = "back",
			fade0 = 0.15, fade1 = 1, lateFade = true, life = life or 1.4, delay = delay })
	end
	self:Ring(center, color, radius * 0.4, radius, 0.6, delay)
end

-- Rays of light shooting out from a point (a starburst), at a height.
function PowerFX:Rays(center, color, count, length, delay, height, width)
	local base = ground(center, height or 1.5)
	local bright = color:Lerp(WHITE, 0.35)
	for index = 1, count do
		local angle = index * math.pi * 2 / count + self.random:NextNumber(-0.1, 0.1)
		local direction = Vector3.new(math.cos(angle), 0.08, math.sin(angle)).Unit
		local reach = length * (index % 2 == 0 and 1 or 0.7)
		local part = self:_part(Enum.PartType.Block, bright, Enum.Material.Neon, 0.1)
		if part then
			local thick = width or 0.45
			part.Size = Vector3.new(thick, thick, 0.2)
			self:_spawn({ part = part, life = 0.45, delay = delay,
				update = function(record, t)
					local grow = ease("out", math.min(1, t / 0.4)) * reach
					record.part.Size = Vector3.new(thick * (1 - t * 0.7), thick * (1 - t * 0.7), math.max(0.2, grow))
					record.part.CFrame = CFrame.lookAt(base + direction * grow / 2, base + direction * reach)
					record.part.Transparency = 0.1 + 0.9 * math.max(0, (t - 0.45) / 0.55)
				end })
		end
	end
end

-- Lines on the ground radiating from the centre with rings joining them: a
-- web, or (dark, with debris thrown up) the cracks of a smash.
function PowerFX:Web(center, radius, color, spokes, rings, delay, life, height)
	local base = ground(center, height or 0.35)
	local corners = {}
	for index = 1, spokes do
		local angle = index * math.pi * 2 / spokes
		corners[index] = angle
		local tip = base + Vector3.new(math.cos(angle), 0, math.sin(angle)) * radius
		local part = self:_part(Enum.PartType.Block, color, Enum.Material.Neon, 0.15)
		if part then
			part.Size = Vector3.new(0.18, 0.12, radius)
			self:_spawn({ part = part, from = (base + tip) / 2, life = life or 1.2, delay = delay, fade0 = 0.15, fade1 = 1, lateFade = true,
				turn = CFrame.lookAt(Vector3.zero, tip - base) })
		end
	end
	for ring = 1, rings do
		local reach = radius * ring / (rings + 0.4)
		for index = 1, spokes do
			local a, b = corners[index], corners[index % spokes + 1]
			local p1 = base + Vector3.new(math.cos(a), 0, math.sin(a)) * reach
			local p2 = base + Vector3.new(math.cos(b), 0, math.sin(b)) * reach
			local part = self:_part(Enum.PartType.Block, color, Enum.Material.Neon, 0.25)
			if part then
				part.Size = Vector3.new(0.14, 0.1, (p2 - p1).Magnitude)
				self:_spawn({ part = part, from = (p1 + p2) / 2, turn = CFrame.lookAt(Vector3.zero, p2 - p1), life = life or 1.2,
					delay = (delay or 0) + ring * 0.06, fade0 = 0.25, fade1 = 1, lateFade = true })
			end
		end
	end
end

-- The cracks of a smash: dark lines across the ground, chunks thrown up and
-- falling back, dust rolling out.
function PowerFX:Cracks(center, radius, color, count, delay)
	local dark = color:Lerp(Color3.fromRGB(40, 32, 26), 0.75)
	self:Web(center, radius, dark, count or 7, 0, delay, 1.4, 0.32)
	for index = 1, 6 do
		local angle = index * math.pi / 3 + self.random:NextNumber(-0.3, 0.3)
		local from = ground(center, 0.6)
		local to = ground(around(center, radius * self.random:NextNumber(0.5, 0.9), angle), 0.4)
		self:Projectile(from, to, Color3.fromRGB(96, 84, 72), { size = Vector3.new(0.9, 0.7, 0.9), material = Enum.Material.Slate, arc = 5, life = 0.55,
			delay = delay, ease = "linear", look = false, spin = Vector3.new(8, 5, 0) })
	end
	self:Emit("smoke", ground(center, 0.5), Color3.fromRGB(150, 130, 105), 6, delay)
end

-- A wall of water (or wind) running out from the centre and sinking.
function PowerFX:Wave(center, radius, color, count, delay)
	local base = ground(center, 0)
	for index = 1, count do
		local angle = index * math.pi * 2 / count
		local direction = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local part = self:_part(Enum.PartType.Block, color, Enum.Material.Glass, 0.35)
		if part then
			local arc = 2 * math.pi * radius / count
			self:_spawn({ part = part, life = 0.9, delay = delay,
				update = function(record, t)
					local e = ease("out", t)
					local reach = radius * (0.25 + 0.95 * e)
					local tall = 5.5 * (1 - t * 0.8)
					record.part.Size = Vector3.new(arc * (0.25 + 0.95 * e) * 1.05, tall, 1.1)
					record.part.CFrame = CFrame.lookAt(base + direction * reach + Vector3.new(0, tall / 2, 0), base + direction * (reach + 1) + Vector3.new(0, tall / 2, 0))
					record.part.Transparency = 0.35 + 0.65 * t
				end })
		end
		if index % 3 == 0 then self:Emit("snow", ground(around(center, radius * 0.9, angle), 1.5), WHITE, 4, (delay or 0) + 0.35) end
	end
end

-- A magic circle drawn on the ground: two rims turning opposite ways and
-- spokes between them.
function PowerFX:Circle(center, radius, color, delay, life)
	life = life or 1.4
	local base = ground(center, 0.32)
	for index, scale in ipairs({ 1, 0.62 }) do
		local part = self:_part(Enum.PartType.Cylinder, color, Enum.Material.Neon, 1)
		if part then
			local line = ringGui(part, color)
			part.Size = Vector3.new(0.1, radius * 2 * scale, radius * 2 * scale)
			self:_spawn({ part = part, life = life, delay = delay,
				update = function(record, t)
					local grow = ease("back", math.min(1, t / 0.25))
					local size = radius * 2 * scale * math.max(0.05, grow)
					record.part.Size = Vector3.new(0.1, size, size)
					record.part.CFrame = CFrame.new(base) * CFrame.Angles(0, (index == 1 and 1.2 or -1.8) * t * 3, 0) * FLAT
					line.Transparency = math.max(0, (t - 0.7) / 0.3)
				end })
		end
	end
	for index = 1, 6 do
		local part = self:_part(Enum.PartType.Block, color:Lerp(WHITE, 0.25), Enum.Material.Neon, 0.2)
		if part then
			part.Size = Vector3.new(0.2, 0.1, radius * 0.36)
			self:_spawn({ part = part, life = life, delay = delay,
				update = function(record, t)
					local angle = index * math.pi / 3 + t * 3.6
					local reach = radius * 0.81 * ease("back", math.min(1, t / 0.25))
					local at = base + Vector3.new(math.cos(angle), 0, math.sin(angle)) * reach
					record.part.CFrame = CFrame.lookAt(at, at + Vector3.new(math.cos(angle), 0, math.sin(angle)))
					record.part.Transparency = 0.2 + 0.8 * math.max(0, (t - 0.7) / 0.3)
				end })
		end
	end
	self:Emit("star", base + UP, color, 10, delay)
end

-- A beam from high above sweeping across the area (an optic blast, a heat
-- ray), setting the ground alight where it passes.
function PowerFX:Sweep(center, radius, color, width, delay)
	local base = ground(center, 0.3)
	local origin = base + Vector3.new(-radius * 0.6, 28, -radius * 0.9)
	local side = Vector3.new(1, 0, -0.4).Unit
	local part = self:_part(Enum.PartType.Block, color:Lerp(WHITE, 0.2), Enum.Material.Neon, 0.15)
	if part then
		self:_spawn({ part = part, life = 0.7, delay = delay,
			update = function(record, t)
				local target = base + side * radius * (ease("inout", t) * 2 - 1)
				local length = (target - origin).Magnitude
				record.part.Size = Vector3.new(width * (1 - t * 0.5), width * (1 - t * 0.5), length)
				record.part.CFrame = CFrame.lookAt((origin + target) / 2, target)
				record.part.Transparency = 0.15 + 0.85 * math.max(0, (t - 0.75) / 0.25)
			end })
	end
	for index = 0, 5 do
		local spot = base + side * radius * (index / 5 * 2 - 1)
		self:Emit("fire", spot + UP * 0.5, color, 3, (delay or 0) + index * 0.12)
		self:Emit("spark", spot + UP, color, 5, (delay or 0) + index * 0.12)
	end
end

--==============================================================================
-- Signatures: one per hero, in the power's colour
--==============================================================================
local RAINBOW = { Color3.fromRGB(255, 90, 120), Color3.fromRGB(255, 170, 60), Color3.fromRGB(255, 230, 90),
	Color3.fromRGB(110, 230, 120), Color3.fromRGB(90, 190, 255), Color3.fromRGB(180, 120, 255) }

local SIGNATURES = {}
PowerFX.SIGNATURES = SIGNATURES
-- Signatures that draw the bolts to the enemies their power struck (points).
PowerFX.DRAWS_POINTS = { thor = true, wasp = true }

-- A spread from 0.5 to 1 that differs per piece but not per cast.
local function spread(index)
	return 0.5 + ((index * 37) % 11) / 22
end

-- Armour of Iron: a barrage of micro-missiles drops out of the sky.
SIGNATURES.ironman = function(fx, c, r, color)
	fx:Rain(c, r * 0.75, Color3.fromRGB(150, 225, 255), { count = 7, size = Vector3.new(0.45, 0.45, 2), trail = 0.5, boom = 2.4, boomColor = color, spacing = 0.07 })
	fx:Ring(c, color, r * 0.2, r * 1.1, 0.5, 0.6)
end
-- Eagle Eye: the target is locked, then one great arrow falls on it.
SIGNATURES.hawkeye = function(fx, c, r, color)
	fx:Ring(c, color, r * 1.3, r * 0.15, 0.45)
	fx:Ring(c, color:Lerp(WHITE, 0.4), r * 0.9, r * 0.1, 0.45, 0.08)
	fx:Projectile(ground(c, 34) + Vector3.new(6, 0, 3), ground(c, 0.6), Color3.fromRGB(230, 210, 255),
		{ size = Vector3.new(0.35, 0.35, 5), trail = 0.7, delay = 0.35, life = 0.25, land = function() fx:Boom(c, color, 3.2); fx:Rays(c, color, 8, r * 0.9, 0) end })
end
-- Wing Man: his drone sweeps circles over the squad and lifts them.
SIGNATURES.falcon = function(fx, c, r, color)
	fx:Orbit(ground(c, 0), color, { count = 2, r0 = r * 0.4, r1 = r, h0 = 4, h1 = 6, speed = 9, size = Vector3.one * 0.9, trail = 0.8, life = 1.2 })
	for level = 0, 2 do fx:Ring(c, color, r * 0.3, r * 0.9, 0.45, level * 0.18, 0.3 + level * 1.6) end
	fx:Emit("star", ground(c, 1), color, 14, 0.2)
end
-- Silver Soldier: a flashbang, then smoke.
SIGNATURES.bucky = function(fx, c, r, color)
	fx:Flash(ground(c, 1.5), WHITE, 2, r * 1.6, 0.35, 0, 0.25)
	fx:Ring(c, WHITE, r * 0.2, r * 1.3, 0.4)
	fx:Ring(c, color, r * 0.2, r, 0.5, 0.12)
	fx:Emit("smoke", ground(c, 0.5), Color3.fromRGB(170, 175, 185), 8, 0.1)
	fx:Emit("spark", ground(c, 1), WHITE, 14)
end
-- City Spider: a web thrown over the road.
SIGNATURES.spiderman = function(fx, c, r, color)
	fx:Web(c, r, color, 8, 2, 0, 1.6)
	fx:Projectile(ground(c, 14) + Vector3.new(4, 0, 0), ground(c, 0.4), color, { size = Vector3.new(0.3, 0.3, 2), trail = 0.3, life = 0.2 })
	fx:Emit("spark", ground(c, 1), color, 10, 0.15)
end
-- Dark Widow: an electric bite, sparking in red.
SIGNATURES.widow = function(fx, c, r, color)
	for index = 1, 4 do
		local angle = index * math.pi / 2 + 0.4
		fx:Bolt(ground(around(c, r * 0.9, angle), 2), ground(c, 0.8), color, 0.22, index * 0.05)
	end
	fx:Ring(c, color, r * 0.3, r * 1.4, 0.6, 0.15)
end
-- Tiny Man: a giant's shadow falls on the road, then the stomp.
SIGNATURES.antman = function(fx, c, r, color)
	fx:Ring(c, Color3.fromRGB(40, 30, 40), r * 1.4, r * 0.4, 0.45)
	fx:_later(0.4, function()
		fx:Cracks(c, r, color, 7)
		fx:Boom(c, color, 3)
	end)
end
-- Queen Bee: a swarm of stings darting about.
SIGNATURES.wasp = function(fx, c, r, color, event)
	fx:Orbit(ground(c, 0), color, { count = 10, r0 = r * 0.2, r1 = r * 0.9, h0 = 1, h1 = 3.5, speed = 11, alternate = true, size = Vector3.one * 0.35, trail = 0.25, trailLife = 0.18, life = 1 })
	for index, point in ipairs(event.points or {}) do
		if index > 6 then break end
		if typeof(point) == "Vector3" then fx:Bolt(ground(c, 3), point + UP, color, 0.14, 0.1 + index * 0.05, 3) end
	end
end
-- Sharpshooter Raccoon: salvage flying out of the scrap, coins and gears.
SIGNATURES.rocket = function(fx, c, r, color)
	for index = 1, 8 do
		local angle = index * math.pi / 4
		local gold = index % 2 == 0
		fx:Projectile(ground(c, 1), ground(around(c, r * 0.8, angle), 0.4), gold and Color3.fromRGB(255, 205, 70) or color,
			{ shape = Enum.PartType.Cylinder, size = gold and Vector3.new(0.2, 1, 1) or Vector3.new(0.45, 1.3, 1.3), arc = 7, life = 0.65, ease = "linear",
				look = false, spin = Vector3.new(0, 9, 0), material = gold and Enum.Material.Metal or Enum.Material.Neon, delay = index * 0.03 })
	end
	fx:Emit("star", ground(c, 2), Color3.fromRGB(255, 205, 70), 12)
end
-- Blind Vigilante: sonar ripples sweeping out, again and again.
SIGNATURES.daredevil = function(fx, c, r, color)
	for pulse = 0, 3 do fx:Ring(c, color, r * 0.1, r * 1.5, 0.6, pulse * 0.22) end
	fx:Flash(ground(c, 1), color, 1, 3, 0.3)
end
-- Master of the Rings: ten golden rings circle the road and close in.
SIGNATURES.shangchi = function(fx, c, r, color)
	fx:Orbit(ground(c, 0), color, { count = 10, r0 = r * 1.1, r1 = r * 0.15, h0 = 2.5, h1 = 1.2, speed = 5, size = Vector3.new(0.1, 1.6, 1.6),
		shape = Enum.PartType.Cylinder, ring = true, life = 1.1, spin = Vector3.new(0, 0, 3), alternate = true })
	fx:Emit("vortex", ground(c, 1), color, 2, 0.4)
	fx:Emit("spark", ground(c, 1.5), color, 12, 0.9)
end
-- Shield Captain: the shield ricochets around the area, then a dome of force.
SIGNATURES.captain = function(fx, c, r, color)
	local points = { ground(around(c, r, 0.3), 2), ground(around(c, r, 2.4), 2), ground(around(c, r, 4.4), 2) }
	local previous = ground(c, 6) + Vector3.new(0, 4, 0)
	for index, point in ipairs(points) do
		fx:Projectile(previous, point, Color3.fromRGB(110, 170, 255), { shape = Enum.PartType.Cylinder, size = Vector3.new(0.25, 2.2, 2.2), look = false,
			spin = Vector3.new(0, 14, 0), trail = 0.9, life = 0.16, delay = (index - 1) * 0.16, ease = "linear" })
		fx:Emit("spark", point, WHITE, 8, index * 0.16)
		previous = point
	end
	fx:Dome(c, r, color, 1.5, 0.45)
end
-- Panther King: the stored energy released in a purple burst that heals.
SIGNATURES.panther = function(fx, c, r, color)
	fx:Flash(ground(c, 2), color, 2, r * 1.2, 0.35, 0, 0.3)
	fx:Rays(c, color, 10, r, 0.05)
	fx:Column(c, color, 14, r * 0.5, 0.8, 0.1)
	fx:Emit("star", ground(c, 1), color:Lerp(WHITE, 0.3), 22, 0.15)
end
-- Raging Giant: the smash cracks the ground and throws the rubble.
SIGNATURES.hulk = function(fx, c, r, color)
	fx:Cracks(c, r * 1.1, color, 9)
	fx:Boom(c, color, 4)
	fx:Ring(c, color, r * 0.3, r * 1.6, 0.6, 0.08)
end
-- Prism Android: three beams from a floating gem, then a phase bubble.
SIGNATURES.vision = function(fx, c, r, color)
	fx:Flash(ground(c, 4), color, 1.5, 2.5, 0.9, 0, 0.1)
	fx:Orbit(ground(c, 0), color, { count = 3, r0 = 0.5, r1 = r, h0 = 4, h1 = 0.6, speed = 4, size = Vector3.new(0.5, 0.5, 0.5), trail = 1.2, trailLife = 0.4, life = 0.8 })
	fx:Dome(c, r * 0.9, color, 1.2, 0.35)
end
-- Armoured Soldier: a heavy bombardment.
SIGNATURES.warmachine = function(fx, c, r, color)
	fx:Rain(c, r, Color3.fromRGB(205, 210, 220), { count = 10, size = Vector3.new(0.6, 0.6, 2.2), trail = 0.6, trailColor = Color3.fromRGB(150, 150, 160),
		boom = 2.8, boomColor = Color3.fromRGB(255, 150, 60), spacing = 0.06, material = Enum.Material.Metal })
end
-- Star Pirate: the mixtape plays, rings pulse to the beat in every colour.
SIGNATURES.starlord = function(fx, c, r, color)
	for beat = 1, 6 do
		local tint = RAINBOW[beat]
		fx:Ring(c, tint, r * 0.15, r * 1.3, 0.5, (beat - 1) * 0.14)
		fx:Emit("star", ground(around(c, r * 0.6, beat), 1.5), tint, 6, (beat - 1) * 0.14)
	end
end
-- Green Giant: roots burst out of the road in a wall, leaves flying.
SIGNATURES.groot = function(fx, c, r, color)
	fx:Spikes(c, r, Color3.fromRGB(122, 88, 56), 10, 6, Enum.Material.Wood)
	fx:Emit("leaf", ground(c, 3), color, 16, 0.15)
	fx:Ring(c, color, r * 0.2, r * 1.2, 0.6)
end
-- Thunder God: the storm answers, a great bolt and a crown of strikes.
SIGNATURES.thor = function(fx, c, r, color, event)
	fx:Emit("smoke", ground(c, 24), Color3.fromRGB(70, 80, 100), 8)
	fx:SkyStrike(c, color, 4, 0.15)
	for index = 1, 4 do
		local at = ground(around(c, r * 0.8, index * math.pi / 2 + 0.6), 0.4)
		fx:Bolt(at + Vector3.new(1, 30, 0), at, color, 0.3, 0.3 + index * 0.07, 5)
	end
	for index, point in ipairs(event.points or {}) do
		if index > 6 then break end
		if typeof(point) == "Vector3" then fx:Bolt(ground(c, 3), point + UP, color, 0.22, 0.5 + index * 0.04, 4) end
	end
	fx:Ring(c, color, r * 0.3, r * 1.7, 0.7, 0.2)
end
-- Chaos Witch: crimson runes circle the area and close on it.
SIGNATURES.wanda = function(fx, c, r, color)
	fx:Circle(c, r, color, 0, 1.4)
	fx:Orbit(ground(c, 0), color, { count = 6, r0 = r, r1 = r * 0.1, h0 = 3, h1 = 1, speed = 4, size = Vector3.new(1, 1, 0.15), shape = Enum.PartType.Block,
		spin = Vector3.new(2, 3, 0), life = 1, delay = 0.2 })
	fx:Emit("vortex", ground(c, 1), color, 3, 0.6)
	fx:Flash(ground(c, 1.5), color, 2, r, 0.4, 1.1, 0.3)
end
-- Mystic Doctor: a golden magic circle that slows time.
SIGNATURES.strange = function(fx, c, r, color)
	fx:Circle(c, r, color, 0, 1.8)
	fx:Circle(c, r * 0.55, color:Lerp(WHITE, 0.3), 0.2, 1.4)
	fx:Emit("star", ground(c, 2), color, 16, 0.3)
end
-- Flame Rider: hellfire rises in a ring around the road.
SIGNATURES.ghostrider = function(fx, c, r, color)
	fx:FlameRing(c, r, color, 12, 0, 5)
	fx:FlameRing(c, r * 0.45, Color3.fromRGB(255, 200, 80), 6, 0.2, 4)
	fx:Ring(c, color, r * 0.2, r * 1.2, 0.6)
	fx:Column(c, color, 10, r * 0.4, 0.7, 0.1)
end
-- Star Captain: a photon nova, a starburst and three shockwaves.
SIGNATURES.captainmarvel = function(fx, c, r, color)
	fx:Flash(ground(c, 2), color:Lerp(WHITE, 0.2), 3, r * 1.4, 0.45, 0, 0.25)
	fx:Rays(c, color, 12, r * 1.3, 0.05, 2, 0.6)
	for wave = 0, 2 do fx:Ring(c, color, r * 0.2, r * (1.1 + wave * 0.3), 0.55, wave * 0.12) end
	fx:Emit("core", ground(c, 2), color, 4)
	fx:Column(c, color, 22, r * 0.4, 0.6)
end
-- Cosmic Surfer: a silver beam from the stars.
SIGNATURES.silversurfer = function(fx, c, r, color)
	fx:SkyStrike(c, color, 3.5)
	fx:Rays(c, color, 8, r, 0.12, 1, 0.3)
	fx:Emit("star", ground(c, 6), WHITE, 20, 0.1)
end
-- Steel Claw: two crossing sets of claw marks.
SIGNATURES.wolverine = function(fx, c, r, color)
	for index = -1, 1 do
		fx:Slash(c + Vector3.new(index * 1.1, 0, 0), color, r * 1.1, 0.6, index * 0.03)
		fx:Slash(c + Vector3.new(0, 0, index * 1.1), color, r * 1.1, -0.6 + math.pi / 2, 0.22 + index * 0.03)
	end
	fx:Emit("spark", ground(c, 2), color, 14, 0.25)
end
-- Ruby Eye: a beam sweeps the road from above.
SIGNATURES.cyclops = function(fx, c, r, color)
	fx:Sweep(c, r, color, 1.6)
	fx:Ring(c, color, r * 0.2, r * 1.2, 0.5, 0.5)
end
-- Weather Goddess: a cyclone of wind with lightning around it.
SIGNATURES.storm = function(fx, c, r, color)
	for level = 0, 3 do
		fx:Orbit(ground(c, 0), color:Lerp(WHITE, 0.3), { count = 4, r0 = r * (0.3 + level * 0.18), r1 = r * (0.5 + level * 0.25), h0 = 1 + level * 2.5, h1 = 1.5 + level * 3,
			speed = 8 - level, size = Vector3.one * 0.5, trail = 0.6, trailLife = 0.3, life = 1.3, delay = level * 0.05 })
	end
	for index = 1, 3 do
		local at = ground(around(c, r, index * 2.1), 0.4)
		fx:Bolt(at + Vector3.new(0, 26, 0), at, Color3.fromRGB(190, 240, 255), 0.26, 0.3 + index * 0.15, 5)
	end
end
-- Radiant Psychic: flames rise in the shape of wings.
SIGNATURES.jean = function(fx, c, r, color)
	local fire = Color3.fromRGB(255, 150, 70)
	fx:Column(c, color, 16, r * 0.45, 0.9)
	for side = -1, 1, 2 do
		for index = 1, 7 do
			local spread = index / 7
			local at = ground(c, 2 + spread * 6) + Vector3.new(side * spread * r * 1.1, 0, -spread * r * 0.25)
			fx:Emit("fire", at, index % 2 == 0 and fire or color, 3, index * 0.04)
		end
	end
	fx:FlameRing(c, r * 0.7, color, 8, 0.25, 3)
	fx:Flash(ground(c, 3), color, 2, r * 0.8, 0.4, 0.1, 0.3)
end
-- Living Ice: ice spikes burst from the road, snow falls.
SIGNATURES.iceman = function(fx, c, r, color)
	fx:Spikes(c, r, color:Lerp(WHITE, 0.3), 12, 5)
	fx:Emit("snow", ground(c, 7), WHITE, 20, 0.1)
	fx:Ring(c, color, r * 0.2, r * 1.2, 0.7)
end
-- Card Master: a rain of charged cards, each one going off.
SIGNATURES.gambit = function(fx, c, r, color)
	fx:Rain(c, r, color, { count = 9, size = Vector3.new(0.9, 0.08, 1.3), spin = Vector3.new(0, 12, 6), trail = 0.35, boom = 1.8, spacing = 0.06, slant = 4, life = 0.5 })
end
-- Blue Teleporter: puffs of smoke all around as he blinks in and out.
SIGNATURES.nightcrawler = function(fx, c, r, color)
	local smoke = Color3.fromRGB(70, 60, 110)
	for index = 1, 5 do
		local at = ground(around(c, r * 0.8, index * 1.26), 1.5)
		fx:Emit("smoke", at, smoke, 4, index * 0.09)
		fx:Flash(at, color, 0.8, 3, 0.25, index * 0.09, 0.3)
	end
	fx:Emit("vortex", ground(c, 1), color, 2, 0.5)
	fx:Ring(c, color, r * 1.3, r * 0.2, 0.6, 0.45)
end
-- Furry Acrobat: a leap and a landing that leaves enemies seeing stars.
SIGNATURES.beast = function(fx, c, r, color)
	fx:Boom(c, color, 3)
	fx:Ring(c, color, r * 0.2, r * 1.4, 0.5, 0.1)
	fx:Orbit(ground(c, 0), Color3.fromRGB(255, 225, 90), { count = 4, r0 = 1.6, r1 = 1.6, h0 = 4, h1 = 4, speed = 7, size = Vector3.one * 0.5, life = 1.2, delay = 0.15 })
	fx:Emit("smoke", ground(c, 0.5), Color3.fromRGB(150, 130, 105), 5)
end
-- Psychic Ninja: psychic blades flash across the area.
SIGNATURES.psylocke = function(fx, c, r, color)
	for index = 1, 6 do
		local at = ground(around(c, r * 0.5 * ((index % 3) / 2), index * 1.9), 0)
		fx:Slash(at, color, r * 0.9, index * 1.05, (index - 1) * 0.07, 0.35)
	end
end
-- Chatty Mercenary: swords crossing in an X, and confetti.
SIGNATURES.deadpool = function(fx, c, r, color)
	fx:Slash(c, color, r * 1.2, 0.8)
	fx:Slash(c, color, r * 1.2, 0.8 + math.pi / 2, 0.12)
	for index = 1, 10 do
		local tint = RAINBOW[(index % #RAINBOW) + 1]
		local to = ground(around(c, r * spread(index), index * 0.63), 0.3)
		fx:Projectile(ground(c, 1.5), to, tint, { size = Vector3.new(0.35, 0.35, 0.35), arc = 6, life = 0.7, ease = "linear", look = false, spin = Vector3.new(7, 9, 4), delay = 0.15 })
	end
end
-- Lunar Knight: a crescent moon rises and silver light falls on the road.
SIGNATURES.moonknight = function(fx, c, r, color)
	local sky = ground(c, 15)
	fx:Flash(sky, Color3.fromRGB(245, 240, 225), 4.5, 5, 1.2, 0, 0.05)
	fx:Flash(sky + Vector3.new(1.4, 0.4, -0.6), Color3.fromRGB(28, 30, 48), 4.2, 4.6, 1.2, 0, 0.02)
	fx:Column(c, Color3.fromRGB(230, 225, 210), 15, r * 0.6, 1, 0.2, 0.7)
	fx:Ring(c, color, r * 0.3, r * 1.4, 0.7, 0.3)
	fx:Emit("star", sky, WHITE, 10, 0.1)
end
-- Cosmic Guardian: a supernova in blue.
SIGNATURES.nova = function(fx, c, r, color)
	fx:Flash(ground(c, 2), color:Lerp(WHITE, 0.3), 3, r * 1.3, 0.45, 0, 0.25)
	fx:Rays(c, color, 14, r * 1.2, 0.05, 2.5, 0.5)
	fx:Ring(c, color, r * 0.2, r * 1.5, 0.55, 0.1)
	fx:Ring(c, WHITE, r * 0.2, r * 1.1, 0.45, 0.2)
	fx:Emit("core", ground(c, 2), color, 4)
	fx:Emit("star", ground(c, 3), color, 16, 0.2)
end
-- Captain Men: an unbreakable dome and a burst of gold.
SIGNATURES.capmen = function(fx, c, r, color)
	fx:Dome(c, r, color, 1.6)
	fx:Rays(c, Color3.fromRGB(255, 205, 80), 8, r * 0.9, 0.2, 2)
	fx:Emit("star", ground(c, 2), Color3.fromRGB(255, 205, 80), 16, 0.25)
end
-- Golden Amazon: the lasso spins wide and tightens.
SIGNATURES.amazon = function(fx, c, r, color)
	fx:Orbit(ground(c, 0), color, { count = 12, r0 = r * 1.2, r1 = r * 0.3, h0 = 1.6, h1 = 1.2, speed = 6, size = Vector3.one * 0.55, trail = 0.5, trailLife = 0.3, life = 1 })
	fx:Ring(c, color, r * 1.2, r * 0.3, 1)
	fx:Flash(ground(c, 1.5), color, 1, r * 0.8, 0.4, 0.9, 0.35)
end
-- King of the Seas: a tidal wave runs out over the road.
SIGNATURES.seaking = function(fx, c, r, color)
	fx:Wave(c, r * 1.2, color, 16)
	fx:Ring(c, color, r * 0.2, r * 1.4, 0.8, 0.1)
end
-- Green Guardian: a giant fist of green light slams down.
SIGNATURES.emerald = function(fx, c, r, color)
	fx:Projectile(ground(c, 26) + Vector3.new(4, 0, 2), ground(c, 2.5), color, { size = Vector3.new(r * 0.55, r * 0.5, r * 0.55), fade = 0.25,
		trail = 2, life = 0.38, look = false, land = function()
			fx:Boom(c, color, 4)
			fx:Cracks(c, r, color, 7)
			fx:Ring(c, color, r * 0.3, r * 1.6, 0.6)
		end })
end
-- Ruby Speedster: a red streak zig-zags through the area, lightning behind it.
SIGNATURES.speedster = function(fx, c, r, color)
	local previous = ground(around(c, r * 1.2, 3.6), 1.4)
	for index = 1, 6 do
		local point = ground(around(c, r * (index % 2 == 0 and 1 or 0.5), 3.6 + index * 1.1), 1.4)
		fx:Projectile(previous, point, color, { size = Vector3.new(0.5, 0.5, 1.6), trail = 1, trailLife = 0.4, life = 0.08, delay = (index - 1) * 0.08, ease = "linear" })
		fx:Bolt(previous + UP, point + UP, Color3.fromRGB(255, 225, 90), 0.12, (index - 1) * 0.08 + 0.04, 3)
		previous = point
	end
	fx:Ring(c, color, r * 0.2, r * 1.3, 0.5, 0.5)
end
-- Solar Guardian: a small sun comes down and flares out.
SIGNATURES.solartitan = function(fx, c, r, color)
	local fire = Color3.fromRGB(255, 160, 60)
	fx:Projectile(ground(c, 30), ground(c, 3), fire, { shape = Enum.PartType.Ball, size = Vector3.one * r * 0.45, fade = 0.15, trail = 2, life = 0.55, look = false,
		land = function()
			fx:Flash(ground(c, 3), fire, r * 0.5, r * 1.8, 0.5, 0, 0.2)
			fx:Rays(c, color, 12, r * 1.2, 0, 2, 0.55)
			fx:FlameRing(c, r * 0.8, color, 10, 0.05, 4)
			fx:Ring(c, color, r * 0.3, r * 1.6, 0.6)
		end })
end
-- Night Hunter: a smoke bomb, sparks in the dark.
SIGNATURES.nightstalker = function(fx, c, r, color)
	fx:Emit("smoke", ground(c, 1), Color3.fromRGB(80, 86, 104), 14)
	fx:Emit("spark", ground(c, 1), Color3.fromRGB(255, 220, 140), 12, 0.05)
	fx:Flash(ground(c, 1), Color3.fromRGB(255, 230, 170), 1, 4, 0.2)
	fx:Ring(c, color, r * 0.2, r * 1.3, 0.6)
end

-- What a power of an unlisted hero looks like: by kind of power.
local BY_KIND = {
	blast = "hulk", smite = "silversurfer", execute = "hawkeye", heal = "panther", barrier = "capmen", shield = "capmen", rally = "starlord",
	slow = "iceman", stun = "bucky", chain = "thor", reveal = "daredevil", pull = "shangchi", push = "seaking", burn = "ghostrider",
	weaken = "psylocke", frenzy = "speedster", overdrive = "antman", energy = "rocket",
}

-- Plays the cast. False when there is nothing to draw it with.
function PowerFX:Cast(event, tint)
	if typeof(event.position) ~= "Vector3" then return false end
	local signature = SIGNATURES[event.heroId or ""] or SIGNATURES[BY_KIND[event.abilityKind or ""] or ""]
	if not signature then return false end
	local radius = math.clamp(tonumber(event.radius) or 8, 5, 40)
	local ok, problem = pcall(signature, self, ground(event.position, 0.3), radius, tint, event)
	if not ok then self.lastError = problem end
	return ok
end

return PowerFX
