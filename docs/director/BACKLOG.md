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
- [ ] M1.3 Dividir `init.client.luau`: `Panels.luau` (painéis do lobby). Aceite: client_boot verde, cliente <150 KB.
- [ ] M1.4 Dividir: `MatchHud.luau` + `LobbyWorld.luau`; `test_client_boot.py` descobre módulos sozinho; guarda de tamanho no `test_contract.py`.

## M1.5 — Consertos de HUD que todo jogador vê (da AUDIT)
- [x] M1.5.0 Câmera da partida abre de cima (commit 9a774e9).
- [x] M1.5.1 Barra de heróis estilo TTD: quadrado com retrato, número e preço; nome só no selecionado. Aceite: 5 espaços inteiros em 667×375, nenhum nome quebrado.
- [x] M1.5.2 Baús no celular: botão INVOCAR sempre visível sem rolar.
- [x] M1.5.3 Chat do Roblox fora do menu esquerdo e da barra do celular.
- [x] M1.5.4 "ONDA 20 / 50" sem estourar; rótulo da base só no idioma do jogador.
- [x] M1.5.5 Fim de partida: botão "JOGAR DE NOVO" (mesmo mapa/modo) + texto sem corte.
- [ ] M1.5.6 Painel da torre no celular: não cobre o chefe; texto ≥12 px.

## M2 — Marca original
- [ ] M2.1 `tests/ip_blocklist.json` + `tests/test_ip_safety.py` (começa listando o que falta).
- [ ] M2.2 Heróis: nomes, ramos, poderes e descrições originais (pt/en); `docs/HEROES.md` regenerado.
- [ ] M2.3 Chefes, inimigos, mapas, bases, conquistas (normalize por id), códigos, título "Multiverse Doomsday".
- [ ] M2.4 Lobby: placas, outdoors, naves, torre e agência sem marcas.
- [ ] M2.5 Uniformes: os 12 visuais mais reconhecíveis redesenhados (`HERO_LOOK`/`HERO_EXTRAS`).
- [ ] M2.6 Uniformes: os outros 24.

## M3 — Sensação de combate
- [ ] M3.1 Números de dano por golpe (seus dourados, aliados claros, tamanho pelo valor).
- [ ] M3.2 Agrupar `Shot` em lotes de 0,1 s (menos eventos de rede com 3x).
- [ ] M3.3 Upgrade com antes→depois e % no painel do herói.
- [ ] M3.4 Limite por herói por raridade (8/6/5/4/3), "2/4" na barra, recusa `unitLimit`.
- [ ] M3.5 Velocidade 3x (passe) e 2x por maioria; teto de ticks 6→10.
- [ ] M3.6 Prévia da próxima onda (ícones + contagem + "CHEFE em N").
- [ ] M3.7 Chegada do chefe (câmera, cartão, barra com fases, "FASE 2!").
- [ ] M3.8 Tela final com MVP (dano, abates, ouro por jogador).
- [ ] M3.9 Ímã de moedas igual no cliente e no servidor; `duel_sweep` com `p.cash`.

## M4 — Robux
- [ ] M4.1 Código: starter pack (uma vez), 6º espaço de equipe, VIP (+10% ouro, título), 3x; chaves no template e testes.
- [ ] M4.2 Creator Hub: criar passes e produtos, IDs no `Config.luau`, tabela no LOG.

## M5 — Identidade dos mapas e dificuldades
- [ ] M5.1 Perigo telegrafado por mapa (dados no Catalog, regra no Rules, passo no MatchService).
- [ ] M5.2 Normal/Difícil/Pesadelo com desbloqueio em cadeia; escolha no elevador.

## M6 — Progressão
- [ ] M6.1 Curva de raridade medida e ajustada (`--sweep heroes`).
- [ ] M6.2 Estrelas por duplicata e variante brilhante.
- [ ] M6.3 Missões rotativas e marcos de coleção.
- [ ] M6.4 Passe de temporada grátis/premium.

## M7 — Áudio
- [ ] M7.1 Enviar WAVs no Creator Hub em ordem de importância; IDs no `Config.Audio`.

## M8 — Primeiros 5 minutos
- [ ] M8.1 Novato: um botão "COMEÇAR TREINO", treino 12 ondas, baú grátis guiado.

## M9 — Desempenho
- [ ] M9.1 Orçamento de peças por mapa nos testes; qualidade automática quando o FPS cai.

## M10 — Entrega
- [ ] M10.1 `docs/RELEASE_CHECKLIST.md`, `PRODUCTION_STATUS.md`, `MORNING_REPORT.md`.
