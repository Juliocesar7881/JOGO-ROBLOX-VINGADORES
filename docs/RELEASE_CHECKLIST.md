# Checklist de lançamento — o que só o dono pode fazer

Tudo que o código e os testes cobrem já está no `main` e no lugar da equipe
(place 97132875544830). Esta lista é o que **não** dá para automatizar com
segurança: contas, termos, dinheiro e decisões de marca. Cada item diz quem
faz e como conferir.

## 1. Antes de qualquer teste com jogadores

- [ ] **Aceitar os termos atualizados do Roblox** no Creator Hub ("Updated
  Agreements", em vigor em 01/11/2026). Sem isso o Creator Hub não deixa
  criar mais produtos.
- [ ] **Pacote VIP**: Monetização → Passes → Pacote VIP visual → Vendas →
  ligar "Item for sale" e pôr 299. O passe e o ID já existem e estão no código.
- [ ] **Criar os 19 produtos de herói que faltam** (lista em
  `docs/director/ROBUX_CATALOG.md`; o fluxo está descrito lá) e gravar os IDs
  em `src/shared/Config.luau → Products.Heroes`. Até lá esses heróis aparecem
  como "Preço indisponível" na loja (sem erro).
- [ ] **Enviar os áudios**: `assets/audio/*.wav` (28 arquivos) no Creator Hub →
  Ativos → Áudio, e pôr os IDs em `Config.Audio` (0 = usa os sons do Roblox).
  Cota pode ser de 10 por mês; a ordem de prioridade está em
  `docs/director/BACKLOG.md` (M7.1).
- [ ] **Título e ícone da experiência**: nome "Multiverse Doomsday" (ou o que
  o dono escolher), ícone e miniaturas próprios, descrição em português.
  Imagens de divulgação 1920×1080 do próprio jogo (sem interface do Studio)
  já geradas em `assets/store/` por `python tools/store_media.py` (lobby, equipe,
  revelação de herói, baús, vitória): é só escolher e enviar na aba Mídia da
  experiência; refaça com o Studio aberto se algo mudar.
  Nenhuma imagem de terceiros.
- [ ] **Faixa etária / questionário de conteúdo** da experiência.

## 2. Compras (com uma conta alternativa, nunca a principal)

- [ ] Comprar cada passe e cada pacote uma vez e conferir: o item chega, o
  recibo não se repete ao reentrar, a loja marca "✓ JÁ É SEU".
- [ ] **Pacote Inicial**: comprar duas vezes; a segunda só paga Ouro (o herói
  vem uma vez por conta).
- [ ] Passe 3x: o botão da partida passa de 2x para 3x; sem o passe, recusa.
- [ ] Região restrita a itens aleatórios: baús só por Ouro (já é assim); conferir
  com uma conta de menor de idade.

## 3. Lugares e viagem (precisam de lugares publicados)

- [ ] Publicar lobby, partida e AFK como lugares (`docs/DEPLOYMENT.md`) e pôr os
  IDs em `deployment/local.json`; rodar
  `python tools/release.py --config deployment/local.json --check`.
- [ ] Teste de portal: 1 jogador e grupo de 4 entram numa fila, viajam para o
  lugar da partida e voltam.
- [ ] Reconexão no meio da partida (fechar e reabrir o app).

## 4. Aparelhos reais (o que o computador não prova)

- [ ] **Celular de entrada** (Android antigo): FPS no lobby e numa partida de
  onda 30+; o jogo reduz os efeitos sozinho abaixo de 27 FPS (veja o aviso);
  se o lobby (3.351 peças) pesar, ligar StreamingEnabled em um lugar de cópia
  e testar antes.
- [ ] Toque: colocar herói, melhorar, arrastar a câmera, painéis longos.
- [ ] Tela pequena (667×375) e notch: nada coberto pelos botões do Roblox.
- [ ] Sons: ouvir os "jingles" de moedas, baú, chefe, vitória, derrota.

## 5. Marca e legal

- [ ] Ler `docs/HEROES.md` e confirmar os nomes originais; trocar o que não
  agradar (é só dado no `Catalog.luau`; o teste `tests/test_ip_safety.py` avisa
  se algum nome de terceiros voltar).
- [ ] Conferir o nome no repositório/README e se quer renomear a pasta.
- [ ] Política de privacidade e termos do jogo, se for pedir.

## 6. Publicar (só o dono)

- [ ] `python tools/test.py` verde; revisar `git log` desde a última versão.
- [ ] Publicar a partir do Studio (Arquivo → Publicar no Roblox) no lugar da
  equipe; marcar a experiência como pública **só depois** dos itens 1 a 4.
- [ ] Vigiar a primeira hora: Analytics → funil "Tutorial", quedas e compras.

- Texto pronto da página da experiência (título, descrição pt/en, tags, nota da v1.0): `docs/STORE_PAGE.md`.
