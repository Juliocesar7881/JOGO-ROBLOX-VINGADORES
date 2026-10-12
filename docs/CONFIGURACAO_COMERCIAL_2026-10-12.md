# Configuração comercial e descoberta — 12/10/2026

Destino único: **Multiverse Doomsday Tower Defense**, universo **10768165352**,
place **97132875544830**. O pedido do dono autoriza preços menores, cadastros,
metadados e publicação no projeto oficial; nenhuma cópia foi criada.

## Preços e produtos cadastrados

Foram cadastrados os 26 produtos de heróis restantes e o Passe de Temporada.
Os produtos anteriores foram atualizados, sem criar IDs duplicados. Todos os
51 itens têm IDs reais em `Config.Products`, nomes/descrições conferidos e
preços reduzidos no Creator Hub:

- Heróis compráveis: **Comum 9, Raro 29, Lendário 79 Robux**. São 41 produtos;
  os dois heróis iniciais continuam gratuitos.
- Passes: Drone **19**, Velocidade 3x **19**, Treinamento **29**, VIP **29**,
  Temporada **49 Robux**. Os cinco estão à venda; o VIP foi ativado.
- Ouro: **1.000 por 5**, **5.000 por 19**, **12.000 por 39**, **30.000 por 79**.
  Pacote Inicial: **19 Robux**.

Esses são os preços padrão. O cliente consulta o preço que o Roblox oferece
ao jogador, inclusive preços regionais. O servidor continua decidindo item,
posse, política e entrega; a tela não anuncia um preço global antigo.
“Melhor valor” usa a cotação real e “Sugestão” não alega popularidade medida.
Os botões dizem Robux, sem confundir a moeda com reais brasileiros.

Custos em Ouro, quantidades dos pacotes, chances dos baús e progressão foram
preservados. A compensação existente para recompra direta de herói já possuído
continua derivada do preço Robux; acompanha a redução desse preço.

O filtro do Roblox ocultou o antigo nome de `solartitan`; **Guardião Solar /
Solar Guardian** foi salvo e conferido no mesmo produto. Chave interna,
propriedade, poderes e atributos foram preservados.

## Página e idiomas

Título: **Multiverse Doomsday Tower Defense**. Descrição base em inglês,
descrições manuais em português e espanhol e tradução automática da informação
da experiência e dos produtos habilitada para **17 idiomas de destino**.
O título, descrições e registro completo estão em
`assets/store/release-2026-10-12/`.

A descrição informa o conteúdo existente: 43 heróis, seis mapas, solo/equipe
de até quatro jogadores, campanha, Cartas, competitivo, missões, evolução,
comando Q e controles móveis. Sem palavras-chave repetidas, números inventados
de popularidade ou promessa de recompensa que o jogo não entrega.
Gênero Strategy / Tower Defense preservado. Exclusão das recomendações está
desmarcada; classificação de conteúdo **Minimal**, questionário preenchido.
Ícone e miniatura atuais já usam a apresentação limpa de `assets/store/`.

## Alcance que ainda depende da conta do dono

O painel mostra **Public**, com alcance **16+ e amigos de confiança**.
Para ampliar, a própria conta ainda exige **verificação de identidade** e
**autenticação em duas etapas**. A verificação de idade por câmera aparece
concluída. O painel de alcance também mostra taxa reembolsável não submetida
e alternativa de engajamento em **0/250 jogadores altamente engajados**.
A opção de revisão acelerada de 50.000 Robux é separada e opcional.

Não foram enviados documentos, digitadas credenciais, aceitos contratos ou
declarações de direitos, nem pagas taxas/compras. Esses passos pessoais não
podem ser concluídos automaticamente. Não declarar alcance para todas as
idades, retorno financeiro ou viralização como garantidos.

## Validação e entrega

O auditor encontra **41/41 produtos de herói e nenhum ID faltante**. Testes
de recibos usam o PlayerService real contra armazenamento simulado: cada ID
oficial de herói entrega o herói correto e repetir o recibo não entrega duas
vezes. Testes do cliente verificam preço regional divergente do servidor,
produto fora de venda, nova tentativa e comparação de pacotes em seis telas.


Código **b089b43** enviado ao `main` e publicado no lugar oficial em
**12/10/2026 às 14:12:16 local (17:12:16 UTC)**. `Go to PublishSuccessful`
confirmado no log do Studio. Quatro módulos sincronizados seletivamente;
40 fontes comparadas com o repositório, prefixo de papel preservado e lobby
reconstruído com **4.481 peças**, abaixo do teto de 4.500.

Suíte completa **exit 0 em 63,83 s**; PlayerService com **910 asserções**,
incluindo entrega/replay dos 41 IDs oficiais. Revisão nativa em seis cenas,
14 capturas finais em PC PT, PC EN e vertical 375×667 EN, sem erro/overflow
acusado pela ferramenta. Compras ficam desativadas no perfil temporário do
Studio; essas imagens comprovam layout, não uma transação real.

MarketplaceService confirmou os **51 IDs/nomes à venda**. As cotações
consultadas não excedem os preços padrão; alguns itens já retornam valor
menor. Não apresentar a cotação de uma sessão como preço universal.
Nenhuma compra real foi realizada.

**Shop nativo publicado**, confirmado por “Shop published”: todos os 51
itens listados, organizados em **Heróis / Heroes (41), Passes (5), Ouro /
Gold (4) e Pacotes / Packs (1)**. O botão global adicional permanece
desligado; a navegação própria do jogo já tem a loja.

Depois da publicação, o Studio perdeu acesso ao mesmo lugar com **RCC-273**
(“Você não tem mais acesso a esta experiência”). A reconexão não restabeleceu
a sessão. Isso impediu concluir os ícones externos individuais planejados;
o protótipo foi rejeitado e não foi enviado. Arte própria da loja interna,
ícone e miniatura existentes da experiência permanecem. O Studio terminou
na Home; não declarar que foi deixado no lugar em modo de edição.

Evidências: `test-results/galerias/Configuracao_Comercial_2026-10-12/INDICE.html`,
`publication.json`, `evidence.json` e `commerce-marketplace.json`. As pendências
pessoais e os testes reais continuam no checklist de lançamento.

## Registro completo

| Chave | Nome no catálogo | Preço padrão (Robux) | ID Roblox |
|---|---|---|---|
| Passes.training | Treinamento acelerado | 29 | 2001722936 |
| Passes.speed3 | Velocidade 3x | 19 | 2001776936 |
| Passes.season | Passe de Temporada | 49 | 2026575250 |
| Passes.collector | Drone coletor | 19 | 2004326420 |
| Passes.vip | Pacote VIP visual | 29 | 2003954466 |
| Consumables.gold12000 | 12.000 de Ouro | 39 | 3715833842 |
| Consumables.gold30000 | 30.000 de Ouro | 79 | 3715833975 |
| Consumables.gold5000 | 5.000 de Ouro | 19 | 3715833690 |
| Consumables.gold1000 | 1.000 de Ouro | 5 | 3715833438 |
| Consumables.starterPack | Pacote Inicial | 19 | 3715833256 |
| Heroes.deadpool | Mercenário Falante | 29 | 3718186419 |
| Heroes.jean | Psíquica Radiante | 79 | 3718186464 |
| Heroes.amazon | Amazona Dourada | 29 | 3718184374 |
| Heroes.warmachine | Soldado Blindado | 29 | 3715835379 |
| Heroes.storm | Deusa do Clima | 79 | 3718186499 |
| Heroes.cyclops | Olho Rubi | 9 | 3718186531 |
| Heroes.silversurfer | Surfista Cósmico | 79 | 3718186558 |
| Heroes.daredevil | Vigilante Cego | 9 | 3715835002 |
| Heroes.psylocke | Ninja Psíquica | 29 | 3718186588 |
| Heroes.ghostrider | Motoqueiro Chama | 79 | 3718186629 |
| Heroes.captain | Capitão Escudo | 29 | 3715835121 |
| Heroes.thor | Deus do Trovão | 79 | 3718186668 |
| Heroes.speedster | Velocista Rubro | 79 | 3718186702 |
| Heroes.wanda | Bruxa do Caos | 79 | 3718186734 |
| Heroes.beast | Acrobata Peludo | 9 | 3718186763 |
| Heroes.bucky | Soldado de Prata | 9 | 3715834397 |
| Heroes.rocket | Guaxinim Atirador | 9 | 3715834932 |
| Heroes.spiderman | Aranha Urbana | 9 | 3715834470 |
| Heroes.wasp | Abelha Rainha | 9 | 3715834861 |
| Heroes.gambit | Mestre das Cartas | 29 | 3718186805 |
| Heroes.widow | Viúva Sombria | 9 | 3715834541 |
| Heroes.nightstalker | Caçador da Noite | 29 | 3718186834 |
| Heroes.capmen | Capitão Men | 29 | 3718186861 |
| Heroes.solartitan | Guardião Solar | 79 | 3718186894 |
| Heroes.falcon | Homem-Asa | 9 | 3715834320 |
| Heroes.nightcrawler | Teleportador Azul | 9 | 3718187550 |
| Heroes.antman | Homem Miúdo | 9 | 3715834624 |
| Heroes.vision | Androide Prisma | 29 | 3715835303 |
| Heroes.panther | Rei Pantera | 29 | 3715835190 |
| Heroes.nova | Guardião Cósmico | 79 | 3718187579 |
| Heroes.shangchi | Mestre dos Anéis | 9 | 3715835053 |
| Heroes.strange | Doutor Místico | 79 | 3718187623 |
| Heroes.moonknight | Cavaleiro Lunar | 9 | 3718187669 |
| Heroes.starlord | Pirata Estelar | 29 | 3715835477 |
| Heroes.wolverine | Garra de Aço | 29 | 3718187710 |
| Heroes.hulk | Gigante Furioso | 29 | 3715835244 |
| Heroes.iceman | Gelo Vivo | 9 | 3718187741 |
| Heroes.groot | Gigante Verde | 29 | 3718187771 |
| Heroes.emerald | Guardião Verde | 79 | 3718187811 |
| Heroes.captainmarvel | Capitã Estelar | 79 | 3718187847 |
| Heroes.seaking | Rei dos Mares | 29 | 3718187883 |

## Referências da plataforma

- [Preços regionais e consulta no cliente](https://create.roblox.com/docs/production/monetization/regional-pricing)
- [Shop e catálogo](https://create.roblox.com/docs/production/monetization/shop)
- [Recibos de produtos](https://create.roblox.com/docs/production/monetization/developer-products)
- [Traduções](https://create.roblox.com/docs/production/localization/add-translations)
- [Descoberta](https://create.roblox.com/docs/discovery)
- [Requisitos de publicação e alcance](https://create.roblox.com/docs/production/publishing/publish-games-and-places)
