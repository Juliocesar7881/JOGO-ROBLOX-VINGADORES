# Raridades e escolha da equipe — 11/10/2026

## Resultado

A coleção passa de cinco para **três raridades**:

| Raridade | Heróis | Bases | Origem |
|---|---:|---:|---|
| Comum | 16 | 5 | Antigos comuns e raros |
| Raro | 15 | 2 | Antigos épicos |
| Lendário | 12 | 4 | Antigos lendários e míticos |

Filtros, contornos, ficha, roleta, recibo, loja e sons usam os mesmos três
nomes e cores. As cartas de partida também usam Comum/Raro/Lendário;
suas chances continuam 60/30/10. Nenhum herói foi removido ou adicionado.

## Proteção da coleção e da economia

Não há migração destrutiva: posse, IDs, maestria, estrelas, cartas, ranks,
alocações, aparência brilhante, habilidades e equipe continuam nos mesmos
registros. Os preços de baús, compras garantidas, produtos existentes e
melhorias de habilidade foram preservados, assim como as compensações
individuais por repetidos. Atributos e especializações de combate não mudam.

Os grupos de aquisição originais continuam guardando chances individuais,
prioridade de itens novos, limiares de garantia e quais itens zeram o
contador. Unificar a cor não amplia a garantia Cósmica para outros itens
nem diminui o valor de um repetido que antes era mítico.

Um retrato recebe estrela quando pertence ao conjunto de destaque daquela
garantia. A lista usa `Rules.ChestOutcomes`, com a mesma seleção de grupos
de `RollChest`: chances mostradas acompanham posse e garantia ativa.

Os cinco baús conservam seus IDs e preços, com nomes mais distintos:
Suprimentos, Aliança, Vanguarda, Lendas e Cósmico. As duas coleções físicas
continuam separadas. Não houve alteração de preços ou configurações no
Creator Hub.

## Melhorias relacionadas

- Filtros de antiaéreo, área, controle e apoio para escolher pela função do
  ataque inicial. Especializações posteriores podem acrescentar funções.
- Contagem possuídos/total por raridade disponível na dica do filtro.
- Estado vazio com ação Limpar filtros, sem confundir ausência no filtro
  com ausência de heróis na conta.
- A roleta de um baú ganho usa apenas itens realmente disponíveis naquele
  baú, com os mesmos pesos; heróis iniciais não aparecem como prêmios falsos.
- Texto de repetidos informa Ouro, maestria, estrelas e cartas.
- Recibo de repetido confirma a compensação recebida, sem anunciar um novo
  herói na coleção.
- Três finais sonoros, com um final mais elaborado para os lendários;
  volumes limitados, cancelamento, mute e uma fanfarra por resultado.

## Validação

`tests/rarity_baseline.luau` registra o catálogo anterior (`a148e63`). A
regressão compara preços/compensações de todos os heróis e bases e a
sequência de **35.280 sorteios determinísticos**, incluindo quatro estados
de posse e garantia normal/ativa nos dez baús. Item entregue, repetido,
acionamento e reinício da garantia permanecem idênticos. As chances
efetivas somam 100%, excluem os iniciais e incluem cada resultado possível.

O teste real de PlayerService confere a entrega de repetido para os 43
heróis, conservando rank, cartas, alocação, habilidade e aparência.
Os seis roteiros do cliente verificam três filtros de raridade, contagens,
funções e ausência de gasto/mudança de equipe ao filtrar. A simulação de
200 mil aberturas por baú continua na suíte.

Primeira suíte completa: saída 0, 72,06 s; regras com 674.057 asserções,
PlayerService com 664 e cliente com 1.265–1.271 verificações por formato
antes das duas asserções adicionais do recibo.

36 capturas de nove cenas em PC/horizontal PT e PC/vertical EN, com saída
0 nas duas varreduras e nenhum erro/corte de texto reportado. Os painéis
com listas usam rolagem; itens fora da área da lista continuam acessíveis.
Os cliques reais verificaram 43 heróis, 24 antiaéreos, 29 de área, nove de
controle, dois de apoio e 12 lendários. Filtrar não alterou Ouro, número de
baús nem fase do perfil temporário. As três regiões Sonniss tocaram
carregadas, com uma fanfarra por raridade, cancelamento e mute verificados.

Galeria: `Desktop/Multiverse_Raridades_2026-10-11/INDICE.html`.
Evidências locais em `test-results/rarity-refinement/`. Nova suíte completa
após os ajustes do recibo/revisão: saída 0, 72,58 s, com 1.295–1.301
verificações por formato no cliente. Oito capturas adicionais do recibo e
quatro da roleta também passaram; a própria revisão usa prêmios elegíveis.
O baú grátis real levou o contador de 0 para 1, com uma fanfarra, retrato
visível e sem segunda abertura. Publicação conferida, conforme entrega abaixo.

Régua aplicada às telas alteradas: leitura 4, acabamento 4, consistência 4,
clareza 4 e recompensa 4. A avaliação não atribui nota nova ao combate ou
à anatomia dos modelos. Rolagem de listas continua necessária em telas
pequenas; testes nativos de aparelho continuam separados.

## Escopo

Esta entrega simplifica coleção e recrutamento. Não declara concluídos
anatomia dos modelos, combate, testes de celular físico, quatro jogadores,
teleporte e entrada fria em produção, já registrados na fila de lançamento.

## Entrega

Oito módulos sincronizados seletivamente no place **97132875544830**;
40 fontes comparadas, preservando o prefixo de papel existente no servidor.
Código `8cf1334` enviado ao `main`; suíte que condicionou o commit: saída 0,
71.89 s. Quatro destaques da garantia Cósmica conferidos por clique
real, preservando o limiar de 15. Recibo e roleta refeitos após os ajustes;
48 capturas totais nas varreduras, sem erros/cortes de texto reportados.

Lobby de edição reconstruído com 4.433 peças, dentro do orçamento; 40
fontes comparadas novamente antes de publicar. Publicado no mesmo place
**97132875544830 em 11/10/2026 às 16:47:04 local (19:47:04 UTC)**, com
`Go to PublishSuccessful` novo confirmado no log do Studio. Studio em edição.
Evidência de publicação: `test-results/rarity-refinement/publication.json` e
na galeria do Desktop. Configurações da experiência e Creator Hub preservados.
