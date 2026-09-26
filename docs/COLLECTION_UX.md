# Coleção, formação e ficha dos heróis — 25/09/2026

Esta revisão completa parte do fluxo de inventário previsto no backlog.

- Busca por nome ou função, aceitando português/inglês e palavras sem acento.
  A busca é aplicada ao confirmar ou sair do campo; digitar não reconstrói
  o campo a cada letra.
- Filtro de raridade e ordenação por coleção, raridade, maestria, custo de
  posicionamento ou nome. Empates mantêm uma ordem estável.
- Contagem dos resultados, limpar filtros e estado vazio sem área negativa.
- Base equipada junto da equipe, com ilustração e acesso direto à troca.
  Em telas estreitas, a base passa para a linha seguinte.
- Primeiro slot dourado abre a escolha de líder. É possível escolher outro
  slot da equipe ou um herói possuído na coleção, sem abrir sua ficha.
  A operação continua sendo `SetLoadout`, validada pelo servidor.
- Cartões da coleção mostram a função do herói, além de raridade e maestria.
- A ficha abre na aba Poder e equipe, com as ações de equipar/evoluir.
  A aba Na defesa explica os valores iniciais da torre, alvos atingidos e as
  duas especializações finais, separadamente da evolução permanente do poder.
- Cabeçalhos das seções têm espaço para quebra de linha em telas estreitas.

O painel adia reconstruções enquanto há um campo de texto em edição, retoma
ao terminar a digitação e mantém a área de rolagem existente. Isso também
protege a entrada de códigos no painel de prêmios enquanto ela tem foco.

Validação automatizada: 3.510 verificações do cliente em seis resoluções,
incluindo busca sem acentos, ausência de resultados, filtro, ordenação,
troca de líder, preservação de texto com foco e rolagem sob atualizações.
A suíte completa (`python tools/test.py`) foi aprovada e regenerou os três
lugares em `dist/`.

No Studio, a busca por `capitao` encontrou Capitão América; alterações de
saldo preservaram o campo em edição. Depois de filtrar, a coleção foi rolada
até 300 pixels e recebeu oito atualizações de perfil sem perder a posição.
Captura da formação/coleção: `test-results/collection-review.png`.
A ficha foi inspecionada no renderer em `test-results/hero-defense-review.png`.
Com área útil forçada a 640 × 320, o painel mediu 620 × 300, a área rolável
586 × 226 e o campo de busca 490 × 44. Esse ensaio não substitui toque em
aparelho real.

Ainda pendentes neste subsistema: favoritos persistentes, comparação lado
a lado entre heróis e ensaio com toque/teclado virtual em aparelho real.
Arte dos personagens, áudio publicado e validação dos serviços online
continuam nas respectivas áreas do backlog; esta revisão não encerra a
produção do jogo.
