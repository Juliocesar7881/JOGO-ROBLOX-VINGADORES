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
			window.VerticalAlignment = Enum.VerticalAlignment.Center
			window.HeightScale, window.WidthScale = 0.7, 0.9
			window.BackgroundColor3 = C.panel
		end
	end)
end)

local state, language = nil, "pt"
local boardSize, boardMap, boardData = 1, "hydra", nil
local selectedTower, selectedHero, selectedSkill = nil, nil, nil
local selectedPosition, placementValid = nil, false
local placementPinned = false
local layoutKind, lastProfileSignature = nil, nil
local refs, productInfo, productFetching = {}, {}, false
local placementRing, ghost, towerRing
local ghostParts, ghostLift
local contextPanel = nil
local cosmeticsRetryPending = false
local contextRefreshPending = false
local pending = {}
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
	local toast = UI.roundFrame(overlays, {
		Name = "Toast", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, activeMatch() and 8 or math.max(8,screenSize().Y-78)),
		Size = UDim2.new(1, -32, 0, 62), ZIndex = 60,
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

local function act(action, payload, callback)
	if pending[action] then return end
	pending[action] = true
	task.spawn(function()
		local result = request(action, payload)
		pending[action] = nil
		if result and result.ok and callback then callback(result.data) end
	end)
end

local audio = Audio.new(function() return state end)
local nameplates = Nameplates.new(player, function() return language end)
local effects = Effects.new(player, request, function() return state end, audio)
local routePreview = RoutePreview.new(effects.folder, Catalog, C)

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

-- Quickbar and formation cards share a real 3D portrait, a clear price and
-- a small slot number. The compact version keeps its tested touch geometry.
local function heroCard(parent, id, index, width, height, callback, equipped)
	local def, tint = Catalog.Heroes[id], colorFor(id)
	local tight = height < 62
	local portraitW = tight and 40 or math.floor(width * 0.43)
	local button = UI.secondary(parent, "", callback, {
		Name = "HeroCard_" .. id, LayoutOrder = index,
		Size = UDim2.fromOffset(width, height), BackgroundColor3 = equipped and tint:Lerp(C.background, 0.48) or C.card,
	})
	local portraitBack=UI.frame(button,{Position=UDim2.fromOffset(3,3),Size=UDim2.fromOffset(portraitW,height-6),BackgroundColor3=tint,BackgroundTransparency=0.75})
	UI.corner(portraitBack,11)
	heroPortrait(button, id, {Position = UDim2.fromOffset(3, 3), Size = UDim2.fromOffset(portraitW, height - 6)})
	local textX = portraitW + 9
	UI.label(button, L(def.name), {Name = "HeroName", Position = UDim2.fromOffset(textX, tight and 3 or 7), Size = UDim2.new(1, -textX - 5, 0, tight and 26 or 32), TextSize = tight and 12 or 14, Font = UI.Fonts.display, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
	if index==1 then UI.stroke(button,C.gold,3.5) end
	local price = UI.label(button, "🪙 " .. tostring(def.cost), {Name = "EnergyCost", Position = UDim2.new(0, textX, 1, tight and -21 or -26), Size = UDim2.new(1, -textX - 4, 0, 20), TextColor3 = C.gold, TextSize = tight and 12 or 15, Font = UI.Fonts.display})
	local badge = UI.label(button, index==1 and "★1" or tostring(index), {Name = "SlotNumber", Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(tight and 22 or 26, tight and 15 or 18), BackgroundColor3 = C.background, BackgroundTransparency = 0.08, TextSize = 10, TextColor3 = tint, Font = Enum.Font.GothamBold, TextXAlignment = Enum.TextXAlignment.Center})
	UI.corner(badge, 5)
	local line = UI.frame(button, {Name = "SelectionLine", Position = UDim2.new(0, 8, 1, -3), Size = UDim2.new(1, -16, 0, 2), BackgroundColor3 = tint, BackgroundTransparency = equipped and 0 or 0.65})
	return button, price, line
end

-- Lobby locations and the HUD share these panels. The HUD offers a quick
-- route to playing, forming a team and spending earned progression points.
local modeTint = {
	normal = C.green, ranked = Color3.fromRGB(255, 138, 61), tutorial = C.gold,
	cards = Color3.fromRGB(177,119,243),
}
for id, destination in pairs(Catalog.Destinations) do
	if not modeTint[id] then modeTint[id] = modeTint[destination.modeId] end
end
local modeLockHints = {
	normal = {pt = "Conclua o treinamento.", en = "Complete training."},
	ranked = {pt = "Vença qualquer mapa da campanha.", en = "Win any campaign map."},
	cards = {pt = "Vença qualquer mapa da campanha.", en = "Win any campaign map."},
	tutorial = {pt = "Sempre disponível.", en = "Always available."},
}

local function makeLeader(id,callback)
	local list=copy(profile().loadout)
	local old=table.find(list,id)
	if old then table.remove(list,old) elseif #list>=5 then table.remove(list,5) end
	table.insert(list,1,id)
	act("SetLoadout",{heroes=list},callback)
end

local heroDetailTab="power"
local function contextHero(body, data)
	UI.secondary(body,T("‹ MEUS HERÓIS","‹ MY HEROES"),function() openContext("inventory",{}) end,{Name="BackToInventory",Size=UDim2.new(1,-6,0,44),TextSize=12})
	local id = data.heroId
	local def = Catalog.Heroes[id]
	if not def then return end
	local owned = (profile().heroes or {})[id]
	local rarity = Catalog.Rarities[def.rarity]
	local tint = UI.color(rarity.color)
	local showcase = UI.row(body, 136)
	heroPortrait(showcase,id,{Position=UDim2.fromOffset(0,0),Size=UDim2.fromOffset(104,132)})
	UI.label(showcase,L(rarity.name),{Position=UDim2.fromOffset(118,0),Size=UDim2.new(1,-122,0,20),TextColor3=tint,Font=Enum.Font.GothamBold})
	UI.label(showcase,L(def.name),{Position=UDim2.fromOffset(118,25),Size=UDim2.new(1,-122,0,62),TextSize=23,Font=Enum.Font.GothamBlack,TextWrapped=true})
	UI.label(showcase,"🪙 "..number(def.cost)..T(" Ouro na partida"," Gold in battle"),{Position=UDim2.fromOffset(118,95),Size=UDim2.new(1,-122,0,25),TextColor3=C.gold})
	smallText(body,L(def.description),0,48)
	local tabs=UI.row(body,44)
	for index,tab in ipairs({{id="power",label=T("PODER E EQUIPE","POWER & SQUAD")},{id="defense",label=T("NA DEFESA","ON DEFENSE")}}) do
		UI.button(tabs,tab.label,function() heroDetailTab=tab.id; renderContext() end,{Name="HeroDetail_"..tab.id,Position=UDim2.new((index-1)/2,0,0,0),Size=UDim2.new(0.5,-6,0,44),TextSize=11,BackgroundColor3=heroDetailTab==tab.id and tint or C.card,TextColor3=heroDetailTab==tab.id and C.background or C.text})
	end
	if heroDetailTab=="defense" then
	UI.section(body,T("NA DEFESA","ON DEFENSE"),T("Valores da torre inicial, antes de maestria, talentos e outros bônus.","Starting tower values, before mastery, talents and other bonuses."))
	local stats=UI.row(body,116)
	for index,entry in ipairs({{T("DANO","DAMAGE"),tostring(def.damage)},{T("ALCANCE","RANGE"),tostring(def.range).." studs"},{T("INTERVALO","INTERVAL"),string.format("%.2f s",def.interval)},{T("POSICIONAR","PLACE"),"🪙 "..number(def.cost)}}) do
		local card=UI.roundFrame(stats,{Name="HeroStat_"..index,Position=UDim2.new((index-1)%2/2,0,0,math.floor((index-1)/2)*58),Size=UDim2.new(0.5,-6,0,52),BackgroundColor3=tint:Lerp(C.panel,0.9)},tint:Lerp(C.stroke,0.6))
		UI.label(card,entry[1],{Position=UDim2.fromOffset(8,4),Size=UDim2.new(1,-16,0,18),TextSize=10,TextColor3=C.muted,Font=Enum.Font.GothamBold})
		UI.label(card,entry[2],{Position=UDim2.fromOffset(8,24),Size=UDim2.new(1,-16,0,24),TextSize=14,TextColor3=tint,Font=Enum.Font.GothamBold})
	end
	UI.label(body,def.air and T("ATINGE SOLO E VOADORES","HITS GROUND AND AIR") or T("ATINGE INIMIGOS NO SOLO","HITS GROUND ENEMIES"),{Name="HeroTargets",Size=UDim2.new(1,-6,0,30),TextColor3=C.green,Font=Enum.Font.GothamBold,TextSize=12,TextWrapped=true})
	UI.section(body,T("DOIS CAMINHOS","TWO PATHS"),T("Na última melhoria da torre, escolha uma especialização por partida.","At the tower's final upgrade, choose one specialization for that match."))
	for index,branch in ipairs(def.branches or {}) do
		local card=UI.roundFrame(body,{Name="HeroBranch_"..index,Size=UDim2.new(1,-6,0,98),BackgroundColor3=C.card},tint)
		UI.label(card,tostring(index),{Position=UDim2.fromOffset(9,11),Size=UDim2.fromOffset(26,26),TextColor3=tint,TextSize=22,Font=Enum.Font.GothamBlack})
		UI.label(card,L(branch.name),{Position=UDim2.fromOffset(44,7),Size=UDim2.new(1,-56,0,38),TextWrapped=true,TextSize=14,Font=Enum.Font.GothamBold})
		UI.label(card,L(branch.description),{Position=UDim2.fromOffset(12,48),Size=UDim2.new(1,-24,0,43),TextWrapped=true,TextSize=12,TextColor3=C.muted})
	end
	return
	end
	local ability=Catalog.Abilities[def.ability]
	local rank=(profile().abilities or {})[id] or 1
	UI.section(body,L(ability.name),T("Seu primeiro herói empresta o poder especial para você!","Your first hero lends you their special power!"))
	smallText(body,Rules.AbilityText(ability,rank,language),0,64)
	if not owned then
		UI.button(body,T("ENCONTRAR NOS BAÚS","FIND IN CHESTS"),function() openContext("chests",{}) end,{Size=UDim2.new(1,-6,0,44),BackgroundColor3=C.gold})
		UI.secondary(body,T("Compra direta • Robux","Direct purchase • Robux"),function() openContext("premium",{}) end,{Size=UDim2.new(1,-6,0,44)})
		return
	end
	UI.button(body,(profile().loadout or {})[1]==id and T("LÍDER ATUAL • SLOT 1","CURRENT LEADER • SLOT 1") or T("USAR COMO LÍDER • SLOT 1","MAKE LEADER • SLOT 1"),function()
		makeLeader(id)
	end,{Name="MakeLeader_"..id,Size=UDim2.new(1,-6,0,46),BackgroundColor3=C.gold})
	UI.secondary(body,contains(profile().loadout,id) and T("Retirar da equipe","Unequip") or T("Adicionar à equipe","Equip hero"),function()
		local list=copy(profile().loadout); local old=table.find(list,id)
		if old then table.remove(list,old) elseif #list<5 then table.insert(list,id) else showToast(T("A equipe tem 5 heróis. Retire um primeiro.","Squad full. Unequip a hero first."),true); return end
		act("SetLoadout",{heroes=list})
	end,{Size=UDim2.new(1,-6,0,44)})
	UI.section(body,T("MELHORE SEU PODER","UPGRADE YOUR POWER"),T("Nível do herói ","Hero level ")..owned.level.."/20")
	local offer=Rules.AbilityUpgrade(def,rank)
	if offer then
		local buy=UI.button(body,T("MELHORAR • ","UPGRADE • ")..number(offer.cost)..T(" Ouro • Herói nível "," Gold • Hero level ")..offer.mastery,function()
			act("UpgradeAbility",{heroId=id,expectedRank=rank},function() audio:Cue("upgrade") end)
		end,{Name="UpgradeAbility_"..id,Size=UDim2.new(1,-6,0,46),BackgroundColor3=tint})
		if owned.level<offer.mastery or (profile().gold or 0)<offer.cost then UI.disabled(buy) end
  if owned.level<offer.mastery then
   smallText(body,T("Seu herói precisa do nível ","Your hero needs level ")..offer.mastery..T(". Jogue usando este herói para evoluir.",". Play with this hero to progress."),0,42)
  elseif (profile().gold or 0)<offer.cost then
   smallText(body,T("Faltam ","You need ")..number(offer.cost-(profile().gold or 0))..T(" Ouro para esta melhoria."," more Gold for this upgrade."),0,32)
  end
 else
  UI.label(body,T("PODER NO NÍVEL MÁXIMO!","POWER AT MAX LEVEL!"),{Size=UDim2.new(1,-6,0,32),TextColor3=C.gold,Font=Enum.Font.GothamBold,TextSize=13})
 end
 local progress=UI.row(body,12)
 for level=1,Catalog.AbilityRanks.max do
  UI.roundFrame(progress,{Name="AbilityProgress_"..level,Position=UDim2.new((level-1)/Catalog.AbilityRanks.max,0,0,0),Size=UDim2.new(1/Catalog.AbilityRanks.max,-6,0,9),BackgroundColor3=level<=rank and tint or C.stroke})
 end
	for level=1,Catalog.AbilityRanks.max do
		local row=UI.roundFrame(body,{Name="AbilityRank_"..level,Size=UDim2.new(1,-6,0,84),BackgroundColor3=level<=rank and tint:Lerp(C.background,0.85) or C.card},level<=rank and tint or C.stroke)
		UI.label(row,T("NÍVEL ","LEVEL ")..level..(level<=rank and " ✓" or ""),{Position=UDim2.fromOffset(12,6),Size=UDim2.new(1,-24,0,22),TextColor3=tint,Font=Enum.Font.GothamBold})
		UI.label(row,Rules.AbilityText(ability,level,language),{Position=UDim2.fromOffset(12,31),Size=UDim2.new(1,-24,0,45),TextSize=11,TextWrapped=true})
	end

end

local function categoryTabs(body, name, options, selected, onSelect)
 local row=UI.row(body,44)
 row.Name=name
 for index,option in ipairs(options) do
  UI.button(row,option.label,function() onSelect(option.id) end,{
   Name=name.."_"..option.id,Position=UDim2.new((index-1)/#options,0,0,0),
   Size=UDim2.new(1/#options,-6,0,44),TextSize=12,
   BackgroundColor3=selected==option.id and C.gold or C.card,
   TextColor3=selected==option.id and C.background or C.text})
 end
end

local lastChestResult
local selectedChest="rare"
local confirmChest
local premiumCategory="hero"
local inventoryFilter="owned"
local inventoryView={query="",rarity="all",sort="collection",leaderPick=false}
local function contextChests(body,data)
 if data and Catalog.Chests[data.chestId] then selectedChest=data.chestId; data.chestId=nil; confirmChest=nil end
 local collection=Catalog.Chests[selectedChest].kind or "hero"
 local isBase=collection=="base"
 local itemCatalog=isBase and Catalog.Bases or Catalog.Heroes
 local owned=isBase and (profile().bases or {outpost=true}) or (profile().heroes or {})
 local function itemName(id) return L(itemCatalog[id].name) end
 local function portrait(parent,id,properties)
  if isBase then return UI.basePortrait(parent,Catalog.Bases[id],properties) end
  return heroPortrait(parent,id,properties)
 end
 categoryTabs(body,"CollectionTabs",{{id="hero",label=T("HERÓIS","HEROES")},{id="base",label=T("BASES","BASES")}},collection,function(kind) selectedChest=kind=="base" and "base_rare" or "rare"; confirmChest=nil; lastChestResult=nil; renderContext() end)
 local ids=isBase and Catalog.BaseChestOrder or Catalog.HeroChestOrder
 local options={}
 for _,id in ipairs(ids) do table.insert(options,{id=id,label=L(Catalog.Chests[id].name)}) end
 categoryTabs(body,"ChestTabs",{options[1],options[2],options[3]},selectedChest,function(id) selectedChest=id; confirmChest=nil; renderContext() end)
 categoryTabs(body,"ChestTopTabs",{options[4],options[5]},selectedChest,function(id) selectedChest=id; confirmChest=nil; renderContext() end)
 UI.secondary(body,isBase and T("VER MINHAS BASES","MY BASE COLLECTION") or T("VER MEUS HERÓIS","MY HERO COLLECTION"),function() openContext(isBase and "bases" or "inventory") end,{Size=UDim2.new(1,-6,0,44),TextSize=12})
	UI.label(body,T("SEU OURO: ","YOUR GOLD: ")..number(profile().gold),{Name="ChestBalance",Size=UDim2.new(1,-6,0,30),TextColor3=C.gold,Font=Enum.Font.GothamBold,TextSize=16})
	smallText(body,T("Escolha um baú. Abrir a loja não gasta Ouro.","Choose a chest. Opening the shop spends no Gold."),0,30)
	if lastChestResult and ((lastChestResult.baseId~=nil)==isBase) then
		local r=lastChestResult
		local itemId=r.baseId or r.heroId
		local row=UI.roundFrame(body,{Name="ChestResult",Size=UDim2.new(1,-6,0,154),BackgroundColor3=C.card},UI.color(Catalog.Rarities[r.rarity].color))
		portrait(row,itemId,{Position=UDim2.fromOffset(4,4),Size=UDim2.fromOffset(100,130)})
		UI.label(row,itemName(itemId),{Position=UDim2.fromOffset(112,10),Size=UDim2.new(1,-126,0,44),TextSize=20,TextWrapped=true,Font=Enum.Font.GothamBlack})
		UI.label(row,r.duplicate and (T("Repetido: +","Duplicate: +")..r.refundGold..T(" Ouro e +"," Gold and +")..r.refundMastery..T(" maestria"," mastery")) or T("NOVO HERÓI DESBLOQUEADO!","NEW HERO UNLOCKED!"),{Position=UDim2.fromOffset(112,57),Size=UDim2.new(1,-126,0,38),TextWrapped=true,TextSize=12,TextColor3=C.gold})
		if isBase then
			for _,label in ipairs(row:GetChildren()) do if label:IsA("TextLabel") and label.TextColor3==C.gold then label.Text=r.duplicate and ("+"..r.refundGold..T(" Ouro por repetida"," Gold for duplicate")) or T("NOVA BASE!","NEW BASE!") end end
		end
		UI.button(row,isBase and T("VER BASES","VIEW BASES") or T("VER HERÓI","VIEW HERO"),function() openContext(isBase and "bases" or "hero",{heroId=r.heroId}) end,{Position=UDim2.fromOffset(112,100),Size=UDim2.new(1,-126,0,44),TextSize=12})
	end
	for _,id in ipairs({selectedChest}) do
		local chest=Catalog.Chests[id]; local tint=UI.color(chest.color)
		local display=UI.roundFrame(body,{Name="ChestDisplay_"..id,Size=UDim2.new(1,-6,0,146),BackgroundColor3=tint:Lerp(C.background,0.65)},tint)
		UI.shade(display,35)
		UI.printTexture(display,tint)
		local halo=UI.frame(display,{Position=UDim2.fromOffset(8,16),Size=UDim2.fromOffset(110,110),BackgroundColor3=C.gold,BackgroundTransparency=0.85})
		UI.corner(halo,100)
		UI.stroke(halo,C.gold,2).Transparency=0.55
		local chestArt=UI.frame(display,{Name="ChestIllustration",BackgroundTransparency=1,Position=UDim2.fromOffset(12,20),Size=UDim2.fromOffset(104,100)})
		UI.roundFrame(chestArt,{Position=UDim2.fromOffset(7,42),Size=UDim2.fromOffset(92,53),BackgroundColor3=tint:Lerp(C.background,0.3)},tint)
		UI.roundFrame(chestArt,{Position=UDim2.fromOffset(3,18),Size=UDim2.fromOffset(100,35),BackgroundColor3=tint},C.gold)
		for _,x in ipairs({20,77}) do UI.frame(chestArt,{Position=UDim2.fromOffset(x,20),Size=UDim2.fromOffset(9,71),BackgroundColor3=C.gold}) end
		UI.roundFrame(chestArt,{Position=UDim2.fromOffset(42,42),Size=UDim2.fromOffset(24,25),BackgroundColor3=C.gold},tint)
		UI.label(chestArt,"◆",{Position=UDim2.fromOffset(43,40),Size=UDim2.fromOffset(22,25),TextColor3=C.background,TextXAlignment=Enum.TextXAlignment.Center,TextSize=17})
		UI.label(display,Catalog.Upper(L(chest.name)),{Position=UDim2.fromOffset(128,20),Size=UDim2.new(1,-140,0,49),Font=Enum.Font.GothamBlack,TextColor3=tint,TextSize=21,TextWrapped=true})
		UI.label(display,number(chest.cost)..T(" OURO"," GOLD"),{Position=UDim2.fromOffset(128,79),Size=UDim2.new(1,-140,0,24),Font=Enum.Font.GothamBold,TextColor3=C.gold})
		UI.label(display,isBase and T("1 base • chances abaixo","1 base • odds below") or T("1 herói • chances abaixo","1 hero • odds below"),{Position=UDim2.fromOffset(128,110),Size=UDim2.new(1,-140,0,25),TextSize=11,TextColor3=C.muted,TextWrapped=true})
		local forced=chest.pity and ((profile().pity or {})[id] or 0)+1>=chest.pity.after
		if chest.pity then smallText(body,T("Garantia ","Guarantee ")..L(Catalog.Rarities[chest.pity.minimum].name).."+: "..tostring((profile().pity or {})[id] or 0).."/"..chest.pity.after..(forced and T(" • ATIVA NESTE BAÚ"," • ACTIVE NOW") or ""),0,44) end
		local total=0
		local minimum=forced and table.find(Catalog.RarityOrder,chest.pity.minimum) or 1
		for index,rarity in ipairs(Catalog.RarityOrder) do if index>=minimum then total+=chest.odds[rarity] or 0 end end
		local summary={}
		for index,rarity in ipairs(Catalog.RarityOrder) do
			local weight=index>=minimum and (chest.odds[rarity] or 0) or 0
			if weight>0 then table.insert(summary,L(Catalog.Rarities[rarity].name).." "..string.format("%.1f%%",weight/total*100)) end
		end
		smallText(body,table.concat(summary,"  •  "),0,48)
		local eligible=(profile().gold or 0)>=chest.cost and not profile().paidRandomRestricted
		if confirmChest==id then
			local confirmation=UI.roundFrame(body,{Name="ChestConfirmation",Size=UDim2.new(1,-6,0,138),BackgroundColor3=C.gold:Lerp(C.background,0.9)},C.gold)
			UI.label(confirmation,T("ABRIR 1 BAÚ POR ","OPEN 1 CHEST FOR ")..number(chest.cost)..T(" OURO?"," GOLD?"),{Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-24,0,42),TextWrapped=true,TextSize=15,Font=Enum.Font.GothamBold,TextColor3=C.gold})
			UI.label(confirmation,T("Seu saldo depois: ","Balance afterwards: ")..number((profile().gold or 0)-chest.cost)..(isBase and T(" Ouro. Uma base aleatória."," Gold. One random base.") or T(" Ouro. Um herói aleatório."," Gold. One random hero.")),{Position=UDim2.fromOffset(12,51),Size=UDim2.new(1,-24,0,30),TextWrapped=true,TextSize=12})
			local yes=UI.button(confirmation,T("CONFIRMAR","CONFIRM"),function()
				if pending.OpenChest then return end
				pending.OpenChest=true; confirmChest=nil; renderContext()
				task.spawn(function()
					local response=request("OpenChest",{chestId=id})
					pending.OpenChest=nil
					if response and response.ok then
						lastChestResult=response.data and response.data.result
						if lastChestResult then celebrate:Chest(lastChestResult,id) else audio:Cue("chest") end
					end
					if contextPanel and contextPanel.kind=="chests" then renderContext() end
				end)
			end,{Name="ConfirmChest_"..id,Position=UDim2.fromOffset(12,86),Size=UDim2.new(0.6,-18,0,44),TextSize=12,BackgroundColor3=C.gold})
			if not eligible or pending.OpenChest then UI.disabled(yes) end
			UI.secondary(confirmation,T("CANCELAR","CANCEL"),function() confirmChest=nil; renderContext() end,{Name="CancelChest",Position=UDim2.new(0.6,0,0,86),Size=UDim2.new(0.4,-12,0,44),TextSize=12})
		else
			local buy=UI.button(body,pending.OpenChest and T("ABRINDO…","OPENING…") or T("ABRIR ","OPEN ")..Catalog.Upper(L(chest.name)).." • "..number(chest.cost)..T(" OURO"," GOLD"),function() confirmChest=id; renderContext() end,{Name="OpenChest_"..id,Size=UDim2.new(1,-6,0,48),BackgroundColor3=tint,TextSize=14})
			if not eligible or pending.OpenChest then UI.disabled(buy) end
		end
		if not profile().paidRandomRestricted and (profile().gold or 0)<chest.cost then
			smallText(body,T("Faltam ","You need ")..number(chest.cost-(profile().gold or 0))..T(" Ouro. Ganhe nas partidas ou resgate seus prêmios gratuitos."," more Gold. Earn it in matches or claim your free rewards."),0,44)
		end
		UI.section(body,T("DENTRO DESTE BAÚ","INSIDE THIS CHEST"),isBase and T("Chances por base. Repetidas devolvem até 40% do custo em Ouro.","Odds per base. Duplicates refund up to 40% of the cost in Gold.") or T("Chances por herói nesta abertura. Repetidos viram Ouro e XP do herói.","Hero odds for this opening. Duplicates become Gold and hero XP."))
		for index,rarity in ipairs(Catalog.RarityOrder) do
			local weight=index>=minimum and (chest.odds[rarity] or 0) or 0
			if weight>0 then
				local pool=Rules.ChestPool(rarity,collection); local fresh={}
				for _,heroId in ipairs(pool) do if not owned[heroId] then table.insert(fresh,heroId) end end
				local candidates=#fresh>0 and fresh or pool
				local rarityTint=UI.color(Catalog.Rarities[rarity].color)
				UI.label(body,Catalog.Upper(L(Catalog.Rarities[rarity].name)),{Size=UDim2.new(1,-6,0,24),TextColor3=rarityTint,Font=Enum.Font.GothamBold,TextSize=13})
				local size=screenSize(); local width=UI.contextLayout(size.X,size.Y).w-34
				local columns=math.max(1,math.min(3,math.floor((width+8)/140)))
				local cell=(width-(columns-1)*8)/columns
				local gallery=UI.frame(body,{Name="ChestContents_"..rarity,Size=UDim2.new(1,-6,0,math.ceil(#pool/columns)*144-8),BackgroundTransparency=1})
				for heroIndex,heroId in ipairs(pool) do
					local chance=contains(candidates,heroId) and weight/total/#candidates*100 or 0
					local card=UI.roundFrame(gallery,{Name="ChestHero_"..heroId,Position=UDim2.fromOffset((heroIndex-1)%columns*(cell+8),math.floor((heroIndex-1)/columns)*144),Size=UDim2.fromOffset(cell,136),BackgroundColor3=rarityTint:Lerp(C.background,0.9)},rarityTint)
					portrait(card,heroId,{Position=UDim2.fromOffset(4,3),Size=UDim2.new(1,-8,0,65)})
					UI.label(card,itemName(heroId),{Position=UDim2.fromOffset(6,70),Size=UDim2.new(1,-12,0,34),TextWrapped=true,TextSize=12,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center})
					UI.label(card,string.format("%.4f%%",chance),{Name="ChestOdds_"..heroId,Position=UDim2.fromOffset(6,110),Size=UDim2.new(1,-12,0,20),TextColor3=rarityTint,TextSize=12,TextXAlignment=Enum.TextXAlignment.Center})
				end
			end
		end
		smallText(body,T("Novos itens têm prioridade dentro da raridade sorteada. Veja o conteúdo e as chances antes de confirmar.","Unowned items take priority within the rolled rarity. Review contents and odds before confirming."),0,54)
	end
	if profile().paidRandomRestricted then
		smallText(body,T("Abertura de baús indisponível para esta conta. Aqui você compra o herói ou a base que escolher, com Ouro, pelo preço médio de tirar no baú.","Chest openings are unavailable for this account. Here you buy the exact hero or base you choose, with Gold, at the average cost of drawing it."),0,58)
		UI.section(body,T("COMPRA GARANTIDA","GUARANTEED PURCHASE"),T("Sem sorteio: você escolhe e recebe exatamente este item.","No draw: you choose and get exactly this item."))
		local owned=profile().heroes or {}
		local ownedBases=profile().bases or {}
		local function offer(id,name,rarity,isOwned)
			local price=Rules.GuaranteedPrice(id)
			if not price or isOwned then return end
			local row=UI.roundFrame(body,{Name="Guaranteed_"..id,Size=UDim2.new(1,-6,0,58),BackgroundColor3=C.card})
			UI.label(row,name,{Position=UDim2.fromOffset(12,4),Size=UDim2.new(1,-170,0,26),Font=UI.Fonts.display,TextSize=15})
			UI.label(row,Catalog.Upper(L(Catalog.Rarities[rarity].name)),{Position=UDim2.fromOffset(12,30),Size=UDim2.new(1,-170,0,20),TextSize=11,TextColor3=UI.color(Catalog.Rarities[rarity].color)})
			local button=UI.button(row,"🪙 "..number(price),function() act("BuyGuaranteed",{itemId=id}) end,{AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-8,0.5,0),Size=UDim2.fromOffset(148,44),BackgroundColor3=C.gold,TextSize=14})
			if (profile().gold or 0)<price then UI.disabled(button) end
		end
		for _,id in ipairs(Catalog.HeroOrder) do local def=Catalog.Heroes[id]; offer(id,L(def.name),def.rarity,owned[id]~=nil) end
		for _,id in ipairs(Catalog.BaseOrder) do local def=Catalog.Bases[id]; offer(id,L(def.name),def.rarity,ownedBases[id]==true) end
	end
end

local function contextPremium(body)
 categoryTabs(body,"PremiumTabs",{{id="hero",label=T("HERÓIS","HEROES")},{id="pass",label=T("PASSES","PASSES")},{id="product",label=T("OURO","GOLD")}},premiumCategory,function(id) premiumCategory=id; renderContext() end)
	UI.section(body,T("LOJA ROBUX","ROBUX SHOP"),T("Heróis garantidos, passes e Ouro. Preços consultados no Roblox.","Guaranteed heroes, passes and Gold. Prices loaded from Roblox."))
	for _,group in ipairs({{kind="hero",items=Catalog.Products.Heroes},{kind="pass",items=Catalog.Products.Passes},{kind="product",items=Catalog.Products.Consumables}}) do
		if group.kind~=premiumCategory then continue end
		local keys={}; for key in pairs(group.items) do table.insert(keys,key) end; table.sort(keys)
		for _,key in ipairs(keys) do
			local def=group.items[key]; local info=productInfo[group.kind..":"..key]
			local owned=group.kind=="hero" and (profile().heroes or {})[key] or group.kind=="pass" and (profile().passes or {})[key]
			local tint=group.kind=="hero" and UI.color(Catalog.Rarities[Catalog.Heroes[key].rarity].color) or group.kind=="pass" and C.green or C.gold
			local row=UI.roundFrame(body,{Size=UDim2.new(1,-6,0,154),BackgroundColor3=tint:Lerp(C.panel,0.82)},tint:Lerp(C.stroke,0.4))
			local left=92
			local art=UI.portraitStage(row,tint,{Position=UDim2.fromOffset(7,7),Size=UDim2.fromOffset(75,96)})
			if group.kind=="hero" then heroPortrait(row,key,{Position=UDim2.fromOffset(4,4),Size=UDim2.fromOffset(80,100)})
			else UI.icon(art,group.kind=="pass" and "star" or "chest",tint,{Position=UDim2.fromOffset(15,23),Size=UDim2.fromOffset(46,46)}) end
			UI.label(row,L(def.name),{Position=UDim2.fromOffset(left,8),Size=UDim2.new(1,-left-12,0,40),TextWrapped=true,Font=Enum.Font.GothamBlack,TextSize=15})
			UI.label(row,group.kind=="hero" and L(Catalog.Heroes[key].role) or def.description and L(def.description) or T("Ouro para recrutar e evoluir.","Gold to recruit and upgrade."),{Position=UDim2.fromOffset(left,52),Size=UDim2.new(1,-left-12,0,48),TextWrapped=true,TextSize=12,TextColor3=C.muted})
			local buy=UI.button(row,owned and T("ADQUIRIDO","OWNED") or info and tostring(info.price).." Robux" or T("Indisponível","Unavailable"),function()
				if not info or owned then return end
				local ok=pcall(function() if group.kind=="pass" then MarketplaceService:PromptGamePassPurchase(player,info.id) else MarketplaceService:PromptProductPurchase(player,info.id) end end)
				if not ok then showToast(T("Falha ao abrir compra.","Could not open purchase."),true) end
			end,{Position=UDim2.fromOffset(10,103),Size=UDim2.new(1,-20,0,44),BackgroundColor3=tint,TextSize=12})
			if not info or owned then UI.disabled(buy) end
		end
	end
	fetchProducts()
end

local function contextShop(body, data)
	if data.shopKind then premiumCategory=data.shopKind; data.shopKind=nil end
	contextPremium(body)
end

local function contextQuests(body)
	UI.section(body, T("Missões e conquistas", "Missions and achievements"), T("Diárias acumulam por até 3 dias.", "Daily missions accumulate for up to 3 days."))
	local quests = {}
	for id, quest in pairs(profile().quests or {}) do table.insert(quests, {id = id, quest = quest}) end
	table.sort(quests, function(a, b) return a.id < b.id end)
	for _, item in ipairs(quests) do
		local quest, id = item.quest, item.id
		local card = UI.roundFrame(body, {Size = UDim2.new(1, -6, 0, 176), BackgroundColor3 = C.card})
		heading(card, L(quest.name), 10)
		smallText(card, L(quest.description), 39, 34)
		local progress = math.min(quest.progress or 0, quest.target or 1)
		local fill = UI.bar(card, C.green, UDim2.fromOffset(14, 78), UDim2.new(1, -28, 0, 7))
		fill.Size = UDim2.fromScale(progress / math.max(quest.target or 1, 1), 1)
		smallText(card, progress .. "/" .. (quest.target or 1) .. "  •  " .. number(quest.gold or 0) .. T(" Ouro  +  ", " Gold  +  ") .. number(quest.xp or 0) .. " XP", 91, 22)
		local claim = UI.button(card, quest.claimed and T("Resgatado ✓", "Claimed ✓") or T("Resgatar recompensa", "Claim reward"), function() act("ClaimQuest", {questId = id}) end, {Position = UDim2.new(0, 12, 1, -54), Size = UDim2.new(1, -24, 0, 44)})
		if quest.claimed or progress < (quest.target or 1) then UI.disabled(claim) end
	end
	if #quests == 0 then UI.label(body, T("Conclua o treinamento para iniciar suas missões.", "Complete training to begin your missions."), {Size = UDim2.new(1, -6, 0, 40), TextWrapped = true, TextColor3 = C.muted}) end
	UI.section(body, T("Títulos", "Titles"))
	local titles = {}
	for id, name in pairs(profile().titles or {}) do table.insert(titles, {id = id, name = name}) end
	table.sort(titles, function(a, b) return a.id < b.id end)
	local currentTitle = profile().title or ""
	UI.secondary(body, T("Sem título", "No title") .. (currentTitle == "" and "  ✓" or ""), function() act("SetTitle", {titleId = ""}) end, {Size = UDim2.new(1, -6, 0, 38), TextSize = 13, TextColor3 = currentTitle == "" and C.green or C.text})
	for _, entry in ipairs(titles) do
		local selected = currentTitle == entry.id
		UI.secondary(body, "✦ " .. L(entry.name) .. (selected and "  ✓" or ""), function() act("SetTitle", {titleId = entry.id}) end, {Size = UDim2.new(1, -6, 0, 40), TextSize = 13, TextColor3 = selected and C.green or C.gold})
	end
	UI.section(body, T("Galeria de feitos", "Achievement gallery"))
	local count = 0
	for _, achievement in pairs(profile().achievements or {}) do
		count += 1
		local row = UI.roundFrame(body, {Size = UDim2.new(1, -6, 0, 54), BackgroundColor3 = C.card})
		heading(row, "✦  " .. L(achievement.name), 14, C.gold)
	end
	if count == 0 then UI.label(body, T("Suas vitórias e títulos aparecerão aqui.", "Your victories and titles will appear here."), {Size = UDim2.new(1, -6, 0, 40), TextColor3 = C.muted, TextWrapped = true}) end
end

local boardMode="ranked"
local function loadBoard()
	local maps=Rules.MapsForMode(boardMode)
	if not table.find(maps,boardMap) then boardMap=maps[1] end
	act("Leaderboard", {mapId = boardMap, size = boardSize, modeId=boardMode}, function(data) boardData = data; if contextPanel and contextPanel.kind == "leaderboard" then renderContext() end end)
end

local function contextLeaderboard(body)
	local maps=Rules.MapsForMode(boardMode)
	if not table.find(maps,boardMap) then boardMap=maps[1] end
 boardMode="ranked"
 if boardMode=="ranked" then
  local rank=Rules.RankForWaves(boardData and boardData.personal or 0)
  UI.section(body,T("SEU RANK: ","YOUR RANK: ")..(language=="en" and rank.en or rank.pt),T("Bronze 10 • Prata 20 • Ouro 30 • Diamante 40 • Lenda 50 ondas","Bronze 10 • Silver 20 • Gold 30 • Diamond 40 • Legend 50 waves"))
 end
	UI.section(body, T("Lendas da resistência", "Legends of the resistance"), T("Evolução real da conta • temporadas de 60 dias.", "Real account progression • 60-day seasons."))
	local controls = UI.row(body, 46)
	UI.secondary(controls, mapName(boardMap), function()
		local index = table.find(maps, boardMap) or 1
		boardMap = maps[index % #maps + 1]
		boardData = nil; renderContext(); loadBoard()
	end, {Size = UDim2.new(0.6, -6, 0, 40), TextSize = 12})
	UI.secondary(controls, tostring(boardSize) .. T(" jogador(es)", " player(s)"), function() boardSize = boardSize % 4 + 1; boardData = nil; renderContext(); loadBoard() end, {Position = UDim2.new(0.6, 4, 0, 0), Size = UDim2.new(0.4, -4, 0, 40), TextSize = 12})
	local row = UI.roundFrame(body, {Size = UDim2.new(1, -6, 0, 66), BackgroundColor3 = C.card})
	heading(row, T("Sua melhor marca: ", "Your personal best: ") .. tostring(boardData and boardData.personal or 0) .. T(" ondas", " waves"), 10, C.green)
	smallText(row, T("Temporada ", "Season ") .. tostring(boardData and boardData.season or profile().season or 1), 38, 22)
	if boardData and boardData.rows then
		for _, entry in ipairs(boardData.rows) do
			local entryRow = UI.roundFrame(body, {Size = UDim2.new(1, -6, 0, 56), BackgroundColor3 = entry.userId == player.UserId and Color3.fromRGB(24, 54, 49) or C.card})
			UI.label(entryRow, "#" .. tostring(entry.rank), {Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(49, 30), Font = Enum.Font.GothamBold, TextColor3 = C.gold})
			local tier=Rules.RankForWaves(entry.waves)
			local title=(entry.name or tostring(entry.userId))..(boardMode=="ranked" and ("\n"..(language=="en" and tier.en or tier.pt)) or "")
			UI.label(entryRow, title, {Position = UDim2.fromOffset(65, 6), Size = UDim2.new(1, -145, 0, 42), TextSize = 12, TextWrapped=true})
			UI.label(entryRow, tostring(entry.waves), {Position = UDim2.new(1, -72, 0, 10), Size = UDim2.fromOffset(58, 30), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, TextColor3 = C.green})
		end
		if #boardData.rows == 0 then UI.label(body, T("Seja o primeiro a deixar sua marca neste setor.", "Be the first to set a record in this sector."), {Size = UDim2.new(1, -6, 0, 50), TextWrapped = true, TextColor3 = C.muted}) end
	else UI.label(body, T("Carregando placar…", "Loading leaderboard…"), {TextColor3 = C.muted}) end
	UI.secondary(body, T("Atualizar placar", "Refresh leaderboard"), loadBoard, {Size = UDim2.new(1, -6, 0, 40)})
end

-- Four small loops around the main game, all decided by the server's clock:
-- a free chest on a timer, a daily login streak, gifts for time played today
-- and one-time milestones for the collection. Nothing here can be bought.
local lastRewardResult
local function rewardGiven(paid)
	if type(paid) ~= "table" then return end
	local parts = {}
	if paid.gold and paid.gold > 0 then table.insert(parts, "+" .. number(paid.gold) .. T(" Ouro", " Gold")) end
	if paid.xp and paid.xp > 0 then table.insert(parts, "+" .. number(paid.xp) .. " XP") end
	if paid.chest then
		local hero = Catalog.Heroes[paid.chest.heroId]
		table.insert(parts, paid.chest.duplicate and T("herói repetido → recompensa", "duplicate hero → reward") or (T("novo herói: ", "new hero: ") .. (hero and L(hero.name) or paid.chest.heroId)))
	end
	lastRewardResult = paid
	showToast(#parts > 0 and table.concat(parts, "  •  ") or T("Recompensa resgatada!", "Reward claimed!"), false)
	if paid.chest then celebrate:Chest(paid.chest, paid.chest.chestId) else audio:Cue("upgrade") end
end

local function contextRewards(body)
	local rewards = profile().rewards
	if not rewards then
		UI.label(body, T("Carregando prêmios…", "Loading rewards…"), {Size = UDim2.new(1, -6, 0, 40), TextColor3 = C.muted})
		return
	end
	UI.section(body, T("VOLTE TODO DIA", "COME BACK EVERY DAY"), T("Baú grátis, sequência de login, presentes por tempo jogado e metas de coleção.", "A free chest, a login streak, gifts for time played and collection milestones."))
	if lastRewardResult and lastRewardResult.chest then
		local r = lastRewardResult.chest
		local row = UI.roundFrame(body, {Name = "RewardChestResult", Size = UDim2.new(1, -6, 0, 100), BackgroundColor3 = C.card}, UI.color(Catalog.Rarities[r.rarity].color))
		heroPortrait(row, r.heroId, {Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(72, 92)})
		UI.label(row, heroName(r.heroId), {Position = UDim2.fromOffset(84, 10), Size = UDim2.new(1, -96, 0, 30), Font = Enum.Font.GothamBlack, TextSize = 16, TextWrapped = true})
		UI.label(row, r.duplicate and T("Repetido: virou Ouro e maestria", "Duplicate: turned into Gold and mastery") or T("NOVO HERÓI!", "NEW HERO!"), {Position = UDim2.fromOffset(84, 44), Size = UDim2.new(1, -96, 0, 40), TextSize = 12, TextWrapped = true, TextColor3 = C.gold})
	end

	-- Free chest: opens on the spot, then makes you wait.
	local chest = rewards.freeChest
	local freeCard = UI.roundFrame(body, {Name = "FreeChestCard", Size = UDim2.new(1, -6, 0, 92), BackgroundColor3 = C.card}, chest.ready and C.gold or C.stroke)
	UI.icon(freeCard, "chest", chest.ready and C.gold or C.muted, {Position = UDim2.fromOffset(12, 14), Size = UDim2.fromOffset(40, 40)})
	UI.label(freeCard, T("Baú grátis", "Free chest"), {Position = UDim2.fromOffset(62, 10), Size = UDim2.new(1, -180, 0, 26), Font = Enum.Font.GothamBold, TextSize = 16})
	UI.label(freeCard, chest.ready and T("Pronto para abrir!", "Ready to open!") or (T("Pronto em ", "Ready in ") .. math.floor(chest.remaining / 3600) .. "h" .. math.floor((chest.remaining % 3600) / 60) .. "m"), {Position = UDim2.fromOffset(62, 38), Size = UDim2.new(1, -180, 0, 24), TextSize = 12, TextColor3 = C.muted})
	local claimFree = UI.button(freeCard, T("ABRIR", "OPEN"), function()
		act("ClaimFreeChest", {}, function(snapshot) rewardGiven(snapshot.result) end)
	end, {Name = "ClaimFreeChest", Position = UDim2.new(1, -108, 0, 24), Size = UDim2.fromOffset(96, 44), BackgroundColor3 = C.gold})
	if not chest.ready then UI.disabled(claimFree) end

	-- Login streak: a seven-day strip, the ready day highlighted.
	UI.section(body, T("Sequência de login", "Login streak"), T("Um dia perdido é perdoado; dois reiniciam a sequência.", "One missed day is forgiven; two reset the streak."))
	-- lastCompletedIndex is the slot most recently claimed (today's, if the
	-- streak already paid out today; otherwise yesterday's). Everything up to
	-- it is checked off, except the slot about to be claimed, which is next.
	local cycle = rewards.login.cycle
	local lastCompletedIndex = rewards.login.streak > 0 and (((rewards.login.streak - 1) % cycle) + 1) or 0
	local strip = UI.row(body, 78)
	for day = 1, cycle do
		local def = Catalog.Rewards.login[day]
		local isNext = rewards.login.claimable and day == rewards.login.nextIndex
		local done = not isNext and day <= lastCompletedIndex
		local cell = UI.roundFrame(strip, {Name = "LoginDay_" .. day, Position = UDim2.new((day - 1) / cycle, 2, 0, 0), Size = UDim2.new(1 / cycle, -4, 1, 0),
			BackgroundColor3 = isNext and C.gold:Lerp(C.card, 0.15) or C.card}, isNext and C.gold or C.stroke)
		UI.label(cell, T("Dia ", "Day ") .. day, {Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 16), TextSize = 10, TextColor3 = isNext and C.gold or C.muted})
		UI.label(cell, def.chest and "🎁" or ("+" .. number(def.gold)), {Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 26), TextSize = def.chest and 18 or 13, Font = Enum.Font.GothamBold, TextColor3 = isNext and C.gold or C.text})
		if done then UI.label(cell, "✓", {Position = UDim2.fromOffset(0, 52), Size = UDim2.new(1, 0, 0, 20), TextSize = 14, TextColor3 = C.green}) end
	end
	local claimLogin = UI.button(body, rewards.login.claimable and (T("RESGATAR DIA ", "CLAIM DAY ") .. rewards.login.nextIndex) or T("Volte amanhã", "Come back tomorrow"), function()
		act("ClaimLogin", {}, function(snapshot) rewardGiven(snapshot.result) end)
	end, {Name = "ClaimLogin", Size = UDim2.new(1, -6, 0, 46), BackgroundColor3 = C.gold})
	if not rewards.login.claimable then UI.disabled(claimLogin) end

	-- Playtime gifts: how long you have played today, in one bar with markers.
	UI.section(body, T("Presentes de hoje", "Today's gifts"), T("O tempo reinicia a cada dia.", "Time resets every day."))
	for _, gift in ipairs(rewards.playtime.gifts) do
		local card = UI.roundFrame(body, {Name = "PlaytimeGift_" .. gift.index, Size = UDim2.new(1, -6, 0, 60), BackgroundColor3 = C.card})
		local progress = math.clamp(rewards.playtime.seconds / (gift.minutes * 60), 0, 1)
		local fill = UI.bar(card, gift.claimed and C.muted or C.green, UDim2.fromOffset(12, 10), UDim2.new(1, -130, 0, 8))
		fill.Size = UDim2.fromScale(progress, 1)
		UI.label(card, gift.minutes .. T(" min de jogo", " min played"), {Position = UDim2.fromOffset(12, 24), Size = UDim2.new(1, -130, 0, 30), TextSize = 12, TextColor3 = C.muted})
		local claim = UI.button(card, gift.claimed and T("RESGATADO", "CLAIMED") or (gift.chest and T("BAÚ", "CHEST") or ("+" .. number(gift.gold))), function()
			act("ClaimPlaytime", {index = gift.index}, function(snapshot) rewardGiven(snapshot.result) end)
		end, {Name = "ClaimPlaytime_" .. gift.index, Position = UDim2.new(1, -108, 0, 10), Size = UDim2.fromOffset(96, 40), BackgroundColor3 = gift.ready and C.green or C.card, TextSize = 12})
		if not gift.ready then UI.disabled(claim) end
	end

	-- Collection milestones: how many different heroes the account owns.
	UI.section(body, T("Metas de coleção", "Collection milestones"), T("Você tem ", "You own ") .. rewards.collection.owned .. T(" de ", " of ") .. #Catalog.HeroOrder .. T(" heróis.", " heroes."))
	for _, milestone in ipairs(rewards.collection.milestones) do
		local card = UI.roundFrame(body, {Name = "Milestone_" .. milestone.index, Size = UDim2.new(1, -6, 0, 60), BackgroundColor3 = C.card})
		UI.label(card, milestone.count .. T(" heróis", " heroes"), {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -130, 0, 26), Font = Enum.Font.GothamBold, TextSize = 14})
		local sub = "+" .. number(milestone.gold) .. T(" Ouro", " Gold") .. (milestone.title and T("  •  título", "  •  title") or "")
		UI.label(card, sub, {Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -130, 0, 22), TextSize = 11, TextColor3 = C.muted})
		local claim = UI.button(card, milestone.claimed and T("RESGATADO", "CLAIMED") or T("RESGATAR", "CLAIM"), function()
			act("ClaimMilestone", {index = milestone.index}, function(snapshot) rewardGiven(snapshot.result) end)
		end, {Name = "ClaimMilestone_" .. milestone.index, Position = UDim2.new(1, -108, 0, 10), Size = UDim2.fromOffset(96, 40), BackgroundColor3 = milestone.ready and C.gold or C.card, TextSize = 12})
		if milestone.claimed or not milestone.ready then UI.disabled(claim) end
	end

	-- Codes, the group and friends: the ways a YouTuber, a Discord or a friend
	-- brings someone in. The server checks every code and the group membership.
	UI.section(body, T("CÓDIGOS E AMIGOS", "CODES AND FRIENDS"), T("Códigos saem nas redes do jogo. Cada código vale uma vez por conta.", "Codes are posted on the game's socials. Each one works once per account."))
	local codeRow = UI.roundFrame(body, {Name = "CodeRow", Size = UDim2.new(1, -6, 0, 60), BackgroundColor3 = C.card})
	local codeBox = UI.create("TextBox", {
		Name = "CodeInput", Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -128, 0, 44), BackgroundColor3 = C.background,
		Text = "", PlaceholderText = T("Digite o código", "Type the code"), ClearTextOnFocus = false,
		Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = C.text, PlaceholderColor3 = C.muted,
	}, codeRow)
	UI.corner(codeBox, 10)
	UI.button(codeRow, T("USAR", "REDEEM"), function()
		local typed = codeBox.Text or ""
		if typed == "" then showToast(T("Digite um código primeiro.", "Type a code first."), true) return end
		act("RedeemCode", {code = typed}, function(snapshot)
			codeBox.Text = ""
			rewardGiven(snapshot and snapshot.result)
		end)
	end, {Name = "RedeemCode", Position = UDim2.new(1, -110, 0, 8), Size = UDim2.fromOffset(100, 44), BackgroundColor3 = C.gold, TextSize = 14})
	if (tonumber(Config.GroupId) or 0) > 0 then
		local group = rewards.group or {}
		local groupCard = UI.roundFrame(body, {Name = "GroupReward", Size = UDim2.new(1, -6, 0, 60), BackgroundColor3 = C.card})
		UI.label(groupCard, T("Entre no grupo do jogo", "Join the game's group"), {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -130, 0, 24), Font = Enum.Font.GothamBold, TextSize = 14})
		UI.label(groupCard, "+" .. number(group.gold or 0) .. T(" Ouro, uma vez", " Gold, once"), {Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -130, 0, 20), TextSize = 11, TextColor3 = C.muted})
		local claimGroup = UI.button(groupCard, group.claimed and T("RESGATADO", "CLAIMED") or T("RESGATAR", "CLAIM"), function()
			act("ClaimGroupReward", {}, function(snapshot) rewardGiven(snapshot and snapshot.result) end)
		end, {Name = "ClaimGroupReward", Position = UDim2.new(1, -110, 0, 8), Size = UDim2.fromOffset(100, 44), BackgroundColor3 = C.gold, TextSize = 12})
		if group.claimed then UI.disabled(claimGroup) end
	end
	UI.button(body, T("CONVIDAR AMIGOS", "INVITE FRIENDS"), function()
		-- Roblox's own invite sheet: it decides who can be invited and how.
		local ok = pcall(function()
			local social = game:GetService("SocialService")
			if social:CanSendGameInviteAsync(player) then social:PromptGameInvite(player) else error("cannot invite") end
		end)
		if not ok then showToast(T("Convites indisponíveis agora.", "Invites are unavailable right now."), true) end
	end, {Name = "InviteFriends", Size = UDim2.new(1, -6, 0, 48), BackgroundColor3 = C.blue, TextSize = 14})
end

local function contextSquad(body)
	local screen=screenSize()
	local wide=UI.contextLayout(screen.X,screen.Y).w>=530
	local formation=UI.row(body,wide and 96 or 78)
	local lineup=UI.frame(formation,{Name="SquadSlots",Size=UDim2.new(wide and 0.72 or 1,0,1,0),BackgroundTransparency=1})
	local base=Catalog.Bases[profile().equippedBase or "outpost"] or Catalog.Bases.outpost
	local baseCard=UI.secondary(wide and formation or body,"",function() openContext("bases") end,{Name="OpenBases",Position=wide and UDim2.fromScale(0.73,0) or UDim2.fromOffset(0,0),Size=wide and UDim2.new(0.27,-6,0,96) or UDim2.new(1,-6,0,80),BackgroundColor3=C.green:Lerp(C.panel,0.9)})
	UI.stroke(baseCard,C.green,1)
	UI.label(baseCard,T("BASE • TROCAR ›","BASE • CHANGE ›"),{Position=UDim2.fromOffset(8,6),Size=UDim2.new(1,-16,0,20),TextColor3=C.green,Font=Enum.Font.GothamBold,TextSize=11})
	UI.basePortrait(baseCard,base,{Position=UDim2.fromOffset(5,30),Size=UDim2.fromOffset(50,44)})
	UI.label(baseCard,L(base.name),{Name="FormationBaseName",Position=UDim2.fromOffset(61,30),Size=UDim2.new(1,-69,0,42),TextWrapped=true,Font=Enum.Font.GothamBold,TextSize=12})
	for slot=1,5 do
		local id=(profile().loadout or {})[slot]
		local tile=UI.secondary(lineup,"",function()
			if slot==1 then inventoryView.leaderPick=not inventoryView.leaderPick; inventoryFilter="owned"; inventoryView.query=""; inventoryView.rarity="all"; renderContext()
			elseif id and inventoryView.leaderPick then makeLeader(id,function() inventoryView.leaderPick=false; renderContext() end)
			elseif id then openContext("hero",{heroId=id}) else inventoryFilter="owned"; renderContext(); showToast(T("Escolha um herói abaixo e toque em Adicionar à equipe.","Choose a hero below, then tap Equip hero.")) end
		end,{Name="SquadSlot_"..slot,Position=UDim2.new((slot-1)/5,0,0,0),Size=UDim2.new(0.2,-6,0,78),BackgroundColor3=slot==1 and C.gold:Lerp(C.background,0.8) or C.card})
		if slot==1 then UI.stroke(tile,C.gold,2) end
		if id then heroPortrait(tile,id,{Position=UDim2.fromOffset(4,3),Size=UDim2.new(1,-8,0,53)})
		else UI.label(tile,"+",{Position=UDim2.fromOffset(0,4),Size=UDim2.new(1,0,0,47),TextSize=32,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Center}) end
		UI.label(tile,slot==1 and T("★ LÍDER","★ LEADER") or tostring(slot),{Position=UDim2.new(0,2,1,-21),Size=UDim2.new(1,-4,0,18),TextSize=10,Font=Enum.Font.GothamBold,TextColor3=slot==1 and C.gold or C.muted,TextXAlignment=Enum.TextXAlignment.Center})
	end
	if inventoryView.leaderPick then
		UI.section(body,T("QUEM VAI LIDERAR?","WHO WILL LEAD?"),T("Toque em um herói da equipe ou da coleção. O poder ativo passa a ser o dele.","Tap a hero in your squad or collection. Their skill becomes your active power."))
		UI.secondary(body,T("CANCELAR TROCA DE LÍDER","CANCEL LEADER CHANGE"),function() inventoryView.leaderPick=false; renderContext() end,{Name="CancelLeaderPick",Size=UDim2.new(1,-6,0,44),TextSize=12})
	end
	local leader=(profile().loadout or {})[1]
	if leader then
		local banner=UI.roundFrame(body,{Name="LeaderBanner",Size=UDim2.new(1,-6,0,64),BackgroundColor3=C.gold:Lerp(C.background,0.85)},C.gold)
		UI.label(banner,T("★ LÍDER — define sua habilidade: ","★ LEADER — sets your ability: ")..heroName(leader),{Position=UDim2.fromOffset(12,5),Size=UDim2.new(1,-150,0,22),Font=UI.Fonts.display,TextColor3=C.gold,TextWrapped=true,TextSize=14})
		UI.label(banner,T("PODER: ","POWER: ")..L(Catalog.Abilities[Catalog.Heroes[leader].ability].name),{Position=UDim2.fromOffset(12,29),Size=UDim2.new(1,-150,0,30),TextWrapped=true,TextSize=12})
		-- Changing the leader is an explicit choice, not only a drag of cards.
		UI.button(banner,inventoryView.leaderPick and T("ESCOLHENDO…","CHOOSING…") or T("TROCAR LÍDER","CHANGE LEADER"),function()
			inventoryView.leaderPick=not inventoryView.leaderPick; inventoryFilter="owned"; inventoryView.query=""; inventoryView.rarity="all"; renderContext()
		end,{Name="ChangeLeader",AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),Size=UDim2.fromOffset(128,44),BackgroundColor3=C.gold,TextSize=13})
	end
 local ownedCount=0
 for _,id in ipairs(Catalog.HeroOrder) do if (profile().heroes or {})[id] then ownedCount+=1 end end
 UI.label(body,T("SUA COLEÇÃO • ","YOUR COLLECTION • ")..ownedCount.."/"..#Catalog.HeroOrder,{Size=UDim2.new(1,-6,0,26),TextColor3=C.coral,Font=Enum.Font.GothamBold,TextSize=15})
 categoryTabs(body,"InventoryTabs",{{id="owned",label=T("MEUS HERÓIS","MY HEROES")},{id="all",label=T("TODOS","ALL")}},inventoryFilter,function(id) inventoryFilter=id; renderContext() end)
	local searchRow=UI.row(body,50)
	local search=UI.create("TextBox",{Name="HeroSearch",Position=UDim2.fromOffset(0,2),Size=UDim2.new(1,-96,0,44),BackgroundColor3=C.card,Text=inventoryView.query,PlaceholderText=T("Buscar nome ou função...","Search name or role..."),ClearTextOnFocus=false,TextColor3=C.text,PlaceholderColor3=C.muted,TextSize=14,Font=Enum.Font.Gotham,TextXAlignment=Enum.TextXAlignment.Left},searchRow)
	UI.corner(search,10); UI.padding(search,10)
	search:GetPropertyChangedSignal("Text"):Connect(function() inventoryView.query=search.Text end)
	search.FocusLost:Connect(function() inventoryView.query=search.Text; task.defer(renderContext) end)
	UI.button(searchRow,T("BUSCAR","SEARCH"),function() inventoryView.query=search.Text; renderContext() end,{Name="SearchHeroes",Position=UDim2.new(1,-90,0,2),Size=UDim2.fromOffset(84,44),TextSize=12,BackgroundColor3=C.coral})
	local filterRow=UI.row(body,44)
	UI.secondary(filterRow,inventoryView.rarity=="all" and T("RARIDADE: TODAS","RARITY: ALL") or L(Catalog.Rarities[inventoryView.rarity].name).." ›",function()
		local index=table.find(Catalog.RarityOrder,inventoryView.rarity) or 0
		inventoryView.rarity=Catalog.RarityOrder[index+1] or "all"; renderContext()
	end,{Name="CycleHeroRarity",Size=UDim2.new(0.5,-5,0,44),TextSize=11})
	local sorts={"collection","rarity","level","cost","name"}
	local sortNames={collection=T("COLEÇÃO","COLLECTION"),rarity=T("RARIDADE ↓","RARITY ↓"),level=T("NÍVEL ↓","LEVEL ↓"),cost=T("CUSTO ↑","COST ↑"),name=T("NOME A–Z","NAME A–Z")}
	UI.secondary(filterRow,sortNames[inventoryView.sort].." ›",function() inventoryView.sort=sorts[(table.find(sorts,inventoryView.sort) or 0)%#sorts+1]; renderContext() end,{Name="CycleHeroSort",Position=UDim2.new(0.5,0,0,0),Size=UDim2.new(0.5,-6,0,44),TextSize=11})
	local entries=UI.collectionEntries(Catalog,profile(),{query=inventoryView.query,rarity=inventoryView.rarity,sort=inventoryView.sort,ownership=inventoryFilter},language)
	local filterActive=inventoryView.query~="" or inventoryView.rarity~="all"
	local summary=UI.row(body,filterActive and 44 or 24)
	UI.label(summary,tostring(#entries)..T(" heróis encontrados"," heroes found"),{Name="HeroSearchCount",Size=UDim2.new(filterActive and 0.55 or 1,-8,1,0),TextColor3=C.muted,TextSize=11})
	if filterActive then UI.secondary(summary,T("LIMPAR","CLEAR"),function() inventoryView.query=""; inventoryView.rarity="all"; renderContext() end,{Name="ClearHeroFilters",Position=UDim2.fromScale(0.55,0),Size=UDim2.new(0.45,-6,0,44),TextSize=11}) end
 local size=screenSize()
 local width=UI.contextLayout(size.X,size.Y).w-34
 local columns=math.max(1,math.min(3,math.floor((width+10)/165)))
 local cellWidth=(width-(columns-1)*10)/columns
	if #entries==0 then UI.section(body,T("NENHUM HERÓI ENCONTRADO","NO HEROES FOUND"),T("Tente outro nome, limpe os filtros ou abra a aba Todos para ver a coleção completa.","Try another name, clear filters or open All to browse the full collection.")) end
 local gallery=UI.frame(body,{Name="HeroGallery",Size=UDim2.new(1,-6,0,math.max(0,math.ceil(#entries/columns)*282-10)),BackgroundTransparency=1})
 for index,id in ipairs(entries) do
  local def=Catalog.Heroes[id]
  local owned=(profile().heroes or {})[id]
  local rarity=Catalog.Rarities[def.rarity]
  local tint=UI.color(rarity.color)
  local slot=table.find(profile().loadout or {},id)
  local row=UI.roundFrame(gallery,{Name="Collection_"..id,Position=UDim2.fromOffset(((index-1)%columns)*(cellWidth+10),math.floor((index-1)/columns)*282),Size=UDim2.fromOffset(cellWidth,272),BackgroundColor3=C.cream},id==leader and C.gold or tint)
  UI.shade(row,30)
  UI.portraitStage(row,tint,{Name="HeroArtwork",Position=UDim2.fromOffset(5,27),Size=UDim2.new(1,-10,0,101)})
  heroPortrait(row,id,{Position=UDim2.new(0,5,0,28),Size=UDim2.new(1,-10,0,100)})
  UI.label(row,Catalog.Upper(L(rarity.name)),{Position=UDim2.fromOffset(9,7),Size=UDim2.new(1,-18,0,18),TextColor3=C.background,Font=Enum.Font.GothamBlack,TextSize=10})
  UI.label(row,heroName(id),{Position=UDim2.fromOffset(9,131),Size=UDim2.new(1,-18,0,38),Font=Enum.Font.GothamBlack,TextSize=13,TextWrapped=true,TextColor3=C.background})
  UI.label(row,owned and (T("NÍVEL ","LEVEL ")..owned.level.."/20") or T("AINDA NÃO TEM","NOT OWNED YET"),{Position=UDim2.fromOffset(9,172),Size=UDim2.new(1,-18,0,18),TextSize=10,TextColor3=C.panel})
	UI.label(row,L(def.role),{Position=UDim2.fromOffset(9,191),Size=UDim2.new(1,-18,0,28),TextWrapped=true,TextSize=10,TextColor3=C.panel})
  UI.button(row,inventoryView.leaderPick and owned and T("ESCOLHER LÍDER","CHOOSE LEADER") or slot==1 and T("★ LÍDER","★ LEADER") or slot and (T("NA EQUIPE • ","EQUIPPED • ")..slot) or T("VER HERÓI","VIEW HERO"),function()
		if inventoryView.leaderPick and owned then makeLeader(id,function() inventoryView.leaderPick=false; renderContext() end) else openContext("hero",{heroId=id}) end
	end,{Name="FormationHero_"..id,Position=UDim2.fromOffset(7,221),Size=UDim2.new(1,-14,0,44),BackgroundColor3=id==leader and C.gold or owned and tint or C.card,TextColor3=owned and C.background or C.text,TextSize=11})
 end
	UI.section(body, T("Formações salvas", "Saved formations"), T("Salve a equipe e seu líder.", "Save your squad and leader."))
	local slots = profile().loadoutSlots or (profile().passes and profile().passes.formations and 8 or 3)
	for slot = 1, slots do
		local saved = profile().savedLoadouts and profile().savedLoadouts[tostring(slot)]
		local row = UI.roundFrame(body, {Size = UDim2.new(1, -6, 0, 64), BackgroundColor3 = C.card})
		UI.label(row, T("Formação ", "Formation ") .. slot .. (saved and "  ✓" or ""), {Position = UDim2.fromOffset(12, 10), Size = UDim2.new(0.4, -12, 0, 36), TextSize = 12})
		UI.secondary(row, T("Salvar", "Save"), function() act("SaveLoadout", {slot = slot}, function() showToast(T("Formação salva.", "Formation saved.")) end) end, {Position = UDim2.new(0.4, 0, 0, 10), Size = UDim2.new(0.3, -10, 0, 44)})
		local load = UI.button(row, T("Usar", "Load"), function() act("LoadLoadout", {slot = slot}) end, {Position = UDim2.new(0.7, 0, 0, 10), Size = UDim2.new(0.3, -12, 0, 44)})
		if not saved then UI.disabled(load) end
	end
end

local function contextSettings(body)
 UI.button(body,T("APRENDER A JOGAR • 20 ONDAS","LEARN TO PLAY • 20 WAVES"),function() act("StartMatch",{mapId="manhattan",modeId="tutorial"}) end,{Name="OptionalTutorial",Size=UDim2.new(1,-6,0,44)})
	UI.section(body, T("Seu jeito de jogar", "Your experience"), T("Acessibilidade e apresentação. As regras de combate são iguais para todos.", "Accessibility and presentation. Combat rules are the same for everyone."))
	local settings = profile().settings or {}
	local effectsOn = settings.effects
	if effectsOn == nil then effectsOn = settings.music ~= false end
	local options = {
		{title = T("Idioma", "Language"), value = language == "pt" and "Português (Brasil)" or "English", key = "language", next = language == "pt" and "en" or "pt"},
		{title = T("Menos efeitos e flashes", "Fewer effects and flashes"), value = settings.lowFX and T("Ligado", "On") or T("Desligado", "Off"), key = "lowFX", next = not settings.lowFX},
		{title = T("Movimento de câmera", "Camera movement"), value = settings.shake and T("Ligado", "On") or T("Desligado", "Off"), key = "shake", next = not settings.shake},
		{title = T("Música", "Music"), value = settings.music ~= false and T("Ligado", "On") or T("Desligado", "Off"), key = "music", next = settings.music == false},
		{title = T("Efeitos sonoros", "Sound effects"), value = effectsOn and T("Ligado", "On") or T("Desligado", "Off"), key = "effects", next = not effectsOn},
		{title = T("Sons da interface", "Interface sounds"), value = settings.interface ~= false and T("Ligado", "On") or T("Desligado", "Off"), key = "interface", next = settings.interface == false},
	}
	for _, option in ipairs(options) do
		local card = UI.roundFrame(body, {Size = UDim2.new(1, -6, 0, 100), BackgroundColor3 = C.card})
		heading(card, option.title, 10)
		UI.secondary(card, option.value .. "  ↻", function()
			local update = {}
			update[option.key] = option.next
			act("Settings", update)
		end, {Position = UDim2.fromOffset(12, 43), Size = UDim2.new(1, -24, 0, 44)})
	end
	UI.section(body, T("Controles", "Controls"))
	UI.label(body, T("1–5: escolher herói  •  Q: poder do líder\nClique ou toque: selecionar posição / torre\nConfirmar: posicionar  •  Esc / Cancelar: cancelar seleção", "1–5: choose hero  •  Q: leader power\nClick or tap: select position / tower\nConfirm: place tower  •  Esc / Cancel: cancel selection"), {Size = UDim2.new(1, -6, 0, 90), TextColor3 = C.muted, TextSize = 13, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
end

local talentBranch = 1
local talentSelected, talentZoom = nil, 1
local function contextTalents(body)
	local p = profile()
	local points = p.talentPoints or 0
	local ranks = p.talents or {}
	local overview = UI.roundFrame(body, {Name = "TalentOverview", Size = UDim2.new(1, -6, 0, 126), BackgroundColor3 = Color3.fromRGB(68,43,91)}, C.violet)
	UI.printTexture(overview,C.violet)
	UI.label(overview,T("CADA AVENTURA TE FAZ CRESCER!", "EVERY ADVENTURE HELPS YOU GROW!"),{Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,18),Font=Enum.Font.GothamBlack,TextColor3=C.gold,TextSize=11})
	UI.label(overview, tostring(points), {Position = UDim2.fromOffset(14, 29), Size = UDim2.fromOffset(62, 53), TextSize = 46, Font = Enum.Font.GothamBlack, TextColor3 = C.gold})
	UI.label(overview, T("PONTOS DISPONÍVEIS", "AVAILABLE POINTS"), {Position = UDim2.fromOffset(82, 35), Size = UDim2.new(1, -92, 0, 22), TextSize = 12, Font = Enum.Font.GothamBold})
	UI.label(overview, T("Subiu de nível? Ganhou 1 ponto! Escolha o que melhorar.", "Level up, earn 1 point! Choose what to improve."), {Position = UDim2.fromOffset(82, 59), Size = UDim2.new(1, -92, 0, 40), TextWrapped = true, TextSize = 12, TextColor3 = C.muted})
	local track = UI.roundFrame(overview, {Position = UDim2.fromOffset(14, 110), Size = UDim2.new(1, -28, 0, 6), BackgroundColor3 = C.background})
	UI.frame(track, {Size = UDim2.fromScale(levelProgress(), 1), BackgroundColor3 = C.gold})
	-- The tree is a honeycomb on a canvas you can drag, zoom and re-centre:
	-- one column per branch, each talent a hexagon, lines to its parent.
	-- Tapping a hexagon shows its card below: now → next, cost, requirement.
	local COLUMN_X, ROW_Y, TOP, HEX = 190, 112, 92, 92
	local positions, mapW, mapH = {}, 0, 0
	for b, branch in ipairs(Catalog.TalentBranches) do
		for index, id in ipairs(branch.nodes) do
			local x = 100 + (b - 1) * COLUMN_X
			local y = TOP + (index - 1) * ROW_Y + (b % 2 == 0 and ROW_Y / 2 or 0)
			positions[id] = Vector2.new(x, y)
			mapW, mapH = math.max(mapW, x + 100), math.max(mapH, y + 80)
		end
	end
	local function available(id)
		local def = Catalog.Talents[id]
		return not def.parent or (ranks[def.parent] or 0) >= def.requiredRank
	end
	if not talentSelected or not Catalog.Talents[talentSelected] then
		for _, branch in ipairs(Catalog.TalentBranches) do
			for _, id in ipairs(branch.nodes) do
				if not talentSelected and available(id) and (ranks[id] or 0) < Catalog.Talents[id].maxRank then talentSelected = id end
			end
		end
		talentSelected = talentSelected or Catalog.TalentBranches[1].nodes[1]
	end
	local controls = UI.row(body, 44)
	local canvasH = math.clamp(screenSize().Y - 330, 220, 430)
	local canvas = UI.scroll(body, {Name = "TalentTree", Size = UDim2.new(1, -6, 0, canvasH), ScrollingDirection = Enum.ScrollingDirection.XY,
		AutomaticCanvasSize = Enum.AutomaticSize.None, CanvasSize = UDim2.fromOffset(mapW * talentZoom, mapH * talentZoom),
		BackgroundTransparency = 0.35, BackgroundColor3 = C.ink, ScrollBarThickness = 8})
	UI.corner(canvas, 14)
	local map = UI.frame(canvas, {Name = "TalentMap", Size = UDim2.fromOffset(mapW, mapH), BackgroundTransparency = 1})
	UI.create("UIScale", {Scale = talentZoom}, map)
	local function centreOn(id)
		local at = positions[id]
		if not at then return end
		local view = canvas.AbsoluteSize
		local w, h = (view and view.X > 0) and view.X or 500, (view and view.Y > 0) and view.Y or canvasH
		canvas.CanvasPosition = Vector2.new(math.max(0, at.X * talentZoom - w / 2), math.max(0, at.Y * talentZoom - h / 2))
	end
	UI.secondary(controls, "−", function() talentZoom = math.max(0.6, talentZoom - 0.2); renderContext() end, {Name = "TalentZoomOut", Size = UDim2.fromOffset(52, 44), TextSize = 24})
	UI.secondary(controls, "+", function() talentZoom = math.min(1.6, talentZoom + 0.2); renderContext() end, {Name = "TalentZoomIn", Position = UDim2.fromOffset(58, 0), Size = UDim2.fromOffset(52, 44), TextSize = 24})
	UI.secondary(controls, T("CENTRALIZAR", "CENTRE"), function() centreOn(talentSelected) end, {Name = "TalentCentre", Position = UDim2.fromOffset(116, 0), Size = UDim2.fromOffset(140, 44), TextSize = 14})
	-- Hexagons: the UI has no polygons, so three bars turned 0/60/120° form one.
	local function hexagon(parent, name, center, width, tint, z)
		local root = UI.frame(parent, {Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(center.X, center.Y), Size = UDim2.fromOffset(width, width), BackgroundTransparency = 1, ZIndex = z})
		local r = width / 2
		for _, angle in ipairs({0, 60, 120}) do
			UI.frame(root, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(r, r * 1.732), Rotation = angle, BackgroundColor3 = tint, ZIndex = z})
		end
		return root
	end
	for b, branch in ipairs(Catalog.TalentBranches) do
		local tint = Color3.fromRGB(unpack(branch.color))
		local first = positions[branch.nodes[1]]
		UI.label(map, L(branch.name), {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.fromOffset(first.X, 8), Size = UDim2.fromOffset(COLUMN_X - 10, 30), TextSize = 20, Font = UI.Fonts.display, TextColor3 = tint, TextXAlignment = Enum.TextXAlignment.Center})
		for index, id in ipairs(branch.nodes) do
			local def = Catalog.Talents[id]
			local rank, open = ranks[id] or 0, available(id)
			local at = positions[id]
			if index > 1 then
				local from = positions[branch.nodes[index - 1]]
				local dx, dy = at.X - from.X, at.Y - from.Y
				UI.frame(map, {Name = "TalentLink", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((at.X + from.X) / 2, (at.Y + from.Y) / 2), Size = UDim2.fromOffset(8, math.sqrt(dx * dx + dy * dy)), Rotation = math.deg(math.atan2(dx, -dy)), BackgroundColor3 = open and tint or C.card, ZIndex = 1})
			end
			local selected = id == talentSelected
			hexagon(map, "TalentHexOutline_" .. id, at, HEX + 8, selected and C.gold or C.ink, 2)
			hexagon(map, "TalentHex_" .. id, at, HEX, rank > 0 and tint or (open and tint:Lerp(C.panel, 0.55) or C.card), 3)
			UI.label(map, def.icon or "?", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y - 10), Size = UDim2.fromOffset(HEX, 30), TextSize = 22, Font = UI.Fonts.display, TextColor3 = open and C.text or C.muted, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4})
			UI.label(map, rank .. "/" .. def.maxRank, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y + 18), Size = UDim2.fromOffset(HEX, 22), TextSize = 15, Font = UI.Fonts.display, TextColor3 = rank >= def.maxRank and C.gold or C.text, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4})
			UI.button(map, "", function() talentSelected = id; renderContext() end, {Name = "TalentNode_" .. id, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y), Size = UDim2.fromOffset(HEX, HEX), BackgroundTransparency = 1, ZIndex = 5})
		end
	end
	-- The chosen talent's card: exactly what one more point does, and why not.
	do
		local id = talentSelected
		local def = Catalog.Talents[id]
		local branchTint = C.violet
		for _, branch in ipairs(Catalog.TalentBranches) do if table.find(branch.nodes, id) then branchTint = Color3.fromRGB(unpack(branch.color)) end end
		local rank, open = ranks[id] or 0, available(id)
		local unit = def.unit == "%" and "%" or (def.unit == "HP" and " HP" or (def.unit == "gold" and " 🪙" or ""))
		local function value(r) return (r > 0 and "+" or "") .. tostring(r * def.effect) .. unit end
		local card = UI.roundFrame(body, {Name = "Talent_" .. id, Size = UDim2.new(1, -6, 0, 196), BackgroundColor3 = branchTint:Lerp(C.background, 0.78)}, branchTint)
		UI.label(card, L(def.name), {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -90, 0, 30), TextSize = 20, Font = UI.Fonts.display, TextColor3 = branchTint})
		UI.label(card, rank .. " / " .. def.maxRank, {Position = UDim2.new(1, -82, 0, 10), Size = UDim2.fromOffset(70, 26), TextSize = 18, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Right})
		UI.label(card, L(def.description), {Position = UDim2.fromOffset(12, 40), Size = UDim2.new(1, -24, 0, 40), TextWrapped = true, TextSize = 12, TextColor3 = C.muted, TextYAlignment = Enum.TextYAlignment.Top})
		local nowNext = rank >= def.maxRank and (T("Agora: ", "Now: ") .. value(rank) .. T("  •  nível máximo", "  •  max level"))
			or (T("Agora: ", "Now: ") .. value(rank) .. "  →  " .. T("Próximo: ", "Next: ") .. value(rank + 1) .. "  •  " .. T("custa 1 ponto", "costs 1 point"))
		UI.label(card, nowNext, {Name = "TalentNowNext", Position = UDim2.fromOffset(12, 84), Size = UDim2.new(1, -24, 0, 26), TextSize = 15, Font = UI.Fonts.display, TextColor3 = C.gold})
		local parentDef = def.parent and Catalog.Talents[def.parent]
		local need = not open and parentDef and (T("Requer ", "Requires ") .. L(parentDef.name) .. " " .. def.requiredRank .. "/" .. parentDef.maxRank) or ""
		UI.label(card, need, {Position = UDim2.fromOffset(12, 110), Size = UDim2.new(1, -24, 0, 22), TextSize = 12, TextColor3 = C.red})
		local label = rank >= def.maxRank and T("COMPLETO!", "COMPLETE!") or not open and T("BLOQUEADO", "LOCKED") or points < 1 and T("GANHE MAIS XP", "EARN MORE XP") or T("EVOLUIR • 1 PONTO", "UPGRADE • 1 POINT")
		local button = UI.button(card, label, function()
			act("UpgradeTalent", {talentId = id, expectedRank = rank}, function() audio:Cue("upgrade"); showToast(L(def.name) .. "  " .. (rank + 1) .. "/" .. def.maxRank) end)
		end, {Name = "UpgradeTalent_" .. id, Position = UDim2.fromOffset(12, 138), Size = UDim2.new(1, -24, 0, 48), BackgroundColor3 = branchTint, TextSize = 15})
		if not open or rank >= def.maxRank or points < 1 then UI.disabled(button) end
	end
	task.defer(function() if canvas.Parent then centreOn(talentSelected) end end)
	local confirmReset = false
	local reset
	reset = UI.secondary(body, T("Redistribuir pontos • grátis", "Reset points • free"), function()
		if not confirmReset then confirmReset = true; reset.Text = T("Confirmar redistribuição", "Confirm reset"); return end
		act("ResetTalents", {}, function() showToast(T("Pontos devolvidos. Experimente outra especialidade!", "Points refunded. Try a different specialty!")) end)
	end, {Size = UDim2.new(1, -6, 0, 44)})
end

local function contextModes(body)
	UI.section(body,T("ESCOLHA SEU DESTINO","CHOOSE YOUR DESTINATION"),T("Cada portal tem seu mapa e seu modo. Para jogar com amigos, entrem no mesmo portal.","Each portal has its own map and mode. To play with friends, enter the same portal."))
	if not profile().tutorialComplete then
		local first=UI.roundFrame(body,{Name="FirstMission",Size=UDim2.new(1,-6,0,168),BackgroundColor3=C.gold:Lerp(C.panel,0.78)},C.gold)
		UI.label(first,T("COMECE AQUI!","START HERE!"),{Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,36),TextSize=26,Font=Enum.Font.GothamBlack,TextColor3=C.gold})
		UI.label(first,T("Aprenda em 20 ondas e ganhe 1.000 Ouro na primeira vitória.","Learn in 20 waves and earn 1,000 Gold on your first victory."),{Position=UDim2.fromOffset(14,46),Size=UDim2.new(1,-28,0,58),TextSize=13,TextWrapped=true})
		UI.button(first,T("JOGAR O TREINO • 20 ONDAS","PLAY TRAINING • 20 WAVES"),function() act("StartMatch",{mapId="manhattan",modeId="tutorial"}) end,{Name="PlayMode_tutorial",Position=UDim2.fromOffset(12,112),Size=UDim2.new(1,-24,0,46),BackgroundColor3=C.gold,TextSize=14})
	end
	local colors={manhattan=C.coral,gamma=C.green,asgard=C.gold,hydra=C.red,wakanda=C.violet,latveria=C.blue}
	local lastDistrict
	for _,id in ipairs(Catalog.DestinationOrder) do
		local destination=Catalog.Destinations[id]
		local map,mode=Catalog.Maps[destination.mapId],Catalog.Modes[destination.modeId]
		local tint=colors[destination.mapId]
		-- One heading per lobby district, in the order the portals stand.
		local district=destination.district or "center"
		if district~=lastDistrict then
			lastDistrict=district
			local headings={
				center={T("CAMPANHA","CAMPAIGN"),T("Os três portais do centro do refúgio. Comece por aqui!","The three portals in the middle of the refuge. Start here!")},
				expedition={T("EXPEDIÇÕES","EXPEDITIONS"),T("Campanhas mais longas nos cantos do sul: Wakanda, Asgard e a final, Latvéria (70 ondas).","Longer campaigns in the southern corners: Wakanda, Asgard and the finale, Latveria (70 waves).")},
				arena={T("ARENA COMPETITIVA","COMPETITIVE ARENA"),T("Três portais vizinhos. Cada mapa tem seu placar e exige uma estratégia diferente.","Three neighboring portals. Each map has its own leaderboard and calls for a different strategy.")},
				special={T("TREINO E CARTAS","TRAINING & CARDS"),T("Treino de 20 ondas e o roguelike de cartas.","The 20-wave training and the card roguelike.")},
			}
			local heading=headings[district]
			if heading then UI.section(body,heading[1],heading[2]) end
		end
		local allowed=Rules.ModeUnlocked(profile(),destination.modeId)
		local card=UI.roundFrame(body,{Name="Destination_"..id,Size=UDim2.new(1,-6,0,178),BackgroundColor3=tint:Lerp(C.panel,0.88)},tint)
		UI.mapArt(card,map,tint,{Position=UDim2.fromOffset(10,18),Size=UDim2.fromOffset(96,76)})
		UI.label(card,L(map.name),{Position=UDim2.fromOffset(118,10),Size=UDim2.new(1,-132,0,42),TextSize=19,Font=Enum.Font.GothamBlack,TextColor3=tint,TextWrapped=true})
		local waves=Rules.WaveCount(destination.modeId,destination.mapId)
		UI.label(card,L(mode.name).." • "..(waves==0 and T("SEM FIM","ENDLESS") or tostring(waves).." "..T("ONDAS","WAVES")),{Position=UDim2.fromOffset(118,54),Size=UDim2.new(1,-132,0,24),TextSize=12,Font=Enum.Font.GothamBold,TextWrapped=true})
		UI.label(card,allowed and L(map.description) or L(modeLockHints[destination.modeId]),{Position=UDim2.fromOffset(118,81),Size=UDim2.new(1,-132,0,40),TextSize=11,TextWrapped=true,TextColor3=C.muted})
		local button=UI.button(card,allowed and T("JOGAR NESTE MAPA","PLAY THIS MAP") or T("AINDA BLOQUEADO","LOCKED FOR NOW"),function() act("StartMatch",{destinationId=id}) end,{Name="PlayDestination_"..id,Position=UDim2.fromOffset(12,126),Size=UDim2.new(1,-24,0,44),BackgroundColor3=allowed and C.green or tint,TextSize=17})
		if not allowed then
			UI.disabled(button)
			-- A lock sticker over the map art, like a locked level card.
			local lock=UI.label(card,"🔒 "..T("BLOQUEADO","LOCKED"),{Name="LockedPill",Position=UDim2.fromOffset(14,70),Size=UDim2.fromOffset(92,24),BackgroundTransparency=0,BackgroundColor3=C.ink,TextSize=12,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center})
			UI.corner(lock,12)
			UI.stroke(lock,Color3.new(1,1,1),1.5)
		end
		if destination.modeId=="ranked" then
			button.Size=UDim2.new(0.64,-18,0,44)
			UI.secondary(card,T("PLACAR","LEADERBOARD"),function()
				boardMode="ranked"; boardMap=destination.mapId; openContext("leaderboard",{})
			end,{Name="DestinationBoard_"..id,Position=UDim2.new(0.64,0,0,126),Size=UDim2.new(0.36,-12,0,44),TextSize=12})
		end
	end
	if profile().tutorialComplete then
		UI.secondary(body,T("TREINAR DE NOVO • 20 ONDAS","TRAIN AGAIN • 20 WAVES"),function() act("StartMatch",{mapId="manhattan",modeId="tutorial"}) end,{Size=UDim2.new(1,-6,0,44)})
	end
end

local function contextBases(body)
	categoryTabs(body,"BaseNavigation",{{id="inventory",label=T("HERÓIS","HEROES")},{id="bases",label=T("BASES","BASES")}},"bases",function(id) openContext(id) end)
	smallText(body,T("Equipe 1 base. Evolua com o Ouro da partida. O nível reinicia a cada partida; sua coleção fica salva.","Equip 1 base. Upgrade with match Gold in battle. Levels reset each match; your collection is saved."),0,58)
	UI.button(body,T("LOJA DE BAÚS DE BASES","BASE CHEST SHOP"),function() openContext("chests",{chestId="base_rare"}) end,{Size=UDim2.new(1,-6,0,44),BackgroundColor3=C.gold,TextSize=13})
	for _,id in ipairs(Catalog.BaseOrder) do
		local def=Catalog.Bases[id]; local stats=Rules.BaseStats(id,1)
		local owned=(profile().bases or {outpost=true})[id]; local equipped=(profile().equippedBase or "outpost")==id
		local tint=UI.color(Catalog.Rarities[def.rarity].color)
		local row=UI.roundFrame(body,{Name="BaseCard_"..id,Size=UDim2.new(1,-6,0,258),BackgroundColor3=C.cream},equipped and C.green or tint)
		UI.basePortrait(row,def,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(100,106)})
		UI.label(row,L(def.name),{Position=UDim2.fromOffset(116,10),Size=UDim2.new(1,-126,0,62),TextSize=17,TextWrapped=true,TextColor3=C.background,Font=Enum.Font.GothamBlack})
		UI.label(row,L(Catalog.Rarities[def.rarity].name),{Position=UDim2.fromOffset(116,76),Size=UDim2.new(1,-126,0,25),TextSize=13,TextColor3=C.background})
		UI.label(row,L(def.description),{Position=UDim2.fromOffset(12,115),Size=UDim2.new(1,-24,0,48),TextSize=13,TextWrapped=true,TextColor3=C.background})
		UI.label(row,"+"..stats.income..T(" Ouro/onda  •  +"," Gold/wave  •  +")..stats.hp..T(" vida*"," HP*"),{Position=UDim2.fromOffset(12,164),Size=UDim2.new(1,-24,0,30),TextSize=12,TextColor3=C.background})
		local button=UI.button(row,equipped and T("EQUIPADA","EQUIPPED") or owned and T("EQUIPAR BASE","EQUIP BASE") or T("ENCONTRAR NOS BAÚS","FIND IN CHESTS"),function()
			if owned then act("EquipBase",{baseId=id}) else openContext("chests",{chestId="base_rare"}) end
		end,{Name="EquipBase_"..id,Position=UDim2.fromOffset(12,204),Size=UDim2.new(1,-24,0,44),BackgroundColor3=equipped and C.green or tint,TextSize=13})
		if equipped then UI.disabled(button) end
	end
	smallText(body,T("*No grupo, cada bônus de vida é dividido pelo tamanho inicial da equipe. Renda exige contribuição na onda.","*In co-op, each HP bonus is divided by the starting party size. Income requires wave contribution."),0,60)
end

local function contextGuide(body)
	local p=profile()
	local intro=UI.roundFrame(body,{Name="RefugeWelcome",Size=UDim2.new(1,-6,0,112),BackgroundColor3=C.cream},C.gold)
	UI.illustration(intro,"guide",C.green,{Position=UDim2.fromOffset(12,18),Size=UDim2.fromOffset(64,64)})
	UI.label(intro,T("BEM-VINDO AO REFÚGIO!","WELCOME TO THE REFUGE!"),{Position=UDim2.fromOffset(87,12),Size=UDim2.new(1,-100,0,36),TextSize=17,TextWrapped=true,Font=Enum.Font.GothamBlack,TextColor3=C.background})
	UI.label(intro,T("Sou o Nico! Prepare sua equipe, explore o bosque e entre em um portal para defender o mundo.","I'm Nico! Prepare your team, explore the woods and step into a portal to defend the world."),{Position=UDim2.fromOffset(87,53),Size=UDim2.new(1,-100,0,49),TextSize=12,TextWrapped=true,TextColor3=C.panel})
	local nextTitle,nextHint,nextPanel
	if not p.tutorialComplete then
		nextTitle=T("SUA PRIMEIRA MISSÃO","YOUR FIRST MISSION")
		nextHint=T("Aprenda a defender em 8 ondas. A primeira vitória no treino dá 1.000 Ouro.","Learn to defend in 8 waves. Your first training victory grants 1,000 Gold.")
		nextPanel="modes"
	elseif (p.talentPoints or 0)>0 then
		nextTitle=T("VOCÊ PODE EVOLUIR!","YOU CAN GROW!")
		nextHint=tostring(p.talentPoints)..T(" ponto(s) para melhorar suas passivas. Escolha na Academia."," point(s) to improve your passives. Choose in the Academy.")
		nextPanel="talents"
	else
		nextTitle=T("PRONTO PARA A PRÓXIMA?","READY FOR THE NEXT ADVENTURE?")
		nextHint=T("O primeiro herói da equipe é seu líder e define seu poder ativo. Confira sua base antes de sair!","Your first hero is the leader and determines your active power. Check your base before leaving!")
		nextPanel="inventory"
	end
	local goal=UI.roundFrame(body,{Name="RefugeNextGoal",Size=UDim2.new(1,-6,0,144),BackgroundColor3=C.panel},C.green)
	UI.label(goal,nextTitle,{Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-24,0,24),TextSize=14,Font=Enum.Font.GothamBold,TextColor3=C.green})
	UI.label(goal,nextHint,{Position=UDim2.fromOffset(12,37),Size=UDim2.new(1,-24,0,45),TextWrapped=true,TextSize=12})
	UI.button(goal,T("VAMOS LÁ","LET'S GO"),function() openContext(nextPanel,{}) end,{Name="GuideNextGoal",Position=UDim2.fromOffset(12,91),Size=UDim2.new(1,-24,0,44),TextSize=13})
	UI.section(body,T("O QUE VOCÊ QUER FAZER?","WHAT WOULD YOU LIKE TO DO?"),T("Abra por aqui ou visite os balcões da praça.","Open it here or visit the desks in the square."))
	local links={
		{"modes",T("Jogar","Play"),T("Solo ou grupo de até 4","Solo or a party of up to 4"),"bolt",C.green},
		{"inventory",T("Minha equipe","My team"),T("5 heróis • 1 líder","5 heroes • 1 leader"),"hero",C.coral},
		{"bases",T("Minha base","My base"),T("Equipe sua defesa","Equip your defense"),"heart",C.green},
		{"talents",T("Academia","Academy"),T("Gaste seus pontos","Spend your points"),"star",C.violet},
		{"chests",T("Baús","Chests"),T("Heróis e bases por Ouro","Heroes and bases for Gold"),"chest",C.gold},
		{"quests",T("Missões","Missions"),T("Objetivos e conquistas","Goals and achievements"),"star",C.coral},
		{"leaderboard",T("Placares","Leaderboards"),T("Ranks e recordes","Ranks and records"),"trophy",C.gold},
		{"settings",T("Opções","Settings"),T("Idioma, som e controles","Language, sound and controls"),"bolt",C.cream},
	}
	local columns=screenSize().X<400 and 1 or 2
	local grid=UI.frame(body,{Name="RefugeDirectory",Size=UDim2.new(1,-6,0,math.ceil(#links/columns)*106),BackgroundTransparency=1})
	for i,entry in ipairs(links) do
		local tile=UI.button(grid,"",function() openContext(entry[1],{}) end,{Name="GuideLink_"..entry[1],Position=UDim2.new(((i-1)%columns)/columns,0,0,math.floor((i-1)/columns)*106),Size=UDim2.new(1/columns,-6,0,98),BackgroundColor3=C.card})
		UI.illustration(tile,entry[4],entry[5],{Position=UDim2.fromOffset(10,12),Size=UDim2.fromOffset(38,38)})
		UI.label(tile,entry[2],{Position=UDim2.fromOffset(57,10),Size=UDim2.new(1,-67,0,40),TextSize=15,Font=Enum.Font.GothamBold,TextWrapped=true,TextColor3=entry[5]})
		UI.label(tile,entry[3],{Position=UDim2.fromOffset(12,55),Size=UDim2.new(1,-24,0,33),TextSize=12,TextWrapped=true,TextColor3=C.muted})
	end
	UI.section(body,T("EXPLORE ALÉM DA PRAÇA","EXPLORE BEYOND THE SQUARE"),T("Siga a trilha da Árvore da Aurora. As pontes levam a três cantinhos para explorar com amigos.","Follow the Aurora Tree trail. The bridges lead to three places to explore with friends."))
	for _,place in ipairs({
		{T("ALDEIA DO BOSQUE","WOODLAND VILLAGE"),T("Atrás da árvore: cabanas coloridas, um poço e mesas de piquenique.","Beyond the tree: colorful cottages, a well and a picnic corner."),"heart",C.green},
		{T("ILHA DOS EXPLORADORES","EXPLORER ISLAND"),T("Ponte oeste: pule pelos troncos e suba as escadas do mirante.","West bridge: hop across the stumps and climb the lookout stairs."),"star",C.gold},
		{T("JARDIM DAS ESTRELAS","STARLIGHT GARDEN"),T("Ponte leste: um laguinho, flores e um observatório para encontrar amigos.","East bridge: a reflecting pool, flowers and an observatory to meet friends."),"star",C.violet},
	}) do
		local card=UI.roundFrame(body,{Name="ExplorePlace",Size=UDim2.new(1,-6,0,114),BackgroundColor3=place[4]:Lerp(C.panel,0.9)},place[4])
		UI.illustration(card,place[3],place[4],{Position=UDim2.fromOffset(12,14),Size=UDim2.fromOffset(32,32)})
		UI.label(card,place[1],{Position=UDim2.fromOffset(54,10),Size=UDim2.new(1,-66,0,38),TextColor3=place[4],TextSize=14,Font=Enum.Font.GothamBold,TextWrapped=true})
		UI.label(card,place[2],{Position=UDim2.fromOffset(14,52),Size=UDim2.new(1,-28,0,52),TextSize=12,TextWrapped=true})
	end
end

local contextBuilders = {
	maps=contextModes,
	guide=contextGuide,
	bases=contextBases,
	modes=contextModes,
	talents = contextTalents,
	hero = contextHero, chests = contextChests, premium = contextPremium, inventory = contextSquad, shop = contextShop,
	quests = contextQuests, leaderboard = contextLeaderboard, squad = contextSquad, settings = contextSettings,
	rewards = contextRewards,
}

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
					productInfo[cacheKey] = response and response.ok and response.data or false
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
	for _,name in ipairs({"LobbyPill","SquadButton","SettingsButton","LobbyNavigation"}) do
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
		entry.button.BackgroundColor3=active and entry.tint:Lerp(C.panel,0.75) or C.panel
		entry.line.Visible=active
		if entry.badge then
			local points=profile().talentPoints or 0
			entry.badge.Visible=points>0
			entry.badge.Text=tostring(points)
		end
	end
end

renderContext = function()
	lobbyChrome(true)
	refreshNavigation()
	if not contextPanel or not state or state.phase ~= "Lobby" then
		contextRefreshPending=false
		if refs.context then refs.context:Destroy(); refs.context=nil; menuBlur(false) end
		return
	end
	local panel=refs.context
	local body=panel and panel:FindFirstChild("ContextBody")
	local reuse=panel and panel.Parent and panel:GetAttribute("ContextKind")==contextPanel.kind and body
	if reuse then
		local focused=UserInputService:GetFocusedTextBox()
		while focused and focused~=panel do focused=focused.Parent end
		if focused==panel then contextRefreshPending=true; return end
	end
	contextRefreshPending=false
	if not reuse and panel then panel:Destroy(); panel=nil; body=nil end
	local size = screenSize()
	local slot=UI.contextLayout(size.X,size.Y,{wide=contextPanel.kind=="talents",elevator=state.elevator~=nil})
	lobbyChrome(not slot.modal)
	local theme=UI.Themes[contextPanel.kind] or UI.Themes.inventory
	local tint=theme.color
	if not panel then panel=UI.roundFrame(main,{Name="ContextPanel",BackgroundColor3=C.background,Active=true}) end
	panel.Position,panel.Size=at(slot),dims(slot)
	if reuse then
		for _,child in ipairs(panel:GetChildren()) do
			if child~=body and not child:IsA("UIComponent") then child:Destroy() end
		end
	end
	-- Header: a band in the screen's colour, the title in big outlined
	-- letters tilted like a sticker, and a round red close button.
	local band=UI.frame(panel,{Name="TitleRibbon",Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,0,52),BackgroundColor3=tint,Active=false})
	UI.corner(band,13)
	UI.shade(band,90,0.32)
	local gloss=UI.frame(band,{Name="Shine",Position=UDim2.new(0,8,0,4),Size=UDim2.new(1,-16,0.34,0),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=0.8,Active=false})
	UI.corner(gloss,8)
	refs.context = panel
	if not reuse then menuBlur(true) end
	panel:SetAttribute("ContextKind",contextPanel.kind)
	local titles = {hero = T("GALERIA DE HERÓIS", "HERO GALLERY"), skill = T("TREINAMENTO", "TRAINING"), shop = T("SUPRIMENTOS", "SUPPLIES"), quests = T("CENTRAL DE MISSÕES", "MISSION BOARD"), leaderboard = T("LENDAS DA RESISTÊNCIA", "RESISTANCE LEGENDS"), squad = T("FORMAÇÃO TÁTICA", "TACTICAL FORMATION"), settings = T("OPÇÕES", "SETTINGS")}
	titles.talents = T("ÁRVORE DE EVOLUÇÃO", "TALENT TREE")
	titles.guide = T("REFÚGIO DA AURORA", "AURORA REFUGE")
	titles.maps = T("ESCOLHA SEU MAPA", "CHOOSE YOUR MAP")
	titles.bases=T("MINHA BASE","MY BASE")
	titles.chests=T("BAÚS • OURO","CHESTS • GOLD"); titles.premium=T("LOJA ROBUX","ROBUX SHOP"); titles.inventory=T("INVENTÁRIO","INVENTORY")
	titles.inventory=T("MEUS HERÓIS","MY HEROES"); titles.modes=T("VAMOS JOGAR!","LET'S PLAY!"); titles.rewards=T("PRÊMIOS DIÁRIOS","DAILY REWARDS")
	local medal=UI.frame(panel,{Name="TitleMedal",Position=UDim2.fromOffset(8,6),Size=UDim2.fromOffset(48,48),BackgroundColor3=C.ink,Active=false})
	UI.corner(medal,24)
	UI.stroke(medal,Color3.new(1,1,1),2)
	UI.illustration(medal,theme.icon,tint,{Position=UDim2.fromOffset(6,6),Size=UDim2.fromOffset(36,36)})
	UI.label(panel, titles[contextPanel.kind] or "DOOMSDAY", {Name="ContextTitle",Position = UDim2.fromOffset(62, 8), Size = UDim2.new(1, -124, 0, 42), TextColor3 = C.text, Font = UI.Fonts.display, TextSize = size.X < 560 and 19 or 24, Rotation = -2})
	local close=UI.button(panel, "×", closeContext, {Name="CloseContext",Position = UDim2.new(1, -54, 0, 5), Size = UDim2.fromOffset(46, 46), TextSize = 32,BackgroundColor3=C.red})
	close:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(0,23)
	if not body then
		body=UI.scroll(panel,{Name="ContextBody",Position=UDim2.fromOffset(14,62),Size=UDim2.new(1,-28,1,-74),ScrollBarImageColor3=tint})
		UI.list(body,10)
	end
	body.ScrollBarImageColor3=tint
	-- A refresh from the server rebuilds the rows, never the reader's place in
	-- the list: remember the scroll and put it back once the rows exist.
	local keepScroll=reuse and body.CanvasPosition or nil
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
local CONTEXT_ANCHOR = {
	chests = {kind="ChestStand",attribute="ChestId",field="chestId"},
	shop = { kind = "ShopStand", attribute = "ShopKey", field = "shopKey" },
	quests = { kind = "Board", attribute = "BoardId", value = "quests" },
	leaderboard = { kind = "Board", attribute = "BoardId", value = "leaderboard" },
}

local function anchorPosition(kind, data)
	local spec = CONTEXT_ANCHOR[kind]
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
	if kind=="hero" then heroDetailTab="power" end
	if kind~="inventory" and kind~="squad" then inventoryView.leaderPick=false end
	data = data or {}
	confirmChest = nil
	data.kind = kind
	data.animate=true
	data.anchor = not data.hud and anchorPosition(kind, data) or nil
	contextPanel = data
	if kind == "leaderboard" then boardData = nil; loadBoard() end
	if refs.firstVisitHint then refs.firstVisitHint.Visible = false end
	renderContext()
end

closeContext = function()
	contextPanel = nil
	confirmChest = nil
	if refs.context then refs.context:Destroy(); refs.context = nil end
	menuBlur(false)
	lobbyChrome(true)
	refreshNavigation()
	if refs.firstVisitHint then refs.firstVisitHint.Visible = not (state and state.elevator) end
end

-- Per-viewer cosmetics on the shared lobby geometry: locked portals, unowned
-- heroes and unlearned skills get a translucent shroud (never a mutation of
-- the server's own parts), and equipped gear gets a highlight outline.
local shroudColor = Color3.fromRGB(8, 10, 14)
local function setShroud(model, locked, hint)
	local existing = model:FindFirstChild("LockShroud")
	if locked then
		if existing then return end
		local ok, cf, size = pcall(function() return model:GetBoundingBox() end)
		if not ok then return end
		local shroud = Instance.new("Part")
		shroud.Name, shroud.Anchored = "LockShroud", true
		shroud.CanCollide, shroud.CanTouch, shroud.CanQuery, shroud.CastShadow = false, false, false, false
		-- Lock state is communicated by the sign, not an opaque box over art.
		shroud.Material, shroud.Color, shroud.Transparency = Enum.Material.SmoothPlastic, shroudColor, 1
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

-- The showroom's props move: the collector drone spins and bobs in its case
-- above its turning ring, as the design brief describes the store.
-- Purely local and cheap; reduced effects leaves them still.
local lobbyProps = nil
local function animateLobby(dt)
	if not state or state.phase ~= "Lobby" then return end
	if profile().settings and profile().settings.lowFX then return end
	if not lobbyProps or (lobbyProps[1] and lobbyProps[1].part.Parent == nil) then
		lobbyProps = {}
		local lobby = workspace:FindFirstChild("DoomLobby")
		-- Each prop turns about a pivot: its own centre for the showroom drone,
		-- the hub for a rotor blade, the mast for the radar dish.
		local function collect(model, partName, pivotName, spin, bob)
			local pivotPart = pivotName and model:FindFirstChild(pivotName)
			for _, child in ipairs(model:GetChildren()) do
				if child.Name == partName and child:IsA("BasePart") then
					local pivot = pivotPart and CFrame.new(pivotPart.Position) or child.CFrame
					table.insert(lobbyProps, {part = child, pivot = pivot, offset = pivot:Inverse() * child.CFrame, spin = spin, bob = bob, angle = 0})
				end
			end
		end
		for _, model in ipairs(lobby and lobby:GetChildren() or {}) do
			if model.Name == "Shop_collector" then
				collect(model, "Drone", nil, 1.8, 0.25)
				collect(model, "DroneRing", nil, -1.2, 0.25)
			elseif model.Name == "Rotor" then
				collect(model, "Blade", "RotorHub", 2.6, 0)
			elseif model.Name == "Radar" then
				collect(model, "RadarDish", "RadarMast", 0.9, 0)
			elseif model:GetAttribute("Kind") == "AfkZone" then
				collect(model, "AfkIcon", nil, 1.4, 0.35)
			elseif model.Name == "CommandAtrium" then
				collect(model, "AuroraCrystal", nil, 0.25, 0.12)
				for _,child in ipairs(model:GetChildren()) do
					if child.Name=="FestivalPennant" then
						table.insert(lobbyProps,{part=child,pivot=child.CFrame,offset=CFrame.new(),spin=0,bob=0,angle=0,sway=child.Position.X*0.08})
					end
				end
			elseif model.Name == "VillageDetails" then
				collect(model, "BeaconCrystal", nil, 0.3, 0.15)
			elseif model.Name == "AuroraSanctuary" then
				collect(model, "ForestMote", nil, 0.3, 0.7)
			end
		end
	end
	local now = os.clock()
	for _, prop in ipairs(lobbyProps) do
		prop.angle += dt * prop.spin
		if prop.sway then
			prop.part.CFrame=prop.pivot*CFrame.Angles(math.sin(now*1.4+prop.sway)*0.08,0,0)
		else
			prop.part.CFrame = prop.pivot * CFrame.new(0, math.sin(now * 2) * prop.bob, 0) * CFrame.Angles(0, prop.angle, 0) * prop.offset
		end
	end
end

-- Each portal's sign says, for this viewer, what stepping in will start:
-- which sector (the campaign's next unbeaten one, today's daily), how many
-- waves, or what is still missing to unlock it.
local function portalSign(model)
	local sign = model:FindFirstChild("Sign")
	local surface = sign and sign:FindFirstChild("Board")
	return surface and surface:FindFirstChildOfClass("TextLabel")
end

local function updatePortal(model, p)
	local portalId = model:GetAttribute("PortalId") or model:GetAttribute("ModeId")
	local modeId = Rules.PortalMode(p, portalId)
	local unlocked = Rules.ModeUnlocked(p, modeId)
	setShroud(model, not unlocked, L(modeLockHints[modeId]))
	local label = portalSign(model)
	if label then
		local mapId = Rules.PortalMap(portalId)
		local mode = Catalog.Modes[modeId]
		if not unlocked then
			label.Text = T("BLOQUEADO", "LOCKED") .. "\n" .. L(modeLockHints[modeId])
			label.TextColor3 = C.red
		elseif mode then
			local count = Rules.WaveCount(modeId, mapId)
			local waves = count == 0 and T("ONDAS INFINITAS", "ENDLESS WAVES") or (tostring(count) .. T(" ONDAS", " WAVES"))
			label.Text = (modeId == "tutorial" and (T("TREINAMENTO", "TRAINING") .. "\n") or "") .. (mapId and Catalog.Upper(mapName(mapId)) or T("MAPA ALEATÓRIO","RANDOM MAP")) .. "\n" .. waves .. "  •  " .. T("ENTRE PARA JOGAR", "STEP IN TO PLAY")
			label.TextColor3 = modeTint[portalId] or C.green
		end
	end
	-- A first-time visitor sees one beacon, over the portal that starts
	-- training, visible from the spawn through the crowd.
	local beacon = model:FindFirstChild("StartHere")
	local wantBeacon = portalId == "normal" and p.tutorialComplete ~= true
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
	if not state or state.phase ~= "Lobby" then return end
	local lobby = workspace:FindFirstChild("DoomLobby")
	if not lobby then
		-- The lobby is built server-side at boot, but a slow client can get its
		-- first snapshot before that model replicates. Without this retry the
		-- shrouds would never appear and every portal would look unlocked.
		if not cosmeticsRetryPending then
			cosmeticsRetryPending = true
			task.delay(1, function()
				cosmeticsRetryPending = false
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
		end
	end
	if localizedLanguage~=language then
		localizedLanguage=language
		for _,obj in ipairs(localizedLabels) do
			local value=obj:GetAttribute(language=="en" and "LobbyTextEN" or "LobbyTextPT")
			if obj:IsA("TextLabel") then obj.Text=value
			elseif obj:IsA("ProximityPrompt") then obj.ObjectText=value; obj.ActionText=T("Abrir","Open") end
		end
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
local elevatorDeadline, elevatorSignature = nil, nil

local function elevatorCountText()
	if not elevatorDeadline then return "" end
	local left = math.max(0, math.ceil(elevatorDeadline - os.clock()))
	return left > 0 and tostring(left) or "…"
end

renderElevator = function()
	local e = state and state.phase == "Lobby" and state.elevator or nil
	if e then
		local deadline = os.clock() + (tonumber(e.remaining) or 0)
		if not elevatorDeadline or math.abs(deadline - elevatorDeadline) > 1.2 then elevatorDeadline = deadline end
	else
		elevatorDeadline = nil
	end
	local signature = e and HttpService:JSONEncode({e.portalId, e.modeId, e.mapId or "random", #(e.riders or {}), e.host, e.carId, language}) or nil
	if signature == elevatorSignature and (refs.elevator ~= nil) == (e ~= nil) then return false end
	elevatorSignature = signature
	if refs.elevator then refs.elevator:Destroy(); refs.elevator, refs.elevatorCount = nil, nil end
	if refs.firstVisitHint then refs.firstVisitHint.Visible = e == nil and contextPanel == nil end
	if not e then return true end
	local size = screenSize()
	local hud = UI.lobbyLayout(size.X, size.Y)
	local compact, r = hud.class.compact, hud.elevator
	local tint = modeTint[e.portalId] or C.green
	local card = UI.roundFrame(main, {Name = "ElevatorCard", Position = at(r), Size = dims(r), BackgroundColor3 = C.background}, tint)
	refs.elevator = card
	-- The plan before anyone is committed: map, mode, length, final boss and
	-- what a win pays in lobby Gold.
	local title=mapName(e.mapId).." / "..modeName(e.modeId)
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
	UI.button(card, T("SAIR", "LEAVE"), function() act("ElevatorLeave", {}) end, {Position = UDim2.new(1, -(leaveW + 12), 0, rowY), Size = UDim2.fromOffset(leaveW, rowH), BackgroundColor3 = C.red, TextColor3 = C.text, TextSize = 13})
	local statusRight = leaveW + 28
	-- Whoever stepped on first may skip the rest of the countdown.
	if e.host then
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
	local pill = UI.frame(main, {Name = "LobbyPill", Position = at(hud.pill), Size = dims(hud.pill), BackgroundColor3 = C.ink, BackgroundTransparency = 0.4})
	UI.corner(pill, 22)
	UI.stroke(pill, C.ink, 2)
	UI.illustration(pill,"coin",C.gold,{Position=UDim2.fromOffset(2,2),Size=UDim2.fromOffset(40,40)})
	refs.gold = UI.label(pill, goldText(), {Name = "GoldAmount", Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -96, 1, -6), TextSize = compact and 19 or 25, Font = UI.Fonts.display, TextColor3 = C.gold})
	local star = UI.illustration(pill,"star",C.violet,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-2,0,0),Size=UDim2.fromOffset(44,44)})
	star.ZIndex = 2
	refs.commander = UI.label(pill, levelText(), {Position = UDim2.new(1, -46, 0, 0), Size = UDim2.new(0, 44, 1, -2), TextSize = compact and 11 or 13, Font = UI.Fonts.display, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3})
	local track = UI.frame(pill, {Position = UDim2.new(0, 46, 1, -9), Size = UDim2.new(1, -96, 0, 6), BackgroundColor3 = C.ink})
	UI.corner(track, 3)
	refs.levelBar = UI.frame(track, {Size = UDim2.fromScale(levelProgress(), 1), BackgroundColor3 = C.violet})
	UI.corner(refs.levelBar, 3)
	UI.button(pill, "", function() openContext("talents", {}) end, {Name = "OpenTalentTree", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1})
	UI.button(main, T("JOGAR", "PLAY"), function() openContext("modes", {}) end, {Name = "SquadButton", Position = at(hud.squad), Size = dims(hud.squad), BackgroundColor3=C.green,TextSize = compact and 16 or 20})
	UI.secondary(main, T("OPÇÕES", "SETTINGS"), function() openContext("settings", {}) end, {Name = "SettingsButton", Position = at(hud.settings), Size = dims(hud.settings), BackgroundColor3 = C.blue, TextSize = compact and 13 or 15})

	local dock=UI.frame(main,{Name="LobbyNavigation",Position=at(hud.navigation),Size=dims(hud.navigation),BackgroundTransparency=1})
	local nav={{"inventory",T("HERÓIS","HEROES"),C.coral,"hero"},{"talents",T("EVOLUÇÃO","TALENTS"),C.violet,"star"},{"chests",T("BAÚS","CHESTS"),C.gold,"chest"},{"premium","ROBUX",C.green,"shop"},{"rewards",T("PRÊMIOS","GIFTS"),C.pink,"gift"}}
	refs.navigation={}
	for i,entry in ipairs(nav) do
		-- Big floating icons, no box: a soft coloured glow, the illustration and
		-- an outlined label, the way the biggest Roblox games dress their dock.
		local button=UI.button(dock,entry[2],function() openContext(entry[1],{}) end,{Name="Nav_"..entry[1],Position=UDim2.new((i-1)/#nav,0,0,0),Size=UDim2.new(1/#nav,-5,1,0),BackgroundTransparency=1,TextTransparency=1})
		local artSize=hud.class.short and 34 or compact and 46 or 60
		local glow=UI.frame(button,{Name="IconGlow",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.new(0.5,0,0,artSize/2+2),Size=UDim2.fromOffset(artSize+8,artSize+8),BackgroundColor3=entry[3],BackgroundTransparency=0.72,Active=false})
		UI.corner(glow,(artSize+8)/2)
		UI.stroke(glow,entry[3],2).Transparency=0.35
		local navIcon=UI.illustration(button,entry[4],entry[3],{Name="NavIcon",Position=UDim2.new(0.5,-artSize/2,0,2),Size=UDim2.fromOffset(artSize,artSize)})
		UI.label(button,entry[2],{Position=UDim2.new(0,-4,1,-21),Size=UDim2.new(1,8,0,20),TextSize=compact and 13 or 15,Font=UI.Fonts.display,TextColor3=C.text,TextXAlignment=Enum.TextXAlignment.Center,TextTruncate=Enum.TextTruncate.None})
		if entry[1]=="chests" then
			local chestBadge=UI.roundFrame(button,{Name="ChestsBadge",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-4,0,4),Size=UDim2.fromOffset(18,18),BackgroundColor3=C.gold,Visible=canOpenChest(),ZIndex=5},C.background)
			UI.corner(chestBadge,9)
			UI.label(chestBadge,"!",{Size=UDim2.fromScale(1,1),TextSize=12,Font=Enum.Font.GothamBlack,TextColor3=C.background,TextXAlignment=Enum.TextXAlignment.Center})
			refs.chestsBadge=chestBadge
		end
		if entry[1]=="rewards" then
			local claimable=tonumber(profile().rewards and profile().rewards.claimable) or 0
			local badge=UI.roundFrame(button,{Name="RewardsBadge",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-4,0,4),Size=UDim2.fromOffset(18,18),BackgroundColor3=C.red,Visible=claimable>0,ZIndex=5},C.background)
			UI.corner(badge,9)
			UI.label(badge,tostring(math.min(claimable,9)),{Size=UDim2.fromScale(1,1),TextSize=11,Font=Enum.Font.GothamBlack,TextColor3=Color3.new(1,1,1)})
			refs.rewardsBadge=badge
		end
		local line=UI.frame(button,{Name="SelectedTab",Position=UDim2.new(0,8,1,-5),Size=UDim2.new(1,-16,0,3),BackgroundColor3=entry[3],Visible=false})
		local badge
		if entry[1]=="talents" then
			badge=UI.label(button,"",{Name="AvailableTalentPoints",Position=UDim2.new(1,-22,0,2),Size=UDim2.fromOffset(20,18),BackgroundTransparency=0,BackgroundColor3=C.gold,TextColor3=C.background,TextSize=10,Font=Enum.Font.GothamBold,TextXAlignment=Enum.TextXAlignment.Center})
			UI.corner(badge,7)
		end
		refs.navigation[entry[1]]={button=button,line=line,tint=entry[3],badge=badge,icon=navIcon,iconX=-artSize/2,phase=i*0.9}
	end

	-- Nico, the refuge's little robot, gives the next step in a speech strip.
	refs.firstVisitHint=UI.button(main,"",function() openContext("guide",{}) end,{
		Name="FirstVisitHint",Position=at(hud.hint),Size=dims(hud.hint),BackgroundColor3=C.ink,BackgroundTransparency=0.25,
	})
	do
		local hint=refs.firstVisitHint
		hint:FindFirstChild("Border").Color=C.gold
		UI.illustration(hint,"guide",C.gold,{Position=UDim2.fromOffset(4,-10),Size=UDim2.fromOffset(46,46)})
		local p=profile()
		local tip=not p.tutorialComplete and T("Entre no portal de CAMPANHA para jogar!","Step into a CAMPAIGN portal to play!")
			or (canOpenChest() and T("Você tem Ouro para um baú! Vá até a LOJA.","You have Gold for a chest! Visit the MARKET."))
			or T("Fale com o Nico: dicas, mapas e segredos do refúgio.","Talk to Nico: tips, maps and refuge secrets.")
		UI.label(hint,tip,{Name="GuideTip",Position=UDim2.fromOffset(54,0),Size=UDim2.new(1,-60,1,0),TextSize=compact and 12 or 14,Font=UI.Fonts.display,TextColor3=C.cream,TextWrapped=true,TextTruncate=Enum.TextTruncate.None})
	end
	refs.firstVisitHint.Visible=not state.elevator and contextPanel==nil
	refs.questTracker=nil
	if hud.tracker then
		local quests={}
		for _,quest in pairs(profile().quests or {}) do if not quest.claimed then table.insert(quests,quest) end end
		table.sort(quests,function(a,b)
			local ra,rb=(a.progress or 0)>=(a.target or 1),(b.progress or 0)>=(b.target or 1)
			if ra~=rb then return ra end
			return tostring(a.id)<tostring(b.id)
		end)
		if #quests>0 then
			local r=hud.tracker
			local tracker=UI.button(main,"",function() openContext("quests",{hud=true}) end,{Name="QuestTracker",Position=at(r),Size=dims(r),BackgroundTransparency=1})
			refs.questTracker=tracker
			UI.label(tracker,T("MISSÕES","QUESTS"),{Position=UDim2.fromOffset(0,0),Size=UDim2.new(1,-4,0,26),TextSize=20,Font=UI.Fonts.display,TextColor3=C.gold,TextXAlignment=Enum.TextXAlignment.Right})
			for index=1,math.min(3,#quests) do
				local quest=quests[index]
				local ready=(quest.progress or 0)>=(quest.target or 1)
				local row=UI.frame(tracker,{Name="QuestRow_"..index,Position=UDim2.fromOffset(0,28+(index-1)*56),Size=UDim2.new(1,0,0,52),BackgroundColor3=C.ink,BackgroundTransparency=0.35})
				UI.corner(row,10)
				local fade=UI.create("UIGradient",{Transparency=NumberSequence.new(0.6,0),Rotation=0},row)
				UI.label(row,L(quest.name),{Position=UDim2.fromOffset(8,2),Size=UDim2.new(1,-14,0,20),TextSize=13,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Right})
				UI.label(row,ready and T("PRONTO! RESGATE","READY! CLAIM") or (number(quest.progress or 0).." / "..number(quest.target or 1)),{Position=UDim2.fromOffset(8,20),Size=UDim2.new(1,-14,0,22),TextSize=ready and 15 or 18,Font=UI.Fonts.display,TextColor3=ready and C.green or C.gold,TextXAlignment=Enum.TextXAlignment.Right})
				local bar=UI.bar(row,ready and C.green or C.gold,UDim2.new(0,8,1,-9),UDim2.new(0.55,0,0,6))
				bar.Size=UDim2.fromScale(math.clamp((quest.progress or 0)/math.max(1,quest.target or 1),0,1),1)
			end
		end
	end

	elevatorSignature = nil
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
local placementReason = nil
local function positionValid(position)
	if not state or not state.match or not selectedHero then return false, "bounds" end
	local match = state.match
	local towers, mine = {}, 0
	for _, tower in ipairs(match.towers or {}) do
		if typeof(tower.position) == "Vector3" then table.insert(towers, tower.position) end
		if tower.ownerId == player.UserId then mine += 1 end
	end
	local ok, reason = Rules.BuildCheck(match.mapId, position, towers, Config, match.blockers)
	if not ok then return false, reason end
	if mine >= (match.towerLimit or 16) then return false, "limit" end
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
	if selectedHero then placementValid, placementReason = positionValid(selectedPosition) else placementValid, placementReason = true, nil end
	local tint = placementValid and C.green or C.red
	placementRing = rangeRing(placementRing, selectedPosition, radius, tint)
	if selectedHero then
		if not ghost then
			ghost = UI.heroModel(effects.folder, selectedHero, heroSource(selectedHero))
			ghost.Name = "HeroPlacementPreview"
			local bounds, size = ghost:GetBoundingBox()
			ghostLift = size.Y * 0.5 - bounds.Position.Y + 0.15
			ghostParts = {}
			for _, part in ipairs(ghost:GetChildren()) do
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
		local reason = placementReason and Rules.BuildReasons[placementReason]
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
	local wanted = (state.match.speedVote or 1) == 2 and 1 or 2
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
		act("PlaceTower", {heroId = hero, position = position}, function() audio:Cue("place", 0.05); clearPlacement() end)
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
local priorityNames = {First = {pt = "Primeiro", en = "First"}, Last = {pt = "Último", en = "Last"}, Strongest = {pt = "Mais forte", en = "Strongest"}, Nearest = {pt = "Mais próximo", en = "Nearest"}}
local priorityOrder = {"First", "Last", "Strongest", "Nearest"}

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
	local levelText = T("Nível ", "Level ") .. tostring(tower.level) .. "/5" .. (tower.branch and "  •  " .. L(def.branches[tower.branch].name) or "")
	UI.secondary(panel, "×", closeTowerPanel, {Name="CloseTower",Position = UDim2.fromOffset(w - 46, 4), Size = UDim2.fromOffset(40, 40), TextSize = 24})
	local actionY, actionH, rowY, rowH
	if wide then
		local nameW = math.floor((w - 66) * 0.5)
		UI.label(panel, heroName(tower.heroId), {Position = UDim2.fromOffset(12, 6), Size = UDim2.fromOffset(nameW, 22), TextSize = 15, Font = Enum.Font.GothamBold, TextColor3 = colorFor(tower.heroId)})
		UI.label(panel, levelText, {Position = UDim2.fromOffset(12 + nameW + 6, 8), Size = UDim2.fromOffset(w - 66 - nameW - 6, 18), TextSize = 11, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Right})
		refs.towerStats = UI.label(panel, "", {Position = UDim2.fromOffset(12, 30), Size = UDim2.fromOffset(w - 64, 18), TextSize = 10, TextColor3 = C.muted})
		actionY, actionH, rowY, rowH = 52, 36, 92, 34
	else
		UI.label(panel, heroName(tower.heroId), {Position = UDim2.fromOffset(12, 8), Size = UDim2.fromOffset(w - 54, 24), TextSize = 17, Font = Enum.Font.GothamBold, TextColor3 = colorFor(tower.heroId)})
		UI.label(panel, levelText, {Position = UDim2.fromOffset(12, 34), Size = UDim2.fromOffset(w - 24, 18), TextSize = 12, TextColor3 = C.muted})
		refs.towerStats = UI.label(panel, "", {Position = UDim2.fromOffset(12, 54), Size = UDim2.fromOffset(w - 24, 32), TextSize = 12, TextColor3 = C.muted, TextWrapped = true, TextTruncate = Enum.TextTruncate.None})
		actionY, actionH, rowY, rowH = 88, 40, 178, 40
	end
	local function note(text)
		UI.label(panel, text, {Position = UDim2.fromOffset(12, actionY), Size = UDim2.fromOffset(w - 24, (own and rowY - 6 or slot.h - 6) - actionY), TextSize = 11, TextColor3 = C.muted, TextWrapped = true, TextTruncate = Enum.TextTruncate.None, TextYAlignment = Enum.TextYAlignment.Top})
	end
	if not own then
		note(T("Torre de um aliado. Somente o dono pode modificá-la.", "Ally tower. Only its owner can modify it."))
		return
	end
	if tower.level < 4 then
		UI.button(panel, T("MELHORAR  •  ", "UPGRADE  •  ") .. "🪙 " .. number(tower.upgradeCost), function() act("UpgradeTower", {towerId = tower.id}) end, {Position = UDim2.fromOffset(12, actionY), Size = UDim2.fromOffset(w - 24, actionH), TextSize = 13})
	elseif tower.level == 4 then
		for branch = 1, 2 do
			local label = L(def.branches[branch].name) .. " • 🪙 " .. number(tower.upgradeCost)
			local position = wide and UDim2.fromOffset(12 + (branch - 1) * (half + 6), actionY) or UDim2.fromOffset(12, actionY + (branch - 1) * 42)
			local size = wide and UDim2.fromOffset(half, actionH) or UDim2.fromOffset(w - 24, 40)
			UI.button(panel, label, function() act("UpgradeTower", {towerId = tower.id, branch = branch}) end, {Position = position, Size = size, TextSize = wide and 10 or 11, BackgroundColor3 = branch == 1 and C.green or C.blue})
		end
	else
		note(L(def.branches[tower.branch or 1].description))
	end
	UI.secondary(panel, T("Alvo: ", "Target: ") .. L(priorityNames[tower.priority] or tower.priority), function()
		local index = table.find(priorityOrder, tower.priority) or 1
		act("SetPriority", {towerId = tower.id, priority = priorityOrder[index % #priorityOrder + 1]})
	end, {Position = UDim2.fromOffset(12, rowY), Size = UDim2.fromOffset(half, rowH), TextSize = 11})
	UI.secondary(panel, T("Vender • ", "Sell • ") .. "🪙 " .. number(math.floor((tower.invested or 0) * 0.7)), function()
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
				local gui = Instance.new("BillboardGui")
				gui.Name, gui.Size, gui.AlwaysOnTop, gui.Active = "Upgrade_" .. id, UDim2.fromOffset(128, 34), true, true
				gui.StudsOffset, gui.MaxDistance, gui.ResetOnSpawn = Vector3.new(0, 9, 0), 200, false
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
			board.button.Text = (nextLevel == 5 and ("★ " .. T("EVOLUIR", "EVOLVE")) or ("⬆ " .. T("NV", "LV") .. tostring(nextLevel))) .. "  🪙" .. number(cost)
			board.button.BackgroundColor3 = affordable and C.green or C.card
			board.button.TextColor3 = affordable and C.background or C.muted
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
	UI.label(art,L(def.name).."\n"..T("NÍVEL ","LEVEL ")..base.level.." / 5",{Position=UDim2.fromOffset(114,4),Size=UDim2.new(1,-124,1,-8),TextSize=18,Font=Enum.Font.GothamBlack,TextWrapped=true,ZIndex=48})
	local function line(text,color,height) UI.label(body,text,{Size=UDim2.new(1,-8,0,height or 28),TextSize=13,TextWrapped=true,TextColor3=color or C.text,ZIndex=48}) end
	line(L(def.description),C.muted,46)
	line(T("RENDA POR ONDA: ","INCOME PER WAVE: ")..stats.income.." → "..nextStats.income..T(" Ouro"," Gold"),C.gold)
	line(T("VIDA EXTRA DO NÚCLEO: ","EXTRA CORE HP: ")..math.floor(stats.hp/(state.match.partySize or 1)).." → "..math.floor(nextStats.hp/(state.match.partySize or 1)),C.green)
	if stats.damage>0 then line(T("DANO: ","DAMAGE: ")..stats.damage.." → "..nextStats.damage..T(" • ALCANCE: "," • RANGE: ")..stats.range.." → "..nextStats.range,C.coral) end
	if stats.wall>0 then line(T("BARRICADA: ","BARRICADE: ")..(base.wall or 0).."/"..stats.wall.." → "..nextStats.wall..T(" HP • regenera após 5 s"," HP • regenerates after 5 s"),C.blue,40) end
	if stats.soldier>0 then line(T("SOLDADO: ","SOLDIER: ")..stats.soldier.." → "..nextStats.soldier..T(" HP • a cada "," HP • every ")..stats.interval.." s",C.violet,40) end
	local button=UI.button(body,base.level>=5 and T("NÍVEL MÁXIMO","MAXIMUM LEVEL") or T("EVOLUIR • ","UPGRADE • ").."🪙 "..stats.upgradeCost,function()
		act("UpgradeBase",{expectedLevel=base.level},function() audio:Cue("upgrade"); shade:Destroy() end)
	end,{Name="ConfirmBaseUpgrade",Size=UDim2.new(1,-8,0,48),TextSize=14,BackgroundColor3=C.green,ZIndex=48})
	if base.level>=5 or (state.match.cash or 0)<stats.upgradeCost then UI.disabled(button) end
	refs.refreshBaseModal=function()
		if not shade.Parent then refs.refreshBaseModal=nil; return end
		local current=state.match
		if not current or not current.base or current.base.level~=base.level then shade:Destroy(); refs.refreshBaseModal=nil; return end
		local missing=math.max(0,stats.upgradeCost-(current.cash or 0))
		if base.level>=5 then return end
		button.Text=missing>0 and T("FALTAM ","NEED ").."🪙 "..number(missing) or T("EVOLUIR • ","UPGRADE • ").."🪙 "..stats.upgradeCost
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
	local top = UI.roundFrame(main, {Position = at(topRect), Size = dims(topRect), BackgroundColor3 = C.ink, BackgroundTransparency = 0.2})
	UI.frame(top, {Position = UDim2.fromOffset(0, 12), Size = UDim2.new(0, 3, 1, -24), BackgroundColor3 = C.green})
	refs.wave = UI.label(top, "", {Position = at(layout.wave, topRect), Size = dims(layout.wave), TextSize = class.short and 18 or (compact and 20 or 26), Font = UI.Fonts.display, TextColor3 = C.green})
	refs.map = UI.label(top, "", {Position = at(layout.map, topRect), Size = dims(layout.map), TextWrapped=class.narrow, TextSize = compact and 10 or 12, TextColor3 = C.muted})
	refs.hpText = UI.button(top, "", openBaseUpgrade, {Name="OpenBaseUpgrade",Position = at(layout.hpText, topRect), Size = UDim2.fromOffset(layout.hpText.w,math.max(44,layout.hpText.h)),BackgroundTransparency=1,TextColor3=C.text,TextXAlignment = Enum.TextXAlignment.Right,TextYAlignment=Enum.TextYAlignment.Top, TextSize = compact and 14 or 18, Font = UI.Fonts.display})
	UI.outline(refs.hpText, 2)
	refs.hp = UI.bar(top, C.green, at(layout.hpBar, topRect), dims(layout.hpBar))
	refs.matchGold = UI.label(main, "", {Position = at(layout.gold), Size = dims(layout.gold), TextSize = compact and 16 or 20, TextColor3 = C.gold, Font = UI.Fonts.display, TextXAlignment = class.narrow and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right})
	refs.energy = UI.label(main, "", {Position = at(layout.energy), Size = dims(layout.energy), TextColor3 = C.blue, Font = UI.Fonts.display, TextSize = compact and 16 or 21, TextXAlignment = class.narrow and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left})
	surface(refs.matchGold,C.gold:Lerp(C.stroke,0.5))
	surface(refs.energy,C.blue:Lerp(C.stroke,0.5))
	refs.matchGold.BackgroundColor3,refs.matchGold.TextColor3,refs.matchGold.BackgroundTransparency=C.ink,C.gold,0.2
	refs.energy.BackgroundColor3,refs.energy.TextColor3,refs.energy.BackgroundTransparency=C.ink,C.blue,0.2
	refs.energy.TextXAlignment=Enum.TextXAlignment.Center
	refs.matchGold.TextXAlignment=Enum.TextXAlignment.Center
	refs.waveInfo = UI.label(main, "", {Position = at(layout.waveInfo), Size = dims(layout.waveInfo), TextWrapped = true, TextTruncate = Enum.TextTruncate.AtEnd, TextSize = compact and 13 or 15, Font = UI.Fonts.display, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Center})
	surface(refs.waveInfo,C.stroke)
	refs.skip = UI.button(main, T("PRONTO", "READY"), function() act("SkipWave", {}) end, {Position = at(layout.skip), Size = dims(layout.skip), BackgroundColor3 = C.green, TextSize = 18})
	-- Competitive only: everyone agreeing between waves ends the run and keeps the record.
	refs.endVote = UI.button(main, T("ENCERRAR PARTIDA", "END RUN"), function()
		act("VoteEnd", {on = not (state.match and state.match.endVote)})
	end, {Name = "VoteEndRun", Position = UDim2.fromOffset(layout.skip.x, layout.skip.y + layout.skip.h + 6), Size = UDim2.fromOffset(layout.skip.w, 40), BackgroundColor3 = C.red, TextSize = 14, Visible = false})
	local bossRect = layout.boss
	refs.boss = UI.roundFrame(main, {Position = at(bossRect), Size = dims(bossRect), BackgroundColor3 = Color3.fromRGB(66,30,44), Visible = false}, C.red)
	refs.bossName = UI.label(refs.boss, "", {Position = UDim2.fromOffset(12, 3), Size = UDim2.new(1, -24, 0, 22), TextColor3 = C.red, Font = UI.Fonts.display, TextSize = 18, TextXAlignment = Enum.TextXAlignment.Center})
	refs.bossHP = UI.bar(refs.boss, C.red, UDim2.fromOffset(12, 27), UDim2.new(1, -24, 0, 7))
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
		local button = UI.secondary(abilities, "", function() chooseSkill(id) end, {Name="LeaderPower",LayoutOrder = index, Size = UDim2.fromOffset(layout.skillW, layout.buttonH), TextSize = 11, TextTruncate = Enum.TextTruncate.AtEnd})
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
			local button, price, line = heroCard(cards, id, index, layout.cardW, layout.heroCards.h - 14, function() chooseHero(id) end)
			refs.heroCards[id] = {button = button, price = price, line = line}
		else
			local empty = UI.roundFrame(cards, {Name = "EmptyHeroSlot", LayoutOrder = index, Size = UDim2.fromOffset(layout.cardW, layout.heroCards.h - 14), BackgroundColor3 = C.background, BackgroundTransparency = 0.25})
			UI.label(empty, "+", {Position = UDim2.fromOffset(8, 0), Size = UDim2.new(0, 24, 1, 0), TextSize = 25, TextColor3 = C.stroke, TextXAlignment = Enum.TextXAlignment.Center})
			UI.label(empty, T("ESPAÇO ", "SLOT ") .. index .. "\n" .. T("Equipe no lobby", "Equip in lobby"), {Position = UDim2.fromOffset(38, 0), Size = UDim2.new(1, -44, 1, 0), TextSize = compact and 10 or 11, TextColor3 = C.muted, TextWrapped = true})
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
	refs.hpText.Text = T("BASE ", "CORE ") .. tostring(math.ceil(match.baseHP or 0)) .. "/" .. tostring(match.maxBaseHP or 100) .. ((match.shield or 0) > 0 and "  +" .. math.ceil(match.shield) or "") .. T("\n↑ EVOLUIR", "\n↑ UPGRADE")
	refs.hp.Size = UDim2.fromScale(math.clamp((match.baseHP or 0) / (match.maxBaseHP or 100), 0, 1), 1)
	refs.hp.BackgroundColor3 = (match.baseHP or 0)/math.max(1,match.maxBaseHP or 100) > 0.3 and C.green or C.red
	-- Lobby Gold this run has banked so far: a reward, not money to spend.
	refs.matchGold.Text = "🏆 +" .. number(match.goldEarned) .. T(" PRÊMIO", " REWARD")
	local towerCount = 0
	for _, tower in ipairs(match.towers or {}) do if tower.ownerId == player.UserId then towerCount += 1 end end
	-- Match Gold in hand, plus what is still lying on the ground to collect.
	local waiting = match.coinsWaiting or 0
	refs.energy.Text = "🪙 " .. number(match.cash) .. (waiting > 0 and ("  +" .. number(waiting) .. T(" no chão", " on ground")) or "")
	refs.energy.TextSize=mobile() and 12 or 16
	if refs.speedToggle then
		local fast, voted = (match.speed or 1) == 2, (match.speedVote or 1) == 2
		local party = match.partySize or 1
		-- In a group, 2x starts only when everyone asked; show who is waiting.
		refs.speedToggle.Text = fast and "▶▶ 2x" or (voted and party > 1 and ("2x " .. tostring(match.speedVotes or 1) .. "/" .. tostring(party)) or "▶ 1x")
		refs.speedToggle.BackgroundColor3 = fast and C.gold or (voted and C.gold:Lerp(C.card, 0.6) or C.card)
		refs.speedToggle.TextColor3 = fast and C.background or C.text
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
	refs.waveInfo.Text = state.phase == "Preparing" and (T("PRÓXIMA HORDA", "NEXT HORDE") .. (#threatNames > 0 and "  •  " .. table.concat(threatNames, " / ") or T("  •  Prepare suas defesas e colete Ouro.", "  •  Prepare your defenses and collect Gold."))) or (T("INIMIGOS: ", "ENEMIES: ") .. tostring(match.enemies or 0)..T("  •  HERÓIS: ","  •  HEROES: ")..towerCount.."/"..tostring(match.towerLimit or 16))
	local boss = match.boss
	refs.boss.Visible = boss ~= nil
	if boss then
		refs.bossName.Text = (boss.final and T("CHEFE FINAL • ","FINAL BOSS • ") or "")..L(boss.name)
		refs.bossName.TextSize=mobile() and 12 or 14
		refs.bossHP.Size = UDim2.fromScale(math.clamp((boss.hp or 0) / math.max(boss.maxHP or 1, 1), 0, 1), 1)
		refs.bossHint.Text = L(boss.hint)
	end
	for id, record in pairs(refs.abilityButtons or {}) do
		local remaining = match.ability and match.ability.cooldown or 0
		local shortcut = UserInputService.TouchEnabled and "" or "Q  "
		local label = (record.ultimate and "⚡ " or "")..record.name
		record.button.Text = shortcut..label.."\n"..(remaining>0 and (T("Recarrega em ","Ready in ")..math.ceil(remaining).."s") or state.phase=="Preparing" and T("Na próxima onda","Next wave") or T("PRONTO!","READY!"))
		record.button.TextColor3 = remaining > 0 and C.muted or record.tint
		record.button.BackgroundColor3=remaining>0 and C.card or record.tint:Lerp(C.panel,0.8)
		record.meter.Size = UDim2.fromScale(1 - math.clamp(remaining / math.max(match.ability and match.ability.cooldownTotal or 1, 1), 0, 1), 1)
	end
	for id, card in pairs(refs.heroCards or {}) do
		local selected = selectedHero == id
		card.button.BackgroundColor3 = selected and colorFor(id):Lerp(C.background, 0.7) or C.card
		card.line.BackgroundTransparency = selected and 0 or 0.65
		card.price.TextColor3 = (match.cash or 0) >= Catalog.Heroes[id].cost and C.gold or C.red
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
			if refs.towerStats then
				-- The wide panel has a single line for stats; the tall one has two.
				refs.towerStats.Text = T("Dano ", "Damage ") .. number(tower.damage) .. "  •  " .. string.format("%.1f", tower.rate or 0) .. T("/s", "/s")
					.. (refs.towerWide and "  •  " or "\n") .. T("Alcance ", "Range ") .. string.format("%.1f", tower.range or 0)
			end
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
	UI.button(panel,T("VOLTAR À BASE","RETURN TO BASE"),function() act("ReturnLobby",{}) end,{Name="ResultReturn",Position=UDim2.new(0,18,1,-64),Size=UDim2.new(1,-36,0,48),TextSize=15})
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
	if not retained then contextPanel = nil end
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
	-- Roblox's normal camera retains orbit, wheel zoom and touch pinch control.
	player.CameraMinZoomDistance = inBattle and 14 or 7
	player.CameraMaxZoomDistance = inBattle and 100 or 55
	task.delay(0.5, function()
		if inBattle ~= not not activeMatch() then return end
		local camera = workspace.CurrentCamera
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not camera or not root then return end
		local focus = root.Position + Vector3.new(0, 2, 0)
		camera.FieldOfView = inBattle and 60 or 70
		camera.CFrame = CFrame.lookAt(focus + (inBattle and Vector3.new(0, 30, 29) or Vector3.new(0, 6, 23)), focus)
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
		if refs.chestsBadge then refs.chestsBadge.Visible=canOpenChest() end
		if refs.rewardsBadge then
			local claimable=tonumber(profile().rewards and profile().rewards.claimable) or 0
			refs.rewardsBadge.Visible=claimable>0
			local badgeLabel=refs.rewardsBadge:FindFirstChildOfClass("TextLabel")
			if badgeLabel then badgeLabel.Text=tostring(math.min(claimable,9)) end
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

stateRemote.OnClientEvent:Connect(applyState)
fxRemote.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" then return end
	if event.kind == "Notice" then
		showToast(event.text, event.tone == "boss")
		if event.tone == "boss" then audio:Cue("boss", 4) end
	elseif event.kind == "WaveCash" then
		-- The wave bonus lands straight in the wallet: show it next to the Gold.
		if refs.energy and refs.energy.Parent and tonumber(event.amount) then
			celebrate:Float("+" .. number(event.amount) .. " 🪙", refs.energy, C.gold)
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
			celebrate:Banner(def and def.name or {pt = "CHEFE", en = "BOSS"}, event.final and {pt = "⚠ CHEFE FINAL", en = "⚠ FINAL BOSS"} or {pt = "⚠ CHEFE", en = "⚠ BOSS"}, C.red, {big = event.final == true, cue = "boss", duration = 2.2})
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
local afkBanner, afkTitle, afkDetail, afkBannerAt = nil, nil, nil, 0
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
		if afkBanner then afkBanner.Visible = false end
		if afk.eco then setAfkEco(false) end
		return
	end
	if not afkBanner then
		afkBanner = UI.roundFrame(overlays, {Name = "AfkBanner", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 58), Size = UDim2.fromOffset(math.min(460, screenSize().X - 24), 58), BackgroundColor3 = C.background}, C.gold)
		afkTitle = UI.label(afkBanner, "", {Name = "AfkTitle", Position = UDim2.fromOffset(12, 4), Size = UDim2.new(1, -24, 0, 28), TextSize = 18, Font = Enum.Font.GothamBlack, TextXAlignment = Enum.TextXAlignment.Center})
		-- The dedicated AFK place, when the game has one configured.
		afk.travel = UI.button(afkBanner, T("SERVIDOR AFK", "AFK SERVER"), function() act("EnterAfkServer", {}) end, {Name = "AfkServerGo", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -104, 0.5, 0), Size = UDim2.fromOffset(120, 44), BackgroundColor3 = C.violet, TextSize = 12, Visible = false})
		UI.button(afkBanner, T("ECONOMIA", "SAVER"), function() setAfkEco(true) end, {Name = "AfkEcoOn", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -6, 0.5, 0), Size = UDim2.fromOffset(92, 44), BackgroundColor3 = C.blue, TextSize = 13})
		afkDetail = UI.label(afkBanner, "", {Name = "AfkDetail", Position = UDim2.fromOffset(12, 30), Size = UDim2.new(1, -24, 0, 22), TextSize = 13, Font = Enum.Font.GothamBold, TextColor3 = C.muted, TextXAlignment = Enum.TextXAlignment.Center})
	end
	local tint = UI.color(farm.color)
	afkBanner.Visible = true
	afkTitle.Text = "💤 " .. Catalog.Upper(L(farm.name))
	afkTitle.TextColor3 = tint
	-- Session clock, what has really been paid, and whether the last minute is
	-- still being saved: the server sets all of it, the banner only reads it.
	local session = math.floor(tonumber(player:GetAttribute("AfkSession")) or 0)
	local earned = tonumber(player:GetAttribute("AfkEarned")) or 0
	local saving = player:GetAttribute("AfkSaving") == true
	afkDetail.Text = L(farm.rate) .. "  •  " .. T("próximo em ", "next in ") .. tostring(player:GetAttribute("AfkNext") or 60) .. "s"
		.. "  •  " .. string.format("%d:%02d", math.floor(session / 60), session % 60)
		.. "  •  +" .. number(earned) .. (kind == "gold" and " 🪙" or " XP")
		.. "  " .. (saving and T("salvando…", "saving…") or "✓")
	if afk.travel then afk.travel.Visible = player:GetAttribute("AfkTravel") == true end
	-- On the AFK place the saving screen comes on by itself, once.
	if player:GetAttribute("AfkServer") and not afk.autoEco then afk.autoEco = true; setAfkEco(true) end
	if afk.text then
		afk.text.Text = L(farm.name) .. "\n" .. T("Sessão ", "Session ") .. string.format("%d:%02d", math.floor(session / 60), session % 60)
			.. "\n" .. T("Próximo pagamento em ", "Next payment in ") .. tostring(player:GetAttribute("AfkNext") or 60) .. "s"
			.. "\n" .. T("Recebido: +", "Received: +") .. number(earned) .. (kind == "gold" and " 🪙" or " XP") .. "  " .. (saving and T("(salvando…)", "(saving…)") or T("✓ salvo", "✓ saved"))
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

local nameplateAt, anchorCheckAt = 0, 0
RunService.RenderStepped:Connect(function(dt)
	if os.clock() >= afkBannerAt then
		afkBannerAt = os.clock() + 0.25
		updateAfkBanner()
	end
	routePreview:Step(dt or 1 / 60, state and state.phase)
	-- The dock breathes, and anything waiting for the player wiggles.
	if not (profile().settings and profile().settings.lowFX) then
		local now = os.clock()
		for _, entry in pairs(refs.navigation or {}) do
			if entry.icon and entry.icon.Parent then
				entry.icon.Position = UDim2.new(0.5, entry.iconX, 0, 2 + math.sin(now * 2.2 + entry.phase) * 2.5)
			end
		end
		for _, badge in ipairs({refs.chestsBadge, refs.rewardsBadge}) do
			if badge and badge.Parent and badge.Visible then badge.Rotation = math.sin(now * 7) * 14 end
		end
	end
	if contextRefreshPending and not UserInputService:GetFocusedTextBox() then renderContext() end
	animateLobby(dt or 1 / 60)
	celebrate:Step(dt or 1 / 60)
	if refs.elevatorCount then
		local count = elevatorCountText()
		if refs.elevatorCount.Text ~= count then refs.elevatorCount.Text = count end
	end
	if os.clock() >= nameplateAt then
		nameplateAt = os.clock() + 0.7
		nameplates:Refresh()
	end
	-- A contextual panel belongs to the place that opened it: walk away from
	-- the pedestal and the panel closes, the way the physical lobby implies.
	if contextPanel and contextPanel.anchor and os.clock() >= anchorCheckAt then
		anchorCheckAt = os.clock() + 0.25
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
local resizeQueued = false
local function queueRelayout()
	if resizeQueued then return end
	resizeQueued = true
	task.delay(0.2, function()
		resizeQueued = false
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
