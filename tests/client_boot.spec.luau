--!nonstrict
-- Executed by test_client_boot.py, which inlines the real client, shared and
-- world modules.
--
-- Until this ran, the client was only ever compiled: 1,100 lines of HUD,
-- panels and effects that no test executed, where a single nil index would
-- sail past every other suite and break the game on the first frame. This
-- boots init.client for real against Roblox stand-ins, drives it through
-- lobby, match and results on several real screen sizes, presses its
-- buttons, fires every FX event it handles, and fails on any Lua error.
local Stubs = __STUBS__
local v3 = Stubs.v3
local newSignal = Stubs.newSignal
local services = Stubs.services

local checks, failures = 0, 0
local function check(condition, label)
	checks += 1
	if not condition then
		failures += 1
		print("FAIL: " .. label)
	end
end

--==============================================================================
-- Scheduler: delays queue up and run when the test flushes, like frames do
--==============================================================================
local queued = {}
task = {
	spawn = function(fn, ...) fn(...) end,
	defer = function(fn, ...) table.insert(queued, { fn, { ... } }) end,
	delay = function(_, fn, ...) table.insert(queued, { fn, { ... } }) end,
	wait = function() return 0 end,
}
local now = 1000
local clockOs = setmetatable({ clock = function() return now end }, { __index = os })
local function advance(seconds) now += seconds end

local function flush()
	for _ = 1, 6 do
		local batch = queued
		queued = {}
		if #batch == 0 then return end
		for _, job in ipairs(batch) do job[1](table.unpack(job[2])) end
	end
end

--==============================================================================
-- Screen: every Frame reports the usable screen as its absolute size, which
-- is what the client reads from its full-screen root frame.
--==============================================================================
local SCREEN = { w = 1280, h = 662 }
local baseNew = Instance.new
Instance = { new = function(className, parent)
	local created = baseNew(className, parent)
	if className == "Frame" then created.AbsoluteSize = Vector2.new(SCREEN.w, SCREEN.h) end
	return created
end }

--==============================================================================
-- Module system: ModuleScript stand-ins resolved through require()
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

local replicated = services.ReplicatedStorage
local shared = Instance.new("Folder")
shared.Name, shared.Parent = "DoomShared", replicated
moduleScript(shared, "Catalog", __CATALOG__)
moduleScript(shared, "Config", __CONFIG__)
moduleScript(shared, "Rules", __RULES__)
local Catalog = require(shared.Catalog)
local Rules = require(shared.Rules)
local SharedConfig = require(shared.Config)
local UILayout = __UI__(nil, clockOs)
local WorldBuilder = __WORLD__(nil, clockOs)
local CLIENT_MODULES = __CLIENT_MODULES__

--==============================================================================
-- Fixtures
--==============================================================================
local LOCAL_ID, ALLY_ID = 1001, 2002

-- A realistic rewards status, shaped like Rules.RewardsStatus's real output.
-- "ready" (the default) has a free chest, day three of the login streak, one
-- playtime gift and one collection milestone all waiting; "empty" has none.
local function rewardsFixture(mode)
	local ready = mode ~= "empty"
	local fixture = {
		claimable = ready and 3 or 0,
		freeChest = { ready = ready, remaining = ready and 0 or 3600, chestId = "rare", cooldown = Catalog.Rewards.freeChest.cooldown },
		login = { claimable = ready, streak = 2, cycle = #Catalog.Rewards.login, nextIndex = 3, nextStreak = 3 },
		playtime = { seconds = ready and 700 or 60, gifts = {} },
		collection = { owned = 5, milestones = {} },
	}
	for index, def in ipairs(Catalog.Rewards.playtime) do
		table.insert(fixture.playtime.gifts, { index = index, minutes = def.minutes, gold = def.gold, xp = def.xp, chest = def.chest,
			claimed = ready and index == 1, ready = ready and index == 2 })
	end
	for index, def in ipairs(Catalog.Rewards.collection) do
		table.insert(fixture.collection.milestones, { index = index, count = def.count, gold = def.gold, title = def.title,
			claimed = false, ready = ready and def.count <= 5 })
	end
	return fixture
end

local function veteranProfile(overrides)
	local profile = {
		gold = 2500, xp = 1200, level = 7,
		heroes = { ironman = { xp = 300, level = 3, stars = 2, shiny = true }, hawkeye = { xp = 50, level = 1 }, spiderman = { xp = 0, level = 1 } },
		loadout = { "ironman", "hawkeye" },
		abilities = { ironman = 1, hawkeye = 1, spiderman = 1 }, talents = {}, pity = {},
		activeSkills = { "overload", "scan" }, passives = { "magnet" },
		campaign = { manhattan = { normal = true } }, tutorialComplete = true,
		passes = { vip = true, collector = true },
		settings = { language = "pt", lowFX = false, shake = true, music = true },
		savedLoadouts = { ["1"] = { heroes = { "ironman" } } },
		quests = { daily1 = { name = { pt = "Defensor", en = "Defender" }, description = { pt = "Vença ondas", en = "Clear waves" }, progress = 5, target = 5, gold = 100, xp = 50 } },
		achievements = { a1 = { name = { pt = "Primeira vitória", en = "First win" } } },
		titles = { t1 = { pt = "Veterano", en = "Veteran" } }, title = "t1",
		best = {}, season = 1, skillSlots = { active = 2, passive = 2 }, rewards = rewardsFixture("empty"),
	}
	for key, value in pairs(overrides or {}) do profile[key] = value end
	return profile
end

local function newcomerProfile()
	return veteranProfile({
		gold = 0, xp = 0, level = 1, heroes = { ironman = { xp = 0, level = 1 }, hawkeye = { xp = 0, level = 1 } },
		loadout = { "ironman", "hawkeye" }, skills = { overload = 1, magnet = 1 }, activeSkills = { "overload" },
		passives = { "magnet" }, campaign = {}, tutorialComplete = false, passes = {}, quests = {}, achievements = {},
		titles = {}, title = "", savedLoadouts = {},
	})
end

local function lobbySnapshot(profile)
	return {
		phase = "Lobby", role = "Standalone", profile = profile,
		players = { { userId = LOCAL_ID, name = "Tester", level = profile.level }, { userId = ALLY_ID, name = "Ally", level = 4 } },
		party = { code = "AB23", leaderId = LOCAL_ID, members = { { userId = LOCAL_ID, name = "Tester" }, { userId = ALLY_ID, name = "Ally" } }, locked = false, maxSize = 4 },
	}
end

local function towers()
	return {
		{ id = "t1", heroId = "ironman", ownerId = LOCAL_ID, level = 2, position = v3(10, 0, 10), priority = "First", damage = 26, range = 28.8, rate = 1.2, upgradeCost = 350, invested = 475,
			base = { damage = 26, range = 28.8, rate = 1.2 }, next = { damage = 37.7, range = 30.6, rate = 1.25 } },
		{ id = "t2", heroId = "hawkeye", ownerId = LOCAL_ID, level = 4, position = v3(-20, 0, 5), priority = "Strongest", damage = 60, range = 40, rate = 0.7, upgradeCost = 630, invested = 1000,
			base = { damage = 60, range = 40, rate = 0.7 }, branches = { { damage = 96, range = 42, rate = 0.75 }, { damage = 81, range = 50, rate = 0.9 } } },
		{ id = "t3", heroId = "ironman", ownerId = LOCAL_ID, level = 5, branch = 2, position = v3(30, 0, -10), priority = "Last", damage = 120, range = 33, rate = 1.3, upgradeCost = 0, invested = 2000 },
		{ id = "t4", heroId = "spiderman", ownerId = ALLY_ID, level = 1, position = v3(0, 0, 40), priority = "First", damage = 10, range = 24, rate = 0.9, upgradeCost = 252, invested = 280 },
	}
end

local function matchSnapshot(profile, phase, extra)
	local match = {
		runId = "run", mapId = "manhattan", modeId = "normal", wave = 3, totalWaves = 50, completedWaves = 2,
		baseHP = 86, maxBaseHP = 100, shield = 0, cash = 940, coinsWaiting = 60, towerLimit = 16, prepRemaining = 9, enemies = 0, elapsed = 120,
		ability = {id = Catalog.Heroes.ironman.ability, heroId = "ironman", rank = 1, target = "area", cooldown = 0, cooldownTotal = 60, radius = 20}, cardOffers = {}, cards = {}, goldEarned = 150, xpEarned = 40,
		partySize = 2, skipVotes = 1, threats = { "runner", "flyer" }, towers = towers(),
	}
	for key, value in pairs(extra or {}) do match[key] = value end
	return {
		phase = phase, role = "Standalone", profile = profile, match = match,
		players = { { userId = LOCAL_ID, name = "Tester", level = profile.level }, { userId = ALLY_ID, name = "Ally", level = 4 } },
	}
end

local function resultsSnapshot(profile)
	return {
		phase = "Results", role = "Standalone", profile = profile,
		results = { victory = true, waves = 50, gold = 1500, xp = 300, mapId = "manhattan", modeId = "normal", mastery = { ironman = 120, hawkeye = 40 },
			team = { { userId = ALLY_ID, name = "Ally", damage = 52000, kills = 340, gold = 2100 }, { userId = LOCAL_ID, name = "Tester", damage = 31000, kills = 210, gold = 1800 } } },
		players = { { userId = LOCAL_ID, name = "Tester", level = profile.level } },
	}
end

--==============================================================================
-- GUI helpers
--==============================================================================
local function shown(item, root)
	while item and item ~= root do
		if item.Visible == false then return false end
		item = item.Parent
	end
	return true
end

local function findButton(root, prefix)
	for _, item in ipairs(root:GetDescendants()) do
		if rawget(item, "__class") == "TextButton" and type(item.Text) == "string"
			and string.sub(item.Text, 1, #prefix) == prefix and shown(item, root) then
			return item
		end
	end
	return nil
end

local function frameAt(parent, r)
	for _, child in ipairs(parent:GetChildren()) do
		local p, s = child.Position, child.Size
		if type(p) == "table" and type(s) == "table" and p.X and s.X and p.X.Offset == r.x and p.Y.Offset == r.y
			and s.X.Offset == r.w and s.Y.Offset == r.h then
			return child
		end
	end
	return nil
end

local function named(root, name)
	for _, item in ipairs(root:GetDescendants()) do if item.Name == name then return item end end
	return nil
end

-- Resolve fixed HUD geometry independently of the stand-ins' AbsoluteSize.
-- They intentionally give every Frame the screen size, so reading that fake
-- value cannot prove a results footer remains reachable without scrolling.
local function screenRect(item, root, screen)
	if item == root then return {x = 0, y = 0, w = screen.w, h = screen.h} end
	if not item or not item.Parent then return nil end
	local parent = screenRect(item.Parent, root, screen)
	if not parent then return nil end
	local size, position = item.Size or UDim2.new(), item.Position or UDim2.new()
	local width = parent.w * size.X.Scale + size.X.Offset
	local height = parent.h * size.Y.Scale + size.Y.Offset
	for _, child in ipairs(item:GetChildren()) do
		if rawget(child, "__class") == "UISizeConstraint" then
			if child.MaxSize then width = math.min(width, child.MaxSize.X); height = math.min(height, child.MaxSize.Y) end
			if child.MinSize then width = math.max(width, child.MinSize.X); height = math.max(height, child.MinSize.Y) end
		end
	end
	local anchor = item.AnchorPoint or Vector2.new(0, 0)
	return {x = parent.x + parent.w * position.X.Scale + position.X.Offset - width * anchor.X,
		y = parent.y + parent.h * position.Y.Scale + position.Y.Offset - height * anchor.Y, w = width, h = height}
end

-- Every HUD element placed in absolute pixels must be on screen, shown or not.
local function offscreen(root, screen)
	local bad = {}
	for _, child in ipairs(root:GetChildren()) do
		local p, s = child.Position, child.Size
		if type(p) == "table" and type(s) == "table" and p.X and s.X and child.AnchorPoint == nil
			and p.X.Scale == 0 and p.Y.Scale == 0 and s.X.Scale == 0 and s.Y.Scale == 0 then
			if p.X.Offset < 0 or p.Y.Offset < 0 or p.X.Offset + s.X.Offset > screen.w or p.Y.Offset + s.Y.Offset > screen.h then
				table.insert(bad, string.format("%s(%d,%d %dx%d)", tostring(child.Name), p.X.Offset, p.Y.Offset, s.X.Offset, s.Y.Offset))
			end
		end
	end
	return bad
end

local function textOf(root)
	local parts = {}
	for _, item in ipairs(root:GetDescendants()) do
		if type(item.Text) == "string" and item.Text ~= "" then table.insert(parts, item.Text) end
	end
	return table.concat(parts, " ")
end

local function countNamed(root, name)
	local total = 0
	for _, item in ipairs(root:GetDescendants()) do if item.Name == name then total += 1 end end
	return total
end

--==============================================================================
-- One full client session
--==============================================================================
local function session(screen)
	SCREEN.w, SCREEN.h = screen.w, screen.h
	local tag = string.format("%s %dx%d", screen.name, screen.w, screen.h)
	local function step(name, fn)
		local ok, problem = xpcall(fn, debug.traceback)
		check(ok, tag .. ": " .. name .. " ran without a Lua error: " .. tostring(problem))
		return ok
	end

	-- Fresh engine services for this session, so nothing connected by a
	-- previous session keeps firing.
	for _, name in ipairs({ "DoomLobby", "DoomWorld", "DoomClientVisuals" }) do
		local old = workspace:FindFirstChild(name)
		while old do old:Destroy(); old = workspace:FindFirstChild(name) end
	end
	local runService = { RenderStepped = newSignal(), Heartbeat = newSignal(), binds = {} }
	function runService:BindToRenderStep(name, _, fn) self.binds[name] = fn end
	function runService:IsStudio() return true end
	function runService:IsServer() return false end
	local input = { InputBegan = newSignal(), InputEnded = newSignal(), JumpRequest = newSignal(), TouchTapInWorld = newSignal(), TouchLongPress = newSignal(), TouchEnabled = false }
	function input:GetFocusedTextBox() return self.focused end
	function input:GetMouseLocation() return Vector2.new(SCREEN.w / 2, SCREEN.h / 2) end
	local guiService = {}
	function guiService:GetGuiInset() return Vector2.new(0, 58), Vector2.new(0, 0) end
	local prompts = {}
	local market = {
		PromptGamePassPurchase = function(_, _, id) table.insert(prompts, "pass:" .. tostring(id)) end,
		PromptProductPurchase = function(_, _, id) table.insert(prompts, "product:" .. tostring(id)) end,
	}
	services.RunService, services.UserInputService, services.GuiService = runService, input, guiService
	-- Context actions: the bound handlers and button titles are kept so a test can press them.
	local contextActions = { handlers = {}, titles = {} }
	function contextActions:BindAction(name, handler) self.handlers[name] = handler end
	function contextActions:SetTitle(name, title) self.titles[name] = title end
	function contextActions:UnbindAction(name) self.handlers[name] = nil end
	services.ContextActionService = contextActions
	services.TweenService = { Create = function() return { Play = function() end, Cancel = function() end } end }
	services.MarketplaceService = market

	local camera = Instance.new("Camera")
	camera.ViewportSize = Vector2.new(SCREEN.w, SCREEN.h + 58)
	camera.CFrame = CFrame.new(0, 80, 60)
	camera.ScreenPointToRay = function() return { Origin = v3(0, 80, 60), Direction = v3(0, -1, 0) } end
	workspace.CurrentCamera = camera
	local rayHit = nil
	workspace.Raycast = function() return rayHit end

	local localPlayer = Instance.new("Player")
	localPlayer.UserId, localPlayer.Name = LOCAL_ID, "Tester"
	local playerGui = Instance.new("PlayerGui")
	playerGui.Name, playerGui.Parent = "PlayerGui", localPlayer
	local character = Instance.new("Model")
	local root = Instance.new("Part")
	root.Name, root.CFrame, root.Parent = "HumanoidRootPart", CFrame.new(0, 3, 345), character
	localPlayer.Character = character
	services.Players.LocalPlayer = localPlayer
	services.Players.GetPlayerByUserId = function(_, userId) return userId == LOCAL_ID and localPlayer or nil end

	local oldRemotes = replicated:FindFirstChild("DoomRemotes")
	if oldRemotes then oldRemotes:Destroy() end
	local remotes = Instance.new("Folder")
	remotes.Name, remotes.Parent = "DoomRemotes", replicated
	local requestRemote = Instance.new("RemoteFunction")
	requestRemote.Name, requestRemote.Parent = "Request", remotes
	local stateRemote = Instance.new("RemoteEvent")
	stateRemote.Name, stateRemote.Parent = "State", remotes
	local fxRemote = Instance.new("RemoteEvent")
	fxRemote.Name, fxRemote.Parent = "FX", remotes

	local current = lobbySnapshot(veteranProfile())
	local actions = {}
	local actionPayloads = {}
	-- What the mocked server answers to OpenChest; nil keeps the plain {} reply.
	local chestResult
	local collectorPrice, leaderboardDown = false, false
	requestRemote.InvokeServer = function(_, action, payload)
		table.insert(actions, action)
		actionPayloads[action] = payload
		if action == "Sync" then return { ok = true, data = current } end
		if action == "ProductInfo" then
			if payload.key == "vip" then return { ok = true, data = { id = 777, price = 299, name = "VIP" } } end
			-- The training pass price never answers until the test says so.
			if payload.key == "training" and not collectorPrice then return nil end
			if payload.key == "training" then return { ok = true, data = { id = 778, price = 149, name = "Training" } } end
			return { ok = false, message = { pt = "ID não configurado", en = "ID not configured" } }
		end
		if action == "Leaderboard" then
			if leaderboardDown then return { ok = false, message = { pt = "Placar indisponível", en = "Leaderboard unavailable" } } end
			return { ok = true, data = { rows = { { rank = 1, userId = 5, name = "Ana", waves = 42 }, { rank = 2, userId = LOCAL_ID, name = "Tester", waves = 12 } }, season = 1, personal = 12 } }
		end
		if action == "OpenChest" and chestResult then return { ok = true, data = { result = chestResult } } end
		return { ok = true, data = {} }
	end
	local function push(snapshot)
		current = snapshot
		stateRemote.OnClientEvent:Fire(snapshot)
		flush()
	end
	local function fx(event)
		fxRemote.OnClientEvent:Fire(event)
		flush()
	end
	local function frames(dt, count)
		for _ = 1, count or 1 do
			advance(dt or 1 / 30)
			runService.RenderStepped:Fire(dt or 1 / 30)
			for _, bound in pairs(runService.binds) do bound(dt or 1 / 30) end
		end
		flush()
	end
	local function asked(action)
		for _, name in ipairs(actions) do if name == action then return true end end
		return false
	end
	local function click(prefix)
		local gui = playerGui:FindFirstChild("DoomsdayUI")
		local button = gui and findButton(gui, prefix)
		check(button ~= nil, tag .. ": a visible button labelled '" .. prefix .. "' exists")
		if button then button.Activated:Fire(); flush() end
		return button ~= nil
	end
	local function clickNamed(name)
		local gui = playerGui:FindFirstChild("DoomsdayUI")
		local button = gui and named(gui, name)
		check(button ~= nil and shown(button, gui), tag .. ": a visible control named '" .. name .. "' exists")
		if button and shown(button, gui) then button.Activated:Fire(); flush() end
		return button
	end

	-- The real world, so lobby cosmetics and tower lookups hit real models.
	local world
	step("the world builds", function()
		world = WorldBuilder.new(Catalog, function() end)
		-- Roblox omits server-created Camera instances during replication.
		for _,item in ipairs(workspace.DoomLobby:GetDescendants()) do
			if item:IsA("Camera") then item:Destroy() end
		end
		world:Build("manhattan")
		for _, tower in ipairs(towers()) do world:MakeTower(tower.id, tower.heroId, tower.position, tower.ownerId) end
	end)

	-- Client modules, freshly loaded against this session's services.
	local clientScript = Instance.new("LocalScript")
	clientScript.Name = "DoomClient"
	-- test_client_boot.py lists every src/client module, so a newly split
	-- one is booted here without being named.
	local clientModules = {}
	for name, load in pairs(CLIENT_MODULES) do
		clientModules[name] = moduleScript(clientScript, name, load)
		loaded[clientModules[name]] = nil
	end
	local effectsScript = clientModules.Effects
	local reviewScript = clientModules.Review
	loaded[shared.Config] = nil

	if not step("init.client boots and syncs", function() __CLIENT__(clientScript, clockOs); flush() end) then return end
	local gui = playerGui:FindFirstChild("DoomsdayUI")
	check(gui ~= nil, tag .. ": the client mounts its ScreenGui")
	if not gui then return end
	local main
	for _, child in ipairs(gui:GetChildren()) do
		if rawget(child, "__class") == "Frame" and child.ZIndex ~= 50 then main = child end
	end
	local overlays
	for _, child in ipairs(gui:GetChildren()) do
		if rawget(child, "__class") == "Frame" and child.ZIndex == 50 then overlays = child end
	end
	check(asked("Sync"), tag .. ": the client asked for its first snapshot")

	--========================================================================
	-- Lobby
	--========================================================================
	local lobbyLayout = UILayout.lobbyLayout(SCREEN.w, SCREEN.h)
	step("the lobby HUD lays out", function()
		check(frameAt(main, lobbyLayout.pill) ~= nil, tag .. ": the gold pill sits where lobbyLayout puts it")
		check(frameAt(main, lobbyLayout.squad) ~= nil, tag .. ": the squad button sits where lobbyLayout puts it")
		check(frameAt(main, lobbyLayout.settings) ~= nil, tag .. ": the settings button sits where lobbyLayout puts it")
		check(frameAt(main, lobbyLayout.elevator) == nil, tag .. ": no elevator card while standing on the open deck")
		-- The world is the menu: nothing else sits on screen when the lobby opens.
		local visible = 0
		for _, child in ipairs(main:GetChildren()) do
			if child.Visible ~= false then visible += 1 end
		end
		-- Wide screens add the side quest tracker; phones keep the view clear.
		local tracker = main:FindFirstChild("QuestTracker")
		check((tracker ~= nil) == (lobbyLayout.tracker ~= nil), tag .. ": the quest tracker shows exactly on screens with room for it")
		if tracker then check(frameAt(main, lobbyLayout.tracker) ~= nil, tag .. ": the quest tracker sits where lobbyLayout puts it") end
		local expected = tracker and 6 or 5
		check(visible == expected, tag .. ": the idle lobby shows counters, play/settings, dock, guide and quests, got " .. visible .. " elements")
		local bad = offscreen(main, SCREEN)
		check(#bad == 0, tag .. ": every lobby element is on screen: " .. table.concat(bad, ", "))
	end)

	step("per-viewer lobby cosmetics", function()
		local lobby = workspace:FindFirstChild("DoomLobby")
		-- Collections live in the HUD, and a veteran with a campaign victory
		-- has every portal open: no world shroud at all.
		check(countNamed(lobby, "LockShroud") == 0, tag .. ": the veteran sees every portal open")
		local highlights = 0
		for _, item in ipairs(lobby:GetDescendants()) do if rawget(item, "__class") == "Highlight" then highlights += 1 end end
		check(highlights == 0, tag .. ": removed hero statues leave no equipped world highlights")
		local boardText = lobby.Board_quests.Panel.Board:FindFirstChildOfClass("TextLabel").Text
		check(string.find(boardText, "1 PRONTA", 1, true) ~= nil, tag .. ": the mission board tells this viewer a reward is waiting, got " .. boardText)
		-- Each portal's sign names what stepping in starts for this viewer.
		local nextMap = "random"
		local campaignSign = localPlayer.PlayerGui.PortalPicture_normal.MapRules.Text
		check(nextMap ~= nil and string.find(localPlayer.PlayerGui.PortalPicture_normal.MapTitle.Text, "Manhattan", 1, true) ~= nil,
			tag .. ": the campaign sign names the next unbeaten sector, got " .. campaignSign)
		check(lobby.Portal_normal.QueueSign1.QueueBoard.QueueStatus.Text == "0/4  •  ENTRE", tag .. ": the first queue invites the viewer in")
		local picture=localPlayer.PlayerGui.PortalPicture_normal.MapPicture
		check(picture.CurrentCamera==picture.PictureCamera,tag..": map picture camera is bound on this client")
		check(picture.Parent.Adornee==lobby.Portal_normal.MapBillboard and lobby.Portal_normal.MapBillboard.MapBoard.Enabled==false,tag..": rendered picture is mounted through PlayerGui without duplicate sign")
		check(picture.Parent.Adornee==lobby.Portal_normal.MapBillboard and lobby.Portal_normal.MapBillboard.MapBoard.Enabled==false,tag..": rendered picture is mounted through PlayerGui without duplicate sign")
		local arenaSign = localPlayer.PlayerGui.PortalPicture_ranked.MapRules.Text
		check(string.find(arenaSign, "ONDAS INFINITAS", 1, true) ~= nil, tag .. ": the competitive sign promises endless waves, got " .. arenaSign)
		check(countNamed(lobby, "StartHere") == 0, tag .. ": a veteran gets no first-visit beacon")
	end)

	step("the showroom drone turns in its case", function()
		local stand = workspace:FindFirstChild("DoomLobby").Shop_collector
		local arm
		for _, child in ipairs(stand:GetChildren()) do
			if child.Name == "Drone" and child.Size.X > 3 then arm = child end
		end
		local before = arm and arm.CFrame.LookVector
		frames(0.25, 4)
		local after = arm and arm.CFrame.LookVector
		check(before ~= nil and after ~= nil and before.X * after.X + before.Z * after.Z < 0.99, tag .. ": the drone's rotor arm has turned")
	end)

	local contextSlot = lobbyLayout.context
	local function contextOpen() return main:FindFirstChild("ContextPanel") ~= nil end
	step("the next-goal strip sends the player to a place",function()
		-- Chests are bought at the shop: the strip shows the way, it opens no menu.
		clickNamed("FirstVisitHint")
		check(not contextOpen(),tag..": the shop suggestion sends the player walking, no chest menu")
		check(named(gui,"RefugeWelcome")==nil and named(gui,"GuideLink_modes")==nil,tag..": there is no guide panel")
		check(#offscreen(main,SCREEN)==0,tag..": the strip stays inside the usable screen")
	end)
	step("a portal opens no menu", function()
		fx({ kind = "OpenPanel", panel = "play", modeId = "normal" })
		check(not contextOpen(), tag .. ": an unknown panel request opens nothing; portals are walked into")
	end)
	local openings = {
		{ panel = "quests" }, { panel = "leaderboard" },
		{ panel = "shop", shopKind = "pass", shopKey = "vip" }, { panel = "shop", shopKind = "pass", shopKey = "collector" },
		{ panel = "shop", shopKind = "product", shopKey = "gold" },
	}
	for _, heroId in ipairs(Catalog.HeroOrder) do table.insert(openings, { panel = "hero", heroId = heroId }) end
	for _, panel in ipairs({"inventory", "chests", "premium", "talents", "rewards"}) do table.insert(openings, {panel = panel}) end
	local opened = 0
	for _, spec in ipairs(openings) do
		local label = spec.panel .. ":" .. tostring(spec.modeId or spec.heroId or spec.skillId or spec.shopKey or "")
		step("OpenPanel " .. label, function()
			local event = table.clone(spec)
			event.kind = "OpenPanel"
			fx(event)
			if contextOpen() then opened += 1 end
		end)
	end
	check(opened == #openings, tag .. ": every physical location opens its panel in the context slot, " .. opened .. "/" .. #openings)

	step("talent tree touch and desktop", function()
		local evolved = veteranProfile()
		evolved.talents, evolved.talentPoints = {}, 6
		push(lobbySnapshot(evolved))
		fx({kind="OpenPanel",panel="talents"})
		local tree, node
		for _, item in ipairs(gui:GetDescendants()) do
			if item.Name == "TalentTree" then tree = item end
			if item.Name == "UpgradeTalent_roundGold" then node = item end
		end
		check(tree ~= nil, tag .. ": talent branches render")
		check(#offscreen(main, SCREEN) == 0, tag .. ": talent panel stays within viewport")
		check(node ~= nil, tag .. ": fortune root has an upgrade button")
		if node then node.Activated:Fire(); flush() end
		check(asked("UpgradeTalent"),tag .. ": investing sends server intent")
		click("Redistribuir pontos")
		check(not asked("ResetTalents"),tag .. ": reset first asks confirmation")
		click("Confirmar redistribuição")
		check(asked("ResetTalents"),tag .. ": confirmed reset sends server intent")
		push(lobbySnapshot(veteranProfile()))
	end)

	step("the talent honeycomb: select, requirements, a compact tree", function()
		local evolved = veteranProfile()
		evolved.talents, evolved.talentPoints = {}, 3
		push(lobbySnapshot(evolved))
		fx({kind="OpenPanel",panel="talents"})
		check(countNamed(gui, "TalentHex_roundGold") == 1 and countNamed(gui, "TalentHex_abilityPower") == 1 and countNamed(gui, "TalentHex_globalMagnet") == 1, tag .. ": every talent is a hexagon on the map")
		check(countNamed(gui, "TalentIcon_roundGold") == 1 and countNamed(gui, "TalentIcon_abilityPower") == 1, tag .. ": each hexagon carries a drawn icon")
		check(countNamed(gui, "TalentLink") == 0 and countNamed(gui, "TalentZoomIn") == 0, tag .. ": no connecting lines and no zoom controls clutter the tree")
		check(named(gui, "TalentLegend") ~= nil, tag .. ": the three branches are named once, above the tree")
		check(named(gui, "TalentLock_killGold") ~= nil and named(gui, "TalentLock_roundGold") == nil, tag .. ": a talent whose parent is too low shows a lock, an open one does not")
		check(named(named(gui, "TalentRank_roundGold"), "Text") == nil and named(gui, "TalentRank_roundGold").Text == "0/5", tag .. ": the level badge reads 0/5")
		-- The honeycomb is narrow enough for any panel: nothing to drag sideways.
		local treeFrame = named(gui, "TalentTree")
		local mapFrame = treeFrame and named(treeFrame, "TalentMap")
		check(mapFrame ~= nil and mapFrame.Size.X.Offset <= 340, tag .. ": the honeycomb is compact, " .. tostring(mapFrame and mapFrame.Size.X.Offset) .. " px wide")
		clickNamed("TalentNode_killGold")
		check(named(gui, "Talent_killGold") ~= nil, tag .. ": tapping a hexagon shows its card")
		local nowNext = named(gui, "TalentNowNext")
		check(nowNext and string.find(nowNext.Text, "Próximo", 1, true) ~= nil, tag .. ": the card shows now and next values, got " .. tostring(nowNext and nowNext.Text))
		local locked = named(gui, "UpgradeTalent_killGold")
		check(locked and locked.Active == false, tag .. ": a talent whose parent is too low cannot be bought")
		clickNamed("CloseContext")
		push(lobbySnapshot(veteranProfile()))
	end)

	step("gallery and shop category navigation", function()
		fx({kind="OpenPanel",panel="inventory"})
		for slot=1,5 do check(countNamed(gui,"SquadSlot_"..slot)==1,tag..": squad has visible slot "..slot) end
		check(countNamed(gui,"Collection_ironman")==1 and countNamed(gui,"Collection_thor")==0,tag..": inventory defaults to owned heroes")
		local starMark = named(gui, "CollectionStars")
		check(starMark ~= nil and starMark.Text == "★★", tag .. ": a hero with two stars shows them on its collection card")
		check(named(gui, "CollectionShiny") ~= nil, tag .. ": a shiny hero sparkles on its collection card")
		click("TODOS")
		for _,id in ipairs(Catalog.HeroOrder) do check(countNamed(gui,"Collection_"..id)==1,tag..": collection exposes "..id) end
		click("MEUS HERÓIS")
		check(countNamed(gui,"Collection_thor")==0,tag..": owned filter restores compact gallery")
		fx({kind="OpenPanel",panel="chests"})
		check(countNamed(gui,"SummonSelect_rare")==1 and countNamed(gui,"OpenChest_rare")==1 and countNamed(gui,"SummonSelect_base_rare")==0,tag..": rare chest has a dedicated page")
		local odds=named(gui,"SummonOdds")
		local crates=named(gui,"SummonCrates")
		if SCREEN.w>=1000 then
			local viewport=screenRect(named(gui,"ContextBody"),gui,SCREEN)
			local gallery=screenRect(odds,gui,SCREEN)
			local buy=screenRect(named(gui,"OpenChest_rare"),gui,SCREEN)
			check(gallery.y+122<=viewport.y+viewport.h and buy.y+buy.h<=viewport.y+viewport.h,tag..": portraits, odds and purchase are visible together before scrolling")
		end
		odds.CanvasPosition=Vector2.new(0,128)
		crates.CanvasPosition=Vector2.new(14,0)
		clickNamed("SummonSelect_legendary")
		check(countNamed(gui,"OpenChest_legendary")==1 and countNamed(gui,"OpenChest_rare")==0,tag..": legendary tab switches the purchase intent")
		clickNamed("SummonSelect_rare")
		check(named(gui,"SummonOdds").CanvasPosition.Y==128 and named(gui,"SummonCrates").CanvasPosition.X==14,tag..": each summon catalogue retains its scroll when changing crates")
		fx({kind="OpenPanel",panel="premium"})
		click("PASSES")
		check(countNamed(gui,"PremiumTabs_pass")==1,tag..": premium pass tab stays accessible")
		-- A price that never answered offers a retry; one that is not on sale says so.
		-- Prices are fetched one by one; wait for the whole list.
		frames(0.5, 20)
		local retry=named(gui,"Buy_pass:training")
		check(retry~=nil and retry.Text=="Tentar de novo",tag..": a price with no answer offers a retry, got "..tostring(retry and retry.Text))
		click("OURO")
		local unsold=named(gui,"Buy_product:gold1000")
		check(unsold~=nil and unsold.Text=="Indisponível",tag..": a product that is not configured reads unavailable")
		-- The Gold packs rank themselves: the biggest pack is the best deal and
		-- the mid pack is the one most people take; each pack states Gold per R$.
		check(named(gui,"Badge_gold30000")~=nil and named(gui,"Badge_gold5000")~=nil and named(gui,"Badge_gold1000")==nil and named(gui,"Badge_gold12000")==nil,tag..": only the best-value and the most-popular Gold pack wear a badge")
		check(named(gui,"Badge_gold30000").Text=="MELHOR VALOR" and named(gui,"Badge_gold5000").Text=="MAIS POPULAR",tag..": the badges read best value and most popular")
		local valueLine=named(gui,"Value_gold12000")
		check(valueLine~=nil and string.find(valueLine.Text,"20",1,true)~=nil,tag..": a pack states its Gold per Robux, got "..tostring(valueLine and valueLine.Text))
		click("PASSES")
		retry=named(gui,"Buy_pass:training")
		collectorPrice=true
		if retry then retry.Activated:Fire(); flush() end
		frames(0.5, 4)
		local priced=named(gui,"Buy_pass:training")
		check(priced~=nil and string.find(priced.Text,"149",1,true)~=nil,tag..": retrying loads the price, got "..tostring(priced and priced.Text))
		leaderboardDown=true
		-- Checked right away: a place-bound panel closes once the commander is
		-- far from its totem, as this one is.
		fx({kind="OpenPanel",panel="leaderboard"})
		check(named(gui,"BoardRetry")~=nil,tag..": a leaderboard that failed to load offers a retry instead of loading forever")
		leaderboardDown=false
		local again=named(gui,"BoardRetry")
		if again then again.Activated:Fire(); flush() end
		check(named(gui,"BoardRetry")==nil and named(gui,"BoardFailed")==nil,tag..": retrying clears the failure")
		fx({kind="OpenPanel",panel="premium"})
		check(#offscreen(main,SCREEN)==0,tag..": category navigation stays on screen")
	end)

	step("base collection, chest and battle upgrade",function()
		local p=veteranProfile({bases={outpost=true,workshop=true},equippedBase="outpost"})
		push(lobbySnapshot(p)); fx({kind="OpenPanel",panel="bases"})
		check(countNamed(gui,"BaseCard_worldtree")==1,tag..": base gallery includes locked and owned bases")
		local equip=named(gui,"EquipBase_workshop"); check(equip~=nil,tag..": owned base can be equipped")
		if equip then equip.Activated:Fire(); flush() end
		check(asked("EquipBase"),tag..": base equip uses server intent")
		fx({kind="OpenPanel",panel="chests",chestId="base_supply"})
		check(countNamed(gui,"SummonSelect_base_supply")==1 and countNamed(gui,"OpenChest_base_supply")==1 and countNamed(gui,"SummonSelect_supply")==0,tag..": base chest selected independently of hero chests")
		check(countNamed(gui,"ChestOdds_workshop")==1 and countNamed(gui,"ChestOdds_ironman")==0,tag..": base chest displays actual base pool")
		check(named(gui,"ContextTitle").Text=="INVOCAR BASES",tag..": entering the base shop changes its title immediately")
		push(matchSnapshot(p,"Preparing",{base={id="workshop",level=1,stats=Rules.BaseStats("workshop",1),wall=0},cash=1000}))
		local open=named(gui,"OpenBaseUpgrade"); if open then open.Activated:Fire(); flush() end
		check(countNamed(gui,"ConfirmBaseUpgrade")==1,tag..": core bar opens upgrade comparison")
		local upgrade=named(gui,"ConfirmBaseUpgrade"); if upgrade then upgrade.Activated:Fire(); flush() end
		check(asked("UpgradeBase"),tag..": base upgrade uses server intent")
		push(lobbySnapshot(veteranProfile())); fx({kind="OpenPanel",panel="chests",chestId="rare"})
	end)

	step("buying and equipping from the panels", function()
		fx({kind="OpenPanel",panel="chests"})
		clickNamed("OpenChest_rare")
		check(not asked("OpenChest"),tag..": selecting a chest does not spend before confirmation")
		check(countNamed(gui,"ConfirmChest_rare")==1,tag..": the price confirmation appears")
		clickNamed("CancelChest")
		check(not asked("OpenChest"),tag..": cancelling keeps Gold untouched")
		clickNamed("OpenChest_rare")
		clickNamed("ConfirmChest_rare")
		check(asked("OpenChest"),tag .. ": chest sends server recruitment intent")
		fx({kind="OpenPanel",panel="hero",heroId="spiderman"})
		click("+ COLOCAR NA EQUIPE")
		check(asked("SetLoadout"),tag .. ": owned hero can be equipped")
		fx({kind="OpenPanel",panel="hero",heroId="ironman"})
		-- Mastery, ability rank, account level and tower upgrade each have their own word.
		local function shows(fragment)
			for _, item in ipairs(gui:GetDescendants()) do
				if type(item.Text) == "string" and string.find(item.Text, fragment, 1, true) then return true end
			end
			return false
		end
		check(shows("MAESTRIA ") and shows("RANK 1/"), tag .. ": the hero page names mastery and ability rank apart")
		check(not shows("Nível do herói"), tag .. ": the hero page no longer calls mastery a level")
		click("SUBIR PARA RANK")
		check(asked("UpgradeAbility"),tag .. ": leader ability upgrades through server")
		fx({ kind = "OpenPanel", panel = "quests" })
		click("Resgatar recompensa")
		check(asked("ClaimQuest"), tag .. ": the mission board claims a finished quest")
		click("×")
		check(not contextOpen(), tag .. ": the close button dismisses the panel")
	end)

	step("the guide points to the shop when a chest is affordable", function()
		check(named(gui, "Nav_chests") == nil, tag .. ": the dock has no chest button; the chest shop is a place")
		local tip = named(gui, "GuideTip")
		check(tip ~= nil and string.find(tip.Text, "INVOCAÇÃO", 1, true) ~= nil, tag .. ": 2,500 Gold sends the commander to the summon halls")
		fx({kind="OpenPanel",panel="modes",hud=true})
		check(named(gui, "FirstMission") == nil, tag .. ": a trained commander goes straight to the modes")
		click("×")
	end)

	step("earned Gold pops and floats up from the lobby counter", function()
		local richer = veteranProfile()
		richer.gold = (richer.gold or 0) + 250
		push(lobbySnapshot(richer))
		local float = named(overlays, "FloatingGain")
		check(float ~= nil and float.Text == "+250", tag .. ": the gain floats above the Gold counter, got " .. tostring(float and float.Text))
		frames(1 / 30, 45)
		check(named(overlays, "FloatingGain") == nil, tag .. ": the floating number fades away")
		push(lobbySnapshot(veteranProfile()))
	end)

	step("a chest reveal builds suspense, then shows the hero", function()
		local function reveal() return overlays:FindFirstChild("ChestReveal") end
		local function openRare()
			fx({ kind = "OpenPanel", panel = "chests" })
			clickNamed("OpenChest_rare")
			clickNamed("ConfirmChest_rare")
		end
		chestResult = { chestId = "rare", heroId = "thor", rarity = "legendary", duplicate = false, refundGold = 0, refundMastery = 0 }
		openRare()
		local stage = reveal()
		check(stage ~= nil, tag .. ": confirming a chest opens the full-screen reveal")
		local card = stage and named(stage, "RevealHeroCard")
		check(card ~= nil and card.Visible == false, tag .. ": the hero stays hidden while the chest charges")
		frames(1 / 30, 25)
		local tier = stage and named(stage, "TierLabel")
		check(tier ~= nil and tier.Text ~= "", tag .. ": the chest climbs through rarity names while it charges")
		check(not named(stage, "RevealContinue").Visible, tag .. ": no way out before the prize is shown")
		-- The hero is not a photograph: it leaps out of the chest and keeps moving.
		local function findRoot(node)
			for _, child in ipairs(node:GetChildren()) do
				if child.Name == "HumanoidRootPart" then return child end
				local deeper = findRoot(child)
				if deeper then return deeper end
			end
		end
		local portrait = card and named(card, "RevealPortrait")
		local heroRoot = portrait and findRoot(portrait)
		if heroRoot then
			local lowest, highest, turned = math.huge, -math.huge, false
			local first = heroRoot.CFrame
			for _ = 1, 150 do
				frames(1 / 30, 1)
				local y = heroRoot.CFrame.Position.Y
				lowest, highest = math.min(lowest, y), math.max(highest, y)
				if (heroRoot.CFrame.LookVector - first.LookVector).Magnitude > 0.5 then turned = true end
			end
			check(highest - lowest > 1.5, tag .. ": the revealed hero leaps, rising " .. tostring(highest - lowest) .. " studs")
			check(turned, tag .. ": and turns a full circle on the way")
			check(portrait ~= nil and portrait.Parent ~= nil, tag .. ": the live portrait is still the card's portrait")
		else
			check(true, tag .. ": this hero has no jointed figure to animate")
		end
		clickNamed("RevealSkip")
		check(card.Visible and named(stage, "RevealContinue").Visible, tag .. ": a tap skips straight to the hero")
		check(named(stage, "RevealName").Text == Catalog.Heroes.thor.name.pt, tag .. ": the reveal names the hero the server granted")
		check(string.find(named(stage, "RevealStatus").Text, "NOVO", 1, true) ~= nil, tag .. ": a new hero is celebrated as new")
		check(string.find(named(stage, "RevealRarity").Text, "LENDÁRIO", 1, true) ~= nil, tag .. ": the rarity is shouted with its accent intact, got " .. named(stage, "RevealRarity").Text)
		clickNamed("RevealContinue")
		check(reveal() == nil, tag .. ": the continue button closes the reveal")
		check(countNamed(gui, "ChestResult") == 1, tag .. ": the panel keeps the result card afterwards")

		-- A duplicate plays through on its own and says what it turned into.
		chestResult = { chestId = "rare", heroId = "falcon", rarity = "common", duplicate = true, refundGold = 150, refundMastery = 60 }
		openRare()
		frames(1 / 30, 90)
		stage = reveal()
		check(stage ~= nil and named(stage, "RevealContinue").Visible, tag .. ": left alone, the reveal finishes by itself")
		check(stage and string.find(named(stage, "RevealStatus").Text, "150", 1, true) ~= nil, tag .. ": a duplicate shows the Gold it became")
		clickNamed("RevealContinue")
		chestResult = { chestId = "rare", heroId = "falcon", rarity = "common", duplicate = true, refundGold = 150, refundMastery = 60, starGained = true, stars = 2 }
		openRare()
		frames(1 / 30, 90)
		stage = reveal()
		check(stage and string.find(named(stage, "RevealStatus").Text, "+1 ★ (2/5)", 1, true) ~= nil, tag .. ": a duplicate that gains a star says so")
		clickNamed("RevealContinue")
		chestResult = { chestId = "rare", heroId = "falcon", rarity = "common", duplicate = false, refundGold = 0, refundMastery = 0, shiny = true }
		openRare()
		frames(1 / 30, 90)
		stage = reveal()
		check(stage and string.find(named(stage, "RevealStatus").Text, "BRILHANTE", 1, true) ~= nil, tag .. ": a shiny pull is announced")
		clickNamed("RevealContinue")

		-- Reduced effects: same result, no charging build-up.
		local calm = veteranProfile()
		calm.settings.lowFX = true
		push(lobbySnapshot(calm))
		chestResult = { chestId = "rare", heroId = "widow", rarity = "rare", duplicate = false, refundGold = 0, refundMastery = 0 }
		frames(1 / 30, 100) -- the previous reveal's confetti has landed
		openRare()
		frames(1 / 30, 25)
		stage = reveal()
		check(stage ~= nil and named(stage, "RevealHeroCard").Visible, tag .. ": with reduced effects the hero shows in under a second")
		check(countNamed(overlays, "Confetti") == 0, tag .. ": reduced effects throws no confetti")
		clickNamed("RevealContinue")
		chestResult = nil
		push(lobbySnapshot(veteranProfile()))
		click("×")
	end)

	step("HUD affordances open their panels", function()
		click("OPÇÕES")
		check(contextOpen(), tag .. ": the settings button opens a panel")
		click("Ligado")
		check(asked("Settings"), tag .. ": a settings toggle is sent to the server")
		click("×")
		fx({kind="OpenPanel",panel="modes",hud=true})
		check(contextOpen(), tag .. ": Play opens a clear choice of modes")
		for _,id in ipairs(Catalog.DestinationOrder) do
			local tile=named(gui,"Destination_"..id)
			check(tile and named(tile,"RouteSegment"),tag..": destination has route preview "..id)
			check(named(gui,"FindPortal_"..id)~=nil,tag..": direct play action "..id)
		end
		check(named(gui,"OpenMapSelection")==nil,tag..": no arbitrary map-mode selector")
		check(named(gui,"PlayButton")==nil,tag..": no PLAY button remains on the HUD")
		clickNamed("FindPortal_normal")
		check(not asked("StartMatch"),tag..": finding a portal never starts a match remotely")
		check(not contextOpen(),tag..": finding a portal clears the screen to walk there")
		clickNamed("ActiveBaseButton")
		check(named(gui,"ActiveBaseSummary")~=nil,tag..": active base has a direct HUD entry")
		click("×")
		clickNamed("Nav_inventory")
		check(contextOpen(), tag .. ": Heroes opens the owned inventory")
		-- One team, always: no saved formations to pick between.
		check(named(gui, "Salvar") == nil and not asked("SaveLoadout"), tag .. ": the team panel has no saved formations")
	end)

	step("collection tabs, rarity chips, base and direct leader selection",function()
		check(named(gui,"FormationBaseName")~=nil,tag..": formation shows its equipped base")
		check(named(gui,"HeroSearch")==nil and named(gui,"CycleHeroSort")==nil,tag..": no search box or sort cycle clutters the team screen")
		clickNamed("InventoryTabs_all")
		check(named(gui,"Collection_captain")~=nil,tag..": the All tab shows the whole collection")
		clickNamed("HeroRarity_"..Catalog.RarityOrder[1])
		check(named(gui,"Collection_ironman")~=nil and named(gui,"Collection_thor")==nil,tag..": a rarity chip narrows the collection")
		clickNamed("HeroRarity_all")
		check(named(gui,"Collection_thor")~=nil,tag..": the All chip brings every rarity back")
		clickNamed("InventoryTabs_owned")
		local rows=named(gui,"HeroGallery"):GetChildren()
		check(#rows>0 and named(gui,"HeroGallery").Size.Y.Offset>=0,tag..": owned heroes fill the gallery")
		clickNamed("SquadSlot_1")
		check(named(gui,"CancelLeaderPick")~=nil,tag..": highlighted first slot opens leader selection")
		clickNamed("FormationHero_spiderman")
		check(actionPayloads.SetLoadout.heroes[1]=="spiderman",tag..": collection directly sends the chosen leader")
		check(actionPayloads.SetLoadout.heroes[2]=="ironman",tag..": changing leader preserves previous squad members")
		clickNamed("FormationHero_ironman")
		check(named(gui,"MakeLeader_ironman")~=nil,tag..": hero details open on power and squad actions")
		clickNamed("HeroDetail_defense")
		check(named(gui,"HeroStat_1") and named(gui,"HeroBranch_2") and named(gui,"HeroTargets"),tag..": hero details explain stats, targets and specialization paths")
		clickNamed("BackToInventory")
	end)

	step("open panels preserve scroll during live profile refresh",function()
		local startRect=screenRect(named(gui,"ContextPanel"),gui,SCREEN)
		local originalBody=named(gui,"ContextBody")
		for i=1,25 do
			local body=named(gui,"ContextBody")
			body.CanvasPosition=Vector2.new(0,140)
			local changed=veteranProfile(); changed.gold=5000+i
			push(lobbySnapshot(changed)); frames(1/30,8)
			local updated=named(gui,"ContextBody")
			check(updated==originalBody,tag..": live update retains the actual scroll frame "..i)
			local panelRect=screenRect(named(gui,"ContextPanel"),gui,SCREEN)
			check(updated.CanvasPosition.Y==140,tag..": refresh preserves scroll "..i)
			check(panelRect.y==startRect.y and panelRect.h==startRect.h,tag..": panel does not drift "..i)
			check(updated.AutomaticCanvasSize==Enum.AutomaticSize.None,tag..": list alone owns canvas size")
		end
		local oldCard=named(gui,"HeroArtwork")
		for i=1,10 do
			local changed=veteranProfile(); changed.gold=5025
			changed.rewards={claimable=0,playedSeconds=i,serverNow=100+i}
			push(lobbySnapshot(changed)); frames(1/30,4)
		end
		check(named(gui,"ContextBody")==originalBody,tag..": reward timer leaves inventory scroll frame intact")
		check(named(gui,"HeroArtwork")==oldCard,tag..": timer changes do not rebuild inventory content")
	end)
	step("daily rewards: badge, free chest, login streak, playtime and milestones", function()
		-- The previous step leaves the inventory panel open, which hides the
		-- dock on short screens; close it first so the gift tab is reachable.
		click("×")
		check(not shown(named(gui, "RewardsBadge"), gui) or named(gui, "RewardsBadge").Visible == false,
			tag .. ": no badge with nothing to claim")
		local withRewards = veteranProfile({ rewards = rewardsFixture("ready") })
		push(lobbySnapshot(withRewards))
		local badge = named(gui, "RewardsBadge")
		check(badge ~= nil and badge.Visible == true, tag .. ": the nav badge appears when rewards are claimable")
		check(badge ~= nil and badge.Text == "3", tag .. ": the badge counts what can be claimed, got " .. tostring(badge and badge.Text))

		clickNamed("Nav_rewards")
		check(contextOpen(), tag .. ": the gift tab opens the rewards panel")
		check(named(gui, "ClaimFreeChest") ~= nil, tag .. ": the free chest card renders")
		clickNamed("ClaimFreeChest")
		check(asked("ClaimFreeChest"), tag .. ": the free chest sends its claim intent")
		clickNamed("ClaimLogin")
		check(asked("ClaimLogin"), tag .. ": the login streak sends its claim intent")
		check(named(gui, "LoginDay_3") ~= nil, tag .. ": the seven-day strip renders every day")
		clickNamed("ClaimPlaytime_2")
		check(asked("ClaimPlaytime"), tag .. ": a ready playtime gift sends its claim intent")
		local claimedGift = named(gui, "ClaimPlaytime_1")
		check(claimedGift ~= nil, tag .. ": an already-claimed gift still renders, disabled")
		local readyMilestone
		for _, milestone in ipairs(withRewards.rewards.collection.milestones) do
			if milestone.ready then readyMilestone = milestone.index end
		end
		check(readyMilestone ~= nil, tag .. ": the fixture has a ready milestone to claim")
		clickNamed("ClaimMilestone_" .. readyMilestone)
		check(asked("ClaimMilestone"), tag .. ": a ready milestone sends its claim intent")
		check(named(gui, "SeasonCard") == nil, tag .. ": a snapshot without a season status draws no season card")
		push(lobbySnapshot(veteranProfile({ rewards = rewardsFixture("ready"), seasonStatus = Rules.SeasonStatus({ id = 1, xp = Rules.SeasonThreshold(3) + 100, freeClaimed = 1, premiumClaimed = 0 }, false) })))
		check(named(gui, "SeasonCard") ~= nil and named(gui, "SeasonLevel_2") ~= nil, tag .. ": the season card shows the next levels")
		check(named(gui, "SeasonUnlock") ~= nil, tag .. ": without the pass the card offers the premium track")
		clickNamed("ClaimSeason")
		check(asked("ClaimSeason"), tag .. ": the season claim sends its intent")
		push(lobbySnapshot(veteranProfile({ rewards = rewardsFixture("ready"), seasonStatus = Rules.SeasonStatus({ id = 1, xp = Rules.SeasonThreshold(3), freeClaimed = 3, premiumClaimed = 3 }, true) })))
		check(named(gui, "SeasonUnlock") == nil, tag .. ": the premium owner is not offered the pass again")
		local codeBox = named(gui, "CodeInput")
		check(codeBox ~= nil, tag .. ": the rewards panel has a code box")
		codeBox.Text = "vingadores"
		clickNamed("RedeemCode")
		check(asked("RedeemCode"), tag .. ": a typed code is sent to the server")
		check(countNamed(gui, "GroupReward") == 0, tag .. ": without a configured group there is no group card")
		clickNamed("InviteFriends")
		check(named(gui, "InviteFriends") ~= nil, tag .. ": inviting friends never breaks the panel, even where invites are unavailable")
		click("×")

		-- Claiming eventually clears the badge, once the server reports nothing left.
		push(lobbySnapshot(veteranProfile({ rewards = rewardsFixture("empty") })))
		check(named(gui, "RewardsBadge") == nil or named(gui, "RewardsBadge").Visible == false,
			tag .. ": the badge clears once nothing is claimable")
		-- Hand off to the next step exactly as "HUD affordances" left it: the
		-- inventory panel open, on a fresh default profile.
		push(lobbySnapshot(veteranProfile()))
		clickNamed("Nav_inventory")
		check(contextOpen(), tag .. ": inventory reopens for the next check")
	end)

	step("a server refresh keeps the reader's place in a list", function()
		local body = named(gui, "ContextBody")
		check(body ~= nil, tag .. ": the inventory list is open")
		if body then
			body.CanvasPosition = Vector2.new(0, 240)
			local richer = veteranProfile()
			richer.gold = (richer.gold or 0) + 123
			push(lobbySnapshot(richer))
			local after = named(gui, "ContextBody")
			check(after == body, tag .. ": the refreshed panel keeps the same list")
			check(after and after.CanvasPosition and after.CanvasPosition.Y == 240, tag .. ": the scroll position survives a server update")
		end
	end)

	step("focused panels preserve navigation and usable touch space", function()
		local context = named(gui, "ContextPanel")
		local body = named(gui, "ContextBody")
		local panelRect, bodyRect = screenRect(context, gui, SCREEN), screenRect(body, gui, SCREEN)
		check(panelRect ~= nil and panelRect.x >= 0 and panelRect.y >= 0
			and panelRect.x + panelRect.w <= SCREEN.w and panelRect.y + panelRect.h <= SCREEN.h,
			tag .. ": the actual context panel fits the usable screen")
		check(bodyRect ~= nil and bodyRect.w >= 200 and bodyRect.h >= 65,
			tag .. ": the panel keeps a positive, usable scrolling area")
		local focused = UILayout.contextLayout(SCREEN.w, SCREEN.h, {}).modal
		for _, name in ipairs({"LobbyPill", "ActiveBaseButton", "SettingsButton", "LobbyNavigation"}) do
			local element = named(gui, name)
			check(element ~= nil and element.Visible == not focused,
				tag .. ": " .. name .. " gives compact panels room and remains available on large screens")
		end
		for _, id in ipairs({"inventory", "talents", "premium", "rewards"}) do
			local nav = named(gui, "Nav_" .. id)
			local indicator = nav and named(nav, "SelectedTab")
			check(indicator ~= nil and indicator.Visible == (id == "inventory"),
				tag .. ": navigation marks only the current inventory page (" .. id .. ")")
		end
		clickNamed("CloseContext")
		check(not contextOpen() and named(gui, "LobbyNavigation").Visible ~= false,
			tag .. ": closing a focused panel restores the navigation")
		for _, id in ipairs({"inventory", "talents", "premium", "rewards"}) do
			local indicator = named(named(gui, "Nav_" .. id), "SelectedTab")
			check(indicator ~= nil and indicator.Visible == false, tag .. ": close clears stale selection for " .. id)
		end
		clickNamed("Nav_inventory")
	end)

	step("standing in a portal shows the elevator card", function()
		local riding = lobbySnapshot(veteranProfile())
		riding.elevator = {
			portalId = "normal", modeId = "normal", mapId = "manhattan", carId="review-car", max = 4, remaining = 6, host = true,
			riders = { { userId = LOCAL_ID, name = "Tester" }, { userId = ALLY_ID, name = "Ally" } },
		}
		click("×")
		push(riding)
		-- A campaign car is taller: it carries the row of difficulties.
		local ridingLayout = UILayout.lobbyLayout(SCREEN.w, SCREEN.h, { difficulty = true })
		local card = frameAt(main, ridingLayout.elevator)
		check(card ~= nil, tag .. ": the elevator card sits where lobbyLayout puts it")
		check(named(gui,"LobbyNavigation").Visible == not lobbyLayout.class.short,
			tag .. ": short screens hide the dock while boarding so Leave stays reachable")
		local function labels()
			local found = {}
			for _, item in ipairs(card and card:GetDescendants() or {}) do
				if rawget(item, "__class") == "TextLabel" then table.insert(found, item.Text) end
			end
			return found
		end
		local function countdown()
			for _, text in ipairs(labels()) do if tonumber(text) then return tonumber(text) end end
			return nil
		end
		check(countdown() == 6, tag .. ": the countdown starts from the server's word, got " .. tostring(countdown()))
		frames(0.5, 4)
		check(countdown() == 4, tag .. ": the countdown ticks locally between snapshots, got " .. tostring(countdown()))
		push(riding)
		check(countdown() == 4, tag .. ": a snapshot with the same countdown does not rewind it, got " .. tostring(countdown()))
		local joined = table.concat(labels(), " | ")
		check(string.find(joined, "2/4", 1, true) ~= nil and (ridingLayout.class.short or string.find(joined, "Ally", 1, true) ~= nil),
			tag .. ": the card lists who is riding, got " .. joined)
		check(string.find(joined, "MANHATTAN", 1, true) ~= nil, tag .. ": the card names the sector")
		check(named(gui,"PortalChooseMap")==nil,tag..": fixed portal has no map switch")
		for _, id in ipairs(Catalog.DifficultyOrder) do
			local chip = named(card, "Difficulty_" .. id)
			local chipRect = chip and screenRect(chip, gui, SCREEN)
			local cardRect = screenRect(card, gui, SCREEN)
			check(chipRect ~= nil and chipRect.h >= 30 and chipRect.x >= cardRect.x and chipRect.x + chipRect.w <= cardRect.x + cardRect.w,
				tag .. ": the campaign card shows a thumb-sized " .. id .. " button inside it")
		end
		check(named(named(card, "Difficulty_nightmare"), "DifficultyLock") ~= nil and named(named(card, "Difficulty_normal"), "DifficultyLock") == nil, tag .. ": a difficulty not opened yet shows a drawn lock, an open one does not")
		clickNamed("Difficulty_hard")
		check(asked("SetDifficulty"), tag .. ": the host's pick is sent to the server as an intent")
		fx({ kind = "OpenPanel", panel = "quests" })
		check(main:FindFirstChild("ContextPanel") ~= nil, tag .. ": a panel opened while riding stops above the card")
		local panelRect = screenRect(named(gui, "ContextPanel"), gui, SCREEN)
		local bodyRect = screenRect(named(gui, "ContextBody"), gui, SCREEN)
		local elevatorRect = screenRect(card, gui, SCREEN)
		check(panelRect ~= nil and elevatorRect ~= nil and panelRect.y + panelRect.h <= elevatorRect.y,
			tag .. ": the actual panel never covers the portal countdown or Leave action")
		check(bodyRect ~= nil and bodyRect.h >= 65,
			tag .. ": a compact screen keeps a scrollable panel body while boarding")
		local close = named(gui, "CloseContext")
		local closeRect = screenRect(close, gui, SCREEN)
		check(closeRect ~= nil and closeRect.w >= 40 and closeRect.h >= 40
			and closeRect.y >= 0 and closeRect.y + closeRect.h <= SCREEN.h,
			tag .. ": the panel close action stays reachable while boarding")
		click("×")
		click("SAIR")
		check(asked("ElevatorLeave"), tag .. ": Leave is sent to the server")
		local guest = table.clone(riding)
		guest.elevator = table.clone(riding.elevator)
		guest.elevator.host = false
		push(guest)
		card = frameAt(main, ridingLayout.elevator)
		local arrows = card and findButton(card, "▶")
		check(card ~= nil and arrows == nil, tag .. ": only the first rider gets the sector switch")
		push(lobbySnapshot(veteranProfile()))
		check(frameAt(main, ridingLayout.elevator) == nil, tag .. ": stepping off removes the card")
	end)

	step("walking away closes the panel that belongs to a place", function()
		fx({ kind = "OpenPanel", panel = "hero", heroId = "ironman" })
		check(contextOpen(), tag .. ": the pedestal panel is open")
		root.CFrame = CFrame.new(-86, 3, 258)
		frames(0.2, 3)
		check(contextOpen(), tag .. ": standing at the pedestal keeps it open")
		root.CFrame = CFrame.new(60, 3, 380)
		frames(0.2, 3)
		check(contextOpen(), tag .. ": inventory remains usable while walking")
	end)

	step("buying a hero reveals its statue", function()
		local profile = veteranProfile()
		profile.heroes.thor = { xp = 0, level = 1 }
		profile.gold = 0
		push(lobbySnapshot(profile))
		check(countNamed(workspace:FindFirstChild("DoomLobby"), "LockShroud") == 0, tag .. ": gaining a hero does not create a lobby statue")
	end)

	step("a newcomer sees locks and the first-visit pointer", function()
		-- A real first session reaches the lobby through a phase change.
		push(resultsSnapshot(newcomerProfile()))
		push(lobbySnapshot(newcomerProfile()))
		local lobby = workspace:FindFirstChild("DoomLobby")
		-- Before training four portals are locked (the campaign portal runs
		-- training instead), ten heroes are unowned, and seven skills sit above
		-- level 1.
		-- Training and all six campaigns are open; the three competitive
		-- portals and cards wait for a first campaign victory.
		check(countNamed(lobby, "LockShroud") == 4, tag .. ": a newcomer sees the four locked destination portals")
		local campaignSign = localPlayer.PlayerGui.PortalPicture_normal.MapRules.Text
		check(string.find(campaignSign, "40 ONDAS", 1, true) ~= nil, tag .. ": Manhattan's campaign sign shows its 40 waves, got " .. campaignSign)
		local lockedSign = localPlayer.PlayerGui.PortalPicture_ranked.MapRules.Text
		check(string.find(lockedSign, "BLOQUEADO", 1, true) ~= nil, tag .. ": a locked portal's sign says so, got " .. lockedSign)
		check(countNamed(lobby.Portal_training, "StartHere") == 0, tag .. ": a newcomer gets the tutorial arrow, not a second sign over the same portal")
		local newcomerBoard = lobby.Board_quests.Panel.Board:FindFirstChildOfClass("TextLabel").Text
		check(string.find(newcomerBoard, "TREINE", 1, true) ~= nil, tag .. ": the mission board points a newcomer to training, got " .. newcomerBoard)
		check(named(gui, "FirstVisitHint") == nil, tag .. ": a newcomer gets no tip strip: the arrows teach")
		frames(1 / 30, 3)
		local card = named(gui, "TutorialCard")
		check(card ~= nil, tag .. ": a newcomer sees the training objective card")
		local cardText = card and named(card, "TutorialText")
		check(cardText ~= nil and string.find(cardText.Text, "TREINO", 1, true) ~= nil, tag .. ": the card says to follow the arrow to the training portal, got " .. tostring(cardText and cardText.Text))
		check(named(workspace, "TutorialArrow") ~= nil, tag .. ": an arrow stands over the way to the training portal")
		check(named(gui, "TutorialShortcut") ~= nil, tag .. ": the card offers to skip the walk")
		fx({kind="OpenPanel",panel="modes",hud=true})
		check(named(gui, "FirstMission") ~= nil, tag .. ": a newcomer's play menu leads with the short training")
		-- A short phone screen has no room for the card beside an open panel.
		frames(1 / 30, 2)
		local openCard = named(gui, "TutorialCard")
		check(openCard ~= nil and openCard.Visible == (SCREEN.h >= 500), tag .. ": the lesson card steps aside for an open panel only on a short screen (h " .. tostring(SCREEN.h) .. ")")
		clickNamed("FindTrainingPortal")
		check(asked("StartTraining") and not asked("StartMatch"), tag .. ": the training button asks the server to board the training queue")
		check(not contextOpen(),tag..": the play menu steps aside once training starts")
	end)

	--========================================================================
	-- Match
	--========================================================================
	local profile = veteranProfile()
	local layout = UILayout.matchLayout(SCREEN.w, SCREEN.h, { skills = 1, vip = true })
	step("the match HUD lays out", function()
		push(matchSnapshot(profile, "Preparing"))
		check(frameAt(main, layout.top) ~= nil, tag .. ": the match top bar sits where matchLayout puts it")
		check(frameAt(main, layout.heroCards) ~= nil, tag .. ": the hero card band sits where matchLayout puts it")
		local bad = offscreen(main, SCREEN)
		check(#bad == 0, tag .. ": every match element is on screen: " .. table.concat(bad, ", "))
		click("PRONTO")
		check(asked("SkipWave"), tag .. ": READY votes to skip preparation")
	end)

	step("the leader power button carries slot one's own hero and name", function()
		local leader = named(gui, "LeaderPower")
		check(leader ~= nil and string.find(leader.Text, Catalog.Abilities.repulsorBarrage.name.pt, 1, true) ~= nil,
			tag .. ": the button shows slot one's actual ability name, not a generic label, got " .. tostring(leader and leader.Text))
		check(not string.find(leader.Text, "⚡", 1, true), tag .. ": an ordinary ability carries no ultimate mark")
		-- The button is only rebuilt on a full render (a fresh match start), never
		-- mid-match — the loadout, and so slot one's ability, cannot change once a
		-- match has begun. Route through Results, like a real match ending, to
		-- reach a fresh "Preparing" the same way a new match would.
		push(resultsSnapshot(profile))
		push(matchSnapshot(profile, "Preparing", { ability = {
			id = Catalog.Heroes.thor.ability, heroId = "thor", kind = "chain", target = "area", rank = 1,
			cooldown = 0, cooldownTotal = 75, radius = 70, duration = 1.5, power = 0.3, ultimate = true,
		} }))
		local ultimateButton = named(gui, "LeaderPower")
		check(ultimateButton ~= nil and string.find(ultimateButton.Text, Catalog.Abilities.thunderCall.name.pt, 1, true) ~= nil,
			tag .. ": slot one's hero decides the button's ability and name, got " .. tostring(ultimateButton and ultimateButton.Text))
		check(string.find(ultimateButton.Text, "★", 1, true) ~= nil, tag .. ": a legendary/mythic ability marks itself as an ultimate")
		-- Back to the default loadout for every step that follows.
		push(resultsSnapshot(profile))
		push(matchSnapshot(profile, "Preparing"))
	end)

	step("2x speed and auto-skip sit in the action band and send votes", function()
		local speed, auto = named(gui, "SpeedToggle"), named(gui, "AutoSkipToggle")
		check(speed ~= nil and shown(speed, gui) and string.find(speed.Text, "1x", 1, true) ~= nil,
			tag .. ": the speed toggle is visible and starts at 1x, got " .. tostring(speed and speed.Text))
		check(auto ~= nil and shown(auto, gui), tag .. ": the auto-skip toggle is visible")
		clickNamed("SpeedToggle")
		check(asked("SetSpeed"), tag .. ": pressing 2x asks the server")
		clickNamed("AutoSkipToggle")
		check(asked("SetAutoSkip"), tag .. ": pressing AUTO asks the server")
		push(matchSnapshot(profile, "Wave", { speed = 2, speedVote = 2, speedVotes = 1, autoSkip = true }))
		check(string.find(named(gui, "SpeedToggle").Text, "2x", 1, true) ~= nil, tag .. ": the toggle shows 2x once the server says so")
		check(string.find(named(gui, "AutoSkipToggle").Text, "✓", 1, true) ~= nil, tag .. ": auto-skip shows it is on")
		push(matchSnapshot(profile, "Wave", { speed = 1, speedVote = 2, speedVotes = 1, partySize = 2, autoSkip = false }))
		check(string.find(named(gui, "SpeedToggle").Text, "1/2", 1, true) ~= nil,
			tag .. ": in a duo the toggle shows the vote still waiting, got " .. named(gui, "SpeedToggle").Text)
		local bad = offscreen(main, SCREEN)
		check(#bad == 0, tag .. ": the action band still fits on screen with the new toggles: " .. table.concat(bad, ", "))
		push(matchSnapshot(profile, "Preparing"))
	end)

	step("battle moments get their own banners", function()
		local function bannerTitle()
			local banner = named(overlays, "CelebrationBanner")
			return banner and named(banner, "BannerTitle").Text or ""
		end
		push(matchSnapshot(profile, "Wave", { completedWaves = 2, wave = 3 }))
		push(matchSnapshot(profile, "Preparing", { completedWaves = 3, wave = 3, goldEarned = 400 }))
		check(string.find(bannerTitle(), "ONDA 3 VENCIDA", 1, true) ~= nil, tag .. ": a cleared wave is celebrated, got " .. bannerTitle())
		check(named(gui, "PopScale") ~= nil, tag .. ": battle Gold pops when it grows")
		push(matchSnapshot(profile, "Wave", { completedWaves = 9, wave = 10 }))
		push(matchSnapshot(profile, "Preparing", { completedWaves = 10, wave = 10 }))
		check(string.find(bannerTitle(), "ONDA 10", 1, true) == nil, tag .. ": a boss wave waits for the boss banner instead")
		push(matchSnapshot(profile, "Wave", { completedWaves = 10, wave = 11 }))
		local camera = workspace.CurrentCamera
		camera.CameraType = Enum.CameraType.Custom
		-- Fired without flushing: the test scheduler runs every delay at once.
		fxRemote.OnClientEvent:Fire({ kind = "BossArrive", enemyId = "lizard", final = false, position = v3(20, 0, 0) })
		check(string.find(bannerTitle(), Catalog.Enemies.lizard.name.pt, 1, true) ~= nil, tag .. ": an arriving boss is named in a banner, got " .. bannerTitle())
		check(camera.CameraType == Enum.CameraType.Scriptable, tag .. ": the camera flies to the arriving boss")
		flush()
		check(camera.CameraType == Enum.CameraType.Custom, tag .. ": and hands the camera back to the player")
		fx({ kind = "EnemyDown", id = 44, enemyId = "lizard", position = v3(0, 0, 0), boss = true })
		check(string.find(bannerTitle(), "CHEFE DERROTADO", 1, true) ~= nil, tag .. ": a fallen boss gets a big banner, got " .. bannerTitle())
		fx({ kind = "Ability", heroId = "captainmarvel", abilityId = "photonNova", abilityKind = "blast", ultimate = true, ownerId = LOCAL_ID,
			position = v3(0, 0, 0), radius = 60, duration = 2, color = Color3.fromRGB(255, 210, 90), points = {} })
		check(string.find(bannerTitle(), "★", 1, true) ~= nil and string.find(bannerTitle(), "NOVA FOTÔNICA", 1, true) ~= nil,
			tag .. ": your own ultimate shouts its name, accents intact, got " .. bannerTitle())
		frames(1 / 30, 120)
		check(named(overlays, "CelebrationBanner") == nil, tag .. ": banners clear themselves")
		push(matchSnapshot(profile, "Preparing"))
		push(matchSnapshot(profile, "Preparing", { completedWaves = 8, wave = 8, nextBoss = 10 }))
		local warned = false
		for _, item in ipairs(gui:GetDescendants()) do
			if type(item.Text) == "string" and string.find(item.Text, "CHEFE EM 2 ONDAS", 1, true) then warned = true end
		end
		check(warned, tag .. ": preparation warns of a boss two waves away")
	end)

	step("the next wave's roads light up during preparation", function()
		local profile = veteranProfile()
		push(matchSnapshot(profile, "Preparing", { nextPaths = { 1 }, newEntrance = true }))
		local arrows = countNamed(workspace, "RouteArrow")
		check(arrows > 0, tag .. ": arrows walk the next wave's road, got " .. arrows)
		push(matchSnapshot(profile, "Wave", { nextPaths = nil }))
		frames(1 / 30, 2)
		check(countNamed(workspace, "RouteArrow") == 0, tag .. ": the arrows clear when the wave starts")
		push(matchSnapshot(profile, "Preparing"))
	end)

	step("placing a tower from a hotkey", function()
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.One, Position = v3(0, 0, 0) }, false)
		flush()
		rayHit = { Instance = workspace:FindFirstChild("DoomWorld").BuildZones.BuildGround, Position = v3(70, 0, -60) }
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown, Position = v3(SCREEN.w / 2, SCREEN.h / 2, 0) }, false)
		flush()
		-- While placing, the ground that refuses a tower is tinted, from the
		-- very rule the server applies: every tinted spot really is refused.
		local visuals = workspace:FindFirstChild("DoomClientVisuals")
		local roads, circles, edges, wrong = 0, 0, 0, {}
		local mapId = matchSnapshot(profile, "Preparing").match.mapId
		for _, item in ipairs(visuals and visuals:GetChildren() or {}) do
			if item.Name == "NoBuildRoad" or item.Name == "NoBuildCorner" or item.Name == "NoBuildTower" then
				if item.Name == "NoBuildRoad" then
					roads += 1
					-- Exactly as wide as the rule: wider would hide good ground,
					-- narrower would leave refused ground untinted.
					if math.abs(item.Size.X - 2 * (SharedConfig.PathHalfWidth + SharedConfig.TowerRadius)) > 0.01 then table.insert(wrong, "road width " .. item.Size.X) end
				elseif item.Name == "NoBuildTower" then
					circles += 1
					if math.abs(item.Size.Y - 4 * SharedConfig.TowerRadius) > 0.01 then table.insert(wrong, "tower ring " .. item.Size.Y) end
				end
				local ok = Rules.BuildCheck(mapId, item.Position, item.Name == "NoBuildTower" and { item.Position } or {}, SharedConfig, {})
				if ok then table.insert(wrong, item.Name) end
			elseif item.Name == "BuildEdge" then
				edges += 1
			end
		end
		check(roads >= #Catalog.Maps[mapId].paths[1] - 1, tag .. ": placing tints every road's no-build band, got " .. roads)
		check(circles == #towers(), tag .. ": placing rings every tower's footprint, got " .. circles)
		check(edges == 4, tag .. ": placing outlines the buildable area")
		check(#wrong == 0, tag .. ": every tinted spot is one the server refuses: " .. table.concat(wrong, ", "))
		click("CONFIRMAR")
		check(asked("PlaceTower"), tag .. ": confirming sends PlaceTower")
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Escape, Position = v3(0, 0, 0) }, false)
		flush()
		local leftover = 0
		for _, item in ipairs(visuals and visuals:GetChildren() or {}) do
			if string.sub(item.Name, 1, 7) == "NoBuild" or item.Name == "BuildEdge" then leftover += 1 end
		end
		check(leftover == 0, tag .. ": leaving placement clears the tint, " .. leftover .. " left")
	end)

	-- Touch: a tap in the world pins the spot, CONFIRM places it, and a tap the
	-- interface already used (processed) never moves anything.
	step("placing a tower with a touch tap", function()
		local function placed()
			local count = 0
			for _, name in ipairs(actions) do if name == "PlaceTower" then count += 1 end end
			return count
		end
		input.TouchEnabled = true
		local before = placed()
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.One, Position = v3(0, 0, 0) }, false)
		flush()
		rayHit = { Instance = workspace:FindFirstChild("DoomWorld").BuildZones.BuildGround, Position = v3(70, 0, -60) }
		input.TouchTapInWorld:Fire(Vector2.new(SCREEN.w / 2, SCREEN.h / 2), true)
		flush()
		check(findButton(playerGui.DoomsdayUI, "CONFIRMAR") == nil, tag .. ": a tap the interface already used does not pin a spot")
		input.TouchTapInWorld:Fire(Vector2.new(SCREEN.w / 2, SCREEN.h / 2), false)
		flush()
		check(placed() == before, tag .. ": a tap only pins the spot, it does not place")
		click("CONFIRMAR")
		check(placed() == before + 1, tag .. ": confirming a tapped spot sends PlaceTower")
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Escape, Position = v3(0, 0, 0) }, false)
		flush()
		input.TouchEnabled = false
	end)

	-- Mines are listed by the server; the client only draws what the list says.
	step("mines on the road", function()
		local function mineParts()
			local count = 0
			local visuals = workspace:FindFirstChild("DoomClientVisuals")
			for _, item in ipairs(visuals and visuals:GetChildren() or {}) do if item.Name == "Mine" then count += 1 end end
			return count
		end
		fx({ kind = "MineSync", mines = { { id = "m1", position = v3(10, 0, 5), radius = 9 }, { id = "m2", position = v3(30, 0, 5), radius = 9 } } })
		check(mineParts() == 2, tag .. ": every listed mine is drawn, got " .. mineParts())
		fx({ kind = "MineSync", mines = { { id = "m1", position = v3(10, 0, 5), radius = 9 }, { id = "m2", position = v3(30, 0, 5), radius = 9 } } })
		check(mineParts() == 2, tag .. ": a repeated list does not draw a mine twice")
		fx({ kind = "MineBlast", id = "m1", position = v3(10, 0, 5), radius = 9, color = Color3.fromRGB(74, 84, 118) })
		check(mineParts() == 1, tag .. ": a mine that went off leaves the road at once")
		fx({ kind = "MineSync", mines = { { id = "m3", position = v3(50, 0, 5), radius = 9 } } })
		check(mineParts() == 1, tag .. ": a mine the list no longer holds is taken off the road")
		fx({ kind = "MineSync", mines = {} })
		check(mineParts() == 0, tag .. ": an empty list clears every mine")
		fx({ kind = "MineSync", mines = { { id = "bad" }, "junk", { id = "m9", position = "nowhere" } } })
		check(mineParts() == 0, tag .. ": malformed mine rows are ignored")
	end)

	-- Tapping an enemy opens a card with its health, armour, pace and a line on
	-- what it does; empty ground folds it away again.
	step("inspecting an enemy", function()
		local ground = workspace:FindFirstChild("DoomWorld").BuildZones.BuildGround
		fx({ kind = "EnemySync", enemies = {
			{ id = 801, enemyId = "splitter", position = v3(40, 0, -20), hp = 80, maxHP = 118, st = 0 },
			{ id = 802, enemyId = "lizard", position = v3(90, 0, -20), hp = 1500, maxHP = 2000, st = 0 },
		} })
		frames(1 / 30, 2)
		local function tap(x, z)
			rayHit = { Instance = ground, Position = v3(x, 0, z) }
			input.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown, Position = v3(400, 300, 0) }, false)
			flush()
		end
		tap(41, -21)
		local card = named(gui, "EnemyCard")
		check(card ~= nil, tag .. ": tapping an enemy opens its card")
		if card then
			check(named(card, "EnemyName").Text == "Gosmento", tag .. ": the card names the enemy, got " .. tostring(named(card, "EnemyName").Text))
			check(named(card, "EnemyHealth").Text == "80 / 118", tag .. ": it shows the health the server last synced, got " .. tostring(named(card, "EnemyHealth").Text))
			check(string.find(named(card, "EnemyNote").Text, "Racha", 1, true) ~= nil, tag .. ": a line says what it does, got " .. tostring(named(card, "EnemyNote").Text))
			check(math.abs(named(card, "EnemyHealthFill").Size.X.Scale - 80 / 118) < 1e-6, tag .. ": the bar matches the health")
		end
		tap(91, -21)
		card = named(gui, "EnemyCard")
		check(card ~= nil and named(card, "EnemyName").Text == "Gekko Colosso" and named(card, "EnemyNote").Text == Catalog.Enemies.lizard.hint.pt, tag .. ": a boss shows its own hint")
		check(countNamed(gui, "EnemyCard") == 1, tag .. ": only one card at a time")
		tap(-60, 60)
		check(named(gui, "EnemyCard") == nil, tag .. ": a tap on empty ground folds the card away")
		tap(41, -21)
		frames(1, 7)
		check(named(gui, "EnemyCard") == nil, tag .. ": the card folds away on its own after a few seconds")
		-- The inspected enemy leaves the road: the card goes with it.
		tap(41, -21)
		check(named(gui, "EnemyCard") ~= nil, tag .. ": the enemy can be inspected again")
		fx({ kind = "Clear" })
		frames(1 / 30, 2)
		check(named(gui, "EnemyCard") == nil, tag .. ": the card goes when its enemy does")
	end)

	-- Run on Shift, jump twice, on every screen; a phone gets a run button.
	step("moving: run and double jump", function()
		local moves = Catalog.Movement
		local humanoid = Instance.new("Humanoid")
		humanoid.Name, humanoid.WalkSpeed, humanoid.Health, humanoid.FloorMaterial = "Humanoid", moves.walk, 100, Enum.Material.Plastic
		humanoid.MoveDirection, humanoid.Sit = v3(1, 0, 0), false
		local changes = {}
		humanoid.ChangeState = function(_, state) table.insert(changes, state) end
		humanoid.Parent = localPlayer.Character
		local root = localPlayer.Character:FindFirstChild("HumanoidRootPart")
		root.AssemblyLinearVelocity = v3(0, 0, 0)
		frames(1 / 30, 2)
		check(humanoid.WalkSpeed == moves.walk, tag .. ": a commander walks at the catalogue speed")
		contextActions.handlers.DoomRun("DoomRun", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftShift })
		frames(1 / 30, 2)
		check(humanoid.WalkSpeed == moves.sprint, tag .. ": holding Shift runs")
		contextActions.handlers.DoomRun("DoomRun", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftShift })
		frames(1 / 30, 2)
		check(humanoid.WalkSpeed == moves.walk, tag .. ": letting go walks again")
		-- A speed the game did not set (a future slowing power) is never overwritten.
		humanoid.WalkSpeed = 9
		contextActions.handlers.DoomRun("DoomRun", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftShift })
		frames(1 / 30, 2)
		check(humanoid.WalkSpeed == 9, tag .. ": a speed set by something else is left alone")
		humanoid.WalkSpeed = moves.walk
		contextActions.handlers.DoomRun("DoomRun", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftShift })
		check(contextActions.handlers.DoomRun("DoomRun", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftShift }) == Enum.ContextActionResult.Pass, tag .. ": the action never swallows the key")
		contextActions.handlers.DoomRun("DoomRun", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftShift })
		-- The first jump leaves the ground; the second, in the air, pushes up again, once.
		input.JumpRequest:Fire()
		check(#changes == 0, tag .. ": a jump from the ground is the game's own, not a double jump")
		task.wait(0.3)
		humanoid.FloorMaterial = Enum.Material.Air
		for _ = 1, 20 do frames(1 / 30, 1) end
		input.JumpRequest:Fire()
		check(#changes == 1 and root.AssemblyLinearVelocity.Y == moves.jumpPower, tag .. ": a jump in the air pushes up again")
		input.JumpRequest:Fire()
		check(#changes == 1, tag .. ": there is only one extra jump per landing")
		humanoid.FloorMaterial = Enum.Material.Plastic
		frames(1 / 30, 2)
		humanoid.FloorMaterial = Enum.Material.Air
		for _ = 1, 20 do frames(1 / 30, 1) end
		input.JumpRequest:Fire()
		check(#changes == 2, tag .. ": landing gives the extra jump back")
		local visuals = workspace:FindFirstChild("DoomClientVisuals")
		local function countParts(name)
			local count = 0
			for _, item in ipairs(visuals and visuals:GetChildren() or {}) do if item.Name == name then count += 1 end end
			return count
		end
		check(countParts("JumpRing") >= 1, tag .. ": the extra jump opens a ring of light")
		frames(1 / 30, 30)
		check(countParts("JumpRing") == 0, tag .. ": the ring fades away")
		-- Running is a context action, so a phone gets Roblox's own button beside
		-- the jump button, and the controller its stick click.
		check(contextActions.handlers.DoomRun ~= nil, tag .. ": running is bound as a context action")
		check(named(gui, "RunButton") == nil, tag .. ": we draw no run button of our own over the HUD")
		local run = contextActions.handlers.DoomRun
		humanoid.FloorMaterial = Enum.Material.Plastic
		run("DoomRun", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Touch, KeyCode = Enum.KeyCode.Unknown })
		run("DoomRun", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Touch, KeyCode = Enum.KeyCode.Unknown })
		frames(1 / 30, 2)
		check(humanoid.WalkSpeed == moves.sprint, tag .. ": a tap on the phone's button turns running on and it stays on")
		check(contextActions.titles.DoomRun == "PARAR", tag .. ": and its title says how to stop, got " .. tostring(contextActions.titles.DoomRun))
		run("DoomRun", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Touch, KeyCode = Enum.KeyCode.Unknown })
		run("DoomRun", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Touch, KeyCode = Enum.KeyCode.Unknown })
		frames(1 / 30, 2)
		check(humanoid.WalkSpeed == moves.walk and contextActions.titles.DoomRun == "CORRER", tag .. ": a second tap stops")
		run("DoomRun", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftShift })
		frames(1 / 30, 2)
		check(humanoid.WalkSpeed == moves.sprint, tag .. ": Shift through the action runs while held")
		run("DoomRun", Enum.UserInputState.End, { UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.LeftShift })
		frames(1 / 30, 2)
		check(humanoid.WalkSpeed == moves.walk, tag .. ": and walks again when released")
		run("DoomRun", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonL3 })
		frames(1 / 30, 2)
		check(humanoid.WalkSpeed == moves.sprint, tag .. ": the controller's stick click toggles running on")
		run("DoomRun", Enum.UserInputState.Begin, { UserInputType = Enum.UserInputType.Gamepad1, KeyCode = Enum.KeyCode.ButtonL3 })
		frames(1 / 30, 2)
		check(humanoid.WalkSpeed == moves.walk, tag .. ": and off again")
		humanoid:Destroy()
	end)

	-- The commander's sheet: your talents, active base and cards, readable in a
	-- match and never editable there.
	step("the commander's sheet in a match", function()
		local sheetProfile = veteranProfile()
		sheetProfile.talents = { roundGold = 3, killGold = 2, magnet = 1 }
		local base = Rules.BaseStats("outpost", 2)
		push(matchSnapshot(sheetProfile, "Wave", { base = { id = "outpost", level = 2, stats = base, wall = 0 }, cardMode = false }))
		check(named(gui, "SheetButton") ~= nil, tag .. ": the match HUD has a button for the commander's sheet")
		check(named(gui, "CommanderSheet") == nil, tag .. ": the sheet starts closed")
		clickNamed("SheetButton")
		check(named(gui, "CommanderSheet") ~= nil, tag .. ": the sheet opens in the middle of a match")
		check(named(gui, "SheetTab_talents") ~= nil and named(gui, "SheetTab_base") ~= nil and named(gui, "SheetTab_cards") == nil, tag .. ": tabs: talents and base, no cards outside the cards mode")
		check(named(gui, "TalentReadOnlyNote") ~= nil, tag .. ": the talents say they only change in the lobby")
		check(named(gui, "TalentNode_roundGold") ~= nil and named(gui, "TalentNode_globalMagnet") ~= nil, tag .. ": the whole tree is drawn, capstone included")
		check(countNamed(gui, "UpgradeTalent_roundGold") == 0 and named(gui, "TalentOverview") == nil, tag .. ": nothing can be spent in a match")
		check(countNamed(gui, "ResetTalents") == 0 and findButton(gui, "Redistribuir") == nil, tag .. ": and nothing can be reset")
		clickNamed("TalentNode_globalMagnet")
		local card = named(gui, "Talent_globalMagnet")
		check(card ~= nil and string.find(named(card, "TalentNowNext").Text, "inativo", 1, true) ~= nil, tag .. ": a talent card says whether the capstone is active, got " .. tostring(card and named(card, "TalentNowNext").Text))
		check(card ~= nil and named(card, "UpgradeTalent_globalMagnet") == nil, tag .. ": the card has no upgrade button")
		clickNamed("SheetTab_base")
		check(string.find(named(gui, "SheetBaseName").Text, Catalog.Bases.outpost.name.pt, 1, true) ~= nil, tag .. ": the base tab names the active base")
		check(string.find(named(gui, "SheetBaseName").Text, "2 / 5", 1, true) ~= nil, tag .. ": and its level")
		check(named(gui, "SheetBaseNote") ~= nil, tag .. ": and says it only changes in the lobby")
		clickNamed("SheetUpgradeBase")
		check(named(gui, "CommanderSheet") == nil and named(gui, "BaseUpgrade") ~= nil, tag .. ": the upgrade button hands over to the base upgrade, closing the sheet")
		named(gui, "BaseUpgrade"):Destroy()
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.C }, false)
		check(named(gui, "CommanderSheet") ~= nil, tag .. ": the C key opens the sheet")
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.C }, false)
		check(named(gui, "CommanderSheet") == nil, tag .. ": and closes it")
		-- The cards mode adds a tab with the cards picked so far.
		push(matchSnapshot(sheetProfile, "Wave", { base = { id = "outpost", level = 2, stats = base, wall = 0 }, cardMode = true, cards = { "sharpen", "sharpen", "income" } }))
		clickNamed("SheetButton")
		check(named(gui, "SheetTab_cards") ~= nil, tag .. ": the cards mode gets a cards tab")
		clickNamed("SheetTab_cards")
		check(named(gui, "SheetCard_sharpen") ~= nil and string.find(textOf(named(gui, "SheetCard_sharpen")), "×2", 1, true) ~= nil and named(gui, "SheetCard_income") ~= nil, tag .. ": each picked card is listed with its stacks")
		clickNamed("CloseSheet")
		check(named(gui, "CommanderSheet") == nil, tag .. ": the close button closes the sheet")
		push(matchSnapshot(sheetProfile, "Preparing"))
		push(lobbySnapshot(veteranProfile()))
	end)

	-- The hero page is not a photograph either: the hero breathes and, every few
	-- seconds and whenever it is tapped, shows its move.
	step("the hero page shows a living hero", function()
		local function findRoot(node)
			for _, child in ipairs(node:GetChildren()) do
				if child.Name == "HumanoidRootPart" then return child end
				local deeper = findRoot(child)
				if deeper then return deeper end
			end
		end
		local function armY(live)
			local hand
			for _, item in ipairs(live:GetDescendants()) do if item.Name == "RightHand" then hand = item end end
			return hand and hand.CFrame.Position.Y
		end
		push(lobbySnapshot(veteranProfile()))
		fx({ kind = "OpenPanel", panel = "hero", heroId = "ironman", hud = true })
		local live = named(gui, "HeroLive")
		check(live ~= nil and findRoot(live) ~= nil, tag .. ": the hero page shows the jointed figure")
		if live then
			local low, high = math.huge, -math.huge
			for _ = 1, 150 do
				frames(1 / 30, 1)
				local y = armY(live)
				if y then low, high = math.min(low, y), math.max(high, y) end
			end
			check(high - low > 0.3, tag .. ": the hero's arms move on their own over time, range " .. tostring(high - low))
			local tap = named(gui, "HeroLiveTap")
			check(tap ~= nil, tag .. ": the portrait can be tapped")
			if tap then tap.Activated:Fire() flush() end
			check(live ~= nil and named(gui, "HeroLive") ~= nil, tag .. ": a tap keeps the hero on stage")
		end
		clickNamed("CloseContext")
		-- Reduced effects keeps the still picture.
		local calm = veteranProfile()
		calm.settings.lowFX = true
		push(lobbySnapshot(calm))
		fx({ kind = "OpenPanel", panel = "hero", heroId = "ironman", hud = true })
		check(named(gui, "HeroLive") == nil, tag .. ": with reduced effects the hero page keeps a still portrait")
		clickNamed("CloseContext")
		push(lobbySnapshot(veteranProfile()))
	end)

	step("training: the arrows teach one lesson at a time", function()
		local trainee = veteranProfile()
		trainee.loadout = { "ironman", "hawkeye" }
		local function mine(level, id)
			return { id = id or "tt1", heroId = "ironman", ownerId = LOCAL_ID, level = level, position = v3(-28, 0, -40), priority = "First", damage = 26, range = 28.8, rate = 1.2,
				upgradeCost = level < 5 and 350 or 0, invested = 250, base = { damage = 26, range = 28.8, rate = 1.2 } }
		end
		local function teach(phase, extra) push(matchSnapshot(trainee, phase, extra)); frames(1 / 30, 3) end
		local function lesson()
			local card = named(gui, "TutorialCard")
			local text = card and named(card, "TutorialText")
			return text and text.Text or ""
		end
		local idle = { modeId = "tutorial", wave = 0, completedWaves = 0, cash = 600, towers = {}, ability = { id = Catalog.Heroes.ironman.ability, heroId = "ironman", rank = 1, target = "area", cooldown = 0, cooldownTotal = 60, radius = 20 } }
		teach("Preparing", idle)
		check(string.find(lesson(), "herói", 1, true) ~= nil or string.find(lesson(), "hero", 1, true) ~= nil, tag .. ": the first lesson is placing a hero, got " .. lesson())
		check(named(gui, "TutorialPointer") ~= nil, tag .. ": a pointer sits over the hero card")
		check(named(workspace, "TutorialArrow") ~= nil, tag .. ": an arrow marks a legal spot beside the road")
		-- Picking the hero changes the lesson to the spot; pinning it, to CONFIRM.
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.One, Position = v3(0, 0, 0) }, false)
		frames(1 / 30, 3)
		check(string.find(lesson(), "ponto", 1, true) ~= nil or string.find(lesson(), "spot", 1, true) ~= nil, tag .. ": with the hero picked the lesson points at the spot, got " .. lesson())
		rayHit = { Position = v3(-28, 0, -40), Instance = workspace }
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, Position = v3(400, 300, 0) }, false)
		frames(1 / 30, 3)
		check(string.find(lesson(), "CONFIRM", 1, true) ~= nil, tag .. ": with the spot pinned the lesson is to confirm, got " .. lesson())
		rayHit = nil
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Escape, Position = v3(0, 0, 0) }, false)
		frames(1 / 30, 2)
		idle.towers = { mine(1) }
		teach("Preparing", idle)
		check(string.find(lesson(), "PRONTO", 1, true) ~= nil, tag .. ": then calling the wave, got " .. lesson())
		idle.wave, idle.cash = 1, 100
		teach("Wave", idle)
		check(string.find(lesson(), "Ouro", 1, true) ~= nil, tag .. ": then collecting Gold for the upgrade, got " .. lesson())
		idle.cash = 1000
		teach("Wave", idle)
		check(string.find(lesson(), "Evolua", 1, true) ~= nil, tag .. ": then upgrading the tower, got " .. lesson())
		idle.towers = { mine(2) }
		teach("Wave", idle)
		check(string.find(lesson(), "poder", 1, true) ~= nil, tag .. ": then the leader's power, got " .. lesson())
		idle.ability.cooldown = 30
		teach("Wave", idle)
		check(string.find(lesson(), "segundo", 1, true) ~= nil, tag .. ": then a second hero, got " .. lesson())
		idle.towers = { mine(2), mine(1, "tt2") }
		teach("Wave", idle)
		check(string.find(lesson(), "Sobreviva", 1, true) ~= nil, tag .. ": then the lesson is to survive, got " .. lesson())
		push(matchSnapshot(trainee, "Wave", { modeId = "normal" }))
		frames(1 / 30, 3)
		check(named(gui, "TutorialCard") == nil and named(workspace, "TutorialArrow") == nil, tag .. ": a real match carries no lesson")
	end)

	step("after the training, two errands: the first chest, then the campaign", function()
		local fresh = veteranProfile()
		fresh.tutorialComplete = true
		fresh.gold = 1500
		fresh.stats = { waves = 12, bosses = 1, wins = 1, matches = 1, goldEarned = 400, chests = 0 }
		fresh.campaign = {}
		push(lobbySnapshot(fresh))
		frames(1 / 30, 3)
		local function errand()
			local card = named(gui, "TutorialCard")
			local text = card and named(card, "TutorialText")
			return text and text.Text or ""
		end
		check(string.find(errand(), "baú", 1, true) ~= nil, tag .. ": a trained commander with Gold is sent to open the first chest, got " .. errand())
		check(named(workspace, "TutorialArrow") ~= nil, tag .. ": an arrow marks the summon hall")
		fresh.stats.chests = 1
		push(lobbySnapshot(fresh))
		frames(1 / 30, 3)
		check(string.find(errand(), "CAMPANHA", 1, true) ~= nil, tag .. ": then to the campaign portal, got " .. errand())
		fresh.stats.matches = 2
		push(lobbySnapshot(fresh))
		frames(1 / 30, 3)
		check(named(gui, "TutorialCard") == nil, tag .. ": after the first real match the errands are over")
		local veteran = veteranProfile()
		push(lobbySnapshot(veteran))
		frames(1 / 30, 3)
		check(named(gui, "TutorialCard") == nil, tag .. ": a profile without the stats gets no errand")
		-- Back to the battle the next steps expect.
		push(matchSnapshot(veteranProfile(), "Wave"))
		frames(1 / 30, 2)
	end)

	step("the map of the day wears a ribbon in the play menu", function()
		local snapshot = lobbySnapshot(veteranProfile())
		snapshot.featured = { mapId = "manhattan", bonus = 0.25, endsAt = os.time() + 3600 }
		push(snapshot)
		fx({ kind = "OpenPanel", panel = "modes", hud = true })
		check(contextOpen(), tag .. ": the play menu opens")
		check(countNamed(gui, "FeaturedRibbon") == 1, tag .. ": exactly one campaign card carries the map-of-the-day ribbon, got " .. countNamed(gui, "FeaturedRibbon"))
		click("×")
		push(lobbySnapshot(veteranProfile()))
		fx({ kind = "OpenPanel", panel = "modes", hud = true })
		check(countNamed(gui, "FeaturedRibbon") == 0, tag .. ": no ribbon without a featured map")
		click("×")
		push(matchSnapshot(veteranProfile(), "Wave"))
		frames(1 / 30, 2)
	end)

	step("a mutated wave is announced in the preview and by a banner", function()
		local function anyLabel(text)
			for _, item in ipairs(gui:GetDescendants()) do
				if type(item.Text) == "string" and string.find(item.Text, text, 1, true) then return item end
			end
			return nil
		end
		push(matchSnapshot(veteranProfile(), "Preparing", { mutation = "rush" }))
		frames(1 / 30, 2)
		check(anyLabel("CORRIDA") ~= nil, tag .. ": the preview names the mutation")
		fx({ kind = "Mutation", mutationId = "swarm" })
		check(named(overlays, "CelebrationBanner") ~= nil and anyLabel("ENXAME") ~= nil, tag .. ": a banner announces the mutated wave")
		push(matchSnapshot(veteranProfile(), "Preparing", {}))
		frames(1 / 30, 2)
		check(anyLabel("CORRIDA") == nil, tag .. ": an ordinary wave carries no mutation line")
		push(matchSnapshot(veteranProfile(), "Wave"))
		frames(1 / 30, 2)
	end)

	step("squad pings: a long press marks the ground, only in a group", function()
		local before = #actions
		local function pings() local n = 0 for _, a in ipairs(actions) do if a == "Ping" then n += 1 end end return n end
		local start = pings()
		-- partySize 2 in the fixture: a long press on the ground sends a Ping.
		rayHit = { Position = v3(10, 0, 20), Instance = workspace }
		input.TouchLongPress:Fire({ Vector2.new(300, 300) }, Enum.UserInputState.Begin, false)
		flush()
		check(pings() == start + 1, tag .. ": a long press in a squad sends a ping")
		check(actionPayloads.Ping ~= nil and typeof(actionPayloads.Ping.position) == "Vector3" and actionPayloads.Ping.position.Y == 0, tag .. ": the ping carries a ground point only")
		fx({ kind = "Ping", position = v3(10, 0, 20), name = "Ally", ownerId = ALLY_ID, slot = 2 })
		local marker = workspace:FindFirstChild("DoomClientVisuals") and named(workspace:FindFirstChild("DoomClientVisuals"), "PingMarker")
		local seen = {}
		for _, item in ipairs(workspace:FindFirstChild("DoomClientVisuals"):GetChildren()) do seen[#seen + 1] = item.Name end
		check(marker ~= nil, tag .. ": a ping from a squad mate draws a marker (" .. table.concat(seen, ",") .. ")")
		-- A long press with a hero selected is placement, not a ping; alone there is nobody to tell.
		local solo = matchSnapshot(veteranProfile(), "Wave", { partySize = 1 })
		push(solo)
		local count = pings()
		input.TouchLongPress:Fire({ Vector2.new(300, 300) }, Enum.UserInputState.Begin, false)
		flush()
		check(pings() == count, tag .. ": alone, a long press sends no ping")
		rayHit = nil
		push(matchSnapshot(veteranProfile(), "Wave"))
		frames(1 / 30, 2)
	end)

	step("each owned tower carries its next upgrade above it", function()
		local function board(id) return playerGui:FindFirstChild("Upgrade_" .. id) end
		local function green(c) local g = UILayout.Colors.green; return c ~= nil and math.abs(c.R - g.R) + math.abs(c.G - g.G) + math.abs(c.B - g.B) < 0.01 end
		check(board("t1") ~= nil and board("t2") ~= nil, tag .. ": the player's upgradable towers get an upgrade button in the world")
		check(board("t3") == nil, tag .. ": a finished level-5 tower has none")
		check(board("t4") == nil, tag .. ": an ally's tower has none")
		local first = board("t1") and board("t1"):FindFirstChildOfClass("TextButton")
		check(first ~= nil and string.find(first.Text, "350", 1, true) ~= nil, tag .. ": the button shows the upgrade cost, got " .. tostring(first and first.Text))
		check(first ~= nil and green(first.BackgroundColor3), tag .. ": an affordable upgrade is green")
		local before = #actions
		if first then first.Activated:Fire(); flush() end
		local sent = false
		for index = before + 1, #actions do if actions[index] == "UpgradeTower" then sent = true end end
		check(sent, tag .. ": tapping it sends UpgradeTower")
		local second = board("t2") and board("t2"):FindFirstChildOfClass("TextButton")
		check(second ~= nil and string.find(second.Text, "EVOLUIR", 1, true) ~= nil, tag .. ": a level-4 tower offers to evolve")
		if second then second.Activated:Fire(); flush() end
		check(frameAt(main, layout.tower) ~= nil, tag .. ": evolving opens the panel where the branch is chosen")
		click("×")
		push(matchSnapshot(profile, "Preparing", { cash = 100 }))
		first = board("t1") and board("t1"):FindFirstChildOfClass("TextButton")
		check(first ~= nil and not green(first.BackgroundColor3), tag .. ": an upgrade the player cannot afford is not green")
		push(matchSnapshot(profile, "Preparing"))
	end)

	local function selectTower(id)
		local model
		for _, candidate in ipairs(workspace:FindFirstChild("DoomWorld").Towers:GetChildren()) do
			if candidate:GetAttribute("TowerId") == id then model = candidate end
		end
		rayHit = { Instance = model and model:FindFirstChild("UpperTorso", true), Position = v3(0, 0, 0) }
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown, Position = v3(10, 10, 0) }, false)
		flush()
		return frameAt(main, layout.tower)
	end

	step("the tower panel in every state", function()
		check(selectTower("t1") ~= nil, tag .. ": an owned tower opens its panel in the " .. layout.towerVariant .. " slot")
		local upgradeLine = false
		for _, item in ipairs(gui:GetDescendants()) do
			if type(item.Text) == "string" and string.find(item.Text, "Melhoria 2/5", 1, true) then upgradeLine = true end
		end
		check(upgradeLine, tag .. ": a tower's in-match upgrade reads as Melhoria, not a level")
		local stats = named(gui, "TowerStats")
		check(stats ~= nil and string.find(stats.Text, "→ 38", 1, true) ~= nil and string.find(stats.Text, "→ 30.6", 1, true) ~= nil,
			tag .. ": the panel shows damage and range as before -> after, got " .. tostring(stats and stats.Text))
		click("MELHORAR")
		check(asked("UpgradeTower"), tag .. ": the upgrade button reaches the server")
		click("Alvo:")
		check(asked("SetPriority"), tag .. ": targeting cycles")
		check(selectTower("t2") ~= nil, tag .. ": a level 4 tower offers both specializations")
		check(findButton(gui, "Precisão absoluta") ~= nil and findButton(gui, "Flechas explosivas") ~= nil, tag .. ": both branch buttons are shown")
		local branchOne = named(gui, "TowerBranch1")
		check(branchOne ~= nil and string.find(branchOne.Text, "DANO 96", 1, true) ~= nil, tag .. ": each specialization shows the damage it gives, got " .. tostring(branchOne and branchOne.Text))
		check(selectTower("t3") ~= nil, tag .. ": a maxed tower shows its specialization")
		check(selectTower("t4") ~= nil, tag .. ": an ally's tower opens read-only")
		check(findButton(gui, "Vender") == nil, tag .. ": an ally's tower cannot be sold from here")
		check(selectTower("t1") ~= nil, tag .. ": reselecting an owned tower works")
		click("Vender")
		check(asked("SellTower"), tag .. ": selling reaches the server")
	end)

	step("wave, boss and battle protocol", function()
		push(matchSnapshot(profile, "Wave", {
			enemies = 12, prepRemaining = 0,
			boss = { id = "lizard", name = { pt = "Lagarto infectado", en = "Infected Lizard" }, hp = 1800, maxHP = 2453, phase = 2, hint = { pt = "Concentre dano", en = "Focus fire" } },
			cardOffers = { "sharpen", "quickDraw", "warChest" },
		}))
		check(frameAt(main, layout.boss) ~= nil, tag .. ": the boss banner sits in its slot")
		local P = UILayout.protocolLayout(SCREEN.w, SCREEN.h)
		local veil = overlays and overlays:GetChildren()[#overlays:GetChildren()]
		check(veil ~= nil and frameAt(veil, P.panel) ~= nil, tag .. ": the protocol chooser sits where protocolLayout puts it")
		local choices = 0
		for _, item in ipairs(veil and veil:GetDescendants() or {}) do
			if rawget(item, "__class") == "TextButton" and string.find(item.Text or "", "ESCOLHER", 1, true) == 1 then
				choices += 1
				local r = screenRect(item, gui, SCREEN)
				check(shown(item, gui) and r ~= nil and r.x >= 0 and r.y >= 0
					and r.x + r.w <= SCREEN.w and r.y + r.h <= SCREEN.h and r.h >= 40,
					tag .. ": every card choice remains visible and comfortably tappable")
			end
		end
		check(choices == 3, tag .. ": all three offered cards have visible choices")
		click("ESCOLHER")
		check(asked("ChooseCard"), tag .. ": a protocol can be chosen")
		push(matchSnapshot(profile, "Wave", { enemies = 12, cardOffers = {} }))
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q, Position = v3(0, 0, 0) }, false)
		flush()
		rayHit = { Instance = workspace:FindFirstChild("DoomWorld").Towers:GetChildren()[1]:FindFirstChild("UpperTorso", true), Position = v3(0, 0, 0) }
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown, Position = v3(5, 5, 0) }, false)
		flush()
		click("CONFIRMAR")
		check(asked("CastSkill"), tag .. ": leader area ability is cast after confirmation")
	end)

	step("every FX event the client handles", function()
		local enemies = {
			{ id = 1, enemyId = "zombie", position = v3(-40, 0, -60), hp = 50, maxHP = 50 },
			{ id = 2, enemyId = "flyer", position = v3(-30, 0, -15), hp = 70, maxHP = 70 },
			{ id = 3, enemyId = "armored", position = v3(0, 0, -15), hp = 126, maxHP = 126 },
			{ id = 4, enemyId = "lizard", position = v3(32, 0, 0), hp = 2453, maxHP = 2453 },
			{ id = 5, enemyId = "doom", position = v3(32, 0, 20), hp = 3522, maxHP = 3522 },
		}
		fx({ kind = "EnemySync", enemies = enemies })
		frames(1 / 30, 3)
		local flyingTorso
		for _,model in ipairs(workspace.DoomClientVisuals:GetChildren()) do
			local torso=model:FindFirstChild("UpperTorso")
			if torso and torso.Position.X < -20 and torso.Position.Z > -20 then flyingTorso=torso end
		end
		check(flyingTorso and flyingTorso.Position.Y>7.7 and flyingTorso.Position.Y<8.3,tag..": airborne visual shares the eight-stud shot height")
		for _, enemy in ipairs(enemies) do enemy.hp -= 20; enemy.position += v3(2, 0, 0) end
		fx({ kind = "EnemySync", enemies = enemies })
		frames(1 / 30, 3)
		fx({ kind = "Shot", from = v3(10, 4, 10), to = v3(-40, 2, -60), color = Color3.fromRGB(220, 48, 51), towerId = "t1" })
		fx({ kind = "Pulse", position = v3(0, 0, 0), radius = 8, color = Color3.fromRGB(100, 200, 100) })
		fx({ kind = "Pulse", position = v3(32, 0, 0), radius = 26, color = Color3.fromRGB(255, 170, 64), duration = 2 })
		local discs, squares = 0, 0
		for _, item in ipairs(workspace:FindFirstChild("DoomClientVisuals"):GetChildren()) do
			if item.Size and item.Size.Y >= 5 and item.Size.Y == item.Size.Z then
				if item.Shape == Enum.PartType.Cylinder and item.Size.X < 1 then discs += 1 else squares += 1 end
			end
		end
		check(discs >= 2 and squares == 0, tag .. ": area pulses are drawn as discs, not squares (" .. discs .. " discs, " .. squares .. " squares)")
		fx({kind="Pulse",position=v3(32,0,0),followEnemyId=4,radius=24,duration=2,warningText={pt="PODER DO CHEFE",en="BOSS POWER"},color=Color3.fromRGB(255,170,64)})
		frames(1/30, 2)
		local warningPart
		for _,item in ipairs(workspace.DoomClientVisuals:GetChildren()) do if item:FindFirstChild("Warning") and item.Warning.Enabled then warningPart=item end end
		check(warningPart and warningPart.Warning.Text.Text:find("PODER DO CHEFE",1,true),tag..": boss warning has a readable countdown")
		local warningX=warningPart and warningPart.Position.X or 0
		enemies[4].position+=v3(8,0,0)
		fx({kind="EnemySync",enemies=enemies})
		frames(1/30, 4)
		check(warningPart and warningPart.Position.X>warningX+1,tag..": boss danger area follows the moving boss")
		fx({ kind = "CoinSpawn", id = "c1", position = v3(1, 0, 1), value = 10 })
		fx({ kind = "Breach", position = v3(88, 0, 66), damage = 3, baseHP = 83, shake = 0.5 })
		fx({ kind = "Notice", text = { pt = "Aviso", en = "Notice" }, tone = "boss" })
		root.CFrame = CFrame.new(1, 3, 1)
		frames(1 / 30, 20)
		check(asked("CollectCoin"), tag .. ": walking over a coin asks to collect it")
		local t1
		for _, candidate in ipairs(workspace:FindFirstChild("DoomWorld").Towers:GetChildren()) do
			if candidate:GetAttribute("TowerId") == "t1" then t1 = candidate end
		end
		local chest = t1 and t1:FindFirstChild("UpperTorso", true)
		local look = chest and chest.CFrame.LookVector
		local want = (v3(-40, 0, -60) - v3(10, 0, 10)).Unit
		check(look ~= nil and look.X * want.X + look.Z * want.Z > 0.95, tag .. ": a hero turns to face what it shoots")
		check(t1 and t1.Platform.CFrame.LookVector.Z < -0.99, tag .. ": the platform the server owns never turns")
		-- The jointed figure: the right hand hangs on shoulder, elbow and wrist.
		local hand = t1 and t1:FindFirstChild("RightHand", true)
		local handRest = hand and hand.CFrame
		fx({kind="Shot",towerId="t1",from=v3(10,4,10),to=v3(-40,2,-60),color=Color3.fromRGB(220,48,51)})
		frames(0.1, 2)
		check(hand and (hand.Position-handRest.Position).Magnitude > 0.025, tag .. ": firing moves the hand around its authored shoulder")
		frames(0.1, 5)
		check(hand and (hand.Position-handRest.Position).Magnitude < 0.001, tag .. ": firing restores the pose without accumulating displacement")
		fx({ kind = "CoinRemove", id = "c1" })
		for _,heroId in ipairs(Catalog.HeroOrder) do
			local ability=Catalog.Abilities[Catalog.Heroes[heroId].ability]
			fx({kind="Ability",heroId=heroId,abilityId=ability.id,abilityKind=ability.kind,position=v3(0,0,0),radius=12,duration=2,color=Color3.fromRGB(110,180,255),points={v3(3,0,2)}})
		end

		-- Every hero has its own attack VFX in Effects:_heroShot, keyed off the
		-- firing tower's HeroId attribute. t1/t2/t4 already cover ironman,
		-- hawkeye and spiderman; build one throwaway tower per remaining hero
		-- and fire a Shot at it, so a typo in any branch crashes this test
		-- instead of shipping silently. The pooled effect budget is shared and
		-- capped, so the ability-FX loop just above is drained first, or its
		-- leftovers would silently eat the shots this checks for.
		frames(1 / 30, 60)
		local shotCovered = { ironman = true, hawkeye = true, spiderman = true }
		local function combatEffects()
			local count = 0
			for _, item in ipairs(workspace:FindFirstChild("DoomClientVisuals"):GetChildren()) do
				if item.Name == "CombatEffect" then count += 1 end
			end
			return count
		end
		-- The ability effects above may still be fading: wait until the pool is empty.
		for _ = 1, 40 do
			if combatEffects() == 0 then break end
			frames(1 / 30, 15)
		end
		local shotIndex, silent = 0, {}
		for _, heroId in ipairs(Catalog.HeroOrder) do
			if not shotCovered[heroId] then
				shotIndex += 1
				local vfxTowerId = "vfx" .. shotIndex
				world:MakeTower(vfxTowerId, heroId, v3(70 + shotIndex, 0, 70), LOCAL_ID)
				local before = combatEffects()
				fx({ kind = "Shot", from = v3(70 + shotIndex, 4, 70), to = v3(70 + shotIndex, 2, 50), color = Color3.fromRGB(200, 200, 200), towerId = vfxTowerId })
				frames(1 / 30, 1)
				if combatEffects() <= before then table.insert(silent, heroId) end
				-- Let this hero's effects expire so the shared pool never starves the next one.
				frames(1 / 30, 20)
			end
		end
		check(#silent == 0, tag .. ": every hero's shot VFX actually renders something, not just avoids crashing: silent " .. table.concat(silent, ", "))
		fx({kind="CardPicked",cardId="sharpen",rarity="common"})
		fx({kind="EnemyDown",id=4,enemyId="lizard",position=v3(32,0,0),boss=true})
		fx({ kind = "EnemySync", enemies = { enemies[1] } })
		frames(0.5, 4)
		fx({ kind = "Clear" })
		frames(1 / 30, 2)
	end)

	step("heroes move between shots: breathing, upgrade, cast and interruption", function()
		push(matchSnapshot(profile, "Wave", { enemies = 0 }))
		world:MakeTower("anim1", "ironman", v3(20, 0, 30), LOCAL_ID)
		local model
		for _, candidate in ipairs(workspace:FindFirstChild("DoomWorld").Towers:GetChildren()) do
			if candidate:GetAttribute("TowerId") == "anim1" then model = candidate end
		end
		local figure = model and model:FindFirstChild("HeroFigure")
		local body = figure and figure:FindFirstChild("UpperTorso")
		local hand = figure and figure:FindFirstChild("RightHand")
		check(body ~= nil and hand ~= nil and figure:GetAttribute("HeroRig") == true, tag .. ": the hero figure is jointed")
		if not (body and hand) then return end
		local restBody, restHand = body.Position, hand.Position
		-- Breathing only runs near the camera; look at this hero from close by.
		workspace.CurrentCamera.CFrame = CFrame.new(20, 30, 70)
		local drift = 0
		for _ = 1, 12 do
			frames(1 / 10, 1)
			drift = math.max(drift, math.abs(body.Position.Y - restBody.Y))
		end
		check(drift > 0.01 and drift < 0.2, tag .. ": an idle hero near the camera breathes, gently, got " .. string.format("%.3f", drift))
		fx({ kind = "TowerUpgrade", towerId = "anim1", level = 2 })
		frames(0.12, 2)
		check(body.Position.Y > restBody.Y + 0.4, tag .. ": an upgraded hero hops off its pedestal")
		frames(0.2, 4)
		check(math.abs(body.Position.Y - restBody.Y) < 0.15, tag .. ": and lands back where it stood")
		fx({ kind = "Ability", abilityId = "repulsorBarrage", abilityKind = "blast", heroId = "ironman", ownerId = LOCAL_ID, position = v3(0, 0, 0), radius = 10, color = Color3.fromRGB(255, 80, 80) })
		frames(0.12, 3)
		check(hand.Position.Y > restHand.Y + 0.5, tag .. ": the leader's hero raises its arms as the ability goes off")
		fx({ kind = "TowersStunned", towerIds = { "anim1" }, duration = 1 })
		frames(1 / 30, 2)
		local visuals = workspace:FindFirstChild("DoomClientVisuals")
		check(countNamed(visuals, "StunStar") == 3, tag .. ": an interrupted tower shows stars circling its head")
		frames(0.3, 5)
		check(countNamed(visuals, "StunStar") == 0, tag .. ": the stars go when the interruption ends")
		fx({ kind = "Clear" })
		frames(1 / 30, 2)
	end)

	step("final art: enemies are cloned from their template and heroes shoot from their Muzzle", function()
		local art = Instance.new("Folder")
		art.Name, art.Parent = "DoomArt", replicated
		local enemies = Instance.new("Folder")
		enemies.Name, enemies.Parent = "Enemies", art
		local template = Instance.new("Model")
		template.Name, template.Parent = "brute", enemies
		local body = Instance.new("Part")
		body.Name, body.Size, body.CFrame, body.Parent = "BruteArt", v3(3, 6, 2), CFrame.new(0, 3, 0), template
		template.PrimaryPart = body
		push(matchSnapshot(profile, "Wave", { enemies = 1 }))
		fx({ kind = "EnemySync", enemies = { { id = 901, enemyId = "brute", position = v3(30, 0, -15), hp = 100, maxHP = 172, st = 0 } } })
		frames(1 / 30, 2)
		local visuals = workspace:FindFirstChild("DoomClientVisuals")
		check(countNamed(visuals, "BruteArt") == 1, tag .. ": an enemy with final art is cloned from it")
		local cloned = named(visuals, "BruteArt")
		check(cloned ~= nil and math.abs(cloned.Position.X - 30) < 1, tag .. ": and walks where the server puts it")
		fx({ kind = "Clear" })
		frames(1 / 30, 2)
		art:Destroy()
		-- A tower whose figure is final art fires from the Muzzle it names.
		local model
		for _, candidate in ipairs(workspace:FindFirstChild("DoomWorld").Towers:GetChildren()) do
			if candidate:GetAttribute("TowerId") == "t1" then model = candidate end
		end
		-- Swap the generated figure for a piece of final art, then put it back.
		local generated = model:FindFirstChild("HeroFigure")
		if generated then generated.Parent = nil end
		local figure = Instance.new("Model")
		figure.Name, figure.Parent = "HeroFigure", model
		figure:SetAttribute("HeroArt", true)
		local muzzle = Instance.new("Attachment")
		muzzle.Name, muzzle.WorldPosition, muzzle.Parent = "Muzzle", v3(11, 7, 12), figure
		push(matchSnapshot(profile, "Wave", { enemies = 0 }))
		local before = #workspace:FindFirstChild("DoomClientVisuals"):GetChildren()
		fx({ kind = "Shot", from = v3(10, 4, 10), to = v3(14, 2, -15), color = Color3.fromRGB(200, 200, 200), towerId = "t1", heroId = "ironman" })
		local fromMuzzle = false
		for _, item in ipairs(workspace:FindFirstChild("DoomClientVisuals"):GetChildren()) do
			if item.Name == "CombatEffect" and item.Size and item.Size.Z > 1 then
				local startPoint = item.CFrame * v3(0, 0, item.Size.Z / 2)
				if (startPoint - v3(11, 7, 12)).Magnitude < 0.5 then fromMuzzle = true end
			end
		end
		check(fromMuzzle, tag .. ": the shot leaves from the art's Muzzle")
		figure:Destroy()
		if generated then generated.Parent = model end
		fx({ kind = "Clear" })
		frames(1 / 30, 2)
	end)

	step("only dock icons with news move", function()
		local calm = veteranProfile()
		calm.gold = 0
		calm.rewards = { claimable = 0 }
		push(lobbySnapshot(calm))
		local function iconY(id)
			local button = named(gui, "Nav_" .. id)
			local icon = button and named(button, "NavIcon")
			return icon and icon.Position.Y.Offset
		end
		local samples = {}
		for _ = 1, 6 do
			frames(0.2, 1)
			for _, id in ipairs({ "inventory", "premium" }) do
				local y = iconY(id)
				if y then samples[id] = samples[id] or {}; table.insert(samples[id], y) end
			end
		end
		local moved = false
		for _, list in pairs(samples) do
			for _, y in ipairs(list) do if math.abs(y - list[1]) > 0.01 then moved = true end end
		end
		check(next(samples) ~= nil and not moved, tag .. ": dock icons with nothing waiting stay still")
	end)

	step("every hero's shot has a weapon sound", function()
		local EffectsModule = require(effectsScript)
		local missing = {}
		for _, heroId in ipairs(Catalog.HeroOrder) do
			local cue = EffectsModule.ShotSound(heroId)
			if SharedConfig.Audio[cue] == nil or SharedConfig.BuiltinCues[cue] == nil then table.insert(missing, heroId .. ":" .. tostring(cue)) end
		end
		check(#missing == 0, tag .. ": every hero maps to a configured weapon cue with a built-in fallback: " .. table.concat(missing, ", "))
	end)

	step("enemy families read at a glance: links, reveal, summons and armour", function()
		push(matchSnapshot(profile, "Wave", { enemies = 4 }))
		local visuals = workspace:FindFirstChild("DoomClientVisuals")
		fx({ kind = "EnemySync", enemies = {
			{ id = 501, enemyId = "support", position = v3(10, 0, -15), hp = 100, maxHP = 100, st = 0 },
			{ id = 502, enemyId = "zombie", position = v3(14, 0, -15), hp = 40, maxHP = 40, st = 256, lk = 501 },
			{ id = 503, enemyId = "stealth", position = v3(20, 0, -15), hp = 60, maxHP = 60, st = 0 },
			{ id = 504, enemyId = "summoner", position = v3(26, 0, -15), hp = 190, maxHP = 190, st = 0, ch = 1 },
		} })
		frames(1 / 30, 2)
		check(countNamed(visuals, "SupportLink") == 1, tag .. ": a support is linked to the one enemy it hastens")
		local charges = 0
		for _, model in ipairs(visuals:GetChildren()) do
			if model.Name == "EnemyVisual" then charges += countNamed(model, "Charge") end
		end
		check(charges == 1, tag .. ": a summoner shows one orb per summons left, got " .. charges)
		local function cloakTransparency()
			for _, model in ipairs(visuals:GetChildren()) do
				local torso = model.Name == "EnemyVisual" and model:FindFirstChild("UpperTorso")
				local seen = torso and (torso.Transparency or 0)
				if seen and seen > 0 and seen < 0.5 then return seen end
			end
			return 0
		end
		check(cloakTransparency() > 0, tag .. ": a cloaked enemy is see-through")
		fx({ kind = "EnemySync", enemies = {
			{ id = 501, enemyId = "support", position = v3(10, 0, -15), hp = 100, maxHP = 100, st = 0 },
			{ id = 502, enemyId = "zombie", position = v3(14, 0, -15), hp = 40, maxHP = 40, st = 0 },
			{ id = 503, enemyId = "stealth", position = v3(20, 0, -15), hp = 60, maxHP = 60, st = 128 },
			{ id = 504, enemyId = "summoner", position = v3(26, 0, -15), hp = 190, maxHP = 190, st = 0, ch = 0 },
		} })
		frames(1 / 30, 2)
		check(countNamed(visuals, "SupportLink") == 0, tag .. ": the link goes when the haste ends")
		check(cloakTransparency() == 0, tag .. ": a revealed cloaked enemy turns solid")
		local spent = 0
		for _, model in ipairs(visuals:GetChildren()) do
			if model.Name == "EnemyVisual" then spent += countNamed(model, "Charge") end
		end
		check(spent == 0, tag .. ": a summoner with no summons left shows no orbs")
		local before = countNamed(visuals, "CombatEffect")
		fx({ kind = "Shot", from = v3(10, 4, 10), to = v3(14, 2, -15), color = Color3.fromRGB(200, 200, 200), towerId = "t1", armored = true })
		check(countNamed(visuals, "ArmorSpark") == 3, tag .. ": a hit on armour throws sparks")
		check(countNamed(visuals, "CombatEffect") >= before, tag .. ": the shot itself still renders")
		fx({ kind = "Clear" })
		frames(1 / 30, 2)
	end)

	step("enemies walk their road smoothly between syncs", function()
		push(matchSnapshot(veteranProfile(), "Wave", { enemies = 1 }))
		local road = Catalog.Maps.manhattan.paths[1]
		local start = v3(road[1][1], 0, road[1][2])
		fx({ kind = "EnemySync", enemies = { { id = 7701, enemyId = "runner", position = start, hp = 40, maxHP = 40, ri = 1, pg = 0, sp = 9 } } })
		local visuals = workspace:FindFirstChild("DoomClientVisuals")
		-- Where a figure stands: the middle of its parts, whatever its rig.
		local function walker()
			for _, model in ipairs(visuals:GetChildren()) do
				if model.Name == "EnemyVisual" then
					local sum, count = v3(0, 0, 0), 0
					for _, item in ipairs(model:GetDescendants()) do
						local position = item.Position
						if typeof(position) == "Vector3" and position.X == position.X then sum += position; count += 1 end
					end
					local middle = count > 0 and sum / count
					if middle and (v3(middle.X, 0, middle.Z) - start).Magnitude < 12 then return { Position = middle } end
				end
			end
			return nil
		end
		local steps, last = {}, nil
		for _ = 1, 6 do
			frames(1 / 30, 1)
			local torso = walker()
			local at = torso and v3(torso.Position.X, 0, torso.Position.Z)
			if at and last then table.insert(steps, (at - last).Magnitude) end
			last = at
		end
		local even = #steps == 5
		for _, stepLength in ipairs(steps) do
			-- 9 studs/s at 30 fps: about 0.3 studs every frame, never a hop or a stall.
			if stepLength < 0.15 or stepLength > 0.5 then even = false end
		end
		check(even, tag .. ": an enemy moves a steady step every frame between syncs, got " .. table.concat(steps, ", "))
		fx({ kind = "Clear" })
		frames(1 / 30, 2)
	end)

	step("reduced effects still runs every path", function()
		local calm = veteranProfile()
		calm.settings.lowFX = true
		push(matchSnapshot(calm, "Wave", { enemies = 1 }))
		fx({ kind = "EnemySync", enemies = { { id = 9, enemyId = "runner", position = v3(0, 0, 0), hp = 30, maxHP = 36 } } })
		fx({ kind = "EnemySync", enemies = { { id = 9, enemyId = "runner", position = v3(1, 0, 0), hp = 10, maxHP = 36 } } })
		fx({ kind = "Shot", from = v3(10, 4, 10), to = v3(0, 2, 0), color = Color3.fromRGB(1, 1, 1), towerId = "t2" })
		frames(1 / 30, 5)
	end)

	--========================================================================
	-- Results, language and resize
	--========================================================================
	step("results and the way back", function()
		local results = resultsSnapshot(profile)
		for _, heroId in ipairs(Catalog.HeroOrder) do results.results.mastery[heroId] = 50 end
		push(results)
		local banner = named(overlays, "CelebrationBanner")
		check(banner ~= nil and string.find(named(banner, "BannerTitle").Text, "VITÓRIA", 1, true) ~= nil, tag .. ": a win is announced with a big banner")
		local goldValue = named(gui, "RewardValue_2")
		check(goldValue ~= nil and goldValue.Text ~= "+1.500", tag .. ": the Gold reward starts counting up instead of appearing whole")
		frames(1 / 30, 60)
		check(goldValue.Text == "+1.500", tag .. ": the Gold counter lands exactly on the reward, got " .. tostring(goldValue.Text))
		push(results)
		check(countNamed(overlays, "CelebrationBanner") <= 1, tag .. ": a re-render of the same results never repeats the celebration")
		local back, body = named(gui, "ResultReturn"), named(gui, "ResultBody")
		check(back ~= nil and body ~= nil and back.Parent == body.Parent,
			tag .. ": return action remains outside the long rewards scroll")
		local backRect, bodyRect = screenRect(back, gui, SCREEN), screenRect(body, gui, SCREEN)
		check(backRect ~= nil and backRect.x >= 0 and backRect.y >= 0
			and backRect.x + backRect.w <= SCREEN.w and backRect.y + backRect.h <= SCREEN.h and backRect.h >= 44,
			tag .. ": returning to the lobby is reachable without scrolling the results")
		check(backRect ~= nil and bodyRect ~= nil and bodyRect.y + bodyRect.h <= backRect.y,
			tag .. ": the pinned return button has its own space below the reward scroll")
		check(named(gui, "ResultSeason") == nil, tag .. ": without a season status the end screen draws no season card")
		local withSeason = resultsSnapshot(veteranProfile({ seasonStatus = Rules.SeasonStatus({ id = 1, xp = Rules.SeasonThreshold(2) + 50, freeClaimed = 0, premiumClaimed = 0 }, false) }))
		push(withSeason)
		local seasonHint = named(gui, "ResultSeasonHint")
		check(named(gui, "ResultSeason") ~= nil and seasonHint ~= nil and string.find(seasonHint.Text, "2", 1, true) ~= nil, tag .. ": the end screen shows the season and the claims waiting")
		check(named(gui, "ResultFeatured") == nil, tag .. ": an ordinary map shows no map-of-the-day line")
		-- (The end screen redraws when the profile changes, so each variant carries its own Gold.)
		local featuredRun = resultsSnapshot(veteranProfile({ gold = 2511 }))
		featuredRun.results.featured = 1.25
		push(featuredRun)
		check(named(gui, "ResultFeatured") ~= nil and string.find(named(gui, "ResultFeatured").Text, "+25%", 1, true) ~= nil, tag .. ": the map of the day is named on the end screen")
		push(results)
		check(named(gui, "ResultParty") == nil, tag .. ": a solo run shows no party bonus")
		local partyRun = resultsSnapshot(veteranProfile({ gold = 2522 }))
		partyRun.results.party = 1.2
		push(partyRun)
		local partyLabel = named(gui, "ResultParty")
		check(partyLabel ~= nil and string.find(partyLabel.Text, "+20%", 1, true) ~= nil, tag .. ": a party's bonus is named on the end screen")
		push(results)
		local mvp = named(gui, "MvpName")
		check(mvp ~= nil and mvp.Text == "Ally" and named(gui, "ResultTeam_2") ~= nil, tag .. ": the end screen names the MVP and lists the squad")
		local again = named(gui, "ResultPlayAgain")
		local againRect = again and screenRect(again, gui, SCREEN)
		check(againRect ~= nil and againRect.y + againRect.h <= SCREEN.h and againRect.h >= 44, tag .. ": PLAY AGAIN sits beside the return button without scrolling")
		click("▶ JOGAR DE NOVO")
		check(asked("PlayAgain"), tag .. ": the results screen offers to play the same map again")
		click("LOBBY")
		check(asked("ReturnLobby"), tag .. ": the results screen returns to base")
		push(lobbySnapshot(profile))
	end)

	step("switching to English re-renders in English", function()
		local english = veteranProfile()
		english.settings.language = "en"
		push(lobbySnapshot(english))
		check(findButton(gui, "SETTINGS") ~= nil, tag .. ": the HUD speaks English after the switch")
		local village=workspace:FindFirstChild("DoomLobby")
		local desk=village:FindFirstChild("Board_maps").PrimaryPart
		check(desk.Board:FindFirstChildOfClass("TextLabel").Text:find("CHOOSE MAP",1,true)~=nil,
			tag..": service desk signage changes language")
		check(desk:FindFirstChildOfClass("ProximityPrompt").ObjectText=="CHOOSE MAP",
			tag..": service prompt changes language")
		local summon=village.HeroesHQ:FindFirstChild("SummonSign")
		local title,subtitle=summon:FindFirstChild("Title",true),summon:FindFirstChild("Subtitle",true)
		check(title.Text=="SUMMONING" and subtitle.Text=="HERO AND BASE CHESTS",tag..": summoning sign changes language")
		check(localPlayer.PlayerGui.PortalPicture_normal.MapTitle.Text==Catalog.Maps.manhattan.name.en,tag..": cloned map picture is localized")
		local status=village.Portal_normal.QueueSign2.QueueBoard.QueueStatus
		status:SetAttribute("LobbyTextPT","4/4 • LOTADO"); status:SetAttribute("LobbyTextEN","4/4 • FULL"); status.Text="4/4 • LOTADO"
		status:GetAttributeChangedSignal("LobbyTextEN"):Fire()
		status:GetPropertyChangedSignal("Text"):Fire()
		push(lobbySnapshot(english))
		check(status.Text=="4/4 • FULL",tag..": changing occupancy preserves the selected language")
		push(matchSnapshot(english, "Preparing"))
		check(findButton(gui, "READY") ~= nil, tag .. ": the match HUD speaks English too")
	end)

	step("rotating the device re-lays the HUD out", function()
		local rotated = { w = SCREEN.h + 58 > SCREEN.w and SCREEN.h + 120 or math.max(640, SCREEN.h), h = math.max(302, SCREEN.w - 400) }
		SCREEN.w, SCREEN.h = rotated.w, rotated.h
		main.AbsoluteSize = Vector2.new(rotated.w, rotated.h)
		main:GetPropertyChangedSignal("AbsoluteSize"):Fire()
		flush()
		local fresh = UILayout.matchLayout(rotated.w, rotated.h, { skills = 1, vip = true })
		check(frameAt(main, fresh.top) ~= nil, tag .. ": after a resize the top bar follows the new layout")
		local bad = offscreen(main, SCREEN)
		check(#bad == 0, tag .. ": after a resize everything is still on screen: " .. table.concat(bad, ", "))
	end)

	-- Automatic quality: two slow five-second windows in a row during a wave
	-- reduce the effects once; hitches and a recovered frame rate do not.
	step("automatic quality", function()
		local AutoQuality = require(clientModules.AutoQuality)
		local wave, reduced, reductions = true, false, 0
		local quality = AutoQuality.new({ active = function() return wave end, reduced = function() return reduced end, reduce = function() reductions += 1 end })
		local function run(seconds, fps) for _ = 1, math.floor(seconds * fps) do quality:Step(1 / fps) end end
		run(30, 60)
		check(reductions == 0, tag .. ": 60 fps never triggers it")
		run(7, 20)
		check(reductions == 0, tag .. ": one slow window is not enough")
		run(5, 60)
		run(10, 20)
		check(reductions == 0, tag .. ": a window back at speed resets the count")
		run(10, 20)
		check(reductions == 1, tag .. ": two slow windows in a row reduce the effects once, got " .. reductions)
		run(60, 15)
		check(reductions == 1, tag .. ": it never fires twice in a session")
		local hitchy = AutoQuality.new({ active = function() return true end, reduced = function() return false end, reduce = function() reductions += 100 end })
		for _ = 1, 400 do hitchy:Step(0.6) end
		check(reductions == 1, tag .. ": frames over half a second are hitches, not speed")
		wave = false
		local lobby = AutoQuality.new({ active = function() return wave end, reduced = function() return false end, reduce = function() reductions += 100 end })
		for _ = 1, 400 do lobby:Step(1 / 10) end
		check(reductions == 1, tag .. ": nothing counts outside a wave")
	end)

	-- A server frame's shots arrive as one Shots event and draw like lone ones.
	step("a batch of shots draws", function()
		push(matchSnapshot(profile, "Wave", { enemies = 4 }))
		fx({ kind = "Shots", shots = { { from = v3(10, 4, 10), to = v3(-30, 2, -50), color = Color3.fromRGB(220, 48, 51), towerId = "t1" },
			{ from = v3(-20, 4, 5), to = v3(-25, 2, -40), color = Color3.fromRGB(70, 160, 96), towerId = "t2", heroId = "hawkeye" } } })
		frames(1 / 30, 20)
	end)

	-- Studio's screen review (the stand-in RunService says IsStudio) draws every
	-- fixture screen; none may raise a Lua error or send anything to the server.
	step("the Studio review shows every screen", function()
		local Review = require(reviewScript)
		local problems, before = {}, #actions
		local realWarn, realPrint = warn, print
		warn = function(first, stage, problem)
			if first == "DOOM_REVIEW_ERROR" then table.insert(problems, tostring(stage) .. ": " .. tostring(problem)) end
		end
		print = function() end
		local ok, problem = xpcall(function()
			for _, stage in ipairs(Review.STAGES) do
				localPlayer:SetAttribute("DoomReview", stage)
				flush(); advance(1); flush()
			end
			localPlayer:SetAttribute("DoomReviewSize", "667x375")
			localPlayer:SetAttribute("DoomReview", "wave")
			flush()
			localPlayer:SetAttribute("DoomReviewSize", "")
			localPlayer:SetAttribute("DoomReview", "live")
			flush()
		end, debug.traceback)
		warn, print = realWarn, realPrint
		check(ok, tag .. ": the review tour runs: " .. tostring(problem))
		check(#problems == 0, tag .. ": every review stage draws without an error: " .. table.concat(problems, " | "))
		check(#actions == before, tag .. ": fixture screens send nothing to the server")
	end)

	check(#prompts <= 1, tag .. ": purchases are only prompted when a button is actually pressed")
end

for _, screen in ipairs({
	{ name = "android landscape", w = 640, h = 302 },
	{ name = "iphone landscape", w = 754, h = 311 },
	{ name = "laptop", w = 1280, h = 662 },
	{ name = "ipad", w = 1024, h = 710 },
	{ name = "desktop", w = 1920, h = 1022 },
	{ name = "phone portrait", w = 375, h = 609 },
}) do
	print("--- " .. screen.name .. " ---")
	session(screen)
end

print(string.format("%s client boot: %d checks, %d failures",
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error("client boot failed", 0) end
