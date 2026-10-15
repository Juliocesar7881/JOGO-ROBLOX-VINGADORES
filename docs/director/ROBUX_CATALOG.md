# Robux — preços atuais (15/10/2026)

**15/10/2026: preços aumentados para os valores comuns no Roblox (pedido do
dono).** Os 55 itens foram alterados no Creator Hub (universo 10768165352) e
conferidos nas listas de produtos e passes; `Catalog.Products` tem os mesmos
valores (commit 81416c1). O jogador continua vendo a cotação regional do Roblox.

| Item | Antes | Agora |
|---|---:|---:|
| Herói Comum (14 produtos) | 9 | 49 |
| Herói Raro (15 produtos) | 29 | 149 |
| Herói Lendário (12 produtos) | 79 | 399 |
| Drone coletor, Velocidade 3x (passes) | 19 | 99 |
| Treinamento acelerado (passe) | 29 | 99 |
| Pacote VIP (passe) | 29 | 199 |
| Passe de Temporada permanente (passe antigo) | 49 | 499 |
| 1.000 / 5.000 / 12.000 / 30.000 de Ouro | 5 / 19 / 39 / 79 | 25 / 99 / 199 / 399 |
| Pacote Inicial | 19 | 99 |
| Ouro em dobro • 1 hora | 29 | 49 |
| Passe da Temporada (por temporada) | 49 | 199 |
| Pacote Equipe | 49 | 299 |
| Pacote Lendário | 99 | 499 |

O passe permanente da temporada ficou acima do passe por temporada para não
competir com ele; a análise de lançamento recomenda tirá-lo de venda.

# Robux — configuração executada em 12/10/2026

**41/41 heróis, cinco passes e cinco consumíveis cadastrados.** Os cinco
passes estão à venda, incluindo VIP e Temporada. Preços padrão menores,
nomes atuais e descrições atualizados no Creator Hub; IDs reais em Config.
Heróis Comum/Raro/Lendário: 9/29/79 Robux. Passes 19–49; pacotes 5–79.
O cliente mostra a cotação regional do Roblox, não o preço antigo do servidor.

**14/10/2026, 22h (UTC-3): os quatro produtos abaixo foram criados no Creator Hub
oficial (universo 10768165352, Managed Pricing ligado, Brasil com preço regional)
e os IDs estão no `Config`:** `goldBoost` = 3718674787 (29), `seasonPass` =
3718674866 (49), `legendaryBundle` = 3718674909 (99), `teamBundle` = 3718675077
(49). Nome do boost no Hub: "Ouro em dobro - 1 hora" (sem o ponto do meio).
Nenhuma compra de teste real foi feita; o fluxo de recibo de cada um tem teste
em `tests/player_service.spec.luau`. A loja só desenha produtos com ID real no
`Config`. Falta: ícone de cada produto (o dono) e publicar o place com este
`Config` (Studio estava fechado).

**Produto novo a cadastrar (14/10/2026):** `goldBoost` — "Ouro em dobro • 1 hora",
Developer Product, preço sugerido **29 Robux**, descrição "Por uma hora, cada
onda e cada vitória pagam o dobro de Ouro. Comprar de novo soma mais uma hora."
Depois de criar, pôr o ID em `Config.Products.Consumables.goldBoost` (hoje 0:
a loja mostra "Indisponível" até lá). O servidor já entrega e aplica o boost
(`profile.boostUntil`), com teste.

**Produto novo a cadastrar (14/10/2026):** `seasonPass` — "Passe da Temporada",
Developer Product, preço sugerido **49 Robux**, descrição "Trilha premium desta
temporada: o dobro de Ouro, mais baús, um título e o herói brilhante da
temporada no nível 30." ID em `Config.Products.Consumables.seasonPass`. Um
produto só, reutilizado a cada temporada: a compra abre a trilha premium da
temporada que está rodando (`profile.season.premium`) e some com a troca de
temporada. O game pass permanente `Passes.season` continua valendo em toda
temporada para quem já comprou; pode ser retirado de venda no Creator Hub
quando o produto existir. O herói de cada temporada está em
`Catalog.SeasonThemes[i].hero` (nível 30 da trilha premium, cópia brilhante).

**Produtos novos a cadastrar (14/10/2026):** `legendaryBundle` — "Pacote
Lendário", Developer Product, **99 Robux**, descrição "Um herói lendário à sua
escolha + 12.000 de Ouro."; `teamBundle` — "Pacote Equipe", Developer Product,
**49 Robux**, descrição "Três heróis raros à sua escolha." IDs em
`Config.Products.Consumables.legendaryBundle` / `.teamBundle`. O recibo paga o
Ouro e credita escolhas por raridade (`profile.heroPicks`); o jogador escolhe
no painel "Escolha seu Herói" (ação `PickHero`), herói já possuído vira
estrela e Ouro como duplicata.

Registro vigente e evidências: [CONFIGURACAO_COMERCIAL_2026-10-12.md](../CONFIGURACAO_COMERCIAL_2026-10-12.md).
Exportação completa: `assets/store/release-2026-10-12/catalog.json`.
Metadados salvos não comprovam compra real. Nenhum contrato foi aceito ou taxa
paga automaticamente. Os registros abaixo são históricos, não instruções
para recadastrar produtos nem aplicar os preços antigos.

## Registro histórico — 01/10/2026

# Robux — o que existe no Creator Hub (01/10/2026)

Atualização de 11/10: a coleção foi unificada em Comum/Raro/Lendário.
Os preços individuais existentes foram preservados, sem alterar o Creator
Hub. As referências a preços por cinco raridades abaixo são históricas;
para um produto novo, consulte `Catalog.Products.Heroes[heroId].price`.

Experiência: Multiverse Doomsday Tower Defense (universe 10768165352).
Conta: LoopsDev7881. IDs já gravados em `src/shared/Config.luau`
(`Products.Passes`, `Products.Consumables`, `Products.Heroes`).
**Managed Pricing ficou desligado em tudo** (ligar exige aceitar termos do
Roblox: decisão do dono).

## Passes (4 de 5 criados)

| Chave | Nome | Preço | ID | Estado |
|---|---|---|---|---|
| speed3 | Velocidade 3x | 149 | 2001776936 | à venda |
| collector | Drone coletor | 149 | 2004326420 | à venda |
| training | Treinamento acelerado | 199 | 2001722936 | à venda |
| vip | Pacote VIP visual | 299 | 2003954466 | **criado, preço NÃO ligado** |
| season | Passe de Temporada | 399 | 0 | **falta criar** (no código desde 01/10; a loja mostra "Indisponível" até lá) |

Falta (dono): Creator Hub → Monetização → Passes → Pacote VIP visual →
Vendas → ligar "Item for sale" e pôr 299 → Save Changes. Até lá a loja do
jogo mostra "Preço indisponível" para o VIP (sem erro).

## Produtos de desenvolvedor — Ouro e Pacote Inicial (5 de 5)

| Chave | Nome | Preço | ID |
|---|---|---|---|
| starterPack | Pacote Inicial | 99 | 3715833256 |
| gold1000 | 1.000 de Ouro | 79 | 3715833438 |
| gold5000 | 5.000 de Ouro | 299 | 3715833690 |
| gold12000 | 12.000 de Ouro | 599 | 3715833842 |
| gold30000 | 30.000 de Ouro | 1299 | 3715833975 |

## Produtos de desenvolvedor — heróis (15 de 34)

Criados (preço por raridade: comum 79, raro 199, épico 449):

| Herói | Preço | ID |
|---|---|---|
| falcon (Cotovia) | 79 | 3715834320 |
| bucky (Sargento Prata) | 79 | 3715834397 |
| spiderman (Laçadora) | 199 | 3715834470 |
| widow (Sombra) | 199 | 3715834541 |
| antman (nome no Roblox: Pocket Titan*) | 199 | 3715834624 |
| wasp (Pirilampo) | 199 | 3715834861 |
| rocket (Guaxo) | 199 | 3715834932 |
| daredevil (Eco) | 199 | 3715835002 |
| shangchi (Rin) | 199 | 3715835053 |
| captain (Comandante Égide) | 449 | 3715835121 |
| panther (Ônix) | 449 | 3715835190 |
| hulk (Pedregulho) | 449 | 3715835244 |
| vision (Prisma) | 449 | 3715835303 |
| warmachine (Bigorna) | 449 | 3715835379 |
| starlord (Cometa) | 449 | 3715835477 |

\* O filtro de texto do Roblox censurou "Titã de Bolso" (nome e descrição
viraram `#####`); o produto foi renomeado para "Pocket Titan". O nome dentro
do jogo continua o do Catálogo.

**Faltam 19** (todos ainda sem ID no Config, portanto "indisponíveis" na loja):
groot (Carvalho, 449), thor (Brontus, 999), wanda (Rubi, 999),
strange (Arcano, 999), ghostrider (Cavaleiro Brasa, 999),
captainmarvel (Solaria, 1999), silversurfer (Órbita, 1999),
wolverine (Presa, 449), cyclops (Farol, 199), storm (Monção, 999),
jean (Aurora, 1999), iceman (Geada, 199), gambit (Ás, 449),
nightcrawler (Pisca, 199), beast (Juba, 199), psylocke (Kunai, 449),
deadpool (Confete, 449), moonknight (Eclipse, 199), nova (Pulsar, 999).

## Por que parou

Ao abrir o formulário do 16º produto o Creator Hub mostrou "Updated
Agreements" (Termos de Serviço e Política de Privacidade do Roblox, em vigor
em 01/11/2026) com **Agree / Reject**. Aceitar termos é decisão do dono, então
a criação parou. Com o aviso aceito, retomar:
1. Abrir `…/developer-products/create` e repetir o fluxo: nome, descrição,
   categoria "Others", preço da raridade, **Managed pricing desligado**, Save.
2. Ler o ID na lista e gravar em `Config.Products.Heroes`.
3. Evitar nomes que o filtro de texto possa censurar (conferir a lista depois
   de salvar: nome aparecendo como `#####` = renomear).

## Pontos de atenção

- Pacote Inicial: o servidor concede o herói **uma vez** por conta
  (`profile.starterPack`); a segunda compra paga só Ouro. Conferir com uma
  conta de teste antes de divulgar.
- Nenhuma compra real foi feita. O teste de compra com conta alternativa fica
  no `docs/RELEASE_CHECKLIST.md`.

## Atenção: nomes mudaram (01/10 noite)

Os 36 heróis foram renomeados e há 7 heróis novos. O jogo mostra os nomes do
`Catalog.luau`, mas o **nome do produto no Creator Hub** é o que aparece na tela
de compra do Roblox: renomeie os 15 produtos já criados para o nome novo de
`docs/HEROES.md` (ex.: "Pocket Titan" → "Tiny Man"). Produtos novos a criar
(IDs 0 até lá; a loja mostra "Indisponível"): Capitão Men (449), Amazona
Dourada (449), Rei dos Mares (449), Caçador da Noite (449, 02/10), Guardião Verde
(999), Velocista Rubro (999), Titã Solar (1.999). São 7 heróis novos no total.
