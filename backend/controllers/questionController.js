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
  markQuestionAnswered,
  markQuestionNew,
  deleteQuestion,
  deleteAnsweredQuestions
}