# Situação de produção

Este registro separa o que está pronto e verificado do que ainda depende de
teste real, de arte ou de configuração. Plano de referência: "Plano de
produção — Multiverse Doomsday Tower Defense" (etapas 0–7).

## Etapa 1 — estrutura e regras (2026-09-26)

### Concluído e verificado por testes automatizados

- **Ouro da partida substitui a Energia.** Cada inimigo derruba moedas
  (`Rules.KillCash`) que precisam ser pegas (ímã = `Config.CollectRadius`,
  +15%/ponto de Magnetismo; o Drone Coletor pega tudo). Esse Ouro paga,
  melhora e vende heróis e evolui a base; bônus direto no fim da onda
  (`Rules.WaveCash`). Simulação: bot que não pega moedas cai na onda ~19; bot que
  pega vence as 40 ondas de Manhattan.
- **Ouro do lobby só pelo resultado da partida** (`Rules.RunGold`): vitória paga
  tudo (campanha 40/onda: 2.000 em 50, 1.600 em 40, 2.800 em 70; cartas 2.500);
  derrota paga 40% das ondas concluídas; competitivo 25/onda +100 a cada dez.
  Ondas concluídas ficam guardadas mesmo com derrota ou queda.
- **Ondas por destino:** treino 20; campanha Manhattan 40, Gama/HYDRA/Wakanda/
  Asgard 50, Latvéria 70; cartas 50; competitivo sem fim. Chefe a cada 10; o
  último da campanha é o chefe do mapa; os anteriores nunca antecipam o final.
- **Loki corrompido** é o chefe de Asgard: ilusões temporárias, sem recompensa,
  que somem sozinhas e não ferem o núcleo.
- **Infinito casual removido.** Competitivo (`ranked`) é o único modo sem fim,
  com três entradas (HYDRA, Wakanda, Latvéria), placar novo `comp2` por mapa,
  tamanho do grupo e temporada, e voto unânime para encerrar entre ondas.
- **Desbloqueios:** treino e campanha sempre abertos; primeira vitória de
  campanha abre cartas e competitivo. Nada depende de vencer um modo sem fim.
- **Cartas:** oferta depois das ondas 5…45; nenhuma depois da vitória.
- **Lobby:** 11 portais — 3 campanhas no centro, 3 expedições nos cantos do sul,
  3 competitivos na arena (com placar da temporada), cartas e treino no canto
  nordeste; mercado no noroeste; zona AFK no oeste.
- **Correções do plano (3.3):** a arma da base mede o alcance do mesmo ponto de
  onde dispara; o pagamento AFK só zera o relógio depois de confirmado e cada
  minuto tem id próprio (repetir nunca paga em dobro).
- Duração medida na simulação (sem o voto de pronto): treino 12,7 min;
  Manhattan 34,4 min; cartas 48,7 min; competitivo ~40 min até a onda 39.

- **Construção única** (`Rules.BuildCheck`): a prévia e o servidor usam a
  mesma regra; recusas dizem o motivo (caminho, ocupado, fora da área, Ouro,
  limite); núcleo e bases bloqueiam; alcance da prévia inclui bônus.
- **Barricada** aparece atravessada na rua exatamente onde a regra para os
  inimigos (15 studs do núcleo) e desbota conforme perde vida.
- **Rolagem** dos painéis preservada nas atualizações do servidor.
- **Preparação do portal:** cartão com ondas, chefe final e prêmio; o primeiro
  passageiro pode COMEÇAR antes da contagem.
- **Líder:** slot 1 com "LÍDER — define sua habilidade" e botão TROCAR LÍDER.
- **Compra garantida** com Ouro para contas com itens aleatórios restritos
  (`Rules.GuaranteedPrice`, custo esperado no baú mais barato).
- **Proporções:** Hulk ~10,5 studs com cabeça menor e mãos enormes; Groot alto e
  estreito; Rocket com 60% da altura humana (só visual).
- **Evolução em colmeia** (hexágonos) com arrastar, zoom, centralizar e cartão
  "Agora → Próximo", custo e requisito.
- **Parkour** opcional no bosque: título "Explorador da Aurora" uma vez, sem Ouro.
- **AFK:** tela de economia (desliga o 3D), sessão, total recebido, salvando e
  "Voltar ao lobby"; sons da interface com chave própria.
- **Prévia animada das rotas** na preparação e aviso de NOVA ENTRADA.
- **Chefes:** janela VULNERÁVEL de 3 s (+25% de dano) depois de cada poder.
- **Telemetria:** saída no meio da partida por onda, Ouro da partida coletado
  por minuto e duração das sessões AFK.
- **Lugar AFK dedicado** (código pronto, desligado até configurar `AfkPlaceId`).
- **Entrada dos chefes:** faixa com nome ("⚠ CHEFE" / "⚠ CHEFE FINAL") e som
  quando o chefe entra na rua.
- **Queda na partida:** quem cai do mapa volta ao próprio posto.
- **Competitivo além da onda 70:** teste chega à onda 149 sem limite antigo,
  com recorde, Ouro por onda e horda dentro do teto.
- **Voadores** têm sombra no chão da rota.
- **Campo de Treino** no canto de treino/cartas: tapete verde abre o painel,
  o herói escolhido sobe ao palco com o anel do alcance real e ataca três
  bonecos por 30 s; sem recompensa, sem dano real.

### Rodada seguinte (2026-09-26/27), concluído e verificado por testes

- **Área proibida marcada ao posicionar:** faixa das ruas, círculo de cada
  torre e base e borda da área, com os mesmos números de `Rules.BuildCheck`.
- **Animações do herói:** respiração parada (perto da câmera), pulo com coluna
  dourada ao melhorar, braços erguidos na habilidade, e **interrupção
  visível** (estrelas e postura caída) quando um chefe paralisa a torre.
- **Leitura dos inimigos:** suporte ligado a quem acelera, camuflado sólido
  ao ser revelado, invocador com orbes das invocações restantes e aviso antes
  de invocar, faíscas na armadura, corredor inclinado, poeira do brutamontes.
- **Áudio:** 12 sons próprios novos, entre eles um ambiente por mapa e um som
  por família de arma. No máximo 4 sons de arma por quarto de segundo, mais
  baixos com a distância. Aviso quando a habilidade volta.
- **Estados de tela:** placar e preços da loja Robux mostram carregando,
  indisponível e falha com **tentar novamente**.
- **Toque mínimo de 48 px** em todos os botões de partida e do lobby testados.
- **Níveis com nomes próprios:** NV (conta), MAESTRIA (herói, 1–20), RANK
  (habilidade, 1–5), Melhoria (torre, só na partida).
- **Coleta de Ouro:** heróis coletores (Falcão, Homem-Formiga, Rocket, Senhor
  das Estrelas) e habilidades de área recolhem o seu Ouro. Nada cria Ouro.
- **Pipeline de arte final:** `.rbxmx` do Studio em `assets/models` com autor
  e permissão; o jogo passa a usar o modelo sozinho (heróis, retratos,
  inimigos, ponto de disparo `Muzzle`, animações opcionais).
- Só se mexe na barra do lobby o que tem novidade.
- **Passe de arte procedural (verificado no Studio):** os 36 heróis em estilo
  "vinil" (corpo arredondado, rosto que segue a curva da cabeça, estrelas de
  verdade, figurino próprio de cada reforço); todos os inimigos e variantes
  regionais (camisa rasgada, sobrancelha, equipamento que acompanha o braço,
  11–19 peças cada); os seis chefes com silhueta própria; lobby com troncos
  redondos, bandeirolas triangulares acima dos portais, pisos de pedra nos
  distritos e o Nico no mesmo estilo. `tools/studio_showroom.py` fotografa
  heróis, inimigos e chefes direto no Studio.

### Implementado, aguardando teste real (Studio/aplicativo)

- Leitura visual das moedas maiores, do ímã e do aviso "no chão".
- Distritos novos do lobby (cantos do sul) e colisões com a floresta.
- Voto de encerrar no competitivo com grupo de 2–4 pessoas.
- Aviso do AFK (sessão, total recebido, salvando).
- Campo de Treino: posição entre as duas pistas dos portais e leitura dos
  disparos no lobby.

### Depende de arte ou configuração

- Modelos, texturas e animações finais dos 36 heróis, inimigos e chefes
  (etapas 2 e 5 do plano): hoje são modelos procedurais refinados (passe de
  arte acima); modelos feitos à mão no Studio ainda os substituem.
  O caminho para a arte está pronto: exportar do Studio como `.rbxmx` para
  `assets/models`, registrar autor e permissão no manifesto e o jogo passa a
  usar o modelo sozinho (ver `assets/models/README.md`).
- Áudio publicado (IDs), passes e produtos (IDs), grupo (`GroupId`).

### Pendente

- Arte final: exportar os modelos do Studio para `assets/models` (o caminho
  está pronto; faltam os modelos). Sugestão do plano: começar pela amostra
  Homem de Ferro, Hulk, Homem-Aranha, quatro inimigos e Lagarto.
- Áudio: importar os 25 WAVs de `assets/audio` na conta e preencher os IDs.
- Lugar AFK: publicar `Doomsday-Afk.rbxlx`, configurar `AfkPlaceId` e testar
  por 1 h sem interação no aplicativo (a renovação por teleporte a cada 15 min
  é uma hipótese; a API não garante).
- Soldados: conferência visual no Studio.
- Amostra visual da etapa 2 (Manhattan, Homem de Ferro, Hulk, Homem-Aranha,
  quatro inimigos, Lagarto) e sessão com três pessoas de fora.

## Histórico anterior


Este registro distingue código existente de aprovação para lançamento.

## Entrega desta revisão

- Expansão 2026.4: **36 heróis, 11 bases equipáveis, cinco baús por coleção**,
  15 variantes de inimigos por mapa, renda de Energia e melhorias de base
  durante a partida. Canhões, barricadas regenerativas e soldados funcionam
  no servidor. Detalhes e valores em [BASES.md](BASES.md).
- HUDs com identidade coral/violeta/dourado/verde/rosa, galeria clara,
  ilustrações de bases e comparação de melhorias. A seleção de base fica no
  inventário; a barra de vida abre a evolução durante a partida.

- Poses de ataque articuladas nos 24 heróis, com armas acompanhando as mãos,
  giro para o alvo e retorno à pose sem acumular deslocamento. Projéteis saem
  das armas/mãos; voadores e ataques agora compartilham a mesma altura visual.
- Pedestais de combate circulares, iluminação mais legível em Manhattan,
  HYDRA e Latvéria e inimigos com silhuetas arredondadas/material de tecido.
- Avisos de chefes acompanham seu movimento, usam o alcance do poder e têm
  contagem regressiva. O aviso de descarga desaparece ao quebrar o escudo.
- Escudo, marcação, lentidão e outros estados aparecem nos inimigos. Um limite
  de barras comuns evita cobrir toda a horda; chefes mantêm suas barras.
- Duas trilhas e 11 efeitos originais em `assets/audio`, gerador reproduzível,
  transições suaves e controles independentes de música/efeitos. São arquivos
  prontos para importação; a versão distribuída ainda precisa dos IDs de áudio.
- Gerador de publicação com template, validação de IDs, hashes e relatório.
  Instruções em [DEPLOYMENT.md](DEPLOYMENT.md); nenhum lugar foi publicado.
- Os arquivos XML e projetos Rojo agora declaram o chat moderno do Roblox.
  A janela fica afastada do cabeçalho de saldo e navegação, sem substituir
  o serviço de chat por mensagens personalizadas sem filtragem.

- Exposições e estátuas de heróis removidas do lobby, incluindo a vitrine
  premium. Os 24 personagens, seus retratos e habilidades foram preservados.
- Duas áreas verdes identificadas diante dos baús. O servidor detecta a
  entrada e abre a página correta uma vez; sair e voltar rearma a interação.
- Saldo e custo destacados; resumo por raridade; galeria de retratos com as
  chances atuais por herói, respeitando prioridade de novos e garantia.
- Confirmação mostra custo e saldo restante. Cancelamento não compra;
  requisições em andamento impedem outra confirmação no mesmo cliente.
- Resultado e compensação por repetido vêm do servidor. Política regional,
  saldo, sorteio e gravação continuam controlados pelo servidor.
- Lobby passou de aproximadamente 3.100 para 2.035 peças no teste de geração.
  Essa redução não é uma medição de FPS.

## Já implementado, ainda sujeito a teste de lançamento

36 heróis; 11 bases; evolução de conta e de habilidades; dez baús; inventário;
cinco mapas; Campanha/Ranqueado/Cartas com 50 ondas e Infinito; chefes;
recompensas; coleta; lojas; salvamento; placares e fluxo de reconexão.
Existir em código não significa que arte, balanceamento ou serviços online
estejam aprovados em produção.

## Dependências que ainda impedem declarar lançamento pronto

1. **Configuração da conta:** faltam 69 IDs no template: experiência, dois
   lugares, quatro passes, três pacotes de Ouro, 34 heróis e 25 áudios.
   É necessário criar/importar esses itens na conta proprietária e preencher
   `deployment/local.json`. O gerador está pronto para aplicá-los aos lugares.
2. **Fluxo em aparelhos:** testar movimentação/toque, joystick, rolagem,
   área segura, abertura dos baús, evolução e formação de equipe em celular
   real; medir FPS e memória nos mapas mais pesados e grupos de quatro.
3. **Balanceamento com jogadores:** medir duração, dificuldade por grupo,
   tempo para recrutar e utilidade das composições. A simulação automática
   desta revisão venceu Manhattan em cerca de 42 minutos sem antecipar
   preparações; isso ainda exige avaliação humana do ritmo.
4. **Serviços online:** validar preços, recibos, falhas de gravação, entrega,
   teleporte reservado, grupos de quatro,
   reconexão, checkpoints e placares entre servidores reais. A persistência
   em Studio usa memória temporária por configuração.
5. **Preparação pública:** definir autorização dos assets e uso da marca,
   revisar apresentação/classificação da experiência e realizar beta fechado
   antes de liberar comercialmente.

## Validação desta revisão

Cena de estresse no renderer do Studio: 24 heróis disparando, 180 inimigos,
cinco mapas. Após carregamento, amostras de dez segundos ficaram próximas
de 60 FPS, com p95 de aproximadamente 18 ms nesta máquina. A primeira amostra
inclui travamento de carregamento; esse resultado não certifica celular ou
quatro clientes conectados. A memória observada (~3,1 GB) inclui o Studio e
suas ferramentas; não representa memória de um aplicativo Roblox publicado.

A trilha original de batalha carregou e tocou na revisão local (`IsLoaded=true`,
`IsPlaying=true`, duração 34,29 s). Isso usou arquivo local de prévia, sem
confundir esse teste com disponibilidade do áudio na nuvem.

Simulações cooperativas completas em Manhattan: dupla venceu 50 ondas em
40,9 min, trio venceu em 39,5 min e quarteto perdeu após 49 ondas em 41,1 min.
São decisões de um bot com a mesma composição de referência, não limites
demonstrados de jogadores humanos. Não houve ajuste de poderes baseado apenas
nessa taxa de vitória. Contas, recompensas individuais e limites foram conferidos.

`python tools/test.py` aprovado: compilação, regras, serviço de perfis,
grupos, elevadores, contratos, mapas, cliente, servidor e simulações.
Os testes novos cobrem entrada, permanência, troca de baú, tolerância nas
bordas, saída/reentrada, dois jogadores e remoção de personagem/conexão;
também cobrem confirmar e cancelar compras no HUD em seis resoluções.

As verificações com dublês não substituem compras, teleporte e aparelhos.
`tools/studio_shop_entry_review.luau` permite conferir a entrada real numa
cópia descartável de Studio, sem compras nem concessão de moeda.

Conferência realizada no Studio: o personagem foi colocado na área verde
real pelo servidor; o cliente registrou `chests / rare`, sem envio de compra.
Não houve texto excedendo seus limites na janela medida. Captura local:
`test-results/shop-entry.png`. Compras reais e toque em aparelho continuam
pendentes conforme os itens acima.
