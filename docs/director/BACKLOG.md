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
