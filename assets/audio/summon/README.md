# Sons de invocação

`reference.mp3` é o arquivo fornecido pelo dono em 08/10/2026:
`CSGO Case + Knife Opening Sound Effect - Nexiz.mp3`. Não é uma gravação
autoral deste projeto. Os trechos de abertura e clique foram separados;
o final do arquivo não é utilizado. Não declarar autoria desses dois trechos.

Os cinco finais são sínteses originais, diferentes em instrumento, notas,
ritmo e duração: confirmação curta (Comum), sinos (Raro), carga digital
(Épico), fanfarra (Lendário) e impacto com acorde amplo (Mítico).

Todos os WAVs são mono, PCM de 16 bits, 32 kHz. Gerar novamente com
`python tools/generate_summon_audio.py` (PyAV e NumPy para decodificar o MP3).
O manifesto registra os hashes, a origem e os limites dos recortes.

## Integração pendente na conta

Os arquivos ainda não foram enviados ao Roblox: `assetId = 0`. O dono
precisa enviar `reelStart.wav`, `reelTick.wav`, `rewardCommon.wav`,
`rewardRare.wav`, `rewardEpic.wav`, `rewardLegendary.wav` e `rewardMythic.wav`,
responder às declarações aplicáveis e permitir o uso pela experiência
10768165352. Depois da aprovação, colocar os IDs nas chaves de mesmo nome
em `src/shared/Config.luau → Audio`, atualizar o manifesto e sincronizar.

O código já aceita esses sete IDs. Cada gravação substitui seu fallback:
não há som de recebimento duplicado. Enquanto os IDs forem zero, a versão
jogável usa gravações próprias já publicadas, com clique mecânico e cinco
assinaturas por raridade. Esse fallback não é o áudio exato do MP3.
