# Refinamento do plano de continuação — 08/10/2026

Projeto: Multiverse DoomsDay Tower Defense. Lugar da equipe: `97132875544830`.
Base da entrega: `bf807bd`, preservando o catálogo, os modos, as ondas por mapa e a economia atuais.

## Diagnóstico e entregas

| Problema observado | Evidência | Correção | Verificação |
|---|---|---|---|
| A ficha dos heróis só respondia a mouse | `UI.hover` só conectava MouseEnter/MouseLeave | Segurar por 0,4 s abre a ficha; soltar fecha; arrastar cancela; o toque longo não equipa ao soltar | Testes do cliente nos seis formatos, com toque curto, longo e arrasto |
| A árvore encolhia na ficha da partida | Raio dos hexágonos podia cair a 22–26 pixels lógicos | Raio mínimo de 40, rolagem nos dois eixos, mapa sem coordenadas negativas, descrição mais compacta e preservação da rolagem | Cenas `sheet`, PC, celular vertical e horizontal; teste da posição da rolagem |
| O cartão não mostrava a contribuição daquela torre | O servidor só acumulava o dano do jogador | Dano efetivo e abates por torre, replicados pelo servidor e atualizados sem recriar o cartão a cada acerto | Simulação: sobrevivência, abate, excesso de dano, repetição, escudo e fonte da base; revisão `tower` |

Outras melhorias do lote:

- Dicas continuam funcionando com o mouse. O gesto de arrasto não abre uma ficha durante a rolagem.
- Chefes fotografados em 3/4. Comandante Sombra recebeu ombreiras próprias; Megabruto ganhou espinhas projetadas nos ombros; a cauda articulada do Gekko ficou mais longa.
- `server:unlock` libera a campanha apenas na memória da revisão do Studio. Não concede Ouro, XP ou compras; perfis de nuvem recusam a operação. Desbloqueio e equipe de revisão são protegidos pela fila de sessão e atualizam ambas as cópias em memória, sobrevivendo ao salvamento automático.
- `InteractionHud.luau` compartilha o desenho dos avisos reais e das novas cenas `afk` e `prompt`. O botão de viagem AFK tem uma linha separada, sem disputar espaço com o título.
- Os seis roteiros completos do cliente agora rodam em processos independentes. `--workers 1` permite executá-los em série; nenhuma resolução ou etapa de layout foi removida.
- Números de dano usam os maiores acertos agregados pelo servidor, com limite de dez por sincronização e quarenta simultâneos. Acertos mais fortes têm uma pequena animação de escala; “Menos efeitos” remove essa animação.
- O novo nível acende o indicador do cartão com uma animação curta, desativada em “Menos efeitos”.
- A loja vertical distribui selo, valor por Robux, nome e descrição em linhas próprias. O Pacote Inicial mostra o benefício completo. A ficha do herói ajusta nomes longos, separa maestria e estrelas e mostra as cartas numa linha própria em telas estreitas.
- A revisão limpa a sequência de baús e a janela anterior ao trocar de cena. O aviso AFK aguarda o layout do objetivo e usa o texto completo de renda, pagamento, sessão e salvamento. A ferramenta agora retorna erro quando encontra textos cortados ou erros de script.

## Matriz de aceite

Estados: Pendente; Implementado; Verificado no jogo; Bloqueado por dependência.

| Item do plano | Estado | Evidência e limite |
|---|---|---|
| A — toque longo | Implementado | Testes de entrada de toque nos seis formatos. Ainda exige toque em aparelho real. |
| B / M17.1 — árvore da partida | Verificado no jogo | Capturas do Studio e teste de rolagem preservada. |
| C / M17.2 — chefes | Verificado no jogo | Comparação da mesma câmera 3/4, seis chefes; orçamento do world boot aprovado. |
| D — desbloqueio de revisão | Verificado no jogo | Partida nova de Cartas em `gamma` iniciada com cinco torres, após desbloqueio exclusivamente em memória. Testes confirmam preservação no salvamento e recusa em nuvem. |
| E — cenas AFK e interação | Verificado no jogo | Mesmos componentes da apresentação real; varredura de texto do Studio. |
| F — tempo da suíte | Implementado | Seis roteiros completos; rodada final em 115,5 s e anterior à publicação em 105,8 s. Rodadas anteriores: 263,8 s, 272,4 s, 116,3 s, 115,7 s, 118,4 s e 110,9 s. O plano anterior registrava aproximadamente dez minutos; não foi reexecutada uma linha de base serial nesta entrega. |
| G — contribuição e impacto | Verificado no jogo | Testes do servidor, cartão e indicador de melhoria; capturas `tower`, sequência real de ataques e 60 FPS durante a medição de carga. Não substitui sessão prolongada nem celular real. |
| H — varredura de interfaces | Verificado no jogo | 37 cenas em PC, português vertical/horizontal e inglês horizontal; cenas afetadas repetidas após as correções. Não substitui celular físico. |

## Testes e inspeção visual

`python tools/test.py` inclui compilação, 632.736 verificações de regras, 535 verificações de persistência/compras, 6.051 do mundo, seis roteiros completos de cliente, 2.968 do servidor e 1.577 da simulação de partidas, além dos contratos, layouts e builds.

Artefatos locais ficam em `test-results/`, que é ignorado pelo Git:

- `refinement-publish-suite.txt`: suíte aprovada antes da publicação; seis roteiros do cliente com 888–891 verificações cada.
- `refinement-docs-suite.txt`: repetição completa aprovada antes do commit de documentação e ajuste da captura de combate, saída 0; seis roteiros em 115,5 s.
- `review-pt-landscape.txt`: primeira varredura de PC e celular horizontal.
- `review-pt-landscape-final.txt`: cenas restantes e repetição das telas alteradas no horizontal.
- `review-pt-portrait.txt`: primeira varredura das 37 cenas de PC e celular vertical; os defeitos encontrados estão corrigidos nos registros seguintes.
- `review-pt-portrait-fixed.txt` e `review-pt-interactions-final.txt`: ficha, loja e avisos repetidos após as correções, sem corte nem erro de script.
- `review-en-landscape.txt`: 37 cenas em inglês, PC e horizontal.
- `review-en-landscape-final.txt`: cenas afetadas repetidas em inglês, sem corte nem erro de script.
- `showroom/bosses-refinement-3q.png`: antes do reforço das silhuetas, já com a câmera nova.
- `showroom/bosses-final-3q.png`: depois, com a mesma câmera e iluminação.
- `refinement/`: capturas preservadas por idioma/formato e sequência de combate.
- `refinement-performance-verified.txt`: medição real, snapshot do servidor e tempos da sequência de capturas.
- `refinement-prepublish-sync.txt`: confirmação do destino, módulos recebidos e reconstrução do lobby de edição.
- `refinement-publication.txt`: confirmação de publicação no mesmo lugar da equipe.

Comparações locais: `showroom/bosses-refinement-3q.png` e `showroom/bosses-final-3q.png`; ficha vertical antes em `refinement/pt-portrait/35-herocard-phone.png` e depois em `refinement/pt-portrait-final/05-herocard-phone.png`. Um aviso inicial de brilho na cena AFK foi registrado enquanto a animação de baús ainda cobria a tela; as capturas corrigidas de AFK não repetiram o aviso.

Os aparelhos utilizados nesta rodada são áreas de tela simuladas no Roblox Studio do PC do proprietário, incluindo 667×375 e 375×667. Não são medições em Android ou iPhone físicos.

## Sincronização, desempenho e publicação

A comparação dos scripts abertos com o Git encontrou somente o cabeçalho de papel do place, gerado pelo build, no script principal do servidor. O sincronizador preserva esse cabeçalho. Os demais arquivos coincidiram com a base antes das alterações.

Somente os módulos alterados foram sincronizados no lugar da equipe. Nenhuma configuração de acesso público, colaborador, preço ou produto foi alterada.

A medição de combate é reproduzível com:

```powershell
python tools/studio_review.py --window-handle <h> live --keep-playing
python tools/studio_refinement_check.py --window-handle <h>
```

Esse comando exige um playtest novo, sem batalha ativa, com perfil de memória. Desbloqueia a revisão, inicia cartas no destino válido do catálogo, posiciona a equipe e mede a carga antes e depois de adicionar 80 inimigos. Faz três capturas sucessivas com os intervalos reais registrados. Não testa compras, quatro jogadores físicos nem sessão prolongada.

O exemplo antigo `server:start manhattan cards` do plano foi substituído por `server:start gamma cards`: o catálogo atual associa Cartas ao Complexo Gama. Nenhuma associação de mapa/modo foi alterada para viabilizar a revisão. O primeiro ensaio real detectou uma batalha de treinamento já aberta e o descarte das alterações de revisão no próximo salvamento; o segundo defeito ganhou correção e teste de regressão.

Medição realizada no PC do proprietário: Intel Core i5-14600KF, GeForce RTX 4060 Ti e 31,8 GiB de RAM. Duas amostras de dez segundos no mesmo playtest:

| Amostra | FPS médio | Quadro p95 | Memória indicada pelo Studio |
|---|---:|---:|---:|
| Partida de Cartas, cinco torres | 60,0 | 17,62 ms | 5.073,0 MB |
| Após adicionar 80 inimigos | 60,0 | 18,17 ms | 5.085,8 MB |

O snapshot ao fim da segunda amostra tinha 114 inimigos (incluindo a onda e reforços), cinco torres e 319 de dano efetivo acumulado. A memória inclui o ambiente do Studio e não representa um cliente mobile isolado. Essa janela curta não comprova estabilidade de memória em sessões prolongadas.

As três capturas próximas dos ataques ficaram em `refinement/combat-event-01.png`, `-02.png` e `-03.png`, com tempos de 116, 269 e 420 ms desde o início da captura. São imagens sucessivas com cerca de 152 ms entre elas, devido ao custo de PrintWindow; não são três frames consecutivos a 60 FPS. Números de dano e os ataques foram inspecionados nessas imagens.

Código do jogo salvo e enviado ao `main` no commit `3dd40f4`. Todos os módulos alterados foram sincronizados seletivamente no place `97132875544830`; a última sincronização confirmou `PlayerService`, `WorldBuilder` e 4.537 objetos no lobby de edição. Após o dono confirmar que o PC estava livre, a publicação nesse mesmo lugar foi confirmada por `Go to PublishSuccessful` às **13:16:21 UTC / 10:16:21 local de 08/10/2026**. O Studio ficou em modo de edição. Nenhuma configuração de acesso público ou colaboradores foi modificada.

## Arquivos e assets da entrega

- Interface: `UI.luau`, `Panels.luau`, `Sheet.luau`, `MatchHud.luau`, `Review.luau`, `Effects.luau`, `init.client.luau` e o novo `InteractionHud.luau`, em `src/client/`.
- Servidor: `PlayerService.luau`, `MatchService.luau`, `WorldBuilder.luau` e `init.server.luau`, em `src/server/`.
- Ferramentas: teste do cliente em processos independentes, vitrine 3/4, captura sequencial, revisão que acusa falhas e novo `tools/studio_refinement_check.py`.
- Testes: entrada de toque, rolagem, componentes de interação, estatísticas das torres, filtros de efeitos, memória de revisão e contratos do Studio.
- Arte: os modelos procedurais dos três chefes foram alterados em `WorldBuilder.luau`; não houve upload de asset nem troca de ID de áudio ou imagem.

## Dependências que continuam com o proprietário

1. Confirmar autoria e reenviar a música de batalha bloqueada pela moderação.
2. Aceitar os termos do Creator Hub, habilitar o VIP e criar/configurar os 19 produtos de heróis restantes.
3. Decidir a marca e os visuais da liga e o nome “Capitão Men” antes de abrir ao público.
4. Finalizar página, ícone, miniaturas, descrição e classificação etária.
5. Publicar/configurar os lugares separados e testar portal com um e quatro jogadores e reconexão no Roblox normal.
6. Testar toque, notch, áudio, FPS e memória em celular real, incluindo um Android antigo.
7. Realizar compras de teste e conferir as concessões reais, incluindo o Pacote Inicial duas vezes.

Essas dependências estão em `docs/RELEASE_CHECKLIST.md`. A revisão do Studio e os testes automatizados não encerram o aceite de lançamento.
