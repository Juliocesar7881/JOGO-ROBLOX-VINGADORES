# Artes do Evento Jurássico — 18/10/2026

Entrega aplicada no universo `10768165352` e publicada no place oficial
`97132875544830` às **10:42:14 de 18/10/2026** (13:42:14 UTC).
O Studio confirmou `PublishSuccessful` e ficou em modo de edição.

## Artes e identidade

Cinco imagens geradas com o **image_gen integrado**, usando capturas dos
modelos atuais e do lobby. O conjunto preserva a armadura branca/cobalto
com reator ciano, ombreiras em domo, Capitão teal/dourado e herói do trovão
prata/navy. Flávio Hipotético aparece de terno azul e gravata amarela,
montado no T-Rex marrom com lenço verde. O lança-chamas fica com o cavaleiro.

| Uso | Arquivo | Entrega |
| --- | --- | --- |
| Ícone | `icone.png` | 512×512, sem texto, Flávio e T-Rex em primeiro plano |
| Miniatura do evento | `thumbnail-event.jpg` | 1920×1080, nome do herói e defesa da rota |
| Miniatura da equipe | `thumbnail-squad.jpg` | 1920×1080, Flávio e trio atual, sem texto |
| Carregamento/conexão/retorno | `launch_refuge_v3.png` | Fundo novo com a praça, globo e portais atuais |
| AFK/economia de energia | `afk_refuge_v3.png` | Fundo novo com os heróis e pavilhão atual; Ouro e XP |

Materiais promocionais em
[`assets/store/promo-2026-10-18/`](../assets/store/promo-2026-10-18/).
Fundos e versões de 1024×576 em
[`assets/ui/illustrated/`](../assets/ui/illustrated/).
Originais, prompts, correções, dimensões e hashes estão preservados.
As seis referências de geração foram arquivadas em `referencias/`, com
mapeamento para as capturas originais em `references.json`.

São ilustrações promocionais baseadas no jogo. Os fundos continuam sem
texto embutido: títulos, progresso, botões e valores são desenhados pelo
jogo e seguem o idioma do jogador.

## Creator Hub

Ícone salvo, relido na página e conferido visualmente pela CDN pública,
estado `Completed`. Duas miniaturas aprovadas na página de detalhes, com
textos de acessibilidade:

| Miniatura | Asset ID |
| --- | --- |
| Equipe | `116292789932511` |
| Evento | `71851013049409` |

As quatro miniaturas antigas foram removidas da página de detalhes após
a aprovação das substitutas. A Home usa uma lista separada: **somente as
duas novas estão ativas**, com personalização ligada, confirmado após
reabrir a página (`hub/home-roundtrip.png`). As antigas ficaram inativas
na Home, preservando seu histórico.

Descrição atualizada e relida em **EN/PT-BR/ES**, destacando o Evento
Jurássico, Flávio Hipotético, T-Rex, 44 heróis, seis mapas e cooperação para
até quatro jogadores. Chances do baú descritas conforme o catálogo atual.
Título `Multiverse Heroes: Doomsday Tower Defense` e idioma-fonte EN
preservados; demais opções da tela de configurações conferidas antes/depois.

O nome do personagem aparece naturalmente na primeira frase e no texto
de acessibilidade. A descrição apresenta conteúdo existente, sem acumular
palavras-chave ou prometer posições em buscas. A orientação adotada vem da
[documentação de descoberta](https://create.roblox.com/docs/discovery) e de
[miniaturas do Roblox](https://create.roblox.com/docs/production/publishing/thumbnails).
O desempenho em busca/recomendação precisa ser acompanhado com dados reais.

## Integração e verificação

- `Config.UiArt.launch = 100615646421098`.
- `Config.UiArt.afk = 102874803609554`.
- IDs e proprietário verificados no Studio após a importação.
- Config do Studio comparado com o repositório antes da alteração;
  sincronização seletiva somente de `src/shared/Config.luau`.
- `python tools/test.py`: **exit 0**, incluindo build dos quatro places.
- `python tests/test_ui_art.py`: **PASS**, oito texturas, hashes, IDs e atlas.
- Revisão PT no PC e 667×375: `startup`, `loading`, `afkgold`, `afkxp`;
  revisão EN no PC e 375×667: `startup`, `afkxp`. Ambas **exit 0**, sem
  estouro de texto ou erros de script reportados.
- Consulta no cliente real: as duas `RefugePainting` com os IDs novos
  ficaram `IsLoaded = true` e `Visible = true`.
- Lobby de edição reconstruído (4.324 peças), publicação confirmada no log
  `0.743.0.7431133_20261018T121548Z_Studio_E9411_last.log`.

Evidências em `test-results/art-event-20261018/`; resumo reproduzível em
[`publication.json`](../assets/store/promo-2026-10-18/publication.json).
Galeria para o dono em
[`test-results/galerias/Artes_Evento_2026-10-18/index.html`](../test-results/galerias/Artes_Evento_2026-10-18/index.html).
