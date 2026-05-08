# Build Step 05B - Fix Check Script PowerShell Label Syntax
# Run this script from: C:\Users\boskm\anonymous-question-box
#
# This only fixes check_question_box.ps1.
# It does not change the app, backend, frontend, password, or storage.

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Build Step 05B - Fix Check Script" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Join-Path $env:USERPROFILE "anonymous-question-box"

if (!(Test-Path $ProjectRoot)) {
    throw "Project folder not found: $ProjectRoot"
}

function Write-Utf8NoBomFile {
    param (
        [string]$Path,
        [string]$Content
    )

    $folder = Split-Path -Parent $Path
    if (!(Test-Path $folder)) {
        New-Item -ItemType Directory -Force -Path $folder | Out-Null
    }

    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Content, $utf8NoBom)
    Write-Host "Updated: $Path" -ForegroundColor Green
}

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "check_question_box.ps1") -Content @'
# Anonymous Question Box - Check App Health
# Run this in a second PowerShell window while the app is running.

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Checking Anonymous Question Box..." -ForegroundColor Cyan
Write-Host ""

function Test-Url {
    param(
        [string]$Label,
        [string]$Url
    )

    try {
        $Response = Invoke-RestMethod -Uri $Url -TimeoutSec 8
        Write-Host ("{0}: OK" -f $Label) -ForegroundColor Green
        return $Response
    } catch {
        Write-Host ("{0}: FAILED" -f $Label) -ForegroundColor Red
        Write-Host ("  {0}" -f $_.Exception.Message) -ForegroundColor Yellow
        return $null
    }
}

$Health = Test-Url -Label "Backend health" -Url "http://localhost:5000/api/health"

if ($Health) {
    Write-Host ("  App: {0}" -f $Health.app) -ForegroundColor DarkGray
    Write-Host ("  Time: {0}" -f $Health.timestamp) -ForegroundColor DarkGray
}

Write-Host ""

$AdminPassword = Read-Host "Enter admin password to test admin API"

try {
    $AdminResponse = Invoke-RestMethod `
        -Uri "http://localhost:5000/api/questions/admin" `
        -Headers @{ "x-admin-password" = $AdminPassword } `
        -TimeoutSec 8

    $QuestionCount = 0

    if ($AdminResponse.questions) {
        $QuestionCount = $AdminResponse.questions.Count
    }

    Write-Host "Admin API: OK" -ForegroundColor Green
    Write-Host ("Questions found: {0}" -f $QuestionCount) -ForegroundColor White
} catch {
    Write-Host "Admin API: FAILED" -ForegroundColor Red
    Write-Host ("  {0}" -f $_.Exception.Message) -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Open these pages:" -ForegroundColor Cyan
Write-Host "Public form: http://localhost:5173/ask" -ForegroundColor White
Write-Host "Admin page:  http://localhost:5173/admin/questions" -ForegroundColor White
Write-Host ""
'@

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " Build Step 05B completed successfully" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now run:" -ForegroundColor Cyan
Write-Host "cd C:\Users\boskm\anonymous-question-box" -ForegroundColor White
Write-Host ".\check_question_box.ps1" -ForegroundColor White
Write-Host ""
