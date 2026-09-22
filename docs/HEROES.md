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

| Herói | Custo (Energia) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Homem de Ferro** — Dano tecnológico versátil | 250 | único (ar) | 20 | 27 | 0.90s | Rajada Repulsora |
| **Gavião Arqueiro** — Longo alcance e alvos prioritários | 180 | único (ar) | 27 | 33 | 1.60s | Tiro Mortal |
| **Falcão** — Ataque rápido contra voadores | 220 | único (ar) | 16 | 30 | 0.68s | Comando Aéreo |
| **Soldado Invernal** — Perfuração de armadura | 300 | único | 28 | 28 | 1.00s | Emboscada |

## Raro — 199 Robux (compra direta)

| Herói | Custo (Energia) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Homem-Aranha** — Desaceleração e controle | 280 | área | 14 | 24 | 1.10s | Teia Gigante |
| **Viúva Negra** — Revela camuflados e marca alvos | 260 | único (ar) | 14 | 25 | 0.75s | Marca da Viúva |
| **Homem-Formiga** — Ataques rápidos e pisões | 380 | único | 22 | 26 | 0.70s | Partículas Pym |
| **Vespa** — Ferrão rápido que desacelera | 240 | único (ar) | 10 | 22 | 0.40s | Enxame Elétrico |
| **Rocket** — Explosivos em área | 330 | área (ar) | 15 | 26 | 1.30s | Sucata Valiosa |
| **Demolidor** — Enxerga camuflados | 270 | único | 17 | 20 | 0.60s | Sentido Radar |
| **Shang-Chi** — Combate corpo a corpo veloz | 340 | único | 14 | 18 | 0.40s | Dez Anéis |

## Épico — 449 Robux (compra direta)

| Herói | Custo (Energia) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Capitão América** — Ricochetes e suporte às torres | 360 | corrente | 17 | 23 | 1.05s | Escudo de Vibranium |
| **Pantera Negra** — Ataques rápidos e enfraquece armadura | 400 | único | 19 | 19 | 0.48s | Wakanda para Sempre |
| **Hulk** — Dano de área terrestre | 450 | área | 34 | 24 | 1.60s | Hulk Esmaga! |
| **Visão** — Feixe que atravessa alinhados | 480 | feixe (ar) | 44 | 30 | 1.30s | Fase Densa |
| **Máquina de Combate** — Artilharia pesada em área | 520 | área (ar) | 27 | 28 | 1.40s | Bombardeio |
| **Senhor das Estrelas** — Rajadas rápidas de blasters | 430 | único (ar) | 16 | 25 | 0.32s | Mixtape Incrível |
| **Groot** — Controle e dano em área terrestre | 420 | área | 19 | 23 | 1.50s | Muralha de Raízes |

## Lendário — 999 Robux (compra direta)

| Herói | Custo (Energia) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Thor** — Relâmpagos encadeados e defesa aérea | 550 | corrente (ar) | 32 | 26 | 1.50s | Chamado do Trovão ⚡ (ultimate) |
| **Feiticeira Escarlate** — Dano mágico persistente em área | 650 | queima contínua (ar) | 34 | 26 | 1.80s | Hex Escarlate ⚡ (ultimate) |
| **Doutor Estranho** — Controle espacial e suporte mágico | 560 | área (ar) | 36 | 28 | 1.50s | Dilatação do Tempo ⚡ (ultimate) |
| **Motoqueiro Fantasma** — Fogo do inferno persistente | 620 | queima contínua | 28 | 26 | 1.40s | Fogo do Inferno ⚡ (ultimate) |

## Mítico — 1999 Robux (compra direta)

| Herói | Custo (Energia) | Ataque | Dano | Alcance | Intervalo | Habilidade |
| --- | --- | --- | --- | --- | --- | --- |
| **Capitã Marvel** — Feixe cósmico devastador | 780 | feixe (ar) | 68 | 30 | 1.50s | Nova Fotônica ⚡ (ultimate) |
| **Surfista Prateado** — Energia cósmica encadeada | 800 | corrente (ar) | 34 | 32 | 1.20s | Julgamento Cósmico ⚡ (ultimate) |

## Habilidades

Toda habilidade tem 5 ranks (`Catalog.AbilityRanks`); cada rank melhora poder
e/ou duração em 18% e reduz a recarga em até 4%, com o custo em Ouro e a
maestria exigida crescendo por rank e multiplicados pela raridade do herói
(`Rules.AbilityUpgrade`). Os valores abaixo são do **rank 1**.

| Habilidade | Herói | Recarga | Descrição (rank 1) |
| --- | --- | --- | --- |
| Rajada Repulsora | Homem de Ferro | 55s | Rajada em área: 35% da vida máxima de cada inimigo em 22 studs. |
| Tiro Mortal | Gavião Arqueiro | 50s | Elimina inimigos comuns com menos de 22% de vida em 14 studs. Chefes sofrem dano menor. |
| Comando Aéreo | Falcão | 60s | Todas as suas torres atacam 25% mais rápido por 8 s. |
| Emboscada | Soldado Invernal | 55s | Paralisa inimigos por 2.2 s em 16 studs. Chefes resistem. |
| Teia Gigante | Homem-Aranha | 60s | Desacelera inimigos em 50% por 5 s em 28 studs. |
| Marca da Viúva | Viúva Negra | 55s | Revela camuflados e faz alvos sofrerem +20% de dano por 9 s em 30 studs. |
| Partículas Pym | Homem-Formiga | 45s | Uma torre sua ataca 50% mais rápido por 8 s. |
| Enxame Elétrico | Vespa | 50s | Ferroa 6 inimigos: 16% da vida máxima de cada um. |
| Sucata Valiosa | Rocket | 60s | Recebe Energia na hora: 60% de uma onda inteira de renda. |
| Sentido Radar | Demolidor | 70s | Revela camuflados por 14 s e marca alvos (+12% de dano) em 45 studs. |
| Dez Anéis | Shang-Chi | 55s | Empurra inimigos 26 studs para trás na rota em 24 studs. Chefes não são afetados. |
| Escudo de Vibranium | Capitão América | 90s | Um escudo absorve 20 de dano à base por 10 s. |
| Wakanda para Sempre | Pantera Negra | 100s | Restaura 14 de vida do núcleo e o protege com um escudo de 10 por 8 s. |
| Hulk Esmaga! | Hulk | 60s | Esmagamento: 35% da vida máxima de cada inimigo em 28 studs e paralisa por 1.8 s. |
| Fase Densa | Visão | 55s | Reduz a armadura dos inimigos em 45% por 10 s em 40 studs e os marca (+15% de dano). |
| Bombardeio | Máquina de Combate | 65s | Bombardeio: 28% da vida máxima de cada inimigo em 42 studs. |
| Mixtape Incrível | Senhor das Estrelas | 65s | Todas as suas torres causam 25% mais dano por 9 s. |
| Muralha de Raízes | Groot | 60s | Prende inimigos por 3 s em 22 studs e os desacelera em 50% depois. Chefes resistem. |
| Chamado do Trovão ⚡ | Thor | 75s | ULTIMATE: relâmpagos atingem 10 inimigos (30% da vida máxima de cada) e os paralisam por 1.5 s. |
| Hex Escarlate ⚡ | Feiticeira Escarlate | 80s | ULTIMATE: a realidade se dobra. Paralisa por 3.5 s em 34 studs, derrete 40% da armadura e causa 20% da vida máxima. Chefes resistem. |
| Dilatação do Tempo ⚡ | Doutor Estranho | 85s | ULTIMATE: o tempo quase para em 70 studs. Desacelera 85% por 9 s e empurra os inimigos 22 studs para trás. |
| Fogo do Inferno ⚡ | Motoqueiro Fantasma | 80s | ULTIMATE: o inferno engole a zona. Queima 60% da vida máxima em 7 s, atordoa por 1 s e desacelera em 40%. |
| Nova Fotônica ⚡ | Capitã Marvel | 90s | ULTIMATE: uma nova varre quase o mapa todo. 60% da vida máxima de cada inimigo em 60 studs, paralisa por 2.5 s e marca os alvos (+25% de dano). Chefes sofrem bem menos. |
| Julgamento Cósmico ⚡ | Surfista Prateado | 90s | ULTIMATE: destrói o inimigo mais forte (95% da vida máxima), fulmina outros 6 em todo o mapa (35% cada) e derrete 40% da armadura de todos por 8 s. Chefes sofrem bem menos. |

