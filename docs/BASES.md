# Bases, reforços e recrutamento — 11/10/2026

A coleção tem **43 heróis e 13 bases**, em três raridades: Comum, Raro e
Lendário. Cada comandante equipa uma base
no lobby; suas torres continuam usando os cinco espaços de heróis. A base
gratuita é o Posto da Resistência.

## Como jogar

1. No HUD do lobby, abra **Base** no menu esquerdo para escolher sua base.
2. Os salões **Invocar heróis / Invocar bases** têm coleções separadas.
   Só a confirmação de abertura gasta Ouro.
3. Na partida, toque em **BASE / EVOLUIR**, na barra de vida. Compare renda,
   vida e defesa antes de melhorar.
4. Melhorias gastam **Ouro da partida**. Ouro do lobby é a moeda persistente para
   recrutamento e habilidades; a fazenda não fabrica Ouro permanente.

## Bases

| Base | Raridade | Estilo | Ouro da partida por onda, nível 1 |
|---|---|---|---:|
| Posto da Resistência | Comum, gratuito | Equilibrado | 20 |
| Oficina de Ferro | Comum | Gerador | 45 |
| Horta de suprimentos | Comum | Fazenda | 40 |
| Bunker da Agência | Comum | Barricada | 20 |
| Arsenal de Ferro | Comum | Canhão | 20 |
| Quartel da Selva | Raro | Soldados | 25 |
| Reator de cristal | Raro | Gerador | 65 |
| Estação Polar | Raro | Campo de gelo | 25 |
| Cofre Blindado | Raro | Juros | 20 |
| Cidadela Celeste | Lendário | Barricada | 28 |
| Porta-aviões da Resistência | Lendário | Soldados | 32 |
| Santuário Arcano | Lendário | Canhão mágico | 30 |
| Jardim da Árvore-Mundo | Lendário | Fazenda | 85 |

Todas têm cinco níveis por partida. Custos para chegar aos níveis 2–5:
**450 / 950 / 1.800 / 3.200 Ouro da partida**. Renda e defesas crescem com o nível;
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
- **Campo de gelo (Estação Polar, 15/10):** os inimigos dentro do alcance da
  base andam 18% mais devagar no nível 1, mais 4 pontos por nível (34% no
  nível 5, nunca mais de 40%); chefes sentem 40% disso. Não soma com a
  lentidão de um herói: vale a mais forte. Acaba um instante depois que o
  inimigo sai do campo, que aparece no chão em volta da base.
- **Juros (Cofre Blindado, 15/10):** ao fim de cada onda, paga 8% do Ouro da
  partida que você guardou (16% no nível 5), até 60 Ouro por onda no nível 1
  (228 no nível 5). Exige contribuição na onda, como a renda.

## Baús de heróis

| Tipo | Ouro | Comum | Raro | Lendário | Garantia |
|---|---:|---:|---:|---:|---|
| Suprimentos | 400 | 98% | 2% | — | — |
| Aliança | 1.000 | 78% | 20% | 2% | — |
| Vanguarda | 1.500 | 45% | 47% | 8% | Destaque na 8ª abertura sem obter um destaque |
| Lendas | 2.000 | 30% | 42% | 28% | Lendário na 10ª sem obter um lendário |
| Cósmico | 5.000 | — | 45% | 55% | Destaque na 15ª sem obter um destaque |

São oito produtos de recrutamento com Ouro: cinco de heróis e três de bases.
As garantias têm contadores independentes por baú e coleção. A interface mostra
as chances efetivas quando a garantia está ativa; uma estrela marca quais
itens contam como destaque. Os grupos de aquisição originais conservam
chances por item e prioridade de itens novos; os iniciais não aparecem.
Bases repetidas devolvem o menor valor entre 40% do custo e a compensação
original por base. Heróis repetidos mantêm a compensação existente em
Ouro/maestria/cartas/estrelas, independente da nova cor da coleção.
As restrições da conta a itens aleatórios pagos valem para ambas as coleções.

## Três baús de bases (15/10)

Cada baú de base tem **quatro bases só dele**: o que um baú dá, nenhum outro
dá. As chances pesam apenas as bases daquele baú (`bases` em cada baú do
`Catalog`).

| Baú | Ouro | Bases (chance de cada) | Garantia |
|---|---:|---|---|
| Suprimentos | 400 | Oficina de Ferro 35%, Horta de suprimentos 35%, Bunker da Agência 15%, Arsenal de Ferro 15% | — |
| Vanguarda | 1.500 | Quartel da Selva, Reator de cristal, Estação Polar e Cofre Blindado, 25% cada | — |
| Cósmico | 5.000 | Cidadela Celeste 37,5%, Porta-aviões 37,5%, Santuário Arcano 12,5%, Árvore-Mundo 12,5% | Santuário ou Árvore-Mundo na 15ª abertura sem um deles |

Dentro de cada grupo de um baú, uma base que você ainda não tem sai antes de
uma repetida. Os baús de base Aliança e Lendas saíram; o contador de garantia
do Cósmico continua o mesmo. O salão "Invocar bases" do lobby abre no baú da
Vanguarda (`Chest_base_epic`).

## Referência do elenco

Habilidades de líder com cinco ranks, especializações e detalhes próprios
nos modelos procedurais.
Referência gerada completa em [HEROES.md](HEROES.md).

Há 15 variantes de inimigos, distribuídas entre capangas de Manhattan,
mutantes Gama, soldados Sombra, saqueadores de cristal e robôs do Tirano.
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
