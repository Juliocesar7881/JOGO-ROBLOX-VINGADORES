-- The lobby's context panels: heroes, squad, chests, shop, quests, rewards,
-- leaderboard, talents, modes, bases, settings and the guide. They used to
-- live in init.client, which ran into Luau's 200-register limit; the
-- controller builds them once with everything they use in `ctx` (values that
-- change, like the state snapshot, through accessor functions) and keeps the
-- state it shares with them (selected chest, hero tab, inventory view) in
-- `kit`. Purely presentation: every action is a request the server decides.
local Panels = {}

function Panels.new(ctx)
	local C, Catalog, Config, L, MarketplaceService, Rules, T, UI, act, at, audio, board = ctx.C, ctx.Catalog, ctx.Config, ctx.L, ctx.MarketplaceService, ctx.Rules, ctx.T, ctx.UI, ctx.act, ctx.at, ctx.audio, ctx.board
	local celebrate, contains, copy, heading, heroName, heroPortrait, kit, levelProgress, mapName, number, pending, player = ctx.celebrate, ctx.contains, ctx.copy, ctx.heading, ctx.heroName, ctx.heroPortrait, ctx.kit, ctx.levelProgress, ctx.mapName, ctx.number, ctx.pending, ctx.player
	local productInfo, profile, request, routePreview, screenSize, showToast, smallText = ctx.productInfo, ctx.profile, ctx.request, ctx.routePreview, ctx.screenSize, ctx.showToast, ctx.smallText
	local openContext, renderContext, fetchProducts, closeContext = ctx.openContext, ctx.renderContext, ctx.fetchProducts, ctx.closeContext
	-- Training starts at once (the server boards the commander); the panel steps aside.
	local function startTraining() closeContext(); act("StartTraining", {}) end

	-- Lobby locations and the HUD share these panels. The HUD offers a quick
	-- route to playing, forming a team and spending earned progression points.
	kit.modeTint = {
		normal = C.green, ranked = Color3.fromRGB(255, 138, 61), tutorial = C.gold,
		cards = Color3.fromRGB(177,119,243),
	}
	for id, destination in pairs(Catalog.Destinations) do
		if not kit.modeTint[id] then kit.modeTint[id] = kit.modeTint[destination.modeId] end
	end
	kit.modeLockHints = {
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

	kit.heroDetailTab ="power"
	-- One hero, big: the figure on its rarity stage, name, price and mastery,
	-- three stat tiles, then either the leader power or the two tower paths.
	local function contextHero(body, data)
		local id = data.heroId
		local def = Catalog.Heroes[id]
		if not def then return end
		local p = profile()
		local owned = (p.heroes or {})[id]
		local rarity = Catalog.Rarities[def.rarity]
		local tint = UI.color(rarity.color)
		UI.secondary(body,T("‹ VOLTAR","‹ BACK"),function() openContext("inventory",{hud=true}) end,{Name="BackToInventory",Size=UDim2.fromOffset(120,40),TextSize=15})
		-- On a short screen the actions come right under a smaller showcase: the
		-- panel opens on what you can do, and the numbers wait below.
		local short = UI.sizeClass(screenSize().X, screenSize().Y).short
		local showcase = UI.row(body, short and 132 or 210)
		UI.portraitStage(showcase,tint,{Name="HeroStage",Size=UDim2.new(0.42,0,1,0)})
		heroPortrait(showcase,id,{Position=UDim2.fromOffset(4,4),Size=UDim2.new(0.42,-8,1,-8)})
		local info=UI.frame(showcase,{Position=UDim2.new(0.42,12,0,0),Size=UDim2.new(0.58,-12,1,0),BackgroundTransparency=1})
		UI.chip(info,Catalog.Upper(L(rarity.name)),tint,{Size=UDim2.fromOffset(110,24),TextSize=13})
		UI.label(info,((owned and owned.shiny) and "✨ " or "")..L(def.name),{Name="HeroTitle",Position=UDim2.fromOffset(0,28),Size=UDim2.new(1,0,0,short and 36 or 66),TextSize=short and 24 or 28,Font=UI.Fonts.display,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
		if not short then UI.label(info,L(def.description),{Position=UDim2.fromOffset(0,96),Size=UDim2.new(1,0,0,52),TextSize=14,TextWrapped=true,TextColor3=C.muted,TextYAlignment=Enum.TextYAlignment.Top}) end
		UI.chip(info,"💰 "..number(def.cost)..T(" na partida"," in battle"),C.gold:Lerp(C.panel,0.3),{Position=UDim2.fromOffset(0,short and 68 or 152),Size=UDim2.fromOffset(150,26),TextSize=13})
		if owned then
			local stars=math.clamp(owned.stars or 0,0,Catalog.Stars.max)
			local rowY=short and 98 or 182
			UI.label(info,T("MAESTRIA ","MASTERY ")..owned.level.."/20",{Position=UDim2.fromOffset(0,rowY),Size=UDim2.new(0.55,0,0,20),TextSize=13,Font=UI.Fonts.display,TextColor3=C.violet})
			UI.label(info,string.rep("★",stars)..string.rep("☆",Catalog.Stars.max-stars),{Name="HeroStars",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,rowY-2),Size=UDim2.new(0.45,0,0,24),TextSize=17,Font=UI.Fonts.display,TextColor3=C.gold,TextXAlignment=Enum.TextXAlignment.Right})
		end
		local function drawActions()
			if owned then
				UI.button(body,(p.loadout or {})[1]==id and T("★ É O SEU LÍDER","★ YOUR LEADER") or T("★ USAR COMO LÍDER","★ MAKE LEADER"),function()
					makeLeader(id)
				end,{Name="MakeLeader_"..id,Size=UDim2.new(1,-6,0,50),BackgroundColor3=C.gold,TextSize=18})
				UI.secondary(body,contains(p.loadout,id) and T("TIRAR DA EQUIPE","REMOVE FROM TEAM") or T("+ COLOCAR NA EQUIPE","+ ADD TO TEAM"),function()
					local list=copy(p.loadout); local old=table.find(list,id)
					if old then table.remove(list,old) elseif #list<5 then table.insert(list,id) else showToast(T("A equipe tem 5 heróis. Tire um primeiro.","Team full. Remove a hero first."),true); return end
					act("SetLoadout",{heroes=list})
				end,{Size=UDim2.new(1,-6,0,46),TextSize=16,BackgroundColor3=contains(p.loadout,id) and C.card or C.green})
			else
				UI.button(body,T("GANHE NA INVOCAÇÃO","GET IT AT THE SUMMON HALLS"),function() routePreview.goShop() end,{Size=UDim2.new(1,-6,0,50),BackgroundColor3=C.gold,TextSize=17})
				UI.secondary(body,T("COMPRAR COM ROBUX","BUY WITH ROBUX"),function() openContext("premium",{hud=true}) end,{Size=UDim2.new(1,-6,0,44),TextSize=15})
			end
		end
		if short then drawActions() end
		-- Three numbers anyone can compare: hit, reach, speed.
		local stats=UI.row(body,78)
		local perSecond=def.interval>0 and 1/def.interval or 0
		for index,entry in ipairs({{"⚔",T("DANO","DAMAGE"),tostring(def.damage)},{"🎯",T("ALCANCE","RANGE"),tostring(def.range)},{"⚡",T("ATAQUES/S","HITS/S"),string.format("%.1f",perSecond)}}) do
			local card=UI.roundFrame(stats,{Name="HeroStat_"..index,Position=UDim2.new((index-1)/3,0,0,0),Size=UDim2.new(1/3,-8,1,-4),BackgroundColor3=tint:Lerp(C.panel,0.7)},tint)
			UI.label(card,entry[1].." "..entry[2],{Position=UDim2.fromOffset(8,6),Size=UDim2.new(1,-16,0,20),TextSize=12,Font=UI.Fonts.display,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Center})
			UI.label(card,entry[3],{Position=UDim2.fromOffset(8,28),Size=UDim2.new(1,-16,0,38),TextSize=28,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center})
		end
		UI.label(body,def.air and T("✈ ACERTA INIMIGOS NO CHÃO E VOANDO","✈ HITS GROUND AND FLYING ENEMIES") or T("🦶 ACERTA SÓ INIMIGOS NO CHÃO","🦶 HITS GROUND ENEMIES ONLY"),{Name="HeroTargets",Size=UDim2.new(1,-6,0,26),TextColor3=def.air and C.green or C.coral,Font=UI.Fonts.display,TextSize=15,TextWrapped=true})
		if def.pickup then UI.label(body,"🧲 "..T("Puxa o Ouro que cai perto dela","Pulls in Gold that lands nearby"),{Size=UDim2.new(1,-6,0,24),TextColor3=C.gold,Font=UI.Fonts.display,TextSize=14}) end
		if not short then drawActions() end
		local tabs=UI.row(body,44)
		for index,tab in ipairs({{id="power",label=T("PODER","POWER")},{id="defense",label=T("CAMINHOS","PATHS")}}) do
			UI.button(tabs,tab.label,function() kit.heroDetailTab=tab.id; renderContext() end,{Name="HeroDetail_"..tab.id,Position=UDim2.new((index-1)/2,0,0,0),Size=UDim2.new(0.5,-6,0,44),TextSize=16,BackgroundColor3=kit.heroDetailTab==tab.id and tint or C.card})
		end
		if kit.heroDetailTab=="defense" then
			-- The tower's two specializations, chosen at its last upgrade.
			for index,branch in ipairs(def.branches or {}) do
				local card=UI.roundFrame(body,{Name="HeroBranch_"..index,Size=UDim2.new(1,-6,0,86),BackgroundColor3=C.card},tint)
				UI.label(card,tostring(index),{Position=UDim2.fromOffset(10,8),Size=UDim2.fromOffset(34,34),TextColor3=tint,TextSize=30,Font=UI.Fonts.display})
				UI.label(card,L(branch.name),{Position=UDim2.fromOffset(50,6),Size=UDim2.new(1,-60,0,30),TextWrapped=true,TextSize=18,Font=UI.Fonts.display})
				UI.label(card,L(branch.description),{Position=UDim2.fromOffset(12,40),Size=UDim2.new(1,-24,0,40),TextWrapped=true,TextSize=13,TextColor3=C.muted})
			end
			return
		end
		-- The leader power: what it does now, its rank as pips, and the next rank.
		local ability=Catalog.Abilities[def.ability]
		local rank=(p.abilities or {})[id] or 1
		local power=UI.roundFrame(body,{Name="LeaderPowerCard",Size=UDim2.new(1,-6,0,112),BackgroundColor3=tint:Lerp(C.panel,0.75)},tint)
		UI.label(power,"★ "..L(ability.name),{Position=UDim2.fromOffset(12,6),Size=UDim2.new(1,-110,0,30),TextSize=20,Font=UI.Fonts.display,TextColor3=C.gold})
		UI.chip(power,"RANK "..rank.."/"..Catalog.AbilityRanks.max,C.gold,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,8),Size=UDim2.fromOffset(86,24),TextSize=13})
		UI.label(power,Rules.AbilityText(ability,rank,ctx.language()),{Position=UDim2.fromOffset(12,38),Size=UDim2.new(1,-24,0,46),TextSize=13,TextWrapped=true})
		for level=1,Catalog.AbilityRanks.max do
			local pip=UI.frame(power,{Name="AbilityProgress_"..level,Position=UDim2.new((level-1)/Catalog.AbilityRanks.max,12,1,-20),Size=UDim2.new(1/Catalog.AbilityRanks.max,-16,0,10),BackgroundColor3=level<=rank and C.gold or C.background})
			UI.corner(pip,5)
		end
		if not owned then return end
		local offer=Rules.AbilityUpgrade(def,rank)
		if offer then
			local buy=UI.button(body,T("SUBIR PARA RANK ","UPGRADE TO RANK ")..(rank+1).." • 💰 "..number(offer.cost),function()
				act("UpgradeAbility",{heroId=id,expectedRank=rank},function() audio:Cue("upgrade") end)
			end,{Name="UpgradeAbility_"..id,Size=UDim2.new(1,-6,0,50),BackgroundColor3=C.green,TextSize=17})
			if owned.level<offer.mastery or (p.gold or 0)<offer.cost then UI.disabled(buy) end
			if owned.level<offer.mastery then
				smallText(body,T("Precisa de maestria ","Needs mastery ")..offer.mastery..T(": jogue com este herói.",": play with this hero."),0,28)
			elseif (p.gold or 0)<offer.cost then
				smallText(body,T("Faltam ","You need ")..number(offer.cost-(p.gold or 0))..T(" Ouro."," more Gold."),0,28)
			end
		else
			UI.label(body,T("PODER NO RANK MÁXIMO!","POWER AT MAX RANK!"),{Size=UDim2.new(1,-6,0,32),TextColor3=C.gold,Font=UI.Fonts.display,TextSize=18})
		end
	end

	local function categoryTabs(body, name, options, selected, onSelect)
	 local row=UI.row(body,44)
	 row.Name=name
	 for index,option in ipairs(options) do
	  UI.button(row,option.label,function() onSelect(option.id) end,{
	   Name=name.."_"..option.id,Position=UDim2.new((index-1)/#options,0,0,0),
	   Size=UDim2.new(1/#options,-6,0,44),TextSize=16,
	   BackgroundColor3=selected==option.id and C.gold or C.card,
	   TextColor3=selected==option.id and C.background or C.text})
	 end
	end

	local lastChestResult
	kit.selectedChest ="rare"
	local premiumCategory="hero"
	local inventoryFilter="owned"
	kit.inventoryView ={query="",rarity="all",sort="collection",leaderPick=false}
	-- The summon counter: a row of treasure chests by tier, the chosen one big
	-- with its buy button and guarantee, and everyone it can give with clean
	-- odds. Chests cost the Gold earned in battle.
	local function contextChests(body,data)
		local p=profile()
		local chest=Catalog.Chests[kit.selectedChest]
		local collection=chest.kind or "hero"
		local isBase=collection=="base"
		local tint=isBase and C.green or C.gold
		local catalog=isBase and Catalog.Bases or Catalog.Heroes
		local owned=isBase and (p.bases or {outpost=true}) or (p.heroes or {})
		local ids=isBase and Catalog.BaseChestOrder or Catalog.HeroChestOrder
		local size=screenSize(); local slot=UI.contextLayout(size.X,size.Y,{wide=true,elevator=ctx.state().elevator~=nil,difficulty=ctx.state().elevator~=nil and ctx.state().elevator.modeId=="normal"})
		local width=slot.w-34; local wide=width>=620
		local function portrait(parent,id,properties)
			if isBase then return UI.basePortrait(parent,catalog[id],properties) end
			return heroPortrait(parent,id,properties)
		end

		local function resultCard()
		if lastChestResult and ((lastChestResult.baseId~=nil)==isBase) then
			local r=lastChestResult; local id=r.baseId or r.heroId
			local color=UI.color(Catalog.Rarities[r.rarity].color)
			local card=UI.roundFrame(body,{Name="ChestResult",Size=UDim2.new(1,-6,0,112),BackgroundColor3=color:Lerp(C.panel,0.7)},color)
			portrait(card,id,{Position=UDim2.fromOffset(6,6),Size=UDim2.fromOffset(92,100)})
			UI.label(card,T("VOCÊ GANHOU: ","YOU GOT: ")..L(catalog[id].name),{Position=UDim2.fromOffset(106,6),Size=UDim2.new(1,-116,0,30),TextSize=18,Font=UI.Fonts.display,TextWrapped=true})
			local message=r.duplicate and (T("Repetido: +","Duplicate: +")..number(r.refundGold)..T(" Ouro"," Gold")) or T("NOVO NA COLEÇÃO!","NEW IN YOUR COLLECTION!")
			UI.label(card,message,{Position=UDim2.fromOffset(106,36),Size=UDim2.new(1,-116,0,20),TextSize=14,Font=UI.Fonts.display,TextColor3=color})
			local active=isBase and p.equippedBase==id
			local button=UI.button(card,active and T("BASE ATIVA","ACTIVE BASE") or isBase and T("ATIVAR ESTA BASE","ACTIVATE THIS BASE") or T("VER HERÓI","VIEW HERO"),function()
				if isBase then act("EquipBase",{baseId=id},function() showToast(T("Base ativada para a próxima partida!","Base activated for your next match!")) end)
				else openContext("hero",{heroId=id}) end
			end,{Name="SummonEquipResult",Position=UDim2.fromOffset(106,60),Size=UDim2.new(1,-116,0,44),BackgroundColor3=C.green,TextSize=15})
			if active then UI.disabled(button) end
		end
		end

		-- The tiers: big chests you can see from across the room.
		-- A phone panel has room for the tiers and one buy row above the fold:
		-- shorter tiles and a single-row purchase card keep SUMMON visible.
		local tileH=wide and 112 or 92
		local selector=UI.scroll(body,{Name="SummonCrates",Size=UDim2.new(1,-6,0,tileH+16),AutomaticCanvasSize=Enum.AutomaticSize.None,ScrollingDirection=Enum.ScrollingDirection.X,ScrollBarThickness=3,ScrollBarImageColor3=tint})
		local tileWidth=wide and (width-6)/#ids or 118
		selector.CanvasSize=UDim2.fromOffset(tileWidth*#ids,0)
		selector:SetAttribute("SummonChestId",kit.selectedChest)
		local scrolls=data.summonViews and data.summonViews[kit.selectedChest] or {}
		selector.CanvasPosition=scrolls.crates or Vector2.new(0,0)
		for i,id in ipairs(ids) do
			local def=Catalog.Chests[id]; local chosen=id==kit.selectedChest
			local color=UI.color(def.color)
			local tile=UI.button(selector,"",function() kit.selectedChest=id; kit.confirmChest=nil; renderContext() end,
				{Name="SummonSelect_"..id,Position=UDim2.fromOffset((i-1)*tileWidth+3,chosen and 2 or 8),Size=UDim2.fromOffset(tileWidth-8,tileH),BackgroundColor3=chosen and color:Lerp(C.panel,0.25) or color:Lerp(C.panel,0.72)})
			if chosen then UI.stroke(tile,Color3.new(1,1,1),3) end
			UI.illustration(tile,"crate",color,{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,4),Size=wide and UDim2.fromOffset(58,52) or UDim2.fromOffset(46,40)})
			UI.label(tile,L(def.name),{Position=UDim2.fromOffset(4,wide and 56 or 44),Size=UDim2.new(1,-8,0,wide and 30 or 24),TextWrapped=true,TextSize=wide and 13 or 12,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center})
			UI.label(tile,"💰 "..number(def.cost),{Position=UDim2.new(0,4,1,-26),Size=UDim2.new(1,-8,0,22),TextColor3=C.gold,TextSize=16,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center})
		end

		local forced=chest.pity and ((p.pity or {})[kit.selectedChest] or 0)+1>=chest.pity.after
		local minimum=forced and table.find(Catalog.RarityOrder,chest.pity.minimum) or 1
		local total=0; local outcomes={}
		for index,rarity in ipairs(Catalog.RarityOrder) do if index>=minimum then total+=chest.odds[rarity] or 0 end end
		for index,rarity in ipairs(Catalog.RarityOrder) do
			local weight=index>=minimum and (chest.odds[rarity] or 0) or 0
			if weight>0 then
				local pool=Rules.ChestPool(rarity,collection); local fresh={}
				for _,id in ipairs(pool) do if not owned[id] then table.insert(fresh,id) end end
				local candidates=#fresh>0 and fresh or pool
				for _,id in ipairs(pool) do table.insert(outcomes,{id=id,rarity=rarity,chance=contains(candidates,id) and weight/total/#candidates*100 or 0}) end
			end
		end
		local purchaseParent, galleryParent=body,body
		local galleryHeight=254
		if wide then
			local stageHeight=math.max(260,math.min(440,slot.h-248))
			local stage=UI.frame(body,{Name="SummonStage",Size=UDim2.new(1,-6,0,stageHeight),BackgroundTransparency=1})
			galleryParent=UI.frame(stage,{Name="SummonPreview",Size=UDim2.new(0.58,-8,1,0),BackgroundTransparency=1})
			purchaseParent=UI.frame(stage,{Name="SummonActions",Position=UDim2.fromScale(0.59,0),Size=UDim2.new(0.41,0,1,0),BackgroundTransparency=1})
			UI.list(purchaseParent,8)
			galleryHeight=stageHeight-34
		end
		local eligible=(p.gold or 0)>=chest.cost and not p.paidRandomRestricted
		local color=UI.color(chest.color)
		local id=kit.selectedChest
		local confirming=kit.confirmChest==id
		local function openChest()
			if pending.OpenChest then return end
			pending.OpenChest=true; kit.confirmChest=nil; renderContext()
			task.spawn(function()
				local response=request("OpenChest",{chestId=id}); pending.OpenChest=nil
				if response and response.ok then
					lastChestResult=response.data and response.data.result
					if lastChestResult then celebrate:Chest(lastChestResult,id) end
				end
				if ctx.contextPanel() and ctx.contextPanel().kind=="chests" then renderContext() end
			end)
		end
		if not wide then
			-- One row: chest, name and balance, then the action on the right.
			local purchase=UI.roundFrame(purchaseParent,{Name="SummonPurchase",Size=UDim2.new(1,-6,0,74),BackgroundColor3=color:Lerp(C.panel,0.6)},color)
			UI.illustration(purchase,"crate",color,{Position=UDim2.fromOffset(6,8),Size=UDim2.fromOffset(62,56)})
			UI.label(purchase,Catalog.Upper(L(chest.name)),{Position=UDim2.fromOffset(74,8),Size=UDim2.new(0.5,-78,0,24),TextSize=16,Font=UI.Fonts.display,TextTruncate=Enum.TextTruncate.AtEnd})
			UI.label(purchase,"💰 "..number(p.gold),{Name="SummonBalance",Position=UDim2.fromOffset(74,32),Size=UDim2.new(0.5,-78,0,20),TextSize=14,Font=UI.Fonts.display,TextColor3=C.gold})
			if chest.pity then
				local count=(p.pity or {})[id] or 0
				local fill=UI.bar(purchase,C.gold,UDim2.fromOffset(74,56),UDim2.new(0.5,-80,0,7))
				fill.Size=UDim2.fromScale(math.clamp(count/chest.pity.after,0,1),1)
			end
			if confirming then
				local confirm=UI.button(purchase,T("CONFIRMAR!","CONFIRM!"),openChest,{Name="ConfirmChest_"..id,Position=UDim2.new(0.5,0,0,8),Size=UDim2.new(0.3,-6,0,58),BackgroundColor3=C.green,TextSize=16})
				if not eligible then UI.disabled(confirm) end
				UI.secondary(purchase,T("VOLTAR","BACK"),function() kit.confirmChest=nil; renderContext() end,{Name="CancelChest",Position=UDim2.new(0.8,0,0,8),Size=UDim2.new(0.2,-8,0,58),TextSize=13})
			else
				local button=UI.button(purchase,pending.OpenChest and T("INVOCANDO…","SUMMONING…") or T("INVOCAR\n💰 ","SUMMON\n💰 ")..number(chest.cost),function() kit.confirmChest=id; renderContext() end,
					{Name="OpenChest_"..id,Position=UDim2.new(0.5,0,0,8),Size=UDim2.new(0.5,-8,0,58),BackgroundColor3=C.green,TextSize=17})
				if not eligible or pending.OpenChest then UI.disabled(button) end
			end
		else
			local purchase=UI.roundFrame(purchaseParent,{Name="SummonPurchase",Size=UDim2.new(1,-6,0,confirming and 196 or 176),BackgroundColor3=color:Lerp(C.panel,0.6)},color)
			UI.illustration(purchase,"crate",color,{Position=UDim2.fromOffset(10,8),Size=UDim2.fromOffset(92,82)})
			UI.label(purchase,Catalog.Upper(L(chest.name)),{Position=UDim2.fromOffset(110,10),Size=UDim2.new(1,-120,0,32),TextSize=22,Font=UI.Fonts.display,TextWrapped=true})
			UI.label(purchase,T("Você tem 💰 ","You have 💰 ")..number(p.gold),{Name="SummonBalance",Position=UDim2.fromOffset(110,44),Size=UDim2.new(1,-120,0,22),TextSize=15,Font=UI.Fonts.display,TextColor3=C.gold})
			if chest.pity then
				-- The guarantee as a bar that fills.
				local count=(p.pity or {})[id] or 0
				UI.label(purchase,forced and T("★ GARANTIA ATIVA!","★ GUARANTEE ACTIVE!") or (T("Garantia ","Guarantee ")..L(Catalog.Rarities[chest.pity.minimum].name).."+ "..count.."/"..chest.pity.after),{Position=UDim2.fromOffset(110,68),Size=UDim2.new(1,-120,0,18),TextSize=12,Font=UI.Fonts.display,TextColor3=forced and C.gold or C.muted})
				local fill=UI.bar(purchase,C.gold,UDim2.fromOffset(110,88),UDim2.new(1,-122,0,8))
				fill.Size=UDim2.fromScale(math.clamp(count/chest.pity.after,0,1),1)
			end
			if confirming then
				UI.label(purchase,T("Sobra: 💰 ","Left: 💰 ")..number((p.gold or 0)-chest.cost),{Position=UDim2.fromOffset(12,100),Size=UDim2.new(1,-24,0,26),TextSize=15,Font=UI.Fonts.display})
				local confirm=UI.button(purchase,T("CONFIRMAR!","CONFIRM!"),openChest,{Name="ConfirmChest_"..id,Position=UDim2.fromOffset(10,132),Size=UDim2.new(0.6,-14,0,54),BackgroundColor3=C.green,TextSize=19})
				if not eligible then UI.disabled(confirm) end
				UI.secondary(purchase,T("VOLTAR","BACK"),function() kit.confirmChest=nil; renderContext() end,{Name="CancelChest",Position=UDim2.new(0.6,0,0,132),Size=UDim2.new(0.4,-10,0,54),TextSize=16})
			else
				local button=UI.button(purchase,pending.OpenChest and T("INVOCANDO…","SUMMONING…") or T("INVOCAR • 💰 ","SUMMON • 💰 ")..number(chest.cost),function() kit.confirmChest=id; renderContext() end,
					{Name="OpenChest_"..id,Position=UDim2.fromOffset(10,108),Size=UDim2.new(1,-20,0,58),BackgroundColor3=C.green,TextSize=21})
				if not eligible or pending.OpenChest then UI.disabled(button) end
			end
		end
		if not eligible and not p.paidRandomRestricted then smallText(purchaseParent,T("Faltam 💰 ","You need 💰 ")..number(chest.cost-(p.gold or 0))..T(": jogue partidas e pegue os prêmios.",": play matches and claim gifts."),0,36) end

		local caption=UI.frame(galleryParent,{Name="SummonOddsCaption",Size=UDim2.new(1,-6,0,30),BackgroundTransparency=1})
		UI.label(caption,T("PODE VIR NESTE BAÚ","IN THIS CHEST"),{Size=UDim2.new(1,0,1,0),TextSize=20,Font=UI.Fonts.display,TextColor3=C.cream})
		local cols=wide and 3 or math.max(2,math.floor(width/145))
		local gallery=UI.scroll(galleryParent,{Name="SummonOdds",Position=UDim2.fromOffset(0,32),Size=UDim2.new(1,-6,0,galleryHeight),AutomaticCanvasSize=Enum.AutomaticSize.None,CanvasSize=UDim2.fromOffset(0,math.ceil(#outcomes/cols)*128),ScrollBarThickness=5,ScrollBarImageColor3=tint})
		gallery:SetAttribute("SummonChestId",kit.selectedChest)
		gallery.CanvasPosition=scrolls.odds or Vector2.new(0,0)
		for i,outcome in ipairs(outcomes) do
			local rarityColor=UI.color(Catalog.Rarities[outcome.rarity].color)
			local card=UI.roundFrame(gallery,{Name="ChestHero_"..outcome.id,Position=UDim2.new(((i-1)%cols)/cols,2,0,math.floor((i-1)/cols)*128),Size=UDim2.new(1/cols,-6,0,122),BackgroundColor3=rarityColor:Lerp(C.panel,0.6)},rarityColor)
			portrait(card,outcome.id,{Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,0,78)})
			UI.chip(card,UI.percent(outcome.chance,ctx.language()),rarityColor,{Name="ChestOdds_"..outcome.id,AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-6,0,6),Size=UDim2.fromOffset(58,22),TextSize=12})
			UI.label(card,L(catalog[outcome.id].name),{Position=UDim2.fromOffset(6,84),Size=UDim2.new(1,-12,0,34),TextWrapped=true,TextSize=13,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center})
		end
		smallText(body,isBase and T("Base repetida vira Ouro.","A duplicate base becomes Gold.") or T("Herói repetido vira Ouro e maestria. Heróis novos têm prioridade.","A duplicate hero becomes Gold and mastery. New heroes come first."),0,30)
		resultCard()
		if p.paidRandomRestricted then
			UI.section(body,T("ESCOLHA GARANTIDA","GUARANTEED CHOICE"),T("Esta conta compra sem sorteio: escolha exatamente o que receber.","This account buys without a draw: choose exactly what you get."))
			for _,itemId in ipairs(isBase and Catalog.BaseOrder or Catalog.HeroOrder) do
				if owned[itemId] then continue end
				local price=Rules.GuaranteedPrice(itemId); if not price then continue end
				local row=UI.roundFrame(body,{Name="Guaranteed_"..itemId,Size=UDim2.new(1,-6,0,64),BackgroundColor3=C.card})
				UI.label(row,L(catalog[itemId].name),{Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-168,0,48),TextWrapped=true,TextSize=16,Font=UI.Fonts.display})
				local buy=UI.button(row,"💰 "..number(price),function() act("BuyGuaranteed",{itemId=itemId}) end,{Position=UDim2.new(1,-148,0,8),Size=UDim2.fromOffset(136,48),TextSize=16})
				if p.gold<price then UI.disabled(buy) end
			end
		end
	end

	-- The starter pack, featured above every tab until the account owns it.
	local function starterOffer(body)
		local pack=Catalog.Products.Consumables.starterPack
		if not pack or profile().starterPack then return end
		local info=productInfo["product:starterPack"]
		local ready=type(info)=="table"
		local row=UI.roundFrame(body,{Name="StarterPack",Size=UDim2.new(1,-6,0,132),BackgroundColor3=C.gold:Lerp(C.panel,0.45)},C.gold)
		UI.candy(row)
		heroPortrait(row,pack.heroId,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(104,116)})
		UI.chip(row,T("SÓ UMA VEZ","ONE TIME ONLY"),C.red,{Position=UDim2.fromOffset(120,10),Size=UDim2.fromOffset(120,22),TextSize=12})
		UI.label(row,Catalog.Upper(L(pack.name)),{Position=UDim2.fromOffset(120,34),Size=UDim2.new(1,-130,0,28),Font=UI.Fonts.display,TextSize=22,TextColor3=C.gold})
		UI.label(row,L(Catalog.Heroes[pack.heroId].name).." + 💰 "..UI.format(pack.gold),{Position=UDim2.fromOffset(120,60),Size=UDim2.new(1,-130,0,22),Font=UI.Fonts.display,TextSize=16})
		local buy=UI.button(row,ready and ("R$ "..tostring(info.price)) or T("Carregando preço…","Loading price…"),function()
			if not ready then return end
			local ok=pcall(function() MarketplaceService:PromptProductPurchase(player,info.id) end)
			if not ok then showToast(T("Falha ao abrir compra.","Could not open purchase."),true) end
		end,{Name="Buy_product:starterPack",Position=UDim2.new(0,120,1,-46),Size=UDim2.new(1,-132,0,40),BackgroundColor3=C.green,TextSize=17})
		if not ready then UI.disabled(buy) end
	end

	local function contextPremium(body)
	 starterOffer(body)
	 categoryTabs(body,"PremiumTabs",{{id="hero",label=T("HERÓIS","HEROES")},{id="pass",label=T("PASSES","PASSES")},{id="product",label=T("OURO","GOLD")}},premiumCategory,function(id) premiumCategory=id; renderContext() end)
		for _,group in ipairs({{kind="hero",items=Catalog.Products.Heroes},{kind="pass",items=Catalog.Products.Passes},{kind="product",items=Catalog.Products.Consumables}}) do
			if group.kind~=premiumCategory then continue end
			-- Cheapest first; the starter pack has its own banner above.
			local keys={}; for key in pairs(group.items) do if key~="starterPack" then table.insert(keys,key) end end
			-- Things you do not own come first: a shop that opens on "already yours" sells nothing.
			local function ownedKey(key) return group.kind=="hero" and (profile().heroes or {})[key]~=nil or group.kind=="pass" and (profile().passes or {})[key]==true end
			table.sort(keys,function(a,b)
				local oa,ob=ownedKey(a),ownedKey(b)
				if oa~=ob then return not oa end
				local pa,pb=group.items[a].price or 0,group.items[b].price or 0
				if pa~=pb then return pa<pb end
				return a<b
			end)
			for _,key in ipairs(keys) do
				local def=group.items[key]; local info=productInfo[group.kind..":"..key]
				local owned=group.kind=="hero" and (profile().heroes or {})[key] or group.kind=="pass" and (profile().passes or {})[key]
				local tint=group.kind=="hero" and UI.color(Catalog.Rarities[Catalog.Heroes[key].rarity].color) or group.kind=="pass" and C.green or C.gold
				local row=UI.roundFrame(body,{Name="Product_"..key,Size=UDim2.new(1,-6,0,118),BackgroundColor3=tint:Lerp(C.panel,0.6)},tint)
				UI.candy(row)
				local left=118
				local art=UI.portraitStage(row,tint,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(100,102)})
				if group.kind=="hero" then heroPortrait(row,key,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(100,102)})
				else UI.illustration(art,group.kind=="pass" and "star" or "coin",C.gold,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(64,64)}) end
				if group.kind=="hero" then UI.chip(row,Catalog.Upper(L(Catalog.Rarities[Catalog.Heroes[key].rarity].name)),tint,{Position=UDim2.fromOffset(left,10),Size=UDim2.fromOffset(96,20),TextSize=12}) end
				UI.label(row,L(def.name),{Position=UDim2.fromOffset(left,group.kind=="hero" and 32 or 12),Size=UDim2.new(1,-left-12,0,30),TextWrapped=true,Font=UI.Fonts.display,TextSize=20})
				local cacheKey=group.kind..":"..key
				local ready=type(info)=="table"
				local label=owned and T("✓ JÁ É SEU","✓ YOURS") or ready and ("R$ "..tostring(info.price))
					or info=="retry" and T("Tentar de novo","Try again") or info==nil and T("Carregando preço…","Loading price…") or T("Indisponível","Unavailable")
				local buy=UI.button(row,label,function()
					if info=="retry" and not owned then productInfo[cacheKey]=nil; fetchProducts(); renderContext(); return end
					if not ready or owned then return end
					local ok=pcall(function() if group.kind=="pass" then MarketplaceService:PromptGamePassPurchase(player,info.id) else MarketplaceService:PromptProductPurchase(player,info.id) end end)
					if not ok then showToast(T("Falha ao abrir compra.","Could not open purchase."),true) end
				end,{Name="Buy_"..cacheKey,Position=UDim2.new(0,left,1,-56),Size=UDim2.new(1,-left-12,0,46),BackgroundColor3=owned and C.card or C.green,TextSize=17})
				if owned or (not ready and info~="retry") then UI.disabled(buy) end
			end
		end
		fetchProducts()
	end

	local function contextShop(body, data)
		if data.shopKind then premiumCategory=data.shopKind; data.shopKind=nil end
		contextPremium(body)
	end

	-- Today's missions, the week's mission, and any older ones still unclaimed
	-- (a mission lives three days after it was drawn). The newest set of each
	-- period is the current one; a ready mission always comes first.
	local function timeLeft(seconds)
		seconds = math.max(0, seconds)
		if seconds >= 86400 then return math.floor(seconds / 86400) .. "d " .. math.floor((seconds % 86400) / 3600) .. "h" end
		return math.floor(seconds / 3600) .. "h " .. string.format("%02d", math.floor((seconds % 3600) / 60)) .. "m"
	end

	local function contextQuests(body)
		local newest, groups, total = {}, { daily = {}, weekly = {}, old = {} }, 0
		for _, quest in pairs(profile().quests or {}) do
			local period = quest.period or "daily"
			newest[period] = math.max(newest[period] or 0, quest.expiresAt or 0)
		end
		for id, quest in pairs(profile().quests or {}) do
			local period = quest.period or "daily"
			local current = (quest.expiresAt or 0) == newest[period]
			if current or not quest.claimed then
				table.insert(groups[current and period or "old"], {id = id, quest = quest})
				total += 1
			end
		end
		local function state(item)
			local quest = item.quest
			if quest.claimed then return 2 end
			return (quest.progress or 0) >= (quest.target or 1) and 0 or 1
		end
		local function drawGroup(list, title, subtitle)
			if #list == 0 then return end
			table.sort(list, function(a, b)
				local sa, sb = state(a), state(b)
				if sa ~= sb then return sa < sb end
				return a.id < b.id
			end)
			UI.section(body, title, subtitle)
			for _, item in ipairs(list) do
				local quest, id = item.quest, item.id
				local progress = math.min(quest.progress or 0, quest.target or 1)
				local ready = not quest.claimed and progress >= (quest.target or 1)
				local card = UI.roundFrame(body, {Name = "Quest_" .. id, Size = UDim2.new(1, -6, 0, 122), BackgroundColor3 = ready and C.green:Lerp(C.panel, 0.6) or C.card}, ready and C.green or nil)
				UI.label(card, L(quest.name), {Position = UDim2.fromOffset(14, 8), Size = UDim2.new(1, -160, 0, 28), Font = UI.Fonts.display, TextSize = 19})
				UI.label(card, L(quest.description), {Position = UDim2.fromOffset(14, 36), Size = UDim2.new(1, -160, 0, 36), TextSize = 13, TextWrapped = true, TextColor3 = C.muted})
				local fill = UI.bar(card, ready and C.green or C.gold, UDim2.fromOffset(14, 84), UDim2.new(1, -170, 0, 18))
				fill.Size = UDim2.fromScale(progress / math.max(quest.target or 1, 1), 1)
				UI.label(fill.Parent, progress .. " / " .. (quest.target or 1), {Size = UDim2.fromScale(1, 1), TextSize = 13, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3})
				UI.label(card, "💰" .. number(quest.gold or 0) .. "  ⭐" .. number(quest.xp or 0), {Position = UDim2.new(1, -146, 0, 10), Size = UDim2.fromOffset(134, 26), TextSize = 15, Font = UI.Fonts.display, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right})
				local claim = UI.button(card, quest.claimed and T("Resgatado ✓", "Claimed ✓") or T("Resgatar recompensa", "Claim reward"), function() act("ClaimQuest", {questId = id}) end, {Position = UDim2.new(1, -146, 0, 50), Size = UDim2.fromOffset(134, 58), BackgroundColor3 = ready and C.green or C.card, TextSize = 14})
				if quest.claimed or progress < (quest.target or 1) then UI.disabled(claim) end
			end
		end
		local now = os.time()
		-- The day's set is replaced at the next UTC midnight, two days before it expires.
		local dailyAt = (newest.daily or 0) - 2 * 86400
		if newest.daily then UI.label(body, T("Novas missões em ", "New missions in ") .. timeLeft(dailyAt - now) .. T("  •  semanais em ", "  •  weekly ones in ") .. timeLeft((newest.weekly or now) - now), {Name = "QuestReset", Size = UDim2.new(1, -6, 0, 24), TextSize = 13, TextColor3 = C.muted}) end
		drawGroup(groups.daily, T("MISSÕES DE HOJE", "TODAY'S MISSIONS"), nil)
		drawGroup(groups.weekly, T("MISSÕES DA SEMANA", "THIS WEEK'S MISSIONS"), nil)
		drawGroup(groups.old, T("AINDA PARA RESGATAR", "STILL TO CLAIM"), nil)
		if total == 0 then UI.label(body, T("Conclua o treinamento para iniciar suas missões.", "Complete training to begin your missions."), {Size = UDim2.new(1, -6, 0, 40), TextWrapped = true, TextColor3 = C.muted}) end
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

	local function loadBoard()
		local maps=Rules.MapsForMode(board.mode)
		if not table.find(maps,board.map) then board.map=maps[1] end
		board.failed = false
		local function refresh() if ctx.contextPanel() and ctx.contextPanel().kind == "leaderboard" then renderContext() end end
		act("Leaderboard", {mapId = board.map, size = board.size, modeId=board.mode}, function(data) board.data = data; refresh() end,
			function() board.failed = true; refresh() end)
	end

	local function contextLeaderboard(body)
		local maps=Rules.MapsForMode(board.mode)
		if not table.find(maps,board.map) then board.map=maps[1] end
	 board.mode="ranked"
	 if board.mode=="ranked" then
	  local rank=Rules.RankForWaves(board.data and board.data.personal or 0)
	  UI.section(body,T("SEU RANK: ","YOUR RANK: ")..(ctx.language()=="en" and rank.en or rank.pt),T("Bronze 10 • Prata 20 • Ouro 30 • Diamante 40 • Lenda 50 ondas","Bronze 10 • Silver 20 • Gold 30 • Diamond 40 • Legend 50 waves"))
	 end
		UI.section(body, T("Lendas da resistência", "Legends of the resistance"), T("Evolução real da conta • temporadas de 60 dias.", "Real account progression • 60-day seasons."))
		local controls = UI.row(body, 46)
		UI.secondary(controls, mapName(board.map), function()
			local index = table.find(maps, board.map) or 1
			board.map = maps[index % #maps + 1]
			board.data = nil; renderContext(); loadBoard()
		end, {Size = UDim2.new(0.6, -6, 0, 40), TextSize = 12})
		UI.secondary(controls, tostring(board.size) .. T(" jogador(es)", " player(s)"), function() board.size = board.size % 4 + 1; board.data = nil; renderContext(); loadBoard() end, {Position = UDim2.new(0.6, 4, 0, 0), Size = UDim2.new(0.4, -4, 0, 40), TextSize = 12})
		local row = UI.roundFrame(body, {Size = UDim2.new(1, -6, 0, 66), BackgroundColor3 = C.card})
		heading(row, T("Sua melhor marca: ", "Your personal best: ") .. tostring(board.data and board.data.personal or 0) .. T(" ondas", " waves"), 10, C.green)
		smallText(row, T("Temporada ", "Season ") .. tostring(board.data and board.data.season or profile().season or 1), 38, 22)
		if board.data and board.data.rows then
			for _, entry in ipairs(board.data.rows) do
				local entryRow = UI.roundFrame(body, {Size = UDim2.new(1, -6, 0, 56), BackgroundColor3 = entry.userId == player.UserId and Color3.fromRGB(24, 54, 49) or C.card})
				UI.label(entryRow, "#" .. tostring(entry.rank), {Position = UDim2.fromOffset(12, 10), Size = UDim2.fromOffset(49, 30), Font = Enum.Font.GothamBold, TextColor3 = C.gold})
				local tier=Rules.RankForWaves(entry.waves)
				local title=(entry.name or tostring(entry.userId))..(board.mode=="ranked" and ("\n"..(ctx.language()=="en" and tier.en or tier.pt)) or "")
				UI.label(entryRow, title, {Position = UDim2.fromOffset(65, 6), Size = UDim2.new(1, -145, 0, 42), TextSize = 12, TextWrapped=true})
				UI.label(entryRow, tostring(entry.waves), {Position = UDim2.new(1, -72, 0, 10), Size = UDim2.fromOffset(58, 30), TextXAlignment = Enum.TextXAlignment.Right, Font = Enum.Font.GothamBold, TextColor3 = C.green})
			end
			if #board.data.rows == 0 then UI.label(body, T("Seja o primeiro a deixar sua marca neste setor.", "Be the first to set a record in this sector."), {Size = UDim2.new(1, -6, 0, 50), TextWrapped = true, TextColor3 = C.muted}) end
		elseif board.failed then
			-- Failure is a state with a way out, not an endless "loading".
			UI.label(body, T("Não foi possível carregar o placar agora.", "The leaderboard could not be loaded right now."), {Name = "BoardFailed", Size = UDim2.new(1, -6, 0, 40), TextWrapped = true, TextColor3 = C.red})
			UI.button(body, T("TENTAR NOVAMENTE", "TRY AGAIN"), function() board.data = nil; loadBoard(); renderContext() end, {Name = "BoardRetry", Size = UDim2.new(1, -6, 0, 48), BackgroundColor3 = C.gold, TextSize = 14})
		else UI.label(body, T("Carregando placar…", "Loading leaderboard…"), {TextColor3 = C.muted}) end
		UI.secondary(body, T("Atualizar placar", "Refresh leaderboard"), loadBoard, {Size = UDim2.new(1, -6, 0, 40)})
	end

	-- Four small loops around the main game, all decided by the server's clock:
	-- a free chest on a timer, a daily login streak, gifts for time played today
	-- and one-time milestones for the collection. Nothing here can be bought.
	local lastRewardResult
	local function rewardGiven(paid)
		if type(paid) ~= "table" then return end
		-- A season claim can open several chests: the last (the best) is the one shown.
		local opened = type(paid.chests) == "table" and #paid.chests or 0
		if opened > 0 then paid.chest = paid.chests[opened] end
		local parts = {}
		if paid.gold and paid.gold > 0 then table.insert(parts, "+" .. number(paid.gold) .. T(" Ouro", " Gold")) end
		if paid.xp and paid.xp > 0 then table.insert(parts, "+" .. number(paid.xp) .. " XP") end
		if paid.chest then
			local hero = Catalog.Heroes[paid.chest.heroId]
			table.insert(parts, paid.chest.duplicate and T("herói repetido → recompensa", "duplicate hero → reward") or (T("novo herói: ", "new hero: ") .. (hero and L(hero.name) or paid.chest.heroId)))
		end
		if opened > 1 then table.insert(parts, "+" .. (opened - 1) .. T(" baús abertos", " more chests opened")) end
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
		if lastRewardResult and lastRewardResult.chest then
			local r = lastRewardResult.chest
			local row = UI.roundFrame(body, {Name = "RewardChestResult", Size = UDim2.new(1, -6, 0, 100), BackgroundColor3 = C.card}, UI.color(Catalog.Rarities[r.rarity].color))
			heroPortrait(row, r.heroId, {Position = UDim2.fromOffset(4, 4), Size = UDim2.fromOffset(72, 92)})
			UI.label(row, heroName(r.heroId), {Position = UDim2.fromOffset(84, 10), Size = UDim2.new(1, -96, 0, 30), Font = Enum.Font.GothamBlack, TextSize = 16, TextWrapped = true})
			UI.label(row, r.duplicate and T("Repetido: virou Ouro e maestria", "Duplicate: turned into Gold and mastery") or T("NOVO HERÓI!", "NEW HERO!"), {Position = UDim2.fromOffset(84, 44), Size = UDim2.new(1, -96, 0, 40), TextSize = 12, TextWrapped = true, TextColor3 = C.gold})
		end

		-- Free chest: opens on the spot, then makes you wait.
		local chest = rewards.freeChest
		local freeCard = UI.roundFrame(body, {Name = "FreeChestCard", Size = UDim2.new(1, -6, 0, 104), BackgroundColor3 = chest.ready and C.gold:Lerp(C.panel, 0.55) or C.card}, chest.ready and C.gold or C.stroke)
		UI.illustration(freeCard, "crate", chest.ready and C.gold or C.muted, {Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(92, 82)})
		UI.label(freeCard, T("BAÚ GRÁTIS", "FREE CHEST"), {Position = UDim2.fromOffset(112, 14), Size = UDim2.new(1, -250, 0, 32), Font = UI.Fonts.display, TextSize = 24})
		UI.label(freeCard, chest.ready and T("Pronto para abrir!", "Ready to open!") or (T("Volta em ", "Back in ") .. math.floor(chest.remaining / 3600) .. "h " .. math.floor((chest.remaining % 3600) / 60) .. "m"), {Position = UDim2.fromOffset(112, 50), Size = UDim2.new(1, -250, 0, 26), TextSize = 16, Font = UI.Fonts.display, TextColor3 = chest.ready and C.cream or C.muted})
		local claimFree = UI.button(freeCard, T("ABRIR!", "OPEN!"), function()
			act("ClaimFreeChest", {}, function(snapshot) rewardGiven(snapshot.result) end)
		end, {Name = "ClaimFreeChest", Position = UDim2.new(1, -130, 0.5, -28), Size = UDim2.fromOffset(118, 56), BackgroundColor3 = C.green, TextSize = 20})
		if not chest.ready then UI.disabled(claimFree) end

		-- Season pass: thirty levels from the XP of matches and missions. The free
		-- track pays everyone; the premium track pays the owner of the season pass.
		local season = profile().seasonStatus
		if season then
			local theme = season.theme and (" • " .. L(season.theme.name)) or ""
			UI.section(body, T("TEMPORADA ", "SEASON ") .. tostring(season.id or "") .. theme, T("Nível ", "Level ") .. season.level .. "/" .. season.maxLevel
				.. (season.endsAt and (T("  •  termina em ", "  •  ends in ") .. math.max(0, math.ceil((season.endsAt - os.time()) / 86400)) .. T(" dias", " days")) or ""))
			local seasonCard = UI.roundFrame(body, {Name = "SeasonCard", Size = UDim2.new(1, -6, 0, season.owned and 196 or 252), BackgroundColor3 = C.card}, season.claimable > 0 and C.gold or C.stroke)
			local xpFill = UI.bar(seasonCard, C.violet, UDim2.fromOffset(12, 12), UDim2.new(1, -24, 0, 16))
			xpFill.Size = UDim2.fromScale(math.clamp(season.xpInto / season.xpNeed, 0, 1), 1)
			UI.label(seasonCard, season.level >= season.maxLevel and T("Temporada completa!", "Season complete!") or (number(season.xpInto) .. " / " .. number(season.xpNeed) .. T(" XP para o próximo nível", " XP to the next level")),
				{Name = "SeasonXp", Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 20), TextSize = 13, TextColor3 = C.muted})
			local shown = math.min(#season.upcoming, 5)
			for index = 1, shown do
				local entry = season.upcoming[index]
				local cell = UI.roundFrame(seasonCard, {Name = "SeasonLevel_" .. entry.level, Position = UDim2.new((index - 1) / shown, 6, 0, 58), Size = UDim2.new(1 / shown, -3, 0, 92),
					BackgroundColor3 = entry.reached and C.gold:Lerp(C.card, 0.8) or C.background}, entry.reached and C.gold or C.stroke)
				local function line(y, text, tint) UI.label(cell, text, {Position = UDim2.fromOffset(0, y), Size = UDim2.new(1, 0, 0, 20), TextSize = 14, Font = UI.Fonts.display, TextColor3 = tint, TextXAlignment = Enum.TextXAlignment.Center}) end
				line(4, T("NV ", "LV ") .. entry.level, entry.reached and C.gold or C.muted)
				line(26, (entry.freeClaimed and "✓" or "💰") .. (entry.freeClaimed and "" or number(entry.free.gold)), entry.freeClaimed and C.green or C.text)
				local premiumText = (entry.premiumClaimed and "✓") or ((season.owned and "💎" or "🔒") .. number(entry.premium.gold))
				line(48, premiumText, entry.premiumClaimed and C.green or (season.owned and C.cream or C.muted))
				local marks = (entry.free.chest and "🎁" or "") .. (entry.premium.chest and "🎁" or "") .. (entry.premium.title and "🏆" or "")
				if marks ~= "" then line(68, marks, C.pink) end
			end
			local claimSeason = UI.button(seasonCard, season.claimable > 0 and (T("RESGATAR ", "CLAIM ") .. season.claimable .. T(" PRÊMIO(S)", " REWARD(S)")) or T("Jogue para subir de nível", "Play to level up"), function()
				act("ClaimSeason", {}, function(snapshot)
					local paid = snapshot and snapshot.result
					rewardGiven(paid)
					-- With chests, the reveal is the celebration; without, a banner is.
					if type(paid) == "table" and not (paid.chests and #paid.chests > 0) then
						celebrate:Banner({pt = "TEMPORADA • NÍVEL " .. tostring(paid.level or ""), en = "SEASON • LEVEL " .. tostring(paid.level or "")},
							{pt = "+" .. number(paid.gold or 0) .. " Ouro", en = "+" .. number(paid.gold or 0) .. " Gold"}, C.violet, {cue = "upgrade", duration = 1.8})
					end
				end)
			end, {Name = "ClaimSeason", Position = UDim2.fromOffset(12, 158), Size = UDim2.new(1, -24, 0, 48), BackgroundColor3 = season.claimable > 0 and C.green or C.card, TextSize = 16})
			if season.claimable == 0 then UI.disabled(claimSeason) end
			if not season.owned then
				UI.button(seasonCard, T("LIBERAR TRILHA PREMIUM 💎", "UNLOCK THE PREMIUM TRACK 💎"), function() openContext("shop", {shopKind = "pass"}) end,
					{Name = "SeasonUnlock", Position = UDim2.fromOffset(12, 210), Size = UDim2.new(1, -24, 0, 36), BackgroundColor3 = C.violet, TextSize = 14})
			end
		end

		-- Login streak: a seven-day strip, the ready day highlighted.
		UI.section(body, T("PRÊMIO DE CADA DIA", "EVERY DAY'S PRIZE"))
		-- lastCompletedIndex is the slot most recently claimed (today's, if the
		-- streak already paid out today; otherwise yesterday's). Everything up to
		-- it is checked off, except the slot about to be claimed, which is next.
		local cycle = rewards.login.cycle
		local lastCompletedIndex = rewards.login.streak > 0 and (((rewards.login.streak - 1) % cycle) + 1) or 0
		local strip = UI.row(body, 92)
		for day = 1, cycle do
			local def = Catalog.Rewards.login[day]
			local isNext = rewards.login.claimable and day == rewards.login.nextIndex
			local done = not isNext and day <= lastCompletedIndex
			local cell = UI.roundFrame(strip, {Name = "LoginDay_" .. day, Position = UDim2.new((day - 1) / cycle, 2, 0, 0), Size = UDim2.new(1 / cycle, -4, 1, 0),
				BackgroundColor3 = isNext and C.gold:Lerp(C.card, 0.15) or C.card}, isNext and C.gold or C.stroke)
			UI.label(cell, T("DIA ", "DAY ") .. day, {Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 18), TextSize = 13, Font = UI.Fonts.display, TextColor3 = isNext and C.gold or C.muted, TextXAlignment = Enum.TextXAlignment.Center})
			if def.chest then UI.illustration(cell, "crate", C.pink, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(40, 36)})
			else UI.label(cell, "💰" .. number(def.gold), {Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 30), TextSize = 15, Font = UI.Fonts.display, TextColor3 = isNext and C.gold or C.text, TextXAlignment = Enum.TextXAlignment.Center}) end
			if done then UI.label(cell, "✓", {Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 24), TextSize = 22, Font = UI.Fonts.display, TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Center}) end
		end
		local claimLogin = UI.button(body, rewards.login.claimable and (T("RESGATAR DIA ", "CLAIM DAY ") .. rewards.login.nextIndex) or T("Volte amanhã", "Come back tomorrow"), function()
			act("ClaimLogin", {}, function(snapshot) rewardGiven(snapshot.result) end)
		end, {Name = "ClaimLogin", Size = UDim2.new(1, -6, 0, 52), BackgroundColor3 = C.gold, TextSize = 19})
		if not rewards.login.claimable then UI.disabled(claimLogin) end

		-- Playtime gifts: how long you have played today, in one bar with markers.
		UI.section(body, T("PRESENTES POR TEMPO DE JOGO", "GIFTS FOR PLAYING"))
		for _, gift in ipairs(rewards.playtime.gifts) do
			local card = UI.roundFrame(body, {Name = "PlaytimeGift_" .. gift.index, Size = UDim2.new(1, -6, 0, 60), BackgroundColor3 = C.card})
			local progress = math.clamp(rewards.playtime.seconds / (gift.minutes * 60), 0, 1)
			local fill = UI.bar(card, gift.claimed and C.muted or C.green, UDim2.fromOffset(12, 10), UDim2.new(1, -130, 0, 8))
			fill.Size = UDim2.fromScale(progress, 1)
			UI.label(card, "⏱ " .. gift.minutes .. " min", {Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -130, 0, 30), TextSize = 16, Font = UI.Fonts.display, TextColor3 = gift.ready and C.green or C.muted})
			local claim = UI.button(card, gift.claimed and T("RESGATADO", "CLAIMED") or (gift.chest and T("BAÚ", "CHEST") or ("+" .. number(gift.gold))), function()
				act("ClaimPlaytime", {index = gift.index}, function(snapshot) rewardGiven(snapshot.result) end)
			end, {Name = "ClaimPlaytime_" .. gift.index, Position = UDim2.new(1, -108, 0, 8), Size = UDim2.fromOffset(96, 44), BackgroundColor3 = gift.ready and C.green or C.card, TextSize = 15})
			if not gift.ready then UI.disabled(claim) end
		end

		-- Collection milestones: how many different heroes the account owns.
		UI.section(body, T("COLECIONE HERÓIS • ", "COLLECT HEROES • ") .. rewards.collection.owned .. "/" .. #Catalog.HeroOrder)
		for _, milestone in ipairs(rewards.collection.milestones) do
			local card = UI.roundFrame(body, {Name = "Milestone_" .. milestone.index, Size = UDim2.new(1, -6, 0, 60), BackgroundColor3 = C.card})
			UI.label(card, "🦸 " .. milestone.count .. T(" heróis", " heroes"), {Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -130, 0, 26), Font = UI.Fonts.display, TextSize = 17})
			local sub = "+" .. number(milestone.gold) .. T(" Ouro", " Gold") .. (milestone.title and T("  •  título", "  •  title") or "")
			UI.label(card, sub, {Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -130, 0, 22), TextSize = 14, Font = UI.Fonts.display, TextColor3 = C.gold})
			local claim = UI.button(card, milestone.claimed and T("RESGATADO", "CLAIMED") or T("RESGATAR", "CLAIM"), function()
				act("ClaimMilestone", {index = milestone.index}, function(snapshot) rewardGiven(snapshot.result) end)
			end, {Name = "ClaimMilestone_" .. milestone.index, Position = UDim2.new(1, -108, 0, 10), Size = UDim2.fromOffset(96, 40), BackgroundColor3 = milestone.ready and C.gold or C.card, TextSize = 12})
			if milestone.claimed or not milestone.ready then UI.disabled(claim) end
		end

		-- Codes, the group and friends: the ways a YouTuber, a Discord or a friend
		-- brings someone in. The server checks every code and the group membership.
		UI.section(body, T("CÓDIGOS", "CODES"))
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
			UI.label(groupCard, "+" .. number(group.gold or 0) .. T(" Ouro, uma vez", " Gold, once"), {Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -130, 0, 20), TextSize = 12, TextColor3 = C.muted})
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

	-- The team and the collection on one screen: five slots and the base on
	-- top (the leader crowned), then big hero cards. Tap a card to see the hero;
	-- the only filters are the owned/all tabs and one row of rarity chips.
	local function contextSquad(body)
		local p=profile()
		local screen=screenSize()
		local width=UI.contextLayout(screen.X,screen.Y).w-34
		local wide=width>=500
		local team=UI.row(body,wide and 104 or 190)
		local lineup=UI.frame(team,{Name="SquadSlots",Size=wide and UDim2.new(0.76,0,0,104) or UDim2.new(1,0,0,104),BackgroundTransparency=1})
		local base=Catalog.Bases[p.equippedBase or "outpost"] or Catalog.Bases.outpost
		local baseCard=UI.secondary(team,"",function() openContext("bases") end,{Name="OpenBases",Position=wide and UDim2.fromScale(0.77,0) or UDim2.fromOffset(0,110),Size=wide and UDim2.new(0.23,-6,0,104) or UDim2.new(1,-6,0,76),BackgroundColor3=C.green:Lerp(C.panel,0.55)})
		UI.basePortrait(baseCard,base,{Position=UDim2.fromOffset(8,8),Size=wide and UDim2.new(1,-16,0,50) or UDim2.fromOffset(64,56)})
		UI.label(baseCard,L(base.name),{Name="FormationBaseName",Position=wide and UDim2.fromOffset(6,60) or UDim2.fromOffset(80,6),Size=wide and UDim2.new(1,-12,0,38) or UDim2.new(1,-90,1,-12),TextWrapped=true,Font=UI.Fonts.display,TextSize=14,TextXAlignment=wide and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left})
		for slot=1,5 do
			local id=(p.loadout or {})[slot]
			local tile=UI.secondary(lineup,"",function()
				if slot==1 then kit.inventoryView.leaderPick=not kit.inventoryView.leaderPick; inventoryFilter="owned"; kit.inventoryView.rarity="all"; renderContext()
				elseif id and kit.inventoryView.leaderPick then makeLeader(id,function() kit.inventoryView.leaderPick=false; renderContext() end)
				elseif id then openContext("hero",{heroId=id}) else inventoryFilter="owned"; renderContext(); showToast(T("Toque num herói abaixo e depois em Adicionar à equipe.","Tap a hero below, then Equip hero.")) end
			end,{Name="SquadSlot_"..slot,Position=UDim2.new((slot-1)/5,0,0,0),Size=UDim2.new(0.2,-6,0,104),BackgroundColor3=slot==1 and C.gold:Lerp(C.panel,0.45) or C.card})
			if slot==1 then UI.stroke(tile,C.gold,3) end
			if id then heroPortrait(tile,id,{Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,1,-8)})
			else UI.label(tile,"+",{Size=UDim2.fromScale(1,1),TextSize=38,Font=UI.Fonts.display,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Center}) end
			UI.chip(tile,slot==1 and T("★ LÍDER","★ LEAD") or tostring(slot),slot==1 and C.gold or C.background,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-4),Size=UDim2.new(slot==1 and 0.9 or 0.4,0,0,20),TextSize=slot==1 and 11 or 13})
		end
		local leader=(p.loadout or {})[1]
		if kit.inventoryView.leaderPick then
			local pick=UI.roundFrame(body,{Name="LeaderPick",Size=UDim2.new(1,-6,0,56),BackgroundColor3=C.gold:Lerp(C.panel,0.6)},C.gold)
			UI.label(pick,T("Toque no herói que vai liderar","Tap the hero who will lead"),{Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-150,1,0),Font=UI.Fonts.display,TextSize=16,TextWrapped=true})
			UI.secondary(pick,T("CANCELAR","CANCEL"),function() kit.inventoryView.leaderPick=false; renderContext() end,{Name="CancelLeaderPick",AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-8,0.5,0),Size=UDim2.fromOffset(124,44),TextSize=15,BackgroundColor3=C.red})
		elseif leader then
			-- One line says what the leader does; the crowned slot does the rest.
			local power=UI.row(body,48)
			power.Name="LeaderPower"
			UI.label(power,T("★ PODER DO LÍDER: ","★ LEADER POWER: ")..L(Catalog.Abilities[Catalog.Heroes[leader].ability].name),{Size=UDim2.new(1,-150,1,0),Font=UI.Fonts.display,TextColor3=C.gold,TextSize=16,TextWrapped=true})
			UI.button(power,T("TROCAR LÍDER","CHANGE LEADER"),function()
				kit.inventoryView.leaderPick=true; inventoryFilter="owned"; kit.inventoryView.rarity="all"; renderContext()
			end,{Name="ChangeLeader",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,2),Size=UDim2.fromOffset(140,44),BackgroundColor3=C.gold,TextSize=15})
		end
		local owned=0
		for _,id in ipairs(Catalog.HeroOrder) do if (p.heroes or {})[id] then owned+=1 end end
		categoryTabs(body,"InventoryTabs",{{id="owned",label=T("MEUS HERÓIS • ","MY HEROES • ")..owned},{id="all",label=T("TODOS • ","ALL • ")..#Catalog.HeroOrder}},inventoryFilter,function(id) inventoryFilter=id; renderContext() end)
		-- Rarity chips: one tap narrows the cards, the active chip glows.
		local chips=UI.row(body,40)
		chips.Name="RarityChips"
		local options={"all"}
		for _,id in ipairs(Catalog.RarityOrder) do table.insert(options,id) end
		for index,id in ipairs(options) do
			local rarity=Catalog.Rarities[id]
			local tint=rarity and UI.color(rarity.color) or C.cream
			local active=kit.inventoryView.rarity==id
			local chip=UI.button(chips,rarity and Catalog.Upper(L(rarity.name)) or T("TODAS","ALL"),function() kit.inventoryView.rarity=id; renderContext() end,{
				Name="HeroRarity_"..id,Position=UDim2.new((index-1)/#options,0,0,0),Size=UDim2.new(1/#options,-5,0,38),TextSize=width<520 and 10 or 13,
				BackgroundColor3=active and tint or tint:Lerp(C.panel,0.7)})
			if active then UI.stroke(chip,Color3.new(1,1,1),3) end
		end
		local entries=UI.collectionEntries(Catalog,p,{query="",rarity=kit.inventoryView.rarity,sort="collection",ownership=inventoryFilter},ctx.language())
		local columns=math.max(2,math.min(4,math.floor((width+10)/150)))
		local cellW=(width-(columns-1)*10)/columns
		local cellH=math.floor(cellW*1.12)+36
		if #entries==0 then UI.section(body,T("NENHUM HERÓI AQUI","NO HEROES HERE"),T("Abra baús na INVOCAÇÃO para ganhar heróis.","Open chests at the SUMMON halls to get heroes.")) end
		local gallery=UI.frame(body,{Name="HeroGallery",Size=UDim2.new(1,-6,0,math.max(0,math.ceil(#entries/columns)*(cellH+10)-10)),BackgroundTransparency=1})
		for index,id in ipairs(entries) do
			local def=Catalog.Heroes[id]
			local mine=(p.heroes or {})[id]
			local rarity=Catalog.Rarities[def.rarity]
			local tint=UI.color(rarity.color)
			local slot=table.find(p.loadout or {},id)
			local card=UI.roundFrame(gallery,{Name="Collection_"..id,Position=UDim2.fromOffset(((index-1)%columns)*(cellW+10),math.floor((index-1)/columns)*(cellH+10)),Size=UDim2.fromOffset(cellW,cellH),BackgroundColor3=mine and tint:Lerp(C.panel,0.35) or C.background},id==leader and C.gold or tint)
			UI.candy(card)
			UI.portraitStage(card,tint,{Name="HeroArtwork",Position=UDim2.fromOffset(5,5),Size=UDim2.new(1,-10,1,-42)})
			heroPortrait(card,id,{Position=UDim2.fromOffset(5,5),Size=UDim2.new(1,-10,1,-42)})
			UI.chip(card,Catalog.Upper(L(rarity.name)),tint,{Position=UDim2.fromOffset(8,8),Size=UDim2.fromOffset(math.min(84,cellW-20),20),TextSize=12})
			if mine then UI.chip(card,T("NV ","LV ")..mine.level,C.violet,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,8),Size=UDim2.fromOffset(46,20),TextSize=12})
			else
				local shade=UI.frame(card,{Name="NotOwned",Position=UDim2.fromOffset(5,5),Size=UDim2.new(1,-10,1,-42),BackgroundColor3=C.ink,BackgroundTransparency=0.45})
				UI.corner(shade,12)
				UI.label(shade,"🔒",{Size=UDim2.fromScale(1,1),TextSize=30,TextXAlignment=Enum.TextXAlignment.Center})
			end
			if slot then UI.chip(card,slot==1 and "★" or tostring(slot),slot==1 and C.gold or C.green,{AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-8,1,-42),Size=UDim2.fromOffset(28,24),TextSize=15}) end
			-- Earned stars (one per duplicate) along the bottom of the artwork.
			local stars=mine and math.clamp(mine.stars or 0,0,Catalog.Stars.max) or 0
			if mine and mine.shiny then UI.label(card,"✨",{Name="CollectionShiny",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,30),Size=UDim2.fromOffset(28,24),TextSize=18,TextXAlignment=Enum.TextXAlignment.Right}) end
			if stars>0 then UI.label(card,string.rep("★",stars),{Name="CollectionStars",Position=UDim2.new(0,8,1,-64),Size=UDim2.new(0.6,0,0,20),TextSize=14,Font=UI.Fonts.display,TextColor3=C.gold}) end
			UI.label(card,heroName(id),{Name="HeroName",Position=UDim2.new(0,6,1,-36),Size=UDim2.new(1,-12,0,32),Font=UI.Fonts.display,TextSize=cellW<150 and 13 or 16,TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Center})
			UI.button(card,"",function()
				if kit.inventoryView.leaderPick and mine then makeLeader(id,function() kit.inventoryView.leaderPick=false; renderContext() end) else openContext("hero",{heroId=id}) end
			end,{Name="FormationHero_"..id,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=4})
		end
	end

	local function contextSettings(body)
	 UI.button(body,T("APRENDER A JOGAR • 12 ONDAS","LEARN TO PLAY • 12 WAVES"),startTraining,{Name="OptionalTutorial",Size=UDim2.new(1,-6,0,44)})
		UI.section(body, T("Seu jeito de jogar", "Your experience"), T("Acessibilidade e apresentação. As regras de combate são iguais para todos.", "Accessibility and presentation. Combat rules are the same for everyone."))
		local settings = profile().settings or {}
		local effectsOn = settings.effects
		if effectsOn == nil then effectsOn = settings.music ~= false end
		local options = {
			{title = T("Idioma", "Language"), value = ctx.language() == "pt" and "Português (Brasil)" or "English", key = "language", next = ctx.language() == "pt" and "en" or "pt"},
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

	local talentSelected, talentZoom = nil, 1
	local function contextTalents(body)
		local p = profile()
		local points = p.talentPoints or 0
		local ranks = p.talents or {}
		local overview = UI.roundFrame(body, {Name = "TalentOverview", Size = UDim2.new(1, -6, 0, 126), BackgroundColor3 = Color3.fromRGB(68,43,91)}, C.violet)
		UI.printTexture(overview,C.violet)
		UI.label(overview,T("CADA AVENTURA TE FAZ CRESCER!", "EVERY ADVENTURE HELPS YOU GROW!"),{Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,18),Font=Enum.Font.GothamBlack,TextColor3=C.gold,TextSize=12})
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
				-- A word a child can read (DANO, ALCANCE, ÍMÃ), not an abbreviation.
				local word = UI.label(map, def.short and L(def.short) or def.icon or "?", {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at.X, at.Y - 9), Size = UDim2.fromOffset(HEX - 14, 26), TextScaled = true, Font = UI.Fonts.display, TextColor3 = open and C.text or C.muted, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 4})
				UI.create("UITextSizeConstraint", {MaxTextSize = 20, MinTextSize = 9}, word)
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
			local unit = def.unit == "%" and "%" or (def.unit == "HP" and " HP" or (def.unit == "gold" and T(" Ouro", " Gold") or ""))
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
			UI.label(first,T("Aprenda em 12 ondas e ganhe 1.000 Ouro na primeira vitória.","Learn in 12 waves and earn 1,000 Gold on your first victory."),{Position=UDim2.fromOffset(14,46),Size=UDim2.new(1,-28,0,58),TextSize=13,TextWrapped=true})
			UI.button(first,T("JOGAR O TREINO • 12 ONDAS","PLAY TRAINING • 12 WAVES"),startTraining,{Name="FindTrainingPortal",Position=UDim2.fromOffset(12,112),Size=UDim2.new(1,-24,0,46),BackgroundColor3=C.gold,TextSize=14})
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
					expedition={T("EXPEDIÇÕES","EXPEDITIONS"),T("Campanhas mais longas nas ilhas: Selva de Cristal e Ponte Celeste na ilha oeste, a final, Cidadela do Tirano (70 ondas), na ilha leste.","Longer campaigns on the islands: Crystal Jungle and Sky Bridge on the west island, the finale, Tyrant's Citadel (70 waves), on the east island.")},
					arena={T("ARENA COMPETITIVA","COMPETITIVE ARENA"),T("Três portais vizinhos. Cada mapa tem seu placar e exige uma estratégia diferente.","Three neighboring portals. Each map has its own leaderboard and calls for a different strategy.")},
					special={T("TREINO E CARTAS","TRAINING & CARDS"),T("Na ilha norte: o treino de 12 ondas e o roguelike de cartas.","On the north island: the 12-wave training and the card roguelike.")},
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
			UI.label(card,allowed and L(map.description) or L(kit.modeLockHints[destination.modeId]),{Position=UDim2.fromOffset(118,81),Size=UDim2.new(1,-132,0,40),TextSize=12,TextWrapped=true,TextColor3=C.muted})
			local button=UI.button(card,allowed and T("ENCONTRAR PORTAL","FIND PORTAL") or T("AINDA BLOQUEADO","LOCKED FOR NOW"),function() routePreview.goPortal(id) end,{Name="FindPortal_"..id,Position=UDim2.fromOffset(12,126),Size=UDim2.new(1,-24,0,44),BackgroundColor3=allowed and C.green or tint,TextSize=17})
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
					board.mode="ranked"; board.map=destination.mapId; openContext("leaderboard",{})
				end,{Name="DestinationBoard_"..id,Position=UDim2.new(0.64,0,0,126),Size=UDim2.new(0.36,-12,0,44),TextSize=12})
			end
		end
		if profile().tutorialComplete then
			UI.secondary(body,T("TREINAR DE NOVO • 12 ONDAS","TRAIN AGAIN • 12 WAVES"),startTraining,{Size=UDim2.new(1,-6,0,44)})
		end
	end

	local function contextBases(body)
		categoryTabs(body,"BaseNavigation",{{id="inventory",label=T("HERÓIS","HEROES")},{id="bases",label=T("BASES","BASES")}},"bases",function(id) openContext(id) end)
		local activeId=profile().equippedBase or "outpost"
		local active=Catalog.Bases[activeId] or Catalog.Bases.outpost
		local activeStats=Rules.BaseStats(activeId,1)
		local summary=UI.roundFrame(body,{Name="ActiveBaseSummary",Size=UDim2.new(1,-6,0,146),BackgroundColor3=C.green:Lerp(C.panel,0.87)},C.green)
		UI.basePortrait(summary,active,{Position=UDim2.fromOffset(8,12),Size=UDim2.fromOffset(94,98)})
		UI.label(summary,T("BASE ATIVA","ACTIVE BASE").." • "..L(active.name),{Position=UDim2.fromOffset(110,8),Size=UDim2.new(1,-122,0,48),TextWrapped=true,TextSize=18,Font=UI.Fonts.display,TextColor3=C.green})
		UI.label(summary,T("Entra automaticamente na sua próxima partida.","Deploys automatically in your next match."),{Position=UDim2.fromOffset(110,59),Size=UDim2.new(1,-122,0,43),TextWrapped=true,TextSize=13})
		UI.label(summary,"+"..activeStats.income..T(" Ouro/onda • Melhore tocando na vida da base durante a partida."," Gold/wave • Upgrade by tapping the base HP during a match."),{Position=UDim2.fromOffset(12,108),Size=UDim2.new(1,-24,0,32),TextWrapped=true,TextSize=12})

		UI.button(body,T("IR À LOJA DE BASES","GO TO THE BASE SHOP"),function() routePreview.goShop("base_rare") end,{Size=UDim2.new(1,-6,0,44),BackgroundColor3=C.gold,TextSize=13})
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
			local button=UI.button(row,equipped and T("BASE ATIVA","ACTIVE BASE") or owned and T("ATIVAR BASE","ACTIVATE BASE") or T("ENCONTRAR NOS BAÚS","FIND IN CHESTS"),function()
				if owned then act("EquipBase",{baseId=id},function() showToast(T("Base ativada! Ela aparecerá na próxima partida.","Base activated! It will deploy in your next match.")) end) else routePreview.goShop("base_rare") end
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
			nextHint=T("Aprenda a defender em "..Catalog.Modes.tutorial.waves.." ondas. A primeira vitória no treino dá "..number(Catalog.Chests.rare.cost).." Ouro.","Learn to defend in "..Catalog.Modes.tutorial.waves.." waves. Your first training victory grants "..number(Catalog.Chests.rare.cost).." Gold.")
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
			{"shopWay",T("Loja","Shop"),T("Baús de heróis e bases: ande até o Mercado","Hero and base chests: walk to the Market"),"chest",C.gold},
			{"rewards",T("Prêmios","Gifts"),T("Baú grátis, presentes e passe de temporada","Free chest, gifts and the season pass"),"gift",C.pink},
			{"quests",T("Missões","Missions"),T("Objetivos e conquistas","Goals and achievements"),"star",C.coral},
			{"leaderboard",T("Placares","Leaderboards"),T("Ranks e recordes","Ranks and records"),"trophy",C.gold},
			{"settings",T("Opções","Settings"),T("Idioma, som e controles","Language, sound and controls"),"bolt",C.cream},
		}
		local columns=screenSize().X<400 and 1 or 2
		local grid=UI.frame(body,{Name="RefugeDirectory",Size=UDim2.new(1,-6,0,math.ceil(#links/columns)*106),BackgroundTransparency=1})
		for i,entry in ipairs(links) do
			local tile=UI.button(grid,"",function() if entry[1]=="shopWay" then routePreview.goShop() else openContext(entry[1],{}) end end,{Name="GuideLink_"..entry[1],Position=UDim2.new(((i-1)%columns)/columns,0,0,math.floor((i-1)/columns)*106),Size=UDim2.new(1/columns,-6,0,98),BackgroundColor3=C.card})
			UI.illustration(tile,entry[4],entry[5],{Position=UDim2.fromOffset(10,12),Size=UDim2.fromOffset(38,38)})
			UI.label(tile,entry[2],{Position=UDim2.fromOffset(57,10),Size=UDim2.new(1,-67,0,40),TextSize=15,Font=Enum.Font.GothamBold,TextWrapped=true,TextColor3=entry[5]})
			UI.label(tile,entry[3],{Position=UDim2.fromOffset(12,55),Size=UDim2.new(1,-24,0,33),TextSize=12,TextWrapped=true,TextColor3=C.muted})
		end
		UI.section(body,T("AS ILHAS DO REFÚGIO","THE REFUGE ISLANDS"),T("Três pontes levam às ilhas dos portais. A Agência guarda os cantos da praça.","Three bridges lead to the portal islands. The Agency guards the plaza's corners."))
		for _,place in ipairs({
			{T("ACADEMIA DO BOSQUE","WOODLAND ACADEMY"),T("Ponte norte, atrás da árvore: TREINO e CARTAS, o campo de treino, cabanas e o poço.","North bridge, beyond the tree: TRAINING and CARDS, the training yard, cottages and the well."),"heart",C.green},
			{T("POSTO DE EXPEDIÇÕES","EXPEDITION OUTPOST"),T("Ponte oeste: os portais de SELVA e PONTE CELESTE e o mirante.","West bridge: the JUNGLE and SKY BRIDGE portals and the lookout."),"star",C.gold},
			{T("VIGIA DA CIDADELA","CITADEL WATCH"),T("Ponte leste: o portal da CIDADELA DO TIRANO e o observatório.","East bridge: the LATVERIAN FORTRESS portal and the observatory."),"star",C.violet},
			{T("AGÊNCIA","The Agency"),T("Nos cantos da praça: o jato no hangar, o posto de comando e o arsenal. Olhe para o céu: o porta-aviões voador!","In the plaza's corners: the jet's hangar, the command post and the armory. Look up: the flying carrier!"),"bolt",C.blue},
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

	return { contextBuilders = contextBuilders, loadBoard = loadBoard }
end

return Panels
