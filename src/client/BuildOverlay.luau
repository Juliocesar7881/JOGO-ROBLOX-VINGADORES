--!nonstrict
-- Build overlay: while a hero is being placed, the ground that refuses a tower
-- is tinted — each road's clearance band, the circle every tower and base
-- keeps free, and the edge of the buildable area. It draws the numbers of
-- Rules.BuildCheck (Config.PathHalfWidth + Config.TowerRadius, Rules.BUILD_LIMIT)
-- and never its own, so the picture cannot promise a spot the server refuses.
-- Purely visual; the server re-checks every placement.
local BuildOverlay = {}
BuildOverlay.__index = BuildOverlay

local HEIGHT = 0.5

function BuildOverlay.new(folder, catalog, rules, config, colors)
	return setmetatable({ folder = folder, catalog = catalog, rules = rules, config = config, colors = colors, parts = {}, signature = nil }, BuildOverlay)
end

function BuildOverlay:Clear()
	for _, item in ipairs(self.parts) do item:Destroy() end
	self.parts, self.signature = {}, nil
end

function BuildOverlay:_part(name, size, frame, shape)
	local part = Instance.new("Part")
	part.Name, part.Size, part.CFrame = name, size, frame
	part.Color, part.Material, part.Transparency = self.colors.red, Enum.Material.Neon, 0.8
	part.Anchored, part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = true, false, false, false, false
	if shape then part.Shape = shape end
	part.Parent = self.folder
	table.insert(self.parts, part)
	return part
end

-- A flat disc: Roblox runs a cylinder's axis along X, so it is stood on edge.
function BuildOverlay:_disc(name, x, z, radius)
	return self:_part(name, Vector3.new(0.04, radius * 2, radius * 2), CFrame.new(x, HEIGHT, z) * CFrame.Angles(0, 0, math.pi / 2), Enum.PartType.Cylinder)
end

local function signatureOf(match)
	local pieces = { tostring(match.mapId) }
	for _, tower in ipairs(match.towers or {}) do
		local p = tower.position
		if typeof(p) == "Vector3" then table.insert(pieces, string.format("%.1f,%.1f", p.X, p.Z)) end
	end
	for _, blocker in ipairs(match.blockers or {}) do
		table.insert(pieces, string.format("b%.1f,%.1f,%.1f", blocker.x or 0, blocker.z or 0, blocker.r or 0))
	end
	return table.concat(pieces, ";")
end

-- Shows the overlay for this match, or clears it when there is none. Cheap to
-- call every frame: it only rebuilds when towers, blockers or the map change.
function BuildOverlay:Update(match)
	if not match then self:Clear(); return end
	local signature = signatureOf(match)
	if signature == self.signature then return end
	self:Clear()
	self.signature = signature
	local map = self.catalog.Maps[match.mapId]
	if not map then return end
	local radius = tonumber(self.config.TowerRadius) or 3
	local clearance = (tonumber(self.config.PathHalfWidth) or 6) + radius
	local corners = {}
	for _, route in ipairs(map.paths) do
		for i = 1, #route - 1 do
			local a, b = Vector3.new(route[i][1], HEIGHT, route[i][2]), Vector3.new(route[i + 1][1], HEIGHT, route[i + 1][2])
			local length = (b - a).Magnitude
			if length > 0.01 then
				self:_part("NoBuildRoad", Vector3.new(clearance * 2, 0.04, length), CFrame.lookAt((a + b) / 2, b))
			end
			for _, point in ipairs({ route[i], route[i + 1] }) do
				local key = tostring(point[1]) .. "," .. tostring(point[2])
				if not corners[key] then
					corners[key] = true
					self:_disc("NoBuildCorner", point[1], point[2], clearance)
				end
			end
		end
	end
	for _, tower in ipairs(match.towers or {}) do
		local p = tower.position
		if typeof(p) == "Vector3" then self:_disc("NoBuildTower", p.X, p.Z, radius * 2) end
	end
	for _, blocker in ipairs(match.blockers or {}) do
		self:_disc("NoBuildBlocker", blocker.x or 0, blocker.z or 0, (blocker.r or 0) + radius)
	end
	local limit = self.rules.BUILD_LIMIT or 106
	for _, edge in ipairs({ { limit, 0, 0.4, limit * 2 }, { -limit, 0, 0.4, limit * 2 }, { 0, limit, limit * 2, 0.4 }, { 0, -limit, limit * 2, 0.4 } }) do
		local line = self:_part("BuildEdge", Vector3.new(edge[3], 0.06, edge[4]), CFrame.new(edge[1], HEIGHT, edge[2]))
		line.Transparency = 0.35
	end
end

function BuildOverlay:Count()
	return #self.parts
end

return BuildOverlay
