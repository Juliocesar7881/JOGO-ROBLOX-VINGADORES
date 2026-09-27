-- Enough of the Roblox API to run real game modules outside Roblox.
--
-- These are stand-ins, not a reimplementation: vectors and CFrames do the
-- actual maths, and Instances record properties, parents and children so a
-- builder can be run and then inspected. Anything that needs a renderer, a
-- network or a DataStore is out of scope by design.
local Stubs = {}

--==============================================================================
-- Vector3
--==============================================================================
local V3 = {}
local V3_METHODS = {}

local function v3(x, y, z)
	return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V3)
end

V3.__index = function(self, key)
	if key == "X" then return rawget(self, "x") end
	if key == "Y" then return rawget(self, "y") end
	if key == "Z" then return rawget(self, "z") end
	if key == "Magnitude" then
		local a, b, c = rawget(self, "x"), rawget(self, "y"), rawget(self, "z")
		return math.sqrt(a * a + b * b + c * c)
	end
	if key == "Unit" then
		local a, b, c = rawget(self, "x"), rawget(self, "y"), rawget(self, "z")
		local m = math.sqrt(a * a + b * b + c * c)
		if m == 0 then return v3(0, 0, 0) end
		return v3(a / m, b / m, c / m)
	end
	return V3_METHODS[key]
end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
V3.__mul = function(a, b)
	if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
V3.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
V3.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
function V3_METHODS:Dot(other) return self.X * other.X + self.Y * other.Y + self.Z * other.Z end
function V3_METHODS:Cross(other)
	return v3(self.Y * other.Z - self.Z * other.Y,
		self.Z * other.X - self.X * other.Z,
		self.X * other.Y - self.Y * other.X)
end
function V3_METHODS:Lerp(other, t)
	return v3(self.X + (other.X - self.X) * t, self.Y + (other.Y - self.Y) * t, self.Z + (other.Z - self.Z) * t)
end

Vector3 = { new = v3, zero = v3(0, 0, 0), one = v3(1, 1, 1) }
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, {
			__index = function(self, key)
				if key == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y) end
				return nil
			end,
		})
	end,
}

--==============================================================================
-- CFrame: translation plus a 3x3 rotation, composed properly
--==============================================================================
local CF = {}

local function cframe(position, rotation)
	return setmetatable({
		p = position or v3(0, 0, 0),
		r = rotation or { 1, 0, 0, 0, 1, 0, 0, 0, 1 },
	}, CF)
end

local function rotate(r, vector)
	return v3(
		r[1] * vector.X + r[2] * vector.Y + r[3] * vector.Z,
		r[4] * vector.X + r[5] * vector.Y + r[6] * vector.Z,
		r[7] * vector.X + r[8] * vector.Y + r[9] * vector.Z)
end

CF.__index = function(self, key)
	if key == "Position" or key == "p" then return rawget(self, "p") end
	if key == "X" then return rawget(self, "p").X end
	if key == "Y" then return rawget(self, "p").Y end
	if key == "Z" then return rawget(self, "p").Z end
	if key == "Inverse" then
		return function(cf)
			local r, p = rawget(cf, "r"), rawget(cf, "p")
			local t = { r[1], r[4], r[7], r[2], r[5], r[8], r[3], r[6], r[9] }
			local back = rotate(t, p)
			return cframe(v3(-back.X, -back.Y, -back.Z), t)
		end
	end
	if key == "LookVector" then
		local r = rawget(self, "r")
		return v3(-r[3], -r[6], -r[9])
	end
	if key == "RightVector" then
		local r = rawget(self, "r")
		return v3(r[1], r[4], r[7])
	end
	if key == "UpVector" then
		local r = rawget(self, "r")
		return v3(r[2], r[5], r[8])
	end
	return nil
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		local ra, rb, out = rawget(a, "r"), rawget(b, "r"), {}
		for row = 0, 2 do
			for column = 1, 3 do
				out[row * 3 + column] = ra[row * 3 + 1] * rb[column]
					+ ra[row * 3 + 2] * rb[3 + column]
					+ ra[row * 3 + 3] * rb[6 + column]
			end
		end
		return cframe(rawget(a, "p") + rotate(ra, rawget(b, "p")), out)
	end
	return rawget(a, "p") + rotate(rawget(a, "r"), b)
end
CF.__add = function(a, b) return cframe(rawget(a, "p") + b, rawget(a, "r")) end
CF.__sub = function(a, b) return cframe(rawget(a, "p") - b, rawget(a, "r")) end

CFrame = {
	new = function(x, y, z)
		if type(x) == "table" then return cframe(x) end
		return cframe(v3(x or 0, y or 0, z or 0))
	end,
	Angles = function(rx, ry, rz)
		local cx, sx = math.cos(rx or 0), math.sin(rx or 0)
		local cy, sy = math.cos(ry or 0), math.sin(ry or 0)
		local cz, sz = math.cos(rz or 0), math.sin(rz or 0)
		return cframe(v3(0, 0, 0), {
			cy * cz, -cy * sz, sy,
			sx * sy * cz + cx * sz, -sx * sy * sz + cx * cz, -sx * cy,
			-cx * sy * cz + sx * sz, cx * sy * sz + sx * cz, cx * cy,
		})
	end,
	fromMatrix = function(position, x, y, z)
		z = z or x:Cross(y)
		return cframe(position, { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z })
	end,
	lookAt = function(from, target, up)
		up = up or v3(0, 1, 0)
		local forward = (target - from)
		if forward.Magnitude == 0 then return cframe(from) end
		forward = forward.Unit
		local right = forward:Cross(up)
		if right.Magnitude == 0 then right = v3(1, 0, 0) else right = right.Unit end
		local trueUp = right:Cross(forward)
		return cframe(from, {
			right.X, trueUp.X, -forward.X,
			right.Y, trueUp.Y, -forward.Y,
			right.Z, trueUp.Z, -forward.Z,
		})
	end,
}

--==============================================================================
-- Small value types
--==============================================================================
local C3 = {}
C3.__index = C3
local function color3(r, g, b) return setmetatable({ R = r, G = g, B = b }, C3) end
function C3:Lerp(other, t)
	return color3(self.R + (other.R - self.R) * t, self.G + (other.G - self.G) * t, self.B + (other.B - self.B) * t)
end
Color3 = {
	new = function(r, g, b) return color3(r or 0, g or 0, b or 0) end,
	fromRGB = function(r, g, b) return color3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255) end,
}

UDim = { new = function(scale, offset) return { Scale = scale or 0, Offset = offset or 0 } end }
UDim2 = {
	new = function(sx, ox, sy, oy) return { X = UDim.new(sx, ox), Y = UDim.new(sy, oy) } end,
	fromScale = function(x, y) return UDim2.new(x, 0, y, 0) end,
	fromOffset = function(x, y) return UDim2.new(0, x, 0, y) end,
}
NumberSequenceKeypoint = { new = function(t, value) return { Time = t, Value = value } end }
NumberSequence = { new = function(a, b) return { keypoints = { a, b } } end }
ColorSequence = { new = function(a, b) return { keypoints = { a, b } } end }
NumberRange = { new = function(minimum, maximum) return { Min = minimum, Max = maximum or minimum } end }
TweenInfo = { new = function(...) return { ... } end }
RaycastParams = { new = function() return { FilterDescendantsInstances = {} } end }

--==============================================================================
-- Enums: every access yields a stable token, so comparisons work
--==============================================================================
local enumCache = {}
Enum = setmetatable({}, {
	__index = function(_, category)
		if not enumCache[category] then
			enumCache[category] = setmetatable({}, {
				__index = function(self, name)
					local value = { EnumType = category, Name = name, Value = 0 }
					rawset(self, name, value)
					return value
				end,
			})
		end
		return enumCache[category]
	end,
})

--==============================================================================
-- Instances
--==============================================================================
local INHERITS = {
	Part = { "BasePart", "PVInstance" },
	SpawnLocation = { "BasePart", "PVInstance" },
	MeshPart = { "BasePart", "PVInstance" },
	WedgePart = { "BasePart", "PVInstance" },
	CornerWedgePart = { "BasePart", "PVInstance" },
	PointLight = { "Light" },
	SpotLight = { "Light" },
	SurfaceLight = { "Light" },
	Model = { "PVInstance" },
	TextLabel = { "GuiObject", "GuiBase2d" },
	TextButton = { "GuiObject", "GuiBase2d" },
	Frame = { "GuiObject", "GuiBase2d" },
	UICorner = { "UIComponent" },
	UIStroke = { "UIComponent" },
	UIListLayout = { "UIComponent", "UILayout" },
	UIGridLayout = { "UIComponent", "UILayout" },
	UIPadding = { "UIComponent" },
	UISizeConstraint = { "UIComponent", "UIConstraint" },
}

local INSTANCE = {}
local instanceCount = 0

-- Joints move what they hold, as in the engine: setting a Motor6D's Transform
-- places Part1 at Part0 * C0 * Transform * C1:Inverse(), and every joint and
-- weld hanging from that part follows. Enough for a test to see an arm rise.
local jointsByPart0 = setmetatable({}, { __mode = "k" })
local JOINT_CLASSES = { Motor6D = true, Weld = true }
local function registerJoint(joint, part0)
	local list = jointsByPart0[part0]
	if not list then list = {}; jointsByPart0[part0] = list end
	table.insert(list, joint)
end
local function solveJoint(joint)
	local props = rawget(joint, "__props")
	local part0, part1 = props.Part0, props.Part1
	if not part0 or not part1 then return end
	local from = rawget(part0, "__props").CFrame
	if not from then return end
	local c0, c1 = props.C0 or CFrame.new(), props.C1 or CFrame.new()
	rawget(part1, "__props").CFrame = from * c0 * (props.Transform or CFrame.new()) * c1:Inverse()
	for _, child in ipairs(jointsByPart0[part1] or {}) do solveJoint(child) end
end

local function newInstance(className)
	instanceCount += 1
	local self = setmetatable({}, INSTANCE)
	rawset(self, "__class", className)
	rawset(self, "__props", { Name = className, ClassName = className, Parent = nil })
	rawset(self, "__signals", {})
	rawset(self, "__children", {})
	rawset(self, "__attributes", {})
	rawset(self, "__id", instanceCount)
	return self
end

local METHODS = {}

function METHODS:IsA(className)
	local own = rawget(self, "__class")
	if own == className or className == "Instance" then return true end
	for _, parent in ipairs(INHERITS[own] or {}) do
		if parent == className then return true end
	end
	return false
end

function METHODS:GetChildren()
	return table.clone(rawget(self, "__children"))
end

function METHODS:GetDescendants()
	local out = {}
	for _, child in ipairs(rawget(self, "__children")) do
		table.insert(out, child)
		for _, nested in ipairs(child:GetDescendants()) do table.insert(out, nested) end
	end
	return out
end

function METHODS:FindFirstChild(name, recursive)
	for _, child in ipairs(rawget(self, "__children")) do
		if child.Name == name then return child end
	end
	if recursive then
		for _, child in ipairs(rawget(self, "__children")) do
			local found = child:FindFirstChild(name, true)
			if found then return found end
		end
	end
	return nil
end

function METHODS:FindFirstChildWhichIsA(className, recursive)
	for _, child in ipairs(rawget(self, "__children")) do
		if child:IsA(className) then return child end
	end
	if recursive then
		for _, child in ipairs(rawget(self, "__children")) do
			local found = child:FindFirstChildWhichIsA(className, true)
			if found then return found end
		end
	end
	return nil
end

function METHODS:WaitForChild(name)
	return self:FindFirstChild(name)
end

function METHODS:FindFirstChildOfClass(className)
	for _, child in ipairs(rawget(self, "__children")) do
		if rawget(child, "__class") == className then return child end
	end
	return nil
end

function METHODS:SetAttribute(name, value)
	local attributes=rawget(self,"__attributes")
	if attributes[name]==value then return end
	attributes[name]=value
	self:GetAttributeChangedSignal(name):Fire()
end
function METHODS:GetAttribute(name) return rawget(self, "__attributes")[name] end

function METHODS:Destroy()
	local props = rawget(self, "__props")
	local parent = props.Parent
	if parent then
		local siblings = rawget(parent, "__children")
		for index, child in ipairs(siblings) do
			if child == self then
				table.remove(siblings, index)
				break
			end
		end
	end
	props.Parent = nil
	rawset(self, "__destroyed", true)
end

-- Terrain: every fill is recorded instead of voxelised, so tests can ask
-- which materials a map laid down and where, and Clear really clears.
local function terrainLog(self)
	local fills = rawget(self, "__fills")
	if not fills then
		fills = {}
		rawset(self, "__fills", fills)
	end
	return fills
end
function METHODS:FillBlock(cframe, size, material)
	table.insert(terrainLog(self), { kind = "Block", cframe = cframe, size = size, material = material })
end
function METHODS:FillBall(center, radius, material)
	table.insert(terrainLog(self), { kind = "Ball", center = center, radius = radius, material = material })
end
function METHODS:FillCylinder(cframe, height, radius, material)
	table.insert(terrainLog(self), { kind = "Cylinder", cframe = cframe, height = height, radius = radius, material = material })
end
function METHODS:FillWedge(cframe, size, material)
	table.insert(terrainLog(self), { kind = "Wedge", cframe = cframe, size = size, material = material })
end
function METHODS:Clear() rawset(self, "__fills", {}) end
function METHODS:SetMaterialColor(material, color)
	local colors = rawget(self, "__materialColors") or {}
	rawset(self, "__materialColors", colors)
	colors[material and material.Name or "?"] = color
end
function METHODS:GetMaterialColor(material)
	local colors = rawget(self, "__materialColors") or {}
	return colors[material and material.Name or "?"]
end

function METHODS:PivotTo(target)
	local props = rawget(self, "__props")
	-- A model moves with its parts, the way Roblox pivots a character: the
	-- root part lands on the target and every other part keeps its offset.
	local pivot = props.PrimaryPart or self:FindFirstChild("HumanoidRootPart")
	local from = pivot and rawget(pivot, "__props").CFrame
	if from then
		local offset = from:Inverse()
		for _, item in ipairs(self:GetDescendants()) do
			local itemProps = rawget(item, "__props")
			if itemProps and itemProps.CFrame then itemProps.CFrame = target * (offset * itemProps.CFrame) end
		end
	end
	props.CFrame = target
end
function METHODS:GetPivot()
	local props = rawget(self, "__props")
	if props.PrimaryPart and rawget(props.PrimaryPart, "__props").CFrame then return rawget(props.PrimaryPart, "__props").CFrame end
	return props.CFrame or CFrame.new()
end
-- A real deep copy: properties, attributes and children, with references
-- inside the copied tree (a Model's PrimaryPart) pointing at the copies.
function METHODS:Clone()
	local map = {}
	local function copy(source)
		local made = newInstance(rawget(source, "__class"))
		map[source] = made
		local props = rawget(made, "__props")
		for key, value in pairs(rawget(source, "__props")) do
			if key ~= "Parent" then props[key] = value end
		end
		for key, value in pairs(rawget(source, "__attributes")) do rawget(made, "__attributes")[key] = value end
		for _, child in ipairs(rawget(source, "__children")) do
			local childCopy = copy(child)
			rawget(childCopy, "__props").Parent = made
			table.insert(rawget(made, "__children"), childCopy)
		end
		return made
	end
	local root = copy(self)
	for original, made in pairs(map) do
		local props = rawget(made, "__props")
		for key, value in pairs(props) do
			if type(value) == "table" and map[value] and key ~= "Parent" then props[key] = map[value] end
		end
		if JOINT_CLASSES[rawget(made, "__class")] and props.Part0 then registerJoint(made, props.Part0) end
	end
	return root
end

local function newSignal()
	local signal = { handlers = {} }
	function signal:Connect(fn)
		table.insert(self.handlers, fn)
		local handlers = self.handlers
		return { Disconnect = function()
			local index = table.find(handlers, fn)
			if index then table.remove(handlers, index) end
		end }
	end
	function signal:Fire(...)
		for _, fn in ipairs(table.clone(self.handlers)) do fn(...) end
	end
	return signal
end

local function instanceSignal(self, key)
	local signals = rawget(self, "__signals")
	if not signals[key] then signals[key] = newSignal() end
	return signals[key]
end

function METHODS:GetPropertyChangedSignal(name) return instanceSignal(self, "Changed:" .. tostring(name)) end
function METHODS:GetAttributeChangedSignal(name) return instanceSignal(self, "AttributeChanged:" .. tostring(name)) end

-- Remote events record what the server sent, per player, so a test can read
-- back exactly the snapshots and effects a client would have received.
function METHODS:FireClient(player, ...)
	local log = rawget(self, "__fired") or {}
	rawset(self, "__fired", log)
	table.insert(log, { player = player, args = table.pack(...) })
end
function METHODS:FireAllClients(...)
	local log = rawget(self, "__fired") or {}
	rawset(self, "__fired", log)
	table.insert(log, { player = "all", args = table.pack(...) })
end

-- Axis-aligned box around every part in the model: enough for code that sizes
-- an overlay to what it covers, without pretending to model rotation.
function METHODS:GetBoundingBox()
	local low, high
	for _, child in ipairs(self:GetDescendants()) do
		if child:IsA("BasePart") and child.Size and child.CFrame then
			local c, half = child.CFrame.Position, child.Size * 0.5
			local a, b = c - half, c + half
			low = low and v3(math.min(low.X, a.X), math.min(low.Y, a.Y), math.min(low.Z, a.Z)) or a
			high = high and v3(math.max(high.X, b.X), math.max(high.Y, b.Y), math.max(high.Z, b.Z)) or b
		end
	end
	if not low then return CFrame.new(), v3(0, 0, 0) end
	return CFrame.new((low + high) * 0.5), high - low
end

local SIGNAL_NAMES = {
	Triggered = true, Touched = true, Changed = true, ChildAdded = true,
	OnClientEvent = true, OnServerEvent = true, MouseButton1Click = true, FocusLost = true,
	PlayerRemoving = true, CharacterRemoving = true, Died = true,
	CharacterAdded = true, PlayerAdded = true, Activated = true, Heartbeat = true,
	MouseButton1Down = true, MouseButton1Up = true, MouseLeave = true, MouseEnter = true,
}

INSTANCE.__index = function(self, key)
	if METHODS[key] then return METHODS[key] end
	if SIGNAL_NAMES[key] then return instanceSignal(self, key) end
	local props = rawget(self, "__props")
	-- A part's Position is derived from its CFrame, exactly as in the engine.
	if key == "Position" and props.Position == nil and props.CFrame ~= nil then return props.CFrame.Position end
	local value = props[key]
	if value ~= nil then return value end
	return self:FindFirstChild(key)
end

INSTANCE.__newindex = function(self, key, value)
	local props = rawget(self, "__props")
	if key == "Parent" then
		local previous = props.Parent
		if previous then
			local siblings = rawget(previous, "__children")
			for index, child in ipairs(siblings) do
				if child == self then
					table.remove(siblings, index)
					break
				end
			end
		end
		props.Parent = value
		if value then table.insert(rawget(value, "__children"), self) end
		return
	end
	props[key] = value
	if JOINT_CLASSES[rawget(self, "__class")] then
		if key == "Part0" and value then registerJoint(self, value) end
		if key == "Transform" then solveJoint(self) end
	end
end

Instance = { new = function(className, parent)
	local created = newInstance(className)
	if parent then created.Parent = parent end
	return created
end }

--==============================================================================
-- Services and globals
--==============================================================================
workspace = newInstance("Workspace")
do
	local terrain = newInstance("Terrain")
	terrain.Name = "Terrain"
	terrain.Parent = workspace
end
local guid = 0
local SERVICES = {
	Workspace = workspace,
	Lighting = newInstance("Lighting"),
	SoundService = newInstance("SoundService"),
	ReplicatedStorage = newInstance("ReplicatedStorage"),
	ServerScriptService = newInstance("ServerScriptService"),
	ServerStorage = newInstance("ServerStorage"),
	Players = newInstance("Players"),
	HttpService = {
		GenerateGUID = function() guid += 1 return "stub-" .. tostring(guid) end,
		JSONEncode = function(_, value)
			local function encode(item)
				local kind = type(item)
				if kind == "table" and getmetatable(item) == nil then
					local keys = {}
					for key in pairs(item) do table.insert(keys, key) end
					table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
					local parts = {}
					for _, key in ipairs(keys) do table.insert(parts, string.format("%q:%s", tostring(key), encode(item[key]))) end
					return "{" .. table.concat(parts, ",") .. "}"
				elseif kind == "string" then
					return string.format("%q", item)
				end
				return tostring(item)
			end
			return encode(value)
		end,
	},
	RunService = { IsStudio = function() return false end, IsServer = function() return true end },
	PhysicsService = {
		IsCollisionGroupRegistered = function() return true end,
		RegisterCollisionGroup = function() end,
		CollisionGroupSetCollidable = function() end,
	},
}
game = {
	GetService = function(_, name)
		return assert(SERVICES[name], "unstubbed service: " .. tostring(name))
	end,
	BindToClose = function() end,
	JobId = "",
}

Random = {
	new = function(seed)
		local state = (math.abs(math.floor(seed or 0)) % 2147483646) + 1
		local function nextValue()
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end
		return {
			NextInteger = function(_, low, high) return low + math.floor(nextValue() * (high - low + 1 - 1e-9)) end,
			NextNumber = function(_, low, high)
				if low == nil then return nextValue() end
				return low + nextValue() * (high - low)
			end,
		}
	end,
}

task = {
	spawn = function(fn, ...) fn(...) end,
	defer = function(fn, ...) fn(...) end,
	delay = function(_, fn, ...) fn(...) end,
	wait = function() return 0 end,
}

local realType = type
function typeof(value)
	if realType(value) == "table" then
		local mt = getmetatable(value)
		if mt == V3 then return "Vector3" end
		if mt == CF then return "CFrame" end
		if mt == C3 then return "Color3" end
		if mt == INSTANCE then return "Instance" end
	end
	return realType(value)
end

warn = function() end

Stubs.v3 = v3
Stubs.newSignal = newSignal
Stubs.services = SERVICES
Stubs.workspace = workspace
Stubs.instanceMeta = INSTANCE
Stubs.countInstances = function(root, className)
	local total = 0
	for _, child in ipairs(root:GetDescendants()) do
		if className == nil or rawget(child, "__class") == className then total += 1 end
	end
	return total
end

return Stubs
