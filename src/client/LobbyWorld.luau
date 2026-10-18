-- The lobby as this viewer sees it: per-player cosmetics on the shared
-- geometry the server built (shrouds over what is still locked, highlights on
-- equipped heroes, each portal's own sign and picture, the mission board's
-- status) and the local motion of its props. Nothing here changes a rule or
-- a server part; split out of init.client to keep that script small.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Motion = require(script.Parent:WaitForChild("Motion"))

local LobbyWorld = {}

function LobbyWorld.new(ctx)
	local Catalog, Rules, UI, C, kit = ctx.Catalog, ctx.Rules, ctx.UI, ctx.C, ctx.kit
	local T, L, contains, profile, player = ctx.T, ctx.L, ctx.contains, ctx.profile, ctx.player
	-- Which physical model in the lobby a panel belongs to, so the panel can
	-- close itself when the player walks away from it. Panels opened from the HUD
	-- (squad, settings) have no anchor and simply stay until dismissed.
	kit.CONTEXT_ANCHOR = {
		chests = {kind="ChestStand",attribute="ChestId",field="chestId"},
		shop = { kind = "ShopStand", attribute = "ShopKey", field = "shopKey" },
		offer = { kind = "ShopStand", attribute = "ShopKey", field = "shopKey" },
		quests = { kind = "Board", attribute = "BoardId", value = "quests" },
		leaderboard = { kind = "Board", attribute = "BoardId", value = "leaderboard" },
	}

	local function anchorPosition(kind, data)
		local spec = kit.CONTEXT_ANCHOR[kind]
		-- The arena's scoreboard kiosk opens the same leaderboard panel.
		if kind == "leaderboard" and data.board == "arena" then spec = { kind = "Scoreboard", attribute = "BoardId", value = "arena" } end
		if not spec then return nil end
		local wanted = spec.value or data[spec.field]
		if not wanted then return nil end
		local lobby = workspace:FindFirstChild("DoomLobby")
		if not lobby then return nil end
		for _, model in ipairs(lobby:GetChildren()) do
			if model:GetAttribute("Kind") == spec.kind and model:GetAttribute(spec.attribute) == wanted then
				local pivot = model.PrimaryPart
				return pivot and pivot.Position or nil
			end
		end
		return nil
	end

	-- Per-viewer cosmetics on the shared lobby geometry: locked portals, unowned
	-- heroes and unlearned skills get a translucent shroud (never a mutation of
	-- the server's own parts), and equipped gear gets a highlight outline.
	kit.shroudColor = Color3.fromRGB(8, 10, 14)
	local function setShroud(model, locked, hint)
		local existing = model:FindFirstChild("LockShroud")
		if locked then
			if existing then return end
			local ok, cf, size = pcall(function()
				if model:GetAttribute("Kind")=="ModePortal" then return model.PrimaryPart.CFrame*CFrame.new(0,12,0),Vector3.new(32,26,13) end
				return model:GetBoundingBox()
			end)
			if not ok then return end
			local shroud = Instance.new("Part")
			shroud.Name, shroud.Anchored = "LockShroud", true
			shroud.CanCollide, shroud.CanTouch, shroud.CanQuery, shroud.CastShadow = false, false, false, false
			-- Lock state is communicated by the sign, not an opaque box over art.
			shroud.Material, shroud.Color, shroud.Transparency = Enum.Material.SmoothPlastic, kit.shroudColor, 1
			shroud.Size, shroud.CFrame = size + Vector3.new(0.4, 0.4, 0.4), cf
			shroud.Parent = model
			-- A portal's own sign already says it is locked and why; a second,
			-- floating line only covered the sign's words.
			if model:GetAttribute("Kind") == "ModePortal" then return end
			local billboard = Instance.new("BillboardGui")
			billboard.Name, billboard.Size = "LockHint", UDim2.fromOffset(220, 50)
			billboard.StudsOffset, billboard.MaxDistance = Vector3.new(0, size.Y / 2 + 2, 0), 36
			billboard.Adornee, billboard.Parent = model.PrimaryPart, model
			UI.label(billboard, T("BLOQUEADO: ", "LOCKED: ") .. (hint or ""), {Size = UDim2.fromScale(1, 1), TextColor3 = C.red, TextSize = 12, Font = Enum.Font.BuilderSansExtraBold, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true})
			return
		end
		if not existing then return end
		existing:Destroy()
		local billboard = model:FindFirstChild("LockHint")
		if billboard then billboard:Destroy() end
		local pivot = model.PrimaryPart
		if not pivot then return end
		local burst = Instance.new("Part")
		burst.Anchored, burst.CanCollide, burst.CanQuery, burst.CanTouch, burst.CastShadow = true, false, false, false, false
		burst.Shape, burst.Material, burst.Color, burst.Transparency = Enum.PartType.Cylinder, Enum.Material.Neon, C.green, 0.2
		burst.Size, burst.CFrame = Vector3.new(0.2, 1, 1), pivot.CFrame * CFrame.Angles(0, 0, math.pi / 2)
		burst.Parent = ctx.effects.folder
		TweenService:Create(burst, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {Size = Vector3.new(0.2, 13, 13), Transparency = 1}):Play()
		task.delay(0.65, function() if burst.Parent then burst:Destroy() end end)
		ctx.audio:Cue("place", 0.05)
	end

	local function setEquippedHighlight(model, on)
		local highlight = model:FindFirstChildOfClass("Highlight")
		if on then
			if highlight then return end
			highlight = Instance.new("Highlight")
			highlight.FillTransparency, highlight.OutlineTransparency, highlight.OutlineColor = 1, 0.2, C.green
			highlight.Parent = model
		elseif highlight then
			highlight:Destroy()
		end
	end

	-- The mission board is shared scenery, but each viewer's client rewrites its
	-- face locally with their own status, so it reads from across the deck
	-- whether there is a reward waiting — the "next goal" the design asks for.
	local function updateQuestBoard(lobby, p)
		local board = lobby:FindFirstChild("Board_quests")
		local panel = board and board:FindFirstChild("Panel")
		local surface = panel and panel:FindFirstChild("Board")
		local label = surface and surface:FindFirstChild("Status")
		if not label then return end
		local active, ready = 0, 0
		for _, quest in pairs(p.quests or {}) do
			if not quest.claimed then
				active += 1
				if (quest.progress or 0) >= (quest.target or 1) then ready += 1 end
			end
		end
		local status
		if ready > 0 then
			status = tostring(ready) .. (ready == 1 and T(" PRONTA PARA RESGATAR", " READY TO CLAIM") or T(" PRONTAS PARA RESGATAR", " READY TO CLAIM"))
		elseif active > 0 then
			status = tostring(active) .. T(" EM ANDAMENTO", " IN PROGRESS")
		else
			status = T("TREINE PARA RECEBER MISSÕES", "TRAIN TO RECEIVE MISSIONS")
		end
		label.Text = status
		label.TextColor3 = ready > 0 and C.gold or Color3.fromRGB(230, 240, 244)
	end

	-- The lobby's props move: the collector drone spins and bobs in its case, the
	-- AFK icons turn, and anything the world tags with Spin/Bob (the globe and its
	-- orbits, the Helicarrier's rotors, the patrolling Quinjet, the prize chests)
	-- or Sway (flags, hinged at the pole) comes alive. Purely local and cheap;
	-- reduced effects leaves them still.
	local lobbyProps = nil
	-- Figures standing as scenery (statues, cameos, the agency's staff) breathe
	-- and glance about: each is rigged once and posed by hand, only while it is
	-- near the camera and at about half the frame rate.
	local idleFigures = {}
	local idleFrame = 0
	local function idleStep(now)
		idleFrame += 1
		local camera = workspace.CurrentCamera
		local eye = camera and camera.CFrame.Position
		-- The heroes notice a visitor: within 18 studs in front of one, its head
		-- turns to them and it waves, once every 14 seconds at most.
		local character = player and player.Character
		local me = character and character:FindFirstChild("HumanoidRootPart")
		local mePosition = me and me:IsA("BasePart") and me.Position
		for index = #idleFigures, 1, -1 do
			local figure = idleFigures[index]
			if not figure.model.Parent then
				table.remove(idleFigures, index)
			elseif (idleFrame + index) % 2 == 0 and (not eye or (figure.rig.root.Position - eye).Magnitude < 150) then
				local t = now + figure.phase
				local joints = figure.rig.joints
				local turn
				if mePosition and not figure.guard then
					local rel = figure.rig.root.CFrame:Inverse() * mePosition
					if Vector3.new(rel.X, 0, rel.Z).Magnitude < 18 and rel.Z < 4 then
						turn = math.clamp(-math.atan2(rel.X, -rel.Z), -0.9, 0.9)
						if not figure.wavedAt or now - figure.wavedAt > 14 then figure.wavedAt = now end
					end
				end
				local waveAge = figure.wavedAt and now - figure.wavedAt or math.huge
				local wave = waveAge < 2.6 and math.clamp(math.min(waveAge / 0.3, (2.6 - waveAge) / 0.4), 0, 1) or 0
				Motion.Hero(joints, { breathe = math.sin(t * 1.7), style = "idle", t = t, wave = wave })
				if figure.eyes == nil then figure.eyes = Motion.Eyes(figure.model) or false end
				if figure.accents == nil then figure.accents = Motion.Accents(figure.model) end
				if figure.accents[1] then Motion.StepAccents(figure.accents, t) end
				if figure.eyes then Motion.SetEyes(figure.eyes, Motion.BlinkClosed(t, figure.phase)) end
				-- Heads turn slowly to one side, hold and come back, or follow the visitor.
				local glance = math.max(0, math.sin(t * 0.31)) ^ 0.5 * math.sin(t * 0.9) * 0.45
				figure.look = (figure.look or 0) + ((turn or glance) - (figure.look or 0)) * 0.15
				if joints.Neck then joints.Neck.Transform = CFrame.Angles(-0.02 * math.sin(t * 1.7), figure.look, 0) end
				if figure.guard and joints.LeftShoulder and joints.RightShoulder then
					-- Hands clasped in front of the belt, as staff stand at a post (held
					-- up at the chest they read as a tray, owner 17/10).
					joints.LeftShoulder.Transform = CFrame.Angles(0.24, 0, 0.34)
					joints.RightShoulder.Transform = CFrame.Angles(0.24, 0, -0.34)
					joints.LeftElbow.Transform = CFrame.Angles(0.82, 0, 0)
					joints.RightElbow.Transform = CFrame.Angles(0.82, 0, 0)
				end
				Motion.Solve(figure.rig)
			elseif figure.eyes and figure.eyes.closed then
				-- Out of range it stops moving: never with its eyes shut.
				Motion.SetEyes(figure.eyes, false)
				Motion.Solve(figure.rig)
			end
		end
	end
	-- Only the place the commander stands in is drawn (owner, 17/10: "mapas
	-- que dão stuterring"): the lobby's 4,300 parts, 80 lights and particles
	-- stood behind every battlefield and were drawn whenever the camera looked
	-- their way. While the commander is on the battlefield (a match phase,
	-- within MAP_REACH of the map's centre: maps stay inside 104 studs, the
	-- lobby begins at 350) the lobby leaves this client's workspace; it is back
	-- the first frame they are anywhere else, before the trip home lands them.
	-- Purely local: the server keeps the lobby and keeps replicating into it.
	local MAP_REACH = 160
	local hiddenLobby = nil
	local function cullLobby(state)
		local character = player and player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local position = root and root:IsA("BasePart") and root.Position
		local onMap = state ~= nil and state.phase ~= "Lobby" and position ~= nil
			and Vector3.new(position.X, 0, position.Z).Magnitude < MAP_REACH
		if onMap and not hiddenLobby then
			local lobby = workspace:FindFirstChild("DoomLobby")
			if lobby then hiddenLobby = lobby; lobby.Parent = nil end
		elseif not onMap and hiddenLobby then
			local lobby = hiddenLobby
			hiddenLobby = nil
			-- A lobby rebuilt meanwhile replaced this one; never bring both.
			if not workspace:FindFirstChild("DoomLobby") then pcall(function() lobby.Parent = workspace end) end
		end
	end
	local function animateLobby(dt)
		local state = ctx.state()
		cullLobby(state)
		if not state or state.phase ~= "Lobby" then return end
		if profile().settings and profile().settings.lowFX then return end
		if not lobbyProps or (lobbyProps[1] and lobbyProps[1].part.Parent == nil) then
			lobbyProps = {}
			local lobby = workspace:FindFirstChild("DoomLobby")
			-- Each prop turns about a pivot: its own axes for a showroom piece, a
			-- vertical axis through SpinCenter (or its own centre) for tagged ones.
			local function add(child, pivot, spin, bob, rate)
				table.insert(lobbyProps, {part = child, pivot = pivot, offset = pivot:Inverse() * child.CFrame, spin = spin, bob = bob, rate = rate or 2, angle = 0})
			end
			local function collect(model, partName, spin, bob)
				for _, child in ipairs(model:GetChildren()) do
					if child.Name == partName and child:IsA("BasePart") then add(child, child.CFrame, spin, bob) end
				end
			end
			for _, model in ipairs(lobby and lobby:GetChildren() or {}) do
				if model.Name == "Shop_collector" then
					collect(model, "Drone", 1.8, 0.25)
					collect(model, "DroneRing", -1.2, 0.25)
				elseif model:GetAttribute("Kind") == "AfkZone" then
					collect(model, "AfkIcon", 1.4, 0)
				end
			end
			idleFigures = {}
			for _, child in ipairs(lobby and lobby:GetDescendants() or {}) do
				if child:IsA("Model") and child:GetAttribute("IdleFigure") then
					local rigged, rig = pcall(Motion.Rig, child)
					if rigged and rig and rig.joints and rig.joints.LeftShoulder then
						table.insert(idleFigures, { model = child, rig = rig, phase = child:GetAttribute("IdlePhase") or 0, guard = child:GetAttribute("IdleGuard") == true })
					end
				end
				-- The vortex's glow and core breathe (Breathe: how much they swell).
				if child:IsA("GuiObject") and child:GetAttribute("Breathe") then
					local host = child.Parent
					while host and not host:IsA("BasePart") do host = host.Parent end
					table.insert(lobbyProps, {part = host or lobby, breathe = child:GetAttribute("Breathe"), gui = child, base = child.Size, spin = 0, angle = 0, phase = #lobbyProps * 0.37})
				end
				-- Portal vortices turn; each one a little differently.
				if child:IsA("SurfaceGui") and child.Name == "PortalSwirl" and child.Parent then
					local swirl = child:FindFirstChild("Swirl")
					if swirl then table.insert(lobbyProps, {part = child.Parent, swirl = swirl, spin = 0, angle = 0, speed = 110 + (child.Parent.Position.X % 7) * 8}) end
					-- The outer arcs turn the other way, slower: the vortex looks deep.
					local outer = child:FindFirstChild("SwirlOuter")
					if outer then table.insert(lobbyProps, {part = child.Parent, swirl = outer, spin = 0, angle = 0, speed = -(60 + (child.Parent.Position.Z % 5) * 6)}) end
				end
				if child:IsA("BasePart") then
					local spin, bob, sway = child:GetAttribute("Spin"), child:GetAttribute("Bob"), child:GetAttribute("Sway")
					local pulse = child:GetAttribute("Pulse")
					if pulse then
						table.insert(lobbyProps, {part = child, pulse = pulse, size = child.Size, spin = 0, angle = 0, phase = child.Position.X * 0.3})
					elseif spin or bob then
						add(child, CFrame.new(child:GetAttribute("SpinCenter") or child.Position), spin or 0, bob or 0, child:GetAttribute("BobRate"))
					elseif sway then
						local hinge = child.CFrame * CFrame.new(-child.Size.X / 2, 0, 0)
						table.insert(lobbyProps, {part = child, pivot = hinge, offset = hinge:Inverse() * child.CFrame, spin = 0, bob = 0, rate = 2, angle = 0,
							sway = sway, phase = child.Position.X * 0.08 + child.Position.Z * 0.05})
					end
				end
			end
		end
		local now = os.clock()
		idleStep(now)
		for _, prop in ipairs(lobbyProps) do
			prop.angle += dt * prop.spin
			if prop.breathe then
				local k = 1 + math.sin(now * 2.4 + prop.phase) * prop.breathe
				prop.gui.Size = UDim2.new(prop.base.X.Scale * k, prop.base.X.Offset, prop.base.Y.Scale * k, prop.base.Y.Offset)
			elseif prop.swirl then
				prop.swirl.Rotation = (prop.swirl.Rotation + dt * prop.speed) % 360
			elseif prop.pulse then
				local k = 1 + math.sin(now * 3 + prop.phase) * prop.pulse * 0.4
				prop.part.Size = Vector3.new(prop.size.X, prop.size.Y * k, prop.size.Z * k)
			elseif prop.sway then
				prop.part.CFrame = prop.pivot * CFrame.Angles(0, math.sin(now * 1.6 + prop.phase) * prop.sway, 0) * prop.offset
			else
				prop.part.CFrame = prop.pivot * CFrame.new(0, math.sin(now * prop.rate) * prop.bob, 0) * CFrame.Angles(0, prop.angle, 0) * prop.offset
			end
		end
	end

	-- Each portal's sign says, for this viewer, what stepping in will start:
	-- which sector (the campaign's next unbeaten one, today's daily), how many
	-- waves, or what is still missing to unlock it.
	local portalBoards={}
	local function portalSign(model)
		local board=portalBoards[model]
		return board and board:FindFirstChild("MapRules",true)
	end

	local function updatePortal(model, p)
		local portalId = model:GetAttribute("PortalId") or model:GetAttribute("ModeId")
		local modeId = Rules.PortalMode(p, portalId)
		local unlocked = Rules.ModeUnlocked(p, modeId)
		setShroud(model, not unlocked, L(kit.modeLockHints[modeId]))
		local sign=model:FindFirstChild("MapBillboard")
		local source=sign and sign:FindFirstChild("MapBoard")
		-- Roblox does not render ViewportFrames under Workspace SurfaceGuis.
		-- Keep the authored template, render its own camera through PlayerGui.
		if source and not portalBoards[model] then
			local board=source:Clone()
			board.Name="PortalPicture_"..portalId
			board.Adornee,board.MaxDistance=sign,190
			board.Parent=player:WaitForChild("PlayerGui")
			portalBoards[model]=board
			source.Enabled=false
			local picture=board:FindFirstChild("MapPicture")
			if picture then
				-- Cameras do not replicate from the server. Construct the view locally.
				local camera=picture:FindFirstChild("PictureCamera") or Instance.new("Camera")
				camera.Name="PictureCamera"
				camera.CFrame=picture:GetAttribute("PictureCFrame") or CFrame.lookAt(Vector3.new(100,120,140),Vector3.new(0,7,0))
				camera.FieldOfView=picture:GetAttribute("PictureFieldOfView") or 40
				camera.Parent=picture
				picture.CurrentCamera=camera
			end
		end
		local board=portalBoards[model]
		if board then
			for _,node in ipairs(board:GetChildren()) do
				if node:IsA("TextLabel") then node.Text=node:GetAttribute(ctx.language()=="en" and "LobbyTextEN" or "LobbyTextPT") or node.Text end
			end
		end
		local label = portalSign(model)
		if label then
			local mapId = Rules.PortalMap(portalId)
			local mode = Catalog.Modes[modeId]
			if not unlocked then
				label.Text = T("BLOQUEADO", "LOCKED") .. " • " .. L(kit.modeLockHints[modeId])
				label.TextColor3 = C.red
			elseif mode then
				local count = Rules.WaveCount(modeId, mapId)
				local waves = count == 0 and T("ONDAS INFINITAS", "ENDLESS WAVES") or (tostring(count) .. T(" ONDAS", " WAVES"))
				label.Text = Catalog.Upper(L(mode.name)) .. " • " .. waves
				label.TextColor3 = kit.modeTint[portalId] or C.green
			end
		end
		-- The tutorial's own arrow (Tutorial.luau) now leads a newcomer to this
		-- portal; a second "START HERE" sign over the same spot hid behind it.
		-- Clear any beacon an older session left.
		local beacon = model:FindFirstChild("StartHere")
		if beacon then beacon:Destroy() end
	end

	local localizedLobby, localizedLanguage, localizedLabels
	local updateWorldCosmetics
	updateWorldCosmetics = function()
		local state, language = ctx.state(), ctx.language()
		-- A lobby snapshot brings the lobby back at once, not a frame later.
		cullLobby(state)
		for model,board in pairs(portalBoards) do
			if not model.Parent then board:Destroy(); portalBoards[model]=nil end
		end
		if not state or state.phase ~= "Lobby" then return end
		local lobby = workspace:FindFirstChild("DoomLobby")
		if not lobby then
			-- The lobby is built server-side at boot, but a slow client can get its
			-- first snapshot before that model replicates. Without this retry the
			-- shrouds would never appear and every portal would look unlocked.
			if not kit.cosmeticsRetryPending then
				kit.cosmeticsRetryPending = true
				task.delay(1, function()
					kit.cosmeticsRetryPending = false
					updateWorldCosmetics()
				end)
			end
			return
		end
		local p = profile()
		if localizedLobby~=lobby then
			localizedLobby,localizedLanguage,localizedLabels=lobby,nil,{}
			for _,obj in ipairs(lobby:GetDescendants()) do
				if obj:GetAttribute("LobbyTextPT") then table.insert(localizedLabels,obj) end
				if obj.Name=="QueueStatus" and obj:IsA("TextLabel") then
					local function localizeQueue()
						local value=obj:GetAttribute(ctx.language()=="en" and "LobbyTextEN" or "LobbyTextPT")
						if value and obj.Text~=value then obj.Text=value end
					end
					obj:GetAttributeChangedSignal("LobbyTextPT"):Connect(localizeQueue)
					obj:GetAttributeChangedSignal("LobbyTextEN"):Connect(localizeQueue)
					obj:GetPropertyChangedSignal("Text"):Connect(localizeQueue)
				end
			end
		end
		-- Queue attributes change on the server while a player is standing still.
		-- Localize them with every lobby snapshot, not only on a language change.
		localizedLanguage=language
		for _,obj in ipairs(localizedLabels) do
				local value=obj:GetAttribute(language=="en" and "LobbyTextEN" or "LobbyTextPT")
				if obj:IsA("TextLabel") then obj.Text=value
				elseif obj:IsA("ProximityPrompt") then obj.ObjectText=value; obj.ActionText=T("Abrir","Open") end
		end
		updateQuestBoard(lobby, p)
		for _, model in ipairs(lobby:GetChildren()) do
			local kind = model:GetAttribute("Kind")
			if kind == "ModePortal" then
				updatePortal(model, p)
			elseif kind == "HeroPedestal" then
				local heroId = model:GetAttribute("HeroId")
				local templates = ReplicatedStorage:FindFirstChild("DoomHeroPortraits")
				UI.rememberHero(heroId, templates and templates:FindFirstChild(heroId) or model)
				local owned = p.heroes and p.heroes[heroId] ~= nil
				setShroud(model, not owned, T("Ainda não comprado", "Not purchased yet"))
				setEquippedHighlight(model, owned and contains(p.loadout, heroId))

			end
		end
	end

	return { update = updateWorldCosmetics, animate = animateLobby, anchorPosition = anchorPosition }
end

return LobbyWorld
