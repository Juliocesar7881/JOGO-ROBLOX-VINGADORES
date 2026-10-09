# Base, fundo da árvore e sons da roleta — 08/10/2026

Pedido do dono: colocar Base no menu principal, separar a equipe da seleção
de base, mostrar o cenário desfocado atrás dos talentos e usar a referência
de roleta enviada, com um final diferente para cada raridade.

| Entrega | Estado | Verificação |
|---|---|---|
| Base junto aos botões principais | Verificado no Studio | Seis botões na coluna do PC e no dock do celular; só Opções no canto superior |
| Heróis sem cartão/atalho de base | Verificado no Studio | Cinco slots usam toda a largura, sem cartão da base nem espaço vazio extra |
| Bases sem abas para Heróis | Verificado no Studio | Abre diretamente na base ativa; posse, equipamento e melhorias preservados |
| Árvore sem fundo preto | Verificado no Studio | Painel e mapa transparentes; BlurEffect existente e texto com contorno |
| Clique por passagem de item | Verificado no Studio | Independente da coleta, região curta aplicada no Sound real; sem rajada ao pular ou atrasar um quadro |
| Final por raridade | Verificado no Studio | Cinco assinaturas exercitadas no cliente real com gravações carregadas; um final ao parar e nenhum segundo som no recibo |
| MP3 exato e gravações finais dedicadas | Bloqueado por envio na conta | Sete WAVs preparados; IDs ainda zero, conforme o manifesto |

## Arquivos e assets

- `UI.luau` e `init.client.luau`: dock com Base, geometria com seis botões
  e seleção da aba correta; o botão antigo no topo foi removido.
- `Panels.luau`: equipe sem base, tela de Bases independente e árvore
  transparente sobre o blur. Arraste, zoom e regras de pontos preservados.
- `Audio.luau` e `Celebrate.luau`: vozes próprias da roleta, confirmação
  por raridade, cancelamento de camadas ao mudar de cena e substituição
  integral por gravações dedicadas quando os IDs estiverem disponíveis.
- `Config.luau` e `deployment/template.json`: sete chaves de áudio, todas
  desativadas até o upload real; os IDs existentes continuam iguais.
- `tools/generate_summon_audio.py` e `assets/audio/summon/`: MP3 fornecido
  pelo dono, abertura/clique recortados e cinco finais sintetizados, com
  hashes e origem separados no manifesto. Não são uploads já publicados.

## Testes e evidências

`python tools/test.py`: saída 0. 632.736 asserções de regras, 6.937
checagens de layout, seis roteiros completos do cliente com 959–962
checagens por formato; compilação, áudio, integridade dos assets, servidor,
simulação e geração dos quatro places aprovados.

Os testes cobrem a presença da Base no dock, ausência dos antigos atalhos,
largura liberada na equipe, transparência da árvore, blur, clique rápido,
cinco finais distintos, limite de oito vozes, mute, cancelamento e
substituição de fallback por um upload. Os testes do fluxo de recompensa
continuam cobrindo baús comprados e recebidos, sem segunda abertura.

Capturas locais:

- `test-results/base-tree-reel/pc/`: lobby, equipe, bases, talentos,
  roleta e recibos. O fundo preto saiu e a Base aparece na esquerda.
- `test-results/base-tree-reel/horizontal/`: mesmas telas em 667×375.
- `test-results/base-tree-reel/vertical/`: lobby, equipe, bases e
  talentos em 375×667. A árvore continua navegável; conteúdo fora da área
  visível é alcançado por arraste, sem encolher todos os hexágonos.
- `test-results/base-tree-reel/en/`: lobby, equipe, bases, talentos e
  roleta em inglês, no formato horizontal.

Não houve `DOOM_REVIEW_OVERFLOW` nessas passagens. As dimensões de celular
são fixtures no Studio, não testes em um aparelho físico. A referência
exata ainda depende da conta; não afirmar que ela já toca no Roblox.

No cliente real do Studio, seis fontes foram carregadas por
`ContentProvider:PreloadAsync`: click, open e quatro famílias de ataque.
O `Sound` da roleta confirmou a região de 65 ms. As cinco assinaturas foram
exercitadas, e a pasta temporária da conferência foi removida ao final.
A conferência inicial teve uma igualdade exata de ponto flutuante recusada;
repetida com tolerância de 10 µs, confirmou 0,0649999976 s, conforme o valor
representado pelo Roblox. Isso não exigiu mudar o código do jogo.
Este teste confirma carregamento e execução; avaliação auditiva pelo jogador
e teste em celular físico continuam pendentes.

## Próxima ação necessária para o áudio exato

Enviar os sete WAVs, responder às declarações aplicáveis na conta do dono,
permitir uso na experiência 10768165352 e atualizar os IDs de `Config.Audio`.
Os dois recortes têm origem no arquivo fornecido; não declarar que foram
sintetizados pelo projeto. Os cinco finais são sínteses originais.
Instruções e lista dos arquivos: `assets/audio/summon/README.md`.

O fallback atual já oferece cliques e finais por raridade. A gravação
dedicada substituirá cada som inteiro, sem sobrepor o final antigo.

Código **86fb6bc** enviado ao `main`, com suíte completa verde antes do
commit. Seis fontes finais conferidas no Studio e sincronizadas
seletivamente. Lobby de edição refeito com 4.455 peças, abaixo do teto.
Publicado no mesmo place **97132875544830** em **08/10/2026 às 23:44:17
local (09/10/2026 às 02:44:17 UTC)**, com `Go to PublishSuccessful`
confirmado no log. Studio em modo de edição; acesso e colaboradores
preservados. Os uploads dedicados continuam pendentes.
