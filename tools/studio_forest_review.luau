assert(game.PlaceId ~= 97132875544830, "Disposable copies only: never run this in the team place (use tools/studio_review.py).")
-- Run on a disposable copy to inspect the sanctuary in the real renderer.
local shared=game:GetService("ReplicatedStorage"):WaitForChild("DoomShared")
local server=game:GetService("ServerScriptService"):WaitForChild("DoomServer")
for _,name in ipairs({"EditorBaseplate","EditorSpawn"}) do
	local item=workspace:FindFirstChild(name)
	if item then item:Destroy() end
end
require(server.WorldBuilder).new(require(shared.Catalog),function() end)
workspace.CurrentCamera.Focus=CFrame.new(0,4,353)
workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(240,195,630),Vector3.new(0,4,353))
workspace.CurrentCamera.FieldOfView=65
print("DOOM_FOREST_REVIEW_READY")
