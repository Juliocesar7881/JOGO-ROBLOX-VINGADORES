--!nonstrict
-- Builds the real world: the lobby and every campaign map, outside Roblox.
--
-- Everything a player sees is generated at run time by WorldBuilder, so until
-- this ran, nothing proved the world could be built at all. A typo here is the
-- difference between a game and an empty void, and no other test would catch it.

local Stubs = __STUBS__
local v3 = Stubs.v3

local Catalog = __CATALOG__
local Config = __CONFIG__
local WorldBuilder = __WORLD__
local Motion = __MOTION__
local InteractionHud = __INTERACTION__

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

do
	for _,style in ipairs({"smash","strike","slash","bow","shoot","magic","punch"}) do
		local impact,prepare=Motion.AttackEnvelope(0,1,style)
		check(impact==1 and prepare==0,style..": impact on confirmed shot")
		local recovered=Motion.AttackEnvelope(0.6,1,style)
		check(recovered==0,style..": recovery completes before next attack")
		local _,windup=Motion.AttackEnvelope(0.99,1,style)
		check(windup>0.9,style..": prepares the next cosmetic pose")
		local _,ended=Motion.AttackEnvelope(2,1,style)
		check(ended==0,style..": no perpetual windup after combat ends")
	end
	check(Motion.WindupEnvelope(0.19,0.2)>0.98,"confirmed anticipation approaches its full pose")
	check(Motion.WindupEnvelope(0.3,0.2)==0 and Motion.WindupEnvelope(math.huge,nil)==0,"expired/missing windup cannot stick")
	local camera={ViewportSize={X=800,Y=600},WorldToViewportPoint=function(_,point) return point,point.Z>0 end}
	check(InteractionHud.InView(camera,v3(400,300,1),270,66),"Whole billboard fits at screen center")
	check(not InteractionHud.InView(camera,v3(100,300,1),270,66),"Left edge cannot cut billboard")
	check(not InteractionHud.InView(camera,v3(700,300,1),270,66),"Right edge cannot cut billboard")
	check(not InteractionHud.InView(camera,v3(400,30,1),270,66),"Top edge cannot cut billboard")
	check(not InteractionHud.InView(camera,v3(400,580,1),270,66),"Bottom edge cannot cut billboard")
	check(not InteractionHud.InView(camera,v3(400,300,-1),270,66),"Behind-camera billboards are hidden")
	camera.ViewportSize={X=375,Y=667}
	check(not InteractionHud.InView(camera,v3(400,300,1),270,66),"Resize recomputes visible rectangle")
end

--==============================================================================
-- Lobby: a diegetic hub, not a single panel with tabs
--==============================================================================
print("--- lobby ---")
local panels = {}
local ok, world = pcall(WorldBuilder.new, Catalog, function(player, panel, data)
	table.insert(panels, { player=player,panel = panel, data = data or {} })
end, Config)
check(ok, "WorldBuilder.new builds the lobby: " .. tostring(world))
if not ok then
	print("FAIL match: world could not be constructed")
	error("world boot failed", 0)
end

--==============================================================================
-- Enemy figures: up to 180 walk at once, so each one has a part budget
--==============================================================================
print("--- enemy figures ---")
do
	local storage = game:GetService("ReplicatedStorage")
	local folder = storage:FindFirstChild("DoomFigures")
	local enemies = folder and folder:FindFirstChild("Enemies")
	check(enemies ~= nil, "the published enemy figures exist")
	local report = {}
	-- A boss towers over the defence: at least twice a hero tower (towers stand at 1.15x a figure).
	do
		local portrait = storage:FindFirstChild("DoomHeroPortraits") and storage.DoomHeroPortraits:FindFirstChild("ironman")
		local hero = portrait and portrait:FindFirstChild("HeroFigure")
		local tower = hero and (hero:GetAttribute("FigureHeight") or 0) * 1.15 or 0
		for id, def in pairs(Catalog.Enemies) do
			local figure = enemies and enemies:FindFirstChild(id)
			if def.boss and figure then
				local height = figure:GetAttribute("FigureHeight") or 0
				check(tower > 0 and height >= tower * 2, id .. " stands at least twice a hero tower, got " .. string.format("%.1f vs %.1f", height, tower))
			end
		end
	end
	for id, def in pairs(Catalog.Enemies) do
		local figure = enemies and enemies:FindFirstChild(id)
		check(figure ~= nil, "every enemy has a published figure: " .. id)
		if figure then
			local parts = 0
			for _, item in ipairs(figure:GetDescendants()) do if item:IsA("BasePart") then parts += 1 end end
			table.insert(report, id .. "=" .. parts)
			-- A common enemy is drawn by the hundred; only a boss may be elaborate.
			check(parts <= (def.boss and 60 or 40), id .. " stays inside its part budget, got " .. parts)
			if (def.family or id) == "armored" then
				local plate = figure:FindFirstChild("Pauldron")
				check(plate and plate:IsA("WedgePart"), id .. " has sloped armour with its existing geometry")
			end
		end
	end
	table.sort(report)
	print("  parts: " .. table.concat(report, " "))
	-- Variety (owner, 16/10): the plain families come in several outfits, each
	-- published beside the family's own look and inside the crowd's budget.
	local looks = {}
	for _, figure in ipairs(enemies and enemies:GetChildren() or {}) do
		local base, index = string.match(figure.Name, "^(.-)#(%d+)$")
		if base then
			local def = Catalog.Enemies[base]
			local parts = 0
			for _, item in ipairs(figure:GetDescendants()) do if item:IsA("BasePart") then parts += 1 end end
			check(def ~= nil and not def.boss and def.faction == nil, figure.Name .. " dresses a plain family")
			check(parts <= 40, figure.Name .. " stays inside the crowd's part budget, got " .. parts)
			check(figure:GetAttribute("Outfit") ~= nil and figure:GetAttribute("Gait") == enemies[base]:GetAttribute("Gait"), figure.Name .. " is an outfit that walks like its family")
			if base == "armored" then
				local plate = figure:FindFirstChild("Pauldron")
				check(plate and plate:IsA("WedgePart"), figure.Name .. " keeps its sloped armour")
			end
			looks[base] = math.max(looks[base] or 1, tonumber(index))
		end
	end
	for id, wanted in pairs({ zombie = 7, runner = 4, brute = 3, armored = 3, flyer = 3 }) do
		local base = enemies and enemies:FindFirstChild(id)
		check(base ~= nil and base:GetAttribute("Outfits") == wanted and looks[id] == wanted, id .. " comes in " .. wanted .. " looks, got " .. tostring(looks[id]))
	end
	-- Original villains (IP_POLICY): no boss brings back a known villain's
	-- signature piece or palette, and the starter armour is not red and gold.
	local banned = {
		lizard = { "Coat", "CoatTail" }, abomination = { "Fin", "Gill" },
		redskull = { "Cube", "Socket", "Nose", "CommandMantle" }, killmonger = { "Ear", "Muzzle", "Fang" },
		doom = { "Hood", "Slit", "Grille", "Mask" }, loki = { "Horn", "Helmet", "Gem", "Scepter" },
	}
	for id, names in pairs(banned) do
		local figure = enemies and enemies:FindFirstChild(id)
		for _, name in ipairs(names) do
			check(figure ~= nil and figure:FindFirstChild(name, true) == nil, id .. " no longer carries the villain piece " .. name)
		end
	end
	local function share(figure, test)
		local hits, total = 0, 0
		for _, item in ipairs(figure and figure:GetDescendants() or {}) do
			if item:IsA("BasePart") and item.Name ~= "HumanoidRootPart" and (item.Transparency or 0) < 1 then
				total += 1
				local color = item.Color
				if test(color.R * 255, color.G * 255, color.B * 255) then hits += 1 end
			end
		end
		return total > 0 and hits / total or 1
	end
	local function green(r, g, b) return g > r + 25 and g > b + 15 end
	local function red(r, g, b) return r > 150 and g < 90 and b < 90 end
	local function gold(r, g, b) return r > 200 and g > 150 and b < 110 end
	check(share(enemies:FindFirstChild("redskull"), red) < 0.05, "the foundry commander wears no red head or red coat")
	check(share(enemies:FindFirstChild("doom"), green) < 0.05 and share(enemies:FindFirstChild("loki"), green) < 0.05, "the tyrant and the illusion master wear no green")
	check(share(enemies:FindFirstChild("killmonger"), gold) < 0.05, "the raider king wears no gold")
	check(share(enemies:FindFirstChild("lizard"), green) < 0.1, "the gecko is not green")
	local armor = storage:FindFirstChild("DoomHeroPortraits") and storage.DoomHeroPortraits:FindFirstChild("ironman")
	check(armor ~= nil and armor:FindFirstChild("ArcReactorCore", true) == nil and armor:FindFirstChild("ChestBolt", true) ~= nil, "the starter armour carries a bolt, not a round chest reactor")
	check(share(armor, red) + share(armor, gold) < 0.05, "the starter armour is not red and gold")
end

-- A preview figure can be posed by hand (Motion.Rig / Motion.Solve): the same
-- joints the towers use, solved outward from the root with every part anchored.
do
	local portraits = game:GetService("ReplicatedStorage"):FindFirstChild("DoomHeroPortraits")
	local source = portraits and portraits:FindFirstChild("thor")
	local figure = source and source:FindFirstChild("HeroFigure", true)
	check(figure ~= nil and figure:GetAttribute("HeroArt") == true, "a hero's portrait source holds its jointed figure")
	if figure then
		local copy = figure:Clone()
		for _, item in ipairs(copy:GetDescendants()) do if item:IsA("BasePart") then item.Anchored = true end end
		local rig = Motion.Rig(copy)
		check(rig ~= nil and rig.joints ~= nil and rig.joints.LeftShoulder ~= nil and rig.joints.RightShoulder ~= nil, "the rig finds the figure's joints")
		if rig and rig.joints then
			local function part(name) return copy:FindFirstChild(name, true) end
			local function pose(values)
				Motion.Reset(rig.joints)
				Motion.Hero(rig.joints, values)
				Motion.Solve(rig)
			end
			pose({ breathe = 0 })
			local head, hand, shoulder = part("Head"), part("LeftHand"), part("LeftUpperArm")
			check(head ~= nil and hand ~= nil and shoulder ~= nil, "the figure has a head, a hand and an upper arm")
			local restY = hand.Position.Y
			local shoulderToHand = (hand.Position - shoulder.Position).Magnitude
			check(hand.Position.Y < head.Position.Y - 1, "at rest the hand hangs well below the head")
			pose({ cast = 1, breathe = 0 })
			check(hand.Position.Y > head.Position.Y, "a cheer lifts the hand above the head, got " .. tostring(hand.Position.Y - head.Position.Y))
			check(math.abs((hand.Position - shoulder.Position).Magnitude - shoulderToHand) < 0.35 * shoulderToHand, "the arm keeps its length while it moves")
			check(hand.Position.Y > restY + 1.5, "the hand really travelled")
			local muzzle = copy:FindFirstChild("Muzzle",true)
			if muzzle then
				local expected = (muzzle.Parent.CFrame*CFrame.new(muzzle.Position)).Position
				local stale = muzzle.Parent.CFrame
				muzzle.Parent.CFrame = stale*CFrame.new(100,0,0)
				local resolved = Motion.Point(rig,muzzle.Parent,muzzle.Position)
				check((resolved-expected).Magnitude<0.001,"emission resolves the current pose despite a stale physics attachment")
				Motion.Solve(rig)
			end
			-- Moving the root carries the whole figure with it.
			local rootAt = rig.root.Position
			rig.root.CFrame = rig.root.CFrame * CFrame.new(0, 3, 0)
			Motion.Solve(rig)
			check(math.abs(head.Position.Y - (rootAt.Y + 3 + (head.Position.Y - rootAt.Y - 3))) < 1e-3 and head.Position.Y > rootAt.Y + 3, "moving the root moves every part")
			-- Welded extras (capes, hammers) follow their host.
			local welded = 0
			for _, joint in ipairs(copy:GetDescendants()) do if joint:IsA("Weld") then welded += 1 end end
			check(welded > 0, "the figure has welded gear that follows its body, found " .. welded)
		end
	end
end

local lobby = workspace:FindFirstChild("DoomLobby")
check(lobby ~= nil, "the lobby model lands in the workspace")
check(countClass(lobby, "BasePart") > 40,
	"the lobby has real geometry, got " .. tostring(countClass(lobby, "BasePart")) .. " parts")
check(lobby:FindFirstChild("LobbySpawn") ~= nil, "the lobby has a spawn point")
check(world.lobbySpawn ~= nil, "the spawn position is recorded for MovePlayer")
do
	for _, id in ipairs({"maps", "inventory", "bases", "talents", "quests", "leaderboard"}) do
		local board = lobby:FindFirstChild("Board_" .. id)
		local panel = board and board:FindFirstChild("Panel")
		local surface = panel and panel:FindFirstChild("Board")
		local face = panel and -panel.CFrame.LookVector
		local towardPlaza = panel and (v3(0, panel.Position.Y, 480) - panel.Position).Unit
		check(surface and surface.Face == Enum.NormalId.Back and face:Dot(towardPlaza) > 0.98, id .. ": readable screen faces the central plaza")
		local frame = board and board:GetAttribute("ServiceFrame")
		local localAt = frame and frame:Inverse() * panel.Position
		check(localAt and math.abs(localAt.X) < 0.01 and localAt.Z < 0 and localAt.Z > -2 and panel.Size.X <= 9.2, id .. ": screen stays between its rear supports, behind the counter")
		local connected = false
		for _, mount in ipairs(lobby.HubServices:GetChildren()) do
			if mount.Name == "ServiceScreenMount" then
				local delta = panel.CFrame:Inverse() * mount.Position
				if math.abs(delta.X) <= (panel.Size.X + mount.Size.X) / 2 and math.abs(delta.Y) <= (panel.Size.Y + mount.Size.Y) / 2
					and math.abs(delta.Z) <= (panel.Size.Z + mount.Size.Z) / 2 then connected = true end
			end
		end
		check(connected, id .. ": sign physically meets its support instead of floating in front of it")
		check(surface and surface.Title.TextSize > surface.Status.TextSize and surface.Title:GetAttribute("LobbyTextEN") ~= nil, id .. ": short localized title has its own visual hierarchy")
	end
	local emblems = 0
	for _, model in ipairs(lobby.HubServices:GetChildren()) do
		if model:IsA("Model") and string.sub(model.Name, 1, 11) == "DeskEmblem_" then
			emblems += 1
			for _, piece in ipairs(model:GetDescendants()) do
				if piece:IsA("BasePart") then check(piece:GetAttribute("Bob") == 0.35, model.Name .. ": every compound piece follows the medal") end
			end
		end
	end
	check(emblems == 6, "all six service medals share a complete animation")
end
-- The bay used to contain a 360-stud square void before any battle existed.
do
	local fills=rawget(workspace.Terrain,"__fills") or {}
	for _, point in ipairs({v3(-170,-5,-170),v3(170,-5,-170),v3(-170,-5,170),v3(170,-5,170),v3(0,-5,0)}) do
		local water=false
		for _,fill in ipairs(fills) do
			if fill.kind=="Block" and fill.material==Enum.Material.Water then
				local at=fill.cframe:Inverse()*point
				if math.abs(at.X)<=fill.size.X/2 and math.abs(at.Y)<=fill.size.Y/2 and math.abs(at.Z)<=fill.size.Z/2 then water=true end
			end
		end
		check(water,"uninterrupted water before the first match: "..tostring(point))
	end
	local tower=lobby:FindFirstChild("HeroTower")
	local floor=tower and tower:FindFirstChild("TowerPassageFloor")
	check(floor and floor.CanCollide and math.abs(floor.Position.Y+floor.Size.Y/2-WorldBuilder.HQ.groundY)<.05,"tower passage has a solid floor flush with the road")
	check(floor and floor.Size.X>=14 and floor.Size.Z>=28,"paved passage covers the gap between the connecting roads")
	local plaza=lobby.HeroesHQ:FindFirstChild("TowerPlaza")
	local road=lobby.HeroesHQ:FindFirstChild("TowerRoad")
	check(floor and math.abs(floor.Position.Z-floor.Size.Z/2-(plaza.Position.Z+plaza.Size.Z/2))<.05 and math.abs(floor.Position.Z+floor.Size.Z/2-(road.Position.Z-road.Size.Z/2))<.05,"passage joins both roads without gaps or overlapping top surfaces")
	check(tower and tower:FindFirstChild("PremiumShopSign") and not tower:FindFirstChild("StarkShopTitle"),"premium shop uses a physical sign")
	for _, name in ipairs({"Shop_heroes","Shop_gold","Shop_collector","Shop_training","Shop_vip"}) do
		local shop=lobby:FindFirstChild(name)
		local plaque=shop and shop:FindFirstChild("ProductPlaque")
		check(plaque and plaque:FindFirstChild("Title",true):GetAttribute("LobbyTextEN")~=nil,name.." has a localized physical product plaque")
	end
	check(lobby.Shop_collector:FindFirstChild("DroneMotor") and lobby.Shop_gold:FindFirstChild("VaultDoor") and lobby.Shop_training:FindFirstChild("TrainingScreen"),"products have distinct equipment silhouettes")
	for _,name in ipairs({"Chest_rare","Chest_base_epic"}) do
		local hall=lobby:FindFirstChild(name)
		local windows=0
		for _,p in ipairs(hall:GetChildren()) do if p.Name=="HallWindowGlass" then windows+=1 end end
		check(windows==4,name.." has framed glazing on both side walls")
	end
end
-- Close-up architectural detail must leave the four routes and the service
-- approach usable. Sweep a player's body through each compass entrance.
do
	local hub, floor = WorldBuilder.HQ.hub, WorldBuilder.HQ.groundY
	local blocked = {}
	local obstacles = {}
	for _, item in ipairs(lobby:GetDescendants()) do
		if item:IsA("BasePart") and item.CanCollide and (string.find(item.Name,"Garden") or string.find(item.Name,"Statue") or string.find(item.Name,"Lantern")) then
			table.insert(obstacles,item)
		end
	end
	for _, direction in ipairs({v3(1,0,0),v3(-1,0,0),v3(0,0,1),v3(0,0,-1)}) do
		local side=v3(-direction.Z,0,direction.X)
		for distance=10,68,2 do for _, lane in ipairs({-5,0,5}) do
			local at=hub+direction*distance+side*lane+v3(0,floor+2.7,0)
			for _,p in ipairs(obstacles) do
				local localPoint=p.CFrame:Inverse()*at
				if math.abs(localPoint.X)<p.Size.X/2+1 and math.abs(localPoint.Y)<p.Size.Y/2+1.7 and math.abs(localPoint.Z)<p.Size.Z/2+1 then table.insert(blocked,p.Name) end
			end
		end end
	end
	check(#blocked==0,"plaza entrance routes clear for a player's body: "..table.concat(blocked,","))
	local gardens=0
	for _,garden in ipairs(lobby.HeroesHQ:GetChildren()) do if garden.Name=="PlazaGarden" then
		gardens+=1
		for _,p in ipairs(garden:GetChildren()) do if p.Name=="GardenFoundation" then
			check(p.CanCollide and p.Position.Y-p.Size.Y/2<=floor+.01 and p.Position.Y+p.Size.Y/2>=floor+1.45,"curved planter foundation reaches the ground")
		end end
	end end
	check(gardens==4,"four gardens frame the plaza without filling its entrances")
	for _,name in ipairs({"Chest_rare","Chest_base_epic"}) do
		local hall=lobby[name]
		local pane=hall:FindFirstChild("SummonPortalPane")
		check(pane and pane:FindFirstChild("PortalSwirl") and not pane.CanCollide,"summon portal art animates without blocking entry")
		check(not hall:FindFirstChild("PrizeBeam"),"summon hall has a mounted crest instead of an unsupported prize beam")
		local header=hall.SummonHeader.SignBack
		local joins=0
		for _,p in ipairs(hall:GetChildren()) do if p.Name=="HallHeaderSupport" then
			local at=header.CFrame:Inverse()*p.Position
			if math.abs(at.X)<header.Size.X/2 and math.abs(at.Y)<header.Size.Y/2 and math.abs(at.Z)<header.Size.Z/2+p.Size.Z/2 then joins+=1 end
		end end
		check(joins==2,"summon header rests on both physical supports")
	end
end
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

-- The Heroes' HQ: a hub island with a raised plaza, landmarks every child
-- can name, and scenery that never stands in anyone's way.
local hq = lobby:FindFirstChild("HeroesHQ")
check(hq ~= nil, "the HQ scenery is owned by the lobby model")
do
	local hub = WorldBuilder.HQ.hub
	check((world.lobbySpawn - hub).Magnitude < 8 and world.lobbySpawn.Y > WorldBuilder.HQ.plazaY, "everyone spawns on the raised hero plaza")
	check(hub.Z - 176 > 250, "the island lies well away from the battlefield square")
	for _, name in ipairs({ "HubDeck", "PlazaDeck", "RingRoad" }) do
		local piece = hq and hq:FindFirstChild(name)
		check(piece ~= nil and piece.CanCollide, "walkable hub surface: " .. name)
	end
	local bridges, islandBridges = 0, 0
	for _, piece in ipairs(hq and hq:GetChildren() or {}) do
		if piece:GetAttribute("BridgeId") then
			check(piece.CanCollide and piece.Size.X >= 10, "a bridge has a solid walkable deck: " .. piece.Name)
			if piece.Name == "IslandBridge" then islandBridges += 1 else bridges += 1 end
		end
	end
	check(bridges == 4 and islandBridges == 3, "four bridges cross the moat and three reach the islands, got " .. bridges .. "/" .. islandBridges)
	-- Landmarks.
	local beacon = lobby:FindFirstChild("HeroBeacon")
	local step = beacon and beacon:FindFirstChild("BeaconStep")
	local deck = hq and hq:FindFirstChild("HubInner")
	check(step and deck and math.abs(step.Position.Y - step.Size.X / 2 - (deck.Position.Y + deck.Size.X / 2)) < .03, "beacon foundation meets the lower hub deck instead of floating above it")
	local pierCounts = {MoatPier = 0, IslandPier = 0}
	for _, piece in ipairs(hq and hq:GetChildren() or {}) do
		if pierCounts[piece.Name] then
			pierCounts[piece.Name] += 1
			check(piece.CanCollide and piece.Position.Y + piece.Size.X / 2 < WorldBuilder.HQ.groundY, "bridge piling stays below the walkable surface")
			check(piece.Position.Y - piece.Size.X / 2 < -8, "bridge piling extends below the sea surface")
		end
	end
	check(pierCounts.MoatPier == 16 and pierCounts.IslandPier == 12, "all seven lobby bridges have four structural pilings")
	local academy = hq and hq:FindFirstChild("AcademySign")
	local supports = 0
	for _, piece in ipairs(academy and academy:GetChildren() or {}) do
		if piece.Name == "SignLeg" then
			supports += 1
			check(math.abs(piece.Position.Y - piece.Size.X / 2 - WorldBuilder.HQ.groundY) < .01, "academy board has a support reaching the ground")
		end
	end
	check(supports == 2, "academy board has two physical supports")
	local stones = 0
	for _, piece in ipairs(beacon and beacon:GetChildren() or {}) do
		if piece.Name == "JumpStone" and piece.CanCollide then stones += 1 end
	end
	check(stones == 7, "seven jump stones spiral up the hero beacon, got " .. stones)
	check(lobby:FindFirstChild("HeroTower") and lobby.HeroTower:FindFirstChild("TowerShaft") ~= nil, "the tower rises over the north road")
	local statues = lobby:FindFirstChild("HeroStatues")
	check(statues and statues:FindFirstChild("Statue_ironman") and statues:FindFirstChild("Statue_captain"), "two gameplay heroes greet the plaza")
	local portraits = game:GetService("ReplicatedStorage").DoomHeroPortraits
	for _, id in ipairs({"ironman", "captain"}) do
		local monument = statues:FindFirstChild("Statue_" .. id)
		local figure = monument and monument:FindFirstChild("HeroFigure")
		local source = portraits[id]:FindFirstChild("HeroFigure")
		check(figure and figure:GetAttribute("HeroArt") and not figure:GetAttribute("IdleFigure"), id .. ": the enlarged gameplay figure stays still")
		if figure then
			check(figure:GetAttribute("FigureScale") == source:GetAttribute("FigureScale") * 2, id .. ": monument doubles the gameplay model scale")
			local count = 0
			for _, piece in ipairs(figure:GetDescendants()) do
				if piece:IsA("BasePart") and piece:GetAttribute("HeroVisual") then
					count += 1
					check(piece.Anchored, id .. ": all costume parts remain anchored")
				end
			end
			local sourceCount = 0
			for _, piece in ipairs(source:GetDescendants()) do
				if piece:IsA("BasePart") and piece:GetAttribute("HeroVisual") then sourceCount += 1 end
			end
			check(count == sourceCount, id .. ": complete gameplay costume reused without substitute pieces")
			local chest = figure:FindFirstChild("UpperTorso")
			check(chest.Size == source.UpperTorso.Size * 2, id .. ": body proportions follow the original model")
			check(figure:FindFirstChild(id == "ironman" and "ChestBolt" or "Shield", true) ~= nil, id .. ": original signature equipment is present")
			local hips = figure.LowerTorso:FindFirstChild("BodyContour")
			check(hips.MeshType == Enum.MeshType.Brick and hips.Scale == Vector3.one, id .. ": waist has a continuous silhouette")
			-- The monument strikes a pose and still stands on its pedestal: the soles
			-- touch the top plate (no floating, no feet sunk into the stone).
			check(figure:GetAttribute("StatuePosed") == true, id .. ": the statue holds a heroic pose")
			local top = statues:FindFirstChild("StatueTopField")
			local lowest = math.huge
			for _, piece in ipairs(figure:GetDescendants()) do
				if piece:IsA("BasePart") and piece:GetAttribute("HeroVisual") and piece.Name ~= "HumanoidRootPart" then
					lowest = math.min(lowest, piece.Position.Y - piece.Size.Y / 2)
				end
			end
			local deck = top and (top.Position.Y + 0.01) or lowest
			check(math.abs(lowest - deck) < 0.35, id .. ": the posed statue stands on its pedestal, soles at " .. string.format("%.2f", lowest) .. " vs deck " .. string.format("%.2f", deck))
			if id == "captain" then
				-- An open face under the helmet (skin, not a mask the colour of the suit).
				local head, helmet = figure:FindFirstChild("Head"), figure:FindFirstChild("Helmet")
				check(head and helmet and head.Color ~= helmet.Color and head.Color.R > head.Color.B, "the captain shows his face under the helmet")
				-- His own winged badge sits ahead of the chest.
				local chestBadge = figure:FindFirstChild("ChestBadge")
				check(chestBadge and chestBadge.Fit.C0.Position.Z < -figure.UpperTorso.Size.Z / 2, "the chest badge sits on the front of the uniform")
				-- The shield is turned toward the front, not a thin oval on the side,
				-- and its badge sits ahead of its core along the shield's own axis.
				local shield, core, badge = figure:FindFirstChild("Shield"), figure:FindFirstChild("ShieldCore"), figure:FindFirstChild("ShieldBadge")
				check(shield and math.abs(shield.Fit.C0.RightVector.Z) > 0.6, "the shield faces the front")
				if shield and core and badge then
					local axis = shield.Fit.C0.RightVector
					local ahead = (badge.Fit.C0.Position - core.Fit.C0.Position):Dot(axis)
					local coreAhead = (core.Fit.C0.Position - shield.Fit.C0.Position):Dot(axis)
					check(ahead * coreAhead > 0 and math.abs(ahead) > 0, "the shield badge sits on the outside face")
				end
				check(figure:FindFirstChild("Star", true) == nil, "no star on the captain: his badge is his own")
			end
		end
	end
	local outpost = hq and hq:FindFirstChild("ShieldOutpost")
	for _, name in ipairs({ "QuinjetHull", "HelicarrierHull", "RadarDish", "CommandModule", "ArmoryDepot" }) do
		check(outpost and outpost:FindFirstChild(name, true) ~= nil, "S.H.I.E.L.D. set piece: " .. name)
	end
	check(hq and hq:FindFirstChild("CitySkyline") ~= nil, "a city skyline stands across the bay")
	-- Scenery is physical: nobody walks through the agency's jet, crates or buildings, nor through a trunk.
	local passable, checkedSolid = {}, 0
	for _, piece in ipairs(outpost and outpost:GetDescendants() or {}) do
		if piece:IsA("BasePart") and piece.Material ~= Enum.Material.Neon and piece.Material ~= Enum.Material.ForceField and (piece.Transparency or 0) < 0.45
			and math.min(piece.Size.X, piece.Size.Y, piece.Size.Z) >= 0.35 and piece.Position.Y < 24 then
			checkedSolid += 1
			if not piece.CanCollide then table.insert(passable, piece.Name) end
		end
	end
	check(checkedSolid > 40, "the agency set pieces have plenty of solid parts to check, got " .. checkedSolid)
	check(#passable == 0, "every agency set piece is solid, yet passable: " .. table.concat(passable, ", "))
	local trunks, softTrunks = 0, 0
	for _, piece in ipairs(lobby:GetDescendants()) do
		if piece:IsA("BasePart") and (piece.Name == "TreeTrunk" or piece.Name == "PalmTrunk") then
			trunks += 1
			if not piece.CanCollide then softTrunks += 1 end
		end
	end
	check(trunks > 10 and softTrunks == 0, "tree and palm trunks stop a walking commander: " .. softTrunks .. " of " .. trunks .. " are passable")
	for _, piece in ipairs(outpost and outpost:GetDescendants() or {}) do
		check(not (piece:IsA("BasePart") and string.find(piece.Name, "Title", 1, true)), "the agency set pieces carry no title: " .. tostring(piece.Name))
	end
	-- Every area has its big illustrated sign, localized.
	for _, name in ipairs({ "CampaignSign", "AfkSign", "SummonSign", "ExpeditionSign", "LatveriaSign", "AcademySign" }) do
		local sign = hq and hq:FindFirstChild(name)
		local title = sign and sign:FindFirstChild("Title", true)
		check(title ~= nil and title:GetAttribute("LobbyTextPT") ~= nil and title:GetAttribute("LobbyTextEN") ~= nil, "area sign with a localized title: " .. name)
	end
	-- Things that move on the client: the globe, orbits, rotors, the patrol.
	local spinning = 0
	for _, piece in ipairs(lobby:GetDescendants()) do
		if piece:IsA("BasePart") and (piece:GetAttribute("Spin") or 0) ~= 0 then spinning += 1 end
	end
	check(spinning >= 30, "the lobby has living, moving set pieces, got " .. spinning)
	-- Scenery stays off every area floor, off the hub and off the bridges.
	local function onFloor(position, margin)
		for _, id in ipairs({ "campaign", "arena", "afk", "academy", "expedition", "latveria" }) do
			local center, width, depth = WorldBuilder.LobbyFloor(id)
			if math.abs(position.X - center.X) <= width / 2 + margin and math.abs(position.Z - center.Z) <= depth / 2 + margin then return id end
		end
		return nil
	end
	local misplaced = {}
	for _, grove in ipairs(hq and hq:GetChildren() or {}) do
		if grove:IsA("Model") and (grove.Name == "HQTree" or grove.Name == "HQPalm") and not grove:GetAttribute("Planted") then
			local trunk = grove:FindFirstChild("TreeTrunk") or grove:FindFirstChild("PalmTrunk")
			local at = trunk and trunk.Position
			if at then
				local offset = v3(at.X - hub.X, 0, at.Z - hub.Z)
				local area = onFloor(at, 1)
				if area or offset.Magnitude < 100 then table.insert(misplaced, grove.Name .. "@" .. (area or "hub")) end
				for _, zone in pairs(world.portalZones) do
					if v3(at.X - zone.center.X, 0, at.Z - zone.center.Z).Magnitude < 12 then table.insert(misplaced, grove.Name .. "@portal") end
				end
			end
		end
	end
	check(#misplaced == 0, "trees and palms stand on free grass only: " .. table.concat(misplaced, ", "))
	-- Every station stands on its area's paved floor.
	for portalId, destination in pairs(Catalog.Destinations) do
		check(onFloor(v3(destination.x, 0, destination.z), -2) ~= nil, "station " .. portalId .. " stands on an area floor")
	end
	check(countClass(lobby, "BasePart") < 4550, "the lobby remains under its geometry budget, got " .. tostring(countClass(lobby, "BasePart")))
	print("  lobby: " .. tostring(countClass(lobby, "BasePart")) .. " parts")
end
-- Nothing stands in front of a sign's letters (owner, 16/10: the summon
-- halls' gold supports crossed their titles). For every SurfaceGui in the
-- lobby that shows text, the box from its face to 6 studs out (inset a little
-- at the edges, where rims and studs frame a sign) holds no other visible part
-- than the sign's own. Oriented boxes, separating-axis test. The battle maps
-- are checked the same way below (their rooftop billboards).
local function blockedSigns(root)
	local function dot(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
	local function cross(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
	local function overlap(A, B)
		local axes = {}
		for _, u in ipairs(A.a) do table.insert(axes, u) end
		for _, u in ipairs(B.a) do table.insert(axes, u) end
		for _, u in ipairs(A.a) do for _, w in ipairs(B.a) do
			local c = cross(u, w)
			if c.Magnitude > 1e-6 then table.insert(axes, c.Unit) end
		end end
		local d = B.c - A.c
		for _, axis in ipairs(axes) do
			local ra, rb = 0, 0
			for i = 1, 3 do ra += A.h[i] * math.abs(dot(A.a[i], axis)); rb += B.h[i] * math.abs(dot(B.a[i], axis)) end
			if math.abs(dot(d, axis)) > ra + rb then return false end
		end
		return true
	end
	local function face(part, name)
		local cf, s = part.CFrame, part.Size
		if name == "Back" then return -cf.LookVector, s.Z, cf.RightVector, s.X, cf.UpVector, s.Y end
		if name == "Right" then return cf.RightVector, s.X, cf.LookVector, s.Z, cf.UpVector, s.Y end
		if name == "Left" then return -cf.RightVector, s.X, cf.LookVector, s.Z, cf.UpVector, s.Y end
		if name == "Top" then return cf.UpVector, s.Y, cf.RightVector, s.X, cf.LookVector, s.Z end
		if name == "Bottom" then return -cf.UpVector, s.Y, cf.RightVector, s.X, cf.LookVector, s.Z end
		return cf.LookVector, s.Z, cf.RightVector, s.X, cf.UpVector, s.Y
	end
	local function within(node, ancestor)
		while node do if node == ancestor then return true end node = node.Parent end
		return false
	end
	local solids = {}
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("BasePart") and (item.Transparency or 0) < 0.9 then table.insert(solids, item) end
	end
	local blocked, signs = {}, 0
	for _, gui in ipairs(root:GetDescendants()) do
		local host = gui:IsA("SurfaceGui") and gui.Parent
		local words
		if host and host:IsA("BasePart") then
			for _, label in ipairs(gui:GetDescendants()) do
				if label:IsA("TextLabel") and (label.Text or "") ~= "" then words = label.Text break end
			end
		end
		if words then
			signs += 1
			local n, depth, u, width, w, height = face(host, gui.Face and gui.Face.Name or "Front")
			local box = { c = host.Position + n * (depth / 2 + 3.05), a = { u, w, n }, h = { width / 2 * 0.92, height / 2 * 0.86, 3 } }
			-- The sign's own pieces (a Kit.sign model: back, rims, studs) frame it.
			local own = host.Parent and host.Parent:IsA("Model") and (host.Parent:FindFirstChild("SignBack") or host.Parent:FindFirstChild("SignFace")) and host.Parent
			for _, other in ipairs(solids) do
				if other ~= host and not (own and within(other, own)) then
					local B = { c = other.Position, a = { other.CFrame.RightVector, other.CFrame.UpVector, other.CFrame.LookVector }, h = { other.Size.X / 2, other.Size.Y / 2, other.Size.Z / 2 } }
					if overlap(box, B) then table.insert(blocked, words .. ": " .. other.Name .. " in " .. tostring(other.Parent and other.Parent.Name)) end
				end
			end
		end
	end
	return signs, blocked
end
do
	local signs, blocked = blockedSigns(lobby)
	check(signs >= 20 and #blocked == 0, "no lobby part stands in front of a sign's letters (" .. signs .. " signs), got: " .. table.concat(blocked, "; ", 1, math.min(#blocked, 8)))
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
	local shaft = lobby:FindFirstChild("TowerShaft", true)
	local wing = lobby:FindFirstChild("PodiumWing", true)
	check(shaft ~= nil and shaft.CastShadow == true and wing ~= nil and wing.CastShadow == true, "the tower's landmark volumes still cast shadows")
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
		if surface:FindFirstChild("MapPhoto") then
			check(picture.Visible==false and #picture.MapScene:GetChildren()==0,modeId..": a photographed map builds no hidden diorama")
		else
			check(picture.MapScene:FindFirstChild("Road")~=nil,modeId..": picture includes the map route")
		end
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
	root.Position=world.shopZones.base_epic.purchaseCenter
	check(world:NearMarket(visitor,"base") and not world:NearMarket(visitor,"hero"),"base hall authorizes only base summons")
	root.Position=world.lobbySpawn
	check(not world:NearMarket(visitor),"the spawn plaza is not a purchase zone")
	root.Position=world.shopZones.rare.center+world.shopZones.rare.frame.LookVector*-40
	check(not world:NearMarket(visitor),"the approach in front of a hall is not a purchase zone")
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
	root.Position=world.shopZones.base_epic.center
	world:StepShopEntries({visitor})
	check(#panels==start+2 and panels[#panels].data.chestId=="base_epic","walking to the other pad selects base collection")
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
check(#(byKind.Board or {}) == 6, "missions, ranking, maps, team, academy and base desks, got "
	.. tostring(#(byKind.Board or {})))
local boardIds = {}
for _, model in ipairs(byKind.Board or {}) do boardIds[model:GetAttribute("BoardId")] = true end
check(boardIds.quests and boardIds.leaderboard, "both the quest board and the leaderboard totem exist")
for _,id in ipairs({"maps","inventory","talents","bases"}) do
	check(boardIds[id],"functional service desk exists: "..id)
end
for _,id in ipairs({"quests","leaderboard"}) do
	local board=lobby:FindFirstChild("Board_"..id)
	local offset=board.PrimaryPart.Position-WorldBuilder.HQ.hub
	check(v3(offset.X,0,offset.Z).Magnitude<60,"public notice board stands on the hub, facing the plaza: "..id)
	check(board:FindFirstChild("Post")==nil,"central support no longer obscures notice text: "..id)
end
local details=lobby:FindFirstChild("HubServices")
check(details and details:FindFirstChild("GuideHead")==nil and boardIds.guide==nil,"there is no guide character or desk: a new player is taught by arrows")
check(details and countClass(details,"Seat")==3,"hub benches provide usable seats")
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
	check(world:AfkZoneOf(visitorAt(world.lobbySpawn)) == nil, "the spawn plaza is not an AFK farm")
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
	local arena = lobby:FindFirstChild("Scoreboard_arena")
	local arenaArt = arena and arena:FindFirstChild("ArenaArtwork", true)
	check(arenaArt ~= nil and arenaArt.BackgroundColor3.R == 1 and arenaArt.BackgroundColor3.G == 1 and arenaArt.BackgroundColor3.B == 1, "arena gradient uses a neutral base so its blue face never multiplies to black")
	check(arena and arena:FindFirstChild("ArenaTitle", true):IsA("TextLabel"), "arena identity is mounted inside the board rather than floating above it")
	for _, column in ipairs(world.arenaColumns or {}) do
		local head = column.label.Parent:FindFirstChild("MapTitle", true)
		check(head and head:GetAttribute("LobbyTextEN") == Catalog.Upper(Catalog.Maps[column.mapId].name.en), "arena division title follows the viewer's language: " .. column.mapId)
		check(column.label.Position.Y.Offset + column.label.Size.Y.Offset <= column.label.Parent.Size.Y.Offset, "arena records and empty invitation stay inside their division: " .. column.mapId)
		check(column.label.TextScaled and not column.label.TextWrapped, "five arena records keep each full username on its own line: " .. column.mapId)
		if column.mapId == "wakanda" then
			check(column.label:GetAttribute("LobbyTextEN") == "Be the first!" and column.label.Parent.PodiumArtwork.Visible, "empty arena division has a localized invitation and podium artwork")
		elseif column.mapId == "hydra" then
			check(column.label:GetAttribute("LobbyTextEN"):find("Campeão") ~= nil and not column.label.Parent.PodiumArtwork.Visible, "real arena records replace the empty podium without invented scores")
		end
	end
	for _, name in ipairs({ "CampaignTerrace", "ArenaFloor", "AfkFloor", "AcademyPlaza", "ExpeditionPlaza", "LatveriaPlaza", "TowerPlaza", "MarketFloor", "HangarFloor", "CommandFloor", "ArmoryFloor" }) do
		local floor = hq and hq:FindFirstChild(name)
		check(floor ~= nil and floor.CanCollide, "area has its own walkable floor: " .. name)
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
					-- A pass stand sells its pass on a card of its own (owner, 15/10).
				local want = kind == "Board" and model:GetAttribute("BoardId")
					or (kind == "ShopStand" and model:GetAttribute("ShopKind") == "pass" and "offer") or expectedPanel[kind]
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
	local expected = 2 + 5 + 6 + 1
	check(refused == expected, "the distance re-check refused all " .. expected .. " far presses, got " .. tostring(refused))
end

local totalPrompts = countClass(lobby, "ProximityPrompt")
-- A player-width corridor stays free of scenery along every bridge.
do
	local blocked = {}
	for _, bridge in ipairs(hq and hq:GetChildren() or {}) do
		if bridge:GetAttribute("BridgeId") then
			local a = bridge.CFrame * v3(0, 0, bridge.Size.Z / 2)
			local b = bridge.CFrame * v3(0, 0, -bridge.Size.Z / 2)
			local ab = v3(b.X - a.X, 0, b.Z - a.Z)
			for _, piece in ipairs(lobby:GetDescendants()) do
				if piece:IsA("BasePart") and piece.CanCollide and piece.Parent ~= nil and piece.Position.Y > 0.9 and piece.Position.Y < 8
					and not piece:GetAttribute("BridgeId") and piece.Name:sub(1, 5) ~= "Fence" and piece.Name:sub(1, 4) ~= "Gate" and piece.Name ~= "BridgeBeam" then
					local p = piece.Position
					local t = math.clamp(((p.X - a.X) * ab.X + (p.Z - a.Z) * ab.Z) / (ab.X * ab.X + ab.Z * ab.Z), 0, 1)
					local gap = v3(p.X - a.X - ab.X * t, 0, p.Z - a.Z - ab.Z * t).Magnitude
					if gap < 3.5 then table.insert(blocked, piece.Name .. "@" .. tostring(bridge:GetAttribute("BridgeId"))) end
				end
			end
		end
	end
	check(#blocked == 0, "every bridge corridor is clear: " .. table.concat(blocked, ", "))
end
-- Chests, Robux stands, boards and desks, plus the arena scoreboard kiosk.
local expectedPrompts = 2 + 5 + 6 + 1
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
	do
		local _, blocked = blockedSigns(workspace:FindFirstChild("DoomWorld"))
		check(#blocked == 0, mapId .. ": nothing stands in front of a sign's letters, got: " .. table.concat(blocked, "; ", 1, math.min(#blocked, 6)))
	end
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
		local bloom = lighting:FindFirstChild("Bloom")
		check(bloom ~= nil and bloom.Intensity <= 0.2, mapId .. " keeps bloom at or under 0.2 (the owner's no blown-out glow rule), got " .. tostring(bloom and bloom.Intensity))
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
		HubDeck = true, PlazaDeck = true, PlazaBase = true, JumpStone = true, StatueBase = true, AfkPlatform = true, LandingDeck = true,
	}
	local COLUMNS = {
		CoreColumn = true, LampPole = true, Trunk = true, CoolingTower = true, WaterTank = true, Chimney = true,
		Hydrant = true, Bin = true, Barrel = true, FireBarrel = true,
		TreeTrunk = true, BeaconPillar = true, FloodMast = true, FlagPole = true, SignLeg = true, FortressTower = true, AcademyColumn = true,
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
check(lighting.FogEnd == 2600 and lighting.ClockTime == 14.3, "returning to the lobby restores its own fog and mood, not the last chapter's")
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
		print(string.format("  %s: %d parts, %d lights", mapId, parts, lights))
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

-- Heroes blink (owner, 16/10): every hero with drawn eyes can shut them; a
-- blink hides the open eye and drops the lid, opening puts each piece back
-- exactly, and the timing is a short blink every few seconds, out of step
-- between neighbours. Masks and helmets keep their own eyes.
do
	local library = game:GetService("ReplicatedStorage"):FindFirstChild("DoomHeroPortraits")
	local blinkers, missing = 0, {}
	for _, heroId in ipairs(Catalog.HeroOrder) do
		local figure = library and library:FindFirstChild(heroId) and library[heroId]:FindFirstChild("HeroFigure")
		local style = figure and figure:GetAttribute("FaceStyle")
		local drawn = style == "smile" or style == "grin" or style == "fierce" or style == "angry"
		local eyes = figure and Motion.Eyes(figure)
		if eyes then blinkers += 1 elseif drawn then table.insert(missing, heroId) end
	end
	check(#missing == 0 and blinkers >= 20, "every hero with drawn eyes blinks (" .. blinkers .. "), missing: " .. table.concat(missing, ", "))
	local thor = library and library.thor:FindFirstChild("HeroFigure")
	local eyes = thor and Motion.Eyes(thor)
	check(eyes ~= nil and #eyes.open >= 8 and #eyes.lids >= 2, "thor's eyes have whites, irises, pupils, highlights and lids")
	if eyes then
		local lid = eyes.lids[1]
		local restY = lid.weld.C0.Position.Y
		Motion.SetEyes(eyes, true)
		local hidden = true
		for _, piece in ipairs(eyes.open) do hidden = hidden and piece.part.Transparency == 1 end
		check(hidden and lid.weld.C0.Position.Y < restY - 0.04, "a blink hides the open eye and drops the lid")
		Motion.SetEyes(eyes, false)
		local shown = true
		for _, piece in ipairs(eyes.open) do shown = shown and piece.part.Transparency == piece.shown end
		check(shown and math.abs(lid.weld.C0.Position.Y - restY) < 1e-6, "opening the eyes puts every piece back")
	end
	local masked = library and library.ironman:FindFirstChild("HeroFigure")
	check(masked ~= nil and Motion.Eyes(masked) == nil, "a helmet's eyes do not blink")
	local frames, shut, run, longest, together = 60 * 120, 0, 0, 0, 0
	for frame = 0, frames - 1 do
		local t = 1000 + frame / 60
		local a, b = Motion.BlinkClosed(t, 0), Motion.BlinkClosed(t, 1.7)
		if a then shut += 1; run += 1; longest = math.max(longest, run) else run = 0 end
		if a and b then together += 1 end
	end
	check(shut / frames > 0.02 and shut / frames < 0.07, "the eyes are shut 2-7% of the time, got " .. shut / frames)
	check(longest <= 9, "one blink lasts at most 0.15 s, got " .. longest .. " frames")
	check(together < shut * 0.5, "two neighbours do not blink in unison")
	-- At ease, a lobby hero's weight shifts from foot to foot; greeting a
	-- visitor, it raises its right arm and swings the forearm.
	local rig = thor and Motion.Rig(thor)
	if rig and rig.joints and rig.joints.Root then
		Motion.Hero(rig.joints, { breathe = 0, style = "idle", t = 2.8 })
		local roll = rig.joints.Root.Transform.UpVector.X
		check(math.abs(roll) > 0.01, "an idle hero shifts its weight, lean " .. roll)
		local rest = rig.joints.RightShoulder.Transform.UpVector.Y
		Motion.Hero(rig.joints, { breathe = 0, style = "idle", t = 2.95, wave = 1 })
		local raised = rig.joints.RightShoulder.Transform.UpVector.Y
		local swing = rig.joints.RightElbow.Transform.UpVector.X
		check(raised < -0.8 and rest > 0.9, "a waving hero raises its right arm overhead, up " .. raised .. " from " .. rest)
		check(math.abs(swing) > 0.05, "a waving hero swings its forearm, " .. swing)
		Motion.Reset(rig.joints)
	end
end

print("--- towers ---")
local portraits = game:GetService("ReplicatedStorage"):FindFirstChild("DoomHeroPortraits")
check(portraits ~= nil, "portrait library survives separately from the map")
for _, heroId in ipairs(Catalog.HeroOrder) do
	local portrait = portraits and portraits:FindFirstChild(heroId)
	check(portrait and portrait:FindFirstChild("UpperTorso", true) ~= nil, heroId .. " has a portrait torso")
	check(portrait and portrait:FindFirstChild("Head", true) ~= nil, heroId .. " has a portrait head")
	if portrait then
		local rig = portrait:FindFirstChild("HeroFigure")
		local armoured = rig ~= nil and rig:GetAttribute("ArmourFinish") == "chunky"
		for _,side in ipairs({"Left","Right"}) do
			for _,segment in ipairs({"UpperArm","LowerArm","UpperLeg","LowerLeg"}) do
				local limb=portrait:FindFirstChild(side..segment,true)
				local contour=limb and limb:FindFirstChild("BodyContour")
				if armoured and contour then
					-- Armour (owner, 16/10): a segment reaches its shoulder, wrist, hip
					-- or ankle and stops short of its elbow or knee, over a dark joint.
					local half = limb.Size.Y / 2
					-- A file mesh's scale is in mesh units (the chamfered limb block is 2 tall).
					local drawn = contour.MeshType == Enum.MeshType.FileMesh and contour.Scale.Y or contour.Scale.Y * half
					local top, bottom = contour.Offset.Y + drawn, contour.Offset.Y - drawn
					local reach = string.find(segment, "Upper") and top or -bottom
					check(reach >= half - 1e-3, heroId .. ": armour reaches the outer joint: " .. side .. segment)
				else
					check(contour and contour.Scale.Y>=1,heroId..": limb silhouette reaches the joint: "..side..segment)
				end
			end
			if armoured then
				local s = rig:GetAttribute("FigureScale") or 1
				for _, pair in ipairs({ { "UpperArm", "LowerArm", "ElbowJoint" }, { "UpperLeg", "LowerLeg", "KneeJoint" } }) do
					local upper, lower = portrait:FindFirstChild(side .. pair[1], true), portrait:FindFirstChild(side .. pair[2], true)
					local joint
					for _, item in ipairs(rig:GetChildren()) do
						local fit = item.Name == pair[3] and item:FindFirstChild("Fit")
						if fit and fit.Part0 and fit.Part0.Name == side .. pair[1] then joint = item end
					end
					local cu, cl = upper.BodyContour, lower.BodyContour
					local function drawnHalf(contour, limb) return contour.MeshType == Enum.MeshType.FileMesh and contour.Scale.Y or contour.Scale.Y * limb.Size.Y / 2 end
					local gapUpper = cu.Offset.Y - drawnHalf(cu, upper) + upper.Size.Y / 2
					local gapLower = lower.Size.Y / 2 - (cl.Offset.Y + drawnHalf(cl, lower)) + 0.02 * s
					check(joint ~= nil and joint.Size.Y / 2 >= math.max(gapUpper, gapLower), heroId .. ": a dark joint fills the gap at the " .. pair[3] .. ": " .. side)
				end
			end
		end
		if heroId=="ironman" then
			local hosts={}
			for _,item in ipairs(portrait:GetDescendants()) do
				if item.Name=="Bracer" then hosts[item.Fit.Part0.Name]=true end
			end
			check(hosts.LeftLowerArm and hosts.RightLowerArm,"matching armour on different limbs is never deduplicated")
		end
		for _, piece in ipairs(portrait:GetDescendants()) do
			if piece:IsA("BasePart") then check(piece:GetAttribute("HeroVisual") == true, heroId .. " portrait excludes world furniture") end
		end
		-- A jointed body: fifteen segments on Motor6D joints under one root.
		local joints = 0
		for _, item in ipairs(portrait:GetDescendants()) do if item:IsA("Motor6D") then joints += 1 end end
		check(joints >= 15, heroId .. " is a jointed figure, got " .. joints .. " joints")
		local head = portrait:FindFirstChild("Head", true)
		check(head and head:FindFirstChildOfClass("SpecialMesh") ~= nil, heroId .. " has the classic rounded head")
		for _,name in ipairs({"UpperTorso","LowerTorso","LeftHand","RightHand","LeftFoot","RightFoot"}) do
			local piece=portrait:FindFirstChild(name,true)
			check(piece and piece:FindFirstChild("BodyContour"),heroId..": body contour without extra parts: "..name)
		end
		local slopes, thumbs, soles = 0, 0, 0
		for _,piece in ipairs(portrait:GetDescendants()) do
			if piece.Name=="TorsoSlope" then
				slopes+=1
				check(piece:IsA("WedgePart") and piece:FindFirstChild("Fit").Part0.Name=="UpperTorso",heroId..": tapered silhouette follows the chest joint")
			elseif piece.Name=="Thumb" then thumbs+=1
			elseif piece.Name=="BootSole" then soles+=1 end
		end
		-- A sculpted torso (a broad chest over a waist) has no shoulder wedges.
		local sculpted = rig ~= nil and rig:GetAttribute("TorsoFinish") == "sculpted"
		check((sculpted and slopes == 0 and rig:FindFirstChild("Waist") ~= nil or not sculpted and slopes == 2) and thumbs==2 and soles==2,heroId..": finished torso, hands and boots share the portrait rig")
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
		-- A click on the hero itself must land on the tower: an invisible, queryable box as tall as the figure.
		local hitbox = model:FindFirstChild("TowerHitbox")
		if not hitbox or hitbox.CanQuery ~= true or hitbox.Transparency ~= 1 or hitbox:GetAttribute("TowerId") ~= "t" .. heroId or hitbox.Size.Y < 4 then table.insert(missing, heroId .. ":hitbox") end
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

-- A commander starts beside their own base, never inside a base or the core.
do
	for _, spec in ipairs({ { 88, 66 }, { 0, 90 }, { 88, 76 }, { -20, 40 } }) do
		for index = 1, 4 do
			world:UpdateBase(index, { id = "outpost", level = 1 }, v3(spec[1], 0, spec[2]))
		end
		for index = 1, 4 do
			local spot = world:CommanderSpot(index)
			local own = world.Scenery:FindFirstChild("PlayerBase_" .. index).Foundation.Position
			check((v3(spot.X - own.X, 0, spot.Z - own.Z)).Magnitude < 14, "the commander arrives beside their own base: " .. index)
			for other = 1, 4 do
				local foundation = world.Scenery:FindFirstChild("PlayerBase_" .. other).Foundation
				local flat = v3(spot.X - foundation.Position.X, 0, spot.Z - foundation.Position.Z)
				check(math.abs(flat.X) > 4.6 or math.abs(flat.Z) > 4.6, "and not inside a base's foundation: " .. index .. " vs " .. other)
			end
		end
	end
end

for _,id in ipairs(Catalog.BaseOrder) do
	for level=1,5 do
		local position=world:UpdateBase(1,{id=id,level=level},v3(88,0,78))
		local model=world.Scenery:FindFirstChild("PlayerBase_1")
		check(model~=nil and model:FindFirstChild("Building")~=nil,"base model exists: "..id.."/"..level)
		check(math.abs(position.X)<=100 and math.abs(position.Z)<=100,"base respects map bounds")
		local markers=0
		for _,item in ipairs(model:GetChildren()) do
			if item.Name=="LevelLamp" then markers+=1 end
			if item:IsA("BasePart") then
				-- The body of the outpost is solid, and so is the agent beside it (one
				-- invisible block for the person); every piece of dressing is passable.
				local solid = item.Name == "Foundation" or item.Name == "Building" or item.Name == "Roof" or item.Name == "WallSection" or item.Name == "Turret" or item.Name == "AgentTrigger"
				check(item.CanCollide == solid, "only the outpost's body is solid: " .. item.Name)
			end
		end
		check(markers==level,"base upgrade level is visible")
	end
end

-- A configured photograph replaces a portal's rendered diorama; a map without
-- one keeps its diorama. (Last: this rebuilds the lobby.)
do
	WorldBuilder.new(Catalog, function() end, { MapImages = { manhattan = 12 } })
	local board = workspace.DoomLobby.Portal_normal.MapBillboard.MapBoard
	local photo = board:FindFirstChild("MapPhoto")
	check(photo ~= nil and photo.Image == "rbxassetid://12" and board.MapPicture.Visible == false, "a configured photograph covers the rendered diorama")
	check(board.MapPicture.MapScene:FindFirstChild("Road") == nil and board.MapPicture.CurrentCamera ~= nil, "under a photograph the sign keeps its camera and builds no diorama")
	local gamma = workspace.DoomLobby.Portal_normal_gamma.MapBillboard.MapBoard
	check(gamma:FindFirstChild("MapPhoto") == nil and gamma.MapPicture.MapScene:FindFirstChild("Road") ~= nil, "a map without a photograph keeps its diorama")
end

-- A battle server builds the bay and an arrival deck, never the lobby.
do
	local ok, arrival = pcall(WorldBuilder.new, Catalog, function() end, nil, { lobby = false })
	check(ok, "a battle server's world builds: " .. tostring(arrival))
	if ok then
		local deck = workspace:FindFirstChild("DoomArrival")
		local parts = 0
		for _, item in ipairs(deck and deck:GetDescendants() or {}) do if item:IsA("BasePart") then parts += 1 end end
		check(workspace:FindFirstChild("DoomLobby") == nil, "a battle server has no lobby model")
		check(deck ~= nil and deck:FindFirstChild("LobbySpawn") ~= nil and arrival.lobbySpawn ~= nil, "a battle server has a spawn on its arrival deck")
		check(parts > 0 and parts < 200, "the arrival deck is a few dozen parts, not the lobby's thousands: " .. parts)
		check(next(arrival.portalZones) == nil and not arrival:NearMarket(nil), "a battle server has no portal queues or shop")
		local built = pcall(function() arrival:Build("manhattan") end)
		check(built and workspace:FindFirstChild("DoomLobby") == nil, "a map builds next to the arrival deck")
	end
end

print(string.format("%s world boot: %d checks, %d failures",
	failures == 0 and "PASS" or "FAIL", checks, failures))
if failures > 0 then error("world boot failed", 0) end
