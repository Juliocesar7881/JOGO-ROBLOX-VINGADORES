# Heróis

Gerado por `tools/gen_heroes_doc.luau` a partir de `src/shared/Catalog.luau` e
`src/shared/Rules.luau` — não edite este arquivo à mão, rode o gerador de novo.

São 43 heróis em três raridades: Comum, Raro e Lendário. Heróis chegam
pelos cinco baús do lobby ou pela compra direta na Loja Robux. Cada herói tem uma
única habilidade, e é sempre a do herói no **slot 1** da formação que o
comandante usa em combate — por isso o slot 1 é visualmente destacado na UI.
Habilidades dos heróis lendários são **ultimates**: além do efeito principal,
elas disparam um ou mais efeitos secundários (`extras`) no mesmo cast.
Todo herói ataca inimigos no chão e voando.

## Comum — 16 heróis

| Herói | Custo (Ouro da partida) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Armadura de Ferro** — Dano tecnológico versátil | 250 | único | 20 | 27 | 0.90s | Rajada de Plasma |
| **Olho de Águia** — Longo alcance e alvos prioritários | 180 | único | 27 | 33 | 1.60s | Tiro Mortal |
| **Homem-Asa** — Ataque rápido contra voadores | 220 | único | 16 | 30 | 0.68s | Comando Aéreo |
| **Soldado de Prata** — Perfuração de armadura | 300 | único | 28 | 28 | 1.00s | Emboscada |
| **Aranha Urbana** — Desaceleração e controle | 280 | área | 14 | 24 | 1.10s | Rede Gigante |
| **Viúva Sombria** — Revela camuflados e marca alvos | 260 | único | 18 | 25 | 0.75s | Marca da Viúva |
| **Homem Miúdo** — Ataques rápidos e pisões | 380 | único | 22 | 26 | 0.70s | Partículas Quânticas |
| **Abelha Rainha** — Ferrão rápido que desacelera | 240 | único | 10 | 22 | 0.40s | Enxame Elétrico |
| **Guaxinim Atirador** — Explosivos em área | 330 | área | 19 | 26 | 1.30s | Sucata Valiosa |
| **Vigilante Cego** — Enxerga camuflados | 270 | único | 17 | 20 | 0.60s | Sentido Radar |
| **Mestre dos Anéis** — Combate corpo a corpo veloz | 340 | único | 14 | 18 | 0.40s | Anéis Celestes |
| **Olho Rubi** — Feixe que atravessa a horda | 320 | feixe | 28 | 32 | 1.35s | Explosão óptica |
| **Gelo Vivo** — Congela o avanço de grupos | 300 | área | 11 | 25 | 1.05s | Era do gelo |
| **Teleportador Azul** — Ataques rápidos e recuo tático | 290 | único | 24 | 22 | 0.80s | Puf! |
| **Acrobata Peludo** — Impactos curtos contra hordas | 270 | área | 15 | 18 | 0.95s | Salto selvagem |
| **Cavaleiro Lunar** — Revela camuflados na rota | 310 | único | 34 | 25 | 1.05s | Luz da Lua |

## Raro — 15 heróis

| Herói | Custo (Ouro da partida) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Capitão Escudo** — Ricochetes e suporte às torres | 360 | corrente | 17 | 23 | 1.05s | Escudo Égide |
| **Rei Pantera** — Ataques rápidos e enfraquece armadura | 400 | único | 19 | 19 | 0.48s | Garra da Noite |
| **Gigante Furioso** — Dano de área terrestre | 450 | área | 34 | 24 | 1.60s | Gigante Esmaga! |
| **Androide Prisma** — Feixe que atravessa alinhados | 480 | feixe | 44 | 30 | 1.30s | Fase Densa |
| **Soldado Blindado** — Artilharia pesada em área | 520 | área | 27 | 28 | 1.40s | Bombardeio |
| **Pirata Estelar** — Rajadas rápidas de blasters | 430 | único | 16 | 25 | 0.32s | Batida Cósmica |
| **Gigante Verde** — Controle e dano em área terrestre | 420 | área | 19 | 23 | 1.50s | Muralha de Raízes |
| **Garra de Aço** — Garras contra elites | 420 | único | 36 | 16 | 0.65s | Fúria das garras |
| **Mestre das Cartas** — Cartas explosivas contra grupos | 390 | área | 35 | 29 | 1.15s | Ás explosivo |
| **Ninja Psíquica** — Lâminas psíquicas perfurantes | 400 | único | 32 | 23 | 0.70s | Corte psíquico |
| **Mercenário Falante** — Rajadas rápidas e apoio ofensivo | 380 | único | 24 | 28 | 0.60s | Trabalho em equipe |
| **Capitão Men** — Socos que empurram, imbatível | 400 | único | 29 | 17 | 0.60s | Indestrutível |
| **Amazona Dourada** — Laço da verdade e espada | 420 | corrente | 18 | 24 | 0.90s | Laço da Verdade |
| **Rei dos Mares** — Marés que atrasam e empurram | 430 | área | 19 | 25 | 1.40s | Maremoto |
| **Caçador da Noite** — Minas e armadilhas na estrada | 380 | mine | 40 | 26 | 1.50s | Bomba de Fumaça |

## Lendário — 12 heróis

| Herói | Custo (Ouro da partida) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Deus do Trovão** — Relâmpagos encadeados e defesa aérea | 550 | corrente | 32 | 26 | 1.50s | Chamado do Trovão ⚡ (ultimate) |
| **Bruxa do Caos** — Dano mágico persistente em área | 650 | queima contínua | 34 | 26 | 1.80s | Feitiço Rubi ⚡ (ultimate) |
| **Doutor Místico** — Controle espacial e suporte mágico | 560 | área | 36 | 28 | 1.50s | Dilatação do Tempo ⚡ (ultimate) |
| **Motoqueiro Chama** — Fogo fantasma persistente | 620 | queima contínua | 28 | 26 | 1.40s | Fogo Fantasma ⚡ (ultimate) |
| **Capitã Estelar** — Feixe cósmico devastador | 780 | feixe | 68 | 30 | 1.50s | Nova Fotônica ⚡ (ultimate) |
| **Surfista Cósmico** — Energia cósmica encadeada | 800 | corrente | 34 | 32 | 1.20s | Julgamento Cósmico ⚡ (ultimate) |
| **Deusa do Clima** — Relâmpagos e defesa aérea | 600 | corrente | 40 | 34 | 1.40s | Olho da tempestade ⚡ (ultimate) |
| **Psíquica Radiante** — Explosões de energia psíquica | 760 | área | 44 | 30 | 1.30s | Chama Aurora ⚡ (ultimate) |
| **Guardião Cósmico** — Feixe cósmico antiaéreo | 590 | feixe | 48 | 32 | 1.05s | Supernova ⚡ (ultimate) |
| **Guardião Verde** — Construções de energia e controle | 600 | área | 30 | 28 | 1.50s | Construção Esmeralda ⚡ (ultimate) |
| **Velocista Rubro** — Golpes ultrarrápidos | 560 | corrente | 11 | 24 | 0.18s | Supervelocidade ⚡ (ultimate) |
| **Guardião Solar** — Visão de calor e força suprema | 800 | feixe | 50 | 32 | 1.30s | Fúria Solar ⚡ (ultimate) |

## Habilidades

Toda habilidade tem 5 ranks (`Catalog.AbilityRanks`); cada rank melhora poder
e/ou duração em 18% e reduz a recarga em até 4%, com o custo em Ouro e a
maestria exigida crescendo por rank. O multiplicador de custo de cada herói
foi preservado na unificação (`hero.economy.abilityCost`)
(`Rules.AbilityUpgrade`). Os valores abaixo são do **rank 1**.

| Habilidade | Herói | Recarga | Descrição (rank 1) |
| --- | --- | --- | --- |
| Rajada de Plasma | Armadura de Ferro | 55s | Rajada em área: 35% da vida máxima de cada inimigo em 22 studs. |
| Tiro Mortal | Olho de Águia | 50s | Elimina inimigos comuns com menos de 22% de vida em 14 studs. Chefes sofrem dano menor. |
| Comando Aéreo | Homem-Asa | 60s | Todas as suas torres atacam 25% mais rápido por 8 s. |
| Emboscada | Soldado de Prata | 55s | Paralisa inimigos por 2.2 s em 16 studs. Chefes resistem. |
| Rede Gigante | Aranha Urbana | 60s | Desacelera inimigos em 50% por 5 s em 28 studs. |
| Marca da Viúva | Viúva Sombria | 55s | Revela camuflados e faz alvos sofrerem +20% de dano por 9 s em 30 studs. |
| Partículas Quânticas | Homem Miúdo | 45s | Uma torre sua ataca 50% mais rápido por 8 s. |
| Enxame Elétrico | Abelha Rainha | 50s | Ferroa 6 inimigos: 16% da vida máxima de cada um. |
| Sucata Valiosa | Guaxinim Atirador | 60s | Recebe Ouro da partida na hora: 60% de uma onda inteira de renda. |
| Sentido Radar | Vigilante Cego | 70s | Revela camuflados por 14 s e marca alvos (+12% de dano) em 45 studs. |
| Anéis Celestes | Mestre dos Anéis | 55s | Empurra inimigos 26 studs para trás na rota em 24 studs. Chefes não são afetados. |
| Escudo Égide | Capitão Escudo | 90s | Um escudo absorve 20 de dano à base por 10 s. |
| Garra da Noite | Rei Pantera | 100s | Restaura 14 de vida do núcleo e o protege com um escudo de 10 por 8 s. |
| Gigante Esmaga! | Gigante Furioso | 60s | Esmagamento: 35% da vida máxima de cada inimigo em 28 studs e paralisa por 1.8 s. |
| Fase Densa | Androide Prisma | 55s | Reduz a armadura dos inimigos em 45% por 10 s em 40 studs e os marca (+15% de dano). |
| Bombardeio | Soldado Blindado | 65s | Bombardeio: 28% da vida máxima de cada inimigo em 42 studs. |
| Batida Cósmica | Pirata Estelar | 65s | Todas as suas torres causam 25% mais dano por 9 s. |
| Muralha de Raízes | Gigante Verde | 60s | Prende inimigos por 3 s em 22 studs e os desacelera em 50% depois. Chefes resistem. |
| Chamado do Trovão ⚡ | Deus do Trovão | 75s | ULTIMATE: relâmpagos atingem 10 inimigos (30% da vida máxima de cada) e os paralisam por 1.5 s. |
| Feitiço Rubi ⚡ | Bruxa do Caos | 80s | ULTIMATE: a realidade se dobra. Paralisa por 3.5 s em 34 studs, derrete 40% da armadura e causa 20% da vida máxima. Chefes resistem. |
| Dilatação do Tempo ⚡ | Doutor Místico | 85s | ULTIMATE: o tempo quase para em 70 studs. Desacelera 85% por 9 s e empurra os inimigos 22 studs para trás. |
| Fogo Fantasma ⚡ | Motoqueiro Chama | 80s | ULTIMATE: o inferno engole a zona. Queima 60% da vida máxima em 7 s, atordoa por 1 s e desacelera em 40%. |
| Nova Fotônica ⚡ | Capitã Estelar | 90s | ULTIMATE: uma nova varre quase o mapa todo. 60% da vida máxima de cada inimigo em 60 studs, paralisa por 2.5 s e marca os alvos (+25% de dano). Chefes sofrem bem menos. |
| Julgamento Cósmico ⚡ | Surfista Cósmico | 90s | ULTIMATE: destrói o inimigo mais forte (95% da vida máxima), fulmina outros 6 em todo o mapa (35% cada) e derrete 40% da armadura de todos por 8 s. Chefes sofrem bem menos. |
| Fúria das garras | Garra de Aço | 55s | Finaliza alvos abaixo de 28% de vida em 30 studs. Chefes resistem. |
| Explosão óptica | Olho Rubi | 60s | Explosão: 28% da vida máxima em 30 studs. Chefes resistem. |
| Olho da tempestade ⚡ | Deusa do Clima | 75s | Relâmpagos: 26% da vida de 6 alvos; paralisa por 1.2 s. Chefes resistem. |
| Chama Aurora ⚡ | Psíquica Radiante | 80s | Chama: 8% de vida por segundo por 6 s; remove 20% de armadura. Chefes resistem. |
| Era do gelo | Gelo Vivo | 65s | Desacelera 50% por 6 s em 30 studs. |
| Ás explosivo | Mestre das Cartas | 60s | Explosão: 32% da vida máxima em 30 studs. Chefes resistem. |
| Puf! | Teleportador Azul | 65s | Recua inimigos 22 studs. Não move chefes. |
| Salto selvagem | Acrobata Peludo | 65s | Paralisa por 2 s em 30 studs. Chefes resistem. |
| Corte psíquico | Ninja Psíquica | 65s | Remove 40% de armadura por 6 s. |
| Trabalho em equipe | Mercenário Falante | 65s | Suas torres ganham 20% de dano por 6 s. |
| Luz da Lua | Cavaleiro Lunar | 65s | Revela e marca: +18% de dano por 6 s. |
| Supernova ⚡ | Guardião Cósmico | 75s | Explosão: 38% da vida em 30 studs; revela e marca (+12% dano). Chefes resistem. |
| Indestrutível | Capitão Men | 80s | Um escudo absorve 30 de dano ao núcleo por 12 s e o núcleo recupera 8 de vida. |
| Construção Esmeralda ⚡ | Guardião Verde | 80s | ULTIMATE: uma gaiola de energia paralisa por 3 s em 36 studs, puxa os inimigos 10 studs para trás e derrete 30% da armadura. Chefes resistem. |
| Fúria Solar ⚡ | Guardião Solar | 85s | ULTIMATE: uma explosão de calor varre 55 studs: 50% da vida máxima de cada inimigo, atordoa por 2 s e queima 30% em 5 s. Chefes sofrem bem menos. |
| Supervelocidade ⚡ | Velocista Rubro | 80s | ULTIMATE: o mundo desacelera para a sua equipe. Todas as suas torres atacam 40% mais rápido por 10 s e todos os inimigos andam 50% mais devagar por 6 s. |
| Laço da Verdade | Amazona Dourada | 60s | Revela camuflados e faz alvos sofrerem +30% de dano por 10 s em 40 studs, e derrete 30% da armadura. |
| Maremoto | Rei dos Mares | 70s | Uma onda empurra os inimigos 30 studs para trás em 45 studs e os desacelera em 50% depois. Chefes não saem do lugar. |
| Bomba de Fumaça | Caçador da Noite | 70s | Paralisa por 3 s em 34 studs e derrete 25% da armadura por 8 s. Chefes resistem. |

