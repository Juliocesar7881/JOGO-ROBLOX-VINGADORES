# Direção de arte

Referência curta para manter o jogo consistente. Vale para heróis, inimigos,
chefes, lobby e interface. Tudo é construído por código (sem modelos da
Toolbox); a arte final feita no Studio entra por `assets/models` e substitui
o modelo gerado sem mudar regras.

## Identidade

Aventura de quadrinhos dos Vingadores com **proporções de avatar Roblox**:
corpo articulado em blocos, cabeça clássica arredondada, cores de uniforme
fortes e poucos detalhes, mas intencionais. O jogador deve reconhecer cada
personagem pela silhueta, pelas cores e por um acessório (escudo, martelo,
arco, garras, capa), sem ler o nome.

Fontes consultadas: capturas das duas gravações do proprietário
(`C:\Users\loops\Videos\NVIDIA\Desktop`, folhas de quadros extraídas em
2026-09-26): a segunda mostra um TD/RPG do Roblox com avatares padrão, ícones
ilustrados grandes no dock e um guia com balão de fala. Tower Defense
Simulator, Tower Defense X e Toilet Tower Defense foram usados como
referência de categoria (unidades reconhecíveis, inimigos por família,
evolução visível). Não foram jogados nem assistidos nesta sessão.

## Corpo (figuras articuladas)

- Esquema R15: `HumanoidRootPart` nos pés, `LowerTorso`, `UpperTorso`,
  `Head`, braço (`UpperArm`, `LowerArm`, `Hand`) e perna (`UpperLeg`,
  `LowerLeg`, `Foot`). Um `Motor6D` em cada articulação; o cliente anima só
  com `Motor6D.Transform` (`src/client/Motion.luau`).
- Humano = 6 studs. A torre acrescenta 15%.
- Tamanho vem de **proporção**, não de zoom: Hulk ~10 studs, peito largo,
  braços grossos, cabeça pequena; Groot alto e estreito, braços longos;
  Rocket ~60% do humano, cabeça grande; brutamontes largo de pernas curtas.
- Inimigos comuns ~0,8 do humano; chefes 1,45–1,8.
- Acessórios soldados à parte do corpo a que pertencem (escudo no antebraço,
  martelo na mão, capa nas costas) para acompanharem a pose.

## Rosto

Sem imagens: olhos de peça. Rosto exposto = dois ovais escuros com brilho e
sorriso clássico; herói bravo ganha sobrancelhas. Máscaras usam lentes
brancas com borda (Homem-Aranha, Pantera, Wolverine), visor ou fendas
luminosas (Homem de Ferro, Ciclope, Máquina de Combate). Infectados: órbitas
escuras com olhos verdes luminosos de tamanhos diferentes e mandíbula aberta.

## Paleta e materiais

| Uso | Cor |
|---|---|
| Tinta / contorno | `#181C27` |
| Branco de uniforme | `#ECF0F4` |
| Vermelho herói | `#BE2632` |
| Dourado | `#E8B84C` |
| Azul-marinho | `#1C3A70` |
| Energia (neon) | `#89E2FF` |
| Pele infectada | `#80AA68` |
| Olho infectado (neon) | `#BEFF6E` |

- `SmoothPlastic` para roupa e pele; reflexo 0,1 em armaduras.
- `Neon` só para energia (reator, repulsores, olhos, magias) e nunca em
  superfícies grandes.
- `Wood` no Groot, `Ice` no Homem de Gelo. Texturas de material apenas no
  cenário, com escala coerente.

## Movimento

- Inimigos andam por distância percorrida (pé não escorrega): arrastar
  (infectado, braços à frente), correr inclinado, pisar pesado (poeira),
  marchar com escudo, esgueirar agachado, pairar, deslizar, espreitar,
  réptil, régio.
- Heróis: respiração em repouso, giro para o alvo, ataque no estilo do
  herói (tiro, arco, duas armas, rifle, golpe, soco, corte, magia, raio,
  arremesso), braços para cima na habilidade, salto na melhoria, tontura ao
  serem interrompidos.
- Com "Menos efeitos", os inimigos ficam parados na pose e os heróis não
  respiram.

## Evolução visível

Nível 2 ombreiras, 3 braceletes luminosos, 4 emblema no peito, 5 mãos e
auréola na cor do ramo (quente = ramo 1, fria = ramo 2).

## Lobby: Base dos Heróis

Referência do proprietário (27/09/2026): capturas do lobby do Toilet Tower
Defense — praça elevada cercada de vidro iluminado, placas ilustradas
enormes, títulos flutuando sobre cada área, filas com pads que brilham, água
azul e muita vegetação. A tradução para o nosso universo é uma ilha-base
tropical dos Vingadores/S.H.I.E.L.D., sempre de tarde e ensolarada.

- Paleta: pedra clara `#CED5E0`, aço `#46546E`, marinho `#1C2640`, ciano
  `#40D4FF`, vidro aceso `#96F0FF`, dourado `#FFC440`, lâmpada `#FFD480`;
  árvores redondas em dois verdes, areia `#F0DCA8`, mar turquesa.
- Cada área tem **uma cor-assinatura, uma placa ilustrada gigante e um
  marco**: campanha (verde-água, horizonte de Manhattan), arena (laranja,
  placar e refletores), zona AFK (azul, lua), invocação (dourado/rosa, baú),
  expedições (roxo, cristais de vibranium e arco de Asgard), Latvéria (verde,
  muralha com chamas), academia (violeta, alvo e cartas gigantes).
- Um só vocabulário (`Kit` em `WorldBuilder.luau`): cerca de vidro aceso,
  poste, árvore, palmeira, canteiro, escada com nariz de neon, marcas
  amarelas de canto, bandeira, estrela, placa ilustrada e título flutuante.
  Nada novo entra no lobby fora desse kit.
- Placas são desenhadas com GUI (céu em gradiente, raios de sol, ilustração,
  título LuckiestGuy com contorno) — nenhuma imagem enviada.
- Neon com bloom é o que faz o lobby brilhar: em frisos, vidro e anéis, nunca
  em superfícies grandes de piso.
- Movimento só no cliente, por atributo (`Spin`, `Bob`, `SpinCenter`,
  `Sway`): globo holográfico e órbitas, rotores do Helicarrier, Quinjet em
  patrulha, baús de prêmio, ícones dos balcões, bandeiras. "Menos efeitos"
  congela tudo.
- Cenário nunca pisa em piso de área, ponte ou fila (há teste para isso).
- Sem logotipos oficiais da Marvel: estrela e emblemas estilizados.

## Interface

Fonte de destaque FredokaOne com contorno escuro; texto de apoio Gotham.
Verde = jogar/confirmar, dourado = Ouro, laranja = evolução, roxo =
coleção, vermelho = perigo/vender. Placas do lobby: título curto na cor do
balcão e uma linha pequena de instrução; sem painel inteiro em maiúsculas.
