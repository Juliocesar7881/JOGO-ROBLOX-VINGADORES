-- Executed by test_party_service.py, which inlines the real PartyService.
--
-- Parties are formed in a lobby server and travel together to a reserved
-- match server, so the failure modes that matter are social ones: a code that
-- outlives its party, a leader who leaves, a member who disconnects between
-- pressing start and arriving. None of that is visible to the other suites.
local checks, failures = 0, 0
local function check(condition, label)
	checks += 1
	if not condition then
		failures += 1
		print("FAIL: " .. label)
	end
end

--==============================================================================
-- Roblox stand-ins
--==============================================================================
local online = {}
local function newPlayer(userId, name)
	local player = { UserId = userId, Name = name or ("Player" .. tostring(userId)) }
	online[userId] = player
	return player
end
local function disconnect(player) online[player.UserId] = nil end

local players = {}
function players:GetPlayerByUserId(userId) return online[userId] end

game = {
	GetService = function(_, name)
		assert(name == "Players", "unstubbed service: " .. tostring(name))
		return players
	end,
}

-- Deterministic, and deliberately terrible: this generator repeats itself
-- constantly, which is exactly the pressure the code-collision path needs.
local sequence, cursor = { 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 }, 0
Random = {
	new = function()
		return {
			NextInteger = function(_, low, high)
				cursor += 1
				local value = sequence[(cursor - 1) % #sequence + 1]
				return math.clamp(low + value - 1, low, high)
			end,
		}
	end,
}

warn = function() end

local PartyService = __SERVICE__

--==============================================================================
-- Forming a party
--==============================================================================
print("--- forming ---")
local notified = {}
local function newService(maxSize)
	notified = {}
	return PartyService.new({ MaxPartySize = maxSize or 4 }, function(player)
		notified[player.UserId] = (notified[player.UserId] or 0) + 1
	end)
end

local service = newService()
local leader = newPlayer(1, "Leader")
local friend = newPlayer(2, "Friend")
local stranger = newPlayer(3, "Stranger")

check(service:Get(leader) == nil, "a fresh player has no party")
check(service:IsLeader(leader), "an unpartied player counts as their own leader")
check(service:Snapshot(leader) == nil, "an unpartied player has no party snapshot")

local created, problem = service:Create(leader)
check(created, "the leader can create a party: " .. tostring(problem))
local party = service:Get(leader)
check(party ~= nil and #party.code == 4, "the party gets a four character code")
check(notified[leader.UserId] == 1, "creating a party pushes one snapshot to its only member")

local again, reason = service:Create(leader)
check(not again and reason ~= nil, "the same player cannot create a second party")

--==============================================================================
-- Joining
--==============================================================================
print("--- joining ---")
check(service:Join(friend, party.code), "a friend joins with the code")
check(service:Get(friend) == party, "the friend lands in the same party")
check(#party.members == 2, "the party holds both members")
check(service:IsLeader(friend) == false, "a joiner is not the leader")

check(service:Join(friend, party.code) == true, "re-joining your own party is a no-op success")
check(#party.members == 2, "re-joining does not duplicate the member")

check(service:Join(friend, string.lower(party.code)), "codes are case insensitive")
check(service:Join(stranger, " " .. party.code .. " "), "surrounding whitespace is tolerated")
check(#party.members == 3, "the stranger joined once")

local ok, notFound = service:Join(newPlayer(9), "ZZZZ")
check(not ok and notFound ~= nil, "an unknown code is refused")
check(not (service:Join(newPlayer(10), 1234)), "a non-string code is refused")
check(not (service:Join(newPlayer(11), string.rep("A", 40))), "an absurdly long code is refused")

local fourth = newPlayer(4)
check(service:Join(fourth, party.code), "a fourth member fits")
local fifth = newPlayer(5)
local full, fullReason = service:Join(fifth, party.code)
check(not full and fullReason ~= nil, "a fifth member is refused")
check(#party.members == 4, "the party caps at four")

--==============================================================================
-- A locked party is one already travelling
--==============================================================================
print("--- locked ---")
service:Leave(fourth)
service:SetLocked(leader, true)
local locked, lockedReason = service:Join(fourth, party.code)
check(not locked and lockedReason ~= nil, "nobody joins a party that is already entering a match")
service:SetLocked(leader, false)
check(service:Join(fourth, party.code), "unlocking lets them back in")

--==============================================================================
-- Membership, ordering and disconnects
--==============================================================================
print("--- membership ---")
local members = service:Members(leader)
check(#members == 4, "every connected member travels, got " .. tostring(#members))
check(members[1] == leader, "the leader travels first")

disconnect(stranger)
local connected = service:Members(leader)
check(#connected == 3, "a member who dropped does not travel, got " .. tostring(#connected))
for _, member in ipairs(connected) do
	check(member ~= stranger, "the disconnected member is absent from the travel list")
end
online[stranger.UserId] = stranger

local snapshot = service:Snapshot(leader)
check(snapshot ~= nil and snapshot.code == party.code, "the snapshot carries the code")
check(snapshot.leaderId == leader.UserId, "the snapshot names the leader")
check(#snapshot.members == 4 and snapshot.maxSize == 4, "the snapshot lists members and the cap")

--==============================================================================
-- Leaving: the code must never outlive the party
--==============================================================================
print("--- leaving ---")
check(service:Leave(leader), "the leader can leave")
check(service:Get(leader) == nil, "leaving clears your party")
check(party.leaderId ~= leader.UserId, "leadership passes to someone still present")
check(service:IsLeader(friend) or service:IsLeader(fourth) or service:IsLeader(stranger),
	"exactly one remaining member is promoted")

local code = party.code
for _, member in ipairs({ friend, stranger, fourth }) do service:Leave(member) end
local orphan, orphanReason = service:Join(newPlayer(12), code)
check(not orphan and orphanReason ~= nil, "the code dies with the last member, so it cannot pull in a stranger")
check(service:Leave(newPlayer(13)) == false, "leaving without a party is a harmless no-op")

--==============================================================================
-- Disband and Remove
--==============================================================================
print("--- disband ---")
local host = newPlayer(20)
local guest = newPlayer(21)
service:Create(host)
service:Join(guest, service:Get(host).code)
local hostCode = service:Get(host).code
service:Disband(host)
check(service:Get(host) == nil and service:Get(guest) == nil, "disbanding clears everyone")
check(not (service:Join(newPlayer(22), hostCode)), "a disbanded code stops working")

service:Create(host)
service:Remove(host)
check(service:Get(host) == nil, "Remove drops a leaving player from their party")
local disbandFree = pcall(function() service:Disband(newPlayer(23)) end)
check(disbandFree, "disbanding without a party does not throw")

--==============================================================================
-- Party size cap comes from config
--==============================================================================
print("--- configured cap ---")
local duo = newService(2)
local a, b, c = newPlayer(30), newPlayer(31), newPlayer(32)
duo:Create(a)
check(duo:Join(b, duo:Get(a).code), "a second member fits a duo server")
check(not (duo:Join(c, duo:Get(a).code)), "a third member does not fit a duo server")
check(duo:Snapshot(a).maxSize == 2, "the snapshot reports the configured cap")

--==============================================================================
-- Code collisions never hand out a duplicate
--==============================================================================
-- The stubbed generator above can only ever produce three distinct codes.
-- Under that pressure the service must hand out those three and then refuse,
-- never recycle a code that another live party is still using.
print("--- codes ---")
local collide = newService()
local seen, issued, refused = {}, 0, 0
for index = 1, 12 do
	local host2 = newPlayer(100 + index)
	if collide:Create(host2) then
		issued += 1
		local partyCode = collide:Get(host2).code
		check(seen[partyCode] == nil, "every live party has a unique code, repeated " .. tostring(partyCode))
		seen[partyCode] = true
	else
		refused += 1
	end
end
check(issued == 3, "the exhaustible generator issues exactly its three codes, got " .. tostring(issued))
check(refused == 9, "once codes run out creation fails closed, got " .. tostring(refused) .. " refusals")

-- And a code freed by a disbanded party becomes available again.
local recycler = newService()
local first = newPlayer(200)
recycler:Create(first)
local freedCode = recycler:Get(first).code
recycler:Disband(first)
local second = newPlayer(201)
check(recycler:Create(second), "creation still works after a disband freed its code")
check(recycler.parties[freedCode] == nil or recycler:Get(second).code == freedCode,
	"the disbanded code is released, never left dangling on a party nobody is in")

print(string.format("%s party service: %d checks, %d failures",
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error("party service failed", 0) end
