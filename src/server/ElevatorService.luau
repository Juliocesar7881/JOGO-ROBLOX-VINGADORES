--!nonstrict
-- Mode portals as elevators, the way the big Roblox tower defenses do it:
-- stepping onto a portal's pad puts you in its car, a short countdown runs,
-- anyone who steps on meanwhile rides along, and at zero the match starts.
-- No menu is involved. Everything here is the server's call — who is on the
-- pad, which map, whether each rider may play it — and the client only draws
-- the countdown and offers Leave. The map is never chosen: it is drawn at random
-- the moment the car departs.
local Elevator = {}
Elevator.__index = Elevator

local COUNTDOWN = 8
local JOIN_GRACE = 5
local MAX_RIDERS = 4

local function inside(zone, position)
	local offset = position - zone.center
	return math.abs(offset.X) <= zone.size.X / 2 and math.abs(offset.Y) <= zone.size.Y / 2
		and math.abs(offset.Z) <= zone.size.Z / 2
end

function Elevator.new(options)
	return setmetatable({
		rules = options.rules,
		profileOf = options.profileOf,
		zones = options.zones or {},
		launch = options.launch,
		notify = options.notify or function() end,
		changed = options.changed or function() end,
		eject = options.eject or function() end,
		available = options.available or function() return true end,
		-- A number in [0,1) for the map draw; injected so tests can pin it.
		random = options.random or function() return math.random() end,
		cars = {}, riding = {}, refused = {},
	}, Elevator)
end

function Elevator:_announce(car)
	for _, rider in ipairs(car.riders) do self.changed(rider) end
end

-- The host is whoever stepped on first; the mode follows their profile (the
-- campaign portal runs training until they have trained).
function Elevator:Plan(portalId)
	local car = self.cars[portalId]
	local host = car and car.riders[1]
	local profile = host and self.profileOf(host)
	if not profile then return nil end
	return self.rules.PortalMode(profile, portalId)
end

function Elevator:_refuse(player, portalId, reason)
	self.refused[player] = portalId
	local zone = self.zones[portalId]
	if zone then self.eject(player, zone.exit) end
	self.notify(player, reason)
end

function Elevator:_board(player, portalId)
	local profile = self.profileOf(player)
	if not profile then return end
	local car = self.cars[portalId]
	if car and #car.riders >= MAX_RIDERS then
		self:_refuse(player, portalId, "Este portal já está cheio. / This portal is full.")
		return
	end
	local modeId = self.rules.PortalMode(profile, portalId)
	if car then
		-- A car already has a plan, set by its first rider. Joining is only
		-- allowed for someone who could actually play it, so nobody rides a
		-- countdown only to be thrown off at zero.
		local planned = self:Plan(portalId)
		if planned then
			-- Whether someone may play a mode never depends on which map is
			-- drawn, so any map stands in for the check.
			local allowed, reason = self.rules.CanStart(profile, self.rules.PickMap(planned, 0), planned)
			if not allowed then
				self:_refuse(player, portalId, reason or self.rules.ModeLockReason(planned, profile))
				return
			end
		end
	elseif not self.rules.ModeUnlocked(profile, modeId) then
		self:_refuse(player, portalId, self.rules.ModeLockReason(modeId, profile))
		return
	end
	if not car then
		car = { portalId = portalId, riders = {}, remaining = COUNTDOWN }
		self.cars[portalId] = car
	end
	table.insert(car.riders, player)
	self.riding[player] = portalId
	-- Someone who just stepped on always gets a few seconds to decide.
	car.remaining = math.max(car.remaining, JOIN_GRACE)
	self:_announce(car)
end

function Elevator:_drop(player)
	local portalId = self.riding[player]
	if not portalId then return end
	self.riding[player] = nil
	local car = self.cars[portalId]
	if not car then return end
	local index = table.find(car.riders, player)
	if index then table.remove(car.riders, index) end
	if #car.riders == 0 then self.cars[portalId] = nil else self:_announce(car) end
	if player.Parent ~= nil then self.changed(player) end
end

-- The Leave button: off the car and off the pad, and not boarded again
-- until the player has actually stepped away and come back.
function Elevator:Leave(player)
	local portalId = self.riding[player]
	if not portalId then return false end
	self:_drop(player)
	self.refused[player] = portalId
	local zone = self.zones[portalId]
	if zone then self.eject(player, zone.exit) end
	return true
end

function Elevator:_depart(portalId)
	local car = self.cars[portalId]
	local modeId = self:Plan(portalId)
	if not modeId then
		car.remaining = 2
		return
	end
	-- Drawn once, for everyone aboard, at the moment of departure.
	local mapId = self.rules.PickMap(modeId, self.random())
	local going = {}
	for _, player in ipairs(table.clone(car.riders)) do
		local profile = self.profileOf(player)
		local allowed, reason = self.rules.CanStart(profile, mapId, modeId)
		if allowed then
			table.insert(going, player)
		else
			self:Leave(player)
			self.notify(player, reason or self.rules.ModeLockReason(modeId, profile))
		end
	end
	if #going == 0 then
		self.cars[portalId] = nil
		return
	end
	local ok, message = self.launch(going, mapId, modeId)
	if not ok then
		car.remaining = COUNTDOWN
		for _, player in ipairs(going) do self.notify(player, message) end
		self:_announce(car)
		return
	end
	self.cars[portalId] = nil
	for _, player in ipairs(going) do self.riding[player] = nil end
end

function Elevator:Step(dt, players)
	for _, player in ipairs(players) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local here = nil
		-- A player who already left the server is never boarded again, even
		-- if a stale list still names them.
		if root and player.Parent ~= nil and self.available(player) then
			for portalId, zone in pairs(self.zones) do
				if inside(zone, root.Position) then here = portalId break end
			end
		end
		local current = self.riding[player]
		if current and current ~= here then
			self:_drop(player)
			current = nil
		end
		if not here then
			self.refused[player] = nil
		elseif not current and self.refused[player] ~= here then
			self:_board(player, here)
		end
	end
	for player in pairs(self.riding) do
		if player.Parent == nil then self:_drop(player) end
	end
	for player in pairs(self.refused) do
		if player.Parent == nil then self.refused[player] = nil end
	end
	for portalId, car in pairs(self.cars) do
		car.remaining -= dt
		if car.remaining <= 0 then self:_depart(portalId) end
	end
end

function Elevator:Snapshot(player)
	local portalId = self.riding[player]
	local car = portalId and self.cars[portalId]
	if not car then return nil end
	local modeId = self:Plan(portalId)
	local riders = {}
	for _, rider in ipairs(car.riders) do table.insert(riders, { userId = rider.UserId, name = rider.Name }) end
	return {
		portalId = portalId, modeId = modeId, riders = riders, max = MAX_RIDERS,
		remaining = math.max(0, math.ceil(car.remaining)), host = car.riders[1] == player,
	}
end

return Elevator
