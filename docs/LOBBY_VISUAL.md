# Refúgio da Aurora — revisão visual

## Entrega

- Praça de pedra com grama integrada, caminhos até portais e lojas, jardins,
  árvores na praça, fonte com cristal e pequena construção de vigia.
- Barracas com lonas listradas, madeira, caixas, lanternas e bandeirolas.
- Remoção das grandes vigas, piso de hangar, aeronaves e decoração de pista
  da montagem do lobby; floresta, cachoeira e portais preservados.
- Letreiros menores e iluminação mais quente.
- Menu inferior com ilustrações próprias de capacete, árvore de evolução,
  baú, moedas e presente. Os desenhos usam formas nativas da interface.
- Contador de Ouro com moeda ilustrada, cabeçalhos claros e cores de seção;
  fundos menos saturados e gradientes mais discretos.
- No celular em paisagem, a contagem do portal substitui temporariamente o
  menu inferior, mantendo o botão Sair e o conteúdo dos painéis acessíveis.

## Verificação

`python tools/test.py` passou após as alterações, incluindo 6.313 verificações
de layout, 2.358 do cliente, 3.443 de construção do mundo e 1.248 da simulação
de partidas. Os três arquivos em `dist/` foram regenerados.

O lobby foi inspecionado no renderer do Studio, inclusive o menu em uma área
de 640 × 302 pixels. Isso valida uma apresentação de tela pequena, não toque
ou desempenho em aparelho real. O lobby construído tem 2.023 peças, dentro
do orçamento existente de 3.500.

## Limites desta entrega

Esta revisão usa materiais do Roblox e geometria construída no projeto.
Não inclui texturas pintadas sob medida, animações novas de personagens ou
uma remodelagem completa de cada tela. Esses trabalhos continuam no plano
de arquitetura. Compras e serviços publicados mantêm suas validações próprias.
