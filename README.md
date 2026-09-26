# Vingadores: Doomsday — Última Defesa

Tower defense cooperativo para Roblox com heróis dos Vingadores, construído
inteiramente em Luau autoral — nenhum asset da Toolbox; mapas, heróis,
inimigos e efeitos são gerados por código. Documentação relacionada:
[docs/GAME_DESIGN.md](docs/GAME_DESIGN.md) (como o jogo funciona hoje),
[docs/HEROES.md](docs/HEROES.md) (referência gerada de heróis/habilidades),
[docs/BALANCE.md](docs/BALANCE.md) (como o balanceamento é medido),
[IMPLEMENTATION.md](IMPLEMENTATION.md) (contrato cliente/servidor),
[CONTRIBUTING.md](CONTRIBUTING.md) (trabalhando em dupla neste repositório),
[docs/PUBLISHING.md](docs/PUBLISHING.md) (publicar no GitHub e no Roblox).

## Rodando agora

**Expansão 2026.4:** 36 heróis, 11 bases equipáveis, cinco tipos de baú para
heróis e cinco para bases. Abra **Heróis → Minhas bases** no lobby e toque
em **BASE / EVOLUIR** durante a partida. A renda da fazenda e as melhorias
usam Energia; os baús usam Ouro. [Guia de bases e baús](docs/BASES.md).

```bash
python tools/setup_luau.py   # uma vez: baixa o Luau oficial e confere o SHA256
python tools/build.py        # gera dist/Doomsday-{Studio,Lobby,Match}.rbxlx
python tools/test.py         # compila, roda a suíte inteira, gera os lugares
```

Abra `dist/Doomsday-Studio.rbxlx` no Roblox Studio e aperte **Play** — cliente
e servidor rodam no mesmo processo Standalone, perfis ficam em memória e
compras ficam desativadas (não há como testar Robux fora de uma experiência
publicada). Detalhes de publicação real em
[docs/PUBLISHING.md](docs/PUBLISHING.md).

## Estado atual (resumo; detalhes em docs/GAME_DESIGN.md)

- **Combate visual:** poses de ataque nos 24 heróis, disparos nas armas,
  pedestais circulares, mapas mais claros, estados dos inimigos e avisos
  de chefes que acompanham a área real de perigo.
- **Áudio e implantação:** [25 áudios originais](assets/audio/README.md),
  música/efeitos com controles separados e [gerador de publicação](docs/DEPLOYMENT.md)
  que aplica IDs da conta sem alterar os fontes. Uploads e testes publicados
  ainda dependem da configuração proprietária.

- **Loja de baús:** as exposições físicas de heróis saíram do lobby.
  Pisar no verde diante do Raro ou Lendário abre sua loja; o menu mostra
  saldo, retratos, chances e confirmação antes de gastar Ouro. Fechar
  enquanto está sobre a área não reabre o menu repetidamente.
  Progresso e pendências de lançamento: [docs/PRODUCTION_STATUS.md](docs/PRODUCTION_STATUS.md).

- **36 heróis**, 5 raridades. Um herói só chega à conta por um dos **5 baús de heróis**
  do lobby (400 a 5.000 Ouro; Lendário: 2.000 Ouro, com garantia após 10
  aberturas sem lendário/mítico) ou pela compra direta na Loja Robux —
  **nunca** por Ouro direto. Em combate, a habilidade ativa é sempre a do
  herói no **slot 1** da formação, visualmente diferenciado, porque é o
  único slot que decide o que o botão de habilidade no canto da tela faz.
  Habilidades **lendárias e míticas são ultimates**: disparam o efeito
  principal mais um ou mais efeitos secundários no mesmo cast, com um pilar
  de luz e ondas de choque próprios na tela.
- **4 modos** nos portais do lobby — Campanha, Ranqueado, Cartas, Infinito —
  todos com **50 ondas** (exceto Infinito) e chefe a cada 10 (final na 50);
  o servidor **sorteia o mapa** entre os 5 disponíveis a cada partida. O
  modo Difícil, o desafio diário e a investida de chefes foram removidos.
- **Árvore de evolução de conta** (não física, tela no HUD) com 3 ramos e
  redistribuição gratuita.
- **4 laços de retorno diário** (baú grátis, sequência de login, presentes
  por tempo jogado, metas de coleção), decididos pelo relógio do servidor,
  nenhum comprável.
- Persistência versionada, sessão exclusiva por conta, `ProcessReceipt`
  idempotente, placares `OrderedDataStore` por mapa/tamanho/temporada,
  reconexão com vaga guardada.

O que ainda falta antes de lançar publicamente: testes em experiência
publicada (teleporte, servidor reservado, compras reais só existem lá), IDs
de produto/lugar/áudio, licenciamento Marvel, e playtests humanos de
balanceamento — a simulação automatizada mede o que um bot determinístico
consegue, não o que é divertido (veja `docs/BALANCE.md`).

---

## Histórico de iterações

As seções abaixo registram decisões e revisões anteriores, na ordem em que
foram escritas — mais recentes primeiro. Onde um número ou contrato diverge
do resumo acima, **o resumo acima e o código-fonte são a verdade atual**;
o que está abaixo é contexto histórico, não instrução para o estado do jogo.

## Interfaces: navegação e acabamento — 22/09/2026

- HUD do lobby com ícones próprios, indicação da categoria aberta e botão
  **JOGAR**. Ele abre os modos disponíveis, explica os bloqueios e inicia uma
  partida com mapa sorteado pelo servidor. Portais continuam disponíveis.
- Azul mais claro, bordas suaves, contraste maior e abertura animada breve,
  respeitando **Menos efeitos e flashes**. Referências e decisões em
  [docs/HUD_REFERENCES.md](docs/HUD_REFERENCES.md).
- Evolução mostra os pontos disponíveis também na navegação. Inventário,
  árvore, configurações, missões e lojas têm ações maiores para toque.
- Ouro e Energia identificados; combate mostra uso do limite de heróis,
  recarga do poder do líder, vida da base e orientação do chefe. A barra de
  heróis aproveita a largura disponível para retratos e nomes maiores.
- Menus adaptados a telas baixas preservam o fechamento e o cartão de saída
  do portal. Cartas têm mais espaço para descrição. Resultados mantêm
  **VOLTAR À BASE** fixo, fora da rolagem, e agrupam ondas, Ouro e XP no início.
- Validação automatizada: suíte completa aprovada; 6.313 verificações de
  layout e 1.494 de execução/navegação do cliente. Revisão visual no renderer
  do Studio com `tools/studio_hud_review.luau`, que usa estados simulados e
  bloqueia intenções de compra/progresso na cópia descartável de teste.
  Isso não substitui testes de toque e desempenho em aparelhos reais.

Reabra **dist/Doomsday-Studio.rbxlx** no Studio para carregar o HUD atualizado.

## Rotas visíveis e modo ranqueado — revisão atual

- Campanha começa diretamente com **50 ondas**, mesmo na primeira sessão.
  O portal não redireciona mais ao tutorial. O treinamento de oito ondas é
  opcional, em **Opções → Aprender a jogar**.
- Modos nos portais: **Campanha, Ranqueado, Cartas e Infinito**. Os três
  primeiros têm 50 ondas e chefes em 10/20/30/40/50. Infinito continua sem fim.
  Ranqueado e Cartas abrem após uma vitória na campanha; Infinito após vitória
  no Ranqueado. Vitórias antigas no Difícil preservam o acesso ao Infinito.
- Ranqueado substitui Difícil: melhor onda concluída determina o rank por
  mapa, tamanho de equipe e temporada. Iniciante: 0–9; Bronze: 10–19;
  Prata: 20–29; Ouro: 30–39; Diamante: 40–49; Lenda: 50. Empates compartilham
  posição. Placares persistentes separados do Infinito, com histórico.
  A versão competitiva passou a `2026.3`; registros antigos são preservados.
- Caminhos: zigue-zague de Manhattan; braços do reator Gama; corredores
  alternados da HYDRA; espiral de Wakanda; três entradas da Latvéria.
  Faixas coloridas e setas seguem os mesmos segmentos usados pela simulação.
- Corrigida a altura do terreno: o relevo gerado escondia o pavimento sob
  aproximadamente dois studs de solo. Agora o terreno encontra as ruas.
  Conferência real no Studio em `test-results/wakanda-route.png`.

Esta seção substitui as descrições anteriores de modo Difícil e tutorial
obrigatório. As rotas novas mudam a cobertura das torres: duração e dificuldade
ainda precisam de balanceamento em partidas humanas.

## Versão atual: recrutamento, líder e cartas — 21/09/2026

### Acabamento de navegação

- Direção infantil: painéis azuis mais claros, botões arredondados e textos
  curtos. A equipe aparece em cinco espaços com retratos e uma estrela no
  líder. Espaços vazios explicam como adicionar um herói possuído.
- A interface chama maestria de **nível do herói** e rank de **nível do poder**.
  As regras de progressão permanecem iguais. Ajuda de controles corrigida
  para **Q: poder do líder**; não oferece mais uma segunda ativa inexistente.
- Captura real desta revisão: `test-results/friendly-inventory.png`.
  Inventário, herói, baús e loja Robux abriram no Studio sem texto excedendo
  seus limites na janela medida. Isso não substitui testes em aparelhos.

- Inventário em galeria responsiva: retratos 3D, raridade, maestria, slot e
  destaque dourado do líder. Filtros **Meus heróis** e **Todos** permitem
  consultar a coleção completa sem confundir heróis possuídos com bloqueados.
- Baús raro e lendário têm abas próprias, mantendo as chances individuais
  na página do baú selecionado. Loja Robux: abas **Heróis**, **Passes**, **Ouro**.
- Tela de habilidade mostra a próxima melhoria antes da lista de ranks,
  informa falta de Ouro/maestria e apresenta cinco marcadores de progresso.
  Um botão leva de volta ao inventário.
- Navegação executada nos testes do cliente em seis resoluções, incluindo
  celular em retrato e paisagem: 1.242 verificações sem falhas.
- Verificação adicional no Studio: inventário, habilidade, baús e loja Robux
  abriram sem textos excedendo seus limites na janela testada. Captura em
  `test-results/navigation-studio.png`; o cabeçalho do inventário foi
  compactado após essa captura para antecipar a galeria.

Abra `dist/Doomsday-Studio.rbxlx` no Roblox Studio e pressione **Play**.
Se o arquivo já estava aberto, reabra-o para carregar esta compilação.
Os arquivos anteriores foram preservados em `.tools/backup-before-chests-*`.

- **36 heróis**, cada um com habilidade própria e cinco ranks de evolução.
- **Baú raro: 1.000 Ouro; lendário: 2.000 Ouro.** A tela informa chances
  individuais, prioridade para heróis ainda não possuídos e a garantia do
  lendário. Repetidos concedem Ouro e maestria. Tutorial: 1.000 Ouro na
  primeira conclusão, suficiente para um baú raro.
- **Heróis / Evolução / Baús / Robux** acessíveis pelo HUD do lobby. Inventário
  permanece aberto enquanto o jogador caminha. Primeiro slot destacado em
  dourado; **Usar como líder** define a única habilidade ativa da partida.
  Melhorias da habilidade exigem Ouro e maestria; talentos de conta usam os
  pontos recebidos por nível. Árvore de talentos é uma tela, sem pedestal.
- Loja Robux separada: heróis diretos, passes e pacotes. Preços vêm da
  plataforma quando os IDs estiverem configurados; produtos sem ID ficam
  indisponíveis. Restrições de itens aleatórios são verificadas no servidor.
- **Normal, difícil, cartas e infinito**, com escolha aleatória entre os cinco
  mapas ao partir. Normal/difícil/cartas: 50 ondas; chefes em 10/20/30/40/50,
  com chefe final reforçado. Cartas: escolha a cada cinco ondas concluídas
  antes do final (nove escolhas). Infinito não tem última onda. Tutorial
  continua curto, com oito ondas. Desafio diário e investida foram retirados.
- Baús com ilustração e cores próprias, retratos 3D no inventário e lojas,
  cartas com acabamento por raridade e efeitos de habilidade por categoria.
  A floresta e os demais trabalhos offline foram mantidos.

**Verificação desta revisão:** compilação; regras; persistência/recibos;
partidas; portais; mundo; cliente em seis resoluções; integração de servidor
solo/reconexão/dupla; geração dos três arquivos nativos. Todos passaram.
Coleta manual e drone deram 1.380 Ouro na mesma simulação de derrota.
O agente de teste venceu 50 ondas no modo cartas em 49,2 min; no normal chegou
à onda final em 43 min e perdeu. Balanceamento de duração/dificuldade, compras
reais, multiplayer publicado e desempenho mobile ainda exigem playtests.

O Studio também iniciou uma cópia descartável e confirmou a abertura da loja
(`DOOM_CHEST_REVIEW_READY`) sem erro de script do jogo. A captura local ficou
em branco; essa execução não constitui aprovação visual da interface.

As seções abaixo registram etapas anteriores; números e contratos antigos
que divergirem desta seção foram substituídos. Contratos atuais em
`IMPLEMENTATION.md`.


## Bosque da Aurora — expansão do lobby

O lobby agora ocupa uma ilha de aproximadamente 340 × 310 studs, com a praça
dos cinco portais preservada no centro. Uma floresta de mais de 40 árvores,
arbustos e flores cerca trilhas de pedra e areia. Os destinos são a Árvore da
Aurora (copa dourada, coração azul e raízes escaláveis), acampamento, mirante
com cachoeira e sete pedras de salto. Não há recompensas econômicas nesses
elementos de exploração.

A árvore tem copa em camadas, relevos no tronco e lanternas suspensas. Um arco
de madeira com vegetação marca a entrada do bosque, bancos têm encostos e o
mirante recebeu corrimão. Doze pontos de luz animados localmente acompanham a
área da árvore; a opção de reduzir efeitos desliga seu movimento.

A ilha tem chão com colisão, bordas rochosas e três camadas de penhasco. Toda a
geometria pertence ao modelo do lobby e fica fora da área de combate. O spawn
e os portais mantêm suas posições para preservar o acesso às partidas. A
cachoeira é cenográfica; não há simulação de correnteza. Desempenho em celular
ainda exige medição no aparelho.

## Direção de arte — revisão do lobby

A central recebeu uma nova composição: piso claro com placas e juntas,
passarela azul-marinho, estrutura metálica, anéis dimensionais com camadas,
reator orbital, vegetação, letreiros físicos e expositores próprios para heróis
e suprimentos. Os materiais texturizados desta versão são nativos do Roblox
(Concrete, Metal, DiamondPlate, Slate e LeafyGrass); não são texturas PBR
personalizadas importadas.

O bloqueio de conteúdo não cobre mais a geometria com caixas escuras. A árvore
ganhou emblemas vetoriais e indicadores de ranks. Os mapas usam novos anéis de
invasão e um núcleo esférico. A captura real da primeira revisão do lobby está
em `test-results/art-lobby.png`; pequenos ajustes posteriores de expositores e
altura do letreiro estão no arquivo gerado.

Esta é uma revisão de arte do protótipo, **não uma aprovação para publicação**.
Modelagem final dos personagens, animação autoral, texturas próprias, efeitos e
composição dos cinco mapas ainda precisam de acabamento e revisão visual.

## Árvore de evolução — 21/09/2026

- Cada nível de conta acima do primeiro concede **1 ponto**, até 49 no nível 50.
  Contas existentes recebem o orçamento correspondente ao nível já conquistado.
- Abra a árvore clicando no indicador de Ouro/nível, em **Equipe** ou em um
  pedestal de habilidade. Fortuna, Guardião e Comando têm nove talentos com
  pré-requisitos, ranks e redistribuição gratuita com confirmação no lobby.
- Há bônus reais de Ouro por onda, Ouro por eliminação, recompensa de vitória,
  vida da base, reparos, barreira, Energia inicial, dano e recarga.
  Em grupo, vida e reparos usam o maior bônus, sem somar quatro jogadores.
- A tela final mostra evolução de nível e pontos conquistados. Talentos são
  persistidos pelo servidor; cliques repetidos não gastam pontos adicionais.
- Sons curtos nativos do Roblox dão retorno de coleta, construção, evolução e
  resultado. `Config.BuiltinCues` configura esses retornos; música e uma direção
  sonora original ainda dependem de áudio próprio importado na experiência.
- A versão de balanceamento passou a `2026.2`, separando os novos placares.

## Atualização visual — 21/09/2026

- Os 12 heróis têm corpos articulados, poses, paletas, máscaras e equipamento
  próprios. Galeria, torres e retratos usam a mesma geometria autoral.
- Cartões da equipe e painéis contextuais mostram retratos 3D em `ViewportFrame`,
  com custo, espaços vazios e recarga legíveis. O lobby continua físico.
- Relâmpagos de Thor, teias, flechas, escudo, magia e repulsores têm efeitos
  distintos. Moedas confirmadas voam até o comandante; inimigos têm dissolução
  curta e animação corrigida, com limites de objetos e opção de menos efeitos.
- A câmera inicia as partidas mais alta, mantendo os controles normais de zoom
  e rotação. A iluminação noturna recebeu preenchimento para revelar os modelos.
- Corrigido um bloqueio real de inicialização: `Lighting.Technology` não pode
  ser escrito por scripts de jogo. `Future` agora é definido no arquivo `.rbxlx`
  e nos manifestos Rojo, sem essa escrita durante a construção do cenário.

**Abra novamente o arquivo gerado:** uma aba antiga do Studio mantém os scripts
que carregou antes. Rode `python tools/build.py` e abra `dist/Doomsday-Studio.rbxlx`
para testar estas mudanças. Não sobrescreva o projeto gerado com uma aba antiga.

Validação desta atualização: suíte automatizada completa aprovada; construção
real de Manhattan e dos 12 heróis executada no Studio, com captura em
`test-results/visual-review.png`. Isso não substitui teste de FPS em celular,
compras reais ou teleporte publicado.

Tower Defense cooperativo para Roblox: heróis dos Vingadores, invasão zumbi,
progressão de conta persistente e monetização por conveniência.

Estado atual: **a partida completa roda de ponta a ponta** — lobby, grupo,
tutorial, 30 ondas, chefes, protocolos de batalha, economia, perfil salvo,
compras e placares. O código é todo autoral e não depende de nenhum asset da
Toolbox: cenários, heróis e inimigos são construídos por script.

---

## 1. Como rodar agora (5 minutos, sem instalar nada além do Python)

```bash
python tools/build.py
```

Isso gera três lugares prontos em `dist/`:

| Arquivo | Papel | Uso |
| --- | --- | --- |
| `Doomsday-Studio.rbxlx` | `Standalone` | Abrir no Studio e apertar Play. Lobby e partida no mesmo servidor. |
| `Doomsday-Lobby.rbxlx` | `Lobby` | Vira o lugar inicial da experiência publicada. |
| `Doomsday-Match.rbxlx` | `Match` | Vira o segundo lugar, recebe servidores reservados. |

Abra `dist/Doomsday-Studio.rbxlx` no Roblox Studio e aperte **Play**. Você cai no
helicarrier e vê um hub físico, não um menu: portais de modo, galeria de
heróis, sala de treinamento, loja, quadro de missões e totem de placar, cada
um no seu próprio lugar. Aproxime-se de qualquer um, aperte E, e um painel
pequeno e contextual abre só com o que aquele local oferece.

No Studio os perfis ficam em memória (`Config.StudioMemory`), as compras ficam
desativadas e o teleporte é ignorado — por isso o servidor entra em modo
`Standalone` sozinho e a partida acontece ali mesmo.

### Alternativa com Rojo

Se você já usa Rojo, os três manifestos estão prontos:

```bash
rojo serve default.project.json
```

`lobby.project.json` e `match.project.json` marcam o atributo `DoomRole` do
Workspace, que é o que o bootstrap lê para decidir o comportamento do servidor.

---

## 2. Publicar de verdade

1. Crie a experiência e **dois lugares** na sua conta.
2. Suba `Doomsday-Lobby.rbxlx` no lugar inicial e `Doomsday-Match.rbxlx` no segundo.
3. Abra `src/shared/Config.luau` e preencha:
   - `LobbyPlaceId` e `MatchPlaceId` com os IDs reais;
   - `Products.Passes.*.id` com os IDs dos Game Passes;
   - `Products.Consumables.*.id` com os IDs dos Developer Products.
4. Rode `python tools/build.py` de novo e suba os lugares atualizados.

Enquanto um ID estiver em `0`, o produto aparece na loja como **indisponível** e
não pode ser comprado — falha fechada, nunca uma compra sem entrega.

Enquanto `LobbyPlaceId` ou `MatchPlaceId` estiver em `0`, qualquer servidor roda
em `Standalone`. Isso é proposital: nenhum jogador fica preso em um lugar sem
destino configurado.

> Teleporte, servidor reservado e o fluxo entre lugares **não funcionam** no
> playtest do Studio. Esse trecho só pode ser aceito em uma experiência
> publicada, aberta pelo aplicativo do Roblox.

### Direitos de uso

Personagens, nomes e marcas Marvel pertencem a seus detentores. Este repositório
usa apenas arte e texto autorais; a liberação comercial depende de resolver o
licenciamento antes da publicação pública.

---

## 3. Estrutura

```
src/shared/     Catalog (dados), Config (IDs e ambiente), Rules, Waves
src/server/     init.server (bootstrap e roteador), MatchService, PlayerService,
                PartyService, PresenceService, AnalyticsService, RejoinService,
                WorldBuilder
src/client/     init.client (controlador), UI, Effects, Audio, Nameplates
tools/          build.py, test.py, setup_luau.py, studio_bridge.py
tests/          boot real do servidor e do cliente, layout em 22 telas,
                PlayerService e PartyService com dublês, construção do mundo,
                partida simulada inteira e contrato cliente/servidor
IMPLEMENTATION.md  contrato entre os módulos (leia antes de editar)
```

Regra de ouro do projeto: **o cliente envia intenção, o servidor decide**.
Custo, propriedade, alcance, saldo, recarga, dano e recompensa nunca são
calculados no cliente. Pedido inválido é recusado sem alterar estado.

---

## 4. O que está pronto

- **Lobby diegético, sem menu para jogar**: o mundo abre sem HUD cobrindo a
  tela (só um indicador pequeno de Ouro/nível e os botões EQUIPE e OPÇÕES).
  Os cinco portais de modo são **elevadores**: você entra, um contador de 8 s
  começa, quem entrar junto vai no mesmo grupo (até 4) e a partida começa
  sozinha. Para quem nunca jogou, o portal da campanha roda o treinamento e um
  sinal "COMECE AQUI" aponta para ele. Galeria com um pedestal por herói, sala
  de treinamento com um console por habilidade, um estande por produto da
  loja, quadro de missões e totem de placar — 29 locais interativos, cada um
  abrindo só o painel pequeno daquela função. O porta-aviões voa sobre um
  oceano, com rotores girando, jatos no convés e radar.
- **Mapas completos**: cada capítulo é um lugar — ruas com asfalto, calçada,
  meio-fio e faixa central, postes com luz, avenida em volta com carros,
  praças/estacionamentos/quadras/helipontos, e uma muralha contínua de prédios
  com lojas e janelas acesas. Manhattan (cidade à noite), Gama (laboratório),
  HYDRA (pátio industrial com contêineres), Wakanda (savana e torres de
  vibranium) e Latvéria (fortaleza na neve). Nada disso ocupa espaço onde uma
  torre pode ser construída (testado).
- **Upgrades visíveis**: cada torre sua mostra no mundo um botão "⬆ NV3 350⚡"
  (verde quando dá para pagar); no nível 4 ele vira "★ EVOLUIR" e abre a
  escolha de especialização. Bloqueio e propriedade (portal fechado, herói não comprado,
  habilidade sem nível) são cosméticos por jogador, aplicados no cliente sobre
  a mesma geometria compartilhada; a validação real continua só no servidor.
- **Combate**: 12 heróis com 5 níveis e 2 especializações finais, 8 famílias de
  inimigos, 5 chefes com fases e telegrafia, 4 prioridades de alvo, venda com
  70% de devolução, limite de torres por tamanho de grupo.
- **Partida**: 30 ondas, minichefes em 10 e 20, 20 s de preparação com início
  antecipado por unanimidade, aviso de ameaças antes da onda, Protocolos de
  Batalha nas ondas 5/10/15/20/25.
- **Modos**: tutorial, campanha, difícil, infinito, desafio diário e investida
  de chefes, com os desbloqueios encadeados.
- **Economia**: Ouro persistente e Energia por partida, moedas pessoais com
  coleta manual ou por drone, entrega do Ouro não coletado ao fim da partida,
  recompensa por contribuição (dano, controle e suporte contam).
- **Progressão**: nível 1–50, maestria 1–20 por herói, habilidades ativas e
  passivas com limites de bônus, missões diárias e semanais, conquistas.
- **Persistência**: perfil versionado com sessão exclusiva, gravação atômica,
  concessão única por recibo e por checkpoint, falha de leitura nunca
  sobrescreve dados existentes.
- **Monetização**: 4 passes e 3 pacotes de Ouro, `ProcessReceipt` com registro
  durável antes da confirmação, preço consultado na plataforma.
- **Placares**: `OrderedDataStore` separado por mapa, tamanho de grupo,
  temporada e versão de balanceamento; empates compartilham posição.
- **Grupo e viagem**: código de 4 caracteres no lobby, líder inicia, servidor
  reservado por partida, reconexão com vaga guardada por 2 minutos.
- **Interface**: português e inglês; cada HUD é calculado em pixels a partir
  da tela utilizável real, com um arranjo próprio para celular deitado (o
  padrão do Roblox), tablet, desktop e retrato; "menos efeitos e flashes",
  movimento de câmera e som opcionais.
- **Identidade**: títulos conquistados por campanha, temporada e VIP, exibidos
  acima do comandante no idioma de quem olha; trilha VIP visível para todos;
  drone coletor com aparência própria para quem tem o passe.
- **Retorno visual**: uma invasão que chega ao núcleo produz impacto, tremor,
  som e aviso de núcleo crítico, em vez de apenas mover a barra.
- **Iluminação e materiais por capítulo**: `Lighting.Technology = Future`,
  `Atmosphere`, `Bloom`, `ColorCorrection` e `SunRays` com uma paleta própria
  por mapa (Manhattan noturna azulada, Gama esverdeada radioativa, HYDRA
  industrial cinza/vermelho, Wakanda púrpura/dourada, Latvéria fria e
  arroxeada), só com materiais nativos do Roblox. `DepthOfField` fica ligado
  só no lobby — durante a partida a leitura do campo de batalha vem antes da
  estética. Cerca de 1 em cada 5 prédios do horizonte aparece parcialmente
  destruído, com escombros no chão.
- **Combate mais legível**: torres recuam visivelmente a cada disparo, os
  infectados caminham com balanço procedural nas pernas (desligado em
  `lowFX`), e números de dano flutuantes aparecem lendo a vida que o
  `EnemySync` já envia — nenhum evento de rede novo por acerto.
- **Orçamento de celular**: `CastShadow` é `false` por padrão em tudo que o
  `WorldBuilder` constrói, ligado de volta só nos poucos marcos grandes
  (casco do helicarrier, ponte de comando, prédios do horizonte). Toques nos
  painéis contextuais têm pelo menos 36–40px de altura.
- **Partículas e chefes**: `ParticleEmitter` só nos marcos que aparecem uma
  vez — portais inimigos, núcleo e os cinco portais do lobby —, nunca por
  inimigo ou por torre. Os cinco chefes têm silhueta própria (cauda e crista
  do Lagarto, espinhos do Abominável, capote da Caveira Vermelha, máscara
  dourada de Killmonger, capuz e placa facial de Destino) em vez de serem um
  infectado ampliado.
- **Telegrafia de chefe**: além do aviso em texto, um anel âmbar marca no chão
  a área do poder que vem, e dura exatamente os 2 segundos de reação.
- **O painel pertence ao lugar**: andar mais de 26 studs para longe do
  pedestal fecha o painel que ele abriu.
- **Heróis que miram**: a cada disparo o herói gira para encarar o alvo (só a
  figura; a plataforma, o anel e os marcadores do servidor ficam parados).
- **Áreas desenhadas como são**: splash, habilidades de área e o aviso do
  chefe são discos, porque toda área do jogo é um raio — o quadrado de antes
  marcava perigo nos cantos, onde não havia.
- **Vitrine viva e quadro pessoal**: o drone coletor gira na vitrine da loja,
  e o quadro de missões mostra para cada jogador, legível de longe, se há
  recompensa esperando ("1 PRONTA PARA RESGATAR") ou quantas estão em
  andamento.
- **Áudio**: sinais nativos de coleta, posicionamento, invasão, evolução,
  vitória e derrota em `Config.BuiltinCues`. IDs próprios em `Config.Audio`
  substituem esses sinais; música permanece silenciosa até ser configurada.
- **Telemetria**: funil do tutorial, progressão por onda, duração da partida,
  Ouro por minuto, economia de Ouro com origem e destino, composições usadas e
  tempo até desbloquear cada herói.
- **Reconexão**: quem cai no meio da batalha volta ao mesmo servidor reservado
  enquanto a vaga estiver guardada, usando MemoryStore.

## 5. O que ainda falta para lançar

| Item | Por quê |
| --- | --- |
| Testes em experiência publicada | Teleporte, servidor reservado e compras reais só existem fora do Studio. |
| IDs de produtos e lugares | Dependem da conta proprietária. |
| IDs de áudio | O sistema de som está pronto; `Config.Audio` continua zerado até existirem trilhas licenciadas. |
| Licenciamento Marvel | Requisito legal anterior à publicação comercial. |
| Ajuste fino de balanceamento | Os números atuais são os valores iniciais do documento de design. |

---

## 6. Testes

```bash
python tools/setup_luau.py   # uma vez: baixa o Luau oficial e confere o SHA256
python tools/test.py
```

O que a suíte cobre hoje, e passa:

- compilação de todos os `.luau` com o compilador Luau oficial;
- ~438 mil asserções sobre catálogo, progressão, especializações, portões de
  desbloqueio, economia das ondas, todos os mapas/modos/tamanhos de grupo e
  sorteio de protocolos;
- 80 asserções executando o `PlayerService` real contra dublês determinísticos
  de DataStore e MarketplaceService: recibo repetido concede uma vez só, falha
  de gravação não confirma compra, carregamento com falha não apaga perfil;
- **~5.600 verificações de layout** em 22 telas reais — celulares deitados
  (o padrão do Roblox, `LandscapeSensor`), tablets, desktops e retrato como
  alvo secundário —, já descontando a barra do Roblox e a área segura. Para o
  HUD de partida, o do lobby, o painel da torre e o seletor de protocolo:
  nada do que aparece junto se sobrepõe, nada sai da tela, e todo controle de
  toque tem altura de polegar. Esse teste reproduz o painel da torre que
  começava 168px acima de uma tela de celular deitado, com o botão MELHORAR
  fora dela;
- **o servidor é executado de verdade**: 227 verificações sobem o
  `init.server.luau` real — com `PlayerService`, `MatchService`,
  `WorldBuilder`, `PartyService` e o resto — como servidor Standalone do
  Studio, num relógio simulado com um agendador cooperativo, e jogam por
  `Request` exatamente como um cliente: um novato entra, faz o tutorial
  inteiro até a vitória e **compra o primeiro herói com o Ouro do
  tutorial** (critério literal do documento de design); joga a campanha,
  coleta moedas andando até elas, cai e reconecta no meio da batalha, perde
  e **mantém o Ouro já ganho**; forma um duo, o parceiro reconecta; o
  limitador de taxa segura uma enxurrada; e o servidor desliga com a batalha
  em andamento. Qualquer aviso de pedido que o `pcall` do roteador teria
  engolido reprova. Foi esse teste que achou a prioridade de alvo quebrada:
  o cliente enviava `"first"` e o servidor só aceitava `"First"`, então o
  botão **Alvo** nunca funcionou;
- **o cliente é executado de verdade**: 738 verificações sobem o
  `init.client.luau` real contra dublês do Roblox em seis telas, sincronizam,
  abrem cada um dos 34 painéis do lobby, compram e equipam por eles, jogam o
  HUD de partida (atalhos, posicionar, os quatro estados do painel da torre,
  habilidade, protocolo, chefe), disparam todos os eventos de FX, passam por
  resultados, trocam de idioma e giram a tela. Qualquer erro de Lua reprova —
  inclusive os que o compilador aceita. Foi esse teste que achou a loja
  recriando o próprio painel a cada 1,3s enquanto ficava aberta;
- 53 asserções sobre o `PartyService` real: código de 4 caracteres único por
  servidor, entrada sem diferenciar maiúsculas nem espaços, grupo cheio e
  grupo trancado recusam, liderança passa para quem ficou, membro desconectado
  não viaja, e — o que mais importa — o código morre junto com o grupo, então
  um código velho nunca puxa um estranho para a partida reservada de alguém;
- **uma partida inteira jogada de verdade**, fora do Roblox: o `MatchService`
  real roda contra dublês, o robô procura terreno válido, constrói, melhora e
  atravessa as 30 ondas. Verifica vitória, derrota com o núcleo desprotegido,
  venda com 70%, recusa de construir na rota, herói não equipado, teto de
  inimigos, energia nunca negativa, ondas só avançando e o placar do Infinito;
- 16 testes de contrato entre cliente e servidor: os valores de prioridade de alvo são idênticos nos dois lados, toda ação enviada pelo cliente
  chega a um ramo do roteador, todo evento visual emitido é tratado, ações de
  lobby continuam bloqueadas durante a partida, o desligamento drena as
  recompensas antes de liberar os perfis, todo passe vendido é lido por algum
  módulo, nenhum ID de asset fica embutido fora do `Config` e o código do
  servidor reservado nunca viaja junto com o jogador;
- 121 verificações construindo o mundo de verdade fora do Roblox: os 34 locais
  físicos do lobby com seus atributos, um pedestal por herói e um console por
  habilidade, um mood de iluminação distinto por capítulo, sombra desligada em
  tudo que é pequeno, partículas só nos marcos, e as duas especializações
  finais de cada torre visivelmente diferentes uma da outra;
- integridade dos três lugares gerados: cada fonte embutida exatamente uma vez,
  scripts habilitados, atributo de papel correto, artefatos determinísticos.

O que **não** é coberto por automação e precisa de teste manual publicado:
teleporte entre lugares, servidores reservados, compras reais em Robux,
desempenho em celular, controles de toque e áudio. Os testes de layout e de
boot do cliente conferem geometria e execução, não aparência: provam que nada
se sobrepõe, nada sai da tela e nada quebra, não que está bonito.

---

## 7. Balanceamento medido

Números de uma campanha completa em Manhattan, medidos pela simulação
(`python tests/test_match_simulation.py`):

| | Medido | Alvo do plano |
| --- | --- | --- |
| Tutorial | 7,4 min, núcleo 100/100 | 5–8 min |
| Campanha (30 ondas) | 36,6 min, vitória com núcleo 100/100 | 25–35 min |
| Ouro da primeira vitória | 1.500 | 1.000 + 500 de primeira vez |
| Pico de inimigos | 67 | teto de 180 |

A primeira medição deu **46,8 min**. A rota de Manhattan tem 418 studs e os
infectados andavam a 5,8 studs/s: só a travessia custava 72 s por onda.

A correção foi uma compressão de tempo neutra em dificuldade — inimigos 35%
mais rápidos com 26% menos vida (chefes 18% / 15%). O dano que um inimigo
recebe atravessando a rota é idêntico, então a dificuldade não mudou: a
campanha termina com o núcleo em 100/100 nos dois casos. Só a preparação entre
ondas mudou de fato, de 20 s para 14 s — 30 ondas a 20 s eram 10 min parados,
um terço da sessão.

Tentei antes encurtar as rotas em 30%: virou injogável, com derrota na onda 9.
Está registrado aqui porque é o tipo de ajuste que parece inofensivo e não é.

Faltam 1,6 min para o alvo. A simulação nunca usa o voto de "pronto", então ela
mede a sessão mais lenta possível; um grupo que pula parte da preparação fica
perto de 30 min. Fechar o resto exige playtest com gente de verdade, não um robô.

## 8. Marcos

| Etapa | Situação |
| --- | --- |
| 1. Partida funcional | Concluída |
| 2. Progressão e salvamento | Concluída |
| 3. Conteúdo completo (5 mapas, 12 heróis, 5 modos, placares) | Concluída |
| 4. Monetização e acabamento | Código concluído; falta validar compras publicadas e desempenho em celular |
| 5. Lançamento controlado | Pendente: depende de publicar e testar |
