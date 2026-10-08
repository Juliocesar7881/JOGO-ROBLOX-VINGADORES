# Direção de arte

Referência de produção do Multiverse Doomsday. A assinatura é **heróis com
personalidade, defesa em equipe e uma ilha tecnológica acolhedora**. A arte
precisa comunicar o jogo na câmera do jogador; quantidade de peças não é
critério de acabamento. Os arquivos Luau são a fonte de verdade.

## Identidade e referências

Aventura de quadrinhos, com anatomia estilizada de Roblox, silhuetas fortes,
cores de uniforme e equipamento reconhecível. Preserve os nomes atuais do
catálogo e a política de conteúdo do projeto. Nenhum logotipo oficial.

Referências: capturas e vídeos enviados pelo proprietário, com estudos
anteriores registrados em `docs/director/REFERENCE_TTD.md`; tower defenses
como referência de clareza, portais e evolução. As imagens fornecidas pelo
dono mostram placas com vistas de mapas, unidades grandes e navegação
simples. Não se afirma ter jogado os títulos ou assistido novamente às
gravações nesta rodada. Tutorial por setas, sem mascote ou personagem guia.

## Personagens

- Rig articulado: raiz, tronco, cabeça, braços, mãos, pernas e pés, com
  Motor6D. A animação do cliente não altera a simulação do servidor.
- Massa vem de proporções: grandalhão com cabeça menor, peito largo e braços
  pesados; herói orgânico alto e estreito; atirador pequeno com mãos e arma
  proporcionais. Não aumentar todos os eixos de um boneco genérico.
- Ombros, cintura, mãos e pés precisam de desenho; acessórios soldados à
  articulação correta. Preserve pivôs, alcance, colisões e emissão.
- Diferenciar chefes pelo corpo, postura e equipamento, incluindo capa,
  focinho, cauda ou espinhas quando fizerem parte do personagem.
- Equipamento, roupa e pose devem tornar a melhoria perceptível na partida.
  Emblema ou aura repetida não substitui evolução própria da unidade.
- Rostos e cores de família legíveis sem depender do nome flutuante.

## Materiais, iluminação e paleta

| Função | Tratamento |
|---|---|
| Pele e uniformes | Cores sólidas, SmoothPlastic, pequenos detalhes de acabamento |
| Armadura e arma | Metal; reflexo controlado, atualmente até 0,06 nas armaduras brilhantes |
| Orgânico e rocha | Wood e Slate aplicados por personagem, com facetas e formas próprias |
| Arquitetura | Concreto, pedra e metal, com texturas em escala coerente |
| Vidro | Glass transparente; sem transformar paredes e cercas em lâmpadas |
| Energia | Neon em bordas, olhos, emissão e segmentos curtos |

Tinta escura, azul profundo, pedra clara, verde da vegetação e mar turquesa
formam a base. Dourado e ciano indicam tecnologia; outras cores identificam
distritos e funções. Não aplicar todas as cores de raridade ao cenário.
Bloom limitado a 0,2. Materiais texturizados não devem esconder o desenho do
rosto ou produzir ruído em todos os uniformes.

## Lobby

Caminhos claros entre partida, equipe, evolução, invocação, arena e AFK.
Cada área tem marco e cor funcional, com espaço de circulação. Placas de
mapa ficam acima dos portais e mostram uma vista do mapa; decoração não
recebe títulos flutuantes. Reduzir competição entre placas e fontes de luz.

Toda estrutura física deve mostrar como se sustenta: bases em contato com o
chão, pontes com pilares, placas com suportes e vitrines montadas na
arquitetura. Hologramas e nave podem flutuar intencionalmente; pilares de
concreto não. Cenário sólido, sem props bloqueando pontes, filas ou cliques.
Apoios e circulação são testados. Teto atual: 4.500 peças no lobby.

Trabalhar composição e formas inclinadas antes de acrescentar adornos.
Avaliar chegada, passagem e distritos na altura do jogador. Uma vista aérea
não demonstra travessia. O movimento é local, limitado e respeita Menos
efeitos: árvores, bandeiras, hologramas e nave não precisam animar juntos.

## Interface e combate

Fredoka One nos destaques, Builder Sans no apoio; canvas lógico 1150x640,
UIScale e utilitários UI.fit/UI.oneLine. Português e inglês, no locale.
Verde confirma, vermelho comunica perigo, dourado comunica Ouro. Custos,
requisitos e resultados têm hierarquia própria.

O centro e o horizonte pertencem à batalha. Separar comando e núcleo em
telas largas; reduzir informações secundárias e limitar avisos sobre
unidades. Dois botões rápidos de melhoria no máximo, priorizando seleção.
Personagens continuam selecionáveis pelo modelo. Toque precisa de espaço
suficiente, rolagem e seleção não podem se perder ao atualizar estado.

Ataque: preparar, orientar, emitir da mão/arma, acertar e recuperar. Feixes
com núcleo fino, explosões e poderes com ondas vazadas, cores do herói e
pouca luz branca. Respeitar limite compartilhado de 80 efeitos e Menos
efeitos. Apresentação segue os eventos do servidor.

## Som e avaliação

Armas, golpes, controle e magia têm timbres e ritmos próprios, com volume,
distância, repetição e número de vozes limitados. Equalização deve voltar ao
perfil neutro quando uma voz é reutilizada. Música e efeitos independentes.
Lobby mantém sua trilha; combate usa o arranjo de ação existente.

Os doze WAVs em `assets/audio/refined/` são fontes produzidas, ainda sem
integração publicada. Envio, declaração de autoria do dono e moderação são
necessários. Nunca apresentar mistura de assets antigos como nova gravação.

A revisão atual do catálogo está em `REFINAMENTO_DIRECAO_2026-10-08.md`:
43 heróis inspecionados, acabamento ainda 3/5. Finalizar uma amostra de
anatomia, movimento, inimigo e combate antes de replicá-la. Testes verdes não
substituem inspeção visual, escuta, celular real ou quatro jogadores.
