# Heróis

Gerado por `tools/gen_heroes_doc.luau` a partir de `src/shared/Catalog.luau` e
`src/shared/Rules.luau` — não edite este arquivo à mão, rode o gerador de novo.

Heróis só chegam à conta pelos baús do lobby (Baú Raro, 1.000 Ouro; Baú
Lendário, 2.000 Ouro) ou pela compra direta na Loja Robux. Cada herói tem uma
única habilidade, e é sempre a do herói no **slot 1** da formação que o
comandante usa em combate — por isso o slot 1 é visualmente destacado na UI.
Habilidades lendárias e míticas são **ultimates**: além do efeito principal,
elas disparam um ou mais efeitos secundários (`extras`) no mesmo cast.

## Comum — 79 Robux (compra direta)

| Herói | Custo (Ouro da partida) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Volt** — Dano tecnológico versátil | 250 | único (ar) | 20 | 27 | 0.90s | Rajada de Plasma |
| **Lince** — Longo alcance e alvos prioritários | 180 | único (ar) | 27 | 33 | 1.60s | Tiro Mortal |
| **Cotovia** — Ataque rápido contra voadores | 220 | único (ar) | 16 | 30 | 0.68s | Comando Aéreo |
| **Sargento Prata** — Perfuração de armadura | 300 | único | 28 | 28 | 1.00s | Emboscada |

## Raro — 199 Robux (compra direta)

| Herói | Custo (Ouro da partida) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Laçadora** — Desaceleração e controle | 280 | área | 14 | 24 | 1.10s | Rede Gigante |
| **Sombra** — Revela camuflados e marca alvos | 260 | único (ar) | 18 | 25 | 0.75s | Marca da Sombra |
| **Titã de Bolso** — Ataques rápidos e pisões | 380 | único | 22 | 26 | 0.70s | Partículas Quânticas |
| **Pirilampo** — Ferrão rápido que desacelera | 240 | único (ar) | 10 | 22 | 0.40s | Enxame Elétrico |
| **Guaxo** — Explosivos em área | 330 | área (ar) | 19 | 26 | 1.30s | Sucata Valiosa |
| **Eco** — Enxerga camuflados | 270 | único | 17 | 20 | 0.60s | Sentido Radar |
| **Rin** — Combate corpo a corpo veloz | 340 | único | 14 | 18 | 0.40s | Anéis Celestes |
| **Farol** — Feixe que atravessa a horda | 320 | feixe (ar) | 28 | 32 | 1.35s | Explosão óptica |
| **Geada** — Congela o avanço de grupos | 300 | área | 11 | 25 | 1.05s | Era do gelo |
| **Pisca** — Ataques rápidos e recuo tático | 290 | único | 24 | 22 | 0.80s | Puf! |
| **Juba** — Impactos curtos contra hordas | 270 | área | 15 | 18 | 0.95s | Salto selvagem |
| **Eclipse** — Revela camuflados na rota | 310 | único (ar) | 34 | 25 | 1.05s | Luz da Lua |

## Épico — 449 Robux (compra direta)

| Herói | Custo (Ouro da partida) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Comandante Égide** — Ricochetes e suporte às torres | 360 | corrente | 17 | 23 | 1.05s | Escudo Égide |
| **Ônix** — Ataques rápidos e enfraquece armadura | 400 | único | 19 | 19 | 0.48s | Garra da Noite |
| **Pedregulho** — Dano de área terrestre | 450 | área | 34 | 24 | 1.60s | Pedregulho Esmaga! |
| **Prisma** — Feixe que atravessa alinhados | 480 | feixe (ar) | 44 | 30 | 1.30s | Fase Densa |
| **Bigorna** — Artilharia pesada em área | 520 | área (ar) | 27 | 28 | 1.40s | Bombardeio |
| **Cometa** — Rajadas rápidas de blasters | 430 | único (ar) | 16 | 25 | 0.32s | Batida Cósmica |
| **Carvalho** — Controle e dano em área terrestre | 420 | área | 19 | 23 | 1.50s | Muralha de Raízes |
| **Presa** — Garras contra elites | 420 | único | 36 | 16 | 0.65s | Fúria das garras |
| **Ás** — Cartas explosivas contra grupos | 390 | área (ar) | 35 | 29 | 1.15s | Ás explosivo |
| **Kunai** — Lâminas psíquicas perfurantes | 400 | único | 32 | 23 | 0.70s | Corte psíquico |
| **Confete** — Rajadas rápidas e apoio ofensivo | 380 | único (ar) | 24 | 28 | 0.60s | Trabalho em equipe |

## Lendário — 999 Robux (compra direta)

| Herói | Custo (Ouro da partida) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Brontus** — Relâmpagos encadeados e defesa aérea | 550 | corrente (ar) | 32 | 26 | 1.50s | Chamado do Trovão ⚡ (ultimate) |
| **Rubi** — Dano mágico persistente em área | 650 | queima contínua (ar) | 34 | 26 | 1.80s | Feitiço Rubi ⚡ (ultimate) |
| **Arcano** — Controle espacial e suporte mágico | 560 | área (ar) | 36 | 28 | 1.50s | Dilatação do Tempo ⚡ (ultimate) |
| **Cavaleiro Brasa** — Fogo fantasma persistente | 620 | queima contínua | 28 | 26 | 1.40s | Fogo Fantasma ⚡ (ultimate) |
| **Monção** — Relâmpagos e defesa aérea | 600 | corrente (ar) | 40 | 34 | 1.40s | Olho da tempestade ⚡ (ultimate) |
| **Pulsar** — Feixe cósmico antiaéreo | 590 | feixe (ar) | 48 | 32 | 1.05s | Supernova ⚡ (ultimate) |

## Mítico — 1999 Robux (compra direta)

| Herói | Custo (Ouro da partida) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Solaria** — Feixe cósmico devastador | 780 | feixe (ar) | 68 | 30 | 1.50s | Nova Fotônica ⚡ (ultimate) |
| **Órbita** — Energia cósmica encadeada | 800 | corrente (ar) | 34 | 32 | 1.20s | Julgamento Cósmico ⚡ (ultimate) |
| **Aurora** — Explosões de energia psíquica | 760 | área (ar) | 44 | 30 | 1.30s | Chama Aurora ⚡ (ultimate) |

## Habilidades

Toda habilidade tem 5 ranks (`Catalog.AbilityRanks`); cada rank melhora poder
e/ou duração em 18% e reduz a recarga em até 4%, com o custo em Ouro e a
maestria exigida crescendo por rank e multiplicados pela raridade do herói
(`Rules.AbilityUpgrade`). Os valores abaixo são do **rank 1**.

| Habilidade | Herói | Recarga | Descrição (rank 1) |
| --- | --- | --- | --- |
| Rajada de Plasma | Volt | 55s | Rajada em área: 35% da vida máxima de cada inimigo em 22 studs. |
| Tiro Mortal | Lince | 50s | Elimina inimigos comuns com menos de 22% de vida em 14 studs. Chefes sofrem dano menor. |
| Comando Aéreo | Cotovia | 60s | Todas as suas torres atacam 25% mais rápido por 8 s. |
| Emboscada | Sargento Prata | 55s | Paralisa inimigos por 2.2 s em 16 studs. Chefes resistem. |
| Rede Gigante | Laçadora | 60s | Desacelera inimigos em 50% por 5 s em 28 studs. |
| Marca da Sombra | Sombra | 55s | Revela camuflados e faz alvos sofrerem +20% de dano por 9 s em 30 studs. |
| Partículas Quânticas | Titã de Bolso | 45s | Uma torre sua ataca 50% mais rápido por 8 s. |
| Enxame Elétrico | Pirilampo | 50s | Ferroa 6 inimigos: 16% da vida máxima de cada um. |
| Sucata Valiosa | Guaxo | 60s | Recebe Ouro da partida na hora: 60% de uma onda inteira de renda. |
| Sentido Radar | Eco | 70s | Revela camuflados por 14 s e marca alvos (+12% de dano) em 45 studs. |
| Anéis Celestes | Rin | 55s | Empurra inimigos 26 studs para trás na rota em 24 studs. Chefes não são afetados. |
| Escudo Égide | Comandante Égide | 90s | Um escudo absorve 20 de dano à base por 10 s. |
| Garra da Noite | Ônix | 100s | Restaura 14 de vida do núcleo e o protege com um escudo de 10 por 8 s. |
| Pedregulho Esmaga! | Pedregulho | 60s | Esmagamento: 35% da vida máxima de cada inimigo em 28 studs e paralisa por 1.8 s. |
| Fase Densa | Prisma | 55s | Reduz a armadura dos inimigos em 45% por 10 s em 40 studs e os marca (+15% de dano). |
| Bombardeio | Bigorna | 65s | Bombardeio: 28% da vida máxima de cada inimigo em 42 studs. |
| Batida Cósmica | Cometa | 65s | Todas as suas torres causam 25% mais dano por 9 s. |
| Muralha de Raízes | Carvalho | 60s | Prende inimigos por 3 s em 22 studs e os desacelera em 50% depois. Chefes resistem. |
| Chamado do Trovão ⚡ | Brontus | 75s | ULTIMATE: relâmpagos atingem 10 inimigos (30% da vida máxima de cada) e os paralisam por 1.5 s. |
| Feitiço Rubi ⚡ | Rubi | 80s | ULTIMATE: a realidade se dobra. Paralisa por 3.5 s em 34 studs, derrete 40% da armadura e causa 20% da vida máxima. Chefes resistem. |
| Dilatação do Tempo ⚡ | Arcano | 85s | ULTIMATE: o tempo quase para em 70 studs. Desacelera 85% por 9 s e empurra os inimigos 22 studs para trás. |
| Fogo Fantasma ⚡ | Cavaleiro Brasa | 80s | ULTIMATE: o inferno engole a zona. Queima 60% da vida máxima em 7 s, atordoa por 1 s e desacelera em 40%. |
| Nova Fotônica ⚡ | Solaria | 90s | ULTIMATE: uma nova varre quase o mapa todo. 60% da vida máxima de cada inimigo em 60 studs, paralisa por 2.5 s e marca os alvos (+25% de dano). Chefes sofrem bem menos. |
| Julgamento Cósmico ⚡ | Órbita | 90s | ULTIMATE: destrói o inimigo mais forte (95% da vida máxima), fulmina outros 6 em todo o mapa (35% cada) e derrete 40% da armadura de todos por 8 s. Chefes sofrem bem menos. |
| Fúria das garras | Presa | 55s | Finaliza alvos abaixo de 28% de vida em 30 studs. Chefes resistem. |
| Explosão óptica | Farol | 60s | Explosão: 28% da vida máxima em 30 studs. Chefes resistem. |
| Olho da tempestade ⚡ | Monção | 75s | Relâmpagos: 26% da vida de 6 alvos; paralisa por 1.2 s. Chefes resistem. |
| Chama Aurora ⚡ | Aurora | 80s | Chama: 8% de vida por segundo por 6 s; remove 20% de armadura. Chefes resistem. |
| Era do gelo | Geada | 65s | Desacelera 50% por 6 s em 30 studs. |
| Ás explosivo | Ás | 60s | Explosão: 32% da vida máxima em 30 studs. Chefes resistem. |
| Puf! | Pisca | 65s | Recua inimigos 22 studs. Não move chefes. |
| Salto selvagem | Juba | 65s | Paralisa por 2 s em 30 studs. Chefes resistem. |
| Corte psíquico | Kunai | 65s | Remove 40% de armadura por 6 s. |
| Trabalho em equipe | Confete | 65s | Suas torres ganham 20% de dano por 6 s. |
| Luz da Lua | Eclipse | 65s | Revela e marca: +18% de dano por 6 s. |
| Supernova ⚡ | Pulsar | 75s | Explosão: 38% da vida em 30 studs; revela e marca (+12% dano). Chefes resistem. |

