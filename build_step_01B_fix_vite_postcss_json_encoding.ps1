# Build Step 01B - Fix Vite PostCSS JSON Encoding Issue
# Run this script from: C:\Users\boskm\anonymous-question-box
# It rewrites JSON/config files as clean UTF-8 without BOM.

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Build Step 01B - Fix Vite/PostCSS JSON Encoding" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Join-Path $env:USERPROFILE "anonymous-question-box"
$FrontendRoot = Join-Path $ProjectRoot "frontend"
$BackendRoot = Join-Path $ProjectRoot "backend"

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
    Write-Host "Fixed encoding: $Path" -ForegroundColor Green
}

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "package.json") -Content @'
{
  "name": "anonymous-question-box",
  "version": "1.0.0",
  "private": true,
  "description": "A simple anonymous question form with a private admin view.",
  "scripts": {
    "install:all": "npm install --prefix backend && npm install --prefix frontend",
    "dev": "concurrently \"npm run dev --prefix backend\" \"npm run dev --prefix frontend\""
  },
  "devDependencies": {
    "concurrently": "^9.1.2"
  }
}
'@

Write-Utf8NoBomFile -Path (Join-Path $FrontendRoot "package.json") -Content @'
{
  "name": "anonymous-question-box-frontend",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite --host 0.0.0.0",
    "build": "tsc -b && vite build",
    "preview": "vite preview"
  },
  "dependencies": {
    "@vitejs/plugin-react": "^4.3.4",
    "typescript": "^5.7.3",
    "vite": "^6.0.7",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  },
  "devDependencies": {
    "@types/react": "^19.0.2",
    "@types/react-dom": "^19.0.2"
  }
}
'@

Write-Utf8NoBomFile -Path (Join-Path $FrontendRoot "tsconfig.json") -Content @'
{
  "compilerOptions": {
    "target": "ES2020",
    "useDefineForClassFields": true,
    "lib": ["DOM", "DOM.Iterable", "ES2020"],
    "allowJs": false,
    "skipLibCheck": true,
    "esModuleInterop": true,
    "allowSyntheticDefaultImports": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "noEmit": true,
    "jsx": "react-jsx"
  },
  "include": ["src"]
}
'@

Write-Utf8NoBomFile -Path (Join-Path $FrontendRoot "tsconfig.node.json") -Content @'
{
  "compilerOptions": {
    "composite": true,
    "module": "ESNext",
    "moduleResolution": "Bundler",
    "allowSyntheticDefaultImports": true
  },
  "include": ["vite.config.ts"]
}
'@

Write-Utf8NoBomFile -Path (Join-Path $BackendRoot "package.json") -Content @'
{
  "name": "anonymous-question-box-backend",
  "version": "1.0.0",
  "private": true,
  "main": "server.js",
  "scripts": {
    "dev": "nodemon server.js",
    "start": "node server.js"
  },
  "dependencies": {
    "cors": "^2.8.5",
    "dotenv": "^16.4.7",
    "express": "^4.21.2"
  },
  "devDependencies": {
    "nodemon": "^3.1.9"
  }
}
'@

Write-Host ""
Write-Host "Removing Vite cache..." -ForegroundColor Cyan

$ViteCache = Join-Path $FrontendRoot "node_modules\.vite"
if (Test-Path $ViteCache) {
    Remove-Item -Path $ViteCache -Recurse -Force
    Write-Host "Removed: $ViteCache" -ForegroundColor Green
} else {
    Write-Host "No Vite cache found. That is okay." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Checking frontend package.json..." -ForegroundColor Cyan
Push-Location $FrontendRoot
npm pkg get name
Pop-Location

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " Step 01B completed" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now restart Vite cleanly:" -ForegroundColor Cyan
Write-Host "1. Stop the running dev server with CTRL + C" -ForegroundColor White
Write-Host "2. Run:" -ForegroundColor White
Write-Host "   cd C:\Users\boskm\anonymous-question-box" -ForegroundColor White
Write-Host "   npm run dev" -ForegroundColor White
Write-Host ""
Write-Host "Then open:" -ForegroundColor Cyan
Write-Host "http://localhost:5173/ask" -ForegroundColor White
Write-Host ""
