# Prévia de habilidades e árvore navegável — 08/10/2026

Código entregue no `main`: `2aa4d0f`. Sincronizado seletivamente e publicado
no lugar da equipe `97132875544830` às 11:46:18 local (14:46:18 UTC), com
`PublishSuccessful` confirmado no log do Studio. O Studio ficou em edição.

## O que muda para o jogador

- Q prepara a habilidade regional do líder e desenha a região afetada antes do clique. A prévia acompanha o mouse, usa o raio efetivo recebido do servidor e mantém a preparação durante a reorganização do HUD.
- O contorno azul identifica a região válida; vermelho indica posição fora dos limites. Mira no céu, cancelamento e troca de partida removem a prévia. Poder global continua imediato, sem círculo fictício.
- A árvore do lobby tem hexágonos maiores, fundo escuro, ilustrações, arraste com mouse/dedo, zoom pela roda e botão Centralizar. Arrastar sobre um talento não compra a evolução.
- Posição e zoom sobrevivem à atualização do perfil. Mudanças de tamanho da tela preservam a região explorada; o centro se adapta à escala dos hexágonos.
- Entrada, hover e evolução têm respostas breves. Os sons usam o áudio original do projeto com volume, pitch e limite de vozes próprios; os controles de som e Menos efeitos são respeitados.
- As dependências, custos, pontos, atributos e regras da progressão continuam no servidor. A ficha da partida conserva sua árvore de consulta.

## Referência utilizada

Foram inspecionados quadros do vídeo local `Desktop 2026.10.04 - 17.25.34.01.mp4`, especialmente entre 44 e 58 segundos: fundo escuro, hexágonos grandes, estados de desbloqueio, navegação e tooltip. Os quadros extraídos ficam em `test-results/reference-tree/`. Os sons são próprios do jogo; o áudio do vídeo não foi avaliado nem copiado.

## Código e verificação

`TalentViewport.luau` cuida apenas de navegação e desconecta seus eventos ao fechar. `Panels.luau`, `UI.luau` e `Audio.luau` apresentam a árvore. `init.client.luau` desenha a prévia e envia a intenção de lançar; a validação de gameplay permanece em `MatchService.luau`.

O contorno reutiliza 28 segmentos locais, sem colisão, toque ou participação nos raycasts. Não são criados novos segmentos a cada quadro.

Os testes cobrem arraste a partir de um nó comprável, clique estacionário, toque, zoom limitado, coordenadas lógicas, posição preservada, adaptação da tela, encerramento dos eventos e mute dos sons. Para Q, cobrem raio enviado pelo servidor, movimentação, reorganização do HUD sem lançamento, posição inválida, céu, cancelamento e poder global.

O dublê de `Instance:Destroy()` agora destrói os descendentes e dispara Destroying, como o Roblox. Isso permite detectar eventos que sobrevivam a uma janela fechada; nenhuma resolução ou etapa da suíte foi removida.

## Matriz de aceite

| Área | Estado | Evidência / limite |
|---|---|---|
| Navegação da árvore | Implementado | Testes de mouse/toque e zoom nos seis formatos; a interação física em celular continua pendente. |
| Árvore no PC/horizontal | Verificado no jogo | Revisão do Studio sem cortes; adaptação ao horizontal conferida após corrigir os deslocamentos. |
| Prévia regional / global | Implementado | Testes de intenção e raio; círculo e 28 segmentos inspecionados no Studio sobre Manhattan. |
| Vertical / inglês | Verificado no jogo | Árvore, mira e ficha revisadas no Studio; comandos de revisão terminaram com saída 0, sem cortes ou erros de script. |
| Publicação da equipe | Verificado no jogo | Fontes comparadas com o Git, sincronização seletiva, lobby de edição refeito e publicação confirmada no mesmo place às 14:46:18 UTC. |

## Evidências locais

- Suíte completa: `test-results/tree-skill-delivery-suite.txt`, saída 0; seis roteiros completos de cliente com 917–920 verificações cada, sem falhas.
- Fontes do Studio comparadas com o Git antes da sincronização: `tree-skill-studio-guard.txt`.
- Capturas iniciais e após correções: `test-results/tree-skill/`.
- Árvore vertical em português: `test-results/tree-skill/pt-portrait/01-talents-phone.png`.
- Árvore em inglês no PC e horizontal: `test-results/tree-skill/en-landscape/01-talents.png` e `01-talents-phone.png`.
- Contorno final azul sobre Manhattan: `test-results/tree-skill/pt-portrait/07-snap.png` e `test-results/tree-skill/en-landscape/04-snap.png`.
- Revisões com saída 0: `tree-skill-review-portrait.txt` e `tree-skill-review-english.txt`.
- Fontes finais e publicação: `tree-skill-current-guard.txt`, `tree-skill-publish-sync.txt` e `tree-skill-publication.txt`.

A revisão visual usa Roblox Studio no PC do proprietário e áreas simuladas de 667×375 e 375×667. Não equivale a teste de toque, áudio ouvido, FPS ou memória em aparelho físico. As dependências de lançamento de `RELEASE_CHECKLIST.md` permanecem separadas desta entrega.
