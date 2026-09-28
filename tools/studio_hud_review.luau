-- Run through Studio --task RunScript on a DISPOSABLE local place copy only.
-- Installs a client-only visual fixture. No remote purchase, reward, profile,
-- placement or progression action is submitted during the review.
-- After Play, use the CLIENT command bar to revisit any stage:
-- game.Players.LocalPlayer:SetAttribute("DoomHudStage", "cards")
-- Optional: change DoomHudLanguage to "en" and revisit a stage.
-- Stages: lobby, modes, inventory, hero, talents, chests, premium, preparing,
-- wave, tower, cards, results. Additional manual stages: quests, leaderboard,
-- settings, defeat, finalboss, boarding. The automatic tour finishes on results.
local starters = game:GetService("StarterPlayer").StarterPlayerScripts
for _, child in ipairs(starters:GetChildren()) do
	if not child:IsA("LocalScript") then continue end
	local source = child.Source
	if not source:find("stateRemote.OnClientEvent:Connect(applyState)", 1, true) then continue end
	source = source:gsub("stateRemote%.OnClientEvent:Connect%(applyState%)", [[stateRemote.OnClientEvent:Connect(function(snapshot)
	if not player:GetAttribute("DoomHudReview") then applyState(snapshot) end
end)]], 1)
	-- Source assignments stop at 200,000 characters; the editor service does not.
	local reviewSource = source .. [==[

task.spawn(function()
	while not state or not state.profile do task.wait(0.2) end
	task.wait(2)
	player:SetAttribute("DoomHudReview", true)
	-- Optional editor attributes constrain only the review's GUI area. This
	-- exercises actual text rendering at phone sizes, not device performance.
	local reviewWidth, reviewHeight = workspace:GetAttribute("DoomHudWidth"), workspace:GetAttribute("DoomHudHeight")
	if type(reviewWidth)=="number" and type(reviewHeight)=="number" then
		main.Size=UDim2.fromOffset(reviewWidth,reviewHeight)
		overlays.Size=main.Size
	end
	local function clone(value)
		if type(value) ~= "table" then return value end
		local result = {}
		for key, entry in pairs(value) do result[key] = clone(entry) end
		return result
	end
	local fixtureProfile = clone(state.profile)
	fixtureProfile.gold, fixtureProfile.level, fixtureProfile.xp = 4250, 12, 4200
	fixtureProfile.loadout = {"ironman", "hawkeye", "spiderman", "hulk", "thor"}
	fixtureProfile.heroes, fixtureProfile.abilities = {}, {}
	fixtureProfile.bases={}; fixtureProfile.equippedBase="barracks"
	for _,id in ipairs(Catalog.BaseOrder) do fixtureProfile.bases[id]=true end
	for _, id in ipairs(Catalog.HeroOrder) do
		fixtureProfile.heroes[id] = {level = 10, xp = 1200}
		fixtureProfile.abilities[id] = 2
	end
	fixtureProfile.talentPoints, fixtureProfile.talents = 4, {}
	fixtureProfile.pity = {legendary = 4}
	fixtureProfile.tutorialComplete = true
	fixtureProfile.campaign = {manhattan = {normal = true, ranked = true}}
	fixtureProfile.settings = {language = "pt", lowFX = true, shake = false, music = false}
	fixtureProfile.passes = {}
	fixtureProfile.paidRandomRestricted = false
	local actors = {{userId = player.UserId, name = player.DisplayName, level = 12}}
	local reviewTowers = {
		{id = "review1", heroId = "ironman", ownerId = player.UserId, level = 2,
			position = Vector3.new(10, 0, 10), priority = "First", damage = 26,
			range = 28.8, rate = 1.2, upgradeCost = 350, invested = 475},
		{id = "review2", heroId = "hawkeye", ownerId = player.UserId, level = 4,
			position = Vector3.new(-20, 0, 5), priority = "Strongest", damage = 60,
			range = 40, rate = 0.7, upgradeCost = 630, invested = 1000},
	}
	-- Controller callbacks remain interactive, but all network intents are
	-- intercepted locally so testing buttons can never change the real account.
	request = function(action, payload, silent)
		print("DOOM_HUD_REVIEW_INTENT", action)
		if not silent then showToast("Prévia visual: nenhuma alteração foi salva.") end
		return {ok = false, message = "Visual review only"}
	end
	local function matchFixture(phase)
		return {
			phase = phase, role = "Standalone", profile = fixtureProfile, players = actors,
			match = {
				runId = "visual-review", mapId = "manhattan", modeId = "cards",
				wave = 20, totalWaves = 50, completedWaves = 19,
				baseHP = 86, maxBaseHP = 120, shield = 0, energy = 940, towerLimit = 16,
				prepRemaining = 12, enemies = phase == "Wave" and 28 or 0, elapsed = 960,
				goldEarned = 1250, xpEarned = 340, partySize = 1, skipVotes = 0,
				threats = {"runner", "flyer", "armored"}, towers = reviewTowers,
				ability = {id = Catalog.Heroes.ironman.ability, heroId = "ironman", rank = 2,
					target = "area", cooldown = 0, cooldownTotal = 60, radius = 20},
				cards = {"sharpen"}, cardOffers = {}, cardMode = true,
			},
		}
	end
	local function visibleText(item)
		if not (item:IsA("TextLabel") or item:IsA("TextButton")) or item.Text == "" then return false end
		-- Icon navigation retains accessible text on its parent button, but only
		-- the child label is painted. Do not report deliberately invisible text.
		if item.TextTransparency >= 1 and item.TextStrokeTransparency >= 1 then return false end
		if item.AbsoluteSize.X <= 0 or item.AbsoluteSize.Y <= 0 then return false end
		local top, bottom = item.AbsolutePosition.Y, item.AbsolutePosition.Y + item.AbsoluteSize.Y
		local left, right = item.AbsolutePosition.X, item.AbsolutePosition.X + item.AbsoluteSize.X
		local ancestor = item
		while ancestor and ancestor ~= gui do
			if ancestor:IsA("GuiObject") then
				if not ancestor.Visible then return false end
				if ancestor.ClipsDescendants and (bottom <= ancestor.AbsolutePosition.Y
					or top >= ancestor.AbsolutePosition.Y + ancestor.AbsoluteSize.Y
					or right <= ancestor.AbsolutePosition.X
					or left >= ancestor.AbsolutePosition.X + ancestor.AbsoluteSize.X) then return false end
			end
			ancestor = ancestor.Parent
		end
		return true
	end
	local function measure(stage)
		local overflow, visible = 0, 0
		for _, item in ipairs(gui:GetDescendants()) do
			if visibleText(item) then
				visible += 1
				if item.TextBounds.X > item.AbsoluteSize.X + 2 or item.TextBounds.Y > item.AbsoluteSize.Y + 2 or item.TextFits == false then
					overflow += 1
					print("DOOM_HUD_OVERFLOW", stage, item.Name, item.Text, item.TextBounds, item.AbsoluteSize)
				end
			end
		end
		print("DOOM_HUD_MEASURE", stage, "visible", visible, "overflow", overflow, "screen", main.AbsoluteSize)
	end
	local function showStage(stage)
		local w,h=workspace:GetAttribute("DoomHudWidth"),workspace:GetAttribute("DoomHudHeight")
		if type(w)=="number" and type(h)=="number" then main.Size=UDim2.fromOffset(w,h); overlays.Size=main.Size end
		language = player:GetAttribute("DoomHudLanguage") == "en" and "en" or "pt"
		fixtureProfile.settings.language = language
		if stage == "baseupgrade" or stage == "preparing" or stage == "wave" or stage == "tower" or stage == "cards" or stage == "finalboss" then
			state = matchFixture(stage == "preparing" and "Preparing" or "Wave")
			state.match.base={id="barracks",level=2,stats=Rules.BaseStats("barracks",2),wall=0}
			if stage ~= "preparing" then
				state.match.boss = {id = "lizard", name = {pt = "Lagarto infectado", en = "Infected Lizard"},
					hp = 1800, maxHP = 2453, phase = 2,
					hint = {pt = "Concentre os ataques para parar a regeneração!", en = "Focus your attacks to stop regeneration!"}}
			end
			if stage == "finalboss" then
				state.match.wave = 50
				state.match.boss.final = true
				state.match.boss.name = Catalog.Enemies.killmonger.name
				state.match.boss.hint = Catalog.Enemies.killmonger.hint
			end
			if stage == "cards" then state.match.cardOffers = {"sharpen", "quickDraw", "warChest"} end
			render()
			if stage == "tower" then selectTower("review2") end
			if stage == "baseupgrade" then openBaseUpgrade() end
		elseif stage == "results" or stage == "defeat" then
			state = {phase = "Results", role = "Standalone", profile = fixtureProfile, players = actors,
				results = {victory = stage == "results", waves = stage == "results" and 50 or 37, gold = 1825, xp = 840, startLevel = 10,
					mapId = "manhattan", modeId = "ranked", mastery = {ironman = 180, hawkeye = 90, spiderman = 80, thor = 65, hulk = 55}}}
			render()
		else
			state = {phase = "Lobby", role = "Standalone", profile = fixtureProfile, players = actors}
			if stage == "boarding" then
				state.elevator = {portalId = "normal", modeId = "normal", mapId = "gamma", max = 4, remaining = 99,
					host = true, maps = 5, riders = actors}
			end
			render()
			if stage == "boarding" then
				openContext("quests", {})
			elseif stage == "basechests" then
				openContext("chests",{chestId="base_cosmic"})
			elseif stage ~= "lobby" then
				openContext(stage, stage == "hero" and {heroId = "ironman"} or {})
			end
		end
		player:SetAttribute("DoomHudShownStage", stage)
		task.delay(0.8, function() if player:GetAttribute("DoomHudShownStage") == stage then measure(stage) end end)
	end
	player:GetAttributeChangedSignal("DoomHudStage"):Connect(function()
		local stage = player:GetAttribute("DoomHudStage")
		if type(stage) == "string" then showStage(stage) end
	end)
	for _, stage in ipairs({"lobby", "modes", "inventory", "hero", "talents", "chests", "basechests", "bases", "premium", "preparing", "wave", "tower", "cards", "results", "baseupgrade"}) do
		player:SetAttribute("DoomHudStage", stage)
		task.wait(1.8)
	end
	print("DOOM_HUD_REVIEW_READY")
end)
]==]
	game:GetService("ScriptEditorService"):UpdateSourceAsync(child, function() return reviewSource end)
	print("DOOM_HUD_REVIEW_INSTALLED", child:GetFullName())
end
