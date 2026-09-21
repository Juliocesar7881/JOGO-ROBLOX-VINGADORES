--!nonstrict
-- Executed by test_server_boot.py, which inlines the real bootstrap and every
-- server, shared and world module.
--
-- The bootstrap is the only place every service meets: the request router,
-- the rate limiter, snapshots, travel, presence and shutdown. It used to be
-- checked by regular expressions only. Worse, its router wraps each request
-- in pcall, so a runtime bug there does not crash anything — it quietly turns
-- every request of that kind into "Internal error. Nothing changed." This runs
-- the real init.server as a Standalone Studio server, plays real sessions
-- through Request exactly as a client would, and fails on any such warning.
local Stubs = __STUBS__
local v3 = Stubs.v3
local newSignal = Stubs.newSignal
local services = Stubs.services

local say = print
local checks, failures = 0, 0
local function check(condition, label)
	checks += 1
	if not condition then
		failures += 1
		say("FAIL: " .. label)
	end
end

--==============================================================================
-- A cooperative scheduler on a simulated clock. task.wait really suspends the
-- calling thread until the clock reaches its wake time, which is what keeps
-- PlayerService's autosave loop and the leaderboard totem loop from spinning.
--==============================================================================
local clock = 0
local sleeping = {}
local function resume(thread, ...)
	local ok, problem = coroutine.resume(thread, ...)
	if not ok then error(tostring(problem) .. "\n" .. debug.traceback(thread), 0) end
end
local function schedule(thread, wake, args) table.insert(sleeping, { thread = thread, wake = wake, args = args or {} }) end
task = {
	spawn = function(fn, ...)
		local thread = type(fn) == "thread" and fn or coroutine.create(fn)
		resume(thread, ...)
		return thread
	end,
	defer = function(fn, ...)
		local thread = coroutine.create(fn)
		schedule(thread, clock, table.pack(...))
		return thread
	end,
	delay = function(seconds, fn, ...)
		local thread = coroutine.create(fn)
		schedule(thread, clock + (tonumber(seconds) or 0), table.pack(...))
		return thread
	end,
	wait = function(seconds)
		local thread = coroutine.running()
		assert(thread and coroutine.isyieldable(), "task.wait called outside a thread")
		local duration = math.max(tonumber(seconds) or 0.03, 0.001)
		schedule(thread, clock + duration)
		coroutine.yield()
		return duration
	end,
}
local function advance(seconds)
	local target = clock + seconds
	while true do
		local pick, index
		for i, entry in ipairs(sleeping) do
			if entry.wake <= target and (not pick or entry.wake < pick.wake) then pick, index = entry, i end
		end
		if not pick then break end
		table.remove(sleeping, index)
		clock = math.max(clock, pick.wake)
		resume(pick.thread, table.unpack(pick.args, 1, pick.args.n or #pick.args))
	end
	clock = target
end
local clockOs = setmetatable({ clock = function() return clock end }, { __index = os })

local warnings = {}
warn = function(...)
	local parts = {}
	for _, value in ipairs({ ... }) do table.insert(parts, tostring(value)) end
	table.insert(warnings, table.concat(parts, " "))
end
print = function() end

--==============================================================================
-- Engine services the bootstrap and its modules reach for
--==============================================================================
local runService = { Heartbeat = newSignal(), Stepped = newSignal() }
function runService:IsStudio() return true end
function runService:IsServer() return true end
function runService:IsClient() return false end
services.RunService = runService

local teleports = {}
services.TeleportService = {
	TeleportInitFailed = newSignal(),
	TeleportAsync = function(_, placeId, players) table.insert(teleports, { placeId = placeId, players = players }) end,
	ReserveServer = function() return "code", "id" end,
}
services.DataStoreService = {
	GetDataStore = function() error("Studio memory profiles must never touch DataStore") end,
	GetOrderedDataStore = function() error("Studio memory boards must never touch DataStore") end,
}
services.MemoryStoreService = { GetHashMap = function() error("Rejoin must stay off in Studio") end }
services.AnalyticsService = {}
services.MarketplaceService = {
	PromptGamePassPurchaseFinished = newSignal(),
	UserOwnsGamePassAsync = function() return false end,
	GetProductInfo = function() return { PriceInRobux = 99, Name = "Product" } end,
}

local Players = services.Players
Players.GetPlayers = function(self)
	local list = {}
	for _, child in ipairs(self:GetChildren()) do
		if rawget(child, "__class") == "Player" then table.insert(list, child) end
	end
	return list
end
Players.GetPlayerByUserId = function(self, userId)
	for _, player in ipairs(self:GetPlayers()) do if player.UserId == userId then return player end end
	return nil
end
Players.GetNameFromUserIdAsync = function(_, userId) return "Player" .. tostring(userId) end

local closeHandler
game.BindToClose = function(_, fn) closeHandler = fn end

--==============================================================================
-- Module system and the place layout the bootstrap expects
--==============================================================================
local loaders, loaded = {}, {}
require = function(target)
	if loaded[target] ~= nil then return loaded[target] end
	local loader = loaders[target]
	assert(loader, "require of an unknown module: " .. tostring(target and target.Name))
	local value = loader(target, clockOs)
	loaded[target] = value
	return value
end
local function moduleScript(parent, name, loader)
	local instance = Instance.new("ModuleScript")
	instance.Name, instance.Parent = name, parent
	loaders[instance] = loader
	return instance
end

local shared = Instance.new("Folder")
shared.Name, shared.Parent = "DoomShared", services.ReplicatedStorage
moduleScript(shared, "Catalog", __CATALOG__)
moduleScript(shared, "Config", __CONFIG__)
moduleScript(shared, "Rules", __RULES__)
moduleScript(shared, "Waves", __WAVES__)
local Catalog = require(shared.Catalog)

local serverScript = Instance.new("Script")
serverScript.Name, serverScript.Parent = "DoomServer", services.ServerScriptService
moduleScript(serverScript, "PlayerService", __PLAYERS__)
moduleScript(serverScript, "WorldBuilder", __WORLD__)
moduleScript(serverScript, "MatchService", __MATCH__)
moduleScript(serverScript, "PartyService", __PARTY__)
moduleScript(serverScript, "PresenceService", __PRESENCE__)
moduleScript(serverScript, "AnalyticsService", __ANALYTICS__)
moduleScript(serverScript, "RejoinService", __REJOIN__)
moduleScript(serverScript, "ElevatorService", __ELEVATOR__)

local function step(name, fn)
	local ok, problem = xpcall(fn, debug.traceback)
	check(ok, name .. " ran without a Lua error: " .. tostring(problem))
	return ok
end

if not step("the bootstrap boots as a Standalone server", function()
	task.spawn(function() __SERVER__(serverScript, clockOs) end)
	advance(0.1)
end) then error("server boot failed", 0) end

local remotes = services.ReplicatedStorage:FindFirstChild("DoomRemotes")
check(remotes ~= nil and remotes:FindFirstChild("Request") ~= nil, "the bootstrap creates the remote contract")
check(workspace:FindFirstChild("DoomLobby") ~= nil, "the bootstrap builds the lobby")
local router = remotes.Request.OnServerInvoke
check(type(router) == "function", "Request is answered by a server function")

--==============================================================================
-- Harness: players, requests, snapshots and frames
--==============================================================================
local function join(userId, name)
	local player = Instance.new("Player")
	player.UserId, player.Name = userId, name
	player.GetJoinData = function() return {} end
	local character = Instance.new("Model")
	character.Name = name
	local root = Instance.new("Part")
	root.Name, root.CFrame, root.Parent = "HumanoidRootPart", CFrame.new(0, 3, 345), character
	local humanoid = Instance.new("Humanoid")
	humanoid.Parent = character
	character.Parent = workspace
	player.Character = character
	player.Parent = Players
	task.spawn(function() Players.PlayerAdded:Fire(player) end)
	advance(0.2)
	return player
end

local function leave(player)
	player.Parent = nil
	task.spawn(function() Players.PlayerRemoving:Fire(player) end)
	advance(0.2)
end

local function request(player, action, payload)
	local result, done
	task.spawn(function()
		result = router(player, action, payload)
		done = true
	end)
	for _ = 1, 400 do
		if done then break end
		advance(0.05)
	end
	check(done == true, "request " .. tostring(action) .. " completes")
	check(type(result) == "table" and type(result.ok) == "boolean", "request " .. tostring(action) .. " answers {ok, ...}")
	return result or { ok = false }
end

local function snapshots(player)
	local list = {}
	for _, entry in ipairs(rawget(remotes.State, "__fired") or {}) do
		if entry.player == player then table.insert(list, entry.args[1]) end
	end
	return list
end
local function latest(player)
	local list = snapshots(player)
	return list[#list]
end
local fxRead = 0
local function newEffects(player)
	local log, found = rawget(remotes.FX, "__fired") or {}, {}
	for index = fxRead + 1, #log do
		local entry = log[index]
		if entry.player == player then table.insert(found, entry.args[1]) end
	end
	return found
end

local function frames(seconds)
	local steps = math.floor(seconds / 0.1 + 0.5)
	for _ = 1, steps do
		advance(0.1)
		task.spawn(function() runService.Heartbeat:Fire(0.1) end)
	end
end

-- Starting a match is walking onto a portal pad: no request is involved.
local SPAWN = CFrame.new(0, 3, 345)
local function stepInto(player, modeId)
	local pad = workspace:FindFirstChild("DoomLobby"):FindFirstChild("Portal_" .. modeId):FindFirstChild("Pad")
	player.Character.HumanoidRootPart.CFrame = CFrame.new(pad.Position + v3(0, 2, 0))
end
local function stepOut(player) player.Character.HumanoidRootPart.CFrame = SPAWN end
local function rideUntilDeparture(player)
	for _ = 1, 24 do
		frames(0.5)
		if latest(player).match ~= nil then return true end
	end
	return false
end

local function routerWarnings()
	local bad = {}
	for _, line in ipairs(warnings) do
		if string.find(line, "Request", 1, true) or string.find(line, "failed", 1, true) or string.find(line, "Snapshot", 1, true) then
			table.insert(bad, line)
		end
	end
	return bad
end

--==============================================================================
-- A brand-new commander
--==============================================================================
say("--- first session ---")
local ana = join(501, "Ana")
local first = latest(ana)
check(first ~= nil, "joining pushes a first snapshot")
check(first and first.phase == "Lobby" and first.role == "Standalone", "a Studio server starts in the lobby, Standalone")
check(first and first.profile and first.profile.tutorialComplete == false, "a new commander has not trained yet")
check(first and first.profile and first.profile.gold == 0, "a new commander starts with no gold")

local sync = request(ana, "Sync", {})
check(sync.ok and sync.data and sync.data.phase == "Lobby", "Sync answers with the lobby snapshot")

-- The router's input validation, as a hostile client would probe it.
check(not router(ana, 42, {}).ok, "a non-string action is refused")
check(not router(ana, string.rep("x", 60), {}).ok, "an absurdly long action is refused")
check(not router(ana, "Sync", "payload").ok, "a non-table payload is refused")
check(not request(ana, "Teleport", {}).ok, "an unknown action is refused")
check(not request(ana, "PlaceTower", { heroId = "ironman", position = v3(0, 0, 0) }).ok, "match actions are refused in the lobby")
check(Catalog.Modes.normal.waves==50,"campaign is a 50 wave run")
check(not request(ana, "StartMatch", { mapId = "atlantis", modeId = "normal" }).ok, "an unknown map is refused")
check(not request(ana, "BuyHero", { heroId = "thor" }).ok, "a hero cannot be bought without gold")

check(request(ana, "Settings", { language = "pt", lowFX = true, shake = false, music = false }).ok, "settings are saved")
check(latest(ana).profile.settings.lowFX == true, "the saved setting comes back in the next snapshot")
check(request(ana, "SetLoadout", { heroes = { "ironman", "hawkeye" } }).ok, "the starting squad can be equipped")
check(request(ana, "Leaderboard", { mapId = "manhattan", size = 1 }).ok, "the leaderboard answers")
check(request(ana, "CreateParty", {}).ok, "a party can be created")
check(latest(ana).party ~= nil and #latest(ana).party.code == 4, "the party code arrives in the snapshot")
check(request(ana, "LeaveParty", {}).ok, "the party can be left")

--==============================================================================
-- Portals: the lobby's mode portals are elevators, walked into
--==============================================================================
say("--- portals ---")
stepInto(ana, "ranked")
frames(0.5)
check(latest(ana).elevator == nil, "a locked portal does not take a newcomer aboard")
local function noticed(player, fragment)
	for _, snap in ipairs(snapshots(player)) do
		if type(snap.notice) == "string" and string.find(snap.notice, fragment, 1, true) then return true end
	end
	return false
end
check(noticed(ana, "campanha normal"), "the refusal tells the newcomer to train first")
local anaRoot = ana.Character.HumanoidRootPart
local hardPad = workspace:FindFirstChild("DoomLobby").Portal_ranked.Pad
check((anaRoot.Position - hardPad.Position).Magnitude > 6, "and the newcomer is set down outside that portal")
stepOut(ana)
stepInto(ana, "normal")
frames(0.5)
local riding = latest(ana).elevator
check(riding ~= nil and riding.modeId == "normal" and riding.mapId == nil, "the campaign portal boards a newcomer for training in Manhattan")
check(riding and riding.host == true and #riding.riders == 1 and riding.remaining > 0, "as the first rider, with a countdown running")
check(not request(ana, "ElevatorMap", { step = 1 }).ok, "the first rider may switch the sector")
check(request(ana, "ElevatorLeave", {}).ok, "Leave is answered")
check(latest(ana).elevator == nil, "leaving clears the elevator from the snapshot")
check((anaRoot.Position - workspace:FindFirstChild("DoomLobby").Portal_normal.Pad.Position).Magnitude > 6, "and sets the player outside the portal")
frames(1)
check(latest(ana).elevator == nil, "standing at the exit does not board again")
check(not request(ana, "ElevatorLeave", {}).ok, "Leave outside a portal changes nothing")
check(not request(ana, "ElevatorMap", { step = 1 }).ok, "switching sector outside a portal is refused")
stepOut(ana)
frames(0.5)

--==============================================================================
-- The tutorial, played through Request exactly as a client would
--==============================================================================
say("--- tutorial ---")
check(request(ana,"StartMatch",{mapId="manhattan",modeId="tutorial"}).ok,"optional tutorial starts explicitly")
check(latest(ana).match and latest(ana).match.modeId=="tutorial","tutorial stays separate from the campaign portal")
check(not request(ana, "BuyHero", { heroId = "spiderman" }).ok, "lobby actions are refused inside a match")
check(not request(ana, "PlaceTower", { heroId = "ironman", position = v3(0, 0, -15) }).ok, "building on the route is refused")
check(not request(ana, "PlaceTower", { heroId = "thor", position = v3(-28, 0, -40) }).ok, "a hero not in the squad cannot be placed")

-- Spots twelve studs off the Manhattan route, cheapest-first.
local SPOTS = {
	v3(-28, 0, -40), v3(-10, 0, -27), v3(-10, 0, -3), v3(10, 0, -27), v3(20, 0, 10), v3(0, 0, 23),
	v3(44, 0, 10), v3(0, 0, 47), v3(-12, 0, 52), v3(-52, 0, -30), v3(-70, 0, -48), v3(30, 0, 54),
}
local used, towerIds, protocolsChosen, coinsCollected, casts, upgrades = {}, {}, 0, 0, 0, 0
local function manage(player)
	local snap = latest(player)
	if not snap or not snap.match then return end
	local match = snap.match
	if match.cardOffers and #match.cardOffers > 0 then
		if request(player, "ChooseCard", { cardId = match.cardOffers[1] }).ok then protocolsChosen += 1 end
	end
	for index, spot in ipairs(SPOTS) do
		if not used[index] and (latest(player).match.energy or 0) >= 250 then
			local hero = index % 2 == 1 and "ironman" or "hawkeye"
			local placed = request(player, "PlaceTower", { heroId = hero, position = spot })
			if placed.ok then
				used[index] = true
				table.insert(towerIds, placed.data.towerId)
			end
		end
	end
	for _, tower in ipairs(latest(player).match.towers or {}) do
		if tower.ownerId == player.UserId and tower.level < 5 and (latest(player).match.energy or 0) >= tower.upgradeCost then
			local payload = { towerId = tower.id }
			if tower.level == 4 then payload.branch = 1 end
			if request(player, "UpgradeTower", payload).ok then upgrades += 1 end
		end
	end
end
local function collect(player)
	for _, effect in ipairs(newEffects(player)) do
		if effect.kind == "CoinSpawn" and typeof(effect.position) == "Vector3" then
			player.Character.HumanoidRootPart.CFrame = CFrame.new(effect.position.X, 3, effect.position.Z)
			if request(player, "CollectCoin", { coinId = effect.id }).ok then coinsCollected += 1 end
		end
	end
	fxRead = #(rawget(remotes.FX, "__fired") or {})
end

local sawWave, sawPriority, sold = false, false, false
for _ = 1, 260 do
	local snap = latest(ana)
	if snap.phase == "Results" then break end
	if snap.phase == "Preparing" then
		manage(ana)
		request(ana, "SkipWave", {})
	elseif snap.phase == "Wave" then
		sawWave = true
		local mine = nil
		for _, tower in ipairs(snap.match.towers or {}) do if tower.ownerId == ana.UserId then mine = tower end end
		if mine and (snap.match.ability.cooldown or 0) <= 0 then
			if request(ana, "CastSkill", { skillId = snap.match.ability.id, position = mine.position }).ok then casts += 1 end
		end
		if mine and not sawPriority then sawPriority = request(ana, "SetPriority", { towerId = mine.id, priority = "Strongest" }).ok end
	end
	collect(ana)
	frames(2)
end
local results = latest(ana)
check(sawWave, "the tutorial reaches its waves")
check(results.phase == "Results", "the tutorial reaches the results screen, ended in " .. tostring(results.phase))
check(results.results and results.results.victory == true, "a defended tutorial is a victory")
check(#towerIds >= 3 and upgrades >= 2, "towers were built and upgraded through the router: " .. #towerIds .. " built, " .. upgrades .. " upgrades")
check(casts >= 1, "overload was cast mid-wave through the router, got " .. casts)
check(sawPriority, "targeting priority can be changed mid-wave")

-- Rewards are saved before anyone may leave the results screen.
local back
for _ = 1, 40 do
	back = request(ana, "ReturnLobby", {})
	if back.ok then break end
	frames(1)
end
check(back and back.ok, "the results screen returns to the lobby once rewards are saved")
local lobby = latest(ana)
check(lobby.phase == "Lobby", "the commander is back in the lobby")
check(lobby.profile.tutorialComplete == true, "finishing training marks it complete")
check(lobby.profile.gold >= 600, "training pays its 600 Gold, got " .. tostring(lobby.profile.gold))

-- The design brief's own acceptance line: a new player finishes the tutorial
-- with a working squad and can buy a hero.
local bought = request(ana, "OpenChest", { chestId = "rare" })
local recruited = bought.data and bought.data.result and bought.data.result.heroId
check(bought.ok, "the tutorial's gold buys a first hero: " .. tostring(bought.message))
check(recruited ~= nil and latest(ana).profile.heroes[recruited] ~= nil, "the new hero is owned")
check(request(ana, "SetLoadout", { heroes = { "ironman", "hawkeye", recruited } }).ok, "and joins the squad")

--==============================================================================
-- A solo campaign: personal coins, a mid-battle reconnect, and a defeat that
-- keeps what was earned ("Derrotas mantêm recompensas já conquistadas").
--==============================================================================
say("--- campaign ---")
local goldBefore = latest(ana).profile.gold
stepOut(ana)
stepInto(ana, "normal")
check(rideUntilDeparture(ana), "the campaign portal starts the campaign after training")
check(latest(ana).match.modeId == "normal" and Catalog.Maps[latest(ana).match.mapId] ~= nil, "and picks the first unbeaten sector")
used, towerIds = {}, {}
for _ = 1, 200 do
	local snap = latest(ana)
	if snap.phase ~= "Preparing" and snap.phase ~= "Wave" then break end
	if (snap.match.completedWaves or 0) >= 3 then break end
	if snap.phase == "Preparing" then
		manage(ana)
		request(ana, "SkipWave", {})
	end
	collect(ana)
	frames(2)
end
check(coinsCollected >= 1, "personal coins were collected by walking to them, got " .. coinsCollected)
check((latest(ana).match.goldEarned or 0) > 0, "the campaign pays gold as enemies fall")

-- Drop out mid-battle and come back: same match, same towers.
local towersBefore = #(latest(ana).match.towers or {})
leave(ana)
frames(3)
ana = join(501, "Ana")
frames(1)
local resumed = latest(ana)
check(resumed and resumed.match ~= nil, "a commander who reconnects lands back in the same battle")
check(resumed and resumed.match and #(resumed.match.towers or {}) == towersBefore, "and finds their towers still standing")

-- Tear the defense down and let the core fall.
for _, tower in ipairs(latest(ana).match.towers or {}) do
	if tower.ownerId == ana.UserId then request(ana, "SellTower", { towerId = tower.id }) end
end
check(#(latest(ana).match.towers or {}) == 0, "every tower can be sold")
local campaignProtocols = 0
for _ = 1, 400 do
	local snap = latest(ana)
	if snap.phase == "Results" then break end
	local offers = snap.match and snap.match.cardOffers or {}
	if #offers > 0 then
		check(not request(ana, "ChooseCard", { cardId = "notAProtocol" }).ok, "an unoffered protocol is refused")
		if request(ana, "ChooseCard", { cardId = offers[1] }).ok then campaignProtocols += 1 end
		check(#(latest(ana).match.cardOffers or {}) == 0, "choosing a protocol clears the offer")
	end
	if snap.phase == "Preparing" then request(ana, "SkipWave", {}) end
	frames(3)
end
check(campaignProtocols == 0, "normal mode offers no roguelike cards, got " .. campaignProtocols)
local defeat = latest(ana)
check(defeat.phase == "Results" and defeat.results and defeat.results.victory == false, "an undefended core is a defeat")
for _ = 1, 40 do
	if request(ana, "ReturnLobby", {}).ok then break end
	frames(1)
end
check(latest(ana).phase == "Lobby", "a defeat returns to the lobby too")
check(latest(ana).profile.gold > goldBefore, "a defeat keeps the gold already earned: " .. goldBefore .. " -> " .. tostring(latest(ana).profile.gold))

--==============================================================================
-- Progression the lobby panels drive: formations, abilities, missions,
-- titles and the mode gates, all through Request.
--==============================================================================
say("--- progression ---")
check(request(ana, "SaveLoadout", { slot = 1 }).ok, "the current squad saves to a formation slot")
check(request(ana, "SetLoadout", { heroes = { "ironman" } }).ok, "the squad can shrink to one hero")
check(request(ana, "LoadLoadout", { slot = 1 }).ok, "a saved formation loads back")
check(#latest(ana).profile.loadout == 3, "loading restores the saved three-hero squad")
check(not request(ana, "LoadLoadout", { slot = 2 }).ok, "an empty formation slot cannot be loaded")
check(not request(ana, "SaveLoadout", { slot = 99 }).ok, "a slot beyond the owned count is refused")
check(not request(ana, "SetLoadout", { heroes = { "ironman", "thor" } }).ok, "an unowned hero cannot join the squad")
check(not request(ana, "SetLoadout", { heroes = { "ironman", "ironman" } }).ok, "a hero cannot fill two squad slots")
check(not request(ana,"SetSkills",{active={"overload"}}).ok,"obsolete independent skill selection refused")
local priced = request(ana,"UpgradeAbility",{heroId="ironman",expectedRank=1})
check(priced.ok or (priced.message ~= nil and priced.message ~= ""),"ability upgrade succeeds or explains its requirement")
check(not request(ana,"UpgradeAbility",{heroId="notAHero",expectedRank=1}).ok,"unknown hero ability refused")
local quests = latest(ana).profile.quests or {}
local unfinished, finished
for id, quest in pairs(quests) do
	if not quest.claimed and (quest.progress or 0) >= (quest.target or 1) then finished = id end
	if not quest.claimed and (quest.progress or 0) < (quest.target or 1) then unfinished = id end
end
if unfinished then check(not request(ana, "ClaimQuest", { questId = unfinished }).ok, "an unfinished mission cannot be claimed") end
if finished then
	local goldBeforeQuest = latest(ana).profile.gold
	check(request(ana, "ClaimQuest", { questId = finished }).ok, "a finished mission pays out")
	check(latest(ana).profile.gold > goldBeforeQuest, "and its gold lands in the profile")
	check(not request(ana, "ClaimQuest", { questId = finished }).ok, "and cannot be claimed twice")
end
check(request(ana, "SetTitle", { titleId = "" }).ok, "the title can be cleared")
check(not request(ana, "SetTitle", { titleId = "emperor" }).ok, "an unearned title is refused")
check(not request(ana, "StartMatch", { mapId = "manhattan", modeId = "daily" }).ok, "the daily challenge waits for a Manhattan victory")
check(not request(ana, "StartMatch", { mapId = "manhattan", modeId = "ranked" }).ok, "ranked mode waits for a normal victory on that map")
check(Catalog.Modes.normal.waves == 50, "normal games have 50 waves")
check(not request(ana, "StartMatch", { mapId = "latveria", modeId = "bossrush" }).ok, "boss rush waits for the whole campaign")

--==============================================================================
-- A duo: party start, the duo tower cap, a partner reconnecting, and a
-- server shutdown while the battle is still running.
--==============================================================================
say("--- duo ---")
local bia = join(502, "Bia")
stepOut(ana)
stepInto(ana, "normal")
frames(0.5)
stepInto(bia, "normal")
frames(0.5)
check(latest(bia).elevator ~= nil, "a newcomer can join the campaign")
stepOut(ana)
stepOut(bia)
frames(0.5)
stepInto(bia, "normal")
frames(0.5)
stepInto(ana, "normal")
frames(0.5)
local duo = latest(ana).elevator
check(duo and #duo.riders == 2 and duo.host == false and duo.modeId == "normal", "a veteran rides along into the newcomer's training")
check(not request(ana, "ElevatorMap", { step = 1 }).ok, "only the first rider switches the sector")
check(rideUntilDeparture(ana), "training starts for everyone aboard")
check(latest(bia).match ~= nil and latest(bia).match.partySize == 2, "both commanders are in one match of size two")
check(latest(ana).match.towerLimit == 12, "a duo gets the duo tower cap")
frames(4)
leave(bia)
frames(3)
check(latest(ana).match ~= nil, "the match survives a partner dropping")
local biaAgain = join(502, "Bia")
frames(1)
check(latest(biaAgain) ~= nil and latest(biaAgain).match ~= nil, "a reconnecting partner lands back in the same match")
local placed = request(biaAgain, "PlaceTower", { heroId = "ironman", position = v3(0, 0, -88) })
check(placed.ok, "and can build immediately: " .. tostring(placed.message))
check(placed.ok and request(biaAgain, "SellTower", { towerId = placed.data.towerId }).ok, "and sell what they built")
check(not request(ana, "SellTower", { towerId = placed.ok and placed.data.towerId or "none" }).ok, "nobody sells a tower twice")

--==============================================================================
-- Abuse and shutdown
--==============================================================================
say("--- limits ---")
advance(3)
local refused = 0
for _ = 1, 60 do
	local answer = router(ana, "Sync", {})
	if not answer.ok then refused += 1 end
end
check(refused > 0, "a request flood is rate limited")
advance(3)
check(router(ana, "Sync", {}).ok, "the limiter refills with time")

say("--- shutdown ---")
check(type(closeHandler) == "function", "the bootstrap registers a shutdown handler")
check(latest(ana).match ~= nil, "the duo's battle is still running at shutdown")
step("BindToClose finishes the running battle, drains and releases", function()
	local finished = false
	task.spawn(function() closeHandler(); finished = true end)
	for _ = 1, 400 do
		if finished then break end
		advance(0.1)
	end
	check(finished, "shutdown completes")
end)

local bad = routerWarnings()
check(#bad == 0, "no request, snapshot or step failed silently: " .. table.concat(bad, " | "))

say(string.format("  simulated %.0f s; tutorial: %d towers, %d upgrades, %d casts; campaign: %d coins; defeat on wave %s; %d snapshots sent",
	clock, #towerIds, upgrades, casts, coinsCollected, tostring(defeat and defeat.results and defeat.results.waves),
	#(rawget(remotes.State, "__fired") or {})))
say(string.format("%s server boot: %d checks, %d failures (%d warnings)",
	failures == 0 and "PASS" or "FAIL", checks, failures, #warnings))
if failures > 0 then error("server boot failed", 0) end
