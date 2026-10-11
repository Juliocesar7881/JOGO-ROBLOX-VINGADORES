# Arte de interface ilustrada

Produzida em 11/10/2026 com a skill `imagegen` e a ferramenta nativa
`image_gen`. Referências: propostas próprias em
`output/imagegen/huds-pc-2026-10-10/`, especialmente 04-squad, 07-chests e
31-results. Os arquivos de referência não são imagens de gameplay.

Os PNGs nesta pasta são os originais selecionados. `button-v1.png` e
`card-v1.png` preservam as primeiras versões, rejeitadas na inspeção por
escurecerem os botões e terem textura excessiva. Os arquivos `roblox/md_*`
são as entregas reduzidas por `python tools/prepare_ui_art.py`. O script
somente redimensiona: não desenha nem recria a arte.

`manifest.json` registra prompts resumidos, arquivo gerado, resoluções,
SHA256 e IDs importados na conta do projeto pelo Gerenciador de ativos do
place 97132875544830. Os IDs usados pelo jogo ficam em `Config.UiArt`.

| Imagem | Uso real | Recorte |
|---|---|---|
| window | Janelas, avisos e painel AFK | SliceCenter (110,100)-(914,583), escala 0,26 |
| button | Botões, abas, fitas e menu lateral | Gutter removido (0,36), tamanho 1024x241; slice (110,70)-(914,171) |
| card | Cartas, retratos e vitrines | SliceCenter (90,90)-(934,934), escala 0,17; cor aplicada em runtime |
| icons | Navegação e recursos da interface | Atlas 4x4, células 256x256 |
| chests | Seleção, compra e baú recebido | Atlas 3x2, células 341x341 |
| observatory | Inicialização, conexão e farms AFK | Crop proporcional; sombreado separado sob texto |

Ordem dos ícones, da esquerda para a direita por linha: capacete, base,
evolução, moedas; presente, missão, opções, troféu; estrela XP, vórtice,
dano, mira; baú, casa, jogar, escudo. Ordem dos baús: madeira, raro, épico;
lendário, cósmico, recursos. Os baús de base compartilham a linguagem da
raridade, com suprimentos próprios em verde.

Nenhum texto, preço, número ou botão funcional está gravado nas imagens.
São elementos passivos sobre os controles nativos. Português, inglês,
seleção, bloqueios e valores continuam dinâmicos. Retratos continuam
mostrando os modelos reais do jogo; não substituímos heróis jogáveis por
desenhos inventados na proposta.

`IllustratedSkin` compartilha seis URLs entre todas as cópias. Faz o
carregamento assíncrono uma vez por URL e mantém os desenhos nativos até a
confirmação. Não há espera de rede no carregamento inicial nem consulta por
quadro. `tests/test_ui_art.py` verifica hashes, resoluções, transparência,
recortes e concordância com Config; o roteiro de cliente testa também a
conclusão assíncrona sem evento IsLoaded, texto vivo e ausência de dupla
moldura.
