--!nonstrict
-- Cosmetics that other people are supposed to see. The VIP trail is built on
-- the server so every client renders it, unlike the collector drone, which is a
-- local effect for its owner. Titles travel inside the roster so each viewer
-- reads them in their own language.
local Players = game:GetService("Players")

local Presence = {}
Presence.__index = Presence

local TRAIL_START = Color3.fromRGB(255, 214, 112)
local TRAIL_END = Color3.fromRGB(111, 247, 167)

function Presence.new()
	return setmetatable({ records = {} }, Presence)
end

function Presence:Bind(player)
	if self.records[player.UserId] then return end
	self.records[player.UserId] = { vip = false }
	player.CharacterAdded:Connect(function(character)
		task.defer(function()
			if player.Parent == Players then self:_apply(player, character) end
		end)
	end)
	if player.Character then self:_schedule(player) end
end

-- _apply waits for the character to stream in, so it is never called on a
-- thread that a client is waiting on.
function Presence:_schedule(player)
	task.spawn(function()
		local character = player.Character
		if character and player.Parent == Players then self:_apply(player, character) end
	end)
end

function Presence:Release(player)
	self.records[player.UserId] = nil
end

function Presence:Update(player, vip)
	local record = self.records[player.UserId]
	if not record then return end
	vip = vip == true
	if record.vip == vip then return end
	record.vip = vip
	self:_schedule(player)
end

function Presence:_apply(player, character)
	local record = self.records[player.UserId]
	if not record or character.Parent == nil then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		root = character:WaitForChild("HumanoidRootPart", 6)
		if not root or character.Parent == nil then return end
	end
	local existing = root:FindFirstChild("VipTrail")
	if not record.vip then
		if existing then existing:Destroy() end
		for _, name in ipairs({ "VipTrailTop", "VipTrailBottom" }) do
			local attachment = root:FindFirstChild(name)
			if attachment then attachment:Destroy() end
		end
		return
	end
	if existing then return end
	local top = Instance.new("Attachment")
	top.Name, top.Position, top.Parent = "VipTrailTop", Vector3.new(0, 1.2, 0.4), root
	local bottom = Instance.new("Attachment")
	bottom.Name, bottom.Position, bottom.Parent = "VipTrailBottom", Vector3.new(0, -1.2, 0.4), root
	local trail = Instance.new("Trail")
	trail.Name = "VipTrail"
	trail.Attachment0, trail.Attachment1 = top, bottom
	trail.Color = ColorSequence.new(TRAIL_START, TRAIL_END)
	trail.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	trail.Lifetime, trail.MinLength, trail.WidthScale = 0.55, 0.2, NumberSequence.new(1, 0.1)
	trail.LightEmission, trail.FaceCamera = 0.55, true
	trail.Parent = root
end

return Presence
