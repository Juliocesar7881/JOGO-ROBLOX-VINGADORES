# Relatório da manhã — 01/10/2026

Tudo está no GitHub `main` e sincronizado no lugar da equipe
(place 97132875544830). **Nada foi publicado ao vivo.**

## O que aconteceu na noite

- 23:56–01:15 trabalho contínuo; **01:15–07:30 parado** pelo limite de uso
  da conta. A tarefa agendada `roblox-td-director` disparou de hora em hora,
  mas **não abriu nenhuma sessão** (0 execuções registradas) — ver "Precisa
  de você".
- 07:30 em diante: retomado nesta sessão.

## Entregue (9 commits)

| Commit | O quê |
|---|---|
| 7a0dc3d | Infra do diretor: trava de uma sessão por vez (`tools/director.py`), skill `roblox-td-director` (ciclo, régua, Studio, marca), referência do TTD (29 observações do vídeo) e fila. |
| ac954b9 | `Review.luau` + `tools/studio_review.py`: revisão de telas no Studio **sem editar nenhum script do lugar** (substitui o gancho antigo que reescrevia o cliente). |
| 9a774e9 | Câmera da partida abre **de cima do mapa** (antes ficava colada no chão). |
| a79ec4d | Ferramentas: leitura dos logs dos dois processos do Studio, nova tentativa de comandos, modo celular real. |
| 56d19ff | **Barra de heróis estilo TTD**: retrato, número e preço; 5 espaços sempre cabem no celular (antes nomes quebravam e os espaços 4–5 sumiam). |
| 3f2fdfc | Chat do Roblox compacto à direita (saiu de cima do menu e da barra). |
| a401530 | "ONDA 20 / 50" cabe; placa da base diz "BASE" nos dois idiomas. |
| bae208f | Baús no celular: botão **INVOCAR visível sem rolar**. |
| 2dc8b53 | **"▶ JOGAR DE NOVO"** no fim da partida (voto no servidor, mesmo mapa e modo; treino continua indo ao lobby). |

Notas da régua (antes → depois): barra de heróis 2 → 4; câmera 2 → 4;
baús no celular 3 → 4; fim de partida 3 → 5. Auditoria completa em
`docs/director/AUDIT.md`.

## Precisa de você

1. **Tarefa agendada:** abra "Agendado" na barra lateral do app, entre em
   "Diretor do jogo (noite)" e clique **Executar agora** uma vez com você
   olhando — se aparecer pedido de permissão ou de confiança na pasta, aprove.
   Sem isso as rodadas noturnas não começam.
2. **Marca:** confirme o título no jogo **"Multiverse Doomsday"** (o nome que
   você deu à experiência) e se os nomes propostos para os heróis originais
   (Volt, Arqueiro Vento, Comandante Égide, Pedregulho, Brontus…) servem — a
   troca da Marvel é o próximo bloco grande (M2).
3. **Robux (M4):** os preços propostos estão no plano; os passes/produtos
   ainda não foram criados no Creator Hub.

## Próximos itens da fila

M1.5.6 painel da torre no celular → M2 marca original (nomes, chefes, mapas,
placas, uniformes) → M3 combate (números de dano, antes→depois no upgrade,
limite por herói, 3x, prévia de onda, entrada do chefe, MVP) → M4 Robux.

## Como reverter

Cada item é um commit pequeno: `git revert <hash>` e depois
`python tools/studio_sync.py <arquivos> --place-id 97132875544830`.
Para pausar o diretor: crie `docs/director/STOP` (pode ser pelo GitHub).
