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
- [ ] M1.4 Dividir: `MatchHud.luau` + `LobbyWorld.luau`; `test_client_boot.py` descobre módulos sozinho; guarda de tamanho no `test_contract.py`.

## M1.5 — Consertos de HUD que todo jogador vê (da AUDIT)
- [x] M1.5.0 Câmera da partida abre de cima (commit 9a774e9).
- [x] M1.5.1 Barra de heróis estilo TTD: quadrado com retrato, número e preço; nome só no selecionado. Aceite: 5 espaços inteiros em 667×375, nenhum nome quebrado.
- [x] M1.5.2 Baús no celular: botão INVOCAR sempre visível sem rolar.
- [x] M1.5.3 Chat do Roblox fora do menu esquerdo e da barra do celular.
- [x] M1.5.4 "ONDA 20 / 50" sem estourar; rótulo da base só no idioma do jogador.
- [x] M1.5.5 Fim de partida: botão "JOGAR DE NOVO" (mesmo mapa/modo) + texto sem corte.
- [x] M1.5.6 Painel da torre no celular: não cobre o chefe; texto ≥12 px.

- [!] M1.5.7 (NÃO REPRODUZ: captura seguinte sem a cunha; efeito passageiro) Lobby: a ponta amarela neon da estrela do nascimento enche 1/3 da câmera do computador ao entrar (captura 01-newcomer.png, 01/10 11:00). Aceite: nenhuma peça do chão ocupa >10% da tela na câmera inicial.
- [ ] M1.5.8 Botão COMEÇAR TREINO maior e pulsando no computador (hoje é a faixa fina da dica).

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
- [!] M4.2 (BLOQUEADO: extensão Claude in Chrome desconectada às 10:00 — reabrir o Chrome logado) Creator Hub: criar passes e produtos, IDs no `Config.luau`, tabela no LOG.

## M5 — Identidade dos mapas e dificuldades
- [ ] M5.1 Perigo telegrafado por mapa (dados no Catalog, regra no Rules, passo no MatchService).
- [ ] M5.2 Normal/Difícil/Pesadelo com desbloqueio em cadeia; escolha no elevador.

## M6 — Progressão
- [ ] M6.1 (dados 01/10 duel sweep: Juba 83–94% e Geada 74–95% fortes demais p/ raros; Sombra 32–56%, Guaxo 27–64% fracos; mítico só 1 torre a 5000) Curva de raridade medida e ajustada (`--sweep heroes`).
- [ ] M6.2 Estrelas por duplicata e variante brilhante.
- [ ] M6.3 Missões rotativas e marcos de coleção.
- [ ] M6.4 Passe de temporada grátis/premium.

## M7 — Áudio
- [ ] M7.1 Enviar WAVs no Creator Hub em ordem de importância; IDs no `Config.Audio`.

## M8 — Primeiros 5 minutos
- [x] M8.1 Novato: um botão "COMEÇAR TREINO", treino 12 ondas, baú grátis guiado.

## M9 — Desempenho
- [ ] M9.1 Orçamento de peças por mapa nos testes; qualidade automática quando o FPS cai.

## M10 — Entrega
- [ ] M10.1 `docs/RELEASE_CHECKLIST.md`, `PRODUCTION_STATUS.md`, `MORNING_REPORT.md`.
