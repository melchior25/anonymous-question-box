# Build Step 02 - Real Use Polish and Safety
# Run this script from: C:\Users\boskm\anonymous-question-box
#
# What this updates:
# - Fixes admin dashboard text encoding issue
# - Allows frontend ports 5173 and 5174 to reach backend
# - Adds simple backend cooldown protection
# - Improves public submit confirmation
# - Improves admin dashboard layout and empty state
# - Keeps the app simple: no login/signup for visitors

$ErrorActionPreference = "Stop"

Write-Host ""
Write-Host "===================================================" -ForegroundColor Cyan
Write-Host " Build Step 02 - Real Use Polish and Safety" -ForegroundColor Cyan
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

Write-Host "Updating backend files..." -ForegroundColor Cyan

Write-Utf8NoBomFile -Path (Join-Path $BackendRoot ".env") -Content @'
PORT=5000
ADMIN_PASSWORD=change-this-password
FRONTEND_URL=http://localhost:5173
FRONTEND_URLS=http://localhost:5173,http://localhost:5174,http://127.0.0.1:5173,http://127.0.0.1:5174
QUESTION_COOLDOWN_SECONDS=20
'@

Write-Utf8NoBomFile -Path (Join-Path $BackendRoot "server.js") -Content @'
const express = require('express')
const cors = require('cors')
const dotenv = require('dotenv')
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

const allowedOrigins = getAllowedOrigins()

app.use(cors({
  origin(origin, callback) {
    if (!origin || allowedOrigins.includes(origin)) {
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
    timestamp: new Date().toISOString()
  })
})

app.use('/api/questions', questionRoutes)

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
  console.log(`Allowed frontend origins: ${allowedOrigins.join(', ')}`)
})
'@

Write-Utf8NoBomFile -Path (Join-Path $BackendRoot "services\questionRateLimitService.js") -Content @'
const submissionTimesByClient = new Map()

function getClientKey(req) {
  const forwardedFor = req.headers['x-forwarded-for']

  if (typeof forwardedFor === 'string' && forwardedFor.trim()) {
    return forwardedFor.split(',')[0].trim()
  }

  return req.ip || req.socket?.remoteAddress || 'unknown-client'
}

function getCooldownSeconds() {
  const parsed = Number(process.env.QUESTION_COOLDOWN_SECONDS || 20)

  if (!Number.isFinite(parsed) || parsed < 0) {
    return 20
  }

  return parsed
}

function getSubmissionCooldownStatus(req) {
  const cooldownSeconds = getCooldownSeconds()

  if (cooldownSeconds === 0) {
    return {
      allowed: true,
      remainingSeconds: 0,
      clientKey: getClientKey(req)
    }
  }

  const clientKey = getClientKey(req)
  const now = Date.now()
  const previousSubmissionTime = submissionTimesByClient.get(clientKey)

  if (!previousSubmissionTime) {
    return {
      allowed: true,
      remainingSeconds: 0,
      clientKey
    }
  }

  const elapsedSeconds = Math.floor((now - previousSubmissionTime) / 1000)
  const remainingSeconds = cooldownSeconds - elapsedSeconds

  if (remainingSeconds > 0) {
    return {
      allowed: false,
      remainingSeconds,
      clientKey
    }
  }

  return {
    allowed: true,
    remainingSeconds: 0,
    clientKey
  }
}

function recordQuestionSubmission(clientKey) {
  submissionTimesByClient.set(clientKey, Date.now())

  if (submissionTimesByClient.size > 500) {
    const oldestKeys = Array.from(submissionTimesByClient.keys()).slice(0, 100)

    oldestKeys.forEach((key) => {
      submissionTimesByClient.delete(key)
    })
  }
}

module.exports = {
  getSubmissionCooldownStatus,
  recordQuestionSubmission
}
'@

Write-Utf8NoBomFile -Path (Join-Path $BackendRoot "services\questionStorageService.js") -Content @'
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

function removeJsonByteOrderMark(value) {
  if (typeof value !== 'string') return ''
  return value.replace(/^\uFEFF/, '').trim()
}

async function readQuestions() {
  await ensureStorage()

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

Write-Utf8NoBomFile -Path (Join-Path $BackendRoot "controllers\questionController.js") -Content @'
const {
  addQuestion,
  getQuestions,
  updateQuestionAnswered,
  removeQuestion
} = require('../services/questionStorageService')
const {
  getSubmissionCooldownStatus,
  recordQuestionSubmission
} = require('../services/questionRateLimitService')

function cleanQuestion(value) {
  if (typeof value !== 'string') return ''
  return value.replace(/\s+/g, ' ').trim()
}

async function createQuestion(req, res, next) {
  try {
    const cooldownStatus = getSubmissionCooldownStatus(req)

    if (!cooldownStatus.allowed) {
      return res.status(429).json({
        ok: false,
        message: `Please wait ${cooldownStatus.remainingSeconds} seconds before sending another question.`
      })
    }

    const question = cleanQuestion(req.body?.question)

    if (!question) {
      return res.status(400).json({
        ok: false,
        message: 'Please type a question first.'
      })
    }

    if (question.length < 3) {
      return res.status(400).json({
        ok: false,
        message: 'The question is too short.'
      })
    }

    if (question.length > 1000) {
      return res.status(400).json({
        ok: false,
        message: 'The question is too long. Please keep it under 1000 characters.'
      })
    }

    const savedQuestion = await addQuestion(question)
    recordQuestionSubmission(cooldownStatus.clientKey)

    res.status(201).json({
      ok: true,
      message: 'Question submitted.',
      question: {
        id: savedQuestion.id,
        createdAt: savedQuestion.createdAt
      }
    })
  } catch (error) {
    next(error)
  }
}

async function getAdminQuestions(req, res, next) {
  try {
    const questions = await getQuestions()

    res.json({
      ok: true,
      questions
    })
  } catch (error) {
    next(error)
  }
}

async function markQuestionAnswered(req, res, next) {
  try {
    const { id } = req.params
    const updated = await updateQuestionAnswered(id, true)

    if (!updated) {
      return res.status(404).json({
        ok: false,
        message: 'Question not found.'
      })
    }

    res.json({
      ok: true,
      question: updated
    })
  } catch (error) {
    next(error)
  }
}

async function deleteQuestion(req, res, next) {
  try {
    const { id } = req.params
    const removed = await removeQuestion(id)

    if (!removed) {
      return res.status(404).json({
        ok: false,
        message: 'Question not found.'
      })
    }

    res.json({
      ok: true,
      message: 'Question deleted.'
    })
  } catch (error) {
    next(error)
  }
}

module.exports = {
  createQuestion,
  getAdminQuestions,
  markQuestionAnswered,
  deleteQuestion
}
'@

Write-Host ""
Write-Host "Updating frontend files..." -ForegroundColor Cyan

Write-Utf8NoBomFile -Path (Join-Path $FrontendRoot "vite.config.ts") -Content @'
import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    strictPort: false
  }
})
'@

Write-Utf8NoBomFile -Path (Join-Path $FrontendRoot "src\services\questionApi.ts") -Content @'
import type { Question } from '../types/question.types'

const API_URL = import.meta.env.VITE_API_URL || 'http://localhost:5000'

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
  return 'Cannot reach the backend. Make sure npm run dev is running from the project root.'
}

export async function submitQuestion(question: string) {
  try {
    const response = await fetch(`${API_URL}/api/questions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({ question })
    })

    return readResponse<{ question: { id: string; createdAt: string } }>(response)
  } catch (error) {
    if (error instanceof Error && error.message !== 'Failed to fetch') {
      throw error
    }

    throw new Error(getNetworkErrorMessage())
  }
}

export async function getAdminQuestions(adminPassword: string) {
  try {
    const response = await fetch(`${API_URL}/api/questions/admin`, {
      headers: {
        'x-admin-password': adminPassword
      }
    })

    return readResponse<{ questions: Question[] }>(response)
  } catch (error) {
    if (error instanceof Error && error.message !== 'Failed to fetch') {
      throw error
    }

    throw new Error(getNetworkErrorMessage())
  }
}

export async function markQuestionAnswered(questionId: string, adminPassword: string) {
  try {
    const response = await fetch(`${API_URL}/api/questions/${questionId}/answered`, {
      method: 'PATCH',
      headers: {
        'x-admin-password': adminPassword
      }
    })

    return readResponse<{ question: Question }>(response)
  } catch (error) {
    if (error instanceof Error && error.message !== 'Failed to fetch') {
      throw error
    }

    throw new Error(getNetworkErrorMessage())
  }
}

export async function deleteQuestion(questionId: string, adminPassword: string) {
  try {
    const response = await fetch(`${API_URL}/api/questions/${questionId}`, {
      method: 'DELETE',
      headers: {
        'x-admin-password': adminPassword
      }
    })

    return readResponse<Record<string, never>>(response)
  } catch (error) {
    if (error instanceof Error && error.message !== 'Failed to fetch') {
      throw error
    }

    throw new Error(getNetworkErrorMessage())
  }
}
'@

Write-Utf8NoBomFile -Path (Join-Path $FrontendRoot "src\pages\AskQuestionPage.tsx") -Content @'
import { FormEvent, useMemo, useState } from 'react'
import { submitQuestion } from '../services/questionApi'

const MAX_LENGTH = 1000

function AskQuestionPage() {
  const [question, setQuestion] = useState('')
  const [status, setStatus] = useState<'idle' | 'sending' | 'sent' | 'error'>('idle')
  const [errorMessage, setErrorMessage] = useState('')

  const remainingCharacters = useMemo(() => {
    return MAX_LENGTH - question.length
  }, [question])

  async function handleSubmit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()

    const cleanQuestion = question.trim()

    if (!cleanQuestion) {
      setStatus('error')
      setErrorMessage('Please type your question first.')
      return
    }

    try {
      setStatus('sending')
      setErrorMessage('')
      await submitQuestion(cleanQuestion)
      setQuestion('')
      setStatus('sent')
    } catch (error) {
      setStatus('error')
      setErrorMessage(error instanceof Error ? error.message : 'Could not send your question.')
    }
  }

  return (
    <main className="public-page-shell">
      <section className="public-card">
        <div className="privacy-badge">No name. No account. No login.</div>

        <div className="eyebrow">Anonymous question box</div>

        <h1>Ask your question anonymously</h1>

        <p className="intro">
          Type your question below. You do not need to write your name, email address,
          username, or any personal information.
        </p>

        {status === 'sent' ? (
          <div className="success-panel">
            <div className="success-icon">OK</div>
            <h2>Your question has been sent.</h2>
            <p>
              Thank you. Your question was received anonymously. You may send another
              question if needed.
            </p>
            <button
              type="button"
              className="secondary-button"
              onClick={() => setStatus('idle')}
            >
              Ask another question
            </button>
          </div>
        ) : (
          <form className="question-form" onSubmit={handleSubmit}>
            <label htmlFor="question">Your question</label>

            <textarea
              id="question"
              value={question}
              maxLength={MAX_LENGTH}
              placeholder="Type your question here..."
              onChange={(event) => {
                setQuestion(event.target.value)

                if (status === 'error') {
                  setStatus('idle')
                  setErrorMessage('')
                }
              }}
            />

            <div className="form-row">
              <span className={remainingCharacters < 80 ? 'danger-count' : ''}>
                {remainingCharacters} characters left
              </span>
              <span>Keep it respectful and clear</span>
            </div>

            {status === 'error' && (
              <p className="error-message">{errorMessage}</p>
            )}

            <button
              type="submit"
              className="primary-button"
              disabled={status === 'sending'}
            >
              {status === 'sending' ? 'Sending...' : 'Send anonymously'}
            </button>
          </form>
        )}

        <p className="footer-note">
          This page only sends your question. It does not ask for a name or account.
        </p>
      </section>
    </main>
  )
}

export default AskQuestionPage
'@

Write-Utf8NoBomFile -Path (Join-Path $FrontendRoot "src\pages\AdminQuestionsPage.tsx") -Content @'
import { FormEvent, useEffect, useMemo, useState } from 'react'
import {
  deleteQuestion,
  getAdminQuestions,
  markQuestionAnswered
} from '../services/questionApi'
import type { Question } from '../types/question.types'

const PASSWORD_STORAGE_KEY = 'anonymous_question_box_admin_password'

function formatDate(value: string) {
  return new Intl.DateTimeFormat('en', {
    dateStyle: 'medium',
    timeStyle: 'short'
  }).format(new Date(value))
}

function AdminQuestionsPage() {
  const [adminPassword, setAdminPassword] = useState(() => {
    return sessionStorage.getItem(PASSWORD_STORAGE_KEY) || ''
  })
  const [passwordInput, setPasswordInput] = useState(adminPassword)
  const [questions, setQuestions] = useState<Question[]>([])
  const [loading, setLoading] = useState(false)
  const [errorMessage, setErrorMessage] = useState('')

  const newQuestionsCount = useMemo(() => {
    return questions.filter((question) => !question.answered).length
  }, [questions])

  const answeredQuestionsCount = useMemo(() => {
    return questions.filter((question) => question.answered).length
  }, [questions])

  async function loadQuestions(password = adminPassword) {
    if (!password) return

    try {
      setLoading(true)
      setErrorMessage('')
      const data = await getAdminQuestions(password)
      setQuestions(data.questions)
      sessionStorage.setItem(PASSWORD_STORAGE_KEY, password)
    } catch (error) {
      setQuestions([])
      setErrorMessage(error instanceof Error ? error.message : 'Could not load questions.')
    } finally {
      setLoading(false)
    }
  }

  async function handleLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    const cleanPassword = passwordInput.trim()
    setAdminPassword(cleanPassword)
    await loadQuestions(cleanPassword)
  }

  async function handleMarkAnswered(questionId: string) {
    try {
      await markQuestionAnswered(questionId, adminPassword)
      await loadQuestions(adminPassword)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Could not update question.')
    }
  }

  async function handleDelete(questionId: string) {
    const confirmed = window.confirm('Delete this question? This cannot be undone.')

    if (!confirmed) return

    try {
      await deleteQuestion(questionId, adminPassword)
      await loadQuestions(adminPassword)
    } catch (error) {
      setErrorMessage(error instanceof Error ? error.message : 'Could not delete question.')
    }
  }

  function handleLogout() {
    sessionStorage.removeItem(PASSWORD_STORAGE_KEY)
    setAdminPassword('')
    setPasswordInput('')
    setQuestions([])
    setErrorMessage('')
  }

  useEffect(() => {
    if (adminPassword) {
      loadQuestions(adminPassword)
    }
  }, [])

  if (!adminPassword) {
    return (
      <main className="admin-page-shell">
        <section className="admin-login-card">
          <div className="eyebrow">Private admin page</div>
          <h1>View anonymous questions</h1>
          <p className="intro">
            Enter the admin password to see submitted questions.
          </p>

          <form className="login-form" onSubmit={handleLogin}>
            <label htmlFor="password">Admin password</label>
            <input
              id="password"
              type="password"
              value={passwordInput}
              placeholder="Enter password"
              onChange={(event) => setPasswordInput(event.target.value)}
            />

            {errorMessage && (
              <p className="error-message">{errorMessage}</p>
            )}

            <button type="submit" className="primary-button">
              Open admin page
            </button>
          </form>
        </section>
      </main>
    )
  }

  return (
    <main className="admin-page-shell">
      <section className="admin-panel">
        <header className="admin-header">
          <div>
            <div className="eyebrow">Admin dashboard</div>
            <h1>Anonymous questions</h1>
            <p>
              {questions.length} total questions - {newQuestionsCount} new
            </p>
          </div>

          <div className="admin-actions">
            <button
              type="button"
              className="secondary-button"
              onClick={() => loadQuestions(adminPassword)}
              disabled={loading}
            >
              {loading ? 'Refreshing...' : 'Refresh'}
            </button>
            <button
              type="button"
              className="text-button"
              onClick={handleLogout}
            >
              Lock
            </button>
          </div>
        </header>

        <div className="admin-stats">
          <div className="stat-card">
            <span>Total</span>
            <strong>{questions.length}</strong>
          </div>
          <div className="stat-card">
            <span>New</span>
            <strong>{newQuestionsCount}</strong>
          </div>
          <div className="stat-card">
            <span>Answered</span>
            <strong>{answeredQuestionsCount}</strong>
          </div>
        </div>

        {errorMessage && (
          <p className="error-message">{errorMessage}</p>
        )}

        {questions.length === 0 ? (
          <div className="empty-state">
            <h2>No questions yet</h2>
            <p>
              When someone submits a question from the public page, it will appear here.
            </p>
            <a href="/ask" className="inline-link">
              Open public question page
            </a>
          </div>
        ) : (
          <div className="question-list">
            {questions.map((question) => (
              <article
                key={question.id}
                className={question.answered ? 'question-card answered' : 'question-card'}
              >
                <div className="question-card-top">
                  <span className="date-label">{formatDate(question.createdAt)}</span>
                  <span className={question.answered ? 'status answered-status' : 'status new-status'}>
                    {question.answered ? 'Answered' : 'New'}
                  </span>
                </div>

                <p>{question.text}</p>

                <div className="question-card-actions">
                  {!question.answered && (
                    <button
                      type="button"
                      className="secondary-button"
                      onClick={() => handleMarkAnswered(question.id)}
                    >
                      Mark answered
                    </button>
                  )}

                  <button
                    type="button"
                    className="danger-button"
                    onClick={() => handleDelete(question.id)}
                  >
                    Delete
                  </button>
                </div>
              </article>
            ))}
          </div>
        )}
      </section>
    </main>
  )
}

export default AdminQuestionsPage
'@

Write-Utf8NoBomFile -Path (Join-Path $FrontendRoot "src\styles.css") -Content @'
:root {
  font-family:
    Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI",
    sans-serif;
  color: #111827;
  background: #f5f1ea;
  font-synthesis: none;
  text-rendering: optimizeLegibility;
  -webkit-font-smoothing: antialiased;
}

* {
  box-sizing: border-box;
}

body {
  margin: 0;
  min-width: 320px;
  min-height: 100vh;
}

button,
textarea,
input {
  font: inherit;
}

button {
  cursor: pointer;
}

button:disabled {
  cursor: not-allowed;
  opacity: 0.65;
}

.public-page-shell,
.admin-page-shell {
  min-height: 100vh;
  padding: 32px 18px;
  display: grid;
  place-items: center;
  background:
    radial-gradient(circle at top left, rgba(255, 255, 255, 0.9), transparent 32rem),
    radial-gradient(circle at bottom right, rgba(219, 226, 215, 0.65), transparent 30rem),
    linear-gradient(135deg, #f7f1e7 0%, #f6f7fb 48%, #eef3f0 100%);
}

.public-card,
.admin-login-card,
.admin-panel {
  position: relative;
  width: min(100%, 760px);
  background: rgba(255, 255, 255, 0.94);
  border: 1px solid rgba(17, 24, 39, 0.08);
  border-radius: 32px;
  box-shadow: 0 28px 80px rgba(70, 55, 30, 0.12);
}

.public-card,
.admin-login-card {
  padding: clamp(28px, 5vw, 54px);
}

.admin-panel {
  width: min(100%, 980px);
  padding: clamp(22px, 4vw, 38px);
}

.privacy-badge {
  display: inline-flex;
  width: fit-content;
  margin-bottom: 20px;
  padding: 8px 12px;
  border-radius: 999px;
  background: #f3efe7;
  color: #4b3822;
  font-size: 0.82rem;
  font-weight: 850;
}

.eyebrow {
  color: #875f2d;
  font-size: 0.78rem;
  font-weight: 850;
  letter-spacing: 0.12em;
  text-transform: uppercase;
  margin-bottom: 14px;
}

h1,
h2,
p {
  margin-top: 0;
}

h1 {
  margin-bottom: 14px;
  font-size: clamp(2rem, 5vw, 3.6rem);
  line-height: 0.98;
  letter-spacing: -0.07em;
}

h2 {
  margin-bottom: 10px;
  font-size: 1.35rem;
  letter-spacing: -0.03em;
}

.intro {
  max-width: 620px;
  margin-bottom: 32px;
  color: #5b6473;
  font-size: 1.05rem;
  line-height: 1.7;
}

.footer-note {
  margin: 18px 0 0;
  color: #7a8190;
  font-size: 0.92rem;
  line-height: 1.55;
}

.question-form,
.login-form {
  display: grid;
  gap: 14px;
}

label {
  color: #111827;
  font-weight: 850;
}

textarea,
input {
  width: 100%;
  border: 1px solid rgba(17, 24, 39, 0.14);
  border-radius: 22px;
  outline: none;
  background: #fff;
  color: #111827;
  box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.7);
  transition:
    border-color 160ms ease,
    box-shadow 160ms ease;
}

textarea {
  min-height: 230px;
  padding: 18px;
  resize: vertical;
  line-height: 1.55;
}

input {
  min-height: 54px;
  padding: 0 16px;
}

textarea:focus,
input:focus {
  border-color: rgba(135, 95, 45, 0.7);
  box-shadow: 0 0 0 4px rgba(135, 95, 45, 0.12);
}

.form-row,
.question-card-top,
.question-card-actions,
.admin-header,
.admin-actions {
  display: flex;
  align-items: center;
  gap: 12px;
}

.form-row,
.question-card-top {
  justify-content: space-between;
  color: #6b7280;
  font-size: 0.9rem;
}

.danger-count {
  color: #b42318;
  font-weight: 850;
}

.primary-button,
.secondary-button,
.danger-button,
.text-button {
  border: 0;
  border-radius: 999px;
  font-weight: 850;
  transition:
    transform 160ms ease,
    box-shadow 160ms ease,
    background 160ms ease;
}

.primary-button {
  min-height: 56px;
  padding: 0 24px;
  background: #111827;
  color: #fff;
  box-shadow: 0 18px 40px rgba(17, 24, 39, 0.18);
}

.primary-button:hover {
  transform: translateY(-1px);
  box-shadow: 0 22px 46px rgba(17, 24, 39, 0.22);
}

.secondary-button {
  min-height: 42px;
  padding: 0 16px;
  background: #f3efe7;
  color: #2d2418;
}

.secondary-button:hover {
  background: #ebe1d2;
}

.danger-button {
  min-height: 42px;
  padding: 0 16px;
  background: #fff1f0;
  color: #a31912;
}

.danger-button:hover {
  background: #ffe2df;
}

.text-button {
  min-height: 42px;
  padding: 0 8px;
  background: transparent;
  color: #5b6473;
}

.error-message {
  margin: 0;
  padding: 12px 14px;
  border-radius: 16px;
  background: #fff1f0;
  color: #a31912;
  font-weight: 750;
  line-height: 1.5;
}

.success-panel,
.empty-state {
  padding: 26px;
  border-radius: 26px;
  background: #f7faf7;
  border: 1px solid rgba(42, 98, 61, 0.12);
}

.success-panel p,
.empty-state p {
  color: #5b6473;
  line-height: 1.65;
}

.success-icon {
  width: 48px;
  height: 48px;
  display: grid;
  place-items: center;
  margin-bottom: 16px;
  border-radius: 50%;
  background: #dff2e3;
  color: #245c38;
  font-weight: 900;
  font-size: 0.95rem;
}

.admin-header {
  justify-content: space-between;
  padding-bottom: 22px;
  border-bottom: 1px solid rgba(17, 24, 39, 0.08);
  margin-bottom: 18px;
}

.admin-header h1 {
  font-size: clamp(1.8rem, 4vw, 3rem);
  margin-bottom: 8px;
}

.admin-header p {
  margin: 0;
  color: #6b7280;
}

.admin-actions,
.question-card-actions {
  flex-wrap: wrap;
  justify-content: flex-end;
}

.admin-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 12px;
  margin-bottom: 22px;
}

.stat-card {
  padding: 16px;
  border-radius: 22px;
  background: #fbfaf8;
  border: 1px solid rgba(17, 24, 39, 0.06);
}

.stat-card span {
  display: block;
  margin-bottom: 8px;
  color: #6b7280;
  font-size: 0.82rem;
  font-weight: 800;
  text-transform: uppercase;
  letter-spacing: 0.08em;
}

.stat-card strong {
  color: #111827;
  font-size: 2rem;
  line-height: 1;
}

.question-list {
  display: grid;
  gap: 16px;
}

.question-card {
  padding: 20px;
  border-radius: 24px;
  background: #fff;
  border: 1px solid rgba(17, 24, 39, 0.08);
  box-shadow: 0 12px 30px rgba(17, 24, 39, 0.05);
}

.question-card.answered {
  background: #fbfbfa;
}

.question-card p {
  margin: 16px 0;
  color: #111827;
  font-size: 1.04rem;
  line-height: 1.65;
  white-space: pre-wrap;
}

.date-label {
  color: #6b7280;
}

.status {
  padding: 6px 10px;
  border-radius: 999px;
  font-size: 0.78rem;
  font-weight: 900;
}

.new-status {
  background: #eff6ff;
  color: #1d4ed8;
}

.answered-status {
  background: #ecfdf3;
  color: #247044;
}

.inline-link {
  display: inline-flex;
  margin-top: 4px;
  color: #111827;
  font-weight: 850;
  text-decoration: none;
}

.inline-link:hover {
  text-decoration: underline;
}

@media (max-width: 680px) {
  .public-page-shell,
  .admin-page-shell {
    align-items: start;
    padding-top: 18px;
  }

  .public-card,
  .admin-login-card,
  .admin-panel {
    border-radius: 24px;
  }

  .admin-header,
  .form-row,
  .question-card-top {
    align-items: flex-start;
    flex-direction: column;
  }

  .admin-actions,
  .question-card-actions {
    justify-content: flex-start;
  }

  .admin-stats {
    grid-template-columns: 1fr;
  }

  .primary-button,
  .secondary-button,
  .danger-button {
    width: 100%;
  }
}
'@

Write-Host ""
Write-Host "Clearing Vite cache..." -ForegroundColor Cyan

$ViteCache = Join-Path $FrontendRoot "node_modules\.vite"
if (Test-Path $ViteCache) {
    Remove-Item -Path $ViteCache -Recurse -Force
    Write-Host "Removed: $ViteCache" -ForegroundColor Green
} else {
    Write-Host "No Vite cache found. That is okay." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "===================================================" -ForegroundColor Green
Write-Host " Build Step 02 completed successfully" -ForegroundColor Green
Write-Host "===================================================" -ForegroundColor Green
Write-Host ""
Write-Host "Next:" -ForegroundColor Cyan
Write-Host "1. Stop dev server with CTRL + C if it is running" -ForegroundColor White
Write-Host "2. Run from the project root:" -ForegroundColor White
Write-Host "   cd C:\Users\boskm\anonymous-question-box" -ForegroundColor White
Write-Host "   npm run dev" -ForegroundColor White
Write-Host ""
Write-Host "Test pages:" -ForegroundColor Cyan
Write-Host "http://localhost:5173/ask" -ForegroundColor White
Write-Host "http://localhost:5173/admin/questions" -ForegroundColor White
Write-Host ""
Write-Host "Admin password:" -ForegroundColor Cyan
Write-Host "change-this-password" -ForegroundColor White
Write-Host ""
