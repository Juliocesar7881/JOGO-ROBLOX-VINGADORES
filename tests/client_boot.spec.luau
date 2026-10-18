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
	if className == "ImageLabel" then created.AbsoluteSize = Vector2.new(0,0) end
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
services.ReplicatedFirst = Instance.new("ReplicatedFirst")
local firstScript = Instance.new("LocalScript", services.ReplicatedFirst)
firstScript.Name = "DoomLoader"
moduleScript(firstScript, "ScreenArt", __SCREEN_ART__)
game.IsLoaded = function() return true end

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
		gift = { pending = ready and 1 or 0, sentToday = false, chestId = Catalog.Rewards.gift.chestId },
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
	function runService:Set3dRenderingEnabled(enabled) self.renderingEnabled = enabled end
	local input = { InputBegan = newSignal(), InputChanged = newSignal(), InputEnded = newSignal(), JumpRequest = newSignal(), TouchTapInWorld = newSignal(), TouchLongPress = newSignal(), TouchEnabled = false }
	function input:GetFocusedTextBox() return self.focused end
	function input:GetMouseLocation() return self.mouseLocation or Vector2.new(SCREEN.w / 2, SCREEN.h / 2) end
	local guiService = {}
	function guiService:GetGuiInset() return Vector2.new(0, 58), Vector2.new(0, 0) end
	local prompts = {}
	local market = {
		GetProductInfoAsync = function(_, id)
			local prices = {[777]=19, [778]=23, [779]=0, [780]=15, [781]=31, [782]=63}
			return {PriceInRobux=prices[id], IsForSale=id~=779}
		end,
		PromptGamePassPurchase = function(_, _, id) table.insert(prompts, "pass:" .. tostring(id)) end,
		PromptProductPurchase = function(_, _, id) table.insert(prompts, "product:" .. tostring(id)) end,
	}
	services.RunService, services.UserInputService, services.GuiService = runService, input, guiService
	services.LocalizationService = {RobloxLocaleId="pt-br"}
	services.ReplicatedFirst.RemoveDefaultLoadingScreen = function(self) self.defaultRemoved=true end
	-- Context actions: the bound handlers and button titles are kept so a test can press them.
	local contextActions = { handlers = {}, titles = {} }
	function contextActions:BindAction(name, handler) self.handlers[name] = handler end
	function contextActions:SetTitle(name, title) self.titles[name] = title end
	function contextActions:UnbindAction(name) self.handlers[name] = nil end
	services.ContextActionService = contextActions
	services.TweenService = { Create = function(_, subject, _, goal)
		return { Play = function()
			-- Blur has no layout side effects; model its completed tween.
			if subject:IsA("BlurEffect") then subject.Size = goal.Size end
		end, Cancel = function() end }
	end }
	services.MarketplaceService = market
	-- Roblox's chat window: the client places it and hides it under its own windows.
	local chatWindow = { Enabled = true }
	local chatInput = { Enabled = true }
	services.TextChatService = { ChatWindowConfiguration = chatWindow, ChatInputBarConfiguration = chatInput, WaitForChild = function(self, name) return self[name] end }

	local camera = Instance.new("Camera")
	camera.ViewportSize = Vector2.new(SCREEN.w, SCREEN.h + 58)
	camera.CFrame = CFrame.new(0, 80, 60)
	-- Every ray the client asks for is kept, with the space it was asked in:
	-- the placement ghost must sit exactly under the pointer.
	local rays = {}
	camera.ScreenPointToRay = function(_, x, y) table.insert(rays, { space = "screen", x = x, y = y }) return { Origin = v3(0, 80, 60), Direction = v3(0, -1, 0) } end
	camera.ViewportPointToRay = function(_, x, y) table.insert(rays, { space = "viewport", x = x, y = y }) return { Origin = v3(0, 80, 60), Direction = v3(0, -1, 0) } end
	camera.WorldToViewportPoint=function(self,position)
		local relative=self.CFrame:Inverse()*position
		local depth=-relative.Z
		local f=self.ViewportSize.Y/(2*math.tan(math.rad(70)/2))
		local point=v3(self.ViewportSize.X/2+relative.X*f/math.max(0.001,depth),self.ViewportSize.Y/2-relative.Y*f/math.max(0.001,depth),depth)
		return point,depth>0 and point.X>=0 and point.X<=self.ViewportSize.X and point.Y>=0 and point.Y<=self.ViewportSize.Y
	end
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
	local rewardResult
	local collectorPrice, leaderboardDown = false, false
	requestRemote.InvokeServer = function(_, action, payload)
		table.insert(actions, action)
		actionPayloads[action] = payload
		if action == "Sync" then return { ok = true, data = current } end
		if action == "ProductInfo" then
			local goldIds={gold1000=779,gold5000=780,gold12000=781,gold30000=782}
			if goldIds[payload.key] then return {ok=true,data={id=goldIds[payload.key],price=999}} end
			if payload.key == "vip" then return { ok = true, data = { id = 777, price = 299, name = "VIP" } } end
			if payload.key == "speed3" then return { ok = true, data = { id = 777, price = 299, name = "3x Speed", preview = true } } end
			-- The training pass price never answers until the test says so.
			if payload.key == "training" and not collectorPrice then return nil end
			if payload.key == "training" then return { ok = true, data = { id = 778, price = 149, name = "Training" } } end
			return { ok = false, message = { pt = "ID não configurado", en = "ID not configured" } }
		end
		if action == "Leaderboard" then
			if leaderboardDown then return { ok = false, message = { pt = "Placar indisponível", en = "Leaderboard unavailable" } } end
			return { ok = true, data = { rows = { { rank = 1, userId = 5, name = "Ana", waves = 42 }, { rank = 2, userId = LOCAL_ID, name = "Tester", waves = 12 } }, season = 1, personal = 12,
				mapId = payload.mapId, size = payload.size, period = payload.period or "s1" } }
		end
		if action == "OpenChest" and chestResult then return { ok = true, data = { result = chestResult } } end
		if rewardResult and (action:sub(1,5) == "Claim" or action == "RedeemCode") then return { ok = true, data = { result = rewardResult } } end
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
	local function requestCount(action)
		local count = 0
		for _, name in ipairs(actions) do if name == action then count += 1 end end
		return count
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
	step("shop quotes complete independently and time out safely", function()
		local Quotes = require(clientModules.ProductQuotes)
		local jobs, timers, cache, updates = {}, {}, {}, 0
		local quotes = Quotes.new({
			catalog = {Heroes = {}, Passes = {a = {price=1}, b = {price=2}, c = {price=3}, d = {price=4}}, Consumables = {gold = {price=1}}},
			cache = cache, profile = function() return {} end,
			quote = function(kind, key) return {price=17, kind=kind, key=key} end,
			spawn = function(fn) table.insert(jobs, fn) end,
			delay = function(seconds, fn) check(seconds == 12, tag .. ": bounded Marketplace wait"); table.insert(timers, fn) end,
			updated = function() updates += 1 end,
		})
		quotes:Fetch("pass")
		check(#jobs == 3, tag .. ": Marketplace concurrency is bounded")
		quotes:Fetch("product")
		jobs[2]()
		check(cache["pass:a"] == nil and cache["pass:b"].price == 17 and updates == 1, tag .. ": a stalled quote cannot block a ready price")
		jobs[4]()
		check(cache["product:gold"] ~= nil and cache["pass:d"] == nil, tag .. ": changing tabs prioritizes visible products")
		timers[1]()
		check(cache["pass:a"] == "retry", tag .. ": a quote that never completes becomes retryable")
		cache["pass:a"] = nil
		quotes:Fetch("pass")
		jobs[5]()
		local fresh, count = cache["pass:a"], updates
		jobs[1]()
		check(cache["pass:a"] == fresh and updates == count, tag .. ": a late timed-out quote cannot overwrite a retried price")
		quotes.ctx.quote = function() return false end
		jobs[6]()
		check(cache["pass:d"] == false, tag .. ": off-sale status is preserved rather than retried forever")
	end)
	loaded[shared.Config] = nil
	step("cold-join art works before the client and always dismisses",function()
		local originalDelay=task.delay
		local timeout
		task.delay=function(_,fn) timeout=fn end
		local loadedWorld=false
		game.IsLoaded=function() return loadedWorld end
		__FIRST__(firstScript,clockOs)
		task.delay=originalDelay
		local cover=playerGui:FindFirstChild("DoomLoader")
		check(cover and cover.IgnoreGuiInset==true and named(cover,"DimensionalBackdrop"),tag..": early loader draws its packaged full-screen art without the world")
		advance(0.2);runService.RenderStepped:Fire(0.2)
		check(named(cover,"SplashStatus").Text=="Carregando o refúgio…",tag..": initial status reflects actual world loading")
		loadedWorld=true;advance(0.2);runService.RenderStepped:Fire(0.2)
		check(named(cover,"SplashStatus").Text=="Conectando seu perfil…",tag..": profile status begins only after the world loads")
		localPlayer:SetAttribute("DoomReady",true);advance(0.2);runService.RenderStepped:Fire(0.2)
		check(not cover.Parent,tag..": first real profile dismisses the early loader")
		timeout()
		localPlayer:SetAttribute("DoomReady",nil)
		loadedWorld=false
		task.delay=function(_,fn) timeout=fn end
		__FIRST__(firstScript,clockOs)
		task.delay=originalDelay
		cover=playerGui:FindFirstChild("DoomLoader")
		localPlayer:SetAttribute("DoomReady",true);advance(0.2);runService.RenderStepped:Fire(0.2)
		check(not cover.Parent,tag..": a successfully rendered HUD can take over even while optional world loading remains pending")
		localPlayer:SetAttribute("DoomReady",nil)
		task.delay=function(_,fn) timeout=fn end
		__FIRST__(firstScript,clockOs)
		task.delay=originalDelay
		cover=playerGui:FindFirstChild("DoomLoader")
		timeout()
		check(not cover.Parent,tag..": the hard timeout also dismisses when the world never loads")
		game.IsLoaded=function() return true end
	end)
	step("reference paintings replace native fallback only when ready",function()
		local Art=require(firstScript.ScreenArt)
		local host=Instance.new("Frame",playerGui)
		local create=Instance.new
		Instance.new=function(class,...)
			local item=create(class,...)
			if class=="ImageLabel" then item.IsLoaded=false end
			return item
		end
		local backdrop=Art.Draw(host,"loading",1150,640)
		Instance.new=create
		local painting=named(backdrop,"RefugePainting")
		check(painting and painting:GetAttribute("ReferenceArt")=="launch" and painting.BackgroundTransparency==1,tag..": image download leaves a transparent fallback and does not block entry")
		check(named(backdrop,"LobbyPhotography").Visible~=false,tag..": the actual game models remain the fallback before the painting loads")
		painting.IsLoaded=true; painting:GetPropertyChangedSignal("IsLoaded"):Fire()
		check(painting.Visible and named(backdrop,"LobbyPhotography").Visible==false,tag..": completed reference art replaces its native fallback")
		local duplicated=false
		for _,item in ipairs(backdrop:GetChildren()) do if item:IsA("ViewportFrame") and item.Visible~=false then duplicated=true end end
		check(not duplicated,tag..": generated heroes are never doubled by model overlays")
		local farm=Art.Draw(host,"xp",375,667)
		check(named(farm,"RefugePainting"):GetAttribute("ReferenceArt")=="afk",tag..": AFK uses its own faithful scene with a safe portrait crop")
		shared.Parent=nil
		local early=Art.Draw(host,"loading",1150,640)
		check(not named(early,"RefugePainting"),tag..": a cold cover draws even before Config replicates")
		shared.Parent=replicated; frames(0.6,1)
		check(named(early,"RefugePainting")~=nil,tag..": late configuration attaches the art without rebuilding or blocking the cover")
		host:Destroy()
	end)

	-- Reproduce the real cold-join ordering: Sync returns Lobby before the
	-- data store has supplied a profile. The next packet is still Lobby.
	local profilePending=true
	local firstSyncHeld=false
	local invoke=requestRemote.InvokeServer
	requestRemote.InvokeServer=function(self,action,payload)
		if action=="Sync" and profilePending then
			table.insert(actions,action)
			if not firstSyncHeld then firstSyncHeld=true; coroutine.yield() end
			return {ok=true,data={phase="Lobby",players={}}}
		end
		return invoke(self,action,payload)
	end
	-- The test scheduler is synchronous; hold the initial retry coroutine
	-- while we supply the real delayed State packet, then let it terminate.
	local spawn=task.spawn
	local bootThreads={}
	task.spawn=function(fn,...)
		local thread=coroutine.create(fn)
		local ok,problem=coroutine.resume(thread,...)
		assert(ok,problem)
		if coroutine.status(thread)~="dead" then table.insert(bootThreads,thread) end
	end
	local wait=task.wait
	task.wait=function() coroutine.yield() end
	if not step("init.client boots and syncs before its profile arrives", function() __CLIENT__(clientScript, clockOs); flush() end) then return end
	task.spawn=spawn; task.wait=wait
	local gui = playerGui:FindFirstChild("DoomsdayUI")
	check(gui ~= nil, tag .. ": the client mounts its ScreenGui")
	if not gui then return end
	check(named(gui,"LoadingSplash")~=nil and localPlayer:GetAttribute("DoomReady")~=true,tag..": pending profile keeps a truthful cover and does not signal readiness")
	frames(2.1,1)
	check(requestCount("Sync")==2 and named(gui,"LoadingSplash")~=nil,tag..": a blocked first Sync permits an independent bounded retry")
	-- A profile that could not be loaded: the cover offers a way out.
	stateRemote.OnClientEvent:Fire({phase="Lobby",players={},profileFailed=true}); flush()
	check(named(gui,"RetryProfile")~=nil and named(gui,"LoadingSplash")~=nil,tag..": a profile that could not be loaded offers Try again on the cover")
	clickNamed("RetryProfile")
	check(asked("RetryProfile"),tag..": Try again asks the server to load the profile again")
	profilePending=false
	-- Cover both delivery orders: a later Sync reply and the pushed State.
	if screen.w>1000 then frames(2.1,1) else push(current) end
	check(named(gui,"LoadingSplash")==nil and localPlayer:GetAttribute("DoomReady")==true,tag..": delayed profile rebuilds Lobby and releases the cover on the first join")
	local synced=requestCount("Sync")
	frames(2.1,2)
	check(requestCount("Sync")==synced,tag..": successful handoff disconnects bootstrap retries")
	for _,thread in ipairs(bootThreads) do if coroutine.status(thread)~="dead" then local ok,problem=coroutine.resume(thread);check(ok,tag..": cold boot retry completes: "..tostring(problem)) end end
	check(named(gui,"LoadingSplash")==nil,tag..": a stale nil-profile reply cannot resurrect the loading screen")
	step("AFK screens only display authoritative payments and restore play",function()
		local before=requestCount("LeaveAfk")
		localPlayer:SetAttribute("AfkZone","gold")
		localPlayer:SetAttribute("AfkNext",24)
		localPlayer:SetAttribute("AfkSession",756)
		localPlayer:SetAttribute("AfkEarned",60)
		localPlayer:SetAttribute("AfkSaving",false)
		frames(0.3,2);clickNamed("AfkEcoOn");frames(0.3,2)
		local screenRoot=named(gui,"AfkScreen")
		check(screenRoot and screenRoot:GetAttribute("AfkKind")=="gold" and named(screenRoot,"DimensionalBackdrop"),tag..": Gold AFK has an opaque dedicated resource scene")
		check(named(screenRoot,"AfkScreenEarned").Text=="+60 Ouro" and named(screenRoot,"AfkScreenNext").Text=="24s",tag..": AFK shows actual earned Gold and the server countdown")
		check(named(screenRoot,"AfkPaymentFill").Size.X.Scale==0.6,tag..": payment bar follows the server interval")
		check(runService.renderingEnabled==false and not chatWindow.Enabled and not chatInput.Enabled,tag..": saver disables 3D and hides chat over the complete screen")
		local count=#screenRoot:GetDescendants()
		check(count<1100,tag..": actual-model AFK composition stays within a fixed geometry/UI budget, got "..count)
		frames(20,4)
		check(named(screenRoot,"AfkScreenEarned").Text=="+60 Ouro" and #screenRoot:GetDescendants()==count,tag..": elapsed client time neither invents rewards nor accumulates art")
		localPlayer:SetAttribute("AfkSaving",true);frames(0.3,2)
		check(named(screenRoot,"AfkScreenSaved").Text=="Salvando pagamento…",tag..": pending payment is never labelled as saved")
		localPlayer:SetAttribute("AfkZone","xp");localPlayer:SetAttribute("AfkEarned",0);localPlayer:SetAttribute("AfkSaving",false);frames(0.3,2)
		screenRoot=named(gui,"AfkScreen")
		check(screenRoot:GetAttribute("AfkKind")=="xp" and named(screenRoot,"AfkScreenEarned").Text=="+0 XP",tag..": switching chambers rebuilds the XP scene and unit")
		check(named(screenRoot,"AfkScreenSaved").Text=="Aguardando o primeiro pagamento",tag..": no saved award is claimed before the first minute")
		-- screenRect works in the client's logical pixels (it does not apply UIScale):
		-- the screen in those pixels is the real one over the client's scale.
		local scale=(named(gui,"ScreenScale") or {}).Scale or 1
		for _,name in ipairs({"AfkEcoOff","AfkLeave","AfkScreenEarned","AfkScreenNext"}) do
			local rect=screenRect(named(screenRoot,name),gui,screen)
			check(rect and rect.x>=0 and rect.y>=0 and rect.x+rect.w<=screen.w/scale+1 and rect.y+rect.h<=screen.h/scale+1,tag..": AFK control/counter stays on screen: "..name)
		end
		local canvas=gui:GetChildren()[1]
		local originalSize=canvas.AbsoluteSize
		SCREEN.w,SCREEN.h=screen.h,screen.w
		canvas.AbsoluteSize=Vector2.new(SCREEN.w,SCREEN.h)
		canvas:GetPropertyChangedSignal("AbsoluteSize"):Fire();flush();frames(0.3,2)
		screenRoot=named(gui,"AfkScreen")
		check(screenRoot and screenRoot:GetAttribute("AfkKind")=="xp" and named(screenRoot,"AfkScreenEarned").Text=="+0 XP",tag..": rotating rebuilds the active farm without changing its server counters")
		check(runService.renderingEnabled==false,tag..": relayout preserves power saving")
		SCREEN.w,SCREEN.h=screen.w,screen.h
		canvas.AbsoluteSize=originalSize
		canvas:GetPropertyChangedSignal("AbsoluteSize"):Fire();flush();frames(0.3,2)
		clickNamed("AfkEcoOff");frames(0.3,2)
		check(not named(gui,"AfkScreen") and runService.renderingEnabled==true and requestCount("LeaveAfk")==before,tag..": show game restores rendering without leaving the farm")
		clickNamed("AfkEcoOn");frames(0.3,2);clickNamed("AfkLeave");frames(0.3,2)
		check(requestCount("LeaveAfk")==before+1 and runService.renderingEnabled==true,tag..": exit requests exactly one server leave and restores 3D")
		clickNamed("AfkEcoOn");frames(0.3,2)
		localPlayer:SetAttribute("AfkZone",nil);frames(0.3,2)
		check(not named(gui,"AfkScreen") and runService.renderingEnabled==true and chatWindow.Enabled and chatInput.Enabled,tag..": leaving the chamber restores the interface and chat automatically")
	end)
	step("comic artwork stays bounded and owns its lifetime",function()
		local UI=require(clientModules.UI)
		local host=UI.frame(playerGui,{Name="ComicProbe",Size=UDim2.fromOffset(320,220)})
		UI.windowSkin(host,UI.Colors.blue,"inventory")
		local count=#host:GetDescendants()
		UI.windowSkin(host,UI.Colors.blue,"inventory")
		check(#host:GetDescendants()==count,tag..": skin refresh replaces its art without accumulating instances")
		check(host.BackgroundColor3.R==1,tag..": window gradients preserve their navy values without dark colour multiplication")
		local art=host:FindFirstChild("Sheen")
		local passive=art.ClipsDescendants and art.Active==false
		for _,item in ipairs(art:GetDescendants()) do if item:IsA("GuiObject") and item.Active~=false then passive=false end end
		check(passive and #art:GetDescendants()<=45,tag..": chapter art is clipped, passive and within its fixed budget")
		local shell=host:FindFirstChild("ComicShell")
		check(shell and shell:FindFirstChild("MetalRim") and shell:FindFirstChild("Enamel"),tag..": the window has native cut corners and a separate metal rim")
		local shellPassive=true
		for _,item in ipairs(shell:GetDescendants()) do if item:IsA("GuiObject") and item.Active~=false then shellPassive=false end end
		check(shellPassive,tag..": decorative metal layers never consume clicks or touch gestures")
		local border=host:FindFirstChild("Border")
		border.Color=UI.Colors.green
		-- Property notifications are explicit in the Roblox stand-in.
		border:GetPropertyChangedSignal("Color"):Fire()
		check(shell.MetalRim:GetChildren()[1].BackgroundColor3==UI.Colors.green,tag..": a live selection colour reaches the visible metal rim")
		local before=#host:GetDescendants()
		UI.angular(host,UI.Colors.gold)
		check(#host:GetDescendants()==before,tag..": recolouring a selection does not accumulate geometry")
		local portrait=UI.heroPortrait(host,"ironman",nil,UI.Colors.blue,{Name="LifetimePortrait",Size=UDim2.fromOffset(90,90)})
		check(portrait.BackgroundTransparency==1 and portrait:GetAttribute("PortraitFraming")=="bust",tag..": small portraits expose their illustrated stage and frame the face and torso")
		check(host:FindFirstChild("LifetimePortrait_Art")~=nil,tag..": the portrait has its own graphic stage")
		portrait:Destroy()
		check(host:FindFirstChild("LifetimePortrait_Art")==nil,tag..": virtualized portraits release their sibling artwork on destruction")
		local full=UI.heroPortrait(host,"ironman",nil,UI.Colors.blue,{FullFigure=true})
		check(full:GetAttribute("PortraitFraming")=="figure",tag..": large hero sheets retain their full figure")
		local cutout=UI.heroPortrait(host,"ironman",nil,UI.Colors.blue,{Name="CutoutPortrait",FullFigure=true,NoBackdrop=true})
		check(host:FindFirstChild("CutoutPortrait_Art")==nil,tag..": a scene illustration keeps its transparent background")
		cutout:Destroy()
		for _,baseId in ipairs({"outpost","garden","barracks","polar","vault"}) do
			local def=Catalog.Bases[baseId]
			if def then
				local miniature=UI.basePortrait(host,def,{Name="BaseArtProbe",Size=UDim2.fromOffset(180,130)})
				local count,passive=0,true
				for _,item in ipairs(miniature:GetDescendants()) do
					if item:IsA("BasePart") then count+=1;passive=passive and item.Anchored and item.CanCollide==false and item.CanQuery==false end
				end
				-- The card shows the match's own model (owner, 17/10: richer bases), still bounded.
				check(miniature:IsA("ViewportFrame") and miniature.CurrentCamera~=nil and count>0 and count<=90 and passive,tag..": base miniature is a bounded cosmetic model with no gameplay collision, got "..count.." parts")
				miniature:Destroy()
			end
		end
		local previousMotion=UI.reducedMotion
		UI.reducedMotion=function() return true end
		local button=UI.button(host,"Probe",nil)
		button.MouseButton1Down:Fire();button.MouseEnter:Fire()
		check(button.PressScale.Scale==1,tag..": reduced effects keeps button scale stable")
		UI.reducedMotion=previousMotion
		host:Destroy()
	end)
	step("illustrated HUD downloads, atlas crops and fallback",function()
		local UI=require(clientModules.UI)
		local host=UI.frame(playerGui,{Name="IllustratedProbe",Size=UDim2.fromOffset(320,220)})
		local icon=UI.icon(host,"hero",UI.Colors.gold)
		local raster=icon:FindFirstChild("Illustrated_icons")
		check(raster and raster.Active==false and raster.ImageRectSize.X==256,tag..": a passive atlas replaces the hero symbol")
		local function onlyArtwork(root,art)
			return art and #root:GetChildren()==1 and root:GetChildren()[1]==art and art.Visible~=false
		end
		for _,loaded in ipairs({false,true,false,true}) do
			raster.IsLoaded=loaded; raster:GetPropertyChangedSignal("IsLoaded"):Fire();flush()
			check(onlyArtwork(icon,raster),tag..": an atlas icon has no legacy drawing at any download state: "..tostring(loaded))
		end
		for _,kind in ipairs({"hero","base","star","shop","gift","scroll","gear","trophy","xp","wave","damage","range","chest","home","play","shield"}) do
			local root=UI.icon(host,kind,UI.Colors.gold)
			local symbol=root:FindFirstChild("Illustrated_icons")
			check(symbol and symbol.ImageRectOffset.X+symbol.ImageRectSize.X<=1024 and symbol.ImageRectOffset.Y+symbol.ImageRectSize.Y<=1024,tag..": atlas crop is bounded: "..kind)
			check(onlyArtwork(root,symbol),tag..": only the atlas symbol is constructed: "..kind)
			local illustration=UI.illustration(host,kind,UI.Colors.gold)
			check(onlyArtwork(illustration,illustration:FindFirstChild("Illustrated_icons")),tag..": an illustration does not nest another icon or native drawing: "..kind)
		end
		for _,kind in ipairs({"hero","talents","shop","gift","scroll","gear"}) do
			local nav=UI.roundIcon(host,"NavProbe_"..kind,"Caption",UI.Colors.gold,kind,nil)
			local root=nav.Disc:FindFirstChild("NavIcon")
			check(onlyArtwork(root,root:FindFirstChild("Illustrated_icons")) and nav.Caption.Text=="Caption",tag..": navigation keeps one icon and its live caption: "..kind)
		end
		for _,rarity in ipairs({"supply","rare","epic","legendary","cosmic","base_supply","base_epic","base_cosmic"}) do
			local root=UI.illustration(host,"crate",UI.Colors.blue,{Rarity=rarity})
			local chest=root:FindFirstChild("Illustrated_chests")
			check(chest and chest:GetAttribute("ArtRarity")==rarity and chest.ImageRectOffset.X+chest.ImageRectSize.X<=1023 and chest.ImageRectOffset.Y+chest.ImageRectSize.Y<=682,tag..": chest rarity maps to a valid authored crop: "..rarity)
			check(onlyArtwork(root,chest),tag..": authored chests contain no old chest drawing: "..rarity)
		end
		local button=UI.button(host,"Live caption",nil)
		local plate=button.ComicShell.IllustratedPlate
		plate.IsLoaded=false; plate:GetPropertyChangedSignal("IsLoaded"):Fire()
		check(button.Text=="Live caption" and button.ComicShell.Enamel.Visible,tag..": slow image loading preserves native live controls")
		plate.IsLoaded=true; plate:GetPropertyChangedSignal("IsLoaded"):Fire()
		check(button.Text=="Live caption" and not button.ComicShell.Enamel.Visible,tag..": the loaded plate leaves the caption intact")
		local short=UI.button(host,"Skip walk",nil,{Size=UDim2.fromOffset(160,24),ZIndex=2})
		check(short.Caption and short.Caption.Text=="Skip walk" and short.Caption.ZIndex>=short.ComicShell.ZIndex,tag..": a short control keeps its caption above the opaque illustration")
		button.BackgroundColor3=UI.Colors.green;button:GetPropertyChangedSignal("BackgroundColor3"):Fire()
		check(plate.ImageColor3==UI.Colors.green,tag..": selection colour reaches the illustrated button")
		local stage=UI.portraitStage(host,UI.Colors.blue,{Size=UDim2.fromOffset(100,100)})
		UI.heroPortrait(stage,"ironman",nil,UI.Colors.blue,{Name="AlreadyStaged"})
		check(not stage:FindFirstChild("AlreadyStaged_Art"),tag..": a framed hero card avoids a second overlapping frame")
		check(stage.ComicShell.IllustratedPlate.ImageColor3==UI.Colors.blue,tag..": the hero supplies the portrait identity colour")
		local Skin=require(clientModules.IllustratedSkin)
		local plateHost=UI.frame(host,{Name="PlateResizeProbe"})
		local plateScale=UI.create("UIScale",{Scale=1},plateHost)
		for _,factor in ipairs({0.65,1,1.3,1.6}) do
			plateScale.Scale=factor
			for _,case in ipairs({{"window",600,84},{"window",640,66},{"window",400,46},{"window",560,420},{"button",160,24},{"card",24,24}}) do
				local art=Skin.plate(plateHost,case[1],UI.Colors.gold)
				art.AbsoluteSize=Vector2.new(case[2]*factor,case[3]*factor)
				art:GetPropertyChangedSignal("AbsoluteSize"):Fire()
				local texture=case[1]=="window" and Vector2.new(1024,683) or (case[1]=="card" and Vector2.new(1024,1024) or Vector2.new(1024,241))
				local slice=art.SliceCenter
				local gap=case[1]=="window" and 12 or 6
				check((slice.Min.X+texture.X-slice.Max.X)*art.SliceScale<=case[2]-gap+0.01,tag..": illustrated ends fit the logical width at scale "..factor)
				check((slice.Min.Y+texture.Y-slice.Max.Y)*art.SliceScale<=case[3]-gap+0.01,tag..": illustrated corners fit short HUDs at scale "..factor)
				if case[1]=="window" then
					check(slice.Min.X>=352 and slice.Min.X==texture.X-slice.Max.X and slice.Min.Y==texture.Y-slice.Max.Y,tag..": both complete window ends are preserved symmetrically")
				end
				art.AbsoluteSize=Vector2.new(800*factor,500*factor)
				art:GetPropertyChangedSignal("AbsoluteSize"):Fire()
				check(math.abs(art.SliceScale-(case[1]=="window" and 0.26 or 0.17))<0.0001,tag..": enlarged plates recover their authored border size")
				art:Destroy()
			end
		end
		plateHost:Destroy()
		local previousProvider=services.ContentProvider
		local fetches,ready=0,0
		services.ContentProvider={PreloadAsync=function(_,urls,callback)
			if urls[1]=="rbxasset://illustrated-completion-probe" then
				fetches+=1
				callback(urls[1],Enum.AssetFetchStatus.Success)
			end
		end}
		for _=1,2 do
			local delayed=UI.create("ImageLabel",{Image="rbxasset://illustrated-completion-probe",IsLoaded=false},host)
			Skin.loaded(delayed,function(loaded) if loaded then ready+=1 end end)
		end
		flush()
		check(fetches==1 and ready==2,tag..": one asynchronous completion updates all atlas copies without an IsLoaded notification ("..fetches.." fetches, "..ready.." copies)")
		services.ContentProvider=previousProvider
		local Config=require(shared.Config)
		local previous=Config.UiArt.icons;Config.UiArt.icons=0
		local native=UI.icon(host,"hero",UI.Colors.gold)
		check(not native:FindFirstChild("Illustrated_icons") and #native:GetChildren()>0,tag..": a missing asset retains a usable native symbol")
		local nativeIllustration=UI.illustration(host,"hero",UI.Colors.gold)
		check(not nativeIllustration:FindFirstChild("Illustrated_icons") and #nativeIllustration:GetChildren()>0,tag..": an illustration without an asset still has its native symbol")
		Config.UiArt.icons=previous
		local unmapped=UI.icon(host,"clock",UI.Colors.gold)
		check(not unmapped:FindFirstChild("Illustrated_icons") and #unmapped:GetChildren()>0,tag..": a symbol outside the atlas remains visible")
		host:Destroy()
	end)
	local main
	for _, child in ipairs(gui:GetChildren()) do
		if rawget(child, "__class") == "Frame" and child.ZIndex ~= 50 then main = child end
	end
	local overlays
	for _, child in ipairs(gui:GetChildren()) do
		if rawget(child, "__class") == "Frame" and child.ZIndex == 50 then overlays = child end
	end
	check(asked("Sync"), tag .. ": the client asked for its first snapshot")
	-- The HUD is laid out in logical pixels and drawn scaled (ScreenScale on the
	-- root frame): a 1920 x 1022 window is a 1200 x 638 canvas drawn 1.6x.
	local function view()
		local scale = main and main:FindFirstChild("ScreenScale")
		local factor = scale and scale.Scale or 1
		return { w = math.floor(SCREEN.w / factor), h = math.floor(SCREEN.h / factor) }
	end

	--========================================================================
	-- Lobby
	--========================================================================
	local lobbyLayout = UILayout.lobbyLayout(view().w, view().h)
	step("the lobby HUD lays out", function()
		local audioFolder = services.SoundService:FindFirstChild("DoomAudio")
		local ambience = audioFolder and audioFolder:FindFirstChild("Bank_world_1")
		check(ambience and ambience.IsPlaying and ambience.PlaybackRegionsEnabled and ambience.Looped,
			tag .. ": configured lobby ambience starts as a bounded looping audio region")
		check(frameAt(main, lobbyLayout.pill) ~= nil, tag .. ": the gold pill sits where lobbyLayout puts it")
		check(named(main,"Nav_bases") ~= nil and named(main,"Nav_bases").Parent == named(main,"LobbyNavigation"), tag .. ": Base sits in the main navigation dock")
		check(frameAt(main, lobbyLayout.settings) ~= nil, tag .. ": the settings button sits where lobbyLayout puts it")
		check(frameAt(main, lobbyLayout.elevator) == nil, tag .. ": no elevator card while standing on the open deck")
		-- The world is the menu: nothing else sits on screen when the lobby opens.
		local visible = 0
		for _, child in ipairs(main:GetChildren()) do
			if child.Visible ~= false and rawget(child, "__class") ~= "UIScale" then visible += 1 end
		end
		-- Wide screens add the side quest tracker; phones keep the view clear.
		local tracker = main:FindFirstChild("QuestTracker")
		check((tracker ~= nil) == (lobbyLayout.tracker ~= nil), tag .. ": the quest tracker shows exactly on screens with room for it")
		if tracker then check(frameAt(main, lobbyLayout.tracker) ~= nil, tag .. ": the quest tracker sits where lobbyLayout puts it") end
		local expected = tracker and 5 or 4
		check(visible == expected, tag .. ": the idle lobby shows counters, settings, dock, guide and quests, got " .. visible .. " elements")
		for _, id in ipairs({"inventory","bases","talents","premium","rewards","quests"}) do
			check(named(main,"Nav_"..id)~=nil,tag..": shared dock contains "..id)
		end
		local bad = offscreen(main, view())
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
		check(lobby.Board_quests.Panel.Board.Title.Text == "MISSÕES" and not string.find(boardText, "MISSÕES", 1, true), tag .. ": mission status cannot overwrite or duplicate its title")
		local medal = lobby.HubServices:FindFirstChild("DeskEmblem_leaderboard")
		local star = medal and medal:FindFirstChild("PodiumStar", true)
		local podium = medal and medal:FindFirstChild("PodiumFirst")
		local before = star and podium and star.Position - podium.Position
		frames(0.17, 3)
		check(before and ((star.Position - podium.Position) - before).Magnitude < 0.001, tag .. ": Hall of Fame star stays attached while the medal bobs")
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

	step("the showroom drone's rotors turn above their motors", function()
		local stand = workspace:FindFirstChild("DoomLobby").Shop_collector
		local arm
		for _, child in ipairs(stand:GetChildren()) do
			if child.Name == "DroneRotor" then arm = child end
		end
		local before = arm and arm.CFrame.LookVector
		frames(0.25, 4)
		local after = arm and arm.CFrame.LookVector
		check(before ~= nil and after ~= nil and before.X * after.X + before.Z * after.Z < 0.99, tag .. ": the drone's rotor has turned")
	end)

	local contextSlot = lobbyLayout.context
	local function contextOpen() return main:FindFirstChild("ContextPanel") ~= nil end
	step("the next-goal strip sends the player to a place",function()
		-- Chests are bought at the shop: the strip shows the way, it opens no menu.
		clickNamed("FirstVisitHint")
		check(not contextOpen(),tag..": the shop suggestion sends the player walking, no chest menu")
		check(named(gui,"RefugeWelcome")==nil and named(gui,"GuideLink_modes")==nil,tag..": there is no guide panel")
		check(#offscreen(main,view())==0,tag..": the strip stays inside the usable screen")
	end)
	step("Roblox's chat steps aside while a window of the game is open", function()
		fx({ kind = "OpenPanel", panel = "quests" })
		check(contextOpen(), tag .. ": the missions window is open")
		frames(0.3, 1)
		check(chatWindow.Enabled == false, tag .. ": the chat hides under an open window")
		check(chatInput.Enabled == false, tag .. ": the typing field also hides instead of covering upgrades")
		if contextOpen() then click("X") end
		frames(0.3, 1)
		check(not contextOpen() and chatWindow.Enabled == true, tag .. ": the chat comes back when the window closes")
		check(chatInput.Enabled == true, tag .. ": the typing field returns after closing the window")
	end)
	step("a portal opens no menu", function()
		fx({ kind = "OpenPanel", panel = "play", modeId = "normal" })
		check(not contextOpen(), tag .. ": an unknown panel request opens nothing; portals are walked into")
	end)
	step("a short commander at the summon hall is sent to the Gold packs", function()
		local broke = veteranProfile({ gold = 0 })
		push(lobbySnapshot(broke))
		fx({ kind = "OpenPanel", panel = "chests" })
		check(contextOpen() and named(gui, "BuyGoldShortcut") ~= nil, tag .. ": without Gold the chest hall offers the Gold packs")
			clickNamed("BuyGoldShortcut")
		check(named(gui, "PremiumTabs_product") ~= nil and named(gui, "BuyGoldShortcut") == nil, tag .. ": the shortcut opens the Robux shop")
		check(named(gui, "Product_gold1000") ~= nil and named(gui, "Product_legendaryBundle") == nil, tag .. ": on the Gold tab, with Gold packs only")
		if contextOpen() then click("X") end
		-- The offers live on their own tab.
		fx({ kind = "OpenPanel", panel = "shop", shopKind = "offer" })
		check(named(gui, "Product_legendaryBundle") ~= nil and named(gui, "Product_goldBoost") ~= nil and named(gui, "Product_gold1000") == nil, tag .. ": the Offers tab holds the bundles and the boost, no Gold packs")
		if contextOpen() then click("X") end
		-- "Buy with Robux" on a hero's page opens the hero tab with that hero.
		fx({ kind = "OpenPanel", panel = "hero", heroId = "thor" })
		local buyRobux = named(gui, "HeroBuyRobux")
		if buyRobux and shown(buyRobux, gui) then
			clickNamed("HeroBuyRobux")
			check(named(gui, "Product_thor") ~= nil and named(gui, "Product_gold1000") == nil, tag .. ": the hero's Robux button opens the hero tab with that hero")
		end
		-- The welcome offer: a new account sees the countdown in the shop and on the lobby strip.
		local fresh = veteranProfile({ gold = 0 })
		fresh.starterOfferEndsAt = os.time() + 2 * 86400 + 3600
		fresh.rewards = rewardsFixture("empty")
		fresh.talentPoints = 0
		push(lobbySnapshot(fresh))
		fx({ kind = "OpenPanel", panel = "premium" })
		local urgency = named(gui, "StarterUrgency")
		check(urgency ~= nil and string.find(urgency.Text, "uma vez", 1, true) ~= nil and string.find(urgency.Text, "dias", 1, true) == nil and string.find(urgency.Text, "Termina", 1, true) == nil, tag .. ": the shop banner says once per account and shows no countdown, got " .. tostring(urgency and urgency.Text))
		if contextOpen() then click("X") end
		local strip = named(gui, "GuideTip")
		check(strip ~= nil and string.find(strip.Text, "Pacote Inicial", 1, true) ~= nil, tag .. ": with nothing else waiting, the lobby strip points at the welcome offer, got " .. tostring(strip and strip.Text))
		fresh.starterOfferEndsAt = nil
		push(lobbySnapshot(fresh))
		strip = named(gui, "GuideTip")
		check(strip == nil or string.find(strip.Text, "Pacote Inicial", 1, true) == nil, tag .. ": once the offer window closes, the strip lets it go")
		push(lobbySnapshot(veteranProfile()))
	end)
	step("waiting gifts beat the standing goal on the lobby strip", function()
		-- The server nearly always has a next goal; something free waiting right now comes first.
		local busy = veteranProfile({ gold = 0 })
		busy.nextGoal = { id = "win", text = { pt = "Vença Manhattan", en = "Win Manhattan" }, target = { portal = "normal" } }
		busy.rewards = rewardsFixture("ready")
		push(lobbySnapshot(busy))
		local strip = named(gui, "GuideTip")
		check(strip ~= nil and string.find(strip.Text, "prêmios", 1, true) ~= nil, tag .. ": claimable gifts show ahead of the goal, got " .. tostring(strip and strip.Text))
		busy.rewards = rewardsFixture("empty")
		push(lobbySnapshot(busy))
		strip = named(gui, "GuideTip")
		check(strip ~= nil and string.find(strip.Text, "Manhattan", 1, true) ~= nil, tag .. ": with nothing waiting the goal leads again, got " .. tostring(strip and strip.Text))
		push(lobbySnapshot(veteranProfile()))
	end)
	step("a friend in a portal queue is one tap away", function()
		local snapshot = lobbySnapshot(veteranProfile({ rewards = rewardsFixture("empty") }))
		snapshot.friendsRiding = { { userId = ALLY_ID, name = "Ally", mapId = "gamma", portalId = "normal_gamma" } }
		push(snapshot)
		local strip = named(gui, "GuideTip")
		check(strip ~= nil and string.find(strip.Text, "ir junto", 1, true) ~= nil and string.find(strip.Text, "Ally", 1, true) ~= nil, tag .. ": the strip offers to go along with the friend, got " .. tostring(strip and strip.Text))
		clickNamed("FirstVisitHint")
		check(asked("ElevatorJoin"), tag .. ": going along asks the server to join the friend's queue")
		push(lobbySnapshot(veteranProfile()))
	end)
	step("a bundle's hero is chosen in its own panel", function()
		local picker = veteranProfile({ gold = 0 })
		picker.heroPicks = { legendary = 1 }
		picker.rewards = rewardsFixture("empty")
		picker.talentPoints = 0
		push(lobbySnapshot(picker))
		local strip = named(gui, "GuideTip")
		check(strip ~= nil and string.find(strip.Text, "escolher", 1, true) ~= nil, tag .. ": the lobby strip points at the pending hero pick, got " .. tostring(strip and strip.Text))
		fx({ kind = "OpenPanel", panel = "premium" })
		check(named(gui, "PickHeroes") ~= nil, tag .. ": the Robux shop keeps the way to the pending picks on top")
		if contextOpen() then click("X") end
		fx({ kind = "OpenPanel", panel = "pick" })
		check(contextOpen() and named(gui, "PickHeading_legendary") ~= nil and named(gui, "Pick_thor") ~= nil, tag .. ": the pick panel lists the legendary heroes")
		check(named(gui, "Pick_hawkeye") == nil, tag .. ": a common hero is not offered for a legendary pick")
		clickNamed("Pick_thor")
		check(actions[#actions] == "PickHero", tag .. ": choosing sends PickHero; the server grants")
		if contextOpen() then click("X") end
		push(lobbySnapshot(veteranProfile()))
	end)
	step("a friend trade is drawn from the server's view", function()
		local trader = veteranProfile()
		trader.heroes.thor = { xp = 0, level = 1, stars = 0 }
		trader.tradesLeft = 10
		push(lobbySnapshot(trader))
		fx({ kind = "OpenPanel", panel = "trade" })
		check(contextOpen() and named(gui, "TradeInvite_" .. ALLY_ID) ~= nil, tag .. ": the trade panel lists the other player in the server")
		clickNamed("TradeInvite_" .. ALLY_ID)
		check(actions[#actions] == "TradeOffer", tag .. ": inviting sends TradeOffer")
		if contextOpen() then click("X") end
		trader.trade = { id = "t1", stage = "invited", invited = true, partnerId = ALLY_ID, partnerName = "Ally" }
		push(lobbySnapshot(trader))
		local strip = named(gui, "GuideTip")
		check(strip ~= nil and string.find(strip.Text, "trocar", 1, true) ~= nil, tag .. ": the lobby strip announces the invite, got " .. tostring(strip and strip.Text))
		fx({ kind = "OpenPanel", panel = "trade" })
		check(named(gui, "TradeAccept") ~= nil, tag .. ": an invite shows Accept")
		clickNamed("TradeAccept")
		check(actions[#actions] == "TradeAccept", tag .. ": accepting sends TradeAccept")
		if contextOpen() then click("X") end
		trader.trade = { id = "t1", stage = "open", invited = false, partnerId = ALLY_ID, partnerName = "Ally", theirs = "hulk", lockedUntil = 0, unequal = false }
		push(lobbySnapshot(trader))
		fx({ kind = "OpenPanel", panel = "trade" })
		check(named(gui, "TradeSet_thor") ~= nil and named(gui, "TradeSet_ironman") == nil, tag .. ": only tradeable heroes are offered: no starters, nothing on the team")
		check(named(gui, "TradeConfirm") ~= nil and named(gui, "TradeConfirm").Active == false, tag .. ": with nothing offered the confirm sleeps")
		clickNamed("TradeSet_thor")
		check(actions[#actions] == "TradeSet", tag .. ": offering sends TradeSet")
		if contextOpen() then click("X") end
		trader.trade.mine = "thor"; trader.trade.unequal = true
		push(lobbySnapshot(trader))
		fx({ kind = "OpenPanel", panel = "trade" })
		-- (A stand-in button only carries Active once UI.disabled set it.)
		check(named(gui, "TradeUnequal") ~= nil and named(gui, "TradeConfirm").Active ~= false and string.find(named(gui, "TradeConfirm").Text, "mesmo assim", 1, true) ~= nil, tag .. ": an unequal trade is flagged and the confirm wakes as 'confirm anyway'")
		clickNamed("TradeConfirm")
		check(actions[#actions] == "TradeConfirm", tag .. ": confirming sends TradeConfirm")
		if contextOpen() then click("X") end
		push(lobbySnapshot(veteranProfile()))
	end)
	step("the day's market sells exact heroes for Gold", function()
		local shopper = veteranProfile({ gold = 50000 })
		shopper.market = { day = 1, renewsAt = os.time() + 3600, offers = { { heroId = "thor", rarity = "legendary", price = 40000, bought = false }, { heroId = "hawkeye", rarity = "common", price = 500, bought = false } } }
		push(lobbySnapshot(shopper))
		fx({ kind = "OpenPanel", panel = "chests" })
		local thor = named(gui, "MarketBuy_thor")
		check(thor ~= nil and string.find(thor.Text, "40", 1, true) ~= nil, tag .. ": the hero hall lists today's offer with its Gold price, got " .. tostring(thor and thor.Text))
		check(named(gui, "MarketBuy_hawkeye") ~= nil and named(gui, "MarketBuy_hawkeye").Active == false, tag .. ": an owned hero's offer is marked yours and sleeps")
		clickNamed("MarketBuy_thor")
		check(actions[#actions] == "BuyMarket", tag .. ": buying sends BuyMarket; the server charges")
		if contextOpen() then click("X") end
		push(lobbySnapshot(veteranProfile()))
	end)
	local openings = {
		{ panel = "quests" }, { panel = "leaderboard" },
		{ panel = "shop", shopKind = "pass", shopKey = "vip" }, { panel = "shop", shopKind = "pass", shopKey = "collector" },
		{ panel = "offer", shopKind = "pass", shopKey = "vip" }, { panel = "offer", shopKind = "pass", shopKey = "training" },
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

	step("a pass stand shows that pass, what it gives and its price", function()
		push(lobbySnapshot(veteranProfile()))
		local before = #prompts
		local vip = Catalog.Products.Passes.vip
		fx({ kind = "OpenPanel", panel = "offer", shopKind = "pass", shopKey = "vip" })
		local name = named(gui, "OfferName")
		check(named(gui, "OfferHeader") ~= nil and name ~= nil and string.find(name.Text, Catalog.Upper(vip.name.pt), 1, true) ~= nil,
			tag .. ": the VIP stand opens the VIP card, got " .. tostring(name and name.Text))
		check(named(gui, "PremiumTabs") == nil, tag .. ": a pass card is not the whole shop list")
		local lines = 0
		for index, line in ipairs(vip.benefits) do
			local row = named(gui, "OfferBenefit_" .. index)
			local text = row and named(row, "BenefitText")
			if text and text.Text == line.pt then lines += 1 end
		end
		check(lines == #vip.benefits and lines >= 3, tag .. ": every benefit of the pass is listed, " .. lines .. "/" .. #vip.benefits)
		check(named(gui, "Buy_pass:vip") ~= nil, tag .. ": the card carries the Robux button")
		check(#prompts == before, tag .. ": the client prompts nothing by itself (the stand's E opens the purchase on the server)")
		if contextOpen() then click("X") end
	end)

	step("talent tree touch and desktop", function()
		local evolved = veteranProfile()
		evolved.talents, evolved.talentPoints = {}, 6
		push(lobbySnapshot(evolved))
		fx({kind="OpenPanel",panel="talents"})
		local tree, node
		for _, item in ipairs(gui:GetDescendants()) do
			if item.Name == "TalentTree" then tree = item end
			if item.Name == "TalentNode_roundGold" then node = item end
		end
		check(tree ~= nil, tag .. ": talent branches render")
		check(#offscreen(main, view()) == 0, tag .. ": talent panel stays within viewport")
		check(node ~= nil, tag .. ": fortune root is a tappable hexagon")
		check(named(gui, "Talent_roundGold") == nil and countNamed(gui, "UpgradeTalent_roundGold") == 0, tag .. ": no card or button ever opens below the tree")
		check(named(gui, "TalentInfo") ~= nil and string.find(named(gui, "TalentInfo").Text, "Agora", 1, true) ~= nil, tag .. ": one line above the icons says what the talent does")
		if node then node.Activated:Fire(); flush() end
		check(asked("UpgradeTalent"),tag .. ": tapping a hexagon spends the point through the server")
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
		check(named(gui, "TalentLegend") ~= nil, tag .. ": the branches are named once on the tree")
		-- Every branch name sits inside the board's box (owner, 17/10: FORTUNE and
		-- COMMAND were cut at the bottom), and every new talent is a hexagon.
		do
			local map = named(gui, "TalentMap")
			for _, branch in ipairs(Catalog.TalentBranches) do
				local pill = named(gui, "TalentBranch_" .. branch.id)
				check(pill ~= nil, tag .. ": the " .. branch.id .. " branch is named")
				if pill and map then
					local left = pill.Position.X.Offset - pill.AnchorPoint.X * pill.Size.X.Offset
					local top = pill.Position.Y.Offset - pill.AnchorPoint.Y * pill.Size.Y.Offset
					check(left >= 0 and top >= 0 and left + pill.Size.X.Offset <= map.Size.X.Offset and top + pill.Size.Y.Offset <= map.Size.Y.Offset,
						tag .. ": the " .. branch.id .. " name lies inside the board, at " .. left .. "," .. top .. " in " .. map.Size.X.Offset .. "x" .. map.Size.Y.Offset)
				end
				for _, id in ipairs(branch.nodes) do check(countNamed(gui, "TalentHex_" .. id) == 1, tag .. ": " .. id .. " is a hexagon on the board") end
			end
		end
		check(named(gui, "TalentLock_killGold") ~= nil and named(gui, "TalentLock_roundGold") == nil, tag .. ": a talent whose parent is too low shows a lock, an open one does not")
		check(named(named(gui, "TalentRank_roundGold"), "Text") == nil and named(gui, "TalentRank_roundGold").Text == "0/5", tag .. ": the level badge reads 0/5")
		-- Large research nodes live on an explorable board instead of shrinking.
		local treeFrame = named(gui, "TalentTree")
		check(not named(gui,"TalentChampionFortune") and not named(gui,"TalentChampionCommand"),tag..": talent tree has no decorative hero portraits")
		check(named(gui,"TalentBackdrop") == nil and treeFrame.BackgroundTransparency == 1 and named(gui,"ContextPanel").BackgroundTransparency == 1, tag .. ": talent nodes overlay the world without an opaque background")
		local blur = game:GetService("Lighting"):FindFirstChild("DoomMenuBlur")
		check(blur ~= nil and blur.Size == 14, tag .. ": the talent tree blurs the game behind it")
		local mapFrame = treeFrame and named(treeFrame, "TalentMap")
		check(mapFrame ~= nil and named(gui, "TalentViewport") ~= nil and named(gui, "TalentViewport").ClipsDescendants == true, tag .. ": the large honeycomb is clipped inside its movable viewport")
		check(named(gui, "TalentExit") ~= nil and named(gui, "TalentRoot") ~= nil, tag .. ": the full-screen tree has its Exit button and the commander's hexagon")
		local function spent() local n = 0; for _, name in ipairs(actions) do if name == "UpgradeTalent" then n += 1 end end; return n end
		local spentBefore = spent()
		-- The stand-ins run timers on flush: look at the message before its
		-- timed removal runs.
		local lockedNode = named(gui, "TalentNode_killGold")
		check(lockedNode ~= nil, tag .. ": the locked hexagon is on the board")
		if lockedNode then lockedNode.Activated:Fire() end
		-- The message it raises never sits on a control (owner, 17/10: toasts
		-- at the bottom covered Exit, Reset and the close buttons).
		do
			local toast = named(gui, "Toast")
			check(toast ~= nil, tag .. ": a locked hexagon explains itself in a message")
			local box = toast and screenRect(toast, gui, SCREEN)
			for _, control in ipairs({ "TalentExit", "ResetTalents", "TalentCenter", "CloseContext" }) do
				local item = named(gui, control)
				local other = item and screenRect(item, gui, SCREEN)
				if box and other then
					local overlap = box.x < other.x + other.w and other.x < box.x + box.w and box.y < other.y + other.h and other.y < box.y + box.h
					check(not overlap, tag .. ": the message stays clear of " .. control)
				end
			end
		end
		flush()
		check(named(gui, "Talent_killGold") == nil, tag .. ": tapping a hexagon opens no card below")
		local info = named(gui, "TalentInfo")
		check(info and string.find(info.Text, "Próximo", 1, true) ~= nil and string.find(info.Text, "Requer", 1, true) ~= nil, tag .. ": the line above says now, next and what it requires, got " .. tostring(info and info.Text))
		check(spent() == spentBefore, tag .. ": a talent whose parent is too low cannot be bought")
		clickNamed("CloseContext")
		push(lobbySnapshot(veteranProfile()))
	end)

	step("research board drag, touch, zoom and preserved view", function()
		local boughtBefore = requestCount("UpgradeTalent")
		local listenersBefore = #input.InputChanged.handlers
		local evolved = veteranProfile({talents = {}, talentPoints = 3})
		push(lobbySnapshot(evolved)); fx({kind="OpenPanel",panel="talents"})
		local board = named(gui, "TalentViewport")
		local node = named(gui, "TalentNode_roundGold")
		local beforeX, beforeY = board:GetAttribute("PanX"), board:GetAttribute("PanY")
		local gesture = {UserInputType = Enum.UserInputType.MouseButton1, Position = v3(120, 160, 0)}
		board.InputBegan:Fire(gesture)
		node.InputBegan:Fire(gesture)
		input.InputChanged:Fire({UserInputType = Enum.UserInputType.MouseMovement, Position = v3(200, 210, 0)})
		input.InputEnded:Fire(gesture); node.Activated:Fire(gesture); flush()
		check(requestCount("UpgradeTalent") == boughtBefore and node:GetAttribute("DragConsumed") == true, tag .. ": dragging from a buyable node never spends a talent point")
		check(board:GetAttribute("PanX") ~= beforeX and board:GetAttribute("PanY") ~= beforeY, tag .. ": the mouse moves the board on both axes")
		local scale = named(main, "ScreenScale").Scale
		check(math.abs(board:GetAttribute("PanX") - beforeX - 80 / scale) < 0.1, tag .. ": pan uses logical rather than physical pixels")
		local keepX, keepY = board:GetAttribute("PanX"), board:GetAttribute("PanY")
		push(lobbySnapshot(evolved))
		board = named(gui, "TalentViewport")
		check(board:GetAttribute("PanX") == keepX and board:GetAttribute("PanY") == keepY, tag .. ": a server refresh keeps the same view of the board")
		-- Stand-ins do not calculate AbsolutePosition; use the independent
		-- layout resolver rather than pretending every child starts at (0,0).
		local rect = screenRect(board, gui, SCREEN)
		board.AbsolutePosition = Vector2.new(rect.x, rect.y)
		input.mouseLocation = board.AbsolutePosition + Vector2.new(100 * scale, 100 * scale) + Vector2.new(0, 58)
		local zoomBefore = board:GetAttribute("Zoom")
		input.InputChanged:Fire({UserInputType = Enum.UserInputType.MouseWheel, Position = v3(0, 0, 1)})
		check(math.abs(board:GetAttribute("Zoom") - math.min(1.35, zoomBefore + 0.1)) < 0.001, tag .. ": mouse wheel zooms the board")
		for _ = 1, 30 do input.InputChanged:Fire({UserInputType = Enum.UserInputType.MouseWheel, Position = v3(0, 0, 1)}) end
		check(board:GetAttribute("Zoom") == 1.35, tag .. ": zoom has an upper bound")
		for _ = 1, 30 do input.InputChanged:Fire({UserInputType = Enum.UserInputType.MouseWheel, Position = v3(0, 0, -1)}) end
		check(board:GetAttribute("Zoom") == 0.65, tag .. ": zoom has a lower bound")
		input.mouseLocation = nil
		clickNamed("TalentCenter")
		local centerX = board:GetAttribute("PanX")
		local finger = {UserInputType = Enum.UserInputType.Touch, Position = v3(90, 90, 0)}
		board.InputBegan:Fire(finger); finger.Position = v3(150, 120, 0); input.InputChanged:Fire(finger); input.InputEnded:Fire(finger)
		check(board:GetAttribute("PanX") ~= centerX, tag .. ": a finger pans the research board")
		node = named(gui, "TalentNode_roundGold")
		local tap = {UserInputType = Enum.UserInputType.MouseButton1, Position = v3(120, 160, 0)}
		node.InputBegan:Fire(tap); input.InputEnded:Fire(tap); node.Activated:Fire(tap); flush()
		check(requestCount("UpgradeTalent") == boughtBefore + 1, tag .. ": a stationary click still sends exactly one upgrade to the server")
		clickNamed("CloseContext")
		check(#input.InputChanged.handlers == listenersBefore, tag .. ": closing the board disconnects its global input handler")
		local lastX = board:GetAttribute("PanX")
		input.InputChanged:Fire({UserInputType = Enum.UserInputType.MouseWheel, Position = v3(0, 0, 1)})
		check(board:GetAttribute("PanX") == lastX, tag .. ": a closed board no longer responds to input")
		push(lobbySnapshot(veteranProfile()))
		-- A different available canvas preserves the explored region rather
		-- than keeping the old desktop offsets on a narrow phone.
		fx({kind="OpenPanel",panel="talents"})
		localPlayer:SetAttribute("DoomReviewSize", "375x667"); flush()
		board = named(gui, "TalentViewport")
		local map = named(board,"TalentMap")
		local root = named(map,"TalentRoot")
		local viewRect = screenRect(board,gui,SCREEN)
		local rootX = map.Position.X.Offset + root.Position.X.Offset * named(map,"TalentZoom").Scale
		check(rootX > 0 and rootX < viewRect.w, tag .. ": the root remains reachable after changing screen shape and node zoom")
		localPlayer:SetAttribute("DoomReviewSize", ""); flush(); clickNamed("CloseContext")
	end)

	step("gallery and shop category navigation", function()
		fx({kind="OpenPanel",panel="inventory"})
		for slot=1,5 do check(countNamed(gui,"SquadSlot_"..slot)==1,tag..": squad has visible slot "..slot) end
		check(countNamed(gui,"Collection_ironman")==1 and countNamed(gui,"Collection_thor")==0,tag..": inventory defaults to owned heroes")
		local starMark = named(gui, "CollectionStars")
		check(starMark ~= nil and starMark.Text == "2", tag .. ": a hero with two stars shows them on its collection card's gold star")
		check(named(gui, "CollectionShiny") ~= nil, tag .. ": a shiny hero sparkles on its collection card")
		click("Todos")
		for _,id in ipairs(Catalog.HeroOrder) do check(countNamed(gui,"Collection_"..id)==1,tag..": collection exposes "..id) end
		click("Meus heróis")
		check(countNamed(gui,"Collection_thor")==0,tag..": owned filter restores compact gallery")
		fx({kind="OpenPanel",panel="chests"})
		check(countNamed(gui,"SummonSelect_rare")==1 and countNamed(gui,"OpenChest_rare")==1 and countNamed(gui,"SummonSelect_base_rare")==0,tag..": rare chest has a dedicated page")
		local odds=named(gui,"SummonOdds")
		local panel=named(gui,"ContextPanel")
		check(panel.Sheen:GetAttribute("Chapter")=="chests",tag..": summon window carries its own chapter artwork")
		-- The odds grid is the whole showcase (owner, 17/10: the heroes of a chest
		-- were hard to see in a small scroll): no featured row, two full rows of
		-- big cards at least, wherever the window is wide.
		check(named(gui,"SummonFeatured")==nil,tag..": no featured row squeezes the chest's heroes")
		local first=odds:GetChildren()[1]
		check(first and first.Size.Y.Offset>=110,tag..": every hero of the chest gets a big portrait card")
		if view().w>=1000 then check(odds.Size.Y.Offset>=240,tag..": at least two rows of hero cards show without scrolling, got "..odds.Size.Y.Offset) end
		local crates=named(gui,"SummonCrates")
		if view().w>=1000 then
			local viewport=screenRect(named(gui,"ContextBody"),gui,SCREEN)
			local gallery=screenRect(odds,gui,SCREEN)
			local buy=screenRect(named(gui,"OpenChest_rare"),gui,SCREEN)
			check(gallery.y+122<=viewport.y+viewport.h and buy.y+buy.h<=viewport.y+viewport.h,tag..": portraits, odds and purchase are visible together before scrolling")
		end
		odds.CanvasPosition=Vector2.new(0,128)
		crates.CanvasPosition=Vector2.new(14,0)
		check(countNamed(gui,"SummonSelect_legendary")==0 and countNamed(gui,"SummonSelect_epic")==0,tag..": the retired chests are gone from the summon hall")
		clickNamed("SummonSelect_jurassic")
		check(countNamed(gui,"OpenChest_jurassic")==1 and countNamed(gui,"OpenChest_rare")==0,tag..": the event chest has its own page")
		check(named(gui,"ChestHero_flavio")~=nil and named(gui,"ChestHero_ironman")~=nil,tag..": the event chest shows its two heroes, Flávio and the Iron Armor")
		-- 99.99% is not a certainty (owner, 18/10: it showed as 100%).
		check(named(gui,"ChestOdds_ironman").Text=="99,99%" and named(gui,"ChestOdds_flavio").Text=="0,01%",tag..": the event chest shows 99,99% and 0,01%, got "..named(gui,"ChestOdds_ironman").Text)
		clickNamed("SummonSelect_cosmic")
		for _,entry in ipairs(Rules.ChestOutcomes("cosmic",0,{})) do
			check((named(gui,"GuaranteedFeature_"..entry.id)~=nil)==entry.guaranteed,tag..": cosmic stars mark the preserved guarantee pool "..entry.id)
		end
		clickNamed("SummonSelect_rare")
		check(named(gui,"SummonOdds").CanvasPosition.Y==128 and named(gui,"SummonCrates").CanvasPosition.X==14,tag..": each summon catalogue retains its scroll when changing crates")
		fx({kind="OpenPanel",panel="premium"})
		click("Vantagens")
		check(countNamed(gui,"PremiumTabs_pass")==1,tag..": premium pass tab stays accessible")
		-- Prices arrive one by one: each updates its own button, the window is
		-- never redrawn for them (that flickered and stuttered).
		local bodyBefore, bannerBefore = named(gui,"ContextBody"), named(gui,"StarterPack")
		-- A price that never answered offers a retry; one that is not on sale says so.
		-- Available products update independently of a missing quote.
		frames(0.5, 20)
		check(bannerBefore ~= nil and named(gui,"StarterPack") == bannerBefore and bannerBefore.Parent ~= nil and named(gui,"ContextBody") == bodyBefore,
			tag..": arriving prices update their buttons without redrawing the shop")
		local retry=named(gui,"Buy_pass:training")
		check(retry~=nil and retry.Text=="Tentar de novo",tag..": a price with no answer offers a retry, got "..tostring(retry and retry.Text))
		check(named(gui,"Buy_product:starterPack").Text=="Indisponível",tag..": an unavailable starter pack cannot remain loading")
		local preview = named(gui,"Buy_pass:speed3")
		check(preview and preview.Text == "19 Robux • Teste", tag .. ": a Studio preview still displays the actual regional price")
		local beforePrompts = #prompts
		preview.Activated:Fire()
		check(#prompts == beforePrompts, tag .. ": a Studio preview cannot open a real purchase even if activated")
		click("Ouro")
		local unsold=named(gui,"Buy_product:gold1000")
		check(unsold~=nil and unsold.Text=="Indisponível",tag..": client off-sale status overrides a server quote")
		-- A product without a real ID in Config is not drawn at all: nothing on sale that cannot be bought.
		do
			local Config=require(shared.Config)
			local saved=Config.Products.Consumables.gold30000.id
			Config.Products.Consumables.gold30000.id=0
			click("Vantagens"); click("Ouro")
			check(named(gui,"Product_gold30000")==nil and named(gui,"Product_gold5000")~=nil,tag..": an unconfigured product is left out of the shop")
			Config.Products.Consumables.gold30000.id=saved
			click("Vantagens"); click("Ouro")
			check(named(gui,"Product_gold30000")~=nil,tag..": a configured product is drawn")
		end
		-- The Gold packs rank themselves: the biggest pack is the best deal and
		-- the mid pack is recommended; each available pack states Gold per Robux.
		check(named(gui,"Badge_gold30000")~=nil and named(gui,"Badge_gold5000")~=nil and named(gui,"Badge_gold1000")==nil and named(gui,"Badge_gold12000")==nil,tag..": only the best-value and the recommended Gold pack wear a badge")
		check(named(gui,"Badge_gold30000").Text=="Melhor valor" and named(gui,"Badge_gold5000").Text=="Sugestão",tag..": regional prices determine best value; recommendations do not claim popularity")
		local valueLine=named(gui,"Value_gold12000")
		check(valueLine~=nil and string.find(valueLine.Text,"387",1,true)~=nil,tag..": a pack states Gold per regional Robux, got "..tostring(valueLine and valueLine.Text))
		click("Vantagens")
		retry=named(gui,"Buy_pass:training")
		collectorPrice=true
		if retry then retry.Activated:Fire(); flush() end
		frames(0.5, 4)
		local priced=named(gui,"Buy_pass:training")
		check(priced~=nil and priced.Text=="23 Robux",tag..": retrying loads the client regional price, not the server price, got "..tostring(priced and priced.Text))
		leaderboardDown=true
		-- Checked right away: a place-bound panel closes once the commander is
		-- far from its totem, as this one is.
		fx({kind="OpenPanel",panel="leaderboard"})
		check(named(gui,"BoardRetry")~=nil,tag..": a leaderboard that failed to load offers a retry instead of loading forever")
		leaderboardDown=false
		local again=named(gui,"BoardRetry")
		if again then again.Activated:Fire(); flush() end
		check(named(gui,"BoardRetry")==nil and named(gui,"BoardFailed")==nil,tag..": retrying clears the failure")
		-- The hall of fame (owner, 17/10): a podium with the leaders' faces, your
		-- own standing, and every board one tap away.
		check(named(gui,"Podium_1")~=nil and named(named(gui,"Podium_1"),"PodiumFace")~=nil and string.find(textOf(named(gui,"Podium_1")),"Ana",1,true)~=nil,tag..": the leader stands on the podium with a face")
		check(named(gui,"BoardStanding")~=nil and string.find(named(gui,"BoardStanding").Text,"#2",1,true)~=nil,tag..": your position on the board is shown, got "..tostring(named(gui,"BoardStanding") and named(gui,"BoardStanding").Text))
		local boardsAsked=requestCount("Leaderboard")
		clickNamed("BoardSize_2")
		check(requestCount("Leaderboard")==boardsAsked+1 and named(gui,"Podium_1")~=nil,tag..": choosing a party size loads that board")
		clickNamed("BoardPeriod_all")
		check(requestCount("Leaderboard")==boardsAsked+2,tag..": the all-time record is one tap away")
		for _,mapId in ipairs(Rules.MapsForMode("ranked")) do check(named(gui,"BoardMap_"..mapId)~=nil,tag..": the "..mapId.." board has its tab") end
		fx({kind="OpenPanel",panel="premium"})
		check(#offscreen(main,view())==0,tag..": category navigation stays on screen")
		-- Everything on sale can be inspected before it is paid for.
		clickNamed("PremiumTabs_pass")
		clickNamed("ProductInfo_training")
		local details=named(gui,"ProductDetails_training")
		check(details~=nil and string.find(textOf(details),Catalog.Products.Passes.training.description.pt,1,true)~=nil,tag..": a pass shows what it gives before it is bought")
		clickNamed("PremiumTabs_hero")
		local anyHero
		for key in pairs(Catalog.Products.Heroes) do if not (profile and profile.heroes and profile.heroes[key]) then anyHero=anyHero or key end end
		if anyHero and named(gui,"ProductInfo_"..anyHero) then
			clickNamed("ProductInfo_"..anyHero)
			local hero=named(gui,"ProductDetails_"..anyHero)
			check(hero~=nil and named(hero,"InfoStat_1")~=nil and named(hero,"InfoStat_3")~=nil,tag..": a hero on sale shows damage, range and speed before it is bought")
		end
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
		check(named(gui,"ContextTitle").Text=="Invocar Bases",tag..": entering the base shop changes its title immediately")
		push(matchSnapshot(p,"Preparing",{base={id="workshop",level=1,stats=Rules.BaseStats("workshop",1),wall=0},cash=1000}))
		-- The base is upgraded at the agent beside it: its prompt opens the window,
		-- another commander's agent does not.
		local function agentPrompt(owner) return { GetAttribute = function(_, key) if key == "BaseOwnerId" then return owner end end } end
		services.ProximityPromptService.PromptTriggered:Fire(agentPrompt(ALLY_ID)); flush()
		check(countNamed(gui,"ConfirmBaseUpgrade")==0,tag..": another commander's agent does not open your base")
		services.ProximityPromptService.PromptTriggered:Fire(agentPrompt(LOCAL_ID)); flush()
		check(countNamed(gui,"ConfirmBaseUpgrade")==1,tag..": the base agent opens the upgrade comparison")
		local upgrade=named(gui,"ConfirmBaseUpgrade"); if upgrade then upgrade.Activated:Fire(); flush() end
		check(asked("UpgradeBase"),tag..": base upgrade uses server intent")
		-- Upgrading does not close the window: it redraws at the new level.
		push(matchSnapshot(p,"Preparing",{base={id="workshop",level=2,stats=Rules.BaseStats("workshop",2),wall=0},cash=1000}))
		check(countNamed(gui,"ConfirmBaseUpgrade")==1 and string.find(textOf(named(gui,"BaseUpgrade")), "2 / 5", 1, true)~=nil,tag..": the base window stays open and shows the new level")
		-- Short of Gold the button still reads (owner, 17/10): the price and what
		-- is missing, in its words; it simply does not upgrade.
		push(matchSnapshot(p,"Preparing",{base={id="workshop",level=2,stats=Rules.BaseStats("workshop",2),wall=0},cash=100}))
		local poor=named(gui,"ConfirmBaseUpgrade")
		local cost=tostring(Rules.BaseStats("workshop",2).upgradeCost)
		check(poor~=nil and string.find(poor.Text,cost,1,true)~=nil and string.find(poor.Text,"faltam",1,true)~=nil and poor.Active==false,
			tag..": a base upgrade you cannot afford names its price and what is missing, got "..tostring(poor and poor.Text))
		check(named(gui,"BaseUpgradeFooter")~=nil and named(named(gui,"BaseUpgradeFooter"),"ConfirmBaseUpgrade")~=nil,tag..": the upgrade button lives in a footer that never scrolls away")
		named(gui,"BaseUpgrade"):Destroy()
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
		click("+ Colocar na equipe")
		check(asked("SetLoadout"),tag .. ": owned hero can be equipped")
		fx({kind="OpenPanel",panel="hero",heroId="ironman"})
		-- Mastery, ability rank, account level and tower upgrade each have their own word.
		local function shows(fragment)
			for _, item in ipairs(gui:GetDescendants()) do
				if type(item.Text) == "string" and string.find(item.Text, fragment, 1, true) then return true end
			end
			return false
		end
		check(shows("Maestria ") and shows("Rank 1/"), tag .. ": the hero page names mastery and ability rank apart")
		check(not shows("Nível do herói"), tag .. ": the hero page no longer calls mastery a level")
		click("Subir para rank")
		check(asked("UpgradeAbility"),tag .. ": leader ability upgrades through server")
		fx({ kind = "OpenPanel", panel = "quests" })
		click("Resgatar recompensa")
		check(asked("ClaimQuest"), tag .. ": the mission board claims a finished quest")
		click("X")
		check(not contextOpen(), tag .. ": the close button dismisses the panel")
	end)

	step("the guide points to the shop when a chest is affordable", function()
		check(named(gui, "Nav_chests") == nil, tag .. ": the dock has no chest button; the chest shop is a place")
		local tip = named(gui, "GuideTip")
		check(tip ~= nil and string.find(tip.Text, "INVOCAÇÃO", 1, true) ~= nil, tag .. ": 2,500 Gold sends the commander to the summon halls")
		fx({kind="OpenPanel",panel="modes",hud=true})
		check(named(gui, "FirstMission") == nil, tag .. ": a trained commander goes straight to the modes")
		click("X")
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
		local function reel() return overlays:FindFirstChild("ChestReel") end
		-- A chest opens like a case (owner, 16/10: the roulette stays): a strip
		-- of prizes slows to a stop on the one the server drew; a tap lands it,
		-- a second tap goes on to the prize card.
		local function throughReel()
			clickNamed("RevealSkip")
			clickNamed("RevealSkip")
			frames(1 / 30, 3)
		end
		chestResult = { chestId = "rare", heroId = "thor", rarity = "legendary", duplicate = false, refundGold = 0, refundMastery = 0 }
		openRare()
		local strip = reel()
		check(strip ~= nil, tag .. ": confirming a chest opens the full-screen reel")
		check(strip ~= nil and countNamed(strip, "ReelTile") == 46 and named(strip, "ReelMarker") ~= nil, tag .. ": a strip of prizes passes a marker")
		check(strip ~= nil and string.find(named(strip, "ReelTitle").Text, Catalog.Upper(Catalog.Chests.rare.name.pt), 1, true) ~= nil, tag .. ": the reel is titled with the chest's name")
		frames(1 / 30, 15)
		local track = strip and named(strip, "ReelTrack")
		check(track ~= nil and track.Position.X.Offset < -100, tag .. ": the strip rushes past the marker")
		clickNamed("RevealSkip")
		check(strip and named(strip, "ReelPrize").Text == Catalog.Upper(Catalog.Heroes.thor.name.pt), tag .. ": it stops on the hero the server granted, got " .. tostring(strip and named(strip, "ReelPrize").Text))
		clickNamed("RevealSkip")
		frames(1 / 30, 3)
		check(reel() == nil, tag .. ": a second tap moves on from the reel")
		local stage = reveal()
		check(stage ~= nil, tag .. ": then the prize card opens")
		local card = stage and named(stage, "RevealHeroCard")
		check(card ~= nil and card.Visible == true, tag .. ": the already granted prize appears immediately after the reel")
		check(stage and named(stage,"ChestView") == nil and named(stage,"RevealChest").Visible == false, tag .. ": no second chest model or opening after the reel")
		check(stage and named(stage,"RevealFlash").BackgroundTransparency == 1, tag .. ": no second opening flash")
		-- The actual hero makes a grounded entrance and keeps its own signature.
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
			check(highest - lowest < 1.5, tag .. ": the receipt does not repeat a chest-emergence leap")
			check(portrait ~= nil and portrait.Parent ~= nil, tag .. ": the live portrait is still the card's portrait")
		else
			check(true, tag .. ": this hero has no jointed figure to animate")
		end
		clickNamed("RevealSkip")
		check(card.Visible and named(stage, "RevealContinue").Visible, tag .. ": a tap skips straight to the hero")
		check(named(stage, "RevealName").Text == Catalog.Heroes.thor.name.pt, tag .. ": the reveal names the hero the server granted")
		check(string.find(named(stage, "RevealStatus").Text, "NOVO", 1, true) ~= nil, tag .. ": a new hero is celebrated as new")
		check(named(stage,"RecruitSaved").Text=="Adicionado à sua coleção",tag..": a new receipt confirms collection ownership")
		check(string.find(named(stage, "RevealRarity").Text, "LENDÁRIO", 1, true) ~= nil, tag .. ": the rarity is shouted with its accent intact, got " .. named(stage, "RevealRarity").Text)
		clickNamed("RevealContinue")
		check(reveal() == nil, tag .. ": the continue button closes the reveal")
		check(countNamed(gui, "ChestResult") == 1, tag .. ": the panel keeps the result card afterwards")

		-- A duplicate plays through on its own and says what it turned into.
		chestResult = { chestId = "rare", heroId = "falcon", rarity = "common", duplicate = true, refundGold = 150, refundMastery = 60, cards = 3 }
		openRare()
		throughReel()
		frames(1 / 30, 90)
		stage = reveal()
		check(stage ~= nil and named(stage, "RevealContinue").Visible, tag .. ": left alone, the reveal finishes by itself")
		check(stage and string.find(named(stage, "RevealStatus").Text, "150", 1, true) ~= nil, tag .. ": a duplicate shows the Gold it became")
		check(stage and string.find(named(stage, "RevealStatus").Text, "+3 CARTAS", 1, true) ~= nil, tag .. ": and the cards it paid for the hero's ladder")
		check(named(stage,"RecruitSaved").Text=="Recompensa do repetido recebida",tag..": a duplicate receipt confirms compensation without claiming a new hero")
		clickNamed("RevealContinue")
		chestResult = { chestId = "rare", heroId = "falcon", rarity = "common", duplicate = true, refundGold = 150, refundMastery = 60, starGained = true, stars = 2 }
		openRare()
		throughReel()
		frames(1 / 30, 90)
		stage = reveal()
		check(stage and string.find(named(stage, "RevealStatus").Text, "+1 ★ (2/5)", 1, true) ~= nil, tag .. ": a duplicate that gains a star says so")
		clickNamed("RevealContinue")
		chestResult = { chestId = "rare", heroId = "falcon", rarity = "common", duplicate = false, refundGold = 0, refundMastery = 0, shiny = true }
		openRare()
		throughReel()
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
		throughReel()
		frames(1 / 30, 25)
		stage = reveal()
		check(stage ~= nil and named(stage, "RevealHeroCard").Visible, tag .. ": with reduced effects the hero shows in under a second")
		check(countNamed(overlays, "Confetti") == 0, tag .. ": reduced effects throws no confetti")
		clickNamed("RevealContinue")
		-- Several at once: the quantity buttons, then one reel per chest and a summary.
		push(lobbySnapshot(veteranProfile({ gold = 9000 })))
		fx({ kind = "OpenPanel", panel = "chests" })
		clickNamed("ChestCountPlus")
		clickNamed("ChestCountPlus")
		check(string.find(named(gui, "ChestCount").Text, "x3", 1, true) ~= nil, tag .. ": the quantity buttons count up, got " .. named(gui, "ChestCount").Text)
		clickNamed("ChestCountMax")
		local most = math.floor(9000 / Catalog.Chests.rare.cost)
		check(string.find(named(gui, "ChestCount").Text, "x" .. most, 1, true) ~= nil, tag .. ": MAX is the most the Gold pays for (9,000 Gold = " .. most .. " Alliance chests)")
		clickNamed("ChestCountMinus")
		clickNamed("OpenChest_rare")
		clickNamed("ConfirmChest_rare")
		check(asked("OpenChest"), tag .. ": several chests go out as one request")
		chestResult = nil
		push(lobbySnapshot(veteranProfile()))
		push(lobbySnapshot(veteranProfile()))
		click("X")
	end)

	step("HUD affordances open their panels", function()
		click("Opções")
		check(contextOpen(), tag .. ": the settings button opens a panel")
		click("Ligado")
		check(asked("Settings"), tag .. ": a settings toggle is sent to the server")
		click("X")
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
		check(named(gui,"ActiveBaseButton")==nil and named(gui,"Nav_bases").Parent.Name=="LobbyNavigation",tag..": Base shares the main dock, with no corner shortcut")
		clickNamed("Nav_bases")
		check(named(gui,"ActiveBaseSummary")~=nil,tag..": active base has a direct HUD entry")
		check(named(gui,"BaseNavigation")==nil and named(gui,"BaseNavigation_inventory")==nil,tag..": Bases has no hero navigation")
		click("X")
		clickNamed("Nav_inventory")
		check(contextOpen(), tag .. ": Heroes opens the owned inventory")
		-- One team, always: no saved formations to pick between.
		check(named(gui, "Salvar") == nil and not asked("SaveLoadout"), tag .. ": the team panel has no saved formations")
	end)

	step("collection tabs, rarity chips, base and direct leader selection",function()
		check(named(gui,"FormationBaseName")==nil and named(gui,"OpenBases")==nil and named(gui,"BasePortrait")==nil,tag..": Heroes shows only heroes, without a base card or base shortcut")
		check(named(gui,"SquadSlots").Size.X.Scale==1 and named(gui,"TeamRow").Size.Y.Offset==104,tag..": five hero slots use the freed width and one row")
		check(named(gui,"HeroSearch")==nil and named(gui,"CycleHeroSort")==nil,tag..": no search box or sort cycle clutters the team screen")
		clickNamed("InventoryTabs_all")
		check(named(gui,"Collection_captain")~=nil,tag..": the All tab shows the whole collection")
		clickNamed("HeroRarity_"..Catalog.RarityOrder[1])
		check(named(gui,"Collection_ironman")~=nil and named(gui,"Collection_thor")==nil,tag..": a rarity chip narrows the collection")
		clickNamed("HeroRarity_all")
		check(named(gui,"Collection_thor")~=nil,tag..": the All chip brings every rarity back")
		check(named(gui,"HeroRarity_epic")==nil and named(gui,"HeroRarity_mythic")==nil,tag..": only three collectible rarity filters remain")
		check(named(gui,"HeroRarity_common"):GetAttribute("TotalCount")==16 and named(gui,"HeroRarity_rare"):GetAttribute("TotalCount")==15 and named(gui,"HeroRarity_legendary"):GetAttribute("TotalCount")==12,tag..": collection counts match the merged roster")
		local filterActions=#actions
		check(named(gui,"HeroRole_air")==nil,tag..": no anti-air filter: every hero hits flyers")
		clickNamed("HeroRole_area")
		check(named(gui,"Collection_hulk")~=nil and named(gui,"Collection_ironman")==nil,tag..": area filter uses the hero's ordinary attack")
		clickNamed("HeroRole_control")
		check(named(gui,"Collection_spiderman")~=nil and named(gui,"Collection_ironman")==nil,tag..": control filter finds slowing heroes")
		clickNamed("HeroRole_support")
		for _,id in ipairs(Catalog.HeroOrder) do check((named(gui,"Collection_"..id)~=nil)==Catalog.Heroes[id].roles.support,tag..": support filter matches catalog "..id) end
		clickNamed("HeroRole_all")
		check(#actions==filterActions and named(gui,"Collection_thor")~=nil,tag..": presentation filters never change the squad or spend Gold")
		clickNamed("InventoryTabs_owned")
		local rows=named(gui,"HeroGallery"):GetChildren()
		check(#rows>0 and named(gui,"HeroGallery").Size.Y.Offset>=0,tag..": owned heroes fill the gallery")
		-- Hovering a hero shows what it does now; leaving it takes the box away.
		local hoverTarget = named(gui, "FormationHero_ironman")
		check(hoverTarget ~= nil, tag .. ": the collection card has a hover target")
		if hoverTarget then
			hoverTarget.MouseEnter:Fire()
			flush()
			local tip = named(gui, "Tooltip")
			local tipTitle = tip and named(tip, "TipTitle")
			check(tip ~= nil and tipTitle ~= nil and tipTitle.Text == Catalog.Heroes.ironman.name.pt, tag .. ": hovering a hero opens a tooltip with its name")
			local lines = {}
			for _, item in ipairs(tip and tip:GetDescendants() or {}) do
				if item.Name == "TipLine" then table.insert(lines, item.Text) end
			end
			local joined = table.concat(lines, " | ")
			check(string.find(joined, "Dano", 1, true) ~= nil and string.find(joined, "Alcance", 1, true) ~= nil, tag .. ": the tooltip lists damage and range, got " .. joined)
			hoverTarget.MouseLeave:Fire()
			flush()
			check(named(gui, "Tooltip") == nil, tag .. ": leaving the card closes the tooltip")
			local finger = { UserInputType = Enum.UserInputType.Touch, UserInputState = Enum.UserInputState.Begin, Position = Vector3.new(screen.w / 2, screen.h / 2, 0) }
			hoverTarget.InputBegan:Fire(finger)
			frames(0.2, 1)
			check(named(gui, "Tooltip") == nil, tag .. ": a quick touch does not open a tooltip")
			frames(0.21, 1)
			check(named(gui, "Tooltip") ~= nil, tag .. ": holding a hero for 0.4 seconds opens its tooltip")
			local beforeHold = #actions
			finger.UserInputState = Enum.UserInputState.End
			input.InputEnded:Fire(finger)
			hoverTarget.Activated:Fire(finger)
			check(named(gui, "Tooltip") == nil and #actions == beforeHold, tag .. ": releasing a held card closes the tooltip without equipping it")
			local swipe = { UserInputType = Enum.UserInputType.Touch, UserInputState = Enum.UserInputState.Begin, Position = finger.Position }
			hoverTarget.InputBegan:Fire(swipe)
			swipe.Position = swipe.Position + Vector3.new(0, 40, 0)
			frames(0.5, 1)
			check(named(gui, "Tooltip") == nil, tag .. ": scrolling a card cancels the hold")
			input.InputEnded:Fire(swipe)
		end
		clickNamed("SquadSlot_1")
		check(named(gui,"CancelLeaderPick")~=nil,tag..": highlighted first slot opens leader selection")
		local tapTarget = named(gui, "FormationHero_spiderman")
		local tap = { UserInputType = Enum.UserInputType.Touch, UserInputState = Enum.UserInputState.Begin, Position = v3(100, 100, 0) }
		tapTarget.InputBegan:Fire(tap)
		frames(0.1, 1)
		tap.UserInputState = Enum.UserInputState.End
		tapTarget.InputEnded:Fire(tap)
		tapTarget.Activated:Fire(tap)
		flush()
		check(actionPayloads.SetLoadout.heroes[1]=="spiderman",tag..": collection directly sends the chosen leader")
		check(actionPayloads.SetLoadout.heroes[2]=="ironman",tag..": changing leader preserves previous squad members")
		-- A hero in the collection (down here) offers two choices; one in the team (up there) leaves at a tap.
		clickNamed("FormationHero_ironman")
		check(named(gui,"HeroChoice")~=nil and named(gui,"ChoiceTeam")~=nil and named(gui,"ChoiceInfo")~=nil,tag..": a tap in the collection offers: put in the team, or see the info")
		clickNamed("SquadSlot_2")
		check(actionPayloads.SetLoadout~=nil and #actionPayloads.SetLoadout.heroes<=1,tag..": a tap on a hero in the team takes it out of the team")
		clickNamed("FormationHero_ironman")
		clickNamed("ChoiceInfo")
		check(named(gui,"MakeLeader_ironman")~=nil,tag..": hero details open on power and squad actions")
		clickNamed("HeroDetail_defense")
		check(named(gui,"HeroStat_1") and named(gui,"HeroBranch_2"),tag..": hero details explain stats and specialization paths")
		check(named(gui,"HeroTargets") == nil,tag..": every hero hits ground and air, so no targets line is shown")
		local back=named(gui,"BackToInventory")
		local backBefore=screenRect(back,gui,SCREEN)
		local detailBody=named(gui,"ContextBody")
		detailBody.CanvasPosition=Vector2.new(0,600)
		frames(1/30,2)
		local backAfter=screenRect(back,gui,SCREEN)
		check(back.Parent.Name=="HeroNavigation" and backBefore.x==backAfter.x and backBefore.y==backAfter.y,tag..": gallery return remains fixed when hero details scroll")
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
		click("X")
		check(not shown(named(gui, "RewardsBadge"), gui) or named(gui, "RewardsBadge").Visible == false,
			tag .. ": no badge with nothing to claim")
		local withRewards = veteranProfile({ rewards = rewardsFixture("ready") })
		push(lobbySnapshot(withRewards))
		local badge = named(gui, "RewardsBadge")
		check(badge ~= nil and badge.Visible == true, tag .. ": the nav badge appears when rewards are claimable")
		check(badge ~= nil and badge.Text == "3", tag .. ": the badge counts what can be claimed, got " .. tostring(badge and badge.Text))
		-- A tile with news bobs as one piece: icon, name and count move together.
		local giftTile = named(gui, "Nav_rewards")
		local giftDisc, giftCaption = giftTile and named(giftTile, "Disc"), giftTile and named(giftTile, "Caption")
		local together = true
		for _ = 1, 8 do
			frames(0.11, 1)
			if giftDisc and giftCaption and badge then
				local lift = giftDisc.Position.Y.Offset - 2
				together = together and math.abs((giftCaption.Position.Y.Offset + 4) - lift) < 1e-6 and math.abs((badge.Position.Y.Offset - 8) - lift) < 1e-6
			end
		end
		check(giftDisc ~= nil and giftCaption ~= nil and together, tag .. ": the gift tile's icon, name and count bob together")

		clickNamed("Nav_rewards")
		check(contextOpen(), tag .. ": the gift tab opens the rewards panel")
		check(named(gui, "ClaimFreeChest") ~= nil, tag .. ": the free chest card renders")
		clickNamed("ClaimFreeChest")
		check(asked("ClaimFreeChest"), tag .. ": the free chest sends its claim intent")
		rewardResult={chest={chestId="rare",heroId="widow",rarity="rare",duplicate=false}}
		clickNamed("ClaimFreeChest")
		check(named(overlays,"ChestReel") ~= nil and named(overlays,"ChestReveal") == nil, tag .. ": a reward chest starts the same reel as a purchased chest")
		clickNamed("RevealSkip"); clickNamed("RevealSkip"); frames(1/30,3)
		local receipt=named(overlays,"ChestReveal")
		check(receipt and named(receipt,"RevealHeroCard").Visible and named(receipt,"ChestView") == nil, tag .. ": reward reel finishes with a receipt, no second opening")
		check(receipt and named(receipt,"RevealName").Text==Catalog.Heroes.widow.name.pt, tag .. ": reward receipt displays the server-granted hero")
		clickNamed("RevealContinue")
		rewardResult=nil
		clickNamed("ClaimLogin")
		check(asked("ClaimLogin"), tag .. ": the login streak sends its claim intent")
		check(named(gui, "LoginDay_3") ~= nil and named(gui, "LoginDay_28") ~= nil, tag .. ": the four-week calendar renders every day")
		clickNamed("ClaimGift")
		check(asked("ClaimGift"), tag .. ": a friend's chest sends its claim intent")
		clickNamed("SendGift_" .. ALLY_ID)
		check(asked("SendGift"), tag .. ": sending a chest to the other player sends SendGift")
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
		rewardResult={chests={
			{chestId="rare",heroId="widow",rarity="rare",duplicate=false},
			{chestId="base_epic",baseId="outpost",rarity="common",duplicate=true,refundGold=100},
			{chestId="legendary",heroId="thor",rarity="legendary",duplicate=false},
		}}
		clickNamed("ClaimSeason")
		check(named(overlays,"ChestReel")~=nil,tag..": a season batch starts its first reel")
		clickNamed("RevealSkip");clickNamed("RevealSkip");frames(1/30,45)
		local second=named(overlays,"ChestReel")
		check(second and string.find(named(second,"ReelTitle").Text,Catalog.Upper(Catalog.Chests.base_epic.name.pt),1,true)~=nil,
			tag..": mixed rewards use the second prize's actual base chest")
		clickNamed("ReelSkipAll")
		local summary=named(overlays,"ChestSummary")
		check(summary and countNamed(summary,"SummaryTile")==3,tag..": reward batches preserve all prizes in one summary")
		clickNamed("RevealContinue")
		rewardResult=nil
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
		click("X")

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
			and panelRect.x + panelRect.w <= view().w and panelRect.y + panelRect.h <= view().h,
			tag .. ": the actual context panel fits the usable screen")
		check(bodyRect ~= nil and bodyRect.w >= 200 and bodyRect.h >= 65,
			tag .. ": the panel keeps a positive, usable scrolling area")
		local focused = UILayout.contextLayout(view().w, view().h, {}).modal
		for _, name in ipairs({"LobbyPill", "SettingsButton", "LobbyNavigation"}) do
			local element = named(gui, name)
			check(element ~= nil and element.Visible == not focused,
				tag .. ": " .. name .. " gives compact panels room and remains available on large screens")
		end
		for _, id in ipairs({"inventory", "bases", "talents", "premium", "rewards"}) do
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
		click("X")
		push(riding)
		-- A campaign car is taller: it carries the row of difficulties.
		local ridingLayout = UILayout.lobbyLayout(view().w, view().h, { difficulty = true })
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
		check(string.find(joined, "Manhattan", 1, true) ~= nil, tag .. ": the card names the sector")
		-- The host's friends-only heart and everyone's invite: thumb-sized, inside
		-- the card, clear of Start, Leave and the difficulty row.
		do
			local cardRect = screenRect(card, gui, SCREEN)
			local rects = {}
			for _, name in ipairs({ "ElevatorFriends", "ElevatorInvite", "ElevatorStartNow", "ElevatorLeave", "Difficulty_normal", "Difficulty_hard", "Difficulty_nightmare", "Difficulty_quick" }) do
				local item = named(card, name)
				if item then rects[name] = screenRect(item, gui, SCREEN) end
			end
			for _, name in ipairs({ "ElevatorFriends", "ElevatorInvite" }) do
				local r = rects[name]
				check(r ~= nil and r.w >= 30 and r.h >= 30 and r.x >= cardRect.x and r.x + r.w <= cardRect.x + cardRect.w, tag .. ": " .. name .. " is a thumb-sized button inside the card")
				for other, o in pairs(rects) do
					if other ~= name and r and o then
						local apart = r.x + r.w <= o.x + 0.5 or o.x + o.w <= r.x + 0.5 or r.y + r.h <= o.y + 0.5 or o.y + o.h <= r.y + 0.5
						check(apart, tag .. ": " .. name .. " does not cover " .. other)
					end
				end
			end
			clickNamed("ElevatorFriends")
			check(asked("ElevatorFriends"), tag .. ": the lock asks the server to close the queue to friends")
			-- The server's answer redraws the card: the lock lights up and the riders' line says so.
			riding.elevator.friendsOnly = true
			push(riding)
			local friends = named(gui, "ElevatorFriends")
			local lit = friends and friends.BackgroundColor3
			check(lit ~= nil and math.abs(lit.R - UILayout.Colors.coral.R) < 1e-3 and math.abs(lit.G - UILayout.Colors.coral.G) < 1e-3 and math.abs(lit.B - UILayout.Colors.coral.B) < 1e-3,
				tag .. ": a friends-only queue lights its lock button")
			local ridersLine = named(gui, "PortalRiders")
			check(ridingLayout.class.short or (ridersLine ~= nil and string.find(ridersLine.Text, "Só amigos", 1, true) ~= nil), tag .. ": the riders' line says the queue is friends-only")
			riding.elevator.friendsOnly = nil
			push(riding)
			card = frameAt(main, ridingLayout.elevator)
		end
		local tip = named(gui, "FirstVisitHint")
		check(tip == nil or tip.Visible == false, tag .. ": the tip strip steps aside while the queue card is up")
		check(named(gui,"PortalChooseMap")==nil,tag..": fixed portal has no map switch")
		local chipIds = table.clone(Catalog.DifficultyOrder)
		table.insert(chipIds, "quick")
		for _, id in ipairs(chipIds) do
			local chip = named(card, "Difficulty_" .. id)
			local chipRect = chip and screenRect(chip, gui, SCREEN)
			local cardRect = screenRect(card, gui, SCREEN)
			check(chipRect ~= nil and chipRect.h >= 30 and chipRect.x >= cardRect.x and chipRect.x + chipRect.w <= cardRect.x + cardRect.w,
				tag .. ": the campaign card shows a thumb-sized " .. id .. " button inside it")
		end
		check(named(named(card, "Difficulty_nightmare"), "DifficultyLock") ~= nil and named(named(card, "Difficulty_normal"), "DifficultyLock") == nil, tag .. ": a difficulty not opened yet shows a drawn lock, an open one does not")
		clickNamed("Difficulty_hard")
		check(asked("SetDifficulty"), tag .. ": the host's pick is sent to the server as an intent")
		clickNamed("Difficulty_quick")
		check(asked("ElevatorQuick"), tag .. ": the quick session is the host's pick on the same row")
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
			and closeRect.y >= 0 and closeRect.y + closeRect.h <= view().h,
			tag .. ": the panel close action stays reachable while boarding")
		click("X")
		click("Sair")
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

	step("a portal's light goes out when the ride is over", function()
		local riding = lobbySnapshot(veteranProfile())
		riding.elevator = { portalId = "normal", modeId = "normal", mapId = "manhattan", carId = "glow-car", queueId = "q-glow", max = 4, remaining = 3, host = true,
			riders = { { userId = LOCAL_ID, name = "Tester" } } }
		push(riding)
		local visuals = workspace:FindFirstChild("DoomClientVisuals")
		check(countNamed(visuals, "RideColumn") == 1, tag .. ": the pad this player rides lights up")
		riding.elevator.departing = true
		push(riding)
		push(matchSnapshot(veteranProfile(), "Preparing"))
		check(countNamed(visuals, "RideColumn") == 0, tag .. ": the light goes out when the battle starts")
		push(lobbySnapshot(veteranProfile()))
		check(countNamed(visuals, "RideColumn") == 0, tag .. ": and the lobby comes back without the white light")
		-- The old path: a lobby redraw with no queue (after the results) used to keep it.
		push(riding)
		push(resultsSnapshot(veteranProfile()))
		push(lobbySnapshot(veteranProfile()))
		check(countNamed(visuals, "RideColumn") == 0, tag .. ": a lobby redrawn after the results keeps no pad light")
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
		check(openCard ~= nil and openCard.Visible == (view().h >= 500 and view().w >= 560), tag .. ": the lesson card steps aside for an open panel only on a short or narrow screen (" .. tostring(view().w) .. "x" .. tostring(view().h) .. ")")
		clickNamed("FindTrainingPortal")
		check(asked("StartTraining") and not asked("StartMatch"), tag .. ": the training button asks the server to board the training queue")
		check(not contextOpen(),tag..": the play menu steps aside once training starts")
	end)

	--========================================================================
	-- Match
	--========================================================================
	local profile = veteranProfile()
	local layout = UILayout.matchLayout(view().w, view().h, { skills = 1, vip = true })
	step("the match HUD lays out", function()
		push(matchSnapshot(profile, "Preparing"))
		check(frameAt(main, layout.top) ~= nil, tag .. ": the match top bar sits where matchLayout puts it")
		check(frameAt(main, layout.heroCards) ~= nil, tag .. ": the hero card band sits where matchLayout puts it")
		-- The hero bar (owner, 17/10): each card prices its hero as the server
		-- will, and a hero the match Gold cannot pay for dims under a veil.
		local firstId = profile.loadout[1]
		local card = named(gui, "HeroCard_" .. firstId)
		check(card ~= nil and named(card, "PricePill") ~= nil and named(card, "CostVeil") ~= nil, tag .. ": a hero card carries its price pill and its veil")
		push(matchSnapshot(profile, "Preparing", {cash = 0}))
		card = named(gui, "HeroCard_" .. firstId)
		check(card ~= nil and named(card, "CostVeil").BackgroundTransparency < 1, tag .. ": a hero you cannot pay for dims")
		push(matchSnapshot(profile, "Preparing", {cash = 100000}))
		card = named(gui, "HeroCard_" .. firstId)
		check(card ~= nil and named(card, "CostVeil").BackgroundTransparency == 1 and named(card, "EnergyCost").Text == tostring(Rules.PlacementCost(firstId, profile, nil)), tag .. ": a hero you can pay for is bright and priced as the server charges")
		push(matchSnapshot(profile, "Preparing"))
		local bad = offscreen(main, view())
		check(#bad == 0, tag .. ": every match element is on screen: " .. table.concat(bad, ", "))
		click("Pronto")
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
		check(speed ~= nil and shown(speed, gui) and string.find(speed.Text, "2x", 1, true) ~= nil,
			tag .. ": the 2x button is visible, got " .. tostring(speed and speed.Text))
		local three = named(gui, "Speed3Toggle")
		check(three ~= nil and shown(three, gui) and string.find(three.Text, "3x", 1, true) ~= nil, tag .. ": 3x is a button of its own")
		check(string.find(three.Text, "Loja", 1, true) ~= nil and string.find(three.Text, "Passe", 1, true) == nil, tag .. ": without the perk the 3x button points to the shop (the game has no passes)")
		clickNamed("Speed3Toggle")
		check(not asked("SetSpeed"), tag .. ": 3x without the pass never asks the server for 3x")
		check(auto ~= nil and shown(auto, gui), tag .. ": the auto-skip toggle is visible")
		-- A mouse over a control explains it.
		speed.MouseEnter:Fire()
		flush()
		local tip = named(gui, "Tooltip")
		local words = {}
		for _, item in ipairs(tip and tip:GetDescendants() or {}) do
			if item:IsA("TextLabel") then table.insert(words, item.Text) end
		end
		check(tip ~= nil and string.find(table.concat(words, " | "), "Velocidade 2x", 1, true) ~= nil, tag .. ": hovering 2x explains it, got " .. table.concat(words, " | "))
		speed.MouseLeave:Fire()
		flush()
		check(named(gui, "Tooltip") == nil, tag .. ": leaving the control closes its tip")
		clickNamed("SpeedToggle")
		check(asked("SetSpeed"), tag .. ": pressing 2x asks the server")
		clickNamed("AutoSkipToggle")
		check(asked("SetAutoSkip"), tag .. ": pressing AUTO asks the server")
		push(matchSnapshot(profile, "Wave", { speed = 2, speedVote = 2, speedVotes = 1, autoSkip = true }))
		check(string.find(named(gui, "SpeedToggle").Text, "2x", 1, true) ~= nil, tag .. ": the 2x button shows 2x once the server says so")
		check(string.find(named(gui, "AutoSkipToggle").Text, "ON", 1, true) ~= nil, tag .. ": auto-skip shows it is on")
		push(matchSnapshot(profile, "Wave", { speed = 1, speedVote = 2, speedVotes = 1, partySize = 2, autoSkip = false }))
		check(string.find(named(gui, "SpeedToggle").Text, "1/2", 1, true) ~= nil,
			tag .. ": in a duo the toggle shows the vote still waiting, got " .. named(gui, "SpeedToggle").Text)
		local bad = offscreen(main, view())
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
		-- Fired without flushing: the flash removes itself on a delay the scheduler would run at once.
		fxRemote.OnClientEvent:Fire({ kind = "EnemyDown", id = 44, enemyId = "lizard", position = v3(0, 0, 0), boss = true })
		check(named(overlays, "BossFlash") ~= nil, tag .. ": a boss kill flashes the screen")
		flush()
		check(string.find(bannerTitle(), "CHEFE DERROTADO", 1, true) ~= nil, tag .. ": a fallen boss gets a big banner, got " .. bannerTitle())
		fx({ kind = "Ability", heroId = "captainmarvel", abilityId = "photonNova", abilityKind = "blast", ultimate = true, ownerId = LOCAL_ID,
			position = v3(0, 0, 0), radius = 60, duration = 2, color = Color3.fromRGB(255, 210, 90), points = {} })
		check(named(overlays, "PowerCutIn") == nil and string.find(bannerTitle(), "NOVA FOTÔNICA", 1, true) == nil,
			tag .. ": your own ultimate puts nothing over the battle: the power itself is the show")
		frames(1 / 30, 120)
		check(named(overlays, "CelebrationBanner") == nil, tag .. ": banners clear themselves")
		push(matchSnapshot(profile, "Preparing"))
		push(matchSnapshot(profile, "Preparing", { completedWaves = 8, wave = 8, nextBoss = 10 }))
		local warned = false
		for _, item in ipairs(gui:GetDescendants()) do
			if type(item.Text) == "string" and string.find(item.Text, "Chefe em 2 ondas", 1, true) then warned = true end
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
		-- Hovering the ground previews the spot (a click would already place).
		table.clear(rays)
		frames(1 / 30, 3)
		-- The mouse location is in viewport pixels (top bar included), so the
		-- hover must turn it into a ray as it is: ScreenPointToRay would add the
		-- top bar again and put the ghost 58 px below the cursor.
		local mouse = input:GetMouseLocation()
		local aimed, offset = 0, {}
		for _, ray in ipairs(rays) do
			if ray.space == "viewport" and ray.x == mouse.X and ray.y == mouse.Y then aimed += 1 else table.insert(offset, ray.space .. " " .. ray.x .. "," .. ray.y) end
		end
		check(aimed > 0 and #offset == 0, tag .. ": the ghost follows the pointer exactly, got " .. aimed .. " aimed, off: " .. table.concat(offset, "; "))
		check(named(gui, "PlacementHint") ~= nil and not named(gui, "PlacementHint"):IsA("TextButton"), tag .. ": the bar under the ghost is a hint, not a confirm button")
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
		-- There is no confirmation step: the click that picks a legal spot places.
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown, Position = v3(SCREEN.w / 2, SCREEN.h / 2, 0) }, false)
		flush()
		check(asked("PlaceTower"), tag .. ": clicking a legal spot sends PlaceTower at once")
		-- A quick right click drops the hero in hand; it is not placed.
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Two, Position = v3(0, 0, 0) }, false)
		flush()
		frames(1 / 30, 2)
		check(countNamed(workspace, "HeroPlacementPreview") > 0, tag .. ": a second hotkey shows its ghost")
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton2, KeyCode = Enum.KeyCode.Unknown, Position = v3(0, 0, 0) }, false)
		input.InputEnded:Fire({ UserInputType = Enum.UserInputType.MouseButton2, KeyCode = Enum.KeyCode.Unknown, Position = v3(0, 0, 0) }, false)
		flush()
		check(countNamed(workspace, "HeroPlacementPreview") == 0, tag .. ": a right click cancels the hero in hand")
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Escape, Position = v3(0, 0, 0) }, false)
		flush()
		local leftover = 0
		for _, item in ipairs(visuals and visuals:GetChildren() or {}) do
			if string.sub(item.Name, 1, 7) == "NoBuild" or item.Name == "BuildEdge" then leftover += 1 end
		end
		check(leftover == 0, tag .. ": leaving placement clears the tint, " .. leftover .. " left")
	end)

	-- Touch: a tap in the world places on the spot, and a tap the interface
	-- already used (processed) never moves anything.
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
		check(placed() == before, tag .. ": a tap the interface already used places nothing")
		input.TouchTapInWorld:Fire(Vector2.new(SCREEN.w / 2, SCREEN.h / 2), false)
		flush()
		check(placed() == before + 1, tag .. ": tapping a legal spot places the tower at once")
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
		tap(10, 10)
		local towerClose=named(gui,"CloseTower")
		check(named(gui,"EnemyCard")==nil and towerClose and shown(towerClose,gui),tag..": selecting a tower closes enemy inspection before showing its upgrades")
		tap(91, -21)
		card = named(gui, "EnemyCard")
		check(card ~= nil and named(card, "EnemyName").Text == "Gekko Colosso" and named(card, "EnemyNote").Text == Catalog.Enemies.lizard.hint.pt, tag .. ": a boss shows its own hint")
		check(not shown(towerClose,gui),tag..": inspecting an enemy closes tower upgrades, including on phones")
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
		check(named(gui, "SheetButton") == nil, tag .. ": the match HUD has no commander's sheet (Ficha) button")
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.C }, false)
		check(named(gui, "CommanderSheet") == nil, tag .. ": the C key opens nothing")
		-- The cards mode keeps its own button: the cards picked so far (a cards
		-- run is one from the start, so it begins as a fresh match here).
		push(resultsSnapshot(sheetProfile))
		push(matchSnapshot(sheetProfile, "Wave", { base = { id = "outpost", level = 2, stats = base, wall = 0 }, cardMode = true, cards = { "sharpen", "sharpen", "income" } }))
		check(named(gui, "SheetButton") == nil and named(gui, "CardsButton") ~= nil, tag .. ": the cards mode has its Cards button and no sheet button")
		clickNamed("CardsButton")
		check(named(gui, "SheetTab_cards") ~= nil and named(gui, "SheetTab_talents") == nil, tag .. ": the cards view shows the cards, not the talents")
		check(named(gui, "SheetCard_sharpen") ~= nil and string.find(textOf(named(gui, "SheetCard_sharpen")), "×2", 1, true) ~= nil and named(gui, "SheetCard_income") ~= nil, tag .. ": each picked card is listed with its stacks")
		clickNamed("CloseSheet")
		check(named(gui, "CommanderSheet") == nil, tag .. ": the close button closes the sheet")
		-- The sheet follows the match: the end of the match closes it.
		clickNamed("CardsButton")
		push(resultsSnapshot(sheetProfile))
		frames(1 / 30, 2)
		check(named(gui, "CommanderSheet") == nil, tag .. ": the sheet closes when the match ends")
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
		-- Picking the hero changes the lesson to the spot.
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.One, Position = v3(0, 0, 0) }, false)
		frames(1 / 30, 3)
		check(string.find(lesson(), "ponto", 1, true) ~= nil or string.find(lesson(), "spot", 1, true) ~= nil, tag .. ": with the hero picked the lesson points at the spot, got " .. lesson())
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
		fresh.rewards={freeChest={ready=true},claimable=1}
		push(lobbySnapshot(fresh))
		frames(1/30,3)
		local freeText=named(gui,"TutorialText")
		check(freeText and string.find(freeText.Text,"grátis",1,true)~=nil,tag..": first chest points to free reward before spending")
		-- The arrow never sits on another button: a dock in a column is pointed at from the side.
		local dockFrame, arrow = named(gui, "LobbyNavigation"), named(gui, "TutorialPointer")
		local column = dockFrame and dockFrame.AbsoluteSize.Y > dockFrame.AbsoluteSize.X * 1.5
		check(arrow ~= nil and arrow.Text == (column and "◀" or "▼"), tag .. ": the gifts arrow points " .. (column and "from the side of the column" or "down at the dock") .. ", got " .. tostring(arrow and arrow.Text))
		fresh.rewards.freeChest.ready=false
		fresh.rewards.claimable=0
		push(lobbySnapshot(fresh))
		frames(1 / 30, 3)
		local function errand()
			local card = named(gui, "TutorialCard")
			local text = card and named(card, "TutorialText")
			return text and text.Text or ""
		end
		check(string.find(errand(), "baú", 1, true) ~= nil, tag .. ": a trained commander with Gold is sent to open the first chest, got " .. errand())
		check(named(workspace, "TutorialArrow") ~= nil, tag .. ": an arrow marks the summon hall")
		local strip = named(gui, "FirstVisitHint")
		check(strip == nil, tag .. ": the tip strip does not repeat the first-chest errand")
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

	step("committed next goal changes with campaign progress",function()
		local p=veteranProfile()
		p.stats={chests=2,matches=5};p.rewards={claimable=0,freeChest={ready=false}}
		p.talentPoints=0;p.quests={};p.gold=0;p.campaign={manhattan={normal=true}}
		p.nextGoal=Rules.NextGoal(p)
		push(lobbySnapshot(p));frames(1/30,2)
		local text=named(gui,"GuideTip")
		check(text and string.find(text.Text,"Complexo Gama",1,true)~=nil and string.find(text.Text,"1/6",1,true)~=nil,tag..": lobby shows server-supplied next sector and real progress")
		push(matchSnapshot(veteranProfile(),"Wave"));frames(1/30,2)
	end)

	step("the map of the day wears a ribbon in the play menu", function()
		local snapshot = lobbySnapshot(veteranProfile())
		snapshot.featured = { mapId = "manhattan", bonus = 0.25, endsAt = os.time() + 3600 }
		push(snapshot)
		fx({ kind = "OpenPanel", panel = "modes", hud = true })
		check(contextOpen(), tag .. ": the play menu opens")
		check(countNamed(gui, "FeaturedRibbon") == 1, tag .. ": exactly one campaign card carries the map-of-the-day ribbon, got " .. countNamed(gui, "FeaturedRibbon"))
		click("X")
		-- The weekend event: its map wears a second ribbon and the HUD counts it down.
		snapshot.event = { active = true, mapId = "gamma", goldScale = 2, startsAt = os.time() - 3600, endsAt = os.time() + 7200, name = { pt = "Tema", en = "Theme" } }
		push(snapshot)
		check(named(gui, "EventTag") ~= nil and string.find(named(gui, "EventTag").Text, "×2", 1, true) ~= nil, tag .. ": the lobby HUD shows the running event, got " .. tostring(named(gui, "EventTag") and named(gui, "EventTag").Text))
		fx({ kind = "OpenPanel", panel = "modes", hud = true })
		check(countNamed(gui, "EventRibbon") == 1, tag .. ": exactly one campaign card carries the event ribbon, got " .. countNamed(gui, "EventRibbon"))
		click("X")
		snapshot.event = { active = false, mapId = "gamma", goldScale = 2, startsAt = os.time() + 86400 + 3600, endsAt = os.time() + 3 * 86400 }
		push(snapshot)
		check(named(gui, "EventTag") ~= nil and string.find(named(gui, "EventTag").Text, "1d", 1, true) ~= nil, tag .. ": a coming event is announced with its countdown, got " .. tostring(named(gui, "EventTag") and named(gui, "EventTag").Text))
		snapshot.event = nil
		push(lobbySnapshot(veteranProfile()))
		fx({ kind = "OpenPanel", panel = "modes", hud = true })
		check(countNamed(gui, "FeaturedRibbon") == 0, tag .. ": no ribbon without a featured map")
		click("X")
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

	step("nearby owned towers retain quick upgrades", function()
		local function board(id) return playerGui:FindFirstChild("Upgrade_" .. id) end
		local function green(c) local g = UILayout.Colors.green; return c ~= nil and math.abs(c.R - g.R) + math.abs(c.G - g.G) + math.abs(c.B - g.B) < 0.01 end
		check(board("t1") ~= nil and board("t2") ~= nil, tag .. ": the player's upgradable towers get an upgrade button in the world")
		check(board("t3") == nil, tag .. ": a finished level-5 tower has none")
		check(board("t4") == nil, tag .. ": an ally's tower has none")
		local first = board("t1") and board("t1"):FindFirstChildOfClass("TextButton")
		check(first ~= nil and string.find(first.Text, "350", 1, true) ~= nil, tag .. ": the button shows the upgrade cost, got " .. tostring(first and first.Text))
		check(first ~= nil and green(first.BackgroundColor3), tag .. ": an affordable upgrade is green")
		check(board("t1") ~= nil and board("t1").Size.X.Offset == math.floor(136 * main.ScreenScale.Scale), tag .. ": a quick upgrade retains the HUD scale after state updates")
		local before = #actions
		if first then first.Activated:Fire(); flush() end
		local sent = false
		for index = before + 1, #actions do if actions[index] == "UpgradeTower" then sent = true end end
		check(sent, tag .. ": tapping it sends UpgradeTower")
		local second = board("t2") and board("t2"):FindFirstChildOfClass("TextButton")
		check(second ~= nil and string.find(second.Text, "Evoluir", 1, true) ~= nil, tag .. ": a level-4 tower offers to evolve")
		if second then second.Activated:Fire(); flush() end
		check(frameAt(main, layout.tower) ~= nil, tag .. ": evolving opens the panel where the branch is chosen")
		click("X")
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

	step("quick upgrades leave the horde visible and prioritize selection", function()
		-- This test isolates selection/budget from camera position; the edge
		-- transition below exercises the real per-frame visibility integration.
		local oldProjection=camera.WorldToViewportPoint
		local clipped=false
		camera.WorldToViewportPoint=function() return v3(clipped and 1 or camera.ViewportSize.X/2,camera.ViewportSize.Y/2,1),true end
		local snapshot = matchSnapshot(profile, "Wave")
		for index = 5, 6 do
			local tower = table.clone(snapshot.match.towers[1])
			tower.id, tower.position = "t" .. index, v3(1000 + index * 10, 0, 0)
			table.insert(snapshot.match.towers, tower)
			world:MakeTower(tower.id, tower.heroId, tower.position, LOCAL_ID)
		end
		local function countVisible()
			local count = 0
			for _, item in ipairs(playerGui:GetChildren()) do
				if string.sub(item.Name, 1, 8) == "Upgrade_" and item.Enabled then count += 1 end
			end
			return count
		end
		push(snapshot)
		check(countVisible() == 2, tag .. ": only two quick upgrades cover the battlefield")
		check(playerGui.Upgrade_t6.Enabled == false, tag .. ": a distant unselected hero has no floating label")
		check(selectTower("t6") ~= nil and playerGui.Upgrade_t6.Enabled, tag .. ": selecting that hero makes its upgrade visible")
		check(countVisible() == 2, tag .. ": selection keeps the same label budget")
		clipped=true;frames(1/60,1)
		check(countVisible()==0,tag..": camera movement hides clipped upgrade cards on the same frame")
		clipped=false;frames(1/60,1)
		check(countVisible()==2,tag..": fully visible cards return without another server snapshot")
		camera.WorldToViewportPoint=oldProjection
		click("X")
		push(matchSnapshot(profile, "Wave"))
		check(playerGui:FindFirstChild("Upgrade_t6") == nil, tag .. ": removing a tower cleans its contextual label")
		for _, model in ipairs(workspace.DoomWorld.Towers:GetChildren()) do
			if model:GetAttribute("TowerId") == "t5" or model:GetAttribute("TowerId") == "t6" then model:Destroy() end
		end
	end)

	step("the tower panel in every state", function()
		check(selectTower("t1") ~= nil, tag .. ": an owned tower opens its panel in the " .. layout.towerVariant .. " slot")
		check(named(gui, "TowerTotals") ~= nil and string.find(named(gui, "TowerTotals").Text, "Abates", 1, true) ~= nil, tag .. ": the tower card shows server damage and kills")
		local upgradeLine = false
		for _, item in ipairs(gui:GetDescendants()) do
			if type(item.Text) == "string" and string.find(item.Text, "Melhoria 2/5", 1, true) then upgradeLine = true end
		end
		check(upgradeLine, tag .. ": a tower's in-match upgrade reads as Melhoria, not a level")
		-- The tall panel has a table (now, and the next value in green); a phone's
		-- strip keeps one line of text. Both read as before -> after.
		local stats = named(gui, "TowerStats")
		local nextDamage, nextRange = named(gui, "TowerNext_damage"), named(gui, "TowerNext_range")
		local shownStats = stats and stats.Text or ((nextDamage and nextDamage.Text or "") .. " | " .. (nextRange and nextRange.Text or ""))
		check(string.find(shownStats, "→ 38", 1, true) ~= nil and string.find(shownStats, "→ 30.6", 1, true) ~= nil,
			tag .. ": the panel shows damage and range as before -> after, got " .. tostring(shownStats))
		click("Melhorar")
		check(asked("UpgradeTower"), tag .. ": the upgrade button reaches the server")
		click("Alvo:")
		check(asked("SetPriority"), tag .. ": targeting cycles")
		local evolved = matchSnapshot(profile, "Preparing")
		for _, tower in ipairs(evolved.match.towers) do
			if tower.id == "t1" then tower.level, tower.totalDamage, tower.kills = 3, 1500, 7 end
		end
		push(evolved)
		check(string.find(named(gui, "TowerTotals").Text, "1.500", 1, true) ~= nil and string.find(named(gui, "TowerTotals").Text, "7", 1, true) ~= nil, tag .. ": tower totals update from the next server snapshot")
		if layout.towerVariant == "tall" then
			check(named(gui, "LevelPip3"):FindFirstChild("UpgradePop") ~= nil, tag .. ": the newly earned upgrade pip pops on the tower card")
		end
		check(selectTower("t2") ~= nil, tag .. ": a level 4 tower offers both specializations")
		check(findButton(gui, "Precisão absoluta") ~= nil and findButton(gui, "Flechas explosivas") ~= nil, tag .. ": both branch buttons are shown")
		local branchOne = named(gui, "TowerBranch1")
		check(branchOne ~= nil and string.find(branchOne.Text, "Dano 96", 1, true) ~= nil, tag .. ": each specialization shows the damage it gives, got " .. tostring(branchOne and branchOne.Text))
		local branchDamage = named(gui, "TowerNext_damage")
		if branchDamage then
			check(string.find(branchDamage.Text, "96", 1, true) ~= nil and string.find(branchDamage.Text, "81", 1, true) ~= nil,
				tag .. ": at upgrade 4 the table's next row shows both specializations' damage, got " .. tostring(branchDamage.Text))
		end
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
		local P = UILayout.protocolLayout(view().w, view().h)
		local veil = overlays and overlays:GetChildren()[#overlays:GetChildren()]
		check(veil ~= nil and frameAt(veil, P.panel) ~= nil, tag .. ": the protocol chooser sits where protocolLayout puts it")
		local choices = 0
		for _, item in ipairs(veil and veil:GetDescendants() or {}) do
			if rawget(item, "__class") == "TextButton" and string.find(item.Text or "", "Escolher", 1, true) == 1 then
				choices += 1
				local r = screenRect(item, gui, SCREEN)
				check(shown(item, gui) and r ~= nil and r.x >= 0 and r.y >= 0
					and r.x + r.w <= view().w and r.y + r.h <= view().h and r.h >= 40,
					tag .. ": every card choice remains visible and comfortably tappable")
			end
		end
		check(choices == 3, tag .. ": all three offered cards have visible choices")
		click("Escolher")
		check(asked("ChooseCard"), tag .. ": a protocol can be chosen")
		push(matchSnapshot(profile, "Wave", { enemies = 12, cardOffers = {} }))
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q, Position = v3(0, 0, 0) }, false)
		flush()
		rayHit = { Instance = workspace:FindFirstChild("DoomWorld").Towers:GetChildren()[1]:FindFirstChild("UpperTorso", true), Position = v3(0, 0, 0) }
		input.InputBegan:Fire({ UserInputType = Enum.UserInputType.MouseButton1, KeyCode = Enum.KeyCode.Unknown, Position = v3(5, 5, 0) }, false)
		flush()
		check(asked("CastSkill"), tag .. ": leader area ability is cast on the click, without a confirmation")
	end)

	-- A card reads like a card: a medallion, one bar per effect with the number
	-- green when it helps and red when it costs, and your running totals in a
	-- corner; the cards have a button of their own.
	step("leader ability previews server radius before casting", function()
		local castBefore = requestCount("CastSkill")
		local ability = {id = "repulsorBarrage", heroId = "ironman", rank = 5, target = "area", cooldown = 0, radius = 37.5}
		push(matchSnapshot(profile, "Wave", {ability = ability, cardOffers = {}}))
		rayHit = {Instance = workspace:FindFirstChild("DoomWorld").Towers:GetChildren()[1]:FindFirstChild("UpperTorso", true), Position = v3(12, 0, 18)}
		input.InputBegan:Fire({UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q}, false)
		frames(1/60)
		local ring = named(workspace, "SkillRangePreview")
		check(ring and ring.Size.Y == 75 and ring.Size.Z == 75, tag .. ": Q shows the server's effective diameter before a click")
		check(requestCount("CastSkill") == castBefore, tag .. ": aiming a regional power does not spend it")
		local outline = named(workspace, "SkillAreaOutline")
		check(outline and #outline:GetChildren() == 28, tag .. ": the radius has a bounded visible outline")
		rayHit.Position = v3(42, 0, -20); frames(1/60)
		check(ring and ring.CFrame.Position.X == 42 and ring.CFrame.Position.Z == -20, tag .. ": the ability preview follows the pointer every frame")
		check(named(workspace, "SkillAreaOutline") == outline and #outline:GetChildren() == 28, tag .. ": pointer motion reuses outline segments")
		check(string.find(named(gui, "PlacementHint").Text, "usar", 1, true) ~= nil, tag .. ": the power hint says cast rather than place a hero")
		localPlayer:SetAttribute("DoomReviewSize", "375x667"); flush()
		ring = named(workspace,"SkillRangePreview")
		check(ring and ring.Size.Y == 75 and requestCount("CastSkill") == castBefore, tag .. ": HUD relayout keeps the skill preview without casting")
		localPlayer:SetAttribute("DoomReviewSize", ""); flush(); ring = named(workspace,"SkillRangePreview")
		rayHit.Position = v3(120, 0, 0); frames(1/60)
		input.InputBegan:Fire({UserInputType = Enum.UserInputType.MouseButton1, Position = v3(5, 5, 0)}, false)
		check(requestCount("CastSkill") == castBefore and ring.Color.R == UILayout.Colors.red.R and ring.Color.G == UILayout.Colors.red.G, tag .. ": off-map aiming is red and never submits a cast")
		rayHit = nil; frames(1/60)
		check(named(workspace, "SkillRangePreview") == nil, tag .. ": aiming at the sky clears the stale area")
		check(named(workspace, "SkillAreaOutline") == nil, tag .. ": aiming at the sky also clears the perimeter")
		input.InputBegan:Fire({UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Escape}, false)
		ability = {id = "airCommand", heroId = "falcon", target = "self", cooldown = 0, radius = 0}
		push(matchSnapshot(profile, "Wave", {ability = ability, cardOffers = {}}))
		input.InputBegan:Fire({UserInputType = Enum.UserInputType.Keyboard, KeyCode = Enum.KeyCode.Q}, false)
		check(requestCount("CastSkill") == castBefore + 1 and named(workspace, "SkillRangePreview") == nil and named(workspace, "SkillAreaOutline") == nil, tag .. ": a global power casts directly without a fictitious circle")
		push(lobbySnapshot(profile))
	end)

	step("cards have a medallion, green and red numbers, totals and a button", function()
		local function same(a, b) return a ~= nil and math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.01 end
		local deck = { cardMode = true, cards = { "sharpen", "sharpen" }, cardOffers = { "glassCannon", "sharpen", "supplyDrop" } }
		push(lobbySnapshot(profile))
		push(matchSnapshot(profile, "Preparing", deck))
		check(named(gui, "CardsButton") ~= nil and shown(named(gui, "CardsButton"), gui), tag .. ": the cards mode has a CARDS button")
		local cardCard = named(overlays, "Card_glassCannon")
		check(cardCard ~= nil, tag .. ": an offered card is drawn as a card")
		check(cardCard ~= nil and named(cardCard, "CardMedallion") ~= nil, tag .. ": with a medallion")
		-- Glass Cannon: +35% damage (green), -15% range (red).
		local greens, reds = 0, 0
		for _, item in ipairs(cardCard and cardCard:GetDescendants() or {}) do
			if item.Name == "EffectValue" then
				if string.sub(item.Text, 1, 1) == "+" then greens += 1; check(same(item.TextColor3, UILayout.Colors.green), tag .. ": a gain is green") end
				if string.sub(item.Text, 1, 1) == "-" then reds += 1; check(same(item.TextColor3, UILayout.Colors.red), tag .. ": a cost is red") end
			end
		end
		check(greens >= 1 and reds >= 1, tag .. ": Glass Cannon shows a green gain and a red cost, got " .. greens .. "/" .. reds)
		-- Two Sharpened Edges already make x1.21: the corner panel shows it.
		local total = named(gui, "CardTotal_damage")
		check(total ~= nil and string.find(textOf(total), "x1.21", 1, true) ~= nil, tag .. ": the corner panel shows the compounded total x1.21")
		-- Taking a card with a cost turns that total red once it falls below 1x.
		push(matchSnapshot(profile, "Preparing", { cardMode = true, cards = { "glassCannon", "glassCannon", "glassCannon" }, cardOffers = {} }))
		local rangeTotal = named(gui, "CardTotal_range")
		check(rangeTotal ~= nil and same(named(rangeTotal, "TotalValue").TextColor3, UILayout.Colors.red), tag .. ": a total below 1x is red")
		push(matchSnapshot(profile, "Preparing", { cardMode = true, cards = {}, cardOffers = {} }))
		check(named(gui, "CardStats") == nil, tag .. ": no cards, no corner panel")
		push(matchSnapshot(profile, "Preparing"))
	end)

	-- The hero's card (the Clash-style ladder): cards from duplicates plus Gold
	-- raise its level with no top; each level brings a point for damage, attack
	-- speed or range.
	step("the hero page carries the card ladder", function()
		local ranked = veteranProfile({ gold = 5000 })
		ranked.heroes.ironman = { xp = 300, level = 3, stars = 2, rank = 3, copies = 6, alloc = { damage = 1, speed = 0, range = 0 } }
		push(lobbySnapshot(ranked))
		fx({ kind = "OpenPanel", panel = "hero", heroId = "ironman", hud = true })
		check(named(gui, "HeroCardLadder") ~= nil, tag .. ": an owned hero shows its card")
		check(string.find(named(gui, "HeroCardRank").Text, "3", 1, true) ~= nil, tag .. ": with its level")
		check(string.find(named(gui, "HeroCardCopies").Text, "6 / 5", 1, true) ~= nil, tag .. ": and the cards it has against the cards the next level needs (6 / 5)")
		check(string.find(named(gui, "HeroCardPoints").Text, "1", 1, true) ~= nil, tag .. ": rank 3 earned 2 points, 1 spent, 1 free")
		clickNamed("RankUpHero_ironman")
		check(asked("RankUpHero"), tag .. ": levelling the card asks the server")
		clickNamed("HeroPointPlus_range")
		check(asked("SetHeroPoints"), tag .. ": spending a point asks the server")
		check(string.find(named(gui, "HeroCardBonus_damage").Text, "+11%", 1, true) ~= nil, tag .. ": damage shows base 8% plus one point 3%, got " .. named(gui, "HeroCardBonus_damage").Text)
		-- Too few cards: the button is dead and says what is missing.
		ranked.heroes.ironman.copies = 1
		push(lobbySnapshot(ranked))
		fx({ kind = "OpenPanel", panel = "hero", heroId = "ironman", hud = true })
		check(string.find(named(gui, "HeroCardHint").Text, "Faltam", 1, true) ~= nil, tag .. ": a missing card is named")
		push(lobbySnapshot(veteranProfile()))
		click("X")
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
		fx({kind="Ability",heroId="spiderman",abilityKind="slow",position=v3(55,0,55),radius=10,duration=3,color=Color3.fromRGB(230,240,250)})
		local hollowPower
		for _,item in ipairs(workspace.DoomClientVisuals:GetChildren()) do
			if item:FindFirstChild("RingGui") and item.Size.Y==20 and item.Transparency>=.95 then hollowPower=item end
		end
		check(hollowPower~=nil,tag..": confirmed player power leaves enemies visible through its hollow area")
		check(warningPart and warningPart.Transparency<.8,tag..": cosmetic power does not weaken the boss danger telegraph")
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
		-- A cleared wave: the heroes cheer, arms in the air with a little hop,
		-- then stand at rest again (owner, 16/10: heroes come alive).
		-- Measured against the chest: the new phase may turn the whole figure.
		local function handOnChest() return chest.CFrame:Inverse() * hand.Position end
		local onChest = hand and chest and handOnChest()
		push(matchSnapshot(profile, "Wave"))
		frames(0.1, 1)
		push(matchSnapshot(profile, "Preparing"))
		frames(0.1, 7)
		local raised = onChest and (handOnChest() - onChest).Magnitude or 0
		check(raised > 0.05, tag .. ": a cleared wave makes the heroes cheer, hand moved " .. raised)
		frames(0.1, 20)
		local after = onChest and (handOnChest() - onChest).Magnitude or math.huge
		check(after < 0.01, tag .. ": after the cheer a hero stands at rest again, off by " .. after)
		-- A hero just placed (the server's placement pulse names its tower) hops
		-- onto its pedestal, then stands on it again.
		local chestY = chest and chest.Position.Y
		fx({ kind = "Pulse", position = v3(10, 0, 10), radius = 5, duration = 0.45, color = Color3.fromRGB(220, 48, 51), towerId = "t1" })
		frames(0.1, 3)
		check(chest and chest.Position.Y > chestY + 0.3, tag .. ": a hero just placed hops onto its pedestal")
		frames(0.1, 10)
		-- (Within a breath: a hero at rest breathes a few hundredths of a stud.)
		local settle = chest and math.abs(chest.Position.Y - chestY) or math.huge
		check(settle < 0.08, tag .. ": after the hop it stands on its pedestal again, off by " .. settle)
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
		-- Effects that grow over their life grow from their birth size: at a high
		-- frame rate a per-frame multiply compounds into map-wide neon bars.
		do
			local largest, culprit = 0, ""
			for index, heroId in ipairs({ "hawkeye", "ironman", "captain" }) do
				local towerId = "vfx-fps" .. index
				world:MakeTower(towerId, heroId, v3(90 + index * 3, 0, 70), LOCAL_ID)
				fx({ kind = "Shot", from = v3(90 + index * 3, 4, 70), to = v3(90 + index * 3, 2, 50), color = Color3.fromRGB(200, 200, 200), towerId = towerId, heroId = heroId })
				for _ = 1, 160 do
					frames(1 / 240, 1)
					for _, item in ipairs(workspace:FindFirstChild("DoomClientVisuals"):GetChildren()) do
						if item.Name == "CombatEffect" then
							local size = math.max(item.Size.X, item.Size.Y, item.Size.Z)
							if size > largest then largest, culprit = size, heroId end
						end
					end
				end
			end
			check(largest < 40, tag .. ": no combat effect outgrows its shot at 240 fps, largest " .. string.format("%.1f", largest) .. " studs from " .. culprit)
		end
		fx({kind="CardPicked",cardId="sharpen",rarity="common"})
		fx({kind="EnemyDown",id=4,enemyId="lizard",position=v3(32,0,0),boss=true})
		fx({ kind = "EnemySync", enemies = { enemies[1] } })
		frames(0.5, 4)
		fx({ kind = "Clear" })
		frames(1 / 30, 2)
	end)

	step("confirmed anticipation expires and never creates a hit", function()
		local testProfile = veteranProfile()
		push(matchSnapshot(testProfile, "Wave", {enemies=0}))
		fx({kind="Clear"})
		local tower = world:MakeTower("weight-test","hulk",v3(70,0,70),LOCAL_ID)
		fx({kind="Shot",towerId="weight-test",heroId="hulk",from=v3(70,4,70),to=v3(70,2,50),interval=1})
		frames(.1,7)
		local shoulder = tower:FindFirstChild("LeftShoulder",true)
		local rest = (shoulder.Transform or CFrame.new()).LookVector
		local visuals = workspace.DoomClientVisuals
		local before = countNamed(visuals,"CombatEffect")
		fx({kind="Shots",shots={},windups={{towerId="weight-test",to=v3(70,2,50),duration=0.23}}})
		frames(1/60,10)
		check(((shoulder.Transform or CFrame.new()).LookVector-rest).Magnitude>0.5,tag..": real windup visibly lifts a heavy hero's arms")
		check(countNamed(visuals,"CombatEffect")==before,tag..": anticipation emits no projectile or impact")
		frames(1/60,14)
		check((shoulder.Transform.LookVector-rest).Magnitude<0.02,tag..": missing confirmation expires back to rest")
		fx({kind="Windup",towerId="weight-test",to=v3(70,2,50),duration=.23})
		frames(1/60,8)
		fx({kind="Shot",towerId="weight-test",heroId="hulk",from=v3(70,4,70),to=v3(70,2,50),interval=1})
		frames(1/60,1)
		check(countNamed(visuals,"CombatEffect")>before,tag..": only a confirmed shot creates an impact")
		frames(1/60,40)
		check((shoulder.Transform.LookVector-rest).Magnitude<0.02,tag..": confirmed attack clears anticipation without pose drift")
		testProfile.settings.lowFX=true
		push(matchSnapshot(testProfile,"Wave",{enemies=0}))
		frames(1/60,2)
		fx({kind="Windup",towerId="weight-test",to=v3(70,2,50),duration=.23})
		frames(1/60,10)
		check((shoulder.Transform.LookVector-rest).Magnitude<0.02,tag..": reduced effects suppress anticipation")
		tower:Destroy()
		fx({kind="Clear"})
	end)

	step("ultimate banners preserve each hero's power sound", function()
		push(matchSnapshot(veteranProfile(), "Wave", {enemies = 0}))
		local folder = services.SoundService:FindFirstChild("DoomAudio")
		local bank = require(clientModules.SoundBank)
		local oldCamera = camera.CFrame
		camera.CFrame = CFrame.new(0, 30, 20)
		for heroId, cue in pairs({thor = "powerLightning", wanda = "powerMagic"}) do
			for _, voice in ipairs(folder:GetChildren()) do
				if string.match(voice.Name, "^Bank_powers_") then voice:Stop() end
			end
			advance(1)
			local ability = Catalog.Abilities[Catalog.Heroes[heroId].ability]
			fx({kind = "Ability", heroId = heroId, abilityId = ability.id, abilityKind = ability.kind,
				ownerId = LOCAL_ID, ultimate = true, position = v3(0, 0, 0), radius = 12,
				color = Color3.fromRGB(110, 180, 255)})
			local playing, matched = 0, false
			for _, voice in ipairs(folder:GetChildren()) do
				if string.match(voice.Name, "^Bank_powers_") and voice.IsPlaying then
					playing += 1
					matched = voice.PlaybackRegion.Min == bank[cue].regions[1][1]
						and voice.SoundId == "rbxassetid://" .. SharedConfig.Audio.sfxPowers
				end
			end
			check(playing == 1 and matched, tag .. ": " .. heroId .. " ultimate plays its own power cue once, without the banner consuming its cooldown")
		end
		camera.CFrame = oldCamera
		fx({kind = "Clear"})
	end)

	step("dense attack effects preserve silhouettes and return to their pool", function()
		push(matchSnapshot(profile, "Wave", {enemies = 0}))
		fx({kind = "Clear"})
		world:MakeTower("refine-beam", "cyclops", v3(70, 0, 70), LOCAL_ID)
		local visuals = workspace:FindFirstChild("DoomClientVisuals")
		local shot = {kind = "Shot", heroId = "cyclops", towerId = "refine-beam", from = v3(70, 4, 70), to = v3(70, 2, 50), color = Color3.fromRGB(220, 50, 70)}
		fx(shot)
		local cores, glows, sparks = 0, 0, 0
		for _, item in ipairs(visuals:GetChildren()) do
			if item.Name == "CombatEffect" and item.Size.Z > 10 and item.Shape == Enum.PartType.Block then
				cores += 1
				check(item.Size.X < .6 and item.Transparency >= .15, tag .. ": laser does not cover the enemy with an opaque slab")
			end
		end
		for _, item in ipairs(visuals:GetDescendants()) do
			if item.Name == "CombatBeam" and item.Enabled == true then
				glows += 1
				check(item.FaceCamera == true and item.Width0 < 2 and (item.LightEmission or 0) <= 0.2, tag .. ": the outer glow is a narrow camera-facing beam with tame light")
			end
			if item.ClassName == "ParticleEmitter" then sparks += item.Emitted or 0 end
		end
		check(cores == 1 and glows == 1, tag .. ": laser uses a narrow core part and a restrained outer Beam")
		check(sparks > 0, tag .. ": the hit throws particle sparks instead of pool parts")
		for _ = 1, 40 do fx(shot) end
		check(countNamed(visuals, "CombatEffect") <= 80, tag .. ": dense fire stays within the shared effect budget")
		frames(1 / 30, 25)
		check(countNamed(visuals, "CombatEffect") == 0, tag .. ": all attack primitives expire from the scene")
		local lit = 0
		for _, item in ipairs(visuals:GetDescendants()) do if item.Name == "CombatBeam" and item.Enabled == true then lit += 1 end end
		check(lit == 0, tag .. ": every laser Beam switches off and returns to its pool")
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

	step("every hero's power has a sound that fits it, heard by its caster", function()
		local AudioModule = require(clientModules.Audio)
		local bank = require(clientModules.SoundBank)
		local missing = {}
		for _, heroId in ipairs(Catalog.HeroOrder) do
			local spec = AudioModule.HeroPower[heroId]
			if not spec or not bank[spec[1]] or type(spec[2]) ~= "number" or spec[2] < 0.5 or spec[2] > 2 then table.insert(missing, heroId) end
		end
		check(#missing == 0, tag .. ": every hero's power names a bank sound and a pitch: " .. table.concat(missing, ", "))
		-- The commander's own power is heard even when it lands far from the camera.
		push(matchSnapshot(veteranProfile(), "Wave", {enemies = 0}))
		local folder = services.SoundService:FindFirstChild("DoomAudio")
		for _, voice in ipairs(folder:GetChildren()) do if string.match(voice.Name, "^Bank_powers_") then voice:Stop() end end
		advance(1)
		local ability = Catalog.Abilities[Catalog.Heroes.ironman.ability]
		fx({kind = "Ability", heroId = "ironman", abilityId = ability.id, abilityKind = ability.kind, ownerId = LOCAL_ID,
			position = camera.CFrame.Position + v3(400, 0, 0), radius = 12, color = Color3.fromRGB(255, 90, 70)})
		local heard = false
		for _, voice in ipairs(folder:GetChildren()) do
			if string.match(voice.Name, "^Bank_powers_") and voice.IsPlaying and voice.Volume >= 0.3 then heard = true end
		end
		check(heard, tag .. ": the commander hears their own power at full volume, however far it lands")
		-- Then the power's own score: every hero has one, of bank sounds, timed to its look.
		local scores, badScore = AudioModule.PowerScores, {}
		for _, heroId in ipairs(Catalog.HeroOrder) do
			local score = scores[heroId]
			local fine = type(score) == "table" and #score >= 2 and #score <= 8
			for _, note in ipairs(score or {}) do
				fine = fine and bank[note[2]] ~= nil and note[1] >= 0 and note[1] <= 1.5 and note[3] >= 0.5 and note[3] <= 2 and note[4] > 0 and note[4] <= 1
			end
			if not fine then table.insert(badScore, heroId) end
		end
		check(#badScore == 0, tag .. ": every hero's power has a score of bank sounds timed to its look: " .. table.concat(badScore, ", "))
		local scored = 0
		for _, voice in ipairs(folder:GetChildren()) do
			if string.match(voice.Name, "^Bank_score_") and voice.IsPlaying then scored += 1 end
		end
		check(scored >= 2, tag .. ": the commander's power plays its score after the first sound, got " .. scored .. " notes")
		-- A power that falls sounds as it lands: its score has a note there.
		local unsung = {}
		for _, heroId in ipairs(Catalog.HeroOrder) do
			local def = Catalog.Abilities[Catalog.Heroes[heroId].ability]
			local landing = Rules.AbilityLanding(def, 1)
			if landing > 0 then
				local heard = false
				for _, note in ipairs(scores[heroId] or {}) do if math.abs(note[1] - landing) <= 0.03 then heard = true end end
				if not heard then table.insert(unsung, heroId) end
			end
		end
		check(#unsung == 0, tag .. ": every power that falls has a note as it lands: " .. table.concat(unsung, ", "))
		fx({kind = "Clear"})
	end)

	step("every hero's power has its own look, and nothing covers the screen", function()
		local PowerFXModule = require(clientModules.PowerFX)
		local missing = {}
		for _, heroId in ipairs(Catalog.HeroOrder) do
			if type(PowerFXModule.SIGNATURES[heroId]) ~= "function" then table.insert(missing, heroId) end
		end
		check(#missing == 0, tag .. ": every hero has a power look of its own: " .. table.concat(missing, ", "))
		-- Each look on its own: it runs without an error (delayed layers included),
		-- costs a bounded number of parts at its peak and leaves nothing behind.
		local probe = PowerFXModule.new(workspace)
		for _, heroId in ipairs(Catalog.HeroOrder) do
			local ability = Catalog.Abilities[Catalog.Heroes[heroId].ability]
			probe.lastError = nil
			local cast = probe:Cast({heroId = heroId, abilityKind = ability.kind, position = v3(0, 0, 0), radius = 12, points = {v3(3, 0, 2), v3(-4, 0, 1)}},
				Color3.fromRGB(ability.color[1], ability.color[2], ability.color[3]))
			local most = 0
			for _ = 1, 100 do
				probe:Step(1 / 30)
				most = math.max(most, (probe:Count()))
			end
			check(cast and probe.lastError == nil, tag .. ": " .. heroId .. "'s power look runs cleanly: " .. tostring(probe.lastError))
			check(most > 0 and most <= 60, tag .. ": " .. heroId .. "'s power look peaks at a bounded part count, got " .. most)
			check(probe:Count() == 0, tag .. ": " .. heroId .. "'s power look leaves nothing behind")
		end
		-- A power that falls lands as the server strikes (Rules.AbilityLanding):
		-- some layer of its look appears at every landing, missile by missile and
		-- bolt by bolt; and a bolt goes to where its enemy is by then.
		local born, offbeat = {}, {}
		local spawnRecord = probe._spawn
		probe._spawn = function(self, record)
			local result = spawnRecord(self, record)
			table.insert(born, record.born)
			return result
		end
		local targets, points = {}, {}
		for index = 1, 4 do targets[index], points[index] = "e" .. index, v3(index * 2, 0, -index) end
		for _, heroId in ipairs(Catalog.HeroOrder) do
			local ability = Catalog.Abilities[Catalog.Heroes[heroId].ability]
			if Rules.AbilityLanding(ability, 1) > 0 then
				probe:Clear()
				table.clear(born)
				local cast = probe.clock
				probe:Cast({heroId = heroId, abilityId = ability.id, abilityKind = ability.kind, position = v3(0, 0, 0), radius = 12, points = points, targets = targets},
					Color3.fromRGB(ability.color[1], ability.color[2], ability.color[3]))
				for _ = 1, 60 do probe:Step(1 / 30) end
				local landings = if ability.kind == "chain" then #points else Rules.AbilityHits(ability)
				for index = 1, landings do
					local at, seen = Rules.AbilityLanding(ability, index), false
					for _, moment in ipairs(born) do if moment - cast >= at - 0.001 and moment - cast <= at + 0.05 then seen = true end end
					if not seen then table.insert(offbeat, heroId .. "#" .. index) end
				end
			end
		end
		check(#offbeat == 0, tag .. ": every power that falls draws its landing as the server strikes: " .. table.concat(offbeat, ", "))
		probe._spawn = nil
		probe:Clear()
		local tracked = v3(20, 0, 20)
		probe.locate = function(id) return if id == "e7" then tracked else nil end
		local thunder = Catalog.Abilities.thunderCall
		probe:Cast({heroId = "thor", abilityId = thunder.id, abilityKind = thunder.kind, position = v3(0, 0, 0), radius = 12, points = {v3(3, 0, 2)}, targets = {"e7"}},
			Color3.fromRGB(120, 220, 255))
		local reached = false
		for _ = 1, 30 do
			probe:Step(1 / 30)
			for _, item in ipairs(probe.folder:GetChildren()) do
				if item.Name == "PowerEffect" and (item.Position - (tracked + v3(0, 1, 0))).Magnitude < 1.5 then reached = true end
			end
		end
		check(reached, tag .. ": thunder's bolt goes to where its enemy stands when it lands")
		probe.locate = nil
		probe:Clear()
		probe.folder:Destroy()
		for kind, spec in pairs(PowerFXModule.PARTICLES) do
			check(type(spec[1]) == "string" and string.match(spec[1], "^[%w_]+%.dds$") ~= nil, tag .. ": particle " .. kind .. " uses an engine texture")
		end
		push(matchSnapshot(veteranProfile(), "Wave", {enemies = 0}))
		fx({kind = "Clear"})
		local folder = workspace.DoomClientVisuals:FindFirstChild("PowerFX")
		check(folder ~= nil, tag .. ": the power looks have a folder of their own")
		local function shown()
			local count = 0
			for _, item in ipairs(folder:GetChildren()) do if item.Name == "PowerEffect" then count += 1 end end
			return count
		end
		-- The commander's own ultimate: the hero's own look on the road, nothing on the screen.
		local thunder = Catalog.Abilities[Catalog.Heroes.thor.ability]
		fx({kind = "Ability", heroId = "thor", abilityId = thunder.id, abilityKind = thunder.kind, ultimate = true, ownerId = LOCAL_ID,
			position = v3(0, 0, 0), radius = 14, duration = 2, color = Color3.fromRGB(120, 220, 255), points = {v3(4, 0, 2)}, shake = 1.1})
		check(named(overlays, "PowerCutIn") == nil and named(overlays, "PowerCutInStrip") == nil, tag .. ": a power puts no band or strip over the screen")
		frames(1 / 30, 12)
		local peak = shown()
		check(peak > 4, tag .. ": the hero's own power look is on the road, got " .. peak)
		-- Every hero's look at once (a teammate's: a strip, not the full cut-in) stays inside its pool.
		for _, heroId in ipairs(Catalog.HeroOrder) do
			local ability = Catalog.Abilities[Catalog.Heroes[heroId].ability]
			fx({kind = "Ability", heroId = heroId, abilityId = ability.id, abilityKind = ability.kind, ownerId = LOCAL_ID + 1,
				position = v3(0, 0, 0), radius = 12, duration = 2, color = Color3.fromRGB(ability.color[1], ability.color[2], ability.color[3]), points = {v3(3, 0, 2)}})
			frames(1 / 30, 1)
			check(shown() <= PowerFXModule.MAX_PARTS, tag .. ": the power looks stay inside their pool after " .. heroId)
		end
		check(named(overlays, "PowerCutInStrip") == nil, tag .. ": a teammate's power puts nothing on the screen either")
		frames(1 / 30, 120)
		check(shown() == 0, tag .. ": every power look clears itself")
		-- Reduced effects: no cut-in and no power look (the radius ring stays).
		local calm = veteranProfile()
		calm.settings.lowFX = true
		push(matchSnapshot(calm, "Wave", {enemies = 0}))
		fx({kind = "Ability", heroId = "thor", abilityId = thunder.id, abilityKind = thunder.kind, ultimate = true, ownerId = LOCAL_ID,
			position = v3(0, 0, 0), radius = 14, duration = 2, color = Color3.fromRGB(120, 220, 255)})
		frames(1 / 30, 6)
		check(shown() == 0 and named(overlays, "PowerCutIn") == nil, tag .. ": reduced effects draws no power look")
		fx({kind = "Clear"})
	end)

	step("every hero's shot has a weapon sound", function()
		local EffectsModule = require(effectsScript)
		local missing = {}
		for _, heroId in ipairs(Catalog.HeroOrder) do
			local cue = EffectsModule.ShotSound(heroId)
			if SharedConfig.Audio[cue] == nil or SharedConfig.BuiltinCues[cue] == nil then table.insert(missing, heroId .. ":" .. tostring(cue)) end
		end
		check(#missing == 0, tag .. ": every hero maps to a configured weapon cue with a built-in fallback: " .. table.concat(missing, ", "))
		-- And every hero's blow is heard: its recording family has a loudness gain
		-- (the iron armour's repulsor is a beam, 16/10).
		local AudioModule = require(clientModules.Audio)
		local quiet = {}
		for heroId in pairs(Catalog.Heroes) do
			local bank = AudioModule.WeaponProfile(heroId, EffectsModule.ShotSound(heroId))
			if not AudioModule.BankGain[bank] then table.insert(quiet, heroId .. ":" .. tostring(bank)) end
		end
		check(#quiet == 0, tag .. ": every hero's weapon sound has a loudness gain, missing: " .. table.concat(quiet, ", "))
		check(AudioModule.WeaponProfile("ironman", EffectsModule.ShotSound("ironman")) == "beam", tag .. ": the iron armour's repulsor sounds like a beam")
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
		fx({ kind = "EnemySync", hits = { [9] = 20 }, enemies = { { id = 9, enemyId = "runner", position = v3(1, 0, 0), hp = 10, maxHP = 36 } } })
		local damageLabel
		for _, item in ipairs(workspace:FindFirstChild("DoomClientVisuals"):GetDescendants()) do if item:IsA("TextLabel") and item.Text == "-20" then damageLabel = item end end
		check(damageLabel ~= nil, tag .. ": a confirmed strong hit keeps its number under reduced effects")
		local calmSize = damageLabel and damageLabel.TextSize
		fx({ kind = "Shot", from = v3(10, 4, 10), to = v3(0, 2, 0), color = Color3.fromRGB(1, 1, 1), towerId = "t2" })
		frames(1 / 30, 5)
		check(damageLabel and damageLabel.TextSize == calmSize, tag .. ": reduced effects removes the damage-number pop")
	end)

	--========================================================================
	-- Results, language and resize
	--========================================================================
	-- Opening a screen and leaving it open must not make it flicker: a periodic
	-- snapshot whose only news is a ticking clock never redraws it.
	step("an open screen is never redrawn by periodic snapshots or ticking clocks", function()
		local base = veteranProfile()
		base.rewards = rewardsFixture("empty")
		push(lobbySnapshot(base))
		local redrawn = {}
		for _, kind in ipairs({ "inventory", "squad", "chests", "bases", "premium", "shop", "rewards", "quests", "modes", "maps", "settings", "talents" }) do
			-- Missions open from the dock (a board-opened panel closes when the
			-- commander walks away, and this one stands far from the board).
			if kind == "quests" then
				-- A short phone hides the dock behind an open window: close it first.
				if named(gui, "CloseContext") then clickNamed("CloseContext"); frames(0.5, 1) end
				clickNamed("Nav_quests")
			else
				fx({ kind = "OpenPanel", panel = kind })
			end
			frames(0.5, 2)
			local body = named(gui, "ContextBody")
			local marker
			for _, child in ipairs(body and body:GetChildren() or {}) do
				if not child:IsA("UIComponent") then marker = child; break end
			end
			for tick = 1, 4 do
				local again = table.clone(base)
				again.rewards = rewardsFixture("empty")
				again.rewards.freeChest.remaining = 3600 - tick * 2
				again.rewards.playtime.seconds = 60 + tick * 2
				push(lobbySnapshot(again))
				frames(0.5, 1)
			end
			-- An empty screen (no missions yet) has no row to watch: the same body must stay.
			if body == nil or (marker ~= nil and marker.Parent == nil) or named(gui, "ContextBody") ~= body then table.insert(redrawn, kind) end
		end
		check(#redrawn == 0, tag .. ": open screens keep their content through periodic snapshots, redrawn: " .. table.concat(redrawn, ", "))
		local clock = named(gui, "FreeChestClock")
		fx({ kind = "OpenPanel", panel = "rewards" })
		clock = named(gui, "FreeChestClock")
		check(clock ~= nil and string.find(clock.Text, "59m", 1, true) ~= nil, tag .. ": the free chest clock still ticks in place, got " .. tostring(clock and clock.Text))
		push(lobbySnapshot(veteranProfile()))
	end)

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
		local gutter = body and body:FindFirstChildOfClass("UIPadding")
		check(gutter and gutter.PaddingLeft.Offset >= 6 and gutter.PaddingRight.Offset >= 6 and gutter.PaddingTop.Offset >= 6 and gutter.PaddingBottom.Offset >= 6,
			tag .. ": result cards keep their rounded strokes inside the scroll clip on all four sides")
		check(back ~= nil and body ~= nil and back.Parent == body.Parent,
			tag .. ": return action remains outside the long rewards scroll")
		local backRect, bodyRect = screenRect(back, gui, SCREEN), screenRect(body, gui, SCREEN)
		check(backRect ~= nil and backRect.x >= 0 and backRect.y >= 0
			and backRect.x + backRect.w <= view().w and backRect.y + backRect.h <= view().h and backRect.h >= 44,
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
		-- The end screen: no hero figures beside the panel, and one even dark veil
		-- over the whole screen (Roblox's top bar included), gone after the results.
		check(named(gui, "ResultChampionLeft") == nil and named(gui, "ResultChampionRight") == nil and named(gui, "ResultVipRing") == nil, tag .. ": no hero figures stand beside the end screen")
		local backdrop = localPlayer.PlayerGui:FindFirstChild("DoomBackdrop")
		local shade = backdrop and backdrop:FindFirstChild("ResultBackdrop")
		check(backdrop ~= nil and backdrop.Enabled == true and backdrop.IgnoreGuiInset == true and shade ~= nil and shade.Size.X.Scale == 1 and shade.Size.Y.Scale == 1 and shade.Size.X.Offset == 0 and shade.Size.Y.Offset == 0 and shade.BackgroundTransparency < 0.5,
			tag .. ": the end screen darkens the whole screen, top bar included")
		check(named(gui, "ResultVeil") ~= nil and named(gui, "ResultVeil").BackgroundTransparency == 1, tag .. ": the panel's own veil adds no second, partial shade")
		local again = named(gui, "ResultPlayAgain")
		local againRect = again and screenRect(again, gui, SCREEN)
		check(againRect ~= nil and againRect.y + againRect.h <= view().h and againRect.h >= 44, tag .. ": PLAY AGAIN sits beside the return button without scrolling")
		-- One quiet offer closes the results; it opens Roblox's own prompt only when pressed.
		local offer = named(gui, "ResultOfferBuy")
		check(offer ~= nil and named(gui, "ResultOfferName") ~= nil, tag .. ": the results end with one offer")
		local promptsBefore = #prompts
		if offer then offer.Activated:Fire(); flush() end
		check(#prompts == promptsBefore + 1 and string.find(prompts[#prompts] or "", "product:", 1, true) ~= nil, tag .. ": the offer opens Roblox's purchase prompt")
		if #prompts > promptsBefore then table.remove(prompts) end
		local invite = named(gui, "ResultInvite")
		local inviteRect = invite and screenRect(invite, gui, SCREEN)
		check(inviteRect ~= nil and againRect ~= nil and inviteRect.x >= againRect.x + againRect.w and inviteRect.y + inviteRect.h <= view().h, tag .. ": a friend invite sits beside PLAY AGAIN on the results screen")
		click("▶ Jogar de novo")
		check(asked("PlayAgain"), tag .. ": the results screen offers to play the same map again")
		click("Lobby")
		check(asked("ReturnLobby"), tag .. ": the results screen returns to base")
		-- The trip back hides behind the loading cover (owner, 17/10).
		local cover = playerGui:FindFirstChild("DoomReturnCover")
		check(cover ~= nil and cover:FindFirstChild("LoadingSplash", true) ~= nil, tag .. ": the way back to the lobby is covered by the loading screen")
		if cover then cover:Destroy() end
		-- On the battlefield the lobby is out of this client's workspace (owner,
		-- 17/10: maps stuttered behind it); the lobby snapshot brings it back.
		check(workspace:FindFirstChild("DoomLobby") == nil, tag .. ": the lobby is not drawn behind the battlefield")
		push(lobbySnapshot(profile))
		check(workspace:FindFirstChild("DoomLobby") ~= nil, tag .. ": back home the lobby is drawn again at once")
	end)

	step("switching to English re-renders in English", function()
		local english = veteranProfile()
		english.settings.language = "en"
		push(lobbySnapshot(english))
		check(findButton(gui, "Settings") ~= nil, tag .. ": the HUD speaks English after the switch")
		local village=workspace:FindFirstChild("DoomLobby")
		local desk=village:FindFirstChild("Board_maps").PrimaryPart
		check(desk.Board.Title.Text=="MAPS" and desk.Board.Status.Text=="Choose your destination",
			tag..": service desk signage changes language")
		check(desk:FindFirstChildOfClass("ProximityPrompt").ObjectText=="MAPS",
			tag..": service prompt changes language")
		local summon=village.HeroesHQ:FindFirstChild("SummonSign")
		local title=summon:FindFirstChild("Title",true)
		check(title and title.Text=="SUMMONING",tag..": summoning sign changes language")
		check(village.Chest_rare.SummonHeader:FindFirstChild("Title",true).Text=="SUMMON HEROES" and village.Chest_base_epic.SummonHeader:FindFirstChild("Title",true).Text=="SUMMON BASES",tag..": both mounted summon headers change language")
		check(localPlayer.PlayerGui.PortalPicture_normal.MapTitle.Text==Catalog.Maps.manhattan.name.en,tag..": cloned map picture is localized")
		local status=village.Portal_normal.QueueSign2.QueueBoard.QueueStatus
		status:SetAttribute("LobbyTextPT","4/4 • LOTADO"); status:SetAttribute("LobbyTextEN","4/4 • FULL"); status.Text="4/4 • LOTADO"
		status:GetAttributeChangedSignal("LobbyTextEN"):Fire()
		status:GetPropertyChangedSignal("Text"):Fire()
		push(lobbySnapshot(english))
		check(status.Text=="4/4 • FULL",tag..": changing occupancy preserves the selected language")
		push(matchSnapshot(english, "Preparing"))
		check(findButton(gui, "Ready") ~= nil, tag .. ": the match HUD speaks English too")
	end)

	step("rotating the device re-lays the HUD out", function()
		local rotated = { w = SCREEN.h + 58 > SCREEN.w and SCREEN.h + 120 or math.max(640, SCREEN.h), h = math.max(302, SCREEN.w - 400) }
		SCREEN.w, SCREEN.h = rotated.w, rotated.h
		main.AbsoluteSize = Vector2.new(rotated.w, rotated.h)
		main:GetPropertyChangedSignal("AbsoluteSize"):Fire()
		flush()
		-- A phone on its side draws everything smaller (owner, 17/10); layouts are
		-- in the client's logical pixels, the real screen over that scale.
		local scale = (named(gui, "ScreenScale") or {}).Scale or 1
		if rotated.h < 520 and rotated.w >= 560 then check(scale < 1 and scale >= 0.85, tag .. ": a phone on its side draws the HUD smaller, got " .. scale) end
		local fresh = UILayout.matchLayout(math.floor(rotated.w / scale), math.floor(rotated.h / scale), { skills = 1, vip = true })
		check(frameAt(main, fresh.top) ~= nil, tag .. ": after a resize the top bar follows the new layout")
		local bad = offscreen(main, view())
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
			localPlayer:SetAttribute("DoomReview", "sheet"); flush()
			localPlayer:SetAttribute("DoomReview", "skillaim"); flush()
			check(named(gui,"CommanderSheet") == nil and named(workspace,"SkillRangePreview") ~= nil, tag .. ": aiming review closes the previous sheet and keeps its radius visible")
			check(not overlays:FindFirstChild("ChestReel") and not overlays:FindFirstChild("ChestReveal"), tag .. ": the next fixture clears the chest sequence")
			localPlayer:SetAttribute("DoomReview", "reel"); flush(); advance(1); flush()
			localPlayer:SetAttribute("DoomReview", "afk"); flush(); advance(5); flush()
			check(not overlays:FindFirstChild("ChestReel") and not overlays:FindFirstChild("ChestReveal"), tag .. ": an old reel never returns over the AFK fixture")
			check(not gui:FindFirstChild("ContextPanel", true), tag .. ": the AFK fixture clears the previous hero window")
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

local screenFilter = __SCREEN_FILTER__
for index, screen in ipairs({
	{ name = "android landscape", w = 640, h = 302 },
	{ name = "iphone landscape", w = 754, h = 311 },
	{ name = "laptop", w = 1280, h = 662 },
	{ name = "ipad", w = 1024, h = 710 },
	{ name = "desktop", w = 1920, h = 1022 },
	{ name = "phone portrait", w = 375, h = 609 },
}) do
	if screenFilter == 0 or screenFilter == index then
		print("--- " .. screen.name .. " ---")
		session(screen)
	end
end

print(string.format("%s client boot: %d checks, %d failures",
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error("client boot failed", 0) end
