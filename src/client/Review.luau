-- Studio-only screen review. init.client requires this only when
-- RunService:IsStudio() is true, so a live server never runs it, and it edits
-- no script: tools/studio_review.py drives it from the Studio command bar
-- (client context) through attributes on the local player.
--
--   DoomReview = "<stage>"        show a fixture screen; nothing reaches the server
--   DoomReview = "live"           back to the real server state
--   DoomReviewSize = "667x375"    draw the HUD in a phone-sized area ("" = full)
--   DoomReviewLanguage = "en"     fixture language (default pt)
--   DoomReviewFocus = "tower"     camera on the first tower ("" = normal camera)
--   DoomReviewServer = "start manhattan normal" | "spawn lizard,zombie" |
--                      "crowd 120" | "endwave 10" | "finish true" | "panel chests"
--                                 a Studio-only server scene (real match)
--
-- After each change it prints DOOM_REVIEW_SHOWN <stage> visible <n> overflow
-- <n> (and one DOOM_REVIEW_OVERFLOW line per clipped text) to the Output log.
local Review = {}

Review.STAGES = {
	"lobby", "modes", "squad", "hero", "talents", "chests", "basechests", "bases", "premium",
	"quests", "leaderboard", "settings", "rewards", "guide", "boarding",
	"preparing", "wave", "tower", "cards", "finalboss", "baseupgrade", "results", "defeat",
	"reveal", "revealbase", "revealcommon",
}

local MATCH_STAGES = { preparing = true, wave = true, tower = true, cards = true, finalboss = true, baseupgrade = true }

local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, entry in pairs(value) do result[key] = clone(entry) end
	return result
end

-- api: everything the controller lends the review (see init.client).
function Review.start(api)
	local player, Catalog, Rules = api.player, api.Catalog, api.Rules
	local self = { held = nil, active = false }

	local function fixtureProfile()
		local base = api.getState() and api.getState().profile or {}
		local p = clone(base)
		p.gold, p.level, p.xp = 4250, 12, 4200
		p.loadout = {}
		for index = 1, 5 do p.loadout[index] = Catalog.HeroOrder[index] end
		p.heroes, p.abilities, p.bases = {}, {}, {}
		for _, id in ipairs(Catalog.HeroOrder) do
			p.heroes[id] = { level = 10, xp = 1200 }
			p.abilities[id] = 2
		end
		for _, id in ipairs(Catalog.BaseOrder) do p.bases[id] = true end
		p.equippedBase = Catalog.BaseOrder[1]
		p.talentPoints, p.talents = 4, {}
		p.pity = { legendary = 4 }
		p.tutorialComplete = true
		p.campaign = { [Catalog.MapOrder and Catalog.MapOrder[1] or "manhattan"] = { normal = true, ranked = true } }
		p.settings = { language = player:GetAttribute("DoomReviewLanguage") == "en" and "en" or "pt", lowFX = false, shake = false, music = false }
		p.passes = p.passes or {}
		p.paidRandomRestricted = false
		return p
	end

	local function actors()
		return { { userId = player.UserId, name = player.DisplayName, level = 12 } }
	end

	local function firstBoss()
		local mapId = Catalog.MapOrder and Catalog.MapOrder[1] or "manhattan"
		local map = Catalog.Maps[mapId]
		return mapId, (map and map.bossId) or Catalog.BossOrder[1]
	end

	local function matchFixture(p, stage)
		local mapId, bossId = firstBoss()
		local loadout = p.loadout
		local towers = {
			{ id = "review1", heroId = loadout[1], ownerId = player.UserId, level = 2, position = Vector3.new(10, 0, 10),
				priority = "First", damage = 26, range = 28.8, rate = 1.2, upgradeCost = 350, invested = 475,
				base = { damage = 26, range = 28.8, rate = 1.2 }, next = { damage = 37.7, range = 30.6, rate = 1.25 } },
			{ id = "review2", heroId = loadout[2], ownerId = player.UserId, level = 4, position = Vector3.new(-20, 0, 5),
				priority = "Strongest", damage = 60, range = 40, rate = 0.7, upgradeCost = 630, invested = 1000,
				base = { damage = 60, range = 40, rate = 0.7 }, branches = { { damage = 96, range = 42, rate = 0.75 }, { damage = 81, range = 50, rate = 0.9 } } },
		}
		local heroAbility = Catalog.Heroes[loadout[1]] and Catalog.Heroes[loadout[1]].ability
		local match = {
			runId = "studio-review", mapId = mapId, modeId = stage == "cards" and "cards" or "normal",
			wave = 20, totalWaves = 50, completedWaves = 19, baseHP = 86, maxBaseHP = 120, shield = 0,
			cash = 940, towerLimit = 16, prepRemaining = 12, enemies = stage == "preparing" and 0 or 28,
			elapsed = 960, goldEarned = 1250, xpEarned = 340, partySize = 1, skipVotes = 0,
			threats = { "runner", "flyer", "armored" }, towers = towers,
			ability = heroAbility and { id = heroAbility, heroId = loadout[1], rank = 2, target = "area", cooldown = 0, cooldownTotal = 60, radius = 20 } or nil,
			cards = { "sharpen" }, cardOffers = stage == "cards" and { "sharpen", "quickDraw", "warChest" } or {}, cardMode = stage == "cards",
			base = { id = p.equippedBase, level = 2, stats = Rules.BaseStats(p.equippedBase, 2), wall = 0 },
		}
		if stage ~= "preparing" then
			local boss = Catalog.Enemies[bossId]
			match.boss = { id = bossId, name = boss.name, hp = 1800, maxHP = 2453, phase = 2, hint = boss.hint }
		end
		if stage == "finalboss" then
			local finalId = Catalog.BossOrder[#Catalog.BossOrder]
			match.wave = 50
			match.boss = { id = finalId, name = Catalog.Enemies[finalId].name, hp = 2100, maxHP = 2818, phase = 3, hint = Catalog.Enemies[finalId].hint, final = true }
		end
		return { phase = stage == "preparing" and "Preparing" or "Wave", role = "Standalone", profile = p, players = actors(), match = match }
	end

	local function visibleText(item)
		if not (item:IsA("TextLabel") or item:IsA("TextButton")) or item.Text == "" then return false end
		if (item.TextTransparency or 0) >= 1 and (item.TextStrokeTransparency or 1) >= 1 then return false end
		if not item.AbsoluteSize or item.AbsoluteSize.X <= 0 or item.AbsoluteSize.Y <= 0 then return false end
		local top, bottom = item.AbsolutePosition.Y, item.AbsolutePosition.Y + item.AbsoluteSize.Y
		local left, right = item.AbsolutePosition.X, item.AbsolutePosition.X + item.AbsoluteSize.X
		local ancestor = item
		while ancestor and ancestor ~= api.gui do
			if ancestor:IsA("GuiObject") then
				if not ancestor.Visible then return false end
				if ancestor.ClipsDescendants and (bottom <= ancestor.AbsolutePosition.Y or top >= ancestor.AbsolutePosition.Y + ancestor.AbsoluteSize.Y
					or right <= ancestor.AbsolutePosition.X or left >= ancestor.AbsolutePosition.X + ancestor.AbsoluteSize.X) then return false end
			end
			ancestor = ancestor.Parent
		end
		return true
	end

	local function measure(stage)
		local overflow, visible = 0, 0
		for _, item in ipairs(api.gui:GetDescendants()) do
			if visibleText(item) then
				visible += 1
				local bounds = item.TextBounds or Vector2.new(0, 0)
				if bounds.X > item.AbsoluteSize.X + 2 or bounds.Y > item.AbsoluteSize.Y + 2 or item.TextFits == false then
					overflow += 1
					print("DOOM_REVIEW_OVERFLOW", stage, item:GetFullName(), item.Text)
				end
			end
		end
		print("DOOM_REVIEW_SHOWN", stage, "visible", visible, "overflow", overflow, "screen", tostring(api.main.AbsoluteSize))
	end

	local function applySize()
		local size = player:GetAttribute("DoomReviewSize")
		local w, h
		if type(size) == "string" then w, h = size:match("^(%d+)x(%d+)$") end
		local dimension = w and UDim2.fromOffset(tonumber(w), tonumber(h)) or UDim2.fromScale(1, 1)
		api.main.Size, api.overlays.Size = dimension, dimension
	end

	-- Fixture screens never talk to the server: a pressed button only logs.
	local function intercept(on)
		api.setRequest(on and function(action)
			print("DOOM_REVIEW_INTENT", action)
			return { ok = false, message = "Studio review" }
		end or nil)
	end

	local function show(stage)
		applySize()
		if stage == "live" or stage == "" then
			self.active = false
			intercept(false)
			if self.held then api.applyState(self.held); self.held = nil end
			api.render()
			task.delay(0.8, measure, "live")
			return
		end
		self.active = true
		intercept(true)
		local p = fixtureProfile()
		api.setLanguage(p.settings.language)
		if MATCH_STAGES[stage] then
			api.setState(matchFixture(p, stage))
			api.render()
			if stage == "tower" then api.selectTower("review2") end
			if stage == "baseupgrade" then api.openBaseUpgrade() end
		elseif stage == "results" or stage == "defeat" then
			local mapId = firstBoss()
			local mastery = {}
			for index, id in ipairs(p.loadout) do mastery[id] = 200 - index * 30 end
			api.setState({ phase = "Results", role = "Standalone", profile = p, players = actors(),
				results = { victory = stage == "results", waves = stage == "results" and 50 or 37, gold = 1825, xp = 840, startLevel = 10,
					mapId = mapId, modeId = "ranked", mastery = mastery } })
			api.render()
		else
			local snapshot = { phase = "Lobby", role = "Standalone", profile = p, players = actors() }
			if stage == "boarding" then
				snapshot.elevator = { portalId = "normal", modeId = "normal", mapId = firstBoss(), max = 4, remaining = 99, host = true, maps = 5, riders = actors() }
			end
			api.setState(snapshot)
			api.render()
			if stage == "reveal" or stage == "revealbase" or stage == "revealcommon" then
				local legendary, common
				for _, id in ipairs(Catalog.HeroOrder) do
					local rarity = Catalog.Heroes[id].rarity
					if rarity == "legendary" and not legendary then legendary = id end
					if rarity == "common" and not common then common = id end
				end
				local result = stage == "revealbase" and { baseId = Catalog.BaseOrder[#Catalog.BaseOrder], rarity = "epic", duplicate = false, refundGold = 0 }
					or stage == "revealcommon" and { heroId = common, rarity = "common", duplicate = true, refundGold = 150, refundMastery = 60 }
					or { heroId = legendary, rarity = "legendary", duplicate = false, refundGold = 0, refundMastery = 0 }
				api.celebrate:Chest(result, stage == "revealbase" and "base_epic" or "legendary")
			elseif stage == "basechests" then
				api.openContext("chests", { chestId = "base_cosmic" })
			elseif stage ~= "lobby" and stage ~= "boarding" then
				api.openContext(stage, stage == "hero" and { heroId = p.loadout[1] } or {})
			end
		end
		task.delay(0.8, function()
			if player:GetAttribute("DoomReview") == stage then measure(stage) end
		end)
	end

	-- Real server snapshots wait while a fixture is on screen, then return.
	api.hold(function(snapshot)
		if self.active then self.held = snapshot else api.applyState(snapshot) end
	end)

	player:GetAttributeChangedSignal("DoomReview"):Connect(function()
		local stage = player:GetAttribute("DoomReview")
		if type(stage) ~= "string" then stage = "live" end
		local ok, problem = pcall(show, stage)
		if not ok then warn("DOOM_REVIEW_ERROR", stage, problem) end
	end)
	player:GetAttributeChangedSignal("DoomReviewSize"):Connect(applySize)
	-- DoomReviewFocus = "tower": frame the first tower from above, so a capture
	-- shows the fight; "" hands the camera back.
	player:GetAttributeChangedSignal("DoomReviewFocus"):Connect(function()
		local camera = workspace.CurrentCamera
		local focus = player:GetAttribute("DoomReviewFocus")
		local state = api.getState()
		local tower = state and state.match and state.match.towers and state.match.towers[1]
		if focus == "tower" and tower and typeof(tower.position) == "Vector3" then
			camera.CameraType = Enum.CameraType.Scriptable
			camera.CFrame = CFrame.lookAt(tower.position + Vector3.new(0, 30, 26), tower.position)
		else
			camera.CameraType = Enum.CameraType.Custom
		end
	end)
	player:GetAttributeChangedSignal("DoomReviewServer"):Connect(function()
		local line = player:GetAttribute("DoomReviewServer")
		if type(line) ~= "string" or line == "" then return end
		local command, rest = line:match("^(%S+)%s*(.*)$")
		local arg, modeId = rest:match("^(%S*)%s*(%S*)$")
		local value = arg
		if command == "spawn" then value = string.split(arg, ",")
		elseif command == "crowd" or command == "endwave" then value = tonumber(arg)
		elseif command == "finish" then value = arg == "true" end
		local result = api.serverRequest("StudioReview", { command = command, arg = value, modeId = modeId ~= "" and modeId or nil }, true)
		print("DOOM_REVIEW_SERVER", line, result and result.ok)
	end)
	print("DOOM_REVIEW_READY")
	return self
end

return Review
