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

---

# Revisão crítica — 02/10/2026 (olhar de crítico de jogos Roblox)

Feita sobre capturas reais do Studio (computador e celular deitado), os testes
e a leitura do código. Notas 0–5; "TTD" é a referência. Honesta de propósito.

| Área | Nota | O que um crítico diria |
|---|---|---|
| Primeiros 60 s | **4** | Seta grande + trilha + seta na borda levam ao portal de treino; no treino, cartão de 5 passos com ponteiro no botão certo; depois, baú e campanha. Falta ver com um jogador de verdade: não validamos toque nem o ritmo real. |
| Lobby | **4** | Bonito e vivo, sem mascote. Muita placa flutuando ao mesmo tempo; o brilho foi baixado, mas ainda é o ponto mais forte de qualquer tela. Sets da agência agora são sólidos e fechados. |
| Partida (leitura) | **4** | Barra de heróis, números de dano, antes→depois no upgrade, chefe com câmera. No celular o canto superior esquerdo concentra HUD + painel da torre + barra do chefe. |
| Combate (sensação) | **3,5** | Efeito próprio por herói e poses (soco, voo, arco), mas inimigos reagem pouco ao dano (sem recuo/flash por golpe forte), e os mapas de Manhattan/Gama são cinzentos de cima. |
| Variedade de heróis | **4** | 42 heróis, 42 poderes, 6 com mecânica própria (empurrão, imunidade a paralisia, voo). A maioria ainda é "dano + alcance + um modificador": só os 6 da liga e uns 10 antigos jogam diferente. |
| Progressão | **4** | Nível, maestria, estrelas, brilhante, 16+ missões, passe de 30 níveis, bônus de grupo. Falta algo que dê meta de longo prazo visível (coleção completa tem marcos, mas sem vitrine no lobby). |
| Monetização | **3** | Código completo e testado; produtos reais ainda incompletos (19 heróis + 6 novos + passe + preço do VIP). Não há como testar compra real sem o dono. |
| Áudio | **2** | Só os sons nativos do Roblox: os WAVs próprios não foram enviados (Creator Hub parado). É a maior diferença para um jogo "de mercado". |
| Celular | **3** | Layout testado em 9 telas e fonte ≥12 px, mas nada foi tocado num aparelho real; desempenho no celular não foi medido. |
| Marca/IP | **2** | Os nomes são epítetos e os visuais são homenagens próximas (cores e símbolos) a personagens conhecidos. **Risco real de moderação/denúncia do Roblox** se publicar assim; o dono pediu esse estilo e decide. Alternativa: manter os kits e trocar visuais/nomes por originais antes de abrir ao público. |
| Social/retenção | **3** | Bônus de grupo, placar, missões diárias. Faltam presentes entre amigos, convite com recompensa e eventos de tempo limitado. |

## O que bloqueia uma nota 5 e quem pode resolver

1. **Áudio próprio no jogo** — precisa do Creator Hub (Chrome conectado, termos aceitos). 
2. **Aparelho real** — teste de toque, desempenho e teleporte num celular com o lugar publicado.
3. **Decisão de IP** — o dono escolhe entre homenagem próxima (rápido, arriscado) e visual original.
4. **Produtos de Robux** — dono aceita os termos; o diretor cria o resto.

Tudo que não depende disso virou fila: ver `BACKLOG.md`, seção M12.
