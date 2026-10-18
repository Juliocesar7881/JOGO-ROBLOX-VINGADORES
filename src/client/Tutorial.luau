--!nonstrict
-- The training, taught with arrows. A new commander is led (a big bobbing
-- arrow over the target, a trail of chevrons on the ground, an arrow on the
-- edge of the screen when the target is out of view) to the training portal,
-- and once inside is walked through the first minutes one step at a time:
-- place a hero, call the wave, upgrade a tower, use the leader's power, place
-- a second hero. A card at the top says what to do now.
--
-- Pure presentation. Every step is read off the server's snapshot, nothing
-- here decides a rule, and nothing is stored: leaving and coming back picks
-- the lesson up where the state says it is.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local Tutorial = {}
Tutorial.__index = Tutorial

local CHEVRON_SPACING, CHEVRONS = 10, 9

-- ctx: gui (the overlay frame), UI, C (colours), T (pt/en), Catalog, Rules,
-- Config, effects (its folder and coins), state(), refs(), act(), profile().
function Tutorial.new(ctx)
	local self = setmetatable({ ctx = ctx, clock = 0, chevrons = {}, signature = nil }, Tutorial)
	self.folder = Instance.new("Folder")
	self.folder.Name = "TutorialGuide"
	self.folder.Parent = ctx.effects.folder
	return self
end

--------------------------------------------------------------------------------
-- What to do now
--------------------------------------------------------------------------------
local function distanceXZ(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

-- The next point to walk to along a polyline, from wherever the player is:
-- the end of the segment they are closest to.
function Tutorial.NextWaypoint(position, points)
	local best, bestDistance = 2, math.huge
	for index = 1, #points - 1 do
		local a, b = points[index], points[index + 1]
		local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local length2 = ab.X * ab.X + ab.Z * ab.Z
		local t = length2 > 0 and math.clamp(((position.X - a.X) * ab.X + (position.Z - a.Z) * ab.Z) / length2, 0, 1) or 0
		local closest = Vector3.new(a.X + ab.X * t, 0, a.Z + ab.Z * t)
		local d = distanceXZ(position, closest)
		if d < bestDistance then best, bestDistance = index + 1, d end
	end
	return points[math.min(best, #points)]
end

function Tutorial:_trainingDestination()
	for _, id in ipairs(self.ctx.Catalog.DestinationOrder) do
		local def = self.ctx.Catalog.Destinations[id]
		if def.modeId == "tutorial" then return id, def end
	end
	return nil
end

-- A pad in the lobby by model name: the portal's "Pad", the hall's entry pad.
function Tutorial:_padOf(modelName, padName)
	local lobby = Workspace:FindFirstChild("DoomLobby")
	local model = lobby and lobby:FindFirstChild(modelName)
	local pad = model and (model:FindFirstChild(padName) or model.PrimaryPart)
	return pad and pad.Position or nil
end

-- After the training, two short errands finish the first minutes: open the
-- first chest, then enter the campaign. Only for accounts that really have the
-- stats to say so, and gone for good after the first real match.
function Tutorial:_firstErrands(state, root)
	local ctx = self.ctx
	local T, profile = ctx.T, state.profile
	local stats = profile.stats
	if type(stats) ~= "table" or not root then return nil end
	if state.elevator and (state.elevator.modeId == "normal" or state.elevator.modeId == "quick") then
		return { id = "campaign", number = 2, total = 2, text = T("Boa! A partida começa em instantes.", "Nice! The match starts in a moment.") }
	end
	local cost = ctx.Catalog.Chests.rare.cost
	if (stats.chests or 0)==0 and profile.rewards and profile.rewards.freeChest and profile.rewards.freeChest.ready then
		local navigation=ctx.refs().navigation
		local rewards=navigation and navigation.rewards
		return {id="freeChest",number=1,total=2,gui=rewards and rewards.button,
			text=T("Resgate seu baú grátis em PRÊMIOS","Claim your free chest in REWARDS")}
	end
	if (stats.chests or 0) == 0 and (profile.gold or 0) >= cost and not profile.paidRandomRestricted then
		local target = self:_padOf("Chest_rare", "ShopEntryPad")
		if target then
			return { id = "chest", number = 1, total = 2, world = target, final = target, trail = true,
				text = T("Abra seu primeiro baú de herói na INVOCAÇÃO", "Open your first hero chest at the SUMMON hall") }
		end
	elseif (stats.matches or 0) <= 1 and next(profile.campaign or {}) == nil then
		local target = self:_padOf("Portal_normal", "Pad")
		if target then
			return { id = "campaign", number = 2, total = 2, world = target, final = target, trail = true,
				text = T("Agora enfrente a CAMPANHA: entre no portal", "Now take on the CAMPAIGN: step into the portal") }
		end
	end
	return nil
end

-- The lobby leg: the way from the plaza to the training portal.
function Tutorial:_lobbyStep(state, root)
	local ctx = self.ctx
	local T = ctx.T
	if state.profile.tutorialComplete then return self:_firstErrands(state, root) end
	local id, def = self:_trainingDestination()
	if not def or not root then return nil end
	if state.elevator and state.elevator.modeId == "tutorial" then
		return { id = "board", number = 2, total = 2, text = T("Boa! O treino começa em instantes.", "Nice! Training starts in a moment.") }
	end
	local lobby = Workspace:FindFirstChild("DoomLobby")
	local station = lobby and lobby:FindFirstChild("Portal_" .. id)
	local pad = station and station:FindFirstChild("Pad")
	local target = pad and pad.Position or Vector3.new(def.x, 3, def.z)
	local spawn = lobby and lobby:FindFirstChild("LobbySpawn")
	local origin = spawn and spawn.Position or Vector3.new(0, target.Y, 480)
	local points = { Vector3.new(origin.X, target.Y, origin.Z) }
	for _, via in ipairs(def.via or {}) do table.insert(points, Vector3.new(via.x, target.Y, via.z)) end
	table.insert(points, target)
	local nextPoint = Tutorial.NextWaypoint(root.Position, points)
	return {
		id = "walk", number = 1, total = 2, world = nextPoint, final = target, trail = true,
		text = T("Siga a seta até o portal de TREINO", "Follow the arrow to the TRAINING portal"),
		shortcut = true,
	}
end

-- A spot beside the road where a hero may stand: the first valid one found
-- walking back from the base, either side, twelve studs off the road.
-- Cached for half a second: the search walks the whole road, and a frame has no
-- business doing that sixty times a second.
function Tutorial:_spot(match, taken)
	local cache = self.spotCache
	if cache and cache.key == #taken .. ":" .. tostring(match.mapId) and self.clock - cache.at < 0.5 then return cache.value end
	local value = self:_findSpot(match, taken)
	self.spotCache = { key = #taken .. ":" .. tostring(match.mapId), at = self.clock, value = value }
	return value
end

function Tutorial:_findSpot(match, taken)
	local ctx = self.ctx
	local map = ctx.Catalog.Maps[match.mapId]
	local route = map and map.paths[1]
	if not route then return nil end
	local blockers = match.blockers or {}
	for step = (#route - 1) * 4, 2, -1 do
		local a, b = route[math.max(1, math.floor(step / 4))], route[math.min(#route, math.floor(step / 4) + 1)]
		local ax, az, bx, bz = a[1], a[2], b[1], b[2]
		local length = math.sqrt((bx - ax) ^ 2 + (bz - az) ^ 2)
		if length > 0 then
			local t = (step % 4) / 4
			local px, pz = ax + (bx - ax) * t, az + (bz - az) * t
			local nx, nz = -(bz - az) / length, (bx - ax) / length
			for _, side in ipairs({ 12, -12 }) do
				local position = Vector3.new(px + nx * side, 0, pz + nz * side)
				if ctx.Rules.BuildCheck(match.mapId, position, taken, ctx.Config, blockers) then return position end
			end
		end
	end
	return nil
end

local function clickWord(T)
	return UserInputService.TouchEnabled and T("Toque", "Tap") or T("Clique", "Click")
end

-- The match leg, step by step.
function Tutorial:_matchStep(state)
	local ctx = self.ctx
	local T, refs, match = ctx.T, ctx.refs(), state.match
	local player = ctx.player
	local mine, positions = {}, {}
	for _, tower in ipairs(match.towers or {}) do
		table.insert(positions, tower.position)
		if tower.ownerId == player.UserId then table.insert(mine, tower) end
	end
	local profile = state.profile or {}
	local loadout = profile.loadout or {}
	local total = 5

	if #mine == 0 then
		local hero = loadout[1]
		local card = hero and refs.heroCards and refs.heroCards[hero]
		local picked, pinned = ctx.placement()
		if picked then
			return { id = "place1", number = 1, total = total, text = T(clickWord(T) .. " no ponto marcado, perto da estrada", clickWord(T) .. " the marked spot beside the road"), world = self:_spot(match, positions) }
		end
		return {
			id = "place1", number = 1, total = total,
			text = T("Escolha seu herói na barra embaixo", "Pick your hero on the bar below"),
			gui = card and card.button, world = self:_spot(match, positions),
		}
	end
	if state.phase == "Preparing" and (match.wave or 0) < 1 then
		return {
			id = "ready", number = 2, total = total,
			text = T("Aperte PRONTO para chamar a primeira onda", "Press READY to call the first wave"),
			gui = refs.skip, side = "left",
		}
	end
	local upgradable
	for _, tower in ipairs(mine) do
		if (tower.level or 1) >= 2 then upgradable = nil; break end
		upgradable = tower
	end
	if upgradable then
		local affordable = (match.cash or 0) >= (upgradable.upgradeCost or math.huge)
		return {
			id = "upgrade", number = 3, total = total,
			text = affordable and T("Evolua sua torre: toque no botão verde sobre ela", "Upgrade your tower: tap the green button above it")
				or T("Pegue o Ouro dos inimigos para evoluir sua torre", "Collect the Gold enemies drop to upgrade your tower"),
			world = affordable and upgradable.position or self:_nearestCoin(),
		}
	end
	local ability = match.ability
	if ability and (ability.cooldown or 0) <= 0 and not self.usedAbility then
		local record = refs.abilityButtons and refs.abilityButtons[ability.id]
		return {
			id = "ability", number = 4, total = total,
			-- The Q key only means something with a keyboard. The leader is the first
			-- hero of the team: every hero has a power, the leader's is the one used
			-- (owner, 16/10: the tutorial should say so).
			text = UserInputService.KeyboardEnabled and T("Use o poder do líder (o 1º herói da equipe): o botão grande, tecla Q", "Use your leader's power (your team's 1st hero): the big button, Q key")
				or T("Use o poder do líder (o 1º herói da equipe): toque no botão grande", "Use your leader's power (your team's 1st hero): tap the big button"),
			gui = record and record.button,
		}
	elseif ability and (ability.cooldown or 0) > 0 then
		self.usedAbility = true
	end
	if #mine < 2 and loadout[2] then
		local hero = loadout[2]
		local card = refs.heroCards and refs.heroCards[hero]
		local cost = ctx.Catalog.Heroes[hero] and ctx.Catalog.Heroes[hero].cost or 0
		local affordable = (match.cash or 0) >= cost
		local picked, pinned = ctx.placement()
		return {
			id = "place2", number = 5, total = total,
			text = affordable and (picked and T(clickWord(T) .. " no ponto marcado", clickWord(T) .. " the marked spot") or T("Posicione um segundo herói", "Place a second hero"))
				or T("Junte Ouro para um segundo herói", "Save up Gold for a second hero"),
			gui = affordable and not picked and card and card.button or nil,
			world = affordable and self:_spot(match, positions) or self:_nearestCoin(),
		}
	end
	return {
		id = "survive", number = total, total = total,
		text = T("Sobreviva às ondas! O chefe chega no final", "Survive the waves! The boss comes at the end"),
		quiet = true,
	}
end

function Tutorial:_nearestCoin()
	local effects = self.ctx.effects
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not effects.coins then return nil end
	local best, bestDistance
	for _, coin in pairs(effects.coins) do
		if coin.position then
			local d = distanceXZ(coin.position, root.Position)
			if not bestDistance or d < bestDistance then best, bestDistance = coin.position, d end
		end
	end
	return best
end

-- The current step, or nil when there is nothing to teach.
function Tutorial:Evaluate()
	local ctx = self.ctx
	local state = ctx.state()
	if not state or not state.profile then return nil end
	if state.phase == "Lobby" then
		local character = Players.LocalPlayer.Character
		return self:_lobbyStep(state, character and character:FindFirstChild("HumanoidRootPart"))
	end
	if state.match and state.match.modeId == "tutorial" and (state.phase == "Preparing" or state.phase == "Wave") then
		return self:_matchStep(state)
	end
	return nil
end

--------------------------------------------------------------------------------
-- Drawing
--------------------------------------------------------------------------------
function Tutorial:_clear()
	for _, child in ipairs(self.folder:GetChildren()) do child:Destroy() end
	self.chevrons = {}
	self.anchor, self.ring, self.beam = nil, nil, nil
	if self.card then self.card:Destroy(); self.card = nil end
	if self.pointer then self.pointer:Destroy(); self.pointer = nil end
	if self.edge then self.edge:Destroy(); self.edge = nil end
	self.signature, self.step = nil, nil
end

function Tutorial:_buildCard(step)
	local ctx = self.ctx
	local UI, C, T = ctx.UI, ctx.C, ctx.T
	local inMatch = ctx.state() and ctx.state().phase ~= "Lobby"
	-- The objective, like the big games' quest strip: a gold flag on the left,
	-- the step's dots, the goal in big letters, the skip button on the right.
	local card = UI.roundFrame(ctx.gui, {
		Name = "TutorialCard", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, inMatch and 122 or 10),
		Size = UDim2.new(1, -140, 0, step.shortcut and 84 or 62), BackgroundColor3 = C.background, ZIndex = 49,
	}, C.green)
	UI.windowSkin(card, C.green)
	-- On a phone on its side the card is a narrow strip in the status row, not
	-- a band across the battlefield (owner, 17/10).
	local screen = UI.toLogical(ctx.gui.AbsoluteSize)
	local phone = screen ~= nil and screen.Y > 0 and screen.Y < 520
	UI.create("UISizeConstraint", { MaxSize = Vector2.new(phone and 440 or 600, phone and 84 or 100), MinSize = Vector2.new(260, 46) }, card)
	local flag = UI.frame(card, { Name = "TutorialFlag", Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(40, 40), BackgroundColor3 = C.gold, ZIndex = 50 })
	UI.corner(flag, 20)
	UI.stroke(flag, C.ink, 2.5)
	UI.icon(flag, "star", C.ink, { Position = UDim2.fromOffset(7, 7), Size = UDim2.fromOffset(26, 26), ZIndex = 51 })
	-- Progress dots: where you are in the lesson.
	for index = 1, step.total do
		local dot = UI.frame(card, {
			Name = "TutorialDot_" .. index, Position = UDim2.new(0, 60 + (index - 1) * 18, 0, 9), Size = UDim2.fromOffset(12, 12),
			BackgroundColor3 = index <= step.number and C.green or C.stroke, ZIndex = 50,
		})
		UI.corner(dot, 6)
	end
	-- The goal shrinks to fit a narrow card instead of losing its last words.
	UI.fit(UI.label(card, step.text, {
		Name = "TutorialText", Position = UDim2.fromOffset(60, 24), Size = UDim2.new(1, -72, 0, step.shortcut and 30 or 34), TextSize = 20, Font = UI.Fonts.display,
		TextColor3 = C.cream, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, ZIndex = 50,
	}), 12)
	if step.shortcut then
		UI.button(card, T("Pular a caminhada ▶", "Skip the walk ▶"), function() ctx.act("StartTraining", {}) end, {
			Name = "TutorialShortcut", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -8, 1, -6), Size = UDim2.fromOffset(200, 28), TextSize = 15, BackgroundColor3 = C.blue, ZIndex = 50,
		})
	end
	self.card = card
end

function Tutorial:_ensureWorld(lowFX)
	if self.anchor and self.anchor.Parent then return end
	local C = self.ctx.C
	local anchor = Instance.new("Part")
	anchor.Name, anchor.Size, anchor.Transparency, anchor.Anchored = "TutorialTarget", Vector3.new(1, 1, 1), 1, true
	anchor.CanCollide, anchor.CanTouch, anchor.CanQuery, anchor.CastShadow = false, false, false, false
	anchor.Parent = self.folder
	local gui = Instance.new("BillboardGui")
	gui.Name, gui.Size, gui.AlwaysOnTop, gui.MaxDistance = "TutorialArrow", UDim2.fromOffset(110, 126), true, 2000
	gui.StudsOffsetWorldSpace = Vector3.new(0, 7, 0)
	gui.Adornee, gui.Parent = anchor, anchor
	local arrow = Instance.new("TextLabel")
	arrow.Name, arrow.Size, arrow.BackgroundTransparency, arrow.Text = "Arrow", UDim2.new(1, 0, 0, 92), 1, "▼"
	arrow.Font, arrow.TextScaled, arrow.TextColor3, arrow.TextStrokeTransparency = Enum.Font.FredokaOne, true, C.green, 0
	arrow.TextStrokeColor3 = Color3.fromRGB(10, 40, 20)
	arrow.Parent = gui
	local distance = Instance.new("TextLabel")
	distance.Name, distance.Position, distance.Size, distance.BackgroundTransparency = "Distance", UDim2.fromOffset(0, 90), UDim2.new(1, 0, 0, 28), 1
	distance.Font, distance.TextSize, distance.TextColor3, distance.TextStrokeTransparency = Enum.Font.FredokaOne, 22, C.cream, 0.2
	distance.Text = ""
	distance.Parent = gui
	self.anchor, self.arrowLabel, self.distanceLabel = anchor, arrow, distance
	local ring = Instance.new("Part")
	ring.Name, ring.Shape, ring.Size, ring.Color = "TutorialRing", Enum.PartType.Cylinder, Vector3.new(0.2, 9, 9), C.green
	ring.Material, ring.Transparency, ring.Anchored = Enum.Material.Neon, 0.5, true
	ring.CanCollide, ring.CanTouch, ring.CanQuery, ring.CastShadow = false, false, false, false
	ring.Parent = self.folder
	self.ring = ring
end

function Tutorial:_ensureTrail(root)
	if #self.chevrons > 0 then return end
	for _ = 1, CHEVRONS do
		local chevron = { arms = {} }
		for side = 1, 2 do
			local part = Instance.new("Part")
			part.Name, part.Size, part.Color = "TutorialChevron", Vector3.new(1, 0.2, 4.6), self.ctx.C.green
			part.Material, part.Transparency, part.Anchored = Enum.Material.Neon, 0.25, true
			part.CanCollide, part.CanTouch, part.CanQuery, part.CastShadow = false, false, false, false
			part.Parent = self.folder
			table.insert(chevron.arms, part)
		end
		table.insert(self.chevrons, chevron)
	end
end

-- An arrow on the screen's edge toward a world point that is out of view.
function Tutorial:_edgeArrow(worldPoint)
	local ctx = self.ctx
	local camera = Workspace.CurrentCamera
	if not camera or not camera.WorldToScreenPoint then return end
	local ok, screen, onScreen = pcall(function()
		local point, visible = camera:WorldToScreenPoint(worldPoint)
		return point, visible
	end)
	local size = ctx.UI.toLogical(ctx.gui.AbsoluteSize)
	if ok and typeof(screen) == "Vector3" then
		-- Roblox answers in real pixels; the arrow is placed in logical ones.
		local flat = ctx.UI.toLogical(Vector2.new(screen.X, screen.Y))
		screen = Vector3.new(flat.X, flat.Y, screen.Z)
	end
	if not ok or typeof(screen) ~= "Vector3" or size.X < 50 then
		if self.edge then self.edge.Visible = false end
		return
	end
	if onScreen then
		if self.edge then self.edge.Visible = false end
		return
	end
	if not self.edge then
		local UI, C = ctx.UI, ctx.C
		local frame = UI.frame(ctx.gui, { Name = "TutorialEdge", AnchorPoint = Vector2.new(0.5, 0.5), Size = UDim2.fromOffset(64, 64), BackgroundTransparency = 1, ZIndex = 48 })
		local glyph = UI.label(frame, "▶", { Name = "Glyph", Size = UDim2.fromScale(1, 1), TextSize = 56, Font = UI.Fonts.display, TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 49 })
		glyph.TextStrokeTransparency = 0
		self.edge = frame
	end
	local cx, cy = size.X / 2, size.Y / 2
	local dx, dy = screen.X - cx, screen.Y - cy
	if screen.Z < 0 then dx, dy = -dx, -dy end
	local length = math.sqrt(dx * dx + dy * dy)
	if length < 1 then dx, dy, length = 0, -1, 1 end
	local ux, uy = dx / length, dy / length
	local margin = 54
	local scale = math.min((cx - margin) / math.max(math.abs(ux), 0.001), (cy - margin) / math.max(math.abs(uy), 0.001))
	self.edge.Position = UDim2.fromOffset(cx + ux * scale, cy + uy * scale)
	self.edge.Rotation = math.deg(math.atan2(uy, ux))
	self.edge.Visible = true
end

-- A pointer over a piece of the interface (a hero card, the READY button).
function Tutorial:_guiPointer(target)
	local ctx = self.ctx
	if not target or not target.Parent then
		if self.pointer then self.pointer.Visible = false end
		return
	end
	if not self.pointer then
		local UI, C = ctx.UI, ctx.C
		local label = UI.label(ctx.gui, "▼", { Name = "TutorialPointer", AnchorPoint = Vector2.new(0.5, 1), Size = UDim2.fromOffset(52, 44), TextSize = 40, Font = UI.Fonts.display,
			TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 52 })
		label.TextStrokeTransparency = 0
		self.pointer = label
	end
	local origin = ctx.gui.AbsolutePosition
	local position, size = target.AbsolutePosition, target.AbsoluteSize
	local scale = ctx.UI.screenScale or 1
	local x = ((position and position.X or 0) - (origin and origin.X or 0) + (size and size.X or 0) / 2) / scale
	local y = ((position and position.Y or 0) - (origin and origin.Y or 0)) / scale
	local bob = math.sin(self.clock * 6) * 6
	-- A button stacked in a column (the lobby dock on a wide screen) is pointed
	-- at from its right: from above, the arrow would sit on the button over it.
	local side = self.step and self.step.side
	local holder = target.Parent
	local stack = holder and holder:IsA("GuiObject") and holder.AbsoluteSize
	if not side and stack and stack.Y > stack.X * 1.5 then side = "right" end
	if side == "right" then
		self.pointer.Text = "◀"
		self.pointer.AnchorPoint = Vector2.new(0, 0.5)
		local right = ((position and position.X or 0) - (origin and origin.X or 0) + (size and size.X or 0)) / scale
		self.pointer.Position = UDim2.fromOffset(right + 6 - bob, y + (size and size.Y or 0) / 2 / scale)
	elseif side == "left" then
		-- A wide button (READY) is pointed at from its left side, so the pointer
		-- never covers the text above it.
		self.pointer.Text = "▶"
		self.pointer.AnchorPoint = Vector2.new(1, 0.5)
		local left = (position and position.X or 0) - (origin and origin.X or 0)
		self.pointer.Position = UDim2.fromOffset(left - 6 + bob, y + (size and size.Y or 0) / 2)
	else
		self.pointer.Text = "▼"
		self.pointer.AnchorPoint = Vector2.new(0.5, 1)
		self.pointer.Position = UDim2.fromOffset(x, y - 4 + bob)
	end
	self.pointer.Visible = target.Visible ~= false
end

function Tutorial:Step(dt)
	self.clock += dt
	local step = self:Evaluate()
	if not step then
		if self.card or self.anchor then self:_clear() end
		return
	end
	local signature = step.id .. ":" .. tostring(step.number)
	if signature ~= self.signature then
		self:_clear()
		self.signature, self.step = signature, step
		self:_buildCard(step)
	end
	self.step = step
	local lowFX = self.ctx.profile().settings and self.ctx.profile().settings.lowFX
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")

	-- The text can change inside a step (not enough Gold yet, then enough).
	local label = self.card and self.card:FindFirstChild("TutorialText")
	if label and label.Text ~= step.text then label.Text = step.text end

	-- The first time the way to the portal is shown, the camera swings to look
	-- along it: the plaza spawns everyone facing the other way.
	if step.trail and step.world and root and self.orientedFor ~= step.id then
		self.orientedFor = step.id
		local camera = Workspace.CurrentCamera
		if camera and camera.CameraType == Enum.CameraType.Custom then
			local line = Vector3.new(step.world.X - root.Position.X, 0, step.world.Z - root.Position.Z)
			if line.Magnitude > 1 then
				local direction = line.Unit
				local focus = root.Position + Vector3.new(0, 2, 0)
				camera.CFrame = CFrame.lookAt(focus - direction * 23 + Vector3.new(0, 6, 0), focus)
			end
		end
	end

	if step.gui then self:_guiPointer(step.gui) elseif self.pointer then self.pointer.Visible = false end
	-- The card never covers what it points at: when the target (READY, a hero
	-- tile) sits where the card does, the card steps down just below it.
	if self.card then
		local inMatch = self.ctx.state() and self.ctx.state().phase ~= "Lobby"
		-- In the lobby on a short phone the gold pill and the options button share the
		-- top row with the card, so it drops one row lower there.
		local screen = self.ctx.UI.toLogical(self.ctx.gui.AbsoluteSize)
		-- On a phone held upright the gold pill and the corner buttons share the
		-- top row with the card: it goes below them there.
		local narrow = screen and screen.X < 560
		-- In a match on a phone on its side it rides the status row (top bar 46 + gaps).
		local phoneMatch = inMatch and screen ~= nil and screen.Y < 520 and not narrow
		local cardY = phoneMatch and 60 or (inMatch and 122 or (narrow and 104 or ((screen and screen.Y < 500) and 62 or 10)))
		local target = step.gui
		local origin, position, size = self.ctx.gui.AbsolutePosition, target and target.AbsolutePosition, target and target.AbsoluteSize
		local scale = self.ctx.UI.screenScale or 1
		local cardHeight = self.card.AbsoluteSize and self.card.AbsoluteSize.Y / scale or 52
		if origin and position and size and target.Visible ~= false then
			local top, height = (position.Y - origin.Y) / scale, size.Y / scale
			if top < cardY + cardHeight + 6 and top + height > cardY - 6 then cardY = top + height + 10 end
		end
		self.card.Position = UDim2.new(0.5, 0, 0, cardY)
		-- On a short phone screen an open panel fills the area the card uses;
		-- the walk resumes when it closes.
		local panelOpen = self.ctx.panelOpen and self.ctx.panelOpen()
		local covered = self.ctx.fullScreen and self.ctx.fullScreen()
		self.card.Visible = not ((panelOpen and not inMatch and screen and (screen.Y < 500 or screen.X < 560)) or covered)
	end

	local world = step.world
	if not world then
		if self.anchor then self.anchor.Parent = nil; self.ring.Parent = nil end
		if self.edge then self.edge.Visible = false end
		for _, chevron in ipairs(self.chevrons) do
			for _, arm in ipairs(chevron.arms) do arm.Transparency = 1 end
		end
		return
	end
	self:_ensureWorld(lowFX)
	if not self.anchor.Parent then self.anchor.Parent = self.folder; self.ring.Parent = self.folder end
	-- The marks lie on the floor the player last stood on, so jumping never
	-- lifts the ring or the chevrons off the ground.
	if root then
		local humanoid = root.Parent and root.Parent:FindFirstChildOfClass("Humanoid")
		local standing = not humanoid or humanoid.FloorMaterial ~= Enum.Material.Air
		if standing or not self.floorY then
			local hip = humanoid and tonumber(humanoid.HipHeight)
			self.floorY = root.Position.Y - (hip and (hip + root.Size.Y / 2) or 2.6)
		end
	end
	local ground = Vector3.new(world.X, self.floorY or 1.5, world.Z)
	self.anchor.CFrame = CFrame.new(world)
	local bob = math.sin(self.clock * 5) * 1.2
	self.anchor:FindFirstChildOfClass("BillboardGui").StudsOffsetWorldSpace = Vector3.new(0, 7 + bob, 0)
	self.ring.CFrame = CFrame.new(ground + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	local pulse = 1 + math.sin(self.clock * 4) * 0.12
	self.ring.Size = Vector3.new(0.2, 9 * pulse, 9 * pulse)
	if root then
		local meters = math.floor(distanceXZ(root.Position, step.final or world) / 3.5)
		self.distanceLabel.Text = meters > 6 and (tostring(meters) .. " m") or ""
	end
	self:_edgeArrow(world + Vector3.new(0, 4, 0))

	-- Walking leg: a trail of chevrons from the player toward the point.
	if step.trail and root and not lowFX then
		self:_ensureTrail(root)
		local from = Vector3.new(root.Position.X, ground.Y, root.Position.Z)
		local line = Vector3.new(world.X - from.X, 0, world.Z - from.Z)
		local length = line.Magnitude
		local unit = length > 0 and line.Unit or Vector3.new(0, 0, -1)
		local offset = (self.clock * 6) % CHEVRON_SPACING
		for index, chevron in ipairs(self.chevrons) do
			local along = (index - 1) * CHEVRON_SPACING + offset + 5
			local visible = along < length - 4
			local fade = 0.2 + 0.6 * (index - 1) / #self.chevrons
			for side, arm in ipairs(chevron.arms) do
				arm.Transparency = visible and fade or 1
				if visible then
					-- A ">" lying on the ground, its point toward the target: two bars
					-- leaning back from the tip.
					local tip = from + unit * along
					arm.CFrame = CFrame.lookAt(tip, tip + unit) * CFrame.Angles(0, (side == 1 and 1 or -1) * math.rad(40), 0) * CFrame.new(0, 0, 2.1)
				end
			end
		end
	end
end

function Tutorial:Destroy()
	self:_clear()
	self.folder:Destroy()
end

function Tutorial:Current()
	return self.step
end

return Tutorial
