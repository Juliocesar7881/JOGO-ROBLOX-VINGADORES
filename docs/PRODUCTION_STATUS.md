# Situação de produção — combate, loja e pacote de publicação

Este registro distingue código existente de aprovação para lançamento.

## Entrega desta revisão

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

24 heróis; evolução de conta e de habilidades; dois baús; inventário;
cinco mapas; Campanha/Ranqueado/Cartas com 50 ondas e Infinito; chefes;
recompensas; coleta; lojas; salvamento; placares e fluxo de reconexão.
Existir em código não significa que arte, balanceamento ou serviços online
estejam aprovados em produção.

## Dependências que ainda impedem declarar lançamento pronto

1. **Configuração da conta:** faltam 45 IDs no template: experiência, dois
   lugares, quatro passes, três pacotes de Ouro, 22 heróis e 13 áudios.
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
