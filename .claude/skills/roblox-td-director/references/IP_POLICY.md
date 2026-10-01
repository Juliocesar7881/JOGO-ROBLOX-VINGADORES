# Marca segura

O jogo é **original**. Nada que um jogador veja pode usar nome, logo, uniforme
ou lugar de franquia de terceiros (Marvel/Disney, DC, Toilet Tower Defense,
Skibidi etc.). O vídeo do TTD é só referência de ritmo e de sistemas — nunca
copiar arte, nomes, sons ou textos dele.

- IDs internos (`ironman`, `wakanda`...) podem ficar: o jogador não os vê e os
  saves dependem deles. Tudo que aparece (Catalog `name/title/desc` em pt e en,
  placas, SurfaceGui, BillboardGui, prompts, códigos, nomes de Instance que
  aparecem em tooltips) precisa ser original.
- Uniformes: nada de combinação icônica copiada (armadura vermelha e dourada
  com reator no peito, escudo redondo de estrelas, martelo + capa vermelha,
  teia, garras de adamantium, pele verde gigante de shorts roxo...). Use a
  paleta, a silhueta e um acessório próprios de cada herói original.
- `tests/ip_blocklist.json` lista termos proibidos; `tests/test_ip_safety.py`
  roda no `tools/test.py`. Termo novo descoberto → adicione à lista no mesmo
  commit que o remove.
- Título no jogo: **Multiverse Doomsday** (nome que o dono deu à experiência),
  subtítulo "Última Defesa" / "Last Stand". "Doomsday" é palavra comum; não use
  "Avengers/Vingadores", "Doom" sozinho como personagem, nem "Marvel".
