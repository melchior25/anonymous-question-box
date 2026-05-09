const fs = require('fs/promises')
const path = require('path')
const { Pool } = require('pg')

let pool = null
let databaseReady = false

function getDatabaseUrl() {
  return (process.env.DATABASE_URL || '').trim()
}

function hasDatabaseUrl() {
  return Boolean(getDatabaseUrl())
}

function getPool() {
  if (!hasDatabaseUrl()) return null

  if (!pool) {
    pool = new Pool({
      connectionString: getDatabaseUrl(),
      ssl: { rejectUnauthorized: false },
      max: 5,
      idleTimeoutMillis: 30000,
      connectionTimeoutMillis: 15000
    })

    pool.on('error', (error) => {
      console.warn('Unexpected Postgres pool error.')
      console.warn(error)
    })
  }

  return pool
}

async function ensureDatabaseStorage() {
  const activePool = getPool()
  if (!activePool) return false
  if (databaseReady) return true

  await activePool.query(`
    CREATE TABLE IF NOT EXISTS questions (
      id TEXT PRIMARY KEY,
      text TEXT NOT NULL,
      answered BOOLEAN NOT NULL DEFAULT FALSE,
      created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
      answered_at TIMESTAMPTZ NULL
    );
  `)

  await activePool.query(`
    CREATE INDEX IF NOT EXISTS questions_created_at_idx
    ON questions (created_at DESC);
  `)

  databaseReady = true
  console.log('Question storage: Neon/Postgres is ready.')
  return true
}

function mapDatabaseQuestion(row) {
  return {
    id: row.id,
    text: row.text,
    answered: Boolean(row.answered),
    createdAt: row.created_at instanceof Date ? row.created_at.toISOString() : row.created_at,
    answeredAt: row.answered_at
      ? row.answered_at instanceof Date
        ? row.answered_at.toISOString()
        : row.answered_at
      : null
  }
}

function getQuestionsFile() {
  const configuredFile = (process.env.QUESTION_STORAGE_FILE || '').trim()
  if (configuredFile) return configuredFile

  const configuredDirectory = (process.env.QUESTION_STORAGE_DIR || '').trim()
  if (configuredDirectory) return path.join(configuredDirectory, 'questions.json')

  return path.join(__dirname, '..', 'data', 'questions.json')
}

async function ensureJsonStorage() {
  const questionsFile = getQuestionsFile()
  await fs.mkdir(path.dirname(questionsFile), { recursive: true })

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

async function readJsonQuestions() {
  await ensureJsonStorage()
  const questionsFile = getQuestionsFile()
  const raw = await fs.readFile(questionsFile, 'utf8')
  const cleaned = removeJsonByteOrderMark(raw)
  if (!cleaned) return []

  try {
    const parsed = JSON.parse(cleaned)
    return Array.isArray(parsed) ? parsed : []
  } catch {
    const brokenBackupFile = `${questionsFile}.broken-${Date.now()}`
    await fs.writeFile(brokenBackupFile, raw, 'utf8')
    await fs.writeFile(questionsFile, JSON.stringify([], null, 2), 'utf8')
    console.warn(`questions.json was invalid. A backup was saved to: ${brokenBackupFile}`)
    return []
  }
}

async function writeJsonQuestions(questions) {
  await ensureJsonStorage()
  const questionsFile = getQuestionsFile()
  const temporaryFile = `${questionsFile}.tmp`
  await fs.writeFile(temporaryFile, JSON.stringify(questions, null, 2), 'utf8')
  await fs.rename(temporaryFile, questionsFile)
}

function createId() {
  return `question_${Date.now()}_${Math.random().toString(16).slice(2)}`
}

async function addQuestion(text) {
  if (await ensureDatabaseStorage()) {
    const newQuestion = {
      id: createId(),
      text,
      answered: false,
      createdAt: new Date().toISOString(),
      answeredAt: null
    }

    await getPool().query(
      `INSERT INTO questions (id, text, answered, created_at, answered_at)
       VALUES ($1, $2, $3, $4, $5)`,
      [newQuestion.id, newQuestion.text, newQuestion.answered, newQuestion.createdAt, newQuestion.answeredAt]
    )

    return newQuestion
  }

  const questions = await readJsonQuestions()
  const newQuestion = {
    id: createId(),
    text,
    answered: false,
    createdAt: new Date().toISOString(),
    answeredAt: null
  }

  questions.unshift(newQuestion)
  await writeJsonQuestions(questions)
  return newQuestion
}

async function getQuestions() {
  if (await ensureDatabaseStorage()) {
    const result = await getPool().query(`
      SELECT id, text, answered, created_at, answered_at
      FROM questions
      ORDER BY created_at DESC
    `)
    return result.rows.map(mapDatabaseQuestion)
  }

  return readJsonQuestions()
}

async function updateQuestionAnswered(id, answered) {
  if (await ensureDatabaseStorage()) {
    const result = await getPool().query(
      `UPDATE questions
       SET answered = $2,
           answered_at = CASE WHEN $2 = TRUE THEN NOW() ELSE NULL END
       WHERE id = $1
       RETURNING id, text, answered, created_at, answered_at`,
      [id, answered]
    )

    if (result.rowCount === 0) return null
    return mapDatabaseQuestion(result.rows[0])
  }

  const questions = await readJsonQuestions()
  const questionIndex = questions.findIndex((question) => question.id === id)
  if (questionIndex === -1) return null

  questions[questionIndex] = {
    ...questions[questionIndex],
    answered,
    answeredAt: answered ? new Date().toISOString() : null
  }

  await writeJsonQuestions(questions)
  return questions[questionIndex]
}

async function removeQuestion(id) {
  if (await ensureDatabaseStorage()) {
    const result = await getPool().query('DELETE FROM questions WHERE id = $1', [id])
    return result.rowCount > 0
  }

  const questions = await readJsonQuestions()
  const nextQuestions = questions.filter((question) => question.id !== id)
  if (nextQuestions.length === questions.length) return false

  await writeJsonQuestions(nextQuestions)
  return true
}

async function removeAnsweredQuestions() {
  if (await ensureDatabaseStorage()) {
    const result = await getPool().query('DELETE FROM questions WHERE answered = TRUE')
    return result.rowCount || 0
  }

  const questions = await readJsonQuestions()
  const nextQuestions = questions.filter((question) => !question.answered)
  const deletedCount = questions.length - nextQuestions.length

  if (deletedCount === 0) return 0
  await writeJsonQuestions(nextQuestions)
  return deletedCount
}

async function getStorageStatus() {
  if (hasDatabaseUrl()) {
    try {
      await ensureDatabaseStorage()
      return { type: 'postgres', ok: true }
    } catch (error) {
      return { type: 'postgres', ok: false, message: error.message }
    }
  }

  return { type: 'json', ok: true }
}

module.exports = {
  addQuestion,
  getQuestions,
  updateQuestionAnswered,
  removeQuestion,
  removeAnsweredQuestions,
  getStorageStatus
}