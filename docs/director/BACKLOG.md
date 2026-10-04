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

- [ ] M7.2 Conferir a trilha `battle` (ID 138426860300125): em 03/10 respondia `AssetDelivery403Moderated` (moderação do Roblox pendente ou negada). Como conferir: partida de teste (`studio_review.py --keep-playing live`) e um `Sound` com esse ID + `ContentProvider:PreloadAsync` (ver LOG 03/10 01:20). Se ainda falhar 24 h depois, regenerar a trilha com outra semente/andamento (`tools/generate_audio.py`), atualizar `assets/audio/manifest.json` e reenviar com `python tools/studio_upload_audio.py --window-handle <hwnd> battle` (abrir Janela > Gerenciador de ativos e a fila de importação antes), atualizando `assets/audio/uploads.json` e `Config.Audio.battle`.

## M8 — Primeiros 5 minutos
- [x] M8.1 Novato: um botão "COMEÇAR TREINO", treino 12 ondas, baú grátis guiado.

## M9 — Desempenho
- [x] M9.1 Orçamento de peças por mapa nos testes; qualidade automática quando o FPS cai.

## M10 — Entrega
- [x] M10.1 `docs/RELEASE_CHECKLIST.md`, `PRODUCTION_STATUS.md`, `MORNING_REPORT.md`.

## M11 — Próximas melhorias (abertas pelo diretor em 01/10, noite)
Escolha pela régua: o pior eixo primeiro. Cada item cabe numa sessão.
- [~] M11.1 (colocar: feito 01/10 — anel + coluna de luz na cor do herói; falta chefe abatido e nível da torre: já tem salto/anel; checar no Studio) **Uau** (nota 3): ao colocar uma torre, subir de nível e abater chefe, mostrar movimento + som + número em ≤0,3 s (anel que expande, pulso na barra de heróis, "+N" no ouro). Aceite: cena no Studio com 3 quadros seguidos; `Effects.luau` dentro do orçamento de partes.
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
- [~] M12.5 (02/10: ping de grupo feito; falta presente/convite com recompensa) Social.
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
- [ ] M13.8 Tabela do herói que evolui: números de alcance, dano e cadência bem maiores, janela maior; descrição do que cada evolução faz ANTES de evoluir.
- [ ] M13.9 Clicar no boneco do herói em jogo (não só no círculo do chão) abre o cartão; cartão mais informativo (efeito de cada herói: lentidão do Gelo Vivo, e como evolui).
- [~] M13.10 (feito: o relógio vai a 1x enquanto alguém tem oferta de carta aberta; falta botão próprio e visual) Modo cartas: o tempo NÃO corre em 2x/3x enquanto escolhe a carta; botão próprio CARTAS (sai de FICHA); cartas informativas e bonitas; valores em verde (ganha) e vermelho (perde).
- [ ] M13.11 Cartas estilo arena de LoL: ícone por tipo (círculo = alcance, banco = economia, espada = dano, arco = cadência...).
- [~] M13.12 (feito: `Rules.CardTotals` multiplica; falta o painel de atributos no canto, verde >=1x e vermelho <1x) Cartas escalonam multiplicando (+10% duas vezes = +21%, -10% depois tira 10% do que já tem).
- [ ] M13.13 Velocidade: botões 1x/2x separados do 3x; em dupla o 2x precisa dos dois; 3x pago vale sozinho; sem passe o 3x abre a compra; auto-pular com visual melhor.
- [ ] M13.14 Janelinha de baixo ("defense income") da árvore NUNCA abre; toda evolução toca só no hexágono.
- [ ] M13.15 Árvore de evolução sem janela: só os ícones navegáveis sobre o mundo.
- [ ] M13.16 Equipe: clicar em cima do herói tira da equipe; clicar embaixo abre 2 opções (colocar na equipe / informações).
- [ ] M13.17 Ícone próprio MINHAS BASES no HUD (sai de dentro de Heróis).
- [ ] M13.18 Baús: animação de abertura igual à de caixa da Valve (fita de prêmios que roda e para); abrir vários em sequência; escolher de 1 até o máximo que o Ouro paga.
- [ ] M13.19 Duplicata de herói vira CARTA (Clash Royale); cada carta evolui sem limite, aumenta tudo, e o jogador distribui pontos entre dano, cadência e alcance.
- [ ] M13.20 Loja mostra status/informações de cada item antes de comprar.
- [ ] M13.21 Heróis atiram de verdade: lasers, projéteis, raios e poderes por herói (hoje os ataques são feios).
- [ ] M13.22 Primeira abertura do jogo fica com tela preta/carregando por muito tempo (investigar: pré-carga, terreno, tela de carregamento).
- [ ] M13.23 HUD/IU inteira: letras maiores, formas arredondadas e modernas, lobby sem cara "quadrada".

