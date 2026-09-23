# Bases, reforços e recrutamento — versão 2026.4

A coleção agora tem **36 heróis e 11 bases**. Cada comandante equipa uma base
no lobby; suas torres continuam usando os cinco espaços de heróis. A base
gratuita é o Posto da Resistência.

## Como jogar

1. No HUD do lobby, abra **Heróis → Minhas bases** para escolher sua base.
2. A loja de baús tem abas **Heróis / Bases**. Os dois pisos verdes do lobby
   levam às respectivas coleções. Só a confirmação de abertura gasta Ouro.
3. Na partida, toque em **BASE / EVOLUIR**, na barra de vida. Compare renda,
   vida e defesa antes de melhorar.
4. Melhorias gastam **Energia da partida**. Ouro é a moeda persistente para
   recrutamento e habilidades; a fazenda não fabrica Ouro permanente.

## Bases

| Base | Raridade | Estilo | Energia por onda, nível 1 |
|---|---|---|---:|
| Posto da Resistência | Comum, gratuito | Equilibrado | 20 |
| Oficina Stark | Comum | Gerador | 45 |
| Horta de suprimentos | Comum | Fazenda | 40 |
| Bunker S.H.I.E.L.D. | Raro | Barricada | 20 |
| Arsenal Stark | Raro | Canhão | 20 |
| Quartel de Wakanda | Épico | Soldados | 25 |
| Reator de vibranium | Épico | Gerador | 65 |
| Cidadela de Asgard | Lendário | Barricada | 28 |
| Porta-aviões da Resistência | Lendário | Soldados | 32 |
| Sanctum Sanctorum | Mítico | Canhão mágico | 30 |
| Jardim de Yggdrasil | Mítico | Fazenda | 85 |

Todas têm cinco níveis por partida. Custos para chegar aos níveis 2–5:
**450 / 950 / 1.800 / 3.200 Energia**. Renda e defesas crescem com o nível;
cada melhoria acrescenta 12 pontos ao bônus de vida. Melhorar acrescenta
somente a nova capacidade de vida, sem curar todo o dano anterior.

No grupo, cada jogador mantém sua própria base e renda. O bônus de vida
contribui ao núcleo compartilhado dividido pelo tamanho inicial do grupo,
arredondado para baixo. Sair do servidor não muda esse divisor. Reconectar
recupera o mesmo módulo da partida. Os níveis reiniciam na próxima partida.

- **Renda:** entregue uma vez por onda concluída, somente a quem contribuiu.
- **Canhão:** acerta alvos terrestres e aéreos próximos ao núcleo; camuflados
  continuam exigindo os heróis de reconhecimento.
- **Barricada:** usa sua própria vida para causar dano nos terrestres chegando
  ao núcleo. Regenera após cinco segundos sem sofrer impacto. Não congela
  chefes nem impede voadores de passar.
- **Quartel:** soldados percorrem as rotas ao contrário, alternando entradas.
  Colidem com terrestres e gastam vida proporcional ao dano. Ao chegar à
  entrada inimiga, desaparecem sem causar efeito ou conceder recompensa.
  Máximo de seis soldados por jogador. Invocados continuam sem recompensa.

## Cinco baús por coleção

| Tipo | Ouro | Comum | Raro | Épico | Lendário | Mítico | Garantia |
|---|---:|---:|---:|---:|---:|---:|---|
| Suprimentos | 400 | 75% | 23% | 2% | — | — | — |
| Raro | 1.000 | 34% | 44% | 20% | 2% | — | — |
| Épico | 1.500 | — | 45% | 47% | 7% | 1% | Épico+ na 8ª abertura sem obter Épico+ |
| Lendário | 2.000 | — | 30% | 42% | 22% | 6% | Lendário+ na 10ª sem obter Lendário+ |
| Cósmico | 5.000 | — | — | 45% | 43% | 12% | Mítico na 15ª sem obter Mítico |

São dez produtos de recrutamento com Ouro, cinco em cada coleção. As
garantias têm contadores independentes por baú e coleção. A interface mostra
as chances efetivas quando a garantia está ativa. Dentro da raridade
sorteada, itens ainda não possuídos têm prioridade; os iniciais não aparecem.
Bases repetidas devolvem o menor valor entre 40% do custo e a compensação
da raridade. Heróis repetidos mantêm a compensação existente em Ouro/maestria.
As restrições da conta a itens aleatórios pagos valem para ambas as coleções.

## Conteúdo novo

Wolverine, Ciclope, Tempestade, Jean Grey, Homem de Gelo, Gambit, Noturno,
Fera, Psylocke, Deadpool, Cavaleiro da Lua e Nova: habilidades de líder com
cinco ranks, especializações e detalhes próprios nos modelos procedurais.
Referência gerada completa em [HEROES.md](HEROES.md).

Há 15 variantes de inimigos, distribuídas entre capangas de Manhattan,
mutantes Gama, soldados HYDRA, saqueadores de vibranium e Doombots.
Elas herdam as famílias comum/corredor/blindado, com identidade visual por
mapa e mesmos atributos/recompensas da família. Não são novos chefes:
os cinco chefes anteriores continuam nas ondas 10, 20, 30, 40 e 50.

## Verificação e limites

Testes cobrem compra e gravação atômicas, repetidos, equipar/recusar bases,
recarregar perfil, custo e limite de evolução, renda única, troca de vida da
barricada, regeneração, canhão e colisão/desaparecimento dos soldados.
O cliente é exercitado em seis resoluções e os HUDs são revisados no Studio.

Nesta revisão, a suíte completa passou, incluindo 1.248 verificações da
simulação de partidas, 295 de persistência/compras e 2.352 do cliente.
No Studio, as telas novas foram conferidas em português e inglês; a área de
375×609 pixels não apresentou cortes de texto nas telas de bases e baús.
Os cortes antigos do nome do modo e do rank foram corrigidos e reconferidos.
A cena visual com 36 heróis, quatro bases, oito soldados e 180 inimigos
manteve aproximadamente 60 FPS nesta máquina em primeiro plano, com efeitos
reduzidos. Isso não valida celular nem o servidor com quatro clientes reais.

Essa expansão inicia a versão competitiva **2026.4**, preservando os placares
anteriores. Os valores são iniciais: partidas humanas e aparelhos reais ainda
precisam validar equilíbrio e desempenho. A configuração online e os IDs
continuam descritos em [PRODUCTION_STATUS.md](PRODUCTION_STATUS.md).
