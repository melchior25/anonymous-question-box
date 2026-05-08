# Build Step 01C - Fix Backend Questions JSON Storage
# Run this script from: C:\Users\boskm\anonymous-question-box
# It fixes backend/data/questions.json and makes the JSON reader safer.

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Build Step 01C - Fix Backend JSON Storage" -ForegroundColor Cyan
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host ""

$ProjectRoot = Join-Path $env:USERPROFILE "anonymous-question-box"
$BackendRoot = Join-Path $ProjectRoot "backend"
$QuestionsFile = Join-Path $BackendRoot "data\questions.json"
$StorageServiceFile = Join-Path $BackendRoot "services\questionStorageService.js"

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
    Write-Host "Created/updated: $Path" -ForegroundColor Green
}

Write-Host "Rewriting question storage file as clean UTF-8 JSON..." -ForegroundColor Cyan
Write-Utf8NoBomFile -Path $QuestionsFile -Content @'
[]
'@

Write-Host ""
Write-Host "Updating backend storage service with safer JSON reading..." -ForegroundColor Cyan

Write-Utf8NoBomFile -Path $StorageServiceFile -Content @'
const fs = require('fs/promises')
const path = require('path')

const dataDirectory = path.join(__dirname, '..', 'data')
const questionsFile = path.join(dataDirectory, 'questions.json')

async function ensureStorage() {
  await fs.mkdir(dataDirectory, { recursive: true })

  try {
    await fs.access(questionsFile)
  } catch {
    await fs.writeFile(questionsFile, JSON.stringify([], null, 2), 'utf8')
  }
}

function cleanJsonText(raw) {
  if (typeof raw !== 'string') return ''

  return raw
    .replace(/^\uFEFF/, '')
    .replace(/\u0000/g, '')
    .trim()
}

async function recoverInvalidStorage(raw, error) {
  const timestamp = new Date().toISOString().replace(/[:.]/g, '-')
  const backupFile = path.join(dataDirectory, `questions.invalid-${timestamp}.json`)

  try {
    await fs.writeFile(backupFile, raw || '', 'utf8')
  } catch {
    // Keep recovery safe even if backup fails.
  }

  await fs.writeFile(questionsFile, JSON.stringify([], null, 2), 'utf8')

  console.warn('Invalid questions.json was reset. Backup created if possible.')
  console.warn(error.message)

  return []
}

async function readQuestions() {
  await ensureStorage()

  const raw = await fs.readFile(questionsFile, 'utf8')
  const cleaned = cleanJsonText(raw)

  if (!cleaned) {
    await fs.writeFile(questionsFile, JSON.stringify([], null, 2), 'utf8')
    return []
  }

  try {
    const parsed = JSON.parse(cleaned)

    if (!Array.isArray(parsed)) {
      await fs.writeFile(questionsFile, JSON.stringify([], null, 2), 'utf8')
      return []
    }

    return parsed
  } catch (error) {
    return recoverInvalidStorage(raw, error)
  }
}

async function writeQuestions(questions) {
  await ensureStorage()

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

module.exports = {
  addQuestion,
  getQuestions,
  updateQuestionAnswered,
  removeQuestion
}
'@

Write-Host ""
Write-Host "Checking backend storage file..." -ForegroundColor Cyan

Push-Location $BackendRoot
node -e "const fs=require('fs'); const data=JSON.parse(fs.readFileSync('./data/questions.json','utf8').replace(/^\uFEFF/,'').trim() || '[]'); console.log('questions.json OK:', Array.isArray(data));"
Pop-Location

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " Step 01C completed" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Now restart cleanly:" -ForegroundColor Cyan
Write-Host "1. Stop the current backend/dev server with CTRL + C" -ForegroundColor White
Write-Host "2. Run:" -ForegroundColor White
Write-Host "   cd C:\Users\boskm\anonymous-question-box" -ForegroundColor White
Write-Host "   npm run dev" -ForegroundColor White
Write-Host ""
Write-Host "Then test:" -ForegroundColor Cyan
Write-Host "http://localhost:5173/ask" -ForegroundColor White
Write-Host "http://localhost:5173/admin/questions" -ForegroundColor White
Write-Host ""
