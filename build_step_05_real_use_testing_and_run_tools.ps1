# Build Step 05 - Real Use Testing and Run Tools
# Run this script from: C:\Users\boskm\anonymous-question-box
#
# What this updates:
# - Does NOT overwrite your backend .env or admin password
# - Adds simple run/check helper scripts
# - Adds a real-use checklist
# - Adds clearer README instructions
# - Keeps the anonymous question app simple

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Build Step 05 - Real Use Testing and Run Tools" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Join-Path $env:USERPROFILE "anonymous-question-box"
$BackendRoot = Join-Path $ProjectRoot "backend"
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

Write-Host "Creating helper scripts..." -ForegroundColor Cyan

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
        $ProcessIds = $Connections | Select-Object -ExpandProperty OwningProcess -Unique

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

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "start_question_box.ps1") -Content @'
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
'@

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
        Write-Host "$Label: OK" -ForegroundColor Green
        return $Response
    } catch {
        Write-Host "$Label: FAILED" -ForegroundColor Red
        Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
        return $null
    }
}

$Health = Test-Url -Label "Backend health" -Url "http://localhost:5000/api/health"

if ($Health) {
    Write-Host "  App: $($Health.app)" -ForegroundColor DarkGray
    Write-Host "  Time: $($Health.timestamp)" -ForegroundColor DarkGray
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
    Write-Host "Questions found: $QuestionCount" -ForegroundColor White
} catch {
    Write-Host "Admin API: FAILED" -ForegroundColor Red
    Write-Host "  $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Open these pages:" -ForegroundColor Cyan
Write-Host "Public form: http://localhost:5173/ask" -ForegroundColor White
Write-Host "Admin page:  http://localhost:5173/admin/questions" -ForegroundColor White
Write-Host ""
'@

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "open_question_box_pages.ps1") -Content @'
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
'@

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "REAL_USE_CHECKLIST.md") -Content @'
# Anonymous Question Box - Real Use Checklist

Use this checklist before sharing the question form with people.

## 1. Start the app

```powershell
cd C:\Users\boskm\anonymous-question-box
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\start_question_box.ps1
```

Keep that PowerShell window open.

## 2. Check the app

Open a second PowerShell window:

```powershell
cd C:\Users\boskm\anonymous-question-box
.\check_question_box.ps1
```

## 3. Open pages

Public form:

```text
http://localhost:5173/ask
```

Admin page:

```text
http://localhost:5173/admin/questions
```

## 4. Test the full flow

- Open the public form.
- Send a test question.
- Open the admin page.
- Confirm the question appears.
- Copy the question text.
- Mark the question as answered.
- Mark it back to new.
- Delete it.

## 5. Change admin password before real use

```powershell
cd C:\Users\boskm\anonymous-question-box
.\set_admin_password.ps1
```

Restart the app after changing the password.

## 6. Use on another device on the same Wi-Fi

When the app starts, Vite shows a Network URL like:

```text
http://192.168.x.x:5173/
```

Use:

```text
http://192.168.x.x:5173/ask
```

The other device must be on the same Wi-Fi network.

## 7. If ports are stuck

```powershell
cd C:\Users\boskm\anonymous-question-box
.\stop_question_box_ports.ps1
```

Then start again:

```powershell
.\start_question_box.ps1
```

## Notes

- Visitors do not log in.
- Visitors do not enter a name.
- Questions are saved in `backend\data\questions.json`.
- The admin page is protected with the admin password.
'@

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "README.md") -Content @'
# Anonymous Question Box

A simple one-page anonymous question form with a private admin page.

## What it does

- Visitors can ask a question anonymously.
- Visitors do not need a login, signup, username, email, or name.
- You can view questions on a private admin page.
- You can mark questions answered, copy question text, and delete questions.

## Start the app

Recommended:

```powershell
cd C:\Users\boskm\anonymous-question-box
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\start_question_box.ps1
```

Alternative:

```powershell
cd C:\Users\boskm\anonymous-question-box
npm run dev
```

Keep the PowerShell window open while using the app.

## Pages

Public form:

```text
http://localhost:5173/ask
```

Admin page:

```text
http://localhost:5173/admin/questions
```

## Open both pages quickly

```powershell
cd C:\Users\boskm\anonymous-question-box
.\open_question_box_pages.ps1
```

## Check if the app is working

Run this in a second PowerShell window while the app is running:

```powershell
cd C:\Users\boskm\anonymous-question-box
.\check_question_box.ps1
```

## If ports are stuck

```powershell
cd C:\Users\boskm\anonymous-question-box
.\stop_question_box_ports.ps1
```

Then start again:

```powershell
.\start_question_box.ps1
```

## Backend

Runs on:

```text
http://localhost:5000
```

Health check:

```text
http://localhost:5000/api/health
```

## Frontend

Runs on:

```text
http://localhost:5173
```

Vite may also show a Network URL. Another device on the same Wi-Fi can open the form with:

```text
http://YOUR-NETWORK-IP:5173/ask
```

## Admin password

The first default password is:

```text
change-this-password
```

Change it before real use:

```powershell
cd C:\Users\boskm\anonymous-question-box
.\set_admin_password.ps1
```

Then restart:

```powershell
.\start_question_box.ps1
```

## Admin tools

The admin page can:

- view all anonymous questions
- copy the public form link
- copy question text
- mark a question as answered
- mark an answered question back to new
- delete one question
- delete all answered questions

## Real-use checklist

Open:

```text
REAL_USE_CHECKLIST.md
```
'@

Write-Host ""
Write-Host "Checking existing app files..." -ForegroundColor Cyan

$RequiredFiles = @(
    (Join-Path $BackendRoot "server.js"),
    (Join-Path $FrontendRoot "src\pages\AskQuestionPage.tsx"),
    (Join-Path $FrontendRoot "src\pages\AdminQuestionsPage.tsx"),
    (Join-Path $BackendRoot ".env")
)

foreach ($File in $RequiredFiles) {
    if (Test-Path $File) {
        Write-Host "Found: $File" -ForegroundColor Green
    } else {
        Write-Host "Missing: $File" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " Build Step 05 completed successfully" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next recommended command:" -ForegroundColor Cyan
Write-Host "cd C:\Users\boskm\anonymous-question-box" -ForegroundColor White
Write-Host ".\start_question_box.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Then open a second PowerShell window and run:" -ForegroundColor Cyan
Write-Host ".\check_question_box.ps1" -ForegroundColor White
Write-Host ""
Write-Host "Public form:" -ForegroundColor Cyan
Write-Host "http://localhost:5173/ask" -ForegroundColor White
Write-Host ""
Write-Host "Admin page:" -ForegroundColor Cyan
Write-Host "http://localhost:5173/admin/questions" -ForegroundColor White
Write-Host ""
