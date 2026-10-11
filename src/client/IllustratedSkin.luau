-- Authored, text-free raster art. Live labels and hit targets stay in UI.luau.
-- One texture per atlas, shared by all copies; no per-frame work or preload gate.
local Config=require(game:GetService("ReplicatedStorage"):WaitForChild("DoomShared"):WaitForChild("Config"))
local Skin={}
local downloads={}
local icons={hero=1,base=2,heart=16,star=9,talents=3,shop=4,coin=4,gift=5,scroll=6,quest=6,gear=7,trophy=8,xp=9,bolt=10,wave=10,sword=11,damage=11,range=12,target=12,chest=13,home=14,play=15,shield=16}
local chests={common=1,supply=1,rare=2,epic=3,legendary=4,mythic=5,cosmic=5,base=6,
	base_supply=6,base_rare=2,base_epic=3,base_legendary=4,base_cosmic=5}
function Skin.available(name)
	return type(Config.UiArt)=="table" and (tonumber(Config.UiArt[name]) or 0)>0
end
local function image(parent,name,properties)
	if not Skin.available(name) then return nil end
	local item=Instance.new("ImageLabel")
	item.Name="Illustrated_"..name
	item.BackgroundTransparency=1; item.BorderSizePixel=0; item.Active=false
	item.Size=UDim2.fromScale(1,1); item.ZIndex=parent.ZIndex
	item.Image="rbxassetid://"..Config.UiArt[name]
	for key,value in pairs(properties or {}) do item[key]=value end
	item.Parent=parent
	return item
end
-- Fallbacks are hidden only once Roblox confirms the texture has loaded.
function Skin.loaded(item,callback)
	if not item then return end
	local url=item.Image
	local download=downloads[url]
	if not download then download={waiting={}}; downloads[url]=download end
	local function update() if item.Parent then callback(item.IsLoaded==true or download.ready==true) end end
	local signal=item:GetPropertyChangedSignal("IsLoaded"):Connect(update)
	item.Destroying:Connect(function() signal:Disconnect(); download.waiting[item]=nil end)
	update()
	if download.ready then return end
	download.waiting[item]=update
	if download.loading then return end
	download.loading=true
	-- IsLoaded does not reliably notify when a cached image becomes ready in
	-- Studio. One asynchronous fetch per URL completes all waiting copies;
	-- this never blocks the UI or adds a polling loop to the render frame.
	task.defer(function()
		pcall(function()
			game:GetService("ContentProvider"):PreloadAsync({url},function(_,status)
				if status==Enum.AssetFetchStatus.Success then download.ready=true end
			end)
		end)
		for _,notify in pairs(download.waiting) do notify() end
		download.waiting={}
		if not download.ready then downloads[url]=nil end
	end)
end
function Skin.plate(parent,kind,tint,properties)
	local imageProperties={ScaleType=Enum.ScaleType.Slice}
	if kind=="window" then
		imageProperties.SliceCenter=Rect.new(110,100,914,583); imageProperties.SliceScale=0.26
	elseif kind=="card" then
		imageProperties.SliceCenter=Rect.new(90,90,934,934); imageProperties.SliceScale=0.17
		imageProperties.ImageColor3=tint
	else
		-- Ignore the transparent top/bottom gutters of the authored button.
		imageProperties.ImageRectOffset=Vector2.new(0,36); imageProperties.ImageRectSize=Vector2.new(1024,241)
		imageProperties.SliceCenter=Rect.new(110,70,914,171); imageProperties.SliceScale=0.17
		imageProperties.ImageColor3=tint
	end
	for key,value in pairs(properties or {}) do imageProperties[key]=value end
	return image(parent,kind,imageProperties)
end
function Skin.icon(parent,kind,properties)
	local index=icons[kind]
	if not index then return nil end
	local item=image(parent,"icons",properties)
	if item then
		item.ScaleType=Enum.ScaleType.Fit
		item.ImageRectOffset=Vector2.new(((index-1)%4)*256,math.floor((index-1)/4)*256)
		item.ImageRectSize=Vector2.new(256,256)
		item:SetAttribute("ArtSymbol",kind)
	end
	return item
end
function Skin.chest(parent,rarity,properties)
	local index=chests[rarity] or 2
	local item=image(parent,"chests",properties)
	if item then
		item.ScaleType=Enum.ScaleType.Fit
		item.ImageRectOffset=Vector2.new(((index-1)%3)*341,math.floor((index-1)/3)*341)
		item.ImageRectSize=Vector2.new(341,341)
		item:SetAttribute("ArtRarity",rarity)
	end
	return item
end
return Skin
