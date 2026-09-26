-- UI primitives shared by the lobby and match controller. No external assets required.
local UI = {}

-- Candy palette for a kids' game: saturated accents on deep navy, white
-- text with a black outline, and thick dark borders around everything.
UI.Colors = {
	background = Color3.fromRGB(22, 24, 36),
	panel = Color3.fromRGB(35, 39, 56),
	card = Color3.fromRGB(50, 55, 78),
	stroke = Color3.fromRGB(96, 106, 140),
	ink = Color3.fromRGB(12, 13, 20),
	text = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(190, 198, 222),
	green = Color3.fromRGB(88, 224, 79),
	gold = Color3.fromRGB(255, 210, 63),
	red = Color3.fromRGB(255, 77, 94),
	blue = Color3.fromRGB(63, 169, 255),
	coral = Color3.fromRGB(255, 138, 61),
	violet = Color3.fromRGB(169, 112, 255),
	pink = Color3.fromRGB(255, 111, 198),
	cream = Color3.fromRGB(255, 241, 204),
}

-- One bubbly display face for titles, numbers and buttons; Gotham stays for
-- small running text, where legibility matters more than personality.
UI.Fonts = { display = Enum.Font.FredokaOne, bold = Enum.Font.GothamBold, body = Enum.Font.Gotham }

UI.Themes = {
	guide = {color=UI.Colors.gold, icon="guide"}, maps = {color=UI.Colors.gold, icon="bolt"},
	inventory = {color=UI.Colors.coral, icon="hero"}, hero = {color=UI.Colors.coral, icon="hero"}, squad = {color=UI.Colors.coral, icon="hero"},
	talents = {color=UI.Colors.violet, icon="star"}, chests = {color=UI.Colors.gold, icon="chest"},
	premium = {color=UI.Colors.green, icon="shop"}, shop = {color=UI.Colors.green, icon="shop"},
	rewards = {color=UI.Colors.pink, icon="gift"}, modes = {color=UI.Colors.green, icon="bolt"},
	quests = {color=UI.Colors.coral, icon="star"}, leaderboard = {color=UI.Colors.gold, icon="trophy"},
	settings = {color=UI.Colors.blue, icon="bolt"}, bases={color=UI.Colors.green,icon="heart"},
}

function UI.create(className, properties, parent)
	local instance = Instance.new(className)
	for key, value in pairs(properties or {}) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

function UI.corner(parent, radius)
	return UI.create("UICorner", {CornerRadius = UDim.new(0, radius or 16)}, parent)
end

-- The border of a control. Named, so a text outline on the same object is
-- never mistaken for it, and selection states recolour this one border.
function UI.stroke(parent, color, thickness)
	local existing = parent:FindFirstChild("Border")
	if existing then
		existing.Color = color or UI.Colors.ink
		existing.Thickness = thickness or 1
		existing.Transparency = 0
		return existing
	end
	return UI.create("UIStroke", {Name = "Border", Color = color or UI.Colors.ink, Thickness = thickness or 1, Transparency = 0, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, LineJoinMode = Enum.LineJoinMode.Round}, parent)
end

-- The black outline around display text that every kids' game uses: it keeps
-- white words readable over any colour, sky or button.
function UI.outline(textObject, thickness)
	local existing = textObject:FindFirstChild("TextOutline")
	if existing then existing.Thickness = thickness or existing.Thickness; return existing end
	return UI.create("UIStroke", {Name = "TextOutline", Color = UI.Colors.ink, Thickness = thickness or 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual, LineJoinMode = Enum.LineJoinMode.Round}, textObject)
end

-- A vertical shade that makes a flat colour read as a rounded, lit object.
function UI.shade(parent, rotation, depth)
	local gradient = parent:FindFirstChildOfClass("UIGradient") or UI.create("UIGradient", {}, parent)
	local low = 1 - (depth or 0.16)
	gradient.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.new(low, low, low))
	gradient.Rotation = rotation or 90
	return gradient
end

function UI.frame(parent, properties)
	local defaults = {BackgroundColor3 = UI.Colors.panel, BorderSizePixel = 0}
	for key, value in pairs(properties or {}) do defaults[key] = value end
	return UI.create("Frame", defaults, parent)
end

-- Panels and cards: rounded, a thick dark border (or the caller's accent),
-- and a gentle top-lit shade.
function UI.roundFrame(parent, properties, color)
	local frame = UI.frame(parent, properties)
	UI.corner(frame, 16)
	UI.stroke(frame, color or UI.Colors.ink, color and 2 or 3)
	UI.shade(frame, 90, 0.1)
	return frame
end

local DISPLAY_FONTS = { [Enum.Font.GothamBlack] = true, [Enum.Font.FredokaOne] = true }

function UI.label(parent, text, properties)
	local defaults = {
		BackgroundTransparency = 1, BorderSizePixel = 0, Text = text,
		Font = UI.Fonts.body, TextColor3 = UI.Colors.text, TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Center,
		Size = UDim2.new(1, 0, 0, 24), TextTruncate = Enum.TextTruncate.AtEnd,
	}
	for key, value in pairs(properties or {}) do defaults[key] = value end
	-- Display text becomes the bubbly face with a black outline, unless it is
	-- dark text printed on a light surface (then an outline would smear it).
	local display = DISPLAY_FONTS[defaults.Font]
	if display then defaults.Font = UI.Fonts.display end
	local label = UI.create("TextLabel", defaults, parent)
	local color = defaults.TextColor3
	local bright = typeof(color) ~= "Color3" or (color.R + color.G + color.B) > 1.2
	if display and bright and (defaults.TextSize or 0) >= 12 then
		UI.outline(label, (defaults.TextSize or 15) >= 26 and 3 or ((defaults.TextSize or 15) >= 17 and 2 or 1.5))
	end
	return label
end

local function isDark(color)
	return typeof(color) == "Color3" and (color.R + color.G + color.B) < 0.75
end

-- Candy buttons: saturated fill, thick dark border, a glossy highlight on the
-- top half and white outlined text. Invisible hit areas stay invisible.
function UI.button(parent, text, callback, properties)
	local defaults = {
		BackgroundColor3 = UI.Colors.green, BorderSizePixel = 0, AutoButtonColor = true,
		Text = text, TextColor3 = UI.Colors.text, Font = UI.Fonts.display,
		TextSize = 15, Size = UDim2.new(0, 140, 0, 44), TextWrapped = true,
	}
	for key, value in pairs(properties or {}) do defaults[key] = value end
	local visible = (defaults.BackgroundTransparency or 0) < 1
	if visible then
		defaults.Font = (defaults.Font == Enum.Font.GothamBold or DISPLAY_FONTS[defaults.Font]) and UI.Fonts.display or defaults.Font
		-- Dark text on a colour was the old style; white-and-outline reads better.
		if isDark(defaults.TextColor3) and not isDark(defaults.BackgroundColor3) then defaults.TextColor3 = UI.Colors.text end
	end
	local button = UI.create("TextButton", defaults, parent)
	UI.corner(button, 12)
	if visible then
		UI.shade(button, 90, 0.26)
		UI.stroke(button, UI.Colors.ink, 3)
		local shine = UI.frame(button, {Name = "Shine", Position = UDim2.new(0, 6, 0, 4), Size = UDim2.new(1, -12, 0.36, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.78, Active = false, ZIndex = button.ZIndex})
		UI.corner(shine, 8)
		UI.outline(button, (defaults.TextSize or 15) >= 20 and 2.5 or 2)
	end
	if callback then button.Activated:Connect(callback) end
	-- Every button squashes under the finger and springs back: the smallest
	-- bit of feel, applied everywhere at once.
	local press = UI.create("UIScale", {Name = "PressScale", Scale = 1}, button)
	local function squash(target, seconds, style)
		local ok, tweens = pcall(game.GetService, game, "TweenService")
		if ok and tweens then
			tweens:Create(press, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Scale = target}):Play()
		else
			press.Scale = target
		end
	end
	button.MouseButton1Down:Connect(function() if button.Active ~= false then squash(0.9, 0.07) end end)
	button.MouseButton1Up:Connect(function() squash(1, 0.28, Enum.EasingStyle.Back) end)
	button.MouseEnter:Connect(function() if button.Active ~= false then squash(1.05, 0.12) end end)
	button.MouseLeave:Connect(function() squash(1, 0.15) end)
	return button
end

function UI.secondary(parent, text, callback, properties)
	properties = properties or {}
	properties.BackgroundColor3 = properties.BackgroundColor3 or UI.Colors.card
	properties.TextColor3 = properties.TextColor3 or UI.Colors.text
	return UI.button(parent, text, callback, properties)
end

function UI.disabled(button)
	button.Active = false
	button.AutoButtonColor = false
	button.BackgroundColor3 = Color3.fromRGB(92, 96, 112)
	button.TextColor3 = UI.Colors.muted
end

-- Friendly HUD symbols made from a handful of flat shapes. Every symbol is
-- decorative; its neighbouring text button remains the single tap target.
function UI.icon(parent, kind, tint, properties)
	local defaults = {Name = "Icon_" .. kind, BackgroundTransparency = 1, Size = UDim2.fromOffset(24, 24), Active = false}
	for key, value in pairs(properties or {}) do defaults[key] = value end
	local root = UI.frame(parent, defaults)
	tint = tint or UI.Colors.text
	local function shape(x, y, w, h, rotation, color, radius)
		local child = UI.frame(root, {Position = UDim2.fromScale(x, y), Size = UDim2.fromScale(w, h), Rotation = rotation or 0, BackgroundColor3 = color or tint, Active = false, ZIndex = root.ZIndex})
		if radius then UI.corner(child, radius) end
		return child
	end
	if kind == "hero" then
		shape(0.2, 0.67, 0.6, 0.26, 0, tint, 6)
		shape(0.3, 0.08, 0.4, 0.54, 0, tint, 8)
		shape(0.34, 0.3, 0.32, 0.12, 0, UI.Colors.background, 2)
		shape(0.47, 0.26, 0.06, 0.2)
	elseif kind == "star" then
		shape(0.32, 0.32, 0.36, 0.36, 45)
		for index = 0, 4 do
			local angle = math.rad(index * 72 - 90)
			shape(0.4 + math.cos(angle) * 0.23, 0.35 + math.sin(angle) * 0.23, 0.2, 0.3, index * 72, tint, 2)
		end
	elseif kind == "chest" then
		shape(0.12, 0.21, 0.76, 0.63, 0, tint, 5)
		shape(0.12, 0.45, 0.76, 0.07, 0, UI.Colors.background)
		shape(0.43, 0.4, 0.14, 0.25, 0, UI.Colors.background, 2)
		shape(0.47, 0.44, 0.06, 0.12)
	elseif kind == "shop" then
		shape(0.2, 0.35, 0.6, 0.55, 0, tint, 4)
		shape(0.32, 0.1, 0.36, 0.36, 0, tint, 8)
		shape(0.42, 0.18, 0.16, 0.16, 0, UI.Colors.background, 3)
		shape(0.43, 0.52, 0.14, 0.14, 45, UI.Colors.background)
	elseif kind == "heart" then
		shape(0.2, 0.17, 0.4, 0.42, 0, tint, 20)
		shape(0.4, 0.17, 0.4, 0.42, 0, tint, 20)
		shape(0.28, 0.35, 0.44, 0.44, 45, tint, 2)
	elseif kind == "trophy" then
		shape(0.26, 0.12, 0.48, 0.48, 0, tint, 5)
		shape(0.08, 0.2, 0.24, 0.3, -16, tint, 5)
		shape(0.68, 0.2, 0.24, 0.3, 16, tint, 5)
		shape(0.43, 0.52, 0.14, 0.23)
		shape(0.26, 0.76, 0.48, 0.13, 0, tint, 3)
	elseif kind == "gift" then
		shape(0.14, 0.42, 0.72, 0.46, 0, tint, 4)
		shape(0.08, 0.3, 0.84, 0.15, 0, tint, 3)
		shape(0.44, 0.3, 0.12, 0.58, 0, UI.Colors.background)
		shape(0.26, 0.12, 0.22, 0.22, -18, tint, 10)
		shape(0.52, 0.12, 0.22, 0.22, 18, tint, 10)
	else -- bolt
		shape(0.36, 0.08, 0.21, 0.49, 29)
		shape(0.3, 0.4, 0.41, 0.19, -4)
		shape(0.47, 0.47, 0.18, 0.44, 29)
	end
	return root
end

-- Small, authored colour illustrations. Built-in shapes stay sharp at every
-- resolution and need no uploaded image or external icon dependency.
function UI.illustration(parent, kind, tint, properties)
	local root=UI.frame(parent,{Name="Illustration_"..kind,BackgroundTransparency=1,Size=UDim2.fromOffset(44,44),Active=false})
	for k,v in pairs(properties or {}) do root[k]=v end
	local ink=Color3.fromRGB(34,42,43)
	local gold=Color3.fromRGB(247,195,83)
	local cream=Color3.fromRGB(255,239,192)
	local function shape(x,y,w,h,color,radius,rotation)
		local p=UI.frame(root,{Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),BackgroundColor3=color,Rotation=rotation or 0,Active=false,ZIndex=root.ZIndex})
		if radius then UI.corner(p,radius) end
		return p
	end
	if kind=="guide" then
		shape(.23,.52,.54,.40,Color3.fromRGB(68,122,106),7)
		shape(.17,.47,.66,.13,gold,2)
		shape(.64,.5,.12,.29,gold,2,-10)
		shape(.13,.12,.74,.40,cream,13)
		shape(.21,.23,.58,.17,ink,5)
		shape(.29,.27,.07,.08,Color3.fromRGB(146,232,186),2)
		shape(.64,.27,.07,.08,Color3.fromRGB(146,232,186),2)
		shape(.72,.02,.04,.14,cream,2)
		shape(.67,0,.14,.10,gold,7)
	elseif kind=="hero" then
		shape(.16,.65,.68,.29,ink,9)
		shape(.22,.67,.56,.19,tint,7)
		shape(.23,.05,.54,.68,ink,12)
		shape(.28,.09,.44,.55,Color3.fromRGB(202,77,56),10)
		shape(.34,.16,.32,.41,gold,8)
		shape(.32,.31,.15,.07,cream,2,-8)
		shape(.53,.31,.15,.07,cream,2,8)
		shape(.42,.51,.16,.04,ink,1)
		shape(.43,.71,.14,.14,cream,20)
	elseif kind=="star" then
		shape(.44,.29,.12,.56,tint,3)
		shape(.21,.42,.38,.065,tint,2,-32)
		shape(.47,.38,.34,.065,tint,2,32)
		shape(.36,.05,.28,.28,ink,8,45)
		shape(.40,.09,.20,.20,tint,6,45)
		for _,p in ipairs({{.09,.44},{.66,.39},{.37,.72}}) do
			shape(p[1],p[2],.24,.24,ink,20)
			shape(p[1]+.04,p[2]+.04,.16,.16,gold,20)
		end
	elseif kind=="chest" then
		shape(.08,.20,.84,.69,ink,8)
		shape(.13,.27,.74,.55,Color3.fromRGB(150,86,45),5)
		shape(.13,.28,.74,.19,Color3.fromRGB(207,133,64),5)
		shape(.22,.25,.10,.56,gold,2)
		shape(.68,.25,.10,.56,gold,2)
		shape(.13,.49,.74,.06,ink)
		shape(.40,.42,.20,.26,gold,4)
		shape(.47,.50,.06,.09,ink,3)
		shape(.20,.13,.12,.05,cream,2,35)
		shape(.73,.08,.06,.14,cream,2,30)
	elseif kind=="gift" then
		shape(.12,.34,.76,.57,ink,5)
		shape(.17,.40,.66,.45,tint,3)
		shape(.08,.28,.84,.19,ink,4)
		shape(.12,.31,.76,.11,tint,3)
		shape(.44,.32,.12,.53,cream,1)
		shape(.24,.10,.24,.20,cream,10,-22)
		shape(.52,.10,.24,.20,cream,10,22)
		shape(.44,.21,.12,.12,gold,8)
	elseif kind=="shop" or kind=="coin" then
		for i=0,(kind=="coin" and 0 or 2) do
			local x=kind=="coin" and .1 or .1+i*.19
			local y=kind=="coin" and .1 or .35-i*.12
			local size=kind=="coin" and .8 or .55
			shape(x,y,size,size,ink,30)
			shape(x+.04,y+.04,size-.08,size-.08,gold,30)
			shape(x+.09,y+.09,size-.18,size-.18,Color3.fromRGB(210,145,51),30)
			shape(x+size*.43,y+size*.25,size*.14,size*.48,cream,2,18)
		end
	else
		UI.icon(root,kind,tint,{Size=UDim2.fromScale(1,1)})
	end
	return root
end

-- Small clipped comic-print motifs; no textures to upload and no animated
-- particles on menus. Each panel gets one motif, never one per text label.
function UI.printTexture(parent, tint, properties)
	local root = UI.frame(parent, {Name="ComicPrint", BackgroundTransparency=1, Size=UDim2.fromScale(1,1), ClipsDescendants=true, Active=false})
	for key,value in pairs(properties or {}) do root[key]=value end
	for row=0,3 do
		for column=0,5 do
			local dot=UI.frame(root,{Name="InkDot",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-12-column*15,0,8+row*15),Size=UDim2.fromOffset(3+row,3+row),BackgroundColor3=tint,BackgroundTransparency=0.84,Active=false})
			UI.corner(dot,8)
		end
	end
	return root
end

function UI.ribbon(parent, tint, height)
	local band=UI.frame(parent,{Name="TitleRibbon",Position=UDim2.fromOffset(5,5),Size=UDim2.new(1,-10,0,height or 46),BackgroundColor3=UI.Colors.cream,ClipsDescendants=true,Active=false})
	UI.corner(band,10)
	UI.frame(band,{Name="SectionTab",Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(42,height or 46),BackgroundColor3=tint,Active=false})
	UI.frame(band,{Name="RibbonInk",Position=UDim2.new(0,48,1,-4),Size=UDim2.new(1,-105,0,2),BackgroundColor3=tint,BackgroundTransparency=0.15})
	return band
end

function UI.portraitStage(parent, tint, properties)
	local stage=UI.frame(parent,properties)
	stage.BackgroundColor3=tint:Lerp(UI.Colors.background,0.42)
	stage.ClipsDescendants=true
	UI.corner(stage,12)
	UI.shade(stage,45)
	local halo=UI.frame(stage,{Name="PortraitHalo",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.53),Size=UDim2.fromOffset(88,88),BackgroundColor3=tint,BackgroundTransparency=0.65})
	UI.corner(halo,100)
	UI.stroke(halo,tint,2).Transparency=0.55
	UI.printTexture(stage,UI.Colors.text)
	return stage
end

-- A miniature expedition vignette makes the mode screen a destination
-- selector, not a stack of identical text boxes.
-- Route previews come directly from the map catalog, so selecting a map
-- teaches its geometry instead of showing an unrelated landscape picture.
function UI.mapArt(parent,map,tint,properties)
	local root=UI.frame(parent,properties)
	root.Name="MapRoutePreview"
	root.BackgroundColor3=tint:Lerp(UI.Colors.background,0.85)
	UI.corner(root,8)
	root.ClipsDescendants=true
	if not map then
		UI.label(root,"?",{Size=UDim2.fromScale(1,1),TextSize=48,Font=Enum.Font.GothamBlack,TextColor3=tint,TextXAlignment=Enum.TextXAlignment.Center})
		return root
	end
	local function project(point) return 7+(point[1]+100)/200*82,7+(point[2]+100)/200*62 end
	for _,route in ipairs(map.paths) do
		for i=2,#route do
			local x1,y1=project(route[i-1]); local x2,y2=project(route[i])
			local dx,dy=x2-x1,y2-y1
			UI.frame(root,{Name="RouteSegment",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromOffset((x1+x2)/2,(y1+y2)/2),Size=UDim2.fromOffset(math.sqrt(dx*dx+dy*dy)+2,3),Rotation=math.deg(math.atan2(dy,dx)),BackgroundColor3=tint})
		end
		for _,index in ipairs({1,#route}) do
			local x,y=project(route[index])
			local dot=UI.frame(root,{Position=UDim2.fromOffset(x-3,y-3),Size=UDim2.fromOffset(6,6),BackgroundColor3=index==1 and UI.Colors.red or UI.Colors.cream})
			UI.corner(dot,3)
		end
	end
	return root
end

function UI.expeditionArt(parent, kind, tint, properties)
	local art=UI.frame(parent,properties)
	art.BackgroundColor3=tint:Lerp(UI.Colors.background,0.7)
	art.ClipsDescendants=true
	UI.corner(art,12)
	UI.shade(art,90)
	local function shape(x,y,w,h,color,angle,round)
		local p=UI.frame(art,{Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),BackgroundColor3=color,Rotation=angle or 0,Active=false})
		if round then UI.corner(p,round) end
		return p
	end
	shape(0.71,0.12,0.21,0.3,tint,0,60)
	for i=0,5 do
		local h=0.2+(i%3)*0.09
		shape(i*0.18,0.75-h,0.14,h,UI.Colors.background:Lerp(tint,0.13))
		shape(i*0.18+0.03,0.8-h,0.025,0.05,tint)
	end
	shape(-0.1,0.84,1.2,0.3,tint:Lerp(UI.Colors.background,0.72),-8)
	shape(0.34,0.7,0.34,0.06,tint,0,4)
	local portal=shape(0.35,0.19,0.32,0.54,UI.Colors.background,0,50)
	UI.stroke(portal,tint,3).Transparency=0
	UI.icon(portal,kind,tint,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromScale(0.62,0.62)})
	UI.printTexture(art,tint)
	return art
end

-- Small vector emblems stay crisp at any UI scale without asset downloads.
function UI.emblem(parent, kind, tint, properties)
	local root=UI.frame(parent,properties)
	root.BackgroundColor3=tint:Lerp(UI.Colors.background,0.78)
	UI.corner(root,12)
	UI.stroke(root,tint,1.5)
	local function shape(x,y,w,h,rotation,color,round)
		local f=UI.frame(root,{Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),Rotation=rotation or 0,BackgroundColor3=color or tint})
		if round then UI.corner(f,100) end
		return f
	end
	if kind=="fortune" then
		local coin=shape(0.2,0.2,0.6,0.6,0,tint,true)
		UI.stroke(coin,tint:Lerp(Color3.new(1,1,1),0.5),2)
		shape(0.45,0.3,0.1,0.4,0,UI.Colors.background)
	elseif kind=="guardian" then
		shape(0.25,0.23,0.5,0.4,0,tint)
		shape(0.32,0.39,0.36,0.36,45,tint)
		shape(0.45,0.28,0.1,0.38,0,UI.Colors.background)
		shape(0.33,0.4,0.34,0.1,0,UI.Colors.background)
	else
		shape(0.38,0.15,0.19,0.45,28,tint)
		shape(0.35,0.43,0.34,0.14,0,tint)
		shape(0.45,0.44,0.16,0.4,28,tint)
	end
	return root
end

function UI.list(parent, gap, horizontal)
	local layout=UI.create("UIListLayout", {
		Padding = UDim.new(0, gap or 10),
		FillDirection = horizontal and Enum.FillDirection.Horizontal or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
	}, parent)
	if parent:IsA("ScrollingFrame") then
		-- Only the list owns the canvas extent. AutomaticCanvasSize also
		-- measures nested/scaled decorations and can feed back into its size.
		parent.AutomaticCanvasSize=Enum.AutomaticSize.None
		local function resizeCanvas()
			if parent:GetAttribute("UpdatingCanvas") then return end
			local size=layout.AbsoluteContentSize
			parent.CanvasSize=horizontal and UDim2.fromOffset(math.ceil(size.X)+8,0) or UDim2.fromOffset(0,math.ceil(size.Y)+8)
		end
		layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(resizeCanvas)
	end
	return layout
end

function UI.finishScrollUpdate(frame)
	local layout=frame:FindFirstChildOfClass("UIListLayout")
	if not layout then return end
	-- Read after all rows exist; transient empty layouts must never shrink
	-- the canvas and clamp a player's scroll position back to zero.
	local size=layout.AbsoluteContentSize
	frame:SetAttribute("UpdatingCanvas",nil)
	if size then
		local horizontal=layout.FillDirection==Enum.FillDirection.Horizontal
		frame.CanvasSize=horizontal and UDim2.fromOffset(math.ceil(size.X)+8,0) or UDim2.fromOffset(0,math.ceil(size.Y)+8)
	end
end

function UI.padding(parent, value)
	return UI.create("UIPadding", {
		PaddingTop = UDim.new(0, value), PaddingBottom = UDim.new(0, value),
		PaddingLeft = UDim.new(0, value), PaddingRight = UDim.new(0, value),
	}, parent)
end

function UI.scroll(parent, properties)
	local defaults = {
		BackgroundTransparency = 1, BorderSizePixel = 0, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ScrollBarThickness = 6,
		ScrollBarImageColor3 = UI.Colors.blue, ScrollingDirection = Enum.ScrollingDirection.Y,
		Size = UDim2.fromScale(1, 1),
	}
	for key, value in pairs(properties or {}) do defaults[key] = value end
	return UI.create("ScrollingFrame", defaults, parent)
end

function UI.section(parent, title, subtitle)
	local frame = UI.frame(parent, {BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, subtitle and 100 or 48)})
	UI.label(frame, title, {Font = UI.Fonts.display, TextSize = 21, TextWrapped=true, TextTruncate=Enum.TextTruncate.None, Size = UDim2.new(1, 0, 0, 46)})
	if subtitle then
		UI.label(frame, subtitle, {TextColor3 = UI.Colors.muted, TextSize = 12, Position = UDim2.fromOffset(0, 48), Size = UDim2.new(1, 0, 0, 50), TextWrapped = true, TextTruncate = Enum.TextTruncate.None})
	end
	return frame
end

function UI.row(parent, height)
	return UI.frame(parent, {BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, height or 44)})
end

function UI.grid(parent, height, width)
	local frame = UI.frame(parent, {BackgroundTransparency = 1, Size = UDim2.new(1, -8, 0, 0), AutomaticSize = Enum.AutomaticSize.Y})
	UI.create("UIGridLayout", {CellPadding = UDim2.fromOffset(10, 10), CellSize = UDim2.fromOffset(width or 210, height), SortOrder = Enum.SortOrder.LayoutOrder}, frame)
	return frame
end

function UI.bar(parent, color, position, size)
	local base = UI.frame(parent, {BackgroundColor3 = UI.Colors.ink, Position = position, Size = size})
	UI.corner(base, 8)
	UI.stroke(base, UI.Colors.ink, 2)
	local fill = UI.frame(base, {BackgroundColor3 = color, Size = UDim2.fromScale(0, 1)})
	UI.corner(fill, 8)
	UI.shade(fill, 90, 0.3)
	return fill
end

-- A portrait is the game's own procedural model rendered by Roblox, never
-- an asset ID or a picture pretending to be a playable character. Copy only
-- authored geometry: no scripts, prompts, particles or world billboards enter
-- the UI. Store lightweight descriptors so a lobby teardown does not erase
-- the selected heroes' appearance before the battle HUD is built.
local portraitGeometry = {}
local portraitExcluded = {
	Plinth = true, Ring = true, PowerRing = true, LockShroud = true,
	Base = true, Range = true, UpgradeRing = true,
}

function UI.rememberHero(heroId, source)
	if portraitGeometry[heroId] then return true end
	if not source then return false end
	local parts, tagged = {}, false
	for _, child in ipairs(source:GetDescendants()) do
		if child:IsA("BasePart") and child:GetAttribute("HeroVisual") == true then tagged = true; break end
	end
	local torso = source:FindFirstChild("Suit", true)
	local origin = torso and torso.Position or Vector3.zero
	for _, child in ipairs(source:GetDescendants()) do
		if child:IsA("BasePart") and not portraitExcluded[child.Name] and (not tagged or child:GetAttribute("HeroVisual") == true) then
			local mesh=child:FindFirstChildOfClass("SpecialMesh")
			table.insert(parts, {
				class = child.ClassName, name = child.Name, size = child.Size,
				cf = CFrame.new(-origin) * child.CFrame, color = child.Color,
				material = child.Material, shape = child:IsA("Part") and child.Shape or nil,
				transparency = child.Transparency or 0,
				meshType=mesh and mesh.MeshType, meshScale=mesh and mesh.Scale,
			})
		end
	end
	if #parts == 0 then return false end
	portraitGeometry[heroId] = parts
	return true
end

function UI.heroModel(parent, heroId, source)
	UI.rememberHero(heroId, source)
	local model = UI.create("Model", {Name = heroId}, parent)
	for _, descriptor in ipairs(portraitGeometry[heroId] or {}) do
		local properties = {
			Name = descriptor.name, Size = descriptor.size, CFrame = descriptor.cf,
			Color = descriptor.color, Material = descriptor.material, Transparency = descriptor.transparency,
			Anchored = true, CanCollide = false, CanTouch = false, CanQuery = false, CastShadow = false,
		}
		if descriptor.shape then properties.Shape = descriptor.shape end
		local rendered=UI.create(descriptor.class, properties, model)
		if descriptor.meshType then UI.create("SpecialMesh",{MeshType=descriptor.meshType,Scale=descriptor.meshScale},rendered) end
	end
	return model
end

function UI.heroPortrait(parent, heroId, source, tint, properties)
	local defaults = {
		Name = "Portrait_" .. heroId, Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tint:Lerp(UI.Colors.background, 0.8), BorderSizePixel = 0,
		Ambient = Color3.fromRGB(195, 207, 224), LightColor = Color3.fromRGB(255, 245, 228),
		LightDirection = Vector3.new(-1, -0.6, -1), BackgroundTransparency = 0.05,
	}
	for key, value in pairs(properties or {}) do defaults[key] = value end
	local viewportFrame = UI.create("ViewportFrame", defaults, parent)
	UI.corner(viewportFrame, 8)
	local world = UI.create("WorldModel", {Name = "HeroPreview"}, viewportFrame)
	local model = UI.heroModel(world, heroId, source)
	local frame, bounds = model:GetBoundingBox()
	local focus = frame.Position + Vector3.new(0, bounds.Y * 0.06, 0)
	local span = math.max(bounds.Y, bounds.X * 0.9, 5)
	local camera = UI.create("Camera", {Name = "PortraitCamera", FieldOfView = 32}, viewportFrame)
	-- Characters face -Z. A mild three-quarter angle keeps their emblems,
	-- weapons and silhouette readable even in the small quickbar slots.
	camera.CFrame = CFrame.lookAt(focus + Vector3.new(span * 0.44, span * 0.12, -span * 1.95), focus)
	viewportFrame.CurrentCamera = camera
	return viewportFrame
end

function UI.color(value)
	if typeof(value) == "Color3" then return value end
	if type(value) == "table" then
		local r, g, b = value[1] or value.r or 111, value[2] or value.g or 247, value[3] or value.b or 167
		return Color3.fromRGB(r, g, b)
	end
	return UI.Colors.green
end

-- Shared by collection controls: search accepts names with or without accents,
-- and ties always resolve to the catalog order so live updates don't shuffle it.
function UI.searchKey(value)
	local text=string.lower(tostring(value or ""))
	for _,pair in ipairs({{"á","a"},{"à","a"},{"â","a"},{"ã","a"},{"é","e"},{"ê","e"},{"í","i"},{"ó","o"},{"ô","o"},{"õ","o"},{"ú","u"},{"ç","c"},{"Á","a"},{"À","a"},{"Â","a"},{"Ã","a"},{"É","e"},{"Ê","e"},{"Í","i"},{"Ó","o"},{"Ô","o"},{"Õ","o"},{"Ú","u"},{"Ç","c"}}) do
		text=string.gsub(text,pair[1],pair[2])
	end
	return (text:gsub("^%s+",""):gsub("%s+$",""))
end

function UI.collectionEntries(catalog,profile,options,language)
	local entries,indexes={},{}
	local query=UI.searchKey(options.query)
	for index,id in ipairs(catalog.HeroOrder) do
		indexes[id]=index
		local def=catalog.Heroes[id]
		local owned=(profile.heroes or {})[id]
		local searchable=UI.searchKey(id.." "..def.name.pt.." "..def.name.en.." "..def.role.pt.." "..def.role.en)
		if (options.ownership=="all" or owned) and (options.rarity=="all" or options.rarity==def.rarity)
			and (query=="" or string.find(searchable,query,1,true)) then table.insert(entries,id) end
	end
	local function key(id)
		local def=catalog.Heroes[id]
		if options.sort=="name" then return UI.searchKey(def.name[language] or def.name.pt) end
		if options.sort=="rarity" then return -(table.find(catalog.RarityOrder,def.rarity) or 0) end
		if options.sort=="level" then return -((profile.heroes or {})[id] and profile.heroes[id].level or 0) end
		if options.sort=="cost" then return def.cost end
		return indexes[id]
	end
	table.sort(entries,function(a,b) local x,y=key(a),key(b); if x==y then return indexes[a]<indexes[b] end; return x<y end)
	return entries
end

-- Every HUD below is laid out from the real usable screen size, in pixels.
-- Roblox runs phones in landscape by default (StarterGui.ScreenOrientation is
-- LandscapeSensor), so "short" — a phone on its side, 300-ish pixels tall
-- once the topbar is taken out — is the mobile case that actually ships.
-- "narrow" only happens if the experience opts into portrait.
function UI.sizeClass(width, height)
	width, height = tonumber(width) or 1280, tonumber(height) or 720
	local narrow, short = width < 560, height < 520
	return { narrow = narrow, short = short, compact = narrow or short or width < 820 }
end

local function rect(x, y, w, h)
	return { x = math.floor(x), y = math.floor(y), w = math.max(0, math.floor(w)), h = math.max(0, math.floor(h)) }
end

-- Heights the tower panel's content actually needs in each arrangement.
UI.TOWER_TALL_HEIGHT = 226
UI.TOWER_WIDE_HEIGHT = 132

local function clampScreen(width, height)
	return math.max(320, math.floor(tonumber(width) or 1280)), math.max(280, math.floor(tonumber(height) or 720))
end

-- The match HUD, in absolute pixels of the usable screen. On tall screens the
-- tower panel lives below the boss banner; on a landscape phone there is no
-- "below", so the right edge becomes a column shared by the tower panel and
-- the placement bar (never shown together) while banners use what is left.
function UI.matchLayout(width, height, options)
	width, height = clampScreen(width, height)
	options = options or {}
	local class = UI.sizeClass(width, height)
	local pad, gap = 12, 6
	local layout = { class = class, width = width, height = height }

	local topH = class.narrow and 90 or (class.short and 46 or 64)
	local top = rect(pad, 8, width - 2 * pad, topH)
	layout.top = top
	local inner = top.w - 24
	local leftW = math.floor(inner * 0.52)
	local rightW = inner - leftW - 8
	local rightX = top.x + 12 + leftW + 8
	layout.wave = rect(top.x + 12, top.y + 4, leftW, class.short and 20 or 26)
	layout.map = rect(top.x + 12, top.y + (class.short and 26 or 32), leftW, class.narrow and 40 or (class.short and 16 or 20))
	layout.hpText = rect(rightX, top.y + 4, rightW, class.short and 18 or 22)
	layout.hpBar = rect(rightX + math.floor(rightW * 0.1), top.y + (class.short and 30 or 36), rightW - math.floor(rightW * 0.1), 7)

	local statusY = top.y + topH + gap
	local statusH
	if class.narrow then
		-- Portrait: gold and energy become the top bar's third row.
		local half = math.floor(inner / 2)
		layout.gold = rect(top.x + 12, top.y + 60, half - 4, 24)
		layout.energy = rect(top.x + 12 + half + 4, top.y + 60, inner - half - 4, 24)
		statusH = 34
		layout.waveInfo = rect(pad, statusY, width - 2 * pad, statusH)
	else
		statusH = class.short and 26 or 30
		local energyW = class.compact and 170 or 230
		local goldW = class.compact and 150 or 190
		layout.energy = rect(pad + 4, statusY, energyW, statusH)
		layout.gold = rect(width - pad - 4 - goldW, statusY, goldW, statusH)
		local infoX = layout.energy.x + energyW + gap
		layout.waveInfo = rect(infoX, statusY, layout.gold.x - gap - infoX, statusH)
	end
	local bannerY = statusY + statusH + gap

	-- A commander fights with exactly one ability: the slot-one hero's.
	local count = math.clamp(math.floor(tonumber(options.skills) or 1), 0, 1)
	local small = class.short or class.narrow
	local skillW = small and 124 or (class.compact and 144 or 190)
	local saluteW = small and 78 or 96
	-- Speed (1x/2x) and auto-skip ride in the same band as the ability: they
	-- are pressed often, so they get thumb height and sit where the hand is.
	local controlW = small and 52 or 64
	local abilitiesW = count * skillW + math.max(0, count - 1) * 8
	if options.vip then abilitiesW += (count > 0 and 8 or 0) + saluteW end
	abilitiesW += (abilitiesW > 0 and 8 or 0) + 2 * controlW + 8
	layout.controlW = controlW
	local buttonH = 48
	local bandH = class.compact and 64 or 86
	local bandY = height - 8 - bandH
	layout.buttonH, layout.skillW, layout.saluteW = buttonH, skillW, saluteW
	layout.cardW = class.compact and 110 or 143
	if class.short then
		-- One bottom band: hero cards scroll on the left, abilities fixed on the
		-- right. A phone on its side has width to spare and no height at all.
		layout.abilities = rect(width - pad - abilitiesW, bandY + math.floor((bandH - buttonH) / 2), abilitiesW, buttonH)
		layout.heroCards = rect(pad, bandY, width - 2 * pad - abilitiesW - (abilitiesW > 0 and 8 or 0), bandH)
		layout.actionTop = bandY
	else
		local cardsW = math.min(775, width - 2 * pad)
		layout.heroCards = rect(math.floor((width - cardsW) / 2), bandY, cardsW, bandH)
		layout.actionTop = bandY - 8 - buttonH
		layout.abilities = rect(pad, layout.actionTop, abilitiesW, buttonH)
	end
	-- Use spare quickbar width for readable names and portraits. Only scroll
	-- when five comfortable cards cannot fit, as on a landscape phone.
	layout.cardW = math.max(layout.cardW, math.min(160, math.floor((layout.heroCards.w - 42) / 5)))

	-- Every control a thumb must hit on a phone is at least 48 x 48 pixels.
	local placementH, hintH = 60, 40
	local bossH = class.short and 60 or 76
	if class.short then
		local columnW = math.min(300, width - 2 * pad - 220)
		local columnX = width - pad - columnW
		local columnBottom = bandY - gap
		local area = columnX - gap - pad
		local skipW = math.min(208, area)
		local bossW = math.min(560, area)
		layout.skip = rect(pad + math.floor((area - skipW) / 2), bannerY, skipW, 48)
		layout.boss = rect(pad + math.floor((area - bossW) / 2), bannerY, bossW, bossH)
		layout.placement = rect(columnX, columnBottom - placementH, columnW, placementH)
		layout.hint = rect(columnX, layout.placement.y - 4 - hintH, columnW, hintH)
		layout.tower = rect(columnX, bannerY, columnW, math.min(UI.TOWER_WIDE_HEIGHT, columnBottom - bannerY))
		layout.towerVariant = "wide"
	else
		local skipW = math.min(208, width - 2 * pad)
		local bossW = math.min(560, width - 2 * pad)
		layout.skip = rect(math.floor((width - skipW) / 2), bannerY, skipW, 48)
		layout.boss = rect(math.floor((width - bossW) / 2), bannerY, bossW, bossH)
		local placementW = math.min(430, width - 2 * pad)
		if abilitiesW == 0 or pad + abilitiesW + 12 + placementW <= width - pad then
			layout.placement = rect(width - pad - placementW, layout.actionTop + buttonH - placementH, placementW, placementH)
		else
			layout.placement = rect(math.floor((width - placementW) / 2), layout.actionTop - 8 - placementH, placementW, placementH)
		end
		layout.hint = rect(layout.placement.x, layout.placement.y - 4 - hintH, layout.placement.w, hintH)
		local towerTop = bannerY + bossH + gap
		local towerBottom = layout.actionTop - gap
		local tall = towerBottom - towerTop >= UI.TOWER_TALL_HEIGHT
		local towerW = tall and math.min(292, width - 2 * pad) or math.min(420, width - 2 * pad)
		local towerH = tall and UI.TOWER_TALL_HEIGHT or math.min(UI.TOWER_WIDE_HEIGHT, towerBottom - towerTop)
		layout.tower = rect(width - pad - towerW, towerBottom - towerH, towerW, towerH)
		layout.towerVariant = tall and "tall" or "wide"
	end
	return layout
end

-- The battle-protocol chooser. Stacked cards need a tall screen; a landscape
-- phone gets three side-by-side cards sized to whatever height it has, so
-- every CHOOSE button stays on screen.
function UI.protocolLayout(width, height)
	width, height = clampScreen(width, height)
	local class = UI.sizeClass(width, height)
	local stacked = class.narrow and height >= 480
	local panelW = math.min(960, width - 36)
	local headerH = 78
	local panelH
	if stacked then
		panelH = math.min(height - 24, headerH + 3 * 142 + 2 * 10 + 14)
	else
		panelH = math.min(332, height - 24)
	end
	local panel = rect(math.floor((width - panelW) / 2), math.floor((height - panelH) / 2), panelW, panelH)
	local cards, buttons, descriptions = {}, {}, {}
	for index = 1, 3 do
		local card
		if stacked then
			local cardH = math.floor((panelH - headerH - 14 - 20) / 3)
			card = rect(panel.x + 14, panel.y + headerH + (index - 1) * (cardH + 10), panelW - 28, cardH)
		else
			local cardW = math.floor((panelW - 28 - 2 * 12) / 3)
			card = rect(panel.x + 14 + (index - 1) * (cardW + 12), panel.y + headerH, cardW, panelH - headerH - 14)
		end
		cards[index] = card
		buttons[index] = rect(card.x + 10, card.y + card.h - 54, card.w - 20, 48)
		descriptions[index] = rect(card.x + 12, card.y + 34, card.w - 24, card.h - 34 - 58)
	end
	return { class = class, stacked = stacked, panel = panel, headerH = headerH, cards = cards, buttons = buttons, descriptions = descriptions }
end

-- Small counters above and an illustrated dock below leave the arrival view
-- clear. A boarding card sits above the dock, except on short phones where
-- it temporarily replaces the dock to preserve room for contextual sheets.
function UI.lobbyLayout(width, height)
	width, height = clampScreen(width, height)
	local class = UI.sizeClass(width, height)
	local pad = class.compact and 10 or 14
	local rowH = 48
	local buttonW = class.compact and 78 or 100
	local settings = rect(width - pad - buttonW, pad, buttonW, rowH)
	local squad = rect(settings.x - 8 - buttonW, pad, buttonW, rowH)
	-- The pill never reaches the buttons, however narrow the screen.
	local pill = rect(pad, pad, math.min(class.compact and 160 or 228, squad.x - 8 - pad), rowH)
	local navigationW = math.min(class.short and 470 or 510, width - 2 * pad)
	local navigationH = class.short and 54 or class.compact and 68 or 82
	local navigation = rect(math.floor((width - navigationW) / 2), height - pad - navigationH, navigationW, navigationH)
	local cardW = math.min(460, width - 2 * pad)
	local cardH = class.short and 84 or 96
	local elevator = rect(math.floor((width - cardW) / 2), (class.short and height - pad or navigation.y - 8) - cardH, cardW, cardH)
	local hintW = math.min(520, width - 2 * pad)
	local hint = rect(math.floor((width - hintW) / 2), navigation.y - 48, hintW, 40)
	local contextW = math.min(560, width - 2 * pad)
	-- The context panel is a sheet on landscape phones. Hiding corner chrome
	-- there makes enough room for the close control and scrollable content.
	local contextTop = class.short and pad or pad + rowH + 8
	local function contextAbove(bottom)
		local h = math.min(class.compact and 330 or 400, bottom - contextTop)
		return rect(math.floor((width - contextW) / 2), bottom - h, contextW, h)
	end
	-- The side quest tracker needs a wide, tall screen; phones keep the view clear.
	local tracker
	if not class.compact and not class.short then
		local trackerW, trackerY = 240, settings.y + rowH + 16
		local trackerH = math.min(28 + 3 * 56, hint.y - 12 - trackerY)
		if trackerH >= 84 then tracker = rect(width - pad - trackerW, trackerY, trackerW, trackerH) end
	end
	return {
		class = class, pill = pill, squad = squad, settings = settings, navigation = navigation,
		elevator = elevator, hint = hint, tracker = tracker,
		context = contextAbove(navigation.y - 8),
		contextRiding = contextAbove(elevator.y - 8),
	}
end

-- One source of truth for every lobby panel, including the wide talent tree.
-- Controllers hide the corner HUD/navigation while a modal sheet is open;
-- the elevator remains visible and tappable below it when the player boards.
function UI.contextLayout(width, height, options)
	width, height = clampScreen(width, height)
	options = options or {}
	local hud = UI.lobbyLayout(width, height)
	local pad = hud.class.compact and 10 or 14
	local modal = hud.class.short
	local top = modal and pad or hud.pill.y + hud.pill.h + 8
	local bottom = options.elevator and hud.elevator.y - 8 or modal and height - pad or hud.navigation.y - 8
	local maxWidth = options.wide and 900 or 690
	local panelWidth = math.min(maxWidth, width - 2 * pad)
	local slot = rect(math.floor((width - panelWidth) / 2), top, panelWidth, bottom - top)
	slot.modal = modal
	slot.class = hud.class
	return slot
end

function UI.format(number)
	local n = math.floor(tonumber(number) or 0)
	local sign = n < 0 and "-" or ""
	local digits = tostring(math.abs(n))
	local formatted = digits:reverse():gsub("(%d%d%d)", "%1."):reverse():gsub("^%.", "")
	return sign .. formatted
end

function UI.clear(parent)
	for _, child in ipairs(parent:GetChildren()) do
		if not child:IsA("UIComponent") then child:Destroy() end
	end
end

function UI.basePortrait(parent, def, properties)
	local root=UI.frame(parent,properties)
	root.BackgroundTransparency=1
	local tint=UI.color(def.color)
	local function block(x,y,w,h,color,radius)
		local f=UI.frame(root,{Position=UDim2.fromScale(x,y),Size=UDim2.fromScale(w,h),BackgroundColor3=color,ZIndex=root.ZIndex})
		UI.corner(f,radius or 3); return f
	end
	block(0.06,0.79,0.88,0.15,UI.Colors.background,8)
	block(0.12,0.74,0.76,0.1,tint,6)
	block(0.22,0.36,0.56,0.39,tint:Lerp(UI.Colors.background,0.35),5)
	block(0.16,0.28,0.68,0.13,tint,6)
	for n=0,2 do block(0.29+n*0.16,0.46,0.09,0.12,UI.Colors.cream,2) end
	if def.style=="farm" then
		for n=0,3 do
			block(0.14+n*0.19,0.68,0.13,0.13,UI.Colors.coral)
			block(0.17+n*0.19,0.52,0.07,0.18,UI.Colors.green,10)
		end
	elseif def.style=="wall" then
		for n=0,3 do block(0.07+n*0.23,0.57,0.18,0.28,tint:Lerp(UI.Colors.cream,0.25),3) end
	elseif def.style=="turret" then
		block(0.36,0.12,0.26,0.22,UI.Colors.stroke,5)
		block(0.42,0.06,0.12,0.17,UI.Colors.gold,3)
	elseif def.style=="soldiers" then
		block(0.4,0.57,0.2,0.22,UI.Colors.background)
		block(0.77,0.13,0.03,0.59,UI.Colors.cream)
		block(0.79,0.13,0.19,0.19,UI.Colors.coral)
	end
	return root
end

return UI
