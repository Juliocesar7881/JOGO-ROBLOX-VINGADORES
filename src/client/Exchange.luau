-- Heroes that change hands outside a chest: the picks a bundle paid for
-- (Catalog.Products.Consumables.*.heroPicks, action PickHero) and trading one
-- hero for one with a Roblox friend (Catalog.Trade, the Trade* actions). Split
-- out of Panels.luau for the script size limit; built with the same `ctx`.
-- Purely presentation: the server decides every credit, rule and swap.
local Exchange = {}

function Exchange.new(ctx)
	local C, Catalog, L, T, UI, act = ctx.C, ctx.Catalog, ctx.L, ctx.T, ctx.UI, ctx.act
	local heroPortrait, kit, number, player, profile, showToast = ctx.heroPortrait, ctx.kit, ctx.number, ctx.player, ctx.profile, ctx.showToast
	local openContext, renderContext = ctx.openContext, ctx.renderContext

	-- How many bundle heroes are still to be chosen (profile.heroPicks, by rarity).
	local function heroPicksLeft()
		local total=0
		for _,count in pairs(type(profile().heroPicks)=="table" and profile().heroPicks or {}) do total+=math.max(0,math.floor(tonumber(count) or 0)) end
		return total
	end

	-- A bundle's heroes, chosen here: one credit per hero of the paid rarity.
	-- The server spends the credit; a hero already owned pays like a duplicate.
	local function contextPick(body)
		local p=profile()
		local picks=type(p.heroPicks)=="table" and p.heroPicks or {}
		local any=false
		for _,rarity in ipairs(Catalog.RarityOrder) do
			local left=math.floor(tonumber(picks[rarity]) or 0)
			if left<=0 then continue end
			any=true
			local def=Catalog.Rarities[rarity]
			local tint=UI.color(def.color)
			local head=UI.row(body,34)
			UI.fit(UI.label(head,(left==1 and T("Escolha 1 herói ","Choose 1 ") or T("Escolha "..left.." heróis ","Choose "..left.." "))..Catalog.Upper(L(def.name)),{Name="PickHeading_"..rarity,Size=UDim2.new(1,0,1,0),Font=UI.Fonts.display,TextSize=22,TextColor3=tint}),12)
			local ids={}
			for id,hero in pairs(Catalog.Heroes) do if hero.rarity==rarity then table.insert(ids,id) end end
			-- Heroes you do not own come first; owned ones say what a duplicate pays.
			table.sort(ids,function(a,b)
				local oa,ob=(p.heroes or {})[a]~=nil,(p.heroes or {})[b]~=nil
				if oa~=ob then return not oa end
				return L(Catalog.Heroes[a].name)<L(Catalog.Heroes[b].name)
			end)
			for _,id in ipairs(ids) do
				local hero=Catalog.Heroes[id]
				local mine=(p.heroes or {})[id]~=nil
				local row=UI.roundFrame(body,{Name="PickRow_"..id,Size=UDim2.new(1,-6,0,84),BackgroundColor3=UI.Skin.slot},tint)
				UI.hover(row,function(box) kit.heroTooltip(box,id) end,330)
				heroPortrait(row,id,{Position=UDim2.fromOffset(8,6),Size=UDim2.fromOffset(72,72)})
				UI.fit(UI.label(row,L(hero.name),{Position=UDim2.fromOffset(92,10),Size=UDim2.new(1,-260,0,28),Font=UI.Fonts.display,TextSize=20}),12)
				local line=mine and (T("Já é seu: vira estrela e ","Already yours: a star and ")..number(def.duplicate.gold)..T(" Ouro"," Gold")) or (T("Dano ","Damage ")..tostring(hero.damage).."  •  "..T("Alcance ","Range ")..tostring(hero.range))
				UI.fit(UI.label(row,line,{Position=UDim2.fromOffset(92,42),Size=UDim2.new(1,-260,0,24),TextSize=14,TextColor3=C.muted}),10)
				UI.button(row,T("Escolher","Choose"),function()
					act("PickHero",{heroId=id},function(data)
						local result=type(data)=="table" and data.result
						showToast(L(hero.name)..((type(result)=="table" and result.duplicate) and T(" virou estrela e Ouro."," became a star and Gold.") or T(" entrou para a sua coleção!"," joined your collection!")))
						renderContext()
					end)
				end,{Name="Pick_"..id,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),Size=UDim2.fromOffset(150,50),BackgroundColor3=mine and C.card or C.green,TextSize=18})
			end
		end
		if not any then
			UI.label(body,T("Nenhuma escolha pendente. Os pacotes Lendário e Equipe dão heróis à sua escolha.","No pick pending. The Legendary and Team packs give heroes of your choice."),{Size=UDim2.new(1,-6,0,60),TextWrapped=true,TextSize=16,TextColor3=C.muted})
			UI.button(body,T("Ver pacotes","See packs"),function() openContext("premium",{shopKind="product"}) end,{Name="PickToShop",Size=UDim2.new(1,-6,0,48),BackgroundColor3=C.gold,TextSize=17})
		end
	end

	-- Trading, one hero for one, with a Roblox friend in this server. Every rule
	-- is the server's (PlayerService trade actions); this only draws its view.
	local function contextTrade(body)
		local p=profile()
		local trade=type(p.trade)=="table" and p.trade or nil
		local left=tonumber(p.tradesLeft) or 0
		if not trade then
			UI.label(body,T("Troque 1 herói por 1 herói com um amigo do Roblox que esteja neste servidor. Nunca Ouro, nunca heróis iniciais nem os da sua equipe.","Trade 1 hero for 1 hero with a Roblox friend in this server. Never Gold, never starter heroes or the ones on your team."),{Name="TradeIntro",Size=UDim2.new(1,-6,0,64),TextWrapped=true,TextSize=15,TextColor3=C.muted})
			UI.label(body,left==1 and T("1 troca restante hoje","1 trade left today") or (tostring(left)..T(" trocas restantes hoje"," trades left today")),{Name="TradesLeft",Size=UDim2.new(1,-6,0,24),TextSize=14,TextColor3=C.gold})
			local others={}
			for _,entry in ipairs(ctx.state().players or {}) do if entry.userId~=player.UserId then table.insert(others,entry) end end
			if #others==0 then UI.label(body,T("Ninguém mais está neste servidor agora.","Nobody else is in this server right now."),{Name="TradeNobody",Size=UDim2.new(1,-6,0,40),TextSize=16,TextWrapped=true}) end
			for _,entry in ipairs(others) do
				local row=UI.roundFrame(body,{Name="TradeWith_"..tostring(entry.userId),Size=UDim2.new(1,-6,0,64),BackgroundColor3=UI.Skin.slot})
				UI.fit(UI.label(row,tostring(entry.name or "?").."  •  NV "..tostring(entry.level or 1),{Position=UDim2.fromOffset(14,8),Size=UDim2.new(1,-190,0,48),Font=UI.Fonts.display,TextSize=18}),12)
				local invite=UI.button(row,T("Convidar","Invite"),function() act("TradeOffer",{userId=entry.userId}) end,{Name="TradeInvite_"..tostring(entry.userId),AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),Size=UDim2.fromOffset(150,46),BackgroundColor3=C.green,TextSize=17})
				if left<=0 then UI.disabled(invite) end
			end
			return
		end
		local partner=tostring(trade.partnerName or "?")
		if trade.stage=="invited" then
			if trade.invited then
				UI.label(body,partner..T(" quer trocar um herói com você."," wants to trade a hero with you."),{Name="TradeInviteText",Size=UDim2.new(1,-6,0,48),TextWrapped=true,TextSize=18,Font=UI.Fonts.display})
				UI.button(body,T("Aceitar","Accept"),function() act("TradeAccept",{}) end,{Name="TradeAccept",Size=UDim2.new(1,-6,0,50),BackgroundColor3=C.green,TextSize=18})
				UI.button(body,T("Recusar","Decline"),function() act("TradeCancel",{}) end,{Name="TradeCancel",Size=UDim2.new(1,-6,0,46),BackgroundColor3=C.red,TextSize=16})
			else
				UI.label(body,T("Esperando ","Waiting for ")..partner..T(" aceitar…"," to accept…"),{Name="TradeWaiting",Size=UDim2.new(1,-6,0,48),TextWrapped=true,TextSize=18,Font=UI.Fonts.display})
				UI.button(body,T("Cancelar","Cancel"),function() act("TradeCancel",{}) end,{Name="TradeCancel",Size=UDim2.new(1,-6,0,46),BackgroundColor3=C.red,TextSize=16})
			end
			return
		end
		-- Open: the two offers side by side, then the confirm and the cancel.
		local board=UI.row(body,150)
		board.Name="TradeBoard"
		local function side(x,title,heroId,confirmed,name)
			local box=UI.roundFrame(board,{Name=name,Position=UDim2.fromScale(x,0),Size=UDim2.new(0.5,-6,1,0),BackgroundColor3=UI.Skin.slot},confirmed and C.green or C.ink)
			UI.fit(UI.label(box,title,{Position=UDim2.fromOffset(10,6),Size=UDim2.new(1,-20,0,22),Font=UI.Fonts.display,TextSize=16}),10)
			local def=heroId and Catalog.Heroes[heroId]
			if def then
				heroPortrait(box,heroId,{Position=UDim2.fromOffset(10,32),Size=UDim2.fromOffset(84,84)})
				UI.fit(UI.label(box,L(def.name),{Position=UDim2.fromOffset(102,36),Size=UDim2.new(1,-112,0,24),Font=UI.Fonts.display,TextSize=16}),10)
				UI.chip(box,Catalog.Upper(L(Catalog.Rarities[def.rarity].name)),UI.color(Catalog.Rarities[def.rarity].color),{Position=UDim2.fromOffset(102,64),Size=UDim2.fromOffset(100,20),TextSize=11})
			else
				UI.label(box,T("Nada ainda","Nothing yet"),{Position=UDim2.fromOffset(10,32),Size=UDim2.new(1,-20,0,84),TextSize=15,TextColor3=C.muted})
			end
			if confirmed then UI.chip(box,T("Confirmado","Confirmed"),C.green,{Name=name.."Confirmed",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-8,1,-8),Size=UDim2.fromOffset(110,22),TextSize=12}) end
		end
		side(0,T("Você dá","You give"),trade.mine,trade.myConfirm,"TradeMine")
		side(0.5,partner..T(" dá"," gives"),trade.theirs,trade.theirConfirm,"TradeTheirs")
		if trade.unequal then UI.chip(body,T("Troca desigual: raridades diferentes","Unequal trade: different rarities"),C.red,{Name="TradeUnequal",Size=UDim2.new(1,-6,0,28),TextSize=13}) end
		local lockLeft=math.max(0,math.ceil((tonumber(trade.lockedUntil) or 0)-os.time()))
		local ready=trade.mine~=nil and trade.theirs~=nil and lockLeft<=0
		local label=trade.myConfirm and (T("Esperando ","Waiting for ")..partner) or (lockLeft>0 and (T("Aguarde ","Wait ")..tostring(lockLeft).."s") or (trade.unequal and T("Confirmar mesmo assim","Confirm anyway") or T("Confirmar troca","Confirm trade")))
		local confirm=UI.button(body,label,function() act("TradeConfirm",{acceptUnequal=trade.unequal==true}) end,{Name="TradeConfirm",Size=UDim2.new(1,-6,0,52),BackgroundColor3=trade.unequal and C.coral or C.green,TextSize=19})
		if not ready or trade.myConfirm then UI.disabled(confirm) end
		if lockLeft>0 then
			-- Redraw when the wait ends, so the button wakes up by itself.
			kit.tradeTick=(kit.tradeTick or 0)+1
			local tick=kit.tradeTick
			task.delay(lockLeft+0.2,function() if kit.tradeTick==tick and type(profile().trade)=="table" then renderContext() end end)
		end
		UI.button(body,T("Cancelar troca","Cancel trade"),function() act("TradeCancel",{}) end,{Name="TradeCancel",Size=UDim2.new(1,-6,0,44),BackgroundColor3=C.red,TextSize=16})
		-- What I can offer: no starters, nothing on my team (the server is the judge).
		UI.label(body,T("Escolha o que você oferece","Choose what you offer"),{Size=UDim2.new(1,-6,0,28),Font=UI.Fonts.display,TextSize=18})
		local ids={}
		for id in pairs(p.heroes or {}) do
			local def=Catalog.Heroes[id]
			local onTeam=table.find(p.loadout or {},id)~=nil
			if def and not def.starter and not onTeam then table.insert(ids,id) end
		end
		table.sort(ids,function(a,b)
			local ra,rb=table.find(Catalog.RarityOrder,Catalog.Heroes[a].rarity) or 0,table.find(Catalog.RarityOrder,Catalog.Heroes[b].rarity) or 0
			if ra~=rb then return ra>rb end
			return L(Catalog.Heroes[a].name)<L(Catalog.Heroes[b].name)
		end)
		if #ids==0 then UI.label(body,T("Nenhum herói disponível para troca.","No hero available to trade."),{Name="TradeNothing",Size=UDim2.new(1,-6,0,40),TextSize=15,TextColor3=C.muted}) end
		for _,id in ipairs(ids) do
			local def=Catalog.Heroes[id]
			local tint=UI.color(Catalog.Rarities[def.rarity].color)
			local selected=trade.mine==id
			local row=UI.roundFrame(body,{Name="TradeOffer_"..id,Size=UDim2.new(1,-6,0,64),BackgroundColor3=UI.Skin.slot},selected and C.green or tint)
			heroPortrait(row,id,{Position=UDim2.fromOffset(6,4),Size=UDim2.fromOffset(56,56)})
			UI.fit(UI.label(row,L(def.name),{Position=UDim2.fromOffset(72,8),Size=UDim2.new(1,-240,0,24),Font=UI.Fonts.display,TextSize=17}),10)
			UI.chip(row,Catalog.Upper(L(Catalog.Rarities[def.rarity].name)),tint,{Position=UDim2.fromOffset(72,36),Size=UDim2.fromOffset(100,20),TextSize=11})
			UI.button(row,selected and T("Retirar","Withdraw") or T("Oferecer","Offer"),function() act("TradeSet",selected and {} or {heroId=id}) end,{Name="TradeSet_"..id,AnchorPoint=Vector2.new(1,0.5),Position=UDim2.new(1,-10,0.5,0),Size=UDim2.fromOffset(140,46),BackgroundColor3=selected and C.card or C.blue,TextSize=16})
		end
	end

	return { heroPicksLeft = heroPicksLeft, pick = contextPick, trade = contextTrade }
end

return Exchange
