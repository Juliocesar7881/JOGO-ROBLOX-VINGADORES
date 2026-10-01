# Studio: sincronizar e revisar no lugar da equipe

O lugar da equipe é o **place 97132875544830** (universe 10768165352), aberto
em Team Create no Studio do dono. É o jogo de verdade: tudo que você escreve
lá o parceiro vê. O repositório continua sendo a fonte da verdade.

## Achar a janela

```powershell
Get-Process RobloxStudioBeta | Where-Object { $_.MainWindowTitle -like '*Doomsday*' } | Select-Object Id, MainWindowHandle, MainWindowTitle
```

O handle muda quando o Studio reinicia; sempre consulte de novo. Se só existe
uma janela "Roblox Studio" (tela inicial), abra o lugar sem roubar o foco:

```powershell
$exe = (Get-Process RobloxStudioBeta | Select-Object -First 1).Path
Start-Process $exe -ArgumentList "-task","EditPlace","-placeId","97132875544830","-universeId","10768165352" -WindowStyle Minimized
```

Espere ~60 s e procure de novo. Studio fechado de vez → trabalhe só em código.

## Sincronizar (sempre em modo de edição)

```bash
python tools/studio_sync.py src/server/MatchService.luau src/shared/Catalog.luau --place-id 97132875544830 --window-handle <h>
```

Recusa se o Studio estiver em Play ou em outro lugar. Mande só os arquivos que
mudaram (o cliente inteiro leva ~1 min). Nunca use `--preview-lobby` no lugar
da equipe (apaga o terreno do editor).

## Revisar (Play → cenas → capturas → Stop)

```bash
python tools/studio_review.py --window-handle <h> lobby squad chests match boss finish --phone
```

Usa o modo de revisão embutido (`src/client/Review.luau`, só existe com
`RunService:IsStudio()`), que não altera nenhum script do lugar. As capturas
saem em `test-results/review/<cena>.png` (e `-phone.png`). Abra cada uma com
Read e dê nota. Captura preta ou do tamanho errado = o Studio estava
minimizado/oculto: o script restaura a janela sem ativá-la; tente uma vez mais
e, se falhar, registre e siga sem revisão visual.

Ferramentas antigas `tools/studio_*_review.luau` editam scripts e são só para
cópias locais: elas recusam rodar no place 97132875544830.

## Captura avulsa

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools/capture_studio.ps1 -OutputPath test-results/review/x.png -WindowHandle <h>
```

PrintWindow só da janela do Studio — nunca capture a área de trabalho inteira
(o dono usa outros programas).
