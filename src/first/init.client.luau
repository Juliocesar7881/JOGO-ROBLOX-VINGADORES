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
local INK = Color3.fromRGB(11, 15, 36)

local gui = Instance.new("ScreenGui")
gui.Name, gui.IgnoreGuiInset, gui.ResetOnSpawn, gui.DisplayOrder = "DoomLoader", true, false, 1000
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local cover = Instance.new("Frame")
cover.Name, cover.Size, cover.BackgroundColor3, cover.BorderSizePixel = "Cover", UDim2.fromScale(1, 1), NAVY, 0
cover.ClipsDescendants = true
cover.Parent = gui
local gradient = Instance.new("UIGradient")
gradient.Color, gradient.Rotation = ColorSequence.new(NAVY:Lerp(VIOLET, 0.55), NAVY), 90
gradient.Parent = cover

local function corner(target, radius)
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0, radius)
	round.Parent = target
end
local function stroke(target, color, thickness)
	local line = Instance.new("UIStroke")
	line.Color, line.Thickness = color, thickness
	line.Parent = target
	return line
end

-- Soft sunburst rays turning slowly behind the title, like the big games'
-- splash screens; faint, so they never flash.
local rays = {}
for index = 0, 5 do
	local ray = Instance.new("Frame")
	ray.Name, ray.AnchorPoint, ray.Position = "Ray", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.42)
	ray.Size, ray.BackgroundColor3, ray.BackgroundTransparency, ray.BorderSizePixel = UDim2.new(3, 0, 0.15, 0), Color3.new(1, 1, 1), 0.94, 0
	ray.Rotation = index * 30
	ray.Parent = cover
	table.insert(rays, ray)
end

-- Everything else sits on a logical 720 x 460 stage scaled to the screen, so
-- a 4K monitor and a phone both see the same composition.
local stage = Instance.new("Frame")
stage.Name, stage.AnchorPoint, stage.Position, stage.Size = "Stage", Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromOffset(720, 460)
stage.BackgroundTransparency = 1
stage.Parent = cover
local stageScale = Instance.new("UIScale")
stageScale.Parent = stage
local function fitStage()
	local view = Vector2.new(1280, 720)
	pcall(function()
		local camera = workspace.CurrentCamera
		if camera and camera.ViewportSize.X > 0 then view = camera.ViewportSize end
	end)
	stageScale.Scale = math.clamp(math.min(view.X / 1150, view.Y / 640), 0.55, 4)
end
fitStage()

local function label(text, y, height, size, color, font)
	local made = Instance.new("TextLabel")
	made.BackgroundTransparency, made.Text, made.Font, made.TextSize = 1, text, font or Enum.Font.FredokaOne, size
	made.TextColor3, made.TextXAlignment = color, Enum.TextXAlignment.Center
	made.AnchorPoint, made.Position, made.Size = Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, y), UDim2.new(1, 0, 0, height)
	made.TextWrapped = true
	stroke(made, INK, size >= 60 and 6 or (size >= 26 and 3 or 2))
	made.Parent = stage
	return made
end

-- The emblem: a big gold star that rocks gently.
local star = label("★", 0, 112, 104, GOLD)
star.Name = "Emblem"
label(T("MULTIVERSO", "MULTIVERSE"), 112, 36, 30, GOLD)
local title = label("DOOMSDAY", 142, 100, 96, CREAM)
title.Name = "Title"
local shine = Instance.new("UIGradient")
shine.Color, shine.Rotation = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 214, 110)), 90
shine.Parent = title

-- The subtitle on a green ribbon.
local ribbon = Instance.new("Frame")
ribbon.Name, ribbon.AnchorPoint, ribbon.Position, ribbon.Size = "Ribbon", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 246), UDim2.fromOffset(290, 46)
ribbon.BackgroundColor3, ribbon.BorderSizePixel = GREEN:Lerp(INK, 0.15), 0
ribbon.Parent = stage
corner(ribbon, 14)
stroke(ribbon, INK, 3)
local subtitle = label(T("ÚLTIMA DEFESA", "LAST DEFENSE"), 0, 46, 30, Color3.new(1, 1, 1))
subtitle.Parent, subtitle.Position = ribbon, UDim2.fromScale(0.5, 0)

local track = Instance.new("Frame")
track.Name, track.AnchorPoint, track.Position, track.Size = "Track", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 318), UDim2.fromOffset(440, 22)
track.BackgroundColor3, track.BorderSizePixel, track.ClipsDescendants = INK, 0, true
track.Parent = stage
corner(track, 11)
stroke(track, Color3.fromRGB(70, 80, 140), 2)
local slider = Instance.new("Frame")
slider.Name, slider.Size, slider.Position, slider.BackgroundColor3, slider.BorderSizePixel = "Bar", UDim2.fromScale(0.4, 1), UDim2.fromScale(-0.4, 0), GREEN, 0
slider.Parent = track
corner(slider, 11)

local status = label(T("Preparando o refúgio…", "Preparing the refuge…"), 348, 30, 20, CREAM, Enum.Font.BuilderSansBold)
local TIPS = {
	{ "Clique no chão para posicionar um herói: sem confirmação.", "Click the ground to place a hero: no confirmation." },
	{ "Repetidos dos baús viram cartas para evoluir seus heróis sem limite.", "Duplicates from chests become cards that level your heroes with no cap." },
	{ "Em grupo, os inimigos têm mais vida — mas vocês também têm mais torres.", "In a group the enemies are tougher — but so is your defence." },
	{ "O Agente da Base, ao lado da sua base, evolui a base com a tecla E.", "The Base Agent beside your base upgrades it with the E key." },
	{ "Shift para correr e pulo duplo para chegar mais rápido aos portais.", "Shift to run and a double jump to reach the portals faster." },
	{ "Passe o mouse num herói para ver o dano, o alcance e o poder dele.", "Hover a hero to see its damage, range and power." },
}
-- The tip in a dark box under the bar.
local tipBox = Instance.new("Frame")
tipBox.Name, tipBox.AnchorPoint, tipBox.Position, tipBox.Size = "TipBox", Vector2.new(0.5, 0), UDim2.new(0.5, 0, 0, 388), UDim2.fromOffset(660, 62)
tipBox.BackgroundColor3, tipBox.BackgroundTransparency, tipBox.BorderSizePixel = INK, 0.35, 0
tipBox.Parent = stage
corner(tipBox, 14)
local tip = label("", 0, 62, 19, Color3.fromRGB(214, 224, 255), Enum.Font.BuilderSansBold)
tip.Parent, tip.Position, tip.Size = tipBox, UDim2.fromScale(0.5, 0), UDim2.new(1, -28, 1, 0)

local started = os.clock()
local tipIndex = 1
local nextTip = 0
local connection
connection = RunService.RenderStepped:Connect(function()
	local elapsed = os.clock() - started
	fitStage()
	slider.Position = UDim2.fromScale(-0.4 + 1.8 * ((elapsed * 0.7) % 1), 0)
	for index, ray in ipairs(rays) do ray.Rotation = (index - 1) * 30 + elapsed * 5 end
	star.Rotation = math.sin(elapsed * 1.6) * 6
	if elapsed >= nextTip then
		nextTip = elapsed + 4
		local entry = TIPS[tipIndex]
		tip.Text = T("Dica: ", "Tip: ") .. T(entry[1], entry[2])
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
