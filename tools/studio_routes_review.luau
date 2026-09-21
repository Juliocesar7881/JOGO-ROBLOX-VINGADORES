-- Disposable edit-mode inspection using the real world builder and renderer.
local shared=game:GetService("ReplicatedStorage"):WaitForChild("DoomShared")
local server=game:GetService("ServerScriptService"):WaitForChild("DoomServer")
local catalog=require(shared.Catalog)
for _,name in ipairs({"EditorBaseplate","EditorSpawn","DoomWorld","DoomLobby"}) do
	local old=workspace:FindFirstChild(name)
	if old then old:Destroy() end
end
local world=require(server.WorldBuilder).new(catalog,function() end)
for _,mapId in ipairs(catalog.MapOrder) do
	world:Build(mapId)
	local count=0
	for _,part in ipairs(world.Paths:GetChildren()) do if part.Name=="MobTrail" then count+=1 end end
	print("DOOM_ROUTES_READY",mapId,count)
end
world:Build("wakanda")
workspace.CurrentCamera.CFrame=CFrame.lookAt(Vector3.new(0,255,145),Vector3.new(0,0,0))
workspace.CurrentCamera.FieldOfView=58
print("DOOM_ROUTES_CAPTURE_READY")
