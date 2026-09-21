--!nonstrict
-- Groups are formed inside a single lobby server and travel together to a
-- reserved match server. Codes are per-server and expire with the party, so a
-- stale code can never pull a stranger into someone else's reserved match.
local Players = game:GetService("Players")

local PartyService = {}
PartyService.__index = PartyService

-- Ambiguous glyphs (0/O, 1/I) are excluded: codes are read aloud and retyped.
local ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
local CODE_LENGTH = 4

local function text(pt, en) return pt .. " / " .. en end

function PartyService.new(config, onChanged)
	return setmetatable({
		config = config,
		onChanged = onChanged or function() end,
		maxSize = math.clamp(tonumber(config and config.MaxPartySize) or 4, 1, 4),
		parties = {},
		byUser = {},
		random = Random.new(),
	}, PartyService)
end

function PartyService:_notify(party)
	for _, userId in ipairs(party.members) do
		local player = Players:GetPlayerByUserId(userId)
		if player then
			local ok, problem = pcall(self.onChanged, player)
			if not ok then warn("[PartyService] Snapshot callback failed: " .. tostring(problem)) end
		end
	end
end

function PartyService:_code()
	for _ = 1, 64 do
		local code = ""
		for _ = 1, CODE_LENGTH do
			local index = self.random:NextInteger(1, #ALPHABET)
			code ..= string.sub(ALPHABET, index, index)
		end
		if not self.parties[code] then return code end
	end
	return nil
end

function PartyService:Get(player)
	local party = self.byUser[player.UserId]
	if party and self.parties[party.code] == party then return party end
	return nil
end

function PartyService:Create(player)
	if self:Get(player) then return false, text("Você já está em um grupo.", "You are already in a party.") end
	local code = self:_code()
	if not code then return false, text("Não foi possível criar um código agora.", "Could not create a code right now.") end
	local party = { code = code, leaderId = player.UserId, members = { player.UserId }, locked = false, createdAt = os.clock() }
	self.parties[code] = party
	self.byUser[player.UserId] = party
	self:_notify(party)
	return true
end

function PartyService:Join(player, code)
	if type(code) ~= "string" or #code > 16 then return false, text("Código inválido.", "Invalid code.") end
	code = string.upper(string.gsub(code, "%s", ""))
	local party = self.parties[code]
	if not party then return false, text("Grupo não encontrado neste servidor.", "Party not found on this server.") end
	if self:Get(player) == party then return true end
	if self:Get(player) then return false, text("Saia do seu grupo atual primeiro.", "Leave your current party first.") end
	if party.locked then return false, text("Este grupo já está entrando em uma partida.", "This party is already entering a match.") end
	if #party.members >= self.maxSize then return false, text("O grupo está completo.", "The party is full.") end
	table.insert(party.members, player.UserId)
	self.byUser[player.UserId] = party
	self:_notify(party)
	return true
end

function PartyService:Leave(player)
	local party = self:Get(player)
	if not party then return false end
	local index = table.find(party.members, player.UserId)
	if index then table.remove(party.members, index) end
	self.byUser[player.UserId] = nil
	if #party.members == 0 then
		self.parties[party.code] = nil
	else
		if party.leaderId == player.UserId then party.leaderId = party.members[1] end
		self:_notify(party)
	end
	local ok = pcall(self.onChanged, player)
	if not ok then warn("[PartyService] Snapshot callback failed after leave.") end
	return true
end

function PartyService:Remove(player)
	if self:Get(player) then self:Leave(player) end
end

function PartyService:IsLeader(player)
	local party = self:Get(player)
	return party == nil or party.leaderId == player.UserId
end

-- Ordered leader-first, and limited to members still connected here. A member
-- who disconnected while the leader pressed start simply does not travel.
function PartyService:Members(player)
	local party = self:Get(player)
	if not party then return { player } end
	local members, seen = {}, {}
	local leader = Players:GetPlayerByUserId(party.leaderId)
	if leader then
		table.insert(members, leader)
		seen[leader.UserId] = true
	end
	for _, userId in ipairs(party.members) do
		local member = Players:GetPlayerByUserId(userId)
		if member and not seen[userId] then
			table.insert(members, member)
			seen[userId] = true
		end
	end
	if #members == 0 then members = { player } end
	while #members > self.maxSize do table.remove(members) end
	return members
end

function PartyService:SetLocked(player, locked)
	local party = self:Get(player)
	if not party then return end
	party.locked = locked == true
	self:_notify(party)
end

function PartyService:Disband(player)
	local party = self:Get(player)
	if not party then return end
	local members = table.clone(party.members)
	self.parties[party.code] = nil
	for _, userId in ipairs(members) do self.byUser[userId] = nil end
	for _, userId in ipairs(members) do
		local member = Players:GetPlayerByUserId(userId)
		if member then pcall(self.onChanged, member) end
	end
end

function PartyService:Snapshot(player)
	local party = self:Get(player)
	if not party then return nil end
	local members = {}
	for _, userId in ipairs(party.members) do
		local member = Players:GetPlayerByUserId(userId)
		table.insert(members, { userId = userId, name = member and member.Name or ("Player " .. tostring(userId)) })
	end
	return { code = party.code, leaderId = party.leaderId, members = members, locked = party.locked, maxSize = self.maxSize }
end

return PartyService
