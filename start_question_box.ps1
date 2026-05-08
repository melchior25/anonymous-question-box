# Anonymous Question Box - Start App
# Run from: C:\Users\boskm\anonymous-question-box

$ErrorActionPreference = "Stop"

$ProjectRoot = Join-Path $env:USERPROFILE "anonymous-question-box"

if (!(Test-Path $ProjectRoot)) {
    throw "Project folder not found: $ProjectRoot"
}

Write-Host ""
Write-Host "Starting Anonymous Question Box..." -ForegroundColor Cyan
Write-Host ""
Write-Host "Project:" -ForegroundColor Yellow
Write-Host $ProjectRoot
Write-Host ""

Set-Location $ProjectRoot

Write-Host "Local pages:" -ForegroundColor Cyan
Write-Host "Public form: http://localhost:5173/ask" -ForegroundColor White
Write-Host "Admin page:  http://localhost:5173/admin/questions" -ForegroundColor White
Write-Host ""

Write-Host "Network pages for devices on the same Wi-Fi:" -ForegroundColor Cyan

$NetworkAddresses = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
    Where-Object {
        $_.IPAddress -notlike "127.*" -and
        $_.IPAddress -notlike "169.254.*" -and
        $_.PrefixOrigin -ne "WellKnown"
    } |
    Select-Object -ExpandProperty IPAddress -Unique

if ($NetworkAddresses) {
    foreach ($Address in $NetworkAddresses) {
        Write-Host "Public form: http://$Address`:5173/ask" -ForegroundColor White
        Write-Host "Admin page:  http://$Address`:5173/admin/questions" -ForegroundColor White
    }
} else {
    Write-Host "No local network address found. Use the Vite Network URL after startup." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Keep this PowerShell window open while using the app." -ForegroundColor Yellow
Write-Host "Starting npm run dev..." -ForegroundColor Cyan
Write-Host ""

npm run dev