-- The Iron armour skin's repulsor, wherever the commander stands (owner, 18/10:
-- "estou com a skin mas não consigo atirar"). In a battle the server decides
-- the shot: a left click aims it (init.client), the FIRE button on a touch
-- screen lets the server pick the nearest enemy. In the lobby there is nothing
-- to hit, so the blast is only a show drawn on this screen: a click aims it, the
-- button fires it ahead of the commander.
local SkinBlaster = {}
SkinBlaster.__index = SkinBlaster

-- ctx: player, input (UserInputService), UI, C, T, gui (overlay), Rules,
-- effects, request(action, payload, quiet), getState(), profile().
function SkinBlaster.new(ctx)
	local self = setmetatable({ ctx = ctx, readyAt = 0, button = nil }, SkinBlaster)
	if ctx.input and ctx.input.InputBegan then
		ctx.input.InputBegan:Connect(function(event, processed) self:_began(event, processed) end)
	end
	return self
end

function SkinBlaster:Active()
	local p = self.ctx.profile()
	return p ~= nil and p.passes ~= nil and p.passes.ironSkin == true and (p.settings or {}).heroSkin ~= false
end

local function inBattle(state)
	return state ~= nil and state.phase ~= "Lobby" and state.match ~= nil
end

-- The repulsor's hand, else the chest.
function SkinBlaster:_muzzle()
	local character = self.ctx.player.Character
	local hand = character and (character:FindFirstChild("SkinRightHand", true) or character:FindFirstChild("RightHand"))
	if hand and hand:IsA("BasePart") then return hand.Position end
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root and root:IsA("BasePart") and root.Position + Vector3.new(0, 1.6, 0) or nil
end

-- aim: a point to fire at, or nil (the battle's nearest enemy; in the lobby,
-- straight ahead of the commander).
function SkinBlaster:Fire(aim)
	if not self:Active() then return false end
	local now = os.clock()
	if now < self.readyAt then return false end
	self.readyAt = now + (self.ctx.Rules.SkinShot and self.ctx.Rules.SkinShot.cooldown or 0.5)
	local state = self.ctx.getState()
	if inBattle(state) then
		local payload = aim and { position = aim } or { auto = true }
		task.spawn(function() self.ctx.request("SkinShot", payload, true) end)
		return true
	end
	local from = self:_muzzle()
	if not from then return false end
	local character = self.ctx.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local ahead = root and root:IsA("BasePart") and root.Position + root.CFrame.LookVector * 34 - Vector3.new(0, 2.5, 0) or from + Vector3.new(0, 0, -34)
	self.ctx.effects:SkinBlast(from, aim or ahead, true)
	return true
end

-- A left click in the lobby fires at the point under the mouse.
function SkinBlaster:_began(event, processed)
	if processed or event.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
	if inBattle(self.ctx.getState()) or not self:Active() then return end
	local camera = workspace.CurrentCamera
	if not camera or not self.ctx.input.GetMouseLocation then return end
	local mouse = self.ctx.input:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { self.ctx.player.Character }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	self:Fire(hit and hit.Position or ray.Origin + ray.Direction * 60)
end

-- The FIRE button on a touch screen, above the run button (both clear of
-- Roblox's jump button in the corner).
function SkinBlaster:Step()
	local ctx = self.ctx
	local wanted = ctx.input.TouchEnabled and self:Active()
	if not wanted then
		if self.button then self.button:Destroy(); self.button = nil end
		return
	end
	if not (self.button and self.button.Parent) then
		self.button = ctx.UI.button(ctx.gui, ctx.T("DISPARAR", "FIRE"), function() self:Fire(nil) end, {
			Name = "SkinFireButton", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -18, 1, -244), Size = UDim2.fromOffset(86, 48),
			TextSize = 14, BackgroundColor3 = Color3.fromRGB(40, 150, 220), ZIndex = 40,
		})
	end
	local ready = os.clock() >= self.readyAt
	self.button.BackgroundTransparency = ready and 0 or 0.45
end

return SkinBlaster
