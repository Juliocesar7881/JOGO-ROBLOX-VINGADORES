# Régua do diretor (0–5 por eixo)

Dê nota a cada entrega visível olhando as capturas do Studio, não o código.
5 = tão bom quanto o melhor TD do Roblox; 4 = publicável; 3 = parece jogo de
estudante; ≤2 = não entra. **Uma entrega não pode baixar a nota de nenhum eixo.**

| Eixo | 5 parece | 0–2 parece |
|---|---|---|
| **Leitura no celular** (667×375) | Uma ação principal óbvia; texto ≥12 px; toque ≥48 px; nada cortado ou sobreposto; números grandes | Parágrafos; texto cortado; botões colados; informação duplicada |
| **Uau** | Todo evento importante (colocar, upgrade, abate de chefe, onda, baú, nível) tem movimento + som + número em ≤0,3 s | Coisas aparecem/somem sem transição; silêncio |
| **Acabamento** | Formas com volume, contorno, sombra, cor de família; ícones desenhados; nada de cinza padrão | Caixas cinza, texto solto sobre o mundo, placeholder, "TODO" |
| **Consistência** | Paleta do `UI.luau` e fontes iguais em todas as telas; mesma linguagem de botão | Cada tela num estilo |
| **Clareza do objetivo** | A criança sabe o que fazer em 3 s e o que ganha em seguida | Precisa ler para entender |
| **Combate** | Golpes com peso, inimigos reagem, dano visível, upgrade sentido, chefe com entrada | Bonecos andando e sumindo |
| **Recompensa** | Sempre há algo a 1–5 min de distância (baú, nível, missão), com barra visível | Recompensa escondida em menu |
| **Desempenho** | 60 FPS no PC, sem picos; peças e efeitos dentro do orçamento | Travadas ao abrir painel, centenas de partes por efeito |
| **Marca segura** | Tudo original (IP_POLICY); teste `test_ip_safety.py` verde | Nome, logo ou uniforme reconhecível de terceiros |
| **Perto do TTD** | Mesmo ritmo de loop (lobby→fila→partida→recompensa) com algo melhor | Mais lento ou mais confuso que o TTD |

## Checagens rápidas antes de dar nota

- Texto: `UI.layoutReport`/test_ui_layout cobre sobra e corte; olhe também a
  captura — se você precisa apertar os olhos, está pequeno.
- Para cada tela nova: conte palavras. Mais de ~12 palavras fora de listas = cortar.
- Para cada número que importa (ouro, onda, vida, dano): está grande e animado?
- Para cada botão: o que acontece se uma criança apertar 10× rápido? (o servidor
  recusa sem mudar estado; o cliente não trava)
- Para cada efeito: quantas partes cria e quanto vive? (`Effects.luau` tem limite)

## Como registrar

No LOG: `notas leitura 4, uau 3, acabamento 4, ... — pior: <eixo> porque <evidência>`.
O pior eixo vira o próximo item se não houver coisa mais urgente.
