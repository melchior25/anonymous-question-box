# Anonymous Question Box - Deployment Precheck
# Run from: C:\Users\boskm\anonymous-question-box

$ErrorActionPreference = "Stop"

$ProjectRoot = Join-Path $env:USERPROFILE "anonymous-question-box"
$FrontendDist = Join-Path $ProjectRoot "frontend\dist\index.html"
$EnvFile = Join-Path $ProjectRoot "backend\.env"

Set-Location $ProjectRoot

Write-Host ""
Write-Host "Anonymous Question Box deployment precheck" -ForegroundColor Cyan
Write-Host ""

function Check-Command {
    param(
        [string]$CommandName,
        [string]$Label
    )

    if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
        Write-Host ("{0}: OK" -f $Label) -ForegroundColor Green
    } else {
        Write-Host ("{0}: Missing" -f $Label) -ForegroundColor Red
    }
}

Check-Command -CommandName "node" -Label "Node.js"
Check-Command -CommandName "npm" -Label "npm"
Check-Command -CommandName "git" -Label "Git"

Write-Host ""

if (Test-Path $EnvFile) {
    $EnvContent = Get-Content $EnvFile -Raw

    if ($EnvContent -match "ADMIN_PASSWORD=change-this-password") {
        Write-Host "Admin password: still default - change before real public use" -ForegroundColor Yellow
    } else {
        Write-Host "Admin password: appears changed" -ForegroundColor Green
    }
} else {
    Write-Host "Backend .env: missing locally. That is okay for production if env vars are set in the host dashboard." -ForegroundColor Yellow
}

if (Test-Path $FrontendDist) {
    Write-Host "Frontend production build: found" -ForegroundColor Green
} else {
    Write-Host "Frontend production build: missing - run .\build_for_production.ps1" -ForegroundColor Yellow
}

Write-Host ""

try {
    git status --short
    Write-Host "Git status command: OK" -ForegroundColor Green
} catch {
    Write-Host "Git status command failed. If this is not a Git repo yet, initialize/push it before Render deployment." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Precheck complete." -ForegroundColor Cyan
Write-Host ""