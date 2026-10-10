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

Cinco fontes finais comparadas com o repositório e sincronizadas no
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

Código **`903a157`** no `main`, enviado ao remoto após a suíte completa
(`test-results/sonniss-suite-commit.txt`). Publicação no mesmo lugar
**97132875544830** confirmada pelo log em **09/10/2026 às 23:57:05 local**
(10/10 às 02:57:05 UTC), `Go to PublishSuccessful`.
Registro: `test-results/sonniss-publish.txt`.

Ao preparar o preview, o comando sem lista de arquivos iniciou um reenvio
amplo antes de ser interrompido. A conferência posterior verificou todas as
**37 fontes** iguais ao repositório; o lobby foi reconstruído sem outro
reenvio e manteve o teto de 4.500 peças. Evidências:
`test-results/sonniss-preview-safe.txt` e
`test-results/review/sonniss-edit-preview.png`.
Para próximos lotes, sempre informar os arquivos alterados junto de
`--preview-lobby`: sem lista, `studio_sync.py` sincroniza todos os módulos.

Studio deixado em **modo de edição**, no diálogo pessoal de direitos,
sem confirmar o envio. Captura:
`test-results/review/sonniss-rights-final.png`.
Os efeitos publicados funcionam com os áudios anteriores enquanto
`Config.Audio.sfx*` estiver em zero.

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

## Atualização de 10/10 — bancos reais e ultimates

O estado pendente acima descreve a entrega de 09/10. Em 10/10, às 08:41
local, os sete bancos apareceram importados no Gerenciador de ativos do
mesmo lugar **97132875544830**. IDs reais registrados no manifesto e Config;
mapeamento em `assets/audio/sonniss/README.md`. Nenhum novo lugar criado.

Conferência no cliente real do Studio:

- Sete bancos carregados (`IsLoaded`), com duração correspondente aos WAVs.
- 56 funções / 73 regiões tocadas, dentro dos limites de cada trecho.
- Cinco finais de raridade distintos; todos encerram sem tocar o trecho
  seguinte. Troca de ambiente interrompe o anterior; mute bloqueia novas vozes.
- Disparos e golpes reais observados usando o banco de combate. Uma revisão
  adicional descobriu que o banner de ultimate tocava `Cue("ability")` antes
  do efeito: isso consumia o intervalo mínimo e silenciava o poder correto.
  O banner agora só desenha; `Effects` toca a família do herói. Regressão
  de relâmpago e magia com proprietário/ultimate reais nos seis layouts.
- Depois da correção, cinco lançamentos aceitos pelo servidor e seus FX
  foram conferidos no cliente real: Gigante Furioso, Armadura de Ferro,
  Aranha Urbana, Deus do Trovão e Feiticeira Rubi. O banco de poderes estava
  carregado e reproduzindo a região correta em todos, inclusive os ultimates.

| Amostra de seis segundos | Inimigos visíveis | FPS | p95 | Pior quadro |
|---|---:|---:|---:|---:|
| Antes da carga adicional | 10 | 60,00 | 17,67 ms | 19,11 ms |
| Depois de `server:crowd 80` | 114 | 59,99 | 18,24 ms | 30,72 ms |

PC do dono, NVIDIA GeForce RTX 4060 Ti, Studio, Cartas/Complexo Gama.
Os sete bancos novos estavam carregados. Um dos 34 Sounds era a trilha
antiga `battle`, ainda moderada; o arranjo de ação existente cobre esse caso.
Esta amostra curta não verifica memória prolongada, celular ou quatro jogadores.

Arquivos alterados nesta ativação: Config, manifesto, gerador (preserva ID
somente para PCM idêntico), controlador do cliente (banner), dublê de Sound,
regressões do cliente/IDs e documentação. Não houve mudança de economia,
habilidades, dano ou progressão.

Evidências locais: `test-results/sonniss/activated-loaded.json`,
`activated-probe.json`, `activated-measure.json`, `activated-powers.json`;
`test-results/review/sonniss-activate-ids.png` e `sonniss-active-combat80.png`.
O gerador e testes garantem IDs consistentes e hashes dos sete WAVs privados.
Escuta subjetiva de timbre/volume pelo jogador permanece em M24.8; não é
inferida de `IsPlaying`.

Suíte completa desta ativação: saída **0**, registro
`test-results/sonniss-activate-final-tests.txt`. Inclui 632.736 asserções de
regras/economia, 6.937 checagens de layout e seis roteiros completos do
cliente (965/968 checagens por formato), além de serviços, simulação e builds.
