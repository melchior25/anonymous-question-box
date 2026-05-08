# Anonymous Question Box - Build for Production
# Run from: C:\Users\boskm\anonymous-question-box

$ErrorActionPreference = "Stop"

$ProjectRoot = Join-Path $env:USERPROFILE "anonymous-question-box"

if (!(Test-Path $ProjectRoot)) {
    throw "Project folder not found: $ProjectRoot"
}

function Run-NpmCommand {
    param(
        [string]$CommandText
    )

    Write-Host ""
    Write-Host $CommandText -ForegroundColor Cyan

    cmd /c $CommandText

    if ($LASTEXITCODE -ne 0) {
        throw "Command failed: $CommandText"
    }
}

Set-Location $ProjectRoot

Write-Host ""
Write-Host "Building Anonymous Question Box for production..." -ForegroundColor Cyan
Write-Host ""

Run-NpmCommand "npm run install:all"
Run-NpmCommand "npm run build --prefix frontend"

$FrontendIndex = Join-Path $ProjectRoot "frontend\dist\index.html"

if (!(Test-Path $FrontendIndex)) {
    throw "Production build did not create frontend\dist\index.html"
}

Write-Host ""
Write-Host "Production build complete." -ForegroundColor Green
Write-Host "Frontend build folder:" -ForegroundColor Cyan
Write-Host "C:\Users\boskm\anonymous-question-box\frontend\dist" -ForegroundColor White
Write-Host ""
Write-Host "Local production-style start command:" -ForegroundColor Cyan
Write-Host "npm start --prefix backend" -ForegroundColor White
Write-Host ""
Write-Host "Then open:" -ForegroundColor Cyan
Write-Host "http://localhost:5000/ask" -ForegroundColor White
Write-Host "http://localhost:5000/admin/questions" -ForegroundColor White
Write-Host ""