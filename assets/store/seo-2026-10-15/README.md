# Página do jogo: nome com "Heroes" e texto para crianças (15/10, noite)

Pedido do dono: pôr "Heroes" no nome e trocar o texto da página (feito antes por
outra ferramenta) por um que puxe a criança para dentro do jogo.

- **Nome (todos os idiomas):** `Multiverse Heroes: Doomsday Tower Defense` (41 de 50
  caracteres). "Heroes" e "Tower Defense" são o que a criança digita na busca, e
  "Multiverse Heroes" aparece primeiro no card da descoberta. A tela de carregamento
  do jogo mostra o mesmo nome (`src/first/ScreenArt.luau`).
- **Texto:** gancho curto em maiúsculas, uma linha por motivo para jogar (com emoji),
  os códigos ativos e um convite a dar Like e Favorite, sem prêmio em troca (regra do
  Roblox). Arquivos: `description.{en-us,pt-br,es-es}.txt` e `metadata.json`.
- **Cada promessa confere com o código:** 43 heróis e 3 raridades em jogo, comum, rara e
  lendária (`Catalog.RarityOrder`; épico e mítico não existem mais para o jogador); baú grátis
  a cada 6 horas (`Catalog.Rewards.freeChest`); 28 dias de login com um herói lendário
  à escolha no último (`Catalog.Rewards.login`); 6 mapas, Competitivo sem fim, Roguelike
  de Cartas; grupo de até 4 jogadores no total (`Config.MaxPartySize`); 2x sem passe; códigos `ULTIMATE` (1.000 de Ouro + baú raro,
  expira em 01/01/2027) e `LANCAMENTO` (300 de Ouro + baú raro) em `src/server/Codes.luau`.
  **Quando ULTIMATE expirar, tirar o código da descrição.**
- Idioma-fonte da página: inglês; português e espanhol como traduções manuais.
