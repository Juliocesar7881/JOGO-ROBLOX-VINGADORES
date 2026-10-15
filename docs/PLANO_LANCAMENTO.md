# Plano final de lançamento — Multiverse Doomsday Tower Defense

## Contexto

O dono quer lançar o jogo para ganhar dinheiro e pediu uma análise do que falta
para ele ficar completo, divertido e reter crianças (modelos, texturas, lobby,
compráveis), com um plano final de lançamento. A auditoria de 14/10 (código no
`main`, commit `59ccba9`; place oficial 97132875544830) mostrou:

- **Monetização já cadastrada:** 51 produtos com IDs reais em `src/shared/Config.luau`
  (41 heróis 9/29/79 Robux, 5 passes 19–49, 4 pacotes de Ouro 5–79, Pacote
  Inicial 19), recibos atômicos, preço regional. Nunca houve compra real de teste.
- **Quatro bugs de jogo** que tiram sensação de progresso e podem gerar
  reembolso: velocidade de Pesadelo/Corrida nunca é aplicada; bônus de
  recompensa de Competitivo/Cartas/Difícil não valem nas ondas; conquista
  "Destemido" impossível; progressão de cartas sem teto fura o limite de 15%.
- **Um servidor = uma batalha.** `LobbyPlaceId/MatchPlaceId = 0`: quem entra
  enquanto um grupo joga recebe "já existe uma batalha". Isso mata retenção e
  receita com mais de 4 jogadores por servidor.
- **Retenção rasa para o público-alvo:** sem troca, sem skins, sem evento
  limitado, sem loja rotativa, passe de temporada só com Ouro/baús, VIP sem
  conteúdo exclusivo visível.
- **Visual:** tudo é peça do Roblox (sem malha, textura, decal, skybox ou
  animação publicada); acabamento de heróis avaliado 3/5; lobby a 31 peças
  do teto (4.519/4.550).
- **Analytics não mede compras** (nenhum evento de loja/compra).

Decisões do dono (14/10): arte só por script (sem malhas pagas); troca em
versão segura; separar lugares antes de lançar; sem grupo do Roblox.

Regras inegociáveis continuam valendo: servidor decide tudo, nada da Toolbox,
nada de nomes/marcas de terceiros (`tests/ip_blocklist.json`), sem emoji,
Bloom ≤ 0,2, sem mascote, `python tools/test.py` verde antes de cada commit,
trabalho direto no `main` e no place da equipe.

---

## Diagnóstico (régua `.claude/skills/roblox-td-director/references/RUBRIC.md`)

| Eixo | Nota | Por quê |
|---|---|---|
| Leitura no celular | 4 | varreduras sem corte; falta aparelho real |
| Uau | 3 | golpes sem peso, sem evento de "jackpot", evolução sem visual próprio |
| Acabamento | 3 | rostos geométricos, sem textura, skybox padrão |
| Consistência | 4 | pele de janela única |
| Clareza do objetivo | 4 | `nextGoal` + setas |
| Combate | 3 | bugs de velocidade/recompensa, dano crítico sem destaque |
| Recompensa | 3 | loops curtos existem; sem evento, sem loja rotativa, passe raso |
| Desempenho | 4 | 60 FPS no PC; celular não medido |
| Marca segura | 2 | homenagens próximas + "Capitão Men" (decisão do dono) |
| Perto do TTD | 2 | sem troca, sem escassez, uma batalha por servidor |

Pior eixo técnico: **Perto do TTD / Recompensa** (retenção). Pior eixo de
negócio: **Marca** (risco de derrubada depois de viralizar).

---

## Fase 0 — Corrigir o que engana o jogador (1–2 dias)

Tudo em `src/server/MatchService.luau` / `src/shared/Rules.luau` com teste
em `tools/test_rules.luau` ou `tests/match_simulation.spec.luau`.

1. **Velocidade de inimigo:** aplicar o multiplicador de `src/shared/Waves.luau:60`
   (Pesadelo 1,1×, mutação Corrida 1,3×) no spawn (`MatchService.luau:331-356`)
   e no movimento (`:959`). Aceite: simulação mostra tempo de travessia menor.
2. **Bônus de recompensa por modo/dificuldade:** aplicar `rewardMultiplier`
   (Competitivo 1,5×, Cartas 1,25×, Difícil 1,5×, Pesadelo 2×) no Ouro e XP
   **por onda**, não só no bônus de vitória (`MatchService.luau:1079`,
   `Rules.RunGold`). Rebalancear depois com `python tests/test_match_simulation.py --sweep rosters`.
3. **Conquista "Destemido" (`hardWin`)** virar "sobreviver a 30 ondas no
   Competitivo" (`PlayerService.luau:1140-1143`).
4. **Teto de progressão:** estrelas + cartas entram no limite permanente
   (`Rules.luau:445-447`) ou o limite sobe de forma declarada (ex.: 15% base
   + até 25% de cartas). Documentar em `docs/BALANCE.md`.
5. **Baús da temporada premium em região restrita:** `ClaimSeason`
   (`PlayerService.luau:969-974`) converte o baú em Ouro quando
   `randomRestricted`. Teste em `tests/player_service.spec.luau`.
6. **Lista `_receipts` sem poda:** manter só os últimos 200.
7. **Nova trilha de batalha:** gerar variação com `tools/generate_audio.py`,
   atualizar `assets/audio/manifest.json`; o **dono** reenvia (declaração de
   autoria) e põe o ID em `Config.Audio.battle`.

## Fase 1 — Lugares separados e capacidade (2–3 dias; parte é do dono)

Código já existe (`tools/build.py`, `docs/DEPLOYMENT.md`, `RejoinService`,
`ElevatorService` teleporte). Falta:

1. **Dono:** publicar no mesmo universo os lugares `Doomsday-Match` (e `Afk`,
   opcional) a partir de `dist/`, copiar `deployment/template.json` para
   `deployment/local.json` **com os IDs reais atuais** (não zeros) e rodar
   `python tools/release.py --config deployment/local.json --check`.
2. **Corrigir `tools/release.py:97-107`:** nunca sobrescrever um ID real do
   `Config` com 0 vindo do JSON (mesma regra já usada para `MapImages`).
   Teste em `tests/test_release.py`.
3. Lobby com N batalhas simultâneas via servidores reservados; conferir
   teleporte com 1 e 4 jogadores e reconexão (`RejoinService`), item do
   `docs/RELEASE_CHECKLIST.md`.
4. **Servidor de match com 4 vagas, lobby com 20–30** (Config do lugar). Fila
   de portal continua decidindo o grupo.

## Fase 2 — Monetização pronta para dar dinheiro (3–5 dias)

Princípio: tudo comprável tem que ser **visto** e **desejado** no fluxo
normal, sem bloquear quem não paga (política do Roblox para crianças e boa
retenção).

1. **Funil de compra no Analytics** (`src/server/AnalyticsService.luau` +
   chamadas em `init.server.luau`/`PlayerService.luau`): `ShopOpened`
   (categoria), `ItemViewed`, `PromptShown`, `PurchaseCompleted/Cancelled`
   com SKU; `IAP` só por recibo real (hoje é adivinhado). Sem isso não dá para
   otimizar preço nem saber o que vende.
2. **Pacote Inicial em destaque com tempo:** banner no lobby nos primeiros 3
   dias da conta (contador real pelo `createdAt` do perfil, servidor decide se
   ainda vale; depois some). Só visual: preço e entrega já existem.
3. **Ofertas que a criança entende (dados em `Catalog.Products`, sem código
   novo além de um tipo `bundle`):**
   - "Pacote Lendário": 1 herói lendário à escolha + 12.000 Ouro.
   - "Pacote Equipe": 3 heróis raros à escolha.
   - Entrega pelo mesmo `_receipt` (grant hero + gold); recibo único.
   **Dono** cadastra os produtos no Creator Hub e põe IDs no `Config`.
4. **Passe de temporada por temporada:** hoje é game pass permanente
   (`passes.season`). Trocar por **Developer Product** por temporada
   (`Products.SeasonPass[seasonId]`), gravando `profile.season.premiumId`;
   a cada 60 dias o dono cria um produto novo (documentar em
   `docs/director/ROBUX_CATALOG.md`). Manter o pass antigo válido para quem
   comprou (temporada 1).
5. **Passe com conteúdo exclusivo visível:** no nível 30 da trilha premium um
   **herói brilhante exclusivo da temporada** (variante `shiny` com cor
   própria em `HERO_LOOK`) e um título; mostrar o prêmio final no cartão da
   temporada e no resultado. Dados em `Catalog.Season`.
6. **VIP valer a pena:** além de título/rastro, +1 baú grátis por dia (6 h → 3 h
   de recarga em `Rules.RewardsStatus`) e a cor dourada do nome. Mostrar na
   loja o que o VIP dá, com ícones.
7. **Boost comprável de 2× Ouro por 1 h** (Developer Product; `profile.boostUntil`
   decidido no servidor; `RunGold` aplica). Visível na barra do topo com
   contador.
8. **Ouro de dinheiro vs Ouro de jogo:** manter como está (baús só com Ouro,
   compra direta de herói com Robux), que passa na regra de itens aleatórios.
9. **Loja Robux dentro do fluxo:** botão "Loja" do dock já abre; adicionar
   atalho "Comprar Ouro" quando o jogador tenta abrir baú sem Ouro suficiente
   (`Panels.luau` chests → `openContext("premium",{category="gold"})`).
10. **Ícones dos produtos** (Creator Hub): o dono envia as imagens que já estão
    em `assets/ui/illustrated` (chest/hero atlas recortado por
    `tools/prepare_ui_art.py`) — item M34.6, Studio precisa recuperar acesso.

## Fase 3 — Retenção para crianças (1–2 semanas)

Ordem por impacto/custo. Cada item: dado no `Catalog`, regra no `Rules`,
decisão no servidor, teste novo.

1. **Troca segura entre amigos (pedido do dono):**
   - Só entre jogadores no mesmo servidor que são amigos no Roblox
     (`player:IsFriendsWith`), 1 herói por 1 herói (nunca Ouro/Robux), raridade
     igual ou o servidor mostra aviso "troca desigual" e exige segunda
     confirmação; 5 s de "trava" após a última mudança; heróis iniciais e
     equipe atual não trocáveis; limite de 10 trocas/dia; registro em
     `profile._trades` (reversível por suporte).
   - Novo painel `trade` em `Panels.luau`; ações `TradeOffer/TradeSet/TradeConfirm/TradeCancel`
     em `PlayerService` (transação dupla sob `_withLock` dos dois userIds).
   - Testes: `tests/player_service.spec.luau` (replay, saída no meio, troca
     desigual, limite) e `client_boot`.
2. **Loja rotativa de heróis (escassez do TTD sem Robux):** 3 heróis por dia
   compráveis com Ouro (preço por raridade em `Catalog.RotatingShop`), seed
   do dia no servidor, contador de "renova em" e "estoque 1". Painel no
   balcão "Mercado" já existente.
3. **Evento de fim de semana** (dados em `Catalog.Events`): sábado/domingo um
   mapa com mutação fixa, 2× Ouro e um **herói de evento** só obtível no
   baú do evento (Ouro). Banner no lobby com contador; servidor decide
   pelo relógio UTC. Repetir mensalmente com tema das temporadas que já
   existem (`SeasonThemes`).
4. **Sequência longa de login:** estender o ciclo de 7 para 28 dias com prêmio
   grande no dia 28 (herói lendário garantido). `Catalog.Rewards.login`.
5. **Skins por script:** variante de cor por herói (`HERO_LOOK` com paleta
   alternativa), ganha no nível 20 de maestria ("Despertar") e no passe.
   O "shiny" passa a aparecer no modelo da torre (hoje só mostra ◆ no menu:
   ligar em `WorldBuilder.luau:7777`).
6. **Presente entre amigos:** 1 baú de Suprimentos por dia enviável a um amigo
   (servidor paga do nada, limita 1/dia; cria motivo para voltar em dupla).
7. **Modo rápido de 10 ondas (5 min)** para sessões curtas no celular:
   `Catalog.Modes.quick`, recompensa proporcional. Primeiro portal visível.
8. **Códigos como marketing:** manter 3 códigos e adicionar um por vídeo de
   divulgação (`src/server/Codes.luau`); painel "Códigos" no dock de
   Prêmios.
9. **Emote/comemoração de vitória** própria (pose procedural em `Motion.Perform`)
   para todos, e uma exclusiva do VIP.

## Fase 4 — Visual por script (contínuo, 1 semana de foco)

Sem malhas pagas; imagens feitas pelo dono/IA entram só como ID em `Config`.

1. **Rostos por imagem:** `Figure.Face` (`WorldBuilder.luau:414`) recebe
   `Decal` com 6–8 rostos próprios (feliz, sério, máscara, visor…), ID em
   `Config.UiArt.faces`. Maior ganho de acabamento por custo.
2. **Skybox próprio** por mapa e lobby: `Sky` em `applyMapLighting`
   (`:3317`) e `ApplyLobbyLighting` (`:4102`), 6 imagens por céu feitas por
   IA (dia, tóxico, forja, savana, neve, dourado). Zero peças.
3. **Materiais pintados:** 3–4 `MaterialVariant` (asfalto, tijolo, metal
   riscado, mármore) criados em `tools/build.py build_tree`, aplicados em
   `STREET_THEME` (`:6368`) e no kit do lobby; texturas 512 px feitas por IA
   com licença própria.
4. **Partículas com textura própria:** `emitter()` (`:103`) e `Beam` nos
   lasers (`Effects:_laser`), dentro do teto de 80 efeitos.
5. **Lobby:** trocar 100–150 peças de decoração distante (horizonte de 16
   torres por 6 torres maiores com janelas em textura) para abrir orçamento;
   usar o espaço para 1 marco por área (fonte da praça animada, sala de
   troféus com as estátuas dos 3 melhores do placar).
6. **Peso de combate:** número de dano crítico com "pop" de escala e cor,
   tremor leve em golpes pesados, flash de abate em chefe (dentro de
   `lowFX`); pips do cartão animando na evolução.
7. **Silhuetas de chefes (M17.2/M36.4):** vitrine em 3/4 e reforço de
   quem parecer infectado comum.

## Fase 5 — Lançamento (checklist do dono + 2 semanas de medição)

**Só o dono (ordem):**
1. Verificação de identidade + 2FA (libera alcance abaixo de 16 anos). Sem
   isso o jogo não chega às crianças.
2. Decisão de marca: renomear "Capitão Men" e afastar os 2–3 visuais mais
   próximos dos originais (lista em `docs/director/AUDIT.md`). Trocar nomes em
   `Catalog.luau` e produtos no Creator Hub. **Recomendação: fazer antes de
   divulgar**, porque uma derrubada depois do pico zera a receita.
3. Publicar lugares separados (Fase 1) e preencher `deployment/local.json`.
4. Reenviar trilha de batalha (declaração de autoria).
5. Cadastrar produtos novos (pacotes, passe por temporada, boost) e ícones.
6. Compras reais em conta de teste: cada passe/produto uma vez, Pacote
   Inicial duas, cancelamento, sair/voltar, região restrita.
7. Teste em Android de entrada e iPhone (FPS, toque, notch, som).
8. 4 jogadores reais: fila, teleporte, reconexão, replay.
9. 10–20 crianças/novatos sem explicação: medir D1/D7 pelo Analytics.

**Marketing de lançamento (sem custo):** 3 vídeos curtos (abertura de baú
lendário, chefe final, troca com amigo) com um código por vídeo; página com
ícone/miniatura já em `assets/store/`; código "LANCAMENTO" dando 1 baú Raro.

**Metas das primeiras 2 semanas:** D1 ≥ 25%, sessão média ≥ 12 min,
conversão ≥ 2% dos novos em qualquer compra, Pacote Inicial = item mais
vendido. Se D1 < 20%: atacar o maior abandono do funil (tutorial →
primeira torre → primeiro baú) antes de gastar em divulgação.

---

## Estado em 14/10/2026 (fim do dia)

Feito e **publicado** no place 97132875544830 (Studio log `Go to
PublishSuccessful`, 01:59 UTC de 15/10):

- Fase 0 inteira; Fase 1 (código): `release.py` preserva IDs.
- Fase 2: funil de compra, Pacote Inicial com contador, pacotes Lendário e
  Equipe, passe por temporada com herói brilhante exclusivo, VIP (baú grátis
  2x mais rápido, nome dourado), boost de Ouro 2x por 1 h, atalho "Comprar
  Ouro". **Os 4 produtos novos existem no Creator Hub** (IDs em
  `Config.Products.Consumables`) e a loja só desenha produtos com ID real:
  nada à venda que não funcione. Faltam só os ícones (dono).
- Fase 3: troca segura entre amigos, mercado do dia, evento de fim de semana,
  login de 28 dias, presente entre amigos, comemoração de vitória (VIP com
  holofote), abate de chefe com peso. Não feitos: modo rápido (um portal novo
  estoura o orçamento de peças do lobby), skins por maestria.
- Fase 4: brilho do herói "shiny" na torre em partida; flash e tremor no chefe.
  O resto depende de imagens (rostos, skybox, texturas) que só o dono envia.
- Fase 5: tudo do dono continua pendente (identidade/2FA, marca, lugares
  separados, trilha de batalha, ícones, compras de teste, aparelho real, D1/D7).

## Ordem de execução recomendada

Fase 0 → Fase 1 (código) → Fase 2 itens 1, 2, 9 → Fase 3 itens 1, 2, 3 →
Fase 4 itens 1, 2, 6 → restante das fases 2/3/4 em paralelo com os aceites
do dono (Fase 5). Lançar quando Fase 0, 1, 2 (1–5, 9) e 3 (1–3) estiverem
verdes e os itens 1, 2, 6 e 8 do dono concluídos.

## Verificação

- `python tools/test.py > out.txt; echo $?` = 0 a cada commit; testes novos
  para cada sistema (regras, PlayerService, client_boot, world_boot).
- Balanço: `python tests/test_match_simulation.py --sweep rosters` e
  `--sweep heroes` após a Fase 0 (taxa de vitória de referência em
  `docs/BALANCE.md`).
- Studio: `tools/studio_sync.py` no place 97132875544830, `studio_review.py`
  (PC, `--phone`, `--phone-size 375x667`, `--language en`) sem
  `DOOM_REVIEW_OVERFLOW`/erro; `studio_showroom.py bosses --zoom` em 3/4;
  orçamento do lobby < 4.550 peças; 60 FPS com `server:crowd 80`.
- Publicação: `Go to PublishSuccessful` no log do Studio; Analytics
  publicado mostrando `PurchaseCompleted` após compra de teste.
- Documentar cada entrega em `docs/director/BACKLOG.md` (novo bloco M37 com
  estes itens) e `docs/director/LOG.md`.
