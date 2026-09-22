# Publicação

Duas publicações independentes: o **código no GitHub** (para trabalhar em
dupla e ter histórico) e o **jogo no Roblox** (para jogadores de verdade). Os
IDs de asset/produto do Roblox nunca vão para o GitHub — `Config.luau` é
código, não segredo, mas os *valores* de produção (Game Pass IDs, Place IDs)
ficam só na cópia local até estarem prontos, se preferir mantê-los fora do
histórico público.

## GitHub

Este repositório ainda não tem remote — nenhuma sessão de IA tem permissão
para criar contas, fazer login ou manusear tokens/senhas, então esta etapa
precisa de uma pessoa.

### Passo único, com a GitHub CLI (recomendado)

```powershell
winget install GitHub.cli
gh auth login
```

Depois de autenticado (uma vez só), rode:

```powershell
powershell -File tools/publish_github.ps1
```

O script (`tools/publish_github.ps1`):
1. Cria o repositório `JOGO-ROBLOX-VINGADORES` (privado por padrão — o nome
   pedido tinha espaços, que o GitHub não aceita em nome de repositório; o
   hífen é a forma válida mais próxima) na sua conta.
2. Publica o branch atual (`git push`).
3. Convida `voidhb` com permissão de escrita.

Rode `powershell -File tools/publish_github.ps1 -Public` para público em vez
de privado, ou `-Collaborator outraconta` para convidar outra pessoa.

### Alternativa manual, sem a CLI

1. Crie um repositório vazio em <https://github.com/new>, nome
   `JOGO-ROBLOX-VINGADORES` (ou o que preferir), sem README/`.gitignore`
   (este repositório já tem os dois).
2. No terminal, dentro da pasta do projeto:
   ```bash
   git remote add origin https://github.com/<sua-conta>/JOGO-ROBLOX-VINGADORES.git
   git push -u origin main
   ```
   O Git para Windows abre uma janela de login do navegador na primeira vez
   (Git Credential Manager); depois disso fica salvo.
3. Em **Settings → Collaborators** do repositório, convide `voidhb`.

### Depois de publicado

Trabalhar em dois no mesmo repositório precisa de disciplina de commit — veja
`CONTRIBUTING.md`. Considere proteger o branch principal (Settings → Branches
→ branch protection) exigindo que `python tools/test.py` passe antes de um
merge, se configurar CI; não há workflow de CI configurado neste repositório
ainda.

## Roblox

Publicar o jogo em si (dois lugares, IDs de produto, licenciamento) está
documentado na seção **"2. Publicar de verdade"** do `README.md` — não
duplicado aqui para não haver duas versões da mesma instrução divergindo com
o tempo. Resumo: preencha os IDs em `Config.luau`, rode
`python tools/build.py`, suba os dois `.rbxlx` gerados para os lugares
correspondentes.

Teleporte, servidor reservado e compras reais só funcionam numa experiência
publicada — nunca no playtest do Studio.
