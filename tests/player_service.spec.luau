-- Executed by test_player_service.py, which inlines the actual source modules.
local checks = 0
local function check(condition, message)
	checks += 1
	assert(condition, message)
end
local function clone(value)
	if type(value) ~= "table" then return value end
	local result = {}
	for key, item in pairs(value) do result[key] = clone(item) end
	return result
end

-- A frozen clock the tests move by hand: reward timers and the login calendar
-- depend on it, and no test should wait real hours. Declared before the
-- inlined modules below, so their bare `os.time()` calls close over this local
-- instead of the real global. Starts at noon UTC so no test straddles a day
-- boundary by accident.
local realOs = os
local clockOffset = 0
local clockBase = math.floor(realOs.time() / 86400) * 86400 + 43200
local os = { time = function() return clockBase + clockOffset end, clock = realOs.clock, date = realOs.date, difftime = realOs.difftime }

local stores, orderedStores, online, passOwners = {}, {}, {}, {}
local isStudio, guid = false, 0
local failBefore, failAfter, replayCallback = 0, 0, false
local scheduleUpdates = false
local marketplace = { PromptGamePassPurchaseFinished = { Connect = function(_, callback)
	return { Disconnect = function() end, callback = callback }
end } }
function marketplace:UserOwnsGamePassAsync(userId, passId) return passOwners[tostring(userId) .. ":" .. tostring(passId)] == true end
function marketplace:GetProductInfoAsync(id, _infoType) return { Name = "Platform product " .. id, PriceInRobux = 87, IsForSale = true } end
local function createStore()
	local store = { values = {} }
	function store:UpdateAsync(key, transform)
		if scheduleUpdates then coroutine.yield("network") end
		if failBefore > 0 then failBefore -= 1; error("SIMULATED_NETWORK_FAILURE") end
		if replayCallback then transform(clone(self.values[key])) end
		local result = transform(clone(self.values[key]))
		if result ~= nil then self.values[key] = clone(result) end
		if failAfter > 0 then failAfter -= 1; error("SIMULATED_RESPONSE_LOST_AFTER_COMMIT") end
		return clone(result)
	end
	function store:GetSortedAsync(_ascending, size)
		local rows = {}
		for key, value in pairs(self.values) do table.insert(rows, { key = key, value = value }) end
		table.sort(rows, function(a, b) return a.value > b.value end)
		while #rows > size do table.remove(rows) end
		return { GetCurrentPage = function() return rows end }
	end
	return store
end
local services = {
	DataStoreService = {
		GetDataStore = function(_, name)
			if not stores[name] then stores[name] = createStore() end
			return stores[name]
		end,
		GetOrderedDataStore = function(_, name)
			if not orderedStores[name] then orderedStores[name] = createStore() end
			return orderedStores[name]
		end,
	},
	MarketplaceService = marketplace,
	Players = {
		GetPlayerByUserId = function(_, userId) return online[userId] end,
		GetNameFromUserIdAsync = function(_, userId) return "TestPlayer" .. tostring(userId) end,
	},
	RunService = { IsStudio = function() return isStudio end },
	HttpService = { GenerateGUID = function() guid += 1; return "test-uuid-" .. guid end },
}
local game = { JobId = "unit-server", GetService = function(_, name) return services[name] end }
local Enum = { InfoType = { GamePass = "pass", Product = "product" }, ProductPurchaseDecision = { NotProcessedYet = "pending", PurchaseGranted = "granted" } }
-- Background timers are suppressed; tests invoke flush/release explicitly.
local task = { spawn = function() end, wait = function() if scheduleUpdates then coroutine.yield("waiting") end end }
local warn = function() end
-- A seeded stand-in for Roblox's Random. Tests replace service.random to script
-- the exact rolls a chest consumes.
local Random = { new = function()
	local state = 20260921
	return { NextNumber = function()
		state = (state * 48271) % 2147483647
		return state / 2147483647
	end }
end }
local Catalog = __CATALOG__
local Rules = __RULES__
local PlayerService = __SERVICE__
local config = {
	DataStoreName = "Tests", StudioMemory = true, ProfileRetries = 3, GroupId = 777,
	Codes = { TESTE = { gold = 200 }, VELHO = { gold = 1, expires = 1 }, BAU = { gold = 0, chest = "rare" } },
	Products = {
		Passes = { collector = { id = 201 }, training = { id = 202 }, season = { id = 203 } },
		Consumables = { gold1000 = { id = 101 }, gold5000 = { id = 102 }, starterPack = { id = 103 } },
		Heroes = { falcon = { id = 301 }, thor = { id = 302 }, ironman = { id = 999 } },
	},
}
-- Scripts the rolls a chest consumes, in order, then falls back to zero.
local function scriptedRolls(...)
	local values, index = { ... }, 0
	return { NextNumber = function() index += 1; return values[index] or 0 end }
end
local function player(id)
	local result = { UserId = id, Name = "Player" .. id }
	online[id] = result
	return result
end
local p1, p2 = player(1), player(2)
local service = PlayerService.new(config, Catalog, nil, Rules)
check(service.memory == false, "A live server must ignore StudioMemory=true")
local initial = service:Load(p1)
check(initial and initial.gold == 0 and initial.level == 1, "New account defaults")
check(initial.heroes.ironman and initial.heroes.hawkeye and #initial.loadout == 2, "Starter heroes")
check(initial._receipts == nil and initial._session == nil and initial._awards == nil, "Secrets never replicate")
initial.gold = 999999
check(service:Get(p1).gold == 0, "Public snapshots cannot mutate saved state")
check(initial.abilities.ironman == 1 and initial.abilities.hawkeye == 1, "Every owned hero starts its ability at rank one")
check(initial.loadout[1] == "ironman", "Slot one starts with Iron Man, whose ability the player fights with")
check(initial.pity.legendary == 0 and initial.stats.chests == 0, "A new account has opened no chests")
check(initial.skills == nil and initial.activeSkills == nil and initial.passives == nil, "The old skill system leaves no trace")
check(initial.paidRandomRestricted == false, "Regional restriction defaults to open")
check(not service:StudioUnlock(p1) and not service:Get(p1).campaign.manhattan, "Studio unlock cannot mutate a cloud profile")
check(not pcall(function() PlayerService.new(config, Catalog) end), "The service refuses to start without the shared Rules")

-- AFK farm pay is server-internal: a small fixed amount per minute, and the
-- client can never ask for it by name.
do
	local p1 = player(4242)
	service:Load(p1)
	local before = service:Get(p1)
	local paidOK, paidWhy = service:GrantAfk(p1, "gold", 1)
	check(paidOK, "AFK gold minute is paid: " .. tostring(paidWhy) .. " loaded=" .. tostring(service:Get(p1) ~= nil))
	check(service:Get(p1).gold == before.gold + Catalog.Afk.gold.gold and service:Get(p1).xp == before.xp, "AFK gold pays only its gold rate")
	check(service:GrantAfk(p1, "xp", 2), "AFK XP minutes are paid")
	check(service:Get(p1).xp == before.xp + Catalog.Afk.xp.xp * 2 and service:Get(p1).gold == before.gold + Catalog.Afk.gold.gold, "AFK XP pays only its XP rate")
	check(not service:GrantAfk(p1, "gems", 1) and not service:GrantAfk(p1, "gold", 0) and not service:GrantAfk(p1, "gold", 60), "Invalid AFK payouts refused")
	local handled, asked = service:Handle(p1, "GrantAfk", { kind = "gold", minutes = 10 }, true)
	check(not handled and not asked, "No client action pays AFK gold")
	check(service:Get(p1).gold == before.gold + Catalog.Afk.gold.gold, "Refused AFK requests change nothing")
	-- Each minute has its own payment id: a retry after a lost response is
	-- recognised and never pays twice.
	local afterFirst = service:Get(p1).gold
	check(service:GrantAfk(p1, "gold", 1, "afk:gold:test:1"), "an AFK minute with a payment id is paid")
	check(service:GrantAfk(p1, "gold", 1, "afk:gold:test:1"), "retrying the same minute is acknowledged")
	check(service:Get(p1).gold == afterFirst + Catalog.Afk.gold.gold, "a retried AFK minute pays only once")
	check(service:GrantAfk(p1, "gold", 1, "afk:gold:test:2") and service:Get(p1).gold == afterFirst + 2 * Catalog.Afk.gold.gold, "the next minute pays again")
end
-- Mutations and reward idempotency, including retries AFTER a successful commit.
replayCallback = true
failAfter = 1
check(service:Award(p1, "tutorial:finish", { tutorial = true, finished = true, victory = true, modeId = "tutorial", mapId = "manhattan", gold = 0, xp = 100, mastery = { ironman = 10 } }), "Tutorial award survives lost response")
check(service:Get(p1).gold == 1000, "Repeated UpdateAsync callbacks cannot duplicate tutorial gold, got " .. tostring(service:Get(p1).gold))
check(service:Get(p1).tutorialComplete, "Tutorial unlock saved")
check(service:Award(p1, "tutorial:finish", { tutorial = true, finished = true, victory = true, gold = 999999 }), "Duplicate award acknowledged")
check(service:Get(p1).gold == 1000 and service:Get(p1).xp == 100, "Duplicate award is inert")
check(service:Award(p1, "tutorial:again", { tutorial = true, finished = true, victory = true }), "Replay tutorial award")
check(service:Get(p1).gold == 1000, "Tutorial first-clear bonus awarded once")

-- Heroes come from chests, never from a plain gold purchase.
local handled, boughtDirect = service:Handle(p1, "BuyHero", { heroId = "spiderman" }, true)
check(not handled and not boughtDirect, "The old direct hero purchase no longer exists")
local _, brokeOpen = service:Handle(p1, "OpenChest", { chestId = "legendary" }, true)
check(not brokeOpen and service:Get(p1).gold == 1000 and service:Get(p1).stats.chests == 0, "A chest needs its full price")
local _, badChest = service:Handle(p1, "OpenChest", { chestId = "platinum" }, true)
check(not badChest and service:Get(p1).gold == 1000, "Unknown chests rejected")
local _, nonString = service:Handle(p1, "OpenChest", { chestId = { "rare" } }, true)
check(not nonString, "A table is not a chest id")
service:Award(p1, "seed-chest-gold", { gold = 9000 })
check(service:Get(p1).gold == 10000, "Gold to spend on chests")
local _, inMatch = service:Handle(p1, "OpenChest", { chestId = "rare" }, false)
check(not inMatch and service:Get(p1).gold == 10000, "Chests only open in the lobby")

-- A scripted rare chest: rarity roll 0 is a common, hero roll 0 the first of the pool.
service.random = scriptedRolls(0, 0)
local _, openedOk, opened = service:Handle(p1, "OpenChest", { chestId = "rare" }, true)
check(openedOk and opened.gold == 9000, "A rare chest costs 1,000")
check(opened.result.chestId == "rare" and opened.result.heroId == "falcon" and opened.result.rarity == "common" and not opened.result.duplicate, "The reply reports what the chest held")
check(opened.result.cost == 1000, "The reply reports the price")
check(opened.heroes.falcon and opened.heroes.falcon.level == 1, "The hero drawn joins the account")
check(opened.abilities.falcon == 1, "A new hero's ability starts at rank one")
check(opened.loadout[3] == "falcon", "A new hero takes the first free slot")
check(opened.stats.chests == 1, "Chests opened are counted")
check(opened.achievements.firstChest ~= nil, "First chest achievement")
check(stores.Tests.values.p_1.heroes.falcon ~= nil and stores.Tests.values.p_1.gold == 9000, "The hero and the price are durable together")

-- The same roll now finds Falcon owned: a chest prefers something new.
service.random = scriptedRolls(0, 0)
local _, secondOk, second = service:Handle(p1, "OpenChest", { chestId = "rare" }, true)
check(secondOk and second.heroes.bucky ~= nil and second.gold == 8000, "A repeated roll delivers the other new common instead of a duplicate")
service.random = scriptedRolls(0, 0)
local masteryBefore = service:Get(p1).heroes.falcon.xp + service:Get(p1).heroes.bucky.xp
local _, thirdOk, third = service:Handle(p1, "OpenChest", { chestId = "rare" }, true)
check(thirdOk, "A third common opening resolves")
check(third.gold == 8000 - 1000 + Catalog.Heroes[third.result.heroId].economy.duplicate.gold, "A duplicate refunds its per-hero Gold")
check(third.result.duplicate and third.result.refundGold == 150 and third.result.refundMastery == 60, "The reply reports the duplicate refund")
check(third.heroes.falcon.xp + third.heroes.bucky.xp == masteryBefore + Catalog.Heroes[third.result.heroId].economy.duplicate.mastery, "A duplicate becomes mastery on that hero")
check(#third.loadout == 4, "A duplicate never takes a slot")
check(third.result.starGained == true and third.result.stars == 1 and (third.heroes.falcon.stars or 0) + (third.heroes.bucky.stars or 0) == 1,
	"A duplicate adds one star to that hero and the reply says so")
do
	-- Past the last star a duplicate only pays Gold and mastery.
	-- Transactions read the stored value, so the stars are set there.
	local stored = stores.Tests.values.p_1.heroes
	stored.falcon.stars, stored.bucky.stars = Catalog.Stars.max, Catalog.Stars.max
	service.random = scriptedRolls(0, 0)
	local _, maxOk, maxed = service:Handle(p1, "OpenChest", { chestId = "rare" }, true)
	check(maxOk and maxed.result.duplicate and maxed.result.starGained == false and maxed.result.stars == Catalog.Stars.max, "A maxed hero gains no more stars")
	check((maxed.heroes.falcon.stars or 0) <= Catalog.Stars.max and (maxed.heroes.bucky.stars or 0) <= Catalog.Stars.max, "Stars never pass the maximum")
	stored.falcon.stars, stored.bucky.stars = 0, 0
	-- Shiny: the chest's third roll decides it, once per hero, and it is cosmetic.
	service.random = scriptedRolls(0, 0, 0.99)
	local _, shinyOk, shiny = service:Handle(p1, "OpenChest", { chestId = "rare" }, true)
	check(shinyOk and shiny.result.shiny == true, "A third roll in the top 1/40 makes the pulled hero shiny")
	check(shiny.heroes[shiny.result.heroId].shiny == true, "The hero keeps its shine")
	local statsBefore = Rules.PermanentModifiers(service.records[p1.UserId].profile, shiny.result.heroId).damageBonus
	service.random = scriptedRolls(0, 0, 0.99)
	local _, againOk, again = service:Handle(p1, "OpenChest", { chestId = "rare" }, true)
	check(againOk and again.result.shiny == false, "An already shiny hero is not announced shiny twice")
	service.random = scriptedRolls(0, 0, 0.5)
	local _, plainOk, plain = service:Handle(p1, "OpenChest", { chestId = "rare" }, true)
	check(plainOk and plain.result.shiny == false, "An ordinary third roll gives no shine")
end

-- Slot one is the ability slot: the loadout order is stored exactly as sent.
local _, reorderOk, reordered = service:Handle(p1, "SetLoadout", { heroes = { "falcon", "ironman", "hawkeye", "bucky" } }, true)
check(reorderOk and reordered.loadout[1] == "falcon" and reordered.loadout[2] == "ironman", "Loadout order is preserved")
check(stores.Tests.values.p_1.loadout[1] == "falcon", "The ability slot is durable")

-- A rare chest that hits an epic, then the legendary chest with its pity counter.
service.random = scriptedRolls(0.9, 0)
local _, epicOk, epic = service:Handle(p1, "OpenChest", { chestId = "rare" }, true)
local epicHero
for id in pairs(epic.heroes) do if Catalog.Heroes[id].rarity == "rare" then epicHero = id end end
check(epicOk and epicHero ~= nil, "A high roll in the Alliance chest is now rare")
check(epic.pity.legendary == 0, "The rare chest keeps no pity counter")
for opening = 1, 9 do
	service:Award(p1, "pity-gold-" .. opening, { gold = 2000 })
	local goldBeforeOpen = service:Get(p1).gold
	-- A low rarity roll is a plain rare hero, which is never a top hero.
	service.random = scriptedRolls(0, opening / 20)
	local _, legendaryOk, snapshot = service:Handle(p1, "OpenChest", { chestId = "legendary" }, true)
	check(legendaryOk, "Legendary opening " .. opening)
	check(snapshot.pity.legendary == opening, "Each miss raises pity, opening " .. opening)
	local spent = goldBeforeOpen - snapshot.gold
	check(spent <= 2000 and spent >= 1700, "The low entry pool of the Legends chest keeps its original refund")
end
service:Award(p1, "chest-gold-2", { gold = 30000 })
service.random = scriptedRolls(0, 0.3)
local _, pityOk, pitySnapshot = service:Handle(p1, "OpenChest", { chestId = "legendary" }, true)
check(pityOk and pitySnapshot.pity.legendary == 0, "Pity resets when a top hero arrives")
local topFound = false
for id in pairs(pitySnapshot.heroes) do
	local rarity = Catalog.Heroes[id].rarity
	if rarity == "legendary" or rarity == "mythic" then topFound = true end
end
check(topFound, "The tenth legendary chest guarantees a legendary or better")

-- A response lost after the commit and a replayed callback still charge once
-- and add at most one hero, because the roll lives inside the committed transaction.
do
	service:Award(p1, "chest-gold-3", { gold = 5000 })
	replayCallback = true
	local goldNow, ownedNow = service:Get(p1).gold, 0
	for _ in pairs(service:Get(p1).heroes) do ownedNow += 1 end
	service.random = scriptedRolls(0.5, 0.1)
	failAfter = 1
	local _, replayOk = service:Handle(p1, "OpenChest", { chestId = "rare" }, true)
	replayCallback = false
	local ownedAfter = 0
	for _ in pairs(service:Get(p1).heroes) do ownedAfter += 1 end
	check(replayOk, "A chest survives a lost response")
	check(service:Get(p1).gold >= goldNow - 1000 and service:Get(p1).gold <= goldNow - 1000 + 1200, "A replayed callback cannot charge twice")
	check(ownedAfter == ownedNow or ownedAfter == ownedNow + 1, "A replayed callback cannot add two heroes")
end

-- Ability upgrades: gold, mastery and rank, all checked on the server.
do
	service:Award(p1, "ability-gold", { gold = 20000 })
	local goldNow = service:Get(p1).gold
	local _, wrongRank = service:Handle(p1, "UpgradeAbility", { heroId = "ironman", expectedRank = 3 }, true)
	check(not wrongRank and service:Get(p1).abilities.ironman == 1, "A stale rank is refused")
	local _, unowned = service:Handle(p1, "UpgradeAbility", { heroId = "captainmarvel", expectedRank = 1 }, true)
	check(not unowned, "A hero you do not own has no ability to improve")
	local _, notHero = service:Handle(p1, "UpgradeAbility", { heroId = "nobody", expectedRank = 1 }, true)
	check(not notHero, "Unknown heroes rejected")
	service:Award(p1, "ability-mastery", { mastery = { ironman = 300 } })
	check(service:Get(p1).heroes.ironman.level >= 3, "Mastery earned in matches unlocks ranks")
	local goldBeforeRank = service:Get(p1).gold
	local _, matchUpgrade = service:Handle(p1, "UpgradeAbility", { heroId = "ironman", expectedRank = 1 }, false)
	check(not matchUpgrade, "Abilities are upgraded in the lobby only")
	local _, upgradeOk, upgraded = service:Handle(p1, "UpgradeAbility", { heroId = "ironman", expectedRank = 1 }, true)
	check(upgradeOk and upgraded.abilities.ironman == 2, "Rank two bought")
	check(goldBeforeRank - upgraded.gold == 300, "Rank two costs 300 on a common hero")
	local _, again = service:Handle(p1, "UpgradeAbility", { heroId = "ironman", expectedRank = 1 }, true)
	check(not again and service:Get(p1).abilities.ironman == 2, "A retry cannot buy a rank twice")
	local _, tooSoon = service:Handle(p1, "UpgradeAbility", { heroId = "ironman", expectedRank = 2 }, true)
	check(not tooSoon, "Rank three needs mastery six")
	service:Award(p1, "ability-mastery-2", { mastery = { ironman = 100000 } })
	for rank = 2, 4 do
		local _, ok = service:Handle(p1, "UpgradeAbility", { heroId = "ironman", expectedRank = rank }, true)
		check(ok and service:Get(p1).abilities.ironman == rank + 1, "Rank " .. (rank + 1))
	end
	local _, maxed = service:Handle(p1, "UpgradeAbility", { heroId = "ironman", expectedRank = 5 }, true)
	check(not maxed and service:Get(p1).abilities.ironman == 5, "Rank five is the ceiling")
	-- A mythic hero costs more for the same rank; give the account one directly.
	local record = service.records[p1.UserId]
	record.profile.heroes.captainmarvel = { xp = 100000, level = 20 }
	record.profile.abilities.captainmarvel = 1
	stores.Tests.values.p_1.heroes.captainmarvel = { xp = 100000, level = 20 }
	stores.Tests.values.p_1.abilities.captainmarvel = 1
	service:Award(p1, "mythic-gold", { gold = 50000 })
	local mythicBefore = service:Get(p1).gold
	local _, mythicOk = service:Handle(p1, "UpgradeAbility", { heroId = "captainmarvel", expectedRank = 1 }, true)
	check(mythicOk and mythicBefore - service:Get(p1).gold == math.floor(300 * 4.5 + 0.5), "Rarer heroes cost more to improve")
end
local _, duplicateLoadout = service:Handle(p1, "SetLoadout", { heroes = { "ironman", "ironman" } }, true)
check(not duplicateLoadout, "Duplicate loadout rejected")
local _, unownedLoadout = service:Handle(p1, "SetLoadout", { heroes = { "doom" } }, true)
check(not unownedLoadout, "Unknown/unowned loadout rejected")
local _, malformedLoadout = service:Handle(p1, "SetLoadout", { heroes = { [1] = "ironman", evil = "hawkeye" } }, true)
check(not malformedLoadout, "Mixed-key forged loadout rejected")
local _, validLoadout = service:Handle(p1, "SetLoadout", { heroes = { "ironman", "falcon" } }, true)
check(validLoadout and #service:Get(p1).loadout == 2, "Valid loadout persisted")
local _, sixHeroes = service:Handle(p1, "SetLoadout", { heroes = { "ironman", "hawkeye", "falcon", "bucky", "thor", "hulk" } }, true)
check(not sixHeroes, "A loadout holds five heroes at most")
local _, emptyLoadout = service:Handle(p1, "SetLoadout", { heroes = {} }, true)
check(not emptyLoadout and #service:Get(p1).loadout == 2, "A loadout cannot be empty")
-- One team, always: saved formations are gone from the contract.
local savedAction = service:Handle(p1, "SaveLoadout", { slot = 1 }, true)
check(not savedAction and service:Get(p1).savedLoadouts == nil and service:Get(p1).loadoutSlots == nil, "There is one team and no formation slots")

-- Developer receipts remain pending without durable storage and grant exactly once.
local goldBeforeReceipts = service:Get(p1).gold
local receipt = { PlayerId = 1, ProductId = 101, PurchaseId = "purchase-1" }
failAfter = 1
check(service:_receipt(receipt) == "granted", "Receipt succeeds after commit response lost")
check(service:Get(p1).gold == goldBeforeReceipts + 1000, "Receipt adds gold once")
check(service:_receipt(receipt) == "granted" and service:Get(p1).gold == goldBeforeReceipts + 1000, "Receipt replay acknowledged without gold")
failBefore = 3
check(service:_receipt({ PlayerId = 1, ProductId = 101, PurchaseId = "purchase-2" }) == "pending", "Storage failure leaves receipt pending")
check(service:Get(p1).gold == goldBeforeReceipts + 1000, "Failed receipt doesn't mutate memory")
check(service:_receipt({ PlayerId = 1, ProductId = 101, PurchaseId = "purchase-2" }) == "granted", "Pending receipt can retry")
check(service:Get(p1).gold == goldBeforeReceipts + 2000, "Pending receipt grants later exactly once")
check(service:_receipt({ PlayerId = 1, ProductId = 9999, PurchaseId = "unknown-product" }) == "pending", "Unknown products remain pending")
check(service:_receipt({ PlayerId = 9999, ProductId = 101, PurchaseId = "offline" }) == "pending", "Offline receipts remain pending")
local _, productOK, productInfo = service:Handle(p1, "ProductInfo", { kind = "product", key = "gold1000" }, true)
check(productOK and productInfo.price == 87 and productInfo.id == 101, "Actual platform price used")
local _, unconfigured = service:Handle(p1, "ProductInfo", { kind = "product", key = "gold12000" }, true)
check(not unconfigured, "ID zero disabled")

-- Heroes bought directly with Robux: priced by the platform, granted exactly once.
local _, heroInfoOk, heroInfo = service:Handle(p1, "ProductInfo", { kind = "hero", key = "thor" }, true)
check(heroInfoOk and heroInfo.id == 302 and heroInfo.price == 87, "A hero product reports the platform price")
local _, notConfiguredHero = service:Handle(p1, "ProductInfo", { kind = "hero", key = "wanda" }, true)
check(not notConfiguredHero, "A hero without a product id is unavailable")
local _, ownedHero = service:Handle(p1, "ProductInfo", { kind = "hero", key = "falcon" }, true)
check(not ownedHero, "A hero you own is not for sale")
local _, starterHero = service:Handle(p1, "ProductInfo", { kind = "hero", key = "ironman" }, true)
check(not starterHero, "A starter is never sold")
local goldBeforeThor = service:Get(p1).gold
local thorReceipt = { PlayerId = 1, ProductId = 302, PurchaseId = "thor-1" }
failAfter = 1
check(service:_receipt(thorReceipt) == "granted", "A hero receipt survives a lost response")
check(service:Get(p1).heroes.thor and service:Get(p1).abilities.thor == 1, "The purchased hero arrives with its ability")
check(service:Get(p1).gold == goldBeforeThor, "A new hero purchase gives no gold")
local loadoutBefore = #service:Get(p1).loadout
check(service:_receipt(thorReceipt) == "granted" and #service:Get(p1).loadout == loadoutBefore, "A replayed hero receipt is inert")
-- A second purchase of a hero already owned is never wasted: it becomes gold.
check(service:_receipt({ PlayerId = 1, ProductId = 302, PurchaseId = "thor-2" }) == "granted", "A duplicate purchase is still acknowledged")
check(service:Get(p1).gold == goldBeforeThor + Catalog.Products.Heroes.thor.price * 10, "A duplicate purchase refunds gold, 10 per Robux")
check(service:_receipt({ PlayerId = 1, ProductId = 302, PurchaseId = "thor-1" }) == "granted" and service:Get(p1).gold == goldBeforeThor + Catalog.Products.Heroes.thor.price * 10, "The receipt ledger stays exact")
failBefore = 3
check(service:_receipt({ PlayerId = 1, ProductId = 301, PurchaseId = "falcon-x" }) == "pending", "A storage failure leaves a hero receipt pending")
failBefore = 0

-- The starter pack: an epic hero and Gold, once per account.
do
	local pack = Catalog.Products.Consumables.starterPack
	local before = service:Get(p1)
	check(before.starterPack == false and not before.heroes[pack.heroId], "A new account has not bought the starter pack")
	local goldBefore = before.gold
	check(service:_receipt({ PlayerId = 1, ProductId = 103, PurchaseId = "starter-1" }) == "granted", "The starter pack is granted")
	local after = service:Get(p1)
	check(after.starterPack == true and after.heroes[pack.heroId] ~= nil and after.gold == goldBefore + pack.gold,
		"It brings its hero, its Gold and marks the account")
	check(service:_receipt({ PlayerId = 1, ProductId = 103, PurchaseId = "starter-1" }) == "granted" and service:Get(p1).gold == goldBefore + pack.gold,
		"A replayed starter receipt is inert")
	check(service:_receipt({ PlayerId = 1, ProductId = 103, PurchaseId = "starter-2" }) == "granted"
		and service:Get(p1).gold == goldBefore + pack.gold * 2 + pack.repeatGold, "Bought again, the pack pays Gold instead of a second hero")
end

-- Some regions restrict paid random items, so Gold packs are withheld there.
do
	services.PolicyService = { GetPolicyInfoForPlayerAsync = function(_, who)
		return { ArePaidRandomItemsRestricted = who.UserId == 7 }
	end }
	local restricted, free = player(7), player(8)
	local regional = PlayerService.new(config, Catalog, nil, Rules)
	regional:Load(restricted); regional:Load(free)
	check(regional:Snapshot(restricted).paidRandomRestricted == true, "The policy reaches the snapshot")
	local _, packRestricted = regional:Handle(restricted, "ProductInfo", { kind = "product", key = "gold1000" }, true)
	check(not packRestricted, "Gold packs are unavailable to a restricted player")
	local _, packFree = regional:Handle(free, "ProductInfo", { kind = "product", key = "gold1000" }, true)
	check(packFree, "Gold packs are available elsewhere")
	local _, passRestricted = regional:Handle(restricted, "ProductInfo", { kind = "pass", key = "collector" }, true)
	check(passRestricted, "Passes stay available to a restricted player")
	local _, heroRestricted = regional:Handle(restricted, "ProductInfo", { kind = "hero", key = "thor" }, true)
	check(heroRestricted, "Direct hero purchases stay available to a restricted player")
	regional:Award(restricted,"restricted-test-budget",{gold=3000})
	local beforeRestricted=regional:Get(restricted).gold
	local _, restrictedChest = regional:Handle(restricted, "OpenChest", { chestId = "rare" }, true)
	check(not restrictedChest and regional:Get(restricted).gold==beforeRestricted, "Restricted random purchases rejected even with sufficient gold")
	services.PolicyService = nil
end

-- Lease prevents concurrent servers; releasing permits the next place to load.
local goldAtHandoff = service:Get(p1).gold
local other = PlayerService.new(config, Catalog, nil, Rules)
local locked = other:Load(p1)
check(locked == nil, "Second server cannot take an active lease")
service:Release(p1)
check(service:Get(p1) == nil, "Released state no longer served")
local transferred = other:Load(p1)
check(transferred and transferred.gold == goldAtHandoff and transferred.heroes.falcon and transferred.heroes.thor, "Transfer retains durable progress")
check(other:_receipt(receipt) == "granted" and other:Get(p1).gold == goldAtHandoff, "Receipt survives server changes")
service = other

-- Paid boosts have no unique power ceiling; only server-verified ownership applies.
passOwners["1:202"] = true
service:_refreshPasses(p1)
check(service:Get(p1).passes.training, "Verified pass ownership")
local beforeXP = service:Get(p1).xp
local beforeMastery = service:Get(p1).heroes.ironman.xp
check(service:Award(p1, "training-test", { xp = 100, mastery = { ironman = 100 } }), "Training award")
check(service:Get(p1).xp == beforeXP + 125 and service:Get(p1).heroes.ironman.xp == beforeMastery + 125, "Training boost applied to both XP types")

check(service:Award(p1, "max-level", { xp = 1000000, gold = 100000, mastery = { ironman = 100000 } }), "Large legitimate progression award")
local leveled = service:Get(p1)
check(leveled.level == 50 and leveled.heroes.ironman.level == 20 and leveled.heroes.ironman.awakened, "Account and mastery level caps")
check(leveled.skills == nil and leveled.skillSlots == nil and leveled.skillOffers == nil, "The old skill slots and offers are gone")
local _, oldSkill = service:Handle(p1, "BuySkill", { skillId = "scan" }, true)
check(not oldSkill, "Buying skills is no longer possible")
local _, oldSlots = service:Handle(p1, "SetSkills", { active = { "overload" }, passive = {} }, true)
check(not oldSlots, "Equipping skills is no longer possible")
local _, invalidSettings = service:Handle(p1, "Settings", { lowFX = "true" }, false)
check(not invalidSettings, "Settings type validation")
local _, settings = service:Handle(p1, "Settings", { language = "en", lowFX = true, shake = false }, false)
check(settings and service:Get(p1).settings.language == "en", "Accessibility settings during match")
local _, effectsMuted = service:Handle(p1, "Settings", { effects = false }, false)
check(effectsMuted and service:Get(p1).settings.effects == false and service:Get(p1).settings.music == true, "Sound effects mute independently of music")
local _, invalidEffects = service:Handle(p1, "Settings", { effects = 0 }, false)
check(not invalidEffects and service:Get(p1).settings.effects == false, "Invalid sound option cannot change saved preference")
local _, pace = service:Handle(p1, "Settings", { autoSkip = true, fastForward = true }, false)
check(pace and service:Get(p1).settings.autoSkip == true and service:Get(p1).settings.fastForward == true, "2x and auto-skip are remembered, even from inside a match")
local _, invalidPace = service:Handle(p1, "Settings", { fastForward = 2 }, false)
check(not invalidPace and service:Get(p1).settings.fastForward == true, "A malformed speed preference is refused")

-- First clear, daily bonus, quests, and medals.
local goldBefore = service:Get(p1).gold
service:Award(p1, "normal-first", { gold = 300, xp = 0, victory = true, finished = true, modeId = "normal", mapId = "manhattan", noDamage = true, waves = 15, bosses = 1 })
check(service:Get(p1).gold == goldBefore + 800 and service:Get(p1).campaign.manhattan.normal, "First normal clear plus base completion")
check(service:Get(p1).achievements["medal:manhattan"] ~= nil, "No damage medal")
service:Award(p1, "normal-repeat", { gold = 300, victory = true, finished = true, modeId = "normal", mapId = "manhattan" })
check(service:Get(p1).gold == goldBefore + 1100, "First clear bonus cannot repeat")
service:Award(p1, "ranked-first", { gold = 450, victory = true, finished = true, modeId = "ranked", mapId = "gamma" })
check(service:Get(p1).campaign.gamma.ranked == true and service:Get(p1).achievements.hardWin ~= nil, "A legacy ranked clear is still recorded")
service:Award(p1, "cards-first", { gold = 300, victory = true, finished = true, modeId = "cards", mapId = "hydra" })
check(service:Get(p1).campaign.hydra.cards == true and service:Get(p1).achievements.cardsWin ~= nil, "A card-mode clear is recorded")
check(Rules.ModeUnlocked(service:Get(p1), "ranked") and Rules.ModeUnlocked(service:Get(p1), "cards"), "The profile's own record opens the later modes")
service:Award(p1, "daily-ghost", { gold = 300, victory = true, finished = true, modeId = "daily", mapId = "manhattan" })
for _, mapId in ipairs(Catalog.MapOrder) do
	service:Award(p1, "clear-" .. mapId, { gold = 0, victory = true, finished = true, modeId = "normal", mapId = mapId })
end
check(service:Get(p1).achievements.campaign ~= nil and service:Get(p1).achievements.campaign.kind == "title", "Clearing all five maps earns the campaign title")
goldBefore = service:Get(p1).gold
-- Both callbacks yield like network requests; the per-player FIFO must preserve
-- both grants without one stale snapshot overwriting the other.
goldBefore = service:Get(p1).gold
scheduleUpdates = true
local first = coroutine.create(function() check(service:Award(p1, "concurrent-a", { gold = 17 }), "First concurrent award") end)
local second = coroutine.create(function() check(service:Award(p1, "concurrent-b", { gold = 23 }), "Second concurrent award") end)
local turns = 0
while coroutine.status(first) ~= "dead" or coroutine.status(second) ~= "dead" do
	turns += 1
	assert(turns < 20, "Queue deadlocked")
	for _, thread in ipairs({ first, second }) do
		if coroutine.status(thread) ~= "dead" then local success, problem = coroutine.resume(thread); assert(success, tostring(problem)) end
	end
end
scheduleUpdates = false
check(service:Get(p1).gold == goldBefore + 40, "Serialized concurrent grants preserve both balances")
local questId
for id, quest in pairs(service:Get(p1).quests) do
	if quest.kind == "waves" and quest.period == "daily" and quest.progress >= quest.target then questId = id; break end
end
check(questId ~= nil, "Daily quests progress from verified reward deltas")
goldBefore = service:Get(p1).gold
local _, claimed = service:Handle(p1, "ClaimQuest", { questId = questId }, true)
local _, reclaimed = service:Handle(p1, "ClaimQuest", { questId = questId }, true)
check(claimed and not reclaimed and service:Get(p1).gold == goldBefore + 150, "Quest reward claimed exactly once")
check(not service:Award(p1, "nan", { gold = 0 / 0 }), "NaN rewards rejected")

-- Missions rotate: the wave mission every day plus two drawn from the pool.
do
	local seen = {}
	for day = 20000, 20020 do
		local keys = PlayerService.QuestKeys("daily", day)
		check(#keys == 3 and keys[1] == "waves", "Every day brings three missions, the wave mission first")
		local distinct = {}
		for _, key in ipairs(keys) do distinct[key] = true; seen[key] = true end
		check(next(distinct) ~= nil and (function() local n = 0 for _ in pairs(distinct) do n += 1 end return n end)() == 3, "A day's missions are all different")
		check(table.concat(keys, ",") == table.concat(PlayerService.QuestKeys("daily", day), ","), "The same day always draws the same missions")
	end
	local kinds = 0
	for _ in pairs(seen) do kinds += 1 end
	check(kinds >= 6, "Three weeks of days use at least six mission kinds, got " .. kinds)
	local week = PlayerService.QuestKeys("weekly", 2857)
	check(#week == 3 and week[1] == "waves" and week[2] == "bosses", "A week brings the wave and boss missions plus one more")
	-- Every mission says what it asks for, in both languages, apart from its name.
	for id, quest in pairs(service:Get(p1).quests) do
		check(#quest.description.pt > 10 and #quest.description.en > 10 and quest.description.pt ~= quest.name.pt and quest.description.en ~= quest.name.en, "The mission " .. id .. " has its own description")
	end
	-- A new account gets today's three missions and the week's three, not a catch-up of earlier days.
	local newbie = player(82)
	service:Load(newbie)
	check(service:Award(newbie, "q:first", { waves = 1 }), "a first award is accepted")
	local daily, weekly = 0, 0
	for _, quest in pairs(service:Get(newbie).quests) do
		if quest.period == "daily" then daily += 1 else weekly += 1 end
	end
	check(daily == 3 and weekly == 3, "A new account has 3 daily and 3 weekly missions, got " .. daily .. "/" .. weekly)
	-- Progress for the new kinds, from verified reward deltas only.
	local record = stores.Tests.values.p_1
	local function mission(key, target) record.quests["test:" .. key] = { id = "test:" .. key, kind = key, period = "daily", name = { pt = key, en = key }, progress = 0, target = target, gold = 1, xp = 1, claimed = false, expiresAt = os.time() + 86400, heroIds = {} } end
	for key, target in pairs({ gold = 1500, campaign = 2, noDamage = 2, cards = 1, chests = 2 }) do mission(key, target) end
	service:Award(p1, "mission-run", { gold = 700, victory = true, finished = true, modeId = "normal", mapId = "manhattan", noDamage = true, waves = 3 })
	local quests = service:Get(p1).quests
	check(quests["test:gold"].progress == 700, "The gold mission counts the gold earned")
	check(quests["test:campaign"].progress == 1 and quests["test:noDamage"].progress == 1, "A finished flawless campaign win counts for both")
	check(quests["test:cards"].progress == 0, "A campaign win is no card win")
	service:Award(p1, "mission-cards", { gold = 100, victory = true, finished = true, modeId = "cards", mapId = "hydra" })
	check(service:Get(p1).quests["test:cards"].progress == 1, "A card-mode win counts for the card mission")
	local goldMissionBefore = service:Get(p1).quests["test:gold"].progress
	service:Award(p1, "mission-training", { gold = 900, victory = true, finished = true, modeId = "tutorial", mapId = "manhattan", tutorial = true })
	check(service:Get(p1).quests["test:gold"].progress == goldMissionBefore, "Training counts for none of the new missions")
end
check(not service:Award(p1, "negative", { gold = -1 }), "Negative rewards rejected")

-- Persistent leaderboard outbox, monotonic max, separated sizes, and tied ranks.
service:Load(p2)
check(service:RecordBest(p1, "hydra", 1, 45, "ranked"), "Best score accepted")
check(service:_flushBoards(p1), "Leaderboard outbox flush")
check(service:RecordBest(p1, "hydra", 1, 20, "ranked"), "Lower score ignored safely")
service:RecordBest(p2, "hydra", 1, 45, "ranked")
service:_flushBoards(p2)
local leaderboard = service:Leaderboard("hydra", 1, nil, "ranked")
check(#leaderboard == 2 and leaderboard[1].waves == 45 and leaderboard[2].waves == 45, "OrderedDataStore max preserves best")
check(leaderboard[1].rank == 1 and leaderboard[2].rank == 1, "Ties share rank")
check(#service:Leaderboard("hydra", 2, nil, "ranked") == 0, "Party sizes have separate boards")
check(#service:Leaderboard("hydra", 1, "all", "ranked") == 2, "All-time board is queryable")
check(#service:Leaderboard("wakanda", 1, nil, "ranked") == 0, "Each map has its own board")
check(service:Leaderboard("hydra", 1, "s99999", "ranked") == nil, "Future seasons rejected")
local key = service:_boardKey("hydra", 1, "s" .. tostring(service:_season()), "ranked")
check(service:Get(p1).best[key] == 45, "Personal best persisted")
check(string.sub(key, 1, 6) == "comp2:", "A new competitive version: the old ranked and endless boards stay archived")

check(service:RecordBest(p1,"hydra",1,75,"ranked"),"Competitive is endless: waves past 50 are accepted")
check(service:_flushBoards(p1),"Competitive score flushes durably")
check(service:RecordBest(p1,"hydra",1,10,"ranked"),"Lower competitive score cannot erase best")
check(service:Leaderboard("hydra",1,nil,"ranked")[1].waves==75,"The endless record climbs past 50")
check(not service:RecordBest(p1,"hydra",1,30,"infinite"),"The removed casual endless mode records nothing")
check(not service:RecordBest(p1,"hydra",1,30),"A result without the competitive mode records nothing")
check(service:Leaderboard("hydra",1,nil,"infinite")==nil,"The removed endless board is not served")
check(service:Leaderboard("hydra",1,nil,"invalid")==nil,"Unknown competitive mode refused")
check(Rules.RankForWaves(9).minimum==0 and Rules.RankForWaves(10).pt=="Bronze","Rank uses completed wave threshold")
check(Rules.RankForWaves(49).pt=="Diamante" and Rules.RankForWaves(50).pt=="Lenda","Legend requires clearing final wave")
check(next(service.records[p1.UserId].profile._pendingBoards) == nil, "Confirmed outbox entries removed")

-- Existing profiles are never replaced on failed or corrupted loads.
local p3 = player(3)
failBefore = 3
check(service:Load(p3) == nil and stores.Tests.values.p_3 == nil, "Failed load doesn't create blank saved data")
stores.Tests.values.p_3 = { schemaVersion = 999, gold = 7654, xp = 0, heroes = {} }
check(service:Load(p3) == nil and stores.Tests.values.p_3.gold == 7654, "Future schema fails closed")

-- Expired owner cannot mutate after another server acquires the profile.
stores.Tests.values.p_2._session.expires = 0
local takeover = PlayerService.new(config, Catalog, nil, Rules)
check(takeover:Load(p2) ~= nil, "Expired lease can be acquired")
check(not service:Award(p2, "stale-server", { gold = 1000 }), "Old server cannot overwrite new owner")
check(service:Get(p2) == nil and takeover:Get(p2).gold == 0, "Lost session revoked locally")

isStudio = true
local localOnly = PlayerService.new(config, Catalog, nil, Rules)
local p4 = player(4)
check(localOnly.memory and localOnly:Load(p4) ~= nil, "Studio memory opt-in")
local beforeUnlock = clone(localOnly:Get(p4))
check(localOnly:StudioUnlock(p4), "Studio review can unlock its memory profile")
for mapId in pairs(Catalog.Maps) do check(localOnly:Get(p4).campaign[mapId].normal == true, "Review unlock opens campaign map " .. mapId) end
check(localOnly:Get(p4).gold == beforeUnlock.gold and localOnly:Get(p4).xp == beforeUnlock.xp, "Review unlock grants no economy or XP")
check(not localOnly:StudioUnlock({ UserId = p4.UserId }), "Review unlock rejects a different player instance")
check(localOnly:StudioGrant(p4, {"ironman", "hulk"}) and localOnly:Save(p4), "A memory save accepts the review roster")
check(localOnly:Get(p4).tutorialComplete and localOnly:Get(p4).campaign.gamma.normal, "Review unlock survives an automatic memory save")
check(localOnly:Get(p4).heroes.hulk ~= nil and localOnly:Get(p4).loadout[2] == "hulk", "Review heroes survive the next memory transaction")
check(localOnly:_receipt({ PlayerId = 4, ProductId = 101, PurchaseId = "studio-purchase" }) == "pending", "Memory mode cannot acknowledge real purchases")
local _, studioPurchase = localOnly:Handle(p4, "ProductInfo", { kind = "product", key = "gold1000" }, true)
check(not studioPurchase, "Studio memory shop disabled")

-- Talent points are derived from earned levels, never bought or client supplied.
check(localOnly:Snapshot(p4).talentPoints == 0, "Level one starts with zero talent points")
local _, noPoint = localOnly:Handle(p4, "UpgradeTalent", {talentId="roundGold",expectedRank=0}, true)
check(not noPoint, "Cannot spend an unearned point")
check(localOnly:Award(p4, "talent-xp", {xp=1000000}), "Earn talent points through server awards")
check(localOnly:Snapshot(p4).talentPoints == 49, "Level fifty supplies exactly forty-nine points")
local _, locked = localOnly:Handle(p4, "UpgradeTalent", {talentId="killGold",expectedRank=0}, true)
check(not locked, "Branch prerequisite enforced")
local _, invested = localOnly:Handle(p4, "UpgradeTalent", {talentId="roundGold",expectedRank=0}, true)
local _, duplicate = localOnly:Handle(p4, "UpgradeTalent", {talentId="roundGold",expectedRank=0}, true)
check(invested and not duplicate and localOnly:Snapshot(p4).talentPoints == 48, "Retry cannot spend a second point")
local _, battleEdit = localOnly:Handle(p4, "UpgradeTalent", {talentId="roundGold",expectedRank=1}, false)
check(not battleEdit, "Talent changes rejected during matches")
for rank=1,4 do local _, ok = localOnly:Handle(p4,"UpgradeTalent",{talentId="roundGold",expectedRank=rank},true); check(ok,"Valid root investment") end
local _, capped = localOnly:Handle(p4,"UpgradeTalent",{talentId="roundGold",expectedRank=5},true)
check(not capped, "Node rank cap enforced")
local _, child = localOnly:Handle(p4,"UpgradeTalent",{talentId="killGold",expectedRank=0},true)
check(child and localOnly:Snapshot(p4).talentPoints == 43,"Unlocked branch spends one point")
local _, resetBattle = localOnly:Handle(p4,"ResetTalents",{},false)
check(not resetBattle,"Reset rejected during matches")
local goldBeforeReset = localOnly:Get(p4).gold
local _, reset = localOnly:Handle(p4,"ResetTalents",{},true)
check(reset and localOnly:Snapshot(p4).talentPoints == 49 and next(localOnly:Get(p4).talents)==nil and localOnly:Get(p4).gold==goldBeforeReset,"Free reset restores all points")
local _, persistTalent = service:Handle(p1,"UpgradeTalent",{talentId="baseVitality",expectedRank=0},true)
check(persistTalent and stores.Tests.values.p_1.talents.baseVitality == 1,"Talent is durable before acknowledgement")
local budgetBefore = service:Snapshot(p1).talentPoints
service:Award(p1,"max-level",{xp=1000000})
check(service:Snapshot(p1).talentPoints == budgetBefore,"Repeated XP checkpoint does not duplicate points")

-- A profile written by an older version loads: it is healed, never rejected.
do
	local legacyPlayer = player(5)
	stores.Tests.values.p_5 = {
		schemaVersion = 1, gold = 1234, xp = 5000, level = 9,
		heroes = { ironman = { xp = 0, level = 1 }, hawkeye = { xp = 0, level = 1 }, spiderman = { xp = 400, level = 1 }, retired = { xp = 10, level = 1 } },
		loadout = { "spiderman", "ghost", "spiderman", "ironman" },
		skills = { overload = 2, magnet = 1 }, activeSkills = { "overload" }, passives = { "magnet" },
		-- barrierPower no longer exists; victoryGold's parent (magnet) has no rank.
		talents = { roundGold = 2, killGold = 1, barrierPower = 3, victoryGold = 4 },
		campaign = {}, tutorialComplete = true, settings = { language = "pt", lowFX = false, shake = true },
		-- Unlocked under the old names: they follow today's names on load.
		achievements = {
			allHeroes = { name = { pt = "Vingadores reunidos", en = "Avengers assembled" }, unlockedAt = 5, kind = "achievement" },
			["medal:hydra"] = { name = { pt = "Defesa perfeita: Instalação da HYDRA", en = "Flawless defense: HYDRA Facility" }, unlockedAt = 6, kind = "medal", mapId = "hydra" },
			firstChest = { name = { pt = "Primeiro baú", en = "First chest" }, unlockedAt = 7, kind = "achievement" },
		},
	}
	local healed = service:Load(legacyPlayer)
	check(healed and healed.achievements.allHeroes.name.pt == "Coleção completa" and healed.achievements.allHeroes.unlockedAt == 5,
		"An achievement unlocked under an old name shows today's name and keeps its date")
	check(healed and healed.achievements["medal:hydra"].name.pt == "Defesa perfeita: " .. Catalog.Maps.hydra.name.pt,
		"A map medal follows the map's current name")
	check(healed and healed.achievements.firstChest.name.pt == "Primeiro baú", "Other achievements keep their names")
	check(healed ~= nil, "An older profile still loads")
	check(healed.gold == 1234 and healed.xp == 5000, "Gold and experience survive the migration")
	check(healed.skills == nil and healed.activeSkills == nil and healed.passives == nil, "Legacy skill fields are dropped")
	check(healed.talents.roundGold == 2 and healed.talents.killGold == 1, "Valid talents survive")
	check(healed.talents.barrierPower == nil and healed.talents.victoryGold == nil, "Removed or unreachable talents are dropped, not fatal")
	check(healed.talentPoints == healed.level - 1 - 3, "Points are recomputed from what remains")
	check(#healed.loadout == 2 and healed.loadout[1] == "spiderman" and healed.loadout[2] == "ironman", "The loadout keeps its order, drops unknown heroes and duplicates")
	check(healed.abilities.spiderman == 1 and healed.abilities.ironman == 1 and healed.abilities.hawkeye == 1, "Every owned hero gains an ability rank")
	check(healed.pity.legendary == 0, "The pity counter is created")
	check(healed.rewards ~= nil and healed.rewards.freeChest.ready and healed.rewards.login.claimable, "A legacy profile with no reward record at all gets a fresh one")
	stores.Tests.values.p_6 = { schemaVersion = 1, gold = 10, xp = 0, heroes = { ironman = { xp = 0, level = 1 } }, loadout = { "ghost" }, talents = { roundGold = 50 } }
	local repaired = service:Load(player(6))
	check(repaired and repaired.loadout[1] == "ironman" and repaired.talents.roundGold == nil, "An empty loadout falls back to the starters and impossible ranks are dropped")
	stores.Tests.values.p_9 = { schemaVersion = 1, gold = 10, xp = 0, heroes = { ironman = { xp = 0, level = 1 } }, talents = { roundGold = 5, killGold = 5, magnet = 5, victoryGold = 10 } }
	check(service:Load(player(9)) == nil and stores.Tests.values.p_9.gold == 10, "A talent budget the level cannot pay for still fails closed")
end

--==============================================================================
-- Rewards: free chest, login streak, playtime gifts, collection milestones
--==============================================================================
-- Every day-spanning check here moves the frozen clock by hand instead of
-- waiting; the session lease is stretched so a multi-day jump cannot expire it
-- mid-section. Each sub-section uses its own fresh player so the incidental
-- playtime a claim's own transaction accumulates (the gap since the account's
-- last save) never contaminates a different section's expectations.
do
	local realLease = service.leaseSeconds
	service.leaseSeconds = 1e9

	-- The free chest: opens on the spot for nothing, then makes you wait.
	do
		local rewarded = player(20)
		local fresh = service:Load(rewarded)
		check(fresh.rewards.freeChest.ready and fresh.rewards.login.claimable, "A new account has a free chest and a login reward waiting")
		check(fresh.rewards.claimable == 2, "The badge counts exactly what a brand new account can claim, got " .. tostring(fresh.rewards.claimable))

		service.random = scriptedRolls(0, 0)
		local _, chestOk, chest = service:Handle(rewarded, "ClaimFreeChest", {}, true)
		check(chestOk and chest.result.chest.heroId ~= nil and chest.result.gold == 0 and chest.result.xp == 0, "The free chest costs nothing and grants a hero")
		check(chest.stats.chests == 1 and chest.heroes[chest.result.chest.heroId] ~= nil, "The free chest's hero joins the account and is counted")
		check(not chest.rewards.freeChest.ready and chest.rewards.freeChest.remaining == Catalog.Rewards.freeChest.cooldown, "The free chest starts its timer")
		local _, tooSoon = service:Handle(rewarded, "ClaimFreeChest", {}, true)
		check(not tooSoon, "The free chest cannot be claimed twice")
		local _, notInMatch = service:Handle(rewarded, "ClaimFreeChest", {}, false)
		check(not notInMatch, "Rewards are claimed in the lobby, not mid-match")

		clockOffset += Catalog.Rewards.freeChest.cooldown - 1
		local _, almost = service:Handle(rewarded, "ClaimFreeChest", {}, true)
		check(not almost, "One second early is still early")
		clockOffset += 1
		check(service:Get(rewarded).rewards.freeChest.ready, "The free chest is ready the instant the timer ends")
		service.random = scriptedRolls(0, 0)
		local _, secondChest = service:Handle(rewarded, "ClaimFreeChest", {}, true)
		check(secondChest, "The free chest can be claimed again after the wait")
	end

	-- The login streak: one a day, a missed day forgiven, two missed days reset.
	do
		local streaker = player(23)
		service:Load(streaker)
		local _, day1Ok, day1 = service:Handle(streaker, "ClaimLogin", {}, true)
		check(day1Ok and day1.result.day == 1 and day1.result.streak == 1 and day1.result.gold == Catalog.Rewards.login[1].gold, "Day one pays the first reward")
		local goldAfterDay1 = day1.gold
		local _, sameDay = service:Handle(streaker, "ClaimLogin", {}, true)
		check(not sameDay and service:Get(streaker).gold == goldAfterDay1, "Today's login reward can only be claimed once")

		clockOffset += 86400
		local _, day2Ok, day2 = service:Handle(streaker, "ClaimLogin", {}, true)
		check(day2Ok and day2.result.day == 2 and day2.result.streak == 2 and day2.result.gold == Catalog.Rewards.login[2].gold, "The next consecutive day continues the streak")

		clockOffset += 2 * 86400
		local _, graceOk, grace = service:Handle(streaker, "ClaimLogin", {}, true)
		check(graceOk and grace.result.streak == 3 and grace.result.day == 3, "One missed day is forgiven")

		clockOffset += 3 * 86400
		local _, resetOk, reset = service:Handle(streaker, "ClaimLogin", {}, true)
		check(resetOk and reset.result.streak == 1 and reset.result.day == 1, "Two missed days reset the streak")

		local sawChestDay
		for day = 2, #Catalog.Rewards.login do
			clockOffset += 86400
			service.random = scriptedRolls(0.5, 0.5)
			local _, ok, claimed = service:Handle(streaker, "ClaimLogin", {}, true)
			check(ok and claimed.result.day == day and claimed.result.streak == day, "Consecutive day " .. day .. " of the cycle")
			if claimed.result.chest then sawChestDay = day end
			local def = Catalog.Rewards.login[day]
			if def.xp then check(claimed.result.xp == def.xp, "Login xp is paid on day " .. day) end
		end
		check(sawChestDay == #Catalog.Rewards.login, "The last day of the cycle opens a chest, got " .. tostring(sawChestDay))

		clockOffset += 86400
		local _, wrapOk, wrap = service:Handle(streaker, "ClaimLogin", {}, true)
		check(wrapOk and wrap.result.day == 1 and wrap.result.streak == #Catalog.Rewards.login + 1, "The seven-day cycle restarts, but the streak keeps counting up")
	end

	-- Playtime gifts: how long the account has been in the game today.
	do
		local grinder = player(24)
		service:Load(grinder)
		local _, early = service:Handle(grinder, "ClaimPlaytime", { index = 1 }, true)
		check(not early, "A gift is not ready before its minutes have passed")

		clockOffset += Catalog.Rewards.playtime[1].minutes * 60
		check(service:Get(grinder).rewards.playtime.gifts[1].ready, "The gift becomes ready as time passes")
		local before = service:Get(grinder).gold
		local _, giftOk, gift = service:Handle(grinder, "ClaimPlaytime", { index = 1 }, true)
		check(giftOk and gift.gold == before + Catalog.Rewards.playtime[1].gold, "The gift pays its gold")
		local _, giftAgain = service:Handle(grinder, "ClaimPlaytime", { index = 1 }, true)
		check(not giftAgain, "A gift pays once a day")
		local _, later = service:Handle(grinder, "ClaimPlaytime", { index = 2 }, true)
		check(not later, "Time does not skip ahead to a gift that needs more of it")
		for _, badIndex in ipairs({ 0, 99, 1.5, -1 }) do
			local _, invalid = service:Handle(grinder, "ClaimPlaytime", { index = badIndex }, true)
			check(not invalid, "Invalid gift index rejected: " .. tostring(badIndex))
		end
		for _, badIndex in ipairs({ "1", false, {} }) do
			local _, invalid = service:Handle(grinder, "ClaimPlaytime", { index = badIndex }, true)
			check(not invalid, "A non-numeric gift index is rejected: " .. tostring(badIndex))
		end

		clockOffset += 86400
		local _, renewed = service:Handle(grinder, "ClaimPlaytime", { index = 1 }, true)
		check(renewed, "Yesterday's claimed gift can be earned again today")
	end

	-- Collection milestones: how many different heroes the account owns, once each.
	do
		local collector = player(21)
		stores.Tests.values.p_21 = { schemaVersion = 1, gold = 0, xp = 0, heroes = {}, loadout = { "ironman" } }
		for index, heroId in ipairs(Catalog.HeroOrder) do
			if index <= 12 then stores.Tests.values.p_21.heroes[heroId] = { xp = 0, level = 1 } end
		end
		local loaded = service:Load(collector)
		check(loaded.rewards.collection.owned == 12, "The panel counts the collection")
		local ready = 0
		for _, milestone in ipairs(loaded.rewards.collection.milestones) do if milestone.ready then ready += 1 end end
		check(ready == 4, "Four milestones are ready with twelve heroes, got " .. ready)

		local _, notYet = service:Handle(collector, "ClaimMilestone", { index = 8 }, true)
		check(not notYet, "The last milestone needs every hero")
		local goldBefore = loaded.gold
		local _, mOk, milestone = service:Handle(collector, "ClaimMilestone", { index = 4 }, true)
		check(mOk and milestone.gold == goldBefore + Catalog.Rewards.collection[4].gold, "A milestone pays its gold")
		check(milestone.titles.collector ~= nil, "The collector title is awarded")
		local _, mAgain = service:Handle(collector, "ClaimMilestone", { index = 4 }, true)
		check(not mAgain and service:Get(collector).gold == milestone.gold, "A milestone pays once")
		local _, mTooMany = service:Handle(collector, "ClaimMilestone", { index = 5 }, true)
		check(not mTooMany, "A milestone needs its full count, not just the gold to pretend")
		for _, badIndex in ipairs({ 0, 9, 2.5 }) do
			local _, invalid = service:Handle(collector, "ClaimMilestone", { index = badIndex }, true)
			check(not invalid, "Invalid milestone index rejected: " .. tostring(badIndex))
		end
	end

	-- A damaged reward record is repaired field by field, not fatal.
	do
		local damagedPlayer = player(22)
		stores.Tests.values.p_22 = { schemaVersion = 1, gold = 5, xp = 0, heroes = { ironman = { xp = 0, level = 1 } }, loadout = { "ironman" },
			rewards = { freeChestAt = "soon", loginDay = 0 / 0, playClaimed = 5, collection = "x" } }
		local damaged = service:Load(damagedPlayer)
		check(damaged ~= nil and damaged.rewards.freeChest.ready and damaged.rewards.login.claimable, "A damaged reward record is repaired, not fatal")
		service.random = scriptedRolls(0, 0)
		local _, repairedClaim = service:Handle(damagedPlayer, "ClaimFreeChest", {}, true)
		check(repairedClaim, "A repaired account can claim like any other")
	end

	-- Promo codes: typed any way, once per account, checked before any save.
	do
		local fan = player(25)
		service:Load(fan)
		local goldBefore = service:Get(fan).gold
		local _, codeOk, redeemed = service:Handle(fan, "RedeemCode", { code = "  tes te " }, true)
		check(codeOk and redeemed.gold == goldBefore + 200 and redeemed.result.code == "TESTE", "A code typed in lowercase with spaces still pays")
		local _, again, againMessage = service:Handle(fan, "RedeemCode", { code = "TESTE" }, true)
		check(not again and string.find(againMessage, "já usou", 1, true) and service:Get(fan).gold == goldBefore + 200, "A code pays once per account")
		local _, expired = service:Handle(fan, "RedeemCode", { code = "velho" }, true)
		check(not expired, "An expired code pays nothing")
		for _, bad in ipairs({ {}, 42, "", "x", string.rep("A", 40), "TE$TE" }) do
			local _, refused = service:Handle(fan, "RedeemCode", { code = bad }, true)
			check(not refused, "A malformed code is refused: " .. tostring(bad))
		end
		-- Guessing is throttled: after enough misses even a real code must wait.
		service.random = scriptedRolls(0, 0)
		local _, throttled, throttleMessage = service:Handle(fan, "RedeemCode", { code = "BAU" }, true)
		check(not throttled and string.find(throttleMessage, "Muitas tentativas", 1, true), "Too many wrong guesses in a minute ask the player to wait")
		clockOffset += 61
		service.random = scriptedRolls(0, 0)
		local _, chestOk, chest = service:Handle(fan, "RedeemCode", { code = "bau" }, true)
		check(chestOk and chest.result.chest and chest.heroes[chest.result.chest.heroId] ~= nil, "A code can open a chest, and the hero joins the account")
		local _, inMatch = service:Handle(fan, "RedeemCode", { code = "TESTE" }, false)
		check(not inMatch, "Codes are redeemed in the lobby")
		check(stores.Tests.values.p_25.codes.TESTE ~= nil, "Used codes are durable")
		check(service:Get(fan).codes == nil, "The list of used codes never replicates")
	end

	-- The group reward: Roblox decides membership, the server pays once.
	do
		local member = player(26)
		service:Load(member)
		local _, outsider, outsiderMessage = service:Handle(member, "ClaimGroupReward", {}, true)
		check(not outsider and string.find(outsiderMessage, "grupo", 1, true), "Not in the group yet: nothing is paid")
		member.IsInGroup = function(_, groupId) return groupId == 777 end
		local goldBefore = service:Get(member).gold
		local _, joined, paid = service:Handle(member, "ClaimGroupReward", {}, true)
		check(joined and paid.gold == goldBefore + Catalog.Rewards.group.gold, "A member is paid the group reward")
		check(paid.rewards.group.claimed == true, "The panel learns the reward was claimed")
		local _, twice = service:Handle(member, "ClaimGroupReward", {}, true)
		check(not twice and service:Get(member).gold == paid.gold, "The group reward pays once")
		member.IsInGroup = function() error("Roblox is down") end
		local other = player(27)
		service:Load(other)
		other.IsInGroup = function() error("Roblox is down") end
		local _, failed = service:Handle(other, "ClaimGroupReward", {}, true)
		check(not failed, "A failed membership check pays nothing")
	end

	-- A friend's invite: a brand-new account is welcomed once, and the friend
	-- who invited (in this server) is thanked, a few times a day at most.
	do
		local invite = Catalog.Rewards.invite
		local friend = player(41)
		service:Load(friend)
		local newcomer = player(42)
		service:Load(newcomer)
		local before, friendBefore = service:Get(newcomer).gold, service:Get(friend).gold
		local paid = service:InviteBonus(newcomer, 41)
		check(paid and paid.newcomer == invite.newcomerGold and service:Get(newcomer).gold == before + invite.newcomerGold, "A new account that joined from an invite gets the welcome Gold")
		check(paid.friend == friend and paid.thanks == invite.inviterGold and service:Get(friend).gold == friendBefore + invite.inviterGold, "The friend who invited, in this server, is thanked")
		check(service:InviteBonus(newcomer, 41) == nil and service:Get(newcomer).gold == before + invite.newcomerGold, "The welcome Gold pays once")
		check(service:Get(newcomer).referredBy == nil, "Who invited whom never replicates")
		local alone = player(43)
		service:Load(alone)
		check(service:InviteBonus(alone, 43) == nil and service:InviteBonus(alone, 0) == nil, "Nobody invites themselves, and no referrer means no bonus")
		local away = player(44)
		service:Load(away)
		local awayPaid = service:InviteBonus(away, 99999)
		check(awayPaid and awayPaid.friend == nil, "A friend in another server: the newcomer is still welcomed")
		-- The friend's thanks stop at the daily cap; the newcomers are still welcomed.
		local thanked = 1
		for index = 1, invite.inviterDailyCap + 1 do
			local guest = player(50 + index)
			service:Load(guest)
			local result = service:InviteBonus(guest, 41)
			check(result and result.newcomer == invite.newcomerGold, "Every new guest is welcomed")
			if result.friend then thanked += 1 end
		end
		check(thanked == invite.inviterDailyCap, "The friend is thanked at most " .. invite.inviterDailyCap .. " times a day, got " .. thanked)
		-- An account older than the window gets nothing.
		local veteran = player(45)
		service:Load(veteran)
		clockOffset += invite.newAccountSeconds + 1
		check(service:InviteBonus(veteran, 41) == nil, "An account older than the window gets no invite bonus")
	end

	service.leaseSeconds = realLease
end

-- Base ownership is durable, collection-specific and lobby-only.
do
	local owner=player(91); service:Load(owner)
	check(service:Get(owner).equippedBase=="outpost" and service:Get(owner).bases.outpost,"starter base is free")
	service:Award(owner,"base-budget",{gold=20000})
	local gold=service:Get(owner).gold
	local _,locked=service:Handle(owner,"EquipBase",{baseId="worldtree"},true)
	check(not locked and service:Get(owner).equippedBase=="outpost","unowned base cannot be equipped")
	service.random=scriptedRolls(0,0)
	replayCallback=true
	local _,ok,result=service:Handle(owner,"OpenChest",{chestId="base_supply"},true)
	replayCallback=false
	check(ok and result.gold==gold-400,"base chest charges once under callback replay")
	check(result.result.baseId=="workshop" and result.result.heroId==nil,"base chest never grants a hero")
	check(result.bases.workshop and not result.heroes.workshop,"separate inventory for bases")
	check(stores.Tests.values.p_91.bases.workshop,"base grant persisted with charge")
	local _,equipped=service:Handle(owner,"EquipBase",{baseId="workshop"},true)
	check(equipped and stores.Tests.values.p_91.equippedBase=="workshop","equipped base persists")
	local _,battle=service:Handle(owner,"EquipBase",{baseId="outpost"},false)
	check(not battle and service:Get(owner).equippedBase=="workshop","cannot swap base during battle")
	service.random=scriptedRolls(0,0)
	service:Handle(owner,"OpenChest",{chestId="base_supply"},true)
	service.random=scriptedRolls(0,0)
	local _,duplicate,paid=service:Handle(owner,"OpenChest",{chestId="base_supply"},true)
	check(duplicate and paid.result.duplicate and paid.result.refundGold<=160 and paid.result.refundMastery==0,"base duplicate refund is capped; no hero mastery")
	service:Release(owner); service:Load(owner)
	check(service:Get(owner).equippedBase=="workshop" and service:Get(owner).bases.garden,"base collection survives reload")
	service.records[owner.UserId].randomRestricted=true
	local before=service:Get(owner).gold
	local _,restricted=service:Handle(owner,"OpenChest",{chestId="base_cosmic"},true)
	check(not restricted and service:Get(owner).gold==before,"paid random restriction also blocks base chests without charge")
end

-- Guaranteed purchase: only where chests are restricted, exact item, exact price.
do
	local buyer = player(4343)
	service:Load(buyer)
	local target = "thor"
	local price = Rules.GuaranteedPrice(target)
	service:Award(buyer, "guaranteed-funds", { gold = price + 100 })
	local _, open = service:Handle(buyer, "BuyGuaranteed", { itemId = target }, true)
	check(not open, "an unrestricted account uses the chests instead")
	service.records[buyer.UserId].randomRestricted = true
	local _, poor = service:Handle(buyer, "BuyGuaranteed", { itemId = "nobody" }, true)
	check(not poor, "an unknown item is refused")
	local before = service:Get(buyer).gold
	local _, bought = service:Handle(buyer, "BuyGuaranteed", { itemId = target }, true)
	check(bought and service:Get(buyer).heroes[target] ~= nil, "a restricted account buys the exact hero it chose")
	check(service:Get(buyer).gold == before - price, "the guaranteed price is charged exactly once")
	local _, again = service:Handle(buyer, "BuyGuaranteed", { itemId = target }, true)
	check(not again and service:Get(buyer).gold == before - price, "an owned item cannot be bought again")
	local _, broke = service:Handle(buyer, "BuyGuaranteed", { itemId = "silversurfer" }, true)
	check(not broke, "the price must be affordable")
end

-- Cosmetic feats: a title once, never Gold, only for known feats.
do
	local climber = player(4444)
	service:Load(climber)
	local gold = service:Get(climber).gold
	local ok, result = service:GrantCosmetic(climber, "parkour")
	check(ok and result.fresh == true and service:Get(climber).titles["feat:parkour"] ~= nil, "the parkour grants its title")
	local again, second = service:GrantCosmetic(climber, "parkour")
	check(again and second.fresh == false, "the parkour title is granted only once")
	check(service:Get(climber).gold == gold, "a cosmetic feat never pays Gold")
	check(not service:GrantCosmetic(climber, "infiniteGold"), "unknown feats are refused")
	local handled = service:Handle(climber, "GrantCosmetic", { featId = "parkour" }, true)
	check(not handled, "no client action grants a feat")
end

-- Language: a new account follows the Roblox locale until the player picks one.
do
	local portuguese = player(91)
	portuguese.LocaleId = "pt-br"
	local english = player(92)
	english.LocaleId = "en-us"
	local spanish = player(93)
	spanish.LocaleId = "es-es"
	local unknown = player(94)
	check(service:Load(portuguese).settings.language == "pt", "a pt-br locale starts in Portuguese")
	check(service:Load(english).settings.language == "en", "an en-us locale starts in English")
	check(service:Load(spanish).settings.language == "en", "any other locale starts in English")
	check(service:Load(unknown).settings.language == "pt", "a player without a locale keeps the default")
	-- Picking a language wins over the locale, for good.
	local _, chose = service:Handle(english, "Settings", { language = "pt" }, true)
	check(chose and service:Get(english).settings.language == "pt" and service:Get(english).settings.languageSet == true, "choosing a language sticks")
	service:Release(english)
	english.LocaleId = "en-us"
	check(service:Load(english).settings.language == "pt", "a chosen language is not overridden by the locale on the next visit")
	local _, frenchOk = service:Handle(english, "Settings", { language = "fr" }, true)
	check(not frenchOk and service:Get(english).settings.language == "pt", "an unsupported language is refused and changes nothing")
end

-- Season pass: XP climbs levels, the free track pays everyone, the premium
-- track only the owner, and every claim is idempotent.
do
	check(Rules.SeasonLevelXp(1) == Catalog.Season.firstXp and Rules.SeasonLevelXp(30) == Catalog.Season.firstXp + 29 * Catalog.Season.stepXp, "The first level is the cheapest, the last the dearest")
	local summed = 0
	for level = 1, Catalog.Season.levels do
		summed += Rules.SeasonLevelXp(level)
		check(Rules.SeasonThreshold(level) == summed, "The threshold of level " .. level .. " is the sum of the levels before it")
	end
	check(Rules.SeasonThreshold(0) == 0, "Level 0 needs nothing")
	local status0 = Rules.SeasonStatus({ id = 1, xp = 0, freeClaimed = 0, premiumClaimed = 0 }, false)
	check(status0.level == 0 and status0.claimable == 0 and #status0.upcoming == 6, "A fresh season has no level and no claim")
	local mid = Rules.SeasonStatus({ id = 1, xp = Rules.SeasonThreshold(3) + 10, freeClaimed = 1, premiumClaimed = 0 }, true)
	check(mid.level == 3 and mid.claimableFree == 2 and mid.claimablePremium == 3 and mid.claimable == 5, "Levels reached minus levels claimed, per track")
	check(Rules.SeasonStatus({ xp = 1e9 }, false).level == Catalog.Season.levels, "Level is capped")
	local free10, premium30 = Rules.SeasonReward(10, "free"), Rules.SeasonReward(30, "premium")
	check(free10.chest == "rare" and Rules.SeasonReward(9, "free").chest == nil, "The free track gives a chest every ten levels")
	check(premium30.chest == "legendary" and premium30.title ~= nil, "The last premium level gives a legendary chest and a title")
	check(Rules.SeasonReward(5, "premium").gold > Rules.SeasonReward(5, "free").gold, "Premium always pays more Gold")
	local totalFree, totalPremium = 0, 0
	for level = 1, Catalog.Season.levels do
		totalFree += Rules.SeasonReward(level, "free").gold
		totalPremium += Rules.SeasonReward(level, "premium").gold
	end
	check(totalFree > 0 and totalPremium > totalFree * 1.5, "The premium track is clearly worth buying: " .. totalFree .. " vs " .. totalPremium)

	local climber = player(81)
	service:Load(climber)
	local before = service:Get(climber)
	check(before.seasonStatus.level == 0 and before.seasonStatus.claimable == 0, "A new player starts the season at level 0")
	local handled, ok = service:Handle(climber, "ClaimSeason", {}, true)
	check(handled and not ok, "Nothing to claim at level 0")
	-- XP from a match feeds the season (and a replayed award does not feed it twice).
	check(service:Award(climber, "season:xp1", { xp = 4500 }), "an award with XP is accepted")
	check(not service:Award(climber, "season:xp1", { xp = 4500 }) or service:Get(climber).seasonStatus.xp == 4500, "A repeated award id adds no second XP")
	local afterXp = service:Get(climber).seasonStatus
	local badgeBefore = service:Get(climber).rewards.claimable
	check(afterXp.theme ~= nil and #afterXp.theme.name.pt > 3 and #afterXp.theme.name.en > 3, "the season has a name in both languages")
	check(afterXp.endsAt ~= nil and afterXp.endsAt > os.time() and afterXp.endsAt - os.time() <= 60 * 86400, "the season says when it ends, within its length")
	check(Rules.SeasonTheme(1) ~= Rules.SeasonTheme(2) and Rules.SeasonTheme(1) == Rules.SeasonTheme(1 + #Catalog.SeasonThemes), "the names cycle")
	check(afterXp.xp == 4500 and afterXp.level == 2 and afterXp.claimableFree == 2 and afterXp.claimablePremium == 0, "XP became season levels, premium locked: " .. afterXp.xp)
	check(badgeBefore >= 1, "A claimable season level lights the gift badge")
	local goldBefore = service:Get(climber).gold
	local handled2, ok2, snap2 = service:Handle(climber, "ClaimSeason", {}, true)
	local paid = snap2.result
	check(handled2 and ok2 and paid.gold == Rules.SeasonReward(1, "free").gold + Rules.SeasonReward(2, "free").gold, "A claim pays every claimable free level")
	check(service:Get(climber).gold == goldBefore + paid.gold, "The Gold arrives in the profile")
	local handled3, ok3 = service:Handle(climber, "ClaimSeason", {}, true)
	check(handled3 and not ok3, "The same levels cannot be claimed twice")
	-- Buying the premium pass back-pays every level reached.
	passOwners["81:203"] = true
	service:_refreshPasses(climber)
	check(service:Get(climber).passes.season and service:Get(climber).seasonStatus.claimablePremium == 2, "Owning the pass unlocks the premium levels already reached")
	local _, ok4, snap4 = service:Handle(climber, "ClaimSeason", {}, true)
	local paid4 = snap4.result
	check(ok4 and paid4.gold == Rules.SeasonReward(1, "premium").gold + Rules.SeasonReward(2, "premium").gold, "The premium claim pays the premium levels: ")
	-- The top: every chest of both tracks, a title, nothing claimable afterwards.
	local record = stores.Tests.values.p_81
	record.season.xp = Rules.SeasonThreshold(Catalog.Season.levels)
	local _, ok5, snap5 = service:Handle(climber, "ClaimSeason", {}, true)
	local top = snap5.result
	check(ok5 and top.level == Catalog.Season.levels and #top.chests == 9, "Levels 3-30 open three free and six premium chests: " .. tostring(top and #top.chests))
	check(#top.titles == 1 and service:Get(climber).titles.seasonPremium ~= nil, "The season champion title is unlocked")
	check(service:Get(climber).seasonStatus.claimable == 0, "The finished season has nothing left to claim")
	-- A new season starts from zero.
	local newSeasonId = service:_season()
	stores.Tests.values.p_81.season.id = newSeasonId - 1
	local awarded = service:Award(climber, "season:xp2", { xp = 2100 })
	local fresh = service:Get(climber).seasonStatus
	check(awarded and fresh.xp == 2100 and fresh.level == 1 and fresh.freeClaimed == 0 and fresh.premiumClaimed == 0, "A previous season's XP does not carry into the new one, which counts from zero: " .. tostring(fresh.xp) .. "/" .. tostring(fresh.level))
	-- Damaged records are repaired when a profile loads.
	stores.Tests.values.p_81.season = { id = "x", xp = -5, freeClaimed = 999, premiumClaimed = 1 / 0 }
	service:Release(climber)
	service:Load(climber)
	local repaired = stores.Tests.values.p_81.season
	check(repaired.xp == 0 and repaired.freeClaimed == Catalog.Season.levels and repaired.premiumClaimed == Catalog.Season.levels, "A damaged season record is repaired into range")
end

-- Campaign difficulty: a win on one opens the next on that map only.
do
	local climber = player(77)
	localOnly:Load(climber)
	check(not localOnly:Award(climber, "diff:bad", { finished = true, victory = true, modeId = "normal", mapId = "gamma", difficultyId = "insane" }), "an unknown difficulty is refused")
	check(localOnly:Award(climber, "diff:normal", { finished = true, victory = true, modeId = "normal", mapId = "gamma" }), "a Normal win is awarded")
	check(Rules.DifficultyUnlocked(localOnly:Get(climber), "gamma", "hard") and not Rules.DifficultyUnlocked(localOnly:Get(climber), "gamma", "nightmare"), "a Normal win opens Hard")
	check(localOnly:Award(climber, "diff:hard", { finished = true, victory = true, modeId = "normal", mapId = "gamma", difficultyId = "hard" }), "a Hard win is awarded")
	check(Rules.DifficultyUnlocked(localOnly:Get(climber), "gamma", "nightmare"), "a Hard win opens Nightmare")
	check(not Rules.DifficultyUnlocked(localOnly:Get(climber), "manhattan", "hard"), "other maps stay on Normal")
end

-- Hero cards (the Clash-style ladder) and opening several chests at once.
-- A function of its own: the file already holds close to Luau's 200 locals.
(function()
	local fan = player(91)
	localOnly:Load(fan)
	localOnly:Award(fan, "cards:gold", { gold = 20000 })
	local goldNow = localOnly:Get(fan).gold
	-- Several chests in one request: one price, one committed result per chest.
	localOnly.random = scriptedRolls(0, 0, 0, 0, 0, 0, 0, 0, 0)
	local _, badCount = localOnly:Handle(fan, "OpenChest", { chestId = "rare", count = 0 }, true)
	check(not badCount and localOnly:Get(fan).gold == goldNow, "A count of zero is refused")
	local _, hugeCount = localOnly:Handle(fan, "OpenChest", { chestId = "rare", count = Catalog.MaxChestsAtOnce + 1 }, true)
	check(not hugeCount and localOnly:Get(fan).gold == goldNow, "More than the cap is refused, never clamped")
	local _, floatCount = localOnly:Handle(fan, "OpenChest", { chestId = "rare", count = 2.5 }, true)
	check(not floatCount and localOnly:Get(fan).gold == goldNow, "A fractional count is refused")
	local _, pricey = localOnly:Handle(fan, "OpenChest", { chestId = "legendary", count = 40 }, true)
	check(not pricey and localOnly:Get(fan).gold == goldNow, "Forty legendary chests need all forty prices")
	local _, batchOk, batch = localOnly:Handle(fan, "OpenChest", { chestId = "rare", count = 3 }, true)
	check(batchOk and batch.result.count == 3 and #batch.result.batch == 3, "Three chests come back as three results, got " .. tostring(batchOk))
	local refunds = 0
	for _, opened in ipairs(batch.result.batch) do refunds += opened.refundGold or 0 end
	check(batch.gold == goldNow - 3 * Catalog.Chests.rare.cost + refunds and batch.result.cost == 3 * Catalog.Chests.rare.cost, "The price is three chests' worth, taken once (duplicates refund their Gold)")
	check(batch.stats.chests == 3, "Every chest of the batch is counted")
	-- A duplicate hero pays cards for its rank ladder.
	local heroId = batch.result.batch[1].heroId
	check(batch.heroes[heroId] and batch.heroes[heroId].rank == 1 and (batch.heroes[heroId].copies or 0) >= 0, "A new hero starts at rank 1")
	local stored = localOnly.memoryProfiles.p_91.heroes[heroId]
	stored.copies = 0
	localOnly.random = scriptedRolls(0, 0, 0)
	local before = localOnly:Get(fan).heroes
	-- Force a duplicate by owning every common hero first.
	for _, id in ipairs(Catalog.HeroOrder) do
		if Catalog.Heroes[id].rarity == "common" and not localOnly.memoryProfiles.p_91.heroes[id] then
			localOnly.memoryProfiles.p_91.heroes[id] = { xp = 0, level = 1, stars = 0, rank = 1, copies = 0, alloc = { damage = 0, speed = 0, range = 0 } }
			localOnly.memoryProfiles.p_91.abilities[id] = 1
		end
	end
	for _, owned in pairs(localOnly.memoryProfiles.p_91.heroes) do owned.copies = 0 end
	localOnly.random = scriptedRolls(0, 0, 0)
	local _, dupOk, dup = localOnly:Handle(fan, "OpenChest", { chestId = "rare" }, true)
	check(dupOk and dup.result.duplicate == true and dup.result.cards == Catalog.Heroes[dup.result.heroId].economy.cards, "A duplicate pays its original per-hero compensation")
	local dupHero = dup.result.heroId
	check(dup.heroes[dupHero].copies == dup.result.cards, "The cards are kept on the hero: " .. tostring(dupHero) .. " has " .. tostring(dup.heroes[dupHero].copies) .. ", result " .. tostring(dup.result.cards) .. " copies " .. tostring(dup.result.copies))
	-- Rank up: cards and Gold, no top.
	local rankNeed = Rules.CardRankCost(1)
	check(rankNeed.copies == 2 and rankNeed.gold == 100, "Rank 1 -> 2 costs 2 cards and 100 Gold")
	check(Rules.CardRankCost(2).copies == 3 and Rules.CardRankCost(3).copies == 5 and Rules.CardRankCost(10).copies > Rules.CardRankCost(9).copies, "Each rank costs more cards than the one before")
	local _, wrongRank = localOnly:Handle(fan, "RankUpHero", { heroId = dupHero, expectedRank = 5 }, true)
	check(not wrongRank, "A stale rank is refused")
	localOnly.memoryProfiles.p_91.heroes[dupHero].copies = 1
	local goldBefore = localOnly:Get(fan).gold
	local _, shortCards = localOnly:Handle(fan, "RankUpHero", { heroId = dupHero, expectedRank = 1 }, true)
	check(not shortCards and localOnly:Get(fan).gold == goldBefore, "One card is not enough for rank 2")
	localOnly.memoryProfiles.p_91.heroes[dupHero].copies = 5
	local _, rankOk, ranked = localOnly:Handle(fan, "RankUpHero", { heroId = dupHero, expectedRank = 1 }, true)
	check(rankOk and ranked.result.rank == 2 and ranked.heroes[dupHero].rank == 2 and ranked.heroes[dupHero].copies == 3 and ranked.gold == goldBefore - 100, "Ranking up spends 2 cards and 100 Gold")
	check(ranked.result.points == 1, "Rank 2 earns one point")
	-- Points go to damage, speed and range, never more than the rank earned.
	local _, tooMany = localOnly:Handle(fan, "SetHeroPoints", { heroId = dupHero, damage = 1, speed = 1, range = 0 }, true)
	check(not tooMany, "Two points at rank 2 is refused")
	local _, negative = localOnly:Handle(fan, "SetHeroPoints", { heroId = dupHero, damage = -1, speed = 2, range = 0 }, true)
	check(not negative, "A negative point is refused")
	local _, fractional = localOnly:Handle(fan, "SetHeroPoints", { heroId = dupHero, damage = 0.5 }, true)
	check(not fractional, "A fractional point is refused")
	local _, pointsOk, pointed = localOnly:Handle(fan, "SetHeroPoints", { heroId = dupHero, damage = 0, speed = 1, range = 0 }, true)
	check(pointsOk and pointed.heroes[dupHero].alloc.speed == 1, "The point goes where the player chose")
	local mods = Rules.PermanentModifiers(localOnly.memoryProfiles.p_91, dupHero)
	local same = clone(localOnly.memoryProfiles.p_91.heroes[dupHero])
	same.rank, same.alloc = 1, nil
	local plain = Rules.PermanentModifiers({ heroes = { [dupHero] = same }, talents = {} }, dupHero)
	check(math.abs(mods.damageBonus - plain.damageBonus - Catalog.HeroCards.base.damage) < 1e-9, "Rank 2 adds the base damage bonus")
	check(math.abs(mods.attackSpeedBonus - plain.attackSpeedBonus - Catalog.HeroCards.base.speed - Catalog.HeroCards.point.speed) < 1e-9, "and the point adds attack speed")
	check(math.abs(mods.rangeBonus - plain.rangeBonus - Catalog.HeroCards.base.range) < 1e-9, "every rank lifts all three stats")
	-- A damaged record never keeps points it did not earn (checked on the
	-- datastore-backed service, which reads the saved record back on load).
	local keeper = player(92)
	service:Load(keeper)
	check(stores.Tests.values.p_92.heroes.ironman ~= nil, "a new account starts with its first hero")
	stores.Tests.values.p_92.heroes.ironman.rank = 3
	stores.Tests.values.p_92.heroes.ironman.alloc = { damage = 99, speed = 99, range = 99 }
	service:Release(keeper)
	service:Load(keeper)
	local healed = stores.Tests.values.p_92.heroes.ironman
	check(service:Get(keeper).heroes.ironman.rank == 3, "The rank is kept")
	check(service:Get(keeper).heroes.ironman.alloc.damage == 0 and service:Get(keeper).heroes.ironman.alloc.speed == 0, "Points beyond the rank are discarded on load")
end)()

-- A colour merge preserves the actual grant, including an existing rank,
-- allocation, shiny appearance, copies and stars, for every owned hero.
do
	local baseline=__RARITY_BASELINE__
	for id,old in pairs(baseline.heroes) do
		local owned={xp=100,level=1,stars=2,rank=3,copies=7,alloc={damage=1,speed=1,range=0},shiny=true}
		local profile={gold=1234,heroes={[id]=owned},abilities={[id]=2},loadout={id}}
		local duplicate,refund=service:_grantHero(profile,id,1700000000)
		check(duplicate and refund.gold==old.duplicateGold and refund.mastery==old.duplicateMastery and refund.cards==old.cards,"Existing grant values survive rarity merge: "..id)
		check(profile.gold==1234+old.duplicateGold and owned.xp==100+old.duplicateMastery,"Gold and mastery are paid exactly: "..id)
		check(owned.copies==7+old.cards and owned.stars==3 and owned.rank==3 and owned.shiny and owned.alloc.damage==1 and profile.abilities[id]==2 and profile.loadout[1]==id,"Owned progression is intact: "..id)
	end
end
-- Exercise the official registry against fake storage, with no Roblox purchase.
-- Every configured hero ID must grant exactly that hero and survive a replay.
do
	local official = __CONFIG__
	official.DataStoreName, official.StudioMemory = "OfficialCommerceTests", false
	local wasStudio = isStudio
	isStudio = false
	local shop = PlayerService.new(official, Catalog, nil, Rules)
	local index = 950
	for heroId, product in pairs(official.Products.Heroes) do
		check(Catalog.Products.Heroes[heroId] ~= nil and product.id > 0, "Official ID belongs to a purchasable hero: "..heroId)
		index += 1
		local buyer = player(index)
		check(shop:Load(buyer) ~= nil, "Official registry test buyer loaded")
		local receipt = {PlayerId=index, ProductId=product.id, PurchaseId="official-"..heroId}
		check(shop:_receipt(receipt) == "granted", "Official receipt grants: "..heroId)
		local granted = shop:Get(buyer)
		check(granted.heroes[heroId] ~= nil and granted.abilities[heroId] == 1, "Correct hero and ability delivered: "..heroId)
		local gold, copies = granted.gold, granted.heroes[heroId].copies
		check(shop:_receipt(receipt) == "granted", "Official receipt replay acknowledged: "..heroId)
		local replayed = shop:Get(buyer)
		check(replayed.gold == gold and replayed.heroes[heroId].copies == copies, "Official receipt replay grants nothing twice: "..heroId)
	end
	isStudio = wasStudio
end
print("PASS PlayerService: " .. checks .. " assertions (real module, mocked Roblox persistence and purchases)")
