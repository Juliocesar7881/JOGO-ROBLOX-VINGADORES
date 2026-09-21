-- Disposable local preview: exercises the actual Roblox materials and lighting.
local shared=game:GetService("ReplicatedStorage"):WaitForChild("DoomShared")
local server=game:GetService("ServerScriptService"):WaitForChild("DoomServer")
require(server.WorldBuilder).new(require(shared.Catalog),function() end)
workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(38,25,370),Vector3.new(0,9,300))
workspace.CurrentCamera.FieldOfView=65
print("DOOM_ART_REVIEW_READY")
