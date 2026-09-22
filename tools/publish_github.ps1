<#
.SYNOPSIS
    One-time setup: create the GitHub repository for this project, push the
    current branch, and invite a collaborator.

.DESCRIPTION
    This script does not handle any credential, token or password itself —
    it only shells out to the GitHub CLI (`gh`), which owns its own login.
    Run it yourself, once, after `gh auth login` has succeeded interactively.

    GitHub repository names cannot contain spaces, so "JOGO ROBLOX
    VINGADORES" becomes "JOGO-ROBLOX-VINGADORES" (the closest valid slug).

.PARAMETER RepoName
    The GitHub repository name (no spaces). Default: JOGO-ROBLOX-VINGADORES

.PARAMETER Collaborator
    GitHub username to invite with write access. Default: voidhb

.PARAMETER Public
    Pass -Public to create a public repository. Default is private.

.EXAMPLE
    powershell -File tools/publish_github.ps1
.EXAMPLE
    powershell -File tools/publish_github.ps1 -RepoName MeuJogo -Collaborator outraconta -Public
#>
param(
    [string]$RepoName = "JOGO-ROBLOX-VINGADORES",
    [string]$Collaborator = "voidhb",
    [switch]$Public
)

# Windows PowerShell 5.1 turns any native stderr line into an error record, and
# git/gh write normal progress there; exit codes are checked explicitly instead.
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot

function Require-Command($name, $installHint) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Error "'$name' não encontrado no PATH.`n$installHint"
        exit 1
    }
}

Require-Command "git" "Instale o Git para Windows: https://git-scm.com/download/win"
# A terminal opened before `winget install GitHub.cli` does not see the new
# PATH entry yet; fall back to the installer's default location.
if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
    $defaultGh = Join-Path $env:ProgramFiles "GitHub CLI"
    if (Test-Path (Join-Path $defaultGh "gh.exe")) { $env:PATH = "$defaultGh;$env:PATH" }
}
Require-Command "gh" @"
Instale a GitHub CLI e faça login uma vez, interativamente:
  winget install GitHub.cli
  gh auth login
Depois rode este script de novo.
"@

function Fail($message) {
    Write-Host $message -ForegroundColor Red
    Pop-Location
    exit 1
}

Push-Location $root
gh auth status *> $null
if ($LASTEXITCODE -ne 0) { Fail "gh não está autenticado. Rode 'gh auth login' e tente de novo." }
$owner = (gh api user --jq .login).Trim()
if ($LASTEXITCODE -ne 0 -or -not $owner) { Fail "Não foi possível ler a conta logada no gh." }

if (-not (Test-Path ".git")) {
    Write-Host "Inicializando o repositório Git local..."
    git init
}
$currentBranch = (git branch --show-current).Trim()
if (-not $currentBranch) {
    $currentBranch = "main"
    git checkout -b $currentBranch
}

if ((git remote) -contains "origin") {
    Write-Host "Remote 'origin' já existe: $(git remote get-url origin). Enviando o branch $currentBranch..."
    git push -u origin $currentBranch
    if ($LASTEXITCODE -ne 0) { Fail "O envio (git push) falhou." }
} else {
    $visibility = if ($Public) { "--public" } else { "--private" }
    Write-Host "Criando repositório GitHub '$owner/$RepoName' ($(if ($Public) {'público'} else {'privado'}))..."
    gh repo create $RepoName $visibility --source=. --remote=origin --push
    if ($LASTEXITCODE -ne 0) { Fail "A criação do repositório falhou." }
}

Write-Host "Convidando '$Collaborator' com permissão de escrita..."
gh api "repos/$owner/$RepoName/collaborators/$Collaborator" -X PUT -f permission=push | Out-Null
if ($LASTEXITCODE -ne 0) { Fail "O convite para '$Collaborator' falhou." }
Write-Host "Convite enviado. '$Collaborator' precisa aceitar pelo e-mail ou em https://github.com/$owner/$RepoName/invitations"

$repoUrl = gh repo view "$owner/$RepoName" --json url -q .url
Write-Host ""
Write-Host "Pronto: $repoUrl"
Pop-Location
