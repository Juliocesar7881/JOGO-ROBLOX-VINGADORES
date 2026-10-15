# Fila do diretor

Legenda: `[ ]` a fazer · `[~] <id>` em andamento · `[x]` feito · `[!]` bloqueado (motivo).
Cada item cabe em 30–60 min e tem um critério de aceite verificável. Itens
novos entram na seção certa com a evidência (captura, teste, minuto do TTD).

## M0 — Referência e auditoria
- [x] M0.1 Assistir o vídeo do TTD → `docs/director/REFERENCE_TTD.md` com ≥25 observações com minuto.
- [x] M0.2 Jogar o jogo atual no Studio → `docs/director/AUDIT.md` com nota TTD × nós por área.

## M1 — Base segura para trabalhar a noite toda
- [x] M1.1 `src/client/Review.luau` + ação `StudioReview` só no Studio; `tools/studio_review.py` (Play, cenas, PrintWindow, Stop). Aceite: capturas de lobby/partida/fim sem editar nenhum script do lugar.
- [x] M1.2 Guardas: `studio_*_review.luau` recusam o place 97132875544830; apagar `tools/studio_hud_review.luau`.
- [x] M1.3 Dividir `init.client.luau`: `Panels.luau` (painéis do lobby). Aceite: client_boot verde, cliente <150 KB.
- [x] M1.4 Dividir: `LobbyWorld.luau`; `test_client_boot.py` descobre módulos sozinho; guarda de tamanho no `test_contract.py` (init.client 126→114 KB).
- [x] M1.4b Dividir `MatchHud.luau` (painel da torre, placas de upgrade, protocolo, renderMatch). Aceite: client_boot verde, init.client <90 KB.

## M1.5 — Consertos de HUD que todo jogador vê (da AUDIT)
- [x] M1.5.0 Câmera da partida abre de cima (commit 9a774e9).
- [x] M1.5.1 Barra de heróis estilo TTD: quadrado com retrato, número e preço; nome só no selecionado. Aceite: 5 espaços inteiros em 667×375, nenhum nome quebrado.
- [x] M1.5.2 Baús no celular: botão INVOCAR sempre visível sem rolar.
- [x] M1.5.3 Chat do Roblox fora do menu esquerdo e da barra do celular.
- [x] M1.5.4 "ONDA 20 / 50" sem estourar; rótulo da base só no idioma do jogador.
- [x] M1.5.5 Fim de partida: botão "JOGAR DE NOVO" (mesmo mapa/modo) + texto sem corte.
- [x] M1.5.6 Painel da torre no celular: não cobre o chefe; texto ≥12 px.

- [x] M1.5.7 (CAUSA ACHADA 01/10: a câmera inicial do lobby fica 23 studs atrás do spawn, dentro do Farol/HeroBeacon, a 27 studs ao sul; as órbitas de neon dourado giravam na frente dela. Farol movido para 46 studs; consulta ao Studio com `query()` listou as peças amarelas perto da câmera.) Lobby: a ponta amarela neon da estrela do nascimento enche 1/3 da câmera do computador ao entrar (captura 01-newcomer.png, 01/10 11:00). Aceite: nenhuma peça do chão ocupa >10% da tela na câmera inicial.
- [x] M1.5.8 Botão COMEÇAR TREINO maior e pulsando no computador (hoje é a faixa fina da dica).

## M2 — Marca original
- [x] M2.1 `tests/ip_blocklist.json` + `tests/test_ip_safety.py` (começa listando o que falta).
- [x] M2.2 Heróis: nomes, ramos, poderes e descrições originais (pt/en); `docs/HEROES.md` regenerado.
- [x] M2.3 Chefes, inimigos, mapas, bases, conquistas (normalize por id), códigos, título "Multiverse Doomsday".
- [x] M2.4 Lobby: placas, outdoors, naves, torre e agência sem marcas.
- [x] M2.5 Uniformes: os 12 visuais mais reconhecíveis redesenhados (`HERO_LOOK`/`HERO_EXTRAS`).
- [x] M2.6 Uniformes: os outros 24.

## M3 — Sensação de combate
- [x] M3.1 Números de dano por golpe (seus dourados, aliados claros, tamanho pelo valor).
- [x] M3.2 Agrupar `Shot` em lotes de 0,1 s (menos eventos de rede com 3x).
- [x] M3.3 Upgrade com antes→depois e % no painel do herói.
- [x] M3.4 Limite por herói por raridade (8/6/5/4/3), "2/4" na barra, recusa `unitLimit`.
- [x] M3.5 Velocidade 3x (passe) e 2x por maioria; teto de ticks 6→10.
- [x] M3.6 Prévia da próxima onda (ícones + contagem + "CHEFE em N").
- [x] M3.7 Chegada do chefe (câmera, cartão, barra com fases, "FASE 2!").
- [x] M3.8 Tela final com MVP (dano, abates, ouro por jogador).
- [x] M3.9 Ímã de moedas igual no cliente e no servidor; `duel_sweep` com `p.cash`.

## M4 — Robux
- [x] M4.1 Código: starter pack (uma vez), 6º espaço de equipe, VIP (+10% ouro, título), 3x; chaves no template e testes.
- [~] M4.2 (4 passes, 5 produtos, 15/34 heróis criados; PARADO no aviso de termos do Roblox — ver docs/director/ROBUX_CATALOG.md) Creator Hub: criar passes e produtos, IDs no `Config.luau`, tabela no LOG.

## M5 — Identidade dos mapas e dificuldades
- [x] M5.1 Perigo telegrafado por mapa (dados no Catalog, regra no Rules, passo no MatchService).
- [x] M5.2a Dificuldades Normal/Difícil/Pesadelo: dados no Catalog, cadeia por mapa no Rules (DifficultyUnlocked/CanUseDifficulty/HighestDifficulty), vida e ritmo no Waves; testes.
- [x] M5.2b Servidor: o primeiro do elevador escolhe a dificuldade (ação SetDifficulty, recusa se travada para qualquer passageiro), MatchService passa ao Waves, recompensa × rewardMultiplier, vitória grava campaign[mapa][winKey]; varredura mostra Difícil vencível com time bom.
- [x] M5.2c Cliente: seletor de 3 dificuldades no cartão do elevador (cadeado + motivo), cor da dificuldade no HUD e na tela final.

## M6 — Progressão
- [x] M6.1 (dados 01/10 duel sweep: Juba 83–94% e Geada 74–95% fortes demais p/ raros; Sombra 32–56%, Guaxo 27–64% fracos; mítico só 1 torre a 5000) Curva de raridade medida e ajustada (`--sweep heroes`).
- [x] M6.2 Estrelas por duplicata e variante brilhante.
- [x] M6.3 Missões rotativas e marcos de coleção.
- [x] M6.4 Passe de temporada grátis/premium (30 níveis, 2.000 → 7.800 XP por nível, 147 mil no total; passe `season` 399 com ID 0 até o dono criar no Creator Hub).

## M7 — Áudio
- [x] M7.1 (03/10: os 27 WAVs enviados pelo Gerenciador de ativos do Studio com `tools/studio_upload_audio.py`; IDs em `assets/audio/uploads.json` e `Config.Audio`; 26 tocam, `battle` aguarda a moderação do Roblox e enquanto isso a música do lobby cobre) Enviar WAVs; IDs no `Config.Audio`.
  - Notas 01/10: Chrome desconectado e Creator Hub parado nos termos; `CreateAssetAsync` indisponível no Studio 0.741 (ver LOG 18:20). Ferramenta pronta: `tools/studio_file_dialog.ps1` (responde ao diálogo Import File). Ordem de importância: click, place, upgrade, wave, chest, collect, victory, defeat, boss, ability, levelUp, open, breach, shot*, depois música (lobby, battle) e ambientes.

- [!] M7.2 (05/10 23:55 UTC: ainda `AssetFetchStatus.Failure` numa partida de teste; lobby, vitória e clique carregam. O jogo já troca para o tema do lobby após 6 s, então a partida não fica muda. Reenviar exige confirmar no Studio a declaração de que o arquivo é do dono: PRECISA do OK do dono) Conferir a trilha `battle` (ID 138426860300125): em 03/10 respondia `AssetDelivery403Moderated` (moderação do Roblox pendente ou negada). Como conferir: partida de teste (`studio_review.py --keep-playing live`) e um `Sound` com esse ID + `ContentProvider:PreloadAsync` (ver LOG 03/10 01:20). Se ainda falhar 24 h depois, regenerar a trilha com outra semente/andamento (`tools/generate_audio.py`), atualizar `assets/audio/manifest.json` e reenviar com `python tools/studio_upload_audio.py --window-handle <hwnd> battle` (abrir Janela > Gerenciador de ativos e a fila de importação antes), atualizando `assets/audio/uploads.json` e `Config.Audio.battle`.

## M8 — Primeiros 5 minutos
- [x] M8.1 Novato: um botão "COMEÇAR TREINO", treino 12 ondas, baú grátis guiado.

## M9 — Desempenho
- [x] M9.1 Orçamento de peças por mapa nos testes; qualidade automática quando o FPS cai.

## M10 — Entrega
- [x] M10.1 `docs/RELEASE_CHECKLIST.md`, `PRODUCTION_STATUS.md`, `MORNING_REPORT.md`.

## M11 — Próximas melhorias (abertas pelo diretor em 01/10, noite)
Escolha pela régua: o pior eixo primeiro. Cada item cabe numa sessão.
- [x] M11.1 (colocar: anel + coluna de luz na cor do herói; nível da torre: salto, anel e coluna dourada; chefe abatido: impacto dourado, faixa CHEFE DERROTADO! com confete e som de vitória; conferido 05/10) **Uau** (nota 3): ao colocar uma torre, subir de nível e abater chefe, mostrar movimento + som + número em ≤0,3 s (anel que expande, pulso na barra de heróis, "+N" no ouro). Aceite: cena no Studio com 3 quadros seguidos; `Effects.luau` dentro do orçamento de partes.
- [x] M11.2 (02/10: espaçamento menor, comandante/temporada mais baixos, rank em uma linha; ondas, ouro, XP, MVP, rank, comandante e temporada cabem sem rolar em 1280×720; só a lista de heróis que evoluíram rola) **Tela final enxuta**: hoje tem 6 blocos (ondas/ouro/XP, MVP, rank, comandante, temporada, equipe) e rola no computador. Aceite: tudo importante visível sem rolar em 1280×720; o resto atrás de "ver detalhes".
- [~] M11.3 (02/10: contrato testado — toque no chão só fixa o local, CONFIRMAR coloca, toque já usado pela interface é ignorado; falta aparelho real) **Toque no celular**: colocar torre arrastando do ladrilho (o jogo hoje coloca por toque no chão?). Aceite: teste de contrato de que a colocação aceita toque; revisão em 667×375. Precisa de aparelho real para validar.
- [x] M11.4 (02/10: brilho médio medido por captura no Studio — Fundição 72→98, Wakanda 91→97, Cidadela 90→102, Gama 132 e Manhattan 134 intactos; os três ficam mais escuros que Manhattan de propósito, mas legíveis) **Mapa de Gama e Fundição**: ainda os mais escuros da folha de mapas; testar `exposure` 0,45 e luz mais quente. Aceite: folha de mapas com nenhum mapa mais escuro que Manhattan.
- [x] M11.5 (02/10: a tela de carregamento roda ANTES de o cliente conhecer o perfil, então dica por perfil é impossível ali; o conjunto passou de 6 para 12 dicas, incluindo Gosmento, Sabotador, ping, mapa do dia e mutações) **Dicas dinâmicas**: a tela de carregamento tem 6 dicas fixas; trocar por dica conforme o que o jogador ainda não fez (nunca abriu a temporada, nunca fez estrela). Aceite: `tests/client_boot.spec` cobre a escolha.
- [x] M11.6 (02/10: MELHOR VALOR no maior pacote, MAIS POPULAR no de 5.000, 'Ouro por R$' em cada pacote, calculado do preço que a plataforma informa; linhas e pacote inicial mais enxutos no celular deitado; cartão do tutorial some atrás de painel aberto em tela curta) **Loja de Robux**: mostrar "Mais popular"/"Melhor valor" e o valor em Ouro por Robux nos pacotes. Aceite: captura da loja; preço continua vindo do Roblox (nunca do código).
- [x] M11.7 (calculado 01/10 em docs/BALANCE.md; falta confirmar com jogadores reais) **Equilíbrio do passe de temporada com dados reais**: medir XP por partida na simulação (campanha 50 ondas ≈ ?) e ajustar `firstXp/stepXp` para ~30–40 partidas ao todo. Aceite: número no `docs/BALANCE.md`.
- [x] M11.8 (6 nomes em ciclo, fim em dias no cartão) **Eventos de temporada**: nome e cor da temporada no cartão (ex.: "Temporada 1 • Ilhas do Alvorecer"). Aceite: `Catalog.Seasons` com nomes e a temporada atual derivada de `_season()`.

## M12 — Da revisão crítica de 02/10
- [x] M12.1 (flash e número já existiam; 02/10 entrou o micro recuo por golpe, maior nos fortes) Combate: o inimigo reage a golpe forte. Aceite: captura de 3 quadros + `Effects` dentro do limite.
- [x] M12.2 (02/10: Manhattan mais clara e quente, Gama com grama e chão claros) Manhattan e Gama menos cinzentos de cima (cor de telhado/ruas/arbustos). Aceite: folha de mapas com nenhum mapa mais monótono que a Selva.
- [x] M12.3 (conferido 02/10: já cabe em 667×375 sem sobreposição; nomes encurtados) Celular: topo esquerdo da partida concentra três painéis; separar o painel da torre para a direita em tela baixa. Aceite: ui_layout + captura 667×375.
- [x] M12.9 (02/10: Gosmento, 9º inimigo comum) Variedade de inimigos: o Gosmento racha em 2 Fragmentos ao morrer (Catalog.Enemies.splitter/splitling, MatchService._flushSplits); entra na onda 12 (8 no competitivo), nunca no treino; área e ricochete limpam os fragmentos. Aceite: test_rules + match_simulation (vida escalada, Ouro dividido, teto de inimigos, fim de onda só com fragmentos mortos).
- [x] M12.10 (02/10: Sabotador) Inimigo que interage com as torres: a cada 7 s avisa (1,2 s, 'CHOQUE') e paralisa por 1,6 s as torres num raio de 15 (Catalog.Enemies.saboteur.shock, MatchService `_shockable`); entra na onda 18 (14 no competitivo). Heróis imunes a paralisia (Capitão Men e a aura da Muralha humana) ignoram; paralisar o sabotador cancela o choque. Aceite: test_rules (limites do choque, nunca no treino) + match_simulation (aviso, paralisia, imune, cancelamento).
- [x] M12.11 (02/10: Caçador da Noite, 43º herói) Herói com mecânica nova de verdade: planta minas na estrada à frente dos inimigos (`attack = "mine"`, Match.mines, FX MineSync/MineBlast), dois ramos (Fragmentação: 7 minas maiores; Choque: paralisa e planta mais rápido) e a Bomba de Fumaça (paralisa + derrete armadura). Aceite: test_rules, match_simulation (planta, espaçamento, gatilho, voadores poupados, limite, expiração, venda, sincronização, ramos) e client_boot (desenha/limpa/ignora lixo); varredura de heróis: 22 ondas, dentro do grupo dos épicos.
- [x] M12.12 (02/10: inspetor de inimigo) Tocar/clicar num inimigo mostra um cartão com nome, vida atual, armadura, ritmo (LENTO/MÉDIO/RÁPIDO), tipo (VOADOR/CAMUFLADO/CHEFE) e uma linha do que ele faz e como responder (`trait`/`hint` no Catalog). Só apresentação (src/client/Inspect.luau); some em 5 s, ao tocar no chão vazio ou quando o inimigo sai. Aceite: client_boot (abre, mostra a vida sincronizada, chefe mostra a dica, some sozinho) e capturas desktop/celular (estágios `enemycard`/`enemycardboss`).
- [-] M12.4 (descartado 03/10: a coleção já aparece na galeria — contagem, filtros, estrelas, brilhantes — e o lobby não tem espaço livre para uma sala nova sem refazer o mapa; o Salão dos Heróis com as figuras que respiram cobre o lado cênico) Vitrine de coleção no lobby.
- [x] M12.5 (02/10: ping de grupo; 06/10: bônus de convite — conta nova que entra pelo convite ganha 500 Ouro uma vez, quem convidou ganha 300 se estiver no mesmo servidor, até 5 por dia; `Catalog.Rewards.invite`, `PlayerService:InviteBonus`, testes; presente entre jogadores fica para depois) Social.
- [x] M12.6 (02/10: mapa do dia +25% de Ouro e XP na campanha, faixa no menu, no elevador e na tela final) Evento diário.
- [x] M12.7 Áudio próprio (M7.1) — feito em 03/10 pelo Gerenciador de ativos do Studio (26 de 27 tocam; `battle` em moderação).
- [!] M12.8 Decisão de IP dos visuais — do dono (ver AUDIT 02/10).

## M13 — Feedback do dono, 03/10 (jogou com o amigo no Roblox normal)
Pedido do dono, na ordem em que chegou. Ele quer: letras maiores, visual moderno de Roblox em tudo, informação antes de gastar, nada de janelinha escondida.
- [x] M13.1 Colocar herói e usar poder de área SEM confirmação: o toque/clique no chão válido já posiciona (barra de baixo vira só dica + Cancelar).
- [x] M13.2 Setas do tutorial (anel, trilha de chevrons) ficam no chão ao pular (usam o último chão pisado).
- [x] M13.3 Faixa "Você tem Ouro para um baú!" some quando o Ouro acaba (a faixa só era refeita na renderização inteira).
- [x] M13.4 Em grupo a vida dos inimigos vale 2x (dupla), 3x (trio), 5x (quatro): `Waves.partyScale`.
- [x] M13.5 Sem limite de heróis (nem por herói nem por jogador): só um teto anti-inundação de 150 torres (`Rules.SafetyTowerCeiling`); a barra mostra "x2" em vez de "2/4".
- [x] M13.6 Evoluir a base não fecha a janela (ela se redesenha com o nível novo e o próximo preço).
- [x] M13.7 Agente da Base (figura articulada com anel dourado) ao lado da base de cada jogador: E abre SÓ a evolução da base; a aba BASE saiu da ficha e o texto de vida do HUD só avisa onde evoluir. Nome sem "S.H.I.E.L.D." (marca bloqueada em `ip_blocklist.json`).
- [x] M13.8 (painel da torre maior: números grandes com +%, lentidão/área, traços do herói, descrição de cada especialização antes de escolher) Tabela do herói que evolui: números de alcance, dano e cadência bem maiores, janela maior; descrição do que cada evolução faz ANTES de evoluir.
- [x] M13.9 (caixa invisível do tamanho do herói recebe o clique; Gelo Vivo: lentidão cresce com o nível, 25%->40% no nível 4) Clicar no boneco do herói em jogo (não só no círculo do chão) abre o cartão; cartão mais informativo (efeito de cada herói: lentidão do Gelo Vivo, e como evolui).
- [x] M13.10 (relógio a 1x durante a escolha; botão CARTAS próprio; aba CARTAS com totais e cartas ilustradas) Modo cartas: o tempo NÃO corre em 2x/3x enquanto escolhe a carta; botão próprio CARTAS (sai de FICHA); cartas informativas e bonitas; valores em verde (ganha) e vermelho (perde).
- [x] M13.11 Cartas com medalhão por tipo (anel = alcance, banco = economia, espada = dano, arco = cadência, relógio, caveira, asa, olho) em `src/client/CardArt.luau`; falta olhar no Studio e afinar o visual.
- [x] M13.12 (`Rules.CardTotals` multiplica; painel no canto com x1.21 verde >=1x e vermelho <1x; números da carta verdes/vermelhos) Cartas escalonam multiplicando (+10% duas vezes = +21%, -10% depois tira 10% do que já tem).
- [x] M13.13 Velocidade: botões 2x e 3x separados; em grupo o 2x precisa de todos (mostra 1/2); o 3x do passe vale sozinho; sem passe o botão abre a compra do passe. Falta: visual melhor do AUTO.
- [x] M13.14 (tocar no hexágono gasta o ponto; só uma linha de texto em cima, nada abre embaixo) Janelinha de baixo ("defense income") da árvore NUNCA abre; toda evolução toca só no hexágono.
- [x] M13.15 (painel da árvore sem fundo, hexágonos maiores) Árvore de evolução sem janela: só os ícones navegáveis sobre o mundo.
- [x] M13.16 (equipe: tocar no herói da equipe tira; tocar na coleção abre COLOCAR NA EQUIPE / INFORMAÇÕES) Equipe: clicar em cima do herói tira da equipe; clicar embaixo abre 2 opções (colocar na equipe / informações).
- [x] M13.17 (já existe o botão BASE no canto superior direito) Ícone próprio MINHAS BASES no HUD (sai de dentro de Heróis).
- [x] M13.18 (tela feita: seletor 1..máx, fita estilo caixa da Valve com marcador, um baú depois do outro, PULAR TUDO e resumo; falta olhar no Studio) (SERVIDOR PRONTO: `OpenChest` aceita `count` de 1 a `Catalog.MaxChestsAtOnce`=50, um resultado por baú em `result.batch`; FALTA a tela: seletor de quantidade 1..máximo pelo Ouro, fita de prêmios estilo caixa da Valve e abertura em sequência) Baús: animação de abertura igual à de caixa da Valve (fita de prêmios que roda e para); abrir vários em sequência; escolher de 1 até o máximo que o Ouro paga.
- [x] M13.19 (servidor + tela: seção "CARTA DO HERÓI" na página do herói com cartas, EVOLUIR e pontos de dano/velocidade/alcance; abertura mostra "+N CARTAS"; falta olhar no Studio) (SERVIDOR PRONTO e testado: `Catalog.HeroCards`, `Rules.CardRankCost/CardPoints/CleanPoints/CardBonus`, duplicata paga cartas, ações `RankUpHero` e `SetHeroPoints`, `PermanentModifiers` usa posto e pontos; FALTA a tela: seção "carta do herói" na página do herói com cartas x/y, EVOLUIR, pontos + e -, e "+N CARTAS" na abertura) Duplicata de herói vira CARTA (Clash Royale); cada carta evolui sem limite, aumenta tudo, e o jogador distribui pontos entre dano, cadência e alcance.
- [x] M13.20 (botão "i" em cada item da loja Robux abre status/descrição antes de comprar) Loja mostra status/informações de cada item antes de comprar.
- [x] M13.21 (lasers em 3 camadas com clarão no cano e rajada no impacto, conferidos em captura no Studio; cada tipo de poder tem visual próprio: coluna de luz e onda para explosão, cúpula e anéis para cura/escudo, estacas de gelo, raios do céu para atordoar/corrente, puxar/empurrar com rastros, fogo, enfraquecer; `tools/studio_review.py fx:lasers|powers` dispara em câmera lenta) Heróis atiram de verdade: lasers, projéteis, raios e poderes por herói.
- [x] M13.22 (tela de carregamento do jogo em ReplicatedFirst, `src/first`: tira a tela padrão preta, mostra marca, barra e dicas até a interface avisar `DoomReady` ou 60 s; build, Rojo, sync e contrato cobrem) Primeira abertura do jogo fica com tela preta/carregando por muito tempo (investigar: pré-carga, terreno, tela de carregamento).
- [x] M13.23 (fonte Gotham Black em lobby e HUD, painéis grandes e arredondados, placas do lobby com cantos redondos, botão AUTO com ON/OFF; o lobby já é praça circular com cercas e anéis) HUD/IU inteira: letras maiores, formas arredondadas e modernas, lobby sem cara quadrada.

## M14 — Refazer a IU no padrão dos jogos de referência, 04/10 (dono dormindo: trabalhar sem parar)

Referências: dois vídeos do dono (tycoon "Buy/Country/Sell" e um tower defense de anime), ver memória ui-reference-style. Tudo grande, título com fonte arredondada, nada cortado, informação ao passar o mouse.

- [x] M14.1 (fantasma sob o cursor via ViewportPointToRay, clique coloca, botão direito cancela, barra vira dica; teste cobre o raio) Colocar herói: o fantasma fica EXATAMENTE sob o cursor (o preview usava GetMouseLocation com ScreenPointToRay: 58 px abaixo do cursor), clique esquerdo coloca na hora, clique inválido não prende o fantasma, botão direito/Esc cancela, a barra de baixo vira dica (não parece botão de confirmar). Ping com G também.
- [x] M14.2 (canvas lógico 1150x640 escalado com UIScale; 1440p = 2,1x; celular fica 1x; Tutorial/Celebrate/Inspect/Sheet convertem pixels) Escala global da IU: HUD e painéis crescem com a tela (2560x1440 = 2x), layouts calculados num espaço lógico; testes de layout continuam passando.
- [x] M14.3 (Fredoka One + Builder Sans, faixa de título inclinada, X vermelho quadrado, corpo escuro com brilho diagonal, botões e abas com textura de pinos atrás do texto) Linguagem visual nova nos primitivos (UI.luau): fonte arredondada em caixa normal (não TUDO MAIÚSCULO), contorno escuro grosso e sombra, botões e abas com textura de pinos, janelas com faixa de título inclinada, corpo escuro texturizado, X vermelho quadrado.
- [x] M14.4 (dica ao passar o mouse: herói na coleção, equipe, barra da partida e chances do baú; talentos com agora/próximo/requisito) Passar o mouse mostra informação: herói na barra da partida e na coleção (dano, alcance, velocidade, alvos, traços, poder, nível/cartas); talentos (nome, efeito, custo).
- [x] M14.5 (tela cheia escura, hexágonos grandes saindo do hexágono de nível, ramos nomeados, entram encaixando um a um com som de clique, Sair/Redistribuir/pontos no rodapé) Árvore de evolução estilo "pesquisa" do vídeo: tela cheia escura, hexágonos grandes com ícone, nome e custo, abre animada com som de encaixe de Lego, botão Sair embaixo, pontos no canto; no lobby e na partida.
- [x] M14.6 (grade de heróis na cor da raridade com estrela e nível + painel com nome, nível, equipar/informações/líder, tabela Dano/Ataques/Alcance, pílulas de traço e poder) Equipe/Inventário estilo anime TD: grade de heróis (cor da raridade, estrelas, nível) + painel lateral (nome, nível, equipar/tirar, tabela Dano/Velocidade/Alcance, traços, poder, carta e evoluir).
- [x] M14.7 (cartas de chance na cor da raridade com % grande, selo Novo, nome contornado, preço em chip; dica com status ao passar o mouse) Invocação (baús) estilo banner: cartas altas com retrato, % e estrelas; botões grandes x1 e xN; nada cortado.
- [x] M14.8 (abas coloridas com ícone, linhas escuras iluminadas na cor do item, nome grande e linha de descrição, botão de preço grande) Loja estilo tycoon: abas coloridas com ícone, itens em linhas grandes com imagem, nome, raridade, descrição e botões de preço; loja Robux em cartões coloridos com info antes de comprar.
- [x] M14.9 (topo e barra de heróis na pele escura, ouro/troféu em pílulas com borda, painel da torre como carta de unidade com tabela agora/próximo e pips, cartas e resultados no mesmo estilo) HUD da partida: barra de topo maior (onda, vida da base), barra de heróis maior com retratos e preço, botões de velocidade/auto bonitos, painel da torre com tabela grande e prévia da melhoria.
- [x] M14.10 (postes, pés de balcão, arbustos, estátuas e o Agente da Base sólidos; nos mapas só sobra detalhe de chão) Lobby: tudo que parece sólido tem colisão (o dono atravessou coisas "em certos mapas"); auditar lobby e mapas.
- [x] M14.11 (porta redonda com moldura, aro colorido, poço escuro e galáxia em espiral girando contra arcos externos; piso redondo com chevron; dentro do orçamento de peças, sem partículas) Portais mais bonitos (anéis animados, prévia do mapa, nome legível), dentro da regra de brilho.
- [x] M14.12 (varredura de todas as telas no Studio em janela grande e em celular 667x375: nenhum texto cortado acusado; fila do portal, base, ficha, cartão de inimigo, resultados e cartas no mesmo estilo; só falta aparelho real e entrada real) Revisão completa no Studio em 2560x1440 e celular: nada cortado, nada sobreposto; conferir item a item a lista do dono de 03/10 (M13) no jogo de verdade.
- [x] M14.13 (publicado 05/10 05:58, 15:43 e de novo depois das torres/fontes; a experiência continua Privada: o dono decide o público) Publicar na Roblox depois de verde + revisão (o dono pediu manter o Studio e a Roblox atualizados).

## M15 — Refino contínuo, 05/10 (o dono pediu para não parar)

- [x] M15.1 (legenda de botão e rótulos com `UI.fit`/`UI.textLimit`; o limite do UITextSizeConstraint é em pixel real e não cresce com o UIScale, então agora é convertido pela escala da tela e reconvertido quando ela muda — antes, em 1080p, abas, avisos e o botão do poder saíam ~35% menores) Texto que encolhe para caber: a legenda de todo botão e os rótulos longos (opções, bases, cartas, resultados, objetivo, nível da árvore) diminuem até caber em vez de cortar; janela estreita sem estouro na revisão `--phone-size 375x667`.
- [x] M15.2 (varredura das 35 telas no Studio numa janela de escala 1,52 = classe 1080p; achou o limite de texto em pixel real, corrigido em M15.1; resultado de aliado e nome longo de baú ajustados) Revisão em 1920x1080 (o PC mais comum): lobby, HUD da partida, painel da torre e janelas; nada pequeno demais nem cortado. Aceite: capturas `test-results/review` sem GLARE nem estouro, nota >= 4 em leitura.
- [x] M15.3 (capturas na altura do jogador nas 4 direções: títulos grandes legíveis; o miúdo fica nos quadros de ranking, que são para ler de perto) Placas do lobby legíveis da praça: menos texto miúdo nas placas grandes (campanha, arena, invocação), título grande e no máximo uma linha de apoio. Aceite: captura da praça em 1280x720 onde cada placa se lê.
- [x] M15.4 (letras maiores: 2x/3x 22, Ficha/Cartas 17, AUTO 16; texto branco contornado em todos os estados; a cor do botão diz o estado) Controles da partida (2x, 3x, AUTO, Ficha, Cartas) com ícone desenhado e rótulo curto, estado ligado em cor; nada abaixo de 14 px no desktop.
- [x] M15.5 (passo do chefe levanta poeira maior e treme a câmera de leve perto dele; golpe forte já tinha número maior e mais claro) Sensação de combate: golpe forte com número maior e tremor leve, chefe pisando faz o chão pulsar; tudo respeitando "menos efeitos".
- [x] M15.6 Tela de carregamento com cara de jogo grande: raios girando, estrela dourada, título com degradê, faixa verde, barra maior e dica em caixa, tudo escalado à tela (commit 9601c12).
- [x] M15.7 Texto do servidor em "pt / en" aparecia cru na barra do chefe ("Impacto próximo / Impact nearby"): agora mostra só a metade do idioma; aviso de chefe com caveira em vez de cadeado; nome da base na partida nos dois idiomas.
- [x] M15.8 Resultado com o rosto (avatar) de cada comandante: MVP em aro dourado, aliados ao lado do nome; a faixa de dica do lobby não repete o objetivo do primeiro baú.
- [x] M15.9 Com chefe na estrada, as faixas de celebração da partida passam abaixo da barra do chefe e dos avisos (antes cobriam).
- [x] M15.10 Aviso de interação (tecla E) no visual do jogo para teclado e controle: tecla numa tampa dourada, lugar em cima e ação grande, painel escuro com borda dourada, clique funciona como a tecla; celular e tablet ficam com o aviso do Roblox (toque já testado).
- [x] M15.11 Trilha dos inimigos com cor de tinta saturada (antes uma faixa pálida que parecia tubo de luz) e bloom dos mapas limitado a 0,2 (Gama, Wakanda e Latvéria passavam: 0,26-0,31), com teste no world boot. Desempenho medido no Studio: 60 FPS no lobby, na partida e com 80 inimigos (pior quadro 35 ms).
- [x] M15.12 Menores textos do celular (nível do comandante, linha do mapa, botões de ramo da torre) com pelo menos 12 px, encolhendo para caber quando aperta.
- [x] M15.13 Dica ao passar o mouse nos controles da partida (poder do líder com o que faz agora, tecla e recarga; 2x, 3x, onda automática, ficha, cartas) e no espaço vazio da barra de heróis; teste do 2x.
- [x] M15.14 Inspeção do mundo na altura do jogador (invocação, portais de todos os mapas, zona AFK, loja, estátuas): a placa de portal bloqueado repetia o aviso numa linha flutuante por cima das próprias palavras; removida (commit 771f124).

## M16 — Refino contínuo, 06/10

- [x] M16.1 Painel da torre na Melhoria 4: a linha do próximo valor ficava vazia (o servidor manda as duas especializações, não um 'next'); agora cada número mostra o valor das duas especializações, cada um na cor do seu botão (verde | azul), como o ganho em verde das referências. Teste no client boot. Não conferido no Studio (dono com a janela em primeiro plano).
- [x] M16.2 Plural de verdade no texto do jogador: "ponto(s)", "prêmio(s)", "jogador(es)" (subida de nível, resultado, temporada, placar) agora escolhem singular ou plural pelo número; `tests/test_no_emoji.py` também recusa "(s)" em qualquer texto.
- [x] M16.3 (resultado em duas colunas em tela curta: o que ganhou à esquerda, rank, nível do comandante e temporada à direita, visíveis sem rolar; MVP compacto e linha do aliado numa linha só; conferido por captura 667x375 no Studio) Resultado no celular.
- [x] M16.4 Painel da torre na Melhoria 4 (M16.1) conferido no Studio: tabela com os valores das duas especializações (verde | azul).
- [x] M16.5 Linha da preparação: "Chefe na próxima onda" vem primeiro (era cortado no fim), no máximo três inimigos separados por vírgula (os nomes regionais já têm "•" por dentro) e reticências; chegada do chefe anunciada só pela faixa, sem o aviso repetido embaixo.
- [x] M16.6 Painéis no PC revistos por captura: rótulo de aba fica numa linha (encolhe medindo a largura, `UI.oneLine`, em vez de quebrar "Meus heróis 43"); missão não concluída diz "Em andamento" (não "Resgatar recompensa" apagado); botões do placar e abas de filtro maiores; trilha da temporada com prêmio grátis grande e botões legíveis.
- [x] M16.7 Cartão do inimigo maior (nome 23, vida 20, barra mais grossa, chips 24 px, dica em creme 16) e ficha da partida medida pelo tamanho real da janela (abria pequena porque media durante a animação); aba "Talentos" legível.
- [x] M16.8 Colocação: a faixa de cima diz o herói e o preço (antes repetia "clique para colocar" da barra de baixo); poder diz a área em studs; textos da faixa, da barra e do Cancelar maiores.
- [x] M16.9 Celular em pé (375x667) sem texto cortado: título da janela numa linha que encolhe, título de seção, nome e texto das missões, melhor marca, baú grátis e resumo do portal encolhem para caber (relógio ao lado da contagem do portal).
- [x] M16.10 O chat do Roblox (à direita, no meio) se esconde enquanto uma janela do jogo está aberta (painel, ficha, resultado, cartas, evolução da base, carta da torre) e volta ao fechar; antes cobria o filtro "Mítico" e o cartão da torre.
- [x] M16.11 Zona AFK: o aviso "+5 Ouro por minuto • próximo em…" ficava atrás do cartão de objetivo; agora desce para baixo dele, na pele das janelas, com título e detalhe maiores (conferido levando o personagem à câmara no Studio).
- [x] M16.12 Avisos de interação no idioma do jogador: o servidor escrevia "Abrir / Open"; agora o cliente mostra só a metade certa, e lojas e salões de invocação levam nome em português e inglês (placa e aviso).

## M17 — Próximos passos, 07/10 (abertos pela revisão do Studio)

- [x] M17.1 Ficha da partida: hexágonos com raio mínimo de 40 px, árvore rolável sem coordenadas negativas e seleção preservando rolagem. Cena `sheet` conferida no Studio em PC, horizontal e vertical, português e inglês.
- [x] M17.2 Vitrine em 3/4, seis chefes conferidos na mesma câmera/iluminação; cauda do Gekko, ombreiras do Comandante Sombra e espinhas do Megabruto reforçadas. Orçamento do world boot aprovado.
- [x] M17.3 (dublê de TextChatService no client_boot; abre Missões, confere o chat escondido, fecha e confere de volta) Teste de cliente para o chat que se esconde com janela aberta (o dublê ainda não tem TextChatService). Aceite: `client_boot.spec` abre um painel e confere `ChatWindowConfiguration.Enabled == false`, fecha e confere `true`.
- [!] M17.4 Depende do dono: trilha `battle` bloqueada pela moderação (reenvio pede a declaração de autoria no Studio); produtos restantes no Creator Hub (aviso de termos); decisão de IP do visual da liga e do nome "Capitão Men"; teste em aparelho real.

- [x] M17.5 Dica por toque longo: 0,4 s abre, soltar fecha, arrastar cancela, toque curto seleciona e mouse preservado. Entrada de toque simulada nos seis roteiros completos; aparelho físico segue em M17.4.
- [x] M17.6 `server:unlock` exclusivo da memória do Studio, com equipe e desbloqueios preservados no salvamento; testes de nuvem/memória e contrato aprovados. Partida nova de Cartas em `gamma` iniciada no Studio com cinco torres; nenhum desbloqueio de nuvem.
- [x] M17.7 Cenas `afk` e `prompt` usam os componentes reais. Renda, sessão e salvamento completos; viagem em linha própria, abaixo do objetivo após o layout. PC e celular vertical/horizontal conferidos sem cortes.
- [x] M17.8 Seis processos independentes executam todos os roteiros do cliente, sem remover cobertura. Rodada medida em 110,9 s; `--workers 1` mantém execução serial disponível.
- [x] M17.9 Dano efetivo e abates por torre no cartão, acertos fortes com escala limitada e indicador animado da melhoria; respeitam Menos efeitos e limites de efeitos. Testes aprovados e três capturas de combate real. PC no Studio: 60 FPS antes/depois de adicionar 80 inimigos (114 no snapshot), p95 de 17,62/18,17 ms; celular e sessão prolongada continuam pendentes.
- [x] M17.10 Varredura das 37 cenas em português (PC, vertical, horizontal) e inglês (PC, horizontal). Corrigidos cortes da loja/ficha e contaminação das cenas pela animação de baús; telas afetadas repetidas com saída 0. Revisão agora falha ao encontrar corte ou erro de script.
- [x] M17.11 Última correção de `PlayerService.luau` sincronizada seletivamente, lobby de edição refeito e publicação no lugar da equipe `97132875544830` confirmada por `PublishSuccessful` em 08/10/2026 às 13:16:21 UTC (10:16 local), após o dono confirmar que o PC estava livre. Acesso e colaboradores preservados.

## M18 — Prévia de Q e árvore navegável, 08/10

- [x] M18.1 Q: prévia regional antes do clique, raio recebido do servidor, acompanhamento da mira, contorno reutilizado, limites/cancelamento e ausência de círculo em poder global; testes de relayout sem lançamento.
- [x] M18.2 Árvore do lobby navegável por arraste e roda, hexágonos maiores, Centralizar, posição/zoom preservados e adaptação à tela; arraste não compra, eventos encerram ao fechar e sons respeitam mute.
- [x] M18.3 Revisão final em PC, celular horizontal/vertical e inglês sem cortes detectados; fontes finais comparadas, sincronização seletiva e publicação no lugar da equipe às 14:46:18 UTC. Código `2aa4d0f`; evidências e limites em `docs/REFINAMENTO_Q_ARVORE_2026-10-08.md`.

## M19 — Acabamento do lobby e áudio, 08/10

- [x] M19.1 Mar sem reserva vazia antes da partida; costa, passagem pavimentada da torre, cantos arredondados, caixilhos, iluminação e cinco vitrines distintas. Salões com frontões, janelas circulares e plataforma. 4.489 peças dentro do teto; passagem do personagem, aviso físico da loja e capturas conferidos no Studio.
- [x] M19.2 Mix atual mais discreto: coleta curta, construção mecânica, melhoria com carga, habilidades por família, distância, variação e limite de vozes. Testes de repetição, mute, camadas agendadas, transições e famílias aprovados. IDs antigos preservados.
- [!] M19.3 Doze fontes WAV novas produzidas e verificadas, ainda sem upload/moderação: confirmação de autoria somente pelo dono. Arquivos, manifesto e procedimento em `assets/audio/refined/README.md`. O mix M19.2 já funciona com os assets existentes.
- [x] M19.4 Código `ba3bd26` no main, fontes finais comparadas e sincronizadas seletivamente; lobby de edição refeito. Publicação no mesmo lugar da equipe confirmada por `PublishSuccessful` em 08/10/2026 às 16:17:38 UTC (13:17 local). Capturas, testes e limites em `docs/REFINAMENTO_LOBBY_AUDIO_2026-10-08.md`.

## M20 — Contornos, baús e música de combate, 08/10

- [x] M20.1 Margens para contornos em listas, galerias e barra de heróis, com canvas preservando rolagem. Capturas de PC, celular horizontal/vertical e inglês conferidas no Studio, sem cortes de texto detectados.
- [x] M20.2 Recompensas na mesma roleta da compra; todos os prêmios de lotes preservados e cartão imediato, sem segunda abertura. Testes do cliente em seis formatos aprovados.
- [x] M20.3 Trilha não carregada usa arranjo de ação com coro menor e percussão dos próprios áudios; Música/Efeitos independentes e lobby mantido. Três stems carregados durante partida real, lobby parado e encerramento no resultado conferidos. Testes de áudio aprovados; avaliação auditiva pelo jogador pendente.
- [x] M20.4 Código `7e8b8b6` no main, seis fontes sincronizadas seletivamente e 36 fontes conferidas. Contornos em 46 capturas, baú gratuito real e música carregada na partida aprovados; lobby de edição refeito. Publicação no lugar `97132875544830` confirmada por `PublishSuccessful` às 17:05:04 UTC (14:05 local), 08/10/2026. Registro em `docs/REFINAMENTO_HUD_BAUS_2026-10-08.md`.

## M21 — Núcleo da base e aviso na partida, 08/10

- [x] M21.1 Núcleo da base sem laje neon: a placa ciano de 14 studs (que virava uma mancha estourada vista da câmera, captura 05-live 08/10 14:10) virou borda acesa fina; capas dos pilares em metal com faixa acesa. Aviso 'Evoluir base' 22% menor durante a partida para não cobrir o campo. Commit fc35568, conferido no Studio (03-live).
- [x] M21.2 `fc35568` incluído na publicação do refinamento M22 no mesmo lugar 97132875544830 em 08/10 às 21:11:50 UTC; `PublishSuccessful` confirmado.
- [x] M21.3 `studio_review.py` disparava os efeitos e pulava a fotografia. Captura automática adicionada; feixes e poderes inspecionados no Studio, com eventos de revisão identificados separadamente do combate real.

## M22 — Direção de arte, apoios e leitura de combate, 08/10

- [x] M22.1 Farol assentado, placa da academia com pés e sete pontes com quatro pilares cada; testes de contato e orçamento de peças.
- [x] M22.2 Passagem com nervuras, teto e painéis; vitrines com montantes; vidro, estrada, farol e pedestais com brilho menor. Capturas no lugar da equipe.
- [x] M22.3 HUD largo com horizonte livre; dois avisos rápidos no máximo, seleção prioritária e controles de toque mantidos; testes de layout e cliente.
- [x] M22.4 Revisão de 43 heróis, seis chefes e cinco famílias; armaduras metálicas, placas inclinadas e acabamento orgânico/rochoso. Rig e pivôs preservados; arte final ainda em M22.7.
- [x] M22.5 Feixes finos, ondas vazadas, poderes sem coluna gigante; treze perfis de ataque, retorno ao timbre neutro e limites de vozes/efeitos testados. Sem novos uploads.
- [x] M22.6 PC, celular horizontal/vertical e inglês sem cortes detectados; Cartas com cinco torres e 114 inimigos a 60 FPS, p95 18,22 ms. Código `ead8ccd`/`bb10c95`, seis fontes comparadas e sincronizadas seletivamente, preview 4.455 peças. Publicado no lugar 97132875544830 às 21:11:50 UTC; Studio em edição. Limites e capturas no relatório de direção.
- [ ] M22.7 Acabamento dos modelos ainda 3/5: anatomia de tronco, cintura, membros, mãos e pés refinada em M33 e conferida na amostra em movimento; 43 heróis e seis chefes fotografados. Falta acabamento próprio de figurinos/rostos e silhuetas por herói, sem classificar catálogo inteiro como finalizado. Evidências atuais: `test-results/anatomy/showroom/` e relatório REFINAMENTO_MODELOS_COMBATE_2026-10-11.md.
- [!] M22.8 Dependências externas: envio e moderação dos doze WAVs com declaração do dono, celular físico, quatro jogadores, viagens, compras e sessão prolongada. Consulte RELEASE_CHECKLIST e o relatório de direção.
- [ ] M22.9 Sensação de combate ainda 3/5: M33 conferiu três fases de cinco heróis, preparação com alvo real e emissão na pose atual, com Menos efeitos coberto. Falta conferir desempenho ativo com 80 inimigos e ampliar refinamento das demais assinaturas; as duas medições desta rodada foram invalidadas pelo Studio em segundo plano. Evidência: `test-results/anatomy/live/poses-audit.json`; aceite completo continua aberto.
- [x] M22.10 Reconstrução real revelou 4.569 peças, contra 4.476 no dublê. Decoração redistribuída sem retirar apoios: final 4.455 no Studio/4.362 no teste. `--preview-lobby` passa a recusar contagem real acima do teto de 4.500.

## M23 — Base, blur dos talentos e roleta por raridade, 08/10

- [x] M23.1 Base no dock principal, Heróis sem cartão de base e Bases sem abas para Heróis. Seis botões conferidos em PC/horizontal/vertical; regressão de seleção e geometria aprovada.
- [x] M23.2 Árvore sobre o cenário desfocado, sem fundo preto; textos com contorno, navegação e configuração Menos efeitos preservadas. Testes e capturas reais do Studio.
- [x] M23.3 Cliques independentes da coleta, sincronizados à roleta; um final distinto por raridade usando áudios próprios disponíveis, sem som duplicado no recibo. Mute, cancelamento, orçamento de vozes e substituição por upload cobertos.
- [!] M23.4 Áudio exato depende de envio na conta: `assets/audio/summon/` contém sete WAVs, o MP3 fornecido e manifesto. O dono responde às declarações aplicáveis e permite uso na experiência; depois atualizar `Config.Audio`. Não atribuir autoria dos recortes ao projeto. Instruções em `assets/audio/summon/README.md`.
- [x] M23.5 Código `86fb6bc` no main, suíte completa verde, seis fontes conferidas e sincronizadas seletivamente. PC/horizontal/vertical/inglês sem cortes; cinco assinaturas exercitadas e fontes carregadas no Studio. Lobby de edição com 4.455 peças; publicado no place 97132875544830 em 08/10 às 23:44:17 local (09/10 às 02:44:17 UTC), `PublishSuccessful` confirmado. Studio em edição. M23.4 continua pendente.

## M24 — Sons Sonniss e impactos legíveis, 09/10

- [x] M24.1 Inventário de 347 gravações nos cinco volumes; seleção de 52 fontes, 56 funções e 73 regiões em sete WAVs privados. Manifesto de origem/edição/hash e produtor reproduzível; biblioteca licenciada fora do Git.
- [x] M24.2 Perfis para o elenco atual, oito famílias de habilidade, três entradas de chefe, ambientes por mapa e cinco finais de roleta. Pools limitados, distância, variação, mute, carregamento e som anterior testados; IDs novos em zero.
- [x] M24.3 Impactos com aro expansivo e três fragmentos foscos, disparos finos da base e áreas cosméticas vazadas sem enfraquecer perigo. Nove quadros de revisão; batalha real com cinco torres e 90 inimigos visíveis a 60 FPS, p95 17,77 ms na RTX 4060 Ti. Suíte completa verde; PC/horizontal/vertical/inglês conferidos.
- [x] M24.4 Sete WAVs importados no Gerenciador de ativos do lugar oficial em 10/10, às 08:41 local. IDs reais em Config/manifesto, sete bancos carregados no cliente real. Arquivos privados e mapeamento em `assets/audio/sonniss/README.md`; envio anterior pendente é histórico.
- [x] M24.5 Integração técnica dos bancos: 73/73 regiões reproduzidas, cinco finais terminando sem vazamento, troca de loops e mute conferidos. Cartas/Complexo Gama, 114 inimigos visíveis: 59,99 FPS, p95 18,24 ms na RTX 4060 Ti. Corrigido som genérico do banner que silenciava o áudio específico dos ultimates; regressão no cliente em seis formatos. Evidências em `test-results/sonniss/activated-*.json`.
- [x] M24.6 Código `903a157` enviado ao main, suíte completa verde; 37 fontes finais iguais ao repositório, lobby salvo reconstruído dentro do orçamento. Publicado no mesmo place 97132875544830 em 09/10 às 23:57:05 local (10/10 às 02:57:05 UTC), `PublishSuccessful` confirmado. Studio em edição, importação parada no diálogo pessoal de direitos; bancos novos ainda em zero. Relatório registra o reenvio amplo interrompido durante o preview e a conferência posterior.
- [ ] M24.7 Aviso 3D da base corta na borda quando fica fora do enquadramento (`test-results/review/sonniss-combat80.png`). Ocultar ou reposicionar a apresentação projetada sem perder a interação; conferir PC e toque. Não é corte de texto do canvas 2D.
- [ ] M24.8 Escuta pelo jogador para ajustar preferência de timbre/volume do pacote já integrado. Celular físico, quatro jogadores, viagens e sessão prolongada permanecem no checklist; reprodução nativa no Studio não certifica esses itens.
- [x] M24.9 Ativação publicada: código `30e99e5` no main, suíte completa verde, Config/controlador sincronizados seletivamente e 37 fontes finais iguais ao git. Cinco poderes reais reproduzidos, inclusive ultimates; preview 4.455 peças. Publicado no place 97132875544830 em 10/10 às 09:13:57 local (12:13:57 UTC), `PublishSuccessful` confirmado; Studio em edição.

## M25 — HUDs com identidade de quadrinhos, 10/10

- [x] M25.1 Corpo azul-marinho corrigido, molduras, fitas, emblema dimensional original, navegação, botões e barras; árvore somente sobre blur e Menos efeitos preservados. Conferido no Studio em PC e celular.
- [x] M25.2 Retratos em busto na equipe/coleção/barra, figura inteira na ficha, vitrine da invocação com resultados reais e probabilidades compactas; bases, torre, cartas e roleta no mesmo sistema visual. Corrigidos chat sobre a torre, sobreposição torre/inimigo e textos da invocação/missões no vertical.
- [x] M25.3 Suíte completa verde; 38 cenas em PC/horizontal/vertical em português e 38 no horizontal em inglês, mais seleções em PC/vertical em inglês. Regressões e controles inferiores conferidos; rodadas finais de 93 + 48 capturas sem cortes de texto ou erros detectados. Carga de 90 inimigos: 60 FPS, p95 18,02 ms na RTX 4060 Ti. Sete módulos sincronizados seletivamente, 37 fontes finais conferidas; lobby 4.455 peças. Publicado no place 97132875544830 em 10/10 às 10:51:56 local (13:51:56 UTC), `PublishSuccessful` confirmado; Studio em edição. Relatório: `docs/REFINAMENTO_HUD_QUADRINHOS_2026-10-10.md`.
- [ ] M25.4 Comparar preferência visual com o jogador e validar toque no aparelho físico; modelos básicos continuam em M22.7 e peso dos ataques em M22.9.

## M26 — Implementação das propostas de HUD, 10/10

- [x] M26.1 Placas angulares nativas, contorno metálico, paleta azul-marinho, fitas e menu ilustrado; atualizações de seleção e entrada passiva cobertas por regressão.
- [x] M26.2 Composições de invocação, missões, opções, árvore, cartas, resultados, conexão e recibos. Bases com miniaturas 3D por função. Custos e dados reais preservados; 38 cenas conferidas em PC.
- [x] M26.3 Suíte completa verde, 38 capturas finais no PC e 72 nas revisões de formatos menores/inglês, sem erros/cortes detectados. Cinco heróis e 114 inimigos a 60 FPS, p95 18,02 ms na RTX 4060 Ti. Oito módulos sincronizados seletivamente, 37 fontes conferidas com prefixo de papel anterior preservado; preview com 4.455 peças. Publicado no mesmo place 97132875544830 em 10/10 às 13:27:05 local (16:27:05 UTC), `PublishSuccessful` confirmado. Studio em edição. Relatório `docs/REFINAMENTO_HUD_REFERENCIAS_2026-10-10.md`; galeria comparativa no Desktop.
- [ ] M26.4 Preferência do jogador e toque físico. Anatomia original ainda precisa de M22.7; não declarar os modelos das propostas como implementados.

## M27 — Inicialização e telas completas AFK, 10/10

- [x] M27.1 Ouro e XP com cenário próprio, contadores separados, estados honestos de pagamento e ações completas; arte nativa visível com 3D desligado. Pagamentos naturais, Mostrar jogo e Voltar ao lobby conferidos no Studio.
- [x] M27.2 Mesma arte na inicialização e conexão, prontidão real e prazo de saída incluindo mundo; regressões em seis formatos, inclusive perfil chegando antes do cenário e rotação da tela AFK.
- [x] M27.3 Suíte completa verde, 32 capturas PC/celular emulado/inglês sem cortes detectados. 39 fontes conferidas, cinco módulos sincronizados e lobby 4.455 peças. Publicado no place 97132875544830 em 10/10 às 14:06:51 local (17:06:51 UTC), `PublishSuccessful` confirmado. Studio em edição; galeria no Desktop e relatório `REFINAMENTO_TELAS_COMPLETAS_2026-10-10.md`. Celular físico/reconexão/sessão prolongada continuam no checklist.

## M28 — Arte ilustrada integrada aos HUDs, 11/10

- [x] M28.1 Seis texturas próprias produzidas e importadas: moldura, botão, carta, 16 ícones, seis baús e observatório. Fontes, prompts, entregas e hashes em `assets/ui/illustrated/`; IDs em Config. Texto e controles continuam nativos.
- [x] M28.2 Aplicação compartilhada ao catálogo de telas; retratos sem molduras duplicadas e com cor do herói, compra com espaço reservado para os controles e baú adaptável. Fallback imediato, conclusão assíncrona por URL, sem espera de rede na inicialização. Árvore mantém fundo desfocado.
- [x] M28.3 Código `a17f8a0` no main, suíte completa exit 0, 41 cenas PC/horizontal PT/vertical EN (205 capturas e 20 revisões), cliques reais, baú grátis e compra com Ouro, controles AFK. Cinco heróis/114 inimigos: 60 FPS, p95 18,10 ms na RTX 4060 Ti. Seis módulos sincronizados seletivamente, 40 fontes conferidas, preview 4.455 peças. Publicado no place 97132875544830 em 11/10 às 02:07:16 local/05:07:16 UTC, `PublishSuccessful` confirmado; Studio em edição. Galeria no Desktop, relatório `REFINAMENTO_HUD_ILUSTRADO_2026-10-11.md`.
- [ ] M28.4 Validação de preferência visual e toque no aparelho físico. Modelos reais continuam nos retratos; anatomia das propostas depende de M22.7. Memória prolongada e quatro jogadores continuam no checklist de lançamento.
- [x] M28.5 Removidos os desenhos antigos dos ícones e baús que possuem imagem no atlas, inclusive durante o download; legendas e controles preservados. Regressões em seis formatos, suíte completa verde e varredura no Studio: 41 cenas, 418 imagens, nenhuma camada antiga junto dos símbolos. Código `a7b4b1f` no main; UI sincronizada seletivamente, 40 fontes conferidas, publicado no place 97132875544830 em 11/10 às 09:00:47 local/12:00:47 UTC, `PublishSuccessful` confirmado; Studio em edição.
- [x] M28.6 Extremidades completas nas molduras do tutorial e das notificações; cantos adaptados à altura e escala em avisos, janelas, cartas e botões. Suíte completa verde em seis formatos, 24 combinações reais de tamanho/escala e redimensionamento no Studio, clique real no talento bloqueado e 19 capturas PC/horizontal/vertical, sem erros ou estouro de texto detectado. Código `9508be2` no main; IllustratedSkin sincronizada seletivamente, 40 fontes conferidas, preview 4.455 peças. Publicado no place 97132875544830 em 11/10 às 09:32:52 local/12:32:52 UTC, `PublishSuccessful` confirmado; Studio em edição.

## M29 — Lobby do conceito e placar da arena, 11/10

- [x] M29.1 Praça em camadas, jardins curvos, lanternas e monumentos com armaduras próprias; torre e invocação em azul-marinho/dourado, globo orbital e horizonte rochoso. Vistas dos mapas e funções existentes preservadas.
- [x] M29.2 Placar físico da arena com moldura, troféu, divisões coloridas por mapa, título montado e estado vazio ilustrado. Recordes reais substituem o pódio; títulos e estados em português/inglês.
- [x] M29.3 Regressões de circulação, bases dos jardins, apoios das placas e estados do placar; suíte completa verde. Preview real 4.433 peças contra teto de 4.500, sem elevar orçamento.

- [x] M29.4 Código `fb65172` no main, suíte completa exit 0 (72,56 s); circulação nas quatro pontes/passagem e duas lojas verificadas com personagem real. 20 capturas PC/horizontal PT/vertical EN sem cortes de texto ou erros detectados; placa PT/EN e cinco nomes longos por divisão conferidos. Cinco heróis/104 inimigos: 60 FPS, p95 17,92 ms na RTX 4060 Ti. WorldBuilder sincronizado seletivamente, 40 fontes comparadas, preview 4.433 peças. Publicado no place 97132875544830 em 11/10 às 11:05:12 local/14:05:12 UTC, `PublishSuccessful` confirmado; Studio em edição. Galeria Desktop `Multiverse_Lobby_2026-10-11/INDICE.html`; relatório `REFINAMENTO_LOBBY_CONCEITO_2026-10-11.md`.

## M30 — Primeira entrada, pinturas fiéis e recrutamento, 11/10

- [x] M30.1 Corrigida transição Lobby sem perfil para Lobby com perfil; prontidão após montar o HUD, duas tentativas de Sync no máximo e resposta antiga descartada. Carregador não espera assets opcionais; regressões em seis formatos.
- [x] M30.2 Duas pinturas geradas a partir da torre/praça/globo/estação AFK e dois heróis reais; fontes/prompts/hashes no manifesto, IDs reais carregados no Studio. Textos e controles nativos, reserva com modelos do jogo e remoção de duplicação ao carregar.
- [x] M30.3 Recibo com modelo real, entrada curta, assinatura do herói e raridade; nenhuma segunda abertura/fanfarra após a roleta. Cinco finais Sonniss com mix/acento limitado, mute/cancelamento e chat recolhido durante a recompensa.
- [x] M30.4 Código `b9e022a` no main, suíte completa exit 0 (75,33 s), PC/horizontal PT/vertical EN conferidos; baú ganho 0→1 com uma fanfarra, cliques reais e AFK, recrutamento a 60 FPS, p95 17,97 ms. Oito fontes sincronizadas seletivamente, 40 comparadas, preview 4.433 peças. Publicado no place 97132875544830 em 11/10 às 15:44:01 local/18:44:01 UTC, `PublishSuccessful` confirmado; Studio em edição. Galeria Desktop `Multiverse_Recrutamento_Entrada_2026-10-11/INDICE.html`, relatório `REFINAMENTO_RECRUTAMENTO_ENTRADA_2026-10-11.md`.
- [ ] M30.5 Conferir primeira entrada no cliente publicado em rede/dispositivo reais e preferência do jogador para as novas artes/animação/mix; não confundir essa validação com o perfil temporário do Studio.

## M31 — Três raridades e escolha por função, 11/10

- [x] M31.1 Comum/Raro/Lendário para 43 heróis, 11 bases e cartas de partida; cores, nomes e sons consistentes. Preservar preços, progressão, chances individuais, preferência de aquisição, limiares e reinício da garantia.
- [x] M31.2 Filtros de antiaéreo/área/controle/apoio, contagens na dica e Limpar filtros; chances efetivas compartilhadas com o sorteio e destaques da garantia marcados. Roleta de prêmio sem iniciais ou itens indisponíveis.
- [x] M31.3 Código `8cf1334` no main; suíte completa saída 0 (71.89 s), regressão de 35.280 sorteios/economia, 48 capturas PC/horizontal PT/vertical EN sem cortes ou erros detectados. Filtros por clique real sem alterar perfil; três finais sonoros carregados, cancelamento/mute e baú ganho 0→1 com uma fanfarra. Quatro destaques Cósmicos conferidos. Oito módulos sincronizados seletivamente, 40 fontes comparadas, preview 4.433 peças. Publicado no place 97132875544830 em 11/10/2026 às 16:47:04 local (19:47:04 UTC), `PublishSuccessful` confirmado; Studio em edição. Galeria Desktop e relatório `REFINAMENTO_RARIDADES_2026-10-11.md`.


## M32 — Retenção, aceites de lançamento e combate, 11/10

- [x] M32.1 Analytics com assinatura correta, falhas isoladas/retry e milestones por sessão/coorte. Teste de API estrita; Studio excluído.
- [x] M32.2 Próximo objetivo derivado pelo servidor e no resultado, prioridade ao baú gratuito no guia; sem nova economia ou requisição.
- [x] M32.3 Avisos 3D inteiros no viewport e atualização por quadro, limite de duas melhorias; regressões em seis formatos.
- [x] M32.4 Preparação/impacto/recuperação por família e contornos sem peças extras; M22.7/M22.9 não encerrados por essa fatia.
- [x] M32.5 Auditor de configuração e checklist atualizados: 26 produtos de heróis/temporada pendentes, VIP fora de venda confirmado, roteiro de testes reais e retenção.
- [x] M32.6 Código `fd58c0b` no main; suíte completa verde (68,53 s), 21 cenas PC/horizontal PT/vertical EN sem overflow/erro. Cinco heróis/80–104 inimigos a 60 FPS, p95 até 18,28 ms; avisos reais somem/restauram com a câmera. Treino encerrado por revisão confirmou objetivo grátis; resgate real 0→1 herói no perfil temporário. 12 módulos sincronizados seletivamente, 40 fontes comparadas, preview 4.433 peças. Publicado no place 97132875544830 em 11/10 às 21:33:00 local (12/10 00:33:00 UTC), PublishSuccessful confirmado; Studio em edição. Relatório RETENCAO_LANCAMENTO_2026-10-11.md e galeria Desktop.
- [ ] M32.7 Aceite externo: conta nova publicada, celular físico, quatro jogadores, compras reais, sessão prolongada e D1/D7. Usar RELEASE_CHECKLIST e RETENCAO_LANCAMENTO_2026-10-11.md.

## M33 — Anatomia e preparação dos ataques, 11/10

- [x] M33.1 Tronco afunilado, cintura/membros com volume, polegares/solas nos 43 heróis e chefes; amostra humanoide/grandalhão/inimigo, catálogo e seis chefes conferidos no Studio. Juntas/acessórios e limites existentes preservados.
- [x] M33.2 Preparação cosmética com alvo válido, uma vez por recarga, agrupada nos tiros; golpe pesado/controle e recuperação refinados. Emissão pela cadeia de juntas atual; nenhum dano, custo ou prazo alterado.
- [x] M33.3 Regressões de geometria, alvo/pista vazia, emissão, expiração e Menos efeitos em seis formatos; três fases observadas em cinco heróis no combate nativo. Evidências e limites em REFINAMENTO_MODELOS_COMBATE_2026-10-11.md.
- [x] M33.4 Código `f636a9a` no main, suíte completa verde (87,38 s), 20 capturas PC/horizontal PT/vertical EN sem erro ou overflow; 23 preparações/25 tiros e três fases de cinco heróis observadas no Studio. Quatro módulos sincronizados seletivamente, 40 fontes comparadas e preview 4.481 peças. Publicado no place 97132875544830 em 11/10 às 23:42:32 local (12/10 02:42:32 UTC), PublishSuccessful confirmado; Studio em edição. M33.5/M33.6 e aceites externos permanecem abertos.
- [!] M33.5 Medição de carga ativa pendente: duas tentativas invalidadas pelo Studio em segundo plano (~15 FPS), segunda também sem inimigos. Não declarar 60 FPS deste lote. Repetir quando houver foco estável, cinco heróis e pelo menos 80 inimigos.
- [ ] M33.6 Continuar figurinos/rostos e silhuetas próprios por herói (M22.7), depois demais assinaturas de ataque (M22.9). Acabamento de personagens e combate permanecem 3/5 até esses aceites; celular físico e sessão prolongada separados.

## M34 — Loja acessível e configuração comercial, 12/10

- [x] M34.1 26 produtos faltantes e Temporada criados no universo oficial; 51 IDs reais, nomes/descrições conferidos. VIP ativado, cinco passes à venda. Sem duplicar IDs existentes.
- [x] M34.2 Preços menores em Catalog e Creator Hub: heróis 9/29/79, passes 19–49, pacotes 5–79 Robux. Cliente consulta preço regional e valor real dos pacotes; servidor mantém política/entrega. Testes de 41 recibos oficiais e replay.
- [x] M34.3 Página fiel: título limpo, descrição base EN e PT/ES manuais, 17 idiomas automáticos habilitados, gênero correto e exclusão de recomendações desmarcada. Minimal e alcance Public/16+ confirmados.
- [x] M34.4 Código b089b43 no main, suíte completa exit 0 (63,83 s), 14 capturas finais e 51 metadados reais à venda. Quatro módulos sincronizados, 40 fontes comparadas, lobby 4.481 peças; publicado no place 97132875544830 em 12/10 às 14:12:16 local/17:12:16 UTC, PublishSuccessful. Shop publicado depois, 51 itens listados em quatro categorias; botão global adicional desligado.
- [ ] M34.5 Identidade/2FA e requisitos de ampliação pessoal; compras reais, celular físico, quatro jogadores, reconexão, sessão longa e D1/D7. Não declarar esses aceites por testes simulados ou metadados.

- [!] M34.6 Ícones externos individuais opcionais: protótipo nativo rejeitado, não enviado. Studio perdeu acesso ao place oficial depois da publicação (RCC-273); reconexão não restaurou a sessão. Arte interna e ícone/miniatura da experiência preservados. Retomar somente após restabelecer o acesso oficial.

## M35 — Placas do lobby e preços progressivos, 12/10

- [x] M35.1 Seis placas orientadas para a praça e apoiadas atrás dos balcões; título/status separados, texto curto e estrela acompanhando o emblema inteiro. Regressões de geometria, animação e localização.
- [x] M35.2 Preços da aba visível atualizam independentemente, com três consultas, timeout/retry e descarte de resposta antiga. Pacote inicial sem carregamento eterno; Studio mostra preços reais como teste sem permitir compra.
- [x] M35.3 Código 0358559 no main; suíte completa verde, 7.898 checagens de mundo e seis roteiros completos do cliente. Placas PT/EN, 14 telas PC/celular sem erro/overflow, estrela com offset constante e 51 preços reais conferidos. Seis módulos sincronizados, 41 fontes comparadas, lobby 4.499 peças. Publicado no place 97132875544830 em 12/10 às 23:14:09 local (13/10 02:14:09 UTC), PublishSuccessful confirmado; Studio em edição. Alterações locais anteriores do Claude preservadas. Relatório REFINAMENTO_PLACAS_PRECOS_2026-10-12.md e galeria test-results/galerias/Placas_Precos_2026-10-12.

## M36 — Heróis, estátuas e navegação, 13/10

- [x] M36.1 Árvore sem retratos laterais e Voltar fixo na ficha; regressões nos seis formatos.
- [x] M36.2 Acabamento dos 43 figurinos e dos dois monumentos, sem aumentar orçamento; suíte completa verde.
- [x] M36.3 Catálogo completo, ficha rolada PC/celular, estátuas e combate conferidos no Studio; fontes verificadas e publicação oficial confirmada em 13/10 às 18:00:25 local. Relatório REFINAMENTO_HEROIS_NAVEGACAO_2026-10-13.md e galeria Herois_Navegacao_2026-10-13.
- [ ] M36.4 Direção de arte futura: diferenciar silhuetas individuais além da estrutura compartilhada (roster-02/09.png); ajustar truncamento preexistente do detalhe de poder no celular vertical (hero-scrolled-vertical-en.png). Evidências na galeria M36; não são regressões de navegação.
- [x] M36.5 Estátuas usam os próprios heróis da partida em escala 2, com peças fixas e acessórios reais; modelos exclusivos e marcadores invisíveis removidos. Regressões de figurino/escala e capturas nativas, relatório CORRECAO_ESTATUAS_2026-10-14.md.
- [x] M36.6 Encaixes dos figurinos fundadores: peito/elmo/escudo do Capitão, cintura e contornos dos membros dos dois heróis; construtor compartilhado preserva o mesmo modelo de partida e estátua, sem peças adicionais. Regressões geométricas e galeria Estatuas_Ajustadas_2026-10-14.

## M37 — Plano final de lançamento, 14/10 (ver `docs/PLANO_LANCAMENTO.md`)

- [x] M37.0 (14/10: `speedMultiplier` guardado no inimigo e aplicado no movimento; `rewardBonus` inclui a dificuldade, vitória não conta duas vezes; `RunGold` aceita dificuldade e o cartão da fila mostra; "Sem medo do perigo" por 30 ondas competitivas (`wavesReached` no prêmio final); `Catalog.HeroCards.cap`; baú premium vira Ouro em região restrita; `_receipts` limitado a 200; testes em test_rules, player_service e simulação; trilha de batalha continua com o dono) Fase 0: velocidade de inimigo (Pesadelo/Corrida) aplicada; bônus de recompensa por modo/dificuldade por onda; conquista "Destemido" alcançável; teto de progressão com estrelas e cartas; baú da temporada premium vira Ouro em região restrita; poda de `_receipts`.
- [~] M37.1 (14/10: `release.py` mantém o valor do Config quando o JSON diz 0, com teste; `docs/DEPLOYMENT.md` atualizado. Falta o dono publicar o lugar de partida e preencher `deployment/local.json`) Fase 1: `tools/release.py` nunca sobrescreve ID real com 0; lugares separados publicados pelo dono; teleporte com 1 e 4 jogadores.
- [~] M37.2 (14/10: funil de compra no Analytics; Pacote Inicial com contador de 3 dias no banner e na faixa do lobby; atalho "Comprar Ouro" no baú; VIP com baú grátis em metade do tempo e nome dourado; produto `goldBoost` (dobro de Ouro por 1 h, empilha) pronto no servidor, HUD e loja; produto `seasonPass` (49 Robux) abre a trilha premium da temporada corrente e o nível 30 premium paga o herói brilhante exclusivo da temporada (`SeasonThemes[i].hero`), cartão e resultado mostram "Herói"; pacotes Lendário (99 Robux: 1 lendário à escolha + 12.000 Ouro) e Equipe (49 Robux: 3 raros à escolha) por crédito `heroPicks` e painel "Escolha seu Herói"; os quatro produtos criados no Creator Hub em 14/10 com IDs no Config; a loja só desenha produtos com ID real; faltam os ícones) Fase 2: funil de compra no Analytics; Pacote Inicial com contador; pacotes (Lendário/Equipe); passe por temporada com herói exclusivo; VIP com baú a cada 3 h; boost 2x Ouro; atalho "Comprar Ouro" no baú.
- [~] M37.3 (14/10: troca segura entre amigos pronta — 1 herói por 1 herói, só amigos do Roblox no mesmo servidor, sem Ouro, sem iniciais nem equipe, raridade diferente exige segunda confirmação, trava de 5 s, 10 por dia, histórico em `_trades`, painel "Troca entre Amigos" a partir de Meus Heróis; mercado do dia pronto — um herói por raridade por dia UTC, preço = garantia × 0,5, um de cada por conta, no salão de invocação; evento de fim de semana pronto — sábado e domingo UTC um mapa da campanha paga Ouro e XP ×2, faixa no cartão do portal e contador no HUD, sem mutação fixa por enquanto; login de 28 dias com baú a cada 7 e herói lendário à escolha no 28º; presente entre amigos pronto — 1 baú de Suprimentos por dia a um amigo do Roblox no servidor, aberto na página de Prêmios; comemoração de vitória: o herói líder do jogador performa vivo na tela de resultado, VIP com holofote dourado e confete; abate de chefe com tremor e flash. Faltam: modo rápido, painel de códigos separado, skins por maestria) Fase 3: troca segura entre amigos; loja rotativa diária; evento de fim de semana; login de 28 dias; skins por maestria; presente entre amigos; modo rápido; códigos; comemoração de vitória.
- [ ] M37.4 Fase 4: rostos por imagem; skybox próprio; materiais pintados; partículas próprias; lobby com marcos; peso de combate; silhuetas de chefes.
- [!] M37.5 Fase 5 (dono): identidade/2FA; decisão de marca; lugares publicados; trilha de batalha; produtos novos e ícones; compras de teste; aparelho real; 4 jogadores; D1/D7.
