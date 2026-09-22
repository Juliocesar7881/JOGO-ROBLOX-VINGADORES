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

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot

function Require-Command($name, $installHint) {
    if (-not (Get-Command $name -ErrorAction SilentlyContinue)) {
        Write-Error "'$name' não encontrado no PATH.`n$installHint"
        exit 1
    }
}

Require-Command "git" "Instale o Git para Windows: https://git-scm.com/download/win"
Require-Command "gh" @"
Instale a GitHub CLI e faça login uma vez, interativamente:
  winget install GitHub.cli
  gh auth login
Depois rode este script de novo.
"@

Push-Location $root
try {
    $authStatus = gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Error "gh não está autenticado. Rode 'gh auth login' e tente de novo.`n$authStatus"
        exit 1
    }

    if (-not (Test-Path ".git")) {
        Write-Host "Inicializando o repositório Git local..."
        git init
    }

    $currentBranch = (git branch --show-current).Trim()
    if (-not $currentBranch) {
        $currentBranch = "main"
        git checkout -b $currentBranch
    }

    $existingRemote = git remote get-url origin 2>$null
    if ($existingRemote) {
        Write-Host "Remote 'origin' já existe: $existingRemote"
        Write-Host "Este script só cria o repositório e convida o colaborador; para publicar, rode:"
        Write-Host "  git push -u origin $currentBranch"
    } else {
        $visibility = if ($Public) { "--public" } else { "--private" }
        Write-Host "Criando repositório GitHub '$RepoName' ($(if ($Public) {'público'} else {'privado'}))..."
        gh repo create $RepoName $visibility --source=. --remote=origin --push
    }

    Write-Host "Convidando '$Collaborator' com permissão de escrita..."
    gh api "repos/:owner/$RepoName/collaborators/$Collaborator" -X PUT -f permission=push | Out-Null
    Write-Host "Convite enviado. '$Collaborator' precisa aceitar pelo e-mail ou por https://github.com/$RepoName/invitations"

    $repoUrl = gh repo view --json url -q .url
    Write-Host ""
    Write-Host "Pronto: $repoUrl"
} finally {
    Pop-Location
}
