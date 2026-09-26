--!nonstrict
-- Server bootstrap. Owns the remote contract, the request router, the match
-- loop and place-to-place travel. Every client message is treated as an intent:
-- costs, ownership, ranges, cooldowns and rewards are decided here.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local PhysicsService = game:GetService("PhysicsService")
local HttpService = game:GetService("HttpService")

local shared = ReplicatedStorage:WaitForChild("DoomShared")
local Config = require(shared:WaitForChild("Config"))
local Catalog = require(shared:WaitForChild("Catalog"))
local Rules = require(shared:WaitForChild("Rules"))
local Waves = require(shared:WaitForChild("Waves"))

local PlayerService = require(script:WaitForChild("PlayerService"))
local Codes = require(script:WaitForChild("Codes"))
local WorldBuilder = require(script:WaitForChild("WorldBuilder"))
local MatchService = require(script:WaitForChild("MatchService"))
local PartyService = require(script:WaitForChild("PartyService"))
local PresenceService = require(script:WaitForChild("PresenceService"))
local AnalyticsService = require(script:WaitForChild("AnalyticsService"))
local RejoinService = require(script:WaitForChild("RejoinService"))
local ElevatorService = require(script:WaitForChild("ElevatorService"))

local function text(pt, en) return pt .. " / " .. en end

--==============================================================================
-- Remote contract
--==============================================================================
local function ensure(parent, className, name)
	local existing = parent:FindFirstChild(name)
	if existing then
		if existing:IsA(className) then return existing end
		existing:Destroy()
	end
	local instance = Instance.new(className)
	instance.Name = name
	instance.Parent = parent
	return instance
end

local remoteFolder = ensure(ReplicatedStorage, "Folder", "DoomRemotes")
local remotes = {
	Request = ensure(remoteFolder, "RemoteFunction", "Request"),
	State = ensure(remoteFolder, "RemoteEvent", "State"),
	FX = ensure(remoteFolder, "RemoteEvent", "FX"),
}

--==============================================================================
-- Place role
--==============================================================================
local lobbyPlaceId = math.floor(tonumber(Config.LobbyPlaceId) or 0)
local matchPlaceId = math.floor(tonumber(Config.MatchPlaceId) or 0)
local afkPlaceId = math.floor(tonumber(Config.AfkPlaceId) or 0)
-- Teleport never works in a Studio playtest, and unconfigured IDs would strand
-- players. Both cases collapse to a single self-contained server instead.
local travelEnabled = lobbyPlaceId > 0 and matchPlaceId > 0 and not RunService:IsStudio()

local role = workspace:GetAttribute("DoomRole")
if role ~= "Lobby" and role ~= "Match" and role ~= "Afk" then role = "Standalone" end
if not travelEnabled then role = "Standalone" end
-- The dedicated AFK place is optional: without its ID, AFK farming stays in
-- the lobby chambers and an "Afk" place behaves like a standalone server.
local afkTravel = travelEnabled and afkPlaceId > 0
if role == "Afk" and not afkTravel then role = "Standalone" end
print(string.format("[Doomsday] version %s starting (role=%s, travel=%s)", tostring(Config.Version), role, tostring(travelEnabled)))

pcall(function()
	if not PhysicsService:IsCollisionGroupRegistered("Commanders") then
		PhysicsService:RegisterCollisionGroup("Commanders")
	end
	PhysicsService:CollisionGroupSetCollidable("Commanders", "Commanders", false)
end)

--==============================================================================
-- Services
--==============================================================================
local pushState
local notices = {}

local function notify(player, message)
	if not message or message == "" then return end
	notices[player.UserId] = message
	if pushState then pushState(player) end
end

local refreshPresence
local profiles = PlayerService.new(Config, Catalog, function(player)
	if refreshPresence then refreshPresence(player) end
	if pushState then pushState(player) end
end, Rules, Codes)

-- The built place ships a baseplate and a spawn so the editor viewport is not
-- an empty void before anyone presses Play. The generated lobby replaces them.
for _, placeholder in ipairs({ "EditorBaseplate", "EditorSpawn" }) do
	local item = workspace:FindFirstChild(placeholder)
	if item then item:Destroy() end
end

local world = WorldBuilder.new(Catalog, function(player, panel, data)
	data = type(data) == "table" and data or {}
	remotes.FX:FireClient(player, {
		kind = "OpenPanel", panel = panel, modeId = data.modeId, heroId = data.heroId,
		chestId = data.chestId, shopKind = data.shopKind, shopKey = data.shopKey,
	})
end)

local match = MatchService.new(Config, Catalog, Rules, Waves, profiles, world, remotes, function(player)
	if pushState then pushState(player) end
end)

local party = PartyService.new(Config, function(player)
	if pushState then pushState(player) end
end)

local cosmetics = PresenceService.new()
local analytics = AnalyticsService.new(true)
local rejoin = RejoinService.new(travelEnabled, matchPlaceId)

-- What other players are allowed to see about someone: the title they equipped,
-- their level and whether they carry the VIP trail. Kept as a small cache so a
-- roster never costs a full profile copy per viewer.
local presence = {}
local sessionStart = {}
-- Set by the router just before an action that is known to move gold, so the
-- single logging site below can name the transaction instead of guessing.
local goldHint = {}

function refreshPresence(player)
	local profile = profiles:Snapshot(player)
	if not profile then
		presence[player.UserId] = nil
		goldHint[player.UserId] = nil
		return nil
	end
	local previous = presence[player.UserId]
	local label = nil
	if profile.title ~= "" and profile.titles then label = profile.titles[profile.title] end
	local vip = profile.passes ~= nil and profile.passes.vip == true
	presence[player.UserId] = {
		userId = player.UserId, name = player.Name, level = profile.level,
		title = label, vip = vip, gold = profile.gold,
	}
	-- Every gold movement is recorded here and nowhere else: this runs after the
	-- profile has actually committed, so the amount and the ending balance are
	-- both real, and no path can count the same gold twice.
	if previous then
		local delta = profile.gold - previous.gold
		if delta ~= 0 then
			local hint = goldHint[player.UserId]
			local transaction = hint and hint.transaction
				or (match:Has(player) and "Gameplay")
				or (delta > 0 and "IAP" or "Shop")
			analytics:Economy(player, delta > 0, math.abs(delta), profile.gold, transaction, hint and hint.sku or nil)
		end
	end
	goldHint[player.UserId] = nil
	cosmetics:Update(player, vip)
	return profile
end

local function rosterEntry(userId, name)
	local public = presence[userId]
	if not public then return { userId = userId, name = name } end
	return { userId = userId, name = name, level = public.level, title = public.title, vip = public.vip }
end

local function minutesPlayed(player)
	return math.floor((os.clock() - (sessionStart[player.UserId] or os.clock())) / 60)
end

local function logMatchStart()
	for _, entry in ipairs(match:Roster()) do
		local member = Players:GetPlayerByUserId(entry.userId)
		if member then
			analytics:Progression(member, match.mapId, match.modeId, "Start", 1)
			local profile = profiles:Snapshot(member)
			if profile then analytics:Composition(member, profile.loadout, match.mapId) end
			if match.modeId == "tutorial" then analytics:TutorialStep(member, 1, "Start") end
		end
	end
end

-- Closing a match releases the reserved seats and records the run. It has to
-- read results before anyone returns to the lobby and leaves the roster.
match.onFinish = function(victory)
	local seconds, mapId, modeId = match.elapsed, match.mapId, match.modeId
	for _, entry in ipairs(match:Roster()) do
		rejoin:Forget(entry.userId)
		local member = Players:GetPlayerByUserId(entry.userId)
		if member then
			local _, results = match:Snapshot(member)
			local waves = results and results.waves or match.completedWaves
			local gold = results and results.gold or 0
			analytics:MatchFinished(member, mapId, modeId, victory, waves, seconds, gold)
			-- Match Gold actually picked up per minute: how well the magnet and
			-- the collecting habit work in real play.
			local p = match.participants[member.UserId]
			if p then analytics:Custom(member, "MatchGoldPerMinute", math.floor((p.collected or 0) * 60 / math.max(1, seconds)), mapId, modeId) end
			if modeId == "tutorial" and victory then analytics:TutorialStep(member, 3, "Complete") end
		end
	end
end

--==============================================================================
-- Snapshots
--==============================================================================
local elevator

local function snapshotFor(player)
	local matchState, results = match:Snapshot(player)
	local roster
	if matchState then
		roster = {}
		for _, entry in ipairs(match:Roster()) do
			table.insert(roster, rosterEntry(entry.userId, entry.name))
		end
	else
		roster = {}
		for _, other in ipairs(Players:GetPlayers()) do
			table.insert(roster, rosterEntry(other.UserId, other.Name))
		end
	end
	local snapshot = {
		phase = matchState and match.phase or "Lobby",
		role = role,
		profile = profiles:Snapshot(player),
		players = roster,
		party = party:Snapshot(player),
		elevator = (not matchState and elevator) and elevator:Snapshot(player) or nil,
		match = matchState,
		results = results,
		notice = notices[player.UserId],
	}
	notices[player.UserId] = nil
	return snapshot
end

pushState = function(player)
	if not player or player.Parent ~= Players then return end
	local ok, snapshot = pcall(snapshotFor, player)
	if not ok then
		warn("[Doomsday] Snapshot failed for " .. player.Name .. ": " .. tostring(snapshot))
		return
	end
	remotes.State:FireClient(player, snapshot)
end

local function pushAll()
	for _, player in ipairs(Players:GetPlayers()) do pushState(player) end
end

local function pushMatch()
	for _, entry in ipairs(match:Roster()) do
		local member = Players:GetPlayerByUserId(entry.userId)
		if member then pushState(member) end
	end
end

-- A battle needs a steady stream; a lobby only needs to see other people
-- arriving, because every profile change already pushes immediately.
local function pushPeriodic(lobbyTurn)
	for _, player in ipairs(Players:GetPlayers()) do
		if lobbyTurn or match:Has(player) then pushState(player) end
	end
end

--==============================================================================
-- Travel between places
--==============================================================================
local travelling = {}

local function sendToLobby(player)
	if (role ~= "Match" and role ~= "Afk") or not travelEnabled or travelling[player.UserId] then return end
	travelling[player.UserId] = true
	task.spawn(function()
		local ok, problem = pcall(function()
			TeleportService:TeleportAsync(lobbyPlaceId, { player })
		end)
		if not ok then
			travelling[player.UserId] = nil
			warn("[Doomsday] Return teleport failed: " .. tostring(problem))
			notify(player, text("Nao foi possivel voltar ao lobby. Tentando novamente.", "Could not return to the lobby. Retrying."))
			task.delay(4, function()
				if player.Parent == Players then sendToLobby(player) end
			end)
		end
	end)
end

-- The dedicated AFK place: one reserved server per stretch. Every
-- AFK_RENEW_SECONDS the server moves the player to a fresh one; whether that
-- keeps Roblox's idle disconnect away is a hypothesis for a published test
-- (docs/PRODUCTION_STATUS.md), not a promise. Economy data never travels in
-- TeleportData: only which farm (gold or xp) the player chose.
local AFK_RENEW_SECONDS = 15 * 60
local function sendToAfk(player, kind)
	if not afkTravel or travelling[player.UserId] or not Catalog.Afk[kind] then return false end
	local reserved, code = pcall(function() return (TeleportService:ReserveServer(afkPlaceId)) end)
	if not reserved or type(code) ~= "string" then
		warn("[Doomsday] AFK ReserveServer failed: " .. tostring(code))
		analytics:Fault(player, "afk", "reserve")
		return false
	end
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = code
	options:SetTeleportData({ afkKind = kind })
	travelling[player.UserId] = true
	local ok, problem = pcall(function() TeleportService:TeleportAsync(afkPlaceId, { player }, options) end)
	if not ok then
		travelling[player.UserId] = nil
		warn("[Doomsday] AFK teleport failed: " .. tostring(problem))
		analytics:Fault(player, "afk", "teleport")
		return false
	end
	return true
end

local function sendToMatch(leader, members, mapId, modeId)
	if travelling[leader.UserId] then
		return { ok = false, message = text("Sua partida ja esta sendo preparada.", "Your match is already being prepared.") }
	end
	local reserved, accessCode = pcall(function()
		return (TeleportService:ReserveServer(matchPlaceId))
	end)
	if not reserved or type(accessCode) ~= "string" then
		warn("[Doomsday] ReserveServer failed: " .. tostring(accessCode))
		return { ok = false, message = text("Servidor de batalha indisponivel. Tente novamente.", "Battle server unavailable. Please try again.") }
	end
	local userIds = {}
	for _, member in ipairs(members) do table.insert(userIds, member.UserId) end
	local runId = HttpService:GenerateGUID(false)
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	-- The access code itself stays out of the teleport data, which the
	-- travelling player can read.
	options:SetTeleportData({
		mapId = mapId, modeId = modeId, runId = runId,
		size = #members, leaderId = leader.UserId, members = userIds,
		balanceVersion = tostring(Config.BalanceVersion),
	})
	for _, member in ipairs(members) do travelling[member.UserId] = true end
	party:SetLocked(leader, true)
	local ok, problem = pcall(function()
		TeleportService:TeleportAsync(matchPlaceId, members, options)
	end)
	if not ok then
		for _, member in ipairs(members) do travelling[member.UserId] = nil end
		party:SetLocked(leader, false)
		warn("[Doomsday] TeleportAsync failed: " .. tostring(problem))
		return { ok = false, message = text("O teleporte falhou. Nenhum progresso foi perdido.", "The teleport failed. No progress was lost.") }
	end
	rejoin:Remember(userIds, accessCode, runId)
	return { ok = true }
end

-- A player who dropped mid-battle comes back to the same reserved server for as
-- long as the battle server keeps their seat warm.
local function resumeBattle(player)
	if role ~= "Lobby" then return end
	local seat = rejoin:Lookup(player.UserId)
	if not seat or player.Parent ~= Players or travelling[player.UserId] then return end
	travelling[player.UserId] = true
	notify(player, text("Levando voce de volta a sua batalha.", "Taking you back to your battle."))
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = seat.code
	local ok, problem = pcall(function()
		TeleportService:TeleportAsync(seat.place, { player }, options)
	end)
	if not ok then
		travelling[player.UserId] = nil
		rejoin:Forget(player.UserId)
		warn("[Doomsday] Rejoin teleport failed: " .. tostring(problem))
		notify(player, text("Sua batalha anterior nao esta mais disponivel.", "Your previous battle is no longer available."))
	end
end

TeleportService.TeleportInitFailed:Connect(function(player, result, problem)
	travelling[player.UserId] = nil
	party:SetLocked(player, false)
	-- The player never arrived, so the seat recorded for them is stale.
	rejoin:Forget(player.UserId)
	warn("[Doomsday] TeleportInitFailed " .. tostring(result) .. ": " .. tostring(problem))
	notify(player, text("O teleporte falhou. Voce continua no lobby.", "The teleport failed. You are still in the lobby."))
end)

--==============================================================================
-- Match arrivals (reserved server)
--==============================================================================
local arrivals = nil

local function teleportPayload(player)
	local ok, joinData = pcall(function() return player:GetJoinData() end)
	if not ok or type(joinData) ~= "table" then return nil end
	local data = joinData.TeleportData
	if type(data) ~= "table" then return nil end
	if type(data.mapId) ~= "string" or type(data.modeId) ~= "string" then return nil end
	if not Catalog.Maps[data.mapId] or not Catalog.Modes[data.modeId] then return nil end
	return data
end

local function registerArrival(player)
	local data = teleportPayload(player)
	if not data then
		notify(player, text("Entre pelo lobby para iniciar uma defesa.", "Enter through the lobby to start a defense."))
		task.delay(3, function() if player.Parent == Players then sendToLobby(player) end end)
		return
	end
	if match:Has(player) then return end
	if match.running then
		notify(player, text("Esta batalha ja comecou.", "This battle already started."))
		task.delay(3, function() if player.Parent == Players then sendToLobby(player) end end)
		return
	end
	if not arrivals or arrivals.runId ~= data.runId then
		arrivals = {
			runId = data.runId, mapId = data.mapId, modeId = data.modeId,
			expected = math.clamp(math.floor(tonumber(data.size) or 1), 1, 4),
			waiting = {}, deadline = os.clock() + 25,
		}
	end
	if not table.find(arrivals.waiting, player.UserId) then table.insert(arrivals.waiting, player.UserId) end
end

local function beginReservedMatch()
	if not arrivals or match.running then return end
	local present = {}
	for _, userId in ipairs(arrivals.waiting) do
		local member = Players:GetPlayerByUserId(userId)
		if member and profiles:Snapshot(member) then table.insert(present, member) end
	end
	local ready = #present >= arrivals.expected or os.clock() >= arrivals.deadline
	if not ready or #present == 0 then
		if os.clock() >= arrivals.deadline and #present == 0 then arrivals = nil end
		return
	end
	local mapId, modeId, runId = arrivals.mapId, arrivals.modeId, arrivals.runId
	arrivals = nil
	-- Difficulty follows the party that actually arrived, never the size the
	-- lobby server announced.
	local ok, problem = match:Start(present, mapId, modeId, runId)
	if ok then logMatchStart() end
	if not ok then
		for _, member in ipairs(present) do
			notify(member, problem or text("Nao foi possivel iniciar a partida.", "Could not start the match."))
			sendToLobby(member)
		end
		return
	end
	pushMatch()
end

--==============================================================================
-- Request router
--==============================================================================
local MATCH_ACTIONS = {
	UpgradeBase = true, PlaceTower = true, UpgradeTower = true, SellTower = true, SetPriority = true,
	CastSkill = true, CollectCoin = true, SkipWave = true, ChooseCard = true, ReturnLobby = true,
	SetSpeed = true, SetAutoSkip = true,
}
-- Coin pickups arrive several times per second and already answer with their
-- own FX event, so they never trigger a full snapshot broadcast.
local QUIET_ACTIONS = { CollectCoin = true }
-- Actions that move gold, so the economy can be read from the funnels instead
-- of being inferred from balance snapshots.
local ECONOMY_ACTIONS = { OpenChest = "Chest", UpgradeAbility = "Upgrade", ClaimQuest = "Gameplay" }
local tutorialTower = {}

local function startMatch(player, payload)
	local mapId, modeId = payload.mapId, payload.modeId
	if payload.destinationId then
		local destination = type(payload.destinationId)=="string" and Catalog.Destinations[payload.destinationId]
		if not destination then return {ok=false,message=text("Destino inválido.","Invalid destination.")} end
		mapId,modeId=destination.mapId,destination.modeId
	end
	if type(mapId) ~= "string" or not Catalog.Maps[mapId] or type(modeId) ~= "string" or not Catalog.Modes[modeId] then
		return { ok = false, message = text("Mapa ou modo invalido.", "Invalid map or mode.") }
	end
	if match:Has(player) then
		return { ok = false, message = text("Voce ja esta em uma partida.", "You are already in a match.") }
	end
	if travelling[player.UserId] then
		return { ok = false, message = text("Preparando sua partida...", "Preparing your match...") }
	end
	if not party:IsLeader(player) then
		return { ok = false, message = text("Apenas o lider inicia a defesa.", "Only the party leader starts the defense.") }
	end
	local members = party:Members(player)
	for _, member in ipairs(members) do
		local profile = profiles:Snapshot(member)
		if not profile then
			return { ok = false, message = text("Aguarde o perfil de " .. member.Name .. ".", "Waiting for the profile of " .. member.Name .. ".") }
		end
		local allowed, reason = Rules.CanStart(profile, mapId, modeId)
		if not allowed then
			return { ok = false, message = reason or text("Requisito nao cumprido.", "Requirement not met.") }
		end
	end
	if role == "Lobby" then
		return sendToMatch(player, members, mapId, modeId)
	end
	if not match:CanStart() then
		return { ok = false, message = text("Uma partida ja ocupa este servidor.", "A match is already using this server.") }
	end
	local ok, problem = match:Start(members, mapId, modeId)
	if not ok then return { ok = false, message = problem } end
	logMatchStart()
	pushMatch()
	return { ok = true }
end

-- Mode portals are elevators: stepping onto a pad boards it and the match
-- starts when its countdown ends. In a Lobby server that means travel to a
-- reserved match server; anywhere else the match starts right here.
local function launchFromPortal(members, mapId, modeId)
	if role == "Lobby" then
		local result = sendToMatch(members[1], members, mapId, modeId)
		return result.ok == true, result.message
	end
	if not match:CanStart() then
		return false, text("Uma batalha ja ocupa este servidor. Aguarde ela terminar.", "A battle is already using this server. Wait for it to end.")
	end
	local ok, problem = match:Start(members, mapId, modeId)
	if not ok then return false, problem end
	logMatchStart()
	pushMatch()
	return true
end

elevator = ElevatorService.new({
	rules = Rules,
	profileOf = function(player) return profiles:Snapshot(player) end,
	zones = world.portalZones,
	launch = launchFromPortal,
	notify = notify,
	changed = function(player) if pushState then pushState(player) end end,
	eject = function(player, position)
		local character = player.Character
		if character then pcall(function() character:PivotTo(CFrame.new(position)) end) end
	end,
	available = function(player) return not match:Has(player) and not travelling[player.UserId] end,
})

local function route(player, action, payload)
	if action == "Sync" then
		return { ok = true, data = snapshotFor(player) }
	end
	local inMatch = match:Has(player)
	if inMatch and MATCH_ACTIONS[action] then
		local ok, data = match:Handle(player, action, payload)
		if ok == true and action == "ReturnLobby" then
			rejoin:Forget(player.UserId)
			sendToLobby(player)
		end
		if ok == true and action == "PlaceTower" and match.modeId == "tutorial" and not tutorialTower[player.UserId] then
			tutorialTower[player.UserId] = true
			analytics:TutorialStep(player, 2, "FirstTower")
		end
		if not QUIET_ACTIONS[action] then
			pushMatch()
			if not match:Has(player) then pushState(player) end
		end
		return {
			ok = ok == true,
			data = type(data) == "table" and data or nil,
			message = ok ~= true and tostring(data) or nil,
		}
	end
	local flow = ECONOMY_ACTIONS[action]
	if flow then
		goldHint[player.UserId] = { transaction = flow, sku = payload.chestId or payload.heroId or payload.questId }
	end
	local handled, ok, data = profiles:Handle(player, action, payload, not inMatch)
	goldHint[player.UserId] = nil
	if handled then
		if not ok then return { ok = false, message = tostring(data) } end
		if type(data) == "table" and type(data.gold) == "number" then
			local result = data.result
			if action == "OpenChest" and type(result) == "table" then
				analytics:Custom(player, "ChestOpened", result.cost, result.chestId, result.rarity, result.heroId)
				if not result.duplicate and result.heroId then
					analytics:HeroUnlocked(player, tostring(result.heroId), data.level, minutesPlayed(player))
				end
			elseif action == "UpgradeAbility" and type(result) == "table" then
				analytics:Custom(player, "AbilityUpgraded", result.rank, result.heroId, result.cost)
			elseif action == "SetLoadout" then
				analytics:Composition(player, data.loadout)
			end
		end
		return { ok = true, data = data }
	end
	if action == "StartMatch" then return startMatch(player, payload) end
	if action == "ElevatorLeave" then
		return { ok = elevator:Leave(player) }
	end
	if action == "EnterAfkServer" then
		-- From a lobby AFK chamber to the dedicated AFK place.
		local kind = world:AfkZoneOf(player)
		if role ~= "Lobby" or not afkTravel or not kind then return { ok = false, message = text("Servidor AFK indisponível.", "AFK server unavailable.") } end
		return { ok = sendToAfk(player, kind), message = text("Não foi possível ir ao servidor AFK. Tente de novo.", "Could not reach the AFK server. Try again.") }
	end
	if action == "LeaveAfk" and role == "Afk" then
		sendToLobby(player)
		return { ok = true }
	end
	if action == "LeaveAfk" then
		-- Out of the farm chamber, onto the plaza side of it.
		local kind = world:AfkZoneOf(player)
		local farm = kind and Catalog.Afk[kind]
		local character = player.Character
		if not farm or not character then return { ok = false } end
		pcall(function() character:PivotTo(CFrame.new(farm.x + 16, 4, farm.z)) end)
		return { ok = true }
	end
	if action == "ElevatorStart" then
		return { ok = elevator:StartNow(player), message = text("Só quem entrou primeiro pode começar.", "Only the first rider can start.") }
	end
	if action == "CreateParty" then
		if match:Has(player) then return { ok = false, message = text("Termine a partida primeiro.", "Finish the match first.") } end
		local created, message = party:Create(player)
		return { ok = created, message = message }
	end
	if action == "JoinParty" then
		if match:Has(player) then return { ok = false, message = text("Termine a partida primeiro.", "Finish the match first.") } end
		local joined, message = party:Join(player, payload.code)
		return { ok = joined, message = message }
	end
	if action == "LeaveParty" then
		party:Leave(player)
		return { ok = true }
	end
	if action == "ReturnLobby" then
		sendToLobby(player)
		return { ok = true }
	end
	if MATCH_ACTIONS[action] then
		return { ok = false, message = text("Esta acao so funciona durante uma partida.", "This action only works during a match.") }
	end
	return { ok = false, message = text("Acao desconhecida.", "Unknown action.") }
end

-- A token bucket keeps a scripted client from turning the router into a
-- DataStore amplifier, while leaving room for rapid coin pickups.
local buckets = {}
local function allow(player)
	local bucket = buckets[player.UserId]
	local now = os.clock()
	if not bucket then
		bucket = { tokens = 40, at = now }
		buckets[player.UserId] = bucket
	end
	bucket.tokens = math.min(40, bucket.tokens + (now - bucket.at) * 22)
	bucket.at = now
	if bucket.tokens < 1 then return false end
	bucket.tokens -= 1
	return true
end

remotes.Request.OnServerInvoke = function(player, action, payload)
	if type(action) ~= "string" or #action > 40 then
		return { ok = false, message = text("Acao invalida.", "Invalid action.") }
	end
	if payload ~= nil and type(payload) ~= "table" then
		return { ok = false, message = text("Dados invalidos.", "Invalid data.") }
	end
	if not allow(player) then
		return { ok = false, message = text("Muitas acoes em pouco tempo.", "Too many actions at once.") }
	end
	local ok, result = pcall(route, player, action, payload or {})
	if not ok then
		warn("[Doomsday] Request " .. action .. " failed: " .. tostring(result))
		return { ok = false, message = text("Erro interno. Nada foi alterado.", "Internal error. Nothing changed.") }
	end
	if type(result) ~= "table" then
		return { ok = false, message = text("Resposta invalida.", "Invalid response.") }
	end
	return result
end

--==============================================================================
-- Player lifecycle
--==============================================================================
local function placeCharacter(player)
	if not player.Character then return end
	world:MovePlayer(player, match:Has(player), match:Index(player))
end

local joined = {}

local function onPlayerAdded(player)
	if joined[player.UserId] then return end
	joined[player.UserId] = true
	sessionStart[player.UserId] = os.clock()
	cosmetics:Bind(player)
	player.CharacterAdded:Connect(function()
		task.defer(placeCharacter, player)
	end)
	local profile, failure
	for attempt = 1, 4 do
		profile, failure = profiles:Load(player)
		if profile or player.Parent ~= Players then break end
		notify(player, failure)
		task.wait(1.5 * attempt)
	end
	if player.Parent ~= Players then return end
	if not profile then
		notify(player, failure or text("Perfil indisponivel. Nenhum dado foi alterado.", "Profile unavailable. No data was changed."))
		return
	end
	refreshPresence(player)
	if match:Reconnect(player) then
		rejoin:Extend(player.UserId)
	elseif role == "Match" then
		registerArrival(player)
	elseif role == "Lobby" then
		task.spawn(resumeBattle, player)
	end
	placeCharacter(player)
	pushAll()
end

Players.PlayerAdded:Connect(function(player)
	local ok, problem = pcall(onPlayerAdded, player)
	if not ok then warn("[Doomsday] Join failed for " .. player.Name .. ": " .. tostring(problem)) end
end)

Players.PlayerRemoving:Connect(function(player)
	local wasPlaying = match:Has(player)
	-- Leaving mid-battle, by wave: the abandonment curve the launch plan asks for.
	if wasPlaying and match.running then
		pcall(function() analytics:Custom(player, "LeftMidMatch", match.wave or 0, match.mapId, match.modeId) end)
	end
	pcall(function() match:OnLeave(player) end)
	pcall(function() party:Remove(player) end)
	pcall(function() cosmetics:Release(player) end)
	-- A live participant keeps their seat for the reconnect window; anyone else
	-- releases it immediately.
	if wasPlaying and match.running then
		rejoin:Hold(player.UserId, (tonumber(Config.ReconnectSeconds) or 120) + 20)
	elseif role == "Match" then
		rejoin:Forget(player.UserId)
	end
	presence[player.UserId] = nil
	sessionStart[player.UserId] = nil
	tutorialTower[player.UserId] = nil
	joined[player.UserId] = nil
	buckets[player.UserId] = nil
	notices[player.UserId] = nil
	travelling[player.UserId] = nil
	pcall(function() profiles:Release(player) end)
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(function()
		local ok, problem = pcall(onPlayerAdded, player)
		if not ok then warn("[Doomsday] Late join failed: " .. tostring(problem)) end
	end)
end

--==============================================================================
-- Loops
--==============================================================================
local step = math.clamp(tonumber(Config.SimulationStep) or 0.1, 1 / 60, 0.25)
local snapshotInterval = math.max(0.2, tonumber(Config.SnapshotInterval) or 0.5)
local accumulator, snapshotTimer, arrivalTimer, snapshotCycle, elevatorTimer = 0, 0, 0, 0, 0

-- AFK farm: the server watches each lobby visitor's position and pays one
-- minute at a time to whoever stood in a farm chamber all minute. Stepping out
-- resets the clock. The client is only told (through player attributes) which
-- farm it is in and how long until the next payout, to draw its banner.
local afkClock = {}
local parkourSeen = {}
if role == "Afk" then
	local function arrived(player)
		local ok, join = pcall(function() return player:GetJoinData() end)
		local data = ok and type(join) == "table" and join.TeleportData or nil
		local kind = type(data) == "table" and Catalog.Afk[data.afkKind] and data.afkKind or "gold"
		player:SetAttribute("AfkServer", kind)
	end
	Players.PlayerAdded:Connect(arrived)
	for _, player in ipairs(Players:GetPlayers()) do arrived(player) end
end
local function stepAfk(elapsed, visitors)
	local interval = Catalog.Afk.interval
	local inLobby = {}
	for _, player in ipairs(visitors) do
		inLobby[player] = true
		local kind = world:AfkZoneOf(player) or (role == "Afk" and player:GetAttribute("AfkServer")) or nil
		if role == "Lobby" and player:GetAttribute("AfkTravel") ~= afkTravel then player:SetAttribute("AfkTravel", afkTravel) end
		local clock = afkClock[player.UserId]
		if kind then
			if not clock or clock.kind ~= kind then
				clock = { kind = kind, seconds = 0, minutes = 0, earned = 0, session = 0,
					sessionId = "afk:" .. kind .. ":" .. tostring(player.UserId) .. ":" .. HttpService:GenerateGUID(false) }
				afkClock[player.UserId] = clock
			end
			-- The clock stops at a full minute until that minute is confirmed as
			-- saved: a failed save is retried, never skipped or paid twice
			-- (each minute has its own award id, so a retry is idempotent).
			if not clock.paying then clock.seconds = math.min(interval, clock.seconds + elapsed) end
			clock.session = (clock.session or 0) + elapsed
			if clock.seconds >= interval and not clock.paying then
				clock.paying = true
				local minute = (clock.minutes or 0) + 1
				task.spawn(function()
					local ok = profiles:GrantAfk(player, kind, 1, (clock.sessionId or "afk") .. ":" .. minute)
					clock.paying = false
					if ok then
						clock.seconds, clock.minutes = 0, minute
						local reward = Rules.AfkReward(kind, 1)
						clock.earned = (clock.earned or 0) + (reward and (reward.gold + reward.xp) or 0)
					else
						warn("[Doomsday] AFK payout failed for " .. tostring(player.UserId) .. "; retrying")
					end
				end)
			end
			-- On the AFK place, hop to a fresh server before idling too long.
			if role == "Afk" and clock.session >= AFK_RENEW_SECONDS and not clock.paying and not clock.renewing then
				clock.renewing = true
				task.spawn(function()
					if not sendToAfk(player, kind) then task.delay(60, function() clock.renewing = false end) end
				end)
			end
			player:SetAttribute("AfkZone", kind)
			player:SetAttribute("AfkNext", math.max(0, math.ceil(interval - clock.seconds)))
			player:SetAttribute("AfkSession", math.floor(clock.session))
			player:SetAttribute("AfkEarned", clock.earned or 0)
			player:SetAttribute("AfkSaving", clock.paying == true)
		else
			if clock and (clock.minutes or 0) > 0 then
				pcall(function() analytics:Custom(player, "AfkSession", clock.minutes, clock.kind) end)
			end
			afkClock[player.UserId] = nil
		end
	end
	for _, player in ipairs(Players:GetPlayers()) do
		if not inLobby[player] or not afkClock[player.UserId] then
			if not inLobby[player] then afkClock[player.UserId] = nil end
			if player:GetAttribute("AfkZone") ~= nil then
				for _, key in ipairs({ "AfkZone", "AfkNext", "AfkSession", "AfkEarned", "AfkSaving" }) do player:SetAttribute(key, nil) end
			end
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	-- 2x speed is match time running twice as fast as the frame clock; the
	-- six-tick cap still bounds the work done in any one frame.
	accumulator += math.min(dt, 0.5) * match:Speed()
	local ticks = 0
	while accumulator >= step and ticks < 6 do
		accumulator -= step
		ticks += 1
		local ok, problem = pcall(match.Step, match, step)
		if not ok then warn("[Doomsday] Match step failed: " .. tostring(problem)) end
	end
	if ticks >= 6 then accumulator = 0 end

	if role ~= "Match" then
		elevatorTimer += dt
		if elevatorTimer >= 0.25 then
			local elapsed = elevatorTimer
			elevatorTimer = 0
			local ok, problem = pcall(elevator.Step, elevator, elapsed, Players:GetPlayers())
			if not ok then warn("[Doomsday] Elevator step failed: " .. tostring(problem)) end
			local visitors={}
			for _,player in ipairs(Players:GetPlayers()) do
				if profiles:Get(player) and not match:Has(player) and not travelling[player.UserId] then table.insert(visitors,player) end
			end
			local shopOK,shopProblem=pcall(world.StepShopEntries,world,visitors)
			if not shopOK then warn("[Doomsday] Shop entry failed: "..tostring(shopProblem)) end
			local recoveryOK,recoveryProblem=pcall(world.RecoverLobbyVisitors,world,visitors)
			if not recoveryOK then warn("[Doomsday] Lobby recovery failed: "..tostring(recoveryProblem)) end
			-- The optional parkour: the server notices a visitor on the last stone
			-- and grants its cosmetic title once (no Gold, not repeatable).
			for _,visitor in ipairs(visitors) do
				if not parkourSeen[visitor.UserId] and world:ParkourReached(visitor) then
					parkourSeen[visitor.UserId]=true
					task.spawn(function()
						local ok,result=profiles:GrantCosmetic(visitor,"parkour")
						if ok and result and result.fresh then notify(visitor,"CONQUISTA • Explorador da Aurora (novo título!) / ACHIEVEMENT • Aurora explorer (new title!)") end
					end)
				end
			end
			local afkOK,afkProblem=pcall(stepAfk,elapsed,visitors)
			if not afkOK then warn("[Doomsday] AFK farm step failed: "..tostring(afkProblem)) end
		end
	end

	if role == "Match" then
		arrivalTimer += dt
		if arrivalTimer >= 1 then
			arrivalTimer = 0
			local ok, problem = pcall(beginReservedMatch)
			if not ok then warn("[Doomsday] Reserved start failed: " .. tostring(problem)) end
		end
	end

	snapshotTimer += dt
	if snapshotTimer >= snapshotInterval then
		snapshotTimer = 0
		snapshotCycle = (snapshotCycle + 1) % 4
		pushPeriodic(snapshotCycle == 0)
	end
end)

-- The hall-of-fame totem is shared scenery: one public leaderboard, refreshed
-- on a slow timer rather than per viewer. Match-role servers never show it to
-- anyone, so they skip the DataStore read entirely.
if role ~= "Match" then
	task.spawn(function()
		-- First pass runs right away: waiting a full cycle left the totem
		-- reading "Carregando…" for the first half minute of every server.
		while true do
			local ok, rows = pcall(function() return profiles:Leaderboard("hydra", 1, nil, "ranked") end)
			if ok then
				local applied = pcall(function() world:UpdateLeaderboardBoard(rows, "RANQUEADO • " .. Catalog.Maps.hydra.name.pt) end)
				if not applied then warn("[Doomsday] Leaderboard totem refresh failed") end
			end
			-- The arena's season board: one solo column per ranked map.
			local boards = {}
			for _, mapId in ipairs(Rules.MapsForMode("ranked")) do
				local found, mapRows = pcall(function() return profiles:Leaderboard(mapId, 1, nil, "ranked") end)
				if found and mapRows then boards[mapId] = mapRows end
			end
			local shown = pcall(function() world:UpdateArenaScoreboard(boards) end)
			if not shown then warn("[Doomsday] Arena scoreboard refresh failed") end
			task.wait(30)
		end
	end)
end

--==============================================================================
-- Shutdown
--==============================================================================
game:BindToClose(function()
	if match.running then
		-- Gold already earned survives through the checkpoint ledger, even
		-- though the battle itself cannot be restored on a new server.
		pcall(function() match:Finish(false) end)
	end
	-- BindToClose allows roughly 30s in total, and PlayerService:Shutdown
	-- spends up to 25 of them releasing leases.
	pcall(function() match:Drain(5) end)
	profiles:Shutdown()
end)
