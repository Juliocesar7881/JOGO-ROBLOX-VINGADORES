"""Boot the real server as a live single-place deployment, as a lobby and as a battle.

Run: python tests/test_server_travel.py

Config.SinglePlace turns the published place into two kinds of server: public
servers are lobbies and every battle runs in a server the lobby reserves of the
same place (Rules.PlaceRole). Teleports never work in a Studio playtest, so
this boots the real init.server outside Studio (in-memory DataStore and
MemoryStore stand-ins, a recording TeleportService) and walks the whole trip:
a portal in a lobby reserves a battle server and teleports the group there;
when Roblox cannot reserve, the lobby hosts the battle itself; a battle server
starts the group that arrives with the lobby's travel data and sends a stray
arrival back to a lobby. The harness is the one tests/server_boot.spec.luau
uses (everything above its first session), with these services swapped.
"""
from pathlib import Path
import argparse
import subprocess
import sys
import tempfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import test_server_boot as boot  # noqa: E402

PLACE = 97132875544830

SERVICES = r'''
services.DataStoreService = (function()
	local function clone(value)
		if type(value) ~= "table" then return value end
		local out = {}
		for key, item in pairs(value) do out[key] = clone(item) end
		return out
	end
	local function store()
		local self = { values = {} }
		function self:UpdateAsync(key, transform)
			local result = transform(clone(self.values[key]))
			if result ~= nil then self.values[key] = clone(result) end
			return clone(result)
		end
		function self:GetAsync(key) return clone(self.values[key]) end
		function self:SetAsync(key, value) self.values[key] = clone(value) end
		function self:GetSortedAsync()
			local rows = {}
			for key, value in pairs(self.values) do table.insert(rows, { key = key, value = value }) end
			table.sort(rows, function(a, b) return a.value > b.value end)
			return { GetCurrentPage = function() return rows end }
		end
		return self
	end
	local stores = {}
	return {
		GetDataStore = function(_, name) stores[name] = stores[name] or store(); return stores[name] end,
		GetOrderedDataStore = function(_, name) stores["o:" .. name] = stores["o:" .. name] or store(); return stores["o:" .. name] end,
	}
end)()
-- One shared map, as MemoryStore is across the servers of a universe. The
-- battle scenario files the code the lobby would have filed for this server.
rejoinValues = { ["server:reserved-1"] = "code-1" }
services.MemoryStoreService = { GetHashMap = function()
	return {
		SetAsync = function(_, key, value) rejoinValues[key] = value; return true end,
		GetAsync = function(_, key) return rejoinValues[key] end,
		RemoveAsync = function(_, key) rejoinValues[key] = nil end,
	}
end }
services.AnalyticsService = {
	LogCustomEvent = function() end, LogEconomyEvent = function() end,
	LogFunnelStepEvent = function() end, LogProgressionEvent = function() end,
	LogOnboardingFunnelStepEvent = function() end,
}
services.PolicyService = { GetPolicyInfoForPlayerAsync = function() return { ArePaidRandomItemsRestricted = false, IsPaidItemTradingAllowed = true } end }
'''

TELEPORT = r'''local teleports = {}
local reserveFails = false
services.TeleportService = {
	TeleportInitFailed = newSignal(),
	TeleportAsync = function(_, placeId, players, options)
		table.insert(teleports, { placeId = placeId, players = players, code = options and options.ReservedServerAccessCode, data = options and options.__teleportData })
	end,
	ReserveServer = function()
		if reserveFails then error("reserve unavailable") end
		return "code-1", "server-1"
	end,
}
-- TeleportOptions as the engine has it: an access code and SetTeleportData.
Instance = setmetatable({ new = function(className, ...)
	if className == "TeleportOptions" then
		local options = { ReservedServerAccessCode = "" }
		function options:SetTeleportData(data) self.__teleportData = data end
		return options
	end
	return Instance.__original(className, ...)
end, __original = Instance.new }, { __index = Instance })'''

SCENARIOS = {
    "lobby": r'''
say("--- single place: lobby server ---")
local function teleportsOf(userId)
	local found = {}
	for _, trip in ipairs(teleports) do
		for _, member in ipairs(trip.players or {}) do if member.UserId == userId then table.insert(found, trip) end end
	end
	return found
end
local ana = join(501, "Ana")
check(latest(ana) and latest(ana).role == "Lobby", "a public server of the single place is a lobby, got " .. tostring(latest(ana) and latest(ana).role))
check(latest(ana).profile ~= nil, "the lobby loads the profile from the DataStore")
stepInto(ana, "normal")
for _ = 1, 30 do
	frames(0.5)
	if #teleportsOf(501) > 0 then break end
end
local trip = teleportsOf(501)[1]
check(trip ~= nil and trip.placeId == __PLACE__ and trip.code == "code-1", "the portal reserves a battle server of the same place and sends the group there")
check(trip and type(trip.data) == "table" and trip.data.mapId == "manhattan" and trip.data.modeId == "normal" and trip.data.size == 1 and table.find(trip.data.members, 501) ~= nil, "the trip carries map, mode and the party, never the access code")
check(trip and trip.data and trip.data.code == nil and trip.data.accessCode == nil, "the access code stays out of the travel data")
frames(1)
check(rejoinValues["server:server-1"] == "code-1" and type(rejoinValues["501"]) == "table", "the lobby files the seat and the server's access code in MemoryStore")
check(latest(ana).match == nil, "the lobby does not run that battle itself")

-- "Go along": a friend joins the queue a friend is riding; a stranger cannot.
local function joinFriendly(userId, name, friendIds)
	local player = Instance.new("Player")
	player.UserId, player.Name = userId, name
	player.GetJoinData = function() return {} end
	player.IsFriendsWith = function(_, otherId) return table.find(friendIds, otherId) ~= nil end
	local character = Instance.new("Model")
	character.Name = name
	local root = Instance.new("Part")
	root.Name, root.CFrame, root.Parent = "HumanoidRootPart", CFrame.new(0, 5.5, 480), character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	character.Parent = workspace
	player.Character = character
	player.Parent = Players
	task.spawn(function() Players.PlayerAdded:Fire(player) end)
	advance(0.2)
	return player
end
local dan = joinFriendly(503, "Dan", { 504 })
local eva = joinFriendly(504, "Eva", { 503 })
local stranger = joinFriendly(505, "Stranger", {})
frames(0.5)
stepInto(dan, "normal_hydra")
frames(0.5)
check(latest(dan).elevator ~= nil, "(setup) Dan rides a queue")
frames(2.5) -- lobby snapshots reach everyone every two seconds
check(type(latest(eva).friendsRiding) == "table" and latest(eva).friendsRiding[1].userId == 503, "Eva's snapshot shows her friend's queue")
check(latest(stranger).friendsRiding == nil, "a stranger is not shown other people's queues")
check(not request(stranger, "ElevatorJoin", { userId = 503 }).ok, "a stranger cannot go along")
check(request(eva, "ElevatorJoin", { userId = 503 }).ok and latest(eva).elevator ~= nil and latest(eva).elevator.portalId == "normal_hydra", "Eva goes along into Dan's queue")
check(request(dan, "ElevatorFriends", { on = true }).ok and latest(dan).elevator.friendsOnly == true, "Dan closes the queue to friends")
check(not request(eva, "ElevatorFriends", { on = false }).ok, "only the first rider opens or closes the queue")
request(eva, "ElevatorLeave", {})
request(dan, "ElevatorLeave", {})
frames(0.5)

-- Roblox cannot reserve a server: the lobby hosts the battle rather than stranding the group.
reserveFails = true
local bia = join(502, "Bia")
stepInto(bia, "normal_gamma")
local started = false
for _ = 1, 30 do
	frames(0.5)
	if latest(bia).match ~= nil then started = true; break end
end
check(started and #teleportsOf(502) == 0, "when travel fails the lobby runs the battle itself")
''',
    "match": r'''
say("--- single place: battle server ---")
local function teleportsOf(userId)
	local found = {}
	for _, trip in ipairs(teleports) do
		for _, member in ipairs(trip.players or {}) do if member.UserId == userId then table.insert(found, trip) end end
	end
	return found
end
local function joinWith(userId, name, data)
	local player = Instance.new("Player")
	player.UserId, player.Name = userId, name
	player.GetJoinData = function() return { TeleportData = data, SourcePlaceId = __PLACE__ } end
	local character = Instance.new("Model")
	character.Name = name
	local root = Instance.new("Part")
	root.Name, root.CFrame, root.Parent = "HumanoidRootPart", CFrame.new(0, 5.5, 480), character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	character.Parent = workspace
	player.Character = character
	player.Parent = Players
	task.spawn(function() Players.PlayerAdded:Fire(player) end)
	advance(0.2)
	return player
end
-- Someone who reaches a battle server without travel data goes back to a lobby.
local stray = join(601, "Stray")
check(latest(stray) and latest(stray).role == "Match", "a reserved server of the single place is a battle server, got " .. tostring(latest(stray) and latest(stray).role))
frames(7)
local back = teleportsOf(601)[1]
check(back ~= nil and back.placeId == __PLACE__ and (back.code == nil or back.code == ""), "a stray arrival is sent to a public lobby of the same place")
-- The group arrives with the lobby's travel data: its battle starts.
local cris = joinWith(602, "Cris", { mapId = "manhattan", modeId = "normal", runId = "run-1", size = 1, leaderId = 602, members = { 602 } })
local started = false
for _ = 1, 20 do
	frames(0.5)
	if latest(cris).match ~= nil then started = true; break end
end
check(started and latest(cris).match.mapId == "manhattan", "the arriving group's battle starts in the battle server")
check(#teleportsOf(602) == 0, "the arriving group is not sent anywhere")
frames(1)
local seat = rejoinValues["602"]
check(type(seat) == "table" and seat.code == "code-1" and seat.place == __PLACE__, "the battle server files the player's seat with its own access code, for reconnects and replays")
''',
}

ENDING = r'''
local bad = {}
for _, line in ipairs(routerWarnings()) do
	-- The lobby scenario breaks ReserveServer on purpose to exercise the fallback.
	local provoked = reserveFails and (string.find(line, "ReserveServer failed", 1, true) or string.find(line, "Travel failed", 1, true))
	if not provoked then table.insert(bad, line) end
end
check(#bad == 0, "no request, snapshot or step failed silently: " .. table.concat(bad, " | "))
say(string.format("%s server travel (__SCENARIO__): %d checks, %d failures (%d warnings)",
	failures == 0 and "PASS" or "FAIL", checks, failures, #warnings))
if failures > 0 then
	for _, line in ipairs(warnings) do say("  warning: " .. line) end
	error("server travel failed", 0)
end
'''


def assemble(root: Path, scenario: str) -> str:
    spec = (root / "tests" / "server_boot.spec.luau").read_text(encoding="utf-8")
    harness = spec.split('say("--- first session ---")', 1)[0]
    swaps = [
        ("function runService:IsStudio() return true end", "function runService:IsStudio() return false end"),
        ('''local teleports = {}
services.TeleportService = {
	TeleportInitFailed = newSignal(),
	TeleportAsync = function(_, placeId, players) table.insert(teleports, { placeId = placeId, players = players }) end,
	ReserveServer = function() return "code", "id" end,
}''', TELEPORT),
        ('''services.DataStoreService = {
	GetDataStore = function() error("Studio memory profiles must never touch DataStore") end,
	GetOrderedDataStore = function() error("Studio memory boards must never touch DataStore") end,
}
services.MemoryStoreService = { GetHashMap = function() error("Rejoin must stay off in Studio") end }
services.AnalyticsService = {}''', SERVICES),
        ('if not step("the bootstrap boots as a Standalone server", function()',
         'game.PlaceId, game.PrivateServerId, game.PrivateServerOwnerId = __PLACE__, "__PRIVATE__", 0\n'
         'if not step("the bootstrap boots as a live single-place server", function()'),
    ]
    for old, new in swaps:
        assert harness.count(old) == 1, f"server_boot.spec harness changed: {old[:60]!r}"
        harness = harness.replace(old, new)
    source = harness + SCENARIOS[scenario] + ENDING
    source = source.replace("__PLACE__", str(PLACE)).replace("__PRIVATE__", "reserved-1" if scenario == "match" else "").replace("__SCENARIO__", scenario)
    for token, relative in boot.IMMEDIATE.items():
        body = (root / relative).read_text(encoding="utf-8-sig")
        source = source.replace(token, "(function()\n" + body + "\nend)()")
    for token, relative in boot.LOADERS.items():
        body = (root / relative).read_text(encoding="utf-8-sig")
        source = source.replace(token, "(function(script, os)\n" + body + "\nend)")
    return source


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser()
    parser.add_argument("--luau", type=Path, default=root / ".tools" / "luau" / "luau.exe")
    parser.add_argument("--keep", type=Path, help="Write the assembled scripts here for debugging")
    args = parser.parse_args()
    if not args.luau.is_file():
        raise SystemExit("Luau CLI missing. Run tools/test.py or supply --luau <path>.")
    status = 0
    for scenario in ("lobby", "match"):
        source = assemble(root, scenario)
        if args.keep:
            args.keep.mkdir(parents=True, exist_ok=True)
            (args.keep / f"travel-{scenario}.luau").write_text(source, encoding="utf-8")
        with tempfile.TemporaryDirectory(prefix="doomsday-server-travel-") as temporary:
            script = Path(temporary) / "server.luau"
            script.write_text(source, encoding="utf-8")
            result = subprocess.run([str(args.luau), str(script)], cwd=root, check=False)
            status = status or result.returncode
    raise SystemExit(status)


if __name__ == "__main__":
    main()
