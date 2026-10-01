-- Client presentation and intent controller. Authority always remains on the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local GuiService = game:GetService("GuiService")

local player = Players.LocalPlayer
local shared = ReplicatedStorage:WaitForChild("DoomShared")
local Catalog = require(shared:WaitForChild("Catalog"))
local Rules = require(shared:WaitForChild("Rules"))
local Config = require(shared:WaitForChild("Config"))
local UI = require(script:WaitForChild("UI"))
local Effects = require(script:WaitForChild("Effects"))
local Audio = require(script:WaitForChild("Audio"))
local Nameplates = require(script:WaitForChild("Nameplates"))
local Celebrate = require(script:WaitForChild("Celebrate"))
local RoutePreview = require(script:WaitForChild("RoutePreview"))
local BuildOverlay = require(script:WaitForChild("BuildOverlay"))
local Panels = require(script:WaitForChild("Panels"))
local remotes = ReplicatedStorage:WaitForChild("DoomRemotes")
local requestRemote = remotes:WaitForChild("Request")
local stateRemote = remotes:WaitForChild("State")
local fxRemote = remotes:WaitForChild("FX")
local C = UI.Colors

-- Keep Roblox's filtered chat away from the currency/header and tower bar.
-- Configuration can be absent in a test host; it must not block HUD startup.
task.spawn(function()
	pcall(function()
		local chat = game:GetService("TextChatService")
		local window = chat:WaitForChild("ChatWindowConfiguration", 10)
		if window then
			-- A small, see-through window on the right edge: the left holds the
			-- lobby's menu column and the bottom the hero bar, and the right
			-- middle is open sky in the lobby and open road in a battle.
			for key, value in pairs({ VerticalAlignment = Enum.VerticalAlignment.Center, HorizontalAlignment = Enum.HorizontalAlignment.Right,
				HeightScale = 0.34, WidthScale = 0.34, BackgroundColor3 = C.panel, BackgroundTransparency = 0.6, TextSize = 13 }) do
				pcall(function() window[key] = value end)
			end
		end
	end)
end)

local state, language = nil, "pt"
-- Leaderboard panel state, one table to spare the script's local slots.
local board = { size = 1, map = "hydra", data = nil, mode = "ranked", failed = false }
local selectedTower, selectedHero, selectedSkill = nil, nil, nil
local selectedPosition, placementValid = nil, false
local placementPinned = false
local layoutKind, lastProfileSignature = nil, nil
local refs, productInfo, productFetching = {}, {}, false
local placementRing, ghost, towerRing
local ghostParts, ghostLift
local contextPanel = nil
local pending = {}
-- Small HUD state and constants, one table to spare the main chunk's
-- registers (Luau allows 200 and this script is close to it).
local kit = { cosmeticsRetryPending = false, contextRefreshPending = false }
local render, renderLobby, renderContext, renderElevator, openContext, closeContext, updateWorldCosmetics, fetchProducts, updateMatch, showToast

local function T(pt, en) return language == "en" and en or pt end
local function L(value)
	if type(value) == "table" then return value[language] or value.pt or value.en or "" end
	return tostring(value or "")
end
local function number(value) return UI.format(value) end
local function profile() return state and state.profile or {} end
local function activeMatch() return state and (state.phase == "Wave" or state.phase == "Preparing") end
local function viewport()
	local camera = workspace.CurrentCamera
	return camera and camera.ViewportSize or Vector2.new(1280, 720)
end
local function colorFor(id) return UI.color(Catalog.Heroes[id] and Catalog.Heroes[id].color) end
local function heroName(id) return L(Catalog.Heroes[id] and Catalog.Heroes[id].name or id) end
local function mapName(id) return L(Catalog.Maps[id] and Catalog.Maps[id].name or id) end
local function modeName(id) return L(Catalog.Modes[id] and Catalog.Modes[id].name or id) end
local function contains(array, id) return table.find(array or {}, id) ~= nil end
local function copy(array) return table.clone(array or {}) end

local gui = UI.create("ScreenGui", {Name = "DoomsdayUI", ResetOnSpawn = false, ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 10}, player:WaitForChild("PlayerGui"))
local main = UI.frame(gui, {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1)})
local overlays = UI.frame(gui, {BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 50})

-- Every HUD is laid out from the usable screen: the viewport minus Roblox's
-- topbar and the device's safe area, which is exactly main's AbsoluteSize.
-- Before the first layout pass that is still zero, so fall back to the
-- viewport minus the reported inset.
local function screenSize()
	local size = main.AbsoluteSize
	if size.X > 0 and size.Y > 0 then return size end
	local camera, inset = viewport(), GuiService:GetGuiInset()
	return Vector2.new(camera.X, camera.Y - inset.Y)
end
local function sizeClass()
	local size = screenSize()
	return UI.sizeClass(size.X, size.Y)
end
local function mobile() return sizeClass().compact end
-- A layout rect from UI.*Layout, as Position/Size. With an origin rect the
-- position becomes relative to that parent frame.
local function at(r, origin) return UDim2.fromOffset(r.x - (origin and origin.x or 0), r.y - (origin and origin.y or 0)) end
local function dims(r) return UDim2.fromOffset(r.w, r.h) end
local function screenKey()
	local size = screenSize()
	return tostring(math.floor(size.X)) .. "x" .. tostring(math.floor(size.Y))
end

-- Small one-shot motion acknowledges a new screen; reduced effects stays still.
local function welcomePanel(panel)
	if profile().settings and profile().settings.lowFX then return end
	local scale=UI.create("UIScale",{Scale=0.975},panel)
	TweenService:Create(scale,TweenInfo.new(0.18,Enum.EasingStyle.Quad),{Scale=1}):Play()
end

-- Menus blur the world behind them, like the big Roblox games do. Local to
-- this client's Lighting, skipped on "fewer effects", eased in and out.
local function menuBlur(on)
	pcall(function()
		local lighting = game:GetService("Lighting")
		local blur = lighting:FindFirstChild("DoomMenuBlur")
		local lowFX = state and state.profile and state.profile.settings and state.profile.settings.lowFX
		if on and lowFX then on = false end
		if on and not blur then
			blur = Instance.new("BlurEffect")
			blur.Name, blur.Size, blur.Parent = "DoomMenuBlur", 0, lighting
		end
		if not blur then return end
		local target = on and 14 or 0
		local ok, tweens = pcall(game.GetService, game, "TweenService")
		if ok and tweens then tweens:Create(blur, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = target}):Play() else blur.Size = target end
	end)
end

local function surface(label,tint)
	label.BackgroundColor3=C.ink
	label.BackgroundTransparency=0.25
	UI.corner(label,12)
	UI.stroke(label,tint or C.ink,2)
	return label
end

showToast = function(message, bad)
	if not message or message == "" then return end
	local current = overlays:FindFirstChild("Toast")
	if current then current:Destroy() end
	local inBattle = activeMatch() and refs.toastTop ~= nil
	local top = inBattle and ((refs.boss and refs.boss.Parent and refs.boss.Visible) and refs.toastBossTop or refs.toastTop) or nil
	local toast = UI.roundFrame(overlays, {
		Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, top or (activeMatch() and 8 or math.max(8,screenSize().Y-78))),
		Size = UDim2.new(1, -32, 0, inBattle and 48 or 62), ZIndex = 60,
	}, bad and C.red or C.green)
	UI.create("UISizeConstraint", {MaxSize = Vector2.new(580, 100)}, toast)
	UI.label(toast, L(message), {Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -28, 1, -12), TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextSize = 14, ZIndex = 61})
	toast.Active=false
	welcomePanel(toast)
	task.delay(4.5, function() if toast.Parent then toast:Destroy() end end)
end

local function request(action, payload, silent)
	local success, result = pcall(function() return requestRemote:InvokeServer(action, payload or {}) end)
	if not success or type(result) ~= "table" then
		if not silent then showToast(T("Sem resposta do servidor. Tente novamente.", "The server did not respond. Please try again."), true) end
		return nil
	end
	if not result.ok and not silent then showToast(result.message or T("Ação indisponível.", "Action unavailable."), true) end
	return result
end

local function act(action, payload, callback, onFail)
	if pending[action] then return end
	pending[action] = true
	-- A slow answer says it is being handled, instead of looking like a dead button.
	task.delay(0.6, function()
		if pending[action] and not activeMatch() then showToast(T("⏳ Processando…", "⏳ Working…")) end
	end)
	task.spawn(function()
		local result = request(action, payload)
		pending[action] = nil
		if result and result.ok then
			if callback then callback(result.data) end
		elseif onFail then
			onFail(result)
		end
	end)
end

local audio = Audio.new(function() return state end)
UI.onPress = function() audio:Cue("click", 0.04) end
local nameplates = Nameplates.new(player, function() return language end)
local effects = Effects.new(player, request, function() return state end, audio)
local routePreview = RoutePreview.new(effects.folder, Catalog, C)
-- "Buy it at the shop": close the panel and light the way to the chest pad.
function routePreview.goShop(chestId)
	local lobby = workspace:FindFirstChild("DoomLobby")
	local stand = lobby and lobby:FindFirstChild("Chest_" .. (chestId or "rare"))
	local pad = stand and (stand:FindFirstChild("ShopEntryPad") or stand.PrimaryPart)
	closeContext()
	if pad and routePreview:ShowWay(pad.Position, T("LOJA • PISE AQUI", "SHOP • STEP HERE")) then
		showToast(T("Siga a luz até a LOJA: lá você compra baús de heróis e de bases.", "Follow the light to the SHOP: buy hero and base chests there."))
	else
		showToast(T("Os baús ficam na LOJA do Mercado, na praça.", "Chests are sold at the Market SHOP on the plaza."))
	end
end
function routePreview.goPortal(destinationId)
	local destination=Catalog.Destinations[destinationId or "normal"]
	if not destination then return end
	local lobby=workspace:FindFirstChild("DoomLobby")
	local station=lobby and lobby:FindFirstChild("Portal_"..(destinationId or "normal"))
	local pad=station and station:FindFirstChild("Pad")
	closeContext()
	local position=pad and pad.Position or Vector3.new(destination.x,1,destination.z)
	routePreview:ShowWay(position,T("PORTAL • ENTRE NA FILA","PORTAL • JOIN A QUEUE"))
	showToast(T("Siga a luz. Cada fila aceita até 4 pessoas.","Follow the light. Each queue holds up to 4 players."))
end
local buildOverlay = BuildOverlay.new(effects.folder, Catalog, Rules, Config, C)

local function smallText(parent, text, y, h)
	return UI.label(parent, text, {Position = UDim2.fromOffset(14, y), Size = UDim2.new(1, -28, 0, h or 40), TextSize = 12, TextColor3 = C.muted, TextWrapped = true, TextTruncate = Enum.TextTruncate.None})
end

local function heading(parent, text, y, tint)
	return UI.label(parent, text, {Position = UDim2.fromOffset(14, y or 12), Size = UDim2.new(1, -28, 0, 26), TextSize = 17, Font = Enum.Font.GothamBold, TextColor3 = tint or C.text})
end

local function profileSignature()
	local p = profile()
	local presented=table.clone(p)
	-- Only the gifts page renders reward clocks. Updating those clocks must
	-- not rebuild a shop, inventory or destination page while it is scrolled.
	if not contextPanel or contextPanel.kind~="rewards" then presented.rewards=nil end
	local ok, encoded = pcall(HttpService.JSONEncode, HttpService, presented)
	return ok and encoded or tostring(p.gold) .. tostring(p.level)
end

-- True when the Gold on hand already opens at least one chest.
local function canOpenChest()
	if profile().paidRandomRestricted then return false end
	for _, chest in pairs(Catalog.Chests) do
		if (profile().gold or 0) >= chest.cost then return true end
	end
	return false
end

local function goldText() return number(profile().gold) end
local function levelText() return T("NV ", "LV ") .. tostring(profile().level or 1) end
local function levelProgress()
	local p = profile()
	local level = p.level or 1
	local floor = Rules.LevelXP(level)
	local span = (p.xpNext or floor) - floor
	if span <= 0 then return 1 end
	return math.clamp(((p.xp or 0) - floor) / span, 0, 1)
end

local function selectedLoadoutLine()
	local names = {}
	for _, id in ipairs(profile().loadout or {}) do table.insert(names, heroName(id)) end
	return table.concat(names, "  /  ")
end

local function heroSource(id)
	local templates = ReplicatedStorage:FindFirstChild("DoomHeroPortraits")
	local source = templates and (templates:FindFirstChild(id) or templates:FindFirstChild("Hero_" .. id))
	local lobby = workspace:FindFirstChild("DoomLobby")
	return source or (lobby and lobby:FindFirstChild("Hero_" .. id))
end

local function heroPortrait(parent, id, properties)
	return UI.heroPortrait(parent, id, heroSource(id), colorFor(id), properties)
end

-- Chest reveals, banners, confetti and counter pops. Purely presentation:
-- every number it shows was committed by the server first.
local celebrate = Celebrate.new({
	UI = UI, root = overlays, audio = audio, portrait = heroPortrait,
	language = function() return language end,
	lowFX = function() local settings = profile().settings return settings ~= nil and settings.lowFX == true end,
})
local resultsCelebrated = false

-- A quickbar slot: the hero's 3D portrait on a tile in its rarity colour,
-- the slot number in a corner and the price on the bottom edge. No name: a
-- name never fits a phone tile, and the portrait and colour already say who.
local function heroCard(parent, id, index, width, height, callback, equipped)
	local def = Catalog.Heroes[id]
	local rarity = Catalog.Rarities[def.rarity]
	local tint = rarity and UI.color(rarity.color) or colorFor(id)
	local button = UI.secondary(parent, "", callback, {
		Name = "HeroCard_" .. id, LayoutOrder = index,
		Size = UDim2.fromOffset(width, height), BackgroundColor3 = tint:Lerp(C.background, equipped and 0.25 or 0.45),
	})
	UI.stroke(button, index == 1 and C.gold or tint, index == 1 and 3.5 or 2.5)
	heroPortrait(button, id, {Position = UDim2.fromOffset(2, 1), Size = UDim2.new(1, -4, 1, -14)})
	local priceH = height < 62 and 17 or 20
	local price = UI.label(button, "💰" .. tostring(def.cost), {Name = "EnergyCost", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -2),
		Size = UDim2.new(1, -6, 0, priceH), BackgroundTransparency = 0.15, BackgroundColor3 = C.background, TextColor3 = C.gold,
		TextSize = height < 62 and 12 or 14, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Center})
	UI.corner(price, 8)
	local badge = UI.label(button, index == 1 and "★" or tostring(index), {Name = "SlotNumber", Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(18, 18),
		BackgroundColor3 = index == 1 and C.gold or C.background, BackgroundTransparency = 0.05, TextSize = 11,
		TextColor3 = index == 1 and C.ink or C.text, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Center})
	UI.corner(badge, 9)
	local count = UI.label(button, "", {Name = "PlacedCount", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -3, 0, 3), Size = UDim2.fromOffset(30, 16),
		BackgroundColor3 = C.background, BackgroundTransparency = 0.2, TextSize = 11, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Center, Visible = false})
	UI.corner(count, 8)
	local line = UI.frame(button, {Name = "SelectionLine", Position = UDim2.new(0, 6, 1, -3), Size = UDim2.new(1, -12, 0, 3), BackgroundColor3 = C.gold, BackgroundTransparency = equipped and 0 or 1})
	return button, price, line, count
end

-- The lobby panels live in Panels.luau (see its header).
local panels = Panels.new({
	state = function() return state end,
	language = function() return language end,
	contextPanel = function() return contextPanel end,
	C = C,
	Catalog = Catalog,
	Config = Config,
	L = L,
	MarketplaceService = MarketplaceService,
	Rules = Rules,
	T = T,
	UI = UI,
	act = act,
	at = at,
	audio = audio,
	board = board,
	celebrate = celebrate,
	contains = contains,
	copy = copy,
	heading = heading,
	heroName = heroName,
	heroPortrait = heroPortrait,
	kit = kit,
	levelProgress = levelProgress,
	mapName = mapName,
	number = number,
	pending = pending,
	player = player,
	productInfo = productInfo,
	profile = profile,
	request = request,
	routePreview = routePreview,
	screenSize = screenSize,
	showToast = showToast,
	smallText = smallText,
	openContext = function(...) return openContext(...) end,
	renderContext = function(...) return renderContext(...) end,
	fetchProducts = function(...) return fetchProducts(...) end,
	closeContext = function(...) return closeContext(...) end,
})
local contextBuilders, loadBoard = panels.contextBuilders, panels.loadBoard

fetchProducts = function()
	if productFetching then return end
	productFetching = true
	task.spawn(function()
		local fetched = false
		for _, group in ipairs({{kind = "pass", data = Catalog.Products.Passes}, {kind = "product", data = Catalog.Products.Consumables}, {kind = "hero", data = Catalog.Products.Heroes}}) do
			for key in pairs(group.data) do
				local cacheKey = group.kind .. ":" .. key
				if productInfo[cacheKey] == nil then
					local response = request("ProductInfo", {kind = group.kind, key = key}, true)
					-- No answer at all can be retried; a refusal means it is not on sale.
					productInfo[cacheKey] = response == nil and "retry" or response.ok and response.data or false
					fetched = true
					task.wait(0.18)
				end
			end
		end
		productFetching = false
		-- Re-render only when a price actually arrived. The shop panel calls
		-- fetchProducts every time it renders, so an unconditional re-render
		-- here rebuilt the open panel every 1.3 seconds, forever.
		if fetched and contextPanel and (contextPanel.kind == "shop" or contextPanel.kind == "premium") and state and state.phase == "Lobby" then renderContext() end
	end)
end

local function lobbyChrome(visible)
	for _,name in ipairs({"LobbyPill","ActiveBaseButton","SettingsButton","LobbyNavigation"}) do
		local item=main:FindFirstChild(name)
		if item then
			local size=screenSize()
			item.Visible=visible and not (name=="LobbyNavigation" and state and state.elevator and UI.sizeClass(size.X,size.Y).short)
		end
	end
	-- The side tracker yields to any open panel, modal or not.
	local tracker=main:FindFirstChild("QuestTracker")
	if tracker then tracker.Visible=visible and contextPanel==nil end
end

local function refreshNavigation()
	local selected=contextPanel and contextPanel.kind
	if selected=="hero" or selected=="squad" or selected=="bases" then selected="inventory" end
	if selected=="shop" then selected="premium" end
	for id,entry in pairs(refs.navigation or {}) do
		local active=selected==id
		entry.line.Visible=active
		if entry.badge and entry.count then
			local count=entry.count()
			entry.badge.Visible=count>0
			entry.badge.Text=tostring(math.min(count,9))
		end
	end
end

renderContext = function()
	lobbyChrome(true)
	refreshNavigation()
	if not contextPanel or not state or state.phase ~= "Lobby" then
		kit.contextRefreshPending=false
		if refs.context then refs.context:Destroy(); refs.context=nil end
		menuBlur(false)
		return
	end
	local panel=refs.context
	local body=panel and panel:FindFirstChild("ContextBody")
	local reuse=panel and panel.Parent and panel:GetAttribute("ContextKind")==contextPanel.kind and body
	if reuse then
		local focused=UserInputService:GetFocusedTextBox()
		while focused and focused~=panel do focused=focused.Parent end
		if focused==panel then kit.contextRefreshPending=true; return end
	end
	kit.contextRefreshPending=false
	if not reuse and panel then panel:Destroy(); panel=nil; body=nil end
	local size = screenSize()
	local slot=UI.contextLayout(size.X,size.Y,{wide=contextPanel.kind=="talents" or contextPanel.kind=="chests",elevator=state.elevator~=nil})
	lobbyChrome(not slot.modal)
	local theme=UI.Themes[contextPanel.kind] or UI.Themes.inventory
	local tint=theme.color
	if contextPanel.kind=="chests" and Catalog.Chests[kit.selectedChest].kind=="base" then tint=C.green end
	if not panel then panel=UI.roundFrame(main,{Name="ContextPanel",BackgroundColor3=C.panel,Active=true}) end
	panel.Position,panel.Size=at(slot),dims(slot)
	UI.stroke(panel,tint:Lerp(Color3.new(1,1,1),0.35),3)
	if reuse then
		for _,child in ipairs(panel:GetChildren()) do
			if child~=body and not child:IsA("UIComponent") then child:Destroy() end
		end
	end
	-- Header: a band in the screen's colour, the title in big outlined
	-- letters tilted like a sticker, and a round red close button.
	local band=UI.frame(panel,{Name="TitleRibbon",Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,0,0,60),BackgroundColor3=tint,Active=false})
	UI.corner(band,18)
	UI.candy(band)
	UI.stroke(band,C.ink,3)
	local gloss=UI.frame(band,{Name="Shine",Position=UDim2.new(0,64,0,6),Size=UDim2.new(1,-128,0.26,0),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=0.78,Active=false})
	UI.corner(gloss,8)
	refs.context = panel
	if not reuse then menuBlur(true) end
	panel:SetAttribute("ContextKind",contextPanel.kind)
	local titles = {hero = T("GALERIA DE HERÓIS", "HERO GALLERY"), skill = T("TREINAMENTO", "TRAINING"), shop = T("SUPRIMENTOS", "SUPPLIES"), quests = T("CENTRAL DE MISSÕES", "MISSION BOARD"), leaderboard = T("LENDAS DA RESISTÊNCIA", "RESISTANCE LEGENDS"), squad = T("FORMAÇÃO TÁTICA", "TACTICAL FORMATION"), settings = T("OPÇÕES", "SETTINGS")}
	titles.talents = T("ÁRVORE DE EVOLUÇÃO", "TALENT TREE")
	titles.guide = T("REFÚGIO DA AURORA", "AURORA REFUGE")
	titles.maps = T("ESCOLHA SEU MAPA", "CHOOSE YOUR MAP")
	titles.bases=T("MINHA BASE","MY BASE")
	titles.chests=Catalog.Chests[kit.selectedChest].kind=="base" and T("INVOCAR BASES","SUMMON BASES") or T("INVOCAR HERÓIS","SUMMON HEROES"); titles.premium=T("LOJA ROBUX","ROBUX SHOP"); titles.inventory=T("INVENTÁRIO","INVENTORY")
	titles.inventory=T("MEUS HERÓIS","MY HEROES"); titles.modes=T("ENCONTRE SEU PORTAL","FIND YOUR PORTAL"); titles.rewards=T("PRÊMIOS DIÁRIOS","DAILY REWARDS")
	-- A round medal and the close button sit on the corners like stickers.
	local medal=UI.frame(panel,{Name="TitleMedal",Position=UDim2.fromOffset(-6,-6),Size=UDim2.fromOffset(62,62),BackgroundColor3=C.ink,Active=false,ZIndex=3})
	UI.corner(medal,31)
	UI.stroke(medal,Color3.new(1,1,1),3)
	UI.illustration(medal,theme.icon,tint,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(46,46),ZIndex=3})
	UI.label(panel, titles[contextPanel.kind] or "DOOMSDAY", {Name="ContextTitle",Position = UDim2.fromOffset(66, 6), Size = UDim2.new(1, -128, 0, 48), TextColor3 = C.text, Font = UI.Fonts.display, TextSize = size.X < 560 and 22 or 28, Rotation = 0})
	local close=UI.button(panel, "×", closeContext, {Name="CloseContext",Position = UDim2.new(1, -46, 0, -6), Size = UDim2.fromOffset(52, 52), TextSize = 34,BackgroundColor3=C.red,ZIndex=3})
	close:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(0,26)
	if not body then
		body=UI.scroll(panel,{Name="ContextBody",Position=UDim2.fromOffset(14,70),Size=UDim2.new(1,-28,1,-82),ScrollBarImageColor3=tint})
		UI.list(body,10)
	end
	body.ScrollBarImageColor3=tint
	-- A refresh from the server rebuilds the rows, never the reader's place in
	-- the list: remember the scroll and put it back once the rows exist.
	local keepScroll=reuse and body.CanvasPosition or nil
	if reuse and contextPanel.kind=="chests" then
		contextPanel.summonViews=contextPanel.summonViews or {}
		for _,item in ipairs({{name="SummonCrates",key="crates"},{name="SummonOdds",key="odds"}}) do
			local scroll=body:FindFirstChild(item.name,true)
			local id=scroll and scroll:GetAttribute("SummonChestId")
			if id then
				contextPanel.summonViews[id]=contextPanel.summonViews[id] or {}
				contextPanel.summonViews[id][item.key]=scroll.CanvasPosition
			end
		end
	end
	body:SetAttribute("UpdatingCanvas",true)
	UI.clear(body)
	local builder = contextBuilders[contextPanel.kind]
	if builder then builder(body, contextPanel) end
	UI.finishScrollUpdate(body)
	if keepScroll then body.CanvasPosition=keepScroll end
	-- Keep panel geometry stable while Roblox lays out its scrolling content.
	contextPanel.animate=nil
end

-- Which physical model in the lobby a panel belongs to, so the panel can
-- close itself when the player walks away from it. Panels opened from the HUD
-- (squad, settings) have no anchor and simply stay until dismissed.
kit.CONTEXT_ANCHOR = {
	chests = {kind="ChestStand",attribute="ChestId",field="chestId"},
	shop = { kind = "ShopStand", attribute = "ShopKey", field = "shopKey" },
	quests = { kind = "Board", attribute = "BoardId", value = "quests" },
	leaderboard = { kind = "Board", attribute = "BoardId", value = "leaderboard" },
}

local function anchorPosition(kind, data)
	local spec = kit.CONTEXT_ANCHOR[kind]
	-- The arena's scoreboard kiosk opens the same leaderboard panel.
	if kind == "leaderboard" and data.board == "arena" then spec = { kind = "Scoreboard", attribute = "BoardId", value = "arena" } end
	if not spec then return nil end
	local wanted = spec.value or data[spec.field]
	if not wanted then return nil end
	local lobby = workspace:FindFirstChild("DoomLobby")
	if not lobby then return nil end
	for _, model in ipairs(lobby:GetChildren()) do
		if model:GetAttribute("Kind") == spec.kind and model:GetAttribute(spec.attribute) == wanted then
			local pivot = model.PrimaryPart
			return pivot and pivot.Position or nil
		end
	end
	return nil
end

openContext = function(kind, data)
	if not contextPanel or contextPanel.kind ~= kind then audio:Cue("open", 0.2) end
	if kind=="hero" then kit.heroDetailTab="power" end
	if kind~="inventory" and kind~="squad" then kit.inventoryView.leaderPick=false end
	data = data or {}
	if kind=="chests" and Catalog.Chests[data.chestId] then kit.selectedChest=data.chestId end
	kit.confirmChest = nil
	data.kind = kind
	data.animate=true
	data.anchor = not data.hud and anchorPosition(kind, data) or nil
	contextPanel = data
	if kind == "leaderboard" then board.data = nil; loadBoard() end
	if refs.firstVisitHint then refs.firstVisitHint.Visible = false end
	renderContext()
end

closeContext = function()
	contextPanel = nil
	kit.confirmChest = nil
	if refs.context then refs.context:Destroy(); refs.context = nil end
	menuBlur(false)
	lobbyChrome(true)
	refreshNavigation()
	if refs.firstVisitHint then refs.firstVisitHint.Visible = not (state and state.elevator) end
end

-- Per-viewer cosmetics on the shared lobby geometry: locked portals, unowned
-- heroes and unlearned skills get a translucent shroud (never a mutation of
-- the server's own parts), and equipped gear gets a highlight outline.
kit.shroudColor = Color3.fromRGB(8, 10, 14)
local function setShroud(model, locked, hint)
	local existing = model:FindFirstChild("LockShroud")
	if locked then
		if existing then return end
		local ok, cf, size = pcall(function()
			if model:GetAttribute("Kind")=="ModePortal" then return model.PrimaryPart.CFrame*CFrame.new(0,12,0),Vector3.new(32,26,13) end
			return model:GetBoundingBox()
		end)
		if not ok then return end
		local shroud = Instance.new("Part")
		shroud.Name, shroud.Anchored = "LockShroud", true
		shroud.CanCollide, shroud.CanTouch, shroud.CanQuery, shroud.CastShadow = false, false, false, false
		-- Lock state is communicated by the sign, not an opaque box over art.
		shroud.Material, shroud.Color, shroud.Transparency = Enum.Material.SmoothPlastic, kit.shroudColor, 1
		shroud.Size, shroud.CFrame = size + Vector3.new(0.4, 0.4, 0.4), cf
		shroud.Parent = model
		local billboard = Instance.new("BillboardGui")
		billboard.Name, billboard.Size = "LockHint", UDim2.fromOffset(220, 50)
		billboard.StudsOffset, billboard.MaxDistance = Vector3.new(0, size.Y / 2 + 2, 0), 36
		billboard.Adornee, billboard.Parent = model.PrimaryPart, model
		UI.label(billboard, T("BLOQUEADO: ", "LOCKED: ") .. (hint or ""), {Size = UDim2.fromScale(1, 1), TextColor3 = C.red, TextSize = 12, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true})
		return
	end
	if not existing then return end
	existing:Destroy()
	local billboard = model:FindFirstChild("LockHint")
	if billboard then billboard:Destroy() end
	local pivot = model.PrimaryPart
	if not pivot then return end
	local burst = Instance.new("Part")
	burst.Anchored, burst.CanCollide, burst.CanQuery, burst.CanTouch, burst.CastShadow = true, false, false, false, false
	burst.Shape, burst.Material, burst.Color, burst.Transparency = Enum.PartType.Cylinder, Enum.Material.Neon, C.green, 0.2
	burst.Size, burst.CFrame = Vector3.new(0.2, 1, 1), pivot.CFrame * CFrame.Angles(0, 0, math.pi / 2)
	burst.Parent = effects.folder
	TweenService:Create(burst, TweenInfo.new(0.6, Enum.EasingStyle.Quad), {Size = Vector3.new(0.2, 13, 13), Transparency = 1}):Play()
	task.delay(0.65, function() if burst.Parent then burst:Destroy() end end)
	audio:Cue("place", 0.05)
end

local function setEquippedHighlight(model, on)
	local highlight = model:FindFirstChildOfClass("Highlight")
	if on then
		if highlight then return end
		highlight = Instance.new("Highlight")
		highlight.FillTransparency, highlight.OutlineTransparency, highlight.OutlineColor = 1, 0.2, C.green
		highlight.Parent = model
	elseif highlight then
		highlight:Destroy()
	end
end

-- The mission board is shared scenery, but each viewer's client rewrites its
-- face locally with their own status, so it reads from across the deck
-- whether there is a reward waiting — the "next goal" the design asks for.
local function updateQuestBoard(lobby, p)
	local board = lobby:FindFirstChild("Board_quests")
	local panel = board and board:FindFirstChild("Panel")
	local surface = panel and panel:FindFirstChild("Board")
	local label = surface and surface:FindFirstChildOfClass("TextLabel")
	if not label then return end
	local active, ready = 0, 0
	for _, quest in pairs(p.quests or {}) do
		if not quest.claimed then
			active += 1
			if (quest.progress or 0) >= (quest.target or 1) then ready += 1 end
		end
	end
	local status
	if ready > 0 then
		status = tostring(ready) .. T(" PRONTA(S) PARA RESGATAR", " READY TO CLAIM")
	elseif active > 0 then
		status = tostring(active) .. T(" EM ANDAMENTO", " IN PROGRESS")
	else
		status = T("TREINE PARA RECEBER MISSÕES", "TRAIN TO RECEIVE MISSIONS")
	end
	label.Text = T("MISSÕES", "MISSIONS") .. "\n" .. status
	label.TextColor3 = ready > 0 and C.gold or Color3.fromRGB(230, 240, 244)
end

-- The lobby's props move: the collector drone spins and bobs in its case, the
-- AFK icons turn, and anything the world tags with Spin/Bob (the globe and its
-- orbits, the Helicarrier's rotors, the patrolling Quinjet, the prize chests)
-- or Sway (flags, hinged at the pole) comes alive. Purely local and cheap;
-- reduced effects leaves them still.
local lobbyProps = nil
local function animateLobby(dt)
	if not state or state.phase ~= "Lobby" then return end
	if profile().settings and profile().settings.lowFX then return end
	if not lobbyProps or (lobbyProps[1] and lobbyProps[1].part.Parent == nil) then
		lobbyProps = {}
		local lobby = workspace:FindFirstChild("DoomLobby")
		-- Each prop turns about a pivot: its own axes for a showroom piece, a
		-- vertical axis through SpinCenter (or its own centre) for tagged ones.
		local function add(child, pivot, spin, bob, rate)
			table.insert(lobbyProps, {part = child, pivot = pivot, offset = pivot:Inverse() * child.CFrame, spin = spin, bob = bob, rate = rate or 2, angle = 0})
		end
		local function collect(model, partName, spin, bob)
			for _, child in ipairs(model:GetChildren()) do
				if child.Name == partName and child:IsA("BasePart") then add(child, child.CFrame, spin, bob) end
			end
		end
		for _, model in ipairs(lobby and lobby:GetChildren() or {}) do
			if model.Name == "Shop_collector" then
				collect(model, "Drone", 1.8, 0.25)
				collect(model, "DroneRing", -1.2, 0.25)
			elseif model:GetAttribute("Kind") == "AfkZone" then
				collect(model, "AfkIcon", 1.4, 0.35)
			end
		end
		for _, child in ipairs(lobby and lobby:GetDescendants() or {}) do
			-- Portal vortices turn; each one a little differently.
			if child:IsA("SurfaceGui") and child.Name == "PortalSwirl" and child.Parent then
				local swirl = child:FindFirstChild("Swirl")
				if swirl then table.insert(lobbyProps, {part = child.Parent, swirl = swirl, spin = 0, angle = 0, speed = 110 + (child.Parent.Position.X % 7) * 8}) end
			end
			if child:IsA("BasePart") then
				local spin, bob, sway = child:GetAttribute("Spin"), child:GetAttribute("Bob"), child:GetAttribute("Sway")
				local pulse = child:GetAttribute("Pulse")
				if pulse then
					table.insert(lobbyProps, {part = child, pulse = pulse, size = child.Size, spin = 0, angle = 0, phase = child.Position.X * 0.3})
				elseif spin or bob then
					add(child, CFrame.new(child:GetAttribute("SpinCenter") or child.Position), spin or 0, bob or 0, child:GetAttribute("BobRate"))
				elseif sway then
					local hinge = child.CFrame * CFrame.new(-child.Size.X / 2, 0, 0)
					table.insert(lobbyProps, {part = child, pivot = hinge, offset = hinge:Inverse() * child.CFrame, spin = 0, bob = 0, rate = 2, angle = 0,
						sway = sway, phase = child.Position.X * 0.08 + child.Position.Z * 0.05})
				end
			end
		end
	end
	local now = os.clock()
	for _, prop in ipairs(lobbyProps) do
		prop.angle += dt * prop.spin
		if prop.swirl then
			prop.swirl.Rotation = (prop.swirl.Rotation + dt * prop.speed) % 360
		elseif prop.pulse then
			local k = 1 + math.sin(now * 3 + prop.phase) * prop.pulse * 0.4
			prop.part.Size = Vector3.new(prop.size.X, prop.size.Y * k, prop.size.Z * k)
		elseif prop.sway then
			prop.part.CFrame = prop.pivot * CFrame.Angles(0, math.sin(now * 1.6 + prop.phase) * prop.sway, 0) * prop.offset
		else
			prop.part.CFrame = prop.pivot * CFrame.new(0, math.sin(now * prop.rate) * prop.bob, 0) * CFrame.Angles(0, prop.angle, 0) * prop.offset
		end
	end
end

-- Each portal's sign says, for this viewer, what stepping in will start:
-- which sector (the campaign's next unbeaten one, today's daily), how many
-- waves, or what is still missing to unlock it.
local portalBoards={}
local function portalSign(model)
	local board=portalBoards[model]
	return board and board:FindFirstChild("MapRules",true)
end

local function updatePortal(model, p)
	local portalId = model:GetAttribute("PortalId") or model:GetAttribute("ModeId")
	local modeId = Rules.PortalMode(p, portalId)
	local unlocked = Rules.ModeUnlocked(p, modeId)
	setShroud(model, not unlocked, L(kit.modeLockHints[modeId]))
	local sign=model:FindFirstChild("MapBillboard")
	local source=sign and sign:FindFirstChild("MapBoard")
	-- Roblox does not render ViewportFrames under Workspace SurfaceGuis.
	-- Keep the authored template, render its own camera through PlayerGui.
	if source and not portalBoards[model] then
		local board=source:Clone()
		board.Name="PortalPicture_"..portalId
		board.Adornee,board.MaxDistance=sign,190
		board.Parent=player:WaitForChild("PlayerGui")
		portalBoards[model]=board
		source.Enabled=false
		local picture=board:FindFirstChild("MapPicture")
		if picture then
			-- Cameras do not replicate from the server. Construct the view locally.
			local camera=picture:FindFirstChild("PictureCamera") or Instance.new("Camera")
			camera.Name="PictureCamera"
			camera.CFrame=picture:GetAttribute("PictureCFrame") or CFrame.lookAt(Vector3.new(100,120,140),Vector3.new(0,7,0))
			camera.FieldOfView=picture:GetAttribute("PictureFieldOfView") or 40
			camera.Parent=picture
			picture.CurrentCamera=camera
		end
	end
	local board=portalBoards[model]
	if board then
		for _,node in ipairs(board:GetChildren()) do
			if node:IsA("TextLabel") then node.Text=node:GetAttribute(language=="en" and "LobbyTextEN" or "LobbyTextPT") or node.Text end
		end
	end
	local label = portalSign(model)
	if label then
		local mapId = Rules.PortalMap(portalId)
		local mode = Catalog.Modes[modeId]
		if not unlocked then
			label.Text = T("BLOQUEADO", "LOCKED") .. " • " .. L(kit.modeLockHints[modeId])
			label.TextColor3 = C.red
		elseif mode then
			local count = Rules.WaveCount(modeId, mapId)
			local waves = count == 0 and T("ONDAS INFINITAS", "ENDLESS WAVES") or (tostring(count) .. T(" ONDAS", " WAVES"))
			label.Text = Catalog.Upper(L(mode.name)) .. " • " .. waves
			label.TextColor3 = kit.modeTint[portalId] or C.green
		end
	end
	-- A first-time visitor sees one beacon, over the portal that starts
	-- training, visible from the spawn through the crowd.
	local beacon = model:FindFirstChild("StartHere")
	local wantBeacon = portalId == "training" and p.tutorialComplete ~= true
	if wantBeacon and not beacon and model.PrimaryPart then
		beacon = Instance.new("BillboardGui")
		beacon.Name, beacon.Size, beacon.AlwaysOnTop = "StartHere", UDim2.fromOffset(200, 64), true
		beacon.StudsOffset, beacon.MaxDistance = Vector3.new(0, 19, 0), 400
		beacon.Adornee, beacon.Parent = model.PrimaryPart, model
		UI.label(beacon, T("COMECE AQUI", "START HERE") .. "\n▼", {Size = UDim2.fromScale(1, 1), TextColor3 = C.gold, TextSize = 20, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = true, TextStrokeTransparency = 0.3})
	elseif beacon and not wantBeacon then
		beacon:Destroy()
	end
end

local localizedLobby, localizedLanguage, localizedLabels
updateWorldCosmetics = function()
	for model,board in pairs(portalBoards) do
		if not model.Parent then board:Destroy(); portalBoards[model]=nil end
	end
	if not state or state.phase ~= "Lobby" then return end
	local lobby = workspace:FindFirstChild("DoomLobby")
	if not lobby then
		-- The lobby is built server-side at boot, but a slow client can get its
		-- first snapshot before that model replicates. Without this retry the
		-- shrouds would never appear and every portal would look unlocked.
		if not kit.cosmeticsRetryPending then
			kit.cosmeticsRetryPending = true
			task.delay(1, function()
				kit.cosmeticsRetryPending = false
				updateWorldCosmetics()
			end)
		end
		return
	end
	local p = profile()
	if localizedLobby~=lobby then
		localizedLobby,localizedLanguage,localizedLabels=lobby,nil,{}
		for _,obj in ipairs(lobby:GetDescendants()) do
			if obj:GetAttribute("LobbyTextPT") then table.insert(localizedLabels,obj) end
			if obj.Name=="QueueStatus" and obj:IsA("TextLabel") then
				local function localizeQueue()
					local value=obj:GetAttribute(language=="en" and "LobbyTextEN" or "LobbyTextPT")
					if value and obj.Text~=value then obj.Text=value end
				end
				obj:GetAttributeChangedSignal("LobbyTextPT"):Connect(localizeQueue)
				obj:GetAttributeChangedSignal("LobbyTextEN"):Connect(localizeQueue)
				obj:GetPropertyChangedSignal("Text"):Connect(localizeQueue)
			end
		end
	end
	-- Queue attributes change on the server while a player is standing still.
	-- Localize them with every lobby snapshot, not only on a language change.
	localizedLanguage=language
	for _,obj in ipairs(localizedLabels) do
			local value=obj:GetAttribute(language=="en" and "LobbyTextEN" or "LobbyTextPT")
			if obj:IsA("TextLabel") then obj.Text=value
			elseif obj:IsA("ProximityPrompt") then obj.ObjectText=value; obj.ActionText=T("Abrir","Open") end
	end
	updateQuestBoard(lobby, p)
	for _, model in ipairs(lobby:GetChildren()) do
		local kind = model:GetAttribute("Kind")
		if kind == "ModePortal" then
			updatePortal(model, p)
		elseif kind == "HeroPedestal" then
			local heroId = model:GetAttribute("HeroId")
			local templates = ReplicatedStorage:FindFirstChild("DoomHeroPortraits")
			UI.rememberHero(heroId, templates and templates:FindFirstChild(heroId) or model)
			local owned = p.heroes and p.heroes[heroId] ~= nil
			setShroud(model, not owned, T("Ainda não comprado", "Not purchased yet"))
			setEquippedHighlight(model, owned and contains(p.loadout, heroId))

		end
	end
end

-- The elevator card, shown only while this player stands in a portal. The
-- countdown ticks locally from the server's last word and re-syncs on every
-- snapshot; Leave and the first rider's sector switch are plain intents.
kit.elevatorDeadline, kit.elevatorSignature = nil, nil

local function elevatorCountText()
	if not kit.elevatorDeadline then return "" end
	local left = math.max(0, math.ceil(kit.elevatorDeadline - os.clock()))
	return left > 0 and tostring(left) or "…"
end

renderElevator = function()
	local e = state and state.phase == "Lobby" and state.elevator or nil
	if e then
		local deadline = os.clock() + (tonumber(e.remaining) or 0)
		if not kit.elevatorDeadline or math.abs(deadline - kit.elevatorDeadline) > 1.2 then kit.elevatorDeadline = deadline end
	else
		kit.elevatorDeadline = nil
	end
	local signature = e and HttpService:JSONEncode({e.portalId, e.queueId, e.slot, e.departing, e.modeId, e.mapId or "random", #(e.riders or {}), e.host, e.carId, profile().equippedBase, language}) or nil
	if signature == kit.elevatorSignature and (refs.elevator ~= nil) == (e ~= nil) then return false end
	kit.elevatorSignature = signature
	-- The pad this player rides lights up: a column of light and rising sparks
	-- in the portal's colour, flaring white when the queue departs.
	local glow = effects.rideGlow
	local rideKey = e and tostring(e.queueId or e.portalId) or nil
	if glow and glow.key ~= rideKey then glow.part:Destroy(); effects.rideGlow, glow = nil, nil end
	if e and not glow then
		local lobby = workspace:FindFirstChild("DoomLobby")
		local station = lobby and lobby:FindFirstChild("Portal_" .. tostring(e.portalId))
		local pad = station and station:FindFirstChild((e.slot or 1) == 1 and "Pad" or "Pad" .. tostring(e.slot))
		if pad then
			local column = Instance.new("Part")
			column.Name, column.Shape, column.Material, column.Color = "RideColumn", Enum.PartType.Cylinder, Enum.Material.Neon, pad.Color
			column.Size, column.CFrame = Vector3.new(14, 7.4, 7.4), CFrame.new(pad.Position + Vector3.new(0, 7.1, 0)) * CFrame.Angles(0, 0, math.pi / 2)
			column.Transparency, column.Anchored, column.CanCollide, column.CanQuery, column.CanTouch, column.CastShadow = 0.8, true, false, false, false, false
			column.Parent = effects.folder
			local sparks
			if not (profile().settings and profile().settings.lowFX) then
				sparks = Instance.new("ParticleEmitter")
				sparks.Color, sparks.LightEmission, sparks.LightInfluence = ColorSequence.new(pad.Color, Color3.new(1, 1, 1)), 1, 0
				sparks.Size, sparks.Transparency = NumberSequence.new(0.55, 0.05), NumberSequence.new(0.1, 1)
				sparks.Rate, sparks.Speed, sparks.Lifetime = 26, NumberRange.new(5, 9), NumberRange.new(0.9, 1.5)
				sparks.EmissionDirection, sparks.SpreadAngle = Enum.NormalId.Right, Vector2.new(8, 8)
				sparks.Parent = column
			end
			effects.rideGlow = { key = rideKey, part = column, sparks = sparks }
			audio:Cue("place", 0.1)
		end
	end
	glow = effects.rideGlow
	if glow and e and e.departing and not glow.flared then
		glow.flared = true
		glow.part.Transparency, glow.part.Color = 0.35, glow.part.Color:Lerp(Color3.new(1, 1, 1), 0.5)
		if glow.sparks then glow.sparks.Rate = 140 end
		audio:Cue("wave", 0.2)
	end
	if refs.elevator then refs.elevator:Destroy(); refs.elevator, refs.elevatorCount = nil, nil end
	if refs.firstVisitHint then refs.firstVisitHint.Visible = e == nil and contextPanel == nil end
	if not e then return true end
	local size = screenSize()
	local hud = UI.lobbyLayout(size.X, size.Y)
	local compact, r = hud.class.compact, hud.elevator
	local tint = kit.modeTint[e.portalId] or C.green
	local card = UI.roundFrame(main, {Name = "ElevatorCard", Position = at(r), Size = dims(r), BackgroundColor3 = C.background}, tint)
	refs.elevator = card
	-- The plan before anyone is committed: map, mode, length, final boss and
	-- what a win pays in lobby Gold.
	local title=mapName(e.mapId).." • "..T("FILA ","QUEUE ")..tostring(e.slot or 1)
	local waves=Rules.WaveCount(e.modeId,e.mapId)
	local map=Catalog.Maps[e.mapId]
	local boss=map and Catalog.Enemies[e.modeId=="tutorial" and "lizard" or map.bossId]
	local prize=e.modeId=="ranked" and T("🏆 25/onda","🏆 25/wave") or ("🏆 "..number(Rules.RunGold(e.modeId,e.mapId,waves,true)))
	local summary=(waves==0 and T("SEM FIM","ENDLESS") or (tostring(waves).." "..T("ONDAS","WAVES")))
		..((boss and waves>0) and ("  •  "..T("CHEFE: ","BOSS: ")..Catalog.Upper(L(boss.name))) or "").."  •  "..prize
	UI.label(card, Catalog.Upper(title), {Name="PortalDestination",Position = UDim2.fromOffset(14, 3), Size = UDim2.new(1, -90, 0, 22), TextWrapped=true,TextSize = compact and 12 or 15, Font = UI.Fonts.display, TextColor3 = tint})
	UI.label(card, summary, {Name="PortalSummary",Position = UDim2.fromOffset(14, 25), Size = UDim2.new(1, -90, 0, 18), TextSize = compact and 10 or 12, Font = Enum.Font.GothamBold, TextColor3 = C.muted})
	refs.elevatorCount = UI.label(card, elevatorCountText(), {Position = UDim2.new(1, -80, 0, 4), Size = UDim2.fromOffset(66, 40), TextSize = compact and 28 or 34, Font = Enum.Font.GothamBlack, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right})
	local rowH = compact and 34 or 36
	local rowY = r.h - rowH - 8
	local leaveW = compact and 76 or 92
	local leave=UI.button(card, T("SAIR", "LEAVE"), function() act("ElevatorLeave", {}) end, {Name="ElevatorLeave",Position = UDim2.new(1, -(leaveW + 12), 0, rowY), Size = UDim2.fromOffset(leaveW, rowH), BackgroundColor3 = C.red, TextColor3 = C.text, TextSize = 13})
	if e.departing then UI.disabled(leave) end
	local statusRight = leaveW + 28
	-- Whoever stepped on first may skip the rest of the countdown.
	if e.host and not e.departing then
		local startW = compact and 96 or 120
		UI.button(card, T("COMEÇAR", "START"), function() act("ElevatorStart", {}) end, {Name = "ElevatorStartNow", Position = UDim2.new(1, -(leaveW + startW + 20), 0, rowY), Size = UDim2.fromOffset(startW, rowH), BackgroundColor3 = C.blue, TextSize = 13})
		statusRight += startW + 8
	end
	local names = {}
	for _, rider in ipairs(e.riders or {}) do table.insert(names, rider.name) end
	local status = tostring(#names) .. "/" .. tostring(e.max or 4) .. "  " .. T("jogadores", "players") .. "  •  " .. table.concat(names, ", ")
	UI.label(card, status, {Position = UDim2.fromOffset(14, rowY), Size = UDim2.new(1, -(14 + statusRight), 0, rowH), TextSize = compact and 11 or 12, TextColor3 = C.muted})
	return true
end

-- Persistent illustrated shortcuts complement the walk-in shops. Layout
-- reserves space for both the dock and the portal's countdown card.
renderLobby = function()
	local size = screenSize()
	local hud = UI.lobbyLayout(size.X, size.Y)
	local compact = hud.class.compact
	-- Gold and level float over the world like stickers: a big coin, a big
	-- outlined number, and the level in a star with its XP bar underneath.
	local pill = UI.frame(main, {Name = "LobbyPill", Position = at(hud.pill), Size = dims(hud.pill), BackgroundColor3 = C.ink, BackgroundTransparency = 0.2})
	UI.corner(pill, 24)
	UI.stroke(pill, C.gold, 2.5)
	UI.illustration(pill,"coin",C.gold,{Position=UDim2.fromOffset(2,2),Size=UDim2.fromOffset(44,44)})
	refs.gold = UI.label(pill, goldText(), {Name = "GoldAmount", Position = UDim2.fromOffset(50, 0), Size = UDim2.new(1, -100, 1, -6), TextSize = compact and 21 or 27, Font = UI.Fonts.display, TextColor3 = C.gold})
	local star = UI.illustration(pill,"star",C.violet,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-2,0,0),Size=UDim2.fromOffset(46,46)})
	star.ZIndex = 2
	refs.commander = UI.label(pill, levelText(), {Position = UDim2.new(1, -48, 0, 0), Size = UDim2.new(0, 46, 1, -2), TextSize = compact and 11 or 13, Font = UI.Fonts.display, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3})
	local track = UI.frame(pill, {Position = UDim2.new(0, 50, 1, -10), Size = UDim2.new(1, -100, 0, 6), BackgroundColor3 = C.background})
	UI.corner(track, 3)
	refs.levelBar = UI.frame(track, {Size = UDim2.fromScale(levelProgress(), 1), BackgroundColor3 = C.violet})
	UI.corner(refs.levelBar, 3)
	UI.button(pill, "", function() openContext("talents", {}) end, {Name = "OpenTalentTree", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
	-- Round corner buttons: the equipped base (its own little picture) and settings.
	local equipped = Catalog.Bases[profile().equippedBase or "outpost"] or Catalog.Bases.outpost
	UI.roundIcon(main, "ActiveBaseButton", T("BASE", "BASE"), C.green, function(disc)
		UI.basePortrait(disc, equipped, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.54), Size = UDim2.fromScale(0.74, 0.6)})
	end, function() openContext("bases", {}) end, {Position = at(hud.squad), Size = dims(hud.squad)})
	UI.roundIcon(main, "SettingsButton", T("OPÇÕES", "SETTINGS"), C.blue, "gear", function() openContext("settings", {}) end, {Position = at(hud.settings), Size = dims(hud.settings)})

	-- The big round buttons: a column on the left of wide screens, a dock at
	-- the bottom of phones. Each carries a count bubble when something waits.
	local dock=UI.frame(main,{Name="LobbyNavigation",Position=at(hud.navigation),Size=dims(hud.navigation),BackgroundTransparency=1})
	local function readyQuests()
		local ready=0
		for _,quest in pairs(profile().quests or {}) do
			if not quest.claimed and (quest.progress or 0)>=(quest.target or 1) then ready+=1 end
		end
		return ready
	end
	local nav={
		{"inventory",T("HERÓIS","HEROES"),C.coral,"hero"},
		{"talents",T("EVOLUÇÃO","TALENTS"),C.violet,"star",function() return profile().talentPoints or 0 end},
		{"premium",T("LOJA","SHOP"),C.green,"shop"},
		{"rewards",T("PRÊMIOS","GIFTS"),C.pink,"gift",function() return tonumber(profile().rewards and profile().rewards.claimable) or 0 end},
		{"quests",T("MISSÕES","QUESTS"),C.gold,"scroll",readyQuests},
	}
	refs.navigation={}
	refs.rewardsBadge=nil
	for i,entry in ipairs(nav) do
		local position,cell
		if hud.column then position,cell=UDim2.new(0,0,(i-1)/#nav,0),UDim2.new(1,0,1/#nav,-8)
		else position,cell=UDim2.new((i-1)/#nav,0,0,0),UDim2.new(1/#nav,-6,1,0) end
		local button,disc=UI.roundIcon(dock,"Nav_"..entry[1],entry[2],entry[3],entry[4],function() openContext(entry[1],{hud=true}) end,{Position=position,Size=cell})
		local badge
		if entry[5] then
			badge=UI.badge(button,entry[1]=="rewards" and "RewardsBadge" or entry[1]=="talents" and "AvailableTalentPoints" or "ReadyQuests","")
			local count=entry[5]()
			badge.Visible,badge.Text=count>0,tostring(math.min(count,9))
			if entry[1]=="rewards" then refs.rewardsBadge=badge end
		end
		local line=UI.frame(button,{Name="SelectedTab",AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,2),Size=UDim2.new(0.7,0,0,4),BackgroundColor3=entry[3],Visible=false})
		UI.corner(line,2)
		refs.navigation[entry[1]]={button=button,line=line,tint=entry[3],badge=badge,count=entry[5],icon=disc,iconX=0,phase=i*0.9}
	end

	-- Nico, the HQ's little robot, gives the next step in a speech strip.
	local newcomer=not profile().tutorialComplete
	refs.firstVisitHint=UI.button(main,"",function()
		if newcomer then act("StartTraining",{}) else openContext("guide",{}) end
	end,{
		Name="FirstVisitHint",Position=at(hud.hint),Size=dims(hud.hint),BackgroundColor3=newcomer and C.green or C.ink,BackgroundTransparency=newcomer and 0 or 0.2,
	})
	do
		local hint=refs.firstVisitHint
		hint:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(0,22)
		hint:FindFirstChild("Border").Color=C.gold
		UI.illustration(hint,"guide",C.gold,{Position=UDim2.fromOffset(4,-12),Size=UDim2.fromOffset(50,50)})
		local p=profile()
		local tip=not p.tutorialComplete and T("▶ COMEÇAR TREINO  •  ganhe um baú!","▶ START TRAINING  •  win a chest!")
			or (canOpenChest() and T("Você tem Ouro para um baú! Vá até a INVOCAÇÃO.","You have Gold for a chest! Visit the SUMMON halls."))
			or T("Toque aqui: o Nico mostra o caminho.","Tap here: Nico shows the way.")
		UI.label(hint,tip,{Name="GuideTip",Position=UDim2.fromOffset(58,0),Size=UDim2.new(1,-66,1,0),TextSize=compact and 14 or 16,Font=UI.Fonts.display,TextColor3=C.cream,TextWrapped=true,TextTruncate=Enum.TextTruncate.None})
	end
	refs.firstVisitHint.Visible=not state.elevator and contextPanel==nil

	kit.elevatorSignature = nil
	renderElevator()
	renderContext()
	updateWorldCosmetics()
end

local function previewPart(name, size, tint, transparency)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Color, p.Transparency = name, size, tint, transparency
	p.Material, p.Anchored = Enum.Material.ForceField, true
	p.CanCollide, p.CanTouch, p.CanQuery, p.CastShadow = false, false, false, false
	p.Parent = effects.folder
	return p
end

local function rangeRing(existing, position, radius, tint)
	local ring = existing or previewPart("RangePreview", Vector3.one, tint, 0.7)
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.10, radius * 2, radius * 2)
	ring.Color = tint
	ring.CFrame = CFrame.new(position.X, 0.18, position.Z) * CFrame.Angles(0, 0, math.pi / 2)
	return ring
end

local function clearPlacement()
	selectedHero, selectedSkill, selectedPosition, placementPinned = nil, nil, nil, false
	if ghost then ghost:Destroy(); ghost = nil end
	ghostParts, ghostLift = nil, nil
	if placementRing then placementRing:Destroy(); placementRing = nil end
	buildOverlay:Clear()
	if refs.placement then refs.placement.Visible = false end
	if refs.hint then refs.hint.Visible = false end
end

local function distanceToSegment(point, a, b)
	local delta = b - a
	local t = delta:Dot(delta) > 0 and math.clamp((point - a):Dot(delta) / delta:Dot(delta), 0, 1) or 0
	return (point - (a + delta * t)).Magnitude
end

-- The same placement rule the server applies (Rules.BuildCheck), plus the
-- wallet and the hero limit, so the preview never promises what the server
-- refuses. Returns true, or false and the reason key.
kit.placementReason = nil
local function positionValid(position)
	if not state or not state.match or not selectedHero then return false, "bounds" end
	local match = state.match
	local towers, mine, same = {}, 0, 0
	for _, tower in ipairs(match.towers or {}) do
		if typeof(tower.position) == "Vector3" then table.insert(towers, tower.position) end
		if tower.ownerId == player.UserId then
			mine += 1
			if tower.heroId == selectedHero then same += 1 end
		end
	end
	local ok, reason = Rules.BuildCheck(match.mapId, position, towers, Config, match.blockers)
	if not ok then return false, reason end
	if mine >= (match.towerLimit or 16) then return false, "limit" end
	if same >= Rules.HeroLimit(selectedHero) then return false, "unitLimit" end
	local hero = Catalog.Heroes[selectedHero]
	local discount = math.clamp(Rules.CardTotals(match.cards).discount or 0, 0, 0.5)
	if hero and (match.cash or 0) < math.floor(hero.cost * (1 - discount)) then return false, "cash" end
	return true
end

-- The range a new tower of this hero really gets: mastery, talents and cards.
local function effectiveRange(heroId)
	local perm = Rules.PermanentModifiers(profile(), heroId)
	local cards = Rules.CardTotals(state and state.match and state.match.cards)
	local stats = Rules.TowerStats(heroId, 1, nil, { rangeBonus = perm.rangeBonus + (cards.range or 0), damageBonus = perm.damageBonus, attackSpeedBonus = perm.attackSpeedBonus })
	return stats.range
end

local function raycast(screenPosition, groundOnly)
	local camera = workspace.CurrentCamera
	if not camera then return nil end
	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	local world = workspace:FindFirstChild("DoomWorld")
	if groundOnly and world and world:FindFirstChild("BuildZones") then
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {world.BuildZones, world:FindFirstChild("Paths") or world.BuildZones}
	else
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = player.Character and {player.Character, effects.folder} or {effects.folder}
	end
	return workspace:Raycast(ray.Origin, ray.Direction * 1500, params)
end

local function updatePreview(position)
	selectedPosition = Vector3.new(position.X, 0, position.Z)
	local radius = selectedHero and effectiveRange(selectedHero) or (state.match and state.match.ability and state.match.ability.radius or 20)
	if selectedHero then placementValid, kit.placementReason = positionValid(selectedPosition) else placementValid, kit.placementReason = true, nil end
	local tint = placementValid and C.green or C.red
	placementRing = rangeRing(placementRing, selectedPosition, radius, tint)
	-- While a hero is being placed, the ground that refuses a tower is tinted.
	buildOverlay:Update(selectedHero and state.match or nil)
	if selectedHero then
		if not ghost then
			ghost = UI.heroModel(effects.folder, selectedHero, heroSource(selectedHero))
			ghost.Name = "HeroPlacementPreview"
			local bounds, size = ghost:GetBoundingBox()
			ghostLift = size.Y * 0.5 - bounds.Position.Y + 0.15
			ghostParts = {}
			for _, part in ipairs(ghost:GetDescendants()) do
				if part:IsA("BasePart") then
					table.insert(ghostParts, {part = part, cf = part.CFrame, color = part.Color})
					part.Transparency = 0.35
				end
			end
		end
		for _, item in ipairs(ghostParts or {}) do
			item.part.CFrame = CFrame.new(selectedPosition + Vector3.new(0, ghostLift or 0, 0)) * item.cf
			item.part.Color = placementValid and item.color or item.color:Lerp(C.red, 0.65)
		end
	end
	if refs.confirm then
		refs.confirm.BackgroundColor3 = placementValid and C.green or C.red
		local reason = kit.placementReason and Rules.BuildReasons[kit.placementReason]
		refs.confirm.Text = placementValid and T("CONFIRMAR", "CONFIRM") or Catalog.Upper(reason and L(reason) or T("POSIÇÃO INVÁLIDA", "INVALID POSITION"))
	end
	if refs.placement then refs.placement.Visible = true end
end

local function chooseHero(id)
	if not activeMatch() then return end
	clearPlacement()
	selectedTower, selectedHero = nil, id
	if refs.towerPanel then refs.towerPanel.Visible = false end
	if towerRing then towerRing:Destroy(); towerRing = nil end
	refs.hint.Text = heroName(id) .. " • " .. T("Toque no chão e confirme a posição.", "Select a ground position and confirm.")
	refs.hint.Visible = true
	refs.placement.Visible = true
	refs.confirm.Text = T("SELECIONE O CHÃO", "SELECT GROUND")
	updateMatch()
end

local function chooseSkill(id)
	if not activeMatch() then return end
	local ability=state.match.ability
	if not ability or ability.id~=id then return end
	local cooldown = ability.cooldown or 0
	if cooldown > 0 then showToast(T("Habilidade recarregando.", "Ability is recharging."), true); return end
	if ability.target == "self" then act("CastSkill", {skillId = id}); return end
	clearPlacement()
	selectedSkill, selectedTower = id, nil
	if refs.towerPanel then refs.towerPanel.Visible = false end
	if towerRing then towerRing:Destroy(); towerRing = nil end
	refs.hint.Text = L(Catalog.Abilities[id].name) .. " • " .. (ability.target == "tower" and T("Selecione uma torre sua.", "Select one of your towers.") or T("Selecione uma região e confirme.", "Select a region and confirm."))
	refs.hint.Visible = true
	refs.placement.Visible = true
	refs.confirm.Text = T("SELECIONE UM ALVO", "SELECT A TARGET")
end

-- 2x and auto-skip are votes the server counts; the settings write only
-- remembers the choice for the next match. Neither ever changes a rule here.
local function toggleSpeed()
	if not activeMatch() then return end
	-- 1x -> 2x -> 3x (with the pass) -> 1x.
	local current = state.match.speedVote or 1
	local wanted = current == 1 and 2 or (current == 2 and profile().passes and profile().passes.speed3) and 3 or 1
	act("SetSpeed", {speed = wanted}, function() audio:Cue("wave", 0.1) end)
	act("Settings", {fastForward = wanted == 2})
end

local function toggleAutoSkip()
	if not activeMatch() then return end
	local wanted = not state.match.autoSkip
	act("SetAutoSkip", {on = wanted})
	act("Settings", {autoSkip = wanted})
end

local function confirmPlacement()
	if selectedHero and selectedPosition and placementValid then
		local hero, position = selectedHero, selectedPosition
		act("PlaceTower", {heroId = hero, position = position}, function(reply)
			audio:Cue("place", 0.05); clearPlacement()
			-- The price the server actually charged, floating off the wallet.
			if reply and tonumber(reply.cost) and refs.energy and refs.energy.Parent then
				celebrate:Float("-" .. number(reply.cost) .. " 💰", refs.energy, C.red)
			end
		end)
	elseif selectedSkill and selectedPosition and Catalog.Abilities[selectedSkill].target ~= "tower" then
		local skill, position = selectedSkill, selectedPosition
		act("CastSkill", {skillId = skill, position = position}, function() clearPlacement() end)
	end
end

local function findTower(id)
	for _, tower in ipairs(state and state.match and state.match.towers or {}) do if tostring(tower.id) == tostring(id) then return tower end end
	return nil
end

local function selectTower(id)
	local tower = findTower(id)
	if not tower then return end
	if selectedSkill and Catalog.Abilities[selectedSkill].target == "tower" then
		if tower.ownerId ~= player.UserId then showToast(T("Selecione uma torre sua.", "Select one of your towers."), true); return end
		act("CastSkill", {skillId = selectedSkill, towerId = tower.id}, function() clearPlacement() end)
		return
	end
	clearPlacement()
	selectedTower = tower.id
	refs.towerKey = nil
	updateMatch()
end

-- These must be the server's own values: MatchService accepts exactly
-- First/Last/Strongest/Nearest. The lowercase spelling this used to send was
-- refused on every press, so targeting could never be changed from the HUD.
kit.priorityNames = {First = {pt = "Primeiro", en = "First"}, Last = {pt = "Último", en = "Last"}, Strongest = {pt = "Mais forte", en = "Strongest"}, Nearest = {pt = "Mais próximo", en = "Nearest"}}
kit.priorityOrder = {"First", "Last", "Strongest", "Nearest"}

local function currentMatchLayout()
	local size = screenSize()
	return UI.matchLayout(size.X, size.Y, {skills = 1, vip = profile().passes ~= nil and profile().passes.vip == true})
end

local function closeTowerPanel()
	selectedTower = nil
	if refs.towerPanel then refs.towerPanel.Visible = false end
	if towerRing then towerRing:Destroy(); towerRing = nil end
end

-- Two arrangements of the same controls, chosen by UI.matchLayout: a single
-- tall column where the screen has height to spare, and a short two-row
-- panel for a phone on its side, where the old 306px column started above
-- the top of the screen and took the upgrade button with it.
local function towerStatsText(tower, wide)
	-- One stat as "now -> next": the next value in green, as the server sent it.
	local function statChange(icon, now, after, format)
		local text = icon .. " " .. format(now or 0)
		if after and math.abs((after or 0) - (now or 0)) > 0.001 then
			text ..= ' <font color="#6BE38A">→ ' .. format(after) .. "</font>"
		end
		return text
	end
	local now, nextStats = tower.base or tower, tower.next
	local function whole(v) return number(math.floor(v + 0.5)) end
	local function tenth(v) return string.format("%.1f", v) end
	local function rate(v) return string.format("%.2f", v) end
	local lines = {
		statChange("⚔", tower.damage, nextStats and nextStats.damage * ((tower.damage or 0) / math.max(0.001, now.damage or 1)), whole),
		statChange("◎", tower.range, nextStats and nextStats.range, tenth),
		statChange("⚡", tower.rate, nextStats and nextStats.rate * ((tower.rate or 0) / math.max(0.001, now.rate or 1)), rate),
	}
	local hero = Catalog.Heroes[tower.heroId]
	if hero and hero.pickup then table.insert(lines, "🧲 " .. hero.pickup) end
	return table.concat(lines, wide and "    " or "\n")
end

local function towerPanel(tower)
	if refs.towerPanel then refs.towerPanel:Destroy() end
	local layout = refs.layout or currentMatchLayout()
	local slot, wide = layout.tower, layout.towerVariant == "wide"
	local w = slot.w
	local panel = UI.roundFrame(main, {Position = at(slot), Size = dims(slot), BackgroundColor3 = C.background})
	refs.towerPanel, refs.towerWide = panel, wide
	local def = Catalog.Heroes[tower.heroId]
	local own = tower.ownerId == player.UserId
	local half = math.floor((w - 30) / 2)
	local levelText = T("Melhoria ", "Upgrade ") .. tostring(tower.level) .. "/5" .. (tower.branch and "  •  " .. L(def.branches[tower.branch].name) or "")
	UI.secondary(panel, "×", closeTowerPanel, {Name="CloseTower",Position = UDim2.fromOffset(w - 46, 4), Size = UDim2.fromOffset(40, 40), TextSize = 24})
	local actionY, actionH, rowY, rowH
	-- Every stat reads as now -> after (the server's preview of the next
	-- upgrade), in text a thumb-length away can still read.
	if wide then
		local nameW = math.floor((w - 66) * 0.55)
		UI.label(panel, heroName(tower.heroId), {Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(nameW, 22), TextSize = 16, Font = UI.Fonts.display, TextColor3 = colorFor(tower.heroId), TextTruncate = Enum.TextTruncate.AtEnd})
		UI.label(panel, levelText, {Position = UDim2.fromOffset(12 + nameW + 4, 8), Size = UDim2.fromOffset(w - 66 - nameW - 4, 18), TextSize = 12, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right, TextTruncate = Enum.TextTruncate.AtEnd})
		refs.towerStats = UI.label(panel, "", {Name = "TowerStats", Position = UDim2.fromOffset(12, 29), Size = UDim2.fromOffset(w - 24, 18), TextSize = 13, Font = UI.Fonts.display, RichText = true, TextTruncate = Enum.TextTruncate.AtEnd})
		actionY, actionH, rowY, rowH = 50, 40, 94, 34
	else
		UI.label(panel, heroName(tower.heroId), {Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(w - 54, 24), TextSize = 18, Font = UI.Fonts.display, TextColor3 = colorFor(tower.heroId), TextTruncate = Enum.TextTruncate.AtEnd})
		UI.label(panel, levelText, {Position = UDim2.fromOffset(12, 32), Size = UDim2.fromOffset(w - 54, 18), TextSize = 13, TextColor3 = C.muted, TextTruncate = Enum.TextTruncate.AtEnd})
		refs.towerStats = UI.label(panel, "", {Name = "TowerStats", Position = UDim2.fromOffset(12, 54), Size = UDim2.fromOffset(w - 24, 62), TextSize = 15, Font = UI.Fonts.display, RichText = true, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top, LineHeight = 1.05})
		actionY, actionH, rowY, rowH = 122, 46, 176, 40
	end
	local function note(text)
		UI.label(panel, text, {Position = UDim2.fromOffset(12, actionY), Size = UDim2.fromOffset(w - 24, (own and rowY - 6 or slot.h - 6) - actionY), TextSize = 11, TextColor3 = C.muted, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top})
	end
	if not own then
		note(T("Torre de um aliado. Somente o dono pode modificá-la.", "Ally tower. Only its owner can modify it."))
		return
	end
	if tower.level < 4 then
		local upgrade = UI.button(panel, T("MELHORAR  •  ", "UPGRADE  •  ") .. "💰 " .. number(tower.upgradeCost), function() act("UpgradeTower", {towerId = tower.id}) end, {Name = "TowerUpgrade", Position = UDim2.fromOffset(12, actionY), Size = UDim2.fromOffset(w - 24, actionH), TextSize = wide and 15 or 18, BackgroundColor3 = C.green})
		if (state.match and state.match.cash or 0) < (tower.upgradeCost or 0) then upgrade.BackgroundColor3 = C.card end
	elseif tower.level == 4 then
		-- Two specializations side by side, each with its new damage.
		for branch = 1, 2 do
			local after = tower.branches and tower.branches[branch]
			local label = L(def.branches[branch].name) .. "\n" .. (after and ("⚔ " .. number(math.floor(after.damage + 0.5)) .. "  •  ") or "") .. "💰 " .. number(tower.upgradeCost)
			UI.button(panel, label, function() act("UpgradeTower", {towerId = tower.id, branch = branch}) end, {Name = "TowerBranch" .. branch, Position = UDim2.fromOffset(12 + (branch - 1) * (half + 6), actionY), Size = UDim2.fromOffset(half, actionH), TextSize = wide and 11 or 12, TextWrapped = true, BackgroundColor3 = branch == 1 and C.green or C.blue})
		end
	else
		note(L(def.branches[tower.branch or 1].description))
	end
	UI.secondary(panel, T("Alvo: ", "Target: ") .. L(kit.priorityNames[tower.priority] or tower.priority), function()
		local index = table.find(kit.priorityOrder, tower.priority) or 1
		act("SetPriority", {towerId = tower.id, priority = kit.priorityOrder[index % #kit.priorityOrder + 1]})
	end, {Position = UDim2.fromOffset(12, rowY), Size = UDim2.fromOffset(half, rowH), TextSize = 11})
	UI.secondary(panel, T("Vender • ", "Sell • ") .. "💰 " .. number(math.floor((tower.invested or 0) * 0.7)), function()
		act("SellTower", {towerId = tower.id}, closeTowerPanel)
	end, {Position = UDim2.fromOffset(18 + half, rowY), Size = UDim2.fromOffset(half, rowH), TextColor3 = C.red, TextSize = 11})
end

-- Every tower you own carries its next upgrade above it, in the world: tap
-- to buy, green when the energy is there. The panel stays one tap away for
-- targeting and selling, and it is where level 4 picks a branch, but a
-- plain upgrade never needs it. Billboards live in PlayerGui, so they are
-- this player's alone and survive HUD re-layouts.
local upgradeBoards = {}
local function clearUpgradeBoards()
	for id, board in pairs(upgradeBoards) do
		board.gui:Destroy()
		upgradeBoards[id] = nil
	end
end

local function towerAnchor(id)
	local world = workspace:FindFirstChild("DoomWorld")
	local folder = world and world:FindFirstChild("Towers")
	for _, model in ipairs(folder and folder:GetChildren() or {}) do
		if tostring(model:GetAttribute("TowerId")) == tostring(id) then return model.PrimaryPart end
	end
	return nil
end

local function updateUpgradeBoards(match)
	local seen = {}
	for _, tower in ipairs(match.towers or {}) do
		if tower.ownerId ~= player.UserId or (tower.level or 1) >= 5 then continue end
		local id = tostring(tower.id)
		local board = upgradeBoards[id]
		if board and (board.gui.Adornee == nil or board.gui.Adornee.Parent == nil) then
			-- The model was rebuilt (an upgrade swaps parts); re-anchor.
			board.gui:Destroy()
			upgradeBoards[id], board = nil, nil
		end
		if not board then
			local anchor = towerAnchor(tower.id)
			if anchor then
				-- Above the hero's own head: Hulk is far taller than Rocket.
				local figure = anchor.Parent and anchor.Parent:FindFirstChild("HeroFigure")
				local height = figure and tonumber(figure:GetAttribute("FigureHeight")) or 6.5
				local gui = Instance.new("BillboardGui")
				gui.Name, gui.Size, gui.AlwaysOnTop, gui.Active = "Upgrade_" .. id, UDim2.fromOffset(128, 34), true, true
				gui.StudsOffset, gui.MaxDistance, gui.ResetOnSpawn = Vector3.new(0, height + 2.6, 0), 200, false
				gui.Adornee = anchor
				board = {gui = gui}
				board.button = UI.button(gui, "", function()
					local current = board.tower
					if not current then return end
					if (current.level or 1) >= 4 then selectTower(current.id) else act("UpgradeTower", {towerId = current.id}) end
				end, {Size = UDim2.fromScale(1, 1), TextSize = 13})
				UI.stroke(board.button, C.background, 2)
				gui.Parent = player:WaitForChild("PlayerGui")
				upgradeBoards[id] = board
			end
		end
		if board then
			seen[id] = true
			board.tower = tower
			local cost = tower.upgradeCost or 0
			local affordable = (match.cash or 0) >= cost
			local nextLevel = (tower.level or 1) + 1
			board.button.Text = (nextLevel == 5 and ("★ " .. T("EVOLUIR", "EVOLVE")) or ("⬆ " .. tostring(nextLevel) .. "/5")) .. "  💰" .. number(cost)
			board.button.BackgroundColor3 = affordable and C.green or C.card
			-- Light text on green: dark text under the dark outline read as blots.
			board.button.TextColor3 = affordable and C.text or C.muted
		end
	end
	for id, board in pairs(upgradeBoards) do
		if not seen[id] then
			board.gui:Destroy()
			upgradeBoards[id] = nil
		end
	end
end

-- Stacked cards on a tall portrait screen, three across everywhere else, and
-- always sized to the screen's real height so every CHOOSE button is on it.
local function protocolModal(offers)
	if refs.protocolPanel then refs.protocolPanel:Destroy(); refs.protocolPanel = nil end
	if #offers == 0 then return end
	local size = screenSize()
	local P = UI.protocolLayout(size.X, size.Y)
	local veil = UI.frame(overlays, {BackgroundColor3 = C.background, BackgroundTransparency = 0.22, Size = UDim2.fromScale(1, 1), ZIndex = 51, Active = true})
	refs.protocolPanel = veil
	local panel = UI.roundFrame(veil, {Position = at(P.panel), Size = dims(P.panel), ZIndex = 52}, C.green)
	UI.label(panel, T("ESCOLHA SUA CARTA", "CHOOSE YOUR CARD"), {Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 30), TextColor3 = C.green, Font = Enum.Font.GothamBold, TextSize = P.class.compact and 18 or 21, ZIndex = 53})
	UI.label(panel, T("Escolha um bônus para esta partida.", "Choose a bonus for this match."), {Position = UDim2.fromOffset(20, 48), Size = UDim2.new(1, -40, 0, 24), TextColor3 = C.muted, TextSize = 13, ZIndex = 53})
	for index, id in ipairs(offers) do
		local def = Catalog.Cards[id]
		local cardRect = P.cards[index]
		if not def or not cardRect then continue end
		local rarity=Catalog.Rarities[def.rarity]
		local tint=rarity and UI.color(rarity.color) or C.green
		local card = UI.roundFrame(panel, {Position = at(cardRect, P.panel), Size = dims(cardRect), BackgroundColor3 = tint:Lerp(C.card,0.88), ZIndex = 53},tint)
		UI.shade(card,30)
		UI.frame(card,{Position=UDim2.fromOffset(0,6),Size=UDim2.new(0,3,1,-12),BackgroundColor3=tint,ZIndex=54})
		UI.label(card, L(def.name), {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 24), Font = Enum.Font.GothamBold, TextSize = P.class.compact and 13 or 15, TextWrapped = true, ZIndex = 54})
		UI.label(card, L(def.description), {Position = at(P.descriptions[index], cardRect), Size = dims(P.descriptions[index]), TextSize = 12, TextColor3 = C.muted, TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 54})
		UI.button(card, T("ESCOLHER", "CHOOSE").." • "..Catalog.Upper(rarity and L(rarity.name) or ""), function() act("ChooseCard", {cardId = id}) end, {Position = at(P.buttons[index], cardRect), Size = dims(P.buttons[index]), BackgroundColor3=tint, TextSize = 12, ZIndex = 54})
	end
end

local function openBaseUpgrade()
	if not activeMatch() or not state.match.base then return end
	local old=overlays:FindFirstChild("BaseUpgrade"); if old then old:Destroy() end
	local base=state.match.base; local def=Catalog.Bases[base.id]; local stats=base.stats
	local nextStats=Rules.BaseStats(base.id,math.min(5,base.level+1))
	local screen=screenSize()
	local shade=UI.frame(overlays,{Name="BaseUpgrade",Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,BackgroundTransparency=0.25,Active=true,ZIndex=45})
	local panel=UI.roundFrame(shade,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(math.min(420,screen.X-24),math.min(486,screen.Y-24)),BackgroundColor3=C.background,ZIndex=46},C.green)
	UI.label(panel,T("EVOLUIR BASE","UPGRADE BASE"),{Position=UDim2.fromOffset(14,12),Size=UDim2.new(1,-72,0,30),TextColor3=C.green,TextSize=19,Font=Enum.Font.GothamBlack,ZIndex=47})
	UI.button(panel,"×",function() shade:Destroy() end,{Position=UDim2.new(1,-50,0,6),Size=UDim2.fromOffset(44,44),BackgroundColor3=C.red,TextSize=25,ZIndex=47})
	local body=UI.scroll(panel,{Position=UDim2.fromOffset(14,58),Size=UDim2.new(1,-28,1,-70),ZIndex=47}); UI.list(body,10)
	local art=UI.row(body,106); art.ZIndex=47
	UI.basePortrait(art,def,{Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(104,104),ZIndex=48})
	UI.label(art,L(def.name).."\n"..T("MELHORIA ","UPGRADE ")..base.level.." / 5",{Position=UDim2.fromOffset(114,4),Size=UDim2.new(1,-124,1,-8),TextSize=18,Font=Enum.Font.GothamBlack,TextWrapped=true,ZIndex=48})
	local function line(text,color,height) UI.label(body,text,{Size=UDim2.new(1,-8,0,height or 28),TextSize=13,TextWrapped=true,TextColor3=color or C.text,ZIndex=48}) end
	line(L(def.description),C.muted,46)
	line(T("RENDA POR ONDA: ","INCOME PER WAVE: ")..stats.income.." → "..nextStats.income..T(" Ouro"," Gold"),C.gold)
	line(T("VIDA EXTRA DO NÚCLEO: ","EXTRA CORE HP: ")..math.floor(stats.hp/(state.match.partySize or 1)).." → "..math.floor(nextStats.hp/(state.match.partySize or 1)),C.green)
	if stats.damage>0 then line(T("DANO: ","DAMAGE: ")..stats.damage.." → "..nextStats.damage..T(" • ALCANCE: "," • RANGE: ")..stats.range.." → "..nextStats.range,C.coral) end
	if stats.wall>0 then line(T("BARRICADA: ","BARRICADE: ")..(base.wall or 0).."/"..stats.wall.." → "..nextStats.wall..T(" HP • regenera após 5 s"," HP • regenerates after 5 s"),C.blue,40) end
	if stats.soldier>0 then line(T("SOLDADO: ","SOLDIER: ")..stats.soldier.." → "..nextStats.soldier..T(" HP • a cada "," HP • every ")..stats.interval.." s",C.violet,40) end
	local button=UI.button(body,base.level>=5 and T("NÍVEL MÁXIMO","MAXIMUM LEVEL") or T("EVOLUIR • ","UPGRADE • ").."💰 "..stats.upgradeCost,function()
		act("UpgradeBase",{expectedLevel=base.level},function() audio:Cue("upgrade"); shade:Destroy() end)
	end,{Name="ConfirmBaseUpgrade",Size=UDim2.new(1,-8,0,48),TextSize=14,BackgroundColor3=C.green,ZIndex=48})
	if base.level>=5 or (state.match.cash or 0)<stats.upgradeCost then UI.disabled(button) end
	refs.refreshBaseModal=function()
		if not shade.Parent then refs.refreshBaseModal=nil; return end
		local current=state.match
		if not current or not current.base or current.base.level~=base.level then shade:Destroy(); refs.refreshBaseModal=nil; return end
		local missing=math.max(0,stats.upgradeCost-(current.cash or 0))
		if base.level>=5 then return end
		button.Text=missing>0 and T("FALTAM ","NEED ").."💰 "..number(missing) or T("EVOLUIR • ","UPGRADE • ").."💰 "..stats.upgradeCost
		if missing>0 then UI.disabled(button)
		else button.Active=true; button.AutoButtonColor=true; button.BackgroundColor3=C.green; button.TextColor3=C.background end
	end
	refs.refreshBaseModal()
	line(T("Usa o Ouro desta partida. O Ouro do lobby nunca é gasto aqui. Renda exige contribuição na onda.","Uses this match's Gold. Lobby Gold is never spent here. Income requires contribution to the wave."),C.muted,48)
end

local function renderMatch()
	-- Every rect comes from UI.matchLayout, which tests/ui_layout.spec.luau
	-- checks on 22 real screens: nothing co-visible overlaps, nothing leaves
	-- the screen, and every control a thumb has to hit stays thumb-sized.
	local layout = currentMatchLayout()
	refs.layout = layout
	local class = layout.class
	local compact = class.compact
	local topRect = layout.top
	local top = UI.roundFrame(main, {Position = at(topRect), Size = dims(topRect), BackgroundColor3 = C.panel, BackgroundTransparency = 0.1})
	UI.stroke(top, C.ink, 3)
	refs.wave = UI.label(top, "", {Position = at(layout.wave, topRect), Size = dims(layout.wave), TextSize = math.min(class.short and 20 or (compact and 23 or 30), layout.wave.h + 2), Font = UI.Fonts.display, TextColor3 = C.gold})
	refs.map = UI.label(top, "", {Position = at(layout.map, topRect), Size = dims(layout.map), TextWrapped=class.narrow, TextSize = compact and 11 or 14, Font = UI.Fonts.display, TextColor3 = C.muted})
	refs.hpText = UI.button(top, "", openBaseUpgrade, {Name="OpenBaseUpgrade",Position = at(layout.hpText, topRect), Size = UDim2.fromOffset(layout.hpText.w,math.max(44,layout.hpText.h)),BackgroundTransparency=1,TextColor3=C.text,TextXAlignment = Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Top, TextSize = compact and 14 or 18, Font = UI.Fonts.display})
	UI.outline(refs.hpText, 2)
	refs.hp = UI.bar(top, C.green, at(layout.hpBar, topRect), dims(layout.hpBar))
	UI.label(top, "❤", {Name = "CoreHeart", Position = UDim2.fromOffset(layout.hpBar.x - topRect.x - 30, layout.hpBar.y - topRect.y - 7), Size = UDim2.fromOffset(28, layout.hpBar.h + 14), TextSize = layout.hpBar.h + 10, TextColor3 = C.red, TextXAlignment = Enum.TextXAlignment.Center, TextTruncate = Enum.TextTruncate.None})
	refs.matchGold = UI.label(main, "", {Position = at(layout.gold), Size = dims(layout.gold), TextSize = compact and 15 or 18, TextColor3 = C.cream, Font = UI.Fonts.display, TextXAlignment = class.narrow and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right})
	refs.energy = UI.label(main, "", {Position = at(layout.energy), Size = dims(layout.energy), TextColor3 = C.gold, Font = UI.Fonts.display, TextSize = compact and 18 or 24, TextXAlignment = class.narrow and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left})
	surface(refs.matchGold,C.violet)
	surface(refs.energy,C.gold)
	refs.matchGold.BackgroundColor3,refs.matchGold.BackgroundTransparency=C.violet:Lerp(C.ink,0.55),0.1
	refs.energy.BackgroundColor3,refs.energy.TextColor3,refs.energy.BackgroundTransparency=C.gold:Lerp(C.ink,0.62),C.gold,0.05
	refs.energy.TextXAlignment=Enum.TextXAlignment.Center
	refs.matchGold.TextXAlignment=Enum.TextXAlignment.Center
	refs.waveInfo = UI.label(main, "", {Position = at(layout.waveInfo), Size = dims(layout.waveInfo), TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = compact and 14 or 17, Font = UI.Fonts.display, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Center})
	surface(refs.waveInfo,C.stroke)
	refs.waveInfo.BackgroundColor3,refs.waveInfo.BackgroundTransparency=C.panel,0.15
	refs.skip = UI.button(main, T("PRONTO", "READY"), function() act("SkipWave", {}) end, {Position = at(layout.skip), Size = dims(layout.skip), BackgroundColor3 = C.green, TextSize = 18})
	-- Competitive only: everyone agreeing between waves ends the run and keeps the record.
	refs.endVote = UI.button(main, T("ENCERRAR PARTIDA", "END RUN"), function()
		act("VoteEnd", {on = not (state.match and state.match.endVote)})
	end, {Name = "VoteEndRun", Position = UDim2.fromOffset(layout.skip.x, layout.skip.y + layout.skip.h + 6), Size = UDim2.fromOffset(layout.skip.w, 40), BackgroundColor3 = C.red, TextSize = 14, Visible = false})
	local bossRect = layout.boss
	-- In battle a notice slides in under the HUD rows (under the boss bar
	-- when a boss is on the road), never over the wave and core readouts.
	refs.toastTop = (layout.waveInfo.y or 0) + (layout.waveInfo.h or 0) + 6
	refs.toastBossTop = (bossRect.y or 0) + (bossRect.h or 0) + 6
	refs.boss = UI.roundFrame(main, {Position = at(bossRect), Size = dims(bossRect), BackgroundColor3 = Color3.fromRGB(66,30,44), Visible = false}, C.red)
	refs.bossName = UI.label(refs.boss, "", {Position = UDim2.fromOffset(12, 2), Size = UDim2.new(1, -24, 0, 24), TextColor3 = C.text, Font = UI.Fonts.display, TextSize = 20, TextXAlignment = Enum.TextXAlignment.Center})
	refs.bossHP = UI.bar(refs.boss, C.red, UDim2.fromOffset(12, 26), UDim2.new(1, -24, 0, 12))
	refs.bossHint = UI.label(refs.boss, "", {Position = UDim2.fromOffset(12, 37), Size = UDim2.new(1, -24, 0, bossRect.h - 41), TextColor3 = C.muted, TextSize = 11, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center})
	refs.hint = UI.label(main, "", {Position = at(layout.hint), Size = dims(layout.hint), TextColor3 = C.green, TextSize = compact and 13 or 15, Font = UI.Fonts.display, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, Visible = false})
	surface(refs.hint,C.green)
	refs.placement = UI.roundFrame(main, {Position = at(layout.placement), Size = dims(layout.placement), Visible = false})
	refs.confirm = UI.button(refs.placement, T("CONFIRMAR", "CONFIRM"), confirmPlacement, {Position = UDim2.fromOffset(6, 6), Size = UDim2.new(0.65, -9, 1, -12), TextSize = 17})
	UI.button(refs.placement, T("Cancelar", "Cancel"), clearPlacement, {Position = UDim2.new(0.65, 2, 0, 6), Size = UDim2.new(0.35, -8, 1, -12), BackgroundColor3 = C.red, TextSize = 15})
	local abilities = UI.frame(main, {BackgroundTransparency = 1, Position = at(layout.abilities), Size = dims(layout.abilities)})
	UI.list(abilities, 8, true)
	refs.abilityButtons = {}
	-- Slot one decides which hero the commander fights with, so its button
	-- carries that hero's own color and name instead of a generic label —
	-- the same differentiation the squad bar gives slot one (gold star, gold
	-- border). An ultimate (legendary/mythic) also gets a thicker glow and a
	-- ⚡ mark, so the rarest skills read as a bigger deal at a glance.
	for index, id in ipairs(state.match and state.match.ability and {state.match.ability.id} or {}) do
		if index > 2 then break end
		local abilityInfo = state.match.ability
		local def = Catalog.Abilities[id]
		local tint = colorFor(abilityInfo.heroId)
		local button = UI.secondary(abilities, "", function() chooseSkill(id) end, {Name="LeaderPower",LayoutOrder = index, Size = UDim2.fromOffset(layout.skillW, layout.buttonH), TextSize = compact and 12 or 14, TextTruncate = Enum.TextTruncate.AtEnd})
		UI.stroke(button, tint, abilityInfo.ultimate and 3 or 1.5)
		local meter = UI.bar(button, tint, UDim2.new(0, 7, 1, -5), UDim2.new(1, -14, 0, 2))
		refs.abilityButtons[id] = {button = button, index = index, meter = meter, tint = tint,
			name = (def and L(def.name) or T("PODER DO LÍDER", "LEADER POWER")), ultimate = abilityInfo.ultimate}
	end
	if profile().passes and profile().passes.vip then
		UI.secondary(abilities, "✦ " .. T("Saudação", "Salute"), function()
			local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if humanoid then pcall(function() humanoid:PlayEmote("wave") end) end
		end, {LayoutOrder = 3, Size = UDim2.fromOffset(layout.saluteW, layout.buttonH), TextColor3 = C.gold, TextSize = 11})
	end
	refs.speedToggle = UI.secondary(abilities, "1x", toggleSpeed, {Name = "SpeedToggle", LayoutOrder = 4, Size = UDim2.fromOffset(layout.controlW, layout.buttonH), TextSize = 13, Font = Enum.Font.GothamBlack})
	refs.autoSkipToggle = UI.secondary(abilities, "AUTO", toggleAutoSkip, {Name = "AutoSkipToggle", LayoutOrder = 5, Size = UDim2.fromOffset(layout.controlW, layout.buttonH), TextSize = 11, Font = Enum.Font.GothamBlack})
	local bottom = UI.roundFrame(main, {Position = at(layout.heroCards), Size = dims(layout.heroCards), BackgroundColor3 = C.background})
	local cards = UI.scroll(bottom, {Position = UDim2.fromOffset(7, 7), Size = UDim2.new(1, -14, 1, -14), ScrollingDirection = Enum.ScrollingDirection.X, AutomaticCanvasSize = Enum.AutomaticSize.X, ScrollBarThickness = 2})
	UI.list(cards, 7, true)
	refs.heroCards = {}
	for index = 1, 5 do
		local id = (profile().loadout or {})[index]
		if id and Catalog.Heroes[id] then
			local button, price, line, count = heroCard(cards, id, index, layout.cardW, layout.heroCards.h - 14, function() chooseHero(id) end)
			refs.heroCards[id] = {button = button, price = price, line = line, count = count}
		else
			-- An empty slot is a quiet tile with a plus: heroes are equipped in
			-- the lobby, and a phone tile has no room to say so.
			local empty = UI.roundFrame(cards, {Name = "EmptyHeroSlot", LayoutOrder = index, Size = UDim2.fromOffset(layout.cardW, layout.heroCards.h - 14), BackgroundColor3 = C.background, BackgroundTransparency = 0.35}, C.stroke)
			UI.label(empty, "+", {Size = UDim2.fromScale(1, 1), TextSize = 26, TextColor3 = C.stroke, TextXAlignment = Enum.TextXAlignment.Center})
		end
	end
	updateMatch()
end

updateMatch = function()
	if refs.refreshBaseModal then refs.refreshBaseModal() end
	if not state or not state.match or not refs.wave then return end
	local match = state.match
	refs.wave.Text = T("ONDA ", "WAVE ") .. tostring(match.wave or 0) .. (match.totalWaves == 0 and " / ∞" or " / " .. tostring(match.totalWaves or 50))
	refs.map.Text = mapName(match.mapId) .. "  /  " .. modeName(match.modeId)
	-- One line: a second one used to fall behind the health bar.
	refs.hpText.Text = "BASE " .. tostring(math.ceil(match.baseHP or 0)) .. "/" .. tostring(match.maxBaseHP or 100) .. ((match.shield or 0) > 0 and "  🛡" .. math.ceil(match.shield) or "")
		.. (refs.layout and refs.layout.class.narrow and "  ⬆" or T("   ⬆ EVOLUIR", "   ⬆ UPGRADE"))
	refs.hp.Size = UDim2.fromScale(math.clamp((match.baseHP or 0) / (match.maxBaseHP or 100), 0, 1), 1)
	refs.hp.BackgroundColor3 = (match.baseHP or 0)/math.max(1,match.maxBaseHP or 100) > 0.3 and C.green or C.red
	-- Lobby Gold this run has banked so far: a reward, not money to spend.
	refs.matchGold.Text = "🏆 +" .. number(match.goldEarned)
	local towerCount = 0
	for _, tower in ipairs(match.towers or {}) do if tower.ownerId == player.UserId then towerCount += 1 end end
	-- Match Gold in hand, plus what is still lying on the ground to collect.
	local waiting = match.coinsWaiting or 0
	refs.energy.Text = "💰 " .. number(match.cash) .. (waiting > 0 and ("  +" .. number(waiting)) or "")
	refs.energy.TextSize=mobile() and 16 or 22
	if refs.speedToggle then
		local speed, vote = match.speed or 1, match.speedVote or 1
		local party = match.partySize or 1
		-- In a group, a faster speed starts only when everyone asked for it;
		-- show who is waiting.
		local label = speed >= 3 and "▶▶▶ 3x" or speed == 2 and "▶▶ 2x" or "▶ 1x"
		if vote > speed and party > 1 then label = tostring(vote) .. "x " .. tostring(match.speedVotes or 1) .. "/" .. tostring(party) end
		refs.speedToggle.Text = label
		refs.speedToggle.BackgroundColor3 = speed > 1 and C.gold or (vote > 1 and C.gold:Lerp(C.card, 0.6) or C.card)
		refs.speedToggle.TextColor3 = speed > 1 and C.background or C.text
	end
	if refs.autoSkipToggle then
		refs.autoSkipToggle.Text = match.autoSkip and "AUTO ✓" or "AUTO"
		refs.autoSkipToggle.BackgroundColor3 = match.autoSkip and C.green or C.card
		refs.autoSkipToggle.TextColor3 = match.autoSkip and C.background or C.text
	end
	refs.skip.Visible = state.phase == "Preparing"
	if refs.endVote then
		local canEnd = match.modeId == "ranked" and state.phase == "Preparing" and (match.completedWaves or 0) >= 1
		refs.endVote.Visible = canEnd
		if canEnd then
			refs.endVote.Text = (match.endVote and T("✓ ENCERRAR", "✓ END RUN") or T("ENCERRAR PARTIDA", "END RUN")) .. "  " .. tostring(match.endVotes or 0) .. "/" .. tostring(match.partySize or 1)
		end
	end
	refs.skip.Text = T("PRONTO", "READY") .. "  •  " .. tostring(math.max(0, math.ceil(match.prepRemaining or 0))) .. "s" .. (match.skipVotes and "  (" .. tostring(match.skipVotes) .. "/" .. tostring(#(state.players or {})) .. ")" or "")
	local threatNames = {}
	for _, id in ipairs(match.threats or match.nextThreats or {}) do
		local def = Catalog.Enemies[id]
		table.insert(threatNames, def and L(def.name) or tostring(id))
	end
	-- A boss within three waves is announced while there is time to prepare.
	local bossAhead = state.phase == "Preparing" and match.nextBoss and (match.nextBoss - (match.wave or 0)) or nil
	local bossNote = bossAhead and bossAhead >= 1 and bossAhead <= 3 and ("   ⚠ " .. (bossAhead == 1 and T("CHEFE NA PRÓXIMA ONDA!", "BOSS NEXT WAVE!") or (T("CHEFE EM ", "BOSS IN ") .. bossAhead .. T(" ONDAS", " WAVES")))) or ""
	refs.waveInfo.Text = state.phase == "Preparing" and (T("VEM AÍ: ", "COMING: ") .. (#threatNames > 0 and table.concat(threatNames, " • ") or T("prepare suas defesas!", "get your defenses ready!")) .. bossNote) or ("👾 " .. tostring(match.enemies or 0) .. T(" inimigos     🦸 ", " enemies     🦸 ") .. towerCount .. "/" .. tostring(match.towerLimit or 16))
	local boss = match.boss
	refs.boss.Visible = boss ~= nil
	if boss then
		refs.bossName.Text = (boss.final and T("CHEFE FINAL • ","FINAL BOSS • ") or "")..L(boss.name)
		refs.bossName.TextSize=mobile() and 15 or 20
		refs.bossHP.Size = UDim2.fromScale(math.clamp((boss.hp or 0) / math.max(boss.maxHP or 1, 1), 0, 1), 1)
		refs.bossHint.Text = L(boss.hint)
		-- Each new phase is announced: a boss that changes should feel like it.
		local key = tostring(boss.id) .. ":" .. tostring(boss.phase or 1)
		if kit.bossPhase and kit.bossPhase ~= key and string.match(kit.bossPhase, "^[^:]+") == tostring(boss.id) and (boss.phase or 1) > 1 then
			celebrate:Banner({pt = "FASE " .. tostring(boss.phase) .. "!", en = "PHASE " .. tostring(boss.phase) .. "!"}, boss.name, C.red, {cue = "boss", duration = 1.6})
		end
		kit.bossPhase = key
	else
		kit.bossPhase = nil
	end
	for id, record in pairs(refs.abilityButtons or {}) do
		local remaining = match.ability and match.ability.cooldown or 0
		-- A chime the moment the leader's power comes back mid-wave.
		if record.cooling and remaining <= 0 and state.phase == "Wave" then audio:Cue("abilityReady", 1) end
		record.cooling = remaining > 0
		local shortcut = UserInputService.TouchEnabled and "" or "Q  "
		local label = (record.ultimate and "⚡ " or "")..record.name
		record.button.Text = shortcut..label.."\n"..(remaining>0 and (T("Recarrega em ","Ready in ")..math.ceil(remaining).."s") or state.phase=="Preparing" and T("Na próxima onda","Next wave") or T("PRONTO!","READY!"))
		-- Ready: white outlined letters on the hero's colour, readable at a glance.
		record.button.TextColor3 = remaining > 0 and C.muted or C.text
		record.button.BackgroundColor3=remaining>0 and C.card or record.tint:Lerp(C.panel,0.45)
		record.meter.Size = UDim2.fromScale(1 - math.clamp(remaining / math.max(match.ability and match.ability.cooldownTotal or 1, 1), 0, 1), 1)
	end
	for id, card in pairs(refs.heroCards or {}) do
		local selected = selectedHero == id
		local rarity = Catalog.Rarities[Catalog.Heroes[id].rarity]
		local tint = rarity and UI.color(rarity.color) or colorFor(id)
		card.button.BackgroundColor3 = tint:Lerp(C.background, selected and 0.1 or 0.45)
		card.line.BackgroundTransparency = selected and 0 or 1
		card.price.TextColor3 = (match.cash or 0) >= Catalog.Heroes[id].cost and C.gold or C.red
		local placed = 0
		for _, tower in ipairs(match.towers or {}) do if tower.ownerId == player.UserId and tower.heroId == id then placed += 1 end end
		local cap = Rules.HeroLimit(id)
		card.count.Visible = placed > 0
		card.count.Text = tostring(placed) .. "/" .. tostring(cap)
		card.count.TextColor3 = placed >= cap and C.red or C.text
	end
	updateUpgradeBoards(match)
	if routePreview:Update(state.phase, match, profile().settings and profile().settings.lowFX) then
		showToast(T("NOVA ENTRADA! Os inimigos vão chegar por outro caminho.", "NEW ENTRANCE! Enemies will come another way."), true)
	end
	if selectedTower then
		local tower = findTower(selectedTower)
		if not tower then selectedTower = nil; if refs.towerPanel then refs.towerPanel.Visible = false end; if towerRing then towerRing:Destroy(); towerRing = nil end
		else
			local key = tostring(tower.id) .. ":" .. tostring(tower.level) .. ":" .. tostring(tower.priority)
			if refs.towerKey ~= key then refs.towerKey = key; towerPanel(tower) end
			if refs.towerStats then refs.towerStats.Text = towerStatsText(tower, refs.towerWide) end
			if typeof(tower.position) == "Vector3" then towerRing = rangeRing(towerRing, tower.position, tower.range or 20, colorFor(tower.heroId)) end
		end
	end
	local offers = match.cardOffers or {}
	local signature = table.concat(offers, ":")
	if refs.protocolSignature ~= signature then refs.protocolSignature = signature; protocolModal(offers) end
end

local function renderResults()
	local result = state.results or {}
	local victory = result.victory == true or result.ended == true
	local veil = UI.frame(main, {Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.background, BackgroundTransparency = 0.12})
	local panel = UI.roundFrame(veil, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -32, 1, -50), BackgroundColor3 = C.panel}, victory and C.green or C.red)
	UI.create("UISizeConstraint", {MaxSize = Vector2.new(580, 590)}, panel)
	local content = UI.scroll(panel, {Name="ResultBody",Position = UDim2.fromOffset(20, 18), Size = UDim2.new(1, -40, 1, -98)})
	UI.frame(panel,{Position=UDim2.new(0,18,1,-75),Size=UDim2.new(1,-36,0,1),BackgroundColor3=C.stroke})
	-- Like the genre's best: one tap runs the same map again; going back to
	-- base is the quieter choice. Training always returns to the lobby.
	if result.modeId=="tutorial" then
		UI.button(panel,T("VOLTAR À BASE","RETURN TO BASE"),function() act("ReturnLobby",{}) end,{Name="ResultReturn",Position=UDim2.new(0,18,1,-64),Size=UDim2.new(1,-36,0,48),TextSize=15})
	else
		local waiting=result.again==true
		local again=UI.button(panel,waiting and (T("ESPERANDO ","WAITING ")..tostring(result.againVotes or 1).."/"..tostring(result.againTotal or 1)) or T("▶ JOGAR DE NOVO","▶ PLAY AGAIN"),
			function() act("PlayAgain",{}) end,{Name="ResultPlayAgain",Position=UDim2.new(0,18,1,-64),Size=UDim2.new(0.62,-24,0,48),BackgroundColor3=C.green,TextSize=16})
		if waiting then UI.disabled(again) end
		UI.secondary(panel,T("LOBBY","LOBBY"),function() act("ReturnLobby",{}) end,{Name="ResultReturn",Position=UDim2.new(0.62,0,1,-64),Size=UDim2.new(0.38,-18,0,48),TextSize=15})
	end
	UI.list(content, 12)
	local short=sizeClass().short
	local celebration=UI.row(content,short and 44 or 72)
	local emblemSize=short and 36 or 48
	UI.icon(celebration,victory and "trophy" or "heart",victory and C.gold or C.blue,{Position=UDim2.fromOffset(2,short and 4 or 12),Size=UDim2.fromOffset(emblemSize,emblemSize)})
	UI.label(celebration, result.ended and T("RECORDE GUARDADO!", "RECORD SAVED!") or victory and T("VOCÊS CONSEGUIRAM!", "YOU DID IT!") or T("VAMOS TENTAR DE NOVO?", "LET'S TRY AGAIN!"), {Position=UDim2.fromOffset(emblemSize+14,0),Size = UDim2.new(1, -emblemSize-20, 1, 0), TextSize = short and 20 or (mobile() and 22 or 27), Font = Enum.Font.GothamBlack, TextWrapped = true, TextColor3 = victory and C.green or C.blue})
	UI.label(content, mapName(result.mapId or "manhattan") .. "  /  " .. modeName(result.modeId or "normal"), {Size = UDim2.new(1, -6, 0, short and 18 or 26), TextColor3 = C.muted, TextSize = short and 11 or 13, TextXAlignment = Enum.TextXAlignment.Center})
	-- Core rewards stay together and appear before the optional detailed history,
	-- including on short screens where three large rows needed several scrolls.
	local rewards=UI.row(content,short and 64 or 82)
	rewards.Name="ResultRewards"
	for index,reward in ipairs({{T("ONDAS", "WAVES"), tostring(result.waves or 0), C.green}, {T("OURO", "GOLD"), "+" .. number(result.gold or 0), C.gold}, {"XP", "+" .. number(result.xp or 0), C.blue}}) do
		local tile=UI.roundFrame(rewards,{Name="Reward_"..index,Position=UDim2.new((index-1)/3,0,0,0),Size=UDim2.new(1/3,-6,1,0),BackgroundColor3=reward[3]:Lerp(C.card,0.9)},reward[3]:Lerp(C.stroke,0.5))
		UI.label(tile,reward[1],{Position=UDim2.fromOffset(4,6),Size=UDim2.new(1,-8,0,18),TextSize=10,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Center,Font=Enum.Font.GothamBold})
		UI.label(tile,reward[2],{Name="RewardValue_"..index,Position=UDim2.fromOffset(4,26),Size=UDim2.new(1,-8,1,-32),TextSize=mobile() and 19 or 24,TextColor3=reward[3],TextXAlignment=Enum.TextXAlignment.Center,Font=Enum.Font.GothamBlack})
	end
	if not resultsCelebrated then
		-- Once per results screen: a re-render while rewards finish saving must
		-- not throw a second round of confetti.
		resultsCelebrated=true
		celebrate:CountUp(rewards:FindFirstChild("Reward_1") and rewards.Reward_1:FindFirstChild("RewardValue_1"),result.waves or 0,function(v) return tostring(v) end,1)
		celebrate:CountUp(rewards:FindFirstChild("Reward_2") and rewards.Reward_2:FindFirstChild("RewardValue_2"),result.gold or 0,function(v) return "+"..number(v) end,1.4)
		celebrate:CountUp(rewards:FindFirstChild("Reward_3") and rewards.Reward_3:FindFirstChild("RewardValue_3"),result.xp or 0,function(v) return "+"..number(v) end,1.4)
		if victory then
			celebrate:Banner({pt="VITÓRIA!",en="VICTORY!"},{pt=tostring(result.waves or 0).." ondas defendidas",en=tostring(result.waves or 0).." waves defended"},C.gold,{big=true,cue="victory",confetti=60})
		else
			celebrate:Banner({pt="QUASE LÁ!",en="SO CLOSE!"},{pt="Você chegou à onda "..tostring(result.waves or 0)..". Da próxima vez vai!",en="You reached wave "..tostring(result.waves or 0)..". Next time!"},C.blue,{duration=2.2})
		end
	end
	-- The squad's scoreboard: the MVP on top in gold, everyone's damage and
	-- kills under it (a solo commander sees their own numbers).
	local team=result.team or {}
	if #team>0 then
		local mvp=team[1]
		local mine=mvp.userId==player.UserId
		local card=UI.roundFrame(content,{Name="ResultMvp",Size=UDim2.new(1,-6,0,short and 54 or 66),BackgroundColor3=C.gold:Lerp(C.panel,0.72)},C.gold)
		UI.label(card,"⭐ MVP",{Position=UDim2.fromOffset(12,4),Size=UDim2.new(0,90,1,-8),TextSize=short and 18 or 22,Font=UI.Fonts.display,TextColor3=C.gold})
		UI.label(card,mine and T("VOCÊ!","YOU!") or tostring(mvp.name),{Name="MvpName",Position=UDim2.fromOffset(102,4),Size=UDim2.new(1,-112,0.5,-2),TextSize=short and 15 or 18,Font=UI.Fonts.display,TextTruncate=Enum.TextTruncate.AtEnd})
		UI.label(card,"⚔ "..number(mvp.damage).."   💀 "..number(mvp.kills).."   💰 "..number(mvp.gold),{Name="MvpStats",Position=UDim2.new(0,102,0.5,0),Size=UDim2.new(1,-112,0.5,-4),TextSize=short and 13 or 15,Font=UI.Fonts.display,TextColor3=C.cream})
		for index=2,#team do
			local entry=team[index]
			local row=UI.row(content,short and 26 or 30)
			row.Name="ResultTeam_"..index
			UI.label(row,(entry.userId==player.UserId and T("Você","You") or tostring(entry.name)),{Size=UDim2.new(0.5,0,1,0),TextSize=14,Font=UI.Fonts.display,TextTruncate=Enum.TextTruncate.AtEnd})
			UI.label(row,"⚔ "..number(entry.damage).."   💀 "..number(entry.kills),{Position=UDim2.fromScale(0.5,0),Size=UDim2.new(0.5,0,1,0),TextSize=14,Font=UI.Fonts.display,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Right})
		end
	end
	if result.modeId=="ranked" then
		local tier=Rules.RankForWaves(result.waves)
		UI.section(content,"RANK: "..(language=="en" and tier.en or tier.pt),T("Seu melhor resultado fica no placar da temporada.","Your best result stays on the seasonal leaderboard."))
	end
	local earnedPoints = math.max(0, (profile().level or 1) - (result.startLevel or profile().level or 1))
	local evolution = UI.roundFrame(content, {Name = "ResultEvolution", Size = UDim2.new(1, -6, 0, 98), BackgroundColor3 = C.gold:Lerp(C.background, 0.88)}, C.gold)
	UI.label(evolution, T("COMANDANTE • NÍVEL ", "COMMANDER • LEVEL ") .. tostring(profile().level or 1), {Position = UDim2.fromOffset(12, 10), Size = UDim2.new(1, -24, 0, 24), Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = C.gold})
	UI.label(evolution, earnedPoints > 0 and ("+" .. earnedPoints .. T(" ponto(s) para sua árvore!", " point(s) for your talent tree!")) or T("Continue ganhando XP para liberar outro ponto.", "Keep earning XP to unlock another point."), {Position = UDim2.fromOffset(12, 38), Size = UDim2.new(1, -24, 0, 36), TextWrapped = true, TextSize = 13})
	local xpTrack = UI.frame(evolution, {Position = UDim2.fromOffset(12, 82), Size = UDim2.new(1, -24, 0, 5), BackgroundColor3 = C.stroke})
	UI.frame(xpTrack, {Size = UDim2.fromScale(levelProgress(), 1), BackgroundColor3 = C.gold})
	local gains = {}
	for heroId, earned in pairs(result.mastery or {}) do
		if Catalog.Heroes[heroId] and earned > 0 then table.insert(gains, {id = heroId, xp = earned}) end
	end
	table.sort(gains, function(a, b) return a.xp > b.xp end)
	if #gains > 0 then
		local card = UI.roundFrame(content, {Size = UDim2.new(1, -6, 0, 34 + #gains * 26), BackgroundColor3 = C.card})
		UI.label(card, T("SEUS HERÓIS APRENDERAM!", "YOUR HEROES GREW!"), {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -24, 0, 20), TextSize = 11, TextColor3 = C.muted, Font = Enum.Font.GothamBold})
		for index, gain in ipairs(gains) do
			local y = 30 + (index - 1) * 26
			UI.label(card, heroName(gain.id), {Position = UDim2.fromOffset(12, y), Size = UDim2.new(0.62, -12, 0, 22), TextSize = 13, TextColor3 = colorFor(gain.id)})
			UI.label(card, "+" .. number(gain.xp) .. " XP", {Position = UDim2.new(0.62, 0, 0, y), Size = UDim2.new(0.38, -12, 0, 22), TextSize = 13, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Right})
		end
	end
	UI.label(content,T("Próximo objetivo: evolua a habilidade do líder ou recrute nos baús.","Next goal: upgrade your leader ability or recruit from chests."),{Size=UDim2.new(1,-6,0,50),TextWrapped=true,TextColor3=C.muted})
	welcomePanel(panel)
end

render = function()
	local baseModal=overlays:FindFirstChild("BaseUpgrade"); if baseModal then baseModal:Destroy() end
	clearPlacement()
	selectedTower = nil
	if towerRing then towerRing:Destroy(); towerRing = nil end
	if refs.protocolPanel then refs.protocolPanel:Destroy() end
	local retained=state and state.phase=="Lobby" and contextPanel and refs.context
	for _,child in ipairs(main:GetChildren()) do
		if child~=retained and not child:IsA("UIComponent") then child:Destroy() end
	end
	refs = {context=retained or nil}
	-- A panel closed by leaving the lobby must take its blur with it, or the
	-- whole battle is played behind frosted glass.
	if not retained then contextPanel = nil; menuBlur(false) end
	if not activeMatch() then clearUpgradeBoards() end
	if not state or not state.profile then
		local frame = UI.roundFrame(main, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.new(1, -40, 0, 190)}, C.green)
		UI.create("UISizeConstraint", {MaxSize = Vector2.new(480, 220)}, frame)
		UI.label(frame, "DOOMSDAY", {Position = UDim2.fromOffset(20, 20), Size = UDim2.new(1, -40, 0, 52), Font = Enum.Font.GothamBlack, TextSize = 38, TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Center})
		UI.label(frame, T("Conectando à resistência…", "Connecting to the resistance…"), {Position = UDim2.fromOffset(20, 86), Size = UDim2.new(1, -40, 0, 55), TextColor3 = C.muted, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center})
		return
	end
	if state.phase == "Lobby" then renderLobby() elseif state.phase == "Results" then renderResults() else renderMatch() end
end

local function frameCommanderView(inBattle)
	-- Start above the battlefield instead of at eye level among the zombies.
	-- Roblox's camera keeps its own zoom, so setting the CFrame alone never
	-- pulls it back: pin min and max to the wanted distance for a moment, then
	-- hand orbit, wheel zoom and touch pinch back to the player.
	local offset = inBattle and Vector3.new(0, 44, 36) or Vector3.new(0, 6, 23)
	local distance = offset.Magnitude
	player.CameraMaxZoomDistance = 400
	player.CameraMinZoomDistance = distance
	player.CameraMaxZoomDistance = distance
	task.delay(0.5, function()
		if inBattle ~= not not activeMatch() then return end
		local camera = workspace.CurrentCamera
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if camera and root then
			local focus = root.Position + Vector3.new(0, 2, 0)
			camera.FieldOfView = inBattle and 60 or 70
			camera.CFrame = CFrame.lookAt(focus + offset, focus)
		end
		task.delay(0.3, function()
			player.CameraMinZoomDistance = inBattle and 14 or 7
			player.CameraMaxZoomDistance = inBattle and 110 or 55
		end)
	end)
end

player.CharacterAdded:Connect(function()
	frameCommanderView(not not activeMatch())
end)

-- Compares the previous snapshot with the new one and celebrates what the
-- player just earned: Gold in the lobby, Gold in battle, a cleared wave.
local function celebrateChanges(previousGold, previousMatch, phaseChanged)
	if phaseChanged then return end
	if state.phase == "Lobby" and previousGold and refs.gold and (profile().gold or 0) > previousGold then
		celebrate:Pop(refs.gold, 0.25)
		celebrate:Float("+" .. number((profile().gold or 0) - previousGold), refs.gold, C.gold)
	end
	local match = state.match
	if not (activeMatch() and match and previousMatch and previousMatch.runId == match.runId) then return end
	if refs.matchGold and (match.goldEarned or 0) > (previousMatch.goldEarned or 0) then celebrate:Pop(refs.matchGold, 0.12) end
	local cleared = match.completedWaves or 0
	if cleared > (previousMatch.completedWaves or 0) and not Rules.IsBossWave(match.modeId, cleared, match.mapId) then
		-- Boss waves get their own, bigger banner when the boss falls.
		celebrate:Banner({pt = "ONDA " .. cleared .. " VENCIDA!", en = "WAVE " .. cleared .. " CLEARED!"}, nil, C.green, {cue = "wave"})
	end
end

local function applyState(nextState)
	if type(nextState) ~= "table" then return end
	local previousPhase = state and state.phase
	local previousLevel = state and state.profile and state.profile.level
	local previousGold = state and state.profile and state.profile.gold
	local previousMatch = state and state.match
	local previousLanguage = language
	state = nextState
	language = state.profile and state.profile.settings and state.profile.settings.language or language
	local kind = screenKey()
	local signature = profileSignature()
	local phaseChanged = previousPhase ~= state.phase and not ((previousPhase == "Wave" or previousPhase == "Preparing") and activeMatch())
	if phaseChanged then celebrate:Clear() end
	if state.phase ~= "Results" then resultsCelebrated = false end
	if phaseChanged or kind ~= layoutKind or language ~= previousLanguage or not refs.wave and activeMatch() then
		layoutKind = kind
		render()
		if phaseChanged and state.phase ~= "Results" then frameCommanderView(activeMatch()) end
	elseif state.phase == "Lobby" then
		if refs.gold then refs.gold.Text = goldText() end
		if refs.commander then refs.commander.Text = levelText() end
		if refs.levelBar then refs.levelBar.Size = UDim2.fromScale(levelProgress(), 1) end
		if refs.rewardsBadge then
			local claimable=tonumber(profile().rewards and profile().rewards.claimable) or 0
			refs.rewardsBadge.Visible=claimable>0
			refs.rewardsBadge.Text=tostring(math.min(claimable,9))
		end
		local elevatorMoved = renderElevator()
		if signature ~= lastProfileSignature or elevatorMoved then renderContext(); updateWorldCosmetics() end
	elseif activeMatch() then updateMatch()
	elseif state.phase == "Results" and signature ~= lastProfileSignature then render() end
	lastProfileSignature = signature
	audio:Update(state)
	if previousLevel and (profile().level or 1) > previousLevel then
		celebrate:Banner({pt = "SUBIU DE NÍVEL! NV " .. profile().level, en = "LEVEL UP! LV " .. profile().level},
			{pt = "+" .. (profile().level - previousLevel) .. " ponto(s) na árvore de evolução", en = "+" .. (profile().level - previousLevel) .. " talent point(s) to spend"},
			C.violet, {big = true, cue = "levelUp", confetti = 40})
	end
	celebrateChanges(previousGold, previousMatch, phaseChanged)
	nameplates:Update(state.players)
	if state.notice then showToast(state.notice) end
end

-- In Studio the screen review (Review.luau) may hold real snapshots while a
-- fixture screen is shown; everywhere else this is applyState directly.
local reviewHold = nil
stateRemote.OnClientEvent:Connect(function(snapshot)
	if reviewHold then reviewHold(snapshot) else applyState(snapshot) end
end)
fxRemote.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" then return end
	if event.kind == "Notice" then
		showToast(event.text, event.tone == "boss")
		if event.tone == "boss" then audio:Cue("boss", 4) end
	elseif event.kind == "WaveCash" then
		-- The wave bonus lands straight in the wallet: show it next to the Gold.
		if refs.energy and refs.energy.Parent and tonumber(event.amount) then
			celebrate:Float("+" .. number(event.amount) .. " 💰", refs.energy, C.gold)
			celebrate:Pop(refs.energy, 0.12)
		end
	elseif event.kind == "OpenPanel" and state and state.phase == "Lobby" then
		if contextBuilders[event.panel] then
			openContext(event.panel, {
				heroId = event.heroId, chestId = event.chestId,
				shopKind = event.shopKind, shopKey = event.shopKey,
			})
		end
	else
		if event.kind == "BossArrive" and activeMatch() then
			local def = Catalog.Enemies[event.enemyId]
			celebrate:Banner(def and def.name or {pt = "CHEFE", en = "BOSS"}, event.final and {pt = "⚠ CHEFE FINAL", en = "⚠ FINAL BOSS"} or {pt = "⚠ CHEFE", en = "⚠ BOSS"}, C.red, {big = true, cue = "boss", duration = 2.4})
			-- A short entrance: the camera flies to the boss and back, unless
			-- the player turned camera motion off or is placing a hero.
			local camera = workspace.CurrentCamera
			local settings = profile().settings or {}
			if camera and typeof(event.position) == "Vector3" and settings.shake ~= false and not selectedHero and camera.CameraType == Enum.CameraType.Custom then
				local home = camera.CFrame
				local target = event.position + Vector3.new(0, 4, 0)
				camera.CameraType = Enum.CameraType.Scriptable
				TweenService:Create(camera, TweenInfo.new(0.55, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {CFrame = CFrame.lookAt(target + Vector3.new(0, 16, 24), target)}):Play()
				task.delay(1.8, function()
					if camera.CameraType ~= Enum.CameraType.Scriptable then return end
					TweenService:Create(camera, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {CFrame = home}):Play()
					task.delay(0.47, function() if camera.CameraType == Enum.CameraType.Scriptable then camera.CameraType = Enum.CameraType.Custom end end)
				end)
			end
		elseif event.kind == "EnemyDown" and event.boss and activeMatch() then
			local def = Catalog.Enemies[event.enemyId]
			celebrate:Banner({pt = "CHEFE DERROTADO!", en = "BOSS DEFEATED!"}, def and def.name or nil, C.gold, {big = true, cue = "victory", confetti = 50})
		elseif event.kind == "Ability" and event.ultimate and event.ownerId == player.UserId then
			local def = Catalog.Abilities[event.abilityId]
			if def then celebrate:Banner({pt = "⚡ " .. Catalog.Upper(def.name.pt) .. "!", en = "⚡ " .. Catalog.Upper(def.name.en) .. "!"}, {pt = "ULTIMATE", en = "ULTIMATE"}, UI.color(def.color), {cue = "ability", duration = 1.5}) end
		end
		effects:Handle(event)
	end
end)

local function handleWorldPointer(position)
	if not activeMatch() or refs.protocolPanel then return end
	if selectedHero or (selectedSkill and Catalog.Abilities[selectedSkill].target ~= "tower") then
		local hit = raycast(position, true)
		if hit then updatePreview(hit.Position); placementPinned = true end
		return
	end
	local hit = raycast(position, false)
	local instance = hit and hit.Instance
	while instance and instance ~= workspace do
		local id = instance:GetAttribute("TowerId")
		if id then selectTower(id); return end
		instance = instance.Parent
	end
	if hit then
		local best, distance
		for _, tower in ipairs(state.match.towers or {}) do
			local d = (Vector3.new(tower.position.X, 0, tower.position.Z) - Vector3.new(hit.Position.X, 0, hit.Position.Z)).Magnitude
			if d < 5 and (not distance or d < distance) then best, distance = tower.id, d end
		end
		if best then selectTower(best) end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then handleWorldPointer(Vector2.new(input.Position.X, input.Position.Y))
	elseif input.KeyCode == Enum.KeyCode.Escape then clearPlacement()
	elseif activeMatch() then
		local keys = {Enum.KeyCode.One, Enum.KeyCode.Two, Enum.KeyCode.Three, Enum.KeyCode.Four, Enum.KeyCode.Five}
		local index = table.find(keys, input.KeyCode)
		if index and profile().loadout[index] then chooseHero(profile().loadout[index])
		elseif input.KeyCode == Enum.KeyCode.Q and state.match.ability then chooseSkill(state.match.ability.id)
		elseif input.KeyCode == Enum.KeyCode.F then toggleSpeed() end
	end
end)

UserInputService.TouchTapInWorld:Connect(function(position, processed)
	if not processed then handleWorldPointer(position) end
end)

-- AFK farm banner. The server marks the commander standing in a farm chamber
-- (attributes AfkZone / AfkNext) and pays each minute itself; this only shows
-- it, and keeps Roblox's idle kick from ending a farm the player chose.
kit.afkBanner, kit.afkTitle, kit.afkDetail, kit.afkBannerAt = nil, nil, nil, 0
-- Power saving while farming: the 3D world stops rendering and a quiet
-- screen shows the session. It always switches back when the farm ends.
local afk = { eco = false, screen = nil, text = nil, travel = nil, autoEco = false }
local function setAfkEco(on)
	afk.eco = on
	pcall(function() RunService:Set3dRenderingEnabled(not on) end)
	if on and not afk.screen then
		afk.screen = UI.frame(overlays, {Name = "AfkScreen", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.02, Active = true, ZIndex = 60})
		UI.label(afk.screen, T("💤 FARM AFK", "💤 AFK FARM"), {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.18, 0), Size = UDim2.fromOffset(420, 56), TextSize = 40, Font = UI.Fonts.display, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 61})
		afk.text = UI.label(afk.screen, "", {Name = "AfkScreenStats", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0.18, 70), Size = UDim2.fromOffset(460, 150), TextSize = 20, Font = UI.Fonts.display, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 61})
		UI.button(afk.screen, T("MOSTRAR O JOGO", "SHOW THE GAME"), function() setAfkEco(false) end, {Name = "AfkEcoOff", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, -115, 0.18, 236), Size = UDim2.fromOffset(220, 50), BackgroundColor3 = C.blue, TextSize = 16, ZIndex = 61})
		UI.button(afk.screen, T("VOLTAR AO LOBBY", "BACK TO LOBBY"), function() setAfkEco(false); act("LeaveAfk", {}) end, {Name = "AfkLeave", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 115, 0.18, 236), Size = UDim2.fromOffset(220, 50), BackgroundColor3 = C.red, TextSize = 16, ZIndex = 61})
	elseif not on and afk.screen then
		afk.screen:Destroy(); afk.screen, afk.text = nil, nil
	end
end
local function updateAfkBanner()
	local kind = player:GetAttribute("AfkZone")
	local farm = kind and Catalog.Afk[kind]
	if not farm then
		if kit.afkBanner then kit.afkBanner.Visible = false end
		if afk.eco then setAfkEco(false) end
		return
	end
	if not kit.afkBanner then
		kit.afkBanner = UI.roundFrame(overlays, {Name = "AfkBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(math.min(460, screenSize().X - 24), 58), BackgroundColor3 = C.background}, C.gold)
		kit.afkTitle = UI.label(kit.afkBanner, "", {Name = "AfkTitle", Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 28), TextSize = 18, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center})
		-- The dedicated AFK place, when the game has one configured.
		afk.travel = UI.button(kit.afkBanner, T("SERVIDOR AFK", "AFK SERVER"), function() act("EnterAfkServer", {}) end, {Name = "AfkServerGo", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -104, 0.5, 0), Size = UDim2.fromOffset(120, 44), BackgroundColor3 = C.violet, TextSize = 12, Visible = false})
		UI.button(kit.afkBanner, T("ECONOMIA", "SAVER"), function() setAfkEco(true) end, {Name = "AfkEcoOn", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(92, 44), BackgroundColor3 = C.blue, TextSize = 13})
		kit.afkDetail = UI.label(kit.afkBanner, "", {Name = "AfkDetail", Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 22), TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center})
	end
	local tint = UI.color(farm.color)
	kit.afkBanner.Visible = true
	kit.afkTitle.Text = "💤 " .. Catalog.Upper(L(farm.name))
	kit.afkTitle.TextColor3 = tint
	-- Session clock, what has really been paid, and whether the last minute is
	-- still being saved: the server sets all of it, the banner only reads it.
	local session = math.floor(tonumber(player:GetAttribute("AfkSession")) or 0)
	local earned = tonumber(player:GetAttribute("AfkEarned")) or 0
	local saving = player:GetAttribute("AfkSaving") == true
	kit.afkDetail.Text = L(farm.rate) .. "  •  " .. T("próximo em ", "next in ") .. tostring(player:GetAttribute("AfkNext") or 60) .. "s"
		.. "  •  " .. string.format("%d:%02d", math.floor(session / 60), session % 60)
		.. "  •  +" .. number(earned) .. (kind == "gold" and T(" Ouro", " Gold") or " XP")
		.. "  " .. (saving and T("salvando…", "saving…") or "✓")
	if afk.travel then afk.travel.Visible = player:GetAttribute("AfkTravel") == true end
	-- On the AFK place the saving screen comes on by itself, once.
	if player:GetAttribute("AfkServer") and not afk.autoEco then afk.autoEco = true; setAfkEco(true) end
	if afk.text then
		afk.text.Text = L(farm.name) .. "\n" .. T("Sessão ", "Session ") .. string.format("%d:%02d", math.floor(session / 60), session % 60)
			.. "\n" .. T("Próximo pagamento em ", "Next payment in ") .. tostring(player:GetAttribute("AfkNext") or 60) .. "s"
			.. "\n" .. T("Recebido: +", "Received: +") .. number(earned) .. (kind == "gold" and T(" Ouro", " Gold") or " XP") .. "  " .. (saving and T("(salvando…)", "(saving…)") or T("✓ salvo", "✓ saved"))
	end
end
pcall(function()
	player.Idled:Connect(function()
		if not player:GetAttribute("AfkZone") then return end
		pcall(function()
			local virtual = game:GetService("VirtualUser")
			virtual:CaptureController()
			virtual:ClickButton2(Vector2.new())
		end)
	end)
end)

kit.nameplateAt, kit.anchorCheckAt = 0, 0
RunService.RenderStepped:Connect(function(dt)
	if os.clock() >= kit.afkBannerAt then
		kit.afkBannerAt = os.clock() + 0.25
		updateAfkBanner()
	end
	routePreview:Step(dt or 1 / 60, state and state.phase)
	-- Only real news moves: a dock icon bobs while it has something waiting
	-- (a chest to open, a gift, talent points) and its badge wiggles; every
	-- other button stays still.
	if not (profile().settings and profile().settings.lowFX) then
		local now = os.clock()
		local waiting = { rewards = refs.rewardsBadge }
		for id, entry in pairs(refs.navigation or {}) do
			if entry.icon and entry.icon.Parent then
				local flag = waiting[id] or entry.badge
				local news = flag ~= nil and flag.Parent ~= nil and flag.Visible ~= false
				entry.icon.Position = UDim2.new(0.5, entry.iconX, 0, 2 + (news and math.sin(now * 2.2 + entry.phase) * 3 or 0))
			end
		end
		for _, badge in ipairs({refs.rewardsBadge}) do
			if badge and badge.Parent and badge.Visible then badge.Rotation = math.sin(now * 7) * 14 end
		end
	end
	if kit.contextRefreshPending and not UserInputService:GetFocusedTextBox() then renderContext() end
	animateLobby(dt or 1 / 60)
	celebrate:Step(dt or 1 / 60)
	if refs.elevatorCount then
		local count = elevatorCountText()
		if refs.elevatorCount.Text ~= count then refs.elevatorCount.Text = count end
	end
	if os.clock() >= kit.nameplateAt then
		kit.nameplateAt = os.clock() + 0.7
		nameplates:Refresh()
	end
	-- A contextual panel belongs to the place that opened it: walk away from
	-- the pedestal and the panel closes, the way the physical lobby implies.
	if contextPanel and contextPanel.anchor and os.clock() >= kit.anchorCheckAt then
		kit.anchorCheckAt = os.clock() + 0.25
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - contextPanel.anchor).Magnitude > 26 then closeContext() end
	end
	if activeMatch() and selectedHero and not placementPinned and not UserInputService.TouchEnabled then
		local hit = raycast(UserInputService:GetMouseLocation(), true)
		if hit then updatePreview(hit.Position) end
	end
end)

-- Layouts are computed in pixels from the usable screen, so any change to it
-- re-lays the HUD out: a rotation, a resized window, or Roblox changing its
-- own topbar inset. Debounced, and skipped when the size did not really move.
kit.resizeQueued = false
local function queueRelayout()
	if kit.resizeQueued then return end
	kit.resizeQueued = true
	task.delay(0.2, function()
		kit.resizeQueued = false
		local key = screenKey()
		if key == layoutKind then return end
		layoutKind = key
		render()
	end)
end
local function watchCamera()
	local camera = workspace.CurrentCamera
	if not camera then return end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(queueRelayout)
end
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(watchCamera)
main:GetPropertyChangedSignal("AbsoluteSize"):Connect(queueRelayout)
watchCamera()
render()

task.spawn(function()
	while not state or not state.profile do
		local response = request("Sync", {}, true)
		if response and response.ok and response.data then applyState(response.data) end
		if not state or not state.profile then task.wait(2) end
	end
end)

-- Studio-only screen review: fixture screens and server scenes driven from
-- the command bar by tools/studio_review.py. A live server never loads it.
if RunService:IsStudio() and script:FindFirstChild("Review") then
	local liveRequest = request
	require(script.Review).start({
		player = player, Catalog = Catalog, Rules = Rules, gui = gui, main = main, overlays = overlays, celebrate = celebrate,
		getState = function() return state end,
		setState = function(snapshot) state = snapshot end,
		setLanguage = function(value) language = value end,
		setRequest = function(fn) request = fn or liveRequest end,
		serverRequest = liveRequest,
		applyState = applyState,
		render = function() render() end,
		selectTower = selectTower,
		openBaseUpgrade = openBaseUpgrade,
		openContext = function(kind, data) openContext(kind, data) end,
		hold = function(fn) reviewHold = fn end,
	})
end
