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
		if piece.Name=="ForestTrunk" then trees+=1 end
		if piece.Name=="JumpStone" and piece.CanCollide then stones+=1 end
		if piece.Name=="ForestTrail" and piece.CanCollide then trails+=1 end
		if piece:IsA("BasePart") then check(piece.Position.Z>150,"Forest stays outside all combat terrain bounds") end
	end
	check(trees>=30,"Forest surrounds the plaza with mature trees, got "..tostring(trees))
	check(stones==7 and trails>=7,"Exploration paths and jumping stones are traversable")
	check(sanctuary:FindFirstChild("AuroraHeart")~=nil and sanctuary:FindFirstChild("AuroraFalls")~=nil,"Tree landmark and waterfall exist")
	check(countClass(lobby,"BasePart")<3500,"Expanded lobby remains under its geometry budget")
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
	check(lobbyEmitters == #Catalog.DestinationOrder * 2 + 2 + #Catalog.AfkOrder, "each destination emits from its glass and pad, plus the two shops and each AFK farm, got " .. tostring(lobbyEmitters))
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
		local sign = model:FindFirstChild("Sign")
		local surface = sign and sign:FindFirstChild("Board")
		check(surface ~= nil and surface:FindFirstChildOfClass("TextLabel") ~= nil, modeId .. ": the portal has a sign each client rewrites for its viewer")
	end
end

check(#(byKind.HeroPedestal or {}) == 0,"the lobby no longer displays hero statues")
local portraits=game:GetService("ReplicatedStorage"):FindFirstChild("DoomHeroPortraits")
for _,heroId in ipairs(Catalog.HeroOrder) do check(portraits and portraits:FindFirstChild(heroId),"removing statues preserves portrait "..heroId) end

check(#(byKind.SkillPedestal or {}) == 0, "talents live in HUD")
check(#(byKind.ChestStand or {}) == 2, "two recruitment chest stands")
do
	local root={Position=world.shopZones.rare.center}
	local visitor={UserId=801,Character={FindFirstChild=function(_,name) return name=="HumanoidRootPart" and root or nil end}}
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

check(#(byKind.ShopStand or {}) == 6, "one stand per pass plus one gold vault, got "
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
	local expected = 2 + 6 + 7 + 1
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
local expectedPrompts = 2 + 6 + 7 + 1
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
print("--- towers ---")
local portraits = game:GetService("ReplicatedStorage"):FindFirstChild("DoomHeroPortraits")
check(portraits ~= nil, "portrait library survives separately from the map")
for _, heroId in ipairs(Catalog.HeroOrder) do
	local portrait = portraits and portraits:FindFirstChild(heroId)
	check(portrait and portrait:FindFirstChild("Suit") ~= nil, heroId .. " has a portrait torso")
	check(portrait and portrait:FindFirstChild("Mask") ~= nil, heroId .. " has a portrait head")
	if portrait then
		for _, piece in ipairs(portrait:GetDescendants()) do
			if piece:IsA("BasePart") then check(piece:GetAttribute("HeroVisual") == true, heroId .. " portrait excludes world furniture") end
			if piece:IsA("BasePart") and table.find({"Suit","Thigh","Shin","UpperArm","Gauntlet"},piece.Name) then
				check(piece.Shape==Enum.PartType.Block,heroId.." uses continuous body segments: "..piece.Name)
			end
		end
		check(portrait.Mask:FindFirstChildOfClass("SpecialMesh")~=nil,heroId.." preserves head proportions with a mesh")
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
		if not markers or not markers:FindFirstChild("BranchEmblem") then table.insert(missing, heroId .. ":branch-emblem") end
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
