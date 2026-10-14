# Estátuas com os heróis da partida — 14/10/2026

As duas figuras do lobby passam a usar o mesmo construtor e figurino dos
heróis da partida, ampliados para escala 2 sobre os pedestais existentes.
A modelagem exclusiva dos monumentos foi removida. O atributo de animação
ociosa é retirado da figura interna: o cliente não move suas peças.

Um rascunho local já tentava reaproveitar os heróis, mas retirava o atributo
do contêiner externo e incluía peças invisíveis para satisfazer os testes
antigos. A correção remove essas peças e confere os acessórios reais.

Verificação: suíte completa verde, 8.345 checagens de mundo; testes conferem
figurino completo, escala, proporções, peças ancoradas, reator e escudo.
Capturas reais dos dois modelos no lobby, de frente e em três quartos,
sem erros de script. Galeria em
`test-results/galerias/Estatuas_Gameplay_2026-10-14/`.

O lobby tem 4.516 peças no dublê e 4.536 no Studio. O limite de preview foi
alinhado às 4.550 peças do teste local para acomodar os figurinos completos.
Não houve medição nova de FPS. Fontes conferidas antes da sincronização;
somente WorldBuilder enviado, sem sobrescrever alterações desconhecidas.

Publicação e commit: consultar o registro M36.5 no LOG.
