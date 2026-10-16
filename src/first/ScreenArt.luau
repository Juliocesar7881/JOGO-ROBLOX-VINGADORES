-- Launch/AFK art referenced from the actual lobby and hero geometry.
-- A cold join never waits for imagery, world replication or a profile to draw.
local ScreenArt = {}
local P = {
	ink = Color3.fromRGB(5, 13, 29), navy = Color3.fromRGB(10, 27, 51),
	steel = Color3.fromRGB(34, 66, 96), blue = Color3.fromRGB(35, 189, 255),
	gold = Color3.fromRGB(255, 210, 63), cream = Color3.fromRGB(255, 241, 204),
	violet = Color3.fromRGB(169, 112, 255), muted = Color3.fromRGB(188, 209, 230),
}
local function make(class, parent, properties)
	local item = Instance.new(class)
	for key, value in pairs(properties) do item[key] = value end
	item.Parent = parent
	return item
end
local function frame(parent, name, x, y, w, h, color, z, rotation, transparency)
	return make("Frame", parent, {Name=name, Position=UDim2.fromOffset(x,y), Size=UDim2.fromOffset(w,h), BackgroundColor3=color,
		BorderSizePixel=0, Active=false, ZIndex=z, Rotation=rotation or 0, BackgroundTransparency=transparency or 0})
end
local function round(item, radius)
	make("UICorner", item, {CornerRadius=UDim.new(0,radius)})
	return item
end
local function line(parent, name, x1,y1,x2,y2,thickness,color,z,transparency)
	local dx,dy=x2-x1,y2-y1
	local made=frame(parent,name,(x1+x2)/2,(y1+y2)/2,math.sqrt(dx*dx+dy*dy),thickness,color,z,math.deg(math.atan2(dy,dx)),transparency)
	made.AnchorPoint=Vector2.new(0.5,0.5)
	return made
end
local function gradient(item,a,b,rotation)
	make("UIGradient",item,{Color=ColorSequence.new(a,b),Rotation=rotation or 90})
end

-- Neither the reference painting nor the native model fallback blocks entry.
-- ReplicatedFirst draws immediately, before Config, imagery or profiles exist.
function ScreenArt.Draw(parent, mode, width, height, z)
	z=z or 1
	local accent=mode=="gold" and P.gold or (mode=="xp" and P.violet or P.blue)
	local root=make("Frame",parent,{Name="DimensionalBackdrop",Size=UDim2.fromScale(1,1),BackgroundColor3=P.navy,BorderSizePixel=0,ClipsDescendants=true,Active=false,ZIndex=z})
	gradient(root,Color3.fromRGB(29,60,87),P.ink,30)
	-- A quiet technical cover remains usable if an image fails to download.
	for i=1,14 do line(root,"LaunchGrid",0,height*i/14,width,height*i/14,1,P.steel,z+1,0.65) end
	for i=1,22 do line(root,"LaunchGrid",width*i/22,0,width*i/22,height,1,P.steel,z+1,0.65) end
	local view=make("ViewportFrame",root,{Name="LobbyPhotography",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=z+2,
		Ambient=Color3.fromRGB(165,190,210),LightColor=Color3.fromRGB(255,241,211),LightDirection=Vector3.new(-1,-1,-0.4)})
	local world=make("WorldModel",view,{Name="ActualLobby"})
	local camera=make("Camera",view,{FieldOfView=60})
	camera.CFrame=CFrame.lookAt(Vector3.new(-34,32,559),Vector3.new(0,15,466))
	view.CurrentCamera=camera
	local filled,heroes=false,false
	local painting,artReady,artConnection
	local function showPainting()
		if not root.Parent or not painting then return end
		artReady=true; painting.Visible=true; view.Visible=false
		for _,item in ipairs(root:GetChildren()) do
			if item:IsA("ViewportFrame") then item.Visible=false end
		end
	end
	local function requestPainting()
		if painting then return end
		local shared=game:GetService("ReplicatedStorage"):FindFirstChild("DoomShared")
		local config=shared and shared:FindFirstChild("Config")
		if not config then return end
		local ok,data=pcall(require,config)
		local id=ok and data.UiArt and data.UiArt[mode=="loading" and "launch" or "afk"]
		if not id or id<=0 then return end
		-- Keep the transparent image drawable while fetching: Roblox may leave
		-- IsLoaded false forever for a hidden ImageLabel, despite a cached asset.
		painting=make("ImageLabel",root,{Name="RefugePainting",Size=UDim2.fromScale(1,1),BackgroundTransparency=1,Active=false,ZIndex=z+5,Image="rbxassetid://"..tostring(id),ScaleType=Enum.ScaleType.Crop})
		painting:SetAttribute("ReferenceArt",mode=="loading" and "launch" or "afk")
		-- Preserve the heroes on the left on tall screens, without stretching.
		if width/height<1 then painting.ImageRectOffset=Vector2.zero; painting.ImageRectSize=Vector2.new(640,576) end
		artConnection=painting:GetPropertyChangedSignal("IsLoaded"):Connect(function()
			if painting.IsLoaded then showPainting() end
		end)
		if painting.IsLoaded then showPainting() end
		-- Roblox does not always notify IsLoaded. The asynchronous fetch is an
		-- alternative completion signal; it never controls DoomReady or rewards.
		task.spawn(function()
			pcall(function()
				game:GetService("ContentProvider"):PreloadAsync({painting.Image},function(_,status)
					if status==Enum.AssetFetchStatus.Success then showPainting() end
				end)
			end)
		end)
	end
	local function clean(model)
		for _,item in ipairs(model:GetDescendants()) do
			if item:IsA("BasePart") then item.Anchored=true; item.CanCollide=false; item.CanTouch=false; item.CanQuery=false
			elseif item:IsA("LuaSourceContainer") or item:IsA("ProximityPrompt") or item:IsA("BillboardGui") or item:IsA("SurfaceGui") then item:Destroy() end
		end
	end
	local function populate()
		if not root.Parent then return end
		requestPainting()
		if painting and painting.IsLoaded then showPainting() end
		if artReady then return end
		local lobby=workspace:FindFirstChild("DoomLobby")
		if lobby and not filled then
			-- Prioritize the finished tower and plaza; a fixed part budget avoids
			-- cloning the entire island or its gameplay objects into every screen.
			local count=0
			for _,name in ipairs({"HeroTower","HeroBeacon","HeroesHQ","HeroStatues","SummonHeroesHall","SummonBasesHall"}) do
				local source=lobby:FindFirstChild(name)
				for _,item in ipairs(source and source:GetDescendants() or {}) do
					if count<280 and item:IsA("BasePart") and (item.Transparency or 0)<1 and (item.Position-Vector3.new(0,0,480)).Magnitude<180 then
						local copy=item:Clone(); clean(copy)
						copy.Anchored=true; copy.CanCollide=false; copy.CanTouch=false; copy.CanQuery=false
						copy.Parent=world; count+=1
					end
				end
			end
			filled=count>0
			view:SetAttribute("ActualLobbyParts",count)
		end
		local templates=game:GetService("ReplicatedStorage"):FindFirstChild("DoomHeroPortraits")
		if templates and not heroes then
			local made=0
			for i,id in ipairs(mode=="gold" and {"ironman","captain"} or {"thor","ironman"}) do
				local source=templates:FindFirstChild(id)
				if root:FindFirstChild("ActualHero_"..id) then made+=1
				elseif source then
					local portrait=make("ViewportFrame",root,{Name="ActualHero_"..id,Position=UDim2.fromScale(i==1 and 0.015 or 0.24,0.28),Size=UDim2.fromScale(0.34,0.66),BackgroundTransparency=1,ZIndex=z+4,
						Ambient=Color3.fromRGB(190,206,222),LightColor=Color3.fromRGB(255,238,207),LightDirection=Vector3.new(-1,-0.7,-1)})
					local heroWorld=make("WorldModel",portrait,{Name="ActualHeroModel"})
					local model=source:Clone(); clean(model); model.Parent=heroWorld
					local cf,bounds=model:GetBoundingBox()
					local focus=cf.Position+Vector3.new(0,bounds.Y*0.04,0)
					local span=math.max(bounds.Y,bounds.X,5)
					local cam=make("Camera",portrait,{FieldOfView=32})
					cam.CFrame=CFrame.lookAt(focus+Vector3.new(span*(i==1 and 0.46 or -0.46),span*0.1,-span*1.95),focus)
					portrait.CurrentCamera=cam; portrait:SetAttribute("HeroId",id); made+=1
				end
			end
			heroes=made==2
		end
	end
	populate()
	-- ReplicatedFirst can precede the world/templates. Poll with no yielding,
	-- then disconnect both on success and destruction (also across resizes).
	local connection
	local nextCheck=0
	if not artReady then
		connection=game:GetService("RunService").RenderStepped:Connect(function()
			if os.clock()<nextCheck then return end
			nextCheck=os.clock()+0.5
			populate()
			if artReady and connection then connection:Disconnect(); connection=nil end
		end)
	end
	root.Destroying:Connect(function()
		if connection then connection:Disconnect(); connection=nil end
		if artConnection then artConnection:Disconnect(); artConnection=nil end
	end)
	local shade=make("Frame",root,{Name="ReadingShade",Position=UDim2.fromScale(0.40,0),Size=UDim2.fromScale(0.60,1),BackgroundColor3=P.ink,BackgroundTransparency=0.04,BorderSizePixel=0,Active=false,ZIndex=z+6})
	make("UIGradient",shade,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.43,0.08),NumberSequenceKeypoint.new(1,0)}),Rotation=0})
	frame(root,"LaunchEdge",width-5,0,5,height,accent,z+7)
	return root
end

-- Both the early loader and the reconnect splash use this same composition.
-- The optional UI adapter applies the game's scale-aware text limits once it
-- exists; ReplicatedFirst itself never waits for the client or shared modules.
-- farm ({kind = "gold"|"xp", title}) is a trip to an AFK farm: its own art and
-- words, the same picture the farm screen then shows (owner, 15/10: no other
-- screen may flash on the way in).
function ScreenArt.Loading(parent, T, size, UI, farm)
	local w,h=size.X,size.Y
	local compact=w<600
	local root=make("Frame",parent,{Name="LoadingSplash",Size=UDim2.fromScale(1,1),BackgroundColor3=P.ink,BorderSizePixel=0,Active=true,ZIndex=80})
	if farm then root:SetAttribute("AfkKind",farm.kind) end
	local backdrop=ScreenArt.Draw(root,farm and farm.kind or "loading",w,h+80,80)
	backdrop.Position=UDim2.fromOffset(0,-80)
	backdrop.Size=UDim2.new(1,0,1,80)
	local height=math.min(h-40,360)
	local box=make("Frame",root,{Name="LaunchContent",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(compact and 0.5 or 0.74,0.52),Size=UDim2.fromOffset(compact and w-32 or math.min(w*0.43,490),height),BackgroundTransparency=1,Active=false,ZIndex=90})
	if compact then
		box.BackgroundColor3=P.ink; box.BackgroundTransparency=0.12
		round(box,14)
		make("UIStroke",box,{Color=P.steel,Thickness=1,Transparency=0.3})
	end
	local function label(name,text,y,lh,fs,color,body)
		local properties={Name=name,Position=UDim2.fromOffset(compact and 16 or 0,y),Size=UDim2.new(1,compact and -32 or 0,0,lh),BackgroundTransparency=1,BorderSizePixel=0,Text=text,TextColor3=color or P.cream,
			TextSize=fs,Font=body and Enum.Font.BuilderSansBold or Enum.Font.FredokaOne,TextXAlignment=Enum.TextXAlignment.Left,TextWrapped=body==true,ZIndex=91}
		local made=UI and UI.label(box,text,properties) or make("TextLabel",box,properties)
		if UI then if body then UI.fit(made,11) else UI.oneLine(made,12) end end
		return made
	end
	local small=height<330
	local accent=farm and (farm.kind=="gold" and P.gold or P.violet) or P.gold
	-- The game's name, "Multiverse Heroes: Doomsday Tower Defense" (owner, 15/10).
	label("SplashKicker",farm and T("MULTIVERSO / REFÚGIO","MULTIVERSE / REFUGE") or "DOOMSDAY  •  TOWER DEFENSE",0,26,small and 14 or 17,accent,true)
	local titleSize=farm and (compact and 34 or (small and 36 or 48)) or (compact and 40 or (small and 40 or 56))
	local title=label("SplashTitle",farm and farm.title or "MULTIVERSE HEROES",small and 30 or 32,small and 66 or 86,titleSize)
	-- Long words on a narrow phone shrink instead of spilling out of the box.
	title.TextScaled=true
	if not title:FindFirstChildOfClass("UITextSizeConstraint") then make("UITextSizeConstraint",title,{MaxTextSize=titleSize,MinTextSize=18}) end
	if farm then title.TextColor3=accent end
	label("SplashSubtitle",farm and T("Seu farm continua enquanto você descansa.","Your farm keeps going while you rest.") or T("O próximo mundo precisa de você.","The next world needs you."),small and 100 or 122,36,small and 16 or 20,P.muted,true)
	local statusY=small and 148 or 183
	local status=label("SplashStatus","",statusY,28,17,P.blue,true)
	local track=frame(box,"SplashTrack",compact and 16 or 0,statusY+38,compact and w-64 or math.min(w*0.43,490),10,P.steel,91)
	track.ClipsDescendants=true
	local slider=frame(track,"SplashBar",0,0,90,10,P.blue,92)
	local steps={}
	for i,text in ipairs({T("Cenário","World"),T("Perfil","Profile"),T("Pronto","Ready")}) do
		local chip=label("LoadStep"..i,text,statusY+62,22,13,P.muted,true)
		chip.Position=UDim2.new((i-1)/3,compact and 16 or 0,0,statusY+62)
		chip.Size=UDim2.new(1/3,compact and -24 or -8,0,22)
		steps[i]=chip
	end
	label("SplashTip",farm and T("DICA  •  Fique no farm: o pagamento cai a cada minuto, mesmo com a tela parada.","TIP  •  Stay in the farm: a payment lands every minute, even with the screen still.")
		or T("DICA  •  O primeiro herói da equipe define seu poder na partida.","TIP  •  Your first equipped hero sets your power in battle."),height-48,48,small and 13 or 15,P.muted,true)
	local function step(elapsed,worldLoaded,ready,reduced)
		if not root.Parent then return end
		local phase=ready and 3 or (worldLoaded and 2 or 1)
		if farm then
			status.Text=phase==3 and T("Farm pronto!","Farm ready!") or (phase==2 and T("Conectando seu perfil…","Connecting your profile…") or T("Entrando no farm…","Entering the farm…"))
		else
			status.Text=phase==3 and T("Tudo pronto. Vamos defender!","All set. Time to defend!") or (phase==2 and T("Conectando seu perfil…","Connecting your profile…") or T("Carregando o refúgio…","Loading the refuge…"))
		end
		if elapsed>=15 and not ready then
			status.Text=T("A conexão está demorando. Tentando novamente…","Connection is taking longer. Retrying…")
		end
		for i,item in ipairs(steps) do item.TextColor3=i<=phase and P.blue or P.muted end
		if phase==3 then slider.Position=UDim2.fromScale(0,0); slider.Size=UDim2.fromScale(1,1)
		else slider.Size=UDim2.fromScale(0.22,1); slider.Position=UDim2.fromScale(reduced and 0.39 or (0.78*((elapsed*0.38)%1)),0) end
	end
	step(0,false,false,false)
	return {root=root,Step=step}
end

return ScreenArt
