local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local Match = {}
Match.__index = Match

local function finite(n) return type(n) == "number" and n == n and math.abs(n) < 1e7 end
local function validPosition(v) return typeof(v) == "Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z) end
local function contains(list, value) return table.find(list or {}, value) ~= nil end
local function distanceXZ(a, b) return Vector2.new(a.X - b.X, a.Z - b.Z).Magnitude end
local function segmentDistance(p, a, b)
	local d = b - a
	local t = d:Dot(d) > 0 and math.clamp((p-a):Dot(d) / d:Dot(d), 0, 1) or 0
	return (p - (a + d*t)).Magnitude
end
local function talent(p, id) return (p.profile.talents or {})[id] or 0 end
local function cardStat(p, key) return (p.mods and p.mods[key]) or 0 end
-- The account XP a commander really banks, for the results screen: the
-- training pass and the Hero academy talent (PlayerService:Award applies both).
local function xpScale(p, rules)
	return (p.profile.passes and p.profile.passes.training and 1.25 or 1) * (1 + rules.TalentEffect(p.profile, "xpBoost"))
end

-- Bosses shrug off percentage attacks: an ability that takes a third of an
-- ordinary enemy's health takes a small slice of a boss's.
local BOSS_SHARE = 0.12
-- A stunned boss is held for a quarter of the time and then cannot be held
-- again for a while, so no ability chain can lock one down for good.
local BOSS_STUN_SHARE, BOSS_STUN_IMMUNITY = 0.25, 15
-- Seconds a commander has to choose a card before the next wave begins.
local CARD_SECONDS = 30

local STATUS = { stunned = 1, slowed = 2, marked = 4, burning = 8, shielded = 16, weakened = 32, vulnerable = 64, revealed = 128, boosted = 256 }
-- Every boss power leaves an opening: for a few seconds after it the boss
-- takes extra damage, shown over its head, so the rhythm rewards timing.
local VULNERABLE_SECONDS, VULNERABLE_BONUS = 3, 0.25

-- One lesson per tutorial wave, in the order a new commander actually needs
-- them (the training is short: Catalog.Modes.tutorial.waves). Keyed by wave
-- number; the "final" lesson always goes with the last wave, the boss.
local TUTORIAL_LESSONS = {
	[1] = {
		"Cada inimigo derrotado derruba Ouro no chão. Ande perto das moedas para pegar: é com esse Ouro que você compra e melhora heróis.",
		"Every defeated enemy drops Gold on the ground. Walk near the coins to pick them up: that Gold buys and upgrades your heroes.",
	},
	[2] = {
		"Toque em uma torre para melhorar, vender ou mudar a prioridade.",
		"Select a tower to upgrade, sell or change targeting.",
	},
	[3] = {
		"Sua habilidade ativa vem do herói no PRIMEIRO slot da equipe. Use o botão grande durante a onda: ela recarrega sozinha.",
		"Your active ability comes from the hero in the FIRST slot of your squad. Use the big button during a wave; it recharges on its own.",
	},
	[4] = {
		"Antes de cada onda o aviso mostra as ameaças. Tocar em PRONTO começa a onda mais cedo; 2x e AUTO deixam a partida mais rápida.",
		"Before each wave the banner lists the threats. Pressing READY starts the wave early; 2x and AUTO speed the match up.",
	},
	[5] = {
		"Na árvore de Evolução do lobby, Magnetismo aumenta o raio do ímã que puxa o Ouro do chão.",
		"In the lobby's Talent tree, Magnetism widens the magnet that pulls Gold off the ground.",
	},
	final = {
		"Última onda: derrote o chefe para concluir o treino e ganhar 1.000 de Ouro para abrir baús no lobby.",
		"Final wave: beat the boss to finish training and earn 1,000 Gold to open chests in the lobby.",
	},
}

function Match.new(config, catalog, rules, waves, profiles, world, remotes, changed)
	return setmetatable({ config=config, catalog=catalog, rules=rules, waves=waves, profiles=profiles,
		world=world, remotes=remotes, changed=changed, running=false, phase="Lobby", participants={},
		enemies={}, towers={}, rewardQueue={}, nextId=0, syncTimer=0, rewardTimer=0, hitBuffer={}, critBuffer={}, speed=1,
		landings={}, landingClock=0, landingSerial=0 }, Match)
end

-- How many seconds of match time pass per real second. 2 only while every
-- commander still playing asked for it, so nobody is ever rushed by a
-- teammate; a solo player decides alone. The bootstrap multiplies its real
-- frame time by this before stepping the simulation.
function Match:Speed()
	if not self.running then return 1 end
	-- Choosing a card is never rushed: while anyone present still has an offer
	-- open, the clock runs at normal speed whatever was voted.
	for _, p in pairs(self.participants) do
		if not p.returned and not p.disconnectedAt and #p.cardOffers > 0 then return 1 end
	end
	return self.speed or 1
end

-- 2x needs everyone present to agree. 3x belongs to the pass: a commander who
-- owns it and chose 3x sets the whole match to 3x alone, with nobody's leave
-- (SetSpeed refuses 3x to anyone without the pass).
function Match:_refreshSpeed()
	local slowest, three = nil, false
	for _, p in pairs(self.participants) do
		if not p.returned and not p.disconnectedAt then
			local vote = p.speedVote or 1
			slowest = math.min(slowest or 3, vote)
			if vote >= 3 and p.profile.passes and p.profile.passes.speed3 then three = true end
		end
	end
	self.speed = three and 3 or math.min(slowest or 1, 2)
end

-- Preparation ends early once everyone either pressed READY or has
-- auto-skip on (and no card waiting to be chosen). It still leaves one real
-- second, so the wave never starts on the same frame as the last one ended.
function Match:_checkSkip()
	if self.phase ~= "Preparing" then return end
	for uid, other in pairs(self.participants) do
		if not other.returned and not self.skipVotes[uid] and not (other.autoSkip and #other.cardOffers == 0) then return end
	end
	self.prepRemaining = math.min(self.prepRemaining, 1)
end

function Match:_fx(event, player)
	if player then
		if player.Parent == Players then self.remotes.FX:FireClient(player, event) end
	else
		for _, p in pairs(self.participants) do
			if not p.returned and p.player.Parent == Players then self.remotes.FX:FireClient(p.player, event) end
		end
	end
end

-- One server frame's shots travel together: at 3x with a full squad that is
-- one event per frame instead of hundreds per second.
function Match:BeginShots()
	self.shotBuffer = self.shotBuffer or {}
	self.windupBuffer = self.windupBuffer or {}
end

function Match:FlushShots()
	local shots, windups = self.shotBuffer, self.windupBuffer
	self.shotBuffer, self.windupBuffer = nil, nil
	if (shots and #shots > 0) or (windups and #windups > 0) then
		self:_fx({kind="Shots",shots=shots or {},windups=windups})
	end
end

function Match:_notice(pt, en, tone)
	self:_fx({kind="Notice", text={pt=pt,en=en},tone=tone or "info"})
end

function Match:Has(player)
	local p = self.participants[player.UserId]
	return p ~= nil and not p.returned
end

function Match:CanStart()
	if self.running then return false end
	for _, p in pairs(self.participants) do if not p.returned and p.player.Parent == Players then return false end end
	return true
end

function Match:Start(members, mapId, modeId, runId, difficultyId)
	if not self:CanStart() then return false, "Já existe uma partida neste servidor. / A match is already active." end
	if not self.catalog.Maps[mapId] or not self.catalog.Modes[modeId] then return false, "Mapa ou modo inválido. / Invalid map or mode." end
	if #members < 1 or #members > 4 then return false, "Grupo inválido. / Invalid party." end
	for _, player in ipairs(members) do
		local profile = self.profiles:Snapshot(player)
		if not profile then return false, "Perfil indisponível. / Profile unavailable." end
		local ok, reason = self.rules.CanStart(profile, mapId, modeId)
		if ok then ok, reason = self.rules.CanUseDifficulty(profile, mapId, modeId, difficultyId) end
		if not ok then return false, reason end
	end
	self.runId, self.mapId, self.modeId = runId or HttpService:GenerateGUID(false), mapId, modeId
	self.difficultyId = difficultyId or "normal"
	self.size, self.wave, self.completedWaves, self.baseHP, self.shield = #members, 0, 0, self.config.BaseHP, 0
	-- Party size and the map of the day each add to every commander's Gold and XP.
	self.partyBonus = self.rules.PartyBonus(#members)
	self.featuredBonus = self.config.DailyFeature == false and 1 or self.rules.FeaturedBonus(mapId, modeId, math.floor(os.time() / 86400))
	-- The weekend event's map pays over as well (Rules.WeekendEvent).
	self.eventBonus = self.config.WeekendEvent == false and 1 or self.rules.EventBonus(mapId, modeId, os.time())
	-- A harder difficulty pays its Gold and XP over on every wave as well.
	self.difficultyBonus = (self.catalog.Difficulties[self.difficultyId] or {rewardMultiplier=1}).rewardMultiplier or 1
	self.rewardBonus = self.partyBonus * self.featuredBonus * self.difficultyBonus * self.eventBonus
	self.maxBaseHP, self.recovery, self.baseWasDamaged = self.config.BaseHP, 0, false
	self.lastStandHeal, self.lastStandUsed = 0, false
	-- Core plating (a share off every leak) and the wave shield (leaks it
	-- cancels each wave): the best in the squad, like the other Guardian talents.
	self.coreArmor, self.waveShieldMax, self.waveShieldLeft = 0, 0, 0
	for _, member in ipairs(members) do
		local snapshot = self.profiles:Snapshot(member)
		local ranks = snapshot.talents or {}
		self.maxBaseHP = math.max(self.maxBaseHP, self.config.BaseHP + (ranks.baseVitality or 0) * 4)
		self.recovery = math.max(self.recovery, ranks.baseRecovery or 0)
		self.lastStandHeal = math.max(self.lastStandHeal, (ranks.lastStand or 0) * 5)
		self.coreArmor = math.max(self.coreArmor, math.min(0.5, self.rules.TalentEffect(snapshot, "baseArmor")))
		self.waveShieldMax = math.max(self.waveShieldMax, self.rules.TalentEffect(snapshot, "waveShield"))
	end
	self.baseHP = self.maxBaseHP
	self.elapsed, self.phase, self.running, self.shieldUntil = 0, "Preparing", true, 0
	self.hazardTimer, self.hazardState, self.hazardCount = 0, {}, 0
	self.speed = 1
	self.hitBuffer, self.critBuffer = {}, {}
	self.landings, self.landingClock, self.landingSerial = {}, 0, 0
	-- One seed for the whole run keeps every wave and every card offer stable.
	self.seed, self.nextThreats, self.criticalWarned = math.floor(os.time() / 86400), {}, false
	self.cardMode = self.catalog.Modes[modeId].cards == true
	self.prepRemaining = modeId == "tutorial" and 30 or self.config.PreparationSeconds
	self.participants, self.enemies, self.towers, self.rewardQueue, self.skipVotes = {}, {}, {}, {}, {}
	self.soldiers={}
	self.pendingSpawns, self.spawnIndex, self.spawnTimer, self.alive = {}, 1, 0, 0
	self.splits, self.mines = {}, {}
	self.routeCache = {}
	for index, route in ipairs(self.catalog.Maps[mapId].paths) do
		local points, lengths, total = {}, {}, 0
		for _, p in ipairs(route) do table.insert(points, Vector3.new(p[1], 0, p[2])) end
		for i=1,#points-1 do lengths[i] = (points[i+1]-points[i]).Magnitude total += lengths[i] end
		self.routeCache[index] = {points=points,lengths=lengths,total=total}
	end
	local finish = self.routeCache[1].points
	self.corePosition = finish[#finish]
	self.world:Build(mapId)
	self:_previewThreats()
	for index, player in ipairs(members) do
		local profile = self.profiles:Snapshot(player)
		-- cash is match Gold: dropped by enemies, spent on heroes, never saved.
		self.participants[player.UserId] = {player=player,profile=profile,index=index,cash=(self.config.StartCash or self.config.StartEnergy or 600) + ((profile.talents or {}).startingEnergy or 0)*20,
			killGoldRemainder=0,startLevel=profile.level or 1,
			goldEarned=0,xpEarned=0,waveGold=0,coins={},cooldowns={},cards={},cardOffers={},mods={},modsVersion=0,
			perm={},waveHeroes={},contributed=false,towerCount=0,bossKills=0,disconnectedAt=nil,returned=false,collected=0,endVote=false,
			damageDealt=0,kills=0,
			masteryEarned={},rallyUntil=0,rallyStat=nil,rallyValue=0,
			-- Remembered between matches: a commander who plays on 2x and
			-- auto-skip does not have to switch them on every single run.
			-- Training always starts at 1x without auto-skip: it is a lesson.
			speedVote=(profile.settings and profile.settings.fastForward and modeId~="tutorial") and 2 or 1,
			autoSkip=(profile.settings and profile.settings.autoSkip)==true and modeId~="tutorial"}
		local p=self.participants[player.UserId]
		local baseId=profile.equippedBase or "outpost"
		if not self.catalog.Bases[baseId] or (baseId~="outpost" and not (profile.bases or {})[baseId]) then baseId="outpost" end
		p.base={id=baseId,level=1,nextAttack=0,nextSoldier=0,wallHitAt=-100,routeCursor=0}
		p.base.stats=self.rules.BaseStats(baseId,1); p.base.wall=p.base.stats.wall
		local extra=math.floor(p.base.stats.hp/self.size)
		self.maxBaseHP+=extra; self.baseHP+=extra
		if self.world.UpdateBase then p.base.visualPosition=self.world:UpdateBase(p.index,p.base,self.corePosition,p.player.UserId) end
		if self.world.UpdateBarrier then self.world:UpdateBarrier(p.index,p.base,self.routeCache,1) end
		self:_fx({kind="Clear"},player)
		self.world:MovePlayer(player,true,index)
	end
	if modeId == "tutorial" then
		self:_notice("TREINAMENTO • Siga as setas: elas ensinam o jogo passo a passo. Os inimigos derrubam Ouro: pegue para comprar mais heróis.",
			"TRAINING • Follow the arrows: they teach the game one step at a time. Enemies drop Gold: pick it up to buy more heroes.")
	elseif self.cardMode then
		self:_notice("ROGUELIKE DE CARTAS • A cada 5 ondas escolha uma carta. Chefe a cada 10 ondas. 50 ondas.",
			"CARD ROGUELIKE • Pick a card every 5 waves. A boss every 10 waves. 50 waves.")
	elseif modeId == "ranked" then
		self:_notice("COMPETITIVO • Ondas sem fim. Entre as ondas o grupo pode votar para encerrar e guardar o recorde.",
			"COMPETITIVE • Endless waves. Between waves the squad can vote to end and keep the record.")
	else
		local total = self.rules.WaveCount(modeId, mapId)
		self:_notice("Defenda o núcleo por "..total.." ondas. Pegue o Ouro que os inimigos derrubam para comprar heróis.",
			"Defend the core for "..total.." waves. Pick up the Gold enemies drop to buy heroes.")
	end
	return true
end

function Match:Reconnect(player)
	local p = self.participants[player.UserId]
	if p and not p.returned and p.disconnectedAt and os.clock()-p.disconnectedAt <= self.config.ReconnectSeconds then
		p.player, p.disconnectedAt = player, nil
		self.world:MovePlayer(player,true,p.index)
		self:_fx({kind="Clear"},player)
		for id,c in pairs(p.coins) do self:_fx({kind="CoinSpawn",id=id,position=c.position,value=c.value},player) end
		return true
	end
	return false
end

function Match:OnLeave(player)
	local p = self.participants[player.UserId]
	if p and not p.returned then
		p.disconnectedAt = os.clock()
		self:_checkpoint(p, "disconnect:"..tostring(self.wave)..":"..tostring(math.floor(self.elapsed)), false)
	end
end

function Match:_nextId(prefix)
	-- Visual coin grouping must never change combat entity identities.
	self.entityIds = self.entityIds or {}
	self.entityIds[prefix] = (self.entityIds[prefix] or 0) + 1
	return prefix .. tostring(self.entityIds[prefix])
end

-- Announced before the wave arrives, so a player can answer camouflage, armour
-- and air with the heroes they already own instead of losing to a surprise.
function Match:_previewThreats()
	self.nextThreats, self.nextMutation = {}, nil
	if not self.running and self.phase ~= "Preparing" then return end
	self.nextMutation = self.rules.WaveMutation(self.modeId, self.mapId, self.wave + 1, self.seed)
	local ok, specs = pcall(self.waves.Generate, self.mapId, self.modeId, self.wave + 1, self.size, self.seed, self.difficultyId)
	if not ok or type(specs) ~= "table" then return end
	-- Which roads the next wave walks, and whether that changed: the client
	-- animates them during preparation and warns about a new entrance.
	local paths, used = {}, {}
	for _, spec in ipairs(specs) do
		if not used[spec.pathIndex] then used[spec.pathIndex] = true; table.insert(paths, spec.pathIndex) end
	end
	table.sort(paths)
	local signature = table.concat(paths, ",")
	self.newEntrance = self.lastPathSignature ~= nil and self.lastPathSignature ~= signature
	self.lastPathSignature, self.nextPaths = signature, paths
	local seen = {}
	for _, spec in ipairs(specs) do
		local def = self.catalog.Enemies[spec.enemyId]
		local notable = def and (def.boss or def.air or def.stealth or (def.armor or 0) >= 0.3
			or spec.enemyId == "summoner" or spec.enemyId == "support" or spec.enemyId == "brute" or spec.enemyId == "splitter" or spec.enemyId == "saboteur")
		if notable and not seen[spec.enemyId] then
			seen[spec.enemyId] = true
			table.insert(self.nextThreats, spec.enemyId)
		end
	end
end

function Match:Roster()
	local roster = {}
	for _, p in pairs(self.participants) do
		if not p.returned then table.insert(roster, { userId = p.player.UserId, name = p.player.Name }) end
	end
	table.sort(roster, function(a, b) return a.userId < b.userId end)
	return roster
end

function Match:Index(player)
	local p = self.participants[player.UserId]
	return p and p.index or 1
end

-- Lets the shutdown path wait for queued checkpoints instead of dropping gold
-- that players already earned.
function Match:Drain(seconds)
	local deadline = os.clock() + math.max(0, tonumber(seconds) or 0)
	while (self.rewardBusy or #self.rewardQueue > 0) and os.clock() < deadline do
		self:_processRewards()
		task.wait(0.25)
	end
	return #self.rewardQueue == 0
end

function Match:_pathPosition(routeIndex, distance)
	local route = self.routeCache[routeIndex] or self.routeCache[1]
	local remaining = distance
	for i,length in ipairs(route.lengths) do
		if remaining <= length then return route.points[i]:Lerp(route.points[i+1], math.clamp(remaining/length,0,1)) end
		remaining -= length
	end
	return route.points[#route.points]
end

function Match:_spawn(spec)
	if self.alive >= self.config.MaxEnemies then return false end
	local def = self.catalog.Enemies[spec.enemyId]
	if not def then return true end
	local id = self:_nextId("e")
	local hp = def.hp * (spec.hpMultiplier or 1)
	local routeIndex = self.routeCache[spec.pathIndex or 1] and (spec.pathIndex or 1) or 1
	local final = def.boss and not spec.rewardless and self.rules.IsFinalWave(self.modeId, self.wave, self.mapId)
	local enemy = {id=id,def=def,enemyId=spec.enemyId,hp=hp,maxHP=hp,progress=spec.progress or 0,speedMultiplier=spec.speedMultiplier or 1,
		routeIndex=routeIndex,cash=spec.rewardless and 0 or (spec.cash or self.rules.KillCash(spec.enemyId)),rewardless=spec.rewardless,
		position=self:_pathPosition(routeIndex,spec.progress or 0),slow=0,slowUntil=0,revealUntil=0,
		mark=0,markUntil=0,armorBreak=0,armorUntil=0,nextPower=self.elapsed+(def.shock and def.shock.first or 10),summons=0,
		phase=1,shield=0,lastHit=0,portalUntil=0,stunUntil=0,stunImmuneUntil=0,final=final == true,
		expiresAt=def.illusion and self.elapsed+8 or nil}
	self.enemies[id], self.alive = enemy, self.alive + 1
	if def.boss and not spec.rewardless then
		-- A short entrance: name, title and a rumble, before the fight.
		self:_fx({kind="BossArrive",enemyId=spec.enemyId,final=final==true,position=enemy.position})
		if final then
			self:_notice("CHEFE FINAL • "..def.name.pt.." chegou! O mais forte de todos.", "FINAL BOSS • "..def.name.en.." has arrived! The strongest of all.","boss")
		else
			self:_notice("CHEFE • "..def.name.pt, "BOSS • "..def.name.en,"boss")
		end
	end
	return true
end

function Match:_beginWave()
	self.wave += 1
	self.phase, self.skipVotes = "Wave", {}
	self.waveShieldLeft = self.waveShieldMax
	-- The wave a leak starts to hurt twice as much is announced, so the
	-- danger never grows in silence.
	local scale = self.rules.LeakScale(self.wave)
	if scale > self.rules.LeakScale(self.wave - 1) then
		self:_notice("PERIGO • Inimigos que chegam ao núcleo agora causam " .. scale .. "x de dano!", "DANGER • Enemies reaching the core now deal " .. scale .. "x damage!", "boss")
	end
	for _, p in pairs(self.participants) do
		p.waveHeroes, p.contributed, p.bossKills = {}, false, 0
		-- A commander who let the timer run out is dealt the first offer, so a
		-- run never stalls on someone who stepped away.
		if #p.cardOffers > 0 then self:_chooseCard(p, p.cardOffers[1]) end
	end
	self.pendingSpawns = self.waves.Generate(self.mapId,self.modeId,self.wave,self.size,self.seed,self.difficultyId)
	self.spawnIndex, self.spawnTimer = 1, 0
	self.mutation = self.rules.WaveMutation(self.modeId, self.mapId, self.wave, self.seed)
	if self.mutation then self:_fx({kind="Mutation",mutationId=self.mutation}) end
	local threats = {}
	for _, spec in ipairs(self.pendingSpawns) do
		if spec.enemyId == "stealth" then threats.stealth=true elseif spec.enemyId=="flyer" then threats.air=true elseif spec.enemyId=="armored" then threats.armor=true elseif spec.enemyId=="splitter" then threats.split=true elseif spec.enemyId=="saboteur" then threats.shock=true end
	end
	-- The first splitter wave of a run explains itself once; later waves keep the usual warnings.
	if threats.split and not self.splitTold then
		self.splitTold=true
		self:_notice("Gosmentos chegando: eles se dividem ao morrer. Dano em área limpa os fragmentos.","Splitters incoming: they burst into fragments when they die. Area damage clears the pieces.")
	elseif threats.shock and not self.shockTold then
		self.shockTold=true
		self:_notice("Sabotadores chegando: eles paralisam as torres por perto. Elimine-os cedo; heróis imunes a paralisia protegem a linha.","Saboteurs incoming: they stun nearby towers. Take them out early; stun-proof heroes keep the line firing.")
	elseif threats.stealth then self:_notice("Camuflados chegando: Viúva Sombria, Vigilante Cego ou uma habilidade de revelar mostram os alvos.","Cloaked enemies incoming: Shadow Widow, Blind Vigilante or a reveal ability shows them.")
	elseif threats.air then self:_notice("Ameaça aérea: voadores passam por cima de minas, barreiras e soldados.","Air threat: flyers pass over mines, barriers and soldiers.")
	elseif threats.armor then self:_notice("Blindados: perfuração e dano mágico são eficientes.","Armored enemies: piercing and magic are effective.") end
	-- The tutorial teaches one idea per wave instead of dumping everything in
	-- the opening notice: place, then upgrade, then abilities, then pacing,
	-- and finally what to spend the reward on.
	if self.modeId=="tutorial" then
		local final=self.wave>=self.rules.WaveCount(self.modeId,self.mapId)
		local lesson=final and TUTORIAL_LESSONS.final or TUTORIAL_LESSONS[self.wave]
		if lesson then self:_notice(lesson[1],lesson[2]) end
	end
end

-- A pile of match Gold on the ground for one commander. Piles near each other
-- merge, so a crowded road stays readable. Only its owner sees and takes it.
function Match:_coin(p, position, amount)
	if amount <= 0 then return end
	local nearest, nearestDistance, count = nil, math.huge, 0
	for id,c in pairs(p.coins) do
		count+=1 local d=distanceXZ(c.position,position)
		if d<nearestDistance then nearest,nearestDistance=id,d end
	end
	local id
	if nearest and (nearestDistance<9 or count>=self.config.MaxCoinPiles) then id=nearest p.coins[id].value+=amount
	else id=self:_nextId("c") p.coins[id]={position=Vector3.new(position.X,1.5,position.Z),value=amount} end
	self:_fx({kind="CoinSpawn",id=id,position=p.coins[id].position,value=p.coins[id].value},p.player)
end

-- Collects a commander's Gold within radius of a point (a scavenger tower,
-- an ability's area). The coins fly to that point; the total never changes.
function Match:_collectAround(p, center, radius)
	local count=0
	for id,coin in pairs(p.coins) do
		if distanceXZ(coin.position,center)<=radius then
			p.collected+=coin.value p.cash+=coin.value p.coins[id]=nil count+=1
			self:_fx({kind="CoinRemove",id=id,value=coin.value,to=center+Vector3.new(0,3,0)},p.player)
		end
	end
	return count
end

function Match:_contribute(tower)
	local p = self.participants[tower.ownerId]
	if p and not p.returned and not p.disconnectedAt then
		p.contributed=true
		if tower.heroId then p.waveHeroes[tower.heroId]=true end
	end
end

-- Damage is booked per enemy so the client can float one tidy number over each
-- target every sync instead of one event per hit.
function Match:_recordHit(enemy, amount)
	if amount >= 1 then self.hitBuffer[enemy.id] = (self.hitBuffer[enemy.id] or 0) + amount end
end

function Match:_damage(enemy, amount, tower, stats)
	if enemy.hp<=0 then return end
	local damage
	if stats and stats.trueDamage then
		-- Ability damage is a share of the target's health and ignores armor.
		damage = amount
	else
		local armor = enemy.def.armor or 0
		if enemy.armorUntil>self.elapsed then armor = math.max(0,armor-enemy.armorBreak) end
		if enemy.fortifyUntil and enemy.fortifyUntil>self.elapsed then armor=math.max(armor,0.5) end
		local magic = stats and stats.damageType=="magic"
		if magic then armor *= 0.5 end
		if enemy.enemyId=="doom" and enemy.phase==2 and magic then armor=math.max(armor,0.35) end
		armor=math.clamp(armor-(stats and stats.armorPierce or 0),0,0.65)
		damage=amount*(1-armor)
		if enemy.def.boss then damage*=1+(stats and stats.bossDamage or 0) end
		if enemy.def.air and stats and (stats.airDamage or 0) ~= 0 then damage*=1+stats.airDamage end
		if enemy.def.stealth and stats and (stats.stealthDamage or 0) ~= 0 then damage*=1+stats.stealthDamage end
	end
	if enemy.markUntil>self.elapsed then damage*=1+enemy.mark end
	if enemy.vulnerableUntil and enemy.vulnerableUntil>self.elapsed then damage*=1+VULNERABLE_BONUS end
	if enemy.shield>0 then local absorbed=math.min(damage,enemy.shield) enemy.shield-=absorbed damage-=absorbed end
	local owner = tower and self.participants[tower.ownerId]
	local dealt = math.max(0, math.min(damage, enemy.hp))
	if owner then owner.damageDealt = (owner.damageDealt or 0) + dealt end
	if tower and tower.id and tower.heroId then tower.totalDamage = (tower.totalDamage or 0) + dealt end
	enemy.hp-=damage enemy.lastHit=self.elapsed
	self:_recordHit(enemy, damage)
	if enemy.regenUntil and enemy.regenUntil>self.elapsed then
		enemy.regenDamage=(enemy.regenDamage or 0)+damage
		if enemy.regenDamage>=enemy.maxHP*0.05 then enemy.regenUntil=0 end
	end
	if tower then self:_contribute(tower) end
	if enemy.hp<=0 then
		if owner then owner.kills = (owner.kills or 0) + 1 end
		if tower and tower.id and tower.heroId then tower.kills = (tower.kills or 0) + 1 end
		self.enemies[enemy.id]=nil self.alive-=1
		self:_fx({kind="EnemyDown",id=enemy.id,enemyId=enemy.enemyId,position=enemy.position,boss=enemy.def.boss==true,split=enemy.def.split and true or nil})
		-- The fragments wait for the end of the damage pass (see _flushSplits).
		if enemy.def.split then table.insert(self.splits,enemy) end
		for _, p in pairs(self.participants) do
			if p.contributed and not p.returned and not p.disconnectedAt then
				-- Every contributor gets their own pile; talents and cards grow it.
				local exactCash = enemy.cash * (1 + talent(p,"killGold")*0.04 + cardStat(p,"killGold") + (p.base and p.base.stats.bounty or 0)) + p.killGoldRemainder
				local earnedCash = math.floor(exactCash + 0.000001)
				p.killGoldRemainder = exactCash - earnedCash
				self:_coin(p,enemy.position,earnedCash)
				if enemy.def.boss and not enemy.rewardless then p.bossKills+=1 end
			end
		end
	end
end

-- The permanent part of a tower's stats depends only on the account, so it is
-- worked out once per participant and hero.
function Match:_permanent(p, heroId)
	local perm = p.perm[heroId]
	if not perm then
		perm = self.rules.PermanentModifiers(p.profile, heroId)
		p.perm[heroId] = perm
	end
	return perm
end

-- A tower's stats without any timed buff. Cached until its level, branch or the
-- owner's cards change: attack loops read this for every tower every tick.
-- preview {level, branch}: what an upgrade would make this tower, with the
-- same bonuses, so the HUD can show before -> after without computing it.
function Match:_baseStats(tower, preview)
	local p = self.participants[tower.ownerId]
	local cache = tower.cache
	if not preview and cache and cache.version == p.modsVersion and cache.level == tower.level and cache.branch == tower.branch then return cache.stats end
	local hero = self.catalog.Heroes[tower.heroId]
	local perm = self:_permanent(p, tower.heroId)
	local mods = p.mods
	local level, branch = tower.level, tower.branch
	if preview then level, branch = preview.level, preview.branch end
	local stats = self.rules.TowerStats(hero, level, branch, {
		damageBonus = perm.damageBonus + (mods.damage or 0),
		rangeBonus = perm.rangeBonus + (mods.range or 0),
		attackSpeedBonus = perm.attackSpeedBonus + (mods.speed or 0),
		armorPierceBonus = (mods.pierce or 0) + (perm.armorPierceBonus or 0), bossDamageBonus = (mods.bossDamage or 0) + (perm.bossDamageBonus or 0),
		splashBonus = (mods.area or 0) + (perm.splashBonus or 0),
		airDamage = (mods.airDamage or 0) + (perm.airDamage or 0), stealthDamage = (mods.stealthDamage or 0) + (perm.stealthDamage or 0),
	})
	if hero.support then stats.range *= 1 + (mods.supportRange or 0) end
	-- Field workshop (talent): upgrades cost less; Critical strike rides along.
	stats.upgradeCost = math.floor(stats.upgradeCost * (1 - math.clamp(perm.upgradeDiscount or 0, 0, 0.5)))
	stats.critChance = perm.critChance or 0
	if preview then return stats end
	tower.cache = { version = p.modsVersion, level = tower.level, branch = tower.branch, stats = stats }
	return stats
end

local function statLine(stats)
	return { damage = stats.damage, range = stats.range, rate = stats.rate, slow = stats.slow, splash = stats.splash }
end

-- The upgrade the tower's owner would buy next: one line below level 4, the
-- two specializations at level 4, nothing once maxed.
function Match:_upgradePreview(tower)
	if tower.level < 4 then return { next = statLine(self:_baseStats(tower, { level = tower.level + 1 })) } end
	if tower.level == 4 then
		return { branches = { statLine(self:_baseStats(tower, { level = 5, branch = 1 })), statLine(self:_baseStats(tower, { level = 5, branch = 2 })) } }
	end
	return nil
end

-- The stats the tower fights with right now: its base plus any ability buff.
function Match:_towerStats(tower)
	local base = self:_baseStats(tower)
	local p = self.participants[tower.ownerId]
	local overload = (tower.overloadUntil or 0) > self.elapsed
	local rally = p.rallyUntil > self.elapsed
	if not overload and not rally then return base end
	local stats = table.clone(base)
	if overload then
		stats.interval /= 1 + (tower.overloadValue or 0.5)
	end
	if rally and p.rallyStat == "speed" then stats.interval /= 1 + p.rallyValue end
	if rally and p.rallyStat == "damage" then stats.damage *= 1 + p.rallyValue end
	stats.rate = 1 / stats.interval
	return stats
end

-- Every hero can spot a cloaked enemy that walks right past it, so a squad
-- with no revealing hero is never helpless. A revealing hero, or a reveal
-- ability, exposes them across the tower's whole range instead.
local CLOAK_SIGHT = 12

function Match:_canTarget(tower, enemy, stats)
	if enemy.def.air and not stats.air then return false end
	local distance = distanceXZ(tower.position,enemy.position)
	if enemy.def.stealth and not stats.reveal and enemy.revealUntil<=self.elapsed then
		return distance<=math.min(stats.range,CLOAK_SIGHT)
	end
	return distance<=stats.range
end

-- Cosmetic anticipation on a scheduled attack, once per cooldown. A real
-- eligible enemy must exist. No target is reserved, no hit is predicted and
-- the actual attack still selects its target at the unchanged deadline.
function Match:_windup(tower, stats)
	if tower.windupFor == tower.nextAttack then return end
	local remaining = tower.nextAttack - self.elapsed
	local lead = math.min(0.23, stats.interval * 0.25)
	if remaining <= 0 or remaining > lead then return end
	tower.windupFor = tower.nextAttack
	for _, enemy in pairs(self.enemies) do
		if self:_canTarget(tower, enemy, stats) then
			local height = self.world.AimHeight and self.world:AimHeight(enemy.enemyId) or (enemy.def.air and 8 or 2)
			local event = {kind="Windup",towerId=tower.id,to=enemy.position+Vector3.new(0,height,0),duration=remaining}
			if self.windupBuffer then event.kind=nil table.insert(self.windupBuffer,event) else self:_fx(event) end
			return
		end
	end
end

function Match:_attack(tower, stats)
	local candidates={}
	for _,enemy in pairs(self.enemies) do if self:_canTarget(tower,enemy,stats) then table.insert(candidates,enemy) end end
	if #candidates==0 then return false end
	table.sort(candidates,function(a,b)
		if tower.priority=="Strongest" then return a.hp>b.hp end
		if tower.priority=="Nearest" then return distanceXZ(tower.position,a.position)<distanceXZ(tower.position,b.position) end
		local pa=a.progress/self.routeCache[a.routeIndex].total local pb=b.progress/self.routeCache[b.routeIndex].total
		if tower.priority=="Last" then return pa<pb end
		return pa>pb
	end)
	local target=candidates[1]
	local hits={target}
	tower.attacks=(tower.attacks or 0)+1
	-- A mine hero does not hit the target: it plants a mine on the road ahead.
	local mineAt
	if stats.attack=="mine" then
		mineAt=self:_plantMine(tower,stats,target)
		if not mineAt then tower.attacks-=1 return false end
		hits={}
	end
	local attack=stats.attack
	local stomp = false
	if stats.periodicSplash and stats.periodicSplash>0 and tower.attacks%stats.periodicSplash==0 then attack="splash" stomp=true end
	if attack=="splash" or attack=="dot" then
		hits={}
		for _,enemy in pairs(self.enemies) do
			if (not enemy.def.air or stats.air) and distanceXZ(enemy.position,target.position)<=(stats.splash or 8) then table.insert(hits,enemy) end
		end
	elseif attack=="chain" then
		for i=2,math.min(#candidates,stats.chain or 3) do table.insert(hits,candidates[i]) end
	elseif attack=="beam" then
		local direction=(target.position-tower.position)
		local endpoint=tower.position+(direction.Magnitude>0 and direction.Unit or Vector3.new(0,0,1))*stats.range
		for i=2,#candidates do if segmentDistance(candidates[i].position,tower.position,endpoint)<=(stats.beamWidth or 3) then table.insert(hits,candidates[i]) end end
	end
	-- Critical strike (talent): the share of attacks that hit for double, spread
	-- evenly (no dice to replay) and offset per tower so they never crit together.
	local crit=false
	if (stats.critChance or 0)>0 then
		local beat=tower.attacks+(tower.critOffset or 0)
		crit=math.floor(beat*stats.critChance)>math.floor((beat-1)*stats.critChance)
	end
	local boost=0
	for _,ally in pairs(self.towers) do
		if ally.id~=tower.id and (ally.stunnedUntil or 0)<=self.elapsed then
			local aStats=self:_baseStats(ally)
			if (aStats.supportBoost or 0)>boost and distanceXZ(ally.position,tower.position)<=aStats.range then
				if ally.heroId~="strange" or stats.damageType=="magic" then boost=aStats.supportBoost self:_contribute(ally) end
			end
		end
	end
	for _, enemy in ipairs(hits) do
		if (stats.slow or 0)>0 then
			enemy.slow=math.max(enemy.slow,math.min(stats.slow,enemy.def.boss and 0.2 or 0.55)) enemy.slowUntil=math.max(enemy.slowUntil,self.elapsed+2.5)
		end
		if (stats.mark or 0)>0 then enemy.mark=math.max(enemy.mark,stats.mark) enemy.markUntil=self.elapsed+4 end
		if (stats.armorShred or 0)>0 then enemy.armorBreak=math.max(enemy.armorBreak,stats.armorShred) enemy.armorUntil=self.elapsed+4 end
		if stats.portal and not enemy.def.boss and enemy.portalUntil<=self.elapsed then
			enemy.progress=math.max(0,enemy.progress-7) enemy.portalUntil=self.elapsed+9
		end
		if attack=="dot" or (stats.dotDuration or 0)>0 then
			enemy.dot={untilTime=self.elapsed+(stats.dotDuration or 3),damage=stats.damage*0.2,tower=tower,stats=stats,nextTick=self.elapsed+1}
		end
		self:_damage(enemy,stats.damage*(1+boost)*(crit and 2 or 1),tower,stats)
		if crit then self.critBuffer[enemy.id]=true end
		-- A punch with weight: the enemy is shoved back along the road, at most once
		-- every 0.8 s so a fast puncher never pins it in place, and never a boss.
		if (stats.knockback or 0)>0 and enemy.hp>0 and not enemy.def.boss and (enemy.knockUntil or 0)<=self.elapsed then
			enemy.progress=math.max(0,enemy.progress-stats.knockback)
			enemy.knockUntil=self.elapsed+0.8
		end
	end
	local c=self.catalog.Heroes[tower.heroId].color
	-- The figure's own chest when the world knows it; otherwise the old heights.
	local visualHeight = (self.world.AimHeight and self.world:AimHeight(target.enemyId)) or (target.def.air and 8 or target.def.boss and 4.2 or target.enemyId=="brute" and 2.9 or 2)
	local shot={kind="Shot",from=tower.position+Vector3.new(0,4,0),to=mineAt and mineAt+Vector3.new(0,0.4,0) or target.position+Vector3.new(0,visualHeight,0),color=Color3.fromRGB(c[1],c[2],c[3]),towerId=tower.id,heroId=tower.heroId,style=attack,stomp=stomp,
		armored=(target.def.armor or 0)>=0.25 or nil,interval=stats.interval}
	-- Inside a frame's batch every shot rides in one Shots event; alone (tests,
	-- a stray call) it goes out at once.
	if self.shotBuffer then shot.kind=nil table.insert(self.shotBuffer,shot) else self:_fx(shot) end
	if attack=="splash" or attack=="dot" then self:_fx({kind="Pulse",position=target.position,radius=stats.splash or 8,color=Color3.fromRGB(c[1],c[2],c[3])}) end
	return true
end

-- Mines: planted on the road a little ahead of the target, they wait for the
-- first ground enemy to come within reach and then blast everything in their
-- radius. A tower keeps at most mineMax of them; selling the tower, the end of
-- the wave or half a minute without a victim removes them.
local MINE_TRIGGER, MINE_LIFETIME, MINE_SPACING = 3.4, 30, 7

function Match:_plantMine(tower, stats, target)
	local max=stats.mineMax or 0
	local count=0
	for _,mine in pairs(self.mines) do if mine.towerId==tower.id then count+=1 end end
	if count>=max then return nil end
	-- As far ahead of the target as the tower can reach, so the trap is laid
	-- before the horde gets there; never closer than a few studs.
	local route=self.routeCache[target.routeIndex]
	local at
	for _,lead in ipairs({22,18,14,10,6}) do
		local candidate=self:_pathPosition(target.routeIndex,math.min(route.total-2,target.progress+lead))
		local clear=true
		for _,mine in pairs(self.mines) do
			if distanceXZ(mine.position,candidate)<MINE_SPACING then clear=false break end
		end
		if clear and distanceXZ(tower.position,candidate)<=stats.range then at=candidate break end
	end
	if not at then return nil end
	local id=self:_nextId("m")
	self.mines[id]={id=id,towerId=tower.id,ownerId=tower.ownerId,position=at,damage=stats.damage,radius=stats.mineRadius,stun=stats.mineStun or 0,
		stats=table.clone(stats),expiresAt=self.elapsed+MINE_LIFETIME}
	self:_contribute(tower)
	return at
end

function Match:_detonate(mine)
	self.mines[mine.id]=nil
	local tower=self.towers[mine.towerId]
	local victims={}
	for _,enemy in pairs(self.enemies) do
		if enemy.hp>0 and not enemy.def.air and distanceXZ(enemy.position,mine.position)<=mine.radius then table.insert(victims,enemy) end
	end
	for _,enemy in ipairs(victims) do
		self:_damage(enemy,mine.damage,tower,mine.stats)
		if mine.stun>0 and enemy.hp>0 then
			if enemy.def.boss then
				if enemy.stunImmuneUntil<=self.elapsed then
					enemy.stunUntil=self.elapsed+mine.stun*BOSS_STUN_SHARE
					enemy.stunImmuneUntil=self.elapsed+BOSS_STUN_IMMUNITY
				end
			else
				enemy.stunUntil=math.max(enemy.stunUntil,self.elapsed+mine.stun)
			end
		end
	end
	local hero=tower and self.catalog.Heroes[tower.heroId]
	local c=hero and hero.color or {255,170,64}
	self:_fx({kind="MineBlast",id=mine.id,position=mine.position,radius=mine.radius,color=Color3.fromRGB(c[1],c[2],c[3]),towerId=mine.towerId,shake=0.2})
end

function Match:_minesStep()
	for id,mine in pairs(self.mines) do
		if self.elapsed>=mine.expiresAt or not self.towers[mine.towerId] then
			self.mines[id]=nil
		else
			for _,enemy in pairs(self.enemies) do
				if enemy.hp>0 and not enemy.def.air and not enemy.def.illusion and distanceXZ(enemy.position,mine.position)<=MINE_TRIGGER then
					self:_detonate(mine)
					break
				end
			end
		end
	end
end

-- A splitter that fell leaves its fragments on the road where it died, with
-- the same health scaling and a share of its Gold. They are made after the
-- damage pass, never inside it: adding to self.enemies while a loop walks it
-- would skip or repeat enemies.
function Match:_flushSplits()
	if #self.splits==0 then return end
	local fallen=self.splits
	self.splits={}
	for _,enemy in ipairs(fallen) do
		local split=enemy.def.split
		local share=enemy.rewardless and 0 or math.floor(self.rules.KillCash(split.into)*enemy.cash/math.max(1,self.rules.KillCash(enemy.enemyId))+0.5)
		for index=1,split.count do
			-- Spread along the road so the pieces do not stack into one blob.
			self:_spawn({enemyId=split.into,pathIndex=enemy.routeIndex,progress=math.max(0,enemy.progress+(index*2-split.count-1)*1.6),
				hpMultiplier=enemy.maxHP/enemy.def.hp,rewardless=enemy.rewardless,cash=share})
		end
	end
end

function Match:_summon(enemy, count, enemyId)
	for _=1,count do
		self:_spawn({enemyId=enemyId,pathIndex=enemy.routeIndex,progress=enemy.progress,hpMultiplier=1+self.wave*0.12,rewardless=true})
	end
end

-- Boss powers interrupt nearby towers for a moment. Every client is told which
-- ones, so an interrupted hero is shown as interrupted, not as a bug.
-- Each map's own danger (Catalog.Maps[id].hazard), on its own clock during
-- waves and announced a few seconds ahead: frenzy (the infected run faster),
-- shield (enemies gain a shield), stun (a circle stops towers) and push (a
-- gust drives enemies back down the road). Training has none.
function Match:_hazardCenter(hazard)
	if hazard.kind ~= "stun" then return nil end
	local towers = {}
	for _, t in pairs(self.towers) do table.insert(towers, t) end
	if #towers == 0 then return nil end
	table.sort(towers, function(a, b) return a.id < b.id end)
	return towers[Random.new(self.seed + self.wave * 13 + self.hazardCount):NextInteger(1, #towers)].position
end

function Match:_hazardStep(dt)
	local map = self.catalog.Maps[self.mapId]
	local hazard = map and map.hazard
	if not hazard or self.modeId == "tutorial" or self.phase ~= "Wave" then return end
	self.hazardTimer += dt
	local state = self.hazardState
	local color = Color3.fromRGB(hazard.color[1], hazard.color[2], hazard.color[3])
	if not state.warned and self.hazardTimer >= hazard.every - hazard.warn then
		state.warned, state.center = true, self:_hazardCenter(hazard)
		self:_notice("▲ " .. hazard.name.pt .. ": " .. hazard.hint.pt, "▲ " .. hazard.name.en .. ": " .. hazard.hint.en, "hazard")
		if state.center then
			self:_fx({kind="Pulse",position=state.center,radius=hazard.radius or 12,color=color,duration=hazard.warn,warningText=hazard.warning})
		end
	end
	if self.hazardTimer < hazard.every then return end
	self.hazardTimer, state.warned = 0, false
	self.hazardCount += 1
	if hazard.kind == "frenzy" then
		for _, e in pairs(self.enemies) do e.frenzyUntil = self.elapsed + hazard.duration end
	elseif hazard.kind == "shield" then
		for _, e in pairs(self.enemies) do if not e.def.boss then e.shield = math.max(e.shield, e.maxHP * hazard.power) end end
	elseif hazard.kind == "push" then
		for _, e in pairs(self.enemies) do
			if not e.def.boss then
				e.progress = math.max(0, e.progress - hazard.power)
				e.position = self:_pathPosition(e.routeIndex, e.progress)
			end
		end
	elseif hazard.kind == "stun" and state.center then
		self:_stunTowers(state.center, hazard.radius, hazard.duration)
	end
	self:_fx({kind="Pulse",position=state.center or self.corePosition,radius=(hazard.radius or 14)*1.2,color=color,duration=0.6})
	state.center = nil
end

-- A tower that cannot be stunned, or that stands within the steadying aura of
-- one that can hold the line for its allies.
function Match:_stunProof(tower)
	local own=self:_baseStats(tower)
	if own.stunProof then return true end
	for _,ally in pairs(self.towers) do
		if ally.id~=tower.id then
			local stats=self:_baseStats(ally)
			if (stats.stunAura or 0)>0 and distanceXZ(ally.position,tower.position)<=stats.stunAura then return true end
		end
	end
	return false
end

-- Whether a tower that is not stun-proof stands within reach of a shock.
function Match:_shockable(center, radius)
	for _,t in pairs(self.towers) do
		if distanceXZ(t.position,center)<radius and not self:_stunProof(t) then return true end
	end
	return false
end

function Match:_stunTowers(center, radius, seconds)
	local ids={}
	for _,t in pairs(self.towers) do
		if distanceXZ(t.position,center)<radius and not self:_stunProof(t) then t.stunnedUntil=self.elapsed+seconds table.insert(ids,t.id) end
	end
	if #ids>0 then self:_fx({kind="TowersStunned",towerIds=ids,duration=seconds}) end
end

-- Boss powers, telegraphed two seconds ahead. Every boss has a distinct
-- mechanic so the ten-wave rhythm teaches a new lesson each time; the final one
-- combines them and works faster.
function Match:_power(enemy)
	local id=enemy.enemyId
	local bonus = enemy.final and 2 or 0
	if id=="lizard" then
		enemy.regenUntil=self.elapsed+6 enemy.regenDamage=0 enemy.hint="Concentre dano para interromper a regeneração / Focus fire to stop regeneration"
	elseif id=="abomination" then
		enemy.fortifyUntil=self.elapsed+5 enemy.hint="Impacto próximo / Impact nearby"
		self:_stunTowers(enemy.position,24,1.8)
	elseif id=="redskull" then
		self:_summon(enemy,4,"runner")
		for _,e in pairs(self.enemies) do if not e.def.boss then e.frenzyUntil=self.elapsed+7 end end
		enemy.hint="Elimine os reforços / Clear the reinforcements"
	elseif id=="killmonger" then
		if enemy.shield>0 then
			self:_stunTowers(enemy.position,28,2)
			enemy.shield=0
		else
			enemy.shield=enemy.maxHP*0.08 enemy.dischargeAt=self.elapsed+5
			self:_fx({kind="Pulse",position=enemy.position,radius=28,color=Color3.fromRGB(255,170,64),duration=5,
				followEnemyId=enemy.id,requiresShield=true,warningText={pt="QUEBRE O ESCUDO",en="BREAK THE SHIELD"}})
		end
		enemy.hint="Quebre o escudo antes da descarga / Break the shield before discharge"
	elseif id=="doom" then
		self:_summon(enemy,3+enemy.phase+bonus,"armored")
		enemy.fortifyUntil=self.elapsed+4
		if enemy.final then
			-- The final form also silences the towers around him.
			self:_stunTowers(enemy.position,22,1.5)
		end
		enemy.hint="Feche a invasão; alterne suas fontes de dano / Stop the invasion; mix your damage sources"
	elseif id=="loki" then
		-- Illusions: worthless decoys that pull fire for a few seconds.
		self:_summon(enemy,2+enemy.phase+bonus,"illusion")
		enemy.hint="Ilusões somem sozinhas; mire no Mestre verdadeiro / Illusions fade on their own; aim at the real Master"
	end
	self:_fx({kind="Pulse",position=enemy.position,radius=24,color=Color3.fromRGB(104,255,119),shake=enemy.final and 1 or 0.7})
	enemy.vulnerableUntil=self.elapsed+VULNERABLE_SECONDS
end

function Match:_statusOf(enemy)
	local flags = 0
	if enemy.stunUntil > self.elapsed then flags += STATUS.stunned end
	if (enemy.slowUntil > self.elapsed and enemy.slow > 0) or (enemy.chillUntil or 0) > self.elapsed then flags += STATUS.slowed end
	if enemy.markUntil > self.elapsed then flags += STATUS.marked end
	if enemy.dot and enemy.dot.untilTime > self.elapsed then flags += STATUS.burning end
	if enemy.shield > 0 then flags += STATUS.shielded end
	if enemy.armorUntil > self.elapsed and enemy.armorBreak > 0 then flags += STATUS.weakened end
	if enemy.vulnerableUntil and enemy.vulnerableUntil > self.elapsed then flags += STATUS.vulnerable end
	if enemy.def.stealth and enemy.revealUntil > self.elapsed then flags += STATUS.revealed end
	if enemy.boostUntil and enemy.boostUntil > self.elapsed then flags += STATUS.boosted end
	return flags
end

function Match:_enemiesStep(dt)
	for _,enemy in pairs(self.enemies) do
		if enemy.hp>0 then
			if enemy.dot and self.elapsed>=enemy.dot.nextTick then
				if self.elapsed<=enemy.dot.untilTime then
					enemy.dot.nextTick=self.elapsed+1 self:_damage(enemy,enemy.dot.damage,enemy.dot.tower,enemy.dot.stats)
				else enemy.dot=nil end
			end
			if enemy.hp<=0 then continue end
			if enemy.expiresAt and self.elapsed>=enemy.expiresAt then
				self.enemies[enemy.id]=nil self.alive-=1
				self:_fx({kind="EnemyDown",id=enemy.id,enemyId=enemy.enemyId,position=enemy.position,boss=false,faded=true})
				continue
			end
			if enemy.def.boss and not enemy.rewardless then
				enemy.phase=enemy.hp/enemy.maxHP<0.33 and 3 or (enemy.hp/enemy.maxHP<0.66 and 2 or 1)
				if self.elapsed>=enemy.nextPower-2 and not enemy.telegraphed then
					enemy.telegraphed=true self:_notice(enemy.def.name.pt.." prepara uma habilidade!",enemy.def.name.en.." is preparing an ability!","boss")
					-- The toast says a power is coming; this ring says where, and
					-- lasts exactly the two seconds the player has to react.
					local radius = enemy.enemyId=="abomination" and 24 or enemy.enemyId=="killmonger" and 28 or enemy.enemyId=="doom" and enemy.final and 22 or 6
					self:_fx({kind="Pulse",position=enemy.position,radius=radius,color=Color3.fromRGB(255,170,64),duration=2,
						followEnemyId=enemy.id,warningText={pt="PODER DO CHEFE",en="BOSS POWER"}})
				end
				if self.elapsed>=enemy.nextPower then self:_power(enemy) enemy.nextPower=self.elapsed+(enemy.final and 9 or 14) enemy.telegraphed=false end
				if enemy.dischargeAt and self.elapsed>=enemy.dischargeAt then
					enemy.dischargeAt=nil
					if enemy.shield>0 then self:_power(enemy) end
				end
				if enemy.regenUntil and enemy.regenUntil>self.elapsed then enemy.hp=math.min(enemy.maxHP,enemy.hp+enemy.maxHP*0.009*dt) end
			elseif enemy.def.shock and enemy.stunUntil<=self.elapsed then
				-- A shock is announced a moment ahead, over the saboteur, and only
				-- when a tower that can feel it is in reach. A stun cancels it.
				local shock=enemy.def.shock
				if not enemy.shockTold and self.elapsed>=enemy.nextPower and self:_shockable(enemy.position,shock.radius) then
					enemy.shockTold=true enemy.nextPower=self.elapsed+shock.warn
					self:_fx({kind="Pulse",position=enemy.position,radius=shock.radius,color=Color3.fromRGB(90,190,255),duration=shock.warn,
						followEnemyId=enemy.id,warningText={pt="CHOQUE",en="SHOCK"}})
				elseif enemy.shockTold and self.elapsed>=enemy.nextPower then
					enemy.shockTold=false enemy.nextPower=self.elapsed+shock.every
					self:_stunTowers(enemy.position,shock.radius,shock.seconds)
					self:_fx({kind="Pulse",position=enemy.position,radius=shock.radius,color=Color3.fromRGB(150,225,255),shake=0.25})
				end
			elseif enemy.def.shock and enemy.shockTold then
				-- Stunned mid-warning: the shock fizzles and starts over later.
				enemy.shockTold=false enemy.nextPower=enemy.stunUntil+enemy.def.shock.every*0.5
			elseif enemy.enemyId=="summoner" and enemy.summons<2 then
				-- A summons is announced a moment ahead and opens a portal; the
				-- orbs on the staff show how many are left (EnemySync "ch").
				if not enemy.summonTold and self.elapsed>=enemy.nextPower-1.5 then
					enemy.summonTold=true
					self:_fx({kind="Pulse",position=enemy.position,radius=6,color=Color3.fromRGB(190,110,255),duration=1.5,
						followEnemyId=enemy.id,warningText={pt="INVOCANDO",en="SUMMONING"}})
				end
				if self.elapsed>=enemy.nextPower then
					enemy.summons+=1 enemy.nextPower=self.elapsed+12 enemy.summonTold=false self:_summon(enemy,3,"zombie")
					self:_fx({kind="Pulse",position=enemy.position,radius=7,color=Color3.fromRGB(190,110,255)})
				end
			end
			if enemy.stunUntil > self.elapsed then enemy.speedNow = 0 continue end
			-- A Nightmare run and a Rush wave really are faster (Waves sets it).
			local speed=enemy.def.speed*(enemy.speedMultiplier or 1)
			-- The strongest slow applies, a hero's (slow) or an ice field's (chill): they never stack.
			local slowed=0
			if enemy.slowUntil>self.elapsed then slowed=enemy.slow else enemy.slow=0 end
			if (enemy.chillUntil or 0)>self.elapsed then slowed=math.max(slowed,enemy.chill or 0) end
			speed*=1-slowed
			if enemy.frenzyUntil and enemy.frenzyUntil>self.elapsed then speed*=1.2 end
			for _,support in pairs(self.enemies) do
				if support.enemyId=="support" and support.id~=enemy.id and distanceXZ(support.position,enemy.position)<18 then
					speed*=1.12 enemy.boostedBy=support.id enemy.boostUntil=self.elapsed+0.3 break
				end
			end
			enemy.progress+=speed*dt enemy.position=self:_pathPosition(enemy.routeIndex,enemy.progress) enemy.speedNow=speed
			if enemy.progress>=self.routeCache[enemy.routeIndex].total then
				self.enemies[enemy.id]=nil self.alive-=1
				local damage=enemy.def.leak or 1
				if not enemy.def.boss then damage*=self.rules.LeakScale(self.wave) end
				damage=math.max(0,math.floor(damage*(1-self.coreArmor)+0.5))
				if not enemy.def.boss and damage>0 and self.waveShieldLeft>0 then
					self.waveShieldLeft-=1 damage=0
					self:_fx({kind="Pulse",position=self.corePosition,radius=9,color=Color3.fromRGB(76,221,174),duration=0.4})
				end
				local absorbed=math.min(self.shield,damage)
				self.shield-=absorbed self.baseHP=math.max(0,self.baseHP-damage+absorbed)
				if damage > absorbed then self.baseWasDamaged = true end
				local taken=damage-absorbed
				-- A leak used to be silent: the bar dropped and nothing said why.
				self:_fx({kind="Breach",position=self.corePosition,damage=taken,baseHP=self.baseHP,
					boss=enemy.def.boss==true,shake=math.clamp(taken/12,0.25,1)})
				-- Last stand: once per match, when the core drops below 30%, the
				-- best repair crew in the squad patches it up.
				if taken>0 and self.baseHP>0 and self.baseHP<self.maxBaseHP*0.3 and not self.lastStandUsed and self.lastStandHeal>0 then
					self.lastStandUsed=true
					self.baseHP=math.min(self.maxBaseHP,self.baseHP+self.lastStandHeal)
					self:_notice("ÚLTIMA RESISTÊNCIA • O núcleo foi reparado!","LAST STAND • The core was repaired!")
				end
				if taken>0 and self.baseHP>0 and self.baseHP<=25 and not self.criticalWarned then
					self.criticalWarned=true
					self:_notice("NÚCLEO CRÍTICO • Segure a próxima leva.","CORE CRITICAL • Hold the next push.","boss")
				end
				if self.baseHP<=0 then self:Finish(false) return end
			end
		end
	end
end

-- A commander's paid Gold boost (Catalog.Products.Consumables.goldBoost): the
-- server's clock against the profile's boostUntil, so it can run out mid-match.
function Match:_goldBoost(p)
	local boost = self.catalog.Products.Consumables.goldBoost
	local until_ = tonumber(p.profile and p.profile.boostUntil) or 0
	return (boost and until_ > os.time()) and (boost.boostScale or 1) or 1
end

function Match:_checkpoint(p, suffix, completed)
	local mastery={}
	local xp=0
	if completed and p.contributed and not p.disconnectedAt then
		xp=math.floor(self.rules.WaveXP(self.wave)*self.rewardBonus)
		for id in pairs(p.waveHeroes) do
			mastery[id]=self.rules.WaveMastery(self.wave)
			p.masteryEarned[id]=(p.masteryEarned[id] or 0)+mastery[id]
		end
	end
	local gold=p.waveGold p.waveGold=0
	if gold<=0 and xp<=0 then return end
	p.xpEarned+=xp*xpScale(p,self.rules)
	table.insert(self.rewardQueue,{player=p.player,id=self.runId..":"..suffix,
		reward={gold=gold,xp=xp,mastery=mastery,waves=completed and 1 or 0,bosses=p.bossKills or 0,mapId=self.mapId,modeId=self.modeId}})
end

function Match:_processRewards()
	if self.rewardBusy or #self.rewardQueue==0 then return end
	self.rewardBusy=true
	task.spawn(function()
		local remaining={}
		for _,grant in ipairs(self.rewardQueue) do
			local ok=self.profiles:Award(grant.player,grant.id,grant.reward)
			if not ok then table.insert(remaining,grant) end
		end
		self.rewardQueue=remaining self.rewardBusy=false
	end)
end

function Match:_endWave()
	if self.wave <= self.completedWaves then return end
	self.completedWaves=self.wave
	self.mines={}
	self.landings={}
	if self.wave % 5 == 0 and self.recovery > 0 then
		self.baseHP = math.min(self.maxBaseHP, self.baseHP + self.recovery)
	end
	local offering = self.rules.CardWave(self.modeId, self.wave)
	for _,p in pairs(self.participants) do
		if not p.returned then
			if p.contributed and not p.disconnectedAt then
				-- Lobby Gold for the completed wave, banked now so a later
				-- defeat or disconnect never takes it back.
				local banked = math.floor((self.rules.WaveGold(self.modeId, self.wave) + talent(p,"roundGold") * 2) * self.rewardBonus * self:_goldBoost(p))
				p.waveGold += banked p.goldEarned += banked
			end
			self:_checkpoint(p,"wave:"..self.wave,true)
			if p.contributed and not p.disconnectedAt then
				-- The Armored vault pays interest on the Gold kept through the wave.
				local interest = self.rules.BaseInterest(p.base.stats, p.cash)
				local income = math.floor(self.rules.WaveCash(self.wave)*(1+cardStat(p,"energyIncome")+self.rules.TalentEffect(p.profile,"waveIncome")))+p.base.stats.income+interest
				p.cash += income
				self:_fx({kind="WaveCash",amount=income,interest=interest>0 and interest or nil},p.player)
				if self.modeId=="ranked" then
					task.spawn(function() self.profiles:RecordBest(p.player,self.mapId,self.size,self.completedWaves,self.modeId) end)
				end
			end
			if offering then
				p.cardOffers = self.rules.CardOffers(self.seed, self.wave, p.index, p.cards)
			end
		end
	end
	self:_processRewards()
	local total=self.rules.WaveCount(self.modeId,self.mapId)
	if total>0 and self.wave>=total then self:Finish(true) return end
	self.phase,self.prepRemaining,self.skipVotes="Preparing",self.config.PreparationSeconds,{}
	for _,other in pairs(self.participants) do other.endVote=false end
	if offering then
		self.prepRemaining = math.max(self.prepRemaining, CARD_SECONDS)
		self:_notice("CARTAS • Escolha uma carta antes da próxima onda.","CARDS • Pick a card before the next wave.")
	end
	self:_previewThreats()
end

function Match:Finish(victory, ended)
	if not self.running then return end
	self.running,self.phase=false,"Results"
	self.enemies,self.alive={},0
	self.mines={}
	self.hitBuffer={}
	-- Standalone servers share one Workspace between the lobby and the map:
	-- put the lighting back the moment the battle ends, before anyone walks
	-- back and finds the helicarrier still lit like the chapter they just left.
	self.world:ApplyLobbyLighting()
	for _,p in pairs(self.participants) do
		if not p.returned then
			-- rewardBonus already carries party, map of the day and difficulty.
			local party=self.rewardBonus
			local bonus=0
			if victory and p.contributed and not p.disconnectedAt then
				bonus=math.floor(self.rules.VictoryGold(self.modeId,self.mapId) * (1+talent(p,"victoryGold")*0.02) * party * self:_goldBoost(p))
			end
			self:_checkpoint(p,"remaining",false)
			if not p.disconnectedAt then
				table.insert(self.rewardQueue,{player=p.player,id=self.runId..":final",reward={gold=bonus,xp=victory and math.floor(150*party) or 0,difficultyId=self.difficultyId,
					mapId=self.mapId,modeId=self.modeId,victory=victory and p.contributed,tutorial=self.modeId=="tutorial",finished=true,
					noDamage=not self.baseWasDamaged,mastery={},waves=0,wavesReached=p.contributed and self.completedWaves or 0}})
			end
			p.goldEarned+=bonus
			if victory and p.contributed then
				if self.modeId=="tutorial" and not p.profile.tutorialComplete then p.goldEarned+=self.catalog.Chests.rare.cost
				elseif self.modeId=="normal" and not ((p.profile.campaign[self.mapId] or {}).normal) then p.goldEarned+=500 end
			end
			p.xpEarned+=victory and 150*party*xpScale(p,self.rules) or 0
			p.results={victory=victory,ended=ended==true,waves=self.completedWaves,gold=math.floor(p.goldEarned),xp=math.floor(p.xpEarned),
				mapId=self.mapId,modeId=self.modeId,difficultyId=self.difficultyId,mastery=p.masteryEarned,startLevel=p.startLevel,cards=table.clone(p.cards),party=self.partyBonus,featured=self.featuredBonus,event=self.eventBonus}
			p.coins={}
			self:_fx({kind="Clear"},p.player)
		end
	end
	-- The squad's scoreboard, most damage first: the end screen's MVP.
	local team = {}
	for _,p in pairs(self.participants) do
		if not p.returned then
			table.insert(team,{userId=p.player.UserId,name=p.player.DisplayName,damage=math.floor(p.damageDealt or 0),kills=p.kills or 0,gold=math.floor(p.collected or 0)})
		end
	end
	table.sort(team,function(a,b) if a.damage~=b.damage then return a.damage>b.damage end return a.userId<b.userId end)
	for _,p in pairs(self.participants) do if p.results then p.results.team=team end end
	self:_processRewards()
	if ended then
		self:_notice("PARTIDA ENCERRADA • Recorde de "..self.completedWaves.." ondas guardado.", "RUN ENDED • Record of "..self.completedWaves.." waves saved.")
	else
		self:_notice(victory and "VITÓRIA • A resistência continua!" or "BASE DESTRUÍDA • Seu progresso conquistado foi preservado.",
			victory and "VICTORY • The resistance lives on!" or "BASE DESTROYED • Your earned progress is preserved.")
	end
	-- One hook lets the bootstrap close out seats, telemetry and travel together.
	if self.onFinish then
		local ok,problem=pcall(self.onFinish,victory)
		if not ok then warn("[Match] finish hook failed: "..tostring(problem)) end
	end
end

--==============================================================================
-- Cards
--==============================================================================
function Match:_chooseCard(p, id)
	if not contains(p.cardOffers, id) then return false end
	local card = self.catalog.Cards[id]
	table.insert(p.cards, id)
	p.cardOffers = {}
	p.mods = self.rules.CardTotals(p.cards)
	-- Every cached tower stat of this player is now stale.
	p.modsVersion += 1
	local instant = card.instant
	if instant then
		if instant.energy then p.cash += instant.energy end
		if instant.maxHealth then self.maxBaseHP += instant.maxHealth end
		if instant.heal then self.baseHP = math.min(self.maxBaseHP, self.baseHP + instant.heal) end
		if instant.gamble then
			-- Decided here and nowhere else, so a client can never rig the coin.
			if Random.new(self.seed + self.wave * 31 + p.index * 7 + #p.cards):NextNumber() < 0.5 then p.cash += 600 else p.cash = math.max(0, p.cash - 200) end
		end
	end
	self:_fx({kind="CardPicked",cardId=id,rarity=card.rarity},p.player)
	return true
end

--==============================================================================
-- The hero ability: whatever hero stands in the first slot of the loadout.
--==============================================================================
function Match:_abilityOf(p)
	local heroId = p.profile.loadout[1]
	local hero = heroId and self.catalog.Heroes[heroId]
	local def = hero and self.catalog.Abilities[hero.ability]
	if not def then return nil end
	local rank = (p.profile.abilities or {})[heroId] or 1
	local options = {
		abilityPower = talent(p, "abilityPower") * 0.02 + cardStat(p, "abilityPower"),
		cooldownReduction = talent(p, "skillTempo") * 0.01 + cardStat(p, "cooldown"),
	}
	-- extras are the secondary effects of an ultimate; they fire with the main one.
	return def, self.rules.AbilityStats(def, rank, options), heroId, self.rules.AbilityExtras(def, rank, options)
end

function Match:_inRadius(position, radius)
	local found = {}
	for _, enemy in pairs(self.enemies) do
		if enemy.hp > 0 and distanceXZ(enemy.position, position) <= radius then table.insert(found, enemy) end
	end
	return found
end

-- Percentage damage: a share of the target's health, far smaller against bosses.
function Match:_percentDamage(p, enemy, fraction)
	local share = enemy.def.boss and BOSS_SHARE or 1
	self:_damage(enemy, enemy.maxHP * fraction * share, nil, { trueDamage = true })
end

-- Powers that act on the caster's side (a buff, Gold, a core shield or heal)
-- take effect as they are cast; only a power that strikes enemies waits for
-- its look to land.
local SELF_KINDS = { rally = true, energy = true, barrier = true, heal = true, overdrive = true }

-- A targeted power picks its targets as it is cast, so the look can draw a
-- bolt to each of them.
local TARGETS = {}

function TARGETS.chain(self, stats, at)
	local near = self:_inRadius(at, stats.radius)
	table.sort(near, function(a, b) return distanceXZ(a.position, at) < distanceXZ(b.position, at) end)
	local targets = {}
	for index = 1, math.min(#near, stats.count) do targets[index] = near[index] end
	return targets
end

function TARGETS.smite(self)
	local strongest
	for _, enemy in pairs(self.enemies) do
		if not strongest or enemy.hp > strongest.hp then strongest = enemy end
	end
	return { strongest }
end

local ABILITY_HANDLERS = {}

function ABILITY_HANDLERS.blast(self, p, stats, at)
	for _, enemy in ipairs(self:_inRadius(at, stats.radius)) do self:_percentDamage(p, enemy, stats.power) end
end

function ABILITY_HANDLERS.execute(self, p, stats, at)
	for _, enemy in ipairs(self:_inRadius(at, stats.radius)) do
		if enemy.def.boss then self:_damage(enemy, enemy.maxHP * 0.03, nil, { trueDamage = true })
		elseif enemy.hp / enemy.maxHP <= stats.power then self:_damage(enemy, enemy.hp + 1, nil, { trueDamage = true }) end
	end
end

function ABILITY_HANDLERS.rally(self, p, stats)
	p.rallyUntil, p.rallyStat, p.rallyValue = self.elapsed + stats.duration, stats.stat, stats.power
end

function ABILITY_HANDLERS.stun(self, p, stats, at)
	for _, enemy in ipairs(self:_inRadius(at, stats.radius)) do
		if enemy.def.boss then
			if enemy.stunImmuneUntil <= self.elapsed then
				enemy.stunUntil = self.elapsed + stats.duration * BOSS_STUN_SHARE
				enemy.stunImmuneUntil = self.elapsed + BOSS_STUN_IMMUNITY
			end
		else
			enemy.stunUntil = math.max(enemy.stunUntil, self.elapsed + stats.duration)
		end
	end
end

function ABILITY_HANDLERS.slow(self, p, stats, at)
	for _, enemy in ipairs(self:_inRadius(at, stats.radius)) do
		enemy.slow = math.max(enemy.slow, math.min(stats.power, enemy.def.boss and 0.25 or 0.75))
		enemy.slowUntil = math.max(enemy.slowUntil, self.elapsed + stats.duration)
	end
end

function ABILITY_HANDLERS.reveal(self, p, stats, at)
	for _, enemy in ipairs(self:_inRadius(at, stats.radius)) do
		enemy.revealUntil = math.max(enemy.revealUntil, self.elapsed + stats.duration)
		enemy.mark = math.max(enemy.mark, stats.power)
		enemy.markUntil = math.max(enemy.markUntil, self.elapsed + stats.duration)
	end
end

function ABILITY_HANDLERS.overdrive(self, p, stats, at, tower)
	tower.overloadUntil = math.max(tower.overloadUntil or 0, self.elapsed + stats.duration)
	tower.overloadValue = stats.power
end

function ABILITY_HANDLERS.chain(self, p, stats, at)
	local points = {}
	for index, enemy in ipairs(TARGETS.chain(self, stats, at)) do
		points[index] = enemy.position
		self:_percentDamage(p, enemy, stats.power)
	end
	return points
end

function ABILITY_HANDLERS.energy(self, p, stats)
	p.cash += math.floor(stats.power * (200 + 10 * self.wave))
end

function ABILITY_HANDLERS.pull(self, p, stats, at)
	for _, enemy in ipairs(self:_inRadius(at, stats.radius)) do
		if not enemy.def.boss then enemy.progress = math.max(0, enemy.progress - stats.power) end
	end
end

function ABILITY_HANDLERS.barrier(self, p, stats)
	self.shield = math.max(self.shield, stats.power)
	self.shieldUntil = self.elapsed + stats.duration
end

-- Core healing wears off: each heal a commander casts restores 15% less than the
-- one before (never below a fifth). Measured in the competitive sweep, a leader
-- whose power heals the core carried a run to wave 63 against 20 for everyone
-- else, because leaks were simply healed away; this lets a heal slow the end of
-- a run, never cancel it.
function ABILITY_HANDLERS.heal(self, p, stats)
	local casts = p.heals or 0
	p.heals = casts + 1
	self.baseHP = math.min(self.maxBaseHP, self.baseHP + stats.power * math.max(0.2, 0.85 ^ casts))
end

function ABILITY_HANDLERS.weaken(self, p, stats, at)
	for _, enemy in ipairs(self:_inRadius(at, stats.radius)) do
		enemy.armorBreak = math.max(enemy.armorBreak, stats.power)
		enemy.armorUntil = math.max(enemy.armorUntil, self.elapsed + stats.duration)
	end
end

function ABILITY_HANDLERS.burn(self, p, stats, at)
	for _, enemy in ipairs(self:_inRadius(at, stats.radius)) do
		local share = enemy.def.boss and BOSS_SHARE or 1
		enemy.dot = { untilTime = self.elapsed + stats.duration, damage = enemy.maxHP * stats.power * share / stats.duration,
			stats = { trueDamage = true }, nextTick = self.elapsed + 1 }
	end
end

function ABILITY_HANDLERS.smite(self, p, stats)
	local strongest = TARGETS.smite(self)[1]
	if not strongest then return nil end
	self:_percentDamage(p, strongest, stats.power)
	return { strongest.position }
end

-- A power in flight waits in a queue on real time, so the meteor's damage
-- comes as the meteor reaches the ground at 1x, 2x or 3x alike: the client
-- draws the look in real time. Entries run in the order they fall due.
function Match:_later(delay, action)
	self.landingSerial += 1
	table.insert(self.landings, { due = self.landingClock + delay, serial = self.landingSerial, action = action })
end

function Match:_landingsStep(realDt)
	self.landingClock += realDt
	if #self.landings == 0 then return end
	local due, waiting = {}, {}
	for _, entry in ipairs(self.landings) do
		table.insert(entry.due <= self.landingClock + 1e-6 and due or waiting, entry)
	end
	if #due == 0 then return end
	self.landings = waiting
	table.sort(due, function(a, b) if a.due ~= b.due then return a.due < b.due end return a.serial < b.serial end)
	for _, entry in ipairs(due) do entry.action() end
	-- The hit is shown as it lands: the health bars and numbers go out this
	-- step instead of waiting for the next regular sync.
	self.syncTimer = math.max(self.syncTimer, self.config.EnemySyncInterval)
end

-- One effect of a cast, now or when the power lands (Catalog impact). A
-- barrage splits its damage over its missiles; a targeted power strikes each
-- target as its bolt arrives, if it is still standing. Returns the points it
-- strikes for the client's bolts and, when they are struck later, the
-- targets' ids, so each bolt is drawn to where its enemy is by then.
function Match:_resolve(p, def, kind, stats, at, tower, main)
	if SELF_KINDS[kind] or self.rules.AbilityLanding(def, 1) <= 0 then
		return ABILITY_HANDLERS[kind](self, p, stats, at, tower)
	end
	local pick = TARGETS[kind]
	if pick then
		local points, ids = {}, {}
		for index, enemy in ipairs(pick(self, stats, at)) do
			points[index], ids[index] = enemy.position, enemy.id
			self:_later(self.rules.AbilityLanding(def, index), function()
				if self.enemies[enemy.id] == enemy and enemy.hp > 0 then self:_percentDamage(p, enemy, stats.power) end
			end)
		end
		return points, ids
	end
	local hits = (main and kind == "blast") and self.rules.AbilityHits(def) or 1
	local share = stats
	if hits > 1 then
		share = table.clone(stats)
		share.power = stats.power / hits
	end
	for index = 1, hits do
		self:_later(self.rules.AbilityLanding(def, index), function() ABILITY_HANDLERS[kind](self, p, share, at, tower) end)
	end
	return nil
end

function Match:_castAbility(player, p, payload)
	local def, stats, heroId, extras = self:_abilityOf(p)
	if not def then return false, "Sem habilidade equipada. / No ability equipped." end
	-- The client may name the ability it believes it is casting, but the server
	-- only ever casts the one that belongs to the hero in slot one.
	if payload.skillId ~= nil and payload.skillId ~= def.id then return false, "Habilidade não equipada. / Ability not equipped." end
	if self.phase ~= "Wave" then return false, "Use a habilidade durante uma onda. / Use the ability during a wave." end
	if (p.cooldowns[def.id] or 0) > self.elapsed then return false, "Habilidade recarregando. / Ability recharging." end
	local at, tower
	if def.target == "area" then
		local position = payload.position
		if not validPosition(position) or math.abs(position.X) > 112 or math.abs(position.Z) > 112 then return false, "Escolha uma área no mapa. / Select an area on the map." end
		at = Vector3.new(position.X, 0, position.Z)
	elseif def.target == "tower" then
		tower = self.towers[payload.towerId]
		if not tower or tower.ownerId ~= player.UserId then return false, "Selecione uma das suas torres. / Select one of your towers." end
		at = tower.position
	else
		at = self.corePosition
	end
	-- The main effect first, then the extras, each now or as the power lands.
	local points, targets, later = nil, nil, false
	local function gather(found, ids)
		if not found then return end
		points, targets = points or {}, targets or {}
		for index, point in ipairs(found) do
			table.insert(points, point)
			table.insert(targets, ids and ids[index] or "")
			later = later or ids ~= nil
		end
	end
	gather(self:_resolve(p, def, def.kind, stats, at, tower, true))
	local extraFx = {}
	for _, extra in ipairs(extras) do
		gather(self:_resolve(p, def, extra.kind, extra, at, tower, false))
		table.insert(extraFx, { kind = extra.kind, radius = extra.radius, duration = extra.duration, power = extra.power })
	end
	-- Casting counts as taking part, and the hero whose ability it is earns the
	-- mastery even when none of its towers are on the field.
	p.contributed = true
	p.waveHeroes[heroId] = true
	p.cooldowns[def.id] = self.elapsed + stats.cooldown
	-- An area power also sweeps up the caster's Gold lying inside it.
	if def.target == "area" and (stats.radius or 0) > 0 then self:_collectAround(p, at, stats.radius) end
	self:_fx({kind="Ability", abilityId=def.id, abilityKind=def.kind, heroId=heroId, position=at, radius=stats.radius,
		duration=stats.duration, power=stats.power, points=points, targets=later and targets or nil, towerId=tower and tower.id, ownerId=player.UserId,
		ultimate=def.ultimate or nil, extras=#extraFx>0 and extraFx or nil,
		color=Color3.fromRGB(def.color[1], def.color[2], def.color[3]),
		shake=def.ultimate and 1.1 or ((def.kind=="blast" or def.kind=="smite") and 0.5 or 0.15)})
	return true
end

--==============================================================================
-- Simulation
--==============================================================================
-- Base defenses use the same server-owned damage/reward path as heroes.
-- Walls and soldiers trade their own HP for enemy damage; no infinite block.
function Match:_basesStep(dt)
	for uid,p in pairs(self.participants) do
		if p.returned or p.disconnectedAt then continue end
		local base=p.base; local stats=base.stats
		if self.elapsed-base.wallHitAt>=5 then base.wall=math.min(stats.wall,base.wall+stats.regen*dt) end
		-- The barricade on the road shows how much it has left.
		if stats.wall>0 and self.world.SetBarrierHealth then
			local ratio=base.wall/stats.wall
			if math.abs(ratio-(base.shownWall or -1))>=0.1 or (ratio>=1 and base.shownWall~=1) then base.shownWall=ratio; self.world:SetBarrierHealth(p.index,ratio) end
		end
		if self.phase~="Wave" then continue end
		local source={ownerId=uid}
		if (stats.chill or 0)>0 then
			-- The Polar station's ice field slows everything inside it, a boss
			-- less, and lets go a moment after an enemy leaves. Two fields never
			-- stack: each step an enemy keeps the strongest one reaching it.
			local center=base.visualPosition or self.corePosition
			for _,enemy in pairs(self.enemies) do
				if enemy.hp>0 and distanceXZ(enemy.position,center)<=stats.range then
					if enemy.chillAt~=self.elapsed then enemy.chillAt,enemy.chill=self.elapsed,0 end
					enemy.chill=math.max(enemy.chill,self.rules.BaseChill(stats,enemy.def.boss)); enemy.chillUntil=self.elapsed+0.25
				end
			end
		end
		if stats.damage>0 and self.elapsed>=base.nextAttack then
			-- The gun measures its range from the same spot it fires from.
			local muzzle=base.visualPosition or self.corePosition
			local target,best=nil,-math.huge
			for _,enemy in pairs(self.enemies) do
				local remaining=self.routeCache[enemy.routeIndex].total-enemy.progress
				if enemy.hp>0 and not enemy.def.stealth and distanceXZ(enemy.position,muzzle)<=stats.range and -remaining>best then target,best=enemy,-remaining end
			end
			if target then
				base.nextAttack=self.elapsed+1.2
				self:_damage(target,stats.damage,source,{damageType=base.id=="sanctum" and "magic" or "tech"})
				self:_fx({kind="BaseShot",from=muzzle+Vector3.new(0,6,0),to=target.position+Vector3.new(0,target.def.air and 8 or 2,0),color=Color3.fromRGB(unpack(self.catalog.Bases[base.id].color))})
			end
		end
		if stats.wall>0 and base.wall>0 then
			for _,enemy in pairs(self.enemies) do
				local remaining=self.routeCache[enemy.routeIndex].total-enemy.progress
				if enemy.hp>0 and not enemy.def.air and remaining<=(self.world.BarrierDistance or 15) then
					local spent=math.min(base.wall,enemy.hp+enemy.shield)
					base.wall-=spent; base.wallHitAt=self.elapsed
					self:_damage(enemy,spent,source,{trueDamage=true})
					self:_fx({kind="Pulse",position=enemy.position,radius=4,color=Color3.fromRGB(150,225,255),duration=0.3})
					if base.wall<=0 then break end
				end
			end
		end
		if stats.soldier>0 and self.elapsed>=base.nextSoldier then
			local count=0; for _,soldier in pairs(self.soldiers) do if soldier.ownerId==uid then count+=1 end end
			if count<6 then
				base.nextSoldier=self.elapsed+stats.interval; base.routeCursor=base.routeCursor%#self.routeCache+1
				local route=self.routeCache[base.routeCursor]; local id=self:_nextId("s")
				self.soldiers[id]={id=id,ownerId=uid,routeIndex=base.routeCursor,progress=route.total,hp=stats.soldier,maxHP=stats.soldier,baseId=base.id,position=self.corePosition}
			end
		end
	end
	if self.phase~="Wave" then return end
	for id,soldier in pairs(self.soldiers) do
		local p=self.participants[soldier.ownerId]
		if not p or p.returned or p.disconnectedAt then self.soldiers[id]=nil; continue end
		local before=soldier.progress
		soldier.progress-=11*dt
		soldier.position=self:_pathPosition(soldier.routeIndex,math.max(0,soldier.progress))
		-- Sorted route intersections make a large dt hit the nearest target first.
		local collisions={}
		for _,enemy in pairs(self.enemies) do
			if enemy.hp>0 and not enemy.def.air and enemy.routeIndex==soldier.routeIndex and enemy.progress>=soldier.progress-3 and enemy.progress<=before+3 then table.insert(collisions,enemy) end
		end
		table.sort(collisions,function(a,b) return a.progress>b.progress end)
		for _,enemy in ipairs(collisions) do
			if enemy.hp>0 and soldier.hp>0 then
				local spent=math.min(soldier.hp,enemy.hp+enemy.shield); soldier.hp-=spent
				self:_damage(enemy,spent,{ownerId=soldier.ownerId},{trueDamage=true})
			end
		end
		if soldier.hp<=0 or soldier.progress<=0 then self.soldiers[id]=nil end
	end
end

function Match:Step(dt)
	self.rewardTimer+=dt
	if self.rewardTimer>=5 then self.rewardTimer=0 self:_processRewards() end
	if not self.running then return end
	self.elapsed+=dt
	local anyone=false
	for _,p in pairs(self.participants) do
		if not p.returned and not p.disconnectedAt then anyone=true end
		if p.disconnectedAt and os.clock()-p.disconnectedAt>self.config.ReconnectSeconds then p.returned=true end
	end
	if not anyone then
		local waiting=false for _,p in pairs(self.participants) do if not p.returned then waiting=true end end
		if not waiting then self:Finish(false) return end
	end
	if self.shieldUntil<=self.elapsed then self.shield=0 end
	for _,p in pairs(self.participants) do
		if not p.returned and not p.disconnectedAt then
			local root=p.player.Character and p.player.Character:FindFirstChild("HumanoidRootPart")
			-- Falling off the battlefield puts the commander back at their post.
			if root and root.Position.Y < -30 and self.world.MovePlayer then
				pcall(function() self.world:MovePlayer(p.player,true,p.index) end)
			end
			local radius=self:_magnet(p)
			for id,coin in pairs(p.coins) do
				if (p.profile.passes and p.profile.passes.collector) or (root and (root.Position-coin.position).Magnitude<=radius) then
					p.collected+=coin.value p.cash+=coin.value p.coins[id]=nil self:_fx({kind="CoinRemove",id=id,value=coin.value},p.player)
				end
			end
			-- Scavenger heroes pull in their owner's Gold that lands near them.
			if next(p.coins) then
				for _,tower in pairs(self.towers) do
					local hero=tower.ownerId==p.player.UserId and self.catalog.Heroes[tower.heroId]
					if hero and hero.pickup then self:_collectAround(p,tower.position,hero.pickup) end
				end
			end
		end
	end
	-- dt is match time; preparation and network sync run on real time, so 2x
	-- speeds up the fighting without halving the time to build or to pick a
	-- card, and without doubling the enemy updates sent to every client.
	local realDt = dt / self:Speed()
	self:_refreshSpeed()
	self:_basesStep(dt)
	if self.phase=="Preparing" then
		self:_checkSkip()
		self.prepRemaining-=realDt
		if self.prepRemaining<=0 then self:_beginWave() end
	elseif self.phase=="Wave" then
		self.spawnTimer-=dt
		if self.spawnIndex<=#self.pendingSpawns and self.spawnTimer<=0 and self.alive<self.config.MaxEnemies then
			local spec=self.pendingSpawns[self.spawnIndex]
			self:_spawn(spec) self.spawnIndex+=1 self.spawnTimer=spec.delay or 0.7
		end
		-- Reveal before targeting, independent of hash iteration order.
		for _,tower in pairs(self.towers) do
			local stats=self:_baseStats(tower)
			if stats.reveal and (tower.stunnedUntil or 0)<=self.elapsed then
				for _,enemy in pairs(self.enemies) do if distanceXZ(tower.position,enemy.position)<=stats.range then enemy.revealUntil=self.elapsed+0.3 end end
			end
		end
		for _,tower in pairs(self.towers) do
			-- Build combat stats only at the attack deadline or the first short
			-- anticipation window, not on every simulation tick during cooldown.
			local due = tower.nextAttack<=self.elapsed
			local anticipating = tower.windupFor~=tower.nextAttack and tower.nextAttack-self.elapsed<=0.23
			if (tower.stunnedUntil or 0)<=self.elapsed and (due or anticipating) then
				local stats=self:_towerStats(tower)
				if due then
					if self:_attack(tower,stats) then tower.nextAttack=self.elapsed+stats.interval else tower.nextAttack=self.elapsed+0.2 end
				else
					self:_windup(tower,stats)
				end
			end
		end
		self:_landingsStep(realDt)
		self:_flushSplits()
		self:_enemiesStep(dt)
		self:_minesStep()
		self:_hazardStep(dt)
		self:_flushSplits()
		if self.running and self.alive==0 and self.spawnIndex>#self.pendingSpawns then self:_endWave() end
	end
	self.syncTimer+=realDt
	if self.syncTimer>=self.config.EnemySyncInterval then
		self.syncTimer=0 local enemies={}
		-- Replicate route position, not a second visual flight offset. Client
		-- torso height and Shot endpoints use the same 8-stud airborne center.
		-- lk: the support hastening this enemy, for the link the client draws;
		-- ch: a summoner's summons left. ri/pg/sp: road, distance along it and
		-- speed per real second, so clients walk enemies smoothly between syncs
		-- instead of hopping to each new position.
		local timeScale=self:Speed()
		for _,e in pairs(self.enemies) do
			local boosted=e.boostUntil and e.boostUntil>self.elapsed
			table.insert(enemies,{id=e.id,enemyId=e.enemyId,position=e.position,hp=e.hp,maxHP=e.maxHP,phase=e.phase,st=self:_statusOf(e),final=e.final or nil,
				lk=boosted and e.boostedBy or nil,ch=e.enemyId=="summoner" and math.max(0,2-(e.summons or 0)) or nil,
				ri=e.routeIndex,pg=math.floor(e.progress*100+0.5)/100,sp=math.floor((e.speedNow or 0)*timeScale*100+0.5)/100})
		end
		-- The heaviest few hits since the last sync, one number per enemy.
		local hits, order = {}, {}
		for id, amount in pairs(self.hitBuffer) do
			if self.enemies[id] then table.insert(order, id) end
		end
		table.sort(order, function(a, b) return self.hitBuffer[a] > self.hitBuffer[b] end)
		for index = 1, math.min(#order, 10) do hits[order[index]] = math.floor(self.hitBuffer[order[index]]) end
		local crits
		for id in pairs(self.critBuffer) do if hits[id] then crits = crits or {}; crits[id] = true end end
		self.hitBuffer, self.critBuffer = {}, {}
		self:_fx({kind="EnemySync",enemies=enemies,hits=next(hits) and hits or nil,crits=crits})
		local soldiers={}
		for _,s in pairs(self.soldiers) do table.insert(soldiers,{id=s.id,position=s.position,hp=s.hp,maxHP=s.maxHP,baseId=s.baseId}) end
		self:_fx({kind="SoldierSync",soldiers=soldiers})
		-- The mines on the road, sent only while there are some (and once more
		-- when the last one is gone, so the clients clear them).
		if next(self.mines) or self.minesShown then
			local rows={}
			for _,mine in pairs(self.mines) do
				local hero=self.towers[mine.towerId] and self.catalog.Heroes[self.towers[mine.towerId].heroId]
				table.insert(rows,{id=mine.id,position=mine.position,radius=mine.radius,color=hero and Color3.fromRGB(hero.color[1],hero.color[2],hero.color[3]) or nil})
			end
			self.minesShown=#rows>0
			self:_fx({kind="MineSync",mines=rows})
		end
	end
end

-- How far a commander's magnet reaches for match Gold on the ground.
function Match:_magnet(p)
	-- The capstone of the Fortune branch: the whole map is within reach.
	if talent(p,"globalMagnet")>0 and talent(p,"victoryGold")>=self.catalog.Talents.globalMagnet.requiredRank then return self.catalog.GlobalMagnetRadius end
	local per = ((self.catalog.Talents.magnet or {}).effect or 15) / 100
	return self.config.CollectRadius*(1+talent(p,"magnet")*per)
end

-- The solid things of a battlefield that are not roads: the core and every
-- commander's base. Sent to the clients too, so the preview agrees.
function Match:_blockers()
	local list={}
	if self.corePosition then table.insert(list,{x=self.corePosition.X,z=self.corePosition.Z,r=8}) end
	for _,p in pairs(self.participants) do
		local at=p.base and p.base.visualPosition
		if at then table.insert(list,{x=at.X,z=at.Z,r=6.5}) end
	end
	return list
end

-- The shared placement rule (Rules.BuildCheck): true, or false and a reason key.
function Match:_validBuild(position)
	if not validPosition(position) then return false,"bounds" end
	local towers={}
	for _,tower in pairs(self.towers) do table.insert(towers,tower.position) end
	return self.rules.BuildCheck(self.mapId,position,towers,self.config,self:_blockers())
end

function Match:Handle(player,action,payload)
	local p=self.participants[player.UserId]
	if not p or p.returned then return false,"Você não está nesta partida. / You are not in this match." end
	if action=="ReturnLobby" then
		if self.phase~="Results" then return false,"Termine a partida primeiro. / Finish the match first." end
		if self.rewardBusy or #self.rewardQueue>0 then return false,"Salvando recompensas. Tente novamente em instantes. / Saving rewards; try again shortly." end
		p.returned=true self.world:MovePlayer(player,false) return true
	end
	-- Play again: every commander still on the results screen votes, and the
	-- same map and mode restart right here for exactly those players.
	if action=="PlayAgain" then
		if self.phase~="Results" or self.running then return false,"Termine a partida primeiro. / Finish the match first." end
		if self.modeId=="tutorial" then return false,"O treino terminou: escolha uma missão no lobby! / Training is over: pick a mission in the lobby!" end
		if self.rewardBusy or #self.rewardQueue>0 then return false,"Salvando recompensas. Tente novamente em instantes. / Saving rewards; try again shortly." end
		p.again=true
		local voters,total={},0
		for _,q in pairs(self.participants) do
			if not q.returned and q.player.Parent==Players then
				total+=1
				if q.again then table.insert(voters,q) end
			end
		end
		for _,q in pairs(self.participants) do
			if q.results then q.results.againVotes,q.results.againTotal,q.results.again=#voters,total,q.again==true end
		end
		if #voters<total then return true end
		table.sort(voters,function(a,b) return a.index<b.index end)
		local members={}
		for _,q in ipairs(voters) do table.insert(members,q.player); q.returned=true end
		local ok,problem=self:Start(members,self.mapId,self.modeId,nil,self.difficultyId)
		if not ok then
			for _,q in ipairs(voters) do q.returned,q.again=false,false end
			return false,problem
		end
		return true
	end
	if not self.running then return false,"A partida terminou. / The match ended." end
	if action=="UpgradeBase" then
		local base=p.base; local stats=base.stats
		if payload.expectedLevel~=base.level then return false,"Base atualizada. / Base changed." end
		if base.level>=5 then return false,"Base no máximo. / Base maxed." end
		if p.cash<stats.upgradeCost then return false,"Ouro insuficiente. / Not enough Gold." end
		p.cash-=stats.upgradeCost; base.level+=1
		base.stats=self.rules.BaseStats(base.id,base.level)
		local added=math.floor(base.stats.hp/self.size)-math.floor(stats.hp/self.size)
		self.maxBaseHP+=added; self.baseHP+=added
		base.wall+=base.stats.wall-stats.wall
		if self.world.UpdateBase then base.visualPosition=self.world:UpdateBase(p.index,base,self.corePosition,p.player.UserId) end
		if self.world.UpdateBarrier then self.world:UpdateBarrier(p.index,base,self.routeCache,base.stats.wall>0 and base.wall/base.stats.wall or 1) end
		self:_fx({kind="Pulse",position=self.corePosition,radius=12,color=Color3.fromRGB(unpack(self.catalog.Bases[base.id].color)),duration=0.5})
		return true
	elseif action=="PlaceTower" then
		local id=payload.heroId local hero=type(id)=="string" and self.catalog.Heroes[id]
		if not hero or not contains(p.profile.loadout,id) or not p.profile.heroes[id] then return false,"Herói não equipado. / Hero not equipped." end
		local reasons=self.rules.BuildReasons
		local function refuse(key) return false,reasons[key].pt..". / "..reasons[key].en.."." end
		if p.towerCount>=self.rules.TowerLimit(self.size) then return refuse("limit") end
		local same=0
		for _,t in pairs(self.towers) do if t.ownerId==player.UserId and t.heroId==id then same+=1 end end
		if same>=self.rules.HeroLimit(id) then return refuse("unitLimit") end
		local cost=self.rules.PlacementCost(hero,p.profile,{discount=cardStat(p,"discount")})
		if p.cash<cost then return refuse("cash") end
		local valid,reason=self:_validBuild(payload.position)
		if not valid then return refuse(reason or "bounds") end
		local towerId=self:_nextId("t") local pos=Vector3.new(payload.position.X,0,payload.position.Z)
		local tower={id=towerId,heroId=id,ownerId=player.UserId,position=pos,level=1,branch=nil,priority="First",invested=cost,nextAttack=0,totalDamage=0,kills=0,critOffset=(self.nextId*7)%11}
		local owned=p.profile.heroes and p.profile.heroes[id]
		tower.model=self.world:MakeTower(towerId,id,pos,player.UserId,{shiny=type(owned)=="table" and owned.shiny==true})
		self.towers[towerId]=tower p.cash-=cost p.towerCount+=1
		-- towerId only lets every client play the hero's arrival hop (a look).
		self:_fx({kind="Pulse",position=pos,radius=5,color=Color3.fromRGB(unpack(hero.color)),duration=0.45,towerId=towerId})
		return true,{towerId=towerId,cost=cost}
	elseif action=="UpgradeTower" or action=="SellTower" or action=="SetPriority" then
		local tower=self.towers[payload.towerId]
		if not tower or tower.ownerId~=player.UserId then return false,"Torre inválida. / Invalid tower." end
		if action=="SellTower" then
			p.cash+=math.floor(tower.invested*0.7) p.towerCount-=1 tower.model:Destroy() self.towers[tower.id]=nil return true
		elseif action=="SetPriority" then
			if not contains({"First","Last","Strongest","Nearest"},payload.priority) then return false,"Prioridade inválida. / Invalid priority." end
			tower.priority=payload.priority return true
		end
		local stats=self:_baseStats(tower)
		if tower.level>=5 then return false,"Melhoria máxima. / Maximum upgrade." end
		if tower.level==4 and payload.branch~=1 and payload.branch~=2 then return false,"Escolha uma especialização. / Choose a specialization." end
		if p.cash<stats.upgradeCost then return false,"Ouro insuficiente. / Not enough Gold." end
		p.cash-=stats.upgradeCost tower.invested+=stats.upgradeCost tower.level+=1
		if tower.level==5 then tower.branch=payload.branch end
		local mastery=p.profile.heroes[tower.heroId]
		self.world:UpgradeTower(tower.model,tower.level,tower.branch,mastery and mastery.level or 1)
		self:_fx({kind="TowerUpgrade",towerId=tower.id,level=tower.level,branch=tower.branch})
		return true
	elseif action=="SkinShot" then
		-- The Iron armour skin's repulsor (owner, 17/10): its owner fires where
		-- they click, from their own character, a small hit on a short beat.
		if not (p.profile.passes and p.profile.passes.ironSkin) then return false,"Skin não ativa. / Skin not active." end
		if self.phase~="Wave" and self.phase~="Preparing" then return false,"Aguarde a partida. / Wait for the battle." end
		local target=payload.position
		if typeof(target)~="Vector3" then return false,"Alvo inválido. / Invalid target." end
		local rule=self.rules.SkinShot
		if self.elapsed<(p.skinReadyAt or 0) then return false,"Recarregando. / Recharging." end
		local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root then return false,"Sem personagem. / No character." end
		local from=root.Position
		if distanceXZ(from,target)>rule.range then return false,"Longe demais. / Too far." end
		p.skinReadyAt=self.elapsed+rule.cooldown
		local damage=self.rules.SkinShotDamage(self.wave)
		local stats={damageType="tech",armorPierce=0.1,bossDamage=0}
		local hits={}
		for _,enemy in pairs(self.enemies) do
			if enemy.hp>0 and distanceXZ(enemy.position,target)<=rule.radius and not enemy.def.illusion then table.insert(hits,enemy) end
		end
		for _,enemy in ipairs(hits) do self:_damage(enemy,damage,nil,stats) end
		if #hits>0 then p.contributed=true end
		self:_flushSplits()
		self:_fx({kind="Shot",from=from+Vector3.new(0,1.6,0),to=Vector3.new(target.X,(target.Y or 0)+1,target.Z),color=Color3.fromRGB(120,220,255),heroId="ironman",style="beam",skin=true})
		return true,{hits=#hits}
	elseif action=="SkipWave" then
		if self.phase~="Preparing" then return false,"Aguarde o intervalo. / Wait for preparation." end
		if #p.cardOffers>0 then return false,"Escolha uma carta primeiro. / Pick a card first." end
		p.skip=true self.skipVotes[player.UserId]=true
		self:_checkSkip()
		return true
	elseif action=="VoteEnd" then
		if self.modeId~="ranked" then return false,"Só no competitivo. / Competitive only." end
		if self.phase~="Preparing" or self.completedWaves<1 then return false,"Vote entre as ondas. / Vote between waves." end
		if type(payload.on)~="boolean" then return false,"Voto inválido. / Invalid vote." end
		p.endVote=payload.on
		for _,other in pairs(self.participants) do
			if not other.returned and not other.disconnectedAt and not other.endVote then return true,{ended=false} end
		end
		self:Finish(false,true)
		return true,{ended=true}
	elseif action=="SetSpeed" then
		if payload.speed~=1 and payload.speed~=2 and payload.speed~=3 then return false,"Velocidade inválida. / Invalid speed." end
		if payload.speed==3 and not (p.profile.passes and p.profile.passes.speed3) then return false,"A velocidade 3x é uma vantagem da loja. / 3x speed is a perk from the shop." end
		p.speedVote=payload.speed
		self:_refreshSpeed()
		return true,{speed=self.speed}
	elseif action=="Ping" then
		-- A squad's marker: "look here". Relayed to everyone in the match, at most
		-- one per commander every 1.5 s; alone there is nobody to tell.
		if self.size<2 then return false,"Marcar um local é para jogar em grupo. / Pings are for playing in a group." end
		local at=payload.position
		if not validPosition(at) or math.abs(at.X)>112 or math.abs(at.Z)>112 then return false,"Marque um ponto do mapa. / Mark a point on the map." end
		if os.clock()-(p.lastPing or -10)<1.5 then return false,"Calma! / Easy!" end
		p.lastPing=os.clock()
		self:_fx({kind="Ping",position=Vector3.new(at.X,0,at.Z),name=player.DisplayName,ownerId=player.UserId,slot=p.index})
		return true
	elseif action=="SetAutoSkip" then
		if type(payload.on)~="boolean" then return false,"Configuração inválida. / Invalid setting." end
		p.autoSkip=payload.on
		self:_checkSkip()
		return true
	elseif action=="ChooseCard" then
		if type(payload.cardId)~="string" then return false,"Carta inválida. / Invalid card." end
		return self:_chooseCard(p,payload.cardId),"Carta inválida. / Invalid card."
	elseif action=="CollectCoin" then
		local coin=p.coins[payload.coinId] local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not coin or not root or (root.Position-coin.position).Magnitude>self:_magnet(p)+1 then return false,"Moeda fora do alcance. / Coin out of range." end
		p.collected+=coin.value p.cash+=coin.value p.coins[payload.coinId]=nil self:_fx({kind="CoinRemove",id=payload.coinId,value=coin.value},player) return true
	elseif action=="CastSkill" then
		return self:_castAbility(player,p,payload)
	end
	return false,"Ação desconhecida. / Unknown action."
end

function Match:Snapshot(player)
	local p=self.participants[player.UserId]
	if not p or p.returned then return nil end
	local towers={}
	for _,t in pairs(self.towers) do
		local stats=self:_towerStats(t)
		local preview=t.ownerId==player.UserId and self:_upgradePreview(t) or nil
		table.insert(towers,{id=t.id,heroId=t.heroId,ownerId=t.ownerId,position=t.position,level=t.level,branch=t.branch,
			totalDamage=math.floor(t.totalDamage or 0),kills=t.kills or 0,
			priority=t.priority,invested=t.invested,damage=stats.damage,range=stats.range,rate=stats.rate,slow=stats.slow,splash=stats.splash,upgradeCost=stats.upgradeCost,
			base=preview and statLine(self:_baseStats(t)) or nil,next=preview and preview.next or nil,branches=preview and preview.branches or nil,
			stunned=(t.stunnedUntil or 0)>self.elapsed and math.ceil((t.stunnedUntil-self.elapsed)*10)/10 or nil})
	end
	-- The ability the commander fights with: always the first slot's hero.
	local ability
	local def, stats, heroId = self:_abilityOf(p)
	if def then
		ability = { id = def.id, heroId = heroId, kind = def.kind, target = def.target, rank = stats.rank,
			cooldown = math.max(0, (p.cooldowns[def.id] or 0) - self.elapsed), cooldownTotal = stats.cooldown,
			radius = stats.radius, duration = stats.duration, power = stats.power, ultimate = def.ultimate or nil }
	end
	local boss
	for _,e in pairs(self.enemies) do
		if e.def.boss and not e.rewardless then boss={id=e.id,name=e.def.name,hp=e.hp,maxHP=e.maxHP,phase=e.phase,hint=e.hint,final=e.final or nil} break end
	end
	local votes=0 for _ in pairs(self.skipVotes or {}) do votes+=1 end
	local speedVotes,speedPlayers=0,0 for _,other in pairs(self.participants) do if not other.returned then speedPlayers+=1 if (other.speedVote or 1)>=2 and (p.speedVote or 1)>1 then speedVotes+=1 end end end
	-- The next boss wave, so the wave bar can count down to it.
	local nextBoss
	local total=self.rules.WaveCount(self.modeId,self.mapId)
	for wave=self.wave+ (self.phase=="Wave" and 0 or 1), (total>0 and total or self.wave+10) do
		if self.rules.IsBossWave(self.modeId, wave, self.mapId) then nextBoss=wave break end
	end
	local waiting,endVotes=0,0
	for _,coin in pairs(p.coins) do waiting+=coin.value end
	for _,other in pairs(self.participants) do if not other.returned and other.endVote then endVotes+=1 end end
	return {runId=self.runId,mapId=self.mapId,modeId=self.modeId,difficultyId=self.difficultyId,wave=self.wave,totalWaves=total,
		base={id=p.base.id,level=p.base.level,stats=table.clone(p.base.stats),wall=math.floor(p.base.wall)},
		completedWaves=self.completedWaves,baseHP=self.baseHP,maxBaseHP=self.maxBaseHP,shield=self.shield,leakScale=self.rules.LeakScale(self.wave),waveShield=self.waveShieldLeft,cash=math.floor(p.cash),coinsWaiting=waiting,magnet=self:_magnet(p),blockers=self:_blockers(),towerLimit=self.rules.TowerLimit(self.size),
		prepRemaining=math.max(0,math.ceil(self.prepRemaining)),enemies=self.alive,elapsed=self.elapsed,ability=ability,
		cards=table.clone(p.cards),cardOffers=p.cardOffers,cardMode=self.cardMode,goldEarned=p.goldEarned,xpEarned=p.xpEarned,towers=towers,boss=boss,
		partySize=self.size,skipVotes=votes,nextBoss=nextBoss,threats=self.phase=="Preparing" and self.nextThreats or nil,
		mutation=self.phase=="Preparing" and self.nextMutation or (self.phase=="Wave" and self.mutation or nil),
			nextPaths=self.phase=="Preparing" and self.nextPaths or nil,newEntrance=self.phase=="Preparing" and self.newEntrance or nil,
		speed=self:Speed(),speedVote=p.speedVote or 1,speedVotes=speedVotes,speedPlayers=speedPlayers,autoSkip=p.autoSkip==true,endVote=p.endVote==true,endVotes=endVotes},p.results
end

return Match
