-- Commander tags above other players: the title they equipped and their level.
--
-- Rendered per viewer rather than on the server, so each person reads the title
-- in their own language.
local Players = game:GetService("Players")
local UI = require(script.Parent:WaitForChild("UI"))

local Nameplates = {}
Nameplates.__index = Nameplates

function Nameplates.new(player, getLanguage)
	local self = setmetatable({}, Nameplates)
	self.player = player
	self.getLanguage = getLanguage or function() return "pt" end
	self.plates = {}
	self.roster = {}
	return self
end

function Nameplates:_text(value)
	if type(value) ~= "table" then return nil end
	local language = self.getLanguage()
	local label = value[language] or value.pt or value.en
	return label ~= "" and label or nil
end

function Nameplates:_destroy(userId)
	local plate = self.plates[userId]
	if not plate then return end
	if plate.gui then plate.gui:Destroy() end
	self.plates[userId] = nil
end

function Nameplates:Update(roster)
	self.roster = {}
	for _, entry in ipairs(roster or {}) do
		if type(entry) == "table" and type(entry.userId) == "number" and entry.userId ~= self.player.UserId then
			self.roster[entry.userId] = entry
		end
	end
	for userId in pairs(self.plates) do
		if not self.roster[userId] then self:_destroy(userId) end
	end
	self:Refresh()
end

function Nameplates:Refresh()
	for userId, entry in pairs(self.roster) do
		local other = Players:GetPlayerByUserId(userId)
		local head = other and other.Character and other.Character:FindFirstChild("Head")
		local title = self:_text(entry.title)
		local level = tonumber(entry.level)
		if not head or (not title and not level) then
			self:_destroy(userId)
		else
			local plate = self.plates[userId]
			-- A respawn hands us a new head, so the old tag is rebuilt rather
			-- than left pointing at a destroyed part.
			if plate and (plate.gui.Parent == nil or plate.head ~= head) then
				self:_destroy(userId)
				plate = nil
			end
			if not plate then
				local gui = Instance.new("BillboardGui")
				gui.Name = "DoomTag"
				gui.Size = UDim2.fromOffset(190, 34)
				gui.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
				gui.AlwaysOnTop = false
				gui.MaxDistance = 130
				gui.Adornee = head
				gui.Parent = head
				local label = UI.label(gui, "", {
					Size = UDim2.fromScale(1, 0.62), TextScaled = false, TextSize = 14,
					Font = Enum.Font.BuilderSansExtraBold, TextColor3 = UI.Colors.gold,
					TextXAlignment = Enum.TextXAlignment.Center, TextStrokeTransparency = 0.5,
				})
				local rank = UI.label(gui, "", {
					Position = UDim2.fromScale(0, 0.6), Size = UDim2.fromScale(1, 0.4), TextSize = 11,
					TextColor3 = UI.Colors.muted, TextXAlignment = Enum.TextXAlignment.Center,
					TextStrokeTransparency = 0.6,
				})
				plate = { gui = gui, label = label, rank = rank, head = head }
				self.plates[userId] = plate
			end
			plate.label.Text = title or ""
			plate.label.Visible = title ~= nil
			-- A VIP's level line is gold and says so: the pass is seen by everyone.
			plate.rank.Text = level and ((entry.vip and "VIP  •  " or "") .. "NV " .. tostring(level)) or ""
			plate.rank.TextColor3 = entry.vip and UI.Colors.gold or UI.Colors.muted
			plate.rank.Visible = level ~= nil
		end
	end
end

function Nameplates:Clear()
	for userId in pairs(self.plates) do self:_destroy(userId) end
	self.roster = {}
end

return Nameplates
