# Contornos, baús e música de combate — 08/10/2026

Pedido: corrigir bordas cortadas nas interfaces, dar mais ação à música das
partidas e usar a mesma roleta nos baús comprados e recebidos, sem repetir
uma abertura depois que a roleta termina.

## Implementação

- Listas roláveis têm uma margem interna de seis pixels lógicos nos quatro
  lados, suficiente para seus contornos. O cálculo do canvas inclui essas
  margens, preservando a rolagem ao atualizar dados.
- Galerias de chances, seletores de baús, resumo de resultados e barra de
  heróis também preservam o espaço dos contornos; não se desligou o recorte
  de conteúdo que está fora da tela.
- Baús de recompensas usam a roleta da loja. Um lote da temporada mostra
  todos os prêmios, cada um com seu baú correto, e permite pular o lote.
- Após a roleta, o cartão aparece pronto: sem segundo modelo de baú,
  carregamento de raridade, clarão ou sequência sonora de abertura.
  Duplicados, cartas, estrelas, aparência brilhante e bases são preservados.
- Prêmios continuam sendo concedidos e confirmados pelo servidor antes da
  animação; pular ou fechar uma tela não faz nova compra nem novo sorteio.
- A trilha de combate que o Roblox não carrega usa agora um arranjo de ação
  com os áudios próprios já disponíveis: coro grave em tonalidade menor e
  percussão a 96 BPM. Usa três vozes reutilizadas e o controle de Música,
  independentemente do controle de Efeitos; encerra no resultado/lobby.
  A faixa e velocidade da música do lobby foram mantidas.
- As fontes WAV mais recentes continuam aguardando envio/moderação pelo
  dono. Nenhum ID de áudio novo foi inventado nem houve declaração de
  autoria automática. O arranjo disponível não depende desse upload.

## Verificação

Testes do cliente em seis formatos: baú comprado, baú de recompensa,
resultado imediato, ausência de segundo baú/clarão e lote de recompensas
com herói e base. Testes de áudio: falha de carregamento, escolha do
arranjo de ação, mute independente, reutilização de vozes e saída da partida.

Suíte completa final aprovada, saída 0, em
`test-results/hud-chest-final-suite.txt`. Compilação, regras, serviços,
simulação de partida, cliente, layouts e geração dos quatro places verdes.

Após o dono confirmar que o PC estava livre, os seis módulos foram comparados
com as fontes do Studio antes da sincronização seletiva. Conferência final
das fontes novamente aprovada em `test-results/hud-chest-guard-final.txt`.

| Área | Estado | Evidência |
|---|---|---|
| Contornos e telas | Verificado no Studio | 46 capturas: PC e celular horizontal/vertical em português; PC e horizontal em inglês. Sem cortes de texto ou erros de script detectados. |
| Baú gratuito | Verificado no Studio | `ClaimFreeChest` real no perfil isolado de memória, seguido da roleta e recibo dos componentes reais. Herói confirmado no inventário; nova solicitação recusada. |
| Lotes de recompensa | Implementado e testado | Teste do cliente com três resultados de baús diferentes, incluindo base, resumo completo e opção de pular. |
| Música da partida | Reprodução verificada no Studio | Os três stems carregados; coro e percussão ativos durante a partida; lobby parado e stems encerrados no resultado. Preferência sonora ainda depende da avaliação do jogador. |
| Publicação | Pendente neste registro | Mesmo lugar da equipe, depois da entrega verde ao main. |

Capturas em `test-results/hud-chest/`:

- [Resultado no PC](../test-results/hud-chest/pt/landscape/01-defeat.png).
- [Resultado no celular vertical](../test-results/hud-chest/pt/portrait/01-defeat-phone.png).
- [Loja no celular vertical](../test-results/hud-chest/pt/portrait/04-chests-phone.png).
- [Roleta do baú gratuito](../test-results/hud-chest/live/free-chest-reel.png).
- [Prêmio sem segunda abertura](../test-results/hud-chest/live/free-chest-receipt.png).

Medição no PC com GeForce RTX 4060 Ti, Studio, três torres e comando
`server:crowd 80`: 240 quadros em quatro segundos, 60 FPS, p95 de 17,87 ms
e pior quadro de 19,70 ms. A captura registrou 103 inimigos na estrada.
Resultado técnico em `test-results/hud-chest/live/functional.json`.
É uma amostra curta em um PC; não comprova desempenho em quatro jogadores,
aparelho físico ou sessão prolongada. A abertura foi conferida com os
componentes reais e o servidor, sem simular um clique no botão da tela.

Arquivos de produção: `UI.luau`, `Panels.luau`, `Celebrate.luau`,
`Audio.luau`, `Review.luau` e `init.client.luau`, todos em `src/client/`.
Testes alterados: `tests/client_boot.spec.luau` e `tests/test_audio.py`.
