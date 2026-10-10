-- Original, entirely native comic scenery. ReplicatedFirst carries it so a
-- cold join never waits for an image, the world or the player's profile.
-- Static 2D art also remains visible with 3D rendering disabled in AFK mode.
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
local function ellipse(parent,name,x,y,w,h,color,z,transparency)
	return round(frame(parent,name,x,y,w,h,color,z,0,transparency),math.max(w,h))
end
local function gradient(item,a,b,rotation)
	make("UIGradient",item,{Color=ColorSequence.new(a,b),Rotation=rotation or 90})
end

function ScreenArt.Draw(parent, mode, width, height, z)
	z=z or 1
	local accent=mode=="gold" and P.gold or (mode=="xp" and P.violet or P.blue)
	local root=make("Frame",parent,{Name="DimensionalBackdrop",Size=UDim2.fromScale(1,1),BackgroundColor3=P.navy,BorderSizePixel=0,ClipsDescendants=true,Active=false,ZIndex=z})
	gradient(root,mode=="gold" and Color3.fromRGB(33,47,58) or Color3.fromRGB(23,36,72),P.ink,30)
	local canvas=make("Frame",root,{Name="Illustration",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(1150,640),BackgroundTransparency=1,Active=false,ZIndex=z})
	make("UIScale",canvas,{Scale=math.max(width/1150,height/640)})
	if width<600 then canvas.AnchorPoint=Vector2.new(0.27,0.5) end
	-- The observatory looks across the island towards a city, framed by steel
	-- ribs. Far scenery stays lower contrast than the portal and live counters.
	ellipse(canvas,"DistantMoon",740,70,100,100,Color3.fromRGB(57,88,128),z)
	ellipse(canvas,"MoonShadow",762,61,92,100,Color3.fromRGB(21,37,65),z)
	for i=1,22 do
		local x=(i*173)%1130
		local y=35+(i*73)%270
		ellipse(canvas,"Star",x,y,i%4==0 and 4 or 2,i%4==0 and 4 or 2,P.muted,z,0.35)
	end
	for i=0,12 do
		local x=490+i*57
		local h=38+(i*37)%126
		frame(canvas,"CityTower",x,350-h,42,h,Color3.fromRGB(24,52,81),z)
		frame(canvas,"RoofCap",x+5,346-h,32,4,Color3.fromRGB(52,82,110),z)
		for row=0,3 do
			line(canvas,"CityWindow",x+9,362-h+row*22,x+30,362-h+row*22,2,P.blue,z,0.65)
		end
	end
	frame(canvas,"IslandHorizon",0,350,1150,80,Color3.fromRGB(17,49,59),z)
	for i=0,10 do
		local x=70+i*105
		frame(canvas,"TreeTrunk",x+18,321,9,44,Color3.fromRGB(12,34,43),z)
		ellipse(canvas,"TreeCrown",x,290-(i%3)*8,48,44,Color3.fromRGB(24,67,67),z)
	end
	gradient(frame(canvas,"Harbour",0,376,1150,100,Color3.new(1,1,1),z),Color3.fromRGB(28,74,92),Color3.fromRGB(14,34,54))
	for i=1,8 do line(canvas,"WaterReflection",640+(i*63)%420,388+i*8,720+(i*63)%420,388+i*8,2,P.blue,z,0.8) end
	-- Perspective deck and skylight: broad shapes, very few luminous strokes.
	frame(canvas,"Deck",0,476,1150,164,Color3.fromRGB(17,30,49),z+1)
	line(canvas,"HorizonRail",0,476,1150,476,5,Color3.fromRGB(71,104,126),z+1)
	for i=-2,8 do line(canvas,"DeckSeam",480,476,i*210,640,2,Color3.fromRGB(36,54,73),z+1) end
	for i=1,4 do line(canvas,"DeckCrossSeam",0,476+i*i*10,1150,476+i*i*10,2,Color3.fromRGB(36,54,73),z+1) end
	for _,x in ipairs({-20,1050}) do
		frame(canvas,"WindowRib",x,0,62,483,P.ink,z+2,x<0 and -9 or 9)
		frame(canvas,"RibInlay",x+26,20,5,396,P.steel,z+2,x<0 and -9 or 9)
	end
	frame(canvas,"Ceiling",0,0,1150,22,P.ink,z+2)
	line(canvas,"CeilingLight",72,24,1030,24,3,accent,z+2,0.5)
	-- A dimensional reactor is the visual signature, not another flat window.
	-- Eight armour segments, an inset ring, and a printed resource emblem.
	ellipse(canvas,"ReactorShadow",110,482,388,40,P.ink,z+2,0.05)
	frame(canvas,"ReactorFoot",182,443,252,35,P.steel,z+3)
	frame(canvas,"ReactorPlinth",150,474,316,18,P.ink,z+3)
	line(canvas,"PlinthLight",178,476,438,476,3,accent,z+4,0.2)
	ellipse(canvas,"PortalRim",127,112,360,360,P.ink,z+3)
	ellipse(canvas,"PortalSteel",139,124,336,336,P.steel,z+3)
	ellipse(canvas,"PortalAccent",151,136,312,312,accent,z+3)
	ellipse(canvas,"PortalWell",157,142,300,300,P.ink,z+3)
	gradient(ellipse(canvas,"PortalInterior",171,156,272,272,Color3.new(1,1,1),z+3),accent:Lerp(P.navy,0.68),P.navy,45)
	for i=0,7 do
		local a=math.rad(i*45)
		local x,y=307+math.cos(a)*171,292+math.sin(a)*171
		local plate=frame(canvas,"RingArmour",x,y,51,21,P.steel,z+4,i*45+90)
		plate.AnchorPoint=Vector2.new(0.5,0.5)
		line(canvas,"ArmourLight",x-9*math.sin(a),y+9*math.cos(a),x+9*math.sin(a),y-9*math.cos(a),3,accent,z+5)
	end
	for i=0,5 do
		local a=math.rad(i*60+15)
		line(canvas,"InnerCircuit",307+math.cos(a)*113,292+math.sin(a)*113,307+math.cos(a)*99,292+math.sin(a)*99,3,accent,z+4,0.3)
	end
	if mode=="gold" then
		-- An embossed coin, drawn as solid metal with an offset edge and mint mark.
		ellipse(canvas,"CoinEdge",241,228,146,146,Color3.fromRGB(151,89,26),z+5)
		ellipse(canvas,"CoinFace",229,216,146,146,P.gold,z+5)
		ellipse(canvas,"CoinInset",242,229,120,120,Color3.fromRGB(218,145,31),z+5)
		ellipse(canvas,"CoinCenter",248,235,108,108,Color3.fromRGB(255,200,64),z+5)
		line(canvas,"MintMark",312,256,295,321,13,Color3.fromRGB(157,95,21),z+6)
		line(canvas,"CoinShine",264,244,285,237,4,P.cream,z+6)
		for _,p in ipairs({{191,402},{399,380}}) do
			ellipse(canvas,"StoredCoin",p[1],p[2],46,17,Color3.fromRGB(174,113,31),z+4)
			ellipse(canvas,"StoredCoinTop",p[1],p[2]-5,46,17,P.gold,z+4)
		end
	else
		local color=mode=="xp" and Color3.fromRGB(138,219,255) or P.blue
		local gem=frame(canvas,"DimensionalCrystal",307,289,98,98,color,z+5,45)
		gem.AnchorPoint=Vector2.new(0.5,0.5)
		gradient(gem,P.cream,color:Lerp(P.violet,0.5),45)
		local inner=frame(canvas,"CrystalFacet",307,289,58,58,accent,z+6,45)
		inner.AnchorPoint=Vector2.new(0.5,0.5)
		line(canvas,"CrystalRidge",307,220,307,358,3,P.cream,z+7,0.25)
		for _,p in ipairs({{227,232},{394,333}}) do
			local shard=frame(canvas,"OrbitShard",p[1],p[2],17,17,color,z+5,45)
			shard.AnchorPoint=Vector2.new(0.5,0.5)
		end
	end
	-- Inks and small stars feel printed, rather than adding bloom to the world.
	for i=0,6 do line(canvas,"ComicAccent",70+i*14,538,90+i*14,524,2,accent,z+2,0.5) end
	for i=1,24 do ellipse(canvas,"Halftone",35+(i%8)*13,545+math.floor(i/8)*13,3,3,P.muted,z+2,0.8) end
	-- The quiet right side is reserved for the live information panel.
	local shade=make("Frame",root,{Name="ReadingShade",Position=UDim2.fromScale(0.47,0),Size=UDim2.fromScale(0.53,1),BackgroundColor3=P.ink,BackgroundTransparency=0.12,BorderSizePixel=0,Active=false,ZIndex=z+8})
	make("UIGradient",shade,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(0.4,0.12),NumberSequenceKeypoint.new(1,0)}),Rotation=0})
	return root
end

-- Both the early loader and the reconnect splash use this same composition.
-- The optional UI adapter applies the game's scale-aware text limits once it
-- exists; ReplicatedFirst itself never waits for the client or shared modules.
function ScreenArt.Loading(parent, T, size, UI)
	local w,h=size.X,size.Y
	local compact=w<600
	local root=make("Frame",parent,{Name="LoadingSplash",Size=UDim2.fromScale(1,1),BackgroundColor3=P.ink,BorderSizePixel=0,Active=true,ZIndex=80})
	local backdrop=ScreenArt.Draw(root,"loading",w,h+80,80)
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
	label("SplashKicker",T("MULTIVERSO / ÚLTIMA DEFESA","MULTIVERSE / LAST DEFENSE"),0,26,small and 14 or 17,P.gold,true)
	label("SplashTitle","DOOMSDAY",small and 30 or 32,small and 66 or 86,compact and 49 or (small and 48 or 68))
	label("SplashSubtitle",T("O próximo mundo precisa de você.","The next world needs you."),small and 100 or 122,36,small and 16 or 20,P.muted,true)
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
	label("SplashTip",T("DICA  •  O primeiro herói da equipe define seu poder na partida.","TIP  •  Your first equipped hero sets your power in battle."),height-48,48,small and 13 or 15,P.muted,true)
	local function step(elapsed,worldLoaded,ready,reduced)
		if not root.Parent then return end
		local phase=(ready and worldLoaded) and 3 or (worldLoaded and 2 or 1)
		status.Text=phase==3 and T("Tudo pronto. Vamos defender!","All set. Time to defend!") or (phase==2 and T("Conectando seu perfil…","Connecting your profile…") or T("Carregando o refúgio…","Loading the refuge…"))
		for i,item in ipairs(steps) do item.TextColor3=i<=phase and P.blue or P.muted end
		if phase==3 then slider.Position=UDim2.fromScale(0,0); slider.Size=UDim2.fromScale(1,1)
		else slider.Size=UDim2.fromScale(0.22,1); slider.Position=UDim2.fromScale(reduced and 0.39 or (0.78*((elapsed*0.38)%1)),0) end
	end
	step(0,false,false,false)
	return {root=root,Step=step}
end

return ScreenArt
