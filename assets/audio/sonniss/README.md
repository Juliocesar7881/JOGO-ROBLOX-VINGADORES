# Sons Sonniss — seleção do jogo

Os cinco ZIPs fornecidos pelo dono contêm 347 gravações. A seleção usa 52
fontes dos cinco volumes para 56 funções do jogo, com 73 regiões editadas.
Não há necessidade de tocar toda a biblioteca: a escolha acompanha a função,
o material da arma e o espaço disponível no mix.

## Bancos importados

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

## Ativação no projeto oficial — 10/10/2026

Os sete WAVs foram importados pelo Gerenciador de ativos do lugar
**97132875544830**, com horário de criação **08:41 local**. Os IDs reais
estão no manifesto e em `src/shared/Config.luau`:

| Campo | ID |
|---|---:|
| sfxUi | 85369475902522 |
| sfxEvents | 75724766927443 |
| sfxSummon | 78967956683172 |
| sfxCombat | 106008096538276 |
| sfxPowers | 85187270766836 |
| sfxBoss | 88205770181304 |
| sfxWorld | 140273603492577 |

No cliente real do Studio, os sete bancos carregaram e as **73 regiões**
tocaram dentro dos limites. Foram conferidos os cinco finais da roleta,
encerramento dos trechos, troca de ambiente e mute. A carga de Cartas em
Complexo Gama com 114 inimigos manteve aproximadamente 60 FPS na RTX 4060 Ti.
Isso verifica reprodução e integração; preferência de timbre/volume pelo
jogador e testes em aparelho físico continuam pendentes.

O gerador preserva um ID existente somente quando o WAV reconstruído tem
o mesmo SHA-256. Se os bytes mudarem, o manifesto volta a zero: reimportar
esse banco e atualizar também Config. O teste recusa IDs divergentes.

O registro de 09/10, com importação parada no diálogo de direitos, é
histórico; não repetir o envio desses arquivos já importados. Em novos
uploads, o dono continua respondendo pessoalmente às declarações. Não usar
`tools/studio_upload_audio.py` para confirmar automaticamente direitos de
material licenciado. Sonniss é a origem das gravações, não o projeto.

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
