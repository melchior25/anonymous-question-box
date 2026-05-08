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