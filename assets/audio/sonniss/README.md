# Sons Sonniss — seleção do jogo

Os cinco ZIPs fornecidos pelo dono contêm 347 gravações. A seleção usa 52
fontes dos cinco volumes para 56 funções do jogo, com 73 regiões editadas.
Não há necessidade de tocar toda a biblioteca: a escolha acompanha a função,
o material da arma e o espaço disponível no mix.

## Arquivos prontos para enviar

Estão na pasta local `assets/audio/sonniss/rendered/`. São sete WAVs mono,
PCM 16 bits/32 kHz, somando aproximadamente 11 MB. Cada arquivo é um atlas:
o cliente toca somente a região correspondente à ação.

| Arquivo | Campo em Config.Audio | Uso |
|---|---|---|
| sfx_ui.wav | sfxUi | botões, navegação, cartas e árvore |
| sfx_events.wav | sfxEvents | moedas, construção, melhorias, ondas e resultados |
| sfx_summon.wav | sfxSummon | mecanismo da roleta e cinco finais por raridade |
| sfx_combat.wav | sfxCombat | 13 famílias de armas, golpes e poderes básicos |
| sfx_powers.wav | sfxPowers | oito famílias de habilidades do líder |
| sfx_boss.wav | sfxBoss | entradas mecânicas, criaturas, ilusão e derrota |
| sfx_world.wav | sfxWorld | ambientes do lobby e dos seis mapas |

O código não considera um arquivo publicado até existir um ID real em
`src/shared/Config.luau`. Sem esse ID, ou enquanto o Roblox carrega o áudio,
o som anterior continua disponível. A música do lobby foi preservada.

## Envio para o projeto oficial

No Gerenciador de ativos do lugar **97132875544830**, importar os sete WAVs
sem converter para um formato com perda. O dono confirma pessoalmente a
declaração de direitos solicitada pelo Roblox. Após processamento/moderação,
copiar os IDs reais para os sete campos acima e conceder o uso ao universo
**10768165352**, quando necessário. Manter os áudios privados.

Não usar `tools/studio_upload_audio.py` para esse pacote: a versão antiga
confirma automaticamente uma declaração, sem parar para o dono responder.
Os arquivos Sonniss são licenciados; não são gravações próprias do projeto.

A fila de importação foi preparada no Studio da equipe com os sete arquivos.
O envio foi interrompido na janela **Importação de arquivo**, antes de
**Confirmar**. Essa janela declara os direitos de inserção na Roblox e
autoriza o uso nesta experiência. Não houve envio confirmado, cobrança nem
ID obtido. Caso a fila tenha sido fechada, selecionar os sete WAVs da pasta
`rendered/` no Gerenciador de ativos e iniciar a importação novamente.

Estado final da sessão: Studio em edição, janela de direitos aberta para o
dono responder, após publicar código/efeitos às 23:57:05 local de 09/10.
Captura local: `test-results/review/sonniss-rights-final.png`.

Conferir no playtest que os sete Sound.IsLoaded estão verdadeiros, ouvir a
seleção por família e conferir loops e finais antes de publicar. Produção,
envio, autorização e verificação são etapas distintas.

## Origem, edição e reprodução

`manifest.json` registra volume, caminho interno, CRC, hash dos WAVs, região,
início na fonte, duração e ajuste de pitch de cada trecho. Variações combinam
transientes distintos quando disponíveis e pequenos ajustes editoriais de
pitch. Não são 73 gravações originais diferentes.

Para reconstruir no computador do dono (Python, PyAV e NumPy):

```powershell
python tools/prepare_sonniss.py --source "D:\Downloads google\audios sfx para games"
```

Os trechos isolados para escuta ficam em `audition/`. O índice usado pelo
jogo é `src/client/SoundBank.luau`, gerado junto com os atlases.

Licença consultada em 09/10/2026:
[Sonniss GDC Bundle License, versão 2, de 27/08/2026](https://sonniss.com/gdc-bundle-license/).
Ela permite integrar e editar os sons em jogos, mas proíbe redistribuir a
biblioteca como arquivos de áudio independentes. Por isso os WAVs e trechos
ficam fora do Git público; só receitas, metadados e código são versionados.
