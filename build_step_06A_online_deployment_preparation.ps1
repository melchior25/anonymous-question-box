# Build Step 06A - Online Deployment Preparation
# Run this script from: C:\Users\boskm\anonymous-question-box
#
# What this updates:
# - Prepares the app for online deployment
# - Lets the backend serve the built frontend in production
# - Keeps local development working
# - Makes production storage path configurable
# - Adds deployment guides/checklists
# - Does NOT overwrite backend .env or admin password
# - Does NOT deploy automatically; it prepares the project for Render/GitHub deployment

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Build Step 06A - Online Deployment Preparation" -ForegroundColor Cyan
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

Write-Host "Updating root project files..." -ForegroundColor Cyan

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "package.json") -Content @'
{
  "name": "anonymous-question-box",
  "version": "1.0.0",
  "private": true,
  "description": "A simple anonymous question form with a private admin view.",
  "scripts": {
    "install:all": "npm install --prefix backend && npm install --prefix frontend",
    "dev": "concurrently \"npm run dev --prefix backend\" \"npm run dev --prefix frontend\"",
    "build": "npm run build --prefix frontend",
    "start": "npm start --prefix backend",
    "render:build": "npm run install:all && npm run build --prefix frontend"
  },
  "devDependencies": {
    "concurrently": "^9.1.2"
  }
}
'@

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot ".gitignore") -Content @'
node_modules
.env
.env.local
dist
.DS_Store

frontend/dist
frontend/node_modules
backend/node_modules

backend/data/questions.json
backend/data/questions.json.tmp
backend/data/*.broken-*
'@

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot ".env.example") -Content @'
# Backend production variables
# Do not commit your real .env file.

NODE_ENV=production
ADMIN_PASSWORD=replace-with-a-strong-password
QUESTION_COOLDOWN_SECONDS=20

# Optional for hosts with persistent disk:
# QUESTION_STORAGE_FILE=/var/data/questions.json
'@

Write-Host ""
Write-Host "Updating backend for production serving + configurable storage..." -ForegroundColor Cyan

Write-Utf8NoBomFile -Path (Join-Path $BackendRoot "server.js") -Content @'
const express = require('express')
const cors = require('cors')
const dotenv = require('dotenv')
const os = require('os')
const fs = require('fs')
const path = require('path')
const questionRoutes = require('./routes/questionRoutes')

dotenv.config()

const app = express()
const PORT = process.env.PORT || 5000

function getAllowedOrigins() {
  const fallbackOrigin = process.env.FRONTEND_URL || 'http://localhost:5173'
  const configuredOrigins = process.env.FRONTEND_URLS || fallbackOrigin

  return configuredOrigins
    .split(',')
    .map((origin) => origin.trim())
    .filter(Boolean)
}

function isPrivateNetworkHost(hostname) {
  return (
    hostname === 'localhost' ||
    hostname === '127.0.0.1' ||
    hostname.startsWith('192.168.') ||
    hostname.startsWith('10.') ||
    /^172\.(1[6-9]|2[0-9]|3[0-1])\./.test(hostname)
  )
}

function isAllowedDevelopmentOrigin(origin) {
  if (!origin) return true

  try {
    const parsedOrigin = new URL(origin)
    const allowedPorts = new Set(['5173', '5174', '5175'])

    return (
      parsedOrigin.protocol === 'http:' &&
      allowedPorts.has(parsedOrigin.port) &&
      isPrivateNetworkHost(parsedOrigin.hostname)
    )
  } catch {
    return false
  }
}

function isAllowedProductionOrigin(origin) {
  if (!origin) return true

  const publicUrl = (process.env.PUBLIC_URL || '').trim()

  if (!publicUrl) {
    return false
  }

  return origin === publicUrl
}

function getLocalNetworkAddresses() {
  const interfaces = os.networkInterfaces()
  const addresses = []

  Object.values(interfaces).forEach((networkItems) => {
    if (!Array.isArray(networkItems)) return

    networkItems.forEach((item) => {
      if (item.family === 'IPv4' && !item.internal) {
        addresses.push(item.address)
      }
    })
  })

  return addresses
}

const allowedOrigins = getAllowedOrigins()

app.use(cors({
  origin(origin, callback) {
    if (
      !origin ||
      allowedOrigins.includes(origin) ||
      isAllowedDevelopmentOrigin(origin) ||
      isAllowedProductionOrigin(origin)
    ) {
      callback(null, true)
      return
    }

    callback(new Error(`CORS blocked origin: ${origin}`))
  },
  methods: ['GET', 'POST', 'PATCH', 'DELETE'],
  allowedHeaders: ['Content-Type', 'x-admin-password']
}))

app.use(express.json({ limit: '30kb' }))

app.get('/api/health', (req, res) => {
  res.json({
    ok: true,
    app: 'Anonymous Question Box',
    mode: process.env.NODE_ENV || 'development',
    timestamp: new Date().toISOString()
  })
})

app.use('/api/questions', questionRoutes)

const frontendDistPath = path.join(__dirname, '..', 'frontend', 'dist')
const frontendIndexPath = path.join(frontendDistPath, 'index.html')

if (fs.existsSync(frontendIndexPath)) {
  app.use(express.static(frontendDistPath))

  app.get(['/', '/ask', '/admin/questions'], (req, res) => {
    res.sendFile(frontendIndexPath)
  })
}

app.use((req, res) => {
  res.status(404).json({
    ok: false,
    message: 'Route not found.'
  })
})

app.use((error, req, res, next) => {
  console.error(error)

  res.status(500).json({
    ok: false,
    message: 'Something went wrong on the server.'
  })
})

app.listen(PORT, () => {
  console.log(`Anonymous Question Box backend running on http://localhost:${PORT}`)
  console.log(`Mode: ${process.env.NODE_ENV || 'development'}`)

  if (fs.existsSync(frontendIndexPath)) {
    console.log('Frontend build detected. Backend is serving the public app.')
  } else {
    console.log('No frontend build detected. Use the Vite frontend during development.')
  }

  console.log(`Allowed configured frontend origins: ${allowedOrigins.join(', ')}`)
  console.log('Local network backend URLs:')

  const networkAddresses = getLocalNetworkAddresses()

  if (networkAddresses.length === 0) {
    console.log('  No local network address found.')
  } else {
    networkAddresses.forEach((address) => {
      console.log(`  http://${address}:${PORT}`)
    })
  }
})
'@

Write-Utf8NoBomFile -Path (Join-Path $BackendRoot "services\questionStorageService.js") -Content @'
const fs = require('fs/promises')
const path = require('path')

function getQuestionsFile() {
  const configuredFile = (process.env.QUESTION_STORAGE_FILE || '').trim()

  if (configuredFile) {
    return configuredFile
  }

  const configuredDirectory = (process.env.QUESTION_STORAGE_DIR || '').trim()

  if (configuredDirectory) {
    return path.join(configuredDirectory, 'questions.json')
  }

  return path.join(__dirname, '..', 'data', 'questions.json')
}

async function ensureStorage() {
  const questionsFile = getQuestionsFile()
  const dataDirectory = path.dirname(questionsFile)

  await fs.mkdir(dataDirectory, { recursive: true })

  try {
    await fs.access(questionsFile)
  } catch {
    await fs.writeFile(questionsFile, JSON.stringify([], null, 2), 'utf8')
  }
}

function removeJsonByteOrderMark(value) {
  if (typeof value !== 'string') return ''
  return value.replace(/^\uFEFF/, '').trim()
}

async function readQuestions() {
  await ensureStorage()

  const questionsFile = getQuestionsFile()
  const raw = await fs.readFile(questionsFile, 'utf8')
  const cleaned = removeJsonByteOrderMark(raw)

  if (!cleaned) {
    return []
  }

  try {
    const parsed = JSON.parse(cleaned)

    if (!Array.isArray(parsed)) {
      return []
    }

    return parsed
  } catch (error) {
    const brokenBackupFile = `${questionsFile}.broken-${Date.now()}`
    await fs.writeFile(brokenBackupFile, raw, 'utf8')
    await fs.writeFile(questionsFile, JSON.stringify([], null, 2), 'utf8')

    console.warn(`questions.json was invalid. A backup was saved to: ${brokenBackupFile}`)
    return []
  }
}

async function writeQuestions(questions) {
  await ensureStorage()

  const questionsFile = getQuestionsFile()
  const temporaryFile = `${questionsFile}.tmp`
  await fs.writeFile(temporaryFile, JSON.stringify(questions, null, 2), 'utf8')
  await fs.rename(temporaryFile, questionsFile)
}

function createId() {
  return `question_${Date.now()}_${Math.random().toString(16).slice(2)}`
}

async function addQuestion(text) {
  const questions = await readQuestions()

  const newQuestion = {
    id: createId(),
    text,
    answered: false,
    createdAt: new Date().toISOString()
  }

  questions.unshift(newQuestion)

  await writeQuestions(questions)

  return newQuestion
}

async function getQuestions() {
  return readQuestions()
}

async function updateQuestionAnswered(id, answered) {
  const questions = await readQuestions()
  const questionIndex = questions.findIndex((question) => question.id === id)

  if (questionIndex === -1) {
    return null
  }

  questions[questionIndex] = {
    ...questions[questionIndex],
    answered,
    answeredAt: answered ? new Date().toISOString() : null
  }

  await writeQuestions(questions)

  return questions[questionIndex]
}

async function removeQuestion(id) {
  const questions = await readQuestions()
  const nextQuestions = questions.filter((question) => question.id !== id)

  if (nextQuestions.length === questions.length) {
    return false
  }

  await writeQuestions(nextQuestions)

  return true
}

async function removeAnsweredQuestions() {
  const questions = await readQuestions()
  const nextQuestions = questions.filter((question) => !question.answered)
  const deletedCount = questions.length - nextQuestions.length

  if (deletedCount === 0) {
    return 0
  }

  await writeQuestions(nextQuestions)

  return deletedCount
}

module.exports = {
  addQuestion,
  getQuestions,
  updateQuestionAnswered,
  removeQuestion,
  removeAnsweredQuestions
}
'@

Write-Host ""
Write-Host "Updating frontend API handling for online deployment..." -ForegroundColor Cyan

Write-Utf8NoBomFile -Path (Join-Path $FrontendRoot "src\services\questionApi.ts") -Content @'
import type { Question } from '../types/question.types'

function getApiUrl() {
  const configuredApiUrl = (import.meta.env.VITE_API_URL || '').trim()

  if (configuredApiUrl) {
    return configuredApiUrl
  }

  const hostname = window.location.hostname
  const port = window.location.port
  const isLocalDevFrontend = ['5173', '5174', '5175'].includes(port)

  if (isLocalDevFrontend) {
    return `${window.location.protocol}//${hostname}:5000`
  }

  return window.location.origin
}

const API_URL = getApiUrl()

type ApiResult<T> = {
  ok: boolean
  message?: string
} & T

async function readResponse<T>(response: Response): Promise<ApiResult<T>> {
  const data = await response.json().catch(() => ({}))

  if (!response.ok) {
    throw new Error(data.message || 'Something went wrong.')
  }

  return data
}

function getNetworkErrorMessage() {
  return 'Cannot reach the backend. Make sure the app server is running.'
}

async function requestWithNetworkMessage<T>(request: () => Promise<Response>) {
  try {
    const response = await request()
    return readResponse<T>(response)
  } catch (error) {
    if (error instanceof Error && error.message !== 'Failed to fetch') {
      throw error
    }

    throw new Error(getNetworkErrorMessage())
  }
}

export async function submitQuestion(question: string) {
  return requestWithNetworkMessage<{ question: { id: string; createdAt: string } }>(() => {
    return fetch(`${API_URL}/api/questions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ question })
    })
  })
}

export async function getAdminQuestions(adminPassword: string) {
  return requestWithNetworkMessage<{ questions: Question[] }>(() => {
    return fetch(`${API_URL}/api/questions/admin`, {
      headers: {
        'x-admin-password': adminPassword
      }
    })
  })
}

export async function markQuestionAnswered(questionId: string, adminPassword: string) {
  return requestWithNetworkMessage<{ question: Question }>(() => {
    return fetch(`${API_URL}/api/questions/${questionId}/answered`, {
      method: 'PATCH',
      headers: {
        'x-admin-password': adminPassword
      }
    })
  })
}

export async function markQuestionNew(questionId: string, adminPassword: string) {
  return requestWithNetworkMessage<{ question: Question }>(() => {
    return fetch(`${API_URL}/api/questions/${questionId}/new`, {
      method: 'PATCH',
      headers: {
        'x-admin-password': adminPassword
      }
    })
  })
}

export async function deleteQuestion(questionId: string, adminPassword: string) {
  return requestWithNetworkMessage<Record<string, never>>(() => {
    return fetch(`${API_URL}/api/questions/${questionId}`, {
      method: 'DELETE',
      headers: {
        'x-admin-password': adminPassword
      }
    })
  })
}

export async function deleteAnsweredQuestions(adminPassword: string) {
  return requestWithNetworkMessage<{ deletedCount: number }>(() => {
    return fetch(`${API_URL}/api/questions/admin/answered`, {
      method: 'DELETE',
      headers: {
        'x-admin-password': adminPassword
      }
    })
  })
}
'@

Write-Host ""
Write-Host "Creating online deployment helper scripts..." -ForegroundColor Cyan

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "build_for_production.ps1") -Content @'
# Anonymous Question Box - Build for Production
# Run from: C:\Users\boskm\anonymous-question-box

$ErrorActionPreference = "Stop"

$ProjectRoot = Join-Path $env:USERPROFILE "anonymous-question-box"

if (!(Test-Path $ProjectRoot)) {
    throw "Project folder not found: $ProjectRoot"
}

Set-Location $ProjectRoot

Write-Host ""
Write-Host "Building Anonymous Question Box for production..." -ForegroundColor Cyan
Write-Host ""

npm run install:all
npm run build --prefix frontend

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

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "deploy_precheck.ps1") -Content @'
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
'@

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "DEPLOY_RENDER_GUIDE.md") -Content @'
# Deploy Anonymous Question Box Online with Render

This guide deploys the app as one web service.

The backend serves the built frontend, so the final online links become:

```text
https://your-render-url.onrender.com/ask
https://your-render-url.onrender.com/admin/questions
```

## Important storage note

This app currently stores questions in a JSON file.

For online use, use a persistent disk or change the storage to a real database.

If the host has an ephemeral filesystem, saved questions can be lost when the service restarts or redeploys.

## 1. Build locally first

```powershell
cd C:\Users\boskm\anonymous-question-box
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\build_for_production.ps1
```

Then test production-style locally:

```powershell
npm start --prefix backend
```

Open:

```text
http://localhost:5000/ask
http://localhost:5000/admin/questions
```

Stop with `CTRL + C`.

## 2. Push project to GitHub

If this folder is not a Git repo yet:

```powershell
cd C:\Users\boskm\anonymous-question-box
git init
git add .
git commit -m "Prepare anonymous question box for online deployment"
```

Create an empty GitHub repository, then connect it:

```powershell
git remote add origin YOUR_GITHUB_REPO_URL
git branch -M main
git push -u origin main
```

## 3. Create Render Web Service

In Render:

1. Create a new Web Service.
2. Connect the GitHub repository.
3. Use the project root as the root directory.
4. Use this Build Command:

```text
npm run render:build
```

5. Use this Start Command:

```text
npm start
```

6. Use this health check path:

```text
/api/health
```

## 4. Environment variables

Set these in the Render dashboard:

```text
NODE_ENV=production
ADMIN_PASSWORD=your-strong-admin-password
QUESTION_COOLDOWN_SECONDS=20
```

For persistent disk setup, also set:

```text
QUESTION_STORAGE_FILE=/var/data/questions.json
```

## 5. Persistent disk

If using Render persistent disk:

- Mount path: `/var/data`
- Storage file env var: `QUESTION_STORAGE_FILE=/var/data/questions.json`

Without persistent storage, the JSON questions file should not be trusted for real use.

## 6. After deployment

Open:

```text
https://your-render-url.onrender.com/ask
```

Submit a test question.

Then open:

```text
https://your-render-url.onrender.com/admin/questions
```

Use the production admin password from Render environment variables.

## 7. If admin page says it cannot reach backend

Make sure you opened the Render URL, not the local `localhost` URL.

The frontend should call the same Render domain automatically in production.
'@

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "ONLINE_DEPLOYMENT_CHECKLIST.md") -Content @'
# Online Deployment Checklist

## Before deployment

- [ ] Run `.\deploy_precheck.ps1`
- [ ] Change the admin password
- [ ] Run `.\build_for_production.ps1`
- [ ] Test `http://localhost:5000/ask`
- [ ] Test `http://localhost:5000/admin/questions`
- [ ] Push project to GitHub

## Render settings

Build Command:

```text
npm run render:build
```

Start Command:

```text
npm start
```

Health Check Path:

```text
/api/health
```

Environment variables:

```text
NODE_ENV=production
ADMIN_PASSWORD=your-strong-password
QUESTION_COOLDOWN_SECONDS=20
QUESTION_STORAGE_FILE=/var/data/questions.json
```

Persistent disk:

```text
Mount path: /var/data
```

## After deployment

- [ ] Open `/ask`
- [ ] Submit a test question
- [ ] Open `/admin/questions`
- [ ] Confirm the question appears
- [ ] Mark answered
- [ ] Mark new
- [ ] Delete test question
- [ ] Copy public link
'@

Write-Utf8NoBomFile -Path (Join-Path $ProjectRoot "README.md") -Content @'
# Anonymous Question Box

A simple anonymous question app with a public form and private admin page.

## Public page

```text
/ask
```

## Admin page

```text
/admin/questions
```

## Local development

```powershell
cd C:\Users\boskm\anonymous-question-box
.\start_question_box.ps1
```

Local public form:

```text
http://localhost:5173/ask
```

Local admin page:

```text
http://localhost:5173/admin/questions
```

## Local production-style test

```powershell
cd C:\Users\boskm\anonymous-question-box
.\build_for_production.ps1
npm start --prefix backend
```

Then open:

```text
http://localhost:5000/ask
http://localhost:5000/admin/questions
```

## Online deployment

Read:

```text
DEPLOY_RENDER_GUIDE.md
ONLINE_DEPLOYMENT_CHECKLIST.md
```

Recommended Render settings:

Build Command:

```text
npm run render:build
```

Start Command:

```text
npm start
```

Health Check Path:

```text
/api/health
```

Important production env vars:

```text
NODE_ENV=production
ADMIN_PASSWORD=your-strong-password
QUESTION_COOLDOWN_SECONDS=20
QUESTION_STORAGE_FILE=/var/data/questions.json
```

## Storage warning

The current app saves questions in a JSON file.

For online use, use a persistent disk or switch to a real database. Without persistent storage, saved questions can be lost when the service restarts or redeploys.

## Helper scripts

```text
start_question_box.ps1
stop_question_box_ports.ps1
check_question_box.ps1
open_question_box_pages.ps1
set_admin_password.ps1
build_for_production.ps1
deploy_precheck.ps1
```
'@

Write-Host ""
Write-Host "Running production build check..." -ForegroundColor Cyan

Push-Location $ProjectRoot
npm run build --prefix frontend
Pop-Location

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " Build Step 06A completed successfully" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next local production test:" -ForegroundColor Cyan
Write-Host "cd C:\Users\boskm\anonymous-question-box" -ForegroundColor White
Write-Host "npm start --prefix backend" -ForegroundColor White
Write-Host ""
Write-Host "Then open:" -ForegroundColor Cyan
Write-Host "http://localhost:5000/ask" -ForegroundColor White
Write-Host "http://localhost:5000/admin/questions" -ForegroundColor White
Write-Host ""
Write-Host "Deployment guide:" -ForegroundColor Cyan
Write-Host "DEPLOY_RENDER_GUIDE.md" -ForegroundColor White
Write-Host ""
