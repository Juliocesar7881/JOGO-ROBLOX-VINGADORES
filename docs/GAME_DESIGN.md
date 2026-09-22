# Design do jogo (estado atual)

Este documento descreve o jogo **como o código está implementado hoje**, não
o plano original. Para os números exatos, o código-fonte é sempre a
referência: `src/shared/Catalog.luau` (dados) e `src/shared/Rules.luau`
(regras). `docs/HEROES.md` é gerado direto do catálogo e nunca fica
desatualizado; use-o para qualquer número de herói/habilidade específico.

## O laço principal

1. O lobby tem quatro portais, dois baús, loja Robux, missões e placar.
   As exposições de heróis foram removidas; a coleção continua no HUD.
   Pisar na área verde de um baú abre sua loja sem gastar Ouro. É preciso
   confirmar a abertura para pagar. Sair e voltar à área permite reabrir;
   ficar parado depois de fechar não força o menu novamente. O botão de
   proximidade permanece como alternativa. Andar para longe fecha o painel.
2. Cada portal é um elevador: entrar nele começa uma contagem regressiva;
   quem entra junto vai para o mesmo grupo (até 4). O servidor **sorteia o
   mapa** entre os cinco disponíveis a cada partida — o jogador nunca escolhe
   o mapa diretamente.
3. Uma partida (exceto Infinito) tem sempre **50 ondas**, com um chefe a
   cada 10 (ondas 10/20/30/40) e o chefe final, mais forte, na onda 50.
4. Ao vencer ou perder, Ouro/XP ganhos na partida são creditados
   imediatamente; a conta nunca perde progresso por queda de conexão (ver
   `RejoinService` em `IMPLEMENTATION.md`).

## Modos (`Catalog.Modes`, portais em `Catalog.PortalOrder`)

| Modo | Ondas | Multiplicador de vida | Recompensa | Desbloqueio |
| --- | --- | --- | --- | --- |
| Treinamento | 8 | 0.6× | 1× | Sempre disponível, opcional (Opções → Aprender a jogar) |
| Campanha (`normal`) | 50 | 1.2× | 1× | Sempre disponível |
| Ranqueado (`ranked`) | 50 | 1.45× | 1.5× | Após vencer a Campanha |
| Cartas (`cards`) | 50 | 1.6× | 1.25× | Após vencer a Campanha |
| Infinito (`infinite`) | sem fim | 1.1× | 1× | Após vencer o Ranqueado |

Ranqueado é o modo mais difícil por design (ver `docs/BALANCE.md`): é ele que
alimenta o rank sazonal (`Rules.RankForWaves`, placar por
mapa/tamanho/temporada). Cartas é um roguelike leve: a cada 5 ondas
completas o comandante escolhe uma de três cartas (`Catalog.Cards`, 23
cartas em `Catalog.CardOrder`) que altera a partida em andamento — dano,
alcance, economia, ou um evento instantâneo (cura, Energia, aposta).

## Mapas (`Catalog.MapOrder`)

Manhattan (ruas em zigue-zague), Complexo Gama (braços do reator), HYDRA
(corredores industriais alternados), Fronteira de Wakanda (espiral na
savana) e Fortaleza da Latvéria (três entradas na neve) — cada um com seu
próprio chefe (`bossId`), paleta de iluminação e rota. O mapa de uma partida
é sempre sorteado pelo servidor; nenhum modo deixa escolher.

## Heróis e habilidades

24 heróis em 5 raridades (Comum → Mítico). Um herói só chega à conta por um
dos dois baús do lobby ou pela compra direta na Loja Robux — **não existe
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
