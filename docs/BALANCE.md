# Balanceamento

Nota de 11/10/2026: as cinco raridades das medições históricas abaixo foram
unificadas em Comum (16 heróis), Raro (15) e Lendário (12). Atributos de
combate, custos individuais e probabilidades por item foram preservados.
As médias antigas continuam históricas; use as três categorias atuais em
novas medições.

Como o balanceamento é medido, os números atuais e como reproduzi-los. Todos
os números abaixo vêm de simulações automatizadas (um bot jogando de
verdade, fora do Roblox) e datam do commit em que este arquivo foi escrito —
qualquer mudança em `Catalog.luau`/`Rules.luau` pode mudá-los; rode as
sweeps de novo antes de confiar neles para decidir algo.

## Como medir

Revisão de 22/09/2026: o teste normal também executa partidas completas com
2, 3 e 4 jogadores em Manhattan, verifica resultados, limites e recompensas
individuais. Com o bot de referência, as duplas/trios venceram 50 ondas em
40,9/39,5 minutos; o quarteto perdeu após 49 ondas em 41,1 minutos. O solo
venceu em 42,3 minutos. Preparações não foram antecipadas nessas medições.
Esses dados ainda exigem sessões humanas para aprovar dificuldade e duração.

```bash
# Três elencos sintéticos em todo mapa/modo — visão geral da campanha.
python tests/test_match_simulation.py --sweep rosters
python tests/test_match_simulation.py --sweep rosters --roster <nome>   # só um elenco

# Cada um dos 24 heróis, sozinho com o Homem de Ferro, no Ranqueado.
# É o teste certo para avaliar UM herói: Ranqueado é o modo mais difícil,
# e o parceiro fixo evita que um herói só-de-chão leve a culpa dos voadores
# que nunca conseguiria acertar de qualquer forma.
python tests/test_match_simulation.py --sweep heroes

# DPS efetivo por Energia gasta, sem economia nem habilidade — todo herói
# gasta o mesmo orçamento em torres do próprio tipo, nível 3.
python tests/test_match_simulation.py --sweep duel
```

Cada sweep reusa o mesmo bot de `tests/match_simulation.spec.luau`: ele
procura terreno válido, constrói, prioriza melhorar sobre expandir, e compra
o próximo herói da rotação que a Energia alcança — não é um jogador ótimo,
mas é determinístico e nunca some do teclado, o que já é o suficiente para
comparar heróis entre si.

## Ajuste dos raros (01/10/2026, `--sweep duel`)

O duelo (mesmo orçamento de Ouro de partida, sem habilidade) mostrou raros
fora da faixa depois da renomeação dos heróis:

| Herói | Antes (3000/5000/7000) | Depois |
| --- | --- | --- |
| Juba (beast) | 83 / 94 / 94 % | 55 / 77 / 83 % (custo 240→270, dano 26→15) |
| Geada (iceman) | 74 / 94 / 95 % | 54 / 76 / 82 % (dano 17→11) |
| Farol (cyclops) | 54 / 91 / 98 % | 44 / 78 / 92 % (dano 38→28) |
| Sombra (widow) | 32 / 49 / 56 % | 39 / 60 / 69 % (dano 14→18) |
| Guaxo (rocket) | 27 / 47 / 64 % | 38 / 65 / 82 % (dano 15→19, área 4,5→5,5) |

Médias por raridade no duelo depois do ajuste: comum 40 / 62 / 74, raro
43 / 67 / 78, épico 50 / 72 / 90, lendário 45 / 76 / 92 — raro um pouco acima
de comum, abaixo de épico, como pretendido. O mítico só tem 1 torre até
5000 de Ouro: o custo (760–800) é a barreira, não o dano.

## A curva de raridade pretendida

Raridade mais alta deve significar poder claramente maior — é um pedido
explícito de design, não só um efeito colateral da economia. `--sweep heroes`
é a melhor forma de verificar isso: cada linha é "quantas ondas esse herói,
sozinho com um parceiro fixo, sobrevive no modo mais difícil".

Estado medido neste commit (`--sweep heroes`, médias por raridade, ondas
sobrevividas no Ranqueado):

| Raridade | Média (ondas) |
| --- | --- |
| Comum | 35.2 |
| Raro | 36.1 |
| Épico | 33.0 |
| Lendário | 33.4 |
| Mítico | 35.5 |

Antes do ajuste mais recente, a média de Épico (23.4) estava **abaixo** da de
Comum (24.5) — o oposto do pretendido — puxada por cinco dos sete heróis
épicos (Capitão América, Hulk, Visão, Máquina de Combate, Groot) muito atrás
dos seus pares de raridade. A causa raiz, em cada caso, era uma combinação
de: alcance curto demais para o heurístico de posicionamento do bot cobrir
bem a rota, intervalo de ataque lento sem dano suficiente para compensar, ou,
para os quatro heróis mais caros (Homem-Formiga, Visão, Groot, Doutor
Estranho), um custo alto o bastante para que o bot raramente conseguisse
pagar por uma segunda torre no início da partida — o que também explica por
que um elenco sintético *só* com heróis caros (veja "elenco lenda" abaixo)
falha de forma dramática mesmo depois do ajuste.

O ajuste foi: dano/alcance/intervalo mais generosos nos sete heróis mais
fracos de cada faixa, e uma redução de custo (16–21%) nos quatro cuja
fraqueza aparente vinha principalmente de serem caros demais para chegar ao
campo de batalha, não de fracos por torre. Cada rodada foi verificada com o
sweep antes de seguir para a próxima — ver o histórico de commits para os
valores intermediários e o raciocínio completo de cada mudança.

Alguns heróis ficam deliberadamente acima ou abaixo da própria média de
raridade (variedade de build é saudável); o que a curva por raridade não
deveria fazer é inverter — um Épico não deveria, em média, perder para um
Comum.

## Elencos de referência (`tests/balance_sweep.luau`)

| Elenco | Composição | Ideia |
| --- | --- | --- |
| `iniciais` | Homem de Ferro + Gavião Arqueiro | Conta nova, só os dois heróis iniciais |
| `decente` | + Hulk, Thor, Viúva Negra | Conta em progresso, mistura de raridades |
| `forte` | Homem de Ferro, Viúva Negra, Thor, Motoqueiro Fantasma, Surfista Prateado | Conta avançada, mas com pelo menos uma torre barata desde o início |
| `lenda` | Surfista Prateado, Thor, Motoqueiro Fantasma, Capitã Marvel, Feiticeira Escarlate | Só lendário/mítico, **nenhum** herói barato |

`lenda` existe para medir exatamente o problema descrito acima: **sem**
nenhuma torre barata disponível no início, o bot mal consegue construir uma
única torre com a Energia inicial (600) e o núcleo cai antes da onda 30 em
todo mapa/modo. Isso não é um bug de balanceamento dos heróis em si — é o
comportamento esperado de escalar uma formação sem nenhuma opção econômica
de abertura, o mesmo erro que um jogador real cometeria ao montar um time só
com os heróis mais caros que tem. Os outros três elencos (que sempre têm
pelo menos um herói barato) vencem a Campanha na maioria das tentativas e o
Ranqueado com taxa de vitória menor, como pretendido pelo próprio catálogo
de modos (Ranqueado tem 1.45× vida e 1.5× recompensa — é para ser mais
difícil).

## Onde os números moram

- Estatística base de cada torre/herói: `Catalog.Heroes[id]` (dano, alcance,
  intervalo, tipo de ataque, custo).
- Fórmulas de habilidade (rank, poder, ultimates): `Rules.AbilityStats`,
  `Rules.AbilityExtras`, `Rules.AbilityUpgrade`.
- Geração de onda e vida dos inimigos: `src/shared/Waves.luau`, com
  compressão de tempo documentada no histórico do README (inimigos mais
  rápidos e com menos vida em vez de rotas mais curtas — ver por que abaixo).

### Por que compressão de tempo, não rotas mais curtas

Uma tentativa anterior de acelerar as partidas encurtou as rotas em 30%.
Resultado: o jogo ficou injogável (derrota na onda 9), porque encurtar a
rota reduz o tempo que uma torre tem para atacar cada inimigo antes que ele
chegue ao núcleo, mudando a dificuldade de verdade. A correção que funcionou
foi deixar os inimigos mais rápidos com menos vida (dano recebido ao
atravessar a rota é idêntico) — só o tempo parado entre ondas mudou. Está
registrado aqui porque é o tipo de ajuste que parece inofensivo e não é.

## Passe de temporada: ritmo (01/10/2026)

XP por partida (solo, sem passe de treino): `WaveXP(w) = 18 + 2w` por onda
concluída + 150 de vitória. Campanha de 50 ondas vencida: 3.450 + 150 = 3.600 XP
(de 40 ondas: 2.380 + 150; de 70: 6.230 + 150). Missões somam ~190 XP por dia
e ~700 por semana. Grupo de 4 ganha +30%; passe de treino +25%.

O passe tem 30 níveis; o nível n custa `2000 + 200·(n−1)` XP e o total é 147.000
(`Catalog.Season`). Quem vence uma campanha por dia (~3.800 XP com missões) chega
ao nível 30 em ~39 dias de uma temporada de 60; quem joga a metade disso termina
perto do fim; quem não joga quase nada pega os níveis grátis. Os primeiros níveis
saem em uma partida (2.000 XP), o último em duas. Se a medição real mostrar
que a maioria fecha em menos de 25 dias, subir `stepXp`; se quase ninguém passar
do nível 15, descer `firstXp`.

## Líderes de cura no competitivo (02/10/2026)

`--sweep heroes` (cada herói de líder + Homem de Ferro, competitivo): Rei Pantera
(cura 14 de vida do núcleo) e Capitão Men (escudo + cura) chegavam a **63 ondas**
contra ~22 dos outros. Trocando o líder para o Homem de Ferro eles caíam para
25 e 22: o que carregava a partida não era a torre, era a habilidade do líder
**desfazendo os vazamentos** de um modo sem fim. Agora cada cura de núcleo de um
comandante vale 15% menos que a anterior (piso de 20%, `ABILITY_HANDLERS.heal`):
Pantera 33 ondas, Capitão Men 36 (com +5 de dano, de 24 para 29), ambos ainda acima
da média dos épicos (28), mas sem furar o placar. Cuidado com a leitura: heróis de
800 de Ouro quase nunca são construídos pelo robô da varredura (ele gasta nos baratos),
então o 'mítico fraco' dessa tabela é artefato; a varredura `duel` (mesmo orçamento)
mostra os míticos no topo com 7.000 de Ouro (87% contra 72% dos comuns).
`--hero a,b,c` limita a varredura; a tabela agora mostra os minutos simulados.


## Bônus de convite (06/10/2026)

`Catalog.Rewards.invite`: quem entra pelo convite de um amigo (o servidor lê
`GetJoinData().ReferredByPlayerId`; o cliente nunca diz quem convidou) e tem conta
nova (nenhuma partida e criada há no máximo 30 min) ganha **500 Ouro** uma vez na
vida; o amigo que convidou, se estiver no mesmo servidor, ganha **300 Ouro**, até
**5 vezes por dia UTC**. Referência: o baú de Suprimentos custa 400 e o grupo paga
750 uma vez. O teto diário limita contas descartáveis; se a medição mostrar abuso,
baixar `inviterDailyCap` ou exigir uma partida concluída antes de pagar o amigo.

## Fase 0 do plano de lançamento (14/10/2026)

Quatro regras que o jogo prometia e não cumpria, corrigidas sem mudar números
do `Catalog`:

- **Velocidade:** `Waves.Generate` já calculava o multiplicador (Pesadelo 1,1×,
  mutação Corrida 1,3×), mas o `MatchService` ignorava. Agora o inimigo guarda
  `speedMultiplier` ao nascer e anda com ele.
- **Dificuldade paga por onda:** o `rewardMultiplier` de Difícil (1,5×) e
  Pesadelo (2×) entra no `rewardBonus` da partida, então vale no Ouro e no XP
  de cada onda, e não só no bônus de vitória. O total de uma vitória continua o
  mesmo de antes (o bônus já era multiplicado). `Rules.RunGold` aceita a
  dificuldade como quinto argumento, e o cartão da fila mostra esse valor.
- **"Sem medo do perigo":** o competitivo nunca "vence", então a conquista era
  impossível. Agora é dada ao segurar 30 ondas numa corrida competitiva
  (`FEARLESS_WAVES` no `PlayerService`).
- **Teto das cartas de herói:** o posto da carta continua sem fim (sempre há o
  que gastar), mas o bônus para em +40% de dano, +20% de velocidade e +15% de
  alcance (`Catalog.HeroCards.cap`). Com maestria/talentos (15%) e estrelas
  (15%), o máximo permanente de dano de um herói é +70%, um número conhecido
  que o balanço das ondas tardias e o placar competitivo podem assumir.

Também: a trilha premium da temporada paga o valor do baú em Ouro para contas
em região com itens aleatórios pagos restritos, e a lista de recibos guarda só
os 200 mais recentes.
