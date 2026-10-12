# Anatomia e peso dos ataques — 11/10/2026

Continuação dos itens M22.7/M22.9, registrada na fila M33. Este lote melhora
a forma dos personagens e a preparação do combate. Não declara o catálogo
inteiro como arte final nem substitui os aceites de lançamento do
[`RELEASE_CHECKLIST.md`](RELEASE_CHECKLIST.md).

## Mudança visível

Os 43 heróis usam tronco com núcleo estreito e laterais inclinadas, cintura
arredondada, segmentos de braços/pernas com volume e polegares/solas próprios.
As cores e materiais seguem o figurino. O acabamento aparece nos retratos,
torres, colocação e figuras do lobby, mantendo juntas, dimensões do rig,
acessórios e pontos de emissão existentes.

Inimigos recebem o mesmo tratamento de tronco/membros; chefes também recebem
mãos/pés detalhados. A ilusão descartável mantém o tronco compacto porque
casaco/chifres já ocupam seu orçamento de peças. As silhuetas dos seis chefes
e as oito fileiras do catálogo foram fotografadas no Studio.

A preparação do ataque agora acontece quando o servidor encontra um alvo
válido perto da recarga terminar. Expira se o disparo não vier; um tiro
confirmado encerra a preparação e inicia impacto/recuperação. Golpe pesado
ganha elevação dos braços, flexão e recuperação; controle concentra as mãos
antes de soltar. As outras famílias mantêm suas poses próprias.

O projétil resolve a cadeia de juntas na pose de impacto, evitando nascer
na posição da mão do quadro anterior. O servidor continua decidindo alvo,
alcance, recarga e dano; o primeiro ataque não recebe atraso. A antecipação
não aplica dano, cobra recursos ou cria efeitos/sons de acerto. É agrupada
no evento existente de tiros e respeita Menos efeitos. Os cálculos de combate
são executados na janela curta de preparação ou no prazo do ataque, sem
recalcular estatísticas durante toda a recarga.

## Verificação

| Aceite | Evidência |
|---|---|
| Geometria dos 43 heróis, soldas, juntas e limites | `tests/world_boot.spec.luau`, 6.861 verificações |
| Preparação sem mudar vida, prazo, contagem de ataques ou dinheiro | `tests/match_simulation.spec.luau`; alvo aéreo/oculto e pista vazia também cobertos |
| Preparação/expiração/tiro/repouso e Menos efeitos | `tests/client_boot.spec.luau`, seis formatos |
| Emissão na pose atual mesmo com posição física antiga | Regressão de cadeia de juntas no world boot |
| Três fases de cinco heróis em combate nativo | `test-results/anatomy/live/poses-audit.json`: 23 preparações, 25 tiros e 15 poses observadas na rodada final |
| Formas e figurinos no Studio | `test-results/anatomy/showroom/`: 43 heróis, seis chefes, seis famílias e três detalhes |
| Revisão dos retratos/HUDs | Herói, equipe, torre e prêmio em PC, horizontal PT e vertical EN |
| Orçamento de peças | Lobby 4.481 no Studio/4.472 no dublê; comuns até 39 e chefes até 46, abaixo dos limites existentes |

As 20 capturas de interface das rodadas finais não acusaram corte de texto
ou erro de script: quatro PC, oito horizontal PT e oito vertical EN
(as rodadas com emulação também repetem a vista PC).

Estudos estáticos `pose-preparation.png`, `pose-impact.png` e
`pose-recovery.png` usam exatamente os modelos e `Motion` atuais. São uma
comparação de poses, não três quadros consecutivos da mesma animação. A
observação da partida real é separada no JSON acima. Objetos de vitrine,
clones e conexões de observação foram removidos após o uso.

**Limite da medição de desempenho:** duas tentativas foram invalidadas.
O Studio ficou em segundo plano, limitado aproximadamente a 15 FPS; a segunda
rodada também terminou sem inimigos. `combat-audit.json` e `benchmark.json`
preservam esses dados e o estado de foco. Não atribuir esse resultado ao
desempenho ativo nem reaproveitar os 60 FPS da versão anterior como prova
deste lote. Repetir com janela ativa e 80 inimigos segue em M33.5.

## Direção de arte e próximo aceite

Leitura, consistência, objetivo e recompensa permanecem 4. O volume dos
corpos melhorou, mas figurinos e rostos do catálogo ainda variam em detalhe;
acabamento de personagens permanece 3/5. A preparação/impacto/recuperação
está legível na amostra; combate permanece 3/5 até fechar carga ativa e
refinamento das demais assinaturas. Não aumentar peças ou brilho para
disfarçar falta de forma.

M22.7 continua com aceite de figurinos/silhuetas próprios por herói;
M22.9 mantém a conferência de carga e o peso das outras famílias. Celular
físico, quatro jogadores, nuvem/compras, sessão prolongada e D1/D7 continuam
no checklist de lançamento. Nenhum deles é comprovado pelo perfil de memória
do Studio ou pela emulação de tamanho de tela.

## Entrega

Código **`f636a9a`** enviado ao `main`, com suíte completa verde na cadeia do
commit (87,38 s). Publicado no mesmo place da equipe **97132875544830** em
**11/10/2026 às 23:42:32 local (12/10 às 02:42:32 UTC)**, com
`Go to PublishSuccessful` confirmado no log do Studio. Sincronização seletiva
de WorldBuilder, MatchService, Motion e Effects; 40 fontes comparadas com o
repositório e prefixo Standalone preservado.

Lobby salvo reconstruído com **4.481 peças**, abaixo do teto de 4.500, e
Studio deixado em edição. Nenhuma configuração da experiência foi alterada.
Comprovantes: `test-results/anatomy/publication.json`, `final-audit.json` e
`preview-counts.txt`. A medição de carga ativa continua pendente em M33.5.

Galeria local: `C:/Users/loops/Desktop/Multiverse_Modelos_Combate_2026-10-11/INDICE.html`.
