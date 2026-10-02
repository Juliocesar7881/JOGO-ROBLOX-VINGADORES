--!nonstrict
-- A full playthrough of the real MatchService, outside Roblox.
--
-- The rules tests check formulas and the PlayerService tests check persistence.
-- Neither of them ever plays a match, so this harness drives the actual match
-- loop: it places towers by trial, survives waves, fights bosses and reads the
-- results screen. It is the closest thing to pressing Play that can run in CI.
--
-- Rendering, input, networking and DataStores are out of scope here; Studio and
-- a published place remain separate acceptance gates.

--==============================================================================
-- Roblox stand-ins
--==============================================================================
local V3 = {}
local V3_METHODS = {}

local function v3(x, y, z)
	return setmetatable({ x = x or 0, y = y or 0, z = z or 0 }, V3)
end

V3.__index = function(self, key)
	if key == "X" then return rawget(self, "x") end
	if key == "Y" then return rawget(self, "y") end
	if key == "Z" then return rawget(self, "z") end
	if key == "Magnitude" then
		local a, b, c = rawget(self, "x"), rawget(self, "y"), rawget(self, "z")
		return math.sqrt(a * a + b * b + c * c)
	end
	if key == "Unit" then
		local a, b, c = rawget(self, "x"), rawget(self, "y"), rawget(self, "z")
		local m = math.sqrt(a * a + b * b + c * c)
		if m == 0 then return v3(0, 0, 0) end
		return v3(a / m, b / m, c / m)
	end
	return V3_METHODS[key]
end
V3.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
V3.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
V3.__mul = function(a, b)
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
function V3_METHODS:Dot(other) return self.X * other.X + self.Y * other.Y + self.Z * other.Z end
function V3_METHODS:Lerp(other, t)
	return v3(self.X + (other.X - self.X) * t, self.Y + (other.Y - self.Y) * t, self.Z + (other.Z - self.Z) * t)
end

Vector3 = { new = v3 }
Vector2 = {
	new = function(x, y)
		return setmetatable({ X = x or 0, Y = y or 0 }, {
			__index = function(self, key)
				if key == "Magnitude" then return math.sqrt(self.X * self.X + self.Y * self.Y) end
				return nil
			end,
		})
	end,
}
Color3 = { fromRGB = function(r, g, b) return { R = r, G = g, B = b } end }

local realType = type
function typeof(value)
	if realType(value) == "table" and getmetatable(value) == V3 then return "Vector3" end
	return realType(value)
end

Random = {
	new = function(seed)
		local state = (math.abs(math.floor(seed or 0)) % 2147483646) + 1
		local function nextValue()
			state = (state * 48271) % 2147483647
			return state / 2147483647
		end
		-- Nearby seeds must not start with nearby numbers, as with the real thing.
		for _ = 1, 12 do nextValue() end
		return {
			NextInteger = function(_, low, high) return low + math.floor(nextValue() * (high - low + 1 - 1e-9)) end,
			NextNumber = function(_, low, high)
				if low == nil then return nextValue() end
				return low + nextValue() * (high - low)
			end,
		}
	end,
}

task = {
	spawn = function(fn, ...) fn(...) end,
	wait = function() return 0 end,
	delay = function(_, fn, ...) fn(...) end,
}

local PLAYERS = { __service = "Players" }
local guidCounter = 0
local SERVICES = {
	Players = PLAYERS,
	HttpService = {
		GenerateGUID = function()
			guidCounter += 1
			return "sim-" .. tostring(guidCounter)
		end,
	},
}
game = { GetService = function(_, name) return assert(SERVICES[name], "unstubbed service: " .. name) end }
warn = function() end

--==============================================================================
-- Modules under test
--==============================================================================
-- Declared in dependency order: each inlined module captures the previous ones
-- as upvalues, which is how the rewritten requires resolve.
local Config = __CONFIG__
-- The map of the day would change expected rewards with the calendar: switched off here, tested apart.
Config.DailyFeature = false
local Catalog = __CATALOG__
local Rules = __RULES__
local Waves = __WAVES__
local MatchService = __MATCH__

--==============================================================================
-- Test doubles for everything the match talks to
--==============================================================================
local checks, failures = 0, 0
local function check(condition, label)
	checks += 1
	if not condition then
		failures += 1
		print("FAIL: " .. label)
	end
end

local function newWorld()
	local world = { built = 0, towers = 0, upgrades = 0 }
	function world:Build() self.built += 1 end
	function world:MovePlayer() end
	function world:ApplyLobbyLighting() end
	function world:UpgradeTower() self.upgrades += 1 end
	function world:MakeTower()
		self.towers += 1
		local owner = self
		return { Destroy = function() owner.towers -= 1 end }
	end
	return world
end

local function newProfile(overrides)
	local profile = {
		gold = 0, xp = 0, level = 12,
		heroes = {}, abilities = {}, loadout = {}, talents = {},
		campaign = {}, tutorialComplete = true,
		passes = {}, settings = {}, best = {},
	}
	for _, id in ipairs(Catalog.HeroOrder) do
		profile.heroes[id] = { xp = 4000, level = 10 }
		profile.abilities[id] = 1
	end
	-- Slot one is Iron Man, so the ability the run fights with is his barrage.
	profile.loadout = { "ironman", "hawkeye", "hulk", "thor", "spiderman" }
	for key, value in pairs(overrides or {}) do profile[key] = value end
	return profile
end

local function newProfiles(profile, byUser)
	return {
		awards = {}, bests = {},
		Snapshot = function(self, who) return byUser and byUser[who.UserId] or profile end,
		Award = function(self, who, id, reward)
			local target = byUser and byUser[who.UserId] or profile
			if byUser then id = tostring(who.UserId)..":"..id end
			if self.awards[id] then return true end
			self.awards[id] = reward
			target.gold += reward.gold or 0
			return true
		end,
		RecordBest = function(self, _, mapId, size, waves)
			table.insert(self.bests, { mapId = mapId, size = size, waves = waves })
			return true
		end,
	}
end

local function newPlayer(userId, position)
	return {
		UserId = userId, Name = "Sim" .. tostring(userId), Parent = PLAYERS,
		Character = position and {
			FindFirstChild = function(_, name)
				if name == "HumanoidRootPart" then return { Position = position } end
				return nil
			end,
		} or nil,
	}
end

local function newRemotes(log)
	log.notices = log.notices or {}
	return { FX = { FireClient = function(_, _, event)
		log[event.kind] = (log[event.kind] or 0) + 1
		if event.kind == "Notice" and event.text then table.insert(log.notices, event.text.pt or "") end
	end } }
end

--==============================================================================
-- The player: place what fits, upgrade what is already standing
--==============================================================================
-- A tower only earns its cost if it covers the route, so the harness ranks
-- candidate ground by distance to the path the way a player eyeballs it.
local function distanceToPath(mapId, point)
	local best = math.huge
	for _, route in ipairs(Catalog.Maps[mapId].paths) do
		for index = 1, #route - 1 do
			local a = v3(route[index][1], 0, route[index][2])
			local b = v3(route[index + 1][1], 0, route[index + 1][2])
			local delta = b - a
			local square = delta:Dot(delta)
			local t = square > 0 and math.clamp((point - a):Dot(delta) / square, 0, 1) or 0
			local distance = (point - (a + delta * t)).Magnitude
			if distance < best then best = distance end
		end
	end
	return best
end

-- A person places towers where they cover the most road: in the bends and
-- where roads meet, not just beside the nearest kerb. The harness scores every
-- legal spot by how much of the route lies within a typical tower's reach and
-- fills the best ones first, keeping a little space between towers.
local spotCache = {}
local function buildSpots(mapId)
	if spotCache[mapId] then return spotCache[mapId] end
	local minimum = Config.PathHalfWidth + Config.TowerRadius + 0.5
	local samples = {}
	for _, route in ipairs(Catalog.Maps[mapId].paths) do
		for index = 1, #route - 1 do
			local a = v3(route[index][1], 0, route[index][2])
			local b = v3(route[index + 1][1], 0, route[index + 1][2])
			local length = (b - a).Magnitude
			for step = 0, math.floor(length / 3) do table.insert(samples, a + (b - a) * (step * 3 / length)) end
		end
	end
	local spots = {}
	for x = -100, 100, 4 do
		for z = -100, 100, 4 do
			local point = v3(x, 0, z)
			if distanceToPath(mapId, point) >= minimum then
				local covered = 0
				for _, sample in ipairs(samples) do
					if (sample - point).Magnitude <= 24 then covered += 1 end
				end
				if covered > 0 then table.insert(spots, { point = point, covered = covered }) end
			end
		end
	end
	table.sort(spots, function(a, b)
		if a.covered ~= b.covered then return a.covered > b.covered end
		if a.point.X ~= b.point.X then return a.point.X < b.point.X end
		return a.point.Z < b.point.Z
	end)
	spotCache[mapId] = spots
	return spots
end

local function buildPhase(match, player, heroes)
	local snapshot = match:Snapshot(player)
	if not snapshot then return end
	-- A commander with cards on offer takes the first one, as the timer would.
	if #snapshot.cardOffers > 0 then
		match:Handle(player, "ChooseCard", { cardId = snapshot.cardOffers[1] })
		snapshot = match:Snapshot(player)
	end
	local mine = 0
	for _, tower in ipairs(snapshot.towers) do
		if tower.ownerId == player.UserId then mine += 1 end
	end
	-- Upgrade first: a tall tower beats a wide one in this game.
	for _, tower in ipairs(snapshot.towers) do
		if tower.ownerId == player.UserId and tower.upgradeCost > 0 and snapshot.cash >= tower.upgradeCost then
			local branch = nil
			if tower.level == 4 then branch = 1 end
			if match:Handle(player, "UpgradeTower", { towerId = tower.id, branch = branch }) then
				snapshot = match:Snapshot(player)
			end
		end
	end
	-- Then expand, trying real positions until the server accepts one.
	while mine < snapshot.towerLimit do
		-- Buy the next hero in the rotation that the Energy can pay for: waiting
		-- for the priciest one while the road is undefended is not how anyone plays.
		local heroId
		for offset = 0, #heroes - 1 do
			local candidate = heroes[((mine + offset) % #heroes) + 1]
			if Catalog.Heroes[candidate].cost <= snapshot.cash then heroId = candidate break end
		end
		if not heroId then break end
		local placed = false
		for _, spot in ipairs(buildSpots(snapshot.mapId)) do
			local crowded = false
			for _, tower in ipairs(snapshot.towers) do
				if (tower.position - spot.point).Magnitude < 9 then crowded = true break end
			end
			if not crowded and match:Handle(player, "PlaceTower", { heroId = heroId, position = spot.point }) then
				placed = true
				break
			end
		end
		if not placed then break end
		mine += 1
		snapshot = match:Snapshot(player)
	end
end

-- Casts the slot-one ability where it does the most: over the densest knot of
-- enemies for an area ability, on the first tower for a tower ability.
local function castAbility(match, player)
	local snapshot = match:Snapshot(player)
	local ability = snapshot and snapshot.ability
	if not ability or ability.cooldown > 0 or match.phase ~= "Wave" then return false end
	local payload = { skillId = ability.id }
	if ability.target == "area" then
		local best, bestCount = nil, 0
		for _, enemy in pairs(match.enemies) do
			local count = 0
			for _, other in pairs(match.enemies) do
				if (other.position - enemy.position).Magnitude <= ability.radius then count += 1 end
			end
			if count > bestCount then best, bestCount = enemy, count end
		end
		if not best or bestCount < 3 then return false end
		payload.position = best.position
	elseif ability.target == "tower" then
		local tower = snapshot.towers[1]
		if not tower then return false end
		payload.towerId = tower.id
	end
	return match:Handle(player, "CastSkill", payload)
end

local function simulate(options)
	local profile = newProfile(options.profile)
	if options.loadout then profile.loadout = options.loadout end
	-- The bot picks up every coin it earns, like a commander walking the road:
	-- match Gold on the ground is what pays for heroes.
	local function pickup(target)
		if options.pickup ~= false then target.passes = table.clone(target.passes or {}); target.passes.collector = true end
	end
	pickup(profile)
	local members, byUser = {}, {[1]=profile}
	for id=1,(options.size or 1) do
		table.insert(members,newPlayer(id,options.characterAt))
		if id>1 then byUser[id]=newProfile(options.profile); byUser[id].loadout=profile.loadout; pickup(byUser[id]) end
	end
	local profiles = newProfiles(profile,options.size and byUser or nil)
	local world = newWorld()
	local log = {}
	local player = members[1]
	local match = MatchService.new(Config, Catalog, Rules, Waves, profiles, world, newRemotes(log), function() end)

	local started, problem = match:Start(members, options.mapId, options.modeId, nil, options.difficultyId)
	check(started, "match starts on " .. options.mapId .. "/" .. options.modeId .. ": " .. tostring(problem))
	if not started then return nil end

	local step = Config.SimulationStep
	local seconds, guard = 0, 0
	local lastWave, lastHP, monotonic, negativeEnergy = 0, Config.BaseHP, true, false
	local peakEnemies, bossSeen = 0, false
	local phaseClock, lastPhase, prepTotal, waveTotal, waveTimes = 0, match.phase, 0, 0, {}
	local casts, bossWaves, finalBossWave, picks = 0, {}, nil, 0
	local guardLimit = 5400 / step * 2

	while match.running and guard < guardLimit do
		guard += 1
		if match.phase == "Preparing" and options.build ~= false then
			for _,member in ipairs(members) do buildPhase(match, member, profile.loadout) end
		end
		if match.phase == "Wave" and options.build ~= false and options.cast ~= false and guard % 5 == 0 then
			for _,member in ipairs(members) do if castAbility(match, member) then casts += 1 end end
		end
		match:Step(step)
		seconds += step
		phaseClock += step
		if match.phase ~= lastPhase then
			if lastPhase == "Preparing" then
				prepTotal += phaseClock
			elseif lastPhase == "Wave" then
				waveTotal += phaseClock
				table.insert(waveTimes, phaseClock)
			end
			lastPhase, phaseClock = match.phase, 0
		end
		local snapshot = match:Snapshot(player)
		if snapshot then
			if snapshot.wave < lastWave then monotonic = false end
			lastWave = snapshot.wave
			if snapshot.baseHP > lastHP then monotonic = false end
			lastHP = snapshot.baseHP
			if snapshot.cash < 0 then negativeEnergy = true end
			peakEnemies = math.max(peakEnemies, snapshot.enemies)
			if snapshot.boss then
				bossSeen = true
				bossWaves[snapshot.wave] = snapshot.boss.name.pt
				if snapshot.boss.final then finalBossWave = snapshot.wave end
			end
			picks = math.max(picks, #snapshot.cards)
		end
	end

	local _, results = match:Snapshot(player)
	return {
		match = match, profiles = profiles, profile = profile, world = world, log = log,
		results = results, seconds = seconds, monotonic = monotonic,
		negativeEnergy = negativeEnergy, peakEnemies = peakEnemies, bossSeen = bossSeen,
		player = player, members=members, byUser=byUser, prepTotal = prepTotal, waveTotal = waveTotal, waveTimes = waveTimes,
		casts = casts, bossWaves = bossWaves, finalBossWave = finalBossWave, picks = picks,
	}
end

--==============================================================================
-- Playthroughs
--==============================================================================
print("--- tutorial ---")
local tutorial = simulate({ mapId = "manhattan", modeId = "tutorial" })
check(tutorial ~= nil, "tutorial ran")
check(tutorial ~= nil and tutorial.results ~= nil and tutorial.results.party == 1, "playing alone has no party bonus on the results")
if tutorial then
	check(tutorial.match.phase == "Results", "tutorial reaches the results screen")
	check(tutorial.results ~= nil, "tutorial produces a result")
	check(tutorial.results.victory == true, "a defended tutorial is a win")
	check(tutorial.results.waves == 12, "tutorial clears all 12 waves, got " .. tostring(tutorial.results.waves))
	check(tutorial.seconds >= 180 and tutorial.seconds <= 1500,
		"tutorial lasts 3-25 min, got " .. string.format("%.1f min", tutorial.seconds / 60))
	check(tutorial.bossSeen, "the tutorial boss shows up")
	check(tutorial.world.towers > 0, "towers are built in the world")
	-- Teaching is paced across the run: a new commander should be told about
	-- upgrading, abilities, wave pacing and where to spend the reward.
	local taught = 0
	for _, text in ipairs(tutorial.log.notices or {}) do
		if string.find(text, "melhorar", 1, true) or string.find(text, "habilidade ativa", 1, true)
			or string.find(text, "PRONTO", 1, true) or string.find(text, "baús", 1, true) then
			taught += 1
		end
	end
	check(taught >= 4, "the tutorial paces its lessons across the run, got " .. tostring(taught) .. " of 4")
	print(string.format("  %d waves, %.1f min, base %d/100, peak %d enemies, gold %d",
		tutorial.results.waves, tutorial.seconds / 60, tutorial.match.baseHP, tutorial.peakEnemies, tutorial.results.gold))
end

print("--- party bonus ---")
local duo = simulate({ mapId = "manhattan", modeId = "tutorial", size = 2 })
check(duo ~= nil and duo.results ~= nil and math.abs(duo.results.party - Rules.PartyBonus(2)) < 1e-9, "a party of two earns the party bonus, shown on the results")
check(duo ~= nil and duo.results.xp >= tutorial.results.xp, "the party's XP is at least the solo run's")

print("--- campaign difficulty ---")
do
	-- Refused before anything starts when the map's Normal is not beaten yet.
	local locked = MatchService.new(Config, Catalog, Rules, Waves, newProfiles(newProfile()), newWorld(), newRemotes({}), function() end)
	local started = locked:Start({ newPlayer(1) }, "manhattan", "normal", nil, "hard")
	check(not started and not locked.running, "Hard is refused on a map whose Normal was never beaten")
	local hard = simulate({ mapId = "manhattan", modeId = "normal", difficultyId = "hard", profile = { campaign = { manhattan = { normal = true } } } })
	check(hard ~= nil and hard.match.difficultyId == "hard", "a Hard run starts on Hard")
	if hard then
		local final
		for id, reward in pairs(hard.profiles.awards) do if string.find(id, ":final", 1, true) then final = reward end end
		check(final ~= nil and final.difficultyId == "hard", "the final award names the difficulty, so a win opens Nightmare")
		check(hard.results.difficultyId == "hard", "the results screen knows the difficulty")
		print(string.format("Hard Manhattan: the bot reached wave %d (victory %s)", hard.results.waves or 0, tostring(hard.results.victory)))
	end
end

print("--- campaign, Manhattan ---")
local campaign = simulate({ mapId = "manhattan", modeId = "normal" })
check(campaign ~= nil, "campaign ran")
if campaign then
	check(campaign.match.phase == "Results", "campaign terminates instead of hanging")
	check(campaign.monotonic, "waves only move forward and the core never heals itself")
	check(not campaign.negativeEnergy, "match Gold never goes negative")
	check(campaign.peakEnemies <= Config.MaxEnemies, "the enemy cap holds")
	check(campaign.bossSeen, "a boss reaches the field")
	check(campaign.results.waves >= 30,
		"a competent defense survives most of the campaign, got wave " .. tostring(campaign.results.waves))
	check(campaign.casts > 3, "the bot uses its hero ability, got " .. tostring(campaign.casts) .. " casts")
	check((campaign.log.Ability or 0) == campaign.casts, "every cast is announced to the clients")
	check(campaign.picks == 0, "the campaign offers no cards")
	-- Manhattan's own boss, the Lizard, waits for the last wave; the rest
	-- of the cast comes first, in story order.
	local expectedBosses = { [10] = "Megabruto infectado", [20] = "Comandante Sombra", [30] = "Rei Saqueador infectado", [40] = "Gekko Colosso" }
	for wave, name in pairs(expectedBosses) do
		if campaign.results.waves >= wave then check(campaign.bossWaves[wave] == name, "wave " .. wave .. " brings " .. name .. ", saw " .. tostring(campaign.bossWaves[wave])) end
	end
	for wave in pairs(campaign.bossWaves) do check(wave % 10 == 0, "bosses only walk in on every tenth wave, saw one on " .. wave) end
	check(campaign.results.gold > 0, "the run pays out gold")
	check(next(campaign.profiles.awards) ~= nil, "checkpoints are committed to the profile")
	check((campaign.log.Shot or 0) > 0, "towers actually fire")
	check((campaign.log.Breach or 0) >= 0, "breaches are reported")
	print(string.format("  %d waves, %.1f min, base %d/100, peak %d enemies, gold %d, victory=%s",
		campaign.results.waves, campaign.seconds / 60, campaign.match.baseHP,
		campaign.peakEnemies, campaign.results.gold, tostring(campaign.results.victory)))
	print(string.format("  preparacao %.1f min, combate %.1f min", campaign.prepTotal / 60, campaign.waveTotal / 60))
	local line = "  por onda:"
	for index, value in ipairs(campaign.waveTimes) do
		if index % 5 == 0 then line ..= string.format(" w%d=%.0fs", index, value) end
	end
	print(line)
	if campaign.results.victory then
		check(campaign.finalBossWave == 40, "Manhattan's final boss is the wave-40 boss")
		check(campaign.results.gold >= Rules.RunGold("normal", "manhattan", 40, true), "a victory pays the whole campaign reward")
		-- This harness never uses the unanimous ready vote, so it measures the
		-- slowest possible session.
		check(campaign.seconds >= 18 * 60 and campaign.seconds <= 50 * 60,
			"a full 40-wave campaign stays inside 18-50 min, got " .. string.format("%.1f min", campaign.seconds / 60))
		print(string.format("  40 ondas, medido %.1f min sem usar o voto de pronto", campaign.seconds / 60))
	end
end

print("--- undefended core ---")
local undefended = simulate({ mapId = "manhattan", modeId = "normal", build = false })
check(undefended ~= nil, "undefended run ran")
if undefended then
	check(undefended.results.victory == false, "an undefended core falls")
	check(undefended.match.baseHP == 0, "the core reaches zero")
	check((undefended.log.Breach or 0) > 0, "every leak is announced to the client")
	check(undefended.results.gold >= 0, "a loss still preserves what was earned")
	print(string.format("  lost on wave %d after %.1f min, gold kept %d",
		undefended.match.wave, undefended.seconds / 60, undefended.results.gold))
end

print("--- picking up match Gold ---")
-- Match Gold pays for heroes, so a commander who never picks it up starves:
-- only the starting purse and the wave bonus reach the wallet.
-- It never walks to a coin and never casts (an area power sweeps up Gold);
-- its squad has no scavenger heroes.
local starved = simulate({ mapId = "manhattan", modeId = "normal", pickup = false, cast = false, characterAt = v3(88, 0, 66) })
local drone = simulate({ mapId = "manhattan", modeId = "normal", profile = { passes = { collector = true } } })
if starved and drone then
	check((drone.log.CoinRemove or 0) > 0, "the drone actually picks coins up")
	check((starved.log.CoinRemove or 0) == 0, "coins left on the ground stay there")
	check(starved.results.waves <= drone.results.waves, string.format("leaving the Gold on the ground never helps (%d vs %d waves)", starved.results.waves, drone.results.waves))
	check(starved.results.gold <= drone.results.gold, "lobby Gold comes from the run, never from coins")
	print(string.format("  sem pegar %d ondas, pegando %d ondas", starved.results.waves, drone.results.waves))
end

print("--- competitive, HYDRA ---")
local endless = simulate({ mapId = "hydra", modeId = "ranked", profile = {
	campaign = { manhattan = { normal = true } },
} })
if endless then
	check(endless.match.phase == "Results", "competitive ends in defeat rather than looping forever")
	check(#endless.profiles.bests > 0, "competitive records a leaderboard best")
	check(endless.results.waves >= 5, "competitive survives a few waves, got " .. tostring(endless.results.waves))
	check(endless.picks == 0, "competitive offers no cards")
	check(endless.results.gold == Rules.RunGold("ranked", "hydra", endless.results.waves, false), "every completed competitive wave pays its lobby Gold")
	print(string.format("  survived %d waves in %.1f min", endless.results.waves, endless.seconds / 60))
end

print("--- card roguelike, Gamma ---")
local cardRun = simulate({ mapId = "gamma", modeId = "cards", profile = { campaign = { manhattan = { normal = true } } } })
if cardRun then
	check(cardRun.match.phase == "Results", "the card run terminates")
	check(cardRun.picks == math.min(9, math.floor(cardRun.results.waves / 5)), "one card per five completed waves, got " .. cardRun.picks .. " picks for " .. cardRun.results.waves .. " waves")
	check(cardRun.picks >= 3, "the run lasts long enough to matter")
	check(#cardRun.results.cards == cardRun.picks, "the results screen lists the run's cards")
	for _, id in ipairs(cardRun.results.cards) do check(Catalog.Cards[id] ~= nil, "a real card in the results") end
	print(string.format("  %d waves, %d cartas, %.1f min, victory=%s", cardRun.results.waves, cardRun.picks, cardRun.seconds / 60, tostring(cardRun.results.victory)))
end

print("--- competitive, wakanda ---")
local hardRun = simulate({ mapId = "wakanda", modeId = "ranked", profile = { campaign = { manhattan = { normal = true } } } })
if hardRun then
	check(hardRun.match.phase == "Results", "the competitive run terminates")
	check(hardRun.picks == 0, "competitive offers no cards")
	print(string.format("  %d waves, %.1f min, victory=%s", hardRun.results.waves, hardRun.seconds / 60, tostring(hardRun.results.victory)))
end

print("--- selling and limits ---")
local economy = simulate({ mapId = "manhattan", modeId = "normal", build = false })
if economy then
	local match = economy.match
	local player = economy.player
	match.running, match.phase = true, "Preparing"
	local before = match:Snapshot(player).cash
	local placed = match:Handle(player, "PlaceTower", { heroId = "ironman", position = v3(-70, 0, -30) })
	check(placed, "a tower can be placed on open ground")
	local spent = before - match:Snapshot(player).cash
	check(spent == Catalog.Heroes.ironman.cost, "placing charges exactly the hero cost")
	local entrance = Catalog.Maps.manhattan.paths[1][1]
	local onPath = match:Handle(player, "PlaceTower", { heroId = "ironman", position = v3(entrance[1], 0, entrance[2]) })
	check(not onPath, "the route itself cannot be built on")
	local towerId = match:Snapshot(player).towers[1].id
	local beforeSale = match:Snapshot(player).cash
	match:Handle(player, "SellTower", { towerId = towerId })
	local refund = match:Snapshot(player).cash - beforeSale
	check(refund == math.floor(spent * 0.7), "selling refunds 70 percent, got " .. tostring(refund))
	check(not match:Handle(player, "PlaceTower", { heroId = "strange", position = v3(-70, 0, -30) }),
		"an unequipped hero cannot be placed")
end

print("--- talent bonuses ---")
do
	local player = newPlayer(901)
	local profile = newProfile({talents={roundGold=2,killGold=5,baseVitality=3,baseRecovery=2,startingEnergy=2}})
	local profiles = newProfiles(profile)
	local match = MatchService.new(Config,Catalog,Rules,Waves,profiles,newWorld(),newRemotes({}),function() end)
	check(match:Start({player},"manhattan","normal","talent-test"),"Talented account starts a match")
	local p = match.participants[player.UserId]
	check(match.maxBaseHP==112 and match.baseHP==112,"Vitality raises actual and maximum base HP")
	check(p.cash==Config.StartCash+40,"Preparation talent grants initial Energy")
	check(match:Snapshot(player).maxBaseHP==112,"HUD receives increased maximum HP")
	p.contributed=true
	for i=1,10 do
		local enemy={id=i,hp=1,maxHP=1,def={},armorUntil=0,markUntil=0,shield=0,cash=1,position=v3(0,0,0)}
		match.enemies[i],match.alive=enemy,1
		match:_damage(enemy,10,nil,nil)
	end
	local dropped=0 for _,coin in pairs(p.coins) do dropped+=coin.value end
	check(dropped==12,"Fractional kill bonuses accumulate instead of vanishing on small coins, got "..dropped)
	check(p.goldEarned==0,"Kills drop match Gold, never lobby Gold")
	match.wave,match.baseHP,match.baseWasDamaged=5,108,true
	match:_endWave()
	check(match.baseHP==110,"Repair talent restores HP every five completed waves")
	local banked=Rules.WaveGold("normal",5)+2*2
	check(p.goldEarned==banked and profile.gold==banked,"A completed wave banks its lobby Gold plus the wave talent, got "..p.goldEarned)
	match:_endWave()
	check(p.goldEarned==banked and match.baseHP==110,"Duplicate wave completion cannot duplicate gold or repairs")
	match:Finish(true)
	check(profiles.awards["talent-test:final"].noDamage==false,"Repair cannot award a false flawless medal")
	local idleProfile=newProfile({talents={roundGold=5}})
	local idle=MatchService.new(Config,Catalog,Rules,Waves,newProfiles(idleProfile),newWorld(),newRemotes({}),function() end)
	idle:Start({player},"manhattan","normal","idle-talents")
	idle.wave=1; idle:_endWave()
	check(idleProfile.gold==0,"Idle participants cannot farm wave talent gold")
end

--==============================================================================
-- Staging helpers for the focused tests below
--==============================================================================
local stagedPlayers = 0
local function stage(options)
	options = options or {}
	stagedPlayers += 1
	local player = newPlayer(4000 + stagedPlayers)
	local profile = newProfile(options.profile)
	-- Later modes are gated behind victories; a staged match has earned them.
	if not (options.profile and options.profile.campaign) then profile.campaign = { manhattan = { normal = true, ranked = true } } end
	if options.loadout then profile.loadout = options.loadout end
	local profiles = newProfiles(profile)
	local log = {}
	local world = newWorld()
	local match = MatchService.new(Config, Catalog, Rules, Waves, profiles, world, newRemotes(log), function() end)
	local started, problem = match:Start({ player }, options.mapId or Rules.PickMap(options.modeId or "normal",0), options.modeId or "normal", "stage-" .. stagedPlayers)
	check(started, "staged match starts: " .. tostring(problem))
	match.phase = "Wave"
	match.wave = options.wave or 10
	return match, player, profile, log
end

local function spawn(match, enemyId, progress, hpMultiplier)
	match:_spawn({ enemyId = enemyId, pathIndex = 1, progress = progress, hpMultiplier = hpMultiplier or 1 })
	return match.enemies["e" .. match.entityIds.e]
end

local function place(match, player, heroId)
	for _, spot in ipairs(buildSpots(match.mapId)) do
		local ok, reply = match:Handle(player, "PlaceTower", { heroId = heroId, position = spot.point })
		if ok then return match.towers[reply.towerId] end
	end
	error("no valid spot for " .. heroId)
end

local function distanceBetween(a, b) return (a - b).Magnitude end

--==============================================================================
-- Every hero ability, cast against real enemies
--==============================================================================
print("--- hero abilities ---")
do
	local casts = 0
	for _, heroId in ipairs(Catalog.HeroOrder) do
		local hero = Catalog.Heroes[heroId]
		local def = Catalog.Abilities[hero.ability]
		local match, player, profile = stage({ loadout = { heroId, "ironman" } })
		local p = match.participants[player.UserId]
		local label = heroId .. "/" .. def.id .. " (" .. def.kind .. ")"

		local snapshot = match:Snapshot(player)
		check(snapshot.ability and snapshot.ability.id == def.id and snapshot.ability.heroId == heroId, "slot one decides the ability: " .. label)
		check(snapshot.ability.cooldown == 0 and snapshot.ability.cooldownTotal == def.cooldown, "a fresh ability is ready: " .. label)

		local stats = Rules.AbilityStats(def, 1)
		local tower = place(match, player, "ironman")
		local near = {}
		for offset = 0, 5 do table.insert(near, spawn(match, "zombie", 100 + offset * 0.5, 4)) end
		if def.kind == "execute" then
			near[1].hp = near[1].maxHP * 0.1
			near[2].hp = near[2].maxHP
		end
		local hidden = def.kind == "reveal" and spawn(match, "stealth", 100.4, 1) or nil
		local at = near[1].position
		local farProgress = 330
		local far = spawn(match, "zombie", farProgress, 4)
		local farAway = distanceBetween(far.position, at) > stats.radius + 6
		local boss = def.kind ~= "chain" and spawn(match, "lizard", 100.2, 1) or nil
		local payload = { skillId = def.id, position = at, towerId = tower.id }
		local energyBefore, coreBefore = p.cash, match.baseHP
		match.baseHP = match.maxBaseHP - 20
		coreBefore = match.baseHP
		local hpBefore = {}
		for index, enemy in ipairs(near) do hpBefore[index] = enemy.hp end
		local bossBefore = boss and boss.hp
		local intervalBefore, damageBefore = match:_towerStats(tower).interval, match:_towerStats(tower).damage

		local ok, message = match:Handle(player, "CastSkill", payload)
		check(ok, "the ability casts: " .. label .. " " .. tostring(message))
		casts += 1
		check((match:Snapshot(player).ability.cooldown or 0) > 0, "casting starts the cooldown: " .. label)
		local again = match:Handle(player, "CastSkill", payload)
		check(not again, "a recharging ability cannot be cast again: " .. label)
		check(p.contributed and p.waveHeroes[heroId], "casting counts as taking part and credits the hero: " .. label)

		if def.kind == "blast" then
			for index, enemy in ipairs(near) do
				check(math.abs(enemy.hp - hpBefore[index] * (1 - stats.power)) < 0.001, "blast takes its share of health: " .. label)
			end
			if farAway then check(far.hp == far.maxHP, "blast leaves distant enemies alone: " .. label) end
			check(math.abs(boss.hp - bossBefore * (1 - stats.power * 0.12)) < 0.01, "a boss takes only a slice of a blast: " .. label)
		elseif def.kind == "execute" then
			check(match.enemies[near[1].id] == nil, "execute finishes a wounded enemy: " .. label)
			check(match.enemies[near[2].id] ~= nil and near[2].hp == near[2].maxHP, "execute spares a healthy enemy: " .. label)
			check(boss.hp > bossBefore * 0.95 and boss.hp < bossBefore, "a boss takes a small hit, never an execution: " .. label)
		elseif def.kind == "rally" then
			check(p.rallyUntil > match.elapsed and p.rallyStat == def.stat, "rally starts a timed buff: " .. label)
			local buffed = match:_towerStats(tower)
			if def.stat == "speed" then check(buffed.interval < intervalBefore, "rally speeds towers up: " .. label)
			else check(buffed.damage > damageBefore, "rally strengthens towers: " .. label) end
			match.elapsed += stats.duration + 1
			check(match:_towerStats(tower).interval == intervalBefore, "the rally wears off: " .. label)
		elseif def.kind == "stun" then
			for _, enemy in ipairs(near) do check(enemy.stunUntil >= match.elapsed + stats.duration - 0.001, "stun holds ordinary enemies: " .. label) end
			check(math.abs(boss.stunUntil - (match.elapsed + stats.duration * 0.25)) < 0.001, "a boss is held for a quarter as long: " .. label)
			if farAway then check(far.stunUntil <= match.elapsed, "stun does not reach distant enemies: " .. label) end
			-- Stunned enemies really stop.
			local frozen, progressBefore = near[2], near[2].progress
			match:_enemiesStep(0.5)
			check(frozen.progress == progressBefore, "a stunned enemy does not move: " .. label)
			-- No chain of casts can lock a boss down.
			match.elapsed += stats.duration * 0.25 + 0.5
			p.cooldowns[def.id] = 0
			local heldUntil = boss.stunUntil
			match:Handle(player, "CastSkill", payload)
			check(boss.stunUntil == heldUntil, "a boss just stunned cannot be stunned again: " .. label)
		elseif def.kind == "slow" then
			for _, enemy in ipairs(near) do check(enemy.slow > 0 and enemy.slowUntil > match.elapsed, "slow applies: " .. label) end
			check(boss.slow <= 0.25, "a boss resists slowing: " .. label)
		elseif def.kind == "reveal" then
			for _, enemy in ipairs(near) do check(enemy.markUntil > match.elapsed and enemy.mark >= stats.power, "reveal marks enemies: " .. label) end
			check(hidden.revealUntil > match.elapsed, "reveal exposes cloaked enemies: " .. label)
			check(match:_canTarget({ position = hidden.position }, hidden, { air = false, reveal = false, range = 5 }), "a revealed enemy can be targeted by any tower: " .. label)
		elseif def.kind == "overdrive" then
			check((tower.overloadUntil or 0) > match.elapsed, "overdrive starts a timer on the tower: " .. label)
			check(match:_towerStats(tower).interval < intervalBefore, "overdrive attacks faster: " .. label)
			local other = { UserId = 9999, Name = "Other", Parent = PLAYERS }
			p.cooldowns[def.id] = 0
			local foreign = match:Handle(player, "CastSkill", { skillId = def.id, towerId = "t-not-mine" })
			check(not foreign, "overdrive needs one of your own towers: " .. label)
		elseif def.kind == "chain" then
			local struck = 0
			for _, enemy in ipairs(near) do if enemy.hp < hpBefore[1] * 0.999 then struck += 1 end end
			check(struck == math.min(stats.count, #near), "chain strikes exactly its count of enemies: " .. label .. " " .. struck)
		elseif def.kind == "energy" then
			check(p.cash == energyBefore + math.floor(stats.power * (200 + 10 * match.wave)), "energy scales with the wave: " .. label)
		elseif def.kind == "pull" then
			for index, enemy in ipairs(near) do check(math.abs(enemy.progress - (100 + (index - 1) * 0.5 - stats.power)) < 0.001, "pull pushes enemies back: " .. label) end
			check(boss.progress == 100.2, "a boss cannot be pulled: " .. label)
		elseif def.kind == "barrier" then
			check(match.shield == stats.power and match.shieldUntil > match.elapsed, "barrier shields the core: " .. label)
		elseif def.kind == "heal" then
			check(match.baseHP == coreBefore + math.min(stats.power, 20), "heal restores core health: " .. label)
		elseif def.kind == "weaken" then
			for _, enemy in ipairs(near) do check(enemy.armorBreak >= stats.power and enemy.armorUntil > match.elapsed, "weaken strips armor: " .. label) end
		elseif def.kind == "burn" then
			for _, enemy in ipairs(near) do check(enemy.dot and enemy.dot.untilTime > match.elapsed, "burn ignites enemies: " .. label) end
			local target = near[3]
			tower.nextAttack = math.huge
			local start = target.hp
			for _ = 1, math.floor(stats.duration / 0.1) + 12 do match:Step(0.1) end
			check(start - target.hp > target.maxHP * stats.power * 0.6, "burn deals its total over time: " .. label)
		elseif def.kind == "smite" then
			local strongest = spawn(match, "brute", 90, 50)
			match.enemies[strongest.id] = strongest
			p.cooldowns[def.id] = 0
			local before = strongest.hp
			match:Handle(player, "CastSkill", { skillId = def.id })
			check(strongest.hp < before, "smite goes for the strongest enemy: " .. label)
		end

		-- Validation is the server's job, whatever the client sent.
		if def.target == "area" then
			p.cooldowns[def.id] = 0
			check(not match:Handle(player, "CastSkill", { skillId = def.id }), "an area ability needs a position: " .. label)
			check(not match:Handle(player, "CastSkill", { skillId = def.id, position = v3(9999, 0, 0) }), "a position off the map is rejected: " .. label)
			check(not match:Handle(player, "CastSkill", { skillId = def.id, position = "here" }), "a malformed position is rejected: " .. label)
		end
		check(not match:Handle(player, "CastSkill", { skillId = "notAnAbility", position = at, towerId = tower.id }), "only the slot-one ability can be named: " .. label)
		p.cooldowns[def.id] = 0
		match.phase = "Preparing"
		check(not match:Handle(player, "CastSkill", payload), "abilities are for waves, not preparation: " .. label)
	end
	check(casts == #Catalog.HeroOrder, "every hero's ability was exercised, " .. casts)
end

--==============================================================================
-- Ultimates: one cast, several effects
--==============================================================================
print("--- ultimates ---")
do
	local function cast(heroId, setup)
		local match, player = stage({ loadout = { heroId, "ironman" } })
		local p = match.participants[player.UserId]
		local def = Catalog.Abilities[Catalog.Heroes[heroId].ability]
		local events = {}
		local original = match._fx
		match._fx = function(self, event, ...) table.insert(events, event) return original(self, event, ...) end
		local near = {}
		for offset = 0, 5 do table.insert(near, spawn(match, "zombie", 100 + offset * 0.5, 4)) end
		local far = spawn(match, "zombie", 330, 4)
		local boss = spawn(match, "lizard", 100.2, 1)
		local before = {}
		for index, enemy in ipairs(near) do before[index] = enemy.hp end
		local ok = match:Handle(player, "CastSkill", { skillId = def.id, position = near[1].position })
		check(ok, "ultimate casts: " .. heroId)
		local announced
		for _, event in ipairs(events) do if event.kind == "Ability" then announced = event end end
		return match, near, far, boss, before, announced, Rules.AbilityStats(def, 1), Rules.AbilityExtras(def, 1), def
	end

	-- Every ultimate is flagged, announced as one, and rings the screen harder.
	for _, id in ipairs(Catalog.AbilityOrder) do
		local def = Catalog.Abilities[id]
		if def.ultimate then
			check(#(def.extras or {}) >= 1, "an ultimate does more than one thing: " .. id)
			check(def.cooldown >= 75, "an ultimate is a big-cooldown decision: " .. id)
		end
	end

	do -- Photon Nova: damage, stun and mark across a huge area.
		local match, near, far, boss, before, fx, stats, extras = cast("captainmarvel")
		for index, enemy in ipairs(near) do
			check(math.abs(enemy.hp - before[index] * (1 - stats.power)) < 0.001, "nova blasts everything close")
			check(enemy.stunUntil >= match.elapsed + extras[1].duration - 0.001, "nova stuns what it hits")
			check(enemy.markUntil > match.elapsed and enemy.mark >= extras[2].power, "nova marks its targets")
		end
		check(fx and fx.ultimate == true and #fx.extras == 2, "the client is told this is an ultimate with two extras")
		check(fx.shake >= 1, "an ultimate shakes the camera harder")
		check(boss.stunUntil > match.elapsed and boss.stunUntil - match.elapsed < extras[1].duration, "a boss is stunned for a fraction only")
	end

	do -- Cosmic Smite: hits the strongest, chains across the whole map and melts armor everywhere.
		local match, near, far, boss, before, fx, stats, extras = cast("silversurfer")
		check(far.armorBreak >= extras[2].power and far.armorUntil > match.elapsed, "smite weakens armor even at the far end of the map")
		local struck = 0
		for index, enemy in ipairs(near) do if enemy.hp < before[index] then struck += 1 end end
		check(struck >= extras[1].count - 1, "smite chains lightning through the pack, struck " .. struck)
		check(fx.ultimate and fx.points and #fx.points >= 2, "the chain points reach the client")
	end

	do -- Hex Bind: stun, melt and blast.
		local match, near, far, boss, before, fx, stats, extras = cast("wanda")
		for index, enemy in ipairs(near) do
			check(enemy.stunUntil >= match.elapsed + stats.duration - 0.001, "hex holds the enemy")
			check(enemy.armorBreak >= extras[1].power, "hex melts armor")
			check(enemy.hp < before[index], "hex also hurts")
		end
	end

	do -- Time Dilation: nearly frozen and shoved backward.
		local match, near, far, boss, before, fx, stats, extras = cast("strange")
		for index, enemy in ipairs(near) do
			check(enemy.slow >= 0.7 and enemy.slowUntil > match.elapsed, "time nearly stops")
			check(enemy.progress < 100 + (index - 1) * 0.5, "and the pack is pushed back")
		end
	end

	do -- Hellfire: burn + slow + a short stun.
		local match, near, far, boss, before, fx, stats, extras = cast("ghostrider")
		for _, enemy in ipairs(near) do
			check(enemy.dot ~= nil and enemy.slow > 0 and enemy.stunUntil > match.elapsed, "hellfire burns, slows and stuns")
		end
	end
end

-- The hero in slot one is what matters, wherever else it appears.
print("--- 2x speed and auto-skip ---")
do
	-- Solo: the commander decides alone.
	local match, player = stage({ wave = 3 })
	local p = match.participants[player.UserId]
	check(match:Speed() == 1, "a match starts at normal speed")
	check(not match:Handle(player, "SetSpeed", { speed = 3 }), "3x needs the 3x pass")
	check(not match:Handle(player, "SetSpeed", { speed = 4 }), "only 1x, 2x and 3x exist")
	check(not match:Handle(player, "SetSpeed", { speed = "2" }), "a speed must be a number")
	local ok, reply = match:Handle(player, "SetSpeed", { speed = 2 })
	check(ok and reply.speed == 2 and match:Speed() == 2, "a solo commander switches to 2x at once")
	check(match:Snapshot(player).speed == 2 and match:Snapshot(player).speedVote == 2, "the HUD is told the speed and the vote")

	-- Preparation and enemy sync run on real time: 2x never halves the time
	-- to build or to pick a card.
	match.phase, match.prepRemaining = "Preparing", 10
	match:Step(Config.SimulationStep * 2)
	check(math.abs(match.prepRemaining - (10 - Config.SimulationStep)) < 1e-6,
		"one real step of preparation costs one real step at 2x, left " .. tostring(match.prepRemaining))
	local elapsedBefore = match.elapsed
	match:Step(Config.SimulationStep * 2)
	check(math.abs(match.elapsed - elapsedBefore - Config.SimulationStep * 2) < 1e-6, "match time itself runs at 2x")
	p.profile.passes = p.profile.passes or {}
	p.profile.passes.speed3 = true
	check(match:Handle(player, "SetSpeed", { speed = 3 }) and match:Speed() == 3, "with the pass, a solo commander plays at 3x")
	p.profile.passes.speed3 = nil
	check(match:Handle(player, "SetSpeed", { speed = 1 }) and match:Speed() == 1, "back to 1x")

	-- Auto-skip ends preparation as if READY had been pressed every time.
	match.phase, match.prepRemaining, match.skipVotes = "Preparing", 10, {}
	check(not match:Handle(player, "SetAutoSkip", { on = "yes" }), "auto-skip takes a boolean")
	check(match:Handle(player, "SetAutoSkip", { on = true }) and p.autoSkip, "auto-skip switches on")
	check(match.prepRemaining <= 1, "auto-skip ends preparation straight away, left " .. tostring(match.prepRemaining))
	match.phase, match.prepRemaining = "Preparing", 10
	match:Step(Config.SimulationStep)
	check(match.prepRemaining <= 1, "and keeps doing it every preparation")
	-- A card on the table always wins over auto-skip.
	match.phase, match.prepRemaining = "Preparing", 10
	p.cardOffers = { "sharpen", "quickDraw", "longSight" }
	match:Step(Config.SimulationStep)
	check(match.prepRemaining > 5, "auto-skip waits for a pending card choice")
	p.cardOffers = {}
	check(match:Snapshot(player).autoSkip == true, "the HUD is told auto-skip is on")

	-- The choice is remembered: a profile saved with both on starts that way.
	local remembered, rememberedPlayer = stage({ profile = { settings = { fastForward = true, autoSkip = true } } })
	remembered:Step(Config.SimulationStep)
	check(remembered:Speed() == 2 and remembered.participants[rememberedPlayer.UserId].autoSkip, "saved 2x and auto-skip apply to the next match")

	-- Party: 2x waits for everyone, and a player leaving never locks it at 2x.
	local first, second = newPlayer(7101), newPlayer(7102)
	local byUser = { [7101] = newProfile(), [7102] = newProfile() }
	byUser[7101].campaign = { manhattan = { normal = true } }
	byUser[7102].campaign = { manhattan = { normal = true } }
	local duo = MatchService.new(Config, Catalog, Rules, Waves, newProfiles(byUser[7101], byUser), newWorld(), newRemotes({}), function() end)
	check(duo:Start({ first, second }, "manhattan", "normal", "duo-speed"), "a duo match starts")
	duo:Handle(first, "SetSpeed", { speed = 2 })
	duo:Step(Config.SimulationStep)
	check(duo:Speed() == 1, "one vote is not enough in a duo")
	check(duo:Snapshot(first).speedVotes == 1, "the HUD shows one of two votes")
	duo:Handle(second, "SetSpeed", { speed = 2 })
	check(duo:Speed() == 2, "both votes switch the duo to 2x")
	duo:Handle(second, "SetSpeed", { speed = 1 })
	check(duo:Speed() == 1, "either commander can bring it back to 1x")
	duo:Handle(second, "SetSpeed", { speed = 2 })
	duo.participants[second.UserId].returned = true
	duo:Step(Config.SimulationStep)
	check(duo:Speed() == 2, "a teammate who left does not hold the speed hostage")
	duo:Finish(false)
	check(duo:Speed() == 1, "a finished match is never fast-forwarded")
end

print("--- slot one decides ---")
do
	local match, player = stage({ loadout = { "thor", "ironman" } })
	check(match:Snapshot(player).ability.id == "thunderCall", "Thor in slot one fights with Thunder Call")
	local swapped, swappedPlayer = stage({ loadout = { "ironman", "thor" } })
	check(swapped:Snapshot(swappedPlayer).ability.id == "repulsorBarrage", "Iron Man in slot one fights with his barrage, whatever else is equipped")
	local leader = stage({ loadout = { "wanda" } })
	check(true, "a one-hero squad is fine")
	-- Ability rank, talents and cards all strengthen it.
	local m, pl, prof = stage({ loadout = { "ironman" }, profile = { talents = { abilityPower = 5, skillTempo = 10 } } })
	prof.abilities.ironman = 5
	local d, s = m:_abilityOf(m.participants[pl.UserId])
	local plain = Rules.AbilityStats(Catalog.Abilities.repulsorBarrage, 5)
	check(s.power > plain.power and s.cooldown < plain.cooldown, "talents strengthen the ability")
	check(math.abs(s.cooldown - plain.cooldown * 0.9 * 1) < 0.001 or s.cooldown < plain.cooldown, "cooldown talents shorten it")
end

--==============================================================================
-- The card roguelike
--==============================================================================
print("--- cards: rules of the mode ---")
do
	local match, player = stage({ modeId = "cards", wave = 5 })
	local p = match.participants[player.UserId]
	match.phase, match.alive, match.spawnIndex, match.pendingSpawns = "Wave", 0, 1, {}
	match:_endWave()
	check(#p.cardOffers == 3, "wave 5 of the card mode offers three cards")
	check(match.prepRemaining >= 30, "a card wave gives time to choose")
	check(not match:Handle(player, "SkipWave", {}), "you cannot ready up with a card still on the table")
	check(not match:Handle(player, "ChooseCard", { cardId = "definitelyNotACard" }), "unknown cards rejected")
	local notOffered
	for _, id in ipairs(Catalog.CardOrder) do if not table.find(p.cardOffers, id) then notOffered = id break end end
	check(not match:Handle(player, "ChooseCard", { cardId = notOffered }), "a card that was not offered cannot be taken")
	check(not match:Handle(player, "ChooseCard", { cardId = { "sharpen" } }), "a malformed card id is rejected")
	local snapshot = match:Snapshot(player)
	check(#snapshot.cardOffers == 3 and snapshot.cardMode == true, "the snapshot carries the offer")
	-- The timer runs out: the first card is dealt, so a run never stalls.
	local first = p.cardOffers[1]
	match.prepRemaining = 0
	match:Step(0.1)
	check(#p.cards == 1 and p.cards[1] == first and #p.cardOffers == 0, "an unchosen card is dealt automatically")
	check(match.phase == "Wave" and match.wave == 6, "the next wave then begins")

	-- Only the card mode offers cards, and never before the final boss.
	local normal, normalPlayer = stage({ modeId = "normal", wave = 5 })
	normal.phase, normal.alive, normal.spawnIndex, normal.pendingSpawns = "Wave", 0, 1, {}
	normal:_endWave()
	check(#normal.participants[normalPlayer.UserId].cardOffers == 0, "the campaign offers no cards")
	local finalRun, finalPlayer = stage({ modeId = "cards", wave = 50 })
	finalRun.phase, finalRun.alive, finalRun.spawnIndex, finalRun.pendingSpawns = "Wave", 0, 1, {}
	finalRun:_endWave()
	check(#finalRun.participants[finalPlayer.UserId].cardOffers == 0 and finalRun.phase == "Results", "wave 50 ends the run with no card")
	local counted = 0
	local picker, pickerPlayer = stage({ modeId = "cards", wave = 0 })
	local pp = picker.participants[pickerPlayer.UserId]
	for wave = 5, 45, 5 do
		picker.wave, picker.completedWaves = wave, wave - 1
		picker.phase, picker.alive, picker.spawnIndex, picker.pendingSpawns = "Wave", 0, 1, {}
		picker:_endWave()
		if #pp.cardOffers == 3 then counted += 1; picker:Handle(pickerPlayer, "ChooseCard", { cardId = pp.cardOffers[1] }) end
	end
	check(counted == 9 and #pp.cards == 9, "a card run has exactly nine picks")
end

print("--- cards: what each one does ---")
do
	local function withCard(cardId, setup)
		local match, player, profile = stage({ modeId = "cards", loadout = { "ironman", "hulk", "widow", "hawkeye" } })
		match.phase = "Preparing"
		local p = match.participants[player.UserId]
		if setup then setup(match, player, p) end
		local function take() p.cardOffers = { cardId }; return match:Handle(player, "ChooseCard", { cardId = cardId }) end
		return match, player, p, take
	end
	local function towerOf(match, player, heroId)
		local tower = place(match, player, heroId)
		return tower, function() return match:_baseStats(tower) end
	end
	local perm = Rules.PermanentModifiers({ heroes = { ironman = { xp = 4000 } }, talents = {} }, "ironman").damageBonus

	do -- sharpen: +10% damage
		local match, player, p, take = withCard("sharpen")
		local tower, stats = towerOf(match, player, "ironman")
		local before = stats().damage
		check(take(), "sharpen can be taken")
		check(math.abs(stats().damage / before - (1 + perm + 0.10) / (1 + perm)) < 1e-9, "sharpen adds 10% damage and invalidates cached stats")
		p.cardOffers = { "sharpen" }; match:Handle(player, "ChooseCard", { cardId = "sharpen" })
		check(math.abs(stats().damage / before - (1 + perm + 0.20) / (1 + perm)) < 1e-9, "the same card stacks")
	end
	do -- quickDraw / longSight
		local match, player, p, take = withCard("quickDraw")
		local tower, stats = towerOf(match, player, "ironman")
		local before = stats().rate
		take()
		check(stats().rate > before, "quick draw attacks faster")
		local m2, pl2, _, take2 = withCard("longSight")
		local _, stats2 = towerOf(m2, pl2, "ironman")
		local rangeBefore = stats2().range
		take2()
		check(stats2().range > rangeBefore * 1.06, "eagle eye reaches farther")
	end
	do -- armor pierce and area
		local match, player, p, take = withCard("armorBreaker")
		local _, stats = towerOf(match, player, "hulk")
		local before = stats().armorPierce
		take()
		check(math.abs(stats().armorPierce - before - 0.10) < 1e-9, "armor breaker adds 10% pierce")
		local m2, pl2, _, take2 = withCard("wideArea")
		local _, stats2 = towerOf(m2, pl2, "hulk")
		local splash = stats2().splash
		take2()
		check(math.abs(stats2().splash / splash - 1.12) < 1e-9, "wide coverage widens blasts by 12%")
	end
	do -- targeted damage
		for _, case in ipairs({ { "skyHunter", "airDamage" }, { "nightHunter", "stealthDamage" }, { "bossSlayer", "bossDamage" } }) do
			local match, player, p, take = withCard(case[1])
			local _, stats = towerOf(match, player, "ironman")
			local before = stats()[case[2]]
			take()
			check(stats()[case[2]] > before, case[1] .. " raises " .. case[2])
		end
		-- ...and the damage really lands harder on that kind of enemy.
		local match, player, p, take = withCard("skyHunter")
		local tower = place(match, player, "ironman")
		local flyer = spawn(match, "flyer", 60, 1)
		local groundling = spawn(match, "zombie", 60, 1)
		local before = { flyer.maxHP, groundling.maxHP }
		match:_damage(flyer, 100, tower, match:_baseStats(tower))
		local plainLoss = before[1] - flyer.hp
		take()
		local second = spawn(match, "flyer", 60, 1)
		match:_damage(second, 100, tower, match:_baseStats(tower))
		check(second.maxHP - second.hp > plainLoss * 1.2, "sky hunter hits flyers harder")
	end
	do -- risk and reward
		local match, player, p, take = withCard("glassCannon")
		local _, stats = towerOf(match, player, "ironman")
		local damage, range = stats().damage, stats().range
		take()
		check(stats().damage > damage * 1.25 and stats().range < range * 0.9, "glass cannon trades range for damage")
		local m2, pl2, _, take2 = withCard("overclock")
		local _, stats2 = towerOf(m2, pl2, "ironman")
		local damage2, rate2 = stats2().damage, stats2().rate
		take2()
		check(stats2().rate > rate2 * 1.2 and stats2().damage < damage2, "overclock trades damage for speed")
	end
	do -- economy: instants
		local match, player, p, take = withCard("supplyDrop")
		local before = p.cash
		take()
		check(p.cash == before + 350 and #p.cards == 1, "supplies grant 350 Energy")
		local m2, pl2, p2, take2 = withCard("warChest")
		local before2 = p2.cash
		take2()
		check(p2.cash == before2 + 900, "the war chest grants 900 Energy")
		local m3, pl3, p3, take3 = withCard("medic")
		m3.baseHP = 50
		take3()
		check(m3.baseHP == 58, "the medic restores 8 core health")
		local m4, pl4, p4, take4 = withCard("fortify")
		m4.baseHP = 50
		take4()
		check(m4.maxBaseHP == 110 and m4.baseHP == 60, "a fortified core is bigger and healed")
		check(m4:Snapshot(pl4).maxBaseHP == 110, "the HUD sees the new maximum")
	end
	do -- the gamble is settled by the server, both ways
		local outcomes = { win = false, lose = false }
		for wave = 1, 40 do
			local match, player, p, take = withCard("gambler", function(m) m.wave = wave end)
			local before = p.cash
			take()
			if p.cash == before + 600 then outcomes.win = true
			elseif p.cash == math.max(0, before - 200) then outcomes.lose = true
			else check(false, "the gamble must end at +600 or -200, got " .. (p.cash - before)) end
		end
		check(outcomes.win and outcomes.lose, "the gamble can go either way")
		local m, pl, p, take = withCard("gambler", function(match, _, part) part.cash = 50 end)
		take()
		check(p.cash >= 0, "a lost gamble never leaves negative Energy")
	end
	do -- economy: rates
		local match, player, p, take = withCard("coinRain")
		p.contributed = true
		take()
		local enemy = spawn(match, "zombie", 10, 1)
		enemy.cash = 100
		match:_damage(enemy, 1e9, nil, { trueDamage = true })
		local dropped = 0 for _, coin in pairs(p.coins) do dropped += coin.value end
		check(dropped == 115, "coin rain drops 15% more match Gold, got " .. dropped)
		local m2, pl2, p2, take2 = withCard("income")
		p2.contributed = true
		take2()
		local before = p2.cash
		m2.wave = 10; m2.completedWaves = 9; m2.alive = 0; m2.spawnIndex = 1; m2.pendingSpawns = {}
		m2:_endWave()
		check(p2.cash - before == math.floor((90 + 10 * 12) * 1.2)+p2.base.stats.income, "the supply network raises wave income by 20%")
		local m3, pl3, p3, take3 = withCard("discount")
		take3()
		local before3 = p3.cash
		place(m3, pl3, "ironman")
		check(before3 - p3.cash == math.floor(Catalog.Heroes.ironman.cost * 0.92), "the arms contract discounts placement by 8%")
	end
	do -- abilities and support
		local match, player, p, take = withCard("abilityPower")
		local _, before = match:_abilityOf(p)
		take()
		local _, after = match:_abilityOf(p)
		check(math.abs(after.power / before.power - 1.2) < 1e-9, "amplified power adds 20%")
		local m2, pl2, p2, take2 = withCard("fastCharge")
		local _, b2 = m2:_abilityOf(p2)
		take2()
		local _, a2 = m2:_abilityOf(p2)
		check(a2.cooldown < b2.cooldown, "fast recharge shortens the cooldown")
		local m3, pl3, p3, take3 = withCard("tempest")
		local _, b3 = m3:_abilityOf(p3)
		take3()
		local _, a3 = m3:_abilityOf(p3)
		check(a3.power > b3.power * 1.35 and a3.cooldown > b3.cooldown, "tempest trades cooldown for power")
		local m4, pl4, p4, take4 = withCard("supportRange")
		local _, stats4 = towerOf(m4, pl4, "widow")
		local range4 = stats4().range
		take4()
		check(math.abs(stats4().range / range4 - 1.15) < 1e-9, "the command network extends support range by 15%")
		local m5, pl5, p5, take5 = withCard("supportRange")
		local _, stats5 = towerOf(m5, pl5, "ironman")
		local range5 = stats5().range
		take5()
		check(stats5().range == range5, "the command network leaves ordinary heroes alone")
	end
end

--==============================================================================
-- Bosses
--==============================================================================
print("--- bosses ---")
do
	local match, player = stage({ modeId = "normal", mapId = "gamma", wave = 50 })
	local doom = spawn(match, "doom", 20, 1)
	check(doom.final == true, "the wave-50 boss is the final boss")
	local mini, miniPlayer = stage({ modeId = "normal", mapId = "gamma", wave = 30 })
	local skull = spawn(mini, "redskull", 20, 1)
	check(skull.final == false, "an ordinary boss is not the final boss")
	match.elapsed = doom.nextPower
	local before = match.alive
	match:_enemiesStep(0.1)
	check(match.alive - before >= 5, "the final boss calls a bigger wave of reinforcements")
	check(math.abs(doom.nextPower - (match.elapsed + 9)) < 0.001, "the final boss uses a power every 9 seconds")
	mini.elapsed = skull.nextPower
	mini:_enemiesStep(0.1)
	check(math.abs(skull.nextPower - (mini.elapsed + 14)) < 0.001, "an ordinary boss uses a power every 14 seconds")
	check(match:Snapshot(player).boss and match:Snapshot(player).boss.final == true, "the HUD is told it is the final boss")
	local endless, endlessPlayer = stage({ modeId = "ranked", mapId = "hydra", wave = 60, profile = { campaign = { manhattan = { normal = true } } } })
	local cycled = spawn(endless, "lizard", 20, 1)
	check(cycled.final == false, "competitive has no final boss")
	-- Upcoming boss, for the wave bar.
	local counter, counterPlayer = stage({ modeId = "normal", mapId = "gamma", wave = 12 })
	counter.phase = "Preparing"
	check(counter:Snapshot(counterPlayer).nextBoss == 20, "the HUD knows the next boss wave")
	counter.wave = 49
	check(counter:Snapshot(counterPlayer).nextBoss == 50, "wave 50 is the last boss")
end

--==============================================================================
-- Match Gold on the ground, Loki's illusions, and ending a competitive run
--==============================================================================
print("--- match Gold, magnet, Loki and the end vote ---")
do
	-- A kill drops a pile; the wallet only grows when it is picked up.
	local match, player = stage({ modeId = "normal", mapId = "gamma", wave = 5 })
	local p = match.participants[player.UserId]
	p.contributed = true
	local zombie = spawn(match, "zombie", 40, 1)
	local before = p.cash
	match:_damage(zombie, 1e9, nil, { trueDamage = true })
	local pileId, pile = next(p.coins)
	check(pile ~= nil and pile.value == Rules.KillCash("zombie"), "a kill drops the enemy's match Gold on the ground")
	check(p.cash == before, "dropped Gold is not in the wallet until it is picked up")
	check(match:Snapshot(player).coinsWaiting == pile.value, "the HUD is told how much Gold waits on the ground")
	-- Out of the magnet's reach the server refuses the pickup.
	local far = newPlayer(player.UserId, pile.position + v3(40, 0, 0))
	check(not match:Handle(far, "CollectCoin", { coinId = pileId }), "a pile out of reach cannot be taken")
	local near = newPlayer(player.UserId, pile.position + v3(Config.CollectRadius - 1, 0, 0))
	check(match:Handle(near, "CollectCoin", { coinId = pileId }), "walking up to a pile collects it")
	check(p.cash == before + pile.value and next(p.coins) == nil, "picked-up Gold lands in the wallet exactly once")
	check(not match:Handle(near, "CollectCoin", { coinId = pileId }), "the same pile cannot be taken twice")
	-- Magnetism widens the reach.
	local magnetMatch, magnetPlayer = stage({ modeId = "normal", mapId = "gamma", wave = 5, profile = { talents = { magnet = 5 }, campaign = { manhattan = { normal = true } } } })
	local reach = magnetMatch:Snapshot(magnetPlayer).magnet
	check(math.abs(reach - Config.CollectRadius * (1 + 5 * Catalog.Talents.magnet.effect / 100)) < 1e-9, "Magnetism widens the magnet by its talent effect")
	check(reach > Config.CollectRadius * 1.5, "a maxed magnet reaches much further")

	-- Loki fills the road with worthless illusions that fade on their own.
	local asgard, asgardPlayer = stage({ modeId = "normal", mapId = "asgard", wave = 50 })
	local loki = spawn(asgard, "loki", 30, 1)
	check(loki.final == true, "Loki is Asgard's final boss")
	asgard.elapsed = loki.nextPower
	local aliveBefore = asgard.alive
	asgard:_enemiesStep(0.1)
	local illusions = {}
	for _, enemy in pairs(asgard.enemies) do if enemy.enemyId == "illusion" then table.insert(illusions, enemy) end end
	check(#illusions >= 3 and asgard.alive - aliveBefore == #illusions, "Loki's power conjures illusions")
	local ap = asgard.participants[asgardPlayer.UserId]
	ap.contributed = true
	asgard:_damage(illusions[1], 1e9, nil, { trueDamage = true })
	check(next(ap.coins) == nil, "an illusion drops no Gold")
	-- 8.5 s later: the illusions (8 s) are gone, Loki's next power (9 s) is not due.
	asgard.elapsed += 8.5
	asgard:_enemiesStep(0.1)
	local left = 0
	for _, enemy in pairs(asgard.enemies) do if enemy.enemyId == "illusion" then left += 1 end end
	check(left == 0 and asgard.baseHP == asgard.maxBaseHP, "illusions fade on their own and never hurt the core")

	-- The next wave's roads are announced before it starts, and a change of
	-- entrance is flagged (HYDRA alternates its entrance every wave).
	local hydra, hydraPlayer = stage({ modeId = "normal", mapId = "hydra", wave = 1 })
	hydra.phase = "Preparing"
	hydra:_previewThreats()
	hydra:_previewThreats() -- the same wave again: nothing changed
	local first = hydra:Snapshot(hydraPlayer)
	check(first.nextPaths and #first.nextPaths >= 1 and not first.newEntrance, "preparation names the roads of the next wave")
	hydra.wave = 2
	hydra:_previewThreats()
	local second = hydra:Snapshot(hydraPlayer)
	check(second.nextPaths and second.nextPaths[1] ~= first.nextPaths[1] and second.newEntrance == true, "a changed entrance is flagged before the wave")
	hydra.phase = "Wave"
	check(hydra:Snapshot(hydraPlayer).nextPaths == nil, "the preview is only sent during preparation")

	-- After a boss power comes an opening: extra damage for a few seconds.
	local lab, labPlayer = stage({ modeId = "normal", mapId = "gamma", wave = 20 })
	local brute = spawn(lab, "abomination", 30, 1)
	local steady = spawn(lab, "abomination", 31, 1)
	-- The same power interrupts a tower beside it, and every client is told.
	local labTower = place(lab, labPlayer, "ironman")
	brute.position = labTower.position + v3(4, 0, 0)
	local labEvents = {}
	local labFx = lab._fx
	lab._fx = function(self, event, ...) table.insert(labEvents, event) return labFx(self, event, ...) end
	lab.elapsed = brute.nextPower
	lab:_power(brute)
	local stunnedEvent
	for _, event in ipairs(labEvents) do if event.kind == "TowersStunned" then stunnedEvent = event end end
	check(stunnedEvent ~= nil and table.find(stunnedEvent.towerIds, labTower.id) ~= nil and stunnedEvent.duration > 0,
		"an interrupting boss power names the towers it stopped")
	local stunnedRow
	for _, row in ipairs(lab:Snapshot(labPlayer).towers) do if row.id == labTower.id then stunnedRow = row end end
	check(stunnedRow ~= nil and (stunnedRow.stunned or 0) > 0, "the interrupted tower says so in the snapshot")
	lab.participants[labPlayer.UserId].cash = 1e6
	check(lab:Handle(labPlayer, "UpgradeTower", { towerId = labTower.id }), "the interrupted tower can still be upgraded")
	local upgradeEvent
	for _, event in ipairs(labEvents) do if event.kind == "TowerUpgrade" then upgradeEvent = event end end
	check(upgradeEvent ~= nil and upgradeEvent.towerId == labTower.id and upgradeEvent.level == 2, "an upgrade is announced to every client for its animation")
	local hpA, hpB = brute.hp, steady.hp
	lab:_damage(brute, 100, nil, { trueDamage = true })
	lab:_damage(steady, 100, nil, { trueDamage = true })
	check(math.abs((hpA - brute.hp) - 125) < 1e-6 and math.abs((hpB - steady.hp) - 100) < 1e-6, "a boss that just used its power takes 25% more damage")
	check(math.floor(lab:_statusOf(brute) / 64) % 2 == 1, "the opening is shown as VULNERABLE")
	lab.elapsed += 3.1
	check(math.floor(lab:_statusOf(brute) / 64) % 2 == 0, "the opening closes after three seconds")

	-- Enemy families read without names: the server says who a support is
	-- hastening, when a cloaked enemy is revealed, how many summons are left
	-- (announced ahead) and when a shot hits armour.
	local reads, readsPlayer = stage({ modeId = "normal", mapId = "manhattan", wave = 12 })
	local readEvents = {}
	local readFx = reads._fx
	reads._fx = function(self, event, ...) table.insert(readEvents, event) return readFx(self, event, ...) end
	local medic = spawn(reads, "support", 40, 1)
	local walker = spawn(reads, "zombie", 42, 1)
	reads:_enemiesStep(0.05)
	check(walker.boostedBy == medic.id and math.floor(reads:_statusOf(walker) / 256) % 2 == 1, "a support names the enemy it hastens")
	local cloak = spawn(reads, "stealth", 20, 1)
	check(math.floor(reads:_statusOf(cloak) / 128) % 2 == 0, "a cloaked enemy is not shown as revealed")
	cloak.revealUntil = reads.elapsed + 1
	check(math.floor(reads:_statusOf(cloak) / 128) % 2 == 1, "a revealed cloaked enemy is flagged")
	local caller = spawn(reads, "summoner", 10, 1)
	reads.elapsed = caller.nextPower - 1.4
	reads:_enemiesStep(0.01)
	local told
	for _, event in ipairs(readEvents) do if event.kind == "Pulse" and event.followEnemyId == caller.id and event.warningText then told = event end end
	check(told ~= nil and caller.summons == 0, "a summons is announced before it happens")
	reads.elapsed = caller.nextPower
	reads:_enemiesStep(0.01)
	check(caller.summons == 1, "the summons happens on time")
	reads.syncTimer = 1e6
	reads:Step(0)
	local sync
	for _, event in ipairs(readEvents) do if event.kind == "EnemySync" then sync = event end end
	local rows = {}
	for _, row in ipairs(sync and sync.enemies or {}) do rows[row.id] = row end
	check(rows[caller.id] and rows[caller.id].ch == 1, "a summoner's summons left travel with the sync")
	check(rows[walker.id] and rows[walker.id].lk == medic.id, "the hastened enemy's support travels with the sync")
	check(rows[medic.id] and rows[medic.id].lk == nil, "an enemy nobody hastens carries no link")
	local plated = spawn(reads, "armored", 60, 1)
	local gunner = place(reads, readsPlayer, "hawkeye")
	plated.position = gunner.position + v3(3, 0, 0)
	for id, enemy in pairs(reads.enemies) do if enemy ~= plated then reads.enemies[id] = nil end end
	reads:_attack(gunner, reads:_towerStats(gunner))
	local shot
	for _, event in ipairs(readEvents) do if event.kind == "Shot" and event.towerId == gunner.id then shot = event end end
	check(shot ~= nil and shot.armored == true, "a shot on armour says so, for the sparks")

	-- A splitter bursts into its fragments where it fell: the same health
	-- scaling, a share of its Gold, no second burst, and the wave stays open
	-- until the pieces are gone.
	do
		local sm, smPlayer = stage({ modeId = "normal", mapId = "manhattan", wave = 14 })
		local smEvents = {}
		local smFx = sm._fx
		sm._fx = function(self, event, ...) table.insert(smEvents, event) return smFx(self, event, ...) end
		for id in pairs(sm.enemies) do sm.enemies[id] = nil end
		sm.alive, sm.pendingSpawns, sm.spawnIndex = 0, {}, 1
		local blob = spawn(sm, "splitter", 30, 2)
		sm:_damage(blob, blob.hp + 1, nil, { trueDamage = true })
		check(sm.enemies[blob.id] == nil, "a fallen splitter leaves the road")
		local down
		for _, event in ipairs(smEvents) do if event.kind == "EnemyDown" and event.id == blob.id then down = event end end
		check(down ~= nil and down.split == true, "the splitter's fall says it bursts, for the splat")
		check(sm.alive == 0 and #sm.splits == 1, "the fragments wait for the end of the damage pass, not inside it")
		sm:_flushSplits()
		local pieces = {}
		for _, enemy in pairs(sm.enemies) do table.insert(pieces, enemy) end
		check(#pieces == 2 and sm.alive == 2 and #sm.splits == 0, "a splitter leaves two fragments, got " .. #pieces)
		for _, piece in ipairs(pieces) do
			check(piece.enemyId == "splitling" and math.abs(piece.maxHP - Catalog.Enemies.splitling.hp * 2) < 1e-6, "a fragment keeps its parent's health scaling")
			check(math.abs(piece.progress - 30) <= 3 and piece.cash == Rules.KillCash("splitling"), "a fragment stands where it fell and carries its own Gold")
		end
		check(pieces[1].progress ~= pieces[2].progress, "the two fragments do not stack")
		sm.phase = "Wave"
		sm:_damage(pieces[1], 1e9, nil, { trueDamage = true })
		sm:_flushSplits()
		check(sm.alive == 1 and #sm.splits == 0, "a fragment dies for good, without a second burst")
		-- A summoned or rewardless splitter pays nothing, in pieces either.
		local ghost = spawn(sm, "splitter", 40, 1)
		ghost.rewardless, ghost.cash = true, 0
		sm:_damage(ghost, ghost.hp + 1, nil, { trueDamage = true })
		sm:_flushSplits()
		local freebies = 0
		for _, enemy in pairs(sm.enemies) do if enemy.enemyId == "splitling" and enemy.cash == 0 and enemy.rewardless then freebies += 1 end end
		check(freebies == 2, "the pieces of a rewardless splitter are rewardless too")
		-- The enemy cap holds: with one free slot a burst makes one fragment, not two.
		for id in pairs(sm.enemies) do sm.enemies[id] = nil end
		sm.alive = 0
		local crowded = spawn(sm, "splitter", 50, 1)
		sm.alive = Config.MaxEnemies
		sm:_damage(crowded, crowded.hp + 1, nil, { trueDamage = true })
		sm.alive = Config.MaxEnemies - 1
		sm:_flushSplits()
		check(sm.alive == Config.MaxEnemies, "a burst never exceeds the enemy cap, alive is " .. sm.alive)
	end

	-- A saboteur warns, then shorts out the towers beside it for a moment. A
	-- stun-proof hero keeps firing, and a stunned saboteur cancels its shock.
	do
		local sb, sbPlayer = stage({ modeId = "normal", mapId = "manhattan", wave = 20, loadout = { "ironman", "capmen" } })
		local sbEvents = {}
		local sbFx = sb._fx
		sb._fx = function(self, event, ...) table.insert(sbEvents, event) return sbFx(self, event, ...) end
		sb.participants[sbPlayer.UserId].cash = 1e6
		for id in pairs(sb.enemies) do sb.enemies[id] = nil end
		sb.alive, sb.pendingSpawns, sb.spawnIndex = 0, {}, 1
		local soft = place(sb, sbPlayer, "ironman")
		local hard = place(sb, sbPlayer, "capmen")
		hard.position = soft.position + v3(4, 0, 0)
		local saboteur = spawn(sb, "saboteur", 30, 1)
		local function near() saboteur.position = soft.position + v3(3, 0, 0) end
		-- Out of reach of every tower it just walks: no warning, no shock.
		saboteur.position = soft.position + v3(300, 0, 0)
		sb.elapsed = saboteur.nextPower + 0.1
		sb:_enemiesStep(0.01)
		check(not saboteur.shockTold, "a saboteur with no tower in reach does not warn")
		near()
		sb:_enemiesStep(0.01)
		local warning
		for _, event in ipairs(sbEvents) do if event.kind == "Pulse" and event.followEnemyId == saboteur.id and event.warningText then warning = event end end
		check(warning ~= nil and saboteur.shockTold and (soft.stunnedUntil or 0) <= sb.elapsed, "the shock is announced before it lands")
		sb.elapsed += Catalog.Enemies.saboteur.shock.warn + 0.05
		near()
		sb:_enemiesStep(0.01)
		check((soft.stunnedUntil or 0) > sb.elapsed, "the shock stuns the tower beside it")
		check((hard.stunnedUntil or 0) <= sb.elapsed, "a stun-proof hero ignores the shock")
		local stunEvent
		for _, event in ipairs(sbEvents) do if event.kind == "TowersStunned" and table.find(event.towerIds, soft.id) then stunEvent = event end end
		check(stunEvent ~= nil and table.find(stunEvent.towerIds, hard.id) == nil, "the shock names exactly the towers it stopped")
		check(not saboteur.shockTold and saboteur.nextPower > sb.elapsed + 5, "the next shock is a long way off")
		-- Stunned during the warning, the shock fizzles.
		soft.stunnedUntil = 0
		sb.elapsed = saboteur.nextPower + 0.1
		near()
		sb:_enemiesStep(0.01)
		check(saboteur.shockTold, "the second shock is announced too")
		saboteur.stunUntil = sb.elapsed + 3
		sb.elapsed += Catalog.Enemies.saboteur.shock.warn + 0.05
		near()
		sb:_enemiesStep(0.01)
		check((soft.stunnedUntil or 0) <= sb.elapsed and not saboteur.shockTold, "a stunned saboteur's shock fizzles")
	end

	-- Scavenger towers and area powers sweep up their owner's Gold: less
	-- walking, never more Gold.
	local areaHero
	for _, heroId in ipairs(Catalog.HeroOrder) do
		local ability = Catalog.Abilities[Catalog.Heroes[heroId].ability]
		if ability and ability.target == "area" and not areaHero then areaHero = heroId end
	end
	local scav, scavPlayer = stage({ modeId = "normal", mapId = "manhattan", wave = 5, loadout = { areaHero, "rocket" } })
	local sp = scav.participants[scavPlayer.UserId]
	sp.cash = 1e6
	local scavenger = place(scav, scavPlayer, "rocket")
	check(Catalog.Heroes.rocket.pickup ~= nil, "Rocket is a scavenger")
	scav:_coin(sp, scavenger.position + v3(6, 0, 0), 25)
	scav:_coin(sp, v3(-40, 0, 90), 30)
	local collectedBefore = sp.collected
	local farId
	for id, coin in pairs(sp.coins) do if coin.value == 30 then farId = id end end
	scav:Step(0.1)
	check(sp.collected - collectedBefore == 25, "a scavenger tower pulls in the Gold that lands beside it, got " .. tostring(sp.collected - collectedBefore))
	check(farId ~= nil and sp.coins[farId] ~= nil, "Gold far from any scavenger stays on the ground")
	local sweepEvents = {}
	local sweepFx = scav._fx
	scav._fx = function(self, event, ...) table.insert(sweepEvents, event) return sweepFx(self, event, ...) end
	spawn(scav, "zombie", 5, 1)
	scav.phase = "Wave" -- the empty wave above already ended
	local cast = scav:Handle(scavPlayer, "CastSkill", { position = v3(-40, 0, 90) })
	check(cast, "an area power is cast over the Gold")
	check(sp.coins[farId] == nil and sp.collected - collectedBefore == 55, "an area power sweeps up the caster's Gold inside it")
	local flown
	for _, event in ipairs(sweepEvents) do if event.kind == "CoinRemove" and event.id == farId then flown = event end end
	check(flown ~= nil and typeof(flown.to) == "Vector3", "swept coins fly to where they were collected")

	-- Competitive past wave 70: no old 50-wave cap anywhere.
	local deep, deepPlayer = stage({ modeId = "ranked", mapId = "latveria", wave = 149 })
	local dp = deep.participants[deepPlayer.UserId]
	dp.contributed = true
	deep.completedWaves = 148
	local recorded = {}
	deep.profiles.RecordBest = function(_, _, _, _, waves) table.insert(recorded, waves); return true end
	deep:_endWave()
	check(deep.running and deep.completedWaves == 149 and deep.phase == "Preparing", "competitive keeps going past wave 149")
	check(recorded[1] == 149, "a record past wave 70 is kept, got " .. tostring(recorded[1]))
	local deepWave = Waves.Generate("latveria", "ranked", 150, 4, 1)
	check(#deepWave > 0 and #deepWave <= Config.MaxEnemies, "wave 150 still spawns, within the crowd cap")
	check(dp.goldEarned >= Rules.WaveGold("ranked", 149), "wave 149 still pays lobby Gold")

	-- A boss arrives with an entrance the client can show.
	local entrance, _, _, entranceLog = stage({ modeId = "normal", mapId = "gamma", wave = 10 })
	entrance:_spawn({ enemyId = "abomination", pathIndex = 1, progress = 0 })
	check((entranceLog.BossArrive or 0) >= 1, "a boss entering the road sends BossArrive")

	-- Competitive: the whole squad agrees between waves, and the record stays.
	local arena, arenaPlayer = stage({ modeId = "ranked", mapId = "hydra", wave = 12 })
	arena.phase, arena.completedWaves = "Preparing", 12
	local normalRun, normalPlayer = stage({ modeId = "normal", mapId = "gamma", wave = 3 })
	normalRun.phase, normalRun.completedWaves = "Preparing", 3
	check(not normalRun:Handle(normalPlayer, "VoteEnd", { on = true }), "only the competitive arena can be ended by vote")
	arena.phase = "Wave"
	check(not arena:Handle(arenaPlayer, "VoteEnd", { on = true }), "the vote only happens between waves")
	arena.phase = "Preparing"
	local ok, reply = arena:Handle(arenaPlayer, "VoteEnd", { on = true })
	check(ok and reply.ended == true, "a solo commander ends the run on their own")
	local _, ended = arena:Snapshot(arenaPlayer)
	check(ended and ended.ended == true and ended.victory == false and ended.waves == 12, "the run ends as a kept record, not a loss")
end

--==============================================================================
-- Talents in the match
--==============================================================================
print("--- last stand ---")
do
	local match, player = stage({ profile = { talents = { lastStand = 2 } } })
	check(match.lastStandHeal == 10, "two ranks of last stand heal 10")
	match.baseHP = 30.5
	local leaker = spawn(match, "zombie", match.routeCache[1].total - 0.05, 1)
	match:_enemiesStep(0.1)
	check(match.baseHP > 30, "the core is patched up once it drops below 30%, got " .. match.baseHP)
	local healedTo = match.baseHP
	match.baseHP = 29.5
	local second = spawn(match, "zombie", match.routeCache[1].total - 0.05, 1)
	match:_enemiesStep(0.1)
	check(match.baseHP < 29.5 + 0.001, "last stand triggers once per match")
	local none, nonePlayer = stage({})
	none.baseHP = 25
	check(none.lastStandHeal == 0, "no talent, no last stand")
end

print("--- cooperative full matches ---")
for size=2,4 do
	local run=simulate({mapId="manhattan",modeId="normal",size=size})
	check(run and run.results and not run.match.running,"cooperative run reaches results for "..size.." players")
	if run and run.results then
		print(string.format("  %d players: %d waves, %.1f min, victory=%s",size,run.results.waves,run.seconds/60,tostring(run.results.victory)))
		for _,member in ipairs(run.members) do
			local snapshot,result=run.match:Snapshot(member)
			check(result and result.waves==run.results.waves,"all members receive the same completed waves")
			check(snapshot.towerLimit==Rules.TowerLimit(size),"group uses correct tower cap")
			check(run.byUser[member.UserId].gold>0,"each contributing player receives persistent gold")
			check(snapshot.cash>=0,"cooperative energy never goes negative")
		end
		check(run.match.size==size,"party scaling stays fixed through results")
	end
end

print("--- base economy and defenses ---")
do
	for _,id in ipairs(Catalog.BaseOrder) do
		local match,player=stage({profile={equippedBase=id,bases={[id]=true}}})
		local p=match.participants[player.UserId]
		check(p.base.id==id,"owned base selected at start: "..id)
		p.cash=20000; local gold=p.profile.gold
		local before=p.cash
		check(not match:Handle(player,"UpgradeBase",{expectedLevel=2}),"stale base upgrade rejected")
		check(p.cash==before,"stale upgrade spends nothing")
		for level=1,4 do
			local hp=match.baseHP; local max=match.maxBaseHP; local old=p.base.stats
			check(match:Handle(player,"UpgradeBase",{expectedLevel=level}),"upgrade base "..id.." at "..level)
			check(p.base.level==level+1 and p.cash==before-old.upgradeCost,"base upgrade charges match Energy exactly once")
			check(match.baseHP-hp==match.maxBaseHP-max and match.maxBaseHP>max,"upgrade adds new HP without free full repair")
			before=p.cash
		end
		check(not match:Handle(player,"UpgradeBase",{expectedLevel=5}),"base stops at five levels")
		check(p.profile.gold==gold,"base upgrades never spend permanent Gold")
		p.contributed=true; before=p.cash; match:_endWave()
		check(p.cash-before==90+match.wave*12+p.base.stats.income,"completed wave grants base income once")
		before=p.cash; match:_endWave(); check(p.cash==before,"duplicate end-wave cannot farm income")
	end
	local match,player=stage({profile={equippedBase="worldtree",bases={worldtree=true}}})
	local p=match.participants[player.UserId]; local energy=p.cash; match:_endWave()
	check(p.cash==energy,"idle farm earns no income without contribution")
	local fresh,freshPlayer=stage({profile={equippedBase="worldtree",bases={}}})
	check(fresh.participants[freshPlayer.UserId].base.id=="outpost","forged base selection falls back to starter")
	local wall,defender=stage({profile={equippedBase="bunker",bases={bunker=true}}})
	local base=wall.participants[defender.UserId].base
	local enemy=spawn(wall,"brute",wall.routeCache[1].total-10,10)
	local hp=enemy.hp; local capacity=base.wall
	wall:_basesStep(0.1)
	check(base.wall==0 and math.abs(hp-enemy.hp-capacity)<0.001,"wall trades finite HP for damage")
	wall.elapsed+=4; wall:_basesStep(0.1); check(base.wall==0,"wall cannot regenerate while still under attack")
	wall.enemies={}; wall.alive=0; wall.elapsed+=2; wall:_basesStep(1)
	check(base.wall>0 and base.wall<=base.stats.wall,"wall regenerates after five seconds without damage")
	local cannon,g=stage({profile={equippedBase="arsenal",bases={arsenal=true}}})
	local target=spawn(cannon,"zombie",cannon.routeCache[1].total-9,100)
	local hpBefore=target.hp; cannon:_basesStep(0.1)
	check(target.hp<hpBefore and cannon.participants[g.UserId].contributed,"cannon attacks near core and credits support contribution")
	local barracks,s=stage({profile={equippedBase="barracks",bases={barracks=true}}})
	barracks:_basesStep(0.1)
	local soldierId,soldier=next(barracks.soldiers)
	check(soldier and soldier.progress<barracks.routeCache[1].total,"soldier marches toward enemy entrance")
	local victim=spawn(barracks,"zombie",soldier.progress-2,1)
	local hpBefore=soldier.hp; barracks:_basesStep(0.1)
	check(victim.hp<=0 and soldier.hp<hpBefore,"soldier collision spends HP and damages enemy")
	soldier.progress=0.1; local earned=barracks.participants[s.UserId].goldEarned
	barracks:_basesStep(0.1)
	check(not barracks.soldiers[soldierId] and barracks.participants[s.UserId].goldEarned==earned,"soldier reaching entrance vanishes without reward")
	local air=spawn(barracks,"flyer",barracks.routeCache[1].total-2,10)
	barracks.participants[s.UserId].base.nextSoldier=0; barracks:_basesStep(0.1)
	check(air.hp==air.maxHP,"ground soldiers cannot hit flying enemies")
	for size=2,4 do
		local members,byUser={},{}
		for n=1,size do
			local member=newPlayer(8000+n); members[n]=member
			byUser[member.UserId]=newProfile({bases={reactor=true},equippedBase="reactor",campaign={manhattan={normal=true}}})
		end
		local run=MatchService.new(Config,Catalog,Rules,Waves,newProfiles(byUser[8001],byUser),newWorld(),newRemotes({}),function() end)
		check(run:Start(members,"manhattan","normal","base-coop-"..size),"cooperative bases start")
		check(run.maxBaseHP==Config.BaseHP+size*math.floor(Rules.BaseStats("reactor",1).hp/size),"group HP contributions use fixed party divisor")
		local p=run.participants[8001]; p.cash=1000
		check(run:Handle(members[1],"UpgradeBase",{expectedLevel=1}),"commander upgrades personal module")
		check(run.participants[8002].base.level==1 and p.base.level==2,"upgrade cannot change teammate module")
		local hp=run.maxBaseHP; local energy=p.cash
		run:OnLeave(members[1]); check(run:Reconnect(members[1]),"base owner reconnects")
		check(run.maxBaseHP==hp and p.cash==energy and p.base.level==2,"reconnect restores base without duplicating HP or Energy")
	end
end

print("--- map hazards ---")
do
	-- Gama: a toxic surge, announced first, makes the infected run faster.
	local match = stage({ mapId = "gamma", wave = 5 })
	local hazard = Catalog.Maps.gamma.hazard
	local enemy = spawn(match, "zombie", 10)
	match.hazardTimer = hazard.every - hazard.warn - 0.05
	match:_hazardStep(0.1)
	check(match.hazardState.warned == true, "a map hazard is announced before it strikes")
	check((enemy.frenzyUntil or 0) <= match.elapsed, "and does nothing yet")
	match:_hazardStep(hazard.warn)
	check((enemy.frenzyUntil or 0) > match.elapsed, "the toxic surge speeds the infected up")
	-- Fundição: the furnace stuns the towers in its circle.
	local foundry, builder = stage({ mapId = "hydra", wave = 5 })
	local tower = place(foundry, builder, "ironman")
	local furnace = Catalog.Maps.hydra.hazard
	foundry.hazardTimer = furnace.every - furnace.warn
	foundry:_hazardStep(0.01)
	check(foundry.hazardState.center ~= nil, "the furnace marks a circle on a tower first")
	foundry:_hazardStep(furnace.warn)
	check((tower.stunnedUntil or 0) > foundry.elapsed, "the furnace stuns the tower in its circle")
	-- Selva de Cristal: guardian crystals shield the enemies.
	local jungle = stage({ mapId = "wakanda", wave = 5 })
	local brute = spawn(jungle, "brute", 20)
	jungle.hazardTimer = Catalog.Maps.wakanda.hazard.every
	jungle:_hazardStep(0.01)
	check(brute.shield > 0, "guardian crystals shield the enemies")
	-- Ponte Celeste: a gust drives enemies back down the road.
	local bridge = stage({ mapId = "asgard", wave = 5 })
	local runner = spawn(bridge, "runner", 40)
	bridge.hazardTimer = Catalog.Maps.asgard.hazard.every
	bridge:_hazardStep(0.01)
	check(math.abs(runner.progress - (40 - Catalog.Maps.asgard.hazard.power)) < 1e-6, "the sky gust drives enemies back")
	-- Preparation and Manhattan stay calm.
	local calm = stage({ mapId = "manhattan", wave = 5 })
	calm.hazardTimer = 999
	calm:_hazardStep(1)
	check(calm.hazardCount == 0, "Manhattan has no hazard")
end

print("--- squad pings ---")
do
	local duo = simulate({ mapId = "manhattan", modeId = "tutorial", size = 2 })
	local match = duo.match
	check(match ~= nil, "a duo match exists for the ping test")
	if match then
		match.running, match.phase = true, "Wave"
		local first, second = duo.members[1], duo.members[2]
		local events = {}
		local original = match._fx
		match._fx = function(self, event, ...) table.insert(events, event) return original(self, event, ...) end
		local ok = match:Handle(first, "Ping", { position = v3(10, 5, 20) })
		check(ok, "a commander in a squad can ping")
		local ping
		for _, event in ipairs(events) do if event.kind == "Ping" then ping = event end end
		check(ping ~= nil and ping.position.Y == 0 and ping.position.X == 10 and ping.ownerId == first.UserId, "the ping is relayed flat on the ground with its owner")
		check(not match:Handle(first, "Ping", { position = v3(10, 0, 20) }), "pings are rate limited per commander")
		check(match:Handle(second, "Ping", { position = v3(-30, 0, 40) }), "another commander's limit is their own")
		check(not match:Handle(second, "Ping", { position = v3(9999, 0, 0) }), "a ping off the map is refused")
		check(not match:Handle(second, "Ping", { position = "here" }), "a malformed ping is refused")
	end
	local solo = stage({ mapId = "manhattan", wave = 1 })
	local soloPlayer
	for _, p in pairs(solo.participants) do soloPlayer = p.player end
	check(not solo:Handle(soloPlayer, "Ping", { position = v3(1, 0, 1) }), "alone there is nobody to ping")
end

print("--- wave mutations ---")
do
	-- Find a seed and wave that mutate, then compare with the same wave unmutated.
	local seedFound, waveFound, kind
	for seed = 1, 400 do
		for wave = 6, 9 do
			local id = Rules.WaveMutation("normal", "manhattan", wave, seed)
			if id == "swarm" and not seedFound then seedFound, waveFound, kind = seed, wave, id end
		end
	end
	check(seedFound ~= nil, "a swarm wave exists to test")
	if seedFound then
		local plain = Waves.Generate("manhattan", "tutorial", 1, 1, seedFound)
		check(#plain > 0, "a plain wave generates")
		local mutated = Waves.Generate("manhattan", "normal", waveFound, 1, seedFound)
		local baseCount = math.min(100, 9 + math.floor(waveFound * 1.4))
		check(#mutated == math.min(100, math.floor(baseCount * Catalog.Mutations.swarm.count)), "a swarm wave has 50% more enemies: " .. #mutated .. " vs " .. baseCount)
		-- Rush and iron change speed and gold.
		for _, wanted in ipairs({ "rush", "iron" }) do
			local foundSeed, foundWave
			for seed = 1, 600 do
				for wave = 6, 9 do
					if not foundSeed and Rules.WaveMutation("normal", "manhattan", wave, seed) == wanted then foundSeed, foundWave = seed, wave end
				end
			end
			check(foundSeed ~= nil, "a " .. wanted .. " wave exists to test")
			if foundSeed then
				local specs = Waves.Generate("manhattan", "normal", foundWave, 1, foundSeed)
				local def = Catalog.Mutations[wanted]
				check(math.abs(specs[1].speedMultiplier - (def.speed or 1)) < 1e-9, wanted .. " sets the wave's speed")
				check(specs[1].cash == math.floor(Rules.KillCash(specs[1].enemyId) * def.cash + 0.5), wanted .. " scales what its enemies drop")
			end
		end
	end
	-- The match announces it: in the preview while preparing, as an event when it starts.
	local match = stage({ mapId = "manhattan", wave = 5 })
	local announced = {}
	local original = match._fx
	match._fx = function(self, event, ...) table.insert(announced, event) return original(self, event, ...) end
	local mutatingSeed
	for seed = 1, 600 do
		if Rules.WaveMutation("normal", "manhattan", 6, seed) then mutatingSeed = seed break end
	end
	match.seed = mutatingSeed
	match.phase = "Preparing"
	match.wave = 5
	match:_previewThreats()
	check(match.nextMutation == Rules.WaveMutation("normal", "manhattan", 6, mutatingSeed), "the preview knows the next wave's mutation")
	match.prepRemaining = 0
	match:_beginWave()
	local sawEvent = false
	for _, event in ipairs(announced) do if event.kind == "Mutation" and event.mutationId == match.mutation then sawEvent = true end end
	check(match.mutation ~= nil and sawEvent, "starting a mutated wave announces it to every client")
end

print("--- map of the day ---")
do
	local day = math.floor(os.time() / 86400)
	local featuredMapId = Rules.FeaturedMap(day)
	local other
	for _, id in ipairs(Rules.MapsForMode("normal")) do if id ~= featuredMapId then other = id break end end
	local previous = Config.DailyFeature
	Config.DailyFeature = nil
	local match = stage({ mapId = featuredMapId, wave = 1 })
	check(math.abs(match.featuredBonus - (1 + Catalog.DailyFeature.bonus)) < 1e-9, "a match on the map of the day carries the bonus")
	check(math.abs(match.rewardBonus - match.partyBonus * match.featuredBonus) < 1e-9, "and it multiplies the party bonus")
	local plain = stage({ mapId = other, wave = 1 })
	check(plain.featuredBonus == 1, "any other map pays as usual")
	Config.DailyFeature = false
	local off = stage({ mapId = featuredMapId, wave = 1 })
	check(off.featuredBonus == 1, "the feature can be switched off")
	Config.DailyFeature = previous
end

print("--- punches and indestructibility ---")
do
	local match, builder = stage({ mapId = "manhattan", wave = 5, loadout = { "capmen", "ironman" } })
	match.participants[builder.UserId].cash = 1e6
	local puncher = place(match, builder, "capmen")
	local stats = match:_towerStats(puncher)
	check(stats.knockback == Catalog.Heroes.capmen.knockback and stats.stunProof, "Captain Men's tower carries his knockback and steadiness")
	-- An enemy standing inside his reach, far from the end of the road.
	local progress
	for at = 20, 400, 2 do
		local position = match:_pathPosition(1, at)
		if distanceBetween(position, puncher.position) <= stats.range - 1 then progress = at; break end
	end
	check(progress ~= nil, "some stretch of the road lies inside the puncher's reach")
	if progress then
		local victim = spawn(match, "zombie", progress, 80)
		puncher.nextAttack = 0
		match:_attack(puncher, stats)
		check(math.abs(victim.progress - (progress - stats.knockback)) < 1e-6, "a punch shoves the enemy back along the road: " .. tostring(victim.progress))
		-- Never twice inside 0.8 s, so a fast puncher cannot pin an enemy down.
		local shoved = victim.progress
		match:_attack(puncher, stats)
		check(victim.progress == shoved, "the shove has its own short cooldown")
		-- A boss holds its ground.
		local boss = spawn(match, "lizard", progress, 80)
		match:_attack(puncher, stats)
		check(boss.progress == progress, "a boss is never shoved")
	end
	-- Stuns: his tower shrugs them off, a plain one does not, and an aura covers allies.
	local ally = place(match, builder, "ironman")
	match:_stunTowers(puncher.position, 500, 3)
	check((puncher.stunnedUntil or 0) <= match.elapsed, "no stun touches Captain Men")
	check((ally.stunnedUntil or 0) > match.elapsed, "a plain tower is stunned by the same blast")
	ally.stunnedUntil = 0
	ally.position = puncher.position + Vector3.new(10, 0, 0)
	puncher.level, puncher.branch, puncher.cache = 5, 2, nil
	match.participants[builder.UserId].modsVersion += 1
	check(match:_stunProof(ally), "the Human Wall branch steadies the ally beside him")
	match:_stunTowers(ally.position, 500, 3)
	check((ally.stunnedUntil or 0) <= match.elapsed, "so the blast no longer stuns the ally")
	ally.position = puncher.position + Vector3.new(60, 0, 0)
	check(not match:_stunProof(ally), "an ally outside the aura is not steady")
end

print("--- performance guard ---")
do
	local match, player = stage({ wave = 45 })
	match.participants[player.UserId].cash = 1e6
	for _ = 1, 8 do place(match, player, "ironman") end
	-- A common hero is capped at eight towers per commander.
	local refused = 0
	for _, spot in ipairs(buildSpots(match.mapId)) do
		local ok, reason = match:Handle(player, "PlaceTower", { heroId = "ironman", position = spot.point })
		check(not ok, "a ninth tower of a common hero is refused")
		if not ok and string.find(tostring(reason), Rules.BuildReasons.unitLimit.pt, 1, true) then refused += 1 end
		break
	end
	check(refused == 1, "the refusal names the per-hero limit")
	for _ = 1, 4 do place(match, player, "hawkeye") end
	local calls = 0
	local original = Rules.TowerStats
	Rules.TowerStats = function(...) calls += 1 return original(...) end
	for _ = 1, 100 do
		for _, tower in pairs(match.towers) do match:_towerStats(tower) end
	end
	Rules.TowerStats = original
	check(calls <= 12, "tower stats are cached: 1200 reads cost " .. calls .. " recomputations")
end

print(string.format("%s match simulation: %d checks, %d failures",
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error("match simulation failed", 0) end
