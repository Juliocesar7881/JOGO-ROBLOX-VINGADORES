# Fontes de áudio refinadas

12 WAVs originais gerados por `python tools/generate_refined_audio.py`.
Não usam gravações, amostras ou melodias externas. O manifesto registra
formato, duração, pico e SHA256. `assetId: 0` significa **não enviado**.

- `lobby`: cordas suaves, notas dedilhadas espaçadas e vento; 50,526 s.
- `battle`: percussão grave e cordas, sem sequência constante de sinos; 36,923 s.
- `click`, `open`: toque tátil e deslocamento curto da interface.
- `collect`: ressonância metálica curta.
- `place`, `upgrade`: encaixe mecânico e carga que termina em confirmação.
- `shotTech`, `shotArrow`, `shotMagic`, `shotMelee`, `shotBlast`:
  cinco materiais distintos para ataques e habilidades.

## O que já funciona no jogo

O mix do jogo atual usa os IDs existentes de `Config.Audio`: volumes menores,
coleta curta, posicionamento mecânico, habilidades por família, limite de vozes,
distância e variação leve. Os WAVs desta pasta ainda **não** são as gravações
ouvidas no Roblox. Os arquivos e IDs antigos permanecem preservados.

## Ativar os novos arquivos

1. O proprietário importa estes WAVs no Gerenciador de ativos do universo
   `10768165352`, confirma pessoalmente a declaração de autoria e aguarda a
   disponibilidade/moderação. Não executar o uploader automático que confirma
   essa declaração por conta própria.
2. Registrar os novos IDs e suas origens em um manifesto de uploads desta
   pasta; substituir somente as 12 entradas correspondentes em
   `src/shared/Config.luau → Audio` e `deployment/local.json → Audio`.
   Os IDs configurados só podem ser números reais concedidos pela plataforma.
   O manifesto antigo corresponde aos arquivos antigos: preservar ambos.
3. Após enviar `collect`, `place` e `upgrade`, habilitar essas gravações diretas
   em `Config.DirectAudioCues = { collect = true, place = true, upgrade = true }`.
   Isso troca o remix de compatibilidade pela gravação específica. Os demais
   arquivos usam as mesmas chaves existentes e passam a funcionar pelo ID.
4. Rodar a suíte, sincronizar os módulos necessários no lugar da equipe e
   conferir som, volume e repetição numa partida antes de publicar.

`tests/test_release.py` atualmente confirma que o manifesto antigo e os IDs
antigos correspondem. Ao ativar este lote, acrescentar a validação do manifesto
de uploads refinado para comparar os IDs ativos com a origem correta; não
remover a validação de integridade de nenhuma fonte.

Não alterar preços, passes, recompensas ou configurações públicas para enviar
áudio. O envio depende apenas da autoria e disponibilidade dos arquivos.
