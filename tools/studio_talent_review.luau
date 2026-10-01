assert(game.PlaceId ~= 97132875544830, "Disposable copies only: never run this in the team place (use tools/studio_review.py).")
-- Run only against a disposable review copy, never a release artifact.
local starter = game:GetService("StarterPlayer").StarterPlayerScripts
for _, child in ipairs(starter:GetChildren()) do
	if child:IsA("LocalScript") then
		child.Source ..= [[
task.spawn(function()
 while not state or not state.profile do task.wait(1) end
 while true do
  task.wait(8)
  if state.phase == "Lobby" and not contextPanel then
   openContext("talents", {})
   print("DOOM_TALENT_REVIEW_READY")
  end
 end
end)
]]
	end
end
print("DOOM_TALENT_REVIEW_PREPARED")
