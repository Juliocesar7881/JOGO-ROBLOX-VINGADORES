-- The Robux shop and the starter pack: only products with a real ID are drawn,
-- a price that arrives later updates its own button (kit.refreshQuoteButtons),
-- and the Heroes / Offers / Gold / Passes tabs. Split out of Panels.luau for
-- the script size limit; built with the same `ctx` plus the Panels helpers it
-- borrows. Purely presentation: the server checks and grants every purchase.
local Shop = {}

function Shop.new(ctx, helpers)
	local C, Catalog, Config, L, MarketplaceService, Rules, T, UI = ctx.C, ctx.Catalog, ctx.Config, ctx.L, ctx.MarketplaceService, ctx.Rules, ctx.T, ctx.UI
	local fetchProducts, heroPortrait, kit, openContext, player, productInfo = ctx.fetchProducts, ctx.heroPortrait, ctx.kit, ctx.openContext, ctx.player, ctx.productInfo
	local profile, renderContext, screenSize, showToast = ctx.profile, ctx.renderContext, ctx.screenSize, ctx.showToast
	local categoryTabs, heroTooltip, heroPicksLeft = helpers.categoryTabs, helpers.heroTooltip, helpers.heroPicksLeft
	-- The tab the Robux shop shows (a shortcut may name another one).
	local premiumCategory = "hero"
	-- Only products with a real ID in Config are drawn: nothing on sale that
	-- cannot be bought. (The server still refuses an unconfigured product.)
	local function configured(kind,key)
		local group=Config.Products and Config.Products[kind=="hero" and "Heroes" or kind=="pass" and "Passes" or "Consumables"]
		local entry=group and group[key]
		return entry~=nil and (tonumber(entry.id) or 0)>0
	end
	kit.productConfigured=configured

	-- A product's buy button from its quote: the price, loading, try again or
	-- unavailable. Shared by the first draw and by kit.refreshQuoteButtons, so a
	-- quote that arrives later updates its button in place: redrawing the whole
	-- window for every price that came in made the shop flicker and stutter.
	local function quoteLabel(info, owned)
		if owned then return T("✓ Já é seu","✓ Yours") end
		if type(info)=="table" then return tostring(info.price).." Robux"..(info.preview and T(" • Teste"," • Preview") or "") end
		return info=="retry" and T("Tentar de novo","Try again") or info==nil and T("Carregando preço…","Loading price…") or T("Indisponível","Unavailable")
	end
	local function quoteUsable(info, owned) return not owned and (info=="retry" or type(info)=="table" and not info.preview) end
	kit.refreshQuoteButtons=function(root)
		for _,item in ipairs(root and root:GetDescendants() or {}) do
			local cacheKey=item:IsA("TextButton") and string.match(item.Name,"^Buy_(.+)$")
			if cacheKey then
				local owned=item:GetAttribute("Owned")==true
				local info=productInfo[cacheKey]
				local text=quoteLabel(info,owned)
				if item.Text~=text then item.Text=text end
				if quoteUsable(info,owned) then
					if not item.Active then item.Active,item.AutoButtonColor,item.BackgroundColor3,item.TextColor3=true,true,C.green,UI.Colors.text end
				elseif item.Active then UI.disabled(item) end
			end
		end
	end

	-- The starter pack, featured above every tab until the account owns it.
	local function starterOffer(body)
		local pack=Catalog.Products.Consumables.starterPack
		if not pack or profile().starterPack or not configured("product","starterPack") then return end
		local info=productInfo["product:starterPack"]
		-- The pack stays for sale, so the banner never shows a countdown (Roblox:
		-- no timer that is not accurate). What is true: once per account.
		local urgency=T("Boas-vindas  •  só uma vez por conta","Welcome  •  once per account")
		local label=quoteLabel(info,false)
		local function purchase()
			-- The quote as it is now: it may have arrived after the banner was drawn.
			local current=productInfo["product:starterPack"]
			if current=="retry" then productInfo["product:starterPack"]=nil; fetchProducts(premiumCategory); renderContext(); return end
			if type(current)~="table" or current.preview then return end
			local ok=pcall(function() MarketplaceService:PromptProductPurchase(player,current.id) end)
			if not ok then showToast(T("Falha ao abrir compra.","Could not open purchase."),true) end
		end
		-- On a short phone screen the banner is one slim row, so the gold and
		-- the first products stay in view under it.
		if UI.sizeClass(screenSize().X,screenSize().Y).short then
			local slim=UI.roundFrame(body,{Name="StarterPack",Size=UDim2.new(1,-6,0,72),BackgroundColor3=C.gold:Lerp(C.panel,0.45)},C.gold)
			UI.candy(slim)
			UI.fit(UI.label(slim,Catalog.Upper(L(pack.name)).."  •  "..urgency,{Name="StarterUrgency",Position=UDim2.fromOffset(12,6),Size=UDim2.new(1,-170,0,24),Font=UI.Fonts.display,TextSize=16,TextColor3=C.gold}),10)
			UI.label(slim,L(Catalog.Heroes[pack.heroId].name).." + "..UI.format(pack.gold)..T(" Ouro"," Gold"),{Position=UDim2.fromOffset(12,32),Size=UDim2.new(1,-170,0,34),TextWrapped=true,TextSize=13})
			local fast=UI.button(slim,label,purchase,{Name="Buy_product:starterPack",Position=UDim2.new(1,-150,0,14),Size=UDim2.fromOffset(138,44),BackgroundColor3=C.green,TextSize=16})
			if not quoteUsable(info,false) then UI.disabled(fast) end
			return
		end
		local row=UI.roundFrame(body,{Name="StarterPack",Size=UDim2.new(1,-6,0,132),BackgroundColor3=C.gold:Lerp(C.panel,0.45)},C.gold)
		UI.candy(row)
		heroPortrait(row,pack.heroId,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(104,116)})
		local chip=UI.chip(row,urgency,C.green,{Name="StarterUrgency",Position=UDim2.fromOffset(120,10),Size=UDim2.fromOffset(260,24),TextSize=13})
		UI.fit(chip,9)
		UI.label(row,Catalog.Upper(L(pack.name)),{Position=UDim2.fromOffset(120,34),Size=UDim2.new(1,-130,0,28),Font=UI.Fonts.display,TextSize=22,TextColor3=C.gold})
		UI.oneLine(UI.label(row,L(Catalog.Heroes[pack.heroId].name).." + "..UI.format(pack.gold)..T(" Ouro"," Gold"),{Position=UDim2.fromOffset(120,60),Size=UDim2.new(1,-130,0,22),Font=UI.Fonts.display,TextSize=16}),10)
		local buy=UI.button(row,label,purchase,{Name="Buy_product:starterPack",Position=UDim2.new(0,120,1,-46),Size=UDim2.new(1,-132,0,40),BackgroundColor3=C.green,TextSize=17})
		if not quoteUsable(info,false) then UI.disabled(buy) end
	end

	-- A Gold pack sells Gold and nothing else; every other consumable (bundles,
	-- the season pass, the Gold boost) is an offer with a tab of its own.
	local function goldPack(def) return def.gold~=nil and def.heroPicks==nil and def.boostSeconds==nil and def.seasonPass==nil end
	local function contextPremium(body,data)
	 -- A shortcut names the tab it wants (shopKind) and, for a hero, which one (shopKey).
	 local focus
	 if type(data)=="table" then
		if data.shopKind then premiumCategory=data.shopKind; data.shopKind=nil end
		focus=data.shopKey; data.shopKey=nil
	 end
	 starterOffer(body)
	 -- Heroes bought but not yet chosen: the way to them stays on top of the shop.
	 local picksLeft=heroPicksLeft()
	 if picksLeft>0 then UI.button(body,picksLeft==1 and T("Você tem 1 herói para escolher","You have 1 hero to choose") or T("Você tem "..picksLeft.." heróis para escolher","You have "..picksLeft.." heroes to choose"),function() openContext("pick",{}) end,{Name="PickHeroes",Size=UDim2.new(1,-6,0,48),BackgroundColor3=C.green,TextSize=18}) end
	 categoryTabs(body,"PremiumTabs",{{id="hero",label=T("Heróis","Heroes"),icon="hero",color=C.coral},{id="offer",label=T("Ofertas","Offers"),icon="star",color=C.green},{id="pass",label=T("Vantagens","Perks"),icon="star",color=C.blue},{id="product",label=T("Ouro","Gold"),icon="coin",color=C.gold}},premiumCategory,function(id) premiumCategory=id; renderContext() end)
		for _,group in ipairs({{tab="hero",kind="hero",items=Catalog.Products.Heroes},{tab="offer",kind="product",items=Catalog.Products.Consumables,only=function(def) return not goldPack(def) end},{tab="pass",kind="pass",items=Catalog.Products.Passes},{tab="product",kind="product",items=Catalog.Products.Consumables,only=goldPack}}) do
			if group.tab~=premiumCategory then continue end
			-- Cheapest first; the starter pack has its own banner above.
			local keys={}
			for key in pairs(group.items) do
				-- The permanent season pass gives way to the per-season product (still shown to its owners).
				local retired=group.kind=="pass" and key=="season" and (profile().passes or {}).season~=true and configured("product","seasonPass")
				if key~="starterPack" and configured(group.kind,key) and not retired and (not group.only or group.only(group.items[key])) then table.insert(keys,key) end
			end
			-- Things you do not own come first: a shop that opens on "already yours" sells nothing.
			local function ownedKey(key) return group.kind=="hero" and (profile().heroes or {})[key]~=nil or group.kind=="pass" and (profile().passes or {})[key]==true or group.kind=="product" and key=="seasonPass" and (profile().seasonStatus or {}).owned==true end
			table.sort(keys,function(a,b)
				-- The item a shortcut asked for leads (the hero page's "Buy with Robux").
				if a==focus or b==focus then return a==focus end
				local oa,ob=ownedKey(a),ownedKey(b)
				if oa~=ob then return not oa end
				local pa,pb=group.items[a].price or 0,group.items[b].price or 0
				if pa~=pb then return pa<pb end
				return a<b
			end)
			-- Gold packs say how good a deal they are: the best Gold per Robux wears
			-- a badge; the suggested pack has a separate recommendation.
			local bestGold,bestRatio
			if group.kind=="product" then
				for key,def in pairs(group.items) do
					local quote=productInfo["product:"..key]
					-- The catalogue price until this player's regional quote arrives, so
					-- the badge is right on the first draw (quotes never redraw the window).
					local price=type(quote)=="table" and quote.price or def.price
					if def.gold and not def.heroPicks and key~="starterPack" and price and price>0 then
						local ratio=def.gold/price
						if not bestRatio or ratio>bestRatio then bestGold,bestRatio=key,ratio end
					end
				end
			end
			for _,key in ipairs(keys) do
				local def=group.items[key]; local info=productInfo[group.kind..":"..key]
				local owned=ownedKey(key)
				local tint=group.kind=="hero" and UI.color(Catalog.Rarities[Catalog.Heroes[key].rarity].color) or group.kind=="pass" and C.green or C.gold
				-- A short phone screen gets a slimmer row, so more than one product shows.
				local slim=UI.sizeClass(screenSize().X,screenSize().Y).short
				local narrowGold=group.kind=="product" and def.gold~=nil and not slim and screenSize().X<600
				local rowH,artW,buttonH=slim and 96 or 150,slim and 74 or 118,slim and 38 or 50
				if narrowGold then rowH=190 end
				local topY=slim and 5 or 10
				local row=UI.roundFrame(body,{Name="Product_"..key,Size=UDim2.new(1,-6,0,rowH),BackgroundColor3=UI.Skin.slot},tint)
				-- A hero for sale tells its numbers on hover, like everywhere else.
				if group.kind=="hero" then UI.hover(row,function(box) heroTooltip(box,key) end,330) end
				UI.stroke(row,tint,3)
				local light=row:FindFirstChildOfClass("UIGradient")
				if light then light.Color=ColorSequence.new(tint:Lerp(Color3.new(1,1,1),0.1),UI.Skin.slot); light.Rotation=0; light.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0.55),NumberSequenceKeypoint.new(0.6,0.85),NumberSequenceKeypoint.new(1,0.95)}) end
				local left=artW+18
				local art=UI.portraitStage(row,tint,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(artW,rowH-16)})
				if group.kind=="hero" then heroPortrait(row,key,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(artW,rowH-16)})
				else UI.illustration(art,group.kind=="pass" and "star" or "coin",C.gold,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(slim and 48 or 64,slim and 48 or 64)}) end
				if group.kind=="hero" then UI.chip(row,Catalog.Upper(L(Catalog.Rarities[Catalog.Heroes[key].rarity].name)),tint,{Position=UDim2.fromOffset(left,topY),Size=UDim2.fromOffset(96,20),TextSize=12}) end
				local isGold=group.kind=="product" and def.gold~=nil and def.boostSeconds==nil and def.heroPicks==nil
				local goldHeadingBottom=0
				if isGold then
					local badge=key==bestGold and {T("Melhor valor","Best value"),C.green} or def.popular and {T("Sugestão","Recommended"),C.coral} or nil
					local used=0
					if badge then
						UI.chip(row,badge[1],badge[2],{Name="Badge_"..key,Position=UDim2.fromOffset(left,topY),Size=UDim2.fromOffset(122,20),TextSize=12})
						used=130
					end
					-- The Gold per Robux comes from the price the platform reports.
					local price=type(info)=="table" and tonumber(info.price)
					if price and price>0 then
						local valueY=topY+(narrowGold and badge and 22 or 0)
						UI.fit(UI.label(row,T("≈ ","≈ ")..UI.format(math.floor(def.gold/price+0.5))..T(" Ouro por Robux"," Gold per Robux"),{Name="Value_"..key,Position=UDim2.fromOffset(left+(narrowGold and 0 or used),valueY),Size=UDim2.new(1,-left-(narrowGold and 64 or used+12),0,narrowGold and 26 or 20),TextSize=13,TextColor3=C.cream}),10)
						goldHeadingBottom=valueY+26
					end
				end
				local nameY=(group.kind=="hero" or isGold) and (slim and 25 or 32) or (slim and 8 or 12)
				if narrowGold then nameY=math.max(40,goldHeadingBottom+4) end
				UI.fit(UI.label(row,L(def.name),{Name="ProductName",Position=UDim2.fromOffset(left,nameY),Size=UDim2.new(1,-left-64,0,slim and 22 or 30),TextWrapped=true,Font=UI.Fonts.display,TextSize=slim and 19 or 24}),12)
				-- One line says what it is: a hero's numbers, a pass's or a pack's effect.
				if not slim then
					local line=""
					if group.kind=="hero" then
						local hero=Catalog.Heroes[key]
						local perSecond=hero.interval>0 and 1/hero.interval or 0
						line=T("Dano ","Damage ")..tostring(hero.damage).."  •  "..T("Alcance ","Range ")..tostring(hero.range).."  •  "..string.format("%.1f",perSecond)..T(" ataques/s"," hits/s")
					elseif def.description then line=L(def.description)
					elseif isGold then line=T("Ouro para abrir baús de heróis e bases","Gold to open hero and base chests") end
					if line~="" then UI.fit(UI.label(row,line,{Name="ProductLine",Position=UDim2.fromOffset(left,nameY+30),Size=UDim2.new(1,-left-(narrowGold and 12 or 64),0,32),TextSize=16,TextColor3=C.muted}),10) end
				end
				local cacheKey=group.kind..":"..key
				local buy=UI.button(row,quoteLabel(info,owned),function()
					if owned then return end
					-- The quote as it is now: it may have arrived after this row was drawn.
					local current=productInfo[cacheKey]
					if current=="retry" then productInfo[cacheKey]=nil; fetchProducts(premiumCategory); renderContext(); return end
					if type(current)~="table" or current.preview then return end
					local ok=pcall(function() if group.kind=="pass" then MarketplaceService:PromptGamePassPurchase(player,current.id) else MarketplaceService:PromptProductPurchase(player,current.id) end end)
					if not ok then showToast(T("Falha ao abrir compra.","Could not open purchase."),true) end
				end,{Name="Buy_"..cacheKey,Position=UDim2.new(0,left,1,-buttonH-(slim and 6 or 10)),Size=UDim2.new(1,-left-12,0,buttonH),BackgroundColor3=owned and C.card or C.green,TextSize=slim and 17 or 21})
				buy:SetAttribute("Owned",owned==true)
				if not quoteUsable(info,owned) then UI.disabled(buy) end
				-- Everything can be inspected before it is paid for.
				local open=kit.shopInfo==cacheKey
				UI.button(row,open and "X" or "i",function() kit.shopInfo=open and nil or cacheKey; renderContext() end,{Name="ProductInfo_"..key,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,slim and 4 or 8),Size=UDim2.fromOffset(slim and 38 or 44,slim and 38 or 44),BackgroundColor3=open and C.red or C.blue,TextSize=22})
				if open then
					local details=UI.roundFrame(body,{Name="ProductDetails_"..key,Size=UDim2.new(1,-6,0,10),BackgroundColor3=C.background,AutomaticSize=Enum.AutomaticSize.Y},tint)
					UI.padding(details,12)
					UI.list(details,8)
					if group.kind=="hero" then
						local hero=Catalog.Heroes[key]
						UI.label(details,L(hero.description),{Name="InfoText",Size=UDim2.new(1,0,0,44),TextSize=16,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,TextColor3=C.muted})
						local stats=UI.row(details,74)
						local perSecond=hero.interval>0 and 1/hero.interval or 0
						for index,entry in ipairs({{T("Dano","Damage"),tostring(hero.damage)},{T("Alcance","Range"),tostring(hero.range)},{T("Ataques/s","Hits/s"),string.format("%.1f",perSecond)}}) do
							local cell=UI.roundFrame(stats,{Name="InfoStat_"..index,Position=UDim2.new((index-1)/3,0,0,0),Size=UDim2.new(1/3,-8,1,-4),BackgroundColor3=tint:Lerp(C.panel,0.7)},tint)
							UI.label(cell,entry[1],{Position=UDim2.fromOffset(6,4),Size=UDim2.new(1,-12,0,20),TextSize=14,Font=UI.Fonts.display,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Center})
							UI.label(cell,entry[2],{Position=UDim2.fromOffset(6,26),Size=UDim2.new(1,-12,0,40),TextSize=30,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center})
						end
						for _,trait in ipairs(UI.heroTraits(hero,T)) do UI.label(details,"• "..trait,{Size=UDim2.new(1,0,0,24),TextSize=15,TextColor3=C.cream,TextWrapped=true,TextTruncate=Enum.TextTruncate.None}) end
						local ability=Catalog.Abilities[hero.ability]
						if ability then
							UI.label(details,"★ "..L(ability.name),{Size=UDim2.new(1,0,0,26),TextSize=18,Font=UI.Fonts.display,TextColor3=C.gold})
							UI.label(details,Rules.AbilityText(ability,1,ctx.language()),{Size=UDim2.new(1,0,0,44),TextSize=15,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,TextColor3=C.muted})
						end
						for index,branch in ipairs(hero.branches or {}) do
							UI.label(details,index..". "..L(branch.name).." — "..L(branch.description),{Size=UDim2.new(1,0,0,40),TextSize=14,TextWrapped=true,TextTruncate=Enum.TextTruncate.None,TextColor3=C.text})
						end
					else
						UI.label(details,def.description and L(def.description) or (isGold and (T("Você recebe ","You get ")..UI.format(def.gold)..T(" Ouro para gastar em baús."," Gold to spend on chests.")) or ""),{Name="InfoText",Size=UDim2.new(1,0,0,60),TextSize=17,TextWrapped=true,TextTruncate=Enum.TextTruncate.None})
					end
				end
			end
		end
		fetchProducts(premiumCategory)
	end

	local function contextShop(body, data)
		contextPremium(body, data)
	end

	-- One pass, from its stand in the plaza (owner, 15/10): what it gives and its
	-- price on one card, never the whole list. The server opened the Robux
	-- purchase when the stand was used; the button here opens it again.
	local PASS_ART = { collector = "magnet", training = "star", speed3 = "clock", season = "gift", vip = "trophy" }
	local PASS_TINT = { collector = Color3.fromRGB(118, 211, 183), training = Color3.fromRGB(172, 149, 239), speed3 = Color3.fromRGB(90, 190, 255),
		season = Color3.fromRGB(255, 159, 215), vip = Color3.fromRGB(235, 173, 93) }
	local function contextOffer(body, data)
		local key = type(data) == "table" and data.shopKey
		local def = key and Catalog.Products.Passes[key]
		if not def or not configured("pass", key) then return contextPremium(body, { shopKind = "pass" }) end
		local tint = PASS_TINT[key] or C.gold
		local owned = (profile().passes or {})[key] == true
		local cacheKey = "pass:" .. key
		local info = productInfo[cacheKey]
		local slim = UI.sizeClass(screenSize().X, screenSize().Y).short
		local headH, artW = slim and 104 or 140, slim and 88 or 124
		-- The pass on its stage, its name, and that it is forever.
		local top = UI.roundFrame(body, { Name = "OfferHeader", Size = UDim2.new(1, -6, 0, headH), BackgroundColor3 = UI.Skin.slot }, tint)
		UI.stroke(top, tint, 3)
		local art = UI.portraitStage(top, tint, { Name = "OfferArt", Position = UDim2.fromOffset(8, 8), Size = UDim2.fromOffset(artW, headH - 16) })
		UI.illustration(art, PASS_ART[key] or "star", C.gold, { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(slim and 56 or 76, slim and 56 or 76) })
		local left = artW + 20
		UI.chip(top, owned and T("JÁ É SEU", "YOURS") or T("VANTAGEM PERMANENTE", "PERMANENT PERK"), owned and C.green or tint, { Name = "OfferChip", Position = UDim2.fromOffset(left, 10), Size = UDim2.fromOffset(170, 22), TextSize = 12 })
		UI.fit(UI.label(top, Catalog.Upper(L(def.name)), { Name = "OfferName", Position = UDim2.fromOffset(left, 36), Size = UDim2.new(1, -left - 10, 0, slim and 30 or 40), Font = UI.Fonts.display, TextSize = slim and 24 or 32, TextColor3 = tint:Lerp(C.text, 0.35) }), 14)
		if not slim then
			UI.fit(UI.label(top, L(def.description), { Name = "OfferLine", Position = UDim2.fromOffset(left, 80), Size = UDim2.new(1, -left - 10, 0, 50), TextWrapped = true, TextSize = 15, TextColor3 = C.muted, TextYAlignment = Enum.TextYAlignment.Top }), 10)
		end
		-- What it gives, a line each, ticked.
		UI.section(body, T("O que você ganha", "What you get"))
		for index, line in ipairs(def.benefits or { def.description }) do
			local row = UI.roundFrame(body, { Name = "OfferBenefit_" .. index, Size = UDim2.new(1, -6, 0, slim and 40 or 48), BackgroundColor3 = tint:Lerp(C.panel, 0.82) }, tint)
			local badge = UI.frame(row, { Name = "Check", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 10, 0.5, 0), Size = UDim2.fromOffset(26, 26), BackgroundColor3 = C.green })
			UI.corner(badge, 13)
			UI.label(badge, "✓", { Size = UDim2.fromScale(1, 1), TextSize = 17, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Center })
			UI.fit(UI.label(row, L(line), { Name = "BenefitText", Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -54, 1, 0), TextWrapped = true, TextSize = slim and 15 or 17, TextColor3 = C.text }), 10)
		end
		-- The purchase at the price this player's region pays, or that it is theirs.
		local buy = UI.button(body, quoteLabel(info, owned), function()
			if owned then return end
			local current = productInfo[cacheKey]
			if current == "retry" then productInfo[cacheKey] = nil; fetchProducts("pass"); renderContext(); return end
			if type(current) ~= "table" or current.preview then return end
			local ok = pcall(function() MarketplaceService:PromptGamePassPurchase(player, current.id) end)
			if not ok then showToast(T("Falha ao abrir compra.", "Could not open purchase."), true) end
		end, { Name = "Buy_" .. cacheKey, Size = UDim2.new(1, -6, 0, slim and 50 or 60), BackgroundColor3 = owned and C.card or C.green, TextSize = slim and 20 or 24 })
		buy:SetAttribute("Owned", owned)
		if not quoteUsable(info, owned) then UI.disabled(buy) end
		UI.secondary(body, T("Ver todas as vantagens", "See every perk"), function() openContext("premium", { hud = true, shopKind = "pass" }) end, { Name = "OfferAll", Size = UDim2.new(1, -6, 0, 40), TextSize = 15 })
		fetchProducts("pass")
	end

	return { configured = configured, contextPremium = contextPremium, contextShop = contextShop, contextOffer = contextOffer }
end

return Shop
