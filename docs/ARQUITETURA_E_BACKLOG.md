# Arquitetura de produção e trabalhos pendentes

Revisão do código 2026.4 e dos registros de testes locais. Este documento é
um plano de trabalho; não certifica lançamento nem representa alterações já
implementadas. A inspeção desta revisão é de código/documentação; as imagens
e medições do Studio referidas são da revisão anterior.

## Diagnóstico

O jogo tem uma versão funcional ampla: 36 heróis, 11 bases, cinco mapas,
cinco chefes, dez baús, progressão e serviços de conta. O principal trabalho
agora é transformar esses sistemas em uma experiência consistente, legível
e visualmente marcante. Quantidade de conteúdo e quantidade de testes não
medem acabamento artístico ou facilidade de uso por uma criança.

Evidências que orientam a prioridade:

1. **Arte:** `WorldBuilder` constrói heróis, bases e cenários com peças e
   materiais nativos. Há poses e efeitos programados, mas não há uma coleção
   de animações publicadas e texturas próprias aplicada aos personagens.
2. **Bases:** `UpdateBase` usa um prédio comum e acessórios por categoria.
   Duas bases da mesma categoria ainda não têm a identidade arquitetônica
   que seus nomes sugerem. A barricada está desenhada no módulo, mas o dano
   ocorre nos últimos 15 studs das rotas. O canhão mede alcance a partir do
   núcleo, enquanto o disparo visual sai do prédio lateral.
3. **Renda:** Oficina Stark rende 139 no nível 4 e 171 no nível 5. Pagar 3.200
   por +32 por onda exige **100 ondas para recuperar o investimento apenas
   pela renda**. O bônus de vida também tem valor, mas isso evidencia a
   necessidade de recalibrar o propósito econômico da melhoria numa partida
   de 50 ondas.
4. **Inimigos:** as 15 variantes novas copiam atributos e recompensas de três
   famílias. São variedade visual por mapa, não 15 mecânicas diferentes.
5. **Progressão:** os marcos de coleção ainda terminam em 24 heróis, embora
   existam 36; a coleção de bases precisa de objetivos próprios. A sequência
   de login reinicia após ultrapassar a tolerância, divergindo da premissa
   inicial de não perder a sequência por ausência.
6. **Manutenção:** aproximadamente 2.155 linhas no controlador do cliente,
   2.577 em `WorldBuilder`, 1.219 em `MatchService` e 963 em `PlayerService`.
   O problema não é o tamanho sozinho: várias responsabilidades diferentes
   precisam ser alteradas no mesmo arquivo para acrescentar uma função.
7. **Lançamento:** o template versionado continua com 57 IDs zerados. Há
   testes locais, mas compras, teleporte, dados e toque em aparelhos reais
   ainda precisam de aceitação publicada.

## Áreas de produção

Prioridades: **P0** resolve bloqueios de publicação ou decisões que afetam
todo o projeto; **P1** define a qualidade da primeira versão pública;
**P2** amplia uma experiência já aprovada. As sugestões P2 não são requisitos
automaticamente adicionados ao escopo.

| Área | Base existente | Trabalho restante | Critério para considerar pronta | Prioridade |
|---|---|---|---|---|
| Direção de arte | Paleta, materiais nativos, linguagem de quadrinhos | Guia de cores, luz, proporções, texturas, raridades e intensidade de brilho; cena visual de referência | Herói, base, chão, inimigo e HUD juntos parecem pertencer ao mesmo jogo e continuam legíveis no celular | P1 |
| Heróis | 36 personagens, habilidades e especializações | Silhuetas, rostos, armas, texturas próprias, poses de espera, ataque e habilidade; transições; aparência por melhoria e despertar | Cada herói é reconhecível na câmera real; ataque corresponde à arma; melhoria aparece no modelo | P1 |
| Habilidades ativas | Líder do slot 1, cinco ranks, efeitos e recargas | Prévia do poder, área de efeito clara, feedback de alvo inválido, animação e som específicos, comparação de ranks | Jogador entende de quem é o poder, onde age e por que está indisponível | P1 |
| Bases e fazendas | 11 bases, cinco níveis, renda, vida, canhão, barreira e soldados | Construções próprias; vegetação/máquinas animadas; recibo de renda por onda; barreira posicionada no ponto de interceptação, estado de dano/regeneração; canhão orientado ao alvo; saída dos soldados pelo quartel | Modelo, alcance e impacto representam a mesma regra; função de cada base é percebida sem ler um parágrafo | P1 |
| Inimigos | Oito famílias e 15 variantes visuais | Caminhada, impacto e derrota por família; sinais para blindagem/camuflagem; decidir quais variantes merecem comportamento exclusivo | Criança consegue identificar a ameaça e a resposta antes de perder a base | P1 |
| Chefes | Cinco chefes, fases e avisos | Entrada curta, identidade de ataques, animações de preparação/impacto/derrota, áudio, arena legível e recompensas apresentadas | Cada chefe exige uma decisão diferente; avisos permanecem visíveis no meio da horda | P1 |
| Mapas de combate | Cinco mapas com rotas diferentes | Texturas próprias de solo/fachada, marcos visuais, iluminação consistente, limites de construção claros; revisar espaço das quatro bases, oclusão, câmera e decoração sobre a rota | A rota é legível de qualquer posição útil; bases/torres não se sobrepõem visualmente; cenário não esconde ameaças | P1 |
| Lobby | Floresta, praça, quatro portais e pisos de loja | Composição com ponto central memorável, trilhas pela floresta, placas curtas, ambiente sonoro e movimento discreto; pequenas áreas opcionais de exploração | Novo jogador encontra jogar, equipar e evoluir; consegue descrever um lugar marcante depois da sessão | P1; exploração extra P2 |
| Baús | Cinco tiers para cada coleção; chances, garantia, repetidos e confirmação | Arte própria por tier, comparação de preços/conteúdo, abertura e áudio distintos, acesso fácil ao item ganho, sinais claros de bloqueio | Conteúdo, chance, custo e saldo são compreendidos antes da compra; cancelar nunca gasta | P1 |
| Inventário e formação | Cinco slots, líder destacado, uma base ativa | Pesquisa, filtros por função/raridade, ordenação, favoritos, comparação de heróis, base ao lado da equipe, troca de líder mais direta | Montar uma formação e encontrar uma base exige poucos passos, sem busca em lista longa | P1 |
| HUDs | Layout responsivo, cores por seção, feedback e janelas | Revisão tela a tela com dados reais: hierarquia, densidade, ícones, rolagem, estados vazios, compra pendente, erros, reconexão, orientação do celular e telas pequenas | Sem sobreposição/cortes; ação principal evidente; câmera e rota continuam utilizáveis | P1 |
| Árvore e maestria | Um ponto por nível, ramos, reset, evolução de habilidades | Nós mais compactos e ilustrados, visão do caminho, resumo dos bônus finais, limites e próximo efeito; despertar visível; marcos para 36 heróis e bases | Jogador explica o que muda ao gastar o ponto; não confunde talento, maestria, rank do poder e nível da torre | P1 |
| Ondas e modos | Campanha/Ranqueado/Cartas com 50 ondas, Infinito; chefes a cada dez | Curva de dificuldade/tempo, combinações de ondas, transições; sinergias de cartas com bases sem opções inúteis; pausas confortáveis | Cada modo tem identidade de decisão; duração e picos de dificuldade aprovados em partidas humanas | P1 |
| Ranqueado | Faixas por ondas, placares por contexto, temporadas e versão | Explicar o significado do rank, melhorar comparação pessoal, histórico e transição de temporada; decidir se haverá outro modelo competitivo no futuro | Resultado corresponde ao placar e à regra exibida; progressão da conta é transparente | P1; outra forma de rank P2 |
| Economia | Ouro persistente, Energia por partida, renda, baús e compensações | Retorno de investimento das bases, tempo para desbloquear, compra de herói versus habilidade, duplicatas, diferenças por grupo e raridade, oferta gratuita após tutorial | Existem escolhas economicamente úteis no começo e no fim; nenhuma composição depende de gastar Robux para funcionar | P1 |
| Coleta e feedback | Moedas pessoais, agrupamento, drone e entrega no fim | Pilhas de valores legíveis, movimento de coleta, som sem repetição excessiva, retorno visual da renda de base separado do Ouro | Jogador entende qual recurso ganhou e não sente obrigação de abandonar a defesa para correr atrás de moedas | P1 |
| Áudio | Duas trilhas e 11 efeitos originais; mix e controles | Upload/configuração; sons de armas e bases; ambiente por mapa; avisos distintos; limite de sons simultâneos e volumes | Ataques e avisos se distinguem sem saturação; as preferências são respeitadas | P1 |
| Tutorial | Oito ondas, avisos e fluxo básico | Ensinar baú, líder, base, evolução por Energia e primeiro ponto; instruções contextuais; retorno ao lobby com objetivo claro | Uma criança nova completa o ciclo sem uma pessoa explicando os menus | P1 |
| Acessibilidade e localização | Português/inglês, efeitos reduzidos e controles de som | Revisar textos no mundo, inclusive nomes de bases hoje escritos em português; ícone + texto, contraste, tamanhos e leitura em tela estreita; ausência sem punição de sequência | Trocar idioma não deixa placas essenciais para trás; sinais não dependem apenas de cor, flash ou som | P1 |
| Cooperação e serviços | Grupos, teleporte, reconexão, perfis e recibos | Testes publicados com quatro contas; contribuição de suporte/fazenda; chegada tardia, queda de rede, falha de dados, servidor encerrando | Reconectar não duplica moeda/base; falha de gravação não perde compras; suporte recebe crédito adequado | P0 para dados/compras; P1 para UX |
| Desempenho | Simulação central, pools, limite de inimigos e efeitos reduzidos | Medir aparelho real, custo dos retratos, memória por mapa, tráfego, soldados e quatro bases; otimizar conforme perfil de execução | Metas medidas em aparelhos definidos, com pior onda e sessão prolongada | P0 para beta aberto |
| Operação e publicação | Scripts de build/release, testes e eventos analíticos | IDs, autorização dos assets/marca, beta; painéis de métricas, falhas e retorno de versão; eventos de escolha/evolução de bases | Publicação reproduzível, compras confirmadas e falhas monitoradas | P0 |

## Questões técnicas específicas para a próxima implementação

- `Match:_validBuild` impede sobrepor rota e torres, mas não verifica o volume
  dos novos módulos de base. Os módulos também usam deslocamentos fixos em
  todos os mapas. Criar áreas reservadas por mapa e validar cliente/servidor
  com a mesma geometria. A necessidade de proteção está confirmada no código;
  os pontos de sobreposição devem ser reproduzidos por mapa antes da correção.
- Unificar a origem do alcance do canhão com seu desenho ou desenhar claramente
  a área protegida ao redor do núcleo. O usuário não deve precisar conhecer
  a diferença entre posição lógica e visual.
- Representar a interceptação da barricada em cada rota, com vida e regeneração
  visíveis. Hoje o visual lateral não explica onde ela troca vida por dano.
- Revisar critérios de contribuição: uma base econômica sozinha não marca
  contribuição. Isso pode ser intencional contra inatividade, mas precisa ser
  ensinado e testado com funções de suporte no grupo.
- Criar recuperação por falha de analytics: atualmente uma falha desativa o
  serviço analítico naquela instância. Separar erro temporário de configuração
  inválida e incluir a base equipada nas medições de composição.
- Rever caminhos de aquisição para contas com baús bloqueados: heróis têm
  compra direta por Robux, mas bases não têm uma alternativa determinística
  definida. Projetar um caminho de jogo que preserve acesso às bases.
- Consolidar documentação: números antigos de 24 heróis, dois baús e amostras
  de balanceamento permanecem em seções históricas. Marcar revisão/data das
  métricas e gerar índices de conteúdo a partir do catálogo.

## Organização técnica proposta

Manter três camadas: **dados/regras compartilhados**, **servidor que decide**
e **cliente que apresenta**. Compras, sorteios, dano e recompensas continuam
no servidor. A divisão abaixo é incremental, feita quando a área for trabalhada;
não é motivo para reescrever tudo antes de melhorar o visual.

```text
src/shared/
  catalog/          Heroes, Abilities, Bases, Chests, Enemies, Maps, Modes
  rules/            Combat, Progression, Economy, Recruitment
  Catalog.luau      fachada de compatibilidade para o catálogo atual
  Rules.luau        fachada de compatibilidade para regras atuais

src/server/
  MatchService     ciclo e fases da partida
  combat/          Towers, Enemies, Abilities, BaseDefense, Soldiers
  world/           LobbyBuilder, MapBuilders, HeroModels, BaseModels
  PlayerService    dono da sessão e da transação de perfil
  progression/     transformação de heróis, talentos e coleção de bases
  commerce/        catálogo de compra, sorteio e recibos
  services/        grupos, reconexão, placares e analytics

src/client/
  init.client      liga controladores, rede e estado
  screens/         Inventory, Bases, Chests, Talents, Shop, Results
  hud/             LobbyHUD, MatchHUD, TowerPanel, BaseUpgradePanel
  visuals/         Heroes, Enemies, BaseEffects, Soldiers, Coins
  audio/           música, ambiente e efeitos
  UI.luau          componentes, tema e regras de layout

assets/
  audio/           originais e registro de publicação
  art/             texturas, ícones e referências aprovadas
  models/          fontes dos modelos e animações

tests/             regras, transações, integração, cenários e aceite visual
```

Ao extrair módulos econômicos, `PlayerService` permanece o único dono da
transação: abrir um baú continua debitando Ouro e concedendo o item na mesma
gravação. Ao extrair combate, `MatchService` mantém uma fonte de tempo e
estado; nada de criar um loop independente por herói ou soldado.

## Ordem recomendada de execução

1. **Referência visual jogável:** Manhattan, Homem de Ferro, um inimigo,
   uma base, um baú e HUD juntos. Aprovar materiais, animação e legibilidade.
2. **Bases e economia:** retorno do investimento, áreas de construção,
   barricada, canhão e soldados coerentes com o visual.
3. **Fluxo de aprendizado:** tutorial, inventário, líder, base, árvore e
   compra; testar com quem nunca viu o projeto.
4. **Aplicar o padrão ao conteúdo:** todos os heróis, mapas e chefes, com
   revisão de som e performance por lote.
5. **Beta publicado:** conta, dados, compras, teleporte, quatro jogadores,
   aparelhos reais e métricas. Corrigir resultados antes de abrir o acesso.

Cada entrega deve vir com evidência da área alterada: captura ou vídeo em
Studio para arte/UX, teste de regra para economia, recibo para concessões e
medição em aparelho para desempenho. Não usar uma suíte verde como substituto
para a aprovação visual.
