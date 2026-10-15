--!nonstrict
-- Executed by test_elevator.py with the official Luau CLI.
--
-- The mode portals are elevators: step on, a countdown runs, whoever else
-- steps on rides along, and at zero the match starts. Everything that makes
-- that fair lives in ElevatorService — who may board, who is refused and put
-- back outside, what happens to a full car, a leaver, a disconnect, a rider
-- whose plan changed under them, a launch that fails. None of it involves a
-- menu, so no UI suite can see it; this drives the real service directly.
local Stubs = require("./roblox_stubs")
local Rules = require("../src/shared/Rules")
local Catalog = require("../src/shared/Catalog")
local Elevator = require("../src/server/ElevatorService")
local v3 = Stubs.v3

local checks, failures = 0, 0
local function check(condition, label)
	checks += 1
	if not condition then
		failures += 1
		print("FAIL: " .. label)
	end
end

--==============================================================================
-- Fixtures
--==============================================================================
local ZONES = {
	normal = { center = v3(0, 4, 0), size = v3(12, 9, 7), exit = v3(0, 4, 9) },
	ranked = { center = v3(30, 4, 0), size = v3(12, 9, 7), exit = v3(30, 4, 9) },
	cards = { center = v3(60, 4, 0), size = v3(12, 9, 7), exit = v3(60, 4, 9) },
}
local OUTSIDE = v3(0, 4, 40)

local nextId = 100
local function newPlayer(profile)
	nextId += 1
	local root = { Position = OUTSIDE }
	local player = { UserId = nextId, Name = "P" .. nextId, Parent = "Players", profile = profile, root = root }
	player.Character = { FindFirstChild = function(_, name) return name == "HumanoidRootPart" and root or nil end }
	return player
end
local function newcomer() return newPlayer({ tutorialComplete = false, campaign = {} }) end
local function trained() return newPlayer({ tutorialComplete = true, campaign = {} }) end
local function veteran() return newPlayer({ tutorialComplete = true, campaign = { manhattan = { normal = true } } }) end

local function at(player, portalId) player.root.Position = portalId and ZONES[portalId].center or OUTSIDE end

local function harness(options)
	options = options or {}
	local log = { launches = {}, notices = {}, ejected = {}, changed = {} }
	local busy = false
	local blocked = {}
	local service = Elevator.new({
		rules = Rules,
		profileOf = function(player) return player.profile end,
		zones = ZONES,
		launch = function(riders, mapId, modeId)
			table.insert(log.launches, { riders = table.clone(riders), mapId = mapId, modeId = modeId })
			if busy then return false, "busy" end
			-- A started match makes its players unavailable, as the real
			-- server's match:Has and travel checks do.
			for _, rider in ipairs(riders) do blocked[rider] = true end
			return true
		end,
		notify = function(player, message) table.insert(log.notices, { player = player, message = message }) end,
		changed = function(player) log.changed[player] = (log.changed[player] or 0) + 1 end,
		eject = function(player, position)
			table.insert(log.ejected, { player = player, position = position })
			-- A real eject moves the character; tests choose per case whether
			-- the player is actually put outside, to probe both paths.
			if not options.stubbornEject then player.root.Position = position end
		end,
		available = function(player) return not blocked[player] end,
		friends = function(a, b) return (options.friendsOf or {})[a] and options.friendsOf[a][b] == true or (options.friendsOf or {})[b] and options.friendsOf[b][a] == true or false end,
		random = options.random,
		previousMap = options.previousMap,
		day = function() return options.day or 0 end,
	})
	local everyone = {}
	local function step(seconds, players)
		local elapsed = 0
		while elapsed < seconds - 1e-6 do
			service:Step(0.25, players or everyone)
			elapsed += 0.25
		end
	end
	local function noticesFor(player)
		local found = {}
		for _, entry in ipairs(log.notices) do if entry.player == player then table.insert(found, entry.message) end end
		return found
	end
	return {
		service = service, log = log, everyone = everyone, step = step, noticesFor = noticesFor,
		setBusy = function(value) busy = value end,
		block = function(player, value) blocked[player] = value end,
		add = function(...) for _, player in ipairs({ ... }) do table.insert(everyone, player) end end,
	}
end

--==============================================================================
-- Boarding
--==============================================================================
print("--- boarding ---")
do
	local h = harness()
	local ana = newcomer()
	h.add(ana)
	h.step(0.25)
	check(h.service:Snapshot(ana) == nil, "standing on the open deck boards nothing")
	at(ana, "normal")
	h.step(0.25)
	local snap = h.service:Snapshot(ana)
	check(snap ~= nil, "stepping onto the campaign pad boards its car")
	check(snap and snap.modeId == "normal" and snap.mapId == "manhattan", "a newcomer's campaign portal runs training in Manhattan")
	check(snap and snap.host == true and #snap.riders == 1 and snap.max == 4, "the first rider is the host of a one-rider car")
	check(snap and snap.remaining == 8, "a fresh car counts down from eight seconds, got " .. tostring(snap and snap.remaining))
	check((h.log.changed[ana] or 0) >= 1, "boarding pushes the rider a new snapshot")
	h.step(1)
	check(h.service:Snapshot(ana).remaining == 7, "the countdown runs while the rider stays on the pad")
	at(ana, nil)
	h.step(0.25)
	check(h.service:Snapshot(ana) == nil, "stepping off the pad leaves the car")
	check(next(h.service.cars) == nil, "an empty car is removed")
	check(#h.log.launches == 0, "leaving before zero launches nothing")
end

--==============================================================================
-- Locked portals refuse and set the player back outside
--==============================================================================
print("--- refusals ---")
do
	local h = harness({ stubbornEject = true })
	local ana = newcomer()
	h.add(ana)
	at(ana, "ranked")
	h.step(0.25)
	check(h.service:Snapshot(ana) == nil, "a locked portal does not take the player aboard")
	check(#h.log.ejected == 1 and h.log.ejected[1].position == ZONES.ranked.exit, "the refused player is put down at the portal's exit")
	local told = h.noticesFor(ana)
	check(#told == 1 and string.find(told[1], "treino", 1, true) ~= nil, "the refusal says what is missing, got " .. tostring(told[1]))
	-- The eject did not move them (stubborn), so they are still in the zone:
	-- they must not be refused again every quarter second.
	h.step(2)
	check(#h.noticesFor(ana) == 1 and #h.log.ejected == 1, "standing on a refused pad is not spammed with refusals")
	at(ana, nil)
	h.step(0.25)
	at(ana, "ranked")
	h.step(0.25)
	check(#h.noticesFor(ana) == 2, "stepping away and back in is refused again, with a fresh notice")
end

--==============================================================================
-- Riding together
--==============================================================================
print("--- riding together ---")
do
	local h = harness()
	local ana, bia = newcomer(), veteran()
	h.add(ana, bia)
	at(ana, "normal")
	h.step(0.25)
	h.step(4)
	check(h.service:Snapshot(ana).remaining == 4, "the countdown is at four before the second rider")
	at(bia, "normal")
	h.step(0.25)
	local shared = h.service:Snapshot(bia)
	check(shared and #shared.riders == 2 and shared.host == false, "a second rider joins the same car, not as host")
	check(shared and shared.modeId == "normal", "the car's plan follows its first rider: a veteran can ride along into training")
	check(shared and shared.remaining == 5, "a new rider always gets a few seconds to decide, got " .. tostring(shared and shared.remaining))
	check((h.log.changed[ana] or 0) >= 2, "the first rider is told someone joined")
	check(h.service.Cycle == nil, "map selection is random at departure")
	h.step(6)
	check(#h.log.launches == 1, "the car departs once at zero, got " .. #h.log.launches)
	local launch = h.log.launches[1]
	check(launch and #launch.riders == 2 and launch.modeId == "normal" and launch.mapId ~= nil, "both riders launch into training together")
	check(h.service:Snapshot(ana) == nil and h.service:Snapshot(bia) == nil and next(h.service.cars) == nil, "a departed car is gone")
	-- They are still standing on the pad here; the match's availability
	-- check is what keeps them from boarding a second car.
	h.step(1)
	check(next(h.service.cars) == nil, "players already in a match are never boarded")
	h.block(ana, false)
	h.step(0.25)
	check(h.service:Snapshot(ana) ~= nil, "once back in the lobby, the same pad boards them again")
end

--==============================================================================
-- A joiner who could not play the car's plan is refused at the door
--==============================================================================
print("--- plan checks ---")
do
	local h = harness()
	local host, rookie = veteran(), trained()
	h.add(host, rookie)
	at(host, "normal")
	h.step(0.25)
	local plan = h.service:Snapshot(host)
	check(plan and plan.modeId == "normal" and plan.mapId == "manhattan", "map not disclosed before random departure")
	at(rookie, "normal")
	h.step(0.25)
	check(h.service:Snapshot(rookie) ~= nil, "trained players can join any normal map")
	check(#h.service:Snapshot(host).riders == 2, "both riders share the car")

end

--==============================================================================
-- The plan changes under a rider: they are dropped at departure, not launched
--==============================================================================
do
	local h = harness()
	local first, vet, second = newcomer(), veteran(), newcomer()
	h.add(first, vet, second)
	at(first, "normal"); h.step(0.25)
	at(vet, "normal"); h.step(0.25)
	at(second, "normal"); h.step(0.25)
	check(#h.service:Snapshot(first).riders == 3, "three riders share a training car")
	at(first, nil); h.step(0.25)
	local plan = h.service:Snapshot(vet)
	check(plan and plan.host == true and plan.modeId == "normal", "when the host steps off, the next rider's plan takes over")
	h.step(10)
	check(#h.log.launches == 1 and #h.log.launches[1].riders == 2, "only the rider who can play the new plan departs")
	check(#h.noticesFor(second) == 0, "the rider left behind is told why")
	check(h.service:Snapshot(second) == nil, "and is no longer riding")
end

--==============================================================================
-- Full cars, Leave, disconnects, failed launches, daily sector
--==============================================================================
print("--- edges ---")
do
	local h = harness()
	local riders = { veteran(), veteran(), veteran(), veteran() }
	local fifth = veteran()
	for _, player in ipairs(riders) do h.add(player); at(player, "normal") end
	h.add(fifth)
	h.step(0.25)
	check(#h.service:Snapshot(riders[1]).riders == 4, "four riders fill a car")
	at(fifth, "normal")
	h.step(0.25)
	check(h.service:Snapshot(fifth) == nil, "a fifth rider is refused")
	check(string.find(h.noticesFor(fifth)[1] or "", "cheio", 1, true) ~= nil, "and told the car is full")

	check(h.service:Leave(riders[2]), "Leave takes a rider off")
	check(h.service:Snapshot(riders[2]) == nil and #h.service:Snapshot(riders[1]).riders == 3, "the car shrinks to three")
	check(riders[2].root.Position == ZONES.normal.exit, "Leave also puts the player outside the portal")
	h.step(0.25)
	check(h.service:Snapshot(riders[2]) == nil, "standing at the exit after Leave does not re-board")
	at(riders[2], "normal")
	h.step(0.25)
	check(h.service:Snapshot(riders[2]) ~= nil, "stepping back in after Leave boards again")
	check(not h.service:Leave(fifth), "Leave for someone not riding is a no-op")

	riders[3].Parent = nil
	h.step(0.25)
	check(#h.service:Snapshot(riders[1]).riders == 3, "a disconnected rider is dropped from the car")

	h.setBusy(true)
	for _ = 1, 60 do
		if #h.log.launches > 0 then break end
		h.step(0.25)
	end
	check(#h.log.launches == 1, "the car tried to depart")
	check(h.service:Snapshot(riders[1]) ~= nil and h.service:Snapshot(riders[1]).remaining == 8, "a failed launch keeps the car and restarts its countdown")
	check(h.noticesFor(riders[1])[#h.noticesFor(riders[1])] == "busy", "and every rider hears why")
	h.setBusy(false)
	h.step(8.25)
	check(#h.log.launches == 2 and #h.log.launches[2].riders == 3, "the retry departs with everyone still aboard")
end

do
	local h = harness()
	local vet = veteran()
	h.add(vet); at(vet, "cards"); h.step(0.25)
	local plan = h.service:Snapshot(vet)
	check(plan and plan.modeId == "cards" and plan.mapId == "gamma", "cards portal announces Gamma")
	h.step(9)
	local run = h.log.launches[1]
	check(run and run.modeId == "cards" and run.mapId ~= nil, "cards departure selects a real map")

end

print("--- start now ---")
do
	local h=harness()
	local host,guest=veteran(),veteran()
	h.add(host,guest); at(host,"normal"); h.step(0.25); at(guest,"normal"); h.step(0.25)
	check(not h.service:StartNow(guest),"only the first rider may start early")
	check(h.service:StartNow(host),"the host may start early")
	check(#h.log.launches==0,"starting early still leaves a moment to see the plan")
	h.step(1.6)
	local run=h.log.launches[1]
	check(run and #run.riders==2,"the whole car departs together after START")
	check(not h.service:StartNow(host),"nothing to start once the car has left")
end

print("--- fixed destinations ---")
local extra=0
for _,id in ipairs(Catalog.DestinationOrder) do
	if not ZONES[id] then
		extra+=1
		ZONES[id]={center=v3(100+extra*30,4,0),size=v3(12,9,7),exit=v3(100+extra*30,4,10)}
	end
end
for _,id in ipairs(Catalog.DestinationOrder) do
	local h=harness()
	local host,guest=veteran(),veteran()
	host.profile.campaign.hydra={ranked=true}; guest.profile.campaign.hydra={ranked=true}
	h.add(host,guest); at(host,id); at(guest,id); h.step(0.25)
	check(h.service:Snapshot(host).mapId==Rules.PortalMap(id),"fixed destination announced: "..id)
	h.step(9)
	local run=h.log.launches[1]
	check(run and #run.riders==2 and run.mapId==Rules.PortalMap(id) and run.modeId==Rules.PortalMode(host.profile,id),"duo arrives at authored map/mode: "..id)
end
do
	local h=harness()
	local p=veteran(); h.add(p); at(p,"cards"); h.step(0.25)
	check(h.service:Snapshot(p).mapId=="gamma","map is known before departure")
	h.step(9)
	check(h.log.launches[1].mapId=="gamma" and h.log.launches[1].modeId=="cards","card portal always launches Gamma")
	check(h.service.SelectMap==nil,"the client cannot reroute a fixed portal")
end
print("--- three independent queues and touch order ---")
for slot=2,3 do
	ZONES["normal:"..slot]={destinationId="normal",slot=slot,center=v3(-slot*20,4,0),size=v3(8.4,8,8.4),exit=v3(-slot*20,4,10)}
end
do
	local h=harness(); local groups={}
	for slot=1,3 do
		local id=slot==1 and "normal" or "normal:"..slot
		groups[slot]={}
		for _=1,4 do
			local rider=veteran(); table.insert(groups[slot],rider); h.add(rider); at(rider,id)
			check(h.service:Touch(rider,id),"touch reserves seat in "..id)
		end
		local late=veteran(); h.add(late); at(late,id)
		check(not h.service:Touch(late,id),"fifth touch cannot replace a rider in "..id)
		local snap=h.service:Snapshot(groups[slot][1])
		check(snap.slot==slot and snap.queueId==id and snap.portalId=="normal" and snap.mapId=="manhattan","queue identity and catalog destination are distinct: "..id)
		check(snap.host and #snap.riders==4,"first arrival keeps its seat and leadership: "..id)
	end
	local public=h.service:PublicSnapshot()
	check(public.normal.count==4 and public["normal:2"].count==4 and public["normal:3"].count==4,"all twelve seats can coexist")
	check(h.service:Leave(groups[2][1]),"second queue host may leave")
	check(h.service:Snapshot(groups[2][2]).host,"second queue promotes its next arrival")
	check(h.service:Snapshot(groups[1][1]).host and h.service:Snapshot(groups[3][1]).host,"other queue leaders remain unchanged")
	check(h.service:StartNow(groups[1][1]),"first queue can depart early")
	h.step(1.75)
	check(#h.log.launches==1 and #h.log.launches[1].riders==4,"only the requested group departs early")
	check(h.service:Snapshot(groups[2][2]) and h.service:Snapshot(groups[3][1]),"other groups retain their independent countdowns")
	h.step(7)
	check(#h.log.launches==3,"all three groups can depart independently")
	local seen={}
	for _,run in ipairs(h.log.launches) do for _,rider in ipairs(run.riders) do
		check(not seen[rider],"no rider appears in two departures"); seen[rider]=true
	end end
end
do
	local h=harness(); local first,second=veteran(),veteran()
	h.add(second,first); at(first,"normal"); at(second,"normal")
	check(h.service:Touch(first,"normal"),"first physical contact boards immediately")
	h.step(0.25)
	check(h.service:Snapshot(first).host and not h.service:Snapshot(second).host,"touch order takes precedence over player enumeration")
	check(not h.service:Touch(first,"normal:2"),"a rider cannot occupy two queues")
	local outside=veteran()
	check(not h.service:Touch(outside,"normal"),"a touch without a root in the zone is refused")
end
do
	local h=harness(); local rider=veteran(); h.add(rider); at(rider,"normal"); h.step(0.25)
	local launches=0
	h.service.launch=function() launches+=1; coroutine.yield(); return false,"retry" end
	local transfer=coroutine.create(function() h.service:_depart("normal") end)
	check(coroutine.resume(transfer),"transfer may yield")
	check(h.service:Snapshot(rider).departing,"departing state is visible while transfer yields")
	check(not h.service:Leave(rider) and not h.service:StartNow(rider),"departure cannot be cancelled or restarted in flight")
	h.step(3)
	check(launches==1,"concurrent polls cannot launch the same transfer twice")
	check(coroutine.resume(transfer),"failed transfer returns")
	check(not h.service:Snapshot(rider).departing and h.service:Snapshot(rider).remaining==8,"failure retains seats and opens a retry countdown")
	h.service.launch=function() error("transport failure") end
	check(pcall(function() h.service:_depart("normal") end),"unexpected transport errors do not break the queue loop")
	check(not h.service:Snapshot(rider).departing,"unexpected error also releases the transfer lock")
end
--==============================================================================
-- Campaign difficulty: chosen by the host, checked for everyone aboard
--==============================================================================
print("--- difficulty ---")
do
	local h = harness()
	local launched
	h.service.launch = function(riders, mapId, modeId, difficultyId) launched = { mapId = mapId, modeId = modeId, difficultyId = difficultyId }; return true end
	local host, guest, rookie = veteran(), veteran(), trained()
	h.add(host, guest, rookie)
	at(host, "normal"); h.step(0.25)
	check(h.service:Snapshot(host).difficultyId == "normal", "a car starts on Normal")
	check(not h.service:SetDifficulty(rookie, "hard"), "someone not aboard cannot pick a difficulty")
	at(guest, "normal"); h.step(0.25)
	check(not h.service:SetDifficulty(guest, "hard"), "only the first rider picks")
	check(not h.service:SetDifficulty(host, "nightmare"), "a difficulty nobody opened is refused")
	check(not h.service:SetDifficulty(host, "insane"), "an unknown difficulty is refused")
	check(h.service:SetDifficulty(host, "hard") and h.service:Snapshot(guest).difficultyId == "hard", "the host's Hard is announced to the car")
	at(rookie, "normal"); h.step(0.25)
	check(h.service:Snapshot(rookie) == nil and #h.noticesFor(rookie) > 0, "a rider who has not opened Hard here is refused with a reason")
	at(rookie, nil); h.step(0.25)
	check(h.service:SetDifficulty(host, "normal"), "the host can go back to Normal")
	at(rookie, "normal"); h.step(0.25)
	check(h.service:Snapshot(rookie) ~= nil, "on Normal the newcomer rides along")
	check(not h.service:SetDifficulty(host, "hard"), "Hard is refused while a rider aboard has not opened it")
	h.step(10)
	check(launched and launched.difficultyId == "normal" and launched.mapId == "manhattan", "the launch carries the car's difficulty")
	local h2 = harness()
	local sent
	h2.service.launch = function(riders, mapId, modeId, difficultyId) sent = difficultyId; return true end
	local solo = veteran()
	h2.add(solo)
	at(solo, "normal"); h2.step(0.25)
	h2.service:SetDifficulty(solo, "hard")
	h2.step(10)
	check(sent == "hard", "a Hard car launches on Hard")
end
-- The quick session: the first rider turns a campaign car into 20 waves; a difficulty turns it back.
do
	local host, rider = veteran(), veteran()
	local h = harness({})
	for _, p in ipairs({ host, rider }) do h.add(p) end
	at(host, "normal"); h.step(0.25)
	at(rider, "normal"); h.step(0.25)
	check(not h.service:SetQuick(rider, true), "only the first rider makes the car quick")
	check(h.service:SetQuick(host, true) and h.service:Snapshot(rider).modeId == "quick", "the host makes a campaign car the quick session, and everyone sees it")
	check(h.service:Snapshot(host).difficultyId == "normal", "the quick session plays at Normal")
	check(h.service:SetDifficulty(host, "normal") and h.service:Snapshot(host).modeId == "normal", "picking a difficulty turns it back into the campaign")
end
-- A friends-only car: the host closes it, strangers step off and are refused, friends ride.
do
	local host, friend, stranger, late = veteran(), veteran(), veteran(), veteran()
	local friendsOf = { [host] = { [friend] = true } }
	local h = harness({ friendsOf = friendsOf })
	for _, p in ipairs({ host, friend, stranger, late }) do h.add(p) end
	at(host, "normal"); h.step(0.25)
	at(stranger, "normal"); h.step(0.25)
	check(#h.service:Snapshot(host).riders == 2, "(setup) a stranger boards an open car")
	check(not h.service:SetFriendsOnly(stranger, true), "only the host closes the car")
	check(h.service:SetFriendsOnly(host, true) and h.service:Snapshot(host).friendsOnly == true, "the host closes the car to friends")
	check(h.service:Snapshot(stranger) == nil and #h.noticesFor(stranger) > 0, "a stranger aboard steps off with a reason")
	at(late, "normal"); h.step(0.25)
	check(h.service:Snapshot(late) == nil and #h.noticesFor(late) > 0, "a stranger is refused at a friends-only car")
	at(friend, "normal"); h.step(0.25)
	check(h.service:Snapshot(friend) ~= nil and #h.service:Snapshot(host).riders == 2, "a friend boards the friends-only car")
	check(h.service:RideOf(friend).friendsOnly and h.service:RideOf(friend).mapId == "manhattan", "RideOf tells where a friend's queue goes")
	check(h.service:SetFriendsOnly(host, false) and not h.service:Snapshot(host).friendsOnly, "the host can open the car again")
end
print(string.format("%s elevator: %d checks, %d failures", failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error("elevator failed", 0) end
