-- Full-screen AFK presentation. Every counter comes from server attributes;
-- this view neither predicts awards nor owns a payment/save/reconnect loop.
local Art = require(game:GetService("ReplicatedFirst"):WaitForChild("DoomLoader"):WaitForChild("ScreenArt"))
local RestScreen = {}

function RestScreen.new(UI, parent, T, Catalog, size, kind, callbacks)
	local C=UI.Colors
	callbacks=callbacks or {}
	local farm=Catalog.Afk[kind]
	assert(farm,"Unknown AFK presentation")
	local w,h=size.X,size.Y
	local portrait=w<600
	local short=h<440
	local tint=kind=="gold" and C.gold or C.violet
	local root=UI.frame(parent,{Name="AfkScreen",Size=UDim2.fromScale(1,1),BackgroundColor3=C.background,Active=true,ZIndex=60})
	root:SetAttribute("AfkKind",kind)
	local backdrop=Art.Draw(root,kind,w,h+80,60)
	backdrop.Position=UDim2.fromOffset(0,-80)
	backdrop.Size=UDim2.new(1,0,1,80)
	local function label(parent,name,text,x,y,width,height,fs,color,display)
		return UI.fit(UI.label(parent,text,{Name=name,Position=UDim2.fromOffset(x,y),Size=UDim2.fromOffset(width,height),TextSize=fs,
			TextColor3=color or C.text,Font=display and UI.Fonts.display or UI.Fonts.body,TextWrapped=true,ZIndex=72}),11)
	end
	label(root,"AfkBrand",T("MULTIVERSO / REFÚGIO","MULTIVERSE / REFUGE"),portrait and 20 or 32,short and 16 or 28,w-40,24,13,C.muted)
	local title=kind=="gold" and T("Farm de Ouro AFK","AFK Gold Farm") or T("Farm de XP AFK","AFK XP Farm")
	label(root,"AfkScreenTitle",title,portrait and 20 or 32,short and 44 or 64,portrait and w-40 or w*0.5,short and 38 or 52,portrait and 30 or (short and 25 or 38),tint,true)
	if not short then
		label(root,"AfkChamber",kind=="gold" and T("CÂMARA DE RECURSOS","RESOURCE CHAMBER") or T("NÚCLEO DE TREINO","TRAINING CORE"),portrait and 20 or 34,portrait and 114 or 124,portrait and w-40 or w*0.45,26,13,C.muted)
	end
	local cw=portrait and w-32 or math.min(w*0.46,480)
	local ch=short and 270 or 380
	local card=UI.frame(root,{Name="AfkDashboard",AnchorPoint=Vector2.new(0.5,0.5),Position=UDim2.fromScale(portrait and 0.5 or 0.745,portrait and 0.61 or 0.56),Size=UDim2.fromOffset(cw,ch),BackgroundColor3=C.panel,ZIndex=71})
	if portrait then card.Position=UDim2.new(0.5,0,0,math.min(h*0.61,h-82-ch/2)) end
	UI.angular(card,tint,{cut=16})
	local pad=short and 16 or 24
	local inner=cw-pad*2
	local function field(name,text,y,height,fs,color,display)
		return label(card,name,text,pad,y,inner,height,fs,color,display)
	end
	field("AfkReceivedLabel",T("RECEBIDO NESTA SESSÃO","RECEIVED THIS SESSION"),short and 12 or 22,20,short and 11 or 13,C.muted)
	local earned=field("AfkScreenEarned","",short and 36 or 49,short and 44 or 62,short and 32 or 46,tint,true)
	local saved=field("AfkScreenSaved","",short and 82 or 118,24,short and 12 or 14,C.muted)
	local separator=UI.frame(card,{Name="AfkDivider",Position=UDim2.fromOffset(pad,short and 112 or 158),Size=UDim2.new(1,-pad*2,0,1),BackgroundColor3=tint,BackgroundTransparency=0.65,Active=false,ZIndex=72})
	local timerY=short and 121 or 176
	local nextLabel=field("AfkNextLabel",T("Próximo pagamento","Next payment"),timerY,24,short and 13 or 16,C.muted)
	nextLabel.Size=UDim2.fromOffset(inner-68,24)
	local nextTime=label(card,"AfkScreenNext","",cw-pad-68,timerY-3,68,30,short and 22 or 28,C.text,true)
	nextTime.TextXAlignment=Enum.TextXAlignment.Right
	local track=UI.frame(card,{Name="AfkPaymentTrack",Position=UDim2.fromOffset(pad,timerY+35),Size=UDim2.new(1,-pad*2,0,8),BackgroundColor3=C.background,ClipsDescendants=true,Active=false,ZIndex=72})
	UI.corner(track,4)
	local fill=UI.frame(track,{Name="AfkPaymentFill",Size=UDim2.fromScale(0,1),BackgroundColor3=tint,Active=false,ZIndex=73})
	UI.corner(fill,4)
	local session=field("AfkScreenSession","",timerY+52,24,short and 12 or 14,C.muted)
	local buttonY=ch-(short and 62 or 74)
	local bw=(inner-10)/2
	UI.button(card,T("Mostrar jogo","Show game"),callbacks.show,{Name="AfkEcoOff",Position=UDim2.fromOffset(pad,buttonY),Size=UDim2.fromOffset(bw,48),BackgroundColor3=C.blue,TextSize=short and 13 or 16,ZIndex=74})
	UI.button(card,T("Voltar ao lobby","Back to lobby"),callbacks.leave,{Name="AfkLeave",Position=UDim2.fromOffset(pad+bw+10,buttonY),Size=UDim2.fromOffset(bw,48),BackgroundColor3=C.red,TextSize=short and 13 or 16,ZIndex=74})
	-- The rate is catalog copy, not a promise extrapolated from a local timer.
	local rate=label(root,"AfkRate",T(farm.rate.pt,farm.rate.en),portrait and 20 or 32,short and h-38 or h-68,portrait and w-40 or w*0.46,26,short and 15 or 20,tint,true)
	if not short then label(root,"AfkSaverHint",T("Modo de economia ativo","Power saver active"),portrait and 20 or 34,h-38,w-40,22,12,C.muted) end
	local function update(data)
		local value=math.max(0,tonumber(data.earned) or 0)
		local seconds=math.max(0,math.floor(tonumber(data.session) or 0))
		local remaining=math.clamp(tonumber(data.nextPayment) or Catalog.Afk.interval,0,Catalog.Afk.interval)
		earned.Text="+"..UI.format(value)..(kind=="gold" and T(" Ouro"," Gold") or " XP")
		saved.Text=data.saving and T("Salvando pagamento…","Saving payment…") or (value>0 and T("Pagamento confirmado e salvo","Payment confirmed and saved") or T("Aguardando o primeiro pagamento","Waiting for the first payment"))
		saved.TextColor3=data.saving and C.gold or (value>0 and C.green or C.muted)
		nextTime.Text=data.saving and "…" or string.format("%02ds",math.ceil(remaining))
		fill.Size=UDim2.fromScale(1-remaining/Catalog.Afk.interval,1)
		session.Text=T("Tempo nesta sessão  ","Time this session  ")..string.format("%d:%02d",math.floor(seconds/60),seconds%60)
	end
	update({})
	return {root=root,Update=update,kind=kind,sizeKey=tostring(w)..":"..tostring(h)}
end

return RestScreen
