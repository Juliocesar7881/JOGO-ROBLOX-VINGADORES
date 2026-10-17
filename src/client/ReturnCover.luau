-- Back to the lobby (owner, 17/10: "quando eu terminei a partida e cliquei em
-- voltar pro lobby eu voltei pra um lugar nada a ver ali enquanto carregava"):
-- the launch cover hides the trip, from the tap until the commander stands in
-- the lobby and the lobby had a moment to draw around them, and never longer
-- than MAX_SECONDS. Purely presentation: the server moves the commander.
local RunService = game:GetService("RunService")

local ReturnCover = {}
ReturnCover.__index = ReturnCover

local MAX_SECONDS, SETTLE_SECONDS = 8, 1.2
-- Maps are built around the origin (inside ±104 studs); the lobby stands far off.
local LOBBY_DISTANCE = 160

-- ctx: art (the ScreenArt module), T (pt, en), getState, player.
function ReturnCover.new(ctx)
	return setmetatable({ ctx = ctx }, ReturnCover)
end

function ReturnCover:Shown()
	return self.gui ~= nil and self.gui.Parent ~= nil
end

function ReturnCover:Show()
	if self:Shown() then return end
	local ctx = self.ctx
	local playerGui = ctx.player and ctx.player:FindFirstChildOfClass("PlayerGui")
	if not playerGui then return end
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = "DoomReturnCover", true, false, 990
	local canvas = Instance.new("Frame")
	canvas.Name, canvas.BackgroundTransparency, canvas.Size = "Canvas", 1, UDim2.fromScale(1, 1)
	canvas.Parent = gui
	-- The same logical canvas as the launch cover (src/first/init.client).
	local camera = workspace.CurrentCamera
	local size = camera and camera.ViewportSize or Vector2.new(1280, 720)
	if size.X <= 0 or size.Y <= 0 then size = Vector2.new(1280, 720) end
	local amount = math.clamp(math.min(size.X / 1150, size.Y / 640), 1, 4)
	local scale = Instance.new("UIScale")
	scale.Scale, scale.Parent = amount, canvas
	canvas.Size = UDim2.fromScale(1 / amount, 1 / amount)
	local ok, view = pcall(ctx.art.Loading, canvas, ctx.T, Vector2.new(size.X / amount, size.Y / amount))
	if not ok then gui:Destroy(); return end
	gui.Parent = playerGui
	self.gui, self.view, self.started, self.arrived = gui, view, os.clock(), nil
	if self.connection then self.connection:Disconnect() end
	self.connection = RunService.RenderStepped:Connect(function() self:_step() end)
end

function ReturnCover:Hide()
	if self.connection then self.connection:Disconnect(); self.connection = nil end
	if self.gui then self.gui:Destroy(); self.gui = nil end
	self.view = nil
end

-- Home is the lobby phase with the commander far from the battlefield; the
-- cover then waits SETTLE_SECONDS for the lobby to draw around them.
function ReturnCover:_step()
	if not self:Shown() then self:Hide(); return end
	local now = os.clock()
	local elapsed = now - (self.started or now)
	local state = self.ctx.getState()
	local character = self.ctx.player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local home = state ~= nil and state.phase == "Lobby" and root ~= nil
		and Vector3.new(root.Position.X, 0, root.Position.Z).Magnitude > LOBBY_DISTANCE
	if home and not self.arrived then self.arrived = now end
	if self.view and self.view.Step then pcall(self.view.Step, elapsed, self.arrived ~= nil, false, false) end
	if (self.arrived and now - self.arrived >= SETTLE_SECONDS) or elapsed >= MAX_SECONDS then self:Hide() end
end

return ReturnCover
