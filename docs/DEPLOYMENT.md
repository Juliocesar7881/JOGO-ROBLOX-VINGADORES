# Configurar e testar a versão da sua conta

O jogo local está em `dist/Doomsday-Studio.rbxlx`. Os arquivos Lobby e Match
devem ser publicados em dois lugares distintos da mesma experiência.
Não substitua uma sessão aberta com alterações não salvas: salve essa sessão
separadamente e depois abra o arquivo reconstruído.

## IDs e pacote

1. Copie `deployment/template.json` para `deployment/local.json`.
2. Preencha UniverseId, LobbyPlaceId e MatchPlaceId.
3. Crie os quatro passes e os produtos repetíveis na experiência proprietária.
   Em `Products.Heroes`, cada personagem pago usa um Developer Product próprio.
   Os nomes das chaves precisam permanecer iguais aos do template.
4. Importe os 13 arquivos de `assets/audio` e autorize a experiência. Preencha
   `Audio`. O preço exibido pela loja continua vindo da plataforma; a configuração
   contém IDs, sem substituir preços por valores inventados.
5. Opcional: importe as seis fotos `assets/map-photos/*.jpg` no Gerenciador de
   ativos do Studio (botão direito na imagem → copiar ID) e preencha
   `MapImages`, uma por mapa. Com `0`, a placa do portal mostra o diorama 3D
   do mapa; não é pendência. Para refazer uma foto, use
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
