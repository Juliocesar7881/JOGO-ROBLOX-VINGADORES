--!nonstrict
-- Route preview: during preparation, glowing arrows walk the roads the next
-- wave will use, so a changed entrance (HYDRA alternates, Latveria opens a
-- third road) is seen before the enemies arrive. Purely visual: the server
-- names the roads (snapshot.nextPaths) and whether they changed (newEntrance).
local RoutePreview = {}
RoutePreview.__index = RoutePreview

local SPACING = 9
local MAX_ARROWS = 140

function RoutePreview.new(folder, catalog, colors)
	return setmetatable({ folder = folder, catalog = catalog, colors = colors, arrows = {}, signature = nil, offset = 0 }, RoutePreview)
end

function RoutePreview:Clear()
	for _, arrow in ipairs(self.arrows) do arrow.part:Destroy() end
	self.arrows, self.signature = {}, nil
end

function RoutePreview:_arrow(tint)
	local part = Instance.new("Part")
	part.Name, part.Size, part.Color = "RouteArrow", Vector3.new(2.6, 0.18, 1.3), tint
	part.Material, part.Transparency, part.Anchored = Enum.Material.Neon, 0.15, true
	part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false
	part.Parent = self.folder
	return part
end

-- Rebuilds the arrows when the roads change. Returns true the moment a new
-- entrance is announced, so the controller can tell the player.
function RoutePreview:Update(phase, match, lowFX)
	local show = phase == "Preparing" and match and match.nextPaths and #match.nextPaths > 0
	local signature = show and (tostring(match.mapId) .. ":" .. table.concat(match.nextPaths, ",")) or nil
	if signature == self.signature then return false end
	self:Clear()
	self.signature = signature
	if not show then return false end
	local map = self.catalog.Maps[match.mapId]
	local tint = match.newEntrance and self.colors.red or self.colors.gold
	for _, index in ipairs(match.nextPaths) do
		local route = map and map.paths[index]
		if route then
			local segments, total = {}, 0
			for i = 1, #route - 1 do
				local a, b = Vector3.new(route[i][1], 0.45, route[i][2]), Vector3.new(route[i + 1][1], 0.45, route[i + 1][2])
				local length = (b - a).Magnitude
				table.insert(segments, { a = a, b = b, length = length, start = total })
				total += length
			end
			for distance = 0, total, (lowFX and SPACING * 2 or SPACING) do
				if #self.arrows >= MAX_ARROWS then break end
				table.insert(self.arrows, { part = self:_arrow(tint), segments = segments, total = total, base = distance })
			end
		end
	end
	self:Step(0, phase)
	return match.newEntrance == true
end

-- In the lobby the same glow shows the way to a place ("buy it at the
-- shop"): a band of light from the player to it and a marker above it, until
-- the player arrives, leaves the lobby or a minute passes. Client-only.
function RoutePreview:ClearWay()
	local way = self.way
	self.way = nil
	if way then
		way.anchor:Destroy()
		if way.attachment then way.attachment:Destroy() end
	end
end

function RoutePreview:ShowWay(target, text)
	self:ClearWay()
	local players = game:GetService("Players")
	local character = players.LocalPlayer and players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not target or not root then return false end
	local tint = self.colors.gold
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.CFrame = "WayMarker", Vector3.new(1, 1, 1), CFrame.new(target + Vector3.new(0, 3, 0))
	anchor.Anchored, anchor.Transparency, anchor.CanCollide, anchor.CanTouch, anchor.CanQuery = true, 1, false, false, false
	anchor.Parent = self.folder
	local from, to = Instance.new("Attachment"), Instance.new("Attachment")
	from.Name, to.Name = "WayFrom", "WayTo"
	from.Parent, to.Parent = root, anchor
	local beam = Instance.new("Beam")
	beam.Attachment0, beam.Attachment1, beam.Color = from, to, ColorSequence.new(tint)
	beam.Width0, beam.Width1, beam.FaceCamera, beam.LightEmission, beam.Segments = 0.5, 1.6, true, 1, 24
	beam.Transparency, beam.CurveSize0, beam.CurveSize1 = NumberSequence.new(0.2), 6, -6
	beam.Parent = anchor
	local marker = Instance.new("BillboardGui")
	marker.Name, marker.Size, marker.StudsOffset, marker.AlwaysOnTop = "WayLabel", UDim2.fromOffset(190, 54), Vector3.new(0, 5, 0), true
	marker.Adornee, marker.Parent = anchor, anchor
	local label = Instance.new("TextLabel")
	label.Size, label.BackgroundTransparency, label.Text, label.TextScaled = UDim2.fromScale(1, 1), 1, text, true
	label.Font, label.TextColor3, label.TextStrokeTransparency = Enum.Font.FredokaOne, tint, 0.2
	label.Parent = marker
	self.way = { anchor = anchor, attachment = from, target = target, age = 0 }
	return true
end

-- Slides every arrow forward along its road; clears itself once the wave starts.
function RoutePreview:Step(dt, phase)
	local way = self.way
	if way then
		way.age += dt
		local players = game:GetService("Players")
		local character = players.LocalPlayer and players.LocalPlayer.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local offset = root and (root.Position - way.target)
		if phase ~= "Lobby" or way.age > 60 or not offset or Vector3.new(offset.X, 0, offset.Z).Magnitude < 12 then self:ClearWay() end
	end
	if #self.arrows == 0 then return end
	if phase ~= "Preparing" then self:Clear(); return end
	self.offset = (self.offset + dt * 7) % SPACING
	for _, arrow in ipairs(self.arrows) do
		local along = (arrow.base + self.offset) % math.max(1, arrow.total)
		for _, segment in ipairs(arrow.segments) do
			if along <= segment.start + segment.length then
				local t = if segment.length > 0 then (along - segment.start) / segment.length else 0
				local at = segment.a:Lerp(segment.b, math.clamp(t, 0, 1))
				arrow.part.CFrame = CFrame.lookAt(at, at + (segment.b - segment.a))
				break
			end
		end
	end
end

function RoutePreview:Count()
	return #self.arrows
end

return RoutePreview
