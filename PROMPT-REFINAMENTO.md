# Prompt de refinamento — Vingadores: Doomsday

> Cole o conteúdo abaixo (da linha `---` em diante) numa sessão nova do Claude Code
> aberta em `C:\Users\loops\Documents\Roblox Game`.

---

Você vai assumir um jogo de Tower Defense cooperativo para Roblox que já está
funcionando de ponta a ponta, e elevá-lo ao padrão visual e de interface dos
Tower Defense grandes do Roblox (referência explícita: **Toilet Tower Defense**).

**Trabalhe direto no projeto.** Crie e edite os arquivos, rode os testes, corrija
o que quebrar e siga para o próximo item sem parar a cada passo para pedir
confirmação. Explique pouco, entregue muito.

## 1. O que já existe (não reconstrua)

Projeto em `C:\Users\loops\Documents\Roblox Game`. ~5.100 linhas de Luau, tudo
autoral, **zero assets da Toolbox**.

```
src/shared/   Catalog (12 heróis, 13 inimigos, 5 mapas, 6 modos, 10 habilidades,
              5 protocolos, produtos), Config (IDs e ambiente), Rules (fórmulas
              puras), Waves (gerador determinístico de ondas)
src/server/   init.server (bootstrap, roteador de intenções, viagem entre
              lugares), MatchService (combate, ondas, chefes, economia),
              PlayerService (perfil, DataStore, ProcessReceipt, placares),
              PartyService, WorldBuilder (constrói lobby e mapas em runtime),
              PresenceService (títulos/trilha VIP), AnalyticsService, RejoinService
src/client/   init.client (controlador + toda a UI), UI (primitivas),
              Effects (inimigos, moedas, tiros, tremor), Audio, Nameplates
tools/        build.py (gera .rbxlx sem Rojo), test.py, setup_luau.py
tests/        roblox_stubs.luau + 5 suítes
```

**Leia antes de mexer:** `IMPLEMENTATION.md` (contrato entre módulos, é a fonte
da verdade) e `README.md` (setup, estado, balanceamento medido).

### Funciona hoje
Lobby, grupo com código, tutorial, campanha de 30 ondas, 5 mapas, 6 modos,
chefes com fases, Protocolos de Batalha, economia de Ouro/Energia, moedas
pessoais, drone coletor, perfil persistente com sessão exclusiva, passes e
produtos com `ProcessReceipt` idempotente, placares por temporada, telemetria,
reconexão entre servidores, títulos, PT-BR/EN.

### Como rodar e verificar
```bash
python tools/test.py      # suíte completa: compila, 438k asserções de regras,
                          # PlayerService com dublês, contrato cliente/servidor,
                          # boot do mundo, partida completa simulada
python tools/build.py     # gera dist/Doomsday-{Studio,Lobby,Match}.rbxlx
```
Abra `dist/Doomsday-Studio.rbxlx` no Roblox Studio e aperte **F5**.

**Armadilhas do Studio:** (a) pode aparecer a caixa "Recuperação automática" —
clique em **Ignorar**, senão o Play não dispara; (b) o mundo inteiro é gerado em
runtime, então no modo de edição você só vê um chão temporário
(`EditorBaseplate`/`EditorSpawn`, que o servidor apaga no boot); (c) o log fica
em `%LOCALAPPDATA%\Roblox\logs` — procure `[Doomsday] version ... starting` para
confirmar o boot e erros de Lua logo depois.

## 2. O que precisa mudar

### Frente A — Lobby diegético (prioridade máxima)

Hoje o lobby tem 7 terminais com `ProximityPrompt`, mas todos abrem **o mesmo
painel gigante com abas** (JOGAR / HERÓIS / HABILIDADES / MISSÕES / LOJA /
PLACAR). Isso é um menu de aplicativo colado num jogo, e é exatamente o que o
dono do projeto não quer.

**Refaça no modelo do Toilet Tower Defense: cada função é um lugar físico.**

- **Portais de modo.** Cada modo de jogo é um portal 3D distinto no lobby —
  Campanha, Difícil, Infinito, Desafio Diário, Investida de Chefes. Entrar no
  portal (ou usar o prompt) é o que inicia o fluxo daquele modo. Placas ao redor
  mostram mapa, dificuldade, ondas e requisito de desbloqueio; um portal
  bloqueado tem aparência visivelmente diferente e explica o que falta.
- **Loja.** Um prédio/balcão com os produtos **expostos fisicamente**: o drone
  coletor girando numa vitrine, o baú de Ouro, o manequim do pacote VIP. Chegar
  perto mostra preço e benefício num cartaz; comprar é um botão pequeno e
  contextual, não uma aba.
- **Galeria de heróis.** Estátuas/pedestais dos 12 heróis. Herói não comprado
  fica escurecido ou coberto; comprar revela a estátua com um efeito. Equipar
  acontece ali, olhando para o herói.
- **Sala de treinamento.** Onde se compram e equipam habilidades ativas e
  passivas, com alvos/manequins ao fundo.
- **Quadro de missões** e **totem de placar**: `SurfaceGui` renderizado no mundo,
  legível de longe, não uma janela.

**Regra de ouro da UI nova:** a interface que aparece deve ser pequena,
contextual e ancorada no lugar onde o jogador está. O HUD permanente fica só com
o essencial (Ouro, nível, e em partida: onda, núcleo, Energia, heróis,
habilidades). Nada de painel de tela cheia com abas no lobby.

O `ProximityPrompt` e o callback `openPanel` já existem em
`WorldBuilder.luau:64-86` e chegam ao cliente como evento FX `OpenPanel` —
aproveite esse caminho, mas troque o destino.

### Frente B — Qualidade visual

Hoje tudo é `Part` sem textura, cor chapada, `SmoothPlastic`/`Neon`. Funciona,
mas parece blockout.

- **Iluminação:** `Lighting.Technology = Future`, `Atmosphere`, `Bloom`,
  `ColorCorrection`, `SunRays`, `DepthOfField` com parcimônia. Paleta própria
  por capítulo (Manhattan noturna, Gama esverdeada radioativa, HYDRA industrial,
  Wakanda púrpura/dourada, Latvéria fria e mágica).
- **Materiais:** use `MaterialService` com `MaterialVariant` e as texturas
  nativas do Roblox. Só use `SurfaceAppearance` com texturas que você mesmo
  gerar ou que sejam comprovadamente livres — **não baixe nada da Toolbox**.
- **Modelagem:** eleve heróis, inimigos, portais, núcleo e cenário. Silhuetas
  fortes e legíveis de cima (é um TD, a câmera é distante). Chanfros, molduras,
  detalhes repetidos, sujeira e destruição parcial nos cenários.
- **Animação:** inimigos caminhando de verdade (rig + `Animator`, ou ao menos
  balanço procedural convincente), torres com pose de ataque, recuo, e um
  destaque visível a cada melhoria — a regra do projeto é que **toda melhoria
  muda algo visível no herói**.
- **VFX:** `ParticleEmitter`, `Beam`, `Trail` para tiros, explosões, portais,
  invasão do núcleo e habilidades. Legível acima de tudo: o jogador precisa
  entender o que está acontecendo no meio de 80 inimigos.
- **Feedback de dano:** números de dano flutuantes opcionais, flash no inimigo
  atingido, impacto na câmera (já existe `Effects:Shake`, respeitando a
  configuração de acessibilidade).

Mantenha tudo **gerado por script** em `WorldBuilder.luau` e nos módulos de
cliente, ou como modelos que você construa e o build embuta. O pipeline
(`tools/build.py`) monta o `.rbxlx` a partir de `src/`, então qualquer asset
novo precisa caber nesse fluxo — se precisar mudar o build para suportar
modelos, mude.

### Frente C — Celular

Meta: **30 FPS em celular de referência, 60 no PC**. Hoje nada foi testado em
dispositivo.

- Layout de toque em primeiro lugar: botões grandes, alvos de toque generosos,
  nada que dependa de hover. Já existe separação mobile/desktop em
  `init.client.luau` (`mobile()` a partir da largura do viewport) — melhore.
- Posicionar torre no toque precisa de confirmação explícita (já existe, refine).
- Orçamento de performance: limite de peças, `CastShadow = false` no que é
  pequeno, reuso de instâncias (já há pool para inimigos, moedas e tiros),
  `StreamingEnabled` se ajudar, e redução automática de efeitos em aparelho
  fraco **sem alterar regras de jogo** (a configuração `lowFX` já existe).
- Teste os três tamanhos: celular retrato, tablet e desktop.

## 3. Regras invioláveis

1. **O servidor decide.** O cliente envia intenção; custo, alcance, propriedade,
   saldo, recarga, dano e recompensa são calculados no servidor. Nunca mova
   validação para o cliente para facilitar a UI.
2. **A suíte tem que continuar verde.** `python tools/test.py` antes de dizer que
   terminou. Sistema novo pede teste novo — o projeto já tem stubs de Roblox
   completos em `tests/roblox_stubs.luau` (Instance, CFrame com matemática real,
   Enum, task, workspace) para testar código de mundo fora do Roblox.
3. **Nada de asset não licenciado.** Sem Toolbox, sem texturas de terceiros, sem
   áudio de terceiros. `Config.Audio` está zerado de propósito: ID `0` = silêncio.
4. **IDs ficam no `Config.luau`** e `0` significa indisponível, falhando fechado.
   Nunca embuta `rbxassetid://` no código — existe teste que reprova isso.
5. **Marvel é propriedade de terceiros.** O projeto usa arte e texto autorais e o
   licenciamento é um requisito pendente anterior a qualquer publicação
   comercial. Não gere arte que imite material oficial da Marvel.
6. **Balanceamento é medido, não chutado.** `python tests/test_match_simulation.py`
   joga uma campanha inteira e imprime a duração. Números atuais: tutorial 7,4
   min; campanha 30 ondas em 36,6 min com o núcleo intacto; alvo de design 25–35
   min. Se mexer em velocidade, vida ou rota, meça de novo — encurtar rota em 30%
   já tornou o jogo injogável uma vez (derrota na onda 9).

## 4. Critérios de aceitação

- [ ] Nenhum painel de abas em tela cheia no lobby; cada função tem lugar físico.
- [ ] Os 5 modos são portais distintos e legíveis, com estado de bloqueio claro.
- [ ] Loja, galeria de heróis, treinamento, missões e placar existem como locais.
- [ ] Iluminação, materiais e VFX elevados nos 5 mapas e no lobby.
- [ ] Toda melhoria de torre muda algo visível.
- [ ] Layout validado em celular retrato, tablet e desktop.
- [ ] `python tools/test.py` verde, com testes novos cobrindo o que você criou.
- [ ] O jogo boota no Studio sem erro de Lua no log.
- [ ] `README.md` e `IMPLEMENTATION.md` atualizados com o que mudou.

## 5. Ordem sugerida

1. Ler `IMPLEMENTATION.md`, rodar a suíte, abrir no Studio e jogar uma partida
   para sentir o estado atual.
2. Frente A (lobby diegético) — é a que o dono mais quer e a que muda a cara do
   jogo. Comece pelo layout físico, depois troque a UI.
3. Frente B (visual) — lobby primeiro, depois mapa de Manhattan, depois os outros.
4. Frente C (celular) — ao longo das duas anteriores, e uma passada dedicada no fim.
5. Medir de novo, atualizar docs.

Entregue em etapas jogáveis: a cada frente concluída, o jogo tem que abrir,
rodar e passar na suíte.
