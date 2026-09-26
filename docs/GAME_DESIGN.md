# Design do jogo (estado atual)

Este documento descreve o jogo **como o código está implementado hoje**, não
o plano original. Para os números exatos, o código-fonte é sempre a
referência: `src/shared/Catalog.luau` (dados) e `src/shared/Rules.luau`
(regras). `docs/HEROES.md` é gerado direto do catálogo e nunca fica
desatualizado; use-o para qualquer número de herói/habilidade específico.

## O laço principal

1. O lobby é uma ilha dividida em distritos (`World.Districts`): três portais
   de campanha no centro (Manhattan, Complexo Gama, HYDRA), as outras três
   expedições nos cantos do sul (Wakanda e Asgard a oeste, Latvéria a leste),
   a arena competitiva a leste (três portais e o placar da temporada), treino e
   cartas no canto nordeste, o mercado (baús e Robux) no canto noroeste e a
   zona AFK a oeste. O botão JOGAR oferece os mesmos destinos sem atravessar o
   lobby.
2. Cada portal é um elevador com **destino fixo** (`Catalog.Destinations`):
   mapa e modo nunca são sorteados. Quem entra junto vai para o mesmo grupo
   (até 4).
3. A duração depende do destino (`Rules.WaveCount`): treino 20 ondas;
   campanha Manhattan 40, Gama/HYDRA/Wakanda/Asgard 50, Latvéria 70; cartas 50;
   competitivo **sem fim**. Chefe a cada 10 ondas; na campanha o último é o
   chefe do próprio mapa (Asgard: Loki corrompido), e os anteriores percorrem o
   resto do elenco sem nunca antecipar o chefe final.
4. O Ouro do lobby é pago pela partida (ver Economia). Ondas concluídas ficam
   guardadas mesmo com derrota ou queda de conexão (`RejoinService`).

## Economia da partida (`Rules.KillCash`, `Rules.WaveCash`, `Rules.RunGold`)

- **Ouro da partida** (🪙): cada inimigo derrotado derruba moedas no chão; é
  preciso andar perto para pegar (o ímã: `Config.CollectRadius`, ampliado pelo
  talento Magnetismo, +15% por ponto; o passe Drone Coletor pega tudo). Também
  ajudam: heróis **coletores** (Falcão, Homem-Formiga, Rocket e Senhor das
  Estrelas, campo `pickup` no catálogo) puxam o seu Ouro que cai a até 14
  studs da torre, e toda **habilidade de área** recolhe o seu Ouro dentro do
  raio dela. Nada disso cria Ouro; só poupa caminhada. Esse
  Ouro paga, melhora e vende heróis e evolui a base. Ao fim de cada onda entra
  um bônus direto (`Rules.WaveCash` + renda da base). Começa com
  `Config.StartCash`. **Não existe mais Energia**, e esse Ouro nunca sai da
  partida.
- **Ouro do lobby** (baús): nunca vem do que foi gasto na partida. Cada onda
  concluída guarda uma parte garantida; a vitória paga o resto. Campanha: 40 por
  onda na vitória (2.000 em 50 ondas, 1.600 em 40, 2.800 em 70); derrota paga
  só 40% das ondas concluídas. Cartas: 2.500 na vitória. Competitivo: 25 por
  onda e +100 a cada dez, tudo guardado. Treino: 1.000 na primeira vitória.

## Modos (`Catalog.Modes`, portais em `Catalog.PortalOrder`)

| Modo | Ondas | Multiplicador de vida | Desbloqueio |
| --- | --- | --- | --- |
| Treinamento (`tutorial`) | 20 (chefe simplificado no fim) | 0.6× | Sempre disponível e recomendado; não bloqueia a campanha |
| Campanha (`normal`) | 40–70 conforme o mapa | 1.2× | Sempre disponível |
| Competitivo (`ranked`) | sem fim | 1.45× | Primeira vitória de campanha |
| Cartas (`cards`) | 50 | 1.6× | Primeira vitória de campanha |

O competitivo é o único modo sem fim: registra só ondas concluídas, separado
por mapa, tamanho inicial do grupo e temporada de 60 dias (versão de placar
`comp2`; os placares do antigo ranqueado finito e do infinito casual ficam
arquivados). Entre as ondas o grupo pode votar para encerrar e guardar o
recorde. Cartas é um roguelike leve: depois das ondas 5, 10 … 45 o comandante
escolhe uma de três cartas (`Catalog.Cards`); nenhuma carta depois da vitória.

## Mapas (`Catalog.MapOrder`)

Manhattan (ruas em zigue-zague), Complexo Gama (braços do reator), HYDRA
(corredores industriais alternados), Fronteira de Wakanda (espiral na
savana), Fortaleza da Latvéria (três entradas na neve) e Ponte de Asgard —
cada um com seu próprio chefe (`bossId`), paleta de iluminação e rota.

## Zona AFK

Duas salas no lobby: +5 Ouro ou +10 XP por minuto inteiro parado dentro delas,
medido e pago pelo servidor. Cada minuto tem um id de pagamento: uma falha de
salvamento é repetida sem pagar em dobro, e o relógio só zera depois de
confirmado. O aviso na tela mostra tempo de sessão, próximo pagamento, total
recebido e se está salvando. O servidor dedicado com renovação a cada 15
minutos (para evitar a desconexão por inatividade) ainda **não** existe: exige
lugar publicado e teste real de mais de uma hora.

## Heróis e habilidades

36 heróis em 5 raridades (Comum → Mítico). Um herói só chega à conta por um
dos cinco baús de heróis ou pela compra direta na Loja Robux — **não existe
compra direta por Ouro**. Cada herói tem uma única habilidade ativa; em
combate, a habilidade usada é sempre a do herói no **slot 1** da formação
(por isso o slot 1 é visualmente diferenciado na interface — é o único slot
que decide o que o botão de habilidade no canto da tela faz). Trocar o
herói do slot 1 troca instantaneamente qual habilidade está em jogo.

Toda habilidade tem 5 ranks, melhorados com Ouro e maestria do herói
(`Rules.AbilityUpgrade`); o custo é multiplicado pela raridade do herói, e
raridades mais altas custam desproporcionalmente mais para melhorar —
compensado pelo fato de a habilidade em si já ser muito mais forte.

**Habilidades lendárias e míticas são ultimates**: além do efeito principal,
elas disparam um ou mais efeitos secundários (`extras` no catálogo) no mesmo
cast — por exemplo, a Nova Fotônica da Capitã Marvel causa dano em quase todo
o mapa, paralisa os alvos e os marca para dano extra, tudo num único cast.
Visualmente, um ultimate dispara um pilar de luz e ondas de choque em
sequência (`Effects:_ultimateBurst`), maior tremor de câmera, e uma cor
distinta por efeito secundário, para que o jogador leia o que aconteceu sem
precisar ler texto.

## Baús (`Catalog.Chests`)

A expansão **2026.4** adiciona Suprimentos, Épico e Cósmico, além de cinco
baús equivalentes de bases. Há 11 bases equipáveis, fazenda de Energia,
canhões, barricadas e soldados. [BASES.md](BASES.md) contém a tabela atual
dos dez baús e substitui as referências históricas a apenas dois abaixo.

| Baú | Custo | O que vem |
| --- | --- | --- |
| Raro | 1.000 Ouro | Comum 34%, Raro 44%, Épico 20%, Lendário 2%; sem Mítico |
| Lendário | 2.000 Ouro (o dobro do Raro) | Raro 30%, Épico 42%, Lendário 22%, Mítico 6%; sem Comum |

Um baú prioriza heróis que a conta ainda não tem, dentro da raridade
sorteada; repetidos viram Ouro e maestria (mais generosos quanto mais rara a
raridade). No baú Lendário, nove aberturas seguidas sem Lendário/Mítico
ativam a garantia na décima. Essa abertura recalcula e exibe as chances
apenas entre as raridades elegíveis; as porcentagens da tabela são as normais.

A loja mostra saldo, preço, resumo por raridade e galeria com retratos e
chances individuais. A confirmação informa o custo e o saldo restante;
cancelar não manda uma solicitação de compra. O resultado vem do servidor,
com identificação de novo herói ou compensação por repetido.

## Prêmios diários

Quatro pequenos laços de retorno, todos decididos pelo relógio do servidor
(`Catalog.Rewards`, `Rules.RewardsStatus`), nenhum comprável:

- **Baú grátis** a cada 6 horas.
- **Sequência de login**: uma recompensa por dia civil (UTC); faltar um dia é
  perdoado, faltar dois reinicia a sequência. Sete dias no ciclo, o sétimo
  abre um baú.
- **Presentes por tempo jogado**: seis marcos ao longo do dia, o maior deles
  também abre um baú.
- **Metas de coleção**: oito marcos por quantidade de heróis diferentes
  possuídos, os dois últimos concedem título.

## Árvore de evolução (talentos de conta)

Um ponto por nível de conta acima do primeiro (até 49 no nível 50), gastos em
uma árvore com três ramos (Fortuna, Guardião, Comando) mostrada como tela,
não como objeto físico no mundo. Redistribuição é gratuita, com confirmação.

## Economia

Ouro é persistente (conta); Energia é por partida (gasta em torres,
melhorias e habilidades). Moedas de inimigos derrotados podem ser coletadas
andando até elas; Ouro não coletado ao fim da partida ainda é creditado.

## O que NÃO existe (removido do plano original)

- Modo Difícil (substituído por Ranqueado) e o antigo tutorial obrigatório.
- Desafio diário e investida de chefes (boss rush) — removidos.
- Compra direta de herói por Ouro — heróis só vêm de baú ou Robux.
- Escolha manual de mapa — o servidor sempre sorteia.

## Ver também

- `docs/HEROES.md` — referência gerada de todos os heróis e habilidades.
- `docs/BALANCE.md` — como o balanceamento é medido e os números atuais.
- `IMPLEMENTATION.md` — contrato técnico entre cliente e servidor.
