# Áudio original — Última Defesa

27 arquivos WAV, mono, 32 kHz, 16 bits. Composições e síntese próprias deste
projeto, sem samples, gravações, músicas Marvel ou melodias copiadas.

- `lobby.wav`: 48 segundos; tema suave de pátio/floresta, sinos e acordes.
- `battle.wav`: aproximadamente 34,3 segundos; arpejo, baixo e percussão leve.
- `collect`, `place`, `upgrade`, `levelUp`, `victory`, `defeat`, `breach`,
  `ability`, `boss`, `wave`, `chest`: sinais curtos para os eventos do jogo.
- `ambManhattan`, `ambGamma`, `ambHydra`, `ambWakanda`, `ambAsgard`,
  `ambLatveria`: ambientes de 20 s em loop, um por mapa (rua à noite, reator,
  pátio industrial, savana, ponte e fortaleza na neve), tocados baixo sob a
  música da batalha. Ruído filtrado em círculo, sem emenda audível.
- `shotTech`, `shotArrow`, `shotMagic`, `shotMelee`, `shotBlast`: um som por
  família de arma (`Effects.ShotSound`). O jogo toca no máximo 4 por quarto de
  segundo, mais baixo com a distância e nada além de 90 studs.
- `abilityReady`: aviso quando a habilidade do líder recarrega no meio da onda.

As duas trilhas têm caudas circulares para repetição contínua. Os efeitos
têm encerramento suave. O gerador limita picos a 72% da amplitude máxima;
o jogo aplica volumes menores e limita a frequência de reprodução.

Reproduza os WAVs num player local para avaliar a mixagem. Para reconstruir:

```powershell
python tools/generate_audio.py
python tests/test_release.py
```

`manifest.json` registra duração, hash e origem. O teste confere formato,
integridade, amplitude, componente DC e continuidade da borda.

Para ouvir na experiência publicada, importe os arquivos pela conta/grupo
proprietário no Creator Dashboard/Asset Manager, autorize o uso pela experiência
e coloque cada ID em `Audio` no arquivo de implantação. Verifique carregamento
e volume no aplicativo Roblox. [Documentação de áudio](https://create.roblox.com/docs/audio/assets).

A revisão descartável de Studio aceita `ReviewAudio=true` com os WAVs na
subpasta local `content/doomsday-review` da instalação do Studio. Essa prévia
local não publica áudio nem vai no pacote de lançamento. Sem IDs, a versão
normal mantém os efeitos internos de fallback e não toca as trilhas novas.
