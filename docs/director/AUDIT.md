# Auditoria — Multiverse Doomsday × TTD (01/10/2026, 00:45)

Capturas reais do lugar da equipe pelo `tools/studio_review.py` (computador
1864×822 e celular 667×375): lobby, equipe, herói, baús, prêmios, preparação,
torre selecionada, resultados e uma partida real no Complexo Gama.
Notas 0–5 pela RUBRIC; TTD = referência (REFERENCE_TTD.md).

| Área | TTD | Nós | Por quê |
|---|---|---|---|
| Lobby (mundo) | 3 | **4** | Nosso HQ em ilhas é mais bonito e vivo que o lobby do TTD. Perde ponto pela Marvel (Homem de Ferro e Capitão América gigantes, "HANGAR DA S.H.I.E.L.D.", "INSTALAÇÃO DA HYDRA"). |
| HUD do lobby | 4 | 3 | Botões redondos bons. No celular o aviso do guia cobre a barra de navegação e o chat do Roblox fica por cima dos rótulos (desktop: em cima de "EVOLUÇÃO"). |
| Painéis (equipe/herói) | 4 | 3 | Organizados, mas texto pequeno (descrição ~9 px no celular), e a ação principal às vezes abaixo da dobra. |
| Baús | 4 | 3 | Ícones e preços claros; **no celular o botão INVOCAR fica cortado** — a ação principal precisa rolar. |
| Revelação | 3 | **4** | Baú 3D com raios (feito ontem) é melhor que o TTD. |
| Câmera da partida | 5 | 2→**4** | Abria colada no chão sem mostrar o mapa; **corrigido hoje** (commit 9a774e9). |
| Barra de heróis | 5 | 2 | Nomes quebrados no meio ("Homem-Ara nha"); no celular os espaços 4–5 ficam atrás do botão de poder. TTD: quadrado com retrato, número e preço, nada mais. |
| Painel da torre | 5 | 2 | No celular cobre a barra do chefe; atributos em ~9 px; "Melhoria 4/5 · só…" cortado; nenhum antes→depois. |
| Topo da partida | 4 | 3 | Completo, mas "ONDA 20 / 50" estoura a caixa (medido) e a base mostra rótulo bilíngue "NÚCLEO / CORE". |
| Mapa (Gama) | 5 | 3 | Legível de cima, mas escuro e acinzentado; o TTD é saturado e alegre. Mapas só diferem na estrada. |
| Combate | 4 | 2 | Sem números de dano por golpe, sem antes→depois no upgrade, chefe sem entrada, sem tela parada/habilidade de tela inteira. |
| Fim de partida | 4 | 3 | "VOCÊS CONSEGUIRAM!" com números grandes, mas **sem "JOGAR DE NOVO"** (o TTD recomeça em um toque) e texto cortado embaixo. |
| Economia de partida | 4 | 3 | Ouro de partida claro; falta herói de fazenda com feed "+$750" do TTD (verificar se algum herói nosso gera renda). |
| Monetização | 4 | 1 | Todos os IDs zerados; sem starter pack, 3x, espaço extra. |
| Áudio | 3 | 2 | Jingles de amostras nativas; nenhum áudio próprio enviado. |
| Marca | — | 0 | Marvel em nomes, uniformes, lugares, chefes e códigos. |

## Conclusão do diretor

O mundo já é nosso diferencial. O que separa do TTD é **o HUD da partida no
celular** (barra de heróis, painel da torre, CTA escondido), **a sensação de
combate** e **a marca**. Ordem: consertos rápidos de HUD que afetam todo
jogador (M1.5) → marca original (M2) → combate (M3) → Robux (M4).
