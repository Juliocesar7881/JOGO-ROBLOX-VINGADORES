# Lançamento e retenção — configuração reconferida em 12/10/2026

Projeto oficial: place **97132875544830**, universo **10768165352**.
Código no `main`; fonte da verdade em `src/`. Publicar uma atualização nesse
lugar não muda o público da experiência. Testes locais não comprovam compras,
rede, aparelho físico ou retenção.

Prioridade de lançamento e monetização em
[`LANCAMENTO_MONETIZACAO_2026-10-12.md`](LANCAMENTO_MONETIZACAO_2026-10-12.md).
Galerias foram movidas da Área de Trabalho para `test-results/galerias/`.

## Acesso público e alcance

- [ ] Conferir Audience e Audience > Reach na conta do dono. Atualização de
  código publicada não comprova acesso público para cada faixa etária.
  A captura anterior mostrava alcance limitado a 16+ e amigos de confiança.
- [ ] Concluir o questionário e as verificações exigidas pela plataforma.
  A documentação atual diferencia acesso 16+ do acesso a todas as idades,
  incluindo Kids/Select; não presumir que selecionar Public libera ambos.
  Fonte: [requisitos oficiais](https://create.roblox.com/docs/production/publishing/publish-games-and-places#publishing-requirements).

## Código e apresentação

- [x] 43 heróis, 11 bases, seis mapas; três raridades; campanha, competitivo,
  Cartas e treinamento. Missões, login, presentes de tempo, baú gratuito,
  coleção, talentos, temporada e cooperação já existem.
- [x] HUD com arte própria, modelos reais nos retratos e fallback de rede.
  Carregador não depende de downloads opcionais. Recrutamento com uma única
  roleta/finalização, incluindo baús ganhos.
- [x] Sete bancos Sonniss configurados: interface, eventos, invocação, combate,
  poderes, chefes e ambiente. Esses bancos já foram enviados.
- [x] Próximo objetivo pelo progresso salvo, baú gratuito antes da primeira
  compra com Ouro e objetivo no resultado; analytics corrigido e medição
  dos tempos até torre, poder, baú, resultado e segunda partida.
- [ ] Primeira entrada no cliente publicado, conta nova e rede real: abrir
  uma vez, carregar perfil, concluir treino, sair e reentrar. O perfil
  temporário do Studio não fecha esse item.
- [ ] Clareza com jogadores: objetivo, funções dos heróis, custos/alcance e
  recarga sem explicação externa. Anatomia e peso dos golpes continuam em
  M22.7/M22.9 até revisão completa do catálogo.

## Configuração e monetização

Auditoria: `python tools/audit_launch.py --output test-results/launch-audit.json`.
Ela executa o catálogo atual; ID preenchido não comprova venda nem entrega.

- [x] Metadados dos 24 IDs configurados consultados pelo MarketplaceService
  em 11/10. Drone, Treinamento e Velocidade 3x estão à venda pelos preços do
  catálogo. Quinze produtos de heróis e cinco consumíveis possuem metadados.
- [ ] **VIP:** ID existente, mas `IsForSale=false` reconfirmado pela API pública em 12/10.
  Habilitar no Creator Hub com o preço do catálogo (299), depois conferir
  no jogo. Não aceitar contratos em nome do dono.
- [ ] **Temporada:** passe ID zero; preço do catálogo 399. Criar/configurar
  depois de resolver os termos que o Creator Hub eventualmente exigir.
- [ ] **26 produtos de heróis sem ID**, entre 41 compráveis. Lista atual em
  `docs/director/ROBUX_CATALOG.md` e no auditor. Dois iniciais não precisam
  de produto. As rotas de aquisição com recursos do jogo permanecem.
- [ ] Confirmar pessoalmente contratos pendentes, se ainda aparecerem. O
  registro de 01/10 relata “Updated Agreements”; nenhuma aceitação automática.
- [ ] Compra real de cada passe/produto em conta de teste: entrega única,
  saldo, cancelamento, saída/reentrada e recibo repetido. Pacote Inicial:
  segunda compra concede apenas a compensação de Ouro.
- [ ] Conta sujeita à restrição de itens aleatórios: conferir política e
  rotas permitidas; sorteio pago é recusado pelo servidor quando restrito.
- [ ] Música de batalha: ID dedicado antigo ainda sujeito à moderação;
  cliente tem fallback de ação. Verificar aprovação/acesso antes da troca.
  Declarações de autoria são confirmadas pessoalmente pelo dono.

## Cooperação, persistência e implantação

- [x] Lugar atual em **Standalone**, lobby e partida no mesmo servidor.
  IDs Lobby/Match/AFK separados são zero; `deployment/local.json` ausente.
  Isso não equivale a três lugares publicados ou teleporte validado.
- [ ] Quatro jogadores reais: fila simultânea, quinto recusado, sair/voltar,
  pronto/velocidade em grupo, poderes, vitória/derrota, recompensas e replay.
- [ ] Fechar o cliente na partida e reabrir; conferir progresso e reconexão.
  Repetir com rede interrompida; nenhum perfil pode ser zerado.
- [ ] Se adotar lugares separados: publicar no mesmo universo, usar IDs
  reais e seguir `docs/DEPLOYMENT.md`. Portal com 1 e 4 pessoas, falha de
  transferência e retorno. Não inventar IDs nem substituir isso pelo build.
- [ ] Sessão de 30–60 minutos com replays e AFK: acompanhar memória,
  instâncias, sons e efeitos ativos; verificar estabilização e limpeza.

## Aparelhos e página

- [ ] Android de entrada/iPhone físico: FPS no lobby/ondas densas, toque longo,
  colocar/melhorar, mirar Q, arrastar árvore/câmera e notch. Emulação comprova
  layout; não comprova desempenho nem gestos no aparelho.
- [ ] Ouvir em fone/alto-falante: golpes e poderes distintos, música abaixo
  das informações importantes, opções de som e efeitos funcionando.
- [ ] Página: miniaturas fiéis, título/descrição localizados e questionário
  de conteúdo. Materiais em `assets/store/` e `docs/STORE_PAGE.md`.
- [ ] Decisão final de marca pelo dono. Não alterar audiência, preços nem
  colaboradores como parte da publicação de código.

## Aceite de retenção

- [ ] 10–20 pessoas novas jogando sem orientação: observar hesitação e
  abandono. Roteiro em `docs/RETENCAO_LANCAMENTO_2026-10-11.md`.
- [ ] Eventos no Analytics publicado; Studio não envia eventos reais.
  Separar novos/retornando e comparar a mesma versão/origem/dispositivo.
- [ ] D1 depois do dia seguinte e D7 após uma semana, anotando volume e
  origem da amostra. AFK não comprova envolvimento em combate.
- [ ] Corrigir o maior abandono observado antes de ampliar divulgação e
  repetir o teste. Publicação não garante viralização.
