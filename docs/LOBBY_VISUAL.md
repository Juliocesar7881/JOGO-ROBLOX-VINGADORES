# Lobby — revisão visual

## Base dos Heróis — 27/09/2026

O lobby foi refeito do zero no estilo das capturas do Toilet Tower Defense
enviadas pelo proprietário (ver `docs/ART_DIRECTION.md`, "Lobby"). O convés
do Helicarrier, o bosque da Aurora, a vila e os distritos deram lugar a uma
ilha tropical dos Vingadores/S.H.I.E.L.D. com centro em `(0, 480)` — bem ao
norte do quadrado das partidas, para que num servidor único a cidade da
batalha apareça do outro lado do mar, e não colada nos portais.

- **Praça dos heróis** (spawn): plataforma elevada sobre um fosso de água,
  estrela dourada com anel de luz, cerca de vidro aceso no cais, quatro
  pontes com portais iluminados (CAMPANHA, ARENA, ZONA AFK, TORRE • LOJA),
  anel viário em volta. Farol com a Terra holográfica girando entre duas
  órbitas e o parkour de sete pedras. Estátuas coloridas do Homem de Ferro e
  do Capitão América em pedestais dourados com placa. Sete balcões (guia com
  o Nico, mapas, equipe, bases, academia, missões e salão da fama), cada um
  com um ícone grande flutuando.
- **Áreas no anel**: terraço da campanha com os três destinos (sul), arena
  com placar elevado e refletores (leste), zona AFK com palmeiras (oeste),
  dois salões de invocação com baú flutuante (noroeste), torre dos
  Vingadores com a Loja Stark e a armadura em vitrine (norte), hangar com
  Quinjet, posto de comando com radar e arsenal com o SUV nos cantos.
- **Ilhas**: expedições (Wakanda com cristais, Asgard com arco dourado e
  caminho arco-íris), Latvéria (muralha, torres, chamas verdes) e a
  academia (treino e cartas). No céu, o Helicarrier com rotores girando e um
  Quinjet patrulhando a ilha; ao nordeste, o horizonte de uma cidade.
- **Heróis pela base**: Thor no arco de Asgard, Pantera Negra nos cristais de
  vibranium, Doutor Estranho na academia, Hulk na arena, Groot entre as
  palmeiras da zona AFK, Rocket nas caixas do hangar e Homem-Aranha no teto
  do posto de comando, cada um com o nome em cima.
- Cada destino é uma estação: deck de aço, três pads com moldura, portões
  acesos e o mini-diorama do mapa numa placa com moldura neon.

Contratos preservados: 11 destinos com 3 filas cada, dois salões de
invocação (agora girados para a praça; as zonas de compra são medidas no
próprio referencial do salão), cinco quiosques Robux, sete quadros, placar da
arena, duas câmaras AFK, campo de treino e parkour. As posições dos destinos
e das câmaras AFK no `Catalog` acompanham a ilha nova.

Verificação: `python tools/test.py` completo aprovado — mundo (4.833
verificações, incluindo cenário fora dos pisos e das pontes, cada estação
sobre o seu piso e zero faces sobrepostas), cliente (3.954 em 9 telas),
servidor (1.105) e simulação de partidas. O lobby tem 3.269 peças (orçamento
de 3.600) e 15 locais interativos. No Studio, o lobby foi montado no modo de edição e
percorrido num Play solo: jogador nasce na estrela, placas mostram os mapas,
globo, órbitas, rotores e Quinjet animam, sem erro de script no log. Um
problema real só apareceu no Play: estátuas ancoradas depois de posicionadas
ficavam na origem (o corpo liberado segue a raiz só no passo de física);
agora são montadas ancoradas e posicionadas por último.

Fotos dos mapas: as seis estão em `assets/map-photos/*.jpg` (a de Asgard foi
tirada nesta rodada). O Roblox ainda não permite criar imagens por script
(`AssetService:CreateAssetAsync` responde "not available yet"), então elas
entram pelo Gerenciador de ativos e `Config.MapImages`; até lá cada placa
mostra o diorama 3D do mapa. Fotografar Asgard revelou que o mapa nem
construía no Roblox (cor nula na trilha da rota) — corrigido, e os dublês de
teste agora recusam cor, tamanho, CFrame e material nulos.

Limites: desempenho e toque em celular real não foram medidos; o horizonte e
o Helicarrier são silhuetas simples.

## Refúgio da Aurora — revisão visual (substituída)

## Arquipélago e correção da rolagem — 25/09/2026

A correção anterior do painel não cobria a reconstrução da janela enquanto
o usuário estava rolando. Agora `ContextPanel` e `ContextBody` permanecem
vivos nas atualizações do mesmo painel, inclusive no recálculo do layout.
A substituição das linhas suspende a atualização do canvas vazio, evitando
que o Roblox reduza a área rolável e leve `CanvasPosition` a zero. O relógio
dos prêmios não reconstrói inventário/lojas; o indicador de prêmios continua
atualizando separadamente.

No renderer real do Studio, inventário, loja Robux, mapas, baús e prêmios
foram rolados até 370 pixels. Cada painel recebeu 12 mudanças de perfil,
além de uma reconstrução explícita de conteúdo: todos mantiveram o mesmo
ScrollingFrame e a posição 370. Os testes do cliente também verificam que
mudanças apenas no relógio dos prêmios preservam os cartões do inventário.

O lobby recebeu três áreas ligadas por pontes de madeira:

- Aldeia do Bosque: três cabanas de telhados diferentes, chaminés,
  jardineiras, poço, piquenique e bancos utilizáveis.
- Ilha dos Exploradores: percurso opcional de troncos, escadas e mirante.
- Jardim das Estrelas: lago ornamental, flores, observatório e telescópio.

Trilhas contornam a árvore central; placas e o guia em PT/EN indicam os
destinos. Serviços e portais permanecem concentrados na praça. A construção
final tem 3.216 peças, abaixo do orçamento de 3.500, e mantém os 15 pontos
de interação anteriores. As novas áreas são exploração livre, sem exigir
compra ou oferecer vantagens nas partidas.

Verificação automatizada: suíte completa aprovada antes do acabamento;
após as adições, testes de mundo (4.082 verificações) e cliente (3.348,
seis resoluções) aprovados novamente. Desempenho/toque em aparelhos reais,
compras publicadas e teleporte entre lugares continuam sendo validações
separadas. A arte desta entrega usa geometria e materiais do Roblox.

No Studio, o avatar atravessou as três pontes, subiu a escada do mirante e
entrou em uma cabana. A primeira travessia leste revelou uma pedra e uma
lanterna bloqueando o caminho: os obstáculos foram reposicionados/removidos,
e a repetição passou. Um teste automatizado de espaço livre protege agora
o corredor central das pontes contra árvores, pedras e postes da expansão.
Captura da aldeia em `test-results/lobby-village-review.png`.

## Destinos fixos, painéis e personagens — revisão anterior, 25/09/2026

Esta revisão substitui a escolha livre descrita na seção histórica abaixo.

| Portal | Mapa exclusivo | Regra |
|---|---|---|
| Campanha | Ruas de Manhattan | 50 ondas |
| Cartas | Complexo Gama | 50 ondas, cartas a cada cinco |
| Infinito | Ponte de Asgard | Até a derrota |
| Competitivo 1 | Instalação da HYDRA | Ranqueado, 50 ondas |
| Competitivo 2 | Fronteira de Wakanda | Ranqueado, 50 ondas |
| Competitivo 3 | Fortaleza da Latvéria | Ranqueado, 50 ondas |

Os três portais competitivos ficam juntos à direita da praça, em posições
distintas. Entrar na área inicia a contagem para até quatro jogadores.
Letreiros mostram mapa e modo; prédios, tanques, cristais e colunas diferenciam
as entradas. Jogar e o balcão da praça oferecem os mesmos destinos, com uma
ação direta. Não existe mais seleção aleatória nem troca de mapa pelo líder.
Os requisitos de desbloqueio permanecem e o treino é opcional, em oito ondas.

Asgard tem uma rota própria, paleta dourada, mármore, torres e iluminação
quente. A API valida cada combinação; enviar campos de outro mapa junto a um
destino não altera o que ele representa. Os placares mostram só os mapas do
modo selecionado. A conquista de campanha conta apenas destinos de campanha;
progresso histórico dos outros mapas é preservado.

Nos painéis, o tamanho rolável vem somente do conteúdo da lista. Foi removida
a combinação de medição automática com escala animada da janela. Atualizações
do perfil preservam a posição da rolagem. O teste repete 25 atualizações em
seis resoluções e verifica posição, altura e rolagem. No Studio, posição e
extensão do inventário permaneceram constantes durante a observação; a rolagem
continuou respondendo à interação. O relato original de descida contínua não
se reproduziu no primeiro teste parado, antes da correção preventiva.

Os 36 heróis compartilham a correção de geometria: braços/pernas contínuos,
tronco sólido, materiais lisos e cabeça com mesh esférica que preserva as
proporções. Retratos copiam essa mesh. Inimigos também usam torso e braços
contínuos. Rocket, Groot e outros mantêm a escala de personagem nas torres.
Não foram importados assets nem criadas exposições permanentes no lobby.

Capturas de revisão em `test-results/heroes-shapes-fixed.png`,
`test-results/heroes-inventory-fixed.png` e `test-results/lobby-fixed-destinations.png`.
Os bonecos alinhados na última captura são clones temporários de inspeção,
ausentes do build. Os testes de combate, mundo, perfis, portais e cliente são
executados com `python tools/test.py`; compras publicadas, teleporte real e
desempenho em celular seguem pendentes de validação externa.

Resultado final: suíte completa aprovada, incluindo 3.936 verificações de
mundo/modelos, 3.186 do cliente, 287 do bootstrap do servidor e 1.245 da
simulação de partidas. Os três arquivos `dist/Doomsday-*.rbxlx` foram regenerados.

## Histórico: escolha livre de mapas — substituída

Mapa e modo são escolhas separadas. O botão Jogar mostra o mapa selecionado;
tocar nele abre seis cartões: os cinco cenários e Aleatório. Cada cenário
mostra um desenho das rotas reais do catálogo. Escolher um cartão leva aos
modos Campanha, Cartas, Ranqueado e Infinito, com seus requisitos existentes.
O treino continua separado em Manhattan, com oito ondas.

O balcão Escolher mapa, na praça, abre a mesma galeria. Nos portais, o primeiro
jogador é o líder e usa o botão Mapa para escolher para todos. Abrir a galeria
concede uma única janela de até 20 segundos por grupo; confirmar retoma a
contagem curta. A escolha aparece no HUD de todos. Sair do portal transfere
a liderança ao próximo participante, preservando o destino. O servidor valida
líder, proximidade, identificador do grupo e mapa antes de aceitar a alteração.

Aleatório exclui o último mapa registrado para o líder naquele servidor.
Esse histórico é temporário e não persiste entre servidores. É possível
repetir qualquer mapa escolhendo seu cartão explicitamente.

Referência de organização: o [blog oficial do Toilet Tower Defense](https://blog.toilettowerdefense.com/og-event-update/)
descreve um lobby com mapas e dificuldades próprias. A implementação aqui usa
os cenários, desenhos e interface do projeto; não importa assets desse jogo.

Verificação automatizada: 189 verificações do serviço de portais, 2.772 do
cliente em seis resoluções, 3.457 do mundo e toda a suíte `python tools/test.py`
passaram. Incluem escolha explícita, sorteio, transferência de liderança,
pedidos inválidos e envio da seleção pelo HUD. Os três lugares foram gerados
novamente em `dist/`. O lobby agora tem 2.383 peças e 15 pontos interativos.
Teleporte publicado e uso em celulares reais continuam como validações externas.

No Studio, a galeria foi inspecionada no renderer. Um pedido de início pelo
cliente com `wakanda` + `normal` retornou sucesso; o estado do servidor confirmou
esse par e o HUD exibiu Fronteira de Wakanda / Campanha, com 50 ondas. Capturas
locais: `test-results/map-gallery.png` e `test-results/map-selected-wakanda.png`.
O código temporário que abria a galeria para inspeção foi removido após o teste.

## Continuação — 25/09/2026

O lobby ganhou quatro serviços físicos: Nico/guia, equipe, Academia e bases.
Todos abrem as telas reais existentes e usam a validação de proximidade do
servidor. Missões e placar foram movidos para a aproximação do bosque, voltados
para a praça; não é mais necessário passar por trás dos portais para encontrá-los.

O guia também está no HUD. Ele indica treino para iniciantes, talentos quando
há pontos disponíveis ou preparação da equipe, conforme o perfil. Seus oito
atalhos abrem jogar, equipe, bases, Academia, baús, missões, placares e opções.
Não concede recompensas nem altera o inventário por conta própria.

A vila agora tem um farol, balcões de madeira, molduras nas placas, Nico
modelado no cenário, três bancos com assentos utilizáveis, flores e acabamento
na praça. Bandeirolas e cristais têm movimento local; menos efeitos interrompe
essas animações. A câmera inicial enquadra os portais e o farol.

As placas principais e os quatro novos prompts alternam entre português e
inglês. Visitantes que caem abaixo da ilha retornam ao spawn com velocidade
zerada; participantes de partidas e jogadores em teleporte não entram nesse
processamento. A recuperação usa o loop existente de 0,25 segundo do lobby.

Verificação: testes reais dos módulos com dublês do Roblox cobrem os oito
atalhos nas seis resoluções, tradução de placas/prompts, distância dos 14
pontos de interação e recuperação de queda. A construção tem 2.369 peças,
abaixo do orçamento de 3.500. O guia e o cenário foram inspecionados no Studio.
Esta revisão não substitui testes de toque/desempenho em aparelhos reais,
nem valida compras e teleporte numa experiência publicada.

No Studio, a entrada no piso verde abriu a loja de baús de heróis e o teste
de queda retornou o avatar a aproximadamente `(0, 3.3, 345)`, com velocidade
vertical próxima de zero. Os suportes centrais que escondiam o texto dos
quadros foram substituídos por pés laterais.

## Entrega

- Praça de pedra com grama integrada, caminhos até portais e lojas, jardins,
  árvores na praça, fonte com cristal e pequena construção de vigia.
- Barracas com lonas listradas, madeira, caixas, lanternas e bandeirolas.
- Remoção das grandes vigas, piso de hangar, aeronaves e decoração de pista
  da montagem do lobby; floresta, cachoeira e portais preservados.
- Letreiros menores e iluminação mais quente.
- Menu inferior com ilustrações próprias de capacete, árvore de evolução,
  baú, moedas e presente. Os desenhos usam formas nativas da interface.
- Contador de Ouro com moeda ilustrada, cabeçalhos claros e cores de seção;
  fundos menos saturados e gradientes mais discretos.
- No celular em paisagem, a contagem do portal substitui temporariamente o
  menu inferior, mantendo o botão Sair e o conteúdo dos painéis acessíveis.

## Verificação

`python tools/test.py` passou após as alterações, incluindo 6.313 verificações
de layout, 2.358 do cliente, 3.443 de construção do mundo e 1.248 da simulação
de partidas. Os três arquivos em `dist/` foram regenerados.

O lobby foi inspecionado no renderer do Studio, inclusive o menu em uma área
de 640 × 302 pixels. Isso valida uma apresentação de tela pequena, não toque
ou desempenho em aparelho real. O lobby construído tem 2.023 peças, dentro
do orçamento existente de 3.500.

## Limites desta entrega

Esta revisão usa materiais do Roblox e geometria construída no projeto.
Não inclui texturas pintadas sob medida, animações novas de personagens ou
uma remodelagem completa de cada tela. Esses trabalhos continuam no plano
de arquitetura. Compras e serviços publicados mantêm suas validações próprias.
