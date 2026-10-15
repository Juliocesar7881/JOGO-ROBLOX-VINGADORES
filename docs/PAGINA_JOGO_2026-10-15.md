# Página da experiência — 15/10/2026

Universo `10768165352`, place da equipe `97132875544830`.

## Entrega local

Material em [`assets/store/promo-2026-10-15/`](../assets/store/promo-2026-10-15/).
Galeria em
[`test-results/galerias/Pagina_Jogo_2026-10-15/index.html`](../test-results/galerias/Pagina_Jogo_2026-10-15/index.html).

| Arquivo | Conteúdo | Formato |
| --- | --- | --- |
| `icone.png` | Armadura branca/azul e portal | PNG, 512×512 |
| `thumbnail-01.jpg` | Dupla principal no lobby | JPEG, 1920×1080 |
| `thumbnail-02.jpg` | Defesa da rota em Manhattan | JPEG, 1920×1080 |
| `thumbnail-03.jpg` | Trio de heróis atuais | JPEG, 1920×1080 |
| `thumbnail-04.jpg` | Praça e portais | JPEG, 1920×1080 |
| `trailer.mp4` | Lobby, combate, poder do líder, coleção e chefe reais | 24 s, 1280×720, 30 FPS, H.264/AAC |
| `description.en-us.txt` | Descrição no idioma-fonte | Texto |
| `description.pt-br.txt` | Descrição em português | Texto |
| `description.es-es.txt` | Descrição em espanhol | Texto |

## Referências e verificação local

As cinco imagens foram geradas com o `image_gen` integrado. Os prompts,
referências e a correção pontual da miniatura de combate estão em
[`prompts.json`](../assets/store/promo-2026-10-15/prompts.json).
Originais preservados em `originais/`; exportação técnica feita com Pillow.
[`manifest.json`](../assets/store/promo-2026-10-15/manifest.json) registra
dimensões, tamanho em bytes e SHA-256 de cada imagem.

Referências atuais capturadas no Studio, em
`test-results/marketing-20261015/`:

- `clips/01-lobby.first.png`: lobby atual, portais e estátuas usando DoomArt.
- `references/current-heroes-native.first.png`: Armadura branca/azul,
  Capitão teal/navy/amarelo e herói do trovão prata/navy.
- `clips/02-combat.first.png`: captura refeita e validada pelo responsável
  pela revisão, com posicionamentos e poder aceitos pelo servidor.

Todas as imagens finais foram inspecionadas. A miniatura de combate recebeu
uma correção para deixar apenas um martelo no herói do trovão. As quatro
miniaturas têm menos de 1 MB cada; o ícone tem aproximadamente 350 kB.
As artes são ilustrações promocionais, não capturas de gameplay. O vídeo
usa material gravado do jogo real.

As versões que seguiam os modelos antigos foram movidas intactas para
`test-results/marketing-20261015/rascunhos-antigos/`, fora do pacote final.

## Texto e página

As descrições EN/PT/ES e `copy.md` foram copiadas da pasta de produção para
o pacote. O texto apresenta mecânicas existentes, com marca estável e sem
acúmulo de palavras-chave. Referências oficiais e requisitos consultados
estão em [`copy.md`](../assets/store/promo-2026-10-15/copy.md).

O título **Multiverse Doomsday Tower Defense** foi preservado. Descrições
salvas e relidas no Creator Hub nos três idiomas; idioma-fonte inglês e
17 idiomas de tradução automática preservados. Strategy / Tower Defense
continua como gênero/subgênero. Nenhum preço, colaborador ou configuração de
público foi alterado.

## Aplicação e conferência no Roblox

Ícone novo salvo e conferido visualmente pela CDN pública, estado
`Completed`. Quatro miniaturas da página de detalhes aprovadas:

| Arquivo | Asset ID |
| --- | --- |
| `thumbnail-01.jpg` | `140326426504170` |
| `thumbnail-02.jpg` | `86852778868880` |
| `thumbnail-03.jpg` | `107286642963113` |
| `thumbnail-04.jpg` | `106659593225061` |

Textos de acessibilidade salvos nas quatro. A Home usa uma lista separada:
as quatro novas miniaturas estão ativas, personalização ligada e persistência
conferida após reabrir a tela. As duas antigas ficaram inativas para preservar
o histórico. Evidência em `test-results/marketing-20261015/hub/`, especialmente
`applied-summary.json`, `public-media-final.json`, `public-icon.png` e
`home-final-persisted.png`.

O trailer mostra gameplay do place oficial no Studio, sem animação de IA,
narração ou imagens externas sobrepostas. A cena de poder usa `CastSkill`
aceito pelo servidor, com o efeito visível; os perfis e inimigos usados na
captação são temporários do Studio. Música instrumental original do projeto
(`assets/audio/battle.wav`), créditos e procedência em `trailer.json` e
`trailer.credits.txt`. Arquivo decodificado sem erros ou intervalos pretos;
24,000 s, 7,63 MB, áudio medido em -18,32 LUFS / -5,01 dBTP. O Studio foi
deixado em edição, place `97132875544830` confirmado; nenhuma fonte foi
editada ou sincronizada para esta entrega de página.

Vídeo enviado com **Video uploaded successfully**, um único envio e dois
uploads restantes da quota mensal. Registrado como primeiro item da galeria
(`GamePreviewVideo`, asset `136040769273965`, media
`8568662179705711`). Na consulta final de **15/10 às 20:31:02 de Brasília**,
**Video under review** e
`approved=false`: o envio está concluído, a aprovação depende da moderação
do Roblox. Não reenviar enquanto estiver em análise.

## Limite atual de distribuição

A leitura de Manage Audience em 15/10 ainda mostra disponibilidade **16+**,
avaliação de conteúdo completa e requisito de alcance **Incomplete**:
**0/250 highly engaged players**. Isso não foi alterado por esta entrega.
Evidência: `hub/manage-audience-current.json` e `.png`. As novas imagens e
descrições preparam a apresentação; não garantem posição nas buscas,
recomendações ou viralização. Comparar desempenho das miniaturas quando
houver tráfego suficiente, sem trocar o conjunto a cada dia.

## Validação do repositório

`python tools/test.py` concluído com **exit 0**. Regras/economia: 664.794
asserções; layout: 6.937 checagens; mundo: 8.593 checagens. Compilação,
boot de cliente/servidor, simulação e geração dos places incluídos.
Log: `test-results/marketing-20261015/full-suite.txt`.
Entrega principal no `main`: `d74ae82`. O complemento inclui o ícone e os
cinco originais PNG no git, com exceção restrita no `.gitignore` para que as
regras de capturas locais não excluam os assets de produção.
Alterações de combate feitas simultaneamente por outra sessão foram
preservadas e não integram o escopo desta entrega.
