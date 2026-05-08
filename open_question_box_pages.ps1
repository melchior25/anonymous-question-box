# Anonymous Question Box - Open App Pages

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "Opening Anonymous Question Box pages..." -ForegroundColor Cyan

Start-Process "http://localhost:5173/ask"
Start-Process "http://localhost:5173/admin/questions"

Write-Host "Opened:" -ForegroundColor Green
Write-Host "http://localhost:5173/ask" -ForegroundColor White
Write-Host "http://localhost:5173/admin/questions" -ForegroundColor White
Write-Host ""