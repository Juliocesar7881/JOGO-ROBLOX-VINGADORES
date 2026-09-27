--!nonstrict
-- Builds the real world: the lobby and every campaign map, outside Roblox.
--
-- Everything a player sees is generated at run time by WorldBuilder, so until
-- this ran, nothing proved the world could be built at all. A typo here is the
-- difference between a game and an empty void, and no other test would catch it.

local Stubs = __STUBS__
local v3 = Stubs.v3

local Catalog = __CATALOG__
local WorldBuilder = __WORLD__

local checks, failures = 0, 0
local function check(condition, label)
	checks += 1
	if not condition then
		failures += 1
		print("FAIL: " .. label)
	end
end

local function countClass(root, className)
	local total = 0
	for _, child in ipairs(root:GetDescendants()) do
		if child:IsA(className) then total += 1 end
	end
	return total
end

--==============================================================================
-- Lobby: a diegetic hub, not a single panel with tabs
--==============================================================================
print("--- lobby ---")
local panels = {}
local ok, world = pcall(WorldBuilder.new, Catalog, function(player, panel, data)
	table.insert(panels, { player=player,panel = panel, data = data or {} })
end)
check(ok, "WorldBuilder.new builds the lobby: " .. tostring(world))
if not ok then
	print("FAIL match: world could not be constructed")
	error("world boot failed", 0)
end

local lobby = workspace:FindFirstChild("DoomLobby")
check(lobby ~= nil, "the lobby model lands in the workspace")
check(countClass(lobby, "BasePart") > 40,
	"the lobby has real geometry, got " .. tostring(countClass(lobby, "BasePart")) .. " parts")
check(lobby:FindFirstChild("LobbySpawn") ~= nil, "the lobby has a spawn point")
check(world.lobbySpawn ~= nil, "the spawn position is recorded for MovePlayer")
do
	local root={Position=v3(165,-30,380),AssemblyLinearVelocity=v3(0,-70,0)}
	local moves=0
	local character={FindFirstChild=function(_,name) return name=="HumanoidRootPart" and root or nil end,
		PivotTo=function(_,cf) moves+=1; root.Position=cf.Position end}
	world:RecoverLobbyVisitors({{Character=character},{}})
	check(moves==1 and root.Position==world.lobbySpawn,"fallen visitor returns to the lobby spawn")
	check(root.AssemblyLinearVelocity.Magnitude==0 and root.AssemblyAngularVelocity.Magnitude==0,"recovery removes falling momentum")
	world:RecoverLobbyVisitors({{Character=character}})
	check(moves==1,"visitor already on the island is not teleported again")
	root.Position=v3(0,-30,0)
	world:RecoverLobbyVisitors({})
	check(moves==1,"absent match participants are never moved by lobby recovery")
end

local sanctuary=lobby:FindFirstChild("AuroraSanctuary")
check(sanctuary~=nil,"Forest sanctuary is owned by the lobby model")
if sanctuary then
	local ground=sanctuary:FindFirstChild("ForestGround")
	check(ground and ground.CanCollide and ground.Size.Y>=300,"Expanded forest has a walkable island surface")
	local trees,stones,trails=0,0,0
	for _,piece in ipairs(sanctuary:GetChildren()) do
		if piece.Name=="ForestTree" and piece:FindFirstChild("ForestTrunk") then trees+=1 end
		if piece.Name=="JumpStone" and piece.CanCollide then stones+=1 end
		if piece.Name=="ForestTrail" and piece.CanCollide then trails+=1 end
		if piece:IsA("BasePart") then check(piece.Position.Z>150,"Forest stays outside all combat terrain bounds") end
	end
	-- The districts took over the corners; the forest still rings the island.
	check(trees>=20,"Forest surrounds the plaza with mature trees, got "..tostring(trees))
	-- Clearing a district keeps or removes a whole tree: every trunk keeps its
	-- four branches and crowns, and nothing leafy is left without a trunk.
	for _,grove in ipairs(lobby:GetDescendants()) do
		if grove:IsA("Model") and (grove.Name=="ForestTree" or grove.Name=="AuroraTree" or grove.Name=="OuterTree") then
			local trunks,crowns,branches=0,0,0
			for _,piece in ipairs(grove:GetChildren()) do
				if piece.Name:find("Trunk") then trunks+=1 end
				if piece.Name:find("Canopy") then crowns+=1 end
				if piece.Name=="TreeBranch" then branches+=1 end
			end
			local full=grove.Name=="OuterTree" and crowns==3 or (crowns==4 and branches==4)
			check(trunks==1 and full,"a whole tree, crown and all: "..grove.Name.." "..trunks.."/"..branches.."/"..crowns)
		end
	end
	for _,piece in ipairs(lobby:GetDescendants()) do
		if piece:IsA("BasePart") and (piece.Name=="ForestTrunk" or piece.Name=="ForestCanopy" or piece.Name=="TreeBranch" or piece.Name=="OuterTrunk" or piece.Name=="OuterCanopy") then
			check(piece.Parent and (piece.Parent.Name=="ForestTree" or piece.Parent.Name=="AuroraTree" or piece.Parent.Name=="OuterTree"),"tree pieces live in their tree: "..piece.Name)
		end
	end
	check(stones==7 and trails>=7,"Exploration paths and jumping stones are traversable")
	check(sanctuary:FindFirstChild("AuroraHeart")~=nil and sanctuary:FindFirstChild("AuroraFalls")~=nil,"Tree landmark and waterfall exist")
	check(countClass(lobby,"BasePart")<3500,"Expanded lobby remains under its geometry budget, got "..tostring(countClass(lobby,"BasePart")))
end
-- Coplanar overlapping faces flicker (z-fighting) as the camera moves.
do
	local flickers, names = WorldBuilder.CoplanarConflicts(lobby)
	check(flickers == 0, "no two lobby surfaces share a plane, got " .. tostring(flickers) .. " flickering pairs: " .. names)
end

-- Mobile performance budget: shadow-casting is opt-in for the handful of big
-- landmarks, off by default for every small piece of set dressing.
do
	local shadowless, shadowed = 0, 0
	for _, child in ipairs(lobby:GetDescendants()) do
		if child:IsA("BasePart") then
			if child.CastShadow then shadowed += 1 else shadowless += 1 end
		end
	end
	check(shadowless > shadowed * 5, "most lobby parts skip shadow-casting, got "
		.. tostring(shadowed) .. " shadowed vs " .. tostring(shadowless) .. " not")
	local hull = lobby:FindFirstChild("Helicarrier")
	check(hull ~= nil and hull.CastShadow == true, "the helicarrier hull still casts a shadow")
	local lobbyEmitters = countClass(lobby, "ParticleEmitter")
	check(lobbyEmitters <= #Catalog.AfkOrder + 2, "boarding pads use static light instead of multiplying emitters, got " .. tostring(lobbyEmitters))
end

-- Every physical location is its own Model, tagged with a Kind attribute the
-- client reads to apply per-viewer lock/ownership cosmetics.
local byKind = {}
for _, child in ipairs(lobby:GetChildren()) do
	local kind = child:GetAttribute("Kind")
	if kind then
		byKind[kind] = byKind[kind] or {}
		table.insert(byKind[kind], child)
	end
end

check(#(byKind.ModePortal or {}) == #Catalog.DestinationOrder, "one portal per destination, got " .. tostring(#(byKind.ModePortal or {})))
local portalModes = {}
for _, model in ipairs(byKind.ModePortal or {}) do portalModes[model:GetAttribute("ModeId")] = true end
for _, modeId in ipairs(Catalog.PortalOrder) do
	check(portalModes[modeId], "a portal exists for mode " .. modeId)
end

-- Portals are elevators, not buttons: each one publishes the box the server
-- watches for riders, and a spot to put someone who is refused or leaves.
do
	local function inside(zone, position)
		local offset = position - zone.center
		return math.abs(offset.X) <= zone.size.X / 2 and math.abs(offset.Y) <= zone.size.Y / 2
			and math.abs(offset.Z) <= zone.size.Z / 2
	end
	local zones = world.portalZones or {}
	for _, model in ipairs(byKind.ModePortal or {}) do
		local modeId = model:GetAttribute("PortalId")
		local zone = zones[modeId]
		check(zone ~= nil, modeId .. " publishes an elevator zone")
		if zone then
			local pad = model:FindFirstChild("Pad")
			check(pad ~= nil and inside(zone, pad.Position + v3(0, 2, 0)), modeId .. ": standing on the pad is inside the zone")
			check(not inside(zone, zone.exit), modeId .. ": the exit spot is outside the zone, so a refused player is not re-boarded")
			for otherId, other in pairs(zones) do
				if otherId ~= modeId then
					check(not inside(other, zone.exit), modeId .. ": its exit is not inside the " .. otherId .. " portal")
					check(not inside(other, zone.center), modeId .. " and " .. otherId .. " zones do not overlap")
				end
			end
		end
		local prompts = 0
		for _, item in ipairs(model:GetDescendants()) do
			if item:IsA("ProximityPrompt") then prompts += 1 end
		end
		check(prompts == 0, modeId .. ": the portal opens no menu; walking in is the whole interaction")
		local surface=model.MapBillboard.MapBoard
		local picture=surface.MapPicture
		check(picture and picture:IsA("ViewportFrame") and picture.CurrentCamera==picture.PictureCamera,modeId..": map board contains a rendered picture with its own camera")
		check(picture.MapScene:FindFirstChild("Road")~=nil,modeId..": picture includes the map route")
		check(surface.MapTitle:GetAttribute("LobbyTextEN")==Catalog.Maps[model:GetAttribute("MapId")].name.en,modeId..": picture identifies the real destination")
		for slot=1,3 do
			local id=slot==1 and modeId or modeId..":"..slot
			local queue=zones[id]
			local pad=model:FindFirstChild(slot==1 and "Pad" or "Pad"..slot)
			check(queue and queue.destinationId==modeId and queue.slot==slot,id..": independent queue maps back to its authored destination")
			check(queue and pad and inside(queue,pad.Position+v3(0,2,0)),id..": pad and server zone agree")
			for otherId,other in pairs(zones) do if otherId~=id then
				check(not inside(other,queue.center) and not inside(other,queue.exit),id..": center and exit do not enter "..otherId)
			end end
		end
	end
end

do
	local total=0
	for _ in pairs(world.portalZones) do total+=1 end
	check(total==#Catalog.DestinationOrder*3,"every destination has exactly three independent queues")
	world:UpdatePortalQueues({normal={count=4,max=4,remaining=4},["normal:2"]={count=2,max=4,remaining=6}})
	check(world.portalZones.normal.label.Text=="4/4  •  LOTADO","full queue is visibly closed")
	check(world.portalZones["normal:2"].label.Text=="2/4  •  6s","second queue has its own countdown")
	check(world.portalZones["normal:3"].label.Text=="0/4  •  ENTRE","third queue stays available")
	world:UpdatePortalQueues({})
end

check(#(byKind.HeroPedestal or {}) == 0,"the lobby no longer displays hero statues")
local portraits=game:GetService("ReplicatedStorage"):FindFirstChild("DoomHeroPortraits")
for _,heroId in ipairs(Catalog.HeroOrder) do check(portraits and portraits:FindFirstChild(heroId),"removing statues preserves portrait "..heroId) end

check(#(byKind.SkillPedestal or {}) == 0, "talents live in HUD")
check(#(byKind.ChestStand or {}) == 2, "two recruitment chest stands")
do
	local root={Position=world.shopZones.rare.center}
	local visitor={UserId=801,Character={FindFirstChild=function(_,name) return name=="HumanoidRootPart" and root or nil end}}
	check(world:NearMarket(visitor,"hero") and not world:NearMarket(visitor,"base"),"hero doorway authorizes only hero summons")
	root.Position=world.shopZones.rare.purchaseCenter
	check(world:NearMarket(visitor,"hero"),"purchase stays available inside the hero hall")
	root.Position=world.shopZones.base_rare.purchaseCenter
	check(world:NearMarket(visitor,"base") and not world:NearMarket(visitor,"hero"),"base hall authorizes only base summons")
	root.Position=v3(-80,4,370)
	check(not world:NearMarket(visitor),"the market approach is not a purchase zone")
	root.Position=world.shopZones.rare.center
	local start=#panels
	world:StepShopEntries({visitor})
	check(#panels==start+1 and panels[#panels].data.chestId=="rare","stepping on green opens the correct chest")
	for _=1,20 do world:StepShopEntries({visitor}) end
	check(#panels==start+1,"standing on green never repeatedly opens a closed menu")
	root.Position=world.shopZones.rare.center+v3(6.5,0,0)
	world:StepShopEntries({visitor})
	root.Position=world.shopZones.rare.center
	world:StepShopEntries({visitor})
	check(#panels==start+1,"small boundary jitter does not reopen the shop")
	root.Position=world.shopZones.base_rare.center
	world:StepShopEntries({visitor})
	check(#panels==start+2 and panels[#panels].data.chestId=="base_rare","walking to the other pad selects base collection")
	root.Position=world.shopZones.rare.center+v3(0,25,0)
	world:StepShopEntries({visitor})
	check(#panels==start+2,"flying above a pad does not count as standing on it")
	root.Position=world.shopZones.rare.center
	world:StepShopEntries({visitor})
	check(#panels==start+3,"leaving and returning rearms the pad")
	local other={UserId=802,Character=visitor.Character}
	world:StepShopEntries({visitor,other})
	check(#panels==start+4 and panels[#panels].player==other,"each player has independent entry state")
	visitor.Character=nil
	world:StepShopEntries({visitor})
	check(next(world.shopOccupants)==nil,"despawned and disconnected players clear occupancy")
	for _,model in ipairs(byKind.ChestStand) do
		check(model:FindFirstChild("ShopEntryPad")~=nil,"each chest has a visible green entry pad")
	end
end

check(#(byKind.ShopStand or {}) == 5, "hero showcase, gold vault and one stand per pass, got "
	.. tostring(#(byKind.ShopStand or {})))
check(#(byKind.Board or {}) == 7, "missions, ranking, guide, maps, team, academy and base desks, got "
	.. tostring(#(byKind.Board or {})))
local boardIds = {}
for _, model in ipairs(byKind.Board or {}) do boardIds[model:GetAttribute("BoardId")] = true end
check(boardIds.quests and boardIds.leaderboard, "both the quest board and the leaderboard totem exist")
for _,id in ipairs({"guide","inventory","talents","bases"}) do
	check(boardIds[id],"functional service desk exists: "..id)
end
for _,id in ipairs({"quests","leaderboard"}) do
	local board=lobby:FindFirstChild("Board_"..id)
	check(board.PrimaryPart.Position.Z>345,"public notice board is reachable from the forest approach: "..id)
	check(board:FindFirstChild("Post")==nil,"central support no longer obscures notice text: "..id)
end
local details=lobby:FindFirstChild("VillageDetails")
check(details and details:FindFirstChild("GuideHead")~=nil,"Nico welcomes players at the guide desk")
check(countClass(details,"Seat")==3,"village benches provide usable seats")
check(world.leaderboardText ~= nil, "the leaderboard totem exposes a text label to update")

-- Lobby districts: AFK chambers are walk-in zones the server reads, and the
-- arena scoreboard takes one column per ranked map.
do
	local function visitorAt(position)
		local root = { Position = position }
		return { UserId = 900, Character = { FindFirstChild = function(_, name) return name == "HumanoidRootPart" and root or nil end } }
	end
	for _, kind in ipairs(Catalog.AfkOrder) do
		local zone = world.afkZones and world.afkZones[kind]
		check(zone ~= nil, "AFK farm publishes its zone: " .. kind)
		if zone then
			check(world:AfkZoneOf(visitorAt(zone.center)) == kind, "standing in the " .. kind .. " chamber is farming " .. kind)
			check(world:AfkZoneOf(visitorAt(zone.center + v3(0, 30, 0))) == nil, "flying over a chamber is not farming")
		end
		check(lobby:FindFirstChild("AfkZone_" .. kind) ~= nil, "AFK chamber model exists: " .. kind)
	end
	check(world:AfkZoneOf(visitorAt(v3(0, 4, 345))) == nil, "the spawn plaza is not an AFK farm")
	check(world:AfkZoneOf({ Character = nil }) == nil, "a player without a character farms nothing")
	for portalId, zone in pairs(world.portalZones) do
		for _, kind in ipairs(Catalog.AfkOrder) do
			check(world:AfkZoneOf(visitorAt(zone.center)) == nil, "portal " .. portalId .. " is not inside an AFK chamber")
		end
	end
	local rankedMaps = 0
	for _, def in pairs(Catalog.Destinations) do if def.modeId == "ranked" then rankedMaps += 1 end end
	check(#(world.arenaColumns or {}) == rankedMaps, "one arena column per ranked map")
	world:UpdateArenaScoreboard({ hydra = { { rank = 1, name = "Campeão", waves = 42 } }, wakanda = {} })
	local columns = {}
	for _, column in ipairs(world.arenaColumns or {}) do columns[column.mapId] = column.label.Text end
	check(columns.hydra and columns.hydra:find("Campeão") ~= nil, "the arena shows the top ranked player of each map")
	check(columns.wakanda == "Seja o primeiro!", "an empty ranked map invites the first player")
	check(columns.latveria == "Carregando…", "a map without fresh data keeps its previous text")
	for _, d in ipairs(WorldBuilder.Districts or {}) do
		local floor
		for _, obj in ipairs(lobby:GetDescendants()) do
			if obj.Name == "DistrictFloor" and obj:GetAttribute("District") == d.id then floor = obj end
		end
		check(floor ~= nil, "district has its own floor: " .. d.id)
	end
end

-- A barricade stands across the road exactly where its rule stops enemies.
do
	world:Build("manhattan")
	local routes = {}
	for index, route in ipairs(Catalog.Maps.manhattan.paths) do
		local points, lengths, total = {}, {}, 0
		for _, point in ipairs(route) do table.insert(points, v3(point[1], 0, point[2])) end
		for i = 1, #points - 1 do lengths[i] = (points[i + 1] - points[i]).Magnitude; total += lengths[i] end
		routes[index] = { points = points, lengths = lengths, total = total }
	end
	local bunker = { id = "bunker", level = 1, stats = { wall = 120 } }
	world:UpdateBarrier(1, bunker, routes, 1)
	local model = world.Scenery:FindFirstChild("PlayerBarrier_1")
	check(model ~= nil, "a wall base raises a barricade on the battlefield")
	local fields = 0
	for _, piece in ipairs(model and model:GetChildren() or {}) do
		if piece.Name == "BarrierField" then
			fields += 1
			-- Distance to the core along the road must be the rule's distance.
			local route = routes[1]
			local finish = route.points[#route.points]
			local last = route.points[#route.points - 1]
			local along = (finish - last).Magnitude
			local fromEnd = (v3(piece.Position.X, 0, piece.Position.Z) - finish).Magnitude
			check(along < WorldBuilder.BarrierDistance or math.abs(fromEnd - WorldBuilder.BarrierDistance) < 0.01, "the barricade stands where enemies are stopped, got " .. tostring(fromEnd))
			check(piece.CanCollide == false, "the barricade never traps avatars")
		end
	end
	check(fields >= 1, "each road into the core gets its barricade")
	world:SetBarrierHealth(1, 0.2)
	local faded = model and model:FindFirstChild("BarrierField")
	check(faded and faded.Transparency > 0.7, "a worn barricade fades")
	world:UpdateBarrier(1, { id = "outpost", level = 1, stats = { wall = 0 } }, routes, 1)
	check(world.Scenery:FindFirstChild("PlayerBarrier_1") == nil, "a base without a wall has no barricade")
	check(WorldBuilder.StreetRules.BUILD_LIMIT == 106, "the street builder and the placement rule share the build limit")
end

-- The optional parkour: only the last stone counts, not the ground below it.
do
	local goal = world.parkourGoal
	check(goal ~= nil, "the parkour has a goal stone")
	if goal then
		local function standing(position)
			local root = { Position = position }
			return { Character = { FindFirstChild = function(_, name) return name == "HumanoidRootPart" and root or nil end } }
		end
		check(world:ParkourReached(standing(goal + v3(0, 3, 0))), "standing on the last stone completes the parkour")
		check(not world:ParkourReached(standing(v3(goal.X, 3, goal.Z) - v3(0, goal.Y, 0))), "walking under it on the ground does not")
		check(not world:ParkourReached(standing(goal + v3(6, 3, 0))), "a nearby stone does not")
		check(not world:ParkourReached({ Character = nil }), "no character, no parkour")
	end
end

-- Hero proportions from the art direction: a human is ~6 studs, Hulk
-- 10-11 with a small head, Rocket about 60% of a human, Groot tall and narrow.
do
	local portraits = game:GetService("ReplicatedStorage"):FindFirstChild("DoomHeroPortraits")
	local function box(id)
		local model = portraits and portraits:FindFirstChild(id)
		if not model then return nil end
		local _, size = model:GetBoundingBox()
		return size
	end
	local human, hulk, rocket, groot = box("ironman"), box("hulk"), box("rocket"), box("groot")
	check(human and human.Y >= 5.5 and human.Y <= 7.5, "a human-sized hero stands about six studs, got " .. tostring(human and human.Y))
	check(hulk and hulk.Y >= 9.5 and hulk.Y <= 11.5, "Hulk stands about ten to eleven studs, got " .. tostring(hulk and hulk.Y))
	check(rocket and human and rocket.Y / human.Y >= 0.5 and rocket.Y / human.Y <= 0.7, "Rocket is about 60% of a human")
	check(groot and hulk and groot.X < hulk.X and groot.Y >= hulk.Y * 0.9, "Groot is tall and narrower than Hulk")
end

-- The training yard: a pad that opens the panel once, a stage whose ring is
-- the hero's real reach, and dummies every shot lands on. Nothing is a tower.
do
	local yard = lobby:FindFirstChild("TrainingYard")
	check(yard ~= nil, "the lobby has a training yard")
	local dummies = 0
	for _, child in ipairs(yard and yard:GetChildren() or {}) do if child.Name == "TrainingDummy" then dummies += 1 end end
	check(dummies == #WorldBuilder.Training.dummies and dummies >= 3, "the yard has its dummies, got " .. dummies)
	local special
	for _, d in ipairs(WorldBuilder.Districts) do if d.id == "special" then special = d end end
	for _, spot in ipairs({ WorldBuilder.Training.stage, WorldBuilder.Training.pad, table.unpack(WorldBuilder.Training.dummies) }) do
		check(special and spot.X > special.x0 and spot.X < special.x1 and spot.Z > special.z0 and spot.Z < special.z1, "the yard stays inside the training district")
		for portalId, destination in pairs(Catalog.Destinations) do
			check(math.abs(spot.X - destination.x) > 9 or math.abs(spot.Z - destination.z) > 9, "the yard keeps clear of portal " .. portalId)
		end
	end
	local root = { Position = world.shopZones.training.center }
	local trainee = { UserId = 811, Character = { FindFirstChild = function(_, name) return name == "HumanoidRootPart" and root or nil end } }
	local before = #panels
	world:StepShopEntries({ trainee })
	world:StepShopEntries({ trainee })
	check(#panels == before + 1 and panels[#panels].panel == "training", "stepping on the yard pad opens the training panel once")
	check(world:NearTraining(trainee), "standing on the pad is near the yard")
	root.Position = v3(0, 4, 345)
	check(not world:NearTraining(trainee), "the spawn plaza is not near the yard")
	local figure = world:ShowTrainingHero("hulk", 17)
	check(figure ~= nil and figure.Parent == yard and figure:GetAttribute("HeroId") == "hulk", "a chosen hero stands on the stage")
	check(figure and figure.PrimaryPart ~= nil, "the stage hero can be aimed by the client")
	check(math.abs(world.trainingRange.Size.Y - 34) < 1e-6 and world.trainingRange.Transparency < 1, "the floor ring is the hero's reach")
	world:ShowTrainingHero("ironman", 20)
	local heroes = 0
	for _, child in ipairs(yard:GetChildren()) do if child.Name == "TrainingHero" then heroes += 1 end end
	check(heroes == 1, "one hero at a time on the stage")
	local from, to = world:TrainingShot(4)
	check(typeof(from) == "Vector3" and typeof(to) == "Vector3" and (to - from).Magnitude < 20, "a training shot reaches a dummy from the stage")
	world:ClearTrainingHero()
	check(yard:FindFirstChild("TrainingHero") == nil and world.trainingRange.Transparency == 1, "the stage empties after training")
	for _, part in ipairs(yard:GetDescendants()) do
		if part:IsA("BasePart") then check(part.CanCollide == false, "yard pieces never trap avatars: " .. part.Name) end
	end
end

local ok2, err2 = pcall(function() world:UpdateLeaderboardBoard({ { rank = 1, name = "Tester", waves = 30 } }, "Manhattan") end)
check(ok2, "UpdateLeaderboardBoard accepts real rows: " .. tostring(err2))
check(world.leaderboardText.Text:find("Tester") ~= nil, "the totem text reflects the rows it was given")

-- Walk up to every location and press its prompt. Each one must open its own
-- panel with the identifiers that name it, and the server-side distance
-- re-check must refuse a player standing across the deck.
do
	local expectedPanel = { HeroPedestal = "hero", ChestStand = "chests", ShopStand = "shop", Scoreboard = "leaderboard" }
	local function playerAt(position)
		local root = { Position = position }
		return { Character = { FindFirstChild = function(_, name) return name == "HumanoidRootPart" and root or nil end } }
	end
	local wrong, refused = {}, 0
	for _, model in ipairs(lobby:GetChildren()) do
		local kind = model:GetAttribute("Kind")
		if kind and kind ~= "ModePortal" and kind ~= "AfkZone" then
			local prompt
			for _, item in ipairs(model:GetDescendants()) do
				if item:IsA("ProximityPrompt") or rawget(item, "__class") == "ProximityPrompt" then prompt = item end
			end
			local anchor = prompt and prompt.Parent
			if not prompt or not anchor then
				table.insert(wrong, model.Name .. ":no-prompt")
			else
				local before = #panels
				prompt.Triggered:Fire(playerAt(anchor.Position + v3(0, 0, 60)))
				if #panels == before then refused += 1 else table.insert(wrong, model.Name .. ":far-accepted") end
				prompt.Triggered:Fire(playerAt(anchor.Position + v3(3, 0, 0)))
				local opened = panels[#panels]
				if #panels ~= before + 1 or not opened then
					table.insert(wrong, model.Name .. ":near-refused")
				else
					local want = kind == "Board" and model:GetAttribute("BoardId") or expectedPanel[kind]
					if opened.panel ~= want then table.insert(wrong, model.Name .. ":panel=" .. tostring(opened.panel)) end
					local data = opened.data
					if kind == "HeroPedestal" and data.heroId ~= model:GetAttribute("HeroId") then table.insert(wrong, model.Name .. ":hero") end
					if kind == "SkillPedestal" and data.skillId ~= model:GetAttribute("SkillId") then table.insert(wrong, model.Name .. ":skill") end
					if kind == "ShopStand" and (data.shopKey ~= model:GetAttribute("ShopKey") or data.shopKind ~= model:GetAttribute("ShopKind")) then
						table.insert(wrong, model.Name .. ":shop")
					end
				end
			end
		end
	end
	check(#wrong == 0, "every lobby prompt opens its own panel and refuses a distant player: " .. table.concat(wrong, ", "))
	local expected = 2 + 5 + 7 + 1
	check(refused == expected, "the distance re-check refused all " .. expected .. " far presses, got " .. tostring(refused))
end

local totalPrompts = countClass(lobby, "ProximityPrompt")
local archipelago=lobby:FindFirstChild("AuroraArchipelago")
check(archipelago~=nil,"exploration archipelago is built")
if archipelago then
	local bridges,islands,seats=0,0,0
	for _,obj in ipairs(archipelago:GetChildren()) do
		if obj:GetAttribute("ExplorationIsland") then
			islands+=1
			check(obj.CanCollide and obj.Size.Y>=120,"exploration island has a broad solid ground")
		end
		if obj:GetAttribute("BridgeId") then
			bridges+=1
			check(obj.CanCollide and obj.Size.X>=10,"bridge has a solid walkable deck")
		end
		if obj:IsA("Seat") then seats+=1 end
	end
	check(islands==3 and bridges==3,"all three exploration islands have a bridge")
	check(seats>=9,"new areas provide real usable seats")
	check(archipelago:FindFirstChild("ExplorerStair")~=nil,"lookout has walkable stairs")
	check(archipelago:FindFirstChild("TelescopeTube")~=nil,"star garden has its telescope landmark")
	-- Keep a player-width corridor free of scenery along every new bridge.
	for _,route in ipairs({{-120,400,-165,419},{119,431,157,447},{0,484,0,516}}) do
		local dx,dz=route[3]-route[1],route[4]-route[2]
		for _,obj in ipairs(archipelago:GetChildren()) do
			if obj.Name=="IslandOutcrop" or obj.Name=="VillageLampFoot" or obj.Name=="OuterTrunk" then
				local x,z=obj.Position.X,obj.Position.Z
				local t=math.clamp(((x-route[1])*dx+(z-route[2])*dz)/(dx*dx+dz*dz),0,1)
				local distance=math.sqrt((x-route[1]-t*dx)^2+(z-route[2]-t*dz)^2)
				local radius=math.sqrt(obj.Size.X^2+obj.Size.Z^2)*0.5
				check(distance>radius+2.5,"bridge corridor is clear of "..obj.Name)
			end
		end
	end
end
-- Chests, Robux stands, boards and desks, plus the arena scoreboard kiosk.
local expectedPrompts = 2 + 5 + 7 + 1
check(totalPrompts == expectedPrompts,
	"every physical location is interactive, got " .. tostring(totalPrompts) .. "/" .. tostring(expectedPrompts))
print(string.format("  %d parts, %d locais interativos", countClass(lobby, "BasePart"), totalPrompts))

--==============================================================================
-- Every campaign map
--==============================================================================
local lighting = game:GetService("Lighting")
local seenClockTimes = {}
for _, mapId in ipairs(Catalog.MapOrder) do
	print("--- map: " .. mapId .. " ---")
	local built, problem = pcall(function() world:Build(mapId) end)
	check(built, mapId .. " builds: " .. tostring(problem))
	local trailSegments,arrows,expectedSegments={},0,{}
	for _,route in ipairs(Catalog.Maps[mapId].paths) do
		for index=1,#route-1 do
			local a,b=route[index],route[index+1]
			expectedSegments[a[1]..":"..a[2]..":"..b[1]..":"..b[2]]=true
		end
	end
	for _,item in ipairs(world.Paths:GetChildren()) do
		if item.Name=="MobTrail" then
			local route=Catalog.Maps[mapId].paths[item:GetAttribute("RouteIndex")]
			local index=item:GetAttribute("SegmentIndex")
			local a,b=route[index],route[index+1]
			trailSegments[a[1]..":"..a[2]..":"..b[1]..":"..b[2]]=true
			check(not item.CanCollide,mapId..": trail cannot block mobs or players")
			check(math.abs(item.Size.Z-math.sqrt((b[1]-a[1])^2+(b[2]-a[2])^2))<0.01,mapId..": trail matches simulation length")
		elseif item.Name=="TrailArrow" then arrows+=1 end
	end
	for key in pairs(expectedSegments) do check(trailSegments[key],mapId..": route segment has visible trail "..key) end
	check(arrows>10,mapId..": path direction marked repeatedly")
	if built then
		check(lighting.ClockTime ~= nil, mapId .. " applies runtime lighting without writing protected renderer settings")
		check(lighting:FindFirstChild("Atmosphere") ~= nil, mapId .. " keeps a reusable Atmosphere effect")
		check(lighting:FindFirstChild("ColorGrade") ~= nil, mapId .. " keeps a reusable ColorCorrection effect")
		local dof = lighting:FindFirstChild("DOF")
		check(dof ~= nil and dof.FarIntensity == 0, mapId .. " keeps depth of field off so the battlefield stays legible")
		seenClockTimes[lighting.ClockTime] = true
		local root = workspace:FindFirstChild("DoomWorld")
		check(root ~= nil, mapId .. " produces a world model")
		local parts = countClass(root, "BasePart")
		check(parts > 100, mapId .. " has real geometry, got " .. tostring(parts) .. " parts")
		check(root:FindFirstChild("BuildZones") ~= nil, mapId .. " has a build zone folder")
		check(root:FindFirstChild("Paths") ~= nil, mapId .. " has a path folder")
		check(world.base ~= nil, mapId .. " places the resistance core")

		-- One route rendered per path in the catalog, plus a portal for each.
		local routes, portals = {}, 0
		for _, child in ipairs(root:GetDescendants()) do
			if string.sub(child.Name, 1, 5) == "Route" and child.Name ~= "RouteEdge" then routes[child.Name] = true end
			if child.Name == "EnemyPortal" then portals += 1 end
		end
		local expected = #Catalog.Maps[mapId].paths
		local rendered = 0
		for _ in pairs(routes) do rendered += 1 end
		check(rendered == expected,
			mapId .. " renders every route (" .. tostring(rendered) .. "/" .. tostring(expected) .. ")")
		check(portals == expected,
			mapId .. " opens one portal per route (" .. tostring(portals) .. "/" .. tostring(expected) .. ")")
		local skylineShadowed, skylineTotal = 0, 0
		for _, child in ipairs(root:GetDescendants()) do
			if child.Name == "Skyline" then
				skylineTotal += 1
				if child.CastShadow then skylineShadowed += 1 end
			end
		end
		check(skylineTotal > 0 and skylineShadowed == skylineTotal,
			mapId .. " skyline buildings cast shadows for depth, got " .. tostring(skylineShadowed) .. "/" .. tostring(skylineTotal))
		-- Particles belong on singular landmarks only: one per enemy portal
		-- plus the core, never one per enemy or per tower.
		local emitters = countClass(root, "ParticleEmitter")
		check(emitters == expected + 1, mapId .. " emits particles at every portal and the core, got "
			.. tostring(emitters) .. "/" .. tostring(expected + 1))
		print(string.format("  %d parts, %d rotas, %d portais, %d emissores", parts, rendered, portals, emitters))
	end
end

--==============================================================================
-- Cylinders: Roblox runs a Cylinder's axis along X. Getting that wrong turned
-- flat coins into rods and the core's tall energy column into a squat drum.
--==============================================================================
print("--- cylinders ---")
do
	local DISCS = {
		Coin = true, VentGlow = true, CoreRing = true, Manhole = true, PlazaMosaic = true, Helipad = true,
		HelipadRing = true, HelipadInner = true, CourtCircle = true, Needles = true, SnowCap = true, Canopy = true,
		VibraniumRing = true, GoldCrown = true, TowerRoof = true, CoolingGlow = true,
	}
	local COLUMNS = {
		CoreColumn = true, LampPole = true, Trunk = true, CoolingTower = true, WaterTank = true, Chimney = true,
		Hydrant = true, Bin = true, Barrel = true, FireBarrel = true,
	}
	local wrong, seen = {}, 0
	local function inspect(root)
		for _, item in ipairs(root:GetDescendants()) do
			if item:IsA("BasePart") and item.Shape == Enum.PartType.Cylinder and (DISCS[item.Name] or COLUMNS[item.Name]) then
				seen += 1
				local size, axis = item.Size, item.CFrame.RightVector
				local upright = math.abs(axis.Y) > 0.99
				if DISCS[item.Name] and not (upright and size.X < size.Y and size.X < size.Z) then
					table.insert(wrong, item.Name .. " is not a flat disc")
				elseif COLUMNS[item.Name] and not (upright and size.X > size.Y) then
					table.insert(wrong, item.Name .. " is not a tall column")
				end
			end
		end
	end
	inspect(workspace:FindFirstChild("DoomLobby"))
	for _, mapId in ipairs(Catalog.MapOrder) do
		world:Build(mapId)
		inspect(workspace:FindFirstChild("DoomWorld"))
	end
	check(seen > 0, "the cylinder check found discs and columns to inspect")
	check(#wrong == 0, "every disc lies flat and every column stands tall: " .. table.concat(wrong, ", "))
	print(string.format("  %d cilindros conferidos", seen))
end

--==============================================================================
-- Lighting: one distinct mood per chapter, restored when leaving the map
--==============================================================================
print("--- lighting ---")
local distinctMoods = 0
for _ in pairs(seenClockTimes) do distinctMoods += 1 end
check(distinctMoods == #Catalog.MapOrder,
	"every chapter has its own lighting mood, got " .. tostring(distinctMoods) .. "/" .. tostring(#Catalog.MapOrder))
world:ApplyLobbyLighting()
check(lighting.FogEnd == 900, "returning to the lobby restores its own fog and mood, not the last chapter's")
print(string.format("  %d moods distintos", distinctMoods))

--==============================================================================
-- Rebuilding must not leak the previous map
--==============================================================================
--==============================================================================
-- The city around each battlefield: themed, bounded, and never in the way
--==============================================================================
print("--- city ---")
do
	local LANDMARKS = {
		CorePedestal = true, CoreTier = true, CoreTrim = true, CoreButtress = true, CoreButtressCap = true,
		ResistanceCore = true, CoreColumn = true, CoreRing = true, PortalPylon = true, PortalLintel = true,
		EnemyPortal = true, CityLimit = true,
	}
	local terrain = workspace.Terrain
	local groundMaterials = {}
	for _, mapId in ipairs(Catalog.MapOrder) do
		local map = Catalog.Maps[mapId]
		local fillsBefore = #(rawget(terrain, "__fills") or {})
		world:Build(mapId)
		local root = workspace:FindFirstChild("DoomWorld")

		-- Nothing solid on a spot where a tower may be built: every corner and
		-- edge midpoint of every part standing taller than a tower's platform
		-- must be off the buildable ground, by the real build rule.
		local offenders, tall = {}, 0
		for _, item in ipairs(root:GetDescendants()) do
			if item:IsA("BasePart") and not LANDMARKS[item.Name] and item.Parent ~= root.Towers
				and not (item.Parent and item.Parent.Parent == root.Towers) then
				local cf, size = item.CFrame, item.Size
				local top = -math.huge
				local points = {}
				for _, sx in ipairs({ -1, 0, 1 }) do
					for _, sz in ipairs({ -1, 0, 1 }) do
						for _, sy in ipairs({ -1, 1 }) do
							local p = cf * v3(sx * size.X / 2, sy * size.Y / 2, sz * size.Z / 2)
							top = math.max(top, p.Y)
							table.insert(points, p)
						end
					end
				end
				if top > 0.5 then
					tall += 1
					for _, point in ipairs(points) do
						if WorldBuilder.CoversBuildArea(map, point.X, point.Z, 0) then
							table.insert(offenders, string.format("%s@(%.0f,%.0f)", item.Name, point.X, point.Z))
							break
						end
					end
				end
			end
		end
		check(tall > 200, mapId .. " is a real place: " .. tall .. " standing parts")
		check(#offenders == 0, mapId .. " keeps every buildable spot clear: " .. table.concat(offenders, ", ", 1, math.min(#offenders, 6)))

		-- Streets: curbs trace the network's outline and never cross a road.
		local streets = world.streets or {}
		local gameplay, exits, rings = 0, 0, 0
		local crossing = {}
		for _, street in ipairs(streets) do
			if street.ring then rings += 1 elseif street.gameplay then gameplay += 1 else exits += 1 end
			check(street.aligned, mapId .. " streets run along the grid")
			for _, side in ipairs({ -1, 1 }) do
				local runs, line = WorldBuilder.CurbRuns(streets, street, side)
				for _, run in ipairs(runs) do
					for along = run[1] + 0.5, run[2] - 0.5, 1 do
						local x, z = street.alongX and along or line, street.alongX and line or along
						for _, other in ipairs(streets) do
							local reach = other.half
							local a, c = other.alongX and x or z, other.alongX and z or x
							if other ~= street and a > other.lo - reach and a < other.hi + reach and c > other.cross - reach and c < other.cross + reach then
								table.insert(crossing, string.format("(%.0f,%.0f)", x, z))
							end
						end
					end
				end
			end
		end
		check(gameplay >= #map.paths and exits >= 1 and rings == 4, mapId .. " has its routes, an exit street and the boulevard: " .. gameplay .. "/" .. exits .. "/" .. rings)
		check(#crossing == 0, mapId .. " curbs never cross another road: " .. table.concat(crossing, " ", 1, math.min(#crossing, 5)))

		-- The city itself.
		local counts = {}
		for _, item in ipairs(root:GetDescendants()) do counts[item.Name] = (counts[item.Name] or 0) + 1 end
		local lights, fires = 0, 0
		for _, item in ipairs(root:GetDescendants()) do
			local class = rawget(item, "__class")
			if class == "PointLight" or class == "SpotLight" then lights += 1 end
			if class == "Fire" then fires += 1 end
		end
		check((counts.Skyline or 0) >= 30, mapId .. " is walled in by buildings, got " .. tostring(counts.Skyline))
		check((counts.Lamp or 0) >= 8, mapId .. " lights its streets, got " .. tostring(counts.Lamp) .. " lamps")
		check((counts.CityLimit or 0) == 4, mapId .. " keeps commanders inside the city")
		check((counts.Boulevard or 0) == 4, mapId .. " has a boulevard on every side")
		check(lights >= 8 and lights <= 32, mapId .. " stays inside the light budget, got " .. lights)
		check(fires <= 4, mapId .. " stays inside the fire budget, got " .. fires)
		local parts = countClass(root, "BasePart")
		check(parts <= 3200, mapId .. " stays inside the mobile part budget, got " .. parts)
		for _, item in ipairs(root.Scenery:GetDescendants()) do
			if item:IsA("BasePart") and item.Name ~= "CityLimit" and not LANDMARKS[item.Name] and item.CanQuery ~= false then
				check(false, mapId .. " scenery never catches the placement cursor: " .. item.Name)
				break
			end
		end

		-- Terrain: the chapter's own ground, laid over the battlefield only.
		local fills = rawget(terrain, "__fills") or {}
		local ground, far = nil, 0
		for index = fillsBefore + 1, #fills do
			local fill = fills[index]
			local position = fill.cframe and fill.cframe.Position or fill.center
			local extent = fill.size and math.max(fill.size.X, fill.size.Z) / 2 or fill.radius
			if math.abs(position.Z) + extent > 200 or math.abs(position.X) + extent > 200 then far += 1 end
			if fill.kind == "Block" and fill.material.Name ~= "Air" and fill.size.X >= 300 then ground = fill.material.Name end
		end
		check(ground ~= nil, mapId .. " lays a terrain ground")
		check(far == 0, mapId .. " terrain stays inside the battlefield, clear of the lobby")
		if ground then groundMaterials[ground] = true end
		check(terrain:FindFirstChildOfClass("Clouds") ~= nil, mapId .. " has clouds")

		-- Enemy gates face down their street.
		for index, route in ipairs(map.paths) do
			local gate
			for _, item in ipairs(root.Scenery:GetChildren()) do
				if item.Name == "EnemyPortal" and math.abs(item.Position.X - route[1][1]) < 0.5 and math.abs(item.Position.Z - route[1][2]) < 0.5 then gate = item end
			end
			local dx, dz = route[2][1] - route[1][1], route[2][2] - route[1][2]
			local length = math.sqrt(dx * dx + dz * dz)
			local look = gate and gate.CFrame.LookVector
			check(look ~= nil and (look.X * dx + look.Z * dz) / length > 0.99, mapId .. " portal " .. index .. " faces the way its horde walks")
		end

		-- Street furniture gives way to towers.
		local furniture = root.Clutter:GetChildren()
		check(#furniture >= 8, mapId .. " furnishes its sidewalks, got " .. #furniture)
		local lamp = furniture[1]
		if lamp then
			local x, z = lamp:GetAttribute("ClutterX"), lamp:GetAttribute("ClutterZ")
			world:MakeTower("clutter-test", Catalog.HeroOrder[1], v3(x, 0, z), 1)
			check(lamp.Parent == nil, mapId .. " clears the furniture under a new tower")
		end
		print(string.format("  %s: %d parts, %d lamps, %d lights, %d buildings, %d standing", mapId, parts, counts.Lamp or 0, lights, counts.Skyline or 0, tall))
	end
	local distinct = 0
	for _ in pairs(groundMaterials) do distinct += 1 end
	check(distinct >= 4, "the chapters stand on different ground, got " .. distinct .. " materials")
end

print("--- rebuild ---")
world:Build("manhattan")
local first = countClass(workspace:FindFirstChild("DoomWorld"), "BasePart")
world:Build("manhattan")
local second = countClass(workspace:FindFirstChild("DoomWorld"), "BasePart")
check(first == second, "rebuilding a map replaces it instead of stacking, " .. tostring(first) .. " vs " .. tostring(second))
local worlds = 0
for _, child in ipairs(workspace:GetChildren()) do
	if child.Name == "DoomWorld" then worlds += 1 end
end
check(worlds == 1, "only one world model survives a rebuild, got " .. tostring(worlds))

--==============================================================================
-- Towers
--==============================================================================
print("--- final art ---")
do
	-- A stand-in for a model an artist exported from Studio.
	local storage = game:GetService("ReplicatedStorage")
	local art = Instance.new("Folder")
	art.Name, art.Parent = "DoomArt", storage
	local heroes = Instance.new("Folder")
	heroes.Name, heroes.Parent = "Heroes", art
	local template = Instance.new("Model")
	template.Name, template.Parent = "ironman", heroes
	local body = Instance.new("Part")
	body.Name, body.Size, body.CFrame, body.Parent = "ArtBody", v3(2, 5, 1), CFrame.new(0, 2.5, 0), template
	local head = Instance.new("Part")
	head.Name, head.Size, head.CFrame, head.Parent = "Head", v3(1, 1, 1), CFrame.new(0, 5.5, 0), template
	local muzzle = Instance.new("Attachment")
	muzzle.Name, muzzle.Parent = "Muzzle", body
	template.PrimaryPart = body
	world:Build("manhattan")
	local tower = world:MakeTower("art1", "ironman", v3(20, 0, 20), 1)
	local figure = tower:FindFirstChild("HeroFigure")
	check(figure ~= nil and figure:GetAttribute("HeroArt") == true, "a hero with final art uses it for its tower")
	check(tower:FindFirstChild("Suit", true) == nil, "the generated figure is not built next to the art")
	check(figure and figure:FindFirstChild("ArtBody") ~= nil and figure:FindFirstChild("Muzzle", true) ~= nil, "the art keeps its parts and its muzzle")
	local art1 = figure and figure:FindFirstChild("ArtBody")
	check(art1 ~= nil and art1.CanCollide == false and art1:GetAttribute("TowerId") == "art1", "art parts never collide and still select their tower")
	check(tower:FindFirstChild("Platform") ~= nil and tower:FindFirstChild("PowerRing") ~= nil, "the platform and ring stay: they are gameplay, not art")
	check(template:FindFirstChild("ArtBody") ~= nil, "the template itself is left untouched")
	local plain = world:MakeTower("plain1", "hawkeye", v3(-20, 0, 20), 1)
	local jointed = plain:FindFirstChild("HeroFigure")
	check(jointed ~= nil and jointed:GetAttribute("HeroRig") == true and jointed:FindFirstChild("UpperTorso") ~= nil, "a hero without art keeps its generated, jointed figure")
	art:Destroy()
end

print("--- towers ---")
local portraits = game:GetService("ReplicatedStorage"):FindFirstChild("DoomHeroPortraits")
check(portraits ~= nil, "portrait library survives separately from the map")
for _, heroId in ipairs(Catalog.HeroOrder) do
	local portrait = portraits and portraits:FindFirstChild(heroId)
	check(portrait and portrait:FindFirstChild("UpperTorso", true) ~= nil, heroId .. " has a portrait torso")
	check(portrait and portrait:FindFirstChild("Head", true) ~= nil, heroId .. " has a portrait head")
	if portrait then
		for _, piece in ipairs(portrait:GetDescendants()) do
			if piece:IsA("BasePart") then check(piece:GetAttribute("HeroVisual") == true, heroId .. " portrait excludes world furniture") end
		end
		-- A jointed body: fifteen segments on Motor6D joints under one root.
		local joints = 0
		for _, item in ipairs(portrait:GetDescendants()) do if item:IsA("Motor6D") then joints += 1 end end
		check(joints >= 15, heroId .. " is a jointed figure, got " .. joints .. " joints")
		local head = portrait:FindFirstChild("Head", true)
		check(head and head:FindFirstChildOfClass("SpecialMesh") ~= nil, heroId .. " has the classic rounded head")
	end
end
world:Build("manhattan")
local function sameColor(a, b) return a ~= nil and b ~= nil and a.R == b.R and a.G == b.G and a.B == b.B end
local placed, missing = 0, {}
for _, heroId in ipairs(Catalog.HeroOrder) do
	local made, model = pcall(function() return world:MakeTower("t" .. heroId, heroId, v3(20, 0, 20), 1) end)
	if made and model then
		placed += 1
		if countClass(model, "BasePart") < 5 then table.insert(missing, heroId .. ":thin") end
		if model:GetAttribute("HeroId") ~= heroId then table.insert(missing, heroId .. ":attr") end
		local upgraded = pcall(function() world:UpgradeTower(model, 5, 1, 20) end)
		if not upgraded then table.insert(missing, heroId .. ":upgrade") end
		-- A maxed hero is meant to look different from a fresh one.
		if model:FindFirstChild("UpgradeMarkers") == nil then table.insert(missing, heroId .. ":markers") end
		if model:FindFirstChildOfClass("Highlight") == nil then table.insert(missing, heroId .. ":awakened") end
		-- The two final specializations must look different from each other,
		-- not only from an unspecialized tower (every upgrade must change
		-- something visible, per the design brief).
		local other = world:MakeTower("t" .. heroId .. "_b2", heroId, v3(-20, 0, -20), 1)
		world:UpgradeTower(other, 5, 2, 20)
		local ringA = model:FindFirstChild("PowerRing")
		local ringB = other:FindFirstChild("PowerRing")
		if sameColor(ringA and ringA.Color, ringB and ringB.Color) then table.insert(missing, heroId .. ":branch-color") end
		local markers = model:FindFirstChild("UpgradeMarkers")
		-- A jointed hero wears the branch (a halo in its colour) instead of an emblem.
		if not markers or not (markers:FindFirstChild("BranchEmblem") or model:FindFirstChild("GearHalo", true)) then table.insert(missing, heroId .. ":branch-emblem") end
		-- The client's firing recoil animates the ring and restores it to this
		-- attribute. If an upgrade stopped publishing it, every upgraded tower
		-- would silently snap back to its level 1 ring the next time it fired.
		if not ringA or ringA:GetAttribute("BaseSize") ~= ringA.Size.Y then
			table.insert(missing, heroId .. ":ring-basesize")
		end
	else
		table.insert(missing, heroId .. ":build")
	end
end
check(placed == #Catalog.HeroOrder, "every hero has a tower model, got " .. tostring(placed))
check(#missing == 0, "each tower is complete, upgradeable and branch-distinct: " .. table.concat(missing, ", "))
print(string.format("  %d herois modelados", placed))

for _,id in ipairs(Catalog.BaseOrder) do
	for level=1,5 do
		local position=world:UpdateBase(1,{id=id,level=level},v3(88,0,78))
		local model=world.Scenery:FindFirstChild("PlayerBase_1")
		check(model~=nil and model:FindFirstChild("Building")~=nil,"base model exists: "..id.."/"..level)
		check(math.abs(position.X)<=100 and math.abs(position.Z)<=100,"base respects map bounds")
		local markers=0
		for _,item in ipairs(model:GetChildren()) do
			if item.Name=="LevelLamp" then markers+=1 end
			if item:IsA("BasePart") then check(not item.CanCollide,"base decoration cannot block player") end
		end
		check(markers==level,"base upgrade level is visible")
	end
end

print(string.format("%s world boot: %d checks, %d failures",
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error("world boot failed", 0) end
