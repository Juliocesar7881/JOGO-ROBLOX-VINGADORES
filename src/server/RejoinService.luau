--!nonstrict
-- Holding a seat open across two places. A reserved battle server cannot be
-- found again from its place id alone, so the lobby records the access code it
-- reserved and the battle server decides how long that seat stays warm.
--
-- The access code is never sent to a client: teleport data is readable by the
-- player it travels with, and a leaked code would let a stranger walk into
-- someone else's reserved match.
local MemoryStoreService = game:GetService("MemoryStoreService")

local Rejoin = {}
Rejoin.__index = Rejoin

local MAP_NAME = "DoomRejoin_v1"
local MATCH_TTL = 5400 -- Longer than any match; trimmed the moment one ends.

function Rejoin.new(enabled, matchPlaceId)
	local self = setmetatable({ enabled = false, placeId = matchPlaceId }, Rejoin)
	if enabled ~= true then return self end
	-- MemoryStore needs a published universe, so this stays off in Studio and
	-- in any half-configured deployment.
	local ok, map = pcall(function() return MemoryStoreService:GetHashMap(MAP_NAME) end)
	if ok and map then
		self.map = map
		self.enabled = true
	else
		warn("[Rejoin] MemoryStore unavailable; reconnection is limited to a single server.")
	end
	return self
end

function Rejoin:_key(userId)
	return tostring(userId)
end

function Rejoin:Remember(userIds, accessCode, runId)
	if not self.enabled or type(accessCode) ~= "string" or accessCode == "" then return end
	local record = { code = accessCode, place = self.placeId, runId = tostring(runId) }
	for _, userId in ipairs(userIds) do
		task.spawn(function()
			local ok, problem = pcall(function()
				self.map:SetAsync(self:_key(userId), record, MATCH_TTL)
			end)
			if not ok then warn("[Rejoin] could not record a seat: " .. tostring(problem)) end
		end)
	end
end

-- The lobby that reserved a battle server also files its access code under
-- the server's own id, so the battle server can seat its players again after
-- a replay ("Jogar de novo" starts a new run in the same server). The code
-- still never reaches a client.
function Rejoin:RememberServer(serverId, accessCode)
	if not self.enabled or type(serverId) ~= "string" or serverId == "" or type(accessCode) ~= "string" or accessCode == "" then return end
	task.spawn(function()
		pcall(function() self.map:SetAsync("server:" .. serverId, accessCode, MATCH_TTL) end)
	end)
end

function Rejoin:ServerCode(serverId)
	if not self.enabled or type(serverId) ~= "string" or serverId == "" then return nil end
	local ok, value = pcall(function() return self.map:GetAsync("server:" .. serverId) end)
	return ok and type(value) == "string" and value ~= "" and value or nil
end

function Rejoin:Lookup(userId)
	if not self.enabled then return nil end
	local ok, value = pcall(function() return self.map:GetAsync(self:_key(userId)) end)
	if not ok or type(value) ~= "table" then return nil end
	if type(value.code) ~= "string" or value.code == "" then return nil end
	if type(value.place) ~= "number" or value.place <= 0 then return nil end
	return value
end

-- Called when a participant drops: the seat now expires with the reconnect
-- window instead of with the match.
function Rejoin:Hold(userId, seconds)
	if not self.enabled then return end
	task.spawn(function()
		local record = self:Lookup(userId)
		if not record then return end
		pcall(function()
			self.map:SetAsync(self:_key(userId), record, math.clamp(math.floor(seconds or 120), 15, 900))
		end)
	end)
end

-- The player made it back into the battle, so the seat goes back to lasting as
-- long as the match does.
function Rejoin:Extend(userId)
	if not self.enabled then return end
	task.spawn(function()
		local record = self:Lookup(userId)
		if not record then return end
		pcall(function()
			self.map:SetAsync(self:_key(userId), record, MATCH_TTL)
		end)
	end)
end

function Rejoin:Forget(userId)
	if not self.enabled then return end
	task.spawn(function()
		pcall(function() self.map:RemoveAsync(self:_key(userId)) end)
	end)
end

return Rejoin
