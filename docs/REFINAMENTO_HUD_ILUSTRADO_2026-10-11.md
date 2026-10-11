# HUDs ilustrados — 11/10/2026

Pedido: aproximar os HUDs funcionais das 38 propostas em
`output/imagegen/huds-pc-2026-10-10/`, usando arte raster integrada. O dono
autorizou trabalho autônomo, uso do PC e publicação no lugar da equipe.

## Diagnóstico de maior impacto

| Evidência anterior | Problema e efeito | Correção | Verificação |
|---|---|---|---|
| Propostas 04/07/31 e capturas `test-results/hud-reference/pc` | Molduras lisas e ícones geométricos não reproduzem metal, tinta e volume da proposta; todas as telas parecem genéricas. | Texturas próprias de moldura, botão e carta, ícones ilustrados. Textos e alvos continuam nativos. | Comparação no mesmo enquadramento, imagens carregadas, cliques e seis layouts. |
| Tela de invocação e recompensas | O baú desenhado em poucas formas tem pouco destaque e diferenciação de material. | Seis baús ilustrados, com recorte por raridade, integrados aos seletores e recompensas. | Conferir seis recortes, resultado real e ausência de segunda animação. |
| Carregamento e Ouro/XP AFK de M27 | O observatório nativo continua parecido com um esquema de formas simples. | Pintura original de ilha/observatório atrás dos contadores reais. | Carregamento sem depender da imagem; AFK com 3D desligado e estado salvo vindo do servidor. |

## Produção

Arte produzida pela skill imagegen, ferramenta nativa `image_gen`.
Fontes e PNGs de entrega em `assets/ui/illustrated/`. Nenhum texto foi gravado
nas imagens. `tools/prepare_ui_art.py` apenas reduz resolução para entrega no
Roblox; preserva os originais e a divisibilidade dos atlas.

Importação feita pelo Gerenciador de ativos no place **97132875544830**.
IDs consumidos pelo jogo estão em `Config.UiArt`. Importações provisórias
foram substituídas pelos seis arquivos `md_*` selecionados, de resolução
controlada, e seus IDs antigos não são usados no código.

## Matriz de aceite

| Área | Estado | Evidência |
|---|---|---|
| Moldura, botões, cartas e navegação | Verificado no jogo | 41 cenas no PC; retratos sem segunda moldura, seleção colorida, símbolos e legendas reais |
| Baús e recompensas | Verificado no jogo | Seis recortes; baú grátis 0 para 1 e compra com Ouro 1 para 2, confirmação, roleta e recibo por cliques |
| Inicialização e AFK | Verificado no jogo | Pintura carregada no Studio; Economia, Mostrar jogo e Voltar ao lobby por cliques reais |
| Comparação de todas as telas | Verificado no jogo | 41 capturas PC, 41 horizontal PT e 41 vertical EN; galeria antes/proposta/depois no Desktop |
| Interação, idioma e recursos | Verificado no jogo | Suíte completa verde, navegação real, seis formatos automáticos; sem espera de rede para desenhar |
| Desempenho | Verificado no jogo | Cinco torres e 114 inimigos visíveis: 60 FPS, p95 18,10 ms na RTX 4060 Ti |
| Sincronização e publicação oficial | Verificado no jogo | Seis módulos sincronizados seletivamente, 40 fontes iguais ao repo; `PublishSuccessful` no mesmo place |

## O que a inspeção realmente corrigiu

As primeiras imagens de botão eram escuras e o primeiro fundo de carta
competia com o personagem. Foram produzidas versões mais claras e com
centro limpo. Os retratos reutilizam o fundo da carta e a cor do herói.
A invocação reserva espaço para quantidade, preço e confirmação antes de
dimensionar a ilustração, inclusive em janelas de laptop mais baixas.

No Studio, uma imagem oculta antes de carregar podia nunca solicitar sua
textura. Também houve conclusão em cache sem notificação de `IsLoaded`.
As imagens agora continuam desenháveis durante o download, com arte nativa
visível por baixo; uma conclusão assíncrona por URL atualiza todas as cópias.
Os sinais são desconectados quando os elementos são destruídos.

A revisão encontrou a legenda do botão curto “Pular a caminhada” coberta
pela placa opaca. Todo botão com texto agora mantém uma legenda nativa acima
da arte; há regressão específica de 24 px. O símbolo de troféu/XP da árvore
foi separado do ícone de navegação da evolução; a mira usa o atlas correto.
Esses quatro casos foram novamente fotografados nos três formatos.

## Testes e evidências

`python tools/test.py` terminou com código **0**, em 66,66 segundos na rodada
antes do commit. Inclui compilação, 632.736
asserções de regras/economia, 6.937 verificações de layout, 6.137 do mundo,
2.968 do servidor e 1.577 da simulação; seis execuções do cliente entre
1.057 e 1.063 verificações cada. Nenhum teste foi enfraquecido.
`tests/test_ui_art.py` verifica hashes, IDs, alpha, resolução máxima de
1.024 px e 22 células dos atlas. O cliente cobre carregamento lento,
fallback, conclusão sem evento, texto vivo, tintas e dupla moldura.

Revisão no Studio: 205 capturas de base (41 PC; cada revisão de celular
também produz uma captura PC), mais 20 após o ajuste de legendas e símbolos.
Todos os passes terminaram com código 0, sem erro de script ou estouro de
texto detectado. O diretório final retém 123 capturas dos formatos desejados.

Cliques reais abriram Heróis, Base, Evolução, Missões e Prêmios. O baú grátis
foi entregue pelo servidor temporário do Studio e passou pela roleta até o
recibo. Na área AFK, os botões de Economia, Mostrar jogo e retorno ao lobby
funcionaram com a pintura ativa. A loja física abriu por proximidade; a
compra de Suprimentos no perfil temporário debitou 400 Ouro (976 para 576),
elevou baús de 1 para 2 e percorreu confirmação, roleta e recibo. O Ouro
veio de campanha abreviada pelos comandos de revisão, com participação
aceita pelo servidor. Nenhuma compra com Robux foi feita.

Carga real no Studio/Windows, GPU NVIDIA GeForce RTX 4060 Ti: modo Cartas,
Complexo Gama, cinco heróis. Dez segundos de base: 600 quadros, 60,0 FPS,
p95 17,99 ms, memória total do Studio 4.010,3 MB. Após `server:crowd 80`,
114 inimigos visíveis: 600 quadros, 60,0 FPS, p95 18,10 ms, 4.035,3 MB e
346 de dano registrado. São duas amostras curtas; esse valor de memória
inclui o editor e não demonstra estabilidade prolongada. Três quadros
consecutivos foram preservados em `test-results/illustrated/live/`.

Evidência local:

- `test-results/illustrated-fullsuite-precommit-final.txt` e
  `test-results/illustrated-suite-result.json` — suíte completa e código de saída.
- `test-results/illustrated/{pc,phone-pt,portrait-en}` — telas e relatórios.
- `test-results/illustrated/live/flow.json` — estados antes/depois e cliques.
- `test-results/illustrated/live/purchase-flow.json` — compra com Ouro temporário.
- `test-results/illustrated-sources-final.txt` — 40 fontes iguais ao repo,
  com prefixo de papel do servidor anterior preservado.
- `C:/Users/loops/Desktop/Multiverse_HUDs_Ilustrados_2026-10-11/INDICE.html`
  — galeria comparativa, capturas integrais e assets.

## Entrega no projeto da equipe

Código e assets no `main`: **a17f8a0**, enviado ao origin. As seis fontes
modificadas foram sincronizadas com destino obrigatório **97132875544830**.
As 40 fontes do lugar foram comparadas ao repositório antes e depois; o
prefixo de papel do servidor, anterior à entrega, foi preservado. Nenhum
script do parceiro foi substituído por uma versão diferente. Preview do
lobby reconstruído com 4.455 peças, abaixo do teto de 4.500.

Publicado nesse mesmo lugar em **11/10/2026, às 02:07:16 local
(05:07:16 UTC)**. Evidência no log da janela oficial:
`2026-10-11T05:07:16.735Z ... Go to PublishSuccessful`.
Registro completo em `test-results/illustrated-publication.json`.
O place foi novamente conferido em modo de edição após a publicação.
Nenhuma configuração de público, preço ou colaboração foi alterada.
Antes do commit deste registro, a suíte completa terminou novamente com
código 0, em 57,67 segundos (`test-results/illustrated-suite-postpublish.json`).

## Avaliação e limites

Leitura 4/5, acabamento de interface 4/5, consistência 4/5, objetivo 4/5,
recompensa 4/5. A melhoria visível vem dos materiais, silhuetas de ícones,
baús distintos e hierarquia, não de adicionar brilho. “Uau” e combate
continuam 3/5: esta entrega troca a arte da interface; anatomia e peso dos
modelos continuam em M22.7/M22.9. Não declarar o jogo inteiro profissional
nem equivalência literal aos personagens pintados nas propostas.

Não altera preços, sorteios, inventário, progressão, pagamentos ou autoridade
do servidor. Celular físico, quatro jogadores e compras reais continuam
dependências do checklist de lançamento; a revisão emulada não os substitui.
Memória em sessão prolongada, reconexão e DataStore publicado não foram
certificados por este playtest. As telas de combate da galeria são fixtures;
a carga real tem evidência separada. A preferência visual final é do jogador.
