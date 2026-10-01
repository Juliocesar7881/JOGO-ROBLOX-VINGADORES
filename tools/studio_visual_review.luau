assert(game.PlaceId ~= 97132875544830, "Disposable copies only: never run this in the team place (use tools/studio_review.py).")
-- Run through Studio --task RunScript on a disposable generated place copy.
-- This exercises the real renderer and world API, without publishing anything.
local shared = game:GetService("ReplicatedStorage"):WaitForChild("DoomShared")
local server = game:GetService("ServerScriptService"):WaitForChild("DoomServer")
local world = require(server.WorldBuilder).new(require(shared.Catalog), function() end)
world:Build("manhattan")
for i, id in ipairs(require(shared.Catalog).HeroOrder) do
	local x = -30 + ((i - 1) % 6) * 12
	local z = 42 + math.floor((i - 1) / 6) * 13
	world:MakeTower("review" .. i, id, Vector3.new(x, 0, z), 1)
end
workspace.CurrentCamera.CFrame = CFrame.lookAt(Vector3.new(15, 32, 93), Vector3.new(0, 3, 42))
workspace.CurrentCamera.FieldOfView = 55
print("DOOM_VISUAL_REVIEW_READY")
