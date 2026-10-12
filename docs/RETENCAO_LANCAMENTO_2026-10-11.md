# Retenção e conclusão do lançamento — M32

Pedido: executar os refinamentos identificados na auditoria, no projeto
oficial, e separar conclusão técnica de aceites que dependem de uso real.

## Entrega

- Analytics: corrigida a ordem dos argumentos de `LogProgressionEvent`.
  Uma falha não desliga mais todos os eventos; a categoria tenta novamente
  após 30 segundos. Não interfere em recompensas nem no andamento da partida.
- Milestones observados pelo servidor, uma vez por conexão: `ProfileReadySeconds`,
  `FirstMatchSeconds`, `SecondMatchSeconds`, `FirstTowerSeconds`,
  `FirstPowerSeconds`, `FirstChestSeconds`, `FirstResultSeconds`. O valor é
  tempo desde a entrada; campo 1 mapa, campo 2 modo, campo 3 `new`/`returning`
  pelo histórico de partidas. Segunda partida inclui treinamento se ele foi
  a primeira; não interpretar como segunda campanha ou retenção no dia seguinte.
- `profile.nextGoal`: tutorial, baú grátis, recompensas/missões concluídas,
  ponto de talento, primeiro recrutamento com Ouro, campanha por conquistar
  e missão diária/semanal mais próxima. A interface só mostra e encaminha.
  O resultado mantém replay/lobby e agora indica um objetivo real.
- O guia após treinamento aponta primeiro ao baú gratuito, quando disponível.
  Não exige compra em Robux nem adiciona moedas, obrigações ou timers.
- Avisos de interação e melhoria só aparecem inteiros no viewport; mudança
  da câmera atualiza a visibilidade no mesmo quadro. Máximo de dois avisos
  de melhoria permanece, priorizando seleção e depois distância.
- Golpes: preparação, impacto no evento confirmado e recuperação por família;
  arqueiro, golpes pesados e cortes ganham poses distintas. Intervalo vem do
  servidor; redução de efeitos desativa o movimento extra. Retratos usam a
  mesma assinatura. Contornos de tronco/mãos/pés usam meshes internos, sem
  acrescentar peças ao lobby. Isso não substitui a revisão de anatomia do catálogo.
- Auditor de configuração executa o catálogo real e lista os produtos sem
  ID; checklist atualizado, removendo a contagem antiga de 19 faltantes.

## Critérios de aceite e evidências

| Frente | Aceite | Evidência |
|---|---|---|
| Telemetria | Assinatura estrita, falha/retry isolado, deduplicação e exclusão do Studio | `tests/analytics.spec.luau` |
| Próximo objetivo | Prioridades, restrição, campanha completa e ausência de mutação | `tests/next_goal.luau`, suíte de regras |
| Interface | Baú grátis antes de gasto; limite de avisos e bordas por quadro | `tests/client_boot.spec.luau`, seis formatos |
| Apresentação | Envelopes por família e meshes presentes nos 43 retratos, dentro do orçamento | `tests/world_boot.spec.luau` |
| Configuração | 15/41 produtos de heróis, temporada ID zero, sete bancos ativos | `tools/audit_launch.py` |
| Metadados atuais | 24 IDs respondem; VIP fora de venda | `test-results/retention/marketplace.json`, consulta read-only ao MarketplaceService |
| Studio | Revisão visual, jogo real e avisos inteiros | Conferência abaixo; publicação registrada após sucesso no log |

## Conferência de 11/10

- Suíte completa verde, incluindo compilação, regras/economia, simulação,
  cliente em seis formatos, servidor, analytics e geração dos quatro builds.
- 21 cenas no Studio: nove PC, seis horizontal PT e seis vertical EN.
  Nenhum `DOOM_REVIEW_OVERFLOW` ou erro de script nas rodadas finais.
- Combate nativo com cinco heróis e 80–104 inimigos: três amostras de quatro
  segundos, 59,99–60,02 FPS, p95 de 17,98–18,28 ms na RTX 4060 Ti.
  33 tiros confirmados, com intervalo das cinco famílias. Evidência:
  `test-results/retention/live/combat-audit.json`. Janela em primeiro plano;
  a rodada anterior em segundo plano caiu ao limite de inatividade do Studio
  (~15 FPS), portanto não serve para comparar desempenho do jogo ativo.
- Avisos reais de melhoria: um inteiro em tela, zero ao virar a câmera,
  um ao restaurar; limite de dois respeitado. Geometria dos prompts também
  coberta pelas regressões de borda e redimensionamento.
- Perfil temporário: término do treinamento pelo comando de revisão, após
  contribuição com poder, confirmou `tutorialComplete=true` e objetivo
  `freeChest`. Clique real no resgate concedeu um herói (baús 0→1); objetivo
  seguinte `rewards`. O recibo não foi capturado nesta rodada. Isso não é
  uma campanha completa nem prova de persistência em produção.
- Fontes do Studio comparadas com os 40 arquivos atuais, preservando o
  prefixo de papel `Standalone`; sincronização seletiva de 12 módulos.

Notas: leitura 4, acabamento UI 4, consistência 4, objetivo 4, recompensa 4,
desempenho PC 4. Anatomia/combate seguem 3 até a revisão completa M22.7/M22.9;
essa entrega melhora poses e contornos, sem declarar o catálogo finalizado.

## Publicação

Código **`fd58c0b`** enviado ao `main`, suíte completa verde na cadeia do
commit (68,53 s). Publicado no place oficial **97132875544830** em
**11/10/2026 às 21:33:00 local (12/10 às 00:33:00 UTC)**, com
`Go to PublishSuccessful` no log do Studio. Lobby salvo reconstruído com
4.433 peças; 40 fontes comparadas antes e depois. Studio em modo de edição.
Audiência, preços e colaboradores não foram alterados.

Comprovante: `test-results/retention/publication.json`.
Galeria: `C:/Users/loops/Desktop/Multiverse_Retencao_2026-10-11/INDICE.html`.
O checklist mantém abertas as configurações e validações externas; não
interpretar esta publicação como aceite de 100% do lançamento ou retenção.

## Roteiro de teste com jogadores

1. Recrutar 10–20 pessoas que não conhecem o jogo; registrar versão, aparelho
   e origem do convite. Não instruir a compra nem ensinar o caminho durante
   a sessão. Pode observar sem interromper e perguntar depois.
2. Pedir somente “jogue como faria normalmente”. Observar a primeira entrada,
   torre, Q, melhoria, resultado, resgate e próxima partida. Anotar a ação
   pretendida e o ponto em que o jogador se perde; duração isolada não explica
   abandono. Separar falha técnica de desinteresse/dificuldade.
3. Depois perguntar: qual era o objetivo, o que pareceu satisfatório, o que
   repetiu demais e o que gostaria de conquistar na próxima vez. Não sugerir
   respostas nem confundir elogio com retorno real.
4. No Analytics, acompanhar o funil Tutorial e tempos dos milestones, falhas
   por onda, duração/resultado e segunda partida. Verificar denominadores,
   origem/dispositivo e tamanho da amostra. Analytics do Studio fica desligado.
5. Acompanhar D1 e D7 nas datas correspondentes. Comparar versões/coortes
   semelhantes; não existe dado de uma semana no dia da publicação. Contar
   AFK separadamente ao interpretar envolvimento em combate.
6. Corrigir o maior problema observado, repetir o mesmo roteiro e só então
   ampliar aquisição. Se o gargalo for leitura, testar simplificação; se for
   repetição, testar encontros/decisões usando os sistemas existentes.

## Dependências externas

O código não confirma contratos, cria vendas por suposição ou simula compras
como prova de recibo real. VIP, temporada e 26 produtos pendentes estão no
checklist. Os heróis continuam nas rotas de aquisição existentes.
Quatro jogadores reais, celular físico, primeira entrada publicada, sessão
prolongada e métricas após dias continuam com aceite aberto.

## Fontes de análise

Assinatura conferida na [referência oficial de AnalyticsService](https://create.roblox.com/docs/reference/engine/classes/AnalyticsService#LogProgressionEvent).
Roteiro orientado pela documentação de
[retenção](https://create.roblox.com/docs/production/analytics/retention) e
[funis](https://create.roblox.com/docs/production/analytics/funnel-events) do Roblox.
