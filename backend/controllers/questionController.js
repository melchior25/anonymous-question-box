const {
  addQuestion,
  getQuestions,
  updateQuestionAnswered,
  removeQuestion,
  removeAnsweredQuestions
} = require('../services/questionStorageService')
const {
  getSubmissionCooldownStatus,
  recordQuestionSubmission
} = require('../services/questionRateLimitService')
const {
  sendQuestionEmailNotification
} = require('../services/questionEmailService')

function cleanQuestion(value) {
  if (typeof value !== 'string') return ''
  return value.replace(/\s+/g, ' ').trim()
}

function getQuestionReference(id) {
  if (typeof id !== 'string') return 'UNKNOWN'
  return id.split('_').slice(-1)[0]?.slice(0, 6).toUpperCase() || 'UNKNOWN'
}

function escapeCsvValue(value) {
  const stringValue = value === null || value === undefined ? '' : String(value)
  return `"${stringValue.replace(/"/g, '""')}"`
}

function createQuestionsCsv(questions) {
  const header = ['Reference', 'Created At', 'Status', 'Question', 'Answered At']

  const rows = questions.map((question) => {
    return [
      getQuestionReference(question.id),
      question.createdAt || '',
      question.answered ? 'Answered' : 'New',
      question.text || '',
      question.answeredAt || ''
    ]
  })

  return [header, ...rows]
    .map((row) => row.map(escapeCsvValue).join(','))
    .join('\n')
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

    sendQuestionEmailNotification(savedQuestion).catch((error) => {
      console.warn('Question was saved, but email notification failed.')
      console.warn(error)
    })

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

async function exportAdminQuestionsCsv(req, res, next) {
  try {
    const questions = await getQuestions()
    const csv = createQuestionsCsv(questions)
    const dateLabel = new Date().toISOString().slice(0, 10)

    res.setHeader('Content-Type', 'text/csv; charset=utf-8')
    res.setHeader('Content-Disposition', `attachment; filename="anonymous-questions-${dateLabel}.csv"`)
    res.send(csv)
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

async function markQuestionNew(req, res, next) {
  try {
    const { id } = req.params
    const updated = await updateQuestionAnswered(id, false)

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

async function deleteAnsweredQuestions(req, res, next) {
  try {
    const deletedCount = await removeAnsweredQuestions()

    res.json({
      ok: true,
      message: `${deletedCount} answered question${deletedCount === 1 ? '' : 's'} deleted.`,
      deletedCount
    })
  } catch (error) {
    next(error)
  }
}

module.exports = {
  createQuestion,
  getAdminQuestions,
  exportAdminQuestionsCsv,
  markQuestionAnswered,
  markQuestionNew,
  deleteQuestion,
  deleteAnsweredQuestions
}