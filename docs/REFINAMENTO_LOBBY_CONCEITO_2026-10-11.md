# Lobby: praça dos heróis e arena — 11/10/2026

O lobby foi remodelado a partir do conceito aprovado pelo dono: sede
tecnológica de heróis em azul-marinho e dourado, jardins curvos, estátuas
com armaduras próprias, globo orbital e arquitetura com mais profundidade.
A entrega também inclui o pedido seguinte de substituir o placar preto da
arena. O destino continua sendo o lugar da equipe **97132875544830**.

## Implementação

- **Praça:** pavimentação em camadas, anéis de pedra e metal, estrela
  dourada maior, filetes ciano, quatro jardins curvos com bordas e flores,
  lanternas baixas nas escadas e caminhos de acesso livres.
- **Monumentos:** dois modelos estáticos próprios, em verde-petróleo/dourado
  e azul/prata, com capacete, ombreiras, peitoral, cintura, mãos, joelhos,
  botas e pedestais em camadas. O escudo fica do lado externo da passagem.
- **Torre:** vidro azul, cantos chanfrados, pilares, cornijas douradas,
  bandeiras, coluna de energia central e apoios para a plataforma elevada.
  A passagem térrea e as lojas físicas continuam nas posições existentes.
- **Invocação:** entradas com pilares facetados, bases de pedra, cornijas,
  bandeiras, letreiros sustentados e vórtices violeta/ciano animados. A
  entrada de cada coleção continua abrindo somente sua própria loja.
- **Globo e horizonte:** esfera com meridianos ciano e órbitas douradas,
  ilhas rochosas em terraços, vegetação e duas cascatas decorativas no fundo.
  As cascatas são estáticas; os vórtices usam o animador local existente.
- **Sinalização:** seis placas de distrito mais compactas, em azul e ouro;
  as placas dos mapas preservam suas vistas próprias e as filas existentes.
- **Arena:** painel com profundidade e moldura metálica dourada, título
  montado na própria placa, troféu desenhado, três divisões coloridas por
  mapa e convite para estabelecer o primeiro recorde. Os pódios desaparecem
  quando chegam resultados reais. Títulos e estados seguem português/inglês;
  nenhuma pontuação fictícia é mostrada.

A quantidade de peças foi redistribuída: folhas de palmeira, barreiras e
adornos distantes repetidos ficaram mais econômicos para permitir detalhar
os pontos vistos de perto. Colisões, apoios, regras de acesso, custos e
recompensas continuam sob as verificações existentes do servidor.

## Verificação

| Checagem | Resultado |
|---|---|
| Suíte completa `python tools/test.py` | Exit 0, 72,56 s na cadeia do commit `fb65172` |
| Mundo com dublês | 4.424 peças; todas as verificações aprovadas |
| Reconstrução nativa no Studio | 4.433 peças, teto mantido em 4.500 |
| Acessos novos | Varredura das quatro direções em três faixas, sem decoração nova obstruindo |
| Apoios | 20 bases de jardim assentadas, letreiros de invocação sustentados |
| Arena | Dados reais, ausência de dados, estado vazio e localização cobertos |
| Texto da arena no Studio | Nove rótulos em PT/EN sem corte; cinco nomes de 20 caracteres por divisão também cabem |
| Circulação nativa | Personagem percorreu as quatro pontes e a passagem da torre, com colisão real |
| Lojas físicas | Entradas de Heróis e Bases abrem suas próprias coleções, sem compra de teste |
| Lobby no PC | 60 FPS, p95 17,88 ms, pior quadro 19,11 ms em amostra de 6 s |
| Carga de combate | Cinco heróis, 104 inimigos visíveis; 60 FPS, p95 17,92 ms, pior quadro 34,71 ms em 6 s, RTX 4060 Ti |
| Telas menores e inglês | 20 capturas PC/horizontal PT/vertical EN: lobby, tutorial, modos e duas lojas; saída 0, sem cortes de texto ou erros detectados |
| Fontes no lugar da equipe | 40 fontes comparadas; somente WorldBuilder sincronizado |

Capturas e medições nativas ficam em `test-results/lobby-design/`.
A conferência usa perfil temporário do Studio, sem alterar perfis salvos.
A medição de PC é uma amostra curta; não certifica desempenho em celular
físico ou sessões prolongadas. A galeria separada fica no Desktop:
`Multiverse_Lobby_2026-10-11/INDICE.html`.

## Critério visual e limites

A referência orienta materiais, composição, proporções e hierarquia. A
imagem conceitual não é uma captura do jogo nem uma promessa de reprodução
de cada pixel: a versão jogável usa geometria nativa, colisões e orçamento
real de Roblox. As capturas do Studio são a evidência da entrega.

Esta rodada trata do cenário do lobby e do placar físico da arena. Não
conclui a revisão de anatomia do elenco ou peso do combate em M22.7/M22.9,
nem os testes de aparelho físico, quatro jogadores e sessão prolongada do
checklist de lançamento.

Notas da régua: leitura 4, acabamento do cenário 4, consistência 4,
objetivo 4, recompensa 4 e desempenho PC 4. Uau e peso do combate continuam
3, sem regressão identificada nesta rodada: M22.7/M22.9 já registram a
amostra de anatomia e movimento que falta desenvolver. Não classificar
o catálogo inteiro como finalizado a partir desta revisão do lobby.

## Publicação

Código **`fb65172`** enviado ao `main`. Somente `WorldBuilder.luau` foi
sincronizado; as 40 fontes foram comparadas, preservando o prefixo de papel
anterior do servidor. Preview reconstruído com 4.433 peças.

Publicado no mesmo lugar da equipe **97132875544830** em **11/10/2026 às
11:05:12 local (14:05:12 UTC)**. Confirmação nova no log da janela alvo:
`2026-10-11T14:05:11.582Z ... Go to PublishSuccessful`.
Registro completo em `test-results/lobby-design/publication.json`, também
copiado para a galeria. Studio conferido e deixado em modo de edição.
