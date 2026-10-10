# Sonniss: direção de áudio e leitura dos efeitos

Pedido: usar os cinco volumes fornecidos no projeto oficial, escolhendo sons
adequados às ações. O trabalho continua no `main` e no lugar da equipe
**97132875544830**, universo **10768165352**.

## O que está entregue e o que depende da conta

| Área | Estado | Evidência / próximo passo |
|---|---|---|
| Inventário dos cinco ZIPs | Implementado | 347 gravações; origem e CRC no manifesto |
| Seleção e edição | Implementado | 52 fontes dos cinco volumes, 56 funções, 73 regiões |
| Sete WAVs privados | Implementado | PCM mono 16 bits, 32 kHz; hashes, duração, picos e formato testados |
| Roteamento por ação, arma e poder | Implementado | `Audio.luau` e `SoundBank.luau`; testes de regiões e substituição |
| Finais de invocação | Implementado | Cinco regiões distintas; um final por resultado, cancelamento e mute testados |
| Limites e fallback | Implementado | Pools limitados; som anterior enquanto o banco não estiver disponível |
| Impactos, tiros de base e regiões vazadas | Verificado no jogo | Nove quadros no Studio, batalha real e aviso de perigo separado do efeito cosmético |
| Upload e permissão dos sete áudios | Bloqueado por dependência identificada | Fila preparada; declaração de direitos exige resposta pessoal do dono |
| Novas gravações audíveis na Roblox | Pendente | Obter IDs reais, conferir carregamento, ouvir transições/loops e publicar |
| Celular físico e quatro jogadores | Pendente | Esta rodada usa Studio no PC e emulação de tamanho |

Os sete campos `Config.Audio.sfx*` continuam **0**. As gravações Sonniss ainda
não estão ativas no jogo. O código e os efeitos podem ser entregues com os
áudios anteriores, sem inventar IDs ou trocar o som por silêncio.

## Direção aplicada

- Interface curta e discreta: confirmação, recusa, abrir, carta e navegação
  da árvore têm funções separadas. Recusas repetidas são limitadas.
- Treze materiais de ataque: golpe leve, pesado, metal, orgânico, movimento
  ágil, teia, flecha, tecnologia, feixe, magia, gelo, fogo e explosão.
  O elenco atual recebe perfis de acordo com arma e função.
- Oito famílias de habilidades. Uma teia que desacelera usa a assinatura de
  teia; controle mágico não herda automaticamente o som de choque elétrico.
- Chefes diferenciam metal, criatura e ilusão. A derrota não dispara duas
  celebrações sonoras sobrepostas.
- Roleta tem mecanismo, cliques e cinco finais por raridade, com interrupção
  do mecanismo antes do resultado. O recibo continua imediato.
- Lobby e seis mapas recebem ambientes próprios; a música do lobby é
  preservada. Este pacote contém efeitos e ambientes, sem nova música de
  batalha. O arranjo de ação existente continua disponível.
- Distância, repetição, variação e orçamento de vozes contêm o mix. Sons de
  chefe e recompensa abrem espaço brevemente na música. Música, Efeitos e
  Interface continuam respeitando as opções do jogador.

Nos efeitos, impactos pesados usam borda expansiva e três fragmentos foscos
com espaçamento global. Poderes confirmados marcam a região com aro vazado;
avisos de perigo dos chefes mantêm área preenchida, contraste e prioridade.
Disparos de base usam feixe fino com emissão e acerto. O teto de 80 efeitos,
Menos efeitos e a autoridade do servidor foram preservados.

## Arquivos e testes

Código: `src/client/Audio.luau`, `SoundBank.luau`, `Effects.luau`,
`init.client.luau` e `src/shared/Config.luau`. Produção:
`tools/prepare_sonniss.py`, `assets/audio/sonniss/manifest.json` e README.
O guard de título de `studio_realclick.py` aceita a capitalização real
“DoomsDay”, mantendo a restrição à janela do Studio e ao diálogo de importação.

`tests/test_sound_bank.py` confere metadados, regiões, integridade do PCM local,
origem nos cinco volumes e exclusão dos WAVs do Git. `test_audio.py` cobre
fallback durante download, seleção de material/poder, limites, finais,
cancelamento, ducking e mute durante reprodução. O cliente verifica que a
área cosmética fica vazada sem enfraquecer o aviso do chefe.

Suíte completa executada com sucesso: `test-results/sonniss-suite-final-review.txt`.
São seis roteiros completos do cliente, compilação Luau, regras, serviços,
contrato de rede, layout e geração de places. Testes automatizados não
substituem a escuta das gravações carregadas na Roblox.

## Conferência no Studio

Cinco fontes finais comparadas com o repositório e sincronizadas apenas no
lugar da equipe. Revisões `wave`, `tower` e `reel` em PC e celular horizontal;
`wave` e `tower` também em vertical 375×667. Português e inglês conferidos;
os roteiros terminaram sem erro de script ou corte de texto detectado.
São emulações de tamanho no PC, não testes em aparelho físico.

Evidências locais:

- `test-results/sonniss/screens/`: telas, incluindo
  `portrait-01-wave-phone.png` e `en-01-wave-phone.png`.
- `test-results/sonniss/fx/`: três quadros consecutivos de cada demonstração
  de feixes, poderes e corpo a corpo. São eventos controlados de revisão,
  exibidos sobre o mar; não representam uma partida real nem um antes/depois
  com enquadramento idêntico às capturas antigas.
- `test-results/review/sonniss-combat80.png`: partida real de Cartas em
  Complexo Gama, cinco heróis e 114 inimigos no snapshot da captura.
- `test-results/sonniss/measure.json`: seis segundos por amostra na
  NVIDIA GeForce RTX 4060 Ti, com os novos bancos ainda desativados.

| Amostra final | Inimigos visíveis durante a medição | FPS | p95 do quadro | Pior quadro |
|---|---:|---:|---:|---:|
| Antes da carga adicional | 5 | 60,01 | 17,61 ms | 18,78 ms |
| Após `server:crowd 80` | 90 | 59,99 | 17,77 ms | 18,36 ms |

Nenhum erro de script na medição. O número do snapshot pode ser maior que
o de modelos renderizados. Esta amostra curta mede efeitos e sons anteriores;
não certifica o desempenho dos sete bancos Sonniss, quatro jogadores ou
memória numa sessão prolongada.

Avaliação desta fatia: leitura 4/5, consistência 4/5, desempenho no PC 4/5.
Acabamento dos modelos e peso das animações continuam 3/5, com trabalho
concreto aberto em M22.7 e M22.9. A qualidade auditiva do novo mix depende
de escuta após upload; não foi classificada como aprovada. O aviso 3D da
base ainda pode atravessar a borda da tela quando a câmera aponta para longe
dele (`sonniss-combat80.png`); tratar a projeção desse aviso em M24.7.

Entrega no `main` e publicação: em fechamento. Os efeitos funcionam com os
áudios anteriores enquanto `Config.Audio.sfx*` estiver em zero.

## Origem e pendência exata

Receitas, fontes, offsets, pitch e hashes estão no manifesto. WAVs/trechos
licenciados permanecem somente no PC, fora do repositório público. Referência:
[Sonniss GDC Bundle License v2, 27/08/2026](https://sonniss.com/gdc-bundle-license/).
O uso de regiões de áudio segue a
[documentação oficial de Sound](https://create.roblox.com/docs/reference/engine/classes/Sound).

Próxima ação do dono: responder à declaração de direitos na janela
**Importação de arquivo**. O plano local determina: “O Studio pede a
declaração de autoria do arquivo, que **só o dono confirma**”
(`docs/PLANO_CODEX.md`, seção 7.2). O diálogo atual pede direitos de uso,
sem afirmar que as gravações foram criadas pelo projeto; a pausa preserva
a confirmação pessoal combinada com o dono.

Depois: copiar os sete IDs reais para os campos indicados no README,
conferir autorização no universo, `IsLoaded`, duração, limites das regiões e
loops; ouvir as famílias em combate e os cinco finais. Rodar a suíte,
sincronizar seletivamente e publicar no mesmo lugar.
