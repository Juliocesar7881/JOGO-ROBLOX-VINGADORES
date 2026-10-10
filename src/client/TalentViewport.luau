-- A movable research board. Coordinates stay in the UI's logical canvas;
-- only input deltas are converted from screen pixels. No progression rules.
local Input = game:GetService("UserInputService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")

local Viewport = {}

function Viewport.new(ctx)
	local UI, holder, map = ctx.UI, ctx.holder, ctx.map
	local saved = ctx.saved
	local zoom = math.clamp(saved.zoom or 1, 0.65, 1.35)
	local pan = Vector2.new(saved.x or 0, saved.y or 0)
	if saved.width and saved.height then
		-- Keep the explored region centered when rotating a phone or resizing
		-- Studio; absolute desktop offsets otherwise push the root off-screen.
		pan += Vector2.new((ctx.width - saved.width) * 0.5, (ctx.height - saved.height) * 0.6)
	end
	if saved.rootX and saved.rootY then
		pan += (Vector2.new(saved.rootX, saved.rootY) - ctx.root) * zoom
	end
	local scale = UI.create("UIScale", {Name = "TalentZoom", Scale = zoom}, map)
	local connections, drag, velocity = {}, nil, Vector2.new(0, 0)
	local function link(signal, callback) table.insert(connections, signal:Connect(callback)) end
	local function constrain(position)
		return Vector2.new(math.clamp(position.X, 64 - ctx.mapW * zoom, ctx.width - 64), math.clamp(position.Y, 64 - ctx.mapH * zoom, ctx.height - 64))
	end
	local function apply()
		pan = constrain(pan)
		map.Position = UDim2.fromOffset(pan.X, pan.Y)
		scale.Scale = zoom
		saved.x, saved.y, saved.zoom = pan.X, pan.Y, zoom
		saved.width, saved.height = ctx.width, ctx.height
		saved.rootX, saved.rootY = ctx.root.X, ctx.root.Y
		holder:SetAttribute("PanX", pan.X); holder:SetAttribute("PanY", pan.Y); holder:SetAttribute("Zoom", zoom)
	end
	local function center()
		velocity = Vector2.new(0, 0)
		pan = Vector2.new(ctx.width * 0.5, ctx.height * 0.6) - ctx.root * zoom
		apply()
	end
	if saved.x == nil and ctx.overview then
		-- Desktop opens on the whole board, including the highest branch.
		-- Later refreshes retain the explored region; Center still finds the root.
		pan=Vector2.new((ctx.width-ctx.mapW*zoom)*0.5,(ctx.height-ctx.mapH*zoom)*0.5)
		apply()
	elseif saved.x == nil then center() else apply() end
	local function pointer(position)
		local inset = GuiService:GetGuiInset()
		return UI.toLogical(Vector2.new(position.X, position.Y) - inset - holder.AbsolutePosition)
	end
	local function inside(position)
		local p = pointer(position)
		return p.X >= 0 and p.Y >= 0 and p.X <= ctx.width and p.Y <= ctx.height
	end
	local function begin(input, source)
		-- Roblox can deliver the same press to the viewport before its child.
		-- Keep the actual node so releasing a pan cannot trigger its purchase.
		if drag then
			if drag.input == input and source then drag.source = source; source:SetAttribute("DragConsumed", drag.moved) end
			return
		end
		if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
		if source then source:SetAttribute("DragConsumed", false) end
		velocity = Vector2.new(0, 0)
		local point = Vector2.new(input.Position.X, input.Position.Y)
		drag = {input = input, origin = point, previous = point, pan = pan, source = source, moved = false}
	end
	link(holder.InputBegan, function(input) begin(input, nil) end)
	link(Input.InputChanged, function(input)
		if not holder.Parent then return end
		if drag and (input == drag.input or (drag.input.UserInputType == Enum.UserInputType.MouseButton1 and input.UserInputType == Enum.UserInputType.MouseMovement)) then
			local point = Vector2.new(input.Position.X, input.Position.Y)
			local delta = UI.toLogical(point - drag.origin)
			if delta.Magnitude >= 8 then drag.moved = true end
			if drag.moved then
				UI.hideTooltip()
				if drag.source then drag.source:SetAttribute("DragConsumed", true) end
				pan = drag.pan + delta
				velocity = UI.toLogical(point - drag.previous) * 25
				apply()
			end
			drag.previous = point
		elseif not drag and input.UserInputType == Enum.UserInputType.MouseWheel and inside(Input:GetMouseLocation()) then
			local nextZoom = math.clamp(zoom + input.Position.Z * 0.1, 0.65, 1.35)
			local anchor = pointer(Input:GetMouseLocation())
			pan = anchor - (anchor - pan) * (nextZoom / zoom)
			zoom = nextZoom
			velocity = Vector2.new(0, 0)
			UI.hideTooltip(); apply()
		end
	end)
	link(Input.InputEnded, function(input)
		if drag and (input == drag.input or (input.UserInputType == Enum.UserInputType.MouseButton1 and drag.input.UserInputType == Enum.UserInputType.MouseButton1)) then
			if not drag.moved or ctx.lowFX then velocity = Vector2.new(0, 0) end
			drag = nil
		end
	end)
	link(RunService.RenderStepped, function(dt)
		if drag or velocity.Magnitude < 2 or ctx.lowFX then return end
		dt = math.min(dt or 1 / 60, 0.05)
		pan += velocity * dt
		velocity *= math.exp(-12 * dt)
		apply()
	end)
	link(holder.Destroying, function()
		for _, connection in ipairs(connections) do connection:Disconnect() end
		drag = nil
	end)
	return {
		Watch = function(_, node) link(node.InputBegan, function(input) begin(input, node) end) end,
		Center = center,
	}
end

return Viewport
