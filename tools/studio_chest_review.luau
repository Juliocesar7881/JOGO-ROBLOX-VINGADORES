assert(game.PlaceId ~= 97132875544830, "Disposable copies only: never run this in the team place (use tools/studio_review.py).")
-- Disposable review place only. The release contains no preview overrides.
local starter=game:GetService("StarterPlayer").StarterPlayerScripts
for _,child in ipairs(starter:GetChildren()) do
	if child:IsA("LocalScript") then
		child.Source ..= [[
task.spawn(function()
 while not state or not state.profile do task.wait(1) end
 task.wait(4)
 openContext("chests",{})
 print("DOOM_CHEST_REVIEW_READY")
end)
]]
	end
end
print("DOOM_CHEST_REVIEW_PREPARED")
