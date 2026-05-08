# Build Step 07A - Prepare and Push to GitHub
# Run this script from: C:\Users\boskm\anonymous-question-box
#
# What this does:
# - Runs production precheck/build
# - Initializes Git if needed
# - Makes sure saved questions are not committed
# - Commits the current deployment-ready project
# - Pushes to GitHub if a remote exists
# - Or creates/pushes repo if GitHub CLI is installed and logged in
#
# Usage examples:
# .\build_step_07A_prepare_and_push_to_github.ps1
# .\build_step_07A_prepare_and_push_to_github.ps1 -RepoName "anonymous-question-box" -Visibility private
# .\build_step_07A_prepare_and_push_to_github.ps1 -RemoteUrl "https://github.com/YOURNAME/anonymous-question-box.git"

param(
    [string]$RepoName = "anonymous-question-box",
    [ValidateSet("private", "public")]
    [string]$Visibility = "private",
    [string]$RemoteUrl = ""
)

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Build Step 07A - Prepare and Push to GitHub" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Join-Path $env:USERPROFILE "anonymous-question-box"

if (!(Test-Path $ProjectRoot)) {
    throw "Project folder not found: $ProjectRoot"
}

Set-Location $ProjectRoot

function Run-Command {
    param(
        [string]$CommandText,
        [switch]$AllowFailure
    )

    Write-Host ""
    Write-Host $CommandText -ForegroundColor Cyan

    cmd /c $CommandText

    if ($LASTEXITCODE -ne 0 -and !$AllowFailure) {
        throw "Command failed: $CommandText"
    }
}

function Test-CommandExists {
    param([string]$CommandName)

    return [bool](Get-Command $CommandName -ErrorAction SilentlyContinue)
}

function Get-GitRemoteOrigin {
    try {
        $remote = git remote get-url origin 2>$null
        if ($LASTEXITCODE -eq 0 -and ![string]::IsNullOrWhiteSpace($remote)) {
            return $remote.Trim()
        }
    } catch {}

    return ""
}

function Ensure-GitInstalled {
    if (!(Test-CommandExists "git")) {
        throw "Git is not installed or not available in PATH."
    }

    Run-Command "git --version"
}

function Ensure-GitRepo {
    if (!(Test-Path (Join-Path $ProjectRoot ".git"))) {
        Run-Command "git init"
    }

    Run-Command "git branch -M main" -AllowFailure
}

function Ensure-StorageNotCommitted {
    Write-Host ""
    Write-Host "Checking that saved questions are not committed..." -ForegroundColor Cyan

    $TrackedQuestions = git ls-files backend/data/questions.json 2>$null

    if ($TrackedQuestions) {
        Write-Host "Removing backend/data/questions.json from Git tracking, but keeping the local file." -ForegroundColor Yellow
        Run-Command "git rm --cached backend/data/questions.json" -AllowFailure
    } else {
        Write-Host "Saved questions file is not tracked. Good." -ForegroundColor Green
    }
}

function Commit-CurrentWork {
    Run-Command "git add ."

    $Status = git status --short

    if ([string]::IsNullOrWhiteSpace($Status)) {
        Write-Host ""
        Write-Host "No new changes to commit." -ForegroundColor Yellow
        return
    }

    Write-Host ""
    Write-Host "Files ready for commit:" -ForegroundColor Cyan
    git status --short

    Run-Command 'git commit -m "Prepare anonymous question box for online deployment"'
}

function Push-WithExistingRemote {
    $Origin = Get-GitRemoteOrigin

    if ([string]::IsNullOrWhiteSpace($Origin)) {
        return $false
    }

    Write-Host ""
    Write-Host "Existing GitHub remote found:" -ForegroundColor Green
    Write-Host $Origin -ForegroundColor White

    Run-Command "git push -u origin main"
    return $true
}

function Set-Remote-And-Push {
    param([string]$Url)

    if ([string]::IsNullOrWhiteSpace($Url)) {
        return $false
    }

    $ExistingOrigin = Get-GitRemoteOrigin

    if ([string]::IsNullOrWhiteSpace($ExistingOrigin)) {
        Run-Command "git remote add origin $Url"
    } else {
        Run-Command "git remote set-url origin $Url"
    }

    Run-Command "git push -u origin main"
    return $true
}

function Try-GithubCliCreateAndPush {
    if (!(Test-CommandExists "gh")) {
        Write-Host ""
        Write-Host "GitHub CLI was not found." -ForegroundColor Yellow
        return $false
    }

    Write-Host ""
    Write-Host "GitHub CLI found. Checking login..." -ForegroundColor Cyan

    cmd /c "gh auth status"
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "GitHub CLI is installed, but you are not logged in." -ForegroundColor Yellow
        Write-Host "Run this later if you want to use GitHub CLI:" -ForegroundColor Cyan
        Write-Host "gh auth login" -ForegroundColor White
        return $false
    }

    $ExistingOrigin = Get-GitRemoteOrigin

    if (![string]::IsNullOrWhiteSpace($ExistingOrigin)) {
        Run-Command "git push -u origin main"
        return $true
    }

    $VisibilityFlag = "--private"

    if ($Visibility -eq "public") {
        $VisibilityFlag = "--public"
    }

    Write-Host ""
    Write-Host "Creating GitHub repository with GitHub CLI..." -ForegroundColor Cyan
    Write-Host "Repository name: $RepoName" -ForegroundColor White
    Write-Host "Visibility: $Visibility" -ForegroundColor White

    Run-Command "gh repo create $RepoName $VisibilityFlag --source . --remote origin --push"
    return $true
}

Write-Host "Project root:" -ForegroundColor Yellow
Write-Host $ProjectRoot -ForegroundColor White

Ensure-GitInstalled

Write-Host ""
Write-Host "Running deployment precheck..." -ForegroundColor Cyan

if (Test-Path (Join-Path $ProjectRoot "deploy_precheck.ps1")) {
    powershell -ExecutionPolicy Bypass -File ".\deploy_precheck.ps1"
} else {
    Write-Host "deploy_precheck.ps1 not found. Skipping." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Running production build..." -ForegroundColor Cyan

if (Test-Path (Join-Path $ProjectRoot "build_for_production.ps1")) {
    powershell -ExecutionPolicy Bypass -File ".\build_for_production.ps1"
} else {
    Run-Command "npm run build --prefix frontend"
}

Ensure-GitRepo
Ensure-StorageNotCommitted
Commit-CurrentWork

$Pushed = $false

if (![string]::IsNullOrWhiteSpace($RemoteUrl)) {
    $Pushed = Set-Remote-And-Push -Url $RemoteUrl
}

if (!$Pushed) {
    $Pushed = Push-WithExistingRemote
}

if (!$Pushed) {
    $Pushed = Try-GithubCliCreateAndPush
}

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " Build Step 07A completed" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""

if ($Pushed) {
    Write-Host "GitHub push is done." -ForegroundColor Green
    Write-Host ""
    Write-Host "Next step:" -ForegroundColor Cyan
    Write-Host "Create the Render Web Service using DEPLOY_RENDER_GUIDE.md" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host "Project is committed locally, but not pushed yet." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Create an empty GitHub repository named:" -ForegroundColor Cyan
    Write-Host $RepoName -ForegroundColor White
    Write-Host ""
    Write-Host "Then run this script again with your GitHub repo URL:" -ForegroundColor Cyan
    Write-Host '.\build_step_07A_prepare_and_push_to_github.ps1 -RemoteUrl "https://github.com/YOURNAME/anonymous-question-box.git"' -ForegroundColor White
    Write-Host ""
    Write-Host "Or install/login to GitHub CLI and run:" -ForegroundColor Cyan
    Write-Host "gh auth login" -ForegroundColor White
    Write-Host ".\build_step_07A_prepare_and_push_to_github.ps1" -ForegroundColor White
    Write-Host ""
}
