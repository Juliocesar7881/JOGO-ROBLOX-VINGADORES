# Entrada, arte fiel ao jogo e recrutamento — 11/10/2026

## Resultado

A inicialização, a conexão do perfil e as telas de Ouro/XP AFK passam a usar
duas pinturas feitas com referências do lobby e dos modelos reais. A torre
azul com medalhão de estrela, a praça circular, o globo orbital, a estação
ciano, as ilhas e os dois heróis mantêm a identidade do jogo. O acabamento
de luz e materiais é ilustrado; a geometria dos personagens continua
deliberadamente simples, como a versão jogável.

O recebimento mostra o modelo 3D verdadeiro do prêmio: entrada curta,
pose própria do herói, aro da raridade, partículas discretas e ficha com
nome, novidade ou conversão do repetido. O botão Continuar já está
disponível. Depois da roleta não há segunda abertura de baú, clarão ou
repetição da fanfarra. Bases também recebem seu próprio modelo real.

## Correção da primeira entrada

O defeito estava na sequência `Lobby sem perfil → Lobby com perfil`. O
cliente considerava que o layout não havia mudado e mantinha a tela de
carregamento, embora o servidor já tivesse entregado o perfil.

- O primeiro perfil força a reconstrução da tela, mesmo na mesma fase.
- `DoomReady` só é sinalizado depois de montar o HUD de verdade.
- Um `Sync` inicial suspenso não bloqueia a tentativa independente seguinte;
  no máximo duas chamadas de leitura ficam pendentes. Um evento `State`
  também pode concluir a entrada. Respostas antigas sem perfil são ignoradas.
- O carregador inicial sai quando o HUD está pronto, sem esperar imagens,
  áudio ou replicação opcional. O prazo de segurança de 60 segundos continua.
- Imagem ausente ou lenta mantém apresentação nativa e modelos do jogo,
  sem ser requisito para entrar ou receber uma recompensa.

Os testes reproduzem a primeira resposta suspensa, o perfil atrasado tanto
por `Sync` quanto por `State`, a fase inalterada e uma resposta antiga
chegando depois da prontidão. Também exercitam configuração/imagem atrasada
e prontidão anterior a `game:IsLoaded()`.

## Artes e aplicação

Geradas pela ferramenta integrada **image_gen**, a partir da vista real do
lobby e dos retratos reais. Os prompts completos, referências, arquivos e
hashes estão em
[`refuge_v2_provenance.json`](../assets/ui/illustrated/refuge_v2_provenance.json)
e no manifesto de arte. Nenhum texto ou botão foi gravado na pintura:
localização, progresso, pagamentos e ações continuam nativos.

| Uso | Fonte | Entrega Roblox | ID importado |
|---|---|---|---|
| Inicialização/conexão | `assets/ui/illustrated/launch_refuge_v2.png` | `roblox/md_launch_refuge_v2.png`, 1024×576 | `113377652302568` |
| Ouro/XP AFK | `assets/ui/illustrated/afk_refuge_v2.png` | `roblox/md_afk_refuge_v2.png`, 1024×576 | `126038966446275` |

Ambas foram importadas na conta usada pelo lugar oficial e confirmadas
carregadas no Studio. A pintura fica desenhável durante o download;
`IsLoaded` e o resultado assíncrono de `PreloadAsync` podem completar a
troca. Ao aparecer, ela oculta os modelos de reserva, evitando personagens
duplicados. Em formato vertical o recorte preserva a região dos heróis.
As conexões de acompanhamento são desligadas ao concluir ou destruir a tela.

O observatório anterior fica arquivado e deixa de ser usado nessas telas.
Coleção, ficha, invocação e recompensa continuam usando os retratos dos
modelos reais, em vez de substituir personagens por uma ilustração genérica.

## Som e animação

Os cinco finais aproveitam os bancos Sonniss já publicados e carregados:
comum curto; raro com acento mecânico; épico com textura mágica; lendário
com impacto grave; mítico com textura de energia. A melodia da raridade
toca uma vez; o acento é uma camada discreta em canal separado, com duas
vozes no máximo. A música reduz brevemente de volume durante a recompensa.
Mute e cancelamento também eliminam camadas ainda agendadas.

A apresentação usa entrada e acomodação pequenas, seguida da assinatura
do herói, com atualização de pose limitada a 30 Hz. Menos efeitos mantém
a pose estável e remove as partículas. Chat e campo de digitação se
escondem durante roleta/recibo para não cobrir o prêmio.

## Verificação

| Aceite | Evidência |
|---|---|
| Suíte completa | `tools/test.py` exit 0 antes do commit de código, 75,33 s no total; seis roteiros completos do cliente, 1.211–1.217 verificações por roteiro |
| Primeira entrada | Casos de ordem de chegada, tentativa independente, resposta antiga, prontidão e imagens atrasadas aprovados; novo playtest entrou com `DoomReady`, sem cobertura restante |
| Arte no cliente real | Dois IDs carregados; inicialização, conexão e Ouro/XP AFK fotografados no Studio |
| Layout | Nove cenas em PC, horizontal PT e vertical EN; três rodadas com saída 0 e sem cortes de texto ou erros detectados |
| Recibos em telas pequenas | Seis capturas repetidas após estabilização do formato; existência, visibilidade e botão confirmados no cliente |
| Áudio nativo | Cinco regiões distintas carregadas e reproduzindo; uma fanfarra por raridade, acento separado, cancelamento e mute aprovados |
| Baú ganho real | Baú gratuito: roleta, recibo com modelo e chat oculto, Continuar; contagem de baús 0→1 e exatamente uma fanfarra de raridade |
| AFK real | Personagem na plataforma de Ouro, pintura carregada, Mostrar jogo e Voltar ao lobby por cliques reais |
| Recrutamento no PC | 60 FPS, p95 17,97 ms, pior quadro 22,67 ms em 6 s; 361 quadros, RTX 4060 Ti |

As primeiras capturas rápidas dos recibos em telas pequenas não mostraram
a apresentação completa; não foram usadas como evidência visual final.
As capturas substitutas verificam o componente presente antes da fotografia.

Evidências em `test-results/recruitment-entrance/`. A galeria separada no
Desktop é `Multiverse_Recrutamento_Entrada_2026-10-11/INDICE.html`.
Os arquivos incluem capturas do jogo, pinturas originais e prompts completos.

## Escopo e limites

Conferência no Studio com perfil temporário, sem alterar perfis salvos.
Uma nova entrada do cliente publicado com DataStore/rede reais e o toque
em aparelho físico ainda fazem parte do checklist de lançamento. As
capturas de celular são revisões de layout, não medição de dispositivo.
Anatomia do elenco e peso dos ataques continuam em M22.7/M22.9.

Notas da régua para esta entrega: leitura 4, acabamento de UI/arte 4,
consistência 4, clareza 4, recompensa 4 e desempenho PC 4. O conjunto de
combate continua 3, com as pendências anteriores preservadas; a pintura
não certifica acabamento de todos os modelos jogáveis.

## Entrega

Código **`b9e022a`** enviado ao `main`, com sincronização seletiva de oito
fontes no place **97132875544830**. As 40 fontes foram comparadas antes e
depois de refazer o preview, preservando o prefixo de papel já existente no
servidor. Lobby salvo com 4.433 peças, dentro do teto de 4.500.

Publicado nesse mesmo lugar da equipe em **11/10/2026 às 15:44:01 local
(18:44:01 UTC)**. O log confirmou `Go to PublishSuccessful` às
18:44:00.880 UTC. Registro em
`test-results/recruitment-entrance/publication.json`, também copiado para a
galeria do Desktop. Studio deixado em modo de edição.
