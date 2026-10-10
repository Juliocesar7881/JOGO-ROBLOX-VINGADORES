# HUDs a partir das propostas visuais — 10/10/2026

Pedido: aplicar as imagens de referência às telas funcionais do jogo oficial,
escolhendo as variantes mais coerentes. Lugar da equipe: **97132875544830**;
repositório e entrega no `main`.

## Resultado

Molduras com cantos realmente recortados, contorno metálico, esmalte
azul-marinho, fitas inclinadas, retícula discreta e botões com resposta ao
pressionar. O menu lateral incorpora a legenda dentro da placa. Heróis e
bases usam retratos dos conteúdos do jogo; as bases receberam miniaturas
isométricas com plataforma, fachada e equipamentos da sua função.

A invocação apresenta os destaques e as chances do catálogo atual; missões
e opções ganharam ilustrações próprias. Cartas separam a ilustração dos
benefícios. Resultados e conexão usam figuras nas laterais. O recibo da
roleta tem enquadramento de carta colecionável e placa para o nome.
A árvore permanece transparente sobre blur, com navegação existente; no PC
abre mostrando a extensão dos ramos, com hexágonos legíveis.

Referências consultadas: 38 PNGs locais em
`output/imagegen/huds-pc-2026-10-10/`, incluindo as revisões `08-basechests-v2`,
`16-boarding-v2` e `21-placing-v2`. São propostas geradas para este projeto.
O acabamento foi reconstruído com elementos nativos de interface e
ViewportFrames; os modelos originais continuam animados. A anatomia dos
personagens ainda exige M22.7: a ilustração conceitual não representa uma
substituição já feita dos modelos. Preços, chances, atributos e ações seguem
o estado real, mesmo quando o desenho conceitual sugeria valores diferentes.

## Diagnóstico resolvido

| Problema | Correção | Evidência |
|---|---|---|
| Borda arredondada e brilho plástico destoavam das placas propostas | Contorno angular em três camadas, textura discreta e brilho menor | PC: equipe, invocação, resultados |
| Bases pareciam um único ícone plano | Miniatura 3D apoiada, equipamento por família e câmera em 3/4 | Bases, invocação de bases e recibo |
| Título do baú encostava no preço; árvore iniciava com ramo superior cortado | Altura e espaçamento do seletor; enquadramento inicial da árvore | Invocação e talentos |

## Matriz de telas

Estado das cenas abaixo: **verificado no Studio**, em PC horizontal.
As cenas de revisão são estados controlados da interface; a carga de
combate usa uma partida real separada. `sheetbase` continua mostrando a
aba disponível da ficha atual; não foi criada uma mecânica nova de base.

| Cena | Captura em `test-results/hud-reference/pc/` |
|---|---|
| Lobby | `01-lobby.png` |
| Primeiro acesso | `02-newcomer.png` |
| Modos | `03-modes.png` |
| Equipe | `04-squad.png` |
| Herói | `05-hero.png` |
| Árvore | `06-talents.png` |
| Invocação de heróis | `07-chests.png` |
| Invocação de bases | `08-basechests.png` |
| Bases | `09-bases.png` |
| Loja Robux | `10-premium.png` |
| Ouro | `11-premiumgold.png` |
| Missões | `12-quests.png` |
| Placar | `13-leaderboard.png` |
| Opções | `14-settings.png` |
| Prêmios | `15-rewards.png` |
| Embarque | `16-boarding.png` |
| AFK | `17-afk.png` |
| Interação | `18-prompt.png` |
| Preparação | `19-preparing.png` |
| Combate | `20-wave.png` |
| Posicionamento | `21-placing.png` |
| Mira da habilidade | `22-skillaim.png` |
| Ficha | `23-sheet.png` |
| Ficha: estado de base | `24-sheetbase.png` |
| Inimigo | `25-enemycard.png` |
| Chefe inspecionado | `26-enemycardboss.png` |
| Torre | `27-tower.png` |
| Cartas | `28-cards.png` |
| Chefe final | `29-finalboss.png` |
| Evolução da base | `30-baseupgrade.png` |
| Vitória | `31-results.png` |
| Derrota | `32-defeat.png` |
| Conexão do cliente | `33-loading.png` |
| Herói recebido | `34-reveal.png` |
| Base recebida | `35-revealbase.png` |
| Duplicado comum | `36-revealcommon.png` |
| Roleta | `37-reel.png` |
| Carta da galeria | `38-herocard.png` |

## Arquivos e estabilidade

Alterados: `UI.luau`, `Panels.luau`, `MatchHud.luau`, `Celebrate.luau`,
`Sheet.luau`, `InteractionHud.luau`, `TalentViewport.luau` e
`init.client.luau`, todos em `src/client/`; regressões em
`tests/client_boot.spec.luau`.

Os desenhos passivos não interceptam cliques ou gestos. A cor de seleção
atualiza a borda visível sem acumular geometria. Retratos liberam sua arte
ao destruir; miniaturas têm orçamento fixo, sem colisão ou autoridade de
combate. Menos efeitos, idiomas, rolagem, seleção, toque longo, arraste e
zoom continuam cobertos pelo roteiro completo nos seis formatos.

Economia, servidor, inventário, sons e sequência da roleta foram preservados.
O carregamento do controlador recebeu a composição nova; o carregador
inicial de `src/first/` mantém sua apresentação atual.

As fontes do Studio foram conferidas antes da sincronização. A única
diferença anterior no bootstrap do servidor era o prefixo de papel do place
gerado pelo build, preservado sem sobrescrever esse arquivo.

## Verificação e entrega

- Suíte completa: `test-results/hud-reference-full-suite.txt`; execução
  obrigatória na cadeia do commit em `test-results/hud-reference-full-commit.txt`.
- Revisão das 38 cenas: `test-results/hud-reference-pc-review.txt`.
- Bases após a miniatura 3D: `test-results/hud-reference-base-review.txt`.
- Formatos menores e inglês: logs `hud-reference-phone-review.txt`,
  `hud-reference-portrait-review.txt` e `hud-reference-english-review.txt`.
- Carga real: `test-results/hud-reference-live-check.txt` e três quadros
  `test-results/refinement/combat-event-01.png` a `03.png`. Complexo Gama,
  Cartas, cinco heróis: baseline com sete inimigos, 60 FPS e p95 17,81 ms;
  após `crowd 80`, 114 inimigos visíveis, 60 FPS e p95 18,02 ms.
  Duas amostras de dez segundos, PC com RTX 4060 Ti. Memória reportada pelo
  Stats do Studio: 3.820,7 e 3.840,7 MB; não é teste prolongado nem memória
  isolada de um cliente publicado.
- Pasta para comparação no Desktop:
  `Multiverse_HUDs_Implementados_2026-10-10`, com as 38 imagens, folhas de
  contato e índice navegável.

Publicado no mesmo place **97132875544830** em **10/10/2026 às 13:27:05
local (16:27:05 UTC)**; `Go to PublishSuccessful` confirmado no log do
Studio. Evidência: `test-results/hud-reference-publication.json` e
`test-results/hud-reference-publish.txt`. Oito módulos de cliente enviados
seletivamente, 37 fontes conferidas com o prefixo de papel anterior
preservado; lobby salvo com 4.455 peças, teto 4.500. Studio em edição.

Rodada final: 38 capturas de PC e 72 capturas nas revisões de 12 telas em
horizontal, vertical e horizontal/inglês, sem erros de script nem cortes
de texto detectados. A pasta do Desktop contém o índice `INDICE.html`,
cinco folhas de contato e `ANTES_DEPOIS.jpg`; referências e capturas
anteriores foram preservadas em subpastas para comparação.

Validação em celular físico, quatro jogadores e sessão prolongada permanece
**bloqueada por dependência identificada** (aparelho/sessão de teste).
Preferência visual do jogador permanece **pendente**; modelos e peso dos
ataques continuam em M22.7/M22.9, fora desta entrega de interface.

Avaliação pelas capturas: leitura 4, acabamento 4, consistência 4, objetivo 4,
recompensa 4 e desempenho PC 4. Uau e combate permanecem em 3: anatomia e
movimentos exigem a amostra de modelos e ataques, com evidência na captura
de combate acima. Não são resolvidos apenas pelo novo contorno da interface.
