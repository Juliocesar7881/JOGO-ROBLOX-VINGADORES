-- UI primitives shared by the lobby and match controller. No external assets required.
local UI = {}

-- Candy palette for a kids' game: saturated accents on deep slate (the
-- reference games' dark windows), white text with a black outline, and thick
-- dark borders around everything.
UI.Colors = {
	background = Color3.fromRGB(22, 24, 42),
	panel = Color3.fromRGB(36, 40, 68),
	card = Color3.fromRGB(52, 58, 96),
	stroke = Color3.fromRGB(128, 158, 238),
	ink = Color3.fromRGB(11, 15, 36),
	text = Color3.fromRGB(255, 255, 255),
	muted = Color3.fromRGB(206, 218, 255),
	green = Color3.fromRGB(88, 224, 79),
	gold = Color3.fromRGB(255, 210, 63),
	red = Color3.fromRGB(255, 77, 94),
	blue = Color3.fromRGB(63, 169, 255),
	coral = Color3.fromRGB(255, 138, 61),
	violet = Color3.fromRGB(169, 112, 255),
	pink = Color3.fromRGB(255, 111, 198),
	cream = Color3.fromRGB(255, 241, 204),
}

-- The top Roblox games' look (the owner's two reference recordings): one round,
-- chunky display face for titles, numbers and buttons, outlined in black; a
-- clean modern sans (Builder Sans, Roblox's own) for running text.
UI.Fonts = { display = Enum.Font.FredokaOne, bold = Enum.Font.BuilderSansExtraBold, body = Enum.Font.BuilderSansBold }

-- The window skin of those games: dark bodies, a colour frame, slots a shade
-- darker, and text in white on everything.
UI.Skin = {
	body = Color3.fromRGB(30, 32, 50),
	bodyTop = Color3.fromRGB(42, 46, 74),
	slot = Color3.fromRGB(20, 22, 36),
	slotLine = Color3.fromRGB(64, 70, 104),
	tooltip = Color3.fromRGB(14, 15, 24),
}

UI.Themes = {
	guide = {color=UI.Colors.gold, icon="guide"}, maps = {color=UI.Colors.gold, icon="bolt"},
	inventory = {color=UI.Colors.coral, icon="hero"}, hero = {color=UI.Colors.coral, icon="hero"}, squad = {color=UI.Colors.coral, icon="hero"},
	talents = {color=UI.Colors.violet, icon="star"}, chests = {color=UI.Colors.gold, icon="chest"},
	premium = {color=UI.Colors.green, icon="shop"}, shop = {color=UI.Colors.green, icon="shop"},
	rewards = {color=UI.Colors.pink, icon="gift"}, modes = {color=UI.Colors.green, icon="bolt"},
	quests = {color=UI.Colors.coral, icon="star"}, leaderboard = {color=UI.Colors.gold, icon="trophy"},
	settings = {color=UI.Colors.blue, icon="bolt"}, bases={color=UI.Colors.green,icon="heart"},
}

-- Pixel-sized world labels (BillboardGui) grow with the screen like the HUD:
-- their size and every text inside follow UI.screenScale. Call once, after the
-- contents exist.
function UI.scaleBillboard(gui)
	local scale = UI.screenScale or 1
	if scale <= 1.01 or not gui then return gui end
	local size = gui.Size
	if size.X.Scale == 0 and size.Y.Scale == 0 then
		gui.Size = UDim2.fromOffset(math.floor(size.X.Offset * scale), math.floor(size.Y.Offset * scale))
	end
	for _, item in ipairs(gui:GetDescendants()) do
		if item:IsA("TextLabel") or item:IsA("TextButton") then item.TextSize = math.floor(item.TextSize * scale) end
		if item:IsA("UIStroke") then item.Thickness = item.Thickness * math.min(scale, 1.6) end
	end
	return gui
end

-- The HUD is drawn on a scaled canvas (init.client sets this): the sizes and
-- positions Roblox reports (AbsoluteSize, AbsolutePosition, WorldToScreenPoint)
-- are real pixels, while every Position/Size offset is a logical pixel.
UI.screenScale = 1
function UI.toLogical(value)
	local scale = UI.screenScale or 1
	if type(value) == "number" then return value / scale end
	if value == nil then return nil end
	return Vector2.new(value.X / scale, value.Y / scale)
end

-- Text that shrinks to fit (TextScaled) is measured after the screen scale,
-- in real pixels: a UITextSizeConstraint's limits do not grow with UIScale the
-- way TextSize does, so a limit written as 21 drew 21-pixel letters on a
-- monitor where every other 21 is 34. Every such limit is made here, in
-- logical pixels, and converted with the scale in force; UI.rescaleTextLimits
-- converts them again when the scale changes.
local function realTextSize(value)
	return math.clamp(math.floor((tonumber(value) or 1) * (UI.screenScale or 1) + 0.5), 1, 100)
end
function UI.setTextLimit(constraint, maxSize, minSize)
	minSize = math.min(minSize or 1, maxSize)
	constraint:SetAttribute("LogicalMax", maxSize)
	constraint:SetAttribute("LogicalMin", minSize)
	constraint.MaxTextSize, constraint.MinTextSize = realTextSize(maxSize), realTextSize(minSize)
	return constraint
end
function UI.textLimit(target, maxSize, minSize, name)
	local constraint = UI.create("UITextSizeConstraint", {Name = name or "TextLimit"}, target)
	return UI.setTextLimit(constraint, maxSize, minSize)
end
function UI.rescaleTextLimits(root)
	if not root then return end
	for _, item in ipairs(root:GetDescendants()) do
		if item:IsA("UITextSizeConstraint") then
			local maxSize = item:GetAttribute("LogicalMax")
			if maxSize then item.MaxTextSize, item.MinTextSize = realTextSize(maxSize), realTextSize(item:GetAttribute("LogicalMin") or 1) end
		end
	end
end

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

function UI.candy(parent)
	local gradient = parent:FindFirstChildOfClass("UIGradient") or UI.create("UIGradient", {}, parent)
	local function key(t, v) return ColorSequenceKeypoint.new(t, Color3.new(v, v, v)) end
	gradient.Color = ColorSequence.new({ key(0, 1), key(0.5, 0.94), key(0.76, 0.86), key(0.79, 0.62), key(1, 0.56) })
	gradient.Rotation = 90
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
	UI.corner(frame, 18)
	UI.stroke(frame, color or UI.Colors.ink, color and 2.5 or 3)
	UI.shade(frame, 90, 0.18)
	return frame
end

local DISPLAY_FONTS = { [Enum.Font.GothamBlack] = true, [Enum.Font.FredokaOne] = true, [Enum.Font.LuckiestGuy] = true }
local TEXT_FONTS = { [Enum.Font.Gotham] = "body", [Enum.Font.GothamMedium] = "body", [Enum.Font.GothamSemibold] = "bold", [Enum.Font.GothamBold] = "bold", [Enum.Font.SourceSans] = "body", [Enum.Font.SourceSansBold] = "bold" }

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
	if display then defaults.Font = UI.Fonts.display elseif TEXT_FONTS[defaults.Font] then defaults.Font = UI.Fonts[TEXT_FONTS[defaults.Font]] end
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

-- The reference games' button texture: two rows of small raised squares
-- (studs) across the face, faint, behind the words. Drawn from flat frames,
-- clipped to the button, so it needs no image asset.
-- Kept to a few dozen frames per button: panels are rebuilt on every refresh.
local STUD_COLUMNS = 9
function UI.studs(host, height, width, z)
	local rows = height >= 46 and 2 or 1
	local size = math.clamp(math.floor(height * 0.2), 5, 11)
	local columns = width and math.clamp(math.floor(width / (size * 3.4)), 2, 9) or STUD_COLUMNS
	local layer = UI.frame(host, {Name = "Studs", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, Active = false, ZIndex = z})
	UI.corner(layer, 12)
	for row = 1, rows do
		local y = rows == 1 and 0.5 or (row == 1 and 0.3 or 0.72)
		for column = 1, columns do
			UI.frame(layer, {Name = "Stud", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new((column - 0.5) / columns, 0, y, 0),
				Size = UDim2.fromOffset(size, size), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.87, Active = false, ZIndex = z})
		end
	end
	return layer
end

-- The words of a textured button live in a child label above its studs; the
-- button keeps its Text (what tests, readers and other code look for) and
-- every later change to it is copied across.
local CAPTION_PROPERTIES = { "Text", "TextColor3", "TextSize", "Font", "TextXAlignment", "TextYAlignment", "TextScaled", "TextWrapped", "RichText", "TextTruncate", "LineHeight" }
local CAPTION_MIRROR = {}
for _, name in ipairs(CAPTION_PROPERTIES) do CAPTION_MIRROR[name] = true end

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
	UI.corner(button, 14)
	if visible then
		UI.candy(button)
		UI.stroke(button, UI.Colors.ink, 3)
		-- A thin gloss along the top edge: it draws over the button's own text,
		-- so it must stay above the letters, never across them.
		local shine = UI.frame(button, {Name = "Shine", Position = UDim2.new(0, 7, 0, 3), Size = UDim2.new(1, -14, 0.18, 0), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.84, Active = false, ZIndex = button.ZIndex})
		UI.corner(shine, 8)
		-- A thin light rim just inside the dark border: the raised, glossy edge.
		local bevel = UI.frame(button, {Name = "Bevel", Position = UDim2.fromOffset(2, 2), Size = UDim2.new(1, -4, 1, -4), BackgroundTransparency = 1, Active = false, ZIndex = button.ZIndex})
		UI.corner(bevel, 12)
		UI.create("UIStroke", {Name = "BevelLine", Color = Color3.new(1, 1, 1), Thickness = 1.5, Transparency = 0.62, ApplyStrokeMode = Enum.ApplyStrokeMode.Border}, bevel)
		local size = defaults.Size
		local function offsetOf(axis)
			local ok, value = pcall(function() return size[axis].Scale == 0 and size[axis].Offset or nil end)
			return ok and value or nil
		end
		local height, width = offsetOf("Y") or 44, offsetOf("X")
		if text ~= "" and height >= 30 then
			-- Studs behind the words, the words in a caption on top.
			UI.studs(button, height, width, button.ZIndex)
			local caption = UI.create("TextLabel", {Name = "Caption", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Active = false, ZIndex = button.ZIndex}, button)
			for _, name in ipairs(CAPTION_PROPERTIES) do pcall(function() caption[name] = button[name] end) end
			UI.create("UIPadding", {PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6)}, caption)
			UI.outline(caption, (defaults.TextSize or 15) >= 18 and 3 or 2)
			-- The words shrink to fit a narrow button (a phone, a long language)
			-- instead of spilling out of it, never past the size they were given.
			caption.TextScaled = true
			local fit = UI.textLimit(caption, button.TextSize, 10, "CaptionFit")
			button.TextTransparency = 1
			button.Changed:Connect(function(property)
				if property == "TextScaled" then return end
				if property == "TextSize" then UI.setTextLimit(fit, button.TextSize, 10) end
				if CAPTION_MIRROR[property] then pcall(function() caption[property] = button[property] end) end
			end)
		else
			UI.outline(button, (defaults.TextSize or 15) >= 18 and 3 or 2)
		end
	end
	if callback then button.Activated:Connect(callback) end
	-- Every press clicks (the controller wires UI.onPress to its audio).
	button.Activated:Connect(function() if UI.onPress then pcall(UI.onPress, button) end end)
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

-- Shrinks a label's words to fit its box (a narrow window, a long name),
-- never past the size it was given and never below minSize.
function UI.fit(label, minSize)
	label.TextScaled = true
	UI.textLimit(label, label.TextSize, minSize or 10, "TextFit")
	return label
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
	elseif kind == "coin" then
		shape(0.08, 0.08, 0.84, 0.84, 0, tint, 99)
		shape(0.2, 0.2, 0.6, 0.6, 0, tint:Lerp(Color3.new(0, 0, 0), 0.22), 99)
		shape(0.38, 0.28, 0.24, 0.44, 0, tint:Lerp(Color3.new(1, 1, 1), 0.35), 3)
	elseif kind == "magnet" then
		-- A horseshoe: two arms with light tips and a rounded bridge.
		shape(0.16, 0.14, 0.24, 0.6, 0, tint, 5)
		shape(0.6, 0.14, 0.24, 0.6, 0, tint, 5)
		shape(0.16, 0.56, 0.68, 0.3, 0, tint, 9)
		shape(0.4, 0.14, 0.2, 0.46, 0, UI.Colors.background, 3)
		shape(0.16, 0.12, 0.24, 0.16, 0, Color3.fromRGB(236, 240, 248), 3)
		shape(0.6, 0.12, 0.24, 0.16, 0, Color3.fromRGB(236, 240, 248), 3)
	elseif kind == "sword" then
		shape(0.44, 0.04, 0.12, 0.62, 28, tint, 3)
		shape(0.24, 0.5, 0.44, 0.09, 28, tint, 3)
		shape(0.5, 0.62, 0.1, 0.26, 28, tint:Lerp(Color3.new(0, 0, 0), 0.3), 3)
	elseif kind == "plus" then
		shape(0.38, 0.12, 0.24, 0.76, 0, tint, 4)
		shape(0.12, 0.38, 0.76, 0.24, 0, tint, 4)
	elseif kind == "clock" then
		shape(0.08, 0.08, 0.84, 0.84, 0, tint, 99)
		shape(0.18, 0.18, 0.64, 0.64, 0, UI.Colors.background, 99)
		shape(0.47, 0.26, 0.06, 0.28, 0, tint, 2)
		shape(0.47, 0.47, 0.22, 0.06, 0, tint, 2)
	elseif kind == "globe" then
		shape(0.08, 0.08, 0.84, 0.84, 0, tint, 99)
		shape(0.14, 0.14, 0.72, 0.72, 0, tint:Lerp(Color3.new(0, 0, 0), 0.35), 99)
		shape(0.47, 0.1, 0.06, 0.8, 0, tint, 2)
		shape(0.1, 0.47, 0.8, 0.06, 0, tint, 2)
		shape(0.3, 0.12, 0.4, 0.76, 0, Color3.new(0, 0, 0), 99).BackgroundTransparency = 1
		shape(0.32, 0.14, 0.36, 0.72, 0, tint, 99).BackgroundTransparency = 0.7
	elseif kind == "lock" then
		shape(0.28, 0.1, 0.1, 0.4, 0, tint, 3)
		shape(0.62, 0.1, 0.1, 0.4, 0, tint, 3)
		shape(0.28, 0.08, 0.44, 0.12, 0, tint, 4)
		shape(0.18, 0.44, 0.64, 0.46, 0, tint, 5)
		shape(0.45, 0.58, 0.1, 0.16, 0, UI.Colors.background, 2)
	elseif kind == "target" then
		shape(0.06, 0.06, 0.88, 0.88, 0, tint, 99)
		shape(0.2, 0.2, 0.6, 0.6, 0, UI.Colors.background, 99)
		shape(0.3, 0.3, 0.4, 0.4, 0, tint, 99)
		shape(0.4, 0.4, 0.2, 0.2, 0, UI.Colors.background, 99)
	elseif kind == "shield" then
		shape(0.18, 0.1, 0.64, 0.52, 0, tint, 6)
		shape(0.27, 0.42, 0.46, 0.46, 45, tint, 4)
	elseif kind == "dice" then
		shape(0.14, 0.14, 0.72, 0.72, 0, tint, 9)
		for _, spot in ipairs({ { 0.27, 0.27 }, { 0.62, 0.27 }, { 0.44, 0.44 }, { 0.27, 0.62 }, { 0.62, 0.62 } }) do
			shape(spot[1], spot[2], 0.12, 0.12, 0, UI.Colors.background, 99)
		end
	elseif kind == "tag" then
		shape(0.1, 0.26, 0.66, 0.48, 0, tint, 6)
		shape(0.6, 0.31, 0.3, 0.38, 45, tint, 3)
		shape(0.2, 0.43, 0.14, 0.14, 0, UI.Colors.background, 99)
	elseif kind == "sparkle" then
		shape(0.42, 0.06, 0.16, 0.88, 0, tint, 8)
		shape(0.06, 0.42, 0.88, 0.16, 0, tint, 8)
		shape(0.3, 0.3, 0.4, 0.4, 45, tint, 4)
	elseif kind == "cards" then
		shape(0.12, 0.22, 0.5, 0.66, -10, tint:Lerp(Color3.new(0, 0, 0), 0.2), 5)
		shape(0.38, 0.12, 0.5, 0.66, 10, tint, 5)
		shape(0.52, 0.3, 0.22, 0.22, 45, UI.Colors.background, 3)
	elseif kind == "bow" then
		-- A drawn bow: the curved limb, the string and an arrow across it.
		shape(0.1, 0.1, 0.52, 0.8, 0, tint, 99)
		shape(0.2, 0.18, 0.44, 0.64, 0, UI.Colors.background, 99)
		shape(0.5, 0.1, 0.04, 0.8, 0, tint, 2)
		shape(0.18, 0.47, 0.72, 0.07, 0, UI.Colors.text, 2)
		shape(0.78, 0.4, 0.14, 0.2, 45, UI.Colors.text, 2)
	elseif kind == "bank" then
		-- A bank: pediment, four columns and a step.
		shape(0.1, 0.12, 0.8, 0.2, 0, tint, 3)
		shape(0.3, 0.04, 0.4, 0.16, 45, tint, 3)
		for index = 0, 3 do shape(0.16 + index * 0.2, 0.34, 0.1, 0.4, 0, tint, 2) end
		shape(0.08, 0.76, 0.84, 0.14, 0, tint, 3)
	elseif kind == "ring" then
		-- A range circle: a ring with a dot at its heart.
		shape(0.06, 0.06, 0.88, 0.88, 0, tint, 99)
		shape(0.17, 0.17, 0.66, 0.66, 0, UI.Colors.background, 99)
		shape(0.4, 0.4, 0.2, 0.2, 0, tint, 99)
	elseif kind == "wing" then
		shape(0.1, 0.5, 0.5, 0.2, -28, tint, 6)
		shape(0.3, 0.38, 0.52, 0.2, -12, tint, 6)
		shape(0.42, 0.24, 0.48, 0.2, 6, tint, 6)
	elseif kind == "eye" then
		shape(0.06, 0.3, 0.88, 0.4, 0, tint, 99)
		shape(0.34, 0.26, 0.32, 0.48, 0, UI.Colors.background, 99)
		shape(0.42, 0.4, 0.16, 0.2, 0, tint, 99)
	elseif kind == "skull" then
		shape(0.18, 0.1, 0.64, 0.58, 0, tint, 99)
		shape(0.3, 0.55, 0.4, 0.3, 0, tint, 5)
		shape(0.28, 0.34, 0.16, 0.18, 0, UI.Colors.background, 99)
		shape(0.56, 0.34, 0.16, 0.18, 0, UI.Colors.background, 99)
	elseif kind == "alert" then
		-- A warning: a round badge with an exclamation mark.
		shape(0.06, 0.06, 0.88, 0.88, 0, tint, 99)
		shape(0.42, 0.2, 0.16, 0.42, 0, UI.Colors.text, 3)
		shape(0.42, 0.68, 0.16, 0.14, 0, UI.Colors.text, 3)
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
	elseif kind=="crate" then
		-- A treasure chest in the tier's own colour, gold bands and a lock.
		local light=tint:Lerp(Color3.new(1,1,1),0.38)
		shape(.05,.33,.90,.60,ink,10)
		shape(.10,.37,.80,.52,tint,7)
		shape(.10,.37,.80,.14,light,7)
		shape(.03,.14,.94,.27,ink,12)
		shape(.07,.17,.86,.21,light,9)
		shape(.20,.14,.10,.76,gold,2)
		shape(.70,.14,.10,.76,gold,2)
		shape(.39,.31,.22,.26,gold,5)
		shape(.46,.38,.08,.11,ink,3)
		shape(.14,.03,.09,.09,cream,8,45)
		shape(.84,.0,.06,.12,cream,3,30)
	elseif kind=="gear" then
		for i=0,3 do shape(.42,.06,.16,.88,cream,3,i*45) end
		shape(.2,.2,.6,.6,cream,40)
		shape(.34,.34,.32,.32,tint,40)
	elseif kind=="scroll" then
		shape(.18,.14,.64,.74,ink,6)
		shape(.22,.18,.56,.66,cream,4)
		for i=0,2 do shape(.3,.3+i*.15,.4,.06,tint,2) end
		shape(.12,.08,.76,.12,Color3.fromRGB(207,133,64),6)
		shape(.12,.82,.76,.12,Color3.fromRGB(207,133,64),6)
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
	local frame = UI.frame(parent, {BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, subtitle and 90 or 46)})
	local bar = UI.frame(frame, {Name = "SectionMark", Position = UDim2.fromOffset(0, 10), Size = UDim2.fromOffset(6, 26), BackgroundColor3 = UI.Colors.gold})
	UI.corner(bar, 3)
	UI.label(frame, title, {Font = UI.Fonts.display, TextSize = 24, TextColor3 = UI.Colors.cream, TextWrapped=true, TextTruncate=Enum.TextTruncate.None, Position = UDim2.fromOffset(14, 0), Size = UDim2.new(1, -14, 0, 46)})
	if subtitle then
		UI.label(frame, subtitle, {TextColor3 = UI.Colors.muted, TextSize = 16, Position = UDim2.fromOffset(0, 46), Size = UDim2.new(1, 0, 0, 42), TextWrapped = true, TextTruncate = Enum.TextTruncate.None})
	end
	return frame
end

-- A small rounded tag: rarity, level, "NEW", a count.
function UI.chip(parent, text, color, properties)
	local chip = UI.label(parent, text, {BackgroundTransparency = 0, BackgroundColor3 = color, TextColor3 = UI.Colors.text, Font = UI.Fonts.display, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(70, 22)})
	for key, value in pairs(properties or {}) do chip[key] = value end
	UI.corner(chip, 11)
	UI.stroke(chip, UI.Colors.ink, 2)
	return chip
end

-- The big games' HUD button: a round candy disc with an illustration and an
-- outlined caption underneath. The whole rect is the tap target.
function UI.roundIcon(parent, name, caption, color, icon, callback, properties)
	-- The caption doubles as the button's (invisible) text, so it is found and
	-- read like any other button.
	local button = UI.button(parent, caption, callback, {Name = name, BackgroundTransparency = 1, TextTransparency = 1, Size = UDim2.fromOffset(72, 88)})
	for key, value in pairs(properties or {}) do button[key] = value end
	local captionH = caption ~= "" and 20 or 0
	local disc = UI.frame(button, {Name = "Disc", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 2), Size = UDim2.new(1, -captionH, 1, -captionH - 2), BackgroundColor3 = color, Active = false})
	UI.create("UIAspectRatioConstraint", {AspectRatio = 1}, disc)
	UI.corner(disc, 100)
	UI.stroke(disc, UI.Colors.ink, 3)
	UI.candy(disc)
	local shine = UI.frame(disc, {Name = "Shine", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromScale(0.5, 0.07), Size = UDim2.fromScale(0.62, 0.22), BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.72, Active = false})
	UI.corner(shine, 100)
	if type(icon) == "function" then icon(disc) elseif icon then UI.illustration(disc, icon, color, {Name = "NavIcon", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.52), Size = UDim2.fromScale(0.66, 0.66)}) end
	if captionH > 0 then
		UI.label(button, caption, {Name = "Caption", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 0), Size = UDim2.new(1, 24, 0, 22), TextSize = 16, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.None})
	end
	return button, disc
end

-- A red count bubble on a HUD button's corner.
function UI.badge(parent, name, text, color)
	local badge = UI.label(parent, text, {Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(1, -10, 0, 8), Size = UDim2.fromOffset(24, 24), BackgroundTransparency = 0, BackgroundColor3 = color or UI.Colors.red, TextSize = 13, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 5})
	UI.corner(badge, 12)
	UI.stroke(badge, UI.Colors.ink, 2)
	return badge
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
	-- Final art is cloned as it is (a MeshPart cannot be rebuilt from its
	-- properties by a script); portraits and previews never animate it.
	local art = source and source:FindFirstChild("HeroFigure", true)
	if art and art:GetAttribute("HeroArt") then
		local model = UI.create("Model", {Name = heroId}, parent)
		local copy = art:Clone()
		for _, item in ipairs(copy:GetDescendants()) do
			if item:IsA("BasePart") then item.Anchored, item.CanCollide, item.CanTouch, item.CanQuery, item.CastShadow = true, false, false, false, false end
		end
		copy.Parent = model
		return model
	end
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

-- A portrait whose figure can be posed: the jointed figure itself (not the
-- flattened geometry), its camera and where it looks. Returns nil when the hero
-- has no jointed figure to show, and the caller keeps the still portrait.
function UI.heroPortraitLive(parent, heroId, source, tint, properties)
	local art = source and source:FindFirstChild("HeroFigure", true)
	if not (art and art:GetAttribute("HeroArt")) then return nil end
	local defaults = {
		Name = "PortraitLive_" .. heroId, Size = UDim2.fromScale(1, 1),
		BackgroundColor3 = tint:Lerp(UI.Colors.background, 0.8), BorderSizePixel = 0,
		Ambient = Color3.fromRGB(195, 207, 224), LightColor = Color3.fromRGB(255, 245, 228),
		LightDirection = Vector3.new(-1, -0.6, -1), BackgroundTransparency = 0.05,
	}
	for key, value in pairs(properties or {}) do defaults[key] = value end
	local viewportFrame = UI.create("ViewportFrame", defaults, parent)
	UI.corner(viewportFrame, 8)
	local world = UI.create("WorldModel", {Name = "HeroPreview"}, viewportFrame)
	local model = UI.heroModel(world, heroId, source)
	local figure = model:FindFirstChild("HeroFigure", true)
	local frame, bounds = model:GetBoundingBox()
	local focus = frame.Position + Vector3.new(0, bounds.Y * 0.06, 0)
	-- A touch further back than the still portrait: the figure jumps and needs headroom.
	local span = math.max(bounds.Y, bounds.X * 0.9, 5) * 1.02
	local camera = UI.create("Camera", {Name = "PortraitCamera", FieldOfView = 32}, viewportFrame)
	local offset = Vector3.new(span * 0.44, span * 0.12, -span * 1.95)
	camera.CFrame = CFrame.lookAt(focus + offset, focus)
	viewportFrame.CurrentCamera = camera
	return { frame = viewportFrame, model = model, figure = figure, camera = camera, focus = focus, offset = offset }
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
UI.TOWER_TALL_HEIGHT = 360
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
	layout.hpBar = rect(rightX + math.floor(rightW * 0.1), top.y + (class.short and 28 or 34), rightW - math.floor(rightW * 0.1), class.short and 12 or 16)

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
	-- Speed (1x/2x), auto-skip and the commander's sheet ride in the same band as the ability: they
	-- are pressed often, so they get thumb height and sit where the hand is.
	local controlW = small and 52 or 64
	local function bandWidth()
		local w = count * skillW + math.max(0, count - 1) * 8
		if options.vip then w += (count > 0 and 8 or 0) + saluteW end
		-- 2x, 3x, auto-skip, the sheet and, in the cards mode, the cards.
		return w + (w > 0 and 8 or 0) + (options.cards and 5 or 4) * controlW + 16
	end
	-- On a narrow screen the band gives way a little at a time: the ability
	-- first, then the salute, then the small controls (never under 44 wide).
	-- (On a phone on its side the five hero tiles share the row, and need 290.)
	local available = width - 2 * pad - (class.short and 290 or 0)
	for _, step in ipairs({ { "skill", 80 }, { "salute", 40 }, { "control", 36 } }) do
		while bandWidth() > available do
			if step[1] == "skill" and skillW > step[2] then skillW -= 2
			elseif step[1] == "salute" and saluteW > step[2] then saluteW -= 2
			elseif step[1] == "control" and controlW > step[2] then controlW -= 1
			else break end
		end
	end
	local abilitiesW = bandWidth()
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
	-- Slots are portrait tiles with a number and a price, like the genre's
	-- best quickbars: five always sit side by side, so no slot hides behind
	-- the ability buttons on a phone, and on wide screens the band shrinks
	-- around them instead of stretching the tiles.
	local tileH = layout.heroCards.h - 14
	layout.cardW = math.max(48, math.min(tileH + 22, math.floor((layout.heroCards.w - 14 - 4 * 7) / 5)))
	if not class.short then
		local bandW = 5 * layout.cardW + 4 * 7 + 14
		layout.heroCards = rect(math.floor((width - bandW) / 2), layout.heroCards.y, bandW, layout.heroCards.h)
	end

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
		-- The boss banner stays in the middle, narrow enough to leave the right
		-- column to the tower panel.
		local columnW = math.min(330, width - 2 * pad)
		local bossW = math.max(280, math.min(520, width - 2 * (columnW + pad + 10)))
		bossW = math.min(bossW, width - 2 * pad)
		layout.skip = rect(math.floor((width - skipW) / 2), bannerY, skipW, 48)
		layout.boss = rect(math.floor((width - bossW) / 2), bannerY, bossW, bossH)
		local placementW = math.min(430, width - 2 * pad)
		if abilitiesW == 0 or pad + abilitiesW + 12 + placementW <= width - pad then
			layout.placement = rect(width - pad - placementW, layout.actionTop + buttonH - placementH, placementW, placementH)
		else
			layout.placement = rect(math.floor((width - placementW) / 2), layout.actionTop - 8 - placementH, placementW, placementH)
		end
		layout.hint = rect(layout.placement.x, layout.placement.y - 4 - hintH, layout.placement.w, hintH)
		-- The tower panel takes the right-hand column from the status row down to
		-- the action band; only where the boss banner reaches that column does it
		-- start below the banner.
		local towerTop = bannerY
		if layout.boss.x + layout.boss.w > width - pad - columnW then towerTop = bannerY + bossH + gap end
		local towerBottom = layout.actionTop - gap
		local tall = towerBottom - towerTop >= UI.TOWER_TALL_HEIGHT
		local towerW = tall and columnW or math.min(420, width - 2 * pad)
		local towerH = tall and math.min(towerBottom - towerTop, 400) or math.min(UI.TOWER_WIDE_HEIGHT, towerBottom - towerTop)
		layout.tower = rect(width - pad - towerW, tall and towerTop or towerBottom - towerH, towerW, towerH)
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
	local panelW = math.min(1040, width - 36)
	local headerH = class.short and 62 or 84
	local panelH
	if stacked then
		panelH = math.min(height - 24, headerH + 3 * 142 + 2 * 10 + 14)
	else
		panelH = math.min(440, height - 24)
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
-- Heroes, evolution, shop, gifts, missions.
UI.NAV_COUNT = 5

function UI.difficultyRowH(class) return class.compact and 30 or 34 end

function UI.lobbyLayout(width, height, options)
	width, height = clampScreen(width, height)
	local class = UI.sizeClass(width, height)
	local pad = class.compact and 10 or 14
	local rowH = 48
	-- Round buttons in the top-right corner: the active base and settings.
	local round = class.short and 58 or 66
	local settings = rect(width - pad - round, pad, round, round + 16)
	local squad = rect(settings.x - 10 - round, pad, round, round + 16)
	-- The pill never reaches the buttons, however narrow the screen.
	local pill = rect(pad, pad, math.min(class.compact and 170 or 236, squad.x - 8 - pad), rowH)
	local count = UI.NAV_COUNT
	local column = width >= 1000 and not class.short
	local navigation
	if column then
		local cell = 92
		local navigationH = count * cell
		local top = pill.y + pill.h + 20
		navigation = rect(pad, math.max(top, math.floor((height - navigationH) / 2)), 84, navigationH)
	else
		local navigationW = math.min(count * (class.short and 84 or 100), width - 2 * pad)
		local navigationH = class.short and 60 or class.compact and 76 or 88
		navigation = rect(math.floor((width - navigationW) / 2), height - pad - navigationH, navigationW, navigationH)
	end
	local floor = column and height - pad or navigation.y - 8
	local cardW = math.min(class.compact and 460 or 600, width - 2 * pad)
	local cardH = class.short and 84 or (class.compact and 96 or 112)
	-- A campaign car adds its row of difficulties (Normal / Hard / Nightmare).
	-- A short phone has no height to spare: there they take the riders' line.
	if options and options.difficulty and not class.short then cardH += UI.difficultyRowH(class) + 6 end
	local elevator = rect(math.floor((width - cardW) / 2), (class.short and height - pad or floor) - cardH, cardW, cardH)
	local hintW = math.min(520, width - 2 * pad)
	local hint = rect(math.floor((width - hintW) / 2), floor - 44, hintW, 44)
	local contextW = math.min(560, width - 2 * pad)
	-- The context panel is a sheet on landscape phones. Hiding corner chrome
	-- there makes enough room for the close control and scrollable content.
	local contextTop = class.short and pad or pad + squad.h + 8
	local function contextAbove(bottom)
		local h = math.min(class.compact and 330 or 400, bottom - contextTop)
		return rect(math.floor((width - contextW) / 2), bottom - h, contextW, h)
	end
	return {
		class = class, pill = pill, squad = squad, settings = settings, navigation = navigation,
		column = column, elevator = elevator, hint = hint,
		context = contextAbove(column and hint.y - 8 or navigation.y - 8),
		contextRiding = contextAbove(elevator.y - 8),
		contextTop = contextTop, contextBottom = column and hint.y - 8 or navigation.y - 8,
	}
end

-- One source of truth for every lobby panel, including the wide talent tree.
-- Controllers hide the corner HUD/navigation while a modal sheet is open;
-- the elevator remains visible and tappable below it when the player boards.
function UI.contextLayout(width, height, options)
	width, height = clampScreen(width, height)
	options = options or {}
	local hud = UI.lobbyLayout(width, height, { difficulty = options.difficulty })
	local pad = hud.class.compact and 10 or 14
	local modal = hud.class.short
	local top = modal and pad or hud.contextTop
	-- With the menu column on the left, a window may use the screen down to its bottom edge.
	local bottom = options.elevator and hud.elevator.y - 8 or modal and height - pad or (hud.column and height - pad or hud.contextBottom)
	local maxWidth = options.wide and 900 or 690
	-- A panel never slides under the left column of big buttons.
	local margin = hud.column and not modal and hud.navigation.x + hud.navigation.w + 8 or pad
	local panelWidth = math.min(maxWidth, width - 2 * margin)
	local slot = rect(math.floor((width - panelWidth) / 2), top, panelWidth, bottom - top)
	slot.modal = modal
	slot.class = hud.class
	return slot
end

-- What sets a hero apart, one line each (no bullets). `slow` is the slow the
-- tower really has now, when it is a tower.
function UI.heroTraits(def, T, slow)
	local traits = {}
	local function add(pt, en) table.insert(traits, T(pt, en)) end
	local slowNow = slow or def.slow or 0
	if slowNow > 0 then add("Desacelera os inimigos em " .. math.floor(slowNow * 100 + 0.5) .. "% e evolui com o nível", "Slows enemies by " .. math.floor(slowNow * 100 + 0.5) .. "% and grows with level") end
	if (def.knockback or 0) > 0 then add("Cada soco empurra o inimigo para trás", "Every punch shoves the enemy back") end
	if def.stunProof then add("Nunca é paralisado", "Can never be stunned") end
	if (def.stunAura or 0) > 0 then add("No nível 5, protege os aliados da paralisia", "At level 5 shields allies from stuns") end
	if def.attack == "mine" then add("Planta até " .. tostring(def.mineMax or 0) .. " minas na estrada; explodem em área", "Lays up to " .. tostring(def.mineMax or 0) .. " mines on the road; they blast an area") end
	if def.reveal then add("Revela inimigos camuflados", "Reveals hidden enemies") end
	if def.support then add("Fortalece as torres ao redor", "Strengthens the towers around it") end
	if def.pickup then add("Puxa o Ouro que cai perto dela", "Pulls in Gold that lands nearby") end
	if def.attack == "splash" then add("Acerta vários inimigos de uma vez (área)", "Hits several enemies at once (area)") end
	if def.attack == "chain" then add("O ataque salta entre inimigos", "The attack jumps between enemies") end
	if def.attack == "beam" then add("Raio contínuo que atravessa a fila", "A beam that pierces the line") end
	return traits
end

function UI.percent(value, language)
	value = tonumber(value) or 0
	local text = value >= 10 and string.format("%.0f%%", value) or value >= 1 and string.format("%.1f%%", value) or string.format("%.2f%%", value)
	text = text:gsub("%.0%%", "%%")
	if language ~= "en" then text = text:gsub("%.", ",") end
	return text
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

--==============================================================================
-- The reference window skin: slanted title ribbon, square red X, coloured tabs,
-- tooltips that follow the mouse. Everything is flat shapes: no image assets.
--==============================================================================

-- A parallelogram: an axis-aligned clip with a tall frame turned inside it,
-- so its two long edges become the slanted ends ("/ text /").
function UI.parallelogram(parent, color, properties)
	local slant = math.rad(16)
	local clip = UI.frame(parent, {Name = "Parallelogram", BackgroundTransparency = 1, ClipsDescendants = true, Active = false})
	for key, value in pairs(properties or {}) do clip[key] = value end
	local height = clip.Size.Y.Offset > 0 and clip.Size.Y.Offset or 56
	local inner = UI.frame(clip, {Name = "Fill", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, -math.floor(height * math.tan(slant) + 0.5), 0, height * 4), Rotation = math.deg(slant), BackgroundColor3 = color, Active = false, ZIndex = clip.ZIndex})
	return clip, inner
end

-- The title tab of a window, sticking out of its top-left corner: a darker
-- copy behind for depth, a black outline, the colour, a gloss on the top half
-- and the title in big round outlined letters.
function UI.titleRibbon(parent, text, tint, properties)
	properties = properties or {}
	local width, height = properties.width or 380, properties.height or 58
	local z = properties.ZIndex or 3
	local root = UI.frame(parent, {Name = properties.Name or "TitleRibbon", BackgroundTransparency = 1, Position = properties.Position or UDim2.fromOffset(-10, -18),
		Size = UDim2.fromOffset(width, height), Active = false, ZIndex = z})
	UI.parallelogram(root, tint:Lerp(Color3.new(0, 0, 0), 0.55), {Name = "RibbonDepth", Position = UDim2.fromOffset(10, 8), Size = UDim2.fromOffset(width, height), ZIndex = z})
	UI.parallelogram(root, UI.Colors.ink, {Name = "RibbonOutline", Position = UDim2.fromOffset(-3, -3), Size = UDim2.fromOffset(width + 6, height + 6), ZIndex = z})
	local _, fill = UI.parallelogram(root, tint, {Name = "RibbonFill", Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(width, height), ZIndex = z})
	UI.create("UIGradient", {Color = ColorSequence.new(tint:Lerp(Color3.new(1, 1, 1), 0.22), tint:Lerp(Color3.new(0, 0, 0), 0.18)), Rotation = 90}, fill)
	local _, gloss = UI.parallelogram(root, Color3.new(1, 1, 1), {Name = "RibbonGloss", Position = UDim2.fromOffset(6, 4), Size = UDim2.fromOffset(width - 12, math.floor(height * 0.34)), ZIndex = z})
	gloss.BackgroundTransparency = 0.78
	local title = UI.label(root, text, {Name = properties.TitleName or "RibbonTitle", Position = UDim2.fromOffset(math.floor(height * 0.42) + (properties.textInset or 0), 0),
		Size = UDim2.new(1, -math.floor(height * 0.9) - (properties.textInset or 0), 1, -2), Font = UI.Fonts.display, TextSize = properties.TextSize or 32,
		TextColor3 = UI.Colors.text, TextXAlignment = Enum.TextXAlignment.Left, TextScaled = false, ZIndex = z + 1})
	UI.outline(title, 3)
	return root, title
end

-- The square red X of the reference windows.
function UI.closeButton(parent, callback, properties)
	local button = UI.button(parent, "X", callback, {Name = "Close", BackgroundColor3 = UI.Colors.red, TextSize = 30, Size = UDim2.fromOffset(52, 52), ZIndex = 4})
	for key, value in pairs(properties or {}) do button[key] = value end
	local corner = button:FindFirstChildOfClass("UICorner")
	if corner then corner.CornerRadius = UDim.new(0, 12) end
	UI.stroke(button, UI.Colors.ink, 3.5)
	return button
end

-- A dark window body with the colour frame and a soft diagonal sheen.
function UI.windowSkin(frame, tint)
	frame.BackgroundColor3 = UI.Skin.body
	frame.BackgroundTransparency = 0
	local gradient = frame:FindFirstChildOfClass("UIGradient") or UI.create("UIGradient", {}, frame)
	gradient.Color = ColorSequence.new(UI.Skin.bodyTop, UI.Skin.body)
	gradient.Rotation = 90
	gradient.Enabled = true
	local border = UI.stroke(frame, tint:Lerp(Color3.new(1, 1, 1), 0.18), 4)
	local corner = frame:FindFirstChildOfClass("UICorner")
	if corner then corner.CornerRadius = UDim.new(0, 18) end
	local sheen = frame:FindFirstChild("Sheen") or UI.frame(frame, {Name = "Sheen", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ClipsDescendants = true, Active = false})
	UI.clear(sheen)
	for index = 0, 2 do
		UI.frame(sheen, {Name = "Stripe", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.62 + index * 0.13, 0.5),
			Size = UDim2.new(0, 34 + index * 22, 2.4, 0), Rotation = 24, BackgroundColor3 = Color3.new(1, 1, 1), BackgroundTransparency = 0.955, Active = false})
	end
	return border
end

-- A coloured tab with its own icon, the selected one raised and outlined white.
function UI.tab(parent, text, color, icon, selected, callback, properties)
	local button = UI.button(parent, "", callback, {BackgroundColor3 = selected and color or color:Lerp(UI.Skin.body, 0.45), TextSize = 17})
	for key, value in pairs(properties or {}) do button[key] = value end
	UI.stroke(button, selected and Color3.new(1, 1, 1) or UI.Colors.ink, selected and 3 or 2.5)
	local tabSize = button.Size
	UI.studs(button, tabSize.Y.Scale == 0 and tabSize.Y.Offset or 44, tabSize.X.Scale == 0 and tabSize.X.Offset or nil, button.ZIndex)
	local iconSize = math.min(30, math.max(18, (button.Size.Y.Offset > 0 and button.Size.Y.Offset or 44) - 16))
	local hasIcon = icon ~= nil
	if hasIcon then
		UI.icon(button, icon, Color3.new(1, 1, 1), {Name = "TabIcon", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(iconSize, iconSize), ZIndex = (button.ZIndex or 1) + 1})
	end
	local label = UI.label(button, text, {Name = "TabText", Position = UDim2.fromOffset(hasIcon and iconSize + 14 or 6, 0), Size = UDim2.new(1, hasIcon and -(iconSize + 20) or -12, 1, 0),
		Font = UI.Fonts.display, TextSize = button.TextSize, TextXAlignment = hasIcon and Enum.TextXAlignment.Left or Enum.TextXAlignment.Center,
		TextColor3 = selected and UI.Colors.text or UI.Colors.text:Lerp(UI.Skin.body, 0.15), TextScaled = true, TextTruncate = Enum.TextTruncate.None, ZIndex = (button.ZIndex or 1) + 1})
	-- Shrinks to fit a narrow tab (a phone held upright), never past the set size.
	UI.textLimit(label, button.TextSize, 9)
	UI.outline(label, 2)
	-- The button keeps the words (tests and screen readers find it by them) but
	-- draws none: its own text outline would show through as a ghost.
	button.Text = text
	button.TextTransparency = 1
	local ghost = button:FindFirstChild("TextOutline")
	if ghost then ghost:Destroy() end
	return button
end

-- A small trait/tag pill (the anime game's blue tags).
function UI.pill(parent, text, color, properties)
	local pill = UI.label(parent, text, {Name = "Pill", BackgroundTransparency = 0, BackgroundColor3 = color or UI.Colors.blue, Font = UI.Fonts.display, TextSize = 15,
		TextXAlignment = Enum.TextXAlignment.Center, Size = UDim2.fromOffset(0, 28), TextTruncate = Enum.TextTruncate.None})
	for key, value in pairs(properties or {}) do pill[key] = value end
	-- Exactly as wide as its words (measured), plus room on both sides.
	local width = #text * pill.TextSize * 0.56
	pcall(function()
		width = game:GetService("TextService"):GetTextSize(text, pill.TextSize, pill.Font, Vector2.new(2000, 200)).X
	end)
	local height = pill.Size.Y.Offset > 0 and pill.Size.Y.Offset or 28
	pill.Size = UDim2.fromOffset(math.ceil(width) + 24, height)
	UI.corner(pill, 8)
	UI.stroke(pill, UI.Colors.ink, 2)
	return pill
end

-- The "Damage / SPA / Range" table: a row of headers over a row of big values.
function UI.statTable(parent, entries, properties)
	local root = UI.frame(parent, {Name = "StatTable", BackgroundColor3 = UI.Skin.slot, Size = UDim2.new(1, 0, 0, 82)})
	for key, value in pairs(properties or {}) do root[key] = value end
	UI.corner(root, 12)
	UI.stroke(root, UI.Skin.slotLine, 2)
	local count = math.max(1, #entries)
	for index, entry in ipairs(entries) do
		local cell = UI.frame(root, {Name = "Stat_" .. (entry.key or index), BackgroundTransparency = 1, Position = UDim2.fromScale((index - 1) / count, 0), Size = UDim2.fromScale(1 / count, 1)})
		UI.label(cell, entry.label, {Name = "Header", Position = UDim2.fromOffset(4, 6), Size = UDim2.new(1, -8, 0.42, -6), Font = UI.Fonts.display, TextSize = entry.headerSize or 18,
			TextColor3 = UI.Colors.muted, TextXAlignment = Enum.TextXAlignment.Center})
		local value = UI.label(cell, entry.value, {Name = "Value", Position = UDim2.new(0, 4, 0.42, 0), Size = UDim2.new(1, -8, 0.58, -6), Font = UI.Fonts.display, TextSize = entry.valueSize or 26,
			TextColor3 = entry.color or UI.Colors.text, TextXAlignment = Enum.TextXAlignment.Center, RichText = entry.rich == true})
		if entry.rich then value.RichText = true end
		if index > 1 then UI.frame(cell, {Name = "Divider", Position = UDim2.new(0, 0, 0.16, 0), Size = UDim2.new(0, 2, 0.68, 0), BackgroundColor3 = UI.Skin.slotLine, BackgroundTransparency = 0.3}) end
	end
	return root
end

--==============================================================================
-- Tooltips: hovering a hero, a talent or a shop item shows what it is now.
-- One box at a time, in the overlay layer, following the mouse and kept on
-- screen. The controller sets UI.tooltipLayer (its overlay frame).
--==============================================================================
UI.tooltipLayer = nil
local tooltip = { owner = nil, frame = nil, connection = nil }

function UI.hideTooltip(owner)
	if owner ~= nil and tooltip.owner ~= owner then return end
	if tooltip.connection then tooltip.connection:Disconnect() end
	if tooltip.frame then tooltip.frame:Destroy() end
	tooltip.owner, tooltip.frame, tooltip.connection = nil, nil, nil
end

-- A tooltip body: a title, lines, and coloured value rows, added by `build`.
function UI.tooltipTitle(body, text, color)
	return UI.label(body, text, {Name = "TipTitle", Size = UDim2.new(1, 0, 0, 30), Font = UI.Fonts.display, TextSize = 24, TextColor3 = color or UI.Colors.text, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = 1})
end
function UI.tooltipLine(body, text, color, order, size)
	return UI.label(body, text, {Name = "TipLine", Size = UDim2.new(1, 0, 0, 20), TextSize = size or 16, TextColor3 = color or UI.Colors.muted, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, AutomaticSize = Enum.AutomaticSize.Y, LayoutOrder = order or 5, RichText = true})
end

function UI.hover(target, build, width)
	if not target or not target.MouseEnter then return end
	target.MouseEnter:Connect(function()
		local layer = UI.tooltipLayer
		if not layer or not target.Parent then return end
		UI.hideTooltip()
		local box = UI.frame(layer, {Name = "Tooltip", BackgroundColor3 = UI.Skin.tooltip, BackgroundTransparency = 0.04, Size = UDim2.fromOffset(width or 300, 0),
			AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 120, Active = false})
		UI.corner(box, 12)
		UI.stroke(box, Color3.fromRGB(236, 238, 250), 2)
		UI.padding(box, 12)
		local list = UI.list(box, 4)
		list.SortOrder = Enum.SortOrder.LayoutOrder
		local ok = pcall(build, box)
		if not ok then box:Destroy(); return end
		for _, item in ipairs(box:GetDescendants()) do
			if item:IsA("GuiObject") then item.ZIndex = 121 end
		end
		tooltip.owner, tooltip.frame = target, box
		local okServices, input = pcall(game.GetService, game, "UserInputService")
		local _, guiService = pcall(game.GetService, game, "GuiService")
		local _, run = pcall(game.GetService, game, "RunService")
		local function follow()
			if not target.Parent or not box.Parent then UI.hideTooltip(target); return end
			if not okServices or not input then return end
			local mouse = input:GetMouseLocation()
			local inset = guiService and guiService:GetGuiInset() or Vector2.new(0, 0)
			local scale = UI.screenScale or 1
			local x, y = (mouse.X - inset.X) / scale + 18, (mouse.Y - inset.Y) / scale + 18
			local layerSize = UI.toLogical(layer.AbsoluteSize) or Vector2.new(1280, 720)
			local boxSize = UI.toLogical(box.AbsoluteSize) or Vector2.new(width or 300, 120)
			if x + boxSize.X > layerSize.X - 8 then x = x - boxSize.X - 30 end
			if y + boxSize.Y > layerSize.Y - 8 then y = math.max(8, layerSize.Y - 8 - boxSize.Y) end
			box.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
		end
		follow()
		if run and run.RenderStepped then tooltip.connection = run.RenderStepped:Connect(follow) end
	end)
	target.MouseLeave:Connect(function() UI.hideTooltip(target) end)
end

return UI
