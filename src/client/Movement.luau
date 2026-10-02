--!nonstrict
-- How the commander moves, in the lobby and in matches alike: hold Shift (or
-- press the run button on a phone, or click the left stick) to run, and jump
-- again in the air for a double jump. Both are feel, not rules: the numbers
-- live in Catalog.Movement and the server bounds them (it resets a speed or a
-- jump above the ceiling), so nothing here can buy an advantage.
local Movement = {}
Movement.__index = Movement

local RING_LIFETIME = 0.4

-- ctx: player, input (UserInputService), actions (ContextActionService, when
-- there is one), gui (an overlay frame), UI, C, T, config (Catalog.Movement),
-- lowFX() -> boolean, folder (where rings go).
--
-- Running is bound as a context action: Roblox itself draws its button beside
-- the jump button on a phone (where thumbs expect it, clear of our own HUD),
-- and the same action carries Shift and the controller's left stick click.
function Movement.new(ctx)
	local self = setmetatable({
		ctx = ctx, running = false, toggled = false, doubleUsed = false, lastJump = -10,
		rings = {}, dust = 0, clock = 0, phoneButton = nil,
	}, Movement)
	local input = ctx.input
	if input.JumpRequest then input.JumpRequest:Connect(function() self:_jumpRequest() end) end
	if ctx.actions then
		local bound = pcall(function()
			ctx.actions:BindAction("DoomRun", function(_, state, event) return self:_action(state, event) end, true, Enum.KeyCode.LeftShift, Enum.KeyCode.ButtonL3)
			ctx.actions:SetTitle("DoomRun", ctx.T("CORRER", "RUN"))
		end)
		self.bound = bound
	end
	-- Without it (a stand-in, or an engine without the service) the keys are read directly.
	if not self.bound then
		if input.InputBegan then input.InputBegan:Connect(function(event, processed) self:_began(event, processed) end) end
		if input.InputEnded then input.InputEnded:Connect(function(event) self:_ended(event) end) end
	end
	return self
end

-- The context action: a tap on the phone's button or a click of the left stick
-- toggles running; Shift runs while it is held. Never sinks the input.
function Movement:_action(state, event)
	local touch = event and event.UserInputType == Enum.UserInputType.Touch
	if state == Enum.UserInputState.Begin then
		if touch or (event and event.KeyCode == Enum.KeyCode.ButtonL3) then self.toggled = not self.toggled
		else self.held = true end
	elseif state == Enum.UserInputState.End or state == Enum.UserInputState.Cancel then
		if not touch and not (event and event.KeyCode == Enum.KeyCode.ButtonL3) then self.held = false end
	end
	return Enum.ContextActionResult.Pass
end

local function humanoidOf(player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return humanoid, root
end

function Movement:_began(event, processed)
	if processed or self.ctx.input:GetFocusedTextBox() then return end
	if event.KeyCode == Enum.KeyCode.LeftShift or event.KeyCode == Enum.KeyCode.RightShift then
		self.held = true
	elseif event.KeyCode == Enum.KeyCode.ButtonL3 then
		self.toggled = not self.toggled
	end
end

function Movement:_ended(event)
	if event.KeyCode == Enum.KeyCode.LeftShift or event.KeyCode == Enum.KeyCode.RightShift then
		self.held = false
	end
end

-- Running is wanted while Shift is held or the toggle is on.
function Movement:Wanted()
	return self.held == true or self.toggled == true
end

function Movement:SetToggled(on)
	self.toggled = on == true
end

-- A second jump in the air: the same push as the first, once per landing.
function Movement:_jumpRequest()
	local humanoid, root = humanoidOf(self.ctx.player)
	if not humanoid or not root or humanoid.Health <= 0 then return end
	local config = self.ctx.config
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local now = os.clock()
	if grounded then
		self.lastJump, self.doubleUsed = now, false
		return
	end
	if self.doubleUsed or now - self.lastJump < 0.18 then return end
	if humanoid.Sit then return end
	self.doubleUsed, self.lastJump = true, now
	local velocity = root.AssemblyLinearVelocity
	root.AssemblyLinearVelocity = Vector3.new(velocity.X, config.jumpPower, velocity.Z)
	pcall(function() humanoid:ChangeState(Enum.HumanoidStateType.Jumping) end)
	self:_ring(root.Position - Vector3.new(0, 2.6, 0))
	self.jumps = (self.jumps or 0) + 1
end

-- A ring of light that opens under the feet where the second jump pushed off.
function Movement:_ring(position)
	if self.ctx.lowFX and self.ctx.lowFX() then return end
	local folder = self.ctx.folder
	if not folder then return end
	local ring = Instance.new("Part")
	ring.Name, ring.Shape, ring.Size = "JumpRing", Enum.PartType.Cylinder, Vector3.new(0.15, 3, 3)
	ring.Color, ring.Material, ring.Transparency = self.ctx.C.cream, Enum.Material.Neon, 0.35
	ring.Anchored, ring.CanCollide, ring.CanTouch, ring.CanQuery, ring.CastShadow = true, false, false, false, false
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	ring.Parent = folder
	table.insert(self.rings, { part = ring, born = self.clock })
end

-- The run button on touch screens, above the thumb's jump button.
function Movement:_ensurePhoneButton()
	local ctx = self.ctx
	if self.bound or not ctx.input.TouchEnabled then
		if self.phoneButton then self.phoneButton:Destroy() self.phoneButton = nil end
		return
	end
	if self.phoneButton and self.phoneButton.Parent then return end
	local UI, C, T = ctx.UI, ctx.C, ctx.T
	local button = UI.button(ctx.gui, T("CORRER", "RUN"), function() self:SetToggled(not self.toggled) end, {
		Name = "RunButton", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -190), Size = UDim2.fromOffset(86, 44),
		TextSize = 14, BackgroundColor3 = C.card, ZIndex = 40,
	})
	self.phoneButton = button
end

function Movement:Step(dt)
	self.clock += dt
	local ctx = self.ctx
	local config = ctx.config
	local humanoid, root = humanoidOf(ctx.player)
	self:_ensurePhoneButton()
	if humanoid then
		-- Only the walk and run speeds are ours to set: a power that slows or
		-- boosts the commander in some future mode is left alone.
		local want = self:Wanted() and config.sprint or config.walk
		local current = humanoid.WalkSpeed
		if current == config.walk or current == config.sprint then
			if current ~= want then humanoid.WalkSpeed = want end
		end
		if humanoid.FloorMaterial ~= Enum.Material.Air then self.doubleUsed = false end
		self.running = humanoid.WalkSpeed == config.sprint and humanoid.MoveDirection.Magnitude > 0.1 and humanoid.FloorMaterial ~= Enum.Material.Air
		local title = self.toggled and ctx.T("PARAR", "STOP") or ctx.T("CORRER", "RUN")
		if self.phoneButton then
			self.phoneButton.Text = title
			self.phoneButton.BackgroundColor3 = self.toggled and ctx.C.green or ctx.C.card
		end
		if self.bound and self.title ~= title then
			self.title = title
			pcall(function() ctx.actions:SetTitle("DoomRun", title) end)
		end
		-- Dust kicked up at the heels while running, a few puffs a second.
		if self.running and root and not (ctx.lowFX and ctx.lowFX()) and ctx.folder then
			self.dust += dt
			if self.dust >= 0.12 then
				self.dust = 0
				local puff = Instance.new("Part")
				puff.Name, puff.Shape, puff.Size = "RunDust", Enum.PartType.Ball, Vector3.new(0.9, 0.9, 0.9)
				puff.Color, puff.Material, puff.Transparency = Color3.fromRGB(226, 226, 232), Enum.Material.SmoothPlastic, 0.55
				puff.Anchored, puff.CanCollide, puff.CanTouch, puff.CanQuery, puff.CastShadow = true, false, false, false, false
				puff.CFrame = CFrame.new(root.Position - Vector3.new(0, 2.7, 0))
				puff.Parent = ctx.folder
				table.insert(self.rings, { part = puff, born = self.clock, dust = true })
			end
		end
	end
	for index = #self.rings, 1, -1 do
		local entry = self.rings[index]
		local life = (self.clock - entry.born) / (entry.dust and 0.35 or RING_LIFETIME)
		if life >= 1 or not entry.part.Parent then
			entry.part:Destroy()
			table.remove(self.rings, index)
		elseif entry.dust then
			entry.part.Size = Vector3.new(0.9, 0.9, 0.9) * (1 + life * 1.6)
			entry.part.Transparency = 0.55 + life * 0.45
		else
			local grow = 3 + life * 7
			entry.part.Size = Vector3.new(0.15, grow, grow)
			entry.part.Transparency = 0.35 + life * 0.65
		end
	end
end

function Movement:Destroy()
	if self.bound then pcall(function() self.ctx.actions:UnbindAction("DoomRun") end) end
	for _, entry in ipairs(self.rings) do entry.part:Destroy() end
	self.rings = {}
	if self.phoneButton then self.phoneButton:Destroy() end
end

return Movement
