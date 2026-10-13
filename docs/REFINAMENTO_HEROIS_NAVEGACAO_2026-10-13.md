# Heróis, estátuas e navegação — 13/10/2026

Pedido: retirar os personagens decorativos da árvore, manter Voltar acessível
durante a rolagem e refinar os 43 heróis e as duas estátuas principais.

## Implementação

- Árvore sobre o desfoque existente, sem os retratos laterais.
- Voltar numa faixa fixa da janela, fora da lista. Conteúdo abaixo da faixa,
  inclusive no celular; atualização de perfil preserva a rolagem e mantém
  apenas uma instância da navegação.
- Acabamento dos 43 figurinos: membros afunilados chegando às juntas,
  contornos de armadura, placas seguindo o tronco, uniforme com a cor da
  cobertura e tecido de cor lisa. Brilhos secundários viram acabamento
  metálico; olhos e fontes de poder mantêm suas assinaturas. Acentos do peito
  ficam à frente da placa, sem serem escondidos por ela.
- Placas coincidentes no mesmo membro removidas; peças iguais em membros
  diferentes permanecem. O acabamento não acrescenta BaseParts. Rigs,
  emissão das armas, custos e combate preservados.
- Monumentos com elmos/armaduras contornados, peito mais estreito e postura
  assimétrica; reator da Armadura de Ferro e escudo do Capitão.

## Verificação e colaboração

`tools/test.py`: saída 0; world boot com 8.245 checagens e cliente em seis
formatos completos. Lobby no teste: 4.477 peças, abaixo de 4.500.
Fontes da equipe comparadas antes do sync. WorldBuilder tinha alterações
locais anteriores de materiais/comentário; Effects também tinha mudanças
locais ainda não sincronizadas. Backup em `test-results/heroes-20261013/`.
Nenhuma edição desconhecida do Studio sobrescrita. Effects, UI e MatchHud
ficam fora deste lote.

Capturas: `test-results/galerias/Herois_Navegacao_2026-10-13/`.
Este lote refina o catálogo procedural existente; não substitui os 43
figurinos por esculturas novas nem comprova desempenho em aparelho físico.
Revisão nativa concluída: 43 heróis em 11 capturas, árvore, galeria, equipe,
ficha da partida, Voltar com rolagem real no PC/667x375/375x667 (EN), duas
estátuas e combate com carga solicitada de 80 inimigos. Sem erros de script;
não houve medição nova de FPS. A captura vertical ainda mostra truncamento
preexistente em detalhes de poder; não confundir com o Voltar corrigido.

Publicado no place 97132875544830 em 13/10/2026 às 18:00:25 local
(21:00:25 UTC), confirmado por `Go to PublishSuccessful` no log.
Lobby de edição reconstruído: 4.497 peças no Studio (4.477 no dublê).
41 fontes conferidas: 40 iguais ao working tree, Effects igual à versão
anterior já presente no Studio, preservada. Studio deixado em edição.
Galeria: `test-results/galerias/Herois_Navegacao_2026-10-13/index.html`.

Avaliação: clareza da navegação 4/5, coerência dos figurinos 4/5,
distinção de silhuetas 3/5. O acabamento melhora a versão atual, mas várias
silhuetas continuam compartilhando a estrutura procedural; revisão artística
individual mais profunda permanece como oportunidade, não aceite concluído.
