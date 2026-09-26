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
local SCHEMA_VERSION = 1
local PUBLIC_FIELDS = { "gold", "xp", "level", "heroes", "bases", "equippedBase", "loadout", "abilities", "pity", "campaign", "tutorialComplete", "settings", "savedLoadouts", "quests", "achievements", "best", "stats", "title", "talents" }
-- Heroes are won from chests or bought directly with Robux, never with a plain
-- gold purchase, so there is no BuyHero here: OpenChest is the way in.
local ACTIONS = { EquipBase = true, UpgradeTalent = true, ResetTalents = true, OpenChest = true, UpgradeAbility = true, SetLoadout = true, SaveLoadout = true, LoadLoadout = true, Settings = true, ClaimQuest = true, ProductInfo = true, Leaderboard = true, SetTitle = true,
	ClaimFreeChest = true, ClaimLogin = true, ClaimPlaytime = true, ClaimMilestone = true,
	RedeemCode = true, ClaimGroupReward = true }
-- Rewards that can open a chest need their two random numbers drawn up front.
local CHEST_ACTIONS = { OpenChest = true, ClaimFreeChest = true, ClaimLogin = true, ClaimPlaytime = true, RedeemCode = true }
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
		codes = {},
		campaign = {}, tutorialComplete = false, title = "",
		settings = { language = "pt", lowFX = false, shake = true, music = true, effects = true, autoSkip = false, fastForward = false },
		savedLoadouts = {}, quests = {}, achievements = {}, best = {},
		stats = { waves = 0, bosses = 0, wins = 0, matches = 0, goldEarned = 0, chests = 0 },
		createdAt = now, updatedAt = now,
		_receipts = {}, _awards = {}, _operations = {}, _operationOrder = {}, _dailyWins = {},
		_pendingBoards = {}, _passHistory = {},
	}
end

-- Unknown future versions and damaged economic fields fail closed. A failed read
-- must never turn an existing player into a new profile.
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
	return profile
end

local QUEST_TYPES = {
	{ key = "waves", name = { pt = "Resista à invasão", en = "Withstand the invasion" }, target = 15, gold = 150, xp = 70 },
	{ key = "wins", name = { pt = "Defesa concluída", en = "Successful defense" }, target = 1, gold = 100, xp = 60 },
	{ key = "heroes", name = { pt = "Equipe versátil", en = "Versatile team" }, target = 3, gold = 100, xp = 60 },
}
local WEEKLY_TYPES = {
	{ key = "waves", name = { pt = "Veterano da defesa", en = "Defense veteran" }, target = 100, gold = 750, xp = 250 },
	{ key = "bosses", name = { pt = "Caçador de chefes", en = "Boss hunter" }, target = 15, gold = 600, xp = 200 },
	{ key = "heroes", name = { pt = "Aliança de heróis", en = "Hero alliance" }, target = 8, gold = 750, xp = 250 },
}

local function refreshQuests(profile, now)
	for id, quest in pairs(profile.quests) do
		if type(quest) ~= "table" or (quest.expiresAt or 0) <= now then profile.quests[id] = nil end
	end
	local today = math.floor(now / DAY)
	local function add(definition, period, index, expires)
		local id = period .. ":" .. tostring(index) .. ":" .. definition.key
		if not profile.quests[id] then
			profile.quests[id] = { id = id, kind = definition.key, period = period, name = copy(definition.name), description = copy(definition.name), progress = 0, target = definition.target, gold = definition.gold, xp = definition.xp, claimed = false, expiresAt = expires, heroIds = {} }
		end
	end
	for day = today - 2, today do
		for _, definition in ipairs(QUEST_TYPES) do add(definition, "daily", day, (day + 3) * DAY) end
	end
	local week = math.floor((today + 3) / 7) -- Monday-based UTC week.
	for _, definition in ipairs(WEEKLY_TYPES) do add(definition, "weekly", week, (week * 7 + 4) * DAY) end
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
	-- Server-only promo codes (src/server/Codes.luau), keyed in capitals.
	self.codes = codes or config.Codes or {}
	assert(rules and rules.RollChest and rules.AbilityUpgrade, "PlayerService needs the shared Rules module")
	self.random = Random.new()
	self.memory = RunService:IsStudio() and config.StudioMemory == true
	self.closed = false
	self.records, self.gates, self.memoryProfiles, self.memoryBoards = {}, {}, {}, {}
	self.boardCache, self.nameCache = {}, {}
	self.sessionId = (game.JobId ~= "" and game.JobId or "studio") .. ":" .. HttpService:GenerateGUID(false)
	self.leaseSeconds = math.max(60, config.ProfileLeaseSeconds or 180)
	self.retries = math.clamp(config.ProfileRetries or 3, 1, 5)
	self.products = productDefinitions(config, catalog)
	self.productById, self.heroProductById = {}, {}
	for _, product in pairs(self.products.Consumables) do
		if integer(product.id, 1, 9007199254740991) and integer(product.gold, 1, 100000000) then
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
	if not self.memory then self.store = DataStoreService:GetDataStore(config.DataStoreName or "DoomPlayer_v1") end
	MarketplaceService.ProcessReceipt = function(receipt) return self:_receipt(receipt) end
	self.passConnection = MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then return end
		for key, product in pairs(self.products.Passes) do
			if product.id == passId and self.records[player.UserId] then
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
		return false, "Serviço de dados indisponível. Tente novamente."
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

function PlayerService:Load(player)
	if self.closed then return nil, "Servidor encerrando." end
	local result, failure = self:_withLock(player.UserId, function()
		local existing = self.records[player.UserId]
		if existing and not existing.lost and not existing.closing and existing.profile._session and existing.profile._session.expires > os.time() then existing.player = player; return existing end
		if existing then existing.lost = true end
		local lockFailure
		local ok, persisted = self:_update(player.UserId, function(raw)
			local now = os.time()
			local profile = normalize(raw, now, self.catalog)
			local session = profile._session
			if session and session.id ~= self.sessionId and (session.expires or 0) > now then lockFailure = "Seu perfil ainda está em outro servidor. Aguarde alguns segundos."; return nil end
			lockFailure = nil
			profile._session = { id = self.sessionId, expires = now + self.leaseSeconds }
			refreshQuests(profile, now)
			profile.updatedAt = now
			return profile
		end)
		if not ok or not persisted then return nil, lockFailure or "Não foi possível carregar seu perfil. Nenhum dado foi substituído." end
		local record = { player = player, profile = persisted, passes = {}, closing = false, lost = false, lastSaved = os.time(), playMark = os.time(), randomRestricted = false }
		self.records[player.UserId] = record
		return record
	end)
	if not result then return nil, failure end
	self:_refreshPasses(player)
	self:_refreshPolicy(player)
	task.spawn(function() self:_flushBoards(player) end)
	self:_notify(player)
	return self:Snapshot(player)
end

-- Some regions do not allow paid random items. Gold from Robux can end up in a
-- chest, so a restricted player is not offered Gold packs. Chests themselves
-- stay open to everyone: they cost earned Gold, and every hero also has a
-- direct Robux price, so nothing is locked behind chance.
function PlayerService:_refreshPolicy(player)
	local record = self.records[player.UserId]
	if not record or self.memory then return end
	local ok, restricted = pcall(function()
		local policy = game:GetService("PolicyService"):GetPolicyInfoForPlayerAsync(player)
		return policy.ArePaidRandomItemsRestricted == true
	end)
	record.randomRestricted = ok and restricted == true
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
		if not record or record.player ~= player or record.lost or (record.closing and not options.releasing) then return false, "Perfil ainda não disponível." end
		local rejected, value, lost = nil, nil, false
		-- Fixed before the callback, which UpdateAsync may run more than once.
		local elapsed = math.clamp(os.time() - (record.playMark or os.time()), 0, PLAYTIME_CAP)
		local saved, persisted = self:_update(player.UserId, function(raw)
			rejected, value, lost = nil, nil, false
			local now = os.time()
			local profile = normalize(raw, now, self.catalog)
			if not profile._session or profile._session.id ~= self.sessionId or profile._session.expires <= now then lost = true; rejected = "Sessão de dados expirada. Entre novamente."; return nil end
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
		if not saved then return false, "Não foi possível salvar. A operação pode ser repetida com segurança." end
		if not persisted then return false, rejected or "Alteração não confirmada." end
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
	local rarity = self.catalog.Rarities[hero.rarity]
	if profile.heroes[heroId] then
		local refund = options.refundGold or rarity.duplicate.gold
		local mastery = options.mastery == nil and rarity.duplicate.mastery or options.mastery
		profile.gold += refund
		local owned = profile.heroes[heroId]
		owned.xp += mastery
		owned.level = levelFor(owned.xp, 20, masteryThreshold)
		return true, { gold = refund, mastery = mastery }
	end
	profile.heroes[heroId] = { xp = 0, level = 1 }
	profile.abilities[heroId] = 1
	if #profile.loadout < MAX_LOADOUT then table.insert(profile.loadout, heroId) end
	if tableCount(profile.heroes) >= #self.catalog.HeroOrder then achievement(profile, "allHeroes", "Vingadores reunidos", "Avengers assembled", now) end
	if hero.rarity == "mythic" then achievement(profile, "mythic:" .. heroId, "Lenda cósmica: " .. hero.name.pt, "Cosmic legend: " .. hero.name.en, now) end
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
			refund.gold=math.min(math.floor(chest.cost*0.4),self.catalog.Rarities[outcome.rarity].duplicate.gold)
			profile.gold+=refund.gold
		else profile.bases[outcome.baseId]=true end
	else duplicate, refund = self:_grantHero(profile, outcome.heroId, now) end
	profile.stats.chests += 1
	if profile.stats.chests == 1 then achievement(profile, "firstChest", "Primeiro baú", "First chest", now) end
	return { chestId = chestId, heroId = outcome.heroId, baseId = outcome.baseId, rarity = outcome.rarity, duplicate = duplicate,
		refundGold = refund.gold, refundMastery = refund.mastery, pity = outcome.pity, cost = chest.cost }
end

-- Pays a reward table ({ gold, xp, chest, title }) into the profile.
function PlayerService:_payReward(profile, reward, rolls, now, current)
	local paid = { gold = reward.gold or 0, xp = 0 }
	profile.gold += paid.gold
	if reward.xp then
		paid.xp = math.floor(reward.xp * (current.passes.training and 1.25 or 1))
		profile.xp += paid.xp
	end
	if reward.title then achievement(profile, reward.title.id, reward.title.pt, reward.title.en, now, "title") end
	if reward.chest then paid.chest = self:_openChest(profile, reward.chest, rolls, now) end
	return paid
end

-- AFK farm pay. Never a client action: the lobby loop calls it after the
-- server itself has watched the commander stand in a farm for a minute.
function PlayerService:GrantAfk(player, kind, minutes)
	local reward = self.rules.AfkReward(kind, minutes)
	if not reward then return false, "Farm AFK inválido." end
	return self:_transaction(player, function(profile)
		profile.gold += reward.gold
		profile.xp += reward.xp
		profile.stats.goldEarned += reward.gold
		return true, { kind = kind, gold = reward.gold, xp = reward.xp }
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
	result.loadoutSlots = record.passes.formations and 8 or 3
	result.paidRandomRestricted = record.randomRestricted == true
	local now = os.time()
	result.rewards = self.rules.RewardsStatus(record.profile, now, math.clamp(now - (record.playMark or now), 0, PLAYTIME_CAP))
	result.xpNext = result.level < 50 and xpThreshold(result.level + 1) or result.xp
	result.xpFloor = xpThreshold(result.level)
	result.season = self:_season()
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
	return result
end

function PlayerService:_validHeroes(profile, heroes)
	return validList(heroes, MAX_LOADOUT, function(id) return self.catalog.Heroes[id] ~= nil and profile.heroes[id] ~= nil end, false)
end

function PlayerService:Handle(player, action, payload, inLobby)
	if not ACTIONS[action] then return false, false, "Ação não reconhecida." end
	if type(payload) ~= "table" then return true, false, "Dados inválidos." end
	local record = self.records[player.UserId]
	if not record or record.player ~= player or record.closing or record.lost then return true, false, "Aguarde o carregamento do perfil." end
	if not inLobby and action ~= "Settings" then return true, false, "Esta ação só está disponível no lobby." end
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
	local rolls = CHEST_ACTIONS[action] and { self.random:NextNumber(), self.random:NextNumber() } or nil
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
		elseif action == "OpenChest" then
			if record.randomRestricted then return false, "Baús indisponíveis para esta conta. / Chests unavailable for this account." end
			local chest = type(payload.chestId) == "string" and self.catalog.Chests[payload.chestId]
			if not chest then return false, "Baú inválido. / Invalid chest." end
			if profile.gold < chest.cost then return false, "Ouro insuficiente. / Not enough Gold." end
			profile.gold -= chest.cost
			-- The client never supplies or sees a roll, only the committed result.
			return true, self:_openChest(profile, payload.chestId, rolls, now)
		elseif action == "ClaimFreeChest" then
			local state, config = profile.rewards, self.catalog.Rewards.freeChest
			if now < state.freeChestAt then return false, "O baú grátis ainda não está pronto. / The free chest is not ready yet." end
			state.freeChestAt = now + config.cooldown
			return true, { chest = self:_openChest(profile, config.chestId, rolls, now), gold = 0, xp = 0 }
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
		elseif action == "SaveLoadout" or action == "LoadLoadout" then
			local limit = current.passes.formations and 8 or 3
			if not integer(payload.slot, 1, limit) then return false, "Espaço de formação indisponível. / Formation slot unavailable." end
			local slot = tostring(payload.slot)
			if action == "SaveLoadout" then profile.savedLoadouts[slot] = { heroes = copy(profile.loadout) }
			else
				local saved = profile.savedLoadouts[slot]
				if not saved then return false, "Este espaço está vazio. / This slot is empty." end
				if not self:_validHeroes(profile, saved.heroes) then return false, "Esta formação precisa ser atualizada. / This formation needs updating." end
				profile.loadout = copy(saved.heroes)
			end
		elseif action == "Settings" then
			if payload.language ~= nil and payload.language ~= "pt" and payload.language ~= "en" then return false, "Idioma inválido." end
			if payload.lowFX ~= nil and type(payload.lowFX) ~= "boolean" then return false, "Configuração inválida." end
			if payload.shake ~= nil and type(payload.shake) ~= "boolean" then return false, "Configuração inválida." end
			if payload.music ~= nil and type(payload.music) ~= "boolean" then return false, "Configuração inválida." end
			for _, key in ipairs({ "effects", "autoSkip", "fastForward" }) do
				if payload[key] ~= nil and type(payload[key]) ~= "boolean" then return false, "Configuração inválida." end
			end
			for _, key in ipairs({ "language", "lowFX", "shake", "music", "effects", "autoSkip", "fastForward" }) do if payload[key] ~= nil then profile.settings[key] = payload[key] end end
		elseif action == "SetTitle" then
			local id = payload.titleId
			if id == nil or id == "" then
				profile.title = ""
			elseif not validId(id) then
				return false, "Título inválido."
			elseif id == "vip" then
				if not current.passes.vip then return false, "Este título acompanha o pacote VIP." end
				profile.title = id
			else
				local unlocked = profile.achievements[id]
				if type(unlocked) ~= "table" or unlocked.kind ~= "title" then return false, "Você ainda não conquistou este título." end
				profile.title = id
			end
		elseif action == "ClaimQuest" then
			local quest = validId(payload.questId) and profile.quests[payload.questId]
			if not quest or quest.expiresAt <= now or quest.claimed or quest.progress < quest.target then return false, "Missão incompleta, resgatada ou expirada." end
			quest.claimed = true
			profile.gold += quest.gold
			profile.xp += math.floor(quest.xp * (current.passes.training and 1.25 or 1))
		end
		return true
	end)
	local snapshot = ok and self:Snapshot(player) or nil
	-- A chest or an ability upgrade also reports what just happened, so the
	-- client can play the reveal instead of guessing from a diff.
	if snapshot and type(result) == "table" and (action == "OpenChest" or action == "UpgradeAbility" or action == "RedeemCode" or action:sub(1, 5) == "Claim") then snapshot.result = result end
	return true, ok, ok and snapshot or result
end

local PRODUCT_CATEGORY = { pass = "Passes", product = "Consumables", hero = "Heroes" }

function PlayerService:_productInfo(payload, record)
	if self.memory then return false, "Compras desativadas no modo de memória do Studio." end
	local category = PRODUCT_CATEGORY[payload.kind]
	local product = category and type(payload.key) == "string" and self.products[category][payload.key]
	if not product or not integer(product.id, 1, 9007199254740991) then return false, "Produto ainda não configurado." end
	if category == "Consumables" and record and record.randomRestricted then
		return false, "Indisponível na sua região. / Unavailable in your region."
	end
	if category == "Heroes" and record and record.profile.heroes[payload.key] then return false, "Você já possui este herói. / You already own this hero." end
	local ok, info = pcall(function()
		return MarketplaceService:GetProductInfoAsync(product.id, category == "Passes" and Enum.InfoType.GamePass or Enum.InfoType.Product)
	end)
	if not ok or type(info) ~= "table" or not integer(info.PriceInRobux, 0, 1000000000) or info.IsForSale == false then return false, "Preço indisponível. Tente novamente." end
	return true, { id = product.id, price = info.PriceInRobux, name = info.Name or product.name, kind = payload.kind, key = payload.key }
end

function PlayerService:_receipt(receipt)
	local pending = Enum.ProductPurchaseDecision.NotProcessedYet
	if self.memory or self.closed or type(receipt) ~= "table" or not validId(receipt.PurchaseId) then return pending end
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	local product = self.productById[receipt.ProductId]
	local heroId = self.heroProductById[receipt.ProductId]
	if not player or not (product or heroId) or not self.records[player.UserId] then return pending end
	local purchaseId = receipt.PurchaseId
	local ok = self:_transaction(player, function(profile, now)
		local previous = profile._receipts[purchaseId]
		if previous then
			if previous.productId ~= receipt.ProductId then return false, "Recibo inconsistente." end
			return true
		end
		-- Whatever was bought and the receipt that proves it are stored in ONE
		-- atomic value before the purchase is acknowledged.
		if heroId then
			local price = self.products.Heroes[heroId].price or 0
			-- A hero the account already owns is never wasted: it becomes gold.
			self:_grantHero(profile, heroId, now, { refundGold = price * GOLD_PER_ROBUX, mastery = 0 })
		else
			profile.gold += product.gold
		end
		profile._receipts[purchaseId] = { productId = receipt.ProductId, at = now }
		return true
	end, "receipt:" .. purchaseId .. ":" .. tostring(receipt.ProductId))
	return ok and Enum.ProductPurchaseDecision.PurchaseGranted or pending
end

function PlayerService:Award(player, awardId, reward)
	if not validId(awardId) or type(reward) ~= "table" then return false, "Recompensa inválida." end
	for _, key in ipairs({ "gold", "xp", "waves", "bosses" }) do
		if reward[key] ~= nil and not integer(reward[key], 0, 100000000) then return false, "Quantidade inválida: " .. key end
	end
	if reward.mapId and not self.catalog.Maps[reward.mapId] then return false, "Mapa inválido." end
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
		elseif won and reward.modeId == "ranked" and reward.mapId then
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
				local delta = quest.kind == "waves" and waves or (quest.kind == "bosses" and bosses or (quest.kind == "wins" and won and reward.tutorial ~= true and 1 or 0))
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
			achievement(profile, "firstVictory", "Vitória dos Vingadores", "Avengers victory", now)
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

function PlayerService:_boardKey(mapId, size, period, modeId)
	return (modeId == "ranked" and "ranked:" or "") .. tostring(self.config.BalanceVersion or "1") .. ":" .. mapId .. ":" .. tostring(size) .. ":" .. period
end

function PlayerService:_boardStore(key)
	return DataStoreService:GetOrderedDataStore("DoomBest_" .. key)
end

function PlayerService:RecordBest(player, mapId, size, waves, modeId)
	if modeId ~= nil and modeId ~= "infinite" and modeId ~= "ranked" then return false end
	if modeId == "ranked" and waves > 50 then return false end
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
	if modeId ~= nil and modeId ~= "infinite" and modeId ~= "ranked" then return nil, "Modo de placar inválido." end
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
