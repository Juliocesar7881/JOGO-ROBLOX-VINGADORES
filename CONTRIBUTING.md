# Contribuindo

Este projeto é trabalhado por duas pessoas (e por sessões de IA agindo em nome
de cada uma) no mesmo repositório, muitas vezes ao mesmo tempo. As regras
abaixo existem para que isso não vire uma corrida de `git push --force`.

## Antes de editar

```bash
git status --short
git pull
```

Se `git status` já mostra mudanças que você não fez, é a outra pessoa (ou a
sessão dela) trabalhando agora. Leia o que mudou antes de tocar nos mesmos
arquivos — na dúvida, `git commit` o que está pronto e prossiga por cima,
nunca descarte trabalho alheio sem entender o que era.

## Enquanto edita

- **Commits pequenos e frequentes**, um assunto por commit. Um commit gigante
  misturando três funcionalidades é impossível de revisar e impossível de
  reverter parcialmente se algo quebrar.
- **Rode a suíte antes de commitar:**
  ```bash
  python tools/test.py
  ```
  Ela compila todo `.luau`, roda ~900 mil asserções de regras/economia,
  simula partidas inteiras fora do Roblox, sobe o servidor e o cliente reais
  contra dublês do Roblox, confere layout em várias telas e gera os três
  lugares em `dist/`. Não commite com a suíte vermelha.
- **`docs/HEROES.md` é gerado, não editado à mão.** Se você mudou um herói ou
  uma habilidade em `Catalog.luau`, rode:
  ```bash
  .tools/luau/luau.exe tools/gen_heroes_doc.luau > docs/HEROES.md
  ```
  `tools/test.py` falha se esse arquivo ficar desatualizado.
- **Evite abrir o Studio ao mesmo tempo que a outra pessoa está rodando
  `tools/studio_hud_review.luau`** ou qualquer automação — os dois processos
  usando a mesma instância do Studio para coisas diferentes é como nasce um
  bug impossível de reproduzir. Combine quem está com o Studio aberto.
- Mudanças de regra do jogo (custo, dano, recarga, raridade, economia) vão em
  `src/shared/Catalog.luau` e `src/shared/Rules.luau` — nunca no cliente. O
  cliente manda intenção, o servidor decide; veja `IMPLEMENTATION.md`.

## Antes de subir

```bash
python tools/test.py
git add -A
git commit -m "Assunto claro e específico"
git push
```

Mensagens de commit devem dizer **o quê** e **por quê**, não só "ajustes". Se
a mudança envolveu números de balanceamento, cite os números antes/depois —
isso poupa a outra pessoa de ter que rodar a simulação de novo para saber o
que mudou.

## Convenções do código

- Comentários explicam **por que**, não o que o código já deixa óbvio.
- Módulos compartilhados (`src/shared/`) são dados puros ou funções puras —
  nunca leem `game:GetService`. Isso é o que permite testar `Rules.luau`
  inteiro fora do Roblox, em segundos, sem abrir o Studio.
- Todo texto visível ao jogador é bilíngue: `{ pt = "...", en = "..." }` via
  o helper `text(pt, en)` do `Catalog.luau`.
- Veja `IMPLEMENTATION.md` para o contrato entre cliente e servidor (nomes de
  ação, formato do snapshot, o que cada serviço expõe) antes de adicionar uma
  ação nova — ele existe para que as duas pessoas não reinventem convenções
  diferentes para a mesma coisa.

## Testes que faltam automatizar

A suíte cobre regras, economia, uma partida inteira simulada, o boot real do
servidor e do cliente contra dublês do Roblox, e o layout em várias telas.
Ela **não** cobre (precisa de Studio publicado e/ou aparelho real):
teleporte entre lugares, servidores reservados, compras reais em Robux,
desempenho em celular, toque real e áudio. Antes de anunciar algo como
"pronto para lançar", teste isso manualmente.
