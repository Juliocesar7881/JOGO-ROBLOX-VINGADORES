--!nonstrict
-- Mode portals as elevators, the way the big Roblox tower defenses do it:
-- stepping onto a portal's pad puts you in its car, a short countdown runs,
-- anyone who steps on meanwhile rides along, and at zero the match starts.
-- Every portal has a fixed map/mode pair. All riders share that destination.
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
		serial = 0,
		cars = {}, riding = {}, refused = {},
	}, Elevator)
end

function Elevator:_announce(car)
	for _, rider in ipairs(car.riders) do self.changed(rider) end
end

-- A destination has three independent cars. Catalog IDs stay stable; only
-- the zone identifies a particular queue (normal, normal:2, normal:3).
function Elevator:Destination(queueId)
	local zone = self.zones[queueId]
	return zone and zone.destinationId or queueId
end

-- The host is whoever stepped on first; the portal determines the mode.
function Elevator:Plan(portalId)
	local car = self.cars[portalId]
	local host = car and car.riders[1]
	local profile = host and self.profileOf(host)
	if not profile then return nil end
	return self.rules.PortalMode(profile, self:Destination(portalId))
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
	if car and car.departing then
		self:_refuse(player, portalId, "Esta fila já está partindo. Use outra fila. / This queue is departing. Use another queue.")
		return
	end
	if car and #car.riders >= MAX_RIDERS then
		self:_refuse(player, portalId, "Este portal já está cheio. / This portal is full.")
		return
	end
	local destinationId = self:Destination(portalId)
	local modeId = self.rules.PortalMode(profile, destinationId)
	if not modeId then return end
	if car then
		-- A car already has a plan, set by its first rider. Joining is only
		-- allowed for someone who could actually play it, so nobody rides a
		-- countdown only to be thrown off at zero.
		local planned = self:Plan(portalId)
		if planned then
			-- Whether someone may play a mode never depends on which map is
			-- drawn, so any map stands in for the check.
			local allowed, reason = self.rules.CanStart(profile, self.rules.PortalMap(destinationId), planned)
			if allowed then
				allowed, reason = self.rules.CanUseDifficulty(profile, self.rules.PortalMap(destinationId), planned, car.difficulty)
			end
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
		self.serial += 1
		car = { portalId = portalId, riders = {}, remaining = COUNTDOWN, id=tostring(self.serial), difficulty = "normal" }
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

-- Touch order wins even if Players:GetPlayers() has a different order on
-- the next poll. The root still has to be inside the server's actual zone.
function Elevator:Touch(player, queueId)
	local zone=self.zones[queueId]
	local root=player and player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not zone or not root or player.Parent==nil or not self.available(player) then return false end
	if self.riding[player] or self.refused[player]==queueId or not inside(zone,root.Position) then return false end
	self:_board(player,queueId)
	return self.riding[player]==queueId
end

-- The Leave button: off the car and off the pad, and not boarded again
-- until the player has actually stepped away and come back.
function Elevator:Leave(player)
	local portalId = self.riding[player]
	if not portalId then return false end
	if self.cars[portalId] and self.cars[portalId].departing then return false end
	self:_drop(player)
	self.refused[player] = portalId
	local zone = self.zones[portalId]
	if zone then self.eject(player, zone.exit) end
	return true
end

-- START NOW: the host (first rider) may skip the rest of the countdown once
-- everyone aboard has had a moment to see the plan. Anyone else is refused.
local START_NOW_AFTER = 1.5
function Elevator:StartNow(player)
	local portalId = self.riding[player]
	local car = portalId and self.cars[portalId]
	if not car or car.departing or car.riders[1] ~= player then return false end
	car.remaining = math.min(car.remaining, START_NOW_AFTER)
	self:_announce(car)
	return true
end

-- The host (first rider) picks the campaign difficulty. Refused, never
-- clamped, when anyone aboard has not opened it on this map yet.
function Elevator:SetDifficulty(player, difficultyId)
	local portalId = self.riding[player]
	local car = portalId and self.cars[portalId]
	if not car or car.departing then return false, "Entre em um portal primeiro. / Step into a portal first." end
	if car.riders[1] ~= player then return false, "Só quem entrou primeiro escolhe. / Only the first rider chooses." end
	local mapId, modeId = self.rules.PortalMap(self:Destination(portalId)), self:Plan(portalId)
	for _, rider in ipairs(car.riders) do
		local allowed, reason = self.rules.CanUseDifficulty(self.profileOf(rider), mapId, modeId, difficultyId)
		if not allowed then return false, reason end
	end
	car.difficulty = difficultyId
	car.remaining = math.max(car.remaining, JOIN_GRACE)
	self:_announce(car)
	return true
end

function Elevator:_depart(portalId)
	local car = self.cars[portalId]
	if not car or car.departing then return end
	local modeId = self:Plan(portalId)
	if not modeId then
		car.remaining = 2
		return
	end
	-- Resolve from the server catalog, never from a client-provided map.
	local mapId = self.rules.PortalMap(self:Destination(portalId))
	local going = {}
	for _, player in ipairs(table.clone(car.riders)) do
		local profile = self.profileOf(player)
		local allowed, reason = self.rules.CanStart(profile, mapId, modeId)
		if allowed then allowed, reason = self.rules.CanUseDifficulty(profile, mapId, modeId, car.difficulty) end
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
	-- Teleport may yield. Keep the seats reserved and prevent another Step
	-- from launching this same group while the first transfer is pending.
	car.departing = true
	self:_announce(car)
	local called, ok, message = pcall(self.launch, going, mapId, modeId, car.difficulty)
	if not called then ok, message = false, "Falha ao preparar partida. Tentando novamente. / Match transfer failed. Retrying." end
	if not ok then
		car.departing = false
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
		if current and self.cars[current] and self.cars[current].departing then continue end
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
		if car.departing then continue end
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
		carId=car.id, mapId=self.rules.PortalMap(self:Destination(portalId)),
		portalId = self:Destination(portalId), queueId = portalId,
		slot = (self.zones[portalId] or {}).slot or 1, departing = car.departing == true,
		modeId = modeId, difficultyId = car.difficulty, riders = riders, max = MAX_RIDERS,
		remaining = math.max(0, math.ceil(car.remaining)), host = car.riders[1] == player,
	}
end

function Elevator:PublicSnapshot()
	local result = {}
	for queueId, zone in pairs(self.zones) do
		local car = self.cars[queueId]
		result[queueId] = { count = car and #car.riders or 0, max = MAX_RIDERS,
			remaining = car and math.max(0, math.ceil(car.remaining)) or 0,
			departing = car and car.departing == true or false, slot = zone.slot or 1 }
	end
	return result
end

return Elevator
