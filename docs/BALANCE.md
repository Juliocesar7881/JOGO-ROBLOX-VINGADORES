# Balanceamento

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
