# Lançar e começar a monetizar — 12/10/2026

O jogo já tem conteúdo e sistemas para uma beta: 43 heróis, 11 bases, seis
mapas, campanha, Cartas, competitivo, cooperação e progressão. A atualização
de código foi publicada no place oficial 97132875544830. Isso não comprova
que a experiência esteja acessível ao público pretendido ou que compras,
salvamento e retenção tenham sido aprovados em produção.

## Antes de divulgar

1. **Acesso e alcance.** Conferir Audience e Audience > Reach, questionário
   de conteúdo e verificações na conta do dono. A captura anterior mostrava
   restrição a 16+ e amigos de confiança. A consulta anônima de 12/10 retornou
   `GuestProhibited`; isso não determina a configuração atual de audiência
   nem comprova acesso de uma conta autenticada de determinada idade.
   A [documentação atual](https://create.roblox.com/docs/production/publishing/publish-games-and-places#publishing-requirements)
   exige verificações diferentes para 16+ e para todas as idades. Para
   Kids/Select também há 2FA, requisitos de conta/assinatura ou taxa e
   avaliação. Não comprar assinatura/taxa nem alterar o alcance por suposição.
2. **Entrada e salvamento reais.** Conta nova no aplicativo publicado:
   primeira abertura, perfil, treino, prêmio, sair/reentrar e reconectar
   durante a partida. Confirmar que nada fica preso ou perde progresso.
3. **Celular e cooperação.** Android/iPhone físico, comandos de toque e
   quatro jogadores reais. Conferir filas, saída/retorno, recompensas e
   replay. Emulação do Studio só fecha layout.
4. **Compras entregues.** Testar as ofertas que realmente ficarão ativas:
   compra, cancelamento, entrega única, recibo repetido e reentrada. O
   [Roblox exige processamento correto dos recibos](https://create.roblox.com/docs/production/monetization/developer-products).
   Os testes locais não substituem essa conferência em produção.
5. **Página e direitos.** Ícone/miniatura fiéis, descrição localizada,
   conteúdo classificado corretamente e decisão sobre personagens/logos.
   Os visuais próximos de franquias continuam um aceite de marca pendente;
   mudar o nome não comprova autorização do visual. Usar personagens próprios
   ou conteúdo autorizado, conforme as [diretrizes de propriedade intelectual](https://create.roblox.com/docs/production/publishing/ip-guidelines).

## Monetização existente e incompleta

Auditor do catálogo executado em 12/10:

| Oferta | Estado |
|---|---|
| Drone, Treinamento e Velocidade 3x | IDs configurados; à venda na consulta de 11/10, compras reais ainda pendentes |
| Cinco produtos consumíveis | IDs configurados; entrega real ainda pendente |
| Produtos de heróis | 15 de 41 configurados; faltam 26 |
| VIP | API pública reconfirmou `IsForSale=false` em 12/10 |
| Temporada | Passe sem ID; ainda não pode ser vendido |

Evidências: `test-results/launch-audit-2026-10-12.json` e
`test-results/launch-public-metadata-2026-10-12.json`. IDs não comprovam
venda, recibos ou aprovação da experiência. Os termos pendentes, se ainda
aparecerem, são confirmados pessoalmente pelo dono.

**Não é necessário cadastrar os 26 heróis ou vender a temporada para começar
a monetizar.** É possível iniciar uma beta com poucas ofertas existentes,
com benefício claro, estado de venda conferido e entrega real aprovada.
Manter ofertas incompletas desativadas/indisponíveis; não anunciar benefícios
que ainda não possam ser comprados e entregues. Completar o catálogo depois
é expansão comercial, não requisito para a primeira venda.

## Para as pessoas voltarem e comprarem

Minha prioridade de produção é testar com 10–20 pessoas novas, sem explicar
o caminho. Observar entrada, primeira torre/poder, resultado, recompensa e
segunda partida. Corrigir o maior abandono antes de ampliar divulgação.
Ver D1 no dia seguinte e D7 depois de uma semana, separando origem,
dispositivo e versão. AFK não demonstra interesse pelo combate.

Preparação/impacto/recuperação e geometria dos modelos já avançaram; figurinos
individuais, demais assinaturas de ataque e medição válida com 80 inimigos
continuam em M33.5/M33.6. Sessão prolongada também está aberta. Isso deve ser
conferido antes de divulgar amplamente; não existe aceite de 100% ou receita
garantida por passar a suíte ou adicionar mais efeitos.

Além de vendas, [Creator Rewards](https://create.roblox.com/docs/creator-rewards)
remunera engajamento/aquisição elegíveis sob regras específicas. Não é um
pagamento garantido por visita nem motivo para fabricar sessões/contas.

## Robux e saque

Vendas e recompensas elegíveis geram Robux; sacar dinheiro é uma etapa
separada. O [DevEx](https://en.help.roblox.com/hc/en-us/articles/203314100-Developer-Exchange-DevEx-Overview-How-to-Submit-Requirements)
exige, entre outros critérios, 30.000 Earned Robux, idade mínima de 13 anos,
e-mail verificado, conta em boa situação e aprovação/cadastro de pagamento
e dados fiscais. Não calcular faturamento como lucro ou saque imediato.

## Arquivos organizados

As dez pastas `Multiverse_*` antes na Área de Trabalho foram movidas intactas
para `test-results/galerias/`, com contagens e bytes conferidos. Manifesto em
`test-results/galerias/movimentacao-2026-10-12.json`. Novas entregas devem ir
para essa pasta; a preferência foi registrada no AGENTS.md.
