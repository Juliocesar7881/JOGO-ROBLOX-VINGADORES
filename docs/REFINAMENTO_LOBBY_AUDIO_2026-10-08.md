# Lobby e áudio — 08/10/2026

Pedido: corrigir áreas incompletas, o vazio no mar, construções básicas e sons
repetitivos. Trabalho no repositório `main` e no lugar da equipe
`97132875544830`, mantendo as regras de partidas, progressão e monetização.

## Problemas e mudanças

| Problema observado | Mudança | Evidência |
|---|---|---|
| Quadrado vazio de aproximadamente 360 studs no mar antes de qualquer partida | Água contínua quando não existe campo de batalha; um campo já carregado preserva seu volume | Teste de cinco posições no vazio antigo e vista real da baía |
| Passagem da torre sobre grama, com aparência de obra incompleta | Piso contínuo até as duas vias, faixa de ardósia, bordas metálicas, colunas e luminárias | Teste de juntas/altura e personagem atravessando no Studio |
| Paredes retangulares e janelas azuis sem acabamento | Cantos arredondados, caixilhos, peitoris, cobertura da entrada e divisões na torre | Capturas da entrada e das vitrines |
| Cinco vitrines com objetos pouco reconhecíveis | Drone com quatro motores/rotores, cofre, console de treinamento, cartão de recrutamento e escudo VIP | Modelos reais, placas físicas localizadas e teste da animação do rotor |
| Laterais lisas e teto luminoso nos salões de invocação | Janelas circulares com moldura, frontões e acabamento metálico; plataforma circular no interior | Capturas de ambos os salões e orçamento de peças |
| Costa perfeitamente circular e mar muito refletivo | Pequenas enseadas de areia, margens preservando desembarques e reflexão menor | Revisão da baía e circulação |
| Coleta, construção e evolução repetindo melodias similares | Coleta curta, impacto mecânico, carga de melhoria, volumes menores e limite de repetição | Testes do áudio real, incluindo mensagens duplicadas e mute |
| Habilidades com o mesmo som independentemente do herói | Som conforme a família do líder e distância da câmera | Testes de famílias, recarga sonora, distância e mute |

Os sons de ataques têm três vozes por janela de 300 ms, intervalo mínimo por
família de 120 ms, volume por distância e pequenas variações de afinação.
Os sons agendados do posicionamento conferem novamente a opção de efeitos.
Melodias de recompensas raras continuam distinguindo conquistas importantes.

## Arquivos e assets

- `src/server/WorldBuilder.luau`: mar, costa, torre, salões e vitrines.
- `src/client/Audio.luau`, `Effects.luau`: mix, orçamento e som das habilidades.
- `src/shared/Config.luau`: opção de ativar gravações diretas após upload.
- `tools/generate_refined_audio.py`: síntese determinística do novo lote.
- `assets/audio/refined/`: 12 WAVs, manifesto e instruções de ativação.
- Testes de mundo, cliente, áudio e integridade das gravações.

As mudanças de mix usam os IDs que já existem e estão disponíveis no jogo.
O novo lote contém duas trilhas, cliques, coleta, encaixe, carga e cinco famílias
de ataques. Os arquivos antigos e seus IDs foram preservados. Não há IDs
inventados nem declarações de upload concluído para os arquivos novos.

## Verificação

`python tools/test.py` passou na versão final: compilação, 632.736 asserções de
regras, servidor, cliente nos seis tamanhos, geometria, áudio, economia,
simulação de partidas e geração dos places. Log local:
`test-results/lobby-audio-full-suite.txt`.

O lobby ficou com **4.489 peças**, abaixo do limite de 4.500, sem aumentar o
orçamento. Coplanaridade, colisões e caminhos continuam cobertos pela suíte.
As coroas de vegetação foram simplificadas para investir a geometria nas
construções; a quantidade de árvores foi preservada.

No Studio, foram conferidos piso, travessia do personagem, rotor, abertura da
loja pelo aviso físico, salões, vitrines e mar. Nenhuma compra foi realizada.
As fontes do Studio foram comparadas antes de cada sincronização para evitar
sobrescrever alterações exclusivas do parceiro.

Medição final no PC do dono (RTX 4060 Ti, Studio, amostras de quatro segundos):

| Cena | FPS médio | Quadro p95 |
|---|---:|---:|
| Lobby, loja aberta | 60,01 | 17,90 ms |
| Mesma câmera do lobby, loja fechada | 60,02 | 17,89 ms |
| Partida real, duas torres e carga adicional de 80 inimigos | 60,00 | 18,00 ms |

Dados em `test-results/lobby-audio/measure.json`. Uma primeira amostra isolada
da loja teve 25,64 FPS; a repetição acima controlou a câmera e verificou o
estado aberto/fechado. Isso não identifica a causa daquela primeira amostra
nem é um teste prolongado. Na carga final, 22 dos 23 objetos de áudio estavam
carregados; a trilha de batalha antiga continua bloqueada, com o fallback já
existente. A troca completa da gravação exige o upload descrito abaixo.

Capturas locais (em `test-results/`, fora do Git):

- [Torre antes](../test-results/lobby-audio/tower-before.png) e
  [depois](../test-results/lobby-audio/tower-after.png).
- [Vitrines antes](../test-results/lobby-audio/kiosks-before.png) e
  [depois](../test-results/lobby-audio/kiosks-after.png).
- [Baía antes](../test-results/lobby-audio/bay-before.png) e
  [depois](../test-results/lobby-audio/bay-after.png).
- [Passagem](../test-results/lobby-audio/tower-passage-after.png).
- [Salão de heróis](../test-results/review/Chest_rare-after.png) e
  [salão de bases](../test-results/review/Chest_base_rare-after.png).
- [Loja aberta pelo aviso físico](../test-results/review/physical-shop-after.png).

As comparações usam as mesmas posições de câmera. A captura inicial veio do
teste que estava aberto; não é uma comparação quantitativa de iluminação.

## Dependências e limites

**Novas gravações: produzidas, aguardando upload e moderação.** A declaração
de autoria pertence ao dono. Arquivos e procedimento concreto em
`assets/audio/refined/README.md`; o mix atual já funciona sem esse upload.

Os testes desta entrega não substituem avaliação auditiva pelo jogador,
celular real, quatro jogadores, compras e teleporte publicados. Nenhuma dessas
validações foi classificada como concluída.

Este lote resolve os defeitos apontados e refina esses pontos do lobby. O
acabamento dos demais distritos e o teste prolongado continuam na fila; não
equivale a declarar todos os cenários finalizados.
