-- Run only in a disposable local place. Exercises real font/layout measurement.
for _,child in ipairs(game:GetService("StarterPlayer").StarterPlayerScripts:GetChildren()) do
	if child:IsA("LocalScript") then
		child.Source ..= [[
task.spawn(function()
 while not state or not state.profile do task.wait(1) end
 task.wait(3)
 inventoryFilter="all"
 for _,page in ipairs({{kind="inventory"},{kind="hero",heroId="ironman"},{kind="chests",chestId="legendary"},{kind="premium"}}) do
  openContext(page.kind,page)
  task.wait(2)
  local oversized=0
  local panel=main:FindFirstChild("ContextPanel")
  for _,item in ipairs(panel and panel:GetDescendants() or {}) do
   if (item:IsA("TextLabel") or item:IsA("TextButton")) and item.Text~="" and item.AbsoluteSize.X>0 then
    if item.TextBounds.X>item.AbsoluteSize.X+2 or item.TextBounds.Y>item.AbsoluteSize.Y+2 then
     oversized+=1
     print("DOOM_TEXT_OVERFLOW",page.kind,item.Name,item.Text,item.TextBounds,item.AbsoluteSize)
    end
   end
  end
  print("DOOM_NAV_REVIEW",page.kind,oversized)
 end
 openContext("inventory",{})
 print("DOOM_NAV_READY")
end)
]]
	end
end
