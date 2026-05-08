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