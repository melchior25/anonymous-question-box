# Build Step 06B - Fix Production Build TypeScript Env
# Run this script from: C:\Users\boskm\anonymous-question-box
#
# What this fixes:
# - Adds Vite environment types so import.meta.env works in production build
# - Fixes build_for_production.ps1 so it stops when npm build fails
# - Fixes stop_question_box_ports.ps1 so it skips invalid PID 0
# - Does NOT change admin password, saved questions, or app design

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Build Step 06B - Fix Production Build" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Join-Path $env:USERPROFILE "anonymous-question-box"
$FrontendRoot = Join-Path $ProjectRoot "frontend"

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

Write-Host "Adding Vite TypeScript environment file..." -ForegroundColor Cyan

Write-Utf8NoBomFile -Path (Join-Path $FrontendRoot "src\vite-env.d.ts") -Content @'
/// <reference types="vite/client" />
'@

Write-Host ""
Write-Host "Fixing production build helper..." -ForegroundColor Cyan

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "build_for_production.ps1") -Content @'
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
'@

Write-Host ""
Write-Host "Fixing stop ports helper..." -ForegroundColor Cyan

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "stop_question_box_ports.ps1") -Content @'
# Anonymous Question Box - Stop App Ports
# Use this when ports 5000, 5173, 5174, or 5175 are stuck.

$ErrorActionPreference = "Stop"

$Ports = @(5000, 5173, 5174, 5175)

Write-Host ""
Write-Host "Stopping Anonymous Question Box ports..." -ForegroundColor Cyan

foreach ($Port in $Ports) {
    $Connections = Get-NetTCPConnection -LocalPort $Port -ErrorAction SilentlyContinue

    if ($Connections) {
        $ProcessIds = $Connections |
            Select-Object -ExpandProperty OwningProcess -Unique |
            Where-Object { $_ -and $_ -gt 0 }

        if (!$ProcessIds) {
            Write-Host "Port $Port has no stoppable process." -ForegroundColor DarkGray
            continue
        }

        foreach ($ProcessId in $ProcessIds) {
            try {
                Stop-Process -Id $ProcessId -Force
                Write-Host "Stopped process $ProcessId on port $Port" -ForegroundColor Green
            } catch {
                Write-Host "Could not stop process $ProcessId on port $Port" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "Port $Port is free." -ForegroundColor DarkGray
    }
}

Write-Host ""
Write-Host "Done. You can now run:" -ForegroundColor Cyan
Write-Host "npm run dev" -ForegroundColor White
Write-Host ""
'@

Write-Host ""
Write-Host "Running production build now..." -ForegroundColor Cyan

Push-Location $ProjectRoot

cmd /c "npm run build --prefix frontend"

if ($LASTEXITCODE -ne 0) {
    Pop-Location
    throw "Frontend production build failed."
}

Pop-Location

$FrontendIndex = Join-Path $ProjectRoot "frontend\dist\index.html"

if (!(Test-Path $FrontendIndex)) {
    throw "frontend\dist\index.html was not created."
}

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " Build Step 06B completed successfully" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "1. Stop the running backend with CTRL + C if it is still running." -ForegroundColor White
Write-Host "2. Run:" -ForegroundColor White
Write-Host "   cd C:\Users\boskm\anonymous-question-box" -ForegroundColor White
Write-Host "   .\stop_question_box_ports.ps1" -ForegroundColor White
Write-Host "   npm start --prefix backend" -ForegroundColor White
Write-Host ""
Write-Host "Then open production-style local pages:" -ForegroundColor Cyan
Write-Host "http://localhost:5000/ask" -ForegroundColor White
Write-Host "http://localhost:5000/admin/questions" -ForegroundColor White
Write-Host ""
