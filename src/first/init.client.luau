--!nonstrict
-- Cold-join cover. Art is packaged beside this script in ReplicatedFirst:
-- no image download, shared module, profile or world is needed to draw it.
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local LocalizationService = game:GetService("LocalizationService")
local Art = require(script:WaitForChild("ScreenArt"))
local player = Players.LocalPlayer
local portuguese = true
pcall(function() portuguese = string.sub(string.lower(LocalizationService.RobloxLocaleId),1,2)=="pt" end)
local function T(pt,en) return portuguese and pt or en end

local gui = Instance.new("ScreenGui")
gui.Name,gui.IgnoreGuiInset,gui.ResetOnSpawn,gui.DisplayOrder="DoomLoader",true,false,1000
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.Parent=player:WaitForChild("PlayerGui")
local canvas=Instance.new("Frame")
canvas.Name,canvas.Size,canvas.BackgroundColor3,canvas.BorderSizePixel="Cover",UDim2.fromScale(1,1),Color3.fromRGB(5,13,29),0
canvas.Parent=gui
local scale=Instance.new("UIScale")
scale.Parent=canvas
local view,lastSize
local function resize()
	local camera=workspace.CurrentCamera
	local size=camera and camera.ViewportSize or Vector2.new(1280,720)
	if size.X<=0 or size.Y<=0 then return end
	local amount=math.clamp(math.min(size.X/1150,size.Y/640),1,4)
	scale.Scale=amount
	canvas.Size=UDim2.fromScale(1/amount,1/amount)
	local logical=Vector2.new(size.X/amount,size.Y/amount)
	local key=tostring(logical.X)..":"..tostring(logical.Y)
	if key==lastSize then return end
	lastSize=key
	if view then view.root:Destroy() end
	view=Art.Loading(canvas,T,logical)
end
-- Cover first, then remove Roblox's default, avoiding a black-frame gap.
resize()
pcall(function() ReplicatedFirst:RemoveDefaultLoadingScreen() end)

local started=os.clock()
local deadline=started+60
local left=false
local connection
local function leave()
	if left then return end
	left=true
	if connection then connection:Disconnect(); connection=nil end
	gui:Destroy()
end
local nextFrame=0
connection=RunService.RenderStepped:Connect(function()
	local now=os.clock()
	-- Static scenery; only the waiting segment updates, at 12 Hz.
	if now<nextFrame then return end
	nextFrame=now+1/12
	resize()
	local ready=player:GetAttribute("DoomReady")==true
	if view then view.Step(now-started,game:IsLoaded(),ready,false) end
	if (ready and game:IsLoaded()) or now>=deadline then leave() end
end)
-- The hard deadline includes world loading, not just the profile wait.
task.delay(60,leave)
