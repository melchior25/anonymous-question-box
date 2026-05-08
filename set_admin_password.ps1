# Anonymous Question Box - Set Admin Password
# Run from: C:\Users\boskm\anonymous-question-box
#
# Usage:
# .\set_admin_password.ps1
# or:
# .\set_admin_password.ps1 -NewPassword "your-new-password"

param(
    [string]$NewPassword
)

$ErrorActionPreference = "Stop"

$ProjectRoot = Join-Path $env:USERPROFILE "anonymous-question-box"
$EnvFile = Join-Path $ProjectRoot "backend\.env"

if (!(Test-Path $EnvFile)) {
    throw "Could not find backend .env file: $EnvFile"
}

if ([string]::IsNullOrWhiteSpace($NewPassword)) {
    $NewPassword = Read-Host "Enter the new admin password"
}

$NewPassword = $NewPassword.Trim()

if ($NewPassword.Length -lt 8) {
    throw "Password must be at least 8 characters."
}

if ($NewPassword -match '\s') {
    throw "Password cannot contain spaces."
}

$content = Get-Content -Path $EnvFile -Raw

if ($content -match '(?m)^ADMIN_PASSWORD=') {
    $content = $content -replace '(?m)^ADMIN_PASSWORD=.*$', "ADMIN_PASSWORD=$NewPassword"
} else {
    $content = $content.TrimEnd() + "`r`nADMIN_PASSWORD=$NewPassword`r`n"
}

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($EnvFile, $content, $utf8NoBom)

Write-Host ""
Write-Host "Admin password updated." -ForegroundColor Green
Write-Host "Restart the app for the new password to take effect:" -ForegroundColor Yellow
Write-Host "CTRL + C"
Write-Host "npm run dev"
Write-Host ""