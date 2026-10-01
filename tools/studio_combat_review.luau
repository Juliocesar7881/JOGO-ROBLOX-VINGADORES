assert(game.PlaceId ~= 97132875544830, "Disposable copies only: never run this in the team place (use tools/studio_review.py).")
-- Disposable Studio place only: real renderer, full hero roster and 180
-- client enemies. No profile, reward, matchmaking or purchase requests.
local servers=game:GetService("ServerScriptService"):WaitForChild("DoomServer")
servers.Disabled=true
for _,child in ipairs(servers:GetChildren()) do if child:IsA("Script") then child.Disabled=true end end
local starters=game:GetService("StarterPlayer").StarterPlayerScripts
local original
for _,child in ipairs(starters:GetChildren()) do if child:IsA("LocalScript") then child.Disabled=true; original=child end end
assert(original,"Missing game client")
local server=Instance.new("Script")
server.Name="CombatReviewServer"
server.Source=[=[
local shared=game.ReplicatedStorage:WaitForChild("DoomShared")
local catalog=require(shared.Catalog)
local world=require(script.Parent.DoomServer.WorldBuilder).new(catalog,function() end)
local function build()
 local id=workspace:GetAttribute("ReviewMap") or "manhattan"
 if not catalog.Maps[id] then return end
 world:Build(id)
 for i,baseId in ipairs({"garden","arsenal","bunker","barracks"}) do
  local rules=require(shared.Rules)
  world:UpdateBase(i,{id=baseId,level=4,stats=rules.BaseStats(baseId,4)},Vector3.new((i-2.5)*25,0,12))
 end
 for i,hero in ipairs(catalog.HeroOrder) do
  world:MakeTower("review"..i,hero,Vector3.new(-36+((i-1)%6)*12,0,30+math.floor((i-1)/6)*11),1)
 end
 workspace:SetAttribute("ReviewBuilt",id)
end
workspace:GetAttributeChangedSignal("ReviewMap"):Connect(build)
build()
]=]
server.Parent=game.ServerScriptService
local client=Instance.new("LocalScript")
client.Name="CombatReviewClient"
for _,name in ipairs({"UI","Effects","Audio"}) do original:FindFirstChild(name):Clone().Parent=client end
client.Source=[=[
local RunService=game:GetService("RunService")
local player=game.Players.LocalPlayer
local catalog=require(game.ReplicatedStorage:WaitForChild("DoomShared").Catalog)
local config=require(game.ReplicatedStorage.DoomShared.Config)
-- Optional local audio preview. This path is never included in a release.
if workspace:GetAttribute("ReviewAudio") then
 for name in pairs(config.Audio) do config.Audio[name]=0; config.BuiltinCues[name]={path="rbxasset://doomsday-review/"..name..".wav",speed=1} end
end
local state={phase="Wave",wave=40,profile={settings={music=true,effects=true,lowFX=false,shake=false,language="pt"}}}
local audio=require(script.Audio).new(function() return state end)
local effects=require(script.Effects).new(player,function() end,function() return state end,audio)
local gui=Instance.new("ScreenGui");gui.Name="CombatReview";gui.Parent=player:WaitForChild("PlayerGui")
local label=Instance.new("TextLabel");label.Size=UDim2.new(1,0,0,36);label.Position=UDim2.fromOffset(0,60);label.BackgroundColor3=Color3.fromRGB(20,35,55);label.TextColor3=Color3.new(1,1,1);label.TextSize=14;label.Parent=gui
local camera=workspace.CurrentCamera;camera.CameraType=Enum.CameraType.Scriptable
camera.CFrame=CFrame.lookAt(Vector3.new(0,66,103),Vector3.new(0,2,26));camera.FieldOfView=57
RunService:BindToRenderStep("ReviewCamera",Enum.RenderPriority.Camera.Value+2,function()
 workspace.CurrentCamera.CameraType=Enum.CameraType.Scriptable
 workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(0,66,103),Vector3.new(0,2,26))
end)
local enemies=table.clone(catalog.EnemyOrder)
for _,id in ipairs(catalog.BossOrder) do table.insert(enemies,id) end
local elapsed,syncAt,shotAt,started,frames,frameTotal,worst=0,0,0,os.clock(),0,0,0
local samples={}
RunService.RenderStepped:Connect(function(dt)
 elapsed+=dt;frames+=1;frameTotal+=dt;worst=math.max(worst,dt);table.insert(samples,dt)
 if elapsed>=syncAt then
  syncAt=elapsed+0.2
  local snapshot={}
  local count=workspace:GetAttribute("ReviewEnemyCount") or 40
  for i=1,count do
   local kind=enemies[(i-1)%#enemies+1]
   -- Keep five bosses total; the rest are the eight ordinary families.
   if i>#enemies then kind=catalog.EnemyOrder[(i-1)%#catalog.EnemyOrder+1] end
   local x=-44+((i*7+elapsed*3)%88)
   local z=-35+math.floor((i-1)/22)*5
   table.insert(snapshot,{id=i,enemyId=kind,position=Vector3.new(x,0,z),hp=80,maxHP=100,st=i%3==0 and 18 or 0})
  end
  effects:Handle({kind="EnemySync",enemies=snapshot})
  local soldiers={}
  for i=1,8 do table.insert(soldiers,{id="ally"..i,baseId="barracks",hp=70,maxHP=100,position=Vector3.new(-28+i*7,0,18-(elapsed*4+i*3)%45)}) end
  effects:Handle({kind="SoldierSync",soldiers=soldiers})
 end
 if elapsed>=shotAt then
  shotAt=elapsed+0.75
  effects:Handle({kind="BaseShot",from=Vector3.new(0,6,12),to=Vector3.new(0,2,-15),color=Color3.fromRGB(255,191,82)})
  for i,hero in ipairs(catalog.HeroOrder) do
   local position=Vector3.new(-36+((i-1)%6)*12,4,30+math.floor((i-1)/6)*11)
   effects:Handle({kind="Shot",towerId="review"..i,heroId=hero,from=position,to=Vector3.new(position.X,2,-15),color=Color3.fromRGB(table.unpack(catalog.Heroes[hero].color))})
  end
 end
 if os.clock()-started>=10 then
  table.sort(samples)
  local p95=samples[math.max(1,math.ceil(#samples*.95))]
  local map=workspace:GetAttribute("ReviewBuilt") or "loading"
  local fps=frames/math.max(frameTotal,.001)
  label.Text=string.format("REVISÃO LOCAL · %s · %d inimigos · %.1f FPS · p95 %.1f ms · efeitos %s",map,workspace:GetAttribute("ReviewEnemyCount") or 40,fps,p95*1000,state.profile.settings.lowFX and "reduzidos" or "completos")
  print("DOOM_COMBAT_REVIEW",map,frames,string.format("fps=%.1f p95=%.1fms worst=%.1fms memory=%.1fMB",fps,p95*1000,worst*1000,game:GetService("Stats"):GetTotalMemoryUsageMb()))
  started,frames,frameTotal,worst,samples=os.clock(),0,0,0,{}
 end
end)
workspace:GetAttributeChangedSignal("ReviewLowFX"):Connect(function() state.profile.settings.lowFX=workspace:GetAttribute("ReviewLowFX")==true end)
task.delay(6,function()
 effects:Handle({kind="Pulse",position=Vector3.new(0,0,0),followEnemyId=13,radius=22,duration=6,warningText={pt="PODER DO CHEFE",en="BOSS POWER"},color=Color3.fromRGB(255,170,64)})
 audio:Music("battle")
 print("DOOM_COMBAT_CLIENT_READY")
end)
]=]
client.Parent=starters
print("DOOM_COMBAT_REVIEW_INSTALLED")
