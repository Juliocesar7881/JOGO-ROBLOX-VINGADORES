# Relatório da manhã — atualizado 02/10/2026 (tarde)

## Novidades da tarde de 02/10 (depois do relatório da madrugada)

- **Dois inimigos novos que mudam a leitura da partida**: o **Gosmento** racha em
  dois fragmentos ao morrer (dano em área é a resposta) e o **Sabotador** avisa e
  paralisa as torres por perto (derrube cedo; Capitão Men e a Muralha humana são
  imunes). Entram nas ondas 12 e 18; nunca no treino.
- **Herói novo com mecânica inédita**: **Caçador da Noite** planta **minas** na
  estrada à frente dos inimigos; dois ramos (Fragmentação / Choque) e Bomba de
  Fumaça. Total: **43 heróis**.
- **Polimento medido no Studio**: o letreiro "COMECE AQUI" ficava escondido atrás da
  seta do tutorial (removido); loja de Ouro com "MELHOR VALOR / MAIS POPULAR" e
  "Ouro por R$"; pacote inicial e linhas da loja mais enxutos no celular; o
  cartão do tutorial não cobre mais painéis em tela curta; tela final cabe sem
  rolar; Fundição, Wakanda e Cidadela mais claras (brilho médio 72→98, 91→97,
  90→102); 12 dicas de carregamento; teste de contrato do toque (tocar fixa o
  local, CONFIRMAR coloca).
- **Seus pedidos da tarde/noite (02/10)**: sem emoji em lugar nenhum (teste na suíte);
  correr com Shift e pulo duplo no lobby e nas partidas (no celular, o botão de ação do
  próprio Roblox); abertura de baú com o herói pulando, comemorando e mostrando o golpe;
  árvores, arbustos, canteiros e funcionários do lobby refeitos (figuras articuladas que
  respiram); **Ficha do comandante** na partida (talentos, base ativa e cartas só para
  ver); árvore de talentos refeita em favo compacto de ícones; **Ímã global** no fim da
  trilha Fortuna.
- Produtos de Robux a criar agora são **7 heróis novos** (inclui o Caçador da Noite,
  449) — tabela em `ROBUX_CATALOG.md`.


## O que mudou depois do seu feedback (lobby, tutorial, heróis)

- **Brilho**: bloom, exposição e neon do lobby e dos mapas abaixados; o neon claro
  (que virava branco) agora puxa para cores mais profundas.
- **Física**: jato, caixas, prédios da agência, troncos, cristais, o **núcleo** e
  a **base de cada jogador** agora são sólidos; o comandante nasce ao lado da
  própria base (antes cairia dentro dela no Complexo Gama).
- **Acabamento**: os três sets da agência viraram complexos fechados (barreiras com
  listras, postes, cones, bandeira) e **perderam os títulos** (são só cenário).
- **Idioma**: segue o idioma do Roblox (pt-* → português, o resto → inglês);
  escolher em Opções vale para sempre; mensagens do servidor são bilíngues.
- **Tutorial sem Nico**: seta grande + trilha + seta na borda levam ao portal de
  TREINO; dentro do treino, cartão de 5 passos com ponteiro no botão certo;
  depois, setas para o primeiro baú e para o portal da campanha.
- **Heróis**: 36 nomes descritivos que lembram os originais e **6 heróis novos** com
  kit próprio (Capitão Men, Guardião Verde, Titã Solar, Velocista Rubro, Amazona
  Dourada, Rei dos Mares) com mecânicas novas (empurrão, imunidade a paralisia,
  voo, aura) e poses/efeitos próprios. Total: 42 heróis.
- **Retenção**: mapa do dia (+25% Ouro e XP), bônus de grupo, temporada nomeada.
- **Auditoria crítica** honesta em `AUDIT.md` (02/10) e fila nova M12.

## Decisões e riscos que são seus

1. **IP dos visuais (importante):** os heróis novos e os renomeados são homenagens
   próximas a personagens conhecidos (cores, símbolos, poses). Nenhum nome de
   terceiros aparece, mas o **risco de denúncia/moderação do Roblox ao publicar é
   real**. Recomendo, antes de abrir ao público, trocar os visuais por designs
   originais mantendo os kits. Você decide.
2. Creator Hub: aceitar os termos; renomear os 15 produtos de herói já criados para
   os nomes novos (`ROBUX_CATALOG.md`); criar 25 produtos novos + passe de
   temporada + preço do VIP. Chrome precisa estar conectado.
3. Áudio próprio: sem upload não há áudio de mercado.

---


Tudo está no GitHub `main` (55 commits desde 23:56) e sincronizado no lugar da
equipe (place 97132875544830). **Nada foi publicado ao vivo.** A suíte
(`python tools/test.py`) está verde em todo commit.

## Precisa de você (nesta ordem)

1. **Aceitar os "Updated Agreements" do Roblox no Creator Hub.** O Creator Hub
   parou nesse aviso (aceitar termos é decisão do dono, o Claude não aceita).
   Depois disso faltam: **19 produtos de herói** (tabela em
   `docs/director/ROBUX_CATALOG.md`), o **passe "Passe de Temporada" (399)**,
   o **preço do Pacote VIP (299)** — ligar "Item for sale" — e o **upload dos
   WAVs** de `assets/audio`. O Chrome com a extensão Claude também precisa
   estar conectado para o Claude fazer isso; sem ele só o código avança.
2. **Marca:** confira os nomes originais em `docs/HEROES.md`.
3. Itens do dono em `docs/RELEASE_CHECKLIST.md` (renomear a experiência, ícones,
   teste de compra com conta alternativa, publicar).

## O que foi entregue (por área)

**Marca e segurança de IP.** Todos os heróis, vilões, mapas, bases, conquistas e
códigos originais (`tests/test_ip_safety.py` na suíte), 36 uniformes próprios.

**Sensação de combate.** Números de dano por golpe, tiros em lote, upgrade
com antes → depois, limite por herói, 3x (passe), prévia de onda, chegada de
chefe com câmera, tela final com MVP + JOGAR DE NOVO, bônus de grupo.

**Identidade dos mapas.** Perigo telegrafado por mapa; dificuldades Normal /
Difícil / Pesadelo escolhidas no elevador; Manhattan mais clara e alegre.

**Progressão e retenção.** Estrelas por herói repetido (+3% de dano cada),
variante brilhante (1/40 por baú), missões que rotacionam (9 tipos de objetivo),
**passe de temporada de 30 níveis** (trilha grátis + premium, resgate de tudo de
uma vez, selo no botão PRÊMIOS, cartão na tela final), **bônus de grupo**
(+10% de Ouro e XP por comandante extra), qualidade automática por FPS.

**Primeiros minutos.** Um toque em COMEÇAR TREINO (12 ondas, ~7,5 min); guia
atualizado; a primeira vista do lobby estava dentro das órbitas do Farol
(causava o "paredão amarelo") — corrigido.

**Robux (código + Creator Hub).** Passes 3x, coletor, treino, VIP; pacote
inicial; Ouro 1k/5k/12k/30k; 15 de 34 produtos de herói com ID. Tabela e
estado em `docs/director/ROBUX_CATALOG.md`.

## Notas da régua (antes → depois)

barra de heróis 2 → 4 · câmera 2 → 4 · baús no celular 3 → 4 · fim de partida 3 → 5
· painel da torre 2 → 4 · primeira vista do lobby 2 → 4 · missões (clareza) 2 → 4
· mapa de Manhattan (alegria) 2 → 3 · temporada (visibilidade) 0 → 4.
Capturas em `test-results/review/`; auditoria em `docs/director/AUDIT.md`.

## Como reverter

Cada item é um commit pequeno: `git revert <hash>` e depois
`python tools/studio_sync.py <arquivos> --place-id 97132875544830`.
Para pausar o diretor: crie `docs/director/STOP` (pode ser pelo GitHub).
