# Lançamento e retenção — configuração reconferida em 12/10/2026

Projeto oficial: place **97132875544830**, universo **10768165352**.
Código no `main`; fonte da verdade em `src/`. Publicar uma atualização nesse
lugar não muda o público da experiência. Testes locais não comprovam compras,
rede, aparelho físico ou retenção.

Prioridade de lançamento e monetização em
[`LANCAMENTO_MONETIZACAO_2026-10-12.md`](LANCAMENTO_MONETIZACAO_2026-10-12.md).
Galerias foram movidas da Área de Trabalho para `test-results/galerias/`.

## Acesso público e alcance

- [x] Audience e Audience > Reach conferidos em 12/10: Public, alcance
  **16+ e amigos de confiança**; classificação Minimal, questionário completo.
  Exclusão das recomendações desmarcada. Isso não libera todas as idades.
- [ ] O dono concluir identidade e autenticação em duas etapas exigidas pela
  conta. Idade por câmera aparece concluída; alcance ainda mostra taxa
  reembolsável não submetida / alternativa de 0/250 jogadores engajados.
  Nenhum documento, senha, contrato ou pagamento foi tratado automaticamente.
  [Requisitos oficiais](https://create.roblox.com/docs/production/publishing/publish-games-and-places#publishing-requirements).

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

- [x] **51 itens cadastrados** no Creator Hub e Config: 41 heróis, cinco
  passes e cinco consumíveis; 26 produtos e Temporada criados em 12/10,
  anteriores atualizados. Auditor sem IDs faltantes; cinco passes à venda.
- [x] **Preços reduzidos** autorizados pelo dono: heróis 9/29/79 Robux;
  passes 19–49; Ouro 5/19/39/79 e Pacote Inicial 19. VIP ativado por 29.
  Cliente usa cotação regional, sem anunciar preço antigo/global.
  Registro em [CONFIGURACAO_COMERCIAL_2026-10-12.md](CONFIGURACAO_COMERCIAL_2026-10-12.md).
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
- [x] Página: nome/descrição base em inglês, português e espanhol manuais,
  17 idiomas automáticos habilitados; ícone/miniatura atuais preservados.
  Questionário Minimal preenchido. Fontes em `assets/store/release-2026-10-12/`.
- [ ] Decisão final de marca pelo dono. Preços e metadados foram autorizados
  explicitamente em 12/10; colaboradores não foram alterados.

## Aceite de retenção

- [ ] 10–20 pessoas novas jogando sem orientação: observar hesitação e
  abandono. Roteiro em `docs/RETENCAO_LANCAMENTO_2026-10-11.md`.
- [ ] Eventos no Analytics publicado; Studio não envia eventos reais.
  Separar novos/retornando e comparar a mesma versão/origem/dispositivo.
- [ ] D1 depois do dia seguinte e D7 após uma semana, anotando volume e
  origem da amostra. AFK não comprova envolvimento em combate.
- [ ] Corrigir o maior abandono observado antes de ampliar divulgação e
  repetir o teste. Publicação não garante viralização.
