# Refinamento de direção e apresentação — 08/10/2026

Pedido: implementar as melhorias discutidas, com heróis e cooperação como
assinatura. Trabalho na branch `main`, no lugar da equipe `97132875544830`.
Esta entrega melhora o jogo existente; não acrescenta moedas, modos ou
regras de progressão. Critérios externos continuam no RELEASE_CHECKLIST.

## Problemas corrigidos

| Área | Defeito observado | Alteração entregue |
|---|---|---|
| Lobby | Farol e placa da academia sem contato com o chão; pontes sem sustentação | Base do farol rebaixada, dois pés da academia e quatro pilares em cada uma das sete pontes |
| Arquitetura | Passagem com aparência de túnel vazio; vitrines sem suporte visual | Nervuras inclinadas, travessas, painéis de vidro, luz de teto menor e montantes das vitrines |
| Iluminação | Vidro, estrada e pedestais produziam manchas de cor muito fortes | Vidro verdadeiro, metal e plástico em áreas grandes; energia em bordas e segmentos menores |
| Personagens | Equipamentos com material indiferenciado e ombreiras excessivamente cúbicas | Armaduras metálicas, placas inclinadas, facetas no herói de pedra e folhas/casca no herói orgânico; rig e emissão preservados |
| HUD | Barra superior cobria o horizonte; várias melhorias verdes sobre a horda | Comando e núcleo separados em telas largas; no máximo dois avisos rápidos, com prioridade ao herói selecionado |
| Poderes | Feixes grossos, discos sólidos e coluna de luz escondiam os alvos | Feixes de núcleo fino, ondas vazadas, coluna curta, emissões menores; orçamento de efeitos preservado |
| Som | Ataques da mesma família soavam muito parecidos | Treze perfis de timbre, altura e volume, com equalização das vozes reutilizadas e retorno ao perfil neutro |
| Revisão | Vitrine aceitava o marcador de modo como conclusão; comandos de efeitos não fotografavam | Marcador de conclusão exato e captura automática das cenas `fx:*` |

Não se eliminaram movimentos intencionais de hologramas, nave e obstáculos
de parkour. Os suportes físicos são conferidos por teste, junto com o teto de
4.500 peças. Os detalhes menores da vegetação foram redistribuídos para
acomodar a estrutura sem aumentar esse teto.

## Verificação e evidências

- `python tools/test.py`: compilação, regras, servidor, áudio, mundo,
  layouts e seis roteiros completos de cliente. Inclui novos testes de
  contato dos suportes, materiais, limite de avisos, seleção de uma torre
  distante, neutralização dos timbres e limpeza do orçamento de efeitos.
- Fontes do Studio comparadas com o Git e com os arquivos locais antes da
  sincronização seletiva. Não houve alteração direta dos scripts no Studio.
- Catálogo fotografado: 43 heróis em oito grupos, seis chefes e cinco
  famílias de inimigos, todos com câmera em três quartos.
- Combate real: campanha com cinco heróis e carga adicional de 80 inimigos.
  Fotografias de HUD fixo são identificadas separadamente das de partida.

Capturas locais, fora do Git:

- [Farol antes](../test-results/refinement/before/beacon.png) e
  [depois](../test-results/refinement/after/beacon.png).
- [Passagem antes](../test-results/refinement/before/passage.png) e
  [depois](../test-results/refinement/after/passage.png).
- [Catálogo, primeiro grupo](../test-results/showroom/refine-roster-1-full.png)
  até `refine-roster-8-full.png`, na mesma pasta.
- [Chefes](../test-results/showroom/refine-bosses-final-full.png) e
  [inimigos](../test-results/showroom/refine-enemies-final-full.png).
- [Combate com carga](../test-results/refinement/after/combat-crowd.png).
- [Combate final, com dois avisos](../test-results/refinement/after/combat-final.png).
- [Feixes](../test-results/refinement/fx/lasers.png) e
  [poderes](../test-results/refinement/fx/powers.png).
- [HUD vertical](../test-results/refinement/ui-portrait/04-tower-phone.png) e
  [HUD em inglês](../test-results/refinement/ui-english/03-tower-phone.png).

As comparações do lobby usam as mesmas posições de câmera, mas a janela
foi ampliada durante a revisão: não são pares com resolução idêntica.
`wave-layout.png` é uma tela fixa de HUD; `combat-*.png` veio de partida real.
As cenas `fx:*` exercitam os efeitos reais com eventos de revisão; não são
evidência de dano confirmado pelo servidor.

## Avaliação crítica e próxima produção

O elenco está integrado e foi inspecionado inteiro. A nota de acabamento dos
modelos ainda é **3/5**: troncos e pernas muito cúbicos, pequenos acessórios
repetidos e algumas faces pouco expressivas. Material novo não resolve
isso sozinho. Próxima amostra: redesenhar tronco, cintura, mãos e pés de um
herói humanoide, de um grandalhão e de um inimigo comum; comparar em partida
antes de espalhar a proporção pelo catálogo. Evidência: grupos 1–8 acima.

O áudio entregue usa os IDs existentes. Os doze WAVs em
`assets/audio/refined/` continuam aguardando envio pelo dono, declaração de
autoria e moderação. A música do lobby foi preservada; a partida mantém o
arranjo de ação existente. Testes de carregamento e mix não substituem ouvir
o resultado e avaliar a preferência musical.

Celular físico, quatro jogadores, viagens entre lugares, sessão prolongada
e compras publicadas continuam pendentes. A inspeção do Studio e os dublês
não serão apresentados como esses testes. Divulgação deve vir depois da
validação da primeira partida e dessas dependências; não há garantia de
viralização por alterar efeitos ou miniaturas.

## Entrega

Suíte completa verde: 6.137 verificações do mundo, 6.704 de layout, seis
roteiros completos de cliente e demais testes de servidor, regras e áudio.
Lobby final com **4.362 peças no dublê e 4.455 no Studio**, abaixo do teto de
4.500. A primeira reconstrução final revelou 4.569 peças reais, apesar de
4.476 no dublê. Foram reduzidos os parafusos decorativos dos portais e
espaçadas quatro flores por canteiro; suportes e circulação preservados.
`studio_sync.py --preview-lobby` agora recusa uma reconstrução acima do teto,
em vez de considerar suficiente apenas a contagem automatizada.
Revisão do Studio em PC,
667x375 e 375x667; inglês também em PC e 667x375. Sem cortes de texto ou
erros Luau detectados nessas rodadas. Emulação de layout não é aparelho real.

PC utilizado: i5-14600KF, RTX 4060 Ti. Duas amostras de dez segundos em
Cartas/Complexo Gama, cinco torres: **60 FPS** antes e depois de acrescentar
80 inimigos. Snapshot final com 114 inimigos, dano confirmado 374;
p95 de quadro 17,82/18,22 ms. Memória total reportada pelo Studio:
3.701,2/3.705,8 MB. Esses dois pontos não demonstram estabilidade prolongada
nem representam o consumo de um cliente publicado isolado.

Três capturas reais de combate em `test-results/refinement/combat-event-*.png`:
113, 258 e 396 ms desde o início da captura. A ferramenta solicitou intervalo
de 33 ms, mas PrintWindow e gravação aumentaram o intervalo real; não se
apresentam essas imagens como quadros consecutivos a 60 FPS.

Notas da revisão visual: leitura 4/5, consistência 4/5, acabamento dos
modelos 3/5, sensação visual de combate 3/5, desempenho de PC 4/5.
Acabamento e peso dos ataques continuam em M22.7/M22.9. Escuta, marca e
retenção não recebem nota conclusiva nesta entrega.

Publicação será registrada após confirmação no log do lugar da equipe.
