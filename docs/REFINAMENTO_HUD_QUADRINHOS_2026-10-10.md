# HUDs: quadrinhos e tecnologia do multiverso — 10/10/2026

Pedido: enriquecer todas as interfaces com a personalidade de uma aventura
de super-heróis, usando o vídeo fornecido como referência de apresentação.
Trabalho no `main` e no lugar da equipe **97132875544830**.

## Referência consultada e diagnóstico

Arquivo local: `Desktop 2026.10.10 - 09.42.59.01.mp4`, em
`C:\Users\loops\Videos\NVIDIA\Desktop`. Foram inspecionados quadros nos
segundos 3, 13, 23, 33, 43, 53, 63, 73, 83, 93, 103, 116 e 125. O vídeo
mostra um tower defense temático; os elementos aproveitados são a presença
dos personagens, a hierarquia da invocação e a distinção entre informações
de combate. Nenhum desenho, símbolo ou arquivo desse jogo foi incorporado.

| Problema observado | Efeito no jogo | Correção |
|---|---|---|
| Janelas praticamente pretas, embora a paleta previsse azul | Apresentação sem profundidade, pouca diferença entre áreas | Corrigir a multiplicação da cor-base pelo gradiente; corpo azul-marinho, cabeçalho com cor funcional e moldura interna |
| Retratos pequenos sobre retângulos opacos | Heróis pouco presentes na coleção, barra e seleção | Enquadramento de busto nos cartões, cenário ilustrado transparente, figura inteira na ficha grande |
| Mesmo acabamento genérico em botões e cartões | Falta de assinatura visual entre lobby, combate e recompensa | Emblema dimensional original, inscrições nas bordas, cartões por raridade, vitrine de invocação e barras segmentadas |

Antes: [invocação](../test-results/comic-huds/before/02-chests.png),
[torre](../test-results/comic-huds/before/03-tower.png),
[resultado](../test-results/comic-huds/before/04-results.png).

## Direção aplicada

- **Paleta:** azul-marinho `#0C142B` / `#182848`, tinta `#0B0F24`;
  dourado para moeda/recompensa, coral para heróis, verde para bases,
  violeta para evolução e azul para comando. Perigo mantém vermelho.
- **Formas:** placas com cantos de 12–14 px, moldura interna, fitas inclinadas,
  cortes de velocidade nas bordas e anéis dimensionais com núcleo em losango.
- **Tipografia:** Fredoka One nos títulos, Builder Sans no corpo; hierarquia,
  ajuste de texto e canvas lógico de 1150×640 preservados.
- **Personagens:** bustos maiores em cartões pequenos; ficha grande com
  figura inteira e animação existente. A arte acompanha o retrato quando ele
  é destruído, inclusive na virtualização da roleta.
- **Movimento:** pressão e retorno curtos, hover menor para evitar cortes;
  Menos efeitos mantém a escala dos botões estável. A arte nova é estática.

As vitrines mostram resultados possíveis do catálogo real. As chances
dos destaques aparecem nos próprios cartões. As chances completas, os
preços, as garantias e a ação de invocar continuam acessíveis.
No PC há até três destaques e uma lista compacta de probabilidades; no
celular a apresentação privilegia a ação e a rolagem existente.

## Abrangência

Os componentes compartilhados aplicam o acabamento ao lobby, modos,
coleção/equipe, ficha de herói, bases, invocação de heróis/bases, loja,
missões, recompensas, placar, opções, embarque, AFK, avisos de interação,
combate, preparação, posicionamento, habilidade, ficha da partida,
inspeção de inimigos, cartas, evolução de base, resultados e roleta.

A árvore permanece sobre o mundo desfocado, sem painel opaco. A roleta
preserva sua sequência e o recibo imediato; os sons Sonniss integrados na
entrega anterior permanecem ativos. Economia e decisões do servidor não
foram alteradas. As telas de carregamento já tinham sua apresentação
própria e não receberam uma nova sequência nesta entrega.

A inspeção nativa revelou a caixa de digitação do Roblox sobre os atributos
e as especializações da torre. Ela tem configuração independente da janela
de mensagens: as duas agora se escondem ao abrir painéis e voltam ao fechar.
Regressão simulada nos seis formatos e captura real do cartão da torre.

Também foram corrigidas a sobreposição da inspeção de inimigo com a ficha
da torre e as truncagens do nome do baú e do prazo das missões no celular
vertical. Selecionar uma torre fecha a inspeção; inspecionar um inimigo fecha
as melhorias. A cena fixa de invocação agora escolhe explicitamente heróis,
mesmo depois de revisar a invocação de bases, sem alterar a seleção que o
jogador mantém entre visitas reais.

Assets novos: desenhos vetoriais procedurais em Luau, sem imagens ou
texturas externas e sem dependência de upload. Não há novos loops de
animação para os grafismos.

## Verificação e matriz

| Área | Estado | Evidência |
|---|---|---|
| Componentes, retratos, botões e barras | Verificado no jogo | `UI.luau`, `init.client.luau`; capturas PC e celular |
| Coleção, invocação e bases | Verificado no jogo | `Panels.luau`; probabilidades e botão de compra visíveis |
| Torre, cartas, evolução de base e resultados | Verificado no jogo | `MatchHud.luau`; alternância torre/inimigo conferida |
| Roleta e avisos de interação | Verificado no jogo | `Celebrate.luau`, `InteractionHud.luau`; cenas próprias |
| Testes de lógica e layout | Verificado | Suíte completa, `test-results/comic-huds/full-commit.txt`, na cadeia do commit |
| Varredura final e carga | Verificado no jogo | `final-tour.json`: 93 capturas; `portrait-tour.json`: 48; zero erros/cortes de texto detectados; `combat-measure.json` |
| Publicação | Verificado no jogo | Place 97132875544830, 10/10 às 10:51:56 local / 13:51:56 UTC; `publication.txt` |
| Celular físico e quatro jogadores | Bloqueado por dependência identificada | Aparelho e sessão multijogador; checklist de lançamento |

Os testes novos verificam a vida útil da arte de retratos, atualização de
pele sem acúmulo de instâncias, desenhos sem interceptar entrada, orçamento
fixo, enquadramento de figura inteira e Menos efeitos. Os seis roteiros
completos do cliente continuam cobrindo seleção, rolagem, filtros, compra,
recompensas, toque longo e árvore.

Arquivos: `src/client/UI.luau`, `Panels.luau`, `MatchHud.luau`,
`init.client.luau`, `Celebrate.luau`, `InteractionHud.luau`, `Review.luau`
e `tests/client_boot.spec.luau`. Nenhum módulo do servidor ou catálogo
de economia mudou. As 37 fontes abertas no Studio foram comparadas antes
da sincronização; somente os sete módulos de cliente alterados foram enviados.

Capturas: [comparação antes/depois](../test-results/comic-huds/antes-depois.jpg),
[invocação](../test-results/comic-huds/pt-desktop-final/01-chests.png),
[torre](../test-results/comic-huds/pt-desktop-final/04-tower.png),
[resultado](../test-results/comic-huds/pt-desktop-final/06-results.png),
[invocação vertical](../test-results/comic-huds/pt-portrait/07-chests.png).

Carga real no Studio, Complexo Gama/Cartas, RTX 4060 Ti: amostras de seis
segundos. Baseline com seis inimigos: 60,01 FPS, p95 17,70 ms. Após
`crowd 80`, 90 inimigos visíveis: 60,00 FPS, p95 18,02 ms e pior quadro
18,67 ms. Não é medição de aparelho móvel nem teste prolongado.

A revisão passou pelas 38 cenas no PC, celular horizontal e vertical em
português, pelas 38 no horizontal em inglês e por seleções de telas no PC
e vertical em inglês. A rodada vertical final fechou o Gerenciador de
ativos do Studio para que o viewport comportasse o canvas inteiro de
375×667, incluindo o dock inferior. Não foi necessário alterar esse dock.

As 37 fontes finais coincidiram com os arquivos locais antes de publicar.
O lobby de edição foi reconstruído sem reenviar módulos inalterados:
4.455 peças, teto 4.500. `PublishSuccessful` confirmado no log; Studio
deixado em edição. A publicação atualiza o mesmo lugar da equipe.

Avaliação visual da entrega: leitura 4, acabamento 4, consistência 4,
clareza do objetivo 4, recompensa 4 e desempenho 4. Uau e combate seguem
em 3: a moldura melhora a apresentação, mas o peso dos movimentos e a
anatomia do elenco ainda exigem a amostra de arte prevista em M22.

## Limites e próxima entrega

O refinamento gráfico das interfaces não finaliza os modelos do elenco.
As capturas maiores tornam visível a anatomia ainda básica de parte dos
heróis; M22.7 permanece aberto para a amostra humanoide/grandalhão/inimigo,
seguida da animação dos ataques em M22.9. Não atribuir nota final de arte ao
catálogo por causa das molduras novas.

A validação no Studio não substitui toque em aparelho real, quatro
jogadores, compras publicadas e sessão prolongada.
O aviso 3D da base próximo à borda continua identificado em M24.7; não
confundir a varredura de texto dos painéis 2D com a projeção desse aviso.
