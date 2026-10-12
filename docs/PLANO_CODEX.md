# Plano de continuação: Multiverse Doomsday (para o Codex)

Atualizado em 08/10/2026. Último commit no `main` ao escrever: `bf807bd`.
Este arquivo resume o estado do jogo, as regras que não podem ser quebradas e
**tudo o que ainda falta**, em ordem de prioridade, com critério de aceite.

---

## 1. O que é o projeto

- Tower defense cooperativo de Roblox, escrito 100% em Luau, sem nada da
  Toolbox. Mapas, heróis, inimigos e efeitos são feitos por script.
  `tools/build.py` gera os `.rbxlx` em `dist/`.
- Repositório: `C:\Users\loops\Documents\Roblox Game`, branch `main`. Duas
  pessoas e as IAs delas mexem ao mesmo tempo: rode `git pull --rebase` antes
  de começar, faça commits pequenos e **nunca** use force push, `reset --hard`
  ou reescrita de histórico.
- Lugar da equipe no Roblox (Team Create): **place 97132875544830**
  (universo 10768165352). A experiência continua **Privada**; abrir ao público
  é decisão do dono.
- Idioma principal: português; inglês é o secundário. Toda string que o
  jogador vê é `{ pt = "...", en = "..." }` (ou `T("pt", "en")` no cliente).
  Mensagens do servidor são `"português / english"`, e o cliente mostra só a
  metade do idioma do jogador (`serverText` em `src/client/init.client.luau`).

### Pedido do dono: trabalhar direto no projeto da equipe

O dono quer que o trabalho seja feito **direto no projeto que está em equipe**,
não numa cópia:

- **Código:** sempre no repositório e na branch **`main`** (o mesmo que o
  amigo usa). Nada de fork, nada de branch longa e nada de pasta paralela.
  `git pull --rebase` antes, `git push origin main` depois de cada entrega
  verde.
- **Studio:** o lugar em Criação em equipe (Team Create) é o **place
  97132875544830**, aberto no Roblox Studio do dono. Toda mudança de código
  vai para esse lugar com
  `python tools/studio_sync.py <arquivos .luau mudados> --place-id 97132875544830 --window-handle <h>`
  (só em modo de edição; o script recusa se o lugar aberto for outro), para
  que o dono e o amigo testem no Studio a versão atual.
- **Roblox:** depois de um lote verde e conferido, publicar nesse mesmo lugar
  (Arquivo > "Publicar na Roblox"). Assim a versão do Roblox normal também
  fica atualizada para jogar com o amigo. O dono pediu isso. Não mude
  configurações, público, preços nem colaboradores da experiência.
- **Fonte da verdade:** os arquivos `.luau` do git. Algo editado só dentro do
  Studio (Team Create) **se perde** quando o código do repositório é
  sincronizado ou publicado por cima. Por isso toda mudança passa pelo
  repositório primeiro. Se o amigo mexer direto no Studio, traga a mudança
  para o `.luau` correspondente antes de sincronizar.
- **Sem Studio** (por exemplo, o Codex rodando em outra máquina): faça só
  código e testes, dê push no `main` e deixe anotado no
  `docs/director/LOG.md` que falta sincronizar e publicar. O dono, ou a
  sessão que estiver no PC dele, roda o `studio_sync.py` e publica.

Leia antes de mexer: `CLAUDE.md` (regras da casa), `IMPLEMENTATION.md`
(contrato de rede), `docs/director/BACKLOG.md` (fila completa, M1 a M17) e as
últimas linhas de `docs/director/LOG.md`.

## 2. Regras invioláveis

1. **O cliente pede, o servidor decide.** Custo, posse, alcance, recarga, dano
   e recompensa são calculados só em `src/server/*.luau`, com dados de
   `src/shared/Catalog.luau` e funções puras de `src/shared/Rules.luau`. O
   cliente (`src/client/*.luau`) só desenha o que vem em `State`/`FX` e manda
   `Request` com a intenção. Um pedido inválido é recusado sem mudar estado,
   nunca "corrigido" em silêncio.
2. `src/shared/*.luau` contêm só dados e funções puras. Nunca use
   `game:GetService` ali.
3. Sorteio de baú acontece **antes** do `UpdateAsync`, porque o callback pode
   ser repetido.
4. Nenhum nome de terceiros chega ao jogador. A lista proibida está em
   `tests/ip_blocklist.json` e é verificada por `tests/test_ip_safety.py`. Os
   heróis usam epítetos descritivos (ver `docs/HEROES.md`).
5. Nenhum emoji em texto de jogador (`tests/test_no_emoji.py`). Use ícones
   desenhados (`UI.icon`, `Kit.emblem`). Também é proibido o plural
   preguiçoso "ponto(s)": escolha singular ou plural pelo número.
6. Pedidos fixos do dono:
   - nada de mascote ou personagem guia: o tutorial é feito com setas
     (`src/client/Tutorial.luau`);
   - brilho controlado: Bloom ≤ 0,2 (há teste no world boot) e nada de Neon
     pálido (`World.TameNeon`);
   - cenário sólido (`World.SolidifyProps`);
   - decoração sem título flutuante;
   - o idioma segue o locale do Roblox.
7. Interface:
   - Tudo é desenhado num canvas lógico de **1150x640**, escalado por
     `UIScale` (`UI.screenScale`). Tamanhos e posições são em pixels lógicos;
     `AbsoluteSize`/`AbsolutePosition` vêm em pixels reais (converta com
     `UI.toLogical`).
   - Texto que pode não caber: use `UI.fit(label, min)` (encolhe e quebra
     linha), `UI.oneLine(label, min)` (encolhe numa linha só, para abas e
     títulos) ou `UI.textLimit(...)`. **Nunca** crie um `UITextSizeConstraint`
     à mão: o limite dele é em pixel real e não acompanha a escala.
   - Primitivos de pele: `UI.windowSkin`, `UI.titleRibbon`, `UI.closeButton`,
     `UI.tab`, `UI.button`, `UI.pill`, `UI.statTable`, `UI.hover` (dica ao
     passar o mouse), `UI.section` e `UI.chip`.
   - Fontes: `UI.Fonts.display` (Fredoka One), `UI.Fonts.body` (Builder Sans).
8. Nunca aceite termos ou contratos em nome do dono, nunca compre nada, nunca
   digite senha. No Studio, nunca confirme "Redefinir layout" (reinicia o
   Studio).

## 3. Como testar

```bash
python tools/setup_luau.py      # uma vez: baixa o Luau CLI oficial
python tools/test.py > out.txt; echo $?   # tem que dar 0 antes de QUALQUER commit
```

- `tools/test.py` faz tudo:
  - compila todo o Luau;
  - roda cerca de 630 mil asserções de regras e economia;
  - testa PlayerService e PartyService;
  - simula uma partida inteira;
  - liga cliente e servidor reais contra dublês do Roblox
    (`tests/roblox_stubs.luau`);
  - confere o layout da interface em vários tamanhos de tela;
  - gera os places.

  Leva de 15 a 25 minutos. **Não** encaminhe a saída para `tail`, porque isso
  esconde o código de saída.
- Testes isolados mais rápidos:
  - `python tests/test_client_boot.py`: interface (cerca de 10 min).
  - `python tests/test_player_service.py`
  - `python tests/test_world_boot.py`
  - `python tests/test_ui_layout.py`
  - `python tests/test_contract.py`
  - `python tests/test_ip_safety.py`
  - `python tests/test_no_emoji.py`
- Sistema novo pede teste novo. Os testes de interface ficam em
  `tests/client_boot.spec.luau`. Se o código usar um serviço do Roblox que
  ainda não tem dublê, acrescente o dublê lá (veja `TextChatService` e
  `ProximityPromptService`).
- Commit em inglês, curto, no estilo do `git log`. Depois:
  `git pull --rebase && git push origin main`.

## 4. Studio (opcional: só funciona no Windows do dono)

Os scripts usam UI Automation e PrintWindow e não mexem no mouse.

```bash
python tools/studio_sync.py --place-id 97132875544830 --window-handle <h>          # envia todos os módulos (só em modo de edição)
python tools/studio_sync.py --preview-lobby --place-id 97132875544830 --window-handle <h>   # refaz o lobby de edição
python tools/studio_review.py --window-handle <h> [--phone] [--phone-size 375x667] [--language en] <cenas...>
python tools/studio_showroom.py heroes|enemies|bosses --window-handle <h>
```

- Para achar a janela (`<h>`), use `Get-Process RobloxStudioBeta`
  (`MainWindowHandle`).
- Cenas disponíveis:
  - telas: `lobby`, `modes`, `squad`, `hero`, `talents`, `chests`, `bases`,
    `premium`, `quests`, `leaderboard`, `settings`, `rewards`, `boarding`;
  - partida: `preparing`, `wave`, `placing`, `sheet`, `enemycard`, `tower`,
    `cards`, `baseupgrade`, `results`, `defeat`;
  - baús: `reveal`, `reel`;
  - comandos: `live`, `server:start <mapa> <modo>`, `server:towers`,
    `server:spawn a,b`, `server:crowd N`, `server:endwave N`,
    `focus:cam:x,y,z,tx,ty,tz`, `snap`, `hideui:on|off`.
- As capturas vão para `test-results/review/`. O script imprime as linhas
  `DOOM_REVIEW_OVERFLOW` para texto cortado e `GLARE` para brilho estourado.
- Antes de usar o Studio, confira se o dono está usando o PC: veja o tempo
  ocioso com `GetLastInputInfo`. Se houve entrada recente, trabalhe só no
  código.
- Publicar (o dono pediu para manter o Roblox atualizado a cada lote verde):
  Arquivo > "Publicar na Roblox" por UI Automation, no lugar da equipe. Para
  confirmar, procure `Go to PublishSuccessful` no log do Studio
  (`%LOCALAPPDATA%\Roblox\logs\*_Studio_*_last.log`). Antes de publicar, rode
  `python tools/studio_sync.py --preview-lobby --place-id 97132875544830 --window-handle <h>`
  para o lobby salvo no lugar ser o atual.

## 5. Onde está cada coisa

| Área | Arquivo |
|---|---|
| Dados (heróis, inimigos, mapas, baús, talentos, recompensas) | `src/shared/Catalog.luau` |
| Fórmulas | `src/shared/Rules.luau` |
| Ondas | `src/shared/Waves.luau` |
| IDs do Roblox (passes, produtos, áudio, imagens) | `src/shared/Config.luau` |
| Roteador do servidor e cenas de revisão do Studio | `src/server/init.server.luau` |
| Partida | `src/server/MatchService.luau` |
| Perfil, DataStore, compras, convite | `src/server/PlayerService.luau` |
| Mundo (lobby, mapas, figuras) | `src/server/WorldBuilder.luau` |
| Controlador do cliente (HUD, colocação, avisos, prompts) | `src/client/init.client.luau` |
| Primitivos de interface | `src/client/UI.luau` |
| Painéis do lobby (equipe, baús, loja, árvore, prêmios...) | `src/client/Panels.luau` |
| HUD da partida (carta da torre, cartas, resultado, base) | `src/client/MatchHud.luau` |
| Ficha da partida / cartão do inimigo / faixas | `src/client/Sheet.luau`, `Inspect.luau`, `Celebrate.luau` |
| Tutorial com setas | `src/client/Tutorial.luau` |
| Efeitos e áudio | `src/client/Effects.luau`, `src/client/Audio.luau` |
| Tela de carregamento | `src/first/init.client.luau` |
| Telas fixas do Studio (revisão) | `src/client/Review.luau` |

## 6. O que já está pronto (não refazer)

- **M13 e M14 (pedidos do dono de 03 e 04/10), completos:**
  - colocar herói com um clique, com o fantasma exatamente sob o cursor; botão
    direito cancela;
  - interface inteira no padrão dos jogos de referência (pele de janela, fita
    de título, abas com pinos, fontes arredondadas);
  - dicas ao passar o mouse;
  - árvore de evolução em tela cheia com hexágonos que encaixam com som;
  - equipe/inventário, baús em banner, loja;
  - portais redondos com galáxia, adereços sólidos.
- **M15:**
  - texto que encolhe para caber (inclusive em escala de 1080p);
  - nova tela de carregamento;
  - bônus de convite (500 Ouro para conta nova, 300 para quem convidou);
  - avatar no resultado;
  - trilha dos inimigos em cor de tinta e bloom limitado;
  - avisos de interação (tecla E) no visual do jogo.
- **M16:**
  - resultado em duas colunas no celular;
  - plural correto;
  - linha da preparação com o chefe na frente;
  - abas numa linha só;
  - cartão do inimigo maior;
  - colocação sem texto repetido;
  - celular em pé sem nenhum texto cortado;
  - chat do Roblox se esconde quando há janela aberta (com teste);
  - aviso AFK abaixo do objetivo;
  - avisos no idioma do jogador.
- **Desempenho medido no Studio:** 60 FPS no lobby, na partida e com 80
  inimigos (pior quadro: 35 ms).

---

## 7. O QUE FALTA FAZER (em ordem de prioridade)

### 7.1 Dá para o Codex fazer (código)

**A. Dica dos heróis no celular (toque longo).**
`UI.hover` (em `src/client/UI.luau`) só reage a `MouseEnter`, então no
celular não existe "passar o mouse" e o jogador nunca vê a ficha do herói (o
dono pediu essa informação).
- Fazer: segurar o dedo ~0,4 s numa carta de herói (barra da partida, coleção,
  equipe, baú) abre a mesma dica; soltar fecha.
- Aceite:
  - teste em `tests/client_boot.spec.luau` simulando
    `InputBegan`/`InputEnded` de toque;
  - um toque rápido continua sendo seleção normal;
  - nada muda no mouse.

**B. Árvore de talentos dentro da partida (M17.1).**
Na ficha (`src/client/Sheet.luau` chama `ctx.buildTalents` de
`Panels.luau`, opção `readOnly`), a árvore é larga e baixa e fica pequena na
janela de 560 px (hexágonos de ~26 px).
- Fazer: no modo `readOnly`, uma das opções:
  - organizar em duas fileiras (Fortuna e Guardião em cima, Comando embaixo);
  - ou permitir rolagem horizontal com hexágonos de pelo menos 40 px.
- Aceite: cena `sheet` com os hexágonos legíveis no PC e no celular, sem
  nenhum `DOOM_REVIEW_OVERFLOW`.

**C. Silhueta dos chefes (M17.2).**
`tools/studio_showroom.py` fotografa de frente, o que esconde focinho, cauda
e capa.
- Fazer:
  - pôr a câmera da vitrine em 3/4;
  - conferir os 6 chefes (`ENEMY_LOOK` e `ENEMY_EXTRAS.*` em
    `src/server/WorldBuilder.luau`): Comandante Sombra, Mestre das Ilusões,
    Gekko Colosso, Rei Saqueador, Tirano de Ferro e Megabruto;
  - reforçar quem parecer um infectado comum (silhueta, cor de família,
    acessório próprio).
- Aceite:
  - captura `bosses` em 3/4 em que cada chefe se reconhece pela forma;
  - continuar dentro do orçamento de peças do world boot.

**D. Revisão do Studio para modos bloqueados.**
`server:start manhattan cards` (e `ranked`) falha na revisão porque o perfil
de teste do Studio ainda não venceu a campanha.
- Fazer: um comando `server:unlock` só para o Studio, em
  `src/server/init.server.luau`, no mesmo bloco de `StudioGrant`, que marque a
  campanha como vencida **apenas** na memória do Studio (`self.memory`).
- Aceite: `studio_review.py "server:unlock" "server:start manhattan cards"`
  abre a partida de cartas; o teste de contrato garante que o comando não
  existe fora do Studio.

**E. Faixa AFK e prompts nas revisões fixas.**
Criar telas fixas em `src/client/Review.luau` para a faixa AFK
(`AfkBanner`) e para o aviso de interação próprio (`DoomPrompt`), para que a
varredura de texto cortado também passe por elas.
- Aceite: as cenas novas aparecem em `Review.STAGES` e passam na varredura
  `--phone` e `--phone-size 375x667` sem estouro.

**F. Tempo da suíte.**
`tests/test_client_boot.py` leva cerca de 10 min, porque roda o mesmo roteiro
em 6 tamanhos de tela.
- Fazer: sem perder cobertura, deixar o roteiro completo em 2 tamanhos
  (celular deitado e desktop) e nos outros só os passos de layout; ou
  paralelizar os tamanhos em processos separados.
- Aceite:
  - `tools/test.py` continua verde;
  - o número de checagens de layout não cai;
  - o tempo total cai pela metade.

**G. Sensação de combate (eixo "Uau" da régua em `.claude/skills/roblox-td-director/references/RUBRIC.md`).**
Ideias com aceite claro:
- a carta da torre mostra o abate e o dano total do herói na partida (o
  servidor já tem o dano por jogador; seria por torre);
- número de dano crítico ou forte com um leve "pop" de escala, dentro do
  orçamento de `Effects.luau`, respeitando "Menos efeitos";
- o salto do herói ao evoluir aparecer também no cartão (pips animando).

Aceite: captura com 3 quadros seguidos do evento e nenhum FPS perdido com
`server:crowd 80`.

**H. Polimento contínuo.**
Repetir a varredura completa nos três formatos e corrigir o que for acusado:

```bash
python tools/studio_review.py --phone lobby modes squad hero talents chests bases premium quests leaderboard settings rewards boarding preparing wave placing sheet tower cards baseupgrade results defeat reveal reel
python tools/studio_review.py --phone --phone-size 375x667 <as mesmas cenas>
python tools/studio_review.py --language en --phone <as mesmas cenas>
```

### 7.2 Só o dono pode fazer (não automatizar)

Lista completa em `docs/RELEASE_CHECKLIST.md`. Resumo:

1. **Trilha de música de batalha** (`Config.Audio.battle` = 138426860300125)
   bloqueada pela moderação do Roblox. Hoje o jogo toca o tema do lobby no
   lugar (não fica mudo).
   - Para trocar: `python tools/generate_audio.py`, gerar uma variação de
     `battle`, atualizar `assets/audio/manifest.json` e reenviar pelo
     Gerenciador de ativos (`tools/studio_upload_audio.py`).
   - O Studio pede a declaração de autoria do arquivo, que **só o dono
     confirma**.
2. **Creator Hub:**
   - aceitar os termos atualizados;
   - ligar a venda do Pacote VIP (299);
   - criar os 19 produtos de herói que faltam (lista em
     `docs/director/ROBUX_CATALOG.md`) e pôr os IDs em
     `src/shared/Config.luau → Products.Heroes`.
3. **Decisão de marca:** os heróis da "liga" são homenagens próximas, e o
   nome "Capitão Men" fica muito perto de um personagem de TV. Decidir antes
   de abrir ao público; trocas de nome são feitas no `Catalog.luau` e no
   `tests/ip_blocklist.json`.
4. **Página da experiência:** título, ícone, miniaturas (as imagens já estão
   em `assets/store/`), descrição e questionário de faixa etária.
5. **Lugares separados** (lobby, partida e AFK) publicados com os IDs em
   `deployment/local.json` (`docs/DEPLOYMENT.md`). Depois, testar portal com 1
   e com 4 jogadores e a reconexão no meio da partida.
6. **Aparelho real:** celular Android antigo (FPS), toque (colocar, melhorar,
   arrastar a câmera), notch, sons.
7. **Compras de teste:** comprar cada passe e pacote uma vez (o Pacote
   Inicial, duas) e conferir a entrega.

---

## 8. Como entregar cada tarefa

1. `git pull --rebase`
2. Faça a menor mudança que cumpre o aceite: dados no `Catalog`, fórmula no
   `Rules`, decisão no servidor, cliente só desenha.
3. Escreva ou ajuste o teste.
4. `python tools/test.py > out.txt; echo $?` tem que dar `0`.
5. Commit pequeno em inglês e `git push origin main`. Se o push for recusado,
   `git pull --rebase` e push de novo; nunca force.
6. Marque o item `[x]` em `docs/director/BACKLOG.md` e escreva uma linha em
   `docs/director/LOG.md`
   (`python tools/director.py log "FEITO <item>: <o que mudou>, commit <hash>"`).
7. Sincronize com o lugar da equipe (place 97132875544830) e confira por
   captura. A cada lote verde, publique nesse mesmo lugar para o Roblox normal
   ficar atualizado (seção 1, "Pedido do dono"). Sem Studio, anote no LOG que
   falta sincronizar e publicar.

## 9. Execução e refinamento de 08/10/2026

Código entregue no `main`: `3dd40f4`. Consulte
[`REFINAMENTO_2026-10-08.md`](REFINAMENTO_2026-10-08.md) para a matriz de
aceite, testes, capturas e dependências; a fila atualizada fica no
[`BACKLOG.md`](director/BACKLOG.md), M17.1–M17.11.

Entrega sincronizada e publicada no mesmo lugar da equipe em 08/10/2026,
às 10:16 local (13:16 UTC), com sucesso confirmado no log do Studio.
Cartas e carga de combate foram verificadas em playtest real do Studio;
as dependências da seção 7.2 continuam no checklist de lançamento.

A revisão usa o destino atual do modo de Cartas: **Complexo Gama**.
O exemplo da seção D deve ser `server:unlock` seguido de
`server:start gamma cards`; o jogo continua recusando Manhattan nesse modo,
conforme a associação de mapas do catálogo atual. Não é necessário alterar
as regras de entrada para revisar um modo bloqueado.

## 10. Pedido seguinte: Q e navegação da árvore

O refinamento de Q e da árvore tem registro próprio em
[`REFINAMENTO_Q_ARVORE_2026-10-08.md`](REFINAMENTO_Q_ARVORE_2026-10-08.md)
e fila M18 no backlog. O pedido altera a apresentação e navegação: raio
regional antes de lançar, arraste/zoom na árvore e respostas visuais/sonoras,
preservando as regras atuais de progressão e autoridade do servidor.

Código `2aa4d0f`, com suíte completa verde e revisão no Studio. Publicado no
mesmo lugar da equipe em 08/10/2026 às 11:46:18 local (14:46:18 UTC), com
sucesso confirmado no log; Studio deixado em modo de edição.

## 11. Acabamento do lobby e áudio

O pedido seguinte trata da passagem incompleta da torre, vazio no mar,
arquitetura do lobby e repetição dos sons. Implementação, capturas, testes e
dependências em [`REFINAMENTO_LOBBY_AUDIO_2026-10-08.md`](REFINAMENTO_LOBBY_AUDIO_2026-10-08.md), fila M19.

O mix atual usa os assets já disponíveis. Os 12 WAVs em
`assets/audio/refined/` estão produzidos e verificados, mas aguardam envio pelo
dono, declaração de autoria e moderação; não são gravações já publicadas.

Código `ba3bd26` enviado ao `main`, sincronizado seletivamente e publicado no
mesmo lugar da equipe em 08/10/2026 às 13:17:38 local (16:17:38 UTC), com
`PublishSuccessful` confirmado no log. Studio em modo de edição. Suíte
completa verde; travessia, loja física e carga de combate conferidas no Studio.

## 12. Contornos, baús e música de combate

O pedido seguinte corrige contornos cortados em telas roláveis, unifica a
roleta de compras/recompensas e retira a segunda abertura de baú. O combate
ganha um arranjo de ação quando a trilha dedicada não carrega, mantendo a
música do lobby. Fila M20 e registro em
[`REFINAMENTO_HUD_BAUS_2026-10-08.md`](REFINAMENTO_HUD_BAUS_2026-10-08.md).

Código `7e8b8b6` no main, conferido no Studio com 46 capturas, baú grátis
concedido pelo servidor e stems de ação carregados durante a partida.
Publicação no mesmo lugar da equipe confirmada em 08/10/2026 às 14:05:04
local (17:05:04 UTC). Studio em modo de edição; teste auditivo pelo jogador
e aparelho físico continuam pendentes.

## 13. Direção de arte e leitura do combate

Implementação do pedido de refinamento, com heróis e cooperação como
assinatura, registrada em
[`REFINAMENTO_DIRECAO_2026-10-08.md`](REFINAMENTO_DIRECAO_2026-10-08.md),
fila M22. Apoios físicos, passagem, materiais do catálogo, HUD com centro
livre, dois avisos rápidos, efeitos menos opacos e timbres por arma.

Suíte completa verde, revisões em PC e layouts de celular/inglês sem cortes
detectados. Cartas/Complexo Gama com cinco torres e 114 inimigos: 60 FPS no
PC do dono. Modelos e peso dos ataques ainda 3/5, com exemplos concretos na
fila; não confundir inspeção de todo o catálogo com arte final aprovada.

Código `ead8ccd`/`bb10c95` no `main`, seis módulos sincronizados
seletivamente. Publicado no mesmo lugar da equipe `97132875544830` às
18:11:50 local (21:11:50 UTC), 08/10/2026, com sucesso confirmado no log.
Lobby salvo com 4.455 peças, abaixo do teto de 4.500; a sincronização agora
confere esse orçamento também no Studio. Inclui a publicação pendente de
`fc35568`. Studio em edição; dependências de conta e aparelhos preservadas.

## 14. Base, fundo da árvore e sons da roleta

Base agora ocupa o menu principal, junto de Heróis. A equipe não mostra
base, e a tela de Bases não tem abas para Heróis. A árvore mantém arraste e
zoom sobre o cenário desfocado, sem o painel preto. A roleta tem cliques
próprios e um final diferente por raridade, sem repetir o som no recibo.

Código `86fb6bc` no `main`, suíte completa verde e revisão no Studio em
PC, celular horizontal/vertical e inglês. Publicado no mesmo lugar da equipe
às 23:44:17 local de 08/10/2026 (02:44:17 UTC de 09/10), com sucesso
confirmado no log. Registro e limites em
[`REFINAMENTO_BASE_ARVORE_ROLETA_2026-10-08.md`](REFINAMENTO_BASE_ARVORE_ROLETA_2026-10-08.md), fila M23.

O áudio exato do MP3 enviado depende do upload dos sete WAVs de
`assets/audio/summon/` na conta do dono e dos IDs reais. Os dois recortes
mantêm a origem da referência, e os cinco finais são sínteses originais.
Enquanto isso, o mix publicado usa áudios próprios disponíveis; não
confundir arquivos preparados com gravações já disponíveis no Roblox.

## 15. Sons Sonniss e leitura dos impactos

Os cinco volumes fornecidos foram inventariados; 52 fontes selecionadas
viraram 56 funções, 73 regiões e sete WAVs privados. Roteamento por arma,
poder, chefe, ambiente e raridade integrado com fallback, limites e testes.
Impactos e áreas cosméticas mais limpos, preservando os avisos de perigo.
Registro: [`REFINAMENTO_SONNISS_2026-10-09.md`](REFINAMENTO_SONNISS_2026-10-09.md),
fila M24.

Suíte completa verde e conferência no Studio; cinco heróis e 90 inimigos
visíveis mantiveram cerca de 60 FPS no PC. Os sete bancos ainda não estão
publicados: `Config.Audio.sfx* = 0`. O dono confirma os direitos na importação;
depois entram os IDs reais, a escuta e a medição do novo mix. Os sons
anteriores continuam funcionando até essa integração estar verificada.

Código `903a157` no `main`, publicado no lugar oficial em 09/10/2026 às
23:57:05 local (10/10 às 02:57:05 UTC), `PublishSuccessful` confirmado.
Studio em edição, com a janela de direitos dos sete WAVs aguardando o dono.
As 37 fontes finais foram comparadas com o repositório; veja o relatório
para as evidências e o registro do preview. Atenção: `studio_sync.py
--preview-lobby` sem arquivos também sincroniza tudo. Informar sempre os
arquivos alterados quando usar essa opção.

## 16. Ativação dos bancos e som dos ultimates — 10/10

Os sete bancos Sonniss foram importados no lugar oficial às 08:41 local,
com IDs reais em Config e manifesto. Todos carregaram no cliente real do
Studio: 73 regiões reproduzidas, cinco finais por raridade, loops e mute.
Tiros, golpes, teias e magia usam os perfis existentes; poderes têm oito
famílias. O banner de ultimate deixou de tocar um som genérico que consumia
a recarga de áudio e silenciava o poder específico. Regressão coberta nos
seis roteiros completos do cliente.

Com os bancos ativos, Cartas/Complexo Gama e 114 inimigos visíveis mantiveram
59,99 FPS na RTX 4060 Ti, p95 de 18,24 ms, em amostra de seis segundos.
Relatório e evidências em
[`REFINAMENTO_SONNISS_2026-10-09.md`](REFINAMENTO_SONNISS_2026-10-09.md).
A escuta de preferência pelo jogador, aparelho físico e quatro jogadores
continuam pendentes; a trilha antiga moderada mantém o arranjo de ação
existente como alternativa. O lobby preserva sua música.

Código `30e99e5` no `main`, suíte completa verde. Config e controlador do
cliente sincronizados seletivamente, 37 fontes finais conferidas, lobby
salvo com 4.455 peças. Publicado no mesmo place **97132875544830** em
**10/10/2026 às 09:13:57 local (12:13:57 UTC)**, `PublishSuccessful`
confirmado. Studio em edição; estados anteriores com IDs em zero são
históricos. M24.8 mantém a escuta pelo jogador e os testes externos pendentes.

## 17. HUDs com identidade de quadrinhos e multiverso — 10/10

Código `d6f064b` enviado ao `main` após a suíte completa verde.

Corpo azul-marinho, molduras e emblema dimensional original, navegação em
placas, retratos maiores, cartões por raridade, vitrine de invocação e barras
segmentadas. O padrão alcança os menus e o combate; a árvore continua
somente sobre o cenário desfocado. Corrigidos chat sobre as melhorias,
sobreposição torre/inimigo e truncagens do baú e das missões no vertical.

Suíte completa verde, seis roteiros de cliente, 38 cenas revisadas no Studio
em formatos de PC/celular e português/inglês. Carga real de 90 inimigos a
60 FPS, p95 18,02 ms na RTX 4060 Ti. Sete módulos sincronizados seletivamente,
37 fontes finais conferidas e lobby de edição com 4.455 peças. Publicado
no mesmo place **97132875544830** em **10/10/2026 às 10:51:56 local
(13:51:56 UTC)**, `PublishSuccessful` confirmado. Studio em edição.

Capturas, comparação antes/depois, matriz e limites em
[`REFINAMENTO_HUD_QUADRINHOS_2026-10-10.md`](REFINAMENTO_HUD_QUADRINHOS_2026-10-10.md),
fila M25. Preferência visual do jogador, aparelho físico e os modelos do
elenco permanecem identificados separadamente.

## 18. Implementação das propostas visuais de HUD — 10/10

Pedido de aplicar as 38 imagens ao jogo: placas com cantos recortados,
contorno metálico, retratos e composições por tela, miniaturas 3D de bases,
árvore enquadrada no PC e recibos com aparência de carta colecionável.
Dados, servidor e sons preservados. Relatório, matriz e galeria:
[`REFINAMENTO_HUD_REFERENCIAS_2026-10-10.md`](REFINAMENTO_HUD_REFERENCIAS_2026-10-10.md),
fila M26. Modelos reais continuam nos retratos; a anatomia das propostas
não substitui a amostra pendente em M22.7.

Suíte completa verde, 38 telas finais no PC e revisão de 12 telas nos
formatos horizontal/vertical e inglês. Cinco heróis e 114 inimigos a 60 FPS,
p95 18,02 ms na RTX 4060 Ti. Oito módulos sincronizados seletivamente;
37 fontes conferidas, prefixo de papel anterior preservado e preview
com 4.455 peças. Publicado no mesmo place em **10/10/2026 às 13:27:05 local
(16:27:05 UTC)**, `PublishSuccessful` confirmado. Studio em edição.
Comparativo no Desktop: `Multiverse_HUDs_Implementados_2026-10-10/INDICE.html`.

## 19. Telas completas de inicialização e farms AFK — 10/10

Ouro AFK, XP AFK e inicialização receberam cenário 2D nativo original de
observatório dimensional, cores por recurso e hierarquia própria. A arte
funciona com o 3D desligado, sem upload ou dependência de imagem. Contadores,
próximo pagamento e salvamento usam os dados existentes do servidor.
Inicialização e conexão compartilham a composição de ReplicatedFirst.

Suíte completa verde, seis roteiros de cliente e 32 capturas em PC,
celular emulado horizontal/vertical e inglês. Pagamentos naturais de Ouro
e XP, Mostrar jogo e retorno ao lobby verificados no servidor do Studio,
com perfil temporário. 39 fontes conferidas, cinco módulos sincronizados
seletivamente e preview com 4.455 peças. Publicado no mesmo place
**97132875544830** em **10/10/2026 às 14:06:51 local (17:06:51 UTC)**,
`PublishSuccessful` confirmado; Studio em edição.

Relatório e limites:
[`REFINAMENTO_TELAS_COMPLETAS_2026-10-10.md`](REFINAMENTO_TELAS_COMPLETAS_2026-10-10.md),
fila M27. Galeria no Desktop:
`Multiverse_Telas_Completas_2026-10-10/INDICE.html`.
Reconexão prolongada, DataStore publicado e aparelho físico continuam no
checklist; os testes desta entrega não certificam esses fluxos.

## 20. Arte ilustrada nos HUDs — 11/10

O pedido seguinte exige arte raster no jogo, aproximando o acabamento das
propostas. Seis imagens próprias foram produzidas, importadas e integradas
às janelas, botões, cartas, navegação, invocação, inicialização e AFK.
As letras, números e áreas de toque continuam nativos e dinâmicos.

Relatório e aceite:
[`REFINAMENTO_HUD_ILUSTRADO_2026-10-11.md`](REFINAMENTO_HUD_ILUSTRADO_2026-10-11.md),
fila M28. Fontes, prompts e IDs em `assets/ui/illustrated/`. Não confundir
os modelos reais dos retratos com os personagens inventados nas propostas.
Código `a17f8a0` no main, suíte completa verde, 41 cenas em PC/horizontal PT/
vertical EN e revisões finais sem cortes de texto/erros detectados. Cliques
reais, baú grátis, compra com Ouro e controles AFK verificados; cinco heróis
e 114 inimigos a 60 FPS, p95 18,10 ms na RTX 4060 Ti. Seis módulos
sincronizados seletivamente, 40 fontes conferidas, preview 4.455 peças.
Publicado no mesmo place da equipe em 11/10 às 02:07:16 local (05:07:16 UTC),
`PublishSuccessful` confirmado. Studio em edição. Galeria no Desktop:
`Multiverse_HUDs_Ilustrados_2026-10-11/INDICE.html`.

## 21. Lobby do conceito e placa da arena — 11/10

Praça em camadas, jardins curvos, monumentos com armaduras próprias,
torre e salões de invocação em azul-marinho/dourado, globo orbital e
horizonte rochoso. A placa da arena recebeu moldura, troféu, divisões por
mapa e estado vazio ilustrado. Os recordes reais substituem a arte de
pódio, com nomes completos ajustados ao espaço e localização PT/EN.

Fila M29; implementação, testes, capturas e publicação em
[`REFINAMENTO_LOBBY_CONCEITO_2026-10-11.md`](REFINAMENTO_LOBBY_CONCEITO_2026-10-11.md).
Preview com 4.433 peças dentro do teto de 4.500. As vistas dos mapas,
filas, custos e regras existentes foram preservados.

Código `fb65172` no main, suíte completa verde. Quatro pontes, passagem
da torre e duas lojas físicas conferidas; 20 capturas PC/celular emulado e
placar PT/EN sem cortes detectados. Cinco heróis e 104 inimigos a 60 FPS,
p95 17,92 ms na RTX 4060 Ti. WorldBuilder sincronizado seletivamente,
40 fontes comparadas e publicação no mesmo lugar da equipe em **11/10/2026
às 11:05:12 local (14:05:12 UTC)**, `PublishSuccessful` confirmado.
Studio em edição; galeria no Desktop `Multiverse_Lobby_2026-10-11/INDICE.html`.

## 22. Primeira entrada, pinturas fiéis e recrutamento — 11/10

O carregador agora reconstrói o lobby quando o primeiro perfil chega,
mesmo sem mudança de fase. Prontidão após montar o HUD, tentativas de
leitura limitadas e respostas antigas descartadas evitam a cobertura
presa. Imagens e áudio opcionais não bloqueiam a entrada.

Duas pinturas geradas com referências do lobby e dos modelos reais
substituem o observatório da inicialização/conexão e do AFK. Texto,
contadores e controles continuam nativos. O prêmio usa o modelo 3D real,
entrada curta e pose própria, com cinco finais Sonniss; sem segunda
abertura de baú ou fanfarra depois da roleta.

Fila M30; fontes, prompts, IDs e aceite em
[`REFINAMENTO_RECRUTAMENTO_ENTRADA_2026-10-11.md`](REFINAMENTO_RECRUTAMENTO_ENTRADA_2026-10-11.md).
Código `b9e022a` no `main`, suíte completa verde e revisão no Studio.
Oito fontes sincronizadas seletivamente, 40 comparadas e preview com 4.433
peças. Publicado no mesmo lugar da equipe em **11/10/2026 às 15:44:01 local
(18:44:01 UTC)**, com `PublishSuccessful` confirmado. Studio em edição;
primeira entrada no cliente publicado/dispositivo real continua como aceite
separado.

## 23. Três raridades e escolha por função — 11/10

Coleção unificada em Comum (16 heróis), Raro (15) e Lendário (12), também
aplicada às bases e cartas. Economia individual e grupos de aquisição
preservados; posse e progressão não exigem migração. Filtros por função,
destaques da garantia marcados e roleta de prêmio com itens elegíveis.

Fila M31 e aceite em
[`REFINAMENTO_RARIDADES_2026-10-11.md`](REFINAMENTO_RARIDADES_2026-10-11.md).
Código `8cf1334` no `main`, suíte completa verde, 48 capturas e cliques reais
conferidos. Oito módulos sincronizados seletivamente, 40 fontes comparadas,
preview com 4.433 peças. Publicado no place da equipe em **11/10/2026 às 16:47:04 local
(19:47:04 UTC)**, com `PublishSuccessful` confirmado; Studio em edição.
Galeria Desktop `Multiverse_Raridades_2026-10-11/INDICE.html`.

## 24. Retenção, aceites de lançamento e combate — 11/10

Fila M32 e relatório em
[`RETENCAO_LANCAMENTO_2026-10-11.md`](RETENCAO_LANCAMENTO_2026-10-11.md).
Analytics corrigido e tempos por sessão/coorte; próximo objetivo calculado
pelo servidor, baú gratuito prioritário no guia e objetivo no resultado.
Avisos 3D inteiros com atualização por quadro; preparação/impacto/recuperação
por família de ataque e contornos dos modelos sem novas peças.

Código `fd58c0b` no `main`, suíte completa verde e 21 cenas no Studio.
Combate com cinco heróis/80–104 inimigos: 60 FPS, p95 até 18,28 ms em três
amostras de quatro segundos no PC. 12 módulos sincronizados seletivamente,
40 fontes comparadas e preview 4.433 peças. Publicado no mesmo lugar da
equipe em **11/10/2026 às 21:33:00 local (12/10 às 00:33:00 UTC)**,
`PublishSuccessful` confirmado; Studio em edição.

Auditoria atualizada: 26 produtos de heróis sem ID, temporada sem passe e
VIP fora de venda. Esses aceites, compras reais, celular físico, quatro
jogadores, sessão prolongada e D1/D7 seguem no
[`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md). Anatomia/peso do catálogo
completo continuam M22.7/M22.9. Galeria Desktop
`Multiverse_Retencao_2026-10-11/INDICE.html`.

## 25. Anatomia e preparação dos ataques — 11/10

Fila M33 e relatório em
[`REFINAMENTO_MODELOS_COMBATE_2026-10-11.md`](REFINAMENTO_MODELOS_COMBATE_2026-10-11.md).
Tronco, cintura, membros, mãos e pés refinados nos modelos existentes;
preparação com alvo válido, impacto/recuperação e emissão na pose atual.
Três fases de cinco heróis observadas em combate real do Studio. Dano,
recarga, preços e progressão preservados.

Figurinos/silhuetas por herói continuam M22.7; carga ativa e demais
assinaturas continuam M22.9/M33.5. As medições desta rodada foram invalidadas
pelo Studio em segundo plano e não comprovam 60 FPS. Galeria Desktop
`Multiverse_Modelos_Combate_2026-10-11/INDICE.html`; detalhes da revisão e
publicação no relatório.

Código `f636a9a` no main, suíte completa verde (87,38 s), 20 capturas de
interface sem corte de texto/erro detectado. Quatro módulos sincronizados,
40 fontes comparadas e lobby salvo com 4.481 peças. Publicado no place da
equipe em **11/10 às 23:42:32 local (12/10 02:42:32 UTC)**, com
`PublishSuccessful` confirmado; Studio em edição. Medição de carga ativa
e acabamento próprio dos figurinos permanecem abertos.

## Configuração comercial — 12/10/2026

Pedido explícito do dono: completar a loja, baratear as compras e configurar
a página no projeto oficial. Fila M34 e registro em
[CONFIGURACAO_COMERCIAL_2026-10-12.md](CONFIGURACAO_COMERCIAL_2026-10-12.md).
Todos os 41 produtos de herói, cinco passes e cinco pacotes cadastrados;
heróis 9/29/79 Robux, passes 19–49, pacotes 5–79, com cotação regional no
cliente. VIP ativado, Temporada criada. Página localizada e recomendação
permitida; identidade/2FA e requisitos de ampliação continuam pessoais.
As referências anteriores a VIP fora de venda, Temporada sem ID e 26
produtos faltantes são históricas e foram resolvidas neste lote.

Código `b089b43` publicado no mesmo place em 12/10/2026 às 14:12:16 local
(17:12:16 UTC), `PublishSuccessful` confirmado; suíte completa verde,
40 fontes comparadas e 14 capturas finais. Shop nativo publicado com os
51 itens listados em quatro categorias. Depois, o Studio perdeu acesso
com RCC-273; ícones externos individuais ficaram pendentes e o Studio
terminou na Home. A publicação anterior foi confirmada antes desse erro.
