# Configurar e testar a versão da sua conta

## Desde 15/10/2026: um lugar só, várias batalhas (`Config.SinglePlace = true`)

Não é preciso criar um segundo lugar. O place publicado (97132875544830)
funciona como dois tipos de servidor (`Rules.PlaceRole`):

- **servidores públicos** (e servidores privados de dono) são **lobby**;
- **cada batalha** roda num **servidor reservado do mesmo place**, que o lobby
  reserva quando a contagem do portal termina (`TeleportService:ReserveServer`).

Quem chega ao lobby nunca espera a batalha de outro grupo acabar. Se o Roblox
não conseguir reservar ou teleportar, o próprio lobby roda a batalha (como o
servidor único fazia antes). O código de acesso do servidor reservado fica só
na MemoryStore (assentos de reconexão, inclusive depois de "Jogar de novo"),
nunca nos dados de teleporte. Quem volta ao lobby junto (até 2 s de diferença)
viaja no mesmo teleporte e cai no mesmo lobby. No Studio tudo continua num
servidor só (teleporte não funciona em playtest). Testes:
`tests/test_server_travel.py` (lobby e batalha com DataStore/MemoryStore
simulados) e `tools/test_rules.luau` (todas as combinações de papel).

O modo de dois lugares separados abaixo continua disponível: preencher
`LobbyPlaceId` e `MatchPlaceId` com lugares diferentes tem prioridade sobre o
`SinglePlace`.

## Música de batalha por mapa (Creative Commons BY)

Cada mapa tem a sua faixa. As seis são Creative Commons BY: uso comercial
liberado, desde que o autor seja creditado. O jogo mostra os créditos em
Opções para cada faixa que estiver em uso (`Catalog.MusicCredits`).

| Mapa | Faixa | Autor | Licença |
|---|---|---|---|
| Ruas de Manhattan | Chase | Alexander Nakarada (CreatorChords) | CC BY 4.0 |
| Complexo Gama | Checkpoint | Hayden Folker | CC BY 3.0 |
| Fundição Sombria | Pursuit | Hayden Folker | CC BY 3.0 |
| Selva de Cristal | Pirates of the Quarantine | Alexander Nakarada (CreatorChords) | CC BY 4.0 |
| Cidadela do Tirano | Storm | Keys of Moon | CC BY 4.0 |
| Ponte Celeste | Valhalla | Alexander Nakarada (CreatorChords) | CC BY 4.0 |

1. `python tools/prepare_music.py` gera `assets/audio/licensed_music/battle_<mapa>.ogg`
   (fora do git), já com o silêncio das pontas cortado, volume igualado em
   -16 LUFS e fade para o loop. Os créditos e o hash de cada arquivo ficam em
   `assets/audio/music_credits.json`.
2. **Dono:** enviar os seis OGGs como Áudio (Creator Hub > Creations >
   Development Items > Audio, ou Studio > Gerenciador de ativos > Importação
   em massa). O envio pede a sua confirmação de que você tem o direito de
   usar o áudio. A licença CC BY dá esse direito com crédito ao autor.
3. Colocar cada ID em `Config.Audio.battle<Mapa>`. Um mapa com 0 toca a
   faixa geral `battle`. Uma faixa que não carregar (moderação) também
   volta para a geral, e depois para o arranjo próprio.

O "rock instrumental" de autor desconhecido ("no rights") ficou de fora:
sem autor e licença identificáveis, não dá para declarar o direito de uso.

## Códigos promocionais sem publicar (Experience Configs)

Um código por vídeo ou canal, criado no Creator Hub, sem gerar nem publicar o
lugar de novo:

1. Creator Hub > a experiência > **Configs** > criar a chave `codes`, tipo
   **JSON**.
2. Valor (exemplo): `{"VIDEO1": {"gold": 300, "chest": "rare", "expires": 1798761600}}`.
   Campos aceitos: `gold` (0 a 10.000), `xp` (0 a 5.000), `chest` (um baú do
   `Catalog.Chests`, por exemplo `rare`) e `expires` (segundos Unix UTC). O
   nome do código: só letras e números, 3 a 32 caracteres.
3. Publicar as configs. Os servidores abertos leem a mudança sozinhos
   (`UpdateAvailable`); o jogador digita em qualquer caixa, com ou sem acento.

Uma entrada malformada não vira código e aparece no aviso
`[Doomsday] Config codes skipped: ...` (validação em `Rules.ConfigCodes`). Os
códigos de `src/server/Codes.luau` continuam valendo; uma chave igual na config
substitui a do arquivo. Cada conta resgata cada código uma vez.

## Lugares separados (opcional)

O jogo local está em `dist/Doomsday-Studio.rbxlx`. Os arquivos Lobby e Match
devem ser publicados em dois lugares distintos da mesma experiência.
Não substitua uma sessão aberta com alterações não salvas: salve essa sessão
separadamente e depois abra o arquivo reconstruído.

## IDs e pacote

Desde 12/10/2026 os 51 produtos (41 heróis, cinco passes, cinco consumíveis),
os sons e as fotos dos mapas já estão em `src/shared/Config.luau` com IDs
reais. O `deployment/local.json` só precisa do que ainda não está lá: o
universo e os lugares. Um `0` no JSON significa "não mexer": o gerador mantém
o valor do `Config`, nunca o zera.

1. Copie `deployment/template.json` para `deployment/local.json`.
2. Preencha `UniverseId` (10768165352), `LobbyPlaceId` (97132875544830, o
   lugar atual) e `MatchPlaceId` (o lugar novo publicado a partir de
   `dist/Doomsday-Match.rbxlx`, na mesma experiência). `AfkPlaceId` é opcional.
3. `Products`: deixe em `0` para manter os IDs do `Config`. Só preencha se
   criar um produto novo (um pacote, um passe de temporada) ou trocar um ID.
   Em `Products.Heroes`, cada personagem pago usa um Developer Product próprio.
   Os nomes das chaves precisam permanecer iguais aos do template.
4. `Audio`: deixe em `0` para manter os sons já enviados. Preencha só o que
   reenviar (por exemplo, uma trilha `battle` nova aprovada pela moderação). O
   preço exibido pela loja continua vindo da plataforma; a configuração
   contém IDs, sem substituir preços por valores inventados.
5. As seis fotos dos portais já estão importadas na conta LoopsDev7881 e
   configuradas em `Config.MapImages`. Originais e IDs ficam em
   `assets/map-photos/manifest.json`. Em `deployment/local.json`, `MapImages`
   com `0` ou ausente preserva essas fotos; um ID positivo substitui a foto
   daquele mapa. Para refazer uma foto, use
   `python tools/studio_map_photos.py <mapa> --window-handle <janela do Studio>`.
6. Opcional: coloque em `GroupId` o ID do grupo do jogo no Roblox. Com `0`,
   o prêmio "Entre no grupo" simplesmente não aparece; não é pendência.
   Códigos promocionais ficam em `src/server/Codes.luau` (só no servidor).
7. Execute:

```powershell
python tools/test.py
python tools/release.py --config deployment/local.json --check
python tools/release.py --config deployment/local.json --output dist/release
```

O gerador aplica os IDs somente aos arquivos produzidos. Não altera o balanceamento
nem os fontes. Rejeita IDs inválidos, produtos duplicados e lugares iguais.
`build-manifest.json` registra hashes dos fontes, artefatos e configuração.
Ele não verifica a propriedade dos IDs no Roblox; o teste publicado faz isso.

Para gerar uma prévia privada com IDs incompletos, acrescente `--private`.
O relatório identifica as lacunas e marca `cloudValidated=false` explicitamente.
Não trate essa prévia como aprovação para lançamento.

## Teste publicado da integração

Publique primeiro com acesso restrito. Use contas de teste autorizadas e registre
o resultado real, a versão, o dispositivo e eventuais mensagens de erro:

| Cenário | Resultado necessário |
|---|---|
| Novo jogador | Tutorial, dois heróis, recompensa e compra de baú funcionam |
| Dois e quatro jogadores | Grupo viaja junto e mantém dificuldade/limites corretos |
| Cinco mapas | Rotas visíveis correspondem ao movimento dos inimigos |
| Campanha, Ranqueado e Cartas | 50 ondas; chefes 10/20/30/40 e final 50 |
| Coleta | Manual e drone preservam o mesmo orçamento de Ouro |
| Reentrada em até dois minutos | Torres/Energia/recompensas não duplicam |
| Recibo repetido | Produto entrega uma única vez, com gravação confirmada |
| Falha de DataStore | Perfil existente não é substituído; recibo fica pendente |
| Placares | Melhor marca e separação por mapa/grupo/temporada persistem |
| Celular real | Toque, joystick, rolagem, áreas seguras, FPS e memória aprovados |
| Áudio | Todos os assets autorizados carregam e os dois mutes são independentes |

Teleporte exige teste no aplicativo Roblox com lugares publicados; não funciona
no playtest normal do Studio. [Documentação oficial](https://create.roblox.com/docs/projects/teleport).

`tools/studio_combat_review.luau` instala uma cena descartável com 24 heróis,
inimigos, efeitos e medição de quadros. `ReviewEnemyCount=180` testa o limite
visual. Isso não mede celulares nem simula quatro conexões reais.

A decisão de identidade pública e a permissão de uso da marca/personagens
continuam sob responsabilidade da conta proprietária. Não publique comercialmente
uma versão Marvel sem resolver essa dependência.


## Lugar AFK (opcional)

`python tools/build.py` também gera `dist/Doomsday-Afk.rbxlx`. Para ativar o
servidor AFK dedicado: publique esse arquivo como um lugar a mais da mesma
experiência e coloque o ID em `AfkPlaceId` no `deployment/local.json`. Com
`AfkPlaceId = 0` (padrão), o farm AFK continua só nas salas do lobby e o botão
"SERVIDOR AFK" não aparece.

No lugar AFK todo jogador presente recebe o farm escolhido (Ouro ou XP) por
minuto confirmado; a cada 15 minutos o servidor o transfere para um servidor
AFK novo. **Isso ainda precisa de teste publicado de pelo menos uma hora**
sem interação, no aplicativo Roblox: o Studio não faz teleportes, e a API não
garante que a transferência evita a desconexão por inatividade.
