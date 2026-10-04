--!nonstrict
-- The first thing a player sees. This script lives in ReplicatedFirst, so it
-- runs before the world has finished arriving: it takes the place of Roblox's
-- plain loading screen with the game's own (name, a moving bar, a tip), and
-- keeps it up until the game's interface has its first state from the server.
-- A joining player on a cold server used to stare at a black screen while the
-- lobby streamed in; now there is always something to read and a bar that moves.
-- It never decides anything: it only covers the screen, and it always leaves
-- (the interface says it is ready, or 60 seconds pass).
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LocalizationService = game:GetService("LocalizationService")

pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)

local player = Players.LocalPlayer
local portuguese = true
pcall(function() portuguese = string.sub(string.lower(LocalizationService.RobloxLocaleId), 1, 2) == "pt" end)
local function T(pt, en) return portuguese and pt or en end

local NAVY, VIOLET, GOLD, GREEN, CREAM = Color3.fromRGB(24, 32, 72), Color3.fromRGB(110, 70, 200), Color3.fromRGB(255, 210, 63), Color3.fromRGB(88, 224, 79), Color3.fromRGB(255, 241, 204)

local gui = Instance.new("ScreenGui")
gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = "DoomLoader", true, false, 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local cover = Instance.new("Frame")
cover.Name, cover.Size, cover.BackgroundColor3, cover.BorderSizePixel = "Cover", UDim2.fromScale(1, 1), NAVY, 0
cover.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color, gradient.Rotation = ColorSequence.new(NAVY:Lerp(VIOLET, 0.55), NAVY), 90
gradient.Parent = cover

local function label(text, y, height, size, color)
	local made = Instance.new("TextLabel")
	made.BackgroundTransparency, made.Text, made.Font, made.TextSize = 1, text, Enum.Font.GothamBlack, size
	made.TextColor3, made.TextXAlignment = color, Enum.TextXAlignment.Center
	made.AnchorPoint, made.Position, made.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0.5, y), UDim2.new(1, -40, 0, height)
	made.TextWrapped = true
	local outline = Instance.new("UIStroke")
	outline.Color, outline.Thickness = Color3.fromRGB(11, 15, 36), size >= 40 and 4 or 2
	outline.Parent = made
	made.Parent = cover
	return made
end
label(T("MULTIVERSO", "MULTIVERSE"), -150, 36, 28, GOLD)
label("DOOMSDAY", -112, 84, 74, CREAM)
label(T("ÚLTIMA DEFESA", "LAST DEFENSE"), -28, 34, 26, GOLD)

local track = Instance.new("Frame")
track.Name, track.AnchorPoint, track.Position, track.Size = "Track", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0.5, 30), UDim2.fromOffset(320, 14)
track.BackgroundColor3, track.BorderSizePixel, track.ClipsDescendants = Color3.fromRGB(11, 15, 36), 0, true
track.Parent = cover
local round = Instance.new("UICorner")
round.CornerRadius = UDim.new(0, 7)
round.Parent = track
local slider = Instance.new("Frame")
slider.Name, slider.Size, slider.Position, slider.BackgroundColor3, slider.BorderSizePixel = "Bar", UDim2.fromScale(0.4, 1), UDim2.fromScale(-0.4, 0), GREEN, 0
slider.Parent = track
local sliderRound = Instance.new("UICorner")
sliderRound.CornerRadius = UDim.new(0, 7)
sliderRound.Parent = slider

local status = label(T("Preparando o refúgio…", "Preparing the refuge…"), 56, 28, 18, CREAM)
status.Font = Enum.Font.GothamBold
local TIPS = {
	{ "Toque no chão para posicionar um herói: sem confirmação.", "Tap the ground to place a hero: no confirmation." },
	{ "Repetidos dos baús viram cartas para evoluir seus heróis sem limite.", "Duplicates from chests become cards that level your heroes with no cap." },
	{ "Em grupo, os inimigos têm mais vida — mas vocês também têm mais torres.", "In a group the enemies are tougher — but so is your defence." },
	{ "O Agente da Base, ao lado da sua base, evolui a base com a tecla E.", "The Base Agent beside your base upgrades it with the E key." },
	{ "Shift para correr e pulo duplo para chegar mais rápido aos portais.", "Shift to run and a double jump to reach the portals faster." },
}
local tip = label("", 96, 48, 16, Color3.fromRGB(206, 218, 255))
tip.Font = Enum.Font.Gotham
tip.TextColor3 = Color3.fromRGB(206, 218, 255)

local started = os.clock()
local tipIndex = 1
local nextTip = 0
local connection
connection = RunService.RenderStepped:Connect(function()
	local elapsed = os.clock() - started
	slider.Position = UDim2.fromScale(-0.4 + 1.8 * ((elapsed * 0.7) % 1), 0)
	if elapsed >= nextTip then
		nextTip = elapsed + 4
		local entry = TIPS[tipIndex]
		tip.Text = T(entry[1], entry[2])
		tipIndex = tipIndex % #TIPS + 1
	end
	if elapsed > 4 then status.Text = T("Conectando à resistência…", "Connecting to the resistance…") end
end)

-- It leaves when the game's interface has its first state, or after a minute.
local function leave()
	if connection then connection:Disconnect(); connection = nil end
	if not gui.Parent then return end
	local fade = TweenService:Create(cover, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { BackgroundTransparency = 1 })
	for _, item in ipairs(cover:GetDescendants()) do
		if item:IsA("TextLabel") then
			TweenService:Create(item, TweenInfo.new(0.45), { TextTransparency = 1 }):Play()
		elseif item:IsA("Frame") then
			TweenService:Create(item, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
		elseif item:IsA("UIStroke") then
			TweenService:Create(item, TweenInfo.new(0.45), { Transparency = 1 }):Play()
		end
	end
	fade:Play()
	fade.Completed:Connect(function() gui:Destroy() end)
	task.delay(1, function() if gui.Parent then gui:Destroy() end end)
end

task.spawn(function()
	if not game:IsLoaded() then game.Loaded:Wait() end
	local deadline = os.clock() + 60
	while os.clock() < deadline and player:GetAttribute("DoomReady") ~= true do task.wait(0.15) end
	-- A short beat so the first frame of the lobby is already drawn behind it.
	task.wait(0.2)
	leave()
end)
