-- Server-owned account state. Every economic change is committed with UpdateAsync.
-- The in-process queue prevents a late save from overwriting a newer receipt.
-- A session lease protects the same profile when players teleport between places.
local DataStoreService = game:GetService("DataStoreService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local PlayerService = {}
PlayerService.__index = PlayerService

local function talentSpent(profile)
	local spent = 0
	for _, rank in pairs(profile.talents or {}) do spent += rank end
	return spent
end

local DAY = 86400
-- Competitive waves held in one run for the "Fearless" achievement.
local FEARLESS_WAVES = 30
-- Purchase receipts remembered per account; older ones are dropped.
local RECEIPTS_KEPT = 200
local SCHEMA_VERSION = 1
local PUBLIC_FIELDS = { "gold", "xp", "level", "heroes", "bases", "equippedBase", "loadout", "abilities", "pity", "campaign", "tutorialComplete", "settings", "quests", "achievements", "best", "stats", "title", "talents", "starterPack", "boostUntil", "heroPicks" }
-- Heroes are won from chests or bought directly with Robux, never with a plain
-- gold purchase, so there is no BuyHero here: OpenChest is the way in.
local ACTIONS = { BuyGuaranteed = true, PickHero = true, BuyMarket = true, SendGift = true, ClaimGift = true, TradeOffer = true, TradeAccept = true, TradeSet = true, TradeConfirm = true, TradeCancel = true, EquipBase = true, UpgradeTalent = true, ResetTalents = true, OpenChest = true, UpgradeAbility = true, SetLoadout = true, Settings = true, ClaimQuest = true, ProductInfo = true, Leaderboard = true, SetTitle = true, RankUpHero = true, SetHeroPoints = true,
	ClaimFreeChest = true, ClaimLogin = true, ClaimPlaytime = true, ClaimMilestone = true, ClaimSeason = true,
	RedeemCode = true, ClaimGroupReward = true }
-- Rewards that can open a chest need their two random numbers drawn up front.
local CHEST_ACTIONS = { OpenChest = true, ClaimFreeChest = true, ClaimLogin = true, ClaimPlaytime = true, RedeemCode = true, ClaimSeason = true, ClaimGift = true }
-- Wrong promo codes are refused before any DataStore call; past this many
-- misses in a minute, the player is asked to wait instead of guessing.
local CODE_MISSES_PER_MINUTE = 6
-- The VIP pass carries a title that is never earned through play, so it is
-- offered while the pass is owned instead of being written into the profile.
local VIP_TITLE = { pt = "Patrono da Resistencia", en = "Resistance Patron" }
local MAX_LOADOUT = 5
-- A hero bought with Robux that the account already owns (two purchases racing
-- each other) is never wasted: it turns into this much gold per Robux.
local GOLD_PER_ROBUX = 10
-- Time played is counted between transactions, and never more than this per gap.
local PLAYTIME_CAP = 43200

local function copy(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, child in pairs(value) do result[key] = copy(child) end
	return result
end

local function integer(value, minimum, maximum)
	return type(value) == "number" and value == value and value >= minimum and value <= maximum and value % 1 == 0
end

local function tableCount(value)
	local count = 0
	for _ in pairs(value) do count += 1 end
	return count
end

local function xpThreshold(level)
	return math.floor(150 * (level - 1) ^ 1.65)
end

local function masteryThreshold(level)
	return math.floor(90 * (level - 1) ^ 1.55)
end

local function levelFor(xp, maximum, threshold)
	local result = 1
	while result < maximum and xp >= threshold(result + 1) do result += 1 end
	return result
end

local function validId(value)
	return type(value) == "string" and #value > 0 and #value <= 160
end

local function validList(values, maximum, predicate, allowEmpty)
	if type(values) ~= "table" or #values > maximum or (not allowEmpty and #values < 1) then return false end
	local seen, count = {}, 0
	for key, value in pairs(values) do
		count += 1
		if not integer(key, 1, maximum) or key > #values or not validId(value) or seen[value] or not predicate(value) then return false end
		seen[value] = true
	end
	return count == #values
end

-- Trades an account completed today (UTC), from its own ledger.
local function tradesToday(profile, now)
	local day, count = math.floor(now / DAY), 0
	for _, entry in ipairs(type(profile._trades) == "table" and profile._trades or {}) do
		if math.floor((tonumber(entry.at) or 0) / DAY) == day then count += 1 end
	end
	return count
end

local function newProfile(now)
	return {
		schemaVersion = SCHEMA_VERSION,
		gold = 0, xp = 0, level = 1, talents = {},
		bases = {outpost=true}, equippedBase = "outpost",
		heroes = { ironman = { xp = 0, level = 1 }, hawkeye = { xp = 0, level = 1 } },
		-- Slot one is the hero whose ability the player fights with.
		loadout = { "ironman", "hawkeye" }, abilities = { ironman = 1, hawkeye = 1 },
		pity = { legendary = 0 },
		rewards = { freeChestAt = 0, loginDay = -1, loginStreak = 0, playDay = -1, playSeconds = 0, playClaimed = {}, collection = {}, groupClaimed = false },
		codes = {}, starterPack = false, boostUntil = 0, heroPicks = {}, _trades = {}, market = { day = 0, bought = {} }, season = { id = 0, xp = 0, freeClaimed = 0, premiumClaimed = 0 },
		campaign = {}, tutorialComplete = false, title = "",
		settings = { language = "pt", languageSet = false, lowFX = false, shake = true, music = true, effects = true, interface = true, autoSkip = false, fastForward = false },
		quests = {}, achievements = {}, best = {},
		stats = { waves = 0, bosses = 0, wins = 0, matches = 0, goldEarned = 0, chests = 0 },
		createdAt = now, updatedAt = now,
		_receipts = {}, _awards = {}, _operations = {}, _operationOrder = {}, _dailyWins = {},
		_pendingBoards = {}, _passHistory = {},
	}
end

-- Unknown future versions and damaged economic fields fail closed. A failed read
-- must never turn an existing player into a new profile.
-- The season's total XP (every level paid): where the stored count stops.
local function seasonMaxXp(catalog)
	local season = catalog.Season
	return season.levels * season.firstXp + season.stepXp * season.levels * (season.levels - 1) / 2
end

local function normalize(raw, now, catalog)
	if raw == nil then return newProfile(now) end
	if type(raw) ~= "table" or not integer(raw.schemaVersion or 1, 1, SCHEMA_VERSION) then error("UNSUPPORTED_PROFILE_VERSION") end
	if not integer(raw.gold, 0, 9007199254740991) or not integer(raw.xp, 0, 9007199254740991) or type(raw.heroes) ~= "table" then error("INVALID_PROFILE_DATA") end
	local profile = copy(raw)
	local defaults = newProfile(now)
	for key, value in pairs(defaults) do
		if profile[key] == nil then profile[key] = copy(value)
		elseif type(value) == "table" and type(profile[key]) ~= "table" then error("INVALID_PROFILE_FIELD:" .. key) end
	end
	profile.schemaVersion = SCHEMA_VERSION
	profile.bases.outpost=true
	for id,owned in pairs(profile.bases) do if owned~=true or not catalog.Bases[id] then profile.bases[id]=nil end end
	if type(profile.equippedBase)~="string" or not profile.bases[profile.equippedBase] then profile.equippedBase="outpost" end
	if profile.settings.effects == nil then profile.settings.effects = profile.settings.music ~= false end
	if profile.settings.interface == nil then profile.settings.interface = profile.settings.effects ~= false end
	profile.level = levelFor(profile.xp, 50, xpThreshold)
	-- The old per-slot skill system is gone: abilities now belong to heroes.
	profile.skills, profile.activeSkills, profile.passives = nil, nil, nil
	-- A talent that a later version removed or re-shaped is dropped, not fatal:
	-- refusing to load would lock a player out of their own account.
	local changed = true
	while changed do
		changed = false
		for id, rank in pairs(profile.talents) do
			local node = catalog.Talents[id]
			local keep = node ~= nil and integer(rank, 1, node.maxRank)
			if keep and node.parent and (profile.talents[node.parent] or 0) < node.requiredRank then keep = false end
			if not keep then profile.talents[id] = nil; changed = true end
		end
	end
	if talentSpent(profile) > profile.level - 1 then error("INVALID_TALENT_BUDGET") end
	local max = catalog.AbilityRanks.max
	for id, hero in pairs(profile.heroes) do
		if type(hero) ~= "table" or not integer(hero.xp, 0, 9007199254740991) then error("INVALID_MASTERY_DATA") end
		hero.level = levelFor(hero.xp, 20, masteryThreshold)
		hero.stars = math.clamp(math.floor(tonumber(hero.stars) or 0), 0, catalog.Stars.max)
		hero.shiny = hero.shiny == true or nil
		-- Hero cards: the rank has no top, spare copies are whole numbers, and the
		-- points put into damage / speed / range never exceed what the rank earned.
		hero.rank = math.max(1, math.floor(tonumber(hero.rank) or 1))
		hero.copies = math.max(0, math.floor(tonumber(hero.copies) or 0))
		local earned, spent, alloc = (hero.rank - 1) * catalog.HeroCards.pointsPerRank, 0, {}
		for _, key in ipairs(catalog.HeroCards.stats) do
			local value = type(hero.alloc) == "table" and hero.alloc[key] or 0
			value = (type(value) == "number" and value == value and value >= 0) and math.floor(value) or 0
			alloc[key] = value
			spent += value
		end
		-- More points than the rank earned means the record is wrong: start over.
		if spent > earned then alloc = { damage = 0, speed = 0, range = 0 } end
		hero.alloc = alloc
		local rank = profile.abilities[id]
		if not integer(rank, 1, max) then profile.abilities[id] = 1 end
	end
	for id in pairs(profile.abilities) do
		if not profile.heroes[id] then profile.abilities[id] = nil end
	end
	local loadout, seen = {}, {}
	for _, id in ipairs(profile.loadout) do
		if type(id) == "string" and profile.heroes[id] and not seen[id] and #loadout < MAX_LOADOUT then
			table.insert(loadout, id)
			seen[id] = true
		end
	end
	if #loadout == 0 then loadout = { "ironman", "hawkeye" } end
	profile.loadout = loadout
	if type(profile.pity.legendary) ~= "number" then profile.pity.legendary = 0 end
	for _,id in ipairs(catalog.ChestOrder) do
		local chest=catalog.Chests[id]
		if chest.pity and not integer(profile.pity[id],0,chest.pity.after-1) then profile.pity[id]=0 end
	end
	-- A damaged reward record is repaired field by field rather than refusing
	-- to load: nothing in it is worth locking a player out for.
	local rewards = profile.rewards
	for key, fallback in pairs({ freeChestAt = 0, loginDay = -1, loginStreak = 0, playDay = -1, playSeconds = 0 }) do
		if type(rewards[key]) ~= "number" or rewards[key] ~= rewards[key] then rewards[key] = fallback end
	end
	for _, key in ipairs({ "playClaimed", "collection" }) do
		if type(rewards[key]) ~= "table" then rewards[key] = {} end
	end
	if type(rewards.groupClaimed) ~= "boolean" then rewards.groupClaimed = false end
	-- The season record is repaired the same way: counts inside their range.
	local season, seasonMax = profile.season, catalog.Season.levels
	for _, key in ipairs({ "id", "xp" }) do
		if type(season[key]) ~= "number" or season[key] ~= season[key] or season[key] < 0 then season[key] = 0 end
		season[key] = math.floor(season[key])
	end
	season.xp = math.min(season.xp, seasonMaxXp(catalog))
	for _, key in ipairs({ "freeClaimed", "premiumClaimed" }) do
		season[key] = math.clamp(math.floor(tonumber(season[key]) or 0), 0, seasonMax)
	end
	-- Achievements keep the names they were unlocked with, except the ones
	-- named after a hero, a map or an old name: those follow today's names.
	local renamed = { allHeroes = { pt = "Coleção completa", en = "Full collection" }, firstVictory = { pt = "Vitória da Resistência", en = "Resistance victory" } }
	for id, entry in pairs(profile.achievements) do
		if type(entry) == "table" and type(id) == "string" then
			local kind, key = string.match(id, "^(%w+):(.+)$")
			local hero, map = key and catalog.Heroes[key], key and catalog.Maps[key]
			if renamed[id] then entry.name = copy(renamed[id])
			elseif kind == "mythic" and hero then entry.name = { pt = "Lenda cósmica: " .. hero.name.pt, en = "Cosmic legend: " .. hero.name.en }
			elseif kind == "mastery" and hero then entry.name = { pt = "Despertar: " .. hero.name.pt, en = "Awakening: " .. hero.name.en }
			elseif kind == "medal" and map then entry.name = { pt = "Defesa perfeita: " .. map.name.pt, en = "Flawless defense: " .. map.name.en } end
		end
	end
	return profile
end

-- Missions rotate: every day brings the wave mission plus two drawn from the
-- rest of the pool, every week the wave and boss missions plus one more. The
-- draw only depends on the day (or week) number, so every server and every
-- session agrees without storing anything.
local DAILY_FIXED = {
	{ key = "waves", name = { pt = "Resista à invasão", en = "Withstand the invasion" }, target = 15, gold = 150, xp = 70 },
}
local DAILY_POOL = {
	{ key = "wins", name = { pt = "Defesa concluída", en = "Successful defense" }, target = 1, gold = 100, xp = 60 },
	{ key = "heroes", name = { pt = "Equipe versátil", en = "Versatile team" }, target = 3, gold = 100, xp = 60 },
	{ key = "gold", name = { pt = "Rendimento de guerra", en = "War income" }, target = 1500, gold = 120, xp = 60 },
	{ key = "campaign", name = { pt = "Frente de batalha", en = "Front line" }, target = 2, gold = 130, xp = 70 },
	{ key = "chests", name = { pt = "Dia de sorte", en = "Lucky day" }, target = 2, gold = 150, xp = 60 },
	{ key = "bosses", name = { pt = "Caça-chefes", en = "Boss chase" }, target = 1, gold = 140, xp = 70 },
	{ key = "cards", name = { pt = "Mestre das cartas", en = "Card master" }, target = 1, gold = 200, xp = 90 },
}
local WEEKLY_FIXED = {
	{ key = "waves", name = { pt = "Veterano da defesa", en = "Defense veteran" }, target = 100, gold = 750, xp = 250 },
	{ key = "bosses", name = { pt = "Caçador de chefes", en = "Boss hunter" }, target = 15, gold = 600, xp = 200 },
}
local WEEKLY_POOL = {
	{ key = "heroes", name = { pt = "Aliança de heróis", en = "Hero alliance" }, target = 8, gold = 750, xp = 250 },
	{ key = "wins", name = { pt = "Semana vitoriosa", en = "Winning week" }, target = 5, gold = 700, xp = 240 },
	{ key = "noDamage", name = { pt = "Defesa impecável", en = "Flawless defense" }, target = 2, gold = 800, xp = 260 },
	{ key = "cards", name = { pt = "Cartas na mesa", en = "Cards on the table" }, target = 2, gold = 750, xp = 250 },
	{ key = "gold", name = { pt = "Tesouro de guerra", en = "War treasure" }, target = 8000, gold = 700, xp = 240 },
}

-- `count` definitions of the pool for a seed (a day or a week number).
local function drawQuests(pool, count, seed)
	local order = {}
	for index, definition in ipairs(pool) do
		table.insert(order, { definition = definition, weight = (seed * 2654435761 + index * 40503) % 4093 })
	end
	table.sort(order, function(a, b)
		if a.weight ~= b.weight then return a.weight < b.weight end
		return a.definition.key < b.definition.key
	end)
	local picked = {}
	for index = 1, math.min(count, #order) do table.insert(picked, order[index].definition) end
	return picked
end


-- The mission keys a given day (or week) brings: fixed ones first, then the draw.
function PlayerService.QuestKeys(period, number)
	local fixed, pool, count = DAILY_FIXED, DAILY_POOL, 2
	if period == "weekly" then fixed, pool, count = WEEKLY_FIXED, WEEKLY_POOL, 1 end
	local keys = {}
	for _, definition in ipairs(fixed) do table.insert(keys, definition.key) end
	for _, definition in ipairs(drawQuests(pool, count, number)) do table.insert(keys, definition.key) end
	return keys
end

-- What a mission asks for, in words: the card shows it under the name.
local function questDescription(key, target)
	local n = tostring(target)
	if key == "waves" then return { pt = "Sobreviva a " .. n .. " ondas, somando todas as partidas.", en = "Survive " .. n .. " waves, counted across all matches." }
	elseif key == "bosses" then return { pt = "Derrote " .. n .. (target == 1 and " chefe" or " chefes") .. " em partidas.", en = "Defeat " .. n .. (target == 1 and " boss" or " bosses") .. " in matches." }
	elseif key == "wins" then return { pt = "Vença " .. n .. (target == 1 and " defesa" or " defesas") .. " (o treino não conta).", en = "Win " .. n .. (target == 1 and " defense" or " defenses") .. " (training does not count)." }
	elseif key == "heroes" then return { pt = "Use " .. n .. " heróis diferentes em partidas.", en = "Fight with " .. n .. " different heroes in matches." }
	elseif key == "gold" then return { pt = "Ganhe " .. n .. " de Ouro em partidas.", en = "Earn " .. n .. " Gold in matches." }
	elseif key == "campaign" then return { pt = "Termine " .. n .. (target == 1 and " partida" or " partidas") .. " da campanha.", en = "Finish " .. n .. " campaign " .. (target == 1 and "match." or "matches.") }
	elseif key == "noDamage" then return { pt = "Vença " .. n .. (target == 1 and " partida" or " partidas") .. " sem a base sofrer dano.", en = "Win " .. n .. (target == 1 and " match" or " matches") .. " without the base taking damage." }
	elseif key == "cards" then return { pt = "Vença " .. n .. (target == 1 and " partida" or " partidas") .. " no modo Cartas.", en = "Win " .. n .. " Cards-mode " .. (target == 1 and "match." or "matches.") }
	elseif key == "chests" then return { pt = "Abra " .. n .. (target == 1 and " baú" or " baús") .. " de heróis.", en = "Open " .. n .. " hero " .. (target == 1 and "chest." or "chests.") } end
	return { pt = "", en = "" }
end

local function refreshQuests(profile, now)
	for id, quest in pairs(profile.quests) do
		if type(quest) ~= "table" or (quest.expiresAt or 0) <= now then profile.quests[id] = nil
		else quest.description = questDescription(quest.kind, quest.target) end
	end
	local today = math.floor(now / DAY)
	local function add(definition, period, index, expires)
		local id = period .. ":" .. tostring(index) .. ":" .. definition.key
		if not profile.quests[id] then
			profile.quests[id] = { id = id, kind = definition.key, period = period, name = copy(definition.name), description = questDescription(definition.key, definition.target), progress = 0, target = definition.target, gold = definition.gold, xp = definition.xp, claimed = false, expiresAt = expires, heroIds = {} }
		end
	end
	-- Only today's set is drawn. An earlier day's set, if the account was here that
	-- day, lives on (unclaimed missions stay claimable for two more days); a day the
	-- account missed is not made up with free missions.
	for _, definition in ipairs(DAILY_FIXED) do add(definition, "daily", today, (today + 3) * DAY) end
	for _, definition in ipairs(drawQuests(DAILY_POOL, 2, today)) do add(definition, "daily", today, (today + 3) * DAY) end
	local week = math.floor((today + 3) / 7) -- Monday-based UTC week.
	for _, definition in ipairs(WEEKLY_FIXED) do add(definition, "weekly", week, (week * 7 + 4) * DAY) end
	for _, definition in ipairs(drawQuests(WEEKLY_POOL, 1, week)) do add(definition, "weekly", week, (week * 7 + 4) * DAY) end
	for day in pairs(profile._dailyWins) do if tonumber(day) and tonumber(day) < today - 7 then profile._dailyWins[day] = nil end end
end

local function achievement(profile, id, pt, en, now, kind, mapId)
	if not profile.achievements[id] then profile.achievements[id] = { name = { pt = pt, en = en }, unlockedAt = now, kind = kind or "achievement", mapId = mapId } end
end

local function productDefinitions(config, catalog)
	local result = copy(catalog.Products or { Passes = {}, Consumables = {}, Heroes = {} })
	for _, category in ipairs({ "Passes", "Consumables", "Heroes" }) do
		result[category] = result[category] or {}
		for key, override in pairs((config.Products and config.Products[category]) or {}) do
			if result[category][key] then
				if type(override) == "number" then result[category][key].id = override
				elseif type(override) == "table" and override.id ~= nil then result[category][key].id = override.id end
			end
		end
	end
	return result
end

function PlayerService.new(config, catalog, onChanged, rules, codes)
	local self = setmetatable({}, PlayerService)
	self.config, self.catalog, self.onChanged, self.rules = config, catalog, onChanged or function() end, rules
	-- Purchase funnel for the host's analytics: onPurchase(player, phase, kind, key, id)
	-- with phase "start" (a receipt is about to be applied), "granted" (applied
	-- for the first time), "replay" (already applied) or "cancelled" (the
	-- prompt closed without buying). Never affects what is granted.
	self.onPurchase = function() end
	-- Server-only promo codes (src/server/Codes.luau), keyed in capitals.
	self.codes = codes or config.Codes or {}
	assert(rules and rules.RollChest and rules.AbilityUpgrade, "PlayerService needs the shared Rules module")
	self.random = Random.new()
	self.memory = RunService:IsStudio() and config.StudioMemory == true
	self.closed = false
	self.records, self.gates, self.memoryProfiles, self.memoryBoards = {}, {}, {}, {}
	-- Open trades, one session shared by both userIds (see _trade).
	self.trades = {}
	self.boardCache, self.nameCache = {}, {}
	self.sessionId = (game.JobId ~= "" and game.JobId or "studio") .. ":" .. HttpService:GenerateGUID(false)
	self.leaseSeconds = math.max(60, config.ProfileLeaseSeconds or 180)
	self.retries = math.clamp(config.ProfileRetries or 3, 1, 5)
	self.products = productDefinitions(config, catalog)
	self.productById, self.heroProductById = {}, {}
	for _, product in pairs(self.products.Consumables) do
		-- A consumable pays Gold, or (the boost) buys time; anything else is not sold.
		local sells = integer(product.gold, 1, 100000000) or integer(product.boostSeconds, 1, 100000000) or product.seasonPass == true or type(product.heroPicks) == "table"
		if integer(product.id, 1, 9007199254740991) and sells then
			assert(not self.productById[product.id], "Duplicate developer product ID")
			self.productById[product.id] = product
		end
	end
	for heroId, product in pairs(self.products.Heroes) do
		if integer(product.id, 1, 9007199254740991) then
			assert(not self.productById[product.id] and not self.heroProductById[product.id], "Duplicate developer product ID")
			self.heroProductById[product.id] = heroId
		end
	end
	for key, product in pairs(self.products.Consumables) do product.key = product.key or key end
	if not self.memory then self.store = DataStoreService:GetDataStore(config.DataStoreName or "DoomPlayer_v1") end
	MarketplaceService.ProcessReceipt = function(receipt) return self:_receipt(receipt) end
	self:_watchCancelledProducts()
	self.passConnection = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			for key, product in pairs(self.products.Passes) do
				if product.id == passId then self:_purchaseEvent(player, "cancelled", "pass", key, passId) end
			end
			return
		end
		for key, product in pairs(self.products.Passes) do
			if product.id == passId and self.records[player.UserId] then
				self:_purchaseEvent(player, "granted", "pass", key, passId)
				task.spawn(function()
					local ok, owned = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId) end)
					local record = self.records[player.UserId]
					if ok and owned and record and record.player == player then record.passes[key] = true; self:_notify(player) end
				end)
			end
		end
	end)
	local interval = math.min(config.AutoSaveSeconds or 45, self.leaseSeconds / 3)
	task.spawn(function()
		while not self.closed do
			task.wait(math.max(interval, 10))
			if self.closed then break end
			for _, record in pairs(self.records) do
				local player = record.player
				task.spawn(function()
					if not record.closing then self:Save(player); self:_flushBoards(player) end
				end)
			end
		end
	end)
	return self
end

function PlayerService:_notify(player)
	local ok, problem = pcall(self.onChanged, player)
	if not ok then warn("[PlayerService] Snapshot callback failed: " .. tostring(problem)) end
end

function PlayerService:_withLock(userId, callback)
	local gate = self.gates[userId]
	if not gate then gate = { issued = 0, serving = 1 }; self.gates[userId] = gate end
	gate.issued += 1
	local ticket = gate.issued
	while ticket ~= gate.serving do task.wait() end
	local outcome = table.pack(pcall(callback))
	gate.serving += 1
	if gate.serving > gate.issued then self.gates[userId] = nil end
	if not outcome[1] then
		warn("[PlayerService] Transaction failed: " .. tostring(outcome[2]))
		return false, "Serviço de dados indisponível. Tente novamente. / Data service unavailable. Try again."
	end
	return table.unpack(outcome, 2, outcome.n)
end

function PlayerService:_update(userId, transform)
	local key = "p_" .. tostring(userId)
	local lastError
	for attempt = 1, self.retries do
		local ok, value = pcall(function()
			if self.memory then
				local nextValue = transform(copy(self.memoryProfiles[key]))
				if nextValue ~= nil then self.memoryProfiles[key] = copy(nextValue) end
				return nextValue
			end
			return self.store:UpdateAsync(key, transform)
		end)
		if ok then return true, value end
		lastError = value
		if attempt < self.retries then task.wait(0.4 * 2 ^ (attempt - 1)) end
	end
	warn("[PlayerService] UpdateAsync unavailable for " .. tostring(userId) .. ": " .. tostring(lastError))
	return false, nil
end

-- A new account speaks the language of the player's Roblox locale (Portuguese
-- for pt-*, English for everything else) until they pick one in Options.
local function localeLanguage(player)
	local ok, locale = pcall(function() return player.LocaleId end)
	if not ok or type(locale) ~= "string" or locale == "" then return nil end
	return string.sub(string.lower(locale), 1, 2) == "pt" and "pt" or "en"
end

function PlayerService:Load(player)
	if self.closed then return nil, "Servidor encerrando. / The server is closing." end
	local result, failure = self:_withLock(player.UserId, function()
		local existing = self.records[player.UserId]
		if existing and not existing.lost and not existing.closing and existing.profile._session and existing.profile._session.expires > os.time() then existing.player = player; return existing end
		if existing then existing.lost = true end
		local lockFailure
		local ok, persisted = self:_update(player.UserId, function(raw)
			local now = os.time()
			local profile = normalize(raw, now, self.catalog)
			local session = profile._session
			if session and session.id ~= self.sessionId and (session.expires or 0) > now then lockFailure = "Seu perfil ainda está em outro servidor. Aguarde alguns segundos. / Your profile is still on another server. Wait a few seconds."; return nil end
			lockFailure = nil
			profile._session = { id = self.sessionId, expires = now + self.leaseSeconds }
			refreshQuests(profile, now)
			if profile.settings.languageSet ~= true then profile.settings.language = localeLanguage(player) or profile.settings.language end
			profile.updatedAt = now
			return profile
		end)
		if not ok or not persisted then return nil, lockFailure or "Não foi possível carregar seu perfil. Nenhum dado foi substituído. / Could not load your profile. No data was replaced." end
		local record = { player = player, profile = persisted, passes = {}, closing = false, lost = false, lastSaved = os.time(), playMark = os.time(), randomRestricted = false }
		self.records[player.UserId] = record
		return record
	end)
	if not result then return nil, failure end
	self:_refreshPasses(player)
	self:_refreshPolicy(player)
	-- A trade left half-written by a closed server is settled before play.
	self:_settleTrades(player)
	task.spawn(function() self:_flushBoards(player) end)
	self:_notify(player)
	return self:Snapshot(player)
end

-- Roblox's per-account rules. Where paid random items are restricted, chests
-- are closed to the account (OpenChest refuses; it buys exact heroes with
-- BuyGuaranteed instead), so Gold bought with Robux can never become a random
-- item and every Robux product stays on sale. Paid item trading follows
-- IsPaidItemTradingAllowed; when the policy cannot be read, no trading.
function PlayerService:_refreshPolicy(player)
	local record = self.records[player.UserId]
	if not record or self.memory then return end
	local ok, policy = pcall(function()
		return game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player)
	end)
	local known = ok and type(policy) == "table"
	record.randomRestricted = known and policy.ArePaidRandomItemsRestricted == true
	record.tradeAllowed = known and policy.IsPaidItemTradingAllowed ~= false
end

function PlayerService:_refreshPasses(player)
	local record = self.records[player.UserId]
	if not record then return end
	for key, product in pairs(self.products.Passes) do
		if not self.memory and integer(product.id, 1, 9007199254740991) then
			local ok, owned = pcall(function() return MarketplaceService:UserOwnsGamePassAsync(player.UserId, product.id) end)
			if ok then record.passes[key] = owned == true end
		else record.passes[key] = false end
	end
end

function PlayerService:_transaction(player, mutate, operationId, options)
	options = options or {}
	operationId = operationId or HttpService:GenerateGUID(false)
	local ok, result = self:_withLock(player.UserId, function()
		local record = self.records[player.UserId]
		if not record or record.player ~= player or record.lost or (record.closing and not options.releasing and not options.force) then return false, "Perfil ainda não disponível. / Profile not available yet." end
		local rejected, value, lost = nil, nil, false
		-- Fixed before the callback, which UpdateAsync may run more than once.
		local elapsed = math.clamp(os.time() - (record.playMark or os.time()), 0, PLAYTIME_CAP)
		local saved, persisted = self:_update(player.UserId, function(raw)
			rejected, value, lost = nil, nil, false
			local now = os.time()
			local profile = normalize(raw, now, self.catalog)
			if not profile._session or profile._session.id ~= self.sessionId or profile._session.expires <= now then lost = true; rejected = "Sessão de dados expirada. Entre novamente. / Data session expired. Please rejoin."; return nil end
			local previous = profile._operations[operationId]
			if previous then value = copy(previous.result); return profile end
			refreshQuests(profile, now)
			local rewards, today = profile.rewards, math.floor(now / DAY)
			if rewards.playDay ~= today then rewards.playDay, rewards.playSeconds, rewards.playClaimed = today, 0, {} end
			rewards.playSeconds += elapsed
			local accepted, payload = mutate(profile, now, record)
			if accepted == false then rejected = payload or "Operação inválida."; return nil end
			value = payload
			profile.level = levelFor(profile.xp, 50, xpThreshold)
			profile.updatedAt = now
			if options.releasing then profile._session = nil else profile._session.expires = now + self.leaseSeconds end
			-- This bounded list only covers transport retries of a single queued
			-- transaction. Permanent awards and receipts have separate ledgers.
			profile._operations[operationId] = { result = copy(payload) }
			table.insert(profile._operationOrder, operationId)
			while #profile._operationOrder > 64 do profile._operations[table.remove(profile._operationOrder, 1)] = nil end
			return profile
		end)
		if lost then record.lost = true end
		if not saved then return false, "Não foi possível salvar. A operação pode ser repetida com segurança. / Could not save. The action can be safely repeated." end
		if not persisted then return false, rejected or "Alteração não confirmada. / Change not confirmed." end
		record.profile = persisted
		record.lastSaved = os.time()
		record.playMark = os.time()
		return true, value
	end)
	if ok and not options.silent then self:_notify(player) end
	return ok, result
end

-- Puts a hero into an account: a new hero starts its ability at rank one and
-- takes the first free slot of the loadout; one already owned turns into the
-- gold and mastery its rarity is worth. Returns whether it was a duplicate.
function PlayerService:_grantHero(profile, heroId, now, options)
	options = options or {}
	local hero = self.catalog.Heroes[heroId]
	local economy = hero.economy
	if profile.heroes[heroId] then
		local refund = options.refundGold or economy.duplicate.gold
		local mastery = options.mastery == nil and economy.duplicate.mastery or options.mastery
		profile.gold += refund
		local owned = profile.heroes[heroId]
		owned.xp += mastery
		owned.level = levelFor(owned.xp, 20, masteryThreshold)
		-- A duplicate is also a star, until the hero has them all, and cards for
		-- the hero's rank ladder.
		local before = math.clamp(math.floor(tonumber(owned.stars) or 0), 0, self.catalog.Stars.max)
		owned.stars = math.min(self.catalog.Stars.max, before + 1)
		local cards = economy.cards
		owned.copies = (owned.copies or 0) + cards
		return true, { gold = refund, mastery = mastery, stars = owned.stars, starGained = owned.stars > before, cards = cards, copies = owned.copies, rank = owned.rank or 1 }
	end
	profile.heroes[heroId] = { xp = 0, level = 1, stars = 0, rank = 1, copies = 0, alloc = { damage = 0, speed = 0, range = 0 } }
	profile.abilities[heroId] = 1
	if #profile.loadout < MAX_LOADOUT then table.insert(profile.loadout, heroId) end
	if tableCount(profile.heroes) >= #self.catalog.HeroOrder then achievement(profile, "allHeroes", "Coleção completa", "Full collection", now) end
	if hero.cosmicAchievement then achievement(profile, "mythic:" .. heroId, "Lenda cósmica: " .. hero.name.pt, "Cosmic legend: " .. hero.name.en, now) end
	return false, { gold = 0, mastery = 0 }
end

-- Rolls and grants one chest from a pair of random numbers drawn before the
-- transaction. Shared by the paid chests and by every reward that opens one.
function PlayerService:_openChest(profile, chestId, rolls, now)
	local chest = self.catalog.Chests[chestId]
	local owned = {}
	for id in pairs(chest.kind=="base" and profile.bases or profile.heroes) do owned[id] = true end
	local pity = profile.pity[chestId] or 0
	local outcome = self.rules.RollChest(chestId, rolls[1], rolls[2], pity, owned)
	if chest.pity then profile.pity[chestId] = outcome.top and 0 or pity + 1 end
	local duplicate, refund
	if chest.kind=="base" then
		duplicate=profile.bases[outcome.baseId]==true
		refund={gold=0,mastery=0}
		if duplicate then
			refund.gold=math.min(math.floor(chest.cost*0.4),self.catalog.Bases[outcome.baseId].economy.duplicate.gold)
			profile.gold+=refund.gold
		else profile.bases[outcome.baseId]=true end
	else duplicate, refund = self:_grantHero(profile, outcome.heroId, now) end
	-- The third roll decides the shine; a missing roll (older callers) never does.
	local shiny = false
	if chest.kind ~= "base" and rolls[3] and rolls[3] >= 1 - self.catalog.ShinyChance then
		local ownedHero = profile.heroes[outcome.heroId]
		if ownedHero and not ownedHero.shiny then ownedHero.shiny = true; shiny = true end
	end
	profile.stats.chests += 1
	for _, quest in pairs(profile.quests) do
		if quest.kind == "chests" and not quest.claimed then quest.progress = math.min(quest.target, quest.progress + 1) end
	end
	if profile.stats.chests == 1 then achievement(profile, "firstChest", "Primeiro baú", "First chest", now) end
	return { chestId = chestId, heroId = outcome.heroId, baseId = outcome.baseId, rarity = outcome.rarity, duplicate = duplicate,
		refundGold = refund.gold, refundMastery = refund.mastery, stars = refund.stars, starGained = refund.starGained, cards = refund.cards, copies = refund.copies, rank = refund.rank,
		shiny = shiny, pity = outcome.pity, cost = chest.cost }
end

-- Pays a reward table ({ gold, xp, chest, title }) into the profile.
-- The profile's season record for the current season: a new season starts
-- from zero, with nothing claimed.
function PlayerService:_seasonOf(profile)
	local id = self:_season()
	local season = profile.season
	if type(season) ~= "table" or season.id ~= id then
		season = { id = id, xp = 0, freeClaimed = 0, premiumClaimed = 0 }
		profile.season = season
	end
	return season
end

function PlayerService:_seasonXp(profile, amount)
	if amount > 0 then
		local season = self:_seasonOf(profile)
		season.xp = math.min(seasonMaxXp(self.catalog), season.xp + math.floor(amount))
	end
end

function PlayerService:_payReward(profile, reward, rolls, now, current)
	local paid = { gold = reward.gold or 0, xp = 0 }
	profile.gold += paid.gold
	if reward.xp then
		paid.xp = math.floor(reward.xp * (current.passes.training and 1.25 or 1))
		profile.xp += paid.xp
		self:_seasonXp(profile, paid.xp)
	end
	if reward.title then achievement(profile, reward.title.id, reward.title.pt, reward.title.en, now, "title") end
	if reward.chest then paid.chest = self:_openChest(profile, reward.chest, rolls, now) end
	if reward.heroPick and self.catalog.Rarities[reward.heroPick] then
		-- A hero of that rarity, chosen by the player afterwards (PickHero).
		profile.heroPicks = type(profile.heroPicks) == "table" and profile.heroPicks or {}
		profile.heroPicks[reward.heroPick] = math.floor(tonumber(profile.heroPicks[reward.heroPick]) or 0) + 1
		paid.heroPick = reward.heroPick
	end
	return paid
end

-- AFK farm pay. Never a client action: the lobby loop calls it after the
-- server itself has watched the commander stand in a farm for a minute.
-- paymentId names the minute being paid: retrying the same id after a lost
-- response is recognised by the transaction ledger and never pays twice.
-- A friend's invite pays twice. Who invited comes from Roblox's join data,
-- read by the server (a client never names its referrer). A brand-new account
-- (no match played, created within the window) gets the welcome Gold once in
-- its lifetime; the friend who invited, when in this server, gets the thanks
-- Gold up to a daily cap. Returns what was paid, or nil when nothing was.
function PlayerService:InviteBonus(player, inviterId)
	local invite = self.catalog.Rewards.invite
	inviterId = math.floor(tonumber(inviterId) or 0)
	if not invite or inviterId <= 0 or inviterId == player.UserId then return nil end
	local welcomed, gold = self:_transaction(player, function(profile, now)
		if profile.referredBy ~= nil then return false, "Bônus de convite já recebido. / Invite bonus already received." end
		if (profile.stats.matches or 0) > 0 or now - (tonumber(profile.createdAt) or now) > invite.newAccountSeconds then
			return false, "O bônus de convite é para contas novas. / The invite bonus is for new accounts."
		end
		profile.referredBy = inviterId
		profile.gold += invite.newcomerGold
		return true, invite.newcomerGold
	end)
	if not welcomed then return nil end
	local paid = { newcomer = gold }
	local friend = Players:GetPlayerByUserId(inviterId)
	if friend and self.records[inviterId] then
		local thanked, thanks = self:_transaction(friend, function(profile, now)
			local today = math.floor(now / DAY)
			local log = profile.invites
			if type(log) ~= "table" or log.day ~= today then
				log = { day = today, count = 0 }
				profile.invites = log
			end
			if (tonumber(log.count) or 0) >= invite.inviterDailyCap then return false, "Limite de convites de hoje. / Today's invite limit." end
			log.count = (tonumber(log.count) or 0) + 1
			profile.gold += invite.inviterGold
			return true, invite.inviterGold
		end)
		if thanked then paid.friend, paid.thanks = friend, thanks end
	end
	return paid
end

function PlayerService:GrantAfk(player, kind, minutes, paymentId)
	local reward = self.rules.AfkReward(kind, minutes)
	if not reward then return false, "Farm AFK inválido." end
	if paymentId ~= nil and not validId(paymentId) then return false, "Pagamento AFK inválido." end
	return self:_transaction(player, function(profile)
		profile.gold += reward.gold
		profile.xp += reward.xp
		profile.stats.goldEarned += reward.gold
		return true, { kind = kind, gold = reward.gold, xp = reward.xp }
	end, paymentId)
end

-- Cosmetic feats the lobby world notices (never Gold): each grants a title
-- once. The server decides that the feat happened; no client action exists.
local COSMETIC_FEATS = {
	parkour = { pt = "Explorador da Aurora", en = "Aurora explorer" },
}
function PlayerService:GrantCosmetic(player, featId)
	local feat = COSMETIC_FEATS[featId]
	if not feat then return false, "Conquista inválida." end
	local key = "feat:" .. featId
	local fresh = false
	local ok, result = self:_transaction(player, function(profile, now)
		fresh = profile.achievements[key] == nil
		if fresh then achievement(profile, key, feat.pt, feat.en, now, "title") end
		return true, { featId = featId, fresh = fresh }
	end)
	return ok, result
end

-- Studio memory mode only: own these heroes and field them as the squad, for
-- reviewing a hero without opening chests. Never touches saved data.
function PlayerService:_studioEdit(player, mutate)
	if not self.memory or self.closed then return false end
	local ok = self:_withLock(player.UserId, function()
		local record = self.records[player.UserId]
		if not record or record.player ~= player or record.lost or record.closing then return false end
		local profile = copy(record.profile)
		if mutate(profile) ~= true then return false end
		-- The next automatic save reads this in-process backing profile.
		-- Both copies must agree, otherwise a checkpoint discards the review.
		self.memoryProfiles["p_" .. tostring(player.UserId)] = copy(profile)
		record.profile = profile
		return true
	end)
	if ok then self:_notify(player) end
	return ok
end

function PlayerService:StudioGrant(player, heroIds)
	if not self.memory or type(heroIds) ~= "table" then return false end
	local loadout = {}
	for _, id in ipairs(heroIds) do
		if self.catalog.Heroes[id] and #loadout < 5 then
			table.insert(loadout, id)
		end
	end
	if #loadout == 0 then return false end
	return self:_studioEdit(player, function(profile)
		for _, id in ipairs(loadout) do
			profile.heroes[id] = profile.heroes[id] or { xp = 0, level = 1, stars = 0 }
			profile.abilities[id] = profile.abilities[id] or 1
		end
		profile.loadout = loadout
		return true
	end)
end

-- Review unlocks are deliberately ephemeral. A production profile cannot
-- reach this operation, even if it is called internally by mistake.
function PlayerService:StudioUnlock(player)
	if not self.memory then return false end
	return self:_studioEdit(player, function(profile)
		profile.tutorialComplete = true
		for id in pairs(self.catalog.Maps) do
			profile.campaign[id] = profile.campaign[id] or {}
			profile.campaign[id].normal = true
		end
		return true
	end)
end

function PlayerService:Get(player)
	return self:Snapshot(player)
end

function PlayerService:Snapshot(player)
	local record = self.records[player.UserId]
	if not record or record.lost or record.closing or record.player ~= player then return nil end
	local result = {}
	for _, key in ipairs(PUBLIC_FIELDS) do result[key] = copy(record.profile[key]) end
	result.passes = copy(record.passes)
	result.talentPoints = math.max(0, result.level - 1 - talentSpent(record.profile))
	result.paidRandomRestricted = record.randomRestricted == true
	local now = os.time()
	-- The welcome offer: the lobby shows the Starter Pack with a countdown for
	-- the first days of an account that has not bought it. The server owns the
	-- clock; the client only draws what is left.
	local pack = self.catalog.Products.Consumables.starterPack
	if pack and pack.offerSeconds and not record.profile.starterPack then
		local endsAt = (tonumber(record.profile.createdAt) or now) + pack.offerSeconds
		if endsAt > now then result.starterOfferEndsAt = endsAt end
	end
	result.rewards = self.rules.RewardsStatus(record.profile, now, math.clamp(now - (record.playMark or now), 0, PLAYTIME_CAP), record.passes.vip == true and not record.randomRestricted)
	result.tradeAllowed = record.tradeAllowed ~= false
	result.xpNext = result.level < 50 and xpThreshold(result.level + 1) or result.xp
	result.xpFloor = xpThreshold(result.level)
	result.season = self:_season()
	result.seasonStatus = self.rules.SeasonStatus(
		(record.profile.season and record.profile.season.id == result.season) and record.profile.season or { id = result.season, xp = 0, freeClaimed = 0, premiumClaimed = 0 },
		record.passes.season == true)
	result.seasonStatus.theme = copy(self.rules.SeasonTheme(result.season))
	result.seasonStatus.endsAt = (self.config.SeasonEpoch or 1789862400) + result.season * (self.config.SeasonDays or 60) * DAY
	-- The gift tab's badge counts the season's claim as one thing waiting.
	if result.seasonStatus.claimable > 0 and result.rewards then result.rewards.claimable += 1 end
	result.persistence = self.memory and "studio-memory" or "cloud"
	for _, hero in pairs(result.heroes) do
		hero.xpNext = hero.level < 20 and masteryThreshold(hero.level + 1) or hero.xp
		hero.xpFloor = masteryThreshold(hero.level)
		hero.awakened = hero.level >= 20
	end
	for _, quest in pairs(result.quests) do quest.heroIds = nil end
	result.titles = {}
	for id, unlocked in pairs(result.achievements) do
		if unlocked.kind == "title" then result.titles[id] = copy(unlocked.name) end
	end
	if record.passes.vip then result.titles.vip = copy(VIP_TITLE) end
	if result.title ~= "" and not result.titles[result.title] then result.title = "" end
	result.nextGoal = self.rules.NextGoal(result)
	if self.catalog.Market then
		-- Today's market, with what this account already took from it.
		local market = self.rules.DailyMarket(math.floor(now / DAY))
		local slot = type(record.profile.market) == "table" and record.profile.market.day == market.day and record.profile.market or nil
		for _, offer in ipairs(market.offers) do offer.bought = slot ~= nil and slot.bought[offer.heroId] == true end
		result.market = market
	end
	if self.catalog.Trade then
		result.trade = self:_tradeView(player.UserId)
		result.tradesLeft = math.max(0, self.catalog.Trade.perDay - tradesToday(record.profile, now))
		-- A trade that ended (done or cancelled) is told once, then forgotten.
		if record.tradeNotice then result.tradeNotice = record.tradeNotice; record.tradeNotice = nil end
	end
	-- A friend's gift that just landed is told once, then it waits on the gifts page.
	if record.giftNotice then result.giftNotice = record.giftNotice; record.giftNotice = nil end
	return result
end

--==============================================================================
-- Trading between friends: one hero for one hero, never Gold. The session
-- lives in memory (self.trades, one table for both sides) until both confirm;
-- then each account commits its half under its own lock, and a failed second
-- half undoes the first. Every rule is checked again at commit time.
--==============================================================================
-- A chest for a Roblox friend in this server, once per UTC day. The sender's
-- day is spent in its own transaction, the friend's chest lands in theirs;
-- when the second half fails the day is given back.
function PlayerService:_sendGift(player, record, payload)
	local gift = self.catalog.Rewards.gift
	if not gift then return false, "Presentes desligados. / Gifts are off." end
	local targetId = integer(payload.userId, 1, 9007199254740991) and math.floor(payload.userId)
	local target = targetId and self.records[targetId]
	if not target or targetId == player.UserId or target.closing or target.lost then return false, "Esse jogador não está aqui. / That player is not here." end
	local friends = false
	pcall(function() friends = player:IsFriendsWith(targetId) == true end)
	if not friends then return false, "Presentes só entre amigos do Roblox. / Gifts are only between Roblox friends." end
	local today = math.floor(os.time() / DAY)
	if record.profile.rewards.giftDay == today then return false, "Você já enviou o presente de hoje. / You already sent today's gift." end
	local spent, why = self:_transaction(player, function(profile, now)
		if profile.rewards.giftDay == math.floor(now / DAY) then return false, "Você já enviou o presente de hoje. / You already sent today's gift." end
		profile.rewards.giftDay = math.floor(now / DAY)
		return true, { to = targetId }
	end, nil, { silent = true })
	if not spent then return false, why end
	local landed = self:_transaction(target.player, function(profile)
		profile.rewards.giftsPending = math.floor(tonumber(profile.rewards.giftsPending) or 0) + 1
		return true, { from = player.UserId }
	end, nil, { silent = true })
	if not landed then
		self:_transaction(player, function(profile) profile.rewards.giftDay = -1; return true end, nil, { silent = true })
		return false, "Não foi possível entregar agora. Tente de novo. / Could not deliver now. Try again."
	end
	target.giftNotice = { from = player.DisplayName or player.Name }
	self:_notify(target.player)
	self:_notify(player)
	return true, { to = targetId }
end

function PlayerService:_tradeable(profile, partnerProfile, heroId)
	local hero = type(heroId) == "string" and self.catalog.Heroes[heroId]
	if not hero or not profile.heroes[heroId] then return "Você não tem este herói. / You do not own this hero." end
	for _, entry in ipairs(type(profile._trades) == "table" and profile._trades or {}) do
		if entry.pending and entry.got == heroId then return "Esta troca ainda está sendo confirmada. / This trade is still being confirmed." end
	end
	if hero.starter then return "Heróis iniciais não são trocados. / Starter heroes cannot be traded." end
	for _, id in ipairs(profile.loadout or {}) do
		if id == heroId then return "Tire o herói da equipe antes de trocar. / Remove the hero from your team before trading." end
	end
	if partnerProfile and partnerProfile.heroes[heroId] then return "Seu amigo já tem este herói. / Your friend already owns this hero." end
	return nil
end

function PlayerService:_tradeView(userId)
	local session = self.trades[userId]
	if not session then return nil end
	local partnerId = session.from == userId and session.to or session.from
	local partner = self.records[partnerId]
	local mine, theirs = session.offers[userId], session.offers[partnerId]
	return {
		id = session.id, stage = session.stage, partnerId = partnerId,
		partnerName = partner and (partner.player.DisplayName or partner.player.Name) or "?",
		invited = session.stage == "invited" and session.to == userId,
		mine = mine, theirs = theirs,
		myConfirm = session.confirmed[userId] == true, theirConfirm = session.confirmed[partnerId] == true,
		unequal = (mine ~= nil and theirs ~= nil and self.catalog.Heroes[mine].rarity ~= self.catalog.Heroes[theirs].rarity) or false,
		lockedUntil = session.changedAt + self.catalog.Trade.lockSeconds,
	}
end

-- Ends a session for both sides; each is told once through its snapshot.
function PlayerService:_endTrade(session, kind, got)
	for _, userId in ipairs({ session.from, session.to }) do
		if self.trades[userId] == session then self.trades[userId] = nil end
		local record = self.records[userId]
		if record then
			record.tradeNotice = { kind = kind, heroId = got and got[userId] or nil }
			if not record.closing then self:_notify(record.player) end
		end
	end
end

function PlayerService:_trade(player, record, action, payload)
	local config = self.catalog.Trade
	if not config or self.closed then return false, "Trocas desligadas. / Trading is off." end
	local userId, now = player.UserId, os.time()
	local session = self.trades[userId]
	if action == "TradeOffer" and record.tradeAllowed == false then return false, "Trocas não estão disponíveis para esta conta. / Trading is not available for this account." end
	if action == "TradeOffer" then
		if session then return false, "Você já está em uma troca. / You are already trading." end
		local targetId = integer(payload.userId, 1, 9007199254740991) and math.floor(payload.userId)
		local target = targetId and self.records[targetId]
		if not target or targetId == userId or target.closing or target.lost then return false, "Esse jogador não está aqui. / That player is not here." end
		if self.trades[targetId] then return false, "Seu amigo já está em outra troca. / Your friend is already trading." end
		if target.tradeAllowed == false then return false, "Trocas não estão disponíveis para a conta do seu amigo. / Trading is not available for your friend's account." end
		local friends = false
		pcall(function() friends = player:IsFriendsWith(targetId) == true end)
		if not friends then return false, "Trocas só entre amigos do Roblox. / Trades are only between Roblox friends." end
		if tradesToday(record.profile, now) >= config.perDay or tradesToday(target.profile, now) >= config.perDay then return false, "Limite de trocas de hoje atingido. / Today's trade limit was reached." end
		session = { id = HttpService:GenerateGUID(false), from = userId, to = targetId, stage = "invited", offers = {}, confirmed = {}, changedAt = now, createdAt = now }
		self.trades[userId], self.trades[targetId] = session, session
		self:_notify(target.player)
		self:_notify(player)
		return true, { trade = self:_tradeView(userId) }
	end
	if not session then return false, "Nenhuma troca aberta. / No trade open." end
	local partnerId = session.from == userId and session.to or session.from
	local partner = self.records[partnerId]
	if not partner or partner.closing or partner.lost then
		self:_endTrade(session, "cancelled")
		return false, "Seu amigo saiu. / Your friend left."
	end
	-- Replies never carry a snapshot: the pushes from _notify/_endTrade do, and
	-- a snapshot here would swallow the one-time notice before it was shown.
	if action == "TradeCancel" then
		self:_endTrade(session, "cancelled")
		return true, {}
	elseif action == "TradeAccept" then
		if session.stage ~= "invited" or session.to ~= userId then return false, "Nada para aceitar. / Nothing to accept." end
		session.stage, session.changedAt = "open", now
	elseif action == "TradeSet" then
		if session.stage ~= "open" then return false, "A troca ainda não foi aceita. / The trade was not accepted yet." end
		if payload.heroId ~= nil then
			local why = self:_tradeable(record.profile, partner.profile, payload.heroId)
			if why then return false, why end
		end
		-- Any change clears both confirms and restarts the wait.
		session.offers[userId], session.confirmed, session.changedAt = payload.heroId, {}, now
	elseif action == "TradeConfirm" then
		if session.stage ~= "open" then return false, "A troca ainda não foi aceita. / The trade was not accepted yet." end
		local mine, theirs = session.offers[userId], session.offers[partnerId]
		if not mine or not theirs then return false, "Os dois precisam oferecer um herói. / Both must offer a hero." end
		if now < session.changedAt + config.lockSeconds then return false, "Espere um instante depois da última mudança. / Wait a moment after the last change." end
		if self.catalog.Heroes[mine].rarity ~= self.catalog.Heroes[theirs].rarity and payload.acceptUnequal ~= true then
			return false, "Troca desigual: raridades diferentes. Confirme de novo para aceitar. / Unequal trade: different rarities. Confirm again to accept."
		end
		session.confirmed[userId] = true
		if session.confirmed[partnerId] then
			local ok, why = self:_executeTrade(session)
			if not ok then return false, why end
			return true, {}
		end
	end
	self:_notify(partner.player)
	self:_notify(player)
	return true, { trade = self:_tradeView(userId) }
end

function PlayerService:_executeTrade(session)
	local a, b = self.records[session.from], self.records[session.to]
	local giveA, giveB = session.offers[session.from], session.offers[session.to]
	-- The hero travels as it is: mastery, stars, rank, cards, shiny, ability rank.
	local recA, rankA = copy(a.profile.heroes[giveA]), a.profile.abilities[giveA] or 1
	local recB, rankB = copy(b.profile.heroes[giveB]), b.profile.abilities[giveB] or 1
	-- `first`: the half written first is marked pending with a copy of the hero
	-- it gave, so it can be undone if the partner's half never lands.
	local function move(profile, now, give, get, getRecord, getRank, withId, first)
		local why = self:_tradeable(profile, nil, give)
		if why then return false, why end
		if profile.heroes[get] then return false, "Você já tem este herói. / You already own this hero." end
		if tradesToday(profile, now) >= self.catalog.Trade.perDay then return false, "Limite de trocas de hoje atingido. / Today's trade limit was reached." end
		local entry = { id = session.id, with = withId, gave = give, got = get, at = now }
		if first then entry.pending, entry.gaveRecord, entry.gaveRank = true, copy(profile.heroes[give]), profile.abilities[give] or 1 end
		profile.heroes[give], profile.abilities[give] = nil, nil
		profile.heroes[get], profile.abilities[get] = copy(getRecord), getRank
		profile._trades = type(profile._trades) == "table" and profile._trades or {}
		table.insert(profile._trades, entry)
		while #profile._trades > self.catalog.Trade.keep do table.remove(profile._trades, 1) end
		return true, { gave = give, got = get }
	end
	if a.closing or b.closing or a.lost or b.lost then self:_endTrade(session, "cancelled"); return false, "Seu amigo saiu. / Your friend left." end
	local okA, whyA = self:_transaction(a.player, function(profile, now) return move(profile, now, giveA, giveB, recB, rankB, session.to, true) end, "trade:" .. session.id .. ":" .. tostring(session.from), { silent = true })
	if not okA then self:_endTrade(session, "cancelled"); return false, whyA end
	local okB, whyB = self:_transaction(b.player, function(profile, now) return move(profile, now, giveB, giveA, recA, rankA, session.from, false) end, "trade:" .. session.id .. ":" .. tostring(session.to), { silent = true })
	-- Settle the first half against what the partner's store holds now: kept
	-- if the second half landed, undone if it did not (or at the next load).
	self:_settleTrades(a.player)
	if not okB then
		self:_endTrade(session, "cancelled")
		return false, whyB
	end
	self:_endTrade(session, "done", { [session.from] = giveB, [session.to] = giveA })
	return true
end

-- The latest stored copy of an account, read through UpdateAsync with a
-- transform that writes nothing (GetAsync may serve a cached copy). nil when
-- the store could not be read, false when the account has no profile.
function PlayerService:_peekProfile(userId)
	local seen
	local ok = self:_update(userId, function(raw) seen = raw ~= nil and copy(raw) or false; return nil end)
	if not ok then return nil end
	return seen
end

-- A trade is written one account at a time. The first half carries a pending
-- mark and a copy of the hero it gave. Settling looks the partner up in the
-- store: their half landed -> the mark is cleared; it did not -> the first
-- half is undone (the hero comes back, the received one goes). An account
-- that left before settling is settled at its next load. No duplicates.
function PlayerService:_settleTrades(player)
	local record = self.records[player.UserId]
	if not record then return end
	for _, entry in ipairs(type(record.profile._trades) == "table" and record.profile._trades or {}) do
		if entry.pending then
			local theirs = self:_peekProfile(entry.with)
			if theirs ~= nil then
				local landed = false
				for _, other in ipairs(type(theirs) == "table" and type(theirs._trades) == "table" and theirs._trades or {}) do
					if other.id == entry.id then landed = true end
				end
				self:_transaction(player, function(profile)
					for _, mine in ipairs(type(profile._trades) == "table" and profile._trades or {}) do
						if mine.id == entry.id and mine.pending then
							if not landed then
								if profile.heroes[mine.got] and not profile.heroes[mine.gave] and type(mine.gaveRecord) == "table" then
									profile.heroes[mine.gave], profile.abilities[mine.gave] = copy(mine.gaveRecord), mine.gaveRank or 1
									profile.heroes[mine.got], profile.abilities[mine.got] = nil, nil
									for index = #profile.loadout, 1, -1 do if profile.loadout[index] == mine.got then table.remove(profile.loadout, index) end end
								end
								mine.undone = true
							end
							mine.pending, mine.gaveRecord, mine.gaveRank = nil, nil, nil
						end
					end
					return true
				end, "trade:" .. entry.id .. ":settle", { silent = true, force = true })
			end
		end
	end
end

function PlayerService:_validHeroes(profile, heroes)
	return validList(heroes, MAX_LOADOUT, function(id) return self.catalog.Heroes[id] ~= nil and profile.heroes[id] ~= nil end, false)
end

function PlayerService:Handle(player, action, payload, inLobby)
	if not ACTIONS[action] then return false, false, "Ação não reconhecida. / Unknown action." end
	if type(payload) ~= "table" then return true, false, "Dados inválidos." end
	local record = self.records[player.UserId]
	if not record or record.player ~= player or record.closing or record.lost then return true, false, "Aguarde o carregamento do perfil. / Wait for your profile to load." end
	if not inLobby and action ~= "Settings" then return true, false, "Esta ação só está disponível no lobby. / This action is only available in the lobby." end
	if action == "ProductInfo" then
		local ok, result = self:_productInfo(payload, record)
		return true, ok, result
	elseif action == "Leaderboard" then
		if not self.catalog.Maps[payload.mapId] or not integer(payload.size, 1, 4) then return true, false, "Placar inválido." end
		local period = payload.period or ("s" .. tostring(self:_season()))
		local rows, failure = self:Leaderboard(payload.mapId, payload.size, period, payload.modeId)
		if not rows then return true, false, failure end
		local key = self:_boardKey(payload.mapId, payload.size, period, payload.modeId)
		return true, true, { rows = rows, season = self:_season(), period = period, mapId = payload.mapId, size = payload.size, version = tostring(self.config.BalanceVersion or "1"), personal = record.profile.best[key] or 0 }
	elseif string.sub(action, 1, 5) == "Trade" then
		local ok, result = self:_trade(player, record, action, payload)
		return true, ok, result
	elseif action == "SendGift" then
		local ok, result = self:_sendGift(player, record, payload)
		return true, ok, result
	end
	local code, codeEntry
	if action == "RedeemCode" then
		local now = os.time()
		local window = record.codeWindow
		if not window or now - window.start >= 60 then window = { start = now, misses = 0 }; record.codeWindow = window end
		if window.misses >= CODE_MISSES_PER_MINUTE then return true, false, "Muitas tentativas. Espere um minuto. / Too many tries. Wait a minute." end
		code = type(payload.code) == "string" and string.upper((string.gsub(payload.code, "%s", ""))) or ""
		codeEntry = #code >= 3 and #code <= 32 and not string.find(code, "[^%w]") and self.codes[code] or nil
		if not codeEntry or (codeEntry.expires and now >= codeEntry.expires) then
			window.misses += 1
			return true, false, "Código inválido ou expirado. / Invalid or expired code."
		end
		if (record.profile.codes or {})[code] then return true, false, "Você já usou este código. / You already used this code." end
	elseif action == "ClaimGroupReward" then
		local groupId = tonumber(self.config.GroupId) or 0
		if groupId <= 0 then return true, false, "Recompensa de grupo indisponível. / No group reward here." end
		if record.profile.rewards and record.profile.rewards.groupClaimed then return true, false, "Recompensa do grupo já resgatada. / Group reward already claimed." end
		-- Roblox answers this from its own servers; a failure counts as "not yet".
		local ok, member = pcall(function() return player:IsInGroup(groupId) end)
		if not ok or member ~= true then return true, false, "Entre no grupo do jogo e tente de novo. / Join the game's group, then try again." end
	end
	-- A chest's two random numbers are drawn once, here. UpdateAsync may run the
	-- callback below several times, and every run must reach the same hero.
	local rolls = CHEST_ACTIONS[action] and { self.random:NextNumber(), self.random:NextNumber(), self.random:NextNumber() } or nil
	-- Several chests in one request: the count is a whole number from 1 to the
	-- cap, and every chest gets its own three numbers drawn here, up front.
	local openCount, rollSets = 1, nil
	if action == "OpenChest" and payload.count ~= nil then
		if not integer(payload.count, 1, self.catalog.MaxChestsAtOnce) then return true, false, "Quantidade de baús inválida. / Invalid chest count." end
		openCount = payload.count
		if openCount > 1 then
			rollSets = {}
			for index = 1, openCount do rollSets[index] = { self.random:NextNumber(), self.random:NextNumber(), self.random:NextNumber() } end
		end
	end
	local ok, result = self:_transaction(player, function(profile, now, current)
		if action == "UpgradeTalent" then
			local node = type(payload.talentId) == "string" and self.catalog.Talents[payload.talentId]
			if not node then return false, "Talento inválido. / Invalid talent." end
			local rank = profile.talents[payload.talentId] or 0
			if payload.expectedRank ~= rank then return false, "Árvore atualizada. Tente novamente. / Tree changed; try again." end
			if rank >= node.maxRank then return false, "Talento no máximo. / Talent maxed." end
			if profile.level - 1 - talentSpent(profile) < 1 then return false, "Ganhe um nível para obter outro ponto. / Level up to earn another point." end
			if node.parent and (profile.talents[node.parent] or 0) < node.requiredRank then return false, "Evolua primeiro o talento anterior. / Upgrade the previous talent first." end
			profile.talents[payload.talentId] = rank + 1
		elseif action == "ResetTalents" then
			profile.talents = {}
		elseif action == "EquipBase" then
			if type(payload.baseId)~="string" or not self.catalog.Bases[payload.baseId] or profile.bases[payload.baseId]~=true then return false,"Base não desbloqueada. / Base not unlocked." end
			profile.equippedBase=payload.baseId
		elseif action == "BuyGuaranteed" then
			-- Only for accounts that cannot open chests: one exact hero or base
			-- at the Gold it costs on average to draw it (Rules.GuaranteedPrice).
			if not record.randomRestricted then return false, "Use os baús para recrutar. / Use chests to recruit." end
			local itemId = payload.itemId
			local price = type(itemId) == "string" and self.rules.GuaranteedPrice(itemId)
			if not price then return false, "Item inválido. / Invalid item." end
			local isHero = self.catalog.Heroes[itemId] ~= nil
			if (isHero and profile.heroes[itemId]) or (not isHero and profile.bases[itemId]) then return false, "Você já tem este item. / You already own this." end
			if profile.gold < price then return false, "Ouro insuficiente. / Not enough Gold." end
			profile.gold -= price
			if isHero then self:_grantHero(profile, itemId, now) else profile.bases[itemId] = true end
			return true, { itemId = itemId, price = price }
		elseif action == "PickHero" then
			-- A bundle's credit: any hero of the paid rarity, the player's choice.
			-- A hero already owned pays as a duplicate (star, Gold, cards).
			local hero = type(payload.heroId) == "string" and self.catalog.Heroes[payload.heroId]
			if not hero then return false, "Herói inválido. / Invalid hero." end
			local picks = type(profile.heroPicks) == "table" and profile.heroPicks or {}
			local left = math.floor(tonumber(picks[hero.rarity]) or 0)
			if left <= 0 then return false, "Você não tem uma escolha de herói desta raridade. / You have no hero pick of this rarity." end
			picks[hero.rarity] = left - 1
			profile.heroPicks = picks
			local duplicate, paid = self:_grantHero(profile, payload.heroId, now, {})
			return true, { heroId = payload.heroId, rarity = hero.rarity, left = left - 1, duplicate = duplicate, gold = paid and paid.gold or 0 }
		elseif action == "BuyMarket" then
			-- Today's market (Rules.DailyMarket): one of each offer per account per day.
			local day = math.floor(now / DAY)
			local offer
			for _, entry in ipairs(self.rules.DailyMarket(day).offers) do if entry.heroId == payload.heroId then offer = entry end end
			if not offer then return false, "Este herói não está à venda hoje. / This hero is not on sale today." end
			if profile.heroes[offer.heroId] then return false, "Você já tem este herói. / You already own this hero." end
			local slot = type(profile.market) == "table" and profile.market or { day = 0, bought = {} }
			if slot.day ~= day then slot = { day = day, bought = {} } end
			if slot.bought[offer.heroId] then return false, "Esgotado por hoje. / Sold out for today." end
			if profile.gold < offer.price then return false, "Ouro insuficiente. / Not enough Gold." end
			profile.gold -= offer.price
			slot.bought[offer.heroId] = true
			profile.market = slot
			self:_grantHero(profile, offer.heroId, now)
			return true, { heroId = offer.heroId, price = offer.price }
		elseif action == "OpenChest" then
			if record.randomRestricted then return false, "Baús indisponíveis para esta conta. / Chests unavailable for this account." end
			local chest = type(payload.chestId) == "string" and self.catalog.Chests[payload.chestId]
			if not chest then return false, "Baú inválido. / Invalid chest." end
			if profile.gold < chest.cost then return false, "Ouro insuficiente. / Not enough Gold." end
			-- Opening several at once: the count was checked before the draw, every
			-- chest has its own committed rolls, and the Gold is taken in one piece.
			local count = openCount
			if profile.gold < chest.cost * count then return false, "Ouro insuficiente. / Not enough Gold." end
			profile.gold -= chest.cost * count
			-- The client never supplies or sees a roll, only the committed result.
			if count == 1 then return true, self:_openChest(profile, payload.chestId, rolls, now) end
			local batch = {}
			for index = 1, count do table.insert(batch, self:_openChest(profile, payload.chestId, rollSets[index], now)) end
			local last = copy(batch[#batch])
			last.batch, last.count, last.cost = batch, count, chest.cost * count
			return true, last
		elseif action == "RankUpHero" then
			local id = type(payload.heroId) == "string" and payload.heroId
			local owned = id and profile.heroes[id]
			if not owned then return false, "Herói não encontrado. / Hero not found." end
			if payload.expectedRank ~= owned.rank then return false, "A carta mudou. Tente de novo. / The card changed; try again." end
			local cost = self.rules.CardRankCost(owned.rank)
			if (owned.copies or 0) < cost.copies then return false, "Faltam cartas deste herói. / Not enough cards for this hero." end
			if profile.gold < cost.gold then return false, "Ouro insuficiente. / Not enough Gold." end
			owned.copies -= cost.copies
			profile.gold -= cost.gold
			owned.rank += 1
			return true, { heroId = id, rank = owned.rank, copies = owned.copies, points = self.rules.CardPoints(owned.rank), cost = cost }
		elseif action == "SetHeroPoints" then
			local id = type(payload.heroId) == "string" and payload.heroId
			local owned = id and profile.heroes[id]
			if not owned then return false, "Herói não encontrado. / Hero not found." end
			-- Refused, never clamped: more points than the rank earned is a bad request.
			local clean = self.rules.CleanPoints(owned.rank, payload)
			if not clean then return false, "Pontos inválidos. / Invalid points." end
			owned.alloc = clean
			return true, { heroId = id, alloc = clean }
		elseif action == "ClaimFreeChest" then
			local state, config = profile.rewards, self.catalog.Rewards.freeChest
			if now < state.freeChestAt then return false, "O baú grátis ainda não está pronto. / The free chest is not ready yet." end
			-- A VIP's chest comes back sooner (Catalog.Products.Passes.vip.freeChestScale).
			-- Not where paid random items are restricted: a paid pass must not buy more chests.
			state.freeChestAt = now + self.rules.FreeChestCooldown(current.passes.vip == true and not current.randomRestricted)
			return true, { chest = self:_openChest(profile, config.chestId, rolls, now), gold = 0, xp = 0 }
		elseif action == "ClaimGift" then
			-- A chest a friend sent (SendGift): opened here, one per claim.
			local state, gift = profile.rewards, self.catalog.Rewards.gift
			local pending = math.floor(tonumber(state.giftsPending) or 0)
			if not gift or pending <= 0 then return false, "Nenhum presente esperando. / No gift waiting." end
			state.giftsPending = pending - 1
			return true, { chest = self:_openChest(profile, gift.chestId, rolls, now), gold = 0, xp = 0, gift = true }
		elseif action == "ClaimLogin" then
			local claim = self.rules.LoginClaim(profile.rewards, now)
			if not claim then return false, "A recompensa de hoje já foi resgatada. / Today's reward was already claimed." end
			profile.rewards.loginDay, profile.rewards.loginStreak = claim.today, claim.streak
			local paid = self:_payReward(profile, claim.reward, rolls, now, current)
			paid.streak, paid.day = claim.streak, claim.index
			return true, paid
		elseif action == "ClaimPlaytime" then
			local gift = integer(payload.index, 1, #self.catalog.Rewards.playtime) and self.catalog.Rewards.playtime[payload.index]
			if not gift then return false, "Presente inválido. / Invalid gift." end
			local state = profile.rewards
			if state.playClaimed[payload.index] then return false, "Presente já resgatado. / Gift already claimed." end
			if state.playSeconds < gift.minutes * 60 then return false, "Ainda falta tempo para este presente. / This gift is not ready yet." end
			state.playClaimed[payload.index] = true
			return true, self:_payReward(profile, gift, rolls, now, current)
		elseif action == "RedeemCode" then
			if profile.codes[code] then return false, "Você já usou este código. / You already used this code." end
			profile.codes[code] = now
			local paid = self:_payReward(profile, codeEntry, rolls, now, current)
			paid.code = code
			return true, paid
		elseif action == "ClaimSeason" then
			local season = self:_seasonOf(profile)
			local status = self.rules.SeasonStatus(season, current.passes.season == true)
			if status.claimable == 0 then return false, "Nada para resgatar na temporada. / Nothing to claim in the season." end
			local total = { gold = 0, chests = {}, titles = {}, heroes = {} }
			local salt = 0
			local function pay(level, track)
				local reward = self.rules.SeasonReward(level, track, season.id)
				profile.gold += reward.gold
				total.gold += reward.gold
				if reward.hero then
					-- The season's hero, shiny: a duplicate still pays its Gold, star and cards.
					local duplicate, paid = self:_grantHero(profile, reward.hero, now, {})
					profile.heroes[reward.hero].shiny = true
					table.insert(total.heroes, { heroId = reward.hero, shiny = true, duplicate = duplicate, gold = paid and paid.gold or 0 })
					total.gold += paid and paid.gold or 0
				end
				if reward.title then
					achievement(profile, reward.title.id, reward.title.pt, reward.title.en, now, "title")
					table.insert(total.titles, copy(reward.title))
				end
				if reward.chest and track == "premium" and current.randomRestricted then
					-- The premium track is paid for: where paid random items are
					-- restricted, the chest becomes the Gold it would have cost.
					local worth = (self.catalog.Chests[reward.chest] or {}).cost or 0
					profile.gold += worth
					total.gold += worth
				elseif reward.chest then
					-- One roll set per chest, all derived from the pre-drawn rolls so that a
					-- replayed transaction opens the same chests.
					salt += 1
					local derived = { (rolls[1] + salt * 0.61803398875) % 1, (rolls[2] + salt * 0.41421356237) % 1, (rolls[3] + salt * 0.73205080757) % 1 }
					table.insert(total.chests, self:_openChest(profile, reward.chest, derived, now))
				end
			end
			for level = season.freeClaimed + 1, status.level do pay(level, "free") end
			season.freeClaimed = status.level
			if status.owned then
				for level = season.premiumClaimed + 1, status.level do pay(level, "premium") end
				season.premiumClaimed = status.level
			end
			total.level, total.claimed = status.level, status.claimable
			return true, total
		elseif action == "ClaimGroupReward" then
			if profile.rewards.groupClaimed then return false, "Recompensa do grupo já resgatada. / Group reward already claimed." end
			profile.rewards.groupClaimed = true
			return true, self:_payReward(profile, self.catalog.Rewards.group, rolls, now, current)
		elseif action == "ClaimMilestone" then
			local milestone = integer(payload.index, 1, #self.catalog.Rewards.collection) and self.catalog.Rewards.collection[payload.index]
			if not milestone then return false, "Meta inválida. / Invalid milestone." end
			local state = profile.rewards
			if state.collection[payload.index] then return false, "Meta já resgatada. / Milestone already claimed." end
			if tableCount(profile.heroes) < milestone.count then return false, "Você ainda não tem heróis suficientes. / You do not own enough heroes yet." end
			state.collection[payload.index] = true
			return true, self:_payReward(profile, milestone, rolls, now, current)
		elseif action == "UpgradeAbility" then
			local hero = type(payload.heroId) == "string" and self.catalog.Heroes[payload.heroId]
			local owned = hero and profile.heroes[payload.heroId]
			if not owned then return false, "Você ainda não possui este herói. / You do not own this hero yet." end
			local rank = profile.abilities[payload.heroId] or 1
			if payload.expectedRank ~= rank then return false, "A habilidade mudou. Tente novamente. / The ability changed; try again." end
			local upgrade = self.rules.AbilityUpgrade(hero, rank)
			if not upgrade then return false, "Habilidade no nível máximo. / Ability is at its maximum." end
			if owned.level < upgrade.mastery then return false, "Requer maestria " .. tostring(upgrade.mastery) .. " com este herói. / Requires mastery " .. tostring(upgrade.mastery) .. " with this hero." end
			if profile.gold < upgrade.cost then return false, "Ouro insuficiente. / Not enough Gold." end
			profile.gold -= upgrade.cost
			profile.abilities[payload.heroId] = upgrade.rank
			return true, { heroId = payload.heroId, rank = upgrade.rank, cost = upgrade.cost }
		elseif action == "SetLoadout" then
			-- The order is the point: the hero in slot one is the one whose
			-- ability the player will fight with.
			if not self:_validHeroes(profile, payload.heroes) then return false, "Escolha até cinco heróis diferentes que você possui. / Choose up to five different heroes you own." end
			profile.loadout = copy(payload.heroes)
		elseif action == "Settings" then
			if payload.language ~= nil and payload.language ~= "pt" and payload.language ~= "en" then return false, "Idioma inválido." end
			if payload.lowFX ~= nil and type(payload.lowFX) ~= "boolean" then return false, "Configuração inválida." end
			if payload.shake ~= nil and type(payload.shake) ~= "boolean" then return false, "Configuração inválida." end
			if payload.music ~= nil and type(payload.music) ~= "boolean" then return false, "Configuração inválida." end
			for _, key in ipairs({ "effects", "interface", "autoSkip", "fastForward" }) do
				if payload[key] ~= nil and type(payload[key]) ~= "boolean" then return false, "Configuração inválida." end
			end
			for _, key in ipairs({ "language", "lowFX", "shake", "music", "effects", "interface", "autoSkip", "fastForward" }) do if payload[key] ~= nil then profile.settings[key] = payload[key] end end
			-- Once the player picks a language, the locale no longer decides it.
			if payload.language ~= nil then profile.settings.languageSet = true end
		elseif action == "SetTitle" then
			local id = payload.titleId
			if id == nil or id == "" then
				profile.title = ""
			elseif not validId(id) then
				return false, "Título inválido. / Invalid title."
			elseif id == "vip" then
				if not current.passes.vip then return false, "Este título acompanha o pacote VIP. / This title comes with the VIP pack." end
				profile.title = id
			else
				local unlocked = profile.achievements[id]
				if type(unlocked) ~= "table" or unlocked.kind ~= "title" then return false, "Você ainda não conquistou este título. / You have not earned this title yet." end
				profile.title = id
			end
		elseif action == "ClaimQuest" then
			local quest = validId(payload.questId) and profile.quests[payload.questId]
			if not quest or quest.expiresAt <= now or quest.claimed or quest.progress < quest.target then return false, "Missão incompleta, resgatada ou expirada. / Mission incomplete, claimed or expired." end
			quest.claimed = true
			profile.gold += quest.gold
			local questXp = math.floor(quest.xp * (current.passes.training and 1.25 or 1))
			profile.xp += questXp
			self:_seasonXp(profile, questXp)
		end
		return true
	end)
	local snapshot = ok and self:Snapshot(player) or nil
	-- A chest or an ability upgrade also reports what just happened, so the
	-- client can play the reveal instead of guessing from a diff.
	if snapshot and type(result) == "table" and (action == "OpenChest" or action == "UpgradeAbility" or action == "RankUpHero" or action == "SetHeroPoints" or action == "RedeemCode" or action == "PickHero" or action == "BuyMarket" or action:sub(1, 5) == "Claim") then snapshot.result = result end
	return true, ok, ok and snapshot or result
end

local PRODUCT_CATEGORY = { pass = "Passes", product = "Consumables", hero = "Heroes" }

function PlayerService:_productInfo(payload, record)
	local category = PRODUCT_CATEGORY[payload.kind]
	local product = category and type(payload.key) == "string" and self.products[category][payload.key]
	if not product or not integer(product.id, 1, 9007199254740991) then return false, "Produto ainda não configurado. / Product not set up yet." end
	if category == "Heroes" and record and record.profile.heroes[payload.key] then return false, "Você já possui este herói. / You already own this hero." end
	-- This season's premium track is already open: nothing to sell twice.
	local season = record and record.profile.season
	if product.seasonPass and record and (record.passes.season == true or (type(season) == "table" and season.id == self:_season() and season.premium == true)) then
		return false, "A trilha premium desta temporada já é sua. / This season's premium track is already yours."
	end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(product.id, category == "Passes" and Enum.InfoType.GamePass or Enum.InfoType.Product)
	end)
	if not ok or type(info) ~= "table" or not integer(info.PriceInRobux, 0, 1000000000) or info.IsForSale == false then return false, "Preço indisponível. Tente novamente. / Price unavailable. Try again." end
	-- Memory profiles may inspect real prices, but never prompt or process a purchase.
	return true, { id = product.id, price = info.PriceInRobux, name = info.Name or product.name, kind = payload.kind, key = payload.key, preview = self.memory == true }
end

-- A purchase prompt that closed without buying (Developer Products; passes
-- have their own signal above). Only the funnel hears about it.
function PlayerService:_watchCancelledProducts()
	local signal = MarketplaceService.PromptProductPurchaseFinished
	if not signal then return end
	self.productConnection = signal:Connect(function(userId, productId, wasPurchased)
		if wasPurchased then return end
		local player = Players:GetPlayerByUserId(userId)
		if not player then return end
		local heroId = self.heroProductById[productId]
		local product = self.productById[productId]
		if heroId then self:_purchaseEvent(player, "cancelled", "hero", heroId, productId)
		elseif product then self:_purchaseEvent(player, "cancelled", product.key or "product", product.key or "product", productId) end
	end)
end

function PlayerService:_purchaseEvent(player, phase, kind, key, id)
	pcall(self.onPurchase, player, phase, kind, key, id)
end

function PlayerService:_receipt(receipt)
	local pending = Enum.ProductPurchaseDecision.NotProcessedYet
	if self.memory or self.closed or type(receipt) ~= "table" or not validId(receipt.PurchaseId) then return pending end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = self.productById[receipt.ProductId]
	local heroId = self.heroProductById[receipt.ProductId]
	if not player or not (product or heroId) or not self.records[player.UserId] then return pending end
	local purchaseId = receipt.PurchaseId
	local kind, key = heroId and "hero" or "product", heroId or (product and product.key) or "product"
	self:_purchaseEvent(player, "start", kind, key, receipt.ProductId)
	local fresh = false
	local ok = self:_transaction(player, function(profile, now)
		fresh = false
		local previous = profile._receipts[purchaseId]
		if previous then
			if previous.productId ~= receipt.ProductId then return false, "Recibo inconsistente." end
			return true
		end
		fresh = true
		-- Whatever was bought and the receipt that proves it are stored in ONE
		-- atomic value before the purchase is acknowledged.
		if heroId then
			local price = self.products.Heroes[heroId].price or 0
			-- A hero the account already owns is never wasted: it becomes gold.
			self:_grantHero(profile, heroId, now, { refundGold = price * GOLD_PER_ROBUX, mastery = 0 })
		else
			profile.gold += product.gold or 0
			-- The season pass opens the premium track of the season running now;
			-- bought again while it is open (a racing second prompt), it pays Gold.
			if product.seasonPass then
				local season = self:_seasonOf(profile)
				local holder = self.records[player.UserId]
				if season.premium or (holder and holder.passes.season == true) then
					profile.gold += (product.price or 0) * GOLD_PER_ROBUX
				end
				season.premium = true
			end
			-- A bundle's heroes are chosen afterwards (PickHero): credits by rarity.
			if type(product.heroPicks) == "table" then
				profile.heroPicks = type(profile.heroPicks) == "table" and profile.heroPicks or {}
				for rarity, count in pairs(product.heroPicks) do
					profile.heroPicks[rarity] = math.floor(tonumber(profile.heroPicks[rarity]) or 0) + count
				end
			end
			-- A timed boost stacks onto whatever is left of the current one.
			if product.boostSeconds then
				profile.boostUntil = math.max(now, math.floor(tonumber(profile.boostUntil) or 0)) + product.boostSeconds
			end
			-- The starter pack's hero comes once per account.
			if product.heroId and not profile.starterPack then
				self:_grantHero(profile, product.heroId, now, { refundGold = product.repeatGold or 0, mastery = 0 })
				profile.starterPack = true
			elseif product.heroId then
				profile.gold += product.repeatGold or 0
			end
		end
		profile._receipts[purchaseId] = { productId = receipt.ProductId, at = now }
		-- The ledger only has to recognise a retried receipt, which Roblox sends
		-- within days: keep the newest entries and let the oldest go.
		local kept = {}
		for id, entry in pairs(profile._receipts) do table.insert(kept, { id = id, at = tonumber(entry.at) or 0 }) end
		if #kept > RECEIPTS_KEPT then
			table.sort(kept, function(a, b) return a.at > b.at end)
			for index = RECEIPTS_KEPT + 1, #kept do profile._receipts[kept[index].id] = nil end
		end
		return true
	end, "receipt:" .. purchaseId .. ":" .. tostring(receipt.ProductId))
	if ok then self:_purchaseEvent(player, fresh and "granted" or "replay", kind, key, receipt.ProductId) end
	return ok and Enum.ProductPurchaseDecision.PurchaseGranted or pending
end

function PlayerService:Award(player, awardId, reward)
	if not validId(awardId) or type(reward) ~= "table" then return false, "Recompensa inválida." end
	for _, key in ipairs({ "gold", "xp", "waves", "bosses" }) do
		if reward[key] ~= nil and not integer(reward[key], 0, 100000000) then return false, "Quantidade inválida: " .. key end
	end
	if reward.mapId and not self.catalog.Maps[reward.mapId] then return false, "Mapa inválido." end
	if reward.difficultyId ~= nil and not self.catalog.Difficulties[reward.difficultyId] then return false, "Dificuldade inválida." end
	if reward.modeId and not self.catalog.Modes[reward.modeId] then return false, "Modo inválido." end
	if reward.mastery ~= nil and type(reward.mastery) ~= "table" then return false, "Maestria inválida." end
	for heroId, xp in pairs(reward.mastery or {}) do if not self.catalog.Heroes[heroId] or not integer(xp, 0, 100000000) then return false, "Maestria inválida." end end
	return self:_transaction(player, function(profile, now, record)
		if profile._awards[awardId] then return true, { duplicate = true, gold = 0, xp = 0 } end
		local gold = reward.gold or 0
		local multiplier = record.passes.training and 1.25 or 1
		local xp = math.floor((reward.xp or 0) * multiplier)
		local won = reward.finished == true and reward.victory == true
		local waves, bosses = reward.waves or 0, reward.bosses or 0
		if won and reward.tutorial == true and not profile.tutorialComplete then
			profile.tutorialComplete = true
			gold += self.catalog.Chests.rare.cost
			achievement(profile, "tutorial", "Primeira defesa", "First defense", now)
		elseif won and reward.modeId == "normal" and reward.mapId then
			profile.campaign[reward.mapId] = profile.campaign[reward.mapId] or {}
			if not profile.campaign[reward.mapId].normal then gold += 500 end
			profile.campaign[reward.mapId].normal = true
			-- A Hard or Nightmare win opens the next difficulty on this map.
			local difficulty = self.catalog.Difficulties[reward.difficultyId or "normal"]
			profile.campaign[reward.mapId][difficulty.winKey] = true
		elseif reward.modeId == "ranked" and reward.mapId and (won or (tonumber(reward.wavesReached) or 0) >= FEARLESS_WAVES) then
			-- A competitive run never ends in a victory: holding 30 waves is the feat.
			profile.campaign[reward.mapId] = profile.campaign[reward.mapId] or {}
			profile.campaign[reward.mapId].ranked = true
			achievement(profile, "hardWin", "Sem medo do perigo", "Fearless", now)
		elseif won and reward.modeId == "cards" and reward.mapId then
			profile.campaign[reward.mapId] = profile.campaign[reward.mapId] or {}
			profile.campaign[reward.mapId].cards = true
			achievement(profile, "cardsWin", "Mestre das cartas", "Card master", now)
		end
		profile.gold += gold
		profile.xp += xp
		self:_seasonXp(profile, xp)
		local contributing = {}
		for heroId, earned in pairs(reward.mastery or {}) do
			local hero = profile.heroes[heroId]
			if hero and earned > 0 then
				hero.xp += math.floor(earned * multiplier)
				hero.level = levelFor(hero.xp, 20, masteryThreshold)
				contributing[heroId] = true
				if hero.level >= 20 then
					local definition = self.catalog.Heroes[heroId]
					achievement(profile, "mastery:" .. heroId, "Despertar: " .. definition.name.pt, "Awakening: " .. definition.name.en, now)
				end
			end
		end
		for _, quest in pairs(profile.quests) do
			if not quest.claimed then
				local real = reward.tutorial ~= true
				local delta = 0
				if quest.kind == "waves" then delta = waves
				elseif quest.kind == "bosses" then delta = bosses
				elseif quest.kind == "wins" then delta = (won and real) and 1 or 0
				elseif quest.kind == "gold" then delta = real and gold or 0
				elseif quest.kind == "campaign" then delta = (reward.finished and real and reward.modeId == "normal") and 1 or 0
				elseif quest.kind == "noDamage" then delta = (won and real and reward.noDamage) and 1 or 0
				elseif quest.kind == "cards" then delta = (won and real and reward.modeId == "cards") and 1 or 0 end
				if quest.kind == "heroes" then
					for heroId in pairs(contributing) do quest.heroIds[heroId] = true end
					quest.progress = math.min(quest.target, tableCount(quest.heroIds))
				else quest.progress = math.min(quest.target, quest.progress + delta) end
			end
		end
		profile.stats.waves += waves
		profile.stats.bosses += bosses
		profile.stats.goldEarned += gold
		if reward.finished then profile.stats.matches += 1 end
		if won then
			profile.stats.wins += 1
			achievement(profile, "firstVictory", "Vitória da Resistência", "Resistance victory", now)
			if reward.noDamage and reward.mapId and reward.tutorial ~= true then
				local map = self.catalog.Maps[reward.mapId]
				achievement(profile, "medal:" .. reward.mapId, "Defesa perfeita: " .. map.name.pt, "Flawless defense: " .. map.name.en, now, "medal", reward.mapId)
			end
		end
		if profile.stats.bosses >= 10 then achievement(profile, "bosses10", "Caçador de ameaças", "Threat hunter", now) end
		if profile.stats.waves >= 100 then achievement(profile, "waves100", "Guardião das ondas", "Wave guardian", now) end
		-- Only authored campaign destinations count; other maps have other modes.
		local cleared, required = 0, 0
		for _, destination in pairs(self.catalog.Destinations) do
			if destination.modeId=="normal" then
				required += 1
				if profile.campaign[destination.mapId] and profile.campaign[destination.mapId].normal then cleared += 1 end
			end
		end
		if required>0 and cleared >= required then achievement(profile, "campaign", "Última Defesa", "Last Defense", now, "title") end
		local newLevel = levelFor(profile.xp, 50, xpThreshold)
		if newLevel >= 10 then achievement(profile, "commander10", "Comandante", "Commander", now, "title") end
		if newLevel >= 50 then achievement(profile, "commander50", "Comandante supremo", "Supreme commander", now, "title") end
		profile._awards[awardId] = now
		return true, { gold = gold, xp = xp, level = newLevel }
	end, "award:" .. awardId)
end

function PlayerService:_season()
	local epoch = self.config.SeasonEpoch or 1789862400 -- 2026-09-20 00:00 UTC.
	return math.max(1, math.floor((os.time() - epoch) / ((self.config.SeasonDays or 60) * DAY)) + 1)
end

-- Competitive boards are keyed by version, map, starting party size and
-- period. "comp2" is the endless competitive arena: results from the old
-- finite ranked mode and the casual endless mode stay archived under their
-- old keys and are never imported.
local COMPETITIVE_VERSION = "comp2"
function PlayerService:_boardKey(mapId, size, period, modeId)
	return COMPETITIVE_VERSION .. ":" .. tostring(self.config.BalanceVersion or "1") .. ":" .. mapId .. ":" .. tostring(size) .. ":" .. period
end

function PlayerService:_boardStore(key)
	return DataStoreService:GetOrderedDataStore("DoomBest_" .. key)
end

function PlayerService:RecordBest(player, mapId, size, waves, modeId)
	if modeId ~= "ranked" then return false end
	if not self.catalog.Maps[mapId] or not integer(size, 1, 4) or not integer(waves, 1, 1000000) then return false end
	local seasonal = self:_boardKey(mapId, size, "s" .. tostring(self:_season()), modeId)
	local allTime = self:_boardKey(mapId, size, "all", modeId)
	local record = self.records[player.UserId]
	if not record or record.lost then return false end
	if (record.profile.best[seasonal] or 0) >= waves and (record.profile.best[allTime] or 0) >= waves then return self:_flushBoards(player) end
	local ok = self:_transaction(player, function(profile, now)
		for _, key in ipairs({ seasonal, allTime }) do
			profile.best[key] = math.max(profile.best[key] or 0, waves)
			profile._pendingBoards[key] = math.max(profile._pendingBoards[key] or 0, waves)
		end
		if waves >= 30 then achievement(profile, "infinite30", "Além do impossível", "Beyond impossible", now) end
		if waves >= 50 then achievement(profile, "season:" .. tostring(self:_season()), "Sobrevivente da temporada " .. tostring(self:_season()), "Season " .. tostring(self:_season()) .. " survivor", now, "title") end
		return true
	end)
	if ok then task.spawn(function() self:_flushBoards(player) end) end
	return ok
end

function PlayerService:_flushBoards(player)
	local record = self.records[player.UserId]
	if not record or record.closing or record.lost or record.player ~= player then return false end
	if record.flushingBoards then return true end
	record.flushingBoards = true
	local pending = copy(record.profile._pendingBoards)
	local confirmed, allOK = {}, true
	for key, waves in pairs(pending) do
		local ok = pcall(function()
			if self.memory then
				self.memoryBoards[key] = self.memoryBoards[key] or {}
				self.memoryBoards[key][tostring(player.UserId)] = math.max(self.memoryBoards[key][tostring(player.UserId)] or 0, waves)
			else self:_boardStore(key):UpdateAsync(tostring(player.UserId), function(old) return math.max(tonumber(old) or 0, waves) end) end
		end)
		if ok then confirmed[key] = waves; self.boardCache[key] = nil else allOK = false end
	end
	if next(confirmed) then
		local saved = self:_transaction(player, function(profile)
			for key, waves in pairs(confirmed) do
				if (profile._pendingBoards[key] or math.huge) <= waves then profile._pendingBoards[key] = nil end
			end
			return true
		end, nil, { silent = true })
		allOK = allOK and saved
	end
	record.flushingBoards = false
	return allOK
end

function PlayerService:Leaderboard(mapId, size, period, modeId)
	if modeId ~= nil and modeId ~= "ranked" then return nil, "Modo de placar inválido." end
	if not self.catalog.Maps[mapId] or not integer(size, 1, 4) then return nil, "Placar inválido." end
	period = period or ("s" .. tostring(self:_season()))
	if period ~= "all" then
		local requestedSeason = type(period) == "string" and tonumber(string.match(period, "^s(%d+)$"))
		if not integer(requestedSeason, 1, self:_season()) then return nil, "Temporada inválida." end
	end
	local key = self:_boardKey(mapId, size, period, modeId)
	local cache = self.boardCache[key]
	if cache and os.clock() - cache.at < 30 then return copy(cache.rows) end
	local entries
	local ok = pcall(function()
		if self.memory then
			entries = {}
			for userId, waves in pairs(self.memoryBoards[key] or {}) do table.insert(entries, { key = userId, value = waves }) end
			table.sort(entries, function(a, b) return a.value > b.value end)
			while #entries > 50 do table.remove(entries) end
		else entries = self:_boardStore(key):GetSortedAsync(false, 50, 1):GetCurrentPage() end
	end)
	if not ok then return nil, "Placar temporariamente indisponível." end
	local rows, previous, rank = {}, nil, 0
	for index, entry in ipairs(entries) do
		if entry.value ~= previous then rank = index; previous = entry.value end
		local userId = tonumber(entry.key)
		if userId then
			local name = self.nameCache[userId]
			if not name then
				local found, result = pcall(function() return Players:GetNameFromUserIdAsync(userId) end)
				name = found and result or ("Player " .. tostring(userId))
				self.nameCache[userId] = name
			end
			table.insert(rows, { rank = rank, userId = userId, name = name, waves = entry.value })
		end
	end
	self.boardCache[key] = { at = os.clock(), rows = rows }
	return copy(rows)
end

function PlayerService:Save(player)
	return self:_transaction(player, function() return true end, nil, { silent = true })
end

function PlayerService:Release(player)
	local record = self.records[player.UserId]
	if not record or record.player ~= player or record.closing then return end
	self:_flushBoards(player)
	-- The flush yields. A reconnect may have rebound this account meanwhile.
	if self.records[player.UserId] ~= record or record.player ~= player then return end
	record.closing = true
	if self.trades and self.trades[player.UserId] then self:_endTrade(self.trades[player.UserId], "cancelled") end
	local ok = self:_transaction(player, function() return true end, nil, { releasing = true, silent = true })
	-- Mutations already commit immediately. If lease release fails, the next
	-- server waits for expiry rather than taking ownership prematurely.
	if self.records[player.UserId] == record then self.records[player.UserId] = nil end
	if not ok then warn("[PlayerService] Lease release pending expiry for " .. tostring(player.UserId)) end
end

function PlayerService:Shutdown()
	if self.closed then return end
	self.closed = true
	if self.passConnection then self.passConnection:Disconnect() end
	local pending = 0
	for _, record in pairs(self.records) do
		pending += 1
		local player = record.player
		task.spawn(function() self:Release(player); pending -= 1 end)
	end
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do task.wait(0.1) end
end

return PlayerService
