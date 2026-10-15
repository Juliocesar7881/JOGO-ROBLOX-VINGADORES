# Multiverse Doomsday: o que falta para lançar e estourar

Análise de 14 a 15/10/2026. Place 97132875544830, universo 10768165352.

Como foi feita: 10 auditores (um por eixo) leram o código, os documentos e a
API pública do Roblox; cada falha apontada passou por um verificador que
tentou derrubá-la (as que caíram estão na seção 8); um crítico procurou o que
faltava; uma síntese ordenou tudo. 107 agentes no total.

## Já corrigido em 15/10 (publicado no jogo ao vivo)

| Item da análise | O que foi feito | Commit |
|---|---|---|
| Bloqueador 3: efeitos que cresciam sem parar | O rastro dos projéteis multiplicava o tamanho do quadro anterior a cada quadro: a 240 fps chegava a ~20 milhões de studs (barras de neon atravessando o mapa). Agora cresce a partir do tamanho original; teste novo roda tiros a 240 fps. **Esse defeito tinha ido ao ar na publicação de 15/10 01:59 e foi corrigido e republicado.** | f2f076e |
| Estátua do Capitão "quebrada" | Figurino novo (rosto aberto, capacete verde-água com crista dourada, dragonas e punhos dourados, calça e botas azul-marinho, emblema de asas próprio, escudo grande de anéis virado para a praça, sem estrela). As duas estátuas ganharam pose heroica (repulsor erguido; punho erguido e escudo à frente). Homem de Ferro sem o azul vazando. 3 designers + 3 juízes, renderizador offline novo. | acb62d6 |
| 6: contas restritas (menores no Brasil) sem nenhum pacote | Todas as compras com Robux liberadas para elas (os baús já são fechados a essas contas, então Ouro nunca vira sorteio); VIP não acelera o baú grátis dessas contas. | 61b4384 |
| 7: troca sem a regra do Roblox | A troca segue `IsPaidItemTradingAllowed` (se a regra não puder ser lida, não troca). **Falta você refazer o questionário de maturidade.** | 61b4384 |
| 8: passe da temporada vendido duas vezes | A trilha já aberta não é oferecida de novo; compra repetida vira Ouro; o passe permanente sai da loja para quem não o tem. **Falta você tirá-lo de venda no Creator Hub.** | 61b4384 |
| 9: contador falso no Pacote Inicial | Sem relógio: o banner diz "só uma vez por conta" (o que é verdade). | 61b4384 |
| 10: troca podia duplicar herói | A primeira metade fica "pendente" com cópia do herói entregue e é conferida no perfil gravado do amigo: se a outra metade não entrou, é desfeita na hora ou no próximo login. Testado com falha no meio e com servidor fechando. | 61b4384 |
| 4 (parte de código): braçadeira e letreiros | O chefe de casaco militar perdeu a braçadeira vermelha (risco de moderação); ROXXON e BAXTER viraram ÓRBITA e VOLT ENERGIA (e entraram na lista de termos proibidos); o portal de Manhattan mostra o desenho do mapa em vez da foto com letreiros de terceiros. | 61b4384 |
| Alavanca 1 (parte): faixa do lobby que nunca aparecia | Prêmios esperando e baú com Ouro agora vêm antes do objetivo do servidor (que quase sempre existe). | este commit |

Continua valendo tudo o que está marcado como **Dono** abaixo, e os itens de
código ainda não feitos (lugares separados, treino mais curto, 2x e AUTO
ligados no começo, grupo de amigos, insígnias, códigos sem publicar,
medições). Sobre a marca: a **Armadura de Ferro** continua vermelha e dourada
com reator no peito porque você gostou dela; a análise recomenda trocar a
paleta antes de qualquer divulgação. A decisão é sua.

---

## 1. Veredito

1. **Ainda não está pronto para lançar para crianças.** O motor do jogo, porém, é bem mais sólido que a média do Roblox: o servidor decide tudo, há cerca de 674 mil checagens automáticas, 43 heróis, 6 mapas, 4 modos e a loja é segura.
2. **Nenhuma criança com menos de 16 anos consegue ver o jogo**, porque o alcance está em 16+.
3. **Cada servidor roda uma batalha só.** Quem chega depois fica preso no lobby, inclusive o novato que quer fazer o treino.
4. **A página do jogo não tem nenhuma miniatura real.** O ícone mostra personagens que não existem no jogo, e um deles lembra muito o Hulk. O risco de marca está justamente no que mais aparece: o herói inicial, as estátuas, os chefes e o ícone.
5. **Nada foi testado num celular de verdade nem com uma compra de verdade.** O que mais pesa são os itens 2 e 3, e os dois são trabalho seu no Creator Hub. O código para eles já existe.

---

## 2. Nota por eixo

| Eixo | Nota | Por quê |
|---|---|---|
| Primeiros 5 minutos | 3 | As setas ensinam bem e não há Robux no começo. Mas o treino tem 12 ondas (7,4 min), a base termina com 100/100 de vida, e o primeiro herói novo só chega por volta dos 8 a 9 min. |
| Combate, conteúdo e profundidade | 3,5 | 43 heróis, 6 chefes com mecânica própria e 10 famílias de inimigo. O evento de fim de semana só dobra o Ouro, e a campanha mais curta leva 34 min. |
| Retenção e motivos para voltar | 3 | Login de 28 dias, baú grátis, missões e passe. Falta algo limitado para caçar, e Cartas e Competitivo só abrem depois de 40 ondas. |
| Monetização | 2,5 | Recibos e regras de itens aleatórios estão exemplares. Mas a loja esconde as melhores ofertas, o item mais caro custa 99 R$, contas restritas do Brasil não conseguem comprar nenhum pacote e o passe permanente come o passe por temporada. |
| Visual e arte | 3 | A interface tem identidade própria e cada mapa tem luz própria. Os personagens são de blocos, os efeitos não têm textura e a estátua do Capitão está quebrada. |
| Técnico, celular e escala | 2,5 | Os dados são salvos com muita segurança. Mas há uma batalha por servidor, o desempenho no celular nunca foi medido e o lugar da partida monta o lobby inteiro. |
| Descoberta e página | 2 | Título e gênero estão certos. A página não tem miniatura nem vídeo, o convite está escondido e não há insígnias. |
| Marca, IP e conformidade | 2 | Os textos estão limpos. Os visuais e o ícone estão muito próximos de Marvel e DC, o Pacote Inicial tem um contador falso e o questionário de maturidade está desatualizado. |
| Multijogador e social | 2,5 | O elevador, as votações e a troca segura funcionam. Não existe grupo de verdade, e os amigos se separam ao voltar ao lobby. |
| Live-ops e operação | 2,5 | As rotinas diárias rodam sozinhas e os dados resistem a falhas. Mas nada muda sem publicar, e no dia 1 você ficaria sem enxergar os problemas. |

---

## 3. Bloqueadores antes de lançar

### Bloqueadores duros: sem resolver estes, não adianta divulgar

**1. Crianças não conseguem entrar (alcance 16+)**
- **O que é:** o painel mostra "Public, 16+ e amigos de confiança". As contas Kids (5 a 8 anos) e Select (9 a 15) só enxergam jogos aprovados na avaliação Kids/Select.
- **Por que bloqueia:** é exatamente o público de TTD e Anime Defenders. Hoje, qualquer vídeo para criança leva a um jogo que ela não consegue abrir.
- **Quem faz:** Dono, tudo no Creator Hub.
  1. Verificação de identidade com documento.
  2. Autenticação em duas etapas (2FA).
  3. Taxa reembolsável de 1.000 Robux, ou Roblox Plus/Premium por 2 meses seguidos. A taxa volta se o jogo mantiver cerca de 25 jogadores muito engajados por 60 dias sem moderação.
  4. Uma fase só para 16+, com 250 jogadas únicas de jogadores engajados e de idade verificada em até 60 dias.
  5. A revisão de segurança.
- **Esforço:** pouco trabalho, mas o calendário é longo, de até 60 dias.
- **Atenção:**
  - O `docs/PLANO_LANCAMENTO.md:216` diz que identidade e 2FA bastam. Está incompleto.
  - O painel registra "0/250". Confira o número de novo no Audience Reach.
  - A revisão de 50.000 Robux não é necessária.
- **Prova:** CONFIGURACAO_COMERCIAL_2026-10-12.md:53-57; RELEASE_CHECKLIST.md:14-18; create.roblox.com/docs/production/publishing/kids-and-select.

**2. Um servidor = uma batalha**
- **O que é:** os IDs dos lugares de lobby e de partida estão zerados (Config.luau:12-13), então o servidor roda no modo "Standalone".
  - Quem pisa num portal com outra batalha rodando recebe "Uma batalha já ocupa este servidor", e a contagem reinicia a cada 8 s, sem fim. O botão de treino do novato cai no mesmo laço.
  - A campanha mais curta leva 34 min (out.txt).
  - O "Jogar de novo" recomeça a partida direto, sem passar pela fila, então um grupo pode segurar o servidor sem limite.
  - O servidor público aceita 50 vagas (API).
- **Por que bloqueia:** o primeiro minuto de muitos novatos é um erro repetido. A primeira impressão define o D1 (quantos voltam no dia seguinte).
- **Quem faz:**
  - **Dono (30 a 60 min mais o teste):**
    1. Criar o lugar "Partida" no universo.
    2. Publicar `dist/release/Doomsday-Match.rbxlx` nele e `dist/release/Doomsday-Lobby.rbxlx` sobre o place atual.
    3. Configurar o tamanho do servidor: Partida = 4, Lobby = 20 a 24.
    4. Testar com 1 e com 4 contas reais.
    - Importante: só sincronizar pelo Studio não resolve. O `studio_sync.py` mantém a marca "Standalone" no script do servidor.
  - **Código (pequeno a médio, junto com a separação):**
    - Não montar o lobby no lugar da partida. Hoje ele carrega cerca de 7,4 mil peças em vez de cerca de 2,9 mil.
    - Pôr um botão na tela de carregamento quando o perfil ainda estiver preso em outro servidor. Hoje o servidor desiste em cerca de 15 s e a tela fica para sempre.
    - Pagar o convite aceito dentro da partida, que hoje se perde.
    - Devolver o grupo junto ao mesmo lobby.
    - Manter a reconexão funcionando depois do "Jogar de novo".
- **Enquanto não separar:** baixe o servidor atual para 4 vagas e não divulgue.

**3. Não publicar a mudança local em `Effects.luau`**
- **O que é:** uma edição que ainda não foi commitada estica faíscas, flechas e riscos de habilidade a cada quadro. Na simulação, os riscos de cura passam do limite de 2.048 studs do Roblox, ou seja, viram barras de neon atravessando o mapa. A suíte de testes não pega isso.
- **Por que bloqueia:** o `studio_sync.py` lê os arquivos do disco. O conserto das estátuas que você pediu pode levar esse defeito junto para o jogo publicado e estragar toda partida.
- **Quem faz:** Código. Corrigir o esticamento, criar um teste que meça o tamanho depois de vários quadros, e só então commitar. **Esforço:** pequeno.

**4. Marca e IP antes de qualquer vídeo, miniatura ou anúncio**
- **O que é:** o que mais aparece é justamente o mais parecido com Marvel e DC.
  - O herói inicial **Armadura de Ferro** voltou, em 12/10, para carmesim e dourado com reator no peito. É exatamente o que a regra do próprio projeto proíbe (IP_POLICY.md:12-13), e um teste ainda exige a peça "ArcReactorCore". A edição local deixa a armadura ainda mais vermelha e dourada.
  - O **ícone que está no ar** mostra um gigante verde de cabelo preto e short rasgado (no jogo, o Gigante Furioso é de pedra cinza) e um robô que saiu do catálogo.
  - Os **6 chefes** copiam vilões. O caso mais grave é o Comandante Sombra: cabeça vermelha, casaco militar e **braçadeira vermelha**. Isso é risco de moderação por extremismo, não só de marca.
  - Nos letreiros de Manhattan aparecem "ROXXON" e "BAXTER". A **foto do portal de Manhattan**, que é o primeiro portal de todo novato, mostra AVENGERS, DAILY BUGLE e OSCORP.
  - Há nomes que são tradução oficial de marcas: Laço da Verdade, Explosão óptica, Rei dos Mares, Cavaleiro Lunar, e "Capitão Men", quase igual a Captain Man (Nickelodeon).
  - O título "Multiverse Doomsday" junto com um chefe parecido com o Doutor Destino fica perigoso porque **Avengers: Doomsday estreia em 18/12/2026**.
- **Por que bloqueia:** a revisão Kids/Select observa as denúncias feitas durante a fase 16+. Uma remoção por direitos depois de viralizar zera a receita. Já aconteceu: Anime Adventures foi tirado do ar por DMCA em 2023.
- **Quem faz:**
  - **Dono:** decidir o que muda (nome do Capitão Men, paleta da Armadura, título, ícone).
  - **Código, hoje e em uma linha cada:** apagar a braçadeira, trocar ROXXON e BAXTER, e tirar a foto de Manhattan do portal até haver uma nova (ela já tem um desenho de reserva).
  - **Código, médio:** mudar pelo menos 2 de 3 elementos (paleta, emblema, acessório característico) em cada herói e chefe mais exposto, com testes que impeçam a volta.
- **Sobre as estátuas que você pediu:**
  - A do **Capitão** está quebrada mesmo:
    - a cabeça inteira é verde-água, sem pele nem boca, só duas bolinhas pretas;
    - o escudo fica de perfil para quem vem da praça;
    - o emblema é um disco branco flutuando fora do escudo;
    - a paleta mistura canela branca, pé bronze e ombreira cinza;
    - a pose é de braços caídos.
  - A do **Homem de Ferro**, que você achou legal, é a mais arriscada. Dá para manter a pose e a geometria e trocar só a paleta para azul e branco, com um raio no lugar do reator.
  - Outra sessão está mexendo nesses mesmos arquivos agora. É preciso coordenar para não editarem em paralelo.

**5. A página do jogo está vazia**
- **O que é:** a API pública devolve só o quadrado cinza padrão do Roblox, e a lista de mídia vem vazia. O ícone é uma ilustração, não uma captura do jogo. As capturas antigas (01/10) mostram 36 heróis e raridades que não existem mais.
- **Por que bloqueia:** a taxa de quem clica e entra é o sinal número 1 da descoberta. Pela documentação do Roblox, a personalização de miniaturas só funciona com 2 ou mais imagens ativas e deu em média +8,5%.
- **Quem faz:**
  - **Código:** acrescentar ao `tools/store_media.py` cenas de combate, chefe, poder em tela cheia e equipe, e refazer as capturas.
  - **Dono:** subir 3 a 5 miniaturas, um ícone feito a partir de uma captura real e 1 vídeo autêntico de 15 a 30 s.
- **Esforço:** pequeno a médio. Faça depois do item 4, para não fotografar o que vai mudar.

### Corrigir antes de divulgar: risco de dinheiro, reclamação ou moderação

**6. Contas restritas do Brasil não conseguem comprar nenhum pacote**
- **O que é:** para contas com restrição de itens aleatórios pagos, o servidor recusa todos os pacotes: Ouro, Pacote Inicial, Lendário, Equipe, Passe da Temporada e Ouro em dobro (PlayerService.luau:1359-1361). Nenhum deles entrega sorteio.
- **Por que importa:** pela atualização do ECA Digital, menores de 18 no Brasil são justamente essas contas. Elas são o seu público principal.
- **Outro ponto:** para essas contas, o VIP encurta o tempo do baú grátis, o que equivale a pagar por sorteios extras.
- **Quem faz:** Código, pequeno. Dono: conferir com uma conta de teste brasileira menor de 18.

**7. Troca e questionário de maturidade**
- **O que é:** a troca não consulta a regra `IsPaidItemTradingAllowed` do Roblox (nenhuma ocorrência no código). O questionário de maturidade foi respondido em 12/10, antes de a troca existir.
- **Quem faz, nesta ordem:**
  1. **Código (cerca de 40 linhas):** desligar a troca para as contas sem permissão.
  2. Publicar.
  3. **Dono:** refazer o questionário. Ouro comprado que vira baú conta como item aleatório pago. Herói pago pode ser trocado. Inimigos morrendo o tempo todo provavelmente dão a classificação Mild, que continua liberada para Kids e Select.

**8. Passe da Temporada**
- **O que é:**
  - O game pass permanente (2026575250) custa 49 R$ e aparece na loja ao lado do passe por temporada, também a 49 R$. O permanente libera todas as temporadas.
  - Quem já tem o premium pode pagar de novo e não recebe nada (PlayerService.luau:1419).
  - O herói "exclusivo" da temporada também é vendido direto e sai nos baús.
  - A Temporada 1 acaba em 19/11 (Config.luau:10-11), e chegar ao nível 30 leva cerca de 39 dias (BALANCE.md:155).
- **Quem faz:**
  - **Dono:** tirar o game pass permanente de venda. Quem já comprou continua coberto.
  - **Código, pequeno:** esconder o passe antigo, mostrar "Já é seu", converter compra repetida em Ouro, e alinhar o início de uma temporada com o lançamento para crianças.

**9. Contador falso no Pacote Inicial**
- **O que é:** a loja mostra "Termina em Xh" por 3 dias, mas depois o pacote continua à venda. A política de monetização do Roblox diz: "Don't use a countdown timer that isn't accurate" (não use contador que não seja preciso).
- **Quem faz:** Código, pequeno. Tirar o relógio.

**10. A troca pode duplicar herói**
- **O que é:** se os dois jogadores saem ou o servidor fecha no meio da confirmação, a primeira metade fica gravada e o desfazer é recusado (PlayerService.luau:1028-1040). Os testes não cobrem esse caso.
- **Por que importa:** vídeo de "dupe glitch" viraliza entre crianças e derruba a venda dos heróis de 79 R$.
- **Quem faz:** Código, médio.

**11. Compras reais nunca testadas, produtos sem ícone**
- Nenhuma compra de teste foi feita. Os 55 produtos usam a imagem padrão no aviso de compra.
- **Quem faz:** Dono. Roteiro de cerca de 292 Robux: comprar cada tipo de produto, cancelar uma compra e fechar o jogo logo depois de pagar. Depois, ícones começando pelos passes e pelo Pacote Inicial.

**12. Celular real nunca medido**
- Todo FPS medido até hoje foi num PC com RTX 4060 Ti.
  - O lobby tem 4.536 peças e é baixado inteiro, sem streaming.
  - Uma partida pode ter até 180 inimigos de 23 a 46 peças cada.
  - O jogo não registra quando a qualidade automática é reduzida.
- **Mercado:** cerca de 80% dos usuários diários do Roblox jogam no celular (PocketGamer.biz, relatório anual de 2024).
- **Quem faz:** Dono. Jogar num Android de 2 a 3 GB de RAM e num iPhone antigo, com F9 e Shift+F5 abertos, e anotar FPS e memória no lobby e nas ondas mais cheias. Meta: 30 FPS ou mais. Confira também no Creator Hub se "Console" está marcado: com controle não dá para colocar herói, então desmarque até haver suporte.

---

## 4. Para ESTOURAR: as 10 alavancas, em ordem

**1. Primeiros 10 minutos que prendem**

O que acontece hoje:
- O treino tem 12 ondas e 7,4 min, e a base termina com 100/100: não há tensão nenhuma.
- O cartão "Sobreviva às ondas!" fica parado na tela por cerca de 6 min.
- A tarefa "abra um baú com seus 1.000 de Ouro" nunca aparece para o novato, porque abrir o baú grátis já cumpre a condição dela.
- A faixa "Você tem Ouro para um baú!" e o banner do Pacote Inicial não aparecem em produção, por um erro de ordem (init.client.luau:942).
- As lições têm de 20 a 23 palavras e somem em 4,5 s.
- O passo 4 diz "tecla Q" também no celular.
- Quem entra com um amigo direto na campanha não recebe nenhuma orientação.

O que fazer:
- Treino de 6 ondas em até 3,5 min.
- Botão "ABRIR SEU BAÚ GRÁTIS" na vitória do treino.
- Consertar a faixa do lobby.
- Seta ensinando o 2x e o AUTO.

**2. Sessões que cabem no recreio**
- Manhattan tem 40 ondas e leva 34 min em 1x, e todo perfil novo começa em 1x com o AUTO desligado (PlayerService.luau:113). Com 2x e AUTO ligados, a estimativa é de 14 a 16 min, sem nenhum código novo.
- O modo rápido parou por causa do limite de peças do lobby. Dá para fazê-lo como opção no cartão da fila de um portal que já existe, como a escolha de dificuldade, sem gastar nenhuma peça.
- Liberar Cartas e Competitivo mais cedo.
- **Mercado:** o modo Easy do Tower Defense Simulator tem 20 ondas.

**3. Jogar com amigos de verdade**
- O código de grupo existe no servidor, mas nenhum botão o usa. O grupo só se forma quando os jogadores pisam juntos no mesmo elevador, e um estranho que pisa primeiro manda na partida.
- O convite está escondido no fim da página de Prêmios. Quem convidou só ganha se estiver no mesmo servidor.
- Servidores privados estão desligados (API: `createVipServersAllowed=false`).
- Desde jan/2026 o chat exige verificação de idade, então muitas crianças não conseguem se falar.

O que fazer:
- Fila "Só amigos" e botão "Ir junto".
- Convite visível no portal e no resultado.
- Bônus por jogar com amigo.
- Frases rápidas fixas, sem texto livre.
- Ligar servidores privados.

**4. Conteúdo novo a cada 1 a 2 semanas, com data marcada**
- O evento de fim de semana só dobra Ouro e XP (Catalog.luau:664). O herói de evento e a mutação fixa do plano nunca foram feitos.
- A página promete "Novidades toda temporada", e cada temporada dura 60 dias.
- Para a próxima atualização: eventos com data, painel "Novidades", Experience Updates e Events no Creator Hub, e um "kit" que reduza os 13 arquivos que um herói novo exige hoje.
- **Mercado:** Anime Defenders e TTD atualizam a cada 1 a 2 semanas.
- O Halloween já não dá tempo. O evento-chave é o **Natal**.

**5. Algo para caçar e trocar**
- Todos os 41 heróis estão à venda direto: o elenco inteiro custa cerca de 1.509 Robux.
- O herói "exclusivo" do passe também sai dos baús. Sem escassez, a troca perde valor.
- O que fazer: um herói ou skin de evento **ganho jogando** (fichas de evento), não vendido só por Robux com contagem regressiva, porque a política para menores proíbe pressão.
- **Mercado:** os banners do Anime Defenders duram 14 dias e as unidades somem depois.

**6. Códigos e os seus próprios vídeos como motor**
- Os códigos estão fixos no código: cada um exige publicar e não chega aos servidores já abertos. O "LANCAMENTO" não existe. Os resgates não são medidos. Quem digita "LANÇAMENTO", com acento, recebe "Código inválido".
- Você já produz cerca de 20 Shorts por semana em PT e ES que não mostram o jogo.
- O que fazer:
  - Experience Configs, para criar código sem publicar.
  - Um código por canal ou vídeo, com resgate medido.
  - Share Links nos lugares clicáveis.
- **Creator Rewards (documentação do Roblox):** pagam 35% do que um usuário novo trazido por link ou busca gasta, por 60 dias, limitado aos primeiros US$100. Exige ID verificado, conta DevEx e média de 100 ou mais usuários diários.
- **Mercado:** o jogo só tem pt e en, então quem vem do canal ES cai em inglês. Meça antes de traduzir.

**7. Loja que converte, mais uma decisão sua de preço**

Defeitos:
- Três atalhos ("Comprar Ouro", "Ver pacotes", faixa do Pacote Inicial) abrem a aba errada.
- O botão "Comprar com Robux" do herói abre uma lista de 41 linhas, sem levar ao herói.
- Lendário, Equipe, Passe e Ouro em dobro ficam escondidos na aba Ouro.
- A tela de resultado não mostra nenhuma oferta.

Preço:
- O item mais caro custa 99 R$.
- 79 R$ em Ouro rendem cerca de 3 lendários no Baú Cósmico, contra 1 lendário comprado direto pelo mesmo valor.
- O "Ouro em dobro" corre no relógio, mesmo com o jogo fechado. Numa sessão de 12 min ele vale pouco perto dos 29 R$ (estimativa do verificador).
- **Mercado:** TTD vende gemas até 9.999 R$, e o passe Shiny Hunter do Anime Defenders custa 1.299 R$.
- Os preços baixos foram pedido seu em 12/10. Se for reabrir, o momento é agora, antes de haver compradores.

**8. Efeito "uau" para os vídeos**
- Os efeitos são só blocos de neon, sem textura (nenhum ParticleEmitter ou Beam em `Effects.luau`), e a nota de combate nas notas do próprio projeto é 3/5.
- Os chefes são só 1,26 a 1,57 vez a altura de uma torre. A torre do Gigante Furioso é maior que qualquer chefe. Proposta: escala 2,3 a 2,6.
- Personagens: rostos de bolinhas e as estátuas.
- Fundição e Gama estão apagados, e as fotos dos portais são de 27/09.
- A trilha de batalha está presa na moderação. Suba `assets/audio/refined/battle.wav`, que é síntese própria.

**9. Motivos para voltar vindos de fora do jogo**
- 0 insígnias (API), embora já existam cerca de 15 conquistas internas e o Roblox dê 5 insígnias grátis por dia.
- Não há pedido para favoritar o jogo.
- Notificações só chegam a quem tem 13+ e exigem 100 visitas, então têm prioridade baixa.

**10. Medir para decidir**
- O funil do tutorial tem só 3 passos. Com os lugares separados, os tempos reiniciam a cada viagem entre lugares, e a criança passa a contar como "jogador que voltou" já depois do treino.
- Login, baú grátis, códigos, presentes e troca não geram nenhum evento.
- "ItemViewed" conta cotações de preço, não visualizações, e não se sabe de onde veio o clique.
- O evento de composição de equipe estoura o limite do Roblox (8.000 combinações) e vira "Other".
- As falhas aparecem como avisos com o nome do jogador, o que espalha cada erro no relatório. Recibos pendentes são silenciosos.
- Arrume antes do lançamento: dado registrado errado fica errado.

**Fila seguinte, depois das 10:**
- Ondas temáticas.
- "Fúria" do chefe na fase 3.
- Cartas que mudam regras, e não só porcentagens.
- Mecânica própria para os 12 reforços vendidos por Robux, que hoje saem de um molde.
- Placar semanal da campanha, com aba de amigos.

---

## 5. Plano de 4 semanas

O caminho até as crianças passa pela fase 16+. Estas 4 semanas são essa fase, uma espécie de "teste fechado". O lançamento para crianças, com Shorts infantis e códigos, deve acontecer entre **12 e 19/12**, alinhado às férias escolares (por volta de 21/12) e com a marca já resolvida antes da estreia do filme em 18/12.

**Mercado:** pelo relatório anual 10-K da Roblox, o engajamento cai de setembro a novembro e as vendas são mais fortes no 4º trimestre.

Base de hoje (API): 1 visita, 0 jogando, 1 favorito. Não há nenhuma medição de D1, D7 ou sessão ainda. As metas abaixo marcadas como "plano" vêm de `PLANO_LANCAMENTO.md:235-238`. As marcadas "proposta" são sugestões, sem base medida.

| Semana | O que acontece | Metas |
|---|---|---|
| **0 (14 a 20/10), pré-lançamento** | **Dono:** identidade, 2FA e taxa; criar e publicar o lugar de partida; decisão de marca; tirar de venda o passe permanente; compras reais; teste no celular. **Código:** consertar o `Effects.luau`; braçadeira, letreiros e foto de Manhattan; Armadura e estátuas; contas restritas, troca, contador e passe; duplicação na troca; códigos com acento e "LANCAMENTO"; medições (funil por conta, eventos dos loops, falhas agrupadas, composição de equipe, versão automática); capturas para a página. | Suíte verde; log do servidor com "role=Lobby" e "role=Match", nunca "Standalone"; 100% das compras do roteiro entregues; 30 FPS ou mais num Android de entrada |
| **1 (21 a 27/10), abrir para 16+** | Divulgação só para quem tem 16+: Discord e TikTok de TD, amigos e família verificados. Primeiros minutos: treino de 6 ondas, baú grátis na vitória, 2x e AUTO ligados, faixas do lobby consertadas. | Saída antes de 60 s na primeira partida abaixo de 25% (proposta); D1 de 20% como piso (plano: abaixo disso, corrigir o funil antes de divulgar mais); jogadas engajadas aparecendo no Audience Reach |
| **2 (28/10 a 03/11)** | Social: fila "Só amigos", "Ir junto", convite visível, servidores privados. Modo rápido no cartão da fila. Códigos ao vivo. Painel "Novidades". Primeira atualização pública no sábado. 5 insígnias. | D1 de 25% ou mais (plano); sessão de 12 min ou mais (plano); D7 com linha de base medida; parcela de partidas em grupo medida |
| **3 (04 a 10/11)** | Loja: aba Ofertas, defeitos dos atalhos, decisão de preço. Evento leve com data. Preparação do evento de Natal. Pedido da avaliação Kids/Select quando bater as 250 jogadas. | Conversão de 2% ou mais (plano); D7 de pelo menos 1/3 do D1 (proposta); pico de jogadores simultâneos subindo semana a semana (proposta, sem base); caminho para média de 100 usuários diários, o mínimo dos Creator Rewards |

Regras do plano:
- Não pague anúncio enquanto o alcance for 16+. Anúncios não chegam a menores de 13 e hoje comprariam o público errado.
- O D1 de jogadores 16+ não é o seu público. Não ajuste o tutorial só por esse número.
- Publique no máximo 1 vez por dia no jogo ao vivo, fora do horário das crianças (nunca entre 17h e 21h nem no fim de semana), e reinicie os servidores depois.

---

## 6. O que só você pode fazer

Acesso e conta
- [ ] Verificação de identidade com documento e 2FA
- [ ] Taxa reembolsável de 1.000 Robux (ou Plus/Premium por 2 meses)
- [ ] Conferir no Audience Reach se a meta é 250 jogadas ou 25 jogadores; acompanhar o número
- [ ] Refazer o questionário de maturidade, depois que a correção da troca estiver publicada
- [ ] Pedir a avaliação Kids/Select; mudar para todas as idades só depois de aprovado
- [ ] Criar a conta DevEx (libera os Creator Rewards)

Lugares e servidores
- [ ] Criar o lugar "Partida" e publicar os dois arquivos de `dist/release`
- [ ] Tamanho do servidor: Partida = 4, Lobby = 20 a 24; até separar, o servidor atual em 4
- [ ] Teste com 1 e com 4 contas reais: 5º jogador recusado, cair e voltar, falha de viagem, volta ao lobby
- [ ] Conferir os dispositivos: desmarcar Console até haver suporte a controle
- [ ] Ligar servidores privados (grátis ou cerca de 100 Robux/mês; mudar o preço depois cancela as assinaturas)
- [ ] Depois de cada publicação: "Reiniciar servidores para atualizações"
- [ ] Criar uma experiência privada de teste para as sessões publicarem nela

Marca e página
- [ ] Decidir: nome do Capitão Men, paleta da Armadura de Ferro, título e Avengers: Doomsday, direção dos chefes
- [ ] Subir o ícone novo, 3 a 5 miniaturas reais e 1 vídeo; ativar a personalização
- [ ] Arquivar a foto antiga de Manhattan (asset 106232571755279)
- [ ] Renomear no Creator Hub os produtos dos heróis que mudarem de nome

Dinheiro
- [ ] Tirar de venda o game pass permanente da temporada (2026575250)
- [ ] Rodada de compras reais (cerca de 292 Robux)
- [ ] Ícones dos produtos (primeiro passes, Pacote Inicial e os 4 pacotes novos)
- [ ] Decidir se reabre a escada de preços

Testes e conteúdo
- [ ] Celular real: Android barato e iPhone antigo
- [ ] Subir `refined/battle.wav`. Não subir `assets/audio/summon/reelStart` e `reelTick`: são recortes de um MP3 de terceiros e você não pode declarar autoria deles
- [ ] Criar as insígnias (5 grátis por dia)
- [ ] Criar as chaves de Experience Configs e os Share Links
- [ ] Escolher o canal oficial (YouTube e/ou Discord 13+) e mostrar o jogo em parte dos Shorts
- [ ] Marcar a data do lançamento para crianças (12 a 19/12) e o evento de Natal
- [ ] Depois de liberar todas as idades: rodada com 5 a 10 crianças sem explicação

---

## 7. O que já está forte

- **Arquitetura:**
  - o servidor decide tudo;
  - cerca de 674 mil checagens de regras, 911 do serviço de jogadores e 6.937 de layout em 20 tamanhos de tela;
  - dados salvos com trava de sessão e recibos sem duplicação;
  - o código dos lugares separados, com reconexão, já existe.
- **Conteúdo:** 43 heróis com 2 ramos cada, 6 chefes com poderes avisados, 10 famílias de inimigo, 6 mapas com perigos próprios, 3 dificuldades, Competitivo sem fim e roguelike de cartas.
- **Motivos para voltar:** login de 28 dias que perdoa um dia perdido, baú grátis a cada 6 h, missões diárias e semanais, passe de 30 níveis, mercado do dia, troca segura só entre amigos e presente diário.
- **Primeiros minutos:** tutorial por setas sem mascote, nada de Robux no começo, tela de carregamento própria e idioma seguindo a conta.
- **Conformidade:** chances visíveis, preço regional real e compra direta sem sorteio.
- **Ritmo de entrega** muito alto e publicação por script funcionando.

---

## 8. Descartados pela verificação

**Afirmações que não se sustentaram:**
- "Lendário rende quase o mesmo que comum": as medições eram antigas e enviesadas. Por Ouro gasto, o lendário rende cerca de 2x.
- "Grupo de 4 é o caso mais difícil": o dado era de antes do rebalanceamento de 03/10. Cerca de 41 rodadas com 4 jogadores venceram.
- "IDs internos (ironman, ArcReactor) expõem a cópia": nenhum jogador vê esses nomes sem ferramenta de hack, e renomear arriscaria saves e recibos.

**Números ou recomendações corrigidos:**
- O treino dura 7,4 min, não 12,7 min (número velho de 26/09).
- O lobby tem 4.536 peças, não 4.433.
- O chefe final é o Mestre das Ilusões (loki), não o Tirano de Ferro.
- "O Studio perdeu o acesso" está desatualizado: a publicação por script funciona desde 14/10.
- "Publicar o place com o Config atual" já foi feito em 15/10, às 01:59 UTC.
- "A partida usa a música do lobby" é falso: há um arranjo de percussão de ação.
- Pôr uma estrela no escudo do Capitão daria erro, custaria 11 peças e aproximaria da marca.
- Ligar o streaming agora é arriscado e sem ganho claro. Primeiro, medir no celular.
- Céu próprio por mapa não compensa: na batalha a câmera não mostra o céu.
- "Chamar a insígnia dentro da gravação do perfil" faria a chamada repetir. Ela deve acontecer depois da gravação.
- "Comprar anúncios agora" não vale enquanto o alcance for 16+.