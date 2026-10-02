# Integration contract

## Invocação física e filas por destino — 27/09/2026

O mercado tem dois salões: **Invocar heróis** (`Chest_rare`) e **Invocar bases**
(`Chest_base_rare`). Aproximar-se do piso verde abre a coleção correspondente.
Cada salão permite escolher seus cinco baús existentes, consultar as chances
efetivas e confirmar uma invocação. Não mudam preços, garantias ou compensações.
No computador, retratos/chances e compra aparecem lado a lado. Em telas menores,
os baús ficam numa faixa horizontal; cada coleção conserva sua rolagem.
`OpenChest` e `BuyGuaranteed` validam no servidor a presença no salão da coleção;
campos irrelevantes do cliente não podem escolher outra zona de compra.

**Base ativa** substitui o botão Jogar no HUD. `EquipBase` continua validando
posse no lobby; a base entra automaticamente na próxima partida. O resultado
de uma invocação de base também permite ativá-la. Não existe colocação manual
da base no campo.

Cada destino do catálogo possui três filas independentes: o ID antigo mantém
a fila 1; `id:2` e `id:3` identificam as outras. São quatro lugares por fila,
com ordem de contato validada pela posição do personagem, contagem própria,
saída e bloqueio da quinta pessoa. `elevator` acrescenta `queueId`, `slot` e
`departing`. O primeiro jogador pode antecipar a partida; o destino permanece
fixo. Durante um teleporte pendente os lugares ficam reservados e não há uma
segunda partida do mesmo grupo. Falhas devolvem a fila à contagem para tentar
novamente.

`StartMatch` é recusado para clientes antigos. Só uma fila física inicia a
partida. O guia mostra o caminho ao portal, inclusive para o treinamento.
No Studio/Standalone continua havendo uma batalha por servidor; outras filas
aguardam. Em produção, servidores Lobby usam o teleporte reservado existente.

As placas usam uma prévia 3D ilustrada com as rotas de cada mapa, sem IDs de
imagem externos. O cliente monta a SurfaceGui em PlayerGui e define Adornee e
CurrentCamera com uma câmera local (câmeras do servidor não replicam).
ViewportFrames dentro de Workspace não são renderizados pelo
Roblox. Os modelos das prévias são excluídos da correção de faces do cenário.
Não são fotografias capturadas dos mapas nem assets copiados das referências.

Verificação: filas, lotação, ordem, saída, falha/concorrência de transferência,
compra no salão correto, bootstrap e layout PT/EN cobertos pela suíte local.
O teleporte publicado com três grupos e o toque/desempenho em celular real
continuam exigindo a experiência publicada e aparelhos de teste.
Para sincronizar no Team Create correto, use `--place-id 97132875544830`
com `tools/studio_sync.py`; um destino diferente é recusado antes de escrever.

## Bases e recrutamento — 2026.4

`Catalog.Chests` contém dez IDs; `HeroChestOrder` e `BaseChestOrder` separam
as duas coleções. `OpenChest {chestId}` mantém a transação existente e retorna
`result.heroId` **ou** `result.baseId`, mais raridade, repetido e compensação.
Contadores de garantia são independentes. O perfil adiciona `bases: {[id]: true}`
e `equippedBase`; migração concede `outpost` sem modificar Ouro ou heróis.

`EquipBase {baseId}` só funciona no lobby com uma base possuída.
`UpgradeBase {expectedLevel}` só funciona na partida; valida nível e Ouro da partida
no servidor. A intenção não aceita custo, dano, renda ou ID de outro jogador.
`match.base` replica `{id, level, stats, wall}` do jogador. `Rules.BaseStats`
centraliza custos e atributos. A contribuição de vida ao núcleo é dividida
pelo tamanho inicial do grupo. Níveis e soldados ficam apenas na partida.

FX `BaseShot {from,to,color}` e `SoldierSync {soldiers}` representam decisões
do servidor. Cada soldado contém `id,position,hp,maxHP,baseId`. O cliente só
interpola o visual. Limite de seis soldados por comandante; dano e recompensas
usam o mesmo caminho autoritativo das torres. [BASES.md](docs/BASES.md) documenta
o conteúdo e a economia atuais; as seções antigas abaixo são históricas.

Minas (herói `nightstalker`, `attack = "mine"`): a torre não acerta o alvo, planta
uma mina na estrada à frente dele (até `mineMax` por torre, afastadas ≥ 7 studs e
dentro do alcance). O servidor guarda `Match.mines`; a mina detona quando um
inimigo terrestre chega a 3,4 studs, ferindo todo inimigo terrestre no
`mineRadius` (e paralisando com `mineStun`, chefes só um quarto), e expira em 30 s,
no fim da onda ou quando a torre some. FX `MineSync {mines = {{id,position,radius,color}}}`
sai junto da sincronização dos inimigos enquanto houver minas (e mais uma vez vazio
quando a última some); `MineBlast {id,position,radius,color,towerId}` é só o visual
da explosão. O cliente apenas desenha a lista e ignora linhas malformadas.

Sections below are appended in the order they were written, most recent
first, and some are superseded by later ones (each says so where it
happens — e.g. "Contratos atuais" replaces the historical ability/purchase
contracts, "ranked substitui hard" replaces every earlier mention of a hard
mode). Where anything conflicts, **the source is the ground truth**:
`src/shared/Catalog.luau` for data (hero list, actions the server actually
implements are in `ACTIONS`/`Handle` in each service file), and
`docs/HEROES.md` for a hero/ability reference that is generated from the
catalog and cannot drift. The "Action names" section further down still
lists several actions (`BuyHero`, `BuySkill`, `SetSkills`, `ChooseProtocol`)
that no longer exist — see "Contratos atuais — recrutamento e líder" for
their replacements (`OpenChest`, `SetLoadout`, `UpgradeAbility`,
`UpgradeTalent`/`ResetTalents`, `ChooseCard`) and `PlayerService.luau`'s
`ACTIONS` table for the exact, current, authoritative list.

## Promo codes, group reward, invites — 22/09/2026

`src/server/Codes.luau` (server-only; never replicates) maps a capitalised
code to a reward `{gold?, xp?, chest?, title?, expires?}` and is passed as
the fifth argument of `PlayerService.new` (tests may use `config.Codes`).
`RedeemCode {code}`: spaces removed, case ignored, 3–32 letters/digits.
Unknown, malformed or expired codes are refused **before** any DataStore
call; six misses in a minute per player are throttled. A valid code is
recorded in `profile.codes[CODE] = time` (not public) and paid through
`_payReward`, so a code can also open a chest (rolls drawn up front, like
every chest). `ClaimGroupReward {}` needs `Config.GroupId > 0` and
`player:IsInGroup(GroupId)` (a failed check pays nothing); it pays
`Catalog.Rewards.group` once (`rewards.groupClaimed`). Rewards status gains
`group = {claimed, gold}` (not counted as claimable: membership lives on
Roblox). The rewards panel has the code box, the group card (only when
`Config.GroupId` is set) and an invite button using `SocialService`.
`GroupId` is an optional key of the release config.

## Match speed and auto-skip — 22/09/2026

Match actions `SetSpeed {speed = 1|2|3}` → `{speed}` (3 needs the `speed3` pass; the match runs at the slowest speed anyone present chose) and `SetAutoSkip {on}`. `Ping {position}` (squads of 2+, one per commander every 1.5 s, flat on the ground, inside the map) is relayed to everyone in the match as an FX `Ping {position, name, ownerId, slot}`; the client draws a marker for four seconds (long press on touch, G on a keyboard).
`Match:Speed()` is 2 only while every participant still playing (not
returned, not disconnected) voted 2; a solo player decides alone; a finished
match is always 1. The bootstrap multiplies its frame time by `match:Speed()`
before feeding the fixed-step accumulator, so combat, cooldowns and spawns
run twice as fast. Preparation countdown and `EnemySync` cadence divide the
step back by the speed: they stay in real seconds (2x never halves the time
to build or to pick a card, and never doubles network traffic).
`Match:_checkSkip()` ends preparation (down to 1 real second) once every
non-returned participant either voted `SkipWave` or has auto-skip on with no
card offer pending. Preferences persist as `settings.fastForward` and
`settings.autoSkip` (plain `Settings` action, allowed in a match) and seed
`p.speedVote`/`p.autoSkip` at `Start`. Snapshot `match` gains `speed`,
`speedVote`, `speedVotes`, `autoSkip`. The client's `SpeedToggle` (also key
F) and `AutoSkipToggle` sit in the ability band (`layout.controlW`).

## Lobby shop entry, audio and release — 22/09/2026

`Kind="HeroPedestal"` statues and the premium showcase no longer exist; the
hero collection lives only in the HUD (inventory/hero panels). Each chest
has a green entry zone in `world.shopZones[chestId]`; the bootstrap's
Heartbeat calls `World:StepShopEntries(visitors)` (lobby players with a
profile, not in a match, not travelling) every elevator tick. Stepping in
fires `openPanel(player, "chests", {chestId})` exactly once; the player must
leave the zone (1-stud tolerance) before it can fire again, and opening the
page never spends Gold — `OpenChest` still requires the explicit confirm.

`profile.settings.effects` (boolean) is new and independent of `music`;
older profiles inherit it from `music`. `Settings` accepts it.
`Config.Audio` gained `ability`, `boss`, `wave`, `chest`. Release places are
produced by `tools/release.py` from `deployment/local.json` (gitignored);
see `docs/DEPLOYMENT.md`.

Boss telegraph `Pulse` events may carry `followEnemyId` (the client keeps
the ring on that enemy), `warningText={pt,en}` and `requiresShield=true`
(hide the ring once that enemy's shield is gone). `EnemySync` positions are
now the route position; airborne height is added client-side, and `Shot`
endpoints use the same heights (air 8, boss 4.2, brute 2.9, else 2).

## Ultimates and daily rewards — 22/09/2026

Legendary/mythic abilities carry an optional `extras` list on the catalog
entry (`Catalog.Abilities[id].extras = {{kind, power?, duration?, radius?,
count?, unit?}, ...}`) and `ultimate = true`. `Rules.AbilityExtras(def, rank,
options)` turns each entry into a full `Rules.AbilityStats`-shaped table
(riding the primary effect's target/radius unless it names its own, scaled
by the same rank/ability-power/cooldown-reduction rules as the primary
effect); `Rules.AbilityText` fills `{e1.power}`, `{e1.duration}`,
`{e1.radius}`, `{e1.count}`, `{e2...}` placeholders in description text, in
list order. `MatchService:_castAbility` runs every extra through the same
`ABILITY_HANDLERS` table the primary effect uses, then reports the cast as
one `Ability` FX event with `ultimate = true` and `extras = {{kind, radius,
duration, power}, ...}`; the client's `Effects:_ultimateBurst` reads those
two fields to draw one light-pillar + three-shockwave burst plus one ring
per extra, in that extra's own tint, instead of the plain per-kind pulse.

Rewards (`Catalog.Rewards`, `Rules.RewardsStatus`/`Rules.LoginClaim`) are
four independent loops stored in `profile.rewards` (never sent to the
client raw — `PlayerService:Snapshot` computes and attaches
`result.rewards = Rules.RewardsStatus(profile, now, pendingSeconds)`, where
`pendingSeconds` is the time since the account's last committed
transaction, clamped to 12h per gap). New actions, all lobby-only, all
covered by `CHEST_ACTIONS` (so the two random rolls a chest may need are
drawn before the DataStore transaction like `OpenChest` already does):
`ClaimFreeChest {}`, `ClaimLogin {}`, `ClaimPlaytime {index}`,
`ClaimMilestone {index}`. Each returns the usual full snapshot with
`.result` attached (`{gold, xp, chest?, streak?, day?}` — `chest` has the
same shape `OpenChest`'s result does). The client reaches this panel through
`openContext("rewards", {})`, a fifth entry in the lobby's nav dock (not a
physical pedestal — a claimable count shows as a badge on that nav button,
computed client-side from `profile.rewards.claimable`).

**Party bonus.** `Catalog.PartyBonus.perPlayer = 0.1`; `Rules.PartyBonus(size)`
(1.0 solo … 1.3 for four) multiplies the lobby Gold banked per wave, the
victory Gold and the XP of everyone in the match (`MatchService:_endWave`,
`_checkpoint`, `Finish`); the multiplier travels in `results.party` and the
elevator card and end screen name it.

**Wave mutations.** `Catalog.Mutations` (rush, swarm, iron) and
`Rules.WaveMutation(modeId, mapId, wave, seed)`: about one wave in four, never in
training, before wave 6 or on a boss wave, decided by the match seed alone.
`Waves.Generate` applies the mutation (speed, health, head count, drop Gold);
`MatchService` announces it in the snapshot (`match.mutation`, the preview while
preparing, the current wave while it runs) and with a `Mutation` FX event.

**Map of the day.** `Catalog.DailyFeature.bonus = 0.25`; `Rules.FeaturedMap(day)`
cycles the campaign maps by Unix day and `Rules.FeaturedBonus` multiplies the
Gold and XP of a normal-mode match on that map (`MatchService.rewardBonus` =
party × featured; `Config.DailyFeature = false` switches it off, as the match
simulation does). The lobby snapshot carries `featured = {mapId, bonus, endsAt}`
for the ribbon on the play menu, the elevator card and `results.featured`.

**Season pass.** `Catalog.Season = { levels = 30, firstXp = 2000, stepXp = 200 }`
(level n costs `firstXp + stepXp * (n - 1)`, 147,000 XP in all); every
XP the account earns (match rewards, mission claims, reward-claim XP) also
feeds `profile.season = { id, xp, freeClaimed, premiumClaimed }`, which
resets when `PlayerService:_season()` changes (60-day seasons). The
snapshot carries `seasonStatus = Rules.SeasonStatus(season, owned)`
(`level`, `xpInto`, `claimable`, `upcoming` strip) — `profile.season` stays
the leaderboard season number. `ClaimSeason {}` (lobby only, in
`CHEST_ACTIONS`) pays every claimable level at once: the free track for
everyone, the premium track only with the `season` pass (a pass bought later
back-pays the levels already reached). Its `.result` is
`{gold, chests = {...}, titles = {...}, level, claimed}`; each chest is
opened from rolls derived from the three pre-drawn ones, so a replayed
transaction opens the same chests.

## Revisão de interface — 22/09/2026

`UI.contextLayout` calcula a área de todos os menus do lobby. Em telas baixas,
`slot.modal` oculta os cantos e a navegação enquanto o menu está aberto; o
elevador conserva uma área separada. `ResultReturn` fica fora de `ResultBody`.
`UI.icon` produz os símbolos com formas locais, sem IDs de assets externos.
Animações de abertura respeitam `settings.lowFX`; transições não alteram regras.

O botão JOGAR utiliza `StartMatch`, com os mesmos bloqueios de perfil e grupo.
O servidor sorteia o mapa em `startMatch`, incluindo chamadas pelo HUD;
o treinamento continua em Manhattan. Nenhuma decisão de custo, recompensa
ou combate passou ao cliente. `src/client/Review.luau` (só existe com `RunService:IsStudio()`) mostra
estados visuais simulados e intercepta as intenções de rede; a ação
`StudioReview` só é atendida no Studio. `tools/studio_review.py` dirige tudo
pela barra de comando sem editar nenhum script do lugar.

## Atualização de rotas e competição

`ranked` substitui `hard` nos catálogos, portais e partidas. `normal` não
redireciona para `tutorial`; o tutorial permanece explicitamente selecionável.
`Leaderboard` aceita apenas `modeId="ranked"` (competitivo sem fim, versão `comp2`); omissão lê o mesmo placar
`RecordBest` recebe o modo apenas no servidor;
no Ranqueado rejeita pontuações acima de 50. As chaves de Ranqueado têm prefixo
próprio e continuam separadas por mapa/equipe/temporada/versão. Não existe
remote para enviar pontuação. `Rules.RankForWaves` define os seis ranks.

`WorldBuilder` usa os pontos de `Catalog.Maps.paths` para gerar faixas
`MobTrail` e setas `TrailArrow`. O solo usa centro vertical -6 para que a
superfície voxelizada fique próxima de y=0, sem encobrir as ruas. As marcas
não têm colisão e não interferem no posicionamento de torres.

## Contratos atuais — recrutamento e líder

Esta seção substitui os contratos históricos de habilidades e compras abaixo.

- `OpenChest {chestId="rare"|"legendary"}`: debita Ouro e concede no servidor;
  `data.result` contém herói, raridade, duplicata e compensação. Chance real
  depende do catálogo, heróis possuídos e contador de garantia. Recibos e
  concessões são persistidos antes da confirmação. Restrição regional bloqueia
  abertura mesmo com saldo suficiente; cliente recebe `paidRandomRestricted`.
- `SetLoadout {heroes={id,...}}`: até cinco heróis diferentes e possuídos.
  Primeiro ID determina a ativa. `UpgradeAbility {heroId,expectedRank}` exige
  herói possuído, Ouro, maestria e rank esperado. `UpgradeTalent {talentId}` e
  `ResetTalents {}` administram a árvore de pontos da conta.
- `ProductInfo {kind="hero"|"pass"|"product",key}` retorna preço/ID da
  plataforma; sem configuração, nenhuma compra é oferecida.
- `CastSkill {skillId?,position?,towerId?}` só aceita a ativa do líder, com
  alvo e recarga validados. Snapshot `match.ability` fornece ID, herói, rank,
  alvo, raio, recarga restante/total. Não há `SetSkills` nem `BuySkill`.
- `ChooseCard {cardId}` aceita somente uma oferta do servidor no modo cartas.
  Snapshot: `cardOffers`, `cards`, `cardMode`. Não há `ChooseProtocol`.
- Elevadores usam os destinos de `Catalog.DestinationOrder` (campanha ×6, competitivo ×3, cartas, treino); `ElevatorMap` removido; `ElevatorStart` deixa o primeiro passageiro começar antes do fim da contagem.
  Mapa é sorteado no servidor ao partir, sem escolha pelo primeiro passageiro.
- FX: `Ability`, `CardPicked`, `EnemyDown`, além dos eventos existentes.
  Efeitos são locais; não calculam dano nem recompensa.
- IDs de moedas, torres e inimigos têm contadores separados: frequência de
  coleta e agrupamento visual não alteram identidades usadas pelo combate.

Execute `python tools/test.py` para compilar, testar e gerar os três lugares.


## Visual integration (2026-09-21)

WorldBuilder constructs `ReplicatedStorage/DoomHeroPortraits/<heroId>` from the
same `heroFigure` used in the world. Geometry is tagged `HeroVisual=true` and
`HeroGeometry=true`; `Suit` and `Mask` names stay stable. The client caches
geometry descriptors and renders them in ViewportFrames without scripts,
prompts, furniture or world billboards. Keep this library outside DoomLobby so
reserved match places retain portraits when the lobby is removed.

Lighting.Technology is protected by Roblox. Author Future (serialized enum 4)
in build.py and Rojo manifests; never assign it from WorldBuilder runtime code.
Actual Studio validation found this error despite mock-based tests passing.

Attack FX continue to use the existing Shot event and towerId. Effects resolves
the actual tower HeroId to choose an appearance; visual movement, pooling and
coin flights never grant damage or currency. Camera re-framing happens once
when entering lobby/battle; orbit and zoom remain Roblox's default controls.

The application uses `src/shared`, `src/server`, and `src/client`. Shared modules live in ReplicatedStorage/DoomShared; server modules in ServerScriptService/DoomServer; client entrypoint in StarterPlayerScripts/DoomClient. Runtime creates ReplicatedStorage/DoomRemotes with Request (RemoteFunction), State (RemoteEvent), and FX (RemoteEvent).

## Networking

Request:InvokeServer(action: string, payload: table?) always returns `{ok: boolean, message: string?, data: any?}`. Invalid input fails closed. State sends a complete per-player snapshot, at most twice per second in matches; Profile updates can be immediate. FX sends small ephemeral visual events: `Notice`, `OpenPanel`, `Clear`, `EnemySync`, `CoinSpawn`, `CoinRemove`, `Shot`, `Pulse` and `Breach`. Any event may also carry `shake` (0-1.5), which the client applies as camera movement unless the viewer turned that setting off. Client may call `Sync` to get the first snapshot as response.data.

`OpenPanel` carries `{panel, modeId?, heroId?, skillId?, shopKind?, shopKey?}`. `panel` names one of the client's contextual panel builders (`play`, `hero`, `skill`, `shop`, `quests`, `leaderboard`); the other fields identify which specific item within that panel to focus (which mode portal, which hero pedestal, and so on). The client only reacts to this event while `state.phase == "Lobby"`. The client resolves the matching lobby model itself and closes the panel once the player walks more than 26 studs from it, so a panel stays tied to the place that opened it.

`Shot` carries `towerId` so the client can play a firing recoil on that tower's `PowerRing`. `Pulse` accepts an optional `duration` (seconds, clamped to 0.1–6): short pulses expand and fade as an impact, while anything above one second is treated as a telegraph and holds at full radius for its whole life — that is how a boss marks the area of an incoming power during the two-second warning.

Snapshot: `{phase = "Lobby"|"Preparing"|"Wave"|"Results", role = "Lobby"|"Match"|"Standalone", profile = publicProfile, players = {{userId,name,level?,title?,vip?}}, party = {code, leaderId, members = {{userId,name}}, locked, maxSize}?, match = {runId,mapId,modeId,wave,totalWaves,completedWaves,baseHP,shield,energy,towerLimit,prepRemaining,enemies,elapsed,cooldowns = {[skillId]:seconds},protocolOffers={id},protocols={id},goldEarned,xpEarned,partySize,skipVotes,threats={enemyId}?,towers={{id,heroId,ownerId,level,branch,position=Vector3,priority,damage,range,rate,upgradeCost,invested}}, boss={id,name,hp,maxHP,phase,hint}?}, results = {victory,waves,gold,xp,mapId,modeId}?, notice?}`.

Public profile: `{gold,xp,level,heroes = {[id]:{xp,level}},loadout={heroId},skills = {[id]:rank},activeSkills={id},passives={id},campaign = {[mapId]:{normal=true?,hard=true?}},tutorialComplete,passes = {[id]:bool},settings={language="pt"|"en",lowFX:boolean,shake:boolean,music:boolean},quests={},achievements={},best={},title,titles = {[id]:{pt,en}}}`.

## Action names

Lobby: StartMatch `{mapId,modeId}`; CreateParty `{}`; JoinParty `{code}`; LeaveParty `{}`; BuyHero `{heroId}`; SetLoadout `{heroes={id}}`; BuySkill `{skillId}`; SetSkills `{active={id},passive={id}}`; Settings `{language,lowFX,shake,music}`; SetTitle `{titleId}`; ClaimQuest `{questId}`; Leaderboard `{mapId,size}`; ReturnLobby `{}`; Sync `{}`. Shop: ProductInfo `{kind="pass"|"product",key}` returns `{id,price,name}` or disabled error. Client prompts purchase with returned ID. Match: PlaceTower `{heroId,position=Vector3}`; UpgradeTower `{towerId,branch?}`; SellTower `{towerId}`; SetPriority `{towerId,priority="First"|"Last"|"Strongest"|"Nearest"}` (exactly these capitalized values, which are also what tower snapshots carry; `tests/test_contract.py` fails if the client cycles anything else); CastSkill `{skillId,towerId?,position?}`; CollectCoin `{coinId}`; SkipWave `{}`; ChooseProtocol `{protocolId}`. Training: StartTraining `{}` boards the commander on a free training queue and starts it at once (lobby only; refused inside a match). Results: PlayAgain `{}` — a vote from everyone still on the results screen; when all voted, the same map and mode restart in this server for exactly them (refused in training and while rewards are still saving).

## Shared Catalog contract

Catalog.Heroes dictionary indexed by ironman, hawkeye, spiderman, widow, captain, hulk, panther, thor, antman, vision, wanda, strange. Hero fields: id,name={pt,en},description={pt,en},price,cost,damage,range,interval,color={r,g,b},attack="single"|"splash"|"chain"|"beam"|"dot",damageType="physical"|"tech"|"magic",air:boolean,reveal:boolean?,splash:number?,chain:number?,slow:number?,support:boolean?,branches={{name={pt,en},description={pt,en}},{...}}. HeroOrder array. Maps dictionary manhattan,gamma,hydra,wakanda,latveria fields id,name={pt,en},chapter,bossId,color={r,g,b},paths={{{x,z},...}},description={pt,en}. MapOrder. Enemies dictionary zombie,runner,brute,armored,stealth,flyer,support,summoner,lizard,abomination,redskull,killmonger,doom with id,name={pt,en},hp,speed,leak,reward,armor,air,stealth,boss,color={r,g,b}. Modes dictionary tutorial,normal,hard,infinite,daily,bossrush fields id,name={pt,en},waves (0=infinite),hpMultiplier,rewardMultiplier. Skills dictionary overload,scan,barrier,stasis,magnet,haste,precision,reach,logistics,bossHunter with id,name={pt,en},description={pt,en},kind="active"|"passive",price,maxRank=3,unlockLevel,cooldown?; SkillOrder. Protocols dictionary supportRange,armorBreaker,recharge,wideArea,energy with name/description localized. Products={Passes={collector={id=0,price=149,name={pt,en}},training,formations,vip},Consumables={gold1000={id=0,price=79,gold=1000,name={pt,en}},gold5000,gold12000}}. Config is separate and owns IDs/environment.

## Server PlayerService contract

Module returns class with `.new(config, catalog, onChanged)`; `:Load(player)->profile?,error?`; `:Get(player)->profile?`; `:Snapshot(player)->publicProfile?`; `:Handle(player,action,payload,inLobby)->handled,ok,dataOrMessage`; `:Award(player,awardId,reward)->ok,error?` reward={gold,xp,mastery={[heroId]=xp},mapId?,modeId?,victory?,tutorial?,waves?,bosses?,noDamage?,finished?}; `:RecordBest(player,mapId,size,waves)->ok`; `:Leaderboard(mapId,size)->rows`; `:Save(player)->ok`; `:Release(player)`; `:Shutdown()`. It owns MarketplaceService.ProcessReceipt and validates pass entitlements. All durable mutations must be serialized and idempotent. `onChanged(player)` asks root to send new snapshot.

## Server bootstrap contract

`src/server/init.server.luau` creates ReplicatedStorage/DoomRemotes (reusing any
node the place already carries), registers the `Commanders` collision group, then
constructs PlayerService, WorldBuilder, MatchService and PartyService in that
order and wires every `onChanged` callback to a per-player snapshot push.

Place role comes from `workspace:GetAttribute("DoomRole")`. The role collapses to
`Standalone` whenever `Config.LobbyPlaceId` or `Config.MatchPlaceId` is zero or
the server is a Studio playtest, because teleport cannot succeed there and a
half-configured universe must never strand a player.

Routing order for `Request`: `Sync`, then match actions when the caller is a live
participant, then `PlayerService:Handle`, then party and travel actions. Unknown
actions and match actions sent from the lobby are refused without side effects. A
token bucket of 40 with 22/s refill rate-limits every caller.

The router wraps every request in `pcall` and answers a failure with a generic
"internal error", which keeps a bad request from crashing the server but also
hides it. `tests/server_boot.spec.luau` therefore executes this bootstrap for
real — Standalone role, Studio memory profiles, a simulated clock and a
cooperative scheduler — plays full sessions through `Request.OnServerInvoke`,
and fails on any `[Doomsday] Request ... failed` warning. A test double for any
service the bootstrap uses must keep that harness running.

`Lobby` role answers `StartMatch` by validating `Rules.CanStart` for each member,
reserving a server for `MatchPlaceId` and teleporting the party with
`{mapId, modeId, runId, size, leaderId, members, balanceVersion}`. `Match` role
reads that payload from `player:GetJoinData().TeleportData`, waits until everyone
announced has arrived or 25 seconds pass, and starts with the players actually
present, so difficulty never counts someone who never made it. `Standalone` runs
the match in place. Match servers send players back to `LobbyPlaceId` after
`ReturnLobby`, after a failed start, and when someone arrives with no payload.

Simulation runs on a fixed `Config.SimulationStep` accumulator, capped at six
ticks per frame. Snapshots go out every `Config.SnapshotInterval` to players in a
match and every fourth interval to everyone else; `CollectCoin` is answered by FX
alone and never broadcasts. `BindToClose` finishes an open match, drains the
reward queue for up to 5s, then calls `PlayerService:Shutdown`.

## Lobby world contract

The lobby has no full-screen tabbed menu. Every function lives at a physical
location built by `WorldBuilder:BuildLobby`, and each location is its own
`Model` directly under `workspace.DoomLobby`, tagged with a `Kind` attribute
so the client can find it without name-matching:

- `Kind="ModePortal"`, `ModeId=<mode>` — one portal per non-tutorial mode
  (`normal`, `hard`, `infinite`, `daily`, `bossrush`), colored per mode. A
  portal is an **elevator**, not a prompt (see "Mode portals" below). Its
  `Sign` part carries a `SurfaceGui` named `Board` whose TextLabel each client
  rewrites for its own viewer (next sector, waves, or what is missing).
- `Kind="HeroPedestal"`, `HeroId=<hero>` — one statue per hero, built with the
  same `heroFigure` silhouette used by match towers.
- `Kind="SkillPedestal"`, `SkillId=<skill>` — one training console per skill.
- `Kind="ShopStand"`, `ShopKind="pass"|"product"`, `ShopKey=<key>` — one stand
  per Game Pass plus one combined vault for every Gold-pack tier
  (`ShopKey="gold"`).
- `Kind="Board"`, `BoardId="quests"|"leaderboard"` — signage flanking the
  bridge; the leaderboard totem also carries a `SurfaceGui` TextLabel that
  `World:UpdateLeaderboardBoard(rows, mapName)` refreshes on a server timer
  (see the bootstrap's `role ~= "Match"` loop), since that board is shared,
  public scenery rather than personal state.

A `ProximityPrompt` on each model's `PrimaryPart` calls the same `openPanel`
callback `WorldBuilder.new` was constructed with; the bootstrap turns that
into the `OpenPanel` FX event described above. Locked or not-yet-owned state
is never baked into the shared geometry (it is personal, and the lobby model
is shared by everyone in it): the client applies a translucent `LockShroud`
part and a `LockHint` billboard locally, per viewer, in
`updateWorldCosmetics()`, and removes them (with a brief reveal flash) the
moment that viewer's own profile clears the requirement. Equipped heroes and
skills get a local `Highlight` the same way. None of this cosmetic gating is
authoritative — `Rules.ModeUnlocked` and `Rules.CanStart` are what the client
reads to decide what to dim, but `MatchService`/`PlayerService` independently
re-validate every action server-side regardless of what the client displayed.

## Mode portals (ElevatorService)

Starting a match has no menu. `WorldBuilder:BuildLobby` publishes
`world.portalZones[modeId] = { center, size, exit }` and
`src/server/ElevatorService.luau` (stepped from the bootstrap's Heartbeat every
0.25 s, lobby roles only) watches who stands in each zone:

- stepping in boards that portal's car; the first rider is the host and the
  plan follows their profile: `Rules.PortalMode` (the campaign portal runs
  `tutorial` until training is done), `Rules.PortalMaps`/`Rules.PortalMap`
  (next unbeaten campaign sector, today's daily sector, …);
- a locked portal, a full car (4) or a car whose plan the joiner cannot play
  refuses them: they are set down at `exit` and told why
  (`Rules.ModeLockReason(modeId, profile)`), and are not re-boarded until they
  have stepped away;
- the countdown is 8 s, and anyone boarding always gets at least 5 s;
- at zero every rider is re-checked with `Rules.CanStart`; the launch is
  `sendToMatch` in a Lobby server and `match:Start` elsewhere. A failed launch
  keeps the car and restarts the countdown.

Actions: `ElevatorLeave` `{}` → `{ok}` (also ejects to `exit`), and
`ElevatorMap` `{step = 1|-1}` → `{ok, message}` (host only; cycles the sector),
and `SetDifficulty` `{difficultyId}` → `{ok, message}` (host only; refused
unless every rider has opened it on that map, `Rules.CanUseDifficulty`). The
car's difficulty travels in the teleport data and into `match:Start`; it
scales the waves (`Waves.Generate`) and the victory Gold/XP, and a win records
`campaign[mapId][winKey]`, which opens the next one.
Snapshots carry `elevator = {portalId, modeId, mapId, difficultyId, riders = {{userId, name}},
max, remaining, host, maps}` while the player rides, `nil` otherwise. The
legacy `StartMatch`/party actions are still routed but no client UI sends them.
Covered by `tests/elevator.spec.luau` (unit) and `tests/server_boot.spec.luau`
(walking into portals through the real bootstrap).

## Match city contract

`World:Build(mapId)` dresses every map as a place (`World:DressMap`):
chapter terrain (`workspace.Terrain`, only inside ±176 studs), streets built
from the catalog routes (asphalt, sidewalks, curbs clipped at every junction by
`World.CurbRuns`, dashed centre line, manholes), an exit street past each
enemy gate, a boulevard all round at ±110, flat "blocks" on open ground
(plazas, parking, courts, helipads, lawns — nothing taller than 0.5 studs), a
continuous wall of themed buildings at ±118, props on the boulevard, and
sidewalk furniture in `DoomWorld.Clutter`. Rules the tests enforce:

- nothing standing taller than 0.5 studs covers a spot where a tower may be
  built (`World.CoversBuildArea` mirrors `MatchService:_validBuild`);
- `World:MakeTower` clears clutter under the new platform (`World:ClearClutter`);
- budgets per map: ≤ 3200 parts, 8–32 lights, ≤ 4 `Fire`; scenery has
  `CanQuery = false`; invisible `CityLimit` walls at ±116 keep players inside;
- `BuildGround` is invisible and non-colliding: it only serves the placement
  raycast.

`python tools/render_preview.py [--map <id>|--map lobby]` renders a plan and
two perspective PNGs of the real generated geometry (flat-shaded; composition
only — Studio remains the visual acceptance gate).

## Client layout contract

Every HUD rect is computed in pixels by a pure function in `UI.luau` —
`UI.lobbyLayout`, `UI.matchLayout`, `UI.protocolLayout`, `UI.topBarLayout` —
from the **usable** screen, which the client reads as its root frame's
`AbsoluteSize` (viewport minus Roblox's topbar and the device safe area).
`UI.sizeClass` names the three cases: `short` (under 520px tall: a phone in
landscape, which is how Roblox runs phones by default), `narrow` (under 560px
wide: portrait, only if the experience opts in) and `compact` (either, or
under 820px wide). On short screens the right edge becomes a column shared by
the tower panel and the placement bar, abilities move into the hero-card band,
and the tower panel switches to its two-row `wide` arrangement.

Renderers must take positions from these functions and never mix scale-based
positions with fixed-width siblings again. The client re-lays out whenever the
usable size changes (keyed by the exact size, debounced). `tests/ui_layout`
checks the geometry on 22 real screens; `tests/client_boot` executes the real
client against Roblox stand-ins and asserts that what it rendered sits where
the layout functions say.

## Tower visual contract

`World:MakeTower` builds a hero from the shared `heroFigure` silhouette and
gives the tower's `PowerRing` a `BaseSize` attribute. `World:UpgradeTower`
republishes `BaseSize` whenever it widens the ring, and is also what makes an
upgrade visible: the ring widens, rank markers accumulate, and at level five
the chosen branch tints the ring (warm for branch one, cool for branch two)
and adds a `BranchEmblem`, so the two final specializations never look alike.
The client's firing recoil animates that ring and restores it to whatever
`BaseSize` says at the moment the animation ends — never to a value captured
when it started, or an upgrade landing mid-recoil would be undone.

## WorldBuilder lighting contract

`World:Build(mapId)` applies that chapter's lighting mood (ClockTime, Ambient,
Atmosphere, Bloom, ColorCorrection, Fog) in addition to building the map's
geometry; `DepthOfField` is always forced off there, since blurring any part
of an 80-enemy battlefield would fight legibility. `World:ApplyLobbyLighting()`
puts the lobby's own mood back (including a soft DepthOfField, which is only
safe where there is no battlefield to read) and **must** be called by
`MatchService:Finish` before a match's Results phase, because a Standalone
server keeps the lobby and the match map in the same Workspace and shares one
Lighting service between them — nothing else reverts it. Any test double for
`world` needs `Build`, `MovePlayer` and `ApplyLobbyLighting` at minimum.

## Server MatchService additions

`:Roster()->{{userId,name}}` lists live participants. `:Index(player)->number`
gives the spawn slot. `:Drain(seconds)->boolean` flushes queued checkpoints.
`self.seed` is fixed at `Start` so a run crossing the UTC day boundary keeps its
wave composition and daily modifier. `_previewThreats` fills `self.nextThreats`
at `Start` and after each wave, and the snapshot exposes it as `threats` while
the phase is `Preparing`.

## Server PartyService contract

Module returns class with `.new(config, onChanged)`; `:Create(player)->ok,error?`;
`:Join(player, code)->ok,error?`; `:Leave(player)`; `:Remove(player)`;
`:Get(player)->party?`; `:IsLeader(player)->boolean` (true when unpartied);
`:Members(player)->{Player}` leader first, connected only, capped at
`Config.MaxPartySize`; `:SetLocked(player, locked)`; `:Disband(player)`;
`:Snapshot(player)->party?`. Codes are four characters from an alphabet without
ambiguous glyphs, unique per server and destroyed with the party, so a code can
never pull a stranger into an existing reserved match.

## Server PresenceService contract

`.new()`; `:Bind(player)` starts tracking and follows respawns; `:Update(player, vip)`
adds or removes the VIP trail; `:Release(player)`. The trail is built on the
server so every client renders it, unlike the collector drone, which is a local
effect for its owner. Titles are not built here: they ride in the snapshot
roster so each viewer reads them in their own language.

## Server AnalyticsService contract

`.new(enabled)` (Studio is always skipped); `:Custom(player, name, value, a, b, c)`;
`:Economy(player, isSource, amount, endingBalance, transaction, sku?)`;
`:TutorialStep(player, step, name)`; `:Progression(player, mapId, modeId, status, wave)`;
`:MatchFinished(player, mapId, modeId, victory, waves, seconds, gold)`;
`:Composition(player, loadout, mapId?)`; `:HeroUnlocked(player, heroId, level, minutes)`;
`:Fault(player, area, detail)`; `:Report()`. Every call is wrapped and the whole
service disables itself after one failure: telemetry must never fail a match.

Gold is logged from exactly one place, `refreshPresence` in the bootstrap, which
runs after a profile commits and therefore sees both the real delta and the real
ending balance. The router sets `goldHint` before an action known to move gold so
the transaction can be named rather than guessed; nothing else calls `:Economy`,
so no path can count the same gold twice.

## Server RejoinService contract

`.new(enabled, matchPlaceId)`; `:Remember(userIds, accessCode, runId)` called by
the lobby right after a successful teleport; `:Lookup(userId)->seat?`;
`:Hold(userId, seconds)` shortens a seat to the reconnect window when a
participant drops; `:Extend(userId)` restores it when they return; `:Forget(userId)`.
Backed by a MemoryStore hash map, which needs a published universe, so the whole
service disables itself in Studio and reconnection falls back to single-server
behaviour. The reserved access code is never placed in teleport data, because the
travelling client can read it.

## Ownership

Root owns Config, bootstrap, MatchService, WorldBuilder, PartyService, integration and documentation; all of these now exist. Persistence agent owns PlayerService and persistence-specific tests. UI agent owns client files. Catalog/build agent owns Catalog, pure shared Rules/Waves modules, tools/build.py and tools/test files. Avoid modifying another agent's files; message contracts changes first.


## Etapa 1 do plano de produção (2026-09-26): mudanças de contrato

**Moeda da partida.** `Energia` não existe mais. O snapshot da partida troca
`energy` por `cash` (Ouro da partida na carteira) e acrescenta `coinsWaiting`
(Ouro no chão ainda não coletado), `magnet` (alcance do ímã em studs),
`blockers` (`{x,z,r}` do núcleo e das bases, usados pela prévia de construção),
`endVote`/`endVotes` (voto de encerrar no competitivo). `goldEarned` continua
sendo o Ouro **do lobby** guardado pela partida.

**Ações novas.** `VoteEnd {on}` (partida, competitivo, entre ondas; unânime
encerra com `results.ended = true`), `ElevatorStart {}` (lobby, só o primeiro
passageiro), `BuyGuaranteed {itemId}` (lobby, só contas com itens aleatórios
pagos restritos; preço `Rules.GuaranteedPrice`), `LeaveAfk {}` (lobby, tira o
jogador da sala AFK).

**FX novo.** `WaveCash {amount}`: bônus de Ouro da partida ao fim da onda.
`CoinRemove` passa a trazer `value`. `BossArrive {enemyId, final, position}`:
entrada de um chefe (faixa com nome e som). `TowerUpgrade {towerId, level, branch}`:
toda melhoria de torre, para a animação (pulo e coluna dourada).
`TowersStunned {towerIds, duration}`: torres interrompidas por um poder de
chefe (estrelas e postura caída). Cada torre do snapshot traz `stunned`
(segundos restantes) enquanto estiver interrompida.
`EnemySync` traz por inimigo `lk` (id do suporte que o acelera, se houver) e,
nos invocadores, `ch` (invocações restantes, 0–2). Os bits de `st` ganham
`128` (camuflado revelado) e `256` (acelerado por suporte). `Shot` traz
`armored = true` quando o alvo tem armadura de 25% ou mais (faíscas). Uma
invocação é anunciada 1,5 s antes com um `Pulse` que segue o invocador.
`CoinRemove` pode trazer `to` (Vector3): a moeda foi recolhida por uma torre
coletora (`hero.pickup`) ou por uma habilidade de área, e voa até esse ponto.

**Construção.** Prévia e servidor chamam `Rules.BuildCheck(mapId, position,
towers, config, blockers)`; recusas usam `Rules.BuildReasons` (`bounds`,
`path`, `occupied`, `cash`, `limit`).

**AFK.** O servidor publica atributos no jogador: `AfkZone`, `AfkNext`,
`AfkSession`, `AfkEarned`, `AfkSaving`. Cada minuto é pago por
`PlayerService:GrantAfk(player, kind, 1, paymentId)` com id próprio.

**Títulos cosméticos.** `PlayerService:GrantCosmetic(player, featId)` (hoje
só `parkour`), chamado pelo servidor; não existe ação de cliente.

## Final art contract

Modelos definitivos feitos no Studio entram por `assets/models` (ver
[assets/models/README.md](assets/models/README.md)). `tools/build.py` embute
cada `.rbxmx` listado em `assets/models/manifest.json` em
`ReplicatedStorage.DoomArt.Heroes|Enemies/<id>`, prefixando os `referent` e
fundindo `SharedStrings`. Recusa arquivo sem autor/permissão, fora do
manifesto ou com scripts. Em jogo, `WorldBuilder.heroFigure` usa
`DoomArt.Heroes[heroId]` quando existe (torres, retratos, Campo de Treino) e
`Effects` usa `DoomArt.Enemies[enemyId]` (ou o da família). O tiro sai do
`Attachment` `Muzzle`; animações opcionais vêm de atributos numéricos do Model
(`IdleAnimation`, `AttackAnimation`, `AbilityAnimation`, `UpgradeAnimation`,
`WalkAnimation`). Arte nunca altera alcance, colisão ou regras.

