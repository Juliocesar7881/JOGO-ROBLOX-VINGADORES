assert(game.PlaceId ~= 97132875544830, "Disposable copies only: never run this in the team place (use tools/studio_review.py).")
-- RunScript on a disposable place copy. Walks a temporary Studio player onto
-- the real shop pad; does not grant currency or submit any purchase.
local server=Instance.new("Script")
server.Name="ShopEntryReview"
server.Source=[=[
local Players=game:GetService("Players")
local function visit(player)
 local character=player.Character or player.CharacterAdded:Wait()
 character:WaitForChild("HumanoidRootPart")
 task.wait(7)
 character:PivotTo(CFrame.new(43,4,338))
 print("DOOM_SHOP_STOOD_ON_PAD",player.UserId)
end
Players.PlayerAdded:Connect(function(player) task.spawn(visit,player) end)
for _,player in ipairs(Players:GetPlayers()) do task.spawn(visit,player) end
]=]
server.Parent=game:GetService("ServerScriptService")
for _,child in ipairs(game:GetService("StarterPlayer").StarterPlayerScripts:GetChildren()) do
 if not child:IsA("LocalScript") then continue end
 child.Source..=[=[
task.spawn(function()
 task.wait(9)
 workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
 workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(0,34,395),Vector3.new(55,2,350))
 task.wait(1)
 print("DOOM_SHOP_PAD_OPEN",contextPanel and contextPanel.kind,selectedChest)
 local overflow=0
 for _,item in ipairs(gui:GetDescendants()) do
  if (item:IsA("TextLabel") or item:IsA("TextButton")) and item.Text~="" and item.TextTransparency<1 then
   if item.TextFits==false then print("DOOM_SHOP_TEXT_OVERFLOW",item.Name,item.Text); overflow+=1 end
  end
 end
 print("DOOM_SHOP_TEXT_CHECK",overflow)
end)
]=]
end
print("DOOM_SHOP_REVIEW_INSTALLED")
