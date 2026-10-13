# Placas do lobby e carregamento de preços — 12/10/2026

Pedido: corrigir placas viradas/deslocadas, estrela do salão da fama,
hierarquia de Missões/Equipe/Bases e preços que permaneciam carregando.

## Implementação

- Os seis balcões usam a mesma montagem: tela entre os postes, atrás da
  bancada, com suporte que encontra fisicamente o painel. A face legível
  aponta para a praça; o painel de Mapas não fica mais à frente do balcão.
- Títulos curtos com fonte de destaque e cor do serviço; descrição/status
  separados. Missões mantém o título e informa apenas o estado pessoal,
  com singular/plural correto. O salão mostra um recorde; a lista completa
  continua na janela de classificação.
- Todas as peças dos emblemas, inclusive triângulos e núcleo das estrelas,
  recebem a mesma animação. O modo Menos efeitos continua respeitado.
- Consultas de preço independentes, até três em andamento, prioridade para
  a aba aberta e atualização conforme chegam. Após 12 s sem resposta, o
  item permite tentar novamente; uma resposta atrasada não sobrescreve a
  tentativa nova. Preços continuam sendo os regionais retornados ao cliente.
- Pacote inicial diferencia carregando, tentar novamente e indisponível.
  Perfis temporários do Studio podem consultar preços reais com indicação
  de teste; prompts e processamento de compras permanecem bloqueados nesse
  modo. IDs, preços cadastrados, política regional e economia preservados.

## Verificação

Regressões: orientação e apoio físico das seis placas, título/status,
localização, estrela acompanhando o pódio, consulta lenta, troca de aba,
timeout, tentativa nova, resposta atrasada e bloqueio de compra em preview.
`tools/test.py` verifica também compilação, economia, recibos e os seis
formatos completos do cliente; saída final em
`test-results/lobby-prices-20261012/full-suite.txt`.

No playtest oficial: seis placas fotografadas, estrela deslocando-se com
offset constante em relação ao pódio, e 42 itens da aba Heróis/pacote inicial
com preço real, zero carregando/retry/indisponíveis após conclusão. Consultas
reais adicionais confirmaram VIP 29, Ouro 1.000 por 5 e pacote inicial 19
Robux. Isso verifica consulta/exibição; nenhuma compra foi realizada.

Capturas ficam em
`test-results/galerias/Placas_Precos_2026-10-12/`, sem pasta no Desktop.
O lobby nativo ficou com 4.499 peças, dentro do limite de 4.500. Esse limite
tem pouca folga: próximas decorações devem substituir peças existentes.

## Colaboração e entrega

O repositório tinha o commit do Claude `28633ff` ainda não enviado e edições
locais em Effects, MatchHud, UI e rostos no WorldBuilder. Foram preservadas;
as fontes do Studio foram comparadas antes da sincronização. Nenhuma fonte
desconhecida de outra sessão foi substituída. O commit deste lote inclui
somente as correções solicitadas; as demais edições locais permanecem locais.

Seis módulos sincronizados seletivamente no place **97132875544830**;
o módulo novo é ProductQuotes. Conferência visual final e publicação em
andamento; a confirmação será registrada aqui e no LOG.
