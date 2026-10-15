-- The lobby's context panels: heroes, squad, chests, shop, quests, rewards,
-- leaderboard, talents, modes, bases and settings. They used to
-- live in init.client, which ran into Luau's 200-register limit; the
-- controller builds them once with everything they use in `ctx` (values that
-- change, like the state snapshot, through accessor functions) and keeps the
-- state it shares with them (selected chest, hero tab, inventory view) in
-- `kit`. Purely presentation: every action is a request the server decides.
local Motion = require(script.Parent:WaitForChild("Motion"))
local TalentViewport = require(script.Parent:WaitForChild("TalentViewport"))
local Exchange = require(script.Parent:WaitForChild("Exchange"))

local Panels = {}

function Panels.new(ctx)
	local C, Catalog, Config, L, MarketplaceService, Rules, T, UI, act, at, audio, board = ctx.C, ctx.Catalog, ctx.Config, ctx.L, ctx.MarketplaceService, ctx.Rules, ctx.T, ctx.UI, ctx.act, ctx.at, ctx.audio, ctx.board
	local celebrate, contains, copy, heading, heroName, heroPortrait, kit, levelProgress, mapName, number, pending, player = ctx.celebrate, ctx.contains, ctx.copy, ctx.heading, ctx.heroName, ctx.heroPortrait, ctx.kit, ctx.levelProgress, ctx.mapName, ctx.number, ctx.pending, ctx.player
	local productInfo, profile, request, routePreview, screenSize, showToast, smallText = ctx.productInfo, ctx.profile, ctx.request, ctx.routePreview, ctx.screenSize, ctx.showToast, ctx.smallText
	local openContext, renderContext, fetchProducts, closeContext = ctx.openContext, ctx.renderContext, ctx.fetchProducts, ctx.closeContext
	-- Hero picks from bundles and friend trading draw in their own module.
	local exchange = Exchange.new(ctx)
	local heroPicksLeft = exchange.heroPicksLeft
	local rewardGiven
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
		ranked = {pt = "Complete o treino.", en = "Finish training."},
		cards = {pt = "Vença um mapa da campanha ou jogue " .. Rules.CardsAfterWaves .. " ondas.", en = "Win a campaign map or play " .. Rules.CardsAfterWaves .. " waves."},
		tutorial = {pt = "Sempre disponível.", en = "Always available."},
	}

	local function makeLeader(id,callback)
		local list=copy(profile().loadout)
		local old=table.find(list,id)
		if old then table.remove(list,old) elseif #list>=5 then table.remove(list,5) end
		table.insert(list,1,id)
		act("SetLoadout",{heroes=list},callback)
	end

	-- How a hero is now for this commander: level-one tower stats with mastery,
	-- stars, cards and talents applied (what it will really do when placed).
	local function heroNow(id)
		local p = profile()
		local mods = (p.heroes or {})[id] and Rules.PermanentModifiers(p, id) or {}
		local ok, stats = pcall(Rules.TowerStats, id, 1, nil, mods)
		if not ok then
			local def = Catalog.Heroes[id]
			stats = { damage = def.damage, range = def.range, interval = def.interval, slow = def.slow or 0 }
		end
		return stats
	end
	local function fmt(value)
		value = tonumber(value) or 0
		if math.abs(value - math.floor(value + 0.5)) < 0.05 then return tostring(math.floor(value + 0.5)) end
		return string.format("%.1f", value)
	end
	-- The tooltip every hero shows on hover (collection, team, hotbar, summon odds).
	local function heroTooltip(box, id)
		local def = Catalog.Heroes[id]
		if not def then return end
		local p = profile()
		local mine = (p.heroes or {})[id]
		local rarity = Catalog.Rarities[def.rarity]
		local tint = UI.color(rarity.color)
		local stats = heroNow(id)
		UI.tooltipTitle(box, L(def.name), tint:Lerp(Color3.new(1, 1, 1), 0.25))
		local status = L(rarity.name)
		if mine then status ..= T("  •  Maestria ", "  •  Mastery ") .. tostring(mine.level or 1) .. T("  •  Carta nv ", "  •  Card lv ") .. tostring(mine.rank or 1) else status ..= T("  •  Você ainda não tem", "  •  Not owned yet") end
		UI.tooltipLine(box, status, C.muted, 2, 15)
		local perSecond = (stats.interval or 0) > 0 and 1 / stats.interval or 0
		UI.tooltipLine(box, T("Dano ", "Damage ") .. '<font color="#FFFFFF"><b>' .. fmt(stats.damage) .. "</b></font>   " .. T("Alcance ", "Range ") .. '<font color="#FFFFFF"><b>' .. fmt(stats.range) .. "</b></font>   "
			.. T("Ataques/s ", "Hits/s ") .. '<font color="#FFFFFF"><b>' .. string.format("%.1f", perSecond) .. "</b></font>", C.muted, 3, 17)
		UI.tooltipLine(box, def.air and T("Acerta inimigos no chão e voando", "Hits ground and flying enemies") or T("Acerta só inimigos no chão", "Hits ground enemies only"), def.air and C.green or C.coral, 4, 15)
		for index, trait in ipairs(UI.heroTraits(def, T, stats.slow)) do UI.tooltipLine(box, "• " .. trait, C.cream, 4 + index, 15) end
		local ability = def.ability and Catalog.Abilities[def.ability]
		if ability then UI.tooltipLine(box, T("Poder de líder: ", "Leader power: ") .. L(ability.name), C.gold, 20, 15) end
		UI.tooltipLine(box, number(def.cost) .. T(" Ouro para colocar na partida", " Gold to place in battle"), C.gold:Lerp(C.text, 0.3), 21, 14)
	end
	kit.heroTooltip = heroTooltip

	-- A collection tile like the big games' inventories: the hero on its rarity
	-- colour, its stars on a gold badge and its level, nothing else to read.
	local function heroTile(parent, id, properties, onClick)
		local p = profile()
		local def = Catalog.Heroes[id]
		local mine = (p.heroes or {})[id]
		local tint = UI.color(Catalog.Rarities[def.rarity].color)
		local tile = UI.frame(parent, {BackgroundColor3 = mine and tint or tint:Lerp(C.ink, 0.55)})
		for key, value in pairs(properties or {}) do tile[key] = value end
		UI.corner(tile, 14)
		UI.stroke(tile, C.ink, 3)
		UI.cardSkin(tile,mine and tint or tint:Lerp(C.ink,0.55))
		heroPortrait(tile, id, {Position = UDim2.fromOffset(4, 4), Size = UDim2.new(1, -8, 1, -8)})
		if not mine then
			local shade = UI.frame(tile, {Name = "NotOwned", Size = UDim2.fromScale(1, 1), BackgroundColor3 = C.ink, BackgroundTransparency = 0.5})
			UI.corner(shade, 14)
			UI.icon(shade, "lock", C.cream, {AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.45), Size = UDim2.fromOffset(30, 30)})
		end
		return tile, mine, tint
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
		-- On a short screen the actions come right under a smaller showcase: the
		-- panel opens on what you can do, and the numbers wait below.
		local short = UI.sizeClass(screenSize().X, screenSize().Y).short
		local narrowInfo = not short and screenSize().X < 600
		local showcase = UI.row(body, short and 140 or 236)
		UI.portraitStage(showcase,tint,{Name="HeroStage",Size=UDim2.new(0.42,0,1,0)})
		-- The hero is alive on its stage: it breathes, shows its move every few
		-- seconds and again whenever the portrait is tapped. Reduced effects keeps
		-- the still picture.
		local portraitProperties={Position=UDim2.fromOffset(4,4),Size=UDim2.new(0.42,-8,1,-8),FullFigure=true}
		local settings=profile().settings or {}
		local live=ctx.livePortrait and settings.lowFX~=true and ctx.livePortrait(showcase,id,portraitProperties)
		if live and Motion.Prepare(live) then
			live.frame.Name="HeroLive"
			ctx.registerShowcase(live)
			UI.button(showcase,"",function()
				live.taps=(live.taps or 0)+1
				live.tapAt=os.clock()-(live.born or os.clock())
			end,{Name="HeroLiveTap",Position=portraitProperties.Position,Size=portraitProperties.Size,BackgroundTransparency=1,ZIndex=20})
		else
			if live then live.frame:Destroy() end
			heroPortrait(showcase,id,portraitProperties)
		end
		local info=UI.frame(showcase,{Position=UDim2.new(0.42,12,0,0),Size=UDim2.new(0.58,-12,1,0),BackgroundTransparency=1})
		UI.pill(info,L(rarity.name),tint:Lerp(C.ink,0.2),{TextSize=16,Size=UDim2.fromOffset(0,28)})
		UI.fit(UI.label(info,((owned and owned.shiny) and "◆ " or "")..L(def.name),{Name="HeroTitle",Position=UDim2.fromOffset(0,32),Size=UDim2.new(1,0,0,short and 36 or 44),TextSize=short and 26 or 34,Font=UI.Fonts.display,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top}),14)
		if not short then UI.fit(UI.label(info,L(def.description),{Position=UDim2.fromOffset(0,80),Size=UDim2.new(1,0,0,62),TextSize=17,TextWrapped=true,TextColor3=C.muted,TextYAlignment=Enum.TextYAlignment.Top}),11) end
		local price=UI.chip(info,number(def.cost)..T(" Ouro na partida"," Gold in battle"),C.ink,{Name="HeroPrice",Position=UDim2.fromOffset(0,short and 72 or 150),Size=UDim2.new(1,0,0,30),TextSize=17,TextColor3=C.gold})
		UI.create("UISizeConstraint",{MaxSize=Vector2.new(230,30)},price)
		UI.fit(price,11)
		if owned then
			local stars=math.clamp(owned.stars or 0,0,Catalog.Stars.max)
			local rowY=short and 106 or 190
			UI.oneLine(UI.label(info,T("Maestria ","Mastery ")..owned.level.."/20",{Name="HeroMastery",Position=UDim2.fromOffset(0,rowY),Size=UDim2.new(narrowInfo and 1 or 0.5,0,0,24),TextSize=17,Font=UI.Fonts.display,TextColor3=C.violet:Lerp(Color3.new(1,1,1),0.25)}),11)
			if not short then UI.fit(UI.label(narrowInfo and body or info,T("Carta nv ","Card lv ")..(owned.rank or 1).."  •  "..(owned.copies or 0)..T(" cartas"," cards"),{Name="HeroCardSummary",Position=UDim2.fromOffset(narrowInfo and 0 or 238,153),Size=UDim2.new(1,narrowInfo and -6 or -238,0,26),TextSize=17,Font=UI.Fonts.display,TextColor3=C.green}),11) end
			UI.oneLine(UI.label(info,string.rep("★",stars)..string.rep("☆",Catalog.Stars.max-stars),{Name="HeroStars",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,0,0,narrowInfo and rowY+22 or rowY-2),Size=UDim2.new(narrowInfo and 1 or 0.5,0,0,28),TextSize=22,Font=UI.Fonts.display,TextColor3=C.gold,TextXAlignment=narrowInfo and Enum.TextXAlignment.Left or Enum.TextXAlignment.Right}),12)
		end
		local function drawActions()
			if owned then
				UI.button(body,(p.loadout or {})[1]==id and T("★ É o seu líder","★ Your leader") or T("★ Usar como líder","★ Make leader"),function()
					makeLeader(id)
				end,{Name="MakeLeader_"..id,Size=UDim2.new(1,-6,0,50),BackgroundColor3=C.gold,TextSize=18})
				UI.secondary(body,contains(p.loadout,id) and T("Tirar da equipe","Remove from team") or T("+ Colocar na equipe","+ Add to team"),function()
					local list=copy(p.loadout); local old=table.find(list,id)
					if old then table.remove(list,old) elseif #list<5 then table.insert(list,id) else showToast(T("A equipe tem 5 heróis. Tire um primeiro.","Team full. Remove a hero first."),true); return end
					act("SetLoadout",{heroes=list})
				end,{Size=UDim2.new(1,-6,0,46),TextSize=16,BackgroundColor3=contains(p.loadout,id) and C.card or C.green})
			else
				UI.button(body,T("Ganhe na invocação","Get it at the summon halls"),function() routePreview.goShop() end,{Size=UDim2.new(1,-6,0,50),BackgroundColor3=C.gold,TextSize=17})
				UI.secondary(body,T("Comprar com Robux","Buy with Robux"),function() openContext("premium",{hud=true,shopKind="hero",shopKey=id}) end,{Name="HeroBuyRobux",Size=UDim2.new(1,-6,0,44),TextSize=15})
			end
		end
		if short then drawActions() end
		-- Three numbers anyone can compare: hit, reach, speed.
		-- The three numbers as they are now for this commander (mastery, stars,
		-- card and talents included), big enough to compare at a glance.
		local stats=UI.row(body,92)
		local nowStats=heroNow(id)
		local perSecond=(nowStats.interval or 0)>0 and 1/nowStats.interval or 0
		for index,entry in ipairs({{"",T("Dano","Damage"),fmt(nowStats.damage)},{"",T("Alcance","Range"),fmt(nowStats.range)},{"",T("Ataques/s","Hits/s"),string.format("%.1f",perSecond)}}) do
			local card=UI.frame(stats,{Name="HeroStat_"..index,Position=UDim2.new((index-1)/3,0,0,0),Size=UDim2.new(1/3,-8,1,-4),BackgroundColor3=UI.Skin.slot})
			UI.corner(card,14)
			UI.stroke(card,tint,2.5)
			UI.label(card,entry[2],{Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,0,24),TextSize=18,Font=UI.Fonts.display,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Center})
			local value=UI.label(card,entry[3],{Position=UDim2.fromOffset(8,34),Size=UDim2.new(1,-16,0,46),TextSize=36,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center})
			UI.outline(value,3)
		end
		UI.label(body,def.air and T("Acerta inimigos no chão e voando","Hits ground and flying enemies") or T("Acerta só inimigos no chão","Hits ground enemies only"),{Name="HeroTargets",Size=UDim2.new(1,-6,0,28),TextColor3=def.air and C.green or C.coral,Font=UI.Fonts.display,TextSize=19,TextWrapped=true})
		-- What sets this hero apart from the rest, one line each.
		for _,trait in ipairs(UI.heroTraits(def,T,nowStats.slow)) do UI.label(body,"• "..trait,{Name="HeroTrait",Size=UDim2.new(1,-6,0,28),TextColor3=C.cream,Font=UI.Fonts.display,TextSize=18,TextWrapped=true}) end
		if not short then drawActions() end
		-- The hero's card: duplicates from chests are cards; cards and Gold raise
		-- its level with no top, and every level brings a point to put into
		-- damage, attack speed or range.
		if owned then
			local rank=owned.rank or 1
			local need=Rules.CardRankCost(rank)
			local copies=owned.copies or 0
			local alloc=owned.alloc or {damage=0,speed=0,range=0}
			local earned=Rules.CardPoints(rank)
			local spent=(alloc.damage or 0)+(alloc.speed or 0)+(alloc.range or 0)
			local free=earned-spent
			local ladder=UI.roundFrame(body,{Name="HeroCardLadder",Size=UDim2.new(1,-6,0,318),BackgroundColor3=UI.Skin.slot},tint)
			UI.label(ladder,T("Carta do herói","Hero card"),{Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-130,0,32),TextSize=26,Font=UI.Fonts.display,TextColor3=C.gold})
			UI.chip(ladder,T("Nível ","Level ")..rank,tint,{Name="HeroCardRank",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,10),Size=UDim2.fromOffset(104,30),TextSize=17})
			local fill=UI.bar(ladder,C.green,UDim2.fromOffset(12,48),UDim2.new(1,-24,0,22))
			fill.Size=UDim2.fromScale(math.clamp(copies/math.max(1,need.copies),0,1),1)
			UI.label(ladder,copies.." / "..need.copies..T(" cartas"," cards"),{Name="HeroCardCopies",Position=UDim2.fromOffset(12,48),Size=UDim2.new(1,-24,0,22),TextSize=16,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center})
			local can=copies>=need.copies and (p.gold or 0)>=need.gold
			local rankUp=UI.button(ladder,T("Evoluir carta • ","Level up card • ")..number(need.gold)..T(" Ouro"," Gold"),function()
				act("RankUpHero",{heroId=id,expectedRank=rank},function() audio:Cue("upgrade") end)
			end,{Name="RankUpHero_"..id,Position=UDim2.fromOffset(12,78),Size=UDim2.new(1,-24,0,52),BackgroundColor3=C.green,TextSize=19})
			if not can then UI.disabled(rankUp) end
			local missing=copies<need.copies and (T("Faltam ","You need ")..(need.copies-copies)..T(" cartas: repetidos dos baús viram cartas."," more cards: duplicates from chests become cards.")) or ((p.gold or 0)<need.gold and (T("Faltam ","You need ")..number(need.gold-(p.gold or 0))..T(" Ouro."," more Gold.")) or T("Pronto para evoluir!","Ready to level up!"))
			UI.label(ladder,missing,{Name="HeroCardHint",Position=UDim2.fromOffset(12,132),Size=UDim2.new(1,-24,0,22),TextSize=14,TextColor3=can and C.green or C.muted,TextWrapped=true})
			UI.label(ladder,T("Pontos para gastar: ","Points to spend: ")..free,{Name="HeroCardPoints",Position=UDim2.fromOffset(12,158),Size=UDim2.new(1,-24,0,28),TextSize=18,Font=UI.Fonts.display,TextColor3=free>0 and C.gold or C.muted})
			local bonus=Rules.CardBonus(rank,alloc)
			for index,entry in ipairs({{"damage",T("Dano","Damage"),"sword"},{"speed",T("Velocidade","Attack speed"),"bow"},{"range",T("Alcance","Range"),"ring"}}) do
				local y=190+(index-1)*42
				UI.icon(ladder,entry[3],C.cream,{Position=UDim2.fromOffset(12,y+3),Size=UDim2.fromOffset(32,32)})
				UI.label(ladder,entry[2],{Position=UDim2.fromOffset(52,y),Size=UDim2.new(0.34,0,0,38),TextSize=17,Font=UI.Fonts.display})
				UI.label(ladder,"+"..math.floor(bonus[entry[1]]*100+0.5).."%",{Name="HeroCardBonus_"..entry[1],Position=UDim2.new(0.38,0,0,y),Size=UDim2.new(0.2,0,0,38),TextSize=19,Font=UI.Fonts.display,TextColor3=C.green,TextXAlignment=Enum.TextXAlignment.Center})
				local function change(delta)
					local nextPoints={damage=alloc.damage or 0,speed=alloc.speed or 0,range=alloc.range or 0}
					nextPoints[entry[1]]=math.max(0,nextPoints[entry[1]]+delta)
					act("SetHeroPoints",{heroId=id,damage=nextPoints.damage,speed=nextPoints.speed,range=nextPoints.range})
				end
				local minus=UI.button(ladder,"-",function() change(-1) end,{Name="HeroPointMinus_"..entry[1],AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-96,0,y),Size=UDim2.fromOffset(44,38),BackgroundColor3=C.card,TextSize=24})
				UI.label(ladder,tostring(alloc[entry[1]] or 0),{Name="HeroPointValue_"..entry[1],AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-52,0,y),Size=UDim2.fromOffset(40,38),TextSize=20,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center})
				local plus=UI.button(ladder,"+",function() change(1) end,{Name="HeroPointPlus_"..entry[1],AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,y),Size=UDim2.fromOffset(44,38),BackgroundColor3=C.green,TextSize=24})
				if (alloc[entry[1]] or 0)<=0 then UI.disabled(minus) end
				if free<=0 then UI.disabled(plus) end
			end
		end
		local tabs=UI.row(body,50)
		for index,tab in ipairs({{id="power",label=T("Poder de líder","Leader power"),icon="star",color=C.gold},{id="defense",label=T("Especializações","Specializations"),icon="sword",color=C.blue}}) do
			UI.tab(tabs,tab.label,tab.color,tab.icon,kit.heroDetailTab==tab.id,function() kit.heroDetailTab=tab.id; renderContext() end,{Name="HeroDetail_"..tab.id,Position=UDim2.new((index-1)/2,0,0,0),Size=UDim2.new(0.5,-6,0,48),TextSize=19})
		end
		if kit.heroDetailTab=="defense" then
			-- The tower's two specializations, chosen at its last upgrade.
			for index,branch in ipairs(def.branches or {}) do
				local card=UI.roundFrame(body,{Name="HeroBranch_"..index,Size=UDim2.new(1,-6,0,96),BackgroundColor3=UI.Skin.slot},index==1 and C.green or C.blue)
				UI.label(card,tostring(index),{Position=UDim2.fromOffset(12,8),Size=UDim2.fromOffset(36,36),TextColor3=index==1 and C.green or C.blue,TextSize=34,Font=UI.Fonts.display})
				UI.label(card,L(branch.name),{Position=UDim2.fromOffset(54,8),Size=UDim2.new(1,-64,0,32),TextWrapped=true,TextSize=22,Font=UI.Fonts.display})
				UI.label(card,L(branch.description),{Position=UDim2.fromOffset(14,44),Size=UDim2.new(1,-28,0,46),TextWrapped=true,TextSize=16,TextColor3=C.cream})
			end
			return
		end
		-- The leader power: what it does now, its rank as pips, and the next rank.
		local ability=Catalog.Abilities[def.ability]
		local rank=(p.abilities or {})[id] or 1
		local power=UI.roundFrame(body,{Name="LeaderPowerCard",Size=UDim2.new(1,-6,0,132),BackgroundColor3=UI.Skin.slot},C.gold)
		UI.icon(power,"star",C.gold,{Position=UDim2.fromOffset(12,8),Size=UDim2.fromOffset(30,30)})
		UI.label(power,L(ability.name),{Position=UDim2.fromOffset(48,6),Size=UDim2.new(1,-150,0,34),TextSize=24,Font=UI.Fonts.display,TextColor3=C.gold})
		UI.chip(power,T("Rank ","Rank ")..rank.."/"..Catalog.AbilityRanks.max,C.gold:Lerp(C.ink,0.3),{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,8),Size=UDim2.fromOffset(100,30),TextSize=16})
		UI.label(power,Rules.AbilityText(ability,rank,ctx.language()),{Position=UDim2.fromOffset(12,44),Size=UDim2.new(1,-24,0,60),TextSize=16,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
		for level=1,Catalog.AbilityRanks.max do
			local pip=UI.frame(power,{Name="AbilityProgress_"..level,Position=UDim2.new((level-1)/Catalog.AbilityRanks.max,12,1,-20),Size=UDim2.new(1/Catalog.AbilityRanks.max,-16,0,10),BackgroundColor3=level<=rank and C.gold or C.background})
			UI.corner(pip,5)
		end
		if not owned then return end
		local offer=Rules.AbilityUpgrade(def,rank)
		if offer then
			local buy=UI.button(body,T("Subir para rank ","Upgrade to rank ")..(rank+1).." • "..number(offer.cost)..T(" Ouro"," Gold"),function()
				act("UpgradeAbility",{heroId=id,expectedRank=rank},function() audio:Cue("upgrade") end)
			end,{Name="UpgradeAbility_"..id,Size=UDim2.new(1,-6,0,50),BackgroundColor3=C.green,TextSize=17})
			if owned.level<offer.mastery or (p.gold or 0)<offer.cost then UI.disabled(buy) end
			if owned.level<offer.mastery then
				smallText(body,T("Precisa de maestria ","Needs mastery ")..offer.mastery..T(": jogue com este herói.",": play with this hero."),0,28)
			elseif (p.gold or 0)<offer.cost then
				smallText(body,T("Faltam ","You need ")..number(offer.cost-(p.gold or 0))..T(" Ouro."," more Gold."),0,28)
			end
		else
			UI.label(body,T("Poder no rank máximo!","Power at max rank!"),{Size=UDim2.new(1,-6,0,32),TextColor3=C.gold,Font=UI.Fonts.display,TextSize=18})
		end
	end

	-- Tabs like the reference shops: each its own colour and icon, the open one
	-- bright with a white rim, the others a shade darker.
	local TAB_COLORS={C.coral,C.blue,C.green,C.gold,C.violet,C.pink}
	local function categoryTabs(body, name, options, selected, onSelect)
		local row=UI.row(body,50)
		row.Name=name
		for index,option in ipairs(options) do
			UI.tab(row,option.label,option.color or TAB_COLORS[(index-1)%#TAB_COLORS+1],option.icon,selected==option.id,function() onSelect(option.id) end,{
				Name=name.."_"..option.id,Position=UDim2.new((index-1)/#options,0,0,0),
				Size=UDim2.new(1/#options,-8,0,48),TextSize=#options>3 and 16 or 19})
		end
	end

	local lastChestResult
	kit.selectedChest ="rare"
	local premiumCategory="hero"
	local inventoryFilter="owned"
	kit.inventoryView ={query="",rarity="all",role="all",sort="collection",leaderPick=false}
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
			UI.label(card,T("Você ganhou: ","You got: ")..L(catalog[id].name),{Position=UDim2.fromOffset(106,6),Size=UDim2.new(1,-116,0,30),TextSize=18,Font=UI.Fonts.display,TextWrapped=true})
			local message=r.duplicate and (T("Repetido: +","Duplicate: +")..number(r.refundGold)..T(" Ouro"," Gold")) or T("Novo na coleção!","New in your collection!")
			UI.label(card,message,{Position=UDim2.fromOffset(106,36),Size=UDim2.new(1,-116,0,20),TextSize=14,Font=UI.Fonts.display,TextColor3=color})
			local active=isBase and p.equippedBase==id
			local button=UI.button(card,active and T("Base ativa","Active base") or isBase and T("Ativar esta base","Activate this base") or T("Ver herói","View hero"),function()
				if isBase then act("EquipBase",{baseId=id},function() showToast(T("Base ativada para a próxima partida!","Base activated for your next match!")) end)
				else openContext("hero",{heroId=id}) end
			end,{Name="SummonEquipResult",Position=UDim2.fromOffset(106,60),Size=UDim2.new(1,-116,0,44),BackgroundColor3=C.green,TextSize=15})
			if active then UI.disabled(button) end
		end
		end

		-- The tiers: big chests you can see from across the room.
		-- A phone panel has room for the tiers and one buy row above the fold:
		-- shorter tiles and a single-row purchase card keep SUMMON visible.
		local tileH=wide and 94 or 92
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
				{Name="SummonSelect_"..id,Position=UDim2.fromOffset((i-1)*tileWidth+6,chosen and 6 or 8),Size=UDim2.fromOffset(tileWidth-12,tileH),BackgroundColor3=chosen and color:Lerp(UI.Skin.body,0.15) or color:Lerp(UI.Skin.body,0.7)})
			UI.stroke(tile,chosen and Color3.new(1,1,1) or C.ink,chosen and 3.5 or 2.5)
			UI.cardSkin(tile,chosen and color or color:Lerp(UI.Skin.body,0.55))
			UI.illustration(tile,"crate",color,{Rarity=id,AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,4),Size=wide and UDim2.fromOffset(64,38) or UDim2.fromOffset(46,40)})
			UI.oneLine(UI.label(tile,L(def.name),{Position=UDim2.fromOffset(4,wide and 41 or 44),Size=UDim2.new(1,-8,0,wide and 20 or 22),TextWrapped=false,TextSize=wide and 15 or 12,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center}),10)
			local price=UI.chip(tile,number(def.cost),C.ink,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-5),Size=UDim2.new(1,-18,0,wide and 24 or 22),TextSize=wide and 16 or 14,TextColor3=C.gold})
			price.Name="ChestPrice"
		end

		local outcomes,forced=Rules.ChestOutcomes(kit.selectedChest,(p.pity or {})[kit.selectedChest] or 0,owned)
		local purchaseParent, galleryParent=body,body
		local galleryHeight=254
		if wide then
			local stageHeight=math.max(300,math.min(460,slot.h-212))
			local stage=UI.frame(body,{Name="SummonStage",Size=UDim2.new(1,-6,0,stageHeight),BackgroundTransparency=1})
			galleryParent=UI.frame(stage,{Name="SummonPreview",Size=UDim2.new(0.58,-8,1,0),BackgroundTransparency=1})
			purchaseParent=UI.frame(stage,{Name="SummonActions",Position=UDim2.fromScale(0.59,0),Size=UDim2.new(0.41,0,1,0),BackgroundTransparency=1})
			UI.list(purchaseParent,8)
			galleryHeight=stageHeight-34
		end
		-- How many to open at once: from one to the most the Gold pays for.
		local maxCount=math.clamp(math.floor((p.gold or 0)/math.max(1,chest.cost)),1,Catalog.MaxChestsAtOnce)
		local count=math.clamp(kit.chestCount or 1,1,maxCount)
		kit.chestCount=count
		local eligible=(p.gold or 0)>=chest.cost*count and not p.paidRandomRestricted
		local color=UI.color(chest.color)
		local id=kit.selectedChest
		local confirming=kit.confirmChest==id
		local function openChest()
			if pending.OpenChest then return end
			pending.OpenChest=true; kit.confirmChest=nil; renderContext()
			local wanted=count
			task.spawn(function()
				local response=request("OpenChest",{chestId=id,count=wanted>1 and wanted or nil}); pending.OpenChest=nil
				if response and response.ok then
					lastChestResult=response.data and response.data.result
					if lastChestResult then
						-- Every chest gets its own reel, one after the other.
						celebrate:Reel(lastChestResult.batch or {lastChestResult},id,{fillers=outcomes})
					end
				end
				if ctx.contextPanel() and ctx.contextPanel().kind=="chests" then renderContext() end
			end)
		end
		local function setCount(value)
			kit.chestCount=math.clamp(value,1,maxCount); kit.confirmChest=nil; renderContext()
		end
		local function quantityRow(parent,y,rowH)
			local row=UI.frame(parent,{Name="ChestQuantity",Position=UDim2.fromOffset(10,y),Size=UDim2.new(1,-20,0,rowH),BackgroundTransparency=1})
			UI.button(row,"-",function() setCount(count-1) end,{Name="ChestCountMinus",Size=UDim2.new(0.18,-4,1,0),BackgroundColor3=C.card,TextSize=26})
			UI.label(row,"x"..count,{Name="ChestCount",Position=UDim2.fromScale(0.18,0),Size=UDim2.new(0.34,0,1,0),TextSize=26,Font=UI.Fonts.display,TextColor3=C.gold,TextXAlignment=Enum.TextXAlignment.Center})
			UI.button(row,"+",function() setCount(count+1) end,{Name="ChestCountPlus",Position=UDim2.fromScale(0.52,0),Size=UDim2.new(0.18,-4,1,0),BackgroundColor3=C.card,TextSize=26})
			UI.button(row,T("Máx ","Max ")..maxCount,function() setCount(maxCount) end,{Name="ChestCountMax",Position=UDim2.fromScale(0.7,0),Size=UDim2.new(0.3,0,1,0),BackgroundColor3=C.violet,TextSize=16})
			if maxCount<=1 then for _,item in ipairs(row:GetChildren()) do if item:IsA("TextButton") then UI.disabled(item) end end end
		end
		local priceText=count>1 and ("x"..count.." • "..number(chest.cost*count)..T(" Ouro"," Gold")) or (number(chest.cost)..T(" Ouro"," Gold"))
		if not wide then
			-- One row: chest, name and balance, then the action on the right.
			local purchase=UI.roundFrame(purchaseParent,{Name="SummonPurchase",Size=UDim2.new(1,-6,0,confirming and 74 or 128),BackgroundColor3=color:Lerp(C.panel,0.6)},color)
			if not confirming then quantityRow(purchase,76,42) end
			UI.illustration(purchase,"crate",color,{Rarity=id,Position=UDim2.fromOffset(6,8),Size=UDim2.fromOffset(62,56)})
			UI.oneLine(UI.label(purchase,Catalog.Upper(L(chest.name)),{Name="SummonChestName",Position=UDim2.fromOffset(74,8),Size=UDim2.new(0.5,-78,0,24),TextSize=16,Font=UI.Fonts.display}),9)
			UI.oneLine(UI.label(purchase,number(p.gold)..T(" Ouro"," Gold"),{Name="SummonBalance",Position=UDim2.fromOffset(74,32),Size=UDim2.new(0.5,-78,0,20),TextSize=14,Font=UI.Fonts.display,TextColor3=C.gold}),9)
			if chest.pity then
				local count=(p.pity or {})[id] or 0
				local fill=UI.bar(purchase,C.gold,UDim2.fromOffset(74,56),UDim2.new(0.5,-80,0,7))
				fill.Size=UDim2.fromScale(math.clamp(count/chest.pity.after,0,1),1)
			end
			if confirming then
				local confirm=UI.button(purchase,T("Confirmar!","Confirm!"),openChest,{Name="ConfirmChest_"..id,Position=UDim2.new(0.5,0,0,8),Size=UDim2.new(0.3,-6,0,58),BackgroundColor3=C.green,TextSize=16})
				if not eligible then UI.disabled(confirm) end
				UI.secondary(purchase,T("Voltar","Back"),function() kit.confirmChest=nil; renderContext() end,{Name="CancelChest",Position=UDim2.new(0.8,0,0,8),Size=UDim2.new(0.2,-8,0,58),TextSize=13})
			else
				local button=UI.button(purchase,pending.OpenChest and T("Invocando…","Summoning…") or T("Invocar\n","Summon\n")..priceText,function() kit.confirmChest=id; renderContext() end,
					{Name="OpenChest_"..id,Position=UDim2.new(0.5,0,0,8),Size=UDim2.new(0.5,-8,0,58),BackgroundColor3=C.green,TextSize=17})
				if not eligible or pending.OpenChest then UI.disabled(button) end
			end
		else
			-- Reserve the controls first; the illustration uses the remaining
			-- space, including in a short Studio viewport or laptop window.
			local purchaseH=math.min(394,galleryHeight+34)
			local artH=purchaseH-234
			local purchase=UI.roundFrame(purchaseParent,{Name="SummonPurchase",Size=UDim2.new(1,-6,0,confirming and purchaseH-40 or purchaseH),BackgroundColor3=color:Lerp(C.panel,0.6)},color)
			if not confirming then quantityRow(purchase,artH+98,46) end
			UI.illustration(purchase,"crate",color,{Rarity=id,AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,12),Size=UDim2.fromOffset(artH*1.125,artH)})
			UI.oneLine(UI.label(purchase,Catalog.Upper(L(chest.name)),{Position=UDim2.fromOffset(14,artH+14),Size=UDim2.new(1,-28,0,32),TextSize=25,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center}),15)
			UI.oneLine(UI.label(purchase,T("Você tem ","You have ")..number(p.gold)..T(" Ouro"," Gold"),{Name="SummonBalance",Position=UDim2.fromOffset(14,artH+48),Size=UDim2.new(1,-28,0,22),TextSize=15,Font=UI.Fonts.display,TextColor3=C.gold,TextXAlignment=Enum.TextXAlignment.Center}),11)
			if chest.pity then
				-- The guarantee as a bar that fills.
				local count=(p.pity or {})[id] or 0
				UI.label(purchase,forced and T("Garantia ativa!","Guarantee active!") or (T("Garantia ","Guarantee ")..count.."/"..chest.pity.after),{Name="SummonGuarantee",Position=UDim2.fromOffset(14,artH+72),Size=UDim2.new(1,-28,0,18),TextSize=12,Font=UI.Fonts.display,TextColor3=forced and C.gold or C.muted})
				local fill=UI.bar(purchase,C.gold,UDim2.fromOffset(14,artH+90),UDim2.new(1,-28,0,5))
				fill.Size=UDim2.fromScale(math.clamp(count/chest.pity.after,0,1),1)
			end
			if confirming then
				UI.label(purchase,(count>1 and ("x"..count.."  •  ") or "")..T("Sobra: ","Left: ")..number((p.gold or 0)-chest.cost*count)..T(" Ouro"," Gold"),{Position=UDim2.fromOffset(12,artH+98),Size=UDim2.new(1,-24,0,26),TextSize=15,Font=UI.Fonts.display})
				local confirm=UI.button(purchase,T("Confirmar!","Confirm!"),openChest,{Name="ConfirmChest_"..id,Position=UDim2.fromOffset(10,artH+130),Size=UDim2.new(0.6,-14,0,54),BackgroundColor3=C.green,TextSize=19})
				if not eligible then UI.disabled(confirm) end
				UI.secondary(purchase,T("Voltar","Back"),function() kit.confirmChest=nil; renderContext() end,{Name="CancelChest",Position=UDim2.new(0.6,0,0,artH+130),Size=UDim2.new(0.4,-10,0,54),TextSize=16})
			else
				local button=UI.button(purchase,pending.OpenChest and T("Invocando…","Summoning…") or T("Invocar • ","Summon • ")..priceText,function() kit.confirmChest=id; renderContext() end,
					{Name="OpenChest_"..id,Position=UDim2.fromOffset(10,artH+158),Size=UDim2.new(1,-20,0,64),BackgroundColor3=C.green,TextSize=22})
				if not eligible or pending.OpenChest then UI.disabled(button) end
			end
		end
		if not eligible and not p.paidRandomRestricted then
			smallText(purchaseParent,T("Faltam ","You need ")..number(chest.cost*count-(p.gold or 0))..T(" Ouro: jogue partidas e pegue os prêmios."," Gold: play matches and claim gifts."),0,36)
			-- Or buy the Gold: one tap to the Gold packs, the server still decides every price.
			local goldOnSale=false
			for key,def in pairs(Catalog.Products.Consumables) do if def.gold and not def.heroPicks and key~="starterPack" and kit.productConfigured("product",key) then goldOnSale=true end end
			if goldOnSale then UI.button(purchaseParent,T("Comprar Ouro com Robux","Buy Gold with Robux"),function() openContext("premium",{shopKind="product"}) end,{Name="BuyGoldShortcut",Size=UDim2.new(1,-6,0,46),BackgroundColor3=C.gold,TextSize=17}) end
		end

		-- A real roster showcase, separate from the complete odds list. These
		-- are available outcomes, never a promise that the player will win one.
		local featuredH=wide and math.min(210,math.floor(galleryHeight*0.58)) or 0
		if wide then
			local featured=UI.frame(galleryParent,{Name="SummonFeatured",Size=UDim2.new(1,-6,0,featuredH),BackgroundTransparency=1})
			local seen,chosen={},{}
			for index=#outcomes,1,-1 do
				local outcome=outcomes[index]
				if outcome.chance>0 and not seen[outcome.rarity] then seen[outcome.rarity]=true; table.insert(chosen,outcome) end
				if #chosen==3 then break end
			end
			for index,outcome in ipairs(chosen) do
				local tint=UI.color(Catalog.Rarities[outcome.rarity].color)
				local slot=UI.portraitStage(featured,tint,{Name="Featured_"..outcome.id,Position=UDim2.new((index-1)/#chosen,3,0,3),Size=UDim2.new(1/#chosen,-6,1,-6)})
				portrait(slot,outcome.id,{Position=UDim2.fromOffset(3,3),Size=UDim2.new(1,-6,1,-26)})
				UI.chip(slot,UI.percent(outcome.chance,ctx.language()),C.ink,{Name="FeaturedChance",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-4,0,4),Size=UDim2.fromOffset(54,22),TextSize=13,ZIndex=3})
				UI.fit(UI.label(slot,L(catalog[outcome.id].name),{Name="FeaturedName",AnchorPoint=Vector2.new(0,1),Position=UDim2.new(0,4,1,-2),Size=UDim2.new(1,-8,0,24),Font=UI.Fonts.display,TextSize=15,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=3}),10)
			end
		end
		local caption=UI.frame(galleryParent,{Name="SummonOddsCaption",Position=UDim2.fromOffset(0,featuredH),Size=UDim2.new(1,-6,0,30),BackgroundTransparency=1})
		UI.label(caption,forced and T("Destaques garantidos","Guaranteed features") or T("Pode vir neste baú","In this chest"),{Size=UDim2.new(1,0,1,0),TextSize=20,Font=UI.Fonts.display,TextColor3=C.cream})
		local cols=wide and 2 or math.max(2,math.floor(width/145))
		local pitch,tileH=wide and 64 or 128,wide and 56 or 116
		local gallery=UI.scroll(galleryParent,{Name="SummonOdds",Position=UDim2.fromOffset(0,32+featuredH),Size=UDim2.new(1,-6,0,galleryHeight-featuredH),AutomaticCanvasSize=Enum.AutomaticSize.None,CanvasSize=UDim2.fromOffset(0,math.ceil(#outcomes/cols)*pitch+6),ScrollBarThickness=5,ScrollBarImageColor3=tint})
		gallery:SetAttribute("SummonChestId",kit.selectedChest)
		gallery.CanvasPosition=scrolls.odds or Vector2.new(0,0)
		for i,outcome in ipairs(outcomes) do
			local rarityColor=UI.color(Catalog.Rarities[outcome.rarity].color)
			local mine=owned[outcome.id]
			local card=UI.frame(gallery,{Name="ChestHero_"..outcome.id,Position=UDim2.new(((i-1)%cols)/cols,6,0,math.floor((i-1)/cols)*pitch+6),Size=UDim2.new(1/cols,-12,0,tileH),BackgroundColor3=rarityColor})
			UI.corner(card,12)
			UI.stroke(card,mine and C.ink or Color3.new(1,1,1),mine and 2.5 or 3)
			UI.cardSkin(card,rarityColor)
			portrait(card,outcome.id,{Position=UDim2.fromOffset(4,wide and 4 or 22),Size=wide and UDim2.fromOffset(44,48) or UDim2.new(1,-8,0,70)})
			if outcome.guaranteed then UI.icon(card,"star",C.gold,{Name="GuaranteedFeature_"..outcome.id,Position=UDim2.fromOffset(4,wide and 2 or 24),Size=UDim2.fromOffset(16,16),ZIndex=4}) end
			-- The chance on top, big; NEW for what the account does not own yet.
			local odds=UI.label(card,UI.percent(outcome.chance,ctx.language()),{Name="ChestOdds_"..outcome.id,Position=wide and UDim2.new(1,-62,0,14) or UDim2.fromOffset(4,2),Size=wide and UDim2.fromOffset(58,28) or UDim2.new(1,-8,0,22),TextSize=19,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center,BackgroundTransparency=wide and 0.15 or 1,BackgroundColor3=C.ink})
			UI.oneLine(odds,11);UI.corner(odds,8)
			UI.outline(odds,2.5)
			if not mine then UI.chip(card,T("Novo","New"),C.green,{Name="ChestNew",AnchorPoint=Vector2.new(wide and 0 or 1,0),Position=wide and UDim2.fromOffset(4,38) or UDim2.new(1,-4,0,24),Size=UDim2.fromOffset(wide and 40 or 44,wide and 14 or 18),TextSize=wide and 10 or 12,ZIndex=3}) end
			local name=UI.label(card,L(catalog[outcome.id].name),{Position=UDim2.fromOffset(wide and 54 or 4,wide and 4 or 92),Size=wide and UDim2.new(1,-120,0,48) or UDim2.new(1,-8,0,28),TextScaled=true,TextWrapped=wide,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center})
			UI.textLimit(name,15,7)
			UI.outline(name,2)
			if not isBase then UI.hover(card,function(box) if kit.heroTooltip then kit.heroTooltip(box,outcome.id) end end,320) end
		end
		if chest.pity then smallText(body,T("A garantia entrega um dos destaques com estrela.","The guarantee awards one of the starred featured items."),0,28) end
		smallText(body,isBase and T("Base repetida vira Ouro.","A duplicate base becomes Gold.") or T("Repetidos rendem Ouro, maestria, estrelas e cartas.","Duplicates grant Gold, mastery, stars and cards."),0,30)
		resultCard()
		-- The day's market: exact heroes for Gold, new every day, one each per account.
		local market=not isBase and type(p.market)=="table" and p.market or nil
		if market and #(market.offers or {})>0 then
			local renew=math.max(0,(tonumber(market.renewsAt) or 0)-os.time())
			UI.section(body,T("Oferta do dia","Today's offer"),T("Renova em ","Renews in ")..math.floor(renew/3600).."h "..string.format("%02d",math.floor((renew%3600)/60)).."m"..T("  •  estoque 1 de cada","  •  stock 1 of each"))
			for _,offer in ipairs(market.offers) do
				local def=Catalog.Heroes[offer.heroId]
				if def then
					local color=UI.color(Catalog.Rarities[def.rarity].color)
					local row=UI.roundFrame(body,{Name="Market_"..offer.heroId,Size=UDim2.new(1,-6,0,72),BackgroundColor3=UI.Skin.slot},color)
					heroPortrait(row,offer.heroId,{Position=UDim2.fromOffset(6,4),Size=UDim2.fromOffset(64,64)})
					UI.hover(row,function(box) if kit.heroTooltip then kit.heroTooltip(box,offer.heroId) end end,320)
					UI.fit(UI.label(row,L(def.name),{Position=UDim2.fromOffset(80,8),Size=UDim2.new(1,-250,0,26),Font=UI.Fonts.display,TextSize=18}),10)
					UI.chip(row,Catalog.Upper(L(Catalog.Rarities[def.rarity].name)),color,{Position=UDim2.fromOffset(80,40),Size=UDim2.fromOffset(100,20),TextSize=11})
					local mine=owned[offer.heroId]~=nil
					local label=mine and T("Já é seu","Yours") or offer.bought and T("Esgotado hoje","Sold out today") or (number(offer.price)..T(" Ouro"," Gold"))
					local buy=UI.button(row,label,function() act("BuyMarket",{heroId=offer.heroId},function() showToast(L(def.name)..T(" entrou para a sua coleção!"," joined your collection!")) end) end,{Name="MarketBuy_"..offer.heroId,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),Size=UDim2.fromOffset(150,48),BackgroundColor3=C.gold,TextSize=16})
					if mine or offer.bought or (p.gold or 0)<offer.price then UI.disabled(buy) end
				end
			end
		end
		if p.paidRandomRestricted then
			UI.section(body,T("Escolha garantida","Guaranteed choice"),T("Esta conta compra sem sorteio: escolha exatamente o que receber.","This account buys without a draw: choose exactly what you get."))
			for _,itemId in ipairs(isBase and Catalog.BaseOrder or Catalog.HeroOrder) do
				if owned[itemId] then continue end
				local price=Rules.GuaranteedPrice(itemId); if not price then continue end
				local row=UI.roundFrame(body,{Name="Guaranteed_"..itemId,Size=UDim2.new(1,-6,0,64),BackgroundColor3=C.card})
				UI.label(row,L(catalog[itemId].name),{Position=UDim2.fromOffset(12,8),Size=UDim2.new(1,-168,0,48),TextWrapped=true,TextSize=16,Font=UI.Fonts.display})
				local buy=UI.button(row,number(price)..T(" Ouro"," Gold"),function() act("BuyGuaranteed",{itemId=itemId}) end,{Position=UDim2.new(1,-148,0,8),Size=UDim2.fromOffset(136,48),TextSize=16})
				if p.gold<price then UI.disabled(buy) end
			end
		end
	end

	-- Only products with a real ID in Config are drawn: nothing on sale that
	-- cannot be bought. (The server still refuses an unconfigured product.)
	local function configured(kind,key)
		local group=Config.Products and Config.Products[kind=="hero" and "Heroes" or kind=="pass" and "Passes" or "Consumables"]
		local entry=group and group[key]
		return entry~=nil and (tonumber(entry.id) or 0)>0
	end
	kit.productConfigured=configured

	-- The starter pack, featured above every tab until the account owns it.
	local function starterOffer(body)
		local pack=Catalog.Products.Consumables.starterPack
		if not pack or profile().starterPack or not configured("product","starterPack") then return end
		local info=productInfo["product:starterPack"]
		local ready=type(info)=="table"
		-- The pack stays for sale, so the banner never shows a countdown (Roblox:
		-- no timer that is not accurate). What is true: once per account.
		local urgency=T("Boas-vindas  •  só uma vez por conta","Welcome  •  once per account")
		local label=ready and (tostring(info.price).." Robux"..(info.preview and T(" • Teste"," • Preview") or ""))
			or info=="retry" and T("Tentar de novo","Try again") or info==nil and T("Carregando preço…","Loading price…") or T("Indisponível","Unavailable")
		local function purchase()
			if info=="retry" then productInfo["product:starterPack"]=nil; fetchProducts(premiumCategory); renderContext(); return end
			if not ready or info.preview then return end
			local ok=pcall(function() MarketplaceService:PromptProductPurchase(player,info.id) end)
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
			if not ready and info~="retry" or ready and info.preview then UI.disabled(fast) end
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
		if not ready and info~="retry" or ready and info.preview then UI.disabled(buy) end
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
	 categoryTabs(body,"PremiumTabs",{{id="hero",label=T("Heróis","Heroes"),icon="hero",color=C.coral},{id="offer",label=T("Ofertas","Offers"),icon="star",color=C.green},{id="pass",label=T("Passes","Passes"),icon="star",color=C.blue},{id="product",label=T("Ouro","Gold"),icon="coin",color=C.gold}},premiumCategory,function(id) premiumCategory=id; renderContext() end)
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
					local price=type(quote)=="table" and quote.price
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
				local ready=type(info)=="table"
				local label=owned and T("✓ Já é seu","✓ Yours") or ready and (tostring(info.price).." Robux"..(info.preview and T(" • Teste"," • Preview") or ""))
					or info=="retry" and T("Tentar de novo","Try again") or info==nil and T("Carregando preço…","Loading price…") or T("Indisponível","Unavailable")
				local buy=UI.button(row,label,function()
					if info=="retry" and not owned then productInfo[cacheKey]=nil; fetchProducts(premiumCategory); renderContext(); return end
					if not ready or owned or info.preview then return end
					local ok=pcall(function() if group.kind=="pass" then MarketplaceService:PromptGamePassPurchase(player,info.id) else MarketplaceService:PromptProductPurchase(player,info.id) end end)
					if not ok then showToast(T("Falha ao abrir compra.","Could not open purchase."),true) end
				end,{Name="Buy_"..cacheKey,Position=UDim2.new(0,left,1,-buttonH-(slim and 6 or 10)),Size=UDim2.new(1,-left-12,0,buttonH),BackgroundColor3=owned and C.card or C.green,TextSize=slim and 17 or 21})
				if owned or (not ready and info~="retry") or ready and info.preview then UI.disabled(buy) end
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
						UI.label(details,hero.air and T("Acerta inimigos no chão e voando","Hits ground and flying enemies") or T("Acerta só inimigos no chão","Hits ground enemies only"),{Size=UDim2.new(1,0,0,24),TextSize=15,Font=UI.Fonts.display,TextColor3=hero.air and C.green or C.coral})
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
				local card = UI.roundFrame(body, {Name = "Quest_" .. id, Size = UDim2.new(1, -6, 0, 132), BackgroundColor3 = UI.Skin.slot}, ready and C.green or UI.Skin.slotLine)
				UI.stroke(card, ready and C.green or UI.Skin.slotLine, ready and 3 or 2)
				local inset=14
				if screenSize().X>=900 then
					local emblem=UI.roundFrame(card,{Name="MissionEmblem",Position=UDim2.fromOffset(10,12),Size=UDim2.fromOffset(92,108)},ready and C.green or C.gold)
					UI.illustration(emblem,ready and "gift" or "trophy",ready and C.green or C.gold,{Position=UDim2.fromOffset(8,10),Size=UDim2.fromOffset(76,76)})
					inset=116
				end
				UI.fit(UI.label(card, L(quest.name), {Name = "QuestName", Position = UDim2.fromOffset(inset, 8), Size = UDim2.new(1, -176-inset, 0, 30), Font = UI.Fonts.display, TextSize = 23}), 12)
				UI.fit(UI.label(card, L(quest.description), {Name = "QuestText", Position = UDim2.fromOffset(inset, 38), Size = UDim2.new(1, -176-inset, 0, 40), TextSize = 16, TextWrapped = true, TextColor3 = C.muted}), 10)
				local fill = UI.bar(card, ready and C.green or C.gold, UDim2.fromOffset(inset, 90), UDim2.new(1, -186-inset, 0, 24))
				fill.Size = UDim2.fromScale(progress / math.max(quest.target or 1, 1), 1)
				UI.label(fill.Parent, progress .. " / " .. (quest.target or 1), {Size = UDim2.fromScale(1, 1), TextSize = 16, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3})
				UI.label(card, number(quest.gold or 0) .. T(" Ouro", " Gold") .. "\n" .. number(quest.xp or 0) .. " XP", {Position = UDim2.new(1, -176, 0, 6), Size = UDim2.fromOffset(164, 46), TextWrapped = true, TextSize = 18, Font = UI.Fonts.display, TextColor3 = C.gold, TextXAlignment = Enum.TextXAlignment.Right})
				-- The button says what it does now: claim when ready, otherwise the goal is still open.
				local claim = UI.button(card, quest.claimed and T("Resgatado ✓", "Claimed ✓") or (ready and T("Resgatar recompensa", "Claim reward") or T("Em andamento", "In progress")), function()
					act("ClaimQuest", {questId = id}, function(snapshot) rewardGiven(snapshot and snapshot.result) end)
				end, {Name = "ClaimQuest_" .. id, Position = UDim2.new(1, -176, 0, 62), Size = UDim2.fromOffset(164, 56), BackgroundColor3 = ready and C.green or C.card, TextSize = 19})
				if quest.claimed or progress < (quest.target or 1) then UI.disabled(claim) end
			end
		end
		local now = os.time()
		-- The day's set is replaced at the next UTC midnight, two days before it expires.
		local dailyAt = (newest.daily or 0) - 2 * 86400
		if newest.daily then UI.fit(UI.label(body, T("Novas missões em ", "New missions in ") .. timeLeft(dailyAt - now) .. T("  •  semanais em ", "  •  weekly ones in ") .. timeLeft((newest.weekly or now) - now), {Name = "QuestReset", Size = UDim2.new(1, -6, 0, 40), TextSize = 16, TextColor3 = C.muted}),11) end
		drawGroup(groups.daily, T("Missões de hoje", "Today's missions"), nil)
		drawGroup(groups.weekly, T("Missões da semana", "This week's missions"), nil)
		drawGroup(groups.old, T("Ainda para resgatar", "Still to claim"), nil)
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
	  UI.section(body,T("Seu rank: ","Your rank: ")..(ctx.language()=="en" and rank.en or rank.pt),T("Bronze 10 • Prata 20 • Ouro 30 • Diamante 40 • Lenda 50 ondas","Bronze 10 • Silver 20 • Gold 30 • Diamond 40 • Legend 50 waves"))
	 end
		UI.section(body, T("Lendas da resistência", "Legends of the resistance"), T("Evolução real da conta • temporadas de 60 dias.", "Real account progression • 60-day seasons."))
		local controls = UI.row(body, 52)
		UI.tab(controls, mapName(board.map), C.coral, "globe", true, function()
			local index = table.find(maps, board.map) or 1
			board.map = maps[index % #maps + 1]
			board.data = nil; renderContext(); loadBoard()
		end, {Name = "BoardMap", Size = UDim2.new(0.6, -6, 0, 48), TextSize = 21})
		UI.tab(controls, tostring(board.size) .. (board.size == 1 and T(" jogador", " player") or T(" jogadores", " players")), C.blue, "hero", true, function() board.size = board.size % 4 + 1; board.data = nil; renderContext(); loadBoard() end,
			{Name = "BoardSize", Position = UDim2.new(0.6, 4, 0, 0), Size = UDim2.new(0.4, -4, 0, 48), TextSize = 21})
		-- The personal best, big, like a trophy plate.
		local row = UI.roundFrame(body, {Name = "BoardPersonal", Size = UDim2.new(1, -6, 0, 78), BackgroundColor3 = UI.Skin.slot}, C.green)
		UI.stroke(row, C.green, 3)
		UI.icon(row, "trophy", C.gold, {Position = UDim2.fromOffset(12, 15), Size = UDim2.fromOffset(46, 46)})
		UI.fit(UI.label(row, T("Sua melhor marca", "Your personal best"), {Position = UDim2.fromOffset(70, 8), Size = UDim2.new(1, -190, 0, 26), Font = UI.Fonts.display, TextSize = 20, TextColor3 = C.green}), 11)
		UI.label(row, T("Temporada ", "Season ") .. tostring(board.data and board.data.season or profile().season or 1), {Position = UDim2.fromOffset(70, 40), Size = UDim2.new(1, -190, 0, 24), TextSize = 16, TextColor3 = C.muted})
		local best = UI.label(row, tostring(board.data and board.data.personal or 0) .. T(" ondas", " waves"), {Name = "BoardBest", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(170, 44), Font = UI.Fonts.display, TextSize = 30, TextColor3 = C.cream, TextXAlignment = Enum.TextXAlignment.Right})
		UI.outline(best, 3)
		if board.data and board.data.rows then
			local MEDALS = { C.gold, Color3.fromRGB(216, 224, 234), Color3.fromRGB(224, 154, 91) }
			for _, entry in ipairs(board.data.rows) do
				local mine = entry.userId == player.UserId
				local medal = MEDALS[entry.rank]
				local entryRow = UI.roundFrame(body, {Name = "BoardRow_" .. tostring(entry.rank), Size = UDim2.new(1, -6, 0, 64), BackgroundColor3 = mine and Color3.fromRGB(24, 54, 49) or UI.Skin.slot}, medal or UI.Skin.slotLine)
				UI.stroke(entryRow, medal or (mine and C.green or UI.Skin.slotLine), medal and 3 or 2)
				local place = UI.label(entryRow, "#" .. tostring(entry.rank), {Position = UDim2.fromOffset(12, 0), Size = UDim2.new(0, 64, 1, 0), Font = UI.Fonts.display, TextSize = 26, TextColor3 = medal or C.gold})
				UI.outline(place, 2.5)
				local tier=Rules.RankForWaves(entry.waves)
				UI.label(entryRow, entry.name or tostring(entry.userId), {Position = UDim2.fromOffset(80, 6), Size = UDim2.new(1, -200, 0, 28), TextSize = 20, Font = UI.Fonts.display, TextTruncate = Enum.TextTruncate.AtEnd})
				if board.mode=="ranked" then
					UI.label(entryRow, ctx.language()=="en" and tier.en or tier.pt, {Position = UDim2.fromOffset(80, 34), Size = UDim2.new(1, -200, 0, 22), TextSize = 16, TextColor3 = C.muted})
				end
				UI.label(entryRow, tostring(entry.waves) .. T(" ondas", " waves"), {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0), Size = UDim2.fromOffset(120, 34), TextXAlignment = Enum.TextXAlignment.Right, Font = UI.Fonts.display, TextSize = 22, TextColor3 = C.green})
			end
			if #board.data.rows == 0 then UI.label(body, T("Seja o primeiro a deixar sua marca neste setor.", "Be the first to set a record in this sector."), {Size = UDim2.new(1, -6, 0, 50), TextWrapped = true, TextColor3 = C.muted}) end
		elseif board.failed then
			-- Failure is a state with a way out, not an endless "loading".
			UI.label(body, T("Não foi possível carregar o placar agora.", "The leaderboard could not be loaded right now."), {Name = "BoardFailed", Size = UDim2.new(1, -6, 0, 40), TextWrapped = true, TextColor3 = C.red})
			UI.button(body, T("Tentar novamente", "Try again"), function() board.data = nil; loadBoard(); renderContext() end, {Name = "BoardRetry", Size = UDim2.new(1, -6, 0, 48), BackgroundColor3 = C.gold, TextSize = 20})
		else UI.label(body, T("Carregando placar…", "Loading leaderboard…"), {TextColor3 = C.muted}) end
		UI.secondary(body, T("Atualizar placar", "Refresh leaderboard"), loadBoard, {Name = "BoardRefresh", Size = UDim2.new(1, -6, 0, 44), TextSize = 18})
	end

	-- Four small loops around the main game, all decided by the server's clock:
	-- a free chest on a timer, a daily login streak, gifts for time played today
	-- and one-time milestones for the collection. Nothing here can be bought.
	local lastRewardResult
	rewardGiven = function(paid)
		if type(paid) ~= "table" then return end
		-- Preserve every committed prize, including a season's mixed chest batch.
		local opened = type(paid.chests) == "table" and #paid.chests or 0
		local lastChest = opened > 0 and paid.chests[opened] or paid.chest
		local parts = {}
		if paid.gold and paid.gold > 0 then table.insert(parts, "+" .. number(paid.gold) .. T(" Ouro", " Gold")) end
		if paid.xp and paid.xp > 0 then table.insert(parts, "+" .. number(paid.xp) .. " XP") end
		if lastChest then
			local hero = Catalog.Bases[lastChest.baseId] or Catalog.Heroes[lastChest.heroId]
			table.insert(parts, lastChest.duplicate and T("repetido → recompensa", "duplicate → reward") or (T("novo na coleção: ", "new in collection: ") .. (hero and L(hero.name) or "")))
		end
		if opened > 1 then table.insert(parts, "+" .. (opened - 1) .. T(" baús abertos", " more chests opened")) end
		if paid.heroPick and Catalog.Rarities[paid.heroPick] then table.insert(parts, T("herói ", "a ") .. L(Catalog.Rarities[paid.heroPick].name) .. T(" à sua escolha", " hero of your choice")) end
		for _, won in ipairs(type(paid.heroes) == "table" and paid.heroes or {}) do
			local hero = Catalog.Heroes[won.heroId]
			if hero then table.insert(parts, T("herói da temporada: ", "season hero: ") .. L(hero.name) .. (won.shiny and " ◆" or "")) end
		end
		lastRewardResult = copy(paid)
		lastRewardResult.chest = lastChest
		showToast(#parts > 0 and table.concat(parts, "  •  ") or T("Recompensa resgatada!", "Reward claimed!"), false)
		if lastChest then celebrate:Reel(opened > 0 and paid.chests or {lastChest}, lastChest.chestId) else audio:Cue("upgrade") end
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
			UI.label(row, heroName(r.heroId), {Position = UDim2.fromOffset(84, 10), Size = UDim2.new(1, -96, 0, 30), Font = Enum.Font.FredokaOne, TextSize = 16, TextWrapped = true})
			UI.label(row, r.duplicate and T("Repetido: virou Ouro e maestria", "Duplicate: turned into Gold and mastery") or T("Novo herói!", "New hero!"), {Position = UDim2.fromOffset(84, 44), Size = UDim2.new(1, -96, 0, 40), TextSize = 12, TextWrapped = true, TextColor3 = C.gold})
		end

		-- Free chest: opens on the spot, then makes you wait.
		local chest = rewards.freeChest
		local freeCard = UI.roundFrame(body, {Name = "FreeChestCard", Size = UDim2.new(1, -6, 0, 104), BackgroundColor3 = chest.ready and C.gold:Lerp(C.panel, 0.55) or C.card}, chest.ready and C.gold or C.stroke)
		UI.illustration(freeCard, "crate", chest.ready and C.gold or C.muted, {Rarity=chest.chestId,Position = UDim2.fromOffset(10, 10), Size = UDim2.fromOffset(92, 82)})
		UI.fit(UI.label(freeCard, T("Baú grátis", "Free chest"), {Name = "FreeChestTitle", Position = UDim2.fromOffset(112, 14), Size = UDim2.new(1, -250, 0, 32), Font = UI.Fonts.display, TextSize = 24}), 12)
		UI.fit(UI.label(freeCard, chest.ready and T("Pronto para abrir!", "Ready to open!") or (T("Volta em ", "Back in ") .. math.floor(chest.remaining / 3600) .. "h " .. math.floor((chest.remaining % 3600) / 60) .. "m"), {Position = UDim2.fromOffset(112, 50), Size = UDim2.new(1, -250, 0, 26), TextSize = 16, Font = UI.Fonts.display, TextColor3 = chest.ready and C.cream or C.muted}), 11)
		local claimFree = UI.button(freeCard, T("Abrir!", "Open!"), function()
			act("ClaimFreeChest", {}, function(snapshot) rewardGiven(snapshot.result) end)
		end, {Name = "ClaimFreeChest", Position = UDim2.new(1, -130, 0.5, -28), Size = UDim2.fromOffset(118, 56), BackgroundColor3 = C.green, TextSize = 20})
		if not chest.ready then UI.disabled(claimFree) end

		-- Gifts between friends: chests that friends sent wait here, and one chest
		-- a day can be sent to a Roblox friend in this server (the server checks).
		local gift = rewards.gift
		if gift then
			local pending = tonumber(gift.pending) or 0
			if pending > 0 then
				local card = UI.roundFrame(body, {Name = "GiftCard", Size = UDim2.new(1, -6, 0, 84), BackgroundColor3 = C.green:Lerp(C.panel, 0.6)}, C.green)
				UI.illustration(card, "crate", C.green, {Rarity = gift.chestId, Position = UDim2.fromOffset(10, 6), Size = UDim2.fromOffset(78, 72)})
				UI.fit(UI.label(card, pending == 1 and T("Um amigo te mandou um baú!", "A friend sent you a chest!") or (tostring(pending) .. T(" baús de amigos esperando", " chests from friends waiting")), {Position = UDim2.fromOffset(100, 24), Size = UDim2.new(1, -240, 0, 36), Font = UI.Fonts.display, TextSize = 18}), 10)
				UI.button(card, T("Abrir!", "Open!"), function()
					act("ClaimGift", {}, function(snapshot) rewardGiven(snapshot.result) end)
				end, {Name = "ClaimGift", Position = UDim2.new(1, -130, 0.5, -26), Size = UDim2.fromOffset(118, 52), BackgroundColor3 = C.green, TextSize = 20})
			end
			UI.section(body, T("Presente para um amigo", "Gift for a friend"), gift.sentToday and T("O presente de hoje já foi enviado. Amanhã tem mais.", "Today's gift is sent. More tomorrow.") or T("Envie um baú de Suprimentos a um amigo do Roblox que esteja aqui. Um por dia, de graça.", "Send a Supplies chest to a Roblox friend who is here. One a day, free."))
			local others = {}
			for _, entry in ipairs(ctx.state().players or {}) do if entry.userId ~= player.UserId then table.insert(others, entry) end end
			if #others == 0 then smallText(body, T("Ninguém mais está neste servidor agora.", "Nobody else is in this server right now."), 0, 28) end
			for _, entry in ipairs(others) do
				local row = UI.roundFrame(body, {Name = "GiftRow_" .. tostring(entry.userId), Size = UDim2.new(1, -6, 0, 56), BackgroundColor3 = C.card})
				UI.fit(UI.label(row, tostring(entry.name or "?"), {Position = UDim2.fromOffset(14, 6), Size = UDim2.new(1, -170, 0, 44), Font = UI.Fonts.display, TextSize = 17}), 10)
				local send = UI.button(row, T("Enviar", "Send"), function()
					act("SendGift", {userId = entry.userId}, function() showToast(T("Presente enviado para ", "Gift sent to ") .. tostring(entry.name or "?") .. "!") end)
				end, {Name = "SendGift_" .. tostring(entry.userId), AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(130, 42), BackgroundColor3 = C.blue, TextSize = 15})
				if gift.sentToday then UI.disabled(send) end
			end
		end

		-- Season pass: thirty levels from the XP of matches and missions. The free
		-- track pays everyone; the premium track pays the owner of the season pass.
		local season = profile().seasonStatus
		if season then
			local theme = season.theme and (" • " .. L(season.theme.name)) or ""
			UI.section(body, T("Temporada ", "Season ") .. tostring(season.id or "") .. theme, T("Nível ", "Level ") .. season.level .. "/" .. season.maxLevel
				.. (season.endsAt and (T("  •  termina em ", "  •  ends in ") .. math.max(0, math.ceil((season.endsAt - os.time()) / 86400)) .. T(" dias", " days")) or ""))
			local seasonCard = UI.roundFrame(body, {Name = "SeasonCard", Size = UDim2.new(1, -6, 0, season.owned and 196 or 252), BackgroundColor3 = C.card}, season.claimable > 0 and C.gold or C.stroke)
			local xpFill = UI.bar(seasonCard, C.violet, UDim2.fromOffset(12, 12), UDim2.new(1, -24, 0, 16))
			xpFill.Size = UDim2.fromScale(math.clamp(season.xpInto / season.xpNeed, 0, 1), 1)
			UI.label(seasonCard, season.level >= season.maxLevel and T("Temporada completa!", "Season complete!") or (number(season.xpInto) .. " / " .. number(season.xpNeed) .. T(" XP para o próximo nível", " XP to the next level")),
				{Name = "SeasonXp", Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -24, 0, 22), TextSize = 16, TextColor3 = C.muted})
			local shown = math.min(#season.upcoming, 5)
			for index = 1, shown do
				local entry = season.upcoming[index]
				local cell = UI.roundFrame(seasonCard, {Name = "SeasonLevel_" .. entry.level, Position = UDim2.new((index - 1) / shown, 6, 0, 58), Size = UDim2.new(1 / shown, -3, 0, 92),
					BackgroundColor3 = entry.reached and C.gold:Lerp(C.card, 0.8) or C.background}, entry.reached and C.gold or C.stroke)
				-- Level on top, the free prize big, the premium one under it.
				local function line(y, text, tint, size, height) UI.fit(UI.label(cell, text, {Position = UDim2.fromOffset(2, y), Size = UDim2.new(1, -4, 0, height or 20), TextSize = size or 16, Font = UI.Fonts.display, TextColor3 = tint, TextXAlignment = Enum.TextXAlignment.Center}), 10) end
				line(3, T("NV ", "LV ") .. entry.level, entry.reached and C.gold or C.muted, 18, 22)
				line(25, entry.freeClaimed and "✓" or number(entry.free.gold), entry.freeClaimed and C.green or C.text, 24, 28)
				local premiumText = (entry.premiumClaimed and "✓") or number(entry.premium.gold)
				line(53, premiumText, entry.premiumClaimed and C.green or (season.owned and C.cream or C.muted), 18, 20)
				local marks = ((entry.free.chest or entry.premium.chest) and T("Baú", "Chest") or "") .. (entry.premium.hero and ((entry.free.chest or entry.premium.chest) and " + " or "") .. T("Herói", "Hero") or "")
				if marks ~= "" then line(73, marks, C.pink, 15, 17) end
			end
			local claimSeason = UI.button(seasonCard, season.claimable > 0 and (T("Resgatar ", "Claim ") .. season.claimable .. (season.claimable == 1 and T(" prêmio", " reward") or T(" prêmios", " rewards"))) or T("Jogue para subir de nível", "Play to level up"), function()
				act("ClaimSeason", {}, function(snapshot)
					local paid = snapshot and snapshot.result
					rewardGiven(paid)
					-- With chests, the reveal is the celebration; without, a banner is.
					if type(paid) == "table" and not (paid.chests and #paid.chests > 0) then
						celebrate:Banner({pt = "TEMPORADA • NÍVEL " .. tostring(paid.level or ""), en = "SEASON • LEVEL " .. tostring(paid.level or "")},
							{pt = "+" .. number(paid.gold or 0) .. " Ouro", en = "+" .. number(paid.gold or 0) .. " Gold"}, C.violet, {cue = "upgrade", duration = 1.8})
					end
				end)
			end, {Name = "ClaimSeason", Position = UDim2.fromOffset(12, 158), Size = UDim2.new(1, -24, 0, 48), BackgroundColor3 = season.claimable > 0 and C.green or C.card, TextSize = 20})
			if season.claimable == 0 then UI.disabled(claimSeason) end
			if not season.owned then
				UI.button(seasonCard, T("Liberar trilha premium", "Unlock the premium track"), function() openContext("shop", {shopKind = configured("product", "seasonPass") and "offer" or "pass"}) end,
					{Name = "SeasonUnlock", Position = UDim2.fromOffset(12, 210), Size = UDim2.new(1, -24, 0, 36), BackgroundColor3 = C.violet, TextSize = 18})
			end
		end

		-- Login streak: a seven-day strip, the ready day highlighted.
		UI.section(body, T("Prêmio de cada dia", "Every day's prize"))
		-- lastCompletedIndex is the slot most recently claimed (today's, if the
		-- streak already paid out today; otherwise yesterday's). Everything up to
		-- it is checked off, except the slot about to be claimed, which is next.
		local cycle = rewards.login.cycle
		local lastCompletedIndex = rewards.login.streak > 0 and (((rewards.login.streak - 1) % cycle) + 1) or 0
		-- Seven cells a row, one row per week of the cycle.
		local perRow = math.min(7, cycle)
		local rows = math.ceil(cycle / perRow)
		local strip = UI.row(body, 92 * rows + 6 * (rows - 1))
		for day = 1, cycle do
			local def = Catalog.Rewards.login[day]
			local isNext = rewards.login.claimable and day == rewards.login.nextIndex
			local done = not isNext and day <= lastCompletedIndex
			local column, rowIndex = (day - 1) % perRow, math.floor((day - 1) / perRow)
			local cell = UI.roundFrame(strip, {Name = "LoginDay_" .. day, Position = UDim2.new(column / perRow, 2, 0, rowIndex * 98), Size = UDim2.new(1 / perRow, -4, 0, 92),
				BackgroundColor3 = isNext and C.gold:Lerp(C.card, 0.15) or C.card}, isNext and C.gold or (def.heroPick and C.coral or C.stroke))
			UI.label(cell, T("Dia ", "Day ") .. day, {Position = UDim2.fromOffset(0, 6), Size = UDim2.new(1, 0, 0, 20), TextSize = 16, Font = UI.Fonts.display, TextColor3 = isNext and C.gold or C.muted, TextXAlignment = Enum.TextXAlignment.Center})
			if def.heroPick then UI.illustration(cell, "hero", C.coral, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(40, 36)})
			elseif def.chest then UI.illustration(cell, "crate", C.pink, {AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 26), Size = UDim2.fromOffset(40, 36)})
			else UI.label(cell, number(def.gold), {Position = UDim2.fromOffset(0, 28), Size = UDim2.new(1, 0, 0, 30), TextSize = 19, Font = UI.Fonts.display, TextColor3 = isNext and C.gold or C.text, TextXAlignment = Enum.TextXAlignment.Center}) end
			if done then UI.label(cell, "✓", {Position = UDim2.fromOffset(0, 62), Size = UDim2.new(1, 0, 0, 24), TextSize = 22, Font = UI.Fonts.display, TextColor3 = C.green, TextXAlignment = Enum.TextXAlignment.Center}) end
		end
		local claimLogin = UI.button(body, rewards.login.claimable and (T("Resgatar dia ", "Claim day ") .. rewards.login.nextIndex) or T("Volte amanhã", "Come back tomorrow"), function()
			act("ClaimLogin", {}, function(snapshot) rewardGiven(snapshot.result) end)
		end, {Name = "ClaimLogin", Size = UDim2.new(1, -6, 0, 52), BackgroundColor3 = C.gold, TextSize = 19})
		if not rewards.login.claimable then UI.disabled(claimLogin) end

		-- Playtime gifts: how long you have played today, in one bar with markers.
		UI.section(body, T("Presentes por tempo de jogo", "Gifts for playing"))
		for _, gift in ipairs(rewards.playtime.gifts) do
			local card = UI.roundFrame(body, {Name = "PlaytimeGift_" .. gift.index, Size = UDim2.new(1, -6, 0, 60), BackgroundColor3 = C.card})
			local progress = math.clamp(rewards.playtime.seconds / (gift.minutes * 60), 0, 1)
			local fill = UI.bar(card, gift.claimed and C.muted or C.green, UDim2.fromOffset(12, 10), UDim2.new(1, -130, 0, 8))
			fill.Size = UDim2.fromScale(progress, 1)
			UI.label(card, gift.minutes .. " min", {Position = UDim2.fromOffset(12, 22), Size = UDim2.new(1, -130, 0, 30), TextSize = 16, Font = UI.Fonts.display, TextColor3 = gift.ready and C.green or C.muted})
			local claim = UI.button(card, gift.claimed and T("Resgatado", "Claimed") or (gift.chest and T("Baú", "Chest") or ("+" .. number(gift.gold))), function()
				act("ClaimPlaytime", {index = gift.index}, function(snapshot) rewardGiven(snapshot.result) end)
			end, {Name = "ClaimPlaytime_" .. gift.index, Position = UDim2.new(1, -108, 0, 8), Size = UDim2.fromOffset(96, 44), BackgroundColor3 = gift.ready and C.green or C.card, TextSize = 15})
			if not gift.ready then UI.disabled(claim) end
		end

		-- Collection milestones: how many different heroes the account owns.
		UI.section(body, T("Colecione heróis • ", "Collect heroes • ") .. rewards.collection.owned .. "/" .. #Catalog.HeroOrder)
		for _, milestone in ipairs(rewards.collection.milestones) do
			local card = UI.roundFrame(body, {Name = "Milestone_" .. milestone.index, Size = UDim2.new(1, -6, 0, 60), BackgroundColor3 = C.card})
			UI.label(card, milestone.count .. T(" heróis", " heroes"), {Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -130, 0, 26), Font = UI.Fonts.display, TextSize = 17})
			local sub = "+" .. number(milestone.gold) .. T(" Ouro", " Gold") .. (milestone.title and T("  •  título", "  •  title") or "")
			UI.label(card, sub, {Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -130, 0, 22), TextSize = 14, Font = UI.Fonts.display, TextColor3 = C.gold})
			local claim = UI.button(card, milestone.claimed and T("Resgatado", "Claimed") or T("Resgatar", "Claim"), function()
				act("ClaimMilestone", {index = milestone.index}, function(snapshot) rewardGiven(snapshot.result) end)
			end, {Name = "ClaimMilestone_" .. milestone.index, Position = UDim2.new(1, -108, 0, 10), Size = UDim2.fromOffset(96, 40), BackgroundColor3 = milestone.ready and C.gold or C.card, TextSize = 12})
			if milestone.claimed or not milestone.ready then UI.disabled(claim) end
		end

		-- Codes, the group and friends: the ways a YouTuber, a Discord or a friend
		-- brings someone in. The server checks every code and the group membership.
		UI.section(body, T("Códigos", "Codes"))
		local codeRow = UI.roundFrame(body, {Name = "CodeRow", Size = UDim2.new(1, -6, 0, 60), BackgroundColor3 = C.card})
		local codeBox = UI.create("TextBox", {
			Name = "CodeInput", Position = UDim2.fromOffset(10, 8), Size = UDim2.new(1, -128, 0, 44), BackgroundColor3 = C.background,
			Text = "", PlaceholderText = T("Digite o código", "Type the code"), ClearTextOnFocus = false,
			Font = Enum.Font.BuilderSansExtraBold, TextSize = 16, TextColor3 = C.text, PlaceholderColor3 = C.muted,
		}, codeRow)
		UI.corner(codeBox, 10)
		UI.button(codeRow, T("Usar", "Redeem"), function()
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
			UI.label(groupCard, T("Entre no grupo do jogo", "Join the game's group"), {Position = UDim2.fromOffset(12, 8), Size = UDim2.new(1, -130, 0, 24), Font = Enum.Font.BuilderSansExtraBold, TextSize = 14})
			UI.label(groupCard, "+" .. number(group.gold or 0) .. T(" Ouro, uma vez", " Gold, once"), {Position = UDim2.fromOffset(12, 32), Size = UDim2.new(1, -130, 0, 20), TextSize = 12, TextColor3 = C.muted})
			local claimGroup = UI.button(groupCard, group.claimed and T("Resgatado", "Claimed") or T("Resgatar", "Claim"), function()
				act("ClaimGroupReward", {}, function(snapshot) rewardGiven(snapshot and snapshot.result) end)
			end, {Name = "ClaimGroupReward", Position = UDim2.new(1, -110, 0, 8), Size = UDim2.fromOffset(100, 44), BackgroundColor3 = C.gold, TextSize = 12})
			if group.claimed then UI.disabled(claimGroup) end
		end
		local invite = Catalog.Rewards.invite
		if invite then
			smallText(body, T("Amigo novo que entrar pelo seu convite ganha ", "A new friend who joins from your invite gets ") .. number(invite.newcomerGold)
				.. T(" Ouro, e você ganha ", " Gold, and you get ") .. number(invite.inviterGold) .. T(" Ouro (até ", " Gold (up to ") .. invite.inviterDailyCap .. T(" por dia).", " a day)."), 0, 40)
		end
		UI.button(body, T("Convidar amigos", "Invite friends"), function()
			-- Roblox's own invite sheet: it decides who can be invited and how.
			local ok = pcall(function()
				local social = game:GetService("SocialService")
				if social:CanSendGameInviteAsync(player) then social:PromptGameInvite(player) else error("cannot invite") end
			end)
			if not ok then showToast(T("Convites indisponíveis agora.", "Invites are unavailable right now."), true) end
		end, {Name = "InviteFriends", Size = UDim2.new(1, -6, 0, 48), BackgroundColor3 = C.blue, TextSize = 14})
	end

	-- The team and collection: five hero slots, then the hero cards.
	-- Three collectible rarities, and practical roles for building a squad.
	local function contextSquad(body)
		local p=profile()
		local screen=screenSize()
		local width=UI.contextLayout(screen.X,screen.Y,{wide=true}).w-40
		local wide=width>=640
		-- Bases have their own dock entry and screen.
		-- Trading with a friend starts here: the heroes are already on screen.
		if profile().tradeAllowed~=false then UI.button(body,T("Trocar herói com amigo","Trade a hero with a friend"),function() openContext("trade",{}) end,{Name="OpenTrade",Size=UDim2.new(1,-6,0,40),BackgroundColor3=C.blue,TextSize=16}) end
		local team=UI.row(body,104)
		team.Name="TeamRow"
		local lineup=UI.frame(team,{Name="SquadSlots",Size=UDim2.new(1,0,0,104),BackgroundTransparency=1})
		for slot=1,5 do
			local id=(p.loadout or {})[slot]
			local def=id and Catalog.Heroes[id]
			local tint=def and UI.color(Catalog.Rarities[def.rarity].color) or UI.Skin.slot
			local tile=UI.secondary(lineup,"",function()
				if slot==1 then kit.inventoryView.leaderPick=not kit.inventoryView.leaderPick; inventoryFilter="owned"; kit.inventoryView.rarity="all"; renderContext()
				elseif id and kit.inventoryView.leaderPick then makeLeader(id,function() kit.inventoryView.leaderPick=false; renderContext() end)
				elseif id then
					-- A tap on a hero in the team (up here) takes it out of the team.
					local list=copy(p.loadout); table.remove(list,table.find(list,id))
					kit.inventoryView.choice=nil
					act("SetLoadout",{heroes=list},function() showToast(T(heroName(id).." saiu da equipe.",heroName(id).." left the team.")) end)
				else inventoryFilter="owned"; renderContext(); showToast(T("Clique num herói abaixo e escolha Colocar na equipe.","Click a hero below and choose Add to team.")) end
			end,{Name="SquadSlot_"..slot,Position=UDim2.new((slot-1)/5,0,0,0),Size=UDim2.new(0.2,-8,0,104),BackgroundColor3=id and tint:Lerp(UI.Skin.body,0.25) or UI.Skin.slot})
			UI.stroke(tile,slot==1 and C.gold or C.ink,slot==1 and 3.5 or 3)
			if id then
				heroPortrait(tile,id,{Position=UDim2.fromOffset(4,4),Size=UDim2.new(1,-8,1,-30)})
				UI.hover(tile,function(box) heroTooltip(box,id) end,320)
			else UI.label(tile,"+",{Size=UDim2.new(1,0,1,-24),TextSize=40,Font=UI.Fonts.display,TextColor3=C.muted,TextXAlignment=Enum.TextXAlignment.Center}) end
			UI.chip(tile,slot==1 and T("Líder","Leader") or tostring(slot),slot==1 and C.gold or C.ink,{AnchorPoint=Vector2.new(0.5,1),Position=UDim2.new(0.5,0,1,-4),Size=UDim2.new(slot==1 and 0.86 or 0.4,0,0,22),TextSize=slot==1 and 14 or 15})
		end
		local leader=(p.loadout or {})[1]
		if kit.inventoryView.leaderPick then
			local pick=UI.roundFrame(body,{Name="LeaderPick",Size=UDim2.new(1,-6,0,58),BackgroundColor3=C.gold:Lerp(UI.Skin.body,0.6)},C.gold)
			UI.label(pick,T("Clique no herói que vai liderar","Click the hero who will lead"),{Position=UDim2.fromOffset(14,0),Size=UDim2.new(1,-160,1,0),Font=UI.Fonts.display,TextSize=19,TextWrapped=true})
			UI.secondary(pick,T("Cancelar","Cancel"),function() kit.inventoryView.leaderPick=false; renderContext() end,{Name="CancelLeaderPick",AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-8,0.5,0),Size=UDim2.fromOffset(130,44),TextSize=17,BackgroundColor3=C.red})
		elseif leader and not wide then
			-- One line says what the leader does (wide screens show it beside the grid).
			local power=UI.row(body,40)
			power.Name="LeaderPower"
			UI.icon(power,"star",C.gold,{Position=UDim2.fromOffset(2,7),Size=UDim2.fromOffset(26,26)})
			UI.label(power,T("Poder do líder: ","Leader power: ")..L(Catalog.Abilities[Catalog.Heroes[leader].ability].name),{Position=UDim2.fromOffset(34,0),Size=UDim2.new(1,-34,1,0),Font=UI.Fonts.display,TextColor3=C.gold,TextSize=17,TextWrapped=true})
		end
		local owned=0
		local counts={}
		for _,id in ipairs(Catalog.HeroOrder) do
			local rarity=Catalog.Heroes[id].rarity
			counts[rarity]=counts[rarity] or {owned=0,total=0}
			counts[rarity].total+=1
			if (p.heroes or {})[id] then owned+=1;counts[rarity].owned+=1 end
		end
		local filterRow=wide and UI.row(body,50) or body
		if wide then filterRow.Name="FilterRow" end
		local tabsHost=wide and UI.frame(filterRow,{Name="TabsHost",Size=UDim2.new(0.42,0,1,0),BackgroundTransparency=1}) or body
		categoryTabs(tabsHost,"InventoryTabs",{{id="owned",label=T("Meus heróis  ","My heroes  ")..owned,color=C.coral,icon="hero"},{id="all",label=T("Todos  ","All  ")..#Catalog.HeroOrder,color=C.blue,icon="star"}},inventoryFilter,function(id) inventoryFilter=id; renderContext() end)
		-- Rarity chips: one tap narrows the cards, the active chip glows.
		local chips=wide and UI.frame(filterRow,{Name="RarityChips",Position=UDim2.new(0.42,6,0,4),Size=UDim2.new(0.58,-6,0,42),BackgroundTransparency=1}) or UI.row(body,40)
		chips.Name="RarityChips"
		local options={"all"}
		for _,id in ipairs(Catalog.RarityOrder) do table.insert(options,id) end
		for index,id in ipairs(options) do
			local rarity=Catalog.Rarities[id]
			local tint=rarity and UI.color(rarity.color) or C.cream
			local active=kit.inventoryView.rarity==id
			local chip=UI.button(chips,rarity and L(rarity.name) or T("Todas","All"),function() kit.inventoryView.rarity=id; renderContext() end,{
				Name="HeroRarity_"..id,Position=UDim2.new((index-1)/#options,0,0,0),Size=UDim2.new(1/#options,-6,0,38),TextSize=(width<520 or wide) and 13 or 16,
				BackgroundColor3=active and tint or tint:Lerp(UI.Skin.body,0.62),TextWrapped=false,TextScaled=width<520})
			local words=chip:FindFirstChild("Caption")
			if words and width<520 then UI.textLimit(words,13,7) end
			if active then UI.stroke(chip,Color3.new(1,1,1),3) end
			if rarity then
				chip:SetAttribute("OwnedCount",counts[id].owned)
				chip:SetAttribute("TotalCount",counts[id].total)
				UI.hover(chip,L(rarity.name).."  "..counts[id].owned.."/"..counts[id].total,200)
			end
		end
		local roles=UI.row(body,44);roles.Name="HeroRoleFilters"
		local roleOptions={"all","air","area","control","support"}
		for index,id in ipairs(roleOptions) do
			local def=Catalog.HeroRoles[id]
			local active=kit.inventoryView.role==id
			UI.button(roles,def and L(def.name) or T("Funções","Roles"),function() kit.inventoryView.role=id; renderContext() end,
				{Name="HeroRole_"..id,Position=UDim2.new((index-1)/#roleOptions,0,0,0),Size=UDim2.new(1/#roleOptions,-6,0,40),TextSize=13,BackgroundColor3=active and C.blue or UI.Skin.slot})
		end
		local entries=UI.collectionEntries(Catalog,p,{query="",rarity=kit.inventoryView.rarity,role=kit.inventoryView.role,sort="collection",ownership=inventoryFilter},ctx.language())
		-- The detail beside the grid (wide) or above it (narrow): the hero tapped,
		-- or the leader until one is tapped.
		local shown=kit.inventoryView.choice
		if shown and not (p.heroes or {})[shown] then shown=nil end
		local sideW=wide and 300 or 0
		local gridW=width-(wide and sideW+14 or 0)
		local columns=math.max(2,math.min(6,math.floor((gridW+10)/128)))
		local cell=math.floor((gridW-(columns-1)*10)/columns)
		local rowsH=math.max(0,math.ceil(#entries/columns)*(cell+10)-10)
		local function detail(parent,id,closable)
			local def=Catalog.Heroes[id]
			local tint=UI.color(Catalog.Rarities[def.rarity].color)
			local mine=(p.heroes or {})[id]
			local inTeam=contains(p.loadout,id)
			local pick=UI.frame(parent,{Name="HeroChoice",BackgroundColor3=UI.Skin.slot,Size=wide and UDim2.fromOffset(sideW,392) or UDim2.new(1,-6,0,300)})
			UI.corner(pick,16)
			UI.stroke(pick,tint,3)
			UI.label(pick,heroName(id),{Name="ChoiceName",Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,closable and -70 or -28,0,36),TextSize=28,Font=UI.Fonts.display,TextColor3=Color3.new(1,1,1)})
			UI.label(pick,L(Catalog.Rarities[def.rarity].name)..(mine and (T("  •  Nível ","  •  Level ")..tostring(mine.level or 1)) or ""),{Position=UDim2.fromOffset(14,42),Size=UDim2.new(1,-28,0,22),TextSize=17,Font=UI.Fonts.display,TextColor3=tint:Lerp(Color3.new(1,1,1),0.35)})
			if closable then UI.closeButton(pick,function() kit.inventoryView.choice=nil; renderContext() end,{Name="CloseHeroChoice",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,8),Size=UDim2.fromOffset(44,44),TextSize=24}) end
			heroTile(pick,id,{Name="ChoicePortrait",Position=UDim2.fromOffset(14,68),Size=UDim2.fromOffset(110,110)})
			local buttonsX,buttonsW=134,(wide and sideW or 300)-148
			UI.button(pick,inTeam and T("Tirar da equipe","Remove") or T("Colocar na equipe","Add to team"),function()
				local list=copy(p.loadout); local old=table.find(list,id)
				if old then table.remove(list,old) elseif #list<5 then table.insert(list,id) else showToast(T("A equipe tem 5 heróis. Clique num herói da equipe, lá em cima, para tirá-lo.","Team full. Click a hero in the team, up top, to take it out."),true); return end
				kit.inventoryView.choice=nil
				act("SetLoadout",{heroes=list})
			end,{Name="ChoiceTeam",Position=UDim2.fromOffset(buttonsX,68),Size=UDim2.fromOffset(buttonsW,34),BackgroundColor3=inTeam and C.card or C.green,TextSize=15})
			UI.button(pick,T("Informações","Info"),function() kit.inventoryView.choice=nil; openContext("hero",{heroId=id}) end,{Name="ChoiceInfo",Position=UDim2.fromOffset(buttonsX,106),Size=UDim2.fromOffset(buttonsW,34),BackgroundColor3=C.blue,TextSize=15})
			UI.button(pick,(p.loadout or {})[1]==id and T("É o líder","Leader") or T("Fazer líder","Make leader"),function() makeLeader(id) end,{Name="ChoiceLeader",Position=UDim2.fromOffset(buttonsX,144),Size=UDim2.fromOffset(buttonsW,34),BackgroundColor3=C.gold,TextSize=15})
			local stats=heroNow(id)
			local perSecond=(stats.interval or 0)>0 and 1/stats.interval or 0
			UI.statTable(pick,{{key="damage",label=T("Dano","Damage"),value=fmt(stats.damage)},{key="speed",label=T("Ataques/s","Hits/s"),value=string.format("%.1f",perSecond)},{key="range",label=T("Alcance","Range"),value=fmt(stats.range)}},{Name="ChoiceStats",Position=UDim2.fromOffset(14,188),Size=UDim2.new(1,-28,0,68)})
			local pills=UI.frame(pick,{Name="ChoiceTraits",Position=UDim2.fromOffset(14,264),Size=UDim2.new(1,-28,0,72),BackgroundTransparency=1})
			local flow=UI.list(pills,6,true)
			pcall(function() flow.Wraps=true end)
			UI.pill(pills,def.air and T("Chão e ar","Ground + air") or T("Só chão","Ground only"),def.air and C.green:Lerp(C.ink,0.2) or C.coral:Lerp(C.ink,0.2),{TextSize=14})
			for _,trait in ipairs(UI.heroTraits(def,T,stats.slow)) do
				local short=string.match(trait,"^([^,;:]+)") or trait
				if #short>26 then short=string.sub(short,1,24).."…" end
				UI.pill(pills,short,C.blue:Lerp(C.ink,0.15),{TextSize=14})
			end
			local ability=def.ability and Catalog.Abilities[def.ability]
			if ability then UI.label(pick,T("Poder de líder: ","Leader power: ")..L(ability.name),{Name="ChoicePower",Position=UDim2.new(0,14,1,-46),Size=UDim2.new(1,-28,0,40),TextSize=16,Font=UI.Fonts.display,TextColor3=C.gold,TextWrapped=true}) end
			return pick
		end
		if not wide and shown then detail(body,shown,true) end
		if #entries==0 then
			UI.section(body,T("Nenhum herói neste filtro","No heroes match"),T("Troque a função ou veja todos os heróis.","Change the role or view all heroes."))
			UI.secondary(body,T("Limpar filtros","Clear filters"),function() kit.inventoryView.rarity="all";kit.inventoryView.role="all";renderContext() end,{Name="ClearHeroFilters",Size=UDim2.new(1,-6,0,44),TextSize=17})
		end
		local area=UI.frame(body,{Name="HeroArea",Size=UDim2.new(1,-6,0,math.max(rowsH,wide and 392 or 0)),BackgroundTransparency=1})
		local gallery=UI.frame(area,{Name="HeroGallery",Size=UDim2.fromOffset(gridW,rowsH),BackgroundTransparency=1})
		for index,id in ipairs(entries) do
			local mine=(p.heroes or {})[id]
			local slot=table.find(p.loadout or {},id)
			local x,y=((index-1)%columns)*(cell+10),math.floor((index-1)/columns)*(cell+10)
			local card=heroTile(gallery,id,{Name="Collection_"..id,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(cell,cell)})
			if id==(shown or (wide and leader)) then UI.stroke(card,Color3.new(1,1,1),3.5) end
			-- The earned stars on a gold badge (one per duplicate), the level beside.
			local stars=mine and math.clamp(mine.stars or 0,0,Catalog.Stars.max) or 0
			if mine then
				local star=UI.frame(card,{Name="StarBadge",Position=UDim2.new(0,-4,1,-34),Size=UDim2.fromOffset(38,38),BackgroundTransparency=1,ZIndex=4})
				UI.icon(star,"star",C.gold,{Size=UDim2.fromScale(1,1),ZIndex=4})
				UI.label(star,tostring(stars),{Name="CollectionStars",Size=UDim2.fromScale(1,1),TextSize=17,Font=UI.Fonts.display,TextColor3=Color3.fromRGB(150,80,10),TextXAlignment=Enum.TextXAlignment.Center,ZIndex=5})
				local level=UI.label(card,T("Nv. ","Lv. ")..mine.level,{Name="CollectionLevel",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-6,1,-4),Size=UDim2.fromOffset(cell-40,26),TextSize=cell<110 and 16 or 20,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=4})
				UI.outline(level,2.5)
				if mine.shiny then UI.label(card,"◆",{Name="CollectionShiny",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-6,0,4),Size=UDim2.fromOffset(24,22),TextSize=18,TextXAlignment=Enum.TextXAlignment.Right,ZIndex=4}) end
			end
			if slot then UI.chip(card,slot==1 and T("Líder","Lead") or tostring(slot),slot==1 and C.gold or C.green,{Name="TeamMark",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-6,0,mine and mine.shiny and 28 or 6),Size=UDim2.fromOffset(slot==1 and 54 or 26,22),TextSize=13,ZIndex=4}) end
			local hit=UI.button(card,"",function()
				if kit.inventoryView.leaderPick and mine then makeLeader(id,function() kit.inventoryView.leaderPick=false; renderContext() end)
				elseif mine then kit.inventoryView.choice=id; renderContext()
				else openContext("hero",{heroId=id}) end
			end,{Name="FormationHero_"..id,Size=UDim2.fromScale(1,1),BackgroundTransparency=1,ZIndex=6})
			UI.hover(hit,function(box) heroTooltip(box,id) end,330)
		end
		if wide then
			local id=shown or leader or entries[1]
			if id and Catalog.Heroes[id] then
				local panel=detail(area,id,shown~=nil)
				panel.Position=UDim2.fromOffset(gridW+14,0)
			end
		end
	end

	local function contextSettings(body)
	 UI.button(body,T("Aprender a jogar • "..tostring(Catalog.Modes.tutorial.waves).." ondas","Learn to play • "..tostring(Catalog.Modes.tutorial.waves).." waves"),startTraining,{Name="OptionalTutorial",Size=UDim2.new(1,-6,0,52),TextSize=21})
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
		-- One row per option, like the big games' settings: the name on the left,
		-- a switch on the right (green when on).
		local screen = screenSize()
		local narrow = UI.contextLayout(screen.X, screen.Y, {wide = true}).w - 40 < 420
		for _, option in ipairs(options) do
			local card = UI.roundFrame(body, {Name = "Setting_" .. option.key, Size = UDim2.new(1, -6, 0, 66), BackgroundColor3 = UI.Skin.slot}, UI.Skin.slotLine)
			if not narrow then
				local glyphs={language="globe",lowFX="sparkle",shake="target",music="music",effects="bolt",interface="gear"}
				UI.illustration(card,glyphs[option.key],C.blue,{Name="SettingIcon",Position=UDim2.fromOffset(12,11),Size=UDim2.fromOffset(44,44)})
			end
			local name = UI.label(card, option.title, {Position = UDim2.fromOffset(narrow and 16 or 68, 4), Size = narrow and UDim2.new(0.56, -24, 1, -8) or UDim2.new(1, -302, 1, -8), TextSize = 21, Font = UI.Fonts.display, TextWrapped = true})
			UI.fit(name, 12)
			local on = option.value == T("Ligado", "On")
			local off = option.value == T("Desligado", "Off")
			UI.button(card, option.value, function()
				local update = {}
				update[option.key] = option.next
				act("Settings", update)
			end, {AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -12, 0.5, 0), Size = narrow and UDim2.new(0.44, -6, 0, 46) or UDim2.fromOffset(220, 46), TextSize = 19,
				BackgroundColor3 = on and C.green or (off and C.card or C.blue)})
		end
		UI.section(body, T("Controles", "Controls"))
		UI.label(body, T("1 a 5: escolher herói  •  Q: poder do líder  •  F: velocidade  •  C: ficha\nClique no chão: coloca o herói na hora  •  botão direito ou Esc: cancela\nClique num herói em campo: melhorar, mirar ou vender  •  G: marcar um local para o grupo\nShift: correr  •  pule de novo no ar: pulo duplo",
			"1 to 5: choose hero  •  Q: leader power  •  F: speed  •  C: sheet\nClick the ground: places the hero at once  •  right click or Esc: cancel\nClick a hero on the field: upgrade, target or sell  •  G: ping a spot for the squad\nShift: run  •  jump again in the air: double jump"),
			{Name = "ControlsHelp", Size = UDim2.new(1, -6, 0, 120), TextColor3 = C.muted, TextSize = 17, TextWrapped = true, TextYAlignment = Enum.TextYAlignment.Top})
	end

	local talentSelected = nil
	-- One drawn icon per talent (UI.icon kinds): no letters, no emoji.
	local TALENT_ICONS = {
		roundGold = "coin", killGold = "star", magnet = "magnet", victoryGold = "trophy", globalMagnet = "globe",
		baseVitality = "heart", baseRecovery = "plus", lastStand = "shield",
		startingEnergy = "bolt", towerPower = "sword", reach = "target", skillTempo = "clock", abilityPower = "sparkle",
	}
	-- The talent tree, in the style of the big games' research trees: big
	-- hexagons growing out of the commander's own hexagon (the level), Fortune
	-- to the left, Command to the right and Guardian upwards. Hovering one tells
	-- what it does now and next; tapping it evolves it. In the lobby it fills the
	-- screen over a dark backdrop and opens with the hexagons snapping in one by
	-- one like building blocks; inside a match it is read-only and only shows
	-- what the commander already has.
	-- options.readOnly, options.rerender (how to redraw the host), options.canvasHeight.
	local TALENT_STEPS = {
		W = { { -1.732, 0 }, { -0.866, -1.5 }, { -1.732, 0 }, { -0.866, 1.5 } },
		E = { { 1.732, 0 }, { 0.866, -1.5 }, { 1.732, 0 }, { 0.866, 1.5 } },
		N = { { 0.866, -1.5 }, { -0.866, -1.5 } },
	}
	local TALENT_DIRECTION = { fortune = "W", command = "E", guardian = "N" }
	-- Where every hexagon sits, in units of the hexagon's radius, around the
	-- commander's hexagon at (0, 0); and the box they need.
	local function talentUnits()
		local units, order = {}, {}
		local minX, maxX, minY, maxY = -1, 1, -1.1, 1.1
		for b, branch in ipairs(Catalog.TalentBranches) do
			local steps = TALENT_STEPS[TALENT_DIRECTION[branch.id] or ({ "W", "E", "N" })[(b - 1) % 3 + 1]]
			local x, y = 0, 0
			for index, id in ipairs(branch.nodes) do
				local step = steps[(index - 1) % #steps + 1]
				x, y = x + step[1], y + step[2]
				units[id], order[id] = Vector2.new(x, y), index
				minX, maxX = math.min(minX, x - 0.95), math.max(maxX, x + 0.95)
				minY, maxY = math.min(minY, y - 1.1), math.max(maxY, y + 1.1)
			end
		end
		return units, order, minX, maxX, minY, maxY
	end
	-- A pointy-top hexagon: the UI has no polygons, so three bars turned 30, 90
	-- and 150 degrees make one. Opaque only (overlapping see-through bars show).
	local function hexagon(parent, name, radius, tint, z)
		local root = UI.frame(parent, {Name = name, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(radius * 2, radius * 2), BackgroundTransparency = 1, ZIndex = z, Active = false})
		for _, angle in ipairs({30, 90, 150}) do
			UI.frame(root, {Name = "Bar", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(radius, radius * 1.732), Rotation = angle, BackgroundColor3 = tint, ZIndex = z, Active = false})
		end
		return root
	end
	local function talentUnit(def)
		return def.unit == "%" and "%" or (def.unit == "HP" and " HP" or (def.unit == "gold" and T(" Ouro", " Gold") or ""))
	end
	local function talentValue(def, r)
		if def.flag then return r > 0 and T("Ativo", "Active") or T("inativo", "inactive") end
		return (r > 0 and "+" or "") .. tostring(r * def.effect) .. talentUnit(def)
	end
	local function buildTalents(body, options)
		options = options or {}
		local readOnly = options.readOnly == true
		local rerender = options.rerender or function() renderContext() end
		local p = profile()
		local points = p.talentPoints or 0
		local ranks = p.talents or {}
		local screen = screenSize()
		local compact = UI.sizeClass(screen.X, screen.Y).compact
		local function available(id)
			local def = Catalog.Talents[id]
			return not def.parent or (ranks[def.parent] or 0) >= def.requiredRank
		end
		local function branchOf(id)
			for _, branch in ipairs(Catalog.TalentBranches) do if table.find(branch.nodes, id) then return branch end end
			return Catalog.TalentBranches[1]
		end
		if not talentSelected or not Catalog.Talents[talentSelected] then
			for _, branch in ipairs(Catalog.TalentBranches) do
				for _, id in ipairs(branch.nodes) do
					if not talentSelected and available(id) and (ranks[id] or 0) < Catalog.Talents[id].maxRank then talentSelected = id end
				end
			end
			talentSelected = talentSelected or Catalog.TalentBranches[1].nodes[1]
		end
		local function describe(id)
			local def = Catalog.Talents[id]
			local rank, open = ranks[id] or 0, available(id)
			local text = '<font color="#FFD23F">' .. L(def.name) .. "  " .. rank .. "/" .. def.maxRank .. "</font>  " .. L(def.description) .. "\n"
			if rank >= def.maxRank then text ..= T("Agora: ", "Now: ") .. talentValue(def, rank) .. T("  •  nível máximo", "  •  max level")
			else text ..= T("Agora: ", "Now: ") .. talentValue(def, rank) .. "  →  " .. T("Próximo: ", "Next: ") .. talentValue(def, rank + 1) end
			if not open then
				local parentDef = def.parent and Catalog.Talents[def.parent]
				if parentDef then text ..= '\n<font color="#FF4D5E">' .. T("Requer ", "Requires ") .. L(parentDef.name) .. " " .. def.requiredRank .. "/" .. parentDef.maxRank .. "</font>" end
			end
			return text
		end

		-- The stage: the whole screen in the lobby, a fixed band in the match sheet.
		local measured = body.AbsoluteSize
		-- A window still popping open measures smaller than it is: the caller
		-- that knows the real width says so.
		local bodyW = options.canvasWidth or ((measured and measured.X and measured.X > 0) and UI.toLogical(measured.X) or 460)
		local stageW = readOnly and math.max(280, bodyW - 8) or screen.X
		local stageH = readOnly and (options.canvasHeight or 300) or screen.Y
		if readOnly then
			UI.fit(UI.label(body, T("Seus talentos nesta partida. Só mudam no lobby.", "Your talents in this match. They only change in the lobby."), {Name = "TalentReadOnlyNote", Size = UDim2.new(1, -6, 0, 24), TextSize = 14, TextWrapped = true, TextColor3 = C.muted}), 10)
		else
			body.ScrollingEnabled, body.ScrollBarThickness = false, 0
		end
		local stage = UI.frame(body, {Name = "TalentTree", Size = UDim2.new(1, readOnly and -6 or 0, 0, stageH), BackgroundTransparency = 1, ClipsDescendants = readOnly})
		local headH = readOnly and 0 or (compact and 64 or 78)
		local footH = readOnly and 0 or (compact and 70 or 86)
		local infoH = readOnly and 0 or (compact and 0 or 48)
		if not readOnly then
			-- The world stays visible through the controller's menu blur.
			local plaque=UI.frame(stage,{Name="TalentTitlePlate",AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,4),Size=UDim2.new(1,compact and -230 or -330,0,compact and 36 or 48),BackgroundColor3=C.background,Active=false,ZIndex=1})
			UI.angular(plaque,C.gold,{cut=12})
			local heading = UI.label(stage, T("Árvore de Evolução", "Talent Tree"), {Name = "TalentHeading", Position = UDim2.fromOffset(compact and 128 or 160, compact and 4 or 10), Size = UDim2.new(1, compact and -194 or -240, 0, compact and 34 or 42),
				Font = UI.Fonts.display, TextSize = compact and 26 or 38, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3})
			UI.oneLine(heading, compact and 14 or 20)
			UI.outline(heading, 3)
			local instruction = compact and T("Arraste para explorar", "Drag to explore") or T("Arraste para explorar  •  roda do mouse: aproximar  •  clique: evoluir", "Drag to explore  •  mouse wheel: zoom  •  click: upgrade")
			local how = UI.oneLine(UI.label(stage, instruction, {Name = "TalentHow", AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, compact and 40 or 52), Size = UDim2.new(1, compact and -32 or -220, 0, 22),
				TextSize = compact and 12 or 16, TextColor3 = C.text, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 3}), 11)
			UI.outline(how, 2)
		end

		-- The honeycomb, sized to the space between the heading and the footer.
		local units, order, minX, maxX, minY, maxY = talentUnits()
		local areaW, areaH = stageW - 24, stageH - headH - footH - infoH - 12
		-- Never smaller than a fingertip on a small screen: the tree scrolls instead.
		local R = math.floor(math.clamp(math.min(areaW / (maxX - minX), areaH / (maxY - minY)), compact and 30 or 26, readOnly and 50 or 66))
		if readOnly then R = math.max(40, R) else R = compact and 62 or 60 end
		local mapW, mapH = math.ceil((maxX - minX) * R), math.ceil((maxY - minY) * R)
		local holder = stage
		if not readOnly then
			holder = UI.frame(stage, {Name = "TalentViewport", Position = UDim2.fromOffset(12, headH + 4), Size = UDim2.new(1, -24, 0, areaH + 8), BackgroundTransparency = 1, ClipsDescendants = true, Active = true, ZIndex = 3})
		elseif mapH > areaH or mapW > areaW then
			-- A small phone: the tree scrolls inside its band.
			holder = UI.scroll(stage, {Name = "TalentScroll", Position = UDim2.fromOffset(12, headH + 4), Size = UDim2.new(1, -24, 0, areaH + 8), ScrollingDirection = Enum.ScrollingDirection.XY,
				AutomaticCanvasSize = Enum.AutomaticSize.None, CanvasSize = UDim2.fromOffset(mapW + 8, mapH + 8), ScrollBarThickness = 6, ZIndex = 3})
			-- Opens centred on the commander's hexagon, where every branch starts.
			local rootX, rootY = (0 - minX) * R, (0 - minY) * R
			holder.CanvasPosition = Vector2.new(math.max(0, rootX - (areaW - 24) / 2), math.max(0, rootY - areaH / 2))
			if options.canvasPosition then holder.CanvasPosition = options.canvasPosition end
		end
		local map = UI.frame(holder, {Name = "TalentMap", AnchorPoint = holder == stage and Vector2.new(0.5, 0) or Vector2.new(0, 0), Position = holder == stage and UDim2.new(0.5, 0, 0, headH + 4 + math.max(0, math.floor((areaH - mapH) / 2))) or UDim2.fromOffset(4, 4),
			Size = UDim2.fromOffset(mapW, mapH), BackgroundTransparency = 1, ZIndex = 3})
		local function at(unit) return Vector2.new((unit.X - minX) * R, (unit.Y - minY) * R) end
		local lowFX = p.settings and p.settings.lowFX == true
		local navigation
		if not readOnly then
			kit.talentView = kit.talentView or {}
			navigation = TalentViewport.new({UI = UI, holder = holder, map = map, saved = kit.talentView, width = areaW, height = areaH + 8,
				mapW = mapW, mapH = mapH, root = at(Vector2.new(0, 0)), overview = not compact, lowFX = lowFX})
			local center = UI.secondary(stage, T("Centralizar", "Center"), function() navigation.Center(); audio:Talent("center") end,
				{Name = "TalentCenter", Position = UDim2.fromOffset(12, compact and 4 or 12), Size = UDim2.fromOffset(compact and 106 or 130, compact and 34 or 42), TextSize = compact and 14 or 17, ZIndex = 8})
			if compact then UI.hover(center, function(box) UI.tooltipTitle(box, T("Explorar a árvore", "Explore the tree")); UI.tooltipLine(box, T("Arraste com o dedo ou mouse. No PC, use a roda para aproximar.", "Drag with your finger or mouse. On PC, use the wheel to zoom."), C.muted) end, 280) end
		end
		local animate = not readOnly and kit.talentAnimate and not lowFX
		kit.talentAnimate = nil
		local bought = kit.talentBought
		kit.talentBought = nil
		local tweens = game:GetService("TweenService")
		-- A plastic brick snapping into place: the placing thunk and a click a
		-- hair after it, like a building block pressed home.
		local function snap()
			audio:Talent("snap")
		end
		local function popIn(button, delay, fromScale)
			local scale = button:FindFirstChild("PressScale")
			if not scale then return end
			scale.Scale = fromScale
			task.delay(delay, function()
				if not button.Parent then return end
				-- Each hexagon clicks into place like a building brick.
				if fromScale < 1 then snap() end
				pcall(function() tweens:Create(scale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play() end)
			end)
		end

		-- The commander's own hexagon in the middle: the level that pays the points.
		local root = UI.button(map, "", function()
			showToast(T("Cada nível novo dá 1 ponto de evolução.", "Every new level gives 1 talent point."))
		end, {Name = "TalentRoot", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(at(Vector2.new(0, 0)).X, at(Vector2.new(0, 0)).Y), Size = UDim2.fromOffset(R * 1.9, R * 2.1), BackgroundTransparency = 1, ZIndex = 4})
		if navigation then navigation:Watch(root) end
		local rootGlow = UI.frame(root, {Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(R * 2.5, R * 2.5), BackgroundColor3 = C.gold, BackgroundTransparency = 0.82, ZIndex = 4})
		UI.corner(rootGlow, R * 2)
		hexagon(root, "RootRing", R * 1.06, C.cream, 4)
		hexagon(root, "RootRim", R * 1.06 - 3, Color3.fromRGB(150, 98, 20), 4)
		hexagon(root, "RootFace", R * 0.9, C.gold, 4)
		local caption = UI.label(root, T("Nível", "Level"), {Name = "RootCaption", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.33), Size = UDim2.fromOffset(R * 1.4, R * 0.36), Font = UI.Fonts.display, TextScaled = true, TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6})
		UI.textLimit(caption, math.max(10, math.floor(R * 0.3)), 7)
		UI.fit(UI.label(root, tostring(p.level or 1), {Name = "RootLevel", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(R * 1.4, R * 0.7), Font = UI.Fonts.display, TextSize = math.max(18, math.floor(R * 0.62)), TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 6}), 8)
		if animate then popIn(root, 0, 0) end

		-- The branch names, once each, at the outer end of their branch.
		local legend = UI.frame(map, {Name = "TalentLegend", Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ZIndex = 6})
		for b, branch in ipairs(Catalog.TalentBranches) do
			local last = units[branch.nodes[#branch.nodes]]
			local direction = TALENT_DIRECTION[branch.id] or ({ "W", "E", "N" })[(b - 1) % 3 + 1]
			local spot = at(last) + (direction == "N" and Vector2.new(R * 1.85, 0) or Vector2.new(0, R * 1.32))
			local tint = Color3.fromRGB(unpack(branch.color))
			UI.pill(legend, L(branch.name), tint:Lerp(C.ink, 0.25), {Name = "TalentBranch_" .. branch.id, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(spot.X, spot.Y), TextSize = compact and 13 or 17, ZIndex = 7})
		end

		local info
		for _, branch in ipairs(Catalog.TalentBranches) do
			local tint = Color3.fromRGB(unpack(branch.color))
			for _, id in ipairs(branch.nodes) do
				local def = Catalog.Talents[id]
				local rank, open = ranks[id] or 0, available(id)
				local maxed = rank >= def.maxRank
				local buyable = not readOnly and open and not maxed and points >= 1
				local spot = at(units[id])
				local node = UI.button(map, "", function()
					talentSelected = id
					if info then info.Text = describe(id) end
					if readOnly then rerender(); return end
					if not open then
						local parentDef = def.parent and Catalog.Talents[def.parent]
						showToast(parentDef and (T("Primeiro evolua ", "First evolve ") .. L(parentDef.name) .. " " .. T("até ", "to ") .. def.requiredRank .. "/" .. parentDef.maxRank) or T("Bloqueado.", "Locked."), true)
					elseif maxed then
						showToast(L(def.name) .. T(" já está no máximo.", " is already maxed."))
					elseif points < 1 then
						showToast(T("Sem pontos: cada nível novo dá 1 ponto.", "No points: every new level gives 1 point."), true)
					else
						snap()
						act("UpgradeTalent", {talentId = id, expectedRank = rank}, function()
							kit.talentBought = id
							audio:Cue("upgrade")
							showToast(L(def.name) .. "  " .. (rank + 1) .. "/" .. def.maxRank)
						end)
					end
				end, {Name = "TalentNode_" .. id, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(spot.X, spot.Y), Size = UDim2.fromOffset(R * 1.732, R * 2), BackgroundTransparency = 1, ZIndex = 5})
				if navigation then navigation:Watch(node) end
				node.MouseEnter:Connect(function()
					if not readOnly then audio:Talent("hover") end
					if not lowFX then
						local press = node:FindFirstChild("PressScale")
						if press then tweens:Create(press, TweenInfo.new(0.12), {Scale = 1.05}):Play() end
					end
				end)
				node.MouseLeave:Connect(function()
					local press = node:FindFirstChild("PressScale")
					if press then tweens:Create(press, TweenInfo.new(0.12), {Scale = 1}):Play() end
				end)
				-- Owned: the branch colour with a soft glow; maxed: a gold rim;
				-- open: a white rim on a dark face; locked: grey and dim.
				if rank > 0 or buyable then
					local glow = UI.frame(node, {Name = "Glow", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(R * 2.2, R * 2.2), BackgroundColor3 = maxed and C.gold or (rank > 0 and tint or Color3.new(1, 1, 1)), BackgroundTransparency = rank > 0 and 0.78 or 0.9, ZIndex = 5})
					UI.corner(glow, R * 2)
				end
				local ring = maxed and C.gold or (open and Color3.fromRGB(236, 240, 255) or Color3.fromRGB(92, 98, 118))
				hexagon(node, "TalentHexOutline_" .. id, R, ring, 5)
				hexagon(node, "TalentHexRim_" .. id, R - 4, rank > 0 and tint:Lerp(C.ink, 0.45) or (open and Color3.fromRGB(46, 50, 76) or Color3.fromRGB(34, 36, 46)), 5)
				local face = rank > 0 and tint or (open and Color3.fromRGB(28, 31, 52) or Color3.fromRGB(22, 23, 30))
				hexagon(node, "TalentHex_" .. id, R * 0.8, face, 5)
				local iconTint = rank > 0 and Color3.new(1, 1, 1) or (open and tint:Lerp(Color3.new(1, 1, 1), 0.25) or Color3.fromRGB(110, 114, 130))
				-- Everything sits inside the hexagon (neighbours touch): the level on
				-- top, the icon, the name, and the price when it can be bought.
				local small = R < 34
				UI.illustration(node, TALENT_ICONS[id] or "star", iconTint, {Name = "TalentIcon_" .. id, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, small and 0.5 or 0.43), Size = UDim2.fromOffset(R * 0.66, R * 0.66), ZIndex = 7})
				if not open then
					UI.icon(node, "lock", C.cream, {Name = "TalentLock_" .. id, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, R * 0.5, 0.5, -R * 0.5), Size = UDim2.fromOffset(math.max(14, R * 0.36), math.max(14, R * 0.36)), ZIndex = 8})
				end
				local word = UI.label(node, def.short and L(def.short) or L(def.name), {Name = "TalentWord", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.645), Size = UDim2.fromOffset(R * 1.36, math.max(11, R * 0.27)),
					TextScaled = true, Font = UI.Fonts.display, TextColor3 = open and Color3.new(1, 1, 1) or Color3.fromRGB(130, 134, 150), TextXAlignment = Enum.TextXAlignment.Center, Visible = not small, ZIndex = 7})
				UI.textLimit(word, math.max(11, math.floor(R * 0.27)), 8)
				local badge = UI.chip(node, maxed and "MAX" or (rank .. "/" .. def.maxRank), maxed and C.gold or (rank > 0 and tint:Lerp(C.ink, 0.2) or Color3.fromRGB(48, 52, 72)), {Name = "TalentRank_" .. id, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, small and 0.2 or 0.215),
					Size = UDim2.fromOffset(math.max(small and 30 or 40, R * 0.82), math.max(small and 14 or 17, R * 0.27)), TextSize = math.max(small and 9 or 11, math.floor(R * 0.22)), ZIndex = 9})
				if buyable then
					UI.chip(node, T("1 ponto", "1 point"), C.green:Lerp(C.ink, 0.15), {Name = "TalentCost_" .. id, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.8),
						Size = UDim2.fromOffset(math.max(50, R * 0.98), math.max(16, R * 0.27)), TextSize = math.max(10, math.floor(R * 0.21)), ZIndex = 9})
				end
				UI.hover(node, function(box)
					UI.tooltipTitle(box, L(def.name), tint)
					UI.tooltipLine(box, L(def.description), C.muted, 2)
					if maxed then
						UI.tooltipLine(box, T("Agora: ", "Now: ") .. talentValue(def, rank) .. T("  •  nível máximo", "  •  max level"), C.gold, 3, 17)
					else
						UI.tooltipLine(box, T("Agora: ", "Now: ") .. talentValue(def, rank) .. '  →  <font color="#58E04F">' .. T("Próximo: ", "Next: ") .. talentValue(def, rank + 1) .. "</font>", C.text, 3, 17)
					end
					if not open then
						local parentDef = def.parent and Catalog.Talents[def.parent]
						if parentDef then UI.tooltipLine(box, T("Requer ", "Requires ") .. L(parentDef.name) .. " " .. def.requiredRank .. "/" .. parentDef.maxRank, C.red, 4, 16) end
					elseif not maxed and not readOnly then
						UI.tooltipLine(box, points >= 1 and T("Clique para evoluir: 1 ponto", "Click to evolve: 1 point") or T("Sem pontos agora: suba de nível", "No points now: level up"), points >= 1 and C.green or C.coral, 4, 16)
					end
				end, 320)
				if animate then
					popIn(node, 0.12 + (order[id] or 1) * 0.07 + (branch.id == "guardian" and 0.03 or 0), 0)
				elseif bought == id and not lowFX then
					popIn(node, 0, 1.35)
				end
			end
		end

		if readOnly then
			-- The chosen talent's card under the tree: exactly what it does now.
			local id = talentSelected
			local def = Catalog.Talents[id]
			local branchTint = Color3.fromRGB(unpack(branchOf(id).color))
			local rank = ranks[id] or 0
			local card = UI.roundFrame(body, {Name = "Talent_" .. id, Size = UDim2.new(1, -6, 0, 100), BackgroundColor3 = branchTint:Lerp(C.background, 0.78)}, branchTint)
			UI.oneLine(UI.label(card, L(def.name), {Position = UDim2.fromOffset(12, 6), Size = UDim2.new(1, -90, 0, 24), TextSize = 21, Font = UI.Fonts.display, TextColor3 = branchTint}), 12)
			UI.label(card, rank .. " / " .. def.maxRank, {Position = UDim2.new(1, -82, 0, 10), Size = UDim2.fromOffset(70, 26), TextSize = 19, Font = UI.Fonts.display, TextXAlignment = Enum.TextXAlignment.Right})
			UI.fit(UI.label(card, L(def.description), {Position = UDim2.fromOffset(12, 34), Size = UDim2.new(1, -24, 0, 32), TextWrapped = true, TextSize = 14, TextColor3 = C.muted, TextYAlignment = Enum.TextYAlignment.Top}), 10)
			local nowNext = rank >= def.maxRank and (T("Agora: ", "Now: ") .. talentValue(def, rank) .. T("  •  nível máximo", "  •  max level"))
				or (T("Agora: ", "Now: ") .. talentValue(def, rank) .. "  →  " .. T("Próximo: ", "Next: ") .. talentValue(def, rank + 1))
			UI.fit(UI.label(card, nowNext, {Name = "TalentNowNext", Position = UDim2.fromOffset(12, 68), Size = UDim2.new(1, -24, 0, 26), TextSize = 16, Font = UI.Fonts.display, TextColor3 = C.gold}), 10)
			return
		end

		-- The footer: the points to spend on the left, Exit in the middle, reset on the right.
		info = UI.label(stage, describe(talentSelected), {Name = "TalentInfo", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -footH - 4), Size = UDim2.new(1, -40, 0, infoH > 0 and infoH or 1),
			TextSize = 16, TextWrapped = true, RichText = true, TextTruncate = Enum.TextTruncate.None, TextXAlignment = Enum.TextXAlignment.Center, Visible = infoH > 0, ZIndex = 3})
		UI.outline(info, 2)
		local narrowFooter = stageW < 520
		local narrowW = math.floor((stageW - 68) / 3)
		local pointsBox = UI.frame(stage, {Name = "TalentOverview", AnchorPoint = Vector2.new(0, 1), Position = UDim2.new(0, 16, 1, -12), Size = UDim2.fromOffset(narrowFooter and narrowW or (compact and 150 or 250), footH - 20), BackgroundColor3 = UI.Skin.slot, ZIndex = 3})
		UI.corner(pointsBox, 14)
		UI.stroke(pointsBox, points > 0 and C.gold or UI.Skin.slotLine, 2.5)
		UI.icon(pointsBox, "star", C.gold, {Position = UDim2.new(0, 10, 0.5, -(compact and 13 or 18)), Size = UDim2.fromOffset(compact and 26 or 36, compact and 26 or 36), ZIndex = 4})
		local count = UI.label(pointsBox, tostring(points), {Name = "TalentPoints", Position = UDim2.fromOffset(compact and 40 or 54, 0), Size = UDim2.new(0, narrowFooter and 36 or (compact and 36 or 50), 1, 0), Font = UI.Fonts.display, TextSize = compact and 26 or 38, TextColor3 = C.gold, ZIndex = 4})
		UI.outline(count, 3)
		if not narrowFooter then UI.label(pointsBox, compact and T("pontos", "points") or T("pontos para gastar", "points to spend"), {Position = UDim2.fromOffset(compact and 78 or 106, 0), Size = UDim2.new(1, compact and -82 or -110, 1, 0), Font = UI.Fonts.display, TextSize = compact and 13 or 17, TextWrapped = true, ZIndex = 4}) end
		local exitW = narrowFooter and narrowW or (compact and 140 or 210)
		UI.button(stage, T("Sair", "Exit"), closeContext, {Name = "TalentExit", AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -12), Size = UDim2.fromOffset(exitW, footH - 20), BackgroundColor3 = C.red, TextSize = compact and 22 or 30, ZIndex = 3})
		local confirmReset = false
		local reset
		reset = UI.secondary(stage, T("Redistribuir pontos", "Reset points"), function()
			if not confirmReset then confirmReset = true; reset.Text = T("Confirmar redistribuição", "Confirm reset"); return end
			act("ResetTalents", {}, function() showToast(T("Pontos devolvidos. Experimente outra especialidade!", "Points refunded. Try a different specialty!")) end)
		end, {Name = "ResetTalents", AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -12), Size = UDim2.fromOffset(narrowFooter and narrowW or (compact and 150 or 230), footH - 20), TextSize = compact and 13 or 17, ZIndex = 3})
	end
	local function contextTalents(body) buildTalents(body, nil) end

	local function contextModes(body)
		UI.section(body,T("Escolha seu destino","Choose your destination"),T("Cada portal tem seu mapa e seu modo. Para jogar com amigos, entrem no mesmo portal.","Each portal has its own map and mode. To play with friends, enter the same portal."))
		if not profile().tutorialComplete then
			local first=UI.roundFrame(body,{Name="FirstMission",Size=UDim2.new(1,-6,0,168),BackgroundColor3=C.gold:Lerp(C.panel,0.78)},C.gold)
			UI.label(first,T("Comece aqui!","Start here!"),{Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-28,0,36),TextSize=26,Font=Enum.Font.FredokaOne,TextColor3=C.gold})
			UI.label(first,T("Aprenda em "..tostring(Catalog.Modes.tutorial.waves).." ondas e ganhe 1.000 Ouro na primeira vitória.","Learn in "..tostring(Catalog.Modes.tutorial.waves).." waves and earn 1,000 Gold on your first victory."),{Position=UDim2.fromOffset(14,46),Size=UDim2.new(1,-28,0,58),TextSize=13,TextWrapped=true})
			UI.button(first,T("Jogar o treino • "..tostring(Catalog.Modes.tutorial.waves).." ondas","Play training • "..tostring(Catalog.Modes.tutorial.waves).." waves"),startTraining,{Name="FindTrainingPortal",Position=UDim2.fromOffset(12,112),Size=UDim2.new(1,-24,0,46),BackgroundColor3=C.gold,TextSize=14})
		end
		local colors={manhattan=C.coral,gamma=C.green,asgard=C.gold,hydra=C.red,wakanda=C.violet,latveria=C.blue}
		-- Destinations as picture cards, two side by side where the window is wide:
		-- the real map photograph on top (or the drawn route), the name over it.
		local screen=screenSize()
		local width=UI.contextLayout(screen.X,screen.Y,{wide=true}).w-40
		local columns=width>=640 and 2 or 1
		local cellW=math.floor((width-(columns-1)*10)/columns)
		local grid,placed
		local function newGrid()
			grid=UI.frame(body,{Name="DestinationGrid",Size=UDim2.new(1,-6,0,0),BackgroundTransparency=1,AutomaticSize=Enum.AutomaticSize.Y})
			local layout=UI.create("UIGridLayout",{CellPadding=UDim2.fromOffset(10,10),CellSize=UDim2.fromOffset(cellW,272),SortOrder=Enum.SortOrder.LayoutOrder},grid)
			placed=0
			return layout
		end
		local photos=(ctx.Config and ctx.Config.MapImages) or {}
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
					center={T("Campanha","Campaign"),T("Os três portais do centro do refúgio. Comece por aqui!","The three portals in the middle of the refuge. Start here!")},
					expedition={T("Expedições","Expeditions"),T("Campanhas mais longas nas ilhas: Selva de Cristal e Ponte Celeste na ilha oeste, a final, Cidadela do Tirano (70 ondas), na ilha leste.","Longer campaigns on the islands: Crystal Jungle and Sky Bridge on the west island, the finale, Tyrant's Citadel (70 waves), on the east island.")},
					arena={T("Arena competitiva","Competitive arena"),T("Três portais vizinhos. Cada mapa tem seu placar e exige uma estratégia diferente.","Three neighboring portals. Each map has its own leaderboard and calls for a different strategy.")},
					special={T("Treino e cartas","Training & cards"),T("Na ilha norte: o treino de "..tostring(Catalog.Modes.tutorial.waves).." ondas e o roguelike de cartas.","On the north island: the "..tostring(Catalog.Modes.tutorial.waves).."-wave training and the card roguelike.")},
				}
				local heading=headings[district]
				if heading then UI.section(body,heading[1],heading[2]) end
				newGrid()
			end
			if not grid then newGrid() end
			placed+=1
			local allowed=Rules.ModeUnlocked(profile(),destination.modeId)
			local card=UI.roundFrame(grid,{Name="Destination_"..id,LayoutOrder=placed,BackgroundColor3=UI.Skin.slot},tint)
			UI.stroke(card,tint,3)
			-- The picture: the photograph when one is configured, the drawn route otherwise.
			local picture=UI.frame(card,{Name="DestinationPicture",Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,0,126),BackgroundColor3=tint:Lerp(C.ink,0.6),ClipsDescendants=true})
			UI.corner(picture,12)
			local photo=math.floor(tonumber(photos[destination.mapId]) or 0)
			if photo>0 then
				UI.create("ImageLabel",{Name="MapPhoto",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Image="rbxassetid://"..photo,ScaleType=Enum.ScaleType.Crop},picture)
				-- The roads as a small map in the corner, over the photograph.
				local inset=UI.mapArt(picture,map,tint,{AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-8,0,8),Size=UDim2.fromOffset(96,76)})
				UI.stroke(inset,Color3.new(1,1,1),2)
			else
				UI.mapArt(picture,map,tint,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(150,118)})
			end
			local shade=UI.frame(picture,{Name="PictureShade",AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.new(1,0,0,46),BackgroundColor3=C.ink,BackgroundTransparency=0.25})
			UI.create("UIGradient",{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(1,0)}),Rotation=90},shade)
			local title=UI.label(picture,L(map.name),{Name="DestinationName",Position=UDim2.new(0,10,1,-40),Size=UDim2.new(1,-20,0,36),TextSize=26,Font=UI.Fonts.display,TextColor3=Color3.new(1,1,1)})
			UI.outline(title,3)
			local waves=Rules.WaveCount(destination.modeId,destination.mapId)
			UI.label(card,L(mode.name).."  •  "..(waves==0 and T("sem fim","endless") or tostring(waves).." "..T("ondas","waves")),{Position=UDim2.fromOffset(12,138),Size=UDim2.new(1,-24,0,24),TextSize=18,Font=UI.Fonts.display,TextColor3=tint:Lerp(Color3.new(1,1,1),0.3),TextWrapped=true})
			UI.label(card,allowed and L(map.description) or L(kit.modeLockHints[destination.modeId]),{Position=UDim2.fromOffset(12,164),Size=UDim2.new(1,-24,0,44),TextSize=15,TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd,TextColor3=C.muted,TextYAlignment=Enum.TextYAlignment.Top})
			local featured=ctx.state().featured
			if featured and featured.mapId==destination.mapId and destination.modeId=="normal" then
				-- The map of the day pays more: a ribbon on its card.
				local ribbon=UI.label(card,"★ "..T("Mapa do dia","Map of the day").."  +"..math.floor(featured.bonus*100+0.5).."%",{Name="FeaturedRibbon",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,-8),Size=UDim2.fromOffset(176,24),BackgroundTransparency=0,BackgroundColor3=C.gold,TextColor3=C.background,TextSize=12,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=3})
				UI.corner(ribbon,12)
			end
			local event=ctx.state().event
			if event and event.active and event.mapId==destination.mapId and destination.modeId=="normal" then
				-- The weekend event's map pays over: a second ribbon, under the day's if both.
				local stacked=featured and featured.mapId==destination.mapId
				local ribbon=UI.label(card,"✦ "..T("Evento","Event").."  ×"..tostring(event.goldScale or 2),{Name="EventRibbon",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,stacked and 20 or -8),Size=UDim2.fromOffset(150,24),BackgroundTransparency=0,BackgroundColor3=C.coral,TextColor3=C.background,TextSize=12,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=3})
				UI.corner(ribbon,12)
			end
			local button=UI.button(card,allowed and T("Encontrar portal","Find portal") or T("Ainda bloqueado","Locked for now"),function() routePreview.goPortal(id) end,{Name="FindPortal_"..id,Position=UDim2.new(0,10,1,-56),Size=UDim2.new(1,-20,0,46),BackgroundColor3=allowed and C.green or tint,TextSize=20})
			if not allowed then
				UI.disabled(button)
				-- A lock sticker over the map art, like a locked level card.
				local lock=UI.label(card,T("Bloqueado","Locked"),{Name="LockedPill",Position=UDim2.fromOffset(16,16),Size=UDim2.fromOffset(110,28),BackgroundTransparency=0,BackgroundColor3=C.ink,TextSize=15,Font=UI.Fonts.display,TextXAlignment=Enum.TextXAlignment.Center,ZIndex=3})
				UI.corner(lock,12)
				UI.stroke(lock,Color3.new(1,1,1),1.5)
			end
			if destination.modeId=="ranked" then
				button.Size=UDim2.new(0.62,-16,0,46)
				UI.secondary(card,T("Placar","Leaderboard"),function()
					board.mode="ranked"; board.map=destination.mapId; openContext("leaderboard",{})
				end,{Name="DestinationBoard_"..id,Position=UDim2.new(0.62,0,1,-56),Size=UDim2.new(0.38,-10,0,46),TextSize=17})
			end
		end
		if profile().tutorialComplete then
			UI.secondary(body,T("Treinar de novo • "..tostring(Catalog.Modes.tutorial.waves).." ondas","Train again • "..tostring(Catalog.Modes.tutorial.waves).." waves"),startTraining,{Size=UDim2.new(1,-6,0,44)})
		end
	end

	local function contextBases(body)
		local activeId=profile().equippedBase or "outpost"
		local active=Catalog.Bases[activeId] or Catalog.Bases.outpost
		local activeStats=Rules.BaseStats(activeId,1)
		local screen=screenSize()
		local width=UI.contextLayout(screen.X,screen.Y,{wide=true}).w-40
		local narrow=width<420
		-- The base in use, big, with what it gives and where it is upgraded.
		local summary=UI.roundFrame(body,{Name="ActiveBaseSummary",Size=UDim2.new(1,-6,0,narrow and 196 or 150),BackgroundColor3=UI.Skin.slot},C.green)
		UI.stroke(summary,C.green,3)
		UI.basePortrait(summary,active,{Position=UDim2.fromOffset(10,12),Size=UDim2.fromOffset(narrow and 92 or 110,narrow and 100 or 118)})
		local textX=narrow and 112 or 132
		UI.pill(summary,T("Base ativa","Active base"),C.green:Lerp(C.ink,0.2),{Position=UDim2.fromOffset(textX,12),TextSize=15})
		UI.fit(UI.label(summary,L(active.name),{Name="ActiveBaseName",Position=UDim2.fromOffset(textX,44),Size=UDim2.new(1,-textX-12,0,34),TextWrapped=true,TextSize=26,Font=UI.Fonts.display}),14)
		UI.fit(UI.label(summary,"+"..activeStats.income..T(" Ouro por onda"," Gold per wave")..(activeStats.hp>0 and ("  •  +"..activeStats.hp..T(" de vida"," HP")) or ""),{Name="ActiveBaseIncome",Position=UDim2.fromOffset(textX,80),Size=UDim2.new(1,-textX-12,0,narrow and 36 or 24),TextWrapped=narrow,TextSize=18,Font=UI.Fonts.display,TextColor3=C.gold}),11)
		UI.fit(UI.label(summary,T("Entra na sua próxima partida. Evolua com o Agente da Base ao lado dela (tecla E).","Deploys in your next match. Upgrade it with the Base Agent beside it (E key)."),{Name="ActiveBaseHow",Position=narrow and UDim2.fromOffset(12,124) or UDim2.fromOffset(132,106),Size=narrow and UDim2.new(1,-24,0,62) or UDim2.new(1,-144,0,40),TextWrapped=true,TextSize=15,TextColor3=C.muted}),11)

		UI.button(body,T("Ir à loja de bases","Go to the base shop"),function() routePreview.goShop("base_rare") end,{Size=UDim2.new(1,-6,0,50),BackgroundColor3=C.gold,TextSize=20})
		-- Every base as a tile: picture, name, rarity, what it gives, one button.
		local columns=width>=640 and 3 or (width>=420 and 2 or 1)
		local cellW=math.floor((width-(columns-1)*10)/columns)
		local cellH=286
		local grid=UI.frame(body,{Name="BaseGrid",Size=UDim2.new(1,-6,0,math.ceil(#Catalog.BaseOrder/columns)*(cellH+10)-10),BackgroundTransparency=1})
		for index,id in ipairs(Catalog.BaseOrder) do
			local def=Catalog.Bases[id]; local stats=Rules.BaseStats(id,1)
			local owned=(profile().bases or {outpost=true})[id]; local equipped=(profile().equippedBase or "outpost")==id
			local tint=UI.color(Catalog.Rarities[def.rarity].color)
			local row=UI.roundFrame(grid,{Name="BaseCard_"..id,Position=UDim2.fromOffset(((index-1)%columns)*(cellW+10),math.floor((index-1)/columns)*(cellH+10)),Size=UDim2.fromOffset(cellW,cellH),BackgroundColor3=UI.Skin.slot},equipped and C.green or tint)
			UI.stroke(row,equipped and C.green or tint,equipped and 3.5 or 2.5)
			local stage=UI.frame(row,{Name="BaseStage",Position=UDim2.fromOffset(8,8),Size=UDim2.new(1,-16,0,104),BackgroundColor3=tint})
			UI.corner(stage,12)
			UI.create("UIGradient",{Color=ColorSequence.new(tint:Lerp(Color3.new(1,1,1),0.15),tint:Lerp(C.ink,0.55)),Rotation=90},stage)
			UI.cardSkin(stage,tint)
			UI.multiverseSeal(stage,C.cream,{Position=UDim2.fromScale(0.25,0),Size=UDim2.fromScale(0.5,1),ZIndex=0})
			UI.basePortrait(stage,def,{AnchorPoint=Vector2.new(0.5,0),Position=UDim2.new(0.5,0,0,4),Size=UDim2.fromOffset(100,96)})
			if not owned then
				local shade=UI.frame(stage,{Name="NotOwned",Size=UDim2.fromScale(1,1),BackgroundColor3=C.ink,BackgroundTransparency=0.45})
				UI.corner(shade,12)
				UI.icon(shade,"lock",C.cream,{AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(0.5,0.5),Size=UDim2.fromOffset(34,34)})
			end
			UI.label(row,L(def.name),{Position=UDim2.fromOffset(12,116),Size=UDim2.new(1,-24,0,30),TextSize=21,TextWrapped=true,Font=UI.Fonts.display})
			UI.label(row,L(Catalog.Rarities[def.rarity].name),{Position=UDim2.fromOffset(12,144),Size=UDim2.new(1,-24,0,20),TextSize=15,Font=UI.Fonts.display,TextColor3=tint:Lerp(Color3.new(1,1,1),0.35)})
			UI.label(row,L(def.description),{Position=UDim2.fromOffset(12,166),Size=UDim2.new(1,-24,0,40),TextSize=14,TextWrapped=true,TextTruncate=Enum.TextTruncate.AtEnd,TextColor3=C.muted,TextYAlignment=Enum.TextYAlignment.Top})
			UI.label(row,"+"..stats.income..T(" Ouro/onda"," Gold/wave")..(stats.hp>0 and ("  •  +"..stats.hp..T(" vida*"," HP*")) or ""),{Position=UDim2.fromOffset(12,206),Size=UDim2.new(1,-24,0,22),TextSize=15,Font=UI.Fonts.display,TextColor3=C.gold})
			local button=UI.button(row,equipped and T("Base ativa","Active base") or owned and T("Ativar base","Activate base") or T("Encontrar nos baús","Find in chests"),function()
				if owned then act("EquipBase",{baseId=id},function() showToast(T("Base ativada! Ela aparecerá na próxima partida.","Base activated! It will deploy in your next match.")) end) else routePreview.goShop("base_rare") end
			end,{Name="EquipBase_"..id,Position=UDim2.new(0,10,1,-54),Size=UDim2.new(1,-20,0,44),BackgroundColor3=equipped and C.green or (owned and C.blue or C.card),TextSize=18})
			if equipped then UI.disabled(button) end
		end
		smallText(body,T("*No grupo, cada bônus de vida é dividido pelo tamanho inicial da equipe. Renda exige contribuição na onda.","*In co-op, each HP bonus is divided by the starting party size. Income requires wave contribution."),0,60)
	end

	local contextBuilders = {
		maps=contextModes,
		bases=contextBases,
		modes=contextModes,
		talents = contextTalents,
		hero = contextHero, chests = contextChests, premium = contextPremium, pick = exchange.pick, trade = exchange.trade, inventory = contextSquad, shop = contextShop,
		quests = contextQuests, leaderboard = contextLeaderboard, squad = contextSquad, settings = contextSettings,
		rewards = contextRewards,
	}

	return { contextBuilders = contextBuilders, loadBoard = loadBoard, buildTalents = buildTalents }
end

return Panels
