# Inicialização e farms AFK — 10/10/2026

Pedido: transformar a inicialização, a tela de economia do Ouro AFK e a do XP
AFK em telas completas, integradas ao lugar oficial `97132875544830`.

## Diagnóstico e solução

| Evidência anterior | Problema | Correção e verificação |
|---|---|---|
| Print do dono: Farm AFK com título, quatro linhas e dois botões sobre o lobby | O cenário, o tutorial e a navegação continuam disputando atenção; não há composição própria | Observatório dimensional opaco, cenário original em camadas e painel com hierarquia. Capturas de Ouro e XP e teste dos dois botões |
| `src/first/init.client.luau` anterior e cena `loading` | A inicialização e a conexão usam composições diferentes; o carregamento inicial depende de esperar o mundo antes do prazo de saída | Mesma arte empacotada em ReplicatedFirst para as duas etapas. Prazo de 60 segundos inclui o carregamento do mundo; teste antes do cliente/perfil e de saída por prontidão/prazo |
| `AfkScreenStats` anterior | Unidade, relógio e salvamento estão em um único bloco; zero recebido já é marcado como salvo | Total recebido, próximo pagamento com barra, duração e estado de salvamento separados; Ouro e XP distintos. Dados exclusivamente dos atributos do servidor |

## Implementação

- `src/first/ScreenArt.luau`: arte vetorial nativa original, sem downloads:
  observatório, ilha/cidade, lua, deck em perspectiva, reator e moeda/cristal.
  Mesma composição de inicialização usada antes e depois do cliente carregar.
- `src/first/init.client.luau`: capa inicial em tela inteira, idioma do Roblox,
  status de mundo/perfil e descarte da conexão de renderização ao sair.
- `src/client/RestScreen.luau`: dashboard de Ouro/XP, botões de mostrar o mundo
  e voltar ao lobby; arte estática visível com a renderização 3D desligada.
- Controlador: integra os atributos existentes, refaz a tela ao mudar tamanho,
  idioma ou tipo de farm, fecha janelas anteriores e esconde o chat durante a
  apresentação. Nenhuma mudança de taxa, pagamento, salvamento ou reconexão.
- `Review`: cenas `afkgold`, `afkxp` e `startup`, além da conexão `loading`.
  Fixtures não concedem recursos nem chamam ações do servidor.
- Teste de cliente: inicialização real antes da interface, prontidão/prazo,
  contadores autoritativos, salvamento pendente, primeiro pagamento, troca de
  farm, orçamento de menos de 600 instâncias e restauração de 3D/chat/saída.

Referências: print do dono e sistema visual angular já integrado em M26.
Arte criada por código neste projeto; não usa imagem gerada nem da Toolbox.

## Matriz de aceite

Estados: Pendente, Implementado, Verificado no jogo, Bloqueado por dependência.

| Área | Estado | Evidência |
|---|---|---|
| Arte e dashboard de Ouro AFK | Verificado no jogo | Revisão e pagamento natural no servidor do Studio, com 3D desligado |
| Arte e dashboard de XP AFK | Verificado no jogo | Revisão e pagamento natural no servidor do Studio, com 3D desligado |
| Apresentação de inicialização e conexão | Verificado no jogo | Cenas `startup` e `loading` usam a mesma composição de ReplicatedFirst; prontidão/prazo cobertos pelo teste do script inicial real |
| Contadores, confirmação e retorno | Verificado no jogo | Ouro 5→10, XP 0→10 e retorno ao lobby; perfil temporário de Studio |
| PC, celular horizontal/vertical e inglês | Verificado no jogo | 32 capturas dirigidas, sem cortes de texto/erros detectados; celular emulado |
| Sincronização e publicação oficial | Verificado no jogo | 39 fontes conferidas, cinco módulos sincronizados, `PublishSuccessful` no place correto |
| Viagem/reconexão no cliente publicado e celular físico | Bloqueado por dependência | Checklist de lançamento; esta entrega não certifica esses fluxos |

## Validação e entrega

Suíte completa final aprovada: `test-results/fullscreen-delivery-suite.txt`.
Os seis roteiros completos do cliente terminaram em 30,2 segundos, com
1.019–1.025 verificações por formato. O teste também cobre rotação da tela
AFK sem alterar o recurso recebido e perfil chegando antes do mundo sem
concluir prematuramente o carregamento.

Primeira
rodada do cliente acusou um serviço ausente no dublê de ReplicatedFirst;
`LocalizationService` foi acrescentado ao ambiente de teste, sem retirar
asserções.

Capturas: `test-results/fullscreen/{pc,phone,portrait,english,final-portrait}`.
A revisão final no vertical acrescentou um painel de leitura para o texto
da inicialização não disputar contraste com o cristal. Comparação anterior:
print do dono e cena `loading` de M26; não foi fabricado um antes do AFK.

- [Ouro AFK](../test-results/fullscreen/pc/01-afkgold.png)
- [XP AFK](../test-results/fullscreen/pc/02-afkxp.png)
- [Inicialização](../test-results/fullscreen/final-portrait/01-startup.png)
- [Inicialização vertical](../test-results/fullscreen/final-portrait/01-startup-phone.png)
- [Pagamento natural de Ouro](../test-results/fullscreen/live/gold-paid.png)
- [Pagamento natural de XP](../test-results/fullscreen/live/xp-paid.png)

No playtest real, o personagem entrou nas duas zonas e acionou os botões
reais. Foram aguardados os pagamentos naturais, sem conceder recursos por
comando: Ouro passou de 5 para 10, XP de 0 para 10, com a confirmação exibida
após o servidor terminar. Mostrar jogo restaurou o mundo sem encerrar a
farm; Voltar ao lobby encerrou a zona e manteve os valores. Evidências em
`test-results/fullscreen/live/verified-flow.json`.

Galeria entregue no Desktop:
`Multiverse_Telas_Completas_2026-10-10/INDICE.html`, com telas de PC,
horizontal/vertical, inglês e capturas do pagamento real.

Cinco módulos sincronizados seletivamente; 39 fontes comparadas ao
repositório com o prefixo de papel anterior preservado. Lobby de edição
reconstruído com 4.455 peças. Publicado em **10/10/2026 às 14:06:51 local
(17:06:51 UTC)** no mesmo place **97132875544830**, confirmado por
`Go to PublishSuccessful`. Evidência em
`test-results/fullscreen-publication.json`. Studio deixado em edição.

Avaliação visual desta entrega: leitura 4, acabamento 4, consistência 4,
objetivo 4 e recompensa 4. Movimento/impacto permanece 3: o cenário é
estático, com apenas o indicador de espera e os contadores se atualizando.
Combate e modelos não foram alterados. A arte tem menos de 600 instâncias,
sem crescimento durante as atualizações; não foi feita nova medição de FPS.

Permanece o limite de teste em Studio no PC do dono com perfil temporário:
não equivale à certificação de DataStore publicado, reconexão, sessão
prolongada ou aparelho físico. A próxima validação concreta é uma sessão AFK
no cliente publicado, com reconexão e toque em um celular físico, já prevista
no checklist de lançamento.
