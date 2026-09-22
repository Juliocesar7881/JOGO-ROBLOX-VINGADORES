# Referências de interface — Doomsday

Pesquisa em 22/09/2026 para orientar o acabamento do HUD. São referências de organização e clareza; nenhum ícone, imagem, som, textura ou composição de outro jogo é incorporado ao projeto. Os componentes continuam próprios, feitos em Luau.

## Evidência consultada

| Referência | O que a fonte permite observar | Aplicação proposta para Doomsday |
|---|---|---|
| **Adopt Me!** | A imagem oficial mostra itens ilustrados e numerados no rodapé, moeda separada e centro livre. A notícia descreve toque para equipar e atalhos no computador. | Retratos dos heróis na barra, botões fáceis de tocar e atalhos discretos; preservar o cenário no centro. [Notícia e imagem oficiais](https://www.playadopt.me/news/profile-and-qol-improvements) |
| **Pet Simulator 99** | O criador documenta equipes salvas, acesso às equipes pelo inventário e páginas ajustadas ao dispositivo. | Equipe atual e coleção claramente separadas; mostrar o herói equipado antes das opções de compra. [BIG Games: Heaven Update](https://www.biggames.io/post/pet-simulator-99-update-5) |
| **Tower Defense Simulator** | A documentação do Roblox apresenta uma captura da loja e explica o agrupamento por tamanho e proximidade. | Separar visualmente tipo de baú, conteúdo, preço e ação. [Roblox: seção Attention](https://create.roblox.com/docs/production/game-design/ui-ux-design#attention) |
| **DOORS** | O Roblox inclui seu botão de fechar entre exemplos da convenção de um X reconhecível. | Fechamento consistente no canto de cada painel, acessível sem rolar. [Roblox: seção Conventions](https://create.roblox.com/docs/production/game-design/ui-ux-design#conventions) |
| **Jailbreak** | O exemplo oficial distingue uma categoria de recompensas com uma faixa dourada. | Cor e faixa para reconhecer a categoria; incluir texto para não depender apenas da cor. [Roblox: seção Attention](https://create.roblox.com/docs/production/game-design/ui-ux-design#attention) |
| **Dragon Adventures** | O exemplo oficial destaca um cartão usando tamanho e espaço ao redor. | Dar maior presença à ação principal e ao líder da equipe. [Roblox: seção Attention](https://create.roblox.com/docs/production/game-design/ui-ux-design#attention) |
| **BotClash Simulator** | Seus botões ilustram profundidade e um contorno visual reconhecível. | Botões arredondados com contraste, estados de seleção e resposta breve ao toque. [Roblox: seção Buttons](https://create.roblox.com/docs/production/game-design/ui-ux-design#buttons) |
| **Winds of Fortune** | A documentação usa seus ícones de atributos como exemplo de linguagem visual coerente. | Vida, Energia e Ouro usam ícone, nome e cor constantes. [Roblox: seção Icons](https://create.roblox.com/docs/production/game-design/ui-ux-design#icons) |

**Blox Fruits** também faz parte da referência de progressão pedida pelo usuário. O [site oficial da Gamer Robot](https://gamerrobot.com/) foi consultado, mas o material acessível nesta pesquisa não comprovou o arranjo atual do HUD dentro do jogo. O acesso à evolução pelo HUD é uma decisão deste projeto e do pedido do usuário; não é apresentado aqui como uma reprodução verificada da interface atual de Blox Fruits.

As capturas e notícias registram versões específicas. Esta pesquisa não equivale a jogar a versão atual de cada experiência ou validar o desempenho de suas interfaces.

## Três refinamentos prioritários no código atual

1. **Leitura imediata da batalha.** Em `updateMatch`, manter Vida da base, Onda, Energia e Ouro claramente nomeados. Energia não deve competir com o contador de limite de torres. O poder deve indicar o líder, quando está pronto e o tempo restante de recarga. Proposta: azul para Energia, dourado para Ouro, verde para vida saudável; perigo também precisa de texto ou símbolo.
2. **Ações sempre alcançáveis.** Em `renderContext`, `towerPanel` e `renderResults`, reservar espaço fixo para fechar e concluir. A rolagem contém informações, mas não esconde o único retorno ao lobby. Em telas baixas, usar um painel maior que substitui temporariamente a navegação e mantém o botão de fechar visível.
3. **Coleção com personalidade e função.** Em `contextInventory` e na barra de combate, usar retratos, nome legível, seleção evidente e primeiro espaço identificado como LÍDER. O botão de poder precisa corresponder a esse retrato. Animações curtas de abertura e confirmação dão resposta ao toque; o estado final deve permanecer legível sem depender da animação.

Esses refinamentos são propostas próprias a partir das referências e da inspeção do código. A implementação e os testes realizados ficam no registro de entrega; este documento não declara funcionalidades concluídas.

## Critério visual da entrega

- Uma criança consegue encontrar JOGAR, HERÓIS e EVOLUÇÃO sem ler um parágrafo.
- Os botões exibem verbos simples e têm área confortável para toque.
- O cenário continua visível durante a partida.
- Menus, cartas e resultados têm hierarquia clara; textos essenciais não ficam cortados.
- Celebrações são breves e a opção de reduzir efeitos continua respeitada.
- A loja mostra moeda, preço, conteúdo e probabilidades antes da confirmação.

