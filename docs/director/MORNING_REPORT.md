# Relatório da manhã — 01/10/2026 (atualizado 17:30)

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
