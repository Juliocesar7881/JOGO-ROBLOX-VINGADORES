# Relatório da manhã — 01/10/2026 (atualizado 13:00)

Tudo está no GitHub `main` e sincronizado no lugar da equipe
(place 97132875544830). **Nada foi publicado ao vivo.**

## O que aconteceu

- 23:56–01:15 trabalho contínuo; 01:15–07:30 parado pelo limite de uso.
- 07:30–09:07 sessão principal: marca original, combate, Robux (código),
  treino do novato, perigos por mapa.
- 12:34 em diante: **as rodadas agendadas agora abrem sessão sozinhas**
  (esta é uma delas, `run-20261001-1234`; pegou a trava velha da sessão
  principal).

## Entregue (33 commits desde 23:56)

| Commit | O quê |
|---|---|
| 7a0dc3d, ac954b9, a79ec4d, e013a39, 53a47b9 | Infra do diretor: trava, skill, revisão de telas no Studio **sem editar scripts do lugar**. |
| 9a774e9 | Câmera da partida abre de cima do mapa. |
| 56d19ff | Barra de heróis estilo TTD (retrato, número, preço; 5 espaços no celular). |
| 3f2fdfc, a401530, bae208f | Chat à direita; "ONDA 20 / 50" cabe; INVOCAR visível no celular. |
| 2dc8b53 | **JOGAR DE NOVO** no fim da partida (voto no servidor). |
| f4d446d, 8f1c068 | Painel da torre com **antes → depois** de cada atributo, vindo do servidor. |
| 57d46fa, 35d803d | Cliente dividido: `Panels.luau` e `LobbyWorld.luau` (init.client 200 → 114 KB); o teste de boot descobre módulos novos sozinho. |
| e0618cc, e41a60e, 1286501 | **Marca original**: heróis, vilões, mapas, conquistas, código MULTIVERSO; 36 uniformes com visual próprio; `test_ip_safety` na suíte. |
| 3cc9b47 | Números de dano por golpe. |
| 2c232ef | Robux (código): passe 3x, pacote inicial, pacote de 30k Ouro. |
| 371f7bd | Chegada do chefe com câmera + banner de fase. |
| 474f01a | Tela final com MVP e placar do grupo. |
| 770ba42 | Limite por herói por raridade (8/6/5/4/3), contador no ladrilho. |
| 9747feb, 80c42c8, 087dbab | Ímã de moedas igual ao servidor; aviso de chefe a 3/2/1 ondas; tiros em lote (menos rede no 3x). |
| 8825e22, f61c957 | **Novato**: um toque em COMEÇAR TREINO, treino de 12 ondas (~7,5 min), botão pulsando. |
| ab705a2, e3325f9 | **Perigo telegrafado por mapa** (surto tóxico, forno, cristais, rajada, selo). |

Notas da régua (antes → depois): barra de heróis 2 → 4; câmera 2 → 4;
baús no celular 3 → 4; fim de partida 3 → 5; painel da torre 2 → 4.
Capturas em `test-results/review/` (lobby, newcomer, match, boss, finish,
versões `-phone`). Auditoria em `docs/director/AUDIT.md`.

## Precisa de você

1. **Robux (M4.2, BLOQUEADO):** criar passes/produtos no Creator Hub exige o
   Chrome com a extensão Claude conectada e logado. O código já está pronto;
   faltam só os IDs em `deployment/local.json`.
2. **Áudio (M7.1):** enviar os WAVs de `assets/audio` no Creator Hub (mesmo
   motivo).
3. **Marca:** confirme os nomes originais dos heróis em `docs/HEROES.md`.

## Próximos itens da fila

M1.4b dividir `MatchHud.luau` → M5.2 Normal/Difícil/Pesadelo → M6.1 curva de
raridade (Juba e Geada fortes demais; Sombra e Guaxo fracos) → M6.2–M6.4
progressão → M9.1 desempenho.

## Como reverter

Cada item é um commit pequeno: `git revert <hash>` e depois
`python tools/studio_sync.py <arquivos> --place-id 97132875544830`.
Para pausar o diretor: crie `docs/director/STOP` (pode ser pelo GitHub).
